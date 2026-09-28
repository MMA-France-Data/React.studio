-- Simulation tower defense 1v1, entièrement côté serveur (le client ne fait qu'afficher et demander).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Enemies = require(Shared.Enemies)
local MapLayout = require(Shared.MapLayout)
local Placement = require(Shared.Placement)
local Remotes = require(Shared.Remotes)
local Sends = require(Shared.Sends)
local Towers = require(Shared.Towers)

local C = Config.Match

local Game = {}
Game.__index = Game

type Lane = {
	index: number,
	player: Player?,
	name: string,
	baseHealth: number,
	gold: number,
	income: number,
	towers: { any },
	enemies: { any },
	spawnQueue: { any },
	lastActionAt: number,
	lastSendAt: number,
}

-- slots : { { player: Player?, name: string } } (index = numéro de lane)
-- onEnd(winnerLaneIndex: number?, reason: string) est appelé une seule fois.
function Game.new(slots, matchState: Instance, onEnd: (number?, string) -> ())
	local self = setmetatable({}, Game)
	self.matchState = matchState
	self.onEnd = onEnd
	self.running = false
	self.wave = 0
	self.nextId = 0
	self.connections = {}
	self.attributeCache = {}
	self.enemyFolder = workspace:WaitForChild("Enemies")
	self.towerFolder = workspace:WaitForChild("Towers")

	self.lanes = {} :: { Lane }
	self.laneByUserId = {}
	for index, slot in slots do
		local lane: Lane = {
			index = index,
			player = slot.player,
			name = slot.name,
			baseHealth = C.BASE_HEALTH,
			gold = C.STARTING_GOLD,
			income = 0,
			towers = {},
			enemies = {},
			spawnQueue = {},
			lastActionAt = 0,
			lastSendAt = 0,
		}
		self.lanes[index] = lane
		if slot.player then
			self.laneByUserId[slot.player.UserId] = lane
		end
	end
	return self
end

function Game:newId(): number
	self.nextId += 1
	return self.nextId
end

function Game:opponentOf(lane: Lane): Lane
	return self.lanes[if lane.index == 1 then 2 else 1]
end

function Game:notify(lane: Lane, message: string, kind: string?)
	if lane.player and lane.player.Parent then
		Remotes.get("Notify"):FireClient(lane.player, message, kind or "Info")
	end
end

-- N'écrit l'attribut que s'il a changé (moins de trafic réseau).
function Game:setState(name: string, value: any)
	if self.attributeCache[name] ~= value then
		self.attributeCache[name] = value
		self.matchState:SetAttribute(name, value)
	end
end

function Game:syncState()
	self:setState("Wave", self.wave)
	for _, lane in self.lanes do
		local prefix = "Lane" .. lane.index
		self:setState(prefix .. "Health", lane.baseHealth)
		self:setState(prefix .. "Gold", math.floor(lane.gold))
		self:setState(prefix .. "Income", C.BASE_INCOME + lane.income)
	end
end

----------------------------------------------------------------------
-- Ennemis
----------------------------------------------------------------------

function Game:queueEnemy(lane: Lane, enemyType: string, at: number, healthMultiplier: number)
	table.insert(lane.spawnQueue, { enemy = enemyType, at = at, healthMultiplier = healthMultiplier })
end

function Game:spawnEnemy(lane: Lane, enemyType: string, healthMultiplier: number)
	local def = Enemies.Defs[enemyType]
	local health = math.floor(def.health * healthMultiplier)

	local part = Instance.new("Part")
	part.Name = enemyType
	part.Size = Vector3.one * def.size
	part.Color = def.color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part:SetAttribute("Health", health)
	part:SetAttribute("MaxHealth", health)
	part:SetAttribute("Lane", lane.index)

	local localPosition, direction = MapLayout.pointAt(0)
	local position = MapLayout.toWorld(lane.index, localPosition) + Vector3.new(0, def.size / 2, 0)
	part.CFrame = CFrame.lookAt(position, position + direction)
	part.Parent = self.enemyFolder

	table.insert(lane.enemies, {
		id = self:newId(),
		def = def,
		part = part,
		health = health,
		distance = 0,
		position = position,
		slowUntil = 0,
		slowFactor = 0,
		dead = false,
	})
end

function Game:processSpawns(lane: Lane, now: number)
	if #lane.spawnQueue == 0 then
		return
	end
	local capacity = C.MAX_ENEMIES_PER_LANE - #lane.enemies
	for i = #lane.spawnQueue, 1, -1 do
		local item = lane.spawnQueue[i]
		if item.at <= now and capacity > 0 then
			table.remove(lane.spawnQueue, i)
			self:spawnEnemy(lane, item.enemy, item.healthMultiplier)
			capacity -= 1
		end
	end
end

function Game:moveEnemies(lane: Lane, dt: number, now: number, parts: { BasePart }, cframes: { CFrame })
	for _, enemy in lane.enemies do
		if enemy.dead then
			continue
		end
		local speed = enemy.def.speed
		if now < enemy.slowUntil then
			speed *= 1 - enemy.slowFactor
		end
		enemy.distance += speed * dt

		if enemy.distance >= MapLayout.PATH_LENGTH then
			-- L'ennemi atteint la base.
			enemy.dead = true
			enemy.part:Destroy()
			lane.baseHealth = math.max(0, lane.baseHealth - enemy.def.damage)
			continue
		end

		local localPosition, direction = MapLayout.pointAt(enemy.distance)
		local position = MapLayout.toWorld(lane.index, localPosition) + Vector3.new(0, enemy.def.size / 2, 0)
		enemy.position = position
		table.insert(parts, enemy.part)
		table.insert(cframes, CFrame.lookAt(position, position + direction))
	end
end

function Game:damageEnemy(lane: Lane, enemy, amount: number)
	if enemy.dead then
		return
	end
	enemy.health -= amount
	if enemy.health <= 0 then
		enemy.dead = true
		enemy.part:Destroy()
		lane.gold += enemy.def.reward
	else
		enemy.part:SetAttribute("Health", math.ceil(enemy.health))
	end
end

function Game:removeDeadEnemies(lane: Lane)
	for i = #lane.enemies, 1, -1 do
		if lane.enemies[i].dead then
			table.remove(lane.enemies, i)
		end
	end
end

----------------------------------------------------------------------
-- Tours
----------------------------------------------------------------------

local function horizontalDistance(a: Vector3, b: Vector3): number
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

function Game:findTarget(lane: Lane, tower, stats)
	local best, bestScore = nil, -math.huge
	for _, enemy in lane.enemies do
		if enemy.dead or horizontalDistance(tower.position, enemy.position) > stats.range then
			continue
		end
		local score = if tower.def.targeting == "Strongest" then enemy.health else enemy.distance
		if score > bestScore then
			best, bestScore = enemy, score
		end
	end
	return best
end

function Game:towerAttack(lane: Lane, tower, now: number): boolean
	local stats = Towers.stats(tower.type, tower.level)
	local fired = Remotes.get("TowerFired")
	local muzzle = tower.position + Vector3.new(0, 3 + tower.level, 0)

	if tower.def.kind == "Aura" then
		local hitAny = false
		for _, enemy in lane.enemies do
			if not enemy.dead and horizontalDistance(tower.position, enemy.position) <= stats.range then
				hitAny = true
				local currentSlow = if now < enemy.slowUntil then enemy.slowFactor else 0
				enemy.slowFactor = math.max(currentSlow, stats.slow)
				enemy.slowUntil = math.max(enemy.slowUntil, now + stats.slowDuration)
				self:damageEnemy(lane, enemy, stats.damage)
			end
		end
		if hitAny then
			fired:FireAllClients(muzzle, tower.position, tower.type, stats.range)
		end
		return hitAny
	end

	local target = self:findTarget(lane, tower, stats)
	if not target then
		return false
	end
	local impact = target.position

	if tower.def.kind == "Splash" then
		for _, enemy in lane.enemies do
			if not enemy.dead and horizontalDistance(impact, enemy.position) <= stats.splash then
				self:damageEnemy(lane, enemy, stats.damage)
			end
		end
		fired:FireAllClients(muzzle, impact, tower.type, stats.splash)
	else
		self:damageEnemy(lane, target, stats.damage)
		fired:FireAllClients(muzzle, impact, tower.type, 0)
	end
	return true
end

function Game:updateTowers(lane: Lane, dt: number, now: number)
	for _, tower in lane.towers do
		tower.cooldown -= dt
		if tower.cooldown <= 0 then
			local attacked = self:towerAttack(lane, tower, now)
			tower.cooldown = if attacked then Towers.stats(tower.type, tower.level).cooldown else 0
		end
	end
end

function Game:buildTowerModel(lane: Lane, tower)
	local model = Instance.new("Model")
	model.Name = tower.type

	local base = Instance.new("Part")
	base.Name = "Base"
	base.Shape = Enum.PartType.Cylinder
	base.Size = Vector3.new(1, 4, 4)
	base.CFrame = CFrame.new(tower.position + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
	base.Color = Color3.fromRGB(60, 60, 70)
	base.Anchored = true
	base.Parent = model

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Color = tower.def.color
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = true
	body.CanCollide = false
	body.Parent = model

	model.PrimaryPart = base
	model:SetAttribute("TowerId", tower.id)
	model:SetAttribute("TowerType", tower.type)
	model:SetAttribute("Lane", lane.index)
	model:SetAttribute("OwnerUserId", if lane.player then lane.player.UserId else 0)
	model.Parent = self.towerFolder

	tower.model = model
	tower.body = body
	self:refreshTowerModel(tower)
end

function Game:refreshTowerModel(tower)
	local height = 1.5 + tower.level * 1.2
	tower.body.Size = Vector3.new(2.4, height, 2.4)
	tower.body.CFrame = CFrame.new(tower.position + Vector3.new(0, 1 + height / 2, 0))
	tower.body.Material = if tower.level >= Towers.maxLevel(tower.type) then Enum.Material.Neon else Enum.Material.SmoothPlastic
	tower.model:SetAttribute("Level", tower.level)
end

function Game:placeTower(lane: Lane, towerType: string, position: Vector3): (boolean, string?)
	local def = Towers.Defs[towerType]
	if #lane.towers >= C.MAX_TOWERS then
		return false, "Nombre maximum de tours atteint"
	end
	local cost = def.levels[1].cost
	if lane.gold < cost then
		return false, "Pas assez d'or"
	end

	local groundPosition = Vector3.new(position.X, 0, position.Z)
	local existing = {}
	for _, tower in lane.towers do
		table.insert(existing, tower.position)
	end
	local ok, reason = Placement.check(lane.index, groundPosition, existing)
	if not ok then
		return false, reason
	end

	lane.gold -= cost
	local tower = {
		id = self:newId(),
		type = towerType,
		def = def,
		level = 1,
		spent = cost,
		position = groundPosition,
		cooldown = 0,
	}
	table.insert(lane.towers, tower)
	self:buildTowerModel(lane, tower)
	return true, nil
end

local function findTower(lane: Lane, towerId: number)
	for index, tower in lane.towers do
		if tower.id == towerId then
			return tower, index
		end
	end
	return nil, nil
end

----------------------------------------------------------------------
-- Actions des joueurs (toujours validées ici, jamais de confiance au client)
----------------------------------------------------------------------

function Game:laneForAction(player: Player): Lane?
	if not self.running then
		return nil
	end
	local lane = self.laneByUserId[player.UserId]
	if not lane then
		return nil
	end
	local now = os.clock()
	if now - lane.lastActionAt < C.ACTION_COOLDOWN then
		return nil
	end
	lane.lastActionAt = now
	return lane
end

function Game:onPlaceTower(player: Player, towerType: any, position: any)
	if typeof(towerType) ~= "string" or not Towers.Defs[towerType] or typeof(position) ~= "Vector3" then
		return
	end
	local lane = self:laneForAction(player)
	if not lane then
		return
	end
	local ok, reason = self:placeTower(lane, towerType, position)
	if not ok then
		self:notify(lane, reason or "Impossible de poser la tour", "Error")
	end
end

function Game:onUpgradeTower(player: Player, towerId: any)
	if typeof(towerId) ~= "number" then
		return
	end
	local lane = self:laneForAction(player)
	local tower = lane and findTower(lane, towerId)
	if not lane or not tower then
		return
	end
	local cost = Towers.upgradeCost(tower.type, tower.level)
	if not cost then
		self:notify(lane, "Niveau maximum atteint", "Error")
		return
	end
	if lane.gold < cost then
		self:notify(lane, "Pas assez d'or", "Error")
		return
	end
	lane.gold -= cost
	tower.spent += cost
	tower.level += 1
	self:refreshTowerModel(tower)
end

function Game:onSellTower(player: Player, towerId: any)
	if typeof(towerId) ~= "number" then
		return
	end
	local lane = self:laneForAction(player)
	if not lane then
		return
	end
	local tower, index = findTower(lane, towerId)
	if not tower then
		return
	end
	table.remove(lane.towers, index)
	tower.model:Destroy()
	lane.gold += math.floor(tower.spent * C.SELL_REFUND)
end

function Game:onSendEnemies(player: Player, sendId: any)
	if typeof(sendId) ~= "string" or not Sends.Defs[sendId] then
		return
	end
	local lane = self:laneForAction(player)
	if not lane then
		return
	end
	local def = Sends.Defs[sendId]
	local now = workspace:GetServerTimeNow()
	if self.wave < def.minWave then
		self:notify(lane, `Disponible à partir de la vague {def.minWave}`, "Error")
		return
	end
	if now - lane.lastSendAt < Sends.COOLDOWN then
		return
	end
	if lane.gold < def.cost then
		self:notify(lane, "Pas assez d'or", "Error")
		return
	end

	lane.gold -= def.cost
	lane.income += def.income
	lane.lastSendAt = now

	local opponent = self:opponentOf(lane)
	local multiplier = Enemies.healthMultiplier(math.max(1, self.wave))
	for i = 1, def.count do
		self:queueEnemy(opponent, def.enemy, now + (i - 1) * Sends.SPAWN_GAP, multiplier)
	end
	self:notify(opponent, `{lane.name} t'envoie : {def.displayName} x{def.count} !`, "Warning")
end

----------------------------------------------------------------------
-- Vagues, bot, fin de partie
----------------------------------------------------------------------

function Game:startWave(now: number)
	self.wave += 1
	self.nextWaveAt = now + C.WAVE_INTERVAL
	self:setState("NextWaveAt", self.nextWaveAt)

	local composition = Enemies.buildWave(self.wave)
	local multiplier = Enemies.healthMultiplier(self.wave)
	for _, lane in self.lanes do
		lane.gold += C.BASE_INCOME + lane.income
		local at = now
		for _, item in composition do
			self:queueEnemy(lane, item.enemy, at, multiplier)
			at += item.gap
		end
		if not lane.player then
			self:botTurn(lane)
		end
	end
end

-- Bot très simple (utilisé seulement pour les tests solo dans Studio) :
-- dépense son or en posant des tours au hasard ou en les améliorant.
function Game:botTurn(lane: Lane)
	for _ = 1, 30 do
		if lane.gold < 150 then
			return
		end
		local upgradable = lane.towers[math.random(1, math.max(1, #lane.towers))]
		if upgradable and math.random() < 0.3 then
			local cost = Towers.upgradeCost(upgradable.type, upgradable.level)
			if cost and lane.gold >= cost then
				lane.gold -= cost
				upgradable.spent += cost
				upgradable.level += 1
				self:refreshTowerModel(upgradable)
			end
		else
			local towerType = Towers.ORDER[math.random(1, #Towers.ORDER)]
			local x = (math.random() - 0.5) * (MapLayout.LANE_WIDTH - 8)
			local z = (math.random() - 0.5) * (MapLayout.LANE_LENGTH - 8)
			self:placeTower(lane, towerType, MapLayout.toWorld(lane.index, Vector3.new(x, 0, z)))
		end
	end
end

function Game:checkEnd(now: number)
	local destroyed1 = self.lanes[1].baseHealth <= 0
	local destroyed2 = self.lanes[2].baseHealth <= 0
	if destroyed1 and destroyed2 then
		self:finish(nil, "BothDestroyed")
	elseif destroyed1 then
		self:finish(2, "BaseDestroyed")
	elseif destroyed2 then
		self:finish(1, "BaseDestroyed")
	elseif now - self.startedAt >= C.MAX_DURATION then
		local h1, h2 = self.lanes[1].baseHealth, self.lanes[2].baseHealth
		self:finish(if h1 == h2 then nil elseif h1 > h2 then 1 else 2, "TimeLimit")
	end
end

function Game:finish(winner: number?, reason: string)
	if not self.running then
		return
	end
	self:stop()
	self.onEnd(winner, reason)
end

function Game:step(dt: number)
	if not self.running then
		return
	end
	local now = workspace:GetServerTimeNow()
	if now >= self.nextWaveAt then
		self:startWave(now)
	end

	local parts, cframes = {}, {}
	for _, lane in self.lanes do
		self:processSpawns(lane, now)
		self:moveEnemies(lane, dt, now, parts, cframes)
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end

	for _, lane in self.lanes do
		self:updateTowers(lane, dt, now)
		self:removeDeadEnemies(lane)
	end

	self:syncState()
	self:checkEnd(now)
end

function Game:start()
	local now = workspace:GetServerTimeNow()
	self.running = true
	self.startedAt = now
	self.nextWaveAt = now + C.FIRST_WAVE_DELAY
	self:setState("StartedAt", now)
	self:setState("NextWaveAt", self.nextWaveAt)
	self:syncState()

	local function connect(remoteName: string, handler)
		table.insert(self.connections, Remotes.get(remoteName).OnServerEvent:Connect(function(player, ...)
			handler(self, player, ...)
		end))
	end
	connect("PlaceTower", Game.onPlaceTower)
	connect("UpgradeTower", Game.onUpgradeTower)
	connect("SellTower", Game.onSellTower)
	connect("SendEnemies", Game.onSendEnemies)

	table.insert(self.connections, RunService.Heartbeat:Connect(function(dt)
		self:step(dt)
	end))

	for _, lane in self.lanes do
		if not lane.player then
			self:botTurn(lane)
		end
	end
end

function Game:stop()
	self.running = false
	for _, connection in self.connections do
		connection:Disconnect()
	end
	table.clear(self.connections)
	self:syncState()
end

return Game

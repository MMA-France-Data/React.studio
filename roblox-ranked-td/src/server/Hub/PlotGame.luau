-- Simulation du mode infini sur une parcelle (une instance par joueur).
--
-- Impossible de perdre : si une vague fait tomber la base, on redescend d'une vague et on
-- réessaie. Vague réussie -> vague suivante. On oscille donc autour de sa vague maximale.
--
-- Les ennemis n'existent que sous forme de données côté serveur. Les clients reçoivent leur
-- position quelques fois par seconde (paquet binaire compact) et les affichent eux-mêmes :
-- 6 parcelles pleines d'ennemis ne font pas ramer le serveur.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enemies = require(Shared.Enemies)
local IdleConfig = require(Shared.IdleConfig)
local IdleTowers = require(Shared.IdleTowers)
local NumberFormat = require(Shared.NumberFormat)
local PlotLayout = require(Shared.PlotLayout)
local Remotes = require(Shared.Remotes)
local PlayerData = require(script.Parent.Parent.PlayerData)
local HubMap = require(script.Parent.HubMap)
local IdleTowerModel = require(script.Parent.IdleTowerModel)

local ENEMY_INDEX = {}
for index, name in Enemies.ORDER do
	ENEMY_INDEX[name] = index
end
local TOWER_INDEX = {}
for index, name in IdleTowers.ORDER do
	TOWER_INDEX[name] = index
end

-- Taille d'un ennemi dans le paquet : id u32, type u8, distance f32, PV % u8, vitesse % u8
local ENEMY_BYTES = 11
-- Taille d'un tir : départ 3xf32, arrivée 3xf32, type u8, rayon u8
local SHOT_BYTES = 26

local PlotGame = {}
PlotGame.__index = PlotGame

function PlotGame.new(plot, player: Player, data)
	local self = setmetatable({}, PlotGame)
	self.plot = plot
	self.index = plot.index
	self.cframe = PlotLayout.cframe(plot.index)
	self.player = player
	self.data = data
	self.idle = data.idle

	self.enemies = {}
	self.spawnQueue = {}
	self.spawnIndex = 1
	self.towers = {} -- [spotIndex] = tour
	self.drops = {} -- [id] = pile de pièces
	self.dropCount = 0
	self.shots = {}
	self.nextId = 0
	self.attributeCache = {}
	self.lastSyncEmpty = false

	self.state = "Intermission"
	self.nextWaveAt = os.clock() + IdleConfig.FIRST_WAVE_DELAY
	self.baseHealth = IdleConfig.BASE_HEALTH

	self.towerFolder = Instance.new("Folder")
	self.towerFolder.Name = "Towers"
	self.towerFolder.Parent = plot.folder

	for key, saved in self.idle.towers do
		local spotIndex = tonumber(key)
		if spotIndex and IdleTowers.Defs[saved.type] and spotIndex <= self.idle.unlockedSpots then
			self:createTower(spotIndex, saved.type, saved.level or 1, saved.spent or 0)
		end
	end

	HubMap.setUnlockedSpots(plot, self.idle.unlockedSpots)
	self:setAttr("OwnerUserId", player.UserId)
	self:setAttr("MaxBaseHealth", IdleConfig.BASE_HEALTH)
	self:setAttr("NextWaveAt", workspace:GetServerTimeNow() + IdleConfig.FIRST_WAVE_DELAY)
	self:syncAttributes()
	return self
end

function PlotGame:newId(): number
	self.nextId = (self.nextId + 1) % 4294967295
	return self.nextId
end

function PlotGame:notify(message: string, kind: string?)
	if self.player.Parent then
		Remotes.get("Notify"):FireClient(self.player, message, kind or "Info")
	end
end

-- Attributs du dossier de la parcelle (lus par le HUD des clients).
function PlotGame:setAttr(name: string, value: any)
	if self.attributeCache[name] ~= value then
		self.attributeCache[name] = value
		self.plot.folder:SetAttribute(name, value)
	end
end

function PlotGame:syncAttributes()
	local alive = 0
	for _, enemy in self.enemies do
		if not enemy.dead then
			alive += 1
		end
	end
	self:setAttr("Wave", self.idle.wave)
	self:setAttr("WaveType", IdleConfig.waveType(self.idle.wave))
	self:setAttr("BestWave", self.idle.bestWave)
	self:setAttr("HighestWave", self.idle.highestWave)
	self:setAttr("UnlockedSpots", self.idle.unlockedSpots)
	self:setAttr("State", self.state)
	self:setAttr("BaseHealth", math.max(0, self.baseHealth))
	self:setAttr("EnemiesLeft", alive + (#self.spawnQueue - self.spawnIndex + 1))
end

----------------------------------------------------------------------
-- Vagues
----------------------------------------------------------------------

function PlotGame:startWave()
	local now = os.clock()
	local at = now
	self.spawnQueue = {}
	self.spawnIndex = 1
	for _, item in IdleConfig.buildWave(self.idle.wave) do
		table.insert(self.spawnQueue, { enemy = item.enemy, health = item.health, reward = item.reward, at = at })
		at += item.gap
	end
	self.baseHealth = IdleConfig.BASE_HEALTH
	self.state = "Running"
end

function PlotGame:clearEnemies()
	table.clear(self.enemies)
	self.spawnQueue = {}
	self.spawnIndex = 1
end

function PlotGame:endWave(success: boolean)
	local wave = self.idle.wave
	self:clearEnemies()
	self.state = "Intermission"
	local delay
	if success then
		self.idle.bestWave = math.max(self.idle.bestWave, wave)
		self.idle.highestWave = math.max(self.idle.highestWave, wave)
		self.idle.wave = wave + 1
		delay = IdleConfig.WAVE_CLEAR_DELAY
	else
		self.idle.wave = math.max(1, wave - 1)
		delay = IdleConfig.WAVE_FAIL_DELAY
		self:notify(`Vague {wave} ratée : retour à la vague {self.idle.wave}`, "Warning")
	end
	self.nextWaveAt = os.clock() + delay
	self:setAttr("NextWaveAt", workspace:GetServerTimeNow() + delay)
end

function PlotGame:spawnEnemy(item)
	local def = Enemies.Defs[item.enemy]
	local localPosition = PlotLayout.pointAt(0)
	table.insert(self.enemies, {
		id = self:newId(),
		typeIndex = ENEMY_INDEX[item.enemy],
		def = def,
		health = item.health,
		maxHealth = item.health,
		reward = item.reward,
		distance = 0,
		position = self.cframe:PointToWorldSpace(localPosition),
		slowUntil = 0,
		slowFactor = 0,
		dead = false,
	})
end

----------------------------------------------------------------------
-- Pièces
----------------------------------------------------------------------

function PlotGame:sendDrop(action: string, drop)
	if self.player.Parent then
		Remotes.get("CoinDrop"):FireClient(self.player, action, drop.id, drop.position, drop.amount)
	end
end

-- Les pièces tombent au sol ; une nouvelle pièce proche d'une pile s'y ajoute.
function PlotGame:addDrop(position: Vector3, amount: number)
	local nearest, nearestDistance = nil, math.huge
	for _, drop in self.drops do
		local distance = (drop.position - position).Magnitude
		if distance < nearestDistance then
			nearest, nearestDistance = drop, distance
		end
	end
	if nearest and (nearestDistance <= IdleConfig.MERGE_RADIUS or self.dropCount >= IdleConfig.MAX_DROPS) then
		nearest.amount += amount
		self:sendDrop("Set", nearest)
		return
	end

	local ground = self.cframe:PointToObjectSpace(position)
	local drop = {
		id = self:newId(),
		position = self.cframe:PointToWorldSpace(Vector3.new(ground.X, 1, ground.Z)),
		amount = amount,
	}
	self.drops[drop.id] = drop
	self.dropCount += 1
	self:sendDrop("Set", drop)
end

-- Ramasse les piles proches du joueur (appelé quelques fois par seconde).
function PlotGame:collectDrops()
	local character = self.player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or self.dropCount == 0 then
		return
	end
	for id, drop in self.drops do
		local offset = drop.position - root.Position
		if Vector3.new(offset.X, 0, offset.Z).Magnitude <= IdleConfig.PICKUP_RADIUS and math.abs(offset.Y) < 10 then
			self.drops[id] = nil
			self.dropCount -= 1
			PlayerData.addCoins(self.player, drop.amount)
			self:sendDrop("Collect", drop)
		end
	end
end

----------------------------------------------------------------------
-- Combat
----------------------------------------------------------------------

local function horizontalDistance(a: Vector3, b: Vector3): number
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

function PlotGame:damageEnemy(enemy, amount: number)
	if enemy.dead then
		return
	end
	enemy.health -= amount
	if enemy.health <= 0 then
		enemy.dead = true
		-- Le bonus ne s'applique qu'au gain de l'ennemi, jamais aux pièces déjà possédées.
		self:addDrop(enemy.position, enemy.reward * (1 + self.idle.coinBonus / 100))
	end
end

function PlotGame:addShot(from: Vector3, to: Vector3, towerType: string, radius: number)
	if #self.shots < IdleConfig.MAX_SHOTS_PER_PACKET then
		table.insert(self.shots, { from = from, to = to, type = TOWER_INDEX[towerType], radius = radius })
	end
end

function PlotGame:towerAttack(tower, now: number): boolean
	local stats = IdleTowers.stats(tower.type, tower.level)
	local muzzle = tower.position + Vector3.new(0, 5, 0)

	if stats.kind == "Aura" then
		local hitAny = false
		for _, enemy in self.enemies do
			if not enemy.dead and horizontalDistance(tower.position, enemy.position) <= stats.range then
				hitAny = true
				local currentSlow = if now < enemy.slowUntil then enemy.slowFactor else 0
				enemy.slowFactor = math.max(currentSlow, stats.slow)
				enemy.slowUntil = math.max(enemy.slowUntil, now + stats.slowDuration)
				self:damageEnemy(enemy, stats.damage)
			end
		end
		if hitAny then
			self:addShot(tower.position, tower.position, tower.type, stats.range)
		end
		return hitAny
	end

	local target, bestScore = nil, -math.huge
	for _, enemy in self.enemies do
		if not enemy.dead and horizontalDistance(tower.position, enemy.position) <= stats.range then
			local score = if stats.targeting == "Strongest" then enemy.health else enemy.distance
			if score > bestScore then
				target, bestScore = enemy, score
			end
		end
	end
	if not target then
		return false
	end

	local impact = target.position
	if stats.kind == "Splash" then
		for _, enemy in self.enemies do
			if not enemy.dead and horizontalDistance(impact, enemy.position) <= stats.splash then
				self:damageEnemy(enemy, stats.damage)
			end
		end
		self:addShot(muzzle, impact, tower.type, stats.splash)
	else
		if stats.slow then
			-- Tour électrique : fort ralentissement sur une seule cible.
			local currentSlow = if now < target.slowUntil then target.slowFactor else 0
			target.slowFactor = math.max(currentSlow, stats.slow)
			target.slowUntil = math.max(target.slowUntil, now + stats.slowDuration)
		end
		self:damageEnemy(target, stats.damage)
		self:addShot(muzzle, impact, tower.type, 0)
	end
	return true
end

function PlotGame:step(dt: number)
	local now = os.clock()
	if self.state == "Intermission" then
		if now >= self.nextWaveAt then
			self:startWave()
		end
		self:syncAttributes()
		return
	end

	-- Apparitions
	while self.spawnIndex <= #self.spawnQueue and #self.enemies < IdleConfig.MAX_ENEMIES do
		local item = self.spawnQueue[self.spawnIndex]
		if item.at > now then
			break
		end
		self.spawnIndex += 1
		self:spawnEnemy(item)
	end

	-- Déplacements
	for _, enemy in self.enemies do
		if enemy.dead then
			continue
		end
		local speed = enemy.def.speed * IdleConfig.ENEMY_SPEED_MULTIPLIER
		if now < enemy.slowUntil then
			speed *= 1 - enemy.slowFactor
		end
		enemy.distance += speed * dt
		if enemy.distance >= PlotLayout.PATH_LENGTH then
			enemy.dead = true
			self.baseHealth -= enemy.def.damage
		else
			enemy.position = self.cframe:PointToWorldSpace((PlotLayout.pointAt(enemy.distance)))
		end
	end

	-- Tours
	for _, tower in self.towers do
		tower.cooldown -= dt
		if tower.cooldown <= 0 then
			local attacked = self:towerAttack(tower, now)
			tower.cooldown = if attacked then IdleTowers.stats(tower.type, tower.level).cooldown else 0
		end
	end

	for i = #self.enemies, 1, -1 do
		if self.enemies[i].dead then
			table.remove(self.enemies, i)
		end
	end

	if self.baseHealth <= 0 then
		self:endWave(false)
	elseif self.spawnIndex > #self.spawnQueue and #self.enemies == 0 then
		self:endWave(true)
	end
	self:syncAttributes()
end

----------------------------------------------------------------------
-- Réseau
----------------------------------------------------------------------

-- Positions de tous les ennemis vivants, encodées dans un buffer. nil si rien à envoyer.
function PlotGame:buildSyncPacket(): (buffer?, number)
	local count = #self.enemies
	if count == 0 then
		if self.lastSyncEmpty then
			return nil, 0
		end
		self.lastSyncEmpty = true
	else
		self.lastSyncEmpty = false
	end

	local now = os.clock()
	local packet = buffer.create(count * ENEMY_BYTES)
	for i, enemy in self.enemies do
		local offset = (i - 1) * ENEMY_BYTES
		local speedFactor = if now < enemy.slowUntil then 1 - enemy.slowFactor else 1
		buffer.writeu32(packet, offset, enemy.id)
		buffer.writeu8(packet, offset + 4, enemy.typeIndex)
		buffer.writef32(packet, offset + 5, enemy.distance)
		buffer.writeu8(packet, offset + 9, math.clamp(math.ceil(enemy.health / enemy.maxHealth * 255), 0, 255))
		buffer.writeu8(packet, offset + 10, math.clamp(math.floor(speedFactor * 100 + 0.5), 0, 255))
	end
	return packet, count
end

function PlotGame:takeShotsPacket(): (buffer?, number)
	local count = #self.shots
	if count == 0 then
		return nil, 0
	end
	local packet = buffer.create(count * SHOT_BYTES)
	for i, shot in self.shots do
		local offset = (i - 1) * SHOT_BYTES
		buffer.writef32(packet, offset, shot.from.X)
		buffer.writef32(packet, offset + 4, shot.from.Y)
		buffer.writef32(packet, offset + 8, shot.from.Z)
		buffer.writef32(packet, offset + 12, shot.to.X)
		buffer.writef32(packet, offset + 16, shot.to.Y)
		buffer.writef32(packet, offset + 20, shot.to.Z)
		buffer.writeu8(packet, offset + 24, shot.type or 1)
		buffer.writeu8(packet, offset + 25, math.clamp(math.floor(shot.radius + 0.5), 0, 255))
	end
	table.clear(self.shots)
	return packet, count
end

----------------------------------------------------------------------
-- Tours et emplacements (actions du joueur)
----------------------------------------------------------------------

function PlotGame:createTower(spotIndex: number, towerType: string, level: number, spent: number)
	local cframe = PlotLayout.worldCFrame(self.index, PlotLayout.SPOTS[spotIndex] + Vector3.new(0, 0.3, 0))
	local model = IdleTowerModel.create(towerType, cframe, self.towerFolder, {
		SpotIndex = spotIndex,
		PlotIndex = self.index,
		Level = level,
		Spent = spent,
	})
	self.towers[spotIndex] = {
		spotIndex = spotIndex,
		type = towerType,
		level = level,
		spent = spent,
		position = cframe.Position,
		cooldown = 0,
		model = model,
	}
	self.idle.towers[tostring(spotIndex)] = { type = towerType, level = level, spent = spent }
end

function PlotGame:removeTower(spotIndex: number)
	local tower = self.towers[spotIndex]
	if tower then
		tower.model:Destroy()
		self.towers[spotIndex] = nil
		self.idle.towers[tostring(spotIndex)] = nil
	end
end

local function validSpot(self, spotIndex: any): boolean
	return typeof(spotIndex) == "number"
		and spotIndex == math.floor(spotIndex)
		and spotIndex >= 1
		and spotIndex <= self.idle.unlockedSpots
end

-- Poser une tour. Si l'emplacement est occupé, l'ancienne est remplacée et rembourse 50 %.
function PlotGame:placeTower(spotIndex: any, towerType: any)
	if not validSpot(self, spotIndex) or typeof(towerType) ~= "string" or not IdleTowers.Defs[towerType] then
		return
	end
	local def = IdleTowers.Defs[towerType]
	local existing = self.towers[spotIndex]
	if existing and existing.type == towerType then
		self:notify("Cette tour est déjà posée ici", "Error")
		return
	end
	local refund = if existing then math.floor(existing.spent * IdleConfig.SELL_REFUND) else 0
	if self.data.coins + refund < def.placeCost then
		self:notify("Pas assez de pièces", "Error")
		return
	end

	if existing then
		self:removeTower(spotIndex)
		PlayerData.addCoins(self.player, refund)
	end
	PlayerData.addCoins(self.player, -def.placeCost)
	self:createTower(spotIndex, towerType, 1, def.placeCost)
	if existing then
		self:notify(`{def.displayName} posé • ancienne tour revendue +{NumberFormat.short(refund)}`, "Success")
	end
end

-- Améliorer une tour : +1 niveau, dégâts multipliés (voir IdleConfig.UPGRADE_DAMAGE).
function PlotGame:upgradeTower(spotIndex: any)
	local tower = validSpot(self, spotIndex) and self.towers[spotIndex]
	if not tower then
		return
	end
	local cost = IdleTowers.upgradeCost(tower.type, tower.level)
	if self.data.coins < cost then
		self:notify(`Il te faut {NumberFormat.short(cost)} pièces`, "Error")
		return
	end
	PlayerData.addCoins(self.player, -cost)
	tower.level += 1
	tower.spent += cost
	tower.model:SetAttribute("Level", tower.level)
	tower.model:SetAttribute("Spent", tower.spent)
	self.idle.towers[tostring(spotIndex)] = { type = tower.type, level = tower.level, spent = tower.spent }
end

function PlotGame:sellTower(spotIndex: any)
	if not validSpot(self, spotIndex) or not self.towers[spotIndex] then
		return
	end
	local refund = math.floor(self.towers[spotIndex].spent * IdleConfig.SELL_REFUND)
	self:removeTower(spotIndex)
	PlayerData.addCoins(self.player, refund)
	self:notify(`Tour vendue : +{NumberFormat.short(refund)} pièces`, "Success")
end

-- Débloque l'emplacement suivant (toujours dans l'ordre).
function PlotGame:buySpot()
	local spotIndex = self.idle.unlockedSpots + 1
	if spotIndex > #PlotLayout.SPOTS then
		self:notify("Tous les emplacements sont débloqués", "Info")
		return
	end
	local cost = PlotLayout.spotCost(spotIndex)
	if self.data.coins < cost then
		self:notify(`Il te faut {NumberFormat.short(cost)} pièces`, "Error")
		return
	end
	PlayerData.addCoins(self.player, -cost)
	self.idle.unlockedSpots = spotIndex
	HubMap.setUnlockedSpots(self.plot, spotIndex)
	self:syncAttributes()
	self:notify(`Emplacement {spotIndex} débloqué !`, "Success")
end

-- Le joueur quitte le serveur : on libère la parcelle (sa progression est déjà dans ses données).
function PlotGame:destroy()
	self.towerFolder:Destroy()
	self:clearEnemies()
	table.clear(self.drops)
	self.dropCount = 0
	HubMap.setUnlockedSpots(self.plot, PlotLayout.STARTING_SPOTS)
	-- Paquet vide : les clients effacent les ennemis de cette parcelle.
	Remotes.get("PlotSync"):FireAllClients(self.index, buffer.create(0), 0)
	for name in self.attributeCache do
		self.plot.folder:SetAttribute(name, nil)
	end
end

return PlotGame

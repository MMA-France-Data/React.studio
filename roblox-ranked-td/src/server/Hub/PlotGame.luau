-- Simulation du mode infini sur une parcelle (une instance par joueur).
--
-- Impossible de perdre : si UN SEUL ennemi atteint le bout du chemin, la vague est ratée, on redescend
-- d'une vague et on réessaie (pas de PV de base). Vague réussie -> vague suivante. On oscille donc
-- autour de sa vague maximale.
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

-- Taille d'un ennemi dans le paquet : id u32, type u8, distance f32, PV % u8, vitesse % u8.
-- « vitesse % » = facteur de son type (IdleConfig.ENEMY_SPEED_FACTORS) x ralentissement, en % :
-- le client avance l'ennemi à vitesse de Enemies.luau x ENEMY_SPEED_MULTIPLIER x ce facteur.
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

	self.towerFolder = Instance.new("Folder")
	self.towerFolder.Name = "Towers"
	self.towerFolder.Parent = plot.folder

	for key, saved in self.idle.towers do
		local spotIndex = tonumber(key)
		if IdleTowers.Defs[saved.type] and self:ownsSpot(spotIndex) then
			self:createTower(spotIndex, saved.type, saved.level or 1, saved.spent or 0, saved.bonus)
		end
	end
	self:publishInventory()

	self:refreshSpots()
	self:setAttr("OwnerUserId", player.UserId)
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
	-- Renaissance : bonus de pièces en % et nombre de renaissances (lus par RebirthUI).
	-- Publiés avant Wave : un client qui voit la vague retomber à 1 peut vérifier si Rebirths a changé.
	self:setAttr("CoinBonus", self.idle.coinBonus)
	self:setAttr("Rebirths", self.idle.rebirths)
	self:setAttr("Wave", self.idle.wave)
	self:setAttr("WaveType", IdleConfig.waveType(self.idle.wave))
	self:setAttr("BestWave", self.idle.bestWave)
	self:setAttr("HighestWave", self.idle.highestWave)
	self:setAttr("UnlockedSpots", self.idle.unlockedSpots)
	self:setAttr("State", self.state)
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
	self.state = "Running"
end

function PlotGame:clearEnemies()
	table.clear(self.enemies)
	self.spawnQueue = {}
	self.spawnIndex = 1
end

-- Fin de vague. Ratée = un ennemi (leakedName) a atteint le bout du chemin.
function PlotGame:endWave(success: boolean, leakedName: string?)
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
		self:notify(`Vague {wave} ratée : un {leakedName or "ennemi"} a atteint ta base ! Retour à la vague {self.idle.wave}`, "Warning")
	end
	self.nextWaveAt = os.clock() + delay
	self:setAttr("NextWaveAt", workspace:GetServerTimeNow() + delay)
end

-- Renaissance : seule la vague repart à 1 (nouvelle run), contre un bonus de pièces permanent
-- (IdleConfig.rebirthGain, selon la meilleure vague de la run). Tout le reste est gardé : pièces,
-- tours, améliorations, emplacements, tours débloquées, doublons, bonus, record.
-- Les piles de pièces déjà au sol restent à ramasser.
function PlotGame:rebirth()
	local gain = IdleConfig.rebirthGain(self.idle.bestWave)
	if gain <= 0 then
		self:notify(`Réussis la vague {IdleConfig.REBIRTH_MIN_WAVE} pour renaître (meilleure vague de la run : {self.idle.bestWave})`, "Error")
		return
	end
	self.idle.coinBonus = IdleConfig.roundPercent(self.idle.coinBonus + gain)
	self.idle.rebirths += 1
	self.idle.wave = 1
	self.idle.bestWave = 1

	-- La vague en cours s'arrête : ennemis et file d'apparition vidés, entracte avant la vague 1.
	self:clearEnemies()
	self.state = "Intermission"
	self.nextWaveAt = os.clock() + IdleConfig.FIRST_WAVE_DELAY
	self:setAttr("NextWaveAt", workspace:GetServerTimeNow() + IdleConfig.FIRST_WAVE_DELAY)
	self:syncAttributes()

	self:notify(
		`Renaissance ! +{IdleConfig.formatPercent(gain)} % de pièces • bonus total : +{IdleConfig.formatPercent(self.idle.coinBonus)} %`,
		"Success"
	)
	-- Sauvegarde tout de suite (sans bloquer la simulation).
	task.spawn(PlayerData.save, self.player)
end

function PlotGame:spawnEnemy(item)
	local def = Enemies.Defs[item.enemy]
	local localPosition = PlotLayout.pointAt(0)
	table.insert(self.enemies, {
		id = self:newId(),
		typeIndex = ENEMY_INDEX[item.enemy],
		def = def,
		-- Facteur de vitesse de son type, propre au mode infini (cavaliers freinés...).
		speedScale = IdleConfig.enemySpeedFactor(item.enemy),
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

-- Ralentissements : ils ne s'additionnent jamais, le plus fort gagne. Un ralentissement plus fort
-- remplace l'actuel, un égal le prolonge, un plus faible est ignoré tant que l'actuel dure (sans ça,
-- 60 % pendant 1 s puis 25 % pendant 3 s donnaient 60 % pendant 3 s).
local function applySlow(enemy, slow: number, duration: number, now: number)
	local active = now < enemy.slowUntil
	if not active or slow > enemy.slowFactor then
		enemy.slowFactor = slow
		enemy.slowUntil = now + duration
	elseif slow == enemy.slowFactor then
		enemy.slowUntil = math.max(enemy.slowUntil, now + duration)
	end
end

-- Vitesse actuelle en fraction de la vitesse normale du mode infini : type x ralentissement.
local function speedFactorOf(enemy, now: number): number
	local slowFactor = if now < enemy.slowUntil then 1 - enemy.slowFactor else 1
	return enemy.speedScale * slowFactor
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

-- Stats d'une tour posée : niveau, doublons et bonus compris.
function PlotGame:statsOf(tower)
	return IdleTowers.effectiveStats(tower.type, tower.level, self.idle.towerDupes[tower.type], tower.bonus)
end

function PlotGame:towerAttack(tower, now: number): boolean
	local stats = self:statsOf(tower)
	local muzzle = tower.position + Vector3.new(0, 5, 0)

	if stats.kind == "Aura" then
		local hitAny = false
		for _, enemy in self.enemies do
			if not enemy.dead and horizontalDistance(tower.position, enemy.position) <= stats.range then
				hitAny = true
				-- Totem de givre : ralentit fortement tout ce qui est dans l'aura (voir IdleTowers.luau).
				applySlow(enemy, stats.slow, stats.slowDuration, now)
				self:damageEnemy(enemy, stats.damage)
			end
		end
		if hitAny then
			self:addShot(tower.position, tower.position, tower.type, stats.range)
		end
		return hitAny
	end

	if stats.kind == "Chain" then
		-- Touche les N ennemis les plus avancés à portée.
		local inRange = {}
		for _, enemy in self.enemies do
			if not enemy.dead and horizontalDistance(tower.position, enemy.position) <= stats.range then
				table.insert(inRange, enemy)
			end
		end
		if #inRange == 0 then
			return false
		end
		table.sort(inRange, function(a, b)
			return a.distance > b.distance
		end)
		local from = muzzle
		for i = 1, math.min(stats.chains, #inRange) do
			local enemy = inRange[i]
			self:addShot(from, enemy.position, tower.type, 0)
			from = enemy.position
			self:damageEnemy(enemy, stats.damage)
		end
		return true
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
			applySlow(target, stats.slow, stats.slowDuration, now)
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

	-- Déplacements. Un seul ennemi au bout du chemin = vague ratée, tout de suite.
	for _, enemy in self.enemies do
		if enemy.dead then
			continue
		end
		local speed = enemy.def.speed * IdleConfig.ENEMY_SPEED_MULTIPLIER * speedFactorOf(enemy, now)
		enemy.distance += speed * dt
		if enemy.distance >= PlotLayout.PATH_LENGTH then
			self:endWave(false, enemy.def.displayName)
			self:syncAttributes()
			return
		end
		enemy.position = self.cframe:PointToWorldSpace((PlotLayout.pointAt(enemy.distance)))
	end

	-- Tours
	for _, tower in self.towers do
		tower.cooldown -= dt
		if tower.cooldown <= 0 then
			local attacked = self:towerAttack(tower, now)
			tower.cooldown = if attacked then self:statsOf(tower).cooldown else 0
		end
	end

	for i = #self.enemies, 1, -1 do
		if self.enemies[i].dead then
			table.remove(self.enemies, i)
		end
	end

	if self.spawnIndex > #self.spawnQueue and #self.enemies == 0 then
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
		local speedFactor = speedFactorOf(enemy, now)
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

function PlotGame:createTower(spotIndex: number, towerType: string, level: number, spent: number, bonus: string?)
	if bonus and not IdleConfig.BONUS_BY_ID[bonus] then
		bonus = nil
	end
	local cframe = PlotLayout.worldCFrame(self.index, PlotLayout.SPOTS[spotIndex] + Vector3.new(0, 0.3, 0))
	local model = IdleTowerModel.create(towerType, cframe, self.towerFolder, {
		SpotIndex = spotIndex,
		PlotIndex = self.index,
		Level = level,
		Spent = spent,
		Bonus = bonus or "",
	})
	self.towers[spotIndex] = {
		spotIndex = spotIndex,
		type = towerType,
		level = level,
		spent = spent,
		position = cframe.Position,
		cooldown = 0,
		model = model,
		bonus = bonus,
	}
	self:saveTower(self.towers[spotIndex])
end

function PlotGame:saveTower(tower)
	self.idle.towers[tostring(tower.spotIndex)] = { type = tower.type, level = tower.level, spent = tower.spent, bonus = tower.bonus }
end

-- Retire la tour. Son bonus éventuel retourne dans l'inventaire.
function PlotGame:removeTower(spotIndex: number)
	local tower = self.towers[spotIndex]
	if tower and tower.bonus and #self.idle.bonuses < IdleConfig.MAX_BONUS_INVENTORY then
		table.insert(self.idle.bonuses, tower.bonus)
		self:publishInventory()
	end
	if tower then
		tower.model:Destroy()
		self.towers[spotIndex] = nil
		self.idle.towers[tostring(spotIndex)] = nil
	end
end

-- Vrai si le joueur possède cet emplacement (numéro valide ET acheté ou de départ).
-- Toutes les actions sur un emplacement passent par là : le client ne peut rien faire ailleurs.
function PlotGame:ownsSpot(spotIndex: any): boolean
	return PlotLayout.isSpotIndex(spotIndex) and self.idle.ownedSpots[tostring(spotIndex)] == true
end

-- Poser une tour. Emplacement occupé : seulement pour un remplacement confirmé, où le client nomme la
-- tour qu'il remplace (replaceType, envoyé par la confirmation de PlotUI) ; l'ancienne rembourse alors 50 %.
-- Sans ça (clic parti avant l'arrivée de la tour à cause du lag...), la pose est refusée : une grosse
-- tour n'est jamais remplacée par accident.
function PlotGame:placeTower(spotIndex: any, towerType: any, replaceType: any)
	if not self:ownsSpot(spotIndex) or typeof(towerType) ~= "string" or not IdleTowers.Defs[towerType] then
		return
	end
	local def = IdleTowers.Defs[towerType]
	if not self.idle.unlockedTowers[towerType] then
		self:notify(`{def.displayName} n'est pas encore débloquée : invoque-la à l'autel des héros !`, "Error")
		return
	end
	local existing = self.towers[spotIndex]
	if existing and existing.type == towerType then
		self:notify("Cette tour est déjà posée ici", "Error")
		return
	end
	if existing and replaceType ~= existing.type then
		self:notify("Il y a déjà une tour ici : clique dessus puis « Remplacer… »", "Warning")
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
	local tower = self:ownsSpot(spotIndex) and self.towers[spotIndex]
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
	self:saveTower(tower)
end

function PlotGame:sellTower(spotIndex: any)
	if not self:ownsSpot(spotIndex) or not self.towers[spotIndex] then
		return
	end
	local refund = math.floor(self.towers[spotIndex].spent * IdleConfig.SELL_REFUND)
	self:removeTower(spotIndex)
	PlayerData.addCoins(self.player, refund)
	self:notify(`Tour vendue : +{NumberFormat.short(refund)} pièces`, "Success")
end

-- Nombre d'emplacements possédés, compté dans la liste (c'est elle qui fait foi).
function PlotGame:countOwnedSpots(): number
	local count = 0
	for _ in self.idle.ownedSpots do
		count += 1
	end
	return count
end

-- Prix du prochain emplacement, le même pour tous les cadenas (nil si tout est débloqué).
function PlotGame:nextSpotCost(): number?
	local count = self:countOwnedSpots()
	if count >= #PlotLayout.SPOTS then
		return nil
	end
	return PlotLayout.spotCost(count + 1)
end

-- Met à jour les cadenas de la map et l'attribut OwnedSpots (ex. "1,2,3,4,9", lu par PlotUI).
function PlotGame:refreshSpots()
	local list = {}
	for spotIndex = 1, #PlotLayout.SPOTS do
		if self.idle.ownedSpots[tostring(spotIndex)] then
			table.insert(list, spotIndex)
		end
	end
	HubMap.setOwnedSpots(self.plot, self.idle.ownedSpots, self:nextSpotCost())
	self:setAttr("OwnedSpots", table.concat(list, ","))
end

-- Débloque l'emplacement choisi par le joueur, dans n'importe quel ordre.
-- Le prix ne dépend que du nombre d'emplacements déjà possédés : le n-ième coûte spotCost(n).
function PlotGame:buySpot(spotIndex: any)
	if not PlotLayout.isSpotIndex(spotIndex) then
		return
	end
	if self:ownsSpot(spotIndex) then
		self:notify("Cet emplacement est déjà débloqué", "Info")
		return
	end
	local count = self:countOwnedSpots()
	local cost = PlotLayout.spotCost(count + 1)
	if self.data.coins < cost then
		self:notify(`Il te faut {NumberFormat.short(cost)} pièces`, "Error")
		return
	end
	PlayerData.addCoins(self.player, -cost)
	self.idle.ownedSpots[tostring(spotIndex)] = true
	self.idle.unlockedSpots = count + 1
	self:refreshSpots()
	self:syncAttributes()
	self:notify(`Emplacement {spotIndex} débloqué !`, "Success")
end

----------------------------------------------------------------------
-- Machines à sous
----------------------------------------------------------------------

local random = Random.new()

local function rollWeighted(entries, weightOf)
	local total = 0
	for _, entry in entries do
		total += weightOf(entry)
	end
	local roll = random:NextNumber() * total
	for _, entry in entries do
		roll -= weightOf(entry)
		if roll <= 0 then
			return entry
		end
	end
	return entries[#entries]
end

-- Lancers en grand nombre (x1 000, x1 000 000) : on ne lance pas un million de fois. On tire directement
-- COMBIEN de lancers tombent sur chaque rareté, puis sur chaque tour, avec la même loi que des lancers un
-- par un (loi binomiale). Jusqu'à EXACT_SPINS essais : un tirage par essai (exact). Au-delà : loi normale
-- (ou loi de Poisson quand il n'y a que quelques succès attendus). Jamais négatif, et le total est
-- toujours exact : la dernière case reçoit ce qui reste.
local EXACT_SPINS = 1000

-- Nombre au hasard selon une loi normale (moyenne 0, écart-type 1), méthode de Box-Muller.
local function normalRoll(): number
	local u1 = 1 - random:NextNumber() -- entre 0 (exclu) et 1 : pas de log(0)
	local u2 = random:NextNumber()
	return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
end

-- Loi de Poisson (méthode de Knuth) : pour une moyenne petite (< 30).
local function poissonRoll(mean: number): number
	local limit, count, product = math.exp(-mean), 0, random:NextNumber()
	while product > limit do
		count += 1
		product *= random:NextNumber()
	end
	return count
end

-- Nombre de succès sur `trials` essais qui réussissent chacun avec la chance `chance` (0 à 1).
local function binomialRoll(trials: number, chance: number): number
	if trials <= 0 or chance <= 0 then
		return 0
	elseif chance >= 1 then
		return trials
	elseif trials <= EXACT_SPINS then
		local hits = 0
		for _ = 1, trials do
			if random:NextNumber() < chance then
				hits += 1
			end
		end
		return hits
	end
	local mean = trials * chance
	if mean < 30 then
		return math.min(trials, poissonRoll(mean))
	elseif trials - mean < 30 then
		return math.max(0, trials - poissonRoll(trials - mean))
	end
	local roll = math.floor(mean + math.sqrt(mean * (1 - chance)) * normalRoll() + 0.5)
	return math.clamp(roll, 0, trials)
end

-- Répartit `total` lancers entre des cases selon leurs poids : { [i] = nombre }, somme = total exactement.
local function splitRolls(total: number, weights: { number }): { number }
	local counts = table.create(#weights, 0)
	local last = 0 -- dernière case qui peut recevoir quelque chose
	local weightLeft = 0
	for i, weight in weights do
		if weight > 0 then
			last = i
			weightLeft += weight
		end
	end
	local left = total
	for i, weight in weights do
		if weight <= 0 then
			continue
		elseif i == last then
			counts[i] = left
			break
		end
		local got = binomialRoll(left, weight / weightLeft)
		counts[i] = got
		left -= got
		weightLeft -= weight
	end
	return counts
end

-- Inventaire visible par le client (attributs du joueur).
function PlotGame:publishInventory()
	local player = self.player
	local unlocked, dupes = {}, {}
	for _, towerType in IdleTowers.ORDER do
		if self.idle.unlockedTowers[towerType] then
			table.insert(unlocked, towerType)
		end
		local count = self.idle.towerDupes[towerType]
		if count and count > 0 then
			table.insert(dupes, `{towerType}:{count}`)
		end
	end
	player:SetAttribute("UnlockedTowers", table.concat(unlocked, ","))
	player:SetAttribute("TowerDupes", table.concat(dupes, ","))
	player:SetAttribute("Bonuses", table.concat(self.idle.bonuses, ","))
	-- Plus d'attribut TowerSpinTier : le client calcule le palier depuis le record (attribut HighestWave
	-- de la parcelle, IdleConfig.towerSpinTier), exactement comme le serveur.
	player:SetAttribute("LastBonusSpinAt", self.idle.lastBonusSpinAt)
end

function PlotGame:sendResult(result)
	if self.player.Parent then
		Remotes.get("MachineResult"):FireClient(self.player, result)
	end
end

-- Machine à tours : `count` lancers payés en pièces (1, 10, 100... voir IdleConfig.TOWER_SPIN_BULKS ;
-- rien = 1). Le serveur vérifie tout : nombre proposé ET débloqué à ton record, pièces suffisantes.
-- Les chances sont celles du palier de ton RECORD (idle.highestWave), celles affichées par l'autel.
-- La 1re fois qu'une tour tombe, elle est débloquée ; ensuite chaque exemplaire est un doublon.
-- Envoie (et renvoie, pour les tests) le résultat :
--   { machine = "Tower", count, tower, rarity, isNew, dupes, results = { { tower, rarity, count, isNew } } }
-- tower/rarity/isNew/dupes = la tour la plus marquante (la plus rare ; à rareté égale, une nouvelle) ;
-- results = une ligne par tour obtenue, de la plus rare à la plus commune. nil si l'achat est refusé.
function PlotGame:spinTower(count: any)
	if count == nil then
		count = 1
	end
	local record = self.idle.highestWave
	if not IdleConfig.towerSpinBulkAvailable(record, count) then
		for _, bulk in IdleConfig.TOWER_SPIN_BULKS do
			if bulk.count == count then
				self:notify(`Atteins la vague {bulk.minWave} pour lancer x{NumberFormat.short(count)} d'un coup`, "Error")
				return nil
			end
		end
		self:notify("Nombre de lancers invalide", "Error")
		return nil
	end
	local cost = IdleConfig.towerSpinCost(record, count)
	if self.data.coins < cost then
		self:notify(`Il te faut {NumberFormat.short(cost)} pièces`, "Error")
		return nil
	end
	PlayerData.addCoins(self.player, -cost)

	-- Combien de lancers par rareté, puis par tour (voir splitRolls).
	local odds = IdleConfig.TOWER_SPIN_TIERS[IdleConfig.towerSpinTier(record)].odds
	local rarityWeights = {}
	for index, rarity in IdleConfig.RARITY_ORDER do
		rarityWeights[index] = odds[rarity] or 0
	end
	local perRarity = splitRolls(count, rarityWeights)

	local results = {}
	for index = #IdleConfig.RARITY_ORDER, 1, -1 do -- de la plus rare à la plus commune
		local rarity = IdleConfig.RARITY_ORDER[index]
		local choices = IdleTowers.ofRarity(rarity)
		local perTower = splitRolls(perRarity[index], table.create(#choices, 1)) -- chaque tour a la même chance
		for i, towerType in choices do
			local got = perTower[i]
			if got > 0 then
				local isNew = not self.idle.unlockedTowers[towerType]
				local dupes = if isNew then got - 1 else got
				if isNew then
					self.idle.unlockedTowers[towerType] = true
				end
				if dupes > 0 then
					self.idle.towerDupes[towerType] = (self.idle.towerDupes[towerType] or 0) + dupes
				end
				table.insert(results, { tower = towerType, rarity = rarity, count = got, isNew = isNew })
			end
		end
	end

	-- La plus marquante : la plus rare (la 1re de la liste) ; à rareté égale, une tour débloquée.
	local notable = results[1]
	for _, entry in results do
		if entry.rarity == notable.rarity and entry.isNew and not notable.isNew then
			notable = entry
		end
	end

	self:publishInventory()
	local result = {
		machine = "Tower",
		count = count,
		tower = notable.tower,
		rarity = notable.rarity,
		isNew = notable.isNew,
		dupes = self.idle.towerDupes[notable.tower] or 0,
		results = results,
	}
	self:sendResult(result)
	return result
end

-- Tire un bonus et le met dans l'inventaire (utilisé par le lancer en pièces et par l'achat Robux).
function PlotGame:grantBonusSpin(source: string)
	local bonus = rollWeighted(IdleConfig.BONUSES, function(entry)
		return entry.chance
	end)
	if #self.idle.bonuses < IdleConfig.MAX_BONUS_INVENTORY then
		table.insert(self.idle.bonuses, bonus.id)
	end
	self:publishInventory()
	self:sendResult({ machine = "Bonus", bonus = bonus.id, source = source })
end

-- Machine à bonus, lancer payé en pièces : 1 toutes les 30 minutes.
function PlotGame:spinBonusWithCoins()
	local now = os.time()
	local waitLeft = self.idle.lastBonusSpinAt + IdleConfig.BONUS_SPIN_COOLDOWN - now
	if waitLeft > 0 then
		self:notify(`Prochain lancer en pièces dans {math.ceil(waitLeft / 60)} min`, "Warning")
		return
	end
	if #self.idle.bonuses >= IdleConfig.MAX_BONUS_INVENTORY then
		self:notify("Ton inventaire de bonus est plein", "Error")
		return
	end
	local cost = IdleConfig.bonusSpinCost(self.idle.highestWave)
	if self.data.coins < cost then
		self:notify(`Il te faut {NumberFormat.short(cost)} pièces`, "Error")
		return
	end
	PlayerData.addCoins(self.player, -cost)
	self.idle.lastBonusSpinAt = now
	self:grantBonusSpin("Coins")
end

-- Pose un bonus de l'inventaire sur une tour (remplace le bonus déjà posé, qui est perdu).
function PlotGame:applyBonus(spotIndex: any, bonusId: any)
	local tower = self:ownsSpot(spotIndex) and self.towers[spotIndex]
	if not tower or typeof(bonusId) ~= "string" or not IdleConfig.BONUS_BY_ID[bonusId] then
		return
	end
	local inventoryIndex = table.find(self.idle.bonuses, bonusId)
	if not inventoryIndex then
		return
	end
	table.remove(self.idle.bonuses, inventoryIndex)
	tower.bonus = bonusId
	tower.model:SetAttribute("Bonus", bonusId)
	self:saveTower(tower)
	self:publishInventory()
	self:notify(`Bonus {IdleConfig.BONUS_BY_ID[bonusId].displayName} posé !`, "Success")
end

-- Le joueur quitte le serveur : on libère la parcelle (sa progression est déjà dans ses données).
function PlotGame:destroy()
	self.towerFolder:Destroy()
	self:clearEnemies()
	table.clear(self.drops)
	self.dropCount = 0
	HubMap.resetSpots(self.plot)
	-- Paquet vide : les clients effacent les ennemis de cette parcelle.
	Remotes.get("PlotSync"):FireAllClients(self.index, buffer.create(0), 0)
	for name in self.attributeCache do
		self.plot.folder:SetAttribute(name, nil)
	end
end

return PlotGame

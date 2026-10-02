-- Un NIVEAU en cours (règles et chiffres : Shared/Levels.luau).
-- Une instance par joueur qui joue un niveau, dans sa zone de combat (Hub/LevelArena.luau), créée et arrêtée par
-- Hub/LevelsService.luau.
--
-- LevelGame HÉRITE de Combat (Hub/Combat.luau : visée, projectiles, zones, carreau perçant, rayon, contrôles,
-- fragilité, feu des flèches, paquets réseau PlotSync / PlotShots). Ici, les règles autour du combat :
--   * le chemin est celui de la carte du niveau (self.layout) ;
--   * les tours se posent OÙ ON VEUT (Levels.checkPlacement), avec l'OR du niveau, et s'améliorent avec lui ;
--   * les monstres arrivent en un flot continu, de plus en plus serré et résistant (Levels.buildQueue) ; un
--     monstre tué donne son or tout de suite ;
--   * un monstre qui atteint le château coûte des VIES (Levels.ENEMY.leak) ; à 0, le niveau est perdu ;
--   * le niveau est gagné quand tout le flot est éliminé ;
--   * rien n'est sauvegardé ici : les récompenses sont données par LevelsService (onEnd).
-- Ce fichier tourne aussi hors de Studio (tools/levels, avec ses imitations de Roblox) : pas d'autre objet Roblox
-- que le dossier des tours et leurs modèles (IdleTowerModel).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enemies = require(Shared.Enemies)
local IdleConfig = require(Shared.IdleConfig)
local IdleTowers = require(Shared.IdleTowers)
local Levels = require(Shared.Levels)
local Combat = require(script.Parent.Combat)
local IdleTowerModel = require(script.Parent.IdleTowerModel)

local ENEMY_INDEX = {}
for index, name in Enemies.ORDER do
	ENEMY_INDEX[name] = index
end

-- Petite marge pour comparer des heures de la simulation.
local TIME_EPSILON = 1e-6

local LevelGame = setmetatable({}, { __index = Combat })
LevelGame.__index = LevelGame

-- arena = { index (numéro pour les paquets : Levels.arenaIndex), folder (dossier de la zone : ses attributs sont
--           lus par les clients), cframe (centre de la zone), map (nom de la carte) }
-- options = { level, unlocked = { [type] = true }, training = { [type] = niveau d'entraînement },
--             startingTower = vrai pour poser la tour de départ offerte (niveau 1),
--             onEnd = function(game, won) appelée une seule fois à la fin }
function LevelGame.new(arena, player, options)
	local self = setmetatable({}, LevelGame)
	self.plot = arena
	self.index = arena.index
	self.cframe = arena.cframe
	self.player = player
	self.layout = Levels.geometry(arena.map)

	self.level = options.level
	self.definition = Levels.definition(options.level)
	self.unlocked = options.unlocked or {}
	self.training = options.training or {}
	self.onEnd = options.onEnd

	-- Champs du combat (Combat.luau).
	self.enemies = {}
	self.towers = {} -- [id] = tour
	self.shots = {}
	self.impacts = {}
	self.firePatches = {}
	self.nextId = 0
	self.attributeCache = {}
	self.lastSyncEmpty = false
	self.clock = 0
	self.simSpeed = 1
	self.kills = 0

	-- Règles du niveau.
	self.state = "Running" -- "Running" | "Won" | "Lost"
	self.gold = self.definition.gold
	self.lives = self.definition.lives
	self.queue = Levels.buildQueue(options.level)
	self.queueIndex = 1
	self.streamSeconds = math.max(1, self.queue[#self.queue].at) -- heure de sortie du dernier monstre
	self.leaked = 0
	self.usedTowers = {} -- [type] = true : types de tours posés pendant ce niveau (entraînement gagné à la fin)
	self.goldEarned = 0
	self.goldSpent = 0

	self.towerFolder = Instance.new("Folder")
	self.towerFolder.Name = "Towers"
	self.towerFolder.Parent = arena.folder

	if options.startingTower and self.unlocked[Levels.STARTING_TOWER] then
		local spot = self.layout.map.spots[1]
		self:createTower(Levels.STARTING_TOWER, 1, 0, spot)
	end
	self:setAttr("Perks", Levels.perkKeys(self.training))
	self:setAttr("Training", Levels.encodeTraining(self.training))
	self:syncAttributes()
	return self
end

-- Attributs de la zone, lus par les clients (LevelsUI : or, vies, avancée ; PlotRenderer : Wave = style des monstres,
-- State, SimSpeed). Progress = avancée du flot dans le temps, en % (0 = début, 100 = le dernier monstre est sorti) :
-- les monstres sont de plus en plus forts tout du long, la barre du joueur passe du vert au rouge.
function LevelGame:syncAttributes()
	local alive = 0
	for _, enemy in self.enemies do
		if not enemy.dead then
			alive += 1
		end
	end
	self:setAttr("Level", self.level)
	self:setAttr("Wave", self.level)
	self:setAttr("State", self.state)
	self:setAttr("SimSpeed", self.simSpeed)
	self:setAttr("Gold", math.floor(self.gold))
	self:setAttr("Lives", self.lives)
	self:setAttr("Left", alive + (#self.queue - self.queueIndex + 1))
	self:setAttr("Total", #self.queue)
	self:setAttr("Progress", math.floor(math.clamp(self.clock / self.streamSeconds, 0, 1) * 100))
end

-- Point du chemin de la carte (dans le monde) à `distance` studs du départ.
function LevelGame:pathPoint(distance: number): Vector3
	return self.cframe:PointToWorldSpace((self.layout.pointAt(math.min(distance, self.layout.PATH_LENGTH))))
end

function LevelGame:spawnEnemy(item)
	local def = Enemies.Defs[item.enemy]
	table.insert(self.enemies, {
		id = self:newId(),
		typeIndex = ENEMY_INDEX[item.enemy],
		enemyType = item.enemy,
		def = def,
		speedScale = IdleConfig.enemySpeedFactor(item.enemy),
		health = item.health,
		maxHealth = item.health,
		reward = item.reward,
		distance = 0,
		position = self:pathPoint(0),
		controlSource = nil,
		controlFactor = 0,
		controlUntil = 0,
		fatigue = nil,
		fragility = 0,
		fragileUntil = 0,
		pending = 0,
		inFlight = 0,
		dead = false,
		spawnedAt = self.clock,
	})
end

-- Dégâts sur un monstre. fragile = ces dégâts profitent de la fragilité du Totem de givre (toutes les tours sauf
-- celles marquées ignoresFragility) : x (1 + fragilité) tant qu'elle dure. Tué, son or va tout de suite dans la
-- bourse du niveau.
function LevelGame:damageEnemy(enemy, amount: number, fragile: boolean?)
	if enemy.dead then
		return
	end
	if fragile and self.clock < enemy.fragileUntil then
		amount *= 1 + enemy.fragility
	end
	enemy.health -= amount
	if enemy.health <= 0 then
		enemy.dead = true
		self.kills += 1
		self.gold += enemy.reward
		self.goldEarned += enemy.reward
	end
end

function LevelGame:statsOf(tower)
	return Levels.towerStats(tower.type, tower.level, self.training[tower.type])
end

-- Vitesse actuelle en fraction de la vitesse normale : type x contrôle (0 si étourdi). Même calcul que Combat.
local function speedFactorOf(enemy, now: number): number
	local controlFactor = if now < enemy.controlUntil then 1 - enemy.controlFactor else 1
	return enemy.speedScale * controlFactor
end

-- Fin du niveau (une seule fois) : plus rien ne bouge, LevelsService donne les récompenses.
function LevelGame:finish(won: boolean)
	if self.state ~= "Running" then
		return
	end
	self.state = if won then "Won" else "Lost"
	-- Les ennemis encore là disparaissent (défaite), les projectiles et le feu aussi, les rayons s'éteignent.
	table.clear(self.enemies)
	table.clear(self.impacts)
	table.clear(self.firePatches)
	for _, tower in self.towers do
		if tower.beamTarget or (tower.beamShownId or 0) ~= 0 then
			tower.beamTarget = nil
			tower.beamTime = 0
			self:showBeam(tower, nil, 0)
		end
	end
	if self.onEnd then
		self.onEnd(self, won)
	end
end

-- Part du flot éliminée (0 à 1) : monstres tués / monstres du niveau.
function LevelGame:progress(): number
	return if #self.queue > 0 then math.clamp(self.kills / #self.queue, 0, 1) else 0
end

-- Un pas de simulation de dt secondes (horloge de la simulation).
function LevelGame:simulate(dt: number)
	if self.state ~= "Running" then
		return
	end
	self.clock += dt
	local now = self.clock

	-- Apparitions : chaque monstre de la file à son heure.
	while self.queueIndex <= #self.queue and #self.enemies < IdleConfig.MAX_ENEMIES do
		local item = self.queue[self.queueIndex]
		if item.at > now + TIME_EPSILON then
			break
		end
		self.queueIndex += 1
		self:spawnEnemy(item)
	end

	-- Déplacements. Un monstre au bout du chemin coûte des vies.
	local pathLength = self.layout.PATH_LENGTH
	for _, enemy in self.enemies do
		if enemy.dead then
			continue
		end
		local speed = enemy.def.speed * IdleConfig.ENEMY_SPEED_MULTIPLIER * speedFactorOf(enemy, now)
		enemy.distance += speed * dt
		if enemy.distance >= pathLength then
			enemy.dead = true
			self.leaked += 1
			self.lives = math.max(0, self.lives - Levels.ENEMY[enemy.enemyType].leak)
			if self.lives <= 0 then
				self:finish(false)
				return
			end
			continue
		end
		enemy.position = self.cframe:PointToWorldSpace((self.layout.pointAt(enemy.distance)))
	end

	-- Projectiles qui arrivent, tours, zones de feu : Combat.luau.
	self:resolveImpacts(now)
	for _, tower in self.towers do
		local stats = self:statsOf(tower)
		if stats.kind == "Beam" then
			self:beamStep(tower, stats, dt)
			continue
		end
		tower.cooldown -= dt
		if tower.cooldown <= 0 then
			local attacked = self:towerAttack(tower, stats, now)
			tower.cooldown = if attacked then stats.cooldown else 0
		end
	end
	self:burnFires(now)

	for i = #self.enemies, 1, -1 do
		if self.enemies[i].dead then
			table.remove(self.enemies, i)
		end
	end

	if self.queueIndex > #self.queue and #self.enemies == 0 then
		self:finish(true)
	end
end

-- Appelé à chaque image : simSpeed pas de dt (bouton x2).
function LevelGame:step(dt: number)
	for _ = 1, self.simSpeed do
		self:simulate(dt)
	end
	self:syncAttributes()
end

-- 1 = vitesse normale, IdleConfig.SPEED_PASS_FACTOR = x2. Toute autre valeur = 1.
function LevelGame:setSimSpeed(speed: any)
	self.simSpeed = if speed == IdleConfig.SPEED_PASS_FACTOR then IdleConfig.SPEED_PASS_FACTOR else 1
end

----------------------------------------------------------------------
-- Tours : pose libre, amélioration, vente (toujours décidées ici, jamais par le client)
----------------------------------------------------------------------

-- Positions locales des tours posées (pour Levels.checkPlacement), sauf celle de l'id donné.
function LevelGame:towerPositions(): { Vector3 }
	local positions = {}
	for _, tower in self.towers do
		table.insert(positions, tower.localPosition)
	end
	return positions
end

function LevelGame:createTower(towerType: string, level: number, spent: number, localPosition: Vector3)
	local id = self:newId()
	local ground = Vector3.new(localPosition.X, 0, localPosition.Z)
	-- Position de combat (portées, départ des tirs) : un peu au-dessus du sol, comme sur une parcelle.
	local combat = self.cframe * CFrame.new(ground + Vector3.new(0, 0.3, 0))
	local model = IdleTowerModel.create(towerType, self.cframe * CFrame.new(ground), self.towerFolder, {
		-- SpotIndex : PlotRenderer met l'étiquette « Niv. X » aux tours qui en ont un.
		SpotIndex = id,
		TowerId = id,
		PlotIndex = self.index,
		Level = level,
		Spent = spent,
	})
	-- Tour évoluée par l'entraînement : anneau, fanions, étoiles (Levels.evolutionStage).
	IdleTowerModel.addEvolution(model, Levels.evolutionStage(towerType, self.training[towerType]))
	local tower = {
		id = id,
		spotIndex = id, -- (Combat : identifie la tour pour ses zones de feu)
		type = towerType,
		level = level,
		spent = spent,
		localPosition = ground,
		position = combat.Position,
		cooldown = 0,
		model = model,
	}
	self.towers[id] = tower
	self.usedTowers[towerType] = true
	return tower
end

-- Pose une tour au point local `localPosition`. Renvoie (vrai, nil, la tour) ou (faux, raison).
function LevelGame:placeTower(towerType: string, localPosition: Vector3): (boolean, string?, any)
	if self.state ~= "Running" then
		return false, "Le niveau est terminé"
	end
	local def = IdleTowers.Defs[towerType]
	if not def then
		return false, "Tour inconnue"
	end
	if not self.unlocked[towerType] then
		return false, `{def.displayName} n'est pas encore à toi : achète cette tour dans la boutique`
	end
	local copies = IdleTowers.countCopies(self.towers)
	if (copies[towerType] or 0) >= Levels.maxCopies(towerType) then
		return false, `Maximum {Levels.maxCopies(towerType)} {def.displayName} par niveau`
	end
	local cost = Levels.placeCost(towerType)
	if self.gold < cost then
		return false, "Pas assez d'or"
	end
	local ok, reason = Levels.checkPlacement(self.layout.name, localPosition, self:towerPositions())
	if not ok then
		return false, reason
	end
	self.gold -= cost
	self.goldSpent += cost
	return true, nil, self:createTower(towerType, 1, cost, localPosition)
end

function LevelGame:upgradeTower(towerId: number): (boolean, string?)
	local tower = self.towers[towerId]
	if self.state ~= "Running" or not tower then
		return false, nil
	end
	local cost = Levels.upgradeCost(tower.type, tower.level)
	if not cost then
		return false, "Niveau maximum atteint"
	end
	if self.gold < cost then
		return false, "Pas assez d'or"
	end
	self.gold -= cost
	self.goldSpent += cost
	tower.level += 1
	tower.spent += cost
	tower.model:SetAttribute("Level", tower.level)
	tower.model:SetAttribute("Spent", tower.spent)
	return true, nil
end

-- Vend la tour : SELL_REFUND de l'or dépensé. Renvoie (vrai, or rendu) ou (faux).
function LevelGame:sellTower(towerId: number): (boolean, number?)
	local tower = self.towers[towerId]
	if self.state ~= "Running" or not tower then
		return false, nil
	end
	local refund = math.floor(tower.spent * Levels.SELL_REFUND)
	if tower.beamTarget or (tower.beamShownId or 0) ~= 0 then
		self:showBeam(tower, nil, 0)
	end
	self.towers[towerId] = nil
	tower.model:Destroy()
	self.gold += refund
	return true, refund
end

-- Le niveau est rangé (le joueur repart, relance un niveau ou quitte le jeu) : tours effacées, attributs remis à
-- zéro. Le paquet « Clear » qui efface les monstres chez le client est envoyé par LevelsService.
function LevelGame:destroy()
	self.state = if self.state == "Running" then "Lost" else self.state
	table.clear(self.enemies)
	table.clear(self.impacts)
	table.clear(self.firePatches)
	table.clear(self.towers)
	self.towerFolder:Destroy()
	for name in self.attributeCache do
		self.plot.folder:SetAttribute(name, nil)
	end
end

return LevelGame

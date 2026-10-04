-- Le CAMP D'ENTRAÎNEMENT d'un joueur, sur sa parcelle (règles dans Shared/Levels.luau, « LE CAMP SUR LA
-- PARCELLE » ; lancé et rangé par Hub/Camp.luau).
-- Les tours mises dans les emplacements d'entraînement sont posées pour de vrai sur des socles de la parcelle, et
-- des CIBLES ROULANTES suivent le chemin : les tours leur tirent dessus avec le vrai combat des niveaux (CampGame
-- hérite de LevelGame, donc de Combat : mêmes tirs, mêmes paquets réseau, même affichage par PlotRenderer). On
-- voit donc ses tours s'entraîner, avec les pouvoirs que leurs évolutions leur ont donnés.
-- Rien ne se gagne ni ne se perd ici : une cible détruite ne rapporte rien, une cible qui arrive au bout du chemin
-- s'en va. L'XP d'entraînement vient du temps passé dans l'emplacement (Levels.accrueTraining), pas des cibles.
-- Ce fichier tourne aussi hors de Studio (tools/levels).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enemies = require(Shared.Enemies)
local IdleConfig = require(Shared.IdleConfig)
local IdleTowers = require(Shared.IdleTowers)
local Levels = require(Shared.Levels)
local PlotLayout = require(Shared.PlotLayout)
local Remotes = require(Shared.Remotes)
local IdleTowerModel = require(script.Parent.IdleTowerModel)
local LevelGame = require(script.Parent.LevelGame)

local TIME_EPSILON = 1e-6

local CampGame = setmetatable({}, { __index = LevelGame })
CampGame.__index = CampGame

-- Le chemin d'un camp est celui de la parcelle (LevelGame le lit dans self.layout : un seul couloir).
local LAYOUT = {
	name = "Camp",
	PATH_LENGTH = PlotLayout.PATH_LENGTH,
	pointAt = PlotLayout.pointAt,
	lanes = { { PATH_LENGTH = PlotLayout.PATH_LENGTH, pointAt = PlotLayout.pointAt } },
}

-- Vitesse actuelle en fraction de la vitesse normale : type x contrôle (0 si étourdi). Même calcul que Combat.
local function speedFactorOf(enemy, now: number): number
	local controlFactor = if now < enemy.controlUntil then 1 - enemy.controlFactor else 1
	return enemy.speedScale * controlFactor
end

-- plot = parcelle du joueur (Hub/HubMap.luau : { index, folder, spots, ... }) ; levels = ses données des niveaux
-- (data.levels : emplacements, XP, tours débloquées).
function CampGame.new(plot, player, levels)
	local self = setmetatable({}, CampGame)
	self.plot = plot
	self.index = plot.index
	self.cframe = PlotLayout.cframe(plot.index)
	self.player = player
	self.layout = LAYOUT
	self.training = {}

	-- Champs du combat (Combat.luau) et ceux que LevelGame lit.
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
	self.state = "Running"
	self.gold = 0
	self.goldEarned = 0
	self.usedTowers = {}
	self.members = { self } -- (joueurs d'une partie, LevelGame : ici le camp lui-même, qui reçoit l'or des cibles : 0)

	self.slotTowers = {} -- [numéro d'emplacement d'entraînement] = tour
	self.nextTargetAt = 0

	self.towerFolder = Instance.new("Folder")
	self.towerFolder.Name = "Towers"
	self.towerFolder.Parent = plot.folder

	-- Attributs de la parcelle lus par les clients : Camp (PlotRenderer dessine des cibles, PlotBoard affiche le
	-- camp), State et Wave (PlotRenderer), OwnerUserId (panneaux de la parcelle).
	self:setAttr("OwnerUserId", player.UserId)
	self:setAttr("Camp", true)
	self:setAttr("SimSpeed", 1)
	self:setAttr("Wave", 1)
	self:setAttr("State", "Running")
	self:refresh(levels)
	return self
end

-- Pose la tour de cet emplacement d'entraînement sur son socle. stage = ses évolutions (0 à 3).
function CampGame:createSlotTower(slotIndex: number, towerType: string, stage: number)
	local spot = PlotLayout.SPOTS[Levels.CAMP.SPOTS[slotIndex]]
	local id = self:newId()
	local ground = Vector3.new(spot.X, 0, spot.Z)
	-- Position de combat un peu au-dessus du sol ; le modèle, lui, est posé sur le socle.
	local combat = self.cframe * CFrame.new(ground + Vector3.new(0, 0.3, 0))
	local model = IdleTowerModel.create(towerType, self.cframe * CFrame.new(ground + Vector3.new(0, PlotLayout.SPOT_PAD_HEIGHT, 0)), self.towerFolder, {
		TowerId = id,
		PlotIndex = self.index,
		CampSlot = slotIndex, -- (pas de SpotIndex : pas d'étiquette « Niv. X »)
		Level = 1,
		Spent = 0,
	})
	IdleTowerModel.addEvolution(model, stage)
	local tower = {
		id = id,
		spotIndex = id, -- (Combat : identifie la tour pour ses zones de feu)
		slotIndex = slotIndex,
		type = towerType,
		level = 1,
		spent = 0,
		stage = stage,
		localPosition = ground,
		position = combat.Position,
		cooldown = 0,
		model = model,
	}
	self.towers[id] = tower
	self.slotTowers[slotIndex] = tower
	return tower
end

function CampGame:removeSlotTower(slotIndex: number)
	local tower = self.slotTowers[slotIndex]
	if not tower then
		return
	end
	if tower.beamTarget or (tower.beamShownId or 0) ~= 0 then
		self:showBeam(tower, nil, 0)
	end
	self.slotTowers[slotIndex] = nil
	self.towers[tower.id] = nil
	tower.model:Destroy()
end

-- Met le camp d'accord avec les données du joueur : une tour par emplacement occupé, avec son entraînement du
-- moment. Le modèle n'est refait que si la tour ou ses évolutions changent (les dégâts suivent tout seuls :
-- statsOf lit self.training à chaque tir). Renvoie vrai si une tour a été posée, retirée ou refaite.
function CampGame:refresh(levels): boolean
	self.training = Levels.trainingLevels(levels)
	-- Effets débloqués par l'entraînement, pour l'affichage (PlotRenderer : feu des flèches, carreau perçant), comme
	-- dans un niveau.
	self:setAttr("Perks", Levels.perkKeys(self.training))
	local changed = false
	for slotIndex = 1, #Levels.CAMP.SPOTS do
		local slot = levels.slots[slotIndex]
		local wanted = if slot and slot.tower ~= "" and levels.towers[slot.tower] then slot.tower else nil
		local stage = if wanted then Levels.evolutionStage(wanted, self.training[wanted]) else 0
		local tower = self.slotTowers[slotIndex]
		if tower and (tower.type ~= wanted or tower.stage ~= stage) then
			self:removeSlotTower(slotIndex)
			tower = nil
			changed = true
		end
		if wanted and not tower then
			self:createSlotTower(slotIndex, wanted, stage)
			changed = true
		end
	end
	return changed
end

-- PV d'une cible : TARGET_SECONDS secondes de tir de toutes les tours du camp réunies, à leurs dégâts de BASE
-- (sans entraînement : une tour entraînée ou évoluée détruit donc les cibles plus vite).
function CampGame:targetHealth(): number
	local dps = 0
	for _, tower in self.towers do
		dps += IdleTowers.dpsOf(Levels.towerStats(tower.type, 1, 0))
	end
	return math.max(Levels.CAMP.TARGET_MIN_HEALTH, math.floor(dps * Levels.CAMP.TARGET_SECONDS + 0.5))
end

-- Une cible d'entraînement à `distance` studs du début du chemin (0 si absent). Elle roule lentement.
function CampGame:spawnTarget(distance: number?)
	self:spawnEnemy({ enemy = "Normal", health = self:targetHealth(), reward = 0 })
	local target = self.enemies[#self.enemies]
	target.speedScale *= Levels.CAMP.TARGET_SPEED
	if distance and distance > 0 then
		target.distance = distance
		target.position = self:pathPoint(distance)
	end
end

-- Un pas de simulation de dt secondes.
function CampGame:simulate(dt: number)
	self.clock += dt
	local now = self.clock

	-- Cibles roulantes, tant qu'une tour s'entraîne : une nouvelle au début du chemin toutes les TARGET_GAP
	-- secondes. Chemin vide (le camp démarre, ou la première tour vient d'être posée) : des cibles tout le long du
	-- chemin tout de suite, au même écart, pour que les tours tirent sans attendre qu'elles arrivent du fond.
	if next(self.towers) ~= nil then
		if #self.enemies == 0 then
			local speed = Enemies.Defs.Normal.speed * IdleConfig.ENEMY_SPEED_MULTIPLIER * IdleConfig.enemySpeedFactor("Normal") * Levels.CAMP.TARGET_SPEED
			local spacing = math.max(8, speed * Levels.CAMP.TARGET_GAP)
			local distance = self.layout.PATH_LENGTH - spacing
			while distance > 0 and #self.enemies < Levels.CAMP.MAX_TARGETS do
				self:spawnTarget(distance)
				distance -= spacing
			end
			self.nextTargetAt = now + Levels.CAMP.TARGET_GAP
		elseif now + TIME_EPSILON >= self.nextTargetAt and #self.enemies < Levels.CAMP.MAX_TARGETS then
			self.nextTargetAt = now + Levels.CAMP.TARGET_GAP
			self:spawnTarget()
		end
	end

	-- Déplacements. Au bout du chemin, la cible s'en va (rien n'est perdu).
	local pathLength = self.layout.PATH_LENGTH
	for _, enemy in self.enemies do
		if enemy.dead then
			continue
		end
		enemy.distance += enemy.def.speed * IdleConfig.ENEMY_SPEED_MULTIPLIER * speedFactorOf(enemy, now) * dt
		if enemy.distance >= pathLength then
			enemy.dead = true
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
end

-- Appelé à chaque image du serveur (Hub/init.luau).
function CampGame:step(dt: number)
	self:simulate(dt)
end

-- Le camp est rangé (le joueur part) : tours et cibles effacées, attributs de la parcelle remis à zéro, et un
-- paquet « Clear » pour que les clients effacent les cibles.
function CampGame:destroy()
	for slotIndex in self.slotTowers do
		self:removeSlotTower(slotIndex)
	end
	table.clear(self.enemies)
	table.clear(self.impacts)
	table.clear(self.firePatches)
	table.clear(self.towers)
	self.towerFolder:Destroy()
	Remotes.get("PlotSync"):FireAllClients(self.index, buffer.create(0), 0, "Clear")
	for name in self.attributeCache do
		self.plot.folder:SetAttribute(name, nil)
	end
end

return CampGame

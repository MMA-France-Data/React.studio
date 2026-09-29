-- Simulation du mode infini sur une parcelle (une instance par joueur).
--
-- Impossible de perdre : si UN SEUL ennemi atteint le bout du chemin, la vague est ratée, on redescend
-- d'une vague et on réessaie (pas de PV de base). Vague réussie -> vague suivante. On oscille donc
-- autour de sa vague maximale.
--
-- Les ennemis n'existent que sous forme de données côté serveur. Les clients reçoivent leur
-- position quelques fois par seconde (paquet binaire compact) et les affichent eux-mêmes :
-- 6 parcelles pleines d'ennemis ne font pas ramer le serveur.
--
-- Pass Vitesse x2 (Config.GamePasses.SPEED_X2, allumé par Hub/init.luau) : toute la simulation de la
-- parcelle tourne deux fois plus vite (PlotGame:step fait 2 pas de dt par image). Les temps (apparitions,
-- ralentissements, entractes) se comptent sur l'horloge de la simulation, self.clock, pas sur os.clock().
-- L'attribut « SimSpeed » du dossier de la parcelle (1 ou 2) dit aux clients d'avancer les ennemis 2 fois
-- plus vite entre deux paquets ; « NextWaveAt » reste une heure réelle (compte à rebours juste).
--
-- Pass Pièces x2 (Config.GamePasses.COINS_X2, appliqué par Hub/init.luau) : les pièces lâchées par les
-- ennemis tués sont multipliées par PlotGame.COINS_PASS_FACTOR, en plus du bonus de renaissance
-- (voir damageEnemy). L'attribut « CoinMultiplier » du dossier de la parcelle vaut 1 ou 2.
--
-- Combat (détails dans la partie « Combat ») :
--   tirs instantanés : Totem de givre, Mage des tempêtes, Oracle de la foudre ;
--   projectiles (Archer, Catapulte, Baliste, Trébuchet) : la tour vise l'endroit où SERA l'ennemi quand le
--     projectile arrivera, et les dégâts tombent à l'impact (self.impacts, sur l'horloge de la simulation) ;
--   flèches enflammées : zones de feu au sol (self.firePatches) ;
--   rayon continu : Sorcier des arcanes (beamStep), publié aux clients par les attributs « BeamTarget »
--     (id de l'ennemi visé, 0 = éteint) et « BeamRamp » (montée actuelle, arrondie à 0,5) de sa tour.
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
-- le client avance l'ennemi à vitesse de Enemies.luau x ENEMY_SPEED_MULTIPLIER x ce facteur
-- x l'attribut « SimSpeed » de la parcelle. Le paquet ne contient PAS le x2 du pass : le client multiplie.
local ENEMY_BYTES = 11
-- Taille d'un tir : départ 3xf32, arrivée 3xf32, type u8, rayon u8, vol u8 (même format dans PlotRenderer).
-- « vol » = temps de vol qui RESTE quand le paquet part, en centièmes de seconde de simulation (0 = tir
-- instantané, 255 = 2,55 s au plus, voir IdleTowers.MAX_FLIGHT_TIME). Les tirs partent par paquets
-- (IdleConfig.SHOTS_RATE fois par seconde) : un projectile lancé juste avant l'envoi a encore presque tout
-- son vol, un autre lancé juste après le paquet précédent en a déjà fait une partie. Le client anime le
-- projectile jusqu'au point d'impact en vol / SimSpeed secondes réelles : il arrive quand les dégâts tombent.
local SHOT_BYTES = 27
-- Petite marge pour comparer des heures de la simulation (additions de 0,5 s répétées).
local TIME_EPSILON = 1e-6

local PlotGame = {}
PlotGame.__index = PlotGame

-- Pass Pièces x2 : multiplie les pièces des ennemis tués (et les gains d'absence, Hub/init.luau).
PlotGame.COINS_PASS_FACTOR = 2

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
	self.impacts = {} -- projectiles en vol (dégâts à l'arrivée, voir fireProjectile)
	self.firePatches = {} -- zones de feu des flèches enflammées (voir addFirePatch)
	self.nextId = 0
	self.attributeCache = {}
	self.lastSyncEmpty = false
	-- Horloge de la simulation, en secondes : avance de dt à chaque pas (voir PlotGame:step).
	self.clock = 0
	self.simSpeed = 1 -- 1, ou IdleConfig.SPEED_PASS_FACTOR avec le pass Vitesse x2 allumé
	self.autoCollect = false -- pass Ramassage auto
	self.coinMultiplier = 1 -- 1, ou PlotGame.COINS_PASS_FACTOR avec le pass Pièces x2

	self.state = "Intermission"
	self.nextWaveAt = self.clock + IdleConfig.FIRST_WAVE_DELAY

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
	self:setAttr("SimSpeed", self.simSpeed)
	self:setAttr("CoinMultiplier", self.coinMultiplier)
	self:publishNextWave()
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

-- Heure réelle (du serveur) du début de la prochaine vague, pour le compte à rebours des clients :
-- l'entracte restant (en secondes de simulation) passe simSpeed fois plus vite.
function PlotGame:publishNextWave()
	local left = math.max(0, self.nextWaveAt - self.clock)
	self:setAttr("NextWaveAt", workspace:GetServerTimeNow() + left / self.simSpeed)
end

----------------------------------------------------------------------
-- Passes de jeu (appliqués par Hub/init.luau, qui vérifie la possession)
----------------------------------------------------------------------

-- Pass Vitesse x2 : 1 = vitesse normale, IdleConfig.SPEED_PASS_FACTOR = x2. Toute autre valeur = 1.
-- Publié dans l'attribut « SimSpeed » du dossier de la parcelle (lu par PlotRenderer).
function PlotGame:setSimSpeed(speed: any)
	local value = if speed == IdleConfig.SPEED_PASS_FACTOR then IdleConfig.SPEED_PASS_FACTOR else 1
	if value == self.simSpeed then
		return
	end
	self.simSpeed = value
	self:setAttr("SimSpeed", value)
	if self.state == "Intermission" then
		self:publishNextWave()
	end
end

-- Pass Ramassage auto : les piles de pièces de la parcelle sont ramassées sans marcher (collectDrops).
function PlotGame:setAutoCollect(enabled: boolean)
	self.autoCollect = enabled == true
end

-- Pass Pièces x2 : 1 = normal, PlotGame.COINS_PASS_FACTOR = pièces des ennemis doublées. Toute autre
-- valeur = 1. Seules les pièces lâchées après le changement comptent (les piles au sol ne changent pas).
-- Publié dans l'attribut « CoinMultiplier » du dossier de la parcelle.
function PlotGame:setCoinMultiplier(multiplier: any)
	local value = if multiplier == PlotGame.COINS_PASS_FACTOR then PlotGame.COINS_PASS_FACTOR else 1
	self.coinMultiplier = value
	self:setAttr("CoinMultiplier", value)
end

----------------------------------------------------------------------
-- Vagues
----------------------------------------------------------------------

function PlotGame:startWave()
	local now = self.clock
	local at = now
	-- Une vraie vague met fin à l'arène de test (debugArena), si elle était ouverte.
	self.debugHold = nil
	self.debugActive = nil
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
	-- Les projectiles en vol et les zones de feu disparaissent avec la vague, les rayons s'éteignent.
	table.clear(self.impacts)
	table.clear(self.firePatches)
	for _, tower in self.towers do
		if tower.beamTarget or (tower.beamShownId or 0) ~= 0 then
			tower.beamTarget = nil
			tower.beamTime = 0
			self:showBeam(tower, nil, 0)
		end
	end
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
	self.nextWaveAt = self.clock + delay
	self:publishNextWave()
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
	self.nextWaveAt = self.clock + IdleConfig.FIRST_WAVE_DELAY
	self:publishNextWave()
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
		-- Dégâts des projectiles déjà en vol vers lui : s'ils suffisent à le tuer, les tours visent
		-- quelqu'un d'autre (voir isDoomed). inFlight = nombre de ces projectiles.
		pending = 0,
		inFlight = 0,
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

-- Les pièces tombent au sol ; une nouvelle pièce proche d'une pile s'y ajoute. Renvoie la pile.
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
		return nearest
	end

	local ground = self.cframe:PointToObjectSpace(position)
	local drop = {
		id = self:newId(),
		position = self.cframe:PointToWorldSpace(Vector3.new(ground.X, 1, ground.Z)),
		amount = amount,
		createdAt = os.clock(), -- temps réel : le ramassage auto attend IdleConfig.AUTO_COLLECT_DELAY
	}
	self.drops[drop.id] = drop
	self.dropCount += 1
	self:sendDrop("Set", drop)
	return drop
end

function PlotGame:collectDrop(id: number, drop)
	self.drops[id] = nil
	self.dropCount -= 1
	PlayerData.addCoins(self.player, drop.amount)
	self:sendDrop("Collect", drop)
end

-- Ramasse les piles proches du joueur (appelé quelques fois par seconde). Avec le pass Ramassage auto :
-- toutes les piles de la parcelle, où que soit le joueur, dès qu'elles sont au sol depuis
-- IdleConfig.AUTO_COLLECT_DELAY secondes (le temps de les voir tomber).
function PlotGame:collectDrops()
	if self.dropCount == 0 then
		return
	end
	if self.autoCollect then
		local now = os.clock()
		for id, drop in self.drops do
			if now - drop.createdAt >= IdleConfig.AUTO_COLLECT_DELAY then
				self:collectDrop(id, drop)
			end
		end
		return
	end
	local character = self.player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	for id, drop in self.drops do
		local offset = drop.position - root.Position
		if Vector3.new(offset.X, 0, offset.Z).Magnitude <= IdleConfig.PICKUP_RADIUS and math.abs(offset.Y) < 10 then
			self:collectDrop(id, drop)
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
		-- Pass Pièces x2 : x2 en plus du bonus de renaissance (gain x (1 + bonus / 100) x 2). Le ramassage
		-- verse la pile telle quelle (pas de 2e doublement).
		-- (Les ennemis des tests Studio ne rapportent rien, sauf demande : pas de pile vide.)
		if enemy.reward > 0 then
			self:addDrop(enemy.position, enemy.reward * (1 + self.idle.coinBonus / 100) * self.coinMultiplier)
		end
	end
end

-- Effet visuel d'un tir, envoyé aux clients avec le prochain paquet (takeShotsPacket).
-- landsAt = heure (de la simulation) de l'impact : maintenant pour un tir instantané.
function PlotGame:addShot(from: Vector3, to: Vector3, towerType: string, radius: number, landsAt: number)
	if #self.shots < IdleConfig.MAX_SHOTS_PER_PACKET then
		table.insert(self.shots, { from = from, to = to, type = TOWER_INDEX[towerType], radius = radius, landsAt = landsAt })
	end
end

-- Stats d'une tour posée : niveau, doublons et bonus compris. Gardées sur la tour tant que rien ne change
-- (le rayon du Sorcier en a besoin à chaque pas de simulation).
function PlotGame:statsOf(tower)
	local dupes = self.idle.towerDupes[tower.type] or 0
	if not tower.stats or tower.statsLevel ~= tower.level or tower.statsDupes ~= dupes or tower.statsBonus ~= tower.bonus then
		tower.stats = IdleTowers.effectiveStats(tower.type, tower.level, dupes, tower.bonus)
		tower.statsLevel = tower.level
		tower.statsDupes = dupes
		tower.statsBonus = tower.bonus
	end
	return tower.stats
end

-- Condamné : les projectiles déjà en vol vers lui suffiront à le tuer.
local function isDoomed(enemy): boolean
	return enemy.pending >= enemy.health
end

-- Cible d'une tour à portée : la plus avancée (« First ») ou la plus résistante (« Strongest »).
-- Les ennemis condamnés sont évités (pas de tirs gâchés) ; allowDoomed = on les prend quand même s'il n'y
-- a personne d'autre (tirs instantanés et rayon, qui ne gâchent rien en attendant).
function PlotGame:pickTarget(tower, stats, allowDoomed: boolean): any
	local strongest = stats.targeting == "Strongest"
	local best, bestScore = nil, -math.huge
	local fallback, fallbackScore = nil, -math.huge
	for _, enemy in self.enemies do
		if not enemy.dead and horizontalDistance(tower.position, enemy.position) <= stats.range then
			local score = if strongest then enemy.health else enemy.distance
			if not isDoomed(enemy) then
				if score > bestScore then
					best, bestScore = enemy, score
				end
			elseif allowDoomed and score > fallbackScore then
				fallback, fallbackScore = enemy, score
			end
		end
	end
	return best or fallback
end

-- Un coup sur un ennemi : dégâts de la tour, et son ralentissement si elle en a un.
function PlotGame:hitEnemy(enemy, stats, now: number)
	if stats.slow then
		applySlow(enemy, stats.slow, stats.slowDuration, now)
	end
	self:damageEnemy(enemy, stats.damage)
end

-- Un coup de zone : tous les ennemis vivants à moins de stats.splash studs du point d'impact.
function PlotGame:hitArea(center: Vector3, stats, now: number)
	for _, enemy in self.enemies do
		if not enemy.dead and horizontalDistance(center, enemy.position) <= stats.splash then
			self:hitEnemy(enemy, stats, now)
		end
	end
end

-- Ennemi vivant le plus proche d'un point, à moins de `radius` studs (nil sinon).
function PlotGame:enemyNear(position: Vector3, radius: number): any
	local nearest, nearestDistance = nil, radius
	for _, enemy in self.enemies do
		if not enemy.dead then
			local distance = horizontalDistance(position, enemy.position)
			if distance <= nearestDistance then
				nearest, nearestDistance = enemy, distance
			end
		end
	end
	return nearest
end

----------------------------------------------------------------------
-- Projectiles : visée anticipée, dégâts à l'impact
----------------------------------------------------------------------

-- Point du chemin (dans le monde) à `distance` studs du départ.
function PlotGame:pathPoint(distance: number): Vector3
	return self.cframe:PointToWorldSpace((PlotLayout.pointAt(math.min(distance, PlotLayout.PATH_LENGTH))))
end

-- Distance que l'ennemi aura parcourue dans `seconds` secondes de simulation : à sa vitesse ralentie tant
-- que son ralentissement actuel dure, puis à sa vitesse normale (celle de son type). Les ralentissements
-- qui arriveront pendant le vol ne se devinent pas.
local function travelDistance(enemy, now: number, seconds: number): number
	local speed = enemy.def.speed * IdleConfig.ENEMY_SPEED_MULTIPLIER * enemy.speedScale
	local slowed = if now < enemy.slowUntil then math.min(seconds, enemy.slowUntil - now) else 0
	return speed * (slowed * (1 - enemy.slowFactor) + (seconds - slowed))
end

-- Où viser pour toucher `target` avec un projectile parti de `from`, et combien de temps il volera.
-- Le temps de vol dépend de la distance, qui dépend du point visé : on recommence 2 fois (ça converge
-- très vite), puis on prend le point où sera l'ennemi au bout du temps de vol final.
function PlotGame:predictImpact(target, from: Vector3, stats, now: number): (Vector3, number)
	local flight = IdleTowers.flightTime(stats, (target.position - from).Magnitude)
	for _ = 1, 2 do
		local aim = self:pathPoint(target.distance + travelDistance(target, now, flight))
		flight = IdleTowers.flightTime(stats, (aim - from).Magnitude)
	end
	return self:pathPoint(target.distance + travelDistance(target, now, flight)), flight
end

-- Lance un projectile : les dégâts tomberont dans `flight` secondes (de simulation) au point prévu.
-- Les stats sont celles du moment du tir (une amélioration pendant le vol ne change pas ce projectile).
function PlotGame:fireProjectile(tower, stats, target, muzzle: Vector3, now: number)
	local aim, flight = self:predictImpact(target, muzzle, stats, now)
	target.pending += stats.damage
	target.inFlight += 1
	table.insert(self.impacts, {
		at = now + flight,
		spot = tower.spotIndex,
		target = target,
		position = aim,
		stats = stats,
	})
	self:addShot(muzzle, aim, tower.type, stats.splash or 0, now + flight)
end

-- Arrivée d'un projectile.
--   Zone (Catapulte, Baliste, Trébuchet) : tous les ennemis autour du POINT D'IMPACT à cet instant.
--   Flèche : sa cible si elle vit encore (où qu'elle soit) ; si elle est morte pendant le vol, l'ennemi
--   vivant le plus proche du point d'impact à moins de PROJECTILE_CATCH_RADIUS studs, sinon rien.
--   Flèche enflammée : une zone de feu au point d'impact, touchée ou non.
function PlotGame:landImpact(impact, now: number)
	local stats, target = impact.stats, impact.target
	target.inFlight -= 1
	-- Plus rien en vol vers lui : exactement 0. Sans ça, additionner puis retirer des dégâts très
	-- différents (1e20 et 7) laisse un petit reste qui pourrait le faire croire « condamné » à tort
	-- (ou l'infini, avec des dégâts énormes) : les tours à projectile l'ignoreraient pour toujours.
	target.pending = if target.inFlight <= 0 then 0 else math.max(0, target.pending - stats.damage)
	if stats.kind == "Splash" then
		self:hitArea(impact.position, stats, now)
	else
		local victim = if target.dead then self:enemyNear(impact.position, IdleTowers.PROJECTILE_CATCH_RADIUS) else target
		if victim then
			self:hitEnemy(victim, stats, now)
		end
	end
	if stats.fireRadius then
		self:addFirePatch(impact.spot, impact.position, stats, now)
	end
	if self.debugHold then
		-- Tests Studio : où était la cible au moment de l'impact, comparé au point visé.
		self.debugImpactInfo = {
			at = impact.at,
			landedAt = now,
			aim = impact.position,
			targetId = target.id,
			targetAlive = not target.dead,
			targetPosition = target.position,
		}
	end
end

-- Projectiles arrivés (heure d'impact atteinte sur l'horloge de la simulation : marche pareil en x2).
function PlotGame:resolveImpacts(now: number)
	local impacts = self.impacts
	local i = 1
	while i <= #impacts do
		local impact = impacts[i]
		if impact.at <= now then
			-- Retiré en mettant le dernier à sa place (l'ordre ne compte pas).
			impacts[i] = impacts[#impacts]
			impacts[#impacts] = nil
			self:landImpact(impact, now)
		else
			i += 1
		end
	end
end

----------------------------------------------------------------------
-- Flèches enflammées : zones de feu au sol
----------------------------------------------------------------------

-- Une flèche enflammée touche le sol. Dans une zone de la même tour : elle la ravive (fireDuration s de
-- plus, dégâts les plus forts gardés). Sinon, nouvelle zone ; au-delà de fireMaxPatches zones pour cette
-- tour (ou de IdleTowers.FIRE_MAX_PER_PLOT sur la parcelle), celle qui s'éteint le plus tôt disparaît.
function PlotGame:addFirePatch(spot: number, position: Vector3, stats, now: number)
	local dps = IdleTowers.fireDps(stats)
	local patches = self.firePatches
	local mine, oldestMine, oldestAll = 0, nil, nil
	for index, patch in patches do
		if patch.spot == spot then
			if horizontalDistance(patch.position, position) <= patch.radius then
				patch.expiresAt = now + stats.fireDuration
				patch.dps = math.max(patch.dps, dps)
				return
			end
			mine += 1
			if not oldestMine or patch.expiresAt < patches[oldestMine].expiresAt then
				oldestMine = index
			end
		end
		if not oldestAll or patch.expiresAt < patches[oldestAll].expiresAt then
			oldestAll = index
		end
	end
	if mine >= stats.fireMaxPatches and oldestMine then
		table.remove(patches, oldestMine)
	elseif #patches >= IdleTowers.FIRE_MAX_PER_PLOT and oldestAll then
		table.remove(patches, oldestAll)
	end
	table.insert(patches, {
		spot = spot,
		position = position,
		radius = stats.fireRadius,
		dps = dps,
		tick = stats.fireTick,
		expiresAt = now + stats.fireDuration,
		nextTick = now + stats.fireTick, -- 1er coup après fireTick s, puis toutes les fireTick s
	})
end

-- Les zones de feu brûlent tous les ennemis dedans : dps x fireTick à chaque coup, tant qu'elles durent
-- (une zone de 2 s donne 4 coups de 0,5 s). Puis elles s'éteignent.
function PlotGame:burnFires(now: number)
	local patches = self.firePatches
	for i = #patches, 1, -1 do
		local patch = patches[i]
		while patch.nextTick <= now + TIME_EPSILON and patch.nextTick <= patch.expiresAt + TIME_EPSILON do
			local amount = patch.dps * patch.tick
			for _, enemy in self.enemies do
				if not enemy.dead and horizontalDistance(patch.position, enemy.position) <= patch.radius then
					self:damageEnemy(enemy, amount)
				end
			end
			patch.nextTick += patch.tick
		end
		if patch.nextTick > patch.expiresAt + TIME_EPSILON then
			table.remove(patches, i)
		end
	end
end

----------------------------------------------------------------------
-- Rayon continu (Sorcier des arcanes)
----------------------------------------------------------------------

-- Publie le rayon d'une tour pour les clients (seulement quand ça change) : attribut « BeamTarget » = id
-- de l'ennemi visé (0 = éteint), « BeamRamp » = montée actuelle arrondie à 0,5 (épaisseur du rayon).
function PlotGame:showBeam(tower, target, ramp: number)
	local id = if target then target.id else 0
	local shown = if target then math.floor(ramp * 2 + 0.5) / 2 else 0
	if tower.beamShownId ~= id then
		tower.beamShownId = id
		tower.model:SetAttribute("BeamTarget", id)
	end
	if tower.beamShownRamp ~= shown then
		tower.beamShownRamp = shown
		tower.model:SetAttribute("BeamRamp", shown)
	end
end

-- Un pas de dt secondes du rayon. Il garde sa cible tant qu'elle vit et reste à portée, même si un ennemi
-- plus résistant arrive (changer remettrait la montée à zéro). Sinon, il prend le plus résistant à portée
-- et la montée repart de x1. Dégâts de ce pas = damage x montée (au milieu du pas) x dt : exactement les
-- mêmes dégâts par seconde de simulation en x1 et en x2 (voir IdleTowers.beamDamage).
function PlotGame:beamStep(tower, stats, dt: number)
	local target = tower.beamTarget
	if target and (target.dead or horizontalDistance(tower.position, target.position) > stats.range) then
		target = nil
	end
	if not target then
		target = self:pickTarget(tower, stats, true)
		tower.beamTarget = target
		tower.beamTime = 0
	end
	if not target then
		self:showBeam(tower, nil, 0)
		return
	end
	local startTime = tower.beamTime
	tower.beamTime = startTime + dt
	self:damageEnemy(target, stats.damage * IdleTowers.beamRamp(stats, startTime + dt / 2) * dt)
	self:showBeam(tower, target, IdleTowers.beamRamp(stats, tower.beamTime))
end

----------------------------------------------------------------------
-- Tirs des tours
----------------------------------------------------------------------

function PlotGame:towerAttack(tower, stats, now: number): boolean
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
			self:addShot(tower.position, tower.position, tower.type, stats.range, now)
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
			self:addShot(from, enemy.position, tower.type, 0, now)
			from = enemy.position
			self:damageEnemy(enemy, stats.damage)
		end
		return true
	end

	-- Une cible (« Single ») ou une zone autour d'elle (« Splash »). Les tours à projectile ne visent
	-- jamais un ennemi condamné : elles attendent plutôt une autre cible.
	local projectile = IdleTowers.isProjectile(stats)
	local target = self:pickTarget(tower, stats, not projectile)
	if not target then
		return false
	end
	if projectile then
		self:fireProjectile(tower, stats, target, muzzle, now)
		return true
	end
	-- Tir instantané (Mage des tempêtes) : la foudre tombe tout de suite sur la cible (et, pour une zone,
	-- sur les ennemis collés à elle : dégâts et ralentissement pour tous).
	local impact = target.position
	if stats.kind == "Splash" then
		self:hitArea(impact, stats, now)
	else
		self:hitEnemy(target, stats, now)
	end
	self:addShot(muzzle, impact, tower.type, stats.splash or 0, now)
	return true
end

-- Un pas de simulation de dt secondes (horloge de la simulation).
function PlotGame:simulate(dt: number)
	self.clock += dt
	local now = self.clock
	if self.state == "Intermission" then
		if now >= self.nextWaveAt then
			self:startWave()
		end
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
			return
		end
		enemy.position = self.cframe:PointToWorldSpace((PlotLayout.pointAt(enemy.distance)))
	end

	-- Projectiles qui arrivent (dégâts à l'impact)
	self:resolveImpacts(now)

	-- Tours (debugActive : arène de test Studio, seules certaines tours tirent d'elles-mêmes)
	for spotIndex, tower in self.towers do
		if self.debugActive and not self.debugActive[spotIndex] then
			continue
		end
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

	-- Zones de feu des flèches enflammées
	self:burnFires(now)

	for i = #self.enemies, 1, -1 do
		if self.enemies[i].dead then
			table.remove(self.enemies, i)
		end
	end

	-- debugHold : arène de test Studio, la vague ne se termine pas toute seule.
	if not self.debugHold and self.spawnIndex > #self.spawnQueue and #self.enemies == 0 then
		self:endWave(true)
	end
end

-- Appelé à chaque image. Pass Vitesse x2 : simSpeed pas de dt au lieu d'un. C'est exactement la même
-- partie qu'à vitesse normale (mêmes écarts entre les tirs, mêmes ralentissements, mêmes entractes),
-- jouée deux fois plus vite.
function PlotGame:step(dt: number)
	for _ = 1, self.simSpeed do
		self:simulate(dt)
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

	local now = self.clock
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
	local now = self.clock
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
		-- Vol restant, en centièmes de seconde de simulation (0 = instantané ou déjà arrivé).
		local flightLeft = math.max(0, (shot.landsAt or now) - now)
		buffer.writeu8(packet, offset + 26, math.clamp(math.floor(flightLeft * 100 + 0.5), 0, 255))
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
	-- Lancers de l'autel achetés depuis toujours : l'autel affiche les prix exacts (IdleConfig.towerSpinCost).
	-- Seulement pour l'affichage : le serveur calcule toujours les prix avec SES données.
	player:SetAttribute("TowerSpinsBought", IdleConfig.cleanSpinsBought(self.idle.towerSpinsBought))
end

function PlotGame:sendResult(result)
	if self.player.Parent then
		Remotes.get("MachineResult"):FireClient(self.player, result)
	end
end

-- Machine à tours : `count` lancers payés en pièces (1, 10, 100... voir IdleConfig.TOWER_SPIN_BULKS ;
-- rien = 1). Le serveur vérifie tout : nombre proposé ET débloqué à ton record, prix possible (pas « MAX »),
-- pièces suffisantes. Prix = somme des `count` prochains prix, calculée avec le compteur des lancers déjà
-- achetés (idle.towerSpinsBought, jamais remis à zéro), qui augmente ensuite de `count`.
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
	-- Compteur propre (une valeur abîmée compte comme 0), republié : l'autel du client reste exact.
	local bought = IdleConfig.cleanSpinsBought(self.idle.towerSpinsBought)
	self.idle.towerSpinsBought = bought
	self.player:SetAttribute("TowerSpinsBought", bought)
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
	local cost = IdleConfig.towerSpinCost(record, count, bought)
	if cost >= math.huge then
		-- Total trop grand pour être compté (plus de ~1,8e308) : l'autel affiche « MAX ».
		self:notify(`Prix trop élevé (MAX) : impossible de lancer x{NumberFormat.short(count)} d'un coup`, "Error")
		return nil
	end
	if self.data.coins < cost then
		self:notify(`Il te faut {NumberFormat.price(cost)} pièces`, "Error")
		return nil
	end
	PlayerData.addCoins(self.player, -cost)
	-- Chaque lancer acheté rend le suivant plus cher (bought + count reste un entier fini, bien sous 2^53).
	self.idle.towerSpinsBought = bought + count

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

----------------------------------------------------------------------
-- Outils de test (Studio seulement : ServerStorage.StudioDebug, commande « Call », voir Hub/init.luau)
-- Ex. : Invoke(player, "Call", "debugArena", { 6 }) puis Invoke(player, "Call", "debugSpawn", "Boss", 206, 1e9, true)
----------------------------------------------------------------------

-- Arène de test : la vague en cours est vidée, rien n'apparaît plus, la vague ne se termine pas toute
-- seule, et seules les tours des emplacements `activeSpots` tirent d'elles-mêmes ({} = aucune).
-- Une vraie vague (startWave) ou debugEndArena la ferme.
function PlotGame:debugArena(activeSpots: { number }?)
	self:clearEnemies()
	self.state = "Running"
	self.debugHold = true
	self.debugImpactInfo = nil
	self:debugActivate(activeSpots)
	for _, tower in self.towers do
		tower.cooldown = 0
	end
	self:syncAttributes()
	return self.clock
end

-- Change les tours qui tirent d'elles-mêmes dans l'arène.
function PlotGame:debugActivate(activeSpots: { number }?)
	self.debugActive = {}
	for _, spotIndex in activeSpots or {} do
		self.debugActive[spotIndex] = true
	end
end

function PlotGame:debugEndArena()
	self.debugHold = nil
	self.debugActive = nil
	self.debugImpactInfo = nil
	self:clearEnemies()
	self.state = "Intermission"
	self.nextWaveAt = self.clock + IdleConfig.WAVE_CLEAR_DELAY
	self:publishNextWave()
	self:syncAttributes()
end

-- Un ennemi à `distance` studs du début du chemin, avec `health` PV.
-- frozen = immobile (facteur de vitesse de son type à 0 : les ralentissements s'appliquent quand même).
-- reward = son gain en pièces avant bonus et pass (rien = 0 : il ne rapporte rien).
-- Renvoie son id (nil si le type n'existe pas).
function PlotGame:debugSpawn(enemyName: string, distance: number, health: number, frozen: boolean?, reward: number?)
	if not Enemies.Defs[enemyName] then
		return nil
	end
	local coins = if typeof(reward) == "number" and reward > 0 and reward < math.huge then reward else 0
	self:spawnEnemy({ enemy = enemyName, health = health, reward = coins })
	local enemy = self.enemies[#self.enemies]
	enemy.distance = distance
	enemy.position = self:pathPoint(distance)
	if frozen then
		enemy.speedScale = 0
	end
	return enemy.id
end

local function findEnemy(self, id: number)
	for _, enemy in self.enemies do
		if enemy.id == id then
			return enemy
		end
	end
	return nil
end

-- État d'un ennemi (alive = faux s'il est mort ou n'existe plus), avec l'heure de la simulation.
function PlotGame:debugEnemy(id: number)
	local enemy = findEnemy(self, id)
	if not enemy or enemy.dead then
		return { alive = false, clock = self.clock }
	end
	local slowed = self.clock < enemy.slowUntil
	return {
		alive = true,
		health = enemy.health,
		distance = enemy.distance,
		position = enemy.position,
		slowed = slowed,
		slowFactor = if slowed then enemy.slowFactor else 0,
		pending = enemy.pending,
		clock = self.clock,
	}
end

-- Tue cet ennemi. Renvoie les pièces que sa mort a posées au sol (ajoutées aux piles, 0 s'il ne rapporte rien).
function PlotGame:debugKill(id: number): number
	local enemy = findEnemy(self, id)
	if not enemy or enemy.dead then
		return 0
	end
	local before = {}
	for dropId, drop in self.drops do
		before[dropId] = drop.amount
	end
	self:damageEnemy(enemy, enemy.health)
	local dropped = 0
	for dropId, drop in self.drops do
		dropped += drop.amount - (before[dropId] or 0)
	end
	return dropped
end

-- La tour de cet emplacement tire une fois tout de suite (comme d'elle-même). Renvoie ce qui s'est passé :
-- fired, et pour un projectile : flight (temps de vol), aim (point visé), targetId.
function PlotGame:debugFire(spotIndex: number)
	local tower = self.towers[spotIndex]
	if not tower then
		return nil
	end
	local stats = self:statsOf(tower)
	if stats.kind == "Beam" then
		return { fired = false, clock = self.clock }
	end
	local before = #self.impacts
	local fired = self:towerAttack(tower, stats, self.clock)
	local impact = if #self.impacts > before then self.impacts[#self.impacts] else nil
	return {
		fired = fired,
		clock = self.clock,
		damage = stats.damage,
		flight = if impact then impact.at - self.clock else 0,
		aim = impact and impact.position,
		targetId = impact and impact.target.id,
	}
end

-- Stats et rayon d'une tour : dégâts, portée, cible du rayon, secondes sur elle, montée, PV de la cible.
function PlotGame:debugTower(spotIndex: number)
	local tower = self.towers[spotIndex]
	if not tower then
		return nil
	end
	local stats = self:statsOf(tower)
	local target = tower.beamTarget
	local active = target ~= nil and not target.dead
	return {
		type = tower.type,
		level = tower.level,
		damage = stats.damage,
		range = stats.range,
		fireDps = IdleTowers.fireDps(stats),
		beamRampRate = stats.beamRampRate,
		beamRampMax = stats.beamRampMax,
		beamTargetId = if active then target.id else 0,
		beamTime = if active then tower.beamTime else 0,
		beamRamp = if active then IdleTowers.beamRamp(stats, tower.beamTime) else 0,
		targetHealth = if active then target.health else nil,
		clock = self.clock,
	}
end

-- Zones de feu actives de la parcelle.
function PlotGame:debugFires()
	local list = {}
	for _, patch in self.firePatches do
		table.insert(list, {
			spot = patch.spot,
			position = patch.position,
			radius = patch.radius,
			dps = patch.dps,
			expiresIn = patch.expiresAt - self.clock,
		})
	end
	return { count = #list, patches = list, clock = self.clock }
end

-- Dernier projectile arrivé dans l'arène : point visé et position de la cible à l'impact.
function PlotGame:debugLastImpact()
	return self.debugImpactInfo
end

-- Le joueur quitte le serveur : on libère la parcelle (sa progression est déjà dans ses données).
function PlotGame:destroy()
	self:clearEnemies() -- avant les tours : leurs rayons s'éteignent proprement
	self.towerFolder:Destroy()
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

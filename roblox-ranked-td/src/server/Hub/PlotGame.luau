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
--     Archer, Catapulte et Baliste SUIVENT leur cible : l'effet tombe là où elle est vraiment à l'impact
--     (impactCenter), le Trébuchet garde son point prévu ;
--   carreau perçant (Baliste lourde) : à l'impact, les ennemis sur la ligne tour -> point d'impact, 3 au plus
--     (IdleTowers.BALLISTA_PIERCE_MAX : sa cible et les premiers rencontrés, hitLine) ; elle vise le plus
--     résistant, et entre ennemis presque aussi résistants, celui qui en aligne le plus (pickPierceTarget) ;
--   Trébuchet royal : vise le plus gros groupe (pickCrowdTarget) et étourdit la zone ;
--   flèches enflammées : zones de feu au sol (self.firePatches) ;
--   rayon continu : Sorcier des arcanes (beamStep), publié aux clients par les attributs « BeamTarget »
--     (id de l'ennemi visé, 0 = éteint) et « BeamRamp » (montée actuelle, arrondie à 0,5) de sa tour ;
--   CONTRÔLES (ralentissements, étourdissement) : un seul à la fois par ennemi, et fatigue des contrôles courts
--     du Mage et du Trébuchet : jamais prolongés, puis une immunité (applyControl) ;
--   fragilité du Totem de givre : +X % de dégâts reçus (applyFragility, damageEnemy).
-- Apparitions : un ennemi meurt -> le suivant de la file sort tout de suite (IdleConfig.SPAWN_NEXT_ON_KILL) ;
-- vague écrasée = plus personne en vie -> l'ennemi suivant sort tout de suite (IdleConfig.COMPRESS_EMPTY_SPAWNS,
-- voir simulate).
--
-- Paquets réseau (lus par PlotRenderer.luau) :
--   PlotSync (positions)  = count x ENEMY_BYTES octets, PUIS count octets « contrôle » (un par ennemi, même
--     ordre) : bits 0-3 = numéro (IdleTowers.ORDER) du type de tour dont le contrôle est en cours (0 = aucun ;
--     Frost = ralenti par un Totem, Tesla = ralenti par un Mage, Orbital = étourdi par le Trébuchet), bit 7
--     (valeur 128) = fragile (dans l'aura d'un Totem de givre : prend plus de dégâts). Un client qui ne lit que
--     les count x ENEMY_BYTES premiers octets marche toujours (ces octets sont à la fin).
--   PlotShots (tirs)      = count x SHOT_BYTES octets (voir SHOT_BYTES), PUIS count x SHOT_TARGET_BYTES octets :
--     l'id u32 de la cible de chaque tir, même ordre (0 = aucune : tir instantané, aura, Trébuchet). Un id =
--     projectile qui suit sa cible (Archer, Catapulte, Baliste : IdleTowers.followsTarget) : le client le fait
--     voler vers l'ennemi affiché avec cet id, comme le serveur fait tomber l'effet sur lui (impactCenter). Un
--     client qui ne lit que les count x SHOT_BYTES premiers octets marche toujours (ces octets sont à la fin).
--     Baliste (type Rocket) : le trait va du départ au point d'arrivée et touche les ennemis sur sa ligne
--     (demi-largeur IdleTowers.Defs.Rocket.pierceWidth, 3 au plus, rayon envoyé = 0). Trébuchet (type Orbital) : rayon =
--     sa grande zone ; les ennemis étourdis ont le contrôle Orbital dans PlotSync (et une vitesse 0).
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
-- « vitesse % » = facteur de son type (IdleConfig.ENEMY_SPEED_FACTORS) x contrôle (ralentissement ; 0 s'il
-- est étourdi), en % : le client avance l'ennemi à vitesse de Enemies.luau x ENEMY_SPEED_MULTIPLIER x ce
-- facteur x l'attribut « SimSpeed » de la parcelle. Le paquet ne contient PAS le x2 du pass : le client multiplie.
-- Après les count x ENEMY_BYTES octets : count octets « contrôle » (voir en haut du fichier).
local ENEMY_BYTES = 11
-- Octet « contrôle » : bit 7 = ennemi fragile (Totem de givre).
local CONTROL_FRAGILE_FLAG = 128
-- Taille d'un tir : départ 3xf32, arrivée 3xf32, type u8, rayon u8, vol u8 (même format dans PlotRenderer).
-- « vol » = temps de vol qui RESTE quand le paquet part, en centièmes de seconde de simulation (0 = tir
-- instantané, 255 = 2,55 s au plus, voir IdleTowers.MAX_FLIGHT_TIME). Les tirs partent par paquets
-- (IdleConfig.SHOTS_RATE fois par seconde) : un projectile lancé juste avant l'envoi a encore presque tout
-- son vol, un autre lancé juste après le paquet précédent en a déjà fait une partie. Le client anime le
-- projectile jusqu'au point d'impact en vol / SimSpeed secondes réelles : il arrive quand les dégâts tombent.
local SHOT_BYTES = 27
-- Après les count x SHOT_BYTES octets : l'id u32 de la cible de chaque tir (0 = aucune). Paquet plein :
-- MAX_SHOTS_PER_PACKET (24) x 31 = 744 octets, sous la limite d'un UnreliableRemoteEvent (~900 octets).
local SHOT_TARGET_BYTES = 4
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
	self.spawnSkipped = 0 -- attente sautée par les vagues écrasées (voir simulate)
	self.spawnReleases = 0 -- morts qui n'ont pas encore fait sortir leur ennemi (voir simulate)
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

	self:loadTowers()
	self:publishInventory()

	self:refreshSpots()
	self:setAttr("OwnerUserId", player.UserId)
	self:setAttr("SimSpeed", self.simSpeed)
	self:setAttr("CoinMultiplier", self.coinMultiplier)
	self:publishNextWave()
	self:syncAttributes()
	return self
end

-- Tours de la sauvegarde (data.idle.towers) posées sur la parcelle, à l'arrivée du joueur. TOUTES sont gardées, même
-- au-delà de la limite de tours identiques (vieilles sauvegardes, tests du propriétaire) : rien n'est retiré ni
-- remboursé ; le joueur ne peut juste plus poser de ce type tant qu'il est à la limite (placeTower).
function PlotGame:loadTowers()
	for key, saved in self.idle.towers do
		local spotIndex = tonumber(key)
		if IdleTowers.Defs[saved.type] and self:ownsSpot(spotIndex) then
			self:createTower(spotIndex, saved.type, saved.level or 1, saved.spent or 0, saved.runes)
		end
	end
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
	-- DPS total (voir totalDps) : recalculé à chaque image (22 tours au plus, stats gardées par statsOf), donc toujours à
	-- jour (tour posée, vendue, améliorée, rune, doublon...) ; publié seulement quand il change : attribut
	-- « TotalDps » de la parcelle (tableau du fief) et colonne « DPS » de la liste des joueurs.
	local dps = self:totalDps()
	if self.attributeCache.TotalDps ~= dps then
		self:setAttr("TotalDps", dps)
		PlayerData.setDps(self.player, dps)
	end
end

-- DPS total de la parcelle : somme des dégâts par seconde de chaque tour posée (IdleTowers.dpsOf de ses stats : niveau,
-- doublons et runes compris, statsOf). SANS le pass Vitesse x2 (décidé le 30/09/2026) : il accélère aussi les ennemis,
-- on n'est donc pas plus fort, et un pass payant ne doit pas faire monter au classement. C'est LE nombre du mode solo,
-- le même partout : « DPS TOTAL » du tableau du fief (PlotBoard.luau), colonne « DPS » de la liste des joueurs
-- (PlayerData.setDps) et classement solo (SoloLeaderboard.luau). Emplacements lus dans l'ordre : toujours la même
-- somme, au dernier chiffre près. Jamais NaN (0 à la place).
function PlotGame:totalDps(): number
	local total = 0
	for spotIndex = 1, #PlotLayout.SPOTS do
		local tower = self.towers[spotIndex]
		if tower then
			total += IdleTowers.dpsOf(self:statsOf(tower))
		end
	end
	return if total == total then total else 0
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
	self.spawnSkipped = 0
	self.spawnReleases = 0
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
	-- Secondes d'attente sautées dans la file d'apparition (vague écrasée, voir simulate) : un ennemi de la
	-- file sort à item.at - spawnSkipped.
	self.spawnSkipped = 0
	-- Morts qui n'ont pas encore fait sortir leur ennemi (IdleConfig.SPAWN_NEXT_ON_KILL, voir simulate).
	self.spawnReleases = 0
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
		-- Astuce, UNE seule fois (demande du propriétaire, 30/09/2026) : au premier échec quand la renaissance est
		-- possible (vague REBIRTH_MIN_WAVE réussie dans la run) et que le joueur n'en a encore jamais fait :
		-- « Tu bloques ? Utilise la Renaissance, sans perdre ta progression ». Affichée par RebirthUI.
		local gain = IdleConfig.rebirthGain(self.idle.bestWave)
		if not self.idle.rebirthHintShown and (self.idle.rebirths or 0) == 0 and gain > 0 then
			self.idle.rebirthHintShown = true
			Remotes.get("RebirthHint"):FireClient(self.player, gain)
		end
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
		-- Contrôle en cours (un seul à la fois, voir applyControl) : type de tour qui l'a posé (ex. "Frost"),
		-- force (0,6 = -60 % de vitesse, 1 = étourdi) et heure de fin (horloge de la simulation).
		controlSource = nil,
		controlFactor = 0,
		controlUntil = 0,
		-- Fatigue des contrôles courts (Mage, Trébuchet) : [type de tour] = heure jusqu'à laquelle il est immunisé
		-- contre le contrôle de ce type de tour. Créée au premier contrôle court (nil avant).
		fatigue = nil,
		-- Fragilité du Totem de givre : +fragility x 100 % de dégâts reçus jusqu'à fragileUntil.
		fragility = 0,
		fragileUntil = 0,
		-- Dégâts des projectiles déjà en vol vers lui : s'ils suffisent à le tuer, les tours visent
		-- quelqu'un d'autre (voir isDoomed). inFlight = nombre de ces projectiles.
		pending = 0,
		inFlight = 0,
		dead = false,
		spawnedAt = self.clock,
	})
end

-- Vrai s'il reste au moins un ennemi en vie sur la parcelle.
function PlotGame:anyAlive(): boolean
	for _, enemy in self.enemies do
		if not enemy.dead then
			return true
		end
	end
	return false
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

-- CONTRÔLES (règle du propriétaire : « aucun cumul de ralentissement, que ce soit fusion des deux ou entité
-- seule multipliée ») : UN SEUL effet de contrôle à la fois par ennemi, quelle que soit la tour
-- (ralentissement du Totem de givre, ralentissement du Mage des tempêtes, étourdissement du Trébuchet royal),
-- et sa force ne se multiplie jamais.
--   aucun contrôle en cours             -> le nouveau s'applique (source = type de tour, force, fin),
--                                          sauf pendant la fatigue de ce type (voir plus bas) ;
--   contrôle en cours du MÊME type      -> Totem de givre (sans immunité) : prolongé (fin la plus tardive), sa
--                                          force ne change pas : deux Totems = un seul -60 %, jamais plus ;
--                                          contrôle COURT (Mage, Trébuchet : avec une immunité) : refusé, il
--                                          n'est JAMAIS prolongé (il dure exactement sa durée) ;
--   contrôle en cours d'un AUTRE type   -> refusé tant qu'il dure (le premier arrivé garde la priorité) :
--                                          le Mage ne ralentit pas un ennemi gelé par un Totem, et inversement.
-- FATIGUE (retour du propriétaire à la vague 148 : plein de Mages avec x2 vitesse gelaient toute la vague) :
-- quand un contrôle court se termine, l'ennemi est IMMUNISÉ contre ce type de tour pendant `immunity` secondes
-- (IdleTowers : slowImmunity du Mage, stunImmunity du Trébuchet). Les Mages ne peuvent donc ralentir un ennemi
-- que slowDuration s sur (slowDuration + slowImmunity) s au plus (0,6 s sur 1,4 s avec les réglages actuels),
-- les Trébuchets l'étourdir que 0,5 s sur 2 s, quel que soit le nombre de ces tours et leurs runes.
-- L'immunité ne bloque que ce type de tour : le Totem peut geler un ennemi immunisé contre le Mage.
-- source = clé de la tour (stats.towerType), strength = 0 à 1 (1 = étourdi : vitesse 0), immunity = secondes
-- (nil ou 0 = contrôle qui dure, comme le Totem).
-- Renvoie vrai si l'effet s'applique (ou prolonge le sien), faux s'il est refusé. Les dégâts, eux, tombent
-- toujours (voir hitEnemy).
local function applyControl(enemy, source: string, strength: number, duration: number, immunity: number?, now: number): boolean
	local short = immunity ~= nil and immunity > 0
	if now < enemy.controlUntil then
		if enemy.controlSource ~= source or short then
			return false
		end
		enemy.controlUntil = math.max(enemy.controlUntil, now + duration)
		return true
	end
	local fatigue = enemy.fatigue
	if fatigue and fatigue[source] and now < fatigue[source] then
		return false
	end
	enemy.controlSource = source
	enemy.controlFactor = math.clamp(strength, 0, 1)
	enemy.controlUntil = now + duration
	if short then
		-- Jamais prolongé : la fin est connue dès maintenant, l'immunité part de là.
		if not fatigue then
			fatigue = {}
			enemy.fatigue = fatigue
		end
		fatigue[source] = enemy.controlUntil + immunity
	end
	return true
end

-- Fragilité du Totem de givre (ce n'est PAS un contrôle : elle s'applique même pendant le contrôle d'une autre
-- tour). Deux Totems ne s'additionnent pas : une fragilité plus forte remplace l'actuelle, une égale la
-- prolonge, une plus faible est ignorée tant que l'actuelle dure.
local function applyFragility(enemy, fragility: number, duration: number, now: number)
	if fragility <= 0 then
		return
	end
	if now >= enemy.fragileUntil or fragility > enemy.fragility then
		enemy.fragility = fragility
		enemy.fragileUntil = now + duration
	elseif fragility == enemy.fragility then
		enemy.fragileUntil = math.max(enemy.fragileUntil, now + duration)
	end
end

-- Vitesse actuelle en fraction de la vitesse normale du mode infini : type x contrôle (0 si étourdi).
local function speedFactorOf(enemy, now: number): number
	local controlFactor = if now < enemy.controlUntil then 1 - enemy.controlFactor else 1
	return enemy.speedScale * controlFactor
end

-- Inflige `amount` dégâts. fragile = ces dégâts profitent de la fragilité du Totem de givre (toutes les tours
-- sauf celles marquées ignoresFragility : le Mage des tempêtes et les Totems eux-mêmes) : x (1 + fragilité)
-- tant qu'elle dure. Les outils de test (debugKill) passent faux.
function PlotGame:damageEnemy(enemy, amount: number, fragile: boolean?)
	if enemy.dead then
		return
	end
	if fragile and self.clock < enemy.fragileUntil then
		amount *= 1 + enemy.fragility
	end
	enemy.health -= amount
	if enemy.health <= 0 then
		enemy.dead = true
		-- Sa mort fait sortir le prochain ennemi de la file tout de suite (au début du prochain pas, voir simulate).
		if IdleConfig.SPAWN_NEXT_ON_KILL then
			self.spawnReleases += 1
		end
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
-- targetId = id de l'ennemi que le projectile suit (IdleTowers.followsTarget), rien ou 0 = aucun.
function PlotGame:addShot(from: Vector3, to: Vector3, towerType: string, radius: number, landsAt: number, targetId: number?)
	if #self.shots < IdleConfig.MAX_SHOTS_PER_PACKET then
		table.insert(self.shots, { from = from, to = to, type = TOWER_INDEX[towerType], radius = radius, landsAt = landsAt, targetId = targetId or 0 })
	end
end

-- Stats d'une tour posée : niveau, doublons et runes (dégâts ET vitesse) compris. Gardées sur la tour tant
-- que rien ne change (le rayon du Sorcier en a besoin à chaque pas de simulation). tower.runeKey = texte de
-- ses runes (IdleConfig.runeList), mis à jour à chaque pose (setRunes).
function PlotGame:statsOf(tower)
	local dupes = self.idle.towerDupes[tower.type] or 0
	if not tower.stats or tower.statsLevel ~= tower.level or tower.statsDupes ~= dupes or tower.statsRunes ~= tower.runeKey then
		tower.stats = IdleTowers.effectiveStats(tower.type, tower.level, dupes, tower.runeKey)
		tower.statsLevel = tower.level
		tower.statsDupes = dupes
		tower.statsRunes = tower.runeKey
	end
	return tower.stats
end

-- Condamné : les projectiles déjà en vol vers lui suffiront à le tuer.
local function isDoomed(enemy): boolean
	return enemy.pending >= enemy.health
end

-- Cible d'une tour à portée : la plus avancée (« First ») ou la plus résistante (« Strongest »). Le Trébuchet
-- (« Crowd ») a sa propre visée : pickCrowdTarget. La Baliste lourde part du plus résistant, puis choisit
-- parmi les ennemis presque aussi résistants que lui (pickPierceTarget).
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

-- Un coup sur un ennemi : dégâts de la tour, et son contrôle si elle en a un (ralentissement du Mage,
-- étourdissement du Trébuchet), s'il n'est pas refusé par la règle des contrôles (ou par la fatigue). Les
-- dégâts tombent toujours.
function PlotGame:hitEnemy(enemy, stats, now: number)
	if stats.slow then
		applyControl(enemy, stats.towerType, stats.slow, stats.slowDuration, stats.slowImmunity, now)
	end
	if stats.stunDuration then
		applyControl(enemy, stats.towerType, 1, stats.stunDuration, stats.stunImmunity, now)
	end
	self:damageEnemy(enemy, stats.damage, not stats.ignoresFragility)
end

-- Un coup de zone : tous les ennemis vivants à moins de stats.splash studs du point d'impact.
function PlotGame:hitArea(center: Vector3, stats, now: number)
	for _, enemy in self.enemies do
		if not enemy.dead and horizontalDistance(center, enemy.position) <= stats.splash then
			self:hitEnemy(enemy, stats, now)
		end
	end
end

-- Distance (à plat) entre un point et le segment [a, b].
local function segmentDistance(point: Vector3, a: Vector3, b: Vector3): number
	local abx, abz = b.X - a.X, b.Z - a.Z
	local apx, apz = point.X - a.X, point.Z - a.Z
	local lengthSquared = abx * abx + abz * abz
	local t = if lengthSquared > 0 then math.clamp((apx * abx + apz * abz) / lengthSquared, 0, 1) else 0
	local dx, dz = apx - abx * t, apz - abz * t
	return math.sqrt(dx * dx + dz * dz)
end

-- Avancée d'un point le long du segment [a, b], vue depuis a (produit scalaire, à plat) : plus elle est petite,
-- plus tôt un carreau parti de a rencontre ce point. Sert seulement à comparer des points sur le même segment.
local function alongSegment(point: Vector3, a: Vector3, b: Vector3): number
	return (point.X - a.X) * (b.X - a.X) + (point.Z - a.Z) * (b.Z - a.Z)
end

-- Rangement des ennemis d'une ligne (hitLine) : le premier rencontré par le carreau d'abord ; à égalité (ennemis
-- au même endroit), le premier de la liste des ennemis. Toujours le même choix pour la même situation.
local function byAlongThenIndex(a, b): boolean
	if a.along ~= b.along then
		return a.along < b.along
	end
	return a.index < b.index
end

-- Carreau perçant (Baliste lourde). Il transperce AU PLUS IdleTowers.BALLISTA_PIERCE_MAX ennemis (« transperce
-- 3 max », décision du propriétaire) : sa cible si elle vit encore (touchée où qu'elle soit, comme une flèche :
-- un ralentissement arrivé pendant le vol ne lui fait pas éviter le carreau), plus les PREMIERS ennemis vivants
-- que le carreau rencontre à moins de stats.pierceWidth studs du segment origine (la tour) -> point d'impact :
-- les plus proches de la tour le long du trait (alongSegment) ; à égalité, le premier de la liste des ennemis.
-- Une cible morte pendant le vol laisse sa place à un ennemi de la ligne. Chacun une seule fois ; les coups
-- tombent dans l'ordre de la liste des ennemis (comme avant : rien ne change quand la ligne n'est pas pleine).
function PlotGame:hitLine(origin: Vector3, impactPoint: Vector3, stats, target, now: number)
	-- Les autres ennemis sur la ligne : { ennemi, avancée le long du trait, rang dans la liste }.
	local onLine = {}
	for index, enemy in self.enemies do
		if enemy ~= target and not enemy.dead and segmentDistance(enemy.position, origin, impactPoint) <= stats.pierceWidth then
			table.insert(onLine, { enemy = enemy, along = alongSegment(enemy.position, origin, impactPoint), index = index })
		end
	end
	-- Places pour eux : la cible vivante prend toujours la sienne.
	local places = math.max(0, IdleTowers.BALLISTA_PIERCE_MAX - (if target.dead then 0 else 1))
	if #onLine > places then
		-- Trop d'ennemis sur la ligne : seulement les premiers que le carreau rencontre.
		table.sort(onLine, byAlongThenIndex)
	end
	local struck = {}
	for i = 1, math.min(places, #onLine) do
		struck[onLine[i].enemy] = true
	end
	for _, enemy in self.enemies do
		if not enemy.dead and (enemy == target or struck[enemy]) then
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

-- Distance que l'ennemi aura parcourue dans `seconds` secondes de simulation : à sa vitesse ralentie (ou 0
-- s'il est étourdi) tant que son contrôle actuel dure, puis à sa vitesse normale (celle de son type). Les
-- contrôles qui arriveront pendant le vol ne se devinent pas.
local function travelDistance(enemy, now: number, seconds: number): number
	local speed = enemy.def.speed * IdleConfig.ENEMY_SPEED_MULTIPLIER * enemy.speedScale
	local slowed = if now < enemy.controlUntil then math.min(seconds, enemy.controlUntil - now) else 0
	return speed * (slowed * (1 - enemy.controlFactor) + (seconds - slowed))
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

-- Trébuchet royal (« Crowd ») : vise le point du chemin où sa zone touchera le PLUS d'ennemis. Chaque ennemi
-- à portée est un point d'impact possible : on prévoit où il sera à l'arrivée de la pierre (visée anticipée,
-- comme les autres projectiles), puis on compte les ennemis NON condamnés qui seront à moins de stats.splash
-- studs de ce point au même moment (positions prévues avec le même temps de vol). Le plus grand nombre
-- gagne ; à égalité, le groupe le plus avancé sur le chemin. Renvoie (cible, point visé, temps de vol), ou
-- nil si aucun tir ne toucherait un ennemi non condamné (il attend, comme les autres projectiles).
-- Au plus ~80 x 80 comparaisons, une fois par tir (toutes les 5 s) : les ennemis trop loin pour entrer dans
-- la zone pendant le vol sont écartés sans calcul de position, et la position prévue d'un ennemi est gardée
-- pour les candidats qui ont (presque) le même temps de vol (CROWD_FLIGHT_STEP) : plusieurs Trébuchets
-- qui tirent au même moment sur une foule de 80 ennemis ne font pas ramer le serveur.
local CROWD_FLIGHT_STEP = 0.05 -- s ; écart de position < 0,5 stud (ennemis à 13 studs/s au plus), zone : 9
function PlotGame:pickCrowdTarget(tower, stats, muzzle: Vector3, now: number): (any, Vector3?, number)
	local candidates, counted = {}, {}
	for _, enemy in self.enemies do
		if not enemy.dead then
			if horizontalDistance(tower.position, enemy.position) <= stats.range then
				table.insert(candidates, enemy)
			end
			if not isDoomed(enemy) then
				table.insert(counted, enemy)
			end
		end
	end
	if #candidates == 0 or #counted == 0 then
		return nil, nil, 0
	end
	local function speedOf(enemy)
		return enemy.def.speed * IdleConfig.ENEMY_SPEED_MULTIPLIER * enemy.speedScale
	end
	-- Positions prévues des ennemis comptés, rangées par temps de vol arrondi à CROWD_FLIGHT_STEP.
	local predicted = {}
	local function predictedAt(other, flight: number): Vector3
		local step = math.floor(flight / CROWD_FLIGHT_STEP + 0.5)
		local positions = predicted[step]
		if not positions then
			positions = {}
			predicted[step] = positions
		end
		local at = positions[other]
		if not at then
			at = self:pathPoint(other.distance + travelDistance(other, now, step * CROWD_FLIGHT_STEP))
			positions[other] = at
		end
		return at
	end
	local best, bestAim, bestFlight, bestCount, bestAhead = nil, nil, 0, 0, -math.huge
	for _, candidate in candidates do
		local aim, flight = self:predictImpact(candidate, muzzle, stats, now)
		local candidateMove = speedOf(candidate) * flight
		local count = 0
		for _, other in counted do
			-- Écart maximal possible à l'arrivée : écart actuel moins ce que les deux peuvent parcourir.
			if horizontalDistance(candidate.position, other.position) - candidateMove - speedOf(other) * flight <= stats.splash then
				if horizontalDistance(aim, predictedAt(other, flight)) <= stats.splash then
					count += 1
				end
			end
		end
		local ahead = candidate.distance + travelDistance(candidate, now, flight)
		if count > bestCount or (count == bestCount and count > 0 and ahead > bestAhead) then
			best, bestAim, bestFlight, bestCount, bestAhead = candidate, aim, flight, count, ahead
		end
	end
	return best, bestAim, bestFlight
end

-- Baliste lourde : combien d'ennemis le carreau tiré sur `candidate` transpercera. Le carreau va de la tour
-- (origin) au point visé (aim, visée anticipée de predictImpact, temps de vol `flight`) : il touche sa cible,
-- plus chaque ennemi NON condamné qui sera à moins de stats.pierceWidth studs de ce segment à l'arrivée
-- (position prévue avec le même temps de vol, comme le Trébuchet ; un ennemi condamné mourra de toute façon :
-- le toucher ne sert à rien). Un ennemi trop loin du segment pour s'en approcher pendant le vol est écarté
-- sans calcul de position. Aucune table créée : ce calcul tourne à chaque tir de Baliste.
-- Jamais plus de IdleTowers.BALLISTA_PIERCE_MAX (le carreau n'en transperce pas plus, voir hitLine) : 3 alignés
-- ou plus, c'est pareil pour sa visée (à égalité, le plus résistant, voir pickPierceTarget).
function PlotGame:countPierced(candidate, origin: Vector3, aim: Vector3, flight: number, stats, now: number): number
	local width = stats.pierceWidth
	local limit = IdleTowers.BALLISTA_PIERCE_MAX
	local count = 1 -- sa cible : toujours touchée (hitLine)
	for _, other in self.enemies do
		if count >= limit then
			break -- ligne pleine : le carreau n'en transpercera pas plus
		end
		if other ~= candidate and not other.dead and not isDoomed(other) then
			-- Distance parcourue au plus pendant le vol : sa vitesse normale (un ralentissement ne fait qu'en retirer).
			local reach = other.def.speed * IdleConfig.ENEMY_SPEED_MULTIPLIER * other.speedScale * flight
			if segmentDistance(other.position, origin, aim) - reach <= width then
				local at = self:pathPoint(other.distance + travelDistance(other, now, flight))
				if segmentDistance(at, origin, aim) <= width then
					count += 1
				end
			end
		end
	end
	return count
end

-- Baliste lourde (« viser le plus gros monstre ok, mais si plusieurs monstres sont pareils, essayer de faire la
-- meilleure zone », demande du propriétaire). `strongest` = le plus résistant à portée et pas condamné
-- (pickTarget). Sont « pareils » les ennemis à portée, pas condamnés, qui ont au moins
-- IdleTowers.BALLISTA_TIE_RATIO fois ses PV (lui compris). Parmi eux, elle vise celui dont le carreau en
-- transpercera le PLUS (countPierced, IdleTowers.BALLISTA_PIERCE_MAX au plus : 3 alignés ou plus, c'est pareil) ;
-- à nombre égal, le plus résistant, puis le premier de la liste des ennemis (la règle d'avant). Un ennemi bien
-- plus résistant que tous les autres reste donc toujours sa cible.
-- Au plus IdleTowers.BALLISTA_MAX_CANDIDATES ennemis comparés : le plus résistant d'abord, puis dans l'ordre de
-- la liste des ennemis (toujours le même choix pour la même situation). Renvoie (cible, point visé, temps de
-- vol), déjà calculés pour fireProjectile.
function PlotGame:pickPierceTarget(tower, stats, strongest, muzzle: Vector3, now: number): (any, Vector3, number)
	local origin = tower.position
	local bestAim, bestFlight = self:predictImpact(strongest, muzzle, stats, now)
	local best, bestCount = strongest, self:countPierced(strongest, origin, bestAim, bestFlight, stats, now)
	local threshold = strongest.health * IdleTowers.BALLISTA_TIE_RATIO
	local compared = 1
	for _, enemy in self.enemies do
		if compared >= IdleTowers.BALLISTA_MAX_CANDIDATES then
			break
		end
		if
			enemy ~= strongest
			and not enemy.dead
			and enemy.health >= threshold
			and not isDoomed(enemy)
			and horizontalDistance(origin, enemy.position) <= stats.range
		then
			compared += 1
			local aim, flight = self:predictImpact(enemy, muzzle, stats, now)
			local count = self:countPierced(enemy, origin, aim, flight, stats, now)
			if count > bestCount or (count == bestCount and enemy.health > best.health) then
				best, bestAim, bestFlight, bestCount = enemy, aim, flight, count
			end
		end
	end
	return best, bestAim, bestFlight
end

-- Lance un projectile : les dégâts tomberont dans `flight` secondes (de simulation) au point prévu.
-- Les stats sont celles du moment du tir (une amélioration pendant le vol ne change pas ce projectile).
-- aim / flight : point visé et temps de vol déjà calculés (Trébuchet), sinon visée anticipée sur `target`.
function PlotGame:fireProjectile(tower, stats, target, muzzle: Vector3, now: number, aim: Vector3?, flight: number?)
	if not aim or not flight then
		aim, flight = self:predictImpact(target, muzzle, stats, now)
	end
	target.pending += stats.damage
	target.inFlight += 1
	table.insert(self.impacts, {
		at = now + flight,
		spot = tower.spotIndex,
		origin = tower.position, -- départ du carreau perçant (Baliste)
		target = target,
		position = aim,
		stats = stats,
	})
	-- Rayon envoyé au client : la zone (Catapulte, Trébuchet) ; 0 pour une flèche ou le carreau perçant.
	-- Projectile qui suit sa cible : son id, pour que le client le fasse voler vers elle (voir impactCenter).
	local followId = if IdleTowers.followsTarget(stats) then target.id else 0
	self:addShot(muzzle, aim, tower.type, stats.splash or 0, now + flight, followId)
end

-- Où tombe l'effet d'un projectile à l'impact. Archer, Catapulte, Baliste (IdleTowers.followsTarget) : il SUIT
-- sa cible (bug vu par le propriétaire : la Catapulte visait avant de savoir le ralentissement que l'ennemi
-- allait prendre pendant le vol, et tirait trop loin) : sa position RÉELLE si elle vit encore et n'est pas à
-- plus de IdleTowers.followDistance studs du point prévu au tir ; sinon le point prévu. Le Trébuchet royal
-- (« Crowd ») garde toujours son point prévu (il vise une foule).
local function impactCenter(impact): Vector3
	local target, stats = impact.target, impact.stats
	if
		not target.dead
		and IdleTowers.followsTarget(stats)
		and horizontalDistance(target.position, impact.position) <= IdleTowers.followDistance(stats)
	then
		return target.position
	end
	return impact.position
end

-- Arrivée d'un projectile. « Centre » = là où tombe son effet (impactCenter : sa cible s'il la suit, sinon le
-- point prévu au tir).
--   Zone (Catapulte, Trébuchet) : tous les ennemis autour du centre à cet instant.
--   Carreau perçant (Baliste) : sa cible et les premiers ennemis sur la ligne tour -> centre, 3 au plus (hitLine).
--   Flèche : sa cible si elle vit encore (où qu'elle soit) ; si elle est morte pendant le vol, l'ennemi
--   vivant le plus proche du point prévu à moins de PROJECTILE_CATCH_RADIUS studs, sinon rien.
--   Flèche enflammée : une zone de feu au centre, touchée ou non.
function PlotGame:landImpact(impact, now: number)
	local stats, target = impact.stats, impact.target
	target.inFlight -= 1
	-- Plus rien en vol vers lui : exactement 0. Sans ça, additionner puis retirer des dégâts très
	-- différents (1e20 et 7) laisse un petit reste qui pourrait le faire croire « condamné » à tort
	-- (ou l'infini, avec des dégâts énormes) : les tours à projectile l'ignoreraient pour toujours.
	target.pending = if target.inFlight <= 0 then 0 else math.max(0, target.pending - stats.damage)
	local center = impactCenter(impact)
	if stats.kind == "Splash" then
		self:hitArea(center, stats, now)
	elseif stats.kind == "Pierce" then
		self:hitLine(impact.origin, center, stats, target, now)
	else
		local victim = if target.dead then self:enemyNear(impact.position, IdleTowers.PROJECTILE_CATCH_RADIUS) else target
		if victim then
			self:hitEnemy(victim, stats, now)
		end
	end
	if stats.fireRadius then
		self:addFirePatch(impact.spot, center, stats, now)
	end
	if self.debugHold then
		-- Tests Studio : où était la cible au moment de l'impact, comparé au point visé (aim) et au centre de
		-- l'effet (center : sa position si le projectile la suit).
		self.debugImpactInfo = {
			at = impact.at,
			landedAt = now,
			aim = impact.position,
			center = center,
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
		fragile = not stats.ignoresFragility, -- le feu de l'Archer profite de la fragilité du Totem
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
					self:damageEnemy(enemy, amount, patch.fragile)
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
	self:damageEnemy(target, stats.damage * IdleTowers.beamRamp(stats, startTime + dt / 2) * dt, not stats.ignoresFragility)
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
				-- Totem de givre : ralentit fortement tout ce qui est dans l'aura (un contrôle : refusé si une
				-- autre tour contrôle déjà l'ennemi) et le rend fragile (toujours), puis de petits dégâts (qui, eux,
				-- ne profitent pas de la fragilité : ignoresFragility, voir IdleTowers.luau).
				if stats.slow then
					applyControl(enemy, stats.towerType, stats.slow, stats.slowDuration, stats.slowImmunity, now)
				end
				applyFragility(enemy, stats.fragility or 0, stats.fragilityDuration or stats.slowDuration or 0, now)
				self:damageEnemy(enemy, stats.damage, not stats.ignoresFragility)
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
			self:damageEnemy(enemy, stats.damage, not stats.ignoresFragility)
		end
		return true
	end

	-- Trébuchet royal : le plus gros groupe à portée (positions prévues à l'impact).
	if stats.targeting == "Crowd" then
		local target, aim, flight = self:pickCrowdTarget(tower, stats, muzzle, now)
		if not target then
			return false
		end
		self:fireProjectile(tower, stats, target, muzzle, now, aim, flight)
		return true
	end

	-- Une cible (« Single »), une zone autour d'elle (« Splash ») ou un carreau perçant (« Pierce »). Les tours
	-- à projectile ne visent jamais un ennemi condamné : elles attendent plutôt une autre cible.
	local projectile = IdleTowers.isProjectile(stats)
	local target = self:pickTarget(tower, stats, not projectile)
	if not target then
		return false
	end
	if projectile then
		if stats.kind == "Pierce" and stats.targeting == "Strongest" then
			-- Baliste lourde : parmi les ennemis presque aussi résistants que le plus résistant, celui dont le
			-- carreau en transpercera le plus (point visé et temps de vol déjà calculés).
			local aim, flight
			target, aim, flight = self:pickPierceTarget(tower, stats, target, muzzle, now)
			self:fireProjectile(tower, stats, target, muzzle, now, aim, flight)
			return true
		end
		self:fireProjectile(tower, stats, target, muzzle, now)
		return true
	end
	-- Tir instantané (Mage des tempêtes) : la foudre tombe tout de suite sur la cible (et, pour une zone,
	-- sur les ennemis collés à elle : dégâts et ralentissement pour tous).
	local impact = target.position
	if stats.kind == "Splash" then
		self:hitArea(impact, stats, now)
	elseif stats.kind == "Pierce" then
		self:hitLine(tower.position, impact, stats, target, now)
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

	-- Apparitions. Un ennemi sort à son heure (item.at - spawnSkipped) OU en avance quand un ennemi est mort
	-- (IdleConfig.SPAWN_NEXT_ON_KILL) : chaque mort des pas d'avant (spawnReleases) fait sortir UN ennemi de la
	-- file tout de suite, même si d'autres sont encore en vie ; l'attente qui lui restait est sautée et toute la
	-- suite de la file avance d'autant (spawnSkipped), les écarts entre les suivants ne changent pas.
	-- Vague écrasée (IdleConfig.COMPRESS_EMPTY_SPAWNS) : quand plus AUCUN ennemi n'est en vie, qu'il en reste à
	-- faire apparaître et qu'aucune mort n'attend son ennemi, le suivant sort aussi à ce pas (même décalage).
	-- Horloge de la simulation : marche pareil en Vitesse x2. Une vague tuée d'un coup se termine ainsi en ~1 pas
	-- par ennemi.
	if
		IdleConfig.COMPRESS_EMPTY_SPAWNS
		and self.spawnReleases == 0
		and self.spawnIndex <= #self.spawnQueue
		and not self:anyAlive()
	then
		local waitLeft = self.spawnQueue[self.spawnIndex].at - self.spawnSkipped - now
		if waitLeft > 0 then
			self.spawnSkipped += waitLeft
		end
	end
	while self.spawnIndex <= #self.spawnQueue and #self.enemies < IdleConfig.MAX_ENEMIES do
		local item = self.spawnQueue[self.spawnIndex]
		if item.at - self.spawnSkipped > now + TIME_EPSILON then
			if self.spawnReleases <= 0 then
				break
			end
			-- Pas encore son heure, mais un ennemi est mort : il sort maintenant.
			self.spawnReleases -= 1
			self.spawnSkipped += item.at - self.spawnSkipped - now
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

-- Octet « contrôle » d'un ennemi (voir en haut du fichier) : numéro de la tour qui le contrôle (0 = aucune)
-- + CONTROL_FRAGILE_FLAG s'il est fragile.
local function controlByte(enemy, now: number): number
	local value = 0
	if now < enemy.controlUntil and enemy.controlSource then
		value = TOWER_INDEX[enemy.controlSource] or 0
	end
	if now < enemy.fragileUntil and enemy.fragility > 0 then
		value += CONTROL_FRAGILE_FLAG
	end
	return value
end

-- Positions de tous les ennemis vivants, encodées dans un buffer. nil si rien à envoyer.
-- count x ENEMY_BYTES octets, puis count octets « contrôle » (même ordre).
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
	local controlStart = count * ENEMY_BYTES
	local packet = buffer.create(controlStart + count)
	for i, enemy in self.enemies do
		local offset = (i - 1) * ENEMY_BYTES
		local speedFactor = speedFactorOf(enemy, now)
		buffer.writeu32(packet, offset, enemy.id)
		buffer.writeu8(packet, offset + 4, enemy.typeIndex)
		buffer.writef32(packet, offset + 5, enemy.distance)
		buffer.writeu8(packet, offset + 9, math.clamp(math.ceil(enemy.health / enemy.maxHealth * 255), 0, 255))
		buffer.writeu8(packet, offset + 10, math.clamp(math.floor(speedFactor * 100 + 0.5), 0, 255))
		buffer.writeu8(packet, controlStart + i - 1, controlByte(enemy, now))
	end
	return packet, count
end

-- Tirs depuis le dernier paquet. count x SHOT_BYTES octets, puis count x SHOT_TARGET_BYTES octets (id de la
-- cible suivie, même ordre ; voir en haut du fichier).
function PlotGame:takeShotsPacket(): (buffer?, number)
	local count = #self.shots
	if count == 0 then
		return nil, 0
	end
	local targetStart = count * SHOT_BYTES
	local packet = buffer.create(targetStart + count * SHOT_TARGET_BYTES)
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
		-- Cible suivie (0 = aucune).
		buffer.writeu32(packet, targetStart + (i - 1) * SHOT_TARGET_BYTES, shot.targetId or 0)
	end
	table.clear(self.shots)
	return packet, count
end

----------------------------------------------------------------------
-- Tours et emplacements (actions du joueur)
----------------------------------------------------------------------

-- runes = runes déjà posées (sauvegarde : { Damage = id, Speed = id }, voir IdleConfig.runeIds), rien = aucune.
-- Un id inconnu est ignoré, chaque rune va dans l'emplacement de sa sorte.
function PlotGame:createTower(spotIndex: number, towerType: string, level: number, spent: number, runes: any?)
	local runeIds = IdleConfig.runeIds(runes)
	local runeKey = IdleConfig.runeList(runeIds)
	-- cframe = position de la tour pour le combat (portées, départ des tirs) : inchangée. Le MODÈLE, lui, est posé
	-- sur le socle surélevé de l'emplacement (PlotLayout.SPOT_PAD_HEIGHT) : seulement l'affichage.
	local cframe = PlotLayout.worldCFrame(self.index, PlotLayout.SPOTS[spotIndex] + Vector3.new(0, 0.3, 0))
	local modelCFrame = PlotLayout.worldCFrame(self.index, PlotLayout.SPOTS[spotIndex] + Vector3.new(0, PlotLayout.SPOT_PAD_HEIGHT, 0))
	local model = IdleTowerModel.create(towerType, modelCFrame, self.towerFolder, {
		SpotIndex = spotIndex,
		PlotIndex = self.index,
		Level = level,
		Spent = spent,
		-- Runes posées, ex. "Damage20,Speed2" (IdleConfig.runeList) : lues par PlotUI et par le tableau du fief.
		Bonus = runeKey,
	})
	self.towers[spotIndex] = {
		spotIndex = spotIndex,
		type = towerType,
		level = level,
		spent = spent,
		position = cframe.Position,
		cooldown = 0,
		model = model,
		runes = runeIds, -- { Damage = id, Speed = id } : une rune par emplacement
		runeKey = runeKey, -- même chose en texte (attribut « Bonus », cache de statsOf)
	}
	self:saveTower(self.towers[spotIndex])
	self:publishForge() -- les runes tirables dépendent des tours posées
end

function PlotGame:saveTower(tower)
	self.idle.towers[tostring(tower.spotIndex)] = {
		type = tower.type,
		level = tower.level,
		spent = tower.spent,
		runes = table.clone(tower.runes),
	}
end

-- Runes d'une tour changées : texte republié (attribut « Bonus » du modèle, cache de statsOf) et sauvegarde.
function PlotGame:setRunes(tower)
	tower.runeKey = IdleConfig.runeList(tower.runes)
	tower.model:SetAttribute("Bonus", tower.runeKey)
	self:saveTower(tower)
end

-- Retire la tour. Ses runes retournent dans l'inventaire (dégâts d'abord, puis vitesse), tant qu'il y a de la
-- place ; celles qui n'ont pas de place sont perdues (la confirmation de remplacement le dit, PlotUI).
function PlotGame:removeTower(spotIndex: number)
	local tower = self.towers[spotIndex]
	if not tower then
		return
	end
	for _, slot in IdleConfig.RUNE_SLOTS do
		local runeId = tower.runes[slot.kind]
		if runeId and #self.idle.bonuses < IdleConfig.MAX_BONUS_INVENTORY then
			table.insert(self.idle.bonuses, runeId)
		end
	end
	tower.model:Destroy()
	self.towers[spotIndex] = nil
	self.idle.towers[tostring(spotIndex)] = nil
	self:publishInventory() -- runes rendues, et runes tirables par la forge sans cette tour
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
-- Limite de tours identiques (IdleTowers.MAX_COPIES : 5 par tour commune, 4 rare, 3 épique, 2 légendaire) : une
-- pose de trop est refusée avec un message clair, sans rien dépenser. Remplacement : la tour remplacée ne compte
-- que si elle est du même type (remplacer un Oracle par un Trébuchet compte les Trébuchets). Les tours déjà
-- posées au-delà de la limite (vieilles sauvegardes) restent : voir loadTowers.
-- Renvoie true si la tour est posée, sinon false et le message du refus (lu par les tests Studio).
function PlotGame:placeTower(spotIndex: any, towerType: any, replaceType: any): (boolean, string?)
	if not self:ownsSpot(spotIndex) or typeof(towerType) ~= "string" or not IdleTowers.Defs[towerType] then
		return false, nil
	end
	local def = IdleTowers.Defs[towerType]
	local function refuse(message: string, kind: string): (boolean, string?)
		self:notify(message, kind)
		return false, message
	end
	if not self.idle.unlockedTowers[towerType] then
		return refuse(`{def.displayName} n'est pas encore débloquée : invoque-la à l'autel des héros !`, "Error")
	end
	local existing = self.towers[spotIndex]
	if existing and existing.type == towerType then
		return refuse("Cette tour est déjà posée ici", "Error")
	end
	if existing and replaceType ~= existing.type then
		return refuse("Il y a déjà une tour ici : clique dessus puis « Remplacer… »", "Warning")
	end
	if not IdleTowers.canPlaceCopy(self:countCopies(), towerType, existing and existing.type) then
		return refuse(IdleTowers.copiesLimitMessage(towerType), "Error")
	end
	local refund = if existing then math.floor(existing.spent * IdleConfig.SELL_REFUND) else 0
	if self.data.coins + refund < def.placeCost then
		return refuse("Pas assez de pièces", "Error")
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
	return true, nil
end

-- Nombre de tours posées de chaque type sur la parcelle : { [type] = nombre } (limite de tours identiques).
function PlotGame:countCopies(): { [string]: number }
	return IdleTowers.countCopies(self.towers)
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
	-- Lancers de l'autel achetés depuis toujours : l'autel affiche les prix exacts (IdleConfig.towerSpinCost).
	-- Seulement pour l'affichage : le serveur calcule toujours les prix avec SES données.
	player:SetAttribute("TowerSpinsBought", IdleConfig.cleanSpinsBought(self.idle.towerSpinsBought))
	self:publishForge()
end

----------------------------------------------------------------------
-- Forge runique (réglages et formules : IdleConfig, « Forge runique »)
----------------------------------------------------------------------

-- Runes que la forge peut tirer maintenant, et la raison du blocage (nil si au moins une rune est tirable).
-- Chaque tour posée a 2 emplacements (dégâts, vitesse) : une rune est tirable si elle améliore au moins une
-- tour posée DANS L'EMPLACEMENT DE SA SORTE (plus petite valeur de chaque sorte : IdleConfig.weakestRunes ;
-- l'inventaire ne compte pas). Voir IdleConfig.forgeDrawableRunes.
function PlotGame:forgeDrawable()
	local placed = {}
	for _, tower in self.towers do
		table.insert(placed, tower.runes)
	end
	return IdleConfig.forgeDrawableRunes(IdleConfig.weakestRunes(placed))
end

-- État de la forge publié en attributs du joueur (lus par la forge du client, MachineUI) :
--   ForgeSpinsBought : lancers en pièces achetés depuis toujours (jamais remis à zéro) ;
--   ForgeCoinPrice   : prix du prochain lancer en pièces (IdleConfig.forgeCoinPrice), -1 = « MAX » ;
--   ForgeDrawable    : ids des runes tirables maintenant, séparés par des virgules, dans l'ordre de
--                      IdleConfig.BONUSES (ex. "Speed2,Damage3,Damage5,Damage10,Damage20"
--                      quand toutes les tours ont déjà x2 dégâts ou mieux) ; chances affichées =
--                      IdleConfig.forgeOdds (remises sur 100 %) ;
--   ForgeBlocked     : "" si la forge marche, sinon le message à afficher (IdleConfig.FORGE_NO_TOWER, ou
--                      FORGE_ALL_BEST : x20 dégâts ET x2 vitesse sur toutes les tours posées) : boutons
--                      pièces ET Robux bloqués.
-- Seulement pour l'affichage : le serveur revérifie tout à chaque lancer (spinBonusWithCoins).
function PlotGame:publishForge()
	local player = self.player
	local bought = IdleConfig.cleanSpinsBought(self.idle.forgeSpinsBought)
	local price = IdleConfig.forgeCoinPrice(bought)
	local drawable, blocked = self:forgeDrawable()
	local ids = {}
	for _, bonus in drawable do
		table.insert(ids, bonus.id)
	end
	player:SetAttribute("ForgeSpinsBought", bought)
	player:SetAttribute("ForgeCoinPrice", if price < math.huge then price else -1)
	player:SetAttribute("ForgeDrawable", table.concat(ids, ","))
	player:SetAttribute("ForgeBlocked", blocked or "")
end

-- État de la forge (tests Studio) : { bought, price, drawable = { ids }, blocked }.
function PlotGame:forgeState()
	local drawable, blocked = self:forgeDrawable()
	local ids = {}
	for _, bonus in drawable do
		table.insert(ids, bonus.id)
	end
	local bought = IdleConfig.cleanSpinsBought(self.idle.forgeSpinsBought)
	return { bought = bought, price = IdleConfig.forgeCoinPrice(bought), drawable = ids, blocked = blocked }
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
--   { machine = "Tower", count, tower, rarity, isNew, dupes, results = { { tower, rarity, count, isNew } }, source }
-- tower/rarity/isNew/dupes = la tour la plus marquante (la plus rare ; à rareté égale, une nouvelle) ;
-- results = une ligne par tour obtenue, de la plus rare à la plus commune ; source = "Coins" (lancers payés)
-- ou "Challenge" (offerts par un défi classé, grantFreeTowerSpins). nil si l'achat est refusé.
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
	return self:rollTowerSpins(count, "Coins")
end

-- Lancers de l'autel OFFERTS (récompense d'un défi classé, Hub/ChallengeRewards.luau) : gratuits, aux mêmes
-- chances que des lancers payés (palier de ton record), et le compteur des lancers achetés
-- (idle.towerSpinsBought) ne bouge pas : le prochain lancer payé coûte exactement pareil.
-- count = nombre entier de lancers (au plus PlotGame.MAX_FREE_TOWER_SPINS). Renvoie le résultat (format :
-- spinTower, avec source = "Challenge"), nil si count est invalide.
PlotGame.MAX_FREE_TOWER_SPINS = 1000
function PlotGame:grantFreeTowerSpins(count: any)
	if typeof(count) ~= "number" or count ~= count or count < 1 or count ~= math.floor(count) or count > PlotGame.MAX_FREE_TOWER_SPINS then
		return nil
	end
	return self:rollTowerSpins(count, "Challenge")
end

-- Tire `count` lancers de l'autel (déjà payés ou offerts) aux chances du palier de ton RECORD et les ajoute :
-- tours débloquées, doublons. Ne touche ni aux pièces ni au compteur des lancers achetés (spinTower s'en
-- occupe pour les lancers payés). source = "Coins" (payés) ou "Challenge" (offerts par un défi classé).
-- Envoie et renvoie le résultat (voir spinTower).
function PlotGame:rollTowerSpins(count: number, source: string)
	local record = self.idle.highestWave
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
		source = source,
	}
	self:sendResult(result)
	return result
end

-- Tire une rune parmi celles qui améliorent au moins une tour posée dans l'emplacement de leur sorte (dégâts
-- ou vitesse, voir forgeDrawable ; chances remises sur 100 %) et la met dans l'inventaire. source = "Coins"
-- (lancer payé en pièces, déjà vérifié par spinBonusWithCoins), "Robux" (achat livré par Monetization.luau)
-- ou "Challenge" (lancer offert par un défi classé, Hub/ChallengeRewards.luau : il marche comme un lancer Robux).
-- Achat Robux quand la forge est bloquée (aucune rune n'améliorerait une tour : le client bloque le bouton,
-- mais un reçu peut quand même arriver, ex. tour vendue pendant l'achat) : la MEILLEURE rune
-- (IdleConfig.bestRune, x20 dégâts) est donnée, pour que l'achat ne soit jamais perdu. Pareil pour un lancer
-- offert quand les 2 emplacements de toutes les tours posées ont déjà la meilleure rune de leur sorte (x20
-- dégâts ou plus, x2 vitesse). Mais un lancer offert sans AUCUNE tour posée tire aux chances de base (toutes les
-- runes) : sinon, vendre ses tours avant de récupérer un défi donnerait la rune x20 à coup sûr. Une rune
-- Robux ou offerte entre toujours dans l'inventaire, même plein. Ces lancers ne comptent pas dans
-- forgeSpinsBought (prix des lancers en pièces).
-- Envoie (et renvoie) le résultat : { machine = "Bonus", bonus = id, source, price (pièces payées, 0 en
-- Robux ou offert), forgeSpinsBought }.
function PlotGame:grantBonusSpin(source: string, price: number?)
	local drawable, blocked = self:forgeDrawable()
	local function chanceOf(entry)
		return entry.chance
	end
	local bonus
	if #drawable == 0 and source == "Challenge" and blocked == IdleConfig.FORGE_NO_TOWER then
		bonus = rollWeighted(IdleConfig.BONUSES, chanceOf)
	elseif #drawable == 0 then
		bonus = IdleConfig.bestRune()
	else
		bonus = rollWeighted(drawable, chanceOf)
	end
	if source ~= "Coins" or #self.idle.bonuses < IdleConfig.MAX_BONUS_INVENTORY then
		table.insert(self.idle.bonuses, bonus.id)
	end
	self:publishInventory()
	local result = {
		machine = "Bonus",
		bonus = bonus.id,
		source = source,
		price = price or 0,
		forgeSpinsBought = IdleConfig.cleanSpinsBought(self.idle.forgeSpinsBought),
	}
	self:sendResult(result)
	return result
end

-- Forge runique, lancer payé en pièces : plus de délai d'attente. Le serveur vérifie tout : au moins une rune
-- tirable (sinon « Pose d'abord une tour » / « Toutes tes tours ont les meilleures runes »), place dans
-- l'inventaire, prix possible (pas « MAX »), pièces suffisantes. Prix = IdleConfig.forgeCoinPrice(compteur des
-- lancers en pièces déjà achetés, idle.forgeSpinsBought, jamais remis à zéro), qui augmente ensuite de 1.
-- Renvoie le résultat (voir grantBonusSpin), nil si le lancer est refusé.
function PlotGame:spinBonusWithCoins()
	-- Compteur propre (une valeur abîmée compte comme 0), republié : la forge du client reste exacte.
	local bought = IdleConfig.cleanSpinsBought(self.idle.forgeSpinsBought)
	self.idle.forgeSpinsBought = bought
	local drawable, blocked = self:forgeDrawable()
	if blocked or #drawable == 0 then
		self:publishForge()
		self:notify(blocked or IdleConfig.FORGE_ALL_BEST, "Error")
		return nil
	end
	if #self.idle.bonuses >= IdleConfig.MAX_BONUS_INVENTORY then
		self:notify("Ton inventaire de bonus est plein", "Error")
		return nil
	end
	local price = IdleConfig.forgeCoinPrice(bought)
	if price >= math.huge then
		self:notify("Prix trop élevé (MAX) : la forge en pièces n'est plus possible", "Error")
		return nil
	end
	if self.data.coins < price then
		self:notify(`Il te faut {NumberFormat.price(price)} pièces`, "Error")
		return nil
	end
	PlayerData.addCoins(self.player, -price)
	-- Chaque lancer en pièces rend le suivant plus cher (entier fini, bien sous 2^53).
	self.idle.forgeSpinsBought = math.min(bought + 1, IdleConfig.TOWER_SPINS_BOUGHT_MAX)
	return self:grantBonusSpin("Coins", price)
end

-- Pose une rune de l'inventaire sur une tour, dans l'emplacement de SA sorte (dégâts ou vitesse) : elle ne
-- remplace que la rune de la même sorte déjà posée, qui est perdue ; l'autre rune de la tour reste.
function PlotGame:applyBonus(spotIndex: any, bonusId: any)
	local tower = self:ownsSpot(spotIndex) and self.towers[spotIndex]
	local bonus = typeof(bonusId) == "string" and IdleConfig.BONUS_BY_ID[bonusId]
	if not tower or not bonus then
		return
	end
	local inventoryIndex = table.find(self.idle.bonuses, bonusId)
	if not inventoryIndex then
		return
	end
	table.remove(self.idle.bonuses, inventoryIndex)
	tower.runes[bonus.kind] = bonus.id
	self:setRunes(tower)
	self:publishInventory()
	self:notify(`Bonus {bonus.displayName} posé !`, "Success")
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
-- slowed = un contrôle est en cours (ralenti OU étourdi), slowFactor = sa force (1 = étourdi),
-- controlSource = type de tour qui le contrôle ("Frost", "Tesla", "Orbital"), controlLeft = secondes restantes,
-- stunned = étourdi ; immuneLeft = { [type de tour] = secondes d'immunité restantes } (fatigue des contrôles
-- courts, seulement celles en cours) ; fragility = fragilité en cours (0,2 = +20 % de dégâts reçus), fragileLeft.
function PlotGame:debugEnemy(id: number)
	local enemy = findEnemy(self, id)
	if not enemy or enemy.dead then
		return { alive = false, clock = self.clock }
	end
	local now = self.clock
	local controlled = now < enemy.controlUntil
	local fragile = now < enemy.fragileUntil
	local immuneLeft = {}
	for source, untilTime in enemy.fatigue or {} do
		if now < untilTime then
			immuneLeft[source] = untilTime - now
		end
	end
	return {
		alive = true,
		health = enemy.health,
		distance = enemy.distance,
		position = enemy.position,
		slowed = controlled,
		slowFactor = if controlled then enemy.controlFactor else 0,
		controlSource = if controlled then enemy.controlSource else nil,
		controlLeft = if controlled then enemy.controlUntil - now else 0,
		stunned = controlled and enemy.controlFactor >= 1,
		immuneLeft = immuneLeft,
		fragility = if fragile then enemy.fragility else 0,
		fragileLeft = if fragile then enemy.fragileUntil - now else 0,
		pending = enemy.pending,
		clock = now,
	}
end

-- Arrête net cet ennemi (facteur de vitesse de son type à 0, comme debugSpawn « frozen »), par exemple juste
-- après un tir : comme un étourdissement que la visée anticipée ne pouvait pas deviner. Renvoie vrai s'il vit.
function PlotGame:debugFreeze(id: number): boolean
	local enemy = findEnemy(self, id)
	if not enemy or enemy.dead then
		return false
	end
	enemy.speedScale = 0
	return true
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

-- Stats et rayon d'une tour : dégâts, temps entre deux attaques (cooldown, nil pour le rayon), runes posées
-- (texte de IdleConfig.runeList), portée, cible du rayon, secondes sur elle, montée, PV de la cible.
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
		cooldown = stats.cooldown,
		runes = tower.runeKey,
		range = stats.range,
		fragility = stats.fragility or 0,
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

-- Recharge les tours de la sauvegarde (data.idle.towers) comme à l'arrivée du joueur (loadTowers) : les modèles sont
-- refaits, rien n'est vendu, remboursé ni rendu (runes). Sert à tester une vieille sauvegarde, ex. 3 Trébuchets (au-delà
-- de la limite de tours identiques) : tous gardés. Renvoie le nombre de tours de chaque type (countCopies).
function PlotGame:debugReloadTowers(): { [string]: number }
	for _, tower in self.towers do
		tower.model:Destroy()
	end
	table.clear(self.towers)
	self:loadTowers()
	self:publishInventory()
	return self:countCopies()
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

-- Apparitions en avance (sortie à chaque mort, vague écrasée) : joue la vague `wave` d'un seul coup, sans
-- attendre les images, par pas de `dt` secondes de simulation (maxSteps pas au plus), sans qu'aucune tour ne tire.
--   mode "OneShot" : après chaque pas, tous les ennemis en vie sont tués (sans pièces) : une vague écrasée ;
--   mode "KillOldest" : après chaque pas, le plus ancien ennemi en vie est tué (sans pièces) seulement s'il en
--     reste au moins un autre en vie (teste la sortie à chaque mort, pas la vague écrasée) ;
--   mode "Survive" : personne ne meurt (la vague garde son rythme normal).
-- Renvoie { steps, seconds, ended (vague finie), count (ennemis de la vague), spawnTimes (secondes après le
-- début, dans l'ordre d'apparition), expectedTimes (heures prévues par la file, sans compression) }.
-- Ensuite : vague, meilleure vague de la run et record remis comme avant, ennemis vidés, arène fermée.
function PlotGame:debugRunWave(wave: number, mode: string, dt: number, maxSteps: number)
	local saved = { wave = self.idle.wave, bestWave = self.idle.bestWave, highestWave = self.idle.highestWave }
	self:clearEnemies()
	self.idle.wave = wave
	self:startWave()
	self.debugActive = {} -- aucune tour ne tire
	local start = self.clock
	local expectedTimes = {}
	for _, item in self.spawnQueue do
		table.insert(expectedTimes, item.at - start)
	end
	local spawnTimes, seen = {}, {}
	local steps, ended = 0, false
	while steps < maxSteps do
		self:simulate(dt)
		steps += 1
		if self.state ~= "Running" then
			ended = true
			break
		end
		for _, enemy in self.enemies do
			if not seen[enemy.id] then
				seen[enemy.id] = true
				table.insert(spawnTimes, enemy.spawnedAt - start)
			end
			if mode == "OneShot" and not enemy.dead then
				enemy.reward = 0
				self:damageEnemy(enemy, enemy.health)
			end
		end
		if mode == "KillOldest" then
			-- self.enemies est dans l'ordre d'apparition : le premier vivant est le plus ancien.
			local oldest, aliveCount = nil, 0
			for _, enemy in self.enemies do
				if not enemy.dead then
					oldest = oldest or enemy
					aliveCount += 1
				end
			end
			if oldest and aliveCount >= 2 then
				oldest.reward = 0
				self:damageEnemy(oldest, oldest.health)
			end
		end
	end
	local seconds = self.clock - start
	self.idle.wave, self.idle.bestWave, self.idle.highestWave = saved.wave, saved.bestWave, saved.highestWave
	self:debugEndArena()
	return {
		steps = steps,
		seconds = seconds,
		ended = ended,
		count = #expectedTimes,
		spawnTimes = spawnTimes,
		expectedTimes = expectedTimes,
	}
end

-- Le joueur quitte le serveur : on libère la parcelle (sa progression est déjà dans ses données).
function PlotGame:destroy()
	self:clearEnemies() -- avant les tours : leurs rayons s'éteignent proprement
	self.towerFolder:Destroy()
	table.clear(self.drops)
	self.dropCount = 0
	HubMap.resetSpots(self.plot)
	-- Paquet « Clear » à tout le monde (ceux qui voyaient la parcelle, et les autres, pour qui il ne change rien) :
	-- les clients effacent tout de suite ses ennemis, sans animation de mort (ils ne sont pas tués, la parcelle
	-- se vide ; voir PlotRenderer). Les paquets normaux, eux, ne vont qu'aux joueurs proches (Hub/PlotInterest.luau).
	Remotes.get("PlotSync"):FireAllClients(self.index, buffer.create(0), 0, "Clear")
	for name in self.attributeCache do
		self.plot.folder:SetAttribute(name, nil)
	end
end

return PlotGame

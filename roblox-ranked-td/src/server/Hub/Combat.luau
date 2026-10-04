-- LE COMBAT des tours contre les monstres, côté serveur : visée, projectiles, zones, carreau perçant, rayon,
-- contrôles (ralentissements, étourdissement), fragilité, feu des flèches, et les paquets réseau qui montrent tout ça
-- aux clients. C'est la base des jeux qui se jouent sur un chemin : un NIVEAU (Hub/LevelGame.luau) et, par lui, le
-- camp d'entraînement d'une parcelle (Hub/CampGame.luau). Ce fichier ne connaît ni l'or, ni les vies, ni les règles
-- d'un niveau : seulement « des tours tirent sur des monstres ».
--
-- Le jeu qui hérite de Combat fournit :
--   ses champs : plot.folder (dossier dont les attributs sont lus par les clients), cframe (centre de la zone),
--     enemies, towers, shots, impacts, firePatches (listes), nextId, attributeCache, lastSyncEmpty, clock (horloge de
--     la simulation, en secondes) ;
--   trois méthodes : pathPoint(distance, couloir) = point du chemin dans le monde (couloir : celui du monstre,
--     cartes d'équipe ; absent = le premier), statsOf(tour) = ses stats du moment, damageEnemy(monstre, dégâts,
--     fragile) = dégâts infligés (et ce que rapporte sa mort).
--   Un monstre peut avoir lane (son couloir) et laneOffset (ce qui manque à son couloir pour faire la longueur du
--     plus long : ajouté à sa distance, il dit qui est le plus près du château, tous couloirs confondus).
-- Les monstres n'existent que sous forme de données côté serveur. Les clients reçoivent leur position quelques fois
-- par seconde (paquet binaire compact) et les affichent eux-mêmes (client/PlotRenderer.luau).
-- Les temps (impacts, ralentissements, feu) se comptent sur l'horloge de la simulation, self.clock, pas sur
-- os.clock() : tout marche pareil en vitesse x2.
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
--   flèches enflammées : zones de feu au sol (self.firePatches) ; les ronces du Lance-ronces sont des zones du même
--     genre qui EMPOISONNENT (poison : des dégâts qui continuent après la sortie des ronces, burnFires) ;
--   rayon continu : Sorcier des arcanes (beamStep), publié aux clients par les attributs « BeamTarget »
--     (id de l'ennemi visé, 0 = éteint) et « BeamRamp » (montée actuelle, arrondie à 0,5) de sa tour ;
--   CONTRÔLES (ralentissements, étourdissement) : un seul à la fois par ennemi, et fatigue des contrôles courts
--     du Mage et du Trébuchet : jamais prolongés, puis une immunité (applyControl) ;
--   fragilité du Totem de givre : +X % de dégâts reçus (applyFragility, damageEnemy du jeu qui hérite).
--
-- Paquets réseau (lus par PlotRenderer.luau) :
--   PlotSync (positions)  = count x ENEMY_BYTES octets, PUIS count octets « contrôle » (un par ennemi, même
--     ordre) : bits 0-6 = numéro (IdleTowers.ORDER) de la FAMILLE de la tour dont le contrôle est en cours (sa tour
--     de palier 1 ; 0 = aucun ; Frost = ralenti par un Totem, Tesla = ralenti par un Mage, Orbital = étourdi par le
--     Trébuchet, ou par leur version de palier 2), bit 7
--     (valeur 128) = fragile (dans l'aura d'un Totem de givre : prend plus de dégâts). Un client qui ne lit que
--     les count x ENEMY_BYTES premiers octets marche toujours (ces octets sont à la fin).
--     PUIS, seulement si au moins un ennemi est empoisonné, count octets « effets » (même ordre) : bit 0 (valeur 1)
--     = empoisonné (ronces du Lance-ronces). Absents : aucun ennemi empoisonné.
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

local TOWER_INDEX = {}
for index, name in IdleTowers.ORDER do
	TOWER_INDEX[name] = index
end

-- Taille d'un ennemi dans le paquet : id u32, type u8, distance f32, PV % u8, vitesse % u8.
-- « type » = numéro dans Enemies.ORDER + (couloir - 1) x Enemies.LANE_STEP (distance = le long de SON couloir).
-- « vitesse % » = facteur de son type (IdleConfig.ENEMY_SPEED_FACTORS) x contrôle (ralentissement ; 0 s'il
-- est étourdi), en % : le client avance l'ennemi à vitesse de Enemies.luau x ENEMY_SPEED_MULTIPLIER x ce
-- facteur x l'attribut « SimSpeed » de la zone. Le paquet ne contient PAS le x2 : le client multiplie.
-- Après les count x ENEMY_BYTES octets : count octets « contrôle » (voir en haut du fichier).
local ENEMY_BYTES = 11
-- Octet « contrôle » : bit 7 = ennemi fragile (Totem de givre).
local CONTROL_FRAGILE_FLAG = 128
-- Octet « effets » (après les octets « contrôle », seulement si un ennemi est empoisonné) : bit 0 = empoisonné.
local EFFECT_POISON_FLAG = 1
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

local Combat = {}
Combat.__index = Combat

function Combat:newId(): number
	self.nextId = (self.nextId + 1) % 4294967295
	return self.nextId
end

-- Attributs du dossier de la zone (lus par les clients).
function Combat:setAttr(name: string, value: any)
	if self.attributeCache[name] ~= value then
		self.attributeCache[name] = value
		self.plot.folder:SetAttribute(name, value)
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
-- FATIGUE (retour du propriétaire : plein de Mages avec la vitesse x2 gelaient tous les monstres) :
-- quand un contrôle court se termine, l'ennemi est IMMUNISÉ contre ce type de tour pendant `immunity` secondes
-- (IdleTowers : slowImmunity du Mage, stunImmunity du Trébuchet). Les Mages ne peuvent donc ralentir un ennemi
-- que slowDuration s sur (slowDuration + slowImmunity) s au plus (0,6 s sur 1,4 s avec les réglages actuels),
-- les Trébuchets l'étourdir que 0,5 s sur 2 s, quel que soit le nombre de ces tours.
-- L'immunité ne bloque que ce type de tour : le Totem peut geler un ennemi immunisé contre le Mage.
-- « Type » = FAMILLE de la tour (stats.family : sa tour de palier 1). Une tour de palier 2 compte comme sa tour de
-- base : un Totem du blizzard prolonge le gel d'un Totem de givre (le plus fort des deux ralentissements reste, ils
-- ne s'additionnent jamais), et la fatigue du Mage vaut aussi pour l'Archimage (sinon, en les mélangeant, un
-- monstre serait ralenti sans fin).
-- source = famille de la tour (stats.family), strength = 0 à 1 (1 = étourdi : vitesse 0), immunity = secondes
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
		enemy.controlFactor = math.max(enemy.controlFactor, math.clamp(strength, 0, 1))
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

-- POISON des ronces (Lance-ronces, IdleTowers.ThornSpitter) : un ennemi touché par les ronces est empoisonné
-- `duration` s ; il perd dps x POISON_TICK PV toutes les POISON_TICK s (burnFires), même sorti des ronces. Ce n'est
-- PAS un contrôle (il ne ralentit pas). Deux poisons ne s'additionnent pas (comme la fragilité) : un plus fort
-- remplace l'actuel, un égal le prolonge, un plus faible est ignoré tant que l'actuel dure. fragile = ses dégâts
-- profitent de la fragilité du Totem du blizzard. Champs de l'ennemi : poisonDps, poisonUntil (nil = pas
-- empoisonné), poisonNext (heure du prochain coup), poisonFragile.
local function applyPoison(enemy, dps: number, duration: number, fragile: boolean, now: number)
	if dps <= 0 or duration <= 0 then
		return
	end
	local poisoned = enemy.poisonUntil ~= nil and now < enemy.poisonUntil
	if not poisoned then
		enemy.poisonNext = now + IdleTowers.POISON_TICK
	end
	if not poisoned or dps > enemy.poisonDps then
		enemy.poisonDps = dps
		enemy.poisonFragile = fragile
		enemy.poisonUntil = now + duration
	elseif dps == enemy.poisonDps then
		enemy.poisonUntil = math.max(enemy.poisonUntil, now + duration)
	end
end

-- Vitesse actuelle en fraction de la vitesse de base : facteur du type x contrôle (0 si étourdi).
local function speedFactorOf(enemy, now: number): number
	local controlFactor = if now < enemy.controlUntil then 1 - enemy.controlFactor else 1
	return enemy.speedScale * controlFactor
end

-- Effet visuel d'un tir, envoyé aux clients avec le prochain paquet (takeShotsPacket).
-- landsAt = heure (de la simulation) de l'impact : maintenant pour un tir instantané.
-- targetId = id de l'ennemi que le projectile suit (IdleTowers.followsTarget), rien ou 0 = aucun.
function Combat:addShot(from: Vector3, to: Vector3, towerType: string, radius: number, landsAt: number, targetId: number?)
	if #self.shots < IdleConfig.MAX_SHOTS_PER_PACKET then
		table.insert(self.shots, { from = from, to = to, type = TOWER_INDEX[towerType], radius = radius, landsAt = landsAt, targetId = targetId or 0 })
	end
end

-- Avancée d'un ennemi vers le château, comparable d'un couloir à l'autre (plus grande = plus près du château).
local function progressOf(enemy): number
	return enemy.distance + (enemy.laneOffset or 0)
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
function Combat:pickTarget(tower, stats, allowDoomed: boolean): any
	local strongest = stats.targeting == "Strongest"
	local best, bestScore = nil, -math.huge
	local fallback, fallbackScore = nil, -math.huge
	for _, enemy in self.enemies do
		if not enemy.dead and horizontalDistance(tower.position, enemy.position) <= stats.range then
			local score = if strongest then enemy.health else progressOf(enemy)
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
function Combat:hitEnemy(enemy, stats, now: number)
	if stats.slow then
		applyControl(enemy, stats.family or stats.towerType, stats.slow, stats.slowDuration, stats.slowImmunity, now)
	end
	if stats.stunDuration then
		applyControl(enemy, stats.family or stats.towerType, 1, stats.stunDuration, stats.stunImmunity, now)
	end
	self:damageEnemy(enemy, stats.damage, not stats.ignoresFragility)
end

-- Un coup de zone : tous les ennemis vivants à moins de stats.splash studs du point d'impact.
function Combat:hitArea(center: Vector3, stats, now: number)
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
-- 3 max », décision du propriétaire ; stats.pierceMax pour une tour qui a sa propre limite, comme la Baliste du
-- dragon) : sa cible si elle vit encore (touchée où qu'elle soit, comme une flèche :
-- un ralentissement arrivé pendant le vol ne lui fait pas éviter le carreau), plus les PREMIERS ennemis vivants
-- que le carreau rencontre à moins de stats.pierceWidth studs du segment origine (la tour) -> point d'impact :
-- les plus proches de la tour le long du trait (alongSegment) ; à égalité, le premier de la liste des ennemis.
-- Une cible morte pendant le vol laisse sa place à un ennemi de la ligne. Chacun une seule fois ; les coups
-- tombent dans l'ordre de la liste des ennemis (comme avant : rien ne change quand la ligne n'est pas pleine).
function Combat:hitLine(origin: Vector3, impactPoint: Vector3, stats, target, now: number)
	-- Les autres ennemis sur la ligne : { ennemi, avancée le long du trait, rang dans la liste }.
	local onLine = {}
	for index, enemy in self.enemies do
		if enemy ~= target and not enemy.dead and segmentDistance(enemy.position, origin, impactPoint) <= stats.pierceWidth then
			table.insert(onLine, { enemy = enemy, along = alongSegment(enemy.position, origin, impactPoint), index = index })
		end
	end
	-- Places pour eux : la cible vivante prend toujours la sienne.
	local places = math.max(0, (stats.pierceMax or IdleTowers.BALLISTA_PIERCE_MAX) - (if target.dead then 0 else 1))
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
function Combat:enemyNear(position: Vector3, radius: number): any
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
function Combat:predictImpact(target, from: Vector3, stats, now: number): (Vector3, number)
	local flight = IdleTowers.flightTime(stats, (target.position - from).Magnitude)
	for _ = 1, 2 do
		local aim = self:pathPoint(target.distance + travelDistance(target, now, flight), target.lane)
		flight = IdleTowers.flightTime(stats, (aim - from).Magnitude)
	end
	return self:pathPoint(target.distance + travelDistance(target, now, flight), target.lane), flight
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
function Combat:pickCrowdTarget(tower, stats, muzzle: Vector3, now: number): (any, Vector3?, number)
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
			at = self:pathPoint(other.distance + travelDistance(other, now, step * CROWD_FLIGHT_STEP), other.lane)
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
		local ahead = progressOf(candidate) + travelDistance(candidate, now, flight)
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
function Combat:countPierced(candidate, origin: Vector3, aim: Vector3, flight: number, stats, now: number): number
	local width = stats.pierceWidth
	local limit = stats.pierceMax or IdleTowers.BALLISTA_PIERCE_MAX
	local count = 1 -- sa cible : toujours touchée (hitLine)
	for _, other in self.enemies do
		if count >= limit then
			break -- ligne pleine : le carreau n'en transpercera pas plus
		end
		if other ~= candidate and not other.dead and not isDoomed(other) then
			-- Distance parcourue au plus pendant le vol : sa vitesse normale (un ralentissement ne fait qu'en retirer).
			local reach = other.def.speed * IdleConfig.ENEMY_SPEED_MULTIPLIER * other.speedScale * flight
			if segmentDistance(other.position, origin, aim) - reach <= width then
				local at = self:pathPoint(other.distance + travelDistance(other, now, flight), other.lane)
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
function Combat:pickPierceTarget(tower, stats, strongest, muzzle: Vector3, now: number): (any, Vector3, number)
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
function Combat:fireProjectile(tower, stats, target, muzzle: Vector3, now: number, aim: Vector3?, flight: number?)
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
function Combat:landImpact(impact, now: number)
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
end

-- Projectiles arrivés (heure d'impact atteinte sur l'horloge de la simulation : marche pareil en x2).
function Combat:resolveImpacts(now: number)
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
function Combat:addFirePatch(spot: number, position: Vector3, stats, now: number)
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
		poison = stats.poisonDuration, -- ronces : durée du poison (nil = du feu, qui brûle seulement dedans)
		dps = dps,
		tick = stats.fireTick,
		expiresAt = now + stats.fireDuration,
		nextTick = now + stats.fireTick, -- 1er coup après fireTick s, puis toutes les fireTick s
	})
end

-- Les zones de feu brûlent tous les ennemis dedans : dps x fireTick à chaque coup, tant qu'elles durent
-- (une zone de 2 s donne 4 coups de 0,5 s). Puis elles s'éteignent. Les RONCES (patch.poison), elles, empoisonnent
-- les ennemis dedans à chaque coup (applyPoison) ; puis le poison de chaque ennemi empoisonné frappe, toutes les
-- IdleTowers.POISON_TICK s, jusqu'à sa fin.
function Combat:burnFires(now: number)
	local patches = self.firePatches
	for i = #patches, 1, -1 do
		local patch = patches[i]
		while patch.nextTick <= now + TIME_EPSILON and patch.nextTick <= patch.expiresAt + TIME_EPSILON do
			local amount = patch.dps * patch.tick
			for _, enemy in self.enemies do
				if not enemy.dead and horizontalDistance(patch.position, enemy.position) <= patch.radius then
					if patch.poison then
						applyPoison(enemy, patch.dps, patch.poison, patch.fragile, patch.nextTick)
					else
						self:damageEnemy(enemy, amount, patch.fragile)
					end
				end
			end
			patch.nextTick += patch.tick
		end
		if patch.nextTick > patch.expiresAt + TIME_EPSILON then
			table.remove(patches, i)
		end
	end
	local tick = IdleTowers.POISON_TICK
	for _, enemy in self.enemies do
		local untilTime = enemy.poisonUntil
		if untilTime and not enemy.dead then
			while not enemy.dead and enemy.poisonNext <= now + TIME_EPSILON and enemy.poisonNext <= untilTime + TIME_EPSILON do
				self:damageEnemy(enemy, enemy.poisonDps * tick, enemy.poisonFragile)
				enemy.poisonNext += tick
			end
			if enemy.poisonNext > untilTime + TIME_EPSILON then
				enemy.poisonUntil = nil -- (fini)
			end
		end
	end
end

----------------------------------------------------------------------
-- Rayon continu (Sorcier des arcanes)
----------------------------------------------------------------------

-- Publie le rayon d'une tour pour les clients (seulement quand ça change) : attribut « BeamTarget » = id
-- de l'ennemi visé (0 = éteint), « BeamRamp » = montée actuelle arrondie à 0,5 (épaisseur du rayon).
function Combat:showBeam(tower, target, ramp: number)
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
-- mêmes dégâts par seconde de simulation en x1 et en x2 (montée : IdleTowers.beamRamp).
function Combat:beamStep(tower, stats, dt: number)
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

function Combat:towerAttack(tower, stats, now: number): boolean
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
					applyControl(enemy, stats.family or stats.towerType, stats.slow, stats.slowDuration, stats.slowImmunity, now)
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
			return progressOf(a) > progressOf(b)
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
-- count x ENEMY_BYTES octets, puis count octets « contrôle » (même ordre), puis, si au moins un ennemi est
-- empoisonné, count octets « effets » (voir en haut du fichier).
function Combat:buildSyncPacket(): (buffer?, number)
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
	local poisoned = false
	for _, enemy in self.enemies do
		if enemy.poisonUntil and now < enemy.poisonUntil then
			poisoned = true
			break
		end
	end
	local effectStart = controlStart + count
	local packet = buffer.create(if poisoned then effectStart + count else effectStart)
	for i, enemy in self.enemies do
		local offset = (i - 1) * ENEMY_BYTES
		local speedFactor = speedFactorOf(enemy, now)
		buffer.writeu32(packet, offset, enemy.id)
		buffer.writeu8(packet, offset + 4, enemy.typeIndex + ((enemy.lane or 1) - 1) * Enemies.LANE_STEP)
		buffer.writef32(packet, offset + 5, enemy.distance)
		buffer.writeu8(packet, offset + 9, math.clamp(math.ceil(enemy.health / enemy.maxHealth * 255), 0, 255))
		buffer.writeu8(packet, offset + 10, math.clamp(math.floor(speedFactor * 100 + 0.5), 0, 255))
		buffer.writeu8(packet, controlStart + i - 1, controlByte(enemy, now))
		if poisoned then
			buffer.writeu8(packet, effectStart + i - 1, if enemy.poisonUntil and now < enemy.poisonUntil then EFFECT_POISON_FLAG else 0)
		end
	end
	return packet, count
end

-- Tirs depuis le dernier paquet. count x SHOT_BYTES octets, puis count x SHOT_TARGET_BYTES octets (id de la
-- cible suivie, même ordre ; voir en haut du fichier).
function Combat:takeShotsPacket(): (buffer?, number)
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

return Combat

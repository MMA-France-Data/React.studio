-- NIVEAUX : la nouvelle formule du jeu, en PROTOTYPE (demande du propriétaire, 02/10/2026 : « sors-moi tout un
-- prototype, même s'il n'est pas parfait »). Elle vit à côté du jeu actuel (parcelle infinie), sans y toucher.
--
-- Le principe, décidé avec le propriétaire :
--   * le jeu est une suite de niveaux : niveau 1, niveau 2, niveau 3... Chaque niveau est une partie à lui tout
--     seul : un FLOT CONTINU de monstres, de plus en plus serrés et résistants jusqu'à la fin (voir « LE FLOT »), un
--     mini-boss dans le flot au niveau 5, un boss au niveau 10. Dix niveaux = un territoire (une famille de monstres) ;
--   * dans un niveau : vue d'en haut, une base d'OR fixe au départ, l'or tombe tout seul à chaque monstre tué, on
--     pose ses tours OÙ ON VEUT et on les améliore sans arrêt (il le faut : sinon on perd), 10 vies ;
--   * à chaque niveau on repart avec seulement ses tours DÉBLOQUÉES (l'or et les tours posées ne se gardent pas) ;
--   * gagner un niveau rapporte des PIÈCES DE NIVEAU (plus la première fois, bien plus sur les boss ; on peut rejouer
--     un niveau réussi pour en regagner un peu) ; elles servent à acheter les tours suivantes dans une BOUTIQUE À
--     PRIX FIXES (aucun hasard) et à améliorer le CAMP D'ENTRAÎNEMENT ;
--   * le camp d'entraînement : les tours qu'on y met s'entraînent, même quand le joueur est absent, et en jouant ;
--     l'entraînement débloque des améliorations par paliers (ex. les flèches enflammées de l'Archer).
-- Deux monnaies bien séparées : l'OR ne vit que le temps d'un niveau ; les PIÈCES DE NIVEAU se gardent (elles ne
-- sont PAS les pièces de la parcelle infinie, qui montent aux milliards).
-- Rien de tout ça n'entre dans le classé.
--
-- Ce module ne contient que des règles et des chiffres (aucun objet Roblox en dehors de Vector3 / CFrame) : le
-- serveur (Hub/LevelGame.luau, Hub/LevelsService.luau), le client (LevelsUI.luau, PlotRenderer.luau) et le
-- simulateur hors Studio (tools/levels) lisent tous les mêmes.
local Enemies = require(script.Parent.Enemies)
local IdleConfig = require(script.Parent.IdleConfig)
local IdleTowers = require(script.Parent.IdleTowers)

local Levels = {}

Levels.COUNT = 10 -- niveaux jouables dans ce prototype (le premier territoire)
Levels.LIVES = 10

----------------------------------------------------------------------
-- Zones de combat : une par joueur, dans le MÊME serveur que la map principale (pas de téléportation, donc pas
-- d'écran de chargement), loin de la place. Le joueur de la parcelle n joue dans la zone n. Pour l'affichage, une
-- zone est une « parcelle » de plus : son numéro est FIRST_ARENA_INDEX + n (paquets PlotSync / PlotShots).
----------------------------------------------------------------------
Levels.FIRST_ARENA_INDEX = 100
Levels.ARENA_ORIGIN = Vector3.new(0, 0, -3000)
Levels.ARENA_SPACING = 400
Levels.ARENA_SLOTS = 6

function Levels.isArena(index: any): boolean
	return typeof(index) == "number" and index > Levels.FIRST_ARENA_INDEX and index <= Levels.FIRST_ARENA_INDEX + Levels.ARENA_SLOTS
end

function Levels.arenaIndex(slot: number): number
	return Levels.FIRST_ARENA_INDEX + slot
end

function Levels.slotOf(index: number): number
	return index - Levels.FIRST_ARENA_INDEX
end

-- Centre de la zone (au sol), sans rotation : +X = vers la droite de l'écran, -Z = vers le haut de l'écran.
function Levels.arenaCFrame(slot: number): CFrame
	return CFrame.new(Levels.ARENA_ORIGIN + Vector3.new((slot - 3.5) * Levels.ARENA_SPACING, 0, 0))
end

----------------------------------------------------------------------
-- Cartes. Coordonnées locales de la zone : X = largeur (les monstres entrent à gauche, le château est à droite),
-- Z = profondeur. Chemin fait de tronçons droits (RoadGeometry). spots = bons endroits pour une tour, dans l'ordre
-- conseillé : montrés par des « + » au premier niveau (on peut poser ailleurs), et suivis par le joueur simulé.
----------------------------------------------------------------------
Levels.PATH_WIDTH = 6
Levels.TOWER_CLEARANCE = 5 -- distance mini entre le centre d'une tour et le milieu du chemin
Levels.TOWER_SPACING = 4.5 -- distance mini entre deux tours
Levels.BUILD_MARGIN = 3 -- distance mini au bord du terrain
Levels.BASE_CLEARANCE = 7 -- distance mini au château

Levels.MAPS = {
	Valley = {
		displayName = "La vallée du Roi carmin",
		width = 112,
		depth = 52,
		path = {
			Vector3.new(-56, 0, -14),
			Vector3.new(-34, 0, -14),
			Vector3.new(-34, 0, 14),
			Vector3.new(-12, 0, 14),
			Vector3.new(-12, 0, -14),
			Vector3.new(10, 0, -14),
			Vector3.new(10, 0, 14),
			Vector3.new(32, 0, 14),
			Vector3.new(32, 0, -2),
			Vector3.new(48, 0, -2),
		},
		base = Vector3.new(52, 0, -2),
		spots = {
			Vector3.new(-23, 0, 0),
			Vector3.new(-1, 0, 0),
			Vector3.new(21, 0, 0),
			Vector3.new(-45, 0, -3),
			Vector3.new(-23, 0, 22),
			Vector3.new(-1, 0, -22),
			Vector3.new(21, 0, 22),
			Vector3.new(42, 0, 8),
			Vector3.new(-23, 0, -22),
			Vector3.new(-1, 0, 22),
			Vector3.new(21, 0, -22),
			Vector3.new(-45, 0, 6),
		},
	},
}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local geometries = {}

-- Géométrie d'une carte : { map, PATH_LENGTH, pointAt(distance) -> (point local, direction),
-- distanceToPath(point local) -> studs }. La même table à chaque appel.
function Levels.geometry(mapName: string)
	local geometry = geometries[mapName]
	if geometry then
		return geometry
	end
	local map = Levels.MAPS[mapName]
	assert(map, "Carte inconnue : " .. tostring(mapName))
	local path = map.path
	local cumulative = { 0 }
	for i = 2, #path do
		cumulative[i] = cumulative[i - 1] + (path[i] - path[i - 1]).Magnitude
	end
	geometry = { map = map, name = mapName, PATH_LENGTH = cumulative[#cumulative] }

	function geometry.pointAt(distance: number): (Vector3, Vector3)
		if distance <= 0 then
			return path[1], (path[2] - path[1]).Unit
		end
		for i = 2, #path do
			if distance <= cumulative[i] then
				local direction = (path[i] - path[i - 1]).Unit
				return path[i - 1] + direction * (distance - cumulative[i - 1]), direction
			end
		end
		return path[#path], (path[#path] - path[#path - 1]).Unit
	end

	function geometry.distanceToPath(localPosition: Vector3): number
		local p = flat(localPosition)
		local best = math.huge
		for i = 2, #path do
			local a, b = path[i - 1], path[i]
			local ab = b - a
			local t = math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
			best = math.min(best, (p - (a + ab * t)).Magnitude)
		end
		return best
	end

	geometries[mapName] = geometry
	return geometry
end

-- Peut-on poser une tour ici ? localPosition = point de la zone (coordonnées locales), towers = positions locales
-- des tours déjà posées. Le client s'en sert pour l'aperçu vert / rouge, le serveur pour décider (il a le dernier
-- mot). Renvoie (vrai) ou (faux, raison).
function Levels.checkPlacement(mapName: string, localPosition: Vector3, towers: { Vector3 }): (boolean, string?)
	if localPosition.X ~= localPosition.X or localPosition.Z ~= localPosition.Z then
		return false, "Position invalide"
	end
	local geometry = Levels.geometry(mapName)
	local map = geometry.map
	if
		math.abs(localPosition.X) > map.width / 2 - Levels.BUILD_MARGIN
		or math.abs(localPosition.Z) > map.depth / 2 - Levels.BUILD_MARGIN
	then
		return false, "Hors du terrain"
	end
	if geometry.distanceToPath(localPosition) < Levels.TOWER_CLEARANCE then
		return false, "Trop près du chemin"
	end
	if flat(localPosition - map.base).Magnitude < Levels.BASE_CLEARANCE then
		return false, "Trop près du château"
	end
	for _, other in towers do
		if flat(other - localPosition).Magnitude < Levels.TOWER_SPACING then
			return false, "Trop près d'une autre tour"
		end
	end
	return true, nil
end

----------------------------------------------------------------------
-- Monstres d'un niveau. Les PV ne viennent pas du jeu infini : ils sont petits et lisibles.
--   PV = PV du fantassin de ce niveau (champ health de sa définition) x part de son type x montée du moment (ramp).
-- gold = or donné quand il meurt ; leak = vies perdues s'il atteint le château.
----------------------------------------------------------------------
Levels.ENEMY = {
	Normal = { health = 1, gold = 6, leak = 1 },
	Fast = { health = 0.6, gold = 6, leak = 1 },
	Swarm = { health = 0.35, gold = 2, leak = 1 },
	Tank = { health = 4.5, gold = 18, leak = 2 },
	Giant = { health = 30, gold = 120, leak = 5 }, -- mini-boss (chevalier colossal)
	Boss = { health = 60, gold = 300, leak = 10 }, -- boss : s'il passe, c'est perdu
}
-- TAILLE AFFICHÉE des monstres dans un niveau (demande du propriétaire, 02/10/2026 : « j'aurais agrandi aussi les
-- monstres pour bien les voir ») : la carte est vue de haut et de loin, surtout sur téléphone. Multiplie la taille du
-- modèle, de sa barre de vie et de ses effets (client/PlotRenderer.luau). AFFICHAGE SEULEMENT : le combat ne connaît
-- que la place du monstre sur le chemin, la difficulté ne change pas. 1 = la taille qu'il a sur une parcelle.
-- Les gros (colosse, boss) grossissent moins : ils déborderaient trop du chemin (6 studs de large).
Levels.ENEMY_SCALE = { Normal = 1.8, Fast = 1.8, Swarm = 2, Tank = 1.6, Giant = 1.4, Boss = 1.4 }
-- Bouton « x2 » pendant un niveau (tout va 2 fois plus vite, comme le pass Vitesse x2 de la parcelle) :
--   true  -> pour tout le monde (prototype : un niveau doit pouvoir se jouer vite) ;
--   false -> seulement avec le pass Vitesse x2.
-- À décider par le propriétaire avant d'ouvrir les niveaux à tous les joueurs.
Levels.SPEED_FREE = true

----------------------------------------------------------------------
-- LE FLOT. Retour du propriétaire après son premier essai (02/10/2026) : « beaucoup trop facile, et ils sortent
-- par vague malgré tout ; je veux que ce soit en continu, et que le niveau soit de plus en plus dur au fur et à
-- mesure, que je sois obligé d'être super actif pendant le niveau : poser des tours, améliorer... Si juste
-- 2 Archers gèrent le niveau, je passe mon temps à attendre. »
-- Un niveau n'a donc ni groupes ni pauses : un monstre sort, puis le suivant, sans arrêt, pendant `seconds`
-- secondes. Du début à la fin du niveau :
--   * l'écart entre deux monstres RÉTRÉCIT (gap = { au début, à la fin }, en secondes) : 3 fois plus de monstres
--     par seconde à la fin ;
--   * leurs PV MONTENT (RAMP = { au début, à la fin } : part des PV du niveau, champ health) : 16 fois plus à la
--     fin. RAMP_CURVE donne la forme de la montée (1 = régulière ; moins de 1 = elle monte plus vite au début).
-- Les PV qui arrivent par seconde sont donc multipliés par 50 environ entre le début et la fin. La forme a été
-- dessinée avec tools/levels (run.ps1 -Curve) pour suivre ce qu'un joueur peut se payer s'il réinvestit tout son
-- or : les premières secondes ne demandent que le tiers de ses moyens (le temps de poser ses premières tours), la
-- fin les demande tous. Celui qui s'arrête d'acheter est dépassé en une vingtaine de secondes.
-- L'OR suit (ENEMY.gold) : les monstres en donnent assez pour un achat toutes les 3 secondes environ. C'est ce qui
-- oblige à rester actif : on ne peut pas attendre puis tout dépenser d'un coup, il faut poser et améliorer sans
-- arrêt, du début à la fin.
-- Les types se mélangent au lieu d'arriver par paquets : 1 monstre sur FAST_EVERY est un cavalier, 1 sur
-- SWARM_EVERY une meute de SWARM_PACK écuyers serrés, 1 sur TANK_EVERY un chevalier lourd, les autres des
-- fantassins. Chaque type n'entre qu'à partir d'une avancée du niveau (from = { Fast = 0.2 } : après 20 %).
-- specials = monstres à part : { type, avancée du niveau où il sort (1 = tout à la fin, il ferme le flot), part de
-- ses PV (1 si absente : il ne suit pas la montée ; plus petite quand il sort tôt, face à des tours encore
-- faibles) } : mini-boss du niveau 5, colosses des niveaux 8 et 10, boss du niveau 10.
-- Rien n'est tiré au hasard : le même niveau donne toujours exactement le même flot.
----------------------------------------------------------------------
Levels.STREAM = {
	FAST_EVERY = 4,
	SWARM_EVERY = 6,
	SWARM_PACK = 3,
	SWARM_GAP = 0.3, -- secondes entre deux écuyers d'une meute
	TANK_EVERY = 9,
	RAMP = { 0.1, 1.6 },
	RAMP_CURVE = 0.8,
}

-- gold = or de départ. Niveau 1 : un Archer est déjà posé (Levels.STARTING_TOWER) et tire tout de suite.
-- health = PV d'un fantassin quand la montée vaut 1 (une flèche d'Archer : 3). Niveau 1 : le premier fantassin a
-- 7 PV, le dernier 115.
-- C'est LE réglage de la difficulté d'un niveau, trouvé avec les joueurs simulés (tools/levels, run.ps1 -Tune, puis
-- 5 % de marge) : avec les tours attendues à ce niveau, celui qui achète au rythme demandé (un achat toutes les 5 s
-- au niveau 1, toutes les 3,5 s à partir du niveau 6) gagne ; celui qui n'achète que toutes les 8 s perd ; celui qui
-- pose 2 Archers puis attend perd avant 30 % du niveau (tests.luau le vérifie pour les 10 niveaux). Trop dur ou
-- trop facile pour de vrais joueurs : baisser ou monter ce chiffre, rien d'autre.
-- Les niveaux à colosse (5, 8) et à boss (10) ont un flot un peu moins résistant : le gros monstre fait le reste.
Levels.DEFINITIONS = {
	{ gold = 60, seconds = 95, health = 72, gap = { 1.1, 0.34 }, from = { Fast = 0.25 } },
	{ gold = 65, seconds = 105, health = 88, gap = { 1.1, 0.33 }, from = { Fast = 0.15, Swarm = 0.45 } },
	{ gold = 70, seconds = 115, health = 86, gap = { 1.05, 0.32 }, from = { Fast = 0.15, Swarm = 0.3, Tank = 0.6 } },
	{ gold = 75, seconds = 120, health = 88, gap = { 1.05, 0.31 }, from = { Fast = 0.1, Swarm = 0.25, Tank = 0.45 } },
	{ gold = 80, seconds = 130, health = 77, gap = { 1, 0.3 }, from = { Fast = 0.1, Swarm = 0.25, Tank = 0.4 }, specials = { { "Giant", 0.75 } } },
	{ gold = 85, seconds = 130, health = 115, gap = { 1, 0.3 }, from = { Fast = 0.1, Swarm = 0.2, Tank = 0.35 } },
	{ gold = 90, seconds = 135, health = 122, gap = { 1, 0.29 }, from = { Fast = 0.1, Swarm = 0.2, Tank = 0.3 } },
	{ gold = 95, seconds = 140, health = 145, gap = { 0.95, 0.29 }, from = { Fast = 0.1, Swarm = 0.2, Tank = 0.3 }, specials = { { "Giant", 0.6, 0.8 } } },
	{ gold = 100, seconds = 145, health = 158, gap = { 0.95, 0.28 }, from = { Fast = 0.1, Swarm = 0.2, Tank = 0.25 } },
	{ gold = 110, seconds = 155, health = 126, gap = { 0.95, 0.28 }, from = { Fast = 0.1, Swarm = 0.2, Tank = 0.25 }, specials = { { "Giant", 0.5, 0.7 }, { "Boss", 1 } } },
}

-- Niveau 1 : cette tour est déjà posée à l'arrivée du joueur (premier emplacement conseillé de la carte), pour
-- qu'il voie tout de suite le jeu marcher (priorité du propriétaire : « les 10 premières secondes »).
Levels.STARTING_TOWER = "MachineGun"

-- Pièces de niveau gagnées : première victoire, puis en rejouant (REPLAY_SHARE). Mini-boss et boss : bien plus.
-- Défaite : une petite part de la récompense « en rejouant », selon la part des monstres éliminés.
Levels.REPLAY_SHARE = 0.4
Levels.DEFEAT_SHARE = 0.5
function Levels.firstReward(level: number): number
	if level % 10 == 0 then
		return 600
	elseif level % 5 == 0 then
		return 300
	end
	return 60 + 20 * level
end

-- won = niveau gagné, firstClear = première victoire sur ce niveau, progress = part des monstres éliminés (0 à 1).
function Levels.reward(level: number, won: boolean, firstClear: boolean, progress: number?): number
	local first = Levels.firstReward(level)
	if won and firstClear then
		return first
	end
	local replay = math.floor(first * Levels.REPLAY_SHARE + 0.5)
	if won then
		return replay
	end
	return math.floor(replay * Levels.DEFEAT_SHARE * math.clamp(progress or 0, 0, 1))
end

-- Fiche d'un niveau : { level, map, palier (famille de monstres), gold, lives, boss, miniBoss, reward, replay }.
function Levels.definition(level: number)
	local source = Levels.DEFINITIONS[level]
	assert(source, "Niveau inconnu : " .. tostring(level))
	return {
		level = level,
		map = "Valley",
		palier = math.floor((level - 1) / 10),
		gold = source.gold,
		lives = Levels.LIVES,
		boss = level % 10 == 0,
		miniBoss = level % 5 == 0 and level % 10 ~= 0,
		reward = Levels.firstReward(level),
		replay = math.floor(Levels.firstReward(level) * Levels.REPLAY_SHARE + 0.5),
	}
end

-- PV d'un monstre de ce type à ce niveau ; factor = montée du moment (ramp), 1 si absente.
-- Taille affichée d'un monstre dans un niveau, par rapport à celle de la parcelle (Levels.ENEMY_SCALE).
function Levels.enemyScale(enemyType: string): number
	return Levels.ENEMY_SCALE[enemyType] or 1.6
end

function Levels.enemyHealth(level: number, enemyType: string, factor: number?): number
	local raw = Levels.DEFINITIONS[level].health * Levels.ENEMY[enemyType].health * (factor or 1)
	return math.floor(raw * 10 + 0.5) / 10
end

-- Type du monstre n° `slot` du flot (1, 2, 3...) à l'avancée `progress` (0 à 1) : voir « LE FLOT ».
local function streamType(source, slot: number, progress: number): string
	local from = source.from or {}
	local stream = Levels.STREAM
	if from.Tank and progress >= from.Tank and slot % stream.TANK_EVERY == 0 then
		return "Tank"
	elseif from.Swarm and progress >= from.Swarm and slot % stream.SWARM_EVERY == 0 then
		return "Swarm"
	elseif from.Fast and progress >= from.Fast and slot % stream.FAST_EVERY == 0 then
		return "Fast"
	end
	return "Normal"
end

-- File d'apparition d'un niveau : { { enemy, health, reward (or), at (secondes depuis le début) } }, dans l'ordre
-- des heures. Le flot continu décrit plus haut : toujours la même file pour le même niveau.
function Levels.buildQueue(level: number)
	local source = Levels.DEFINITIONS[level]
	assert(source, "Niveau inconnu : " .. tostring(level))
	local queue = {}
	local function push(enemyType: string, at: number, factor: number)
		table.insert(queue, { enemy = enemyType, health = Levels.enemyHealth(level, enemyType, factor), reward = Levels.ENEMY[enemyType].gold, at = at })
	end
	-- Monstres à part (mini-boss, boss), rangés par heure de sortie.
	local specials = {}
	for _, special in source.specials or {} do
		table.insert(specials, { enemy = special[1], at = special[2] * source.seconds, factor = special[3] or 1 })
	end
	table.sort(specials, function(a, b)
		return a.at < b.at
	end)
	local nextSpecial = 1
	local at, slot = 0, 0
	while at < source.seconds do
		while specials[nextSpecial] and specials[nextSpecial].at <= at do
			push(specials[nextSpecial].enemy, at, specials[nextSpecial].factor)
			nextSpecial += 1
		end
		local progress = at / source.seconds
		local ramp = Levels.STREAM.RAMP[1] + (Levels.STREAM.RAMP[2] - Levels.STREAM.RAMP[1]) * progress ^ Levels.STREAM.RAMP_CURVE
		slot += 1
		local enemyType = streamType(source, slot, progress)
		if enemyType == "Swarm" then
			for index = 1, Levels.STREAM.SWARM_PACK do
				push(enemyType, at + (index - 1) * Levels.STREAM.SWARM_GAP, ramp)
			end
			at += (Levels.STREAM.SWARM_PACK - 1) * Levels.STREAM.SWARM_GAP
		else
			push(enemyType, at, ramp)
		end
		at += source.gap[1] + (source.gap[2] - source.gap[1]) * progress
	end
	-- Ceux qui ferment le flot (boss).
	while specials[nextSpecial] do
		push(specials[nextSpecial].enemy, math.max(at, specials[nextSpecial].at), specials[nextSpecial].factor)
		nextSpecial += 1
	end
	return queue
end

-- Durée prévue d'un niveau (secondes) : le dernier monstre apparaît, puis traverse tout le chemin à sa vitesse.
function Levels.duration(level: number): number
	local queue = Levels.buildQueue(level)
	local last = queue[#queue]
	local def = Enemies.Defs[last.enemy]
	local speed = def.speed * IdleConfig.ENEMY_SPEED_MULTIPLIER * IdleConfig.enemySpeedFactor(last.enemy)
	return last.at + Levels.geometry(Levels.definition(level).map).PATH_LENGTH / speed
end

----------------------------------------------------------------------
-- Tours pendant un niveau. Les mêmes 8 tours que la parcelle (IdleTowers : dégâts, portée, effets), mais avec
-- leurs prix à elles, en OR : ceux de la parcelle n'ont pas de sens ici (là-bas l'Archer coûte 10 pièces et tout
-- se joue sur les améliorations).
--   poser : TOWER_COST ; améliorer du niveau n à n + 1 : prix de pose x UPGRADE_FACTOR x UPGRADE_GROWTH ^ (n - 1),
--   pour +35 % de dégâts (IdleConfig.UPGRADE_DAMAGE) ; revendre : SELL_REFUND de l'or dépensé.
-- Limite de tours identiques : celle de la parcelle (IdleTowers.maxCopies : 5 communes, 4 rares, 3 épiques,
-- 2 légendaires), sauf MAX_COPIES ci-dessous. Avec le seul Archer, on en pose 5 au plus : il faut les améliorer,
-- puis acheter d'autres tours. Le Totem de givre est limité à 3 : à 5, le joueur simulé en couvrait tout le chemin
-- et gagnait tout avec « 5 Archers + 5 Totems » (tools/levels).
-- Prix réglés pour que chaque tour vaille son or (joueur simulé, tools/levels) : une nouvelle tour rapporte à peu
-- près 2 fois plus de dégâts par pièce d'or qu'une amélioration ; l'Oracle (légendaire) est la meilleure affaire.
----------------------------------------------------------------------
Levels.TOWER_COST = { MachineGun = 20, Frost = 40, Bomb = 45, Tesla = 40, Rocket = 50, Laser = 90, Chain = 150, Orbital = 100 }
Levels.MAX_COPIES = { Frost = 3 }
-- Stats changées pour les niveaux seulement (la parcelle garde celles de IdleTowers) : { [type] = { champ = valeur } }.
-- Totem de givre : -40 % de vitesse au lieu de -60 %. Retour du propriétaire après avoir joué la 2e version
-- (02/10/2026) : « le ralentissement du givre est un peu cheaté quand même ». Mesuré avec le joueur simulé : à
-- -60 %, trois Totems (120 or) permettaient de battre des monstres 50 à 70 % plus résistants ; à -40 %, 23 à 29 %
-- (avec les Mages, qui ne ralentissent pas un monstre déjà gelé : 12 %). Il reste une bonne tour, plus LA tour.
-- Les PV des niveaux 3 à 10 ont été refaits avec ce réglage (run.ps1 -Tune) : à changer ensemble.
-- (L'amélioration d'entraînement « Gel profond », plus bas, ajoute 10 points : elle suit ce chiffre.)
Levels.TOWER_TWEAKS = {
	Frost = { slow = 0.4 },
}

function Levels.maxCopies(towerType: string): number
	return Levels.MAX_COPIES[towerType] or IdleTowers.maxCopies(towerType)
end
Levels.UPGRADE_FACTOR = 0.75
Levels.UPGRADE_GROWTH = 1.45
Levels.MAX_TOWER_LEVEL = 10
Levels.SELL_REFUND = 0.6

function Levels.placeCost(towerType: string): number
	return Levels.TOWER_COST[towerType]
end

-- Prix pour passer du niveau `level` au suivant ; nil au niveau maximum.
function Levels.upgradeCost(towerType: string, level: number): number?
	if level >= Levels.MAX_TOWER_LEVEL then
		return nil
	end
	return math.floor(Levels.TOWER_COST[towerType] * Levels.UPGRADE_FACTOR * Levels.UPGRADE_GROWTH ^ (level - 1) + 0.5)
end

----------------------------------------------------------------------
-- Boutique : les tours s'achètent à PRIX FIXES avec les pièces de niveau (aucun hasard, décision du propriétaire).
-- DEUX tours sont possédées dès le départ (retour du propriétaire, 02/10/2026 : « il faudrait commencer avec au
-- moins deux tours, juste l'Archer c'est ennuyant ») : l'Archer (une cible, rapide, pas cher) et la Catapulte (une
-- zone : utile quand les monstres arrivent serrés, à la fin d'un niveau). Un joueur qui n'avait que l'Archer
-- reçoit la Catapulte tout seul (cleanData). Pour changer la 2e tour : cette liste, et SHOP.
----------------------------------------------------------------------
Levels.STARTING_TOWERS = { "MachineGun", "Bomb" }
-- Prix : les deux premières tours se paient avec les pièces des premiers niveaux (Totem avant le niveau 3, Mage
-- avant le niveau 6). Les suivantes sont des buts à long terme. Retour du propriétaire (02/10/2026) : « les prix des
-- prochaines tours doivent être plus hauts, pas forcément les basiques mais les légendaires surtout » : avant, les
-- 10 niveaux réussis (2 180 pièces) puis 13 parties rejouées au niveau 10 (240 pièces chacune) suffisaient pour
-- l'Oracle (3 000), et 21 pour le Trébuchet (5 000). Maintenant : 34 parties pour l'Oracle, 63 pour le Trébuchet.
Levels.SHOP = { Frost = 150, Tesla = 400, Rocket = 1200, Laser = 3000, Chain = 8000, Orbital = 15000 }
-- Dans la première version du prototype, la Catapulte s'achetait 350 pièces et le Mage 700 : un joueur qui les
-- avait achetés retrouve la différence, une seule fois (sa sauvegarde d'avant n'a pas de champ `version` :
-- cleanData). Les tours plus chères ne rendent plus rien : leurs prix sont remontés depuis.
Levels.DATA_VERSION = 2
Levels.PRICE_REFUNDS = { Bomb = 350, Tesla = 300 }

----------------------------------------------------------------------
-- Camp d'entraînement. Chaque type de tour a de l'expérience (XP), qui donne un niveau d'entraînement (0 à
-- MAX_LEVEL). Chaque niveau : +DAMAGE_PER_LEVEL de dégâts en niveau, et des améliorations débloquées par paliers
-- (PERKS). L'XP vient de deux endroits :
--   * les emplacements du camp : la tour qu'on y met gagne SLOT_RATE XP par minute, même joueur absent (au plus
--     OFFLINE_MAX_SECONDS d'un coup) ; un emplacement s'améliore (SLOT_UPGRADE_COST) et on en débloque d'autres
--     (SLOT_UNLOCK_COST) avec les pièces de niveau ;
--   * jouer : chaque type de tour posé pendant un niveau gagne XP_PER_WIN (victoire), ou XP_PER_LOSS x la part
--     des monstres éliminés (défaite ou abandon : lancer un niveau et le quitter tout de suite ne donne rien).
-- Attendre n'est donc jamais la seule façon d'avancer (garde-fou voulu), et les premiers niveaux se gagnent sans
-- aucun entraînement.
----------------------------------------------------------------------
Levels.TRAINING = {
	MAX_LEVEL = 6,
	XP = { 20, 60, 140, 300, 600, 1200 }, -- XP total pour atteindre le niveau 1, 2, ... 6
	DAMAGE_PER_LEVEL = 0.05, -- +5 % de dégâts par niveau d'entraînement (+30 % au plus)
	SLOT_RATE = { 1, 1.5, 2.2, 3.2, 4.5 }, -- XP par minute selon le niveau de l'emplacement
	SLOT_UPGRADE_COST = { 120, 300, 700, 1500 }, -- prix pour passer au niveau 2, 3, 4, 5
	SLOT_UNLOCK_COST = { 0, 400, 1500 }, -- prix du 1er (offert), 2e et 3e emplacement
	OFFLINE_MAX_SECONDS = 12 * 3600,
	XP_PER_WIN = 8,
	XP_PER_LOSS = 3,
}

-- Améliorations débloquées par l'entraînement, par tour : { level (niveau d'entraînement), name, text }.
-- on(stats) = effet quand elle est débloquée ; off(stats) = ce qui est retiré tant qu'elle ne l'est pas (les effets
-- qui existent déjà dans IdleTowers : feu de l'Archer, fragilité du Totem, carreau perçant de la Baliste).
-- key = nom court publié aux clients (attribut « Perks » de la zone) pour n'afficher que les effets débloqués.
Levels.PERKS = {
	MachineGun = {
		{ level = 2, key = "Fire", name = "Flèches enflammées", text = "Chaque flèche laisse une petite zone de feu.", off = function(stats)
			stats.fireRadius = nil
		end },
		{ level = 4, name = "Longue-vue", text = "+3 de portée.", on = function(stats)
			stats.range += 3
		end },
		{ level = 6, name = "Tir rapide", text = "+20 % de vitesse d'attaque.", on = function(stats)
			stats.cooldown /= 1.2
		end },
	},
	Frost = {
		{ level = 2, key = "Fragile", name = "Givre mordant", text = "Les ennemis ralentis prennent plus de dégâts des autres tours.", off = function(stats)
			stats.fragility = 0
		end },
		{ level = 4, name = "Grande aura", text = "+2 de portée.", on = function(stats)
			stats.range += 2
		end },
		{ level = 6, name = "Gel profond", text = "Ralentit de 50 % au lieu de 40 %.", on = function(stats)
			stats.slow += 0.1
		end },
	},
	Bomb = {
		{ level = 2, name = "Gros rochers", text = "Zone d'impact plus large (+1,5).", on = function(stats)
			stats.splash += 1.5
		end },
		{ level = 4, name = "Bras long", text = "+3 de portée.", on = function(stats)
			stats.range += 3
		end },
		{ level = 6, name = "Rechargement rapide", text = "+20 % de vitesse d'attaque.", on = function(stats)
			stats.cooldown /= 1.2
		end },
	},
	Tesla = {
		{ level = 2, name = "Éclair large", text = "Zone de foudre plus large (+1).", on = function(stats)
			stats.splash += 1
		end },
		{ level = 4, name = "Long regard", text = "+3 de portée.", on = function(stats)
			stats.range += 3
		end },
		{ level = 6, name = "Tempête", text = "+20 % de vitesse d'attaque.", on = function(stats)
			stats.cooldown /= 1.2
		end },
	},
	Rocket = {
		{ level = 2, key = "Pierce", name = "Carreau perçant", text = "Le carreau transperce jusqu'à 3 ennemis alignés.", off = function(stats)
			stats.kind = "Single"
		end },
		{ level = 4, name = "Tir tendu", text = "+5 de portée.", on = function(stats)
			stats.range += 5
		end },
		{ level = 6, name = "Treuil graissé", text = "+20 % de vitesse d'attaque.", on = function(stats)
			stats.cooldown /= 1.2
		end },
	},
	Laser = {
		{ level = 2, name = "Concentration", text = "Le rayon chauffe 50 % plus vite.", on = function(stats)
			stats.beamRampRate *= 1.5
		end },
		{ level = 4, name = "Long rayon", text = "+3 de portée.", on = function(stats)
			stats.range += 3
		end },
		{ level = 6, name = "Surchauffe", text = "Le rayon monte 20 % plus haut.", on = function(stats)
			stats.beamRampMax *= 1.2
		end },
	},
	Chain = {
		{ level = 2, name = "Éclair bondissant", text = "Un ennemi de plus par éclair (5).", on = function(stats)
			stats.chains += 1
		end },
		{ level = 4, name = "Vision lointaine", text = "+3 de portée.", on = function(stats)
			stats.range += 3
		end },
		{ level = 6, name = "Orage", text = "+20 % de vitesse d'attaque.", on = function(stats)
			stats.cooldown /= 1.2
		end },
	},
	Orbital = {
		{ level = 2, name = "Pierre géante", text = "Zone d'impact plus large (+2).", on = function(stats)
			stats.splash += 2
		end },
		{ level = 4, name = "Onde de choc", text = "Étourdit plus longtemps (+0,3 s).", on = function(stats)
			stats.stunDuration += 0.3
		end },
		{ level = 6, name = "Contrepoids", text = "+20 % de vitesse d'attaque.", on = function(stats)
			stats.cooldown /= 1.2
		end },
	},
}

-- Niveau d'entraînement (0 à MAX_LEVEL) pour ce total d'XP.
function Levels.trainingLevel(xp: any): number
	local value = tonumber(xp) or 0
	local level = 0
	for index, needed in Levels.TRAINING.XP do
		if value >= needed then
			level = index
		end
	end
	return level
end

-- XP du niveau en cours et XP qu'il faut pour le suivant : (fait, total) ; au maximum : (0, 0).
function Levels.trainingProgress(xp: any): (number, number)
	local value = tonumber(xp) or 0
	local level = Levels.trainingLevel(value)
	if level >= Levels.TRAINING.MAX_LEVEL then
		return 0, 0
	end
	local from = if level == 0 then 0 else Levels.TRAINING.XP[level]
	return value - from, Levels.TRAINING.XP[level + 1] - from
end

local statsCache = {}

-- Stats d'une tour posée dans un niveau : son niveau de combat (acheté avec l'or), son entraînement (+5 % de dégâts
-- par niveau) et ses améliorations débloquées. Le tableau renvoyé ne doit jamais être modifié (il est partagé).
function Levels.towerStats(towerType: string, level: number, training: number?)
	local trained = math.clamp(math.floor(tonumber(training) or 0), 0, Levels.TRAINING.MAX_LEVEL)
	local key = `{towerType}:{level}:{trained}`
	local cached = statsCache[key]
	if cached then
		return cached
	end
	local stats = table.clone(IdleTowers.stats(towerType, level))
	for field, value in Levels.TOWER_TWEAKS[towerType] or {} do
		stats[field] = value
	end
	stats.damage *= 1 + Levels.TRAINING.DAMAGE_PER_LEVEL * trained
	for _, perk in Levels.PERKS[towerType] or {} do
		if trained >= perk.level then
			if perk.on then
				perk.on(stats)
			end
		elseif perk.off then
			perk.off(stats)
		end
	end
	statsCache[key] = stats
	return stats
end

-- Effets débloqués qui changent l'affichage, pour les tours données : texte « MachineGun:Fire,Rocket:Pierce »
-- (attribut « Perks » de la zone de combat, lu par PlotRenderer). training = { [type] = niveau d'entraînement }.
function Levels.perkKeys(training: { [string]: number }): string
	local keys = {}
	for _, towerType in IdleTowers.ORDER do
		for _, perk in Levels.PERKS[towerType] or {} do
			if perk.key and (training[towerType] or 0) >= perk.level then
				table.insert(keys, `{towerType}:{perk.key}`)
			end
		end
	end
	return table.concat(keys, ",")
end

-- Niveaux d'entraînement en texte, pour l'attribut « Training » de la zone de combat (ceux du DÉBUT du niveau :
-- ils ne changent pas pendant la partie) : « MachineGun=2,Frost=0,... ». Le client s'en sert pour afficher les
-- vraies stats de chaque tour posée.
function Levels.encodeTraining(training: { [string]: number }): string
	local parts = {}
	for _, towerType in IdleTowers.ORDER do
		table.insert(parts, `{towerType}={math.floor(tonumber(training[towerType]) or 0)}`)
	end
	return table.concat(parts, ",")
end

function Levels.decodeTraining(text: any): { [string]: number }
	local training = {}
	if typeof(text) == "string" then
		for towerType, level in string.gmatch(text, "(%a+)=(%d+)") do
			if IdleTowers.Defs[towerType] then
				training[towerType] = math.clamp(tonumber(level) or 0, 0, Levels.TRAINING.MAX_LEVEL)
			end
		end
	end
	return training
end

-- XP gagnée en jouant un niveau, par type de tour posé (voir TRAINING) : victoire = XP_PER_WIN ; défaite ou
-- abandon = XP_PER_LOSS x la part des monstres éliminés, arrondie au dixième.
function Levels.playXp(won: boolean, progress: number?): number
	if won then
		return Levels.TRAINING.XP_PER_WIN
	end
	return math.floor(Levels.TRAINING.XP_PER_LOSS * math.clamp(progress or 0, 0, 1) * 10 + 0.5) / 10
end

-- Améliorations débloquées en passant du niveau d'entraînement `before` à `after` : { { level, name, text } }.
function Levels.perksBetween(towerType: string, before: number, after: number)
	local list = {}
	for _, perk in Levels.PERKS[towerType] or {} do
		if perk.level > before and perk.level <= after then
			table.insert(list, perk)
		end
	end
	return list
end

----------------------------------------------------------------------
-- ÉVOLUTIONS. Demande du propriétaire (02/10/2026) : « tu peux gérer toute la parcelle et le système d'évolution de
-- tour ». L'entraînement fait ÉVOLUER chaque tour par paliers : chaque amélioration de PERKS est une évolution
-- (1re, 2e, 3e : aux niveaux d'entraînement 2, 4 et 6). Une tour évoluée se reconnaît :
--   * à ses étoiles (★ à ★★★) sur son étiquette, au camp comme dans un niveau ;
--   * à son apparence : anneau de bronze, d'argent puis d'or autour de son socle, fanions, joyaux
--     (Hub/IdleTowerModel.luau, addEvolution) ;
--   * à son nouveau pouvoir (PERKS), qu'on la voit utiliser au camp, sur les cibles d'entraînement.
----------------------------------------------------------------------
Levels.EVOLUTION_NAMES = { "1re évolution", "2e évolution", "3e évolution" }

-- Nombre d'évolutions débloquées (0 à 3) d'une tour à ce niveau d'entraînement.
function Levels.evolutionStage(towerType: string, training: any): number
	local trained = tonumber(training) or 0
	local stage = 0
	for _, perk in Levels.PERKS[towerType] or {} do
		if trained >= perk.level then
			stage += 1
		end
	end
	return stage
end

-- Étoiles d'une tour : « ★★ » pour 2 évolutions, rien sans évolution (texte prêt à afficher).
function Levels.stars(stage: number): string
	return string.rep("★", math.clamp(math.floor(tonumber(stage) or 0), 0, #Levels.EVOLUTION_NAMES))
end

----------------------------------------------------------------------
-- LE CAMP SUR LA PARCELLE. Même demande : la parcelle du joueur devient son camp d'entraînement (le jeu infini ne
-- tourne plus dessus : Config.LEVELS_CAMP_PLOT). Les tours mises dans les emplacements d'entraînement sont posées
-- pour de vrai sur des socles de la parcelle et tirent sur des CIBLES ROULANTES qui suivent le chemin : on les voit
-- s'entraîner, avec leurs évolutions (Hub/Camp.luau, Hub/CampGame.luau). L'XP, elle, vient toujours du temps passé
-- dans l'emplacement (TRAINING.SLOT_RATE) : les cibles ne rapportent rien.
--   SPOTS = socles de la parcelle (numéros de PlotLayout.SPOTS) des emplacements d'entraînement 1, 2, 3 : une
--           rangée face au chemin, juste devant le point d'arrivée du joueur. Les autres socles sont cachés.
--   TARGET_GAP = secondes entre deux cibles ; TARGET_SPEED = leur vitesse (part de celle d'un fantassin : elles
--           roulent lentement, les tours ont le temps de tirer) ;
--   TARGET_SECONDS = PV d'une cible, en secondes de tir de toutes les tours du camp réunies (dégâts de base, sans
--           l'entraînement : une tour entraînée ou évoluée les détruit donc plus vite, et ça se voit) ;
--           TARGET_MIN_HEALTH = PV au moins (un Totem seul ne fait presque pas de dégâts) ;
--   MAX_TARGETS = cibles sur le chemin au plus.
-- Réglé avec tools/levels : à la vitesse d'un fantassin et 45 PV, l'Archer seul tirait 4 flèches par seconde mais ne
-- détruisait que 4 cibles en 3 minutes (chaque cible sortait de sa portée à moitié cassée).
----------------------------------------------------------------------
Levels.CAMP = {
	SPOTS = { 7, 3, 4 },
	TARGET_GAP = 3.5,
	TARGET_SPEED = 0.5,
	TARGET_SECONDS = 2,
	TARGET_MIN_HEALTH = 12,
	MAX_TARGETS = 24,
}

----------------------------------------------------------------------
-- Données sauvegardées du joueur (data.levels, PlayerData.luau). Toujours propres : cleanData remet tout champ
-- absent ou abîmé à sa valeur de départ (une vieille sauvegarde, sans ce champ, donne un nouveau joueur des niveaux).
----------------------------------------------------------------------
function Levels.defaultData()
	local towers = {}
	for _, towerType in Levels.STARTING_TOWERS do
		towers[towerType] = true
	end
	return {
		best = 0, -- plus haut niveau réussi (0 = aucun) : le niveau best + 1 est le prochain à passer
		coins = 0, -- pièces de niveau
		towers = towers, -- [type] = true : tours débloquées
		xp = {}, -- [type] = XP d'entraînement
		slots = { { tower = Levels.STARTING_TOWERS[1], level = 1 } }, -- emplacements du camp (tower = "" : vide)
		trainedAt = 0, -- os.time() du dernier calcul de l'entraînement (0 = jamais)
		bar = table.clone(Levels.STARTING_TOWERS), -- tours de la barre rapide, dans l'ordre
		wins = 0,
		losses = 0,
		version = Levels.DATA_VERSION,
	}
end

local function cleanNumber(value: any, minimum: number, maximum: number, fallback: number): number
	local number = tonumber(value)
	if not number or number ~= number then
		return fallback
	end
	return math.clamp(number, minimum, maximum)
end

function Levels.cleanData(saved: any)
	local data = Levels.defaultData()
	if typeof(saved) ~= "table" then
		return data
	end
	data.best = math.floor(cleanNumber(saved.best, 0, Levels.COUNT, 0))
	data.coins = math.floor(cleanNumber(saved.coins, 0, 1e12, 0))
	data.wins = math.floor(cleanNumber(saved.wins, 0, 1e9, 0))
	data.losses = math.floor(cleanNumber(saved.losses, 0, 1e9, 0))
	data.trainedAt = math.floor(cleanNumber(saved.trainedAt, 0, 1e11, 0))
	if typeof(saved.towers) == "table" then
		for towerType, owned in saved.towers do
			if IdleTowers.Defs[towerType] and owned == true then
				data.towers[towerType] = true
				-- Sauvegarde de la première version : tour payée plus cher qu'aujourd'hui, la différence est rendue.
				if saved.version == nil and Levels.PRICE_REFUNDS[towerType] then
					data.coins += Levels.PRICE_REFUNDS[towerType]
				end
			end
		end
	end
	if typeof(saved.xp) == "table" then
		for towerType, xp in saved.xp do
			if IdleTowers.Defs[towerType] then
				data.xp[towerType] = cleanNumber(xp, 0, 1e9, 0)
			end
		end
	end
	if typeof(saved.slots) == "table" and #saved.slots >= 1 then
		data.slots = {}
		for index = 1, math.min(#saved.slots, #Levels.TRAINING.SLOT_UNLOCK_COST) do
			local slot = saved.slots[index]
			local tower = if typeof(slot) == "table" and data.towers[slot.tower] then slot.tower else ""
			local level = math.floor(cleanNumber(typeof(slot) == "table" and slot.level, 1, #Levels.TRAINING.SLOT_RATE, 1))
			table.insert(data.slots, { tower = tower, level = level })
		end
	end
	if typeof(saved.bar) == "table" then
		local bar, seen = {}, {}
		for _, towerType in saved.bar do
			if data.towers[towerType] and not seen[towerType] then
				seen[towerType] = true
				table.insert(bar, towerType)
			end
		end
		if #bar > 0 then
			data.bar = bar
		end
	end
	return data
end

-- Entraînement du camp jusqu'à `now` (os.time()) : chaque emplacement donne à sa tour SLOT_RATE XP par minute depuis
-- le dernier calcul, OFFLINE_MAX_SECONDS au plus d'un coup. Premier calcul (trainedAt = 0) : rien, l'heure est notée.
-- Renvoie l'XP gagnée par type : { [type] = XP } (vide si rien).
function Levels.accrueTraining(data, now: number): { [string]: number }
	local gained = {}
	local last = data.trainedAt
	data.trainedAt = now
	if typeof(last) ~= "number" or last <= 0 or now <= last then
		return gained
	end
	local minutes = math.min(now - last, Levels.TRAINING.OFFLINE_MAX_SECONDS) / 60
	for _, slot in data.slots do
		if slot.tower ~= "" and data.towers[slot.tower] then
			local amount = minutes * Levels.TRAINING.SLOT_RATE[slot.level]
			data.xp[slot.tower] = (data.xp[slot.tower] or 0) + amount
			gained[slot.tower] = (gained[slot.tower] or 0) + amount
		end
	end
	return gained
end

-- Niveaux d'entraînement de toutes les tours : { [type] = niveau }.
function Levels.trainingLevels(data): { [string]: number }
	local levels = {}
	for _, towerType in IdleTowers.ORDER do
		levels[towerType] = Levels.trainingLevel(data.xp[towerType])
	end
	return levels
end

-- Tours de la barre rapide et de l'inventaire, dans l'ordre : d'abord la barre du joueur, puis ses autres tours
-- (ordre de IdleTowers.ORDER). Toutes les tours débloquées peuvent être posées dans un niveau.
function Levels.ownedTowers(data): { string }
	local list, seen = {}, {}
	for _, towerType in data.bar do
		if data.towers[towerType] and not seen[towerType] then
			seen[towerType] = true
			table.insert(list, towerType)
		end
	end
	for _, towerType in IdleTowers.ORDER do
		if data.towers[towerType] and not seen[towerType] then
			seen[towerType] = true
			table.insert(list, towerType)
		end
	end
	return list
end

return Levels

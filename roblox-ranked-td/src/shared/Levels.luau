-- NIVEAUX : la nouvelle formule du jeu, en PROTOTYPE (demande du propriétaire, 02/10/2026 : « sors-moi tout un
-- prototype, même s'il n'est pas parfait »). Elle vit à côté du jeu actuel (parcelle infinie), sans y toucher.
--
-- Le principe, décidé avec le propriétaire :
--   * le jeu est une suite de niveaux : niveau 1, niveau 2, niveau 3... Chaque niveau est une partie à lui tout
--     seul : une longue vague de monstres qui arrivent en continu, un mini-boss dans la vague au niveau 5, un boss au
--     niveau 10. Dix niveaux = un territoire (une famille de monstres) ;
--   * dans un niveau : vue d'en haut, une base d'OR fixe au départ, l'or tombe tout seul à chaque monstre tué, on
--     pose ses tours OÙ ON VEUT et on les améliore sans arrêt, 10 vies ;
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
--   PV = PV du fantassin de ce niveau (champ health de sa définition) x part de son type (x le réglage du groupe).
-- gold = or donné quand il meurt ; leak = vies perdues s'il atteint le château.
----------------------------------------------------------------------
Levels.ENEMY = {
	Normal = { health = 1, gold = 2, leak = 1 },
	Fast = { health = 0.6, gold = 2, leak = 1 },
	Swarm = { health = 0.35, gold = 1, leak = 1 },
	Tank = { health = 4.5, gold = 6, leak = 2 },
	Giant = { health = 30, gold = 40, leak = 5 }, -- mini-boss (chevalier colossal)
	Boss = { health = 60, gold = 100, leak = 10 }, -- boss : s'il passe, c'est perdu
}
-- Secondes entre deux groupes d'un niveau (le flot ne s'arrête presque jamais).
Levels.GROUP_PAUSE = 2.5
-- Montée en pression dans un niveau : les monstres du premier groupe ont RAMP_START fois les PV du niveau, ceux du
-- dernier RAMP_END fois, les autres entre les deux (régulièrement). Le joueur commence avec peu d'or : les premiers
-- monstres doivent tomber vite, et lui donner de quoi poser la suite. Un groupe peut fixer sa part (champ health).
Levels.RAMP_START = 0.25
Levels.RAMP_END = 1.2
-- Bouton « envoyer la suite » : l'attente qui restait avant le prochain monstre est sautée, et chaque seconde
-- sautée rapporte cet or (au moins RUSH_MIN_SECONDS à sauter, sinon le bouton ne fait rien).
-- 2,2 s : le bouton ne sert qu'aux pauses ENTRE deux groupes (2,5 s et plus), jamais entre deux monstres d'un même
-- groupe (2 s au plus) : une prise de risque de temps en temps (5 à 9 pièces d'or), pas un bouton à marteler.
Levels.RUSH_GOLD_PER_SECOND = 2
Levels.RUSH_MIN_SECONDS = 2.2
-- Bouton « x2 » pendant un niveau (tout va 2 fois plus vite, comme le pass Vitesse x2 de la parcelle) :
--   true  -> pour tout le monde (prototype : un niveau doit pouvoir se jouer vite) ;
--   false -> seulement avec le pass Vitesse x2.
-- À décider par le propriétaire avant d'ouvrir les niveaux à tous les joueurs.
Levels.SPEED_FREE = true

-- Les groupes de chaque niveau, dans l'ordre : { type, nombre, secondes entre deux }. pause = attente après le
-- groupe (GROUP_PAUSE si absent), health = réglage des PV du groupe (1 si absent).
-- gold = or de départ. Niveau 1 : un Archer est déjà posé (Levels.STARTING_TOWER), l'or sert à poser le deuxième.
-- health = PV d'un fantassin à ce niveau (une flèche d'Archer : 3), réglés avec tools/levels (joueur simulé).
-- Chaque niveau dure 2 à 3 minutes et monte en pression : un début calme (le temps de poser ses premières tours
-- avec l'or de départ), puis des groupes de plus en plus serrés, et le mini-boss ou le boss vers la fin.
-- Niveau 1 (réglé avec tools/levels, run.ps1 -Lazy) : un joueur qui ne fait RIEN gagne quand même, mais de peu
-- (l'Archer offert laisse passer 4 monstres à la fin : 6 vies) ; dès qu'il pose une 2e tour, il ne perd plus une
-- vie. À 8 PV, ne rien faire gagnait sans perdre une vie (agir ne se voyait pas) ; à 13, c'était perdu.
Levels.DEFINITIONS = {
	{
		gold = 25,
		health = 11,
		groups = {
			{ "Normal", 8, 2.0 },
			{ "Normal", 12, 1.4 },
			{ "Fast", 8, 1.0 },
			{ "Normal", 16, 1.0 },
			{ "Fast", 10, 0.8 },
			{ "Normal", 20, 0.7 },
		},
	},
	{
		gold = 45,
		health = 19,
		groups = {
			{ "Normal", 12, 1.4 },
			{ "Fast", 10, 0.9 },
			{ "Normal", 18, 0.9 },
			{ "Fast", 12, 0.7 },
			{ "Normal", 22, 0.7 },
			{ "Fast", 16, 0.55 },
			{ "Normal", 24, 0.55 },
		},
	},
	{
		gold = 50,
		health = 42,
		groups = {
			{ "Normal", 13, 1.4 },
			{ "Fast", 11, 0.9 },
			{ "Normal", 20, 0.9 },
			{ "Swarm", 25, 0.35 },
			{ "Tank", 2, 2.2 },
			{ "Fast", 18, 0.6 },
			{ "Normal", 24, 0.6 },
			{ "Swarm", 29, 0.3 },
		},
	},
	{
		gold = 55,
		health = 66,
		groups = {
			{ "Normal", 14, 1.3 },
			{ "Fast", 12, 0.85 },
			{ "Normal", 22, 0.85 },
			{ "Swarm", 28, 0.33 },
			{ "Tank", 3, 2.0 },
			{ "Fast", 20, 0.55 },
			{ "Normal", 26, 0.55 },
			{ "Swarm", 32, 0.25 },
			{ "Tank", 3, 1.5 },
		},
	},
	{
		gold = 60,
		health = 95,
		groups = {
			{ "Normal", 15, 1.3 },
			{ "Fast", 13, 0.8 },
			{ "Normal", 24, 0.8 },
			{ "Swarm", 31, 0.3 },
			{ "Tank", 3, 2.0 },
			{ "Fast", 22, 0.55 },
			{ "Normal", 28, 0.55 },
			{ "Swarm", 35, 0.25 },
			{ "Tank", 3, 1.5, pause = 0 },
			{ "Giant", 1, 0, health = 1 },
		},
	},
	{
		gold = 65,
		health = 98,
		groups = {
			{ "Normal", 16, 1.2 },
			{ "Fast", 14, 0.8 },
			{ "Normal", 26, 0.75 },
			{ "Swarm", 34, 0.3 },
			{ "Tank", 4, 1.9 },
			{ "Fast", 24, 0.5 },
			{ "Normal", 30, 0.5 },
			{ "Swarm", 38, 0.22 },
			{ "Tank", 4, 1.4 },
		},
	},
	{
		gold = 70,
		health = 115,
		groups = {
			{ "Normal", 17, 1.2 },
			{ "Fast", 15, 0.75 },
			{ "Normal", 28, 0.7 },
			{ "Swarm", 37, 0.28 },
			{ "Tank", 4, 1.8 },
			{ "Fast", 26, 0.5 },
			{ "Normal", 32, 0.5 },
			{ "Swarm", 41, 0.22 },
			{ "Tank", 5, 1.3 },
		},
	},
	{
		gold = 75,
		health = 132,
		groups = {
			{ "Normal", 18, 1.1 },
			{ "Fast", 16, 0.7 },
			{ "Normal", 30, 0.7 },
			{ "Swarm", 40, 0.26 },
			{ "Tank", 5, 1.7 },
			{ "Fast", 28, 0.45 },
			{ "Normal", 34, 0.45 },
			{ "Giant", 1, 0, health = 1 },
			{ "Swarm", 44, 0.2 },
			{ "Tank", 5, 1.3 },
		},
	},
	{
		gold = 80,
		health = 150,
		groups = {
			{ "Normal", 19, 1.1 },
			{ "Fast", 17, 0.7 },
			{ "Normal", 32, 0.65 },
			{ "Swarm", 43, 0.25 },
			{ "Tank", 5, 1.6 },
			{ "Fast", 30, 0.45 },
			{ "Normal", 36, 0.45 },
			{ "Swarm", 47, 0.2 },
			{ "Tank", 6, 1.2 },
		},
	},
	{
		gold = 90,
		health = 170,
		groups = {
			{ "Normal", 20, 1.0 },
			{ "Fast", 18, 0.65 },
			{ "Normal", 34, 0.6 },
			{ "Swarm", 46, 0.24 },
			{ "Tank", 6, 1.5 },
			{ "Giant", 1, 0, health = 1 },
			{ "Fast", 32, 0.42 },
			{ "Normal", 38, 0.42 },
			{ "Swarm", 50, 0.2 },
			{ "Tank", 6, 1.2, pause = 0 },
			{ "Boss", 1, 0, health = 1 },
		},
	},
}

-- Niveau 1 : cette tour est déjà posée à l'arrivée du joueur (premier emplacement conseillé de la carte), pour
-- qu'il voie tout de suite le jeu marcher (priorité du propriétaire : « les 10 premières secondes »).
Levels.STARTING_TOWER = "MachineGun"

-- Pièces de niveau gagnées : première victoire, puis en rejouant (REPLAY_SHARE). Mini-boss et boss : bien plus.
-- Défaite : une petite part de la récompense « en rejouant », selon la part de la vague éliminée.
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

-- won = niveau gagné, firstClear = première victoire sur ce niveau, progress = part de la vague éliminée (0 à 1).
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

function Levels.enemyHealth(level: number, enemyType: string, groupFactor: number?): number
	local raw = Levels.DEFINITIONS[level].health * Levels.ENEMY[enemyType].health * (groupFactor or 1)
	return math.floor(raw * 10 + 0.5) / 10
end

-- File d'apparition d'un niveau : { { enemy, health, reward (or), at (secondes depuis le début) } }, dans l'ordre.
function Levels.buildQueue(level: number)
	local source = Levels.DEFINITIONS[level]
	assert(source, "Niveau inconnu : " .. tostring(level))
	local queue = {}
	local at = 0
	local groups = source.groups
	for index, group in groups do
		local enemyType, count, gap = group[1], group[2], group[3]
		local ramp = Levels.RAMP_START + (Levels.RAMP_END - Levels.RAMP_START) * (index - 1) / math.max(1, #groups - 1)
		local health = Levels.enemyHealth(level, enemyType, group.health or ramp)
		for _ = 1, count do
			table.insert(queue, { enemy = enemyType, health = health, reward = Levels.ENEMY[enemyType].gold, at = at })
			at += gap
		end
		at += group.pause or Levels.GROUP_PAUSE
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
-- L'Archer est possédé dès le départ.
----------------------------------------------------------------------
Levels.STARTING_TOWERS = { "MachineGun" }
Levels.SHOP = { Frost = 150, Bomb = 350, Tesla = 700, Rocket = 1200, Laser = 2000, Chain = 3500, Orbital = 6000 }

----------------------------------------------------------------------
-- Camp d'entraînement. Chaque type de tour a de l'expérience (XP), qui donne un niveau d'entraînement (0 à
-- MAX_LEVEL). Chaque niveau : +DAMAGE_PER_LEVEL de dégâts en niveau, et des améliorations débloquées par paliers
-- (PERKS). L'XP vient de deux endroits :
--   * les emplacements du camp : la tour qu'on y met gagne SLOT_RATE XP par minute, même joueur absent (au plus
--     OFFLINE_MAX_SECONDS d'un coup) ; un emplacement s'améliore (SLOT_UPGRADE_COST) et on en débloque d'autres
--     (SLOT_UNLOCK_COST) avec les pièces de niveau ;
--   * jouer : chaque type de tour posé pendant un niveau gagne XP_PER_WIN (victoire), ou XP_PER_LOSS x la part
--     de la vague éliminée (défaite ou abandon : lancer un niveau et le quitter tout de suite ne donne rien).
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
		{ level = 6, name = "Gel profond", text = "Ralentit de 70 % au lieu de 60 %.", on = function(stats)
			stats.slow = 0.7
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
-- abandon = XP_PER_LOSS x la part de la vague éliminée, arrondie au dixième.
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

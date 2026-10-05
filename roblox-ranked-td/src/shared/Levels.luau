-- NIVEAUX : les règles et les chiffres du jeu.
--
-- Le principe, décidé avec le propriétaire (02/10/2026) :
--   * le jeu est une suite de niveaux : niveau 1, niveau 2, niveau 3... Chaque niveau est une partie à lui tout
--     seul : un FLOT CONTINU de monstres, de plus en plus serrés et résistants jusqu'à la fin (voir « LE FLOT »), un
--     mini-boss dans le flot au niveau 5, un boss au niveau 10. Dix niveaux = un TERRITOIRE : sa carte, sa famille
--     de monstres (voir « Territoires ») ;
--   * dans un niveau : vue d'en haut, une base d'OR fixe au départ, l'or tombe tout seul à chaque monstre tué, on
--     pose ses tours OÙ ON VEUT et on les améliore sans arrêt (il le faut : sinon on perd), 10 vies ;
--   * à chaque niveau on repart avec seulement ses tours DÉBLOQUÉES (l'or et les tours posées ne se gardent pas) ;
--   * gagner un niveau rapporte un ŒUF (une tour au hasard, à faire éclore dans une couveuse : « LES ŒUFS ») et des
--     PIÈCES DE NIVEAU (plus la première fois, bien plus sur les boss ; on peut rejouer un niveau réussi pour en
--     regagner un peu). Plus de boutique (décision du propriétaire, 04/10/2026) : toutes les tours sortent des œufs,
--     sauf l'Archer, donné au départ (le niveau 1 donne l'œuf de la Catapulte). Les pièces servent au CAMP
--     D'ENTRAÎNEMENT, aux couveuses et à finir un œuf plus vite ;
--   * le camp d'entraînement : les tours qu'on y met s'entraînent, même quand le joueur est absent, et en jouant ;
--     l'entraînement ne donne que des dégâts, avec une étoile aux niveaux 2, 4 et 6 (« ÉVOLUTIONS ») ;
--   * pour l'instant, le jeu s'arrête au niveau OPEN_COUNT (40) : les niveaux suivants existent, ils seront ouverts
--     par les mises à jour du propriétaire (« comme ça je peux travailler les mises à jour petit à petit »).
-- Deux monnaies bien séparées : l'OR ne vit que le temps d'un niveau ; les PIÈCES DE NIVEAU se gardent.
--
-- Ce module ne contient que des règles et des chiffres (aucun objet Roblox en dehors de Vector3 / CFrame) : le
-- serveur (Hub/LevelGame.luau, Hub/LevelsService.luau), le client (LevelsUI.luau, PlotRenderer.luau) et le
-- simulateur hors Studio (tools/levels) lisent tous les mêmes.
local Enemies = require(script.Parent.Enemies)
local IdleConfig = require(script.Parent.IdleConfig)
local IdleTowers = require(script.Parent.IdleTowers)

local Levels = {}

Levels.COUNT = 100 -- niveaux du jeu : 10 territoires de 10 niveaux (voir « Territoires »)
-- Niveaux OUVERTS pour l'instant (décision du propriétaire, 04/10/2026 : « 16 tours qui te bloquent au niveau 40,
-- comme ça je peux travailler les mises à jour petit à petit »). Les niveaux suivants s'affichent « Bientôt » et ne
-- se lancent pas. Pour en ouvrir d'autres : ce chiffre (puis régler leur difficulté : tools/levels, run.ps1 -Tune).
Levels.OPEN_COUNT = 40

-- Vrai si ce niveau existe et peut se jouer (pas encore « Bientôt »).
function Levels.isOpen(level: any): boolean
	return typeof(level) == "number" and level >= 1 and level <= Levels.OPEN_COUNT and level % 1 == 0
end
Levels.LIVES = 10

----------------------------------------------------------------------
-- Zones de combat : une par joueur, dans le MÊME serveur que la map principale (pas de téléportation, donc pas
-- d'écran de chargement), loin de la place. Le joueur de la parcelle n joue dans la zone n quand elle est libre
-- (sinon dans une autre zone libre) ; une équipe joue dans une seule zone (voir « JOUER EN ÉQUIPE »). Pour
-- l'affichage, une zone est une « parcelle » de plus : son numéro est FIRST_ARENA_INDEX + n (paquets PlotSync /
-- PlotShots).
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
-- conseillé : la tour offerte du niveau 1 est posée sur le premier, le joueur simulé les essaie d'abord. Rien ne
-- les montre au joueur : il pose où il veut (demande du propriétaire, 03/10/2026 : « enlève les emplacements jaunes,
-- je veux que ce soit libre »).
-- Les cartes d'ÉQUIPE (une par territoire et par nombre de joueurs : Shared/TeamMaps.luau) ont plusieurs couloirs
-- (lanes : un par joueur, de son entrée au château) ; une carte seule n'en a qu'un, son chemin (path). Après le
-- tableau MAPS, toutes les cartes ont les deux : lanes, et path = le premier couloir.
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
	-- 2e territoire (niveaux 11 à 20). Le chemin fait le tour du terrain puis revient vers le château, au milieu :
	-- trois couloirs presque parallèles (en haut, en bas, au milieu). Une tour posée entre deux couloirs tire sur
	-- les deux : les monstres passent deux ou trois fois devant elle. Chemin plus long que la vallée (282 studs au
	-- lieu de 204) : ils restent plus longtemps sous les tirs, et ils sont plus résistants.
	Pass = {
		displayName = "Le col des Pillards de cuivre",
		width = 112,
		depth = 52,
		path = {
			Vector3.new(-56, 0, -16),
			Vector3.new(42, 0, -16),
			Vector3.new(42, 0, 16),
			Vector3.new(-40, 0, 16),
			Vector3.new(-40, 0, 0),
			Vector3.new(14, 0, 0),
		},
		base = Vector3.new(18, 0, 0),
		spots = {
			Vector3.new(-13, 0, -8),
			Vector3.new(-13, 0, 8),
			Vector3.new(8, 0, -8),
			Vector3.new(8, 0, 8),
			Vector3.new(30, 0, 0),
			Vector3.new(-30, 0, -8),
			Vector3.new(-30, 0, 8),
			Vector3.new(-47, 0, 8),
			Vector3.new(24, 0, -8),
			Vector3.new(24, 0, 8),
			Vector3.new(-47, 0, -6),
			Vector3.new(48, 0, 0),
		},
	},
	-- 3e territoire (niveaux 21 à 30). Le chemin descend le terrain en S : trois longs couloirs (en haut, au milieu,
	-- en bas), le château dans le coin en bas à droite. Une tour posée entre deux couloirs tire sur les deux.
	-- 308 studs : le plus long chemin (les monstres sont plus résistants).
	Forest = {
		displayName = "La forêt des Gardiens des ronces",
		width = 112,
		depth = 52,
		path = {
			Vector3.new(-56, 0, -18),
			Vector3.new(42, 0, -18),
			Vector3.new(42, 0, 0),
			Vector3.new(-42, 0, 0),
			Vector3.new(-42, 0, 18),
			Vector3.new(48, 0, 18),
		},
		base = Vector3.new(52, 0, 18),
		spots = {
			Vector3.new(-8, 0, -9),
			Vector3.new(12, 0, 9),
			Vector3.new(12, 0, -9),
			Vector3.new(-8, 0, 9),
			Vector3.new(30, 0, -9),
			Vector3.new(-28, 0, 9),
			Vector3.new(-28, 0, -9),
			Vector3.new(30, 0, 9),
			Vector3.new(-46, 0, -9),
			Vector3.new(48, 0, 9),
			Vector3.new(48, 0, -9),
			Vector3.new(-48, 0, 9),
		},
	},
	-- 4e territoire (niveaux 31 à 40). Le chemin serpente de haut en bas : cinq passages verticaux serrés (20 studs
	-- entre deux), puis le château au milieu à droite. Une tour posée entre deux passages tire sur les deux, et les
	-- monstres passent devant beaucoup de tours. 266 studs.
	Glacier = {
		displayName = "Le glacier de la Légion du givre",
		width = 112,
		depth = 52,
		path = {
			Vector3.new(-56, 0, -18),
			Vector3.new(-40, 0, -18),
			Vector3.new(-40, 0, 18),
			Vector3.new(-20, 0, 18),
			Vector3.new(-20, 0, -18),
			Vector3.new(0, 0, -18),
			Vector3.new(0, 0, 18),
			Vector3.new(20, 0, 18),
			Vector3.new(20, 0, -18),
			Vector3.new(40, 0, -18),
			Vector3.new(40, 0, 0),
			Vector3.new(48, 0, 0),
		},
		base = Vector3.new(52, 0, 0),
		spots = {
			Vector3.new(-10, 0, 0),
			Vector3.new(10, 0, 0),
			Vector3.new(-30, 0, 0),
			Vector3.new(30, 0, 0),
			Vector3.new(-10, 0, -10),
			Vector3.new(10, 0, 10),
			Vector3.new(-30, 0, 10),
			Vector3.new(30, 0, -10),
			Vector3.new(-10, 0, 10),
			Vector3.new(10, 0, -10),
			Vector3.new(-48, 0, -6),
			Vector3.new(48, 0, 10),
		},
	},
	-- 5e territoire (niveaux 41 à 50). Le chemin fait le tour du terrain en grand U : tout droit en haut, il descend à
	-- droite, revient en bas avec un crochet au milieu, et le château est EN BAS À GAUCHE, près de la porte d'entrée.
	-- Une tour posée au milieu du terrain voit le haut et le crochet. 252 studs.
	Desert = {
		displayName = "Le désert des Gardes des dunes",
		width = 112,
		depth = 52,
		path = {
			Vector3.new(-56, 0, -18),
			Vector3.new(44, 0, -18),
			Vector3.new(44, 0, 18),
			Vector3.new(8, 0, 18),
			Vector3.new(8, 0, 2),
			Vector3.new(-20, 0, 2),
			Vector3.new(-20, 0, 18),
			Vector3.new(-40, 0, 18),
		},
		base = Vector3.new(-44, 0, 18),
		spots = {
			Vector3.new(-6, 0, -8),
			Vector3.new(18, 0, -8),
			Vector3.new(-30, 0, -8),
			Vector3.new(26, 0, 8),
			Vector3.new(-6, 0, 10),
			Vector3.new(-32, 0, 8),
			Vector3.new(34, 0, -8),
			Vector3.new(8, 0, -8),
			Vector3.new(-48, 0, -8),
			Vector3.new(50, 0, 0),
			Vector3.new(-48, 0, 6),
			Vector3.new(34, 0, 8),
		},
	},
	-- 6e territoire (niveaux 51 à 60). Le chemin a la forme d'une couronne : il descend deux marches, longe le bas,
	-- remonte deux marches, revient tout en haut jusqu'au milieu, puis plonge vers le château, AU CENTRE du terrain.
	-- Les tours posées dans le creux de la couronne voient trois ou quatre bouts de chemin. 252 studs.
	Necropolis = {
		displayName = "La nécropole de la Légion des os",
		width = 112,
		depth = 52,
		path = {
			Vector3.new(-56, 0, -20),
			Vector3.new(-40, 0, -20),
			Vector3.new(-40, 0, 0),
			Vector3.new(-24, 0, 0),
			Vector3.new(-24, 0, 20),
			Vector3.new(24, 0, 20),
			Vector3.new(24, 0, 0),
			Vector3.new(40, 0, 0),
			Vector3.new(40, 0, -20),
			Vector3.new(-8, 0, -20),
			Vector3.new(-8, 0, 8),
		},
		base = Vector3.new(-8, 0, 12),
		spots = {
			Vector3.new(-16, 0, 10),
			Vector3.new(-16, 0, -8),
			Vector3.new(14, 0, 8),
			Vector3.new(32, 0, -10),
			Vector3.new(-32, 0, -10),
			Vector3.new(-32, 0, 10),
			Vector3.new(32, 0, 10),
			Vector3.new(0, 0, 8),
			Vector3.new(8, 0, -8),
			Vector3.new(-48, 0, -8),
			Vector3.new(48, 0, -8),
			Vector3.new(0, 0, -8),
		},
	},
	-- 7e territoire (niveaux 61 à 70). À gauche, le chemin plonge trois fois vers le bas (des « dents » serrées : une
	-- tour posée entre deux dents tire sur les deux), puis fait un grand crochet à droite jusqu'au château, en bas à
	-- droite. 252 studs.
	Storm = {
		displayName = "La citadelle de la Garde de la tempête",
		width = 112,
		depth = 52,
		path = {
			Vector3.new(-56, 0, -20),
			Vector3.new(-40, 0, -20),
			Vector3.new(-40, 0, 16),
			Vector3.new(-28, 0, 16),
			Vector3.new(-28, 0, -8),
			Vector3.new(-12, 0, -8),
			Vector3.new(-12, 0, 16),
			Vector3.new(0, 0, 16),
			Vector3.new(0, 0, -20),
			Vector3.new(40, 0, -20),
			Vector3.new(40, 0, 16),
		},
		base = Vector3.new(44, 0, 16),
		spots = {
			Vector3.new(-34, 0, 4),
			Vector3.new(-6, 0, 4),
			Vector3.new(20, 0, -2),
			Vector3.new(-20, 0, 6),
			Vector3.new(10, 0, 6),
			Vector3.new(30, 0, 6),
			Vector3.new(20, 0, -12),
			Vector3.new(-48, 0, -8),
			Vector3.new(-20, 0, -16),
			Vector3.new(48, 0, 0),
			Vector3.new(-48, 0, 10),
			Vector3.new(10, 0, 20),
		},
	},
	-- 8e territoire (niveaux 71 à 80). Deux grands passages verticaux à gauche, un long couloir tout en haut, puis
	-- le chemin revient vers la gauche par le milieu jusqu'au château, en bas au centre. 270 studs.
	Obsidian = {
		displayName = "Le volcan des Chevaliers d'obsidienne",
		width = 112,
		depth = 52,
		path = {
			Vector3.new(-56, 0, -20),
			Vector3.new(-36, 0, -20),
			Vector3.new(-36, 0, 20),
			Vector3.new(-16, 0, 20),
			Vector3.new(-16, 0, -20),
			Vector3.new(48, 0, -20),
			Vector3.new(48, 0, 4),
			Vector3.new(-2, 0, 4),
			Vector3.new(-2, 0, 16),
		},
		base = Vector3.new(-2, 0, 20),
		spots = {
			Vector3.new(-26, 0, 0),
			Vector3.new(-46, 0, 0),
			Vector3.new(-6, 0, -8),
			Vector3.new(20, 0, -8),
			Vector3.new(40, 0, -8),
			Vector3.new(20, 0, 14),
			Vector3.new(6, 0, 14),
			Vector3.new(-26, 0, -20),
			Vector3.new(-9, 0, 12),
			Vector3.new(36, 0, 14),
			Vector3.new(-46, 0, 14),
			Vector3.new(52, 0, 14),
		},
	},
	-- 9e territoire (niveaux 81 à 90). L'entrée est au MILIEU du bord gauche ; le chemin serpente ensuite de haut en
	-- bas en cinq passages (16 studs entre deux), jusqu'au château, à droite. 272 studs.
	Goblin = {
		displayName = "Les marais de la Horde gobeline",
		width = 112,
		depth = 52,
		path = {
			Vector3.new(-56, 0, 0),
			Vector3.new(-44, 0, 0),
			Vector3.new(-44, 0, -20),
			Vector3.new(-24, 0, -20),
			Vector3.new(-24, 0, 12),
			Vector3.new(-8, 0, 12),
			Vector3.new(-8, 0, -20),
			Vector3.new(8, 0, -20),
			Vector3.new(8, 0, 12),
			Vector3.new(24, 0, 12),
			Vector3.new(24, 0, -20),
			Vector3.new(44, 0, -20),
			Vector3.new(44, 0, 4),
		},
		base = Vector3.new(44, 0, 8),
		spots = {
			Vector3.new(-16, 0, -4),
			Vector3.new(0, 0, -4),
			Vector3.new(16, 0, -4),
			Vector3.new(-34, 0, -8),
			Vector3.new(34, 0, -4),
			Vector3.new(-16, 0, 20),
			Vector3.new(16, 0, 20),
			Vector3.new(0, 0, 20),
			Vector3.new(-34, 0, 12),
			Vector3.new(-50, 0, -10),
			Vector3.new(34, 0, 14),
			Vector3.new(0, 0, -12),
		},
	},
	-- 10e et dernier territoire (niveaux 91 à 100). La grande spirale : le chemin fait le tour du terrain, puis un
	-- deuxième tour plus serré, et finit au château, presque au centre. 330 studs : le plus long chemin du jeu.
	Dragon = {
		displayName = "Le repaire de la Couvée du dragon",
		width = 112,
		depth = 52,
		path = {
			Vector3.new(-56, 0, -20),
			Vector3.new(44, 0, -20),
			Vector3.new(44, 0, 20),
			Vector3.new(-42, 0, 20),
			Vector3.new(-42, 0, -6),
			Vector3.new(24, 0, -6),
			Vector3.new(24, 0, 6),
		},
		base = Vector3.new(20, 0, 6),
		spots = {
			Vector3.new(-10, 0, -13),
			Vector3.new(10, 0, -13),
			Vector3.new(-30, 0, -13),
			Vector3.new(34, 0, -6),
			Vector3.new(0, 0, 7),
			Vector3.new(-24, 0, 7),
			Vector3.new(34, 0, 10),
			Vector3.new(12, 0, 10),
			Vector3.new(-50, 0, 4),
			Vector3.new(50, 0, 0),
			Vector3.new(-10, 0, 13),
			Vector3.new(-36, 0, 7),
		},
	},
}

-- Les cartes d'équipe rejoignent les autres (« Valley_2 », « Valley_3 », « Valley_4 »... : voir Levels.mapFor).
for name, map in require(script.Parent.TeamMaps) do
	Levels.MAPS[name] = map
end
for _, map in Levels.MAPS do
	map.lanes = map.lanes or { map.path }
	map.path = map.lanes[1]
end

----------------------------------------------------------------------
-- Territoires. Demande du propriétaire (02/10/2026) : « ajoute des niveaux ». Un territoire = TERRITORY_SIZE niveaux
-- sur la même carte, contre la même famille de monstres (leur apparence suit le territoire : MedievalModels et
-- CustomModels, palier = territoire - 1 ; le décor de la carte aussi : Hub/LevelArena.luau), avec un mini-boss au
-- milieu et un boss à la fin. Niveaux 1 à 10 : le premier ; 11 à 20 : le deuxième ; 21 à 30 : le troisième ; 31 à
-- 40 : le quatrième (demande du propriétaire, 03/10/2026 : « continue les niveaux jusqu'à 40 ») ; 41 à 50 : le
-- cinquième ; 51 à 60 : le sixième (« fais encore 20 », le même jour) ; 61 à 100 : les quatre derniers, jusqu'au
-- dragon, le dernier boss (« fais les 50 derniers », le même jour).
-- Pour en ajouter un : sa carte dans MAPS, son nom ici, ses 10 niveaux dans DEFINITIONS (PV trouvés avec
-- tools\levels\run.ps1 -Tune), ce que le joueur a en y arrivant dans tools/levels/Bot.luau (Bot.EXPECTED), son
-- décor dans LevelArena.luau (THEMES), puis COUNT.
----------------------------------------------------------------------
Levels.TERRITORY_SIZE = 10
Levels.TERRITORIES = { "Valley", "Pass", "Forest", "Glacier", "Desert", "Necropolis", "Storm", "Obsidian", "Goblin", "Dragon" } -- carte de chaque territoire (clé de MAPS)

-- Numéro du territoire d'un niveau (1, 2...).
function Levels.territoryOf(level: number): number
	return math.floor((level - 1) / Levels.TERRITORY_SIZE) + 1
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local geometries = {}

-- Un couloir : { points, PATH_LENGTH, pointAt(distance) -> (point local, direction) }.
local function lanePath(path: { Vector3 })
	local cumulative = { 0 }
	for i = 2, #path do
		cumulative[i] = cumulative[i - 1] + (path[i] - path[i - 1]).Magnitude
	end
	local lane = { points = path, PATH_LENGTH = cumulative[#cumulative] }

	function lane.pointAt(distance: number): (Vector3, Vector3)
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

	return lane
end

-- Géométrie d'une carte : { map, name, lanes (ses couloirs, voir lanePath ; un seul pour une carte seule),
-- PATH_LENGTH (le plus long couloir), pointAt(distance) -> (point local, direction) (celui du premier couloir),
-- segments = { { a, b } } (les bouts de chemin, chacun une seule fois : des couloirs qui se rejoignent partagent
-- les leurs), distanceToPath(point local) -> studs (jusqu'au chemin le plus proche, tous couloirs confondus) }.
-- La même table à chaque appel.
function Levels.geometry(mapName: string)
	local geometry = geometries[mapName]
	if geometry then
		return geometry
	end
	local map = Levels.MAPS[mapName]
	assert(map, "Carte inconnue : " .. tostring(mapName))
	local lanes, longest = {}, 0
	local segments, seen = {}, {}
	for index, points in map.lanes do
		lanes[index] = lanePath(points)
		longest = math.max(longest, lanes[index].PATH_LENGTH)
		for i = 2, #points do
			local a, b = points[i - 1], points[i]
			local key = `{a.X},{a.Z}>{b.X},{b.Z}`
			if not seen[key] then
				seen[key] = true
				table.insert(segments, { a = a, b = b })
			end
		end
	end
	geometry = { map = map, name = mapName, lanes = lanes, PATH_LENGTH = longest, pointAt = lanes[1].pointAt, segments = segments }

	function geometry.distanceToPath(localPosition: Vector3): number
		local p = flat(localPosition)
		local best = math.huge
		for _, segment in segments do
			local a, b = segment.a, segment.b
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
-- Monstres d'un niveau. Leurs PV sont petits et lisibles.
--   PV = PV du fantassin de ce niveau (champ health de sa définition) x part de son type x montée du moment (ramp).
-- gold = or donné quand il meurt ; leak = vies perdues s'il atteint le château.
----------------------------------------------------------------------
Levels.ENEMY = {
	Normal = { health = 1, gold = 6, leak = 1 },
	Fast = { health = 0.6, gold = 6, leak = 1 },
	Swarm = { health = 0.35, gold = 2, leak = 1 },
	Tank = { health = 4.5, gold = 18, leak = 2 },
	Giant = { health = 30, gold = 120, leak = 5 }, -- chevalier colossal
	Colossus = { health = 75, gold = 300, leak = 10 }, -- colosse géant (mini-boss des niveaux 15, 25, 35) : s'il passe, c'est perdu
	Boss = { health = 60, gold = 300, leak = 10 }, -- boss : s'il passe, c'est perdu
}
-- TAILLE AFFICHÉE des monstres dans un niveau (demande du propriétaire, 02/10/2026 : « j'aurais agrandi aussi les
-- monstres pour bien les voir ») : la carte est vue de haut et de loin, surtout sur téléphone. Multiplie la taille du
-- modèle, de sa barre de vie et de ses effets (client/PlotRenderer.luau). AFFICHAGE SEULEMENT : le combat ne connaît
-- que la place du monstre sur le chemin, la difficulté ne change pas. 1 = sa taille de base (Enemies.luau).
-- Les gros (colosse, colosse géant, boss) grossissent moins : ils déborderaient trop du chemin (6 studs de large).
Levels.ENEMY_SCALE = { Normal = 1.8, Fast = 1.8, Swarm = 2, Tank = 1.6, Giant = 1.4, Colossus = 1.35, Boss = 1.4 }

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
-- faibles) } : mini-boss du niveau 5, colosses des niveaux 8 et 10, boss du niveau 10, colosse géant des niveaux
-- 15, 25 et 35.
-- Rien n'est tiré au hasard : le même niveau donne toujours exactement le même flot. Seule exception, en équipe :
-- le couloir de chaque gros monstre (colosse, colosse géant, boss) est tiré au sort à chaque partie (Levels.buildQueue).
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
-- pose 2 Archers puis attend perd avant 30 % du niveau (tests.luau le vérifie pour les niveaux ouverts). Trop dur ou
-- trop facile pour de vrais joueurs : baisser ou monter ce chiffre, rien d'autre.
-- Les niveaux à colosse (5, 8) et à boss (10) ont un flot un peu moins résistant : le gros monstre fait le reste.
-- NIVEAUX 11 À 20 (2e territoire, carte « Pass ») : plus d'or au départ, des niveaux un peu plus longs, tous les
-- types de monstres dès le début, et des COLOSSES dans presque tous les niveaux (un, puis deux, puis trois). Niveau
-- 15 : le COLOSSE GÉANT (mini-boss : un seul monstre, bien plus résistant). Niveau 20 : deux colosses, puis le boss,
-- qui ferme le flot comme au niveau 10. (Sorti PENDANT le flot, il se faisait doubler par les monstres rapides : les
-- tours qui visent « le plus avancé » ne le touchaient plus, et le joueur simulé très actif perdait après avoir tout
-- éliminé sauf lui.) Réglés pour le joueur qui a les tours des premiers œufs (le Totem et le Mage), puis une tour
-- de PALIER 2 à partir du niveau 16 : le boss du niveau 20 la demande vraiment (Bot.EXPECTED).
-- NIVEAUX 21 À 40 (3e et 4e territoires, cartes « Forest » et « Glacier ») : même principe, plus de colosses
-- (trois, puis quatre), le colosse géant au niveau 25, deux colosses géants au niveau 35, un boss qui ferme le flot
-- aux niveaux 30 et 40. Réglés pour le joueur qui a deux, puis trois tours de palier 2, avec l'entraînement que
-- ces parties donnent (Bot.EXPECTED). Les niveaux à boss sont un peu plus courts : le boss doit encore traverser la
-- carte (200 s au plus en tout).
-- NIVEAUX 41 À 100 : FERMÉS pour l'instant (Levels.OPEN_COUNT). Les PV des niveaux 41 à 50 sont réglés pour les
-- œufs (05/10/2026 : le joueur qui a les mêmes 8 tours qu'au 4e territoire, un peu plus entraînées, Bot.EXPECTED ;
-- run.ps1 -Tune -Vies 8, puis 5 % de marge, sauf aux niveaux 41 et 46 : le joueur lent y gagnait encore) : ouvrir le
-- désert = OPEN_COUNT = 50. Ceux des niveaux 51 à 100
-- datent de la boutique (réglés pour les huit tours de palier 1) : à régler de nouveau avant de les ouvrir. Ce
-- qu'ils contiennent :
-- NIVEAUX 41 À 60 (5e et 6e territoires, cartes « Desert » et « Necropolis ») : quatre ou cinq colosses par niveau,
-- quatre à la file au niveau 45, un trio puis une paire au niveau 55, un boss qui ferme le flot aux niveaux 50 et
-- 60. Leurs chemins sont plus courts (252 studs) : les monstres sortent un peu moins serrés au
-- début (1 s), pour laisser le temps de poser ses premières tours.
-- NIVEAUX 61 À 100 (territoires 7 à 10, cartes « Storm », « Obsidian », « Goblin », « Dragon ») : cinq colosses par
-- niveau ; mini-boss : cinq colosses à la file (65), un gros colosse parmi quatre autres (75), deux paires et un géant
-- (85), un groupe autour d'un gros (95) ; un boss ferme le flot aux niveaux 70, 80, 90 et 100 (le dragon, plus
-- résistant).
Levels.DEFINITIONS = {
	{ gold = 60, seconds = 95, health = 58, gap = { 1.1, 0.34 }, from = { Fast = 0.25 } },
	{ gold = 65, seconds = 105, health = 88, gap = { 1.1, 0.33 }, from = { Fast = 0.15, Swarm = 0.45 } },
	{ gold = 70, seconds = 115, health = 66, gap = { 1.05, 0.32 }, from = { Fast = 0.15, Swarm = 0.3, Tank = 0.6 } },
	{ gold = 75, seconds = 120, health = 72, gap = { 1.05, 0.31 }, from = { Fast = 0.1, Swarm = 0.25, Tank = 0.45 } },
	{ gold = 80, seconds = 130, health = 62, gap = { 1, 0.3 }, from = { Fast = 0.1, Swarm = 0.25, Tank = 0.4 }, specials = { { "Giant", 0.75 } } },
	{ gold = 85, seconds = 130, health = 86, gap = { 1, 0.3 }, from = { Fast = 0.1, Swarm = 0.2, Tank = 0.35 } },
	{ gold = 90, seconds = 135, health = 86, gap = { 1, 0.29 }, from = { Fast = 0.1, Swarm = 0.2, Tank = 0.3 } },
	{ gold = 95, seconds = 140, health = 80, gap = { 0.95, 0.29 }, from = { Fast = 0.1, Swarm = 0.2, Tank = 0.3 }, specials = { { "Giant", 0.6, 0.8 } } },
	{ gold = 100, seconds = 145, health = 99, gap = { 0.95, 0.28 }, from = { Fast = 0.1, Swarm = 0.2, Tank = 0.25 } },
	{ gold = 110, seconds = 155, health = 86, gap = { 0.95, 0.28 }, from = { Fast = 0.1, Swarm = 0.2, Tank = 0.25 }, specials = { { "Giant", 0.5, 0.7 }, { "Boss", 1 } } },
	-- 2e territoire
	{ gold = 115, seconds = 130, health = 158, gap = { 0.95, 0.3 }, from = { Fast = 0.1, Swarm = 0.2, Tank = 0.25 } },
	{ gold = 120, seconds = 135, health = 150, gap = { 0.95, 0.3 }, from = { Fast = 0.1, Swarm = 0.2, Tank = 0.25 }, specials = { { "Giant", 0.75, 0.8 } } },
	{ gold = 125, seconds = 135, health = 145, gap = { 0.95, 0.3 }, from = { Fast = 0.1, Swarm = 0.15, Tank = 0.25 }, specials = { { "Giant", 0.6, 0.8 } } },
	{ gold = 130, seconds = 140, health = 150, gap = { 0.95, 0.3 }, from = { Fast = 0.1, Swarm = 0.15, Tank = 0.2 }, specials = { { "Giant", 0.45, 0.7 }, { "Giant", 0.85 } } },
	{ gold = 135, seconds = 145, health = 120, gap = { 0.95, 0.3 }, from = { Fast = 0.1, Swarm = 0.15, Tank = 0.2 }, specials = { { "Colossus", 0.71, 0.6 } } },
	{ gold = 140, seconds = 145, health = 190, gap = { 0.9, 0.3 }, from = { Fast = 0.05, Swarm = 0.15, Tank = 0.2 }, specials = { { "Giant", 0.4, 0.7 }, { "Giant", 0.8 } } },
	{ gold = 145, seconds = 150, health = 178, gap = { 0.9, 0.3 }, from = { Fast = 0.05, Swarm = 0.1, Tank = 0.2 }, specials = { { "Giant", 0.35, 0.7 }, { "Giant", 0.6, 0.85 }, { "Giant", 0.85 } } },
	{ gold = 150, seconds = 150, health = 178, gap = { 0.9, 0.3 }, from = { Fast = 0.05, Swarm = 0.1, Tank = 0.15 }, specials = { { "Giant", 0.3, 0.7 }, { "Giant", 0.55, 0.85 }, { "Giant", 0.8 } } },
	{ gold = 155, seconds = 155, health = 169, gap = { 0.9, 0.3 }, from = { Fast = 0.05, Swarm = 0.1, Tank = 0.15 }, specials = { { "Giant", 0.3, 0.8 }, { "Giant", 0.55 }, { "Giant", 0.8, 1.2 } } },
	{ gold = 160, seconds = 145, health = 125, gap = { 0.9, 0.3 }, from = { Fast = 0.05, Swarm = 0.1, Tank = 0.15 }, specials = { { "Giant", 0.35, 0.7 }, { "Giant", 0.6, 0.9 }, { "Boss", 1 } } },
	-- 3e territoire
	{ gold = 165, seconds = 135, health = 236, gap = { 0.9, 0.3 }, from = { Fast = 0.05, Swarm = 0.1, Tank = 0.15 }, specials = { { "Giant", 0.6, 0.8 } } },
	{ gold = 170, seconds = 135, health = 194, gap = { 0.9, 0.3 }, from = { Fast = 0.05, Swarm = 0.1, Tank = 0.15 }, specials = { { "Giant", 0.4, 0.7 }, { "Giant", 0.8 } } },
	{ gold = 175, seconds = 140, health = 207, gap = { 0.9, 0.3 }, from = { Fast = 0.05, Swarm = 0.1, Tank = 0.15 }, specials = { { "Giant", 0.35, 0.7 }, { "Giant", 0.7, 0.9 } } },
	{ gold = 180, seconds = 140, health = 207, gap = { 0.9, 0.3 }, from = { Fast = 0.05, Swarm = 0.1, Tank = 0.15 }, specials = { { "Giant", 0.3, 0.7 }, { "Giant", 0.55, 0.85 }, { "Giant", 0.85 } } },
	{ gold = 185, seconds = 145, health = 232, gap = { 0.9, 0.3 }, from = { Fast = 0.05, Swarm = 0.1, Tank = 0.15 }, specials = { { "Colossus", 0.72, 0.5 } } },
	{ gold = 190, seconds = 145, health = 219, gap = { 0.9, 0.3 }, from = { Fast = 0.05, Swarm = 0.1, Tank = 0.15 }, specials = { { "Giant", 0.3, 0.7 }, { "Giant", 0.55, 0.85 }, { "Giant", 0.8 } } },
	{ gold = 195, seconds = 145, health = 207, gap = { 0.9, 0.3 }, from = { Fast = 0.05, Swarm = 0.1, Tank = 0.15 }, specials = { { "Giant", 0.25, 0.7 }, { "Giant", 0.5, 0.85 }, { "Giant", 0.7 }, { "Giant", 0.9, 1.1 } } },
	{ gold = 200, seconds = 150, health = 219, gap = { 0.9, 0.3 }, from = { Fast = 0.05, Swarm = 0.1, Tank = 0.15 }, specials = { { "Giant", 0.25, 0.7 }, { "Giant", 0.45, 0.85 }, { "Giant", 0.65 }, { "Giant", 0.85, 1.1 } } },
	{ gold = 205, seconds = 150, health = 219, gap = { 0.9, 0.3 }, from = { Fast = 0.05, Swarm = 0.1, Tank = 0.15 }, specials = { { "Giant", 0.25, 0.75 }, { "Giant", 0.45, 0.9 }, { "Giant", 0.65 }, { "Giant", 0.85, 1.2 } } },
	{ gold = 210, seconds = 140, health = 207, gap = { 0.9, 0.3 }, from = { Fast = 0.05, Swarm = 0.1, Tank = 0.15 }, specials = { { "Giant", 0.3, 0.7 }, { "Giant", 0.55, 0.9 }, { "Giant", 0.8 }, { "Boss", 1, 1.1 } } },
	-- 4e territoire
	{ gold = 215, seconds = 140, health = 349, gap = { 0.95, 0.28 }, from = { Fast = 0.05, Swarm = 0.08, Tank = 0.12 }, specials = { { "Giant", 0.4, 0.7 }, { "Giant", 0.75, 0.9 } } },
	{ gold = 220, seconds = 140, health = 321, gap = { 0.95, 0.28 }, from = { Fast = 0.05, Swarm = 0.08, Tank = 0.12 }, specials = { { "Giant", 0.3, 0.7 }, { "Giant", 0.55, 0.85 }, { "Giant", 0.85 } } },
	{ gold = 225, seconds = 145, health = 321, gap = { 0.95, 0.28 }, from = { Fast = 0.05, Swarm = 0.08, Tank = 0.12 }, specials = { { "Giant", 0.3, 0.7 }, { "Giant", 0.5, 0.85 }, { "Giant", 0.8, 1.1 } } },
	{ gold = 230, seconds = 145, health = 331, gap = { 0.95, 0.28 }, from = { Fast = 0.05, Swarm = 0.08, Tank = 0.12 }, specials = { { "Giant", 0.25, 0.7 }, { "Giant", 0.45, 0.85 }, { "Giant", 0.65 }, { "Giant", 0.85, 1.1 } } },
	{ gold = 235, seconds = 150, health = 350, gap = { 0.95, 0.28 }, from = { Fast = 0.05, Swarm = 0.08, Tank = 0.12 }, specials = { { "Colossus", 0.46, 0.64 }, { "Colossus", 0.81, 0.8 } } },
	{ gold = 240, seconds = 150, health = 330, gap = { 0.95, 0.28 }, from = { Fast = 0.05, Swarm = 0.08, Tank = 0.12 }, specials = { { "Giant", 0.25, 0.7 }, { "Giant", 0.45, 0.85 }, { "Giant", 0.65 }, { "Giant", 0.85, 1.1 } } },
	{ gold = 245, seconds = 150, health = 360, gap = { 0.95, 0.28 }, from = { Fast = 0.05, Swarm = 0.08, Tank = 0.12 }, specials = { { "Giant", 0.25, 0.75 }, { "Giant", 0.45, 0.9 }, { "Giant", 0.65 }, { "Giant", 0.85, 1.2 } } },
	{ gold = 250, seconds = 155, health = 349, gap = { 0.95, 0.28 }, from = { Fast = 0.05, Swarm = 0.08, Tank = 0.12 }, specials = { { "Giant", 0.2, 0.7 }, { "Giant", 0.4, 0.85 }, { "Giant", 0.6 }, { "Giant", 0.8, 1.1 } } },
	{ gold = 255, seconds = 155, health = 371, gap = { 0.95, 0.28 }, from = { Fast = 0.05, Swarm = 0.08, Tank = 0.12 }, specials = { { "Giant", 0.2, 0.7 }, { "Giant", 0.4, 0.85 }, { "Giant", 0.6 }, { "Giant", 0.8, 1.1 } } },
	{ gold = 260, seconds = 145, health = 378, gap = { 0.95, 0.28 }, from = { Fast = 0.05, Swarm = 0.08, Tank = 0.12 }, specials = { { "Giant", 0.3, 0.7 }, { "Giant", 0.5, 0.85 }, { "Giant", 0.7 }, { "Giant", 0.85, 1.1 }, { "Boss", 1, 0.85 } } },
	-- 5e territoire
	{ gold = 265, seconds = 140, health = 391, gap = { 1.0, 0.28 }, from = { Fast = 0.1, Swarm = 0.12, Tank = 0.15 }, specials = { { "Giant", 0.3, 0.7 }, { "Giant", 0.6, 0.85 }, { "Giant", 0.85 } } },
	{ gold = 270, seconds = 140, health = 350, gap = { 1.0, 0.28 }, from = { Fast = 0.1, Swarm = 0.12, Tank = 0.15 }, specials = { { "Giant", 0.25, 0.7 }, { "Giant", 0.45, 0.85 }, { "Giant", 0.65 }, { "Giant", 0.85, 1.1 } } },
	{ gold = 275, seconds = 145, health = 350, gap = { 1.0, 0.28 }, from = { Fast = 0.1, Swarm = 0.12, Tank = 0.15 }, specials = { { "Giant", 0.25, 0.7 }, { "Giant", 0.45, 0.85 }, { "Giant", 0.65 }, { "Giant", 0.85, 1.1 } } },
	{ gold = 280, seconds = 145, health = 371, gap = { 1.0, 0.28 }, from = { Fast = 0.1, Swarm = 0.12, Tank = 0.15 }, specials = { { "Giant", 0.2, 0.7 }, { "Giant", 0.4, 0.85 }, { "Giant", 0.6 }, { "Giant", 0.8, 1.2 } } },
	{ gold = 285, seconds = 150, health = 302, gap = { 1.0, 0.28 }, from = { Fast = 0.1, Swarm = 0.12, Tank = 0.15 }, specials = { { "Giant", 0.6 }, { "Giant", 0.62 }, { "Giant", 0.64 }, { "Giant", 0.66 } } },
	{ gold = 290, seconds = 150, health = 391, gap = { 1.0, 0.28 }, from = { Fast = 0.1, Swarm = 0.12, Tank = 0.15 }, specials = { { "Giant", 0.2, 0.7 }, { "Giant", 0.4, 0.85 }, { "Giant", 0.6 }, { "Giant", 0.8, 1.2 } } },
	{ gold = 295, seconds = 150, health = 371, gap = { 1.0, 0.28 }, from = { Fast = 0.1, Swarm = 0.12, Tank = 0.15 }, specials = { { "Giant", 0.2, 0.7 }, { "Giant", 0.35, 0.85 }, { "Giant", 0.5 }, { "Giant", 0.7, 1.1 }, { "Giant", 0.88, 1.2 } } },
	{ gold = 300, seconds = 155, health = 371, gap = { 1.0, 0.28 }, from = { Fast = 0.1, Swarm = 0.12, Tank = 0.15 }, specials = { { "Giant", 0.2, 0.7 }, { "Giant", 0.35, 0.85 }, { "Giant", 0.5 }, { "Giant", 0.7, 1.1 }, { "Giant", 0.88, 1.2 } } },
	{ gold = 305, seconds = 155, health = 350, gap = { 1.0, 0.28 }, from = { Fast = 0.1, Swarm = 0.12, Tank = 0.15 }, specials = { { "Giant", 0.15, 0.7 }, { "Giant", 0.3, 0.85 }, { "Giant", 0.5 }, { "Giant", 0.7, 1.1 }, { "Giant", 0.88, 1.2 } } },
	{ gold = 310, seconds = 145, health = 371, gap = { 1.0, 0.28 }, from = { Fast = 0.1, Swarm = 0.12, Tank = 0.15 }, specials = { { "Giant", 0.3, 0.7 }, { "Giant", 0.5, 0.85 }, { "Giant", 0.7 }, { "Giant", 0.85, 1.1 }, { "Boss", 1 } } },
	-- 6e territoire
	{ gold = 315, seconds = 140, health = 302, gap = { 1.0, 0.27 }, from = { Fast = 0.1, Swarm = 0.1, Tank = 0.12 }, specials = { { "Giant", 0.25, 0.7 }, { "Giant", 0.45, 0.85 }, { "Giant", 0.65 }, { "Giant", 0.85, 1.1 } } },
	{ gold = 320, seconds = 145, health = 302, gap = { 1.0, 0.27 }, from = { Fast = 0.1, Swarm = 0.1, Tank = 0.12 }, specials = { { "Giant", 0.2, 0.7 }, { "Giant", 0.4, 0.85 }, { "Giant", 0.6 }, { "Giant", 0.8, 1.2 } } },
	{ gold = 325, seconds = 145, health = 285, gap = { 1.0, 0.27 }, from = { Fast = 0.1, Swarm = 0.1, Tank = 0.12 }, specials = { { "Giant", 0.2, 0.7 }, { "Giant", 0.35, 0.85 }, { "Giant", 0.5 }, { "Giant", 0.7, 1.1 }, { "Giant", 0.88, 1.2 } } },
	{ gold = 330, seconds = 150, health = 285, gap = { 1.0, 0.27 }, from = { Fast = 0.1, Swarm = 0.1, Tank = 0.12 }, specials = { { "Giant", 0.2, 0.7 }, { "Giant", 0.35, 0.85 }, { "Giant", 0.5 }, { "Giant", 0.7, 1.1 }, { "Giant", 0.88, 1.2 } } },
	{ gold = 335, seconds = 150, health = 232, gap = { 1.0, 0.27 }, from = { Fast = 0.1, Swarm = 0.1, Tank = 0.12 }, specials = { { "Giant", 0.4 }, { "Giant", 0.42 }, { "Giant", 0.44 }, { "Giant", 0.8 }, { "Giant", 0.82 } } },
	{ gold = 340, seconds = 150, health = 285, gap = { 1.0, 0.27 }, from = { Fast = 0.1, Swarm = 0.1, Tank = 0.12 }, specials = { { "Giant", 0.15, 0.7 }, { "Giant", 0.3, 0.85 }, { "Giant", 0.5 }, { "Giant", 0.7, 1.1 }, { "Giant", 0.88, 1.2 } } },
	{ gold = 345, seconds = 155, health = 302, gap = { 1.0, 0.27 }, from = { Fast = 0.1, Swarm = 0.1, Tank = 0.12 }, specials = { { "Giant", 0.15, 0.7 }, { "Giant", 0.3, 0.85 }, { "Giant", 0.5 }, { "Giant", 0.7, 1.1 }, { "Giant", 0.88, 1.2 } } },
	{ gold = 350, seconds = 155, health = 285, gap = { 1.0, 0.27 }, from = { Fast = 0.1, Swarm = 0.1, Tank = 0.12 }, specials = { { "Giant", 0.15, 0.75 }, { "Giant", 0.3, 0.9 }, { "Giant", 0.5, 1.1 }, { "Giant", 0.7, 1.1 }, { "Giant", 0.88, 1.2 } } },
	{ gold = 355, seconds = 155, health = 285, gap = { 1.0, 0.27 }, from = { Fast = 0.1, Swarm = 0.1, Tank = 0.12 }, specials = { { "Giant", 0.15, 0.75 }, { "Giant", 0.3, 0.9 }, { "Giant", 0.5, 1.1 }, { "Giant", 0.7, 1.2 }, { "Giant", 0.88, 1.2 } } },
	{ gold = 360, seconds = 145, health = 302, gap = { 1.0, 0.27 }, from = { Fast = 0.1, Swarm = 0.1, Tank = 0.12 }, specials = { { "Giant", 0.3, 0.7 }, { "Giant", 0.45, 0.85 }, { "Giant", 0.6 }, { "Giant", 0.75, 1.1 }, { "Giant", 0.88, 1.2 }, { "Boss", 1, 1.2 } } },
	-- 7e territoire
	{ gold = 365, seconds = 140, health = 285, gap = { 1.0, 0.27 }, from = { Fast = 0.1, Swarm = 0.1, Tank = 0.12 }, specials = { { "Giant", 0.2, 0.7 }, { "Giant", 0.35, 0.85 }, { "Giant", 0.5 }, { "Giant", 0.7, 1.1 }, { "Giant", 0.88, 1.2 } } },
	{ gold = 370, seconds = 145, health = 302, gap = { 1.0, 0.27 }, from = { Fast = 0.1, Swarm = 0.1, Tank = 0.12 }, specials = { { "Giant", 0.2, 0.7 }, { "Giant", 0.35, 0.85 }, { "Giant", 0.5 }, { "Giant", 0.7, 1.1 }, { "Giant", 0.88, 1.2 } } },
	{ gold = 375, seconds = 145, health = 302, gap = { 1.0, 0.27 }, from = { Fast = 0.1, Swarm = 0.1, Tank = 0.12 }, specials = { { "Giant", 0.15, 0.7 }, { "Giant", 0.3, 0.85 }, { "Giant", 0.5 }, { "Giant", 0.7, 1.1 }, { "Giant", 0.88, 1.2 } } },
	{ gold = 380, seconds = 150, health = 302, gap = { 1.0, 0.27 }, from = { Fast = 0.1, Swarm = 0.1, Tank = 0.12 }, specials = { { "Giant", 0.15, 0.7 }, { "Giant", 0.3, 0.85 }, { "Giant", 0.5 }, { "Giant", 0.7, 1.1 }, { "Giant", 0.88, 1.2 } } },
	{ gold = 385, seconds = 150, health = 285, gap = { 1.0, 0.27 }, from = { Fast = 0.1, Swarm = 0.1, Tank = 0.12 }, specials = { { "Giant", 0.55 }, { "Giant", 0.6 }, { "Giant", 0.65 }, { "Giant", 0.7 }, { "Giant", 0.75 } } },
	{ gold = 390, seconds = 150, health = 285, gap = { 1.0, 0.27 }, from = { Fast = 0.1, Swarm = 0.1, Tank = 0.12 }, specials = { { "Giant", 0.15, 0.75 }, { "Giant", 0.3, 0.9 }, { "Giant", 0.5, 1.1 }, { "Giant", 0.7, 1.1 }, { "Giant", 0.88, 1.2 } } },
	{ gold = 395, seconds = 155, health = 302, gap = { 1.0, 0.27 }, from = { Fast = 0.1, Swarm = 0.1, Tank = 0.12 }, specials = { { "Giant", 0.15, 0.75 }, { "Giant", 0.3, 0.9 }, { "Giant", 0.5, 1.1 }, { "Giant", 0.7, 1.1 }, { "Giant", 0.88, 1.2 } } },
	{ gold = 400, seconds = 155, health = 302, gap = { 1.0, 0.27 }, from = { Fast = 0.1, Swarm = 0.1, Tank = 0.12 }, specials = { { "Giant", 0.15, 0.75 }, { "Giant", 0.3, 0.9 }, { "Giant", 0.5, 1.1 }, { "Giant", 0.7, 1.2 }, { "Giant", 0.88, 1.2 } } },
	{ gold = 405, seconds = 155, health = 393, gap = { 1.0, 0.27 }, from = { Fast = 0.1, Swarm = 0.1, Tank = 0.12 }, specials = { { "Giant", 0.15, 0.75 }, { "Giant", 0.3, 0.9 }, { "Giant", 0.5, 1.1 }, { "Giant", 0.7, 1.2 }, { "Giant", 0.88, 1.2 } } },
	{ gold = 410, seconds = 145, health = 371, gap = { 1.0, 0.27 }, from = { Fast = 0.1, Swarm = 0.1, Tank = 0.12 }, specials = { { "Giant", 0.3, 0.7 }, { "Giant", 0.45, 0.85 }, { "Giant", 0.6 }, { "Giant", 0.75, 1.1 }, { "Giant", 0.88, 1.2 }, { "Boss", 1 } } },
	-- 8e territoire
	{ gold = 415, seconds = 140, health = 371, gap = { 1.0, 0.27 }, from = { Fast = 0.1, Swarm = 0.1, Tank = 0.12 }, specials = { { "Giant", 0.2, 0.7 }, { "Giant", 0.35, 0.85 }, { "Giant", 0.5 }, { "Giant", 0.7, 1.1 }, { "Giant", 0.88, 1.2 } } },
	{ gold = 420, seconds = 145, health = 371, gap = { 1.0, 0.27 }, from = { Fast = 0.1, Swarm = 0.1, Tank = 0.12 }, specials = { { "Giant", 0.2, 0.7 }, { "Giant", 0.35, 0.85 }, { "Giant", 0.5 }, { "Giant", 0.7, 1.1 }, { "Giant", 0.88, 1.2 } } },
	{ gold = 425, seconds = 145, health = 393, gap = { 1.0, 0.27 }, from = { Fast = 0.1, Swarm = 0.1, Tank = 0.12 }, specials = { { "Giant", 0.15, 0.7 }, { "Giant", 0.3, 0.85 }, { "Giant", 0.5 }, { "Giant", 0.7, 1.1 }, { "Giant", 0.88, 1.2 } } },
	{ gold = 430, seconds = 150, health = 393, gap = { 1.0, 0.27 }, from = { Fast = 0.1, Swarm = 0.1, Tank = 0.12 }, specials = { { "Giant", 0.15, 0.7 }, { "Giant", 0.3, 0.85 }, { "Giant", 0.5 }, { "Giant", 0.7, 1.1 }, { "Giant", 0.88, 1.2 } } },
	{ gold = 435, seconds = 150, health = 321, gap = { 1.0, 0.27 }, from = { Fast = 0.1, Swarm = 0.1, Tank = 0.12 }, specials = { { "Giant", 0.3, 0.7 }, { "Giant", 0.5, 1.3 }, { "Giant", 0.6 }, { "Giant", 0.7 }, { "Giant", 0.85, 1.1 } } },
	{ gold = 440, seconds = 150, health = 371, gap = { 1.0, 0.27 }, from = { Fast = 0.1, Swarm = 0.1, Tank = 0.12 }, specials = { { "Giant", 0.15, 0.75 }, { "Giant", 0.3, 0.9 }, { "Giant", 0.5, 1.1 }, { "Giant", 0.7, 1.1 }, { "Giant", 0.88, 1.2 } } },
	{ gold = 445, seconds = 150, health = 393, gap = { 1.0, 0.27 }, from = { Fast = 0.1, Swarm = 0.1, Tank = 0.12 }, specials = { { "Giant", 0.15, 0.75 }, { "Giant", 0.3, 0.9 }, { "Giant", 0.5, 1.1 }, { "Giant", 0.7, 1.1 }, { "Giant", 0.88, 1.2 } } },
	{ gold = 450, seconds = 150, health = 393, gap = { 1.0, 0.27 }, from = { Fast = 0.1, Swarm = 0.1, Tank = 0.12 }, specials = { { "Giant", 0.15, 0.75 }, { "Giant", 0.3, 0.9 }, { "Giant", 0.5, 1.1 }, { "Giant", 0.7, 1.2 }, { "Giant", 0.88, 1.2 } } },
	{ gold = 455, seconds = 150, health = 393, gap = { 1.0, 0.27 }, from = { Fast = 0.1, Swarm = 0.1, Tank = 0.12 }, specials = { { "Giant", 0.15, 0.75 }, { "Giant", 0.3, 0.9 }, { "Giant", 0.5, 1.1 }, { "Giant", 0.7, 1.2 }, { "Giant", 0.88, 1.2 } } },
	{ gold = 460, seconds = 145, health = 349, gap = { 1.0, 0.27 }, from = { Fast = 0.1, Swarm = 0.1, Tank = 0.12 }, specials = { { "Giant", 0.3, 0.7 }, { "Giant", 0.45, 0.85 }, { "Giant", 0.6 }, { "Giant", 0.75, 1.1 }, { "Giant", 0.88, 1.2 }, { "Boss", 1, 1.1 } } },
	-- 9e territoire
	{ gold = 465, seconds = 140, health = 393, gap = { 1.0, 0.27 }, from = { Fast = 0.1, Swarm = 0.1, Tank = 0.12 }, specials = { { "Giant", 0.2, 0.7 }, { "Giant", 0.35, 0.85 }, { "Giant", 0.5 }, { "Giant", 0.7, 1.1 }, { "Giant", 0.88, 1.2 } } },
	{ gold = 470, seconds = 145, health = 417, gap = { 1.0, 0.27 }, from = { Fast = 0.1, Swarm = 0.1, Tank = 0.12 }, specials = { { "Giant", 0.2, 0.7 }, { "Giant", 0.35, 0.85 }, { "Giant", 0.5 }, { "Giant", 0.7, 1.1 }, { "Giant", 0.88, 1.2 } } },
	{ gold = 475, seconds = 145, health = 393, gap = { 1.0, 0.27 }, from = { Fast = 0.1, Swarm = 0.1, Tank = 0.12 }, specials = { { "Giant", 0.15, 0.7 }, { "Giant", 0.3, 0.85 }, { "Giant", 0.5 }, { "Giant", 0.7, 1.1 }, { "Giant", 0.88, 1.2 } } },
	{ gold = 480, seconds = 150, health = 404, gap = { 1.0, 0.27 }, from = { Fast = 0.1, Swarm = 0.1, Tank = 0.12 }, specials = { { "Giant", 0.15, 0.7 }, { "Giant", 0.3, 0.85 }, { "Giant", 0.5 }, { "Giant", 0.7, 1.1 }, { "Giant", 0.88, 1.2 } } },
	{ gold = 485, seconds = 150, health = 371, gap = { 1.0, 0.27 }, from = { Fast = 0.1, Swarm = 0.1, Tank = 0.12 }, specials = { { "Giant", 0.4 }, { "Giant", 0.42 }, { "Giant", 0.7, 2.0 }, { "Giant", 0.85 }, { "Giant", 0.87 } } },
	{ gold = 490, seconds = 150, health = 393, gap = { 1.0, 0.27 }, from = { Fast = 0.1, Swarm = 0.1, Tank = 0.12 }, specials = { { "Giant", 0.15, 0.75 }, { "Giant", 0.3, 0.9 }, { "Giant", 0.5, 1.1 }, { "Giant", 0.7, 1.1 }, { "Giant", 0.88, 1.2 } } },
	{ gold = 495, seconds = 150, health = 393, gap = { 1.0, 0.27 }, from = { Fast = 0.1, Swarm = 0.1, Tank = 0.12 }, specials = { { "Giant", 0.15, 0.75 }, { "Giant", 0.3, 0.9 }, { "Giant", 0.5, 1.1 }, { "Giant", 0.7, 1.1 }, { "Giant", 0.88, 1.2 } } },
	{ gold = 500, seconds = 150, health = 393, gap = { 1.0, 0.27 }, from = { Fast = 0.1, Swarm = 0.1, Tank = 0.12 }, specials = { { "Giant", 0.15, 0.75 }, { "Giant", 0.3, 0.9 }, { "Giant", 0.5, 1.1 }, { "Giant", 0.7, 1.2 }, { "Giant", 0.88, 1.2 } } },
	{ gold = 505, seconds = 150, health = 393, gap = { 1.0, 0.27 }, from = { Fast = 0.1, Swarm = 0.1, Tank = 0.12 }, specials = { { "Giant", 0.15, 0.75 }, { "Giant", 0.3, 0.9 }, { "Giant", 0.5, 1.1 }, { "Giant", 0.7, 1.2 }, { "Giant", 0.88, 1.2 } } },
	{ gold = 510, seconds = 145, health = 417, gap = { 1.0, 0.27 }, from = { Fast = 0.1, Swarm = 0.1, Tank = 0.12 }, specials = { { "Giant", 0.3, 0.7 }, { "Giant", 0.45, 0.85 }, { "Giant", 0.6 }, { "Giant", 0.75, 1.1 }, { "Giant", 0.88, 1.2 }, { "Boss", 1 } } },
	-- 10e territoire
	{ gold = 515, seconds = 140, health = 393, gap = { 1.0, 0.27 }, from = { Fast = 0.1, Swarm = 0.1, Tank = 0.12 }, specials = { { "Giant", 0.2, 0.7 }, { "Giant", 0.35, 0.85 }, { "Giant", 0.5 }, { "Giant", 0.7, 1.1 }, { "Giant", 0.88, 1.2 } } },
	{ gold = 520, seconds = 140, health = 417, gap = { 1.0, 0.27 }, from = { Fast = 0.1, Swarm = 0.1, Tank = 0.12 }, specials = { { "Giant", 0.2, 0.7 }, { "Giant", 0.35, 0.85 }, { "Giant", 0.5 }, { "Giant", 0.7, 1.1 }, { "Giant", 0.88, 1.2 } } },
	{ gold = 525, seconds = 145, health = 417, gap = { 1.0, 0.27 }, from = { Fast = 0.1, Swarm = 0.1, Tank = 0.12 }, specials = { { "Giant", 0.15, 0.7 }, { "Giant", 0.3, 0.85 }, { "Giant", 0.5 }, { "Giant", 0.7, 1.1 }, { "Giant", 0.88, 1.2 } } },
	{ gold = 530, seconds = 145, health = 417, gap = { 1.0, 0.27 }, from = { Fast = 0.1, Swarm = 0.1, Tank = 0.12 }, specials = { { "Giant", 0.15, 0.7 }, { "Giant", 0.3, 0.85 }, { "Giant", 0.5 }, { "Giant", 0.7, 1.1 }, { "Giant", 0.88, 1.2 } } },
	{ gold = 535, seconds = 150, health = 393, gap = { 1.0, 0.27 }, from = { Fast = 0.1, Swarm = 0.1, Tank = 0.12 }, specials = { { "Giant", 0.3, 0.8 }, { "Giant", 0.5 }, { "Giant", 0.52 }, { "Giant", 0.7, 1.5 }, { "Giant", 0.88, 1.2 } } },
	{ gold = 540, seconds = 150, health = 417, gap = { 1.0, 0.27 }, from = { Fast = 0.1, Swarm = 0.1, Tank = 0.12 }, specials = { { "Giant", 0.15, 0.75 }, { "Giant", 0.3, 0.9 }, { "Giant", 0.5, 1.1 }, { "Giant", 0.7, 1.1 }, { "Giant", 0.88, 1.2 } } },
	{ gold = 545, seconds = 150, health = 417, gap = { 1.0, 0.27 }, from = { Fast = 0.1, Swarm = 0.1, Tank = 0.12 }, specials = { { "Giant", 0.15, 0.75 }, { "Giant", 0.3, 0.9 }, { "Giant", 0.5, 1.1 }, { "Giant", 0.7, 1.1 }, { "Giant", 0.88, 1.2 } } },
	{ gold = 550, seconds = 150, health = 393, gap = { 1.0, 0.27 }, from = { Fast = 0.1, Swarm = 0.1, Tank = 0.12 }, specials = { { "Giant", 0.15, 0.75 }, { "Giant", 0.3, 0.9 }, { "Giant", 0.5, 1.1 }, { "Giant", 0.7, 1.2 }, { "Giant", 0.88, 1.2 } } },
	{ gold = 555, seconds = 150, health = 417, gap = { 1.0, 0.27 }, from = { Fast = 0.1, Swarm = 0.1, Tank = 0.12 }, specials = { { "Giant", 0.15, 0.75 }, { "Giant", 0.3, 0.9 }, { "Giant", 0.5, 1.1 }, { "Giant", 0.7, 1.2 }, { "Giant", 0.88, 1.2 } } },
	{ gold = 560, seconds = 135, health = 349, gap = { 1.0, 0.27 }, from = { Fast = 0.1, Swarm = 0.1, Tank = 0.12 }, specials = { { "Giant", 0.3, 0.7 }, { "Giant", 0.45, 0.85 }, { "Giant", 0.6 }, { "Giant", 0.75, 1.1 }, { "Giant", 0.88, 1.2 }, { "Boss", 1, 1.5 } } },
}

-- Niveau 1 : cette tour est déjà posée à l'arrivée du joueur (premier emplacement conseillé de la carte), pour
-- qu'il voie tout de suite le jeu marcher (priorité du propriétaire : « les 10 premières secondes »).
Levels.STARTING_TOWER = "MachineGun"

-- Pièces de niveau gagnées : première victoire, puis en rejouant (REPLAY_SHARE). Mini-boss et boss : bien plus, et
-- de plus en plus à chaque territoire (300 et 600 au premier, 600 et 1 200 au deuxième, 900 et 1 800 au troisième,
-- 1 200 et 2 400 au quatrième, 1 500 et 3 000 au cinquième, 1 800 et 3 600 au sixième... 3 000 et 6 000 au dixième).
-- Défaite : une petite part de la récompense « en rejouant », selon la part des monstres éliminés.
Levels.REPLAY_SHARE = 0.4
Levels.DEFEAT_SHARE = 0.5
function Levels.firstReward(level: number): number
	local territory = Levels.territoryOf(level)
	if level % 10 == 0 then
		return 600 * territory
	elseif level % 5 == 0 then
		return 300 * territory
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

----------------------------------------------------------------------
-- JOUER EN ÉQUIPE. Demande du propriétaire (03/10/2026) : « jouer en équipe » ; « et même un bonus 10 % pièces, et
-- on pourrait faire trio et quad aussi avec 30 et 40 % ». Jusqu'à TEAM_MAX joueurs défendent le même château,
-- dans la même partie (serveur : Hub/LevelTeams.luau pour qui est avec qui, LevelGame.luau pour la partie) :
--   * chacun a SON or : l'or de départ du niveau, et TOUT l'or de chaque monstre tué, quel que soit le tireur ;
--   * chacun pose SES tours (ses limites par type, son entraînement, ses évolutions), et n'améliore ou ne vend
--     que les siennes ;
--   * les vies du château et le flot de monstres sont communs ; les monstres ont TEAM_HEALTH fois plus de PV
--     (réglé avec des équipes de joueurs simulés : tools/levels, run.ps1 -Equipe) ;
--   * chacun a SON COULOIR (demande du propriétaire, 03/10/2026 : « chacun a son couloir qui se rejoint ensuite ») :
--     la partie se joue sur la carte d'équipe du territoire à ce nombre de joueurs (Shared/TeamMaps.luau,
--     Levels.mapFor), le joueur n défend le couloir n, son nom est écrit à l'entrée (Hub/LevelArena.luau) ; le flot
--     est partagé entre les couloirs (Levels.buildQueue), qui se rejoignent avant le château ; chaque GROS monstre
--     (colosse, colosse géant, boss) sort dans un couloir TIRÉ AU SORT à chaque partie (idée du propriétaire,
--     04/10/2026 : « un gros colosse plus fort qui apparaît à un couloir aléatoire », « pareil pour les boss ») ;
--   * à la fin, chacun reçoit SES pièces de niveau (première victoire ou non : selon SES niveaux réussis), avec le
--     bonus d'équipe TEAM_COIN_BONUS, et l'XP de SES tours posées ; une victoire ouvre le niveau suivant à chacun ;
--   * c'est le CHEF qui lance les niveaux, et le niveau doit être ouvert pour tous ; il faut avoir fini le
--     niveau 1 (le tuto) pour jouer en équipe ;
--   * celui qui s'en va (bouton Quitter, ou départ du jeu) abandonne pour lui seul : ses tours restent et
--     continuent de tirer, les autres continuent.
-- Les listes sont rangées par nombre de joueurs : [1] = seul, [2] = à deux, [3] = à trois, [4] = à quatre.
-- TEAM_HEALTH, mesuré le 04/10/2026 sur les cartes d'équipe (14 à 16 niveaux, du 3 au 100) avec run.ps1 -Equipe :
-- PV x le plus haut où une équipe de joueurs de référence gagne encore avec 5 vies = 1,9 à 2,4 à deux (médiane 2,15 :
-- chacun reçoit TOUT l'or, deux joueurs font donc un peu plus que deux fois un seul), 2,3 à 3,4 à trois (2,75), 2,7
-- à 4 à quatre (3,45). Les chiffres gardés sont un peu en dessous de la médiane (x0,86) : une équipe de joueurs
-- normaux gagne presque partout, une équipe qui attend perd encore presque toujours. Deux territoires sont plus
-- durs en équipe sur plusieurs niveaux mesurés (le col à deux : 1,6 à 1,9 ; le désert : 1,9 à deux, 2,45 à trois,
-- 2,7 à quatre) : leurs cartes d'équipe ont des monstres un peu moins résistants (TEAM_MAP_HEALTH).
----------------------------------------------------------------------
Levels.TEAM_MAX = 4
Levels.TEAM_HEALTH = { 1, 1.85, 2.35, 2.95 }
Levels.TEAM_MAP_HEALTH = { Pass_2 = 0.82, Desert_2 = 0.92, Desert_3 = 0.92, Desert_4 = 0.8 } -- PV x ce chiffre en plus
Levels.TEAM_COIN_BONUS = { 0, 0.1, 0.3, 0.4 } -- (chiffres du propriétaire)
Levels.TEAM_INVITE_SECONDS = 30 -- une invitation sans réponse disparaît au bout de ce temps

local function teamIndex(size: any): number
	return math.clamp(math.floor(tonumber(size) or 1), 1, Levels.TEAM_MAX)
end

-- Multiplicateur des PV des monstres pour une équipe de `size` joueurs (1 = seul).
function Levels.teamHealth(size: number?): number
	return Levels.TEAM_HEALTH[teamIndex(size)] or 1
end

-- Le BOSS et le COLOSSE GÉANT sont chacun un seul monstre énorme qui ne passe que dans UN couloir d'une carte
-- d'équipe : seules les tours de ce couloir et celles de la partie commune le touchent. Leurs PV d'équipe sont donc
-- moins multipliés : 1 + (teamHealth - 1) x TEAM_BOSS_SHARE. Mesuré avec run.ps1 -Equipe : avec les mêmes PV que le
-- flot, le niveau 10 (son boss) était bien plus dur en équipe que les autres, et le niveau 25 (alors trois colosses
-- ensemble) aussi. Les colosses, eux, viennent à plusieurs et se répartissent entre les couloirs : leurs PV suivent
-- ceux du flot (les alléger aussi rendait les derniers territoires trop faciles).
Levels.TEAM_BOSS_SHARE = 0.5
function Levels.teamBossHealth(size: number?): number
	return 1 + (Levels.teamHealth(size) - 1) * Levels.TEAM_BOSS_SHARE
end

-- Bonus de pièces de niveau d'une équipe de `size` joueurs (0,1 = +10 %).
function Levels.teamBonus(size: number?): number
	return Levels.TEAM_COIN_BONUS[teamIndex(size)] or 0
end

-- Pièces de niveau d'un joueur d'une équipe de `size` joueurs : la récompense normale, plus le bonus d'équipe (sans
-- ami sur le serveur : voir Levels.bonusReward, « LES AMIS »).
function Levels.teamReward(reward: number, size: number?): number
	return math.floor(reward * (1 + Levels.teamBonus(size)) + 0.5)
end

-- Le n° d'un joueur dans les noms d'attributs de sa zone de combat (« Gold_<n°> », « Training_<n°> »,
-- « Result_<n°> ») : son UserId, ou « m » et son opposé pour un n° négatif (joueurs d'essai de Studio) : un nom
-- d'attribut n'accepte que des lettres, des chiffres et « _ ».
function Levels.memberKey(userId: any): string
	local id = math.floor(tonumber(userId) or 0)
	return if id < 0 then "m" .. tostring(-id) else tostring(id)
end

----------------------------------------------------------------------
-- LES AMIS. Demande du propriétaire (04/10/2026), d'après un autre jeu : « quand quelqu'un a un ami qui se connecte,
-- ça envoie une notif pour l'inviter, pour un bonus de pièces » ; « oui 1 2 3 » aux trois propositions :
--   1) un ami Roblox qui se connecte (et qui n'est pas déjà dans le jeu) : un petit panneau « Robin est en ligne ! »
--      avec « Inviter » : l'invitation de Roblox, pour lui (client/LevelsUI.luau) ;
--   2) un ami qui arrive grâce à une invitation (Roblox le dit : GetJoinData().ReferredByPlayerId) : INVITE_REWARD
--      pièces de niveau pour lui ET pour celui qui l'a invité. Règle de Roblox : récompenser seulement un ami qui
--      vient vraiment, pas l'envoi d'une invitation. Une seule fois par ami (claimArrival, claimInvite), INVITE_MAX
--      amis au plus par joueur. Celui qui a invité est récompensé tout de suite s'il est sur le même serveur, sinon à
--      sa prochaine arrivée dans le jeu (Hub/LevelsService.luau) ;
--   3) tant qu'un ami Roblox est sur le même serveur : COIN_BONUS de pièces en plus à chaque fin de niveau (en plus
--      du bonus d'équipe : Levels.bonusReward).
----------------------------------------------------------------------
Levels.FRIENDS = {
	INVITE_REWARD = 200, -- pièces de niveau pour chacun des deux
	INVITE_MAX = 20, -- amis récompensés au plus, par joueur
	COIN_BONUS = 0.1, -- +10 % de pièces avec un ami sur le serveur
	ONLINE_CHECK_SECONDS = 60, -- le client regarde quels amis sont en ligne toutes les ... secondes
	NOTICE_SECONDS = 15, -- un panneau « ami en ligne » reste ... secondes
}

-- Pièces de niveau d'un joueur à la fin d'un niveau : la récompense normale, avec le bonus d'équipe (`size` joueurs)
-- et le bonus d'ami (un ami Roblox sur le même serveur).
function Levels.bonusReward(reward: number, size: number?, friendHere: boolean?): number
	local bonus = Levels.teamBonus(size) + (if friendHere then Levels.FRIENDS.COIN_BONUS else 0)
	return math.floor(reward * (1 + bonus) + 0.5)
end

-- Récompense d'arrivée d'un joueur (ses données des niveaux, son UserId) venu grâce à l'invitation de `inviterId` :
-- une seule fois par joueur, jamais pour lui-même. Renvoie vrai si elle est donnée.
function Levels.claimArrival(levels, selfId: number, inviterId: any): boolean
	local inviter = math.floor(tonumber(inviterId) or 0)
	if levels.invitedBy ~= 0 or inviter == 0 or inviter == selfId then
		return false
	end
	levels.invitedBy = inviter
	levels.coins += Levels.FRIENDS.INVITE_REWARD
	return true
end

-- Récompense de celui qui a invité (ses données, son UserId) pour l'ami `friendId` venu grâce à lui : une fois par ami,
-- INVITE_MAX amis au plus. Renvoie vrai si elle est donnée.
function Levels.claimInvite(levels, selfId: number, friendId: any): boolean
	local friend = math.floor(tonumber(friendId) or 0)
	if friend == 0 or friend == selfId or table.find(levels.invited, friend) or #levels.invited >= Levels.FRIENDS.INVITE_MAX then
		return false
	end
	table.insert(levels.invited, friend)
	levels.coins += Levels.FRIENDS.INVITE_REWARD
	return true
end

-- Fiche d'un niveau : { level, territory, map, palier (famille de monstres), gold, lives, boss, miniBoss, reward,
-- replay }.
function Levels.definition(level: number)
	local source = Levels.DEFINITIONS[level]
	assert(source, "Niveau inconnu : " .. tostring(level))
	local territory = Levels.territoryOf(level)
	return {
		level = level,
		territory = territory,
		map = Levels.TERRITORIES[territory],
		palier = territory - 1,
		gold = source.gold,
		lives = Levels.LIVES,
		boss = level % 10 == 0,
		miniBoss = level % 5 == 0 and level % 10 ~= 0,
		reward = Levels.firstReward(level),
		replay = math.floor(Levels.firstReward(level) * Levels.REPLAY_SHARE + 0.5),
	}
end

-- Carte d'un niveau joué à `teamSize` joueurs : en équipe, la carte d'équipe de son territoire (« Valley_2 »... :
-- un couloir par joueur) ; seul (ou sans carte d'équipe à ce nombre), celle du territoire.
function Levels.mapFor(level: number, teamSize: number?): string
	local map = Levels.definition(level).map
	local size = teamIndex(teamSize)
	local team = `{map}_{size}`
	return if size > 1 and Levels.MAPS[team] then team else map
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

-- File d'apparition d'un niveau : { { enemy, health, reward (or), at (secondes depuis le début), lane (couloir) } },
-- dans l'ordre des heures. Le flot continu décrit plus haut : toujours la même file pour le même niveau. teamSize =
-- nombre de joueurs de la partie (« JOUER EN ÉQUIPE » : PV x teamHealth, x TEAM_MAP_HEALTH de sa carte d'équipe ;
-- absent = seul). En équipe, chacun a son couloir (cartes d'équipe, Levels.mapFor) et le flot est partagé entre les
-- couloirs, chacun son tour, type par type : autant de monstres de chaque type dans chaque couloir. Le premier de
-- chaque type va dans le couloir n° du territoire (territoire 1 : couloir 1, territoire 2 : couloir 2...).
-- random = le Random de la partie (LevelGame) : en équipe, chaque GROS monstre (BIG_ENEMIES : colosse, colosse
-- géant, boss) sort alors dans un couloir tiré au sort : les couloirs sont rangés dans un ordre au hasard au début
-- de la partie, puis chaque gros monstre prend le suivant (personne n'en a deux tant qu'un coéquipier n'en a eu
-- aucun, et le boss ne suit pas de près un colosse dans le même couloir) ; sans lui (tests, aperçus), il suit le
-- partage ci-dessus.
local BIG_ENEMIES = { Giant = true, Colossus = true, Boss = true }
-- (seuls dans leur couloir : PV d'équipe allégés, voir teamBossHealth)
local LONE_ENEMIES = { Colossus = true, Boss = true }
function Levels.buildQueue(level: number, teamSize: number?, random: any?)
	local source = Levels.DEFINITIONS[level]
	assert(source, "Niveau inconnu : " .. tostring(level))
	local queue = {}
	local mapScale = if teamIndex(teamSize) > 1 then Levels.TEAM_MAP_HEALTH[Levels.mapFor(level, teamSize)] or 1 else 1
	local teamScale, bossScale = Levels.teamHealth(teamSize) * mapScale, Levels.teamBossHealth(teamSize) * mapScale
	local lanes = teamIndex(teamSize)
	local firstLane = (Levels.territoryOf(level) - 1) % lanes
	local turns = {} -- [type] = nombre de monstres de ce type déjà placés (+ firstLane)
	local bigLanes, bigNext = nil, 0 -- couloirs des gros monstres : un ordre tiré au sort, puis chacun son tour
	local function push(enemyType: string, at: number, factor: number)
		local health = Levels.enemyHealth(level, enemyType, factor)
		local scale = if LONE_ENEMIES[enemyType] then bossScale else teamScale
		if scale ~= 1 then
			health = math.floor(health * scale * 10 + 0.5) / 10
		end
		local turn = turns[enemyType] or firstLane
		turns[enemyType] = turn + 1
		local lane = turn % lanes + 1
		if random and lanes > 1 and BIG_ENEMIES[enemyType] then
			if not bigLanes then
				bigLanes = {}
				for index = 1, lanes do
					table.insert(bigLanes, random:NextInteger(1, index), index) -- (un ordre au hasard, chacun aussi probable)
				end
			end
			bigNext = bigNext % lanes + 1
			lane = bigLanes[bigNext]
		end
		table.insert(queue, { enemy = enemyType, health = health, reward = Levels.ENEMY[enemyType].gold, at = at, lane = lane })
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
-- Tours pendant un niveau : les 20 tours de IdleTowers (dégâts, portée, effets) ; leurs prix, en OR, sont ici.
--   poser : TOWER_COST ; améliorer du niveau n à n + 1 : prix de pose x UPGRADE_FACTOR x UPGRADE_GROWTH ^ (n - 1),
--   pour +35 % de dégâts (IdleConfig.UPGRADE_DAMAGE) ; revendre : SELL_REFUND de l'or dépensé.
-- Limite de tours identiques : selon leur rareté (IdleTowers.maxCopies : 5 communes, 4 rares, 3 épiques,
-- 2 légendaires), sauf MAX_COPIES ci-dessous. Avec le seul Archer, on en pose 5 au plus : il faut les améliorer,
-- puis avoir d'autres tours (les œufs). Le Totem de givre est limité à 3 : à 5, le joueur simulé en couvrait tout le chemin
-- et gagnait tout avec « 5 Archers + 5 Totems » (tools/levels).
-- Prix réglés pour que chaque tour vaille son or (joueur simulé, tools/levels) : une nouvelle tour rapporte à peu
-- près 2 fois plus de dégâts par pièce d'or qu'une amélioration ; les deux légendaires (Oracle, Trébuchet) sont les
-- meilleures affaires. Ce que chaque tour apporte se mesure avec run.ps1 -Worth (voir NIVEAUX.md).
-- Les tours de PALIER 2 (œufs) coûtent deux fois le prix de leur tour de base, pour 2,3 à 3,5 fois ses dégâts : la
-- tour de base devient presque inutile (demande du propriétaire, IdleTowers.luau). Le Totem du blizzard est limité
-- à 3, comme le Totem de givre. Les tours SPÉCIALES (une par territoire) : un peu plus fortes qu'une tour de palier 2
-- pour leur prix, 2 au plus par niveau (rareté « Special »).
----------------------------------------------------------------------
Levels.TOWER_COST = {
	MachineGun = 20, Frost = 40, Bomb = 45, Tesla = 40, Rocket = 50, Laser = 90, Chain = 150, Orbital = 100,
	FireArcher = 40, BlizzardTotem = 80, MagmaCatapult = 90, StormArchmage = 80, DragonBallista = 100, VoidSorcerer = 180,
	ThunderOracle = 300, CelestialTrebuchet = 200,
	CrimsonBow = 60, CopperCrossbow = 90, ThornSpitter = 90, FrostCatapult = 100, SandTotem = 100,
}
Levels.MAX_COPIES = { Frost = 3, BlizzardTotem = 3 }
-- Stats changées par rapport à IdleTowers : { [type] = { champ = valeur } }.
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
-- TOURS DE DÉPART. Plus de boutique : décision du propriétaire (04/10/2026) : « ça serait mieux pas de tour en
-- boutique, et le niveau 1 te donne un œuf de catapulte qui éclot en 10 s », puis « on peut pas scripter que le
-- premier œuf commun est une catapulte au niveau un ? ». Le joueur commence avec l'Archer seul (une cible, rapide,
-- pas cher ; déjà posé au niveau 1 : STARTING_TOWER) ; sa première victoire au niveau 1 lui donne son PREMIER ŒUF
-- (EGGS.Starter : un œuf commun en apparence, qui donne toujours la Catapulte), qui couve tout seul dans sa
-- première couveuse : 10 s plus tard, il a sa deuxième tour (le tuto le guide). Toutes les autres tours sortent des œufs (« LES ŒUFS »). (Le 02/10 : « il
-- faudrait commencer avec au moins deux tours, juste l'Archer c'est ennuyant » : la Catapulte arrive après le
-- niveau 1, qui dure moins de 2 minutes.)
----------------------------------------------------------------------
Levels.STARTING_TOWERS = { "MachineGun" }

-- BARRE RAPIDE : les BAR_MAX premières tours de la liste du joueur (Levels.ownedTowers, dans l'ordre qu'il choisit
-- dans l'onglet « Mes tours ») sont celles qu'il peut poser dans un niveau (touches 1 à 8 du clavier) ; les autres
-- attendent en RÉSERVE. Avec les œufs, un joueur peut avoir 20 tours : une barre de 20 boutons ne tiendrait pas sur un
-- téléphone. 8 = toutes les tours d'avant les œufs : rien ne change pour un joueur sans tour de palier 2.
Levels.BAR_MAX = 8

-- Tours de sa barre rapide, celles qu'il peut poser dans un niveau : { [type] = true }.
function Levels.barTowers(data): { [string]: boolean }
	local set = {}
	for index, towerType in Levels.ownedTowers(data) do
		if index > Levels.BAR_MAX then
			break
		end
		set[towerType] = true
	end
	return set
end

-- Une NOUVELLE tour pour le joueur (sortie d'un œuf) : elle est à lui et entre dans sa barre rapide :
--   * une tour de palier 2 prend la place de sa tour de base si celle-ci est dans la barre (la tour de base passe à la
--     fin de la liste : en réserve si la barre est pleine) ;
--   * sinon, à la fin de la barre, ou à sa dernière place si la barre est pleine (la tour qui y était passe en
--     réserve).
function Levels.addTower(data, towerType: string)
	local list = Levels.ownedTowers(data)
	data.towers[towerType] = true
	local baseType = IdleTowers.baseOf(towerType)
	local baseIndex = if baseType ~= towerType then table.find(list, baseType) else nil
	if baseIndex and baseIndex <= Levels.BAR_MAX then
		list[baseIndex] = towerType
		table.insert(list, baseType)
	else
		table.insert(list, math.min(#list + 1, Levels.BAR_MAX), towerType)
	end
	data.bar = list
end

----------------------------------------------------------------------
-- Camp d'entraînement. Chaque type de tour a de l'expérience (XP), qui donne un niveau d'entraînement (0 à
-- MAX_LEVEL). Chaque niveau : +DAMAGE_PER_LEVEL de dégâts en niveau, rien d'autre (décision du propriétaire,
-- 04/10/2026 : « le terrain d'entraînement encore là mais pour du niveau dégâts » ; les pouvoirs, eux, sont ceux des
-- tours de palier 2), et une étoile aux niveaux EVOLUTION_LEVELS (« ÉVOLUTIONS »). L'XP vient de deux endroits :
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
	DAMAGE_PER_LEVEL = 0.1, -- +10 % de dégâts par niveau d'entraînement (+60 % au plus)
	SLOT_RATE = { 1, 1.5, 2.2, 3.2, 4.5 }, -- XP par minute selon le niveau de l'emplacement
	SLOT_UPGRADE_COST = { 120, 300, 700, 1500 }, -- prix pour passer au niveau 2, 3, 4, 5
	SLOT_UNLOCK_COST = { 0, 400, 1500 }, -- prix du 1er (offert), 2e et 3e emplacement
	OFFLINE_MAX_SECONDS = 12 * 3600,
	XP_PER_WIN = 8,
	XP_PER_LOSS = 3,
	COINS_PER_XP = 10, -- entraînement acheté avec des pièces de niveau (Levels.trainingPurchase)
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

-- ENTRAÎNEMENT ACHETÉ AVEC DES PIÈCES (bouton ⚡ de l'onglet Entraînement). Demande du propriétaire (03/10/2026) :
-- « améliorer en pièces, peut-être pas mal ». Il peut payer l'XP qui manque à une tour pour son prochain niveau
-- d'entraînement, COINS_PER_XP pièces par XP : 200 pièces pour le niveau 1, 400 pour le 2, 800, 1 600, 3 000, puis
-- 6 000 pour le 6 (12 000 pour mener une tour de 0 au maximum, ★★★). Un joueur bloqué peut donc rejouer des
-- niveaux (pièces et œufs), et rendre ses tours plus fortes.
-- Renvoie (XP de la tour après l'achat, prix) pour une tour qui a `xp` XP, ou nil si elle est au maximum.
function Levels.trainingPurchase(xp: any): (number?, number?)
	local value = tonumber(xp) or 0
	if value ~= value then
		value = 0
	end
	local target = Levels.TRAINING.XP[Levels.trainingLevel(value) + 1]
	if not target then
		return nil, nil
	end
	return target, math.ceil((target - math.max(0, value)) * Levels.TRAINING.COINS_PER_XP - 1e-6)
end

local statsCache = {}

-- Stats d'une tour posée dans un niveau : son niveau de combat (acheté avec l'or) et son entraînement
-- (DAMAGE_PER_LEVEL de dégâts par niveau). Le tableau renvoyé ne doit jamais être modifié (il est partagé).
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
	statsCache[key] = stats
	return stats
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

----------------------------------------------------------------------
-- ÉVOLUTIONS. Demande du propriétaire (02/10/2026) : « tu peux gérer toute la parcelle et le système d'évolution de
-- tour ». Aux niveaux d'entraînement EVOLUTION_LEVELS (2, 4 et 6), une tour ÉVOLUE : 1re, 2e, 3e évolution. Depuis
-- le 04/10/2026, l'entraînement ne donne plus que des dégâts : une évolution est la marque de ces dégâts gagnés
-- (+20 %, +40 %, +60 %). Une tour évoluée se reconnaît :
--   * à ses étoiles (★ à ★★★) sur son étiquette, au camp comme dans un niveau ;
--   * à son apparence : anneau de bronze, d'argent puis d'or autour de son socle, fanions, joyaux
--     (Hub/IdleTowerModel.luau, addEvolution).
----------------------------------------------------------------------
Levels.EVOLUTION_LEVELS = { 2, 4, 6 }
Levels.EVOLUTION_NAMES = { "1re évolution", "2e évolution", "3e évolution" }

-- Nombre d'évolutions (0 à 3) d'une tour à ce niveau d'entraînement (0 pour une tour inconnue).
function Levels.evolutionStage(towerType: string, training: any): number
	if not IdleTowers.Defs[towerType] then
		return 0
	end
	local trained = tonumber(training) or 0
	local stage = 0
	for _, needed in Levels.EVOLUTION_LEVELS do
		if trained >= needed then
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
-- LE CAMP SUR LA PARCELLE. Même demande : la parcelle du joueur est son camp d'entraînement. Les tours mises dans
-- les emplacements d'entraînement sont posées pour de vrai sur des socles de la parcelle et tirent sur des CIBLES
-- ROULANTES qui suivent le chemin : on les voit s'entraîner, avec leurs évolutions (Hub/Camp.luau,
-- Hub/CampGame.luau). L'XP, elle, vient toujours du temps passé dans l'emplacement (TRAINING.SLOT_RATE) : les
-- cibles ne rapportent rien.
--   SPOTS = socles de la parcelle (numéros de PlotLayout.SPOTS) des emplacements d'entraînement 1, 2, 3 : une
--           rangée face au chemin, juste devant le point d'arrivée du joueur.
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
	SPOTS = { 1, 2, 3 },
	TARGET_GAP = 3.5,
	TARGET_SPEED = 0.5,
	TARGET_SECONDS = 2,
	TARGET_MIN_HEALTH = 12,
	MAX_TARGETS = 24,
}

----------------------------------------------------------------------
-- LES ŒUFS. Idée du propriétaire (04/10/2026) : « des œufs de tourelle quand tu finis les niveaux en gagnant, et
-- les mettre dans des générateurs qui donnent un temps » ; « 16 tours qui te bloquent au niveau 40, comme ça je peux
-- travailler les mises à jour petit à petit » ; puis « ça serait mieux pas de tour en boutique, et le niveau 1 te
-- donne un œuf de catapulte qui éclot en 10 s » (« le premier œuf commun est une catapulte »). TOUTES les tours
-- sortent des œufs (sauf l'Archer, donné au départ) :
-- les 8 de palier 1 et leurs 8 versions de palier 2 (IdleTowers.TIER2 : bien plus fortes).
--   * gagner un niveau donne un ŒUF (Levels.eggFor) : première victoire = commun, rare au mini-boss, doré au boss
--     (niveau 1 : le PREMIER ŒUF, Starter) ; en rejouant = commun, rare au boss. EGG_MAX œufs au plus en réserve
--     (au-delà, l'œuf est perdu : l'écran de fin le dit) ;
--   * un œuf se pose dans une COUVEUSE de sa parcelle (la 1re offerte, la 2e achetée : HATCHER_COST ; la 3e est la
--     COUVEUSE ROYALE, dorée, achetée en Robux : ROYAL) et éclot après son temps (EGGS[type].seconds, 2 fois moins
--     dans la couveuse royale), même quand le joueur n'est pas là ; on peut finir tout de suite avec des pièces de
--     niveau (SKIP_COINS_PER_MINUTE par minute qui reste) ou avec des Robux (robuxSkipPrice) ;
--   * en l'ouvrant : une tour au HASARD, avec les chances de son œuf (écrites dans l'onglet Œufs) : par rareté
--     (EGGS[type].chances), et la part des tours de palier 2 (EGGS[type].tier2 : 0 dans un œuf commun, 25 % dans un
--     œuf rare, 75 % dans un œuf doré) ; une tour pas encore à lui devient la sienne (Levels.addTower : une tour de
--     palier 2 prend la place de sa tour de base dans la barre) ; un doublon donne de l'XP d'entraînement à cette tour
--     (DUPLICATE_XP selon sa rareté) ;
--   * le PREMIER ŒUF (Starter, première victoire du niveau 1) : un œuf commun en apparence, qui se pose tout seul
--     dans la première couveuse et éclot en 10 s ; il donne toujours la Catapulte (tower), le tuto montre comment
--     l'ouvrir ;
--   * l'ALLURE de chaque œuf (demande du propriétaire, 04/10/2026, avec l'image d'un autre jeu : « vrai style, les
--     plus rares un peu violets ») : color = sa coquille ; art = { pattern = son motif ("spots" des taches, "cross"
--     deux traînées en croix, "crown" une couronne et des étincelles), detail = la couleur du motif, frame = la
--     couleur de sa vignette (sa rareté : gris, bleu, violet pour le plus rare), rays = des rayons derrière lui }.
--     Dessinés par client/EggArt.luau (l'onglet Œufs) et Hub/Camp.luau (les couveuses en 3D) ;
--   * les ŒUFS SPÉCIAUX (idée du propriétaire, 04/10/2026 : « des œufs spéciaux carmin, ensuite spéciaux orc... »,
--     « une tour spéciale ? ») : un par territoire, qui donne toujours la TOUR SPÉCIALE de ce territoire
--     (IdleTowers.SPECIAL). Battre le boss du territoire (niveaux 10, 20, 30, 40, 50) la première fois le donne EN PLUS
--     de l'œuf doré ; en rejouant ce boss, il revient SPECIAL_REPLAY_CHANCE fois (Levels.bonusEggFor). L'œuf doré reste
--     donc là : le réglage des niveaux ne change pas (les boss demandent les tours de palier 2 des œufs dorés). Un
--     œuf spécial n'est jamais perdu quand la réserve est pleine (il ne compte pas dans EGG_MAX). Un doublon donne
--     DUPLICATE_XP.Special d'XP à sa tour. Leurs dessins : ceux montrés au propriétaire (carmin à bande dorée en
--     zigzag, cuivre à rivets, vert à ronces, bleu glacé à flocons ; le désert : sable à dunes et soleil doré). Les
--     territoires suivants (orc, obsidienne, dragon...) auront les leurs avec leurs mises à jour. Un œuf spécial dont
--     le boss est dans un territoire encore fermé (après OPEN_COUNT) n'apparaît nulle part (Levels.specialEggOpen).
-- Les chiffres sont les miens (temps, chances, prix) : à changer s'il le veut.
----------------------------------------------------------------------
local COMMON_COLOR = Color3.fromRGB(246, 242, 232)
local COMMON_ART = { pattern = "spots", detail = Color3.fromRGB(64, 170, 240), frame = Color3.fromRGB(128, 136, 150) }
Levels.EGGS = {
	Common = {
		displayName = "Œuf commun",
		seconds = 15 * 60,
		color = COMMON_COLOR,
		art = COMMON_ART,
		chances = { Common = 0.7, Rare = 0.25, Epic = 0.05, Legendary = 0 },
		tier2 = 0, -- part des tours de palier 2 (un œuf commun : seulement des tours de palier 1)
	},
	Rare = {
		displayName = "Œuf rare",
		seconds = 60 * 60,
		color = Color3.fromRGB(52, 100, 205),
		art = { pattern = "cross", detail = Color3.fromRGB(176, 228, 255), frame = Color3.fromRGB(38, 142, 232), rays = true },
		chances = { Common = 0.35, Rare = 0.45, Epic = 0.17, Legendary = 0.03 },
		tier2 = 0.25,
	},
	Gold = {
		displayName = "Œuf doré",
		seconds = 4 * 3600,
		color = Color3.fromRGB(255, 198, 56),
		-- (le plus rare : couronne violette, vignette violette)
		art = { pattern = "crown", detail = Color3.fromRGB(146, 66, 220), frame = Color3.fromRGB(124, 60, 200), rays = true },
		chances = { Common = 0, Rare = 0.4, Epic = 0.45, Legendary = 0.15 },
		tier2 = 0.75,
	},
	-- Le PREMIER ŒUF : la première victoire du niveau 1 (TOURS DE DÉPART). Un œuf commun pour le joueur (même nom, même
	-- allure), mais il donne toujours la Catapulte (tower) et il éclot en 10 s. Il ne va pas dans la réserve : il se pose
	-- tout seul dans la première couveuse vide (autoHatch, Levels.giveEgg).
	Starter = {
		displayName = "Œuf commun",
		seconds = 10,
		color = COMMON_COLOR,
		art = COMMON_ART,
		tower = "Bomb",
		autoHatch = true,
	},
	-- Les ŒUFS SPÉCIAUX (voir plus haut) : territory = la carte du territoire dont le boss le donne, tower = sa tour
	-- spéciale (toujours la même). art.accent = une 2e couleur de motif (les rivets, les feuilles).
	Crimson = {
		displayName = "Œuf carmin",
		seconds = 60 * 60,
		color = Color3.fromRGB(200, 36, 60),
		art = { pattern = "zigzag", detail = Color3.fromRGB(245, 197, 66), frame = Color3.fromRGB(178, 30, 54), rays = true },
		tower = "CrimsonBow",
		territory = "Valley",
		special = true,
	},
	Copper = {
		displayName = "Œuf de cuivre",
		seconds = 60 * 60,
		color = Color3.fromRGB(199, 123, 58),
		art = { pattern = "rivets", detail = Color3.fromRGB(126, 69, 32), accent = Color3.fromRGB(242, 192, 138), frame = Color3.fromRGB(176, 102, 46), rays = true },
		tower = "CopperCrossbow",
		territory = "Pass",
		special = true,
	},
	Bramble = {
		displayName = "Œuf des ronces",
		seconds = 60 * 60,
		color = Color3.fromRGB(62, 142, 65),
		art = { pattern = "thorns", detail = Color3.fromRGB(28, 74, 32), accent = Color3.fromRGB(139, 209, 124), frame = Color3.fromRGB(48, 132, 58), rays = true },
		tower = "ThornSpitter",
		territory = "Forest",
		special = true,
	},
	Rime = {
		displayName = "Œuf de givre",
		seconds = 60 * 60,
		color = Color3.fromRGB(159, 216, 245),
		art = { pattern = "flakes", detail = Color3.fromRGB(255, 255, 255), frame = Color3.fromRGB(70, 150, 222), rays = true },
		tower = "FrostCatapult",
		territory = "Glacier",
		special = true,
	},
	-- (le désert : niveaux 41 à 50, fermés pour l'instant ; son œuf n'apparaît nulle part avant leur ouverture, voir
	-- Levels.specialEggOpen)
	Dune = {
		displayName = "Œuf des dunes",
		seconds = 60 * 60,
		color = Color3.fromRGB(232, 194, 120),
		art = { pattern = "dunes", detail = Color3.fromRGB(166, 108, 48), accent = Color3.fromRGB(255, 214, 80), frame = Color3.fromRGB(204, 142, 52), rays = true },
		tower = "SandTotem",
		territory = "Desert",
		special = true,
	},
}
Levels.EGG_ORDER = { "Common", "Rare", "Gold" } -- (les œufs de la réserve ; le premier œuf n'y va jamais)
Levels.SPECIAL_EGG_ORDER = { "Crimson", "Copper", "Bramble", "Rime", "Dune" } -- (dans l'ordre des territoires)
Levels.SPECIAL_REPLAY_CHANCE = 0.1 -- en rejouant le boss d'un territoire : 1 chance sur 10 de regagner son œuf spécial
Levels.EGG_MAX = 30 -- œufs en réserve au plus (tous types ensemble)
Levels.HATCHER_COST = { 0, 600 } -- prix de la 1re (offerte) et de la 2e couveuse, en pièces de niveau (la 3e : ROYAL)
Levels.SKIP_COINS_PER_MINUTE = 5 -- finir un œuf tout de suite : pièces de niveau par minute qui reste
-- LA COUVEUSE ROYALE (demandes du propriétaire, 04/10/2026 : « une 3e couveuse d'une autre couleur, incubation 2 fois
-- plus rapide, à payer en Robux, 99 Robux », qui remplace la 3e couveuse à pièces, « mets-la en or ») : la 3e couveuse
-- de la parcelle (index), dorée, à vie avec le pass « Couveuse royale » (Shared/Monetization.luau, Hub/Shop.luau) ;
-- ses œufs éclosent `speed` fois plus vite. Son œuf est gardé à part (data.royal, pas data.hatchers) : on peut
-- l'avoir sans avoir acheté la 2e.
Levels.ROYAL = { index = 3, speed = 2 }
-- FINIR UN ŒUF EN ROBUX (« 1 Robux les 5 min ») : 1 Robux par tranche de ROBUX_SKIP_SECONDS qui reste, ramené au
-- plus grand de ces prix qui ne le dépasse pas (un produit Roblox a un prix fixe : un produit par prix, créé par le
-- propriétaire ; 7 prix arrondis : sa réponse à ma question).
Levels.ROBUX_SKIP_SECONDS = 5 * 60
Levels.ROBUX_SKIP_PRICES = { 1, 2, 3, 6, 12, 24, 48 }
Levels.RECEIPTS_MAX = 50 -- numéros des derniers achats en Robux gardés dans la sauvegarde (un achat compté une fois)
-- LES PASS « XP x2 » et « ARGENT x2 » (demande du propriétaire, 04/10/2026 : « x2 XP 99 Robux aussi, et x2 argent 199
-- Robux » ; Shared/Monetization.luau) : toute l'XP d'entraînement gagnée (camp, niveaux joués, doublons des œufs ;
-- pas celle achetée avec le bouton ⚡), et les pièces de niveau gagnées en jouant les niveaux, multipliées par ça.
Levels.XP_PASS_MULTIPLIER = 2
Levels.COINS_PASS_MULTIPLIER = 2
Levels.DUPLICATE_XP = { Common = 20, Rare = 40, Epic = 80, Legendary = 160, Special = 200 } -- XP d'entraînement d'un doublon
Levels.RARITY_NAMES = { Common = "Commune", Rare = "Rare", Epic = "Épique", Legendary = "Légendaire", Special = "Spéciale" }
-- Raretés des œufs au hasard (les tours spéciales n'y sont jamais : elles sortent de leur œuf spécial).
Levels.RARITY_ORDER = { "Common", "Rare", "Epic", "Legendary" }

-- L'œuf gagné en remportant ce niveau (première victoire ou non).
function Levels.eggFor(level: number, firstClear: boolean): string
	if level == 1 and firstClear then
		return "Starter" -- (le premier œuf : un œuf commun qui donne la Catapulte)
	end
	local definition = Levels.definition(level)
	if firstClear then
		return if definition.boss then "Gold" elseif definition.miniBoss then "Rare" else "Common"
	end
	return if definition.boss then "Rare" else "Common"
end

-- L'œuf spécial du territoire dont la carte est `mapName` (nil si ce territoire n'en a pas encore).
function Levels.territoryEgg(mapName: string): string?
	for _, eggType in Levels.SPECIAL_EGG_ORDER do
		if Levels.EGGS[eggType].territory == mapName then
			return eggType
		end
	end
	return nil
end

-- L'œuf spécial qui donne cette tour (nil pour une tour qui n'est pas spéciale).
function Levels.towerEgg(towerType: string): string?
	for _, eggType in Levels.SPECIAL_EGG_ORDER do
		if Levels.EGGS[eggType].tower == towerType then
			return eggType
		end
	end
	return nil
end

-- Le niveau du boss qui donne cet œuf spécial (10 pour l'œuf carmin, 20, 30, 40, 50).
function Levels.specialBossLevel(eggType: string): number
	return (table.find(Levels.TERRITORIES, Levels.EGGS[eggType].territory) or 1) * Levels.TERRITORY_SIZE
end

-- Vrai si le boss qui donne cet œuf spécial est ouvert (niveau <= OPEN_COUNT). Sinon, l'œuf et sa tour restent
-- cachés dans l'interface (onglet Œufs, listes des tours) jusqu'à l'ouverture de leur territoire.
function Levels.specialEggOpen(eggType: string): boolean
	return Levels.specialBossLevel(eggType) <= Levels.OPEN_COUNT
end

-- L'ŒUF SPÉCIAL gagné EN PLUS de l'œuf du niveau (Levels.eggFor) en remportant ce niveau, ou nil : celui du
-- territoire, à son boss ; à la première victoire, toujours ; en rejouant, si roll < SPECIAL_REPLAY_CHANCE (roll =
-- un tirage de 0 à 1, au hasard : Random du serveur).
function Levels.bonusEggFor(level: number, firstClear: boolean, roll: number): string?
	local definition = Levels.definition(level)
	if not definition.boss then
		return nil
	end
	local eggType = Levels.territoryEgg(definition.map)
	if eggType and (firstClear or roll < Levels.SPECIAL_REPLAY_CHANCE) then
		return eggType
	end
	return nil
end

-- Œufs en réserve (communs, rares et dorés : les œufs spéciaux ne comptent pas, ils ne sont jamais perdus).
function Levels.eggCount(levels): number
	local count = 0
	for _, eggType in Levels.EGG_ORDER do
		count += levels.eggs[eggType] or 0
	end
	return count
end

-- Un œuf de plus en réserve ; faux si la réserve est pleine (l'œuf est perdu), ou pour le premier œuf (il ne va
-- jamais dans la réserve : Levels.giveEgg). Un œuf spécial ne compte pas dans la réserve (EGG_MAX de chaque au plus).
function Levels.addEgg(levels, eggType: string): boolean
	local egg = Levels.EGGS[eggType]
	if not egg or egg.autoHatch then
		return false
	end
	local full = if egg.special then (levels.eggs[eggType] or 0) >= Levels.EGG_MAX else Levels.eggCount(levels) >= Levels.EGG_MAX
	if full then
		return false
	end
	levels.eggs[eggType] = (levels.eggs[eggType] or 0) + 1
	return true
end

-- Un œuf gagné : dans la réserve (EGG_MAX au plus : au-delà, il est perdu) ; le premier œuf (autoHatch) se pose
-- tout seul dans la première couveuse vide et éclot EGGS[type].seconds plus tard (now = l'heure du serveur, os.time).
-- Renvoie "reserve", "hatcher", ou nil : perdu (réserve pleine ; ou le premier œuf sans couveuse vide : le
-- serveur donne alors sa tour tout de suite).
function Levels.giveEgg(levels, eggType: string, now: number): string?
	local egg = Levels.EGGS[eggType]
	if not egg then
		return nil
	end
	if egg.autoHatch then
		for _, hatcher in levels.hatchers do
			if hatcher.egg == "" then
				hatcher.egg = eggType
				hatcher.readyAt = now + egg.seconds
				return "hatcher"
			end
		end
		return nil
	end
	return if Levels.addEgg(levels, eggType) then "reserve" else nil
end

-- Tours d'un palier (IdleTowers.TIER1 ou TIER2) qui ont cette rareté, dans l'ordre de la liste.
local function towersOf(list: { string }, rarity: string): { string }
	local found = {}
	for _, towerType in list do
		if IdleTowers.Defs[towerType].rarity == rarity then
			table.insert(found, towerType)
		end
	end
	return found
end

-- Les tours qu'un œuf peut donner et leurs chances : { { tower, chance } } (chance de 0 à 1, total 1). La chance de
-- chaque rareté est partagée entre les tours de palier 1 (1 - tier2) et celles de palier 2 (tier2), puis à parts
-- égales entre les tours de chaque palier. Le premier œuf : sa tour, à coup sûr.
function Levels.eggChances(eggType: string): { { tower: string, chance: number } }
	local egg = Levels.EGGS[eggType]
	if egg.tower then
		return { { tower = egg.tower, chance = 1 } }
	end
	local tier2 = egg.tier2 or 0
	local list = {}
	for _, rarity in Levels.RARITY_ORDER do
		local chance = egg.chances[rarity] or 0
		if chance > 0 then
			for tier, towers in { towersOf(IdleTowers.TIER1, rarity), towersOf(IdleTowers.TIER2, rarity) } do
				local share = if tier == 1 then 1 - tier2 else tier2
				if share > 0 and #towers > 0 then
					for _, towerType in towers do
						table.insert(list, { tower = towerType, chance = chance * share / #towers })
					end
				end
			end
		end
	end
	return list
end

-- La tour qui sort de cet œuf pour un tirage `roll` (de 0 à 1, au hasard : Random du serveur).
function Levels.rollEgg(eggType: string, roll: number): string
	local list = Levels.eggChances(eggType)
	local sum = 0
	for _, entry in list do
		sum += entry.chance
		if roll < sum then
			return entry.tower
		end
	end
	return list[#list].tower
end

-- Une tour sort d'un œuf : nouvelle, elle est au joueur (Levels.addTower : dans sa barre rapide) ; doublon :
-- DUPLICATE_XP d'XP d'entraînement pour elle, fois `multiplier` (pass XP x2). Renvoie (nouvelle, XP gagnée).
function Levels.hatchTower(levels, towerType: string, multiplier: number?): (boolean, number)
	if not levels.towers[towerType] then
		Levels.addTower(levels, towerType)
		return true, 0
	end
	local xp = (Levels.DUPLICATE_XP[IdleTowers.Defs[towerType].rarity] or 0) * (multiplier or 1)
	levels.xp[towerType] = (levels.xp[towerType] or 0) + xp
	return false, xp
end

-- Prix pour finir tout de suite un œuf qui doit encore couver `seconds` secondes (0 s'il est prêt).
function Levels.skipCost(seconds: number): number
	return if seconds > 0 then math.ceil(seconds / 60) * Levels.SKIP_COINS_PER_MINUTE else 0
end

-- Prix en Robux pour finir tout de suite un œuf qui doit encore couver `seconds` secondes : 1 Robux par tranche de
-- 5 min qui reste, ramené au plus grand des prix de `prices` qui ne le dépasse pas (par défaut ROBUX_SKIP_PRICES ;
-- le serveur donne seulement les produits qui existent). 0 s'il est prêt (ou aucun prix).
function Levels.robuxSkipPrice(seconds: number, prices: { number }?): number
	if seconds <= 0 then
		return 0
	end
	local exact = math.ceil(seconds / Levels.ROBUX_SKIP_SECONDS)
	local best, smallest = 0, math.huge
	for _, price in prices or Levels.ROBUX_SKIP_PRICES do
		smallest = math.min(smallest, price)
		if price <= exact and price > best then
			best = price
		end
	end
	-- (moins de temps que le plus petit prix : le plus petit prix)
	return if best > 0 then best elseif smallest < math.huge then smallest else 0
end

-- Temps de couvaison d'un œuf (secondes) : la couveuse royale va ROYAL.speed fois plus vite.
function Levels.hatchSeconds(eggType: string, royal: boolean?): number
	local seconds = Levels.EGGS[eggType].seconds
	return if royal then math.ceil(seconds / Levels.ROYAL.speed) else seconds
end

----------------------------------------------------------------------
-- « BLOQUÉ ? ». Ma proposition du 03/10/2026, acceptée par le propriétaire le 04/10/2026 (« oui ») : « un conseil
-- plus clair après deux défaites de suite au même niveau ». Les données du joueur comptent ses défaites DE SUITE à un
-- niveau, sans l'avoir réussi entre-temps (lossLevel, lossStreak) : une victoire à un AUTRE niveau ne remet pas le
-- compte à zéro (rejouer un niveau réussi pour devenir plus fort est justement le conseil) ; un abandon ne compte pas.
-- À STUCK_LOSSES défaites, l'écran de fin (client/LevelsUI.luau) dit comment devenir plus fort : rejouer un niveau
-- réussi (un bouton relance le niveau d'avant), puis UNE aide selon sa situation (des œufs qui attendent, un boss qui
-- demande une tour de palier 2, sinon le camp d'entraînement).
----------------------------------------------------------------------
Levels.STUCK_LOSSES = 2

-- Note une vraie fin de niveau (victoire ou défaite, pas un abandon) dans les données du joueur. Renvoie ses défaites
-- de suite à ce niveau (0 après une victoire).
function Levels.recordResult(levels, level: number, won: boolean): number
	if won then
		if levels.lossLevel == level then
			levels.lossLevel, levels.lossStreak = 0, 0
		end
		return 0
	end
	if levels.lossLevel == level then
		levels.lossStreak += 1
	else
		levels.lossLevel, levels.lossStreak = level, 1
	end
	return levels.lossStreak
end

----------------------------------------------------------------------
-- LES PANNEAUX DE LA PLACE. Demande du propriétaire (04/10/2026) : « rajoute les panneaux au centre avec les niveaux
-- des joueurs » (comme le classement solo de l'ancien jeu). Deux panneaux, de chaque côté de la place centrale
-- (Hub/LevelBoard.luau) : les meilleurs joueurs de tous les serveurs (LevelLeaderboard.luau) et les joueurs du
-- serveur, rangés par plus haut niveau réussi, puis, à égalité, par nombre de victoires. Un OrderedDataStore ne garde
-- qu'un nombre entier par joueur : SCORE = niveau x BOARD_WINS + victoires (plafonnées à BOARD_WINS - 1 ; au plus
-- 101 milliards, loin de la limite des nombres entiers exacts).
----------------------------------------------------------------------
Levels.BOARD_WINS = 1e9

-- Score d'un joueur pour le classement (nil tant qu'il n'a réussi aucun niveau : il n'y apparaît pas).
function Levels.boardScore(best: any, wins: any): number?
	local level = math.floor(tonumber(best) or 0)
	if level ~= level or level < 1 then
		return nil
	end
	local count = math.floor(tonumber(wins) or 0)
	if count ~= count then
		count = 0
	end
	return math.min(level, Levels.COUNT) * Levels.BOARD_WINS + math.clamp(count, 0, Levels.BOARD_WINS - 1)
end

-- Le niveau et les victoires d'un score (Levels.boardScore).
function Levels.fromBoardScore(score: any): (number, number)
	local value = math.floor(tonumber(score) or 0)
	if value ~= value or value < 0 then
		return 0, 0
	end
	return value // Levels.BOARD_WINS, value % Levels.BOARD_WINS
end

----------------------------------------------------------------------
-- TUTO des nouveaux joueurs (affichage : client/TutorialUI.luau ; serveur : Hub/LevelsService.luau). Demande du
-- propriétaire (02/10/2026) : « fais le tuto bien, je veux un jeu sortable ». Pas d'écran à lire : une flèche montre
-- quoi toucher. Le champ `tutorial` des données du joueur dit où il en est :
--   0    = nouveau joueur : la flèche le mène au niveau 1, puis lui montre ses deux premiers gestes (firstSteps) ;
--   EGG  = il a gagné le niveau 1 : son premier œuf couve dans sa couveuse, la flèche lui montre comment
--          l'ouvrir (onglet Œufs) ;
--   DONE = fini (premier œuf ouvert, ou bouton « Passer le tuto »).
----------------------------------------------------------------------
Levels.TUTORIAL = { EGG = 1, DONE = 2 }

-- Les DEUX PREMIERS GESTES du niveau 1, montrés par la flèche du tuto (TutorialUI.luau). Retour du propriétaire
-- (03/10/2026) : « raccourcis le tuto de la première partie, juste poser une tour, et pas forcer un positionnement,
-- et améliorer, et fin, le gars se débrouille ». Avant, la flèche montrait chaque achat jusqu'à la fin du niveau,
-- et où poser.
--   1. POSER une tour, où il veut : tant qu'il n'y a que la tour offerte (ou aucune) ;
--   2. AMÉLIORER une tour : tant qu'aucune n'est au niveau 2.
-- owned  = ses types de tours, dans l'ordre de sa barre ;
-- towers = ses tours posées, de la plus ancienne à la plus récente : { { type = "MachineGun", level = 1 } } ;
-- gold   = son or.
-- Renvoie (conseil, fini) :
--   conseil = { kind = "Place", tower = type } (la première tour de sa barre qu'il peut payer),
--             { kind = "Upgrade", index = numéro dans `towers` } (la tour la moins chère à améliorer),
--             ou nil : rien à montrer (pas encore de quoi payer : l'or arrive, chaque monstre tué en donne) ;
--   fini    = vrai quand les deux gestes sont faits : la flèche ne montre plus rien pendant le niveau.
function Levels.firstSteps(owned: { string }, towers: { any }, gold: number): (any, boolean)
	local placed, upgraded = 0, false
	for _, tower in towers do
		if IdleTowers.Defs[tower.type] then
			placed += 1
			upgraded = upgraded or (tonumber(tower.level) or 1) >= 2
		end
	end
	if placed < 2 then
		for _, towerType in owned do
			if Levels.TOWER_COST[towerType] and gold >= Levels.placeCost(towerType) then
				return { kind = "Place", tower = towerType }, false
			end
		end
		return nil, false
	end
	if upgraded then
		return nil, true
	end
	local best, bestCost = nil, math.huge
	for index, tower in towers do
		local cost = if IdleTowers.Defs[tower.type] then Levels.upgradeCost(tower.type, tonumber(tower.level) or 1) else nil
		if cost and cost < bestCost then
			best, bestCost = index, cost
		end
	end
	return (if best and gold >= bestCost then { kind = "Upgrade", index = best } else nil), false
end

----------------------------------------------------------------------
-- Données sauvegardées du joueur (data.levels, PlayerData.luau). Toujours propres : cleanData remet tout champ
-- absent ou abîmé à sa valeur de départ.
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
		tutorial = 0, -- étape du tuto (Levels.TUTORIAL) : 0 = nouveau joueur
		invitedBy = 0, -- UserId de l'ami dont l'invitation l'a fait venir (0 = personne) : « LES AMIS »
		invited = {}, -- UserId des amis venus grâce à ses invitations (récompensés, une fois chacun)
		eggs = {}, -- [type d'œuf] = nombre en réserve : « LES ŒUFS »
		hatchers = { { egg = "", readyAt = 0 } }, -- ses couveuses (la 1re offerte) : egg = type d'œuf ("" = vide),
		-- readyAt = os.time() où il éclot
		royal = { egg = "", readyAt = 0 }, -- l'œuf de la couveuse royale (Levels.ROYAL : pass en Robux)
		receipts = {}, -- numéros des derniers achats en Robux déjà comptés (Hub/Shop.luau)
		lossLevel = 0, -- « BLOQUÉ ? » : le niveau de ses dernières défaites de suite (0 = aucun)...
		lossStreak = 0, -- ... et leur nombre (Levels.recordResult)
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
	data.lossLevel = math.floor(cleanNumber(saved.lossLevel, 0, Levels.COUNT, 0))
	data.lossStreak = if data.lossLevel > 0 then math.floor(cleanNumber(saved.lossStreak, 0, 1e6, 0)) else 0
	if typeof(saved.eggs) == "table" then
		for _, list in { Levels.EGG_ORDER, Levels.SPECIAL_EGG_ORDER } do
			for _, eggType in list do
				local count = math.floor(cleanNumber(saved.eggs[eggType], 0, Levels.EGG_MAX, 0))
				if count > 0 then
					data.eggs[eggType] = count
				end
			end
		end
	end
	if typeof(saved.hatchers) == "table" and #saved.hatchers >= 1 then
		data.hatchers = {}
		for index = 1, math.min(#saved.hatchers, #Levels.HATCHER_COST) do
			local hatcher = saved.hatchers[index]
			local egg = if typeof(hatcher) == "table" and Levels.EGGS[hatcher.egg] then hatcher.egg else ""
			local readyAt = if egg ~= "" then math.floor(cleanNumber(hatcher.readyAt, 0, 1e11, 0)) else 0
			table.insert(data.hatchers, { egg = egg, readyAt = readyAt })
		end
		-- La 3e couveuse à pièces d'avant la couveuse royale : son œuf revient dans la réserve.
		for index = #Levels.HATCHER_COST + 1, #saved.hatchers do
			local hatcher = saved.hatchers[index]
			local egg = if typeof(hatcher) == "table" then hatcher.egg else nil
			if typeof(egg) == "string" and Levels.EGGS[egg] and not Levels.EGGS[egg].autoHatch then
				data.eggs[egg] = math.min((data.eggs[egg] or 0) + 1, Levels.EGG_MAX)
			end
		end
	end
	local royal = saved.royal
	if typeof(royal) == "table" and typeof(royal.egg) == "string" and Levels.EGGS[royal.egg] and not Levels.EGGS[royal.egg].autoHatch then
		data.royal = { egg = royal.egg, readyAt = math.floor(cleanNumber(royal.readyAt, 0, 1e11, 0)) }
	end
	if typeof(saved.receipts) == "table" then
		for _, receiptId in saved.receipts do
			if typeof(receiptId) == "string" and #receiptId <= 100 and not table.find(data.receipts, receiptId) then
				table.insert(data.receipts, receiptId)
			end
		end
		while #data.receipts > Levels.RECEIPTS_MAX do
			table.remove(data.receipts, 1)
		end
	end
	data.invitedBy = math.floor(cleanNumber(saved.invitedBy, -1e15, 1e15, 0))
	if typeof(saved.invited) == "table" then
		for _, friendId in saved.invited do
			local id = math.floor(cleanNumber(friendId, -1e15, 1e15, 0))
			if id ~= 0 and not table.find(data.invited, id) and #data.invited < Levels.FRIENDS.INVITE_MAX then
				table.insert(data.invited, id)
			end
		end
	end
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
	-- Étape du tuto. Sauvegarde d'avant le tuto (champ absent) : celui qui a déjà gagné un niveau, ou qui a d'autres
	-- tours que celles du départ, ne revoit rien.
	local others = false
	for towerType in data.towers do
		others = others or table.find(Levels.STARTING_TOWERS, towerType) == nil
	end
	local inferred = if others or data.best >= 1 then Levels.TUTORIAL.DONE else 0
	data.tutorial = if saved.tutorial == nil then inferred else math.floor(cleanNumber(saved.tutorial, 0, Levels.TUTORIAL.DONE, inferred))
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
-- le dernier calcul (fois `multiplier` : pass XP x2), OFFLINE_MAX_SECONDS au plus d'un coup. Premier calcul
-- (trainedAt = 0) : rien, l'heure est notée. Renvoie l'XP gagnée par type : { [type] = XP } (vide si rien).
function Levels.accrueTraining(data, now: number, multiplier: number?): { [string]: number }
	local gained = {}
	local last = data.trainedAt
	data.trainedAt = now
	if typeof(last) ~= "number" or last <= 0 or now <= last then
		return gained
	end
	local minutes = math.min(now - last, Levels.TRAINING.OFFLINE_MAX_SECONDS) / 60
	for _, slot in data.slots do
		if slot.tower ~= "" and data.towers[slot.tower] then
			local amount = minutes * Levels.TRAINING.SLOT_RATE[slot.level] * (multiplier or 1)
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
-- (ordre de IdleTowers.ORDER). Les BAR_MAX premières peuvent être posées dans un niveau (Levels.barTowers), les
-- autres sont en réserve.
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

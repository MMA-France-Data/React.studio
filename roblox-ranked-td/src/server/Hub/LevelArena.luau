-- Zones de combat des NIVEAUX (prototype de la nouvelle formule : Shared/Levels.luau).
-- Une zone par joueur, dans le même serveur que la map principale, très loin de la place (Levels.arenaCFrame) :
-- pas de téléportation, donc pas d'écran de chargement. Le dossier workspace.Arenas.Arena<n> existe dès le départ
-- (vide) ; la carte du niveau n'y est construite que pendant qu'un niveau tourne (« Map »), puis effacée : six
-- cartes vides ne coûtent rien, et jamais dix cartes chargées en même temps.
-- Le dossier de la zone porte les attributs lus par les clients : Slot, PlotIndex (numéro pour l'affichage, comme
-- une parcelle de plus), Map (nom de la carte, absent = zone vide), puis ceux du niveau en cours (LevelGame).
-- Il contient aussi « Focus », une pièce invisible au centre : le joueur qui joue un niveau la reçoit comme centre
-- de chargement (Player.ReplicationFocus, LevelsService), au cas où le jeu chargerait la carte par morceaux
-- (StreamingEnabled) : son personnage, lui, reste sur la place.
-- Tout le décor est en MedievalModels.sceneryPart (ni collision ni clic). La pose libre des tours n'a besoin
-- d'aucune pièce : le client calcule le point du sol visé (LevelsUI.luau) et le serveur le vérifie
-- (Levels.checkPlacement).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Levels = require(Shared.Levels)
local MedievalModels = require(Shared.MedievalModels)
local RoadGeometry = require(Shared.RoadGeometry)
local scenery = MedievalModels.sceneryPart

local LevelArena = {}

local arenas = {} -- [slot] = { slot, index, folder, cframe, focus, map, palier }

-- Décor de chaque territoire (palier = (niveau - 1) // 10) : couleurs du sol, du terrain et du chemin.
local THEMES = {
	[0] = {
		ground = Color3.fromRGB(88, 116, 69),
		field = Color3.fromRGB(104, 136, 82),
		path = Color3.fromRGB(150, 138, 110),
		wall = Color3.fromRGB(139, 144, 128),
		banner = Color3.fromRGB(142, 48, 44),
	},
}

-- Crée les dossiers vides des zones. À appeler une fois au démarrage du serveur.
function LevelArena.init()
	local root = Instance.new("Folder")
	root.Name = "Arenas"
	for slot = 1, Levels.ARENA_SLOTS do
		local folder = Instance.new("Folder")
		folder.Name = "Arena" .. slot
		folder:SetAttribute("Slot", slot)
		folder:SetAttribute("PlotIndex", Levels.arenaIndex(slot))
		local cframe = Levels.arenaCFrame(slot)
		local focus = scenery(folder, "Focus", Vector3.one, cframe, Color3.new(1, 1, 1))
		focus.Transparency = 1
		focus.CastShadow = false
		folder.Parent = root
		arenas[slot] = { slot = slot, index = Levels.arenaIndex(slot), folder = folder, cframe = cframe, focus = focus, map = nil, palier = nil }
	end
	root.Parent = workspace
	return root
end

function LevelArena.get(slot: number)
	return arenas[slot]
end

-- Construit la carte `mapName` dans la zone (l'ancienne est effacée). Renvoie la zone.
-- La même carte déjà là (niveau suivant, « Rejouer ») : rien n'est refait, l'écran du joueur ne clignote pas.
function LevelArena.build(slot: number, mapName: string, palier: number)
	local arena = arenas[slot]
	assert(arena, "Zone inconnue : " .. tostring(slot))
	if arena.map == mapName and arena.palier == palier and arena.folder:FindFirstChild("Map") then
		return arena
	end
	LevelArena.clear(slot)
	local geometry = Levels.geometry(mapName)
	local map = geometry.map
	local theme = THEMES[palier] or THEMES[0]
	local origin = arena.cframe
	local w, d = map.width, map.depth

	local folder = Instance.new("Folder")
	folder.Name = "Map"

	-- Grand sol autour du terrain, puis le terrain lui-même (là où on pose les tours), un peu plus clair.
	scenery(folder, "Ground", Vector3.new(w + 260, 1, d + 260), origin * CFrame.new(0, -0.7, 0), theme.ground, Enum.Material.Grass)
	scenery(folder, "Field", Vector3.new(w, 1, d), origin * CFrame.new(0, -0.5, 0), theme.field, Enum.Material.Grass)

	-- Chemin des monstres.
	for _, slab in RoadGeometry.rectangles(map.path, Levels.PATH_WIDTH) do
		scenery(folder, "Path", slab.size, origin * CFrame.new(slab.center + Vector3.new(0, 0.05, 0)), theme.path, Enum.Material.SmoothPlastic)
	end

	-- Porte d'invasion à l'entrée (le chemin part vers +X : la porte est en travers).
	local entry = map.path[1]
	for _, side in { -1, 1 } do
		local post = origin * CFrame.new(entry + Vector3.new(-1.5, 0, side * (Levels.PATH_WIDTH / 2 + 1.2)))
		scenery(folder, "GateTower", Vector3.new(2.4, 7, 2.4), post * CFrame.new(0, 3.5, 0), Color3.fromRGB(78, 75, 69), Enum.Material.Brick)
		scenery(folder, "GateCoping", Vector3.new(3.1, 0.5, 3.1), post * CFrame.new(0, 7.25, 0), Color3.fromRGB(185, 177, 153), Enum.Material.Limestone)
	end
	scenery(folder, "GateLintel", Vector3.new(2.2, 1.5, Levels.PATH_WIDTH + 4.8), origin * CFrame.new(entry + Vector3.new(-1.5, 7, 0)), Color3.fromRGB(70, 67, 62), Enum.Material.Brick)

	-- Château à défendre, au bout du chemin.
	local keep = origin * CFrame.new(map.base)
	scenery(folder, "Base", Vector3.new(7, 6, 7), keep * CFrame.new(0, 3, 0), Color3.fromRGB(103, 98, 88), Enum.Material.Brick)
	for _, offset in { Vector3.new(-3.3, 3.8, -3.3), Vector3.new(3.3, 3.8, -3.3), Vector3.new(-3.3, 3.8, 3.3), Vector3.new(3.3, 3.8, 3.3) } do
		scenery(folder, "CastleTurret", Vector3.new(7.6, 2, 2), keep * CFrame.new(offset) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(88, 84, 76), Enum.Material.Cobblestone).Shape = Enum.PartType.Cylinder
	end
	MedievalModels.banner(folder, keep * CFrame.new(0, 6, 0), theme.banner, 1.3)

	-- Muret autour du terrain (bas : il ne cache rien vu d'en haut), piliers aux coins. Côté entrée, il s'ouvre
	-- devant la porte d'invasion.
	local gateHalf = Levels.PATH_WIDTH / 2 + 2.4
	for _, side in { -1, 1 } do
		scenery(folder, "BoundaryWall", Vector3.new(w + 2, 1.1, 0.9), origin * CFrame.new(0, 0.55, side * (d / 2 + 0.5)), theme.wall, Enum.Material.Cobblestone)
		for _, depthSide in { -1, 1 } do
			scenery(folder, "BoundaryPillar", Vector3.new(1.8, 2.4, 1.8), origin * CFrame.new(side * (w / 2 + 0.5), 1.2, depthSide * (d / 2 + 0.5)), theme.wall, Enum.Material.Cobblestone)
		end
	end
	scenery(folder, "BoundaryWall", Vector3.new(0.9, 1.1, d + 2), origin * CFrame.new(w / 2 + 0.5, 0.55, 0), theme.wall, Enum.Material.Cobblestone)
	for _, piece in { { -d / 2 - 1, entry.Z - gateHalf }, { entry.Z + gateHalf, d / 2 + 1 } } do
		local from, to = piece[1], piece[2]
		if to - from > 0.5 then
			scenery(folder, "BoundaryWall", Vector3.new(0.9, 1.1, to - from), origin * CFrame.new(-w / 2 - 0.5, 0.55, (from + to) / 2), theme.wall, Enum.Material.Cobblestone)
		end
	end
	-- Quelques arbres, seulement au fond et sur les côtés (devant, ils cacheraient le terrain à la caméra).
	for i = 0, 6 do
		MedievalModels.tree(folder, origin * CFrame.new(-w / 2 + 6 + i * (w - 12) / 6, 0, -d / 2 - 12 - (i % 2) * 6), 1.1 + (i % 3) * 0.15, i % 4 == 1)
	end
	for _, side in { -1, 1 } do
		MedievalModels.tree(folder, origin * CFrame.new(side * (w / 2 + 14), 0, -6), 1.2, false)
	end

	folder.Parent = arena.folder
	arena.map = mapName
	arena.palier = palier
	arena.folder:SetAttribute("Map", mapName)
	return arena
end

-- Efface la carte de la zone (le dossier de la zone reste).
function LevelArena.clear(slot: number)
	local arena = arenas[slot]
	if not arena then
		return
	end
	local old = arena.folder:FindFirstChild("Map")
	if old then
		old:Destroy()
	end
	arena.map = nil
	arena.palier = nil
	arena.folder:SetAttribute("Map", nil)
end

return LevelArena

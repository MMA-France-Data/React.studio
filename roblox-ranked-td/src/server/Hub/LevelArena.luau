-- Zones de combat des NIVEAUX (règles et chiffres : Shared/Levels.luau).
-- Une zone par joueur, dans le même serveur que la map principale, très loin de la place (Levels.arenaCFrame) :
-- pas de téléportation, donc pas d'écran de chargement. Le dossier workspace.Arenas.Arena<n> existe dès le départ
-- (vide) ; la carte du niveau n'y est construite que pendant qu'un niveau tourne (« Map »), puis effacée : six
-- cartes vides ne coûtent rien, et jamais dix cartes chargées en même temps.
-- Le dossier de la zone porte les attributs lus par les clients : Slot, PlotIndex (numéro pour l'affichage, comme
-- une parcelle de plus), Map (nom de la carte, absent = zone vide), puis ceux du niveau en cours (LevelGame).
-- Une carte d'équipe (plusieurs couloirs : Shared/TeamMaps.luau) a une porte par couloir, et le nom de chaque
-- joueur au-dessus de la porte du sien (setLaneNames, dans Map.LaneNames).
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

-- Décor de chaque territoire (palier = (niveau - 1) // 10) : couleurs et matières du sol, du terrain et du chemin,
-- feuillage des arbres (autumn = roux, foliage = sa couleur), forest = des arbres en plus (un vrai bois), noTrees =
-- aucun arbre, rochers, cactus, pierres tombales et mares de lave (leur couleur) posés autour du terrain. Le chemin
-- contraste avec les monstres du territoire (qu'on les voie bien).
local THEMES = {
	-- La vallée du Roi carmin : prairie verte.
	[0] = {
		ground = Color3.fromRGB(88, 116, 69),
		field = Color3.fromRGB(104, 136, 82),
		path = Color3.fromRGB(150, 138, 110),
		wall = Color3.fromRGB(139, 144, 128),
		banner = Color3.fromRGB(142, 48, 44),
		groundMaterial = Enum.Material.Grass,
	},
	-- Le col des Pillards de cuivre : terre sèche et rousse, rochers, arbres d'automne.
	[1] = {
		ground = Color3.fromRGB(121, 96, 66),
		field = Color3.fromRGB(150, 121, 80),
		path = Color3.fromRGB(196, 172, 128),
		wall = Color3.fromRGB(128, 106, 88),
		banner = Color3.fromRGB(198, 108, 40),
		groundMaterial = Enum.Material.Ground,
		autumn = true,
		rocks = Color3.fromRGB(133, 110, 92),
	},
	-- La forêt des Gardiens des ronces : sous-bois sombre, beaucoup d'arbres, rochers moussus ; chemin de terre claire
	-- (les Gardiens sont verts).
	[2] = {
		ground = Color3.fromRGB(58, 86, 52),
		field = Color3.fromRGB(80, 112, 64),
		path = Color3.fromRGB(176, 148, 104),
		wall = Color3.fromRGB(104, 118, 92),
		banner = Color3.fromRGB(52, 104, 57),
		groundMaterial = Enum.Material.Grass,
		foliage = Color3.fromRGB(42, 86, 50),
		forest = true,
		rocks = Color3.fromRGB(98, 112, 88),
	},
	-- Le glacier de la Légion du givre : neige, arbres enneigés, rochers bleutés ; chemin de glace sombre (la Légion
	-- est blanche et bleu clair).
	[3] = {
		ground = Color3.fromRGB(226, 233, 240),
		field = Color3.fromRGB(196, 210, 222),
		path = Color3.fromRGB(96, 110, 128),
		wall = Color3.fromRGB(176, 190, 204),
		banner = Color3.fromRGB(72, 162, 190),
		groundMaterial = Enum.Material.Snow,
		foliage = Color3.fromRGB(226, 236, 242),
		rocks = Color3.fromRGB(150, 164, 182),
	},
	-- Le désert des Gardes des dunes : sable, cactus, rochers de grès, pas un arbre ; chemin de terre brune et tassée
	-- (les Gardes sont couleur sable).
	[4] = {
		ground = Color3.fromRGB(214, 186, 132),
		field = Color3.fromRGB(226, 202, 150),
		path = Color3.fromRGB(112, 84, 60),
		wall = Color3.fromRGB(196, 168, 120),
		banner = Color3.fromRGB(176, 64, 40),
		groundMaterial = Enum.Material.Sand,
		noTrees = true,
		cacti = Color3.fromRGB(86, 128, 72),
		rocks = Color3.fromRGB(190, 150, 104),
	},
	-- La nécropole de la Légion des os : herbe morte et grise, arbres sombres, pierres tombales ; chemin d'ardoise
	-- sombre (la Légion est couleur os).
	[5] = {
		ground = Color3.fromRGB(66, 70, 62),
		field = Color3.fromRGB(92, 98, 84),
		path = Color3.fromRGB(56, 50, 64),
		wall = Color3.fromRGB(92, 88, 100),
		banner = Color3.fromRGB(106, 83, 134),
		groundMaterial = Enum.Material.Ground,
		foliage = Color3.fromRGB(68, 58, 78),
		graves = Color3.fromRGB(150, 146, 156),
		rocks = Color3.fromRGB(104, 100, 112),
	},
	-- La citadelle de la Garde de la tempête : plateau de pierre gris, arbres sombres battus par le vent ; chemin clair
	-- (la Garde est bleue).
	[6] = {
		ground = Color3.fromRGB(84, 94, 104),
		field = Color3.fromRGB(110, 120, 126),
		path = Color3.fromRGB(200, 188, 150),
		wall = Color3.fromRGB(126, 132, 146),
		banner = Color3.fromRGB(75, 91, 179),
		groundMaterial = Enum.Material.Slate,
		foliage = Color3.fromRGB(54, 84, 92),
		rocks = Color3.fromRGB(120, 128, 140),
	},
	-- Le volcan des Chevaliers d'obsidienne : basalte noir, mares de lave, pas un arbre ; chemin de cendre claire (les
	-- chevaliers sont noirs et orange).
	[7] = {
		ground = Color3.fromRGB(44, 40, 44),
		field = Color3.fromRGB(70, 64, 66),
		path = Color3.fromRGB(190, 172, 150),
		wall = Color3.fromRGB(60, 56, 62),
		banner = Color3.fromRGB(209, 75, 40),
		groundMaterial = Enum.Material.Basalt,
		noTrees = true,
		lava = Color3.fromRGB(255, 110, 30),
		rocks = Color3.fromRGB(56, 50, 56),
	},
	-- Les marais de la Horde gobeline : boue verte, bois épais ; chemin de boue sèche (les gobelins sont verts et
	-- bruns).
	[8] = {
		ground = Color3.fromRGB(60, 78, 48),
		field = Color3.fromRGB(82, 98, 60),
		path = Color3.fromRGB(178, 160, 118),
		wall = Color3.fromRGB(96, 100, 80),
		banner = Color3.fromRGB(130, 71, 41),
		groundMaterial = Enum.Material.Mud,
		foliage = Color3.fromRGB(64, 92, 46),
		forest = true,
		rocks = Color3.fromRGB(92, 100, 76),
	},
	-- Le repaire de la Couvée du dragon : terre brûlée et rougeâtre, arbres calcinés, mares de lave ; chemin d'os pâle
	-- (les dragons sont rouges).
	[9] = {
		ground = Color3.fromRGB(70, 44, 38),
		field = Color3.fromRGB(96, 62, 50),
		path = Color3.fromRGB(206, 186, 144),
		wall = Color3.fromRGB(92, 64, 56),
		banner = Color3.fromRGB(153, 46, 42),
		groundMaterial = Enum.Material.Ground,
		foliage = Color3.fromRGB(40, 34, 30),
		lava = Color3.fromRGB(255, 120, 40),
		rocks = Color3.fromRGB(82, 58, 52),
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
	scenery(folder, "Ground", Vector3.new(w + 260, 1, d + 260), origin * CFrame.new(0, -0.7, 0), theme.ground, theme.groundMaterial)
	scenery(folder, "Field", Vector3.new(w, 1, d), origin * CFrame.new(0, -0.5, 0), theme.field, theme.groundMaterial)

	-- Chemin des monstres : tous les couloirs de la carte (un seul pour une carte seule ; ceux d'une carte d'équipe
	-- se rejoignent avant le château), chaque dalle une seule fois.
	for _, slab in RoadGeometry.network(map.lanes, Levels.PATH_WIDTH) do
		scenery(folder, "Path", slab.size, origin * CFrame.new(slab.center + Vector3.new(0, 0.05, 0)), theme.path, Enum.Material.SmoothPlastic)
	end

	-- Une porte d'invasion à l'entrée de chaque couloir, en travers du chemin : sur le bord gauche pour une carte
	-- seule ; aussi en haut, en bas ou à droite sur une carte d'équipe. openings = où le muret s'ouvre, par côté.
	local openings = { Left = {}, Right = {}, Top = {}, Bottom = {} }
	for _, lane in map.lanes do
		local entry = lane[1]
		local inward = (lane[2] - lane[1]).Unit
		-- Repère de la porte : +X = vers l'intérieur du terrain (le long du chemin), Z = en travers.
		local gate = origin * CFrame.new(entry) * CFrame.Angles(0, math.atan2(-inward.Z, inward.X), 0)
		for _, side in { -1, 1 } do
			local post = gate * CFrame.new(-1.5, 0, side * (Levels.PATH_WIDTH / 2 + 1.2))
			scenery(folder, "GateTower", Vector3.new(2.4, 7, 2.4), post * CFrame.new(0, 3.5, 0), Color3.fromRGB(78, 75, 69), Enum.Material.Brick)
			scenery(folder, "GateCoping", Vector3.new(3.1, 0.5, 3.1), post * CFrame.new(0, 7.25, 0), Color3.fromRGB(185, 177, 153), Enum.Material.Limestone)
		end
		scenery(folder, "GateLintel", Vector3.new(2.2, 1.5, Levels.PATH_WIDTH + 4.8), gate * CFrame.new(-1.5, 7, 0), Color3.fromRGB(70, 67, 62), Enum.Material.Brick)
		if math.abs(entry.X + w / 2) < 0.01 then
			table.insert(openings.Left, entry.Z)
		elseif math.abs(entry.X - w / 2) < 0.01 then
			table.insert(openings.Right, entry.Z)
		elseif math.abs(entry.Z + d / 2) < 0.01 then
			table.insert(openings.Top, entry.X)
		else
			table.insert(openings.Bottom, entry.X)
		end
	end

	-- Château à défendre, au bout du chemin.
	local keep = origin * CFrame.new(map.base)
	scenery(folder, "Base", Vector3.new(7, 6, 7), keep * CFrame.new(0, 3, 0), Color3.fromRGB(103, 98, 88), Enum.Material.Brick)
	for _, offset in { Vector3.new(-3.3, 3.8, -3.3), Vector3.new(3.3, 3.8, -3.3), Vector3.new(-3.3, 3.8, 3.3), Vector3.new(3.3, 3.8, 3.3) } do
		scenery(folder, "CastleTurret", Vector3.new(7.6, 2, 2), keep * CFrame.new(offset) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(88, 84, 76), Enum.Material.Cobblestone).Shape = Enum.PartType.Cylinder
	end
	MedievalModels.banner(folder, keep * CFrame.new(0, 6, 0), theme.banner, 1.3)

	-- Muret autour du terrain (bas : il ne cache rien vu d'en haut), piliers aux coins. Il s'ouvre devant chaque
	-- porte d'invasion.
	local gateHalf = Levels.PATH_WIDTH / 2 + 2.4
	for _, sideName in { "Left", "Right", "Top", "Bottom" } do
		local vertical = sideName == "Left" or sideName == "Right"
		local half = (if vertical then d else w) / 2 + 1
		local cuts = table.clone(openings[sideName])
		table.sort(cuts)
		local from = -half
		for index = 1, #cuts + 1 do
			local to = if index <= #cuts then cuts[index] - gateHalf else half
			if to - from > 0.5 then
				local middle = (from + to) / 2
				local at = if sideName == "Left"
					then Vector3.new(-w / 2 - 0.5, 0.55, middle)
					elseif sideName == "Right" then Vector3.new(w / 2 + 0.5, 0.55, middle)
					elseif sideName == "Top" then Vector3.new(middle, 0.55, -d / 2 - 0.5)
					else Vector3.new(middle, 0.55, d / 2 + 0.5)
				local size = if vertical then Vector3.new(0.9, 1.1, to - from) else Vector3.new(to - from, 1.1, 0.9)
				scenery(folder, "BoundaryWall", size, origin * CFrame.new(at), theme.wall, Enum.Material.Cobblestone)
			end
			if index <= #cuts then
				from = cuts[index] + gateHalf
			end
		end
	end
	for _, side in { -1, 1 } do
		for _, depthSide in { -1, 1 } do
			scenery(folder, "BoundaryPillar", Vector3.new(1.8, 2.4, 1.8), origin * CFrame.new(side * (w / 2 + 0.5), 1.2, depthSide * (d / 2 + 0.5)), theme.wall, Enum.Material.Cobblestone)
		end
	end
	-- Carte d'équipe : rien de haut dehors juste devant une porte (on doit voir d'où sortent les monstres). Les cartes
	-- seules gardent leur décor d'avant.
	local teamMap = #map.lanes > 1
	local function clearOfGates(x: number, z: number): boolean
		if not teamMap then
			return true
		end
		for _, gateX in openings.Top do
			if z < -d / 2 and math.abs(x - gateX) < 9 then
				return false
			end
		end
		for _, gateX in openings.Bottom do
			if z > d / 2 and math.abs(x - gateX) < 9 then
				return false
			end
		end
		for _, gateZ in openings.Left do
			if x < -w / 2 and math.abs(z - gateZ) < 9 then
				return false
			end
		end
		for _, gateZ in openings.Right do
			if x > w / 2 and math.abs(z - gateZ) < 9 then
				return false
			end
		end
		return true
	end
	-- Quelques arbres, seulement au fond et sur les côtés (devant, ils cacheraient le terrain à la caméra).
	for i = 0, (if theme.noTrees then -1 else 6) do
		local x, z = -w / 2 + 6 + i * (w - 12) / 6, -d / 2 - 12 - (i % 2) * 6
		if clearOfGates(x, z) then
			MedievalModels.tree(folder, origin * CFrame.new(x, 0, z), 1.1 + (i % 3) * 0.15, theme.foliage or theme.autumn or i % 4 == 1)
		end
	end
	for _, side in (if theme.noTrees then {} else { -1, 1 }) do
		if clearOfGates(side * (w / 2 + 14), -6) then
			MedievalModels.tree(folder, origin * CFrame.new(side * (w / 2 + 14), 0, -6), 1.2, theme.foliage or theme.autumn == true)
		end
	end
	-- Un vrai bois : une deuxième rangée d'arbres derrière la première, et d'autres sur les côtés (vers le fond).
	if theme.forest then
		for i = 0, 7 do
			local x, z = -w / 2 - 4 + i * (w + 8) / 7, -d / 2 - 24 - (i % 3) * 4
			if clearOfGates(x, z) then
				MedievalModels.tree(folder, origin * CFrame.new(x, 0, z), 1.25 + (i % 2) * 0.2, theme.foliage:Lerp(Color3.new(0, 0, 0), (i % 3) * 0.1))
			end
		end
		for _, side in { -1, 1 } do
			for i = 0, 2 do
				local x, z = side * (w / 2 + 12 + i * 7), -d / 2 + 4 + i * 9
				if clearOfGates(x, z) then
					MedievalModels.tree(folder, origin * CFrame.new(x, 0, z), 1.1 + i * 0.1, theme.foliage)
				end
			end
		end
	end
	-- Rochers autour du terrain (jamais dessus), au fond et sur les côtés.
	if theme.rocks then
		for i = 0, 9 do
			local size = 3 + (i * 7 % 5)
			local x = -w / 2 - 4 + i * (w + 8) / 9
			local z = -d / 2 - 5 - (i * 3 % 4) * 1.5
			if not clearOfGates(x, z) then
				continue
			end
			local rock = scenery(folder, "Rock", Vector3.new(size * 1.3, size, size * 1.1), origin * CFrame.new(x, size * 0.3, z) * CFrame.Angles(0, i * 0.9, 0.2), theme.rocks:Lerp(Color3.new(0, 0, 0), (i % 3) * 0.08), Enum.Material.Slate)
			rock.Shape = Enum.PartType.Ball
		end
		for _, side in { -1, 1 } do
			for i = 0, 2 do
				local size = 3.5 + i
				if not clearOfGates(side * (w / 2 + 6 + i * 2), -d / 2 + 10 + i * 13) then
					continue
				end
				local rock = scenery(folder, "Rock", Vector3.new(size * 1.2, size, size), origin * CFrame.new(side * (w / 2 + 6 + i * 2), size * 0.3, -d / 2 + 10 + i * 13) * CFrame.Angles(0, i * 1.3, 0.15), theme.rocks, Enum.Material.Slate)
				rock.Shape = Enum.PartType.Ball
			end
		end
	end

	-- Cactus (désert) : un tronc et deux bras, en blocs comme le reste du décor ; au fond et sur les côtés.
	if theme.cacti then
		local function cactus(cf: CFrame, scale: number)
			local color = theme.cacti
			scenery(folder, "Cactus", Vector3.new(1.6, 7, 1.6) * scale, cf * CFrame.new(0, 3.5 * scale, 0), color, Enum.Material.Grass)
			for _, arm in { { -1, 3.2, 2.2 }, { 1, 4.2, 1.8 } } do
				local side, height, length = arm[1], arm[2], arm[3]
				scenery(folder, "Cactus", Vector3.new(1.4, 0.9, 0.9) * scale, cf * CFrame.new(side * 1.3 * scale, height * scale, 0), color, Enum.Material.Grass)
				scenery(folder, "Cactus", Vector3.new(0.9, length, 0.9) * scale, cf * CFrame.new(side * 1.9 * scale, (height + length / 2 - 0.2) * scale, 0), color:Lerp(Color3.new(0, 0, 0), 0.08), Enum.Material.Grass)
			end
		end
		for i = 0, 6 do
			local x, z = -w / 2 + 4 + i * (w - 8) / 6, -d / 2 - 10 - (i % 3) * 5
			if clearOfGates(x, z) then
				cactus(origin * CFrame.new(x, 0, z) * CFrame.Angles(0, i * 0.8, 0), 1.1 + (i % 2) * 0.25)
			end
		end
		for _, side in { -1, 1 } do
			for i = 0, 1 do
				local x, z = side * (w / 2 + 9 + i * 8), -d / 2 + 6 + i * 14
				if clearOfGates(x, z) then
					cactus(origin * CFrame.new(x, 0, z) * CFrame.Angles(0, i * 1.1, 0), 1)
				end
			end
		end
	end
	-- Pierres tombales (nécropole) : une dalle et son chapeau, un peu penchées ; au fond et sur les côtés.
	if theme.graves then
		for i = 0, 9 do
			local x = -w / 2 + 2 + i * (w - 4) / 9
			local z = -d / 2 - 5 - (i % 3) * 2.5
			if not clearOfGates(x, z) then
				continue
			end
			local cf = origin * CFrame.new(x, 0, z) * CFrame.Angles(0, (i % 4 - 1.5) * 0.15, (i % 3 - 1) * 0.12)
			scenery(folder, "Grave", Vector3.new(2.2, 2.8, 0.6), cf * CFrame.new(0, 1.4, 0), theme.graves:Lerp(Color3.new(0, 0, 0), (i % 3) * 0.1), Enum.Material.Slate)
			scenery(folder, "Grave", Vector3.new(1.5, 0.5, 0.7), cf * CFrame.new(0, 3, 0), theme.graves, Enum.Material.Slate)
		end
		for _, side in { -1, 1 } do
			for i = 0, 2 do
				if not clearOfGates(side * (w / 2 + 5 + i * 3), -d / 2 + 6 + i * 12) then
					continue
				end
				local cf = origin * CFrame.new(side * (w / 2 + 5 + i * 3), 0, -d / 2 + 6 + i * 12) * CFrame.Angles(0, math.pi / 2 + i * 0.2, side * 0.1)
				scenery(folder, "Grave", Vector3.new(2.2, 2.8, 0.6), cf * CFrame.new(0, 1.4, 0), theme.graves, Enum.Material.Slate)
			end
		end
	end
	-- Mares de lave (volcan, repaire du dragon) : plates et lumineuses, au fond et sur les côtés.
	if theme.lava then
		for i = 0, 5 do
			local size = 6 + (i * 5 % 4) * 2
			local x = -w / 2 + 8 + i * (w - 16) / 5
			local z = -d / 2 - 9 - (i % 2) * 6
			scenery(folder, "Lava", Vector3.new(size * 1.4, 0.2, size), origin * CFrame.new(x, -0.15, z) * CFrame.Angles(0, i * 0.7, 0), theme.lava, Enum.Material.Neon)
		end
		for _, side in { -1, 1 } do
			scenery(folder, "Lava", Vector3.new(7, 0.2, 10), origin * CFrame.new(side * (w / 2 + 9), -0.15, -d / 2 + 14) * CFrame.Angles(0, side * 0.4, 0), theme.lava, Enum.Material.Neon)
		end
	end

	folder.Parent = arena.folder
	arena.map = mapName
	arena.palier = palier
	arena.folder:SetAttribute("Map", mapName)
	return arena
end

-- Nom de chaque joueur au-dessus de la porte de SON couloir (carte d'équipe : le joueur n défend le couloir n).
-- names = { nom du joueur 1, nom du joueur 2... } ; vide = aucun nom (partie seule). Refait à chaque niveau lancé :
-- la carte peut rester d'un niveau à l'autre, pas forcément l'équipe.
function LevelArena.setLaneNames(slot: number, names: { string })
	local arena = arenas[slot]
	local mapFolder = arena and arena.folder:FindFirstChild("Map")
	if not mapFolder then
		return
	end
	local old = mapFolder:FindFirstChild("LaneNames")
	if old then
		old:Destroy()
	end
	local map = Levels.MAPS[arena.map]
	if #names == 0 or not map or #map.lanes < 2 then
		return
	end
	local holder = Instance.new("Folder")
	holder.Name = "LaneNames"
	for index, lane in map.lanes do
		local name = names[index]
		if not name then
			continue
		end
		-- Point invisible juste après la porte (dans le terrain, pas trop haut : la caméra cadre le terrain), et le nom
		-- dessus, toujours lisible.
		local inward = (lane[2] - lane[1]).Unit
		local anchor = scenery(holder, "Lane" .. index, Vector3.one, arena.cframe * CFrame.new(lane[1] + inward * 5 + Vector3.new(0, 8, 0)), Color3.new(1, 1, 1))
		anchor.Transparency = 1
		anchor.CastShadow = false
		anchor:SetAttribute("Lane", index)
		local gui = Instance.new("BillboardGui")
		gui.Name = "Sign"
		gui.Size = UDim2.fromOffset(150, 30)
		gui.AlwaysOnTop = true
		gui.LightInfluence = 0
		gui.MaxDistance = 500
		gui:SetAttribute("NoTranslate", true) -- un nom de joueur ne se traduit pas (AutoTranslate.luau)
		gui.Parent = anchor
		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = Color3.fromRGB(28, 26, 24)
		label.BackgroundTransparency = 0.25
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Text = name
		label.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = label
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 6)
		padding.PaddingRight = UDim.new(0, 6)
		padding.PaddingTop = UDim.new(0, 3)
		padding.PaddingBottom = UDim.new(0, 3)
		padding.Parent = label
	end
	holder.Parent = mapFolder
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

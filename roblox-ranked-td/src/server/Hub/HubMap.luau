-- Construit la map principale : la place centrale et 6 parcelles. Chaque parcelle est le camp d'entraînement de son
-- joueur (Hub/Camp.luau) : 3 socles d'entraînement, un chemin où roulent les cibles, et devant l'entrée la boutique
-- des tours et la porte des niveaux.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local PlotLayout = require(Shared.PlotLayout)
local ProximityLabel = require(Shared.ProximityLabel)
local MedievalModels = require(Shared.MedievalModels)
local RoadGeometry = require(Shared.RoadGeometry)
local PlotBoard = require(script.Parent.PlotBoard)
local PlotIdentity = require(script.Parent.PlotIdentity)
local scenery = MedievalModels.sceneryPart

local HubMap = {}

HubMap.PLOT_COLORS = {
	Color3.fromRGB(52, 92, 145),
	Color3.fromRGB(142, 48, 44),
	Color3.fromRGB(55, 112, 67),
	Color3.fromRGB(176, 126, 42),
	Color3.fromRGB(102, 62, 129),
	Color3.fromRGB(43, 116, 119),
}

-- Socle d'entraînement d'une parcelle sans camp (Hub/Camp.luau change son aspect selon l'emplacement du joueur).
HubMap.PAD_COLOR = Color3.fromRGB(118, 111, 96)

-- Les deux bâtiments devant l'entrée de chaque parcelle. tab = onglet de la fenêtre du joueur que leur invite ouvre.
HubMap.BUILDINGS = {
	{ key = "Shop", x = -20, title = "BOUTIQUE DES TOURS", tab = "Boutique", color = Color3.fromRGB(118, 73, 145) },
	{ key = "Levels", x = 20, title = "PORTE DES NIVEAUX", tab = "Niveaux", color = Color3.fromRGB(205, 151, 52) },
}

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	return p
end

local function billboard(adornee: BasePart, text: string, offset: Vector3, size: UDim2, color: Color3?, maxDistance: number?)
	local gui = Instance.new("BillboardGui")
	gui.Size = size
	gui.StudsOffsetWorldSpace = offset
	ProximityLabel.register(gui, maxDistance or Config.LabelDistance.Medium)
	gui.Parent = adornee
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Antique
	label.TextScaled = true
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = text
	label.Parent = gui
	return label
end

local function torch(parent: Instance, cframe: CFrame)
	part({ Name = "Torch", Size = Vector3.new(0.35, 3.2, 0.35), CFrame = cframe, Color = Color3.fromRGB(83, 53, 31), Material = Enum.Material.Wood, CanCollide = false, Parent = parent })
	local flame = part({ Name = "Flame", Shape = Enum.PartType.Ball, Size = Vector3.new(0.8, 1.15, 0.8), CFrame = cframe * CFrame.new(0, 2, 0), Color = Color3.fromRGB(255, 146, 42), Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, Parent = parent })
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 161, 72)
	light.Brightness = 2
	light.Range = 18
	light.Shadows = false
	light.Parent = flame
end

local function buildPlot(index: number, parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Plot" .. index
	folder:SetAttribute("PlotIndex", index)
	folder.Parent = parent

	local color = HubMap.PLOT_COLORS[index]
	local origin = PlotLayout.cframe(index)
	local w, l = PlotLayout.WIDTH, PlotLayout.LENGTH
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = folder

	part({
		Name = "Floor",
		Size = Vector3.new(w, 1, l),
		CFrame = origin * CFrame.new(0, -0.5, 0),
		Color = Color3.fromRGB(96, 126, 76),
		Material = Enum.Material.Grass,
		Parent = folder,
	})

	-- Bordure colorée (couleur du propriétaire)
	for _, border in {
		{ Vector3.new(w / 2, 0.3, 0), Vector3.new(1, 0.6, l) },
		{ Vector3.new(-w / 2, 0.3, 0), Vector3.new(1, 0.6, l) },
		{ Vector3.new(0, 0.3, l / 2), Vector3.new(w + 1, 0.6, 1) },
	} do
		part({
			Name = "Border",
			Size = border[2],
			CFrame = origin * CFrame.new(border[1]),
			Color = Color3.fromRGB(86, 82, 73):Lerp(color, 0.2),
			Material = Enum.Material.Cobblestone,
			CanQuery = false,
			Parent = folder,
		})
	end

	-- Chemin des cibles d'entraînement
	local path = PlotLayout.PATH
	for _, slab in RoadGeometry.rectangles(path, PlotLayout.PATH_WIDTH) do
		part({
			Name = "Path",
			Size = slab.size,
			CFrame = origin * CFrame.new(slab.center + Vector3.new(0, 0.05, 0)),
			Color = Color3.fromRGB(119, 109, 91),
			Material = Enum.Material.SmoothPlastic, -- mat, sans petits pavés qui scintillent à distance
			Parent = folder,
		})
	end

	-- Panneau du camp au fond de la parcelle, à droite de la porte par où sortent les cibles. Hors du chemin (z=50).
	local boardFrame = origin * CFrame.new(5, 10, 62)
	local board = part({ Name = "FiefBoard", Size = Vector3.new(28, 15, 0.7), CFrame = boardFrame,
		Color = Color3.fromRGB(43, 53, 48), Material = Enum.Material.Wood,
		CanCollide = false, CanTouch = false, CanQuery = false, Parent = decor })
	for _, side in { -1, 1 } do
		scenery(decor, "BoardPost", Vector3.new(1.25, 18, 1.4), origin * CFrame.new(5 + side * 14.7, 9, 62.3), Color3.fromRGB(98, 67, 41), Enum.Material.Wood)
		scenery(decor, "BoardFoot", Vector3.new(2.2, 1.2, 2.2), origin * CFrame.new(5 + side * 14.7, 0.6, 62.3), Color3.fromRGB(154, 151, 131), Enum.Material.Limestone)
		scenery(decor, "BoardSideTrim", Vector3.new(0.22, 15.5, 0.35), boardFrame * CFrame.new(side * 14.12, 0, -0.3), Color3.fromRGB(205, 170, 99), Enum.Material.Metal)
	end
	for _, y in { -7.7, 7.7 } do
		scenery(decor, "BoardHorizontalTrim", Vector3.new(28.5, 0.3, 0.4), boardFrame * CFrame.new(0, y, -0.3), Color3.fromRGB(205, 170, 99), Enum.Material.Metal)
	end
	MedievalModels.roof(decor, origin * CFrame.new(5, 18, 62.3), 32, 4, 2.5, Color3.fromRGB(43, 82, 94))
	PlotBoard.attach(folder, board)

	part({
		Name = "EnemySpawn",
		Size = Vector3.new(PlotLayout.PATH_WIDTH + 2, 6, 1),
		CFrame = PlotLayout.worldCFrame(index, path[1] + Vector3.new(0, 3, 2)),
		Color = Color3.fromRGB(74, 28, 27),
		Material = Enum.Material.Brick,
		Transparency = 0.72,
		CanCollide = false,
		CanQuery = false,
		Parent = folder,
	})
	-- Porte en pierre par où sortent les cibles.
	for _, x in { -PlotLayout.PATH_WIDTH / 2 - 1, PlotLayout.PATH_WIDTH / 2 + 1 } do
		part({ Name = "GateTower", Size = Vector3.new(2.4, 7, 2.4), CFrame = PlotLayout.worldCFrame(index, path[1] + Vector3.new(x, 3.5, 2)), Color = Color3.fromRGB(78, 75, 69), Material = Enum.Material.Brick, Parent = folder })
	end
	part({ Name = "GateLintel", Size = Vector3.new(PlotLayout.PATH_WIDTH + 4.5, 1.5, 2.2), CFrame = PlotLayout.worldCFrame(index, path[1] + Vector3.new(0, 7, 2)), Color = Color3.fromRGB(70, 67, 62), Material = Enum.Material.Brick, Parent = folder })
	for _, x in { -PlotLayout.PATH_WIDTH / 2 - 1, PlotLayout.PATH_WIDTH / 2 + 1 } do
		local gate = origin * CFrame.new(path[1] + Vector3.new(x, 0, 2))
		scenery(decor, "GateCoping", Vector3.new(3.1, 0.5, 3.1), gate * CFrame.new(0, 7.9, 0), Color3.fromRGB(185, 177, 153), Enum.Material.Limestone)
		MedievalModels.roof(decor, gate * CFrame.new(0, 8.15, 0), 3.5, 3.5, 2.6, Color3.fromRGB(43, 82, 94))
	end
	-- Bordures basses : placées en marge, hors des socles et du chemin.
	for _, side in { -1, 1 } do
		for z = -42, 58, 20 do
			local at = origin * CFrame.new(side * (w / 2 - 1), 0, z)
			scenery(decor, "BoundaryPillar", Vector3.new(1.8, 3.4, 1.8), at * CFrame.new(0, 1.7, 0), Color3.fromRGB(139, 144, 128), Enum.Material.Cobblestone)
			scenery(decor, "PillarCap", Vector3.new(2.2, 0.35, 2.2), at * CFrame.new(0, 3.55, 0), Color3.fromRGB(191, 181, 150), Enum.Material.Limestone)
		end
		for z = -32, 48, 20 do
			scenery(decor, "BoundaryWall", Vector3.new(0.9, 1.3, 18.2), origin * CFrame.new(side * (w / 2 - 1), 0.65, z), Color3.fromRGB(135, 140, 124), Enum.Material.Cobblestone)
		end
	end

	part({
		Name = "Base",
		Size = Vector3.new(9, 7, 9),
		CFrame = PlotLayout.worldCFrame(index, PlotLayout.BASE_POSITION + Vector3.new(0, 3.5, 0)),
		Color = Color3.fromRGB(103, 98, 88),
		Material = Enum.Material.Brick,
		CanQuery = false,
		Parent = folder,
	})
	-- Petit donjon avec quatre tours et une bannière aux couleurs du joueur.
	for _, offset in { Vector3.new(-4.2, 4.4, -4.2), Vector3.new(4.2, 4.4, -4.2), Vector3.new(-4.2, 4.4, 4.2), Vector3.new(4.2, 4.4, 4.2) } do
		part({ Name = "CastleTurret", Shape = Enum.PartType.Cylinder, Size = Vector3.new(8.8, 2.2, 2.2), CFrame = PlotLayout.worldCFrame(index, PlotLayout.BASE_POSITION + offset) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(88, 84, 76), Material = Enum.Material.Cobblestone, Parent = folder })
	end
	part({ Name = "BannerPole", Size = Vector3.new(0.25, 8, 0.25), CFrame = PlotLayout.worldCFrame(index, PlotLayout.BASE_POSITION + Vector3.new(0, 10, 0)), Color = Color3.fromRGB(73, 50, 31), Material = Enum.Material.Wood, CanCollide = false, Parent = folder })
	part({ Name = "Banner", Size = Vector3.new(0.16, 3.2, 3.8), CFrame = PlotLayout.worldCFrame(index, PlotLayout.BASE_POSITION + Vector3.new(0, 11.5, -1.8)), Color = color, Material = Enum.Material.Fabric, CanCollide = false, Parent = folder })
	MedievalModels.keepDetails(decor, origin * CFrame.new(PlotLayout.BASE_POSITION), color, 4.2)

	-- Socles d'entraînement (PlotLayout.SPOTS), surélevés de PlotLayout.SPOT_PAD_HEIGHT
	local spots = Instance.new("Folder")
	spots.Name = "Spots"
	spots.Parent = folder
	local padHeight = PlotLayout.SPOT_PAD_HEIGHT
	for spotIndex, localPosition in PlotLayout.SPOTS do
		local pad = part({
			Name = "Spot" .. spotIndex,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(padHeight, 5, 5),
			CFrame = PlotLayout.worldCFrame(index, localPosition + Vector3.new(0, padHeight / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = HubMap.PAD_COLOR,
			Material = Enum.Material.Cobblestone,
			Parent = spots,
		})
		pad:SetAttribute("SpotIndex", spotIndex)
		pad:SetAttribute("PlotIndex", index)
	end

	-- Panneau à l'entrée avec le nom du propriétaire
	local post = part({
		Name = "Sign",
		Size = Vector3.new(1, 6, 1),
		CFrame = PlotLayout.worldCFrame(index, Vector3.new(0, 3, -l / 2 - 2)),
		Color = Color3.fromRGB(90, 70, 50),
		Material = Enum.Material.Wood,
		Parent = folder,
	})
	-- Le support Sign est réutilisé : vraie plaque en bois plutôt qu'un petit texte flottant.
	local entranceFrame = post.CFrame * CFrame.new(0, 5.2, 0)
	local plaque = part({ Name = "OwnerBoard", Size = Vector3.new(18, 7, 0.65), CFrame = entranceFrame,
		Color = Color3.fromRGB(69, 49, 34), Material = Enum.Material.WoodPlanks,
		CanCollide = false, CanTouch = false, CanQuery = false, Parent = decor })
	for _, side in { -1, 1 } do
		scenery(decor, "OwnerBoardTrim", Vector3.new(0.25, 7.35, 0.9), entranceFrame * CFrame.new(side * 9.12, 0, 0), Color3.fromRGB(205, 170, 99), Enum.Material.Metal)
	end
	for _, y in { -3.65, 3.65 } do
		scenery(decor, "OwnerBoardTrim", Vector3.new(18.5, 0.25, 0.9), entranceFrame * CFrame.new(0, y, 0), Color3.fromRGB(205, 170, 99), Enum.Material.Metal)
	end
	local ownerLabel = PlotIdentity.attach(folder, plaque, index, color)

	-- Deux bâtiments devant l'entrée : leur invite ouvre l'onglet de ce nom dans la fenêtre du joueur (attribut
	-- CampTab, lu par client/LevelsUI.luau ; seulement sur SA parcelle).
	local buildings = {}
	for _, info in HubMap.BUILDINGS do
		local cabinet = part({
			Name = info.key .. "Building",
			Size = Vector3.new(5, 7, 3),
			CFrame = PlotLayout.worldCFrame(index, Vector3.new(info.x, 3.5, -l / 2 - 8)) * CFrame.Angles(0, math.rad(180), 0),
			Color = Color3.fromRGB(83, 79, 72):Lerp(info.color, 0.18),
			Material = Enum.Material.Brick,
			Parent = folder,
		})
		part({
			Name = "Screen",
			Size = Vector3.new(3.8, 2.6, 0.2),
			CFrame = cabinet.CFrame * CFrame.new(0, 1.2, -1.55),
			Color = info.color,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
			Parent = folder,
		})
		local facade = cabinet.CFrame
		MedievalModels.roof(decor, facade * CFrame.new(0, 3.5, 0), 6.4, 4.6, 2.4, info.color:Lerp(Color3.fromRGB(35, 48, 57), 0.65))
		for _, x in { -2.35, 2.35 } do
			scenery(decor, "BuildingPillar", Vector3.new(0.55, 7.4, 0.55), facade * CFrame.new(x, 0, -1.6), Color3.fromRGB(175, 165, 136), Enum.Material.Limestone)
		end
		scenery(decor, "BuildingLintel", Vector3.new(5.6, 0.45, 0.65), facade * CFrame.new(0, 3.2, -1.6), Color3.fromRGB(208, 172, 90), Enum.Material.Metal)
		scenery(decor, "BuildingSigil", Vector3.new(1, 1, 0.22), facade * CFrame.new(0, 1.2, -1.75) * CFrame.Angles(0, 0, math.pi / 4), Color3.fromRGB(242, 211, 132), Enum.Material.Metal)
		billboard(cabinet, info.title, Vector3.new(0, 4.8, 0), UDim2.fromOffset(130, 20), info.color, Config.LabelDistance.Close)
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Ouvrir"
		prompt.ObjectText = info.title
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("CampTab", info.tab)
		prompt.Parent = cabinet
		buildings[info.key] = prompt
		torch(folder, cabinet.CFrame * CFrame.new(if info.x < 0 then -3.3 else 3.3, 0.2, 0))
	end

	return {
		index = index,
		folder = folder,
		ownerLabel = ownerLabel,
		spots = spots,
		buildings = buildings,
	}
end

-- Socles d'une parcelle sans camp : tous visibles, en pierre claire.
function HubMap.resetPads(plot)
	for _, pad in plot.spots:GetChildren() do
		if pad:IsA("BasePart") then
			pad.Color = HubMap.PAD_COLOR
			pad.Transparency = 0
			pad.CanCollide = true
			pad.CanQuery = true
		end
	end
end

function HubMap.build()
	Lighting.ClockTime = 15.4
	Lighting.Brightness = 2.7
	Lighting.Ambient = Color3.fromRGB(111, 119, 132)
	Lighting.OutdoorAmbient = Color3.fromRGB(149, 155, 155)
	Lighting.EnvironmentDiffuseScale = 0.65
	Lighting.EnvironmentSpecularScale = 0.35
	Lighting.ShadowSoftness = 0.35
	local atmosphere = Lighting:FindFirstChild("KingdomAtmosphere") or Instance.new("Atmosphere")
	atmosphere.Name = "KingdomAtmosphere"
	atmosphere.Color = Color3.fromRGB(207, 224, 226)
	atmosphere.Decay = Color3.fromRGB(118, 143, 151)
	atmosphere.Density = 0.27
	atmosphere.Haze = 1.3
	atmosphere.Parent = Lighting

	local hub = Instance.new("Folder")
	hub.Name = "Hub"

	part({
		Name = "Ground",
		Size = Vector3.new(950, 1, 950),
		Position = Vector3.new(0, -0.7, 0),
		Color = Color3.fromRGB(88, 116, 69),
		Material = Enum.Material.Grass,
		Parent = hub,
	})
	local decor = Instance.new("Folder")
	decor.Name = "KingdomDecor"
	decor.Parent = hub
	MedievalModels.landscape(decor, 228, 417)
	for i = 1, PlotLayout.COUNT do
		local angle = (i - 1) / PlotLayout.COUNT * math.pi * 2
		local road = CFrame.Angles(0, angle, 0)
		-- Départ après le bord de la place : plus de surfaces presque coplanaires à l'entrée.
		scenery(decor, "FiefRoad", Vector3.new(12, 0.2, 39), road * CFrame.new(0, 0.05, 55.5), Color3.fromRGB(160, 148, 119), Enum.Material.SmoothPlastic)
		for _, x in { -7, 7 } do
			scenery(decor, "RoadBorder", Vector3.new(0.7, 0.22, 39), road * CFrame.new(x, 0.06, 55.5), Color3.fromRGB(188, 179, 151), Enum.Material.Limestone)
		end
		local village = CFrame.Angles(0, angle + math.pi / 6, 0)
		local garden = village * CFrame.new(0, 0, 53)
		scenery(decor, "GardenBed", Vector3.new(11, 0.35, 10), garden * CFrame.new(0, 0.05, 0), Color3.fromRGB(90, 81, 60), Enum.Material.Ground)
		MedievalModels.tree(decor, garden, 1.05, false) -- même silhouette pour chaque secteur
		for _, side in { -1, 1 } do
			scenery(decor, "GardenKerb", Vector3.new(0.5, 0.65, 10.5), garden * CFrame.new(side * 5.5, 0.22, 0), Color3.fromRGB(188, 179, 151), Enum.Material.Limestone)
		end
		MedievalModels.cottage(decor, village * CFrame.new(-8, 0, 97), Color3.fromRGB(50, 87, 91))
		MedievalModels.cottage(decor, village * CFrame.new(8, 0, 115) * CFrame.Angles(0, -0.3, 0), Color3.fromRGB(122, 67, 48))
		for j = 1, 5 do
			MedievalModels.tree(decor, village * CFrame.new((if j % 2 == 0 then -1 else 1) * 14, 0, 127 + j * 15), 1.1 + j * 0.12, j == 2)
		end
		MedievalModels.banner(decor, village * CFrame.new(0, 0, 39), HubMap.PLOT_COLORS[i], 1.7)
	end

	-- Place centrale
	part({
		Name = "Plaza",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 70, 70),
		CFrame = CFrame.new(0, -0.1, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(169, 160, 137),
		Material = Enum.Material.Cobblestone,
		Parent = hub,
	})
	-- Bordure de pierre et bancs autour de la cour.
	for i = 1, 24 do
		local cf = CFrame.Angles(0, i / 24 * math.pi * 2, 0)
		scenery(decor, "CourtyardKerb", Vector3.new(8.8, 0.45, 1.3), cf * CFrame.new(0, 0.15, 35), Color3.fromRGB(202, 190, 156), Enum.Material.Limestone)
	end
	for _, x in { -23, 23 } do
		for _, z in { -8, 8 } do
			scenery(decor, "Bench", Vector3.new(2.2, 0.4, 7), CFrame.new(x, 1.6, z), Color3.fromRGB(117, 77, 45), Enum.Material.WoodPlanks)
			for _, dz in { -2.4, 2.4 } do
				scenery(decor, "BenchSupport", Vector3.new(1.5, 1.4, 0.6), CFrame.new(x, 0.7, z + dz), Color3.fromRGB(137, 139, 125), Enum.Material.Limestone)
			end
		end
	end

	-- Rosace décorative au milieu de la place, entourée de torches.
	part({
		Name = "PlazaRosette",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 18, 18),
		CFrame = CFrame.new(0, 0.12, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(202, 190, 156),
		Material = Enum.Material.Marble,
		CanCollide = false,
		CanQuery = false,
		Parent = hub,
	})
	part({
		Name = "PlazaRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.25, 20, 20),
		CFrame = CFrame.new(0, 0.08, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(205, 170, 99),
		Material = Enum.Material.Metal,
		CanCollide = false,
		CanQuery = false,
		Parent = hub,
	})
	for i = 1, 8 do
		local angle = (i - 1) / 8 * math.pi * 2
		local pos = Vector3.new(math.cos(angle) * 31, 1.6, math.sin(angle) * 31)
		torch(hub, CFrame.new(pos))
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = Vector3.new(0, 0.2, 45)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = hub

	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = hub

	local plots = {}
	for index = 1, PlotLayout.COUNT do
		plots[index] = buildPlot(index, plotsFolder)
	end

	hub.Parent = workspace
	return {
		plots = plots,
	}
end

return HubMap

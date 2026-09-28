-- Construit la map principale : place centrale (cercle ranked + classement) et 6 parcelles.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local NumberFormat = require(Shared.NumberFormat)
local PlotLayout = require(Shared.PlotLayout)
local ProximityLabel = require(Shared.ProximityLabel)
local MedievalModels = require(Shared.MedievalModels)
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

	-- Chemin des ennemis
	local path = PlotLayout.PATH
	for i = 2, #path do
		local a = PlotLayout.toWorld(index, path[i - 1])
		local b = PlotLayout.toWorld(index, path[i])
		part({
			Name = "Path",
			Size = Vector3.new(PlotLayout.PATH_WIDTH, 0.2, (b - a).Magnitude + PlotLayout.PATH_WIDTH),
			CFrame = CFrame.lookAt((a + b) / 2, b) + Vector3.new(0, 0.05, 0),
			Color = Color3.fromRGB(119, 109, 91),
			Material = Enum.Material.Cobblestone,
			Parent = folder,
		})
	end

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
	-- Porte d'invasion en pierre, lisible sans néon futuriste.
	for _, x in { -PlotLayout.PATH_WIDTH / 2 - 1, PlotLayout.PATH_WIDTH / 2 + 1 } do
		part({ Name = "GateTower", Size = Vector3.new(2.4, 7, 2.4), CFrame = PlotLayout.worldCFrame(index, path[1] + Vector3.new(x, 3.5, 2)), Color = Color3.fromRGB(78, 75, 69), Material = Enum.Material.Brick, Parent = folder })
	end
	part({ Name = "GateLintel", Size = Vector3.new(PlotLayout.PATH_WIDTH + 4.5, 1.5, 2.2), CFrame = PlotLayout.worldCFrame(index, path[1] + Vector3.new(0, 7, 2)), Color = Color3.fromRGB(70, 67, 62), Material = Enum.Material.Brick, Parent = folder })
	for _, x in { -PlotLayout.PATH_WIDTH / 2 - 1, PlotLayout.PATH_WIDTH / 2 + 1 } do
		local gate = origin * CFrame.new(path[1] + Vector3.new(x, 0, 2))
		scenery(decor, "GateCoping", Vector3.new(3.1, 0.5, 3.1), gate * CFrame.new(0, 7.9, 0), Color3.fromRGB(185, 177, 153), Enum.Material.Limestone)
		MedievalModels.roof(decor, gate * CFrame.new(0, 8.15, 0), 3.5, 3.5, 2.6, Color3.fromRGB(43, 82, 94))
	end
	-- Bordures basses : placées en marge, hors des emplacements et du chemin.
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

	-- Emplacements de tours
	local spots = Instance.new("Folder")
	spots.Name = "Spots"
	spots.Parent = folder
	for spotIndex, localPosition in PlotLayout.SPOTS do
		local pad = part({
			Name = "Spot" .. spotIndex,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3, 5, 5),
			CFrame = PlotLayout.worldCFrame(index, localPosition + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(118, 111, 96),
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
	local ownerLabel = billboard(post, "Fief libre", Vector3.new(0, 5, 0), UDim2.fromOffset(145, 26), color, Config.LabelDistance.Medium)

	-- Deux machines à sous devant l'entrée
	local machines = {}
	for _, info in {
		{ key = "Tower", x = -20, title = "AUTEL DES HÉROS", color = Color3.fromRGB(118, 73, 145) },
		{ key = "Bonus", x = 20, title = "FORGE RUNIQUE", color = Color3.fromRGB(205, 151, 52) },
	} do
		local cabinet = part({
			Name = info.key .. "Machine",
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
			scenery(decor, "MachinePillar", Vector3.new(0.55, 7.4, 0.55), facade * CFrame.new(x, 0, -1.6), Color3.fromRGB(175, 165, 136), Enum.Material.Limestone)
		end
		scenery(decor, "MachineLintel", Vector3.new(5.6, 0.45, 0.65), facade * CFrame.new(0, 3.2, -1.6), Color3.fromRGB(208, 172, 90), Enum.Material.Metal)
		scenery(decor, "MachineSigil", Vector3.new(1, 1, 0.22), facade * CFrame.new(0, 1.2, -1.75) * CFrame.Angles(0, 0, math.pi / 4), Color3.fromRGB(242, 211, 132), Enum.Material.Metal)
		billboard(cabinet, info.title, Vector3.new(0, 4.8, 0), UDim2.fromOffset(130, 20), info.color, Config.LabelDistance.Close)
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Ouvrir"
		prompt.ObjectText = info.title
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = cabinet
		machines[info.key] = prompt
		torch(folder, cabinet.CFrame * CFrame.new(if info.x < 0 then -3.3 else 3.3, 0.2, 0))
	end

	return {
		index = index,
		folder = folder,
		ownerLabel = ownerLabel,
		spots = spots,
		machines = machines,
	}
end

-- Met à jour l'apparence des emplacements : possédés (owned[tostring(spotIndex)] = true) ou verrouillés.
-- Tous les cadenas affichent le même prix, nextCost : le prix ne dépend que du nombre d'emplacements
-- déjà possédés, pas de celui qu'on choisit (à rappeler après chaque achat, le prix monte partout).
function HubMap.setOwnedSpots(plot, owned: { [string]: boolean }, nextCost: number?)
	local priceText = "🔒 " .. (if nextCost then NumberFormat.short(nextCost) else "")
	for _, pad in plot.spots:GetChildren() do
		local spotIndex = pad:GetAttribute("SpotIndex")
		local isUnlocked = owned[tostring(spotIndex)] == true
		pad.Color = if isUnlocked then Color3.fromRGB(132, 124, 106) else Color3.fromRGB(49, 47, 43)
		pad.Transparency = if isUnlocked then 0 else 0.35
		pad:SetAttribute("Unlocked", isUnlocked)
		local lock = pad:FindFirstChild("Lock")
		if isUnlocked then
			if lock then
				lock:Destroy()
			end
			continue
		end
		if not lock then
			lock = Instance.new("BillboardGui")
			lock.Name = "Lock"
			lock.Size = UDim2.fromOffset(96, 26)
			lock.StudsOffsetWorldSpace = Vector3.new(0, 1.5, 0)
			ProximityLabel.register(lock, Config.LabelDistance.Close)
			lock.Parent = pad
			local icon = Instance.new("TextLabel")
			icon.Name = "Price"
			icon.Size = UDim2.fromScale(1, 1)
			icon.BackgroundTransparency = 1
			icon.Font = Enum.Font.GothamBlack
			icon.TextScaled = true
			icon.TextColor3 = Color3.fromRGB(255, 205, 80)
			icon.TextStrokeTransparency = 0.3
			icon.Parent = lock
		end
		lock.Price.Text = priceText
	end
end

-- Emplacements d'une parcelle sans propriétaire : seulement ceux de départ, prix du 5e sur les cadenas.
function HubMap.resetSpots(plot)
	HubMap.setOwnedSpots(plot, PlotLayout.startingSpots(), PlotLayout.spotCost(PlotLayout.STARTING_SPOTS + 1))
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
		scenery(decor, "FiefRoad", Vector3.new(12, 0.16, 43), road * CFrame.new(0, 0.03, 53), Color3.fromRGB(160, 148, 119), Enum.Material.Cobblestone)
		for _, x in { -7, 7 } do
			scenery(decor, "RoadBorder", Vector3.new(0.7, 0.22, 43), road * CFrame.new(x, 0.06, 53), Color3.fromRGB(188, 179, 151), Enum.Material.Limestone)
		end
		local village = CFrame.Angles(0, angle + math.pi / 6, 0)
		local garden = village * CFrame.new(0, 0, 53)
		scenery(decor, "GardenBed", Vector3.new(11, 0.35, 10), garden * CFrame.new(0, 0.05, 0), Color3.fromRGB(90, 81, 60), Enum.Material.Ground)
		MedievalModels.tree(decor, garden, 1.05, i % 3 == 0)
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
	-- Rosace de pierre et bancs autour de la cour ; le sceau de duel reste libre.
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

	local radius = PlotLayout.RANKED_CIRCLE_RADIUS
	local circleCenter = PlotLayout.RANKED_CIRCLE_POSITION
	local circle = part({
		Name = "RankedCircle",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, radius * 2, radius * 2),
		CFrame = CFrame.new(circleCenter + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(117, 31, 34),
		Material = Enum.Material.Marble,
		Transparency = 0.06,
		CanCollide = false,
		Parent = hub,
	})
	part({
		Name = "RankedRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.25, radius * 2 + 2, radius * 2 + 2),
		CFrame = CFrame.new(circleCenter + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(255, 205, 80),
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

	local board = part({
		Name = "LeaderboardBoard",
		Size = Vector3.new(28, 20, 1),
		CFrame = CFrame.new(0, 11, -12),
		Color = Color3.fromRGB(56, 45, 37),
		Material = Enum.Material.WoodPlanks,
		Parent = hub,
	})
	for _, x in { -14.8, 14.8 } do
		scenery(decor, "HallColumn", Vector3.new(1.6, 22, 2.5), CFrame.new(x, 11, -12.3), Color3.fromRGB(159, 154, 136), Enum.Material.Limestone)
	end
	MedievalModels.roof(decor, CFrame.new(0, 22, -12.3), 33, 6, 5, Color3.fromRGB(43, 82, 94))
	scenery(decor, "HallPediment", Vector3.new(32, 0.6, 3), CFrame.new(0, 21.8, -12.3), Color3.fromRGB(199, 172, 114), Enum.Material.Metal)

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
		HubMap.resetSpots(plots[index])
	end

	hub.Parent = workspace
	return {
		board = board,
		plots = plots,
	}
end

return HubMap

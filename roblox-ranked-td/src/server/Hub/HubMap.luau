-- Construit la map principale : place centrale (cercle ranked + classement) et 6 parcelles.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NumberFormat = require(Shared.NumberFormat)
local PlotLayout = require(Shared.PlotLayout)

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
	gui.MaxDistance = maxDistance or 140
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
	light.Shadows = true
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

	part({
		Name = "Floor",
		Size = Vector3.new(w, 1, l),
		CFrame = origin * CFrame.new(0, -0.5, 0),
		Color = Color3.fromRGB(67, 94, 53),
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
	local ownerLabel = billboard(post, "Fief libre", Vector3.new(0, 5, 0), UDim2.fromOffset(145, 26), color, 72)

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
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = folder,
		})
		billboard(cabinet, info.title, Vector3.new(0, 4.8, 0), UDim2.fromOffset(130, 20), info.color, 48)
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

-- Met à jour l'apparence des emplacements selon le nombre débloqué.
function HubMap.setUnlockedSpots(plot, unlocked: number)
	for _, pad in plot.spots:GetChildren() do
		local spotIndex = pad:GetAttribute("SpotIndex")
		local isUnlocked = spotIndex <= unlocked
		pad.Color = if isUnlocked then Color3.fromRGB(132, 124, 106) else Color3.fromRGB(49, 47, 43)
		pad.Transparency = if isUnlocked then 0 else 0.35
		pad:SetAttribute("Unlocked", isUnlocked)
		local lock = pad:FindFirstChild("Lock")
		if isUnlocked and lock then
			lock:Destroy()
		elseif not isUnlocked and not lock then
			local gui = Instance.new("BillboardGui")
			gui.Name = "Lock"
			gui.Size = UDim2.fromOffset(96, 26)
			gui.StudsOffsetWorldSpace = Vector3.new(0, 1.5, 0)
			gui.MaxDistance = 60
			gui.Parent = pad
			local icon = Instance.new("TextLabel")
			icon.Size = UDim2.fromScale(1, 1)
			icon.BackgroundTransparency = 1
			icon.Font = Enum.Font.GothamBlack
			icon.TextScaled = true
			icon.TextColor3 = Color3.fromRGB(255, 205, 80)
			icon.TextStrokeTransparency = 0.3
			icon.Text = "🔒 " .. NumberFormat.short(PlotLayout.spotCost(spotIndex))
			icon.Parent = gui
		end
	end
end

function HubMap.build()
	Lighting.ClockTime = 17.35
	Lighting.Brightness = 2.2
	Lighting.Ambient = Color3.fromRGB(104, 91, 82)
	Lighting.OutdoorAmbient = Color3.fromRGB(132, 119, 102)
	Lighting.EnvironmentDiffuseScale = 0.35
	Lighting.EnvironmentSpecularScale = 0.45
	local atmosphere = Lighting:FindFirstChild("KingdomAtmosphere") or Instance.new("Atmosphere")
	atmosphere.Name = "KingdomAtmosphere"
	atmosphere.Color = Color3.fromRGB(219, 196, 164)
	atmosphere.Decay = Color3.fromRGB(104, 86, 77)
	atmosphere.Density = 0.22
	atmosphere.Haze = 1.25
	atmosphere.Parent = Lighting

	local hub = Instance.new("Folder")
	hub.Name = "Hub"

	part({
		Name = "Ground",
		Size = Vector3.new(480, 1, 480),
		Position = Vector3.new(0, -0.7, 0),
		Color = Color3.fromRGB(57, 74, 47),
		Material = Enum.Material.Grass,
		Parent = hub,
	})

	-- Place centrale
	part({
		Name = "Plaza",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 70, 70),
		CFrame = CFrame.new(0, -0.1, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(104, 99, 89),
		Material = Enum.Material.Cobblestone,
		Parent = hub,
	})

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
		HubMap.setUnlockedSpots(plots[index], PlotLayout.STARTING_SPOTS)
	end

	hub.Parent = workspace
	return {
		board = board,
		plots = plots,
	}
end

return HubMap

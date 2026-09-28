-- Construit la map principale : place centrale (cercle ranked + classement) et 6 parcelles.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NumberFormat = require(Shared.NumberFormat)
local PlotLayout = require(Shared.PlotLayout)

local HubMap = {}

HubMap.PLOT_COLORS = {
	Color3.fromRGB(90, 140, 255),
	Color3.fromRGB(255, 100, 90),
	Color3.fromRGB(80, 210, 120),
	Color3.fromRGB(245, 190, 60),
	Color3.fromRGB(190, 100, 255),
	Color3.fromRGB(80, 210, 220),
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

local function billboard(adornee: BasePart, text: string, offset: Vector3, size: UDim2, color: Color3?)
	local gui = Instance.new("BillboardGui")
	gui.Size = size
	gui.StudsOffsetWorldSpace = offset
	gui.MaxDistance = 250
	gui.Parent = adornee
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = text
	label.Parent = gui
	return label
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
		Color = Color3.fromRGB(70, 120, 60),
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
			Color = color,
			Material = Enum.Material.Neon,
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
			Color = Color3.fromRGB(150, 125, 90),
			Material = Enum.Material.Sand,
			Parent = folder,
		})
	end

	part({
		Name = "EnemySpawn",
		Size = Vector3.new(PlotLayout.PATH_WIDTH + 2, 6, 1),
		CFrame = PlotLayout.worldCFrame(index, path[1] + Vector3.new(0, 3, 2)),
		Color = Color3.fromRGB(120, 20, 30),
		Material = Enum.Material.Neon,
		Transparency = 0.3,
		CanCollide = false,
		CanQuery = false,
		Parent = folder,
	})

	part({
		Name = "Base",
		Size = Vector3.new(8, 6, 8),
		CFrame = PlotLayout.worldCFrame(index, PlotLayout.BASE_POSITION + Vector3.new(0, 3, 0)),
		Color = color,
		Material = Enum.Material.SmoothPlastic,
		CanQuery = false,
		Parent = folder,
	})

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
			Material = Enum.Material.SmoothPlastic,
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
	local ownerLabel = billboard(post, "Parcelle libre", Vector3.new(0, 5, 0), UDim2.fromOffset(260, 44), color)

	return {
		index = index,
		folder = folder,
		ownerLabel = ownerLabel,
		spots = spots,
	}
end

-- Met à jour l'apparence des emplacements selon le nombre débloqué.
function HubMap.setUnlockedSpots(plot, unlocked: number)
	for _, pad in plot.spots:GetChildren() do
		local spotIndex = pad:GetAttribute("SpotIndex")
		local isUnlocked = spotIndex <= unlocked
		pad.Color = if isUnlocked then Color3.fromRGB(215, 215, 225) else Color3.fromRGB(45, 45, 55)
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
	local hub = Instance.new("Folder")
	hub.Name = "Hub"

	part({
		Name = "Ground",
		Size = Vector3.new(400, 1, 400),
		Position = Vector3.new(0, -0.7, 0),
		Color = Color3.fromRGB(60, 64, 80),
		Material = Enum.Material.Slate,
		Parent = hub,
	})

	-- Place centrale
	part({
		Name = "Plaza",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 70, 70),
		CFrame = CFrame.new(0, -0.1, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(80, 84, 104),
		Material = Enum.Material.Marble,
		Parent = hub,
	})

	local radius = PlotLayout.RANKED_CIRCLE_RADIUS
	local circleCenter = PlotLayout.RANKED_CIRCLE_POSITION
	local circle = part({
		Name = "RankedCircle",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, radius * 2, radius * 2),
		CFrame = CFrame.new(circleCenter + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(235, 70, 80),
		Material = Enum.Material.Neon,
		Transparency = 0.15,
		CanCollide = false,
		Parent = hub,
	})
	part({
		Name = "RankedRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.25, radius * 2 + 2, radius * 2 + 2),
		CFrame = CFrame.new(circleCenter + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(255, 205, 80),
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanQuery = false,
		Parent = hub,
	})
	billboard(circle, "⚔ RANKED 1v1", Vector3.new(0, 7, 0), UDim2.fromOffset(300, 50), Color3.fromRGB(255, 205, 80))
	billboard(circle, "Entre dans le cercle pour chercher un adversaire", Vector3.new(0, 4.5, 0), UDim2.fromOffset(380, 26))

	local board = part({
		Name = "LeaderboardBoard",
		Size = Vector3.new(28, 20, 1),
		CFrame = CFrame.new(0, 11, -12),
		Color = Color3.fromRGB(25, 27, 38),
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

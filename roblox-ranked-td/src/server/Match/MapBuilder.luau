-- Construit la carte du match par code (aucun modèle à créer dans Studio).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local MapLayout = require(ReplicatedStorage:WaitForChild("Shared").MapLayout)
local ProximityLabel = require(ReplicatedStorage:WaitForChild("Shared").ProximityLabel)

local MapBuilder = {}

local LANE_COLORS = {
	Color3.fromRGB(48, 88, 145),
	Color3.fromRGB(145, 43, 43),
}

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		p[key] = value
	end
	return p
end

local function torch(parent: Instance, position: Vector3)
	part({ Name = "Torch", Size = Vector3.new(0.32, 3.2, 0.32), Position = position, Color = Color3.fromRGB(86, 55, 32), Material = Enum.Material.Wood, CanCollide = false, Parent = parent })
	local flame = part({ Name = "Flame", Shape = Enum.PartType.Ball, Size = Vector3.new(0.75, 1.05, 0.75), Position = position + Vector3.new(0, 2, 0), Color = Color3.fromRGB(255, 139, 37), Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, Parent = parent })
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 154, 67)
	light.Brightness = 2
	light.Range = 17
	light.Parent = flame
end

local function buildLane(laneIndex: number, parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Lane" .. laneIndex
	folder.Parent = parent

	local origin = MapLayout.laneOrigin(laneIndex)

	-- Sol constructible (l'attribut Lane sert au client pour savoir où il clique).
	part({
		Name = "Floor",
		Size = Vector3.new(MapLayout.LANE_WIDTH, 1, MapLayout.LANE_LENGTH),
		Position = origin + Vector3.new(0, -0.5, 0),
		Color = Color3.fromRGB(64, 91, 51),
		Material = Enum.Material.Grass,
		Parent = folder,
	}):SetAttribute("Lane", laneIndex)

	-- Chemin
	local path = MapLayout.PATH
	for i = 2, #path do
		local a, b = origin + path[i - 1], origin + path[i]
		local length = (b - a).Magnitude + MapLayout.PATH_WIDTH
		part({
			Name = "Path",
			Size = Vector3.new(MapLayout.PATH_WIDTH, 0.2, length),
			CFrame = CFrame.lookAt((a + b) / 2, b) + Vector3.new(0, 0.05, 0),
			Color = Color3.fromRGB(117, 107, 89),
			Material = Enum.Material.Cobblestone,
			Parent = folder,
		}):SetAttribute("Lane", laneIndex)
	end

	-- Entrée des ennemis
	part({
		Name = "EnemySpawn",
		Size = Vector3.new(MapLayout.PATH_WIDTH + 2, 6, 1),
		Position = origin + path[1] + Vector3.new(0, 3, 2),
		Color = Color3.fromRGB(83, 31, 29),
		Material = Enum.Material.Brick,
		Transparency = 0.7,
		CanCollide = false,
		CanQuery = false,
		Parent = folder,
	})
	for _, x in { -MapLayout.PATH_WIDTH / 2 - 1, MapLayout.PATH_WIDTH / 2 + 1 } do
		part({ Name = "GateTower", Size = Vector3.new(2.4, 7, 2.4), Position = origin + path[1] + Vector3.new(x, 3.5, 2), Color = Color3.fromRGB(80, 77, 70), Material = Enum.Material.Brick, Parent = folder })
	end
	part({ Name = "GateLintel", Size = Vector3.new(MapLayout.PATH_WIDTH + 4.5, 1.4, 2.2), Position = origin + path[1] + Vector3.new(0, 7, 2), Color = Color3.fromRGB(70, 68, 63), Material = Enum.Material.Brick, Parent = folder })

	-- Base à défendre
	local base = part({
		Name = "Base",
		Size = Vector3.new(10, 7, 10),
		Position = origin + MapLayout.BASE_POSITION + Vector3.new(0, 3.5, 0),
		Color = Color3.fromRGB(100, 96, 87),
		Material = Enum.Material.Brick,
		CanQuery = false,
		Parent = folder,
	})
	for _, offset in { Vector3.new(-4.6, 4.4, -4.6), Vector3.new(4.6, 4.4, -4.6), Vector3.new(-4.6, 4.4, 4.6), Vector3.new(4.6, 4.4, 4.6) } do
		part({ Name = "CastleTurret", Shape = Enum.PartType.Cylinder, Size = Vector3.new(8.8, 2.4, 2.4), CFrame = CFrame.new(origin + MapLayout.BASE_POSITION + offset) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(84, 81, 74), Material = Enum.Material.Cobblestone, Parent = folder })
	end
	part({ Name = "BannerPole", Size = Vector3.new(0.22, 8, 0.22), Position = origin + MapLayout.BASE_POSITION + Vector3.new(0, 10, 0), Color = Color3.fromRGB(74, 49, 30), Material = Enum.Material.Wood, CanCollide = false, Parent = folder })
	part({ Name = "Banner", Size = Vector3.new(0.14, 3, 3.8), Position = origin + MapLayout.BASE_POSITION + Vector3.new(0, 11.5, -1.8), Color = LANE_COLORS[laneIndex], Material = Enum.Material.Fabric, CanCollide = false, Parent = folder })
	for _, x in { -MapLayout.LANE_WIDTH / 2 + 5, MapLayout.LANE_WIDTH / 2 - 5 } do
		torch(folder, origin + Vector3.new(x, 1.6, -MapLayout.LANE_LENGTH / 2 + 9))
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(200, 40)
	billboard.StudsOffset = Vector3.new(0, 6, 0)
	ProximityLabel.register(billboard, Config.LabelDistance.Far)
	billboard.AlwaysOnTop = true
	billboard.Parent = base
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Antique
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Text = "Forteresse " .. laneIndex
	label.Parent = billboard

	-- Murs invisibles : chaque joueur reste sur son terrain.
	-- CanQuery = false pour ne pas bloquer les clics de pose de tour.
	local w, l, h = MapLayout.LANE_WIDTH, MapLayout.LANE_LENGTH, 30
	local walls = {
		{ Vector3.new(w / 2 + 0.5, h / 2, 0), Vector3.new(1, h, l) },
		{ Vector3.new(-w / 2 - 0.5, h / 2, 0), Vector3.new(1, h, l) },
		{ Vector3.new(0, h / 2, l / 2 + 0.5), Vector3.new(w, h, 1) },
		{ Vector3.new(0, h / 2, -l / 2 - 0.5), Vector3.new(w, h, 1) },
	}
	for _, wall in walls do
		part({
			Name = "Wall",
			Position = origin + wall[1],
			Size = wall[2],
			Transparency = 1,
			CanQuery = false,
			Parent = folder,
		})
	end

	return base
end

-- Retourne la table des parts "Base" par lane (pour afficher le nom des joueurs dessus).
function MapBuilder.build()
	Lighting.ClockTime = 18.15
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.fromRGB(91, 80, 77)
	Lighting.OutdoorAmbient = Color3.fromRGB(119, 106, 96)
	local atmosphere = Lighting:FindFirstChild("BattleAtmosphere") or Instance.new("Atmosphere")
	atmosphere.Name = "BattleAtmosphere"
	atmosphere.Color = Color3.fromRGB(209, 185, 157)
	atmosphere.Decay = Color3.fromRGB(93, 70, 67)
	atmosphere.Density = 0.28
	atmosphere.Haze = 1.8
	atmosphere.Parent = Lighting

	local map = Instance.new("Folder")
	map.Name = "Map"

	local bases = {}
	for laneIndex = 1, 2 do
		bases[laneIndex] = buildLane(laneIndex, map)
	end

	-- SpawnLocation neutre : les personnages sont ensuite déplacés sur leur lane.
	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = MapLayout.toWorld(1, MapLayout.PLAYER_SPAWN) - Vector3.new(0, 2.5, 0)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanQuery = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = map

	map.Parent = workspace

	for _, name in { "Enemies", "Towers" } do
		local folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = workspace
	end

	return bases
end

return MapBuilder

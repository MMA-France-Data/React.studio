-- Construit la carte du match par code (aucun modèle à créer dans Studio).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapLayout = require(ReplicatedStorage:WaitForChild("Shared").MapLayout)

local MapBuilder = {}

local LANE_COLORS = {
	Color3.fromRGB(80, 130, 255),
	Color3.fromRGB(255, 100, 90),
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
		Color = Color3.fromRGB(70, 120, 60),
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
			Color = Color3.fromRGB(150, 125, 90),
			Material = Enum.Material.Sand,
			Parent = folder,
		}):SetAttribute("Lane", laneIndex)
	end

	-- Entrée des ennemis
	part({
		Name = "EnemySpawn",
		Size = Vector3.new(MapLayout.PATH_WIDTH + 2, 6, 1),
		Position = origin + path[1] + Vector3.new(0, 3, 2),
		Color = Color3.fromRGB(120, 20, 30),
		Material = Enum.Material.Neon,
		Transparency = 0.3,
		CanCollide = false,
		CanQuery = false,
		Parent = folder,
	})

	-- Base à défendre
	local base = part({
		Name = "Base",
		Size = Vector3.new(8, 6, 8),
		Position = origin + MapLayout.BASE_POSITION + Vector3.new(0, 3, 0),
		Color = LANE_COLORS[laneIndex],
		Material = Enum.Material.SmoothPlastic,
		CanQuery = false,
		Parent = folder,
	})
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(200, 40)
	billboard.StudsOffset = Vector3.new(0, 6, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = base
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Text = "Base " .. laneIndex
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

-- Construit tout le décor au démarrage du serveur : le lobby, puis les salles à la suite, séparées par
-- de petits couloirs sûrs. Rien n'est posé à la main dans Studio.
--
--   lobby (allée + espaces des joueurs) | couloir 0 | SALLE 1 | couloir 1 | SALLE 2 | ... | SALLE 10 | salle des gagnants
--
-- Le joueur avance vers +Z. Chaque salle a une porte d'entrée et une porte de sortie (« niveau suivant »).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Pets = require(ReplicatedStorage.Shared.Pets)
local Build = require(script.Parent.Build)
local GymModels = require(script.Parent.GymModels)
local Lava = require(script.Parent.Events.Lava)

local World = {}

local GYM_Z, GYM_WALL = 30, 18 -- le mur du lobby où s'ouvre la porte des salles, et la hauteur de ses murs
local LOBBY_X, LOBBY_BACK = 90, -170 -- demi-largeur du lobby, et son mur du fond
local ALLEY = 20 -- demi-largeur de l'allée du milieu
local PLOT_X, PLOT_Z = 70, 64 -- taille de l'espace d'un joueur
local DOOR_W, DOOR_H = 12, 12
local SAS_LEN, SAS_HALF, SAS_WALL = 20, 12, 14
local ROOM_HALF_X, ROOM_LEN = 35, 80
local PITCH = SAS_LEN + ROOM_LEN
local WALL = 1.5

World.PLOTS = 6 -- un espace par joueur du serveur
World.ROOM_HALF_X = ROOM_HALF_X
World.ROOM_HALF_Z = ROOM_LEN / 2

local WHITE = Color3.fromRGB(245, 245, 250)

-- Couleurs d'une salle selon son premier événement : { sol A, sol B, murs }.
local THEMES = {
	Lava = { Color3.fromRGB(96, 74, 74), Color3.fromRGB(110, 84, 82), Color3.fromRGB(150, 82, 60) },
	Meteors = { Color3.fromRGB(62, 200, 64), Color3.fromRGB(80, 216, 74), Color3.fromRGB(70, 140, 230) },
	Explosions = { Color3.fromRGB(240, 200, 70), Color3.fromRGB(250, 214, 96), Color3.fromRGB(235, 130, 50) },
	Melody = { Color3.fromRGB(52, 56, 92), Color3.fromRGB(62, 66, 106), Color3.fromRGB(96, 70, 170) },
	Chase = { Color3.fromRGB(120, 60, 60), Color3.fromRGB(136, 70, 68), Color3.fromRGB(70, 30, 40) },
}

-- Mur le long de l'axe X, à la profondeur z, avec le trou d'une porte au milieu.
local function wallWithDoor(parent: Instance, z: number, halfX: number, height: number, color: Color3)
	local side = halfX - DOOR_W / 2
	for _, sign in { -1, 1 } do
		Build.part(parent, "Wall", Vector3.new(side, height, WALL), Vector3.new(sign * (DOOR_W / 2 + side / 2), height / 2, z), color)
	end
	Build.part(parent, "Lintel", Vector3.new(DOOR_W, height - DOOR_H, WALL), Vector3.new(0, DOOR_H + (height - DOOR_H) / 2, z), color)
end

local function sideWalls(parent: Instance, zMin: number, zMax: number, halfX: number, height: number, color: Color3)
	for _, sign in { -1, 1 } do
		Build.part(
			parent,
			"Wall",
			Vector3.new(WALL, height, zMax - zMin),
			Vector3.new(sign * (halfX + WALL / 2), height / 2, (zMin + zMax) / 2),
			color
		)
	end
end

-- Porte : un bloc qui ferme le trou, et un néon au-dessus (rouge = fermée, vert = ouverte).
local function door(parent: Instance, name: string, z: number): Part
	local part = Build.part(parent, name, Vector3.new(DOOR_W, DOOR_H, 1), Vector3.new(0, DOOR_H / 2, z), Color3.fromRGB(60, 62, 72), Enum.Material.Metal)
	local light = Build.part(parent, name .. "Light", Vector3.new(DOOR_W, 0.8, WALL + 0.6), Vector3.new(0, DOOR_H + 0.4, z), Color3.fromRGB(255, 60, 60), Enum.Material.Neon)
	light.CanCollide = false
	part:SetAttribute("Open", false)
	return part
end

function World.setDoor(part: Part, open: boolean)
	if part:GetAttribute("Open") == open then
		return
	end
	part:SetAttribute("Open", open)
	part.CanCollide = not open
	part.Transparency = if open then 1 else 0
	local light = part.Parent:FindFirstChild(part.Name .. "Light")
	if light then
		light.Color = if open then Color3.fromRGB(70, 255, 90) else Color3.fromRGB(255, 60, 60)
	end
end

-- Début (en Z) de la salle n.
function World.roomStart(index: number): number
	return GYM_Z + (index - 1) * PITCH + SAS_LEN
end

-- Milieu du couloir qui suit la salle n (0 = le couloir entre la salle de sport et la salle 1).
function World.sasCenter(index: number): Vector3
	return Vector3.new(0, 3.5, GYM_Z + index * PITCH + SAS_LEN / 2)
end

-- Couleurs des espaces des joueurs : { sol A, sol B }.
local PLOT_COLORS = {
	{ Color3.fromRGB(96, 190, 255), Color3.fromRGB(140, 212, 255) },
	{ Color3.fromRGB(255, 170, 90), Color3.fromRGB(255, 196, 130) },
	{ Color3.fromRGB(120, 220, 130), Color3.fromRGB(160, 236, 160) },
	{ Color3.fromRGB(255, 130, 170), Color3.fromRGB(255, 170, 196) },
	{ Color3.fromRGB(190, 140, 255), Color3.fromRGB(212, 176, 255) },
	{ Color3.fromRGB(255, 224, 90), Color3.fromRGB(255, 236, 140) },
}

-- L'espace d'un joueur : ses 3 machines et son enclos (12 places, dont 5 ouvertes au départ).
-- Les espaces impairs sont à gauche de l'allée, les pairs à droite, trois rangées en partant de la porte des salles.
local function buildPlot(parent: Instance, index: number)
	local side = if index % 2 == 1 then -1 else 1
	local row = math.ceil(index / 2)
	local origin = Vector3.new(side * (ALLEY + PLOT_X / 2), 0, GYM_Z - 2 - PLOT_Z / 2 - (row - 1) * (PLOT_Z + 2))
	local colors = PLOT_COLORS[(index - 1) % #PLOT_COLORS + 1]

	local folder = Instance.new("Folder")
	folder.Name = "Plot" .. index
	folder:SetAttribute("Index", index)
	folder:SetAttribute("Owner", "")
	folder:SetAttribute("OwnerId", 0)
	folder.Parent = parent
	Build.checker(folder, "Floor", origin + Vector3.new(0, 0.12, 0), PLOT_X, PLOT_Z, 8, colors[1]:Lerp(Color3.fromRGB(70, 74, 88), 0.55), colors[2]:Lerp(Color3.fromRGB(70, 74, 88), 0.55), 0.12)

	-- Panneau au bord de l'allée, tourné vers elle : le nom du joueur (écrit par l'écran de chacun).
	local board = Build.part(folder, "Sign", Vector3.new(26, 5, 0.6), origin + Vector3.new(-side * (PLOT_X / 2 - 1), 12, 0), Color3.fromRGB(40, 44, 56))
	board.CFrame = CFrame.new(board.Position) * CFrame.Angles(0, math.rad(side * 90), 0)
	Build.sign(board, Enum.NormalId.Front, "plot|" .. index, colors[1])
	for _, z in { -12, 12 } do
		Build.part(folder, "SignPost", Vector3.new(0.7, 10, 0.7), origin + Vector3.new(-side * (PLOT_X / 2 - 1), 5, z), Color3.fromRGB(40, 44, 56))
	end

	local machines = {}
	local places = { Speed = origin + Vector3.new(-22, 0, -18), Jump = origin + Vector3.new(0, 0, -18), Force = origin + Vector3.new(22, 0, -18) }
	for name, place in places do
		local model = GymModels[name](folder, place)
		Build.billboard(model.PrimaryPart, 11)
		machines[name] = model
	end
	-- Où le joueur se met pour s'entraîner (enter), et où il est reposé après (exit).
	local spots = {
		-- debout sur la bande du premier tapis, face à l'écran
		Speed = { enter = CFrame.new(places.Speed + Vector3.new(-4, 4.9, 1.5)), anchored = true },
		-- couché sur le dos sur le banc, la tête vers la barre
		Force = { enter = CFrame.new(places.Force + Vector3.new(-3, 4, 0.6)) * CFrame.Angles(math.rad(90), 0, math.rad(180)), anchored = true },
		-- au milieu du trampoline : il rebondit tout seul
		Jump = { enter = CFrame.new(places.Jump + Vector3.new(0, 7.5, 0)), anchored = false },
	}
	for name, spot in spots do
		spot.exit = places[name] + Vector3.new(0, 3.5, 12.5)
	end

	-- L'enclos : 12 places sur deux rangées. L'écran de chaque joueur y montre les œufs et les familiers du
	-- propriétaire ; les places pas encore achetées restent sombres.
	local enclosure = Instance.new("Folder")
	enclosure.Name = "Enclosure"
	enclosure.Parent = folder
	local pens = {}
	for spot = 1, Pets.SPOTS_MAX do
		local column, line = (spot - 1) % 6, math.floor((spot - 1) / 6)
		local pad = Build.disc(enclosure, "Spot" .. spot, 5.4, 0.6, origin + Vector3.new(-6 + column * 6.6, 0.4, 9 + line * 13), Color3.fromRGB(60, 64, 78))
		pad:SetAttribute("Spot", spot)
		pens[spot] = pad
	end
	local fence = Color3.fromRGB(150, 110, 70)
	for _, bar in {
		{ Vector3.new(10, 1.6, 1.5), Vector3.new(39, 0.5, 0.5) },
		{ Vector3.new(10, 1.6, 31.5), Vector3.new(39, 0.5, 0.5) },
		{ Vector3.new(29.5, 1.6, 16.5), Vector3.new(0.5, 0.5, 30) },
	} do
		local rail = Build.part(enclosure, "Fence", bar[2], origin + bar[1], fence, Enum.Material.Wood)
		rail.CanCollide = false
	end
	for _, corner in { Vector3.new(-9.5, 1, 1.5), Vector3.new(29.5, 1, 1.5), Vector3.new(-9.5, 1, 31.5), Vector3.new(29.5, 1, 31.5) } do
		Build.part(enclosure, "Post", Vector3.new(0.8, 2.4, 0.8), origin + corner, fence, Enum.Material.Wood)
	end
	local title = Build.part(enclosure, "Title", Vector3.new(1, 1, 1), origin + Vector3.new(10, 1, 16.5), fence)
	title.Transparency = 1
	title.CanCollide = false
	local gui = Build.billboard(title, 15)
	gui.MaxDistance = 140
	gui.Title:SetAttribute("Enclosure", index)

	return {
		index = index,
		folder = folder,
		origin = origin,
		machines = machines,
		spots = spots,
		pens = pens,
		spawn = origin + Vector3.new(-13, 3.5, 2),
	}
end

-- Le lobby : une grande allée au milieu, qui mène à la porte des salles, et les espaces des joueurs des deux côtés.
local function buildGym(parent: Instance)
	local gym = Instance.new("Folder")
	gym.Name = "Gym"
	gym.Parent = parent

	Build.checker(gym, "Floor", Vector3.new(0, 0, (GYM_Z + LOBBY_BACK) / 2), LOBBY_X * 2, GYM_Z - LOBBY_BACK, 10, Color3.fromRGB(70, 74, 88), Color3.fromRGB(80, 84, 98))
	local wallColor = Color3.fromRGB(240, 150, 60)
	sideWalls(gym, LOBBY_BACK, GYM_Z, LOBBY_X, GYM_WALL, wallColor)
	Build.part(gym, "Wall", Vector3.new(LOBBY_X * 2 + WALL * 2, GYM_WALL, WALL), Vector3.new(0, GYM_WALL / 2, LOBBY_BACK - WALL / 2), wallColor)
	wallWithDoor(gym, GYM_Z, LOBBY_X + WALL, GYM_WALL, wallColor)

	-- Point d'apparition de secours, au milieu de l'allée (chaque joueur est ensuite posé dans son espace).
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Position = Vector3.new(0, 0.5, -70)
	spawn.Color = Color3.fromRGB(80, 220, 110)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = gym

	local title = Build.part(gym, "Title", Vector3.new(34, 5, 0.6), Vector3.new(0, 13, LOBBY_BACK + 0.4), Color3.fromRGB(40, 44, 56))
	Build.sign(title, Enum.NormalId.Back, "gym")
	local arrow = Build.part(gym, "ToRooms", Vector3.new(20, 3.4, 0.6), Vector3.new(0, DOOR_H + 3, GYM_Z - WALL), Color3.fromRGB(40, 44, 56))
	Build.sign(arrow, Enum.NormalId.Front, "toRooms", Color3.fromRGB(120, 255, 110))

	local plots = {}
	for index = 1, World.PLOTS do
		plots[index] = buildPlot(gym, index)
	end

	-- La boutique des œufs : un stand dans l'allée, près de la porte des salles (on y échange ses tickets).
	local stand = Vector3.new(-11, 0, 16)
	local counter = Build.part(gym, "Shop", Vector3.new(9, 3.4, 4), stand + Vector3.new(0, 1.7, 0), Color3.fromRGB(255, 200, 60))
	Build.part(gym, "ShopTop", Vector3.new(10, 0.5, 5), stand + Vector3.new(0, 3.6, 0), Color3.fromRGB(150, 90, 40), Enum.Material.Wood)
	for _, x in { -4.6, 4.6 } do
		Build.part(gym, "ShopPost", Vector3.new(0.6, 7, 0.6), stand + Vector3.new(x, 7, 0), Color3.fromRGB(150, 90, 40), Enum.Material.Wood)
	end
	Build.part(gym, "ShopRoof", Vector3.new(11.5, 0.6, 6.5), stand + Vector3.new(0, 10.8, 0), Color3.fromRGB(240, 70, 70))
	local shopBoard = Build.part(gym, "ShopSign", Vector3.new(10, 2.6, 0.5), stand + Vector3.new(0, 12.6, 0), Color3.fromRGB(40, 44, 56))
	Build.sign(shopBoard, Enum.NormalId.Front, "shop", Color3.fromRGB(255, 221, 51))
	Build.sign(shopBoard, Enum.NormalId.Back, "shop", Color3.fromRGB(255, 221, 51))
	for i, color in { Color3.fromRGB(240, 90, 40), Color3.fromRGB(250, 250, 250), Color3.fromRGB(120, 170, 120) } do
		local egg = Build.part(gym, "ShopEgg", Vector3.new(1.8, 1.8, 1.8), stand + Vector3.new(-3 + (i - 1) * 3, 4.9, 0), color)
		egg.Shape = Enum.PartType.Ball
		egg.CanCollide = false
	end

	-- Le raccourci : un rond qui brille dans l'allée, près de la porte des salles, avec son panneau.
	local shortcuts = {}
	for i, cleared in Config.SHORTCUTS do
		local position = Vector3.new(11, 0, 18 - (i - 1) * 14)
		local pad = Build.disc(gym, "Shortcut" .. cleared, 10, 0.4, position + Vector3.new(0, 0.2, 0), Color3.fromRGB(190, 90, 255), Enum.Material.Neon)
		pad:SetAttribute("Cleared", cleared)
		local board = Build.part(gym, "ShortcutSign", Vector3.new(10, 5, 0.6), position + Vector3.new(0, 6, 9), Color3.fromRGB(40, 44, 56))
		Build.sign(board, Enum.NormalId.Front, "shortcut|" .. (cleared + 1), Color3.fromRGB(220, 160, 255))
		Build.part(gym, "ShortcutPost", Vector3.new(0.6, 4, 0.6), position + Vector3.new(0, 2, 9), Color3.fromRGB(40, 44, 56))
		shortcuts[cleared] = pad
	end

	return { folder = gym, plots = plots, shortcuts = shortcuts, shop = counter, spawn = spawn }
end

local function buildSas(parent: Instance, index: number, wallColor: Color3)
	local zMin = GYM_Z + index * PITCH
	local folder = Instance.new("Folder")
	folder.Name = "Sas" .. index
	folder.Parent = parent
	Build.checker(
		folder,
		"Floor",
		Vector3.new(0, 0, zMin + SAS_LEN / 2),
		SAS_HALF * 2,
		SAS_LEN,
		4,
		Color3.fromRGB(200, 204, 214),
		Color3.fromRGB(222, 226, 234)
	)
	sideWalls(folder, zMin, zMin + SAS_LEN, SAS_HALF, SAS_WALL, wallColor)
end

local function buildRoom(parent: Instance, index: number)
	local def = Config.ROOMS[index]
	local theme = THEMES[def.events[1]]
	local zMin = World.roomStart(index)
	local zMax = zMin + ROOM_LEN
	-- Murs : assez hauts pour le parcours de lave (et le plafond qui tombe au-dessus).
	local height = 36
	if def.Lava then
		height = Lava.plan(index, def.Lava).top + if def.Ceiling then 44 else 30
	end

	local folder = Instance.new("Folder")
	folder.Name = "Room" .. index
	folder.Parent = parent
	local static = Instance.new("Folder")
	static.Name = "Static"
	static.Parent = folder
	local effects = Instance.new("Folder")
	effects.Name = "Effects"
	effects.Parent = folder

	Build.checker(static, "Floor", Vector3.new(0, 0, (zMin + zMax) / 2), ROOM_HALF_X * 2, ROOM_LEN, 10, theme[1], theme[2])
	sideWalls(static, zMin, zMax, ROOM_HALF_X, height, theme[3])
	wallWithDoor(static, zMin, ROOM_HALF_X + WALL, height, theme[3])
	wallWithDoor(static, zMax, ROOM_HALF_X + WALL, height, theme[3])
	local entry = door(folder, "Entry", zMin)
	local exit = door(folder, "Exit", zMax)
	World.setDoor(entry, true)

	-- Panneau au-dessus de l'entrée, côté couloir : le numéro de la salle et ses événements.
	local board = Build.part(folder, "Sign", Vector3.new(DOOR_W + 8, 5.4, 0.5), Vector3.new(0, DOOR_H + 3.9, zMin - WALL), Color3.fromRGB(40, 44, 56))
	local needs = {}
	for _, name in Config.MACHINES do
		if def.need and def.need[name] then
			table.insert(needs, name .. ":" .. def.need[name])
		end
	end
	Build.sign(board, Enum.NormalId.Front, "roomSign|" .. index .. "|" .. table.concat(def.events, ",") .. "|" .. table.concat(needs, ","))
	folder:SetAttribute("Needs", table.concat(needs, ","))

	folder:SetAttribute("State", "Idle")
	folder:SetAttribute("Ends", 0)
	folder:SetAttribute("Events", table.concat(def.events, ","))

	return {
		index = index,
		def = def,
		folder = folder,
		static = static,
		effects = effects,
		entry = entry,
		exit = exit,
		center = Vector3.new(0, 0, (zMin + zMax) / 2),
		zMin = zMin,
		zMax = zMax,
		height = height,
		wallColor = theme[3],
	}
end

local function buildFinal(parent: Instance, count: number)
	local zMin = GYM_Z + count * PITCH
	local folder = Instance.new("Folder")
	folder.Name = "Final"
	folder.Parent = parent
	local length = 40
	Build.checker(folder, "Floor", Vector3.new(0, 0, zMin + length / 2), 48, length, 8, Color3.fromRGB(255, 205, 60), Color3.fromRGB(255, 225, 110))
	local gold = Color3.fromRGB(230, 170, 40)
	sideWalls(folder, zMin, zMin + length, 24, 20, gold)
	Build.part(folder, "Wall", Vector3.new(48 + WALL * 2, 20, WALL), Vector3.new(0, 10, zMin + length + WALL / 2), gold)
	-- Le trophée.
	local center = Vector3.new(0, 0, zMin + 26)
	Build.disc(folder, "Base", 8, 1.5, center + Vector3.new(0, 0.75, 0), Color3.fromRGB(60, 62, 72))
	Build.part(folder, "Stem", Vector3.new(1.2, 4, 1.2), center + Vector3.new(0, 3.5, 0), gold, Enum.Material.Metal)
	local cup = Build.part(folder, "Cup", Vector3.new(5, 5, 5), center + Vector3.new(0, 8, 0), Color3.fromRGB(255, 215, 70), Enum.Material.Neon)
	cup.Shape = Enum.PartType.Ball
	local pad = Build.disc(folder, "Back", 10, 0.4, Vector3.new(0, 0.2, zMin + 10), Color3.fromRGB(80, 220, 110), Enum.Material.Neon)
	local board = Build.part(folder, "Sign", Vector3.new(30, 5, 0.6), Vector3.new(0, 14, zMin + length - 0.2), Color3.fromRGB(40, 44, 56))
	Build.sign(board, Enum.NormalId.Front, "finished|" .. count)
	return { folder = folder, back = pad }
end

function World.build()
	local gym = buildGym(workspace)
	local roomsFolder = Instance.new("Folder")
	roomsFolder.Name = "Rooms"
	roomsFolder.Parent = workspace

	local rooms = {}
	for index = 1, #Config.ROOMS do
		rooms[index] = buildRoom(roomsFolder, index)
	end
	-- Couloirs : celui d'avant la salle n prend la couleur de ses murs.
	for index = 0, #rooms - 1 do
		buildSas(roomsFolder, index, rooms[index + 1].wallColor)
	end
	local final = buildFinal(roomsFolder, #rooms)

	return { gym = gym, rooms = rooms, final = final }
end

return World

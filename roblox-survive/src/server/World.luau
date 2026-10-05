-- Construit tout le décor au démarrage du serveur : la salle de sport, puis les salles à la suite, séparées par
-- de petits couloirs sûrs. Rien n'est posé à la main dans Studio.
--
--   salle de sport | couloir 0 | SALLE 1 | couloir 1 | SALLE 2 | ... | SALLE 10 | salle des gagnants
--
-- Le joueur avance vers +Z. Chaque salle a une porte d'entrée et une porte de sortie (« niveau suivant »).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Build = require(script.Parent.Build)
local GymModels = require(script.Parent.GymModels)
local Lava = require(script.Parent.Events.Lava)

local World = {}

local GYM_X, GYM_Z, GYM_WALL = 40, 30, 18
local DOOR_W, DOOR_H = 12, 12
local SAS_LEN, SAS_HALF, SAS_WALL = 20, 12, 14
local ROOM_HALF_X, ROOM_LEN = 35, 80
local PITCH = SAS_LEN + ROOM_LEN
local WALL = 1.5

World.ROOM_HALF_X = ROOM_HALF_X
World.ROOM_HALF_Z = ROOM_LEN / 2

local WHITE = Color3.fromRGB(245, 245, 250)

-- Couleurs d'une salle selon son premier événement : { sol A, sol B, murs }.
local THEMES = {
	Lava = { Color3.fromRGB(96, 74, 74), Color3.fromRGB(110, 84, 82), Color3.fromRGB(150, 82, 60) },
	Meteors = { Color3.fromRGB(62, 200, 64), Color3.fromRGB(80, 216, 74), Color3.fromRGB(70, 140, 230) },
	Explosions = { Color3.fromRGB(240, 200, 70), Color3.fromRGB(250, 214, 96), Color3.fromRGB(235, 130, 50) },
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

local function buildGym(parent: Instance)
	local gym = Instance.new("Folder")
	gym.Name = "Gym"
	gym.Parent = parent

	Build.checker(gym, "Floor", Vector3.new(0, 0, 0), GYM_X * 2, GYM_Z * 2, 8, Color3.fromRGB(70, 74, 88), Color3.fromRGB(80, 84, 98))
	local wallColor = Color3.fromRGB(240, 150, 60)
	sideWalls(gym, -GYM_Z, GYM_Z, GYM_X, GYM_WALL, wallColor)
	Build.part(gym, "Wall", Vector3.new(GYM_X * 2 + WALL * 2, GYM_WALL, WALL), Vector3.new(0, GYM_WALL / 2, -GYM_Z - WALL / 2), wallColor)
	wallWithDoor(gym, GYM_Z, GYM_X + WALL, GYM_WALL, wallColor)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Position = Vector3.new(0, 0.5, -16)
	spawn.Color = Color3.fromRGB(80, 220, 110)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = gym

	local title = Build.part(gym, "Title", Vector3.new(34, 5, 0.6), Vector3.new(0, 13, -GYM_Z + 0.4), Color3.fromRGB(40, 44, 56))
	Build.sign(title, Enum.NormalId.Back, "gym")
	local arrow = Build.part(gym, "ToRooms", Vector3.new(20, 3.4, 0.6), Vector3.new(0, DOOR_H + 3, GYM_Z - WALL), Color3.fromRGB(40, 44, 56))
	Build.sign(arrow, Enum.NormalId.Front, "toRooms", Color3.fromRGB(120, 255, 110))

	local machines = {}
	local places = { Speed = Vector3.new(-26, 0, -14), Jump = Vector3.new(-26, 0, 12), Force = Vector3.new(26, 0, -14) }
	for name, origin in places do
		local model = GymModels[name](gym, origin)
		Build.billboard(model.PrimaryPart, 11)
		machines[name] = model
	end

	-- Le raccourci : un rond qui brille, avec son panneau.
	local shortcuts = {}
	for i, cleared in Config.SHORTCUTS do
		local position = Vector3.new(26, 0, 6 + (i - 1) * 14)
		local pad = Build.disc(gym, "Shortcut" .. cleared, 10, 0.4, position + Vector3.new(0, 0.2, 0), Color3.fromRGB(190, 90, 255), Enum.Material.Neon)
		pad:SetAttribute("Cleared", cleared)
		local board = Build.part(gym, "ShortcutSign", Vector3.new(10, 5, 0.6), position + Vector3.new(8, 6, 0), Color3.fromRGB(40, 44, 56))
		board.CFrame = CFrame.new(board.Position) * CFrame.Angles(0, math.rad(90), 0)
		Build.sign(board, Enum.NormalId.Front, "shortcut|" .. (cleared + 1), Color3.fromRGB(220, 160, 255))
		Build.part(gym, "ShortcutPost", Vector3.new(0.6, 4, 0.6), position + Vector3.new(8, 2, 0), Color3.fromRGB(40, 44, 56))
		shortcuts[cleared] = pad
	end

	return { folder = gym, machines = machines, shortcuts = shortcuts, spawn = spawn }
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
	local board = Build.part(folder, "Sign", Vector3.new(DOOR_W + 6, 4, 0.5), Vector3.new(0, DOOR_H + 3.4, zMin - WALL), Color3.fromRGB(40, 44, 56))
	Build.sign(board, Enum.NormalId.Front, "roomSign|" .. index .. "|" .. table.concat(def.events, ","))

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

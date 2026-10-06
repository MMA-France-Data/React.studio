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
local Scenery = require(script.Parent.Scenery)
local Themes = require(script.Parent.Themes)

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

-- Mur le long de l'axe X, à la profondeur z, avec le trou d'une porte au milieu.
local function wallWithDoor(parent: Instance, z: number, halfX: number, height: number, color: Color3, material: Enum.Material?)
	local side = halfX - DOOR_W / 2
	for _, sign in { -1, 1 } do
		Build.part(parent, "Wall", Vector3.new(side, height, WALL), Vector3.new(sign * (DOOR_W / 2 + side / 2), height / 2, z), color, material)
	end
	Build.part(parent, "Lintel", Vector3.new(DOOR_W, height - DOOR_H, WALL), Vector3.new(0, DOOR_H + (height - DOOR_H) / 2, z), color, material)
end

local function sideWalls(parent: Instance, zMin: number, zMax: number, halfX: number, height: number, color: Color3, material: Enum.Material?)
	for _, sign in { -1, 1 } do
		Build.part(
			parent,
			"Wall",
			Vector3.new(WALL, height, zMax - zMin),
			Vector3.new(sign * (halfX + WALL / 2), height / 2, (zMin + zMax) / 2),
			color,
			material
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

local NAVY = Color3.fromRGB(34, 40, 70)

-- Un panneau sombre qui porte trois lignes de texte (« Title », « Level », « Info »), écrites par l'écran du joueur.
local function upgradeBoard(parent: Instance, name: string, size: Vector3, cframe: CFrame, face: Enum.NormalId): Part
	local part = Build.part(parent, name, size, cframe, NAVY)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Label"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.AutoLocalize = false
	gui.LightInfluence = 0
	gui.Parent = part
	Build.text(gui, "Title", UDim2.fromScale(0.94, 0.3), UDim2.fromScale(0.03, 0.04))
	Build.text(gui, "Level", UDim2.fromScale(0.94, 0.22), UDim2.fromScale(0.03, 0.36), Color3.fromRGB(110, 255, 80))
	local button = Instance.new("Frame")
	button.Name = "Button"
	button.BackgroundColor3 = Color3.fromRGB(40, 190, 60)
	button.BorderSizePixel = 0
	button.Size = UDim2.fromScale(0.7, 0.3)
	button.Position = UDim2.fromScale(0.15, 0.64)
	Instance.new("UICorner", button).CornerRadius = UDim.new(0.2, 0)
	button.Parent = gui
	Build.text(button, "Info", UDim2.fromScale(0.94, 0.86), UDim2.fromScale(0.03, 0.07))
	return part
end

-- Une clôture croisée entre deux points (le long de X ou de Z) : des poteaux sombres, deux lisses et des croisillons
-- de couleur.
local function fence(parent: Instance, from: Vector3, to: Vector3, color: Color3)
	local length = (to - from).Magnitude
	local count = math.max(1, math.round(length / 6.5))
	local step = (to - from) / count
	local span = step.Magnitude
	local height = 3.2
	for i = 0, count do
		Build.part(parent, "FencePost", Vector3.new(1.1, height + 0.8, 1.1), from + step * i + Vector3.new(0, (height + 0.8) / 2, 0), NAVY)
	end
	for i = 1, count do
		local middle = from + step * (i - 0.5)
		local along = CFrame.lookAt(middle, middle + step)
		for _, y in { 0.9, height } do
			Build.part(parent, "FenceRail", Vector3.new(0.5, 0.6, span), along + Vector3.new(0, y, 0), color)
		end
		local diagonal = math.sqrt(span * span + (height - 0.9) ^ 2)
		local angle = math.atan2(height - 0.9, span)
		for _, sign in { -1, 1 } do
			local brace = Build.part(parent, "FenceBrace", Vector3.new(0.4, 0.5, diagonal), (along + Vector3.new(0, (height + 0.9) / 2, 0)) * CFrame.Angles(sign * angle, 0, 0), color)
			brace.CanCollide = false
		end
	end
end

-- L'espace d'un joueur : ses 3 machines (chacune avec son panneau « Améliorer ») et son enclos.
-- Les espaces impairs sont à gauche de l'allée, les pairs à droite, trois rangées en partant de la porte des salles.
local function buildPlot(parent: Instance, index: number)
	local side = if index % 2 == 1 then -1 else 1
	local row = math.ceil(index / 2)
	local origin = Vector3.new(side * (ALLEY + PLOT_X / 2), 0, GYM_Z - 2 - PLOT_Z / 2 - (row - 1) * (PLOT_Z + 2))
	local colors = PLOT_COLORS[(index - 1) % #PLOT_COLORS + 1]

	local folder = Instance.new("Folder")
	folder.Name = "Plot" .. index
	folder:SetAttribute("Index", index)
	folder:SetAttribute("Origin", origin)
	folder:SetAttribute("Owner", "")
	folder:SetAttribute("OwnerId", 0)
	folder.Parent = parent
	-- Sol vert vif en damier, comme une pelouse de jeu.
	Build.checker(folder, "Floor", origin + Vector3.new(0, 0.12, 0), PLOT_X, PLOT_Z, 7, Color3.fromRGB(80, 204, 52), Color3.fromRGB(92, 216, 60), 0.12)

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

	-- Un panneau « Améliorer » à côté de chaque machine (le niveau et le prix sont écrits par l'écran du joueur).
	local signs = {}
	for name, place in places do
		local sign = upgradeBoard(folder, "UpgradeSign", Vector3.new(8, 4.4, 0.6), CFrame.new(place + Vector3.new(7, 4.4, 11.4)), Enum.NormalId.Back)
		sign:SetAttribute("Machine", name)
		signs[name] = sign
		Build.part(folder, "UpgradePost", Vector3.new(1, 2.4, 1), place + Vector3.new(7, 1.2, 11.4), NAVY)
	end

	-- L'enclos : une clôture croisée à la couleur de l'espace, sur un sol vert. Les familiers du joueur s'y
	-- promènent et il y pose ses œufs (l'écran de chacun les dessine). L'entrée est du côté des machines.
	local enclosure = Instance.new("Folder")
	enclosure.Name = "Enclosure"
	enclosure.Parent = folder
	local pen = Pets.PEN
	local x0, x1, z0, z1 = pen.minX - 2.5, pen.maxX + 2.5, pen.minZ - 2.5, pen.maxZ + 2.5
	Build.checker(enclosure, "Grass", origin + Vector3.new((x0 + x1) / 2, 0.22, (z0 + z1) / 2), x1 - x0, z1 - z0, 4, Color3.fromRGB(96, 220, 60), Color3.fromRGB(110, 232, 70), 0.1)
	local gate = 4 -- demi-largeur de l'entrée, au milieu du côté des machines
	local middle = (x0 + x1) / 2
	fence(enclosure, origin + Vector3.new(x0, 0, z0), origin + Vector3.new(middle - gate, 0, z0), colors[1])
	fence(enclosure, origin + Vector3.new(middle + gate, 0, z0), origin + Vector3.new(x1, 0, z0), colors[1])
	fence(enclosure, origin + Vector3.new(x1, 0, z0), origin + Vector3.new(x1, 0, z1), colors[1])
	fence(enclosure, origin + Vector3.new(x1, 0, z1), origin + Vector3.new(x0, 0, z1), colors[1])
	fence(enclosure, origin + Vector3.new(x0, 0, z1), origin + Vector3.new(x0, 0, z0), colors[1])
	-- Le panneau « Améliorer l'enclos », à gauche de l'entrée, tourné vers les machines.
	local upgrade = upgradeBoard(enclosure, "Upgrade", Vector3.new(9, 4.8, 0.6), CFrame.new(origin + Vector3.new(middle - gate - 6, 5.2, z0 - 0.9)), Enum.NormalId.Front)
	Build.part(enclosure, "UpgradePost", Vector3.new(1, 3, 1), origin + Vector3.new(middle - gate - 6, 1.5, z0 - 0.9), NAVY)
	-- Le nom de l'enclos et ce qu'il rapporte, au-dessus.
	local title = Build.part(enclosure, "Title", Vector3.new(1, 1, 1), origin + Vector3.new(middle, 1, (z0 + z1) / 2), NAVY)
	title.Transparency = 1
	title.CanCollide = false
	local gui = Build.billboard(title, 17)
	gui.MaxDistance = 140

	return {
		index = index,
		folder = folder,
		origin = origin,
		machines = machines,
		spots = spots,
		upgrade = upgrade,
		signs = signs,
		spawn = origin + Vector3.new(-13, 3.5, -3),
	}
end

-- Le lobby : une grande allée au milieu, qui mène à la porte des salles, et les espaces des joueurs des deux côtés.
local function buildGym(parent: Instance)
	local gym = Instance.new("Folder")
	gym.Name = "Gym"
	gym.Parent = parent

	Build.checker(gym, "Floor", Vector3.new(0, 0, (GYM_Z + LOBBY_BACK) / 2), LOBBY_X * 2, GYM_Z - LOBBY_BACK, 10, Color3.fromRGB(196, 184, 160), Color3.fromRGB(208, 196, 172), nil, Enum.Material.Pavement)
	local wallColor = Color3.fromRGB(236, 150, 84)
	sideWalls(gym, LOBBY_BACK, GYM_Z, LOBBY_X, GYM_WALL, wallColor, Enum.Material.Brick)
	Build.part(gym, "Wall", Vector3.new(LOBBY_X * 2 + WALL * 2, GYM_WALL, WALL), Vector3.new(0, GYM_WALL / 2, LOBBY_BACK - WALL / 2), wallColor, Enum.Material.Brick)
	wallWithDoor(gym, GYM_Z, LOBBY_X + WALL, GYM_WALL, wallColor, Enum.Material.Brick)
	-- La porte du lobby vers les salles : ouverte, sauf pendant la fermeture (Cycle.luau).
	local gate = door(gym, "Gate", GYM_Z)
	World.setDoor(gate, true)

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

	-- Le stand « VENDRE » : on y vend ses familiers. Un comptoir et un auvent rayé rouge et blanc.
	local sellAt = Vector3.new(11, 0, -2)
	local sell = Build.part(gym, "Sell", Vector3.new(9, 3.2, 3.6), sellAt + Vector3.new(0, 1.6, 0), Color3.fromRGB(110, 96, 100))
	for _, x in { -4.6, 4.6 } do
		for _, z in { -2.4, 2.4 } do
			Build.part(gym, "SellPost", Vector3.new(0.5, 10, 0.5), sellAt + Vector3.new(x, 5, z), Color3.fromRGB(110, 96, 100))
		end
	end
	for i = 0, 8 do
		Build.part(gym, "SellAwning", Vector3.new(1.2, 0.5, 6.4), sellAt + Vector3.new(-4.8 + i * 1.2, 10.2, 0), if i % 2 == 0 then Color3.fromRGB(235, 50, 50) else Color3.fromRGB(250, 250, 250))
	end
	local sellBoard = Build.part(gym, "SellSign", Vector3.new(10, 2.8, 0.5), sellAt + Vector3.new(0, 12.4, 0), NAVY)
	Build.sign(sellBoard, Enum.NormalId.Front, "sell", Color3.fromRGB(255, 70, 70))
	Build.sign(sellBoard, Enum.NormalId.Back, "sell", Color3.fromRGB(255, 70, 70))

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

	-- L'habillage : le haut des murs, les lampadaires, les guirlandes, la fontaine, la grande porte des salles.
	Scenery.lobby(gym, { halfX = LOBBY_X, back = LOBBY_BACK, front = GYM_Z, wall = GYM_WALL, alley = ALLEY, doorWidth = DOOR_W, lamps = { 12, -37, -103, -160 }, fountain = Vector3.new(0, 0, -112) })

	return { folder = gym, plots = plots, shortcuts = shortcuts, shop = counter, sell = sell, gate = gate, spawn = spawn }
end

local function buildSas(parent: Instance, index: number, wallColor: Color3, wallMaterial: Enum.Material?)
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
		Color3.fromRGB(222, 226, 234),
		nil,
		Enum.Material.Marble
	)
	sideWalls(folder, zMin, zMin + SAS_LEN, SAS_HALF, SAS_WALL, wallColor, wallMaterial)
	Scenery.sas(folder, zMin, SAS_LEN, SAS_HALF, SAS_WALL)
end

local function buildRoom(parent: Instance, index: number)
	local def = Config.ROOMS[index]
	local theme = Themes.of(index)
	local zMin = World.roomStart(index)
	local zMax = zMin + ROOM_LEN
	-- Murs : assez hauts pour le parcours de lave (et le plafond qui tombe au-dessus).
	local height = 36
	local course = def.Lava or def.Bomb
	if course then
		height = Lava.plan(index, course).top + if def.Ceiling then 44 else 30
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

	-- Le sol, les murs et les décors prennent le style de la salle (Themes.luau).
	Build.checker(static, "Floor", Vector3.new(0, 0, (zMin + zMax) / 2), ROOM_HALF_X * 2, ROOM_LEN, 10, theme.floor[2], theme.floor[3], nil, theme.floor[1])
	sideWalls(static, zMin, zMax, ROOM_HALF_X, height, theme.wall[2], theme.wall[1])
	wallWithDoor(static, zMin, ROOM_HALF_X + WALL, height, theme.wall[2], theme.wall[1])
	wallWithDoor(static, zMax, ROOM_HALF_X + WALL, height, theme.wall[2], theme.wall[1])
	Themes.dress(static, { center = Vector3.new(0, 0, (zMin + zMax) / 2), zMin = zMin, zMax = zMax, height = height }, theme)
	local entry = door(folder, "Entry", zMin)
	local exit = door(folder, "Exit", zMax)
	World.setDoor(entry, true)

	-- Panneau au-dessus de l'entrée, côté couloir : le numéro de la salle et ses événements.
	local board = Build.part(folder, "Sign", Vector3.new(DOOR_W + 8, 5.4, 0.5), Vector3.new(0, DOOR_H + 3.9, zMin - WALL), Color3.fromRGB(40, 44, 56))
	local needs = {}
	for _, name in Config.MACHINES do
		-- En points de stat : ceux que la salle donne (def.points), sinon ceux du palier demandé (def.need).
		local points = (def.points and def.points[name]) or (def.need and def.need[name] and Config.pointsFor(def.need[name]))
		if points then
			table.insert(needs, name .. ":" .. points)
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
		wallColor = theme.wall[2],
		wallMaterial = theme.wall[1],
	}
end

local function buildFinal(parent: Instance, count: number)
	local zMin = GYM_Z + count * PITCH
	local folder = Instance.new("Folder")
	folder.Name = "Final"
	folder.Parent = parent
	local length = 40
	Build.checker(folder, "Floor", Vector3.new(0, 0, zMin + length / 2), 48, length, 8, Color3.fromRGB(255, 205, 60), Color3.fromRGB(255, 225, 110), nil, Enum.Material.Marble)
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
	Scenery.light()
	local gym = buildGym(workspace)
	Scenery.land(workspace, { halfX = LOBBY_X, back = LOBBY_BACK, front = GYM_Z, wall = GYM_WALL }, GYM_Z + #Config.ROOMS * PITCH + 40)
	local roomsFolder = Instance.new("Folder")
	roomsFolder.Name = "Rooms"
	roomsFolder.Parent = workspace

	local rooms = {}
	for index = 1, #Config.ROOMS do
		rooms[index] = buildRoom(roomsFolder, index)
	end
	-- Couloirs : celui d'avant la salle n prend la couleur de ses murs.
	for index = 0, #rooms - 1 do
		buildSas(roomsFolder, index, rooms[index + 1].wallColor, rooms[index + 1].wallMaterial)
	end
	local final = buildFinal(roomsFolder, #rooms)

	return { gym = gym, rooms = rooms, final = final }
end

return World

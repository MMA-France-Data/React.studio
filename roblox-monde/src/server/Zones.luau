-- LES ZONES DU MONDE : de grands terrains ouverts, posés à la suite, chacun avec son thème (la ferme, la forêt, la
-- jungle), son chemin, ses décors, les camps de ses monstres et l'arène de son boss. Entre deux zones : une falaise
-- avec une porte, qui ne s'ouvre qu'au joueur qui a battu le boss de la zone d'avant (l'écran de chacun l'ouvre
-- pour lui ; Monsters.luau renvoie chez lui celui qui passerait quand même).
-- Tout est fait de blocs, au démarrage du serveur.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Pets = require(ReplicatedStorage.Shared.Pets)
local Build = require(script.Parent.Build)

local Zones = {}

local M = Enum.Material
local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end
local HALF_X = Config.ZONE_SIZE.X / 2
local LENGTH = Config.ZONE_SIZE.Z
local GATE_W, GATE_H = 16, 14
local NAVY = rgb(34, 40, 70)

-- OUTILS ---------------------------------------------------------------------------------------------------------------
-- Un bloc de décor : on passe à travers (solid : on bute dessus).
local function deco(parent: Instance, name: string, size: Vector3, cframe: CFrame | Vector3, color: Color3, material: Enum.Material?, shape: Enum.PartType?, solid: boolean?): Part
	local part = Build.part(parent, name, size, cframe, color, material)
	part.CanCollide = solid == true
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = size.Magnitude > 5
	if shape then
		part.Shape = shape
	end
	return part
end
local function ball(parent: Instance, name: string, diameter: number, position: Vector3, color: Color3, material: Enum.Material?): Part
	return deco(parent, name, Vector3.new(diameter, diameter, diameter), position, color, material, Enum.PartType.Ball)
end
-- Un cylindre debout, posé sur `base`.
local function pillar(parent: Instance, name: string, diameter: number, height: number, base: Vector3, color: Color3, material: Enum.Material?, solid: boolean?): Part
	local part = Build.disc(parent, name, diameter, height, base + Vector3.new(0, height / 2, 0), color, material)
	part.CanCollide = solid == true
	part.CanQuery = false
	part.CanTouch = false
	return part
end
-- Un toit à deux pentes au-dessus d'un rectangle (largeur le long de X, profondeur le long de Z).
local function roof(parent: Instance, base: Vector3, width: number, depth: number, rise: number, color: Color3, material: Enum.Material?)
	for _, sign in { -1, 1 } do
		local wedge = Instance.new("WedgePart")
		wedge.Name = "Roof"
		wedge.Anchored = true
		wedge.CanQuery = false
		wedge.CanTouch = false
		wedge.Size = Vector3.new(depth, rise, width / 2)
		wedge.CFrame = CFrame.new(base + Vector3.new(sign * width / 4, rise / 2, 0)) * CFrame.Angles(0, math.rad(sign * 90), 0)
		wedge.Color = color
		wedge.Material = material or M.SmoothPlastic
		wedge.TopSurface = Enum.SurfaceType.Smooth
		wedge.BottomSurface = Enum.SurfaceType.Smooth
		wedge.Parent = parent
	end
end

-- LES DÉCORS, UN PAR UN -----------------------------------------------------------------------------------------------
local props = {}

function props.tree(parent, at: Vector3, random: Random, scale: number?)
	local k = (scale or 1) * random:NextNumber(0.85, 1.25)
	local height = 11 * k
	pillar(parent, "Trunk", 2.4 * k, height, at, rgb(124, 82, 48), M.Wood, true)
	local greens = { rgb(64, 168, 70), rgb(82, 190, 80), rgb(50, 146, 64) }
	for i = 1, 3 do
		local offset = Vector3.new(random:NextNumber(-2.5, 2.5), random:NextNumber(-1, 3), random:NextNumber(-2.5, 2.5)) * k
		ball(parent, "Leaves", random:NextNumber(11, 15) * k, at + Vector3.new(0, height + 3 * k, 0) + offset, greens[i], M.Grass)
	end
end

function props.pine(parent, at: Vector3, random: Random, scale: number?)
	local k = (scale or 1) * random:NextNumber(0.9, 1.5)
	pillar(parent, "Trunk", 2 * k, 6 * k, at, rgb(96, 62, 38), M.Wood, true)
	local greens = { rgb(30, 110, 62), rgb(38, 128, 70), rgb(24, 96, 56) }
	for i = 0, 3 do
		pillar(parent, "Needles", (11 - i * 2.6) * k, 4.2 * k, at + Vector3.new(0, (4 + i * 3.4) * k, 0), greens[i % 3 + 1], M.Grass)
	end
end

function props.palm(parent, at: Vector3, random: Random, scale: number?)
	local k = (scale or 1) * random:NextNumber(0.9, 1.4)
	local lean = CFrame.Angles(math.rad(random:NextNumber(-8, 8)), random:NextNumber(0, math.pi * 2), math.rad(random:NextNumber(-8, 8)))
	local height = 17 * k
	local trunk = deco(parent, "Trunk", Vector3.new(height, 1.8 * k, 1.8 * k), CFrame.new(at) * lean * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), rgb(150, 112, 70), M.Wood, Enum.PartType.Cylinder, true)
	trunk.CanQuery = false
	local top = (CFrame.new(at) * lean * CFrame.new(0, height, 0)).Position
	for i = 1, 7 do
		local angle = i / 7 * math.pi * 2
		deco(parent, "Frond", Vector3.new(1.8 * k, 0.4, 9 * k), CFrame.new(top) * CFrame.Angles(0, angle, 0) * CFrame.Angles(math.rad(-24), 0, 0) * CFrame.new(0, 0, -4.5 * k), if i % 2 == 0 then rgb(52, 170, 72) else rgb(40, 148, 64), M.Grass)
	end
	for i = 1, 3 do
		ball(parent, "Coconut", 1.3 * k, top + Vector3.new(math.cos(i * 2.1) * k, -0.8 * k, math.sin(i * 2.1) * k), rgb(96, 64, 40))
	end
end

function props.rock(parent, at: Vector3, random: Random, scale: number?, color: Color3?)
	local k = (scale or 1) * random:NextNumber(0.7, 1.6)
	for i = 1, random:NextInteger(1, 3) do
		local size = Vector3.new(random:NextNumber(3, 6), random:NextNumber(2.5, 5), random:NextNumber(3, 6)) * k
		local shade = random:NextNumber(0.85, 1.1)
		local base = color or rgb(130, 132, 140)
		deco(parent, "Rock", size, CFrame.new(at + Vector3.new(random:NextNumber(-2, 2) * k * (i - 1), size.Y * 0.35, random:NextNumber(-2, 2) * k * (i - 1))) * CFrame.Angles(random:NextNumber(-0.3, 0.3), random:NextNumber(0, 3), random:NextNumber(-0.3, 0.3)), rgb(math.min(255, base.R * 255 * shade), math.min(255, base.G * 255 * shade), math.min(255, base.B * 255 * shade)), M.Slate, nil, true)
	end
end

function props.bush(parent, at: Vector3, random: Random, color: Color3?)
	for i = 1, 3 do
		ball(parent, "Bush", random:NextNumber(2.6, 4.2), at + Vector3.new(random:NextNumber(-1.6, 1.6), 1.2, random:NextNumber(-1.6, 1.6)), color or rgb(70, 176, 74), M.Grass)
	end
end

local FLOWERS = { rgb(255, 90, 110), rgb(255, 210, 70), rgb(250, 250, 250), rgb(190, 120, 255), rgb(255, 150, 60) }
function props.flowers(parent, at: Vector3, random: Random)
	for _ = 1, 6 do
		local spot = at + Vector3.new(random:NextNumber(-3.5, 3.5), 0, random:NextNumber(-3.5, 3.5))
		deco(parent, "Stem", Vector3.new(0.18, 1.3, 0.18), spot + Vector3.new(0, 0.65, 0), rgb(60, 150, 60))
		ball(parent, "Flower", 0.8, spot + Vector3.new(0, 1.5, 0), FLOWERS[random:NextInteger(1, #FLOWERS)])
	end
end

function props.hay(parent, at: Vector3, random: Random)
	local straw = rgb(232, 196, 96)
	local turn = CFrame.Angles(0, random:NextNumber(0, math.pi), 0)
	local bale = deco(parent, "Hay", Vector3.new(4, 4.4, 4.4), CFrame.new(at + Vector3.new(0, 2.2, 0)) * turn, straw, M.Grass, Enum.PartType.Cylinder, true)
	bale.CanQuery = false
	if random:NextNumber() < 0.5 then
		deco(parent, "Hay", Vector3.new(4, 4.4, 4.4), CFrame.new(at + Vector3.new(0, 2.2, 0)) * turn * CFrame.new(4.4, 0, 0.6), straw, M.Grass, Enum.PartType.Cylinder, true)
	end
end

-- Un champ de blé : un rectangle doré couvert d'épis.
function props.wheat(parent, at: Vector3, random: Random)
	local sizeX, sizeZ = random:NextNumber(24, 36), random:NextNumber(20, 30)
	deco(parent, "Field", Vector3.new(sizeX, 0.3, sizeZ), at + Vector3.new(0, 0.15, 0), rgb(150, 110, 60), M.Ground).CastShadow = false
	for x = -sizeX / 2 + 1.5, sizeX / 2 - 1.5, 3 do
		deco(parent, "Wheat", Vector3.new(1.6, 2.6, sizeZ - 2), at + Vector3.new(x, 1.5, 0), if (x // 3) % 2 == 0 then rgb(236, 200, 80) else rgb(226, 186, 66), M.Grass).CastShadow = false
	end
end

function props.fence(parent, from: Vector3, to: Vector3)
	local count = math.max(1, math.round((to - from).Magnitude / 6))
	local step = (to - from) / count
	local wood = rgb(170, 120, 70)
	for i = 0, count do
		deco(parent, "Post", Vector3.new(0.8, 3.6, 0.8), from + step * i + Vector3.new(0, 1.8, 0), wood, M.Wood)
	end
	for i = 1, count do
		local middle = from + step * (i - 0.5)
		for _, y in { 1.3, 2.7 } do
			deco(parent, "Rail", Vector3.new(0.4, 0.5, step.Magnitude), CFrame.lookAt(middle + Vector3.new(0, y, 0), middle + step + Vector3.new(0, y, 0)), wood, M.Wood)
		end
	end
end

function props.barn(parent, at: Vector3)
	local red, white = rgb(196, 54, 48), rgb(245, 240, 230)
	deco(parent, "Barn", Vector3.new(26, 16, 20), at + Vector3.new(0, 8, 0), red, M.WoodPlanks, nil, true)
	roof(parent, at + Vector3.new(0, 16, 0), 29, 22, 9, rgb(110, 60, 50), M.Slate)
	deco(parent, "BarnDoor", Vector3.new(9, 11, 0.4), at + Vector3.new(0, 5.5, -10.1), rgb(120, 40, 36), M.WoodPlanks)
	for _, x in { -4.7, 4.7 } do
		deco(parent, "Trim", Vector3.new(0.6, 11, 0.5), at + Vector3.new(x, 5.5, -10.2), white)
	end
	deco(parent, "Trim", Vector3.new(10, 0.6, 0.5), at + Vector3.new(0, 11.2, -10.2), white)
	for _, tilt in { -1, 1 } do
		deco(parent, "Trim", Vector3.new(0.5, 13.5, 0.5), CFrame.new(at + Vector3.new(0, 5.5, -10.25)) * CFrame.Angles(0, 0, math.rad(tilt * 40)), white)
	end
	deco(parent, "Window", Vector3.new(4, 4, 0.4), at + Vector3.new(0, 18.5, -11.1), white)
	-- Le silo à côté.
	pillar(parent, "Silo", 9, 22, at + Vector3.new(20, 0, 2), rgb(206, 210, 220), M.Metal, true)
	ball(parent, "SiloTop", 9, at + Vector3.new(20, 22, 2), rgb(190, 60, 54), M.Metal)
end

function props.windmill(parent, at: Vector3)
	pillar(parent, "Mill", 10, 24, at, rgb(240, 232, 214), M.Brick, true)
	pillar(parent, "MillCap", 11.5, 3, at + Vector3.new(0, 24, 0), rgb(150, 70, 50), M.Slate)
	local hub = at + Vector3.new(0, 21, -5.6)
	ball(parent, "Hub", 2.2, hub, rgb(110, 70, 40))
	for i = 0, 3 do
		deco(parent, "Blade", Vector3.new(3.2, 13, 0.4), CFrame.new(hub) * CFrame.Angles(0, 0, math.rad(22 + i * 90)) * CFrame.new(0, 7, 0), rgb(250, 246, 236), M.Fabric)
	end
end

function props.pond(parent, at: Vector3, random: Random, color: Color3?)
	local size = random:NextNumber(18, 28)
	pillar(parent, "Shore", size + 3, 0.3, at, rgb(214, 196, 150), M.Sand)
	local water = pillar(parent, "Water", size, 0.36, at, color or rgb(70, 180, 250), M.Glass)
	water.Transparency = 0.2
	for i = 1, 4 do
		pillar(parent, "Lily", 2.2, 0.42, at + Vector3.new(math.cos(i * 1.7) * size * 0.28, 0, math.sin(i * 1.7) * size * 0.28), rgb(70, 170, 80))
	end
end

function props.mushroom(parent, at: Vector3, random: Random)
	local k = random:NextNumber(0.8, 2.4)
	pillar(parent, "Stalk", 1.1 * k, 2.2 * k, at, rgb(244, 236, 220))
	local cap = pillar(parent, "Cap", 4 * k, 1.1 * k, at + Vector3.new(0, 2.2 * k, 0), if random:NextNumber() < 0.7 then rgb(220, 50, 50) else rgb(230, 150, 50))
	cap.CastShadow = true
	for i = 1, 4 do
		ball(parent, "Dot", 0.7 * k, at + Vector3.new(math.cos(i * 1.6) * 1.2 * k, 3.3 * k, math.sin(i * 1.6) * 1.2 * k), rgb(250, 250, 250))
	end
end

function props.log(parent, at: Vector3, random: Random)
	local length = random:NextNumber(7, 12)
	local piece = deco(parent, "Log", Vector3.new(length, 2.4, 2.4), CFrame.new(at + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, random:NextNumber(0, math.pi), 0), rgb(110, 74, 46), M.Wood, Enum.PartType.Cylinder, true)
	piece.CanQuery = false
end

function props.cabin(parent, at: Vector3)
	deco(parent, "Cabin", Vector3.new(18, 10, 14), at + Vector3.new(0, 5, 0), rgb(134, 90, 56), M.WoodPlanks, nil, true)
	roof(parent, at + Vector3.new(0, 10, 0), 21, 16, 7, rgb(70, 96, 70), M.Slate)
	deco(parent, "Door", Vector3.new(4, 7, 0.4), at + Vector3.new(-3, 3.5, -7.1), rgb(84, 54, 34), M.Wood)
	local window = deco(parent, "Window", Vector3.new(3.4, 3.4, 0.4), at + Vector3.new(4, 5.5, -7.1), rgb(255, 226, 140), M.Neon)
	local light = Instance.new("PointLight")
	light.Color = rgb(255, 210, 140)
	light.Range = 22
	light.Parent = window
	deco(parent, "Chimney", Vector3.new(2.6, 8, 2.6), at + Vector3.new(5, 13, 3), rgb(120, 120, 128), M.Brick)
end

-- Une ruine de la jungle : un escalier de pierre couvert de mousse, avec une idole.
function props.ruin(parent, at: Vector3)
	local stone, moss = rgb(140, 140, 126), rgb(84, 140, 70)
	for i = 0, 3 do
		local size = 26 - i * 6
		deco(parent, "Ruin", Vector3.new(size, 4, size), at + Vector3.new(0, 2 + i * 4, 0), if i % 2 == 0 then stone else rgb(124, 126, 112), M.Cobblestone, nil, true)
		deco(parent, "Moss", Vector3.new(size + 0.4, 0.5, size + 0.4), at + Vector3.new(0, 4 + i * 4, 0), moss, M.Grass)
	end
	local idol = deco(parent, "Idol", Vector3.new(4, 6, 4), at + Vector3.new(0, 19, 0), rgb(236, 176, 48), M.Metal)
	local eyes = deco(parent, "IdolEyes", Vector3.new(3, 0.8, 0.3), at + Vector3.new(0, 20.4, -2.1), rgb(90, 255, 140), M.Neon)
	local light = Instance.new("PointLight")
	light.Color = rgb(90, 255, 140)
	light.Range = 26
	light.Parent = eyes
	idol.CastShadow = true
end

-- Une grande plante aux larges feuilles.
function props.fern(parent, at: Vector3, random: Random)
	local k = random:NextNumber(0.8, 1.6)
	for i = 1, 6 do
		deco(parent, "Leaf", Vector3.new(1.6 * k, 0.3, 5.5 * k), CFrame.new(at + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, i / 6 * math.pi * 2 + random:NextNumber(-0.2, 0.2), 0) * CFrame.Angles(math.rad(32), 0, 0) * CFrame.new(0, 0, -2.75 * k), if i % 2 == 0 then rgb(40, 160, 80) else rgb(60, 190, 90), M.Grass)
	end
	if random:NextNumber() < 0.4 then
		ball(parent, "Bloom", 1.5 * k, at + Vector3.new(0, 1.6 * k, 0), FLOWERS[random:NextInteger(1, #FLOWERS)], M.Neon)
	end
end

-- LES THÈMES ------------------------------------------------------------------------------------------------------------
-- ground : la couleur et la matière du sol ; path : celles du chemin ; cliff : celles des falaises ; patches : des
-- taches de couleur sur le sol ; scatter : ce qu'on sème partout, avec combien de chaque ; set : les grands décors,
-- posés à des endroits précis (x, z par rapport au milieu de la zone).
local THEMES = {
	Farm = {
		ground = { rgb(110, 200, 80), M.Grass },
		path = { rgb(214, 180, 120), M.Sand },
		cliff = { rgb(170, 130, 90), M.Slate },
		patches = { rgb(126, 214, 90), rgb(98, 188, 74) },
		scatter = { tree = 26, hay = 16, bush = 18, flowers = 30, rock = 6 },
		set = function(folder, center: Vector3, random: Random)
			props.barn(folder, center + Vector3.new(-95, 0, -105))
			props.windmill(folder, center + Vector3.new(100, 0, -95))
			props.wheat(folder, center + Vector3.new(-108, 0, -30), random)
			props.wheat(folder, center + Vector3.new(112, 0, 20), random)
			props.wheat(folder, center + Vector3.new(-112, 0, 80), random)
			props.pond(folder, center + Vector3.new(60, 0, -40), random)
			-- Un pré clôturé près de la grange.
			local a, b = center + Vector3.new(-128, 0, -84), center + Vector3.new(-62, 0, -66)
			props.fence(folder, a, Vector3.new(b.X, 0, a.Z))
			props.fence(folder, Vector3.new(b.X, 0, a.Z), b)
			props.fence(folder, b, Vector3.new(a.X, 0, b.Z))
		end,
	},
	Forest = {
		ground = { rgb(58, 130, 70), M.Grass },
		path = { rgb(120, 92, 62), M.Ground },
		cliff = { rgb(92, 96, 104), M.Slate },
		patches = { rgb(48, 112, 62), rgb(70, 146, 78), rgb(96, 84, 60) },
		scatter = { pine = 70, tree = 14, mushroom = 34, log = 16, rock = 16, bush = 20, flowers = 10 },
		set = function(folder, center: Vector3, random: Random)
			props.cabin(folder, center + Vector3.new(96, 0, -100))
			props.cabin(folder, center + Vector3.new(-104, 0, 46))
			props.pond(folder, center + Vector3.new(-70, 0, -70), random, rgb(60, 150, 190))
			-- Un cercle de gros champignons.
			for i = 1, 9 do
				props.mushroom(folder, center + Vector3.new(70 + math.cos(i * 0.7) * 16, 0, 40 + math.sin(i * 0.7) * 16), random)
			end
		end,
	},
	Jungle = {
		ground = { rgb(64, 150, 62), M.Grass },
		path = { rgb(150, 124, 84), M.Mud },
		cliff = { rgb(110, 116, 96), M.Cobblestone },
		patches = { rgb(46, 128, 58), rgb(86, 170, 70), rgb(112, 100, 66) },
		scatter = { palm = 56, fern = 70, rock = 12, bush = 24, flowers = 16, tree = 10 },
		set = function(folder, center: Vector3, random: Random)
			props.ruin(folder, center + Vector3.new(-98, 0, -96))
			props.ruin(folder, center + Vector3.new(104, 0, 30))
			props.pond(folder, center + Vector3.new(70, 0, -70), random, rgb(60, 200, 170))
			props.pond(folder, center + Vector3.new(-76, 0, 50), random, rgb(60, 200, 170))
		end,
	},
}

-- UNE ZONE ---------------------------------------------------------------------------------------------------------------
-- Où sont les camps : cinq, du rang 1 (près de l'entrée) au rang 5 (près du boss), en zigzag de part et d'autre du
-- chemin. { x, z (depuis l'entrée) }
local CAMPS = { { -52, 48 }, { 56, 92 }, { -60, 138 }, { 58, 184 }, { -50, 226 } }
-- (Les monstres sont bien ecartes les uns des autres, sur un grand rond : on en combat un seul a la fois.)
local CAMP_RADIUS, CAMP_SIZE = 30, 5
-- Les coffres : dans les coins tranquilles de la zone. { x, z (depuis l'entrée) }
local CHESTS = { { 118, 60 }, { -122, 150 }, { 120, 236 }, { -116, 262 } }
local BOSS_Z = LENGTH - 46 -- l'arène du boss, au bout du chemin
local ARENA = 30

local function buildZone(parent: Instance, index: number, zMin: number)
	local theme = THEMES[Config.ZONES[index].theme]
	local zMax = zMin + LENGTH
	local center = Vector3.new(0, 0, (zMin + zMax) / 2)
	local random = Random.new(100 + index)
	local folder = Instance.new("Folder")
	folder.Name = "Zone" .. index
	folder:SetAttribute("Index", index)
	folder:SetAttribute("ZMin", zMin)
	folder:SetAttribute("ZMax", zMax)
	folder.Parent = parent

	-- Le sol, et des taches de couleur pour qu'il ne soit pas uni.
	local ground = Build.part(folder, "Ground", Vector3.new(HALF_X * 2, 4, LENGTH), center + Vector3.new(0, -2, 0), theme.ground[1], theme.ground[2])
	ground.CanQuery = true
	for _ = 1, 26 do
		local size = random:NextNumber(24, 60)
		local patch = pillar(folder, "Patch", size, 0.1, center + Vector3.new(random:NextNumber(-HALF_X + 30, HALF_X - 30), 0, random:NextNumber(-LENGTH / 2 + 30, LENGTH / 2 - 30)), theme.patches[random:NextInteger(1, #theme.patches)], theme.ground[2])
		patch.CastShadow = false
	end
	-- Le chemin : de l'entrée à l'arène du boss, puis jusqu'à la porte suivante, avec un sentier vers chaque camp.
	local function trail(from: Vector3, to: Vector3, width: number)
		local middle = (from + to) / 2
		deco(folder, "Path", Vector3.new(width, 0.16, (to - from).Magnitude + width * 0.6), CFrame.lookAt(middle + Vector3.new(0, 0.08, 0), to + Vector3.new(0, 0.08, 0)), theme.path[1], theme.path[2]).CastShadow = false
	end
	trail(Vector3.new(0, 0, zMin), Vector3.new(0, 0, zMax), 11)
	for _, camp in CAMPS do
		trail(Vector3.new(0, 0, zMin + camp[2]), Vector3.new(camp[1] * 0.75, 0, zMin + camp[2]), 6)
	end
	pillar(folder, "Arena", ARENA * 2, 0.2, Vector3.new(0, 0, zMin + BOSS_Z), theme.path[1], theme.path[2]).CastShadow = false
	pillar(folder, "ArenaRing", ARENA * 2 + 3, 0.14, Vector3.new(0, 0, zMin + BOSS_Z), rgb(200, 50, 50), M.Neon).CastShadow = false

	-- Les bords : un mur qu'on ne voit pas, et devant lui une rangée de rochers de la couleur des falaises.
	for _, sign in { -1, 1 } do
		local wall = Build.part(folder, "Edge", Vector3.new(2, 80, LENGTH), Vector3.new(sign * (HALF_X + 1), 40, center.Z), NAVY)
		wall.Transparency = 1
		wall.CanQuery = false
		for z = zMin + 8, zMax - 8, 16 do
			local height = random:NextNumber(16, 30)
			deco(folder, "Cliff", Vector3.new(random:NextNumber(14, 22), height, random:NextNumber(16, 22)), CFrame.new(sign * (HALF_X + 4), height / 2 - 2, z) * CFrame.Angles(0, random:NextNumber(-0.3, 0.3), random:NextNumber(-0.06, 0.06)), theme.cliff[1], theme.cliff[2])
		end
	end
	-- La première zone commence au mur de la base, qui est moins large qu'elle : on ferme les deux côtés.
	if index == 1 then
		for _, sign in { -1, 1 } do
			local wall = Build.part(folder, "StartWall", Vector3.new(HALF_X - 84, 80, 4), Vector3.new(sign * (84 + (HALF_X - 84) / 2), 40, zMin - 2), NAVY)
			wall.Transparency = 1
			wall.CanQuery = false
			for x = 100, HALF_X, 16 do
				local height = random:NextNumber(18, 28)
				deco(folder, "Cliff", Vector3.new(17, height, 12), CFrame.new(sign * x, height / 2 - 2, zMin - 4) * CFrame.Angles(0, random:NextNumber(-0.15, 0.15), 0), theme.cliff[1], theme.cliff[2])
			end
		end
	end
	-- Le fond : une falaise avec une porte au milieu, vers la zone suivante.
	local side = HALF_X - GATE_W / 2
	for _, sign in { -1, 1 } do
		local wall = Build.part(folder, "EndWall", Vector3.new(side, 80, 6), Vector3.new(sign * (GATE_W / 2 + side / 2), 40, zMax), NAVY)
		wall.Transparency = 1
		wall.CanQuery = false
		for x = GATE_W / 2 + 8, HALF_X, 16 do
			local height = random:NextNumber(20, 34)
			deco(folder, "Cliff", Vector3.new(17, height, random:NextNumber(10, 14)), CFrame.new(sign * x, height / 2 - 2, zMax) * CFrame.Angles(0, random:NextNumber(-0.15, 0.15), 0), theme.cliff[1], theme.cliff[2])
		end
		Build.part(folder, "GatePost", Vector3.new(5, GATE_H + 8, 7), Vector3.new(sign * (GATE_W / 2 + 2.5), (GATE_H + 8) / 2, zMax), NAVY).CanQuery = false
		local flame = ball(folder, "GateFlame", 3, Vector3.new(sign * (GATE_W / 2 + 2.5), GATE_H + 9.6, zMax), rgb(255, 150, 40), M.Neon)
		local fire = Instance.new("Fire")
		fire.Size = 8
		fire.Heat = 10
		fire.Parent = flame
	end
	Build.part(folder, "GateLintel", Vector3.new(GATE_W + 10, 5, 7), Vector3.new(0, GATE_H + 2.5, zMax), NAVY).CanQuery = false
	-- La porte : fermée pour tout le monde ici ; l'écran du joueur qui a battu le boss la lui ouvre.
	local gate = Build.part(folder, "Gate", Vector3.new(GATE_W, GATE_H, 2), Vector3.new(0, GATE_H / 2, zMax), rgb(200, 40, 50), M.ForceField)
	gate.CanQuery = false
	gate:SetAttribute("Opens", index + 1)
	gate:AddTag("ZoneGate")
	local board = Build.part(folder, "GateSign", Vector3.new(GATE_W + 8, 4.4, 0.6), Vector3.new(0, GATE_H + 2.6, zMax - 3.8), rgb(24, 26, 36))
	board.CanQuery = false
	Build.sign(board, Enum.NormalId.Front, "zoneGate|" .. (index + 1))

	-- Les décors : d'abord les grands, puis ce qu'on sème. Rien sur le chemin, dans les camps ni dans l'arène.
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = folder
	theme.set(decor, center, random)
	local function free(x: number, z: number): boolean
		if math.abs(x) < 10 or Vector3.new(x, 0, z - BOSS_Z).Magnitude < ARENA + 6 then
			return false
		end
		for _, chest in CHESTS do
			if Vector3.new(x - chest[1], 0, z - chest[2]).Magnitude < 9 then
				return false
			end
		end
		for _, camp in CAMPS do
			if Vector3.new(x - camp[1], 0, z - camp[2]).Magnitude < CAMP_RADIUS + 5 or (math.abs(z - camp[2]) < 6 and math.abs(x) < math.abs(camp[1])) then
				return false
			end
		end
		return true
	end
	for kind, count in theme.scatter do
		for _ = 1, count do
			for _ = 1, 8 do
				local x, z = random:NextNumber(-HALF_X + 12, HALF_X - 12), random:NextNumber(10, LENGTH - 10)
				if free(x, z) then
					props[kind](decor, Vector3.new(x, 0, zMin + z), random)
					break
				end
			end
		end
	end

	-- À L'ENTRÉE DE CHAQUE CAMP (et devant l'arène du boss) : un mât blanc avec, d'un côté, la BANNIÈRE de l'animal
	-- (son niveau et son portrait) et, de l'autre, une pancarte en bois suspendue qui donne la CHANCE D'ŒUF de chaque
	-- note (C, B, A, S) par monstre battu. Les dessins sont faits par l'écran de chaque joueur (étiquettes
	-- « CampFlag » et « CampOdds ») ; ici, seulement les blocs.
	local function signpost(at: Vector3, rank: number)
		local def = Config.monster(index, rank)
		local gold, white = rgb(240, 180, 50), rgb(246, 244, 238)
		local function block(name: string, size: Vector3, offset: Vector3, color: Color3, material: Enum.Material?): Part
			local part = Build.part(folder, name, size, at + offset, color, material)
			part.CanQuery = false
			part.CanCollide = false
			return part
		end
		block("FlagPole", Vector3.new(0.8, 17, 0.8), Vector3.new(0, 8.5, 0), white).CanCollide = true
		ball(folder, "FlagTop", 1.6, at + Vector3.new(0, 17.4, 0), gold)
		block("FlagArm", Vector3.new(15, 0.6, 0.6), Vector3.new(0, 16, 0), gold)
		for _, y in { 5.5, 11 } do
			block("FlagRing", Vector3.new(1.2, 0.7, 1.2), Vector3.new(0, y, 0), gold)
		end
		-- La bannière, à droite du mât.
		local flag = block("CampFlag", Vector3.new(6.4, 9.4, 0.2), Vector3.new(4, 11, 0), if rank == 6 then rgb(170, 40, 50) else rgb(44, 62, 176), M.Fabric)
		flag:SetAttribute("Animal", Pets.COLLECTIONS[index][rank])
		flag:SetAttribute("Rank", rank)
		flag:SetAttribute("Level", def.level)
		flag:SetAttribute("Boss", rank == 6)
		flag:AddTag("CampFlag")
		for _, sign in { -1, 1 } do
			local tail = Instance.new("WedgePart")
			tail.Name = "FlagTail"
			tail.Anchored = true
			tail.CanCollide = false
			tail.CanQuery = false
			tail.Size = Vector3.new(0.2, 2.2, 3.2)
			tail.CFrame = CFrame.new(at + Vector3.new(4 + sign * 1.6, 5.2, 0)) * CFrame.Angles(0, math.rad(sign * 90), math.rad(180))
			tail.Color = flag.Color
			tail.Material = M.Fabric
			tail.Parent = folder
		end
		-- La pancarte des chances, à gauche, suspendue par deux attaches.
		local board = block("CampOdds", Vector3.new(5.6, 6.6, 0.4), Vector3.new(-4.2, 11.6, 0), rgb(176, 116, 62), M.WoodPlanks)
		board:SetAttribute("Egg", def.egg)
		board:AddTag("CampOdds")
		for _, x in { -5.8, -2.6 } do
			block("OddsHanger", Vector3.new(0.4, 1.3, 0.5), Vector3.new(x, 15.3, 0), rgb(120, 76, 40), M.Wood)
		end
		block("OddsTop", Vector3.new(6.2, 0.5, 0.6), Vector3.new(-4.2, 14.9, 0), gold)
	end
	for rank, camp in CAMPS do
		signpost(Vector3.new(if camp[1] > 0 then 10 else -10, 0, zMin + camp[2] - 7), rank)
	end
	signpost(Vector3.new(12, 0, zMin + BOSS_Z - ARENA - 4), 6)

	-- Où naissent les monstres : CAMP_SIZE par camp, en rond ; et le boss au milieu de son arène.
	local spawns = {}
	for rank, camp in CAMPS do
		for i = 1, CAMP_SIZE do
			local angle = i / CAMP_SIZE * math.pi * 2 + rank
			local away = random:NextNumber(CAMP_RADIUS - 8, CAMP_RADIUS - 3)
			table.insert(spawns, { rank = rank, position = Vector3.new(camp[1] + math.cos(angle) * away, 0, zMin + camp[2] + math.sin(angle) * away) })
		end
	end
	local chests = {}
	for _, chest in CHESTS do
		table.insert(chests, Vector3.new(chest[1], 0, zMin + chest[2]))
		pillar(folder, "ChestSpot", 9, 0.18, Vector3.new(chest[1], 0, zMin + chest[2]), rgb(236, 176, 48), M.Neon).CastShadow = false
	end
	return { index = index, folder = folder, zMin = zMin, zMax = zMax, center = center, spawns = spawns, chests = chests, boss = Vector3.new(0, 0, zMin + BOSS_Z), gate = gate }
end

-- Construit toutes les zones à la suite, à partir de z = `front` (la grande porte de la base).
function Zones.build(parent: Instance, front: number)
	local world = Instance.new("Folder")
	world.Name = "Zones"
	world.Parent = parent
	local zones = {}
	for index in Config.ZONES do
		zones[index] = buildZone(world, index, front + (index - 1) * LENGTH)
	end
	return zones
end

-- La zone où se trouve ce point (0 : la base).
function Zones.at(zones, position: Vector3): number
	for index, zone in zones do
		if position.Z >= zone.zMin and position.Z < zone.zMax then
			return index
		end
	end
	return 0
end

return Zones

-- LES ÉLÉMENTS DU DÉCOR, fabriqués avec des blocs : arbres, palmiers, buissons, fougères, clôtures, lampadaires,
-- bancs, panneaux et bâtiments en bois sombre (le style de l'image du créateur, 14/10 : un zoo à la Planet Zoo).
-- Les rochers, l'herbe, l'eau et les allées sont du terrain Roblox (Map.luau).
local Props = {}

local M = Enum.Material
local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end
Props.rgb = rgb

-- LES COULEURS DU ZOO
Props.WOOD = rgb(86, 62, 44) -- le bois sombre des bâtiments et des clôtures
Props.WOOD_LIGHT = rgb(132, 98, 66)
Props.ROOF = rgb(58, 48, 42)
Props.THATCH = rgb(170, 140, 88)
Props.STONE = rgb(128, 122, 112)
Props.IRON = rgb(40, 42, 44)
Props.CREAM = rgb(236, 226, 198)
local GREENS = { rgb(76, 140, 60), rgb(96, 158, 66), rgb(62, 124, 56), rgb(110, 170, 74), rgb(84, 150, 82), rgb(70, 132, 48) }
local PALMS = { rgb(70, 136, 56), rgb(58, 120, 50), rgb(86, 150, 62) }
local FLOWERS = { rgb(236, 84, 96), rgb(252, 196, 64), rgb(248, 246, 240), rgb(176, 112, 230), rgb(255, 140, 64) }

-- OUTILS ---------------------------------------------------------------------------------------------------------------
-- Un bloc du décor. solid : on bute dessus (sinon on passe à travers).
function Props.part(parent: Instance, name: string, size: Vector3, cframe: CFrame | Vector3, color: Color3, material: Enum.Material?, solid: boolean?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = if typeof(cframe) == "Vector3" then CFrame.new(cframe) else cframe
	part.Color = color
	part.Material = material or M.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = solid == true
	part.CanQuery = solid == true
	part.CanTouch = false
	part.CastShadow = size.Magnitude > 4
	part.Parent = parent
	return part
end
local part = Props.part

function Props.ball(parent: Instance, name: string, diameter: number, position: Vector3, color: Color3, material: Enum.Material?): Part
	local ball = part(parent, name, Vector3.one * diameter, position, color, material)
	ball.Shape = Enum.PartType.Ball
	return ball
end
local ball = Props.ball

-- Un cylindre d'un point à un autre (un tronc, une branche, un poteau).
function Props.stick(parent: Instance, name: string, from: Vector3, to: Vector3, diameter: number, color: Color3, material: Enum.Material?, solid: boolean?): Part
	local length = (to - from).Magnitude
	local stick = part(parent, name, Vector3.new(length, diameter, diameter), CFrame.lookAt((from + to) / 2, to) * CFrame.Angles(0, math.rad(90), 0), color, material, solid)
	stick.Shape = Enum.PartType.Cylinder
	return stick
end
local stick = Props.stick

-- Un toit à deux pentes au-dessus d'un rectangle (largeur le long de X, profondeur le long de Z), tourné de `yaw`.
function Props.roof(parent: Instance, base: CFrame, width: number, depth: number, rise: number, color: Color3, material: Enum.Material?)
	for _, sign in { -1, 1 } do
		local wedge = Instance.new("WedgePart")
		wedge.Name = "Roof"
		wedge.Anchored = true
		wedge.CanQuery = false
		wedge.CanTouch = false
		wedge.Size = Vector3.new(depth, rise, width / 2)
		wedge.CFrame = base * CFrame.new(sign * width / 4, rise / 2, 0) * CFrame.Angles(0, math.rad(-sign * 90), 0)
		wedge.Color = color
		wedge.Material = material or M.Slate
		wedge.TopSurface = Enum.SurfaceType.Smooth
		wedge.BottomSurface = Enum.SurfaceType.Smooth
		wedge.Parent = parent
	end
	-- Le faîte.
	part(parent, "Ridge", Vector3.new(0.8, 0.8, depth + 0.4), base * CFrame.new(0, rise + 0.1, 0), Props.WOOD, M.Wood)
end

-- Un texte sur la face d'un bloc (panneaux, enseignes).
function Props.label(target: BasePart, face: Enum.NormalId, text: string, color: Color3?, font: Enum.Font?): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.6
	gui.Parent = target
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextScaled = true
	label.Font = font or Enum.Font.FredokaOne
	label.TextColor3 = color or Props.CREAM
	label.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.06, 0)
	pad.PaddingRight = UDim.new(0.06, 0)
	pad.PaddingTop = UDim.new(0.1, 0)
	pad.PaddingBottom = UDim.new(0.1, 0)
	pad.Parent = label
	return label
end

-- LA VÉGÉTATION ----------------------------------------------------------------------------------------------------------
-- Un grand arbre feuillu : un tronc un peu tordu, deux ou trois branches, et une couronne de boules de feuilles.
function Props.tree(parent: Instance, at: Vector3, random: Random, scale: number?)
	local k = (scale or 1) * random:NextNumber(0.8, 1.25)
	local model = Instance.new("Model")
	model.Name = "Tree"
	local height = random:NextNumber(12, 17) * k
	local lean = Vector3.new(random:NextNumber(-1, 1), 0, random:NextNumber(-1, 1)) * 1.6 * k
	local middle = at + Vector3.new(0, height * 0.55, 0) + lean * 0.5
	local top = at + Vector3.new(0, height, 0) + lean
	local bark = rgb(92 + random:NextInteger(-10, 10), 70, 52)
	stick(model, "Trunk", at - Vector3.new(0, 1, 0), middle, 2.4 * k, bark, M.Wood, true)
	stick(model, "Trunk", middle, top, 1.7 * k, bark, M.Wood)
	local crowns = {}
	for i = 1, random:NextInteger(2, 3) do
		local angle = i * 2.3 + random:NextNumber(0, 1)
		local tip = middle + Vector3.new(math.cos(angle) * 5 * k, random:NextNumber(3, 5) * k, math.sin(angle) * 5 * k)
		stick(model, "Branch", middle, tip, 0.9 * k, bark, M.Wood)
		table.insert(crowns, tip)
	end
	table.insert(crowns, top)
	for _, spot in crowns do
		for _ = 1, 2 do
			local offset = Vector3.new(random:NextNumber(-2.5, 2.5), random:NextNumber(0, 2.5), random:NextNumber(-2.5, 2.5)) * k
			local leaves = ball(model, "Leaves", random:NextNumber(7, 11) * k, spot + offset, GREENS[random:NextInteger(1, #GREENS)], M.Grass)
			leaves.CastShadow = true
		end
	end
	model.Parent = parent
	return model
end

-- Un palmier : un tronc courbé fait de tronçons, des palmes qui retombent, des noix de coco.
function Props.palm(parent: Instance, at: Vector3, random: Random, scale: number?)
	local k = (scale or 1) * random:NextNumber(0.85, 1.3)
	local model = Instance.new("Model")
	model.Name = "Palm"
	local heading = random:NextNumber(0, math.pi * 2)
	local bend = Vector3.new(math.cos(heading), 0, math.sin(heading))
	local point = at - Vector3.new(0, 0.5, 0)
	local count = 7
	for i = 1, count do
		local t = i / count
		local nextPoint = at + Vector3.new(0, 2.6 * k * i, 0) + bend * (t * t) * 5 * k
		stick(model, "Trunk", point, nextPoint, (1.6 - 0.5 * t) * k, rgb(132, 108, 80), M.Wood, i == 1)
		point = nextPoint
	end
	local top = point
	for i = 1, 9 do
		local angle = i / 9 * math.pi * 2 + random:NextNumber(-0.2, 0.2)
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local from = top
		local color = PALMS[random:NextInteger(1, #PALMS)]
		for j = 1, 3 do
			local droop = (0.2 + j * 0.45) * k
			local to = from + out * 2.8 * k - Vector3.new(0, droop, 0)
			local leaf = part(model, "Frond", Vector3.new((2.2 - j * 0.45) * k, 0.15, (from - to).Magnitude + 0.3), CFrame.lookAt((from + to) / 2, to), color, M.Grass)
			leaf.CastShadow = true
			from = to
		end
	end
	for i = 1, 3 do
		ball(model, "Coconut", 0.9 * k, top + Vector3.new(math.cos(i * 2.1) * 0.8 * k, -0.7 * k, math.sin(i * 2.1) * 0.8 * k), rgb(86, 62, 40), M.Wood)
	end
	model.Parent = parent
	return model
end

-- Un arbre de la jungle : très haut, droit, avec une couronne large et plate.
function Props.jungleTree(parent: Instance, at: Vector3, random: Random, scale: number?)
	local k = (scale or 1) * random:NextNumber(0.85, 1.2)
	local model = Instance.new("Model")
	model.Name = "JungleTree"
	local height = random:NextNumber(22, 30) * k
	local top = at + Vector3.new(random:NextNumber(-1, 1), height, random:NextNumber(-1, 1))
	local bark = rgb(110, 98, 80)
	stick(model, "Trunk", at - Vector3.new(0, 1, 0), top, 2.2 * k, bark, M.Wood, true)
	-- Les racines en contrefort.
	for i = 1, 4 do
		local angle = i * math.pi / 2 + random:NextNumber(-0.3, 0.3)
		stick(model, "Root", at + Vector3.new(0, 3.5 * k, 0), at + Vector3.new(math.cos(angle) * 3 * k, -0.3, math.sin(angle) * 3 * k), 0.9 * k, bark, M.Wood)
	end
	for _ = 1, 6 do
		local angle = random:NextNumber(0, math.pi * 2)
		local radius = random:NextNumber(0, 6) * k
		local leaves = ball(model, "Leaves", random:NextNumber(8, 12) * k, top + Vector3.new(math.cos(angle) * radius, random:NextNumber(-1.5, 1.5), math.sin(angle) * radius), GREENS[random:NextInteger(1, #GREENS)], M.Grass)
		leaves.Size = Vector3.new(leaves.Size.X, leaves.Size.Y, leaves.Size.Z)
		leaves.CastShadow = true
	end
	model.Parent = parent
	return model
end

-- Un conifère (pour la forêt des cerfs, des loups, des ours) : des boules de plus en plus petites vers le haut.
function Props.pine(parent: Instance, at: Vector3, random: Random, scale: number?)
	local k = (scale or 1) * random:NextNumber(0.85, 1.3)
	local model = Instance.new("Model")
	model.Name = "Pine"
	stick(model, "Trunk", at - Vector3.new(0, 1, 0), at + Vector3.new(0, 6 * k, 0), 1.4 * k, rgb(84, 62, 46), M.Wood, true)
	local greens = { rgb(44, 96, 58), rgb(54, 110, 64), rgb(38, 86, 52) }
	for i = 0, 5 do
		local width = (8.5 - i * 1.25) * k
		local layer = ball(model, "Needles", width, at + Vector3.new(random:NextNumber(-0.3, 0.3), (4.5 + i * 2.6) * k, random:NextNumber(-0.3, 0.3)), greens[i % 3 + 1], M.Grass)
		layer.Size = Vector3.new(width, width * 0.8, width)
		layer.CastShadow = true
	end
	model.Parent = parent
	return model
end

-- Un buisson (avec des fleurs, parfois).
function Props.bush(parent: Instance, at: Vector3, random: Random, scale: number?, flowers: boolean?)
	local k = (scale or 1) * random:NextNumber(0.8, 1.3)
	local model = Instance.new("Model")
	model.Name = "Bush"
	for _ = 1, random:NextInteger(3, 5) do
		local offset = Vector3.new(random:NextNumber(-1.8, 1.8), random:NextNumber(0.6, 1.6), random:NextNumber(-1.8, 1.8)) * k
		ball(model, "Leaves", random:NextNumber(2.6, 4.2) * k, at + offset, GREENS[random:NextInteger(1, #GREENS)], M.Grass)
	end
	if flowers then
		local color = FLOWERS[random:NextInteger(1, #FLOWERS)]
		for _ = 1, 7 do
			local angle = random:NextNumber(0, math.pi * 2)
			ball(model, "Flower", 0.55 * k, at + Vector3.new(math.cos(angle) * 2 * k, random:NextNumber(1.6, 3) * k, math.sin(angle) * 2 * k), color)
		end
	end
	model.Parent = parent
	return model
end

-- Une fougère : des feuilles en éventail.
function Props.fern(parent: Instance, at: Vector3, random: Random, scale: number?)
	local k = (scale or 1) * random:NextNumber(0.8, 1.3)
	local model = Instance.new("Model")
	model.Name = "Fern"
	local color = GREENS[random:NextInteger(1, #GREENS)]
	for i = 1, 7 do
		local angle = i / 7 * math.pi * 2 + random:NextNumber(-0.3, 0.3)
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local from = at + Vector3.new(0, 0.2, 0)
		local mid = from + out * 1.6 * k + Vector3.new(0, 1.3 * k, 0)
		local to = mid + out * 1.6 * k - Vector3.new(0, 0.6 * k, 0)
		part(model, "Leaf", Vector3.new(0.9 * k, 0.1, (mid - from).Magnitude), CFrame.lookAt((from + mid) / 2, mid), color, M.Grass)
		part(model, "Leaf", Vector3.new(0.7 * k, 0.1, (to - mid).Magnitude), CFrame.lookAt((mid + to) / 2, to), color, M.Grass)
	end
	model.Parent = parent
	return model
end

-- Des herbes hautes (pour la savane et les terrains à vendre).
function Props.tallGrass(parent: Instance, at: Vector3, random: Random, color: Color3?)
	local model = Instance.new("Model")
	model.Name = "TallGrass"
	for _ = 1, 6 do
		local spot = at + Vector3.new(random:NextNumber(-1.2, 1.2), 0, random:NextNumber(-1.2, 1.2))
		local height = random:NextNumber(1.6, 3)
		part(model, "Blade", Vector3.new(0.18, height, 0.18), CFrame.new(spot + Vector3.new(0, height / 2, 0)) * CFrame.Angles(random:NextNumber(-0.25, 0.25), 0, random:NextNumber(-0.25, 0.25)), color or rgb(176, 160, 92), M.Grass).CastShadow = false
	end
	model.Parent = parent
	return model
end

-- Un parterre de fleurs rond, bordé de pierres.
function Props.flowerBed(parent: Instance, at: Vector3, radius: number, random: Random)
	local model = Instance.new("Model")
	model.Name = "FlowerBed"
	local soil = part(model, "Soil", Vector3.new(0.6, radius * 2, radius * 2), CFrame.new(at + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), rgb(84, 62, 46), M.Ground)
	soil.Shape = Enum.PartType.Cylinder
	local stones = math.floor(radius * 2.4)
	for i = 1, stones do
		local angle = i / stones * math.pi * 2
		ball(model, "Stone", random:NextNumber(0.9, 1.3), at + Vector3.new(math.cos(angle) * radius, 0.3, math.sin(angle) * radius), Props.STONE, M.Slate)
	end
	for _ = 1, math.floor(radius * radius * 1.2) do
		local angle, distance = random:NextNumber(0, math.pi * 2), math.sqrt(random:NextNumber()) * (radius - 0.8)
		local spot = at + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		part(model, "Stem", Vector3.new(0.15, 1.1, 0.15), spot + Vector3.new(0, 0.9, 0), rgb(60, 130, 56)).CastShadow = false
		ball(model, "Flower", 0.65, spot + Vector3.new(0, 1.5, 0), FLOWERS[random:NextInteger(1, #FLOWERS)])
	end
	model.Parent = parent
	return model
end

-- LES CLÔTURES -----------------------------------------------------------------------------------------------------------
-- Une clôture rustique (ferme, cerfs) : des poteaux et deux lisses en bois sombre. Elle arrête le joueur.
function Props.woodFence(parent: Instance, from: Vector3, to: Vector3)
	local count = math.max(1, math.round((to - from).Magnitude / 5))
	local step = (to - from) / count
	for i = 0, count do
		part(parent, "Post", Vector3.new(0.9, 4.4, 0.9), from + step * i + Vector3.new(0, 2.2, 0), Props.WOOD, M.Wood, true)
	end
	local length = (to - from).Magnitude
	for _, y in { 1.5, 3.4 } do
		part(parent, "Rail", Vector3.new(0.35, 0.55, length), CFrame.lookAt((from + to) / 2 + Vector3.new(0, y, 0), to + Vector3.new(0, y, 0)), Props.WOOD_LIGHT, M.Wood, true)
	end
end

-- Une clôture pour les animaux sauvages : un muret de pierre, de hauts rondins, et des vitres côté visiteurs.
function Props.wildFence(parent: Instance, from: Vector3, to: Vector3, glass: boolean?)
	local length = (to - from).Magnitude
	local along = CFrame.lookAt((from + to) / 2, to)
	part(parent, "Wall", Vector3.new(1.6, 2.4, length), along * CFrame.new(0, 1.2, 0), Props.STONE, M.Cobblestone, true)
	if glass then
		local pane = part(parent, "Glass", Vector3.new(0.3, 7, length), along * CFrame.new(0, 5.9, 0), rgb(190, 220, 230), M.Glass, true)
		pane.Transparency = 0.75
		pane.CastShadow = false
		local count = math.max(1, math.round(length / 8))
		for i = 0, count do
			part(parent, "Frame", Vector3.new(0.6, 7.4, 0.6), along * CFrame.new(0, 5.9, -length / 2 + length * i / count), Props.IRON, M.Metal, true)
		end
		part(parent, "Frame", Vector3.new(0.5, 0.5, length), along * CFrame.new(0, 9.5, 0), Props.IRON, M.Metal, true)
	else
		local count = math.max(1, math.round(length / 1.3))
		for i = 0, count - 1 do
			local z = -length / 2 + (i + 0.5) * length / count
			local height = 8 + (i % 3) * 0.4
			local log = part(parent, "Log", Vector3.new(height, 1.25, 1.25), along * CFrame.new(0, 2.4 + height / 2, z) * CFrame.Angles(0, 0, math.rad(90)), if i % 2 == 0 then Props.WOOD else Props.WOOD_LIGHT, M.Wood, true)
			log.Shape = Enum.PartType.Cylinder
			log.CastShadow = false
		end
		part(parent, "Rail", Vector3.new(0.6, 0.6, length), along * CFrame.new(0.7, 8.5, 0), Props.WOOD, M.Wood)
	end
end

-- LE MOBILIER DES ALLÉES ---------------------------------------------------------------------------------------------
-- Un lampadaire. Sa lumière s'allume le soir (Map.setNight).
function Props.lamp(parent: Instance, at: Vector3)
	local model = Instance.new("Model")
	model.Name = "Lamp"
	part(model, "Post", Vector3.new(0.5, 9, 0.5), at + Vector3.new(0, 4.5, 0), Props.IRON, M.Metal, true)
	part(model, "Base", Vector3.new(1.1, 0.8, 1.1), at + Vector3.new(0, 0.4, 0), Props.IRON, M.Metal)
	part(model, "Top", Vector3.new(1.8, 0.3, 1.8), at + Vector3.new(0, 10.2, 0), Props.IRON, M.Metal)
	local bulb = part(model, "Bulb", Vector3.new(1.2, 1.3, 1.2), at + Vector3.new(0, 9.5, 0), rgb(255, 214, 150), M.Glass)
	bulb.CastShadow = false
	local light = Instance.new("PointLight")
	light.Name = "NightLight"
	light.Color = rgb(255, 196, 120)
	light.Range = 22
	light.Brightness = 1.4
	light.Shadows = false
	light.Enabled = false
	light.Parent = bulb
	model.Parent = parent
	return model
end

-- Un banc en bois, tourné vers `facing`.
function Props.bench(parent: Instance, at: Vector3, facing: Vector3)
	local model = Instance.new("Model")
	model.Name = "Bench"
	local base = CFrame.lookAt(at, at + facing)
	part(model, "Seat", Vector3.new(5, 0.35, 1.6), base * CFrame.new(0, 1.6, 0), Props.WOOD_LIGHT, M.Wood, true)
	part(model, "Back", Vector3.new(5, 1.4, 0.3), base * CFrame.new(0, 2.6, 0.75) * CFrame.Angles(math.rad(-10), 0, 0), Props.WOOD_LIGHT, M.Wood)
	for _, x in { -2, 2 } do
		part(model, "Leg", Vector3.new(0.35, 1.6, 1.4), base * CFrame.new(x, 0.8, 0), Props.IRON, M.Metal)
	end
	model.Parent = parent
	return model
end

-- Une poubelle (les papiers des visiteurs).
function Props.bin(parent: Instance, at: Vector3)
	local bin = part(parent, "Bin", Vector3.new(2.6, 1.6, 1.6), CFrame.new(at + Vector3.new(0, 1.3, 0)) * CFrame.Angles(0, 0, math.rad(90)), rgb(46, 80, 56), M.Metal, true)
	bin.Shape = Enum.PartType.Cylinder
	return bin
end

-- Un panneau en bois sur deux poteaux, avec un texte. facing : la direction vers laquelle on lit le panneau.
function Props.sign(parent: Instance, at: Vector3, facing: Vector3, text: string, width: number?, color: Color3?): Part
	local w = width or 8
	local base = CFrame.lookAt(at, at + facing)
	for _, x in { -w / 2 + 0.5, w / 2 - 0.5 } do
		part(parent, "SignPost", Vector3.new(0.5, 6, 0.5), base * CFrame.new(x, 3, 0), Props.WOOD, M.Wood, true)
	end
	local board = part(parent, "Sign", Vector3.new(w, 2.6, 0.4), base * CFrame.new(0, 4.8, 0), Props.WOOD, M.WoodPlanks, true)
	Props.label(board, Enum.NormalId.Front, text, color)
	return board
end

-- LES BÂTIMENTS ----------------------------------------------------------------------------------------------------------
-- Un pavillon en bois sombre sur un socle de pierre, avec un grand toit qui déborde. `base` : le milieu du sol, tourné
-- vers sa façade (-Z local). openFront : la façade est ouverte (un comptoir, un abri).
function Props.lodge(parent: Instance, base: CFrame, width: number, depth: number, height: number, options)
	options = options or {}
	local model = Instance.new("Model")
	model.Name = options.name or "Lodge"
	part(model, "Floor", Vector3.new(width + 1, 0.8, depth + 1), base * CFrame.new(0, 0.4, 0), Props.STONE, M.Cobblestone, true)
	local wall = options.wall or Props.WOOD
	-- Les murs (sauf la façade, si elle est ouverte).
	part(model, "Wall", Vector3.new(width, height, 0.8), base * CFrame.new(0, height / 2 + 0.8, depth / 2), wall, M.WoodPlanks, true)
	for _, x in { -1, 1 } do
		part(model, "Wall", Vector3.new(0.8, height, depth), base * CFrame.new(x * width / 2, height / 2 + 0.8, 0), wall, M.WoodPlanks, true)
	end
	if not options.openFront then
		local door = options.door or 5
		local side = (width - door) / 2
		for _, x in { -1, 1 } do
			part(model, "Wall", Vector3.new(side, height, 0.8), base * CFrame.new(x * (door / 2 + side / 2), height / 2 + 0.8, -depth / 2), wall, M.WoodPlanks, true)
		end
		part(model, "Wall", Vector3.new(door, height - 7, 0.8), base * CFrame.new(0, 7.8 + (height - 7) / 2, -depth / 2), wall, M.WoodPlanks, true)
	else
		-- Un comptoir sur toute la façade.
		part(model, "Counter", Vector3.new(width - 1.6, 3.4, 1.4), base * CFrame.new(0, 2.5, -depth / 2 + 0.4), Props.WOOD_LIGHT, M.Wood, true)
	end
	-- Les poteaux d'angle et le toit.
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			part(model, "Beam", Vector3.new(1.2, height + 1, 1.2), base * CFrame.new(x * (width / 2 + 1.2), (height + 1) / 2 + 0.8, z * (depth / 2 + 1.2)), Props.WOOD, M.Wood, true)
		end
	end
	part(model, "Eave", Vector3.new(width + 4, 0.6, depth + 4), base * CFrame.new(0, height + 1.1, 0), Props.WOOD, M.Wood)
	Props.roof(model, base * CFrame.new(0, height + 1.4, 0), width + 5, depth + 5, options.rise or height * 0.55, options.roof or Props.ROOF, options.roofMaterial or M.Slate)
	-- L'enseigne au-dessus de la façade.
	if options.title then
		local board = part(model, "Sign", Vector3.new(math.min(width - 2, 16), 2.4, 0.4), base * CFrame.new(0, height - 0.6, -depth / 2 - 2.6), Props.WOOD, M.WoodPlanks)
		Props.label(board, Enum.NormalId.Front, options.title)
		Props.label(board, Enum.NormalId.Back, options.title)
	end
	model.Parent = parent
	return model
end

-- Un abri pour les animaux (un toit sur des poteaux, de la paille).
function Props.shelter(parent: Instance, base: CFrame, width: number, depth: number, thatch: boolean?)
	local model = Instance.new("Model")
	model.Name = "Shelter"
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			part(model, "Post", Vector3.new(0.9, 6.5, 0.9), base * CFrame.new(x * width / 2, 3.25, z * depth / 2), Props.WOOD, M.Wood, true)
		end
	end
	part(model, "Wall", Vector3.new(width, 6.5, 0.6), base * CFrame.new(0, 3.25, depth / 2), Props.WOOD_LIGHT, M.WoodPlanks, true)
	Props.roof(model, base * CFrame.new(0, 6.5, 0), width + 2.5, depth + 2.5, 3.2, if thatch then Props.THATCH else Props.ROOF, if thatch then M.Grass else M.Slate)
	part(model, "Straw", Vector3.new(width - 1, 0.3, depth - 1), base * CFrame.new(0, 0.15, 0), rgb(214, 188, 110), M.Grass).CastShadow = false
	model.Parent = parent
	return model
end

-- Une mangeoire : un bac en bois ; la nourriture dedans monte et descend avec le niveau (Enclosures.luau).
function Props.trough(parent: Instance, base: CFrame, foodColor: Color3): (Model, Part)
	local model = Instance.new("Model")
	model.Name = "Trough"
	part(model, "Box", Vector3.new(6, 0.5, 2.4), base * CFrame.new(0, 0.8, 0), Props.WOOD_LIGHT, M.Wood, true)
	for _, z in { -1, 1 } do
		part(model, "Side", Vector3.new(6, 1.4, 0.3), base * CFrame.new(0, 1.5, z * 1.1), Props.WOOD, M.Wood, true)
	end
	for _, x in { -1, 1 } do
		part(model, "Side", Vector3.new(0.3, 1.4, 2.4), base * CFrame.new(x * 2.9, 1.5, 0), Props.WOOD, M.Wood, true)
		part(model, "Leg", Vector3.new(0.5, 0.8, 2.2), base * CFrame.new(x * 2.6, 0.3, 0), Props.WOOD, M.Wood)
	end
	local food = part(model, "Food", Vector3.new(5.4, 1, 1.9), base * CFrame.new(0, 1.55, 0), foodColor, M.Grass)
	food.CastShadow = false
	model.Parent = parent
	return model, food
end

return Props

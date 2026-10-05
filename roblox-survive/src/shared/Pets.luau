-- Les animaux : chaque salle donne l'œuf de son animal ; la rareté est tirée quand l'œuf éclot dans la couveuse.
-- Le même animal existe en 4 raretés : plus il est rare, plus son pouvoir est fort (et plus il est gros et brillant).
-- On n'en équipe qu'un à la fois.
local AssetService = game:GetService("AssetService")

local Pets = {}
local gradient
local PetModels = require(script.Parent.PetModels)

Pets.ORDER = { "Dragon", "Rock", "Rabbit", "Golem", "Owl" }

-- power : ce que fait l'animal ; values : la force du pouvoir pour chaque rareté (commun, rare, épique, légendaire).
-- size : grosseur de l'animal (1 si absent). Le dragon est gros : on monte dessus pendant le vol plané.
Pets.DEFS = {
	Dragon = { power = "glide", values = { 1, 1.5, 2, 3 }, size = 1.8 }, -- secondes de vol plané (sauter une 2e fois en l'air)
	Rock = { power = "shield", values = { 40, 70, 110, 160 } }, -- dégâts encaissés par salle (pas la lave ni le plafond)
	Rabbit = { power = "speed", values = { 4, 7, 10, 15 } }, -- % de vitesse en plus
	Golem = { power = "force", values = { 3, 6, 10, 15 } }, -- force en plus pour repousser le plafond
	Owl = { power = "coins", values = { 5, 10, 15, 25 } }, -- % de pièces en plus
}

-- Chaque rareté a son MÉLANGE de couleurs, peint sur l'animal lui-même : un dégradé de toute la palette recouvre
-- son corps (plusieurs couleurs visibles en même temps), et le contour et les anneaux tournent dans la palette.
-- commun = ses couleurs d'origine ; rare = bleu, turquoise, vert ; épique = doré, orange, rose ;
-- légendaire = violet, rose, bleu, turquoise, et des étincelles.
-- color : la couleur de la rareté dans les textes ; tint : force du voile de couleur si le dégradé ne peut pas
-- être peint (voir gradient plus bas).
Pets.RARITIES = {
	{ key = "Common", color = Color3.fromRGB(200, 204, 214), scale = 1, tint = 0 },
	{
		key = "Rare",
		color = Color3.fromRGB(60, 150, 255),
		scale = 1.12,
		tint = 0.4,
		palette = { Color3.fromRGB(40, 110, 255), Color3.fromRGB(50, 225, 255), Color3.fromRGB(60, 235, 150) },
	},
	{
		key = "Epic",
		color = Color3.fromRGB(255, 200, 40),
		scale = 1.25,
		tint = 0.45,
		palette = { Color3.fromRGB(255, 210, 40), Color3.fromRGB(255, 120, 30), Color3.fromRGB(255, 80, 150) },
	},
	{
		key = "Legendary",
		color = Color3.fromRGB(190, 90, 255),
		scale = 1.4,
		tint = 0.5,
		palette = {
			Color3.fromRGB(160, 70, 255),
			Color3.fromRGB(255, 80, 210),
			Color3.fromRGB(70, 110, 255),
			Color3.fromRGB(50, 235, 225),
		},
	},
}
Pets.COLOR_SECONDS = 1.3 -- temps pour passer d'une couleur de la palette à la suivante

-- Chances de chaque rareté (sur 100) dans la salle 1, et ce qui change à chaque salle suivante.
Pets.ODDS = { 60, 28, 10, 2 }
Pets.ODDS_PER_ROOM = { -3, 1.5, 1, 0.5 }
-- Un animal déjà possédé en aussi bien ou mieux : des pièces à la place.
Pets.DUPLICATE_COINS = { 100, 300, 1000, 5000 }

Pets.MAX_EGGS = 12 -- œufs gardés en attente
Pets.SLOTS = 2 -- couveuses
Pets.GLIDE_COOLDOWN = 6 -- secondes entre deux vols planés
Pets.GLIDE_FALL = 2 -- vitesse de chute pendant le vol (studs par seconde)

-- Temps de couvaison de l'œuf d'une salle, en secondes (30 s pour la salle 1, 5 min pour la salle 10).
function Pets.hatchSeconds(room: number): number
	return 30 * room
end

function Pets.odds(room: number): { number }
	local odds = {}
	for i, base in Pets.ODDS do
		odds[i] = math.max(1, base + Pets.ODDS_PER_ROOM[i] * (room - 1))
	end
	return odds
end

-- Tire une rareté (1 à 4) pour un œuf de cette salle.
function Pets.roll(random: Random, room: number): number
	local odds = Pets.odds(room)
	local total = 0
	for _, weight in odds do
		total += weight
	end
	local pick = random:NextNumber(0, total)
	for i, weight in odds do
		pick -= weight
		if pick <= 0 then
			return i
		end
	end
	return 1
end

-- Grosseur de cet animal par rapport aux autres.
function Pets.size(name: string): number
	local def = Pets.DEFS[name]
	return def and def.size or 1
end

-- Force du pouvoir de cet animal à cette rareté.
function Pets.value(name: string, rarity: number): number
	local def = Pets.DEFS[name]
	return def and def.values[math.clamp(rarity, 1, #def.values)] or 0
end

-- « Dragon:2,Rock:1 » <-> { Dragon = 2, Rock = 1 } (pour envoyer la collection à l'écran du joueur).
function Pets.encode(owned: { [string]: number }): string
	local list = {}
	for _, name in Pets.ORDER do
		if owned[name] then
			table.insert(list, name .. ":" .. owned[name])
		end
	end
	return table.concat(list, ",")
end

function Pets.decode(text: string?): { [string]: number }
	local owned = {}
	for name, rarity in string.gmatch(text or "", "(%a+):(%d+)") do
		owned[name] = tonumber(rarity)
	end
	return owned
end

-- MODÈLES DE SECOURS pour les anciennes places sans assets/pets --------------------------------------------------
local function piece(model: Model, name: string, size: Vector3, offset: CFrame | Vector3, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = if typeof(offset) == "Vector3" then CFrame.new(offset) else offset
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Shape = shape or Enum.PartType.Block
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	return part
end

local BLACK = Color3.fromRGB(20, 20, 26)
local WHITE = Color3.fromRGB(250, 250, 250)

local function eyes(model: Model, x: number, y: number, z: number, size: number)
	for _, side in { -1, 1 } do
		piece(model, "Eye", Vector3.new(size, size, 0.15), Vector3.new(side * x, y, z), WHITE)
		piece(model, "Pupil", Vector3.new(size * 0.5, size * 0.5, 0.16), Vector3.new(side * x, y, z - 0.03), BLACK)
	end
end

-- Tous les modèles regardent vers -Z (l'avant d'un personnage Roblox).
local BUILDERS = {
	Dragon = function(model: Model)
		local red, dark = Color3.fromRGB(230, 70, 40), Color3.fromRGB(150, 36, 24)
		piece(model, "Body", Vector3.new(1.8, 1.4, 3), Vector3.new(0, 0, 0), red)
		piece(model, "Belly", Vector3.new(1.4, 0.3, 2.4), Vector3.new(0, -0.6, 0), Color3.fromRGB(255, 190, 80))
		piece(model, "Head", Vector3.new(1.4, 1.2, 1.4), Vector3.new(0, 0.6, -2), red)
		piece(model, "Snout", Vector3.new(0.9, 0.6, 0.7), Vector3.new(0, 0.35, -2.9), dark)
		eyes(model, 0.4, 0.85, -2.72, 0.4)
		for _, side in { -1, 1 } do
			piece(model, "Horn", Vector3.new(0.25, 0.7, 0.25), CFrame.new(side * 0.45, 1.45, -1.7) * CFrame.Angles(math.rad(25), 0, 0), Color3.fromRGB(255, 225, 150))
			piece(model, "Wing", Vector3.new(2.6, 0.15, 1.9), CFrame.new(side * 2, 0.7, 0.1) * CFrame.Angles(0, 0, math.rad(side * 18)), dark)
		end
		piece(model, "Tail", Vector3.new(0.7, 0.6, 1.8), CFrame.new(0, 0.1, 2.2) * CFrame.Angles(math.rad(-15), 0, 0), red)
		piece(model, "Flame", Vector3.new(0.6, 0.6, 0.6), Vector3.new(0, 0.5, 3.1), Color3.fromRGB(255, 150, 30), Enum.Material.Neon, Enum.PartType.Ball)
	end,
	Rock = function(model: Model)
		local stone = Color3.fromRGB(96, 90, 92)
		piece(model, "Body", Vector3.new(2.4, 2.4, 2.4), Vector3.new(0, 0, 0), stone, Enum.Material.Slate, Enum.PartType.Ball)
		for i, spot in { Vector3.new(0.7, 0.8, 0.5), Vector3.new(-0.9, -0.2, 0.6), Vector3.new(0.2, -0.9, -0.5), Vector3.new(-0.5, 0.9, -0.4) } do
			piece(model, "Ember" .. i, Vector3.new(0.5, 0.5, 0.5), spot, Color3.fromRGB(255, 130, 30), Enum.Material.Neon, Enum.PartType.Ball)
		end
		eyes(model, 0.45, 0.25, -1.15, 0.45)
	end,
	Rabbit = function(model: Model)
		piece(model, "Body", Vector3.new(1.5, 1.4, 1.9), Vector3.new(0, 0, 0), WHITE)
		piece(model, "Head", Vector3.new(1.3, 1.2, 1.2), Vector3.new(0, 0.9, -0.9), WHITE)
		for _, side in { -1, 1 } do
			piece(model, "Ear", Vector3.new(0.35, 1.5, 0.25), CFrame.new(side * 0.35, 2.1, -0.8) * CFrame.Angles(0, 0, math.rad(-side * 8)), WHITE)
			piece(model, "InnerEar", Vector3.new(0.18, 1.1, 0.26), CFrame.new(side * 0.35, 2.1, -0.82) * CFrame.Angles(0, 0, math.rad(-side * 8)), Color3.fromRGB(255, 160, 190))
			piece(model, "Foot", Vector3.new(0.5, 0.3, 0.9), Vector3.new(side * 0.5, -0.8, -0.3), WHITE)
		end
		eyes(model, 0.32, 1.05, -1.52, 0.3)
		piece(model, "Nose", Vector3.new(0.22, 0.18, 0.15), Vector3.new(0, 0.8, -1.55), Color3.fromRGB(255, 120, 160))
		piece(model, "Tail", Vector3.new(0.6, 0.6, 0.6), Vector3.new(0, 0.1, 1.1), WHITE, nil, Enum.PartType.Ball)
	end,
	Golem = function(model: Model)
		local stone, moss = Color3.fromRGB(120, 124, 132), Color3.fromRGB(90, 170, 90)
		piece(model, "Body", Vector3.new(2, 2, 1.4), Vector3.new(0, 0, 0), stone, Enum.Material.Slate)
		piece(model, "Head", Vector3.new(1.2, 1, 1.1), Vector3.new(0, 1.5, -0.1), stone, Enum.Material.Slate)
		piece(model, "Moss", Vector3.new(1.3, 0.25, 1.2), Vector3.new(0, 2.05, -0.1), moss)
		for _, side in { -1, 1 } do
			piece(model, "Arm", Vector3.new(0.8, 2, 0.9), Vector3.new(side * 1.5, -0.2, 0), stone, Enum.Material.Slate)
			piece(model, "Fist", Vector3.new(1, 0.8, 1.1), Vector3.new(side * 1.5, -1.4, 0), Color3.fromRGB(96, 100, 108), Enum.Material.Slate)
			piece(model, "Leg", Vector3.new(0.8, 0.9, 0.9), Vector3.new(side * 0.55, -1.4, 0), stone, Enum.Material.Slate)
		end
		for _, side in { -1, 1 } do
			piece(model, "Eye", Vector3.new(0.3, 0.25, 0.15), Vector3.new(side * 0.3, 1.55, -0.68), Color3.fromRGB(90, 255, 200), Enum.Material.Neon)
		end
	end,
	Owl = function(model: Model)
		local brown, cream = Color3.fromRGB(140, 96, 60), Color3.fromRGB(240, 220, 180)
		piece(model, "Body", Vector3.new(1.9, 2.2, 1.7), Vector3.new(0, 0, 0), brown)
		piece(model, "Chest", Vector3.new(1.3, 1.3, 0.2), Vector3.new(0, -0.3, -0.82), cream)
		for _, side in { -1, 1 } do
			piece(model, "Tuft", Vector3.new(0.4, 0.6, 0.4), CFrame.new(side * 0.7, 1.3, 0) * CFrame.Angles(0, 0, math.rad(-side * 20)), brown)
			piece(model, "Wing", Vector3.new(0.3, 1.5, 1.2), CFrame.new(side * 1.1, -0.1, 0.1) * CFrame.Angles(0, 0, math.rad(side * 10)), Color3.fromRGB(110, 74, 46))
			piece(model, "Foot", Vector3.new(0.5, 0.2, 0.6), Vector3.new(side * 0.45, -1.2, -0.3), Color3.fromRGB(255, 180, 40))
		end
		eyes(model, 0.45, 0.55, -0.87, 0.7)
		piece(model, "Beak", Vector3.new(0.3, 0.35, 0.3), Vector3.new(0, 0.15, -0.95), Color3.fromRGB(255, 180, 40))
	end,
}

-- Pièces qui gardent leur couleur quelle que soit la rareté (yeux, braises...).
local KEEP_COLOR = { Eye = true, Pupil = true, Halo = true, Halo2 = true, Nose = true, Beak = true }

-- Couleur à la position `position` d'une palette (0 = la 1re couleur, 1 = la 2e...) : glisse de l'une à l'autre.
local function along(palette: { Color3 }, position: number): Color3
	position %= #palette
	local index = math.floor(position)
	return palette[index + 1]:Lerp(palette[(index + 1) % #palette + 1], position - index)
end

-- L'image du dégradé d'une rareté, fabriquée par le jeu lui-même (aucune image à mettre en ligne) : des bandes
-- ondulées de toutes les couleurs de la palette. Elle est faite une seule fois et sert à tous les animaux de
-- cette rareté. Si Roblox refuse de créer l'image (réglage du jeu, vieil appareil), renvoie nil : l'animal reçoit
-- alors seulement un voile de couleur.
local gradients = {}
function gradient(rarity: number): any
	if gradients[rarity] ~= nil then
		return gradients[rarity] or nil
	end
	local palette = Pets.RARITIES[rarity].palette
	local ok, content = pcall(function()
		local size = 64
		local image = AssetService:CreateEditableImage({ Size = Vector2.new(size, size) })
		local pixels = buffer.create(size * size * 4)
		for y = 0, size - 1 do
			for x = 0, size - 1 do
				local u, v = x / size, y / size
				local wave = 0.25 * math.sin(v * math.pi * 4) + 0.25 * math.sin(u * math.pi * 6)
				local color = along(palette, (u * 2 + v * 2 + wave) * #palette)
				local offset = (y * size + x) * 4
				buffer.writeu8(pixels, offset, math.floor(color.R * 255))
				buffer.writeu8(pixels, offset + 1, math.floor(color.G * 255))
				buffer.writeu8(pixels, offset + 2, math.floor(color.B * 255))
				buffer.writeu8(pixels, offset + 3, 255)
			end
		end
		image:WritePixelsBuffer(Vector2.zero, Vector2.new(size, size), pixels)
		return Content.fromObject(image)
	end)
	if not ok then
		warn("[Survive] dégradé des animaux impossible : " .. tostring(content))
	end
	gradients[rarity] = if ok then content else false
	return if ok then content else nil
end

-- Construit le modèle d'un animal (ancré, sans collision). Sa pièce principale s'appelle « Body ».
function Pets.build(name: string, rarity: number): Model
	local model = PetModels.build(name)
	if not model then
		model = Instance.new("Model")
		model.Name = name
		local builder = BUILDERS[name] or BUILDERS.Rock
		builder(model)
	end
	local body = model:FindFirstChild("Body") :: BasePart
	model.PrimaryPart = body

	local info = Pets.RARITIES[math.clamp(rarity, 1, #Pets.RARITIES)]
	if info.palette then
		-- 1) Le corps : le dégradé de la palette remplace la texture de chaque maillage ; les pièces simples
		--    (blocs) prennent chacune une couleur de la palette.
		local content = gradient(rarity)
		local count = 0
		for _, part in model:GetDescendants() do
			if part:IsA("MeshPart") and content then
				for _, child in part:GetChildren() do
					if child:IsA("SurfaceAppearance") then
						child:Destroy()
					end
				end
				part.TextureContent = content
				part.Color = Color3.new(1, 1, 1)
				part.Material = Enum.Material.SmoothPlastic
			elseif part:IsA("BasePart") and part ~= body and not KEEP_COLOR[part.Name] then
				count += 1
				part.Color = info.palette[count % #info.palette + 1]
			end
		end
		-- 2) Un contour de couleur (et un voile léger, plus fort si le dégradé n'a pas pu être peint).
		local tint = Instance.new("Highlight")
		tint.Name = "Tint"
		tint.FillTransparency = if content then 0.88 else 1 - info.tint
		tint.OutlineTransparency = 0
		tint.DepthMode = Enum.HighlightDepthMode.Occluded
		tint.Parent = model
		-- 3) Deux anneaux qui brillent sous l'animal, de deux couleurs, et de la lumière.
		local ring = piece(model, "Halo", Vector3.new(0.15, 3.6, 3.6), CFrame.new(0, -1.5, 0) * CFrame.Angles(0, 0, math.rad(90)), info.color, Enum.Material.Neon, Enum.PartType.Cylinder)
		ring.Transparency = 0.3
		piece(model, "Halo2", Vector3.new(0.17, 2.1, 2.1), CFrame.new(0, -1.5, 0) * CFrame.Angles(0, 0, math.rad(90)), info.color, Enum.Material.Neon, Enum.PartType.Cylinder)
		local light = Instance.new("PointLight")
		light.Name = "RarityLight"
		light.Range = 5 + rarity
		light.Brightness = 0.5
		light.Parent = body
		model:SetAttribute("Rarity", rarity)
	end
	if rarity >= 4 then
		local sparkles = Instance.new("Sparkles")
		sparkles.Parent = body
	end
	model:ScaleTo(info.scale * Pets.size(name))
	Pets.shimmer(model, 0)
	return model
end

-- Couleur d'une palette à l'instant t (décalé de `offset` couleurs).
local function blend(palette: { Color3 }, t: number, offset: number): Color3
	return along(palette, t / Pets.COLOR_SECONDS + offset)
end

-- À appeler à chaque image pour un animal rare ou mieux : fait tourner les couleurs du contour, des anneaux et de
-- la lumière (le dégradé du corps, lui, ne bouge pas).
function Pets.shimmer(model: Model, t: number)
	local info = Pets.RARITIES[model:GetAttribute("Rarity") or 1]
	local palette = info and info.palette
	if not palette then
		return
	end
	local first, second, third = blend(palette, t, 0), blend(palette, t, 1), blend(palette, t, 2)
	for _, child in model:GetChildren() do
		if child.Name == "Tint" then
			child.FillColor = first
			child.OutlineColor = third
		elseif child.Name == "Halo" then
			child.Color = second
		elseif child.Name == "Halo2" then
			child.Color = third
		end
	end
	local body = model.PrimaryPart
	local light = body and body:FindFirstChild("RarityLight")
	if light then
		light.Color = first
	end
	local sparkles = body and body:FindFirstChildOfClass("Sparkles")
	if sparkles then
		sparkles.SparkleColor = second
	end
end

return Pets

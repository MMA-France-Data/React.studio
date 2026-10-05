-- Les animaux : chaque salle donne l'œuf de son animal ; la rareté est tirée quand l'œuf éclot dans la couveuse.
-- Le même animal existe en 4 raretés : plus il est rare, plus son pouvoir est fort (et plus il est gros et brillant).
-- On n'en équipe qu'un à la fois.
local Pets = {}

Pets.ORDER = { "Dragon", "Rock", "Rabbit", "Golem", "Owl" }

-- power : ce que fait l'animal ; values : la force du pouvoir pour chaque rareté (commun, rare, épique, légendaire).
Pets.DEFS = {
	Dragon = { power = "glide", values = { 1, 1.5, 2, 3 } }, -- secondes de vol plané (sauter une 2e fois en l'air)
	Rock = { power = "shield", values = { 40, 70, 110, 160 } }, -- dégâts encaissés par salle (pas la lave ni le plafond)
	Rabbit = { power = "speed", values = { 4, 7, 10, 15 } }, -- % de vitesse en plus
	Golem = { power = "force", values = { 3, 6, 10, 15 } }, -- force en plus pour repousser le plafond
	Owl = { power = "coins", values = { 5, 10, 15, 25 } }, -- % de pièces en plus
}

Pets.RARITIES = {
	{ key = "Common", color = Color3.fromRGB(200, 204, 214), scale = 1 },
	{ key = "Rare", color = Color3.fromRGB(70, 160, 255), scale = 1.12 },
	{ key = "Epic", color = Color3.fromRGB(190, 100, 255), scale = 1.25 },
	{ key = "Legendary", color = Color3.fromRGB(255, 200, 40), scale = 1.4 },
}

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

-- LES MODÈLES (faits de blocs) ------------------------------------------------------------------------------------
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

-- Construit le modèle d'un animal (ancré, sans collision). Sa pièce principale s'appelle « Body ».
function Pets.build(name: string, rarity: number): Model
	local model = Instance.new("Model")
	model.Name = name
	local builder = BUILDERS[name] or BUILDERS.Rock
	builder(model)
	local body = model:FindFirstChild("Body") :: BasePart
	model.PrimaryPart = body

	local info = Pets.RARITIES[math.clamp(rarity, 1, #Pets.RARITIES)]
	if rarity >= 2 then
		-- Un anneau qui brille à la couleur de la rareté, de la lumière, et des étincelles pour le légendaire.
		local ring = piece(model, "Halo", Vector3.new(0.15, 3.4, 3.4), CFrame.new(0, -1.5, 0) * CFrame.Angles(0, 0, math.rad(90)), info.color, Enum.Material.Neon, Enum.PartType.Cylinder)
		ring.Transparency = 0.25
		local light = Instance.new("PointLight")
		light.Color = info.color
		light.Range = 6 + rarity * 2
		light.Brightness = 1.5
		light.Parent = body
	end
	if rarity >= 4 then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = info.color
		sparkles.Parent = body
	end
	model:ScaleTo(info.scale)
	return model
end

return Pets

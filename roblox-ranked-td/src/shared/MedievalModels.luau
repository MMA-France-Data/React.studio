-- Habillage médiéval commun aux ennemis du ranked et du mode infini.
-- La racine reste une Part légère déplacée par la simulation ; les éléments visuels
-- sont soudés dessus afin de conserver BulkMoveTo et le protocole réseau existants.
local MedievalModels = {}

local IRON = Color3.fromRGB(92, 98, 108)
local DARK_IRON = Color3.fromRGB(48, 51, 58)
local LEATHER = Color3.fromRGB(91, 57, 35)
local WOOD = Color3.fromRGB(101, 65, 38)
local SKIN = Color3.fromRGB(213, 166, 119)
local HORSE = Color3.fromRGB(93, 59, 38)
local GOLD = Color3.fromRGB(218, 168, 62)

local function piece(root: BasePart, name: string, size: Vector3, relative: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = root.CFrame * relative
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Shape = shape or Enum.PartType.Block
	part.Anchored = false
	part.Massless = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = root
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
	return part
end

local function weapon(root: BasePart, s: number, heavy: boolean?)
	local x = 0.78 * s
	piece(root, "SwordGrip", Vector3.new(0.16, 0.65, 0.16) * s, CFrame.new(x, -0.05 * s, -0.35 * s) * CFrame.Angles(math.rad(-20), 0, 0), LEATHER, Enum.Material.Wood)
	piece(root, "SwordBlade", Vector3.new(0.12, (heavy and 1.7 or 1.35) * s, 0.28 * s), CFrame.new(x, 0.8 * s, -0.8 * s) * CFrame.Angles(math.rad(-28), 0, 0), Color3.fromRGB(190, 198, 207), Enum.Material.Metal)
end

local function shield(root: BasePart, s: number, color: Color3, large: boolean?)
	local scale = if large then 1.25 else 1
	piece(root, "Shield", Vector3.new(0.22 * s, 1.35 * s * scale, 1.15 * s * scale), CFrame.new(-0.72 * s, 0.1 * s, -0.22 * s), color, Enum.Material.Metal, Enum.PartType.Cylinder)
	piece(root, "ShieldBoss", Vector3.new(0.3, 0.35, 0.35) * s, CFrame.new(-0.86 * s, 0.1 * s, -0.22 * s), GOLD, Enum.Material.Metal, Enum.PartType.Ball)
end

local function infantry(root: BasePart, def, armored: boolean, warlord: boolean)
	local s = def.size / 2
	local armor = if warlord then DARK_IRON elseif armored then IRON else def.color
	local tabard = def.color:Lerp(Color3.new(0, 0, 0), 0.18)

	-- Jambes, cotte de mailles, tabard et tête casquée.
	for _, x in { -0.28, 0.28 } do
		piece(root, "Boot", Vector3.new(0.34, 0.75, 0.38) * s, CFrame.new(x * s, -0.64 * s, 0), LEATHER, Enum.Material.Fabric)
	end
	piece(root, "Torso", Vector3.new(1.05, 1.25, 0.72) * s, CFrame.new(0, 0.22 * s, 0), armor, if armored or warlord then Enum.Material.Metal else Enum.Material.Fabric)
	piece(root, "Tabard", Vector3.new(0.72, 0.95, 0.12) * s, CFrame.new(0, 0.12 * s, -0.43 * s), tabard, Enum.Material.Fabric)
	piece(root, "Head", Vector3.one * 0.63 * s, CFrame.new(0, 1.08 * s, 0), SKIN, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	piece(root, "Helmet", Vector3.new(0.72, 0.48, 0.72) * s, CFrame.new(0, 1.33 * s, 0), armor, Enum.Material.Metal)
	piece(root, "Visor", Vector3.new(0.76, 0.17, 0.15) * s, CFrame.new(0, 1.18 * s, -0.37 * s), DARK_IRON, Enum.Material.Metal)

	if armored or warlord then
		for _, x in { -0.72, 0.72 } do
			piece(root, "Pauldron", Vector3.new(0.48, 0.42, 0.82) * s, CFrame.new(x * s, 0.62 * s, 0), armor:Lerp(GOLD, if warlord then 0.35 else 0.05), Enum.Material.Metal, Enum.PartType.Ball)
		end
	end
	shield(root, s, if warlord then Color3.fromRGB(112, 27, 31) else def.color, armored or warlord)
	weapon(root, s, armored or warlord)

	if warlord then
		piece(root, "CrownBand", Vector3.new(0.84, 0.18, 0.84) * s, CFrame.new(0, 1.66 * s, 0), GOLD, Enum.Material.Metal)
		for _, x in { -0.28, 0, 0.28 } do
			piece(root, "CrownSpike", Vector3.new(0.12, 0.42 + (if x == 0 then 0.18 else 0), 0.12) * s, CFrame.new(x * s, 1.93 * s, 0), GOLD, Enum.Material.Metal)
		end
		piece(root, "Cape", Vector3.new(0.95, 1.55, 0.16) * s, CFrame.new(0, 0.12 * s, 0.46 * s) * CFrame.Angles(math.rad(-8), 0, 0), Color3.fromRGB(112, 22, 29), Enum.Material.Fabric)
	end
end

local function cavalry(root: BasePart, def)
	local s = def.size / 2
	-- Cheval orienté vers -Z, donc dans le sens de marche de la racine.
	piece(root, "HorseBody", Vector3.new(1.15, 0.9, 2.35) * s, CFrame.new(0, -0.05 * s, 0.08 * s), HORSE, Enum.Material.SmoothPlastic)
	piece(root, "HorseNeck", Vector3.new(0.62, 1.1, 0.62) * s, CFrame.new(0, 0.42 * s, -0.9 * s) * CFrame.Angles(math.rad(-25), 0, 0), HORSE, Enum.Material.SmoothPlastic)
	piece(root, "HorseHead", Vector3.new(0.72, 0.58, 0.9) * s, CFrame.new(0, 0.82 * s, -1.3 * s), HORSE:Lerp(Color3.new(0, 0, 0), 0.08), Enum.Material.SmoothPlastic)
	for _, offset in {
		Vector3.new(-0.38, -0.76, -0.65), Vector3.new(0.38, -0.76, -0.65),
		Vector3.new(-0.38, -0.76, 0.72), Vector3.new(0.38, -0.76, 0.72),
	} do
		piece(root, "HorseLeg", Vector3.new(0.23, 0.95, 0.23) * s, CFrame.new(offset * s), HORSE:Lerp(Color3.new(0, 0, 0), 0.15), Enum.Material.SmoothPlastic)
	end
	piece(root, "Saddle", Vector3.new(0.9, 0.18, 1.05) * s, CFrame.new(0, 0.55 * s, 0.15 * s), LEATHER, Enum.Material.Fabric)

	-- Cavalier compact avec lance et fanion.
	piece(root, "RiderTorso", Vector3.new(0.75, 0.9, 0.55) * s, CFrame.new(0, 1.15 * s, 0.1 * s), def.color, Enum.Material.Fabric)
	piece(root, "RiderHead", Vector3.one * 0.48 * s, CFrame.new(0, 1.83 * s, 0.02 * s), SKIN, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	piece(root, "RiderHelmet", Vector3.new(0.58, 0.38, 0.58) * s, CFrame.new(0, 2.02 * s, 0.02 * s), IRON, Enum.Material.Metal)
	piece(root, "Lance", Vector3.new(0.13, 0.13, 3.2) * s, CFrame.new(0.65 * s, 1.18 * s, -0.82 * s) * CFrame.Angles(math.rad(-8), 0, 0), WOOD, Enum.Material.Wood)
	piece(root, "LanceTip", Vector3.new(0.22, 0.22, 0.48) * s, CFrame.new(0.65 * s, 1.38 * s, -2.55 * s), Color3.fromRGB(201, 205, 211), Enum.Material.Metal)
	shield(root, s * 0.72, def.color, false)
end

function MedievalModels.decorateEnemy(root: BasePart, def)
	root.Transparency = 1
	root.Color = def.color
	root.Material = Enum.Material.SmoothPlastic
	root.CastShadow = false
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false

	if def.visual == "Cavalry" then
		cavalry(root, def)
	elseif def.visual == "Heavy" then
		infantry(root, def, true, false)
	elseif def.visual == "Warlord" then
		infantry(root, def, true, true)
	else
		infantry(root, def, false, false)
	end
end

return MedievalModels

-- Modèles 3D médiévaux des tours du mode infini.
-- Chaque silhouette reste simple, mais doit être identifiable au premier regard.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IdleTowers = require(ReplicatedStorage:WaitForChild("Shared").IdleTowers)

local IdleTowerModel = {}

local function newPart(model: Model, className: string, name: string, props)
	local object = Instance.new(className)
	local objectPart = object :: BasePart
	objectPart.Name = name
	objectPart.Anchored = true
	objectPart.CanCollide = false
	objectPart.CastShadow = true
	objectPart.TopSurface = Enum.SurfaceType.Smooth
	objectPart.BottomSurface = Enum.SurfaceType.Smooth
	objectPart.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(objectPart :: any)[key] = value
	end
	objectPart.Parent = model
	return objectPart
end

local function part(model: Model, name: string, props)
	return newPart(model, "Part", name, props)
end

local function wedge(model: Model, name: string, props)
	return newPart(model, "WedgePart", name, props)
end

local VERTICAL_CYLINDER = CFrame.Angles(0, 0, math.rad(90))

-- cframe : position au sol de l'emplacement, orientée comme la parcelle.
function IdleTowerModel.create(towerType: string, cframe: CFrame, parent: Instance, attributes: { [string]: any }): Model
	local def = IdleTowers.Defs[towerType]
	local accent = def.color
	local model = Instance.new("Model")
	model.Name = towerType

	local stone = Color3.fromRGB(104, 101, 91)
	local paleStone = Color3.fromRGB(137, 132, 117)
	local darkStone = Color3.fromRGB(61, 60, 57)
	local wood = Color3.fromRGB(101, 65, 37)
	local darkWood = Color3.fromRGB(66, 42, 27)
	local iron = Color3.fromRGB(100, 106, 111)
	local darkIron = Color3.fromRGB(53, 58, 62)
	local gold = Color3.fromRGB(218, 164, 54)
	local skin = Color3.fromRGB(207, 158, 113)

	local function cf(offset: Vector3, rotation: CFrame?): CFrame
		return cframe * CFrame.new(offset) * (rotation or CFrame.new())
	end

	local function block(name: string, size: Vector3, offset: Vector3, color: Color3, material, rotation: CFrame?)
		return part(model, name, {
			Size = size,
			CFrame = cf(offset, rotation),
			Color = color,
			Material = material,
		})
	end

	local function cylinder(name: string, size: Vector3, offset: Vector3, color: Color3, material, rotation: CFrame?)
		return part(model, name, {
			Shape = Enum.PartType.Cylinder,
			Size = size,
			CFrame = cf(offset, rotation),
			Color = color,
			Material = material,
		})
	end

	local function ball(name: string, diameter: number, offset: Vector3, color: Color3, material)
		return part(model, name, {
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * diameter,
			CFrame = cf(offset),
			Color = color,
			Material = material,
		})
	end

	-- Socle commun, volontairement bas pour laisser l'arme ou le héros dominer.
	local base = cylinder("Base", Vector3.new(0.55, 3.8, 3.8), Vector3.new(0, 0.28, 0), darkStone, Enum.Material.Cobblestone, VERTICAL_CYLINDER)
	base.CanCollide = true
	cylinder("Plinth", Vector3.new(0.32, 3.25, 3.25), Vector3.new(0, 0.7, 0), paleStone, Enum.Material.Slate, VERTICAL_CYLINDER)

	if towerType == "MachineGun" then
		-- Archer sur une petite tour crénelée.
		block("Keep", Vector3.new(2.65, 2.2, 2.65), Vector3.new(0, 1.9, 0), stone, Enum.Material.Brick)
		block("Platform", Vector3.new(3.35, 0.28, 3.35), Vector3.new(0, 3.14, 0), wood, Enum.Material.WoodPlanks)
		for _, offset in {
			Vector3.new(-1.28, 3.55, -1.28), Vector3.new(1.28, 3.55, -1.28),
			Vector3.new(-1.28, 3.55, 1.28), Vector3.new(1.28, 3.55, 1.28),
		} do
			block("Crenel", Vector3.new(0.55, 0.7, 0.55), offset, stone, Enum.Material.Brick)
		end
		block("LegL", Vector3.new(0.32, 0.9, 0.35), Vector3.new(-0.28, 3.75, 0), darkWood, Enum.Material.Fabric)
		block("LegR", Vector3.new(0.32, 0.9, 0.35), Vector3.new(0.28, 3.75, 0), darkWood, Enum.Material.Fabric)
		block("ArcherTorso", Vector3.new(1.05, 1.35, 0.72), Vector3.new(0, 4.72, 0), accent, Enum.Material.Fabric)
		ball("Head", 0.7, Vector3.new(0, 5.72, 0), skin, Enum.Material.SmoothPlastic)
		block("Helmet", Vector3.new(0.8, 0.35, 0.78), Vector3.new(0, 6.02, 0), iron, Enum.Material.Metal)
		block("ArmL", Vector3.new(0.3, 1.25, 0.3), Vector3.new(-0.62, 4.85, -0.25), skin, Enum.Material.SmoothPlastic, CFrame.Angles(0, 0, math.rad(-25)))
		block("ArmR", Vector3.new(0.3, 1.25, 0.3), Vector3.new(0.62, 4.85, -0.25), skin, Enum.Material.SmoothPlastic, CFrame.Angles(0, 0, math.rad(25)))
		block("BowUpper", Vector3.new(1.3, 0.12, 0.12), Vector3.new(0.45, 5.25, -0.7), wood, Enum.Material.Wood, CFrame.Angles(0, 0, math.rad(55)))
		block("BowLower", Vector3.new(1.3, 0.12, 0.12), Vector3.new(-0.45, 4.55, -0.7), wood, Enum.Material.Wood, CFrame.Angles(0, 0, math.rad(55)))
		block("Arrow", Vector3.new(0.1, 0.1, 2.25), Vector3.new(0, 5, -1.25), gold, Enum.Material.Metal)
		block("Quiver", Vector3.new(0.55, 1.35, 0.55), Vector3.new(0.58, 4.7, 0.55), darkWood, Enum.Material.Wood, CFrame.Angles(0, 0, math.rad(-15)))

	elseif towerType == "Frost" then
		-- Totem glacé : cercle de menhirs et cristaux effilés.
		for index, offset in {
			Vector3.new(-1.08, 1.65, 0.55), Vector3.new(1.08, 1.65, 0.55), Vector3.new(0, 1.65, -1.05),
		} do
			block("Runestone" .. index, Vector3.new(0.7, 2.05, 0.7), offset, stone, Enum.Material.Slate, CFrame.Angles(math.rad(if index == 3 then 8 else -6), 0, math.rad(if index == 1 then -8 else 8)))
			block("Rune" .. index, Vector3.new(0.12, 0.75, 0.08), offset + Vector3.new(0, 0.1, -0.39), accent, Enum.Material.Neon)
		end
		block("CrystalCore", Vector3.new(0.9, 2.8, 0.9), Vector3.new(0, 3.1, 0), accent, Enum.Material.Ice, CFrame.Angles(0, math.rad(45), math.rad(10))).Transparency = 0.12
		for index, data in {
			{ Vector3.new(-0.85, 2.25, 0), math.rad(-24) },
			{ Vector3.new(0.75, 2.15, 0.25), math.rad(28) },
		} do
			local shard = block("Shard" .. index, Vector3.new(0.48, 1.75, 0.48), data[1], accent:Lerp(Color3.new(1, 1, 1), 0.25), Enum.Material.Glass, CFrame.Angles(0, math.rad(45), data[2]))
			shard.Transparency = 0.2
		end

	elseif towerType == "Bomb" then
		-- Catapulte avec roues, montants, treuil et cuillère.
		block("Chassis", Vector3.new(3.15, 0.42, 2.7), Vector3.new(0, 1.05, 0.2), wood, Enum.Material.WoodPlanks)
		for _, x in { -1.62, 1.62 } do
			cylinder("Wheel", Vector3.new(0.42, 1.85, 1.85), Vector3.new(x, 1.05, 0.3), darkWood, Enum.Material.Wood)
			cylinder("Hub", Vector3.new(0.55, 0.45, 0.45), Vector3.new(x, 1.05, 0.3), iron, Enum.Material.Metal)
			block("Upright", Vector3.new(0.36, 2.9, 0.38), Vector3.new(x * 0.58, 2.5, 0.45), darkWood, Enum.Material.Wood)
		end
		block("Axle", Vector3.new(3.5, 0.28, 0.28), Vector3.new(0, 2.65, 0.45), iron, Enum.Material.Metal)
		block("ThrowingArm", Vector3.new(0.38, 5.2, 0.38), Vector3.new(0, 3.6, -0.1), wood, Enum.Material.Wood, CFrame.Angles(math.rad(-28), 0, 0))
		block("Spoon", Vector3.new(1.2, 0.28, 1.15), Vector3.new(0, 5.8, -1.25), darkWood, Enum.Material.WoodPlanks, CFrame.Angles(math.rad(-28), 0, 0))
		ball("Boulder", 1.05, Vector3.new(0, 6.15, -1.55), Color3.fromRGB(72, 71, 67), Enum.Material.Rock)
		cylinder("Winch", Vector3.new(2.2, 0.55, 0.55), Vector3.new(0, 1.45, 1.1), iron, Enum.Material.Metal)

	elseif towerType == "Tesla" then
		-- Mage des tempêtes, avec l'énergie concentrée dans un petit sceptre.
		block("Dais", Vector3.new(2.5, 0.35, 2.5), Vector3.new(0, 1.02, 0), darkStone, Enum.Material.Slate)
		block("Robe", Vector3.new(1.55, 2.6, 1.25), Vector3.new(0, 2.45, 0), Color3.fromRGB(49, 45, 82), Enum.Material.Fabric)
		block("Mantle", Vector3.new(2.05, 0.45, 1.5), Vector3.new(0, 3.6, 0), accent:Lerp(Color3.fromRGB(35, 35, 55), 0.45), Enum.Material.Fabric)
		ball("Hood", 1.35, Vector3.new(0, 4.35, 0), Color3.fromRGB(42, 38, 68), Enum.Material.Fabric)
		ball("Face", 0.58, Vector3.new(0, 4.32, -0.58), skin, Enum.Material.SmoothPlastic)
		block("Staff", Vector3.new(0.22, 4.7, 0.22), Vector3.new(1.15, 3.15, -0.1), darkWood, Enum.Material.Wood)
		ball("StormGem", 0.72, Vector3.new(1.15, 5.65, -0.1), accent, Enum.Material.Neon)
		block("ForkL", Vector3.new(0.15, 1.05, 0.15), Vector3.new(0.9, 5.9, -0.1), gold, Enum.Material.Metal, CFrame.Angles(0, 0, math.rad(-35)))
		block("ForkR", Vector3.new(0.15, 1.05, 0.15), Vector3.new(1.4, 5.9, -0.1), gold, Enum.Material.Metal, CFrame.Angles(0, 0, math.rad(35)))

	elseif towerType == "Laser" then
		-- Obélisque arcanique, sans grosse sphère néon.
		block("Pedestal", Vector3.new(2.25, 0.65, 2.25), Vector3.new(0, 1.15, 0), darkStone, Enum.Material.Slate)
		block("Obelisk", Vector3.new(1.35, 3.8, 1.35), Vector3.new(0, 3.35, 0), Color3.fromRGB(57, 53, 69), Enum.Material.Slate, CFrame.Angles(0, math.rad(45), 0))
		block("RuneFront", Vector3.new(0.1, 1.75, 0.42), Vector3.new(-0.52, 3.45, -0.52), accent, Enum.Material.Neon, CFrame.Angles(0, math.rad(45), 0))
		for index, data in {
			{ Vector3.new(-1.05, 5.7, 0), -22 }, { Vector3.new(0, 6.25, 0), 0 }, { Vector3.new(1.05, 5.7, 0), 22 },
		} do
			local shard = block("ArcaneShard" .. index, Vector3.new(0.38, 1.25, 0.38), data[1], accent:Lerp(Color3.new(1, 1, 1), 0.15), Enum.Material.Glass, CFrame.Angles(0, math.rad(45), math.rad(data[2])))
			shard.Transparency = 0.12
		end
		for index, data in {
			{ Vector3.new(-0.65, 5.95, 0.45), 45 }, { Vector3.new(0.65, 5.95, 0.45), -45 },
			{ Vector3.new(-0.65, 7.25, 0.45), -45 }, { Vector3.new(0.65, 7.25, 0.45), 45 },
		} do
			block("ArcaneFrame" .. index, Vector3.new(1.75, 0.12, 0.12), data[1], gold, Enum.Material.Metal, CFrame.Angles(0, 0, math.rad(data[2])))
		end

	elseif towerType == "Chain" then
		-- Oracle de la foudre, encadré par deux paratonnerres.
		block("Shrine", Vector3.new(2.65, 1.15, 2.65), Vector3.new(0, 1.45, 0), darkStone, Enum.Material.Brick)
		block("OracleRobe", Vector3.new(1.35, 2.25, 1.1), Vector3.new(0, 3.15, 0), Color3.fromRGB(57, 48, 76), Enum.Material.Fabric)
		ball("OracleHood", 1.18, Vector3.new(0, 4.72, 0), Color3.fromRGB(41, 36, 57), Enum.Material.Fabric)
		ball("OracleFace", 0.48, Vector3.new(0, 4.7, -0.51), skin, Enum.Material.SmoothPlastic)
		for _, x in { -1.18, 1.18 } do
			block("Conductor", Vector3.new(0.18, 3.8, 0.18), Vector3.new(x, 3.2, 0.4), iron, Enum.Material.Metal)
			block("Prong", Vector3.new(0.18, 1.1, 0.18), Vector3.new(x, 5.25, 0.4), gold, Enum.Material.Metal, CFrame.Angles(0, 0, math.rad(if x < 0 then -28 else 28)))
			ball("Spark", 0.42, Vector3.new(x, 5.88, 0.4), accent, Enum.Material.Neon)
		end
		block("LightningRune", Vector3.new(0.12, 1.5, 0.38), Vector3.new(0, 1.55, -1.35), accent, Enum.Material.Neon, CFrame.Angles(0, 0, math.rad(-18)))

	elseif towerType == "Orbital" then
		-- Trébuchet royal construit comme une véritable machine de siège.
		block("Bed", Vector3.new(3.4, 0.38, 3), Vector3.new(0, 1.02, 0.25), darkWood, Enum.Material.WoodPlanks)
		for _, x in { -1.7, 1.7 } do
			cylinder("Wheel", Vector3.new(0.46, 2.05, 2.05), Vector3.new(x, 1.05, 0.3), darkWood, Enum.Material.Wood)
			cylinder("Hub", Vector3.new(0.58, 0.5, 0.5), Vector3.new(x, 1.05, 0.3), iron, Enum.Material.Metal)
			block("TowerPost", Vector3.new(0.42, 4.8, 0.42), Vector3.new(x * 0.62, 3.25, 0.45), wood, Enum.Material.WoodPlanks, CFrame.Angles(0, 0, math.rad(if x < 0 then -5 else 5)))
			block("Brace", Vector3.new(0.3, 4.1, 0.3), Vector3.new(x * 0.62, 2.7, 0.45), darkWood, Enum.Material.Wood, CFrame.Angles(0, 0, math.rad(if x < 0 then 31 else -31)))
		end
		block("Pivot", Vector3.new(3.15, 0.3, 0.3), Vector3.new(0, 5.35, 0.45), iron, Enum.Material.Metal)
		block("TrebuchetArm", Vector3.new(0.46, 7.7, 0.46), Vector3.new(0, 5.5, -0.35), wood, Enum.Material.Wood, CFrame.Angles(math.rad(-38), 0, 0))
		block("Counterweight", Vector3.new(1.55, 1.7, 1.55), Vector3.new(0, 3.18, 1.55), iron, Enum.Material.Metal, CFrame.Angles(math.rad(-8), 0, 0))
		block("Sling", Vector3.new(0.1, 2.15, 0.1), Vector3.new(0, 8.4, -2.65), darkWood, Enum.Material.Fabric, CFrame.Angles(math.rad(-18), 0, 0))
		ball("RunicStone", 1.15, Vector3.new(0, 9.45, -3), accent:Lerp(Color3.fromRGB(90, 86, 80), 0.72), Enum.Material.Rock)

	else -- Rocket : baliste lourde
		block("Turntable", Vector3.new(3.2, 0.38, 3.2), Vector3.new(0, 1.05, 0), darkWood, Enum.Material.WoodPlanks)
		block("PivotPost", Vector3.new(0.75, 1.65, 0.75), Vector3.new(0, 1.95, 0.25), iron, Enum.Material.Metal)
		block("Stock", Vector3.new(0.62, 0.62, 4.8), Vector3.new(0, 3.15, -0.35), wood, Enum.Material.Wood, CFrame.Angles(math.rad(-7), 0, 0))
		for _, x in { -1, 1 } do
			block("BowArm", Vector3.new(2.35, 0.28, 0.34), Vector3.new(x * 0.95, 3.5, -1.58), darkIron, Enum.Material.Metal, CFrame.Angles(0, 0, math.rad(x * 18)))
			block("String", Vector3.new(0.08, 0.08, 2.4), Vector3.new(x * 1.75, 3.22, -0.48), paleStone, Enum.Material.Fabric, CFrame.Angles(0, math.rad(x * 34), 0))
		end
		block("Bolt", Vector3.new(0.18, 0.18, 5.2), Vector3.new(0, 3.58, -1.05), gold, Enum.Material.Metal, CFrame.Angles(math.rad(-7), 0, 0))
		wedge(model, "BoltHead", {
			Size = Vector3.new(0.55, 0.55, 0.7),
			CFrame = cf(Vector3.new(0, 3.95, -3.65), CFrame.Angles(math.rad(-7), math.rad(90), 0)),
			Color = iron,
			Material = Enum.Material.Metal,
		})
		cylinder("Crank", Vector3.new(2.5, 0.28, 0.28), Vector3.new(0, 2.7, 1.05), iron, Enum.Material.Metal)
	end

	model.PrimaryPart = base
	model:SetAttribute("TowerType", towerType)
	model:SetAttribute("RestCFrame", cframe)
	for key, value in attributes do
		model:SetAttribute(key, value)
	end
	model.Parent = parent
	return model
end

return IdleTowerModel

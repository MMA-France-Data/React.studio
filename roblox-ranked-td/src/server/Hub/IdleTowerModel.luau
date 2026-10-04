-- Modèles 3D médiévaux des 16 tours (niveaux, camp d'entraînement, vignettes de la boutique).
-- Chaque silhouette reste simple, mais doit être identifiable au premier regard. Une tour de palier 2
-- (IdleTowers.TIER2) garde la silhouette de sa tour de base, à ses couleurs, avec une parure en plus (plus bas).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IdleTowers = require(ReplicatedStorage:WaitForChild("Shared").IdleTowers)
local MedievalModels = require(ReplicatedStorage.Shared.MedievalModels)

local IdleTowerModel = {}

local function newPart(model: Model, className: string, name: string, props)
	local object = Instance.new(className)
	local objectPart = object :: BasePart
	objectPart.Name = name
	objectPart.Anchored = true
	objectPart.CanCollide = false
	objectPart.CanTouch = false
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

-- Tour de palier 2 : les pièces qui « portent » son pouvoir s'allument à ses couleurs (pointe de la flèche enflammée,
-- rocher de magma, pointe du carreau du dragon, cristal du blizzard, éclats du néant, pierre céleste). Noms des pièces
-- de la silhouette de sa tour de base (plus bas).
local TIER_GLOW_PARTS = {
	MachineGun = { ArrowHead = true },
	Frost = { CrystalCore = true },
	Bomb = { Boulder = true },
	Rocket = { BoltHead = true },
	Laser = { ArcaneShard1 = true, ArcaneShard2 = true, ArcaneShard3 = true },
	Orbital = { RunicStone = true },
}

-- cframe : position au sol de la tour, orientée comme sa zone (niveau ou parcelle).
function IdleTowerModel.create(towerType: string, cframe: CFrame, parent: Instance, attributes: { [string]: any }): Model
	-- Les armes regardent -Z ; sur une parcelle, les cibles arrivent du fond (+Z).
	cframe = cframe * CFrame.Angles(0, math.pi, 0)
	local def = IdleTowers.Defs[towerType]
	local accent = def.color
	-- Silhouette : celle de la tour de palier 1 (une tour de palier 2 la garde, avec sa parure).
	local shape = IdleTowers.baseOf(towerType)
	local model = Instance.new("Model")
	model.Name = towerType

	local stone = Color3.fromRGB(142, 148, 145)
	local paleStone = Color3.fromRGB(188, 184, 165)
	local darkStone = Color3.fromRGB(69, 81, 85)
	local wood = Color3.fromRGB(135, 86, 47)
	local darkWood = Color3.fromRGB(66, 42, 27)
	local iron = Color3.fromRGB(149, 161, 169)
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

	local function beam(name: string, a: Vector3, b: Vector3, width: number, color: Color3, material)
		return part(model, name, { Size = Vector3.new(width, width, (b - a).Magnitude),
			CFrame = cframe * CFrame.lookAt((a + b) / 2, b), Color = color, Material = material })
	end

	local function bowString(tip: Vector3, nock: Vector3, released: Vector3, width: number)
		local stringPart = beam("BowString", tip, nock, width, paleStone, Enum.Material.Fabric)
		stringPart:SetAttribute("StringTip", tip)
		stringPart:SetAttribute("StringNock", nock)
		stringPart:SetAttribute("StringReleased", released)
		model:SetAttribute("WorkingBow", true)
	end

	-- Socle commun, volontairement bas pour laisser l'arme ou le héros dominer.
	local base = cylinder("Base", Vector3.new(0.55, 3.8, 3.8), Vector3.new(0, 0.28, 0), darkStone, Enum.Material.Cobblestone, VERTICAL_CYLINDER)
	base.CanCollide = true
	cylinder("Plinth", Vector3.new(0.32, 3.25, 3.25), Vector3.new(0, 0.7, 0), paleStone, Enum.Material.Slate, VERTICAL_CYLINDER)
	cylinder("FoundationTrim", Vector3.new(0.12, 3.88, 3.88), Vector3.new(0, 0.49, 0), iron, Enum.Material.Metal, VERTICAL_CYLINDER)

	if shape == "MachineGun" then
		-- Archer sur une petite tour crénelée.
		block("Keep", Vector3.new(2.65, 2.2, 2.65), Vector3.new(0, 1.9, 0), stone, Enum.Material.Brick)
		block("Platform", Vector3.new(3.35, 0.28, 3.35), Vector3.new(0, 3.14, 0), wood, Enum.Material.WoodPlanks)
		for _, offset in {
			Vector3.new(-1.28, 3.55, -1.28), Vector3.new(1.28, 3.55, -1.28),
			Vector3.new(-1.28, 3.55, 1.28), Vector3.new(1.28, 3.55, 1.28),
		} do
			block("Crenel", Vector3.new(0.55, 0.7, 0.55), offset, stone, Enum.Material.Brick)
		end
		-- Silhouette dégagée, jambes décalées et bras réellement en position de tir.
		for _, side in { -1, 1 } do
			local z = side * 0.2
			block("Boot", Vector3.new(0.44, 0.46, 0.7), Vector3.new(side * 0.35, 3.51, z - 0.12), darkWood, Enum.Material.Fabric)
			beam("Leg", Vector3.new(side * 0.35, 3.65, z), Vector3.new(side * 0.25, 4.35, 0), 0.36, darkStone, Enum.Material.Fabric)
			block("BootCuff", Vector3.new(0.46, 0.13, 0.48), Vector3.new(side * 0.35, 3.78, z), wood, Enum.Material.Fabric)
		end
		block("TunicSkirt", Vector3.new(1.15, 0.5, 0.83), Vector3.new(0, 4.25, 0), accent, Enum.Material.Fabric)
		block("ArcherTorso", Vector3.new(1.05, 1.18, 0.72), Vector3.new(0, 4.95, 0), accent, Enum.Material.Fabric)
		block("LeatherJerkin", Vector3.new(0.83, 0.82, 0.12), Vector3.new(0, 5.02, -0.4), wood, Enum.Material.Fabric)
		beam("ChestStrap", Vector3.new(-0.4, 5.49, -0.49), Vector3.new(0.37, 4.51, -0.49), 0.13, darkWood, Enum.Material.Fabric)
		ball("Hood", 1.02, Vector3.new(0, 5.94, 0.08), accent:Lerp(darkStone, 0.4), Enum.Material.Fabric)
		block("Face", Vector3.new(0.63, 0.68, 0.36), Vector3.new(0, 5.9, -0.32), skin, Enum.Material.SmoothPlastic)
		block("HoodBrow", Vector3.new(0.83, 0.16, 0.48), Vector3.new(0, 6.25, -0.28), accent:Lerp(darkStone, 0.5), Enum.Material.Fabric)
		for _, side in { -1, 1 } do
			block("Eye", Vector3.new(0.1, 0.09, 0.025), Vector3.new(side * 0.17, 5.99, -0.515), darkWood, Enum.Material.SmoothPlastic)
			block("Eyebrow", Vector3.new(0.17, 0.045, 0.03), Vector3.new(side * 0.17, 6.08, -0.52), darkWood, Enum.Material.SmoothPlastic)
		end
		block("Nose", Vector3.new(0.12, 0.18, 0.12), Vector3.new(0, 5.87, -0.53), skin, Enum.Material.SmoothPlastic)
		block("Mouth", Vector3.new(0.2, 0.035, 0.03), Vector3.new(0, 5.71, -0.515), darkWood, Enum.Material.SmoothPlastic)
		beam("BowSleeve", Vector3.new(-0.54, 5.3, 0), Vector3.new(-0.65, 5.27, -0.75), 0.4, accent, Enum.Material.Fabric)
		beam("BowBracer", Vector3.new(-0.65, 5.27, -0.75), Vector3.new(-0.3, 5.34, -1.5), 0.28, darkWood, Enum.Material.Fabric)
		ball("BowHand", 0.3, Vector3.new(-0.3, 5.34, -1.55), skin, Enum.Material.SmoothPlastic)
		beam("DrawSleeve", Vector3.new(0.52, 5.3, 0), Vector3.new(0.9, 5.45, 0.25), 0.38, accent, Enum.Material.Fabric)
		beam("DrawForearm", Vector3.new(0.9, 5.45, 0.25), Vector3.new(-0.2, 5.45, -0.46), 0.26, skin, Enum.Material.SmoothPlastic)
		ball("DrawHand", 0.27, Vector3.new(-0.25, 5.45, -0.48), skin, Enum.Material.SmoothPlastic)
		local bow = { Vector3.new(-0.3, 6.85, -1.13), Vector3.new(-0.3, 6.5, -1.52), Vector3.new(-0.3, 5.91, -1.76), Vector3.new(-0.3, 5.4, -1.62), Vector3.new(-0.3, 4.89, -1.76), Vector3.new(-0.3, 4.3, -1.52), Vector3.new(-0.3, 3.95, -1.13) }
		for i = 2, #bow do
			beam("LongbowLimb", bow[i - 1], bow[i], 0.14, wood, Enum.Material.Wood)
		end
		beam("BowGrip", Vector3.new(-0.3, 5.16, -1.63), Vector3.new(-0.3, 5.62, -1.63), 0.21, darkWood, Enum.Material.Fabric)
		local nock = Vector3.new(-0.3, 5.45, -0.5)
		for _, tip in { bow[1], bow[#bow] } do
			bowString(tip, nock, Vector3.new(-0.3, 5.45, -1.13), 0.035)
		end
		block("Arrow", Vector3.new(0.07, 0.07, 2.25), Vector3.new(-0.3, 5.45, -1.625), wood, Enum.Material.Wood)
		wedge(model, "ArrowHead", { Size = Vector3.new(0.24, 0.12, 0.36), CFrame = cf(Vector3.new(-0.3, 5.45, -2.83), CFrame.Angles(0, math.pi, 0)), Color = iron, Material = Enum.Material.Metal })
		block("ArrowFeather", Vector3.new(0.24, 0.045, 0.32), Vector3.new(-0.3, 5.45, -0.7), paleStone, Enum.Material.Fabric)
		block("Quiver", Vector3.new(0.5, 1.18, 0.5), Vector3.new(0.54, 5, 0.49), darkWood, Enum.Material.Fabric, CFrame.Angles(0, 0, -0.2))
		for i = 1, 3 do
			local x = 0.35 + i * 0.14
			beam("SpareArrow", Vector3.new(x, 5.35, 0.5), Vector3.new(x + 0.13, 6.02 + i * 0.06, 0.5), 0.055, wood, Enum.Material.Wood)
			block("QuiverFeather", Vector3.new(0.17, 0.28, 0.06), Vector3.new(x + 0.11, 5.92 + i * 0.06, 0.5), paleStone, Enum.Material.Fabric)
		end

	elseif shape == "Frost" then
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

	elseif shape == "Bomb" then
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

	elseif shape == "Tesla" then
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

	elseif shape == "Laser" then
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
			{ Vector3.new(-0.65, 5.95, 0.45), -45 }, { Vector3.new(0.65, 5.95, 0.45), 45 },
			{ Vector3.new(-0.65, 7.25, 0.45), 45 }, { Vector3.new(0.65, 7.25, 0.45), -45 },
		} do
			block("ArcaneFrame" .. index, Vector3.new(1.75, 0.12, 0.12), data[1], gold, Enum.Material.Metal, CFrame.Angles(0, 0, math.rad(data[2])))
		end

	elseif shape == "Chain" then
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

	elseif shape == "Orbital" then
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
		for _, side in { -1, 1 } do
			block("TimberSkid", Vector3.new(0.5, 0.42, 4), Vector3.new(side * 1.1, 1.05, 0.1), darkWood, Enum.Material.Wood)
			beam("Trestle", Vector3.new(side * 1.1, 1.25, 0.8), Vector3.new(side * 0.55, 2.83, -0.2), 0.42, wood, Enum.Material.Wood)
			beam("FrontBrace", Vector3.new(side * 1.1, 1.25, -1.4), Vector3.new(side * 0.55, 2.8, -0.2), 0.28, darkWood, Enum.Material.Wood)
			block("StockRail", Vector3.new(0.24, 0.35, 4.6), Vector3.new(side * 0.28, 3.04, -0.3), wood, Enum.Material.Wood)
			block("TorsionPost", Vector3.new(0.38, 1.15, 0.5), Vector3.new(side * 0.65, 3.1, -1.65), darkWood, Enum.Material.Wood)
			cylinder("RopeBundle", Vector3.new(0.73, 0.3, 0.3), Vector3.new(side * 0.65, 3.16, -1.65), paleStone, Enum.Material.Fabric, VERTICAL_CYLINDER)
			local bow = { Vector3.new(side * 0.7, 3.31, -1.64), Vector3.new(side * 1.45, 3.31, -1.8), Vector3.new(side * 2.3, 3.31, -1.62), Vector3.new(side * 2.95, 3.31, -1.05) }
			for i = 2, #bow do
				beam("WoodenBowLimb", bow[i - 1], bow[i], 0.26 - i * 0.025, wood, Enum.Material.Wood)
			end
			bowString(bow[#bow], Vector3.new(0, 3.31, 1.1), Vector3.new(0, 3.31, -1.05), 0.065)
			for _, z in { -1.25, 0.95 } do
				block("RailBinding", Vector3.new(0.27, 0.39, 0.14), Vector3.new(side * 0.28, 3.04, z), darkIron, Enum.Material.Metal)
			end
		end
		for _, z in { -1.25, 1.3 } do
			block("CrossBrace", Vector3.new(2.7, 0.35, 0.38), Vector3.new(0, 1.25, z), wood, Enum.Material.Wood)
		end
		block("StockBed", Vector3.new(0.8, 0.22, 4.8), Vector3.new(0, 2.8, -0.3), darkWood, Enum.Material.Wood)
		block("TorsionLintel", Vector3.new(1.9, 0.24, 0.65), Vector3.new(0, 3.75, -1.65), wood, Enum.Material.Wood)
		block("Bolt", Vector3.new(0.14, 0.14, 4.2), Vector3.new(0, 3.31, -1), wood, Enum.Material.Wood)
		wedge(model, "BoltHead", { Size = Vector3.new(0.45, 0.24, 0.65), CFrame = cf(Vector3.new(0, 3.31, -3.33), CFrame.Angles(0, math.pi, 0)), Color = iron, Material = Enum.Material.Metal })
		for _, angle in { 0, math.pi / 2 } do
			block("BoltFeather", Vector3.new(0.5, 0.05, 0.6), Vector3.new(0, 3.31, 0.72), paleStone, Enum.Material.Wood, CFrame.Angles(0, 0, angle))
		end
		cylinder("WinchDrum", Vector3.new(0.95, 0.48, 0.48), Vector3.new(0, 2.96, 1.8), darkWood, Enum.Material.Wood)
		for i = -2, 2 do
			cylinder("WinchRope", Vector3.new(0.07, 0.53, 0.53), Vector3.new(i * 0.13, 2.96, 1.8), paleStone, Enum.Material.Fabric)
		end
		block("Crank", Vector3.new(0.13, 0.78, 0.13), Vector3.new(0.65, 2.7, 1.8), darkIron, Enum.Material.Metal)
		cylinder("CrankHandle", Vector3.new(0.5, 0.18, 0.18), Vector3.new(0.86, 2.32, 1.8), wood, Enum.Material.Wood)
	end

	-- Détails structurels : un budget fixe par tour, sans lumières ni émetteurs permanents.
	if shape == "MachineGun" then
		for _, x in { -1.22, 1.22 } do
			block("CornerButtress", Vector3.new(0.4, 2.1, 0.48), Vector3.new(x, 1.9, -1.3), paleStone, Enum.Material.Limestone)
		end
		block("ArrowSlit", Vector3.new(0.28, 1.15, 0.08), Vector3.new(0, 2.05, -1.35), darkStone, Enum.Material.Slate)
		block("WaistBelt", Vector3.new(1.16, 0.17, 0.86), Vector3.new(0, 4.48, 0), darkWood, Enum.Material.Fabric)
		block("Buckle", Vector3.new(0.22, 0.22, 0.08), Vector3.new(0, 4.48, -0.47), gold, Enum.Material.Metal)
		block("Cape", Vector3.new(1.1, 1.8, 0.14), Vector3.new(0, 4.62, 0.48), accent:Lerp(darkStone, 0.35), Enum.Material.Fabric, CFrame.Angles(math.rad(-10), 0, 0))
		for _, x in { -0.51, 0.51 } do
			ball("ShoulderGuard", 0.42, Vector3.new(x, 5.24, 0), iron, Enum.Material.Metal)
		end
		MedievalModels.banner(model, cf(Vector3.new(1.75, 0.8, 0.5)), accent, 0.55)
	elseif shape == "Bomb" or shape == "Orbital" then
		local wheelX = if shape == "Bomb" then 1.62 else 1.7
		local diameter = if shape == "Bomb" then 1.85 else 2.05
		for _, side in { -1, 1 } do
			-- Faces métalliques et rayons contrastés sur l'extérieur de chaque roue.
			cylinder("WheelTyre", Vector3.new(0.12, diameter + 0.12, diameter + 0.12), Vector3.new(side * (wheelX + 0.23), 1.05, 0.3), darkIron, Enum.Material.Metal)
			cylinder("WheelFace", Vector3.new(0.14, diameter - 0.22, diameter - 0.22), Vector3.new(side * (wheelX + 0.25), 1.05, 0.3), wood, Enum.Material.Wood)
			for i = 0, 2 do
				block("WheelSpoke", Vector3.new(0.17, diameter - 0.15, 0.1), Vector3.new(side * (wheelX + 0.34), 1.05, 0.3), paleStone, Enum.Material.Wood, CFrame.Angles(i * math.pi / 3, 0, 0))
			end
			cylinder("AxlePin", Vector3.new(0.26, 0.4, 0.4), Vector3.new(side * (wheelX + 0.4), 1.05, 0.3), iron, Enum.Material.Metal)
			block("IronBrace", Vector3.new(0.48, 0.22, 2.7), Vector3.new(side * 1.2, 1.28, 0.25), darkIron, Enum.Material.Metal)
		end
		ball("ReserveStone", 0.65, Vector3.new(0.85, 1.62, -0.8), darkStone, Enum.Material.Rock)
		MedievalModels.banner(model, cf(Vector3.new(-1.1, 1.2, 1.3)), accent, if shape == "Orbital" then 0.68 else 0.45)
	elseif shape == "Rocket" then
		for i = 1, 3 do
			block("ReserveBolt", Vector3.new(0.12, 0.12, 2.4), Vector3.new(-1.1 + i * 0.2, 1.5, 0.1), wood, Enum.Material.Wood)
		end
	elseif shape == "Tesla" or shape == "Chain" then
		local oracle = shape == "Chain"
		local torsoY = if oracle then 3.15 else 2.45
		local hoodY = if oracle then 4.72 else 4.35
		block("MageStole", Vector3.new(0.35, 2.1, 0.12), Vector3.new(0, torsoY, -0.67), accent, Enum.Material.Fabric)
		block("StoleClasp", Vector3.new(0.32, 0.32, 0.13), Vector3.new(0, torsoY + 0.65, -0.74), gold, Enum.Material.Metal, CFrame.Angles(0, 0, math.pi / 4))
		for _, side in { -1, 1 } do
			block("RobePleat", Vector3.new(0.7, 2.1, 0.9), Vector3.new(side * 0.55, torsoY - 0.1, 0.2), Color3.fromRGB(48, 49, 74), Enum.Material.Fabric, CFrame.Angles(0, 0, side * 0.16))
			block("Sleeve", Vector3.new(0.48, 1.4, 0.55), Vector3.new(side * 0.88, torsoY + 0.4, -0.15), accent:Lerp(darkStone, 0.65), Enum.Material.Fabric, CFrame.Angles(math.rad(-25), 0, side * -0.25))
			ball("Hand", 0.32, Vector3.new(side * 1.02, torsoY - 0.15, -0.48), skin, Enum.Material.SmoothPlastic)
		end
		block("HoodShadow", Vector3.new(0.53, 0.38, 0.08), Vector3.new(0, hoodY + 0.02, -0.68), darkStone, Enum.Material.Fabric)
		for _, x in { -0.13, 0.13 } do
			block("MageEye", Vector3.new(0.11, 0.07, 0.04), Vector3.new(x, hoodY + 0.08, -0.73), accent, Enum.Material.Neon)
		end
		for i = 1, 6 do
			local a = i * math.pi / 3
			block("AltarRune", Vector3.new(0.45, 0.06, 0.12), Vector3.new(math.cos(a) * 1.4, 0.89, math.sin(a) * 1.4), gold, Enum.Material.Metal, CFrame.Angles(0, -a, 0))
		end
	elseif shape == "Frost" then
		for i = 1, 5 do
			local a = i / 5 * math.pi * 2
			wedge(model, "IceOutcrop", { Size = Vector3.new(0.55, 1.1, 0.7), CFrame = cf(Vector3.new(math.cos(a) * 1.45, 1.05, math.sin(a) * 1.45), CFrame.Angles(0, -a, 0)), Color = accent:Lerp(Color3.new(1, 1, 1), 0.4), Material = Enum.Material.Ice })
		end
	elseif shape == "Laser" then
		for _, y in { 1.55, 4.9 } do
			block("ObeliskBand", Vector3.new(1.48, 0.18, 1.48), Vector3.new(0, y, 0), gold, Enum.Material.Metal, CFrame.Angles(0, math.pi / 4, 0))
		end
		for _, side in { -1, 1 } do
			wedge(model, "ObeliskFoot", { Size = Vector3.new(0.6, 1.8, 1.2), CFrame = cf(Vector3.new(side * 0.9, 1.7, 0), CFrame.Angles(0, side * math.pi / 2, 0)), Color = paleStone, Material = Enum.Material.Limestone })
		end
	end

	-- PARURE DU PALIER 2 : une tour sortie d'un œuf se reconnaît de loin, en plus de ses couleurs. Un anneau de
	-- lumière à ses couleurs autour du socle, quatre cristaux lumineux posés dessus, et les pièces de son pouvoir qui
	-- s'allument (TIER_GLOW_PARTS) ; pièces fixes, sans lumière ni émetteur permanent, comme le reste du modèle.
	if def.base then
		local glow = accent:Lerp(Color3.new(1, 1, 1), 0.3)
		cylinder("TierRing", Vector3.new(0.14, 4.25, 4.25), Vector3.new(0, 0.62, 0), glow, Enum.Material.Neon, VERTICAL_CYLINDER)
		for i = 1, 4 do
			local angle = (i - 0.5) * math.pi / 2
			local crystal = block("TierCrystal", Vector3.new(0.3, 0.75, 0.3), Vector3.new(math.cos(angle) * 1.95, 0.95, math.sin(angle) * 1.95), glow, Enum.Material.Neon, CFrame.Angles(0, -angle, math.rad(14)))
			crystal.CastShadow = false
		end
		local glowing = TIER_GLOW_PARTS[shape] or {}
		for _, child in model:GetChildren() do
			if glowing[child.Name] and child:IsA("BasePart") then
				child.Material = Enum.Material.Neon
				child.Color = glow
				child.Transparency = 0
			end
		end
	end

	model.PrimaryPart = base
	model:SetAttribute("TowerType", towerType)
	model:SetAttribute("RestCFrame", cframe)
	model:SetAttribute("AimFrame", cframe)
	for key, value in attributes do
		model:SetAttribute(key, value)
	end
	model.Parent = parent
	return model
end

-- ÉVOLUTIONS (nouvelle formule, Shared/Levels.luau : Levels.evolutionStage). Une tour évoluée se reconnaît de loin :
--   1re évolution : anneau de BRONZE autour du socle et 4 clous ;
--   2e évolution  : anneau d'ARGENT, 4 hampes et leurs fanions aux couleurs de la tour ;
--   3e évolution  : anneau d'OR, hampes plus hautes, 4 joyaux lumineux et un halo doré sur le socle.
-- Les pièces sont ajoutées au modèle (elles tournent avec lui quand la tour vise). L'attribut « Stars » (0 à 3) est lu
-- par les clients pour afficher les étoiles. À appeler juste après create, une seule fois.
local EVOLUTION_METALS = {
	Color3.fromRGB(176, 112, 62),
	Color3.fromRGB(198, 204, 212),
	Color3.fromRGB(240, 196, 84),
}

function IdleTowerModel.addEvolution(model: Model, stage: number)
	local level = math.clamp(math.floor(tonumber(stage) or 0), 0, #EVOLUTION_METALS)
	model:SetAttribute("Stars", level)
	local cframe = model:GetAttribute("RestCFrame")
	local def = IdleTowers.Defs[model:GetAttribute("TowerType")]
	if level <= 0 or typeof(cframe) ~= "CFrame" or not def then
		return
	end
	local metal = EVOLUTION_METALS[level]
	local function at(offset: Vector3, rotation: CFrame?): CFrame
		return cframe * CFrame.new(offset) * (rotation or CFrame.new())
	end
	part(model, "EvolutionRing", {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.18, 4.7, 4.7),
		CFrame = at(Vector3.new(0, 0.1, 0), VERTICAL_CYLINDER),
		Color = metal,
		Material = Enum.Material.Metal,
	})
	for i = 1, 4 do
		local angle = (i - 0.5) * math.pi / 2
		local foot = Vector3.new(math.cos(angle) * 2.2, 0.36, math.sin(angle) * 2.2)
		part(model, "EvolutionStud", {
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * (0.3 + 0.08 * level),
			CFrame = at(foot),
			Color = if level >= 3 then metal:Lerp(Color3.new(1, 1, 1), 0.25) else metal,
			Material = if level >= 3 then Enum.Material.Neon else Enum.Material.Metal,
		})
		if level >= 2 then
			local height = 0.9 + 0.35 * level
			part(model, "EvolutionPost", {
				Size = Vector3.new(0.14, height, 0.14),
				CFrame = at(foot + Vector3.new(0, height / 2, 0)),
				Color = metal,
				Material = Enum.Material.Metal,
			})
			part(model, "EvolutionPennant", {
				Size = Vector3.new(0.06, 0.42, 0.66),
				CFrame = at(foot + Vector3.new(0, height - 0.25, 0.4)),
				Color = def.color,
				Material = Enum.Material.Fabric,
			})
		end
	end
	if level >= 3 then
		part(model, "EvolutionHalo", {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.1, 3.5, 3.5),
			CFrame = at(Vector3.new(0, 0.9, 0), VERTICAL_CYLINDER),
			Color = metal,
			Material = Enum.Material.Neon,
		})
	end
end

return IdleTowerModel

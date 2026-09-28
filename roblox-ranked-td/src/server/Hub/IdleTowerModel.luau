-- Modèles 3D des tours du mode infini (différents de ceux du ranked).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IdleTowers = require(ReplicatedStorage:WaitForChild("Shared").IdleTowers)

local IdleTowerModel = {}

local function newPart(model: Model, name: string, props)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = model
	return part
end

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- les cylindres Roblox sont couchés sur X

-- cframe : position au sol de l'emplacement, orientée comme la parcelle.
function IdleTowerModel.create(towerType: string, cframe: CFrame, parent: Instance, attributes: { [string]: any }): Model
	local def = IdleTowers.Defs[towerType]
	local color = def.color
	local model = Instance.new("Model")
	model.Name = towerType

	local base = newPart(model, "Base", {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 4.4, 4.4),
		CFrame = cframe * CFrame.new(0, 0.5, 0) * UPRIGHT,
		Color = Color3.fromRGB(60, 60, 70),
		CanCollide = true,
	})

	local dark = Color3.fromRGB(45, 45, 50)
	if towerType == "MachineGun" then
		newPart(model, "Body", { Size = Vector3.new(2.4, 2.6, 2.4), CFrame = cframe * CFrame.new(0, 2.3, 0), Color = color })
		for _, x in { -0.5, 0.5 } do
			newPart(model, "Barrel", {
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(3, 0.5, 0.5),
				CFrame = cframe * CFrame.new(x, 3.2, 1.6) * CFrame.Angles(0, math.rad(90), 0),
				Color = dark,
			})
		end
	elseif towerType == "Frost" then
		newPart(model, "Body", { Size = Vector3.new(2, 2.5, 2), CFrame = cframe * CFrame.new(0, 2.2, 0), Color = Color3.fromRGB(200, 220, 235) })
		newPart(model, "Crystal", {
			Size = Vector3.new(1.6, 3, 1.6),
			CFrame = cframe * CFrame.new(0, 5, 0) * CFrame.Angles(0, math.rad(45), math.rad(45)),
			Color = color,
			Material = Enum.Material.Neon,
			Transparency = 0.2,
		})
	elseif towerType == "Bomb" then
		newPart(model, "Body", { Size = Vector3.new(3, 1.6, 3), CFrame = cframe * CFrame.new(0, 1.8, 0), Color = dark })
		newPart(model, "Bomb", {
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 2.6,
			CFrame = cframe * CFrame.new(0, 3.8, 0),
			Color = Color3.fromRGB(30, 30, 35),
		})
		newPart(model, "Fuse", {
			Size = Vector3.new(0.3, 0.8, 0.3),
			CFrame = cframe * CFrame.new(0, 5.4, 0),
			Color = color,
			Material = Enum.Material.Neon,
		})
	elseif towerType == "Tesla" then
		newPart(model, "Body", {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(4.5, 1.2, 1.2),
			CFrame = cframe * CFrame.new(0, 3.2, 0) * UPRIGHT,
			Color = Color3.fromRGB(150, 150, 160),
			Material = Enum.Material.Metal,
		})
		for i, y in { 2, 3.3, 4.6 } do
			newPart(model, "Coil" .. i, {
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.3, 2.2, 2.2),
				CFrame = cframe * CFrame.new(0, y, 0) * UPRIGHT,
				Color = Color3.fromRGB(190, 120, 60),
				Material = Enum.Material.Metal,
			})
		end
		newPart(model, "Orb", {
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 1.6,
			CFrame = cframe * CFrame.new(0, 6.1, 0),
			Color = color,
			Material = Enum.Material.Neon,
		})
	elseif towerType == "Laser" then
		newPart(model, "Body", { Size = Vector3.new(1.6, 5, 1.6), CFrame = cframe * CFrame.new(0, 3.5, 0), Color = Color3.fromRGB(230, 230, 240) })
		newPart(model, "Lens", {
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 1.8,
			CFrame = cframe * CFrame.new(0, 6.6, 0),
			Color = color,
			Material = Enum.Material.Neon,
		})
		newPart(model, "Ring", {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3, 3, 3),
			CFrame = cframe * CFrame.new(0, 5.4, 0) * UPRIGHT,
			Color = color,
			Material = Enum.Material.Neon,
		})
	elseif towerType == "Chain" then
		newPart(model, "Body", { Size = Vector3.new(2.2, 4, 2.2), CFrame = cframe * CFrame.new(0, 3, 0), Color = Color3.fromRGB(60, 50, 90) })
		for i, offset in { Vector3.new(1.3, 5.6, 0), Vector3.new(-1.3, 5.6, 0), Vector3.new(0, 6.4, 0) } do
			newPart(model, "Orb" .. i, {
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 1.2,
				CFrame = cframe * CFrame.new(offset),
				Color = color,
				Material = Enum.Material.Neon,
			})
		end
	elseif towerType == "Orbital" then
		newPart(model, "Mast", { Size = Vector3.new(0.8, 7, 0.8), CFrame = cframe * CFrame.new(0, 4.5, 0), Color = Color3.fromRGB(200, 205, 215), Material = Enum.Material.Metal })
		newPart(model, "Dish", {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.4, 5, 5),
			CFrame = cframe * CFrame.new(0, 8.2, 0) * CFrame.Angles(math.rad(30), 0, math.rad(90)),
			Color = Color3.fromRGB(230, 235, 245),
			Material = Enum.Material.Metal,
		})
		newPart(model, "Beacon", {
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.9,
			CFrame = cframe * CFrame.new(0, 9, 0),
			Color = color,
			Material = Enum.Material.Neon,
		})
	else -- Rocket
		newPart(model, "Body", { Size = Vector3.new(2.6, 2, 2.6), CFrame = cframe * CFrame.new(0, 2, 0), Color = dark })
		newPart(model, "Launcher", {
			Size = Vector3.new(2.6, 1.8, 3.6),
			CFrame = cframe * CFrame.new(0, 3.8, 0) * CFrame.Angles(math.rad(-20), 0, 0),
			Color = color,
		})
		for _, x in { -0.6, 0.6 } do
			newPart(model, "Rocket", {
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(1.2, 0.6, 0.6),
				CFrame = cframe * CFrame.new(x, 4.2, 2) * CFrame.Angles(math.rad(-20), math.rad(90), 0),
				Color = Color3.fromRGB(230, 230, 230),
			})
		end
	end

	model.PrimaryPart = base
	model:SetAttribute("TowerType", towerType)
	for key, value in attributes do
		model:SetAttribute(key, value)
	end
	model.Parent = parent
	return model
end

return IdleTowerModel

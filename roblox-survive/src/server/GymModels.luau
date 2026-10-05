-- Les machines de la salle de sport, faites de blocs (aucun modèle de la bibliothèque Roblox).
-- Chaque machine est un Model posé sur un tapis bleu en damier ; sa pièce « Base » porte l'étiquette et le bouton.
local Build = require(script.Parent.Build)

local GymModels = {}

local DARK = Color3.fromRGB(52, 54, 62)
local BLACK = Color3.fromRGB(24, 24, 28)
local STEEL = Color3.fromRGB(150, 155, 165)
local MAT_A = Color3.fromRGB(96, 190, 255)
local MAT_B = Color3.fromRGB(140, 212, 255)
local BORDER = Color3.fromRGB(170, 174, 184)
local YELLOW = Color3.fromRGB(235, 255, 60)

-- Tapis bleu en damier avec un bord gris, comme dans une vraie salle.
local function mat(model: Model, origin: Vector3, sizeX: number, sizeZ: number): Part
	Build.part(model, "Border", Vector3.new(sizeX + 2, 0.3, sizeZ + 2), origin + Vector3.new(0, 0.15, 0), BORDER)
	Build.checker(model, "Mat", origin + Vector3.new(0, 0.5, 0), sizeX, sizeZ, 4, MAT_A, MAT_B, 0.5)
	local base = Build.part(model, "Base", Vector3.new(sizeX, 0.2, sizeZ), origin + Vector3.new(0, 0.3, 0), MAT_A)
	base.Transparency = 1
	base.CanCollide = false
	model.PrimaryPart = base
	return base
end

local function at(origin: Vector3, x: number, y: number, z: number): Vector3
	return origin + Vector3.new(x, y + 0.5, z)
end

-- Tapis de course : sombre, avec des flèches jaunes qui brillent sur la bande.
function GymModels.Speed(parent: Instance, origin: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "Speed"
	mat(model, origin, 16, 20)
	for _, x in { -4, 4 } do
		Build.part(model, "Deck", Vector3.new(5, 1.2, 12), at(origin, x, 0.6, 1), DARK)
		Build.part(model, "Belt", Vector3.new(3.8, 0.2, 10.6), at(origin, x, 1.25, 1), BLACK)
		-- Flèches : deux petites barres en V, trois fois.
		for i = 0, 2 do
			for _, side in { -1, 1 } do
				local arrow = Build.part(
					model,
					"Arrow",
					Vector3.new(1.7, 0.08, 0.35),
					CFrame.new(at(origin, x + side * 0.6, 1.38, -2 + i * 3)) * CFrame.Angles(0, math.rad(side * 40), 0),
					YELLOW,
					Enum.Material.Neon
				)
				arrow.CanCollide = false
			end
		end
		for _, side in { -1, 1 } do
			Build.part(model, "Post", Vector3.new(0.5, 5.5, 0.5), at(origin, x + side * 2.2, 3.3, -4.2), DARK)
			Build.part(model, "Rail", Vector3.new(0.45, 0.45, 5), at(origin, x + side * 2.2, 5, -1.9), STEEL)
		end
		Build.part(
			model,
			"Console",
			Vector3.new(5, 1.6, 0.6),
			CFrame.new(at(origin, x, 6.3, -4.4)) * CFrame.Angles(math.rad(-25), 0, 0),
			DARK
		)
		local screen = Build.part(
			model,
			"Screen",
			Vector3.new(3, 0.9, 0.1),
			CFrame.new(at(origin, x, 6.35, -4.05)) * CFrame.Angles(math.rad(-25), 0, 0),
			Color3.fromRGB(80, 255, 140),
			Enum.Material.Neon
		)
		screen.CanCollide = false
	end
	model.Parent = parent
	return model
end

-- Trampoline : il fait vraiment rebondir (voir Gym.luau).
function GymModels.Jump(parent: Instance, origin: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "Jump"
	mat(model, origin, 20, 20)
	Build.disc(model, "Frame", 15, 0.9, at(origin, 0, 2.6, 0), Color3.fromRGB(45, 110, 235))
	local bounce = Build.disc(model, "Bounce", 12.4, 0.5, at(origin, 0, 2.95, 0), BLACK, Enum.Material.Fabric)
	bounce:AddTag("Bounce")
	local ring = Build.disc(model, "Ring", 5, 0.1, at(origin, 0, 3.22, 0), YELLOW, Enum.Material.Neon)
	ring.CanCollide = false
	for i = 1, 6 do
		local angle = math.rad(i * 60)
		Build.part(
			model,
			"Leg",
			Vector3.new(0.6, 2.4, 0.6),
			at(origin, math.cos(angle) * 6.8, 1.2, math.sin(angle) * 6.8),
			STEEL,
			Enum.Material.Metal
		)
	end
	-- Petit escalier pour monter dessus.
	Build.part(model, "Step", Vector3.new(4, 1.2, 2.5), at(origin, 0, 0.6, 8.6), DARK)
	model.Parent = parent
	return model
end

-- Banc de musculation : un banc, un support et une barre avec ses poids, plus un support d'haltères.
function GymModels.Force(parent: Instance, origin: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "Force"
	mat(model, origin, 20, 20)
	Build.part(model, "Bench", Vector3.new(2.4, 0.7, 8), at(origin, -3, 2, 0.5), Color3.fromRGB(120, 124, 134))
	for _, z in { -2.5, 3.5 } do
		Build.part(model, "BenchLeg", Vector3.new(2, 1.7, 0.6), at(origin, -3, 0.85, z), BLACK)
	end
	for _, side in { -1, 1 } do
		Build.part(model, "Upright", Vector3.new(0.6, 6.5, 0.6), at(origin, -3 + side * 3.2, 3.25, -2.6), BLACK, Enum.Material.Metal)
		Build.part(model, "Foot", Vector3.new(0.6, 0.5, 5), at(origin, -3 + side * 3.2, 0.25, -1.6), BLACK, Enum.Material.Metal)
		Build.part(model, "Hook", Vector3.new(0.6, 0.4, 1.2), at(origin, -3 + side * 3.2, 5, -1.9), BLACK, Enum.Material.Metal)
	end
	Build.part(model, "Bar", Vector3.new(12, 0.35, 0.35), at(origin, -3, 5.4, -1.9), STEEL, Enum.Material.Metal).Shape = Enum.PartType.Cylinder
	for _, side in { -1, 1 } do
		for i = 0, 1 do
			local plate = Build.part(
				model,
				"Plate",
				Vector3.new(0.5, 3.4 - i * 0.6, 3.4 - i * 0.6),
				at(origin, -3 + side * (4.3 + i * 0.6), 5.4, -1.9),
				BLACK
			)
			plate.Shape = Enum.PartType.Cylinder
		end
	end
	-- Support d'haltères sur le côté.
	Build.part(model, "Rack", Vector3.new(4, 2.2, 9), at(origin, 6, 1.1, 0), DARK)
	for i = 0, 2 do
		local z = -3 + i * 3
		Build.part(model, "Grip", Vector3.new(0.3, 0.3, 1.6), at(origin, 6, 2.6, z), STEEL, Enum.Material.Metal)
		for _, side in { -1, 1 } do
			local weight = Build.part(
				model,
				"Weight",
				Vector3.new(1.3, 1.3, 0.6),
				at(origin, 6, 2.6, z + side * 0.9),
				({ Color3.fromRGB(235, 70, 70), Color3.fromRGB(255, 190, 40), Color3.fromRGB(70, 200, 90) })[i + 1]
			)
			weight.CanCollide = false
		end
	end
	model.Parent = parent
	return model
end

return GymModels

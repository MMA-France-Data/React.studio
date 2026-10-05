-- Machines habillées avec des modèles gratuits du Creator Store, sans leurs scripts.
-- Chaque machine est un Model posé sur un tapis bleu en damier ; sa pièce « Base » porte l'étiquette et le bouton.
local Build = require(script.Parent.Build)
local LibraryVisuals = require(script.Parent.LibraryVisuals)

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
		local deck = Build.part(model, "Deck", Vector3.new(5, 1.2, 12), at(origin, x, 0.6, 1), DARK)
		deck.Transparency = 1 -- same walking surface; imported geometry has no collision
		local belt = Build.part(model, "Belt", Vector3.new(3.8, 0.2, 10.6), at(origin, x, 1.25, 1), BLACK)
		belt.Transparency = 1
		local visual = LibraryVisuals.place(model, "Treadmill", at(origin, x, 0, 1), Vector3.new(5.5, 8, 12))
		for _, part in visual:GetDescendants() do
			if part:IsA("BasePart") then
				part.Color = DARK
				part.Material = Enum.Material.Metal
			end
		end
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
	end
	model.Parent = parent
	return model
end

-- Trampoline : il fait vraiment rebondir (voir Gym.luau).
function GymModels.Jump(parent: Instance, origin: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "Jump"
	mat(model, origin, 20, 20)
	local visual = LibraryVisuals.place(model, "Trampoline", at(origin, 0, 0, 0), Vector3.new(15, 30, 15))
	local surface = visual:FindFirstChild("Bouncy", true)
	assert(surface and surface:IsA("BasePart"), "Trampoline visual surface is missing")
	local lift = 3.7 + origin.Y - (surface.Position.Y + surface.Size.Y / 2)
	visual:PivotTo(visual:GetPivot() + Vector3.new(0, lift, 0))
	local bounce = Build.disc(model, "Bounce", 12.4, 0.5, at(origin, 0, 2.95, 0), BLACK, Enum.Material.Fabric)
	bounce.Transparency = 1 -- the original tagged collider is the only bounce trigger
	bounce:AddTag("Bounce")
	local ring = Build.disc(model, "Ring", 5, 0.1, at(origin, 0, 3.22, 0), YELLOW, Enum.Material.Neon)
	ring.CanCollide = false
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
	LibraryVisuals.place(model, "BenchPress", at(origin, -3, 0, 0), Vector3.new(12, 8, 15))
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

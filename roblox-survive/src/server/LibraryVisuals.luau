-- Local, sanitized Creator Store templates. No runtime marketplace requests or imported scripts.
local ServerStorage = game:GetService("ServerStorage")
local templates = ServerStorage:WaitForChild("LibraryVisuals")
local LibraryVisuals = {}

function LibraryVisuals.clone(name: string): Model
	local template = templates:FindFirstChild(name)
	assert(template and template:IsA("Model"), "Missing visual template: " .. name)
	local model = template:Clone()
	for _, object in model:GetDescendants() do
		if object:IsA("LuaSourceContainer") then
			object:Destroy()
		elseif object:IsA("BasePart") then
			object.Anchored = true
			object.CanCollide = false
			object.CanTouch = false
			object.CanQuery = false
		end
	end
	return model
end

-- Origin is the middle of the footprint, at floor level; aspect ratio is preserved.
function LibraryVisuals.place(parent: Instance, name: string, origin: Vector3, limits: Vector3, yaw: number?): Model
	local model = LibraryVisuals.clone(name)
	local _, size = model:GetBoundingBox()
	local scale = math.min(limits.X / size.X, limits.Y / size.Y, limits.Z / size.Z)
	model:ScaleTo(scale)
	local box, scaledSize = model:GetBoundingBox()
	model:PivotTo(CFrame.new(origin + Vector3.new(0, scaledSize.Y / 2, 0))
		* CFrame.Angles(0, yaw or 0, 0) * box:Inverse() * model:GetPivot())
	model.Parent = parent
	return model
end

-- One mesh per meteor. Gameplay still controls its trajectory and damage.
function LibraryVisuals.meteor(parent: Instance, position: Vector3): BasePart
	local model = LibraryVisuals.clone("Meteor")
	local rock = model:FindFirstChildWhichIsA("BasePart", true)
	assert(rock, "Meteor mesh is missing")
	rock.Parent = nil
	model:Destroy()
	rock.Name = "Meteor"
	rock.Size = Vector3.new(5, 5, 5)
	rock.CFrame = CFrame.new(position)
	rock.Material = Enum.Material.Slate
	rock.Color = Color3.fromRGB(72, 57, 50)
	rock.Parent = parent
	return rock
end

-- Dress an existing collision box, without changing any jump heights or surfaces.
function LibraryVisuals.stonePlatform(parent: Instance, platform: BasePart)
	local depth = 3
	local rock = LibraryVisuals.clone("Rock")
	-- A colored top remains legible; the real collision box is unchanged.
	for _, part in rock:GetDescendants() do
		if part:IsA("BasePart") then
			part.Size = Vector3.new(platform.Size.X * 0.98, depth, platform.Size.Z * 0.98)
			part.CFrame = platform.CFrame * CFrame.new(0, -platform.Size.Y / 2 - depth / 2 + 0.3, 0)
			part.Color = Color3.fromRGB(99, 91, 88)
			part.Material = Enum.Material.Slate
		end
	end
	rock.Name = platform.Name .. "Rock"
	rock.Parent = parent
	return rock
end

return LibraryVisuals

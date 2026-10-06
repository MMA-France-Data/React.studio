-- Compagnons de la bibliothèque : uniquement des modèles locaux nettoyés.
-- Aucun chargement depuis le Creator Store, script importé ou animation de PNJ en partie.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PetModels = {}

-- Les rigs gardent leurs dimensions et poses de liaison d'origine dans les assets.
-- ScaleTo adapte ensemble le maillage, les os et les attaches, sans casser le skinning.
local RIG_SIZE = {
	Dragon = { maximum = 4.6 },
	Rock = { maximum = 3.3 },
	Rabbit = { height = 2.9 },
	Golem = { height = 3.6, yaw = -math.pi / 2 },
	Owl = { height = 2.9 },
}

local function accent(model: Model, name: string, position: Vector3, size: Vector3, color: Color3, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = CFrame.new(position)
	part.Color = color
	part.Material = Enum.Material.Neon
	part.Shape = shape or Enum.PartType.Ball
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Parent = model
	return part
end

function PetModels.build(name: string): Model?
	local folder = ReplicatedStorage:FindFirstChild("PetVisuals")
	local template = folder and folder:FindFirstChild(name)
	if not template or not template:IsA("Model") then
		-- Anciennes places et tests isolés : Pets garde son modèle de secours.
		return nil
	end
	local model = template:Clone()
	model.Name = name
	-- LES ANIMAUX DES COLLECTIONS (assets/collections) : des briques Roblox articulées autour de « RigRoot », avec
	-- leurs animations dans le modèle (lues par StarterAnimator). Ils gardent leurs couleurs et leur taille.
	local rigRoot = model:FindFirstChild("RigRoot")
	-- (Les anciens modèles de la bibliothèque ont parfois un « RigRoot » eux aussi, mais pas ces animations.)
	local walk, idle = model:FindFirstChild("Walk", true), model:FindFirstChild("Idle", true)
	if rigRoot and rigRoot:IsA("BasePart") and walk and walk:IsA("KeyframeSequence") and idle and idle:IsA("KeyframeSequence") then
		for _, instance in model:GetDescendants() do
			if instance:IsA("BasePart") then
				instance.Anchored = true
				instance.CanCollide = false
				instance.CanTouch = false
				instance.CanQuery = false
				instance.CastShadow = false
			end
		end
		model.PrimaryPart = rigRoot
		model:SetAttribute("Starter", true)
		return model
	end
	local hasRig = false
	for _, instance in model:GetDescendants() do
		if instance:IsA("Bone") or instance:IsA("Motor6D") then
			hasRig = true
		end
		if instance:IsA("BasePart") then
			instance.Anchored = true
			instance.CanCollide = false
			instance.CanTouch = false
			instance.CanQuery = false
			instance.CastShadow = false
		end
	end
	-- Pivot stable, indépendant du nom des maillages de la bibliothèque.
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(0.1, 0.1, 0.1)
	local bounds, size = model:GetBoundingBox()
	body.CFrame = if hasRig then CFrame.new(bounds.Position) else CFrame.identity
	body.Transparency = 1
	body.Anchored = true
	body.CanCollide = false
	body.CanTouch = false
	body.CanQuery = false
	body.CastShadow = false
	body.Parent = model
	model.PrimaryPart = body
	if hasRig then
		local dimensions = RIG_SIZE[name]
		model:PivotTo(CFrame.Angles(0, dimensions and dimensions.yaw or 0, 0))
		if dimensions then
			local factor = if dimensions.height then dimensions.height / size.Y else dimensions.maximum / math.max(size.X, size.Y, size.Z)
			model:ScaleTo(factor)
			model:SetAttribute("VisualBaseScale", factor)
		end
		-- Garder l'orientation dans les pièces, pas dans le pivot : le suivi remplace
		-- ensuite le CFrame du modèle et ne doit pas annuler cette correction.
		body.CFrame = CFrame.identity
	end

	if name == "Dragon" then
		if hasRig then
			for _, part in model:GetDescendants() do
				if part:IsA("MeshPart") and part.TextureID == "" then
					part.Color = Color3.fromRGB(175, 54, 32)
					part.Material = Enum.Material.SmoothPlastic
				end
			end
		end
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 105, 30)
		light.Brightness = 0.6
		light.Range = 5
		light.Parent = body
	elseif name == "Rock" and not hasRig then
		-- La vraie pierre conserve le visage et les braises du compagnon d'origine.
		for _, side in { -1, 1 } do
			local eye = accent(model, "Eye", Vector3.new(side * 0.45, 0.25, -1.15), Vector3.new(0.45, 0.45, 0.15), Color3.fromRGB(250, 250, 250), Enum.PartType.Block)
			eye.Material = Enum.Material.SmoothPlastic
			local pupil = accent(model, "Pupil", Vector3.new(side * 0.45, 0.25, -1.18), Vector3.new(0.22, 0.22, 0.16), Color3.fromRGB(20, 20, 26), Enum.PartType.Block)
			pupil.Material = Enum.Material.SmoothPlastic
		end
		for i, spot in { Vector3.new(0.7, 0.8, 0.5), Vector3.new(-0.9, -0.2, 0.6), Vector3.new(0.2, -0.9, -0.5), Vector3.new(-0.5, 0.9, -0.4) } do
			accent(model, "Ember" .. i, spot, Vector3.new(0.4, 0.4, 0.4), Color3.fromRGB(255, 130, 30))
		end
	end
	return model
end

return PetModels

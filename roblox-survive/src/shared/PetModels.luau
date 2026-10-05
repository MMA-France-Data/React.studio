-- Compagnons de la bibliothèque : uniquement des modèles locaux nettoyés.
-- Aucun chargement depuis le Creator Store, script importé ou animation de PNJ en partie.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PetModels = {}

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
	for _, instance in model:GetDescendants() do
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
	body.CFrame = CFrame.identity
	body.Transparency = 1
	body.Anchored = true
	body.CanCollide = false
	body.CanTouch = false
	body.CanQuery = false
	body.CastShadow = false
	body.Parent = model
	model.PrimaryPart = body

	if name == "Dragon" then
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 105, 30)
		light.Brightness = 0.6
		light.Range = 5
		light.Parent = body
	elseif name == "Rock" then
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

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

-- LES ANIMAUX EN MAILLAGE (le nouveau style, 08/10). Deux morceaux pour chacun :
--   ReplicatedStorage.MeshRigs.<Nom> : son squelette (RigRoot, Motor6D) et ses animations, avec des pièces vides ;
--   ReplicatedStorage.MeshImports : ce que le créateur a importé dans Studio (Import 3D du FBX), en vrac.
-- Le jeu fait lui-même l'assemblage (celui des « Assembler-*.luau » de ChatGPT) : chaque pièce vide du squelette est
-- remplacée par son maillage. Tant qu'un animal n'est pas importé, on garde son ancien modèle en blocs.
local MeshRigs = require(script.Parent.MeshRigs)
local meshCache = {}
local function importedMeshes(spec): { [string]: MeshPart }?
	local imports = ReplicatedStorage:FindFirstChild("MeshImports")
	if not imports then
		return nil
	end
	-- Les pièces de tous les animaux portent des noms proches (« Core », « Head »...) : on cherche le groupe importé
	-- qui a EXACTEMENT les pièces de cet animal.
	local best, bestMiss = nil, 0
	local groups = {}
	for _, item in imports:GetDescendants() do
		if item:IsA("MeshPart") and item.Parent then
			groups[item.Parent] = true
		end
	end
	for group in groups do
		local found, count, extra = {}, 0, 0
		for _, item in group:GetChildren() do
			if item:IsA("MeshPart") then
				local short = string.gsub(item.Name, "^Import3D_", "")
				local known = false
				for _, member in spec.members do
					if member.name == short and not found[short] then
						found[short], known = item, true
						count += 1
						break
					end
				end
				if not known then
					extra += 1
				end
			end
		end
		if count == #spec.members and extra == 0 then
			-- (Un animal peut avoir été importé deux fois, après une retouche : on garde l'import dont les pièces ont
			-- les proportions attendues. L'import est en centièmes de stud, d'où le rapport à la première pièce.)
			local first = spec.members[1]
			local unit = found[first.name].Size.Z / first.size[3]
			local miss = 0
			for _, member in spec.members do
				local size = found[member.name].Size / unit
				miss += (size - Vector3.new(table.unpack(member.size))).Magnitude
			end
			if not best or miss < bestMiss then
				best, bestMiss = found, miss
			end
		end
	end
	return best
end
local function meshTemplate(name: string): Model?
	if meshCache[name] ~= nil then
		return meshCache[name] or nil
	end
	meshCache[name] = false
	local spec = MeshRigs[name]
	local rigs = ReplicatedStorage:FindFirstChild("MeshRigs")
	local template = rigs and rigs:FindFirstChild(name)
	local meshes = spec and template and importedMeshes(spec)
	if not meshes then
		return nil
	end
	local rig = template:Clone()
	local ok, problem = pcall(function()
		-- DANS QUEL SENS L'IMPORT EST-IL ARRIVÉ ? Selon les réglages d'Import 3D, les pièces arrivent telles que le
		-- squelette les attend, ou retournées d'un demi-tour (l'avant à la place de l'arrière : le tigre du 08/10 avait
		-- la tête et la mâchoire à l'envers). On compare la place de deux pièces éloignées d'avant en arrière.
		local first, far, depth = spec.members[1], nil, 0
		for _, member in spec.members do
			local dz = math.abs(member.cf[3] - first.cf[3])
			if dz > depth then
				far, depth = member, dz
			end
		end
		local turned = false
		if far then
			local wanted = far.cf[3] - first.cf[3]
			local got = meshes[far.name].Position.Z - meshes[first.name].Position.Z
			turned = wanted * got < 0
		end
		local turn = if turned then CFrame.Angles(0, math.pi, 0) else CFrame.identity
		local placed = {}
		for _, member in spec.members do
			-- (Une articulation porte le meme nom que sa piece : on cherche bien la PIECE.)
			local old = nil
			for _, child in rig:GetChildren() do
				if child.Name == member.name and child:IsA("BasePart") then
					old = child
					break
				end
			end
			assert(old, "piece absente du squelette : " .. member.name)
			local mesh = meshes[member.name]:Clone()
			mesh.Name = member.name
			mesh.Size = Vector3.new(table.unpack(member.size))
			mesh.CFrame = CFrame.new(table.unpack(member.cf)) * turn
			placed[mesh] = true
			mesh.Color = Color3.new(1, 1, 1)
			mesh.Transparency = 0
			mesh.Anchored, mesh.Massless = true, true
			mesh.CanCollide, mesh.CanTouch, mesh.CanQuery = false, false, false
			mesh.CastShadow = false
			for _, child in mesh:GetDescendants() do
				if child:IsA("LuaSourceContainer") or child:IsA("JointInstance") or child:IsA("WeldConstraint") then
					child:Destroy()
				end
			end
			mesh.Parent = rig
			for _, joint in rig:GetDescendants() do
				if joint:IsA("Motor6D") or joint:IsA("Weld") then
					if joint.Part0 == old then
						joint.Part0 = mesh
					end
					if joint.Part1 == old then
						joint.Part1 = mesh
					end
				end
			end
			old:Destroy()
		end
		-- (Les articulations ont été réglées pour des pièces à l'endroit : on y reporte le demi-tour.)
		if turned then
			for _, joint in rig:GetDescendants() do
				if joint:IsA("Motor6D") or joint:IsA("Weld") then
					if placed[joint.Part0] then
						joint.C0 = turn * joint.C0
					end
					if placed[joint.Part1] then
						joint.C1 = turn * joint.C1
					end
				end
			end
		end
		local root = rig:FindFirstChild("RigRoot")
		assert(root and root:IsA("BasePart"), "RigRoot absent")
		rig.PrimaryPart = root
	end)
	if not ok then
		warn("[MONDE] animal en maillage " .. name .. " : " .. tostring(problem))
		rig:Destroy()
		return nil
	end
	rig.Name = name
	rig:SetAttribute("MeshStyle", true)
	meshCache[name] = rig
	return rig
end

function PetModels.build(name: string): Model?
	local folder = ReplicatedStorage:FindFirstChild("PetVisuals")
	local template = meshTemplate(name) or (folder and folder:FindFirstChild(name))
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

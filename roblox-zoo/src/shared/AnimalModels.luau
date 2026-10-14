-- LES ANIMAUX DU ZOO : leur modèle 3D (repris de MONDE : le squelette et les animations de
-- ReplicatedStorage.MeshRigs, habillés des maillages importés dans ReplicatedStorage.MeshImports), à la bonne taille,
-- avec ce qui distingue le mâle de la femelle (les bois du cerf, les cornes du bouc, la crête du coq) et les petits.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(script.Parent.Config)

local AnimalModels = {}

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
		warn("[ZOO] animal en maillage " .. name .. " : " .. tostring(problem))
		rig:Destroy()
		return nil
	end
	rig.Name = name
	rig:SetAttribute("MeshStyle", true)
	meshCache[name] = rig
	return rig
end

-- Les bois du cerf : des branches de bois soudées à la tête (le squelette les emporte quand il bouge la tête).
local function antlers(model: Model)
	local head = model:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local size = head.Size
	local color = Color3.fromRGB(122, 96, 70)
	local function branch(from: CFrame, length: number, width: number): CFrame
		local part = Instance.new("Part")
		part.Name = "Antler"
		part.Size = Vector3.new(width, length, width)
		part.CFrame = from * CFrame.new(0, length / 2, 0)
		part.Color = color
		part.Material = Enum.Material.Wood
		part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery, part.CastShadow = true, false, false, false, false
		part.Parent = model
		local weld = Instance.new("Weld")
		weld.Part0 = head
		weld.Part1 = part
		weld.C0 = head.CFrame:Inverse() * part.CFrame
		weld.Parent = part
		return from * CFrame.new(0, length, 0)
	end
	local unit = math.max(size.X, size.Z) * 0.5
	for _, side in { -1, 1 } do
		local base = head.CFrame * CFrame.new(side * size.X * 0.28, size.Y * 0.45, size.Z * 0.12)
		local tip = branch(base * CFrame.Angles(-0.35, 0, side * -0.55), unit * 1.5, unit * 0.16)
		branch(base * CFrame.Angles(-0.35, 0, side * -0.55) * CFrame.new(0, unit * 0.7, 0) * CFrame.Angles(-0.7, 0, side * 0.5), unit * 0.6, unit * 0.12)
		local top = branch(tip * CFrame.Angles(0.5, 0, side * 0.35), unit * 0.9, unit * 0.12)
		branch(tip * CFrame.Angles(-0.6, 0, side * -0.3), unit * 0.7, unit * 0.1)
		branch(top * CFrame.Angles(0.2, 0, side * -0.6), unit * 0.45, unit * 0.08)
	end
end

-- LES ANIMAUX REPEINTS : le lion, l'ours et le cheval de MONDE sont des boss arc-en-ciel. Dans le zoo (« réaliste »,
-- sa demande du 14/10), on enlève leur image et on peint chaque pièce ; on leur remet des yeux.
local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end
local REPAINT = {
	Lion = { base = rgb(206, 160, 92), parts = { Head = rgb(160, 104, 54), Neck = rgb(160, 104, 54), TailTuft = rgb(104, 66, 38), Jaw = rgb(226, 196, 150) } },
	Bear = { base = rgb(104, 70, 44), parts = { Jaw = rgb(140, 104, 74) } },
	Horse = { base = rgb(136, 90, 56), parts = { Tail = rgb(58, 40, 28), TailTip = rgb(58, 40, 28) } },
}

local function weldTo(head: BasePart, item: BasePart)
	local weld = Instance.new("Weld")
	weld.Part0 = head
	weld.Part1 = item
	weld.C0 = head.CFrame:Inverse() * item.CFrame
	weld.Parent = item
end

local function repaint(model: Model, recipe)
	for _, part in model:GetDescendants() do
		if part:IsA("MeshPart") and part.Transparency < 1 then
			part.TextureID = ""
			for _, child in part:GetChildren() do
				if child:IsA("SurfaceAppearance") then
					child:Destroy()
				end
			end
			part.Color = recipe.parts[part.Name] or recipe.base
		end
	end
	-- Les yeux : deux billes noires sur l'avant de la tête (l'avant du modèle est vers -Z).
	local head = model:FindFirstChild("Head")
	local root = model:FindFirstChild("RigRoot")
	if head and head:IsA("BasePart") and root and root:IsA("BasePart") then
		local size = head.Size
		local front = root.CFrame.LookVector
		local right = root.CFrame.RightVector
		for _, side in { -1, 1 } do
			local eye = Instance.new("Part")
			eye.Name = "Eye"
			eye.Shape = Enum.PartType.Ball
			eye.Size = Vector3.one * math.max(size.X, size.Z) * 0.13
			eye.Color = rgb(20, 18, 16)
			eye.Material = Enum.Material.SmoothPlastic
			eye.Anchored, eye.CanCollide, eye.CanTouch, eye.CanQuery, eye.CastShadow = true, false, false, false, false
			eye.Position = head.Position + front * math.abs(size.Z) * 0.42 + right * side * math.abs(size.X) * 0.22 + Vector3.new(0, size.Y * 0.12, 0)
			eye.Parent = model
			weldTo(head, eye)
		end
	end
end

-- Le bas et le haut des pièces visibles d'un modèle (sans les pièces invisibles du squelette).
function AnimalModels.extents(model: Model): (number, number)
	local low, high = math.huge, -math.huge
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Transparency < 1 then
			local cf, size = part.CFrame, part.Size
			local half = (math.abs(cf.XVector.Y) * size.X + math.abs(cf.YVector.Y) * size.Y + math.abs(cf.ZVector.Y) * size.Z) / 2
			low = math.min(low, cf.Position.Y - half)
			high = math.max(high, cf.Position.Y + half)
		end
	end
	if low == math.huge then
		local box, size = model:GetBoundingBox()
		return box.Y - size.Y / 2, box.Y + size.Y / 2
	end
	return low, high
end

-- Le modèle d'un animal : son espèce, son sexe (« m » ou « f ») et sa croissance (0,5 = un petit, 1 = un adulte).
-- Renvoie nil si l'animal n'est pas importé dans le jeu.
function AnimalModels.build(species: string, sex: string, growth: number?): Model?
	local template = meshTemplate(species)
	if not template then
		return nil
	end
	local def = Config.SPECIES[species]
	local model = template:Clone()
	model.Name = species
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
			part.CastShadow = part.Name == "Core"
		end
	end
	-- (Les boss de MONDE ont un contour lumineux et des étincelles : pas dans le zoo.)
	for _, item in model:GetDescendants() do
		if item:IsA("Highlight") or item:IsA("SelectionBox") or item:IsA("Sparkles") or item:IsA("ParticleEmitter") or item:IsA("Light") then
			item:Destroy()
		end
	end
	if REPAINT[species] then
		repaint(model, REPAINT[species])
	end
	local hide = if sex == "f" then def and def.femaleHide else def and def.maleHide
	for _, name in hide or {} do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			part.Transparency = 1
		end
	end
	-- À sa taille : la hauteur de l'espèce (Config), un peu moins pour certaines femelles, la moitié pour un petit.
	local low, high = AnimalModels.extents(model)
	local wanted = (def and def.height or 3) * (if sex == "f" then def and def.femaleScale or 1 else 1)
	wanted *= 0.45 + 0.55 * math.clamp(growth or 1, 0, 1)
	model:ScaleTo(model:GetScale() * wanted / math.max(high - low, 0.05))
	model:SetAttribute("Height", wanted)
	-- (Les bois après la mise à la taille : ils ne comptent pas dans la hauteur du cerf.)
	if def and def.antlers and sex == "m" and (growth or 1) >= 0.99 then
		antlers(model)
	end
	return model
end

return AnimalModels

-- PLUGIN STUDIO « Ranger les épées » (jeu MONDE).
-- Après avoir importé les sept fichiers de roblox-monde/assets/swords-roblox/A-IMPORTER avec l'importeur de Studio,
-- un clic sur le bouton « Ranger les épées » :
--   1. retrouve chaque épée importée par son NOM (Sword_Iron, Sword_Steel, Sword_Gold, Sword_Frost, Sword_Flame,
--      Sword_Storm, Sword_Prismatic), où qu'elle soit dans le Workspace ;
--   2. la met à la bonne taille (5,2 studs de long) ;
--   3. lui ajoute sa prise (« Grip », au milieu de la poignée, lame vers l'avant) et les deux points de la traînée
--      (TrailBase au bas de la lame, TrailTip à la pointe) ;
--   4. la range dans ReplicatedStorage > SwordMeshes, sous son nom court (Iron, Steel...), dans l'ordre ;
--   5. sélectionne ce dossier : il reste à faire clic droit > « Enregistrer dans un fichier... » et à l'enregistrer
--      dans roblox-monde/assets/swords-roblox sous le nom SwordMeshes.rbxm.
-- Les épées importées restent dans le Workspace, intactes. On peut recliquer autant de fois qu'on veut.
-- (Fichier installé dans %LOCALAPPDATA%\Roblox\Plugins par Claude ; l'original est dans roblox-monde/tools/swords.)
-- Ajouts : Sword_Fusion et Sword_Void (18 950 triangles), prises calibrées et points de petites fumées.
-- Remplacement optionnel : Sword_GoldV2 devient Gold ; l'ancien Sword_Gold reste compatible.
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Selection = game:GetService("Selection")

local LENGTH = 5.2
local ORDER = { "Iron", "Steel", "Gold", "Frost", "Flame", "Storm", "Fusion", "Void", "Prismatic" }
-- En studs : grip = du pommeau au milieu de la poignée ; base et tip = de la poignée au bas de la lame (un peu après
-- la garde) et à la pointe.
-- (Chiffres de assets/swords-roblox/RAPPORT.json, calculés par tools/swords/optimise.py.)
local INFO = {
	Iron = { grip = 0.758, base = 1.008, tip = 4.442 },
	Steel = { grip = 0.802, base = 1.052, tip = 4.398 },
	Gold = { grip = 0.585, base = 0.835, tip = 4.615 },
	Frost = { grip = 0.888, base = 1.138, tip = 4.312 },
	Flame = { grip = 0.758, base = 1.008, tip = 4.442 },
	Storm = { grip = 0.932, base = 1.182, tip = 4.268 },
	Prismatic = { grip = 1.148, base = 1.398, tip = 4.052 },
	Fusion = { grip = 0.910, cross = {0.0016, 0.0014}, base = {0.0159, -0.0030, -0.988}, tip = {0.0007, 0.0898, -4.290} },
	Void = { grip = 0.819, cross = {-0.0013, 0.1861}, base = {0.0004, -0.0403, -1.079}, tip = {-0.0008, 0.2716, -4.381} },
}
-- Une version importée séparément n'utilise jamais la calibration de l'ancien
-- modèle. Sans cette nouvelle source, le rangement garde le comportement habituel.
local REPLACEMENTS = {
	Gold = {
		source = "GoldV2",
		info = { grip = 1.040, cross = {-0.0005, 0.0421},
			base = {-0.0413, 0.0814, -0.858}, tip = {-0.0023, 0.6570, -4.160} },
	},
}
-- Positions measured on the actual orange/cyan/violet texture regions. These
-- are canonical offsets from the middle of the handle, not from the mesh bbox.
local WISPS = {
	Fusion = {
		AuraHot1 = {-0.1683, -0.0578, -1.3831}, AuraHot2 = {0.1175, 0.0061, -2.1798},
		AuraHot3 = {-0.1388, -0.0559, -2.9653}, AuraHot4 = {0.1204, -0.0412, -3.7541},
		AuraCold1 = {-0.1001, 0.1435, -1.3899}, AuraCold2 = {0.1302, 0.2061, -2.1849},
		AuraCold3 = {-0.1725, 0.0721, -2.9732}, AuraCold4 = {0.0355, 0.2400, -3.7586},
	},
	Void = {
		AuraShadow1 = {-0.0267, -0.3406, -1.4708}, AuraShadow2 = {0.0271, -0.6722, -2.2619},
		AuraShadow3 = {-0.0801, -0.3582, -3.0554}, AuraShadow4 = {0.0859, -0.4163, -3.8515},
	},
}

local toolbar = plugin:CreateToolbar("MONDE")
local button = toolbar:CreateButton("Ranger les épées", "Range les épées importées dans ReplicatedStorage > SwordMeshes", "")
button.ClickableWhenViewportHidden = true

-- L'épée importée qui porte ce nom : un modèle, ou directement une pièce.
local function find(name: string): Instance?
	local found = nil
	for _, item in workspace:GetDescendants() do
		if item.Name == "Sword_" .. name and (item:IsA("Model") or item:IsA("MeshPart")) then
			-- (Le modèle plutôt que la pièce du même nom qu'il contient.)
			if not found or item:IsA("Model") and not item:IsDescendantOf(found) and not found:IsA("Model") then
				found = item
			end
			if found:IsA("MeshPart") and found.Parent and found.Parent:IsA("Model") and found.Parent.Name == found.Name then
				found = found.Parent
			end
		end
	end
	return found
end

local function chooseSource(name: string): (Instance?, any)
	local replacement = REPLACEMENTS[name]
	if replacement then
		local source = find(replacement.source)
		if source then return source, replacement.info end
	end
	return find(name), INFO[name]
end

local function arrange(name: string, source: Instance, info): Model
	local model = Instance.new("Model")
	model.Name = name
	local copy = source:Clone()
	local parts = {}
	if copy:IsA("BasePart") then
		table.insert(parts, copy)
	end
	for _, item in copy:GetDescendants() do
		if item:IsA("BasePart") then
			table.insert(parts, item)
		elseif item:IsA("LuaSourceContainer") then
			item:Destroy()
		end
	end
	assert(#parts > 0, "aucune pièce dans Sword_" .. name)
	table.sort(parts, function(a, b)
		return a.Size.Magnitude > b.Size.Magnitude
	end)
	local main = parts[1]
	for _, part in parts do
		part.Anchored = true
		part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
		part.Massless = true
		part.Parent = model
	end
	-- La bonne taille : la plus grande dimension de la pièce = la longueur de l'épée.
	local longest = math.max(main.Size.X, main.Size.Y, main.Size.Z)
	model:ScaleTo(LENGTH / longest)
	-- Le repère de l'épée : l'axe le plus long est la lame (la pointe est du côté négatif de cet axe, c'est ainsi que
	-- les fichiers sont faits), l'axe le plus court est l'épaisseur.
	local size, frame = main.Size, main.CFrame
	local axes = { { size.X, frame.XVector }, { size.Y, frame.YVector }, { size.Z, frame.ZVector } }
	table.sort(axes, function(a, b)
		return a[1] < b[1]
	end)
	local wide, tip = axes[2][2], axes[3][2]
	local pommel = main.Position - tip * (LENGTH / 2)
	local at = pommel + tip * info.grip
	if info.cross then
		-- In particular, the curved Void blade's bbox is sideways from its
		-- handle. Move the grip onto the real handle, not the bbox centerline.
		at += tip:Cross(wide) * info.cross[1] + wide * info.cross[2]
	end
	local grip = Instance.new("Part")
	grip.Name = "Grip"
	grip.Size = Vector3.new(0.2, 0.2, 0.2)
	grip.Transparency = 1
	grip.Anchored = true
	grip.CanCollide, grip.CanTouch, grip.CanQuery = false, false, false
	grip.Massless = true
	grip.CFrame = CFrame.lookAt(at, at + tip, wide)
	grip.Parent = model
	model.PrimaryPart = grip
	-- (Version du rangement : la premiere tenait l epee par la lame, la pointe est du cote positif de l axe.)
	model:SetAttribute("Calibre", 2)
	for key, distance in { TrailBase = info.base, TrailTip = info.tip } do
		local point = Instance.new("Attachment")
		point.Name = key
		point.Position = if type(distance) == "table" then Vector3.new(table.unpack(distance)) else Vector3.new(0, 0, -distance)
		point.Parent = grip
	end
	for key, position in WISPS[name] or {} do
		local point = Instance.new("Attachment")
		point.Name, point.Position, point.Parent = key, Vector3.new(table.unpack(position)), grip
	end
	return model
end

button.Click:Connect(function()
	-- (Le dossier déjà rangé est gardé : seules les épées retrouvées dans le Workspace sont remplacées.)
	local folder = ReplicatedStorage:FindFirstChild("SwordMeshes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "SwordMeshes"
	end
	local done, missing = {}, {}
	for index, name in ORDER do
		local source, info = chooseSource(name)
		if source then
			local ok, result = pcall(arrange, name, source, info)
			if ok then
				local old = folder:FindFirstChild(name)
				if old then
					old:Destroy()
				end
				-- Rangées côte à côte, dans l'ordre, pour qu'on les voie d'un coup d'œil.
				result:PivotTo(CFrame.new(index * 3, 6, 0) * CFrame.Angles(math.rad(90), 0, 0))
				result.Parent = folder
				table.insert(done, name)
			else
				warn("[MONDE] Sword_" .. name .. " : " .. tostring(result))
				table.insert(missing, name)
			end
		elseif not folder:FindFirstChild(name) then
			table.insert(missing, name)
		end
	end
	-- LES STANDS (importés de A-IMPORTER) : « Stand_Epees » est rangé sous le nom « Stand », « Stand_Vente » (en
	-- plusieurs morceaux) sous le nom « StandVente », dans le même dossier. Le jeu les pose lui-même à leur place.
	for imported, name in { Stand_Epees = "Stand", Stand_Vente = "StandVente" } do
		local parts = {}
		for _, item in workspace:GetDescendants() do
			if item:IsA("BasePart") then
				local inside = item:FindFirstAncestor(imported) ~= nil
				if inside or string.sub(item.Name, 1, #imported) == imported then
					table.insert(parts, item)
				end
			end
		end
		if #parts > 0 then
			local model = Instance.new("Model")
			model.Name = name
			for _, part in parts do
				local copy = part:Clone()
				copy.Name = name .. "Piece"
				copy.Anchored = true
				copy.Parent = model
			end
			local old = folder:FindFirstChild(name)
			if old then
				old:Destroy()
			end
			model.Parent = folder
			table.insert(done, name)
		end
	end
	folder.Parent = ReplicatedStorage
	Selection:Set({ folder })
	ChangeHistoryService:SetWaypoint("Ranger les épées")
	print("[MONDE] Épées rangées dans ReplicatedStorage > SwordMeshes : " .. table.concat(done, ", "))
	if #missing > 0 then
		warn("[MONDE] Pas trouvées dans le Workspace (à importer d'abord) : Sword_" .. table.concat(missing, ", Sword_"))
	end
	print("[MONDE] Dernière étape : clic droit sur SwordMeshes > Enregistrer dans un fichier... > roblox-monde/assets/swords-roblox/SwordMeshes.rbxm")
end)

-- PLUGIN STUDIO « Enregistrer les animaux » (jeu MONDE).
-- À copier dans %LOCALAPPDATA%\Roblox\Plugins. Après avoir importé un ou plusieurs animaux en maillage avec
-- Import 3D (les FBX de roblox-monde/assets/collections/monde-*-maillages), un clic sur le bouton :
--   1. ramasse tout ce qui a été importé dans le Workspace (les groupes de MeshPart) dans un seul dossier
--      « MeshImports » ;
--   2. ouvre la fenêtre « Enregistrer » sur ce dossier : il reste à choisir
--      roblox-monde/assets/collections/imports et à valider.
-- Le jeu assemble ensuite lui-même chaque animal avec son squelette (src/shared/PetModels.luau).
local Selection = game:GetService("Selection")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local toolbar = plugin:CreateToolbar("MONDE animaux")
local button = toolbar:CreateButton("Enregistrer les animaux", "Ramasse les animaux importés et ouvre la fenêtre d'enregistrement", "")
button.ClickableWhenViewportHidden = true

button.Click:Connect(function()
	local old = workspace:FindFirstChild("MeshImports")
	local folder = Instance.new("Folder")
	folder.Name = "MeshImports"
	-- Un groupe importé = le parent direct de plusieurs MeshPart (hors de l'ancien dossier, repris tel quel).
	local groups, order = {}, {}
	for _, item in workspace:GetDescendants() do
		if item:IsA("MeshPart") and item.Parent and item.Parent ~= workspace and not groups[item.Parent] then
			groups[item.Parent] = true
			table.insert(order, item.Parent)
		end
	end
	local count = 0
	for _, group in order do
		local meshes = 0
		for _, child in group:GetChildren() do
			if child:IsA("MeshPart") then
				meshes += 1
			end
		end
		if meshes >= 5 then
			local copy = Instance.new("Model")
			copy.Name = "Animal" .. (count + 1) .. "_" .. group.Name
			for _, child in group:GetChildren() do
				if child:IsA("MeshPart") then
					local mesh = child:Clone()
					mesh.Anchored = true
					mesh.Parent = copy
				end
			end
			copy.Parent = folder
			count += 1
		end
	end
	if count == 0 then
		folder:Destroy()
		warn("[MONDE] Aucun animal importé trouvé dans le Workspace : faire d'abord Import 3D des fichiers .fbx.")
		return
	end
	if old then
		old:Destroy()
	end
	folder.Parent = workspace
	Selection:Set({ folder })
	ChangeHistoryService:SetWaypoint("Enregistrer les animaux")
	print("[MONDE] " .. count .. " animal(aux) ramassé(s). Enregistrer dans : roblox-monde/assets/collections/imports/Animaux.rbxm")
	plugin:PromptSaveSelection("Animaux")
end)

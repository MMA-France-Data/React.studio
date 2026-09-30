-- Plugin Studio « Rangeur de monstres » (projet Ranked Tower Defense).
-- Range les modèles 3D importés dans ReplicatedStorage > EnemyModels avec le bon nom (<Type>_<tranche>),
-- sans passer par « Enregistrer dans un fichier » pour chacun :
--   1. Fichier > Importer : importer un ou plusieurs .glb / .fbx (ils arrivent dans le Workspace) ;
--   2. dans le panneau « Ranger un monstre » (bouton « Monstres » de l'onglet Plugins) : choisir la tranche
--      de vagues, sélectionner un modèle importé (dans l'Explorer ou la vue 3D), cliquer sur son type ;
--   3. à la fin, Fichier > Enregistrer (Ctrl+S) : tools/studio-helper/recuperer-monstres.ps1 sort ensuite
--      chaque modèle de EnemyModels en fichier .rbxm dans assets/EnemyModels (Rojo syncback).
-- Installé par tools/studio-helper/install.ps1 (copie dans le dossier des plugins de Studio).
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Selection = game:GetService("Selection")

local TYPES = {
	{ key = "Swarm", label = "Écuyer" },
	{ key = "Normal", label = "Fantassin" },
	{ key = "Fast", label = "Cavalier" },
	{ key = "Tank", label = "Chevalier lourd" },
	{ key = "Giant", label = "Colosse" },
	{ key = "Boss", label = "Boss" },
}
local TRANCHES = 10 -- 0 = vagues 1-10 ... 9 = vagues 91-100

local toolbar = plugin:CreateToolbar("Ranked TD")
local toggle = toolbar:CreateButton("Monstres", "Ranger un monstre importé dans EnemyModels", "")
toggle.ClickableWhenViewportHidden = true

local info = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, false, false, 340, 470, 300, 380)
local widget = plugin:CreateDockWidgetPluginGui("RangeurMonstres", info)
widget.Title = "Ranger un monstre"
toggle.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)
widget:GetPropertyChangedSignal("Enabled"):Connect(function()
	toggle:SetActive(widget.Enabled)
end)

local BACKGROUND = Color3.fromRGB(34, 30, 26)
local BUTTON = Color3.fromRGB(70, 56, 40)
local SELECTED = Color3.fromRGB(196, 150, 60)
local TEXT = Color3.fromRGB(240, 230, 205)
local GOOD = Color3.fromRGB(120, 210, 120)
local BAD = Color3.fromRGB(235, 110, 100)

local root = Instance.new("ScrollingFrame")
root.Size = UDim2.fromScale(1, 1)
root.CanvasSize = UDim2.new()
root.AutomaticCanvasSize = Enum.AutomaticSize.Y
root.ScrollBarThickness = 6
root.BackgroundColor3 = BACKGROUND
root.BorderSizePixel = 0
root.Parent = widget
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = root
local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 8)
padding.PaddingLeft = UDim.new(0, 8)
padding.PaddingRight = UDim.new(0, 8)
padding.PaddingBottom = UDim.new(0, 8)
padding.Parent = root

local order = 0
local function label(text: string, height: number, color: Color3?): TextLabel
	order += 1
	local item = Instance.new("TextLabel")
	item.LayoutOrder = order
	item.Size = UDim2.new(1, 0, 0, height)
	item.BackgroundTransparency = 1
	item.Font = Enum.Font.GothamMedium
	item.TextSize = 14
	item.TextWrapped = true
	item.TextXAlignment = Enum.TextXAlignment.Left
	item.TextYAlignment = Enum.TextYAlignment.Top
	item.TextColor3 = color or TEXT
	item.Text = text
	item.Parent = root
	return item
end
local function grid(cellWidth: number, cellHeight: number, rows: number): Frame
	order += 1
	local frame = Instance.new("Frame")
	frame.LayoutOrder = order
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, 0, 0, rows * (cellHeight + 4))
	frame.Parent = root
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.fromOffset(cellWidth, cellHeight)
	gridLayout.CellPadding = UDim2.fromOffset(4, 4)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = frame
	return frame
end
local function button(parent: Instance, text: string, layoutOrder: number): TextButton
	local item = Instance.new("TextButton")
	item.LayoutOrder = layoutOrder
	item.BackgroundColor3 = BUTTON
	item.BorderSizePixel = 0
	item.Font = Enum.Font.GothamBold
	item.TextSize = 14
	item.TextColor3 = TEXT
	item.Text = text
	item.AutoButtonColor = true
	item.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = item
	return item
end

label("1. Tranche de vagues du monstre :", 20)
local trancheFrame = grid(60, 28, 2)
local tranche = 0
local trancheButtons = {}
local function refreshTranches()
	for index, trancheButton in trancheButtons do
		trancheButton.BackgroundColor3 = if index - 1 == tranche then SELECTED else BUTTON
	end
end
for index = 1, TRANCHES do
	local first = (index - 1) * 10 + 1
	local trancheButton = button(trancheFrame, `{first}-{first + 9}`, index)
	trancheButtons[index] = trancheButton
	trancheButton.Activated:Connect(function()
		tranche = index - 1
		refreshTranches()
	end)
end
refreshTranches()

order += 1
local autoButton = button(root, "Tout ranger automatiquement", order)
autoButton.Size = UDim2.new(1, 0, 0, 36)
autoButton.BackgroundColor3 = Color3.fromRGB(60, 110, 60)
label("Range d'un coup tous les monstres importés du Workspace dont le type est reconnu (noms « Swarm_Mesh », « Fast_... », cheval...). Sinon, à la main :", 50)
label("2. Sélectionne UN monstre importé (Explorer ou vue 3D), puis clique sur son type :", 36)
local typeFrame = grid(150, 34, 3)
local status = label("", 56)
label("3. Quand tout est rangé : Fichier > Enregistrer (Ctrl+S), puis dis à Claude « c'est enregistré ».", 36, SELECTED)
label("Déjà rangés dans ReplicatedStorage > EnemyModels :", 20)
local listLabel = label("", 120)

local function modelsFolder(): Folder
	local folder = ReplicatedStorage:FindFirstChild("EnemyModels")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "EnemyModels"
		folder.Parent = ReplicatedStorage
	end
	return folder :: Folder
end

local function refreshList()
	local names = {}
	for _, child in modelsFolder():GetChildren() do
		if child:IsA("Model") or child:IsA("BasePart") then
			table.insert(names, child.Name)
		end
	end
	table.sort(names)
	listLabel.Text = if #names > 0 then table.concat(names, ", ") else "(aucun)"
end

-- Le modèle importé qui contient la sélection : on remonte jusqu'à l'enfant direct du Workspace.
local function selectedModel(): Model?
	local selected = Selection:Get()
	if #selected ~= 1 then
		return nil
	end
	local item: Instance? = selected[1]
	while item and item.Parent and item.Parent ~= workspace do
		item = item.Parent
	end
	if item and item.Parent == workspace and item:IsA("Model") then
		return item
	end
	return nil
end

local LABELS = {}
for _, typeInfo in TYPES do
	LABELS[typeInfo.key] = typeInfo.label
end

-- Type d'un modèle importé, d'après les noms qu'il contient : ses os et pièces gardent les noms du fichier
-- 3D (« Swarm_Mesh », « Normal_Mesh »... dans InitialPoses, « Horse » pour le cheval, « Fast_1_Gallop_Studio »
-- pour un FBX). nil si rien n'est reconnu (à ranger à la main).
local PATTERNS = {
	{ "swarm", "Swarm" },
	{ "normal", "Normal" },
	{ "tank", "Tank" },
	{ "giant", "Giant" },
	{ "fast", "Fast" },
	{ "horse", "Fast" },
	{ "cavalry", "Fast" },
	{ "boss", "Boss" },
}
local function detectType(model: Instance): string?
	local found: { [string]: boolean } = {}
	local names = { string.lower(model.Name) }
	for _, descendant in model:GetDescendants() do
		table.insert(names, string.lower(descendant.Name))
	end
	for _, name in names do
		for _, pattern in PATTERNS do
			if string.find(name, pattern[1], 1, true) then
				found[pattern[2]] = true
			end
		end
	end
	local result, count = nil, 0
	for key in found do
		result = key
		count += 1
	end
	return if count == 1 then result else nil -- plusieurs types trouvés : trop incertain
end

-- Range un modèle sous le nom <type>_<tranche> dans EnemyModels (remplace l'ancien du même nom).
local function store(model: Model, key: string): (string, boolean)
	local name = `{key}_{tranche}`
	local folder = modelsFolder()
	local old = folder:FindFirstChild(name)
	if old then
		old.Parent = nil -- remplacé (Ctrl+Z le remet)
	end
	model.Name = name
	model.Parent = folder
	return name, old ~= nil
end

for index, typeInfo in TYPES do
	local typeButton = button(typeFrame, typeInfo.label, index)
	typeButton.Activated:Connect(function()
		local model = selectedModel()
		if not model then
			status.TextColor3 = BAD
			status.Text = "Sélectionne d'abord UN seul monstre importé (un modèle posé dans le Workspace)."
			return
		end
		local recording = ChangeHistoryService:TryBeginRecording("Ranger " .. typeInfo.key)
		local name, replaced = store(model, typeInfo.key)
		Selection:Set({})
		if recording then
			ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
		end
		local first = tranche * 10 + 1
		status.TextColor3 = GOOD
		status.Text = `✓ {typeInfo.label} des vagues {first}-{first + 9} rangé : {name}{if replaced then " (ancien remplacé)" else ""}`
		refreshList()
	end)
end

autoButton.Activated:Connect(function()
	local recording = ChangeHistoryService:TryBeginRecording("Ranger tous les monstres")
	local done, unknown = {}, {}
	local seen: { [string]: boolean } = {}
	for _, child in workspace:GetChildren() do
		if not child:IsA("Model") or child:FindFirstChildWhichIsA("Humanoid") or child.Name == "Camera" then
			continue -- (le personnage du joueur n'est là qu'en Play)
		end
		local hasMesh = child:FindFirstChildWhichIsA("MeshPart", true) ~= nil
		if not hasMesh then
			continue
		end
		local key = detectType(child)
		if key and not seen[key] then
			seen[key] = true
			local name = store(child, key)
			table.insert(done, `{LABELS[key]} ({name})`)
		else
			table.insert(unknown, child.Name)
		end
	end
	if recording then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end
	local first = tranche * 10 + 1
	if #done == 0 and #unknown == 0 then
		status.TextColor3 = BAD
		status.Text = "Aucun monstre importé dans le Workspace."
	else
		status.TextColor3 = if #unknown == 0 then GOOD else BAD
		status.Text = `Vagues {first}-{first + 9} : {if #done > 0 then "✓ " .. table.concat(done, ", ") else "rien de rangé"}`
			.. (if #unknown > 0 then ` ; pas reconnus (à ranger à la main) : {table.concat(unknown, ", ")}` else "")
	end
	refreshList()
end)

-- Monstre sélectionné : son type reconnu, pour aider à choisir le bon bouton.
Selection.SelectionChanged:Connect(function()
	local model = selectedModel()
	if model and model.Parent == workspace then
		local key = detectType(model)
		status.TextColor3 = TEXT
		status.Text = if key then `Sélection : « {model.Name} », reconnu comme {LABELS[key]}.` else `Sélection : « {model.Name} », type pas reconnu.`
	end
end)

refreshList()
widget:GetPropertyChangedSignal("Enabled"):Connect(refreshList)

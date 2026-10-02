-- Affichage du panneau physique créé dans HubMap. Lecture seule des attributs existants (le DPS total : attribut
-- TotalDps de la parcelle, calculé par PlotGame:totalDps). Aucun accès aux sauvegardes et aucune modification de la
-- simulation ou du HUD.
-- Parcelle devenue CAMP D'ENTRAÎNEMENT (nouvelle formule, Hub/Camp.luau : attribut Camp de la parcelle) : le même
-- panneau affiche le camp (niveaux réussis, tours débloquées, pièces de niveau, tours à l'entraînement).
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local IdleTowers = require(Shared.IdleTowers)
local Levels = require(Shared.Levels)
local NumberFormat = require(Shared.NumberFormat)

local PlotBoard = {}
local IVORY = Color3.fromRGB(238, 226, 197)
local GOLD = Color3.fromRGB(231, 184, 91)
local MUTED = Color3.fromRGB(159, 183, 176)

local function text(parent, name, value, x, y, width, height, size, color)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(x, y)
	label.Size = UDim2.fromOffset(width, height)
	label.Font = Enum.Font.GothamBold
	label.Text = value
	label.TextColor3 = color or IVORY
	label.TextSize = size
	label.TextScaled = true
	label.TextWrapped = false
	label.RichText = false
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = size
	limit.MinTextSize = 14
	limit.Parent = label
	label.Parent = parent
	return label
end

function PlotBoard.attach(plot: Folder, board: BasePart)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "FiefDisplay"
	gui.Face = Enum.NormalId.Front -- vers le château, le long de l'axe -Z de la parcelle
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(1200, 640)
	gui.LightInfluence = 0
	gui.Brightness = 1
	gui.AlwaysOnTop = false
	gui.MaxDistance = 185
	gui.Parent = board
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = Color3.fromRGB(20, 40, 41)
	panel.BorderSizePixel = 0
	panel.Parent = gui
	local heading = text(panel, "Heading", "CHRONIQUES DU FIEF", 40, 22, 1120, 54, 44, GOLD)
	local ownerLabel = text(panel, "Owner", "Parcelle libre", 40, 81, 1120, 42, 31, MUTED)
	local values, titles = {}, {}
	local CARD_TITLES = { Wave = "VAGUE ACTUELLE", Record = "RECORD DE VAGUE", DPS = "DPS TOTAL" }
	for i, info in {
		{ key = "Wave", title = "VAGUE ACTUELLE" },
		{ key = "Record", title = "RECORD DE VAGUE" },
		{ key = "DPS", title = "DPS TOTAL" },
	} do
		local card = Instance.new("Frame")
		card.Name = info.key .. "Card"
		card.Position = UDim2.fromOffset(38 + (i - 1) * 378, 156)
		card.Size = UDim2.fromOffset(368, 205)
		card.BackgroundColor3 = Color3.fromRGB(29, 54, 53)
		card.BorderSizePixel = 0
		card.Parent = panel
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = card
		titles[info.key] = text(card, "Title", info.title, 12, 17, 344, 38, 26, MUTED)
		values[info.key] = text(card, "Value", "—", 12, 65, 344, 118, 92, if i == 2 then GOLD else IVORY)
	end
	local stateLabel = text(panel, "BattleState", "En attente d'un propriétaire", 40, 389, 1120, 42, 30, IVORY)
	local detailLabel = text(panel, "Details", "", 40, 446, 1120, 42, 27, MUTED)
	local notes = {
		text(panel, "DPSNote", "DPS théorique · niveaux, doublons, bonus et cadence inclus", 35, 525, 1130, 34, 23, MUTED),
		text(panel, "AreaNote", "Hors cibles supplémentaires touchées par les attaques de zone", 35, 562, 1130, 30, 21, MUTED),
	}
	local NOTE_TEXTS = { notes[1].Text, notes[2].Text }

	local alive, queued = true, false
	local connections, ownerConnections, towerFolderConnections = {}, {}, {}
	local towerConnections = {}
	local owner: Player? = nil
	local towers: Instance? = nil
	local function disconnect(list)
		for _, connection in list do connection:Disconnect() end
		table.clear(list)
	end
	local function refresh()
		local camp = plot:GetAttribute("Camp") == true and owner ~= nil and owner.Parent == Players
		heading.Text = if camp then "CAMP D'ENTRAÎNEMENT" else "CHRONIQUES DU FIEF"
		titles.Wave.Text = if camp then "NIVEAUX RÉUSSIS" else CARD_TITLES.Wave
		titles.Record.Text = if camp then "TOURS DÉBLOQUÉES" else CARD_TITLES.Record
		titles.DPS.Text = if camp then "PIÈCES DE NIVEAU" else CARD_TITLES.DPS
		notes[1].Text = if camp then "Les tours posées ici s'entraînent tout le temps, même quand leur seigneur est parti" else NOTE_TEXTS[1]
		notes[2].Text = if camp then "L'entraînement les fait évoluer : ★ ★★ ★★★" else NOTE_TEXTS[2]
		if camp then
			local training = 0
			if towers then
				for _, model in towers:GetChildren() do
					if model:IsA("Model") and model:GetAttribute("CampSlot") then
						training += 1
					end
				end
			end
			ownerLabel.Text = "Camp de " .. (owner :: Player).DisplayName
			values.Wave.Text = `{plot:GetAttribute("CampBest") or 0} / {Levels.COUNT}`
			values.Record.Text = `{plot:GetAttribute("CampTowers") or 0} / {#IdleTowers.ORDER}`
			values.DPS.Text = NumberFormat.short(plot:GetAttribute("CampCoins") or 0)
			stateLabel.Text = if training > 0 then `ENTRAÎNEMENT EN COURS · {training} {if training > 1 then "tours" else "tour"}` else "AUCUNE TOUR À L'ENTRAÎNEMENT"
			detailLabel.Text = tostring(plot:GetAttribute("CampTraining") or "")
			return
		end
		if not owner or owner.Parent ~= Players then
			ownerLabel.Text = "Parcelle libre"
			for _, label in values do label.Text = "—" end
			stateLabel.Text = "En attente d'un propriétaire"
			detailLabel.Text = "Installe tes défenses pour écrire ton histoire"
			return
		end
		local count = 0
		if towers then
			for _, model in towers:GetChildren() do
				local kind = model:GetAttribute("TowerType")
				if model:IsA("Model") and kind and IdleTowers.Defs[kind] then
					count += 1
				end
			end
		end
		local speed = plot:GetAttribute("SimSpeed") or 1
		ownerLabel.Text = "Fief de " .. owner.DisplayName
		values.Wave.Text = NumberFormat.short(plot:GetAttribute("Wave") or 1)
		values.Record.Text = NumberFormat.short(plot:GetAttribute("HighestWave") or 1)
		-- DPS total calculé par le serveur (PlotGame:totalDps : niveaux, doublons et runes compris, SANS la vitesse x2), publié
		-- dans l'attribut TotalDps : exactement le nombre de la colonne « DPS » de la liste des joueurs.
		values.DPS.Text = NumberFormat.short(plot:GetAttribute("TotalDps") or 0)
		local enemies = math.max(0, plot:GetAttribute("EnemiesLeft") or 0)
		stateLabel.Text = if plot:GetAttribute("State") == "Running" then `DÉFENSE EN COURS · {enemies} ennemis restants` else "RÉPIT · Prépare tes défenses"
		detailLabel.Text = `{count} tours  ·  {NumberFormat.short(plot:GetAttribute("Rebirths") or 0)} renaissances  ·  +{NumberFormat.short(plot:GetAttribute("CoinBonus") or 0)} % pièces  ·  Vitesse x{speed}`
	end
	local function schedule()
		if queued or not alive then return end
		queued = true
		task.defer(function()
			queued = false
			if alive then refresh() end
		end)
	end
	local function bindOwner()
		disconnect(ownerConnections)
		local userId = plot:GetAttribute("OwnerUserId")
		owner = if typeof(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
		if owner then
			table.insert(ownerConnections, owner:GetAttributeChangedSignal("TowerDupes"):Connect(schedule))
			table.insert(ownerConnections, owner:GetPropertyChangedSignal("DisplayName"):Connect(schedule))
		end
		schedule()
	end
	local function unwatchTower(model)
		if towerConnections[model] then disconnect(towerConnections[model]); towerConnections[model] = nil end
		schedule()
	end
	local function watchTower(model)
		if not model:IsA("Model") or towerConnections[model] then return end
		local list = {}
		towerConnections[model] = list
		for _, name in { "TowerType", "Level", "Bonus" } do
			table.insert(list, model:GetAttributeChangedSignal(name):Connect(schedule))
		end
		schedule()
	end
	local function bindTowers()
		disconnect(towerFolderConnections)
		for model, list in towerConnections do disconnect(list); towerConnections[model] = nil end
		towers = plot:FindFirstChild("Towers")
		if towers then
			for _, model in towers:GetChildren() do watchTower(model) end
			table.insert(towerFolderConnections, towers.ChildAdded:Connect(watchTower))
			table.insert(towerFolderConnections, towers.ChildRemoved:Connect(unwatchTower))
		end
		schedule()
	end
	for _, name in { "Wave", "HighestWave", "State", "EnemiesLeft", "Rebirths", "CoinBonus", "SimSpeed", "TotalDps", "Camp", "CampBest", "CampCoins", "CampTowers", "CampTraining" } do
		table.insert(connections, plot:GetAttributeChangedSignal(name):Connect(schedule))
	end
	table.insert(connections, plot:GetAttributeChangedSignal("OwnerUserId"):Connect(bindOwner))
	table.insert(connections, Players.PlayerAdded:Connect(function(player)
		if plot:GetAttribute("OwnerUserId") == player.UserId then bindOwner() end
	end))
	table.insert(connections, Players.PlayerRemoving:Connect(function(player)
		if player == owner then disconnect(ownerConnections); owner = nil; schedule() end
	end))
	for _, event in { plot.ChildAdded, plot.ChildRemoved } do
		table.insert(connections, event:Connect(function(child) if child.Name == "Towers" then bindTowers() end end))
	end
	table.insert(connections, board.Destroying:Connect(function()
		alive = false
		disconnect(connections)
		disconnect(ownerConnections)
		disconnect(towerFolderConnections)
		for _, list in towerConnections do disconnect(list) end
		table.clear(towerConnections)
	end))
	bindOwner()
	bindTowers()
end

return PlotBoard

-- Affichage du grand panneau au fond de chaque parcelle (créé dans HubMap) : le CAMP D'ENTRAÎNEMENT de son joueur
-- (niveaux réussis, tours débloquées, pièces de niveau, tours à l'entraînement). Lecture seule des attributs de la
-- parcelle (Camp, CampBest, CampTowers, CampCoins, CampTraining : Hub/Camp.luau). Aucun accès aux sauvegardes.
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
	text(panel, "Heading", "CAMP D'ENTRAÎNEMENT", 40, 22, 1120, 54, 44, GOLD)
	local ownerLabel = text(panel, "Owner", "Parcelle libre", 40, 81, 1120, 42, 31, MUTED)
	local values = {}
	for i, info in {
		{ key = "Wave", title = "NIVEAUX RÉUSSIS" },
		{ key = "Record", title = "TOURS DÉBLOQUÉES" },
		{ key = "DPS", title = "PIÈCES DE NIVEAU" },
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
		text(card, "Title", info.title, 12, 17, 344, 38, 26, MUTED)
		values[info.key] = text(card, "Value", "—", 12, 65, 344, 118, 92, if i == 2 then GOLD else IVORY)
	end
	local stateLabel = text(panel, "BattleState", "En attente d'un propriétaire", 40, 389, 1120, 42, 30, IVORY)
	local detailLabel = text(panel, "Details", "", 40, 446, 1120, 42, 27, MUTED)
	text(panel, "DPSNote", "Les tours posées ici s'entraînent tout le temps, même quand leur seigneur est parti", 35, 525, 1130, 34, 23, MUTED)
	text(panel, "AreaNote", "L'entraînement les fait évoluer : ★ ★★ ★★★", 35, 562, 1130, 30, 21, MUTED)

	local alive, queued = true, false
	local connections, ownerConnections, towerFolderConnections = {}, {}, {}
	local owner: Player? = nil
	local towers: Instance? = nil
	local function disconnect(list)
		for _, connection in list do connection:Disconnect() end
		table.clear(list)
	end
	local function refresh()
		if plot:GetAttribute("Camp") ~= true or not owner or owner.Parent ~= Players then
			ownerLabel.Text = "Parcelle libre"
			for _, label in values do label.Text = "—" end
			stateLabel.Text = "En attente d'un propriétaire"
			detailLabel.Text = "Un camp prêt à accueillir son seigneur"
			return
		end
		local training = 0
		if towers then
			for _, model in towers:GetChildren() do
				if model:IsA("Model") and model:GetAttribute("CampSlot") then
					training += 1
				end
			end
		end
		ownerLabel.Text = "Camp de " .. owner.DisplayName
		values.Wave.Text = `{plot:GetAttribute("CampBest") or 0} / {Levels.COUNT}`
		values.Record.Text = `{plot:GetAttribute("CampTowers") or 0} / {#IdleTowers.ORDER}`
		values.DPS.Text = NumberFormat.short(plot:GetAttribute("CampCoins") or 0)
		stateLabel.Text = if training > 0 then `ENTRAÎNEMENT EN COURS · {training} {if training > 1 then "tours" else "tour"}` else "AUCUNE TOUR À L'ENTRAÎNEMENT"
		detailLabel.Text = tostring(plot:GetAttribute("CampTraining") or "")
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
			table.insert(ownerConnections, owner:GetPropertyChangedSignal("DisplayName"):Connect(schedule))
		end
		schedule()
	end
	local function bindTowers()
		disconnect(towerFolderConnections)
		towers = plot:FindFirstChild("Towers")
		if towers then
			table.insert(towerFolderConnections, towers.ChildAdded:Connect(schedule))
			table.insert(towerFolderConnections, towers.ChildRemoved:Connect(schedule))
		end
		schedule()
	end
	for _, name in { "Camp", "CampBest", "CampCoins", "CampTowers", "CampTraining" } do
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
	end))
	bindOwner()
	bindTowers()
end

return PlotBoard

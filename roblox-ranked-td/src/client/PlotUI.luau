-- Interface de ta parcelle : pièces, vague en cours, et panneau des emplacements / tours.
-- Clique sur un emplacement libre pour poser une tour, sur une tour pour la remplacer ou la
-- vendre (50 % remboursés), sur n'importe quel cadenas pour débloquer CET emplacement (le prix
-- ne dépend que du nombre d'emplacements déjà possédés, il monte après chaque achat).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local IdleConfig = require(Shared.IdleConfig)
local IdleTowers = require(Shared.IdleTowers)
local NumberFormat = require(Shared.NumberFormat)
local PlotLayout = require(Shared.PlotLayout)
local Remotes = require(Shared.Remotes)
local UI = require(script.Parent.UI)

local PlotUI = {}

local KIND_LABELS = {
	Single = "Cible unique",
	Splash = "Zone",
	Aura = "Zone autour",
	Chain = "Chaîne (4 cibles)",
}

local function listAttribute(player: Player, name: string): { string }
	local raw = player:GetAttribute(name)
	if typeof(raw) ~= "string" or raw == "" then
		return {}
	end
	return string.split(raw, ",")
end

local function dupesOf(player: Player, towerType: string): number
	for _, entry in listAttribute(player, "TowerDupes") do
		local name, count = string.match(entry, "^(%w+):(%d+)$")
		if name == towerType then
			return tonumber(count) or 0
		end
	end
	return 0
end

local CARD_WIDTH = 100
local PANEL_HEIGHT = 272

local function kindLabel(def): string
	if def.kind == "Single" and def.slow then
		return "Ralentit 1 cible"
	end
	return KIND_LABELS[def.kind] or ""
end

function PlotUI.start()
	local player = Players.LocalPlayer
	local plotAction = Remotes.get("PlotAction")
	local plotsFolder = workspace:WaitForChild("Hub"):WaitForChild("Plots")
	local gui = UI.screen("Plot")

	local function myPlotIndex(): number?
		return player:GetAttribute("Plot")
	end
	local function myPlotFolder(): Instance?
		local index = myPlotIndex()
		return index and plotsFolder:FindFirstChild("Plot" .. index)
	end
	local function coins(): number
		return player:GetAttribute("Coins") or 0
	end
	-- Emplacements possédés : attribut "OwnedSpots" de la parcelle (ex. "1,2,3,4,9"), publié par le
	-- serveur (PlotGame:refreshSpots). Renvoie { [spotIndex] = true } et leur nombre.
	local function ownedSpots(): ({ [number]: boolean }, number)
		local plot = myPlotFolder()
		local raw = plot and plot:GetAttribute("OwnedSpots")
		local owned, count = {}, 0
		if typeof(raw) ~= "string" or raw == "" then
			for spotIndex = 1, PlotLayout.STARTING_SPOTS do
				owned[spotIndex] = true
			end
			return owned, PlotLayout.STARTING_SPOTS
		end
		for _, text in string.split(raw, ",") do
			local spotIndex = tonumber(text)
			if spotIndex and not owned[spotIndex] then
				owned[spotIndex] = true
				count += 1
			end
		end
		return owned, count
	end

	------------------------------------------------------------------
	-- HUD : pièces + vague
	------------------------------------------------------------------
	local coinsLabel = UI.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.new(0, 360, 0, 46),
		Font = Enum.Font.GothamBlack,
		TextColor3 = UI.Colors.Gold,
		TextStrokeTransparency = 0.3,
		MaxTextSize = 42,
		Parent = gui,
	})

	local wavePanel = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 58),
		Size = UDim2.new(0, 340, 0, 78),
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.15,
		Parent = gui,
	}, { UI.corner(12), UI.padding(8) })
	local waveLabel = UI.label({
		Size = UDim2.new(1, 0, 0, 22),
		Font = Enum.Font.GothamBlack,
		MaxTextSize = 20,
		Parent = wavePanel,
	})
	local hintLabel = UI.label({
		Position = UDim2.new(0, 0, 0, 22),
		Size = UDim2.new(1, 0, 0, 14),
		TextColor3 = UI.Colors.Muted,
		MaxTextSize = 13,
		Parent = wavePanel,
	})
	local _, setBaseHealth = UI.bar({
		Position = UDim2.new(0, 0, 0, 40),
		Size = UDim2.new(1, 0, 0, 10),
		Parent = wavePanel,
	}, UI.Colors.Success)
	local waveInfo = UI.label({
		Position = UDim2.new(0, 0, 0, 52),
		Size = UDim2.new(1, 0, 0, 14),
		TextColor3 = UI.Colors.Muted,
		MaxTextSize = 13,
		Parent = wavePanel,
	})

	------------------------------------------------------------------
	-- Panneau emplacement / tour (en bas au centre)
	------------------------------------------------------------------
	local count = #IdleTowers.ORDER
	local panel = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(count * (CARD_WIDTH + 8) + 12, PANEL_HEIGHT),
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.05,
		Visible = false,
		Parent = gui,
	}, { UI.corner(14), UI.padding(10), UI.stroke() })
	-- Réduit le panneau sur les petits écrans (téléphones).
	local panelScale = UI.new("UIScale", { Parent = panel })
	local function fitPanel()
		local viewport = workspace.CurrentCamera.ViewportSize
		panelScale.Scale = math.min(1, (viewport.X - 24) / panel.Size.X.Offset, (viewport.Y * 0.55) / PANEL_HEIGHT)
	end
	fitPanel()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitPanel)
	local panelTitle = UI.label({
		Size = UDim2.new(1, -40, 0, 26),
		Font = Enum.Font.GothamBlack,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 22,
		Parent = panel,
	})
	local panelSubtitle = UI.label({
		Position = UDim2.new(0, 0, 0, 28),
		Size = UDim2.new(1, 0, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.Muted,
		MaxTextSize = 15,
		Parent = panel,
	})
	local closeButton = UI.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = UI.Colors.PanelLight,
		Text = "X",
		MaxTextSize = 18,
		Parent = panel,
	})

	local cardRow = UI.new("Frame", {
		Position = UDim2.new(0, 0, 0, 52),
		Size = UDim2.new(1, 0, 0, 120),
		BackgroundTransparency = 1,
		Parent = panel,
	}, {
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local cards = {}
	for index, towerType in IdleTowers.ORDER do
		local def = IdleTowers.Defs[towerType]
		local card = UI.new("TextButton", {
			Size = UDim2.fromOffset(CARD_WIDTH, 120),
			LayoutOrder = index,
			BackgroundColor3 = def.color:Lerp(UI.Colors.Panel, 0.55),
			AutoButtonColor = true,
			Text = "",
			Parent = cardRow,
		}, { UI.corner(10), UI.padding(6) })
		local rarity = IdleConfig.RARITIES[def.rarity]
		local stroke = UI.stroke(rarity.color, 2)
		stroke.Transparency = 0
		stroke.Parent = card
		UI.label({
			Size = UDim2.new(1, 0, 0, 20),
			Font = Enum.Font.GothamBlack,
			Text = def.displayName,
			TextColor3 = rarity.color:Lerp(Color3.new(1, 1, 1), 0.4),
			MaxTextSize = 15,
			Parent = card,
		})
		UI.label({
			Position = UDim2.new(0, 0, 0, 22),
			Size = UDim2.new(1, 0, 0, 14),
			TextColor3 = UI.Colors.Muted,
			Text = kindLabel(def),
			MaxTextSize = 12,
			Parent = card,
		})
		UI.label({
			Position = UDim2.new(0, 0, 0, 40),
			Size = UDim2.new(1, 0, 0, 40),
			Text = `DPS {NumberFormat.short(IdleTowers.dps(towerType, 1))}\nPortée {def.range}`,
			MaxTextSize = 13,
			Parent = card,
		})
		local price = UI.label({
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, 0),
			Size = UDim2.new(1, 0, 0, 22),
			Font = Enum.Font.GothamBlack,
			MaxTextSize = 17,
			Parent = card,
		})
		cards[towerType] = { button = card, price = price }
	end

	-- Bonus de l'inventaire à poser sur la tour sélectionnée.
	local bonusRow = UI.new("Frame", {
		Position = UDim2.new(0, 0, 0, 178),
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = panel,
	}, {
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	})

	-- Bas du panneau : [Améliorer] [Vendre] pour une tour, [Débloquer] pour un cadenas.
	local actionButton = UI.button({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = UI.Colors.Error,
		MaxTextSize = 20,
		Parent = panel,
	})
	local upgradeButton = UI.button({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(0.6, -4, 0, 44),
		BackgroundColor3 = UI.Colors.Success,
		MaxTextSize = 20,
		Visible = false,
		Parent = panel,
	})

	------------------------------------------------------------------
	-- Sélection
	------------------------------------------------------------------
	local selectedSpot: number? = nil
	local highlight = Instance.new("Highlight")
	highlight.FillTransparency = 0.8
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded

	local function spotPad(spotIndex: number): Instance?
		local plot = myPlotFolder()
		return plot and plot:FindFirstChild("Spots") and plot.Spots:FindFirstChild("Spot" .. spotIndex)
	end
	local function towerOn(spotIndex: number): Model?
		local plot = myPlotFolder()
		local towers = plot and plot:FindFirstChild("Towers")
		if towers then
			for _, model in towers:GetChildren() do
				if model:GetAttribute("SpotIndex") == spotIndex then
					return model
				end
			end
		end
		return nil
	end

	local function select(spotIndex: number?)
		selectedSpot = spotIndex
		panel.Visible = spotIndex ~= nil
		local target = spotIndex and (towerOn(spotIndex) or spotPad(spotIndex))
		highlight.Adornee = target
		highlight.Parent = target
	end

	closeButton.Activated:Connect(function()
		select(nil)
	end)

	local function isUnlocked(towerType: string): boolean
		return table.find(listAttribute(player, "UnlockedTowers"), towerType) ~= nil
	end

	for towerType, card in cards do
		card.button.Activated:Connect(function()
			if not selectedSpot then
				return
			end
			if not isUnlocked(towerType) then
				UI.toast(`{IdleTowers.Defs[towerType].displayName} : invoque-la à l'autel des héros !`, "Warning")
				return
			end
			plotAction:FireServer("Place", selectedSpot, towerType)
		end)
	end

	-- Pose d'un bonus : si la tour en a déjà un, il faut cliquer deux fois (l'ancien est perdu).
	local bonusRowKey = nil
	local confirmBonus: string? = nil
	local function rebuildBonusRow(tower: Model?)
		local inventory = player:GetAttribute("Bonuses") or ""
		local current = tower and tower:GetAttribute("Bonus") or ""
		local key = `{selectedSpot}:{inventory}:{current}:{confirmBonus}`
		if key == bonusRowKey then
			return
		end
		bonusRowKey = key
		for _, child in bonusRow:GetChildren() do
			if not child:IsA("UIListLayout") then
				child:Destroy()
			end
		end

		local currentBonus = IdleConfig.BONUS_BY_ID[current]
		UI.label({
			Size = UDim2.fromOffset(150, 28),
			LayoutOrder = 0,
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Enum.Font.GothamBold,
			TextColor3 = if currentBonus then UI.Colors.Gold else UI.Colors.Muted,
			Text = if currentBonus then `★ {currentBonus.displayName}` else "Aucun bonus",
			MaxTextSize = 14,
			Parent = bonusRow,
		})

		local counts = {}
		for _, id in listAttribute(player, "Bonuses") do
			counts[id] = (counts[id] or 0) + 1
		end
		for order, bonus in IdleConfig.BONUSES do
			local amount = counts[bonus.id]
			if not amount then
				continue
			end
			local confirming = confirmBonus == bonus.id
			local button = UI.button({
				Size = UDim2.fromOffset(if confirming then 150 else 96, 28),
				LayoutOrder = order,
				BackgroundColor3 = if confirming then UI.Colors.Error else UI.Colors.Gold,
				TextColor3 = Color3.fromRGB(30, 25, 10),
				Text = if confirming then `Remplacer ? {bonus.displayName}` else `{bonus.displayName} ({amount})`,
				MaxTextSize = 13,
				Parent = bonusRow,
			})
			button.Activated:Connect(function()
				if currentBonus and confirmBonus ~= bonus.id then
					confirmBonus = bonus.id
					return
				end
				confirmBonus = nil
				Remotes.get("MachineAction"):FireServer("ApplyBonus", selectedSpot, bonus.id)
			end)
		end
		if next(counts) == nil then
			UI.label({
				Size = UDim2.fromOffset(300, 28),
				LayoutOrder = 99,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = UI.Colors.Muted,
				Text = "Forge des runes pour obtenir des bonus",
				MaxTextSize = 13,
				Parent = bonusRow,
			})
		end
	end

	actionButton.Activated:Connect(function()
		if not selectedSpot then
			return
		end
		local owned = ownedSpots()
		if not owned[selectedSpot] then
			-- Achète CET emplacement (le serveur vérifie le numéro et les pièces).
			plotAction:FireServer("BuySpot", selectedSpot)
		elseif towerOn(selectedSpot) then
			plotAction:FireServer("Sell", selectedSpot)
		end
	end)

	local function upgradeSelected()
		if selectedSpot and towerOn(selectedSpot) then
			plotAction:FireServer("Upgrade", selectedSpot)
		end
	end
	upgradeButton.Activated:Connect(upgradeSelected)

	local function refreshPanel()
		local spotIndex = selectedSpot
		if not spotIndex then
			return
		end
		local owned, ownedCount = ownedSpots()
		local tower = towerOn(spotIndex)
		highlight.Adornee = tower or spotPad(spotIndex)
		highlight.Parent = highlight.Adornee

		upgradeButton.Visible = false
		bonusRow.Visible = false
		actionButton.Size = UDim2.new(1, 0, 0, 44)

		if not owned[spotIndex] then
			-- Emplacement verrouillé : n'importe lequel s'achète, au même prix (celui du prochain).
			cardRow.Visible = false
			local cost = PlotLayout.spotCost(ownedCount + 1)
			panelTitle.Text = `🔒 Emplacement {spotIndex}`
			panelSubtitle.Text = "Débloque-le pour y poser une tour. Chaque achat augmente le prix des suivants."
			actionButton.Visible = true
			actionButton.Text = `Débloquer • {NumberFormat.short(cost)} pièces`
			actionButton.BackgroundColor3 = UI.Colors.Success
			actionButton.BackgroundTransparency = if coins() >= cost then 0 else 0.6
			return
		end

		cardRow.Visible = true
		local refund = 0
		local currentType = tower and tower:GetAttribute("TowerType")
		if tower then
			local def = IdleTowers.Defs[currentType]
			local level = tower:GetAttribute("Level") or 1
			local upgradeCost = IdleTowers.upgradeCost(currentType, level)
			refund = math.floor((tower:GetAttribute("Spent") or 0) * IdleConfig.SELL_REFUND)
			local dupes = dupesOf(player, currentType)
			local bonusId = tower:GetAttribute("Bonus")
			local now = IdleTowers.dpsOf(IdleTowers.effectiveStats(currentType, level, dupes, bonusId))
			local nextLevel = IdleTowers.dpsOf(IdleTowers.effectiveStats(currentType, level + 1, dupes, bonusId))
			local extras = if dupes > 0 then `  •  doublons +{math.floor(dupes * IdleConfig.DUPLICATE_DAMAGE_BONUS * 100 + 0.5)} %` else ""
			panelTitle.Text = `{def.displayName} • Niv. {level}{extras}`
			panelSubtitle.Text = `DPS {NumberFormat.short(now)} → {NumberFormat.short(nextLevel)} au niveau {level + 1}  •  ou remplace-la (revendue +{NumberFormat.short(refund)}) :`
			bonusRow.Visible = true
			rebuildBonusRow(tower)

			upgradeButton.Visible = true
			upgradeButton.Text = `Améliorer [E] • {NumberFormat.short(upgradeCost)}`
			upgradeButton.BackgroundTransparency = if coins() >= upgradeCost then 0 else 0.6
			actionButton.Visible = true
			actionButton.Size = UDim2.new(0.4, -4, 0, 44)
			actionButton.Text = `Vendre • +{NumberFormat.short(refund)}`
			actionButton.BackgroundColor3 = UI.Colors.Error
			actionButton.BackgroundTransparency = 0
		else
			panelTitle.Text = `Emplacement {spotIndex}`
			panelSubtitle.Text = "Choisis une tour à poser :"
			actionButton.Visible = false
		end

		for towerType, card in cards do
			local cost = IdleTowers.Defs[towerType].placeCost
			if not isUnlocked(towerType) then
				card.price.Text = "🔒 Autel"
				card.price.TextColor3 = UI.Colors.Muted
				card.button.BackgroundTransparency = 0.7
			elseif towerType == currentType then
				card.price.Text = "POSÉE"
				card.price.TextColor3 = UI.Colors.Success
				card.button.BackgroundTransparency = 0.5
			else
				local affordable = coins() + refund >= cost
				card.price.Text = NumberFormat.short(cost)
				card.price.TextColor3 = if affordable then UI.Colors.Gold else UI.Colors.Error
				card.button.BackgroundTransparency = if affordable then 0 else 0.5
			end
		end
	end

	-- Clic dans le monde : emplacement ou tour de TA parcelle.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Q then
			select(nil)
			return
		elseif input.KeyCode == Enum.KeyCode.E then
			upgradeSelected()
			return
		end
		local isClick = input.UserInputType == Enum.UserInputType.MouseButton1
		local isTouch = input.UserInputType == Enum.UserInputType.Touch
		if not isClick and not isTouch then
			return
		end
		local plot = myPlotFolder()
		if not plot then
			return
		end
		params.FilterDescendantsInstances = { plot }

		local camera = workspace.CurrentCamera
		local ray
		if isTouch then
			ray = camera:ScreenPointToRay(input.Position.X, input.Position.Y)
		else
			local mouse = UserInputService:GetMouseLocation()
			ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
		end
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
		if not hit then
			return
		end
		local spotIndex = hit.Instance:GetAttribute("SpotIndex")
		if not spotIndex then
			local model = hit.Instance:FindFirstAncestorOfClass("Model")
			spotIndex = model and model:GetAttribute("SpotIndex")
		end
		if spotIndex then
			select(spotIndex)
			refreshPanel()
		end
	end)

	------------------------------------------------------------------
	-- Mise à jour
	------------------------------------------------------------------
	local function update()
		coinsLabel.Text = "💰 " .. NumberFormat.short(coins())

		local plot = myPlotFolder()
		local wave = plot and plot:GetAttribute("Wave")
		wavePanel.Visible = wave ~= nil
		if wave then
			local waveType = IdleConfig.WAVE_TYPES[plot:GetAttribute("WaveType")] or IdleConfig.WAVE_TYPES.Mixed
			local maxHealth = plot:GetAttribute("MaxBaseHealth") or IdleConfig.BASE_HEALTH
			local health = plot:GetAttribute("BaseHealth") or maxHealth
			waveLabel.Text = `Vague {wave} • {waveType.displayName}`
			waveLabel.TextColor3 = if waveType.displayName == "SEIGNEUR DE GUERRE" then UI.Colors.Error else UI.Colors.Text
			hintLabel.Text = waveType.hint
			setBaseHealth(health / maxHealth)
			local state = plot:GetAttribute("State")
			if state == "Intermission" then
				local nextAt = plot:GetAttribute("NextWaveAt") or 0
				local remaining = math.max(0, math.ceil(nextAt - workspace:GetServerTimeNow()))
				waveInfo.Text = `Prochaine vague dans {remaining}s  •  Record : vague {plot:GetAttribute("HighestWave") or 1}`
			else
				waveInfo.Text = `Ennemis restants : {plot:GetAttribute("EnemiesLeft") or 0}  •  Record : vague {plot:GetAttribute("HighestWave") or 1}`
			end
		end

		refreshPanel()
	end

	task.spawn(function()
		while gui.Parent do
			update()
			task.wait(0.1)
		end
	end)
end

return PlotUI

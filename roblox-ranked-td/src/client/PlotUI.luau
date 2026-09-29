-- Interface de ta parcelle : pièces, vague en cours, et panneau des emplacements / tours.
-- Emplacement libre : clique sur une carte pour poser la tour. Tour posée : sa fiche (Améliorer, Vendre,
-- bonus) et un bouton « Remplacer… » à part ; remplacer demande toujours une confirmation, pour ne
-- jamais perdre une grosse tour par accident (vendre aussi : 2 clics).
-- Clique sur n'importe quel cadenas pour débloquer CET emplacement (le prix ne dépend que du nombre
-- d'emplacements déjà possédés, il monte après chaque achat).
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
	Beam = "Rayon continu",
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
-- Un bouton de confirmation ignore les clics juste après son apparition : un double clic ne valide jamais rien.
local CONFIRM_ARM_DELAY = 0.4
-- Après une pose, pas de nouvelle pose sur cet emplacement tant que la tour n'est pas arrivée (sinon un
-- double clic sur une carte remplaçait la tour qu'on venait de poser).
local PLACE_LOCK_TIME = 2
local SELL_CONFIRM_TIME = 3 -- secondes pour confirmer une vente (2e clic)

local function kindLabel(def): string
	if def.fireRadius then
		return "Flèches de feu"
	elseif def.kind == "Splash" and def.slow then
		return "Zone + ralentit"
	elseif def.kind == "Single" and def.slow then
		return "Ralentit 1 cible"
	end
	return KIND_LABELS[def.kind] or ""
end

-- Stats d'une carte (niveau 1, doublons compris) : dégâts par seconde, vitesse, portée.
-- Rayon continu : dégâts par seconde au début → au maximum, « continu » à la place de la vitesse.
local function cardStatsText(stats): string
	local range = `Portée {UI.decimal(stats.range)}`
	if stats.kind == "Beam" then
		return `Rayon {NumberFormat.short(IdleTowers.dpsOf(stats))}→{NumberFormat.short(IdleTowers.beamMaxDps(stats))}/s\n{UI.towerSpeed(stats)}\n{range}`
	end
	return `DPS {NumberFormat.short(IdleTowers.dpsOf(stats))}\n{UI.towerSpeed(stats)}\n{range}`
end

local function refundPercent(): number
	return math.floor(IdleConfig.SELL_REFUND * 100 + 0.5)
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
		Size = UDim2.new(0, 340, 0, 82),
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
	-- Pas de PV de base : un seul ennemi qui atteint la base fait rater la vague.
	UI.label({
		Position = UDim2.new(0, 0, 0, 38),
		Size = UDim2.new(1, 0, 0, 13),
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.fromRGB(235, 160, 110),
		Text = "⚠ 1 ennemi qui passe = vague ratée",
		MaxTextSize = 12,
		Parent = wavePanel,
	})
	local waveInfo = UI.label({
		Position = UDim2.new(0, 0, 0, 52),
		Size = UDim2.new(1, 0, 0, 14),
		TextColor3 = UI.Colors.Muted,
		MaxTextSize = 13,
		Parent = wavePanel,
	})

	------------------------------------------------------------------
	-- Panneau emplacement / tour (en bas à droite : le chat de Roblox occupe le bas à gauche et
	-- intercepterait les clics sur les cartes)
	------------------------------------------------------------------
	local count = #IdleTowers.ORDER
	local panel = UI.new("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.fromOffset(count * (CARD_WIDTH + 8) + 12, PANEL_HEIGHT),
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.05,
		Visible = false,
		Parent = gui,
	}, { UI.corner(14), UI.padding(10), UI.stroke() })
	-- Réduit le panneau quand il n'a pas la place à côté du chat (petits écrans, téléphones).
	local CHAT_WIDTH = 500 -- largeur laissée au chat sur ordinateur
	local panelScale = UI.new("UIScale", { Parent = panel })
	local function fitPanel()
		local viewport = workspace.CurrentCamera.ViewportSize
		local reserved = if viewport.X >= 1000 then CHAT_WIDTH else 0
		panelScale.Scale = math.min(1, (viewport.X - reserved - 32) / panel.Size.X.Offset, (viewport.Y * 0.55) / PANEL_HEIGHT)
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

	-- Cartes des tours : sur un emplacement libre (pose directe) ou après « Remplacer… ».
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
		-- DPS, vitesse d'attaque et portée au niveau 1 (doublons compris) : mis à jour dans refreshCards.
		local stats = UI.label({
			Position = UDim2.new(0, 0, 0, 38),
			Size = UDim2.new(1, 0, 0, 46),
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
		cards[towerType] = { button = card, price = price, stats = stats }
	end

	-- Fiche de la tour posée (à la place des cartes) : ses stats et le bouton « Remplacer… », à part.
	local towerInfo = UI.new("Frame", {
		Position = UDim2.new(0, 0, 0, 52),
		Size = UDim2.new(1, 0, 0, 120),
		BackgroundColor3 = UI.Colors.Background,
		BackgroundTransparency = 0.4,
		Visible = false,
		Parent = panel,
	}, { UI.corner(10), UI.padding(8) })
	local towerStats = UI.label({
		Size = UDim2.new(1, -250, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextWrapped = true,
		RichText = true,
		MaxTextSize = 16,
		Parent = towerInfo,
	})
	local replaceButton = UI.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 12),
		Size = UDim2.fromOffset(230, 46),
		BackgroundColor3 = UI.Colors.Warning,
		Text = "Remplacer…",
		MaxTextSize = 20,
		Parent = towerInfo,
	})
	UI.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 64),
		Size = UDim2.fromOffset(230, 36),
		TextColor3 = UI.Colors.Muted,
		TextWrapped = true,
		Text = "Par une autre tour, qui repart au niveau 1 (avec confirmation)",
		MaxTextSize = 12,
		Parent = towerInfo,
	})

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

	-- Bas du panneau : [Améliorer] [Vendre] pour une tour, [Débloquer] pour un cadenas,
	-- [Garder ma tour] pendant le choix d'un remplacement.
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
	local backButton = UI.button({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = UI.Colors.PanelLight,
		Text = "← Garder ma tour",
		MaxTextSize = 20,
		Visible = false,
		Parent = panel,
	})

	-- Confirmation du remplacement : recouvre tout le panneau. Ses boutons sont en bas, loin des cartes
	-- (un double clic sur une carte ne tombe jamais sur « Confirmer »).
	local confirmFrame = UI.new("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UI.Colors.Panel,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 10,
		Visible = false,
		Parent = panel,
	}, { UI.corner(10) })
	local confirmTitle = UI.label({
		Position = UDim2.new(0, 0, 0, 6),
		Size = UDim2.new(1, 0, 0, 64),
		Font = Enum.Font.GothamBlack,
		TextWrapped = true,
		RichText = true,
		MaxTextSize = 24,
		Parent = confirmFrame,
	})
	local confirmDetail = UI.label({
		Position = UDim2.new(0, 0, 0, 78),
		Size = UDim2.new(1, 0, 0, 64),
		TextWrapped = true,
		RichText = true,
		MaxTextSize = 17,
		Parent = confirmFrame,
	})
	local cancelReplaceButton = UI.button({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(0.5, -4, 0, 44),
		BackgroundColor3 = UI.Colors.PanelLight,
		Text = "Annuler",
		MaxTextSize = 20,
		Parent = confirmFrame,
	})
	local confirmReplaceButton = UI.button({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 1, 0),
		Size = UDim2.new(0.5, -4, 0, 44),
		BackgroundColor3 = UI.Colors.Error,
		Text = "Confirmer le remplacement",
		MaxTextSize = 20,
		Parent = confirmFrame,
	})

	------------------------------------------------------------------
	-- Sélection
	------------------------------------------------------------------
	local selectedSpot: number? = nil
	local replacing = false -- tour posée : cartes affichées pour choisir la remplaçante
	local replacingSince = 0
	local confirmReplace = nil -- { spot, model, towerType, openedAt } : fenêtre de confirmation ouverte
	local pendingPlace = {} -- [spotIndex] = { towerType, at } : pose envoyée, tour pas encore arrivée
	local sellArmedAt: number? = nil -- 1er clic sur « Vendre »
	-- Affichage du panneau ("locked", "empty", "tower", "replace", "confirm") et heure de son dernier
	-- changement : un bouton qui vient d'apparaître sous la souris ignore le 2e clic d'un double clic.
	local panelMode = ""
	local modeChangedAt = 0
	local function setMode(mode: string)
		if mode ~= panelMode then
			panelMode = mode
			modeChangedAt = os.clock()
		end
	end
	local function justChanged(): boolean
		return os.clock() - modeChangedAt < CONFIRM_ARM_DELAY
	end
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
	local function refundOf(tower: Model): number
		return math.floor((tower:GetAttribute("Spent") or 0) * IdleConfig.SELL_REFUND)
	end

	local confirmBonus: string? = nil
	local confirmBonusAt = 0

	local function select(spotIndex: number?)
		if spotIndex ~= selectedSpot then
			-- Autre emplacement : on repart de sa fiche (aucun choix en cours ne suit la sélection).
			replacing = false
			confirmReplace = nil
			sellArmedAt = nil
			confirmBonus = nil
			panelMode = ""
		end
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

	-- Déclarée ici, remplie plus bas (les boutons ci-dessous la rappellent après chaque changement).
	local refreshPanel: () -> ()

	for towerType, card in cards do
		card.button.Activated:Connect(function()
			local spotIndex = selectedSpot
			if not spotIndex or pendingPlace[spotIndex] or confirmReplace then
				return
			end
			local def = IdleTowers.Defs[towerType]
			if not isUnlocked(towerType) then
				UI.toast(`{def.displayName} : invoque-la à l'autel des héros !`, "Warning")
				return
			end
			local tower = towerOn(spotIndex)
			if not tower then
				-- Emplacement libre : pose directe (pas assez de pièces : rien n'est envoyé, l'emplacement
				-- n'est pas bloqué 2 s pour rien).
				if coins() < def.placeCost then
					UI.toast(`Il te faut {NumberFormat.short(def.placeCost)} pièces`, "Error")
					return
				end
				pendingPlace[spotIndex] = { towerType = towerType, at = os.clock() }
				plotAction:FireServer("Place", spotIndex, towerType)
				refreshPanel()
				return
			end
			-- Emplacement occupé : seulement après « Remplacer… », et toujours avec confirmation.
			if not replacing or os.clock() - replacingSince < CONFIRM_ARM_DELAY then
				return
			end
			if tower:GetAttribute("TowerType") == towerType then
				UI.toast("Cette tour est déjà posée ici", "Warning")
				return
			end
			if coins() + refundOf(tower) < def.placeCost then
				UI.toast(`Il te faut {NumberFormat.short(def.placeCost)} pièces`, "Error")
				return
			end
			confirmReplace = { spot = spotIndex, model = tower, towerType = towerType, openedAt = os.clock() }
			refreshPanel()
		end)
	end

	replaceButton.Activated:Connect(function()
		if justChanged() or not selectedSpot or pendingPlace[selectedSpot] or not towerOn(selectedSpot) then
			return
		end
		replacing = true
		replacingSince = os.clock()
		sellArmedAt = nil
		refreshPanel()
	end)
	backButton.Activated:Connect(function()
		if justChanged() then
			return
		end
		replacing = false
		confirmReplace = nil
		refreshPanel()
	end)
	cancelReplaceButton.Activated:Connect(function()
		confirmReplace = nil
		refreshPanel()
	end)
	confirmReplaceButton.Activated:Connect(function()
		local confirm = confirmReplace
		if not confirm or os.clock() - confirm.openedAt < CONFIRM_ARM_DELAY then
			return
		end
		confirmReplace = nil
		replacing = false
		-- La tour a pu changer entre-temps (vendue, déjà remplacée) : on ne remplace que celle affichée.
		if selectedSpot ~= confirm.spot or towerOn(confirm.spot) ~= confirm.model then
			UI.toast("La tour a changé entre-temps : rien n'a été remplacé", "Warning")
			refreshPanel()
			return
		end
		pendingPlace[confirm.spot] = { towerType = confirm.towerType, at = os.clock() }
		-- 4e argument = la tour remplacée : sans lui, le serveur refuse de poser sur une tour existante.
		plotAction:FireServer("Place", confirm.spot, confirm.towerType, confirm.model:GetAttribute("TowerType"))
		refreshPanel()
	end)

	-- Pose d'un bonus : si la tour en a déjà un, il faut cliquer deux fois (l'ancien est perdu).
	local bonusRowKey = nil
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
					confirmBonusAt = os.clock()
					return
				end
				if confirmBonus == bonus.id and os.clock() - confirmBonusAt < CONFIRM_ARM_DELAY then
					return -- double clic : pas une confirmation
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
		-- justChanged : ex. 2e clic d'un double clic sur « Confirmer » qui tomberait sur « Vendre ».
		if not selectedSpot or justChanged() then
			return
		end
		local owned = ownedSpots()
		if not owned[selectedSpot] then
			-- Achète CET emplacement (le serveur vérifie le numéro et les pièces).
			plotAction:FireServer("BuySpot", selectedSpot)
		elseif towerOn(selectedSpot) then
			-- Vente en 2 clics : le 1er arme le bouton, le 2e (pas trop vite, pas trop tard) vend.
			local now = os.clock()
			if sellArmedAt and now - sellArmedAt <= SELL_CONFIRM_TIME then
				if now - sellArmedAt >= CONFIRM_ARM_DELAY then
					sellArmedAt = nil
					plotAction:FireServer("Sell", selectedSpot)
				end
			else
				sellArmedAt = now
			end
			refreshPanel()
		end
	end)

	local function upgradeSelected()
		-- Pas pendant un remplacement (bouton Améliorer caché) : inutile d'améliorer la tour qu'on remplace.
		if selectedSpot and not confirmReplace and not replacing and towerOn(selectedSpot) then
			plotAction:FireServer("Upgrade", selectedSpot)
		end
	end
	upgradeButton.Activated:Connect(upgradeSelected)

	-- Cartes : stats au niveau 1 (doublons compris) et prix. currentType = tour à remplacer (ou nil),
	-- refund = ce que rapporte sa revente, locked = une pose est en cours sur cet emplacement.
	local function refreshCards(currentType: string?, refund: number, locked: boolean)
		for towerType, card in cards do
			local stats = IdleTowers.effectiveStats(towerType, 1, dupesOf(player, towerType))
			card.stats.Text = cardStatsText(stats)

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
				card.button.BackgroundTransparency = if affordable and not locked then 0 else 0.5
			end
		end
	end

	-- Lignes de la fiche d'une tour posée (niveau, doublons et bonus compris).
	local function towerSheet(towerType: string, level: number, dupes: number, bonusId: string?): string
		local def = IdleTowers.Defs[towerType]
		local stats = IdleTowers.effectiveStats(towerType, level, dupes, bonusId)
		local nextStats = IdleTowers.effectiveStats(towerType, level + 1, dupes, bonusId)
		local range = `Portée <b>{UI.decimal(stats.range)}</b>`
		local lines
		if def.kind == "Beam" then
			-- Rayon continu : dégâts par seconde au début (x1) → au maximum, et le temps pour y arriver.
			lines = {
				`Rayon <b>{NumberFormat.short(IdleTowers.dpsOf(stats))} → {NumberFormat.short(IdleTowers.beamMaxDps(stats))}</b> dégâts/s  →  {NumberFormat.short(IdleTowers.dpsOf(nextStats))} → {NumberFormat.short(IdleTowers.beamMaxDps(nextStats))} au niveau {level + 1}`,
				`Vitesse <b>{UI.towerSpeed(stats)}</b>  •  x{UI.decimal(stats.beamRampMax)} en {UI.decimal(math.floor(IdleTowers.beamRampSeconds(stats) * 10 + 0.5) / 10)} s sur la même cible  •  {range}`,
			}
		else
			lines = {
				`DPS <b>{NumberFormat.short(IdleTowers.dpsOf(stats))}</b>  →  {NumberFormat.short(IdleTowers.dpsOf(nextStats))} au niveau {level + 1}`,
				`Dégâts <b>{NumberFormat.short(stats.damage)}</b> par coup  •  Vitesse <b>{UI.towerSpeed(stats)}</b>  •  {range}`,
			}
		end
		-- Façon d'attaquer : cible, zone, chaîne, rayon, feu, ralentissement.
		local special = {}
		if stats.chains then
			table.insert(special, `Éclair sur {stats.chains} ennemis`)
		elseif def.kind == "Splash" and stats.splash then
			table.insert(special, `Zone (rayon {UI.decimal(stats.splash)})`)
		elseif def.kind == "Aura" then
			table.insert(special, "Frappe tous les ennemis à portée")
		elseif def.kind == "Beam" then
			table.insert(special, "Garde sa cible tant qu'elle est à portée (idéal dans un virage)")
		else
			table.insert(special, KIND_LABELS[def.kind] or "")
		end
		if def.targeting == "Strongest" then
			table.insert(special, if def.kind == "Beam" then "choisit le plus résistant" else "vise le plus résistant")
		end
		if stats.fireRadius then
			table.insert(
				special,
				`feu au sol : {NumberFormat.short(IdleTowers.fireDps(stats))} dégâts/s pendant {UI.decimal(stats.fireDuration)} s (rayon {UI.decimal(stats.fireRadius)})`
			)
		end
		if stats.slow and stats.slowDuration then
			table.insert(special, `ralentit de {math.floor(stats.slow * 100 + 0.5)} % pendant {UI.decimal(stats.slowDuration)} s`)
		end
		table.insert(lines, table.concat(special, "  •  "))
		if dupes > 0 then
			-- Arrondi : sans lui, 29 doublons affichaient +57 % au lieu de +58 % (virgules des calculs).
			local percent = math.floor(dupes * IdleConfig.DUPLICATE_DAMAGE_BONUS * 100 + 0.5)
			table.insert(lines, `Doublons : {NumberFormat.short(dupes)} (+{NumberFormat.short(percent)} % de dégâts)`)
		end
		return table.concat(lines, "\n")
	end

	function refreshPanel()
		local spotIndex = selectedSpot
		if not spotIndex then
			return
		end
		local owned, ownedCount = ownedSpots()
		local tower = towerOn(spotIndex)
		highlight.Adornee = tower or spotPad(spotIndex)
		highlight.Parent = highlight.Adornee

		-- Pose en cours : terminée quand la nouvelle tour est arrivée (ou après PLACE_LOCK_TIME, si le
		-- serveur l'a refusée).
		local pending = pendingPlace[spotIndex]
		if pending and ((tower and tower:GetAttribute("TowerType") == pending.towerType) or os.clock() - pending.at > PLACE_LOCK_TIME) then
			pendingPlace[spotIndex] = nil
			pending = nil
		end
		-- La tour a changé (vendue, remplacée...) pendant un choix : on revient à la fiche de l'emplacement.
		if confirmReplace and (confirmReplace.spot ~= spotIndex or confirmReplace.model ~= tower) then
			confirmReplace = nil
		end
		if not tower then
			replacing = false
			sellArmedAt = nil
		end
		if sellArmedAt and os.clock() - sellArmedAt > SELL_CONFIRM_TIME then
			sellArmedAt = nil
		end

		cardRow.Visible = false
		towerInfo.Visible = false
		bonusRow.Visible = false
		upgradeButton.Visible = false
		actionButton.Visible = false
		backButton.Visible = false
		confirmFrame.Visible = false
		actionButton.Size = UDim2.new(1, 0, 0, 44)

		if not owned[spotIndex] then
			-- Emplacement verrouillé : n'importe lequel s'achète, au même prix (celui du prochain).
			setMode("locked")
			local cost = PlotLayout.spotCost(ownedCount + 1)
			panelTitle.Text = `🔒 Emplacement {spotIndex}`
			panelSubtitle.Text = "Débloque-le pour y poser une tour. Chaque achat augmente le prix des suivants."
			actionButton.Visible = true
			actionButton.Text = `Débloquer • {NumberFormat.short(cost)} pièces`
			actionButton.BackgroundColor3 = UI.Colors.Success
			actionButton.BackgroundTransparency = if coins() >= cost then 0 else 0.6
			return
		end

		if not tower then
			-- Emplacement libre : les cartes posent directement.
			setMode("empty")
			panelTitle.Text = `Emplacement {spotIndex}`
			panelSubtitle.Text = if pending then "Pose en cours…" else "Choisis une tour à poser :"
			cardRow.Visible = true
			refreshCards(nil, 0, pending ~= nil)
			return
		end
		local currentType = tower:GetAttribute("TowerType")
		local def = IdleTowers.Defs[currentType]
		if not def then
			setMode("unknown")
			panelTitle.Text = `Emplacement {spotIndex}`
			panelSubtitle.Text = ""
			return
		end

		local level = tower:GetAttribute("Level") or 1
		local refund = refundOf(tower)

		if confirmReplace then
			setMode("confirm")
			local newDef = IdleTowers.Defs[confirmReplace.towerType]
			local bonus = IdleConfig.BONUS_BY_ID[tower:GetAttribute("Bonus") or ""]
			-- Inventaire plein : le serveur ne peut pas rendre le bonus (PlotGame:removeTower), on le dit.
			local inventoryFull = #listAttribute(player, "Bonuses") >= IdleConfig.MAX_BONUS_INVENTORY
			local bonusLine = if not bonus
				then ""
				elseif inventoryFull then `\n<font color="#F06464">Son bonus ({bonus.displayName}) sera PERDU : ton inventaire est plein.</font>`
				else `\nSon bonus ({bonus.displayName}) retourne dans ton inventaire.`
			confirmTitle.Text = `Remplacer ton <font color="#{def.color:Lerp(Color3.new(1, 1, 1), 0.4):ToHex()}">{def.displayName} niv. {level}</font> par <font color="#{newDef.color:Lerp(Color3.new(1, 1, 1), 0.4):ToHex()}">{newDef.displayName}</font> ?`
			confirmDetail.Text = `Tu récupères {refundPercent()} % : <b>{NumberFormat.short(refund)} pièces</b>.`
				.. `\n{newDef.displayName} coûte {NumberFormat.short(newDef.placeCost)} pièces et repart au <b>niveau 1</b>.`
				.. bonusLine
			confirmReplaceButton.BackgroundTransparency = if os.clock() - confirmReplace.openedAt < CONFIRM_ARM_DELAY then 0.5 else 0
			confirmFrame.Visible = true
			return
		end

		if replacing then
			setMode("replace")
			panelTitle.Text = `Remplacer : {def.displayName} • Niv. {level}`
			panelSubtitle.Text = `Choisis la nouvelle tour (elle repart au niveau 1 ; tu récupères {refundPercent()} % : +{NumberFormat.short(refund)}) :`
			cardRow.Visible = true
			refreshCards(currentType, refund, pending ~= nil)
			backButton.Visible = true
			return
		end

		-- Fiche de la tour posée.
		setMode("tower")
		local dupes = dupesOf(player, currentType)
		local upgradeCost = IdleTowers.upgradeCost(currentType, level)
		panelTitle.Text = `{def.displayName} • Niv. {level}`
		panelSubtitle.Text = if pending then "Remplacement en cours…" else def.description or ""
		towerInfo.Visible = true
		towerStats.Text = towerSheet(currentType, level, dupes, tower:GetAttribute("Bonus"))
		replaceButton.BackgroundTransparency = if pending then 0.6 else 0
		bonusRow.Visible = true
		rebuildBonusRow(tower)

		upgradeButton.Visible = true
		upgradeButton.Text = `Améliorer [E] • {NumberFormat.short(upgradeCost)}`
		upgradeButton.BackgroundTransparency = if coins() >= upgradeCost then 0 else 0.6
		actionButton.Visible = true
		actionButton.Size = UDim2.new(0.4, -4, 0, 44)
		actionButton.BackgroundColor3 = UI.Colors.Error
		if sellArmedAt then
			actionButton.Text = `Confirmer la vente • +{NumberFormat.short(refund)}`
			actionButton.BackgroundTransparency = if os.clock() - sellArmedAt < CONFIRM_ARM_DELAY then 0.4 else 0
		else
			actionButton.Text = `Vendre • +{NumberFormat.short(refund)}`
			actionButton.BackgroundTransparency = 0
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
			waveLabel.Text = `Vague {wave} • {waveType.displayName}`
			waveLabel.TextColor3 = if waveType.displayName == "SEIGNEUR DE GUERRE" then UI.Colors.Error else UI.Colors.Text
			hintLabel.Text = waveType.hint
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

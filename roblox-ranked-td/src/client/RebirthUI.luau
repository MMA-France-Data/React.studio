-- Renaissance (mode infini) : bouton dans la colonne de gauche (sous les machines) et fenêtre de
-- confirmation. Seule la vague repart à 1 ; en échange, un bonus de pièces permanent
-- (IdleConfig.rebirthGain). Le serveur publie BestWave, CoinBonus et Rebirths sur le dossier de
-- la parcelle (PlotGame:syncAttributes) et revérifie tout lui-même (PlotGame:rebirth).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local IdleConfig = require(Shared.IdleConfig)
local NumberFormat = require(Shared.NumberFormat)
local Remotes = require(Shared.Remotes)
local UI = require(script.Parent.UI)

local RebirthUI = {}

-- Couleur de la renaissance (bouton, fenêtre, flash).
local REBIRTH_COLOR = Color3.fromRGB(132, 42, 48)
local EXAMPLE_REWARD = 10 -- l'ennemi « qui vaut 10 pièces » de l'exemple
-- Taille de la fenêtre sur un écran d'ordinateur (réduite sur un téléphone pour tenir entière : UI.fitWindow).
local WINDOW_SIZE = Vector2.new(520, 440)
local GOLD_HEX = "#" .. UI.Colors.Gold:ToHex()
local MUTED_HEX = "#" .. UI.Colors.Muted:ToHex()

-- Montant de l'exemple : 10.41, 10.4, 11 ; au-delà de 1000 : NumberFormat.short.
local function formatAmount(value: number): string
	if value >= 1000 then
		return NumberFormat.short(value)
	end
	local text = string.format("%.2f", math.floor(value * 100 + 0.5) / 100)
	text = text:gsub("0+$", ""):gsub("%.$", "")
	return text
end

function RebirthUI.start()
	local player = Players.LocalPlayer
	local plotAction = Remotes.get("PlotAction")
	local plotsFolder = workspace:WaitForChild("Hub"):WaitForChild("Plots")
	local gui = UI.screen("Rebirth", 21)
	-- Le bouton a son propre ScreenGui (ordre 0, comme LobbyUI) : il reste sous le voile sombre
	-- de la fenêtre des machines (ordre 20) au lieu de rester cliquable par-dessus.
	local buttonGui = UI.screen("RebirthButton")
	local percent = IdleConfig.formatPercent
	local minWave = IdleConfig.REBIRTH_MIN_WAVE

	-- État de la run, lu sur le dossier de ma parcelle.
	local function readPlot(): (number, number, number)
		local index = player:GetAttribute("Plot")
		local plot = index and plotsFolder:FindFirstChild("Plot" .. index)
		if not plot then
			return 1, 0, 1
		end
		return plot:GetAttribute("BestWave") or 1, plot:GetAttribute("CoinBonus") or 0, plot:GetAttribute("HighestWave") or 1
	end

	------------------------------------------------------------------
	-- Bouton de la colonne de gauche (index 2, sous « Forge runique ») : 2 lignes,
	-- « Renaissance » et le bonus de pièces actuel.
	------------------------------------------------------------------
	local button = UI.button({
		Position = UDim2.new(0, 16, 0, UI.LEFT_COLUMN_TOP + 2 * UI.LEFT_COLUMN_STEP),
		Size = UDim2.fromOffset(180, 46),
		BackgroundColor3 = UI.Colors.PanelLight,
		Text = "",
		Parent = buttonGui,
	})
	-- Contour qui pulse quand la renaissance est disponible.
	local buttonStroke = UI.stroke(UI.Colors.Gold, 2)
	buttonStroke.Enabled = false
	buttonStroke.Parent = button
	TweenService:Create(
		buttonStroke,
		TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Transparency = 0 }
	):Play()
	-- (Hauteurs en parts du bouton : 20 et 13 px sur un ordinateur, moins sur le petit bouton d'un téléphone.)
	local buttonTitle = UI.label({
		Size = UDim2.new(1, 0, 0.59, 0),
		Font = Enum.Font.GothamBold,
		MaxTextSize = 17,
		Parent = button,
	})
	local buttonBonus = UI.label({
		Position = UDim2.new(0, 0, 0.61, 0),
		Size = UDim2.new(1, 0, 0.39, 0),
		MaxTextSize = 12,
		Parent = button,
	})
	-- Téléphone : le même bouton (son nom et son gain, comme dans les autres jeux : demande du propriétaire), plus
	-- petit, contre le bord droit de l'écran sous les icônes de l'autel et de la forge (UI.leftColumnSlot).
	UI.placeInLeftColumn(button, 2)

	------------------------------------------------------------------
	-- Astuce, une seule fois (demande du propriétaire, 30/09/2026) : au premier échec d'une vague quand la
	-- renaissance est possible, le serveur envoie « RebirthHint » (PlotGame:endWave). Petit panneau à droite du
	-- bouton, qui pulse déjà : « Tu bloques ? Utilise la Renaissance, sans perdre ta progression ».
	------------------------------------------------------------------
	local hint = UI.new("Frame", {
		Name = "RebirthHint",
		Size = UDim2.fromOffset(310, 128),
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.04,
		Visible = false,
		Parent = buttonGui,
	}, { UI.corner(12), UI.padding(10), UI.stroke(UI.Colors.Gold, 2) })
	local hintScale = UI.new("UIScale", { Parent = hint })
	local hintText = UI.label({
		Name = "HintText",
		Size = UDim2.new(1, 0, 1, -40),
		RichText = true,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		MaxTextSize = 15,
		Parent = hint,
	})
	local hintOk = UI.button({
		Name = "HintOk",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 1, 0),
		Size = UDim2.fromOffset(120, 34),
		BackgroundColor3 = UI.Colors.Success,
		Text = "Compris !",
		MaxTextSize = 16,
		Parent = hint,
	})
	local hintShownAt = 0
	local function placeHint()
		-- À côté du bouton Renaissance, à sa hauteur, sans sortir de l'écran (réduit sur un téléphone) : à sa droite
		-- (ordinateur : le bouton est dans la colonne de gauche), ou à sa gauche quand il est contre le bord droit
		-- (téléphone : icône à droite de l'écran).
		local screen = UI.screenSize(buttonGui)
		local at = button.AbsolutePosition - buttonGui.AbsolutePosition
		local right = at.X + button.AbsoluteSize.X + 10
		local onLeft = at.X > screen.X / 2
		hintScale.Scale = math.clamp((if onLeft then at.X - 22 else screen.X - right - 12) / 310, 0.6, 1)
		local width, height = 310 * hintScale.Scale, 128 * hintScale.Scale
		hint.Position = UDim2.fromOffset(
			math.floor(if onLeft then at.X - 10 - width else right),
			math.floor(math.clamp(at.Y, 8, math.max(8, screen.Y - height - 8)))
		)
	end
	hintOk.Activated:Connect(function()
		hint.Visible = false
	end)
	Remotes.get("RebirthHint").OnClientEvent:Connect(function(gain)
		local value = if typeof(gain) == "number" then gain else IdleConfig.REBIRTH_BASE_GAIN
		hintText.Text = `💡 <b>Tu bloques sur une vague ?</b>\nUtilise la <b>Renaissance</b> sans perdre ta progression : tu gardes tes tours, tes améliorations et tes pièces, et tu gagnes +{percent(value)} % de pièces pour toujours.`
		UI.showShortcuts() -- (téléphone : le bouton Renaissance revient si le joueur avait masqué les icônes)
		placeHint()
		hint.Visible = true
		local shownAt = os.clock()
		hintShownAt = shownAt
		task.delay(25, function()
			if hintShownAt == shownAt then
				hint.Visible = false
			end
		end)
	end)

	------------------------------------------------------------------
	-- Fenêtre de confirmation (même style que les machines, MachineUI)
	------------------------------------------------------------------
	local overlay = UI.new("TextButton", {
		Name = "Overlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.5,
		AutoButtonColor = false,
		Text = "",
		Visible = false,
		Parent = gui,
	})
	local window = UI.new("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(WINDOW_SIZE.X, WINDOW_SIZE.Y),
		BackgroundColor3 = UI.Colors.Panel,
		Parent = overlay,
	}, { UI.corner(16), UI.padding(14) })
	local windowStroke = UI.stroke(REBIRTH_COLOR, 3)
	windowStroke.Transparency = 0
	windowStroke.Parent = window
	-- Petit écran (téléphone) : toute la fenêtre est réduite pour tenir sous la barre du haut de Roblox.
	UI.fitWindow(window, WINDOW_SIZE)

	UI.label({
		Size = UDim2.new(1, -40, 0, 30),
		Font = Enum.Font.GothamBlack,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = REBIRTH_COLOR:Lerp(Color3.new(1, 1, 1), 0.35),
		Text = "Renaissance",
		MaxTextSize = 26,
		Parent = window,
	})
	UI.label({
		Position = UDim2.new(0, 0, 0, 32),
		Size = UDim2.new(1, 0, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.Muted,
		Text = "Recommence une run à la vague 1 et gagne un bonus de pièces permanent",
		MaxTextSize = 14,
		Parent = window,
	})
	local closeButton = UI.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(32, 32),
		BackgroundColor3 = UI.Colors.PanelLight,
		Text = "X",
		MaxTextSize = 18,
		Parent = window,
	})

	-- Chiffres : meilleure vague de la run, gain, bonus total avant -> après.
	local stats = UI.new("Frame", {
		Position = UDim2.new(0, 0, 0, 60),
		Size = UDim2.new(1, 0, 0, 110),
		BackgroundColor3 = UI.Colors.Background,
		Parent = window,
	}, {
		UI.corner(12),
		UI.padding(10),
		UI.new("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	UI.stroke(REBIRTH_COLOR, 2).Parent = stats

	local function statRow(order: number, text: string): TextLabel
		local row = UI.new("Frame", {
			Size = UDim2.new(1, 0, 0, 28),
			LayoutOrder = order,
			BackgroundTransparency = 1,
			Parent = stats,
		})
		UI.label({
			Size = UDim2.new(0.5, 0, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = UI.Colors.Muted,
			Text = text,
			MaxTextSize = 16,
			Parent = row,
		})
		return UI.label({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 0),
			Size = UDim2.new(0.5, 0, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Right,
			Font = Enum.Font.GothamBold,
			RichText = true,
			MaxTextSize = 20,
			Parent = row,
		})
	end
	local bestWaveValue = statRow(1, "Meilleure vague de la run")
	local gainValue = statRow(2, "Gain de la renaissance")
	local totalValue = statRow(3, "Bonus de pièces total")

	-- Exemple concret (ou, si la renaissance n'est pas encore possible, ce qu'il faut faire).
	local exampleLabel = UI.label({
		Position = UDim2.new(0, 0, 0, 178),
		Size = UDim2.new(1, 0, 0, 36),
		TextXAlignment = Enum.TextXAlignment.Left,
		RichText = true,
		MaxTextSize = 15,
		Parent = window,
	})

	-- Ce qui est gardé
	UI.label({
		Position = UDim2.new(0, 0, 0, 222),
		Size = UDim2.new(1, 0, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamBold,
		Text = "Tu gardes tout le reste :",
		MaxTextSize = 15,
		Parent = window,
	})
	local keptGrid = UI.new("Frame", {
		Position = UDim2.new(0, 0, 0, 244),
		Size = UDim2.new(1, 0, 0, 62),
		BackgroundTransparency = 1,
		Parent = window,
	}, {
		UI.new("UIGridLayout", {
			CellSize = UDim2.new(1 / 3, -4, 0, 28),
			CellPadding = UDim2.fromOffset(6, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local recordChip = nil
	for order, text in { "Pièces", "Tours posées", "Améliorations", "Emplacements", "Machines et bonus", "Record" } do
		local chip = UI.new("Frame", {
			LayoutOrder = order,
			BackgroundColor3 = UI.Colors.Success,
			BackgroundTransparency = 0.82,
			Parent = keptGrid,
		}, { UI.corner(6) })
		local chipLabel = UI.label({
			Position = UDim2.new(0, 6, 0, 0),
			Size = UDim2.new(1, -12, 1, 0),
			TextColor3 = UI.Colors.Success:Lerp(Color3.new(1, 1, 1), 0.45),
			Font = Enum.Font.GothamBold,
			Text = "✓ " .. text,
			MaxTextSize = 14,
			Parent = chip,
		})
		if text == "Record" then
			recordChip = chipLabel
		end
	end

	UI.label({
		Position = UDim2.new(0, 0, 0, 314),
		Size = UDim2.new(1, 0, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.Warning,
		Font = Enum.Font.GothamBold,
		Text = "● Seule la vague repart à 1 (la vague en cours s'arrête)",
		MaxTextSize = 15,
		Parent = window,
	})

	local confirmButton = UI.button({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(0.6, -4, 0, 50),
		BackgroundColor3 = REBIRTH_COLOR,
		Text = "Renaître",
		MaxTextSize = 22,
		Parent = window,
	})
	local cancelButton = UI.button({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 1, 0),
		Size = UDim2.new(0.4, -4, 0, 50),
		BackgroundColor3 = UI.Colors.PanelLight,
		Text = "Annuler",
		MaxTextSize = 22,
		Parent = window,
	})

	------------------------------------------------------------------
	-- Flash plein écran quand une renaissance vient d'avoir lieu (Rebirths augmente).
	------------------------------------------------------------------
	local flash = UI.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = REBIRTH_COLOR,
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	local flashTitle = UI.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.new(0.8, 0, 0, 70),
		Font = Enum.Font.GothamBlack,
		TextStrokeTransparency = 0.2,
		Text = "RENAISSANCE !",
		MaxTextSize = 64,
		Parent = flash,
	})

	local function playFlash()
		flash.Visible = true
		flash.BackgroundTransparency = 0.5
		flashTitle.TextTransparency = 0
		flashTitle.TextStrokeTransparency = 0.2
		flashTitle.Position = UDim2.fromScale(0.5, 0.4)
		local info = TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(flashTitle, info, {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.34),
		}):Play()
		local tween = TweenService:Create(flash, info, { BackgroundTransparency = 1 })
		tween.Completed:Once(function(state)
			if state == Enum.PlaybackState.Completed then
				flash.Visible = false
			end
		end)
		tween:Play()
	end

	------------------------------------------------------------------
	-- Mise à jour
	------------------------------------------------------------------
	local function refreshButton()
		local bestWave, coinBonus = readPlot()
		local gain = IdleConfig.rebirthGain(bestWave)
		buttonBonus.Text = `Bonus pièces : +{percent(coinBonus)} %`
		if gain > 0 then
			button.BackgroundColor3 = REBIRTH_COLOR
			button.BackgroundTransparency = 0
			buttonTitle.Text = `Renaissance +{percent(gain)} %`
			buttonTitle.TextColor3 = Color3.new(1, 1, 1)
			buttonBonus.TextColor3 = Color3.fromRGB(255, 235, 200)
			buttonStroke.Enabled = true
		else
			-- Grisé tant que la vague minimale n'est pas réussie dans la run.
			button.BackgroundColor3 = UI.Colors.PanelLight
			button.BackgroundTransparency = 0.2
			buttonTitle.Text = `Renaissance : vague {minWave}`
			buttonTitle.TextColor3 = UI.Colors.Muted
			buttonBonus.TextColor3 = UI.Colors.Gold
			buttonStroke.Enabled = false
		end
		-- Téléphone : petit bouton, comme dans les autres jeux (demande du propriétaire) : « Renaissance » et, dessous,
		-- seulement son gain (ou la vague à réussir).
		if UI.touchLayout(UI.screenSize(buttonGui)) then
			buttonTitle.Text = "Renaissance"
			buttonBonus.Text = if gain > 0 then `+{percent(gain)} %` else `vague {minWave}`
		end
	end

	local function refreshWindow()
		local bestWave, coinBonus, highestWave = readPlot()
		local gain = IdleConfig.rebirthGain(bestWave)
		bestWaveValue.Text = `vague {bestWave}`
		if recordChip then
			recordChip.Text = `✓ Record : vague {highestWave}`
		end
		if gain > 0 then
			local after = IdleConfig.roundPercent(coinBonus + gain)
			gainValue.Text = `<font color="{GOLD_HEX}">+{percent(gain)} % de pièces</font>`
			totalValue.Text = `+{percent(coinBonus)} %  →  <font color="{GOLD_HEX}">+{percent(after)} %</font>`
			exampleLabel.Text = `Exemple : un ennemi qui vaut {EXAMPLE_REWARD} pièces en donnera `
				.. `<font color="{GOLD_HEX}"><b>{formatAmount(EXAMPLE_REWARD * (1 + after / 100))}</b></font>`
				.. ` au lieu de {formatAmount(EXAMPLE_REWARD * (1 + coinBonus / 100))}.`
			confirmButton.Text = "Renaître"
			confirmButton.BackgroundTransparency = 0
		else
			gainValue.Text = `<font color="{MUTED_HEX}">vague {minWave} requise</font>`
			totalValue.Text = `+{percent(coinBonus)} %`
			exampleLabel.Text = `Réussis la vague {minWave} pour renaître. Gain : +{percent(IdleConfig.rebirthGain(minWave))} % à la vague {minWave}, `
				.. `+{percent(IdleConfig.rebirthGain(50))} % à la 50, +{percent(IdleConfig.rebirthGain(100))} % à la 100, et plus au-delà.`
			confirmButton.Text = `Vague {minWave} requise`
			confirmButton.BackgroundTransparency = 0.6
		end
	end

	local function open()
		overlay.Visible = true
		refreshWindow()
	end
	local function close()
		overlay.Visible = false
	end

	button.Activated:Connect(open)
	closeButton.Activated:Connect(close)
	cancelButton.Activated:Connect(close)

	local lastConfirm = 0
	confirmButton.Activated:Connect(function()
		local bestWave = readPlot()
		if IdleConfig.rebirthGain(bestWave) <= 0 then
			return
		end
		-- Anti double-clic : le serveur refuserait de toute façon la 2e (vague repartie à 1).
		if os.clock() - lastConfirm < 1 then
			return
		end
		lastConfirm = os.clock()
		plotAction:FireServer("Rebirth")
		close()
	end)

	-- Détecte une renaissance réussie (Rebirths augmente) pour le flash.
	local lastRebirths = nil
	local function watchRebirths()
		local index = player:GetAttribute("Plot")
		local plot = index and plotsFolder:FindFirstChild("Plot" .. index)
		local rebirths = plot and plot:GetAttribute("Rebirths")
		if typeof(rebirths) ~= "number" then
			return
		end
		if lastRebirths and rebirths > lastRebirths then
			playFlash()
		end
		lastRebirths = rebirths
	end

	task.spawn(function()
		while gui.Parent do
			refreshButton()
			if overlay.Visible then
				refreshWindow()
			end
			watchRebirths()
			task.wait(0.25)
		end
	end)
end

return RebirthUI

-- HUD du match : vies des deux bases, or, vagues, boutiques de tours et d'envois, résultat.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Sends = require(Shared.Sends)
local Towers = require(Shared.Towers)
local UI = require(script.Parent.UI)

local MatchUI = {}

local REASONS = {
	BaseDestroyed = "Base détruite",
	BothDestroyed = "Les deux bases sont tombées en même temps",
	TimeLimit = "Temps écoulé : la base la plus solide l'emporte",
	Forfeit = "Abandon",
}

local OUTCOMES = {
	Win = { text = "VICTOIRE", color = UI.Colors.Success },
	Loss = { text = "DÉFAITE", color = UI.Colors.Error },
	Draw = { text = "ÉGALITÉ", color = UI.Colors.Warning },
	Cancelled = { text = "MATCH ANNULÉ", color = UI.Colors.Muted },
}

local function playerPanel(parent: Instance, anchorRight: boolean, accent: Color3)
	local panel = UI.new("Frame", {
		AnchorPoint = Vector2.new(if anchorRight then 1 else 0, 0),
		Position = if anchorRight then UDim2.new(1, -16, 0, 16) else UDim2.new(0, 16, 0, 16),
		Size = UDim2.new(0, 250, 0, 96),
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.1,
		Parent = parent,
	}, { UI.corner(12), UI.padding(10), UI.stroke(accent, 2) })

	local alignment = if anchorRight then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left
	local name = UI.label({
		Size = UDim2.new(1, 0, 0, 22),
		Font = Enum.Font.GothamBold,
		TextXAlignment = alignment,
		MaxTextSize = 20,
		Parent = panel,
	})
	local rank = UI.label({
		Position = UDim2.new(0, 0, 0, 22),
		Size = UDim2.new(1, 0, 0, 16),
		TextXAlignment = alignment,
		TextColor3 = UI.Colors.Muted,
		MaxTextSize = 14,
		Parent = panel,
	})
	local _, setHealth = UI.bar({
		Position = UDim2.new(0, 0, 0, 42),
		Size = UDim2.new(1, 0, 0, 14),
		Parent = panel,
	}, UI.Colors.Success)
	local info = UI.label({
		Position = UDim2.new(0, 0, 0, 58),
		Size = UDim2.new(1, 0, 0, 18),
		TextXAlignment = alignment,
		TextColor3 = UI.Colors.Gold,
		MaxTextSize = 16,
		Parent = panel,
	})
	return { name = name, rank = rank, setHealth = setHealth, info = info }
end

function MatchUI.start(TowerPlacement)
	local player = Players.LocalPlayer
	local matchState = ReplicatedStorage:WaitForChild("MatchState")
	local gui = UI.screen("Match")

	local function myLane(): number
		return player:GetAttribute("Lane") or 1
	end
	local function lane(index: number, key: string): any
		return matchState:GetAttribute(`Lane{index}{key}`)
	end

	-- Panneaux joueurs
	local me = playerPanel(gui, false, UI.Colors.Accent)
	local opponent = playerPanel(gui, true, UI.Colors.Error)

	-- Infos de vague (en haut au centre)
	local waveLabel = UI.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.new(0, 320, 0, 34),
		Font = Enum.Font.GothamBlack,
		MaxTextSize = 30,
		Parent = gui,
	})
	local timerLabel = UI.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 50),
		Size = UDim2.new(0, 320, 0, 20),
		TextColor3 = UI.Colors.Muted,
		MaxTextSize = 18,
		Parent = gui,
	})

	-- Boutique de tours (en bas au centre)
	local towerBar = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.new(0, 4 * 130 + 3 * 8, 0, 70),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local towerButtons = {}
	for index, towerType in Towers.ORDER do
		local def = Towers.Defs[towerType]
		local button = UI.button({
			Size = UDim2.new(0, 130, 1, 0),
			LayoutOrder = index,
			BackgroundColor3 = def.color,
			Text = `[{index}] {def.displayName}\n{def.levels[1].cost} or`,
			MaxTextSize = 18,
			Parent = towerBar,
		})
		button.Activated:Connect(function()
			TowerPlacement.startPlacing(towerType)
		end)
		towerButtons[towerType] = button
	end

	-- Envois chez l'adversaire (à droite)
	local sendPanel = UI.new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.new(0, 190, 0, 40 + #Sends.ORDER * 58),
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.1,
		Parent = gui,
	}, { UI.corner(12), UI.padding(8) })
	UI.label({
		Size = UDim2.new(1, 0, 0, 24),
		Font = Enum.Font.GothamBold,
		Text = "Envoyer à l'adversaire",
		MaxTextSize = 16,
		Parent = sendPanel,
	})
	local sendButtons = {}
	for index, sendId in Sends.ORDER do
		local button = UI.button({
			Position = UDim2.new(0, 0, 0, 28 + (index - 1) * 58),
			Size = UDim2.new(1, 0, 0, 52),
			BackgroundColor3 = UI.Colors.PanelLight,
			MaxTextSize = 15,
			Parent = sendPanel,
		})
		button.Activated:Connect(function()
			Remotes.get("SendEnemies"):FireServer(sendId)
		end)
		sendButtons[sendId] = button
	end

	-- Panneau de la tour sélectionnée (en bas à gauche)
	local towerPanel = UI.new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -92),
		Size = UDim2.new(0, 240, 0, 150),
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = gui,
	}, { UI.corner(12), UI.padding(10) })
	local towerTitle = UI.label({
		Size = UDim2.new(1, 0, 0, 24),
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 20,
		Parent = towerPanel,
	})
	local towerStats = UI.label({
		Position = UDim2.new(0, 0, 0, 26),
		Size = UDim2.new(1, 0, 0, 40),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = UI.Colors.Muted,
		TextWrapped = true,
		MaxTextSize = 14,
		Parent = towerPanel,
	})
	local upgradeButton = UI.button({
		Position = UDim2.new(0, 0, 1, -40),
		Size = UDim2.new(0.58, -4, 0, 40),
		BackgroundColor3 = UI.Colors.Success,
		MaxTextSize = 16,
		Parent = towerPanel,
	})
	local sellButton = UI.button({
		Position = UDim2.new(0.58, 4, 1, -40),
		Size = UDim2.new(0.42, -4, 0, 40),
		BackgroundColor3 = UI.Colors.Error,
		MaxTextSize = 16,
		Parent = towerPanel,
	})
	upgradeButton.Activated:Connect(TowerPlacement.upgradeSelected)
	sellButton.Activated:Connect(TowerPlacement.sellSelected)

	-- Overlay central (attente, compte à rebours, résultat)
	local overlay = UI.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Visible = false,
		ZIndex = 10,
		Parent = gui,
	})
	local overlayTitle = UI.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.4, 0),
		Size = UDim2.new(0.8, 0, 0, 90),
		Font = Enum.Font.GothamBlack,
		MaxTextSize = 80,
		ZIndex = 11,
		Parent = overlay,
	})
	local overlaySubtitle = UI.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.4, 55),
		Size = UDim2.new(0.8, 0, 0, 90),
		TextWrapped = true,
		MaxTextSize = 26,
		ZIndex = 11,
		Parent = overlay,
	})

	local result = nil
	Remotes.get("MatchResult").OnClientEvent:Connect(function(payload)
		result = payload
		TowerPlacement.cancel()
	end)

	local function showOverlay(title: string, subtitle: string, color: Color3?)
		overlay.Visible = true
		overlayTitle.Text = title
		overlayTitle.TextColor3 = color or UI.Colors.Text
		overlaySubtitle.Text = subtitle
	end

	local function resultSubtitle(): string
		local lines = {}
		if result.outcome == "Cancelled" then
			table.insert(lines, result.reason or "")
		else
			table.insert(lines, `{REASONS[result.reason] or result.reason} — contre {result.opponentName or "?"}`)
			if result.ranked then
				local delta = result.newMmr - result.oldMmr
				table.insert(lines, `MMR : {result.oldMmr} → {result.newMmr} ({if delta >= 0 then "+" else ""}{delta})`)
				if result.oldRank ~= result.newRank then
					table.insert(lines, `Nouveau rang : {result.newRank} !`)
				else
					table.insert(lines, `Rang : {result.newRank}`)
				end
			else
				table.insert(lines, "Match non classé")
			end
		end
		table.insert(lines, "Retour au lobby dans quelques secondes...")
		return table.concat(lines, "\n")
	end

	local function updatePanel(panel, index: number)
		local maxHealth = matchState:GetAttribute("BaseHealth") or 100
		local health = lane(index, "Health") or maxHealth
		panel.name.Text = lane(index, "Name") or "..."
		panel.rank.Text = if lane(index, "Mmr") then `{lane(index, "Rank")} • {lane(index, "Mmr")} MMR` else ""
		panel.setHealth(health / maxHealth)
		panel.info.Text = `♥ {health}/{maxHealth}    Or {lane(index, "Gold") or 0}  (+{lane(index, "Income") or 0}/vague)`
	end

	local function update()
		local now = workspace:GetServerTimeNow()
		local phase = matchState:GetAttribute("Phase")
		local mine, theirs = myLane(), if myLane() == 1 then 2 else 1
		local gold = lane(mine, "Gold") or 0
		local wave = matchState:GetAttribute("Wave") or 0

		updatePanel(me, mine)
		updatePanel(opponent, theirs)

		-- Vague / chronos
		waveLabel.Text = if wave > 0 then `Vague {wave}` else "Préparation"
		local nextWaveAt = matchState:GetAttribute("NextWaveAt")
		local startedAt = matchState:GetAttribute("StartedAt")
		if phase == "Playing" and nextWaveAt and startedAt then
			local remaining = (matchState:GetAttribute("MaxDuration") or 0) - (now - startedAt)
			timerLabel.Text = `Prochaine vague : {math.max(0, math.ceil(nextWaveAt - now))}s   •   Fin : {UI.formatTime(remaining)}`
		else
			timerLabel.Text = ""
		end

		-- Boutique : grise ce qui est trop cher
		local placing = TowerPlacement.getPlacingType()
		for towerType, button in towerButtons do
			local affordable = gold >= Towers.Defs[towerType].levels[1].cost
			button.BackgroundTransparency = if affordable then 0 else 0.6
			local stroke = button:FindFirstChild("Selected")
			if placing == towerType and not stroke then
				UI.new("UIStroke", { Name = "Selected", Color = Color3.new(1, 1, 1), Thickness = 3, Parent = button })
			elseif placing ~= towerType and stroke then
				stroke:Destroy()
			end
		end
		for sendId, button in sendButtons do
			local def = Sends.Defs[sendId]
			if wave < def.minWave then
				button.Text = `{def.displayName} — vague {def.minWave}`
				button.BackgroundTransparency = 0.6
			else
				button.Text = `{def.displayName} x{def.count}\n{def.cost} or • +{def.income}/vague`
				button.BackgroundTransparency = if gold >= def.cost then 0 else 0.6
			end
		end

		-- Tour sélectionnée
		local selected = TowerPlacement.getSelected()
		if selected and selected.Parent then
			local towerType = selected:GetAttribute("TowerType")
			local level = selected:GetAttribute("Level") or 1
			local def = Towers.Defs[towerType]
			local stats = Towers.stats(towerType, level)
			local upgradeCost = Towers.upgradeCost(towerType, level)
			towerPanel.Visible = true
			towerTitle.Text = `{def.displayName} — niv. {level}/{Towers.maxLevel(towerType)}`
			towerStats.Text = `Dégâts {stats.damage} • Portée {stats.range} • Cadence {stats.cooldown}s\n{def.description}`
			upgradeButton.Text = if upgradeCost then `Améliorer [E]\n{upgradeCost} or` else "Niveau max"
			upgradeButton.BackgroundTransparency = if upgradeCost and gold >= upgradeCost then 0 else 0.6
			local refund = math.floor(Towers.totalCost(towerType, level) * Config.Match.SELL_REFUND)
			sellButton.Text = `Vendre [X]\n+{refund} or`
		else
			towerPanel.Visible = false
		end

		-- Overlay
		if result then
			local style = OUTCOMES[result.outcome] or OUTCOMES.Cancelled
			showOverlay(style.text, resultSubtitle(), style.color)
		elseif phase == "Waiting" then
			showOverlay("En attente", "Connexion de ton adversaire...")
		elseif phase == "Countdown" then
			local endsAt = matchState:GetAttribute("CountdownEndsAt") or now
			local ranked = matchState:GetAttribute("Ranked")
			showOverlay(tostring(math.max(1, math.ceil(endsAt - now))), if ranked then "Match classé" else "Match non classé (test)")
		elseif phase == "Cancelled" then
			showOverlay("MATCH ANNULÉ", "Retour au lobby...", UI.Colors.Muted)
		else
			overlay.Visible = false
		end
	end

	task.spawn(function()
		while gui.Parent do
			update()
			task.wait(0.1)
		end
	end)
end

return MatchUI

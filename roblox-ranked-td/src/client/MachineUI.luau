-- Fenêtres des deux machines à sous (tours et bonus), avec les chances affichées et une
-- petite animation de rouleau. S'ouvrent via les machines de ta parcelle ou les boutons en haut à droite.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local IdleConfig = require(Shared.IdleConfig)
local IdleTowers = require(Shared.IdleTowers)
local NumberFormat = require(Shared.NumberFormat)
local Remotes = require(Shared.Remotes)
local UI = require(script.Parent.UI)

local MachineUI = {}

local function listAttribute(player: Player, name: string): { string }
	local raw = player:GetAttribute(name)
	if typeof(raw) ~= "string" or raw == "" then
		return {}
	end
	return string.split(raw, ",")
end

local function formatChance(chance: number): string
	if chance >= 1 then
		return string.format("%g %%", chance)
	end
	return string.format("%.1f %%", chance)
end

function MachineUI.start()
	local player = Players.LocalPlayer
	local machineAction = Remotes.get("MachineAction")
	local plotsFolder = workspace:WaitForChild("Hub"):WaitForChild("Plots")
	local gui = UI.screen("Machines", 20)

	local function highestWave(): number
		local index = player:GetAttribute("Plot")
		local plot = index and plotsFolder:FindFirstChild("Plot" .. index)
		return plot and plot:GetAttribute("HighestWave") or 1
	end

	------------------------------------------------------------------
	-- Boutons dans la colonne de gauche, sous « Ma base » et « Cercle ranked » (LobbyUI).
	-- En haut à droite, ils seraient cachés par la liste des joueurs de Roblox.
	------------------------------------------------------------------
	local towerShortcut = UI.button({
		Position = UDim2.new(0, 16, 0, UI.LEFT_COLUMN_TOP + 2 * UI.LEFT_COLUMN_STEP),
		Size = UDim2.fromOffset(180, 46),
		BackgroundColor3 = IdleConfig.RARITIES.Epic.color,
		Text = "🎰 Machine à tours",
		MaxTextSize = 18,
		Parent = gui,
	})
	local bonusShortcut = UI.button({
		Position = UDim2.new(0, 16, 0, UI.LEFT_COLUMN_TOP + 3 * UI.LEFT_COLUMN_STEP),
		Size = UDim2.fromOffset(180, 46),
		BackgroundColor3 = IdleConfig.RARITIES.Legendary.color,
		Text = "🎰 Machine à bonus",
		MaxTextSize = 18,
		Parent = gui,
	})

	------------------------------------------------------------------
	-- Fenêtre commune aux deux machines
	------------------------------------------------------------------
	local overlay = UI.new("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.5,
		AutoButtonColor = false,
		Text = "",
		Visible = false,
		Parent = gui,
	})
	local window = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(540, 470),
		BackgroundColor3 = UI.Colors.Panel,
		Parent = overlay,
	}, { UI.corner(16), UI.padding(14), UI.new("UISizeConstraint", { MaxSize = Vector2.new(540, 470) }) })
	local windowStroke = UI.stroke(Color3.new(1, 1, 1), 3)
	windowStroke.Transparency = 0
	windowStroke.Parent = window

	local title = UI.label({
		Size = UDim2.new(1, -40, 0, 30),
		Font = Enum.Font.GothamBlack,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 26,
		Parent = window,
	})
	local subtitle = UI.label({
		Position = UDim2.new(0, 0, 0, 32),
		Size = UDim2.new(1, 0, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.Muted,
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

	-- Tableau des chances
	local oddsList = UI.new("Frame", {
		Position = UDim2.new(0, 0, 0, 58),
		Size = UDim2.new(1, 0, 0, 176),
		BackgroundTransparency = 1,
		Parent = window,
	}, {
		UI.new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	-- Rouleau (résultat)
	local reel = UI.new("Frame", {
		Position = UDim2.new(0, 0, 0, 244),
		Size = UDim2.new(1, 0, 0, 96),
		BackgroundColor3 = UI.Colors.Background,
		Parent = window,
	}, { UI.corner(12) })
	local reelStroke = UI.stroke(Color3.new(1, 1, 1), 2)
	reelStroke.Parent = reel
	local reelText = UI.label({
		Position = UDim2.new(0, 0, 0, 10),
		Size = UDim2.new(1, 0, 0, 44),
		Font = Enum.Font.GothamBlack,
		MaxTextSize = 36,
		Text = "?",
		Parent = reel,
	})
	local reelDetail = UI.label({
		Position = UDim2.new(0, 0, 0, 58),
		Size = UDim2.new(1, 0, 0, 26),
		TextColor3 = UI.Colors.Muted,
		MaxTextSize = 16,
		Text = "",
		Parent = reel,
	})

	local primaryButton = UI.button({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -34),
		Size = UDim2.new(1, 0, 0, 50),
		BackgroundColor3 = UI.Colors.Success,
		MaxTextSize = 22,
		Parent = window,
	})
	local robuxButton = UI.button({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 1, -34),
		Size = UDim2.new(0.4, -4, 0, 50),
		BackgroundColor3 = Color3.fromRGB(0, 176, 111),
		Text = "Lancer • Robux",
		MaxTextSize = 20,
		Visible = false,
		Parent = window,
	})
	local footer = UI.label({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 26),
		TextColor3 = UI.Colors.Muted,
		MaxTextSize = 14,
		Parent = window,
	})

	local current: string? = nil -- "Tower" | "Bonus"
	local spinning = false
	local oddsKey = nil

	local function oddsRow(order: number, color: Color3, left: string, right: string)
		local row = UI.new("Frame", {
			Size = UDim2.new(1, 0, 0, 20),
			LayoutOrder = order,
			BackgroundColor3 = color,
			BackgroundTransparency = 0.8,
			Parent = oddsList,
		}, { UI.corner(4) })
		UI.label({
			Position = UDim2.new(0, 8, 0, 0),
			Size = UDim2.new(0.8, -8, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.3),
			RichText = true,
			Text = left,
			MaxTextSize = 14,
			Parent = row,
		})
		UI.label({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 0),
			Size = UDim2.new(0.2, 0, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Right,
			Font = Enum.Font.GothamBold,
			Text = right,
			MaxTextSize = 14,
			Parent = row,
		})
	end

	local function rebuildOdds(key: string, build: () -> ())
		if oddsKey == key then
			return
		end
		oddsKey = key
		for _, child in oddsList:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		build()
	end

	local function refresh()
		if not current then
			return
		end
		if current == "Tower" then
			local pending = player:GetAttribute("TowerSpinTier") or 0
			local tier = if pending > 0 then pending else IdleConfig.towerSpinTier(highestWave())
			local tierInfo = IdleConfig.TOWER_SPIN_TIERS[tier]
			local unlocked = {}
			for _, towerType in listAttribute(player, "UnlockedTowers") do
				unlocked[towerType] = true
			end
			title.Text = "🎰 Machine à tours"
			windowStroke.Color = IdleConfig.RARITIES.Epic.color
			subtitle.Text = `1 lancer gratuit à chaque vague réussie (sans cumul) • palier : vague {tierInfo.minWave}+`

			local unlockedKey = player:GetAttribute("UnlockedTowers") or ""
			rebuildOdds(`Tower:{tier}:{unlockedKey}`, function()
				for order, rarity in IdleConfig.RARITY_ORDER do
					local info = IdleConfig.RARITIES[rarity]
					local names = {}
					for _, towerType in IdleTowers.ofRarity(rarity) do
						local mark = if unlocked[towerType] then " ✓" else ""
						table.insert(names, IdleTowers.Defs[towerType].displayName .. mark)
					end
					oddsRow(order, info.color, `<b>{info.displayName}</b>  {table.concat(names, ", ")}`, formatChance(tierInfo.odds[rarity] or 0))
				end
			end)

			robuxButton.Visible = false
			primaryButton.Size = UDim2.new(1, 0, 0, 50)
			if pending > 0 then
				primaryButton.Text = "LANCER (gratuit)"
				primaryButton.BackgroundTransparency = if spinning then 0.6 else 0
			else
				primaryButton.Text = "Passe une vague pour gagner un lancer"
				primaryButton.BackgroundTransparency = 0.6
			end
			footer.Text = "Doublon = +5 % de dégâts permanents pour cette tour  •  ✓ = déjà débloquée"
		else
			local bonuses = listAttribute(player, "Bonuses")
			local cost = IdleConfig.bonusSpinCost(highestWave())
			local waitLeft = (player:GetAttribute("LastBonusSpinAt") or 0) + IdleConfig.BONUS_SPIN_COOLDOWN - workspace:GetServerTimeNow()
			title.Text = "🎰 Machine à bonus"
			windowStroke.Color = IdleConfig.RARITIES.Legendary.color
			subtitle.Text = "Le bonus va dans ton inventaire : clique sur une tour pour le poser (1 bonus par tour)"

			rebuildOdds("Bonus", function()
				for order, bonus in IdleConfig.BONUSES do
					local color = if bonus.chance >= 10
						then IdleConfig.RARITIES.Common.color
						elseif bonus.chance >= 5 then IdleConfig.RARITIES.Rare.color
						elseif bonus.chance >= 1 then IdleConfig.RARITIES.Epic.color
						else IdleConfig.RARITIES.Legendary.color
					oddsRow(order, color, `<b>{bonus.displayName}</b>`, formatChance(bonus.chance))
				end
			end)

			robuxButton.Visible = true
			primaryButton.Size = UDim2.new(0.6, -4, 0, 50)
			if waitLeft > 0 then
				primaryButton.Text = `En pièces dans {UI.formatTime(waitLeft)}`
				primaryButton.BackgroundTransparency = 0.6
			else
				primaryButton.Text = `Lancer • {NumberFormat.short(cost)} pièces`
				local affordable = (player:GetAttribute("Coins") or 0) >= cost
				primaryButton.BackgroundTransparency = if affordable and not spinning then 0 else 0.6
			end
			footer.Text = `Inventaire : {#bonuses} bonus  •  1 lancer en pièces toutes les 30 min, en Robux à volonté`
		end
	end

	local function open(machine: string)
		if current ~= machine then
			oddsKey = nil
			reelText.Text = "?"
			reelText.TextColor3 = UI.Colors.Text
			reelDetail.Text = ""
		end
		current = machine
		overlay.Visible = true
		refresh()
	end

	local function close()
		if spinning then
			return
		end
		current = nil
		overlay.Visible = false
	end

	closeButton.Activated:Connect(close)
	towerShortcut.Activated:Connect(function()
		open("Tower")
	end)
	bonusShortcut.Activated:Connect(function()
		open("Bonus")
	end)
	Remotes.get("OpenMachine").OnClientEvent:Connect(open)

	primaryButton.Activated:Connect(function()
		if spinning then
			return
		end
		if current == "Tower" then
			machineAction:FireServer("SpinTower")
		elseif current == "Bonus" then
			machineAction:FireServer("SpinBonusCoins")
		end
	end)
	robuxButton.Activated:Connect(function()
		if Config.Products.BONUS_SPIN == 0 then
			UI.toast("L'achat en Robux n'est pas encore configuré (Config.Products.BONUS_SPIN)", "Warning")
			return
		end
		MarketplaceService:PromptProductPurchase(player, Config.Products.BONUS_SPIN)
	end)

	-- Animation du rouleau puis affichage du résultat.
	Remotes.get("MachineResult").OnClientEvent:Connect(function(result)
		open(result.machine)
		spinning = true

		local names, colors = {}, {}
		if result.machine == "Tower" then
			for _, towerType in IdleTowers.ORDER do
				local def = IdleTowers.Defs[towerType]
				table.insert(names, def.displayName)
				table.insert(colors, IdleConfig.RARITIES[def.rarity].color)
			end
		else
			for _, bonus in IdleConfig.BONUSES do
				table.insert(names, bonus.displayName)
				table.insert(colors, UI.Colors.Gold)
			end
		end

		reelDetail.Text = ""
		local delay = 0.04
		for step = 1, 22 do
			local index = (step % #names) + 1
			reelText.Text = names[index]
			reelText.TextColor3 = colors[index]
			task.wait(delay)
			delay *= 1.12
		end

		if result.machine == "Tower" then
			local def = IdleTowers.Defs[result.tower]
			local rarity = IdleConfig.RARITIES[result.rarity]
			reelText.Text = def.displayName
			reelText.TextColor3 = rarity.color
			reelStroke.Color = rarity.color
			if result.isNew then
				reelDetail.Text = `NOUVELLE TOUR {string.upper(rarity.displayName)} ! Tu peux la poser sur tes emplacements.`
				UI.toast(`Nouvelle tour : {def.displayName} !`, "Success")
			else
				reelDetail.Text = `Doublon : +{math.floor(result.dupes * IdleConfig.DUPLICATE_DAMAGE_BONUS * 100 + 0.5)} % de dégâts pour tes {def.displayName}`
			end
		else
			local bonus = IdleConfig.BONUS_BY_ID[result.bonus]
			reelText.Text = bonus.displayName
			reelText.TextColor3 = UI.Colors.Gold
			reelStroke.Color = UI.Colors.Gold
			reelDetail.Text = "Ajouté à ton inventaire : clique sur une tour pour le poser."
		end
		spinning = false
		refresh()
	end)

	task.spawn(function()
		while gui.Parent do
			local ready = (player:GetAttribute("TowerSpinTier") or 0) > 0
			towerShortcut.Text = if ready then "🎰 1 lancer gratuit !" else "🎰 Machine à tours"
			towerShortcut.BackgroundTransparency = if ready then 0 else 0.3
			if current then
				refresh()
			end
			task.wait(0.25)
		end
	end)
end

return MachineUI

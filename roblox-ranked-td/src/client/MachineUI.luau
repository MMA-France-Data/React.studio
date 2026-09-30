-- Fenêtres des deux machines à sous (tours et bonus), avec les chances affichées.
-- Autel des héros : invocations payées en pièces, par 1, 10, 100... (IdleConfig.TOWER_SPIN_BULKS, les gros
-- lots se débloquent avec ton record), aux chances du palier de ton RECORD (IdleConfig.towerSpinTier) :
-- exactement celles affichées. x1 = petite animation de rouleau, les gros lots = résumé par tour.
-- Chaque lancer acheté rend le suivant 0,05 % plus cher, pour toujours : les prix des boutons viennent de
-- IdleConfig.towerSpinCost avec le compteur publié par le serveur (attribut TowerSpinsBought du joueur).
-- Un prix trop grand pour être compté affiche « MAX » (bouton grisé) ; le serveur refuse cet achat.
-- Forge runique : plus de délai d'attente. Prix du prochain lancer en pièces = IdleConfig.forgeCoinPrice avec
-- le compteur publié par le serveur (attribut ForgeSpinsBought du joueur : 100 K, puis x5, puis x2 dès 1 T,
-- jamais remis à zéro). Chaque tour a 2 emplacements de rune qui se cumulent : dégâts et vitesse. Seules les
-- runes qui améliorent une tour posée DANS L'EMPLACEMENT DE LEUR SORTE peuvent tomber (attribut ForgeDrawable,
-- chances remises sur 100 % avec IdleConfig.forgeOdds) : les autres sont barrées (« toutes tes tours l'ont
-- déjà »). Forge bloquée (attribut ForgeBlocked : « Pose d'abord une tour » / « Toutes tes tours ont les
-- meilleures runes », x100 dégâts ET x2 vitesse partout) : les boutons pièces ET Robux affichent le message et
-- n'achètent rien (pas de fenêtre d'achat Robux). Si un reçu Robux arrive quand même (ex. tour vendue pendant
-- l'achat), le serveur donne la meilleure rune : un achat payé n'est jamais perdu (PlotGame:grantBonusSpin).
-- S'ouvrent via les machines de ta parcelle ou les boutons de la colonne de gauche.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local IdleConfig = require(Shared.IdleConfig)
local IdleTowers = require(Shared.IdleTowers)
local NumberFormat = require(Shared.NumberFormat)
local Remotes = require(Shared.Remotes)
local SoundManager = require(script.Parent.SoundManager)
local UI = require(script.Parent.UI)

local MachineUI = {}

-- Fanfare (son « RareFanfare ») : tour légendaire à l'autel, ou rune au moins x50 dégâts à la forge.
local FANFARE_RARITY = "Legendary"
local FANFARE_RUNE_MULT = 50

-- Au plus ce temps sans réponse du serveur après un achat : les boutons restent bloqués pendant ce
-- temps (un double clic n'achète jamais deux fois).
local RESULT_TIMEOUT = 3

-- Taille de la fenêtre sur un écran d'ordinateur. Sur un téléphone, elle est réduite pour tenir entière,
-- boutons x1, x10... compris (UI.fitWindow).
local WINDOW_SIZE = Vector2.new(540, 490)

local function listAttribute(player: Player, name: string): { string }
	local raw = player:GetAttribute(name)
	if typeof(raw) ~= "string" or raw == "" then
		return {}
	end
	return string.split(raw, ",")
end

local function formatChance(chance: number): string
	if chance >= 1 or chance == 0 then
		return string.format("%g %%", chance)
	end
	return string.format("%.1f %%", chance)
end

-- Bonus de dégâts de `dupes` doublons, en % arrondi (sans l'arrondi, 29 doublons affichaient +57 %
-- au lieu de +58 %, à cause des virgules des calculs).
local function dupesPercent(dupes: number): string
	return NumberFormat.short(math.floor(dupes * IdleConfig.DUPLICATE_DAMAGE_BONUS * 100 + 0.5))
end

-- Quantité d'un bouton d'invocation : 10 -> "x10", 10000 -> "x10000", 1000000 -> "x1M".
local function countLabel(count: number): string
	return "x" .. (if count < 100000 then string.format("%d", count) else NumberFormat.short(count))
end

-- Hausse du prix à chaque lancer acheté, en % : 1,0005 -> "0,05".
local GROWTH_PERCENT = (
	string.gsub(string.format("%g", math.floor((IdleConfig.TOWER_SPIN_PRICE_GROWTH - 1) * 1e5 + 0.5) / 1e3), "%.", ",")
)

function MachineUI.start()
	local player = Players.LocalPlayer
	local machineAction = Remotes.get("MachineAction")
	local plotsFolder = workspace:WaitForChild("Hub"):WaitForChild("Plots")
	local gui = UI.screen("Machines", 20)

	-- Record de tous les temps (attribut HighestWave de la parcelle) : il décide des chances et des
	-- quantités d'invocations proposées.
	local function highestWave(): number
		local index = player:GetAttribute("Plot")
		local plot = index and plotsFolder:FindFirstChild("Plot" .. index)
		return plot and plot:GetAttribute("HighestWave") or 1
	end
	local function coins(): number
		return player:GetAttribute("Coins") or 0
	end
	-- Lancers de l'autel déjà achetés (publiés par le serveur) : ils décident du prix des prochains.
	local function spinsBought(): number
		return IdleConfig.cleanSpinsBought(player:GetAttribute("TowerSpinsBought"))
	end
	-- Forge : lancers en pièces déjà achetés (attribut ForgeSpinsBought) et prix du prochain (math.huge = MAX).
	local function forgeBought(): number
		return IdleConfig.cleanSpinsBought(player:GetAttribute("ForgeSpinsBought"))
	end
	local function forgePrice(): number
		return IdleConfig.forgeCoinPrice(forgeBought())
	end
	-- Forge : runes tirables maintenant (attribut ForgeDrawable, ids séparés par des virgules ; nil = pas encore
	-- publié) et raison du blocage (attribut ForgeBlocked, nil = la forge marche).
	local function forgeState(): ({ any }?, string?)
		local blocked = player:GetAttribute("ForgeBlocked")
		local raw = player:GetAttribute("ForgeDrawable")
		local drawable = nil
		if typeof(raw) == "string" then
			drawable = {}
			for _, id in string.split(raw, ",") do
				local bonus = IdleConfig.BONUS_BY_ID[id]
				if bonus then
					table.insert(drawable, bonus)
				end
			end
		end
		return drawable, if typeof(blocked) == "string" and blocked ~= "" then blocked else nil
	end

	------------------------------------------------------------------
	-- Boutons en haut de la colonne de gauche, sous le panneau de rang (LobbyUI).
	-- En haut à droite, ils seraient cachés par la liste des joueurs de Roblox.
	------------------------------------------------------------------
	local towerShortcut = UI.button({
		Position = UDim2.new(0, 16, 0, UI.LEFT_COLUMN_TOP + 0 * UI.LEFT_COLUMN_STEP),
		Size = UDim2.fromOffset(180, 46),
		BackgroundColor3 = IdleConfig.RARITIES.Epic.color,
		BackgroundTransparency = 0.3,
		Text = "AUTEL DES HÉROS",
		MaxTextSize = 18,
		Parent = gui,
	})
	local bonusShortcut = UI.button({
		Position = UDim2.new(0, 16, 0, UI.LEFT_COLUMN_TOP + 1 * UI.LEFT_COLUMN_STEP),
		Size = UDim2.fromOffset(180, 46),
		BackgroundColor3 = IdleConfig.RARITIES.Legendary.color,
		Text = "FORGE RUNIQUE",
		MaxTextSize = 18,
		Parent = gui,
	})
	-- Écran trop bas (téléphone) : toute la colonne est réduite pour tenir (UI.leftColumnSlot).
	UI.placeInLeftColumn(towerShortcut, 0)
	UI.placeInLeftColumn(bonusShortcut, 1)

	------------------------------------------------------------------
	-- Fenêtre commune aux deux machines
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
	}, { UI.corner(16), UI.padding(14), UI.new("UISizeConstraint", { MaxSize = WINDOW_SIZE }) })
	local windowStroke = UI.stroke(Color3.new(1, 1, 1), 3)
	windowStroke.Transparency = 0
	windowStroke.Parent = window
	-- Petit écran (téléphone) : toute la fenêtre est réduite pour tenir sous la barre du haut de Roblox.
	UI.fitWindow(window, WINDOW_SIZE)

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

	-- Autel des héros : hausse des prix et nombre de lancers déjà achetés, sous les 4 raretés.
	local spinInfo = UI.label({
		Position = UDim2.new(0, 0, 0, 148),
		Size = UDim2.new(1, 0, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.Muted,
		MaxTextSize = 14,
		Visible = false,
		Parent = window,
	})

	-- Rouleau (résultat d'un lancer) ou résumé (gros lot d'invocations)
	local reel = UI.new("Frame", {
		Position = UDim2.new(0, 0, 0, 244),
		Size = UDim2.new(1, 0, 0, 96),
		BackgroundColor3 = UI.Colors.Background,
		Parent = window,
	}, { UI.corner(12) })
	local reelStroke = UI.stroke(Color3.new(1, 1, 1), 2)
	reelStroke.Parent = reel
	local reelText = UI.label({
		Font = Enum.Font.GothamBlack,
		MaxTextSize = 36,
		Text = "?",
		Parent = reel,
	})
	local reelTextSize = reelText:FindFirstChildOfClass("UITextSizeConstraint") :: UITextSizeConstraint
	local reelDetail = UI.label({
		TextColor3 = UI.Colors.Muted,
		MaxTextSize = 16,
		Text = "",
		Parent = reel,
	})
	-- Résumé : une case par tour obtenue (2 colonnes, 8 tours au plus), de la plus rare à la plus commune.
	local summaryGrid = UI.new("Frame", {
		Position = UDim2.new(0, 8, 0, 60),
		Size = UDim2.new(1, -16, 1, -66),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = reel,
	}, {
		UI.new("UIGridLayout", {
			CellSize = UDim2.new(0.5, -3, 0, 30),
			CellPadding = UDim2.fromOffset(6, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
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
	-- Autel des héros : un bouton par quantité (x1, x10, x100...) débloquée par le record.
	local bulkRow = UI.new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -34),
		Size = UDim2.new(1, 0, 0, 50),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = window,
	}, {
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
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
	local awaitingUntil = 0 -- achat envoyé, résultat pas encore reçu
	local oddsKey = nil

	local function busy(): boolean
		return spinning or os.clock() < awaitingUntil
	end

	-- Placement du rouleau : sous les 4 raretés et la ligne des prix pour l'autel (plus haut, pour le
	-- résumé), sous les 8 runes et la ligne des prix pour la forge.
	local function layoutReel(machine: string?)
		spinInfo.Visible = machine ~= nil
		if machine == "Tower" then
			spinInfo.Position = UDim2.new(0, 0, 0, 148)
			reel.Position = UDim2.new(0, 0, 0, 172)
			reel.Size = UDim2.new(1, 0, 1, -264)
		else
			spinInfo.Position = UDim2.new(0, 0, 0, 236)
			reel.Position = UDim2.new(0, 0, 0, 258)
			reel.Size = UDim2.new(1, 0, 0, 90)
		end
	end

	-- Rouleau classique : un nom au centre et une ligne de détail.
	local function showSingle()
		summaryGrid.Visible = false
		reelText.Position = UDim2.new(0, 0, 0.5, -38)
		reelText.Size = UDim2.new(1, 0, 0, 44)
		reelTextSize.MaxTextSize = 36
		reelDetail.Position = UDim2.new(0, 0, 0.5, 10)
		reelDetail.Size = UDim2.new(1, 0, 0, 26)
	end
	showSingle()

	local function clearSummary()
		for _, child in summaryGrid:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end

	-- Résumé d'un gros lot : titre, total des doublons, puis une case par tour
	-- (nouvelle tour en doré, doublons et bonus de dégâts gagnés).
	local function showSummary(result)
		clearSummary()
		reelText.Position = UDim2.new(0, 0, 0, 6)
		reelText.Size = UDim2.new(1, 0, 0, 30)
		reelDetail.Position = UDim2.new(0, 0, 0, 38)
		reelDetail.Size = UDim2.new(1, 0, 0, 18)
		summaryGrid.Visible = true

		local newCount, totalDupes = 0, 0
		local bestColor = Color3.new(1, 1, 1)
		for order, entry in result.results do
			local def = IdleTowers.Defs[entry.tower]
			local rarity = IdleConfig.RARITIES[entry.rarity]
			if not def or not rarity then
				continue
			end
			if order == 1 then
				bestColor = rarity.color
			end
			local obtained = tonumber(entry.count) or 0
			local dupes = obtained - (if entry.isNew then 1 else 0)
			totalDupes += dupes
			if entry.isNew then
				newCount += 1
				UI.toast(`Nouvelle tour : {def.displayName} !`, "Success")
			end

			local cell = UI.new("Frame", {
				LayoutOrder = order,
				BackgroundColor3 = rarity.color,
				BackgroundTransparency = if entry.isNew then 0.55 else 0.8,
				Parent = summaryGrid,
			}, { UI.corner(6) })
			if entry.isNew then
				local stroke = UI.stroke(UI.Colors.Gold, 2)
				stroke.Transparency = 0
				stroke.Parent = cell
			end
			UI.label({
				Position = UDim2.new(0, 6, 0, 1),
				Size = UDim2.new(0.66, -6, 0, 16),
				TextXAlignment = Enum.TextXAlignment.Left,
				Font = Enum.Font.GothamBold,
				TextColor3 = rarity.color:Lerp(Color3.new(1, 1, 1), 0.45),
				Text = def.displayName,
				MaxTextSize = 14,
				Parent = cell,
			})
			UI.label({
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -6, 0, 1),
				Size = UDim2.new(0.34, -6, 0, 16),
				TextXAlignment = Enum.TextXAlignment.Right,
				Font = Enum.Font.GothamBlack,
				Text = `×{NumberFormat.short(obtained)}`,
				MaxTextSize = 14,
				Parent = cell,
			})
			local bonusText = `+{dupesPercent(dupes)} % de dégâts`
			UI.label({
				Position = UDim2.new(0, 6, 0, 16),
				Size = UDim2.new(1, -12, 0, 13),
				TextXAlignment = Enum.TextXAlignment.Left,
				Font = if entry.isNew then Enum.Font.GothamBlack else Enum.Font.GothamMedium,
				TextColor3 = if entry.isNew then UI.Colors.Gold else UI.Colors.Text,
				Text = if entry.isNew
					then (if dupes > 0 then `NOUVELLE TOUR ! + {NumberFormat.short(dupes)} doublons` else "NOUVELLE TOUR !")
					else `{NumberFormat.short(dupes)} doublons • {bonusText}`,
				MaxTextSize = 12,
				Parent = cell,
			})
		end

		local quantity = countLabel(tonumber(result.count) or 0)
		if result.source == "Challenge" then
			quantity ..= " offerts" -- lancers gratuits d'un défi classé (Hub/ChallengeRewards.luau)
		end
		reelTextSize.MaxTextSize = 26
		reelText.TextColor3 = bestColor
		reelStroke.Color = bestColor
		reelText.Text = if newCount == 1
			then `{quantity} • 1 NOUVELLE TOUR !`
			elseif newCount > 1 then `{quantity} • {newCount} NOUVELLES TOURS !`
			else `{quantity} • que des doublons`
		reelDetail.Text = `{NumberFormat.short(totalDupes)} doublons au total • chacun = +{math.floor(IdleConfig.DUPLICATE_DAMAGE_BONUS * 100 + 0.5)} % de dégâts pour sa tour`
	end

	-- dimmed = ligne grisée (rune qui ne peut pas tomber dans la forge).
	local function oddsRow(order: number, color: Color3, left: string, right: string, dimmed: boolean?)
		local row = UI.new("Frame", {
			Size = UDim2.new(1, 0, 0, 20),
			LayoutOrder = order,
			BackgroundColor3 = color,
			BackgroundTransparency = if dimmed then 0.94 else 0.8,
			Parent = oddsList,
		}, { UI.corner(4) })
		UI.label({
			Position = UDim2.new(0, 8, 0, 0),
			Size = UDim2.new(0.8, -8, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = if dimmed then UI.Colors.Muted else color:Lerp(Color3.new(1, 1, 1), 0.3),
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
			TextColor3 = if dimmed then UI.Colors.Muted else UI.Colors.Text,
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

	-- Boutons d'invocation : ceux que le record débloque, puis la prochaine quantité verrouillée (grisée).
	local bulkKey = nil
	local bulkButtons = {} -- { { count, button } }
	local function buySpins(count: number)
		if busy() then
			return
		end
		-- Même calcul que le serveur (qui recalcule tout avec ses propres données avant d'accepter).
		local cost = IdleConfig.towerSpinCost(highestWave(), count, spinsBought())
		if cost >= math.huge then
			UI.toast(`Prix trop élevé (MAX) : impossible de lancer {countLabel(count)} d'un coup`, "Error")
			return
		end
		if coins() < cost then
			UI.toast(`Il te faut {NumberFormat.price(cost)} pièces pour {countLabel(count)}`, "Error")
			return
		end
		awaitingUntil = os.clock() + RESULT_TIMEOUT
		machineAction:FireServer("SpinTower", count)
	end
	local function rebuildBulkRow(highest: number)
		local available, locked = {}, nil
		for _, bulk in IdleConfig.TOWER_SPIN_BULKS do
			if highest >= bulk.minWave then
				table.insert(available, bulk)
			elseif not locked then
				locked = bulk
			end
		end
		local key = `{#available}:{locked and locked.count}`
		if key == bulkKey then
			return
		end
		bulkKey = key
		table.clear(bulkButtons)
		for _, child in bulkRow:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end

		local slots = #available + (if locked then 1 else 0)
		local width = UDim2.new(1 / slots, -6 * (slots - 1) / slots, 1, 0)
		for order, bulk in available do
			local button = UI.button({
				Size = width,
				LayoutOrder = order,
				BackgroundColor3 = UI.Colors.Success,
				MaxTextSize = 20,
				Parent = bulkRow,
			})
			button.Activated:Connect(function()
				buySpins(bulk.count)
			end)
			table.insert(bulkButtons, { count = bulk.count, button = button })
		end
		if locked then
			local lockedLabel = UI.label({
				Size = width,
				LayoutOrder = #available + 1,
				BackgroundColor3 = UI.Colors.PanelLight,
				BackgroundTransparency = 0.5,
				TextColor3 = UI.Colors.Muted,
				Font = Enum.Font.GothamBold,
				Text = `{countLabel(locked.count)}\n🔒 vague {locked.minWave}`,
				MaxTextSize = 16,
				Parent = bulkRow,
			})
			UI.corner(6).Parent = lockedLabel
		end
	end

	local function refresh()
		if not current then
			return
		end
		if current == "Tower" then
			local highest = highestWave()
			local tier = IdleConfig.towerSpinTier(highest)
			local tierInfo = IdleConfig.TOWER_SPIN_TIERS[tier]
			local nextTier = IdleConfig.TOWER_SPIN_TIERS[tier + 1]
			local unlocked = {}
			for _, towerType in listAttribute(player, "UnlockedTowers") do
				unlocked[towerType] = true
			end
			title.Text = "AUTEL DES HÉROS"
			windowStroke.Color = IdleConfig.RARITIES.Epic.color
			subtitle.Text = `Chances de ton record (vague {highest})`
				.. (if nextTier then `  •  meilleures dès la vague {nextTier.minWave}` else "  •  meilleur palier atteint")

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
			primaryButton.Visible = false
			bulkRow.Visible = true
			rebuildBulkRow(highest)
			local wallet = coins()
			local bought = spinsBought()
			for _, entry in bulkButtons do
				-- Prix exact : somme des prochains prix (« MAX » = trop grand, jamais payable).
				local cost = IdleConfig.towerSpinCost(highest, entry.count, bought)
				entry.button.Text = `{countLabel(entry.count)}\n💰 {NumberFormat.price(cost)}`
				entry.button.BackgroundTransparency = if cost < math.huge and wallet >= cost and not busy() then 0 else 0.6
			end
			local boughtText = if bought == 0
				then "aucun lancer acheté"
				elseif bought == 1 then "déjà 1 lancer"
				else `déjà {NumberFormat.short(bought)} lancers`
			spinInfo.Text = `Prochain lancer : +{GROWTH_PERCENT} % à chaque achat  •  {boughtText}`
			footer.Text = `Doublon = +{math.floor(IdleConfig.DUPLICATE_DAMAGE_BONUS * 100 + 0.5)} % de dégâts permanents pour cette tour  •  ✓ = déjà débloquée`
		else
			local bonuses = listAttribute(player, "Bonuses")
			local price = forgePrice()
			local bought = forgeBought()
			local drawable, blocked = forgeState()
			title.Text = "FORGE RUNIQUE"
			windowStroke.Color = IdleConfig.RARITIES.Legendary.color
			subtitle.Text = "Ne tombent que les runes utiles à une tour posée • 2 runes par tour : dégâts + vitesse"

			-- Chances : celles des runes tirables, remises sur 100 % ; les autres barrées. Pas encore publié
			-- ou aucune tour posée : les chances de base.
			local drawableKey = player:GetAttribute("ForgeDrawable")
			rebuildOdds(`Bonus:{drawableKey}:{blocked}`, function()
				local odds = if drawable and #drawable > 0 then IdleConfig.forgeOdds(drawable) else nil
				for order, bonus in IdleConfig.BONUSES do
					local color = if bonus.chance >= 10
						then IdleConfig.RARITIES.Common.color
						elseif bonus.chance >= 5 then IdleConfig.RARITIES.Rare.color
						elseif bonus.chance >= 1 then IdleConfig.RARITIES.Epic.color
						else IdleConfig.RARITIES.Legendary.color
					-- Le Sorcier des arcanes n'a pas de coups : la rune de vitesse fait chauffer son rayon plus vite.
					local note = if bonus.kind == "Speed" then `  (rayon du Sorcier : chauffe {bonus.mult}x plus vite)` else ""
					if odds and not odds[bonus.id] then
						-- Toutes les tours posées ont déjà, dans l'emplacement de cette sorte, une rune au moins aussi
						-- forte (les runes de dégâts et de vitesse ne se comparent jamais entre elles).
						oddsRow(order, color, `<s>{bonus.displayName}</s>  toutes tes tours l'ont déjà (ou mieux)`, "—", true)
					elseif odds then
						oddsRow(order, color, `<b>{bonus.displayName}</b>{note}`, formatChance(odds[bonus.id]))
					else
						oddsRow(order, color, `<b>{bonus.displayName}</b>{note}`, formatChance(bonus.chance), blocked ~= nil)
					end
				end
			end)

			local boughtText = if bought == 0
				then "aucun lancer en pièces"
				elseif bought == 1 then "déjà 1 lancer en pièces"
				else `déjà {NumberFormat.short(bought)} lancers en pièces`
			spinInfo.Text = `Chaque lancer en pièces : x{IdleConfig.FORGE_FAST_GROWTH} (x{IdleConfig.FORGE_SLOW_GROWTH} dès {NumberFormat.short(IdleConfig.FORGE_GROWTH_SWITCH)})  •  {boughtText}`

			bulkRow.Visible = false
			primaryButton.Visible = true
			robuxButton.Visible = true
			primaryButton.Size = UDim2.new(0.6, -4, 0, 50)
			local full = #bonuses >= IdleConfig.MAX_BONUS_INVENTORY
			if blocked then
				-- Aucune rune n'améliorerait une tour : pièces ET Robux bloqués.
				primaryButton.Text = blocked
				primaryButton.BackgroundTransparency = 0.6
			elseif full then
				primaryButton.Text = `Inventaire plein ({IdleConfig.MAX_BONUS_INVENTORY} runes)`
				primaryButton.BackgroundTransparency = 0.6
			else
				primaryButton.Text = `Lancer • 💰 {NumberFormat.price(price)}`
				primaryButton.BackgroundTransparency = if price < math.huge and coins() >= price and not busy() then 0 else 0.6
			end
			robuxButton.BackgroundTransparency = if blocked then 0.6 else 0
			footer.Text = `Inventaire : {#bonuses} rune{if #bonuses > 1 then "s" else ""}  •  en Robux à volonté, sans hausse de prix`
		end
	end

	local function open(machine: string)
		if current ~= machine then
			oddsKey = nil
			layoutReel(machine)
			showSingle()
			reelText.Text = "?"
			reelText.TextColor3 = UI.Colors.Text
			reelStroke.Color = Color3.new(1, 1, 1)
			reelDetail.Text = ""
		end
		current = machine
		overlay.Visible = true
		-- Machine ouverte ("Tower" | "Bonus", rien = fermée), par l'invite ou par un bouton de gauche : lue par le tuto
		-- (TutorialUI.luau, étape « la forge »).
		gui:SetAttribute("OpenMachine", machine)
		refresh()
	end

	local function close()
		if spinning then
			return
		end
		current = nil
		overlay.Visible = false
		gui:SetAttribute("OpenMachine", nil)
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
		if busy() then
			return
		end
		if current == "Bonus" then
			-- Mêmes vérifications que le serveur (qui recalcule tout avec ses propres données).
			local _, blocked = forgeState()
			if blocked then
				UI.toast(blocked, "Warning")
				return
			end
			if #listAttribute(player, "Bonuses") >= IdleConfig.MAX_BONUS_INVENTORY then
				UI.toast("Ton inventaire de runes est plein : pose-en sur tes tours", "Error")
				return
			end
			local price = forgePrice()
			if price >= math.huge then
				UI.toast("Prix trop élevé (MAX) : la forge en pièces n'est plus possible", "Error")
				return
			end
			if coins() < price then
				UI.toast(`Il te faut {NumberFormat.price(price)} pièces`, "Error")
				return
			end
			awaitingUntil = os.clock() + RESULT_TIMEOUT
			machineAction:FireServer("SpinBonusCoins")
		end
	end)
	robuxButton.Activated:Connect(function()
		-- Forge bloquée (aucune rune n'améliorerait une tour) : pas de fenêtre d'achat. Si un reçu arrive quand
		-- même, le serveur donne la meilleure rune (un achat payé n'est jamais perdu).
		local _, blocked = forgeState()
		if blocked then
			UI.toast(blocked, "Warning")
			return
		end
		if Config.Products.BONUS_SPIN == 0 then
			UI.toast("L'achat en Robux n'est pas encore configuré (Config.Products.BONUS_SPIN)", "Warning")
			return
		end
		MarketplaceService:PromptProductPurchase(player, Config.Products.BONUS_SPIN)
	end)

	-- Résultat : animation du rouleau (1 lancer) ou résumé (gros lot d'invocations).
	Remotes.get("MachineResult").OnClientEvent:Connect(function(result)
		awaitingUntil = 0
		if typeof(result) ~= "table" then
			return
		end
		open(result.machine)
		if result.machine == "Tower" and (tonumber(result.count) or 1) > 1 and typeof(result.results) == "table" then
			-- Gros lot : son de l'autel, puis la fanfare s'il y a au moins une tour légendaire.
			SoundManager.play("AltarSpin")
			for _, entry in result.results do
				if typeof(entry) == "table" and entry.rarity == FANFARE_RARITY then
					task.delay(0.4, SoundManager.play, "RareFanfare")
					break
				end
			end
			showSummary(result)
			refresh()
			return
		end

		spinning = true
		showSingle()
		SoundManager.play(if result.machine == "Tower" then "AltarSpin" else "ForgeSpin")
		local names, colors = {}, {}
		if result.machine == "Tower" then
			for _, towerType in IdleTowers.ORDER do
				local def = IdleTowers.Defs[towerType]
				table.insert(names, def.displayName)
				table.insert(colors, IdleConfig.RARITIES[def.rarity].color)
			end
		else
			-- Le rouleau ne fait défiler que les runes qui pouvaient tomber.
			local drawable = forgeState()
			for _, bonus in (if drawable and #drawable > 0 then drawable else IdleConfig.BONUSES) do
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
				-- Ce que fait la tour (feu, rayon, petite zone... voir IdleTowers.luau).
				reelDetail.Text = `NOUVELLE TOUR {string.upper(rarity.displayName)} ! {def.description}`
				UI.toast(`Nouvelle tour : {def.displayName} !`, "Success")
			else
				reelDetail.Text = `Doublon : +{dupesPercent(tonumber(result.dupes) or 0)} % de dégâts pour tes {def.displayName}`
			end
			if result.rarity == FANFARE_RARITY then
				SoundManager.play("RareFanfare")
			end
		else
			local bonus = IdleConfig.BONUS_BY_ID[result.bonus]
			if bonus and bonus.kind == "Damage" and bonus.mult >= FANFARE_RUNE_MULT then
				SoundManager.play("RareFanfare")
			end
			reelText.Text = if bonus then bonus.displayName else "?"
			reelText.TextColor3 = UI.Colors.Gold
			reelStroke.Color = UI.Colors.Gold
			reelDetail.Text = if result.source == "Challenge"
				then "Offerte par un défi classé : ajoutée à ton inventaire, clique sur une tour pour la poser."
				else "Ajoutée à ton inventaire : clique sur une tour pour la poser."
		end
		spinning = false
		refresh()
	end)

	task.spawn(function()
		while gui.Parent do
			if current then
				refresh()
			end
			task.wait(0.25)
		end
	end)
end

return MachineUI

-- Boutique (passes de jeu du mode infini) et message « Pendant ton absence : +X » au retour.
--
-- Boutique : bouton « BOUTIQUE » dans la colonne de gauche (index 3, sous « Renaissance »). La fenêtre
-- montre les trois passes de jeu (Config.GamePasses : Ramassage auto, Vitesse x2, Pièces x2) :
--   ID à 0 (pas encore créé) -> « Bientôt disponible », aucun achat proposé
--   déjà possédé             -> « Possédé » (et, pour la Vitesse x2, le bouton activée / désactivée)
--   sinon                    -> « Acheter » : fenêtre d'achat de Roblox (PromptGamePassPurchase)
-- Le client ne décide rien : le serveur vérifie la possession (UserOwnsGamePassAsync) et la publie dans
-- les attributs du joueur PassAutoCollect, PassSpeedX2, PassCoinsX2 et SpeedX2Enabled. Ces passes ne
-- servent qu'au mode infini : le match ranked reste identique pour tout le monde (mêmes tours, même or).
--
-- Vitesse x2 : un petit bouton à droite du compteur de pièces (en haut de l'écran) l'active ou la coupe
-- (PassAction "ToggleSpeed" ; le serveur revérifie que le pass est possédé). Il n'apparaît qu'avec le pass.
--
-- Gains hors ligne : au retour (après une absence ou un match classé), le serveur envoie OfflineGains
-- { amount, seconds, kind = "Offline" | "Match", capped, matchAmount, matchSeconds, offlineAmount,
-- offlineSeconds, coinFactor } (Remotes.luau, Hub/init.luau). Les pièces sont déjà ajoutées par le
-- serveur (doublées avec le pass Pièces x2, coinFactor = 2) : cette fenêtre ne fait que l'annoncer
-- (ShopUI.showOfflineGains, branchée dans Main.client).
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local IdleConfig = require(Shared.IdleConfig)
local NumberFormat = require(Shared.NumberFormat)
local Remotes = require(Shared.Remotes)
local UI = require(script.Parent.UI)

local ShopUI = {}

local ROBUX_GREEN = Color3.fromRGB(0, 176, 111) -- même vert que le bouton Robux de la forge (MachineUI)
local SPEED_COLOR = Color3.fromRGB(70, 130, 210)
local COINS_COLOR = Color3.fromRGB(235, 140, 45)
local DARK_TEXT = Color3.fromRGB(30, 25, 10)
-- 3 cartes côte à côte (~256 px chacune). Réduite sur les petits écrans (UI.fitWindow).
local WINDOW_SIZE = Vector2.new(820, 400)
-- Message « Pendant ton absence » : sa taille, et son centre un peu au-dessus du milieu de l'écran.
local OFFLINE_SIZE = Vector2.new(460, 270)
local OFFLINE_CENTER = Vector2.new(0.5, 0.45)
local PROMPT_COOLDOWN = 1 -- secondes entre deux fenêtres d'achat (un double clic n'en ouvre qu'une)
local TOGGLE_COOLDOWN = 0.5 -- secondes entre deux changements de vitesse
-- Limite par défaut des gains hors ligne (en runs complètes par jour), si IdleConfig n'en donne pas.
local DEFAULT_OFFLINE_RUNS = 3
-- Retour d'un match classé : la part « hors ligne » n'est détaillée qu'au-delà de 5 min (en dessous, ce
-- n'est que le temps de la téléportation).
local SPLIT_OFFLINE_SECONDS = 5 * 60
-- Absence hors ligne de moins d'1 min (ex. rejoindre un autre serveur) : un simple message en haut de
-- l'écran au lieu de la grande fenêtre.
local MIN_PANEL_SECONDS = 60

-- Les trois passes de jeu. key = nom dans Config.GamePasses, attribute = attribut du joueur publié par le
-- serveur (true quand le pass est possédé).
local PASSES = {
	{
		key = "AUTO_COLLECT",
		attribute = "PassAutoCollect",
		icon = "→",
		name = "Ramassage auto",
		description = "Les pièces tombées sur ta parcelle arrivent toutes seules dans ta bourse, même quand tu es loin.",
		color = UI.Colors.Gold,
	},
	{
		key = "SPEED_X2",
		attribute = "PassSpeedX2",
		icon = "★",
		name = "Vitesse x2",
		description = "Ta parcelle joue 2 fois plus vite : ennemis, apparitions, tirs des tours et pauses entre les vagues. Tu peux la couper à tout moment.",
		color = SPEED_COLOR,
	},
	{
		key = "COINS_X2",
		attribute = "PassCoinsX2",
		icon = "💰",
		name = "Pièces x2",
		description = "Toutes les pièces gagnées sur ta parcelle sont doublées, même hors ligne.",
		color = COINS_COLOR,
	},
}

-- ID du pass dans Config.GamePasses (0 = pas encore créé dans le Creator Dashboard).
local function passId(key: string): number
	local passes = (Config :: any).GamePasses
	local id = if typeof(passes) == "table" then tonumber(passes[key]) else nil
	if not id or id ~= id or id <= 0 then
		return 0
	end
	return math.floor(id)
end

-- Remote PassAction, cherché au premier clic (s'il manque, seul ce bouton ne marche pas).
local passActionRemote = nil
local function firePassAction(action: string)
	if not passActionRemote then
		local ok, remote = pcall(Remotes.get, "PassAction")
		if not ok then
			warn("[ShopUI] Remote PassAction introuvable :", remote)
			return
		end
		passActionRemote = remote
	end
	passActionRemote:FireServer(action)
end

----------------------------------------------------------------------
-- Boutique
----------------------------------------------------------------------

function ShopUI.start()
	local player = Players.LocalPlayer
	local plotsFolder = workspace:WaitForChild("Hub"):WaitForChild("Plots")
	-- Le bouton a son propre ScreenGui (ordre 0, comme LobbyUI et le bouton Renaissance) : il reste sous
	-- le voile sombre des autres fenêtres. La fenêtre passe au-dessus des machines (20) et de la
	-- renaissance (21).
	local buttonGui = UI.screen("ShopButton")
	local gui = UI.screen("Shop", 22)

	local function owns(pass): boolean
		return player:GetAttribute(pass.attribute) == true
	end
	local function speedEnabled(): boolean
		return player:GetAttribute("SpeedX2Enabled") == true
	end

	------------------------------------------------------------------
	-- Bouton de la colonne de gauche (index 3, sous « Renaissance »)
	------------------------------------------------------------------
	local shopButton = UI.button({
		Position = UDim2.new(0, 16, 0, UI.LEFT_COLUMN_TOP + 3 * UI.LEFT_COLUMN_STEP),
		Size = UDim2.fromOffset(180, 46),
		BackgroundColor3 = UI.Colors.Gold,
		TextColor3 = DARK_TEXT,
		Text = "★ BOUTIQUE",
		MaxTextSize = 18,
		Parent = buttonGui,
	})
	-- Écran trop bas (téléphone) : toute la colonne est réduite pour tenir (UI.leftColumnSlot).
	UI.placeInLeftColumn(shopButton, 3)

	------------------------------------------------------------------
	-- Bouton Vitesse x2 (visible seulement avec le pass) : sur la ligne du compteur de pièces de PlotUI, juste
	-- à sa droite (compteur centré, 360 px de large). Avant, il était sous ce compteur, à droite du panneau de
	-- la vague, retiré depuis (la vague est sur le tableau « CHRONIQUES DU FIEF »).
	------------------------------------------------------------------
	local speedButton = UI.button({
		Position = UDim2.new(0.5, 188, 0, 9),
		Size = UDim2.fromOffset(84, 44),
		BackgroundColor3 = SPEED_COLOR,
		Text = "",
		Visible = false,
		Parent = buttonGui,
	})
	local speedTitle = UI.label({
		Size = UDim2.new(1, 0, 0, 19),
		Font = Enum.Font.GothamBlack,
		MaxTextSize = 18,
		Parent = speedButton,
	})
	UI.label({
		Position = UDim2.new(0, 0, 0, 20),
		Size = UDim2.new(1, 0, 0, 12),
		Text = "Vitesse",
		MaxTextSize = 11,
		Parent = speedButton,
	})

	------------------------------------------------------------------
	-- Fenêtre de la boutique (même style que les machines, MachineUI)
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
	local windowStroke = UI.stroke(UI.Colors.Gold, 3)
	windowStroke.Transparency = 0
	windowStroke.Parent = window
	-- Réduit la fenêtre sur les petits écrans (téléphones). Avant, elle se basait sur l'écran entier, barre du haut
	-- de Roblox comprise : sur un téléphone, son haut (et le « X ») passait sous cette barre.
	UI.fitWindow(window, WINDOW_SIZE)

	UI.label({
		Size = UDim2.new(1, -40, 0, 30),
		Font = Enum.Font.GothamBlack,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.Gold,
		Text = "Boutique",
		MaxTextSize = 26,
		Parent = window,
	})
	UI.label({
		Position = UDim2.new(0, 0, 0, 32),
		Size = UDim2.new(1, 0, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.Muted,
		Text = "Passes du mode infini : aucun effet en ranked (mêmes tours et même or pour tous)",
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

	local cardRow = UI.new("Frame", {
		Position = UDim2.new(0, 0, 0, 60),
		Size = UDim2.new(1, 0, 1, -60),
		BackgroundTransparency = 1,
		Parent = window,
	}, {
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local prices = {} -- [id du pass] = prix en Robux (lu une fois dans le Creator Dashboard)
	local lastPrompt = 0
	local lastToggle = 0
	local cards = {}

	local function toggleSpeed()
		if player:GetAttribute("PassSpeedX2") ~= true or os.clock() - lastToggle < TOGGLE_COOLDOWN then
			return
		end
		lastToggle = os.clock()
		firePassAction("ToggleSpeed")
	end

	for order, pass in PASSES do
		-- Un tiers de la rangée chacune, moins sa part des 2 espaces de 12 px.
		local card = UI.new("Frame", {
			Size = UDim2.new(1 / #PASSES, -12 * (#PASSES - 1) / #PASSES, 1, 0),
			LayoutOrder = order,
			BackgroundColor3 = pass.color:Lerp(UI.Colors.Background, 0.75),
			Parent = cardRow,
		}, { UI.corner(12), UI.padding(12) })
		local cardStroke = UI.stroke(pass.color, 2)
		cardStroke.Transparency = 0.2
		cardStroke.Parent = card

		UI.label({
			Size = UDim2.new(1, 0, 0, 30),
			Font = Enum.Font.GothamBlack,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = pass.color:Lerp(Color3.new(1, 1, 1), 0.35),
			Text = `{pass.icon} {pass.name}`,
			MaxTextSize = 22,
			Parent = card,
		})
		UI.label({
			Position = UDim2.new(0, 0, 0, 36),
			Size = UDim2.new(1, 0, 0, 96),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			Text = pass.description,
			MaxTextSize = 15,
			Parent = card,
		})
		UI.label({
			Position = UDim2.new(0, 0, 0, 136),
			Size = UDim2.new(1, 0, 0, 16),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = UI.Colors.Muted,
			Text = "Pass permanent • mode infini seulement",
			MaxTextSize = 13,
			Parent = card,
		})
		local priceLabel = UI.label({
			Position = UDim2.new(0, 0, 0, 156),
			Size = UDim2.new(1, 0, 0, 22),
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Enum.Font.GothamBold,
			TextColor3 = UI.Colors.Gold,
			Text = "",
			MaxTextSize = 18,
			Parent = card,
		})

		-- Vitesse x2 possédée : le même interrupteur que le bouton à côté de la vague.
		local toggle = nil
		if pass.key == "SPEED_X2" then
			toggle = UI.button({
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 0, 1, -54),
				Size = UDim2.new(1, 0, 0, 40),
				BackgroundColor3 = SPEED_COLOR,
				MaxTextSize = 17,
				Visible = false,
				Parent = card,
			})
			toggle.Activated:Connect(toggleSpeed)
		end

		local buyButton = UI.button({
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, 0),
			Size = UDim2.new(1, 0, 0, 46),
			BackgroundColor3 = ROBUX_GREEN,
			MaxTextSize = 20,
			Parent = card,
		})
		buyButton.Activated:Connect(function()
			if owns(pass) then
				return
			end
			local id = passId(pass.key)
			if id == 0 then
				UI.toast(`{pass.name} : bientôt disponible !`, "Warning")
				return
			end
			if os.clock() - lastPrompt < PROMPT_COOLDOWN then
				return
			end
			lastPrompt = os.clock()
			local ok, err = pcall(function()
				MarketplaceService:PromptGamePassPurchase(player, id)
			end)
			if not ok then
				warn("[ShopUI] Achat impossible :", err)
				UI.toast("Achat impossible pour l'instant, réessaie plus tard", "Error")
			end
		end)

		table.insert(cards, { pass = pass, price = priceLabel, buy = buyButton, toggle = toggle })
	end

	local function refreshWindow()
		for _, card in cards do
			local pass = card.pass
			local id = passId(pass.key)
			local owned = owns(pass)
			local price = prices[id]
			card.price.Text = if not owned and typeof(price) == "number" then `{NumberFormat.short(price)} Robux` else ""

			if owned then
				card.buy.Text = "✓ Possédé"
				card.buy.BackgroundColor3 = UI.Colors.Success
				card.buy.BackgroundTransparency = 0.25
				card.buy.AutoButtonColor = false
			elseif id == 0 then
				card.buy.Text = "Bientôt disponible"
				card.buy.BackgroundColor3 = UI.Colors.PanelLight
				card.buy.BackgroundTransparency = 0.3
				card.buy.AutoButtonColor = false
			else
				card.buy.Text = if typeof(price) == "number" then `Acheter • {NumberFormat.short(price)} Robux` else "Acheter"
				card.buy.BackgroundColor3 = ROBUX_GREEN
				card.buy.BackgroundTransparency = 0
				card.buy.AutoButtonColor = true
			end

			if card.toggle then
				local enabled = speedEnabled()
				card.toggle.Visible = owned
				card.toggle.Text = if enabled then "Vitesse x2 : ACTIVÉE" else "Vitesse x2 : coupée"
				card.toggle.BackgroundColor3 = if enabled then SPEED_COLOR else UI.Colors.PanelLight
			end
		end
	end

	-- Prix des passes (lus une fois dans le Creator Dashboard ; en cas d'échec, on réessaie à la
	-- prochaine ouverture). Sans prix, le bouton affiche juste « Acheter ».
	local function fetchPrices()
		for _, pass in PASSES do
			local id = passId(pass.key)
			if id == 0 or prices[id] ~= nil then
				continue
			end
			prices[id] = false -- en cours
			task.spawn(function()
				local ok, info = pcall(function()
					return MarketplaceService:GetProductInfo(id, Enum.InfoType.GamePass)
				end)
				if ok and typeof(info) == "table" and typeof(info.PriceInRobux) == "number" then
					prices[id] = info.PriceInRobux
				else
					prices[id] = nil
				end
				refreshWindow()
			end)
		end
	end

	local function open()
		overlay.Visible = true
		fetchPrices()
		refreshWindow()
	end
	local function close()
		overlay.Visible = false
	end
	shopButton.Activated:Connect(function()
		if overlay.Visible then
			close()
		else
			open()
		end
	end)
	closeButton.Activated:Connect(close)
	speedButton.Activated:Connect(toggleSpeed)

	------------------------------------------------------------------
	-- Mise à jour
	------------------------------------------------------------------
	local function refreshSpeedButton()
		local index = player:GetAttribute("Plot")
		local plot = index and plotsFolder:FindFirstChild("Plot" .. index)
		-- Seulement quand ma parcelle tourne (attribut Wave de son dossier, publié par le serveur).
		speedButton.Visible = player:GetAttribute("PassSpeedX2") == true and plot ~= nil and plot:GetAttribute("Wave") ~= nil
		local enabled = speedEnabled()
		speedTitle.Text = if enabled then "x2" else "x1"
		speedButton.BackgroundColor3 = if enabled then SPEED_COLOR else UI.Colors.PanelLight
	end

	-- Achat terminé : le serveur revérifie la possession, met à jour ces attributs (le pass marche tout de
	-- suite, sans rejoindre à nouveau) et affiche lui-même « Merci ! Pass ... activé » (Monetization.luau).
	for _, pass in PASSES do
		player:GetAttributeChangedSignal(pass.attribute):Connect(function()
			refreshWindow()
			refreshSpeedButton()
		end)
	end
	player:GetAttributeChangedSignal("SpeedX2Enabled"):Connect(function()
		refreshWindow()
		refreshSpeedButton()
	end)

	refreshWindow()
	task.spawn(function()
		while gui.Parent do
			refreshSpeedButton()
			task.wait(0.25)
		end
	end)
end

----------------------------------------------------------------------
-- Gains hors ligne : « Pendant ton absence : +X »
----------------------------------------------------------------------

-- 45 s -> « 45 s », 12 min -> « 12 min », 3 h 05 -> « 3 h 05 », 2 h pile -> « 2 h ».
local function formatDuration(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	if seconds < 60 then
		return `{seconds} s`
	end
	local minutes = seconds // 60
	if minutes < 60 then
		return `{minutes} min`
	end
	local hours, rest = minutes // 60, minutes % 60
	if rest == 0 then
		return `{hours} h`
	end
	return string.format("%d h %02d", hours, rest)
end

-- Heure locale (celle de l'ordinateur du joueur) de la remise à zéro de la limite : minuit UTC.
local function nextResetTime(): string
	local now = os.time()
	local utc = os.date("!*t", now)
	local left = 86400 - (utc.hour * 3600 + utc.min * 60 + utc.sec)
	local reset = os.date("*t", now + left)
	if reset.min == 0 then
		return `{reset.hour} h`
	end
	return string.format("%d h %02d", reset.hour, reset.min)
end

-- Nombre de runs complètes par jour (IdleConfig.OFFLINE_DAILY_RUNS, 3 sinon).
local function offlineDailyRuns(): number
	local value = (IdleConfig :: any).OFFLINE_DAILY_RUNS
	return if typeof(value) == "number" and value > 0 then value else DEFAULT_OFFLINE_RUNS
end

-- « au ralenti (20 % du rythme normal) » d'après IdleConfig.OFFLINE_RATE.
local function offlineRateText(): string
	local rate = (IdleConfig :: any).OFFLINE_RATE
	if typeof(rate) ~= "number" or rate ~= rate or rate <= 0 then
		return "au ralenti"
	end
	return `au ralenti ({math.floor(rate * 100 + 0.5)} % du rythme normal)`
end

-- Nombre reçu du serveur, rendu propre : fini et jamais négatif (0 sinon).
local function cleanNumber(value: any): number
	local number = tonumber(value)
	if not number or number ~= number or number == math.huge or number < 0 then
		return 0
	end
	return number
end

local offlinePanel = nil -- construit à la première annonce
local offlineQueue = {} -- annonces arrivées pendant qu'une autre est affichée
local showNextOffline: () -> ()

local function buildOfflinePanel()
	local gui = UI.screen("OfflineGains", 30)
	local overlay = UI.new("TextButton", {
		Name = "Overlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.55,
		AutoButtonColor = false,
		Text = "",
		Visible = false,
		Parent = gui,
	})
	local window = UI.new("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(OFFLINE_CENTER.X, OFFLINE_CENTER.Y),
		Size = UDim2.fromOffset(OFFLINE_SIZE.X, OFFLINE_SIZE.Y),
		BackgroundColor3 = UI.Colors.Panel,
		Parent = overlay,
	}, { UI.corner(16), UI.padding(16) })
	local stroke = UI.stroke(UI.Colors.Gold, 3)
	stroke.Transparency = 0
	stroke.Parent = window
	-- Échelle : petite animation à l'ouverture (displayOffline), jusqu'à la taille qui tient dans l'écran.
	local scale = UI.new("UIScale", { Name = "FitScale", Parent = window })

	local title = UI.label({
		Size = UDim2.new(1, 0, 0, 28),
		Font = Enum.Font.GothamBlack,
		Text = "Pendant ton absence :",
		MaxTextSize = 24,
		Parent = window,
	})
	local amount = UI.label({
		Position = UDim2.new(0, 0, 0, 32),
		Size = UDim2.new(1, 0, 0, 58),
		Font = Enum.Font.GothamBlack,
		TextColor3 = UI.Colors.Gold,
		TextStrokeTransparency = 0.4,
		MaxTextSize = 52,
		Parent = window,
	})
	local detail = UI.label({
		Position = UDim2.new(0, 0, 0, 96),
		Size = UDim2.new(1, 0, 0, 44),
		TextWrapped = true,
		RichText = true,
		MaxTextSize = 16,
		Parent = window,
	})
	local capLabel = UI.label({
		Position = UDim2.new(0, 0, 0, 144),
		Size = UDim2.new(1, 0, 0, 36),
		TextWrapped = true,
		Font = Enum.Font.GothamBold,
		TextColor3 = UI.Colors.Warning:Lerp(Color3.new(1, 1, 1), 0.25),
		MaxTextSize = 14,
		Parent = window,
	})
	local okButton = UI.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.new(0.55, 0, 0, 46),
		BackgroundColor3 = UI.Colors.Success,
		Text = "Continuer",
		MaxTextSize = 22,
		Parent = window,
	})

	local panel = {
		overlay = overlay,
		scale = scale,
		title = title,
		amount = amount,
		detail = detail,
		capLabel = capLabel,
		shownAt = 0,
		countUp = nil :: RBXScriptConnection?,
	}

	-- Taille qui tient dans l'écran de ce ScreenGui, sous la barre du haut de Roblox (UI.windowScale). Avant, elle se
	-- basait sur l'écran entier, barre comprise : sur un petit téléphone, le haut du message passait dessous.
	local function fitScale(): number
		return UI.windowScale(UI.screenSize(gui), OFFLINE_SIZE, OFFLINE_CENTER)
	end
	panel.fitScale = fitScale
	-- Écran qui change de taille pendant l'affichage (téléphone tourné) : la fenêtre suit.
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if overlay.Visible and gui.AbsoluteSize.X > 0 and gui.AbsoluteSize.Y > 0 then
			scale.Scale = fitScale()
		end
	end)

	function panel.close()
		if not overlay.Visible then
			return
		end
		if panel.countUp then
			panel.countUp:Disconnect()
			panel.countUp = nil
		end
		overlay.Visible = false
		showNextOffline()
	end
	okButton.Activated:Connect(function()
		-- Pas de fermeture par un clic parti juste avant l'apparition de la fenêtre.
		if os.clock() - panel.shownAt >= 0.4 then
			panel.close()
		end
	end)
	return panel
end

local function displayOffline(entry)
	if not offlinePanel then
		offlinePanel = buildOfflinePanel()
	end
	local panel = offlinePanel

	-- Pass Pièces x2 : les montants reçus sont déjà doublés, on le dit dans le titre.
	panel.title.Text = if entry.doubled then "Pendant ton absence (pièces x2) :" else "Pendant ton absence :"
	if entry.matchAmount > 0 and entry.offlineAmount > 0 and entry.offlineSeconds >= SPLIT_OFFLINE_SECONDS then
		-- Retour d'un match classé après un vrai passage hors ligne : les deux parts, chacune avec sa durée.
		panel.detail.Text = `⚔ Match classé ({formatDuration(entry.matchSeconds)}) : <b>+{NumberFormat.short(entry.matchAmount)}</b> au rythme normal`
			.. `\n🌙 Hors ligne ({formatDuration(entry.offlineSeconds)}) : <b>+{NumberFormat.short(entry.offlineAmount)}</b> au ralenti`
	elseif entry.kind == "Match" then
		-- (Les quelques secondes de téléportation, payées au ralenti, restent dans le total.)
		local matchSeconds = if entry.matchSeconds > 0 then entry.matchSeconds else entry.seconds
		panel.detail.Text = `Ta parcelle a continué de produire <b>au rythme normal</b> pendant ton match classé (<b>{formatDuration(matchSeconds)}</b>).`
	else
		panel.detail.Text = `Ta parcelle a continué de produire <b>{offlineRateText()}</b> pendant <b>{formatDuration(entry.seconds)}</b>.`
	end
	panel.capLabel.Text = if entry.capped
		then `⚠ Limite du jour atteinte : au plus {offlineDailyRuns()} runs complètes de gains hors ligne par jour. Remise à zéro à {nextResetTime()}.`
		else ""

	panel.overlay.Visible = true
	panel.shownAt = os.clock()
	local target = panel.fitScale()
	panel.scale.Scale = target * 0.8
	TweenService:Create(panel.scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = target }):Play()
	-- Taille finale assurée même si l'animation est coupée (ou si l'écran a été mesuré pendant qu'elle jouait).
	local openedAt = panel.shownAt
	task.delay(0.4, function()
		if panel.shownAt == openedAt and panel.overlay.Visible then
			panel.scale.Scale = panel.fitScale()
		end
	end)

	-- Le montant défile de 0 jusqu'au gain (en 1,2 s, de plus en plus lentement).
	if panel.countUp then
		panel.countUp:Disconnect()
	end
	local started = os.clock()
	panel.amount.Text = "💰 +0"
	panel.countUp = RunService.Heartbeat:Connect(function()
		local alpha = math.clamp((os.clock() - started) / 1.2, 0, 1)
		local eased = 1 - (1 - alpha) ^ 3
		panel.amount.Text = "💰 +" .. NumberFormat.short(entry.amount * eased)
		if alpha >= 1 and panel.countUp then
			panel.countUp:Disconnect()
			panel.countUp = nil
		end
	end)

	-- Se ferme tout seul au bout de 25 s (joueur absent de l'écran).
	local shownAt = panel.shownAt
	task.delay(25, function()
		if panel.shownAt == shownAt then
			panel.close()
		end
	end)
end

function showNextOffline()
	local entry = table.remove(offlineQueue, 1)
	if entry then
		displayOffline(entry)
	end
end

-- Appelée par Main.client quand le serveur envoie OfflineGains (format : Remotes.luau). Le serveur a déjà
-- ajouté les pièces : ici on ne fait qu'afficher (les valeurs abîmées comptent pour 0).
-- matchAmount / offlineAmount (facultatifs) : les deux parts quand on revient d'un match classé après
-- être passé hors ligne.
function ShopUI.showOfflineGains(payload: any)
	if typeof(payload) ~= "table" then
		return
	end
	local amount = cleanNumber(payload.amount)
	local entry = {
		amount = amount,
		seconds = cleanNumber(payload.seconds),
		kind = if payload.kind == "Match" then "Match" else "Offline",
		capped = payload.capped == true,
		matchAmount = cleanNumber(payload.matchAmount),
		matchSeconds = cleanNumber(payload.matchSeconds),
		offlineAmount = cleanNumber(payload.offlineAmount),
		offlineSeconds = cleanNumber(payload.offlineSeconds),
		doubled = cleanNumber(payload.coinFactor) > 1, -- pass Pièces x2
	}
	if amount <= 0 then
		-- Rien gagné : seulement un petit message si c'est à cause de la limite du jour.
		if entry.capped then
			UI.toast(`Pendant ton absence : +0 (limite du jour atteinte, remise à zéro à {nextResetTime()})`, "Warning")
		end
		return
	end
	if entry.kind == "Offline" and entry.seconds < MIN_PANEL_SECONDS then
		UI.toast(`Pendant ton absence : +{NumberFormat.short(amount)}{if entry.doubled then " (pièces x2)" else ""}`, "Success")
		return
	end
	table.insert(offlineQueue, entry)
	if not (offlinePanel and offlinePanel.overlay.Visible) then
		showNextOffline()
	end
end

return ShopUI

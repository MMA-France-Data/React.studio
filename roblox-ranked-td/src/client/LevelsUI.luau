-- NIVEAUX, côté client (prototype de la nouvelle formule : règles et chiffres dans Shared/Levels.luau, serveur :
-- Hub/LevelsService.luau). Deux écrans :
--   « Levels »   : le bouton « ⚔ NIVEAUX » de la map principale et sa fenêtre à 4 onglets : Niveaux (choisir un
--                  niveau), Boutique (tours à prix fixes, en pièces de niveau), Entraînement (emplacements du camp,
--                  XP et améliorations de chaque tour), Mes tours (l'inventaire et l'ordre de la barre rapide) ;
--   « LevelHud » : pendant un niveau. Vue d'en haut de la zone de combat (caméra réglée pour montrer toute la carte
--                  entre les bandeaux ; zoom avec la molette ou en pinçant, déplacement en glissant un doigt ou
--                  avec le clic droit / les flèches), or / vies / avancée du flot de monstres, barre rapide des
--                  tours, pose LIBRE (ordinateur : clic sur une tour de la barre, un aperçu vert ou rouge suit la
--                  souris avec sa portée, clic pour poser ; téléphone : appui sur la tour puis appui sur le terrain,
--                  ou glisser la tour depuis la barre ; la tour en main dit « ANNULER » : un appui dessus annule),
--                  « + » aux emplacements conseillés (on peut poser ailleurs), petit menu Améliorer / Vendre à côté
--                  de la tour touchée, bouton x2, écran de fin (Niveau suivant / Rejouer / Retour au camp).
-- Le client ne décide rien : il lit les attributs publiés par le serveur (du joueur : LevelsAccess, LevelsState,
-- LevelArena ; du dossier de sa zone : Level, State, Gold, Lives..., voir Remotes.luau) et envoie des demandes
-- (remote LevelAction). Les monstres, les tirs et les étiquettes des tours sont affichés par PlotRenderer, comme
-- pour une parcelle.
-- Pendant un niveau, le personnage reste sur la place : ses commandes sont coupées, les autres écrans du jeu sont
-- cachés, puis tout est remis au retour.
-- Visible seulement si le serveur donne l'accès (Config.LEVELS_ACCESS : le propriétaire, pour l'instant). Pas
-- encore traduit en anglais (écrans marqués NoTranslate) : à faire avant de l'ouvrir à tout le monde.
-- Tests automatiques (Studio seulement, un plugin ne peut pas cliquer) : l'attribut « TestAction » de chaque écran
-- lance les mêmes fonctions que les boutons et les appuis (voir testAction en bas du fichier).
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local IdleConfig = require(Shared.IdleConfig)
local IdleTowers = require(Shared.IdleTowers)
local Levels = require(Shared.Levels)
local NumberFormat = require(Shared.NumberFormat)
local ProximityLabel = require(Shared.ProximityLabel)
local Remotes = require(Shared.Remotes)
local CampMode = require(script.Parent.CampMode)
local CombatVFX = require(script.Parent.CombatVFX)
local PlotRenderer = require(script.Parent.PlotRenderer)
local SoundManager = require(script.Parent.SoundManager)
local UI = require(script.Parent.UI)

local LevelsUI = {}

local player = Players.LocalPlayer

local COIN = "🏅" -- pièces de niveau (gardées : boutique, camp)
local GOLD = "💰" -- or d'un niveau (repart du montant de départ à chaque niveau)
local SHORT_NAMES = {
	MachineGun = "Archer",
	Frost = "Totem",
	Bomb = "Catapulte",
	Tesla = "Mage",
	Rocket = "Baliste",
	Laser = "Sorcier",
	Chain = "Oracle",
	Orbital = "Trébuchet",
}
local ROLES = {
	MachineGun = "Tireur rapide à longue portée. Ta tour de base.",
	Frost = `Ralentit de {math.floor(Levels.towerStats("Frost", 1, 0).slow * 100 + 0.5)} % tout ce qui passe près de lui.`,
	Bomb = "Ses rochers écrasent les groupes serrés.",
	Tesla = "Foudre sur un petit groupe, gros coup de frein.",
	Rocket = "Gros carreau contre les monstres résistants.",
	Laser = "Rayon qui chauffe : terrible contre les boss.",
	Chain = "Un éclair qui rebondit sur 4 monstres.",
	Orbital = "Une pierre géante sur le plus gros groupe.",
}
local HOTKEYS = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7,
	[Enum.KeyCode.Eight] = 8,
}

-- Vue d'en haut. Inclinaison de la caméra (90° = à la verticale) : choisie entre ces deux angles pour que la
-- carte remplisse le mieux l'écran (un téléphone est large et bas : vue plus couchée ; un écran d'ordinateur :
-- plus plongeante). Champ de vision petit = peu de perspective.
-- Pour une vue FIXE, mets la même valeur aux deux : 70 et 70 = plus plongeante, 90 et 90 = pile au-dessus (on ne voit
-- alors que le dessus des tours et des monstres, et la carte est environ 30 % plus petite à l'écran). Les trois
-- vues ont été montrées au propriétaire le 02/10/2026 (« pourquoi la vue n'est pas vraiment au-dessus ? ») : il a
-- choisi la première, la vue penchée de ce réglage (« le premier est mieux »). Ne pas la changer sans sa demande.
local CAMERA_PITCH_MIN = 48
local CAMERA_PITCH_MAX = 64
local CAMERA_FOV = 40
-- Zoom : 1 = toute la carte, ZOOM_MAX = au plus près. Molette (ou pincement) ; une fois zoomé, on déplace la vue
-- en glissant un doigt, avec le clic droit maintenu ou avec les flèches du clavier.
local ZOOM_MAX = 3
local ZOOM_WHEEL = 1.18 -- un cran de molette
local PAN_KEYS_SPEED = 45 -- studs par seconde avec les flèches (divisé par le zoom)
local RIGHT_CLICK_MOVE = 6 -- px : en dessous, un clic droit annule ; au-dessus, il déplace la vue
-- Étiquettes (barres de vie, niveaux des tours) affichées à moins de ça du centre de la zone : toute la carte.
local LABEL_RADIUS = 160
-- Les sons du combat s'entendent depuis un point à cette distance (au plus) du point regardé, pas depuis la caméra.
local LISTENER_DISTANCE = 32
local SELECT_RADIUS = 2.8 -- un appui à moins de ça d'une tour la choisit (studs)
local SNAP_RADIUS = 3 -- un appui à moins de ça d'un « + » pose exactement dessus
local TAP_MOVE, TAP_TIME = 18, 0.6 -- un appui (téléphone) : moins de 18 px de glissement, moins de 0,6 s
local DRAG_START = 22 -- px : au-delà, un toucher parti d'une tour de la barre devient un « glisser »
local QUIT_CONFIRM = 3 -- secondes pour confirmer « Quitter »
local PLUS_MARKERS = 8 -- « + » affichés au plus (les premiers emplacements conseillés encore libres)
local GOLD_POPUPS = 14 -- « +2 » dorés affichés à la fois au plus (or gagné au-dessus des monstres tués)
-- Conseil « ne garde pas ton or » : affiché quand le joueur a au moins IDLE_GOLD d'or, de quoi acheter quelque
-- chose, et qu'il n'achète rien depuis IDLE_GOLD_SECONDS (un niveau ne se gagne qu'en réinvestissant sans arrêt).
local IDLE_GOLD = 80
local IDLE_GOLD_SECONDS = 4

local WINDOW_SIZE = Vector2.new(780, 540)
local END_SIZE = Vector2.new(460, 372)
local MENU_SIZE = Vector2.new(240, 122)
local MENU_PHONE_SCALE = 0.78 -- téléphone : menu de la tour plus petit (il cacherait trop de carte)
local BAR_BUTTON = Vector2.new(88, 62)
local BAR_BUTTON_PHONE = Vector2.new(80, 44) -- téléphone : barre plus basse, la carte a plus de place
local BAR_GAP = 6
-- Téléphone tenu en large : le bandeau du haut se range dans la barre de Roblox, à droite de ses boutons.
local PHONE_STRIP_LEFT = 190
-- Écrans laissés affichés pendant un niveau (les autres sont cachés puis remis).
local KEEP_GUIS = { LevelHud = true, Toasts = true }
-- Écrans du JEU INFINI, cachés tant que la parcelle du joueur est son camp d'entraînement (CampMode.luau) : pièces
-- du fief et panneau des tours, autel et forge, renaissance, boutique des passes et gains d'absence, défis, tuto
-- du jeu infini, bouton qui masque les raccourcis du téléphone.
local INFINITE_GUIS = {
	"Plot", "Machines", "Rebirth", "RebirthButton", "ShopButton", "Shop", "OfflineGains", "ChallengesButton", "Challenges",
	"Tutorial", "TutorialPointer", "ShortcutsToggle",
}

local levelAction = nil -- remote LevelAction (LevelsUI.start)

----------------------------------------------------------------------
-- État du joueur (attribut « LevelsState », publié par le serveur)
----------------------------------------------------------------------
local state = { best = 0, coins = 0, towers = table.clone(Levels.STARTING_TOWERS), xp = {}, slots = {}, wins = 0, losses = 0 }

local function readState()
	local raw = player:GetAttribute("LevelsState")
	if typeof(raw) ~= "string" then
		return
	end
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not ok or typeof(decoded) ~= "table" then
		return
	end
	local towers = {}
	for _, towerType in if typeof(decoded.towers) == "table" then decoded.towers else {} do
		if IdleTowers.Defs[towerType] then
			table.insert(towers, towerType)
		end
	end
	state = {
		best = tonumber(decoded.best) or 0,
		coins = tonumber(decoded.coins) or 0,
		towers = towers,
		xp = if typeof(decoded.xp) == "table" then decoded.xp else {},
		slots = if typeof(decoded.slots) == "table" then decoded.slots else {},
		wins = tonumber(decoded.wins) or 0,
		losses = tonumber(decoded.losses) or 0,
	}
end

local function owns(towerType: string): boolean
	return table.find(state.towers, towerType) ~= nil
end

local function amount(value: number): string
	return NumberFormat.short(value)
end

-- Nombre court avec une décimale au plus : 4.05 -> « 4 », 12.34 -> « 12,3 ».
local function decimal(value: number): string
	if value >= 1000 then
		return NumberFormat.short(value)
	end
	return UI.decimal(math.floor(value * 10 + 0.5) / 10)
end

-- Ligne de stats d'une tour dans un niveau : « Dégâts 3 • 5 atq/s • Portée 21 ».
local function statsLine(stats): string
	local damage = if stats.kind == "Beam" then `Dégâts {decimal(stats.damage)}/s` else `Dégâts {decimal(stats.damage)}`
	return `{damage} • {UI.towerSpeed(stats)} • Portée {decimal(stats.range)}`
end

----------------------------------------------------------------------
-- Fenêtre du camp : Niveaux, Boutique, Entraînement, Mes tours
----------------------------------------------------------------------
local camp = {}

local function buildCamp()
	local gui = UI.screen("Levels", 23)
	gui:SetAttribute("NoTranslate", true)
	camp.gui = gui

	local openButton = UI.button({
		Name = "LevelsButton",
		BackgroundColor3 = Color3.fromRGB(150, 38, 42),
		Text = "⚔ NIVEAUX",
		MaxTextSize = 18,
		Parent = gui,
	})
	-- Pièces de niveau, toujours visibles à côté du bouton (la parcelle du joueur est son camp : plus de « trésor du
	-- fief » en haut de l'écran).
	local hudCoins = UI.label({
		Name = "HudCoins",
		BackgroundColor3 = UI.Colors.Background,
		BackgroundTransparency = 0.15,
		Font = Enum.Font.GothamBlack,
		TextColor3 = UI.Colors.Gold,
		MaxTextSize = 18,
		Parent = gui,
	})
	UI.corner(8).Parent = hudCoins
	local window = UI.new("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(WINDOW_SIZE.X, WINDOW_SIZE.Y),
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.03,
		Active = true,
		Visible = false,
		Parent = gui,
	}, { UI.corner(14), UI.padding(12) })
	UI.chrome(window)
	camp.window = window
	-- Petit écran (téléphone) : la fenêtre est réduite pour tenir en LARGEUR seulement, et son contenu défile de
	-- haut en bas (pages = ScrollingFrame). Réduite pour tenir aussi en hauteur (comme UI.fitWindow), elle serait à
	-- moitié de sa taille sur un téléphone tenu en large : cartes et textes trop petits pour le doigt.
	local windowScale = UI.new("UIScale", { Name = "FitScale", Parent = window }) :: UIScale

	-- Bouton d'ouverture : à droite du bouton « 🎁 DONNER » du propriétaire (AdminUI), plus petit sur téléphone.
	local function placeButton()
		local screen = UI.screenSize(gui)
		local phone = UI.touchLayout(screen)
		openButton.Position = if phone then UDim2.fromOffset(128, 48) else UDim2.fromOffset(154, 16)
		openButton.Size = if phone then UDim2.fromOffset(110, 30) else UDim2.fromOffset(150, 38)
		hudCoins.Position = if phone then UDim2.fromOffset(244, 48) else UDim2.fromOffset(310, 16)
		hudCoins.Size = if phone then UDim2.fromOffset(84, 30) else UDim2.fromOffset(110, 38)
		if screen.X > 0 and screen.Y > 0 then
			local scale = math.clamp((screen.X - 2 * UI.WINDOW_MARGIN) / WINDOW_SIZE.X, UI.MIN_WINDOW_SCALE, 1)
			windowScale.Scale = scale
			window.Size = UDim2.fromOffset(WINDOW_SIZE.X, math.min(WINDOW_SIZE.Y, (screen.Y - 2 * UI.WINDOW_MARGIN) / scale))
		end
	end
	placeButton()
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeButton)

	UI.label({
		Name = "Title",
		Size = UDim2.new(1, -230, 0, 30),
		Font = Enum.Font.GothamBlack,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 22,
		Text = "⚔ NIVEAUX • " .. Levels.MAPS.Valley.displayName,
		Parent = window,
	})
	local coinsLabel = UI.label({
		Name = "Coins",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -44, 0, 0),
		Size = UDim2.fromOffset(180, 30),
		Font = Enum.Font.GothamBlack,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = UI.Colors.Gold,
		MaxTextSize = 22,
		Parent = window,
	})
	local closeButton = UI.button({
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(36, 30),
		BackgroundColor3 = UI.Colors.Error,
		Text = "X",
		MaxTextSize = 18,
		Parent = window,
	})

	local TABS = { "Niveaux", "Boutique", "Entraînement", "Mes tours" }
	local tabButtons, pages = {}, {}
	local currentTab = TABS[1]
	for index, name in TABS do
		tabButtons[name] = UI.button({
			Name = "Tab" .. index,
			Position = UDim2.new((index - 1) / #TABS, 2, 0, 38),
			Size = UDim2.new(1 / #TABS, -4, 0, 32),
			Text = name,
			MaxTextSize = 16,
			Parent = window,
		})
		-- (hauteur du contenu = celle d'un écran d'ordinateur : sur un écran plus bas, la page défile)
		pages[name] = UI.new("ScrollingFrame", {
			Name = "Page" .. index,
			Position = UDim2.fromOffset(0, 80),
			Size = UDim2.new(1, 0, 1, -80),
			BackgroundTransparency = 1,
			ScrollBarThickness = 5,
			ScrollBarImageColor3 = UI.Colors.Gold,
			CanvasSize = UDim2.fromOffset(0, WINDOW_SIZE.Y - 24 - 80),
			ScrollingDirection = Enum.ScrollingDirection.Y,
			Visible = false,
			Parent = window,
		})
	end

	------------------------------------------------------------------
	-- Onglet « Niveaux » : 10 cartes (5 par rangée)
	------------------------------------------------------------------
	local CARD_W, CARD_H, GAP = 144, 152, 9
	local levelCards = {}
	for level = 1, Levels.COUNT do
		local definition = Levels.definition(level)
		local column, row = (level - 1) % 5, math.floor((level - 1) / 5)
		local card = UI.new("Frame", {
			Name = "Level" .. level,
			Position = UDim2.fromOffset(column * (CARD_W + GAP), row * (CARD_H + GAP)),
			Size = UDim2.fromOffset(CARD_W, CARD_H),
			BackgroundColor3 = UI.Colors.PanelLight,
			Parent = pages.Niveaux,
		}, { UI.corner(10), UI.padding(8) })
		local stroke = UI.stroke(UI.Colors.Gold, 2)
		stroke.Parent = card
		UI.label({
			Size = UDim2.new(1, 0, 0, 24),
			Font = Enum.Font.GothamBlack,
			MaxTextSize = 20,
			Text = "NIVEAU " .. level,
			Parent = card,
		})
		UI.label({
			Position = UDim2.fromOffset(0, 26),
			Size = UDim2.new(1, 0, 0, 18),
			Font = Enum.Font.GothamBold,
			MaxTextSize = 14,
			TextColor3 = if definition.boss then UI.Colors.DangerText elseif definition.miniBoss then UI.Colors.Gold else UI.Colors.Muted,
			Text = if definition.boss then "👑 BOSS" elseif definition.miniBoss then "💀 MINI-BOSS" else `{#Levels.buildQueue(level)} monstres`,
			Parent = card,
		})
		local reward = UI.label({
			Name = "Reward",
			Position = UDim2.fromOffset(0, 48),
			Size = UDim2.new(1, 0, 0, 40),
			TextWrapped = true,
			MaxTextSize = 15,
			Parent = card,
		})
		local button = UI.button({
			Name = "Play",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, 0),
			Size = UDim2.new(1, 0, 0, 38),
			MaxTextSize = 17,
			Parent = card,
		})
		button.Activated:Connect(function()
			if level <= state.best + 1 then
				levelAction:FireServer("Start", level)
			end
		end)
		levelCards[level] = { card = card, stroke = stroke, reward = reward, button = button }
	end
	local summary = UI.label({
		Name = "Summary",
		Position = UDim2.fromOffset(0, 2 * CARD_H + GAP + 12),
		Size = UDim2.new(1, 0, 1, -(2 * CARD_H + GAP + 12)),
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = UI.Colors.Muted,
		MaxTextSize = 15,
		Parent = pages.Niveaux,
	})

	local function refreshLevels()
		for level, entry in levelCards do
			local cleared = level <= state.best
			local nextOne = level == state.best + 1
			entry.reward.Text = if cleared
				then `Rejouer :\n+{amount(Levels.reward(level, true, false))} {COIN}`
				else `Victoire :\n+{amount(Levels.firstReward(level))} {COIN}`
			entry.reward.TextColor3 = if cleared then UI.Colors.Muted else UI.Colors.Gold
			entry.button.Text = if cleared then "REJOUER" elseif nextOne then "▶ JOUER" else "🔒"
			entry.button.BackgroundColor3 = if nextOne then UI.Colors.Success elseif cleared then UI.Colors.Accent else UI.Colors.Panel
			entry.button.AutoButtonColor = cleared or nextOne
			entry.stroke.Transparency = if nextOne then 0 else 0.8
			entry.card.BackgroundTransparency = if cleared or nextOne then 0 else 0.55
		end
		summary.Text = `Chaque niveau est un flot de monstres sans pause, de plus en plus forts : pose et améliore tes tours sans arrêt avec l'or qu'ils donnent, protège ton château ({Levels.LIVES} vies). `
			.. `Gagner rapporte des pièces de niveau {COIN} pour acheter d'autres tours et améliorer ton camp d'entraînement.\n`
			.. `Victoires : {state.wins} • Défaites : {state.losses}`
	end

	------------------------------------------------------------------
	-- Onglet « Boutique » : les 8 tours, à prix fixes (aucun hasard)
	------------------------------------------------------------------
	local SHOP_W, SHOP_H = 182, 206
	local shopCards = {}
	for index, towerType in IdleTowers.ORDER do
		local def = IdleTowers.Defs[towerType]
		local column, row = (index - 1) % 4, math.floor((index - 1) / 4)
		local card = UI.new("Frame", {
			Name = "Shop_" .. towerType,
			Position = UDim2.fromOffset(column * (SHOP_W + GAP), row * (SHOP_H + GAP)),
			Size = UDim2.fromOffset(SHOP_W, SHOP_H),
			BackgroundColor3 = UI.Colors.PanelLight,
			Parent = pages.Boutique,
		}, { UI.corner(10), UI.padding(8) })
		local stroke = UI.stroke(def.color, 2)
		stroke.Transparency = 0.35
		stroke.Parent = card
		UI.label({
			Size = UDim2.new(1, 0, 0, 38),
			Font = Enum.Font.GothamBlack,
			TextWrapped = true,
			TextColor3 = def.color:Lerp(Color3.new(1, 1, 1), 0.4),
			MaxTextSize = 17,
			Text = def.displayName,
			Parent = card,
		})
		UI.label({
			Name = "Role",
			Position = UDim2.fromOffset(0, 42),
			Size = UDim2.new(1, 0, 0, 52),
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			MaxTextSize = 14,
			Text = ROLES[towerType],
			Parent = card,
		})
		UI.label({
			Position = UDim2.fromOffset(0, 98),
			Size = UDim2.new(1, 0, 0, 36),
			TextWrapped = true,
			TextColor3 = UI.Colors.Muted,
			MaxTextSize = 13,
			Text = `En niveau : {Levels.placeCost(towerType)} {GOLD}\n{Levels.maxCopies(towerType)} au plus`,
			Parent = card,
		})
		local button = UI.button({
			Name = "Buy",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, 0),
			Size = UDim2.new(1, 0, 0, 40),
			MaxTextSize = 16,
			Parent = card,
		})
		button.Activated:Connect(function()
			local price = Levels.SHOP[towerType]
			if price and not owns(towerType) and state.coins >= price then
				levelAction:FireServer("Buy", towerType)
			end
		end)
		shopCards[towerType] = { button = button }
	end

	local function refreshShop()
		for towerType, entry in shopCards do
			local price = Levels.SHOP[towerType]
			local button = entry.button
			if owns(towerType) then
				button.Text = "✓ À TOI"
				button.BackgroundColor3 = UI.Colors.Success
				button.AutoButtonColor = false
				button.TextColor3 = Color3.new(1, 1, 1)
			elseif price and state.coins >= price then
				button.Text = `ACHETER {amount(price)} {COIN}`
				button.BackgroundColor3 = UI.Colors.Warning
				button.AutoButtonColor = true
				button.TextColor3 = Color3.new(1, 1, 1)
			else
				button.Text = if price then `{amount(price)} {COIN} (il manque {amount(price - state.coins)})` else "—"
				button.BackgroundColor3 = UI.Colors.Panel
				button.AutoButtonColor = false
				button.TextColor3 = UI.Colors.Muted
			end
		end
	end

	------------------------------------------------------------------
	-- Onglet « Entraînement » : emplacements du camp (à gauche), tours et leur XP (à droite)
	------------------------------------------------------------------
	local SLOT_W, SLOT_H = 296, 98
	local selectedSlot = 1
	local slotRows = {}
	local refreshTraining
	for index = 1, #Levels.TRAINING.SLOT_UNLOCK_COST do
		local row = UI.new("TextButton", {
			Name = "Slot" .. index,
			Position = UDim2.fromOffset(0, (index - 1) * (SLOT_H + 8)),
			Size = UDim2.fromOffset(SLOT_W, SLOT_H),
			BackgroundColor3 = UI.Colors.PanelLight,
			AutoButtonColor = false,
			Text = "",
			Parent = pages["Entraînement"],
		}, { UI.corner(10), UI.padding(8) })
		local stroke = UI.stroke(UI.Colors.Gold, 2)
		stroke.Parent = row
		local title = UI.label({
			Size = UDim2.new(1, 0, 0, 20),
			Font = Enum.Font.GothamBlack,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 15,
			Parent = row,
		})
		local tower = UI.label({
			Position = UDim2.fromOffset(0, 22),
			Size = UDim2.new(1, 0, 0, 20),
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 15,
			Parent = row,
		})
		local rate = UI.label({
			Position = UDim2.fromOffset(0, 46),
			Size = UDim2.new(1, -150, 0, 34),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			TextColor3 = UI.Colors.Muted,
			MaxTextSize = 13,
			Parent = row,
		})
		local action = UI.button({
			Name = "Action",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, 0, 1, 0),
			Size = UDim2.fromOffset(146, 34),
			MaxTextSize = 14,
			Parent = row,
		})
		row.Activated:Connect(function()
			if state.slots[index] then
				selectedSlot = index
				refreshTraining()
			end
		end)
		action.Activated:Connect(function()
			if state.slots[index] then
				levelAction:FireServer("SlotUpgrade", index)
			elseif index == #state.slots + 1 then
				levelAction:FireServer("SlotUnlock")
			end
		end)
		slotRows[index] = { row = row, stroke = stroke, title = title, tower = tower, rate = rate, action = action }
	end
	UI.label({
		Name = "Help",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(0, SLOT_W, 0, 96),
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		TextColor3 = UI.Colors.Muted,
		MaxTextSize = 13,
		Text = `Une tour dans un emplacement gagne de l'XP tout le temps, même quand tu es parti ({Levels.TRAINING.OFFLINE_MAX_SECONDS // 3600} h au plus). Chaque niveau joué donne aussi de l'XP aux tours posées. Chaque niveau d'entraînement : +{math.floor(Levels.TRAINING.DAMAGE_PER_LEVEL * 100 + 0.5)} % de dégâts, et de nouvelles améliorations.`,
		Parent = pages["Entraînement"],
	})
	local trainingList = UI.new("ScrollingFrame", {
		Name = "Towers",
		Position = UDim2.fromOffset(SLOT_W + 12, 0),
		Size = UDim2.new(1, -(SLOT_W + 12), 1, 0),
		BackgroundTransparency = 1,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = UI.Colors.Gold,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = pages["Entraînement"],
	}, { UI.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local trainingRows = {}
	for _, towerType in IdleTowers.ORDER do
		local def = IdleTowers.Defs[towerType]
		local row = UI.new("Frame", {
			Name = "Train_" .. towerType,
			Size = UDim2.new(1, -8, 0, 116),
			BackgroundColor3 = UI.Colors.PanelLight,
			Visible = false,
			Parent = trainingList,
		}, { UI.corner(10), UI.padding(8) })
		UI.label({
			Size = UDim2.new(1, -290, 0, 20),
			Font = Enum.Font.GothamBlack,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = def.color:Lerp(Color3.new(1, 1, 1), 0.4),
			MaxTextSize = 15,
			Text = def.displayName,
			Parent = row,
		})
		local levelLabel = UI.label({
			Name = "Level",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -116, 0, 0),
			Size = UDim2.fromOffset(170, 20),
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = UI.Colors.Gold,
			MaxTextSize = 14,
			Parent = row,
		})
		local bar, setBar = UI.bar({ Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, -116, 0, 12) }, UI.Colors.Gold)
		bar.Parent = row
		local xpLabel = UI.label({
			Position = UDim2.fromOffset(0, 24),
			Size = UDim2.new(1, -116, 0, 12),
			Font = Enum.Font.GothamBold,
			TextStrokeTransparency = 0.4,
			MaxTextSize = 11,
			ZIndex = 2,
			Parent = row,
		})
		-- ÉVOLUTIONS de la tour (Levels.PERKS : aux niveaux d'entraînement 2, 4 et 6) : une case par évolution, dorée
		-- quand elle est débloquée, et le détail de la prochaine en dessous.
		local evolutions = {}
		local perks = Levels.PERKS[towerType] or {}
		for index, _ in perks do
			evolutions[index] = UI.label({
				Name = "Evolution" .. index,
				-- (les cases se partagent la largeur de la ligne moins le bouton de droite : 116 px)
				Position = UDim2.new((index - 1) / #perks, -(index - 1) * 116 / #perks, 0, 42),
				Size = UDim2.new(1 / #perks, -(116 / #perks) - 4, 0, 22),
				BackgroundColor3 = UI.Colors.Background,
				BackgroundTransparency = 0.2,
				Font = Enum.Font.GothamBold,
				MaxTextSize = 12,
				Parent = row,
			})
			UI.corner(6).Parent = evolutions[index]
		end
		local detail = UI.label({
			Name = "NextEvolution",
			Position = UDim2.fromOffset(0, 68),
			Size = UDim2.new(1, -116, 0, 32),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			TextColor3 = UI.Colors.Muted,
			MaxTextSize = 13,
			Parent = row,
		})
		local button = UI.button({
			Name = "Train",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(108, 40),
			MaxTextSize = 13,
			Parent = row,
		})
		button.Activated:Connect(function()
			local slot = state.slots[selectedSlot]
			if slot and owns(towerType) then
				levelAction:FireServer("SlotAssign", selectedSlot, if slot.tower == towerType then "" else towerType)
			end
		end)
		trainingRows[towerType] = { row = row, level = levelLabel, setBar = setBar, xp = xpLabel, evolutions = evolutions, detail = detail, button = button }
	end

	function refreshTraining()
		if not state.slots[selectedSlot] then
			selectedSlot = 1
		end
		for index, entry in slotRows do
			local slot = state.slots[index]
			if slot then
				local def = IdleTowers.Defs[slot.tower]
				local rate = Levels.TRAINING.SLOT_RATE[slot.level] or 0
				local price = Levels.TRAINING.SLOT_UPGRADE_COST[slot.level]
				entry.title.Text = `EMPLACEMENT {index} • niveau {slot.level}`
				entry.tower.Text = if def then def.displayName else "Vide : choisis une tour à droite"
				entry.tower.TextColor3 = if def then def.color:Lerp(Color3.new(1, 1, 1), 0.4) else UI.Colors.Muted
				entry.rate.Text = `+{UI.decimal(rate)} XP par minute`
				entry.action.Visible = true
				entry.action.Text = if price then `Améliorer {amount(price)} {COIN}` else "NIVEAU MAX"
				entry.action.BackgroundColor3 = if price and state.coins >= price then UI.Colors.Warning else UI.Colors.Panel
				entry.action.AutoButtonColor = price ~= nil and state.coins >= price
				entry.row.BackgroundTransparency = 0
				entry.stroke.Transparency = if index == selectedSlot then 0 else 0.85
			else
				local price = Levels.TRAINING.SLOT_UNLOCK_COST[index]
				local nextOne = index == #state.slots + 1
				entry.title.Text = `EMPLACEMENT {index} 🔒`
				entry.tower.Text = if nextOne then "Une tour de plus à l'entraînement" else "Ouvre d'abord le précédent"
				entry.tower.TextColor3 = UI.Colors.Muted
				entry.rate.Text = ""
				entry.action.Visible = nextOne
				entry.action.Text = `Ouvrir {amount(price)} {COIN}`
				entry.action.BackgroundColor3 = if state.coins >= price then UI.Colors.Warning else UI.Colors.Panel
				entry.action.AutoButtonColor = state.coins >= price
				entry.row.BackgroundTransparency = 0.55
				entry.stroke.Transparency = 0.85
			end
		end
		local slot = state.slots[selectedSlot]
		for order, towerType in IdleTowers.ORDER do
			local entry = trainingRows[towerType]
			entry.row.Visible = owns(towerType)
			entry.row.LayoutOrder = table.find(state.towers, towerType) or (100 + order)
			local xp = tonumber(state.xp[towerType]) or 0
			local trained = Levels.trainingLevel(xp)
			local done, needed = Levels.trainingProgress(xp)
			local stars = Levels.stars(Levels.evolutionStage(towerType, trained))
			entry.level.Text = `{if stars ~= "" then stars .. "  " else ""}Entraînement {trained}/{Levels.TRAINING.MAX_LEVEL}`
			entry.setBar(if needed > 0 then done / needed else 1)
			entry.xp.Text = if needed > 0 then `{math.floor(done)} / {needed} XP` else "MAX"
			local nextPerk = nil
			for index, candidate in Levels.PERKS[towerType] or {} do
				local unlocked = trained >= candidate.level
				local chip = entry.evolutions[index]
				chip.Text = `{if unlocked then string.rep("★", index) else "🔒"} {candidate.name}`
				chip.TextColor3 = if unlocked then UI.Colors.Gold else UI.Colors.Muted
				if not unlocked and not nextPerk then
					nextPerk = candidate
				end
			end
			entry.detail.Text = if nextPerk
				then `Prochaine évolution (entraînement {nextPerk.level}) : {nextPerk.name}. {nextPerk.text}`
				else "Toutes ses évolutions sont débloquées."
			local here = slot ~= nil and slot.tower == towerType
			local elsewhere = nil
			for index, other in state.slots do
				if index ~= selectedSlot and other.tower == towerType then
					elsewhere = index
				end
			end
			entry.button.Text = if here then "✓ S'ENTRAÎNE (retirer)" elseif elsewhere then `Empl. {elsewhere} → {selectedSlot}` else "ENTRAÎNER"
			entry.button.BackgroundColor3 = if here then UI.Colors.Success else UI.Colors.Accent
		end
	end

	------------------------------------------------------------------
	-- Onglet « Mes tours » : l'inventaire, dans l'ordre de la barre rapide
	------------------------------------------------------------------
	UI.label({
		Name = "Help",
		Size = UDim2.new(1, 0, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.Muted,
		MaxTextSize = 14,
		Text = "Toutes tes tours peuvent être posées dans un niveau. Cet ordre est celui de ta barre rapide (▲ ▼ pour le changer).",
		Parent = pages["Mes tours"],
	})
	local towerList = UI.new("ScrollingFrame", {
		Name = "Towers",
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, 0, 1, -26),
		BackgroundTransparency = 1,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = UI.Colors.Gold,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = pages["Mes tours"],
	}, { UI.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local towerRows = {}
	local function moveInBar(towerType: string, direction: number)
		local order = table.clone(state.towers)
		local index = table.find(order, towerType)
		local target = index and index + direction
		if index and target and target >= 1 and target <= #order then
			order[index], order[target] = order[target], order[index]
			levelAction:FireServer("Bar", order)
		end
	end
	for _, towerType in IdleTowers.ORDER do
		local def = IdleTowers.Defs[towerType]
		local row = UI.new("Frame", {
			Name = "Tower_" .. towerType,
			Size = UDim2.new(1, -8, 0, 64),
			BackgroundColor3 = UI.Colors.PanelLight,
			Visible = false,
			Parent = towerList,
		}, { UI.corner(10), UI.padding(8) })
		local title = UI.label({
			Size = UDim2.new(1, -100, 0, 20),
			Font = Enum.Font.GothamBlack,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = def.color:Lerp(Color3.new(1, 1, 1), 0.4),
			MaxTextSize = 15,
			Parent = row,
		})
		local stats = UI.label({
			Position = UDim2.fromOffset(0, 22),
			Size = UDim2.new(1, -100, 0, 26),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			TextColor3 = UI.Colors.Muted,
			MaxTextSize = 13,
			Parent = row,
		})
		local up = UI.button({
			Name = "Up",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -46, 0.5, 0),
			Size = UDim2.fromOffset(40, 40),
			BackgroundColor3 = UI.Colors.Panel,
			Text = "▲",
			MaxTextSize = 16,
			Parent = row,
		})
		local down = UI.button({
			Name = "Down",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(40, 40),
			BackgroundColor3 = UI.Colors.Panel,
			Text = "▼",
			MaxTextSize = 16,
			Parent = row,
		})
		up.Activated:Connect(function()
			moveInBar(towerType, -1)
		end)
		down.Activated:Connect(function()
			moveInBar(towerType, 1)
		end)
		towerRows[towerType] = { row = row, title = title, stats = stats }
	end

	local function refreshTowers()
		for order, towerType in IdleTowers.ORDER do
			local entry = towerRows[towerType]
			local index = table.find(state.towers, towerType)
			entry.row.Visible = index ~= nil
			entry.row.LayoutOrder = index or (100 + order)
			if index then
				local def = IdleTowers.Defs[towerType]
				local trained = Levels.trainingLevel(state.xp[towerType])
				local unlocked = {}
				for _, perk in Levels.PERKS[towerType] or {} do
					if trained >= perk.level then
						table.insert(unlocked, perk.name)
					end
				end
				local stars = Levels.stars(Levels.evolutionStage(towerType, trained))
				entry.title.Text = `{index}. {def.displayName}{if stars ~= "" then " " .. stars else ""} • {Levels.placeCost(towerType)} {GOLD} • entraînement {trained}`
				entry.stats.Text = statsLine(Levels.towerStats(towerType, 1, trained))
					.. (if #unlocked > 0 then "\n" .. table.concat(unlocked, ", ") else "")
			end
		end
	end

	------------------------------------------------------------------
	local function refresh()
		coinsLabel.Text = `{amount(state.coins)} {COIN}`
		hudCoins.Text = coinsLabel.Text
		for name, button in tabButtons do
			button.BackgroundColor3 = if name == currentTab then UI.Colors.Accent else UI.Colors.Panel
			pages[name].Visible = name == currentTab
		end
		refreshLevels()
		refreshShop()
		refreshTraining()
		refreshTowers()
	end
	camp.refresh = refresh

	-- slot = emplacement d'entraînement à montrer (invite d'un socle du camp, sur la parcelle).
	function camp.open(tab: string?, slot: number?)
		if tab and pages[tab] then
			currentTab = tab
		end
		if slot and state.slots[slot] then
			selectedSlot = slot
		end
		window.Visible = true
		refresh()
	end

	function camp.close()
		window.Visible = false
	end

	for name, button in tabButtons do
		button.Activated:Connect(function()
			camp.open(name)
		end)
	end
	-- Le bouton « ⚔ NIVEAUX » ouvre toujours l'onglet des niveaux (les autres onglets : leurs boutons, ou les
	-- bâtiments et les socles de la parcelle).
	openButton.Activated:Connect(function()
		if window.Visible then
			camp.close()
		else
			camp.open("Niveaux")
		end
	end)
	closeButton.Activated:Connect(camp.close)
	refresh()
end

----------------------------------------------------------------------
-- Pendant un niveau
----------------------------------------------------------------------
local hud = {}
-- active = un niveau est affiché ; index / slot / cframe = sa zone de combat ; folder = son dossier (attributs).
local level = {
	active = false,
	index = nil :: number?,
	slot = nil :: number?,
	cframe = CFrame.new(),
	folder = nil :: Instance?,
	geometry = nil :: any,
	mapName = nil :: string?,
	runState = nil :: string?,
	number = nil :: number?,
	placing = nil :: string?,
	selected = nil :: Model?,
	startedAt = 0,
	firstTime = false, -- tout premier niveau du joueur : conseils pas à pas
	upgraded = false, -- (conseils) une tour a déjà été améliorée dans ce niveau
	cameraKey = "",
	-- Vue réglée pour toute la carte (fitCamera) : point regardé, distance, direction du regard, inclinaison.
	cameraTarget = Vector3.zero,
	cameraDistance = 100,
	cameraLook = Vector3.new(0, -1, 0),
	cameraPitch = math.rad(CAMERA_PITCH_MAX),
	zoom = 1,
	pan = Vector2.zero, -- déplacement de la vue sur le sol (studs) : X = vers la droite, Y = vers le fond
	pitchOverride = nil :: number?, -- essais dans Studio : inclinaison imposée, en degrés (TestAction « Pitch »)
	quitArmedAt = nil :: number?,
	resultShown = nil :: string?,
	training = {} :: { [string]: number },
	trainingText = nil :: string?,
}
local helpers = Instance.new("Folder")
helpers.Name = "LevelHelpers"
local ghost: Part
local ghostRing: Part
local selectRing: Part
local plusMarkers = {} -- { anchor = Part, billboard = BillboardGui }
local hiddenGuis = {} -- [ScreenGui] = vrai : écrans cachés pendant le niveau, à remettre
local savedCamera = nil -- { type, fov, subject }
local controls = nil
-- [InputObject du toucher] = { position (début), last (dernière position), at, processed, moved }
local touchStarts = setmetatable({}, { __mode = "k" })
local drag = { input = nil :: InputObject?, towerType = nil :: string?, origin = Vector3.zero, active = false }
local rightDrag = { down = false, last = Vector3.zero, moved = 0 }
local towerConnections = {}
local watchedTowers: Instance? = nil

local function arenaFolder(): Instance?
	local folder = level.folder
	if (not folder or not folder.Parent) and level.slot then
		local arenas = workspace:FindFirstChild("Arenas")
		folder = arenas and arenas:FindFirstChild("Arena" .. level.slot)
		level.folder = folder
	end
	return folder
end

local function attribute(name: string): any
	local folder = arenaFolder()
	return folder and folder:GetAttribute(name)
end

local function numberAttribute(name: string): number
	local value = attribute(name)
	return if typeof(value) == "number" and value == value then value else 0
end

local function towersFolder(): Instance?
	local folder = arenaFolder()
	return folder and folder:FindFirstChild("Towers")
end

-- Position locale (dans la zone) du pied d'une tour posée.
local function towerLocal(model: Model): Vector3
	local rest = model:GetAttribute("RestCFrame")
	local world = if typeof(rest) == "CFrame" then rest.Position else model:GetPivot().Position
	local point = level.cframe:PointToObjectSpace(world)
	return Vector3.new(point.X, 0, point.Z)
end

local function towerModels(): { Model }
	local list = {}
	local folder = towersFolder()
	for _, child in if folder then folder:GetChildren() else {} do
		if child:IsA("Model") and typeof(child:GetAttribute("TowerId")) == "number" then
			table.insert(list, child)
		end
	end
	return list
end

local function towerPositions(): { Vector3 }
	local positions = {}
	for _, model in towerModels() do
		table.insert(positions, towerLocal(model))
	end
	return positions
end

local function copiesOf(towerType: string): number
	local count = 0
	for _, model in towerModels() do
		if model:GetAttribute("TowerType") == towerType then
			count += 1
		end
	end
	return count
end

local function trainingOf(towerType: string): number
	local text = attribute("Training")
	if text ~= level.trainingText then
		level.trainingText = text
		level.training = Levels.decodeTraining(text)
	end
	return level.training[towerType] or 0
end

-- Peut-on poser cette tour ici (point local de la zone) ? Même règle que le serveur, qui a le dernier mot.
local function canPlace(towerType: string, point: Vector3): (boolean, string?)
	if attribute("State") ~= "Running" or not level.mapName then
		return false, "Le niveau est terminé"
	end
	if copiesOf(towerType) >= Levels.maxCopies(towerType) then
		return false, `Maximum {Levels.maxCopies(towerType)} {IdleTowers.Defs[towerType].displayName} par niveau`
	end
	if numberAttribute("Gold") < Levels.placeCost(towerType) then
		return false, "Pas assez d'or"
	end
	return Levels.checkPlacement(level.mapName, point, towerPositions())
end

-- Emplacements conseillés encore libres (où une tour peut vraiment être posée), dans l'ordre de la carte.
local function freeSpots(): { Vector3 }
	local spots = {}
	if not level.geometry or not level.mapName then
		return spots
	end
	local positions = towerPositions()
	for _, spot in level.geometry.map.spots do
		if Levels.checkPlacement(level.mapName, spot, positions) then
			table.insert(spots, spot)
			if #spots >= PLUS_MARKERS then
				break
			end
		end
	end
	return spots
end

-- Un point tout près d'un « + » : exactement dessus.
local function snap(point: Vector3): Vector3
	local best, bestDistance = point, SNAP_RADIUS
	for _, spot in freeSpots() do
		local distance = (Vector3.new(spot.X, 0, spot.Z) - Vector3.new(point.X, 0, point.Z)).Magnitude
		if distance <= bestDistance then
			best, bestDistance = spot, distance
		end
	end
	return Vector3.new(best.X, 0, best.Z)
end

-- Point du sol de la zone (à la hauteur `height`) visé par ce rayon, dans le monde ; nil s'il part vers le ciel.
local function groundPoint(ray: Ray, height: number?): Vector3?
	local y = level.cframe.Position.Y + (height or 0)
	if math.abs(ray.Direction.Y) < 1e-6 then
		return nil
	end
	local t = (y - ray.Origin.Y) / ray.Direction.Y
	if t <= 0 then
		return nil
	end
	return ray.Origin + ray.Direction * t
end

local function localGround(ray: Ray): Vector3?
	local world = groundPoint(ray, 0)
	if not world then
		return nil
	end
	local point = level.cframe:PointToObjectSpace(world)
	return Vector3.new(point.X, 0, point.Z)
end

-- Tour visée par ce rayon : celle dont le corps (du pied à 5 studs de haut) passe le plus près du rayon.
local function towerUnder(ray: Ray): Model?
	local best, bestDistance = nil, SELECT_RADIUS
	for _, model in towerModels() do
		local foot = towerLocal(model)
		for _, height in { 0, 2.5, 5 } do
			local world = groundPoint(ray, height)
			if world then
				local point = level.cframe:PointToObjectSpace(world)
				local distance = (Vector3.new(point.X, 0, point.Z) - foot).Magnitude
				if distance < bestDistance then
					best, bestDistance = model, distance
				end
			end
		end
	end
	return best
end

----------------------------------------------------------------------
-- Vue d'en haut
----------------------------------------------------------------------

-- Vue qui montre tous les `points` (dans le monde) dans la partie de l'écran laissée libre par les marges (px) :
-- elle regarde vers le fond de la carte (-Z de la zone), inclinée de `pitch`. On rapproche et on recentre un peu
-- à chaque tour, jusqu'à ce que les points remplissent juste la place libre. Renvoie le point regardé, la
-- distance de la caméra et la direction de son regard.
local function fitCamera(origin: CFrame, points: { Vector3 }, viewport: Vector2, margins, pitch: number): (Vector3, number, Vector3)
	local look = origin:VectorToWorldSpace(Vector3.new(0, -math.sin(pitch), -math.cos(pitch)))
	local forward = origin:VectorToWorldSpace(Vector3.new(0, 0, -1))
	local tanV = math.tan(math.rad(CAMERA_FOV) / 2)
	local tanH = tanV * viewport.X / viewport.Y
	local left = -1 + 2 * margins.left / viewport.X
	local right = 1 - 2 * margins.right / viewport.X
	local top = 1 - 2 * margins.top / viewport.Y
	local bottom = -1 + 2 * margins.bottom / viewport.Y
	local target = origin.Position
	local distance = 140
	for _ = 1, 28 do
		-- (« haut » de l'image = le fond de la carte : marche aussi quand la caméra regarde pile vers le bas)
		local cframe = CFrame.lookAt(target - look * distance, target, forward)
		local minX, maxX, minY, maxY = math.huge, -math.huge, math.huge, -math.huge
		for _, point in points do
			local relative = cframe:PointToObjectSpace(point)
			local depth = math.max(1, -relative.Z)
			local x, y = relative.X / depth / tanH, relative.Y / depth / tanV
			minX, maxX = math.min(minX, x), math.max(maxX, x)
			minY, maxY = math.min(minY, y), math.max(maxY, y)
		end
		local scale = math.max((maxX - minX) / math.max(0.2, right - left), (maxY - minY) / math.max(0.2, top - bottom))
		local offsetX = (minX + maxX) / 2 - (left + right) / 2
		local offsetY = (minY + maxY) / 2 - (top + bottom) / 2
		target += cframe.RightVector * (offsetX * tanH * distance) + forward * (offsetY * tanV * distance / math.sin(pitch))
		distance = math.clamp(distance * scale, 30, 800)
	end
	return target, distance, look
end

-- Zoom et déplacement de la vue, toujours dans les clous : au zoom 1 la carte entière est centrée ; plus on zoome,
-- plus on peut s'écarter du centre (jamais au-delà des bords de la carte).
local function setView(zoom: number, pan: Vector2)
	zoom = math.clamp(zoom, 1, ZOOM_MAX)
	local map = level.geometry and level.geometry.map
	local limitX = if map then map.width / 2 * (1 - 1 / zoom) else 0
	local limitY = if map then map.depth / 2 * (1 - 1 / zoom) else 0
	level.zoom = zoom
	level.pan = Vector2.new(math.clamp(pan.X, -limitX, limitX), math.clamp(pan.Y, -limitY, limitY))
	hud.gui:SetAttribute("Zoom", math.floor(zoom * 100 + 0.5) / 100)
end

-- Studs du sol par pixel de l'écran, au point regardé (pour déplacer la vue du même pas que le doigt).
local function studsPerPixel(): number
	local camera = workspace.CurrentCamera
	local height = if camera then camera.ViewportSize.Y else 0
	if height <= 0 then
		return 0
	end
	return 2 * (level.cameraDistance / level.zoom) * math.tan(math.rad(CAMERA_FOV) / 2) / height
end

-- La vue suit un glissement de (dx, dy) pixels : la carte reste sous le doigt.
local function panByPixels(dx: number, dy: number)
	local scale = studsPerPixel()
	setView(level.zoom, level.pan + Vector2.new(-dx * scale, dy * scale / math.sin(level.cameraPitch)))
end

local function updateCamera()
	local camera = workspace.CurrentCamera
	if not camera or not level.geometry then
		return
	end
	local viewport = camera.ViewportSize
	if viewport.X < 50 or viewport.Y < 50 then
		return
	end
	local margins = hud.margins()
	local key = `{viewport.X}x{viewport.Y}:{margins.top}:{margins.bottom}:{level.mapName}`
	if key ~= level.cameraKey then
		level.cameraKey = key
		local map = level.geometry.map
		local halfW, halfD = map.width / 2 + 2, map.depth / 2 + 2
		local points = {}
		for _, corner in {
			Vector3.new(-halfW, 0, -halfD),
			Vector3.new(halfW, 0, -halfD),
			Vector3.new(-halfW, 0, halfD),
			Vector3.new(halfW, 0, halfD),
			-- (ce qui dépasse en hauteur au fond : tours, porte, bannière du château)
			Vector3.new(-halfW, 6, -halfD),
			Vector3.new(halfW, 6, -halfD),
			map.base + Vector3.new(0, 12, 0),
		} do
			table.insert(points, level.cframe:PointToWorldSpace(corner))
		end
		-- L'inclinaison qui montre la carte en plus grand (caméra la plus proche) ; à peu près égal : la plus
		-- plongeante.
		-- (Essais dans Studio : « Pitch:70 » de TestAction impose une inclinaison, pour comparer les vues.)
		local best = nil
		local steepest = level.pitchOverride or CAMERA_PITCH_MAX
		local flattest = level.pitchOverride or CAMERA_PITCH_MIN
		for degrees = steepest, flattest, -2 do
			local pitch = math.rad(degrees)
			local target, distance, look = fitCamera(level.cframe, points, viewport, margins, pitch)
			if not best or distance < best.distance * 0.985 then
				best = { target = target, distance = distance, look = look, pitch = pitch }
			end
		end
		level.cameraTarget, level.cameraDistance, level.cameraLook, level.cameraPitch = best.target, best.distance, best.look, best.pitch
		hud.gui:SetAttribute("Pitch", math.floor(math.deg(best.pitch) + 0.5))
		setView(level.zoom, level.pan)
	end
	local right = level.cframe:VectorToWorldSpace(Vector3.new(1, 0, 0))
	local forward = level.cframe:VectorToWorldSpace(Vector3.new(0, 0, -1))
	local target = level.cameraTarget + right * level.pan.X + forward * level.pan.Y
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = CAMERA_FOV
	camera.CFrame = CFrame.lookAt(target - level.cameraLook * (level.cameraDistance / level.zoom), target, forward)
	-- On écoute depuis un point proche du terrain, sur la ligne du regard : la caméra, elle, est trop loin pour
	-- entendre les tirs et les morts (SoundManager.setListener). Les effets du combat mesurent aussi leurs
	-- distances depuis ce point (CombatVFX.setFocus), sinon ceux du fond de la carte seraient coupés.
	local near = target - level.cameraLook * math.min(level.cameraDistance / level.zoom, LISTENER_DISTANCE)
	SoundManager.setListener(near)
	CombatVFX.setFocus(near)
end

----------------------------------------------------------------------
-- Pose et sélection
----------------------------------------------------------------------

local function setPlacing(towerType: string?)
	level.placing = towerType
	if towerType then
		level.selected = nil
	end
	hud.gui:SetAttribute("Placing", towerType or "")
	hud.gui:SetAttribute("Selected", 0)
end

-- Appui sur une tour de la barre (ou sa touche) : on la prend pour la poser ; un deuxième appui ANNULE, et le
-- bouton le dit tant que la tour est en main (retour du propriétaire, 02/10/2026 : « quand je clique sur une tour
-- pour la poser, il faut que je puisse annuler mon action »). Aussi : clic droit, touche Q.
local function barTap(towerType: string)
	setPlacing(if level.placing == towerType then nil else towerType)
end

local function selectTower(model: Model?)
	level.selected = model
	if model then
		level.placing = nil
		hud.gui:SetAttribute("Placing", "")
	end
	hud.gui:SetAttribute("Selected", if model then model:GetAttribute("TowerId") else 0)
end

local function tryPlace(towerType: string, point: Vector3): boolean
	local ok, reason = canPlace(towerType, point)
	if not ok then
		UI.toast(reason or "Impossible de poser ici", "Error")
		return false
	end
	levelAction:FireServer("Place", towerType, point.X, point.Z)
	return true
end

-- Un clic ou un appui sur le terrain (rayon de la caméra) : choisir une tour, poser, ou tout désélectionner.
local function tapRay(ray: Ray)
	if attribute("State") ~= "Running" then
		return
	end
	local point = localGround(ray)
	if not point then
		return
	end
	local placing = level.placing
	if placing then
		local snapped = snap(point)
		-- Sur une tour déjà posée (et pas sur un « + ») : on la choisit, on ne pose pas dessus.
		local model = if snapped == point then towerUnder(ray) else nil
		if model then
			selectTower(model)
			return
		end
		if tryPlace(placing, snapped) and not UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
			setPlacing(nil)
		end
		return
	end
	selectTower(towerUnder(ray))
end

-- Vrai si un bouton ou une fenêtre du jeu est affiché à cet endroit de l'écran (l'appui est pour lui).
local function overGui(position: Vector3): boolean
	for _, object in player.PlayerGui:GetGuiObjectsAtPosition(position.X, position.Y) do
		if (object:IsA("GuiButton") or object.Active) and not object:FindFirstAncestor("TouchGui") then
			local current, visible = object, true
			while current and not current:IsA("LayerCollector") do
				if current:IsA("GuiObject") and not current.Visible then
					visible = false
					break
				end
				current = current.Parent
			end
			if visible and current and (current :: LayerCollector).Enabled then
				return true
			end
		end
	end
	return false
end

local function tapScreen(position: Vector3)
	local camera = workspace.CurrentCamera
	if camera then
		tapRay(camera:ScreenPointToRay(position.X, position.Y))
	end
end

local function upgradeSelected()
	local model = level.selected
	if model and model.Parent then
		levelAction:FireServer("Upgrade", model:GetAttribute("TowerId"))
	end
end

local function sellSelected()
	local model = level.selected
	if model and model.Parent then
		levelAction:FireServer("Sell", model:GetAttribute("TowerId"))
		selectTower(nil)
	end
end

local function toggleSpeed()
	local fast = numberAttribute("SimSpeed") >= IdleConfig.SPEED_PASS_FACTOR
	levelAction:FireServer("Speed", if fast then 1 else IdleConfig.SPEED_PASS_FACTOR)
end

----------------------------------------------------------------------
-- Entrée et sortie d'un niveau (écrans, caméra, commandes du personnage)
----------------------------------------------------------------------

local function hideOtherGuis()
	for _, child in player.PlayerGui:GetChildren() do
		if child:IsA("ScreenGui") and child.Enabled and not KEEP_GUIS[child.Name] then
			hiddenGuis[child] = true
			child.Enabled = false
		end
	end
end

local function restoreGuis()
	for gui in hiddenGuis do
		if gui.Parent then
			gui.Enabled = true
		end
	end
	table.clear(hiddenGuis)
end

local function setControls(enabled: boolean)
	pcall(function()
		if not controls then
			local module = player:WaitForChild("PlayerScripts"):FindFirstChild("PlayerModule")
			controls = module and (require :: any)(module):GetControls()
		end
		if controls then
			if enabled then
				controls:Enable()
			else
				controls:Disable()
			end
		end
	end)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, enabled)
	end)
end

local function clearTowerWatch()
	for _, connection in towerConnections do
		connection:Disconnect()
	end
	table.clear(towerConnections)
	watchedTowers = nil
end

-- Sons des tours du niveau : posée, améliorée, vendue (le dossier « Towers » est refait à chaque niveau).
local function watchTowers()
	local folder = towersFolder()
	if folder == watchedTowers then
		return
	end
	clearTowerWatch()
	watchedTowers = folder
	if not folder then
		return
	end
	local function watch(model: Instance)
		if model:IsA("Model") then
			table.insert(towerConnections, model:GetAttributeChangedSignal("Level"):Connect(function()
				level.upgraded = true
				SoundManager.play("TowerUpgraded")
			end))
		end
	end
	for _, model in folder:GetChildren() do
		watch(model)
	end
	table.insert(towerConnections, folder.ChildAdded:Connect(function(model)
		watch(model)
		if os.clock() - level.startedAt > 0.5 then
			SoundManager.play("TowerPlaced")
		end
	end))
	table.insert(towerConnections, folder.ChildRemoved:Connect(function()
		if attribute("State") == "Running" then
			SoundManager.play("TowerSold")
		end
	end))
end

local function exitLevel()
	if not level.active then
		return
	end
	level.active = false
	level.index, level.slot, level.folder = nil, nil, nil
	level.placing, level.selected = nil, nil
	level.runState, level.number, level.resultShown = nil, nil, nil
	level.cameraKey = ""
	clearTowerWatch()
	helpers.Parent = nil
	hud.gui.Enabled = false
	ProximityLabel.setFocus(nil)
	SoundManager.setListener(nil)
	CombatVFX.setFocus(nil)
	restoreGuis()
	setControls(true)
	local camera = workspace.CurrentCamera
	if camera and savedCamera then
		camera.FieldOfView = savedCamera.fov
		camera.CameraType = savedCamera.type
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
	savedCamera = nil
	-- Retour au camp : la fenêtre des niveaux s'ouvre (pièces gagnées, boutique, niveau suivant).
	if player:GetAttribute("LevelsAccess") == true then
		camp.open("Niveaux")
	end
end

local function enterLevel(index: number)
	if level.active and level.index == index then
		return
	end
	if level.active then
		exitLevel()
	end
	level.active = true
	level.index = index
	level.slot = Levels.slotOf(index)
	level.cframe = Levels.arenaCFrame(level.slot)
	level.folder = nil
	level.geometry, level.mapName = nil, nil
	level.runState, level.number, level.resultShown = nil, nil, nil
	level.cameraKey = ""
	level.zoom, level.pan = 1, Vector2.zero
	camp.close()
	local camera = workspace.CurrentCamera
	if camera then
		savedCamera = { type = camera.CameraType, fov = camera.FieldOfView }
	end
	hud.gui.Enabled = true
	hideOtherGuis()
	setControls(false)
	ProximityLabel.setFocus(level.cframe.Position, LABEL_RADIUS)
	helpers.Parent = workspace
end

-- Un niveau vient de démarrer dans la zone (premier niveau, « Niveau suivant », « Rejouer »).
local function onLevelStart(number: number)
	level.startedAt = os.clock()
	level.upgraded = false
	level.quitArmedAt = nil
	level.resultShown = nil
	setView(1, Vector2.zero)
	hud.resetCounters()
	selectTower(nil)
	-- Tout premier niveau : la première tour de la barre est déjà choisie, les « + » sont affichés.
	level.firstTime = number == 1 and state.best == 0
	setPlacing(if level.firstTime then state.towers[1] else nil)
	hud.hideEnd()
end

----------------------------------------------------------------------
-- Écran du niveau
----------------------------------------------------------------------

local function buildHud()
	local gui = UI.screen("LevelHud", 24)
	gui:SetAttribute("NoTranslate", true)
	gui.Enabled = false
	hud.gui = gui

	-- Bandeau du haut : niveau, vies, or, avancée du flot de monstres, x2, quitter.
	local strip = UI.new("Frame", {
		Name = "TopStrip",
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.1,
		Active = true,
		Parent = gui,
	}, { UI.corner(10) })
	UI.stroke(UI.Colors.Gold, 1).Parent = strip
	local levelLabel = UI.label({ Name = "Level", Font = Enum.Font.GothamBlack, MaxTextSize = 18, Parent = strip })
	local livesLabel = UI.label({ Name = "Lives", Font = Enum.Font.GothamBlack, TextColor3 = UI.Colors.DangerText, MaxTextSize = 18, Parent = strip })
	local goldLabel = UI.label({ Name = "Gold", Font = Enum.Font.GothamBlack, TextColor3 = UI.Colors.Gold, MaxTextSize = 20, Parent = strip })
	local progress, setProgress = UI.bar({ Name = "Progress" }, UI.Colors.Success)
	progress.Parent = strip
	local progressFill = progress:FindFirstChildOfClass("Frame") :: Frame
	progressFill.Name = "Fill"
	local progressLabel = UI.label({
		Name = "ProgressText",
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.GothamBold,
		TextStrokeTransparency = 0.4,
		MaxTextSize = 14,
		ZIndex = 2,
		Parent = progress,
	})
	local speedButton = UI.button({ Name = "Speed", MaxTextSize = 16, Parent = strip })
	local quitButton = UI.button({ Name = "Quit", BackgroundColor3 = UI.Colors.Error, Text = "X", MaxTextSize = 16, Parent = strip })

	-- Barre rapide : les tours débloquées, dans l'ordre choisi par le joueur.
	local bar = UI.new("Frame", {
		Name = "TowerBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.fromOffset(0, BAR_BUTTON.Y),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, BAR_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local barScale = UI.new("UIScale", { Parent = bar }) :: UIScale
	local barButtons = {}
	local phoneBar = false -- (barre basse du téléphone : voir layout)
	for _, towerType in IdleTowers.ORDER do
		local def = IdleTowers.Defs[towerType]
		local button = UI.button({
			Name = "Tower_" .. towerType,
			Size = UDim2.fromOffset(BAR_BUTTON.X, BAR_BUTTON.Y),
			BackgroundColor3 = def.color:Lerp(UI.Colors.Panel, 0.6),
			Text = "",
			Visible = false,
			Parent = bar,
		})
		local stroke = button:FindFirstChildOfClass("UIStroke") :: UIStroke
		stroke.Thickness = 2
		local name = UI.label({
			Name = "TowerName",
			Size = UDim2.new(1, 0, 0, 17),
			Font = Enum.Font.GothamBlack,
			MaxTextSize = 14,
			Text = SHORT_NAMES[towerType],
			Parent = button,
		})
		local cost = UI.label({
			Name = "Cost",
			Position = UDim2.fromOffset(0, 18),
			Size = UDim2.new(1, 0, 0, 18),
			Font = Enum.Font.GothamBold,
			MaxTextSize = 15,
			Parent = button,
		})
		local copies = UI.label({
			Name = "Copies",
			Position = UDim2.fromOffset(0, 37),
			Size = UDim2.new(1, 0, 0, 13),
			TextColor3 = UI.Colors.Muted,
			MaxTextSize = 11,
			Parent = button,
		})
		button.Activated:Connect(function()
			if drag.active then
				return -- (fin d'un glisser : déjà traité)
			end
			barTap(towerType)
		end)
		-- Téléphone : glisser la tour depuis la barre jusqu'au terrain (suivi dans TouchMoved / TouchEnded).
		button.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				drag.input, drag.towerType, drag.origin, drag.active = input, towerType, input.Position, false
			end
		end)
		barButtons[towerType] = { button = button, stroke = stroke, name = name, cost = cost, copies = copies, color = button.BackgroundColor3 }
	end

	local hint = UI.label({
		Name = "Hint",
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(560, 24),
		Font = Enum.Font.GothamBold,
		TextStrokeTransparency = 0.25,
		MaxTextSize = 17,
		Text = "",
		Parent = gui,
	})

	-- Petit menu de la tour choisie, à côté d'elle.
	local menu = UI.new("Frame", {
		Name = "TowerMenu",
		Size = UDim2.fromOffset(MENU_SIZE.X, MENU_SIZE.Y),
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.05,
		Active = true,
		Visible = false,
		Parent = gui,
	}, { UI.corner(10), UI.padding(8) })
	local menuStroke = UI.stroke(UI.Colors.Gold, 2)
	menuStroke.Transparency = 0.2
	menuStroke.Parent = menu
	local menuScale = UI.new("UIScale", { Parent = menu }) :: UIScale
	local menuTitle = UI.label({
		Name = "Title",
		Size = UDim2.new(1, 0, 0, 20),
		Font = Enum.Font.GothamBlack,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 16,
		Parent = menu,
	})
	local menuStats = UI.label({
		Name = "Stats",
		Position = UDim2.fromOffset(0, 22),
		Size = UDim2.new(1, 0, 0, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		TextColor3 = UI.Colors.Muted,
		MaxTextSize = 13,
		Parent = menu,
	})
	local upgradeButton = UI.button({
		Name = "Upgrade",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(0.62, -4, 0, 42),
		BackgroundColor3 = UI.Colors.Success,
		MaxTextSize = 15,
		Parent = menu,
	})
	local sellButton = UI.button({
		Name = "Sell",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 1, 0),
		Size = UDim2.new(0.38, -4, 0, 42),
		BackgroundColor3 = UI.Colors.Error,
		MaxTextSize = 14,
		Parent = menu,
	})
	upgradeButton.Activated:Connect(upgradeSelected)
	sellButton.Activated:Connect(sellSelected)

	-- Écran de fin.
	local overlay = UI.new("TextButton", {
		Name = "EndScreen",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.5,
		AutoButtonColor = false,
		Text = "",
		Visible = false,
		ZIndex = 5,
		Parent = gui,
	})
	local panel = UI.new("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(END_SIZE.X, END_SIZE.Y),
		BackgroundColor3 = UI.Colors.Panel,
		ZIndex = 5,
		Parent = overlay,
	}, { UI.corner(16), UI.padding(16) })
	local panelStroke = UI.stroke(UI.Colors.Gold, 3)
	panelStroke.Transparency = 0
	panelStroke.Parent = panel
	UI.fitWindow(panel, END_SIZE)
	local endTitle = UI.label({
		Name = "Title",
		Size = UDim2.new(1, 0, 0, 44),
		Font = Enum.Font.GothamBlack,
		MaxTextSize = 36,
		ZIndex = 5,
		Parent = panel,
	})
	local endReward = UI.label({
		Name = "Reward",
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 0, 34),
		Font = Enum.Font.GothamBlack,
		TextColor3 = UI.Colors.Gold,
		MaxTextSize = 28,
		ZIndex = 5,
		Parent = panel,
	})
	local endDetails = UI.label({
		Name = "Details",
		Position = UDim2.fromOffset(0, 90),
		Size = UDim2.new(1, 0, 1, -90 - 112),
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		MaxTextSize = 16,
		ZIndex = 5,
		Parent = panel,
	})
	local nextButton = UI.button({
		Name = "Next",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -50),
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundColor3 = UI.Colors.Success,
		MaxTextSize = 24,
		ZIndex = 5,
		Parent = panel,
	})
	local replayButton = UI.button({
		Name = "Replay",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(0.5, -4, 0, 42),
		Text = "Rejouer",
		MaxTextSize = 18,
		ZIndex = 5,
		Parent = panel,
	})
	local campButton = UI.button({
		Name = "Camp",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 1, 0),
		Size = UDim2.new(0.5, -4, 0, 42),
		BackgroundColor3 = UI.Colors.PanelLight,
		Text = "⛺ Retour au camp",
		MaxTextSize = 18,
		ZIndex = 5,
		Parent = panel,
	})
	local endResult = nil -- résultat affiché (table décodée de l'attribut « Result »)
	nextButton.Activated:Connect(function()
		if endResult and not (endResult.won and not endResult.nextLevel) then
			-- Gagné : le niveau suivant. Perdu : le bouton principal relance le même niveau. (Dernier niveau gagné : le
			-- bouton dit seulement que tout est réussi.)
			levelAction:FireServer("Start", if endResult.won and endResult.nextLevel then endResult.nextLevel else endResult.level)
		end
	end)
	replayButton.Activated:Connect(function()
		if endResult then
			levelAction:FireServer("Start", endResult.level)
		end
	end)
	campButton.Activated:Connect(function()
		levelAction:FireServer("Quit")
	end)

	function hud.hideEnd()
		overlay.Visible = false
		endResult = nil
	end

	local function showEnd(result)
		endResult = result
		local won = result.won == true
		endTitle.Text = if won then "VICTOIRE !" else "DÉFAITE"
		endTitle.TextColor3 = if won then UI.Colors.PositiveText else UI.Colors.DangerText
		endReward.Text = `+{amount(tonumber(result.reward) or 0)} {COIN}`
		local lines = {}
		if won then
			table.insert(lines, if result.firstClear then `Niveau {result.level} réussi pour la première fois !` else `Niveau {result.level} réussi une fois de plus.`)
			table.insert(lines, `Vies restantes : {result.lives}/{Levels.LIVES}`)
		else
			table.insert(lines, `Niveau {result.level} : {result.kills} monstres éliminés sur {result.total}.`)
			-- Perdu avec de l'or en poche : c'est la raison la plus fréquente, on la dit avec son chiffre.
			local unspent = numberAttribute("Gold")
			if unspent >= IDLE_GOLD then
				table.insert(lines, `Il te restait {amount(unspent)} {GOLD} : dépense ton or au fur et à mesure, les monstres deviennent plus forts sans arrêt.`)
			else
				table.insert(lines, "Les monstres deviennent plus forts sans arrêt : pose et améliore tes tours du début à la fin, sans garder ton or.")
			end
			table.insert(lines, "La boutique et le camp d'entraînement aident aussi.")
		end
		local xp = tonumber(result.xp) or 0
		if xp > 0 and typeof(result.towers) == "table" and #result.towers > 0 then
			table.insert(lines, `Tes tours posées gagnent +{UI.decimal(xp)} XP d'entraînement.`)
		end
		for _, perk in if typeof(result.perks) == "table" then result.perks else {} do
			local def = IdleTowers.Defs[perk.tower]
			table.insert(lines, `⭐ ÉVOLUTION ! {if def then def.displayName else "Tour"} : {perk.name}`)
		end
		endDetails.Text = table.concat(lines, "\n")
		local canNext = won and result.nextLevel ~= nil
		nextButton.Text = if canNext then `Niveau {result.nextLevel} ▶` else if won then "Tous les niveaux sont réussis !" else "Réessayer"
		nextButton.BackgroundColor3 = if canNext or not won then UI.Colors.Success else UI.Colors.Panel
		nextButton.AutoButtonColor = canNext or not won
		-- (perdu : « Réessayer » est le gros bouton, « Rejouer » ferait double emploi)
		replayButton.Visible = won
		campButton.Size = if won then UDim2.new(0.5, -4, 0, 42) else UDim2.new(1, 0, 0, 42)
		overlay.Visible = true
		SoundManager.play(if won then "MatchVictory" else "MatchDefeat")
	end

	-- Marges de l'écran prises par les bandeaux (px, dans l'image de la caméra) : la carte tient entre elles.
	local topMargin, bottomMargin = 60, 100
	function hud.margins()
		return { top = topMargin, bottom = bottomMargin, left = 10, right = 10 }
	end

	local function layout()
		local screen = UI.screenSize(gui)
		if screen.X <= 0 or screen.Y <= 0 then
			return
		end
		local phone = UI.touchLayout(screen)
		local inset = (GuiService:GetGuiInset()).Y
		local height = if phone then 34 else 42
		local left, top, width = 8, 6, screen.X - 16
		if phone and screen.X > screen.Y and inset >= height + 8 then
			-- Téléphone tenu en large : le bandeau se range dans la barre du haut de Roblox, à droite de ses boutons.
			left, top = PHONE_STRIP_LEFT, -inset + math.floor((inset - height) / 2)
			width = screen.X - left - 8
		elseif width > 780 then
			left, width = math.floor((screen.X - 780) / 2), 780
		end
		strip.Position = UDim2.fromOffset(left, top)
		strip.Size = UDim2.fromOffset(width, height)
		local gap, pad = 6, 6
		local widths = if phone
			then { level = 76, lives = 48, gold = 66, speed = 38, quit = 34 }
			else { level = 110, lives = 70, gold = 96, speed = 52, quit = 42 }
		local x = pad
		local function place(object: GuiObject, itemWidth: number)
			object.Position = UDim2.fromOffset(x, 4)
			object.Size = UDim2.fromOffset(itemWidth, height - 8)
			x += itemWidth + gap
		end
		place(levelLabel, widths.level)
		place(livesLabel, widths.lives)
		place(goldLabel, widths.gold)
		local fixed = widths.speed + widths.quit + 2 * gap + pad
		place(progress, math.max(40, width - x - fixed))
		place(speedButton, widths.speed)
		place(quitButton, widths.quit)

		-- Barre des tours : plus basse sur téléphone (le nom et le prix seulement), réduite si elle est trop large.
		phoneBar = phone
		local buttonSize = if phone then BAR_BUTTON_PHONE else BAR_BUTTON
		for _, entry in barButtons do
			entry.button.Size = UDim2.fromOffset(buttonSize.X, buttonSize.Y)
			entry.name.Size = UDim2.new(1, 0, 0, if phone then 15 else 17)
			entry.cost.Position = UDim2.fromOffset(0, if phone then 16 else 18)
			entry.cost.Size = UDim2.new(1, 0, 0, if phone then 16 else 18)
			entry.copies.Visible = not phone
		end
		bar.Size = UDim2.fromOffset(0, buttonSize.Y)
		local count = math.max(1, #state.towers)
		local barWidth = count * buttonSize.X + (count - 1) * BAR_GAP
		barScale.Scale = math.clamp((screen.X - 16) / barWidth, 0.5, 1)
		local barHeight = buttonSize.Y * barScale.Scale
		hint.Position = UDim2.new(0.5, 0, 1, -(8 + barHeight + 3))
		hint.Size = UDim2.fromOffset(math.min(620, screen.X - 16), if phone then 18 else 24)
		menuScale.Scale = if phone then MENU_PHONE_SCALE else 1
		-- (bandeau rangé dans la barre de Roblox : la carte peut monter jusque sous lui)
		topMargin = math.max(4, inset + top + height) + 6
		bottomMargin = 8 + barHeight + 3 + hint.Size.Y.Offset + 4
	end
	hud.layout = layout
	layout()
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)

	speedButton.Activated:Connect(toggleSpeed)
	function hud.quit()
		-- Niveau fini : retour direct. En cours : un deuxième appui confirme l'abandon.
		if attribute("State") ~= "Running" or (level.quitArmedAt and os.clock() - level.quitArmedAt < QUIT_CONFIRM) then
			levelAction:FireServer("Quit")
			level.quitArmedAt = nil
		else
			level.quitArmedAt = os.clock()
			UI.toast("Appuie encore sur X pour abandonner ce niveau", "Warning")
		end
	end
	quitButton.Activated:Connect(hud.quit)

	-- Mise à jour à chaque image (textes changés seulement quand leur valeur change).
	local shown = {}
	local function set(object: any, property: string, value: any)
		local key = object.Name .. property
		if shown[key] ~= value then
			shown[key] = value
			object[property] = value
		end
	end
	local barOrder = ""
	-- Or gagné : le compteur clignote en blanc. Vie perdue (un monstre a atteint le château) : le compteur des vies
	-- clignote et un son prévient. (Valeurs d'avant oubliées à chaque nouveau niveau : hud.resetCounters.)
	local lastGold: number? = nil
	local lastLives: number? = nil
	local function flash(label: TextLabel, color: Color3)
		label.TextColor3 = Color3.new(1, 1, 1)
		TweenService:Create(label, TweenInfo.new(0.35), { TextColor3 = color }):Play()
	end
	-- Or qui dort : heure depuis laquelle le joueur garde de quoi acheter sans rien acheter (nil = il dépense).
	local richSince: number? = nil
	local nextRichCheck = 0
	local function canBuySomething(gold: number): boolean
		for _, towerType in state.towers do
			if gold >= Levels.placeCost(towerType) and copiesOf(towerType) < Levels.maxCopies(towerType) then
				return true
			end
		end
		for _, model in towerModels() do
			local cost = Levels.upgradeCost(model:GetAttribute("TowerType"), model:GetAttribute("Level") or 1)
			if cost and gold >= cost then
				return true
			end
		end
		return false
	end
	function hud.resetCounters()
		lastGold, lastLives = nil, nil
		richSince = nil
	end

	function hud.update()
		local gold = numberAttribute("Gold")
		local total = numberAttribute("Total")
		local left = numberAttribute("Left")
		local lives = numberAttribute("Lives")
		local running = attribute("State") == "Running"
		if running and lastGold and gold > lastGold then
			flash(goldLabel, UI.Colors.Gold)
		end
		if lastLives and lives < lastLives then
			flash(livesLabel, UI.Colors.DangerText)
			SoundManager.play("Error")
		end
		lastGold, lastLives = gold, lives
		set(levelLabel, "Text", `NIVEAU {numberAttribute("Level")}`)
		set(livesLabel, "Text", `❤ {lives}`)
		set(goldLabel, "Text", `{GOLD} {amount(gold)}`)
		setProgress(if total > 0 then 1 - left / total else 0)
		set(progressLabel, "Text", if total > 0 then `Monstres : {left} / {total}` else "")
		-- Le flot devient plus dur du début à la fin du niveau : la barre passe du vert à l'orange, puis au rouge.
		local stream = math.clamp(numberAttribute("Progress") / 100, 0, 1)
		set(progressFill, "BackgroundColor3", if stream < 0.5
			then UI.Colors.Success:Lerp(UI.Colors.Warning, stream * 2)
			else UI.Colors.Warning:Lerp(UI.Colors.Error, (stream - 0.5) * 2))
		local fast = numberAttribute("SimSpeed") >= IdleConfig.SPEED_PASS_FACTOR
		set(speedButton, "Text", if fast then "x2" else "x1")
		set(speedButton, "BackgroundColor3", if fast then UI.Colors.Warning else UI.Colors.Accent)
		set(quitButton, "Text", if level.quitArmedAt and os.clock() - level.quitArmedAt < QUIT_CONFIRM then "X ?" else "X")

		-- Barre rapide.
		local order = table.concat(state.towers, ",")
		if order ~= barOrder then
			barOrder = order
			for _, towerType in IdleTowers.ORDER do
				local entry = barButtons[towerType]
				local index = table.find(state.towers, towerType)
				entry.button.Visible = index ~= nil
				entry.button.LayoutOrder = index or 99
			end
			layout()
		end
		for index, towerType in state.towers do
			local entry = barButtons[towerType]
			if entry then
				local cost = Levels.placeCost(towerType)
				local copies, limit = copiesOf(towerType), Levels.maxCopies(towerType)
				local available = running and gold >= cost and copies < limit
				-- La tour en main : son bouton devient rouge et dit « ANNULER » (un appui dessus annule la pose).
				local held = level.placing == towerType
				-- (téléphone : pas de ligne « 2/5 » ; à la limite, « MAX » remplace le prix)
				entry.cost.Text = if held then "ANNULER" else if phoneBar and copies >= limit then "MAX" else `{cost} {GOLD}`
				entry.cost.TextColor3 = if held
					then Color3.new(1, 1, 1)
					else if gold >= cost and copies < limit then UI.Colors.Gold else UI.Colors.DangerText
				entry.copies.Text = `{copies}/{limit}` .. (if UserInputService.KeyboardEnabled then `  [{index}]` else "")
				entry.copies.TextColor3 = if held then Color3.new(1, 1, 1) else if copies >= limit then UI.Colors.DangerText else UI.Colors.Muted
				entry.button.BackgroundColor3 = if held then UI.Colors.Error else entry.color
				entry.button.BackgroundTransparency = if held or available then 0 else 0.45
				entry.name.TextTransparency = if held or available then 0 else 0.35
				entry.stroke.Transparency = if held then 0 else 0.7
				entry.stroke.Color = if held then Color3.new(1, 1, 1) else UI.Colors.Gold
			end
		end

		-- Conseil au-dessus de la barre.
		if os.clock() >= nextRichCheck then
			nextRichCheck = os.clock() + 0.5
			if running and gold >= IDLE_GOLD and canBuySomething(gold) then
				richSince = richSince or os.clock()
			else
				richSince = nil
			end
		end
		local text = ""
		if running then
			local placingDef = level.placing and IdleTowers.Defs[level.placing]
			if level.firstTime and #towerModels() <= 1 then
				text = "Ton Archer tire déjà ! Touche un « + » pour en poser un deuxième"
			elseif level.firstTime and not level.upgraded and not level.selected and not level.placing then
				text = "Touche une tour pour l'améliorer avec ton or"
			elseif placingDef then
				text = `Touche le terrain (ou un « + ») pour poser : {placingDef.displayName}. Changer d'avis : « Annuler »`
			elseif not level.selected and richSince and os.clock() - richSince > IDLE_GOLD_SECONDS then
				-- Le niveau ne se gagne qu'en réinvestissant son or sans arrêt : on le dit à celui qui le garde.
				text = "Ne garde pas ton or : pose ou améliore une tour, les monstres deviennent de plus en plus forts !"
			end
		end
		set(hint, "Text", text)

		-- Menu de la tour choisie.
		local model = level.selected
		if model and not model.Parent then
			selectTower(nil)
			model = nil
		end
		if model and running then
			local towerType = model:GetAttribute("TowerType")
			local towerLevel = model:GetAttribute("Level") or 1
			local def = IdleTowers.Defs[towerType]
			local stats = Levels.towerStats(towerType, towerLevel, trainingOf(towerType))
			local cost = Levels.upgradeCost(towerType, towerLevel)
			local refund = math.floor((model:GetAttribute("Spent") or 0) * Levels.SELL_REFUND)
			menuTitle.Text = `{def.displayName} • niv. {towerLevel}`
			menuTitle.TextColor3 = def.color:Lerp(Color3.new(1, 1, 1), 0.4)
			if cost then
				local nextStats = Levels.towerStats(towerType, towerLevel + 1, trainingOf(towerType))
				menuStats.Text = `{statsLine(stats)}\nNiveau suivant : dégâts {decimal(nextStats.damage)}`
				upgradeButton.Text = `⬆ Améliorer {amount(cost)} {GOLD}`
				upgradeButton.BackgroundTransparency = if gold >= cost then 0 else 0.55
			else
				menuStats.Text = statsLine(stats)
				upgradeButton.Text = "NIVEAU MAX"
				upgradeButton.BackgroundTransparency = 0.55
			end
			sellButton.Text = `Vendre +{amount(refund)}`
			-- À côté de la tour : au-dessus d'elle s'il y a la place, sinon en dessous ; jamais hors de l'écran, ni
			-- sur le bandeau du haut ou la barre des tours.
			local camera = workspace.CurrentCamera
			local screen = UI.screenSize(gui)
			local world = level.cframe:PointToWorldSpace(towerLocal(model))
			local topPoint = camera:WorldToScreenPoint(world + Vector3.new(0, 7, 0))
			local footPoint = camera:WorldToScreenPoint(world)
			local menuSize = MENU_SIZE * menuScale.Scale
			local topLimit = math.max(2, topMargin - (GuiService:GetGuiInset()).Y)
			local bottomLimit = screen.Y - bottomMargin
			local above = topPoint.Y - menuSize.Y - 6 >= topLimit
			local x = math.clamp(topPoint.X, menuSize.X / 2 + 6, math.max(menuSize.X / 2 + 6, screen.X - menuSize.X / 2 - 6))
			local y = if above then topPoint.Y - 6 - menuSize.Y else footPoint.Y + 16
			menu.AnchorPoint = Vector2.new(0.5, 0)
			menu.Position = UDim2.fromOffset(x, math.clamp(y, topLimit, math.max(topLimit, bottomLimit - menuSize.Y)))
			menu.Visible = true
			hud.showRange(world, stats.range)
		else
			menu.Visible = false
			selectRing.Parent = nil
		end

		-- Écran de fin : dès que le serveur publie le résultat.
		local raw = attribute("Result")
		if typeof(raw) == "string" then
			if raw ~= level.resultShown then
				level.resultShown = raw
				local ok, decoded = pcall(function()
					return HttpService:JSONDecode(raw)
				end)
				if ok and typeof(decoded) == "table" then
					setPlacing(nil)
					selectTower(nil)
					showEnd(decoded)
				end
			end
		elseif overlay.Visible then
			level.resultShown = nil
			hud.hideEnd()
		end
	end
end

----------------------------------------------------------------------
-- Aperçu de pose, « + » conseillés
----------------------------------------------------------------------

local function buildHelpers()
	local function helper(name: string, shape: Enum.PartType, transparency: number): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Shape = shape
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.Neon
		part.Transparency = transparency
		return part
	end
	ghost = helper("TowerGhost", Enum.PartType.Block, 0.4)
	ghost.Size = Vector3.new(2.4, 3.4, 2.4)
	-- Cercles de portée : une plaque invisible posée sur le sol, avec un anneau dessiné dessus (un disque plein
	-- cachait le chemin et les monstres).
	local function ring(name: string): Part
		local part = helper(name, Enum.PartType.Block, 1)
		local surface = UI.new("SurfaceGui", {
			Name = "Ring",
			Face = Enum.NormalId.Top,
			CanvasSize = Vector2.new(512, 512),
			LightInfluence = 0,
			Parent = part,
		})
		UI.new("Frame", {
			Name = "Circle",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -16, 1, -16),
			BackgroundTransparency = 0.88,
			Parent = surface,
		}, { UI.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }), UI.new("UIStroke", { Name = "Edge", Thickness = 7, Transparency = 0.1 }) })
		return part
	end
	ghostRing = ring("GhostRange")
	selectRing = ring("SelectedRange")
	for index = 1, PLUS_MARKERS do
		local anchor = helper("Plus" .. index, Enum.PartType.Block, 1)
		anchor.Size = Vector3.one
		local billboard = UI.new("BillboardGui", {
			Name = "PlusMarker",
			Size = UDim2.fromOffset(30, 30),
			AlwaysOnTop = true,
			Adornee = anchor,
			Parent = anchor,
		}, {
			UI.new("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = UI.Colors.Gold,
				BackgroundTransparency = 0.1,
				Font = Enum.Font.GothamBlack,
				Text = "+",
				TextColor3 = Color3.fromRGB(40, 30, 10),
				TextScaled = true,
			}, { UI.corner(15), UI.stroke(Color3.new(1, 1, 1), 2) }),
		})
		plusMarkers[index] = { anchor = anchor, billboard = billboard }
	end
end

-- Pose un cercle de portée (voir buildHelpers) autour d'un point du sol, à la couleur donnée.
local function placeRing(part: Part, world: Vector3, range: number, color: Color3)
	part.Size = Vector3.new(range * 2, 0.1, range * 2)
	part.CFrame = CFrame.new(world + Vector3.new(0, 0.3, 0))
	local circle = part:FindFirstChild("Ring") and (part :: any).Ring:FindFirstChild("Circle")
	if circle then
		circle.BackgroundColor3 = color
		circle.Edge.Color = color
	end
	part.Parent = helpers
end

local function showGhost(towerType: string, point: Vector3)
	local ok = canPlace(towerType, point)
	local color = if ok then UI.Colors.PositiveText else UI.Colors.DangerText
	local world = level.cframe:PointToWorldSpace(point)
	local range = Levels.towerStats(towerType, 1, trainingOf(towerType)).range
	ghost.Color = color
	ghost.CFrame = CFrame.new(world + Vector3.new(0, 1.7, 0))
	ghost.Parent = helpers
	placeRing(ghostRing, world, range, color)
end

local function hideGhost()
	ghost.Parent = nil
	ghostRing.Parent = nil
end

-- Portée de la tour choisie (appelée par le menu de la tour, hud.update).
function hud.showRange(world: Vector3, range: number)
	placeRing(selectRing, world, range, UI.Colors.Gold)
end

-- Or gagné : un petit « +2 » doré s'envole au-dessus du monstre tué (plus gros pour un mini-boss ou un boss).
-- GOLD_POPUPS à la fois au plus : une vague écrasée d'un coup ne couvre pas l'écran de chiffres.
local goldPopups = 0
local function goldPopup(position: Vector3, gold: number, big: boolean)
	if goldPopups >= GOLD_POPUPS then
		return
	end
	goldPopups += 1
	local anchor = Instance.new("Part")
	anchor.Name = "GoldPopup"
	anchor.Size = Vector3.one * 0.2
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Position = position + Vector3.new(0, 2.5, 0)
	local billboard = UI.new("BillboardGui", {
		Size = if big then UDim2.fromOffset(120, 32) else UDim2.fromOffset(56, 20),
		AlwaysOnTop = true,
		Parent = anchor,
	})
	local label = UI.new("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Text = `+{amount(gold)}`,
		TextColor3 = UI.Colors.Gold,
		TextScaled = true,
		TextStrokeTransparency = 0.25,
		Parent = billboard,
	})
	anchor.Parent = helpers
	local info = TweenInfo.new(0.8)
	TweenService:Create(anchor, info, { Position = anchor.Position + Vector3.new(0, 3.5, 0) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(0.85, function()
		goldPopups -= 1
		anchor:Destroy()
	end)
end

-- Texte doré qui s'envole au-dessus d'un point de la parcelle (camp d'entraînement : « +0,3 XP » d'une tour).
local function campPopup(position: Vector3, text: string)
	local anchor = Instance.new("Part")
	anchor.Name = "CampPopup"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	anchor.Position = position
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(110, 28)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 140
	billboard.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = UI.Colors.Gold
	label.TextStrokeTransparency = 0.2
	label.Text = text
	label.Parent = billboard
	anchor.Parent = workspace
	local info = TweenInfo.new(1.4)
	TweenService:Create(anchor, info, { Position = position + Vector3.new(0, 4, 0) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(1.5, function()
		anchor:Destroy()
	end)
end

-- Aperçu de pose : il suit la souris (ordinateur) ou le doigt pendant un glisser (téléphone).
local function updatePlacing()
	local placing = level.placing
	local running = attribute("State") == "Running"
	local spots = if placing and running then freeSpots() else {}
	for index, marker in plusMarkers do
		local spot = spots[index]
		if spot then
			marker.anchor.CFrame = CFrame.new(level.cframe:PointToWorldSpace(Vector3.new(spot.X, 0.6, spot.Z)))
			marker.anchor.Parent = helpers
		else
			marker.anchor.Parent = nil
		end
	end
	if not placing or not running then
		hideGhost()
		return
	end
	local camera = workspace.CurrentCamera
	local ray = nil
	if drag.active and drag.input then
		ray = camera:ScreenPointToRay(drag.input.Position.X, drag.input.Position.Y)
	elseif UserInputService.MouseEnabled and not UserInputService.TouchEnabled then
		local mouse = UserInputService:GetMouseLocation()
		ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	elseif UserInputService.MouseEnabled and UserInputService:GetLastInputType() ~= Enum.UserInputType.Touch then
		local mouse = UserInputService:GetMouseLocation()
		ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	end
	local point = ray and localGround(ray)
	if point then
		showGhost(placing, snap(point))
	else
		hideGhost()
	end
end

----------------------------------------------------------------------
-- Démarrage
----------------------------------------------------------------------

-- Tests automatiques (Studio) : gui:SetAttribute("TestAction", "<commande>#<numéro>") fait comme le joueur.
--   écran « Levels »   : "Open", "Close", "Tab:Boutique", "Slot:2" (invite du socle d'entraînement 2 du camp)
--   écran « LevelHud » : "Select:MachineGun" (tour en main), "Bar:MachineGun" (appui sur son bouton de la barre :
--                        la prendre, ou annuler si elle est déjà en main), "Tap:-23,0" (appui sur ce point local
--                        du terrain, par le vrai chemin : point de l'écran -> rayon de la caméra -> sol), "Upgrade",
--                        "Sell", "Speed", "Quit", "Next", "Replay", "Camp", "Zoom:2" (zoom voulu), "Pan:120,-40"
--                        (glissement de la vue en pixels, comme un doigt), "Pitch:70" (inclinaison imposée de la
--                        caméra en degrés, 90 = pile au-dessus ; "Pitch:" = de nouveau le réglage normal)
local function testAction(command: string)
	local name, argument = string.match(command, "^(%a+):?([^#]*)")
	if name == "Open" then
		camp.open("Niveaux")
	elseif name == "Close" then
		camp.close()
	elseif name == "Tab" then
		camp.open(argument)
	elseif name == "Slot" then
		-- (comme l'invite « Gérer » d'un socle d'entraînement de la parcelle)
		camp.open("Entraînement", tonumber(argument))
	elseif not level.active then
		return
	elseif name == "Select" then
		setPlacing(if argument ~= "" and owns(argument) then argument else nil)
	elseif name == "Bar" then
		if owns(argument) then
			barTap(argument)
		end
	elseif name == "Tap" then
		local x, z = string.match(argument, "^(-?[%d%.]+),(-?[%d%.]+)$")
		local camera = workspace.CurrentCamera
		if x and camera then
			local world = level.cframe:PointToWorldSpace(Vector3.new(tonumber(x), 0, tonumber(z)))
			local point = camera:WorldToScreenPoint(world)
			tapScreen(Vector3.new(point.X, point.Y, 0))
		end
	elseif name == "Pitch" then
		local degrees = tonumber(argument)
		level.pitchOverride = if degrees then math.clamp(degrees, 20, 90) else nil
		level.cameraKey = ""
	elseif name == "Zoom" then
		setView(tonumber(argument) or 1, level.pan)
	elseif name == "Pan" then
		local dx, dy = string.match(argument, "^(-?[%d%.]+),(-?[%d%.]+)$")
		if dx then
			panByPixels(tonumber(dx), tonumber(dy))
		end
	elseif name == "Upgrade" then
		upgradeSelected()
	elseif name == "Sell" then
		sellSelected()
	elseif name == "Speed" then
		toggleSpeed()
	elseif name == "Quit" then
		hud.quit()
	elseif name == "Next" or name == "Replay" or name == "Camp" then
		local button = hud.gui.EndScreen.Panel:FindFirstChild(name)
		local raw = attribute("Result")
		local ok, result = pcall(function()
			return HttpService:JSONDecode(raw)
		end)
		if name == "Camp" then
			levelAction:FireServer("Quit")
		elseif button and ok and typeof(result) == "table" then
			levelAction:FireServer("Start", if name == "Next" and result.won and result.nextLevel then result.nextLevel else result.level)
		end
	end
end

local function build()
	levelAction = Remotes.get("LevelAction")
	readState()
	buildHelpers()
	buildCamp()
	buildHud()
	-- Monstre tué dans ma zone de combat : l'or qu'il donne s'affiche au-dessus de lui.
	PlotRenderer.onEnemyKilled = function(plotIndex: number, enemyType: string, position: Vector3)
		local enemy = Levels.ENEMY[enemyType]
		if level.active and plotIndex == level.index and enemy then
			goldPopup(position, enemy.gold, enemyType == "Giant" or enemyType == "Boss")
		end
	end

	-- Entraînement qui avance pendant que le joueur est là : « +X XP » au-dessus de la tour, sur sa parcelle (son
	-- camp), et une annonce quand elle monte d'un niveau d'entraînement ou qu'elle ÉVOLUE.
	local function campTower(slotIndex: number): Model?
		local plot = CampMode.plotFolder()
		local towers = plot and plot:FindFirstChild("Towers")
		for _, model in if towers then towers:GetChildren() else {} do
			if model:IsA("Model") and model:GetAttribute("CampSlot") == slotIndex then
				return model
			end
		end
		return nil
	end
	local function announceTraining(before, after)
		for _, towerType in after.towers do
			local oldLevel = Levels.trainingLevel(before.xp[towerType])
			local newLevel = Levels.trainingLevel(after.xp[towerType])
			if newLevel > oldLevel and table.find(before.towers, towerType) and not level.active then
				local def = IdleTowers.Defs[towerType]
				local gained = Levels.perksBetween(towerType, oldLevel, newLevel)
				if #gained > 0 then
					UI.toast(`⭐ ÉVOLUTION ! {def.displayName} : {gained[#gained].name}`, "Success")
					SoundManager.play("MatchVictory")
				else
					UI.toast(`{def.displayName} : entraînement {newLevel} (+{math.floor(Levels.TRAINING.DAMAGE_PER_LEVEL * 100 + 0.5)} % de dégâts)`, "Success")
					SoundManager.play("TowerUpgraded")
				end
			end
		end
		if not CampMode.active() or level.active then
			return
		end
		for slotIndex, slot in after.slots do
			local previous = before.slots[slotIndex]
			local gain = (tonumber(after.xp[slot.tower]) or 0) - (tonumber(before.xp[slot.tower]) or 0)
			local model = if previous and previous.tower == slot.tower and gain > 0.04 then campTower(slotIndex) else nil
			if model then
				campPopup(model:GetPivot().Position + Vector3.new(0, 8, 0), `+{UI.decimal(math.floor(gain * 10 + 0.5) / 10)} XP`)
			end
		end
	end

	local stateReads = 0
	player:GetAttributeChangedSignal("LevelsState"):Connect(function()
		local before = state
		readState()
		stateReads += 1
		if stateReads > 1 then
			announceTraining(before, state)
		end
		camp.refresh()
		hud.layout()
	end)

	-- Parcelle devenue CAMP D'ENTRAÎNEMENT (CampMode.luau) : les écrans du jeu infini sont cachés ; ils reviennent si
	-- la parcelle redevient celle du jeu infini (accès aux niveaux retiré).
	local campHidden = {} -- [ScreenGui] = vrai : cachés par le camp
	task.spawn(function()
		while true do
			if CampMode.active() then
				for _, name in INFINITE_GUIS do
					local gui = player.PlayerGui:FindFirstChild(name)
					if gui and gui:IsA("ScreenGui") and (gui.Enabled or hiddenGuis[gui]) then
						hiddenGuis[gui] = nil -- (caché par un niveau en cours : il ne sera pas remis à la fin)
						gui.Enabled = false
						campHidden[gui] = true
					end
				end
			elseif next(campHidden) ~= nil then
				for gui in campHidden do
					if gui.Parent then
						if level.active then
							hiddenGuis[gui] = true -- (remis à la sortie du niveau)
						else
							gui.Enabled = true
						end
					end
				end
				table.clear(campHidden)
			end
			task.wait(0.25)
		end
	end)

	-- Sur la parcelle : l'invite d'un socle d'entraînement ouvre l'onglet Entraînement sur cet emplacement, celle de
	-- la boutique ou de la porte des niveaux ouvre son onglet (attributs CampSlot / CampTab, Hub/Camp.luau).
	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		local plot = CampMode.plotFolder()
		if who ~= player or level.active or player:GetAttribute("LevelsAccess") ~= true or not plot or not prompt:IsDescendantOf(plot) then
			return
		end
		local slot, tab = prompt:GetAttribute("CampSlot"), prompt:GetAttribute("CampTab")
		if typeof(slot) == "number" then
			camp.open("Entraînement", slot)
		elseif typeof(tab) == "string" then
			camp.open(tab)
		end
	end)

	local function syncAccess()
		local access = player:GetAttribute("LevelsAccess") == true
		-- (pendant un niveau, l'écran du camp est caché avec les autres : il sera remis au retour)
		if not level.active then
			camp.gui.Enabled = access
		elseif not access then
			hiddenGuis[camp.gui] = nil
			camp.gui.Enabled = false
		end
	end
	player:GetAttributeChangedSignal("LevelsAccess"):Connect(syncAccess)
	syncAccess()

	local function syncLevel()
		local index = player:GetAttribute("LevelArena")
		if typeof(index) == "number" and Levels.isArena(index) then
			enterLevel(index)
		else
			exitLevel()
			syncAccess()
		end
	end
	player:GetAttributeChangedSignal("LevelArena"):Connect(syncLevel)
	syncLevel()

	-- Clics, appuis, touches.
	UserInputService.InputBegan:Connect(function(input, processed)
		if not level.active then
			return
		end
		if input.UserInputType == Enum.UserInputType.Touch then
			touchStarts[input] = { position = input.Position, last = input.Position, at = os.clock(), processed = processed, moved = false, gui = overGui(input.Position) }
			return
		end
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			tapScreen(input.Position)
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			-- Clic droit : sans bouger, il annule (pose, sélection) ; maintenu et glissé, il déplace la vue.
			rightDrag.down, rightDrag.last, rightDrag.moved = true, input.Position, 0
		elseif input.UserInputType == Enum.UserInputType.Keyboard then
			local slot = HOTKEYS[input.KeyCode]
			if slot then
				local towerType = state.towers[slot]
				if towerType then
					barTap(towerType)
				end
			elseif input.KeyCode == Enum.KeyCode.E then
				upgradeSelected()
			elseif input.KeyCode == Enum.KeyCode.X then
				sellSelected()
			elseif input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.Backspace then
				setPlacing(nil)
				selectTower(nil)
			elseif input.KeyCode == Enum.KeyCode.F then
				toggleSpeed()
			end
		end
	end)
	UserInputService.InputChanged:Connect(function(input, processed)
		if not level.active then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			-- Molette : zoom (pas au-dessus d'une fenêtre qui défile).
			if not processed then
				setView(level.zoom * ZOOM_WHEEL ^ input.Position.Z, level.pan)
			end
		elseif input.UserInputType == Enum.UserInputType.MouseMovement and rightDrag.down then
			local delta = input.Position - rightDrag.last
			rightDrag.last = input.Position
			rightDrag.moved += math.abs(delta.X) + math.abs(delta.Y)
			if rightDrag.moved > RIGHT_CLICK_MOVE then
				panByPixels(delta.X, delta.Y)
			end
		end
	end)
	UserInputService.TouchMoved:Connect(function(input)
		if not level.active then
			return
		end
		if input == drag.input and drag.towerType then
			-- Toucher parti d'une tour de la barre : il devient un « glisser » (pose), jamais un déplacement de vue.
			if not drag.active and (input.Position - drag.origin).Magnitude > DRAG_START then
				drag.active = true
				setPlacing(drag.towerType)
			end
			return
		end
		local touch = touchStarts[input]
		if not touch or touch.gui then
			return
		end
		local previous = touch.last
		touch.last = input.Position
		if (input.Position - touch.position).Magnitude > TAP_MOVE then
			touch.moved = true
		end
		-- L'autre doigt posé sur le terrain, s'il y en a un : pincement = zoom ; un seul doigt = déplacement.
		local other = nil
		for candidate, info in touchStarts do
			if candidate ~= input and candidate ~= drag.input and not info.gui and candidate.UserInputState ~= Enum.UserInputState.End then
				other = info
			end
		end
		if other then
			local before = (previous - other.last).Magnitude
			local after = (input.Position - other.last).Magnitude
			if before > 4 and after > 4 then
				touch.moved, other.moved = true, true
				setView(level.zoom * after / before, level.pan)
			end
		elseif touch.moved then
			panByPixels(input.Position.X - previous.X, input.Position.Y - previous.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			local wasDown = rightDrag.down
			rightDrag.down = false
			if level.active and wasDown and rightDrag.moved <= RIGHT_CLICK_MOVE then
				setPlacing(nil)
				selectTower(nil)
			end
			return
		end
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local start = touchStarts[input]
		touchStarts[input] = nil
		if input == drag.input then
			local dragging, towerType = drag.active, drag.towerType
			drag.input, drag.towerType = nil, nil
			if dragging then
				-- Fin d'un glisser depuis la barre : la tour est posée là où le doigt se lève (sauf sur un bouton).
				local camera = workspace.CurrentCamera
				local point = if level.active and camera and not overGui(input.Position)
					then localGround(camera:ScreenPointToRay(input.Position.X, input.Position.Y))
					else nil
				if point and towerType then
					tryPlace(towerType, snap(point))
				end
				setPlacing(nil)
				-- (le bouton de la barre reçoit encore son « Activated » juste après : il l'ignore)
				task.defer(function()
					drag.active = false
				end)
				return
			end
		end
		if not level.active or not start then
			return
		end
		-- Glissé (déplacement de la vue, pincement) ou appui long : pas un appui.
		if start.moved or (input.Position - start.position).Magnitude > TAP_MOVE or os.clock() - start.at > TAP_TIME then
			return
		end
		-- Un appui pris par un bouton du jeu est pour lui ; pris par autre chose (zone du joystick de Roblox), il
		-- compte quand même.
		if overGui(input.Position) then
			return
		end
		tapScreen(input.Position)
	end)

	local guiCheck = 0
	RunService.RenderStepped:Connect(function(dt)
		if not level.active then
			return
		end
		local folder = arenaFolder()
		local mapName = folder and folder:GetAttribute("Map")
		if typeof(mapName) == "string" and mapName ~= level.mapName and Levels.MAPS[mapName] then
			level.mapName = mapName
			level.geometry = Levels.geometry(mapName)
			level.cameraKey = ""
		end
		-- Flèches du clavier : déplacer la vue (quand elle est zoomée).
		if level.zoom > 1 and not UserInputService:GetFocusedTextBox() then
			local x = (if UserInputService:IsKeyDown(Enum.KeyCode.Right) then 1 else 0) - (if UserInputService:IsKeyDown(Enum.KeyCode.Left) then 1 else 0)
			local y = (if UserInputService:IsKeyDown(Enum.KeyCode.Up) then 1 else 0) - (if UserInputService:IsKeyDown(Enum.KeyCode.Down) then 1 else 0)
			if x ~= 0 or y ~= 0 then
				setView(level.zoom, level.pan + Vector2.new(x, y) * (PAN_KEYS_SPEED / level.zoom * dt))
			end
		end
		updateCamera()
		if not folder then
			return
		end
		local runState, number = folder:GetAttribute("State"), folder:GetAttribute("Level")
		if runState == "Running" and (level.runState ~= "Running" or level.number ~= number) then
			onLevelStart(number)
		end
		level.runState, level.number = runState, number
		watchTowers()
		hud.update()
		updatePlacing()
		-- Un écran du jeu rallumé pendant le niveau (message, fenêtre) est recaché.
		guiCheck += dt
		if guiCheck >= 0.5 then
			guiCheck = 0
			hideOtherGuis()
		end
	end)

	if RunService:IsStudio() then
		for _, gui in { camp.gui, hud.gui } do
			gui:GetAttributeChangedSignal("TestAction"):Connect(function()
				local command = gui:GetAttribute("TestAction")
				if typeof(command) == "string" then
					testAction(command)
				end
			end)
		end
	end
end

function LevelsUI.start()
	local built = false
	local function tryBuild()
		if not built and player:GetAttribute("LevelsAccess") == true then
			built = true
			build()
		end
	end
	player:GetAttributeChangedSignal("LevelsAccess"):Connect(tryBuild)
	tryBuild()
end

return LevelsUI

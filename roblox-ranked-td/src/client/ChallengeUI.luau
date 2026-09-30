-- Défis classés (map principale) : bouton « ⚔ DÉFIS » (colonne de gauche), avec une pastille quand
-- une récompense attend, et fenêtre « Défis classés » : les 3 défis du jour et les 2 de la semaine, leur
-- progression, leur récompense et le bouton « Récupérer » (✓ une fois récupérée).
-- Le client ne décide rien : il affiche l'état publié par le serveur (attributs ChallengeState et
-- ChallengesReady du joueur, Hub/ChallengeRewards.luau) et envoie « Récupérer » (remote ChallengeAction) ; le
-- serveur revérifie tout. Textes, objectifs et récompenses : Shared/Challenges.luau (les mêmes que le serveur).
-- La progression est comptée par le serveur de match, à la fin de chaque match classé.
-- Classé FERMÉ (Config.RANKED_OPEN = false, Shared/RankedGate.luau) : les défis se font en match classé, donc le
-- bouton « ⚔ DÉFIS » est caché (son ScreenGui éteint) et la fenêtre ne s'ouvre pas ; le serveur refuse « Récupérer ».
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Challenges = require(Shared.Challenges)
local RankedGate = require(Shared.RankedGate)
local Remotes = require(Shared.Remotes)
local SoundManager = require(script.Parent.SoundManager)
local UI = require(script.Parent.UI)

local ChallengeUI = {}

local BUTTON_COLOR = Color3.fromRGB(58, 86, 140)
local WINDOW_SIZE = Vector2.new(560, 530)
local ROW_HEIGHT = 64
local ROW_GAP = 6
local REWARD_WIDTH = 190 -- colonne de droite : récompense et bouton « Récupérer »
-- Zones de Roblox à ne pas couvrir (écrans d'ordinateur, au moins SMALL_SCREEN px de large), en pixels sous la
-- barre du haut : le chat en bas à gauche (même largeur que dans PlotUI) et la liste des joueurs en haut à
-- droite. Liste mesurée sur une capture des tests Studio (hub_ui.png) : ~400 px de large avec les 3 colonnes d'avant
-- (Rang, Pièces, MMR ; maintenant 2 : DPS et Money, donc plus étroite), ~85 px de haut avec 1 joueur et ~40 px de
-- plus par joueur (~290 px avec 6 joueurs).
-- Sur un petit écran (téléphone), la fenêtre est réduite pour tenir, à droite de la colonne de boutons de gauche.
local CHAT_WIDTH = 500
local PLAYER_LIST_WIDTH = 420
local PLAYER_LIST_HEIGHT = 310
local SMALL_SCREEN = 1000
local SCREEN_MARGIN = UI.WINDOW_MARGIN -- 8 px, comme les autres fenêtres
local MIN_SCALE = UI.MIN_WINDOW_SCALE
local CLAIM_COOLDOWN = 1 -- secondes entre deux clics « Récupérer » (le serveur refuse de toute façon le 2e)
local DONE_COLOR = UI.Colors.Success:Lerp(Color3.new(1, 1, 1), 0.35)

-- Temps restant : « 3 j 4 h », « 5 h 07 », « 12 min », « 40 s ».
local function formatLeft(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local days, hours, minutes = seconds // 86400, (seconds % 86400) // 3600, (seconds % 3600) // 60
	if days > 0 then
		return `{days} j {hours} h`
	elseif hours > 0 then
		return string.format("%d h %02d", hours, minutes)
	elseif minutes > 0 then
		return `{minutes} min`
	end
	return `{seconds} s`
end

-- Place de la fenêtre pour un écran (zone du ScreenGui, sous la barre du haut) de taille `screen` (px) : son coin en
-- haut à gauche et son échelle (UIScale, qui la réduit depuis ce coin). Fonction pure : les tests l'appellent aussi
-- avec de fausses tailles de téléphone.
-- Écran d'ordinateur : elle ne couvre ni le chat (à gauche de CHAT_WIDTH) ni la liste des joueurs (coin en haut à
-- droite) : soit entre les deux sur toute la hauteur, soit à droite du chat et SOUS la liste (mieux sur les écrans
-- moins larges) ; on garde la place où elle est la plus grande. Dans cette place, elle est centrée sur l'écran si
-- possible. Petit écran (téléphone) : à droite de la colonne de boutons de gauche, réduite pour tenir. Les boutons
-- de l'autel et de la forge (MachineUI, ordre 20) passent PAR-DESSUS cette fenêtre (ordre 19) : centrée, son bord
-- gauche était caché dessous sur un téléphone de 667 px de large. (Pas assez de place à droite de la colonne :
-- centrée, comme avant.)
function ChallengeUI.placement(screen: Vector2): (Vector2, number)
	local left, right = SCREEN_MARGIN, screen.X - SCREEN_MARGIN
	local top, bottom = SCREEN_MARGIN, screen.Y - SCREEN_MARGIN
	if screen.X >= SMALL_SCREEN then
		left = CHAT_WIDTH
		local between = math.min((screen.X - PLAYER_LIST_WIDTH - left) / WINDOW_SIZE.X, (bottom - top) / WINDOW_SIZE.Y)
		local below = math.min((right - left) / WINDOW_SIZE.X, (bottom - PLAYER_LIST_HEIGHT) / WINDOW_SIZE.Y)
		if between >= below then
			right = screen.X - PLAYER_LIST_WIDTH
		else
			top = PLAYER_LIST_HEIGHT
		end
	else
		local column = UI.leftColumnRight(screen) + SCREEN_MARGIN
		if (right - column) / WINDOW_SIZE.X >= MIN_SCALE then
			left = column
		end
	end
	local scale = math.clamp(math.min((right - left) / WINDOW_SIZE.X, (bottom - top) / WINDOW_SIZE.Y, 1), MIN_SCALE, 1)
	local width, height = WINDOW_SIZE.X * scale, WINDOW_SIZE.Y * scale
	local x = math.clamp((screen.X - width) / 2, left, math.max(left, right - width))
	local y = math.clamp((screen.Y - height) / 2, top, math.max(top, bottom - height))
	return Vector2.new(math.floor(x), math.floor(y)), scale
end

function ChallengeUI.start()
	local player = Players.LocalPlayer
	local challengeAction = Remotes.get("ChallengeAction")
	local plotsFolder = workspace:WaitForChild("Hub"):WaitForChild("Plots")
	-- Le bouton a son propre ScreenGui (ordre 0, comme les autres boutons) : il reste sous le voile sombre des
	-- fenêtres. La fenêtre (19) passe SOUS celles des machines (20) : l'autel ou la forge qui montrent les
	-- lancers offerts s'ouvrent par-dessus, et on revient aux défis en les fermant.
	local buttonGui = UI.screen("ChallengesButton")
	local gui = UI.screen("Challenges", 19)

	-- Record et bonus de pièces (dossier de ma parcelle) : les pièces affichées sont calculées comme le serveur.
	local function readPlot(): (number, number)
		local index = player:GetAttribute("Plot")
		local plot = index and plotsFolder:FindFirstChild("Plot" .. index)
		if not plot then
			return 1, 0
		end
		return plot:GetAttribute("HighestWave") or 1, plot:GetAttribute("CoinBonus") or 0
	end

	-- État publié par le serveur (nil tant qu'il n'est pas arrivé, ou s'il est illisible).
	local function readState()
		local raw = player:GetAttribute("ChallengeState")
		if typeof(raw) ~= "string" then
			return nil
		end
		local ok, state = pcall(HttpService.JSONDecode, HttpService, raw)
		if not ok or typeof(state) ~= "table" or typeof(state.daily) ~= "table" or typeof(state.weekly) ~= "table" then
			return nil
		end
		return state
	end

	------------------------------------------------------------------
	-- Bouton « ⚔ DÉFIS » (colonne de gauche, index 4, sous « Boutique ») et sa pastille
	------------------------------------------------------------------
	local button = UI.button({
		Position = UDim2.new(0, 16, 0, UI.LEFT_COLUMN_TOP + 4 * UI.LEFT_COLUMN_STEP),
		Size = UDim2.fromOffset(180, 46),
		BackgroundColor3 = BUTTON_COLOR,
		Text = "⚔ DÉFIS",
		MaxTextSize = 18,
		Parent = buttonGui,
	})
	-- Contour qui pulse quand une récompense attend (comme le bouton Renaissance).
	local buttonStroke = UI.stroke(UI.Colors.Gold, 2)
	buttonStroke.Enabled = false
	buttonStroke.Parent = button
	TweenService:Create(
		buttonStroke,
		TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Transparency = 0 }
	):Play()
	local badge = UI.new("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = UI.Colors.Gold,
		Visible = false,
		ZIndex = 3,
		Parent = button,
	}, { UI.corner(12), UI.stroke(Color3.new(0, 0, 0), 1) })
	local badgeLabel = UI.label({
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.GothamBlack,
		TextColor3 = Color3.fromRGB(30, 25, 10),
		MaxTextSize = 15,
		ZIndex = 4,
		Parent = badge,
	})
	-- Écran trop bas (téléphone) : toute la colonne est réduite pour tenir (UI.leftColumnSlot). Avant, ce bouton
	-- sortait de l'écran d'un téléphone en paysage.
	UI.placeInLeftColumn(button, 4)

	------------------------------------------------------------------
	-- Fenêtre (même style que les machines, MachineUI)
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
		Size = UDim2.fromOffset(WINDOW_SIZE.X, WINDOW_SIZE.Y),
		BackgroundColor3 = UI.Colors.Panel,
		Parent = overlay,
	}, { UI.corner(16), UI.padding(14) })
	local windowStroke = UI.stroke(BUTTON_COLOR:Lerp(Color3.new(1, 1, 1), 0.3), 3)
	windowStroke.Transparency = 0
	windowStroke.Parent = window
	local windowScale = UI.new("UIScale", { Name = "FitScale", Parent = window })

	-- Place de la fenêtre (Position = son coin en haut à gauche, d'où UIScale la réduit) : ChallengeUI.placement.
	local function placeWindow()
		local screen = gui.AbsoluteSize
		if screen.X <= 0 or screen.Y <= 0 then
			return
		end
		local position, scale = ChallengeUI.placement(screen)
		windowScale.Scale = scale
		window.Position = UDim2.fromOffset(position.X, position.Y)
	end
	placeWindow()
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeWindow)

	UI.label({
		Size = UDim2.new(1, -40, 0, 30),
		Font = Enum.Font.GothamBlack,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.Gold,
		Text = "Défis classés",
		MaxTextSize = 26,
		Parent = window,
	})
	UI.label({
		Position = UDim2.new(0, 0, 0, 32),
		Size = UDim2.new(1, 0, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		TextColor3 = UI.Colors.Muted,
		Text = Challenges.rulesText(),
		MaxTextSize = 13,
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

	-- Titre d'une partie (« Aujourd'hui », « Cette semaine ») et temps avant les nouveaux défis.
	local function sectionHeader(y: number, title: string): TextLabel
		UI.label({
			Position = UDim2.new(0, 0, 0, y),
			Size = UDim2.new(0.5, 0, 0, 22),
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Enum.Font.GothamBlack,
			Text = title,
			MaxTextSize = 18,
			Parent = window,
		})
		return UI.label({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, y + 3),
			Size = UDim2.new(0.5, 0, 0, 18),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = UI.Colors.Muted,
			MaxTextSize = 13,
			Parent = window,
		})
	end

	local lastClaim = 0
	local current = nil -- dernier état lu (readState)

	-- Une ligne de défi : texte, barre x/N, récompense, bouton « Récupérer » (ou ✓).
	local function makeRow(y: number)
		local frame = UI.new("Frame", {
			Position = UDim2.new(0, 0, 0, y),
			Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
			BackgroundColor3 = UI.Colors.Background,
			BackgroundTransparency = 0.3,
			Parent = window,
		}, { UI.corner(8), UI.padding(8) })
		local stroke = UI.stroke(UI.Colors.Gold, 2) -- allumé quand la récompense attend
		stroke.Transparency = 0.1
		stroke.Parent = frame
		local text = UI.label({
			Size = UDim2.new(1, -REWARD_WIDTH - 10, 0, 20),
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Enum.Font.GothamBold,
			MaxTextSize = 16,
			Parent = frame,
		})
		local _, setBar = UI.bar({
			Position = UDim2.new(0, 0, 0, 30),
			Size = UDim2.new(1, -REWARD_WIDTH - 90, 0, 12),
			Parent = frame,
		}, UI.Colors.Success)
		local progress = UI.label({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -REWARD_WIDTH - 10, 0, 26),
			Size = UDim2.fromOffset(74, 20),
			TextXAlignment = Enum.TextXAlignment.Right,
			Font = Enum.Font.GothamBold,
			MaxTextSize = 14,
			Parent = frame,
		})
		local reward = UI.label({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 0),
			Size = UDim2.fromOffset(REWARD_WIDTH, 18),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = UI.Colors.Gold,
			MaxTextSize = 13,
			Parent = frame,
		})
		local claim = UI.button({
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, 0, 1, 0),
			Size = UDim2.fromOffset(REWARD_WIDTH, 26),
			BackgroundColor3 = UI.Colors.Success,
			Text = "Récupérer",
			MaxTextSize = 16,
			Visible = false,
			Parent = frame,
		})
		local status = UI.label({
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, 0, 1, 0),
			Size = UDim2.fromOffset(REWARD_WIDTH, 24),
			TextXAlignment = Enum.TextXAlignment.Right,
			Font = Enum.Font.GothamBold,
			MaxTextSize = 15,
			Parent = frame,
		})
		local row = { frame = frame, stroke = stroke, text = text, setBar = setBar, progress = progress, reward = reward, claim = claim, status = status, key = nil }
		claim.Activated:Connect(function()
			local key, state = row.key, current
			if typeof(key) ~= "string" or not state or os.clock() - lastClaim < CLAIM_COOLDOWN then
				return
			end
			lastClaim = os.clock()
			-- Le numéro du jour (ou de la semaine) affiché : le serveur refuse si les défis ont changé entre-temps.
			local period = if string.sub(key, 1, 1) == "w" then state.week else state.day
			challengeAction:FireServer("Claim", key, period)
		end)
		return row
	end

	-- Les lignes : 3 défis du jour, 2 de la semaine.
	local rows = { daily = {}, weekly = {} }
	local y = 68
	local dayLeftLabel = sectionHeader(y, "Aujourd'hui")
	y += 26
	local function addRow(list)
		local row = makeRow(y)
		table.insert(list, row)
		y += ROW_HEIGHT + ROW_GAP
	end
	for _ = 1, Challenges.DAILY_COUNT do
		addRow(rows.daily)
	end
	y += 2
	local weekLeftLabel = sectionHeader(y, "Cette semaine")
	y += 26
	for _ = 1, Challenges.WEEKLY_COUNT do
		addRow(rows.weekly)
	end
	UI.label({
		Position = UDim2.new(0, 0, 0, y),
		Size = UDim2.new(1, 0, 0, 28),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		TextColor3 = UI.Colors.Warning:Lerp(Color3.new(1, 1, 1), 0.3),
		Text = "Récompenses pour le mode solo. Une récompense pas récupérée avant les nouveaux défis (00:00 UTC, "
			.. "le lundi pour la semaine) est perdue.",
		MaxTextSize = 12,
		Parent = window,
	})

	------------------------------------------------------------------
	-- Mise à jour
	------------------------------------------------------------------
	local function renderRow(row, entry, highestWave: number, coinBonus: number)
		local def = entry and Challenges.BY_ID[entry.id]
		if not def then
			row.key = nil
			row.text.Text = "Chargement..."
			row.progress.Text = ""
			row.reward.Text = ""
			row.setBar(0)
			row.claim.Visible = false
			row.status.Text = ""
			row.stroke.Enabled = false
			return
		end
		local progress = math.clamp(tonumber(entry.p) or 0, 0, def.target)
		local done = progress >= def.target
		local claimed = entry.c == true
		row.key = entry.key
		row.text.Text = def.text
		row.text.TextColor3 = if claimed then UI.Colors.Muted else UI.Colors.Text
		row.progress.Text = Challenges.progressText(def, progress)
		row.progress.TextColor3 = if done then DONE_COLOR else UI.Colors.Text
		row.setBar(progress / def.target)
		row.reward.Text = Challenges.rewardText(Challenges.rewardFor(def, highestWave, coinBonus))
		row.claim.Visible = done and not claimed
		row.status.Text = if claimed then "✓ Récupérée" elseif done then "" else "En cours"
		row.status.TextColor3 = if claimed then DONE_COLOR else UI.Colors.Muted
		row.stroke.Enabled = done and not claimed
		row.frame.BackgroundTransparency = if claimed then 0.6 else 0.3
	end

	local function refreshWindow()
		current = readState()
		local highestWave, coinBonus = readPlot()
		for kind, list in rows do
			local entries = if current then current[kind] else {}
			for index, row in list do
				renderRow(row, entries[index], highestWave, coinBonus)
			end
		end
	end

	local function refreshTimers()
		local now = workspace:GetServerTimeNow()
		local state = current
		for _, pair in { { dayLeftLabel, state and state.dayEndsAt }, { weekLeftLabel, state and state.weekEndsAt } } do
			local label, endsAt = pair[1], pair[2]
			if typeof(endsAt) ~= "number" then
				label.Text = ""
			elseif endsAt - now > 0 then
				label.Text = `Nouveaux défis dans {formatLeft(endsAt - now)}`
			else
				label.Text = "Nouveaux défis en chemin..."
			end
		end
	end

	local function refreshButton()
		local ready = tonumber(player:GetAttribute("ChallengesReady")) or 0
		badge.Visible = ready > 0
		badgeLabel.Text = tostring(ready)
		buttonStroke.Enabled = ready > 0
	end

	local function open()
		if not RankedGate.isOpen() then
			return -- classé fermé : pas de défis
		end
		overlay.Visible = true
		refreshWindow()
		refreshTimers()
	end
	local function close()
		overlay.Visible = false
	end
	-- Classé fermé : bouton caché (tout son ScreenGui : UI.placeInLeftColumn remet parfois le bouton visible) et
	-- fenêtre fermée. Le classé ne change jamais pendant une partie publiée (seulement dans Studio).
	local function applyGate()
		local rankedOpen = RankedGate.isOpen()
		buttonGui.Enabled = rankedOpen
		if not rankedOpen then
			close()
		end
	end
	applyGate()
	RankedGate.onChanged(applyGate)
	button.Activated:Connect(function()
		if overlay.Visible then
			close()
		else
			open()
		end
	end)
	closeButton.Activated:Connect(close)

	player:GetAttributeChangedSignal("ChallengeState"):Connect(function()
		if overlay.Visible then
			refreshWindow()
			refreshTimers()
		end
	end)
	player:GetAttributeChangedSignal("ChallengesReady"):Connect(refreshButton)
	refreshButton()
	-- Son « récompense récupérée » : le nombre de récompenses prêtes baisse juste après un clic « Récupérer »
	-- (le serveur a donné la récompense). Pas quand une récompense est perdue avec les nouveaux défis.
	local lastReady = tonumber(player:GetAttribute("ChallengesReady")) or 0
	player:GetAttributeChangedSignal("ChallengesReady"):Connect(function()
		local ready = tonumber(player:GetAttribute("ChallengesReady")) or 0
		if ready < lastReady and os.clock() - lastClaim < 5 then
			SoundManager.play("ChallengeClaim")
		end
		lastReady = ready
	end)

	task.spawn(function()
		while gui.Parent do
			if overlay.Visible then
				refreshWindow() -- (record et bonus de pièces changent pendant qu'on farme)
				refreshTimers()
			end
			task.wait(0.5)
		end
	end)
end

return ChallengeUI

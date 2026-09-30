-- Interface de la map principale : carte de rang, et tout le classé :
--   * bouton « ⚔ S'INSCRIRE AU CLASSÉ », seulement dans le cercle de l'arène (au centre de la map) ;
--   * statut de la recherche (en bas à droite, visible partout sur la map : on peut partir jouer) avec ANNULER ;
--   * fenêtre « MATCH TROUVÉ ! » quand un adversaire est trouvé : ACCEPTER ou REFUSER avant la fin de la barre.
-- Le client ne décide rien : il affiche les attributs publiés par le serveur (QueueState, InRankedCircle,
-- MatchOpponent..., voir Remotes.luau) et envoie les clics (remote QueueAction) ; le serveur vérifie tout
-- (Hub/init.luau, Matchmaking.luau).
-- Classé FERMÉ (Config.RANKED_OPEN = false, Shared/RankedGate.luau) : dans le cercle, un panneau « BIENTÔT
-- DISPONIBLE » (« RankedSoon ») à la place du bouton ; jamais de statut de recherche ni de « MATCH TROUVÉ ! » ; pas
-- de carte de rang à l'écran.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local PlotLayout = require(Shared.PlotLayout)
local RankedGate = require(Shared.RankedGate)
local Ranks = require(Shared.Ranks)
local Remotes = require(Shared.Remotes)
local UI = require(script.Parent.UI)

local LobbyUI = {}

local SIGNUP_COLOR = Color3.fromRGB(150, 38, 42) -- le rouge du sceau de l'arène
local SIGNUP_SIZE = Vector2.new(400, 64)
local SIGNUP_HINT_HEIGHT = 36 -- conseil sous le bouton, sur 2 lignes
-- Bord droit de la carte de rang (260 px, plus large que les boutons de la colonne de gauche) et une marge : sur un
-- écran étroit (téléphone), le bouton « S'INSCRIRE » se décale vers la droite au lieu de les couvrir.
local LEFT_SIDE = 16 + 260 + 16
local STATUS_SIZE = Vector2.new(390, 52)
local WINDOW_SIZE = Vector2.new(470, 290)
local CLICK_COOLDOWN = 1.5 -- après un clic, le bouton attend la réponse du serveur (qui refuse les doublons)

-- Textes du statut (en bas à droite) pour chaque état de Matchmaking.luau.
local STATUS_TEXTS = {
	Joining = "Inscription au classé…",
	Pending = "⚔ Match trouvé ! Accepte-le vite",
	Accepted = "En attente de l'adversaire…",
	Found = "Match accepté ! Préparation du match…",
	Teleporting = "Téléportation vers le match…",
}

function LobbyUI.start()
	local player = Players.LocalPlayer
	local queueAction = Remotes.get("QueueAction")
	local gui = UI.screen("Lobby")

	-- Carte de rang (en haut à gauche)
	local card = UI.new("Frame", {
		Name = "RankCard",
		Position = UDim2.new(0, 16, 0, 16),
		Size = UDim2.new(0, 260, 0, 130),
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.1,
		Parent = gui,
	}, { UI.corner(12), UI.padding(12), UI.stroke() })
	UI.chrome(card)

	local rankLabel = UI.label({
		Name = "RankLabel",
		Size = UDim2.new(1, 0, 0, 34),
		Font = Enum.Font.GothamBlack,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 30,
		Text = "...",
		Parent = card,
	})
	local mmrLabel = UI.label({
		Name = "MmrLabel",
		Position = UDim2.new(0, 0, 0, 38),
		Size = UDim2.new(1, 0, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.Gold,
		MaxTextSize = 22,
		Text = "",
		Parent = card,
	})
	local statsLabel = UI.label({
		Name = "StatsLabel",
		Position = UDim2.new(0, 0, 0, 66),
		Size = UDim2.new(1, 0, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.Muted,
		MaxTextSize = 18,
		Text = "",
		Parent = card,
	})
	local seasonLabel = UI.label({
		Position = UDim2.new(0, 0, 0, 88),
		Size = UDim2.new(1, 0, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.Muted,
		MaxTextSize = 16,
		Text = `Saison {Config.SEASON} • ROYAUMES EN GUERRE`,
		Parent = card,
	})

	-- Plus de raccourcis « MON FIEF » / « ARÈNE ROYALE » (demande du propriétaire, 29/09/2026) : on va à pied à
	-- sa parcelle et dans le cercle de l'arène. La colonne de gauche, sous le panneau de rang, commence par les
	-- boutons des machines (MachineUI), puis Renaissance, Boutique et Défis. Le chat est en bas à gauche.

	------------------------------------------------------------------
	-- Bouton « ⚔ S'INSCRIRE AU CLASSÉ » : seulement dans le cercle (attribut InRankedCircle du serveur) et si
	-- le joueur n'est pas déjà inscrit. Au-dessus du personnage, sous le compteur de pièces : il ne couvre ni le
	-- chat (en bas à gauche) ni le panneau des tours (en bas à droite).
	------------------------------------------------------------------
	local signUpFrame = UI.new("Frame", {
		Name = "SignUp",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.26, 0),
		Size = UDim2.fromOffset(SIGNUP_SIZE.X, SIGNUP_SIZE.Y + 4 + SIGNUP_HINT_HEIGHT),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	local signUpScale = UI.new("UIScale", { Parent = signUpFrame })
	local signUpButton = UI.button({
		Name = "SignUpButton",
		Size = UDim2.fromOffset(SIGNUP_SIZE.X, SIGNUP_SIZE.Y),
		BackgroundColor3 = SIGNUP_COLOR,
		Text = "⚔ S'INSCRIRE AU CLASSÉ",
		MaxTextSize = 30,
		Parent = signUpFrame,
	})
	-- Contour doré qui pulse : on le remarque en entrant dans le cercle.
	local signUpStroke = signUpButton:FindFirstChildOfClass("UIStroke")
	if signUpStroke then
		signUpStroke.Thickness = 3
		TweenService:Create(
			signUpStroke,
			TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Transparency = 0 }
		):Play()
	end
	UI.label({
		Name = "Hint",
		Position = UDim2.fromOffset(0, SIGNUP_SIZE.Y + 4),
		Size = UDim2.fromOffset(SIGNUP_SIZE.X, SIGNUP_HINT_HEIGHT),
		TextStrokeTransparency = 0.4,
		TextWrapped = true, -- (sur une seule ligne, le texte serait écrit tout petit)
		Text = "Ensuite, va jouer : on te propose le match dès qu'un adversaire est trouvé",
		MaxTextSize = 15,
		Parent = signUpFrame,
	})
	-- Près du sceau mais pas dedans : un petit conseil en bas à droite.
	local circleHint = UI.label({
		Name = "CircleHint",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -20),
		Size = UDim2.new(0, 380, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextStrokeTransparency = 0.5,
		MaxTextSize = 18,
		Text = "Entre dans le sceau rouge pour t'inscrire au classé",
		Visible = false,
		Parent = gui,
	})
	-- Classé fermé : dans le cercle, ce panneau à la place du bouton (même place, même taille : le tuto l'évite pareil).
	local soonFrame = UI.new("Frame", {
		Name = "RankedSoon",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.26, 0),
		Size = UDim2.fromOffset(SIGNUP_SIZE.X, SIGNUP_SIZE.Y + 4 + SIGNUP_HINT_HEIGHT),
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.08,
		Visible = false,
		Parent = gui,
	}, { UI.corner(12), UI.padding(10) })
	local soonStroke = UI.stroke(UI.Colors.Gold, 3)
	soonStroke.Transparency = 0
	soonStroke.Parent = soonFrame
	local soonScale = UI.new("UIScale", { Parent = soonFrame })
	UI.label({
		Name = "Title",
		Size = UDim2.new(1, 0, 0, 44),
		Font = Enum.Font.GothamBlack,
		TextColor3 = UI.Colors.Gold,
		Text = RankedGate.SOON_TITLE,
		MaxTextSize = 32,
		Parent = soonFrame,
	})
	UI.label({
		Name = "Text",
		Position = UDim2.fromOffset(0, 48),
		Size = UDim2.new(1, 0, 1, -48),
		TextWrapped = true,
		Text = RankedGate.SOON_TEXT,
		MaxTextSize = 20,
		Parent = soonFrame,
	})

	------------------------------------------------------------------
	-- Statut de la recherche (en bas à droite, visible partout sur la map). Quand le panneau des tours de la
	-- parcelle est ouvert (PlotUI, en bas à droite lui aussi), il monte juste au-dessus : il ne cache jamais ses
	-- boutons (Améliorer, Vendre...).
	------------------------------------------------------------------
	local status = UI.new("Frame", {
		Name = "QueueStatus",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.fromOffset(STATUS_SIZE.X, STATUS_SIZE.Y),
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = gui,
	}, { UI.corner(10), UI.padding(8), UI.stroke(UI.Colors.Gold, 1) })
	local statusText = UI.label({
		Name = "StatusText",
		Size = UDim2.new(1, -118, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 17,
		Text = "",
		Parent = status,
	})
	local cancelButton = UI.button({
		Name = "CancelButton",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(110, 36),
		BackgroundColor3 = UI.Colors.Error,
		Text = "ANNULER",
		MaxTextSize = 18,
		Parent = status,
	})

	------------------------------------------------------------------
	-- Fenêtre « MATCH TROUVÉ ! » (par-dessus les autres fenêtres, sous les messages) : adversaire, rang, barre
	-- du temps qui reste, ACCEPTER / REFUSER. Après ACCEPTER : « En attente de l'adversaire… ».
	------------------------------------------------------------------
	local acceptGui = UI.screen("RankedAccept", 40)
	local overlay = UI.new("TextButton", {
		Name = "Overlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		AutoButtonColor = false,
		Text = "",
		Visible = false,
		Parent = acceptGui,
	})
	local window = UI.new("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(WINDOW_SIZE.X, WINDOW_SIZE.Y),
		BackgroundColor3 = UI.Colors.Panel,
		Parent = overlay,
	}, { UI.corner(16), UI.padding(16) })
	local windowStroke = UI.stroke(UI.Colors.Gold, 3)
	windowStroke.Transparency = 0
	windowStroke.Parent = window
	local windowScale = UI.new("UIScale", { Parent = window })
	UI.label({
		Name = "Title",
		Size = UDim2.new(1, 0, 0, 40),
		Font = Enum.Font.GothamBlack,
		TextColor3 = UI.Colors.Gold,
		Text = "⚔ MATCH TROUVÉ !",
		MaxTextSize = 34,
		Parent = window,
	})
	local opponentLabel = UI.label({
		Name = "Opponent",
		Position = UDim2.new(0, 0, 0, 48),
		Size = UDim2.new(1, 0, 0, 28),
		Font = Enum.Font.GothamBold,
		Text = "",
		MaxTextSize = 22,
		Parent = window,
	})
	local opponentRank = UI.label({
		Name = "OpponentRank",
		Position = UDim2.new(0, 0, 0, 78),
		Size = UDim2.new(1, 0, 0, 24),
		Text = "",
		MaxTextSize = 19,
		Parent = window,
	})
	local timerBar, setTimer = UI.bar({
		Name = "Timer",
		Position = UDim2.new(0, 0, 0, 118),
		Size = UDim2.new(1, -60, 0, 14),
	}, UI.Colors.Gold)
	timerBar.Parent = window
	local secondsLabel = UI.label({
		Name = "Seconds",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 112),
		Size = UDim2.fromOffset(52, 26),
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = Enum.Font.GothamBold,
		Text = "",
		MaxTextSize = 20,
		Parent = window,
	})
	local acceptButton = UI.button({
		Name = "AcceptButton",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(0.5, -6, 0, 56),
		BackgroundColor3 = UI.Colors.Success,
		Text = "ACCEPTER",
		MaxTextSize = 26,
		Parent = window,
	})
	local refuseButton = UI.button({
		Name = "RefuseButton",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 1, 0),
		Size = UDim2.new(0.5, -6, 0, 56),
		BackgroundColor3 = UI.Colors.Error,
		Text = "REFUSER",
		MaxTextSize = 26,
		Parent = window,
	})
	-- À la place des boutons après ACCEPTER (ou quand le temps est écoulé).
	local waitingLabel = UI.label({
		Name = "Waiting",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -8),
		Size = UDim2.new(1, 0, 0, 40),
		Font = Enum.Font.GothamBold,
		TextColor3 = UI.Colors.Gold,
		Text = "",
		MaxTextSize = 22,
		Visible = false,
		Parent = window,
	})

	-- Petits écrans : la fenêtre est seulement réduite pour tenir ; le bouton aussi, et il reste à droite de la
	-- carte de rang et de la colonne de gauche (centré quand l'écran est assez large).
	local function fitToScreen()
		local screen = gui.AbsoluteSize
		if screen.X <= 0 or screen.Y <= 0 then
			return
		end
		local narrow = screen.X < 700
		card.Size = UDim2.fromOffset(if narrow then math.min(260, (screen.X - 48) / 2) else 260, 130)
		seasonLabel.TextWrapped = narrow
		seasonLabel.Size = UDim2.new(1, 0, 0, if narrow then 22 else 18)
		status.Size = UDim2.fromOffset(math.min(STATUS_SIZE.X, screen.X - 32), STATUS_SIZE.Y)
		statusText.TextWrapped = true
		circleHint.Size = UDim2.fromOffset(math.min(380, screen.X - 32), 40)
		circleHint.TextWrapped = true
		local signUpScaleValue = if narrow then math.min(1, (screen.X - 32) / SIGNUP_SIZE.X)
			else math.clamp((screen.X - LEFT_SIDE - 16) / SIGNUP_SIZE.X, 0.5, 1)
		signUpScale.Scale = signUpScaleValue
		signUpFrame.Position = if narrow then UDim2.new(0.5, 0, 1, -130)
			else UDim2.new(0, math.max(screen.X / 2, LEFT_SIDE + SIGNUP_SIZE.X * signUpScaleValue / 2), 0.26, 0)
		soonScale.Scale = signUpScaleValue
		soonFrame.Position = signUpFrame.Position
		windowScale.Scale = UI.windowScale(screen, WINDOW_SIZE) -- (même règle que les autres fenêtres, UI.luau)
	end
	fitToScreen()
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitToScreen)

	------------------------------------------------------------------
	-- Clics (le serveur vérifie tout : cercle, état, anti-spam)
	------------------------------------------------------------------
	local signUpClickedAt, answeredAt = -math.huge, -math.huge
	local function queueState(): string
		return player:GetAttribute("QueueState") or "Idle"
	end
	signUpButton.Activated:Connect(function()
		if RankedGate.isOpen() and queueState() == "Idle" and os.clock() - signUpClickedAt > CLICK_COOLDOWN then
			signUpClickedAt = os.clock()
			queueAction:FireServer("Join")
		end
	end)
	cancelButton.Activated:Connect(function()
		local state = queueState()
		if state == "Searching" or state == "Joining" then
			queueAction:FireServer("Leave")
		end
	end)
	acceptButton.Activated:Connect(function()
		if queueState() == "Pending" and os.clock() - answeredAt > CLICK_COOLDOWN then
			answeredAt = os.clock()
			queueAction:FireServer("Accept")
		end
	end)
	refuseButton.Activated:Connect(function()
		if queueState() == "Pending" and os.clock() - answeredAt > CLICK_COOLDOWN then
			answeredAt = os.clock()
			queueAction:FireServer("Refuse")
		end
	end)

	------------------------------------------------------------------
	-- Affichage
	------------------------------------------------------------------
	-- Le conseil « entre dans le sceau » n'apparaît que près du sceau rouge.
	local function nearRankedCircle(): boolean
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		return root ~= nil
			and (root.Position - PlotLayout.RANKED_CIRCLE_POSITION).Magnitude <= Config.LabelDistance.Medium
	end

	-- Haut du panneau des tours de la parcelle (PlotUI) quand il est ouvert, sinon nil.
	local function towerPanelTop(): number?
		local plotGui = player.PlayerGui:FindFirstChild("Plot")
		local panel = plotGui and plotGui:FindFirstChild("TowerPanel")
		if panel and panel.Visible and plotGui.Enabled then
			return panel.AbsolutePosition.Y - gui.AbsolutePosition.Y
		end
		return nil
	end

	-- Rang de l'adversaire, comme sur la carte de rang : « Placement 2/5 » (MMR caché) ou « Or • 1234 MMR ».
	local function opponentRankText(mmr: number, games: number): string
		if Ranks.isPlacement(games) then
			return Ranks.label(mmr, games)
		end
		return `{Ranks.label(mmr, games)} • {math.floor(mmr)} MMR`
	end

	local function updateRankCard()
		local mmr = player:GetAttribute("Mmr")
		local games = player:GetAttribute("GamesPlayed") or 0
		-- Classé fermé : pas de carte de rang à l'écran (demande du propriétaire, 30/09/2026 : sur téléphone, « CLASSÉ
		-- 1v1 BIENTÔT DISPONIBLE » écrit en gros prenait la place ; le « bientôt disponible » n'est que dans le cercle).
		card.Visible = RankedGate.isOpen()
		if not RankedGate.isOpen() then
			-- (textes gardés si la carte réapparaît : ni rang ni MMR, seulement « bientôt disponible »)
			rankLabel.Text = "CLASSÉ 1v1"
			rankLabel.TextColor3 = UI.Colors.Text
			mmrLabel.Text = RankedGate.SOON_TITLE
			statsLabel.Text = RankedGate.SOON_TEXT
		elseif mmr then
			rankLabel.Text = Ranks.label(mmr, games)
			rankLabel.TextColor3 = Ranks.color(mmr, games)
			mmrLabel.Text = if Ranks.isPlacement(games) then "MMR caché pendant le placement" else `{mmr} MMR  (record : {player:GetAttribute("PeakMmr") or mmr})`
			statsLabel.Text = `{player:GetAttribute("Wins") or 0} V  •  {player:GetAttribute("Losses") or 0} D  •  {player:GetAttribute("Draws") or 0} N`
		else
			rankLabel.Text = "Chargement..."
		end
	end

	local function updateQueue()
		-- Classé fermé : toujours « pas inscrit » (jamais de statut ni de « MATCH TROUVÉ ! », quoi que disent les
		-- attributs) ; dans le cercle, « BIENTÔT DISPONIBLE » à la place du bouton.
		local open = RankedGate.isOpen()
		local state = if open then queueState() else "Idle"
		local inCircle = player:GetAttribute("InRankedCircle") == true

		-- Bouton d'inscription (ou « BIENTÔT DISPONIBLE ») et conseil
		signUpFrame.Visible = open and inCircle and state == "Idle"
		soonFrame.Visible = not open and inCircle
		signUpButton.Text = if os.clock() - signUpClickedAt < CLICK_COOLDOWN then "Inscription…" else "⚔ S'INSCRIRE AU CLASSÉ"
		circleHint.Visible = open and state == "Idle" and not inCircle and nearRankedCircle()

		-- Statut (en bas à droite, ou juste au-dessus du panneau des tours)
		status.Visible = state ~= "Idle"
		if status.Visible then
			local canCancel = state == "Searching" or state == "Joining"
			cancelButton.Visible = canCancel
			statusText.Size = UDim2.new(1, if canCancel then -118 else 0, 1, 0)
			if state == "Searching" then
				local since = player:GetAttribute("QueueStartedAt")
				local elapsed = if typeof(since) == "number" then workspace:GetServerTimeNow() - since else 0
				statusText.Text = `⚔ Recherche d'un adversaire…  {UI.formatTime(elapsed)}`
			else
				statusText.Text = STATUS_TEXTS[state] or ""
			end
			local top = towerPanelTop()
			status.Position = if top then UDim2.new(1, -16, 0, top - 8) else UDim2.new(1, -16, 1, -16)
		end

		-- Fenêtre « MATCH TROUVÉ ! » (match proposé, puis jusqu'au départ vers le match)
		local offered = state == "Pending" or state == "Accepted" or state == "Found" or state == "Teleporting"
		overlay.Visible = offered
		if not offered then
			return
		end
		local mmr = player:GetAttribute("MatchOpponentMmr")
		local games = player:GetAttribute("MatchOpponentGames")
		opponentLabel.Text = `Adversaire : {player:GetAttribute("MatchOpponent") or "?"}`
		if typeof(mmr) == "number" and typeof(games) == "number" then
			opponentRank.Text = opponentRankText(mmr, games)
			opponentRank.TextColor3 = Ranks.color(mmr, games)
		else
			opponentRank.Text = ""
		end
		local endsAt = player:GetAttribute("MatchAcceptEndsAt")
		local remaining = if typeof(endsAt) == "number" then endsAt - workspace:GetServerTimeNow() else 0
		local counting = state == "Pending" or state == "Accepted"
		timerBar.Visible = counting
		secondsLabel.Visible = counting
		setTimer(remaining / Config.Matchmaking.ACCEPT_SECONDS)
		secondsLabel.Text = `{math.max(0, math.ceil(remaining))} s`

		-- Boutons tant qu'il peut répondre ; sinon, ce qui se passe.
		local answering = state == "Pending" and os.clock() - answeredAt < CLICK_COOLDOWN
		local canAnswer = state == "Pending" and remaining > 0 and not answering
		acceptButton.Visible = canAnswer
		refuseButton.Visible = canAnswer
		waitingLabel.Visible = not canAnswer
		if state == "Pending" then
			waitingLabel.Text = if answering then "Réponse envoyée…" else "Temps écoulé…"
		elseif state == "Accepted" then
			waitingLabel.Text = "En attente de l'adversaire…"
		elseif state == "Found" then
			waitingLabel.Text = "Les deux joueurs ont accepté ! Préparation du match…"
		else
			waitingLabel.Text = "Téléportation vers le match…"
		end
	end

	task.spawn(function()
		while gui.Parent do
			updateRankCard()
			updateQueue()
			task.wait(0.1)
		end
	end)
end

return LobbyUI

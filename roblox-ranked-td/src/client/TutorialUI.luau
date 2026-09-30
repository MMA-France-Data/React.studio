-- Petit tuto des nouveaux joueurs (map principale seulement), montré une seule fois, avec un bouton « Passer ».
-- 6 étapes, chacune validée par ce que le joueur fait vraiment :
--   1. la zone classée : entrer dans le cercle rouge au centre de la map, ou tout près (ou « Suivant ») ; classé fermé
--      (Config.RANKED_OPEN = false, Shared/RankedGate.luau) : le texte dit qu'il arrive bientôt, et montre où il est ;
--   2. ta parcelle : y retourner ;
--   3. poser une tour : au moins une tour sur ta parcelle (le texte nomme l'Archer, sa carte est entourée d'or) ;
--   4. l'améliorer : une tour au niveau 2 ou plus (« Améliorer » entouré d'or) ;
--   5. l'Autel des héros : y aller à pied et lancer x1 (résultat reçu, ou des lancers déjà achetés : attribut
--      TowerSpinsBought ; x1 entouré d'or) ;
--   6. la Forge runique : fermer l'autel s'il est encore ouvert (X entouré d'or), puis l'ouvrir (sa machine ou son
--      bouton de gauche), ou « Terminer ». Forge ouverte : une astuce montre les boutons de gauche (entourés d'or)
--      qui ouvrent l'autel et la forge de n'importe où.
-- Chaque étape reste affichée au moins le temps de lire son texte (READ_MIN à READ_MAX secondes).
-- Une étape déjà faite avant d'y arriver (ex. une tour déjà posée) est validée tout de suite. Le tuto ne bloque
-- rien : un petit panneau en haut de l'écran, un rayon doré du personnage vers la cible et une flèche ▼ au-dessus
-- d'elle (créés seulement chez ce joueur, retirés à la fin ; le rayon repart du nouveau personnage après une mort).
-- Le serveur garde « tuto fini » (PlayerData : tutorialDone, attribut TutorialDone du joueur) ; la fin et « Passer »
-- partent par le remote TutorialAction (Hub/Tutorial.luau). Un joueur qui part au milieu du tuto le recommence à
-- l'étape 1 en revenant : les étapes déjà faites passent toutes seules, et l'étape 1 a « Suivant ».
-- Studio : tes données y sont en mémoire, tu es donc un nouveau joueur à chaque Play et le tuto s'affiche à chaque
-- fois (Config.STUDIO_TUTORIAL = false pour ne plus le voir). Il recommence à l'étape 1 quand l'attribut
-- TutorialReplay du joueur change (StudioDebug « Tutorial », « Replay »). Tests automatiques
-- (ReplicatedStorage.__AutoPlayTest) : jamais tout seul, seulement quand le test le demande (TutorialReplay).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local IdleConfig = require(Shared.IdleConfig)
local IdleTowers = require(Shared.IdleTowers)
local NumberFormat = require(Shared.NumberFormat)
local PlotLayout = require(Shared.PlotLayout)
local RankedGate = require(Shared.RankedGate)
local Remotes = require(Shared.Remotes)
local SoundManager = require(script.Parent.SoundManager)
local UI = require(script.Parent.UI)

local TutorialUI = {}

-- Texte de l'étape 1 (la zone classée) : classé ouvert, ou fermé (« bientôt disponible », Config.RANKED_OPEN).
TutorialUI.RANKED_STEP_OPEN = "Le cercle rouge au centre, c'est le classé : des matchs 1 contre 1 pour monter en rang. Suis le rayon doré !"
TutorialUI.RANKED_STEP_SOON = "Le cercle rouge au centre, c'est le classé : des matchs 1 contre 1, bientôt disponibles ! Suis le rayon doré."

local PANEL_SIZE = Vector2.new(440, 104) -- 3 lignes de texte ; 440 px : ne cache pas le « X » des fenêtres des machines
-- Bord droit de la carte de rang (LobbyUI : 260 px à 16 px du bord) et une marge : sur un écran étroit (téléphone),
-- le panneau se décale vers la droite et rétrécit au lieu de la couvrir (comme le bouton « S'INSCRIRE »).
local LEFT_SIDE = 16 + 260 + 16
-- Haut du panneau : sous le compteur de pièces (PlotUI : 8 + 46 px) ; plus bas quand le bouton « SON » passe sous
-- le compteur (écran de moins de ~1 140 px, SoundManager : 56 + 44 px).
local TOP_WIDE = 60
local TOP_NARROW = 106
local WIDE_SCREEN = 1140
local CHECK_INTERVAL = 0.2 -- secondes entre deux vérifications de l'étape en cours
local DONE_FLASH = 0.8 -- secondes de « ✓ BRAVO ! » avant l'étape suivante
-- Temps de lecture : une étape faite très vite (ex. arrivé sur sa parcelle avant d'avoir fini de lire) garde son
-- texte sous « ✓ BRAVO ! » jusqu'à ce temps-là depuis son apparition : 2 s + 1 s par 15 lettres, entre 3 et 8 s
-- (retour du propriétaire : « j'ai pas eu le temps de lire le texte que j'étais déjà arrivé »).
local READ_MIN, READ_MAX = 3, 8
local READ_CHARS_PER_SECOND = 15
local START_DELAY = 2 -- après le chargement des données : le temps que la map et l'interface arrivent
local CIRCLE_MARGIN = 6 -- studs autour du cercle classé qui comptent comme « dans la zone »
local GUIDE_COLOR = Color3.fromRGB(255, 205, 80) -- doré, comme l'anneau du cercle classé
local DONE_COLOR = Color3.fromRGB(125, 220, 125)

function TutorialUI.start()
	local player = Players.LocalPlayer
	local tutorialAction = Remotes.get("TutorialAction")
	local plotsFolder = workspace:WaitForChild("Hub"):WaitForChild("Plots")
	-- Tests automatiques : le tuto ne démarre jamais tout seul (leurs captures ne changent pas).
	local isAutoTest = ReplicatedStorage:FindFirstChild("__AutoPlayTest") ~= nil
	local autoStart = not isAutoTest and not (RunService:IsStudio() and Config.STUDIO_TUTORIAL == false)

	------------------------------------------------------------------
	-- Ce que le tuto regarde (tout vient des attributs et des objets publiés par le serveur)
	------------------------------------------------------------------
	local running = false
	local runId = 0 -- change à chaque départ ou arrêt : l'ancienne boucle de vérification s'arrête
	local step = 1
	local startedAt = 0 -- os.clock() du départ du tuto
	local flashUntil = 0 -- « ✓ BRAVO ! » affiché jusqu'à cette heure, puis étape suivante (0 = rien)
	local stepShownAt = 0 -- os.clock() de l'apparition de l'étape en cours (temps de lecture)
	local afterShown = false -- l'astuce de fin d'étape (afterText) est affichée sous « ✓ BRAVO ! »
	local lastSpinAt = -math.huge -- dernier résultat de l'Autel des héros reçu (os.clock())
	local lastForgeAt = -math.huge -- dernière ouverture de la Forge runique (os.clock())

	local function rootPart(): BasePart?
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		return if root and root:IsA("BasePart") then root else nil
	end
	local function plotIndex(): number?
		local index = player:GetAttribute("Plot")
		return if typeof(index) == "number" then index else nil
	end
	local function myPlot(): Instance?
		local index = plotIndex()
		return if index then plotsFolder:FindFirstChild("Plot" .. index) else nil
	end
	-- Tours posées sur ta parcelle, triées par emplacement (modèles avec les attributs SpotIndex et Level).
	local function myTowers(): { Instance }
		local plot = myPlot()
		local folder = plot and plot:FindFirstChild("Towers")
		local list = {}
		for _, model in (if folder then folder:GetChildren() else {}) do
			if typeof(model:GetAttribute("SpotIndex")) == "number" then
				table.insert(list, model)
			end
		end
		table.sort(list, function(a, b)
			return a:GetAttribute("SpotIndex") < b:GetAttribute("SpotIndex")
		end)
		return list
	end
	-- Premier emplacement possédé et libre (attribut Unlocked du socle, publié par le serveur).
	local function freeSpot(): BasePart?
		local plot = myPlot()
		local spots = plot and plot:FindFirstChild("Spots")
		if not spots then
			return nil
		end
		local taken = {}
		for _, model in myTowers() do
			taken[model:GetAttribute("SpotIndex")] = true
		end
		local best, bestIndex = nil, math.huge
		for _, pad in spots:GetChildren() do
			local index = pad:GetAttribute("SpotIndex")
			if pad:IsA("BasePart") and pad:GetAttribute("Unlocked") == true and typeof(index) == "number" and not taken[index] and index < bestIndex then
				best, bestIndex = pad, index
			end
		end
		return best
	end
	-- Autel des héros (« TowerMachine ») ou Forge runique (« BonusMachine ») de ta parcelle (Hub/HubMap.luau).
	local function machinePosition(name: string): Vector3?
		local plot = myPlot()
		local machine = plot and plot:FindFirstChild(name)
		return if machine and machine:IsA("BasePart") then machine.Position else nil
	end
	local function forgeOpen(): boolean
		local machines = player.PlayerGui:FindFirstChild("Machines")
		return machines ~= nil and machines:GetAttribute("OpenMachine") == "Bonus" -- (MachineUI)
	end
	local function altarOpen(): boolean
		local machines = player.PlayerGui:FindFirstChild("Machines")
		return machines ~= nil and machines:GetAttribute("OpenMachine") == "Tower" -- (MachineUI)
	end
	local function machineOpen(): boolean
		local machines = player.PlayerGui:FindFirstChild("Machines")
		return machines ~= nil and machines:GetAttribute("OpenMachine") ~= nil
	end
	-- Bouton ou carte vraiment à l'écran (lui et tous ses parents visibles, écran allumé), sinon nil : le tuto
	-- l'entoure d'or (ex. la carte de l'Archer quand le panneau des tours est ouvert).
	local function shownChild(guiName: string, childName: string): GuiObject?
		local screen = player.PlayerGui:FindFirstChild(guiName)
		local child = screen and screen:FindFirstChild(childName, true)
		if not (child and child:IsA("GuiObject")) then
			return nil
		end
		local current: Instance? = child
		while current and current ~= screen do
			if current:IsA("GuiObject") and not current.Visible then
				return nil
			end
			current = current.Parent
		end
		return if screen:IsA("ScreenGui") and screen.Enabled then child else nil
	end

	------------------------------------------------------------------
	-- Les 6 étapes : title et text (panneau ; text peut être une fonction, relue pendant l'étape), marker
	-- (au-dessus de la flèche ▼), button (« Suivant » / « Terminer », sinon aucun : l'action du joueur valide
	-- l'étape), target() = position visée et hauteur de la flèche (nil = pas de guide), highlight() = bouton ou
	-- carte à entourer d'or quand il est à l'écran (facultatif), done() = vrai quand l'étape est faite.
	------------------------------------------------------------------
	local STEPS = {
		{
			title = "LA ZONE CLASSÉE",
			-- Classé fermé : le tuto montre quand même où il est, et dit qu'il arrive bientôt.
			text = function()
				return if RankedGate.isOpen() then TutorialUI.RANKED_STEP_OPEN else TutorialUI.RANKED_STEP_SOON
			end,
			marker = "ARÈNE CLASSÉE",
			button = "Suivant",
			target = function()
				return PlotLayout.RANKED_CIRCLE_POSITION + Vector3.new(0, 0.5, 0), 7
			end,
			done = function()
				if player:GetAttribute("InRankedCircle") == true then
					return true
				end
				local root = rootPart()
				if not root then
					return false
				end
				local offset = root.Position - PlotLayout.RANKED_CIRCLE_POSITION
				return Vector3.new(offset.X, 0, offset.Z).Magnitude <= PlotLayout.RANKED_CIRCLE_RADIUS + CIRCLE_MARGIN
			end,
		},
		{
			title = "TA PARCELLE",
			text = "Voici ta parcelle : des vagues d'ennemis y arrivent sans fin. Retournes-y en suivant le rayon doré.",
			marker = "TA PARCELLE",
			target = function()
				local index = plotIndex()
				return if index then PlotLayout.toWorld(index, Vector3.new(0.5, 0.5, -22)) else nil, 8
			end,
			done = function()
				local index, root = plotIndex(), rootPart()
				if not index or not root then
					return false
				end
				-- Sur le sol de la parcelle, ou devant son entrée (l'autel et la forge).
				local localPosition = PlotLayout.toLocal(index, root.Position)
				return math.abs(localPosition.X) <= PlotLayout.WIDTH / 2 + 2
					and localPosition.Z >= -PlotLayout.LENGTH / 2 - 12
					and localPosition.Z <= PlotLayout.LENGTH / 2 + 2
			end,
		},
		{
			title = "POSE UNE TOUR",
			-- (Retour du propriétaire : avec « une tour », un débutant prend n'importe laquelle : on nomme l'Archer,
			-- et sa carte est entourée d'or dans le panneau des tours.)
			text = `Clique sur un emplacement libre (sous la flèche), puis sur la carte « {IdleTowers.Defs.MachineGun.displayName} » entourée d'or : ta tour tire toute seule.`,
			marker = "ICI",
			highlight = function()
				return shownChild("Plot", "Card_MachineGun")
			end,
			target = function()
				local pad = freeSpot()
				return if pad then pad.Position + Vector3.new(0, 0.4, 0) else nil, 5
			end,
			done = function()
				return #myTowers() > 0
			end,
		},
		{
			title = "AMÉLIORE-LA",
			text = "Clique sur ta tour, puis sur « Améliorer » (entouré d'or) : elle fera plus de dégâts.",
			marker = "TA TOUR",
			highlight = function()
				return shownChild("Plot", "UpgradeButton")
			end,
			target = function()
				local tower, index = myTowers()[1], plotIndex()
				local spot = tower and PlotLayout.SPOTS[tower:GetAttribute("SpotIndex")]
				return if spot and index then PlotLayout.toWorld(index, spot + Vector3.new(0, 0.5, 0)) else nil, 9
			end,
			done = function()
				for _, tower in myTowers() do
					if (tonumber(tower:GetAttribute("Level")) or 1) >= 2 then
						return true
					end
				end
				return false
			end,
		},
		{
			title = "L'AUTEL DES HÉROS",
			-- (Retour du propriétaire : d'abord y aller à pied, pour savoir où il est ; le bouton de gauche est
			-- montré à la fin du tuto.)
			text = "Va à l'Autel des héros (suis le rayon doré), ouvre-le et lance x1 (entouré d'or) : il donne de nouvelles tours.",
			marker = "AUTEL DES HÉROS",
			highlight = function()
				return if altarOpen() then shownChild("Machines", "Spin_1") else nil
			end,
			target = function()
				return machinePosition("TowerMachine"), 8
			end,
			done = function()
				return lastSpinAt >= startedAt or (tonumber(player:GetAttribute("TowerSpinsBought")) or 0) > 0
			end,
		},
		{
			title = "LA FORGE RUNIQUE",
			text = function()
				-- Fenêtre de l'autel encore ouverte (juste après le lancer) : d'abord la fermer (retour du propriétaire).
				if altarOpen() then
					return "Ferme la fenêtre de l'autel (X entouré d'or), puis va à la Forge runique, juste à côté, et ouvre-la."
				end
				-- Prix du prochain lancer en pièces (100K pour un nouveau joueur, voir IdleConfig.forgeCoinPrice).
				local price = IdleConfig.forgeCoinPrice(IdleConfig.cleanSpinsBought(player:GetAttribute("ForgeSpinsBought")))
				return `Va à la Forge runique et ouvre-la : ses runes multiplient les dégâts de tes tours (chères au début : {NumberFormat.short(price)} pièces).`
			end,
			marker = "FORGE RUNIQUE",
			button = "Terminer",
			highlight = function()
				return if altarOpen() then shownChild("Machines", "CloseButton") else nil
			end,
			-- Une fois la forge ouverte, avant la fin : le raccourci (les boutons de gauche), entouré d'or.
			afterText = "Astuce : les boutons « Autel des héros » et « Forge runique », à gauche (entourés d'or), les ouvrent de n'importe où !",
			afterHighlight = function()
				return { shownChild("Machines", "TowerShortcut"), shownChild("Machines", "BonusShortcut") }
			end,
			target = function()
				return machinePosition("BonusMachine"), 8
			end,
			done = function()
				return lastForgeAt >= startedAt or forgeOpen()
			end,
		},
	}

	------------------------------------------------------------------
	-- Panneau (en haut de l'écran, au-dessus des fenêtres des machines, sous « MATCH TROUVÉ ! » et les messages)
	------------------------------------------------------------------
	local gui = UI.screen("Tutorial", 25)
	local panel = UI.new("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, TOP_WIDE),
		Size = UDim2.fromOffset(PANEL_SIZE.X, PANEL_SIZE.Y),
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.08,
		Visible = false,
		Parent = gui,
	}, { UI.corner(12), UI.padding(10) })
	local panelStroke = UI.stroke(UI.Colors.Gold, 2)
	panelStroke.Transparency = 0.2
	panelStroke.Parent = panel
	local panelScale = UI.new("UIScale", { Parent = panel })
	local title = UI.label({
		Name = "Title",
		Size = UDim2.new(1, -108, 0, 22),
		Font = Enum.Font.GothamBlack,
		TextColor3 = UI.Colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 17,
		Parent = panel,
	})
	local body = UI.label({
		Name = "Text",
		Position = UDim2.new(0, 0, 0, 24),
		Size = UDim2.new(1, -108, 1, -24),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		MaxTextSize = 16,
		Parent = panel,
	})
	-- Texte (français) du panneau, gardé ici : body.Text peut être sa traduction anglaise (AutoTranslate.luau), le tuto
	-- ne le relit donc jamais pour décider (temps de lecture, texte à changer).
	local bodyText = ""
	local function setBody(text: string)
		bodyText = text
		body.Text = text
	end
	local nextButton = UI.button({
		Name = "NextButton",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(100, 36),
		BackgroundColor3 = UI.Colors.Success,
		Text = "Suivant",
		MaxTextSize = 18,
		Visible = false,
		Parent = panel,
	})
	local skipButton = UI.button({
		Name = "SkipButton",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 1, 0),
		Size = UDim2.fromOffset(100, 30),
		BackgroundColor3 = UI.Colors.PanelLight,
		Text = "Passer",
		MaxTextSize = 16,
		Parent = panel,
	})

	-- Place du panneau : centré sous le compteur de pièces ; sur un écran étroit, à droite de la carte de rang et
	-- réduit ; sous le bouton « ⚔ S'INSCRIRE AU CLASSÉ » (LobbyUI, dans le cercle) quand il le cacherait.
	-- Téléphone : le panneau des tours (PlotUI, en bas à droite) monte jusqu'ici quand il est ouvert. Le tuto se
	-- cache tant qu'ils se touchent (il revient quand on le ferme) : les cartes des tours et « Améliorer » restent
	-- visibles, et on ne touche jamais « Passer » par erreur à la place d'une carte.
	local function layout()
		local screen = gui.AbsoluteSize
		if screen.X <= 0 or screen.Y <= 0 then
			return
		end
		local scale = math.clamp((screen.X - LEFT_SIDE - 16) / PANEL_SIZE.X, 0.55, 1)
		panelScale.Scale = scale
		local width, height = PANEL_SIZE.X * scale, PANEL_SIZE.Y * scale
		local top = if screen.X >= WIDE_SCREEN then TOP_WIDE else TOP_NARROW
		local lobby = player.PlayerGui:FindFirstChild("Lobby")
		-- (le bouton « S'INSCRIRE », ou « BIENTÔT DISPONIBLE » à sa place quand le classé est fermé)
		for _, name in { "SignUp", "RankedSoon" } do
			local signUp = lobby and lobby:FindFirstChild(name)
			if signUp and signUp:IsA("GuiObject") and signUp.Visible then
				local signTop = signUp.AbsolutePosition.Y - gui.AbsolutePosition.Y
				local signBottom = signTop + signUp.AbsoluteSize.Y
				if top + height > signTop - 4 and top < signBottom then
					top = signBottom + 8
				end
			end
		end
		local centerX = math.max(screen.X / 2, LEFT_SIDE + width / 2)
		panel.Position = UDim2.fromOffset(centerX, top)
		local plotGui = player.PlayerGui:FindFirstChild("Plot")
		local towerPanel = plotGui and plotGui:FindFirstChild("TowerPanel")
		local covered = false
		if towerPanel and towerPanel:IsA("GuiObject") and towerPanel.Visible and plotGui:IsA("ScreenGui") and plotGui.Enabled then
			local towerTop = towerPanel.AbsolutePosition.Y - gui.AbsolutePosition.Y
			local towerLeft = towerPanel.AbsolutePosition.X - gui.AbsolutePosition.X
			covered = towerTop < top + height and towerLeft < centerX + width / 2
		end
		panel.Visible = running and not covered
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)

	------------------------------------------------------------------
	-- Guide dans le monde : un rayon doré du personnage vers la cible, et une flèche ▼ au-dessus de la cible
	------------------------------------------------------------------
	local guide = nil -- { anchor, beam, marker, label } : objets de ce joueur seulement
	local rootAttachment: Attachment? = nil -- dans le personnage actuel (recréé après une mort)

	local function destroyGuide()
		if guide then
			guide.anchor:Destroy()
			guide = nil
		end
		if rootAttachment then
			rootAttachment:Destroy()
			rootAttachment = nil
		end
	end

	local function makeGuide()
		destroyGuide()
		local anchor = UI.new("Part", {
			Name = "TutorialGuide",
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Transparency = 1,
			Size = Vector3.new(0.2, 0.2, 0.2),
		})
		local target = UI.new("Attachment", { Name = "Target", Parent = anchor })
		local beam = UI.new("Beam", {
			Name = "Beam",
			Attachment1 = target,
			Color = ColorSequence.new(GUIDE_COLOR),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0.1) }),
			Width0 = 0.3,
			Width1 = 0.6,
			FaceCamera = true,
			LightEmission = 1,
			LightInfluence = 0,
			Segments = 1,
			Enabled = false,
			Parent = anchor,
		})
		local marker = UI.new("BillboardGui", {
			Name = "Marker",
			Size = UDim2.fromOffset(170, 74),
			AlwaysOnTop = true,
			LightInfluence = 0,
			Enabled = false,
			Parent = anchor,
		})
		local label = UI.label({
			Name = "Label",
			Size = UDim2.new(1, 0, 0, 20),
			Font = Enum.Font.GothamBlack,
			TextColor3 = GUIDE_COLOR,
			TextStrokeTransparency = 0.2,
			MaxTextSize = 16,
			Parent = marker,
		})
		local arrow = UI.label({
			Name = "Arrow",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 20),
			Size = UDim2.fromOffset(52, 48),
			Font = Enum.Font.GothamBlack,
			Text = "▼",
			TextColor3 = GUIDE_COLOR,
			TextStrokeTransparency = 0.1,
			MaxTextSize = 44,
			Parent = marker,
		})
		-- La flèche monte et descend doucement (s'arrête toute seule quand le guide est retiré).
		TweenService:Create(
			arrow,
			TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Position = UDim2.new(0.5, 0, 0, 26) }
		):Play()
		anchor.Parent = workspace
		guide = { anchor = anchor, beam = beam, marker = marker, label = label }
	end

	-- Suit la cible de l'étape et le personnage (nouveau personnage après une mort : le rayon repart de lui).
	local function updateGuide(def)
		if not guide then
			return
		end
		local root = rootPart()
		if rootAttachment and rootAttachment.Parent ~= root then
			rootAttachment:Destroy()
			rootAttachment = nil
		end
		if root and not rootAttachment then
			rootAttachment = UI.new("Attachment", {
				Name = "TutorialGuideRoot",
				Position = Vector3.new(0, -1.2, 0), -- vers les pieds : le rayon court près du sol
				Parent = root,
			})
		end
		local position, height = def.target()
		guide.beam.Attachment0 = rootAttachment
		guide.beam.Enabled = rootAttachment ~= nil and position ~= nil
		guide.marker.Enabled = position ~= nil
		-- Écrit seulement quand il change : traduit en anglais (AutoTranslate), il serait sinon réécrit en français puis
		-- retraduit à chaque vérification.
		if guide.markerText ~= def.marker then
			guide.markerText = def.marker
			guide.label.Text = def.marker
		end
		if position then
			if (guide.anchor.Position - position).Magnitude > 0.05 then
				guide.anchor.CFrame = CFrame.new(position)
			end
			guide.marker.StudsOffsetWorldSpace = Vector3.new(0, height or 6, 0)
		end
	end

	------------------------------------------------------------------
	-- Cadre doré qui clignote autour du bouton ou de la carte à cliquer (highlight de l'étape : carte de l'Archer,
	-- « Améliorer », x1 de l'autel, X de l'autel), seulement quand il est à l'écran.
	------------------------------------------------------------------
	local highlights: { [GuiObject]: Frame } = {} -- [bouton ou carte entouré] = son cadre
	-- targets : un bouton, une liste de boutons (les nil sont ignorés), ou nil (plus aucun cadre).
	local function setHighlight(targets: any)
		local wanted: { [GuiObject]: boolean } = {}
		if typeof(targets) == "Instance" then
			wanted[targets] = true
		elseif type(targets) == "table" then
			for _, target in targets do
				if typeof(target) == "Instance" then
					wanted[target] = true
				end
			end
		end
		for target, frame in highlights do
			if not wanted[target] or frame.Parent ~= target then
				frame:Destroy()
				highlights[target] = nil
			end
		end
		for target in wanted do
			if not highlights[target] then
				local frame = UI.new("Frame", {
					Name = "TutorialHighlight",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.new(1, 8, 1, 8),
					BackgroundTransparency = 1,
					ZIndex = target.ZIndex + 5,
					Parent = target,
				}, { UI.corner(10) })
				local stroke = UI.new("UIStroke", {
					Color = GUIDE_COLOR,
					Thickness = 3,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Parent = frame,
				})
				TweenService:Create(stroke, TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.75 }):Play()
				highlights[target] = frame
			end
		end
	end

	------------------------------------------------------------------
	-- Déroulement
	------------------------------------------------------------------
	-- Boutons du panneau : « Suivant » / « Terminer » seulement si l'étape en a un et pas pendant « ✓ BRAVO ! ».
	-- Aucun des deux (ni « Passer ») tant que l'autel ou la forge est ouvert : réduite (petit écran), leur fenêtre
	-- passe sous le panneau et son X tombait sur « Terminer » (retour du propriétaire : le tuto se fermait quand il
	-- fermait l'autel).
	local function refreshButtons()
		local free = not machineOpen()
		local def = STEPS[step]
		nextButton.Visible = free and flashUntil == 0 and def ~= nil and def.button ~= nil
		skipButton.Visible = free
	end

	local function showStep(index: number)
		step = index
		flashUntil = 0
		afterShown = false
		stepShownAt = os.clock()
		local def = STEPS[index]
		title.Text = `TUTO {index}/{#STEPS} • {def.title}`
		title.TextColor3 = UI.Colors.Gold
		setBody(if typeof(def.text) == "function" then def.text() else def.text)
		nextButton.Text = def.button or ""
		refreshButtons()
	end

	-- Temps pour lire le texte de l'étape en cours (READ_MIN à READ_MAX secondes).
	local function readTime(): number
		local letters = utf8.len(bodyText) or #bodyText
		return math.clamp(2 + letters / READ_CHARS_PER_SECOND, READ_MIN, READ_MAX)
	end

	-- Arrête le tuto chez ce joueur : panneau caché, guide retiré (rien n'est envoyé au serveur).
	local function stop()
		running = false
		runId += 1
		flashUntil = 0
		panel.Visible = false
		destroyGuide()
		setHighlight(nil)
	end

	-- Fin du tuto (« Done » : dernière étape faite ou « Terminer » ; « Skip » : « Passer ») : le serveur note le
	-- drapeau (Hub/Tutorial.luau), qui revient dans l'attribut TutorialDone.
	local function finish(action: string)
		if not running then
			return
		end
		local reached = step
		stop()
		tutorialAction:FireServer(action, reached)
		if action == "Done" then
			SoundManager.play("ChallengeClaim")
			UI.toast("Tuto terminé ! À toi de jouer", "Success")
		else
			UI.toast("Tuto passé : bonne partie !", "Info")
		end
	end

	-- Étape faite : « ✓ BRAVO ! » (son texte reste affiché), puis la suivante (la dernière termine le tuto).
	-- Faite par l'action du joueur : au moins le temps de lire le texte depuis son apparition (readTime). Par le
	-- bouton « Suivant » / « Terminer » : le joueur a fini de lire, juste le court « BRAVO ».
	-- Étape avec afterText (la forge : le raccourci des boutons de gauche) faite par l'action du joueur : ce texte
	-- remplace le sien sous « ✓ BRAVO ! », le temps de le lire, avec afterHighlight entouré d'or.
	local function validate(byButton: boolean)
		if byButton and step >= #STEPS then
			finish("Done")
			return
		end
		local def = STEPS[step]
		local hold = if byButton then DONE_FLASH else math.max(DONE_FLASH, stepShownAt + readTime() - os.clock())
		if not byButton and def.afterText then
			setBody(def.afterText)
			hold = readTime()
			afterShown = true
		end
		flashUntil = os.clock() + hold
		title.Text = "✓ BRAVO !"
		title.TextColor3 = DONE_COLOR
		refreshButtons()
	end

	local function update()
		layout()
		if flashUntil > 0 then
			if os.clock() >= flashUntil then
				if step >= #STEPS then
					finish("Done")
				else
					showStep(step + 1)
				end
			end
		elseif STEPS[step].done() then
			validate(false)
		end
		if running then
			local def = STEPS[step]
			refreshButtons()
			-- Texte qui dépend de ce qui est ouvert (ex. la forge : « ferme d'abord l'autel »).
			if flashUntil == 0 and typeof(def.text) == "function" then
				local text = def.text()
				if bodyText ~= text then
					setBody(text)
				end
			end
			local targets = nil
			if flashUntil == 0 and def.highlight then
				targets = def.highlight()
			elseif afterShown and def.afterHighlight then
				targets = def.afterHighlight()
			end
			setHighlight(targets)
			updateGuide(def)
		end
	end

	local function begin()
		stop()
		running = true
		startedAt = os.clock()
		local myRun = runId
		makeGuide()
		showStep(1)
		panel.Visible = true
		layout() -- (caché tant que le panneau des tours le couvre, voir layout)
		task.spawn(function()
			while running and runId == myRun do
				update()
				task.wait(CHECK_INTERVAL)
			end
		end)
	end

	nextButton.Activated:Connect(function()
		if not running or flashUntil > 0 then
			return
		end
		validate(true)
	end)
	skipButton.Activated:Connect(function()
		finish("Skip")
	end)

	------------------------------------------------------------------
	-- Ce qui valide les étapes 5 et 6, et le départ du tuto
	------------------------------------------------------------------
	Remotes.get("MachineResult").OnClientEvent:Connect(function(result)
		if typeof(result) == "table" and result.machine == "Tower" then
			lastSpinAt = os.clock()
		end
	end)
	-- Forge ouverte par son invite (serveur) ou par un bouton de gauche (attribut OpenMachine de MachineUI).
	Remotes.get("OpenMachine").OnClientEvent:Connect(function(machine)
		if machine == "Bonus" then
			lastForgeAt = os.clock()
		end
	end)
	task.spawn(function()
		local machines = player.PlayerGui:WaitForChild("Machines", 30)
		if machines then
			machines:GetAttributeChangedSignal("OpenMachine"):Connect(function()
				if machines:GetAttribute("OpenMachine") == "Bonus" then
					lastForgeAt = os.clock()
				end
				if running then
					refreshButtons() -- tout de suite, pas au prochain tour de update
				end
			end)
		end
	end)

	-- Tuto fini ou passé (réponse du serveur) : plus rien à l'écran.
	player:GetAttributeChangedSignal("TutorialDone"):Connect(function()
		if running and player:GetAttribute("TutorialDone") == true then
			stop()
		end
	end)
	-- Studio : « Replay » (Hub/Tutorial.luau) -> le tuto recommence à l'étape 1, même pendant les tests automatiques.
	player:GetAttributeChangedSignal("TutorialReplay"):Connect(begin)

	-- Nouveau joueur : le tuto démarre tout seul une fois ses données chargées (TutorialDone = faux).
	task.spawn(function()
		while not player:GetAttribute("DataLoaded") do
			player:GetAttributeChangedSignal("DataLoaded"):Wait()
		end
		task.wait(START_DELAY)
		if autoStart and not running and player:GetAttribute("TutorialDone") == false then
			begin()
		end
	end)
end

return TutorialUI

-- TUTO des nouveaux joueurs : une grosse FLÈCHE dorée qui rebondit, avec deux ou trois mots (« JOUE ICI »), montre à
-- chaque instant ce qu'il faut toucher. Pas d'écran à lire, rien n'est bloqué : le joueur peut toujours faire autre
-- chose, et le bouton « Passer le tuto » l'arrête pour de bon.
-- Leçons de l'ancien jeu (01/10/2026) : « le didacticiel fait fuir les gens avant même qu'ils commencent à jouer » ->
-- il démarre tout de suite par une action, avec des flèches, sans texte à lire avant de jouer.
--
-- Trois moments, d'après l'étape gardée par le serveur (champ `tutorial` de l'état du joueur, Levels.TUTORIAL) :
--   étape 0 (nouveau joueur), au camp : la fenêtre des niveaux s'ouvre toute seule, la flèche montre « ▶ JOUER » du
--     niveau 1 (ou le bouton « ⚔ NIVEAUX » s'il a fermé la fenêtre) ;
--   étape 0, pendant le niveau 1 : ses DEUX PREMIERS GESTES (Levels.firstSteps), puis plus rien. Retour du
--     propriétaire (03/10/2026) : « juste poser une tour, et pas forcer un positionnement, et améliorer, et fin, le
--     gars se débrouille ». La flèche montre une tour de la barre (« PRENDS UN ARCHER ») ; tour en main, seuls des
--     mots disent « POSE-LA OÙ TU VEUX » (aucun endroit n'est montré) ; puis une tour (« TOUCHE CETTE TOUR ») et son
--     bouton « AMÉLIORE ». Ensuite, plus de flèche jusqu'à la fin du niveau, même s'il le rejoue. Défaite : la
--     flèche montre « Réessayer ». Victoire : « Niveau 2 ▶ », et le serveur passe à l'étape 1 ;
--   étape 1 : dès que le joueur a de quoi acheter une tour (en général après le niveau 2 : le Totem de givre), la
--     flèche montre « Retour au camp » sur l'écran de fin d'un niveau, puis au camp la Boutique et le bouton
--     « ACHETER ». L'achat termine le tuto (étape 2).
-- Tout vient de ce que le serveur publie (attributs LevelsState et LevelArena du joueur, attributs de sa zone de
-- combat) et des écrans construits par LevelsUI (leurs objets gardent leurs noms) : ce module ne décide rien du jeu.
-- Pour les tests (Studio) : l'écran « TutorialPointer » porte les attributs « Target » (nom de l'objet montré,
-- « World » pour un point du terrain, « Note » pour des mots seuls, sans flèche ; vide sans flèche),
-- « TargetPoint » (ce point du terrain, dans le monde),
-- « Caption » (ses mots, en français) et « Stage ».
-- Studio : tes données y sont en mémoire, tu es un nouveau joueur à chaque Play et le tuto revient à chaque fois
-- (Config.STUDIO_TUTORIAL = false pour ne plus le voir). Tests automatiques (ReplicatedStorage.__AutoPlayTest) :
-- jamais, sauf dans la place du test « tutorial » (objet __AutoTestNewPlayer).
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Levels = require(Shared.Levels)
local Remotes = require(Shared.Remotes)
local LevelsUI = require(script.Parent.LevelsUI)
local UI = require(script.Parent.UI)

local TutorialUI = {}

-- Les mots de la flèche (2 à 4 mots, en majuscules ; anglais : Shared/LangEN/Game.luau).
TutorialUI.CAPTIONS = {
	Open = "APPUIE ICI",
	LevelsTab = "LES NIVEAUX",
	Play = "JOUE ICI",
	Take = { MachineGun = "PRENDS UN ARCHER", Bomb = "PRENDS UNE CATAPULTE" },
	TakeOther = "PRENDS CETTE TOUR",
	Place = "POSE-LA OÙ TU VEUX",
	Tower = "TOUCHE CETTE TOUR",
	Upgrade = "AMÉLIORE",
	Next = "CONTINUE",
	Retry = "RÉESSAIE",
	ShopOpen = "NOUVELLE TOUR !",
	ShopTab = "LA BOUTIQUE",
	Buy = "ACHÈTE-LA",
}
TutorialUI.SKIP_TEXT = "Passer le tuto"
TutorialUI.SKIP_CONFIRM_TEXT = "Confirmer ?"

local CHECK_INTERVAL = 0.2 -- secondes entre deux choix de ce que la flèche montre
local START_DELAY = 1.2 -- après le chargement des données : le temps que les écrans arrivent
local SKIP_CONFIRM_TIME = 3 -- téléphone : secondes pour toucher « Passer » une 2e fois (« Confirmer ? »)
local GUIDE_COLOR = Color3.fromRGB(255, 205, 80)

-- La flèche (px). Elle est dessinée avec des barres dorées (pas d'image ; le caractère « ▼ » était trop petit sur un
-- téléphone), dans un carré tourné vers sa cible.
TutorialUI.POINTER_ARROW = 56 -- côté du carré : la flèche fait toute sa hauteur
local POINTER_TIP = TutorialUI.POINTER_ARROW / 2 -- du milieu du carré à la pointe de la flèche
local POINTER_BAR = 13 -- épaisseur de ses barres
local POINTER_GAP = 5 -- entre la pointe et le bouton montré
local POINTER_BOUNCE = 10 -- elle recule et revient de tant
local POINTER_BOUNCE_SPEED = 7
local POINTER_CAPTION_HEIGHT = 28
local POINTER_CAPTION_WIDTH = 170 -- largeur prévue pour ses mots, quand ils se mettent à côté d'un bouton
local POINTER_EDGE = 24 -- un petit bouton à moins de tant du bord gauche ou droit de l'écran : la flèche se met à côté
local POINTER_SMALL = Vector2.new(200, 64) -- « petit bouton » : au plus cette taille
local POINTER_MARGIN = 40 -- cible du terrain hors de l'écran : la pointe de la flèche est à tant du bord
local POINTER_BOTTOM_STRIP = 40 -- bande du bas de l'écran laissée libre sous une flèche mise SOUS un bouton (« Passer »)
local TOWER_RADIUS = 22 -- px laissés libres autour d'une tour montrée sur le terrain
local NOTE_GAP = 6 -- mots seuls (sans flèche) : à tant au-dessus du conseil du jeu, lui-même au-dessus de la barre
-- Place qu'il faut à la flèche seule, puis à la flèche et à ses mots au bout.
local POINTER_NEED = 2 * POINTER_TIP + POINTER_BOUNCE + POINTER_GAP
local POINTER_NEED_WORDS = POINTER_NEED + POINTER_GAP + POINTER_CAPTION_HEIGHT

-- La flèche a-t-elle la place de ce côté du bouton ? (Ses mots se mettent au bout d'elle, ou au-dessus d'une flèche
-- de côté quand ils n'ont pas la place derrière : voir placePointer.)
local function sideFits(side: string, screen: Vector2, position: Vector2, size: Vector2): boolean
	if side == "top" then
		return position.Y >= POINTER_NEED_WORDS
	elseif side == "bottom" then
		return position.Y + size.Y + POINTER_NEED_WORDS + POINTER_BOTTOM_STRIP <= screen.Y
	elseif side == "right" then
		return position.X + size.X + POINTER_NEED + 4 <= screen.X
	end
	return position.X - POINTER_NEED - 4 >= 0
end

-- De quel côté d'un bouton se met la flèche (fonction pure). Le bouton est le rectangle `position` (coin en haut à
-- gauche), `size`, dans un écran de taille `screen`.
--   "top" = au-dessus, elle pointe vers le bas (le cas normal) ; "bottom" = dessous, quand la place manque au-dessus ;
--   "left" = à sa gauche, elle pointe vers la droite ; "right" = à sa droite, elle pointe vers la gauche.
--   prefer = côtés à essayer d'abord, dans l'ordre (le premier où la flèche a la place) : un bouton dans une fenêtre
--   est montré du côté où la flèche ne cache ni le texte de la fenêtre ni un autre bouton (ex. « Améliorer » : par
--   la gauche, en dehors du menu de la tour).
--   Sinon : petit bouton collé au bord droit de l'écran : à sa gauche ; collé au bord gauche : à sa droite ;
--   grande cible sans la place au-dessus pour la flèche et ses mots : à côté d'elle, à droite de préférence.
function TutorialUI.pointerSide(screen: Vector2, position: Vector2, size: Vector2, prefer: { string }?): string
	for _, side in prefer or {} do
		if sideFits(side, screen, position, size) then
			return side
		end
	end
	local small = size.X <= POINTER_SMALL.X and size.Y <= POINTER_SMALL.Y
	local below = position.Y + size.Y + POINTER_NEED_WORDS <= screen.Y
	if small then
		if position.X + size.X >= screen.X - POINTER_EDGE then
			return "left"
		elseif position.X <= POINTER_EDGE then
			return "right"
		elseif position.Y >= POINTER_NEED then
			return "top"
		end
		return if below then "bottom" else "top"
	end
	if position.Y >= POINTER_NEED_WORDS then
		return "top"
	end
	local beside = POINTER_NEED + POINTER_GAP + POINTER_CAPTION_WIDTH
	if position.X + size.X + beside <= screen.X then
		return "right"
	elseif position.X - beside >= 0 then
		return "left"
	end
	return if below then "bottom" else "top"
end

local SIDE_DIRECTIONS = {
	top = Vector2.new(0, 1),
	bottom = Vector2.new(0, -1),
	left = Vector2.new(1, 0),
	right = Vector2.new(-1, 0),
}
-- Où va la pointe de la flèche pour ce bouton, et dans quel sens elle pointe (vecteur de la flèche vers le bouton).
-- Fonction pure. Renvoie aussi le côté (TutorialUI.pointerSide).
function TutorialUI.pointerAt(screen: Vector2, position: Vector2, size: Vector2, prefer: { string }?): (Vector2, Vector2, string)
	local side = TutorialUI.pointerSide(screen, position, size, prefer)
	local center = position + size / 2
	local tip
	if side == "top" then
		tip = Vector2.new(center.X, position.Y - POINTER_GAP)
	elseif side == "bottom" then
		tip = Vector2.new(center.X, position.Y + size.Y + POINTER_GAP)
	elseif side == "left" then
		tip = Vector2.new(position.X - POINTER_GAP, center.Y)
	else
		tip = Vector2.new(position.X + size.X + POINTER_GAP, center.Y)
	end
	return tip, SIDE_DIRECTIONS[side], side
end

-- Cible du terrain hors de l'écran : la flèche se met au bord de l'écran, dans la direction `direction` (vecteur
-- écran : x vers la droite, y vers le bas) depuis le milieu, et pointe vers l'extérieur. Fonction pure.
function TutorialUI.pointerToward(screen: Vector2, direction: Vector2): (Vector2, Vector2)
	local d = if direction.Magnitude > 1e-3 then direction.Unit else Vector2.new(0, 1)
	local reachX = if math.abs(d.X) > 1e-3 then (screen.X / 2 - POINTER_MARGIN) / math.abs(d.X) else math.huge
	local reachY = if math.abs(d.Y) > 1e-3 then (screen.Y / 2 - POINTER_MARGIN) / math.abs(d.Y) else math.huge
	return screen / 2 + d * math.max(0, math.min(reachX, reachY)), d
end

function TutorialUI.start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local levelAction = Remotes.get("LevelAction")
	local CAPTIONS = TutorialUI.CAPTIONS
	-- Tests automatiques : le tuto ne démarre jamais tout seul (leurs captures ne changent pas), sauf dans la place du
	-- test « tutorial » (objet __AutoTestNewPlayer, tools/studio-test/mkproj.cjs).
	local isAutoTest = ReplicatedStorage:FindFirstChild("__AutoPlayTest") ~= nil
		and ReplicatedStorage:FindFirstChild("__AutoTestNewPlayer") == nil
	if isAutoTest or (RunService:IsStudio() and Config.STUDIO_TUTORIAL == false) then
		return
	end

	------------------------------------------------------------------
	-- Ce que le tuto regarde
	------------------------------------------------------------------
	local state = { tutorial = Levels.TUTORIAL.DONE, coins = 0, towers = {} :: { string } }
	local function readState()
		local raw = player:GetAttribute("LevelsState")
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(raw)
		end)
		if not ok or typeof(decoded) ~= "table" then
			return
		end
		state = {
			tutorial = tonumber(decoded.tutorial) or Levels.TUTORIAL.DONE,
			coins = tonumber(decoded.coins) or 0,
			towers = if typeof(decoded.towers) == "table" then decoded.towers else {},
		}
	end

	-- Objet d'un écran du jeu par son chemin (« Levels », « Window », « Page1 »...), nil s'il manque.
	local function find(...: string): Instance?
		local current: Instance? = playerGui
		for index = 1, select("#", ...) do
			current = current and current:FindFirstChild((select(index, ...)))
		end
		return current
	end
	-- Vrai si l'objet est vraiment affiché : lui et tous ses parents visibles, écran allumé.
	local function shown(object: Instance?): boolean
		local current = object
		while current and not current:IsA("LayerCollector") do
			if current:IsA("GuiObject") and not current.Visible then
				return false
			end
			current = current.Parent
		end
		return current ~= nil and current:IsA("ScreenGui") and current.Enabled
	end
	-- Un bouton à montrer : ses mots, les côtés préférés de la flèche (TutorialUI.pointerSide ; nil = au mieux), et
	-- son chemin dans les écrans du jeu.
	local function button(caption: string, prefer: { string }?, ...: string)
		local object = find(...)
		return if object and object:IsA("GuiObject") and shown(object) then { gui = object, caption = caption, prefer = prefer } else nil
	end
	-- Sous le bouton d'une carte (la flèche ne cache pas la carte qu'elle montre) ; par la gauche, hors du menu de la
	-- tour (jamais par la droite : elle serait sur « Vendre ») ; à côté de l'écran de fin, en dehors de son panneau.
	local BELOW, MENU_SIDE, PANEL_SIDE = { "bottom" }, { "left", "top" }, { "right", "left" }

	-- Zone de combat du joueur pendant un niveau (workspace.Arenas.Arena<n>), nil au camp.
	local function arenaFolder(): Instance?
		local index = player:GetAttribute("LevelArena")
		if typeof(index) ~= "number" or not Levels.isArena(index) then
			return nil
		end
		local arenas = workspace:FindFirstChild("Arenas")
		return arenas and arenas:FindFirstChild("Arena" .. Levels.slotOf(index))
	end
	-- Tours posées dans le niveau : { model, type, level }, de la plus ancienne à la plus récente.
	local function levelTowers(arena: Instance)
		local folder = arena:FindFirstChild("Towers")
		local list = {}
		for _, model in if folder then folder:GetChildren() else {} do
			local id = model:GetAttribute("TowerId")
			if model:IsA("Model") and typeof(id) == "number" then
				table.insert(list, { model = model, id = id, type = model:GetAttribute("TowerType"), level = model:GetAttribute("Level") or 1 })
			end
		end
		table.sort(list, function(a, b)
			return a.id < b.id
		end)
		return list
	end
	local function towerPoint(model: Model): Vector3
		local rest = model:GetAttribute("RestCFrame")
		return (if typeof(rest) == "CFrame" then rest.Position else model:GetPivot().Position) + Vector3.new(0, 3, 0)
	end

	------------------------------------------------------------------
	-- Ce que la flèche montre maintenant : { gui = bouton, caption }, { world = point du terrain, caption } ou
	-- { note = true, caption } (des mots seuls, sans flèche), ou nil.
	------------------------------------------------------------------
	local opened = false -- la fenêtre des niveaux a déjà été ouverte une fois pour ce nouveau joueur
	local guideDone = false -- ses deux premiers gestes du niveau 1 sont faits : plus de flèche pendant ce niveau
	local guideStage = nil -- étape du tuto quand guideDone a été remis à faux (il y revient si l'étape change)

	local function campTarget()
		local window = find("Levels", "Window")
		if not (window and window:IsA("GuiObject")) or not shown(window) then
			return button(CAPTIONS.Open, nil, "Levels", "LevelsButton")
		end
		local page = find("Levels", "Window", "Page1")
		if not (page and page:IsA("GuiObject") and page.Visible) then
			return button(CAPTIONS.LevelsTab, nil, "Levels", "Window", "Tab1")
		end
		return button(CAPTIONS.Play, BELOW, "Levels", "Window", "Page1", "Level1", "Play")
	end

	-- Pendant le niveau 1 : ses deux premiers gestes (Levels.firstSteps dit lequel, ici on montre où appuyer), puis rien.
	local function levelTarget(arena: Instance)
		local hud = find("LevelHud")
		if not hud then
			return nil
		end
		local endScreen = find("LevelHud", "EndScreen")
		if endScreen and endScreen:IsA("GuiObject") and endScreen.Visible then
			local won = arena:GetAttribute("State") == "Won"
			return button(if won then CAPTIONS.Next else CAPTIONS.Retry, PANEL_SIDE, "LevelHud", "EndScreen", "Panel", "Next")
		end
		if arena:GetAttribute("State") ~= "Running" or guideDone then
			return nil
		end
		local gold = tonumber(arena:GetAttribute("Gold")) or 0
		local placing = hud:GetAttribute("Placing")
		local selected = hud:GetAttribute("Selected")
		local towers = levelTowers(arena)
		local advice, done = Levels.firstSteps(state.towers, towers, gold)
		if done then
			guideDone = true -- (le gars se débrouille : plus rien jusqu'à la fin du niveau, même s'il le rejoue)
			return nil
		end
		-- Une tour en main, pour le premier geste : des mots seulement, il la pose où il veut (s'il a de quoi la payer).
		if typeof(placing) == "string" and placing ~= "" then
			local cost = Levels.TOWER_COST[placing]
			return if cost and gold >= cost and #towers < 2 then { note = true, caption = CAPTIONS.Place } else nil
		end
		if not advice then
			return nil -- (pas encore assez d'or : rien à montrer, l'or arrive)
		end
		if advice.kind == "Place" then
			return button(CAPTIONS.Take[advice.tower] or CAPTIONS.TakeOther, nil, "LevelHud", "TowerBar", "Tower_" .. advice.tower)
		end
		-- Améliorer : la tour qu'il a touchée, s'il peut la payer ; sinon la flèche montre la moins chère.
		for _, tower in towers do
			local cost = if selected == tower.id then Levels.upgradeCost(tower.type, tower.level) else nil
			if cost and gold >= cost then
				return button(CAPTIONS.Upgrade, MENU_SIDE, "LevelHud", "TowerMenu", "Upgrade")
			end
		end
		local tower = towers[advice.index]
		return if tower then { world = towerPoint(tower.model), caption = CAPTIONS.Tower } else nil
	end

	-- La tour la moins chère de la boutique que le joueur peut s'offrir (nil : aucune pour l'instant).
	local function affordableTower(): string?
		local wanted, wantedPrice = nil, math.huge
		for towerType, price in Levels.SHOP do
			if not table.find(state.towers, towerType) and price <= state.coins and price < wantedPrice then
				wanted, wantedPrice = towerType, price
			end
		end
		return wanted
	end

	-- Étape 1, au camp : de quoi acheter une tour -> la boutique.
	local function shopTarget()
		local wanted = affordableTower()
		if not wanted then
			return nil
		end
		local window = find("Levels", "Window")
		if not (window and window:IsA("GuiObject")) or not shown(window) then
			return button(CAPTIONS.ShopOpen, nil, "Levels", "LevelsButton")
		end
		local page = find("Levels", "Window", "Page2")
		if not (page and page:IsA("GuiObject") and page.Visible) then
			return button(CAPTIONS.ShopTab, nil, "Levels", "Window", "Tab2")
		end
		return button(CAPTIONS.Buy, BELOW, "Levels", "Window", "Page2", "Shop_" .. wanted, "Buy")
	end

	local function resolve()
		if state.tutorial >= Levels.TUTORIAL.DONE then
			return nil
		end
		local arena = arenaFolder()
		if state.tutorial < Levels.TUTORIAL.SHOP then
			if arena then
				return if arena:GetAttribute("Level") == 1 then levelTarget(arena) else nil
			end
			return campTarget()
		end
		-- Étape 1, sur l'écran de fin d'un niveau : de quoi acheter une tour -> « Retour au camp » (la boutique l'y
		-- attend) ; sinon, juste après la victoire du niveau 1, la flèche montre encore « Niveau 2 ▶ ».
		if arena then
			local endScreen = find("LevelHud", "EndScreen")
			if not (endScreen and endScreen:IsA("GuiObject") and endScreen.Visible) then
				return nil
			end
			if affordableTower() then
				return button(CAPTIONS.ShopOpen, PANEL_SIDE, "LevelHud", "EndScreen", "Panel", "Camp")
			end
			if arena:GetAttribute("Level") == 1 and arena:GetAttribute("State") == "Won" then
				return button(CAPTIONS.Next, PANEL_SIDE, "LevelHud", "EndScreen", "Panel", "Next")
			end
			return nil
		end
		return shopTarget()
	end

	------------------------------------------------------------------
	-- La flèche : sur son propre écran, au-dessus de toutes les fenêtres et sous les messages. Elle ne prend aucun
	-- clic. `pointed` = ce qu'elle montre, choisi à chaque vérification ; sa place est recalculée à chaque image (la
	-- caméra et les fenêtres bougent).
	------------------------------------------------------------------
	local pointerGui = UI.screen("TutorialPointer", 45)
	pointerGui:SetAttribute("Target", "")
	pointerGui:SetAttribute("Caption", "")
	pointerGui:SetAttribute("Stage", state.tutorial)
	-- Le carré de la flèche : elle pointe vers le BAS quand il n'est pas tourné (Rotation = 0), sa pointe au milieu de
	-- son bord du bas. Trois barres arrondies (la tige et les deux ailes de la pointe), chacune sur une barre sombre
	-- un peu plus large qui fait son contour.
	local arrow = UI.new("Frame", {
		Name = "Arrow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(TutorialUI.POINTER_ARROW, TutorialUI.POINTER_ARROW),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = pointerGui,
	})
	local function arrowBar(center: Vector2, length: number, rotation: number)
		for _, outline in { 6, 0 } do
			UI.new("Frame", {
				Name = if outline > 0 then "Outline" else "Bar",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(center.X, center.Y),
				Size = UDim2.fromOffset(POINTER_BAR + outline, length + outline),
				Rotation = rotation,
				BackgroundColor3 = if outline > 0 then UI.Colors.Ink else GUIDE_COLOR,
				ZIndex = if outline > 0 then 1 else 2,
				Parent = arrow,
			}, { UI.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
		end
	end
	do
		local middle, wing = TutorialUI.POINTER_ARROW / 2, 30
		local slant = math.sin(math.rad(45))
		-- Bout des deux ailes : leur contour sombre (3 px) touche juste le bas du carré.
		local tipY = TutorialUI.POINTER_ARROW - 3 - POINTER_BAR / 2 * (1 - slant)
		local reach = wing / 2 * slant
		arrowBar(Vector2.new(middle, (3 + tipY) / 2), tipY - 3, 0)
		arrowBar(Vector2.new(middle + reach, tipY - reach), wing, 45)
		arrowBar(Vector2.new(middle - reach, tipY - reach), wing, -45)
	end
	local caption = UI.new("TextLabel", {
		Name = "Caption",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(120, POINTER_CAPTION_HEIGHT),
		BackgroundColor3 = UI.Colors.Background,
		BackgroundTransparency = 0.05,
		Font = UI.TitleFont,
		Text = "",
		TextSize = 16,
		TextColor3 = GUIDE_COLOR,
		Visible = false,
		Parent = pointerGui,
	}, { UI.corner(9), UI.stroke(GUIDE_COLOR, 2) })
	-- (largeur selon le texte affiché, qui peut être sa traduction anglaise : AutoTranslate)
	caption:GetPropertyChangedSignal("TextBounds"):Connect(function()
		caption.Size = UDim2.fromOffset(math.ceil(caption.TextBounds.X) + 24, POINTER_CAPTION_HEIGHT)
	end)

	local running = false
	local pointed = nil -- { gui | world, caption } ou nil
	local function setPointed(target)
		pointed = target
		local name, words = "", ""
		if target then
			name = if target.gui then target.gui.Name elseif target.note then "Note" else "World"
			words = target.caption or ""
		end
		if pointerGui:GetAttribute("Target") ~= name then
			pointerGui:SetAttribute("Target", name)
		end
		local point = if target then target.world else nil
		if pointerGui:GetAttribute("TargetPoint") ~= point then
			pointerGui:SetAttribute("TargetPoint", point)
		end
		-- Écrit seulement quand il change : traduit en anglais (AutoTranslate), il serait sinon réécrit en français
		-- puis retraduit à chaque vérification.
		if pointerGui:GetAttribute("Caption") ~= words then
			pointerGui:SetAttribute("Caption", words)
			caption.Text = words
		end
		if not target then
			arrow.Visible = false
			caption.Visible = false
		end
	end

	-- Place de la flèche et de ses mots, à chaque image.
	local function placePointer()
		local target = pointed
		if not running or not target then
			return
		end
		local screen = pointerGui.AbsoluteSize
		local origin = pointerGui.AbsolutePosition
		if target.note then
			-- Des mots seuls, sans flèche (« POSE-LA OÙ TU VEUX » : aucun endroit montré), au milieu, juste au-dessus du
			-- conseil du jeu (il est au-dessus de la barre des tours, même quand il n'a pas de texte).
			arrow.Visible = false
			local hint = find("LevelHud", "Hint")
			local bottom = if hint and hint:IsA("GuiObject") then hint.AbsolutePosition.Y - origin.Y else screen.Y - 120
			local height = caption.AbsoluteSize.Y
			caption.Position = UDim2.fromOffset(screen.X / 2, math.max(height / 2 + 2, bottom - NOTE_GAP - height / 2))
			caption.Visible = (target.caption or "") ~= ""
			return
		end
		local tip, direction
		if target.gui then
			local object = target.gui :: GuiObject
			-- (bouton d'une page qui défile, sorti de la page : la flèche se cache au lieu de pointer hors de la fenêtre)
			local page = object:FindFirstAncestorWhichIsA("ScrollingFrame")
			local middle = object.AbsolutePosition + object.AbsoluteSize / 2
			local clipped = page ~= nil
				and (middle.Y < page.AbsolutePosition.Y or middle.Y > page.AbsolutePosition.Y + page.AbsoluteSize.Y
					or middle.X < page.AbsolutePosition.X or middle.X > page.AbsolutePosition.X + page.AbsoluteSize.X)
			if not object:IsDescendantOf(playerGui) or not shown(object) or clipped then
				arrow.Visible = false
				caption.Visible = false
				return
			end
			tip, direction = TutorialUI.pointerAt(screen, object.AbsolutePosition - origin, object.AbsoluteSize, target.prefer)
		else
			local camera = workspace.CurrentCamera
			if not camera then
				return
			end
			-- (WorldToScreenPoint tient compte de la barre du haut de Roblox, comme la place des boutons)
			local point = camera:WorldToScreenPoint(target.world)
			local at = Vector2.new(point.X, point.Y) - origin
			local inside = point.Z > 0
				and at.X >= POINTER_MARGIN and at.X <= screen.X - POINTER_MARGIN
				and at.Y >= POINTER_MARGIN and at.Y <= screen.Y - POINTER_MARGIN
			if inside and (at.Y - TOWER_RADIUS >= POINTER_NEED or at.Y + TOWER_RADIUS + POINTER_NEED_WORDS > screen.Y) then
				tip, direction = at - Vector2.new(0, TOWER_RADIUS + POINTER_GAP), SIDE_DIRECTIONS.top
			elseif inside then
				tip, direction = at + Vector2.new(0, TOWER_RADIUS + POINTER_GAP), SIDE_DIRECTIONS.bottom
			else
				-- Hors de l'écran (vue zoomée ou déplacée) : au bord de l'écran, du côté où elle est.
				local relative = camera.CFrame:PointToObjectSpace(target.world)
				tip, direction = TutorialUI.pointerToward(screen, Vector2.new(relative.X, -relative.Y))
			end
		end
		local bounce = (math.sin(os.clock() * POINTER_BOUNCE_SPEED) * 0.5 + 0.5) * POINTER_BOUNCE
		local arrowAt = tip - direction * (POINTER_TIP + bounce)
		arrow.Position = UDim2.fromOffset(arrowAt.X, arrowAt.Y)
		arrow.Rotation = math.deg(math.atan2(-direction.X, direction.Y))
		arrow.Visible = true
		-- Ses mots : au bout de la flèche, derrière elle. Flèche vers le bas sans la place au-dessus (cible près du haut
		-- de l'écran) : à côté d'elle, à droite de préférence.
		local words = caption.AbsoluteSize
		local half = math.abs(direction.X) * words.X / 2 + math.abs(direction.Y) * words.Y / 2
		local captionAt = tip - direction * (2 * POINTER_TIP + POINTER_BOUNCE + POINTER_GAP + half)
		if direction.Y > 0.9 and captionAt.Y - words.Y / 2 < 2 then
			local beside = POINTER_TIP + POINTER_GAP + words.X / 2
			local onRight = tip.X + beside + words.X / 2 <= screen.X - 4
			captionAt = Vector2.new(tip.X + (if onRight then beside else -beside), tip.Y - POINTER_TIP - POINTER_BOUNCE / 2)
		elseif math.abs(direction.X) > 0.9 and (captionAt.X - words.X / 2 < 4 or captionAt.X + words.X / 2 > screen.X - 4) then
			-- Flèche de côté sans la place derrière elle pour ses mots : au-dessus d'elle (dessous si la place manque).
			local middle = tip - direction * (POINTER_TIP + POINTER_BOUNCE / 2)
			local above = middle.Y - POINTER_TIP - POINTER_GAP - words.Y / 2
			captionAt = Vector2.new(middle.X, if above - words.Y / 2 >= 2 then above else middle.Y + POINTER_TIP + POINTER_GAP + words.Y / 2)
		end
		caption.Position = UDim2.fromOffset(
			math.clamp(captionAt.X, words.X / 2 + 4, math.max(words.X / 2 + 4, screen.X - words.X / 2 - 4)),
			math.clamp(captionAt.Y, words.Y / 2 + 2, math.max(words.Y / 2 + 2, screen.Y - words.Y / 2 - 4))
		)
		caption.Visible = (target.caption or "") ~= ""
	end
	RunService.RenderStepped:Connect(placePointer)

	------------------------------------------------------------------
	-- Cadre doré qui clignote autour du bouton que la flèche montre.
	------------------------------------------------------------------
	local highlights: { [GuiObject]: Frame } = {}
	local function setHighlight(target: GuiObject?)
		for object, frame in highlights do
			if object ~= target or frame.Parent ~= object then
				frame:Destroy()
				highlights[object] = nil
			end
		end
		if target and not highlights[target] then
			local frame = UI.new("Frame", {
				Name = "TutorialHighlight",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(1, 8, 1, 8),
				BackgroundTransparency = 1,
				ZIndex = target.ZIndex + 5,
				Parent = target,
			}, { UI.corner(8) })
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

	------------------------------------------------------------------
	-- Bouton « Passer le tuto » : petit, en bas à gauche (le joystick de Roblox n'y est pas pendant un niveau, et au
	-- camp il passe par-dessous). Téléphone : il faut le toucher DEUX fois (« Confirmer ? »), un appui par erreur ne
	-- doit pas faire perdre le tuto.
	------------------------------------------------------------------
	local skipButton = UI.button({
		Name = "Skip",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 8, 1, -8),
		Size = UDim2.fromOffset(132, 30),
		BackgroundColor3 = UI.Colors.PanelLight,
		Text = TutorialUI.SKIP_TEXT,
		MaxTextSize = 14,
		Visible = false,
		Parent = pointerGui,
	})
	local skipArmedAt = -math.huge
	local function disarmSkip()
		skipArmedAt = -math.huge
		skipButton.Text = TutorialUI.SKIP_TEXT
		skipButton.BackgroundColor3 = UI.Colors.PanelLight
	end
	local function pressSkip()
		if not running then
			return
		end
		if UI.touchLayout(UI.screenSize(pointerGui)) and os.clock() - skipArmedAt > SKIP_CONFIRM_TIME then
			local armedAt = os.clock()
			skipArmedAt = armedAt
			skipButton.Text = TutorialUI.SKIP_CONFIRM_TEXT
			skipButton.BackgroundColor3 = UI.Colors.Error
			task.delay(SKIP_CONFIRM_TIME, function()
				if skipArmedAt == armedAt then
					disarmSkip()
				end
			end)
			return
		end
		levelAction:FireServer("Tutorial", "Skip")
		UI.toast("Tuto passé : bonne partie !", "Info")
	end
	skipButton.Activated:Connect(pressSkip)
	if RunService:IsStudio() then
		-- Tests automatiques (un plugin ne peut pas cliquer) : l'attribut « TestSkipTap » compte comme un appui.
		pointerGui:GetAttributeChangedSignal("TestSkipTap"):Connect(pressSkip)
	end

	------------------------------------------------------------------
	-- Déroulement
	------------------------------------------------------------------
	local function update()
		local stage = state.tutorial
		if pointerGui:GetAttribute("Stage") ~= stage then
			pointerGui:SetAttribute("Stage", stage)
		end
		-- (un joueur revenu à l'étape 0, comme après « Reset » dans les tests Studio, refait ses deux gestes)
		if stage ~= guideStage then
			guideStage = stage
			guideDone = false
		end
		running = stage < Levels.TUTORIAL.DONE
		if not running then
			setPointed(nil)
			setHighlight(nil)
			skipButton.Visible = false
			return
		end
		-- Nouveau joueur qui arrive au camp : la fenêtre des niveaux s'ouvre toute seule, une seule fois.
		if stage < Levels.TUTORIAL.SHOP and not opened and not arenaFolder() and find("Levels", "Window") then
			opened = true
			LevelsUI.openCamp("Niveaux")
		end
		local target = resolve()
		setPointed(target)
		placePointer() -- (tout de suite : sinon elle resterait une image à son ancienne place)
		setHighlight(if target then target.gui else nil)
		-- « Passer » : tant que les deux premiers gestes ne sont pas faits, et pendant que la flèche montre quelque chose.
		skipButton.Visible = (stage < Levels.TUTORIAL.SHOP and not guideDone) or target ~= nil
	end

	player:GetAttributeChangedSignal("LevelsState"):Connect(function()
		readState()
		update()
	end)
	task.spawn(function()
		while player:GetAttribute("LevelsState") == nil do
			player:GetAttributeChangedSignal("LevelsState"):Wait()
		end
		task.wait(START_DELAY)
		readState()
		while true do
			update()
			task.wait(CHECK_INTERVAL)
		end
	end)
end

return TutorialUI

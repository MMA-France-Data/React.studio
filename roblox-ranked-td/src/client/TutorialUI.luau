-- Petit tuto des nouveaux joueurs (map principale seulement), montré une seule fois, avec un bouton « Passer ».
-- Refait le 01/10/2026 (retour du propriétaire : « le didacticiel fait fuir les gens avant même qu'ils commencent à
-- jouer », ils partent dès leur arrivée sur leur parcelle ; « plus clair, avec des flèches ») :
--   * il démarre tout de suite par une action (« pose une tour »), sans écran d'accueil à lire ;
--   * une grosse FLÈCHE qui rebondit, avec deux ou trois mots (« APPUIE ICI »), montre à chaque instant ce qu'il
--     faut toucher : le « + » d'un emplacement, la carte de l'Archer, la tour, « Améliorer », le bouton de l'autel,
--     « x1 », le X d'une fenêtre à fermer, le bouton de la forge. Cible hors de l'écran : la flèche se met au bord
--     de l'écran, du côté où regarder ;
--   * plus de marche : l'autel et la forge s'ouvrent par leurs boutons (à gauche sur ordinateur, les icônes 🏰 et
--     🔨 à droite sur téléphone), que la flèche montre ;
--   * des textes courts.
-- Classé fermé (Config.RANKED_OPEN = false, Shared/RankedGate.luau) : 4 étapes, chacune validée par ce que le
-- joueur fait vraiment :
--   1. poser une tour : au moins une tour sur ta parcelle (la flèche montre un « + », puis la carte de l'Archer) ;
--   2. l'améliorer : une tour au niveau 2 ou plus (la flèche montre la tour, puis « Améliorer ») ;
--   3. l'Autel des héros : un lancer x1 (résultat reçu, ou des lancers déjà achetés : attribut TowerSpinsBought ; la
--      flèche montre le bouton de l'autel, puis x1) ;
--   4. la Forge runique : l'ouvrir (la flèche montre son bouton), ou « Terminer ». Forge ouverte : un mot de la fin
--      (les runes coûtent cher au début).
-- Classé ouvert : 2 étapes de plus au début (6 en tout), à pied : la zone classée (entrer dans le cercle rouge au
-- centre de la map, ou « Suivant »), puis le retour sur sa parcelle. Elles reviennent toutes seules quand le classé
-- rouvre (demande du propriétaire, 01/10/2026 : « enlève la première partie du tuto qui montre ranked en attendant »).
-- Une fenêtre gêne (l'autel resté ouvert, le panneau des tours qui couvre l'écran d'un téléphone) : la flèche montre
-- son X (« FERME »).
-- Une étape déjà faite avant d'y arriver (ex. une tour déjà posée) est validée tout de suite. Le tuto ne bloque
-- rien : un petit panneau en haut de l'écran (en bas sur téléphone, voir TutorialUI.panelPlace), la flèche, un cadre
-- doré autour du bouton montré, et un rayon doré du personnage vers une cible du monde (créés seulement chez ce
-- joueur, retirés à la fin ; le rayon repart du nouveau personnage après une mort).
-- Le serveur garde « tuto fini » (PlayerData : tutorialDone, attribut TutorialDone du joueur) ; la fin et « Passer »
-- partent par le remote TutorialAction (Hub/Tutorial.luau). Un joueur qui part au milieu du tuto le recommence au
-- début en revenant : les étapes déjà faites passent toutes seules.
-- Studio : tes données y sont en mémoire, tu es donc un nouveau joueur à chaque Play et le tuto s'affiche à chaque
-- fois (Config.STUDIO_TUTORIAL = false pour ne plus le voir). Il recommence au début quand l'attribut
-- TutorialReplay du joueur change (StudioDebug « Tutorial », « Replay »). Tests automatiques
-- (ReplicatedStorage.__AutoPlayTest) : jamais tout seul, seulement quand le test le demande (TutorialReplay).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local IdleConfig = require(Shared.IdleConfig)
local NumberFormat = require(Shared.NumberFormat)
local PlotLayout = require(Shared.PlotLayout)
local RankedGate = require(Shared.RankedGate)
local Remotes = require(Shared.Remotes)
local CampMode = require(script.Parent.CampMode)
local SoundManager = require(script.Parent.SoundManager)
local UI = require(script.Parent.UI)

local TutorialUI = {}

-- Textes des étapes (français ; anglais : Shared/LangEN/Social.luau). Courts : la flèche montre le reste.
-- Les deux étapes à pied (classé ouvert seulement) :
TutorialUI.RANKED_STEP_OPEN = "Le cercle rouge au centre, c'est le classé : des matchs 1 contre 1 pour monter en rang. Suis le rayon doré !"
TutorialUI.PLOT_STEP_RETURN = "Voici ta parcelle : des vagues d'ennemis y arrivent sans fin. Retournes-y en suivant le rayon doré."
TutorialUI.PLACE_TEXT = "Des ennemis attaquent ta parcelle ! Appuie sur un « + » doré, puis sur la carte de l'Archer."
TutorialUI.UPGRADE_TEXT = "Ta tour tire toute seule. Appuie dessus, puis sur « Améliorer » : elle tapera plus fort."
-- L'autel et la forge par leurs boutons : à gauche sur ordinateur, les icônes de droite sur un téléphone tenu en
-- largeur (UI.leftColumnSlot), sous le compteur de pièces sur un téléphone tenu en hauteur.
TutorialUI.ALTAR_TEXT_PC = "Appuie sur « Autel des héros », à gauche, puis lance x1 : il donne de nouvelles tours."
TutorialUI.ALTAR_TEXT_PHONE = "Appuie sur 🏰, à droite, puis lance x1 : il donne de nouvelles tours."
TutorialUI.ALTAR_TEXT_PORTRAIT = "Appuie sur 🏰, puis lance x1 : il donne de nouvelles tours."
TutorialUI.FORGE_TEXT_PC = "Dernière étape : appuie sur « Forge runique », à gauche. Ses runes rendent tes tours bien plus fortes."
TutorialUI.FORGE_TEXT_PHONE = "Dernière étape : appuie sur 🔨, à droite. Ses runes rendent tes tours bien plus fortes."
TutorialUI.FORGE_TEXT_PORTRAIT = "Dernière étape : appuie sur 🔨. Ses runes rendent tes tours bien plus fortes."
-- Une fenêtre ouverte cache ce qu'il faut toucher (ex. l'autel resté ouvert à l'étape de la forge).
TutorialUI.CLOSE_TEXT = "Ferme d'abord cette fenêtre : appuie sur son X."
-- Les mots de la flèche (2 ou 3 mots, en majuscules).
TutorialUI.CAPTIONS = {
	Plus = "APPUIE ICI",
	Card = "CHOISIS L'ARCHER",
	Tower = "APPUIE SUR TA TOUR",
	Upgrade = "AMÉLIORE",
	Altar = "OUVRE L'AUTEL",
	Spin = "LANCE x1",
	Forge = "OUVRE LA FORGE",
	Close = "FERME",
	Ranked = "ARÈNE CLASSÉE",
	Plot = "TA PARCELLE",
}
-- Bouton « Passer » (sur téléphone, un 2e appui le confirme : voir skipButton).
TutorialUI.SKIP_TEXT = "Passer"
TutorialUI.SKIP_CONFIRM_TEXT = "Confirmer ?"

TutorialUI.PANEL_SIZE = Vector2.new(440, 104) -- 3 lignes de texte ; 440 px : ne cache pas le « X » des fenêtres des machines
local PANEL_SIZE = TutorialUI.PANEL_SIZE
-- Bord droit de la carte de rang (LobbyUI : 260 px à 16 px du bord) et une marge : sur un écran étroit (téléphone),
-- le panneau se décale vers la droite et rétrécit au lieu de la couvrir (comme le bouton « S'INSCRIRE »).
local LEFT_SIDE = 16 + 260 + 16
-- Haut du panneau : sous le compteur de pièces (PlotUI : 8 + 64 px ; à 60, du temps où le compteur faisait 46 px,
-- le panneau mordait sur le bas du compteur) ; plus bas quand le bouton « SON » passe sous le compteur (écran de
-- moins de ~1 140 px, SoundManager : 56 + 44 px).
local TOP_WIDE = 78
local TOP_NARROW = 106
local WIDE_SCREEN = 1140
-- Téléphone tenu en largeur : le panneau est en BAS de l'écran, contre la zone du bouton de saut de Roblox (à droite),
-- et ne va pas plus à gauche que cette part de la largeur (le pouce gauche, sur le joystick de Roblox dans le coin en
-- bas à gauche, reste dégagé ; le panneau ne prend aucun toucher, le joystick marche aussi dessous).
local PHONE_LEFT_LIMIT = 0.27
local PHONE_BOTTOM_MARGIN = 6
local CHECK_INTERVAL = 0.2 -- secondes entre deux vérifications de l'étape en cours
local DONE_FLASH = 0.8 -- secondes de « ✓ BRAVO ! » avant l'étape suivante
-- Temps de lecture, pour les étapes à pied (readFirst : arrivé avant d'avoir fini de lire, le texte reste sous
-- « ✓ BRAVO ! » jusqu'à ce temps-là depuis son apparition ; retour du propriétaire : « j'ai pas eu le temps de lire
-- le texte que j'étais déjà arrivé ») et pour le mot de la fin : 2 s + 1 s par 15 lettres, entre 3 et 8 s. Les autres
-- étapes s'enchaînent tout de suite : la flèche passe au bouton suivant.
local READ_MIN, READ_MAX = 3, 8
local READ_CHARS_PER_SECOND = 15
local START_DELAY = 1 -- après le chargement des données : le temps que la map et l'interface arrivent
local CHARACTER_WAIT = 10 -- puis au plus ce temps pour que le personnage apparaisse (le tuto démarre de toute façon)
local SKIP_CONFIRM_TIME = 3 -- téléphone : secondes pour toucher « Passer » une 2e fois (« Confirmer ? »)
-- Après un lancer de l'autel : le rouleau tourne ~3,7 s (MachineUI), puis le joueur lit ce qu'il a gagné. L'étape de
-- l'autel n'est validée qu'après ce temps.
local SPIN_REVEAL_TIME = 5
local CIRCLE_MARGIN = 6 -- studs autour du cercle classé qui comptent comme « dans la zone »
local GUIDE_COLOR = Color3.fromRGB(255, 205, 80) -- doré, comme l'anneau du cercle classé
local DONE_COLOR = Color3.fromRGB(125, 220, 125)

-- La flèche (px). Elle est dessinée avec des barres dorées (pas d'image ; le caractère « ▼ » était trop petit sur un
-- téléphone), dans un carré tourné vers sa cible.
TutorialUI.POINTER_ARROW = 56 -- côté du carré : la flèche fait toute sa hauteur
local POINTER_TIP = TutorialUI.POINTER_ARROW / 2 -- du milieu du carré à la pointe de la flèche
local POINTER_BAR = 13 -- épaisseur de ses barres
local POINTER_GAP = 5 -- entre la pointe et le bouton montré
local POINTER_BOUNCE = 10 -- elle recule et revient de tant
local POINTER_BOUNCE_SPEED = 7
local POINTER_CAPTION_HEIGHT = 26
local POINTER_CAPTION_WIDTH = 160 -- largeur prévue pour ses mots, quand ils se mettent à côté d'un bouton
local POINTER_EDGE = 24 -- un petit bouton à moins de tant du bord gauche ou droit de l'écran : la flèche se met à côté
local POINTER_SMALL = Vector2.new(200, 64) -- « petit bouton » : au plus cette taille
local POINTER_MARGIN = 40 -- cible du monde hors de l'écran : la pointe de la flèche est à tant du bord
-- Place qu'il faut à la flèche seule, puis à la flèche et à ses mots au bout.
local POINTER_NEED = 2 * POINTER_TIP + POINTER_BOUNCE + POINTER_GAP
local POINTER_NEED_WORDS = POINTER_NEED + POINTER_GAP + POINTER_CAPTION_HEIGHT

-- Place du panneau sur l'écran `screen` (fonction pure, vérifiée par les tests) : le x de son milieu, son haut (y) et
-- son échelle (le panneau fait PANEL_SIZE x échelle).
--   Ordinateur, tablette : en haut, centré sous le compteur de pièces ; sur un écran étroit, à droite de la carte de
--   rang et réduit.
--   Téléphone tenu en largeur : en BAS, entre le joystick de Roblox et son bouton de saut. En haut (comme avant le
--   01/10/2026), il cachait presque toute la vue : avec la caméra de départ, tout ce qui est à plus de ~5 studs
--   devant le personnage passait derrière lui, donc les boutons « + » des emplacements et la flèche du tuto (capture
--   phone_a_newplayer du test « téléphone »). En bas, il ne couvre que les pieds du personnage.
--   machineOpen = fenêtre de l'autel ou de la forge ouverte : en haut (les boutons de ces fenêtres sont en bas).
--   Téléphone tenu en hauteur : en haut, centré.
function TutorialUI.panelPlace(screen: Vector2, machineOpen: boolean): (number, number, number)
	if UI.touchLayout(screen) then
		if screen.X > screen.Y and not machineOpen then
			local right = screen.X - UI.PHONE_JUMP_ZONE - 8
			local scale = math.clamp((right - screen.X * PHONE_LEFT_LIMIT) / PANEL_SIZE.X, 0.55, 1)
			return right - PANEL_SIZE.X * scale / 2, screen.Y - PANEL_SIZE.Y * scale - PHONE_BOTTOM_MARGIN, scale
		end
		-- (entre le bouton « ★ BOUTIQUE », en haut à gauche, et les icônes du bord droit : UI.leftColumnSlot)
		return screen.X / 2, 8, math.clamp((screen.X - 2 * (UI.PHONE_SHOP_SIZE.X + 20)) / PANEL_SIZE.X, 0.55, 1)
	end
	local scale = math.clamp((screen.X - LEFT_SIDE - 16) / PANEL_SIZE.X, 0.55, 1)
	local top = if screen.X >= WIDE_SCREEN then TOP_WIDE else TOP_NARROW
	return math.max(screen.X / 2, LEFT_SIDE + PANEL_SIZE.X * scale / 2), top, scale
end

-- De quel côté d'un bouton se met la flèche (fonction pure, vérifiée par les tests). Le bouton est le rectangle
-- `position` (coin en haut à gauche), `size`, dans un écran de taille `screen`.
--   "top" = au-dessus, elle pointe vers le bas (le cas normal) ; "bottom" = dessous, quand la place manque au-dessus ;
--   "left" = à sa gauche, elle pointe vers la droite ; "right" = à sa droite, elle pointe vers la gauche.
--   Petit bouton collé au bord DROIT de l'écran (les icônes de l'autel et de la forge sur téléphone, le X du panneau
--   des tours) : à sa gauche. Collé au bord GAUCHE (les boutons de l'autel et de la forge sur ordinateur : au-dessus
--   ou en dessous, elle couvrirait le bouton voisin de la colonne) : à sa droite.
--   Grande cible (la carte de l'Archer) sans la place au-dessus pour la flèche et ses mots (téléphone : la carte
--   monte presque jusqu'en haut du panneau) : à côté d'elle, à droite de préférence, sans cacher la carte.
function TutorialUI.pointerSide(screen: Vector2, position: Vector2, size: Vector2): string
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
function TutorialUI.pointerAt(screen: Vector2, position: Vector2, size: Vector2): (Vector2, Vector2, string)
	local side = TutorialUI.pointerSide(screen, position, size)
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

-- Cible du monde hors de l'écran : la flèche se met au bord de l'écran, dans la direction `direction` (vecteur écran :
-- x vers la droite, y vers le bas) depuis le milieu, et pointe vers l'extérieur. Renvoie sa pointe et son sens.
-- Fonction pure.
function TutorialUI.pointerToward(screen: Vector2, direction: Vector2): (Vector2, Vector2)
	local d = if direction.Magnitude > 1e-3 then direction.Unit else Vector2.new(0, 1)
	local reachX = if math.abs(d.X) > 1e-3 then (screen.X / 2 - POINTER_MARGIN) / math.abs(d.X) else math.huge
	local reachY = if math.abs(d.Y) > 1e-3 then (screen.Y / 2 - POINTER_MARGIN) / math.abs(d.Y) else math.huge
	return screen / 2 + d * math.max(0, math.min(reachX, reachY)), d
end

function TutorialUI.start()
	local player = Players.LocalPlayer
	local tutorialAction = Remotes.get("TutorialAction")
	local plotsFolder = workspace:WaitForChild("Hub"):WaitForChild("Plots")
	-- Tests automatiques : le tuto ne démarre jamais tout seul (leurs captures ne changent pas). Sauf dans le test
	-- « téléphone » (objet __AutoTestNewPlayer de sa place de test, tools/studio-test/mkproj.cjs) : il regarde
	-- l'arrivée d'un vrai nouveau joueur, tuto compris.
	local isAutoTest = ReplicatedStorage:FindFirstChild("__AutoPlayTest") ~= nil
		and ReplicatedStorage:FindFirstChild("__AutoTestNewPlayer") == nil
	local autoStart = not isAutoTest and not (RunService:IsStudio() and Config.STUDIO_TUTORIAL == false)

	------------------------------------------------------------------
	-- Ce que le tuto regarde (tout vient des attributs et des objets publiés par le serveur)
	------------------------------------------------------------------
	local running = false
	local runId = 0 -- change à chaque départ ou arrêt : l'ancienne boucle de vérification s'arrête
	local steps = {} -- les étapes de ce tuto-ci, dans l'ordre (choisies dans STEPS à son départ, voir begin)
	local step = 1 -- numéro de l'étape en cours dans `steps`
	local startedAt = 0 -- os.clock() du départ du tuto
	local flashUntil = 0 -- « ✓ BRAVO ! » affiché jusqu'à cette heure, puis étape suivante (0 = rien)
	local stepShownAt = 0 -- os.clock() de l'apparition de l'étape en cours (temps de lecture)
	local afterShown = false -- le mot de la fin (afterText) est affiché sous « ✓ BRAVO ! »
	local lastSpinAt = -math.huge -- dernier lancer de l'Autel des héros (os.clock() de son résultat)
	local spinsAtStart = 0 -- lancers de l'autel déjà achetés au départ du tuto (attribut TowerSpinsBought)
	local lastForgeAt = -math.huge -- dernière ouverture de la Forge runique (os.clock())
	local spotTarget: BasePart? = nil -- l'emplacement libre montré par la flèche (gardé tant qu'il reste libre)

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
	-- Le personnage est sur le sol de ta parcelle, ou devant son entrée (l'autel et la forge).
	local function onMyPlot(): boolean
		local index, root = plotIndex(), rootPart()
		if not index or not root then
			return false
		end
		local localPosition = PlotLayout.toLocal(index, root.Position)
		return math.abs(localPosition.X) <= PlotLayout.WIDTH / 2 + 2
			and localPosition.Z >= -PlotLayout.LENGTH / 2 - 12
			and localPosition.Z <= PlotLayout.LENGTH / 2 + 2
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
	-- L'emplacement libre que la flèche montre : possédé (attribut Unlocked du socle, publié par le serveur) et sans
	-- tour. Le plus proche du personnage au moment du choix (le plus petit numéro sans personnage) ; il reste le même
	-- tant qu'il est libre, pour que la flèche ne saute pas d'un « + » à l'autre quand le joueur marche.
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
		local function free(pad: Instance): boolean
			local index = pad:GetAttribute("SpotIndex")
			return pad:IsA("BasePart") and pad:GetAttribute("Unlocked") == true and typeof(index) == "number" and not taken[index]
		end
		if spotTarget and spotTarget.Parent == spots and free(spotTarget) then
			return spotTarget
		end
		local root = rootPart()
		local best, bestScore = nil, math.huge
		for _, pad in spots:GetChildren() do
			if free(pad) then
				local score = if root then ((pad :: BasePart).Position - root.Position).Magnitude else pad:GetAttribute("SpotIndex")
				if score < bestScore then
					best, bestScore = pad, score
				end
			end
		end
		spotTarget = best
		return best
	end
	local function machinesGui(): Instance?
		return player.PlayerGui:FindFirstChild("Machines")
	end
	local function forgeOpen(): boolean
		local machines = machinesGui()
		return machines ~= nil and machines:GetAttribute("OpenMachine") == "Bonus" -- (MachineUI)
	end
	local function altarOpen(): boolean
		local machines = machinesGui()
		return machines ~= nil and machines:GetAttribute("OpenMachine") == "Tower" -- (MachineUI)
	end
	local function machineOpen(): boolean
		local machines = machinesGui()
		return machines ~= nil and machines:GetAttribute("OpenMachine") ~= nil
	end
	-- Bouton ou carte vraiment à l'écran (lui et tous ses parents visibles, écran allumé), sinon nil : la flèche le
	-- montre et le tuto l'entoure d'or (ex. la carte de l'Archer quand le panneau des tours est ouvert).
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
	-- Texte de l'autel ou de la forge selon l'appareil : leurs boutons sont à gauche sur ordinateur, à droite sur un
	-- téléphone tenu en largeur (rappel du propriétaire, 01/10/2026).
	local function bySide(pc: string, phone: string, portrait: string): string
		local screen = UI.screenSize(nil)
		if not UI.touchLayout(screen) then
			return pc
		end
		return if screen.Y > screen.X then portrait else phone
	end

	------------------------------------------------------------------
	-- Les étapes : title et text (panneau ; text peut être une fonction, relue pendant l'étape), button (« Suivant » /
	-- « Terminer », sinon aucun : l'action du joueur valide l'étape), done() = vrai quand l'étape est faite,
	-- point() = ce que la flèche montre en ce moment, nil (rien à montrer) ou false (attendre : aucune flèche) :
	--   { gui = bouton ou carte à l'écran, caption = ses mots } : flèche à côté de lui, et cadre doré autour ;
	--   { world = point du monde, caption = ses mots, anchor = bout du rayon doré (par défaut world), radius = px à
	--     laisser libres autour du point } : flèche au-dessus du point, ou au bord de l'écran s'il n'est pas à l'écran.
	-- rankedOnly : étape montrée seulement quand le classé est ouvert (voir begin). readFirst : étape à pied, son
	-- texte reste le temps de le lire. enter() : appelée quand l'étape apparaît.
	------------------------------------------------------------------
	local CAPTIONS = TutorialUI.CAPTIONS
	local STEPS = {
		{
			title = "LA ZONE CLASSÉE",
			rankedOnly = true, -- classé fermé : le tuto ne montre pas le classé
			readFirst = true,
			text = TutorialUI.RANKED_STEP_OPEN,
			button = "Suivant",
			point = function()
				local circle = PlotLayout.RANKED_CIRCLE_POSITION
				return { world = circle + Vector3.new(0, 6, 0), anchor = circle + Vector3.new(0, 0.5, 0), caption = CAPTIONS.Ranked }
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
			rankedOnly = true, -- (le retour du cercle classé ; classé fermé, le joueur apparaît déjà sur sa parcelle)
			readFirst = true,
			text = TutorialUI.PLOT_STEP_RETURN,
			point = function()
				local index = plotIndex()
				if not index then
					return nil
				end
				return {
					world = PlotLayout.toWorld(index, Vector3.new(0.5, 7, -22)),
					anchor = PlotLayout.toWorld(index, Vector3.new(0.5, 0.5, -22)),
					caption = CAPTIONS.Plot,
				}
			end,
			done = onMyPlot,
		},
		{
			title = "POSE UNE TOUR",
			text = TutorialUI.PLACE_TEXT,
			point = function()
				-- Panneau des tours ouvert sur un emplacement libre : la carte de l'Archer (la seule tour d'un nouveau
				-- joueur ; retour du propriétaire : avec « une tour », un débutant prenait n'importe laquelle).
				local card = shownChild("Plot", "Card_MachineGun")
				if card then
					return { gui = card, caption = CAPTIONS.Card }
				end
				local pad = freeSpot()
				if not pad then
					return nil
				end
				-- Le bouton « + » de cet emplacement (PlotUI : BillboardGui « FreeSpot<n> »), sa taille à l'écran.
				local plus = player.PlayerGui:FindFirstChild("FreeSpot" .. tostring(pad:GetAttribute("SpotIndex")))
				local radius = if plus and plus:IsA("BillboardGui") and plus.Enabled then plus.Size.X.Offset / 2 else 0
				return {
					world = pad.Position + Vector3.new(0, PlotLayout.SPOT_PLUS_HEIGHT, 0),
					anchor = pad.Position + Vector3.new(0, PlotLayout.SPOT_PAD_HEIGHT / 2 + 0.3, 0),
					radius = radius,
					caption = CAPTIONS.Plus,
				}
			end,
			done = function()
				return #myTowers() > 0
			end,
		},
		{
			title = "AMÉLIORE-LA",
			text = TutorialUI.UPGRADE_TEXT,
			point = function()
				-- Fiche d'une tour ouverte : son bouton « Améliorer ». Sinon la tour elle-même.
				local button = shownChild("Plot", "UpgradeButton")
				if button then
					return { gui = button, caption = CAPTIONS.Upgrade }
				end
				local tower, index = myTowers()[1], plotIndex()
				local spot = tower and PlotLayout.SPOTS[tower:GetAttribute("SpotIndex")]
				if not (tower and spot and index) then
					return nil
				end
				local base = PlotLayout.toWorld(index, spot + Vector3.new(0, 0.5, 0))
				local top = base.Y + 6
				if tower:IsA("Model") then
					local cframe, size = tower:GetBoundingBox()
					top = cframe.Position.Y + size.Y / 2
				end
				return { world = Vector3.new(base.X, top + 0.5, base.Z), anchor = base, caption = CAPTIONS.Tower }
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
			-- Par son bouton, sans marcher (choix du propriétaire, 01/10/2026 ; avant, le joueur y allait à pied).
			text = function()
				return bySide(TutorialUI.ALTAR_TEXT_PC, TutorialUI.ALTAR_TEXT_PHONE, TutorialUI.ALTAR_TEXT_PORTRAIT)
			end,
			enter = UI.showShortcuts, -- (téléphone : les icônes reviennent si le joueur les avait masquées avec « ▲ »)
			point = function()
				if lastSpinAt >= startedAt then
					return false -- lancer fait : le rouleau tourne, rien à toucher (ni à fermer) pour l'instant
				end
				if altarOpen() then
					local spin = shownChild("Machines", "Spin_1")
					return if spin then { gui = spin, caption = CAPTIONS.Spin } else nil
				end
				local shortcut = shownChild("Machines", "TowerShortcut")
				return if shortcut then { gui = shortcut, caption = CAPTIONS.Altar } else nil
			end,
			-- Faite : des lancers déjà achetés avant ce tuto, ou un lancer fait pendant le tuto ET le temps de voir
			-- tourner le rouleau et de lire ce qu'on a gagné (pendant qu'il tourne, la fenêtre ne se ferme pas :
			-- la flèche ne doit pas encore montrer son X).
			done = function()
				if lastSpinAt >= startedAt then
					return os.clock() - lastSpinAt >= SPIN_REVEAL_TIME
				end
				return spinsAtStart > 0
			end,
		},
		{
			title = "LA FORGE RUNIQUE",
			text = function()
				return bySide(TutorialUI.FORGE_TEXT_PC, TutorialUI.FORGE_TEXT_PHONE, TutorialUI.FORGE_TEXT_PORTRAIT)
			end,
			button = "Terminer",
			enter = UI.showShortcuts,
			point = function()
				local shortcut = shownChild("Machines", "BonusShortcut")
				return if shortcut then { gui = shortcut, caption = CAPTIONS.Forge } else nil
			end,
			-- Le mot de la fin, une fois la forge ouverte (prix du prochain lancer en pièces : 100K pour un nouveau
			-- joueur, voir IdleConfig.forgeCoinPrice).
			afterText = function()
				local price = IdleConfig.forgeCoinPrice(IdleConfig.cleanSpinsBought(player:GetAttribute("ForgeSpinsBought")))
				return `Les runes coûtent cher au début ({NumberFormat.short(price)} pièces) : reviens à la forge plus tard. À toi de jouer !`
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
		Text = TutorialUI.SKIP_TEXT,
		MaxTextSize = 16,
		Parent = panel,
	})
	-- « Passer » sur téléphone : il faut le toucher DEUX fois (« Passer », puis « Confirmer ? » dans les
	-- SKIP_CONFIRM_TIME secondes). Le panneau y est en bas de l'écran, à côté du bouton de saut et sous le pouce qui
	-- tourne la caméra : un appui par erreur ne doit pas faire perdre le tuto. Ordinateur : un seul clic.
	local skipArmedAt = -math.huge -- os.clock() du 1er appui sur « Passer » (téléphone)
	local function disarmSkip()
		skipArmedAt = -math.huge
		skipButton.Text = TutorialUI.SKIP_TEXT
		skipButton.BackgroundColor3 = UI.Colors.PanelLight
	end

	-- Le panneau des tours (PlotUI) quand il est ouvert, sinon nil.
	local function openTowerPanel(): GuiObject?
		local plotGui = player.PlayerGui:FindFirstChild("Plot")
		local towerPanel = plotGui and plotGui:FindFirstChild("TowerPanel")
		if towerPanel and towerPanel:IsA("GuiObject") and towerPanel.Visible and plotGui:IsA("ScreenGui") and plotGui.Enabled then
			return towerPanel
		end
		return nil
	end

	-- Place du panneau (TutorialUI.panelPlace) : en haut sur ordinateur, en bas sur téléphone ; en haut, il descend sous
	-- le bouton « ⚔ S'INSCRIRE AU CLASSÉ » (LobbyUI, dans le cercle) quand il le cacherait.
	-- Téléphone : le panneau des tours (PlotUI) prend presque tout l'écran quand il est ouvert. Le tuto se cache tant
	-- qu'ils se touchent (il revient quand on le ferme) : les cartes des tours et « Améliorer » restent visibles, et
	-- on ne touche jamais « Passer » par erreur à la place d'une carte. La flèche, elle, reste au-dessus.
	-- Téléphone encore : la fenêtre de l'autel ou de la forge prend aussi presque tout l'écran. Le panneau se cache
	-- tant qu'elle est ouverte (il couvrait son titre et ses chances ; la flèche et ses mots suffisent : « LANCE x1 »,
	-- « FERME »), sauf pour le mot de la fin, affiché en haut.
	local function layout()
		local screen = gui.AbsoluteSize
		if screen.X <= 0 or screen.Y <= 0 then
			return
		end
		local centerX, top, scale = TutorialUI.panelPlace(screen, machineOpen())
		panelScale.Scale = scale
		local width, height = PANEL_SIZE.X * scale, PANEL_SIZE.Y * scale
		if top < screen.Y / 2 then
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
		end
		panel.Position = UDim2.fromOffset(centerX, top)
		local towerPanel = openTowerPanel()
		local covered = false
		if towerPanel then
			-- (les deux rectangles se touchent-ils ?)
			local towerPosition = towerPanel.AbsolutePosition - gui.AbsolutePosition
			local towerSize = towerPanel.AbsoluteSize
			local left = centerX - width / 2
			covered = towerPosition.X < left + width
				and towerPosition.X + towerSize.X > left
				and towerPosition.Y < top + height
				and towerPosition.Y + towerSize.Y > top
		end
		local behindMachine = UI.touchLayout(screen) and machineOpen() and not afterShown
		panel.Visible = running and not covered and not behindMachine
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)

	------------------------------------------------------------------
	-- La flèche : sur son propre écran, au-dessus de toutes les fenêtres (panneau des tours, autel, forge) et sous les
	-- messages. Le caractère « ▼ » tourné vers la cible, et ses mots derrière lui. Elle ne prend aucun clic.
	-- `pointed` = ce qu'elle montre (voir STEPS : point), choisi à chaque vérification de l'étape ; sa place est
	-- recalculée à chaque image (la caméra et les fenêtres bougent). Pour les tests : attributs « Target » (nom du
	-- bouton montré, « World » pour un point du monde, vide sans flèche) et « Caption » (ses mots, en français).
	------------------------------------------------------------------
	local pointerGui = UI.screen("TutorialPointer", 45)
	pointerGui:SetAttribute("Target", "")
	pointerGui:SetAttribute("Caption", "")
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
				BackgroundColor3 = if outline > 0 then Color3.fromRGB(24, 18, 6) else GUIDE_COLOR,
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
	local captionStroke = UI.stroke(GUIDE_COLOR, 2)
	captionStroke.Transparency = 0.1
	local caption = UI.new("TextLabel", {
		Name = "Caption",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(120, POINTER_CAPTION_HEIGHT),
		BackgroundColor3 = UI.Colors.Background,
		BackgroundTransparency = 0.05,
		Font = Enum.Font.GothamBlack,
		Text = "",
		TextSize = 15,
		TextColor3 = GUIDE_COLOR,
		Visible = false,
		Parent = pointerGui,
	}, { UI.corner(9), captionStroke })
	-- (largeur selon le texte affiché, qui peut être sa traduction anglaise : AutoTranslate)
	caption:GetPropertyChangedSignal("TextBounds"):Connect(function()
		caption.Size = UDim2.fromOffset(math.ceil(caption.TextBounds.X) + 24, POINTER_CAPTION_HEIGHT)
	end)

	local pointed = nil -- { gui | world, caption, anchor, radius } ou nil
	local function setPointed(target)
		pointed = target
		local name, words = "", ""
		if target then
			name = if target.gui then target.gui.Name else "World"
			words = target.caption or ""
		end
		if pointerGui:GetAttribute("Target") ~= name then
			pointerGui:SetAttribute("Target", name)
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
		local tip, direction
		if target.gui then
			local object = target.gui :: GuiObject
			if not object:IsDescendantOf(player.PlayerGui) then
				arrow.Visible = false
				caption.Visible = false
				return
			end
			tip, direction = TutorialUI.pointerAt(screen, object.AbsolutePosition - origin, object.AbsoluteSize)
		else
			local camera = workspace.CurrentCamera
			if not camera then
				return
			end
			-- (WorldToScreenPoint tient compte de la barre du haut de Roblox, comme la place des boutons)
			local point = camera:WorldToScreenPoint(target.world)
			local at = Vector2.new(point.X, point.Y) - origin
			local radius = target.radius or 0
			local inside = point.Z > 0
				and at.X >= POINTER_MARGIN and at.X <= screen.X - POINTER_MARGIN
				and at.Y >= POINTER_MARGIN and at.Y <= screen.Y - POINTER_MARGIN
			if inside and (at.Y - radius >= POINTER_NEED or at.Y + radius + POINTER_NEED_WORDS > screen.Y) then
				tip, direction = at - Vector2.new(0, radius + POINTER_GAP), SIDE_DIRECTIONS.top
			elseif inside then
				tip, direction = at + Vector2.new(0, radius + POINTER_GAP), SIDE_DIRECTIONS.bottom
			else
				-- Hors de l'écran (ou derrière la caméra) : au bord de l'écran, du côté où elle est.
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
		end
		caption.Position = UDim2.fromOffset(
			math.clamp(captionAt.X, words.X / 2 + 4, math.max(words.X / 2 + 4, screen.X - words.X / 2 - 4)),
			math.min(captionAt.Y, screen.Y - words.Y / 2 - 4)
		)
		caption.Visible = (target.caption or "") ~= ""
	end
	RunService.RenderStepped:Connect(placePointer)

	------------------------------------------------------------------
	-- Rayon doré du personnage vers une cible du monde (un « + », la tour, le cercle classé...)
	------------------------------------------------------------------
	local guide = nil -- { anchor, beam } : objets de ce joueur seulement
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
		anchor.Parent = workspace
		guide = { anchor = anchor, beam = beam }
	end

	-- Suit la cible montrée (un point du monde seulement) et le personnage (nouveau personnage après une mort : le
	-- rayon repart de lui).
	local function updateGuide(target)
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
		local position = if target and target.world then target.anchor or target.world else nil
		guide.beam.Attachment0 = rootAttachment
		guide.beam.Enabled = rootAttachment ~= nil and position ~= nil
		if position and (guide.anchor.Position - position).Magnitude > 0.05 then
			guide.anchor.CFrame = CFrame.new(position)
		end
	end

	------------------------------------------------------------------
	-- Cadre doré qui clignote autour du bouton ou de la carte que la flèche montre.
	------------------------------------------------------------------
	local highlights: { [GuiObject]: Frame } = {} -- [bouton ou carte entouré] = son cadre
	-- target : un bouton, ou nil (plus aucun cadre).
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

	------------------------------------------------------------------
	-- Déroulement
	------------------------------------------------------------------
	-- Boutons du panneau : « Suivant » / « Terminer » seulement si l'étape en a un et pas pendant « ✓ BRAVO ! ».
	-- Aucun des deux (ni « Passer ») tant que l'autel ou la forge est ouvert : réduite (petit écran), leur fenêtre
	-- passe sous le panneau et son X tombait sur « Terminer » (retour du propriétaire : le tuto se fermait quand il
	-- fermait l'autel).
	local function refreshButtons()
		local free = not machineOpen()
		local def = steps[step]
		nextButton.Visible = free and flashUntil == 0 and def ~= nil and def.button ~= nil
		skipButton.Visible = free
	end

	-- Ce que la flèche doit montrer maintenant pour cette étape, et le texte du panneau.
	-- Une fenêtre gêne : celle de l'autel ou de la forge alors que la cible n'est pas dedans (ex. l'autel resté
	-- ouvert à l'étape de la forge), ou le panneau des tours qui couvre l'écran d'un téléphone alors que la cible
	-- est ailleurs (ex. la fiche de la tour restée ouverte à l'étape de l'autel) : la flèche montre son X.
	local function resolve(def)
		local target = def.point()
		local text = if typeof(def.text) == "function" then def.text() else def.text
		if target == false then
			return nil, text -- (l'étape demande d'attendre : aucune flèche)
		end
		local machines = machinesGui()
		local overlay = machines and machines:FindFirstChild("Overlay")
		if machineOpen() and not (target and target.gui and overlay and target.gui:IsDescendantOf(overlay)) then
			local close = shownChild("Machines", "CloseButton")
			return if close then { gui = close, caption = CAPTIONS.Close } else nil, TutorialUI.CLOSE_TEXT
		end
		local towerPanel = openTowerPanel()
		if towerPanel and UI.touchLayout(gui.AbsoluteSize) and not (target and target.gui and target.gui:IsDescendantOf(towerPanel)) then
			local close = shownChild("Plot", "CloseButton")
			return if close then { gui = close, caption = CAPTIONS.Close } else nil, TutorialUI.CLOSE_TEXT
		end
		return target, text
	end

	local function showStep(index: number)
		step = index
		flashUntil = 0
		afterShown = false
		stepShownAt = os.clock()
		spotTarget = nil
		local def = steps[index]
		title.Text = `TUTO {index}/{#steps} • {def.title}`
		title.TextColor3 = UI.Colors.Gold
		setBody(if typeof(def.text) == "function" then def.text() else def.text)
		nextButton.Text = def.button or ""
		if def.enter then
			def.enter()
		end
		refreshButtons()
	end

	-- Temps pour lire le texte affiché (READ_MIN à READ_MAX secondes).
	local function readTime(): number
		local letters = utf8.len(bodyText) or #bodyText
		return math.clamp(2 + letters / READ_CHARS_PER_SECOND, READ_MIN, READ_MAX)
	end

	-- Arrête le tuto chez ce joueur : panneau caché, flèche, cadre et rayon retirés (rien n'est envoyé au serveur).
	local function stop()
		running = false
		runId += 1
		flashUntil = 0
		afterShown = false
		panel.Visible = false
		disarmSkip()
		destroyGuide()
		setHighlight(nil)
		setPointed(nil)
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

	-- Étape faite : « ✓ BRAVO ! », la flèche disparaît, puis l'étape suivante (la dernière termine le tuto).
	--   Le temps du « BRAVO » : court (DONE_FLASH), la flèche passe tout de suite au bouton suivant. Étape à pied
	--   (readFirst) faite par l'action du joueur : au moins le temps de lire son texte depuis son apparition.
	--   Étape avec afterText (la forge : le mot de la fin) faite par l'action du joueur : ce texte remplace le sien
	--   sous « ✓ BRAVO ! », le temps de le lire.
	local function validate(byButton: boolean)
		if byButton and step >= #steps then
			finish("Done")
			return
		end
		local def = steps[step]
		local hold = DONE_FLASH
		if not byButton and def.readFirst then
			hold = math.max(DONE_FLASH, stepShownAt + readTime() - os.clock())
		end
		if not byButton and def.afterText then
			setBody(if typeof(def.afterText) == "function" then def.afterText() else def.afterText)
			hold = readTime()
			afterShown = true
		end
		flashUntil = os.clock() + hold
		title.Text = "✓ BRAVO !"
		title.TextColor3 = DONE_COLOR
		refreshButtons()
		layout() -- (téléphone : le mot de la fin s'affiche même devant la fenêtre de la forge)
	end

	local function update()
		layout()
		if flashUntil > 0 then
			if os.clock() >= flashUntil then
				if step >= #steps then
					finish("Done")
				else
					showStep(step + 1)
				end
			end
		elseif steps[step].done() then
			validate(false)
		end
		if running then
			refreshButtons()
			local target = nil
			if flashUntil == 0 then
				-- La cible et le texte du moment (ils dépendent de ce qui est ouvert).
				local text
				target, text = resolve(steps[step])
				if bodyText ~= text then
					setBody(text)
				end
			end
			setPointed(target)
			setHighlight(if target then target.gui else nil)
			updateGuide(target)
		end
	end

	local function begin()
		stop()
		-- Les étapes de ce tuto-ci : sans les deux étapes à pied du classé tant qu'il est fermé (choisies au départ :
		-- le classé ne s'ouvre ni ne se ferme jamais pendant une partie publiée).
		table.clear(steps)
		for _, def in STEPS do
			if not def.rankedOnly or RankedGate.isOpen() then
				table.insert(steps, def)
			end
		end
		running = true
		startedAt = os.clock()
		spinsAtStart = tonumber(player:GetAttribute("TowerSpinsBought")) or 0
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
	local function pressSkip()
		if not running then
			return
		end
		-- Téléphone : 1er appui = « Confirmer ? » (rouge) pendant SKIP_CONFIRM_TIME secondes ; 2e appui = on passe.
		if UI.touchLayout(gui.AbsoluteSize) and os.clock() - skipArmedAt > SKIP_CONFIRM_TIME then
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
		finish("Skip")
	end
	skipButton.Activated:Connect(pressSkip)
	-- Tests automatiques dans Studio (un plugin ne peut pas cliquer) : l'attribut « TestSkipTap » de cet écran, quand il
	-- change, compte comme un appui sur « Passer ». Jamais dans le jeu publié.
	if RunService:IsStudio() then
		gui:GetAttributeChangedSignal("TestSkipTap"):Connect(pressSkip)
	end

	------------------------------------------------------------------
	-- Ce qui valide les étapes de l'autel et de la forge, et le départ du tuto
	------------------------------------------------------------------
	Remotes.get("MachineResult").OnClientEvent:Connect(function(result)
		if typeof(result) == "table" and result.machine == "Tower" then
			lastSpinAt = os.clock()
		end
	end)
	-- (au cas où le compteur de lancers arriverait sans le résultat : un lancer de plus = un lancer fait)
	player:GetAttributeChangedSignal("TowerSpinsBought"):Connect(function()
		if running and lastSpinAt < startedAt and (tonumber(player:GetAttribute("TowerSpinsBought")) or 0) > spinsAtStart then
			lastSpinAt = os.clock()
		end
	end)
	-- Forge ouverte par son invite (serveur) ou par son bouton (attribut OpenMachine de MachineUI).
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
					update() -- tout de suite (flèche, boutons, place du panneau), pas au prochain tour
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
	-- Studio : « Replay » (Hub/Tutorial.luau) -> le tuto recommence au début, même pendant les tests automatiques.
	player:GetAttributeChangedSignal("TutorialReplay"):Connect(begin)

	-- Nouveau joueur : le tuto démarre tout seul une fois ses données chargées (TutorialDone = faux) et son personnage
	-- apparu (la flèche et le rayon partent de lui ; sur un appareil lent, il arrive parfois après les données).
	task.spawn(function()
		while not player:GetAttribute("DataLoaded") do
			player:GetAttributeChangedSignal("DataLoaded"):Wait()
		end
		task.wait(START_DELAY)
		if not autoStart or player:GetAttribute("TutorialDone") ~= false then
			return
		end
		-- Parcelle devenue camp d'entraînement (nouvelle formule, CampMode.luau) : ce tuto est celui du jeu infini
		-- (poser une tour sur un emplacement, l'autel, la forge), il n'a rien à montrer là.
		if CampMode.active() then
			return
		end
		local deadline = os.clock() + CHARACTER_WAIT
		while not rootPart() and os.clock() < deadline do
			task.wait(CHECK_INTERVAL)
		end
		if not running and player:GetAttribute("TutorialDone") == false then
			begin()
		end
	end)
end

return TutorialUI

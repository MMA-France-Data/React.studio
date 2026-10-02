-- Petits utilitaires pour construire l'interface en code.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Lang = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Lang"))

local UI = {}

UI.Colors = {
	Background = Color3.fromRGB(18, 20, 31),
	Panel = Color3.fromRGB(35, 38, 53),
	PanelLight = Color3.fromRGB(57, 62, 80),
	Text = Color3.fromRGB(255, 255, 255),
	Muted = Color3.fromRGB(220, 229, 244),
	Accent = Color3.fromRGB(0, 176, 255),
	Success = Color3.fromRGB(91, 224, 26),
	Warning = Color3.fromRGB(255, 169, 30),
	Error = Color3.fromRGB(242, 47, 58),
	Gold = Color3.fromRGB(255, 217, 61),
	DangerText = Color3.fromRGB(255, 132, 145),
	PositiveText = Color3.fromRGB(160, 255, 103),
	Ink = Color3.fromRGB(10, 12, 21),
	Purple = Color3.fromRGB(163, 64, 255),
}

UI.TitleFont = Enum.Font.FredokaOne
UI.BodyFont = Enum.Font.BuilderSansBold

-- Colonne de boutons à gauche de la map principale (sous le panneau de rang de 130 px).
UI.LEFT_COLUMN_TOP = 162
UI.LEFT_COLUMN_STEP = 54
-- Ses boutons (Autel, Forge, Renaissance, Boutique, Défis : 180 x 46 px à 16 px du bord), placés par
-- UI.placeInLeftColumn. Les boutons « (Studio) » viennent après, à leur place fixe (jamais sur un téléphone).
UI.LEFT_COLUMN_X = 16
UI.LEFT_BUTTON_SIZE = Vector2.new(180, 46)
UI.LEFT_COLUMN_COUNT = 5
local plotPanel: GuiObject? = nil
local navigationFits = {}
-- Téléphone : compteur de pièces, « ▲ », SON et Vitesse x2 en haut à droite (UI.phoneTopRight), PETITS (demande du
-- propriétaire, 01/10/2026 : « l'icône son est trop grande et gêne, et même mes pièces ») : le compteur n'affiche que
-- « 💰 22.6M » (120 x 34 px, 160 x 64 avant), SON une icône et Vitesse « x1 » / « x2 » (40 x 34 px, 68 x 44 avant).
UI.PHONE_WALLET_SIZE = Vector2.new(120, 34)
UI.PHONE_BUTTON_SIZE = Vector2.new(40, 34)
local PHONE_MARGIN = 12
local PHONE_GAP = 6
-- Largeur de ce groupe en paysage, du bord droit de l'écran au bord gauche du bouton Vitesse x2 (270 px).
UI.PHONE_TOP_RIGHT_WIDTH = PHONE_MARGIN + UI.PHONE_WALLET_SIZE.X + 3 * (PHONE_GAP + UI.PHONE_BUTTON_SIZE.X)

-- Fenêtres sur petits écrans (téléphones) : chaque fenêtre garde sa taille d'ordinateur (design) et un UIScale la
-- réduit juste assez pour qu'elle tienne entière à l'écran, à WINDOW_MARGIN px des bords. L'écran, c'est la zone
-- de son ScreenGui (UI.screen : IgnoreGuiInset = false), donc déjà SOUS la barre du haut de Roblox et hors des
-- encoches des téléphones. Jamais agrandie (échelle 1 au plus : rien ne change sur un écran d'ordinateur), jamais
-- sous MIN_WINDOW_SCALE. Les MaxTextSize ne changent pas : tout est réduit pareil, textes compris.
UI.WINDOW_MARGIN = 8
UI.MIN_WINDOW_SCALE = 0.4

-- UI.new("Frame", { Size = ..., Parent = ... }, { enfants })
function UI.new(className: string, props: { [string]: any }?, children: { Instance }?)
	local instance = Instance.new(className)
	if instance:IsA("GuiObject") then instance.BorderSizePixel = 0 end
	local parent = nil
	for key, value in (props or {}) :: { [string]: any } do
		if key == "Parent" then
			parent = value
		else
			(instance :: any)[key] = value
		end
	end
	for _, child in (children or {}) :: { Instance } do
		child.Parent = instance
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function UI.corner(radius: number?)
	return UI.new("UICorner", { CornerRadius = UDim.new(0, radius or 10) })
end

function UI.padding(pixels: number)
	local p = UDim.new(0, pixels)
	return UI.new("UIPadding", { PaddingTop = p, PaddingBottom = p, PaddingLeft = p, PaddingRight = p })
end

function UI.stroke(color: Color3?, thickness: number?)
	return UI.new("UIStroke", {
		Color = color or UI.Colors.Ink,
		Thickness = thickness or 3,
		Transparency = 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function UI.screen(name: string, displayOrder: number?)
	return UI.new("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = displayOrder or 0,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
end

-- Échelle d'une fenêtre de taille `design` (px) dont le CENTRE est à `center` de l'écran (en fractions ; par
-- défaut 0,5 ; 0,5 = au milieu), pour qu'elle tienne dans un écran de taille `screen` (px), à WINDOW_MARGIN px des
-- bords. Fonction pure : les tests l'appellent aussi avec de fausses tailles de téléphone.
function UI.windowScale(screen: Vector2, design: Vector2, center: Vector2?): number
	local c = center or Vector2.new(0.5, 0.5)
	-- Place libre de chaque côté du centre (le côté le plus court compte) : la fenêtre en prend la moitié.
	local halfWidth = math.min(c.X, 1 - c.X) * screen.X - UI.WINDOW_MARGIN
	local halfHeight = math.min(c.Y, 1 - c.Y) * screen.Y - UI.WINDOW_MARGIN
	local scale = math.min(1, 2 * halfWidth / design.X, 2 * halfHeight / design.Y)
	return math.clamp(scale, UI.MIN_WINDOW_SCALE, 1)
end

-- Taille (px) de l'écran d'un ScreenGui fait par UI.screen : sa zone, sous la barre du haut de Roblox. Tout juste
-- créé (pas encore mesuré) : l'écran entier moins cette barre.
function UI.screenSize(gui: ScreenGui?): Vector2
	local size = if gui then gui.AbsoluteSize else Vector2.zero
	if size.X > 0 and size.Y > 0 then
		return size
	end
	local camera = workspace.CurrentCamera
	local topLeft, bottomRight = GuiService:GetGuiInset()
	return if camera then camera.ViewportSize - topLeft - bottomRight else Vector2.zero
end

-- Réduit une fenêtre pour qu'elle tienne dans l'écran de son ScreenGui (UI.windowScale), et recommence quand la
-- taille de l'écran change (téléphone tourné, fenêtre redimensionnée). La fenêtre : AnchorPoint 0,5 ; 0,5 et
-- Position en fractions de l'écran (ex. UDim2.fromScale(0.5, 0.5)) : UIScale la réduit autour de son centre.
-- design = sa taille sur un écran d'ordinateur. Elle doit déjà être dans son ScreenGui. Renvoie son UIScale
-- (nommé « FitScale »).
function UI.fitWindow(window: GuiObject, design: Vector2): UIScale
	local scale = UI.new("UIScale", { Name = "FitScale", Parent = window }) :: UIScale
	local gui = window:FindFirstAncestorWhichIsA("ScreenGui")
	local function fit()
		local screen = UI.screenSize(gui)
		if screen.X > 0 and screen.Y > 0 then
			scale.Scale = UI.windowScale(screen, design, Vector2.new(window.Position.X.Scale, window.Position.Y.Scale))
		end
	end
	fit()
	if gui then
		gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	end
	return scale
end

-- Place du bouton n° `index` (0 = le premier) des raccourcis de la map principale (Autel, Forge, Renaissance,
-- Boutique, Défis), pour un écran de taille `screen` (px). Fonction pure (les tests l'appellent avec de fausses
-- tailles).
-- Ordinateur et tablette : colonne à gauche, sous la carte de rang. Écran assez haut pour les 5 boutons : taille
-- normale ; sinon (petite fenêtre) toute la colonne est réduite pour tenir.
-- Téléphone (UI.touchLayout) : plus de colonne à gauche (elle tombait sur le joystick, et réduite elle était trop
-- petite pour le doigt). Disposition choisie par le propriétaire le 01/10/2026, d'après deux captures d'autres
-- jeux Roblox sur son téléphone :
--   index 0 et 1 (Autel, Forge) : deux petites ICÔNES carrées contre le bord DROIT, l'une sous l'autre (🏰, 🔨 :
--     voir UI.placeInLeftColumn) ;
--   index 2 (Renaissance) : un bouton avec son nom, contre le bord droit, sous les deux icônes ;
--   index 3 (Boutique) : son bouton « ★ BOUTIQUE », en haut à gauche, sous les boutons de Roblox ;
--   index 4 (Défis) : une icône sous la Renaissance, ou à gauche de la Forge quand l'écran est trop bas (rien ne
--     descend sur le bouton de saut de Roblox : PHONE_JUMP_ZONE).
--   Portrait : 3 par rangée sous le compteur de pièces.
-- Renvoie le coin en haut à gauche, l'échelle (UIScale) et la taille du bouton.
UI.PHONE_ICON_SIZE = 38
UI.PHONE_REBIRTH_SIZE = Vector2.new(104, 36)
UI.PHONE_SHOP_SIZE = Vector2.new(104, 34)
UI.PHONE_JUMP_ZONE = 96 -- bas de l'écran laissé au bouton de saut (son haut est à ~90 px du bas sur un téléphone)
function UI.leftColumnSlot(screen: Vector2, index: number): (Vector2, number, Vector2)
	if UI.touchLayout(screen) then
		if screen.Y > screen.X then
			local width = math.min(180, math.floor((screen.X - 24 - 2 * 6) / 3))
			return Vector2.new(12 + (index % 3) * (width + 6), 90 + math.floor(index / 3) * 50), 1, Vector2.new(width, 44)
		end
		local size, gap, top = UI.PHONE_ICON_SIZE, 6, 8
		local right = screen.X - 10
		local icon = Vector2.new(size, size)
		if index == 3 then
			return Vector2.new(12, top), 1, UI.PHONE_SHOP_SIZE
		elseif index == 2 then
			return Vector2.new(right - UI.PHONE_REBIRTH_SIZE.X, top + 2 * (size + gap)), 1, UI.PHONE_REBIRTH_SIZE
		elseif index >= 4 then
			local y = top + 2 * (size + gap) + UI.PHONE_REBIRTH_SIZE.Y + gap
			if y + size <= screen.Y - UI.PHONE_JUMP_ZONE then
				return Vector2.new(right - size, y), 1, icon
			end
			return Vector2.new(right - 2 * size - gap, top + size + gap), 1, icon
		end
		return Vector2.new(right - size, top + index * (size + gap)), 1, icon
	end
	local step = UI.LEFT_COLUMN_STEP
	-- Hauteur de la colonne à taille normale : 4 écarts de 54 px et le dernier bouton (46 px).
	local height = (UI.LEFT_COLUMN_COUNT - 1) * step + UI.LEFT_BUTTON_SIZE.Y
	local scale = math.clamp((screen.Y - UI.WINDOW_MARGIN - UI.LEFT_COLUMN_TOP) / height, UI.MIN_WINDOW_SCALE, 1)
	return Vector2.new(UI.LEFT_COLUMN_X, math.floor(UI.LEFT_COLUMN_TOP + index * step * scale)), scale, UI.LEFT_BUTTON_SIZE
end

-- Bord droit (px) des boutons de la colonne de gauche sur cet écran (une fenêtre qu'ils couvriraient reste à côté).
-- Téléphone : 0, il n'y a plus de colonne à gauche (les boutons sont en haut, voir UI.leftColumnSlot).
function UI.leftColumnRight(screen: Vector2): number
	if UI.touchLayout(screen) then
		return 0
	end
	local _, scale = UI.leftColumnSlot(screen, 0)
	return UI.LEFT_COLUMN_X + UI.LEFT_BUTTON_SIZE.X * scale
end

-- Place un bouton de la colonne de gauche (UI.leftColumnSlot) et le replace quand la taille de l'écran change.
-- Il doit déjà être dans son ScreenGui.
-- Téléphone : les raccourcis sont cachés pendant que le panneau des tours est ouvert (il prend tout l'écran, au
-- premier plan : le fermer les rend), et quand le joueur les a masqués avec le bouton « ▲ »
-- (UI.startShortcutToggle). Jamais cachés sur un ordinateur.
local shortcutsHidden = false
local function shortcutsShown(screen: Vector2): boolean
	if not UI.touchLayout(screen) then
		return true
	end
	local plotGui = plotPanel and plotPanel:FindFirstAncestorWhichIsA("ScreenGui")
	local panelOpen = plotPanel ~= nil and plotPanel.Visible and plotGui ~= nil and plotGui.Enabled
	return not shortcutsHidden and not panelOpen
end
local function fitShortcutPadding(button: GuiObject, height: number)
	-- Petit bouton (téléphone) : marge intérieure réduite, pour garder un texte lisible.
	local padding = button:FindFirstChildOfClass("UIPadding")
	if padding then
		local edge = UDim.new(0, if height <= 40 then 3 else 6)
		padding.PaddingTop, padding.PaddingBottom, padding.PaddingLeft, padding.PaddingRight = edge, edge, edge, edge
	end
end
local function refreshNavigation()
	for _, entry in navigationFits do
		if entry.button.Parent then
			entry.fit()
		end
	end
end
-- Téléphone : les boutons SON et Vitesse x2 disparaissent aussi quand le joueur a masqué les raccourcis (il ne reste
-- que « ▼ » et le compteur de pièces : la vue est dégagée). Toujours vrai sur un ordinateur.
function UI.extrasShown(screen: Vector2): boolean
	return not (UI.touchLayout(screen) and shortcutsHidden)
end
-- fit() sera rappelée chaque fois que les raccourcis sont masqués ou remis, et que le panneau des tours s'ouvre ou se
-- ferme (pour un bouton qui suit UI.extrasShown).
function UI.watchShortcuts(button: GuiObject, fit: () -> ())
	table.insert(navigationFits, { button = button, fit = fit })
end

-- icon = l'icône du bouton sur téléphone (emoji) : là, le bouton est un petit carré, son texte est caché et l'icône
-- le remplace (étiquette « PhoneIcon »). Sans icône (bouton Renaissance : il gère la sienne), rien n'est caché.
function UI.placeInLeftColumn(button: GuiObject, index: number, icon: string?)
	local scale = UI.new("UIScale", { Name = "ColumnScale", Parent = button }) :: UIScale
	local gui = button:FindFirstAncestorWhichIsA("ScreenGui")
	local iconLabel = if icon
		then UI.label({ Name = "PhoneIcon", Size = UDim2.fromScale(1, 1), Text = icon, MaxTextSize = 26, Visible = false, Parent = button })
		else nil
	local function place()
		local screen = UI.screenSize(gui)
		if screen.X > 0 and screen.Y > 0 then
			local position, value, size = UI.leftColumnSlot(screen, index)
			button.Position = UDim2.fromOffset(position.X, position.Y)
			button.Size = UDim2.fromOffset(size.X, size.Y)
			scale.Scale = value
			fitShortcutPadding(button, size.Y)
			button.Visible = shortcutsShown(screen)
			if iconLabel then
				local phone = UI.touchLayout(screen)
				iconLabel.Visible = phone
				if button:IsA("TextButton") then
					button.TextTransparency = if phone then 1 else 0
				end
			end
		end
	end
	place()
	table.insert(navigationFits, { button = button, fit = place })
	if gui then
		gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
	end
end

function UI.registerPlotPanel(panel: GuiObject)
	plotPanel = panel
	panel:GetPropertyChangedSignal("Visible"):Connect(refreshNavigation)
	local gui = panel:FindFirstAncestorWhichIsA("ScreenGui")
	if gui then
		gui:GetPropertyChangedSignal("Enabled"):Connect(refreshNavigation)
		gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refreshNavigation)
	end
	refreshNavigation()
end

-- Les raccourcis reviennent (le tuto les montre à la fin : ils doivent être là).
function UI.showShortcuts()
	if shortcutsHidden then
		shortcutsHidden = false
		refreshNavigation()
	end
end

-- Téléphone : bouton « ▲ » qui masque les icônes de droite et le bouton SON (demande du propriétaire, 01/10/2026 :
-- pouvoir dégager la vue, SANS jamais perdre le bouton qui les remet). Il est en haut à droite, collé au compteur de
-- pièces (UI.phoneTopRight, case 3), et ne bouge jamais : icônes masquées, il devient « ▼ » et un appui les remet.
-- Il n'est caché que pendant que le panneau des tours couvre l'écran, et il n'existe pas sur ordinateur. Le choix
-- dure le temps de la partie (icônes affichées à chaque arrivée).
function UI.startShortcutToggle()
	local gui = UI.screen("ShortcutsToggle")
	local button = UI.button({
		Name = "ToggleButton",
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = UI.Colors.PanelLight,
		Text = "▲",
		MaxTextSize = 18,
		Visible = false,
		Parent = gui,
	})
	local function place()
		local screen = UI.screenSize(gui)
		if screen.X <= 0 or screen.Y <= 0 then
			return
		end
		local position, size = UI.phoneTopRight(screen, 3)
		button.Position = position
		button.Size = UDim2.fromOffset(size.X, size.Y)
		button.Text = if shortcutsHidden then "▼" else "▲"
		-- (masqués ou non : le bouton reste, sauf sous le panneau des tours)
		local plotGui = plotPanel and plotPanel:FindFirstAncestorWhichIsA("ScreenGui")
		local panelOpen = plotPanel ~= nil and plotPanel.Visible and plotGui ~= nil and plotGui.Enabled
		button.Visible = UI.touchLayout(screen) and not panelOpen
	end
	local function toggle()
		shortcutsHidden = not shortcutsHidden
		refreshNavigation()
	end
	button.Activated:Connect(toggle)
	table.insert(navigationFits, { button = button, fit = place })
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
	place()
	-- Tests automatiques dans Studio (un plugin ne peut pas cliquer) : changer l'attribut « TestToggle » de cet écran
	-- fait comme un appui sur le bouton. Jamais dans le jeu publié.
	if game:GetService("RunService"):IsStudio() then
		gui:GetAttributeChangedSignal("TestToggle"):Connect(toggle)
	end
end

-- Téléphone = le petit côté de l'écran fait moins de 500 px (paysage 844 x 390, portrait 390 x 844...). Fonction pure.
function UI.isPhone(screen: Vector2): boolean
	return screen.X > 0 and screen.Y > 0 and math.min(screen.X, screen.Y) < 500
end

-- Disposition « téléphone » de la map principale : panneau des tours sur presque tout l'écran, raccourcis en haut
-- (UI.leftColumnSlot). Décidée par la TAILLE de l'écran seulement, pas par « écran tactile » : une tablette garde la
-- disposition d'ordinateur (elle a la place), et le test tools/studio-test/phone.ps1 peut afficher exactement ce
-- que voit un téléphone en réduisant la fenêtre de Studio (un ordinateur n'est jamais « tactile sans clavier »).
function UI.touchLayout(screen: Vector2): boolean
	return UI.isPhone(screen)
end

-- Sur téléphone (demandes du propriétaire, 30/09 et 01/10/2026 : le compteur de pièces et le bouton SON étaient en
-- plein milieu de la vue, puis « trop grands, ils gênent »), le compteur de pièces (PlotUI), le bouton « ▲ » qui
-- masque les icônes (UI.startShortcutToggle), le bouton SON (SoundManager) et le bouton Vitesse x2 (ShopUI) sont
-- petits et regroupés tout en haut à droite, DANS LA BARRE DU HAUT DE ROBLOX (à droite de ses boutons, comme les
-- icônes des autres jeux) : ils ne prennent plus rien sur la vue. slot 0 = compteur (au bord), 3 = « ▲ », 1 = SON,
-- 2 = Vitesse x2, de droite à gauche. Renvoie la position du coin EN HAUT À DROITE (AnchorPoint 1, 0) et la taille.
--   Paysage : hauteur négative = au-dessus de la zone de jeu, dans la barre de Roblox (topBar px de haut, 58 sur
--   un téléphone ; UI.screen ne l'ignore pas : la zone de jeu commence sous elle). Barre trop basse pour eux
--   (moins de 42 px) : en haut de la zone de jeu, comme avant.
--   Portrait : en haut de la zone de jeu, SON, « ▲ » et Vitesse sous le compteur.
-- topBar = hauteur de la barre du haut (par défaut la vraie, GuiService:GetGuiInset ; les tests donnent la leur).
function UI.phoneTopRight(screen: Vector2, slot: number, topBar: number?): (UDim2, Vector2)
	local wallet, button = UI.PHONE_WALLET_SIZE, UI.PHONE_BUTTON_SIZE
	local order = if slot == 3 then 1 elseif slot == 1 then 2 elseif slot == 2 then 3 else 0 -- place depuis la droite
	if screen.Y > screen.X then
		if order == 0 then
			return UDim2.new(1, -PHONE_MARGIN, 0, 8), wallet
		end
		return UDim2.new(1, -PHONE_MARGIN - (order - 1) * (button.X + PHONE_GAP), 0, 8 + wallet.Y + PHONE_GAP), button
	end
	local bar = topBar or (GuiService:GetGuiInset()).Y
	local top = if bar >= wallet.Y + 8 then -bar + math.floor((bar - wallet.Y) / 2) else 8
	if order == 0 then
		return UDim2.new(1, -PHONE_MARGIN, 0, top), wallet
	end
	local right = PHONE_MARGIN + wallet.X + PHONE_GAP + (order - 1) * (button.X + PHONE_GAP)
	return UDim2.new(1, -right, 0, top), button
end

-- Panneau des tours (PlotUI) : sa taille et le nombre de cartes par rangée. Taille réelle, sans réduire les textes.
--   Téléphone : presque tout l'écran (8 px de marge), 4 cartes par rangée dès 560 px de large, 2 sinon ; les cartes
--   se feuillettent par pages (◀ ▶).
--   Ordinateur et tablette : en bas de l'écran comme avant (760 px de large au plus, la place du chat et de la
--   colonne de gauche réservée), 460 px de haut (4 cartes par page) ; PLOT_PANEL_TALL sur un écran haut (790 px et
--   plus : le haut de l'écran, compteur de pièces et tuto, reste libre), pour montrer les 8 tours d'un coup (2
--   rangées de 4, sans pages).
UI.PLOT_PANEL_TALL = 566 -- 2 rangées de cartes de 216 px + 8 px entre elles + 126 px (titre, bas du panneau, marges)
function UI.plotPanelLayout(screen: Vector2): (Vector2, number)
	if UI.touchLayout(screen) then
		local width = math.max(160, screen.X - 16)
		return Vector2.new(width, math.max(160, screen.Y - 16)), if width >= 560 then 4 else 2
	end
	local portrait = screen.X < 700 and screen.Y > screen.X
	local reserved = if portrait then 0 elseif screen.X >= 1100 then 500 else 280
	local width = math.max(160, math.min(760, screen.X - reserved - 32))
	local height = math.max(160, math.min(460, screen.Y - 96, math.max(280, screen.Y * 0.72)))
	if width >= 600 and screen.Y >= UI.PLOT_PANEL_TALL + 224 then
		height = UI.PLOT_PANEL_TALL
	end
	return Vector2.new(width, height), if width >= 600 then 4 else 2
end

function UI.modalSize(screen: Vector2, design: Vector2): Vector2
	return Vector2.new(math.min(design.X, math.max(160, screen.X - 16)), math.min(design.Y, math.max(160, screen.Y - 16)))
end

-- Contour noir et liseré coloré. Pas d'image, de lumière ou d'animation permanente.
function UI.chrome(frame: GuiObject, accent: Color3?)
	local edge = frame:FindFirstChildOfClass("UIStroke")
	if not edge then edge = UI.stroke(accent or UI.Colors.Gold, 1); edge.Parent = frame end
	edge.Color = UI.Colors.Ink
	edge.Thickness = 3
	edge.Transparency = 0
	UI.new("Frame", { Name = "HeaderRule", Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = accent or UI.Colors.Accent, BackgroundTransparency = 0, BorderSizePixel = 0, Parent = frame })
end

-- Décor purement graphique : dégradés statiques, aucun changement d'action ni de texte.
function UI.gradient(parent: Instance, rotation: number?)
	return UI.new("UIGradient", {
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(160, 170, 194)),
		Rotation = rotation or 90,
		Parent = parent,
	})
end

function UI.card(frame: GuiObject, color: Color3?)
	frame.BackgroundColor3 = color or UI.Colors.PanelLight
	UI.stroke(UI.Colors.Ink, 3).Parent = frame
	UI.gradient(frame)
end

function UI.metric(parent: Instance, title: string, index: number, total: number)
	local frame = UI.new("Frame", {
		Name = "Metric" .. index, Position = UDim2.new((index - 1) / total, 3, 0, 0),
		Size = UDim2.new(1 / total, -6, 0, 76), BackgroundColor3 = UI.Colors.PanelLight,
		BorderSizePixel = 0, Parent = parent,
	}, { UI.corner(8), UI.padding(8) })
	local caption = UI.label({ Name = "Caption", Size = UDim2.new(1, 0, 0, 14), Text = title,
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UI.Colors.Muted, MaxTextSize = 12, Parent = frame })
	local value = UI.label({ Name = "Value", Position = UDim2.fromOffset(0, 17), Size = UDim2.new(1, 0, 0, 24),
		Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.Gold, MaxTextSize = 23, Parent = frame })
	local detail = UI.label({ Name = "Detail", Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 0, 14),
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UI.Colors.Muted, MaxTextSize = 12, Parent = frame })
	return { frame = frame, caption = caption, value = value, detail = detail }
end

function UI.label(props: { [string]: any })
	local defaults = {
		BackgroundTransparency = 1,
		Font = UI.BodyFont,
		TextColor3 = UI.Colors.Text,
		TextScaled = true,
		TextStrokeColor3 = UI.Colors.Ink,
		TextStrokeTransparency = 0.45,
	}
	for key, value in props do
		if key ~= "MaxTextSize" then
			defaults[key] = value
		end
	end
	-- Les titres déjà marqués gras gardent leur hiérarchie, dans une police arrondie.
	local title = defaults.Font == Enum.Font.GothamBlack or defaults.Font == Enum.Font.GothamBold or defaults.Font == UI.TitleFont
	if title then
		defaults.Font = UI.TitleFont
		defaults.TextStrokeTransparency = 1
	elseif defaults.Font == Enum.Font.GothamMedium then
		defaults.Font = UI.BodyFont
	end
	local label = UI.new("TextLabel", defaults, { UI.new("UITextSizeConstraint", { MaxTextSize = props.MaxTextSize or 28 }) })
	if title then
		UI.new("UIStroke", { Color = UI.Colors.Ink, Thickness = if (props.MaxTextSize or 28) >= 18 then 2 else 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = label })
	end
	return label
end

function UI.button(props: { [string]: any })
	local defaults = {
		BackgroundColor3 = UI.Colors.Accent,
		AutoButtonColor = true,
		Font = UI.TitleFont,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		TextWrapped = true,
		TextStrokeColor3 = UI.Colors.Ink,
		TextStrokeTransparency = 1,
	}
	local maxTextSize = props.MaxTextSize or 24
	for key, value in props do
		if key ~= "MaxTextSize" then
			defaults[key] = value
		end
	end
	return UI.new("TextButton", defaults, {
		UI.corner(5),
		UI.padding(5),
		UI.stroke(UI.Colors.Ink, 3),
		UI.new("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(160, 170, 194)),
			}),
			Rotation = 90,
		}),
		UI.new("UIStroke", { Color = UI.Colors.Ink, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }),
		UI.new("UITextSizeConstraint", { MaxTextSize = maxTextSize }),
	})
end

-- Barre de progression : retourne (conteneur, fonction set(ratio)).
function UI.bar(props: { [string]: any }, fillColor: Color3)
	local container = UI.new("Frame", {
		BackgroundColor3 = UI.Colors.Background,
		BorderSizePixel = 0,
	}, { UI.corner(6) })
	for key, value in props do
		(container :: any)[key] = value
	end
	local fill = UI.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = fillColor,
		BorderSizePixel = 0,
		Parent = container,
	}, { UI.corner(6) })
	return container, function(ratio: number)
		fill.Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
	end
end

function UI.formatTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- Vitesse d'attaque en attaques par seconde, à partir du temps entre deux attaques (cooldown) :
-- 0,2 s -> « 5 atq/s », 4 s -> « 0.25 atq/s », 1,2 s -> « 0.83 atq/s », 0,1 s -> « 10 atq/s ».
function UI.attackSpeed(cooldown: number): string
	local rate = if typeof(cooldown) == "number" and cooldown > 0 then 1 / cooldown else 0
	local text
	if rate >= 10 then
		text = string.format("%d", math.floor(rate + 0.5))
	else
		-- 2 chiffres après la virgule au plus, sans zéros inutiles (1.50 -> 1.5, 5.00 -> 5)
		text = string.format("%.2f", rate):gsub("0+$", ""):gsub("%.$", "")
	end
	return text .. " atq/s"
end

-- Vitesse d'une tour du mode infini : « continu » pour le rayon du Sorcier des arcanes (pas de coups,
-- des dégâts à chaque instant), sinon ses attaques par seconde (« 5 atq/s »).
function UI.towerSpeed(stats): string
	if stats.kind == "Beam" then
		return "continu"
	end
	return UI.attackSpeed(stats.cooldown)
end

-- Nombre écrit à la française, sans zéros inutiles : 2.25 -> « 2,25 », 13 -> « 13 », 1.2 -> « 1,2 ».
function UI.decimal(value: number): string
	return (string.gsub(string.format("%g", value), "%.", ","))
end

local toastGui = nil
local toastList = nil
local toastCount = 0
local MAX_TOASTS = 3

-- Appelée à chaque nouveau message affiché, (message, kind) : SoundManager y branche le son « refusé » des
-- erreurs (UI ne peut pas charger SoundManager lui-même : SoundManager utilise UI).
UI.onToast = nil :: ((string, string?) -> ())?

-- Petite notification en haut de l'écran.
function UI.toast(message: string, kind: string?)
	if not toastGui then
		toastGui = UI.screen("Toasts", 50)
		toastList = UI.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 90),
			Size = UDim2.new(0.36, 0, 0.5, 0),
			BackgroundTransparency = 1,
			Parent = toastGui,
		}, {
			UI.new("UIListLayout", {
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
	end

	-- Peu de texte à l'écran : un message identique à un message affiché n'est pas répété, et
	-- au-delà de MAX_TOASTS le plus ancien disparaît. (On compare le message d'origine, gardé dans l'attribut
	-- « Message » : le texte affiché peut être sa traduction anglaise, AutoTranslate.luau.)
	for _, existing in toastList:GetChildren() do
		if existing:IsA("TextLabel") and existing:GetAttribute("Message") == message and existing.TextTransparency < 0.5 then
			return
		end
	end
	local visible = {}
	for _, existing in toastList:GetChildren() do
		if existing:IsA("TextLabel") then
			table.insert(visible, existing)
		end
	end
	table.sort(visible, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i = 1, #visible - MAX_TOASTS + 1 do
		visible[i]:Destroy()
	end
	if UI.onToast then
		UI.onToast(message, kind)
	end

	local color = UI.Colors[kind or "Info"] or UI.Colors.PanelLight
	toastCount += 1
	-- Un long message (ex. l'inscription au classé) passe sur 2 lignes au lieu d'être écrit tout petit. Sa longueur
	-- dans la langue du joueur : la traduction anglaise peut être plus longue ou plus courte que le français.
	local shownText = Lang.translate(message, Lang.current())
	local long = (utf8.len(shownText) or #shownText) > 70
	local toast = UI.new("TextLabel", {
		Size = UDim2.new(1, 0, 0, if long then 46 else 28),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.1,
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		TextWrapped = long,
		Text = message,
		LayoutOrder = toastCount,
		Parent = toastList,
	}, {
		UI.corner(8),
		UI.padding(6),
		UI.new("UITextSizeConstraint", { MaxTextSize = 16 }),
	})
	toast:SetAttribute("Message", message) -- message d'origine (voir plus haut : pas de message répété)

	task.delay(2.5, function()
		local tween = TweenService:Create(toast, TweenInfo.new(0.4), { BackgroundTransparency = 1, TextTransparency = 1 })
		tween:Play()
		tween.Completed:Wait()
		toast:Destroy()
	end)
end

return UI

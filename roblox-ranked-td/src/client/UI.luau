-- Petits utilitaires pour construire l'interface en code.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local UI = {}

UI.Colors = {
	Background = Color3.fromRGB(15, 20, 28),
	Panel = Color3.fromRGB(25, 32, 43),
	PanelLight = Color3.fromRGB(39, 49, 64),
	Text = Color3.fromRGB(245, 241, 230),
	Muted = Color3.fromRGB(179, 190, 205),
	Accent = Color3.fromRGB(43, 80, 104),
	Success = Color3.fromRGB(38, 109, 82),
	Warning = Color3.fromRGB(136, 90, 30),
	Error = Color3.fromRGB(147, 45, 60),
	Gold = Color3.fromRGB(236, 192, 105),
	DangerText = Color3.fromRGB(255, 143, 151),
	PositiveText = Color3.fromRGB(128, 226, 175),
}

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
		Color = color or UI.Colors.Gold,
		Thickness = thickness or 1,
		Transparency = 0.7,
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

-- Place du bouton n° `index` (0 = celui du haut) de la colonne de gauche, pour un écran de taille `screen` (px) :
-- son coin en haut à gauche et son échelle. Écran assez haut pour les 5 boutons : taille normale (rien ne change sur
-- un ordinateur). Sinon (téléphone en paysage : la Boutique et les Défis sortaient de l'écran), toute la colonne
-- est réduite pour tenir sous la carte de rang, à sa place d'avant (jamais plus large : elle ne passe pas sur le
-- panneau des tours). Fonction pure.
function UI.leftColumnSlot(screen: Vector2, index: number): (Vector2, number)
	local step = UI.LEFT_COLUMN_STEP
	-- Hauteur de la colonne à taille normale : 4 écarts de 54 px et le dernier bouton (46 px).
	local height = (UI.LEFT_COLUMN_COUNT - 1) * step + UI.LEFT_BUTTON_SIZE.Y
	local scale = math.clamp((screen.Y - UI.WINDOW_MARGIN - UI.LEFT_COLUMN_TOP) / height, UI.MIN_WINDOW_SCALE, 1)
	return Vector2.new(UI.LEFT_COLUMN_X, math.floor(UI.LEFT_COLUMN_TOP + index * step * scale)), scale
end

-- Bord droit (px) des boutons de la colonne de gauche sur cet écran (une fenêtre qu'ils couvriraient reste à côté).
function UI.leftColumnRight(screen: Vector2): number
	local _, scale = UI.leftColumnSlot(screen, 0)
	return UI.LEFT_COLUMN_X + UI.LEFT_BUTTON_SIZE.X * scale
end

-- Place un bouton de la colonne de gauche (UI.leftColumnSlot) et le replace quand la taille de l'écran change.
-- Il doit déjà être dans son ScreenGui.
function UI.placeInLeftColumn(button: GuiObject, index: number)
	local scale = UI.new("UIScale", { Name = "ColumnScale", Parent = button }) :: UIScale
	local gui = button:FindFirstAncestorWhichIsA("ScreenGui")
	local function place()
		local screen = UI.screenSize(gui)
		if screen.X > 0 and screen.Y > 0 then
			local position, value = UI.leftColumnSlot(screen, index)
			button.Position = UDim2.fromOffset(position.X, position.Y)
			scale.Scale = value
			local plotGui = plotPanel and plotPanel:FindFirstAncestorWhichIsA("ScreenGui")
			-- Sur téléphone portrait, la fiche est un panneau au premier plan : fermer la fiche rend la navigation.
			button.Visible = not (screen.X < 700 and screen.Y > screen.X and plotPanel
				and plotPanel.Visible and plotGui and plotGui.Enabled)
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
	local function refreshNavigation()
		for _, entry in navigationFits do if entry.button.Parent then entry.fit() end end
	end
	panel:GetPropertyChangedSignal("Visible"):Connect(refreshNavigation)
	local gui = panel:FindFirstAncestorWhichIsA("ScreenGui")
	if gui then gui:GetPropertyChangedSignal("Enabled"):Connect(refreshNavigation) end
	refreshNavigation()
end

-- Taille réelle des panneaux : le texte ne devient pas minuscule pour faire tenir huit cartes.
function UI.plotPanelLayout(screen: Vector2): (Vector2, number)
	local portrait = screen.X < 700 and screen.Y > screen.X
	local reserved = if portrait then 0 elseif screen.X >= 1100 then 500 else 280
	local width = math.max(160, math.min(760, screen.X - reserved - 32))
	local height = math.max(160, math.min(460, screen.Y - 96, math.max(280, screen.Y * 0.72)))
	return Vector2.new(width, height), if width >= 600 then 4 else 2
end

function UI.modalSize(screen: Vector2, design: Vector2): Vector2
	return Vector2.new(math.min(design.X, math.max(160, screen.X - 16)), math.min(design.Y, math.max(160, screen.Y - 16)))
end

-- Bordure et bande dorée discrètes. Pas d'image, de lumière ou d'animation permanente.
function UI.chrome(frame: GuiObject, accent: Color3?)
	local edge = frame:FindFirstChildOfClass("UIStroke")
	if not edge then edge = UI.stroke(accent or UI.Colors.Gold, 1); edge.Parent = frame end
	edge.Color = accent or UI.Colors.Gold
	edge.Transparency = 0.58
	UI.new("Frame", { Name = "HeaderRule", Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = accent or UI.Colors.Gold, BackgroundTransparency = 0.3, BorderSizePixel = 0, Parent = frame })
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
		Font = Enum.Font.GothamMedium,
		TextColor3 = UI.Colors.Text,
		TextScaled = true,
	}
	for key, value in props do
		if key ~= "MaxTextSize" then
			defaults[key] = value
		end
	end
	return UI.new("TextLabel", defaults, { UI.new("UITextSizeConstraint", { MaxTextSize = props.MaxTextSize or 28 }) })
end

function UI.button(props: { [string]: any })
	local defaults = {
		BackgroundColor3 = UI.Colors.Accent,
		AutoButtonColor = true,
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		TextWrapped = true,
	}
	local maxTextSize = props.MaxTextSize or 24
	for key, value in props do
		if key ~= "MaxTextSize" then
			defaults[key] = value
		end
	end
	return UI.new("TextButton", defaults, {
		UI.corner(8),
		UI.padding(6),
		UI.stroke(UI.Colors.Gold, 1),
		UI.new("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(210, 217, 227)),
			}),
			Rotation = 90,
		}),
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
	-- au-delà de MAX_TOASTS le plus ancien disparaît.
	for _, existing in toastList:GetChildren() do
		if existing:IsA("TextLabel") and existing.Text == message and existing.TextTransparency < 0.5 then
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
	-- Un long message (ex. l'inscription au classé) passe sur 2 lignes au lieu d'être écrit tout petit.
	local long = (utf8.len(message) or #message) > 70
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

	task.delay(2.5, function()
		local tween = TweenService:Create(toast, TweenInfo.new(0.4), { BackgroundTransparency = 1, TextTransparency = 1 })
		tween:Play()
		tween.Completed:Wait()
		toast:Destroy()
	end)
end

return UI

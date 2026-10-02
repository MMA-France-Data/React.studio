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

-- Place des boutons « (Studio) » (galerie des ennemis, panneau des sons) : à gauche, sous la rangée du haut.
UI.STUDIO_BUTTONS_TOP = 110

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

-- Téléphone = le petit côté de l'écran fait moins de 500 px (paysage 844 x 390, portrait 390 x 844...). Fonction pure.
function UI.isPhone(screen: Vector2): boolean
	return screen.X > 0 and screen.Y > 0 and math.min(screen.X, screen.Y) < 500
end

-- Disposition « téléphone ». Décidée par la TAILLE de l'écran seulement, pas par « écran tactile » : une tablette
-- garde la disposition d'ordinateur (elle a la place), et le test tools/studio-test/run.ps1 peut afficher
-- exactement ce que voit un téléphone en réduisant la fenêtre de Studio.
function UI.touchLayout(screen: Vector2): boolean
	return UI.isPhone(screen)
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

-- Vitesse d'une tour : « continu » pour le rayon du Sorcier des arcanes (pas de coups,
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
	-- Un long message passe sur 2 lignes au lieu d'être écrit tout petit. Sa longueur
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

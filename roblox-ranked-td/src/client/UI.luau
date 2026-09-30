-- Petits utilitaires pour construire l'interface en code.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local UI = {}

UI.Colors = {
	Background = Color3.fromRGB(27, 21, 16),
	Panel = Color3.fromRGB(45, 34, 25),
	PanelLight = Color3.fromRGB(69, 50, 35),
	Text = Color3.fromRGB(244, 234, 215),
	Muted = Color3.fromRGB(184, 166, 142),
	Accent = Color3.fromRGB(68, 103, 78),
	Success = Color3.fromRGB(76, 126, 83),
	Warning = Color3.fromRGB(190, 130, 45),
	Error = Color3.fromRGB(151, 48, 46),
	Gold = Color3.fromRGB(216, 170, 76),
}

-- Colonne de boutons à gauche de la map principale (sous le panneau de rang de 130 px).
UI.LEFT_COLUMN_TOP = 162
UI.LEFT_COLUMN_STEP = 54

-- UI.new("Frame", { Size = ..., Parent = ... }, { enfants })
function UI.new(className: string, props: { [string]: any }?, children: { Instance }?)
	local instance = Instance.new(className)
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
		Color = color or Color3.new(1, 1, 1),
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
		Font = Enum.Font.Antique,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
	}
	local maxTextSize = props.MaxTextSize or 24
	for key, value in props do
		if key ~= "MaxTextSize" then
			defaults[key] = value
		end
	end
	return UI.new("TextButton", defaults, {
		UI.corner(6),
		UI.padding(6),
		UI.stroke(UI.Colors.Gold, 1),
		UI.new("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(178, 155, 126)),
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

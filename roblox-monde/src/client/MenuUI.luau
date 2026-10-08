-- Presentation only: native icons need no uploaded image assets or external requests.
local UserInputService = game:GetService("UserInputService")
local UI = {}
UI.Colors = {
	Ink = Color3.fromRGB(12, 19, 34), Panel = Color3.fromRGB(24, 36, 56),
	Card = Color3.fromRGB(35, 51, 75), Well = Color3.fromRGB(17, 27, 44),
	Edge = Color3.fromRGB(84, 111, 143), Text = Color3.fromRGB(247, 250, 255),
	Muted = Color3.fromRGB(197, 212, 232), Gold = Color3.fromRGB(255, 218, 100),
	Blue = Color3.fromRGB(28, 100, 178), Green = Color3.fromRGB(26, 118, 75),
	Red = Color3.fromRGB(190, 49, 62), Purple = Color3.fromRGB(111, 63, 194),
	Teal = Color3.fromRGB(15, 107, 122), Orange = Color3.fromRGB(153, 88, 20),
}
UI.Menu = {
	EggButton = { icon = "egg", color = UI.Colors.Blue },
	PawButton = { icon = "paw", color = UI.Colors.Green },
	BagButton = { icon = "bag", color = UI.Colors.Purple },
	SwordButton = { icon = "sword", color = UI.Colors.Orange },
	ShopButton = { icon = "shop", color = UI.Colors.Teal },
}
UI.Panels = { EggPanel = "EggButton", PetPanel = "PawButton", BagPanel = "BagButton", SwordPanel = "SwordButton", ShopPanel = "ShopButton" }

function UI.screenSize(gui: ScreenGui): Vector2
	local size = gui.AbsoluteSize
	return if size.X > 0 and size.Y > 0 then size else workspace.CurrentCamera.ViewportSize
end
function UI.compact(size: Vector2): boolean
	return size.Y < 660 or size.X < 820 or workspace:GetAttribute("PhoneHud") == true
		or (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)
end
function UI.windowScale(screen: Vector2, design: Vector2): number
	return math.min(1, math.max(1, screen.X - 24) / design.X, math.max(1, screen.Y - 24) / design.Y)
end
function UI.fitWindow(frame: Frame, screen: Vector2)
	frame.Scale.Scale = UI.windowScale(screen, Vector2.new(frame.Size.X.Offset, frame.Size.Y.Offset))
end
function UI.gradient(parent: GuiObject)
	if parent:FindFirstChild("SurfaceGradient") then return end
	local gradient = Instance.new("UIGradient")
	gradient.Name = "SurfaceGradient"
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(203, 218, 238))
	gradient.Parent = parent
end
function UI.chrome(frame: GuiObject, accent: Color3?, radius: number?)
	frame.BorderSizePixel = 0
	local corner = frame:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 12)
	corner.Parent = frame
	local stroke = frame:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	stroke.Name = "UIStroke"
	stroke.Color = accent or UI.Colors.Edge
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame
end
function UI.label(label: TextLabel, maximum: number?)
	label.Font = if (maximum or 24) >= 28 then Enum.Font.FredokaOne else Enum.Font.GothamBold
	label.TextColor3 = UI.Colors.Text
	label.TextScaled = true
	label.TextWrapped = true
	label.AutoLocalize = false
	local stroke = label:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	stroke.Name = "UIStroke"
	stroke.Color = UI.Colors.Ink
	stroke.Thickness = if (maximum or 24) >= 28 then 1.5 else 0.8
	stroke.Transparency = 0.15
	stroke.Parent = label
	local limit = label:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
	limit.MinTextSize = 12
	limit.MaxTextSize = maximum or 24
	limit.Parent = label
end
function UI.button(button: TextButton, color: Color3?)
	button.BackgroundColor3 = color or UI.Colors.Blue
	button.AutoButtonColor = true
	button.AutoLocalize = false
	UI.chrome(button, UI.Colors.Ink, 10)
	UI.gradient(button)
end
function UI.icon(parent: GuiObject, kind: string, color: Color3?)
	local previous = parent:FindFirstChild("Glyph")
	if previous then previous:Destroy() end
	local root = Instance.new("Frame")
	root.Name = "Glyph"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.ZIndex = parent.ZIndex
	root.Parent = parent
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.DominantAxis = Enum.DominantAxis.Height
	aspect.Parent = root
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	local ink = color or UI.Colors.Text
	local function shape(x: number, y: number, w: number, h: number, round: number?, rotation: number?, fill: Color3?, border: boolean?)
		local part = Instance.new("Frame")
		part.Name = "Shape"
		part.Position = UDim2.fromScale(x, y)
		part.Size = UDim2.fromScale(w, h)
		part.Rotation = rotation or 0
		part.BackgroundColor3 = fill or ink
		part.BorderSizePixel = 0
		part.ZIndex = root.ZIndex
		part.Parent = root
		if round then Instance.new("UICorner", part).CornerRadius = UDim.new(round, 0) end
		if border then
			part.BackgroundTransparency = 1
			local outline = Instance.new("UIStroke")
			outline.Thickness = 2
			outline.Color = ink
			outline.Parent = part
		end
		return part
	end
	if kind == "egg" then
		shape(.24, .12, .52, .72, .5)
		shape(.36, .25, .11, .17, .5, -22, UI.Colors.Gold)
		shape(.53, .53, .14, .10, .5, 18, UI.Colors.Blue)
	elseif kind == "paw" then
		shape(.29, .49, .43, .32, .5)
		for _, toe in { { .14, .32 }, { .34, .15 }, { .57, .15 }, { .74, .32 } } do
			shape(toe[1], toe[2], .15, .21, .5)
		end
	elseif kind == "bag" then
		shape(.33, .12, .34, .22, .4, 0, nil, true)
		shape(.20, .28, .60, .55, .18)
		shape(.31, .55, .38, .17, .2, 0, UI.Colors.Purple)
		shape(.34, .35, .32, .07, .3, 0, UI.Colors.Gold)
	elseif kind == "shop" then
		shape(.25, .45, .51, .37, .1)
		shape(.18, .27, .64, .20, .15)
		shape(.32, .16, .36, .10, .2, 0, UI.Colors.Gold)
		shape(.36, .56, .11, .26, .1, 0, UI.Colors.Teal)
		shape(.53, .55, .13, .13, .1, 0, UI.Colors.Teal)
	elseif kind == "sword" or kind == "attack" then
		shape(.43, .12, .15, .52, .1, 34)
		shape(.29, .61, .34, .10, .2, 34, UI.Colors.Gold)
		shape(.30, .67, .12, .20, .2, 34, UI.Colors.Gold)
		if kind == "attack" then shape(.40, .18, .12, .50, .1, -34) end
	elseif kind == "auto" then
		shape(.19, .19, .62, .62, .5, 0, nil, true)
		shape(.64, .14, .20, .20, .1, 45)
		shape(.16, .66, .20, .20, .1, 45)
	end
	return root
end
function UI.scrolling(parent: Instance, name: string, size: UDim2, position: UDim2): ScrollingFrame
	local frame = Instance.new("ScrollingFrame")
	frame.Name = name
	frame.Size = size
	frame.Position = position
	frame.BackgroundColor3 = UI.Colors.Card
	frame.ScrollBarImageColor3 = UI.Colors.Muted
	frame.ScrollBarThickness = 0
	frame.ScrollingDirection = Enum.ScrollingDirection.Y
	frame.CanvasSize = UDim2.fromOffset(0, 0)
	frame.Parent = parent
	UI.chrome(frame)
	return frame
end

return UI

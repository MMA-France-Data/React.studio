-- L'écran du joueur : ses pièces et ses niveaux, le bandeau de la salle (événement, compte à rebours), les
-- messages (« +300 pièces »), les textes du décor dans sa langue, et le rebond du trampoline.
-- Les œufs, les couveuses et les animaux sont dans Animals.luau.
local CollectionService = game:GetService("CollectionService")
local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Texts = require(ReplicatedStorage.Shared.Texts)

local player = Players.LocalPlayer
local lang = if LocalizationService.RobloxLocaleId:lower():sub(1, 2) == "fr" then "fr" else "en"

local function tr(key: string, ...): string
	return Texts.get(lang, key, ...)
end
local function num(value: number): string
	return Texts.number(lang, value)
end

-- LES TEXTES DU DÉCOR -------------------------------------------------------------------------------------------
-- Le serveur pose l'attribut « T » (clé|arguments) ; le texte est écrit ici, dans la langue du joueur.
local function fill(label: Instance)
	if not label:IsA("TextLabel") then
		return
	end
	local parts = string.split(label:GetAttribute("T") or "", "|")
	local key = parts[1]
	if key == "roomSign" then
		local icons = {}
		for _, name in string.split(parts[3] or "", ",") do
			table.insert(icons, Texts.ICONS[name] or "")
		end
		label.Text = tr("room", parts[2]) .. "  " .. table.concat(icons, " ")
	elseif #parts > 1 then
		label.Text = tr(key, tonumber(parts[2]) or parts[2])
	else
		label.Text = tr(key)
	end
end
CollectionService:GetInstanceAddedSignal("T"):Connect(fill)
for _, label in CollectionService:GetTagged("T") do
	fill(label)
end

-- L'ÉCRAN -------------------------------------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "Hud"
gui.ResetOnSpawn = false
gui.AutoLocalize = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local function text(parent: Instance, name: string, size: UDim2, position: UDim2, color: Color3?, maxSize: number?): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Size = size
	label.Position = position
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.Text = ""
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.Parent = label
	if maxSize then
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = maxSize
		limit.Parent = label
	end
	label.Parent = parent
	return label
end

local function box(parent: Instance, name: string, size: UDim2, position: UDim2, color: Color3): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = position
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(20, 20, 30)
	stroke.Parent = frame
	frame.Parent = parent
	return frame
end

-- À gauche, au milieu (en bas à gauche, il y a la manette des téléphones) : les pièces puis les trois niveaux.
local side = Instance.new("Frame")
side.Name = "Side"
side.BackgroundTransparency = 1
side.AnchorPoint = Vector2.new(0, 0.5)
side.Position = UDim2.new(0, 12, 0.5, 0)
side.Size = UDim2.fromOffset(190, 190)
side.Parent = gui

local coinIcon = box(side, "Coin", UDim2.fromOffset(40, 40), UDim2.fromOffset(0, 2), Color3.fromRGB(255, 205, 50))
coinIcon:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)
text(coinIcon, "Sign", UDim2.fromScale(1, 0.8), UDim2.fromScale(0, 0.1), Color3.fromRGB(255, 245, 170)).Text = "$"
local coinsLabel = text(side, "Coins", UDim2.fromOffset(140, 44), UDim2.fromOffset(48, 0), Color3.fromRGB(110, 255, 80))
coinsLabel.TextXAlignment = Enum.TextXAlignment.Left

local STAT_COLORS = { Speed = Color3.fromRGB(60, 170, 255), Jump = Color3.fromRGB(70, 210, 90), Force = Color3.fromRGB(240, 80, 80) }
local statLabels = {}
for i, name in Config.MACHINES do
	local pill = box(side, name, UDim2.fromOffset(170, 36), UDim2.fromOffset(2, 12 + i * 44), STAT_COLORS[name])
	statLabels[name] = text(pill, "Label", UDim2.fromScale(0.92, 0.76), UDim2.fromScale(0.04, 0.12))
end

-- En haut, au milieu : le bandeau de la salle.
local banner = Instance.new("Frame")
banner.Name = "Banner"
banner.BackgroundTransparency = 1
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0, 4)
banner.Size = UDim2.new(0.7, 0, 0, 150)
banner.Visible = false
banner.Parent = gui
local bannerTitle = text(banner, "Title", UDim2.fromScale(1, 0.34), UDim2.fromScale(0, 0), Color3.fromRGB(255, 221, 51), 44)
local bannerHint = text(banner, "Hint", UDim2.fromScale(1, 0.2), UDim2.fromScale(0, 0.34), nil, 24)
local bannerTimer = text(banner, "Timer", UDim2.fromScale(1, 0.4), UDim2.fromScale(0, 0.55), nil, 58)

-- La jauge du plafond : pleine = il est tout en haut, vide = il écrase.
local gauge = box(gui, "Ceiling", UDim2.fromOffset(300, 30), UDim2.new(0.5, -150, 0, 160), Color3.fromRGB(40, 44, 56))
gauge.Visible = false
local gaugeFill = Instance.new("Frame")
gaugeFill.Name = "Fill"
gaugeFill.BorderSizePixel = 0
gaugeFill.Size = UDim2.fromScale(0, 1)
gaugeFill.BackgroundColor3 = Color3.fromRGB(240, 80, 80)
Instance.new("UICorner", gaugeFill).CornerRadius = UDim.new(0, 8)
gaugeFill.Parent = gauge
local gaugeLabel = text(gauge, "Label", UDim2.fromScale(1, 0.84), UDim2.fromScale(0, 0.08))
gaugeLabel.ZIndex = 2

-- Le gros bouton pour repousser le plafond (ou la touche E), à droite.
local pushButton = Instance.new("TextButton")
pushButton.Name = "Push"
pushButton.AnchorPoint = Vector2.new(1, 0.5)
pushButton.Position = UDim2.new(1, -24, 0.42, 0)
pushButton.Size = UDim2.fromOffset(150, 150)
pushButton.BackgroundColor3 = Color3.fromRGB(255, 200, 40)
pushButton.Text = ""
pushButton.AutoButtonColor = true
pushButton.Visible = false
Instance.new("UICorner", pushButton).CornerRadius = UDim.new(1, 0)
local pushStroke = Instance.new("UIStroke")
pushStroke.Thickness = 5
pushStroke.Color = Color3.fromRGB(20, 20, 30)
pushStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
pushStroke.Parent = pushButton
pushButton.Parent = gui
text(pushButton, "Label", UDim2.fromScale(0.86, 0.34), UDim2.fromScale(0.07, 0.2)).Text = tr("push")
text(pushButton, "Key", UDim2.fromScale(0.5, 0.3), UDim2.fromScale(0.25, 0.54), Color3.fromRGB(40, 44, 56)).Text = "E"
pushButton.Key.UIStroke.Color = Color3.new(1, 1, 1)

local pushEvent = ReplicatedStorage:WaitForChild("Push")
local function push()
	if not pushButton.Visible then
		return
	end
	pushEvent:FireServer()
	pushButton.Size = UDim2.fromOffset(134, 134)
	TweenService:Create(pushButton, TweenInfo.new(0.08), { Size = UDim2.fromOffset(150, 150) }):Play()
end
pushButton.Activated:Connect(push)
UserInputService.InputBegan:Connect(function(input, typing)
	if not typing and (input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonX) then
		push()
	end
end)

-- Les messages, au milieu de l'écran.
local toast = text(gui, "Toast", UDim2.new(0.8, 0, 0, 54), UDim2.new(0.1, 0, 0.3, 0), Color3.fromRGB(110, 255, 80), 40)
toast.Visible = false
local toastId = 0
local function showToast(message: string, color: Color3?)
	toastId += 1
	local id = toastId
	toast.Text = message
	toast.TextColor3 = color or Color3.fromRGB(110, 255, 80)
	toast.TextTransparency = 0
	toast.UIStroke.Transparency = 0
	toast.Visible = true
	task.delay(3, function()
		if id ~= toastId then
			return
		end
		local info = TweenInfo.new(0.5)
		TweenService:Create(toast, info, { TextTransparency = 1 }):Play()
		TweenService:Create(toast.UIStroke, info, { Transparency = 1 }):Play()
	end)
end

local RED = Color3.fromRGB(255, 90, 90)
ReplicatedStorage:WaitForChild("Notify").OnClientEvent:Connect(function(key: string, a, b)
	if key == "win" then
		showToast(tr("win", a, num(b)))
	elseif key == "half" then
		showToast(tr("half", num(a), b))
	elseif key == "bought" then
		showToast(tr("bought", tr(a), b))
	elseif key == "poor" then
		showToast(tr("poor", num(a)), RED)
	elseif key == "shortcutLocked" then
		showToast(tr("shortcutLocked", a), RED)
	elseif key == "finished" then
		task.delay(3.2, showToast, tr("finished", a), Color3.fromRGB(255, 221, 51))
	end
end)

-- PIÈCES, NIVEAUX, MACHINES ET BOUTONS ----------------------------------------------------------------------------
local gym = workspace:WaitForChild("Gym")

local function refreshPrompt(prompt: ProximityPrompt)
	local kind = prompt:GetAttribute("Kind")
	if kind == "Machine" then
		local name = prompt:GetAttribute("Machine")
		local price = Config.price(player:GetAttribute(name) or 1)
		prompt.ObjectText = tr(name)
		prompt.ActionText = if price then tr("upgrade", num(price)) else tr("maxed")
	elseif kind == "Shortcut" then
		prompt.ActionText = tr("shortcutGo", prompt:GetAttribute("Cleared") + 1)
	elseif kind == "Back" then
		prompt.ActionText = tr("back")
	end
end

local function refresh()
	coinsLabel.Text = num(player:GetAttribute("Coins") or 0)
	for _, name in Config.MACHINES do
		local level = player:GetAttribute(name) or 1
		statLabels[name].Text = tr("stat" .. name) .. "  " .. level
		local model = gym:FindFirstChild(name)
		local label = model and model.PrimaryPart and model.PrimaryPart:FindFirstChild("Label")
		if label then
			local price = Config.price(level)
			label.Title.Text = tr(name)
			label.Level.Text = tr("level", level, Config.MAX_LEVEL)
			label.Info.Text = if price then tr("next", num(price)) else tr("max")
		end
	end
	for _, prompt in workspace:GetDescendants() do
		if prompt:IsA("ProximityPrompt") then
			refreshPrompt(prompt)
		end
	end
end
player.AttributeChanged:Connect(function(name)
	if name ~= "Room" then
		refresh()
	end
end)
workspace.DescendantAdded:Connect(function(item)
	if item:IsA("ProximityPrompt") then
		task.defer(refreshPrompt, item)
	end
end)
refresh()

-- LE BANDEAU DE LA SALLE ----------------------------------------------------------------------------------------
local roomsFolder = workspace:WaitForChild("Rooms")
RunService.RenderStepped:Connect(function()
	local index = player:GetAttribute("Room") or 0
	local folder = index > 0 and roomsFolder:FindFirstChild("Room" .. index)
	local state = folder and folder:GetAttribute("State")
	if not folder or state == "Idle" then
		banner.Visible = false
		gauge.Visible = false
		pushButton.Visible = false
		return
	end
	local left = math.max(0, math.ceil(folder:GetAttribute("Ends") - workspace:GetServerTimeNow()))
	local titles, hints = {}, {}
	for _, name in string.split(folder:GetAttribute("Events"), ",") do
		table.insert(titles, Texts.ICONS[name] .. " " .. tr(name))
		table.insert(hints, tr("hint" .. name))
	end
	banner.Visible = true
	if state == "Countdown" then
		bannerTitle.Text = tr("room", index) .. "  " .. table.concat(titles, "  ")
		bannerHint.Text = table.concat(hints, "  •  ")
		bannerTimer.Text = tr("prepare", left)
		bannerTimer.TextColor3 = Color3.new(1, 1, 1)
	elseif state == "Event" then
		bannerTitle.Text = table.concat(titles, "  ")
		bannerHint.Text = table.concat(hints, "  •  ")
		bannerTimer.Text = tostring(left)
		-- Salle de la mélodie : où on en est.
		local phase, round, rounds, index, length = string.match(folder:GetAttribute("Melody") or "", "^(%a+)|(%d+)|(%d+)|(%d+)|(%d+)$")
		if phase == "Play" then
			bannerHint.Text = tr("melodyPlay", index, length, round, rounds)
		elseif phase then
			bannerHint.Text = tr("melodyShow", round, rounds)
		end
		bannerTimer.TextColor3 = if left <= 10 then Color3.fromRGB(110, 255, 80) else Color3.new(1, 1, 1)
	else
		bannerTitle.Text = tr("doorOpen")
		bannerHint.Text = ""
		bannerTimer.Text = ""
	end

	local need = folder:GetAttribute("Need") or 0
	gauge.Visible = state == "Event" and need > 0
	pushButton.Visible = gauge.Visible and folder:GetAttribute("Pushing") == true
	if gauge.Visible then
		local left = math.clamp(folder:GetAttribute("Ceiling") or 1, 0, 1)
		gaugeFill.Size = UDim2.fromScale(left, 1)
		gaugeFill.BackgroundColor3 = if left >= 0.5 then Color3.fromRGB(70, 210, 90) else Color3.fromRGB(240, 80, 80)
		gaugeLabel.Text = if pushButton.Visible then tr("pushKey") else tr("ceiling")
	end
end)

-- LES ŒUFS ET LES ANIMAUX -----------------------------------------------------------------------------------------
require(script.Parent.Animals)({ gui = gui, side = side, text = text, box = box, tr = tr, num = num, lang = lang, showToast = showToast })

-- LE TRAMPOLINE -------------------------------------------------------------------------------------------------
local function bouncy(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	part.Touched:Connect(function(hit)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and hit:IsDescendantOf(character) and root.AssemblyLinearVelocity.Y < 5 and root.Position.Y > part.Position.Y then
			local velocity = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(velocity.X, 80, velocity.Z)
		end
	end)
end
CollectionService:GetInstanceAddedSignal("Bounce"):Connect(bouncy)
for _, part in CollectionService:GetTagged("Bounce") do
	bouncy(part)
end

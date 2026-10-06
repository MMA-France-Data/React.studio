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
-- Un gros nombre en court : 950 -> « 950 », 12 500 -> « 12,5K », 2 400 000 000 -> « 2,4B ».
local function compact(value: number): string
	for _, unit in { { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } } do
		if value >= unit[1] then
			local short = math.floor(value / unit[1] * 10) / 10
			local digits = if short == math.floor(short) then string.format("%d", short) else string.format("%.1f", short)
			return (if lang == "fr" then (digits:gsub("%.", ",")) else digits) .. unit[2]
		end
	end
	return num(value)
end

-- LES TEXTES DU DÉCOR -------------------------------------------------------------------------------------------
-- Le serveur pose l'attribut « T » (clé|arguments) ; le texte est écrit ici, dans la langue du joueur.
local function fill(label: Instance)
	if not label:IsA("TextLabel") then
		return
	end
	local parts = string.split(label:GetAttribute("T") or "", "|")
	local key = parts[1]
	if key == "plot" then
		-- Le panneau d'un espace : le nom de son joueur, écrit par Animals.luau.
		return
	elseif key == "roomSign" then
		local icons = {}
		for _, name in string.split(parts[3] or "", ",") do
			table.insert(icons, Texts.ICONS[name] or "")
		end
		local text = tr("room", parts[2]) .. "  " .. table.concat(icons, " ")
		-- 2e ligne : les points de stat conseillés pour réussir la salle (« Vitesse 500 recommandé »).
		local needs = {}
		for name, level in string.gmatch(parts[4] or "", "(%a+):(%d+)") do
			table.insert(needs, tr("stat" .. name) .. " " .. compact(Config.pointsFor(tonumber(level))))
		end
		if #needs > 0 then
			text ..= "\n" .. tr("recommended", table.concat(needs, ", "))
		end
		-- Le texte de base est gardé : une ligne s'y ajoute quand la salle a le bonus de chance.
		label:SetAttribute("Base", text)
		label:SetAttribute("RoomIndex", tonumber(parts[2]))
		label.Text = text
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

-- Ce que rapportent les familiers, sous les pièces.
local incomeLabel = text(side, "Income", UDim2.fromOffset(140, 18), UDim2.fromOffset(48, 38), Color3.fromRGB(255, 221, 51))
incomeLabel.TextXAlignment = Enum.TextXAlignment.Left
incomeLabel.UIStroke.Thickness = 1.5
incomeLabel.Visible = false

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
		showToast(tr("win", a))
	elseif key == "wireCut" then
		showToast(tr("wireCut"))

	elseif key == "maxed" then
		showToast(tr("max"), Color3.fromRGB(255, 221, 51))
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
		-- Seules les machines de son espace servent au joueur.
		prompt.Enabled = prompt:GetAttribute("Plot") == player:GetAttribute("Plot")
		prompt.ObjectText = tr(name)
		prompt.ActionText = if player:GetAttribute("Workout") == name then tr("stopTraining") else tr("train")
	elseif kind == "MachineUpgrade" then
		-- Le panneau « Améliorer » d'une machine.
		local name = prompt:GetAttribute("Machine")
		local price = Config.price(player:GetAttribute(name .. "Machine") or 1)
		prompt.Enabled = prompt:GetAttribute("Plot") == player:GetAttribute("Plot") and price ~= nil
		prompt.ObjectText = tr(name)
		prompt.ActionText = if price then tr("upgradeGo", num(price)) else tr("max")
	elseif kind == "Shortcut" then
		prompt.ActionText = tr("shortcutGo", prompt:GetAttribute("Cleared") + 1)
	elseif kind == "Back" then
		prompt.ActionText = tr("back")
	elseif kind == "Bomb" then
		prompt.ObjectText = tr("bombName")
		prompt.ActionText = tr("defuse")
	end
end

local function refreshCoins()
	coinsLabel.Text = num(player:GetAttribute("Coins") or 0)
	local income = player:GetAttribute("Income") or 0
	incomeLabel.Visible = income > 0
	incomeLabel.Text = tr("income", if income == math.floor(income) then num(income) else (string.format("%.1f", income):gsub("%.", if lang == "fr" then "," else ".")))
end

-- Les trois stats, en gros nombres.
local function refreshStats()
	for _, name in Config.MACHINES do
		statLabels[name].Text = tr("stat" .. name) .. "  " .. compact(player:GetAttribute(name .. "Points") or 0)
	end
end

local function refresh()
	refreshCoins()
	refreshStats()
	local mine = player:GetAttribute("Plot") or 0
	for _, plot in gym:GetChildren() do
		local index = plot:GetAttribute("Index")
		if not index then
			continue
		end
		-- L'étiquette au-dessus de chaque machine : son nom, et ce qu'elle donne à chaque pas (dans son espace).
		for _, name in Config.MACHINES do
			local level = player:GetAttribute(name .. "Machine") or 1
			local model = plot:FindFirstChild(name)
			local label = model and model.PrimaryPart and model.PrimaryPart:FindFirstChild("Label")
			if label then
				label.Title.Text = tr(name)
				label.Level.Text = if index == mine then tr("perStep", compact(Config.gain(level))) else ""
				label.Info.Text = ""
			end
		end
		-- Le panneau « Améliorer » à côté de chaque machine.
		for _, sign in plot:GetChildren() do
			local name = sign.Name == "UpgradeSign" and sign:GetAttribute("Machine")
			local label = name and sign:FindFirstChild("Label")
			if label then
				local level = player:GetAttribute(name .. "Machine") or 1
				local price = Config.price(level)
				label.Title.Text = if index == mine then tr("improve") else tr(name)
				label.Level.Text = if index ~= mine then "" elseif price then tr("levelUp", level, level + 1) else tr("max")
				label.Button.Visible = index == mine and price ~= nil
				label.Button.Info.Text = if price then num(price) else ""
			end
		end
	end
	for _, prompt in workspace:GetDescendants() do
		if prompt:IsA("ProximityPrompt") then
			refreshPrompt(prompt)
		end
	end
end
local STAT_ATTRIBUTES = { Speed = true, Jump = true, Force = true, SpeedPoints = true, JumpPoints = true, ForcePoints = true }
player.AttributeChanged:Connect(function(name)
	-- Les pièces changent à chaque seconde (le revenu des familiers) et les stats à chaque pas d'entraînement : seule
	-- leur étiquette est refaite.
	if name == "Coins" or name == "Income" then
		refreshCoins()
	elseif STAT_ATTRIBUTES[name] then
		refreshStats()
	elseif name ~= "Room" then
		refresh()
	end
end)
workspace.DescendantAdded:Connect(function(item)
	if item:IsA("ProximityPrompt") then
		task.defer(refreshPrompt, item)
	end
end)
refresh()

-- LA FERMETURE DE LA PORTE ET LE BONUS DE CHANCE --------------------------------------------------------------------
-- Dans le lobby, une ligne en haut de l'écran : la porte fermée et les œufs accélérés, ou la salle qui a le bonus
-- de chance et le temps qu'il reste. Le panneau de cette salle gagne une ligne dorée.
local cycleLabel = text(gui, "Cycle", UDim2.new(0.8, 0, 0, 30), UDim2.new(0.1, 0, 0, 6), Color3.fromRGB(255, 221, 51), 24)
local function shortClock(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end
task.spawn(function()
	local rooms = workspace:WaitForChild("Rooms")
	while true do
		local left = (workspace:GetAttribute("CycleEnds") or 0) - workspace:GetServerTimeNow()
		local luckRoom, luck = workspace:GetAttribute("LuckRoom") or 0, workspace:GetAttribute("Luck") or 1
		cycleLabel.Visible = (player:GetAttribute("Room") or 0) == 0
		if workspace:GetAttribute("CycleState") == "Closed" then
			cycleLabel.Text = tr("cycleClosed", math.max(0, math.ceil(left)), Config.CYCLE.speed)
			cycleLabel.TextColor3 = Color3.fromRGB(255, 90, 90)
		elseif luckRoom > 0 then
			cycleLabel.Text = tr("cycleLuck", luckRoom, (luck - 1) * 100, shortClock(left))
			cycleLabel.TextColor3 = Color3.fromRGB(255, 221, 51)
		else
			cycleLabel.Text = tr("cycleNext", shortClock(left))
			cycleLabel.TextColor3 = Color3.new(1, 1, 1)
		end
		for _, room in rooms:GetChildren() do
			local sign = room:FindFirstChild("Sign")
			local surface = sign and sign:FindFirstChildOfClass("SurfaceGui")
			local label = surface and surface:FindFirstChild("Label")
			local base = label and label:GetAttribute("Base")
			if base then
				local lucky = label:GetAttribute("RoomIndex") == luckRoom and luck > 1
				label.Text = if lucky then base .. "\n★ " .. tr("luckSign", (luck - 1) * 100) else base
				label.TextColor3 = if lucky then Color3.fromRGB(255, 221, 51) else Color3.new(1, 1, 1)
			end
		end
		task.wait(0.5)
	end
end)

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
		table.insert(hints, if name == "Meteors" and folder:GetAttribute("Rush") then tr("hintRush") else tr("hint" .. name))
	end
	banner.Visible = true
	if state == "Countdown" then
		bannerTitle.Text = tr("room", index) .. "  " .. table.concat(titles, "  ")
		bannerHint.Text = table.concat(hints, "  •  ")
		-- Il manque un niveau au joueur pour cette salle : on le lui dit tout de suite, en rouge.
		local missing = {}
		for name, level in string.gmatch(folder:GetAttribute("Needs") or "", "(%a+):(%d+)") do
			if (player:GetAttribute(name) or 0) < tonumber(level) then
				table.insert(missing, tr("stat" .. name) .. " " .. compact(Config.pointsFor(tonumber(level))))
			end
		end
		bannerHint.TextColor3 = if #missing > 0 then Color3.fromRGB(255, 90, 90) else Color3.new(1, 1, 1)
		if #missing > 0 then
			bannerHint.Text = tr("needs", table.concat(missing, ", "))
		end
		bannerTimer.Text = tr("prepare", left)
		bannerTimer.TextColor3 = Color3.new(1, 1, 1)
	elseif state == "Event" then
		bannerHint.TextColor3 = Color3.new(1, 1, 1)
		bannerTitle.Text = table.concat(titles, "  ")
		bannerHint.Text = table.concat(hints, "  •  ")
		bannerTimer.Text = tostring(left)
		-- Salle de la bombe : le joueur qui a coupé son fil le voit en vert.
		if player:GetAttribute("BombCut") == index then
			bannerHint.Text = tr("wireCut")
			bannerHint.TextColor3 = Color3.fromRGB(110, 255, 80)
		end
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

-- MARCHER ET COURIR -------------------------------------------------------------------------------------------------
-- Le personnage marche ; il court à pleine vitesse tant que la touche Maj est tenue, ou après un appui sur le bouton
-- « COURIR » (un 2e appui le remet à la marche). La pleine vitesse est celle de son niveau de tapis de course.
local runButton = Instance.new("TextButton")
runButton.Name = "Run"
runButton.AnchorPoint = Vector2.new(1, 1)
runButton.Position = UDim2.new(1, -190, 1, -64)
runButton.Size = UDim2.fromOffset(96, 96)
runButton.BackgroundColor3 = Color3.fromRGB(60, 150, 255)
runButton.Text = ""
Instance.new("UICorner", runButton).CornerRadius = UDim.new(1, 0)
local runStroke = Instance.new("UIStroke")
runStroke.Thickness = 4
runStroke.Color = Color3.fromRGB(20, 20, 30)
runStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
runStroke.Parent = runButton
runButton.Parent = gui
text(runButton, "Label", UDim2.fromScale(0.86, 0.36), UDim2.fromScale(0.07, 0.32)).Text = tr("sprint")
local runHeld, runLocked = false, false
runButton.Activated:Connect(function()
	runLocked = not runLocked
end)
UserInputService.InputBegan:Connect(function(input, typing)
	if typing then
		return
	end
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		runHeld = true
	elseif input.KeyCode == Enum.KeyCode.ButtonL3 then
		runLocked = not runLocked
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		runHeld = false
	end
end)
RunService.Heartbeat:Connect(function()
	local running = runHeld or runLocked
	runButton.BackgroundColor3 = if running then Color3.fromRGB(70, 210, 90) else Color3.fromRGB(60, 150, 255)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	-- Pendant un entraînement, le serveur tient le personnage sur la machine (vitesse 0) : on n'y touche pas.
	if humanoid and (player:GetAttribute("Workout") or "") == "" then
		local full = Config.walkSpeed(player:GetAttribute("Speed") or 0)
		humanoid.WalkSpeed = if running then full else full * Config.WALK_RATIO
	end
end)

-- L'ENTRAÎNEMENT SUR UNE MACHINE ------------------------------------------------------------------------------------
-- Pendant l'entraînement (attribut « Workout »), le personnage fait le geste (il court sur le tapis, pousse la barre
-- sur le banc, rebondit sur le trampoline), chaque pas fait s'envoler un « +N » rose, et un bouton permet d'arrêter.
local stopEvent = ReplicatedStorage:WaitForChild("StopTraining")
local stopButton = Instance.new("TextButton")
stopButton.Name = "StopTraining"
stopButton.AnchorPoint = Vector2.new(0.5, 1)
stopButton.Position = UDim2.new(0.5, 0, 1, -120)
stopButton.Size = UDim2.fromOffset(240, 56)
stopButton.BackgroundColor3 = Color3.fromRGB(235, 50, 50)
stopButton.Text = ""
stopButton.Visible = false
Instance.new("UICorner", stopButton).CornerRadius = UDim.new(0, 10)
local stopStroke = Instance.new("UIStroke")
stopStroke.Thickness = 4
stopStroke.Color = Color3.fromRGB(20, 20, 30)
stopStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
stopStroke.Parent = stopButton
stopButton.Parent = gui
text(stopButton, "Label", UDim2.fromScale(0.94, 0.7), UDim2.fromScale(0.03, 0.15)).Text = tr("stopButton")
stopButton.Activated:Connect(function()
	stopEvent:FireServer()
end)

local workoutTrack: AnimationTrack? = nil
local function workoutGesture(machine: string)
	if workoutTrack then
		workoutTrack:Stop(0.2)
		workoutTrack = nil
	end
	-- Les gestes viennent des animations du personnage lui-même (courir, grimper = pousser avec les bras).
	local folderName = if machine == "Speed" then "run" elseif machine == "Force" then "climb" else nil
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	local animate = character and character:FindFirstChild("Animate")
	local holder = folderName and animate and animate:FindFirstChild(folderName)
	local source = holder and holder:FindFirstChildOfClass("Animation")
	if animator and source then
		local ok, track = pcall(function()
			return animator:LoadAnimation(source)
		end)
		if ok and track then
			track.Looped = true
			track.Priority = Enum.AnimationPriority.Action
			track:Play(0.15, 1, 1.3)
			workoutTrack = track
		end
	end
end
player:GetAttributeChangedSignal("Workout"):Connect(function()
	local machine = player:GetAttribute("Workout") or ""
	stopButton.Visible = machine ~= ""
	workoutGesture(machine)
end)

-- Le « +N » rose qui s'envole au-dessus du joueur à chaque pas.
local function gainPopup(amount: number)
	local head = player.Character and player.Character:FindFirstChild("Head")
	if not head then
		return
	end
	local board = Instance.new("BillboardGui")
	board.Name = "StatGain"
	board.Size = UDim2.fromScale(5, 1.5)
	board.StudsOffsetWorldSpace = Vector3.new(math.random() * 3 - 1.5, 2.5, 0)
	board.AlwaysOnTop = true
	board.AutoLocalize = false
	board.Adornee = head
	board.Parent = gui
	local label = text(board, "Label", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Color3.fromRGB(255, 70, 220))
	label.Text = "+" .. compact(amount)
	local info = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(board, info, { StudsOffsetWorldSpace = board.StudsOffsetWorldSpace + Vector3.new(0, 3.5, 0) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1 }):Play()
	TweenService:Create(label.UIStroke, info, { Transparency = 1 }):Play()
	task.delay(1, board.Destroy, board)
end
local lastPoints = {}
for _, name in Config.MACHINES do
	lastPoints[name] = player:GetAttribute(name .. "Points") or 0
	player:GetAttributeChangedSignal(name .. "Points"):Connect(function()
		local points = player:GetAttribute(name .. "Points") or 0
		if points > lastPoints[name] and player:GetAttribute("Workout") == name then
			gainPopup(points - lastPoints[name])
		end
		lastPoints[name] = points
	end)
end

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

-- L'écran du joueur : ses pièces, son niveau et sa barre d'XP, son épée, son équipe ; le bouton d'attaque et
-- l'attaque automatique ; les chiffres qui s'envolent quand on frappe ; les messages ; les portes des zones ; les
-- textes du décor dans sa langue.
-- Les œufs, l'enclos, les familiers et les monstres sont dessinés par Animals.luau ; l'épée et les gestes par Poses.luau.
local CollectionService = game:GetService("CollectionService")
local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Pets = require(ReplicatedStorage.Shared.Pets)
local Texts = require(ReplicatedStorage.Shared.Texts)

local player = Players.LocalPlayer
local lang = if LocalizationService.RobloxLocaleId:lower():sub(1, 2) == "fr" then "fr" else "en"

local function tr(key: string, ...): string
	return Texts.get(lang, key, ...)
end
local function plain(value: number): string
	return Texts.number(lang, value)
end
-- Un gros nombre en court : 950 -> « 950 », 12 500 -> « 12,5K », 2 400 000 000 -> « 2,4B », puis T, Qa, Qi, Sx...
local function compact(value: number): string
	for _, unit in { { 1e27, "Oc" }, { 1e24, "Sp" }, { 1e21, "Sx" }, { 1e18, "Qi" }, { 1e15, "Qa" }, { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } } do
		if value >= unit[1] then
			local short = math.floor(value / unit[1] * 10) / 10
			local digits = if short == math.floor(short) then string.format("%d", short) else string.format("%.1f", short)
			return (if lang == "fr" then (digits:gsub("%.", ",")) else digits) .. unit[2]
		end
	end
	return plain(value)
end
-- Un nombre écrit en entier (1 234 567) ; à partir de 10 millions, en court (les pièces montent très haut).
local function num(value: number): string
	return if value >= 1e7 then compact(value) else plain(value)
end

-- LES TEXTES DU DÉCOR -------------------------------------------------------------------------------------------
-- Le serveur pose l'attribut « T » (clé|arguments) ; le texte est écrit ici, dans la langue du joueur.
local gateSigns = {} -- [étiquette] = numéro de la zone que la porte ouvre
local function fillGate(label: TextLabel, opens: number)
	local zone = Config.ZONES[opens]
	if not zone then
		label.Text = tr("zoneSoon")
		label.TextColor3 = Color3.fromRGB(200, 200, 210)
		return
	end
	local open = (player:GetAttribute("Zone") or 1) >= opens
	label.Text = tr("zoneTitle", opens, tr(zone.theme)) .. "\n" .. tr(if open then "zoneOpenSign" else "zoneLockedSign")
	label.TextColor3 = if open then Color3.fromRGB(110, 255, 80) else Color3.fromRGB(255, 120, 120)
end
local function fill(label: Instance)
	if not label:IsA("TextLabel") then
		return
	end
	local parts = string.split(label:GetAttribute("T") or "", "|")
	local key = parts[1]
	if key == "plot" then
		-- Le panneau d'un espace : le nom de son joueur, écrit par Animals.luau.
		return
	elseif key == "zoneGate" then
		gateSigns[label] = tonumber(parts[2])
		fillGate(label, tonumber(parts[2]) :: number)
	elseif key == "camp" then
		label.Text = tr("campSign", tr(parts[2]), parts[3])
	elseif key == "boss" then
		label.Text = tr("bossSign", tr(parts[2]))
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

-- À gauche, au milieu : les pièces, le niveau et sa barre d'XP, l'épée, l'équipe, la chance.
local side = Instance.new("Frame")
side.Name = "Side"
side.BackgroundTransparency = 1
side.AnchorPoint = Vector2.new(0, 0.5)
side.Position = UDim2.new(0, 12, 0.5, 0)
side.Size = UDim2.fromOffset(240, 250)
side.Parent = gui
local sideScale = Instance.new("UIScale")
sideScale.Parent = side

-- (Les pièces sont dans leur propre cadre : sur téléphone, il monte en haut à droite de l'écran.)
local wallet = Instance.new("Frame")
wallet.Name = "Wallet"
wallet.BackgroundTransparency = 1
wallet.Size = UDim2.fromOffset(190, 58)
wallet.Parent = side
local walletScale = Instance.new("UIScale")
walletScale.Parent = wallet
local coinIcon = box(wallet, "Coin", UDim2.fromOffset(40, 40), UDim2.fromOffset(0, 2), Color3.fromRGB(255, 205, 50))
coinIcon:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)
text(coinIcon, "Sign", UDim2.fromScale(1, 0.8), UDim2.fromScale(0, 0.1), Color3.fromRGB(255, 245, 170)).Text = "$"
local coinsLabel = text(wallet, "Coins", UDim2.fromOffset(140, 44), UDim2.fromOffset(48, 0), Color3.fromRGB(110, 255, 80))
coinsLabel.TextXAlignment = Enum.TextXAlignment.Left
local incomeLabel = text(wallet, "Income", UDim2.fromOffset(140, 18), UDim2.fromOffset(48, 38), Color3.fromRGB(255, 221, 51))
incomeLabel.TextXAlignment = Enum.TextXAlignment.Left
incomeLabel.UIStroke.Thickness = 1.5
incomeLabel.Visible = false

-- Le niveau : une barre qui se remplit avec l'XP.
local levelPill = box(side, "Level", UDim2.fromOffset(200, 38), UDim2.fromOffset(2, 62), Color3.fromRGB(30, 34, 50))
local xpFill = Instance.new("Frame")
xpFill.Name = "Fill"
xpFill.BorderSizePixel = 0
xpFill.BackgroundColor3 = Color3.fromRGB(60, 150, 255)
xpFill.Size = UDim2.fromScale(0, 1)
Instance.new("UICorner", xpFill).CornerRadius = UDim.new(0, 8)
xpFill.Parent = levelPill
local levelLabel = text(levelPill, "Label", UDim2.fromScale(0.94, 0.8), UDim2.fromScale(0.03, 0.1))
levelLabel.ZIndex = 2
-- L'épée (ses dégâts par coup), l'équipe (ses dégâts par seconde) et la chance d'œuf rare.
local pills = {}
for i, item in { { "Sword", Color3.fromRGB(240, 80, 80) }, { "Team", Color3.fromRGB(255, 150, 40) }, { "Luck", Color3.fromRGB(70, 56, 20) } } do
	local pill = box(side, item[1], UDim2.fromOffset(150, 34), UDim2.fromOffset(2, 66 + i * 42), item[2])
	pills[item[1]] = text(pill, "Label", UDim2.fromScale(0.92, 0.78), UDim2.fromScale(0.04, 0.11))
end
pills.Luck.TextColor3 = Color3.fromRGB(255, 221, 51)
pills.Luck.Parent.UIStroke.Color = Color3.fromRGB(255, 221, 51)

local function teamDamage(): number
	local spots = Pets.decode(player:GetAttribute("Spots"))
	local total = 0
	for _, key in string.split(player:GetAttribute("Team") or "", ",") do
		local pet = spots[key]
		if pet and pet.v then
			total += Pets.damageOf(pet)
		end
	end
	return total
end
local function refreshHud()
	coinsLabel.Text = num(player:GetAttribute("Coins") or 0)
	local income = player:GetAttribute("Income") or 0
	incomeLabel.Visible = income > 0
	incomeLabel.Text = tr("income", if income == math.floor(income) then num(income) else (string.format("%.1f", income):gsub("%.", if lang == "fr" then "," else ".")))
	local level, xp, need = player:GetAttribute("Level") or 1, player:GetAttribute("Xp") or 0, player:GetAttribute("XpNeed") or 1
	levelLabel.Text = tr("hudLevel", level) .. "   " .. compact(xp) .. " / " .. compact(need)
	xpFill.Size = UDim2.fromScale(math.clamp(xp / need, 0, 1), 1)
	pills.Sword.Text = tr("hudSword", compact(Config.hitDamage(player:GetAttribute("Sword") or 1, level)))
	pills.Team.Text = tr("hudTeam", compact(teamDamage()))
	pills.Luck.Text = tr("luckShort", player:GetAttribute("PetLuck") or 0)
	for label, opens in gateSigns do
		fillGate(label, opens)
	end
end
player.AttributeChanged:Connect(refreshHud)
refreshHud()

-- L'ÉCRAN ALLÉGÉ DES TÉLÉPHONES : les pièces en haut à droite, le bloc de gauche plus petit, les boutons de droite
-- plus petits, et pas de liste des joueurs. (« PhoneHud » sur le Workspace : pour l'essayer sur un PC.)
local small = false
local function applyHud()
	local view = workspace.CurrentCamera.ViewportSize
	small = workspace:GetAttribute("PhoneHud") == true or (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled) or view.Y < 520
	sideScale.Scale = if small then 0.72 else 1
	wallet.Parent = if small then gui else side
	wallet.AnchorPoint = if small then Vector2.new(1, 0) else Vector2.zero
	wallet.Position = if small then UDim2.new(1, -6, 0, 2) else UDim2.fromOffset(0, 0)
	walletScale.Scale = if small then 0.7 else 1
	for _, name in { "EggButton", "PawButton", "ShopButton" } do
		local button = gui:FindFirstChild(name)
		if button then
			local scale = button:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
			scale.Scale = if small then 0.78 else 1
			scale.Parent = button
		end
	end
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, not small)
	end)
end
workspace:GetAttributeChangedSignal("PhoneHud"):Connect(applyHud)
task.defer(applyHud)
task.delay(3, applyHud)

-- LES MESSAGES --------------------------------------------------------------------------------------------------
local toast = text(gui, "Toast", UDim2.new(0.8, 0, 0, 40), UDim2.new(0.1, 0, 0.24, 0), Color3.fromRGB(110, 255, 80), 34)
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

local RED, GOLD = Color3.fromRGB(255, 90, 90), Color3.fromRGB(255, 221, 51)
ReplicatedStorage:WaitForChild("Notify").OnClientEvent:Connect(function(key: string, a, b)
	if key == "poor" then
		showToast(tr("poor", num(a)), RED)
	elseif key == "levelUp" then
		showToast(tr("levelUp", a), GOLD)
	elseif key == "petLevel" then
		showToast(tr("petLevel", tr(a), b), Color3.fromRGB(120, 200, 255))
	elseif key == "petDown" then
		showToast(tr("petDown", tr(a)), RED)
	elseif key == "eggDrop" then
		local rarity = Pets.RARITIES[b]
		showToast(tr("eggDrop", tr(a), tr(rarity.key)), rarity.color)
	elseif key == "swordUp" then
		showToast(tr("swordUp", a, compact(b)), GOLD)
	elseif key == "swordMax" then
		showToast(tr("swordMax", a), RED)
	elseif key == "teamJoined" then
		showToast(tr("teamJoined", tr(a), compact(b)), GOLD)
	elseif key == "teamLeft" then
		showToast(tr("teamLeft", tr(a)), RED)
	elseif key == "zoneOpen" then
		showToast(tr("zoneOpen", a), GOLD)
	elseif key == "bossDown" then
		showToast(tr("bossDown", tr(a)), GOLD)
	elseif key == "zoneLocked" then
		showToast(tr("zoneLocked"), RED)
	end
end)

-- Le premier conseil, pour un joueur qui débute.
task.delay(6, function()
	if (player:GetAttribute("Level") or 1) == 1 and (player:GetAttribute("Xp") or 0) == 0 then
		showToast(tr("firstHint"), GOLD)
	end
end)

-- LES CHIFFRES QUI S'ENVOLENT -------------------------------------------------------------------------------------
-- Un coup porté : le chiffre des dégâts (blanc pour l'épée, orange pour les familiers). Un monstre battu : ses
-- pièces et son XP.
local CombatVFX = require(script.Parent.CombatVFX)
local SwordVisuals = require(script.Parent.SwordVisuals)
local popups = Instance.new("Folder")
popups.Name = "Popups"
popups.Parent = workspace
-- L'éclat d'un coup qui touche : une gerbe d'étincelles sur le monstre.
local function sparks(position: Vector3, color: Color3, count: number)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Position = position
	anchor.Parent = popups
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 0) })
	emitter.Lifetime = NumberRange.new(0.25, 0.45)
	emitter.Speed = NumberRange.new(14, 26)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 4
	emitter.Rate = 0
	emitter.Parent = anchor
	emitter:Emit(count)
	task.delay(0.8, function()
		anchor:Destroy()
	end)
end
-- Les pièces qui jaillissent d'un monstre battu.
local function coinBurst(position: Vector3)
	for i = 1, 10 do
		local coin = Instance.new("Part")
		coin.Shape = Enum.PartType.Cylinder
		coin.Size = Vector3.new(0.25, 1.1, 1.1)
		coin.Color = Color3.fromRGB(255, 205, 50)
		coin.Material = Enum.Material.Neon
		coin.Anchored = true
		coin.CanCollide = false
		coin.CanQuery = false
		coin.CanTouch = false
		coin.CFrame = CFrame.new(position + Vector3.new(0, 2, 0)) * CFrame.Angles(0, i, math.rad(90))
		coin.Parent = popups
		local angle = i / 10 * math.pi * 2 + math.random()
		local away = Vector3.new(math.cos(angle), 0, math.sin(angle)) * (3 + math.random() * 4)
		-- Elles montent, puis retombent autour du monstre.
		TweenService:Create(coin, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = coin.CFrame + away * 0.5 + Vector3.new(0, 3.5, 0) }):Play()
		task.delay(0.22, function()
			TweenService:Create(coin, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = CFrame.new(position + away + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, i, math.rad(90)) }):Play()
		end)
		task.delay(0.75, function()
			TweenService:Create(coin, TweenInfo.new(0.25), { Transparency = 1 }):Play()
		end)
		task.delay(1.05, function()
			coin:Destroy()
		end)
	end
end
ReplicatedStorage:WaitForChild("Loot").OnClientEvent:Connect(function(position: Vector3, a: number, b: number, kind: string?)
	if kind == "sword" then
		CombatVFX.impact(position, SwordVisuals.tier(player:GetAttribute("Sword") or 1))
	elseif kind == "pet" then
		sparks(position + Vector3.new(0, 2, 0), Color3.fromRGB(255, 150, 60), 6)
	else
		coinBurst(position)
	end
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Position = position + Vector3.new(math.random(-20, 20) / 10, if kind then 5 else 7, math.random(-20, 20) / 10)
	anchor.Parent = popups
	local board = Instance.new("BillboardGui")
	board.Size = if kind then UDim2.fromScale(5, 2) else UDim2.fromScale(12, 2.4)
	board.AlwaysOnTop = true
	board.AutoLocalize = false
	board.Parent = anchor
	local label = text(board, "Label", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), if kind == "pet" then Color3.fromRGB(255, 170, 60) elseif kind then Color3.new(1, 1, 1) else GOLD)
	label.Text = if kind then compact(a) else tr("loot", compact(a), compact(b))
	local info = TweenInfo.new(if kind then 0.7 else 1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(anchor, info, { Position = anchor.Position + Vector3.new(0, 4, 0) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1 }):Play()
	TweenService:Create(label.UIStroke, info, { Transparency = 1 }):Play()
	task.delay(info.Time + 0.1, function()
		anchor:Destroy()
	end)
end)

-- L'ATTAQUE -----------------------------------------------------------------------------------------------------
-- Un clic (ou la touche F, ou le gros bouton sur téléphone) donne un coup d'épée au monstre le plus proche. Le
-- bouton « AUTO » frappe tout seul dès qu'un monstre est à portée.
local attackEvent = ReplicatedStorage:WaitForChild("Attack")
local lastSwing = 0
local function swing()
	if os.clock() - lastSwing >= Config.ATTACK_COOLDOWN then
		lastSwing = os.clock()
		attackEvent:FireServer()
	end
end
local function roundButton(name: string, size: number, position: UDim2, color: Color3, label: string): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.AnchorPoint = Vector2.new(1, 1)
	button.Position = position
	button.Size = UDim2.fromOffset(size, size)
	button.BackgroundColor3 = color
	button.Text = ""
	button.AutoButtonColor = true
	Instance.new("UICorner", button).CornerRadius = UDim.new(1, 0)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = Color3.fromRGB(20, 20, 30)
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = button
	text(button, "Label", UDim2.fromScale(0.86, 0.5), UDim2.fromScale(0.07, 0.25)).Text = label
	button.Parent = gui
	return button
end
local attackButton = roundButton("Attack", 104, UDim2.new(1, -110, 1, -30), Color3.fromRGB(235, 60, 60), "⚔")
local autoButton = roundButton("Auto", 66, UDim2.new(1, -124, 1, -146), Color3.fromRGB(90, 96, 120), tr("auto"))
local auto = false
attackButton.Activated:Connect(swing)
autoButton.Activated:Connect(function()
	auto = not auto
	autoButton.BackgroundColor3 = if auto then Color3.fromRGB(60, 200, 90) else Color3.fromRGB(90, 96, 120)
end)
UserInputService.InputBegan:Connect(function(input, typing)
	if typing then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.F then
		swing()
	end
end)
-- (Pour les tests : « AutoAttack » sur le Workspace met l'attaque automatique.)
workspace:GetAttributeChangedSignal("AutoAttack"):Connect(function()
	auto = workspace:GetAttribute("AutoAttack") == true
	autoButton.BackgroundColor3 = if auto then Color3.fromRGB(60, 200, 90) else Color3.fromRGB(90, 96, 120)
end)
task.spawn(function()
	while true do
		task.wait(0.1)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		-- L attaque automatique ne frappe QUE le monstre deja vise (celui qu on a frappe soi-meme) : quand il est
		-- battu, elle s arrete. Il faut aller chercher le monstre suivant et lui donner le premier coup.
		local target = player:GetAttribute("Target") or 0
		if auto and root and target > 0 then
			for _, part in CollectionService:GetTagged("Monster") do
				if part:GetAttribute("Id") == target and (part:GetAttribute("Hp") or 0) > 0 and (part.Position - root.Position).Magnitude <= Config.ATTACK_REACH + (part:GetAttribute("Scale") or 1) + 2 then
					swing()
					break
				end
			end
		end
	end
end)

-- VOYAGER : deux boutons en haut de l'écran. « BASE » ramène dans son espace (pour poser ses œufs, la forge) ;
-- « ZONE n » pose à l'entrée de la zone la plus lointaine que le joueur a ouverte.
local travelEvent = ReplicatedStorage:WaitForChild("Travel")
local function travelButton(name: string, x: number, color: Color3): (TextButton, TextLabel)
	local button = Instance.new("TextButton")
	button.Name = name
	button.AnchorPoint = Vector2.new(0.5, 0)
	button.Position = UDim2.new(0.5, x, 0, 6)
	button.Size = UDim2.fromOffset(132, 40)
	button.BackgroundColor3 = color
	button.Text = ""
	Instance.new("UICorner", button).CornerRadius = UDim.new(0, 8)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(20, 20, 30)
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = button
	local label = text(button, "Label", UDim2.fromScale(0.9, 0.76), UDim2.fromScale(0.05, 0.12))
	button.Parent = gui
	return button, label
end
local baseButton, baseLabel = travelButton("ToBase", -72, Color3.fromRGB(50, 190, 80))
local zoneButton, zoneLabel = travelButton("ToZone", 72, Color3.fromRGB(60, 150, 255))
baseLabel.Text = tr("travelBase")
baseButton.Activated:Connect(function()
	travelEvent:FireServer("base")
end)
zoneButton.Activated:Connect(function()
	travelEvent:FireServer(player:GetAttribute("Zone") or 1)
end)
local function refreshTravel()
	zoneLabel.Text = tr("travelZone", player:GetAttribute("Zone") or 1)
end
player:GetAttributeChangedSignal("Zone"):Connect(refreshTravel)
refreshTravel()

-- LES PORTES DES ZONES, LA FORGE ET LE NOM DE LA ZONE -------------------------------------------------------------
local zonesFolder = workspace:WaitForChild("Zones")
local gym = workspace:WaitForChild("Gym")
local currentZone = 0
task.spawn(function()
	while true do
		local unlocked = player:GetAttribute("Zone") or 1
		-- Une porte ne retient que le joueur qui n'a pas battu le boss de la zone d'avant.
		for _, gate in CollectionService:GetTagged("ZoneGate") do
			local open = unlocked >= (gate:GetAttribute("Opens") or 99)
			gate.CanCollide = not open
			gate.Transparency = if open then 1 else 0.25
		end
		local forge = gym:FindFirstChild("Forge")
		local prompt = forge and forge:FindFirstChild("Prompt")
		if prompt then
			prompt.ObjectText = tr("forgeName")
			local sword = player:GetAttribute("Sword") or 1
			prompt.ActionText = if sword >= Config.swordMax(unlocked) then tr("forgeMax", unlocked) else tr("forgeGo", compact(Config.swordPrice(sword)))
		end
		-- Le nom de la zone, quand on y entre.
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			local here = 0
			for _, zone in zonesFolder:GetChildren() do
				if root.Position.Z >= (zone:GetAttribute("ZMin") or 0) and root.Position.Z < (zone:GetAttribute("ZMax") or 0) then
					here = zone:GetAttribute("Index")
				end
			end
			if here ~= currentZone then
				currentZone = here
				showToast(if here == 0 then tr("gym") else tr("zoneTitle", here, tr(Config.ZONES[here].theme)), GOLD)
			end
		end
		task.wait(0.3)
	end
end)

-- LES ŒUFS, LES FAMILIERS ET LES MONSTRES -------------------------------------------------------------------------
require(script.Parent.Animals)({ gui = gui, side = side, text = text, box = box, tr = tr, num = num, lang = lang, showToast = showToast })

-- L'épée dans la main et les gestes des bras (frapper, porter un œuf ou un familier).
require(script.Parent.Poses)()

-- (RunService : gardé pour les tests.)
local _ = RunService

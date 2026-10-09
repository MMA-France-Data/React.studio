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
local Sounds = require(script.Parent.Sounds)
local SwordPalette = require(script.Parent.SwordPalette)
local Draw = require(script.Parent.Draw)

local player = Players.LocalPlayer
-- (L'attribut « Lang » du Workspace force la langue : le tournage de la vidéo se fait en anglais, video.ps1.)
local forcedLang = workspace:GetAttribute("Lang")
local lang = if forcedLang == "fr" or forcedLang == "en" then forcedLang elseif LocalizationService.RobloxLocaleId:lower():sub(1, 2) == "fr" then "fr" else "en"

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
-- Un nombre en court dès mille : 2 500 -> « 2,5K », 200 000 -> « 200K » (sa demande du 08/10 : « refais les
-- nombres comme lui », les abréviations des menus de ChatGPT, dont le reste a été annulé).
local function num(value: number): string
	return if value >= 1e3 then compact(value) else plain(value)
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
	local conquered = (player:GetAttribute("Zone") or 1) >= opens
	local open = conquered or Config.FREE_TRAVEL
	label.Text = tr("zoneTitle", opens, tr(zone.theme)) .. "\n" .. tr(if conquered then "zoneOpenSign" elseif open then "zoneVisitSign" else "zoneLockedSign")
	label.TextColor3 = if conquered then Color3.fromRGB(110, 255, 80) elseif open then Color3.fromRGB(255, 190, 60) else Color3.fromRGB(255, 120, 120)
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
	elseif key == "camp" or key == "boss" then
		-- Le panneau d'un camp : l'animal, son niveau, la chance qu'il lâche son œuf, et la chance de chaque note
		-- de taille (C, B, A, S) pour cet œuf.
		local grades = {}
		for index, grade in Pets.GRADES do
			table.insert(grades, grade .. " " .. Pets.GRADE_ODDS[index] .. "%")
		end
		local title = if key == "boss" then tr("bossSign", tr(parts[2])) else tr("campSign", tr(parts[2]), parts[3])
		label.Text = title .. "\n" .. tr("campEgg", parts[if key == "boss" then 3 else 4] or "?") .. "\n" .. table.concat(grades, "  ")
	else
		label.Text = tr(key)
	end
end
CollectionService:GetInstanceAddedSignal("T"):Connect(fill)
for _, label in CollectionService:GetTagged("T") do
	fill(label)
end

-- LES BANNIÈRES ET LES PANCARTES DES CAMPS ------------------------------------------------------------------------
-- La bannière : « Niveau N » et le portrait de l'animal. La pancarte en bois : pour chaque note (C, B, A, S), la
-- chance de trouver un œuf de cette note en battant un monstre de ce camp.
local GRADE_COLORS = { C = Color3.fromRGB(214, 218, 228), B = Color3.fromRGB(120, 200, 255), A = Color3.fromRGB(120, 255, 120), S = Color3.fromRGB(255, 221, 51) }
local function surface(part: BasePart, face: Enum.NormalId): SurfaceGui
	local board = Instance.new("SurfaceGui")
	board.Face = face
	board.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	board.PixelsPerStud = 40
	board.AutoLocalize = false
	board.LightInfluence = 0
	-- (Range dans l ecran du joueur et accroche au bloc : un portrait en 3D ne s affiche que la.)
	board.Name = "Camp_" .. part.Name
	board.ResetOnSpawn = false
	board.Adornee = part
	board.Parent = player:WaitForChild("PlayerGui")
	return board
end
local function campText(parent: Instance, size: UDim2, position: UDim2, color: Color3?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = size
	label.Position = position
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color or Color3.new(1, 1, 1)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Parent = label
	label.Parent = parent
	return label
end
local function dressFlag(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	local animal, boss = part:GetAttribute("Animal"), part:GetAttribute("Boss") == true
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local board = surface(part, face)
		local title = campText(board, UDim2.fromScale(0.94, 0.2), UDim2.fromScale(0.03, 0.03))
		title.Text = if boss then "👑 BOSS" else tr("lvlLong", part:GetAttribute("Level") or 1)
		local name = campText(board, UDim2.fromScale(0.94, 0.13), UDim2.fromScale(0.03, 0.85), Color3.fromRGB(255, 221, 51))
		name.Text = tr(animal)
		local view = Instance.new("ViewportFrame")
		view.BackgroundTransparency = 1
		view.Size = UDim2.fromScale(0.96, 0.62)
		view.Position = UDim2.fromScale(0.02, 0.23)
		view.Ambient = Color3.fromRGB(215, 215, 225)
		view.LightColor = Color3.new(1, 1, 1)
		view.LightDirection = Vector3.new(1, -1.2, 1)
		view.Parent = board
		local ok, model = pcall(Pets.build, animal, part:GetAttribute("Rank") or 1, true)
		if ok and model then
			model.Parent = view
			local center, size = model:GetBoundingBox()
			local distance = math.max(size.X, size.Y, size.Z) * 1.4
			local camera = Instance.new("Camera")
			camera.FieldOfView = 40
			camera.CFrame = CFrame.lookAt(center.Position + Vector3.new(-distance * 0.55, distance * 0.25, -distance), center.Position)
			camera.Parent = view
			view.CurrentCamera = camera
		end
	end
end
local function dressOdds(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	local egg = part:GetAttribute("Egg") or 0
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local board = surface(part, face)
		local count = #Pets.GRADES
		-- (Le moins rare en haut, le plus rare en bas.)
		for index = 1, count do
			local grade = Pets.GRADES[index]
			local row = Instance.new("Frame")
			row.BackgroundColor3 = Color3.fromRGB(118, 74, 38)
			row.BorderSizePixel = 0
			row.Size = UDim2.fromScale(0.9, 0.9 / count - 0.03)
			row.Position = UDim2.fromScale(0.05, 0.05 + (index - 1) * 0.9 / count)
			Instance.new("UICorner", row).CornerRadius = UDim.new(0.2, 0)
			row.Parent = board
			campText(row, UDim2.fromScale(0.26, 0.86), UDim2.fromScale(0.04, 0.07), GRADE_COLORS[grade]).Text = grade
			local chance = egg * Pets.GRADE_ODDS[index]
			local text = if chance >= 10 then string.format("%d", chance + 0.5) elseif chance >= 1 then string.format("%.1f", chance) else string.format("%.2f", chance)
			campText(row, UDim2.fromScale(0.64, 0.8), UDim2.fromScale(0.32, 0.1)).Text = (if lang == "fr" then (text:gsub("%.", ",")) else text) .. " %"
		end
	end
end
for tag, dress in { CampFlag = dressFlag, CampOdds = dressOdds } do
	CollectionService:GetInstanceAddedSignal(tag):Connect(dress)
	for _, part in CollectionService:GetTagged(tag) do
		task.spawn(dress, part)
	end
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
local luckClick = Instance.new("TextButton")
luckClick.Name = "Explain"
luckClick.BackgroundTransparency = 1
luckClick.Text = ""
luckClick.Size = UDim2.fromScale(1, 1)
luckClick.ZIndex = 3
luckClick.Parent = pills.Luck.Parent
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
-- (Les boutons d'attaque sont créés plus bas : applyHud les range quand ils existent.)
local attackButton: TextButton? = nil
local autoButton: TextButton? = nil
-- LA DISPOSITION DE L'ÉCRAN (refaite sur le modèle que le joueur a montré) :
--   sur PC : le menu (Œufs, Familiers, Boutique) en colonne à gauche, avec le nom sous chaque bouton ; les pièces en
--   bas à gauche, avec l'épée, l'équipe et la chance juste au-dessus ; la grande barre de niveau en bas au milieu ;
--   au-dessus d'elle, les deux actions avec leur touche : F = frapper, R = attaque automatique ;
--   sur téléphone : tout est plus petit et sur les bords, les deux boutons d'attaque ronds sous le pouce droit.
local MENU = { "EggButton", "PawButton", "BagButton", "SwordButton", "ShopButton" }
local function applyHud()
	local view = workspace.CurrentCamera.ViewportSize
	small = workspace:GetAttribute("PhoneHud") == true or (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled) or view.Y < 520
	-- Les pièces.
	wallet.Parent = gui
	wallet.AnchorPoint = if small then Vector2.new(1, 0) else Vector2.new(0, 1)
	-- (Téléphone : tout en haut de l'écran, dans la bande des boutons de Roblox, et décalées vers la gauche pour ne
	-- pas passer sur le bouton des œufs. Sa demande.)
	local top = -game:GetService("GuiService"):GetGuiInset().Y + 4
	wallet.Position = if small then UDim2.new(1, -84, 0, top) else UDim2.new(0, 16, 1, -26)
	local toBase = gui:FindFirstChild("ToBase")
	if toBase then
		toBase.Position = UDim2.new(0.5, 0, 0, if small then top else 0)
	end
	walletScale.Scale = if small then 0.7 else 1.25
	-- L'épée, l'équipe, la chance.
	side.AnchorPoint = if small then Vector2.new(0, 0.5) else Vector2.new(0, 1)
	side.Position = if small then UDim2.new(0, 12, 0.5, 0) else UDim2.new(0, 14, 1, -106)
	side.Size = if small then UDim2.fromOffset(240, 250) else UDim2.fromOffset(380, 34)
	sideScale.Scale = if small then 0.72 else 1
	-- (Les pastilles « épée » et « équipe » sont enlevées, sa demande : l'épée a son bouton et sa fenêtre. Il reste
	-- la chance, sur laquelle on peut cliquer pour savoir ce que c'est.)
	pills.Sword.Parent.Visible = false
	pills.Team.Parent.Visible = false
	local luck = pills.Luck.Parent
	luck.Size = if small then UDim2.fromOffset(150, 34) else UDim2.fromOffset(118, 32)
	luck.Position = if small then UDim2.fromOffset(2, 108) else UDim2.fromOffset(0, 0)
	-- Le cadeau du temps de jeu et les amis, à côté de la chance (en dessous sur téléphone).
	-- (Les pastilles des bonus n'apparaissent que pendant le bonus : on range à la suite celles qui sont visibles.)
	local slot = 0
	for _, name in { "Gift", "Friends", "EvCoins", "EvXp", "EvEggs", "Boost", "PotXp", "PotCoins", "PotDamage" } do
		local pill = side:FindFirstChild(name)
		if pill and pill.Visible then
			slot += 1
			pill.Size = luck.Size
			pill.Position = if small then UDim2.fromOffset(2, 108 + slot * 42) else UDim2.fromOffset(slot * 126, 0)
		end
	end
	-- La barre de niveau.
	levelPill.Parent = if small then side else gui
	levelPill.AnchorPoint = if small then Vector2.zero else Vector2.new(0.5, 1)
	levelPill.Position = if small then UDim2.fromOffset(2, 62) else UDim2.new(0.5, 0, 1, -10)
	levelPill.Size = if small then UDim2.fromOffset(200, 38) else UDim2.fromOffset(540, 32)
	-- Le menu.
	for order, name in MENU do
		local button = gui:FindFirstChild(name)
		if button then
			local scale = button:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
			-- (Téléphone : tous les boutons un peu plus petits que le bouton de saut de Roblox, 70 points.)
			scale.Scale = if small then 0.7 else 0.9
			scale.Parent = button
			button.AnchorPoint = if small then Vector2.new(1, 0.5) else Vector2.new(0, 0.5)
			button.Position = if small then UDim2.new(1, -8, 0.5, -150 + (order - 1) * 52) else UDim2.new(0, 22, 0.5, -210 + (order - 1) * 92)
			local caption = button:FindFirstChild("Caption")
			if caption then
				caption.Visible = not small
			end
		end
	end
	-- Les deux actions.
	for index, button in { attackButton, autoButton } do
		if button then
			local size = if small then 58 else 76
			button.Size = UDim2.fromOffset(size, size)
			button.AnchorPoint = if small then Vector2.new(1, 1) else Vector2.new(0.5, 1)
			if small then
				-- À gauche du bouton de saut : l'attaque en bas, l'automatique juste au-dessus.
				button.Position = if index == 1 then UDim2.new(1, -106, 1, -26) else UDim2.new(1, -106, 1, -92)
			else
				button.Position = UDim2.new(0.5, if index == 1 then -50 else 50, 1, -54)
			end
			button:FindFirstChildOfClass("UICorner").CornerRadius = if small then UDim.new(1, 0) else UDim.new(0, 12)
			button.Key.Visible = not small
		end
	end
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, not small)
		-- (La petite barre de vie de Roblox, en haut a droite : remplacee par celle au-dessus de la tete.)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	end)
end
workspace:GetAttributeChangedSignal("PhoneHud"):Connect(applyHud)
task.defer(applyHud)
task.delay(3, applyHud)

-- MA VIE, AU-DESSUS DE MA TETE (sa demande : « la vie, je la vois mal : au-dessus de la tete, mais uniquement quand
-- je perds de la vie »). Une barre avec le chiffre ; elle disparait des que la vie est de nouveau pleine.
local function lifeBar(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	local head = character:WaitForChild("Head", 10)
	if not humanoid or not head then
		return
	end
	local board = Instance.new("BillboardGui")
	board.Name = "Life"
	board.Size = UDim2.fromScale(5, 0.9)
	board.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
	board.AlwaysOnTop = true
	board.AutoLocalize = false
	board.Adornee = head
	board.Enabled = false
	board.Parent = head
	local back = box(board, "Back", UDim2.fromScale(1, 0.62), UDim2.fromScale(0, 0.19), Color3.fromRGB(30, 30, 40))
	back.UIStroke.Thickness = 2
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BorderSizePixel = 0
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 8)
	fill.Parent = back
	local label = text(back, "Label", UDim2.fromScale(0.96, 0.9), UDim2.fromScale(0.02, 0.05))
	label.ZIndex = 2
	local function refresh()
		local health, max = math.max(0, humanoid.Health), math.max(1, humanoid.MaxHealth)
		local part = math.clamp(health / max, 0, 1)
		board.Enabled = health > 0 and health < max - 0.5
		fill.Size = UDim2.fromScale(part, 1)
		fill.BackgroundColor3 = if part > 0.5 then Color3.fromRGB(80, 220, 90) elseif part > 0.25 then Color3.fromRGB(255, 190, 50) else Color3.fromRGB(240, 70, 70)
		label.Text = compact(math.ceil(health)) .. " / " .. compact(math.floor(max + 0.5))
	end
	humanoid.HealthChanged:Connect(refresh)
	humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(refresh)
	refresh()
end
player.CharacterAdded:Connect(lifeBar)
if player.Character then
	task.spawn(lifeBar, player.Character)
end

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
ReplicatedStorage:WaitForChild("Notify").OnClientEvent:Connect(function(key: string, a, b, c, d)
	if key == "giftReady" then
		showToast(tr("giftReady"), GOLD)
		Sounds.play("level")
	elseif key == "giftCoins" then
		showToast(tr("giftCoins", num(a)), GOLD)
		Sounds.play("coin")
	elseif key == "giftEgg" then
		showToast(tr("giftEgg"), GOLD)
		Sounds.play("hatch")
	elseif key == "friendHere" then
		showToast(tr("friendHere", a, b), GOLD)
		Sounds.play("level")
	elseif key == "giftPotion" then
		showToast(tr("giftPotion", tr("potion_" .. a)), GOLD)
		Sounds.play("hatch")
	elseif key == "potionDrunk" then
		showToast(tr("potionDrunk", tr("potion_" .. a), b), GOLD)
		Sounds.play("level")
	elseif key == "potionRank" then
		showToast(tr("potionRank", tr(a), b), GOLD)
		Sounds.play("level")
	elseif key == "potionMax" then
		showToast(tr("potionMax", tr(a)), RED)
	elseif key == "potionNone" then
		showToast(tr("potionNone"), RED)
	elseif key == "adminSent" or key == "adminStopped" then
		showToast(tr(key), GOLD)
	elseif key == "tutoDone" then
		showToast(tr("tutoDone"), GOLD)
		Sounds.play("level")
	elseif key == "tutoStep" then
		Sounds.play("level")
	elseif key == "storeBought" then
		showToast(tr("storeBought", b, tr("potion_" .. a)), GOLD)
		Sounds.play("hatch")
	elseif key == "passBought" then
		showToast(tr("passBought", tr("pass_" .. a)), GOLD)
		Sounds.play("level")
	end
	if key == "playerLevel" or key == "petLevel" or key == "zoneOpen" then
		Sounds.play("level")
	elseif key == "bossDown" then
		Sounds.play("boss")
	elseif key == "hatched" or key == "hatchedBag" then
		Sounds.play("hatch")
	elseif key == "sold" or key == "placeBought" then
		Sounds.play("coin")
	end
	if key == "poor" then
		showToast(tr("poor", num(a)), RED)
	elseif key == "playerLevel" then
		showToast(tr("playerLevel", a), GOLD)
	elseif key == "bagged" or key == "unbagged" then
		showToast(tr(key, tr(a)), GOLD)
	elseif key == "bagFull" or key == "eggsFull" then
		showToast(tr(key), RED)
	elseif key == "hatchedBag" then
		showToast(tr("hatchedBag", tr(a), tr(Pets.RARITIES[b].key)), GOLD)
	elseif key == "petLevel" then
		showToast(tr("petLevel", tr(a), b), Color3.fromRGB(120, 200, 255))
	elseif key == "fed" then
		showToast(tr("fed", tr(a), tr(b), compact(c), d), GOLD)
	elseif key == "inCombat" then
		showToast(tr("inCombat"), RED)
	elseif key == "eggOut" then
		showToast(tr("eggOut", tr(a)), GOLD)
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

-- LES TROIS CLASSEMENTS de la base (Leaderboards.luau pose le résultat sur chaque panneau, attribut « Rows ») : on
-- les écrit ici, sur les deux faces du panneau.
do
	local MEDALS = { Color3.fromRGB(255, 215, 60), Color3.fromRGB(214, 222, 236), Color3.fromRGB(226, 150, 90) }
	local function duration(seconds: number): string
		local minutes = math.floor(seconds / 60)
		return if minutes >= 60 then string.format("%d h %02d", minutes // 60, minutes % 60) else string.format("%d min", minutes)
	end
	local function draw(board: BasePart)
		local kind = board:GetAttribute("Kind") or "coins"
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local gui = board:FindFirstChild("Top" .. face.Name)
			if not gui then
				gui = Instance.new("SurfaceGui")
				gui.Name = "Top" .. face.Name
				gui.Face = face
				gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
				gui.PixelsPerStud = 40
				gui.LightInfluence = 0
				gui.AutoLocalize = false
				gui.Parent = board
				-- (Marges larges : les deux poteaux passent devant les bords du panneau.)
				text(gui, "Title", UDim2.fromScale(0.78, 0.1), UDim2.fromScale(0.11, 0.02), GOLD)
				for index = 1, 10 do
					local y = 0.135 + (index - 1) * 0.085
					local color = MEDALS[index] or Color3.new(1, 1, 1)
					text(gui, "Rank" .. index, UDim2.fromScale(0.08, 0.07), UDim2.fromScale(0.1, y), color).Text = tostring(index)
					text(gui, "Name" .. index, UDim2.fromScale(0.42, 0.07), UDim2.fromScale(0.19, y), color).TextXAlignment = Enum.TextXAlignment.Left
					text(gui, "Value" .. index, UDim2.fromScale(0.28, 0.07), UDim2.fromScale(0.62, y), color).TextXAlignment = Enum.TextXAlignment.Right
				end
			end
			gui.Title.Text = tr("top_" .. kind)
			local rows = string.split(board:GetAttribute("Rows") or "", string.char(10))
			for index = 1, 10 do
				local name, value = string.match(rows[index] or "", "^(.-)	(%d+)$")
				gui["Rank" .. index].Visible = name ~= nil
				gui["Name" .. index].Text = name or ""
				local number = tonumber(value) or 0
				gui["Value" .. index].Text = if not name then "" elseif kind == "time" then duration(number) else num(number)
			end
		end
	end
	local function watch(board: Instance)
		if board:IsA("BasePart") then
			board:GetAttributeChangedSignal("Rows"):Connect(function()
				draw(board)
			end)
			draw(board)
		end
	end
	CollectionService:GetInstanceAddedSignal("Leaderboard"):Connect(watch)
	for _, board in CollectionService:GetTagged("Leaderboard") do
		watch(board)
	end
end

-- LES RÉGLAGES (la roue dentée, à côté du bouton BASE) : le volume de la musique et celui des sons, de 0 à 100, par
-- pas de 10. Le serveur les garde dans la sauvegarde (attributs « VolMusic » et « VolFx »).
do
	local settingsEvent = ReplicatedStorage:WaitForChild("Settings")
	local gear = Instance.new("TextButton")
	gear.Name = "Gear"
	gear.AnchorPoint = Vector2.new(0.5, 0)
	gear.Size = UDim2.fromOffset(26, 20)
	gear.BackgroundColor3 = Color3.fromRGB(245, 245, 250)
	gear.Font = Enum.Font.FredokaOne
	gear.TextSize = 18
	gear.TextColor3 = Color3.fromRGB(30, 34, 50)
	gear.Text = "⚙"
	Instance.new("UICorner", gear).CornerRadius = UDim.new(0, 8)
	local outline = Instance.new("UIStroke")
	outline.Thickness = 3
	outline.Color = Color3.fromRGB(20, 20, 30)
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	outline.Parent = gear
	gear.Parent = gui
	local function follow()
		local base = gui:FindFirstChild("ToBase")
		if base then
			gear.Position = base.Position + UDim2.fromOffset(52, 0)
		end
	end
	follow()
	task.spawn(function()
		-- (Le bouton BASE est créé plus bas dans ce fichier.)
		gui:WaitForChild("ToBase"):GetPropertyChangedSignal("Position"):Connect(follow)
		follow()
	end)

	-- (Même style que les autres fenêtres : bandeau avec la roue dentée dessinée, fond violet nuit.)
	local panel = box(gui, "SettingsPanel", UDim2.fromOffset(400, 220), UDim2.fromScale(0.5, 0.5), Color3.fromRGB(34, 28, 70))
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Visible = false
	panel.ZIndex = 8
	panel.UIStroke.Color = Draw.DARK
	panel.UIStroke.Thickness = 5
	Draw.shade(panel, 1, 0.6)
	local header = Draw.round(panel, "Header", UDim2.new(1, 16, 0, 58), UDim2.fromOffset(-8, -22), Color3.fromRGB(150, 160, 190), UDim.new(0, 10), 5)
	header.ZIndex = 9
	local headerShade = Instance.new("UIGradient")
	headerShade.Rotation = 90
	headerShade.Color = ColorSequence.new(Color3.fromRGB(225, 230, 245), Color3.fromRGB(130, 140, 170))
	headerShade.Parent = header
	local settingsTitle = text(header, "Title", UDim2.new(1, -170, 0.86, 0), UDim2.new(0, 100, 0.07, 0), nil, 40)
	settingsTitle.Text = tr("settingsTitle")
	settingsTitle.TextXAlignment = Enum.TextXAlignment.Left
	settingsTitle.UIStroke.Thickness = 4
	settingsTitle.ZIndex = 10
	Draw.icon(header, "gear", UDim2.fromOffset(50, 22), 0.8)
	local function small(parent: Instance, name: string, label: string, position: UDim2, color: Color3): TextButton
		local button = Instance.new("TextButton")
		button.Name = name
		button.Size = UDim2.fromOffset(46, 42)
		button.Position = position
		button.BackgroundColor3 = color
		button.Font = Enum.Font.FredokaOne
		button.TextSize = 28
		button.TextColor3 = Color3.new(1, 1, 1)
		button.Text = label
		button.ZIndex = 10
		Instance.new("UICorner", button).CornerRadius = UDim.new(0, 8)
		local line = Instance.new("UIStroke")
		line.Thickness = 4
		line.Color = Draw.DARK
		line.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		line.Parent = button
		Draw.shade(button, 1, 0.7)
		button.Parent = parent
		return button
	end
	small(header, "Close", "X", UDim2.new(1, -56, 0, 8), Color3.fromRGB(235, 40, 50)).Activated:Connect(function()
		panel.Visible = false
	end)
	for row, info in { { "VolMusic", "settingsMusic", Sounds.DEFAULT_MUSIC }, { "VolFx", "settingsFx", Sounds.DEFAULT_FX } } do
		local y = 62 + (row - 1) * 70
		local name = text(panel, info[1] .. "Name", UDim2.fromOffset(150, 40), UDim2.fromOffset(18, y), nil, 24)
		name.Text = tr(info[2])
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.ZIndex = 9
		local value = text(panel, info[1] .. "Value", UDim2.fromOffset(80, 40), UDim2.fromOffset(222, y), GOLD, 26)
		value.ZIndex = 9
		local function current(): number
			return math.clamp(tonumber(player:GetAttribute(info[1])) or info[3], 0, 100)
		end
		local function show()
			value.Text = current() .. " %"
		end
		for _, step in { -10, 10 } do
			local button = small(panel, info[1] .. (if step < 0 then "Less" else "More"), if step < 0 then "-" else "+", UDim2.fromOffset(if step < 0 then 174 else 308, y), if step < 0 then Color3.fromRGB(200, 70, 70) else Color3.fromRGB(60, 190, 80))
			button.Activated:Connect(function()
				local wanted = math.clamp(current() + step, 0, 100)
				player:SetAttribute(info[1], wanted) -- tout de suite à l'oreille ; le serveur l'enregistre
				settingsEvent:FireServer(info[1], wanted)
			end)
		end
		player:GetAttributeChangedSignal(info[1]):Connect(show)
		show()
	end
	gear.Activated:Connect(function()
		panel.Visible = not panel.Visible
	end)
	-- Le petit clic de tous les boutons de l'écran.
	local function clicky(item: Instance)
		if item:IsA("GuiButton") then
			item.Activated:Connect(function()
				Sounds.play("click")
			end)
		end
	end
	gui.DescendantAdded:Connect(clicky)
	for _, item in gui:GetDescendants() do
		clicky(item)
	end
	Sounds.start()
end

-- LE CADEAU DU TEMPS DE JEU ET LES AMIS (Rewards.luau) : deux boutons à côté de la chance.
--   🎁 : le temps qu'il reste avant le cadeau ; « CADEAU ! » en vert quand il est prêt, un clic le donne.
--   👥 : le bonus d'amis du moment ; un clic ouvre la fenêtre d'invitation de Roblox.
do
	local SocialService = game:GetService("SocialService")
	local claimEvent = ReplicatedStorage:WaitForChild("ClaimGift")
	local RunService = game:GetService("RunService")
	-- (Les dessins : Draw.luau.)
	local DARK = Draw.DARK
	local round, shade, drawGift, drawPeople, drawRays, drawPotion = Draw.round, Draw.shade, Draw.gift, Draw.people, Draw.rays, Draw.potion
	-- L'œuf en 3D (le vrai, celui du jeu) dans un petit cadre.
	local function showEgg(view: ViewportFrame, animal: string, color: Color3)
		if view:GetAttribute("Key") == animal then
			return
		end
		view:SetAttribute("Key", animal)
		view:ClearAllChildren()
		local visuals = ReplicatedStorage:FindFirstChild("EggVisuals")
		local template = visuals and visuals:FindFirstChild(animal)
		local model
		if template and template:IsA("Model") then
			model = template:Clone()
		else
			model = Instance.new("Model")
			local shell = Instance.new("Part")
			shell.Shape = Enum.PartType.Ball
			shell.Size = Vector3.new(2, 2.6, 2)
			shell.Color = color
			shell.Anchored = true
			shell.Parent = model
		end
		model.Parent = view
		local center, size = model:GetBoundingBox()
		local distance = math.max(size.X, size.Y, size.Z) * 1.3
		local camera = Instance.new("Camera")
		camera.FieldOfView = 40
		camera.CFrame = CFrame.lookAt(center.Position + Vector3.new(-distance * 0.55, distance * 0.3, -distance), center.Position)
		camera.Parent = view
		view.CurrentCamera = camera
	end
	local function pillButton(name: string, color: Color3): (TextButton, TextLabel)
		local button = Instance.new("TextButton")
		button.Name = name
		button.Size = UDim2.fromOffset(118, 32)
		button.BackgroundColor3 = color
		button.Text = ""
		button.AutoButtonColor = true
		Instance.new("UICorner", button).CornerRadius = UDim.new(0, 8)
		local outline = Instance.new("UIStroke")
		outline.Thickness = 4
		outline.Color = DARK
		outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		outline.Parent = button
		shade(button, 1, 0.68)
		local label = text(button, "Label", UDim2.new(1, -36, 0.8, 0), UDim2.new(0, 32, 0.1, 0))
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.UIStroke.Thickness = 3
		button.Parent = side
		return button, label
	end
	local gift, giftLabel = pillButton("Gift", Color3.fromRGB(90, 96, 120))
	drawGift(gift, UDim2.fromOffset(17, 15), 0.26, Color3.fromRGB(235, 50, 80))
	local friends, friendsLabel = pillButton("Friends", Color3.fromRGB(60, 120, 220))
	drawPeople(friends, UDim2.fromOffset(17, 16), 0.3)
	-- (La chance, à côté, prend le même relief et le même contour.)
	do
		local luck = side:FindFirstChild("Luck")
		if luck then
			luck.UIStroke.Thickness = 4
			luck.UIStroke.Color = DARK
			luck.BackgroundColor3 = Color3.fromRGB(150, 110, 20)
			shade(luck, 1, 0.65)
		end
	end
	local function clockText(seconds: number): string
		return string.format("%d:%02d", seconds // 60, seconds % 60)
	end
	local function showGift()
		local left = player:GetAttribute("GiftIn")
		if left == nil then
			giftLabel.Text = ""
		elseif (player:GetAttribute("GiftsTaken") or 0) >= #Config.GIFTS then
			-- (Les cadeaux du jour sont tous pris.)
			giftLabel.Text = tr("giftTomorrow")
			gift.BackgroundColor3 = Color3.fromRGB(90, 96, 120)
		elseif left <= 0 then
			giftLabel.Text = tr("giftGo")
			gift.BackgroundColor3 = Color3.fromRGB(50, 200, 80)
		else
			giftLabel.Text = tr("giftWait", clockText(left))
			gift.BackgroundColor3 = Color3.fromRGB(90, 96, 120)
		end
	end
	player:GetAttributeChangedSignal("GiftIn"):Connect(showGift)
	player:GetAttributeChangedSignal("GiftsTaken"):Connect(showGift)
	showGift()
	-- LA FENÊTRE DES CADEAUX (demande du créateur, 09/10 : « une fenêtre où tu vois les récompenses avec le timer ») :
	-- les prochains cadeaux côte à côte, chacun avec ce qu'il donne et le temps de jeu qu'il reste avant de l'avoir.
	-- Le premier de la rangée est le prochain : sa barre devient verte « PRENDRE ! » quand il est prêt.
	local giftPanel = box(gui, "GiftPanel", UDim2.fromOffset(732, 372), UDim2.fromScale(0.5, 0.54), Color3.fromRGB(34, 28, 70))
	giftPanel.AnchorPoint = Vector2.new(0.5, 0.5)
	giftPanel.Visible = false
	giftPanel.ZIndex = 8
	giftPanel.UIStroke.Color = DARK
	giftPanel.UIStroke.Thickness = 5
	shade(giftPanel, 1, 0.6)
	local giftScale = Instance.new("UIScale")
	giftScale.Parent = giftPanel
	local function fitGifts()
		local view = workspace.CurrentCamera.ViewportSize
		giftScale.Scale = math.min(1.3, view.X / 800, view.Y / 470)
	end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitGifts)
	fitGifts()
	local giftHeader = round(giftPanel, "Header", UDim2.new(1, 16, 0, 58), UDim2.fromOffset(-8, -22), Color3.fromRGB(255, 170, 30), UDim.new(0, 10), 5)
	local headerShade = Instance.new("UIGradient")
	headerShade.Rotation = 90
	headerShade.Color = ColorSequence.new(Color3.fromRGB(255, 240, 150), Color3.fromRGB(255, 150, 60))
	headerShade.Parent = giftHeader
	local giftTitle = text(giftHeader, "Title", UDim2.new(1, -190, 0.86, 0), UDim2.new(0, 112, 0.07, 0), nil, 42)
	giftTitle.Text = tr("giftTitle")
	giftTitle.TextXAlignment = Enum.TextXAlignment.Left
	giftTitle.UIStroke.Thickness = 4
	drawGift(giftHeader, UDim2.fromOffset(54, 22), 0.95, Color3.fromRGB(235, 50, 80)).Rotation = -8
	local giftSub = text(giftPanel, "Sub", UDim2.new(1, -40, 0, 26), UDim2.fromOffset(20, 42), Color3.fromRGB(120, 225, 255), 24)
	giftSub.Text = tr("giftSub", #Config.GIFTS, Config.GIFT_EVERY // 60)
	local giftClose = Instance.new("TextButton")
	giftClose.Name = "Close"
	giftClose.Size = UDim2.fromOffset(46, 44)
	giftClose.Position = UDim2.new(1, -56, 0, 7)
	giftClose.BackgroundColor3 = Color3.fromRGB(235, 40, 50)
	giftClose.Font = Enum.Font.FredokaOne
	giftClose.TextSize = 30
	giftClose.TextColor3 = Color3.new(1, 1, 1)
	giftClose.Text = "X"
	Instance.new("UICorner", giftClose).CornerRadius = UDim.new(0, 8)
	local closeLine = Instance.new("UIStroke")
	closeLine.Thickness = 4
	closeLine.Color = DARK
	closeLine.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	closeLine.Parent = giftClose
	shade(giftClose, 1, 0.7)
	giftClose.Parent = giftHeader
	giftClose.Activated:Connect(function()
		giftPanel.Visible = false
	end)
	local GIFT_COLORS = { Color3.fromRGB(50, 200, 80), Color3.fromRGB(235, 50, 80), Color3.fromRGB(110, 80, 255), Color3.fromRGB(255, 140, 30) }
	local giftCards = {}
	local GIFT_CARDS = 4 -- (les quatre prochains, dans le cycle de Config.GIFTS)
	for index = 1, GIFT_CARDS do
		local card = round(giftPanel, "Card" .. index, UDim2.fromOffset(166, 286), UDim2.fromOffset(16 + (index - 1) * 178, 74), Color3.fromRGB(14, 14, 30), UDim.new(0, 10), 4)
		local head = text(card, "Head", UDim2.new(1, -8, 0, 26), UDim2.fromOffset(4, 6), nil, 24)
		local rays = drawRays(card, UDim2.fromOffset(83, 96), Color3.new(1, 1, 1))
		local present = drawGift(card, UDim2.fromOffset(83, 96), 1.12, Color3.new(1, 1, 1))
		-- Ce qu'il y a dedans : l'œuf en 3D, ou une pièce d'or ; et son nom à côté.
		local view = Instance.new("ViewportFrame")
		view.Name = "Egg"
		view.Size = UDim2.fromOffset(62, 62)
		view.Position = UDim2.fromOffset(4, 162)
		view.BackgroundTransparency = 1
		view.Ambient = Color3.fromRGB(215, 215, 225)
		view.LightColor = Color3.new(1, 1, 1)
		view.LightDirection = Vector3.new(1, -1.2, 1)
		view.Parent = card
		local coin = round(card, "Coin", UDim2.fromOffset(46, 46), UDim2.fromOffset(12, 170), Color3.fromRGB(255, 205, 40), UDim.new(0.5, 0), 4)
		shade(coin, 1, 0.75)
		text(coin, "Sign", UDim2.fromScale(0.8, 0.8), UDim2.fromScale(0.1, 0.1), Color3.fromRGB(255, 240, 150)).Text = "$"
		local potionIcon = drawPotion(card, UDim2.fromOffset(35, 193), 0.6, Color3.new(1, 1, 1), "")
		potionIcon.Visible = false
		local reward = text(card, "Reward", UDim2.fromOffset(94, 62), UDim2.fromOffset(66, 162), nil, 26)
		local bar = Instance.new("TextButton")
		bar.Name = "Bar"
		bar.Size = UDim2.new(1, -16, 0, 46)
		bar.Position = UDim2.new(0, 8, 1, -54)
		bar.Text = ""
		bar.BackgroundColor3 = Color3.new(1, 1, 1)
		Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 8)
		local barLine = Instance.new("UIStroke")
		barLine.Thickness = 4
		barLine.Color = DARK
		barLine.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		barLine.Parent = bar
		local barColor = Instance.new("UIGradient")
		barColor.Rotation = 90
		barColor.Parent = bar
		bar.Parent = card
		local barLabel = text(bar, "Label", UDim2.fromScale(0.92, 0.84), UDim2.fromScale(0.04, 0.08), nil, 34)
		barLabel.UIStroke.Thickness = 3.5
		bar.Activated:Connect(function()
			local left = player:GetAttribute("GiftIn") or 1
			local taken = player:GetAttribute("GiftsTaken") or 0
			if index == taken + 1 and left <= 0 then
				claimEvent:FireServer()
			elseif index > taken then
				showToast(tr("giftSoon", clockText(math.max(left, 0) + (index - taken - 1) * Config.GIFT_EVERY)), GOLD)
			end
		end)
		giftCards[index] = { card = card, head = head, rays = rays, present = present, view = view, coin = coin, potion = potionIcon, reward = reward, barColor = barColor, label = barLabel }
	end
	local giftReady, giftNext = false, 1
	local function showGifts()
		if not giftPanel.Visible then
			return
		end
		local step = math.clamp(player:GetAttribute("GiftStep") or 1, 1, #Config.GIFTS)
		local left = math.max(player:GetAttribute("GiftIn") or Config.GIFT_EVERY, 0)
		local zone = math.clamp(player:GetAttribute("Zone") or 1, 1, #Pets.COLLECTIONS)
		-- (Les cartes sont les quatre cadeaux DU JOUR, dans l'ordre : ceux déjà pris, le prochain, ceux d'après.)
		local taken = player:GetAttribute("GiftsTaken") or 0
		local _ = step
		giftReady = left <= 0 and taken < #Config.GIFTS
		giftNext = taken + 1
		if taken >= #Config.GIFTS then
			local back = math.max(0, (player:GetAttribute("GiftReset") or 0) - workspace:GetServerTimeNow())
			giftSub.Text = tr("giftBack", string.format("%d h %02d", back // 3600, back % 3600 // 60))
		else
			giftSub.Text = tr("giftSub", #Config.GIFTS, Config.GIFT_EVERY // 60)
		end
		for index, parts in giftCards do
			local number = index
			local info = Config.GIFTS[number]
			local color = GIFT_COLORS[(number - 1) % #GIFT_COLORS + 1]
			parts.card.BackgroundColor3 = color:Lerp(Color3.fromRGB(10, 10, 26), 0.82)
			parts.head.Text = if index == taken + 1 then tr("giftNext") else tr("giftCard", number)
			parts.head.TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.45)
			for _, ray in parts.rays:GetChildren() do
				ray.BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.5)
			end
			parts.present.Body.BackgroundColor3 = color
			parts.present.Lid.BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.25)
			parts.coin.Visible = info.coins ~= nil
			parts.view.Visible = info.egg ~= nil
			parts.potion.Visible = info.potion ~= nil
			if info.coins then
				parts.reward.Text = tr("giftCardCoins", num(Config.monster(zone, 3).coins * info.coins))
				parts.reward.TextColor3 = GOLD
			elseif info.egg then
				local rarity = Pets.RARITIES[info.egg]
				showEgg(parts.view, Pets.COLLECTIONS[zone][info.egg], rarity.color)
				parts.reward.Text = tr("giftCardEgg", tr(rarity.key))
				parts.reward.TextColor3 = rarity.color
			else
				local look = Draw.POTIONS[info.potion]
				parts.potion.Body.BackgroundColor3 = look.color
				parts.potion.Glyph.Text = look.glyph
				parts.reward.Text = tr("potion_" .. info.potion)
				parts.reward.TextColor3 = look.color:Lerp(Color3.new(1, 1, 1), 0.35)
			end
			local wait = left + (index - taken - 1) * Config.GIFT_EVERY
			if index <= taken then
				parts.label.Text = tr("giftTaken")
				parts.barColor.Color = ColorSequence.new(Color3.fromRGB(120, 130, 170), Color3.fromRGB(70, 76, 110))
			elseif wait <= 0 then
				parts.label.Text = tr("giftTake")
				parts.barColor.Color = ColorSequence.new(Color3.fromRGB(120, 245, 90), Color3.fromRGB(30, 170, 60))
			else
				parts.label.Text = clockText(wait)
				parts.barColor.Color = ColorSequence.new(Color3.fromRGB(255, 80, 80), Color3.fromRGB(190, 25, 45))
			end
		end
	end
	for _, name in { "GiftIn", "GiftStep", "GiftsTaken", "Zone" } do
		player:GetAttributeChangedSignal(name):Connect(showGifts)
	end
	-- (Quand tout est pris, plus rien ne change : on rafraîchit quand même le temps avant demain.)
	task.spawn(function()
		while true do
			task.wait(5)
			showGifts()
		end
	end)
	giftPanel:GetPropertyChangedSignal("Visible"):Connect(showGifts)
	-- Les rayons tournent ; le paquet prêt se dandine pour qu'on le prenne.
	RunService.RenderStepped:Connect(function()
		if not giftPanel.Visible then
			return
		end
		local now = os.clock()
		for index, parts in giftCards do
			parts.rays.Rotation = now * 25 + index * 15
			parts.present.Rotation = if index == giftNext and giftReady then math.sin(now * 9) * 9 else -4
		end
	end)
	gift.Activated:Connect(function()
		giftPanel.Visible = not giftPanel.Visible
	end)
	local function showFriends()
		local bonus = player:GetAttribute("FriendBonus") or 0
		friendsLabel.Text = if bonus > 0 then tr("friendsPill", bonus) else tr("friendsNone")
	end
	player:GetAttributeChangedSignal("FriendBonus"):Connect(showFriends)
	showFriends()
	friends.Activated:Connect(function()
		showToast(tr("friendsInfo", math.floor(Config.FRIEND_BONUS * 100 + 0.5), Config.FRIEND_MAX), GOLD)
		-- La fenêtre d'invitation de Roblox (elle n'existe pas partout : on essaie, sans erreur si elle manque).
		task.spawn(function()
			local ok, can = pcall(function()
				return SocialService:CanSendGameInviteAsync(player)
			end)
			if ok and can then
				pcall(function()
					SocialService:PromptGameInvite(player)
				end)
			end
		end)
	end)
	-- LE MENU DE ROBLOX S'OUVRE (le joueur va peut-être partir) : on prévient le serveur, qui répond par un message
	-- (« stayBonus » la première fois de la journée, « stayBye » ensuite), affiché dans un grand BANDEAU en haut de
	-- l'écran. Et, tant que le bonus d'XP dure, une pastille ⚡ avec le temps qu'il reste.
	local GuiService = game:GetService("GuiService")
	local leavingEvent = ReplicatedStorage:WaitForChild("Leaving")
	local banner = box(gui, "StayBanner", UDim2.new(0.86, 0, 0, 74), UDim2.new(0.5, 0, 0, 44), Color3.fromRGB(28, 34, 62))
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Visible = false
	banner.ZIndex = 20
	banner.UIStroke.Color = GOLD
	banner.UIStroke.Thickness = 4
	local bannerText = text(banner, "Label", UDim2.fromScale(0.96, 0.8), UDim2.fromScale(0.02, 0.1), GOLD, 34)
	bannerText.ZIndex = 21
	local bannerId = 0
	local function showBanner(message: string, color: Color3)
		bannerId += 1
		local id = bannerId
		bannerText.Text = message
		bannerText.TextColor3 = color
		banner.UIStroke.Color = color
		banner.Visible = true
		task.delay(9, function()
			if id == bannerId then
				banner.Visible = false
			end
		end)
	end
	GuiService.MenuOpened:Connect(function()
		leavingEvent:FireServer()
	end)
	ReplicatedStorage:WaitForChild("Notify").OnClientEvent:Connect(function(key: string, a, b)
		if key == "stayBonus" then
			showBanner(tr("stayBonus", a, b), Color3.fromRGB(110, 255, 80))
			Sounds.play("level")
		elseif key == "stayBye" then
			showBanner(tr("stayBye"), GOLD)
		end
	end)
	-- Les pastilles des bonus en cours (le bonus du jour, et les potions bues), avec le temps qu'il reste. Elles
	-- n'apparaissent que pendant le bonus ; applyHud les range à la suite.
	local boosts = {
		{ name = "Boost", attr = "XpBoostUntil", color = Color3.fromRGB(150, 70, 220) },
		{ name = "PotXp", attr = "PotXpUntil", color = Color3.fromRGB(60, 120, 230), potion = "xp" },
		{ name = "PotCoins", attr = "PotCoinsUntil", color = Color3.fromRGB(200, 150, 20), potion = "coins" },
		{ name = "PotDamage", attr = "PotDamageUntil", color = Color3.fromRGB(200, 50, 60), potion = "damage" },
		-- (Les événements de l'admin, pour tout le monde : l'heure de fin est sur workspace. Admin.luau.)
		{ name = "EvCoins", attr = Config.EVENT.coins.attr, color = Color3.fromRGB(230, 60, 150), event = "coins", icon = "coin" },
		{ name = "EvXp", attr = Config.EVENT.xp.attr, color = Color3.fromRGB(230, 60, 150), event = "xp", icon = "potion" },
		{ name = "EvEggs", attr = Config.EVENT.eggs.attr, color = Color3.fromRGB(230, 60, 150), event = "eggs", icon = "egg" },
	}
	for _, info in boosts do
		local pill, label = pillButton(info.name, info.color)
		pill.Visible = false
		if info.potion then
			local look = Draw.POTIONS[info.potion]
			drawPotion(pill, UDim2.fromOffset(17, 16), 0.27, look.color, look.glyph)
		elseif info.event then
			Draw.icon(pill, info.icon, UDim2.fromOffset(17, 16), 0.27, if info.icon == "potion" then Draw.POTIONS.xp.color else nil)
		else
			label.Size = UDim2.new(1, -10, 0.8, 0)
			label.Position = UDim2.new(0, 6, 0.1, 0)
			label.TextXAlignment = Enum.TextXAlignment.Center
		end
		info.pill, info.label = pill, label
	end
	task.spawn(function()
		while true do
			local changed = false
			for _, info in boosts do
				local ends = (if info.event then workspace else player):GetAttribute(info.attr) or 0
				local left = ends - workspace:GetServerTimeNow()
				if info.pill.Visible ~= (left > 0) then
					info.pill.Visible = left > 0
					changed = true
				end
				if left > 0 then
					info.label.Text = if info.potion then tr("potionPill", tr("potionShort_" .. info.potion), clockText(math.floor(left)))
						elseif info.event then tr("potionPill", tr("eventShort_" .. info.event, Config.EVENT[info.event].mult), clockText(math.floor(left)))
						else tr("boostPill", math.floor(Config.STAY_XP * 100 + 0.5), clockText(math.floor(left)))
				end
				-- UN ÉVÉNEMENT COMMENCE (ou court déjà quand on arrive) : le grand bandeau, une fois par événement.
				if info.event and left > 0 and info.told ~= ends then
					info.told = ends
					showBanner(tr("eventStart", tr("event_" .. info.event, Config.EVENT[info.event].mult), math.max(1, math.floor(left / 60 + 0.5))), Color3.fromRGB(255, 120, 200))
					Sounds.play("level")
				end
			end
			if changed then
				applyHud()
			end
			task.wait(1)
		end
	end)

	-- « TON AMI EST EN LIGNE » : de temps en temps, on regarde les amis connectés à Roblox qui ne sont pas dans ce
	-- serveur, et on le dit (une seule fois par ami et par partie).
	task.spawn(function()
		local told = {}
		task.wait(45)
		while true do
			local ok, list = pcall(function()
				return player:GetFriendsOnline(30)
			end)
			if ok and list then
				for _, friend in list do
					local id = friend.VisitorId
					if id and not told[id] and not Players:GetPlayerByUserId(id) then
						told[id] = true
						showToast(tr("friendOnline", friend.DisplayName or friend.UserName or "?", math.floor(Config.FRIEND_BONUS * 100 + 0.5)), GOLD)
						break
					end
				end
			end
			task.wait(240)
		end
	end)
end

-- (Le son quand je perds de la vie.)
do
	local function listen(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid and humanoid:IsA("Humanoid") then
			local before = humanoid.Health
			humanoid.HealthChanged:Connect(function(now: number)
				if now < before - 0.5 then
					Sounds.play("hurt")
				end
				before = now
			end)
		end
	end
	player.CharacterAdded:Connect(listen)
	if player.Character then
		task.spawn(listen, player.Character)
	end
end

-- (Le son d'une nouvelle épée.)
player:GetAttributeChangedSignal("Sword"):Connect(function()
	Sounds.play("sword")
end)

-- LE REVENU HORS LIGNE : au retour, on annonce ce que l'enclos a rapporté pendant l'absence.
local function announceOffline()
	local earned = player:GetAttribute("Offline") or 0
	if earned > 0 then
		local minutes = math.floor((player:GetAttribute("OfflineTime") or 0) / 60)
		local away = if minutes >= 60 then tr("awayHours", math.floor(minutes / 60)) else tr("awayMinutes", minutes)
		for _ = 1, 2 do
			showToast(tr("offline", num(earned), away), GOLD)
			task.wait(3.2)
		end
	end
end
task.spawn(function()
	while not player:GetAttribute("Loaded") do
		task.wait(0.2)
	end
	task.wait(2.5)
	announceOffline()
	player:GetAttributeChangedSignal("Offline"):Connect(announceOffline)
end)

-- LE MINI TUTORIEL des nouveaux joueurs (Tutorial.luau ; attribut « Tutorial » = l'étape, 0 = rien) : l'objectif
-- est écrit dans un cadre en haut de l'écran, le bouton à cliquer est entouré d'un cadre jaune qui bat, et à
-- l'étape 1 un trait jaune part du joueur vers le canard le plus proche.
do
	local RING = Color3.fromRGB(255, 230, 40)
	local frame = box(gui, "Tutorial", UDim2.fromOffset(660, 76), UDim2.new(0.5, 0, 0, 30), Color3.fromRGB(34, 28, 70))
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Visible = false
	frame.ZIndex = 6
	frame.UIStroke.Color = RING
	frame.UIStroke.Thickness = 4
	local frameScale = Instance.new("UIScale")
	frameScale.Parent = frame
	local stepLabel = text(frame, "Step", UDim2.new(1, -20, 0, 20), UDim2.fromOffset(10, 4), RING, 18)
	stepLabel.ZIndex = 7
	local goal = text(frame, "Goal", UDim2.new(1, -24, 0, 46), UDim2.fromOffset(12, 25), nil, 28)
	goal.ZIndex = 7
	-- Le cadre jaune autour du bouton de l'étape.
	local ring = Instance.new("Frame")
	ring.Name = "TutorialRing"
	ring.BackgroundTransparency = 1
	ring.Size = UDim2.new(1, 16, 1, 16)
	ring.Position = UDim2.fromOffset(-8, -8)
	ring.ZIndex = 30
	Instance.new("UICorner", ring).CornerRadius = UDim.new(0, 14)
	local ringLine = Instance.new("UIStroke")
	ringLine.Color = RING
	ringLine.Thickness = 5
	ringLine.Parent = ring
	local function target(step: number): Instance?
		if step == 1 then
			return attackButton
		elseif step == 2 then
			return gui:FindFirstChild("EggButton")
		elseif step == 5 then
			return gui:FindFirstChild("ShopButton")
		elseif step == 6 then
			return side:FindFirstChild("Gift")
		end
		return nil
	end
	-- Le trait jaune de l'étape 1 : du joueur au canard le plus proche.
	local guideFrom, guideTo = Instance.new("Attachment"), Instance.new("Attachment")
	local anchor = Instance.new("Part")
	anchor.Name = "TutorialGuide"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	guideTo.Parent = anchor
	local beam = Instance.new("Beam")
	beam.Attachment0 = guideFrom
	beam.Attachment1 = guideTo
	beam.Color = ColorSequence.new(RING)
	beam.Width0 = 0.7
	beam.Width1 = 0.7
	beam.FaceCamera = true
	beam.LightEmission = 0.6
	beam.Transparency = NumberSequence.new(0.25)
	beam.Enabled = false
	beam.Parent = anchor
	anchor.Parent = workspace
	local function refresh()
		local step = player:GetAttribute("Tutorial") or 0
		frame.Visible = step > 0
		ring.Parent = if step > 0 then target(step) else nil
		if step <= 0 then
			return
		end
		stepLabel.Text = tr("tutoStepTitle", step, Config.TUTORIAL_STEPS)
		if step == 4 then
			local price = Config.swordPrice(1)
			goal.Text = tr("tuto4", num(price), num(math.min(player:GetAttribute("Coins") or 0, price)), num(price))
		else
			goal.Text = tr("tuto" .. step)
		end
		local view = workspace.CurrentCamera.ViewportSize
		frameScale.Scale = math.min(1, view.X / 860)
	end
	for _, name in { "Tutorial", "Coins" } do
		player:GetAttributeChangedSignal(name):Connect(refresh)
	end
	task.spawn(function()
		while true do
			local step = player:GetAttribute("Tutorial") or 0
			if step > 0 then
				refresh() -- (les boutons du menu sont créés après ce bloc : on les retrouve ici)
				ringLine.Thickness = 4 + 3 * math.abs(math.sin(os.clock() * 4))
			end
			-- Le trait vers le canard le plus proche encore debout.
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local nearest, best = nil, math.huge
			if step == 1 and root then
				for _, part in CollectionService:GetTagged("Monster") do
					if part:IsA("BasePart") and part:GetAttribute("Rank") == 1 and (part:GetAttribute("Hp") or 0) > 0 then
						local distance = (part.Position - root.Position).Magnitude
						if distance < best then
							nearest, best = part, distance
						end
					end
				end
			end
			if nearest and root then
				guideFrom.Parent = root
				anchor.Position = nearest.Position
				beam.Enabled = true
			else
				beam.Enabled = false
			end
			task.wait(0.1)
		end
	end)
end

-- LE TUTORIEL DE L'ÉPÉE : dès que le joueur a de quoi payer sa première amélioration, on le lui dit (et on le
-- répète toutes les 20 secondes tant qu'il ne l'a pas achetée).
task.spawn(function()
	while (player:GetAttribute("Sword") or 1) <= 1 do
		task.wait(1)
		if player:GetAttribute("Loaded") and (player:GetAttribute("Sword") or 1) == 1 and (player:GetAttribute("Coins") or 0) >= Config.swordPrice(1) then
			showToast(tr("swordHint", Config.swordPrice(1)), GOLD)
			task.wait(20)
		end
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
		-- Une demi-seconde par terre, puis elles FILENT vers le joueur (où qu'il soit allé entre-temps), et font leur
		-- bruit en arrivant (sa demande du 09/10). Elles partent l'une après l'autre, pour faire un petit ruban.
		task.delay(0.52 + 0.5 + i * 0.025, function()
			local from, started = coin.Position, os.clock()
			local flight
			flight = RunService.RenderStepped:Connect(function()
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				local t = (os.clock() - started) / 0.28
				if not root or t >= 1 then
					flight:Disconnect()
					coin:Destroy()
					if root then
						Sounds.play("coin")
					end
					return
				end
				-- (Lente au départ puis de plus en plus vite, en passant un peu en hauteur.)
				local eased = t * t
				local at = from:Lerp(root.Position, eased) + Vector3.new(0, math.sin(t * math.pi) * 2.5, 0)
				coin.CFrame = CFrame.new(at) * CFrame.Angles(0, t * 12 + i, math.rad(90))
				coin.Size = Vector3.new(0.25, 1.1, 1.1) * (1 - 0.5 * eased)
			end)
		end)
	end
end
ReplicatedStorage:WaitForChild("Loot").OnClientEvent:Connect(function(position: Vector3, a: number, b: number, kind: string?)
	if kind == "sword" then
		CombatVFX.impact(position, SwordVisuals.tier(player:GetAttribute("Sword") or 1))
	elseif kind == "pet" then
		sparks(position + Vector3.new(0, 2, 0), Color3.fromRGB(255, 150, 60), 6)
	else
		-- Le cri du monstre tout de suite ; le bruit des pièces, lui, quand elles arrivent sur le joueur (coinBurst).
		Sounds.play("down")
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
local lastSwing, swings = 0, 0
local function swing()
	-- (Pas de coup d'épée avec un œuf sur la tête ou un familier dans les bras : le clic sert à le poser.)
	if (player:GetAttribute("BagNext") or "") ~= "" or (player:GetAttribute("Held") or "") ~= "" then
		return
	end
	if os.clock() - lastSwing >= Config.ATTACK_COOLDOWN then
		lastSwing = os.clock()
		swings += 1
		Sounds.play(if swings % 3 == 0 then "swingBig" else "swing")
		-- (Le son propre à l'épée, par-dessus : le grognement du tigre pour sa griffe.)
		local voice = Sounds.SWORD_VOICE[SwordPalette.gameOrder[math.clamp(player:GetAttribute("Sword") or 1, 1, #SwordPalette.gameOrder)]]
		if voice then
			Sounds.play(voice)
		end
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
	-- La touche du clavier, en haut à gauche du bouton (sur PC).
	local key = text(button, "Key", UDim2.fromOffset(30, 30), UDim2.fromOffset(-8, -14))
	key.TextXAlignment = Enum.TextXAlignment.Left
	button.Parent = gui
	return button
end
attackButton = roundButton("Attack", 104, UDim2.new(1, -110, 1, -30), Color3.fromRGB(235, 60, 60), "⚔")
autoButton = roundButton("Auto", 66, UDim2.new(1, -124, 1, -146), Color3.fromRGB(90, 96, 120), tr("auto"))
attackButton.Key.Text = "F"
autoButton.Key.Text = "R"
-- L'ATTAQUE AUTOMATIQUE (sa demande : « que je puisse mettre l'attaque auto et faire autre chose sur mon PC ») : le
-- personnage va tout seul jusqu'au monstre le plus proche, le combat, puis passe au suivant. Il ne s'éloigne pas à
-- plus de AUTO_RADIUS de l'endroit où on l'a laissé (là où l'AUTO a été allumé, ou là où on a marché en dernier).
local AUTO_RADIUS = 34
local auto = false
local anchor: Vector3? = nil
-- (walking : l AUTO a lance une marche ; il faut l arreter quand l AUTO s eteint ou se met en pause, sinon le
-- personnage continue tout seul vers le dernier monstre.)
local walking = false
local function halt()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if walking and humanoid and root then
		humanoid:MoveTo(root.Position)
	end
	walking = false
end
local function setAuto(on: boolean)
	auto = on
	if not on then
		halt()
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	anchor = if on and root then root.Position else nil
	autoButton.BackgroundColor3 = if auto then Color3.fromRGB(60, 200, 90) else Color3.fromRGB(90, 96, 120)
end
-- (Pour le tournage de la vidéo : l'attribut « AutoAttack » du Workspace allume ou éteint l'attaque automatique.)
workspace:GetAttributeChangedSignal("AutoAttack"):Connect(function()
	setAuto(workspace:GetAttribute("AutoAttack") == true)
end)
attackButton.Activated:Connect(swing)
autoButton.Activated:Connect(function()
	setAuto(not auto)
end)
-- La touche R allume ou éteint l'attaque automatique.
UserInputService.InputBegan:Connect(function(input, typing)
	if not typing and input.KeyCode == Enum.KeyCode.R then
		setAuto(not auto)
	end
end)
player.CharacterAdded:Connect(function()
	anchor = nil
end)
-- Ce que le joueur demande avec ses touches ou sa manette (rien = le personnage est libre pour l'AUTO).
local controls = nil
task.spawn(function()
	local ok, module = pcall(function()
		return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 10)):GetControls()
	end)
	controls = if ok then module else nil
end)
local function steering(): boolean
	local ok, vector = pcall(function()
		return controls:GetMoveVector()
	end)
	if ok and typeof(vector) == "Vector3" and vector.Magnitude > 0.1 then
		return true
	end
	-- (Au cas ou le module des commandes ne repond pas : les touches du clavier.)
	for _, key in { Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right, Enum.KeyCode.Space } do
		if UserInputService:IsKeyDown(key) then
			return true
		end
	end
	return false
end
-- SE DEPLACER MET L AUTO EN PAUSE : elle ne reprend que quand le joueur est immobile depuis AUTO_PAUSE secondes.
local AUTO_PAUSE = 0.8
local lastSteer = 0
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
	setAuto(workspace:GetAttribute("AutoAttack") == true)
end)
task.spawn(function()
	while true do
		task.wait(0.1)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local busy = (player:GetAttribute("BagNext") or "") ~= "" or (player:GetAttribute("Held") or "") ~= ""
		-- (Jamais dans la base : il n'y a rien à combattre, et le personnage partirait tout seul vers la zone.)
		local zone1 = workspace:FindFirstChild("Zones") and workspace.Zones:FindFirstChild("Zone1")
		local inBase = root ~= nil and root.Position.Z < ((zone1 and zone1:GetAttribute("ZMin")) or 30) + 4
		if inBase then
			anchor = nil
		end
		if auto and root and humanoid and humanoid.Health > 0 and not busy and not inBase then
			if steering() then
				lastSteer = os.clock()
			end
			if os.clock() - lastSteer < AUTO_PAUSE or not anchor then
				-- Le joueur marche lui-même : l'AUTO attend, et repartira d'ici.
				anchor = root.Position
				walking = false
			else
				-- La cible : le monstre déjà visé, sinon le plus proche de soi dans le rayon.
				local wanted = player:GetAttribute("Target") or 0
				local best, bestDistance = nil, math.huge
				for _, part in CollectionService:GetTagged("Monster") do
					if (part:GetAttribute("Hp") or 0) > 0 and (part.Position - anchor).Magnitude <= AUTO_RADIUS then
						local distance = (part.Position - root.Position).Magnitude
						if part:GetAttribute("Id") == wanted then
							best, bestDistance = part, distance
							break
						elseif distance < bestDistance then
							best, bestDistance = part, distance
						end
					end
				end
				if best then
					local reach = Config.ATTACK_REACH + (best:GetAttribute("Scale") or 1) - 1
					local away = Vector3.new(root.Position.X - best.Position.X, 0, root.Position.Z - best.Position.Z)
					if away.Magnitude > reach then
						humanoid:MoveTo(best.Position + away.Unit * (reach - 1.5))
						walking = true
					else
						-- (Face au monstre : un coup donne de dos ne touche pas.)
						if away.Magnitude > 0.5 then
							root.CFrame = CFrame.lookAt(root.Position, root.Position - away)
						end
						swing()
					end
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
-- (Sa demande : plus de bouton « ZONE », et « BASE » deux fois plus petit, collé tout en haut de l'écran.)
zoneButton.Visible = false
baseButton.Size = UDim2.fromOffset(64, 20)
baseButton.Position = UDim2.new(0.5, 0, 0, 0)
luckClick.Activated:Connect(function()
	showToast(tr("luckInfo", player:GetAttribute("PetLuck") or 0), GOLD)
end)
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
			local open = Config.FREE_TRAVEL or unlocked >= (gate:GetAttribute("Opens") or 99)
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
applyHud()

-- L'épée dans la main et les gestes des bras (frapper, porter un œuf ou un familier).
require(script.Parent.Poses)()

-- DANS STUDIO SEULEMENT : le bouton « VISITER » ouvre toutes les zones (pour aller voir les mondes suivants sans
-- battre les boss). Il n existe pas dans le jeu publie.
if RunService:IsStudio() and not workspace:GetAttribute("Filming") then
	task.spawn(function()
		local visit = ReplicatedStorage:WaitForChild("DebugVisit", 15)
		if not visit then
			return
		end
		local button = Instance.new("TextButton")
		button.Name = "Visit"
		button.Position = UDim2.fromOffset(200, 8)
		button.Size = UDim2.fromOffset(190, 34)
		button.BackgroundColor3 = Color3.fromRGB(34, 40, 70)
		button.Font = Enum.Font.FredokaOne
		button.TextSize = 16
		button.TextColor3 = Color3.fromRGB(255, 221, 51)
		button.Text = "VISITER : tout ouvrir"
		Instance.new("UICorner", button).CornerRadius = UDim.new(0, 8)
		button.Parent = gui
		-- LA MOLETTE change d epee (1 a 8), pour les essayer. Elle ne zoome donc plus la camera dans Studio (les
		-- touches I et O zooment toujours). Le nom de l epee s affiche a chaque cran.
		local swap = ReplicatedStorage:WaitForChild("DebugSword", 5)
		if swap then
			local names = { "Fer", "Acier", "Or", "Glace", "Feu", "Foudre", "Feu + glace", "Doubles lames violettes", "(double violette)", "(double violette)", "Griffe du tigre", "(griffe du tigre)", "(griffe du tigre)", "Crâne de hyène, à deux mains", "Météorite", "Mâchoire de T-rex" }
			game:GetService("ContextActionService"):BindActionAtPriority("DebugSword", function(_, _, input)
				swap:FireServer(if input.Position.Z > 0 then 1 else -1)
				return Enum.ContextActionResult.Sink
			end, false, 3000, Enum.UserInputType.MouseWheel)
			player:GetAttributeChangedSignal("Sword"):Connect(function()
				local sword = player:GetAttribute("Sword") or 1
				showToast("Épée " .. sword .. " : " .. (names[sword] or "?"), GOLD)
			end)
		end
		button.Activated:Connect(function()
			visit:FireServer()
			button.Text = "Tout est ouvert"
			showToast("Studio : toutes les zones sont ouvertes", GOLD)
		end)
	end)
end

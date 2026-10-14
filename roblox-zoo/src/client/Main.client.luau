-- L'ÉCRAN DU JOUEUR : en haut, le jour, l'heure, l'argent, la note du zoo et les visiteurs ; les messages ; les « +10 $ »
-- qui s'envolent ; ce qu'on porte (avec « Poser ») ; les conseils du début ; les boutons Personnel, Animaux, Marché et
-- Vue ; le bilan du soir avec le bouton du jour suivant ; le scanner (laser et « bip ») ; la vue à la première
-- personne (sa demande du 14/10 : « on peut mettre en première vue le jeu ? »), avec le bouton Vue pour repasser de dos.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local AnimalModels = require(ReplicatedStorage.Shared.AnimalModels)
local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer
local state = ReplicatedStorage:WaitForChild("ZooState")
local remotes = ReplicatedStorage:WaitForChild("Remotes")

require(script.Parent.AnimalsView)()

-- LE STYLE : du bois sombre, du crème, du vert (les couleurs du zoo).
local WOOD = Color3.fromRGB(58, 44, 34)
local WOOD_LIGHT = Color3.fromRGB(86, 64, 48)
local CREAM = Color3.fromRGB(246, 236, 210)
local GREEN = Color3.fromRGB(88, 170, 84)
local RED = Color3.fromRGB(214, 80, 66)
local GOLD = Color3.fromRGB(250, 200, 70)

local gui = Instance.new("ScreenGui")
gui.Name = "ZooHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")
local scale = Instance.new("UIScale")
scale.Parent = gui
local function rescale()
	local size = workspace.CurrentCamera.ViewportSize
	scale.Scale = math.clamp(math.min(size.X / 1200, size.Y / 700), 0.55, 1.15)
end
rescale()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)

local function round(item: GuiObject, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 12)
	corner.Parent = item
end
local function stroke(item: GuiObject, color: Color3?, thickness: number?)
	local line = Instance.new("UIStroke")
	line.Color = color or Color3.fromRGB(150, 116, 80)
	line.Thickness = thickness or 2
	line.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	line.Parent = item
end
local function frame(parent: Instance, size: UDim2, position: UDim2, color: Color3?): Frame
	local item = Instance.new("Frame")
	item.Size = size
	item.Position = position
	item.BackgroundColor3 = color or WOOD
	item.BorderSizePixel = 0
	item.Parent = parent
	return item
end
local function text(parent: Instance, value: string, size: UDim2, position: UDim2, color: Color3?, font: Enum.Font?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = size
	label.Position = position
	label.Text = value
	label.TextColor3 = color or CREAM
	label.Font = font or Enum.Font.FredokaOne
	label.TextScaled = true
	label.Parent = parent
	return label
end
local function button(parent: Instance, value: string, size: UDim2, position: UDim2, color: Color3?): TextButton
	local item = Instance.new("TextButton")
	item.Size = size
	item.Position = position
	item.BackgroundColor3 = color or GREEN
	item.Text = value
	item.TextColor3 = Color3.new(1, 1, 1)
	item.Font = Enum.Font.FredokaOne
	item.TextScaled = true
	item.AutoButtonColor = true
	item.Parent = parent
	round(item, 10)
	stroke(item, Color3.fromRGB(255, 255, 255), 2)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.18, 0)
	pad.PaddingBottom = UDim.new(0.18, 0)
	pad.PaddingLeft = UDim.new(0.08, 0)
	pad.PaddingRight = UDim.new(0.08, 0)
	pad.Parent = item
	return item
end
local function money(value: number): string
	local digits = tostring(math.floor(math.abs(value) + 0.5))
	local out = digits:reverse():gsub("(%d%d%d)", "%1 "):reverse():gsub("^ ", "")
	return (if value < 0 then "-" else "") .. out .. " $"
end

-- LE BANDEAU DU HAUT ---------------------------------------------------------------------------------------------------
local bar = frame(gui, UDim2.fromOffset(620, 54), UDim2.new(0.5, -310, 0, 8))
round(bar, 14)
stroke(bar)
local dayLabel = text(bar, "", UDim2.fromOffset(150, 30), UDim2.fromOffset(12, 4))
dayLabel.TextXAlignment = Enum.TextXAlignment.Left
local phaseLabel = text(bar, "", UDim2.fromOffset(150, 18), UDim2.fromOffset(12, 32), Color3.fromRGB(200, 186, 150), Enum.Font.GothamBold)
phaseLabel.TextXAlignment = Enum.TextXAlignment.Left
local moneyLabel = text(bar, "", UDim2.fromOffset(170, 40), UDim2.fromOffset(165, 7), GOLD)
local starsLabel = text(bar, "", UDim2.fromOffset(150, 30), UDim2.fromOffset(340, 4), GOLD)
local noteLabel = text(bar, "", UDim2.fromOffset(150, 18), UDim2.fromOffset(340, 32), Color3.fromRGB(200, 186, 150), Enum.Font.GothamBold)
local peopleLabel = text(bar, "", UDim2.fromOffset(120, 24), UDim2.fromOffset(492, 6))
local queueLabel = text(bar, "", UDim2.fromOffset(120, 18), UDim2.fromOffset(492, 32), Color3.fromRGB(200, 186, 150), Enum.Font.GothamBold)

local PHASES = { morning = "on prépare…", open = "ouvert", evening = "fermeture", night = "la nuit" }
local function refreshBar()
	local clock = state:GetAttribute("Clock") or 9
	local hours = math.floor(clock) % 24
	local minutes = math.floor((clock - math.floor(clock)) * 60)
	dayLabel.Text = string.format("Jour %d · %02dh%02d", state:GetAttribute("Day") or 1, hours, minutes)
	local weather = ""
	for _, item in Config.WEATHER do
		if item.id == state:GetAttribute("Weather") then
			weather = " · " .. item.icon .. " " .. item.fr
		end
	end
	phaseLabel.Text = (PHASES[state:GetAttribute("Phase") or "open"] or "") .. weather
	moneyLabel.Text = money(state:GetAttribute("Money") or 0)
	moneyLabel.TextColor3 = if (state:GetAttribute("Money") or 0) < 0 then RED else GOLD
	local stars = state:GetAttribute("Stars") or 0
	local full = math.floor(stars + 0.25)
	starsLabel.Text = string.rep("★", full) .. string.rep("☆", 5 - full)
	noteLabel.Text = string.format("note %.1f / 5", stars)
	peopleLabel.Text = (state:GetAttribute("Visitors") or 0) .. " visiteurs"
	local queue = state:GetAttribute("Queue") or 0
	queueLabel.Text = if queue > 0 then queue .. " au guichet" else "guichet vide"
	queueLabel.TextColor3 = if queue > 0 and (state:GetAttribute("Staff_cashier") or 0) == 0 then Color3.fromRGB(255, 170, 90) else Color3.fromRGB(200, 186, 150)
end
state.AttributeChanged:Connect(refreshBar)
refreshBar()

-- LES MESSAGES ---------------------------------------------------------------------------------------------------------
local toasts = frame(gui, UDim2.fromOffset(520, 200), UDim2.new(0.5, -260, 0, 70))
toasts.BackgroundTransparency = 1
local toastList = Instance.new("UIListLayout")
toastList.Padding = UDim.new(0, 6)
toastList.HorizontalAlignment = Enum.HorizontalAlignment.Center
toastList.SortOrder = Enum.SortOrder.LayoutOrder
toastList.Parent = toasts
local toastCount = 0
local function toast(message: string, color: Color3?)
	toastCount += 1
	local item = frame(toasts, UDim2.fromOffset(500, 36), UDim2.new(), color or WOOD_LIGHT)
	item.LayoutOrder = toastCount
	round(item, 10)
	stroke(item, Color3.fromRGB(255, 255, 255), 1.5)
	local label = text(item, message, UDim2.new(1, -20, 1, -10), UDim2.fromOffset(10, 5))
	label.Font = Enum.Font.GothamBold
	task.delay(4.5, function()
		TweenService:Create(item, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		task.wait(0.45)
		item:Destroy()
	end)
	local children = toasts:GetChildren()
	local frames = {}
	for _, child in children do
		if child:IsA("Frame") then
			table.insert(frames, child)
		end
	end
	if #frames > 4 then
		table.sort(frames, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		frames[1]:Destroy()
	end
end

local STOCK = Config.STOCK
local function stockName(item: string): string
	return if STOCK[item] then STOCK[item].fr else item
end
local MESSAGES = {
	noMoney = function(amount)
		return "Pas assez d'argent (" .. money(amount) .. ")", RED
	end,
	took = function(item, amount)
		local def = STOCK[item]
		if def and def.kind == "shop" then
			return "Carton de " .. string.lower(def.fr) .. " x" .. amount .. " : apporte-le au stand.", nil
		end
		return "Tu portes : " .. stockName(item) .. ".", nil
	end,
	handsFull = function()
		return "Tu portes déjà quelque chose (bouton Poser).", RED
	end,
	outOfStock = function(name)
		return "Plus de " .. string.lower(name) .. " en stock : commande sur l'ordinateur de la réserve !", RED
	end,
	needBox = function()
		return "Apporte ici un carton du quai de livraison.", RED
	end,
	storeFull = function(name)
		return "La réserve est pleine de " .. string.lower(name) .. ".", RED
	end,
	stored = function(name, amount)
		return name .. " rangé (+" .. amount .. ").", GREEN
	end,
	needProduct = function(name)
		return "Il faut un carton de " .. string.lower(name) .. " (réserve, rayon Produits).", RED
	end,
	shopFull = function()
		return "Ce stand est déjà plein.", nil
	end,
	restocked = function(name, amount)
		return "Stand rempli : " .. string.lower(name) .. " +" .. amount .. ".", GREEN
	end,
	toiletsClean = function()
		return "Toilettes propres !", GREEN
	end,
	examined = function(name, disease, med)
		return name .. " a : " .. disease .. ". Il lui faut : " .. med .. " (pharmacie de la réserve).", Color3.fromRGB(200, 120, 40)
	end,
	needMed = function()
		return "Il faut un médicament (pharmacie de la réserve). Examine-le d'abord !", RED
	end,
	wrongMed = function(name)
		return "Le " .. string.lower(name) .. " ne soigne pas cette maladie. Examine-le !", RED
	end,
	ordered = function(count, cost, seconds)
		return "Commande : " .. count .. " carton(s), " .. money(cost) .. ". Le camion arrive dans " .. seconds .. " s.", GREEN
	end,
	delivered = function(count)
		return "Livraison : " .. count .. " carton(s) sur le quai, à côté de la réserve. Range-les !", GOLD
	end,
	staffShortage = function(name)
		return "Ton personnel manque de " .. string.lower(name) .. " : commande-en !", RED
	end,
	shopBuilt = function(name, who)
		return name .. " construit" .. (if who ~= "" then " (" .. who .. ")" else "") .. " ! Apporte-lui des produits.", GREEN
	end,
	toyBought = function(name, place)
		return name .. " installé chez les " .. string.lower(place) .. " !", GREEN
	end,
	weather = function(id)
		for _, item in Config.WEATHER do
			if item.id == id then
				return "Météo : " .. item.icon .. " " .. item.fr .. (if item.about then " — " .. item.about else ""), nil
			end
		end
		return "", nil
	end,
	event = function(id)
		for _, item in Config.EVENTS do
			if item.id == id then
				return "Aujourd'hui : " .. item.fr .. " — " .. item.about, GOLD
			end
		end
		return "", nil
	end,
	inspected = function(grade, amount, score)
		local verdict = if grade == "A" or grade == "B" then GREEN elseif grade == "C" then GOLD else RED
		return "Inspection : note " .. grade .. " (" .. score .. "/100)" .. (if amount > 0 then " : prime de " .. money(amount) elseif amount < 0 then " : amende de " .. money(-amount) else ""), verdict
	end,
	journalist = function(value)
		return "Le journaliste donne " .. value .. "/5 à ton zoo dans son article !", if value >= 3 then GREEN else RED
	end,
	oldDeath = function(name, days)
		return name .. " est mort de vieillesse, à " .. days .. " jours.", nil
	end,
	needFood = function(name)
		return "Il faut du " .. string.lower(name) .. " : va le chercher à la réserve.", RED
	end,
	filled = function(name)
		return "Mangeoire remplie (" .. string.lower(name) .. ").", GREEN
	end,
	spaceBought = function(name, who)
		return name .. " acheté ! (" .. who .. ")", GREEN
	end,
	buildingBought = function(name, who)
		return name .. " construit ! (" .. who .. ")", GREEN
	end,
	sick = function(name, place, hint)
		return name .. " est malade (" .. place .. ", " .. (hint or "") .. ") : examine-le !", RED
	end,
	lost = function(name)
		return name .. " n'a pas été soigné à temps : les vétérinaires de la ville l'ont emmené.", RED
	end,
	treated = function(name, who)
		return name .. " est soigné (" .. who .. ").", GREEN
	end,
	treatedBy = function(name)
		return "Le vétérinaire a soigné : " .. name .. ".", GREEN
	end,
	sold = function(name, price, who)
		return name .. " vendu " .. money(price) .. " (" .. who .. ")", GREEN
	end,
	cantSell = function()
		return "Un animal malade ne se vend pas : soigne-le d'abord.", RED
	end,
	bought = function(name, zoo, who)
		return name .. " acheté au " .. zoo .. (if who ~= "" then " (" .. who .. ")" else ""), GREEN
	end,
	swapped = function(given, received, zoo)
		return "Échange fait : " .. given .. " part au " .. zoo .. ", un " .. received .. " arrive (sang neuf).", GREEN
	end,
	needSpace = function(name)
		return "Il te faut d'abord un espace « " .. name .. " » avec de la place (panneau Parcelle à vendre).", RED
	end,
	offerGone = function()
		return "Cette offre n'est plus là.", RED
	end,
	badName = function()
		return "Ce prénom n'est pas accepté.", RED
	end,
	cantSwap = function()
		return "Il te faut un adulte en bonne santé de la même espèce et du même sexe.", RED
	end,
	consanguine = function(baby)
		return "Un " .. string.lower(baby) .. " CONSANGUIN est né (parents de la même famille) : fais un échange au Marché !", Color3.fromRGB(200, 120, 40)
	end,
	angry = function()
		return "Un visiteur est reparti fâché : personne au guichet !", RED
	end,
	hired = function(role)
		return role .. " embauché !", GREEN
	end,
	fired = function(role)
		return role .. " renvoyé.", nil
	end,
	staffFull = function(role)
		return "Tu as déjà assez de : " .. role, RED
	end,
	morning = function(day, expected)
		return "Jour " .. day .. " : environ " .. expected .. " visiteurs attendus.", nil
	end,
	open = function()
		return "Le zoo ouvre ses portes !", GREEN
	end,
	closing = function()
		return "18 h : le zoo ferme.", nil
	end,
	tutoDone = function()
		return "Bravo, ton zoo est lancé ! Fais-le grandir.", GREEN
	end,
}
remotes:WaitForChild("Notify").OnClientEvent:Connect(function(key, ...)
	local make = MESSAGES[key]
	if make then
		local message, color = make(...)
		toast(message, color)
	end
end)

-- LES « +10 $ » QUI S'ENVOLENT ---------------------------------------------------------------------------------------------
remotes:WaitForChild("Popup").OnClientEvent:Connect(function(position: Vector3, value: string, color: Color3?)
	local anchor = Instance.new("Part")
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	anchor.Position = position
	anchor.Parent = workspace
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromOffset(110, 40)
	board.AlwaysOnTop = true
	board.MaxDistance = 80
	board.Parent = anchor
	local label = text(board, value, UDim2.fromScale(1, 1), UDim2.new(), color or GOLD)
	label.TextStrokeTransparency = 0.2
	TweenService:Create(anchor, TweenInfo.new(1.2), { Position = position + Vector3.new(0, 4, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(1.3, function()
		anchor:Destroy()
	end)
end)

-- CE QU'ON PORTE -----------------------------------------------------------------------------------------------------------
local carry = frame(gui, UDim2.fromOffset(330, 46), UDim2.new(0.5, -165, 1, -120))
round(carry, 12)
stroke(carry)
local carryLabel = text(carry, "", UDim2.fromOffset(210, 30), UDim2.fromOffset(12, 8))
carryLabel.TextXAlignment = Enum.TextXAlignment.Left
local dropButton = button(carry, "Poser", UDim2.fromOffset(90, 34), UDim2.fromOffset(232, 6), RED)
dropButton.Activated:Connect(function()
	remotes.Drop:FireServer()
end)
local function refreshCarry()
	local value = player:GetAttribute("Carry") or ""
	carry.Visible = value ~= ""
	local kind, item = string.match(value, "^(%a+):(%a+)$")
	local amount = player:GetAttribute("CarryAmount") or 0
	local name = stockName(item or "")
	carryLabel.Text = if kind == "box" then "Carton : " .. name .. " x" .. amount
		elseif kind == "product" then "Pour un stand : " .. name .. " x" .. amount
		elseif kind == "med" then "Médicament : " .. name
		else "Ration : " .. name
end
player:GetAttributeChangedSignal("Carry"):Connect(refreshCarry)
player:GetAttributeChangedSignal("CarryAmount"):Connect(refreshCarry)
refreshCarry()

-- LES CONSEILS DU DÉBUT ----------------------------------------------------------------------------------------------
local tips = frame(gui, UDim2.fromOffset(290, 96), UDim2.fromOffset(10, 70))
round(tips, 12)
stroke(tips, GOLD, 2)
local tipsTitle = text(tips, "À FAIRE", UDim2.fromOffset(270, 22), UDim2.fromOffset(10, 6), GOLD)
tipsTitle.TextXAlignment = Enum.TextXAlignment.Left
local tipsText = text(tips, "", UDim2.fromOffset(270, 60), UDim2.fromOffset(10, 30), CREAM, Enum.Font.GothamBold)
tipsText.TextXAlignment = Enum.TextXAlignment.Left
tipsText.TextYAlignment = Enum.TextYAlignment.Top
tipsText.TextWrapped = true
local TIPS = {
	"Des visiteurs arrivent ! Entre dans la cabine du guichet (à l'entrée) : vise le billet du visiteur avec le scanner et clique.",
	"Prends du foin ou du grain à la RÉSERVE (à gauche de l'entrée) et remplis une mangeoire de la mini-ferme. Le stock baisse : commande sur l'ordinateur de la réserve.",
	"Les animaux font des crottes : entre dans la mini-ferme (porte « Personnel ») et ramasse-en une.",
	"Construis un espace (panneau « Parcelle à vendre », en face de la mini-ferme), puis achète ses animaux au Marché.",
	"Embauche quelqu'un (bouton Personnel) : un caissier scanne les billets à ta place.",
}
local function refreshTips()
	local step = state:GetAttribute("Tuto") or 0
	tips.Visible = step >= 1 and step <= #TIPS
	tipsText.Text = TIPS[step] or ""
end
state:GetAttributeChangedSignal("Tuto"):Connect(refreshTips)
refreshTips()

-- LES FENÊTRES ----------------------------------------------------------------------------------------------------------
local openWindow: Frame? = nil
-- raw : le corps est un cadre vide (pour une fenêtre en colonnes), sinon une liste qui défile.
local function window(title: string, width: number, height: number, raw: boolean?): (Frame, any)
	if openWindow then
		openWindow:Destroy()
	end
	local panel = frame(gui, UDim2.fromOffset(width, height), UDim2.new(0.5, -width / 2, 0.5, -height / 2))
	round(panel, 16)
	stroke(panel, GOLD, 3)
	local head = frame(panel, UDim2.new(1, 0, 0, 46), UDim2.new(), WOOD_LIGHT)
	round(head, 16)
	text(head, title, UDim2.new(1, -70, 0, 32), UDim2.fromOffset(16, 7), GOLD)
	local close = button(head, "X", UDim2.fromOffset(38, 34), UDim2.new(1, -46, 0, 6), RED)
	close.Activated:Connect(function()
		panel:Destroy()
		if openWindow == panel then
			openWindow = nil
		end
	end)
	-- (À la première personne, la souris est bloquée au milieu : une fenêtre ouverte la libère.)
	local free = Instance.new("TextButton")
	free.Modal = true
	free.Size = UDim2.fromOffset(0, 0)
	free.BackgroundTransparency = 1
	free.Text = ""
	free.Parent = panel
	if raw then
		local plain = Instance.new("Frame")
		plain.Size = UDim2.new(1, -20, 1, -60)
		plain.Position = UDim2.fromOffset(10, 52)
		plain.BackgroundTransparency = 1
		plain.Parent = panel
		openWindow = panel
		return panel, plain
	end
	local body = Instance.new("ScrollingFrame")
	body.Size = UDim2.new(1, -20, 1, -60)
	body.Position = UDim2.fromOffset(10, 52)
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.ScrollBarThickness = 6
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.CanvasSize = UDim2.new()
	body.Parent = panel
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = body
	openWindow = panel
	return panel, body
end

-- Le personnel : chaque métier, son salaire, combien on en a, Embaucher / Renvoyer.
local function staffWindow()
	local _, body = window("Personnel", 560, 430)
	for index, role in Config.STAFF_ORDER do
		local def = Config.STAFF[role]
		local row = frame(body, UDim2.new(1, -10, 0, 70), UDim2.new(), WOOD_LIGHT)
		row.LayoutOrder = index
		round(row, 10)
		local name = text(row, def.fr, UDim2.fromOffset(220, 26), UDim2.fromOffset(12, 6))
		name.TextXAlignment = Enum.TextXAlignment.Left
		local about = text(row, def.about .. "  (" .. def.salary .. " $ / jour)", UDim2.fromOffset(300, 30), UDim2.fromOffset(12, 34), Color3.fromRGB(210, 196, 160), Enum.Font.GothamBold)
		about.TextXAlignment = Enum.TextXAlignment.Left
		about.TextWrapped = true
		local count = text(row, "", UDim2.fromOffset(50, 30), UDim2.fromOffset(318, 20), GOLD)
		local hire = button(row, "Embaucher", UDim2.fromOffset(104, 30), UDim2.fromOffset(372, 6))
		local fire = button(row, "Renvoyer", UDim2.fromOffset(104, 26), UDim2.fromOffset(372, 40), RED)
		local function refresh()
			count.Text = (state:GetAttribute("Staff_" .. role) or 0) .. "/" .. def.max
		end
		refresh()
		state:GetAttributeChangedSignal("Staff_" .. role):Connect(refresh)
		hire.Activated:Connect(function()
			remotes.Hire:FireServer(role)
		end)
		fire.Activated:Connect(function()
			remotes.Fire:FireServer(role)
		end)
	end
end

local SEX = { m = "♂", f = "♀" }
local MUTED = Color3.fromRGB(210, 196, 160)
local ORANGE = Color3.fromRGB(255, 160, 110)
local function note(body: Instance, order: number, value: string, color: Color3?)
	local label = text(body, value, UDim2.new(1, -10, 0, 40), UDim2.new(), color or MUTED, Enum.Font.GothamBold)
	label.LayoutOrder = order
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	return label
end

-- L'animal en 3D dans un cadre (spin : il tourne doucement).
local spinning = {}
local function preview(parent: GuiObject, species: string, sex: string?, baby: boolean?, size: UDim2?, position: UDim2?, spin: boolean?): ViewportFrame
	local view = Instance.new("ViewportFrame")
	view.Size = size or UDim2.fromOffset(78, 78)
	view.Position = position or UDim2.fromOffset(6, 6)
	view.BackgroundColor3 = Color3.fromRGB(196, 214, 170)
	view.Ambient = Color3.fromRGB(190, 190, 190)
	view.LightColor = Color3.fromRGB(255, 255, 255)
	view.LightDirection = Vector3.new(-1, -1, -1)
	view.Parent = parent
	round(view, 10)
	local model = AnimalModels.build(species, sex or "m", if baby then 0.5 else 1)
	if not model then
		return view
	end
	model:PivotTo(CFrame.new())
	local low, high = AnimalModels.extents(model)
	local height = high - low
	model.Parent = view
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	local center = Vector3.new(0, (low + high) / 2, 0)
	camera.CFrame = CFrame.lookAt(center + Vector3.new(-height * 1.5, height * 0.5, -height * 1.6), center)
	camera.Parent = view
	view.CurrentCamera = camera
	if spin then
		spinning[view] = { camera = camera, center = center, distance = height * 2.3, angle = math.rad(220) }
		view.Destroying:Connect(function()
			spinning[view] = nil
		end)
	end
	return view
end
game:GetService("RunService").RenderStepped:Connect(function(dt)
	for _, item in spinning do
		item.angle += dt * 0.5
		local offset = Vector3.new(math.cos(item.angle), 0.35, math.sin(item.angle)) * item.distance
		item.camera.CFrame = CFrame.lookAt(item.center + offset, item.center)
	end
end)

-- Une barre (santé, faim, bonheur) : 0 à 100.
local function gauge(parent: Instance, label: string, value: number, position: UDim2, width: number, caption: string?)
	local name = text(parent, label, UDim2.fromOffset(110, 20), position, MUTED, Enum.Font.GothamBold)
	name.TextXAlignment = Enum.TextXAlignment.Left
	local back = frame(parent, UDim2.fromOffset(width - 120, 16), position + UDim2.fromOffset(112, 2), Color3.fromRGB(40, 30, 24))
	round(back, 8)
	local fraction = math.clamp(value / 100, 0, 1)
	local fill = frame(back, UDim2.fromScale(fraction, 1), UDim2.new(), if fraction >= 0.66 then GREEN elseif fraction >= 0.4 then GOLD else RED)
	round(fill, 8)
	if caption then
		local small = text(back, caption, UDim2.fromScale(1, 1), UDim2.new(), Color3.new(1, 1, 1), Enum.Font.GothamBold)
		small.TextStrokeTransparency = 0.5
	end
end

-- Le temps du zoo, en jours (comme Zoo.days côté serveur).
local function zooDays(): number
	local clock = state:GetAttribute("Clock") or Config.OPEN_HOUR
	local part = math.clamp((clock - Config.OPEN_HOUR) / (Config.CLOSE_HOUR - Config.OPEN_HOUR), 0, 1)
	return (state:GetAttribute("Day") or 1) + part
end
local function animalName(item: Instance): string
	local def = Config.SPECIES[item:GetAttribute("Species")]
	local sex = item:GetAttribute("Sex")
	if (item:GetAttribute("Growth") or 1) < 1 then
		return def.baby
	end
	return if sex == "m" then def.m else def.f
end
local function habitatOfPlot(plotId: string)
	return Config.HABITAT_BY_ID[state:GetAttribute("Plot_" .. plotId) or ""]
end
-- Un petit bouton en forme d'étiquette (un prénom de la famille, cliquable).
local function chip(parent: Instance, value: string, color: Color3?): TextButton
	local item = Instance.new("TextButton")
	item.AutomaticSize = Enum.AutomaticSize.X
	item.Size = UDim2.fromOffset(0, 26)
	item.BackgroundColor3 = color or WOOD
	item.TextColor3 = CREAM
	item.Font = Enum.Font.GothamBold
	item.TextSize = 15
	item.Text = "  " .. value .. "  "
	item.Parent = parent
	round(item, 8)
	return item
end

-- LA FICHE D'UN ANIMAL (sa demande, 15/10 : « une vraie fiche perso sur chaque animal ») : son prénom (qu'on peut
-- changer), son portrait en 3D qui tourne, son âge, d'où il vient, sa famille (parents, petits, frères et sœurs, on
-- clique pour voir leur fiche), sa santé, sa faim, son bonheur, ce qu'il vaut, et la vente.
local animalCard: (number) -> ()
local animalsWindow: () -> ()
function animalCard(id: number)
	local animals = ReplicatedStorage:WaitForChild("ZooAnimals")
	local item = animals:FindFirstChild(tostring(id))
	if not item then
		toast("Cet animal n'est plus au zoo.", RED)
		return
	end
	local def = Config.SPECIES[item:GetAttribute("Species")]
	local sex = item:GetAttribute("Sex")
	local baby = (item:GetAttribute("Growth") or 1) < 1
	local name = item:GetAttribute("Name") or "?"
	local _, body = window("Fiche de " .. name, 760, 540, true)
	-- À gauche : le portrait, le prénom, renommer.
	preview(body, item:GetAttribute("Species"), sex, baby, UDim2.fromOffset(280, 280), UDim2.fromOffset(0, 0), true)
	local title = text(body, name .. "  " .. SEX[sex], UDim2.fromOffset(280, 40), UDim2.fromOffset(0, 288), GOLD)
	title.TextXAlignment = Enum.TextXAlignment.Left
	local kind = text(body, animalName(item) .. (if baby then " (bébé)" else "") .. "  ·  n°" .. id, UDim2.fromOffset(280, 22), UDim2.fromOffset(0, 330), MUTED, Enum.Font.GothamBold)
	kind.TextXAlignment = Enum.TextXAlignment.Left
	local box = Instance.new("TextBox")
	box.Size = UDim2.fromOffset(170, 34)
	box.Position = UDim2.fromOffset(0, 362)
	box.BackgroundColor3 = Color3.fromRGB(246, 236, 210)
	box.TextColor3 = Color3.fromRGB(40, 30, 24)
	box.Font = Enum.Font.GothamBold
	box.TextSize = 16
	box.PlaceholderText = "Nouveau prénom"
	box.Text = ""
	box.ClearTextOnFocus = false
	box.Parent = body
	round(box, 8)
	local rename = button(body, "Renommer", UDim2.fromOffset(102, 34), UDim2.fromOffset(178, 362), WOOD_LIGHT)
	rename.Activated:Connect(function()
		if #box.Text > 0 then
			remotes.Rename:FireServer(id, box.Text)
			task.wait(0.6)
			animalCard(id)
		end
	end)
	local price = item:GetAttribute("Price") or 0
	local sell = button(body, "Vendre " .. money(price), UDim2.fromOffset(280, 44), UDim2.fromOffset(0, 412), RED)
	sell.Activated:Connect(function()
		remotes.Sell:FireServer(id)
		task.wait(0.4)
		animalsWindow()
	end)
	-- À droite : tout ce qu'on sait de lui.
	local info = Instance.new("ScrollingFrame")
	info.Size = UDim2.new(1, -300, 1, 0)
	info.Position = UDim2.fromOffset(296, 0)
	info.BackgroundTransparency = 1
	info.BorderSizePixel = 0
	info.ScrollBarThickness = 6
	info.AutomaticCanvasSize = Enum.AutomaticSize.Y
	info.CanvasSize = UDim2.new()
	info.Parent = body
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = info
	local order = 0
	local function line(label: string, value: string, color: Color3?)
		order += 1
		local row = frame(info, UDim2.new(1, -10, 0, 0), UDim2.new(), WOOD_LIGHT)
		row.AutomaticSize = Enum.AutomaticSize.Y
		row.LayoutOrder = order
		round(row, 8)
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft, pad.PaddingRight, pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 10), UDim.new(0, 10), UDim.new(0, 6), UDim.new(0, 6)
		pad.Parent = row
		local a = text(row, label, UDim2.fromOffset(120, 22), UDim2.new(), GOLD, Enum.Font.GothamBold)
		a.TextXAlignment = Enum.TextXAlignment.Left
		a.TextScaled = false
		a.TextSize = 16
		local b = text(row, value, UDim2.new(1, -124, 0, 0), UDim2.fromOffset(124, 0), color or CREAM, Enum.Font.GothamBold)
		b.AutomaticSize = Enum.AutomaticSize.Y
		b.TextScaled = false
		b.TextSize = 16
		b.TextWrapped = true
		b.TextXAlignment = Enum.TextXAlignment.Left
		return row
	end
	local function family(label: string, list: { Instance }, empty: string)
		order += 1
		local row = frame(info, UDim2.new(1, -10, 0, 0), UDim2.new(), WOOD_LIGHT)
		row.AutomaticSize = Enum.AutomaticSize.Y
		row.LayoutOrder = order
		round(row, 8)
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft, pad.PaddingRight, pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 10), UDim.new(0, 10), UDim.new(0, 6), UDim.new(0, 6)
		pad.Parent = row
		local a = text(row, label, UDim2.fromOffset(120, 22), UDim2.new(), GOLD, Enum.Font.GothamBold)
		a.TextXAlignment = Enum.TextXAlignment.Left
		a.TextScaled = false
		a.TextSize = 16
		local holder = frame(row, UDim2.new(1, -124, 0, 0), UDim2.fromOffset(124, 0), WOOD_LIGHT)
		holder.BackgroundTransparency = 1
		holder.AutomaticSize = Enum.AutomaticSize.Y
		local flow = Instance.new("UIListLayout")
		flow.FillDirection = Enum.FillDirection.Horizontal
		flow.Wraps = true
		flow.Padding = UDim.new(0, 6)
		flow.Parent = holder
		if #list == 0 then
			local none = text(holder, empty, UDim2.fromOffset(300, 22), UDim2.new(), MUTED, Enum.Font.GothamBold)
			none.TextScaled = false
			none.TextSize = 15
			none.TextXAlignment = Enum.TextXAlignment.Left
		end
		for _, other in list do
			local tag = chip(holder, (other:GetAttribute("Name") or "?") .. " " .. SEX[other:GetAttribute("Sex")], if other:GetAttribute("Consang") then Color3.fromRGB(150, 90, 50) else WOOD)
			tag.Activated:Connect(function()
				animalCard(tonumber(other.Name))
			end)
		end
	end
	-- Âge et arrivée.
	local days = math.max(0, math.floor(zooDays() - (item:GetAttribute("Birth") or zooDays())))
	local old = item:GetAttribute("Old") == true
	line("Âge", (if baby then "bébé" elseif old then "âgé" else "adulte") .. " · " .. days .. (if days > 1 then " jours" else " jour") .. " (vit environ " .. (item:GetAttribute("Life") or 60) .. " jours)", if old then ORANGE else nil)
	local due = item:GetAttribute("Pregnant") or 0
	if due > 0 then
		local left = math.max(0, math.ceil(due - zooDays()))
		line("Enceinte", "de " .. (item:GetAttribute("PregnantFather") or "?") .. " · naissance " .. (if left <= 1 then "cette nuit" else "dans " .. left .. " jours"), GOLD)
	end
	local disease = Config.DISEASES[item:GetAttribute("Disease") or ""]
	if disease then
		if item:GetAttribute("Examined") then
			line("Maladie", disease.fr .. " : il lui faut du " .. string.lower(STOCK[disease.med].fr) .. " (pharmacie)", ORANGE)
		else
			line("Maladie", "malade (" .. disease.hint .. ") : examine-le pour savoir ce qu'il a", ORANGE)
		end
	end
	local origin = item:GetAttribute("Origin")
	local from = item:GetAttribute("OriginZoo") or ""
	local arrival = item:GetAttribute("Arrival") or 1
	local e = if sex == "f" then "e" else ""
	local arrivalText = if origin == "bought" then "acheté" .. e .. " au " .. from .. ", le jour " .. arrival
		elseif origin == "swap" then "échangé" .. e .. " avec le " .. from .. ", le jour " .. arrival
		elseif origin == "start" then "là depuis l'ouverture du zoo (venu" .. e .. " de la " .. from .. ")"
		else "né" .. e .. " au zoo, le jour " .. arrival
	line("Arrivée", arrivalText)
	local plot = item:GetAttribute("Space")
	local habitat = habitatOfPlot(plot)
	line("Vit dans", if habitat then "l'espace « " .. habitat.name .. " »" else plot)
	-- La famille.
	line("Famille", (item:GetAttribute("Fam") or "?") .. (if item:GetAttribute("Consang") then "  ·  CONSANGUIN" else ""), if item:GetAttribute("Consang") then ORANGE else nil)
	local father, mother = item:GetAttribute("Father") or 0, item:GetAttribute("Mother") or 0
	local parents, children, siblings = {}, {}, {}
	for _, other in animals:GetChildren() do
		local otherId = tonumber(other.Name)
		if otherId ~= id then
			if otherId == father or otherId == mother then
				table.insert(parents, other)
			end
			if other:GetAttribute("Father") == id or other:GetAttribute("Mother") == id then
				table.insert(children, other)
			end
			if (father > 0 and other:GetAttribute("Father") == father) or (mother > 0 and other:GetAttribute("Mother") == mother) then
				table.insert(siblings, other)
			end
		end
	end
	if father > 0 then
		local gone = {}
		for _, pair in { { father, item:GetAttribute("FatherName") }, { mother, item:GetAttribute("MotherName") } } do
			if not animals:FindFirstChild(tostring(pair[1])) then
				table.insert(gone, (pair[2] or "?") .. " (n°" .. pair[1] .. ", parti)")
			end
		end
		family("Parents", parents, table.concat(gone, ", "))
		if #parents > 0 and #gone > 0 then
			line("", table.concat(gone, ", "), MUTED)
		end
	else
		line("Parents", "inconnus : il vient d'un autre zoo (sang neuf pour tes couples)", MUTED)
	end
	family("Petits", children, "pas encore de petits")
	family("Frères, sœurs", siblings, "aucun au zoo")
	-- Santé, faim, bonheur.
	order += 1
	local health = frame(info, UDim2.new(1, -10, 0, 96), UDim2.new(), WOOD_LIGHT)
	health.LayoutOrder = order
	round(health, 8)
	local sick = item:GetAttribute("Sick") == true
	gauge(health, "Santé", if sick then 15 else 100, UDim2.fromOffset(10, 8), 420, if sick then "malade" else "en forme")
	gauge(health, "Ventre plein", 100 - (item:GetAttribute("Hunger") or 0), UDim2.fromOffset(10, 38), 420)
	gauge(health, "Bonheur", item:GetAttribute("Happy") or 0, UDim2.fromOffset(10, 68), 420)
	line("Ce qu'il mange", Config.FOODS[def.food].fr)
	line("Valeur", money(price) .. (if item:GetAttribute("Consang") then " (moitié prix : consanguin)" else ""))
end

-- Les animaux : chaque espace, et chaque animal (son prénom, son âge, sa famille) : on ouvre sa fiche.
function animalsWindow()
	local _, body = window("Mes animaux", 640, 520)
	local animals = ReplicatedStorage:WaitForChild("ZooAnimals")
	local order = 1
	note(body, order, "Touche un animal pour ouvrir sa fiche (tu peux aussi cliquer sur lui dans son enclos). Consanguin : ses parents sont de la même famille proche.")
	for _, plot in Config.PLOTS do
		local space = habitatOfPlot(plot.id)
		if space then
			local all = {}
			for _, item in animals:GetChildren() do
				if item:GetAttribute("Space") == plot.id then
					table.insert(all, item)
				end
			end
			table.sort(all, function(a, b)
				return tonumber(a.Name) < tonumber(b.Name)
			end)
			order += 1
			local title = text(body, space.name .. "  (" .. #all .. " / " .. space.capacity .. ")", UDim2.new(1, -10, 0, 28), UDim2.new(), GOLD)
			title.LayoutOrder = order
			title.TextXAlignment = Enum.TextXAlignment.Left
			if #all == 0 then
				order += 1
				note(body, order, "Vide : achète ses animaux au Marché.")
			end
			for _, item in all do
				local sex = item:GetAttribute("Sex")
				local baby = (item:GetAttribute("Growth") or 1) < 1
				order += 1
				local row = Instance.new("TextButton")
				row.Size = UDim2.new(1, -10, 0, 58)
				row.BackgroundColor3 = WOOD_LIGHT
				row.Text = ""
				row.AutoButtonColor = true
				row.LayoutOrder = order
				row.Parent = body
				round(row, 10)
				local label = text(row, (item:GetAttribute("Name") or "?") .. " " .. SEX[sex], UDim2.fromOffset(240, 26), UDim2.fromOffset(12, 4))
				label.TextXAlignment = Enum.TextXAlignment.Left
				local days = math.max(0, math.floor(zooDays() - (item:GetAttribute("Birth") or zooDays())))
				local detail = animalName(item) .. (if baby then " (bébé)" else "") .. " · " .. days .. " j · famille : " .. (item:GetAttribute("Fam") or "?") .. " · humeur " .. (item:GetAttribute("Happy") or 0) .. " %"
				local info = text(row, detail, UDim2.fromOffset(470, 20), UDim2.fromOffset(12, 32), MUTED, Enum.Font.GothamBold)
				info.TextXAlignment = Enum.TextXAlignment.Left
				local flags = {}
				if item:GetAttribute("Sick") then
					table.insert(flags, "MALADE")
				end
				if item:GetAttribute("Consang") then
					table.insert(flags, "CONSANGUIN")
				end
				if (item:GetAttribute("Pregnant") or 0) > 0 then
					table.insert(flags, "ENCEINTE")
				end
				if item:GetAttribute("Old") then
					table.insert(flags, "ÂGÉ")
				end
				if #flags > 0 then
					local flag = text(row, table.concat(flags, " · "), UDim2.fromOffset(220, 22), UDim2.fromOffset(250, 6), ORANGE, Enum.Font.GothamBlack)
					flag.TextXAlignment = Enum.TextXAlignment.Left
				end
				local open = text(row, "Fiche ›", UDim2.fromOffset(90, 30), UDim2.new(1, -100, 0, 14), GOLD)
				_ = open
				row.Activated:Connect(function()
					animalCard(tonumber(item.Name))
				end)
			end
		end
	end
end

-- LE CHOIX DES ANIMAUX D'UNE PARCELLE (sa demande, 14/10 : « de base ce serait des parcelles vides, et la déco
-- change quand tu choisis »). Chaque animal : son image en 3D, son prix (l'espace seul), s'il est dangereux (et comment
-- on le protège), combien il en tient, ce qu'il mange.
local SECURITY = {
	fence = "Calme · clôture en bois",
	wall = "Dangereux · hauts murs et vitre",
	moat = "Dangereux · fossé profond et vitre",
	pit = "Dangereux · fosse (ils sont en bas)",
}
local FOOD_NAMES = { hay = "foin", grain = "grain", meat = "viande" }
local function chooseWindow(plotId: string)
	local _, body = window("Construis un espace", 600, 500)
	local cash = state:GetAttribute("Money") or 0
	local order = 0
	order += 1
	local intro = text(body, "Le prix : l'espace seul, construit vide. Ses animaux s'achètent ensuite au Marché (mâles, femelles, bébés).", UDim2.new(1, -10, 0, 40), UDim2.new(), MUTED, Enum.Font.GothamBold)
	intro.LayoutOrder = order
	intro.TextWrapped = true
	intro.TextXAlignment = Enum.TextXAlignment.Left
	for _, habitat in Config.HABITATS do
		if not habitat.hidden then
			order += 1
			local row = frame(body, UDim2.new(1, -10, 0, 90), UDim2.new(), WOOD_LIGHT)
			row.LayoutOrder = order
			round(row, 12)
			preview(row, habitat.species[1])
			local species = Config.SPECIES[habitat.species[1]]
			local name = text(row, habitat.name, UDim2.fromOffset(250, 30), UDim2.fromOffset(96, 6))
			name.TextXAlignment = Enum.TextXAlignment.Left
			local danger = habitat.security ~= "fence"
			local info = text(row, SECURITY[habitat.security] or "", UDim2.fromOffset(300, 20), UDim2.fromOffset(96, 38), if danger then ORANGE else Color3.fromRGB(170, 230, 150), Enum.Font.GothamBold)
			info.TextXAlignment = Enum.TextXAlignment.Left
			local more = text(row, habitat.capacity .. " places · mange du " .. (FOOD_NAMES[species.food] or ""), UDim2.fromOffset(300, 18), UDim2.fromOffset(96, 62), MUTED, Enum.Font.GothamBold)
			more.TextXAlignment = Enum.TextXAlignment.Left
			local buy = button(row, money(habitat.price), UDim2.fromOffset(150, 46), UDim2.new(1, -162, 0, 22), if cash >= habitat.price then GREEN else Color3.fromRGB(120, 110, 100))
			buy.Activated:Connect(function()
				remotes.BuyPlot:FireServer(plotId, habitat.id)
				if openWindow then
					openWindow:Destroy()
					openWindow = nil
				end
			end)
		end
	end
end
remotes:WaitForChild("ChoosePlot").OnClientEvent:Connect(chooseWindow)

-- LE MARCHÉ DES ZOOS (sa demande, 14/10, et son « meilleur interface pour les autres zoos » du 15/10) : à gauche, les
-- zoos (leur blason, leur couleur, combien d'animaux ils proposent) et les échanges ; à droite, la page du zoo choisi :
-- sa présentation, sa spécialité, et ses animaux en cartes (portrait 3D, prénom, âge, prix).
local function habitatFor(species: string)
	for _, habitat in Config.HABITATS do
		if table.find(habitat.species, species) then
			return habitat
		end
	end
	return nil
end
-- Le zoo a-t-il un espace pour cette espèce, avec de la place ?
local function hasHome(species: string): boolean
	local animals = ReplicatedStorage:WaitForChild("ZooAnimals")
	for _, plot in Config.PLOTS do
		local habitat = habitatOfPlot(plot.id)
		if habitat and table.find(habitat.species, species) then
			local count = 0
			for _, item in animals:GetChildren() do
				if item:GetAttribute("Space") == plot.id then
					count += 1
				end
			end
			if count < habitat.capacity then
				return true
			end
		end
	end
	return false
end
-- Le blason d'un zoo : un rond de sa couleur avec ses deux lettres.
local function badge(parent: Instance, zoo, size: number, position: UDim2)
	local circle = frame(parent, UDim2.fromOffset(size, size), position, zoo.color)
	round(circle, size // 2)
	stroke(circle, Color3.new(1, 1, 1), 2)
	text(circle, zoo.badge, UDim2.fromScale(0.8, 0.6), UDim2.fromScale(0.1, 0.2), Color3.new(1, 1, 1))
	return circle
end

local marketPage = 1 -- le numéro du zoo affiché, ou 0 pour les échanges
local marketOpen = false
local function marketWindow(page: number?)
	if page then
		marketPage = page
	end
	local panel, body = window("Marché des zoos", 900, 580, true)
	marketOpen = true
	panel.Destroying:Connect(function()
		marketOpen = false
	end)
	local ok, data = pcall(function()
		return remotes:WaitForChild("GetMarket"):InvokeServer()
	end)
	if not ok or type(data) ~= "table" then
		return
	end
	local cash = state:GetAttribute("Money") or 0
	-- La colonne des zoos.
	local sidebar = Instance.new("ScrollingFrame")
	sidebar.Size = UDim2.new(0, 220, 1, 0)
	sidebar.BackgroundTransparency = 1
	sidebar.BorderSizePixel = 0
	sidebar.ScrollBarThickness = 4
	sidebar.AutomaticCanvasSize = Enum.AutomaticSize.Y
	sidebar.CanvasSize = UDim2.new()
	sidebar.Parent = body
	local sideList = Instance.new("UIListLayout")
	sideList.Padding = UDim.new(0, 8)
	sideList.SortOrder = Enum.SortOrder.LayoutOrder
	sideList.Parent = sidebar
	for index, zoo in Config.MARKET.zoos do
		local count = 0
		for _, offer in data.offers do
			if offer.zoo == zoo.name then
				count += 1
			end
		end
		local entry = Instance.new("TextButton")
		entry.Size = UDim2.new(1, -8, 0, 66)
		entry.BackgroundColor3 = if index == marketPage then Color3.fromRGB(110, 84, 60) else WOOD_LIGHT
		entry.Text = ""
		entry.LayoutOrder = index
		entry.Parent = sidebar
		round(entry, 12)
		if index == marketPage then
			stroke(entry, zoo.color, 3)
		end
		badge(entry, zoo, 46, UDim2.fromOffset(8, 10))
		local label = text(entry, zoo.name, UDim2.fromOffset(150, 34), UDim2.fromOffset(62, 6))
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextWrapped = true
		local small = text(entry, count .. " animaux à vendre", UDim2.fromOffset(150, 18), UDim2.fromOffset(62, 42), MUTED, Enum.Font.GothamBold)
		small.TextXAlignment = Enum.TextXAlignment.Left
		entry.Activated:Connect(function()
			marketWindow(index)
		end)
	end
	local swapEntry = button(sidebar, "⇄  Échanges (" .. #data.swaps .. ")", UDim2.new(1, -8, 0, 50), UDim2.new(), if marketPage == 0 then GREEN else WOOD)
	swapEntry.LayoutOrder = 99
	swapEntry.Activated:Connect(function()
		marketWindow(0)
	end)
	-- La page à droite.
	local content = Instance.new("ScrollingFrame")
	content.Size = UDim2.new(1, -232, 1, 0)
	content.Position = UDim2.fromOffset(232, 0)
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.ScrollBarThickness = 6
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	content.CanvasSize = UDim2.new()
	content.Parent = body
	local contentList = Instance.new("UIListLayout")
	contentList.Padding = UDim.new(0, 10)
	contentList.SortOrder = Enum.SortOrder.LayoutOrder
	contentList.Parent = content
	local animals = ReplicatedStorage:WaitForChild("ZooAnimals")
	if marketPage > 0 then
		local zoo = Config.MARKET.zoos[marketPage]
		-- La bannière du zoo.
		local banner = frame(content, UDim2.new(1, -10, 0, 118), UDim2.new(), zoo.color)
		banner.LayoutOrder = 1
		round(banner, 14)
		local shade = Instance.new("UIGradient")
		shade.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(120, 120, 120))
		shade.Rotation = 90
		shade.Parent = banner
		badge(banner, zoo, 74, UDim2.fromOffset(14, 14))
		local zooName = text(banner, zoo.name, UDim2.new(1, -110, 0, 34), UDim2.fromOffset(100, 10), Color3.new(1, 1, 1))
		zooName.TextXAlignment = Enum.TextXAlignment.Left
		zooName.TextStrokeTransparency = 0.6
		local city = text(banner, zoo.city, UDim2.new(1, -110, 0, 18), UDim2.fromOffset(100, 44), Color3.fromRGB(255, 244, 220), Enum.Font.GothamBold)
		city.TextXAlignment = Enum.TextXAlignment.Left
		local about = text(banner, zoo.about, UDim2.new(1, -112, 0, 44), UDim2.fromOffset(100, 66), Color3.new(1, 1, 1), Enum.Font.Gotham)
		about.TextXAlignment = Enum.TextXAlignment.Left
		about.TextYAlignment = Enum.TextYAlignment.Top
		about.TextWrapped = true
		about.TextScaled = false
		about.TextSize = 15
		-- Ses animaux, en cartes.
		local grid = frame(content, UDim2.new(1, -10, 0, 0), UDim2.new(), WOOD)
		grid.BackgroundTransparency = 1
		grid.AutomaticSize = Enum.AutomaticSize.Y
		grid.LayoutOrder = 2
		local cells = Instance.new("UIGridLayout")
		cells.CellSize = UDim2.fromOffset(200, 276)
		cells.CellPadding = UDim2.fromOffset(10, 10)
		cells.SortOrder = Enum.SortOrder.LayoutOrder
		cells.Parent = grid
		local shown = 0
		for _, offer in data.offers do
			if offer.zoo == zoo.name then
				shown += 1
				local def = Config.SPECIES[offer.species]
				local card = frame(grid, UDim2.fromOffset(200, 276), UDim2.new(), WOOD_LIGHT)
				card.LayoutOrder = shown
				round(card, 12)
				stroke(card, zoo.color, 2)
				preview(card, offer.species, offer.sex, offer.baby, UDim2.fromOffset(184, 128), UDim2.fromOffset(8, 8))
				local title = text(card, (offer.name or "?") .. " " .. SEX[offer.sex], UDim2.fromOffset(184, 28), UDim2.fromOffset(8, 140), GOLD)
				title.TextXAlignment = Enum.TextXAlignment.Left
				local kind = if offer.baby then def.baby .. " (bébé)" else (if offer.sex == "m" then def.m else def.f)
				local line1 = text(card, kind .. " · " .. (offer.age or "?") .. " jours", UDim2.fromOffset(184, 20), UDim2.fromOffset(8, 170), CREAM, Enum.Font.GothamBold)
				line1.TextXAlignment = Enum.TextXAlignment.Left
				local home = hasHome(offer.species)
				local habitat = habitatFor(offer.species)
				local line2 = text(card, if home then "sang neuf : famille " .. zoo.badge else "Il te faut un espace : " .. (habitat and habitat.name or "?"), UDim2.fromOffset(184, 18), UDim2.fromOffset(8, 192), if home then MUTED else ORANGE, Enum.Font.GothamBold)
				line2.TextXAlignment = Enum.TextXAlignment.Left
				local buy = button(card, money(offer.price), UDim2.fromOffset(184, 50), UDim2.fromOffset(8, 218), if home and cash >= offer.price then GREEN else Color3.fromRGB(120, 110, 100))
				buy.Activated:Connect(function()
					remotes.MarketBuy:FireServer(offer.id)
					task.wait(0.5)
					marketWindow()
				end)
			end
		end
		if shown == 0 then
			local empty = note(content, 3, "Ce zoo n'a plus d'animaux à vendre aujourd'hui. Reviens demain matin.")
			_ = empty
		end
	else
		note(content, 1, "Un échange fait entrer du SANG NEUF : l'animal qui arrive n'est pas de ta famille. Donne plutôt un animal qui a déjà de la famille dans son espace (en orange).")
		if #data.swaps == 0 then
			note(content, 2, "Aucun échange aujourd'hui (il faut des adultes). Reviens demain matin.")
		end
		for index, swap in data.swaps do
			local zoo = Config.ZOO_BY_NAME[swap.zoo] or Config.MARKET.zoos[1]
			local def = Config.SPECIES[swap.species]
			local animalKind = if swap.sex == "m" then def.m else def.f
			local mine = {}
			for _, item in animals:GetChildren() do
				if item:GetAttribute("Species") == swap.species and item:GetAttribute("Sex") == swap.sex and (item:GetAttribute("Growth") or 1) >= 1 and not item:GetAttribute("Sick") then
					table.insert(mine, item)
				end
			end
			local card = frame(content, UDim2.new(1, -10, 0, 150 + math.max(0, math.ceil(math.min(#mine, 6) / 2) - 1) * 40), UDim2.new(), WOOD_LIGHT)
			card.LayoutOrder = index + 2
			round(card, 12)
			stroke(card, zoo.color, 2)
			badge(card, zoo, 40, UDim2.fromOffset(10, 10))
			local who = text(card, zoo.name .. " propose :", UDim2.fromOffset(400, 26), UDim2.fromOffset(58, 16), GOLD)
			who.TextXAlignment = Enum.TextXAlignment.Left
			preview(card, swap.species, swap.sex, false, UDim2.fromOffset(110, 86), UDim2.fromOffset(10, 56))
			local theirs = text(card, (swap.name or "?") .. " " .. SEX[swap.sex] .. " · " .. animalKind .. " · " .. (swap.age or "?") .. " j", UDim2.fromOffset(420, 24), UDim2.fromOffset(130, 58), CREAM)
			theirs.TextXAlignment = Enum.TextXAlignment.Left
			local against = text(card, if #mine > 0 then "⇄ contre un de tes " .. animalKind .. "s (touche celui que tu donnes) :" else "⇄ il te faut un " .. animalKind .. " adulte en bonne santé", UDim2.fromOffset(500, 20), UDim2.fromOffset(130, 86), MUTED, Enum.Font.GothamBold)
			against.TextXAlignment = Enum.TextXAlignment.Left
			for slot, item in mine do
				if slot > 6 then
					break
				end
				-- (En orange : un animal qui a de la famille proche dans son espace, le meilleur à donner.)
				local relatives = 0
				for _, other in animals:GetChildren() do
					if other ~= item and other:GetAttribute("Space") == item:GetAttribute("Space") then
						local a, b = tonumber(item.Name), tonumber(other.Name)
						if other:GetAttribute("Father") == a or other:GetAttribute("Mother") == a or item:GetAttribute("Father") == b or item:GetAttribute("Mother") == b
							or ((item:GetAttribute("Father") or 0) > 0 and item:GetAttribute("Father") == other:GetAttribute("Father"))
							or ((item:GetAttribute("Mother") or 0) > 0 and item:GetAttribute("Mother") == other:GetAttribute("Mother")) then
							relatives += 1
						end
					end
				end
				local column = (slot - 1) % 2
				local row = math.floor((slot - 1) / 2)
				local give = button(card, (item:GetAttribute("Name") or "?") .. " n°" .. item.Name .. (if relatives > 0 then " · " .. relatives .. " de sa famille ici" else ""), UDim2.fromOffset(250, 34), UDim2.fromOffset(130 + column * 260, 112 + row * 40), if relatives > 0 or item:GetAttribute("Consang") then Color3.fromRGB(190, 110, 60) else WOOD)
				give.Activated:Connect(function()
					remotes.MarketSwap:FireServer(swap.id, tonumber(item.Name))
					task.wait(0.5)
					marketWindow()
				end)
			end
		end
	end
end
state:GetAttributeChangedSignal("MarketVersion"):Connect(function()
	if marketOpen and openWindow then
		marketWindow()
	end
end)

-- LES COMMANDES (l'ordinateur de la réserve, Stock.luau) : chaque produit, ce qu'il en reste, le prix d'un carton ; on
-- choisit combien de cartons, et le camion les livre.
local MED_FOR = {}
for _, disease in Config.DISEASES do
	MED_FOR[disease.med] = disease.fr
end
local KIND_NAMES = { food = "Nourriture des animaux", med = "Médicaments", shop = "Produits pour les stands" }
local function ordersWindow()
	local _, body = window("Commandes", 640, 540)
	local cart = {}
	local order = 1
	local total: TextLabel
	local function refreshTotal()
		local cost, count = 0, 0
		for item, packs in cart do
			local def = STOCK[item]
			local price = def.price * packs
			if packs >= Config.BULK.packs then
				price *= 1 - Config.BULK.discount
			end
			cost += price
			count += packs
		end
		total.Text = count .. " carton(s) · " .. money(math.floor(cost + 0.5))
	end
	note(body, order, "Le camion livre les cartons sur le quai, à côté de la réserve de l'entrée : porte-les jusqu'au coin « Cartons » d'une réserve pour les ranger. À partir de " .. Config.BULK.packs .. " cartons du même produit : -" .. math.floor(Config.BULK.discount * 100) .. " %.")
	local lastKind = nil
	for _, item in Config.STOCK_ORDER do
		local def = STOCK[item]
		if def.kind ~= lastKind then
			lastKind = def.kind
			order += 1
			local title = text(body, KIND_NAMES[def.kind], UDim2.new(1, -10, 0, 26), UDim2.new(), GOLD)
			title.LayoutOrder = order
			title.TextXAlignment = Enum.TextXAlignment.Left
		end
		order += 1
		local row = frame(body, UDim2.new(1, -10, 0, 54), UDim2.new(), WOOD_LIGHT)
		row.LayoutOrder = order
		round(row, 10)
		local swatch = frame(row, UDim2.fromOffset(10, 38), UDim2.fromOffset(8, 8), def.color)
		round(swatch, 4)
		local name = text(row, def.fr .. (if MED_FOR[item] then " (" .. string.lower(MED_FOR[item]) .. ")" else ""), UDim2.fromOffset(240, 24), UDim2.fromOffset(26, 4))
		name.TextXAlignment = Enum.TextXAlignment.Left
		local have = state:GetAttribute("Stock_" .. item) or 0
		local info = text(row, "en stock " .. have .. " / " .. def.cap .. " · carton de " .. def.pack .. " : " .. money(def.price), UDim2.fromOffset(300, 18), UDim2.fromOffset(26, 30), if have <= 2 then ORANGE else MUTED, Enum.Font.GothamBold)
		info.TextXAlignment = Enum.TextXAlignment.Left
		local minus = button(row, "−", UDim2.fromOffset(40, 38), UDim2.new(1, -150, 0, 8), WOOD)
		local count = text(row, "0", UDim2.fromOffset(50, 34), UDim2.new(1, -106, 0, 10), CREAM)
		local plus = button(row, "+", UDim2.fromOffset(40, 38), UDim2.new(1, -52, 0, 8), GREEN)
		local function set(value: number)
			cart[item] = if value > 0 then value else nil
			count.Text = tostring(value)
			refreshTotal()
		end
		minus.Activated:Connect(function()
			set(math.max(0, (cart[item] or 0) - 1))
		end)
		plus.Activated:Connect(function()
			set(math.min(20, (cart[item] or 0) + 1))
		end)
	end
	order += 1
	local footer = frame(body, UDim2.new(1, -10, 0, 60), UDim2.new(), WOOD)
	footer.LayoutOrder = order
	round(footer, 10)
	total = text(footer, "", UDim2.fromOffset(300, 30), UDim2.fromOffset(12, 6), GOLD)
	total.TextXAlignment = Enum.TextXAlignment.Left
	local onWay = text(footer, "en route : " .. (state:GetAttribute("Pending") or 0) .. " · sur le quai : " .. (state:GetAttribute("Dock") or 0), UDim2.fromOffset(300, 18), UDim2.fromOffset(12, 36), MUTED, Enum.Font.GothamBold)
	onWay.TextXAlignment = Enum.TextXAlignment.Left
	local send = button(footer, "Commander", UDim2.fromOffset(170, 44), UDim2.new(1, -180, 0, 8), GREEN)
	send.Activated:Connect(function()
		if next(cart) then
			remotes.Order:FireServer(cart)
			if openWindow then
				openWindow:Destroy()
				openWindow = nil
			end
		end
	end)
	refreshTotal()
end

-- LA PHARMACIE ET LES PRODUITS (le comptoir d'une réserve) : prendre un médicament, ou un carton pour un stand.
local function storeWindow(kind: string)
	local _, body = window(if kind == "med" then "Pharmacie" else "Produits pour les stands", 520, 420)
	local order = 1
	note(body, order, if kind == "med" then "Examine d'abord l'animal malade pour savoir ce qu'il a, puis apporte-lui le bon médicament." else "Prends un carton et apporte-le au stand qui vend ce produit (bouton Remplir).")
	for _, item in Config.STOCK_ORDER do
		local def = STOCK[item]
		if def.kind == kind then
			order += 1
			local row = frame(body, UDim2.new(1, -10, 0, 54), UDim2.new(), WOOD_LIGHT)
			row.LayoutOrder = order
			round(row, 10)
			local swatch = frame(row, UDim2.fromOffset(10, 38), UDim2.fromOffset(8, 8), def.color)
			round(swatch, 4)
			local name = text(row, def.fr .. (if MED_FOR[item] then " · soigne : " .. string.lower(MED_FOR[item]) else ""), UDim2.fromOffset(300, 24), UDim2.fromOffset(26, 4))
			name.TextXAlignment = Enum.TextXAlignment.Left
			local have = state:GetAttribute("Stock_" .. item) or 0
			local info = text(row, "en stock : " .. have, UDim2.fromOffset(200, 18), UDim2.fromOffset(26, 30), if have <= 0 then ORANGE else MUTED, Enum.Font.GothamBold)
			info.TextXAlignment = Enum.TextXAlignment.Left
			local takeButton = button(row, "Prendre", UDim2.fromOffset(120, 38), UDim2.new(1, -130, 0, 8), if have > 0 then GREEN else Color3.fromRGB(120, 110, 100))
			takeButton.Activated:Connect(function()
				remotes.Take:FireServer(item)
				if openWindow then
					openWindow:Destroy()
					openWindow = nil
				end
			end)
		end
	end
end

-- CONSTRUIRE UN STAND OU DES TOILETTES (un emplacement libre, Shops.luau).
local SHOP_ABOUT = {
	drinks = "calme la soif",
	icecream = "un peu la faim et la soif",
	fries = "calme la faim",
	coffee = "la faim et la soif",
	toilets = "pour les visiteurs pressés : à nettoyer souvent",
	souvenirs = "les visiteurs achètent en partant",
}
local function buildShopWindow(spotId: string)
	local _, body = window("Construis sur cet emplacement", 600, 500)
	local cash = state:GetAttribute("Money") or 0
	local order = 1
	note(body, order, "Un stand vend un produit : apporte-lui des cartons pris à la réserve (rayon Produits). Tu fixes ses prix dans la fenêtre Prix.")
	for _, kind in Config.SHOP_ORDER do
		local def = Config.SHOP_TYPES[kind]
		order += 1
		local row = frame(body, UDim2.new(1, -10, 0, 70), UDim2.new(), WOOD_LIGHT)
		row.LayoutOrder = order
		round(row, 12)
		local swatch = frame(row, UDim2.fromOffset(52, 52), UDim2.fromOffset(9, 9), def.color)
		round(swatch, 10)
		text(swatch, if kind == "toilets" then "WC" else string.sub(def.fr, 1, 2), UDim2.fromScale(0.8, 0.6), UDim2.fromScale(0.1, 0.2), Color3.new(1, 1, 1))
		local name = text(row, def.fr, UDim2.fromOffset(280, 28), UDim2.fromOffset(72, 6))
		name.TextXAlignment = Enum.TextXAlignment.Left
		local info = text(row, (SHOP_ABOUT[kind] or "") .. (if def.product then " · vend " .. string.lower(STOCK[def.product].fr) else ""), UDim2.fromOffset(330, 20), UDim2.fromOffset(72, 40), MUTED, Enum.Font.GothamBold)
		info.TextXAlignment = Enum.TextXAlignment.Left
		local buy = button(row, money(def.price), UDim2.fromOffset(140, 46), UDim2.new(1, -150, 0, 12), if cash >= def.price then GREEN else Color3.fromRGB(120, 110, 100))
		buy.Activated:Connect(function()
			remotes.BuyShop:FireServer(spotId, kind)
			if openWindow then
				openWindow:Destroy()
				openWindow = nil
			end
		end)
	end
end

-- LES JEUX D'UN ESPACE (Enclosures.luau) : chacun rend ses animaux plus heureux (jusqu'à 3).
local function toysWindow(plotId: string)
	local habitat = habitatOfPlot(plotId)
	if not habitat then
		return
	end
	local _, body = window("Jeux : " .. habitat.name, 560, 440)
	local cash = state:GetAttribute("Money") or 0
	local folder = workspace:FindFirstChild("Spaces") and workspace.Spaces:FindFirstChild(plotId)
	local owned = string.split(folder and folder:GetAttribute("Toys") or "", ",")
	local order = 1
	note(body, order, "Des animaux qui jouent sont plus heureux (et les visiteurs aussi). Jusqu'à 3 jeux comptent pour leur bonheur.")
	for _, toy in habitat.toys or {} do
		local def = Config.TOYS[toy]
		local has = table.find(owned, toy) ~= nil
		order += 1
		local row = frame(body, UDim2.new(1, -10, 0, 56), UDim2.new(), WOOD_LIGHT)
		row.LayoutOrder = order
		round(row, 10)
		local name = text(row, def.fr, UDim2.fromOffset(300, 26), UDim2.fromOffset(12, 6))
		name.TextXAlignment = Enum.TextXAlignment.Left
		local info = text(row, if has then "installé" else "+ bonheur pour les " .. string.lower(habitat.name), UDim2.fromOffset(300, 18), UDim2.fromOffset(12, 32), if has then GREEN else MUTED, Enum.Font.GothamBold)
		info.TextXAlignment = Enum.TextXAlignment.Left
		if not has then
			local buy = button(row, money(def.price), UDim2.fromOffset(130, 40), UDim2.new(1, -140, 0, 8), if cash >= def.price then GREEN else Color3.fromRGB(120, 110, 100))
			buy.Activated:Connect(function()
				remotes.BuyToy:FireServer(plotId, toy)
				task.wait(0.5)
				toysWindow(plotId)
			end)
		end
	end
end

-- LES PRIX (sa demande du 15/10, « 2 ») : le billet et chaque produit ; ce qu'en pensent les visiteurs.
local pricesOpen = false
local function pricesWindow()
	local panel, body = window("Prix", 600, 500)
	pricesOpen = true
	panel.Destroying:Connect(function()
		pricesOpen = false
	end)
	local order = 1
	note(body, order, "Plus c'est cher, moins les visiteurs achètent (et ils râlent). Moins cher, ils sont contents mais tu gagnes moins.")
	local function row(key: string, label: string, fair: number, limits: { number })
		local current = state:GetAttribute("Price_" .. key) or 0
		if current <= 0 then
			current = fair
		end
		order += 1
		local item = frame(body, UDim2.new(1, -10, 0, 64), UDim2.new(), WOOD_LIGHT)
		item.LayoutOrder = order
		round(item, 10)
		local name = text(item, label, UDim2.fromOffset(220, 26), UDim2.fromOffset(12, 6))
		name.TextXAlignment = Enum.TextXAlignment.Left
		local chance = Config.buyChance(current, fair)
		local ratio = current / math.max(fair, 0.1)
		local verdict = if ratio < 0.85 then "bon marché" elseif ratio <= 1.0 then "correct" elseif ratio <= 1.3 then "un peu cher" else "trop cher"
		local info = text(item, "prix normal " .. money(fair) .. " · " .. verdict .. " · ils achètent à " .. math.floor(chance * 100) .. " %", UDim2.fromOffset(330, 20), UDim2.fromOffset(12, 36), if ratio <= 1 then GREEN elseif ratio <= 1.3 then GOLD else ORANGE, Enum.Font.GothamBold)
		info.TextXAlignment = Enum.TextXAlignment.Left
		local function change(delta: number)
			remotes.SetPrice:FireServer(key, math.clamp(current + delta, limits[1], limits[2]))
		end
		local down = button(item, "−", UDim2.fromOffset(38, 38), UDim2.new(1, -190, 0, 13), WOOD)
		local value = text(item, money(current), UDim2.fromOffset(100, 34), UDim2.new(1, -148, 0, 15), GOLD)
		local up = button(item, "+", UDim2.fromOffset(38, 38), UDim2.new(1, -46, 0, 13), GREEN)
		_ = value
		down.Activated:Connect(function()
			change(-1)
		end)
		up.Activated:Connect(function()
			change(1)
		end)
	end
	row("ticket", "Billet d'entrée", Config.ticketPrice(state:GetAttribute("Stars") or 2.5), Config.PRICE_LIMITS.ticket)
	for _, kind in Config.SHOP_ORDER do
		local def = Config.SHOP_TYPES[kind]
		if def.product then
			row(kind, def.fr .. " (" .. string.lower(STOCK[def.product].fr) .. ")", def.fair, Config.PRICE_LIMITS.shop)
		end
	end
end
state.AttributeChanged:Connect(function(name)
	if pricesOpen and openWindow and string.sub(name, 1, 6) == "Price_" then
		pricesWindow()
	end
end)

-- Le serveur ouvre une fenêtre (l'ordinateur, la pharmacie, un emplacement, les jeux d'un espace).
remotes:WaitForChild("Open").OnClientEvent:Connect(function(kind, value)
	if kind == "orders" then
		ordersWindow()
	elseif kind == "store" then
		storeWindow(value)
	elseif kind == "buildShop" then
		buildShopWindow(value)
	elseif kind == "toys" then
		toysWindow(value)
	end
end)

-- LA PLUIE ET LA TEMPÊTE (Weather.luau) : des gouttes autour du joueur, un ciel plus sombre.
local Lighting = game:GetService("Lighting")
local rainPart = Instance.new("Part")
rainPart.Name = "Rain"
rainPart.Anchored, rainPart.CanCollide, rainPart.CanQuery, rainPart.CanTouch = true, false, false, false
rainPart.Transparency = 1
rainPart.Size = Vector3.new(120, 1, 120)
rainPart.Parent = workspace
local rain = Instance.new("ParticleEmitter")
rain.Texture = "rbxasset://textures/particles/sparkles_main.dds"
rain.Color = ColorSequence.new(Color3.fromRGB(190, 210, 230))
rain.Size = NumberSequence.new(0.15)
rain.Transparency = NumberSequence.new(0.35)
rain.Lifetime = NumberRange.new(1.2, 1.5)
rain.Speed = NumberRange.new(55, 65)
rain.EmissionDirection = Enum.NormalId.Bottom
rain.Rate = 0
rain.Parent = rainPart
local function refreshWeather()
	local weather = state:GetAttribute("Weather")
	rain.Rate = if weather == "rain" then 500 elseif weather == "storm" then 900 else 0
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		atmosphere.Density = if weather == "rain" then 0.38 elseif weather == "storm" then 0.45 elseif weather == "clouds" then 0.28 else 0.22
	end
	local correction = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if correction then
		correction.TintColor = if weather == "heat" then Color3.fromRGB(255, 236, 210) elseif weather == "rain" or weather == "storm" then Color3.fromRGB(220, 228, 240) else Color3.fromRGB(255, 250, 240)
		correction.Brightness = if weather == "storm" then -0.06 elseif weather == "rain" then -0.03 else 0.01
	end
end
state:GetAttributeChangedSignal("Weather"):Connect(refreshWeather)
refreshWeather()
game:GetService("RunService").RenderStepped:Connect(function()
	if rain.Rate > 0 then
		rainPart.CFrame = CFrame.new(workspace.CurrentCamera.CFrame.Position + Vector3.new(0, 40, 0))
	end
end)

local side = frame(gui, UDim2.fromOffset(130, 272), UDim2.new(1, -140, 0.5, -136))
side.BackgroundTransparency = 1
local staffButton = button(side, "Personnel", UDim2.fromOffset(130, 44), UDim2.fromOffset(0, 0), WOOD_LIGHT)
local animalsButton = button(side, "Animaux", UDim2.fromOffset(130, 44), UDim2.fromOffset(0, 52), WOOD_LIGHT)
local marketButton = button(side, "Marché", UDim2.fromOffset(130, 44), UDim2.fromOffset(0, 104), GREEN)
local pricesButton = button(side, "Prix", UDim2.fromOffset(130, 44), UDim2.fromOffset(0, 156), WOOD_LIGHT)
local viewButton = button(side, "Vue", UDim2.fromOffset(130, 40), UDim2.fromOffset(0, 208), WOOD)
local mouseHint = text(side, "M : la souris", UDim2.fromOffset(130, 18), UDim2.fromOffset(0, 252), CREAM, Enum.Font.GothamBold)
staffButton.Activated:Connect(staffWindow)
animalsButton.Activated:Connect(animalsWindow)
pricesButton.Activated:Connect(pricesWindow)
marketButton.Activated:Connect(function()
	marketWindow()
end)

-- LA VUE À LA PREMIÈRE PERSONNE (par défaut), ou de dos ; le point de visée au milieu de l'écran ; M libère la souris.
local aimGui = Instance.new("ScreenGui")
aimGui.Name = "Aim"
aimGui.IgnoreGuiInset = true
aimGui.ResetOnSpawn = false
aimGui.Parent = player:WaitForChild("PlayerGui")
local dot = frame(aimGui, UDim2.fromOffset(8, 8), UDim2.new(0.5, -4, 0.5, -4), Color3.new(1, 1, 1))
round(dot, 4)
stroke(dot, Color3.fromRGB(30, 30, 30), 1.5)
local freeMouse = Instance.new("TextButton")
freeMouse.Modal = true
freeMouse.Size = UDim2.fromOffset(0, 0)
freeMouse.BackgroundTransparency = 1
freeMouse.Text = ""
freeMouse.Visible = false
freeMouse.Parent = gui
local firstPerson = true
local function applyView()
	if firstPerson then
		player.CameraMinZoomDistance = 0.5
		player.CameraMaxZoomDistance = 0.5
	else
		player.CameraMaxZoomDistance = 40
		player.CameraMinZoomDistance = 8
	end
	viewButton.Text = if firstPerson then "Vue : yeux" else "Vue : de dos"
	dot.Visible = firstPerson
	mouseHint.Visible = firstPerson and not UserInputService.TouchEnabled
end
applyView()
viewButton.Activated:Connect(function()
	firstPerson = not firstPerson
	applyView()
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.M then
		freeMouse.Visible = not freeMouse.Visible
	elseif input.KeyCode == Enum.KeyCode.V then
		firstPerson = not firstPerson
		applyView()
	end
end)

-- LE SCANNER EN MAIN (Scanner.luau) : un clic tire le laser rouge ; sur le billet, « bip » et le visiteur passe.
local scanEvent = remotes:WaitForChild("ScanTicket")
local mouse = player:GetMouse()
mouse.TargetFilter = workspace:WaitForChild("Carried")
local beep = Instance.new("Sound")
beep.SoundId = "rbxasset://sounds/electronicpingshort.wav"
beep.Volume = 0.6
beep.Parent = gui
local function laser(from: Vector3, to: Vector3)
	local length = (to - from).Magnitude
	local ray = Instance.new("Part")
	ray.Anchored, ray.CanCollide, ray.CanQuery, ray.CanTouch, ray.CastShadow = true, false, false, false, false
	ray.Material = Enum.Material.Neon
	ray.Color = Color3.fromRGB(255, 40, 40)
	ray.Size = Vector3.new(0.06, 0.06, length)
	ray.CFrame = CFrame.lookAt((from + to) / 2, to)
	ray.Parent = workspace
	task.delay(0.12, function()
		ray:Destroy()
	end)
end
local function hookScanner(tool: Instance)
	if not tool:IsA("Tool") or tool.Name ~= "Scanner" or tool:GetAttribute("Hooked") then
		return
	end
	tool:SetAttribute("Hooked", true)
	tool.Activated:Connect(function()
		local window = tool:FindFirstChild("Window")
		local tip = window and window:FindFirstChild("Tip")
		local target = mouse.Target
		local hit = mouse.Hit.Position
		if tip and tip:IsA("Attachment") then
			laser(tip.WorldPosition, hit)
		end
		if target and target.Name == "Ticket" then
			beep:Play()
			scanEvent:FireServer(target)
		end
	end)
end
local function watchCharacter(character: Model)
	for _, child in character:GetChildren() do
		hookScanner(child)
	end
	character.ChildAdded:Connect(hookScanner)
end
if player.Character then
	watchCharacter(player.Character)
end
player.CharacterAdded:Connect(function(character)
	watchCharacter(character)
	applyView()
end)

-- CLIQUER (OU TOUCHER) UN ANIMAL DANS SON ENCLOS : sa fiche. (Pas avec le scanner en main.)
local function animalAt(target: Instance?): number?
	local view = workspace:FindFirstChild("ZooAnimalsView")
	local current = target
	while current and current ~= workspace do
		if current:IsA("Model") and current.Parent == view then
			return current:GetAttribute("AnimalId")
		end
		current = current.Parent
	end
	return nil
end
local function holdingTool(): boolean
	return player.Character ~= nil and player.Character:FindFirstChildOfClass("Tool") ~= nil
end
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or input.UserInputType ~= Enum.UserInputType.MouseButton1 or holdingTool() then
		return
	end
	local id = animalAt(mouse.Target)
	if id then
		animalCard(id)
	end
end)
UserInputService.TouchTap:Connect(function(positions, processed)
	if processed or not positions[1] or holdingTool() then
		return
	end
	local ray = workspace.CurrentCamera:ViewportPointToRay(positions[1].X, positions[1].Y)
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 300)
	local id = hit and animalAt(hit.Instance)
	if id then
		animalCard(id)
	end
end)

-- LE BILAN DU SOIR -----------------------------------------------------------------------------------------------------
local LINES = {
	{ "tickets", "Billets" }, { "shops", "Café et bar" }, { "sales", "Animaux vendus" }, { "food", "Nourriture" },
	{ "orders", "Commandes" }, { "spaces", "Constructions" }, { "animals", "Animaux achetés" }, { "toys", "Jeux" },
	{ "inspection", "Inspection" }, { "salaries", "Salaires" },
}
remotes:WaitForChild("Bilan").OnClientEvent:Connect(function(report)
	local panel, body = window("Bilan du jour " .. report.day, 460, 470)
	local order = 0
	local function line(left: string, right: string, color: Color3?)
		order += 1
		local row = frame(body, UDim2.new(1, -10, 0, 26), UDim2.new(), WOOD)
		row.BackgroundTransparency = 1
		row.LayoutOrder = order
		local a = text(row, left, UDim2.fromScale(0.62, 1), UDim2.new(), CREAM, Enum.Font.GothamBold)
		a.TextXAlignment = Enum.TextXAlignment.Left
		local b = text(row, right, UDim2.fromScale(0.36, 1), UDim2.fromScale(0.62, 0), color or CREAM, Enum.Font.GothamBold)
		b.TextXAlignment = Enum.TextXAlignment.Right
	end
	line("Visiteurs", tostring(report.visitors))
	if report.angry > 0 then
		line("Repartis fâchés", tostring(report.angry), RED)
	end
	for _, item in LINES do
		local amount = report.money[item[1]]
		if amount and amount ~= 0 then
			line(item[2], (if amount > 0 then "+" else "") .. money(amount), if amount > 0 then GREEN else RED)
		end
	end
	line("Total du jour", (if report.total > 0 then "+" else "") .. money(report.total), if report.total >= 0 then GOLD else RED)
	line("En caisse", money(report.balance), GOLD)
	line("Note du zoo", string.format("%.1f → %.1f", report.starsBefore, report.starsAfter), if report.starsAfter >= report.starsBefore then GREEN else RED)
	line("Météo", report.weather or "")
	if report.event then
		line("Événement", report.event, GOLD)
	end
	if report.inspection then
		line("Inspection", "note " .. report.inspection, if report.inspection <= "B" then GREEN else RED)
	end
	if report.journalist then
		line("Article du journaliste", string.format("%.1f / 5", report.journalist), if report.journalist >= 3 then GREEN else RED)
	end
	if (report.refused or 0) > 0 then
		line("Repartis (billet trop cher)", tostring(report.refused), RED)
	end
	if (report.old or 0) > 0 then
		line("Morts de vieillesse", tostring(report.old))
	end
	if #report.births > 0 then
		line("Naissances", table.concat(report.births, ", "), GREEN)
	end
	if report.lost > 0 then
		line("Animaux emmenés", tostring(report.lost), RED)
	end
	order += 1
	local nextButton = button(body, "Jour suivant", UDim2.fromOffset(200, 44), UDim2.new(), GREEN)
	nextButton.LayoutOrder = order
	nextButton.Activated:Connect(function()
		remotes.NextDay:FireServer()
		panel:Destroy()
	end)
end)

-- (Pour les tests photo : ouvrir une fenêtre sans cliquer.)
workspace:GetAttributeChangedSignal("OpenWindow"):Connect(function()
	local wanted = workspace:GetAttribute("OpenWindow")
	if wanted == "market" then
		marketWindow(1)
	elseif wanted == "market3" then
		marketWindow(3)
	elseif wanted == "swap" then
		marketWindow(0)
	elseif wanted == "fiche" then
		local animals = ReplicatedStorage:WaitForChild("ZooAnimals")
		local best = nil
		for _, item in animals:GetChildren() do
			if (item:GetAttribute("Father") or 0) > 0 and (not best or tonumber(item.Name) > tonumber(best.Name)) then
				best = item
			end
		end
		best = best or animals:GetChildren()[1]
		if best then
			animalCard(tonumber(best.Name))
		end
	elseif wanted == "orders" then
		ordersWindow()
	elseif wanted == "prices" then
		pricesWindow()
	elseif wanted == "pharmacy" then
		storeWindow("med")
	elseif wanted == "buildShop" then
		buildShopWindow("k3")
	elseif wanted == "toys" then
		toysWindow("w1")
	elseif wanted == "fiche_id" then
		animalCard(workspace:GetAttribute("FicheId"))
	elseif wanted == "animals" then
		animalsWindow()
	elseif wanted == "build" then
		chooseWindow("w1")
	elseif openWindow then
		openWindow:Destroy()
		openWindow = nil
	end
end)

-- (Échap ferme la fenêtre ouverte.)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.Escape and openWindow then
		openWindow:Destroy()
		openWindow = nil
	end
end)

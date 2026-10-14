-- L'ÉCRAN DU JOUEUR : en haut, le jour, l'heure, l'argent, la note du zoo et les visiteurs ; les messages ; les « +10 $ »
-- qui s'envolent ; ce qu'on porte (avec « Poser ») ; les conseils du début ; les boutons Personnel et Animaux ; le
-- bilan du soir avec le bouton du jour suivant.
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
	phaseLabel.Text = PHASES[state:GetAttribute("Phase") or "open"] or ""
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

local FOOD = { hay = "du foin", grain = "du grain", meat = "de la viande", kit = "une trousse de soins" }
local MESSAGES = {
	noMoney = function(amount)
		return "Pas assez d'argent (" .. money(amount) .. ")", RED
	end,
	took = function(kind)
		return "Tu portes " .. (FOOD[kind] or kind) .. ".", nil
	end,
	alreadyCarry = function(name)
		return "Tu portes déjà : " .. name, nil
	end,
	needFood = function(name)
		return "Il faut du " .. string.lower(name) .. " : va le chercher à la réserve.", RED
	end,
	needKit = function()
		return "Il faut une trousse de soins (réserve).", RED
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
	sick = function(name, place)
		return name .. " est malade (" .. place .. ") : soigne-le !", RED
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
		return "Pas d'adulte en bonne santé à vendre ici.", RED
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
	needCafe = function()
		return "Construis d'abord le café.", RED
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
local CARRY_NAMES = { hay = "Foin", grain = "Grain", meat = "Viande", kit = "Trousse de soins" }
local function refreshCarry()
	local kind = player:GetAttribute("Carry") or ""
	carry.Visible = kind ~= ""
	carryLabel.Text = "Tu portes : " .. (CARRY_NAMES[kind] or kind)
end
player:GetAttributeChangedSignal("Carry"):Connect(refreshCarry)
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
	"Des visiteurs arrivent ! Va dans la cabine du guichet (à l'entrée) et scanne leurs billets.",
	"Prends du foin ou du grain à la RÉSERVE (à gauche de l'entrée) et remplis une mangeoire de la mini-ferme.",
	"Les animaux font des crottes : entre dans la mini-ferme (porte « Personnel ») et ramasse-en une.",
	"Achète une parcelle : va au panneau « Parcelle à vendre » (en face de la mini-ferme) et choisis tes animaux.",
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
local function window(title: string, width: number, height: number): (Frame, ScrollingFrame)
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

-- Les animaux : par espace, chaque espèce avec ses mâles, ses femelles, ses petits, et la vente d'un adulte.
local function animalsWindow()
	local _, body = window("Mes animaux", 560, 470)
	local animals = ReplicatedStorage:WaitForChild("ZooAnimals")
	local order = 0
	for _, plot in Config.PLOTS do
		local space = Config.HABITAT_BY_ID[state:GetAttribute("Plot_" .. plot.id) or ""]
		if space then
			local all = {}
			for _, item in animals:GetChildren() do
				if item:GetAttribute("Space") == plot.id then
					table.insert(all, item)
				end
			end
			order += 1
			local title = text(body, space.name .. "  (" .. #all .. " / " .. space.capacity .. ")", UDim2.new(1, -10, 0, 26), UDim2.new(), GOLD)
			title.LayoutOrder = order
			title.TextXAlignment = Enum.TextXAlignment.Left
			for _, species in space.species do
				local def = Config.SPECIES[species]
				local males, females, babies, sick, happy = 0, 0, 0, 0, 0
				for _, item in all do
					if item:GetAttribute("Species") == species then
						if (item:GetAttribute("Growth") or 1) < 1 then
							babies += 1
						elseif item:GetAttribute("Sex") == "m" then
							males += 1
						else
							females += 1
						end
						if item:GetAttribute("Sick") then
							sick += 1
						end
						happy += item:GetAttribute("Happy") or 0
					end
				end
				local total = males + females + babies
				order += 1
				local row = frame(body, UDim2.new(1, -10, 0, 64), UDim2.new(), WOOD_LIGHT)
				row.LayoutOrder = order
				round(row, 10)
				local name = text(row, def.group, UDim2.fromOffset(160, 26), UDim2.fromOffset(12, 6))
				name.TextXAlignment = Enum.TextXAlignment.Left
				local detail = string.format("♂ %d   ♀ %d   petits %d", males, females, babies) .. (if sick > 0 then "   malades " .. sick else "")
				local info = text(row, detail, UDim2.fromOffset(250, 22), UDim2.fromOffset(12, 34), Color3.fromRGB(210, 196, 160), Enum.Font.GothamBold)
				info.TextXAlignment = Enum.TextXAlignment.Left
				local mood = text(row, if total > 0 then "humeur " .. math.floor(happy / total) .. " %" else "", UDim2.fromOffset(110, 22), UDim2.fromOffset(170, 8), GREEN, Enum.Font.GothamBold)
				_ = mood
				local sellM = button(row, "Vendre ♂ " .. money(def.sell), UDim2.fromOffset(150, 26), UDim2.fromOffset(372, 4), WOOD)
				local sellF = button(row, "Vendre ♀ " .. money(def.sell), UDim2.fromOffset(150, 26), UDim2.fromOffset(372, 34), WOOD)
				sellM.Activated:Connect(function()
					remotes.Sell:FireServer(plot.id, species, "m")
					task.wait(0.4)
					animalsWindow()
				end)
				sellF.Activated:Connect(function()
					remotes.Sell:FireServer(plot.id, species, "f")
					task.wait(0.4)
					animalsWindow()
				end)
			end
		end
	end
end

-- LE CHOIX DES ANIMAUX D'UNE PARCELLE (sa demande, 14/10 : « de base ce serait des parcelles vides, et la déco
-- change quand tu choisis »). Chaque animal : son image en 3D, son prix (le décor et le couple de départ), s'il est
-- dangereux (et comment on le protège), combien il en tient, ce qu'il mange.
local SECURITY = {
	fence = "Calme · clôture en bois",
	wall = "Dangereux · hauts murs et vitre",
	moat = "Dangereux · fossé profond et vitre",
	pit = "Dangereux · fosse (ils sont en bas)",
}
local FOOD_NAMES = { hay = "foin", grain = "grain", meat = "viande" }
local function preview(parent: GuiObject, species: string)
	local view = Instance.new("ViewportFrame")
	view.Size = UDim2.fromOffset(78, 78)
	view.Position = UDim2.fromOffset(6, 6)
	view.BackgroundColor3 = Color3.fromRGB(196, 214, 170)
	view.Ambient = Color3.fromRGB(190, 190, 190)
	view.LightColor = Color3.fromRGB(255, 255, 255)
	view.LightDirection = Vector3.new(-1, -1, -1)
	view.Parent = parent
	round(view, 10)
	local model = AnimalModels.build(species, "m", 1)
	if not model then
		return
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
end

local function chooseWindow(plotId: string)
	local _, body = window("Choisis tes animaux", 600, 500)
	local cash = state:GetAttribute("Money") or 0
	local order = 0
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
			local info = text(row, SECURITY[habitat.security] or "", UDim2.fromOffset(300, 20), UDim2.fromOffset(96, 38), if danger then Color3.fromRGB(255, 160, 120) else Color3.fromRGB(170, 230, 150), Enum.Font.GothamBold)
			info.TextXAlignment = Enum.TextXAlignment.Left
			local more = text(row, habitat.capacity .. " places · mange du " .. (FOOD_NAMES[species.food] or ""), UDim2.fromOffset(300, 18), UDim2.fromOffset(96, 62), Color3.fromRGB(210, 196, 160), Enum.Font.GothamBold)
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

local side = frame(gui, UDim2.fromOffset(130, 100), UDim2.new(1, -140, 0.5, -50))
side.BackgroundTransparency = 1
local staffButton = button(side, "Personnel", UDim2.fromOffset(130, 44), UDim2.fromOffset(0, 0), WOOD_LIGHT)
local animalsButton = button(side, "Animaux", UDim2.fromOffset(130, 44), UDim2.fromOffset(0, 54), WOOD_LIGHT)
staffButton.Activated:Connect(staffWindow)
animalsButton.Activated:Connect(animalsWindow)

-- LE BILAN DU SOIR -----------------------------------------------------------------------------------------------------
local LINES = {
	{ "tickets", "Billets" }, { "shops", "Café et bar" }, { "sales", "Animaux vendus" }, { "food", "Nourriture" },
	{ "care", "Soins" }, { "spaces", "Achats" }, { "salaries", "Salaires" },
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

-- (Échap ferme la fenêtre ouverte.)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.Escape and openWindow then
		openWindow:Destroy()
		openWindow = nil
	end
end)

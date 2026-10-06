-- SEULEMENT DANS STUDIO : un panneau de réglages pour essayer le jeu sans s'entraîner.
-- Des jauges qu'on déplace à la souris : les points de vitesse, de saut et de force, les pièces, et la vitesse du
-- prédateur (salle 2). Le bouton « RÉGLAGES » en haut à gauche ouvre et ferme le panneau.
-- Le serveur n'écoute ces réglages que dans Studio (Debug.luau) : rien de tout ça n'existe dans le jeu publié.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)

local WHITE = Color3.new(1, 1, 1)

local UNITS = { { 1e27, "Oc" }, { 1e24, "Sp" }, { 1e21, "Sx" }, { 1e18, "Qi" }, { 1e15, "Qa" }, { 1e12, "T" } }
local function grouped(value: number): string
	-- Les très grands nombres : 1,5 Qa, 87 T...
	for _, unit in UNITS do
		if value >= unit[1] then
			return string.format("%.3g %s", value / unit[1], unit[2])
		end
	end
	local text = string.format("%d", math.floor(value + 0.5))
	local out = text:reverse():gsub("(%d%d%d)", "%1 "):reverse()
	return (out:gsub("^ ", ""))
end
-- Points d'une stat pour un palier avec décimales (0 à 6) : entre deux paliers, on avance tout droit.
local function pointsAt(tier: number): number
	local low = math.floor(tier)
	local from, to = Config.pointsFor(low), Config.pointsFor(math.min(low + 1, Config.MAX_LEVEL))
	if low < 1 then
		return math.floor(to * tier + 0.5)
	end
	-- Entre deux paliers, on avance en multipliant (comme Config.levelOf).
	return math.floor(from * (to / from) ^ (tier - low) + 0.5)
end

return function()
	local remote = ReplicatedStorage:WaitForChild("DebugSet", 10)
	if not remote then
		return
	end
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "DebugPanel"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50
	gui.Parent = player:WaitForChild("PlayerGui")

	local function label(parent: Instance, text: string, size: UDim2, position: UDim2, color: Color3?, height: number?): TextLabel
		local item = Instance.new("TextLabel")
		item.BackgroundTransparency = 1
		item.Size = size
		item.Position = position
		item.Font = Enum.Font.GothamBold
		item.TextSize = height or 15
		item.TextColor3 = color or WHITE
		item.TextXAlignment = Enum.TextXAlignment.Left
		item.Text = text
		item.Parent = parent
		return item
	end
	local function round(item: GuiObject, radius: number)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, radius)
		corner.Parent = item
	end

	local toggle = Instance.new("TextButton")
	toggle.Name = "Toggle"
	toggle.Size = UDim2.fromOffset(120, 30)
	toggle.Position = UDim2.fromOffset(190, 8)
	toggle.BackgroundColor3 = Color3.fromRGB(40, 44, 60)
	toggle.Font = Enum.Font.GothamBold
	toggle.TextSize = 15
	toggle.TextColor3 = Color3.fromRGB(255, 221, 51)
	toggle.Text = "RÉGLAGES"
	toggle.Parent = gui
	round(toggle, 8)

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.fromOffset(380, 0)
	panel.Position = UDim2.fromOffset(190, 44)
	panel.BackgroundColor3 = Color3.fromRGB(28, 30, 42)
	panel.BackgroundTransparency = 0.08
	panel.Visible = false
	panel.Parent = gui
	round(panel, 10)
	label(panel, "Réglages de test (Studio seulement)", UDim2.new(1, -20, 0, 20), UDim2.fromOffset(12, 8), Color3.fromRGB(255, 221, 51))
	label(panel, "Portes ouvertes : traverse les salles, arrête-toi 2 s dans celle à jouer.", UDim2.new(1, -20, 0, 16), UDim2.fromOffset(12, 28), Color3.fromRGB(200, 204, 214), 12)
	toggle.MouseButton1Click:Connect(function()
		panel.Visible = not panel.Visible
	end)

	-- Une jauge : on clique ou on glisse sur la barre. change(x) reçoit la place du curseur (0 à 1) et renvoie le
	-- texte à afficher ; il est appelé pendant qu'on glisse, et send(x) une fois le bouton relâché... et aussi
	-- pendant, quelques fois par seconde, pour voir l'effet tout de suite.
	local rows = 0
	local dragging = nil
	local function slider(title: string, color: Color3, start: number, describe: (number) -> string, send: (number) -> ())
		local y = 52 + rows * 58
		rows += 1
		local caption = label(panel, "", UDim2.new(1, -24, 0, 18), UDim2.fromOffset(12, y))
		local bar = Instance.new("TextButton")
		bar.Name = title
		bar.AutoButtonColor = false
		bar.Text = ""
		bar.Size = UDim2.new(1, -24, 0, 18)
		bar.Position = UDim2.fromOffset(12, y + 24)
		bar.BackgroundColor3 = Color3.fromRGB(60, 64, 84)
		bar.Parent = panel
		round(bar, 9)
		local fill = Instance.new("Frame")
		fill.BackgroundColor3 = color
		fill.BorderSizePixel = 0
		fill.Parent = bar
		round(fill, 9)
		local knob = Instance.new("Frame")
		knob.Size = UDim2.fromOffset(14, 26)
		knob.AnchorPoint = Vector2.new(0.5, 0.5)
		knob.BackgroundColor3 = WHITE
		knob.BorderSizePixel = 0
		knob.Parent = bar
		round(knob, 5)
		local item = { value = start, sent = 0 }
		function item.show()
			fill.Size = UDim2.fromScale(item.value, 1)
			knob.Position = UDim2.fromScale(item.value, 0.5)
			caption.Text = title .. " : " .. describe(item.value)
		end
		function item.at(screenX: number, final: boolean)
			item.value = math.clamp((screenX - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
			item.show()
			if final or os.clock() - item.sent > 0.15 then
				item.sent = os.clock()
				send(item.value)
			end
		end
		bar.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = item
				item.at(input.Position.X, false)
			end
		end)
		item.show()
		panel.Size = UDim2.fromOffset(380, 52 + rows * 58 + 8)
		return item
	end
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			dragging.at(input.Position.X, false)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			dragging.at(input.Position.X, true)
			dragging = nil
		end
	end)

	-- Les trois stats : la jauge va du palier 0 au palier 6.
	local STATS = {
		{ "Speed", "Vitesse", Color3.fromRGB(60, 150, 255), function(tier)
			return string.format("court à %.1f", Config.walkSpeed(tier))
		end },
		{ "Jump", "Saut", Color3.fromRGB(70, 210, 90), function(tier)
			return string.format("saute à %.1f", Config.jumpHeight(tier))
		end },
		{ "Force", "Force", Color3.fromRGB(235, 70, 70), function(tier)
			return string.format("force %.0f", Config.force(tier))
		end },
	}
	for _, stat in STATS do
		local name, title, color, effect = stat[1], stat[2], stat[3], stat[4]
		local start = Config.levelOf(player:GetAttribute(name .. "Points") or 0) / Config.MAX_LEVEL
		local item = slider(title, color, start, function(x)
			local tier = x * Config.MAX_LEVEL
			return string.format("%s points  (palier %.1f, %s)", grouped(pointsAt(tier)), tier, effect(tier))
		end, function(x)
			remote:FireServer(name, pointsAt(x * Config.MAX_LEVEL))
		end)
		-- La jauge suit aussi la stat quand elle change autrement (un entrainement sur la machine).
		player:GetAttributeChangedSignal(name .. "Points"):Connect(function()
			if dragging ~= item then
				item.value = Config.levelOf(player:GetAttribute(name .. "Points") or 0) / Config.MAX_LEVEL
				item.show()
			end
		end)
	end
	-- Les trois machines : leur niveau, de 1 au maximum.
	local function machineAt(x: number): number
		return math.floor(1 + x * (Config.MACHINE_MAX - 1) + 0.5)
	end
	slider("Machines (les trois)", Color3.fromRGB(90, 220, 220), ((player:GetAttribute("SpeedMachine") or 1) - 1) / (Config.MACHINE_MAX - 1), function(x)
		local level = machineAt(x)
		local price = Config.price(level)
		return string.format("niveau %d  (+%s points par pas%s)", level, grouped(Config.gain(level)), if price then ", le suivant coûte " .. grouped(price) else ", maximum")
	end, function(x)
		remote:FireServer("Machines", machineAt(x))
	end)
	-- Les pièces : de 0 à 1 Qa (la jauge avance de plus en plus vite).
	local function coinsAt(x: number): number
		return if x <= 0.02 then 0 else math.floor(10 ^ (x * 15) + 0.5)
	end
	slider("Pièces", Color3.fromRGB(255, 200, 40), 0, function(x)
		return grouped(coinsAt(x))
	end, function(x)
		remote:FireServer("Coins", coinsAt(x))
	end)
	-- Les vannes de la salle 4 : le temps de remplissage des jauges, en % du réglage du jeu (plus petit = plus dur).
	local function valveAt(x: number): number
		return math.floor(60 + x * 80 + 0.5)
	end
	slider("Vannes (salle 4)", Color3.fromRGB(255, 130, 60), (100 - 60) / 80, function(x)
		local percent = valveAt(x)
		return string.format("jauges à %d %% du temps  (%s)", percent, if percent < 100 then "plus dur" elseif percent > 100 then "plus facile" else "réglage du jeu")
	end, function(x)
		remote:FireServer("ValveFactor", valveAt(x) / 100)
	end)
	-- Le prédateur de la salle 2 : sa vitesse, en % de celle du palier demandé (réglage du jeu : 92 %).
	local function ratioAt(x: number): number
		return math.floor(60 + x * 50 + 0.5)
	end
	slider("Prédateur (salle 2)", Color3.fromRGB(200, 90, 255), (Config.HUNTER_RATIO * 100 - 60) / 50, function(x)
		local ratio = ratioAt(x)
		return string.format("%d %% du palier  (court à %.1f)", ratio, Config.walkSpeed(Config.ROOMS[2].Hunter.level) * ratio / 100)
	end, function(x)
		remote:FireServer("HunterRatio", ratioAt(x) / 100)
	end)
end

-- Côté joueur : les œufs et les couveuses (étiquettes, œuf visible), les animaux qui suivent les personnages, le vol
-- plané du dragon de lave, et la fenêtre « Animaux » pour choisir celui qu'on équipe.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Pets = require(ReplicatedStorage.Shared.Pets)

local EGG_COLORS = {
	Dragon = Color3.fromRGB(240, 90, 40),
	Rock = Color3.fromRGB(120, 114, 116),
	Rabbit = Color3.fromRGB(250, 250, 250),
	Golem = Color3.fromRGB(120, 170, 120),
	Owl = Color3.fromRGB(170, 120, 70),
}

-- env : les outils de Main.client.luau ({ gui, side, text, box, tr, num, lang, showToast }).
return function(env)
	local player = Players.LocalPlayer
	local tr, showToast = env.tr, env.showToast

	local function clock(seconds: number): string
		seconds = math.max(0, math.ceil(seconds))
		return string.format("%d:%02d", seconds // 60, seconds % 60)
	end
	local function amount(value: number): string
		local text = tostring(value)
		return if env.lang == "fr" then (text:gsub("%.", ",")) else text
	end
	local function rarityInfo(rarity: number)
		return Pets.RARITIES[math.clamp(rarity, 1, #Pets.RARITIES)]
	end

	-- LES MESSAGES --------------------------------------------------------------------------------------------------
	ReplicatedStorage:WaitForChild("Notify").OnClientEvent:Connect(function(key: string, a, b, c)
		if key == "egg" then
			task.delay(1.6, showToast, tr("egg", tr(a)), EGG_COLORS[a])
		elseif key == "eggFull" then
			task.delay(1.6, showToast, tr("eggFull"), Color3.fromRGB(255, 90, 90))
		elseif key == "noEgg" then
			showToast(tr("noEgg"), Color3.fromRGB(255, 90, 90))
		elseif key == "placed" then
			showToast(tr("placed", tr(a)))
		elseif key == "wait" then
			showToast(tr("wait", clock(a)), Color3.fromRGB(255, 221, 51))
		elseif key == "hatched" then
			showToast(tr("hatched", tr(a), tr(rarityInfo(b).key)), rarityInfo(b).color)
		elseif key == "duplicate" then
			showToast(tr("duplicate", tr(a), tr(rarityInfo(b).key), env.num(c)), rarityInfo(b).color)
		end
	end)

	-- LES COUVEUSES -------------------------------------------------------------------------------------------------
	local gym = workspace:WaitForChild("Gym")
	local function refreshIncubators()
		for _, model in gym:GetChildren() do
			local base = model.Name == "Incubator" and model.PrimaryPart
			local prompt = base and base:FindFirstChild("Prompt")
			local label = base and base:FindFirstChild("Label")
			if prompt and label then
				local slot = prompt:GetAttribute("Slot")
				local animal, ready = string.match(player:GetAttribute("Slot" .. slot) or "", "^(%a+)|(%d+)$")
				local egg = model:FindFirstChild("Egg")
				label.Title.Text = tr("incubator", slot)
				prompt.ObjectText = tr("incubator", slot)
				if animal then
					local left = tonumber(ready) - workspace:GetServerTimeNow()
					label.Level.Text = tr(animal)
					label.Info.Text = if left <= 0 then tr("incReady") else clock(left)
					prompt.ActionText = if left <= 0 then tr("incOpen") else tr("incWait")
					if egg then
						egg.Transparency = 0
						egg.Color = EGG_COLORS[animal] or Color3.new(1, 1, 1)
						egg.Material = if left <= 0 then Enum.Material.Neon else Enum.Material.SmoothPlastic
					end
				else
					local eggs = player:GetAttribute("Eggs") or 0
					label.Level.Text = tr("incEmpty")
					label.Info.Text = if eggs > 0 then tr("incHasEggs", eggs) else tr("incNoEggs")
					prompt.ActionText = tr("incPlace")
					if egg then
						egg.Transparency = 1
					end
				end
			end
		end
	end
	task.spawn(function()
		while true do
			refreshIncubators()
			task.wait(0.25)
		end
	end)

	-- LE VOL PLANÉ DU DRAGON ------------------------------------------------------------------------------------------
	-- En l'air, sauter une 2e fois : le dragon passe sous le joueur et le porte quelques secondes.
	local gliding, glideStart, glideEnd, readyAt, lastRequest = false, 0, 0, 0, 0
	local function parts(): (Humanoid?, BasePart?)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and root and humanoid.Health > 0 then
			return humanoid, root
		end
		return nil, nil
	end
	local function startGlide(forced: boolean?)
		local humanoid = parts()
		if not humanoid or gliding or os.clock() < readyAt or player:GetAttribute("Pet") ~= "Dragon" then
			return
		end
		if not forced and humanoid.FloorMaterial ~= Enum.Material.Air then
			return
		end
		gliding = true
		glideStart = os.clock()
		glideEnd = glideStart + Pets.value("Dragon", player:GetAttribute("PetRarity") or 1)
	end
	UserInputService.JumpRequest:Connect(function()
		-- Tant que la touche reste enfoncée, la demande revient à chaque image : seul un nouvel appui compte.
		local now = os.clock()
		local fresh = now - lastRequest > 0.2
		lastRequest = now
		if fresh then
			startGlide()
		end
	end)
	if RunService:IsStudio() then
		-- Pour le test automatique (impossible de simuler une touche).
		player:GetAttributeChangedSignal("DebugGlide"):Connect(function()
			startGlide(true)
		end)
	end
	RunService.Heartbeat:Connect(function()
		if not gliding then
			return
		end
		local humanoid, root = parts()
		local landed = humanoid and humanoid.FloorMaterial ~= Enum.Material.Air and os.clock() - glideStart > 0.25
		if not humanoid or landed or os.clock() >= glideEnd then
			gliding = false
			readyAt = os.clock() + Pets.GLIDE_COOLDOWN
			return
		end
		local velocity = root.AssemblyLinearVelocity
		if velocity.Y < -Pets.GLIDE_FALL then
			root.AssemblyLinearVelocity = Vector3.new(velocity.X, -Pets.GLIDE_FALL, velocity.Z)
		end
	end)

	-- LES ANIMAUX QUI SUIVENT LES JOUEURS -------------------------------------------------------------------------------
	-- Chaque écran dessine lui-même l'animal de chaque joueur (attributs Pet et PetRarity).
	local folder = Instance.new("Folder")
	folder.Name = "Pets"
	folder.Parent = workspace
	local shown = {} -- [joueur] = { key, model, cframe }
	local function drop(other: Player)
		if shown[other] then
			shown[other].model:Destroy()
			shown[other] = nil
		end
	end
	Players.PlayerRemoving:Connect(drop)
	RunService.RenderStepped:Connect(function(dt)
		for _, other in Players:GetPlayers() do
			local name, rarity = other:GetAttribute("Pet") or "", other:GetAttribute("PetRarity") or 0
			local character = other.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if name == "" or not Pets.DEFS[name] or not root then
				drop(other)
				continue
			end
			local key = name .. rarity
			local entry = shown[other]
			if not entry or entry.key ~= key then
				drop(other)
				local model = Pets.build(name, rarity)
				model.Parent = folder
				entry = { key = key, model = model, cframe = root.CFrame }
				shown[other] = entry
			end
			local riding = other == player and gliding
			local target
			if riding then
				target = root.CFrame * CFrame.new(0, -3.4, 0)
			else
				-- Un gros animal se tient un peu plus loin du joueur.
				local away = (Pets.size(name) - 1) * 2.5
				target = root.CFrame * CFrame.new(3.2 + away, 0.6 + away * 0.3 + math.sin(os.clock() * 2.2) * 0.3, 2.6)
			end
			entry.cframe = if riding then target else entry.cframe:Lerp(target, 1 - math.exp(-9 * dt))
			entry.model:PivotTo(entry.cframe)
			Pets.shimmer(entry.model, os.clock())
		end
	end)

	-- LA FENÊTRE « ANIMAUX » ------------------------------------------------------------------------------------------
	local equipEvent = ReplicatedStorage:WaitForChild("Equip")
	local pill = env.box(env.side, "Pets", UDim2.fromOffset(170, 36), UDim2.fromOffset(2, 12 + 4 * 44), Color3.fromRGB(170, 100, 255))
	env.text(pill, "Label", UDim2.fromScale(0.92, 0.76), UDim2.fromScale(0.04, 0.12)).Text = tr("pets")
	local open = Instance.new("TextButton")
	open.Name = "Open"
	open.BackgroundTransparency = 1
	open.Text = ""
	open.Size = UDim2.fromScale(1, 1)
	open.Parent = pill

	local panel = env.box(env.gui, "PetsPanel", UDim2.fromOffset(470, 372), UDim2.fromScale(0.5, 0.5), Color3.fromRGB(40, 44, 60))
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Visible = false
	panel.ZIndex = 5
	local scale = Instance.new("UIScale")
	scale.Parent = panel
	env.text(panel, "Title", UDim2.new(1, -70, 0, 36), UDim2.fromOffset(12, 8), Color3.fromRGB(255, 221, 51)).TextXAlignment = Enum.TextXAlignment.Left
	panel.Title.Text = tr("petsTitle")
	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.Size = UDim2.fromOffset(40, 36)
	close.Position = UDim2.new(1, -50, 0, 8)
	close.BackgroundColor3 = Color3.fromRGB(240, 80, 80)
	close.Font = Enum.Font.FredokaOne
	close.TextScaled = true
	close.TextColor3 = Color3.new(1, 1, 1)
	close.Text = "X"
	Instance.new("UICorner", close).CornerRadius = UDim.new(0, 8)
	close.Parent = panel

	local rows = {}
	for i, name in Pets.ORDER do
		local row = env.box(panel, name, UDim2.new(1, -24, 0, 56), UDim2.fromOffset(12, 52 + (i - 1) * 63), Color3.fromRGB(58, 62, 82))
		local title = env.text(row, "Animal", UDim2.new(1, -140, 0, 26), UDim2.fromOffset(10, 3))
		title.TextXAlignment = Enum.TextXAlignment.Left
		local power = env.text(row, "Power", UDim2.new(1, -140, 0, 20), UDim2.fromOffset(10, 31), Color3.fromRGB(210, 214, 226), 16)
		power.TextXAlignment = Enum.TextXAlignment.Left
		power.UIStroke.Thickness = 1.5
		local button = Instance.new("TextButton")
		button.Name = "Equip"
		button.Size = UDim2.fromOffset(112, 38)
		button.Position = UDim2.new(1, -122, 0, 9)
		button.Font = Enum.Font.FredokaOne
		button.TextScaled = true
		button.TextColor3 = Color3.new(1, 1, 1)
		Instance.new("UICorner", button).CornerRadius = UDim.new(0, 8)
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = button
		button.Parent = row
		button.Activated:Connect(function()
			equipEvent:FireServer(name)
		end)
		rows[name] = { title = title, power = power, button = button }
	end

	local function refreshPanel()
		local owned = Pets.decode(player:GetAttribute("Pets"))
		local equipped = player:GetAttribute("Pet") or ""
		for _, name in Pets.ORDER do
			local row, rarity = rows[name], owned[name]
			if rarity then
				local info = rarityInfo(rarity)
				row.title.Text = tr(name) .. "  " .. tr(info.key)
				row.title.TextColor3 = info.color
				row.power.Text = tr("power" .. Pets.DEFS[name].power, amount(Pets.value(name, rarity)))
				row.button.Visible = true
				row.button.Text = if equipped == name then tr("equipped") else tr("equip")
				row.button.BackgroundColor3 = if equipped == name then Color3.fromRGB(70, 210, 90) else Color3.fromRGB(60, 150, 255)
			else
				row.title.Text = tr(name)
				row.title.TextColor3 = Color3.fromRGB(150, 154, 168)
				row.power.Text = tr("petUnknown")
				row.button.Visible = false
			end
		end
		local view = workspace.CurrentCamera.ViewportSize
		scale.Scale = math.min(1, view.Y / 430, view.X / 520)
	end
	player:GetAttributeChangedSignal("Pets"):Connect(refreshPanel)
	player:GetAttributeChangedSignal("Pet"):Connect(refreshPanel)
	open.Activated:Connect(function()
		panel.Visible = not panel.Visible
		refreshPanel()
	end)
	close.Activated:Connect(function()
		panel.Visible = false
	end)
	refreshPanel()
end

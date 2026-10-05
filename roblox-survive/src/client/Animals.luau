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
	local shown = {} -- [joueur] = { key, model, cframe, half, limbs, clock }
	local function drop(other: Player)
		if shown[other] then
			shown[other].model:Destroy()
			shown[other] = nil
		end
	end
	Players.PlayerRemoving:Connect(drop)

	-- Membres qui se balancent quand l'animal marche : le point d'attache (épaule, hanche) dans le modèle, le sens,
	-- et les pièces du membre. Seul le golem a des bras et des jambes séparés ; les autres modèles sont d'un bloc.
	local LIMBS = {
		Golem = {
			{ pivot = Vector3.new(0.53, 0.04, 0.09), sign = 1, parts = { "UpperLeg1", "LowerLeg1", "Foot1", "Toe1", "Toe2" } },
			{ pivot = Vector3.new(-0.45, 0.04, 0.09), sign = -1, parts = { "UpperLeg2", "LowerLeg2", "Foot2", "Toe3", "Toe4" } },
			{ pivot = Vector3.new(1, 0.95, 0.04), sign = -1, parts = { "UpperArm1", "LowerArm1", "LashesArm1", "Finger1", "Finger2", "Finger3" } },
			{ pivot = Vector3.new(-0.89, 0.95, 0.04), sign = 1, parts = { "UpperArm2", "LowerArm2", "Hand2" } },
		},
	}
	local function rig(name: string, model: Model)
		local limbs = {}
		local origin, scale = model:GetPivot(), model:GetScale()
		for _, limb in LIMBS[name] or {} do
			local list = {}
			for _, part in model:GetDescendants() do
				if part:IsA("BasePart") and table.find(limb.parts, part.Name) then
					table.insert(list, { part = part, offset = origin:ToObjectSpace(part.CFrame) })
				end
			end
			table.insert(limbs, { pivot = limb.pivot * scale, sign = limb.sign, list = list })
		end
		return limbs
	end

	-- La pose de l'animal par-dessus sa place à côté du joueur, selon sa façon de bouger.
	-- t = son horloge, moving = le joueur avance. Renvoie aussi l'angle de balancement des membres.
	local function motion(move: string, t: number, moving: boolean): (CFrame, number)
		if move == "fly" then
			-- Vole : monte et descend, penche le nez en avançant, se balance d'une aile sur l'autre.
			local pitch = if moving then -0.22 else 0.05 * math.sin(t * 2)
			return CFrame.new(0, math.sin(t * 5) * 0.35, 0) * CFrame.Angles(pitch, 0, math.sin(t * 2.5) * 0.12), 0
		elseif move == "bounce" then
			-- Rebondit tout le temps, plus haut quand le joueur avance.
			return CFrame.new(0, math.abs(math.sin(t * 6)) * (if moving then 2.2 else 0.6), 0), 0
		elseif move == "hop" then
			-- Petits bonds quand le joueur avance, le nez qui suit le bond ; immobile sinon.
			if moving then
				return CFrame.new(0, math.abs(math.sin(t * 8)) * 1.5, 0) * CFrame.Angles(math.cos(t * 8) * 0.3, 0, 0), 0
			end
			return CFrame.new(0, math.sin(t * 3) * 0.04, 0), 0
		elseif move == "walk" then
			-- Marche lourde : se dandine, bras et jambes qui se balancent.
			if moving then
				return CFrame.new(0, math.abs(math.sin(t * 7)) * 0.2, 0) * CFrame.Angles(0, 0, math.sin(t * 7) * 0.1), math.sin(t * 7) * 0.6
			end
			return CFrame.Angles(0, 0, math.sin(t * 1.5) * 0.03), 0
		end
		return CFrame.identity, 0
	end

	RunService.RenderStepped:Connect(function(dt)
		for _, other in Players:GetPlayers() do
			local name, rarity = other:GetAttribute("Pet") or "", other:GetAttribute("PetRarity") or 0
			local character = other.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local def = Pets.DEFS[name]
			if name == "" or not def or not root then
				drop(other)
				continue
			end
			local key = name .. rarity
			local entry = shown[other]
			if not entry or entry.key ~= key then
				drop(other)
				local model = Pets.build(name, rarity)
				local _, size = model:GetBoundingBox()
				entry = { key = key, model = model, cframe = root.CFrame, half = size.Y / 2, limbs = rig(name, model), clock = 0 }
				model.Parent = folder
				shown[other] = entry
			end
			entry.clock += dt
			local velocity = root.AssemblyLinearVelocity
			local moving = Vector3.new(velocity.X, 0, velocity.Z).Magnitude > 2
			local riding = other == player and gliding
			local pose, swing
			if riding then
				-- Le dragon porte le joueur : juste sous lui, bien à plat.
				entry.cframe = root.CFrame * CFrame.new(0, -3.4, 0)
				pose, swing = entry.cframe, 0
			else
				-- Un gros animal se tient un peu plus loin du joueur. Celui qui vole reste à hauteur d'épaule,
				-- les autres ont les pieds par terre.
				local away = (Pets.size(name) - 1) * 2.5
				local height = if def.move == "fly" then 1.2 + away * 0.3 else entry.half - 3
				local target = root.CFrame * CFrame.new(3.2 + away, height, 2.6)
				entry.cframe = entry.cframe:Lerp(target, 1 - math.exp(-9 * dt))
				local offset
				offset, swing = motion(def.move, entry.clock, moving)
				pose = entry.cframe * offset
			end
			entry.model:PivotTo(pose)
			for _, limb in entry.limbs do
				local hinge = pose * CFrame.new(limb.pivot) * CFrame.Angles(swing * limb.sign, 0, 0) * CFrame.new(-limb.pivot)
				for _, item in limb.list do
					item.part.CFrame = hinge * item.offset
				end
			end
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

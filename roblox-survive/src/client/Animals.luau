-- Côté joueur : les panneaux des espaces, les familiers exposés dans les enclos de tous les joueurs, celui qui suit
-- chaque personnage, et la fenêtre « Animaux » (la collection et ce qu'elle rapporte).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Pets = require(ReplicatedStorage.Shared.Pets)
local PetRig = require(ReplicatedStorage.Shared.PetRig)

local EGG_COLORS = {
	Dragon = Color3.fromRGB(240, 90, 40),
	Rock = Color3.fromRGB(120, 114, 116),
	Rabbit = Color3.fromRGB(250, 250, 250),
	Golem = Color3.fromRGB(120, 170, 120),
	Owl = Color3.fromRGB(170, 120, 70),
}
local EGG_SPACING = 3.3 -- écart entre deux œufs dans le nid
local ANIMATE_DISTANCE = 110 -- au-delà, les familiers d'un enclos ne sont plus animés (ils restent posés)

-- env : les outils de Main.client.luau ({ gui, side, text, box, tr, num, lang, showToast }).
return function(env)
	local player = Players.LocalPlayer
	local tr, showToast = env.tr, env.showToast
	local gym = workspace:WaitForChild("Gym")

	local function clock(seconds: number): string
		seconds = math.max(0, math.ceil(seconds))
		return string.format("%d:%02d", seconds // 60, seconds % 60)
	end
	-- 2 -> « 2 », 0.5 -> « 0,5 » (ou « 0.5 » en anglais), 1234.5 -> « 1 234 ».
	local function amount(value: number): string
		if value >= 100 or value == math.floor(value) then
			return env.num(value)
		end
		local text = string.format("%.1f", value)
		return if env.lang == "fr" then (text:gsub("%.", ",")) else text
	end
	local function rarityInfo(rarity: number)
		return Pets.RARITIES[math.clamp(rarity, 1, #Pets.RARITIES)]
	end

	-- LES MESSAGES --------------------------------------------------------------------------------------------------
	ReplicatedStorage:WaitForChild("Notify").OnClientEvent:Connect(function(key: string, a, b, c)
		-- Les messages du familier arrivent juste après « SALLE RÉUSSIE » : ils attendent leur tour.
		if key == "egg" then
			task.delay(1.8, showToast, tr("egg", tr(a), clock(b)), EGG_COLORS[a])
		elseif key == "notYours" then
			showToast(tr("notYours"), Color3.fromRGB(255, 90, 90))
		elseif key == "hatched" then
			task.delay(1.8, showToast, tr("hatched", tr(a), tr(rarityInfo(b).key), amount(Pets.incomeOf(a, b))), rarityInfo(b).color)
		elseif key == "duplicate" then
			task.delay(1.8, showToast, tr("duplicate", tr(a), tr(rarityInfo(b).key), env.num(c)), rarityInfo(b).color)
		end
	end)

	-- LES PANNEAUX DES ESPACES ET DES ENCLOS ----------------------------------------------------------------------------
	local function refreshPlots()
		for _, plot in gym:GetChildren() do
			local index = plot:GetAttribute("Index")
			if not index then
				continue
			end
			local owner = plot:GetAttribute("Owner") or ""
			local sign = plot:FindFirstChild("Sign")
			local surface = sign and sign:FindFirstChildOfClass("SurfaceGui")
			local label = surface and surface:FindFirstChild("Label")
			if label then
				label.Text = if owner == "" then tr("plotFree") else tr("plotOwner", owner)
			end
			-- L'enclos : ce que rapporte la collection de son propriétaire.
			local ownerPlayer = Players:GetPlayerByUserId(plot:GetAttribute("OwnerId") or 0)
			local title = plot:FindFirstChild("Enclosure") and plot.Enclosure:FindFirstChild("Title")
			local board = title and title:FindFirstChild("Label")
			if board then
				board.Title.Text = tr("enclosure")
				if ownerPlayer then
					local owned = Pets.decode(ownerPlayer:GetAttribute("Pets"))
					local waiting = ownerPlayer:GetAttribute("EggCount") or 0
					board.Level.Text = tr("collection", Pets.count(owned), #Pets.ORDER * #Pets.RARITIES) .. (if waiting > 0 then "  •  " .. tr("eggsWaiting", waiting) else "")
					board.Info.Text = tr("income", amount(ownerPlayer:GetAttribute("Income") or 0))
				else
					board.Level.Text = ""
					board.Info.Text = ""
				end
			end
		end
	end
	task.spawn(function()
		while true do
			refreshPlots()
			task.wait(0.25)
		end
	end)

	-- COMMENT UN FAMILIER BOUGE -----------------------------------------------------------------------------------------
	-- Membres qui se balancent quand l'animal marche, pour un modèle sans squelette : le point d'attache (épaule,
	-- hanche), le sens, et les pièces du membre. (Les modèles articulés sont animés par PetRig.)
	local LIMBS = {
		Golem = {
			{ pivot = Vector3.new(0.53, 0.04, 0.09), sign = 1, parts = { "UpperLeg1", "LowerLeg1", "Foot1", "Toe1", "Toe2" } },
			{ pivot = Vector3.new(-0.45, 0.04, 0.09), sign = -1, parts = { "UpperLeg2", "LowerLeg2", "Foot2", "Toe3", "Toe4" } },
			{ pivot = Vector3.new(1, 0.95, 0.04), sign = -1, parts = { "UpperArm1", "LowerArm1", "LashesArm1", "Finger1", "Finger2", "Finger3" } },
			{ pivot = Vector3.new(-0.89, 0.95, 0.04), sign = 1, parts = { "UpperArm2", "LowerArm2", "Hand2" } },
		},
	}
	local function limbsOf(name: string, model: Model)
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

	-- La pose de l'animal par-dessus sa place, selon sa façon de bouger.
	-- t = son horloge, moving = il avance. Renvoie aussi l'angle de balancement des membres.
	local function motion(move: string, t: number, moving: boolean): (CFrame, number)
		if move == "fly" then
			local pitch = if moving then -0.22 else 0.05 * math.sin(t * 2)
			return CFrame.new(0, math.sin(t * 5) * 0.35, 0) * CFrame.Angles(pitch, 0, math.sin(t * 2.5) * 0.12), 0
		elseif move == "bounce" then
			return CFrame.new(0, math.abs(math.sin(t * 6)) * (if moving then 2.2 else 0.6), 0), 0
		elseif move == "hop" then
			if moving then
				return CFrame.new(0, math.abs(math.sin(t * 8)) * 1.5, 0) * CFrame.Angles(math.cos(t * 8) * 0.3, 0, 0), 0
			end
			return CFrame.new(0, math.sin(t * 3) * 0.04, 0), 0
		elseif move == "walk" then
			if moving then
				return CFrame.new(0, math.abs(math.sin(t * 7)) * 0.2, 0) * CFrame.Angles(0, 0, math.sin(t * 7) * 0.1), math.sin(t * 7) * 0.6
			end
			return CFrame.Angles(0, 0, math.sin(t * 1.5) * 0.03), 0
		end
		return CFrame.identity, 0
	end

	-- Un familier affiché : son modèle, son squelette (ou ses membres), sa demi-hauteur.
	local function create(name: string, rarity: number, display: boolean, parent: Instance)
		local model = Pets.build(name, rarity, display)
		local _, size = model:GetBoundingBox()
		local skeleton = PetRig.bind(name, model)
		model.Parent = parent
		return {
			name = name,
			model = model,
			half = size.Y / 2,
			skeleton = skeleton,
			limbs = if skeleton then {} else limbsOf(name, model),
			clock = math.random() * 10,
		}
	end
	-- Pose le familier à cet endroit et l'anime.
	local function animate(pet, base: CFrame, moving: boolean, dt: number)
		pet.clock += dt
		local offset, swing = motion(Pets.DEFS[pet.name].move, pet.clock, moving)
		local pose = base * offset
		pet.model:PivotTo(pose)
		PetRig.step(pet.skeleton, pet.clock, moving, dt)
		for _, limb in pet.limbs do
			local hinge = pose * CFrame.new(limb.pivot) * CFrame.Angles(swing * limb.sign, 0, 0) * CFrame.new(-limb.pivot)
			for _, item in limb.list do
				item.part.CFrame = hinge * item.offset
			end
		end
		Pets.shimmer(pet.model, os.clock())
	end

	local folder = Instance.new("Folder")
	folder.Name = "Pets"
	folder.Parent = workspace

	-- LE FAMILIER QUI SUIT CHAQUE JOUEUR --------------------------------------------------------------------------------
	local followers = {} -- [joueur] = { key, pet, cframe }
	local function dropFollower(other: Player)
		if followers[other] then
			followers[other].pet.model:Destroy()
			followers[other] = nil
		end
	end
	Players.PlayerRemoving:Connect(dropFollower)
	local function stepFollowers(dt: number)
		for _, other in Players:GetPlayers() do
			local name, rarity = other:GetAttribute("Pet") or "", other:GetAttribute("PetRarity") or 0
			local character = other.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local def = Pets.DEFS[name]
			if not def or rarity < 1 or not root then
				dropFollower(other)
				continue
			end
			local key = name .. rarity
			local entry = followers[other]
			if not entry or entry.key ~= key then
				dropFollower(other)
				entry = { key = key, pet = create(name, rarity, false, folder), cframe = root.CFrame }
				entry.pet.model.Name = "Follower_" .. name
				followers[other] = entry
			end
			local velocity = root.AssemblyLinearVelocity
			local moving = Vector3.new(velocity.X, 0, velocity.Z).Magnitude > 2
			-- Un gros animal se tient un peu plus loin. Celui qui vole reste à hauteur d'épaule, les autres ont les
			-- pieds par terre.
			local away = (Pets.size(name) - 1) * 2.5
			local height = if def.move == "fly" then 1.2 + away * 0.3 else entry.pet.half - 3
			entry.cframe = entry.cframe:Lerp(root.CFrame * CFrame.new(3.2 + away, height, 2.6), 1 - math.exp(-9 * dt))
			animate(entry.pet, entry.cframe, moving, dt)
		end
	end

	-- LES ENCLOS ------------------------------------------------------------------------------------------------------
	-- Chaque familier trouvé par le propriétaire d'un espace est posé sur son socle (une colonne par animal, une
	-- rangée par rareté). Les socles vides restent sombres.
	local shown = {} -- [socle] = familier affiché
	local function syncEnclosures()
		local wanted = {}
		for _, plot in gym:GetChildren() do
			local enclosure = plot:FindFirstChild("Enclosure")
			local owner = enclosure and Players:GetPlayerByUserId(plot:GetAttribute("OwnerId") or 0)
			if not owner then
				continue
			end
			local owned = Pets.decode(owner:GetAttribute("Pets"))
			for _, pedestal in enclosure:GetChildren() do
				local name, rarity = pedestal:GetAttribute("Animal"), pedestal:GetAttribute("Rarity")
				if name and owned[name] and owned[name][rarity] then
					wanted[pedestal] = true
					if not shown[pedestal] then
						local pet = create(name, rarity, true, folder)
						pet.model.Name = "Enclosure_" .. name .. rarity
						-- Les familiers regardent vers les machines (l'entrée de l'enclos).
						local lift = 0.3 + pet.half + (if Pets.DEFS[name].move == "fly" then 1.2 else 0)
						pet.base = CFrame.new(pedestal.Position + Vector3.new(0, lift, 0))
						pet.model:PivotTo(pet.base)
						-- Le socle prend la couleur vive de la rareté (pas de néon : il éblouirait le familier).
						pedestal.Color = Pets.RARITIES[rarity].color
						shown[pedestal] = pet
					end
				end
			end
		end
		for pedestal, pet in shown do
			if not wanted[pedestal] then
				pet.model:Destroy()
				shown[pedestal] = nil
				if pedestal.Parent then
					pedestal.Color = Pets.RARITIES[pedestal:GetAttribute("Rarity")].color:Lerp(Color3.fromRGB(40, 44, 56), 0.5)
					pedestal.Material = Enum.Material.SmoothPlastic
				end
			end
		end
	end
	task.spawn(function()
		while true do
			syncEnclosures()
			task.wait(0.5)
		end
	end)

	-- LES ŒUFS DANS LE NID ----------------------------------------------------------------------------------------------
	-- Les œufs du propriétaire de chaque espace, alignés devant les socles, avec le temps qu'il leur reste.
	local nests = {} -- [dossier de l'enclos] = liste d'œufs affichés
	local function eggAt(list, i: number, enclosure: Instance)
		local item = list[i]
		if not item then
			local part = Instance.new("Part")
			part.Name = "Egg"
			part.Shape = Enum.PartType.Ball
			part.Size = Vector3.new(2.4, 2.4, 2.4)
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.TopSurface = Enum.SurfaceType.Smooth
			part.BottomSurface = Enum.SurfaceType.Smooth
			-- Un œuf est plus haut que large.
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Scale = Vector3.new(1, 1.3, 1)
			mesh.Parent = part
			local gui = Instance.new("BillboardGui")
			gui.Size = UDim2.fromScale(4, 1.4)
			gui.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
			gui.MaxDistance = 60
			gui.AutoLocalize = false
			gui.Parent = part
			local label = env.text(gui, "Label", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0))
			part.Position = enclosure:GetAttribute("Nest") + Vector3.new((i - 1) * EGG_SPACING, 1.9, 0)
			part.Parent = folder
			item = { part = part, label = label }
			list[i] = item
		end
		return item
	end
	local function syncEggs()
		local seen = {}
		for _, plot in gym:GetChildren() do
			local enclosure = plot:FindFirstChild("Enclosure")
			local owner = enclosure and Players:GetPlayerByUserId(plot:GetAttribute("OwnerId") or 0)
			local list = enclosure and (nests[enclosure] or {})
			if not enclosure then
				continue
			end
			nests[enclosure] = list
			seen[enclosure] = true
			local count = 0
			for animal, ready in string.gmatch(owner and owner:GetAttribute("Eggs") or "", "(%a+)|(%d+)") do
				count += 1
				local item = eggAt(list, count, enclosure)
				local left = tonumber(ready) - workspace:GetServerTimeNow()
				item.part.Color = EGG_COLORS[animal] or Color3.new(1, 1, 1)
				item.part.Material = if left <= 0 then Enum.Material.Neon else Enum.Material.SmoothPlastic
				item.label.Text = clock(left)
			end
			for i = #list, count + 1, -1 do
				list[i].part:Destroy()
				list[i] = nil
			end
		end
	end
	task.spawn(function()
		while true do
			syncEggs()
			task.wait(0.25)
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		stepFollowers(dt)
		local eye = workspace.CurrentCamera.CFrame.Position
		for _, pet in shown do
			if (pet.base.Position - eye).Magnitude < ANIMATE_DISTANCE then
				animate(pet, pet.base, false, dt)
			end
		end
	end)

	-- LA FENÊTRE « ANIMAUX » : LA COLLECTION ----------------------------------------------------------------------------
	local equipEvent = ReplicatedStorage:WaitForChild("Equip")
	local pill = env.box(env.side, "Pets", UDim2.fromOffset(170, 36), UDim2.fromOffset(2, 12 + 4 * 44), Color3.fromRGB(170, 100, 255))
	env.text(pill, "Label", UDim2.fromScale(0.92, 0.76), UDim2.fromScale(0.04, 0.12)).Text = tr("pets")
	local open = Instance.new("TextButton")
	open.Name = "Open"
	open.BackgroundTransparency = 1
	open.Text = ""
	open.Size = UDim2.fromScale(1, 1)
	open.Parent = pill

	local panel = env.box(env.gui, "PetsPanel", UDim2.fromOffset(560, 404), UDim2.fromScale(0.5, 0.5), Color3.fromRGB(40, 44, 60))
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Visible = false
	panel.ZIndex = 5
	local scale = Instance.new("UIScale")
	scale.Parent = panel
	local title = env.text(panel, "Title", UDim2.new(1, -70, 0, 32), UDim2.fromOffset(12, 6), Color3.fromRGB(255, 221, 51))
	title.TextXAlignment = Enum.TextXAlignment.Left
	local income = env.text(panel, "Income", UDim2.new(1, -24, 0, 24), UDim2.fromOffset(12, 40), Color3.fromRGB(110, 255, 80))
	income.TextXAlignment = Enum.TextXAlignment.Left
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

	-- Une ligne par animal : son nom, quatre cases (une par rareté) et le bouton pour qu'il suive le joueur.
	local rows = {}
	for i, name in Pets.ORDER do
		local row = env.box(panel, name, UDim2.new(1, -24, 0, 60), UDim2.fromOffset(12, 72 + (i - 1) * 65), Color3.fromRGB(58, 62, 82))
		local label = env.text(row, "Animal", UDim2.fromOffset(150, 30), UDim2.fromOffset(8, 15))
		label.TextXAlignment = Enum.TextXAlignment.Left
		local cells = {}
		for rarity, info in Pets.RARITIES do
			local cell = env.box(row, "Rarity" .. rarity, UDim2.fromOffset(62, 44), UDim2.fromOffset(164 + (rarity - 1) * 68, 8), info.color)
			cell.UIStroke.Thickness = 2
			cells[rarity] = { frame = cell, label = env.text(cell, "Label", UDim2.fromScale(0.9, 0.6), UDim2.fromScale(0.05, 0.2)) }
		end
		local button = Instance.new("TextButton")
		button.Name = "Follow"
		button.Size = UDim2.fromOffset(86, 38)
		button.Position = UDim2.new(1, -94, 0, 11)
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
		rows[name] = { label = label, cells = cells, button = button }
	end

	local function refreshPanel()
		local owned = Pets.decode(player:GetAttribute("Pets"))
		local following = player:GetAttribute("Pet") or ""
		title.Text = tr("petsTitle", Pets.count(owned), #Pets.ORDER * #Pets.RARITIES)
		income.Text = tr("income", amount(Pets.income(owned)))
		for _, name in Pets.ORDER do
			local row, list = rows[name], owned[name] or {}
			row.label.Text = tr(name)
			for rarity, info in Pets.RARITIES do
				local cell = row.cells[rarity]
				cell.frame.BackgroundColor3 = if list[rarity] then info.color else info.color:Lerp(Color3.fromRGB(40, 44, 60), 0.75)
				cell.label.Text = if list[rarity] then "+" .. amount(Pets.incomeOf(name, rarity)) else "?"
				cell.label.TextTransparency = if list[rarity] then 0 else 0.5
			end
			row.button.Visible = Pets.best(list) > 0
			row.button.Text = if following == name then tr("following") else tr("follow")
			row.button.BackgroundColor3 = if following == name then Color3.fromRGB(70, 210, 90) else Color3.fromRGB(60, 150, 255)
		end
		local view = workspace.CurrentCamera.ViewportSize
		scale.Scale = math.min(1, view.Y / 460, view.X / 600)
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

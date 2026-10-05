-- Côté joueur : les panneaux des espaces, la boutique des œufs, les places des enclos de tous les joueurs (œufs qui
-- couvent, familiers), le familier qui suit chaque personnage, et la fenêtre « Animaux » (son enclos en liste).
local CollectionService = game:GetService("CollectionService")
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
local ANIMATE_DISTANCE = 110 -- au-delà, les familiers d'un enclos ne sont plus animés (ils restent posés)
local DARK = Color3.fromRGB(40, 44, 56)
local RED = Color3.fromRGB(255, 90, 90)

-- env : les outils de Main.client.luau ({ gui, side, text, box, tr, num, lang, showToast }).
return function(env)
	local player = Players.LocalPlayer
	local tr, showToast = env.tr, env.showToast
	local gym = workspace:WaitForChild("Gym")

	local function clock(seconds: number): string
		seconds = math.max(0, math.ceil(seconds))
		return string.format("%d:%02d", seconds // 60, seconds % 60)
	end
	-- 2 -> « 2 », 0.53 -> « 0,5 » (ou « 0.5 » en anglais), 1234.5 -> « 1 234 ».
	local function amount(value: number): string
		if value >= 100 or value == math.floor(value) then
			return env.num(value)
		end
		local text = string.format(if value < 1 then "%.2f" else "%.1f", value)
		return if env.lang == "fr" then (text:gsub("%.", ",")) else text
	end
	local function rarityInfo(rarity: number)
		return Pets.RARITIES[math.clamp(rarity, 1, #Pets.RARITIES)]
	end

	-- LES MESSAGES --------------------------------------------------------------------------------------------------
	ReplicatedStorage:WaitForChild("Notify").OnClientEvent:Connect(function(key: string, a, b, c)
		if key == "ticket" then
			-- Arrive juste après « SALLE RÉUSSIE » : attend son tour.
			task.delay(1.8, showToast, tr("ticket", a), Color3.fromRGB(255, 221, 51))
		elseif key == "exchanged" then
			showToast(tr("exchanged", a))
		elseif key == "noTicket" or key == "noEgg" or key == "goShop" or key == "notYours" then
			showToast(tr(key), RED)
		elseif key == "placed" then
			showToast(tr("placed", tr(a), tr(rarityInfo(b).key), clock(c)), rarityInfo(b).color)
		elseif key == "wait" then
			showToast(tr("wait", clock(a)), Color3.fromRGB(255, 221, 51))
		elseif key == "hatched" then
			showToast(tr("hatched", tr(a), tr(rarityInfo(b).key), amount(c)), rarityInfo(b).color)
		elseif key == "sold" then
			showToast(tr("sold", tr(a), env.num(b)))
		elseif key == "placeBought" then
			showToast(tr("placeBought", a))
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

	-- LES PLACES DES ENCLOS ---------------------------------------------------------------------------------------------
	-- Sur chaque place : rien (libre ou fermée), un œuf qui couve avec son temps, ou un familier avec ce qu'il rapporte.
	-- Tout le monde voit l'enclos de tout le monde ; seul le propriétaire a les boutons.
	local shown = {} -- [place] = { key, pet ou egg, label }
	local function clear(pad: Instance)
		local item = shown[pad]
		if item then
			if item.pet then
				item.pet.model:Destroy()
			end
			if item.egg then
				item.egg:Destroy()
			end
			shown[pad] = nil
		end
	end
	local function tagOf(pad: BasePart): TextLabel
		local gui = pad:FindFirstChild("Tag")
		if not gui then
			gui = Instance.new("BillboardGui")
			gui.Name = "Tag"
			gui.Size = UDim2.fromScale(6, 1.3)
			gui.StudsOffsetWorldSpace = Vector3.new(0, 1.6, 2.9)
			gui.MaxDistance = 55
			gui.AutoLocalize = false
			gui.Parent = pad
			env.text(gui, "Label", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0))
		end
		return gui.Label
	end
	local function makeEgg(pad: BasePart, animal: string): Part
		local part = Instance.new("Part")
		part.Name = "Egg"
		part.Shape = Enum.PartType.Ball
		part.Size = Vector3.new(2.6, 2.6, 2.6)
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Color = EGG_COLORS[animal] or Color3.new(1, 1, 1)
		-- Un œuf est plus haut que large.
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Scale = Vector3.new(1, 1.3, 1)
		mesh.Parent = part
		part.Position = pad.Position + Vector3.new(0, 2, 0)
		part.Parent = folder
		return part
	end

	local function syncSpots()
		local mine = player:GetAttribute("Plot") or 0
		local bag = player:GetAttribute("Bag") or 0
		local seen = {}
		for _, plot in gym:GetChildren() do
			local enclosure = plot:FindFirstChild("Enclosure")
			if not enclosure then
				continue
			end
			local own = plot:GetAttribute("Index") == mine
			local owner = Players:GetPlayerByUserId(plot:GetAttribute("OwnerId") or 0)
			local spots = Pets.decode(owner and owner:GetAttribute("Spots"))
			local places = owner and owner:GetAttribute("Places") or 0
			for _, pad in enclosure:GetChildren() do
				local index = pad:GetAttribute("Spot")
				if not index then
					continue
				end
				seen[pad] = true
				local spot = spots[tostring(index)]
				local prompt = pad:FindFirstChild("Prompt")
				local label = tagOf(pad)
				local key = if not spot then "" elseif spot.v then "v" .. spot.a .. spot.q .. spot.v else "t" .. spot.a .. spot.q
				if not shown[pad] or shown[pad].key ~= key then
					clear(pad)
					local item = { key = key }
					if spot and spot.v then
						item.pet = create(spot.a, spot.q, true, folder)
						item.pet.model.Name = "Pen_" .. spot.a .. spot.q
						local lift = 0.3 + item.pet.half + (if Pets.DEFS[spot.a].move == "fly" then 1.2 else 0)
						item.pet.base = CFrame.new(pad.Position + Vector3.new(0, lift, 0))
						item.pet.model:PivotTo(item.pet.base)
					elseif spot then
						item.egg = makeEgg(pad, spot.a)
					end
					shown[pad] = item
				end

				-- La couleur de la place, son étiquette et son bouton.
				local action, hold, enabled = "", 0.25, false
				if index > places then
					pad.Color = Color3.fromRGB(34, 36, 46)
					local price = owner and index == places + 1 and Pets.spotPrice(places)
					label.Text = if price and own then env.num(price) else ""
					label.TextColor3 = Color3.fromRGB(255, 221, 51)
					if price and own then
						action, enabled = tr("spotBuy", env.num(price)), true
					end
				elseif not spot then
					pad.Color = Color3.fromRGB(96, 104, 126)
					label.Text = if own then tr("spotEmpty") else ""
					label.TextColor3 = Color3.new(1, 1, 1)
					if own then
						action, enabled = tr("spotPlace", bag), true
					end
				elseif spot.t then
					local info = rarityInfo(spot.q)
					local left = spot.t - workspace:GetServerTimeNow()
					pad.Color = info.color
					label.Text = tr(info.key) .. "  " .. clock(left)
					label.TextColor3 = info.color
					shown[pad].egg.Material = if left <= 0 then Enum.Material.Neon else Enum.Material.SmoothPlastic
				else
					local info = rarityInfo(spot.q)
					pad.Color = info.color
					label.Text = tr("perSecond", amount(Pets.incomeOf(spot.a, spot.v)))
					label.TextColor3 = Color3.fromRGB(110, 255, 80)
					if own then
						-- Vendre demande d'appuyer plus longtemps, pour ne pas le faire par erreur.
						action, hold, enabled = tr("spotSell", env.num(Pets.sellPrice(spot.a, spot.v))), 1.2, true
					end
				end
				if prompt then
					prompt.Enabled = enabled
					prompt.ObjectText = if spot then tr(spot.a) .. "  " .. tr(rarityInfo(spot.q).key) else tr("spotName", index)
					prompt.ActionText = action
					prompt.HoldDuration = hold
				end
			end

			-- Le panneau de l'espace et celui de l'enclos.
			local ownerName = plot:GetAttribute("Owner") or ""
			local sign = plot:FindFirstChild("Sign")
			local surface = sign and sign:FindFirstChildOfClass("SurfaceGui")
			local plotLabel = surface and surface:FindFirstChild("Label")
			if plotLabel then
				plotLabel.Text = if ownerName == "" then tr("plotFree") else tr("plotOwner", ownerName)
			end
			local title = enclosure:FindFirstChild("Title")
			local board = title and title:FindFirstChild("Label")
			if board then
				board.Title.Text = tr("enclosure")
				if owner then
					local pets, eggs = Pets.count(spots)
					board.Level.Text = tr("penCount", pets, eggs)
					board.Info.Text = tr("income", amount(owner:GetAttribute("Income") or 0))
				else
					board.Level.Text = ""
					board.Info.Text = ""
				end
			end
		end
		for pad in shown do
			if not seen[pad] then
				clear(pad)
			end
		end
		-- La boutique : combien de tickets le joueur peut échanger.
		local shop = gym:FindFirstChild("Shop")
		local shopPrompt = shop and shop:FindFirstChild("Prompt")
		if shopPrompt then
			local tickets = player:GetAttribute("Tickets") or 0
			shopPrompt.ObjectText = tr("shopName")
			shopPrompt.ActionText = if tickets > 0 then tr("shopGo", tickets) else tr("shopEmpty")
		end
	end
	task.spawn(function()
		while true do
			syncSpots()
			task.wait(0.25)
		end
	end)

	-- LE MONSTRE DES SALLES DE COURSE -------------------------------------------------------------------------------------
	-- Le serveur déplace un bloc invisible étiqueté « Chaser » ; un grand golem est dessiné dessus, qui marche.
	local chasers = {} -- [bloc] = familier affiché
	local function stepChasers(dt: number)
		for _, part in CollectionService:GetTagged("Chaser") do
			if not chasers[part] and part:IsDescendantOf(workspace) then
				local pet = create("Golem", 1, true, folder)
				pet.model.Name = "Chaser"
				pet.model:ScaleTo(pet.model:GetScale() * 3.2)
				local _, size = pet.model:GetBoundingBox()
				pet.half = size.Y / 2
				-- Le modèle a grossi : ses membres et son squelette sont repris à la nouvelle taille.
				pet.skeleton = PetRig.bind("Golem", pet.model)
				pet.limbs = if pet.skeleton then {} else limbsOf("Golem", pet.model)
				pet.last = part.Position
				chasers[part] = pet
			end
		end
		for part, pet in chasers do
			if not part:IsDescendantOf(workspace) then
				pet.model:Destroy()
				chasers[part] = nil
				continue
			end
			local moving = (part.Position - pet.last).Magnitude > 0.01
			pet.last = part.Position
			-- Le bloc est à 6 studs du sol : le monstre a les pieds par terre.
			animate(pet, part.CFrame * CFrame.new(0, pet.half - 6, 0), moving, dt)
		end
	end

	RunService.RenderStepped:Connect(function(dt)
		stepFollowers(dt)
		stepChasers(dt)
		local eye = workspace.CurrentCamera.CFrame.Position
		for _, item in shown do
			local pet = item.pet
			if pet and (pet.base.Position - eye).Magnitude < ANIMATE_DISTANCE then
				animate(pet, pet.base, false, dt)
			end
		end
	end)

	-- LA FENÊTRE « ANIMAUX » : SON ENCLOS EN LISTE ----------------------------------------------------------------------
	local equipEvent = ReplicatedStorage:WaitForChild("Equip")
	local pill = env.box(env.side, "Pets", UDim2.fromOffset(170, 36), UDim2.fromOffset(2, 12 + 4 * 44), Color3.fromRGB(170, 100, 255))
	env.text(pill, "Label", UDim2.fromScale(0.92, 0.76), UDim2.fromScale(0.04, 0.12)).Text = tr("pets")
	local open = Instance.new("TextButton")
	open.Name = "Open"
	open.BackgroundTransparency = 1
	open.Text = ""
	open.Size = UDim2.fromScale(1, 1)
	open.Parent = pill
	-- Sous le bouton : les tickets à échanger et les œufs à poser.
	local stock = env.text(env.side, "Stock", UDim2.fromOffset(230, 18), UDim2.fromOffset(2, 12 + 5 * 44 - 6), Color3.fromRGB(255, 221, 51))
	stock.TextXAlignment = Enum.TextXAlignment.Left
	stock.UIStroke.Thickness = 1.5

	local panel = env.box(env.gui, "PetsPanel", UDim2.fromOffset(520, 420), UDim2.fromScale(0.5, 0.5), Color3.fromRGB(40, 44, 60))
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Visible = false
	panel.ZIndex = 5
	local scale = Instance.new("UIScale")
	scale.Parent = panel
	local title = env.text(panel, "Title", UDim2.new(1, -70, 0, 30), UDim2.fromOffset(12, 6), Color3.fromRGB(255, 221, 51))
	title.TextXAlignment = Enum.TextXAlignment.Left
	local income = env.text(panel, "Income", UDim2.new(1, -24, 0, 22), UDim2.fromOffset(12, 38), Color3.fromRGB(110, 255, 80))
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

	-- Une ligne par place de l'enclos (deux colonnes de six).
	local rows = {}
	for index = 1, Pets.SPOTS_MAX do
		local column, line = (index - 1) // 6, (index - 1) % 6
		local row = env.box(panel, "Spot" .. index, UDim2.fromOffset(244, 50), UDim2.fromOffset(12 + column * 252, 68 + line * 57), Color3.fromRGB(58, 62, 82))
		row.UIStroke.Thickness = 2
		local name = env.text(row, "Animal", UDim2.fromOffset(150, 22), UDim2.fromOffset(8, 3), nil, 18)
		name.TextXAlignment = Enum.TextXAlignment.Left
		local info = env.text(row, "Info", UDim2.fromOffset(150, 18), UDim2.fromOffset(8, 27), Color3.fromRGB(110, 255, 80), 15)
		info.TextXAlignment = Enum.TextXAlignment.Left
		info.UIStroke.Thickness = 1.5
		local button = Instance.new("TextButton")
		button.Name = "Follow"
		button.Size = UDim2.fromOffset(74, 32)
		button.Position = UDim2.new(1, -80, 0, 9)
		button.Font = Enum.Font.FredokaOne
		button.TextScaled = true
		button.TextColor3 = Color3.new(1, 1, 1)
		Instance.new("UICorner", button).CornerRadius = UDim.new(0, 8)
		button.Parent = row
		button.Activated:Connect(function()
			equipEvent:FireServer(index)
		end)
		rows[index] = { frame = row, name = name, info = info, button = button }
	end

	local function refreshPanel()
		local spots = Pets.decode(player:GetAttribute("Spots"))
		local places = player:GetAttribute("Places") or Pets.SPOTS_FREE
		local following = player:GetAttribute("PetSpot") or ""
		title.Text = tr("penTitle", places, Pets.SPOTS_MAX)
		income.Text = tr("income", amount(Pets.income(spots))) .. "     " .. tr("stock", player:GetAttribute("Tickets") or 0, player:GetAttribute("Bag") or 0)
		stock.Text = tr("stock", player:GetAttribute("Tickets") or 0, player:GetAttribute("Bag") or 0)
		for index, row in rows do
			local spot = spots[tostring(index)]
			row.button.Visible = spot ~= nil and spot.v ~= nil
			if index > places then
				row.frame.BackgroundColor3 = Color3.fromRGB(34, 36, 46)
				row.name.Text = tr("spotLocked")
				row.name.TextColor3 = Color3.fromRGB(150, 154, 168)
				row.info.Text = ""
			elseif not spot then
				row.frame.BackgroundColor3 = Color3.fromRGB(58, 62, 82)
				row.name.Text = tr("spotEmpty")
				row.name.TextColor3 = Color3.new(1, 1, 1)
				row.info.Text = ""
			else
				local info = rarityInfo(spot.q)
				row.frame.BackgroundColor3 = info.color:Lerp(DARK, 0.7)
				row.name.Text = tr(spot.a)
				row.name.TextColor3 = info.color
				if spot.v then
					row.info.Text = tr(info.key) .. "  " .. tr("perSecond", amount(Pets.incomeOf(spot.a, spot.v)))
					row.button.Text = if following == tostring(index) then tr("following") else tr("follow")
					row.button.BackgroundColor3 = if following == tostring(index) then Color3.fromRGB(70, 210, 90) else Color3.fromRGB(60, 150, 255)
				else
					row.info.Text = tr(info.key) .. "  " .. clock(spot.t - workspace:GetServerTimeNow())
				end
			end
		end
		local view = workspace.CurrentCamera.ViewportSize
		scale.Scale = math.min(1, view.Y / 470, view.X / 560)
	end
	for _, name in { "Spots", "Places", "PetSpot", "Tickets", "Bag" } do
		player:GetAttributeChangedSignal(name):Connect(refreshPanel)
	end
	task.spawn(function()
		-- Les temps de couvaison de la fenêtre avancent tant qu'elle est ouverte.
		while true do
			if panel.Visible then
				refreshPanel()
			end
			task.wait(1)
		end
	end)
	open.Activated:Connect(function()
		panel.Visible = not panel.Visible
		refreshPanel()
	end)
	close.Activated:Connect(function()
		panel.Visible = false
	end)
	refreshPanel()
end

-- Côté joueur, tout ce qui touche aux familiers :
--   les enclos de tous les joueurs (familiers qui s'y promènent, œufs posés avec leur temps, gains qui s'envolent),
--   l'œuf que chaque joueur porte sur la tête, le familier qui le suit, le monstre des salles de course,
--   et les boutons de droite : l'œuf (déplie « Œufs en croissance ») et la patte (déplie la liste de ses familiers).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Pets = require(ReplicatedStorage.Shared.Pets)
local PetRig = require(ReplicatedStorage.Shared.PetRig)
local StarterAnimator = require(ReplicatedStorage.Shared.StarterAnimator)

local EGG_COLORS = {
	Dragon = Color3.fromRGB(240, 90, 40),
	Rock = Color3.fromRGB(120, 114, 116),
	Rabbit = Color3.fromRGB(250, 250, 250),
	Golem = Color3.fromRGB(120, 170, 120),
	Owl = Color3.fromRGB(170, 120, 70),
}
-- Les œufs d'une salle à collection ont la couleur de la salle (l'animal ne se voit qu'à l'éclosion).
for room, color in { Color3.fromRGB(255, 226, 150), Color3.fromRGB(190, 140, 90), Color3.fromRGB(250, 245, 235), Color3.fromRGB(120, 150, 110), Color3.fromRGB(70, 190, 110) } do
	for _, name in Pets.COLLECTIONS[room] or {} do
		EGG_COLORS[name] = color
	end
end
local ANIMATE_DISTANCE = 120 -- au-delà, les familiers d'un enclos ne bougent plus (ils restent où ils sont)
local PEN_SCALE = 1.5 -- les familiers de l'enclos sont plus gros que celui qui suit le joueur
local WALK_SPEED = 1.8 -- animaux des collections : la marche est jouée plus vite que le clip livré...
local WALK_GAIN = 2.4 -- ... et les pattes tournent plus (voir StarterAnimator)
local PEN_WALK = 3 -- studs par seconde d'un animal des collections qui se promène (les autres : 4,5)
local DARK = Color3.fromRGB(40, 44, 60)
local RED = Color3.fromRGB(255, 90, 90)
local GREEN = Color3.fromRGB(110, 255, 80)

-- env : les outils de Main.client.luau ({ gui, side, text, box, tr, num, lang, showToast }).
return function(env)
	local player = Players.LocalPlayer
	local tr, showToast = env.tr, env.showToast
	local gym = workspace:WaitForChild("Gym")

	local function clock(seconds: number): string
		seconds = math.max(0, math.ceil(seconds))
		if seconds < 60 then
			return seconds .. " s"
		end
		return string.format("%d:%02d", seconds // 60, seconds % 60)
	end
	-- 2 -> « 2 », 0.53 -> « 0,53 » (ou « 0.53 » en anglais), 1234.5 -> « 1 234 ».
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

	local folder = Instance.new("Folder")
	folder.Name = "Pets"
	folder.Parent = workspace

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

	-- Un familier affiché : son modèle, son squelette (ou ses membres), sa demi-hauteur. factor : grossissement.
	local function create(name: string, rarity: number, display: boolean, factor: number?)
		local model = Pets.build(name, rarity, display)
		if factor and factor ~= 1 then
			model:ScaleTo(model:GetScale() * factor)
		end
		local _, size = model:GetBoundingBox()
		-- Un animal des collections a ses propres animations (repos, marche), lues par StarterAnimator.
		local starter = nil
		if model:GetAttribute("Starter") then
			local ok, rig = pcall(StarterAnimator.bind, model)
			if ok then
				starter = rig
			else
				warn("[Survive] animation de " .. name .. " impossible : " .. tostring(rig))
			end
		end
		local skeleton = if model:GetAttribute("Starter") then nil else PetRig.bind(name, model)
		model.Parent = folder
		return {
			name = name,
			model = model,
			half = size.Y / 2,
			starter = starter,
			skeleton = skeleton,
			limbs = if skeleton then {} else limbsOf(name, model),
			clock = math.random() * 10,
		}
	end
	-- Pose le familier à cet endroit et l'anime.
	local function animate(pet, base: CFrame, moving: boolean, dt: number)
		pet.clock += dt
		if pet.model:GetAttribute("Starter") then
			-- La marche livrée est discrète : on la joue plus vite, les pattes tournent plus, et le corps sautille
			-- à chaque pas (deux pas par tour d'animation), pour qu'on voie l'animal marcher et non glisser.
			local walk = pet.starter and pet.starter.clips.Walk
			local hop = 0
			if moving and walk then
				hop = math.abs(math.sin(pet.clock * WALK_SPEED / walk.duration * math.pi * 2)) * 0.16 * pet.model:GetScale()
			end
			pet.model:PivotTo(base * CFrame.new(0, hop, 0))
			if pet.starter then
				if moving then
					StarterAnimator.step(pet.starter, pet.clock * WALK_SPEED, "Walk", WALK_GAIN)
				else
					StarterAnimator.step(pet.starter, pet.clock, "Idle", 1.5)
				end
			end
			return
		end
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

	-- Un œuf (plus haut que large), de la couleur de son animal.
	-- La grosseur de l'oeuf dit ce que vaudra le familier DANS SON RANG : along = 0 (tout en bas du palier de son
	-- animal) a 1 (tout en haut). Un gros oeuf de renard donne un renard qui rapporte le maximum.
	local function eggSize(base: number, along: number?): number
		return base * (0.3 + 1.7 * math.clamp(along or 0.5, 0, 1)) -- de 30 % (le moins bon) a 200 % (le meilleur) : "je veux vraiment une grosse diff"
	end
	local function makeEgg(animal: string, size: number): Part
		local part = Instance.new("Part")
		part.Name = "Egg"
		part.Shape = Enum.PartType.Ball
		part.Size = Vector3.new(size, size, size)
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Color = EGG_COLORS[animal] or Color3.new(1, 1, 1)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Scale = Vector3.new(1, 1.3, 1)
		mesh.Parent = part
		part.Parent = folder
		-- LES OEUFS DES COLLECTIONS (assets/collections/oeufs) : chaque animal des salles 1 a 5 a son oeuf en briques
		-- (arc-en-ciel pour les super rares). La boule devient invisible et sert de poignee : le modele y est soude,
		-- pose sur son socle, et la suit quand on la deplace. Les autres animaux gardent la boule de couleur.
		local visuals = ReplicatedStorage:FindFirstChild("EggVisuals")
		local template = visuals and visuals:FindFirstChild(animal)
		if template and template:IsA("Model") and template.PrimaryPart then
			local model = template:Clone()
			model.Name = "EggModel"
			local _, bounds = model:GetBoundingBox()
			model:ScaleTo(size * 1.3 / math.max(bounds.Y, 0.1))
			for _, item in model:GetDescendants() do
				if item:IsA("BasePart") then
					item.Anchored = true
					item.CanCollide = false
					item.CanQuery = false
					item.CanTouch = false
				end
			end
			model.Parent = part
			part:SetAttribute("Lift", size * 0.65)
			part.Transparency = 1
		end
		return part
	end
	-- Repose le modele de l'oeuf sur sa boule (a appeler apres avoir deplace la boule). Le pivot du modele est a son
	-- pied : il est pose au bas de la boule. (Les pieces restent ancrees : pas de soudure, pas de physique.)
	local function settleEgg(part: BasePart)
		local model = part:FindFirstChild("EggModel")
		if model then
			model:PivotTo(CFrame.new(part.Position - Vector3.new(0, part:GetAttribute("Lift") or 0, 0)) * part.CFrame.Rotation)
		end
	end

	-- Une étiquette qui flotte au-dessus d'une pièce : deux lignes.
	local function tag(part: BasePart, height: number): (TextLabel, TextLabel)
		local gui = Instance.new("BillboardGui")
		gui.Name = "Tag"
		gui.Size = UDim2.fromScale(7, 2.6)
		gui.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
		gui.MaxDistance = 70
		gui.AutoLocalize = false
		gui.Parent = part
		local top = env.text(gui, "Top", UDim2.fromScale(1, 0.46), UDim2.fromScale(0, 0))
		local bottom = env.text(gui, "Bottom", UDim2.fromScale(1, 0.54), UDim2.fromScale(0, 0.46), GREEN)
		return top, bottom
	end

	-- LE FAMILIER QUI SUIT CHAQUE JOUEUR, ET L'ŒUF QU'IL PORTE -----------------------------------------------------------
	local followers = {} -- [joueur] = { key, pet, cframe }
	local carried = {} -- [joueur] = { key, egg }
	local lifts = {} -- [joueur] = { key, pet } : le familier porté à bout de bras pour aller le vendre
	local function dropFollower(other: Player)
		if followers[other] then
			followers[other].pet.model:Destroy()
			followers[other] = nil
		end
	end
	local function dropCarried(other: Player)
		if carried[other] then
			carried[other].egg:Destroy()
			carried[other] = nil
		end
	end
	Players.PlayerRemoving:Connect(function(other)
		dropFollower(other)
		dropCarried(other)
		if lifts[other] then
			lifts[other].pet.model:Destroy()
			lifts[other] = nil
		end
	end)
	local function stepPlayers(dt: number)
		for _, other in Players:GetPlayers() do
			local character = other.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local head = character and character:FindFirstChild("Head")

			-- L'œuf à poser, porté au-dessus de la tête.
			local nextEgg = other:GetAttribute("BagNext") or ""
			if nextEgg == "" or not head then
				dropCarried(other)
			else
				local item = carried[other]
				if not item or item.key ~= nextEgg then
					dropCarried(other)
					local size = eggSize(2.2, (tonumber(string.match(nextEgg, ":%d+:(%d+)")) or 50) / 100)
					item = { key = nextEgg, egg = makeEgg(string.match(nextEgg, "^%a+") or "", size), lift = 1 + size * 0.65 }
					item.egg.Name = "CarriedEgg"
					carried[other] = item
				end
				item.egg.CFrame = CFrame.new((head.CFrame * CFrame.new(0, item.lift, 0)).Position)
				settleEgg(item.egg)
			end

			-- Le familier porté à bout de bras, pour aller le vendre (« animal:rang:grosseur »).
			local heldPet = other:GetAttribute("HeldPet") or ""
			local lifted = lifts[other]
			if heldPet == "" or not head then
				if lifted then
					lifted.pet.model:Destroy()
					lifts[other] = nil
				end
			else
				if not lifted or lifted.key ~= heldPet then
					if lifted then
						lifted.pet.model:Destroy()
					end
					local petName, rank, size = string.match(heldPet, "^(%a+):(%d+):(%d+)$")
					lifted = { key = heldPet, pet = create(petName, tonumber(rank), true, 0.4 + 1.6 * tonumber(size) / 100) }
					lifted.pet.model.Name = "Held_" .. petName
					lifts[other] = lifted
				end
				local above = (head.CFrame * CFrame.new(0, 1.4 + lifted.pet.half, 0)).Position
				animate(lifted.pet, CFrame.new(above) * (if root then root.CFrame.Rotation else CFrame.identity), false, dt)
			end

			local name, rarity = other:GetAttribute("Pet") or "", other:GetAttribute("PetRarity") or 0
			local def = Pets.DEFS[name]
			if not def or rarity < 1 or not root then
				dropFollower(other)
				continue
			end
			local key = name .. rarity
			local entry = followers[other]
			if not entry or entry.key ~= key then
				dropFollower(other)
				entry = { key = key, pet = create(name, rarity, false), cframe = root.CFrame }
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
	-- Dans chaque enclos : les œufs là où leur joueur les a posés, et ses familiers qui se promènent. Tout le monde
	-- voit l'enclos de tout le monde.
	local shown = {} -- ["numéro de l'espace:place"] = { key, egg ou pet, ... }
	local function clear(id: string)
		local item = shown[id]
		if item then
			if item.pet then
				item.pet.model:Destroy()
			end
			if item.egg then
				item.egg:Destroy()
			end
			shown[id] = nil
		end
	end
	local function randomSpot(origin: Vector3): Vector3
		local pen = Pets.PEN
		return origin + Vector3.new(math.random() * (pen.maxX - pen.minX) + pen.minX, 0, math.random() * (pen.maxZ - pen.minZ) + pen.minZ)
	end

	local function syncPens()
		local seen = {}
		for _, plot in gym:GetChildren() do
			local origin = plot:GetAttribute("Origin")
			local enclosure = plot:FindFirstChild("Enclosure")
			if not origin or not enclosure then
				continue
			end
			local own = plot:GetAttribute("Index") == (player:GetAttribute("Plot") or 0)
			local owner = Players:GetPlayerByUserId(plot:GetAttribute("OwnerId") or 0)
			local spots = Pets.decode(owner and owner:GetAttribute("Spots"))
			local places = owner and owner:GetAttribute("Places") or Pets.SPOTS_FREE
			for index, spot in spots do
				local id = plot.Name .. ":" .. index
				-- Le familier que son joueur porte dans ses bras n'est plus dans l'enclos.
				if owner and (owner:GetAttribute("Held") or "") == tostring(index) then
					continue
				end
				seen[id] = true
				local key = if spot.v then "v" .. spot.a .. spot.q .. spot.v else "t" .. spot.a .. spot.q
				local item = shown[id]
				if not item or item.key ~= key then
					clear(id)
					item = { key = key }
					local place = origin + Vector3.new(spot.x, 0, spot.z)
					if spot.v then
						-- Un familier : il part de là où son œuf était posé et se promène.
						-- Dans son rang, un familier qui vaut plus est plus gros (jusqu'a 150 % en haut du palier, son chiffre), comme
						-- son oeuf l'annoncait. (Le rang, lui, grossit deja l'animal : Pets.RARITIES.)
						item.pet = create(spot.a, spot.q, true, PEN_SCALE * (0.4 + 1.6 * (spot.s or 0.5))) -- de 40 % a 200 %
						item.pet.model.Name = "Pen_" .. spot.a .. spot.q
						item.position, item.target, item.rest = place, randomSpot(origin), math.random() * 2
						item.origin = origin
						item.facing = CFrame.new(place)
						item.income = Pets.incomeOf(spot.a, spot.v)
						item.pop = math.random()
						local anchor = item.pet.model.PrimaryPart
						local top, bottom = tag(anchor, item.pet.half + 2.2)
						top.Text = tr(spot.a)
						top.TextColor3 = rarityInfo(spot.q).color
						bottom.Text = tr("perSecond", amount(item.income))
					else
						local size = eggSize(3, spot.s)
						item.egg = makeEgg(spot.a, size)
						item.egg.Position = place + Vector3.new(0, 0.15 + size * 0.65, 0)
						settleEgg(item.egg)
						item.top, item.bottom = tag(item.egg, size * 0.65 + 1.3)
						item.top.Text = tr("eggName") .. "  " .. tr(rarityInfo(spot.q).key)
						item.top.TextColor3 = rarityInfo(spot.q).color
						item.bottom.TextColor3 = Color3.new(1, 1, 1)
					end
					shown[id] = item
				end
				if item.egg then
					local left = spot.t - workspace:GetServerTimeNow()
					item.bottom.Text = clock(left)
					item.egg.Material = if left <= 0 then Enum.Material.Neon else Enum.Material.SmoothPlastic
				end
			end

			-- Le panneau de l'espace, celui de l'enclos et le panneau « Améliorer l'enclos ».
			local ownerName = plot:GetAttribute("Owner") or ""
			local sign = plot:FindFirstChild("Sign")
			local surface = sign and sign:FindFirstChildOfClass("SurfaceGui")
			local plotLabel = surface and surface:FindFirstChild("Label")
			if plotLabel then
				plotLabel.Text = if ownerName == "" then tr("plotFree") else tr("plotOwner", ownerName)
			end
			local pets, eggs = Pets.count(spots)
			local title = enclosure:FindFirstChild("Title")
			local board = title and title:FindFirstChild("Label")
			if board then
				board.Title.Text = tr("enclosure")
				board.Level.Text = if owner then tr("active", pets + eggs, places) else ""
				board.Info.Text = if owner then tr("income", amount(owner:GetAttribute("Income") or 0)) else ""
			end
			local upgrade = enclosure:FindFirstChild("Upgrade")
			local label = upgrade and upgrade:FindFirstChild("Label")
			if label then
				local price = owner and Pets.spotPrice(places)
				local level = Pets.penLevel(places)
				label.Title.Text = tr("penUpgrade")
				label.Level.Text = if not owner then "" elseif price then tr("levelUp", level, level + 1) else tr("max")
				label.Button.Visible = price ~= nil
				label.Button.Info.Text = if price then env.num(price) else ""
				local prompt = upgrade:FindFirstChild("Prompt")
				if prompt then
					prompt.Enabled = own and price ~= nil
					prompt.ObjectText = tr("penUpgrade")
					prompt.ActionText = if price then tr("penBuy", env.num(price)) else ""
				end
			end
		end
		for id in shown do
			if not seen[id] then
				clear(id)
			end
		end
		-- La boutique des œufs et le stand « VENDRE ».
		local shop = gym:FindFirstChild("Shop")
		local shopPrompt = shop and shop:FindFirstChild("Prompt")
		if shopPrompt then
			local tickets = player:GetAttribute("Tickets") or 0
			shopPrompt.ObjectText = tr("shopName")
			shopPrompt.ActionText = if tickets > 0 then tr("shopGo", tickets) else tr("shopEmpty")
		end
		local sell = gym:FindFirstChild("Sell")
		local sellPrompt = sell and sell:FindFirstChild("Prompt")
		if sellPrompt then
			sellPrompt.ObjectText = tr("sellName")
			sellPrompt.ActionText = tr("sellGo")
		end
	end
	task.spawn(function()
		while true do
			syncPens()
			task.wait(0.25)
		end
	end)

	-- Un gain qui s'envole au-dessus d'un familier (« +12 »).
	local function popup(position: Vector3, value: number)
		local holder = Instance.new("Part")
		holder.Name = "Gain"
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		holder.Transparency = 1
		holder.Size = Vector3.new(0.2, 0.2, 0.2)
		holder.Position = position
		holder.Parent = folder
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromScale(5, 1.6)
		gui.MaxDistance = 90
		gui.AutoLocalize = false
		gui.Parent = holder
		local label = env.text(gui, "Label", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), GREEN)
		label.Text = "+" .. amount(value)
		local info = TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(gui, info, { StudsOffsetWorldSpace = Vector3.new(0, 4.5, 0) }):Play()
		TweenService:Create(label, info, { TextTransparency = 1 }):Play()
		TweenService:Create(label.UIStroke, info, { Transparency = 1 }):Play()
		task.delay(1.2, holder.Destroy, holder)
	end

	-- La promenade : chaque familier va vers un point au hasard de l'enclos, s'arrête un moment, repart.
	local function stepPens(dt: number)
		local eye = workspace.CurrentCamera.CFrame.Position
		for _, item in shown do
			local pet = item.pet
			if not pet or (item.position - eye).Magnitude > ANIMATE_DISTANCE then
				continue
			end
			local moving = false
			if item.rest > 0 then
				item.rest -= dt
			else
				local offset = item.target - item.position
				local distance = offset.Magnitude
				if distance < 0.6 then
					item.target = randomSpot(item.origin)
					item.rest = 1 + math.random() * 3
				else
					local direction = offset.Unit
					item.position += direction * math.min(distance, (if pet.starter then PEN_WALK else 4.5) * dt)
					item.facing = item.facing:Lerp(CFrame.lookAt(Vector3.zero, direction), 1 - math.exp(-6 * dt))
					moving = true
				end
			end
			local lift = 0.25 + pet.half + (if Pets.DEFS[pet.name].move == "fly" then 1.6 else 0)
			animate(pet, CFrame.new(item.position + Vector3.new(0, lift, 0)) * item.facing.Rotation, moving, dt)
			-- Son gain, chaque seconde.
			item.pop += dt
			if item.pop >= 1 then
				item.pop -= 1
				popup(item.position + Vector3.new(0, pet.half * 2 + 1.5, 0), item.income)
			end
		end
	end

	-- LE MONSTRE DES SALLES DE COURSE -------------------------------------------------------------------------------------
	-- Le serveur déplace un bloc invisible étiqueté « Chaser » ; un grand golem est dessiné dessus, qui marche.
	local chasers = {} -- [bloc] = familier affiché
	local function stepChasers(dt: number)
		for _, part in CollectionService:GetTagged("Chaser") do
			if not chasers[part] and part:IsDescendantOf(workspace) then
				local pet = create("Golem", 1, true, 3.2)
				pet.model.Name = "Chaser"
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

	-- LE PRÉDATEUR -------------------------------------------------------------------------------------------------------
	-- Le serveur déplace un bloc invisible « Hunter » par joueur (attribut Owner) et pose un bloc « HunterExit » là où
	-- le prédateur va ressortir de son terrier. Chacun joue seul : on ne dessine que SON prédateur, et pendant la
	-- chasse les autres joueurs de la salle sont cachés.
	local hunters = {} -- [bloc] = { pet, shown }
	local exits = {} -- [bloc] = true : son « ! » est posé
	local hidden = {} -- [personnage] = true : caché pendant la chasse
	local boulders = {} -- [bloc] = { ball, spin } : les rochers de l'avalanche
	local valveGauges = {} -- [vanne] = { gui, fill } : la jauge dessinée au-dessus de chaque vanne
	local function setHidden(character: Model, hide: boolean)
		for _, item in character:GetDescendants() do
			if item:IsA("BasePart") or item:IsA("Decal") then
				item.LocalTransparencyModifier = if hide then 1 else 0
			end
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.DisplayDistanceType = if hide then Enum.HumanoidDisplayDistanceType.None else Enum.HumanoidDisplayDistanceType.Viewer
		end
	end
	local function stepHunters(dt: number)
		local hunting = false
		for _, part in CollectionService:GetTagged("Hunter") do
			if part:GetAttribute("Owner") == player.UserId and part:IsDescendantOf(workspace) then
				hunting = true
				if not hunters[part] then
					local pet = create("Wolf", 1, true, 3.4)
					pet.model.Name = "Hunter"
					local top, bottom = tag(pet.model.PrimaryPart, pet.half + 2.6)
					top.Text = tr("hunterName")
					top.TextColor3 = RED
					bottom.Text = ""
					local light = Instance.new("PointLight")
					light.Color = Color3.fromRGB(255, 50, 50)
					light.Range = 16
					light.Brightness = 1.5
					light.Parent = pet.model.PrimaryPart
					hunters[part] = { pet = pet, shown = part.CFrame }
				end
			end
		end
		for part, item in hunters do
			if not part:IsDescendantOf(workspace) then
				item.pet.model:Destroy()
				hunters[part] = nil
				continue
			end
			if part:GetAttribute("Hidden") then
				-- Dans son terrier : rangé sous le sol.
				item.shown = part.CFrame
				item.pet.model:PivotTo(CFrame.new(part.Position.X, -80, part.Position.Z))
				continue
			end
			-- Le bloc arrive par à-coups du serveur : on le suit en douceur (et d'un coup s'il ressort ailleurs).
			local far = (part.Position - item.shown.Position).Magnitude > 12
			item.shown = if far then part.CFrame else item.shown:Lerp(part.CFrame, 1 - math.exp(-18 * dt))
			-- Le bloc est à 2 studs du sol : le prédateur a les pattes par terre.
			animate(item.pet, item.shown * CFrame.new(0, item.pet.half - 2, 0), part:GetAttribute("Moving") == true, dt)
		end
		-- La sortie du terrier : un grand « ! » rouge, visible à travers le rocher.
		for _, part in CollectionService:GetTagged("HunterExit") do
			if part:GetAttribute("Owner") == player.UserId and part:IsDescendantOf(workspace) and not exits[part] then
				exits[part] = true
				local gui = Instance.new("BillboardGui")
				gui.Name = "Warning"
				gui.Size = UDim2.fromScale(16, 16)
				gui.StudsOffsetWorldSpace = Vector3.new(0, 7, 0)
				gui.AlwaysOnTop = true
				gui.MaxDistance = 300
				gui.AutoLocalize = false
				gui.Parent = part
				local mark = env.text(gui, "Mark", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), RED)
				mark.Text = "!"
				local sound = Instance.new("Sound")
				sound.SoundId = "rbxasset://sounds/bass.wav"
				sound.Volume = 1.2
				sound.PlaybackSpeed = 0.6
				sound.Parent = part
				sound:Play()
			end
		end
		for part in exits do
			if not part:IsDescendantOf(workspace) then
				exits[part] = nil
			end
		end
		-- LES ROCHERS DE L'AVALANCHE : le serveur fait rouler un bloc invisible « Boulder » par rocher ; on dessine
		-- les siens. Un rocher déjà frappé est fissuré (orange) et plus petit.
		for _, part in CollectionService:GetTagged("Boulder") do
			if part:GetAttribute("Owner") == player.UserId and part:IsDescendantOf(workspace) and not boulders[part] then
				local ball = Instance.new("Part")
				ball.Name = "Boulder"
				ball.Shape = Enum.PartType.Ball
				ball.Size = Vector3.new(7, 7, 7)
				ball.Material = Enum.Material.Slate
				ball.Color = Color3.fromRGB(110, 104, 106)
				ball.Anchored = true
				ball.CanCollide = false
				ball.CanQuery = false
				ball.CanTouch = false
				ball.Parent = folder
				boulders[part] = { ball = ball, spin = 0 }
			end
		end
		for part, item in boulders do
			if not part:IsDescendantOf(workspace) then
				-- Cassé (ou passé) : il éclate en morceaux.
				local at = item.ball.Position
				item.ball:Destroy()
				boulders[part] = nil
				for _ = 1, 6 do
					local chip = Instance.new("Part")
					chip.Size = Vector3.new(1.4, 1.4, 1.4)
					chip.Material = Enum.Material.Slate
					chip.Color = Color3.fromRGB(110, 104, 106)
					chip.CanCollide = false
					chip.CanQuery = false
					chip.CanTouch = false
					chip.Position = at
					chip.AssemblyLinearVelocity = Vector3.new(math.random(-18, 18), math.random(14, 30), math.random(-18, 18))
					chip.Parent = folder
					game:GetService("Debris"):AddItem(chip, 1.2)
				end
				continue
			end
			local hp = part:GetAttribute("Hp") or 1
			local size = 4.5 + 2.5 * hp
			item.spin += dt * 3
			item.ball.Size = Vector3.new(size, size, size)
			item.ball.Color = if hp < 0.99 then Color3.fromRGB(230, 130, 60) else Color3.fromRGB(110, 104, 106)
			item.ball.CFrame = CFrame.new(part.Position.X, size / 2, part.Position.Z) * CFrame.Angles(-item.spin, 0, 0)
		end
		-- LES VANNES : une grosse jauge au-dessus de chaque vanne de la salle du joueur, avec SA pression à lui
		-- (attribut « Valves » du joueur : quatre nombres de 0 à 1). Verte, puis jaune, puis rouge qui clignote.
		local mine = player:GetAttribute("Valves")
		local values = {}
		for value in string.gmatch(mine or "", "[%d%.]+") do
			table.insert(values, tonumber(value))
		end
		local myRoom = workspace:FindFirstChild("Rooms") and workspace.Rooms:FindFirstChild("Room" .. (player:GetAttribute("Room") or 0))
		for _, part in CollectionService:GetTagged("Valve") do
			local gauge = valveGauges[part]
			if not gauge then
				local gui = Instance.new("BillboardGui")
				gui.Name = "Gauge"
				gui.Size = UDim2.fromScale(9, 2.2)
				gui.StudsOffsetWorldSpace = Vector3.new(0, 9, 0)
				gui.AlwaysOnTop = true
				gui.MaxDistance = 220
				gui.AutoLocalize = false
				gui.Parent = part
				local back = Instance.new("Frame")
				back.Size = UDim2.fromScale(1, 1)
				back.BackgroundColor3 = Color3.fromRGB(30, 32, 44)
				back.BorderSizePixel = 0
				back.Parent = gui
				Instance.new("UICorner", back).CornerRadius = UDim.new(0.3, 0)
				local fill = Instance.new("Frame")
				fill.Size = UDim2.fromScale(0, 1)
				fill.BorderSizePixel = 0
				fill.Parent = back
				Instance.new("UICorner", fill).CornerRadius = UDim.new(0.3, 0)
				gauge = { gui = gui, fill = fill }
				valveGauges[part] = gauge
			end
			local value = values[part:GetAttribute("Index") or 0]
			local shown = value ~= nil and myRoom ~= nil and part:IsDescendantOf(myRoom)
			gauge.gui.Enabled = shown
			if shown then
				gauge.fill.Size = UDim2.fromScale(math.clamp(value, 0, 1), 1)
				local blink = value > 0.8 and math.floor(os.clock() * 6) % 2 == 0
				gauge.fill.BackgroundColor3 = if blink then Color3.new(1, 1, 1) elseif value > 0.8 then Color3.fromRGB(255, 50, 50) elseif value > 0.5 then Color3.fromRGB(255, 200, 40) else Color3.fromRGB(70, 210, 90)
			end
		end
		-- Dans une salle où chacun joue seul (prédateur, avalanche), on ne voit pas les autres joueurs de la salle.
		local room = player:GetAttribute("Room") or 0
		local roomFolder = workspace:FindFirstChild("Rooms") and workspace.Rooms:FindFirstChild("Room" .. room)
		hunting = hunting or (roomFolder ~= nil and roomFolder:GetAttribute("Solo") == true and roomFolder:GetAttribute("State") == "Event")
		for _, other in Players:GetPlayers() do
			local character = other.Character
			if other ~= player and character then
				local hide = hunting and (other:GetAttribute("Room") or 0) == room
				if hide then
					hidden[character] = true
					setHidden(character, true)
				elseif hidden[character] then
					hidden[character] = nil
					setHidden(character, false)
				end
			end
		end
	end

	RunService.RenderStepped:Connect(function(dt)
		stepPlayers(dt)
		stepPens(dt)
		stepChasers(dt)
		stepHunters(dt)
	end)

	-- LES BOUTONS DE DROITE ET LEURS PANNEAUX ---------------------------------------------------------------------------
	local equipEvent = ReplicatedStorage:WaitForChild("Equip")
	local sellEvent = ReplicatedStorage:WaitForChild("SellPet")
	local placeEvent = ReplicatedStorage:WaitForChild("PlaceEgg")
	local upgradeEvent = ReplicatedStorage:WaitForChild("UpgradePen")

	local function squareButton(name: string, order: number, color: Color3): TextButton
		local button = Instance.new("TextButton")
		button.Name = name
		button.AnchorPoint = Vector2.new(1, 0.5)
		button.Position = UDim2.new(1, -12, 0.5, -110 + order * 76)
		button.Size = UDim2.fromOffset(66, 66)
		button.BackgroundColor3 = color
		button.Text = ""
		Instance.new("UICorner", button).CornerRadius = UDim.new(0, 10)
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 4
		stroke.Color = Color3.fromRGB(20, 20, 30)
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = button
		button.Parent = env.gui
		return button
	end
	local function sidePanel(name: string, height: number): (Frame, TextLabel)
		local panel = env.box(env.gui, name, UDim2.fromOffset(380, height), UDim2.new(1, -90, 0.5, 0), Color3.fromRGB(52, 54, 66))
		panel.AnchorPoint = Vector2.new(1, 0.5)
		panel.Visible = false
		panel.ZIndex = 4
		local scale = Instance.new("UIScale")
		scale.Name = "Scale"
		scale.Parent = panel
		local header = env.box(panel, "Header", UDim2.new(1, 0, 0, 52), UDim2.fromOffset(0, 0), Color3.fromRGB(214, 166, 120))
		local title = env.text(header, "Title", UDim2.new(1, -170, 0, 34), UDim2.fromOffset(10, 9))
		title.TextXAlignment = Enum.TextXAlignment.Left
		-- La flèche rouge qui replie le panneau.
		local fold = Instance.new("TextButton")
		fold.Name = "Fold"
		fold.AnchorPoint = Vector2.new(1, 0.5)
		fold.Position = UDim2.new(0, -10, 0.5, 0)
		fold.Size = UDim2.fromOffset(44, 44)
		fold.BackgroundColor3 = Color3.fromRGB(235, 40, 40)
		fold.Font = Enum.Font.FredokaOne
		fold.TextScaled = true
		fold.TextColor3 = Color3.new(1, 1, 1)
		fold.Text = ">"
		Instance.new("UICorner", fold).CornerRadius = UDim.new(0, 6)
		fold.Parent = panel
		fold.Activated:Connect(function()
			panel.Visible = false
		end)
		return panel, title
	end
	local function fit(panel: Frame)
		local view = workspace.CurrentCamera.ViewportSize
		panel.Scale.Scale = math.min(1, view.Y / (panel.Size.Y.Offset + 60), (view.X - 110) / 440)
	end

	-- L'œuf : combien d'œufs à poser ou qui couvent, et le panneau « Œufs en croissance ».
	local eggButton = squareButton("EggButton", 0, Color3.fromRGB(235, 50, 50))
	local eggIcon = Instance.new("Frame")
	eggIcon.Name = "Icon"
	eggIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	eggIcon.Position = UDim2.fromScale(0.5, 0.5)
	eggIcon.Size = UDim2.fromOffset(32, 42)
	eggIcon.BackgroundColor3 = Color3.fromRGB(255, 226, 190)
	eggIcon.BorderSizePixel = 0
	Instance.new("UICorner", eggIcon).CornerRadius = UDim.new(0.5, 0)
	local eggStroke = Instance.new("UIStroke")
	eggStroke.Thickness = 3
	eggStroke.Color = Color3.fromRGB(60, 30, 20)
	eggStroke.Parent = eggIcon
	eggIcon.Parent = eggButton
	local badge = env.box(eggButton, "Badge", UDim2.fromOffset(28, 28), UDim2.new(1, -14, 1, -14), Color3.fromRGB(40, 190, 60))
	badge:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)
	local badgeText = env.text(badge, "Label", UDim2.fromScale(0.9, 0.8), UDim2.fromScale(0.05, 0.1))

	local eggPanel, eggTitle = sidePanel("EggPanel", 340)
	eggTitle.Text = tr("eggsGrowing")
	local eggInfo = env.text(eggPanel, "Info", UDim2.new(1, -20, 0, 22), UDim2.fromOffset(10, 58), Color3.fromRGB(255, 221, 51), 18)
	eggInfo.TextXAlignment = Enum.TextXAlignment.Left
	local eggRows = {}
	for i = 1, 5 do
		local row = env.box(eggPanel, "Egg" .. i, UDim2.new(1, -20, 0, 44), UDim2.fromOffset(10, 86 + (i - 1) * 50), Color3.fromRGB(74, 76, 90))
		row.UIStroke.Thickness = 2
		local icon = Instance.new("Frame")
		icon.Name = "Icon"
		icon.Position = UDim2.fromOffset(10, 5)
		icon.Size = UDim2.fromOffset(26, 34)
		icon.BorderSizePixel = 0
		Instance.new("UICorner", icon).CornerRadius = UDim.new(0.5, 0)
		icon.Parent = row
		local track = env.box(row, "Track", UDim2.new(1, -150, 0, 26), UDim2.fromOffset(48, 9), Color3.fromRGB(20, 22, 30))
		track.UIStroke.Thickness = 2
		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.BorderSizePixel = 0
		fill.BackgroundColor3 = Color3.fromRGB(60, 220, 70)
		fill.Size = UDim2.fromScale(0, 1)
		Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 8)
		fill.Parent = track
		local label = env.text(track, "Label", UDim2.fromScale(1, 0.84), UDim2.fromScale(0, 0.08))
		label.ZIndex = 2
		local rarity = env.text(row, "Rarity", UDim2.fromOffset(92, 22), UDim2.new(1, -98, 0, 11), nil, 16)
		eggRows[i] = { frame = row, icon = icon, fill = fill, label = label, rarity = rarity }
	end

	-- La patte : la liste de ses familiers, comme « 7/8 Actifs » avec le bouton pour acheter une place.
	local pawButton = squareButton("PawButton", 1, Color3.fromRGB(255, 150, 40))
	env.text(pawButton, "Label", UDim2.fromScale(0.8, 0.8), UDim2.fromScale(0.1, 0.1)).Text = "🐾"
	local petPanel, petTitle = sidePanel("PetPanel", 470)
	local addPlace = Instance.new("TextButton")
	addPlace.Name = "AddPlace"
	addPlace.AnchorPoint = Vector2.new(1, 0)
	addPlace.Position = UDim2.new(1, -8, 0, 8)
	addPlace.Size = UDim2.fromOffset(160, 36)
	addPlace.BackgroundColor3 = Color3.fromRGB(110, 230, 40)
	addPlace.Font = Enum.Font.FredokaOne
	addPlace.TextScaled = true
	addPlace.TextColor3 = Color3.new(1, 1, 1)
	Instance.new("UICorner", addPlace).CornerRadius = UDim.new(0, 6)
	local addStroke = Instance.new("UIStroke")
	addStroke.Thickness = 2
	addStroke.Parent = addPlace
	addPlace.Parent = petPanel.Header
	addPlace.Activated:Connect(function()
		upgradeEvent:FireServer()
	end)
	local petIncome = env.text(petPanel, "Income", UDim2.new(1, -20, 0, 22), UDim2.fromOffset(10, 58), GREEN, 18)
	petIncome.TextXAlignment = Enum.TextXAlignment.Left
	-- LA CHANCE : une ligne qui explique, et une ligne qui dit la chance du joueur en ce moment.
	local GOLD = Color3.fromRGB(255, 221, 51)
	local luckFrame = env.box(petPanel, "Luck", UDim2.new(1, -16, 0, 50), UDim2.fromOffset(8, 84), Color3.fromRGB(70, 56, 20))
	luckFrame.UIStroke.Thickness = 2
	luckFrame.UIStroke.Color = GOLD
	local luckExplain = env.text(luckFrame, "Explain", UDim2.new(1, -12, 0, 20), UDim2.fromOffset(6, 3), GOLD, 16)
	luckExplain.UIStroke.Thickness = 1.5
	luckExplain.Text = tr("luckExplain")
	local luckNow = env.text(luckFrame, "Now", UDim2.new(1, -12, 0, 22), UDim2.fromOffset(6, 25), nil, 18)
	luckNow.UIStroke.Thickness = 1.5
	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.Position = UDim2.fromOffset(8, 142)
	list.Size = UDim2.new(1, -16, 1, -150)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 8
	list.ZIndex = 4
	list.Parent = petPanel
	local petRows = {}
	local selling = 0 -- la place dont le bouton « Vendre » attend son 2e appui
	local function petRow(i: number)
		local row = env.box(list, "Pet" .. i, UDim2.new(1, -14, 0, 78), UDim2.fromOffset(2, 2 + (i - 1) * 84), Color3.fromRGB(74, 76, 90))
		row.UIStroke.Thickness = 2
		local name = env.text(row, "Animal", UDim2.new(1, -196, 0, 24), UDim2.fromOffset(10, 4), nil, 19)
		name.TextXAlignment = Enum.TextXAlignment.Left
		local info = env.text(row, "Info", UDim2.new(1, -196, 0, 20), UDim2.fromOffset(10, 29), GREEN, 16)
		info.TextXAlignment = Enum.TextXAlignment.Left
		info.UIStroke.Thickness = 1.5
		-- Sa chance d'œuf rare, sur sa propre ligne dorée (toute la largeur : c'est ce qu'on compare).
		local luck = env.text(row, "Luck", UDim2.new(1, -20, 0, 22), UDim2.fromOffset(10, 52), GOLD, 18)
		luck.TextXAlignment = Enum.TextXAlignment.Left
		luck.UIStroke.Thickness = 1.5
		local function button(buttonName: string, x: number, width: number): TextButton
			local item = Instance.new("TextButton")
			item.Name = buttonName
			item.Size = UDim2.fromOffset(width, 38)
			item.Position = UDim2.new(1, x, 0, 9)
			item.Font = Enum.Font.FredokaOne
			item.TextScaled = true
			item.TextColor3 = Color3.new(1, 1, 1)
			Instance.new("UICorner", item).CornerRadius = UDim.new(0, 8)
			item.Parent = row
			return item
		end
		local follow = button("Follow", -178, 80)
		local sell = button("Sell", -92, 86)
		local item = { frame = row, name = name, info = info, luck = luck, follow = follow, sell = sell, spot = 0 }
		follow.Activated:Connect(function()
			equipEvent:FireServer(item.spot)
		end)
		-- « Vendre » : le joueur prend le familier dans ses bras pour le porter au stand (un 2e appui le repose).
		sell.Activated:Connect(function()
			sellEvent:FireServer(item.spot)
		end)
		petRows[i] = item
		return item
	end

	local function refreshPanels()
		local spots = Pets.decode(player:GetAttribute("Spots"))
		local places = player:GetAttribute("Places") or Pets.SPOTS_FREE
		local following = player:GetAttribute("PetSpot") or ""
		local bag, tickets = player:GetAttribute("Bag") or 0, player:GetAttribute("Tickets") or 0
		local pets, eggs = {}, {}
		for index, spot in spots do
			table.insert(if spot.v then pets else eggs, { index = tonumber(index), spot = spot })
		end
		table.sort(pets, function(a, b)
			return Pets.incomeOf(a.spot.a, a.spot.v) > Pets.incomeOf(b.spot.a, b.spot.v)
		end)
		table.sort(eggs, function(a, b)
			return a.spot.t < b.spot.t
		end)

		-- L'œuf : la pastille compte les œufs à poser et ceux qui couvent.
		badgeText.Text = tostring(bag + #eggs)
		badge.Visible = bag + #eggs > 0
		eggInfo.Text = tr("stock", tickets, bag)
		for i, row in eggRows do
			local entry = eggs[i]
			row.frame.Visible = entry ~= nil
			if entry then
				local left = entry.spot.t - workspace:GetServerTimeNow()
				local total = math.max(1, entry.spot.d)
				row.icon.BackgroundColor3 = EGG_COLORS[entry.spot.a] or Color3.new(1, 1, 1)
				row.fill.Size = UDim2.fromScale(math.clamp(1 - left / total, 0, 1), 1)
				row.label.Text = clock(left)
				row.rarity.Text = tr(rarityInfo(entry.spot.q).key)
				row.rarity.TextColor3 = rarityInfo(entry.spot.q).color
			end
		end
		fit(eggPanel)

		-- La patte : la liste, du familier qui rapporte le plus à celui qui rapporte le moins.
		local price = Pets.spotPrice(places)
		petTitle.Text = tr("active", #pets + #eggs, places)
		addPlace.Visible = price ~= nil
		addPlace.Text = if price then tr("addPlace", env.num(price)) else ""
		petIncome.Text = tr("income", amount(Pets.income(spots)))
		for i, entry in pets do
			local row = petRows[i] or petRow(i)
			local info = rarityInfo(entry.spot.q)
			row.spot = entry.index
			row.frame.Visible = true
			row.name.Text = tr(entry.spot.a)
			row.name.TextColor3 = info.color
			row.info.Text = tr(info.key) .. "  " .. tr("perSecond", amount(Pets.incomeOf(entry.spot.a, entry.spot.v)))
			row.luck.Text = tr("luckLine", Pets.luckOf(entry.spot))
			local followed = following == tostring(entry.index)
			-- Celui qui suit le joueur : son cadre passe au doré.
			row.frame.UIStroke.Color = if followed then GOLD else Color3.fromRGB(20, 20, 30)
			row.frame.BackgroundColor3 = if followed then Color3.fromRGB(96, 84, 50) else Color3.fromRGB(74, 76, 90)
			row.follow.Text = if followed then tr("following") else tr("follow")
			row.follow.BackgroundColor3 = if followed then Color3.fromRGB(70, 210, 90) else Color3.fromRGB(60, 150, 255)
			local confirm = (player:GetAttribute("Held") or "") == tostring(entry.index)
			row.sell.Text = if confirm then tr("putBack") else tr("sellButton")
			row.sell.BackgroundColor3 = if confirm then Color3.fromRGB(255, 150, 40) else Color3.fromRGB(235, 50, 50)
		end
		for i = #pets + 1, #petRows do
			petRows[i].frame.Visible = false
		end
		list.CanvasSize = UDim2.fromOffset(0, #pets * 84 + 4)
		local follower = spots[following]
		luckNow.Text = if follower and follower.v then tr("luckNow", Pets.luckOf(follower), tr(follower.a)) else tr("luckNone")
		luckNow.TextColor3 = if follower and follower.v then Color3.fromRGB(110, 255, 80) else Color3.fromRGB(255, 120, 120)
		fit(petPanel)
	end
	for _, name in { "Spots", "Places", "PetSpot", "Tickets", "Bag" } do
		player:GetAttributeChangedSignal(name):Connect(refreshPanels)
	end
	task.spawn(function()
		-- Les barres des œufs avancent, et le bouton « Vendre » oublie son 1er appui au bout d'un moment.
		local armed, since = 0, 0
		while true do
			if selling ~= armed then
				armed, since = selling, os.clock()
			elseif selling ~= 0 and os.clock() - since > 3 then
				selling = 0
			end
			refreshPanels()
			task.wait(0.5)
		end
	end)
	eggButton.Activated:Connect(function()
		eggPanel.Visible = not eggPanel.Visible
		petPanel.Visible = false
		refreshPanels()
	end)
	pawButton.Activated:Connect(function()
		petPanel.Visible = not petPanel.Visible
		eggPanel.Visible = false
		refreshPanels()
	end)

	-- POSER L'ŒUF -----------------------------------------------------------------------------------------------------
	-- Quand le joueur porte un œuf et se tient dans son enclos : un gros bouton (ou la touche E) le pose à ses pieds.
	local placeButton = Instance.new("TextButton")
	placeButton.Name = "PlaceEgg"
	placeButton.AnchorPoint = Vector2.new(0.5, 1)
	placeButton.Position = UDim2.new(0.5, 0, 1, -120)
	placeButton.Size = UDim2.fromOffset(280, 58)
	placeButton.BackgroundColor3 = Color3.fromRGB(110, 230, 40)
	placeButton.Text = ""
	placeButton.Visible = false
	Instance.new("UICorner", placeButton).CornerRadius = UDim.new(0, 10)
	local placeStroke = Instance.new("UIStroke")
	placeStroke.Thickness = 4
	placeStroke.Color = Color3.fromRGB(20, 20, 30)
	placeStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	placeStroke.Parent = placeButton
	placeButton.Parent = env.gui
	env.text(placeButton, "Label", UDim2.fromScale(0.94, 0.7), UDim2.fromScale(0.03, 0.15)).Text = tr("placeEgg")
	local function inOwnPen(): boolean
		local plot = gym:FindFirstChild("Plot" .. (player:GetAttribute("Plot") or 0))
		local origin = plot and plot:GetAttribute("Origin")
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not origin or not root then
			return false
		end
		local x, z = root.Position.X - origin.X, root.Position.Z - origin.Z
		local pen = Pets.PEN
		return x >= pen.minX - 1 and x <= pen.maxX + 1 and z >= pen.minZ - 1 and z <= pen.maxZ + 1
	end
	local function placeEgg()
		if placeButton.Visible then
			placeEvent:FireServer()
		end
	end
	placeButton.Activated:Connect(placeEgg)
	UserInputService.InputBegan:Connect(function(input, typing)
		if not typing and input.KeyCode == Enum.KeyCode.E then
			placeEgg()
		end
	end)
	task.spawn(function()
		while true do
			placeButton.Visible = (player:GetAttribute("BagNext") or "") ~= "" and inOwnPen()
			task.wait(0.15)
		end
	end)

	-- LES MESSAGES --------------------------------------------------------------------------------------------------
	ReplicatedStorage:WaitForChild("Notify").OnClientEvent:Connect(function(key: string, a, b, c)
		if key == "ticket" then
			-- Arrive juste après « SALLE RÉUSSIE » : attend son tour.
			task.delay(1.8, showToast, if (b or 1) > 1 then tr("luckTicket", a, math.round((b - 1) * 100)) else tr("ticket", a), Color3.fromRGB(255, 221, 51))
		elseif key == "exchanged" then
			showToast(tr("exchanged", a))
		elseif key == "noTicket" or key == "noEgg" or key == "goShop" or key == "notYours" or key == "notInPen" or key == "penFull" then
			showToast(tr(key), RED)
		elseif key == "placed" then
			showToast(tr("placed", tr(a), tr(rarityInfo(b).key), clock(c)), rarityInfo(b).color)
		elseif key == "hatched" then
			showToast(tr("hatched", tr(a), tr(rarityInfo(b).key), amount(c)), rarityInfo(b).color)
		elseif key == "followLuck" then
			showToast(tr("followLuck", tr(a), b), Color3.fromRGB(255, 221, 51))
		elseif key == "followNone" then
			showToast(tr("followNone"), RED)
		elseif key == "sold" then
			showToast(tr("sold", tr(a), env.num(b)))
		elseif key == "placeBought" then
			showToast(tr("placeBought", a, b))
		elseif key == "openPets" then
			petPanel.Visible = true
			eggPanel.Visible = false
			refreshPanels()
		end
	end)
	refreshPanels()
end

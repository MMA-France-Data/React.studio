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
local ActionAnimator = require(ReplicatedStorage.Shared.ActionAnimator)
local Config = require(ReplicatedStorage.Shared.Config)
local Draw = require(script.Parent.Draw)

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
local TEAM_SCALE = 2 -- les familiers de l equipe, qui suivent le joueur (sa demande du 08/10 : « je veux qu ils soient big »)
local PEN_SCALE = 3 -- (double le 08/10, sa demande : « je veux des enclos avec des gros animaux ») les familiers de l'enclos sont plus gros que celui qui suit le joueur
local WALK_SPEED = 1.8 -- animaux des collections : la marche est jouée plus vite que le clip livré...
local MESH_WALK_GAIN = 2.6 -- les pattes des animaux en maillage, quand ils marchent
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
		-- (Retour du joueur : « au-dessus de la patte, la zone bleue et la violette se chevauchent parfois ». Deux
		-- pieces de l animal avaient des faces exactement au meme endroit, ce qui clignote. Chaque piece est retrecie
		-- d un cheveu different : plus aucune face ne tombe pile sur une autre.)
		local index = 0
		for _, part in model:GetDescendants() do
			-- (Pas les animaux en maillage : leurs pièces sont petites et ajustées au millimètre, ce rétrécissement
			-- ouvrait des fentes, la tête de la chèvre avait l'air décollée.)
			if part:IsA("BasePart") and part.Transparency < 1 and not model:GetAttribute("MeshStyle") then
				index += 1
				local shrink = 0.012 * (index % 9)
				local size = part.Size
				if math.min(size.X, size.Y, size.Z) > shrink * 3 then
					part.Size = size - Vector3.one * shrink
				end
			end
		end
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
		local combat = nil
		if starter and starter.clips.Attack then
			local ok, actionRig = pcall(ActionAnimator.bind, model)
			if ok then combat = actionRig else warn("[Monde] combat : " .. tostring(actionRig)) end
		end
		local skeleton = if model:GetAttribute("Starter") then nil else PetRig.bind(name, model)
		model.Parent = folder
		return {
			name = name,
			model = model,
			half = size.Y / 2,
			starter = starter,
			combat = combat,
			nextAction = 0,
			actionIndex = 0,
			skeleton = skeleton,
			limbs = if skeleton then {} else limbsOf(name, model),
			clock = math.random() * 10,
		}
	end
	-- Pose le familier à cet endroit et l'anime.
	-- attacking : l'animal frappe. S'il a un clip « Attack » (les animations de combat livrées à part), il le joue.
	local function animate(pet, base: CFrame, moving: boolean, dt: number, attacking: boolean?)
		pet.clock += dt
		if pet.chest then
			pet.model:PivotTo(base)
			return
		end
		if pet.combat then
			if attacking and not pet.combat.attack and pet.clock >= pet.nextAction then
				pet.actionIndex += 1
				local action = if pet.combat.clips.Bite and pet.actionIndex % 2 == 0 then "Bite" else "Attack"
				if ActionAnimator.playAttack(pet.combat, pet.clock, action) then
					pet.nextAction = pet.clock + pet.combat.clips.Attack.duration + 0.12
				end
			end
			if pet.combat.attack then
				pet.model:PivotTo(base)
				ActionAnimator.step(pet.combat, pet.clock, if moving then "Walk" else "Idle")
				return
			end
		end
		if pet.model:GetAttribute("Starter") then
			-- La marche livrée est discrète : on la joue plus vite, les pattes tournent plus, et le corps sautille
			-- à chaque pas (deux pas par tour d'animation), pour qu'on voie l'animal marcher et non glisser.
			-- (Les animaux en maillage du nouveau style : leurs mouvements tels quels. Grossis comme ceux des anciens
			-- animaux en blocs, la tête se décollait du corps.)
			local mesh = pet.model:GetAttribute("MeshStyle") == true
			local plain = Pets.PLAIN_WALK[pet.name] == true
			-- (Le ptéranodon vole : il reste en l'air, et bat des ailes même à l'arrêt.)
			local flying = Pets.FLYING[pet.name]
			if flying then
				base *= CFrame.new(0, pet.half * 2 * flying, 0)
				moving = true
			end
			local walk = pet.starter and pet.starter.clips.Walk
			local hop = 0
			if moving and walk then
				-- (Animaux en maillage : presque plus de sautillement, ce sont les pattes qui marchent. Retour du
				-- joueur, 08/10 : « je vois plus les animaux sautiller qu'utiliser vraiment leurs pattes ».)
				hop = math.abs(math.sin(pet.clock * WALK_SPEED / walk.duration * math.pi * 2)) * (if mesh then 0.03 else 0.16) * pet.model:GetScale()
			end
			pet.model:PivotTo(base * CFrame.new(0, hop, 0))
			if pet.starter then
				if moving then
					StarterAnimator.step(pet.starter, pet.clock * (if plain then 1 else WALK_SPEED), "Walk", if plain then 1 elseif mesh then MESH_WALK_GAIN else WALK_GAIN, mesh)
				else
					StarterAnimator.step(pet.starter, pet.clock, "Idle", if mesh then 1 else 1.5)
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
	local followers = {} -- [joueur] = { [rang dans l'équipe] = { key, pet, cframe, bar } }
	-- Une barre de vie qui flotte au-dessus d'un bloc : un titre, et une jauge. Renvoie { gui, title, fill }.
	local function healthBar(adornee: BasePart, height: number, width: number)
		local gui = Instance.new("BillboardGui")
		gui.Name = "Health"
		gui.Size = UDim2.fromScale(width, width * 0.3)
		gui.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
		gui.MaxDistance = 110
		gui.AutoLocalize = false
		gui.Adornee = adornee
		gui.Parent = adornee
		local title = env.text(gui, "Title", UDim2.fromScale(1, 0.56), UDim2.fromScale(0, 0))
		local back = env.box(gui, "Back", UDim2.fromScale(0.9, 0.3), UDim2.fromScale(0.05, 0.62), Color3.fromRGB(30, 30, 40))
		back.UIStroke.Thickness = 2
		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.BorderSizePixel = 0
		fill.Size = UDim2.fromScale(1, 1)
		fill.BackgroundColor3 = Color3.fromRGB(80, 220, 90)
		Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 8)
		fill.Parent = back
		return { gui = gui, title = title, fill = fill }
	end
	-- Le bloc invisible du monstre qui porte ce numéro (la cible d'un joueur).
	local function monsterPart(id: number): BasePart?
		if id <= 0 then
			return nil
		end
		for _, part in CollectionService:GetTagged("Monster") do
			if part:GetAttribute("Id") == id then
				return part
			end
		end
		return nil
	end
	local carried = {} -- [joueur] = { key, egg }
	local lifts = {} -- [joueur] = { key, pet } : le familier porté à bout de bras pour aller le vendre
	local function dropMember(other: Player, index: number)
		local team = followers[other]
		if team and team[index] then
			team[index].pet.model:Destroy()
			team[index].anchor:Destroy()
			team[index] = nil
		end
	end
	local function dropFollower(other: Player)
		for index = 1, 3 do
			dropMember(other, index)
		end
		followers[other] = nil
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
			-- (Seulement dans la base : dehors, l'œuf est dans le sac.)
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

			-- L'ÉQUIPE : jusqu'à trois familiers suivent le joueur. Quand il a une cible, ils courent sur le monstre et
			-- le frappent ; un familier à terre reste couché là où il est tombé.
			if not root then
				dropFollower(other)
				continue
			end
			local team = followers[other] or {}
			followers[other] = team
			local members = string.split(other:GetAttribute("TeamPets") or "", ";")
			local health = string.split(other:GetAttribute("TeamHp") or "", ";")
			local target = monsterPart(other:GetAttribute("Target") or 0)
			if target and (target:GetAttribute("Hp") or 0) <= 0 then
				target = nil
			end
			local velocity = root.AssemblyLinearVelocity
			local walking = Vector3.new(velocity.X, 0, velocity.Z).Magnitude > 2
			for index = 1, 3 do
				local petName, rank, size, level = string.match(members[index] or "", "^(%a+):(%d+):(%d+):(%d+)$")
				if not petName or not Pets.DEFS[petName] then
					dropMember(other, index)
					continue
				end
				local entry = team[index]
				if not entry or entry.key ~= members[index] then
					dropMember(other, index)
					local anchor = Instance.new("Part")
					anchor.Name = "TeamAnchor"
					anchor.Anchored = true
					anchor.CanCollide = false
					anchor.CanQuery = false
					anchor.CanTouch = false
					anchor.Transparency = 1
					anchor.Size = Vector3.new(1, 1, 1)
					anchor.Parent = folder
					entry = { key = members[index], pet = create(petName, tonumber(rank), false, TEAM_SCALE * (0.4 + 1.6 * tonumber(size) / 100)), cframe = root.CFrame, anchor = anchor }
					entry.pet.model.Name = "Team_" .. petName
					entry.bar = healthBar(anchor, entry.pet.half + 1.6, 3.6)
					entry.bar.gui.MaxDistance = 60
					team[index] = entry
				end
				local now, max = string.match(health[index] or "", "^(%d+)/(%d+)$")
				now, max = tonumber(now) or 1, tonumber(max) or 1
				local down = now <= 0
				entry.bar.title.Text = tr("lvl", level)
				entry.bar.title.TextColor3 = if down then RED else Color3.new(1, 1, 1)
				entry.bar.fill.Size = UDim2.fromScale(math.clamp(now / max, 0, 1), 1)
				entry.bar.fill.BackgroundColor3 = if now / max > 0.5 then Color3.fromRGB(80, 220, 90) elseif now / max > 0.2 then Color3.fromRGB(255, 190, 50) else Color3.fromRGB(240, 70, 70)

				-- Sa place : autour du monstre visé, sinon derrière le joueur.
				local slot = ({ Vector3.new(6.5, 0, 4), Vector3.new(-6.5, 0, 4), Vector3.new(0, 0, 9) })[index]
				local ground = root.Position.Y - 3
				local goal: CFrame
				local moving = walking
				if down then
					goal = entry.cframe
					moving = false
				elseif target then
					local scale = target:GetAttribute("Scale") or 1
					local around = CFrame.new(target.Position) * CFrame.Angles(0, index * 2.1 + (other.UserId % 7), 0) * CFrame.new(0, 0, scale * 1.6 + 2.2 + entry.pet.half)
					local lunge = math.max(0, math.sin((os.clock() + index * 0.33) * math.pi * 2)) * 1.2
					local at = around.Position + (target.Position - around.Position).Unit * lunge
					goal = CFrame.lookAt(Vector3.new(at.X, target.Position.Y + entry.pet.half, at.Z), Vector3.new(target.Position.X, target.Position.Y + entry.pet.half, target.Position.Z))
					moving = true
				else
					goal = root.CFrame * CFrame.new(slot.X, entry.pet.half - 3, slot.Z)
					goal = CFrame.new(goal.Position.X, ground + entry.pet.half, goal.Position.Z) * root.CFrame.Rotation
				end
				entry.cframe = entry.cframe:Lerp(goal, 1 - math.exp(-(if target then 6 else 9) * dt))
				entry.anchor.CFrame = CFrame.new(entry.cframe.Position)
				if down then
					if entry.pet.combat then ActionAnimator.cancelAttack(entry.pet.combat) end
					entry.pet.model:PivotTo(entry.cframe * CFrame.Angles(0, 0, math.rad(90)))
				else
					animate(entry.pet, entry.cframe, moving, dt, target ~= nil)
				end
			end
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
			-- La vignette du propriétaire, sur les deux faces du cadre (le portrait que Roblox fournit pour chaque joueur).
			local avatar = plot:FindFirstChild("Avatar")
			local ownerId = plot:GetAttribute("OwnerId") or 0
			if avatar and avatar:IsA("BasePart") and avatar:GetAttribute("Shown") ~= ownerId then
				avatar:SetAttribute("Shown", ownerId)
				avatar.Transparency = if ownerId > 0 then 0 else 1
				for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
					local gui = avatar:FindFirstChild("Face" .. face.Name)
					if not gui then
						gui = Instance.new("SurfaceGui")
						gui.Name = "Face" .. face.Name
						gui.Face = face
						gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
						gui.PixelsPerStud = 40
						gui.LightInfluence = 0
						gui.Parent = avatar
						local image = Instance.new("ImageLabel")
						image.Name = "Portrait"
						image.Size = UDim2.fromScale(0.88, 0.88)
						image.Position = UDim2.fromScale(0.06, 0.06)
						image.BackgroundColor3 = Color3.fromRGB(28, 34, 62)
						image.BorderSizePixel = 0
						Instance.new("UICorner", image).CornerRadius = UDim.new(0.12, 0)
						image.Parent = gui
					end
					gui.Enabled = ownerId > 0
					gui.Portrait.Image = if ownerId > 0 then "rbxthumb://type=AvatarHeadShot&id=" .. ownerId .. "&w=420&h=420" else ""
				end
			end
			local pets, eggs = Pets.count(spots)
			local title = enclosure:FindFirstChild("Title")
			local board = title and title:FindFirstChild("Label")
			if board then
				board.Title.Text = tr("enclosure")
				-- (Seulement les familiers : les œufs qui couvent ne prennent plus de place dans l'enclos.)
				local _ = eggs
				board.Level.Text = if owner then tr("active", pets, places) else ""
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
		-- Le stand « VENDRE ».
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

	-- LES MONSTRES -----------------------------------------------------------------------------------------------------
	-- Le serveur déplace un bloc invisible par monstre (étiquette « Monster ») ; ici on dessine l'animal par-dessus,
	-- en plus gros, avec son nom, son niveau et sa barre de vie. Il disparaît quand il est battu.
	local beasts = {} -- [bloc] = { pet, cframe, bar, last }
	-- Un coffre au trésor, en blocs.
	local function chestModel()
		local model = Instance.new("Model")
		model.Name = "Chest"
		local function piece(name: string, size: Vector3, offset: Vector3, color: Color3, material: Enum.Material?)
			local part = Instance.new("Part")
			part.Name = name
			part.Size = size
			part.CFrame = CFrame.new(offset)
			part.Color = color
			part.Material = material or Enum.Material.WoodPlanks
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Parent = model
			return part
		end
		local wood, gold = Color3.fromRGB(150, 92, 50), Color3.fromRGB(240, 186, 50)
		model.PrimaryPart = piece("Box", Vector3.new(5, 2.6, 3.4), Vector3.new(0, 0, 0), wood)
		piece("Lid", Vector3.new(5.2, 1.2, 3.6), Vector3.new(0, 1.9, 0), Color3.fromRGB(170, 104, 56))
		for _, x in { -1.8, 1.8 } do
			piece("Band", Vector3.new(0.5, 3.9, 3.7), Vector3.new(x, 0.6, 0), gold, Enum.Material.Metal)
		end
		piece("Lock", Vector3.new(0.9, 1.1, 0.4), Vector3.new(0, 1.1, -1.85), gold, Enum.Material.Neon)
		model.Parent = folder
		return { name = "Chest", model = model, half = 1.3, chest = true, clock = 0, limbs = {} }
	end
	local function dropBeast(part: BasePart)
		local beast = beasts[part]
		if beast then
			beast.pet.model:Destroy()
			beast.bar.gui:Destroy()
			beasts[part] = nil
		end
	end
	CollectionService:GetInstanceRemovedSignal("Monster"):Connect(dropBeast)
	local function stepMonsters(dt: number)
		local camera = workspace.CurrentCamera.CFrame.Position
		for _, part in CollectionService:GetTagged("Monster") do
			local hp, max = part:GetAttribute("Hp") or 0, part:GetAttribute("MaxHp") or 1
			-- (Loin de la caméra : pas dessiné du tout.)
			if hp <= 0 or (part.Position - camera).Magnitude > 260 then
				dropBeast(part)
				continue
			end
			local beast = beasts[part]
			if not beast then
				local name, boss = part:GetAttribute("Animal"), part:GetAttribute("Boss") == true
				local chest = part:GetAttribute("Chest") == true
				local pet = if chest then chestModel() else create(name, part:GetAttribute("Rank") or 1, false, part:GetAttribute("Scale") or 1.5)
				pet.model.Name = "Monster_" .. name
				local bar = healthBar(part, pet.half * 2 + 1.5, if boss then 12 else 5)
				bar.gui.MaxDistance = if boss then 160 else 70
				bar.title.Text = if chest then tr("chest") else (if boss then "👑 " else "") .. tr(name) .. "  " .. tr("lvl", part:GetAttribute("Level") or 1)
				bar.title.TextColor3 = if boss then Color3.fromRGB(255, 90, 90) else Color3.fromRGB(255, 221, 51)
				bar.fill.BackgroundColor3 = Color3.fromRGB(240, 70, 70)
				beast = { pet = pet, cframe = part.CFrame, bar = bar, last = part.Position }
				beasts[part] = beast
			end
			beast.bar.fill.Size = UDim2.fromScale(math.clamp(hp / max, 0, 1), 1)
			local moving = (part.Position - beast.last).Magnitude > 0.01
			beast.last = part.Position
			beast.cframe = beast.cframe:Lerp(part.CFrame, 1 - math.exp(-10 * dt))
			-- Un petit bond en avant quand il frappe.
			local since = workspace:GetServerTimeNow() - (part:GetAttribute("HitAt") or 0)
			local lunge = if since >= 0 and since < 0.35 then math.sin(since / 0.35 * math.pi) * 1.8 else 0
			animate(beast.pet, beast.cframe * CFrame.new(0, beast.pet.half, -lunge), moving or lunge > 0, dt, lunge > 0)
		end
	end

	RunService.RenderStepped:Connect(function(dt)
		stepPlayers(dt)
		stepPens(dt)
		stepMonsters(dt)
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
		-- Son nom, écrit dessous (sur PC).
		local caption = env.text(button, "Caption", UDim2.new(1, 60, 0, 24), UDim2.new(0, -30, 1, 0), nil, 20)
		caption.Text = tr(name)
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

	-- LES FENÊTRES « MES FAMILIERS » ET « MES ŒUFS » -------------------------------------------------------------------
	-- (Demande du joueur, sur des captures d'un jeu qu'il aime : une grille de cartes de la couleur du rang, avec la
	-- note du rang (C, B, A, S, SS, SSS), le niveau, une coche sur ceux de l'équipe ; à droite, la fiche du familier
	-- choisi ; et les œufs en grille avec leur nombre.)
	local equipBestEvent = ReplicatedStorage:WaitForChild("EquipBest")
	-- Les potions du joueur (Potions.luau ; attribut « Potions » : « rank:1,xp:0,coins:2,damage:0 »).
	local potionEvent = ReplicatedStorage:WaitForChild("UsePotion")
	local function potionCount(kind: string): number
		return tonumber(string.match(player:GetAttribute("Potions") or "", kind .. ":(%d+)")) or 0
	end
	local takeEvent = ReplicatedStorage:WaitForChild("TakeEgg")
	local unequipAllEvent = ReplicatedStorage:WaitForChild("UnequipAll")
	local GRADES = { "C", "B", "A", "S", "SS", "SSS" }
	local NAVY, GOLDEN = Color3.fromRGB(22, 32, 58), Color3.fromRGB(226, 178, 96)
	local GOLD = Color3.fromRGB(255, 221, 51)
	local function darker(color: Color3, k: number): Color3
		return Color3.new(color.R * k, color.G * k, color.B * k)
	end
	local function button(parent: Instance, name: string, size: UDim2, position: UDim2, color: Color3, label: string): TextButton
		local item = Instance.new("TextButton")
		item.Name = name
		item.Size = size
		item.Position = position
		item.BackgroundColor3 = color
		item.Text = ""
		item.ZIndex = 5
		Instance.new("UICorner", item).CornerRadius = UDim.new(0, 8)
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2.5
		stroke.Color = Color3.fromRGB(14, 18, 30)
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = item
		local text = env.text(item, "Label", UDim2.fromScale(0.92, 0.74), UDim2.fromScale(0.04, 0.13))
		text.Text = label
		text.ZIndex = 6
		item.Parent = parent
		return item
	end
	-- Une fenêtre au milieu de l'écran : fond bleu nuit, liseré doré, titre doré, croix rouge pour fermer.
	local function window(name: string, title: string, width: number, height: number): Frame
		local frame = env.box(env.gui, name, UDim2.fromOffset(width, height), UDim2.fromScale(0.5, 0.5), NAVY)
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Visible = false
		frame.ZIndex = 4
		frame.UIStroke.Color = GOLDEN
		frame.UIStroke.Thickness = 3
		local scale = Instance.new("UIScale")
		scale.Name = "Scale"
		scale.Parent = frame
		local heading = env.text(frame, "Title", UDim2.new(1, -120, 0, 40), UDim2.fromOffset(60, 8), GOLDEN, 34)
		heading.Text = title
		heading.ZIndex = 5
		local close = button(frame, "Close", UDim2.fromOffset(44, 44), UDim2.new(1, -30, 0, -14), Color3.fromRGB(226, 50, 50), "X")
		close.Activated:Connect(function()
			frame.Visible = false
		end)
		return frame
	end
	local function fitWindow(frame: Frame)
		local view = workspace.CurrentCamera.ViewportSize
		frame.Scale.Scale = math.min(1, (view.Y - 30) / (frame.Size.Y.Offset + 30), (view.X - 20) / (frame.Size.X.Offset + 20))
	end
	-- Le portrait en 3D d'un modèle, dans un cadre.
	local function portrait(parent: Instance, size: UDim2, position: UDim2): ViewportFrame
		local view = Instance.new("ViewportFrame")
		view.Name = "Portrait"
		view.Size = size
		view.Position = position
		view.BackgroundTransparency = 1
		view.Ambient = Color3.fromRGB(210, 210, 220)
		view.LightColor = Color3.new(1, 1, 1)
		view.LightDirection = Vector3.new(1, -1.2, 1)
		view.ZIndex = 5
		view.Parent = parent
		return view
	end
	local function show(view: ViewportFrame, key: string, build: () -> Model?)
		if view:GetAttribute("Key") == key then
			return
		end
		view:SetAttribute("Key", key)
		view:ClearAllChildren()
		local model = build()
		if not model then
			return
		end
		model.Parent = view
		local center, size = model:GetBoundingBox()
		local distance = math.max(size.X, size.Y, size.Z) * 1.45
		local camera = Instance.new("Camera")
		camera.FieldOfView = 40
		camera.CFrame = CFrame.lookAt(center.Position + Vector3.new(-distance * 0.55, distance * 0.3, -distance), center.Position)
		camera.Parent = view
		view.CurrentCamera = camera
	end
	local function eggModel(animal: string): Model?
		local visuals = ReplicatedStorage:FindFirstChild("EggVisuals")
		local template = visuals and visuals:FindFirstChild(animal)
		if template and template:IsA("Model") then
			return template:Clone()
		end
		local model = Instance.new("Model")
		local shell = Instance.new("Part")
		shell.Shape = Enum.PartType.Ball
		shell.Size = Vector3.new(2, 2.6, 2)
		shell.Color = EGG_COLORS[animal] or Color3.new(1, 1, 1)
		shell.Anchored = true
		shell.Parent = model
		return model
	end
	-- Une carte de la grille : la couleur du rang, la note, le portrait, une ligne en bas, une coche.
	local function card(parent: Instance, name: string)
		local item = Instance.new("TextButton")
		item.Name = name
		item.Size = UDim2.fromOffset(100, 100)
		item.Text = ""
		item.AutoButtonColor = false
		item.ZIndex = 5
		Instance.new("UICorner", item).CornerRadius = UDim.new(0, 10)
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = item
		local view = portrait(item, UDim2.fromScale(0.9, 0.9), UDim2.fromScale(0.05, 0.02))
		local grade = env.text(item, "Grade", UDim2.fromOffset(44, 26), UDim2.fromOffset(4, 2), nil, 24)
		grade.TextXAlignment = Enum.TextXAlignment.Left
		grade.ZIndex = 6
		local line = env.text(item, "Line", UDim2.new(1, -6, 0, 20), UDim2.new(0, 3, 1, -22), nil, 17)
		line.ZIndex = 6
		local tick = env.text(item, "Tick", UDim2.fromOffset(30, 30), UDim2.new(1, -30, 0, -2), Color3.fromRGB(90, 255, 90), 28)
		tick.Text = "✓"
		tick.ZIndex = 6
		item.Parent = parent
		return { frame = item, stroke = stroke, view = view, grade = grade, line = line, tick = tick }
	end
	-- grade : la note de taille (B, A, S) ; rien pour un œuf du sac.
	local GRADE_COLORS = { C = Color3.fromRGB(200, 204, 214), B = Color3.fromRGB(120, 200, 255), A = Color3.fromRGB(120, 255, 120), S = GOLD }
	local function paint(item, rarity: number, selected: boolean, grade: string?)
		local info = rarityInfo(rarity)
		item.frame.BackgroundColor3 = darker(info.color, 0.45)
		item.stroke.Color = if selected then Color3.new(1, 1, 1) else info.color
		item.stroke.Thickness = if selected then 4 else 3
		item.grade.Text = grade or ""
		item.grade.TextColor3 = GRADE_COLORS[grade or ""] or info.color
	end
	local function grid(parent: Instance, size: UDim2, position: UDim2): ScrollingFrame
		local back = env.box(parent, "GridBack", size, position, Color3.fromRGB(14, 22, 42))
		back.ZIndex = 4
		back.UIStroke.Thickness = 2
		back.UIStroke.Color = Color3.fromRGB(40, 56, 96)
		local list = Instance.new("ScrollingFrame")
		list.Name = "Grid"
		list.Size = UDim2.new(1, -12, 1, -12)
		list.Position = UDim2.fromOffset(8, 6)
		list.BackgroundTransparency = 1
		list.BorderSizePixel = 0
		list.ScrollBarThickness = 8
		list.ZIndex = 5
		list.Parent = back
		local layout = Instance.new("UIGridLayout")
		layout.CellSize = UDim2.fromOffset(100, 100)
		layout.CellPadding = UDim2.fromOffset(10, 10)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = list
		layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			list.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y / math.max(0.01, (list.Parent.Parent :: any).Scale.Scale) + 8)
		end)
		return list
	end

	-- LES ŒUFS : le bouton (avec le nombre d'œufs à poser ou qui couvent), et la fenêtre.
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
	local seenEggs = 0
	local badge = env.box(eggButton, "Badge", UDim2.fromOffset(28, 28), UDim2.new(1, -14, 1, -14), Color3.fromRGB(40, 190, 60))
	badge:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)
	local badgeText = env.text(badge, "Label", UDim2.fromScale(0.9, 0.8), UDim2.fromScale(0.05, 0.1))

	-- Deux parties bien séparées : en haut les œufs DISPONIBLES (dans le sac, à sortir), en bas ceux qui COUVENT.
	local eggPanel = window("EggPanel", tr("eggsTitle"), 600, 560)
	local eggInfo = env.text(eggPanel, "Info", UDim2.new(1, -40, 0, 24), UDim2.fromOffset(20, 52), GOLD, 20)
	eggInfo.TextXAlignment = Enum.TextXAlignment.Left
	eggInfo.ZIndex = 5
	local eggGrid = grid(eggPanel, UDim2.new(1, -40, 0, 236), UDim2.fromOffset(20, 80))
	local hatchInfo = env.text(eggPanel, "Hatching", UDim2.new(1, -40, 0, 24), UDim2.fromOffset(20, 324), Color3.fromRGB(120, 200, 255), 20)
	hatchInfo.TextXAlignment = Enum.TextXAlignment.Left
	hatchInfo.ZIndex = 5
	local hatchGrid = grid(eggPanel, UDim2.new(1, -40, 0, 190), UDim2.fromOffset(20, 352))
	local eggCards, hatchCards = {}, {}

	-- LES FAMILIERS : le bouton patte, et la fenêtre (la grille à gauche, la fiche à droite).
	local pawButton = squareButton("PawButton", 1, Color3.fromRGB(255, 150, 40))
	env.text(pawButton, "Label", UDim2.fromScale(0.8, 0.8), UDim2.fromScale(0.1, 0.1)).Text = "🐾"
	local petPanel = window("PetPanel", tr("petsTitle"), 800, 570)
	local petCount = env.text(petPanel, "Count", UDim2.fromOffset(200, 22), UDim2.fromOffset(24, 54), GREEN, 18)
	petCount.TextXAlignment = Enum.TextXAlignment.Left
	petCount.ZIndex = 5
	local addPlace = button(petPanel, "AddPlace", UDim2.fromOffset(200, 30), UDim2.fromOffset(276, 50), Color3.fromRGB(90, 200, 50), "")
	addPlace.Activated:Connect(function()
		upgradeEvent:FireServer()
	end)
	local petGrid = grid(petPanel, UDim2.fromOffset(470, 410), UDim2.fromOffset(20, 86))
	local petCards = {}
	local selected = 0 -- la place du familier dont on voit la fiche
	local best = button(petPanel, "Best", UDim2.fromOffset(226, 46), UDim2.fromOffset(20, 508), Color3.fromRGB(60, 200, 70), tr("equipBest"))
	local none = button(petPanel, "None", UDim2.fromOffset(226, 46), UDim2.fromOffset(264, 508), Color3.fromRGB(50, 130, 230), tr("unequipAll"))
	best.Activated:Connect(function()
		equipBestEvent:FireServer()
	end)
	none.Activated:Connect(function()
		unequipAllEvent:FireServer()
	end)
	-- La fiche.
	local sheet = env.box(petPanel, "Sheet", UDim2.fromOffset(280, 468), UDim2.fromOffset(502, 86), Color3.fromRGB(30, 44, 78))
	sheet.ZIndex = 4
	sheet.UIStroke.Thickness = 3
	local sheetGrade = env.text(sheet, "Grade", UDim2.fromOffset(70, 40), UDim2.fromOffset(10, 4), GOLD, 38)
	sheetGrade.TextXAlignment = Enum.TextXAlignment.Left
	sheetGrade.ZIndex = 5
	local sheetName = env.text(sheet, "Name", UDim2.new(1, -104, 0, 30), UDim2.fromOffset(96, 8), nil, 26)
	sheetName.ZIndex = 5
	local sheetRarity = env.text(sheet, "Rarity", UDim2.new(1, -20, 0, 20), UDim2.fromOffset(10, 44), nil, 18)
	sheetRarity.ZIndex = 5
	local sheetView = portrait(sheet, UDim2.fromOffset(200, 170), UDim2.fromOffset(40, 62))
	local sheetFight = env.text(sheet, "Fight", UDim2.new(1, -20, 0, 30), UDim2.fromOffset(10, 236), nil, 26)
	sheetFight.ZIndex = 5
	local sheetIncome = env.text(sheet, "Income", UDim2.new(1, -20, 0, 20), UDim2.fromOffset(10, 270), GREEN, 17)
	sheetIncome.ZIndex = 5
	local sheetLuck = env.text(sheet, "Luck", UDim2.new(1, -20, 0, 20), UDim2.fromOffset(10, 292), GOLD, 17)
	sheetLuck.ZIndex = 5
	local xpBack = env.box(sheet, "Xp", UDim2.new(1, -24, 0, 26), UDim2.fromOffset(12, 322), Color3.fromRGB(14, 18, 30))
	xpBack.ZIndex = 5
	xpBack.UIStroke.Thickness = 2
	local xpFill = Instance.new("Frame")
	xpFill.BorderSizePixel = 0
	xpFill.BackgroundColor3 = Color3.fromRGB(60, 200, 80)
	xpFill.ZIndex = 5
	Instance.new("UICorner", xpFill).CornerRadius = UDim.new(0, 8)
	xpFill.Parent = xpBack
	local xpLabel = env.text(xpBack, "Label", UDim2.fromScale(0.96, 0.8), UDim2.fromScale(0.02, 0.1), nil, 17)
	xpLabel.ZIndex = 6
	local equip = button(sheet, "Equip", UDim2.fromOffset(124, 44), UDim2.fromOffset(12, 362), Color3.fromRGB(50, 130, 230), "")
	local sell = button(sheet, "Sell", UDim2.fromOffset(124, 44), UDim2.fromOffset(144, 362), Color3.fromRGB(226, 50, 50), "")
	-- LA FIOLE VERTE à côté de la note : boire une potion de rang sur ce familier (visible quand on en a une et
	-- qu'il n'est pas déjà S).
	local rankUp = button(sheet, "RankUp", UDim2.fromOffset(40, 40), UDim2.fromOffset(50, 6), Color3.fromRGB(50, 200, 80), "")
	Draw.potion(rankUp, UDim2.fromScale(0.5, 0.5), 0.3, Draw.POTIONS.rank.color, Draw.POTIONS.rank.glyph)
	rankUp.Visible = false
	rankUp.Activated:Connect(function()
		if selected > 0 then
			potionEvent:FireServer("rank", selected)
		end
	end)
	equip.Activated:Connect(function()
		if selected > 0 then
			equipEvent:FireServer(selected)
		end
	end)
	-- NOURRIR : on appuie sur « Nourrir », puis on clique sur le familier à lui donner à manger (il disparaît, et le
	-- familier choisi reçoit 75 % de son XP).
	local feedEvent = ReplicatedStorage:WaitForChild("FeedPet")
	local feeding = false
	local doomed = 0 -- la place du familier qui attend la confirmation « es-tu sûr ? »
	local feed = button(sheet, "Feed", UDim2.fromOffset(160, 44), UDim2.fromOffset(12, 414), Color3.fromRGB(240, 170, 30), "")
	-- « Au sac » : range ce familier dans le sac (il libère sa place dans l'enclos).
	local bagEvent = ReplicatedStorage:WaitForChild("BagPet")
	local toBag = button(sheet, "ToBag", UDim2.fromOffset(88, 44), UDim2.fromOffset(180, 414), Color3.fromRGB(120, 90, 200), tr("toBag"))
	toBag.Activated:Connect(function()
		if selected > 0 then
			bagEvent:FireServer(selected)
		end
	end)
	feed.Activated:Connect(function()
		feeding = not feeding
		doomed = 0
		if feeding then
			showToast(tr("feedPick"), GOLD)
		end
	end)
	-- « Vendre » : le joueur prend le familier dans ses bras pour le porter au stand (un 2e appui le repose).
	sell.Activated:Connect(function()
		if selected > 0 then
			local out = (player:GetAttribute("Held") or "") == tostring(selected)
			sellEvent:FireServer(selected)
			-- (La fenêtre se ferme quand on le prend : on peut cliquer dans l'enclos tout de suite.)
			if not out then
				petPanel.Visible = false
			end
		end
	end)

	local function refreshPanels()
		local spots = Pets.decode(player:GetAttribute("Spots"))
		local places = player:GetAttribute("Places") or Pets.SPOTS_FREE
		local inTeam = string.split(player:GetAttribute("Team") or "", ",")
		local bag = player:GetAttribute("Bag") or 0
		local pets, eggs = {}, {}
		for index, spot in spots do
			table.insert(if spot.v then pets else eggs, { index = tonumber(index), spot = spot })
		end
		-- Les plus forts d'abord.
		table.sort(pets, function(a, b)
			local x, y = Pets.damageOf(a.spot), Pets.damageOf(b.spot)
			return if x == y then a.index < b.index else x > y
		end)
		table.sort(eggs, function(a, b)
			return a.spot.t < b.spot.t
		end)
		-- La pastille ne compte que les œufs NOUVEAUX depuis la dernière fois que la fenêtre a été ouverte (sa
		-- demande : « quand j'ouvre, les notifs se ferment »).
		local total = bag + #eggs
		if eggPanel.Visible then
			seenEggs = total
		end
		seenEggs = math.min(seenEggs, total)
		badgeText.Text = tostring(total - seenEggs)
		badge.Visible = total > seenEggs

		-- LES ŒUFS : en haut ceux du sac, groupés (« x12 »), à sortir d'un clic ; en bas ceux qui couvent dans l'enclos,
		-- avec le temps qu'il reste.
		if eggPanel.Visible then
			local ready, hatching = {}, {}
			for animal, rank, count in string.gmatch(player:GetAttribute("BagList") or "", "(%a+):(%d):(%d+)") do
				table.insert(ready, { animal = animal, rank = tonumber(rank), line = "x" .. count, bag = true })
			end
			for _, entry in eggs do
				table.insert(hatching, { animal = entry.spot.a, rank = entry.spot.q, line = "⏳ " .. clock(entry.spot.t - workspace:GetServerTimeNow()), grade = Pets.gradeOf(entry.spot) })
			end
			eggInfo.Text = if #ready == 0 then tr("eggsEmpty") else tr("eggsReady", bag)
			hatchInfo.Text = if #hatching == 0 then tr("eggsNoHatch") else tr("eggsHatching", #hatching)
			local function fillGrid(list, cards, parent, name: string)
				for i, entry in list do
					local item = cards[i]
					if not item then
						item = card(parent, name .. i)
						item.frame.LayoutOrder = i
						-- Un clic sur un œuf du sac le SORT (sur la tête) ; un clic sur celui qu'on porte le RENTRE.
						item.frame.Activated:Connect(function()
							if item.bag then
								takeEvent:FireServer(item.animal, item.rank)
								if not item.out then
									eggPanel.Visible = false
								end
							end
						end)
						cards[i] = item
					end
					item.frame.Visible = true
					item.animal, item.rank, item.bag = entry.animal, entry.rank, entry.bag == true
					item.out = entry.bag == true and string.match(player:GetAttribute("BagNext") or "", "^(%a+:%d)") == entry.animal .. ":" .. entry.rank
					item.tick.Visible = item.out
					paint(item, entry.rank, item.out, entry.grade)
					item.line.Text = entry.line
					show(item.view, entry.animal, function()
						return eggModel(entry.animal)
					end)
				end
				for i = #list + 1, #cards do
					cards[i].frame.Visible = false
				end
			end
			fillGrid(ready, eggCards, eggGrid, "Egg")
			fillGrid(hatching, hatchCards, hatchGrid, "Hatch")
			fitWindow(eggPanel)
		end

		-- LES FAMILIERS.
		if not petPanel.Visible then
			return
		end
		local price = Pets.spotPrice(places)
		petCount.Text = tr("active", #pets, places)
		addPlace.Visible = price ~= nil
		addPlace.Label.Text = if price then tr("addPlace", env.num(price)) else ""
		if not spots[tostring(selected)] or not spots[tostring(selected)].v then
			selected = if pets[1] then pets[1].index else 0
		end
		for i, entry in pets do
			local item = petCards[i]
			if not item then
				item = card(petGrid, "Pet" .. i)
				item.frame.LayoutOrder = i
				item.frame.Activated:Connect(function()
					if feeding and item.spot ~= selected then
						-- Celui-ci sera mangé par le familier de la fiche. PREMIER clic : on demande « es-tu sûr ? »
						-- (il disparaît pour toujours). DEUXIÈME clic sur le même : c'est fait.
						if doomed ~= item.spot then
							doomed = item.spot
							local spots = Pets.decode(player:GetAttribute("Spots"))
							local meal, eater = spots[tostring(item.spot)], spots[tostring(selected)]
							local sure = tr("feedSure", tr(meal and meal.a or "?"))
							if meal and eater then
								sure ..= "  " .. tr("feedLevel", tr(eater.a), Pets.levelOf(eater), Pets.levelAfter(eater, meal))
							end
							showToast(sure, RED)
							refreshPanels()
							return
						end
						feeding, doomed = false, 0
						feedEvent:FireServer(selected, item.spot)
						return
					end
					feeding, doomed = false, 0
					selected = item.spot
					refreshPanels()
				end)
				petCards[i] = item
			end
			item.spot = entry.index
			item.frame.Visible = true
			paint(item, entry.spot.q, entry.index == selected, Pets.gradeOf(entry.spot))
			-- (En nourrissant : sur chaque familier, le niveau qu'atteindrait celui de la fiche en le mangeant.)
			local eater = spots[tostring(selected)]
			item.line.Text = if feeding and entry.index == doomed then tr("feedConfirm")
				elseif feeding and entry.index ~= selected then (if eater then tr("feedTo", Pets.levelAfter(eater, entry.spot)) else tr("feedThis"))
				else tr("lvlLong", Pets.levelOf(entry.spot))
			item.line.TextColor3 = if feeding and entry.index == doomed then RED else Color3.new(1, 1, 1)
			item.tick.Visible = table.find(inTeam, tostring(entry.index)) ~= nil
			show(item.view, entry.spot.a .. entry.spot.q, function()
				return Pets.build(entry.spot.a, entry.spot.q, true)
			end)
		end
		for i = #pets + 1, #petCards do
			petCards[i].frame.Visible = false
		end
		-- La fiche du familier choisi.
		local spot = spots[tostring(selected)]
		sheet.Visible = spot ~= nil
		if spot then
			local info = rarityInfo(spot.q)
			local member = table.find(inTeam, tostring(selected)) ~= nil
			sheet.UIStroke.Color = info.color
			sheetGrade.Text = Pets.gradeOf(spot)
			sheetGrade.TextColor3 = GRADE_COLORS[Pets.gradeOf(spot)]
			rankUp.Visible = potionCount("rank") > 0 and Pets.gradeOf(spot) ~= "S"
			feed.Label.Text = if feeding then tr("feedCancel") else tr("feed")
			feed.BackgroundColor3 = if feeding then Color3.fromRGB(90, 96, 120) else Color3.fromRGB(240, 170, 30)
			sheetName.Text = tr(spot.a)
			sheetRarity.Text = tr(info.key)
			sheetRarity.TextColor3 = info.color
			show(sheetView, spot.a .. spot.q, function()
				return Pets.build(spot.a, spot.q, true)
			end)
			sheetFight.Text = tr("petFight", env.num(Pets.damageOf(spot)), env.num(Pets.healthOf(spot)))
			sheetIncome.Text = tr("income", amount(Pets.incomeOf(spot.a, spot.v)))
			sheetLuck.Text = tr("luckLine", Pets.luckOf(spot))
			local need = Pets.xpNeed(spot)
			xpFill.Size = UDim2.fromScale(math.clamp((spot.xp or 0) / need, 0, 1), 1)
			xpLabel.Text = tr("lvlLong", Pets.levelOf(spot)) .. "   " .. env.num(spot.xp or 0) .. " / " .. env.num(need)
			equip.Label.Text = if member then tr("unequip") else tr("equip")
			equip.BackgroundColor3 = if member then Color3.fromRGB(50, 130, 230) else Color3.fromRGB(240, 170, 30)
			local carrying = (player:GetAttribute("Held") or "") == tostring(selected)
			sell.Label.Text = if carrying then tr("putBack") else tr("takeOut")
			sell.BackgroundColor3 = if carrying then Color3.fromRGB(255, 150, 40) else Color3.fromRGB(226, 50, 50)
		end
		fitWindow(petPanel)
	end
	for _, name in { "Spots", "Places", "Team", "Bag", "BagList", "Held", "BagNext", "Potions" } do
		player:GetAttributeChangedSignal(name):Connect(refreshPanels)
	end
	task.spawn(function()
		-- (Le temps de couvaison des œufs avance.)
		while true do
			refreshPanels()
			task.wait(0.5)
		end
	end)
	-- LA BOUTIQUE : on y dépense ses pièces. L'épée (plus de dégâts pour soi) et les places de l'enclos.
	-- LES POTIONS (sa demande du 09/10) : le bouton « Potions » et la fenêtre où l'on voit ses fioles et où on les boit.
	-- Les potions à durée se boivent ici ; la potion de rang se boit sur la fiche d'un familier (la fiole verte).
	local potionButton = squareButton("PotionButton", 5, Color3.fromRGB(170, 60, 210))
	Draw.potion(potionButton, UDim2.fromScale(0.5, 0.5), 0.5, Color3.fromRGB(255, 90, 220), "")
	local potionPanel = window("PotionPanel", tr("potionsTitle"), 760, 430)
	local potionNote = env.text(potionPanel, "Note", UDim2.new(1, -40, 0, 22), UDim2.new(0, 20, 1, -30), GOLD, 17)
	potionNote.Text = tr("potionsNote")
	potionNote.ZIndex = 5
	local potionCards = {}
	for index, kind in Config.POTION_ORDER do
		local look = Draw.POTIONS[kind]
		local card = env.box(potionPanel, "Card" .. index, UDim2.fromOffset(172, 312), UDim2.fromOffset(16 + (index - 1) * 184, 66), look.color:Lerp(Color3.fromRGB(10, 10, 26), 0.82))
		card.ZIndex = 5
		card.UIStroke.Color = look.color
		card.UIStroke.Thickness = 3
		local rays = Draw.rays(card, UDim2.fromOffset(86, 92), look.color)
		Draw.potion(card, UDim2.fromOffset(86, 92), 1.15, look.color, look.glyph)
		local name = env.text(card, "Name", UDim2.new(1, -12, 0, 30), UDim2.fromOffset(6, 170), look.color:Lerp(Color3.new(1, 1, 1), 0.35), 22)
		name.Text = tr("potion_" .. kind)
		name.ZIndex = 6
		local desc = env.text(card, "Desc", UDim2.new(1, -16, 0, 44), UDim2.fromOffset(8, 202), nil, 15)
		local def = Config.POTIONS[kind]
		desc.Text = if def.seconds then tr("potionDesc_" .. kind, def.seconds // 60) else tr("potionDesc_" .. kind)
		desc.ZIndex = 6
		local drink = button(card, "Drink", UDim2.new(1, -20, 0, 44), UDim2.new(0, 10, 1, -54), Color3.fromRGB(50, 200, 80), "")
		drink.Activated:Connect(function()
			if potionCount(kind) <= 0 then
				showToast(tr("potionNone"), RED)
			elseif kind == "rank" then
				potionPanel.Visible = false
				petPanel.Visible = true
				showToast(tr("potionPick"), GOLD)
			else
				potionEvent:FireServer(kind)
			end
		end)
		potionCards[kind] = { drink = drink, rays = rays }
	end
	local function refreshPotions()
		if not potionPanel.Visible then
			return
		end
		for kind, parts in potionCards do
			local count = potionCount(kind)
			parts.drink.Label.Text = if count > 0 then tr("potionDrink", count) else tr("potionEmpty")
			parts.drink.BackgroundColor3 = if count > 0 then Color3.fromRGB(50, 200, 80) else Color3.fromRGB(90, 96, 120)
		end
		fitWindow(potionPanel)
	end
	player:GetAttributeChangedSignal("Potions"):Connect(refreshPotions)
	potionPanel:GetPropertyChangedSignal("Visible"):Connect(refreshPotions)
	game:GetService("RunService").RenderStepped:Connect(function()
		if potionPanel.Visible then
			for _, parts in potionCards do
				parts.rays.Rotation = os.clock() * 20
			end
		end
	end)
	potionButton.Activated:Connect(function()
		potionPanel.Visible = not potionPanel.Visible
	end)
	-- LE SAC : les familiers rangés hors de l'enclos. Un clic sur l'un d'eux le remet dans l'enclos.
	local bagButton = squareButton("BagButton", 2, Color3.fromRGB(120, 90, 200))
	env.text(bagButton, "Label", UDim2.fromScale(0.8, 0.8), UDim2.fromScale(0.1, 0.1)).Text = "🎒"
	local bagPanel = window("BagPanel", tr("bagTitle"), 600, 460)
	local bagInfo = env.text(bagPanel, "Info", UDim2.new(1, -40, 0, 24), UDim2.fromOffset(20, 52), GOLD, 18)
	bagInfo.TextXAlignment = Enum.TextXAlignment.Left
	bagInfo.ZIndex = 5
	local bagGrid = grid(bagPanel, UDim2.new(1, -40, 1, -104), UDim2.fromOffset(20, 84))
	local bagCards = {}
	local unbagEvent = ReplicatedStorage:WaitForChild("UnbagPet")
	local function refreshBag()
		if not bagPanel.Visible then
			return
		end
		local store = Pets.decodeStore(player:GetAttribute("Store"))
		local spots = Pets.decode(player:GetAttribute("Spots"))
		local places, used = player:GetAttribute("Places") or Pets.SPOTS_FREE, 0
		for _, spot in spots do
			if spot.v then
				used += 1
			end
		end
		bagInfo.Text = if #store == 0 then tr("bagEmpty") else tr("bagHint", #store, math.max(0, places - used))
		for i, pet in store do
			local item = bagCards[i]
			if not item then
				item = card(bagGrid, "Bag" .. i)
				item.frame.LayoutOrder = i
				item.tick.Visible = false
				item.frame.Activated:Connect(function()
					unbagEvent:FireServer(i)
				end)
				bagCards[i] = item
			end
			item.frame.Visible = true
			paint(item, pet.q, false, Pets.gradeOf(pet))
			item.line.Text = tr("lvlLong", Pets.levelOf(pet))
			show(item.view, pet.a .. pet.q, function()
				return Pets.build(pet.a, pet.q, true)
			end)
		end
		for i = #store + 1, #bagCards do
			bagCards[i].frame.Visible = false
		end
		fitWindow(bagPanel)
	end
	for _, name in { "Store", "Spots", "Places" } do
		player:GetAttributeChangedSignal(name):Connect(refreshBag)
	end
	bagPanel:GetPropertyChangedSignal("Visible"):Connect(refreshBag)

	-- LA FENÊTRE DE VENTE (au stand du vendeur) : tous les familiers, ceux de l'enclos puis ceux du sac, avec leur
	-- prix. Un clic en choisit un, le bouton du bas le vend. Ceux de l'équipe portent leur coche.
	local sellPanel = window("SellPanel", tr("sellTitle"), 600, 520)
	local sellInfo = env.text(sellPanel, "Info", UDim2.new(1, -40, 0, 24), UDim2.fromOffset(20, 52), GOLD, 18)
	sellInfo.TextXAlignment = Enum.TextXAlignment.Left
	sellInfo.ZIndex = 5
	local sellGrid = grid(sellPanel, UDim2.new(1, -40, 1, -168), UDim2.fromOffset(20, 84))
	local sellGo = button(sellPanel, "Go", UDim2.new(1, -40, 0, 54), UDim2.new(0, 20, 1, -70), Color3.fromRGB(226, 50, 50), "")
	local sellCards, sellList, sellPick = {}, {}, ""
	local sellNow = ReplicatedStorage:WaitForChild("SellNow")
	local function refreshSell()
		if not sellPanel.Visible then
			return
		end
		local spots = Pets.decode(player:GetAttribute("Spots"))
		local store = Pets.decodeStore(player:GetAttribute("Store"))
		local team = string.split(player:GetAttribute("Team") or "", ",")
		sellList = {}
		local keys = {}
		for key, spot in spots do
			if spot.v then
				table.insert(keys, tonumber(key))
			end
		end
		table.sort(keys)
		for _, index in keys do
			table.insert(sellList, { id = "pen" .. index, kind = "pen", index = index, pet = spots[tostring(index)], team = table.find(team, tostring(index)) ~= nil })
		end
		for index, pet in store do
			table.insert(sellList, { id = "bag" .. index, kind = "bag", index = index, pet = pet, team = false })
		end
		local chosen = nil
		for i, entry in sellList do
			local item = sellCards[i]
			if not item then
				item = card(sellGrid, "Sell" .. i)
				item.frame.LayoutOrder = i
				item.frame.Activated:Connect(function()
					local now = sellList[i]
					sellPick = if now and sellPick ~= now.id then now.id else ""
					refreshSell()
				end)
				sellCards[i] = item
			end
			local pet = entry.pet
			item.frame.Visible = true
			item.tick.Visible = entry.team
			paint(item, pet.q, sellPick == entry.id, Pets.gradeOf(pet))
			item.line.Text = env.num(Pets.sellPrice(pet.a, pet.v)) .. " $"
			show(item.view, pet.a .. pet.q, function()
				return Pets.build(pet.a, pet.q, true)
			end)
			if sellPick == entry.id then
				chosen = entry
			end
		end
		for i = #sellList + 1, #sellCards do
			sellCards[i].frame.Visible = false
		end
		if not chosen then
			sellPick = ""
		end
		sellInfo.Text = if #sellList == 0 then tr("sellEmpty") else tr("sellHint")
		sellGo.Label.Text = if chosen then tr("sellNowGo", tr(chosen.pet.a), tr("lvlLong", Pets.levelOf(chosen.pet)), env.num(Pets.sellPrice(chosen.pet.a, chosen.pet.v))) else tr("sellPick")
		sellGo.BackgroundColor3 = if chosen then Color3.fromRGB(226, 50, 50) else Color3.fromRGB(90, 96, 120)
		sellGo:SetAttribute("Kind", chosen and chosen.kind or "")
		sellGo:SetAttribute("Index", chosen and chosen.index or 0)
		fitWindow(sellPanel)
	end
	sellGo.Activated:Connect(function()
		local kind, index = sellGo:GetAttribute("Kind"), sellGo:GetAttribute("Index")
		if kind ~= "" and index > 0 then
			sellPick = ""
			sellNow:FireServer(kind, index)
		end
	end)
	for _, name in { "Store", "Spots", "Team" } do
		player:GetAttributeChangedSignal(name):Connect(refreshSell)
	end
	sellPanel:GetPropertyChangedSignal("Visible"):Connect(refreshSell)
	bagButton.Activated:Connect(function()
		bagPanel.Visible = not bagPanel.Visible
		for _, name in { "ShopPanel", "SwordPanel" } do
			local other = env.gui:FindFirstChild(name)
			if other then
				other.Visible = false
			end
		end
		petPanel.Visible = false
		eggPanel.Visible = false
	end)

	-- L'ÉPÉE : un bouton, et une fenêtre qui montre seulement mon épée et la suivante, avec leurs dégâts.
	local swordButton = squareButton("SwordButton", 3, Color3.fromRGB(240, 80, 80))
	env.text(swordButton, "Label", UDim2.fromScale(0.8, 0.8), UDim2.fromScale(0.1, 0.1)).Text = "⚔"
	local swordPanel = window("SwordPanel", tr("swordTitle"), 560, 380)
	local SWORD_MODELS = require(script.Parent.SwordPalette).gameOrder
	local function swordCard(x: number, title: string)
		local frame = env.box(swordPanel, "Card", UDim2.fromOffset(240, 240), UDim2.fromOffset(x, 60), Color3.fromRGB(30, 44, 78))
		frame.ZIndex = 4
		frame.UIStroke.Thickness = 3
		local head = env.text(frame, "Head", UDim2.new(1, -16, 0, 26), UDim2.fromOffset(8, 6), GOLD, 22)
		head.Text = title
		head.ZIndex = 5
		local view = portrait(frame, UDim2.fromOffset(220, 150), UDim2.fromOffset(10, 34))
		local damage = env.text(frame, "Damage", UDim2.new(1, -16, 0, 40), UDim2.fromOffset(8, 192), nil, 34)
		damage.ZIndex = 5
		return { frame = frame, view = view, damage = damage }
	end
	local swordNow, swordNext = swordCard(24, tr("swordNow")), swordCard(296, tr("swordNext"))
	env.text(swordPanel, "Arrow", UDim2.fromOffset(32, 40), UDim2.fromOffset(264, 160), GOLD, 34).Text = ">"
	local swordBuy = button(swordPanel, "Buy", UDim2.fromOffset(512, 54), UDim2.fromOffset(24, 312), Color3.fromRGB(60, 200, 70), "")
	local buySwordEvent = ReplicatedStorage:WaitForChild("BuySword")
	swordBuy.Activated:Connect(function()
		buySwordEvent:FireServer()
	end)
	local function swordModel(level: number): Model?
		local meshes = ReplicatedStorage:FindFirstChild("SwordMeshes")
		local template = meshes and meshes:FindFirstChild(SWORD_MODELS[math.clamp(level, 1, #SWORD_MODELS)])
		return if template and template:IsA("Model") then template:Clone() else nil
	end
	local function refreshSword()
		if not swordPanel.Visible then
			return
		end
		local sword, level = player:GetAttribute("Sword") or 1, player:GetAttribute("Level") or 1
		local coins, price = player:GetAttribute("Coins") or 0, Config.swordPrice(sword)
		for offset, item in { [0] = swordNow, [1] = swordNext } do
			item.damage.Text = tr("swordDmg", env.num(Config.hitDamage(sword + offset, level)))
			item.frame.UIStroke.Color = if offset == 0 then Color3.fromRGB(120, 200, 255) else GOLD
			show(item.view, "sword" .. math.clamp(sword + offset, 1, #SWORD_MODELS), function()
				return swordModel(sword + offset)
			end)
		end
		swordBuy.Label.Text = tr("swordBuy", env.num(price))
		swordBuy.BackgroundColor3 = if coins >= price then Color3.fromRGB(60, 200, 70) else Color3.fromRGB(200, 70, 70)
		fitWindow(swordPanel)
	end
	for _, name in { "Coins", "Sword", "Level" } do
		player:GetAttributeChangedSignal(name):Connect(refreshSword)
	end
	swordPanel:GetPropertyChangedSignal("Visible"):Connect(refreshSword)
	swordButton.Activated:Connect(function()
		swordPanel.Visible = not swordPanel.Visible
		for _, name in { "PetPanel", "EggPanel", "BagPanel", "ShopPanel" } do
			local other = env.gui:FindFirstChild(name)
			if other then
				other.Visible = false
			end
		end
	end)

	local shopButton = squareButton("ShopButton", 4, Color3.fromRGB(60, 150, 255))
	env.text(shopButton, "Label", UDim2.fromScale(0.8, 0.8), UDim2.fromScale(0.1, 0.1)).Text = "🛒"
	local shopPanel = window("ShopPanel", tr("shopTitle"), 620, 330)
	local swordEvent = ReplicatedStorage:WaitForChild("BuySword")
	local function shopRow(y: number, icon: string, color: Color3)
		local row = env.box(shopPanel, "Row", UDim2.new(1, -40, 0, 110), UDim2.fromOffset(20, y), Color3.fromRGB(30, 44, 78))
		row.ZIndex = 4
		row.UIStroke.Color = color
		row.UIStroke.Thickness = 3
		local picture = env.text(row, "Icon", UDim2.fromOffset(80, 80), UDim2.fromOffset(12, 15))
		picture.Text = icon
		picture.ZIndex = 5
		local title = env.text(row, "Title", UDim2.new(1, -310, 0, 30), UDim2.fromOffset(104, 10), color, 26)
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.ZIndex = 5
		local line = env.text(row, "Line", UDim2.new(1, -310, 0, 26), UDim2.fromOffset(104, 44), nil, 22)
		line.TextXAlignment = Enum.TextXAlignment.Left
		line.ZIndex = 5
		local note = env.text(row, "Note", UDim2.new(1, -310, 0, 20), UDim2.fromOffset(104, 76), Color3.fromRGB(190, 200, 220), 16)
		note.TextXAlignment = Enum.TextXAlignment.Left
		note.ZIndex = 5
		local buy = button(row, "Buy", UDim2.fromOffset(180, 70), UDim2.new(1, -194, 0, 20), Color3.fromRGB(60, 200, 70), "")
		return { title = title, line = line, note = note, buy = buy }
	end
	local swordRow = shopRow(62, "⚔", Color3.fromRGB(255, 110, 110))
	local penRow = shopRow(186, "🐾", Color3.fromRGB(255, 170, 60))
	swordRow.buy.Activated:Connect(function()
		swordEvent:FireServer()
	end)
	penRow.buy.Activated:Connect(function()
		upgradeEvent:FireServer()
	end)
	local function refreshShop()
		if not shopPanel.Visible then
			return
		end
		local coins = player:GetAttribute("Coins") or 0
		local sword, zone = player:GetAttribute("Sword") or 1, player:GetAttribute("Zone") or 1
		local level = player:GetAttribute("Level") or 1
		local maxed = sword >= Config.swordMax(zone)
		local price = Config.swordPrice(sword)
		swordRow.title.Text = tr("shopSword", sword)
		swordRow.line.Text = tr("shopSwordLine", env.num(Config.hitDamage(sword, level)), env.num(Config.hitDamage(sword + 1, level)))
		swordRow.note.Text = if maxed then tr("forgeMax", zone) else tr("shopSwordNote")
		swordRow.buy.Label.Text = if maxed then "MAX" else env.num(price) .. " $"
		swordRow.buy.BackgroundColor3 = if maxed then Color3.fromRGB(90, 96, 120) elseif coins >= price then Color3.fromRGB(60, 200, 70) else Color3.fromRGB(200, 70, 70)
		local places = player:GetAttribute("Places") or Pets.SPOTS_FREE
		local spot = Pets.spotPrice(places)
		penRow.title.Text = tr("shopPen", Pets.penLevel(places))
		penRow.line.Text = tr("shopPenLine", places, places + 1)
		penRow.note.Text = tr("shopPenNote")
		penRow.buy.Label.Text = if spot then env.num(spot) .. " $" else "MAX"
		penRow.buy.BackgroundColor3 = if not spot then Color3.fromRGB(90, 96, 120) elseif coins >= spot then Color3.fromRGB(60, 200, 70) else Color3.fromRGB(200, 70, 70)
		fitWindow(shopPanel)
	end
	for _, name in { "Coins", "Sword", "Zone", "Places", "Level" } do
		player:GetAttributeChangedSignal(name):Connect(refreshShop)
	end
	shopPanel:GetPropertyChangedSignal("Visible"):Connect(refreshShop)
	shopButton.Activated:Connect(function()
		shopPanel.Visible = not shopPanel.Visible
		swordPanel.Visible = false
		bagPanel.Visible = false
		petPanel.Visible = false
		eggPanel.Visible = false
	end)

	petPanel:GetPropertyChangedSignal("Visible"):Connect(refreshPanels)
	eggPanel:GetPropertyChangedSignal("Visible"):Connect(refreshPanels)
	eggButton.Activated:Connect(function()
		eggPanel.Visible = not eggPanel.Visible
		swordPanel.Visible = false
		bagPanel.Visible = false
		petPanel.Visible = false
		shopPanel.Visible = false
	end)
	pawButton.Activated:Connect(function()
		petPanel.Visible = not petPanel.Visible
		swordPanel.Visible = false
		bagPanel.Visible = false
		eggPanel.Visible = false
		shopPanel.Visible = false
	end)

	-- POSER D'UN CLIC -------------------------------------------------------------------------------------------------
	-- Avec un œuf sorti sur la tête, ou un familier dans les bras : un clic (ou un doigt) dans son enclos le pose à
	-- cet endroit. Plus de bouton. (Le serveur vérifie que c'est bien dans l'enclos, sinon il le dit.)
	local putEvent = ReplicatedStorage:WaitForChild("PutPet")
	local function carrying(): string?
		if (player:GetAttribute("BagNext") or "") ~= "" then
			return "egg"
		elseif (player:GetAttribute("Held") or "") ~= "" then
			return "pet"
		end
		return nil
	end
	local function clickGround(ray: Ray)
		local what = carrying()
		if not what or ray.Direction.Y > -0.02 then
			return
		end
		local point = ray.Origin + ray.Direction * ((0.3 - ray.Origin.Y) / ray.Direction.Y)
		if what == "egg" then
			placeEvent:FireServer(point)
		else
			putEvent:FireServer(point)
		end
	end
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.UserInputType == Enum.UserInputType.MouseButton1 then
			local mouse = UserInputService:GetMouseLocation()
			clickGround(workspace.CurrentCamera:ViewportPointToRay(mouse.X, mouse.Y))
		end
	end)
	UserInputService.TouchTapInWorld:Connect(function(position, processed)
		if not processed then
			clickGround(workspace.CurrentCamera:ScreenPointToRay(position.X, position.Y))
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
		elseif key == "openSell" then
			for _, name in { "PetPanel", "EggPanel", "BagPanel", "ShopPanel", "SwordPanel" } do
				local other = env.gui:FindFirstChild(name)
				if other then
					other.Visible = false
				end
			end
			env.gui.SellPanel.Visible = true
		elseif key == "sellFar" then
			showToast(tr("sellFar"), RED)
		elseif key == "openPets" then
			petPanel.Visible = true
			eggPanel.Visible = false
			refreshPanels()
		end
	end)
	refreshPanels()
end

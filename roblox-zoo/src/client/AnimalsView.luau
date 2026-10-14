-- LES ANIMAUX À L'ÉCRAN : chaque animal du zoo (ReplicatedStorage.ZooAnimals) est dessiné ici et se promène dans son
-- espace (il va de temps en temps manger à sa mangeoire). Au-dessus de lui : son nom, son sexe (♂ / ♀) et son humeur
-- quand on est près ; une croix rouge s'il est malade, avec le bouton « Soigner » (il faut porter une trousse).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AnimalModels = require(ReplicatedStorage.Shared.AnimalModels)
local Config = require(ReplicatedStorage.Shared.Config)
local StarterAnimator = require(ReplicatedStorage.Shared.StarterAnimator)

local SWIMMERS = { Capybara = true, Crocodile = true }
local ANIMATE_DISTANCE = 260
local WALK_PLAY = 1.6 -- la marche livrée est jouée plus vite (les animaux de MONDE glissaient)
local WALK_GAIN = 2.4

return function()
	local player = Players.LocalPlayer
	local camera = workspace.CurrentCamera
	local source = ReplicatedStorage:WaitForChild("ZooAnimals")
	local spaces = workspace:WaitForChild("Spaces")
	local treat = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Treat")
	local examine = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Examine")
	local folder = Instance.new("Folder")
	folder.Name = "ZooAnimalsView"
	folder.Parent = workspace
	local random = Random.new()
	local views = {}

	-- Les mares d'un espace (posées par le serveur en attribut « Pools »).
	local poolCache = {}
	local function poolsOf(spaceId: string)
		local spaceFolder = spaces:FindFirstChild(spaceId)
		local text = spaceFolder and spaceFolder:GetAttribute("Pools") or ""
		local cached = poolCache[spaceId]
		if cached and cached.text == text then
			return cached.list
		end
		local list = {}
		for x, z, r in string.gmatch(text, "([%-%d%.]+),([%-%d%.]+),([%-%d%.]+)") do
			table.insert(list, { x = tonumber(x), z = tonumber(z), r = tonumber(r) })
		end
		poolCache[spaceId] = { text = text, list = list }
		return list
	end

	-- La mangeoire de cette nourriture dans cet espace (si elle n'est pas vide).
	local function troughOf(spaceId: string, food: string): BasePart?
		local spaceFolder = spaces:FindFirstChild(spaceId)
		if not spaceFolder then
			return nil
		end
		for _, item in spaceFolder:GetDescendants() do
			if item.Name == "Box" and item:GetAttribute("Food") == food and (item:GetAttribute("Level") or 0) > 0 then
				return item :: BasePart
			end
		end
		return nil
	end

	-- Où vont les animaux d'une parcelle (attribut « Inner » : minX, maxX, minZ, maxZ) et la hauteur de leur sol
	-- (« Floor » : -10 dans la fosse aux ours).
	local areaCache = {}
	local function areaOf(spaceId: string): ({ number }, number)
		local spaceFolder = spaces:FindFirstChild(spaceId)
		local text = spaceFolder and spaceFolder:GetAttribute("Inner") or ""
		local cached = areaCache[spaceId]
		if cached and cached.text == text then
			return cached.inner, cached.floor
		end
		local inner = {}
		for value in string.gmatch(text, "[%-%d%.]+") do
			table.insert(inner, tonumber(value))
		end
		if #inner < 4 then
			local plot = Config.PLOT_BY_ID[spaceId]
			inner = { plot.center.X - plot.size.X / 2 + 3, plot.center.X + plot.size.X / 2 - 3, plot.center.Z - plot.size.Y / 2 + 3, plot.center.Z + plot.size.Y / 2 - 3 }
		end
		local floor = spaceFolder and spaceFolder:GetAttribute("Floor") or 0
		areaCache[spaceId] = { text = text, inner = inner, floor = floor }
		return inner, floor
	end

	local function pickTarget(view): Vector3
		local species = Config.SPECIES[view.species]
		if random:NextNumber() < 0.22 then
			local trough = troughOf(view.space, species.food)
			if trough then
				local side = random:NextNumber(-2, 2)
				return trough.Position + trough.CFrame.LookVector * -3 + trough.CFrame.RightVector * side
			end
		end
		local inner = areaOf(view.space)
		local margin = 1.5
		for _ = 1, 15 do
			local point = Vector3.new(random:NextNumber(inner[1] + margin, inner[2] - margin), 0, random:NextNumber(inner[3] + margin, inner[4] - margin))
			local wet = false
			for _, pool in poolsOf(view.space) do
				if (Vector3.new(pool.x, 0, pool.z) - point).Magnitude < pool.r + 1.5 then
					wet = true
				end
			end
			if not wet or SWIMMERS[view.species] then
				return point
			end
		end
		return Vector3.new((inner[1] + inner[2]) / 2, 0, (inner[3] + inner[4]) / 2)
	end

	-- L'étiquette au-dessus de l'animal.
	local function makeTag(view)
		local gui = Instance.new("BillboardGui")
		gui.Name = "Tag"
		gui.Size = UDim2.fromOffset(130, 34)
		gui.StudsOffsetWorldSpace = Vector3.new(0, view.height + 1.6, 0)
		gui.MaxDistance = 34
		gui.LightInfluence = 0
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextStrokeTransparency = 0.35
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Parent = gui
		view.tagLabel = label
		gui.Parent = view.model.PrimaryPart
		view.tag = gui
		local cross = Instance.new("BillboardGui")
		cross.Name = "Sick"
		cross.Size = UDim2.fromOffset(46, 46)
		cross.StudsOffsetWorldSpace = Vector3.new(0, view.height + 3.4, 0)
		cross.AlwaysOnTop = true
		cross.MaxDistance = 140
		local mark = Instance.new("TextLabel")
		mark.Size = UDim2.fromScale(1, 1)
		mark.BackgroundColor3 = Color3.new(1, 1, 1)
		mark.Text = "+"
		mark.TextScaled = true
		mark.Font = Enum.Font.GothamBlack
		mark.TextColor3 = Color3.fromRGB(220, 40, 40)
		mark.Parent = cross
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = mark
		cross.Parent = view.model.PrimaryPart
		view.cross = cross
		-- Malade : d'abord l'examiner (on saura ce qu'il a), puis le soigner avec le bon médicament.
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Soigner"
		prompt.ObjectText = ""
		prompt.HoldDuration = 1
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.Parent = view.model.PrimaryPart
		prompt.Triggered:Connect(function()
			if view.item:GetAttribute("Examined") then
				treat:FireServer(view.id)
			else
				examine:FireServer(view.id)
			end
		end)
		view.prompt = prompt
	end

	-- Son prénom et son sexe (« Nala ♀ »), ou « Nala (bébé) ».
	local function nameOf(view): string
		local name = view.item:GetAttribute("Name") or ""
		if name == "" then
			local species = Config.SPECIES[view.species]
			name = if view.growth < 1 then species.baby elseif view.sex == "m" then species.m else species.f
		end
		if view.growth < 1 then
			return name .. " (bébé)"
		end
		return name .. (if view.sex == "m" then " ♂" else " ♀")
	end

	local function refreshTag(view)
		local item = view.item
		local happy = item:GetAttribute("Happy") or 100
		local sick = item:GetAttribute("Sick") == true
		local disease = Config.DISEASES[item:GetAttribute("Disease") or ""]
		local examined = item:GetAttribute("Examined") == true
		local mood = if sick then (if disease and examined then disease.fr else "malade") elseif (item:GetAttribute("Pregnant") or 0) > 0 then "enceinte" elseif happy >= 70 then "content" elseif happy >= 45 then "bof" else "triste"
		view.tagLabel.Text = nameOf(view) .. "  ·  " .. mood
		view.tagLabel.TextColor3 = if sick then Color3.fromRGB(255, 120, 120) elseif happy >= 70 then Color3.fromRGB(170, 255, 150) elseif happy >= 45 then Color3.fromRGB(255, 230, 140) else Color3.fromRGB(255, 160, 120)
		view.cross.Enabled = sick
		view.prompt.Enabled = sick
		view.prompt.ObjectText = nameOf(view)
		view.prompt.ActionText = if examined then "Soigner (" .. (if disease then Config.STOCK[disease.med].fr else "?") .. ")" else "Examiner"
		view.prompt.HoldDuration = if examined then 1 else 2
	end

	-- (Re)fabrique le modèle d'un animal (au départ, et quand il grandit).
	local function build(view)
		if view.model then
			view.model:Destroy()
		end
		local model = AnimalModels.build(view.species, view.sex, view.growth)
		if not model then
			-- (Un animal pas encore importé : un bloc à sa taille, pour ne pas le perdre de vue.)
			model = Instance.new("Model")
			local block = Instance.new("Part")
			block.Size = Vector3.new(1.4, 1, 2.2) * (Config.SPECIES[view.species].height * 0.6)
			block.Anchored, block.CanCollide, block.CanQuery = true, false, false
			block.Color = Color3.fromRGB(150, 120, 90)
			block.Parent = model
			model.PrimaryPart = block
		end
		model.Parent = folder
		-- (On peut le cliquer pour ouvrir sa fiche : Main.client.luau.)
		model:SetAttribute("AnimalId", view.id)
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") and part.Transparency < 1 then
				part.CanQuery = true
			end
		end
		model:PivotTo(CFrame.new(0, 100, 0))
		local low, high = AnimalModels.extents(model)
		view.model = model
		view.lift = 100 - low
		view.height = high - low
		view.rig = nil
		if model:FindFirstChild("RigRoot") then
			local ok, rig = pcall(StarterAnimator.bind, model)
			if ok then
				view.rig = rig
			end
		end
		makeTag(view)
		refreshTag(view)
	end

	local function add(item: Instance)
		if not item:IsA("Configuration") then
			return
		end
		local spaceId = item:GetAttribute("Space")
		if not Config.PLOT_BY_ID[spaceId] then
			return
		end
		local view = {
			item = item,
			id = tonumber(item.Name),
			species = item:GetAttribute("Species"),
			sex = item:GetAttribute("Sex"),
			space = spaceId,
			growth = item:GetAttribute("Growth") or 1,
			clock = random:NextNumber(0, 10),
			wait = random:NextNumber(0, 3),
			heading = CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0),
		}
		view.position = pickTarget(view)
		view.target = view.position
		build(view)
		views[item] = view
		item.AttributeChanged:Connect(function(name)
			if name == "Growth" then
				local growth = item:GetAttribute("Growth") or 1
				-- (On refait le modèle par paliers : à chaque dixième de croissance, et à l'âge adulte.)
				if math.floor(growth * 10) ~= math.floor(view.growth * 10) or (growth >= 1) ~= (view.growth >= 1) then
					view.growth = growth
					build(view)
				else
					view.growth = growth
				end
			else
				refreshTag(view)
			end
		end)
	end

	local function remove(item: Instance)
		local view = views[item]
		if view then
			view.model:Destroy()
			views[item] = nil
		end
	end

	for _, item in source:GetChildren() do
		add(item)
	end
	source.ChildAdded:Connect(add)
	source.ChildRemoved:Connect(remove)

	local state = ReplicatedStorage:WaitForChild("ZooState")
	RunService.Heartbeat:Connect(function(dt)
		local eye = camera.CFrame.Position
		local night = (state:GetAttribute("Phase") == "night")
		for _, view in views do
			local species = Config.SPECIES[view.species]
			local far = (view.position - eye).Magnitude > ANIMATE_DISTANCE
			local moving = false
			if view.wait > 0 then
				view.wait -= dt
				if view.wait <= 0 then
					view.target = pickTarget(view)
				end
			else
				local offset = Vector3.new(view.target.X - view.position.X, 0, view.target.Z - view.position.Z)
				local distance = offset.Magnitude
				local speed = species.speed * (0.6 + 0.4 * view.growth)
				if distance < 0.4 then
					view.wait = if night then random:NextNumber(8, 20) else random:NextNumber(2, 7)
				else
					moving = true
					local direction = offset / distance
					view.position += direction * math.min(distance, speed * dt)
					local wanted = CFrame.lookAt(Vector3.zero, direction)
					view.heading = view.heading:Lerp(wanted, 1 - math.exp(-5 * dt))
				end
			end
			if not far then
				view.clock += dt
				local _, floor = areaOf(view.space)
				local base = CFrame.new(view.position.X, floor + view.lift, view.position.Z) * view.heading
				view.model:PivotTo(base)
				if view.rig then
					if moving then
						StarterAnimator.step(view.rig, view.clock * WALK_PLAY, "Walk", WALK_GAIN, true)
					else
						StarterAnimator.step(view.rig, view.clock, "Idle", 1)
					end
				end
			end
		end
	end)
	_ = player
end

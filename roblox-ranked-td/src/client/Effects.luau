-- Effets visuels purement côté client : tirs des tours et barres de vie des ennemis.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local ProximityLabel = require(Shared.ProximityLabel)
local Remotes = require(Shared.Remotes)
local Towers = require(Shared.Towers)

local Effects = {}

local effectsFolder = Instance.new("Folder")
effectsFolder.Name = "Effects"
effectsFolder.Parent = workspace

local function basePart(): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	return part
end

function Effects.tracer(from: Vector3, to: Vector3, color: Color3, width: number)
	local length = (to - from).Magnitude
	if length < 0.1 then
		return
	end
	local part = basePart()
	part.Size = Vector3.new(width, width, length)
	part.CFrame = CFrame.lookAt((from + to) / 2, to)
	part.Color = color
	part.Parent = effectsFolder
	TweenService:Create(part, TweenInfo.new(0.15), { Transparency = 1 }):Play()
	Debris:AddItem(part, 0.2)
end

function Effects.burst(position: Vector3, radius: number, color: Color3, duration: number)
	local part = basePart()
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one
	part.Position = position
	part.Color = color
	part.Transparency = 0.3
	part.Parent = effectsFolder
	TweenService:Create(part, TweenInfo.new(duration), { Size = Vector3.one * radius * 2, Transparency = 1 }):Play()
	Debris:AddItem(part, duration + 0.05)
end

-- Onde circulaire au sol (tours de zone).
function Effects.pulse(position: Vector3, radius: number, color: Color3)
	local ring = basePart()
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.2, 1, 1)
	ring.CFrame = CFrame.new(position.X, position.Y + 0.4, position.Z) * CFrame.Angles(0, 0, math.rad(90))
	ring.Color = color
	ring.Transparency = 0.4
	ring.Parent = effectsFolder
	TweenService:Create(ring, TweenInfo.new(0.35), { Size = Vector3.new(0.2, radius * 2, radius * 2), Transparency = 1 }):Play()
	Debris:AddItem(ring, 0.4)
end

local function partsNamed(model: Model?, names: { [string]: boolean }): { BasePart }
	local found = {}
	if not model then
		return found
	end
	for _, child in model:GetDescendants() do
		if child:IsA("BasePart") and names[child.Name] then
			table.insert(found, child)
		end
	end
	return found
end

local function hideBriefly(model: Model?, names: { [string]: boolean }, duration: number)
	for _, visual in partsNamed(model, names) do
		local transparency = visual.Transparency
		visual.Transparency = 1
		task.delay(duration, function()
			if visual.Parent then
				visual.Transparency = transparency
			end
		end)
	end
end

local animating: { [BasePart]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function recoil(model: Model?, names: { [string]: boolean }, goalOffset: CFrame, outTime: number, returnTime: number)
	for _, visual in partsNamed(model, names) do
		if animating[visual] then
			continue
		end
		animating[visual] = true
		local rest = visual.CFrame
		local outward = TweenService:Create(visual, TweenInfo.new(outTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = rest * goalOffset })
		outward:Play()
		outward.Completed:Once(function()
			if not visual.Parent then
				animating[visual] = nil
				return
			end
			local back = TweenService:Create(visual, TweenInfo.new(returnTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = rest })
			back:Play()
			back.Completed:Once(function()
				animating[visual] = nil
			end)
		end)
	end
end

local function projectilePart(color: Color3, size: Vector3, material): Part
	local projectile = basePart()
	projectile.Size = size
	projectile.Color = color
	projectile.Material = material
	projectile.Transparency = 0
	projectile.Parent = effectsFolder
	return projectile
end

-- Flèche ou carreau réellement visible pendant tout le trajet.
local function linearProjectile(from: Vector3, to: Vector3, color: Color3, heavy: boolean)
	local delta = to - from
	if delta.Magnitude < 0.1 then
		return
	end
	local projectile = projectilePart(color, if heavy then Vector3.new(0.22, 0.22, 2.8) else Vector3.new(0.12, 0.12, 1.8), Enum.Material.Metal)
	local direction = delta.Unit
	projectile.CFrame = CFrame.lookAt(from, from + direction)
	local duration = math.clamp(delta.Magnitude / (if heavy then 90 else 125), 0.12, 0.55)
	TweenService:Create(projectile, TweenInfo.new(duration, Enum.EasingStyle.Linear), { CFrame = CFrame.lookAt(to, to + direction) }):Play()
	Debris:AddItem(projectile, duration + 0.03)
end

-- Pierre de siège avec une vraie trajectoire parabolique.
local function arcingProjectile(from: Vector3, to: Vector3, color: Color3, radius: number)
	local projectile = projectilePart(color, Vector3.one * 0.9, Enum.Material.Rock)
	projectile.Shape = Enum.PartType.Ball
	local distance = (to - from).Magnitude
	local duration = math.clamp(distance / 55, 0.42, 0.9)
	local arc = math.clamp(distance * 0.22, 5, 15)
	task.spawn(function()
		local elapsed = 0
		while elapsed < duration and projectile.Parent do
			local dt = RunService.RenderStepped:Wait()
			elapsed += dt
			local alpha = math.clamp(elapsed / duration, 0, 1)
			local nextAlpha = math.min(1, alpha + 0.025)
			local position = from:Lerp(to, alpha) + Vector3.new(0, math.sin(alpha * math.pi) * arc, 0)
			local nextPosition = from:Lerp(to, nextAlpha) + Vector3.new(0, math.sin(nextAlpha * math.pi) * arc, 0)
			projectile.CFrame = CFrame.lookAt(position, nextPosition)
		end
		if projectile.Parent then
			projectile:Destroy()
			Effects.burst(to, math.max(1.8, radius), color, 0.24)
		end
	end)
end

local function magicProjectile(from: Vector3, to: Vector3, color: Color3)
	local projectile = projectilePart(color, Vector3.one * 0.58, Enum.Material.Neon)
	projectile.Shape = Enum.PartType.Ball
	projectile.Position = from
	local duration = math.clamp((to - from).Magnitude / 75, 0.18, 0.55)
	TweenService:Create(projectile, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = to, Size = Vector3.one * 0.3 }):Play()
	task.delay(duration, function()
		if projectile.Parent then
			projectile:Destroy()
			Effects.burst(to, 1.4, color, 0.18)
		end
	end)
end

local ARROW_TYPES = { Gunner = true, MachineGun = true, Sniper = true, Rocket = true }
local SIEGE_TYPES = { Mortar = true, Bomb = true, Orbital = true }

local MUZZLE_PARTS = {
	Gunner = { "Arrow" },
	MachineGun = { "Arrow" },
	Sniper = { "Bolt" },
	Rocket = { "Bolt", "BoltHead" },
	Mortar = { "Boulder" },
	Bomb = { "Boulder" },
	Orbital = { "RunicStone" },
	Cryo = { "IceCrystal", "Staff" },
	Frost = { "CrystalCore" },
	Tesla = { "StormGem" },
	Laser = { "ArcaneShard2", "RuneFront" },
	Chain = { "Spark", "Conductor" },
}

local function muzzlePosition(model: Model?, towerType: string, fallback: Vector3): Vector3
	local choices = MUZZLE_PARTS[towerType]
	if not model or not choices then
		return fallback
	end
	for _, name in choices do
		local visual = model:FindFirstChild(name, true)
		if visual and visual:IsA("BasePart") then
			return visual.Position
		end
	end
	return fallback
end

-- Animation mécanique locale : elle est légère, immédiate et ne modifie jamais les dégâts serveur.
local function animateTower(model: Model?, towerType: string): number
	if towerType == "Sniper" or towerType == "Rocket" then
		recoil(model, { CrossbowArm = true, CrossbowString = true, BowArm = true, String = true }, CFrame.new(0, 0, 0.32), 0.1, 0.12)
		hideBriefly(model, { Bolt = true }, 0.28)
		return 0.09
	elseif towerType == "Gunner" or towerType == "MachineGun" then
		recoil(model, { BowUpper = true, BowLower = true }, CFrame.new(0, 0, 0.18) * CFrame.Angles(0, 0, math.rad(5)), 0.08, 0.14)
		hideBriefly(model, { Arrow = true }, 0.22)
		return 0.07
	elseif towerType == "Mortar" or towerType == "Bomb" then
		recoil(model, { ThrowingArm = true, Spoon = true }, CFrame.Angles(math.rad(52), 0, 0), 0.13, 0.42)
		hideBriefly(model, { Boulder = true }, 0.55)
		return 0.12
	elseif towerType == "Orbital" then
		recoil(model, { TrebuchetArm = true, Sling = true }, CFrame.Angles(math.rad(58), 0, 0), 0.16, 0.55)
		recoil(model, { Counterweight = true }, CFrame.new(0, -0.5, 0), 0.16, 0.55)
		hideBriefly(model, { RunicStone = true }, 0.7)
		return 0.15
	elseif towerType == "Cryo" or towerType == "Tesla" then
		recoil(model, { Staff = true }, CFrame.Angles(0, 0, math.rad(-10)), 0.1, 0.22)
	elseif towerType == "Laser" then
		recoil(model, { ArcaneShard1 = true, ArcaneShard2 = true, ArcaneShard3 = true }, CFrame.new(0, 0.35, 0), 0.1, 0.2)
	elseif towerType == "Chain" then
		recoil(model, { Conductor = true, Prong = true, Spark = true }, CFrame.new(0, 0.28, 0), 0.08, 0.18)
	end
	return 0
end

function Effects.playTowerShot(from: Vector3, to: Vector3, towerType: string, radius: number, color: Color3, kind: string, towerModel: Model?)
	from = muzzlePosition(towerModel, towerType, from)
	local delay = animateTower(towerModel, towerType)
	task.delay(delay, function()
		if kind == "Aura" then
			Effects.pulse(to, radius, color)
		elseif SIEGE_TYPES[towerType] then
			arcingProjectile(from, to, Color3.fromRGB(79, 76, 69):Lerp(color, 0.18), radius)
		elseif ARROW_TYPES[towerType] then
			linearProjectile(from, to, if towerType == "Rocket" then color else Color3.fromRGB(218, 171, 71), towerType == "Sniper" or towerType == "Rocket")
		elseif towerType == "Laser" or towerType == "Chain" then
			Effects.tracer(from, to, color, if towerType == "Laser" then 0.28 else 0.18)
		else
			magicProjectile(from, to, color)
		end
	end)
end

local function towerById(towerId: number?): Model?
	if not towerId then
		return nil
	end
	local towers = workspace:FindFirstChild("Towers")
	if not towers then
		return nil
	end
	for _, tower in towers:GetChildren() do
		if tower:IsA("Model") and tower:GetAttribute("TowerId") == towerId then
			return tower
		end
	end
	return nil
end

local function onTowerFired(from: Vector3, to: Vector3, towerType: string, radius: number, towerId: number?)
	local def = Towers.Defs[towerType]
	if not def then
		return
	end
	Effects.playTowerShot(from, to, towerType, radius, def.color, def.kind, towerById(towerId))
end

local function addHealthBar(enemy: Instance)
	if not enemy:IsA("BasePart") then
		return
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(40, 6)
	billboard.StudsOffset = Vector3.new(0, enemy.Size.Y / 2 + 1, 0)
	ProximityLabel.register(billboard, Config.LabelDistance.Far)
	billboard.AlwaysOnTop = true

	local background = Instance.new("Frame")
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	background.BorderSizePixel = 0
	background.Parent = billboard

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(90, 220, 90)
	fill.BorderSizePixel = 0
	fill.Parent = background

	local function update()
		local health = enemy:GetAttribute("Health") or 0
		local maxHealth = enemy:GetAttribute("MaxHealth") or 1
		fill.Size = UDim2.fromScale(math.clamp(health / maxHealth, 0, 1), 1)
	end
	update()
	enemy:GetAttributeChangedSignal("Health"):Connect(update)
	billboard.Parent = enemy
end

-- Badge au-dessus de chaque tour : 3 pastilles qui se remplissent avec le niveau
-- (dorées au niveau max). Visible sur tes tours comme sur celles de l'adversaire.
local function addTowerBadge(model: Instance)
	local towerType = model:GetAttribute("TowerType")
	local def = towerType and Towers.Defs[towerType]
	if not def or not model:IsA("Model") then
		return
	end
	local anchor = model:WaitForChild("Base", 5)
	if not anchor then
		return
	end
	local maxLevel = Towers.maxLevel(towerType)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "LevelBadge"
	billboard.Size = UDim2.fromOffset(78, 26)
	billboard.AlwaysOnTop = true
	ProximityLabel.register(billboard, Config.LabelDistance.Medium)
	billboard.Adornee = anchor

	local background = Instance.new("Frame")
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	background.BackgroundTransparency = 0.25
	background.Parent = billboard
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = background
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.Parent = background

	local pips = {}
	for index = 1, maxLevel do
		local pip = Instance.new("Frame")
		pip.Size = UDim2.fromOffset(14, 14)
		pip.LayoutOrder = index
		pip.Parent = background
		local pipCorner = Instance.new("UICorner")
		pipCorner.CornerRadius = UDim.new(1, 0)
		pipCorner.Parent = pip
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.new(1, 1, 1)
		stroke.Transparency = 0.4
		stroke.Parent = pip
		pips[index] = pip
	end

	local function update()
		local level = model:GetAttribute("Level") or 1
		local maxed = level >= maxLevel
		for index, pip in pips do
			local filled = index <= level
			pip.BackgroundColor3 = if maxed then Color3.fromRGB(255, 205, 80) elseif filled then def.color else Color3.fromRGB(45, 48, 60)
			pip.BackgroundTransparency = if filled then 0 else 0.2
		end
		-- Le badge suit la hauteur de la tour (qui grandit à chaque niveau).
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 1.5 + level * 1.2 + (if maxed then 3.2 else 2), 0)
	end
	update()
	model:GetAttributeChangedSignal("Level"):Connect(update)
	billboard.Parent = model
end

function Effects.start()
	Remotes.get("TowerFired").OnClientEvent:Connect(onTowerFired)

	local towers = workspace:WaitForChild("Towers")
	towers.ChildAdded:Connect(addTowerBadge)
	for _, model in towers:GetChildren() do
		task.spawn(addTowerBadge, model)
	end

	local enemies = workspace:WaitForChild("Enemies")
	enemies.ChildAdded:Connect(addHealthBar)
	for _, enemy in enemies:GetChildren() do
		addHealthBar(enemy)
	end
end

return Effects

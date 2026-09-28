-- Effets visuels purement côté client : tirs des tours et barres de vie des ennemis.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
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

local function onTowerFired(from: Vector3, to: Vector3, towerType: string, radius: number)
	local def = Towers.Defs[towerType]
	if not def then
		return
	end
	if def.kind == "Aura" then
		Effects.pulse(to, radius, def.color)
	elseif def.kind == "Splash" then
		Effects.tracer(from, to, def.color, 0.5)
		Effects.burst(to, radius, def.color, 0.3)
	else
		Effects.tracer(from, to, def.color, if towerType == "Sniper" then 0.35 else 0.2)
	end
end

local function addHealthBar(enemy: Instance)
	if not enemy:IsA("BasePart") then
		return
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(40, 6)
	billboard.StudsOffset = Vector3.new(0, enemy.Size.Y / 2 + 1, 0)
	billboard.MaxDistance = 150
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
	billboard.MaxDistance = 110
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

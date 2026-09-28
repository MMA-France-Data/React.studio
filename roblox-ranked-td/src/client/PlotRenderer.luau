-- Affichage du mode infini côté client : ennemis des 6 parcelles, tirs des tours, pièces à ramasser.
-- Le serveur envoie la position des ennemis quelques fois par seconde ; entre deux paquets,
-- le client les fait avancer lui-même pour que le mouvement reste fluide.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Enemies = require(Shared.Enemies)
local IdleConfig = require(Shared.IdleConfig)
local IdleTowers = require(Shared.IdleTowers)
local MedievalModels = require(Shared.MedievalModels)
local NumberFormat = require(Shared.NumberFormat)
local PlotLayout = require(Shared.PlotLayout)
local ProximityLabel = require(Shared.ProximityLabel)
local Remotes = require(Shared.Remotes)
local Effects = require(script.Parent.Effects)

local PlotRenderer = {}

local ENEMY_BYTES = 11
local SHOT_BYTES = 26
local SNAP_DISTANCE = 4 -- au-delà, on replace l'ennemi directement à la position du serveur

local folder = Instance.new("Folder")
folder.Name = "PlotEnemies"
local coinFolder = Instance.new("Folder")
coinFolder.Name = "Coins"

local plots = {} -- [plotIndex] = { cframe, enemies = { [id] = enemy } }
local coins = {} -- [id] = { part, label }

local function plotState(plotIndex: number)
	local state = plots[plotIndex]
	if not state then
		state = { cframe = PlotLayout.cframe(plotIndex), enemies = {} }
		plots[plotIndex] = state
	end
	return state
end

local function createEnemy(def)
	local part = Instance.new("Part")
	part.Size = Vector3.one * def.size
	part.Color = def.color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	MedievalModels.decorateEnemy(part, def)

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(math.max(30, def.size * 12), 5)
	billboard.StudsOffset = Vector3.new(0, def.size / 2 + 0.8, 0)
	ProximityLabel.register(billboard, Config.LabelDistance.Medium)
	billboard.AlwaysOnTop = true
	billboard.Parent = part
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

	part.Parent = folder
	return part, fill
end

local function onSync(plotIndex: number, packet: buffer, count: number)
	local state = plotState(plotIndex)
	local seen = {}
	for i = 0, count - 1 do
		local offset = i * ENEMY_BYTES
		local id = buffer.readu32(packet, offset)
		local def = Enemies.Defs[Enemies.ORDER[buffer.readu8(packet, offset + 4)]]
		local distance = buffer.readf32(packet, offset + 5)
		local health = buffer.readu8(packet, offset + 9) / 255
		local speedFactor = buffer.readu8(packet, offset + 10) / 100
		if not def then
			continue
		end
		seen[id] = true

		local enemy = state.enemies[id]
		if not enemy then
			local part, fill = createEnemy(def)
			enemy = { def = def, part = part, fill = fill, distance = distance }
			state.enemies[id] = enemy
		elseif math.abs(enemy.distance - distance) > SNAP_DISTANCE then
			enemy.distance = distance
		else
			enemy.distance += (distance - enemy.distance) * 0.5
		end
		enemy.speedFactor = speedFactor
		enemy.fill.Size = UDim2.fromScale(health, 1)
	end

	-- Absents du paquet = morts ou arrivés à la base.
	for id, enemy in state.enemies do
		if not seen[id] then
			enemy.part:Destroy()
			state.enemies[id] = nil
		end
	end
end

local function nearestTower(plotIndex: number, towerType: string, from: Vector3): Model?
	local hub = workspace:FindFirstChild("Hub")
	local plotFolder = hub and hub:FindFirstChild("Plots") and hub.Plots:FindFirstChild("Plot" .. plotIndex)
	if not plotFolder then
		return nil
	end
	local nearest, nearestDistance = nil, math.huge
	for _, candidate in plotFolder:GetDescendants() do
		if candidate:IsA("Model") and candidate:GetAttribute("TowerType") == towerType then
			local anchor = candidate.PrimaryPart or candidate:FindFirstChild("Base")
			if anchor and anchor:IsA("BasePart") then
				local distance = (anchor.Position - from).Magnitude
				if distance < nearestDistance then
					nearest = candidate
					nearestDistance = distance
				end
			end
		end
	end
	return nearest
end

local function onShots(plotIndex: number, packet: buffer, count: number)
	for i = 0, count - 1 do
		local offset = i * SHOT_BYTES
		local from = Vector3.new(buffer.readf32(packet, offset), buffer.readf32(packet, offset + 4), buffer.readf32(packet, offset + 8))
		local to = Vector3.new(buffer.readf32(packet, offset + 12), buffer.readf32(packet, offset + 16), buffer.readf32(packet, offset + 20))
		local towerType = IdleTowers.ORDER[buffer.readu8(packet, offset + 24)]
		local def = IdleTowers.Defs[towerType]
		local radius = buffer.readu8(packet, offset + 25)
		if not def then
			continue
		end
		Effects.playTowerShot(from, to, towerType, radius, def.color, def.kind, nearestTower(plotIndex, towerType, from))
	end
end

----------------------------------------------------------------------
-- Pièces (visibles seulement par le propriétaire de la parcelle)
----------------------------------------------------------------------

local function floatingText(position: Vector3, text: string)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	anchor.Position = position
	anchor.Parent = coinFolder

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(140, 34)
	billboard.AlwaysOnTop = true
	billboard.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 215, 80)
	label.TextStrokeTransparency = 0.2
	label.Text = text
	label.Parent = billboard

	TweenService:Create(anchor, TweenInfo.new(0.9), { Position = position + Vector3.new(0, 4, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(0.9), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(1, function()
		anchor:Destroy()
	end)
end

local function onCoinDrop(action: string, id: number, position: Vector3, amount: number)
	local coin = coins[id]
	if action == "Collect" then
		if coin then
			coin.part:Destroy()
			coins[id] = nil
		end
		floatingText(position, "+" .. NumberFormat.short(amount))
		return
	end

	if not coin then
		local part = Instance.new("Part")
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(0.4, 2, 2)
		part.Color = Color3.fromRGB(255, 200, 60)
		part.Material = Enum.Material.Neon
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Position = position

		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.fromOffset(90, 22)
		billboard.StudsOffset = Vector3.new(0, 1.8, 0)
		ProximityLabel.register(billboard, Config.LabelDistance.Close)
		billboard.Parent = part
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(255, 225, 120)
		label.TextStrokeTransparency = 0.3
		label.Parent = billboard

		part.Parent = coinFolder
		coin = { part = part, label = label, base = position }
		coins[id] = coin
	end
	coin.label.Text = NumberFormat.short(amount)
	-- Les grosses piles grossissent un peu.
	local size = math.clamp(1.6 + math.log10(math.max(1, amount)) * 0.15, 1.6, 3.5)
	coin.part.Size = Vector3.new(0.4, size, size)
end

----------------------------------------------------------------------

-- Étiquette « Niv. X » au-dessus de chaque tour des parcelles (mise à jour à chaque amélioration).
local function addLevelTag(model: Instance)
	if not model:IsA("Model") or not model:GetAttribute("SpotIndex") then
		return
	end
	local def = IdleTowers.Defs[model:GetAttribute("TowerType")]
	local anchor = model:WaitForChild("Base", 5)
	if not def or not anchor then
		return
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "LevelTag"
	billboard.Size = UDim2.fromOffset(70, 24)
	-- Au-dessus du sommet de la tour (les modèles n'ont pas tous la même hauteur), et devant le décor :
	-- elle ne s'affiche de toute façon que de près (ProximityLabel).
	billboard.AlwaysOnTop = true
	ProximityLabel.register(billboard, Config.LabelDistance.Close)
	billboard.Adornee = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	label.BackgroundTransparency = 0.25
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = def.color:Lerp(Color3.new(1, 1, 1), 0.4)
	label.Parent = billboard
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = label

	-- Hauteur du point le plus haut de la tour (en coordonnées du monde, pièces tournées comprises).
	local function towerTop(): number
		local top = anchor.Position.Y
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				local cf, size = part.CFrame, part.Size
				local halfHeight = (math.abs(cf.RightVector.Y) * size.X + math.abs(cf.UpVector.Y) * size.Y + math.abs(cf.LookVector.Y) * size.Z) / 2
				top = math.max(top, cf.Position.Y + halfHeight)
			end
		end
		return top
	end

	local function update()
		label.Text = `Niv. {model:GetAttribute("Level") or 1}`
		billboard.StudsOffsetWorldSpace = Vector3.new(0, towerTop() - anchor.Position.Y + 1.5, 0)
	end
	update()
	model:GetAttributeChangedSignal("Level"):Connect(update)
	-- Les pièces de la tour peuvent arriver après l'étiquette (streaming) : on recalcule sa hauteur.
	model.DescendantAdded:Connect(function()
		task.defer(update)
	end)
	billboard.Parent = model
end

function PlotRenderer.start()
	local plotsFolder = workspace:WaitForChild("Hub"):WaitForChild("Plots")
	plotsFolder.DescendantAdded:Connect(function(instance)
		if instance:IsA("Model") then
			task.defer(addLevelTag, instance)
		end
	end)
	for _, instance in plotsFolder:GetDescendants() do
		if instance:IsA("Model") then
			task.spawn(addLevelTag, instance)
		end
	end

	folder.Parent = workspace
	coinFolder.Parent = workspace

	Remotes.get("PlotSync").OnClientEvent:Connect(onSync)
	Remotes.get("PlotShots").OnClientEvent:Connect(onShots)
	Remotes.get("CoinDrop").OnClientEvent:Connect(onCoinDrop)

	RunService.RenderStepped:Connect(function(dt)
		local parts, cframes = {}, {}
		for _, state in plots do
			for _, enemy in state.enemies do
				enemy.distance = math.min(PlotLayout.PATH_LENGTH, enemy.distance + enemy.def.speed * IdleConfig.ENEMY_SPEED_MULTIPLIER * (enemy.speedFactor or 1) * dt)
				local localPosition, direction = PlotLayout.pointAt(enemy.distance)
				local position = state.cframe:PointToWorldSpace(localPosition) + Vector3.new(0, enemy.def.size / 2, 0)
				local worldDirection = state.cframe:VectorToWorldSpace(direction)
				table.insert(parts, enemy.part)
				table.insert(cframes, CFrame.lookAt(position, position + worldDirection))
			end
		end
		if #parts > 0 then
			workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
		end

		-- Pièces qui tournent et flottent.
		local t = os.clock()
		for id, coin in coins do
			local bob = math.sin(t * 3 + id) * 0.3
			coin.part.CFrame = CFrame.new(coin.base + Vector3.new(0, bob, 0)) * CFrame.Angles(0, t * 2 + id, 0)
		end
	end)
end

return PlotRenderer

-- Affichage du mode infini côté client : ennemis des 6 parcelles, tirs des tours, pièces à ramasser.
-- Le serveur envoie la position des ennemis quelques fois par seconde ; entre deux paquets,
-- le client les fait avancer lui-même pour que le mouvement reste fluide.
-- Vitesse x2 (pass de jeu) : le serveur publie l'attribut « SimSpeed » (1 ou 2) sur le dossier de la
-- parcelle et toute sa simulation va SimSpeed fois plus vite. Le facteur de vitesse du paquet ne
-- contient PAS ce x2 : c'est ici qu'on le multiplie (voir simSpeedOf).
local Players = game:GetService("Players")
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
local SNAP_DISTANCE = 4 -- au-delà, on replace l'ennemi directement à la position du serveur (x SimSpeed)
local MAX_SIM_SPEED = 4 -- garde-fou : une valeur abîmée ne fait pas s'envoler les ennemis
-- Pièces ramassées à distance (pass Ramassage auto) : plus loin que ça du joueur, la pile s'envole vers lui.
local REMOTE_PICKUP_DISTANCE = IdleConfig.PICKUP_RADIUS + 4
local REMOTE_GAIN_DELAY = 0.6 -- les gains des piles arrivées ensemble s'affichent en un seul « +X »

local folder = Instance.new("Folder")
folder.Name = "PlotEnemies"
local coinFolder = Instance.new("Folder")
coinFolder.Name = "Coins"

local plotsFolder: Instance? = nil -- workspace.Hub.Plots (trouvé dans start)
local plots = {} -- [plotIndex] = { cframe, folder, enemies = { [id] = enemy } }
local coins = {} -- [id] = { part, label }
local flyingCoins = {} -- piles ramassées à distance, en vol vers le joueur : { part, from, size, started, duration }
local remoteGain = 0
local remoteGainPending = false

local function plotState(plotIndex: number)
	local state = plots[plotIndex]
	if not state then
		state = { cframe = PlotLayout.cframe(plotIndex), enemies = {} }
		plots[plotIndex] = state
	end
	return state
end

-- Vitesse de la simulation de cette parcelle : 1 (normal) ou 2 (pass Vitesse x2 activé), lue sur
-- l'attribut « SimSpeed » du dossier de la parcelle (publié par le serveur, PlotGame).
local function simSpeedOf(plotIndex: number, state): number
	local plotFolder = state.folder
	if not plotFolder or not plotFolder.Parent then
		plotFolder = plotsFolder and plotsFolder:FindFirstChild("Plot" .. plotIndex)
		state.folder = plotFolder
	end
	local speed = plotFolder and plotFolder:GetAttribute("SimSpeed")
	if typeof(speed) ~= "number" or speed ~= speed then
		return 1
	end
	return math.clamp(speed, 1, MAX_SIM_SPEED)
end

local function characterRoot(): BasePart?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
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
	-- En x2, les ennemis font 2 fois plus de chemin entre deux paquets : même tolérance en temps.
	local snapDistance = SNAP_DISTANCE * simSpeedOf(plotIndex, state)
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
		elseif math.abs(enemy.distance - distance) > snapDistance then
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

-- Gains des piles ramassées à distance : additionnés, puis un seul « +X » au-dessus du joueur quand
-- les pièces arrivent (sinon, en x2 avec beaucoup d'ennemis, l'écran serait couvert de « +X »).
local function addRemoteGain(amount: number)
	remoteGain += amount
	if remoteGainPending then
		return
	end
	remoteGainPending = true
	task.delay(REMOTE_GAIN_DELAY, function()
		remoteGainPending = false
		local total = remoteGain
		remoteGain = 0
		local root = characterRoot()
		if root and total > 0 then
			floatingText(root.Position + Vector3.new(0, 3.5, 0), "+" .. NumberFormat.short(total))
		end
	end)
end

local function onCoinDrop(action: string, id: number, position: Vector3, amount: number)
	local coin = coins[id]
	if action == "Collect" then
		local root = characterRoot()
		local offset = if root then position - root.Position else Vector3.zero
		if not root or Vector3.new(offset.X, 0, offset.Z).Magnitude <= REMOTE_PICKUP_DISTANCE then
			-- Ramassée en marchant dessus : « +X » sur place.
			if coin then
				coin.part:Destroy()
				coins[id] = nil
			end
			floatingText(position, "+" .. NumberFormat.short(amount))
			return
		end
		-- Ramassée à distance (pass Ramassage auto) : la pile s'envole vers le joueur et rétrécit.
		if coin then
			coins[id] = nil
			local billboard = coin.part:FindFirstChildOfClass("BillboardGui")
			if billboard then
				billboard:Destroy() -- son montant ne vole pas avec elle
			end
			table.insert(flyingCoins, {
				part = coin.part,
				from = coin.part.Position,
				size = coin.part.Size,
				started = os.clock(),
				duration = math.clamp(offset.Magnitude / 90, 0.35, 0.8),
			})
		end
		addRemoteGain(amount)
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

-- Étiquette « Niv. X » au pied de chaque tour des parcelles (mise à jour à chaque amélioration).
local function addLevelTag(model: Instance)
	if not model:IsA("Model") or not model:GetAttribute("SpotIndex") then
		return
	end
	local def = IdleTowers.Defs[model:GetAttribute("TowerType")]
	local anchor = model:WaitForChild("Base", 5)
	if not def or not anchor or not anchor:IsA("BasePart") or model:FindFirstChild("LevelTag") then
		return
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "LevelTag"
	billboard.Size = UDim2.fromOffset(64, 22)
	-- Sous la tour, collée à son pied (le socle « Base », au centre de l'emplacement).
	-- Pas de StudsOffsetWorldSpace : il suit l'orientation de la pièce, et « Base » est un cylindre
	-- redressé (tourné de 90°) qui pivote en plus quand la tour vise. L'ancien décalage « vers le haut »
	-- partait donc sur le côté : les étiquettes flottaient à 10-20 studs à droite des tours.
	-- StudsOffset suit la caméra : toujours un peu plus bas à l'écran, sans aucun décalage horizontal.
	billboard.StudsOffset = Vector3.new(0, -1.2, 0)
	billboard.AlwaysOnTop = true -- par-dessus le modèle ; ne s'affiche que de près (ProximityLabel)
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

	local function update()
		label.Text = `Niv. {model:GetAttribute("Level") or 1}`
	end
	update()
	model:GetAttributeChangedSignal("Level"):Connect(update)
	billboard.Parent = model
end

function PlotRenderer.start()
	local plotsRoot = workspace:WaitForChild("Hub"):WaitForChild("Plots")
	plotsFolder = plotsRoot
	plotsRoot.DescendantAdded:Connect(function(instance)
		if instance:IsA("Model") then
			task.defer(addLevelTag, instance)
		end
	end)
	for _, instance in plotsRoot:GetDescendants() do
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
		for plotIndex, state in plots do
			-- Même vitesse que la simulation du serveur : x2 si le pass Vitesse x2 est activé sur cette parcelle.
			local simDt = dt * simSpeedOf(plotIndex, state)
			for _, enemy in state.enemies do
				enemy.distance = math.min(PlotLayout.PATH_LENGTH, enemy.distance + enemy.def.speed * IdleConfig.ENEMY_SPEED_MULTIPLIER * (enemy.speedFactor or 1) * simDt)
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

		-- Piles ramassées à distance : elles volent en arc vers le joueur (qui peut bouger), de plus en
		-- plus vite, en rétrécissant, puis disparaissent.
		if #flyingCoins > 0 then
			local root = characterRoot()
			for i = #flyingCoins, 1, -1 do
				local flying = flyingCoins[i]
				local alpha = (t - flying.started) / flying.duration
				if alpha >= 1 or not root then
					flying.part:Destroy()
					table.remove(flyingCoins, i)
					continue
				end
				local target = root.Position + Vector3.new(0, 1.5, 0)
				local arc = Vector3.new(0, math.sin(alpha * math.pi) * 5, 0)
				flying.part.Size = flying.size * (1 - 0.6 * alpha)
				flying.part.CFrame = CFrame.new(flying.from:Lerp(target, alpha * alpha) + arc) * CFrame.Angles(0, t * 12, 0)
			end
		end
	end)
end

return PlotRenderer

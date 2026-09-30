-- Habillage client uniquement. Aucun dégât, rayon de jeu ou chronomètre serveur ici.
-- Textures natives Roblox : aucun asset payant ni publication de texture nécessaire.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local VFX = {}
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local WARM = Color3.fromRGB(255, 151, 46)
local WHITE = Color3.fromRGB(255, 243, 210)
local PURPLE = Color3.fromRGB(196, 130, 255)
local MAX_TRANSIENT = 96
local FIRE_LIMIT = 16
local STATUS_LIMIT = 48
local DRAW_DISTANCE = 150
local STATUS_DISTANCE = 110
local REFRESH_TIME = 0.25
local transient = 0
local persistent = {}

local function sequence(a: number, b: number, c: number?): NumberSequence
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, a),
		NumberSequenceKeypoint.new(0.4, b), NumberSequenceKeypoint.new(1, c or 0) })
end

local function part(parent: Instance, name: string, size: Vector3, frame: CFrame, color: Color3, transparency: number): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = frame
	p.Color = color
	p.Transparency = transparency
	p.Material = Enum.Material.Neon
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

local function attachment(parent: BasePart, name: string, position: Vector3): Attachment
	local a = Instance.new("Attachment")
	a.Name = name
	a.Position = position
	a.Parent = parent
	return a
end

local function emitter(parent: Instance, name: string, texture: string, color: Color3, rate: number, life: number): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Texture = texture
	e.Color = ColorSequence.new(color)
	e.Lifetime = NumberRange.new(life * 0.7, life)
	e.Rate = rate
	e.Speed = NumberRange.new(1, 2)
	e.Size = sequence(0.3, 0.6, 0)
	e.Transparency = sequence(0.15, 0.35, 1)
	e.Rotation = NumberRange.new(-180, 180)
	e.RotSpeed = NumberRange.new(-35, 35)
	e.LightEmission = 0.7
	e.LightInfluence = 0.2
	e.EmissionDirection = Enum.NormalId.Top
	e.SpreadAngle = Vector2.new(30, 30)
	e.Enabled = false
	e.Parent = parent
	return e
end

local function distance(position: Vector3): number
	local camera = workspace.CurrentCamera
	return if camera then (camera.CFrame.Position - position).Magnitude else math.huge
end

function VFX.isNear(position: Vector3): boolean
	return distance(position) <= DRAW_DISTANCE
end

local function claim(root: BasePart): boolean
	if transient >= MAX_TRANSIENT then return false end
	transient += 1
	root.Destroying:Once(function() transient -= 1 end)
	return true
end

-- Tours des parcelles (workspace.Hub.Plots.PlotN.Towers) : le sol est SOUS elles. Sans ça, l'onde du Totem
-- de givre se posait sur le haut de la tour, en l'air (retour du propriétaire). Liste refaite toutes les 2 s.
local towerFolders: { Instance } = {}
local towerFoldersAt = -math.huge
local function plotTowerFolders(): { Instance }
	if os.clock() - towerFoldersAt < 2 then return towerFolders end
	towerFoldersAt = os.clock()
	table.clear(towerFolders)
	local hub = workspace:FindFirstChild("Hub")
	local plots = hub and hub:FindFirstChild("Plots")
	for _, plot in (if plots then plots:GetChildren() else {}) do
		local towers = plot:FindFirstChild("Towers")
		if towers then table.insert(towerFolders, towers) end
	end
	return towerFolders
end

local function ground(position: Vector3, effects: Instance): Vector3
	local exclusions = { effects }
	for _, name in { "PlotEnemies", "Enemies", "Coins", "Towers" } do
		local folder = workspace:FindFirstChild(name)
		if folder then table.insert(exclusions, folder) end
	end
	for _, folder in plotTowerFolders() do
		table.insert(exclusions, folder)
	end
	local character = Players.LocalPlayer and Players.LocalPlayer.Character
	if character then table.insert(exclusions, character) end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclusions
	params.IgnoreWater = true
	local hit = workspace:Raycast(position + Vector3.new(0, 6, 0), Vector3.new(0, -64, 0), params)
	return Vector3.new(position.X, if hit then hit.Position.Y + 0.09 else position.Y + 0.09, position.Z)
end

local function register(root: BasePart, kind: string, emitters)
	local entry = { root = root, kind = kind, emitters = emitters, active = true, fragile = false, source = nil }
	persistent[root] = entry
	root.Destroying:Once(function() persistent[root] = nil end)
	return entry
end

-- Un seul contrôle de distance/budget, quatre fois par seconde pour tous les effets persistants.
-- Les particules s'animent dans le moteur, pas dans une coroutine par ennemi.
local accumulated = 0
RunService.Heartbeat:Connect(function(dt)
	accumulated += dt
	if accumulated < REFRESH_TIME then return end
	accumulated = 0
	local candidates = {}
	for root, entry in persistent do
		if not root.Parent then
			persistent[root] = nil
		else
			local d = distance(root.Position)
			table.insert(candidates, { entry = entry, distance = d })
		end
	end
	table.sort(candidates, function(a, b) return a.distance < b.distance end)
	local fires, statuses = 0, 0
	for _, candidate in candidates do
		local entry = candidate.entry
		local allowed = false
		if entry.kind == "fire" then
			allowed = entry.active and candidate.distance <= DRAW_DISTANCE and fires < FIRE_LIMIT
			if allowed then fires += 1 end
		else
			allowed = entry.active and candidate.distance <= STATUS_DISTANCE and statuses < STATUS_LIMIT
			if allowed then statuses += 1 end
		end
		for _, setting in entry.emitters do
			local show = allowed and (setting.mode == nil or setting.mode == entry.source
				or (setting.mode == "Fragile" and entry.fragile))
			setting.emitter.Enabled = show
			setting.emitter.Rate = setting.rate * (if candidate.distance > 75 then 0.5 else 1)
		end
	end
end)

local function settings(e: ParticleEmitter, mode: string?)
	return { emitter = e, rate = e.Rate, mode = mode }
end

local function weldVisual(root: BasePart, name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material): Part
	local child = part(root, name, size, root.CFrame * offset, color, 0)
	child.Material = material
	child.Anchored = false
	child.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = child
	weld.Parent = child
	return child
end

local function trail(root: BasePart, color: Color3, width: number, life: number): Trail
	local a = attachment(root, "TrailLeft", Vector3.new(-width / 2, 0, 0))
	local b = attachment(root, "TrailRight", Vector3.new(width / 2, 0, 0))
	local ribbon = Instance.new("Trail")
	ribbon.Name = "ProjectileTrail"
	ribbon.Attachment0 = a
	ribbon.Attachment1 = b
	ribbon.FaceCamera = true
	ribbon.Color = ColorSequence.new(color, color:Lerp(WHITE, 0.3))
	ribbon.Transparency = sequence(0.12, 0.6, 1)
	ribbon.WidthScale = sequence(1, 0.6, 0)
	ribbon.Lifetime = life
	ribbon.MinLength = 0.05
	ribbon.LightEmission = 1
	ribbon.Parent = root
	return ribbon
end

function VFX.decorateArrow(root: BasePart, heavy: boolean, flaming: boolean)
	if not claim(root) then return end -- conserve la flèche simple quand le budget est atteint
	local length = root.Size.Z
	root.Material = Enum.Material.Wood
	root.Color = Color3.fromRGB(114, 76, 43)
	weldVisual(root, "ArrowTip", Vector3.new(root.Size.X * 2, root.Size.Y * 2, length * 0.22),
		CFrame.new(0, 0, -length * 0.45), Color3.fromRGB(179, 183, 186), Enum.Material.Metal)
	for i = 0, 1 do
		weldVisual(root, "Fletching", Vector3.new(0.055, if heavy then 0.5 else 0.32, length * 0.2),
			CFrame.new(0, 0, length * 0.35) * CFrame.Angles(0, 0, i * math.pi / 2),
			Color3.fromRGB(225, 209, 170), Enum.Material.SmoothPlastic)
	end
	trail(root, if flaming then WARM else Color3.fromRGB(213, 190, 135), if flaming then 0.36 else 0.1, if flaming then 0.2 else 0.09)
	if flaming then
		local tip = attachment(root, "BurningArrowTip", Vector3.new(0, 0, -length * 0.5))
		local flame = emitter(tip, "ArrowFlame", FIRE, WARM, 22, 0.25)
		flame.Color = ColorSequence.new(WHITE, Color3.fromRGB(255, 71, 16))
		flame.Size = sequence(0.4, 0.8, 0)
		flame.Transparency = sequence(0, 0.1, 1) -- (bien visible, comme les flammes au sol)
		flame.Speed = NumberRange.new(0.2, 0.8)
		flame.Enabled = true
		local sparks = emitter(tip, "ArrowEmbers", SPARK, WARM, 6, 0.28)
		sparks.Size = sequence(0.08, 0.07, 0)
		sparks.Speed = NumberRange.new(0.6, 1.8)
		sparks.Enabled = true
	end
end

function VFX.decorateStone(root: BasePart, color: Color3)
	if not claim(root) then return end
	trail(root, color:Lerp(Color3.fromRGB(177, 165, 143), 0.75), root.Size.X * 0.7, 0.16)
end

function VFX.decorateMagic(root: BasePart, color: Color3)
	if not claim(root) then return end
	trail(root, color, 0.35, 0.18)
end

function VFX.burst(parent: Instance, position: Vector3, radius: number, color: Color3, duration: number)
	if not VFX.isNear(position) or transient >= MAX_TRANSIENT then return end
	local root = part(parent, "ImpactParticles", Vector3.one * 0.15, CFrame.new(position), color, 1)
	claim(root)
	local a = attachment(root, "Impact", Vector3.zero)
	local sparks = emitter(a, "ImpactSparks", SPARK, color:Lerp(WHITE, 0.4), 0, math.clamp(duration + 0.2, 0.3, 0.65))
	sparks.Speed = NumberRange.new(3, math.clamp(radius * 2, 4, 12))
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Acceleration = Vector3.new(0, -12, 0)
	sparks.Size = sequence(0.1, 0.18, 0)
	sparks:Emit(10)
	local dust = emitter(a, "ImpactHaze", SMOKE, color:Lerp(Color3.fromRGB(93, 86, 78), 0.65), 0, 0.6)
	dust.Size = sequence(0.5, math.clamp(radius * 0.5, 0.8, 2.5), 3)
	dust.Transparency = sequence(0.7, 0.8, 1)
	dust.LightEmission = 0.05
	dust.Speed = NumberRange.new(1, 3)
	dust.SpreadAngle = Vector2.new(90, 90)
	dust:Emit(5)
	Debris:AddItem(root, 0.8)
end

-- Onde CREUSE, fugace : pas le disque plein qui masquait les pieds des ennemis.
function VFX.pulse(parent: Instance, position: Vector3, radius: number, color: Color3)
	if not VFX.isNear(position) or transient >= MAX_TRANSIENT then return end
	radius = math.max(0.5, radius)
	local origin = ground(position, parent)
	local root = part(parent, "GroundShockwave", Vector3.one * 0.1, CFrame.new(origin), color, 1)
	claim(root)
	-- Plus d'anneau de traits lumineux qui s'écartent : sur une grande zone (givre, Trébuchet), il dessinait un
	-- énorme polygone (« losange ») que le propriétaire n'aime pas. Seulement une brume au sol.
	local mist = emitter(root, "AuraMist", SMOKE, color, 0, 0.42)
	mist.Size = sequence(0.3, 0.8, 1.1)
	mist.Transparency = sequence(0.7, 0.85, 1)
	mist.Speed = NumberRange.new(1, 3)
	mist.SpreadAngle = Vector2.new(85, 85)
	mist:Emit(8)
	Debris:AddItem(root, 0.6)
end

-- Cercle bleu simple qui s'agrandit et s'efface au sol : l'onde d'origine du Totem de givre, remise à la demande du
-- propriétaire (30/09/2026 : « remets l'ancienne animation sur la tour de glace, le cercle bleu basique »), mais posée
-- au sol (ground) et non plus sur le haut du Totem.
function VFX.circle(parent: Instance, position: Vector3, radius: number, color: Color3)
	if not VFX.isNear(position) or transient >= MAX_TRANSIENT then return end
	radius = math.max(0.5, radius)
	local origin = ground(position, parent)
	local ring = part(parent, "FrostCircle", Vector3.new(0.2, 1, 1),
		CFrame.new(origin + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)), color, 0.4)
	ring.Shape = Enum.PartType.Cylinder
	claim(ring)
	TweenService:Create(ring, TweenInfo.new(0.35), { Size = Vector3.new(0.2, radius * 2, radius * 2), Transparency = 1 }):Play()
	Debris:AddItem(ring, 0.4)
end

function VFX.stoneImpact(parent: Instance, position: Vector3, radius: number, color: Color3)
	VFX.burst(parent, position, radius, color, 0.35)
	if not VFX.isNear(position) or transient >= MAX_TRANSIENT then return end
	local origin = ground(position, parent)
	local root = part(parent, "SiegeDebris", Vector3.one * 0.1, CFrame.new(origin), color, 1)
	claim(root)
	-- Débris animés et ancrés : aucune simulation physique supplémentaire ni collision.
	for i = 1, 4 do
		local angle = i * math.pi / 2 + 0.35
		local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local span = math.clamp(radius * 0.45, 0.6, 2.5)
		local piece = part(root, "StoneChip", Vector3.one * (0.18 + i * 0.055),
			CFrame.new(origin + Vector3.new(0, 0.2, 0)), color, 0.15)
		piece.Material = Enum.Material.Slate
		local rise = TweenService:Create(piece, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = CFrame.new(origin + outward * span * 0.5 + Vector3.new(0, 0.65, 0)) * CFrame.Angles(angle, 0, angle),
		})
		rise.Completed:Once(function()
			if not piece.Parent then return end
			TweenService:Create(piece, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				CFrame = CFrame.new(origin + outward * span + Vector3.new(0, 0.12, 0)) * CFrame.Angles(angle * 2, angle, 0),
				Transparency = 1,
			}):Play()
		end)
		rise:Play()
	end
	Debris:AddItem(root, 0.5)
end

function VFX.firePatch(parent: Instance, position: Vector3, radius: number): BasePart
	radius = math.max(0.2, radius)
	local root = part(parent, "BurningGround", Vector3.new(radius * 2, 0.1, radius * 2), CFrame.new(ground(position, parent)), WARM, 1)
	local list = {}
	-- Cinq foyers irréguliers, assez hauts, serrés et peu transparents pour bien se voir de la caméra habituelle
	-- (retour du propriétaire : « je veux vraiment que les flammes, mais plus visibles, moins transparentes » ;
	-- pas de disque au sol).
	for i = 0, 4 do
		local angle = i * 2.4
		local offset = if i == 0 then Vector3.zero else Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius * 0.6
		local a = attachment(root, "FlameBed" .. i, offset)
		local flame = emitter(a, "GroundFlames", FIRE, WARM, if i == 0 then 16 else 11, 0.75)
		flame.Color = ColorSequence.new(WHITE, Color3.fromRGB(243, 63, 12))
		flame.Size = sequence(0.6, math.clamp(radius * 1.0, 1.3, 2.5), 0.3)
		flame.Transparency = sequence(0, 0.1, 1)
		flame.Speed = NumberRange.new(2, 4)
		flame.Acceleration = Vector3.new(0, 3, 0)
		flame.LightEmission = 1
		table.insert(list, settings(flame, nil))
	end
	local sparks = emitter(root, "GroundEmbers", SPARK, WARM, 5, 0.65)
	sparks.Size = sequence(0.08, 0.06, 0)
	sparks.Speed = NumberRange.new(2, 4)
	sparks.Acceleration = Vector3.new(0, 1.5, 0)
	table.insert(list, settings(sparks, nil))
	local smoke = emitter(root, "HeatSmoke", SMOKE, Color3.fromRGB(83, 75, 68), 3, 0.8)
	smoke.Size = sequence(0.4, 1.1, 1.7)
	smoke.Transparency = sequence(0.82, 0.88, 1)
	smoke.LightEmission = 0
	smoke.Speed = NumberRange.new(1, 2)
	table.insert(list, settings(smoke, nil))
	register(root, "fire", list)
	return root
end

function VFX.fadeOut(root: BasePart, duration: number)
	if not root.Parent then return end
	local entry = persistent[root]
	if entry then entry.active = false end
	local tail = 0
	for _, child in root:GetDescendants() do
		if child:IsA("ParticleEmitter") then
			child.Enabled = false
			tail = math.max(tail, child.Lifetime.Max)
		elseif child:IsA("Trail") then
			child.Enabled = false
			tail = math.max(tail, child.Lifetime)
		elseif child:IsA("BasePart") then
			TweenService:Create(child, TweenInfo.new(duration), { Transparency = 1 }):Play()
		end
	end
	TweenService:Create(root, TweenInfo.new(duration), { Transparency = 1 }):Play()
	Debris:AddItem(root, math.max(duration, tail) + 0.05)
end

function VFX.statusAnchor(enemy: BasePart, size: number, top: number?): BasePart
	local anchor = part(enemy, "StatusRing", Vector3.new(size * 0.8 + 0.6, 0.1, size * 0.8 + 0.6),
		enemy.CFrame * CFrame.new(0, -size / 2 + 0.18, 0), PURPLE, 1)
	anchor.Anchored = false
	anchor.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = enemy
	weld.Part1 = anchor
	weld.Parent = anchor
	local foot = attachment(anchor, "Ankles", Vector3.new(0, 0.25, 0))
	local head = attachment(anchor, "AboveHead", Vector3.new(0, (top or size / 2) + size / 2 + 0.7, 0))
	local body = attachment(anchor, "FragileAura", Vector3.new(0, size * 0.65, 0))
	local frost = emitter(anchor, "FrostMist", SMOKE, Color3.fromRGB(169, 222, 255), 5, 0.6)
	frost.Size = sequence(0.2, math.clamp(size * 0.38, 0.5, 1.4), 0.7)
	frost.Transparency = sequence(0.65, 0.8, 1)
	frost.Speed = NumberRange.new(0.25, 0.6)
	frost.LockedToPart = true
	local ice = emitter(foot, "IceFlecks", SPARK, Color3.fromRGB(157, 228, 255), 3, 0.55)
	ice.Size = sequence(0.09, 0.15, 0)
	ice.SpreadAngle = Vector2.new(70, 70)
	ice.LockedToPart = true
	local static = emitter(body, "StormStatic", SPARK, Color3.fromRGB(247, 231, 125), 5, 0.22)
	static.Size = sequence(0.14, 0.27, 0)
	static.SpreadAngle = Vector2.new(180, 180)
	static.Speed = NumberRange.new(1.5, 3)
	static.LockedToPart = true
	local stars = emitter(head, "StunStars", SPARK, Color3.fromRGB(255, 212, 90), 4, 0.7)
	stars.Size = sequence(0.16, 0.28, 0.05)
	stars.SpreadAngle = Vector2.new(85, 85)
	stars.Speed = NumberRange.new(0.3, 1)
	stars.RotSpeed = NumberRange.new(60, 100)
	stars.LockedToPart = true
	local fragile = emitter(body, "FragilityMotes", SPARK, PURPLE, 3, 0.6)
	fragile.Size = sequence(0.12, 0.19, 0)
	fragile.Speed = NumberRange.new(0.3, 0.8)
	fragile.LockedToPart = true
	local entry = register(anchor, "status", { settings(frost, "Frost"), settings(ice, "Frost"),
		settings(static, "Tesla"), settings(stars, "Orbital"), settings(fragile, "Fragile") })
	entry.active = false
	return anchor
end

function VFX.setStatus(anchor: BasePart, source: string?, fragile: boolean)
	local entry = persistent[anchor]
	if not entry then return end
	entry.source = source
	entry.fragile = fragile
	entry.active = source ~= nil or fragile
	-- Coupe immédiatement le contrôle terminé, sans attendre le prochain contrôle de budget.
	for _, setting in entry.emitters do
		if setting.mode ~= source and not (setting.mode == "Fragile" and fragile) then
			setting.emitter.Enabled = false
			setting.emitter:Clear()
		end
	end
end

function VFX.createBeam(parent: Instance, color: Color3)
	local origin = part(parent, "ArcaneOrigin", Vector3.one * 0.1, CFrame.new(), color, 1)
	local target = part(origin, "ArcaneTarget", Vector3.one * 0.1, CFrame.new(), color, 1)
	local a = attachment(origin, "RayStart", Vector3.zero)
	local b = attachment(target, "RayEnd", Vector3.zero)
	local layers = {}
	for i = 1, 2 do
		local beam = Instance.new("Beam")
		beam.Name = if i == 1 then "ArcaneCore" else "ArcaneHalo"
		beam.Attachment0 = a
		beam.Attachment1 = b
		beam.FaceCamera = true
		beam.Segments = 1
		beam.LightEmission = 1
		beam.Color = ColorSequence.new(color)
		beam.Transparency = NumberSequence.new(if i == 1 then 0.1 else 0.75)
		beam.Enabled = false
		beam.Parent = origin
		table.insert(layers, beam)
	end
	local sparks = emitter(b, "ArcaneContact", SPARK, color, 10, 0.25)
	sparks.Size = sequence(0.1, 0.2, 0)
	sparks.SpreadAngle = Vector2.new(180, 180)
	return { root = origin, target = target, layers = layers, sparks = sparks, color = color, heatStep = -1 }
end

function VFX.hideBeam(handle)
	for _, beam in handle.layers do beam.Enabled = false end
	handle.sparks.Enabled = false
end

function VFX.updateBeam(handle, from: Vector3, to: Vector3, heat: number, t: number)
	if (to - from).Magnitude < 0.1 or not VFX.isNear(to) then VFX.hideBeam(handle); return end
	heat = math.clamp(heat, 0, 1)
	handle.root.Position = from
	handle.target.Position = to
	local flicker = math.sin(t * 27) * 0.025
	local width = 0.08 + heat * 0.3 + flicker * heat
	-- Les couleurs changent par petits paliers, pas de nouvelles séquences à chaque frame.
	local heatStep = math.floor(heat * 20)
	if heatStep ~= handle.heatStep then
		handle.heatStep = heatStep
		handle.layers[1].Color = ColorSequence.new(handle.color:Lerp(WHITE, 0.35 + heat * 0.5))
		handle.sparks.Color = ColorSequence.new(handle.color:Lerp(WHITE, heat * 0.7))
	end
	for i, beam in handle.layers do
		beam.Width0 = width * (if i == 1 then 1 else 3)
		beam.Width1 = beam.Width0 * 0.85
		beam.Enabled = true
	end
	handle.sparks.Enabled = true
end

function VFX.destroyBeam(handle)
	handle.root:Destroy()
end

return VFX

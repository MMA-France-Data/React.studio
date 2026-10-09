-- LA GRIFFE DU TIGRE (épée 11, celle du boss de la jungle) : ses effets à elle, demandés par le créateur le 09/10
-- (« refais-moi les animations de l'épée du tigre, et pas que la lumière, fais le tout pour la rendre épique »).
--   au repos : les yeux verts du crâne brillent et fument, des braises montent des trois griffes, des feuilles tombent ;
--   pendant un coup : TROIS traînées de griffes qui restent dans l'air (une par griffe, au lieu d'une seule), les
--     griffes s'embrasent, un éclat et une gerbe d'étincelles au départ du coup, les yeux flamboient.
-- Tout est posé sur la poignée invisible de l'épée (sa PrimaryPart), en mesures du modèle rangé (5,2 de long) ;
-- `k` les met à la taille réelle. Rien ne touche au maillage, aux dégâts ni à la prise en main.
local Input = game:GetService("UserInputService")

local Tiger = {}
local MOBILE = Input.TouchEnabled

local ORANGE, AMBER, GREEN = Color3.fromRGB(255, 120, 20), Color3.fromRGB(255, 205, 70), Color3.fromRGB(70, 255, 120)
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local EMBER = "rbxasset://textures/particles/fire_sparks_main.dds"
local FLAME = "rbxasset://textures/particles/fire_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

-- Les trois griffes, de la pointe de l'épée vers la garde : { le pied de la griffe, sa pointe } (x = épaisseur, les
-- deux faces de l'épée ; y = largeur de la lame ; z = le long de la lame, négatif vers la pointe). Mesuré sur le rendu du modèle, puis vérifié
-- en photo dans le jeu.
local CLAWS = {
	{ Vector3.new(0, -0.20, -3.30), Vector3.new(0, 0.44, -4.19) },
	{ Vector3.new(0, -0.12, -2.60), Vector3.new(0, 0.46, -3.50) },
	{ Vector3.new(0, -0.05, -1.92), Vector3.new(0, 0.50, -2.80) },
}
-- Les deux yeux du crâne de la garde, des deux côtés de l'épée (le crâne est sculpté sur ses deux faces).
local EYES = { Vector3.new(0.56, 0.15, -1.06), Vector3.new(0.56, -0.15, -1.06), Vector3.new(-0.56, 0.15, -1.06), Vector3.new(-0.56, -0.15, -1.06) }
local TIP_Z = -4.212 -- où se trouve TrailTip dans ces mesures : sert à trouver l'échelle réelle

local function curve(values): NumberSequence
	local keys = {}
	for _, value in values do
		table.insert(keys, NumberSequenceKeypoint.new(value[1], value[2]))
	end
	return NumberSequence.new(keys)
end

function Tiger.create(model: Model, tip: Attachment)
	local primary = model.PrimaryPart
	if not primary then
		return nil
	end
	local k = math.abs(tip.Position.Z / TIP_Z)
	local state = { model = model, primary = primary, k = k, trails = {}, glows = {}, embers = {}, eyes = {}, owned = {}, time = 0, heat = 0, swinging = false }
	local function point(name: string, position: Vector3): Attachment
		local item = Instance.new("Attachment")
		item.Name, item.Position, item.Parent = name, position * k, primary
		table.insert(state.owned, item)
		return item
	end

	for index, claw in CLAWS do
		local base, top = point("TigerClawBase" .. index, claw[1]), point("TigerClawTip" .. index, claw[2])
		-- 1) LA TRAÎNÉE de cette griffe : large au départ, elle s'effile et reste un tiers de seconde.
		local back = point("TigerClawBack" .. index, claw[2]:Lerp(claw[1], 0.55))
		local trail = Instance.new("Trail")
		trail.Name = "TigerSlash" .. index
		trail.Attachment0, trail.Attachment1 = top, back
		trail.Lifetime, trail.MinLength = 0.34, 0.03
		trail.FaceCamera = true
		trail.LightEmission, trail.LightInfluence, trail.Brightness = 0.7, 0, 4
		trail.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(1, 1, 0.85)), ColorSequenceKeypoint.new(0.15, AMBER), ColorSequenceKeypoint.new(0.6, ORANGE), ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 40, 10)) })
		trail.Transparency = curve({ { 0, 0.0 }, { 0.5, 0.25 }, { 1, 1 } })
		trail.WidthScale = curve({ { 0, 1 }, { 0.6, 0.55 }, { 1, 0.05 } })
		trail.Enabled = false
		trail.Parent = primary
		table.insert(state.trails, trail)
		-- 2) LA GRIFFE QUI S'EMBRASE : un ruban de lumière courbe, du pied à la pointe, plus fort pendant le coup.
		local glow = Instance.new("Beam")
		glow.Name = "TigerClawGlow" .. index
		glow.Attachment0, glow.Attachment1 = base, top
		glow.CurveSize0, glow.CurveSize1 = -0.35 * k, -0.2 * k
		glow.Width0, glow.Width1 = 1.1 * k, 0.35 * k
		glow.Segments, glow.FaceCamera = 10, true
		glow.Texture, glow.TextureMode, glow.TextureSpeed = FLAME, Enum.TextureMode.Stretch, 0.6
		glow.LightEmission, glow.LightInfluence, glow.Brightness = 0.6, 0, 3
		glow.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, ORANGE), ColorSequenceKeypoint.new(1, AMBER) })
		glow.Transparency = NumberSequence.new(1)
		glow.Parent = primary
		table.insert(state.glows, glow)
		-- 3) LES BRAISES qui montent de la griffe.
		local ember = Instance.new("ParticleEmitter")
		ember.Name = "TigerEmber" .. index
		ember.Texture = EMBER
		ember.Color = ColorSequence.new(AMBER, ORANGE)
		ember.LightEmission, ember.LightInfluence, ember.Brightness = 0.7, 0, 4
		ember.Rate = if MOBILE then 5 else 10
		ember.Lifetime, ember.Speed = NumberRange.new(0.5, 0.9), NumberRange.new(0.6, 1.4)
		ember.SpreadAngle = Vector2.new(35, 35)
		ember.Acceleration = Vector3.new(0, 2.2, 0)
		ember.Size = curve({ { 0, 0.1 * k }, { 0.3, 0.5 * k }, { 1, 0 } })
		ember.Transparency = curve({ { 0, 1 }, { 0.15, 0.1 }, { 0.7, 0.4 }, { 1, 1 } })
		ember.Rotation, ember.RotSpeed = NumberRange.new(0, 360), NumberRange.new(-90, 90)
		ember.LockedToPart = false
		ember.Parent = point("TigerClawMid" .. index, claw[1]:Lerp(claw[2], 0.6))
		table.insert(state.embers, ember)
	end

	-- 4) LES YEUX DU CRÂNE : deux braises vertes de chaque côté, une lumière qui bat, un filet de fumée verte.
	for index, eye in EYES do
		local at = point("TigerEye" .. index, eye)
		local ball = Instance.new("Part")
		ball.Name = "TigerEyeGlow"
		ball.Shape = Enum.PartType.Ball
		ball.Material, ball.Color = Enum.Material.Neon, GREEN
		ball.Size = Vector3.one * 0.11 * k
		ball.Anchored, ball.Massless = true, true
		ball.CanCollide, ball.CanTouch, ball.CanQuery, ball.CastShadow = false, false, false, false
		ball.Parent = model
		table.insert(state.owned, ball)
		local smoke = Instance.new("ParticleEmitter")
		smoke.Name = "TigerEyeSmoke"
		smoke.Texture = SMOKE
		smoke.Color = ColorSequence.new(GREEN, Color3.fromRGB(20, 140, 60))
		smoke.LightEmission, smoke.LightInfluence = 1, 0
		smoke.Rate = if MOBILE then 2 else 5
		smoke.Lifetime, smoke.Speed = NumberRange.new(0.5, 0.9), NumberRange.new(0.3, 0.7)
		smoke.EmissionDirection = Enum.NormalId.Top
		smoke.SpreadAngle = Vector2.new(18, 18)
		smoke.Size = curve({ { 0, 0.06 * k }, { 0.4, 0.22 * k }, { 1, 0.3 * k } })
		smoke.Transparency = curve({ { 0, 1 }, { 0.15, 0.35 }, { 1, 1 } })
		smoke.LockedToPart = false
		smoke.Parent = at
		table.insert(state.eyes, { at = at, ball = ball })
	end
	local eyeLight = Instance.new("PointLight")
	eyeLight.Name = "TigerEyeLight"
	eyeLight.Color, eyeLight.Range, eyeLight.Brightness = GREEN, 7, 1.2
	eyeLight.Parent = point("TigerSkull", Vector3.new(0, 0, -1.06))
	state.eyeLight = eyeLight

	-- 5) L'ÉCLAT DU COUP : une lumière orange et une gerbe d'étincelles, au milieu des griffes.
	local heart = point("TigerHeart", Vector3.new(0, 0.2, -3.1))
	local flash = Instance.new("PointLight")
	flash.Name = "TigerFlash"
	flash.Color, flash.Range, flash.Brightness = ORANGE, 14, 0
	flash.Parent = heart
	state.flash = flash
	local burst = Instance.new("ParticleEmitter")
	burst.Name = "TigerBurst"
	burst.Texture = SPARK
	burst.Color = ColorSequence.new(Color3.new(1, 1, 0.8), ORANGE)
	burst.LightEmission, burst.LightInfluence = 1, 0
	burst.Rate, burst.Enabled = 0, false
	burst.Lifetime, burst.Speed = NumberRange.new(0.25, 0.5), NumberRange.new(7, 14)
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.Drag = 4
	burst.Size = curve({ { 0, 0.5 * k }, { 1, 0 } })
	burst.Transparency = curve({ { 0, 0 }, { 0.7, 0.3 }, { 1, 1 } })
	burst.Parent = heart
	state.burst = burst

	-- 7) L'AURA : toute la lame brûle. Des flammes orange montent le long des trois griffes, un grand halo l'entoure,
	-- une flamme verte sort de la garde (l'esprit de la jungle).
	state.aura = {}
	for index = 0, 5 do
		local flame = Instance.new("ParticleEmitter")
		flame.Name = "TigerAura" .. index
		flame.Texture = FLAME
		flame.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 150)), ColorSequenceKeypoint.new(0.3, AMBER), ColorSequenceKeypoint.new(0.7, ORANGE), ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 40, 10)) })
		-- (En plein jour, des flammes seulement lumineuses ne se voient pas : elles sont aussi opaques et vives.)
		flame.LightEmission, flame.LightInfluence, flame.Brightness = 0.55, 0, 3
		flame.Rate = if MOBILE then 10 else 24
		flame.Lifetime, flame.Speed = NumberRange.new(0.45, 0.8), NumberRange.new(0.8, 2)
		flame.SpreadAngle = Vector2.new(40, 40)
		flame.Acceleration = Vector3.new(0, 4, 0)
		flame.Size = curve({ { 0, 0.4 * k }, { 0.25, 1.5 * k }, { 0.7, 0.9 * k }, { 1, 0 } })
		flame.Transparency = curve({ { 0, 1 }, { 0.1, 0.05 }, { 0.6, 0.3 }, { 1, 1 } })
		flame.Rotation, flame.RotSpeed = NumberRange.new(-20, 20), NumberRange.new(-40, 40)
		flame.LockedToPart = false
		flame.ZOffset = -0.4
		flame.Parent = point("TigerAuraPoint" .. index, Vector3.new(0, 0.12, -1.7 - index * 0.48))
		table.insert(state.aura, { item = flame, rate = flame.Rate })
	end
	local spirit = Instance.new("ParticleEmitter")
	spirit.Name = "TigerSpirit"
	spirit.Texture = FLAME
	spirit.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(210, 255, 190)), ColorSequenceKeypoint.new(0.4, GREEN), ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 120, 60)) })
	spirit.LightEmission, spirit.LightInfluence, spirit.Brightness = 0.55, 0, 3
	spirit.Rate = if MOBILE then 8 else 20
	spirit.Lifetime, spirit.Speed = NumberRange.new(0.5, 0.9), NumberRange.new(0.6, 1.6)
	spirit.SpreadAngle = Vector2.new(50, 50)
	spirit.Acceleration = Vector3.new(0, 3, 0)
	spirit.Size = curve({ { 0, 0.3 * k }, { 0.3, 1.3 * k }, { 1, 0 } })
	spirit.Transparency = curve({ { 0, 1 }, { 0.12, 0.08 }, { 0.6, 0.35 }, { 1, 1 } })
	spirit.LockedToPart = false
	spirit.ZOffset = -0.4
	spirit.Parent = point("TigerSpiritPoint", Vector3.new(0, 0, -1.0))
	table.insert(state.aura, { item = spirit, rate = spirit.Rate })
	local low, high = point("TigerHaloLow", Vector3.new(0, 0.05, -1.3)), point("TigerHaloHigh", Vector3.new(0, 0.4, -4.5))
	local halo = Instance.new("Beam")
	halo.Name = "TigerHalo"
	halo.Attachment0, halo.Attachment1 = low, high
	halo.Width0, halo.Width1 = 3.0 * k, 1.6 * k
	halo.Segments, halo.FaceCamera = 8, true
	halo.Texture, halo.TextureMode = "rbxasset://textures/glow.png", Enum.TextureMode.Stretch
	halo.LightEmission, halo.LightInfluence, halo.Brightness = 0.6, 0, 3
	halo.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, ORANGE), ColorSequenceKeypoint.new(1, AMBER) })
	halo.Transparency = NumberSequence.new(0.6)
	halo.ZOffset = -0.6
	halo.Parent = primary
	state.halo = halo
	table.insert(state.glows, halo)
	local aglow = Instance.new("PointLight")
	aglow.Name = "TigerAuraLight"
	aglow.Color, aglow.Range, aglow.Brightness = ORANGE, 12, 1.6
	aglow.Parent = heart
	state.auraLight = aglow
	state.shards = {}
	-- (Retirés le 09/10 : en jeu, ces éclats faisaient des triangles jaunes plats, pas beaux. Mettre 3 pour les revoir.)
	for index = 1, 0 do
		local shard = Instance.new("WedgePart")
		shard.Name = "TigerShard"
		shard.Material, shard.Color = Enum.Material.Neon, if index == 2 then AMBER else ORANGE
		shard.Size = Vector3.new(0.14, 0.75, 0.32) * k
		shard.Anchored, shard.Massless = true, true
		shard.CanCollide, shard.CanTouch, shard.CanQuery, shard.CastShadow = false, false, false, false
		shard.Parent = model
		table.insert(state.owned, shard)
		table.insert(state.shards, shard)
	end

	-- 6) LES FEUILLES qui se détachent des lianes et tombent.
	local leaves = Instance.new("ParticleEmitter")
	leaves.Name = "TigerLeaves"
	leaves.Texture = SPARK
	leaves.Color = ColorSequence.new(Color3.fromRGB(90, 200, 70), Color3.fromRGB(40, 130, 50))
	leaves.LightEmission, leaves.LightInfluence = 0.2, 0.6
	leaves.Rate = if MOBILE then 1.5 else 3
	leaves.Lifetime, leaves.Speed = NumberRange.new(1.1, 1.7), NumberRange.new(0.3, 0.9)
	leaves.SpreadAngle = Vector2.new(60, 60)
	leaves.Acceleration = Vector3.new(0, -3.5, 0)
	leaves.Size = curve({ { 0, 0.14 * k }, { 0.8, 0.12 * k }, { 1, 0 } })
	leaves.Transparency = curve({ { 0, 1 }, { 0.1, 0.1 }, { 0.8, 0.3 }, { 1, 1 } })
	leaves.Rotation, leaves.RotSpeed = NumberRange.new(0, 360), NumberRange.new(-220, 220)
	leaves.LockedToPart = false
	leaves.Parent = point("TigerVines", Vector3.new(0, -0.1, -2.3))
	state.leaves = leaves
	return state
end

-- À chaque image. swinging : l'épée est en train de frapper ; visible : assez près de la caméra ; clear : l'épée
-- vient de se téléporter (on efface les traînées pour ne pas tirer un trait à travers le monde).
function Tiger.update(state, dt: number, visible: boolean, swinging: boolean, clear: boolean)
	if not state then
		return
	end
	state.time += dt
	local started = swinging and not state.swinging
	state.swinging = swinging
	if clear or started or not visible then
		for _, trail in state.trails do
			trail:Clear()
		end
	end
	if started and visible then
		state.heat = 1
		state.burst:Emit(if MOBILE then 10 else 22)
	end
	-- La chaleur monte d'un coup au départ du coup, puis retombe en une demi-seconde.
	state.heat = if swinging then math.max(state.heat, 0.75) else math.max(0, state.heat - dt * 2.2)
	local heat = state.heat
	local pulse = 0.5 + 0.5 * math.sin(state.time * 3.2)
	for index, trail in state.trails do
		trail.Enabled = visible and swinging
		-- (Les griffes brillent l'une après l'autre au repos, comme une respiration ; toutes ensemble dans le coup.)
		local breath = 0.5 + 0.5 * math.sin(state.time * 2.4 - index * 0.9)
		local glow = state.glows[index]
		glow.Enabled = visible
		glow.Transparency = NumberSequence.new(math.clamp(0.55 - 0.25 * breath - 0.4 * heat, 0.05, 1))
		glow.Width0 = (1.1 + 0.7 * heat) * state.k
		local ember = state.embers[index]
		ember.Enabled = visible
		ember.Rate = (if MOBILE then 5 else 10) * (1 + 5 * heat)
	end
	for _, eye in state.eyes do
		eye.ball.CFrame = CFrame.new(eye.at.WorldPosition)
		eye.ball.Transparency = if visible then 0 else 1
		eye.ball.Size = Vector3.one * (0.11 + 0.025 * pulse + 0.07 * heat) * state.k
		eye.ball.Color = GREEN:Lerp(Color3.new(1, 1, 0.7), heat * 0.6)
	end
	state.eyeLight.Enabled = visible
	state.eyeLight.Brightness = 1 + 0.8 * pulse + 3 * heat
	state.flash.Enabled = visible and heat > 0.02
	state.flash.Brightness = 5 * heat
	state.leaves.Enabled = visible
	-- L'aura : plus forte et plus large pendant le coup.
	for _, flame in state.aura do
		flame.item.Enabled = visible
		flame.item.Rate = flame.rate * (1 + 1.5 * heat)
	end
	state.halo.Enabled = visible
	state.halo.Transparency = NumberSequence.new(math.clamp(0.38 - 0.12 * pulse - 0.25 * heat, 0.05, 1))
	state.halo.Width0 = (3.0 + 1.4 * heat) * state.k
	state.auraLight.Enabled = visible
	state.auraLight.Brightness = 1.4 + 0.6 * pulse
	-- Les trois éclats tournent autour de la lame, en montant et en descendant.
	local frame = state.primary.CFrame
	for index, shard in state.shards do
		local turn = state.time * (2.2 + 2.5 * heat) + index * math.pi * 2 / 3
		local along = -2.9 + math.sin(state.time * 1.3 + index * 2) * 1.1
		local radius = 0.95 + 0.25 * heat
		shard.CFrame = frame * CFrame.new(Vector3.new(math.cos(turn) * radius, 0.15 + math.sin(turn) * radius, along) * state.k) * CFrame.Angles(turn, 0, turn * 0.5)
		shard.Transparency = if visible then 0.1 else 1
	end
end

function Tiger.dispose(state)
	if not state then
		return
	end
	for _, item in state.owned do
		item:Destroy()
	end
	for _, trail in state.trails do
		trail:Destroy()
	end
	for _, glow in state.glows do
		glow:Destroy()
	end
end

return Tiger

-- Blade-local elemental VFX. No mesh, texture, grip or gameplay is modified.
-- Uses Roblox's bundled particle textures: no uploads or third-party scripts.
local Input = game:GetService("UserInputService")
local Aura = {}
local MOBILE = Input.TouchEnabled
local CAP = if MOBILE then 6 else 16
local allocated = 0
local TEXTURES = {
	flame = "rbxasset://textures/particles/fire_main.dds",
	spark = "rbxasset://textures/particles/sparkles_main.dds",
	ember = "rbxasset://textures/particles/fire_sparks_main.dds",
	mist = "rbxasset://textures/particles/smoke_main.dds",
	glow = "rbxasset://textures/glow.png",
}
Aura.textures = TEXTURES
Aura.BOOST = 3
local COLORS = {
	Flame = Color3.fromRGB(255, 123, 24),
	Frost = Color3.fromRGB(84, 218, 255),
	Storm = Color3.fromRGB(255, 214, 34),
}
function Aura.supports(id: string): boolean
	return COLORS[id] ~= nil
end
local function curve(values)
	local keys = {}
	for _, value in values do table.insert(keys, NumberSequenceKeypoint.new(value[1], value[2])) end
	return NumberSequence.new(keys)
end
local function anchor(state, name: string): Attachment
	local item = Instance.new("Attachment")
	item.Name, item.Parent = name, state.primary
	table.insert(state.owned, item)
	return item
end
local function beam(state, name, a, b, color, width, texture): Beam
	local item = Instance.new("Beam")
	item.Name, item.Attachment0, item.Attachment1 = name, a, b
	item.Color, item.Width0, item.Width1 = ColorSequence.new(color), width, width * 0.52
	item.FaceCamera, item.LightEmission, item.LightInfluence = true, 1, 0
	-- Fade curves need interior segments; with one segment both transparent
	-- endpoints can erase the halo. Lightning rays use a constant opacity.
	item.Segments, item.Enabled = if texture then 10 else 1, false
	if texture then
		item.Texture, item.TextureMode = texture, Enum.TextureMode.Stretch
	end
	item.Transparency = curve({ {0, 0.55}, {0.2, 0.2}, {0.8, 0.28}, {1, 0.85} })
	item.Parent = state.folder
	table.insert(state.beams, item)
	return item
end
local function emitter(state, point, name, texture, rate, color): ParticleEmitter
	local item = Instance.new("ParticleEmitter")
	item.Name, item.Texture, item.Color = name, texture, color
	item.Rate, item.Enabled = rate * (if MOBILE then 0.55 else 1), false
	item.LightEmission, item.LightInfluence = 1, 0
	item.Lifetime, item.Speed = NumberRange.new(0.35, 0.7), NumberRange.new(0.18, 0.5)
	item.SpreadAngle = Vector2.new(25, 25)
	item.Transparency = curve({ {0, 1}, {0.12, 0.2}, {0.6, 0.4}, {1, 1} })
	item.Size = curve({ {0, 0.04}, {0.22, 0.34}, {0.7, 0.22}, {1, 0} })
	item.Rotation, item.RotSpeed = NumberRange.new(-15, 15), NumberRange.new(-30, 30)
	item.LockedToPart, item.VelocityInheritance = true, 0
	item.Parent = point
	table.insert(state.emitters, { item = item, rate = item.Rate })
	return item
end
function Aura.create(model: Model, id: string, base: Attachment, tip: Attachment)
	if not Aura.supports(id) or allocated >= CAP or not model.PrimaryPart then return nil end
	local state = {
		id = id, primary = model.PrimaryPart, base = base, tip = tip,
		owned = {}, beams = {}, emitters = {}, points = {}, bolts = {}, time = 0,
		visible = false, disposed = false, seed = Random.new(314159 + allocated * 1709),
	}
	state.folder = Instance.new("Folder")
	state.folder.Name, state.folder.Parent = "ElementalBladeAura", model
	allocated += 1
	state.glowBase, state.glowTip = anchor(state, "AuraBladeBase"), anchor(state, "AuraBladeTip")
	state.halo = beam(state, "SoftBladeHalo", state.glowBase, state.glowTip, COLORS[id], 0.76, TEXTURES.glow)
	state.halo.Transparency = curve({ {0, 1}, {0.13, 0.62}, {0.78, 0.68}, {1, 1} })
	state.core = beam(state, "LuminousBladeEdge", state.glowBase, state.glowTip,
		Color3.new(1, 1, 1):Lerp(COLORS[id], 0.18), 0.055, TEXTURES.glow)
	state.core.Transparency = curve({ {0, 1}, {0.08, 0.38}, {0.86, 0.3}, {1, 1} })
	for i = 1, 3 do
		local at = anchor(state, "ElementalBladePoint" .. i)
		table.insert(state.points, { at = at, fraction = 0.12 + (i - 1) * 0.34 })
		if id == "Flame" then
			local fire = emitter(state, at, "BladeFlames", TEXTURES.flame, 8,
				ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 238, 130)),
				ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 158, 20)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(240, 45, 8)) }))
			fire.Size = curve({ {0, 0.12}, {0.2, 0.48}, {0.65, 0.36}, {1, 0} })
			fire.Squash = curve({ {0, 0.25}, {0.5, 0.8}, {1, 1.1} })
			fire.Acceleration, fire.Drag = Vector3.new(0, 0.95, 0), 1.4
			local sparks = emitter(state, at, "RisingEmbers", TEXTURES.ember, 3,
				ColorSequence.new(Color3.fromRGB(255, 183, 47)))
			sparks.LockedToPart, sparks.Speed = false, NumberRange.new(0.55, 1.4)
			sparks.Acceleration = Vector3.new(0, 0.7, 0)
			sparks.Size = curve({ {0, 0.04}, {0.2, 0.11}, {1, 0} })
		elseif id == "Frost" then
			local mist = emitter(state, at, "ColdBladeMist", TEXTURES.mist, 3.5,
				ColorSequence.new(Color3.fromRGB(169, 237, 255)))
			mist.Size = curve({ {0, 0.05}, {0.35, 0.45}, {1, 0.64} })
			mist.Transparency = curve({ {0, 1}, {0.22, 0.85}, {0.7, 0.92}, {1, 1} })
			mist.Acceleration, mist.Drag = Vector3.new(0, -0.18, 0), 1.2
			local frost = emitter(state, at, "IceScintillation", TEXTURES.spark, 2.5,
				ColorSequence.new(Color3.fromRGB(224, 252, 255)))
			frost.Rotation, frost.RotSpeed = NumberRange.new(0, 360), NumberRange.new(-70, 70)
			frost.Size = curve({ {0, 0.01}, {0.3, 0.18}, {1, 0} })
			frost.SpreadAngle = Vector2.new(180, 180)
		else
			local sparks = emitter(state, at, "ElectricGlints", TEXTURES.spark, 1.8,
				ColorSequence.new(Color3.fromRGB(255, 238, 135)))
			sparks.Size = curve({ {0, 0}, {0.16, 0.11}, {1, 0} })
		end
	end
	local lightAt = anchor(state, "BladeLightPoint")
	state.lightAt = lightAt
	state.light = Instance.new("PointLight")
	state.light.Name, state.light.Color = "ElementalBladeLight", COLORS[id]
	state.light.Range, state.light.Brightness, state.light.Shadows = 6, 0, false
	state.light.Parent = lightAt
	if id == "Storm" then
		for k = 1, (if MOBILE then 2 else 3) do
			local bolt = { nodes = {}, branches = {}, beams = {}, next = k * 0.17, fade = 0 }
			for i = 1, 7 do table.insert(bolt.nodes, anchor(state, "ElectricArc" .. k .. "Point" .. i)) end
			for i = 1, 6 do
				for _, spec in { { COLORS.Storm, 0.075 }, { Color3.fromRGB(255, 254, 224), 0.018 } } do
					local ray = beam(state, "ElectricArcSegment", bolt.nodes[i], bolt.nodes[i+1], spec[1], spec[2], nil)
					table.insert(bolt.beams, ray)
				end
			end
			for i = 1, 2 do
				local fork = anchor(state, "ElectricArcFork" .. k .. "Point" .. i)
				table.insert(bolt.branches, fork)
				local ray = beam(state, "ElectricArcBranch", bolt.nodes[3+i], fork, COLORS.Storm, 0.025, nil)
				table.insert(bolt.beams, ray)
			end
			table.insert(state.bolts, bolt)
		end
	end
	-- (Claude, 07/10 : avec les epees enormes du jeu, 8 studs, ces effets etaient trop petits pour se voir : rien
	-- sur les photos, alors que tout etait allume. BOOST fois plus gros et plus nombreux ; le halo sans texture, car
	-- avec « glow.png » il ne s affichait pas du tout.)
	for _, entry in state.emitters do
		local keys = {}
		for _, key in entry.item.Size.Keypoints do
			table.insert(keys, NumberSequenceKeypoint.new(key.Time, key.Value * Aura.BOOST))
		end
		entry.item.Size = NumberSequence.new(keys)
		entry.rate *= Aura.BOOST
		entry.item.Rate = entry.rate
		entry.item.Speed = NumberRange.new(entry.item.Speed.Min * Aura.BOOST, entry.item.Speed.Max * Aura.BOOST)
	end
	state.halo.Texture, state.core.Texture = "", ""
	state.halo.Transparency = curve({ {0, 1}, {0.15, 0.72}, {0.8, 0.78}, {1, 1} })
	state.core.Width0, state.core.Width1 = 0.16, 0.08
	state.light.Range = 14
	return state
end
function Aura.dispose(state)
	if not state or state.disposed then return end
	state.disposed = true
	allocated = math.max(0, allocated - 1)
	for _, item in state.owned do item:Destroy() end
	state.folder:Destroy()
end
function Aura.update(state, dt: number, visible: boolean, swinging: boolean, clear: boolean)
	if not state or state.disposed then return end
	state.time += math.clamp(dt, 0, 0.1)
	local wasVisible = state.visible
	state.visible = visible
	for _, entry in state.emitters do
		entry.item.Enabled = visible
		if clear or (wasVisible and not visible) then entry.item:Clear() end
		entry.item.Rate = entry.rate * (if swinging then 1.25 else 1)
	end
	for _, ray in state.beams do ray.Enabled = visible end
	if not visible then state.light.Brightness = 0; return end
	local primary, a, b = state.primary, state.base.WorldPosition, state.tip.WorldPosition
	local length = (b - a).Magnitude
	if length < 0.05 then
		for _, ray in state.beams do ray.Enabled = false end
		for _, entry in state.emitters do entry.item.Enabled = false end
		state.light.Brightness = 0
		return
	end
	state.glowBase.WorldPosition, state.glowTip.WorldPosition = a, b
	state.lightAt.WorldPosition = a:Lerp(b, 0.46)
	local pulse = 0.5 + 0.5 * math.sin(state.time * 2.1)
	state.halo.Width0, state.halo.Width1 = length * (0.24 + 0.018 * pulse), length * 0.085
	state.light.Brightness = (if MOBILE then 0.18 else 0.42) * (0.85 + pulse * 0.15) * (if swinging then 1.25 else 1)
	for _, point in state.points do
		point.at.WorldCFrame = CFrame.new(a:Lerp(b, point.fraction))
	end
	-- Regenerate bolt SHAPE a few times per second; move its existing points with
	-- the blade every frame. No per-frame instances, no noise-chasing rectangles.
	local radius = math.clamp(length * 0.13, 0.22, 0.5)
	for _, bolt in state.bolts do
		if state.time >= bolt.next then
			bolt.next = state.time + state.seed:NextNumber(0.28, 0.5)
			bolt.fade = state.time + 0.16
			bolt.phase = state.seed:NextNumber(0, math.pi * 2)
			bolt.noise = {}
			for i = 1, 9 do table.insert(bolt.noise, state.seed:NextNumber(-1, 1)) end
		end
		local on = state.time < bolt.fade
		local phase, noise = bolt.phase or 0, bolt.noise
		if noise then
			for i, at in bolt.nodes do
				local t = (i - 1) / 6
				local theta = phase + t * 2.3
				local offset = primary.CFrame.RightVector * (math.cos(theta) * radius * (0.65 + noise[i] * 0.35))
					+ primary.CFrame.UpVector * (math.sin(theta) * radius * (0.7 - noise[i] * 0.3))
				at.WorldPosition = a:Lerp(b, 0.05 + t * 0.92) + offset
			end
			for i, at in bolt.branches do
				at.WorldPosition = bolt.nodes[3+i].WorldPosition
					+ primary.CFrame.UpVector * (radius * noise[7+i])
					+ primary.CFrame.LookVector * (length * 0.13)
			end
		end
		local opacity = NumberSequence.new(math.clamp(1 - (bolt.fade - state.time) / 0.16, 0.08, 1))
		for _, ray in bolt.beams do
			ray.Enabled = on
			ray.Transparency = opacity
		end
	end
end
return Aura

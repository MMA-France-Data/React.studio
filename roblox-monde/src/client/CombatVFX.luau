-- Original, texture-free combat effects. Cosmetic only; never deals damage.
-- Curved white crescents + elemental edge, sparks and confirmed-hit shock ring.
local RunService = game:GetService("RunService")
local Input = game:GetService("UserInputService")
local VFX = {}
local COLORS = {
	Color3.fromRGB(191, 215, 241), Color3.fromRGB(220, 240, 255),
	Color3.fromRGB(83, 226, 255), Color3.fromRGB(255, 104, 35),
	Color3.fromRGB(167, 100, 255), Color3.fromRGB(255, 57, 201),
}
local ARC_CAP = if Input.TouchEnabled then 8 else 14
local SPARK_CAP = if Input.TouchEnabled then 48 else 80
local live, arcPool, sparkPool = {}, {}, {}
local arcCount, sparkCount = 0, 0
local container, connection
local function folder()
	if not container then
		container = Instance.new("Folder")
		container.Name = "MondeCombatVFX"
		container.Parent = workspace
	end
	return container
end
local function visible(position: Vector3): boolean
	local camera = workspace.CurrentCamera
	return camera ~= nil and (camera.CFrame.Position - position).Magnitude <= 85
end
local function color(tier: number, index: number?): Color3
	if tier >= 6 and index then return Color3.fromHSV((index * 0.16) % 1, 0.90, 1) end
	return COLORS[math.clamp(tier, 1, #COLORS)]
end
local function piece(): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Size = Vector3.new(0.08, 0.08, 0.08)
	p.Transparency = 1
	p.Parent = folder()
	return p
end
local function acquireArc()
	if #arcPool > 0 then return table.remove(arcPool) end
	if arcCount >= ARC_CAP then return nil end
	arcCount += 1
	local entry = { anchor = piece(), beams = {} }
	entry.anchor.Name = "Crescent"
	for layer = 1, 2 do
		for i = 1, 4 do
			local a, b = Instance.new("Attachment"), Instance.new("Attachment")
			a.Parent, b.Parent = entry.anchor, entry.anchor
			local beam = Instance.new("Beam")
			beam.Attachment0, beam.Attachment1 = a, b
			beam.LightEmission, beam.LightInfluence = 1, 0
			beam.Brightness = 2
			beam.Segments = if Input.TouchEnabled then 8 else 12
			-- Keep the crescent visible, even with a steep mobile camera angle.
			beam.FaceCamera = true
			beam.Enabled = false
			beam.Parent = entry.anchor
			table.insert(entry.beams, { beam = beam, a = a, b = b, layer = layer, index = i })
		end
	end
	return entry
end
local function acquireSpark()
	if #sparkPool > 0 then return table.remove(sparkPool) end
	if sparkCount >= SPARK_CAP then return nil end
	sparkCount += 1
	local p = piece()
	p.Name = "CombatSpark"
	return p
end
local function release(effect)
	if effect.kind == "arc" then
		for _, s in effect.entry.beams do s.beam.Enabled = false end
		table.insert(arcPool, effect.entry)
	else
		effect.part.Transparency = 1
		table.insert(sparkPool, effect.part)
	end
end
local function frame(theta: number, radius: number): CFrame
	local radial = Vector3.new(math.cos(theta), 0, math.sin(theta))
	local tangent = Vector3.new(-math.sin(theta), 0, math.cos(theta))
	return CFrame.fromMatrix(radial * radius, tangent, radial)
end
local function update(effect, u)
	if effect.kind == "arc" then
		local radius = effect.radius * (1 + (if effect.ring then 1.05 else 0.18) * u)
		effect.entry.anchor.CFrame = effect.base
		local span = if effect.ring then effect.span else effect.direction * math.min(math.rad(105), math.rad(170) * u + math.rad(8))
		local start = if effect.ring then effect.start else effect.start + effect.direction * math.rad(170) * u - span
		for _, s in effect.entry.beams do
			local a = start + (s.index - 1) * span / 4
			local b = start + s.index * span / 4
			s.a.CFrame, s.b.CFrame = frame(a, radius), frame(b, radius)
			local curve = radius * 4 / 3 * math.tan((b - a) / 4)
			s.beam.CurveSize0, s.beam.CurveSize1 = curve, curve
			local taperA = if effect.ring then 1 else math.sin((s.index - 1) / 4 * math.pi) + 0.025
			local taperB = if effect.ring then 1 else math.sin(s.index / 4 * math.pi) + 0.025
			local width = effect.width * (1 - u * 0.7) * (if s.layer == 1 then 1 else 1.45)
			s.beam.Width0, s.beam.Width1 = width * taperA, width * taperB
			s.beam.Color = ColorSequence.new(if s.layer == 1 then Color3.new(1, 1, 1) else color(effect.tier, s.index))
			s.beam.Transparency = NumberSequence.new(math.clamp(u * u + (if s.layer == 1 then 0.08 else 0.38), 0, 1))
			s.beam.ZOffset = if s.layer == 1 then 0.012 else 0
			s.beam.Enabled = true
		end
	else
		local elapsed = u * effect.life
		local at = effect.position + effect.velocity * elapsed + Vector3.new(0, -14 * elapsed * elapsed, 0)
		effect.part.CFrame = CFrame.new(at) * effect.rotation
		effect.part.Size = effect.size * (if effect.flash then 1 + u * 3 else math.max(0.05, 1 - u))
		effect.part.Transparency = math.clamp(u * u, 0, 1)
	end
end
local function ensure()
	if connection then return end
	connection = RunService.PreRender:Connect(function(dt)
		for i = #live, 1, -1 do
			local effect = live[i]
			effect.age += dt
			if effect.age >= effect.life then
				release(effect)
				table.remove(live, i)
			else update(effect, effect.age / effect.life) end
		end
	end)
end
local function sparks(position: Vector3, tier: number, count: number)
	for i = 1, count do
		local p = acquireSpark()
		if not p then break end
		p.Shape = Enum.PartType.Block
		p.Color = if i % 3 == 0 then Color3.new(1, 1, 1) else color(tier, i)
		local angle = i / count * math.pi * 2
		local velocity = Vector3.new(math.cos(angle), 0.8 + i % 3 * 0.18, math.sin(angle)) * (9 + i % 4)
		local effect = { kind = "spark", part = p, position = position, velocity = velocity, rotation = CFrame.Angles(angle, angle * 0.6, angle), size = Vector3.new(0.07, 0.07, 0.45), life = 0.23 + i % 3 * 0.035, age = 0 }
		table.insert(live, effect)
		update(effect, 0)
	end
end
function VFX.slash(root: CFrame, tier: number, variant: string)
	if not visible(root.Position) then return end
	ensure()
	local entry = acquireArc()
	if not entry then return end
	local direction = if variant == "SlashLeft" then -1 else 1
	local base = root * CFrame.new(0, 0.55, 0)
	local effect = { kind = "arc", entry = entry, base = base, radius = 4.2, width = 1.1, start = math.rad(if direction == 1 then 185 else 355), direction = direction, tier = tier, life = 0.22, age = 0 }
	table.insert(live, effect)
	update(effect, 0)
	sparks((root * CFrame.new(0, 0.6, -3.4)).Position, tier, if Input.TouchEnabled then 3 else 5)
end
-- Call only from the existing confirmed sword-hit event, NOT for a missed swing.
function VFX.impact(position: Vector3, tier: number)
	if not visible(position) then return end
	ensure()
	sparks(position + Vector3.new(0, 1.3, 0), tier, if Input.TouchEnabled then 6 else 10)
	local entry = acquireArc()
	if entry then
		local effect = { kind = "arc", entry = entry, base = CFrame.new(position + Vector3.new(0, 0.16, 0)), radius = 0.8, width = 0.16, start = 0, span = math.pi * 2, tier = tier, life = 0.25, age = 0, ring = true }
		table.insert(live, effect);update(effect, 0)
	end
	local p = acquireSpark()
	if p then
		p.Shape = Enum.PartType.Ball;p.Color = Color3.new(1, 1, 1)
		local effect = { kind = "spark", part = p, position = position + Vector3.new(0, 1.2, 0), velocity = Vector3.zero, rotation = CFrame.identity, size = Vector3.new(0.25, 0.25, 0.25), life = 0.10, age = 0, flash = true }
		table.insert(live, effect);update(effect, 0)
	end
end
function VFX.clear()
	for _, effect in live do release(effect) end
	table.clear(live)
end
function VFX.destroy()
	VFX.clear()
	if connection then connection:Disconnect();connection = nil end
	if container then container:Destroy();container = nil end
	table.clear(arcPool);table.clear(sparkPool)
	arcCount, sparkCount = 0, 0
end
return VFX

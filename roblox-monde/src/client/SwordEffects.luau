-- Cosmetic, texture-free FX for native swords or calibrated imported meshes.
-- Call update AFTER the sword follows RightHand, once per rendered frame.
local Input = game:GetService("UserInputService")
local Palette = require(script.Parent.SwordPalette)
local Effects = {}
local MOBILE = Input.TouchEnabled
local PART_CAP = if MOBILE then 48 else 128
local allocated = 0
local registry = setmetatable({}, { __mode = "k" })
local function attachment(model: Model, name: string): Attachment?
	local found = model:FindFirstChild(name, true)
	return if found and found:IsA("Attachment") then found else nil
end
local function trail(name: string, a: Attachment, b: Attachment, color: ColorSequence, core: boolean): Trail
	local result = Instance.new("Trail")
	result.Name, result.Attachment0, result.Attachment1 = name, a, b
	result.Lifetime = if core then 0.09 else 0.13
	result.MinLength = 0.035
	result.FaceCamera = true
	result.LightEmission, result.LightInfluence = 1, 0
	result.Color = color
	result.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, if core then 0.05 else 0.48),
		NumberSequenceKeypoint.new(0.5, if core then 0.25 else 0.65),
		NumberSequenceKeypoint.new(1, 1),
	})
	result.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
	result.Enabled = false
	result.Parent = a.Parent
	return result
end
function Effects.attach(model: Model, identity: any)
	if registry[model] then return registry[model] end
	local a, b = attachment(model, "TrailBase"), attachment(model, "TrailTip")
	assert(a and b and a.Parent:IsA("BasePart"), "Épée : TrailBase / TrailTip requis")
	local id = Palette.id(identity)
	local old = model:FindFirstChild("SwingTrail", true)
	if old and old:IsA("Trail") then old:Destroy() end
	local inner = Instance.new("Attachment")
	inner.Name = "BladeWhiteCore"
	-- Relative to the SAME actual BasePart, even if the tip is on another part.
	inner.Position = a.Parent.CFrame:PointToObjectSpace(a.WorldPosition:Lerp(b.WorldPosition, 0.62))
	inner.Parent = a.Parent
	local holder = Instance.new("Folder")
	holder.Name, holder.Parent = "SwordAura", model
	local state = { id = id, a = a, b = b, holder = holder, bits = {}, elapsed = 0,
		core = trail("SwingWhiteCore", inner, b, ColorSequence.new(Color3.new(1, 1, 1)), true),
		edge = trail("SwingTrail", a, b, Palette.sequence(id), false), swinging = false, disposed = false }
	registry[model] = state
	model.Destroying:Connect(function()
		if state.disposed then return end
		state.disposed = true
		allocated -= #state.bits
		registry[model] = nil
	end)
	return state
end
local function buildBits(state)
	if #state.bits > 0 then return end
	local desired = if state.id == "Iron" then 2 else (if MOBILE then 3 else 5)
	if allocated + desired > PART_CAP then return end
	for i = 1, desired do
		local p = Instance.new(if state.id == "Frost" or state.id == "Flame" or state.id == "Prismatic" then "WedgePart" else "Part")
		p.Name = state.id .. "Orbit"
		p.Anchored, p.Massless = true, true
		p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = false, false, false, false
		p.Material = Enum.Material.Neon
		p.Color, p.Transparency = Palette.color(state.id, i / desired), 1
		p.Size = Vector3.new(0.06, 0.12, 0.06)
		p.Parent = state.holder
		local bit = { part = p, index = i, beams = {} }
		if state.id == "Gold" then
			-- Four tapered, camera-facing arms make a little golden sparkle.
			local center = Instance.new("Attachment")
			center.Parent = p
			for j, offset in { Vector3.xAxis, -Vector3.xAxis, Vector3.yAxis, -Vector3.yAxis } do
				local tip = Instance.new("Attachment")
				tip.Position, tip.Parent = offset * (if j <= 2 then 0.11 else 0.16), p
				local beam = Instance.new("Beam")
				beam.Attachment0, beam.Attachment1 = center, tip
				beam.Width0, beam.Width1, beam.Segments = 0.055, 0.002, 1
				beam.Color, beam.FaceCamera = ColorSequence.new(Palette.color("Gold")), true
				beam.LightEmission, beam.LightInfluence = 1, 0
				beam.Enabled, beam.Parent = false, p
				table.insert(bit.beams, beam)
			end
		elseif state.id == "Storm" then
			-- Three short animated zig-zag segments: yellow, never blue/violet.
			local previous
			for j = 0, 3 do
				local a = Instance.new("Attachment")
				a.Parent = p
				if previous then
					local beam = Instance.new("Beam")
					beam.Attachment0, beam.Attachment1 = previous, a
					beam.Width0, beam.Width1, beam.Segments = 0.028, 0.016, 1
					beam.Color, beam.FaceCamera = ColorSequence.new(Palette.color("Storm")), true
					beam.LightEmission, beam.LightInfluence = 1, 0
					beam.Enabled, beam.Parent = false, p
					table.insert(bit.beams, beam)
				end
				table.insert(bit, a)
				previous = a
			end
		end
		table.insert(state.bits, bit)
	end
	allocated += desired
end
function Effects.update(model: Model, dt: number, swinging: boolean)
	local state = registry[model]
	if not state or state.disposed then return end
	local a, b = state.a.WorldPosition, state.b.WorldPosition
	local camera = workspace.CurrentCamera
	local visible = camera ~= nil and (camera.CFrame.Position - a).Magnitude < (if MOBILE then 55 else 70)
	local teleport = state.last and (a - state.last).Magnitude > 10
	if teleport or (swinging and not state.swinging) or not visible then
		state.core:Clear(); state.edge:Clear()
	end
	state.last, state.swinging = a, swinging
	state.core.Enabled, state.edge.Enabled = visible and swinging, visible and swinging
	state.elapsed += math.min(math.max(dt, 0), 0.10)
	if visible then buildBits(state) end
	local primary = model.PrimaryPart
	if not primary then return end
	local length = (b - a).Magnitude
	local radius = math.clamp(length * 0.06, 0.12, 0.32) * (if swinging then 1.25 else 1)
	for _, bit in state.bits do
		local p, i = bit.part, bit.index
		if not visible then
			p.Transparency = 1
			for _, beam in bit.beams do beam.Enabled = false end
			continue
		end
		local phase = state.elapsed * (if state.id == "Flame" then 1.0 else 0.65) + i / #state.bits
		local theta = phase * math.pi * 2
		local along = 0.15 + 0.75 * ((phase * 0.45 + i * 0.19) % 1)
		local offset = primary.CFrame.RightVector * (math.cos(theta) * radius)
			+ primary.CFrame.UpVector * (math.sin(theta) * radius)
		local position = a:Lerp(b, along) + offset
		if state.id == "Flame" then position += Vector3.new(0, 0.20 * math.sin(theta) ^ 2, 0) end
		p.CFrame = CFrame.new(position) * primary.CFrame.Rotation * CFrame.Angles(theta, theta * 0.4, theta)
		local size = (if state.id == "Iron" then 0.045 else 0.07) * (if swinging then 1.2 else 1)
		p.Size = if state.id == "Gold" then Vector3.new(size, size * 2.3, size)
			elseif state.id == "Frost" or state.id == "Prismatic" then Vector3.new(size, size * 2.8, size * 1.5)
			elseif state.id == "Flame" then Vector3.new(size, size * 2.5, size)
			else Vector3.new(size, size, size)
		p.Color = if state.id == "Flame" then Palette.color("Flame"):Lerp(Color3.fromRGB(255, 211, 60), i / #state.bits)
			else Palette.color(state.id, phase * 0.22 + i / #state.bits)
		p.Transparency = if state.id == "Iron" then 0.50 else 0.18 + math.sin(theta) ^ 2 * 0.35
		for j, beam in bit.beams do
			if state.id == "Storm" then
				bit[j].Position = Vector3.new((j - 2) * 0.07, math.sin(theta * 3 + j * 2) * 0.07, (j - 2) * 0.11)
				bit[j + 1].Position = Vector3.new((j - 1) * 0.07, math.sin(theta * 3 + (j + 1) * 2) * 0.07, (j - 1) * 0.11)
			end
			beam.Enabled = true
		end
	end
end
return Effects

-- A single connected silhouette, made of soft scrolling smoke, not a solid
-- shell/cone. The narrow upper plume sheds world-space smoke and disappears.
local Input = game:GetService("UserInputService")
local Profile = require(script.Parent.VoidAuraProfile)
local Void = {}
local MOBILE = Input.TouchEnabled
local TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local FRACTIONS = { 0.12, 0.36, 0.60, 0.84 }
local function curve(values)
	local keys = {}
	for _, value in values do table.insert(keys, NumberSequenceKeypoint.new(value[1], value[2])) end
	return NumberSequence.new(keys)
end
local function anchor(state, name)
	local at = Instance.new("Attachment")
	at.Name, at.Parent = name, state.primary
	table.insert(state.owned, at)
	return at
end
function Void.create(model: Model, base: Attachment, tip: Attachment, seed: number)
	local state = {
		kind = "VoidShroud", id = "Void", primary = model.PrimaryPart, base = base, tip = tip,
		owned = {}, beams = {}, emitters = {}, nodes = {}, segments = {}, markers = {},
		time = 0, phase = seed * 1.73, visible = false, disposed = false,
	}
	state.folder = Instance.new("Folder")
	state.folder.Name, state.folder.Parent = "VoidBladeShroud", model
	local a, b = state.primary.CFrame:PointToObjectSpace(base.WorldPosition), state.primary.CFrame:PointToObjectSpace(tip.WorldPosition)
	local axis = b - a
	local direction = if axis.Magnitude > 0.05 then axis.Unit else -Vector3.zAxis
	for i, fraction in FRACTIONS do
		local marker = model:FindFirstChild("AuraShadow" .. i, true)
		if marker and marker:IsA("Attachment") then
			-- Follow the curved scimitar, rather than wrapping its bounding box.
			local delta = state.primary.CFrame:PointToObjectSpace(marker.WorldPosition) - a:Lerp(b, fraction)
			delta -= direction * delta:Dot(direction)
			table.insert(state.markers, {fraction = fraction, offset = delta * 0.55})
		else
			table.insert(state.markers, {fraction = fraction, offset = Vector3.zero})
		end
	end
	for i, fraction in (if MOBILE then Profile.mobileNodes else Profile.nodes) do
		table.insert(state.nodes, {at = anchor(state, "VoidSmokeSpine" .. i), fraction = fraction})
	end
	for _, layer in Profile.layers do
		for i = 1, #state.nodes - 1 do
			local from, to = state.nodes[i], state.nodes[i + 1]
			local ray = Instance.new("Beam")
			ray.Name, ray.Parent = layer.name .. i, state.folder
			ray.Attachment0, ray.Attachment1 = from.at, to.at
			ray.Texture, ray.TextureMode, ray.TextureLength = TEXTURE, Enum.TextureMode.Wrap, Profile.textureLength
			ray.TextureSpeed = 0 -- one shared advancing phase across every segment
			ray.Color = ColorSequence.new(Color3.fromRGB(table.unpack(layer.color)))
			ray.Transparency = curve({ {0, Profile.opacityAt(from.fraction, layer.fade)}, {1, Profile.opacityAt(to.fraction, layer.fade)} })
			ray.LightEmission, ray.LightInfluence, ray.FaceCamera = layer.emission, 0.12, true
			ray.Segments, ray.Width0, ray.Width1, ray.Enabled = 3, 0, 0, false
			ray.ZOffset = 0
			table.insert(state.beams, ray)
			table.insert(state.segments, {ray = ray, index = i, layer = layer})
		end
	end
	state.plumeAt = anchor(state, "VoidDissolvingPlume")
	local plume = Instance.new("ParticleEmitter")
	plume.Name, plume.Parent, plume.Texture = "VoidRisingSmoke", state.plumeAt, TEXTURE
	plume.Color = ColorSequence.new(Color3.fromRGB(table.unpack(Profile.plume.first)), Color3.fromRGB(table.unpack(Profile.plume.last)))
	plume.Lifetime, plume.Speed = NumberRange.new(table.unpack(Profile.plume.lifetime)), NumberRange.new(table.unpack(Profile.plume.speed))
	plume.Size, plume.Transparency = curve(Profile.plume.size), curve(Profile.plume.transparency)
	plume.EmissionDirection, plume.SpreadAngle = Enum.NormalId.Top, Vector2.new(12, 12)
	plume.Rotation, plume.RotSpeed = NumberRange.new(0, 360), NumberRange.new(-22, 22)
	plume.LockedToPart, plume.VelocityInheritance = false, 0
	plume.Acceleration, plume.Drag = Vector3.new(0, Profile.plume.rise, 0), 0.45
	plume.LightEmission, plume.LightInfluence, plume.ZOffset = 0.15, 0.12, 0
	plume.Rate, plume.Enabled = if MOBILE then Profile.plume.mobileRate else Profile.plume.rate, false
	table.insert(state.emitters, {item = plume, rate = plume.Rate})
	return state
end
local function bladeOffset(state, fraction)
	local previous, previousOffset = 0, Vector3.zero
	for _, marker in state.markers do
		if fraction <= marker.fraction then
			return previousOffset:Lerp(marker.offset, (fraction - previous) / (marker.fraction - previous))
		end
		previous, previousOffset = marker.fraction, marker.offset
	end
	return previousOffset:Lerp(Vector3.zero, math.clamp((fraction - previous) / (1 - previous), 0, 1))
end
function Void.update(state, dt: number, visible: boolean, clear: boolean)
	if not visible then state.head = nil; return end
	local a, b = state.base.WorldPosition, state.tip.WorldPosition
	local axis = b - a
	local length = axis.Magnitude
	if length < 0.05 then
		for _, ray in state.beams do ray.Enabled = false end
		for _, entry in state.emitters do entry.item.Enabled = false end
		state.head = nil
		return
	end
	-- Above the tip the smoke floats upward, even during a horizontal cut.
	-- Only the free upper end lags; the envelope stays connected to the blade.
	local rise = (Vector3.yAxis * 0.80 + axis.Unit * 0.20).Unit
	local goal = b + rise * (length * Profile.lengthAbove)
	if clear or not state.head then state.head = goal end
	state.head = state.head:Lerp(goal, 1 - math.exp(-10 * math.clamp(dt, 0, 0.1)))
	if (state.head - goal).Magnitude > length * 0.35 then state.head = goal end
	local width = math.clamp(length * Profile.widthRatio, Profile.widthMin, Profile.widthMax)
	local cumulative = 0
	for i, node in state.nodes do
		local f = node.fraction
		local position = if f <= 1 then a:Lerp(b, f) + state.primary.CFrame:VectorToWorldSpace(bladeOffset(state, f))
			else b:Lerp(state.head, (f - 1) / Profile.lengthAbove)
		local bend = math.sin(f * math.pi / (1 + Profile.lengthAbove))
		position += state.primary.CFrame.RightVector * (math.sin(state.time * 1.7 - f * 5 + state.phase) * width * 0.065 * bend)
			+ state.primary.CFrame.UpVector * (math.sin(state.time * 2.3 + f * 8 + state.phase) * width * 0.045 * bend)
		node.at.WorldPosition = position
		node.width = width * Profile.widthAt(f, state.time, state.phase)
		if i > 1 then cumulative += (position - state.nodes[i - 1].at.WorldPosition).Magnitude end
		node.distance = cumulative
	end
	for _, segment in state.segments do
		local from, to, layer = state.nodes[segment.index], state.nodes[segment.index + 1], segment.layer
		segment.ray.Width0, segment.ray.Width1 = from.width * layer.width, to.width * layer.width
		-- Texture coordinates continue across joints: no disconnected smoke balls.
		segment.ray:SetTextureOffset((from.distance / Profile.textureLength - state.time * Profile.flow + layer.offset) % 1)
	end
	state.plumeAt.WorldCFrame = CFrame.new(b + rise * (length * 0.05))
end
return Void

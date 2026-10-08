-- Smooth continuous smoke: ONE cubic ribbon per side, instead of independent
-- camera-facing sections whose corners could overlap as visible triangles.
local Input = game:GetService("UserInputService")
local Profile = require(script.Parent.VoidAuraProfile)
local Smoke = {}
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
function Smoke.supports(id: string): boolean
	return id == "Void" or id == "Fusion"
end
function Smoke.create(model: Model, base: Attachment, tip: Attachment, seed: number, identity: string?)
	local id = identity or "Void"
	local state = {
		kind = id .. "Shroud", shroud = true, id = id, primary = model.PrimaryPart, base = base, tip = tip,
		owned = {}, beams = {}, emitters = {}, layers = {},
		time = 0, phase = seed * 1.73, visible = false, disposed = false,
	}
	state.folder = Instance.new("Folder")
	state.folder.Name, state.folder.Parent = id .. "BladeShroud", model
	local a, b = state.primary.CFrame:PointToObjectSpace(base.WorldPosition), state.primary.CFrame:PointToObjectSpace(tip.WorldPosition)
	local axis = b - a
	local direction = if axis.Magnitude > 0.05 then axis.Unit else -Vector3.zAxis
	for _, data in Profile.layersFor(id) do
		local offset, count = Vector3.zero, 0
		for i, fraction in FRACTIONS do
			local marker = model:FindFirstChild("Aura" .. data.marker .. i, true)
			if marker and marker:IsA("Attachment") then
				local delta = state.primary.CFrame:PointToObjectSpace(marker.WorldPosition) - a:Lerp(b, fraction)
				delta -= direction * delta:Dot(direction)
				offset += delta; count += 1
			end
		end
		offset = if count > 0 then offset / count else Vector3.new(0, data.side, 0)
		local from, to = anchor(state, data.name .. "Base"), anchor(state, data.name .. "Head")
		local ray = Instance.new("Beam")
		ray.Name, ray.Parent = data.name, state.folder
		ray.Attachment0, ray.Attachment1 = from, to
		-- A single elongated cloud; Wrap would repeat circular puffs along it.
		ray.Texture, ray.TextureMode, ray.TextureSpeed = TEXTURE, Enum.TextureMode.Stretch, 0
		ray.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(table.unpack(data.first))),
			ColorSequenceKeypoint.new(0.48, Color3.fromRGB(table.unpack(data.middle))),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(table.unpack(data.last))),
		})
		local opacity = {}
		for _, point in Profile.opacity do table.insert(opacity, {point[1], Profile.opacityAt(point[1], data.fade)}) end
		ray.Transparency = curve(opacity)
		-- Violet keeps its dark colour under bright scene lighting / bloom.
		ray.LightEmission, ray.LightInfluence, ray.FaceCamera = data.emission, 0, true
		ray.Segments = if MOBILE then Profile.mobileSegments else Profile.segments
		ray.Width0, ray.Width1, ray.Enabled, ray.ZOffset = 0, 0, false, 0
		table.insert(state.beams, ray)
		table.insert(state.layers, {ray = ray, from = from, to = to, data = data, offset = offset})
	end
	if id == "Fusion" then
		local hot, cold = state.layers[1], state.layers[2]
		local apart = cold.offset - hot.offset
		local side = if apart.Magnitude > 0.02 then apart.Unit else Vector3.yAxis
		local center = (hot.offset + cold.offset) * 0.5
		-- Keep two colours readable instead of stacking almost identical sheets
		-- into a grey cloud. Use the calibrated hot-to-cold axis of the real mesh.
		local width = math.clamp(axis.Magnitude * Profile.widthRatio, Profile.widthMin, Profile.widthMax)
		local halfGap = math.max(apart.Magnitude * 0.5, width * 0.35)
		hot.offset, cold.offset = center - side * halfGap, center + side * halfGap
	end
	-- Fusion deliberately has NO circular particles: just its two long sheets.
	if id == "Void" then
		state.plumeAt = anchor(state, "VoidDissolvingPlume")
		local plume = Instance.new("ParticleEmitter")
		plume.Name, plume.Parent, plume.Texture = "VoidRisingSmoke", state.plumeAt, TEXTURE
		plume.Color = ColorSequence.new(Color3.fromRGB(table.unpack(Profile.plume.first)), Color3.fromRGB(table.unpack(Profile.plume.last)))
		plume.Lifetime, plume.Speed = NumberRange.new(table.unpack(Profile.plume.lifetime)), NumberRange.new(table.unpack(Profile.plume.speed))
		plume.Size, plume.Transparency = curve(Profile.plume.size), curve(Profile.plume.transparency)
		plume.Squash = curve({ {0, -0.5}, {0.65, -0.3}, {1, 0} })
		plume.EmissionDirection, plume.SpreadAngle = Enum.NormalId.Top, Vector2.new(12, 12)
		plume.Rotation, plume.RotSpeed = NumberRange.new(0, 360), NumberRange.new(-22, 22)
		plume.LockedToPart, plume.VelocityInheritance = false, 0
		plume.Acceleration, plume.Drag = Vector3.new(0, Profile.plume.rise, 0), 0.45
		plume.LightEmission, plume.LightInfluence, plume.ZOffset = Profile.plume.emission, 0, 0
		plume.Rate, plume.Enabled = if MOBILE then Profile.plume.mobileRate else Profile.plume.rate, false
		table.insert(state.emitters, {item = plume, rate = plume.Rate})
	end
	return state
end
local function tangentFrame(position, tangent)
	local right = tangent.Unit
	local reference = if math.abs(right:Dot(Vector3.yAxis)) > 0.92 then Vector3.xAxis else Vector3.yAxis
	local up = (reference - right * reference:Dot(right)).Unit
	return CFrame.fromMatrix(position, right, up, right:Cross(up))
end
function Smoke.update(state, dt: number, visible: boolean, clear: boolean)
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
		* Profile.widthAt(state.time, state.phase)
	local wave = state.primary.CFrame.RightVector * (math.sin(state.time * 1.7 + state.phase) * 0.07)
		+ state.primary.CFrame.UpVector * (math.sin(state.time * 2.3 + state.phase) * 0.05)
	for _, layer in state.layers do
		local offset = state.primary.CFrame:VectorToWorldSpace(layer.offset)
		local from, to = a + offset * 0.55, state.head + offset * 0.30
		layer.from.WorldCFrame = tangentFrame(from, axis.Unit + offset / length + wave)
		layer.to.WorldCFrame = tangentFrame(to, rise - wave * 0.5)
		layer.ray.CurveSize0, layer.ray.CurveSize1 = length * Profile.curveStart, length * Profile.curveEnd
		layer.ray.Width0, layer.ray.Width1 = width * layer.data.width, width * layer.data.width * Profile.endWidth
		-- Gentle texture drift without tiling or a resetting line of round clouds.
		layer.ray:SetTextureOffset(0.10 + math.sin(state.time * 1.4 + state.phase) * 0.025)
	end
	if state.plumeAt then state.plumeAt.WorldCFrame = CFrame.new(b + rise * (length * 0.05)) end
end
return Smoke

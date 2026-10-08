-- HyenaFang is ONE weapon, with both palms locked to two points of ONE handle.
-- Solve after the torso animation, before physics. Never teleport/stretch a limb
-- or independently blend its arms (which would let one hand leave the handle).
local Path = require(script.Parent.TwoHandSwordPath)
local Motion = {}

local function basis(direction: Vector3, axis: Vector3): CFrame
	local y = -direction.Unit
	local z = axis:Cross(y).Unit
	return CFrame.fromMatrix(Vector3.zero, y:Cross(z).Unit, y, z)
end
local function bind(character: Model, findJoint, name: string, parent: string, child: string)
	local link = findJoint(character, child, name)
	if not link then return nil end
	if link:IsA("Motor6D") then
		if not link.Part0 or not link.Part1 then return nil end
		return { link = link, c0 = link.C0, c1 = link.C1, part0 = link.Part0, part1 = link.Part1 }
	end
	-- R15 AnimationConstraint rigs retain the same named rig attachments.
	-- Their local bind frames, not the already-animated limb positions, are used.
	local a, b = character:FindFirstChild(parent), character:FindFirstChild(child)
	local a0 = a and a:FindFirstChild(name .. "RigAttachment")
	local a1 = b and b:FindFirstChild(name .. "RigAttachment")
	if not a0 or not a1 or not a0:IsA("Attachment") or not a1:IsA("Attachment") then return nil end
	return { link = link, c0 = a0.CFrame, c1 = a1.CFrame, part0 = a, part1 = b }
end
local function bindings(character: Model, findJoint)
	local root = bind(character, findJoint, "Root", "HumanoidRootPart", "LowerTorso")
	local waist = bind(character, findJoint, "Waist", "LowerTorso", "UpperTorso")
	if not root or not waist then return nil end
	local arms = {}
	for _, side in { "Right", "Left" } do
		local shoulder = bind(character, findJoint, side .. "Shoulder", "UpperTorso", side .. "UpperArm")
		local elbow = bind(character, findJoint, side .. "Elbow", side .. "UpperArm", side .. "LowerArm")
		local wrist = bind(character, findJoint, side .. "Wrist", side .. "LowerArm", side .. "Hand")
		if not shoulder or not elbow or not wrist then return nil end
		local hand = wrist.part1
		local socket = hand:FindFirstChild(side .. "GripAttachment")
		local point = if socket and socket:IsA("Attachment") then socket.Position else Vector3.new(0, -0.25, 0)
		local segment1 = (shoulder.c1:Inverse() * elbow.c0).Position
		local segment2 = (elbow.c1:Inverse() * wrist.c0).Position
		if segment1.Magnitude < 0.001 or segment2.Magnitude < 0.001 then return nil end
		arms[side] = { shoulder = shoulder, elbow = elbow, wrist = wrist, point = point,
			segment1 = segment1, segment2 = segment2, l1 = segment1.Magnitude, l2 = segment2.Magnitude }
	end
	return { root = root, waist = waist, arms = arms }
end
function Motion.supported(character: Model, findJoint): boolean
	return bindings(character, findJoint) ~= nil
end

-- Exposed pure solver for full FK tests. Targets share one rigid weapon frame.
function Motion.solve(torso: CFrame, weapon: CFrame, arms, holds)
	local position, rotation = weapon.Position, weapon.Rotation
	for side, arm in arms do
		arm.frame = torso * arm.shoulder.c0
		arm.offset = holds[side] * CFrame.new(-arm.point) * arm.wrist.c1
	end
	-- Fit the entire handle into the intersection of the two reach spheres.
	-- This supports different R15 body scales without sliding either palm.
	for _ = 1, 32 do
		for _, side in { "Right", "Left" } do
			local arm = arms[side]
			local delta = position + rotation:VectorToWorldSpace(arm.offset.Position) - arm.frame.Position
			local limit = arm.l1 + arm.l2 - 0.003
			if delta.Magnitude > limit then position += delta.Unit * (limit - delta.Magnitude) end
		end
	end
	weapon = CFrame.new(position) * rotation
	local result = {}
	for _, side in { "Right", "Left" } do
		local arm = arms[side]
		local hand = weapon * holds[side] * CFrame.new(-arm.point)
		local wristAt = (hand * arm.wrist.c1).Position
		local shoulderAt = arm.frame.Position
		local delta = wristAt - shoulderAt
		local distance = delta.Magnitude
		if distance < math.abs(arm.l1 - arm.l2) + 0.0001 or distance > arm.l1 + arm.l2 then return nil end
		local down = delta.Unit
		local preferred = torso:VectorToWorldSpace(Vector3.new(if side == "Right" then 1 else -1, -0.35, 0.15))
		local bend = preferred - down * preferred:Dot(down)
		if bend.Magnitude < 0.001 then bend = down:Cross(torso.LookVector) end
		bend = bend.Unit
		local along = (arm.l1*arm.l1 - arm.l2*arm.l2 + distance*distance) / (2*distance)
		local height = math.sqrt(math.max(0, arm.l1*arm.l1 - along*along))
		local elbowAt = shoulderAt + down * along + bend * height
		local axis = down:Cross(bend).Unit
		local restUpper = basis(arm.segment1, arm.segment1.Unit:Cross(Vector3.new(0, 0, -1)).Unit)
		local restLower = basis(arm.segment2, arm.segment2.Unit:Cross(Vector3.new(0, 0, -1)).Unit)
		local upperRotation = basis(elbowAt - shoulderAt, axis) * restUpper:Inverse()
		local lowerRotation = basis(wristAt - elbowAt, axis) * restLower:Inverse()
		local shoulder = (arm.frame:Inverse() * upperRotation * arm.shoulder.c1).Rotation
		local upper = arm.frame * shoulder * arm.shoulder.c1:Inverse()
		local elbow = ((upper * arm.elbow.c0):Inverse() * lowerRotation * arm.elbow.c1).Rotation
		local lower = upper * arm.elbow.c0 * elbow * arm.elbow.c1:Inverse()
		local wrist = ((lower * arm.wrist.c0):Inverse() * hand * arm.wrist.c1).Rotation
		result[side .. "Shoulder"], result[side .. "Elbow"], result[side .. "Wrist"] = shoulder, elbow, wrist
	end
	return result, weapon
end
function Motion.pose(character: Model, findJoint, sword: Model, variant: string, elapsed: number)
	local rig = bindings(character, findJoint)
	local primary = sword.PrimaryPart
	local right = primary and primary:FindFirstChild("RightHold")
	local left = primary and primary:FindFirstChild("LeftHold")
	if not rig or not right or not left or not right:IsA("Attachment") or not left:IsA("Attachment") then return nil end
	local root, waist = rig.root, rig.waist
	local base = root.part0.CFrame * root.c0 * root.c1:Inverse()
	local lower = root.part0.CFrame * root.c0 * root.link.Transform * root.c1:Inverse()
	local torso = lower * waist.c0 * waist.link.Transform * waist.c1:Inverse()
	local target = Path.sample(variant, elapsed)
	local heightScale = (waist.c0 * waist.c1:Inverse()).Position.Magnitude / 0.91
	local weapon = base * (CFrame.new(target.Position * heightScale) * target.Rotation)
	return Motion.solve(torso, weapon, rig.arms, { Right = right.CFrame, Left = left.CFrame })
end
return Motion

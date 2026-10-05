-- Animations locales des vrais rigs : os skinnés et articulations Motor6D conservés.
-- Aucune animation distante, aucun script de PNJ, aucun besoin de publier un ID d'animation.
local PetRig = {}

local function readClip(sequence: KeyframeSequence?, bones)
	if not sequence then return nil end
	local frames = sequence:GetKeyframes()
	table.sort(frames, function(a, b) return a.Time < b.Time end)
	if #frames < 2 or frames[#frames].Time <= 0 then return nil end
	local tracks = {}
	for _, frame in frames do
		for _, pose in frame:GetDescendants() do
			if pose:IsA("Pose") and pose.Weight > 0 and bones[pose.Name] then
				local track = tracks[pose.Name] or {}
				tracks[pose.Name] = track
				table.insert(track, { time = frame.Time, cf = CFrame.identity:Lerp(pose.CFrame, pose.Weight) })
			end
		end
	end
	return { duration = frames[#frames].Time, tracks = tracks }
end

local function sample(track, t)
	if t <= track[1].time then return track[1].cf end
	for i = 2, #track do
		local previous, nextFrame = track[i - 1], track[i]
		if t <= nextFrame.time then
			local span = nextFrame.time - previous.time
			return previous.cf:Lerp(nextFrame.cf, if span > 0 then (t - previous.time) / span else 1)
		end
	end
	return track[#track].cf
end

function PetRig.bind(name: string, model: Model)
	local bones, rest, joints = {}, {}, {}
	local origin = model:GetPivot()
	for _, child in model:GetDescendants() do
		if child:IsA("Bone") then
			bones[child.Name] = child
			rest[child] = child.Transform
		elseif child:IsA("Motor6D") or child:IsA("Weld") then
			if child.Part0 and child.Part1 then table.insert(joints, child) end
		end
	end
	if next(bones) == nil and #joints == 0 then return nil end
	local root = model:FindFirstChild("RigRoot", true) or model:FindFirstChild("HumanoidRootPart", true)
	local ordered, visited = {}, {}
	if root then
		visited[root] = true
		-- Parcours des vraies liaisons ; les décorations soudées suivent leur membre.
		for _ = 1, #joints do
			local progress = false
			for _, joint in joints do
				if visited[joint.Part0] and not visited[joint.Part1] then
					visited[joint.Part1] = true
					table.insert(ordered, { joint = joint, reverse = false })
					progress = true
				elseif joint:IsA("Weld") and visited[joint.Part1] and not visited[joint.Part0] then
					visited[joint.Part0] = true
					table.insert(ordered, { joint = joint, reverse = true })
					progress = true
				end
			end
			if not progress then break end
		end
	end
	local axes = {}
	for boneName, bone in bones do
		axes[boneName] = {
			pitch = bone.WorldCFrame:VectorToObjectSpace(origin.RightVector),
			yaw = bone.WorldCFrame:VectorToObjectSpace(origin.UpVector),
			flap = bone.WorldCFrame:VectorToObjectSpace(origin.LookVector),
		}
	end
	local sequences = {}
	for _, child in model:GetDescendants() do
		if child:IsA("KeyframeSequence") then sequences[child.Name] = child end
	end
	return { name = name, model = model, bones = bones, rest = rest, axes = axes, joints = ordered,
		walk = readClip(sequences.Walk, bones), idle = readClip(sequences.Idle, bones), blend = 0 }
end

local function boneTurn(rig, name, axis, angle)
	local bone = rig.bones[name]
	if bone then bone.Transform = rig.rest[bone] * CFrame.fromAxisAngle(rig.axes[name][axis], angle) end
end

function PetRig.step(rig, t: number, moving: boolean, dt: number)
	if not rig then return end
	local desired = if moving then 1 else 0
	rig.blend += (desired - rig.blend) * (1 - math.exp(-10 * dt))
	local active = rig.blend
	if rig.name == "Rabbit" then
		for name, bone in rig.bones do
			local idleTrack = rig.idle and rig.idle.tracks[name]
			local walkTrack = rig.walk and rig.walk.tracks[name]
			local idle = if idleTrack then sample(idleTrack, t % rig.idle.duration) else rig.rest[bone]
			local walk = if walkTrack then sample(walkTrack, t % rig.walk.duration) else idle
			-- ScaleTo adapte les os mais pas les KeyframeSequence : adapter leurs déplacements aussi.
			local pose = idle:Lerp(walk, active)
			bone.Transform = CFrame.new(pose.Position * rig.model:GetScale()) * pose.Rotation
		end
	elseif rig.name == "Dragon" then
		local flap = math.sin(t * 5.8) * 0.48
		-- Les suffixes viennent du squelette livré, pas d'un rig humanoïde inventé.
		for name in rig.bones do
			if string.match(name, "^l_shoulder%.") then boneTurn(rig, name, "flap", flap) end
			if string.match(name, "^r_shoulder%.") then boneTurn(rig, name, "flap", -flap) end
			if string.match(name, "^[lr]_forearm%.") then boneTurn(rig, name, "flap", flap * 0.15 * (if string.sub(name, 1, 1) == "l" then 1 else -1)) end
			local tail = string.match(name, "^tail_(%d+)%.")
			if tail then boneTurn(rig, name, "yaw", math.sin(t * 2.1 - tonumber(tail) * 0.25) * 0.025) end
			local neck = string.match(name, "^neck_(%d+)%.")
			if neck then boneTurn(rig, name, "pitch", math.sin(t * 2.1 - tonumber(neck) * 0.15) * 0.007) end
		end
	end
	local pivot = rig.model:GetPivot()
	for _, item in rig.joints do
		local joint = item.joint
		local transform = CFrame.identity
		if joint:IsA("Motor6D") then
			local name = joint.Name
			local angle, worldAxis = 0, pivot.RightVector
			local side = if string.match(name, "[12]$") then (if string.sub(name, -1) == "1" then 1 else -1) else (if string.sub(name, -1) == "L" then 1 else -1)
			if rig.name == "Golem" then
				local swing = math.sin(t * 7) * active
				if string.match(name, "^UpperLeg") then angle = swing * side * 0.42
				elseif string.match(name, "^LowerLeg") then angle = math.max(0, -swing * side) * 0.35
				elseif string.match(name, "^UpperArm") then angle = -swing * side * 0.26
				elseif string.match(name, "^LowerArm") then angle = math.abs(swing) * 0.09
				elseif name == "Head" then angle = math.sin(t * 1.7) * 0.04; worldAxis = pivot.UpVector end
			elseif rig.name == "Owl" then
				if string.match(name, "^Wing") then angle = side * math.sin(t * 7) * 0.65; worldAxis = pivot.LookVector
				elseif name == "Head" then angle = math.sin(t * 1.5) * 0.14; worldAxis = pivot.UpVector
				elseif string.match(name, "^Foot") then angle = 0.3 + math.sin(t * 7) * 0.08 end
			elseif rig.name == "Rock" then
				if string.match(name, "^Hand") then angle = side * (0.18 + math.sin(t * 6 + side) * 0.24); worldAxis = pivot.LookVector
				elseif string.match(name, "^Foot") then angle = math.sin(t * 6) * side * 0.22
				elseif name == "Core" then angle = math.sin(t * 3) * 0.06; worldAxis = pivot.LookVector end
			end
			local localAxis = joint.C0:VectorToObjectSpace(joint.Part0.CFrame:VectorToObjectSpace(worldAxis))
			transform = CFrame.fromAxisAngle(localAxis, angle)
			joint.Transform = transform
		end
		-- Pièces ancrées = pas de simulation physique par compagnon. Résolution des Motor6D/Weld originaux.
		if item.reverse then
			joint.Part0.CFrame = joint.Part1.CFrame * joint.C1 * joint.C0:Inverse()
		else
			joint.Part1.CFrame = joint.Part0.CFrame * joint.C0 * transform * joint.C1:Inverse()
		end
	end
end

return PetRig

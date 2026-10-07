-- Animation autonome des six modèles. Aucun ID distant, aucun accès aux données du jeu.
-- Usage client : bind(model), puis step(rig, time, "Walk" ou "Idle") après model:PivotTo().
-- (Copie de assets/collections/*/StarterAnimator.luau, avec un réglage en plus pour le jeu : `gain` grossit les
-- rotations du clip. Les clips de marche livrés ne tournent les pattes que de 9 à 19 degrés : de loin, l'animal
-- avait l'air de glisser.)
local StarterAnimator = {}

local function clip(sequence)
	local frames = sequence:GetKeyframes()
	table.sort(frames, function(a, b) return a.Time < b.Time end)
	local tracks = {}
	for _, frame in frames do
		for _, pose in frame:GetDescendants() do
			if pose:IsA("Pose") then
				local track = tracks[pose.Name] or {}
				tracks[pose.Name] = track
				table.insert(track, { t = frame.Time, cf = pose.CFrame })
			end
		end
	end
	assert(#frames >= 2 and frames[#frames].Time > 0, "Clip vide")
	return { duration = frames[#frames].Time, tracks = tracks }
end

function StarterAnimator.bind(model: Model)
	local root = model:FindFirstChild("RigRoot")
	assert(root and root:IsA("BasePart"), "RigRoot absent")
	local all, ordered, visited, clips = {}, {}, { [root] = true }, {}
	for _, child in model:GetDescendants() do
		if child:IsA("Motor6D") or child:IsA("Weld") then
			assert(child.Part0 and child.Part1, "Liaison cassée")
			table.insert(all, child)
		elseif child:IsA("KeyframeSequence") then
			clips[child.Name] = clip(child)
		end
	end
	for _ = 1, #all do
		local progress = false
		for _, joint in all do
			if visited[joint.Part0] and not visited[joint.Part1] then
				visited[joint.Part1] = true
				table.insert(ordered, joint)
				progress = true
			end
		end
		if not progress then break end
	end
	for _, child in model:GetDescendants() do
		if child:IsA("BasePart") then assert(visited[child], "Pièce non liée : " .. child.Name) end
	end
	assert(clips.Walk and clips.Idle, "Animations absentes")
	return { model = model, joints = ordered, clips = clips }
end

local function sample(track, t)
	if t <= track[1].t then return track[1].cf end
	for i = 2, #track do
		if t <= track[i].t then
			local a, b = track[i - 1], track[i]
			return a.cf:Lerp(b.cf, (t - a.t) / (b.t - a.t))
		end
	end
	return track[#track].cf
end

local MAX_ANGLE = math.rad(55)
function StarterAnimator.step(rig, time: number, mode: string?, gain: number?)
	local playing = rig.clips[mode or "Idle"] or rig.clips.Idle
	local t = time % playing.duration
	local scale = rig.model:GetScale()
	for _, joint in rig.joints do
		local transform = CFrame.identity
		if joint:IsA("Motor6D") then
			local track = playing.tracks[joint.Part1.Name]
			if track then
				local value = sample(track, t)
				local rotation = value.Rotation
				if gain and gain ~= 1 then
					local axis, angle = rotation:ToAxisAngle()
					rotation = CFrame.fromAxisAngle(axis, math.clamp(angle * gain, -MAX_ANGLE, MAX_ANGLE))
				end
				transform = CFrame.new(value.Position * scale) * rotation
			end
			joint.Transform = transform
		end
		-- Les pièces restent ancrées ; pas de simulation physique ni Humanoid requis.
		joint.Part1.CFrame = joint.Part0.CFrame * joint.C0 * transform * joint.C1:Inverse()
	end
end

return StarterAnimator

-- Separate preview/integration helper; existing StarterAnimator and game stay untouched.
-- bind(model); playAttack(rig, now); PivotTo(base); step(rig, now, "Idle"/"Walk").
local Timeline = require(script.Parent.AttackTimeline)
local CombatAnimator = {}

local function readClip(sequence)
	local frames = sequence:GetKeyframes()
	table.sort(frames, function(a, b) return a.Time < b.Time end)
	assert(#frames >= 2 and frames[#frames].Time > 0, "Clip vide")
	local tracks, impactTime = {}, nil
	for _, frame in frames do
		if frame.Name == "Impact" then
			assert(not impactTime, "Plusieurs impacts dans le clip")
			impactTime = frame.Time
		end
		for _, pose in frame:GetDescendants() do
			if pose:IsA("Pose") then
				local track = tracks[pose.Name] or {}
				tracks[pose.Name] = track
				table.insert(track, { t = frame.Time, cf = pose.CFrame })
			end
		end
	end
	return { duration = frames[#frames].Time, tracks = tracks, loop = sequence.Loop, impactTime = impactTime }
end

function CombatAnimator.bind(model: Model)
	local root = model:FindFirstChild("RigRoot")
	assert(root and root:IsA("BasePart"), "RigRoot absent")
	local all, ordered, visited, clips = {}, {}, { [root] = true }, {}
	for _, child in model:GetDescendants() do
		if child:IsA("Motor6D") or child:IsA("Weld") then
			assert(child.Part0 and child.Part1, "Liaison cassée")
			table.insert(all, child)
		elseif child:IsA("KeyframeSequence") then
			clips[child.Name] = readClip(child)
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
	assert(clips.Idle and clips.Walk and clips.Attack, "Clips Idle/Walk/Attack requis")
	assert(not clips.Attack.loop and clips.Attack.impactTime, "Attack doit être une lecture unique avec Impact")
	local box, size = model:GetBoundingBox()
	local restBottom = (root.CFrame:PointToObjectSpace(box.Position).Y - size.Y / 2) / model:GetScale()
	return { model = model, root = root, joints = ordered, clips = clips, restBottom = restBottom }
end

local function sample(track, time)
	if not track then return CFrame.identity end
	if time <= track[1].t then return track[1].cf end
	for i = 2, #track do
		local b, a = track[i], track[i - 1]
		if time <= b.t then return a.cf:Lerp(b.cf, (time - a.t) / (b.t - a.t)) end
	end
	return track[#track].cf
end

function CombatAnimator.playAttack(rig, now: number)
	local attack = rig.clips.Attack
	return Timeline.start(rig, now, attack.duration, attack.impactTime)
end

function CombatAnimator.cancelAttack(rig)
	Timeline.cancel(rig)
end

function CombatAnimator.step(rig, now: number, mode: string?)
	local base = if mode == "Walk" then rig.clips.Walk else rig.clips.Idle
	local baseTime = now % base.duration
	local elapsed, weight, impact, attacking = Timeline.sample(rig, now)
	local scale = rig.model:GetScale()
	for _, joint in rig.joints do
		local transform = CFrame.identity
		if joint:IsA("Motor6D") then
			local name = joint.Part1.Name
			local value = sample(base.tracks[name], baseTime)
			if elapsed and weight > 0 then
				value = value:Lerp(sample(rig.clips.Attack.tracks[name], elapsed), weight)
			end
			transform = CFrame.new(value.Position * scale) * value.Rotation
			joint.Transform = transform
		end
		joint.Part1.CFrame = joint.Part0.CFrame * joint.C0 * transform * joint.C1:Inverse()
	end
	-- Keep the lowest point above the binding stance, including blended frames.
	-- One native bounds query; no per-Part corner tables or terrain raycasts.
	local box, size = rig.model:GetBoundingBox()
	local bottom = rig.root.CFrame:PointToObjectSpace(box.Position).Y - size.Y / 2
	local lift = rig.restBottom * scale - bottom
	if lift > 0.000001 then
		local correction = CFrame.new(rig.root.CFrame.UpVector * lift)
		for _, joint in rig.joints do joint.Part1.CFrame = correction * joint.Part1.CFrame end
	end
	-- This is only a synchronization signal. No damage or economy logic here.
	return impact, attacking
end

return CombatAnimator

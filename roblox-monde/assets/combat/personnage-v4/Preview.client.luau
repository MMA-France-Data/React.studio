-- Isolated, non-published preview with the actual imported swords and game FX.
local Storage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Content = game:GetService("ContentProvider")
local Log = game:GetService("LogService")
local Animator = require(Storage.CombatAnimator)
local Swords = require(Storage.SwordVisuals)
local Grip = require(Storage.SwordGrip)
local Motion = require(Storage.CombatMotion)
local Dual = require(Storage.DualSwordMotion)
local Aura = require(Storage.SwordElementalAura)
local floor = Instance.new("Part")
floor.Name, floor.Anchored, floor.Size = "PreviewFloor", true, Vector3.new(50, .2, 40)
floor.Position, floor.Color = Vector3.new(0, -.1, 0), Color3.fromRGB(47, 52, 64)
floor.Material, floor.Parent = Enum.Material.Slate, workspace
local function label(part, text, offset)
	local gui = Instance.new("BillboardGui")
	gui.Size, gui.StudsOffsetWorldSpace, gui.AlwaysOnTop = UDim2.fromOffset(250, 35), offset, true
	gui.Parent = part
	local textLabel = Instance.new("TextLabel")
	textLabel.Size, textLabel.BackgroundTransparency = UDim2.fromScale(1, 1), 1
	textLabel.Font, textLabel.TextSize = Enum.Font.GothamBold, 19
	textLabel.TextColor3, textLabel.TextStrokeTransparency = Color3.new(1,1,1), .35
	textLabel.Text, textLabel.Parent = text, gui
end
local gui = Instance.new("ScreenGui")
gui.Name, gui.IgnoreGuiInset, gui.Parent = "LocalPreviewStatus", true, Players.LocalPlayer.PlayerGui
local status = Instance.new("TextLabel")
status.Position, status.Size = UDim2.fromOffset(15, 65), UDim2.new(1,-30,0,30)
status.BackgroundTransparency, status.TextXAlignment = 1, Enum.TextXAlignment.Left
status.TextColor3, status.TextStrokeTransparency = Color3.new(1,1,1), .3
status.TextSize, status.Font, status.Parent = 17, Enum.Font.GothamBold, gui
local errors, failedAssets = 0, 0
Log.MessageOut:Connect(function(_, kind) if kind == Enum.MessageType.MessageError then errors += 1 end end)
local displays = {}
local specs = { {4,"GLACE"}, {5,"FEU"}, {6,"FOUDRE DORÉE"}, {7,"FEU + GLACE"}, {8,"OMBRE VIOLETTE"} }
local upright = CFrame.fromMatrix(Vector3.zero, Vector3.new(0,0,-1), Vector3.xAxis, Vector3.new(0,-1,0))
for i, spec in specs do
	local sword = Swords.build(spec[1], workspace)
	sword:PivotTo(CFrame.new((i-(#specs+1)/2)*5, 1.8, 0) * upright)
	label(sword.PrimaryPart, spec[2], Vector3.new(0,5.8,0))
	table.insert(displays, sword)
end
task.spawn(function()
	local assets = {}
	for _, texture in Aura.textures do table.insert(assets, texture) end
	for _, item in Storage.SwordMeshes:GetDescendants() do
		if item:IsA("MeshPart") or item:IsA("SurfaceAppearance") then table.insert(assets, item) end
	end
	local ok, message = pcall(function()
		Content:PreloadAsync(assets, function(_, result)
			if result ~= Enum.AssetFetchStatus.Success then failedAssets += 1 end
		end)
	end)
	print("ELEMENTAL_PRELOAD", ok, failedAssets, message)
end)
local model = Storage.Models.R15Preview:Clone()
for _, item in model:GetChildren() do
	if item:IsA("Weld") and item.Part1 and string.match(item.Part1.Name,"^Weapon_") then item:Destroy() end
end
for _, item in model:GetChildren() do
	if item:IsA("BasePart") and string.match(item.Name,"^Weapon_") then item:Destroy() end
end
model.Parent = workspace
local base = CFrame.new(0,3.3,-20)
model:PivotTo(base)
local rig = Animator.bind(model)
local sword, leftSword, tier, attackIndex, attackAt, nextAttack = nil, nil, nil, 0, nil, 0
local POSE_KEYS = {
	LowerTorso = "Root", UpperTorso = "Waist", Head = "Neck",
	RightUpperArm = "RightShoulder", LeftUpperArm = "LeftShoulder",
	RightLowerArm = "RightElbow", LeftLowerArm = "LeftElbow",
	RightHand = "RightWrist", LeftHand = "LeftWrist",
	RightUpperLeg = "RightHip", LeftUpperLeg = "LeftHip",
	RightLowerLeg = "RightKnee", LeftLowerLeg = "LeftKnee",
	RightFoot = "RightAnkle", LeftFoot = "LeftAnkle",
}
local camera = workspace.CurrentCamera
camera.CameraType, camera.FieldOfView = Enum.CameraType.Scriptable, 42
local time = 0
RunService.PreRender:Connect(function(dt)
	time += dt
	local phase = time % (9 + #specs * 7)
	local auraView = phase < 9
	if auraView then
		camera.CFrame = CFrame.lookAt(Vector3.new(0,5.7,19), Vector3.new(0,4.2,0))
	else
		camera.CFrame = CFrame.lookAt(Vector3.new(9,10,-33), Vector3.new(0,3.1,-20))
	end
	for _, display in displays do Swords.update(display,dt,false) end
	local chosen = specs[math.clamp(math.floor((phase-9)/7)+1,1,#specs)][1]
	if tier ~= chosen then
		if sword then sword:Destroy() end
		if leftSword then leftSword:Destroy(); leftSword = nil end
		sword, tier = Swords.build(chosen,workspace), chosen
		if Swords.dual(chosen) then leftSword = Swords.build(chosen,workspace) end
	end
	local variant = Motion.variant(attackIndex + 1)
	if time >= nextAttack then
		attackIndex += 1
		rig.clips.Attack = rig.clips[if leftSword then Dual.sourceClip else Motion.variant(attackIndex)]
		if Animator.playAttack(rig,time) then attackAt = time end
		nextAttack = time + .72
	end
	variant = Motion.variant(attackIndex)
	model:PivotTo(base)
	Animator.step(rig,time,"Idle")
	local elapsed = if attackAt then time - attackAt else 1
	if leftSword then
		local pose = Dual.sample(Motion, variant, elapsed)
		local weight = if pose then Motion.weight(elapsed) else 0
		for _, link in rig.joints do
			local key = POSE_KEYS[link.Part1.Name]
			local stance = CFrame.identity
			if key == "RightShoulder" or key == "LeftShoulder" then
				stance = CFrame.Angles(math.rad(22), 0, math.rad(if key == "RightShoulder" then -8 else 8))
			elseif key == "RightElbow" or key == "LeftElbow" then stance = CFrame.Angles(math.rad(62), 0, 0)
			elseif key == "RightWrist" or key == "LeftWrist" then
				stance = CFrame.Angles(math.rad(-4), 0, math.rad(if key == "RightWrist" then -6 else 6))
			end
			local value = stance:Lerp(if pose and key then pose[key] or stance else stance, weight)
			link.Transform = value
			link.Part1.CFrame = link.Part0.CFrame * link.C0 * value * link.C1:Inverse()
		end
	end
	Grip.place(sword,model.RightHand)
	local cutting = attackAt ~= nil and elapsed < Motion.duration and Motion.trail(elapsed)
	Swords.update(sword,dt,cutting and (not leftSword or Dual.activeHand(variant) == "Right"))
	if leftSword then
		Grip.place(leftSword,model.LeftHand)
		Swords.update(leftSword,dt,cutting and Dual.activeHand(variant) == "Left")
	end
	status.Text = string.format("APERÇU LOCAL · %s · erreurs %d · assets non chargés %d",
		if auraView then "auras sur les vraies épées" else "deux balayages alternés", errors, failedAssets)
end)
print("ELEMENTAL_COMBAT_V4_READY")

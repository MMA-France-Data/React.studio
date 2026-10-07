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
local specs = { {4,"GLACE"}, {5,"FEU"}, {6,"FOUDRE DORÉE"} }
local upright = CFrame.fromMatrix(Vector3.zero, Vector3.new(0,0,-1), Vector3.xAxis, Vector3.new(0,-1,0))
for i, spec in specs do
	local sword = Swords.build(spec[1], workspace)
	sword:PivotTo(CFrame.new((i-2)*5, 1.8, 0) * upright)
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
local sword, tier, attackIndex, attackAt, nextAttack = nil, nil, 0, nil, 0
local camera = workspace.CurrentCamera
camera.CameraType, camera.FieldOfView = Enum.CameraType.Scriptable, 42
local time = 0
RunService.PreRender:Connect(function(dt)
	time += dt
	local phase = time % 30
	local auraView = phase < 9
	if auraView then
		camera.CFrame = CFrame.lookAt(Vector3.new(0,5.7,19), Vector3.new(0,4.2,0))
	else
		camera.CFrame = CFrame.lookAt(Vector3.new(9,10,-33), Vector3.new(0,3.1,-20))
	end
	for _, display in displays do Swords.update(display,dt,false) end
	local chosen = specs[math.clamp(math.floor((phase-9)/7)+1,1,3)][1]
	if tier ~= chosen then
		if sword then sword:Destroy() end
		sword, tier = Swords.build(chosen,workspace), chosen
	end
	if time >= nextAttack then
		attackIndex += 1
		rig.clips.Attack = rig.clips[Motion.variant(attackIndex)]
		if Animator.playAttack(rig,time) then attackAt = time end
		nextAttack = time + .72
	end
	model:PivotTo(base)
	Animator.step(rig,time,"Idle")
	Grip.place(sword,model.RightHand)
	Swords.update(sword,dt,attackAt ~= nil and Motion.trail(time-attackAt))
	status.Text = string.format("APERÇU LOCAL · %s · erreurs %d · assets non chargés %d",
		if auraView then "auras sur les vraies épées" else "deux balayages alternés", errors, failedAssets)
end)
print("ELEMENTAL_COMBAT_V4_READY")

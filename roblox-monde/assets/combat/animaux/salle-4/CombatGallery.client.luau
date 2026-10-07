-- Independent local showcase; never installed into the game's client by this delivery.
local Storage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Animator = require(Storage.ActionAnimator)
local ids = { "Boar", "Ram", "Deer", "Lynx", "Wolf", "Bear" }
local labels = { "Sanglier", "Bélier", "Cerf", "Lynx", "Loup", "Ours brun ultra-rare" }
local entries = {}
local floor = Instance.new("Part")
floor.Name = "CombatPreviewFloor"
floor.Anchored = true
floor.Size = Vector3.new(40, 0.2, 30)
floor.CFrame = CFrame.new(0, -0.1, 0)
floor.Material = Enum.Material.SmoothPlastic
floor.Color = Color3.fromRGB(211, 226, 218)
floor.Parent = workspace

for i, id in ids do
	local model = Storage.Models[id]:Clone()
	local _, size = model:GetBoundingBox()
	local base = CFrame.new((i - 1) % 3 * 4.7 - 4.7, size.Y / 2 + 0.12, if i <= 3 then -2.6 else 2.6)
	model:PivotTo(base)
	model.Parent = workspace
	local target = Instance.new("Part")
	target.Name = id .. "PreviewTarget"
	target.Size = Vector3.new(0.62, 0.62, 0.16)
	target.Anchored = true
	target.CanCollide = false
	target.CanTouch = false
	target.CanQuery = false
	target.Color = Color3.fromRGB(227, 111, 74)
	target.CFrame = CFrame.new(base.X, if id == "Turtle" then 0.65 else 1.3, base.Z - size.Z / 2 - 0.40)
	target.Parent = workspace
	local label = Instance.new("BillboardGui")
	label.Name = "CombatPreviewLabel"
	label.Size = UDim2.fromOffset(200, 28)
	label.StudsOffsetWorldSpace = Vector3.new(0, size.Y / 2 + 0.34, 0)
	label.AlwaysOnTop = true
	label.Parent = model.RigRoot
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextSize = 18
	text.TextColor3 = Color3.fromRGB(30, 51, 42)
	text.Text = labels[i]
	text.Parent = label
	table.insert(entries, { rig = Animator.bind(model), base = base, target = target, flash = 0 })
end

local camera = workspace.CurrentCamera
camera.CameraType = Enum.CameraType.Scriptable
camera.FieldOfView = 40
camera.CFrame = CFrame.lookAt(Vector3.new(9, 12, -22), Vector3.new(0, 1.2, 0))
local gui = Instance.new("ScreenGui")
gui.Name = "CombatPreviewControls"
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
local controls = Instance.new("Frame")
controls.Name = "Controls"
controls.AnchorPoint = Vector2.new(0.5, 1)
controls.Position = UDim2.new(0.5, 0, 1, -12)
controls.Size = UDim2.new(0.90, 0, 0, 48)
controls.BackgroundTransparency = 1
controls.Parent = gui
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Padding = UDim.new(0, 8)
layout.Parent = controls
local function button(text)
	local result = Instance.new("TextButton")
	result.Size = UDim2.new(0.22, 0, 1, 0)
	result.BackgroundColor3 = Color3.fromRGB(43, 87, 61)
	result.TextColor3 = Color3.new(1, 1, 1)
	result.Font = Enum.Font.GothamBold
	result.TextScaled = true
	result.Text = text
	result.Parent = controls
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = 19
	constraint.MinTextSize = 12
	constraint.Parent = result
	return result
end
local strike = button("Attaquer")
local biteButton = button("Mordre")
local auto = button("Auto : oui")
local modeButton = button("Repos / marche")
local time, nextAttack, autoPlay, mode = 0, 0.8, true, "Idle"
local autoBite = false
local function attackAll(action)
	for _, entry in entries do Animator.playAttack(entry.rig, time, action) end
end
strike.Activated:Connect(function() attackAll("Attack"); nextAttack = time + 3.1 end)
biteButton.Activated:Connect(function() attackAll("Bite"); nextAttack = time + 3.1 end)
auto.Activated:Connect(function()
	autoPlay = not autoPlay
	auto.Text = if autoPlay then "Auto : oui" else "Auto : non"
	nextAttack = time + 0.4
end)
modeButton.Activated:Connect(function() mode = if mode == "Idle" then "Walk" else "Idle" end)
RunService.RenderStepped:Connect(function(dt)
	time += dt
	if autoPlay and time >= nextAttack then
		for _, entry in entries do
			Animator.playAttack(entry.rig, time, if autoBite and entry.rig.clips.Bite then "Bite" else "Attack")
		end
		autoBite = not autoBite
		nextAttack = time + 3.1
	end
	for _, entry in entries do
		entry.rig.model:PivotTo(entry.base)
		local impact = Animator.step(entry.rig, time, mode)
		if impact then entry.flash = time + 0.14 end
		entry.target.Color = if time < entry.flash then Color3.new(1, 1, 1) else Color3.fromRGB(227, 111, 74)
	end
end)
print("SURVIVE_COMBAT_PREVIEW_READY", #entries)

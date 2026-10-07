-- Animation/FX test only. Grey test blades are NOT the selected Meshy swords.
local Storage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Animator = require(Storage.CombatAnimator)
local Effects = require(Storage.SwordEffects)
local Grip = require(Storage.SwordGrip)
local Palette = require(Storage.SwordPalette)
local Motion = require(Storage.CombatMotion)
local VFX = require(Storage.CombatVFX)
local entries, displays = {}, {}
local function label(part, text, y)
	local gui = Instance.new("BillboardGui")
	gui.Size, gui.StudsOffsetWorldSpace, gui.AlwaysOnTop = UDim2.fromOffset(270, 32), Vector3.new(0, y, 0), true
	gui.Parent = part
	local textLabel = Instance.new("TextLabel")
	textLabel.Size, textLabel.BackgroundTransparency = UDim2.fromScale(1, 1), 1
	textLabel.Font, textLabel.TextSize = Enum.Font.GothamBold, 16
	textLabel.TextColor3, textLabel.TextStrokeTransparency = Color3.new(1, 1, 1), 0.3
	textLabel.Text, textLabel.Parent = text, gui
end
local function testBlade(id)
	local model = Instance.new("Model")
	model.Name = "TestBlade_" .. id
	local function part(name, position, size, color)
		local p = Instance.new("Part")
		p.Name, p.CFrame, p.Size, p.Color = name, CFrame.new(position), size, color
		p.Material, p.Anchored, p.Massless = Enum.Material.Metal, true, true
		p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
		p.Parent = model
		return p
	end
	model.PrimaryPart = part("Grip", Vector3.zero, Vector3.new(0.17, 0.17, 0.65), Color3.fromRGB(65, 66, 77))
	part("Blade", Vector3.new(0, 0, -2.04), Vector3.new(0.11, 0.55, 2.78), Color3.fromRGB(211, 217, 226))
	part("Guard", Vector3.new(0, 0, -0.65), Vector3.new(0.25, 1.1, 0.12), Palette.color(id))
	for name, z in { TrailBase = -0.70, TrailTip = -3.43 } do
		local a = Instance.new("Attachment")
		a.Name, a.Position, a.Parent = name, Vector3.new(0, 0, z), model.PrimaryPart
	end
	model.Parent = workspace
	Effects.attach(model, id)
	return model
end
local floor = Instance.new("Part")
floor.Name, floor.Anchored, floor.Size = "PreviewFloor", true, Vector3.new(55, 0.2, 45)
floor.CFrame, floor.Color = CFrame.new(0, -0.1, 0), Color3.fromRGB(35, 42, 56)
floor.Parent = workspace
for i, variant in { "SlashRight", "SlashLeft" } do
	local model = Storage.Models.R15Preview:Clone()
	for _, item in model:GetChildren() do
		if item:IsA("Weld") and item.Part1 and string.match(item.Part1.Name, "^Weapon_") then item:Destroy() end
	end
	for _, item in model:GetChildren() do
		if item:IsA("BasePart") and string.match(item.Name, "^Weapon_") then item:Destroy() end
	end
	local base = CFrame.new((i - 1.5) * 13, 3.3, -4)
	model:PivotTo(base); model.Parent = workspace
	local rig = Animator.bind(model)
	rig.clips.Attack = rig.clips[variant]
	label(model.RigRoot, if i == 1 then "Gauche → droite · 224°" else "Droite → gauche · 224°", 3.4)
	table.insert(entries, { rig = rig, base = base, variant = variant,
		sword = testBlade(if i == 1 then "Storm" else "Flame"), strikeAt = nil })
end
local names = { "Fer", "Acier", "Or", "Glace", "Feu", "Foudre", "Arc-en-ciel" }
for i, id in Palette.order do
	local sword = testBlade(id)
	sword:PivotTo(CFrame.new((i - 4) * 4.4, 1, 8) * CFrame.Angles(math.pi / 2, 0, 0))
	label(sword.PrimaryPart, names[i] .. " · aura", 4.2)
	table.insert(displays, sword)
end
local camera = workspace.CurrentCamera
camera.CameraType, camera.FieldOfView = Enum.CameraType.Scriptable, 45
camera.CFrame = CFrame.lookAt(Vector3.new(13, 21, -36), Vector3.new(0, 2.5, 1))
local time, nextStrike = 0, 0.7
RunService.PreRender:Connect(function(dt)
	time += dt
	if time >= nextStrike then
		for _, entry in entries do
			if Animator.playAttack(entry.rig, time) then entry.strikeAt = time end
		end
		nextStrike = time + 1.1
	end
	for _, entry in entries do
		entry.rig.model:PivotTo(entry.base)
		local impact = Animator.step(entry.rig, time, "Idle")
		Grip.place(entry.sword, entry.rig.model.RightHand)
		Effects.update(entry.sword, dt, entry.strikeAt ~= nil and Motion.trail(time - entry.strikeAt))
		if impact then VFX.impact(entry.base.Position + Vector3.new(0, -3.2, -4.5), 1) end
	end
	for _, sword in displays do Effects.update(sword, dt, false) end
end)
print("WIDE_COMBAT_AND_SEVEN_AURAS_GALLERY_READY")

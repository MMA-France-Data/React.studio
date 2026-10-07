-- Standalone demonstration only. Not installed into the public MONDE game.
local Storage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Animator = require(Storage.CombatAnimator)
local VFX = require(Storage.CombatVFX)
local Swords = require(Storage.SwordVisuals)
local floor = Instance.new("Part")
floor.Name = "PreviewFloor"
floor.Anchored = true
floor.Size = Vector3.new(50, 0.2, 36)
floor.CFrame = CFrame.new(0, -0.1, 0)
floor.Color = Color3.fromRGB(242, 186, 123)
floor.Material = Enum.Material.SmoothPlastic
floor.Parent = workspace
local variants = { "SlashRight", "SlashLeft" }
local variantLabels = { SlashRight = "Gauche → droite", SlashLeft = "Droite → gauche" }
local entries = {}
local function label(part, text, offset)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(210, 32)
	gui.StudsOffsetWorldSpace = offset
	gui.AlwaysOnTop = true
	gui.Parent = part
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.BackgroundTransparency = 1
	textLabel.Font = Enum.Font.GothamBold
	textLabel.TextSize = 19
	textLabel.TextColor3 = Color3.fromRGB(38, 31, 42)
	textLabel.Text = text
	textLabel.Parent = gui
end
for i, variant in variants do
	local model = Storage.Models.R15Preview:Clone()
	for _, child in model:GetChildren() do
		if child:IsA("Weld") and child.Part1 and string.match(child.Part1.Name, "^Weapon_") then child:Destroy() end
	end
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and string.match(child.Name, "^Weapon_") then child:Destroy() end
	end
	local _, size = model:GetBoundingBox()
	local base = CFrame.new((i - (#variants + 1) / 2) * 12, size.Y / 2 + 0.05, -2)
	model:PivotTo(base)
	model.Parent = workspace
	local rig = Animator.bind(model)
	rig.clips.Attack = rig.clips[variant]
	label(model.RigRoot, variantLabels[variant], Vector3.new(0, 3.1, 0))
	table.insert(entries, { rig = rig, base = base, variant = variant, tier = i + 2, sword = Swords.build(i + 2, workspace), effectOffset = rig.root.CFrame:ToObjectSpace(model.LowerTorso.CFrame) })
end
local swordIds = { "Iron", "Steel", "Frost", "Flame", "Storm", "Prismatic" }
local swordLabels = { "Fer", "Acier", "Glace", "Feu", "Foudre", "Arc-en-ciel" }
for i, id in swordIds do
	local model = Storage.Models["Sword_" .. id]:Clone()
	model:PivotTo(CFrame.new((i - 3.5) * 4.1, 0.9, 8) * CFrame.Angles(math.pi / 2, 0, 0))
	model.Parent = workspace
	label(model.RigRoot, swordLabels[i], Vector3.new(0, 4.1, 0))
end
local camera = workspace.CurrentCamera
camera.CameraType = Enum.CameraType.Scriptable
camera.FieldOfView = 45
camera.CFrame = CFrame.lookAt(Vector3.new(12, 17, -31), Vector3.new(0, 2.5, 1))
local time, nextStrike = 0, 0.7
RunService.RenderStepped:Connect(function(dt)
	time += dt
	if time >= nextStrike then
		for _, entry in entries do
			if Animator.playAttack(entry.rig, time) then
				entry.vfxAt = time + 0.065
			end
		end
		nextStrike = time + 1.1
	end
	for _, entry in entries do
		entry.rig.model:PivotTo(entry.base)
		local impact = Animator.step(entry.rig, time, "Idle")
		entry.sword:PivotTo(entry.rig.model.RightHand.CFrame * CFrame.new(0, -0.25, 0))
		Swords.setSwing(entry.sword, entry.rig.attack ~= nil)
		if entry.vfxAt and time >= entry.vfxAt then
			VFX.slash(entry.rig.root.CFrame * entry.effectOffset, entry.tier, entry.variant)
			entry.vfxAt = nil
		end
		if impact then VFX.impact((entry.rig.root.CFrame * entry.effectOffset * CFrame.new(0, -2.5, -4)).Position, entry.tier) end
	end
end)
print("MONDE_PLAYER_COMBAT_PREVIEW_READY")

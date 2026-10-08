-- Standalone visual gallery; never modifies the live game.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local names = { "Hyena", "Buffalo", "Cheetah", "Rhino", "Elephant", "Lion" }
local labels = { "Hyène", "Buffle", "Guépard", "Rhinocéros", "Éléphant", "Lion royal" }
local chances = { "45 %", "30 %", "14 %", "7 %", "3,5 %", "0,5 %" }

local floor = Instance.new("Part")
floor.Name = "EggPreviewFloor"
floor.Anchored = true
floor.Size = Vector3.new(30, 0.2, 26)
floor.CFrame = CFrame.new(0, -0.1, 0)
floor.Color = Color3.fromRGB(233, 215, 177)
floor.Material = Enum.Material.SmoothPlastic
floor.Parent = workspace

for i, name in names do
	local model = ReplicatedStorage.Models:WaitForChild(name .. "Egg"):Clone()
	model:PivotTo(CFrame.new(((i - 1) % 3 - 1) * 3.8, 0, if i <= 3 then -2.1 else 2.1))
	model.Parent = workspace
	local label = Instance.new("BillboardGui")
	label.Name = "Label"
	label.Size = UDim2.fromOffset(180, 36)
	label.StudsOffsetWorldSpace = Vector3.new(0, 3.5, 0)
	label.AlwaysOnTop = true
	label.Parent = model.EggRoot
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = labels[i] .. " · " .. chances[i]
	text.TextColor3 = if i == 6 then Color3.fromRGB(124, 41, 177) else Color3.fromRGB(31, 48, 62)
	text.Font = Enum.Font.GothamBold
	text.TextSize = 20
	text.Parent = label
end
local camera = workspace.CurrentCamera
camera.CameraType = Enum.CameraType.Scriptable
camera.FieldOfView = 40
camera.CFrame = CFrame.lookAt(Vector3.new(9, 10.8, -18), Vector3.new(0, 1.1, 0))
local gui = Instance.new("ScreenGui")
gui.Name = "EggPreviewTitle"
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
local title = Instance.new("TextLabel")
title.Size = UDim2.new(0.9, 0, 0, 40)
title.Position = UDim2.new(0.05, 0, 0, 12)
title.BackgroundTransparency = 1
title.Text = "Salle 7 — savane : œufs sans nid"
title.TextColor3 = Color3.fromRGB(31, 48, 62)
title.Font = Enum.Font.GothamBold
title.TextSize = 24
title.Parent = gui
print("ROOM7_THEMED_EGG_PREVIEW_READY", #names)

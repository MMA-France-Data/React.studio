local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Animator = require(ReplicatedStorage.StarterAnimator)
local names = { "Squirrel", "Hedgehog", "Raccoon", "Skunk", "Beaver", "Badger" }
local labels = { "Écureuil", "Hérisson", "Raton laveur", "Moufette", "Castor", "Blaireau" }
local rigs = {}

local stage = Instance.new("Part")
stage.Name = "GalleryFloor"
stage.Anchored = true
stage.Size = Vector3.new(40, 0.2, 30)
stage.CFrame = CFrame.new(0, -0.12, 0)
stage.Color = Color3.fromRGB(216, 234, 222)
stage.Material = Enum.Material.SmoothPlastic
stage.Parent = workspace

for i, name in names do
	local model = ReplicatedStorage.Models[name]:Clone()
	local _, size = model:GetBoundingBox()
	local base = CFrame.new((i - 1) % 3 * 4 - 4, size.Y / 2 + 0.12, if i <= 3 then -2.3 else 2.3)
	model:PivotTo(base)
	model.Parent = workspace
	local rig = Animator.bind(model)
	table.insert(rigs, { rig = rig, base = base })
	local label = Instance.new("BillboardGui")
	label.Name = "Label"
	label.Size = UDim2.fromOffset(140, 28)
	label.StudsOffsetWorldSpace = Vector3.new(0, size.Y / 2 + 0.40, 0)
	label.AlwaysOnTop = true
	label.Parent = model.RigRoot
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = labels[i]
	text.Font = Enum.Font.GothamBold
	text.TextSize = 24
	text.TextColor3 = Color3.fromRGB(35, 60, 46)
	text.Parent = label
	print("STARTER_PET_BUILT", name, #rig.joints, size)
end

local camera = workspace.CurrentCamera
camera.CameraType = Enum.CameraType.Scriptable
camera.FieldOfView = 40
camera.CFrame = CFrame.lookAt(Vector3.new(10.0, 11.5, -19), Vector3.new(0, 1, 0))
local gui = Instance.new("ScreenGui")
gui.Name = "CollectionPreview"
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
local button = Instance.new("TextButton")
button.Size = UDim2.fromOffset(250, 46)
button.Position = UDim2.new(0.5, -125, 1, -62)
button.BackgroundColor3 = Color3.fromRGB(43, 87, 61)
button.TextColor3 = Color3.new(1, 1, 1)
button.Font = Enum.Font.GothamBold
button.TextSize = 18
button.Text = "Salle 2 : marche — toucher pour repos"
button.Parent = gui
local mode, time = "Walk", 0
button.Activated:Connect(function()
	mode = if mode == "Walk" then "Idle" else "Walk"
	button.Text = if mode == "Walk" then "Salle 2 : marche — toucher pour repos" else "Salle 2 : repos — toucher pour marche"
end)
RunService.RenderStepped:Connect(function(dt)
	time += dt
	for _, entry in rigs do
		entry.rig.model:PivotTo(entry.base)
		Animator.step(entry.rig, time, mode)
	end
end)
print("STARTER_COLLECTION_GALLERY_READY", #rigs)

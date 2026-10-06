-- Standalone local preview only. Never loaded by the SURVIVE game project.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local models = ReplicatedStorage:WaitForChild("Models")
local rooms = {
	{ "Rabbit", "Turtle", "Cat", "Dog", "Owl", "Fox" },
	{ "Hedgehog", "Squirrel", "Skunk", "Beaver", "Raccoon", "Badger" },
	{ "Duck", "Rooster", "Pig", "Sheep", "Goat", "Horse" },
	{ "Boar", "Ram", "Deer", "Lynx", "Wolf", "Bear" },
	{ "Capybara", "Toucan", "Monkey", "Anaconda", "Crocodile", "Jaguar" },
}
local labels = {
	{ "Lapin", "Tortue", "Chat", "Chien", "Chouette", "Renard" },
	{ "Hérisson", "Écureuil", "Moufette", "Castor", "Raton laveur", "Blaireau" },
	{ "Canard", "Coq", "Cochon", "Mouton", "Chèvre", "Cheval" },
	{ "Sanglier", "Bélier", "Cerf", "Lynx", "Loup", "Ours brun" },
	{ "Capybara", "Toucan", "Singe", "Anaconda", "Crocodile", "Jaguar" },
}
-- Reference labels only; this standalone gallery never rolls an egg or grants pets.
local referenceChances = { "45 %", "30 %", "14 %", "7 %", "3,5 %", "0,5 %" }
local stage = Instance.new("Part")
stage.Name = "EggPreviewFloor"
stage.Anchored = true
stage.Size = Vector3.new(36, 0.2, 26)
stage.CFrame = CFrame.new(0, -0.1, 0)
stage.Color = Color3.fromRGB(219, 230, 235)
stage.Material = Enum.Material.SmoothPlastic
stage.Parent = workspace
local display = Instance.new("Folder")
display.Name = "ThemedEggPreview"
display.Parent = workspace
local gui = Instance.new("ScreenGui")
gui.Name = "EggPreviewNavigation"
gui.ResetOnSpawn = false
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
local title = Instance.new("TextLabel")
title.AnchorPoint = Vector2.new(0.5, 0)
title.Size = UDim2.new(0.8, 0, 0, 40)
title.Position = UDim2.new(0.5, 0, 0, 12)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 24
title.TextColor3 = Color3.fromRGB(31, 48, 62)
title.Parent = gui
local room = 1
local function showRoom()
	display:ClearAllChildren()
	title.Text = "Œufs sans nid — salle " .. room .. " / 5"
	for i, name in rooms[room] do
		local model = models:WaitForChild(name .. "Egg"):Clone()
		model:PivotTo(CFrame.new(((i - 1) % 3 - 1) * 3.8, 0, if i <= 3 then -2.1 else 2.1))
		model.Parent = display
		local label = Instance.new("BillboardGui")
		label.Name = "Label"
		label.Size = UDim2.fromOffset(170, 34)
		label.StudsOffsetWorldSpace = Vector3.new(0, 3.5, 0)
		label.AlwaysOnTop = true
		label.Parent = model.EggRoot
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.GothamBold
		text.TextSize = 20
		text.TextColor3 = if i == 6 then Color3.fromRGB(124, 41, 177) else Color3.fromRGB(31, 48, 62)
		text.Text = labels[room][i] .. " · " .. referenceChances[i]
		text.Parent = label
	end
end
for i, delta in { -1, 1 } do
	local b = Instance.new("TextButton")
	b.Name = if delta < 0 then "PreviousRoom" else "NextRoom"
	b.AnchorPoint = Vector2.new(0.5, 1)
	b.Position = UDim2.new(if i == 1 then 0.3 else 0.7, 0, 1, -12)
	b.Size = UDim2.new(0.35, 0, 0, 44)
	b.BackgroundColor3 = Color3.fromRGB(46, 74, 88)
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 18
	b.Text = if delta < 0 then "< Salle précédente" else "Salle suivante >"
	b.Parent = gui
	b.Activated:Connect(function()
		room = (room - 1 + delta) % #rooms + 1
		showRoom()
	end)
end
local camera = workspace.CurrentCamera
camera.CameraType = Enum.CameraType.Scriptable
camera.FieldOfView = 40
camera.CFrame = CFrame.lookAt(Vector3.new(9, 10.8, -18), Vector3.new(0, 1.1, 0))
showRoom()
print("THEMED_EGG_PREVIEW_READY", 30)

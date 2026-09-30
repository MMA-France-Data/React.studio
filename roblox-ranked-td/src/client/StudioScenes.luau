-- Bouton « SCÈNES (Studio) » (colonne de gauche, à droite de « SONS (Studio) ») : pour t'enregistrer en jouant.
--   « DRAGON — vague 100 » / « BOSS DE GLACE — vague 40 » : ta parcelle remplie de 22 tours et la vague du boss
--       lancée tout de suite, ton personnage face à lui (serveur : src/server/Hub/StudioScenes.luau)
--   « JEU EN ANGLAIS » / « JEU EN FRANÇAIS » : Roblox n'accepte que des vidéos avec textes et son en anglais
--   « CACHER L'INTERFACE » : plus aucun bouton ni texte à l'écran ; touche H pour la remettre
-- Seulement dans Studio avec Config.STUDIO_SCENES = true, jamais dans le jeu publié ni pendant les tests automatiques.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local UI = require(script.Parent.UI)

local StudioScenes = {}

local player = Players.LocalPlayer

-- Après la scène : la caméra derrière ton personnage, tournée vers là où arrive le boss.
local function faceBoss()
	task.wait(0.4)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local forward = root.CFrame.LookVector
	local camera = workspace.CurrentCamera
	camera.CFrame = CFrame.lookAt(root.Position - forward * 14 + Vector3.new(0, 6, 0), root.Position + forward * 30)
end

-- Interface cachée pour enregistrer (écrans du jeu et de Roblox), remise avec la touche H.
local hidden = nil
local function setInterfaceHidden(hide: boolean)
	local playerGui = player:FindFirstChild("PlayerGui")
	if hide and not hidden and playerGui then
		hidden = {}
		for _, gui in playerGui:GetChildren() do
			if gui:IsA("ScreenGui") and gui.Enabled then
				gui.Enabled = false
				table.insert(hidden, gui)
			end
		end
		pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
		end)
	elseif not hide and hidden then
		for _, gui in hidden do
			if gui.Parent then
				gui.Enabled = true
			end
		end
		hidden = nil
		pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)
		end)
	end
end

function StudioScenes.start()
	if not RunService:IsStudio() or Config.STUDIO_SCENES ~= true then
		return -- jamais dans le jeu publié
	end
	if ReplicatedStorage:FindFirstChild("__AutoPlayTest") then
		return -- tests automatiques : leurs captures ne changent pas
	end
	local remote = ReplicatedStorage:WaitForChild("StudioScene", 15)
	if not remote then
		return
	end
	local gui = UI.screen("StudioScenes", 30)
	gui:SetAttribute("NoTranslate", true) -- outil Studio : jamais traduit en anglais (AutoTranslate.luau)
	local top = UI.LEFT_COLUMN_TOP + 5 * UI.LEFT_COLUMN_STEP
	local left = 16 + 180 + 8 + 160 + 8
	local button = UI.button({
		Name = "StudioScenesButton",
		Position = UDim2.new(0, left, 0, top),
		Size = UDim2.fromOffset(170, 46),
		BackgroundColor3 = UI.Colors.PanelLight,
		Text = "SCÈNES (Studio)",
		MaxTextSize = 18,
		Parent = gui,
	})

	local function isEnglish()
		return player:GetAttribute("Lang") == "en"
	end
	local choices = {
		{
			name = "dragon", color = Color3.fromRGB(150, 40, 40),
			text = function()
				return "🐉 DRAGON — vague 100"
			end,
			run = function()
				remote:FireServer("dragon")
				task.spawn(faceBoss)
			end,
		},
		{
			name = "glace", color = Color3.fromRGB(40, 110, 170),
			text = function()
				return "❄ BOSS DE GLACE — vague 40"
			end,
			run = function()
				remote:FireServer("glace")
				task.spawn(faceBoss)
			end,
		},
		{
			name = "langue", color = UI.Colors.Accent,
			text = function()
				return if isEnglish() then "🇫🇷 REMETTRE LE JEU EN FRANÇAIS" else "🇬🇧 JEU EN ANGLAIS (pour les vidéos)"
			end,
			run = function()
				remote:FireServer(if isEnglish() then "lang:fr" else "lang:en")
			end,
		},
		{
			name = "interface", color = UI.Colors.PanelLight,
			text = function()
				return "🎬 CACHER L'INTERFACE (touche H pour la remettre)"
			end,
			run = function()
				setInterfaceHidden(true)
			end,
		},
	}
	local panel = UI.new("Frame", {
		Name = "Choices",
		Position = UDim2.new(0, left, 0, top + 52),
		Size = UDim2.fromOffset(360, #choices * 54 + 8),
		BackgroundColor3 = UI.Colors.Panel,
		Visible = false,
		Parent = gui,
	}, {
		UI.corner(10),
		UI.stroke(UI.Colors.Gold, 1),
	})
	local options = {}
	for index, choice in choices do
		local option = UI.button({
			Name = "Scene_" .. choice.name,
			Position = UDim2.new(0, 8, 0, 8 + (index - 1) * 54),
			Size = UDim2.new(1, -16, 0, 46),
			BackgroundColor3 = choice.color,
			Text = choice.text(),
			MaxTextSize = 16,
			Parent = panel,
		})
		options[choice] = option
		option.Activated:Connect(function()
			panel.Visible = false
			choice.run()
		end)
	end
	local function refreshTexts()
		for choice, option in options do
			option.Text = choice.text()
		end
	end
	player:GetAttributeChangedSignal("Lang"):Connect(refreshTexts)
	button.Activated:Connect(function()
		refreshTexts()
		panel.Visible = not panel.Visible
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.H and hidden then
			setInterfaceHidden(false)
		end
	end)
end

return StudioScenes

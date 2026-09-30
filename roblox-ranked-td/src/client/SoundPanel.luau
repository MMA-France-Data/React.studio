-- Panneau des sons (Studio seulement) : le bouton « SONS (Studio) » (colonne de gauche, à droite de « GALERIE
-- (Studio) ») ouvre la liste de tous les sons du jeu (src/shared/Sounds.luau), rangés comme dans ce fichier :
-- « Jouer » fait écouter le son (en 2D, même quand le bouton « SON » est sur muet), avec son nom, son numéro (id)
-- et ses réglages. Après l'écoute, sa durée s'affiche, ou « ne se charge pas ! » (numéro faux, son privé...).
-- Pour changer un son : remplace son id dans Sounds.luau (voir la partie « Sons » du README).
-- Seulement dans Studio avec Config.STUDIO_SOUND_PANEL = true, jamais dans le jeu publié ni pendant les tests
-- automatiques (tools/studio-test).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Sounds = require(Shared.Sounds)
local SoundManager = require(script.Parent.SoundManager)
local UI = require(script.Parent.UI)

local SoundPanel = {}

local WINDOW_SIZE = Vector2.new(620, 520)
local ROW_HEIGHT = 40
local LOAD_TIMEOUT = 8 -- secondes pour charger un son écouté avant d'afficher « ne se charge pas ! »

-- Réglages d'un son, en court : « 3D, portée 70 • 4 à la fois • 1 toutes les 0,09 s ».
local function settingsText(def): string
	local parts = {}
	if def.music then
		table.insert(parts, "musique en boucle")
	elseif def.loop then
		table.insert(parts, `boucle 3D, portée {def.range}`)
	elseif def.range then
		table.insert(parts, `3D, portée {def.range}`)
	else
		table.insert(parts, "2D")
	end
	table.insert(parts, `volume {UI.decimal(def.volume)}`)
	if def.pitch and def.pitch ~= 1 then
		table.insert(parts, `hauteur {UI.decimal(def.pitch)}`)
	end
	if def.maxAtOnce then
		table.insert(parts, `{def.maxAtOnce} à la fois`)
	end
	if def.minInterval then
		table.insert(parts, `1 toutes les {UI.decimal(def.minInterval)} s`)
	end
	return table.concat(parts, " • ")
end

local function build(gui: ScreenGui)
	local window = UI.new("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(WINDOW_SIZE.X, WINDOW_SIZE.Y),
		BackgroundColor3 = UI.Colors.Panel,
		Visible = false,
		Parent = gui,
	}, { UI.corner(12), UI.padding(10), UI.stroke(UI.Colors.Gold, 1) })
	-- Plus petit sur un petit écran.
	local scale = UI.new("UIScale", { Parent = window })
	local function fit()
		local viewport = workspace.CurrentCamera.ViewportSize
		scale.Scale = math.min(1, (viewport.X - 20) / WINDOW_SIZE.X, (viewport.Y - 20) / WINDOW_SIZE.Y)
	end
	fit()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)

	UI.label({
		Size = UDim2.new(1, -170, 0, 30),
		Font = Enum.Font.GothamBlack,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "SONS DU JEU (Studio)",
		MaxTextSize = 22,
		Parent = window,
	})
	UI.label({
		Position = UDim2.new(0, 0, 0, 30),
		Size = UDim2.new(1, 0, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.Muted,
		Text = "Change un son : remplace son id dans src/shared/Sounds.luau (voir le README, partie « Sons »).",
		MaxTextSize = 13,
		Parent = window,
	})
	local stopButton = UI.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -40, 0, 0),
		Size = UDim2.fromOffset(110, 30),
		BackgroundColor3 = UI.Colors.Warning,
		Text = "Arrêter",
		MaxTextSize = 16,
		Parent = window,
	})
	stopButton:SetAttribute("NoClickSound", true)
	stopButton.Activated:Connect(SoundManager.stopPreview)
	local closeButton = UI.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = UI.Colors.PanelLight,
		Text = "X",
		MaxTextSize = 18,
		Parent = window,
	})
	closeButton.Activated:Connect(function()
		SoundManager.stopPreview()
		window.Visible = false
	end)

	local list = UI.new("ScrollingFrame", {
		Position = UDim2.new(0, 0, 0, 52),
		Size = UDim2.new(1, 0, 1, -52),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = window,
	}, {
		UI.new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	local order = 0
	for _, group in Sounds.GROUPS do
		order += 1
		UI.label({
			Size = UDim2.new(1, -12, 0, 24),
			LayoutOrder = order,
			Font = Enum.Font.GothamBlack,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = UI.Colors.Gold,
			Text = group.title,
			MaxTextSize = 17,
			Parent = list,
		})
		for _, name in group.slots do
			local def = Sounds.SLOTS[name]
			if not def then
				continue
			end
			order += 1
			local row = UI.new("Frame", {
				Size = UDim2.new(1, -12, 0, ROW_HEIGHT),
				LayoutOrder = order,
				BackgroundColor3 = UI.Colors.Background,
				BackgroundTransparency = 0.3,
				Parent = list,
			}, { UI.corner(6) })
			local play = UI.button({
				Position = UDim2.new(0, 4, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				Size = UDim2.fromOffset(74, 30),
				BackgroundColor3 = UI.Colors.Success,
				Text = "Jouer",
				MaxTextSize = 16,
				Parent = row,
			})
			play:SetAttribute("NoClickSound", true) -- (pas de clic par-dessus le son qu'on écoute)
			UI.label({
				Position = UDim2.new(0, 86, 0, 3),
				Size = UDim2.new(1, -196, 0, 18),
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = def.name,
				MaxTextSize = 15,
				Parent = row,
			})
			UI.label({
				Position = UDim2.new(0, 86, 0, 21),
				Size = UDim2.new(1, -196, 0, 15),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = UI.Colors.Muted,
				Text = `id {def.id} • {settingsText(def)}`,
				MaxTextSize = 12,
				Parent = row,
			})
			local status = UI.label({
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -6, 0.5, 0),
				Size = UDim2.fromOffset(100, 30),
				TextXAlignment = Enum.TextXAlignment.Right,
				TextColor3 = UI.Colors.Muted,
				Text = "",
				MaxTextSize = 13,
				Parent = row,
			})
			play.Activated:Connect(function()
				local sound = SoundManager.preview(name)
				if not sound then
					return
				end
				status.Text = "chargement…"
				status.TextColor3 = UI.Colors.Muted
				local deadline = os.clock() + LOAD_TIMEOUT
				while sound.Parent and sound.TimeLength <= 0 and os.clock() < deadline do
					task.wait(0.1)
				end
				if sound.TimeLength > 0 then
					status.Text = `{UI.decimal(math.floor(sound.TimeLength * 10 + 0.5) / 10)} s`
					status.TextColor3 = UI.Colors.Text
				elseif os.clock() >= deadline then
					status.Text = "ne se charge pas !"
					status.TextColor3 = Color3.fromRGB(240, 100, 100)
				end
			end)
		end
	end
	return window
end

function SoundPanel.start()
	if not RunService:IsStudio() or Config.STUDIO_SOUND_PANEL ~= true then
		return -- jamais dans le jeu publié
	end
	if ReplicatedStorage:FindFirstChild("__AutoPlayTest") then
		return -- tests automatiques : leurs captures ne changent pas
	end
	local gui = UI.screen("SoundPanel", 30)
	gui:SetAttribute("NoTranslate", true) -- outil Studio : jamais traduit en anglais (AutoTranslate.luau)
	-- Colonne de gauche, ligne 5 (celle de « GALERIE (Studio) »), juste à sa droite.
	local button = UI.button({
		Name = "SoundPanelButton",
		Position = UDim2.new(0, 16 + 180 + 8, 0, UI.LEFT_COLUMN_TOP + 5 * UI.LEFT_COLUMN_STEP),
		Size = UDim2.fromOffset(160, 46),
		BackgroundColor3 = UI.Colors.PanelLight,
		Text = "SONS (Studio)",
		MaxTextSize = 18,
		Parent = gui,
	})
	local window = nil
	button.Activated:Connect(function()
		window = window or build(gui)
		window.Visible = not window.Visible
		if not window.Visible then
			SoundManager.stopPreview()
		end
	end)
end

return SoundPanel

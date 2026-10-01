-- Panneau « 🎁 DONNER » : seulement pour le propriétaire du jeu (demande du propriétaire, 30/09/2026 : « donner le
-- x2 » à un joueur). Bouton en haut à gauche ; la fenêtre liste les joueurs du serveur avec, pour chacun, les 3 passes
-- (Vitesse x2, Pièces x2, Ramassage auto) : un clic offre le pass, un deuxième clic le reprend (un pass ACHETÉ reste).
-- Le serveur revérifie tout (Hub/AdminGifts.luau) : un autre joueur qui fabriquerait ce panneau ne pourrait rien faire.
-- Jamais pendant les tests automatiques ; dans Studio, visible pour tester.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local UI = require(script.Parent.UI)

local AdminUI = {}

-- nom du pass (Monetization.luau), attribut publié sur chaque joueur, texte du bouton
local PASSES = {
	{ name = "SpeedX2", attribute = "PassSpeedX2", label = "Vitesse x2" },
	{ name = "CoinsX2", attribute = "PassCoinsX2", label = "Pièces x2" },
	{ name = "AutoCollect", attribute = "PassAutoCollect", label = "Ramassage" },
}
local ROW_HEIGHT = 44
local WINDOW_WIDTH = 360

local function isOwner(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	return game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId
end

function AdminUI.start()
	local player = Players.LocalPlayer
	if not isOwner(player) or ReplicatedStorage:FindFirstChild("__AutoPlayTest") then
		return
	end
	local adminAction = Remotes.get("AdminAction")
	local gui = UI.screen("AdminGifts", 25)
	gui:SetAttribute("NoTranslate", true) -- outil du propriétaire : jamais traduit (AutoTranslate.luau)

	local openButton = UI.button({
		Name = "AdminButton",
		Position = UDim2.fromOffset(16, 16),
		Size = UDim2.fromOffset(130, 38),
		BackgroundColor3 = Color3.fromRGB(150, 110, 30),
		Text = "🎁 DONNER",
		MaxTextSize = 17,
		Parent = gui,
	})
	local window = UI.new("Frame", {
		Name = "Window",
		Position = UDim2.fromOffset(16, 60),
		Size = UDim2.fromOffset(WINDOW_WIDTH, 60),
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.04,
		Visible = false,
		Parent = gui,
	}, { UI.corner(12), UI.padding(10), UI.stroke(UI.Colors.Gold, 2) })
	UI.label({
		Size = UDim2.new(1, 0, 0, 22),
		Font = Enum.Font.GothamBlack,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 16,
		Text = "Offrir un pass (clic = offrir / reprendre)",
		Parent = window,
	})
	local list = UI.new("Frame", {
		Name = "Players",
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, 0, 1, -28),
		BackgroundTransparency = 1,
		Parent = window,
	})
	-- Téléphone : plus petit, en haut à gauche sous le bouton « ★ BOUTIQUE » (UI.leftColumnSlot).
	local function place()
		local phone = UI.touchLayout(UI.screenSize(gui))
		openButton.Position = UDim2.fromOffset(if phone then 12 else 16, if phone then 48 else 16)
		openButton.Size = UDim2.fromOffset(if phone then 110 else 130, if phone then 30 else 38)
		window.Position = UDim2.fromOffset(if phone then 12 else 16, if phone then 84 else 60)
	end
	place()
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)

	local rows = {} -- [UserId] = { frame, buttons = { [nom] = bouton } }
	local function refresh()
		local present = {}
		local index = 0
		for _, other in Players:GetPlayers() do
			present[other.UserId] = true
			local row = rows[other.UserId]
			if not row then
				local frame = UI.new("Frame", {
					Name = "Row_" .. other.UserId,
					Size = UDim2.new(1, 0, 0, ROW_HEIGHT - 4),
					BackgroundTransparency = 1,
					Parent = list,
				})
				UI.label({
					Size = UDim2.new(0.34, -4, 1, 0),
					TextXAlignment = Enum.TextXAlignment.Left,
					MaxTextSize = 15,
					Text = other.DisplayName,
					Parent = frame,
				})
				local buttons = {}
				for passIndex, pass in PASSES do
					local button = UI.button({
						Name = "Give_" .. pass.name,
						Position = UDim2.new(0.34 + (passIndex - 1) * 0.22, 0, 0, 2),
						Size = UDim2.new(0.22, -4, 1, -4),
						BackgroundColor3 = UI.Colors.PanelLight,
						Text = pass.label,
						MaxTextSize = 13,
						Parent = frame,
					})
					button.Activated:Connect(function()
						local owned = other:GetAttribute(pass.attribute) == true
						adminAction:FireServer("GivePass", other.UserId, pass.name, not owned)
					end)
					buttons[pass.name] = button
				end
				row = { frame = frame, buttons = buttons }
				rows[other.UserId] = row
			end
			row.frame.Position = UDim2.fromOffset(0, index * ROW_HEIGHT)
			for _, pass in PASSES do
				local owned = other:GetAttribute(pass.attribute) == true
				local button = row.buttons[pass.name]
				button.Text = if owned then "✓ " .. pass.label else pass.label
				button.BackgroundColor3 = if owned then UI.Colors.Success else UI.Colors.PanelLight
			end
			index += 1
		end
		for userId, row in rows do
			if not present[userId] then
				row.frame:Destroy()
				rows[userId] = nil
			end
		end
		window.Size = UDim2.fromOffset(WINDOW_WIDTH, 28 + index * ROW_HEIGHT + 20)
	end

	openButton.Activated:Connect(function()
		window.Visible = not window.Visible
		if window.Visible then
			refresh()
		end
	end)
	task.spawn(function()
		while gui.Parent do
			if window.Visible then
				refresh()
			end
			task.wait(0.5)
		end
	end)
end

return AdminUI

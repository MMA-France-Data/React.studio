-- Interface de la map principale : carte de rang, raccourcis et statut de la recherche ranked.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Ranks = require(Shared.Ranks)
local Remotes = require(Shared.Remotes)
local UI = require(script.Parent.UI)

local LobbyUI = {}

function LobbyUI.start()
	local player = Players.LocalPlayer
	local queueAction = Remotes.get("QueueAction")
	local gui = UI.screen("Lobby")

	-- Carte de rang (en haut à gauche)
	local card = UI.new("Frame", {
		Position = UDim2.new(0, 16, 0, 16),
		Size = UDim2.new(0, 260, 0, 130),
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.1,
		Parent = gui,
	}, { UI.corner(12), UI.padding(12), UI.stroke() })

	local rankLabel = UI.label({
		Size = UDim2.new(1, 0, 0, 34),
		Font = Enum.Font.GothamBlack,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 30,
		Text = "...",
		Parent = card,
	})
	local mmrLabel = UI.label({
		Position = UDim2.new(0, 0, 0, 38),
		Size = UDim2.new(1, 0, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.Gold,
		MaxTextSize = 22,
		Text = "",
		Parent = card,
	})
	local statsLabel = UI.label({
		Position = UDim2.new(0, 0, 0, 66),
		Size = UDim2.new(1, 0, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.Muted,
		MaxTextSize = 18,
		Text = "",
		Parent = card,
	})
	UI.label({
		Position = UDim2.new(0, 0, 0, 88),
		Size = UDim2.new(1, 0, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.Muted,
		MaxTextSize = 16,
		Text = `Saison {Config.SEASON} • Tower Defense 1v1`,
		Parent = card,
	})

	-- Raccourcis de déplacement (à gauche)
	local hubAction = Remotes.get("HubAction")
	for index, shortcut in {
		{ text = "🏠  Ma base", action = "GoHome", color = UI.Colors.Accent },
		{ text = "⚔  Cercle ranked", action = "GoRanked", color = UI.Colors.Error },
	} do
		local shortcutButton = UI.button({
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 16, 0.5, (index - 1) * 54 - 27),
			Size = UDim2.new(0, 180, 0, 46),
			BackgroundColor3 = shortcut.color,
			Text = shortcut.text,
			MaxTextSize = 20,
			Parent = gui,
		})
		shortcutButton.Activated:Connect(function()
			hubAction:FireServer(shortcut.action)
		end)
	end

	-- Statut de la recherche ranked (en bas au centre). On lance une recherche en entrant dans
	-- le cercle au centre de la map ; le bouton sert seulement à annuler.
	local statusLabel = UI.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -100),
		Size = UDim2.new(0, 400, 0, 28),
		MaxTextSize = 22,
		Text = "",
		Parent = gui,
	})
	local button = UI.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -30),
		Size = UDim2.new(0, 300, 0, 60),
		Text = "ANNULER",
		MaxTextSize = 28,
		Visible = false,
		Parent = gui,
	})

	button.Activated:Connect(function()
		local state = player:GetAttribute("QueueState") or "Idle"
		if state == "Searching" or state == "Joining" then
			queueAction:FireServer("Leave")
		end
	end)

	local function update()
		local mmr = player:GetAttribute("Mmr")
		local games = player:GetAttribute("GamesPlayed") or 0
		if mmr then
			rankLabel.Text = Ranks.label(mmr, games)
			rankLabel.TextColor3 = Ranks.color(mmr, games)
			mmrLabel.Text = if Ranks.isPlacement(games) then "MMR caché pendant le placement" else `{mmr} MMR  (record : {player:GetAttribute("PeakMmr") or mmr})`
			statsLabel.Text = `{player:GetAttribute("Wins") or 0} V  •  {player:GetAttribute("Losses") or 0} D  •  {player:GetAttribute("Draws") or 0} N`
		else
			rankLabel.Text = "Chargement..."
		end

		local state = player:GetAttribute("QueueState") or "Idle"
		if state == "Searching" or state == "Joining" then
			local since = player:GetAttribute("QueueStartedAt")
			local elapsed = if since then workspace:GetServerTimeNow() - since else 0
			button.Visible = true
			button.Text = "ANNULER"
			button.BackgroundColor3 = UI.Colors.Error
			statusLabel.Text = `Recherche d'un adversaire...  {UI.formatTime(elapsed)}`
		elseif state == "Found" then
			button.Visible = false
			statusLabel.Text = "Adversaire trouvé ! Téléportation vers le match..."
		else
			button.Visible = false
			statusLabel.Text = "⚔ Entre dans le cercle rouge au centre pour lancer une ranked"
		end
	end

	task.spawn(function()
		while gui.Parent do
			update()
			task.wait(0.2)
		end
	end)
end

return LobbyUI

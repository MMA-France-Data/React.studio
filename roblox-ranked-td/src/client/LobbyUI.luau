-- Interface de la map principale : carte de rang, raccourcis et statut de la recherche ranked.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local PlotLayout = require(Shared.PlotLayout)
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
		Text = `Saison {Config.SEASON} • ROYAUMES EN GUERRE`,
		Parent = card,
	})

	-- Plus de raccourcis « MON FIEF » / « ARÈNE ROYALE » (demande du propriétaire, 29/09/2026) : on va à pied à
	-- sa parcelle et dans le cercle de l'arène. La colonne de gauche, sous le panneau de rang, commence par les
	-- boutons des machines (MachineUI), puis Renaissance, Boutique et Défis. Le chat est en bas à gauche.

	-- Statut de la recherche ranked (en bas à droite). On lance une recherche en entrant dans
	-- le cercle au centre de la map ; le bouton sert seulement à annuler.
	local statusLabel = UI.label({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -84),
		Size = UDim2.new(0, 380, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextStrokeTransparency = 0.5,
		MaxTextSize = 18,
		Text = "",
		Parent = gui,
	})
	local button = UI.button({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -20),
		Size = UDim2.new(0, 220, 0, 56),
		Text = "ANNULER",
		MaxTextSize = 24,
		Visible = false,
		Parent = gui,
	})

	button.Activated:Connect(function()
		local state = player:GetAttribute("QueueState") or "Idle"
		if state == "Searching" or state == "Joining" then
			queueAction:FireServer("Leave")
		end
	end)

	-- Le conseil « entre dans le sceau » n'apparaît que près du sceau rouge.
	local function nearRankedCircle(): boolean
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		return root ~= nil
			and (root.Position - PlotLayout.RANKED_CIRCLE_POSITION).Magnitude <= Config.LabelDistance.Medium
	end

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
			statusLabel.Text = if nearRankedCircle() then "Entre dans le sceau rouge pour défier un autre royaume" else ""
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

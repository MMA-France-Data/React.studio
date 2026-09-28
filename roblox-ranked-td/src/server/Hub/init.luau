-- Map principale (serveur public) : 6 parcelles, cercle ranked au centre, classement.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local PlotLayout = require(Shared.PlotLayout)
local Ranks = require(Shared.Ranks)
local Remotes = require(Shared.Remotes)
local Leaderboard = require(script.Parent.Leaderboard)
local Matchmaking = require(script.Parent.Matchmaking)
local HubMap = require(script.HubMap)
local Plots = require(script.Plots)

local Hub = {}

local function buildBoardGui(board: BasePart)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back -- face tournée vers le cercle ranked (+Z)
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = board

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0.1, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 215, 90)
	title.Text = `CLASSEMENT RANKED — SAISON {Config.SEASON}`
	title.Parent = gui

	local rows = {}
	local count = Config.Ranked.LEADERBOARD_SIZE
	for i = 1, count do
		local row = Instance.new("TextLabel")
		row.Size = UDim2.new(0.94, 0, 0.88 / count, 0)
		row.Position = UDim2.new(0.03, 0, 0.11 + (i - 1) * 0.88 / count, 0)
		row.BackgroundTransparency = if i % 2 == 0 then 1 else 0.85
		row.BackgroundColor3 = Color3.new(1, 1, 1)
		row.Font = Enum.Font.GothamMedium
		row.TextScaled = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = Color3.fromRGB(230, 230, 240)
		row.Text = ""
		row.Parent = gui
		rows[i] = row
	end
	return rows
end

local function refreshBoard(rows)
	local entries = Leaderboard.fetchTop(#rows)
	for i, row in rows do
		local entry = entries[i]
		if entry then
			local rank = Ranks.get(entry.mmr)
			row.Text = `  #{i}   {entry.name}   —   {entry.mmr} MMR ({rank.name})`
			row.TextColor3 = if i <= 3 then rank.color else Color3.fromRGB(230, 230, 240)
		else
			row.Text = if i == 1 and #entries == 0 then "  Aucun joueur classé pour l'instant" else ""
		end
	end
end

-- Entrer dans le cercle lance la recherche (une seule fois par entrée).
local function watchRankedCircle()
	local center = PlotLayout.RANKED_CIRCLE_POSITION
	local radius = PlotLayout.RANKED_CIRCLE_RADIUS
	local inside = {}

	Players.PlayerRemoving:Connect(function(player)
		inside[player] = nil
	end)

	while true do
		task.wait(0.25)
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local isInside = false
			if root then
				local offset = root.Position - center
				isInside = Vector3.new(offset.X, 0, offset.Z).Magnitude <= radius and math.abs(offset.Y) < 8
			end
			if isInside and not inside[player] then
				task.spawn(Matchmaking.join, player)
			end
			inside[player] = isInside
		end
	end
end

function Hub.start()
	local map = HubMap.build()
	Plots.init(map.plots)
	Plots.start()

	local rows = buildBoardGui(map.board)
	Matchmaking.start()

	Remotes.get("QueueAction").OnServerEvent:Connect(function(player, action)
		if action == "Join" then
			Matchmaking.join(player)
		elseif action == "Leave" then
			Matchmaking.leave(player)
		end
	end)

	Remotes.get("HubAction").OnServerEvent:Connect(function(player, action)
		local character = player.Character
		if not character then
			return
		end
		if action == "GoHome" then
			Plots.sendHome(player)
		elseif action == "GoRanked" then
			local position = PlotLayout.RANKED_CIRCLE_POSITION + Vector3.new(0, 3, 0)
			character:PivotTo(CFrame.new(position))
		end
	end)

	task.spawn(watchRankedCircle)
	task.spawn(function()
		while true do
			refreshBoard(rows)
			task.wait(Config.Ranked.LEADERBOARD_REFRESH)
		end
	end)
end

return Hub

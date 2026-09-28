-- Map principale (serveur public) : 6 parcelles, cercle ranked au centre, classement.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local IdleConfig = require(Shared.IdleConfig)
local PlotLayout = require(Shared.PlotLayout)
local Ranks = require(Shared.Ranks)
local Remotes = require(Shared.Remotes)
local Leaderboard = require(script.Parent.Leaderboard)
local Matchmaking = require(script.Parent.Matchmaking)
local PlayerData = require(script.Parent.PlayerData)
local PlotGame = require(script.PlotGame)
local HubMap = require(script.HubMap)
local Plots = require(script.Plots)

local Hub = {}

local games = {} -- [Player] = PlotGame

local function startPlotGame(player: Player, data)
	if games[player] then
		return
	end
	local plotIndex = Plots.get(player)
	if not plotIndex or not player.Parent then
		return
	end
	games[player] = PlotGame.new(Plots.plot(plotIndex), player, data)
end

-- Boucle du mode infini : simulation à chaque frame, envois réseau quelques fois par seconde.
local function runPlotGames()
	local syncRemote = Remotes.get("PlotSync")
	local shotsRemote = Remotes.get("PlotShots")
	local syncTimer, shotsTimer, collectTimer = 0, 0, 0

	RunService.Heartbeat:Connect(function(dt)
		for _, plotGame in games do
			plotGame:step(dt)
		end

		syncTimer += dt
		if syncTimer >= 1 / IdleConfig.SYNC_RATE then
			syncTimer = 0
			for _, plotGame in games do
				local packet, count = plotGame:buildSyncPacket()
				if packet then
					syncRemote:FireAllClients(plotGame.index, packet, count)
				end
			end
		end

		shotsTimer += dt
		if shotsTimer >= 1 / IdleConfig.SHOTS_RATE then
			shotsTimer = 0
			for _, plotGame in games do
				local packet, count = plotGame:takeShotsPacket()
				if packet then
					shotsRemote:FireAllClients(plotGame.index, packet, count)
				end
			end
		end

		collectTimer += dt
		if collectTimer >= 0.2 then
			collectTimer = 0
			for _, plotGame in games do
				plotGame:collectDrops()
			end
		end
	end)
end

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

	-- Une partie infinie par joueur, dès que ses données sont chargées.
	PlayerData.onLoaded(startPlotGame)
	for _, player in Players:GetPlayers() do
		local data = PlayerData.get(player)
		if data then
			startPlotGame(player, data)
		end
	end
	PlayerData.onBeforeRelease(function(player)
		local plotGame = games[player]
		if plotGame then
			games[player] = nil
			plotGame:destroy()
		end
	end)
	runPlotGames()

	local lastPlotAction = {}
	Players.PlayerRemoving:Connect(function(player)
		lastPlotAction[player] = nil
	end)
	Remotes.get("PlotAction").OnServerEvent:Connect(function(player, action, spotIndex, towerType)
		local plotGame = games[player]
		local now = os.clock()
		if not plotGame or now - (lastPlotAction[player] or 0) < 0.15 then
			return
		end
		lastPlotAction[player] = now
		if action == "Place" then
			plotGame:placeTower(spotIndex, towerType)
		elseif action == "Sell" then
			plotGame:sellTower(spotIndex)
		elseif action == "BuySpot" then
			plotGame:buySpot()
		end
	end)

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

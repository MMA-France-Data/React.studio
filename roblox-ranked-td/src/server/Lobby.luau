-- Serveur lobby : décor minimal, tableau des meilleurs joueurs et file ranked.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Ranks = require(Shared.Ranks)
local Remotes = require(Shared.Remotes)
local Leaderboard = require(script.Parent.Leaderboard)
local Matchmaking = require(script.Parent.Matchmaking)

local Lobby = {}

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		p[key] = value
	end
	return p
end

local function buildEnvironment()
	local folder = Instance.new("Folder")
	folder.Name = "Lobby"
	folder.Parent = workspace

	part({
		Name = "Floor",
		Size = Vector3.new(200, 1, 200),
		Position = Vector3.new(0, -0.5, 0),
		Color = Color3.fromRGB(60, 64, 80),
		Material = Enum.Material.SmoothPlastic,
		Parent = folder,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Position = Vector3.new(0, 0.5, 20)
	spawn.Color = Color3.fromRGB(90, 140, 255)
	spawn.Material = Enum.Material.Neon
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = folder

	local board = part({
		Name = "LeaderboardBoard",
		Size = Vector3.new(28, 20, 1),
		CFrame = CFrame.new(0, 11, -20),
		Color = Color3.fromRGB(25, 27, 38),
		Parent = folder,
	})
	return board
end

local function buildBoardGui(board: BasePart)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back -- face tournée vers le spawn (+Z)
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = board

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0.1, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 215, 90)
	title.Text = `CLASSEMENT — SAISON {Config.SEASON}`
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

function Lobby.start()
	local board = buildEnvironment()
	local rows = buildBoardGui(board)

	Matchmaking.start()

	Remotes.get("QueueAction").OnServerEvent:Connect(function(player, action)
		if action == "Join" then
			Matchmaking.join(player)
		elseif action == "Leave" then
			Matchmaking.leave(player)
		end
	end)

	task.spawn(function()
		while true do
			refreshBoard(rows)
			task.wait(Config.Ranked.LEADERBOARD_REFRESH)
		end
	end)
end

return Lobby

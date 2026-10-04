-- Map principale : 6 parcelles autour de la place. La parcelle d'un joueur est son CAMP D'ENTRAÎNEMENT (Hub/Camp.luau) ;
-- il joue ses NIVEAUX dans une zone de combat à part (Hub/LevelsService.luau). Sur la place, les deux panneaux du
-- classement des niveaux (Hub/LevelBoard.luau, LevelLeaderboard.luau).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local IdleConfig = require(Shared.IdleConfig)
local PlotLayout = require(Shared.PlotLayout)
local Remotes = require(Shared.Remotes)
local LevelLeaderboard = require(script.Parent.LevelLeaderboard)
local PlayerData = require(script.Parent.PlayerData)
local Camp = require(script.Camp)
local HubMap = require(script.HubMap)
local LevelBoard = require(script.LevelBoard)
local LevelsService = require(script.LevelsService)
local PlotInterest = require(script.PlotInterest)
local Plots = require(script.Plots)

local Hub = {}

----------------------------------------------------------------------
-- Qui reçoit les cibles et les tirs de chaque camp (règle et réglages : Hub/PlotInterest.luau) :
-- son propriétaire toujours, les autres joueurs seulement quand ils s'en approchent.
----------------------------------------------------------------------
local interest = {
	near = {}, -- mémoire de PlotInterest.compute : [Player] = { [plotIndex] = true }
	viewers = {}, -- [plotIndex] = joueurs qui reçoivent cette parcelle (propriétaire compris)
	positions = {}, -- tests Studio : [Player] = position utilisée à la place de son personnage
	clears = {}, -- tests Studio : [Player] = nombre de paquets « Clear » reçus
}
for plotIndex = 1, PlotLayout.COUNT do
	interest.viewers[plotIndex] = {}
end
local EMPTY_PACKET = buffer.create(0)

-- Position du personnage du joueur (nil = pas de personnage).
local function characterPosition(player: Player): Vector3?
	local override = interest.positions[player]
	if override then
		return override
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.Position else nil
end

-- Recalcule qui reçoit chaque parcelle (quelques fois par seconde, pas à chaque image). Un joueur qui vient
-- d'arrêter de recevoir une parcelle reçoit (lui seul) un paquet PlotSync « Clear » : son client efface tout
-- de suite ce qu'il en affichait (cibles, zones de feu, rayons). À son retour, les paquets suivants redonnent
-- tout (chaque paquet PlotSync contient toutes les cibles de la parcelle).
local function refreshInterest(syncRemote)
	local viewers = {}
	for _, player in Players:GetPlayers() do
		table.insert(viewers, { key = player, position = characterPosition(player), plot = Plots.get(player) })
	end
	local recipients, leaving = PlotInterest.compute(viewers, interest.near)
	interest.viewers = recipients
	for _, gone in leaving do
		local player = gone.key
		if player.Parent then
			syncRemote:FireClient(player, gone.plotIndex, EMPTY_PACKET, 0, "Clear")
			interest.clears[player] = (interest.clears[player] or 0) + 1
		end
	end
end

-- Envoie un paquet d'un camp à son propriétaire (toujours, même loin de sa parcelle) et aux joueurs qui s'en
-- approchent (liste de refreshInterest).
local function sendToViewers(remote, campGame, packet: buffer, count: number)
	local owner = campGame.player
	if owner.Parent then
		remote:FireClient(owner, campGame.index, packet, count)
	end
	for _, player in interest.viewers[campGame.index] do
		if player ~= owner and player.Parent then
			remote:FireClient(player, campGame.index, packet, count)
		end
	end
end

-- Camps d'entraînement : simulation à chaque image, envois réseau quelques fois par seconde.
local function runCamps()
	local syncRemote = Remotes.get("PlotSync")
	local shotsRemote = Remotes.get("PlotShots")
	local syncTimer, shotsTimer = 0, 0
	local interestTimer = PlotInterest.REFRESH_INTERVAL -- premier calcul tout de suite
	Players.PlayerRemoving:Connect(function(player)
		interest.positions[player] = nil
		interest.clears[player] = nil
	end)

	RunService.Heartbeat:Connect(function(dt)
		for _, campGame in Camp.games do
			campGame:step(dt)
		end

		interestTimer += dt
		if interestTimer >= PlotInterest.REFRESH_INTERVAL then
			interestTimer = 0
			refreshInterest(syncRemote)
		end

		syncTimer += dt
		if syncTimer >= 1 / IdleConfig.SYNC_RATE then
			syncTimer = 0
			for _, campGame in Camp.games do
				local packet, count = campGame:buildSyncPacket()
				if packet then
					sendToViewers(syncRemote, campGame, packet, count)
				end
			end
		end

		shotsTimer += dt
		if shotsTimer >= 1 / IdleConfig.SHOTS_RATE then
			shotsTimer = 0
			for _, campGame in Camp.games do
				local packet, count = campGame:takeShotsPacket()
				if packet then
					sendToViewers(shotsRemote, campGame, packet, count)
				end
			end
		end
	end)
end

-- Outil de test, uniquement dans Studio : ServerStorage.StudioDebug (BindableFunction), utilisable depuis la barre
-- de commande ou un plugin.
--   Invoke(player, "Data")                      -> renvoie les données du joueur
--   Invoke(player, "Levels", "State")           -> { levels, active } ; les autres commandes des niveaux ("Action",
--                                                  "Set", "Gold", "Skip", "KillAll", "Finish", "Clock", "Bench") sont
--                                                  décrites en bas de LevelsService.luau
--   Invoke(player, "Camp")                      -> camp du joueur : { camp, towers = { [emplacement] = { type, stage } },
--                                                  targets (cibles en vie), kills (cibles détruites), clock }
-- Camps reçus (cibles et tirs, Hub/PlotInterest.luau) :
--   Invoke(player, "Interest")                  -> { own, receivesOwn, receives = { numéros des parcelles des autres
--                                                  qu'il reçoit }, clears = paquets « Clear » reçus depuis son arrivée }
--   Invoke(player, "Interest", "Position", pos) -> cette position compte à la place de son personnage (nil : de nouveau
--                                                  son personnage), au prochain calcul (PlotInterest.REFRESH_INTERVAL)
--   Invoke(player, "Board", ...)                -> classement des niveaux des panneaux de la place ("State", "Tick",
--                                                  "Clock", "Stored", "Refresh", "Fake", "ClearFakes" : en bas de
--                                                  LevelLeaderboard.luau)
local function setupStudioDebug()
	if not RunService:IsStudio() then
		return
	end
	local debug = Instance.new("BindableFunction")
	debug.Name = "StudioDebug"
	debug.OnInvoke = function(player: Player, command: string, ...)
		if command == "Data" then
			return PlayerData.get(player)
		elseif command == "Levels" then
			return LevelsService.debug(player, ...)
		elseif command == "Camp" then
			local campGame = Camp.games[player]
			local towers = {}
			if campGame then
				for slotIndex, tower in campGame.slotTowers do
					towers[slotIndex] = { type = tower.type, stage = tower.stage }
				end
			end
			return {
				camp = campGame ~= nil,
				towers = towers,
				targets = if campGame then #campGame.enemies else 0,
				kills = if campGame then campGame.kills else 0,
				clock = if campGame then campGame.clock else 0,
			}
		elseif command == "Board" then
			return LevelLeaderboard.debug(player, ...)
		elseif command == "Interest" then
			local action, position = ...
			if action == "Position" then
				interest.positions[player] = if typeof(position) == "Vector3" then position else nil
				return true
			end
			local own = Plots.get(player)
			local receives, receivesOwn = {}, false
			for plotIndex, list in interest.viewers do
				if table.find(list, player) then
					if plotIndex == own then
						receivesOwn = true
					else
						table.insert(receives, plotIndex)
					end
				end
			end
			table.sort(receives)
			return { own = own, receivesOwn = receivesOwn, receives = receives, clears = interest.clears[player] or 0 }
		end
		return nil
	end
	debug.Parent = game:GetService("ServerStorage")
end

function Hub.start()
	local map = HubMap.build()
	Plots.init(map.plots)
	Plots.start()

	-- Niveaux : zones de combat loin de la place, une par parcelle.
	LevelsService.start(Plots)

	-- Le camp de chaque joueur, sur sa parcelle, dès que ses données sont chargées.
	local function onDataLoaded(player: Player, data)
		local plotIndex = Plots.get(player)
		if plotIndex and player.Parent then
			Camp.start(player, Plots.plot(plotIndex), data.levels)
		end
	end
	PlayerData.onLoaded(onDataLoaded)
	for _, player in Players:GetPlayers() do
		local data = PlayerData.get(player)
		if data then
			onDataLoaded(player, data)
		end
	end
	-- État du joueur changé (emplacements, XP, pièces) : son camp suit.
	LevelsService.onChanged(Camp.refresh)

	-- Les panneaux de la place : les meilleurs joueurs de tous les serveurs et les joueurs de ce serveur (plus haut
	-- niveau réussi, victoires).
	for _, entry in map.boards do
		LevelBoard.attach(entry.board, entry.front)
	end
	LevelLeaderboard.start(function(player: Player)
		local data = PlayerData.get(player)
		if not data then
			return nil
		end
		return data.levels.best, data.levels.wins
	end, LevelBoard.show)

	PlayerData.onBeforeRelease(function(player)
		Camp.stop(player)
		local data = PlayerData.get(player)
		if data then
			LevelLeaderboard.leave(player, data.levels.best, data.levels.wins) -- (son dernier score, s'il a monté)
		end
	end)

	runCamps()
	setupStudioDebug()
end

return Hub

-- Serveur de match (serveur réservé créé par le matchmaking).
-- Attend les deux joueurs, lance la partie, applique le MMR puis renvoie tout le monde au lobby.
local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Challenges = require(Shared.Challenges)
local Config = require(Shared.Config)
local Elo = require(Shared.Elo)
local MapLayout = require(Shared.MapLayout)
local Ranks = require(Shared.Ranks)
local Remotes = require(Shared.Remotes)
local Leaderboard = require(script.Parent.Leaderboard)
local PlayerData = require(script.Parent.PlayerData)
local Game = require(script.Game)
local MapBuilder = require(script.MapBuilder)

local C = Config.Match
local isStudio = RunService:IsStudio()

local Match = {}

local matchState: Folder
local bases = {}
local phase = "Waiting"
local slots = {}
local info = nil
local ranked = false
local matchId = ""
local currentGame = nil
local lastChallenges = {} -- [numéro de terrain] = résultat des défis classés du match (tests Studio)

local function setPhase(newPhase: string)
	phase = newPhase
	matchState:SetAttribute("Phase", newPhase)
end

local function otherIndex(index: number): number
	return if index == 1 then 2 else 1
end

local function slotOf(player: Player)
	for _, slot in slots do
		if slot.userId == player.UserId then
			return slot
		end
	end
	return nil
end

local function fetchMatchInfo()
	if game.PrivateServerId == "" then
		return nil
	end
	local matches = MemoryStoreService:GetHashMap("RankedTD_Matches")
	for attempt = 1, 5 do
		local ok, result = pcall(function()
			return matches:GetAsync(game.PrivateServerId)
		end)
		if ok and result then
			return result
		end
		task.wait(attempt)
	end
	return nil
end

local function returnToLobby()
	local players = Players:GetPlayers()
	if #players == 0 then
		return
	end
	if isStudio then
		for _, player in players do
			Remotes.get("Notify"):FireClient(player, "Fin du match (Studio) : pas de retour au lobby possible ici.", "Info")
		end
		return
	end
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, players)
	end)
	if not ok then
		warn("[Match] Retour au lobby impossible :", err)
		for _, player in players do
			player:Kick("Match terminé ! Relance le jeu pour revenir au lobby.")
		end
	end
end

----------------------------------------------------------------------
-- Résultat
----------------------------------------------------------------------

-- Applique l'Elo aux deux joueurs. Synchrone (pas de yield) : peut être appelé pendant le départ
-- d'un joueur, avant la sauvegarde finale de ses données.
local function applyRatings(winner: number?)
	if not ranked then
		return nil
	end
	local player1, player2 = slots[1].player, slots[2].player
	local data1 = player1 and PlayerData.get(player1)
	local data2 = player2 and PlayerData.get(player2)
	if not data1 or not data2 then
		warn("[Match] Données manquantes, MMR non appliqué")
		return nil
	end
	if data1.lastMatchId == matchId or data2.lastMatchId == matchId then
		return nil -- déjà appliqué
	end

	local score1 = if winner == nil then 0.5 elseif winner == 1 then 1 else 0
	local new1, new2 = Elo.compute(data1.mmr, data2.mmr, score1, data1.gamesPlayed, data2.gamesPlayed)

	local results = {}
	for index, entry in { { data1, new1, score1 }, { data2, new2, 1 - score1 } } do
		local data, newMmr, score = entry[1], entry[2], entry[3]
		local result = {
			oldMmr = data.mmr,
			oldRank = Ranks.label(data.mmr, data.gamesPlayed),
		}

		data.mmr = newMmr
		data.peakMmr = math.max(data.peakMmr, newMmr)
		data.gamesPlayed += 1
		data.lastMatchId = matchId
		if score == 1 then
			data.wins += 1
		elseif score == 0 then
			data.losses += 1
		else
			data.draws += 1
		end

		result.newMmr = newMmr
		result.newRank = Ranks.label(data.mmr, data.gamesPlayed)
		result.placementDone = not Ranks.isPlacement(data.gamesPlayed)
		results[index] = result

		local player = slots[index].player
		PlayerData.refresh(player)
		if result.placementDone then
			Leaderboard.submit(player.UserId, newMmr)
		end
	end
	return results
end

-- Défis classés (Shared/Challenges.luau) : compte ce match pour chaque joueur qui a encore ses données,
-- avec les chiffres de son terrain (tours posées, améliorations, types de tours) et la durée de la partie.
-- Challenges.recordMatch vérifie tout : vrai match classé (jamais contre un bot), au moins 3 min, au plus
-- 2 matchs comptés par jour contre le même adversaire, jamais deux fois le même match. Ne change rien à la
-- partie (déjà finie) ni au MMR. Synchrone (pas de yield), comme applyRatings.
-- Renvoie { [numéro de terrain] = { counted, reason, completed, text } }.
local function recordChallenges(winner: number?)
	local results = {}
	local seconds = if currentGame then currentGame:elapsed() else 0
	local now = os.time()
	for index, slot in slots do
		local data = slot.player and PlayerData.get(slot.player)
		if data then
			local stats = if currentGame then currentGame:challengeStats(index) else {}
			local ok, result = pcall(Challenges.recordMatch, data, {
				ranked = ranked,
				matchId = matchId,
				seconds = seconds,
				won = winner == index,
				opponentId = slots[otherIndex(index)].userId,
				towersPlaced = stats.towersPlaced,
				upgrades = stats.upgrades,
				towerTypes = stats.towerTypes,
			}, now)
			if ok then
				results[index] = result
			else
				warn("[Match] Défis classés non comptés :", result) -- le match se termine quand même
			end
		end
	end
	lastChallenges = results
	return results
end

local function finish(winner: number?, reason: string)
	if phase == "Ended" or phase == "Cancelled" then
		return
	end
	setPhase("Ended")
	if currentGame then
		currentGame:stop()
	end
	matchState:SetAttribute("Winner", winner or 0)
	matchState:SetAttribute("EndReason", reason)

	local results = applyRatings(winner)
	local challengeResults = recordChallenges(winner)
	for index, slot in slots do
		local player = slot.player
		if player and player.Parent then
			local outcome = if winner == nil then "Draw" elseif winner == index then "Win" else "Loss"
			local result = results and results[index]
			local challenge = challengeResults[index]
			pcall(function()
				Remotes.get("MatchResult"):FireClient(player, {
					outcome = outcome,
					reason = reason,
					ranked = result ~= nil,
					oldMmr = result and result.oldMmr,
					newMmr = result and result.newMmr,
					oldRank = result and result.oldRank,
					newRank = result and result.newRank,
					opponentName = slots[otherIndex(index)].name,
					challenges = challenge and challenge.text,
				})
				-- Un match qui ne compte pas pour les défis : on dit pourquoi.
				if challenge and not challenge.counted then
					Remotes.get("Notify"):FireClient(player, `Défis classés : {challenge.reason}`, "Warning")
				end
			end)
		end
	end

	-- task.defer : si la fin vient d'un abandon, on laisse d'abord PlayerData faire la
	-- sauvegarde finale du joueur qui part.
	task.defer(function()
		for _, slot in slots do
			if slot.player and PlayerData.get(slot.player) then
				PlayerData.save(slot.player)
			end
		end
		task.wait(C.RESULT_SCREEN_TIME)
		returnToLobby()
	end)
end

local function cancel(message: string)
	if phase == "Ended" or phase == "Cancelled" then
		return
	end
	setPhase("Cancelled")
	if currentGame then
		currentGame:stop()
	end
	for _, player in Players:GetPlayers() do
		pcall(function()
			Remotes.get("MatchResult"):FireClient(player, { outcome = "Cancelled", reason = message, ranked = false })
		end)
	end
	task.delay(6, returnToLobby)
end

----------------------------------------------------------------------
-- Joueurs
----------------------------------------------------------------------

local function placeCharacter(laneIndex: number, character: Model)
	task.defer(function()
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if root then
			local position = MapLayout.toWorld(laneIndex, MapLayout.PLAYER_SPAWN)
			character:PivotTo(CFrame.lookAt(position, position + Vector3.zAxis))
		end
	end)
end

local function setSlotName(slot, name: string)
	slot.name = name
	matchState:SetAttribute(`Lane{slot.index}Name`, name)
	local label = bases[slot.index] and bases[slot.index]:FindFirstChild("Label")
	if label then
		label.TextLabel.Text = name
	end
end

local function onPlayerAdded(player: Player)
	local slot = slotOf(player)
	if not slot and isStudio and phase == "Waiting" then
		-- Studio : les premiers joueurs arrivés prennent les places libres.
		for _, candidate in slots do
			if not candidate.userId then
				candidate.userId = player.UserId
				slot = candidate
				break
			end
		end
	end
	if not slot then
		if not isStudio then
			player:Kick("Ce serveur est réservé à un match ranked.")
		end
		return
	end

	slot.player = player
	player:SetAttribute("Lane", slot.index)
	setSlotName(slot, player.DisplayName)
	matchState:SetAttribute(`Lane{slot.index}UserId`, player.UserId)

	player.CharacterAdded:Connect(function(character)
		placeCharacter(slot.index, character)
	end)
	if player.Character then
		placeCharacter(slot.index, player.Character)
	end

	local data = PlayerData.waitFor(player, 40)
	if data and player.Parent and slot.player == player then
		slot.ready = true
		matchState:SetAttribute(`Lane{slot.index}Mmr`, data.mmr)
		matchState:SetAttribute(`Lane{slot.index}Rank`, Ranks.label(data.mmr, data.gamesPlayed))
	end
end

local function onPlayerRemoving(player: Player)
	local slot = slotOf(player)
	if slot and phase == "Waiting" then
		slot.ready = false
	end
end

-- Appelé par PlayerData juste avant la sauvegarde finale : un départ en cours de match = défaite.
local function onBeforeRelease(player: Player, isShutdown: boolean)
	local slot = slotOf(player)
	if not slot or (phase ~= "Countdown" and phase ~= "Playing") then
		return
	end
	if isShutdown then
		cancel("Le serveur s'est arrêté. Aucun MMR perdu.")
	else
		finish(otherIndex(slot.index), "Forfeit")
	end
end

----------------------------------------------------------------------
-- Déroulement
----------------------------------------------------------------------

local function waitForPlayers(): boolean
	local deadline = os.clock() + (if info then C.WAIT_FOR_PLAYERS else C.STUDIO_SOLO_WAIT)
	while true do
		local readyCount = 0
		for _, slot in slots do
			if slot.ready then
				readyCount += 1
			end
		end
		if readyCount == 2 then
			return true
		end
		if os.clock() >= deadline then
			if info then
				return false
			elseif readyCount >= 1 then
				-- Studio avec un seul joueur : l'autre lane est jouée par un bot, match non classé.
				for _, slot in slots do
					if not slot.ready then
						if slot.player then
							slot.player:SetAttribute("Lane", nil)
						end
						slot.player = nil
						slot.userId = -999
						setSlotName(slot, "Bot")
					end
				end
				return true
			end
		end
		task.wait(0.25)
	end
end

local function run()
	setPhase("Waiting")
	if not waitForPlayers() then
		cancel("Ton adversaire ne s'est pas connecté. Aucun MMR perdu.")
		return
	end

	ranked = slots[1].player ~= nil and slots[2].player ~= nil
	matchState:SetAttribute("Ranked", ranked)

	setPhase("Countdown")
	matchState:SetAttribute("CountdownEndsAt", workspace:GetServerTimeNow() + C.COUNTDOWN)
	task.wait(C.COUNTDOWN)
	if phase ~= "Countdown" then
		return -- abandon pendant le compte à rebours
	end

	currentGame = Game.new({
		{ player = slots[1].player, name = slots[1].name },
		{ player = slots[2].player, name = slots[2].name },
	}, matchState, finish)
	setPhase("Playing")
	currentGame:start()
end

-- Outil de test, uniquement dans Studio : ServerStorage.StudioDebug (BindableFunction), comme sur la map
-- principale (tools/studio-test/scenarios/MatchServer.luau) :
--   Invoke(player, "ChallengeStats")   -> { seconds, lanes = { chiffres des terrains 1 et 2 pour les défis } }
--   Invoke(player, "LastChallenges")   -> résultats des défis classés de la fin du match : { lane1, lane2 }
--   Invoke(player, "ChallengeData")    -> data.challenges du joueur
local function setupStudioDebug()
	if not isStudio then
		return
	end
	local debug = Instance.new("BindableFunction")
	debug.Name = "StudioDebug"
	debug.OnInvoke = function(player: Player, command: string)
		if command == "ChallengeStats" then
			if not currentGame then
				return nil
			end
			return { seconds = currentGame:elapsed(), lanes = { currentGame:challengeStats(1), currentGame:challengeStats(2) } }
		elseif command == "LastChallenges" then
			-- (Clés en texte : un tableau avec un trou, ex. seul le terrain 2, ne passerait pas entier.)
			return { lane1 = lastChallenges[1], lane2 = lastChallenges[2] }
		elseif command == "ChallengeData" then
			local data = player and PlayerData.get(player)
			return data and data.challenges
		end
		return nil
	end
	debug.Parent = game:GetService("ServerStorage")
end

function Match.start()
	setupStudioDebug()
	matchState = Instance.new("Folder")
	matchState.Name = "MatchState"
	matchState:SetAttribute("MaxDuration", C.MAX_DURATION)
	matchState:SetAttribute("BaseHealth", C.BASE_HEALTH)
	matchState.Parent = ReplicatedStorage

	bases = MapBuilder.build()
	for index = 1, 2 do
		slots[index] = { index = index, userId = nil, player = nil, name = "En attente...", ready = false }
	end
	setPhase("Waiting")

	info = fetchMatchInfo()
	if info then
		matchId = info.matchId
		for index, userId in info.players do
			slots[index].userId = userId
		end
	elseif not isStudio then
		-- Serveur réservé sans infos de match (expirées ou erreur) : on renvoie tout le monde.
		setPhase("Cancelled")
		Players.PlayerAdded:Connect(function()
			task.wait(3)
			returnToLobby()
		end)
		task.delay(3, returnToLobby)
		return
	else
		matchId = "studio-" .. HttpService:GenerateGUID(false)
	end

	PlayerData.onBeforeRelease(onBeforeRelease)
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	task.spawn(run)
end

return Match

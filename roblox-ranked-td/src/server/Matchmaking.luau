-- Matchmaking ranked entre tous les serveurs lobby.
--
-- Fonctionnement :
--   1. Un joueur rejoint la file -> entrée dans une MemoryStore SortedMap triée par MMR.
--   2. Un seul serveur lobby à la fois (le "leader", élu via un verrou MemoryStore) lit la file
--      et forme des paires de MMR proche. La fourchette acceptée s'élargit avec le temps d'attente.
--   3. Pour chaque paire, le leader réserve un serveur privé, y enregistre les infos du match,
--      puis écrit une "assignation" pour chaque joueur.
--   4. Chaque serveur lobby surveille les assignations de ses propres joueurs et les téléporte.
local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)

local MM = Config.Matchmaking

local Matchmaking = {}

-- Créés dans Matchmaking.start() : dans Studio (jeu non publié), MemoryStoreService peut refuser
-- l'accès, et une erreur au chargement du module empêcherait tout le lobby de démarrer.
local queueMap, assignments, matchInfos, leaderMap

-- [Player] = { state = "Joining" | "Searching" | "Teleporting", joinedAt = number }
local localQueue = {}

local notify = Remotes.get("Notify")

local function setQueueState(player: Player, state: string)
	player:SetAttribute("QueueState", state)
	if state == "Searching" then
		player:SetAttribute("QueueStartedAt", workspace:GetServerTimeNow())
	end
end

local function queueKey(userId: number): string
	return tostring(userId)
end

local function searchRange(waitSeconds: number): number
	return math.min(MM.MAX_RANGE, MM.BASE_RANGE + MM.RANGE_GROWTH_PER_SECOND * math.max(0, waitSeconds))
end

----------------------------------------------------------------------
-- Côté joueur (chaque serveur lobby gère ses propres joueurs)
----------------------------------------------------------------------

function Matchmaking.join(player: Player)
	if localQueue[player] then
		return
	end
	if RunService:IsStudio() then
		notify:FireClient(player, "Le matchmaking a besoin d'un jeu publié. Pour tester le gameplay : Config.STUDIO_FORCE_MODE = \"Match\".", "Warning")
		return
	end
	if not queueMap then
		notify:FireClient(player, "Le matchmaking est indisponible pour le moment.", "Error")
		return
	end
	local data = PlayerData.get(player)
	if not data then
		notify:FireClient(player, "Tes données sont encore en cours de chargement.", "Warning")
		return
	end

	local entry = { state = "Joining", joinedAt = os.time() }
	localQueue[player] = entry
	setQueueState(player, "Joining")

	local value = { userId = player.UserId, mmr = data.mmr, joinedAt = entry.joinedAt, jobId = game.JobId }
	local ok, err = pcall(function()
		queueMap:SetAsync(queueKey(player.UserId), value, MM.QUEUE_ENTRY_TTL, data.mmr)
	end)

	if localQueue[player] ~= entry then
		-- Le joueur a annulé ou quitté pendant l'écriture.
		pcall(function()
			queueMap:RemoveAsync(queueKey(player.UserId))
		end)
		return
	end
	if not ok then
		warn("[Matchmaking] Impossible de rejoindre la file :", err)
		localQueue[player] = nil
		setQueueState(player, "Idle")
		notify:FireClient(player, "Le matchmaking est indisponible, réessaie.", "Error")
		return
	end

	entry.state = "Searching"
	setQueueState(player, "Searching")
end

function Matchmaking.leave(player: Player)
	local entry = localQueue[player]
	if not entry or entry.state == "Teleporting" then
		return
	end
	localQueue[player] = nil
	if player.Parent then
		setQueueState(player, "Idle")
	end
	if not queueMap then
		return
	end
	task.spawn(function()
		pcall(function()
			queueMap:RemoveAsync(queueKey(player.UserId))
		end)
		-- Si une paire venait d'être formée, l'adversaire verra le match annulé (sans perte de MMR).
		pcall(function()
			assignments:RemoveAsync(queueKey(player.UserId))
		end)
	end)
end

-- Gains d'absence du mode solo : heure (os.time()) du départ vers le match, dans les données du joueur.
-- Elle part avec la sauvegarde faite quand il quitte ce serveur ; à son retour sur la map principale,
-- le temps passé en match rapporte des pièces au revenu normal (Hub/init.luau). 0 = pas de départ
-- (téléportation ratée). Rien ne change dans le match lui-même.
local function setMatchDeparture(player: Player, time: number)
	local data = PlayerData.get(player)
	if data and typeof(data.idle) == "table" then
		data.idle.matchDepartureAt = time
	end
end

local function teleportToMatch(player: Player, assignment)
	local entry = localQueue[player]
	if not entry or entry.state ~= "Searching" then
		return
	end
	entry.state = "Teleporting"
	setQueueState(player, "Found")
	notify:FireClient(player, `Adversaire trouvé ! ({assignment.opponentMmr} MMR)`, "Success")
	setMatchDeparture(player, os.time())

	pcall(function()
		assignments:RemoveAsync(queueKey(player.UserId))
	end)

	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = assignment.accessCode

	for attempt = 1, 3 do
		local ok, err = pcall(function()
			TeleportService:TeleportAsync(game.PlaceId, { player }, options)
		end)
		if ok then
			return
		end
		warn(`[Matchmaking] Téléportation échouée (essai {attempt}) :`, err)
		task.wait(attempt)
		if not player.Parent then
			return
		end
	end

	localQueue[player] = nil
	setMatchDeparture(player, 0)
	setQueueState(player, "Idle")
	notify:FireClient(player, "La téléportation a échoué. Relance une recherche.", "Error")
end

-- Garde l'entrée de la file en vie. UpdateAsync ne recrée PAS une entrée supprimée par le
-- leader (sinon un joueur déjà apparié pourrait être apparié une deuxième fois).
local function refreshEntry(player: Player)
	local found = false
	local ok = pcall(function()
		queueMap:UpdateAsync(queueKey(player.UserId), function(value, sortKey)
			found = value ~= nil
			if value == nil then
				return nil
			end
			return value, sortKey
		end, MM.QUEUE_ENTRY_TTL)
	end)
	if not ok or found then
		return
	end

	-- Entrée disparue : soit le joueur vient d'être apparié (l'assignation existe déjà car le
	-- leader l'écrit AVANT de retirer l'entrée), soit elle a expiré -> on la remet.
	local okAssignment, assignment = pcall(function()
		return assignments:GetAsync(queueKey(player.UserId))
	end)
	if okAssignment and assignment then
		teleportToMatch(player, assignment)
		return
	end
	local data = PlayerData.get(player)
	local entry = localQueue[player]
	if data and entry and entry.state == "Searching" then
		pcall(function()
			local value = { userId = player.UserId, mmr = data.mmr, joinedAt = entry.joinedAt, jobId = game.JobId }
			queueMap:SetAsync(queueKey(player.UserId), value, MM.QUEUE_ENTRY_TTL, data.mmr)
		end)
	end
end

local function pollAssignment(player: Player)
	local ok, assignment = pcall(function()
		return assignments:GetAsync(queueKey(player.UserId))
	end)
	if ok and assignment then
		teleportToMatch(player, assignment)
	end
end

local function searchingPlayers()
	local list = {}
	for player, entry in localQueue do
		if entry.state == "Searching" and player.Parent then
			table.insert(list, player)
		end
	end
	return list
end

----------------------------------------------------------------------
-- Côté leader (un seul serveur à la fois forme les paires)
----------------------------------------------------------------------

local function tryBecomeLeader(): boolean
	local ok, result = pcall(function()
		return leaderMap:UpdateAsync("leader", function(current)
			if current == nil or current == game.JobId then
				return game.JobId
			end
			return nil
		end, MM.LEADER_TTL)
	end)
	return ok and result == game.JobId
end

local function readQueue()
	local entries = {}
	local lowerBound = nil
	for _ = 1, 5 do -- jusqu'à 1000 joueurs en file
		local ok, items = pcall(function()
			return queueMap:GetRangeAsync(Enum.SortDirection.Ascending, 200, lowerBound)
		end)
		if not ok then
			warn("[Matchmaking] Lecture de la file impossible :", items)
			return nil
		end
		for _, item in items do
			table.insert(entries, item.value)
		end
		if #items < 200 then
			break
		end
		local last = items[#items]
		lowerBound = { key = last.key, sortKey = last.sortKey }
	end
	return entries
end

local function createMatch(a, b): boolean
	local ok, accessCode, privateServerId = pcall(function()
		return TeleportService:ReserveServer(game.PlaceId)
	end)
	if not ok then
		warn("[Matchmaking] ReserveServer a échoué :", accessCode)
		return false
	end

	local matchId = HttpService:GenerateGUID(false)
	local info = {
		matchId = matchId,
		players = { a.userId, b.userId },
		mmr = { [tostring(a.userId)] = a.mmr, [tostring(b.userId)] = b.mmr },
		createdAt = os.time(),
	}
	local okInfo, errInfo = pcall(function()
		matchInfos:SetAsync(privateServerId, info, MM.MATCH_INFO_TTL)
	end)
	if not okInfo then
		warn("[Matchmaking] Impossible d'enregistrer le match :", errInfo)
		return false
	end

	-- Ordre important : assignations d'abord, suppression de la file ensuite.
	for _, pair in { { a, b }, { b, a } } do
		local player, opponent = pair[1], pair[2]
		pcall(function()
			assignments:SetAsync(queueKey(player.userId), {
				matchId = matchId,
				accessCode = accessCode,
				opponentId = opponent.userId,
				opponentMmr = opponent.mmr,
			}, MM.ASSIGNMENT_TTL)
		end)
	end
	for _, player in { a, b } do
		pcall(function()
			queueMap:RemoveAsync(queueKey(player.userId))
		end)
	end

	print(`[Matchmaking] Match {matchId} : {a.userId} ({a.mmr}) vs {b.userId} ({b.mmr})`)
	return true
end

local function runMatcher()
	local entries = readQueue()
	if not entries or #entries < 2 then
		return
	end

	-- Les entrées sont triées par MMR : on apparie les voisins si l'écart est acceptable.
	local now = os.time()
	local i = 1
	while i < #entries do
		local a, b = entries[i], entries[i + 1]
		local range = math.max(searchRange(now - a.joinedAt), searchRange(now - b.joinedAt))
		if a.userId ~= b.userId and math.abs(a.mmr - b.mmr) <= range then
			createMatch(a, b)
			i += 2
		else
			i += 1
		end
	end
end

----------------------------------------------------------------------

function Matchmaking.start()
	Players.PlayerRemoving:Connect(function(player)
		Matchmaking.leave(player)
		localQueue[player] = nil
	end)

	if RunService:IsStudio() then
		return -- pas de MemoryStore/téléportation utiles dans Studio
	end

	local ok, err = pcall(function()
		queueMap = MemoryStoreService:GetSortedMap("RankedTD_Queue_S" .. Config.SEASON)
		assignments = MemoryStoreService:GetHashMap("RankedTD_Assignments")
		matchInfos = MemoryStoreService:GetHashMap("RankedTD_Matches")
		leaderMap = MemoryStoreService:GetHashMap("RankedTD_Leader")
	end)
	if not ok then
		warn("[Matchmaking] MemoryStoreService indisponible :", err)
		queueMap = nil
		return
	end

	-- Suivi des joueurs locaux : assignations + maintien de l'entrée dans la file.
	task.spawn(function()
		local sinceRefresh = 0
		while true do
			task.wait(MM.ASSIGNMENT_POLL_INTERVAL)
			sinceRefresh += MM.ASSIGNMENT_POLL_INTERVAL
			local refresh = sinceRefresh >= MM.QUEUE_REFRESH_INTERVAL
			if refresh then
				sinceRefresh = 0
			end
			for _, player in searchingPlayers() do
				task.spawn(function()
					if refresh then
						refreshEntry(player)
					else
						pollAssignment(player)
					end
				end)
			end
		end
	end)

	-- Boucle du leader.
	task.spawn(function()
		while true do
			task.wait(MM.MATCHER_INTERVAL)
			if tryBecomeLeader() then
				runMatcher()
			end
		end
	end)

	TeleportService.TeleportInitFailed:Connect(function(player, _result, message)
		local entry = localQueue[player]
		if entry and entry.state == "Teleporting" then
			warn("[Matchmaking] TeleportInitFailed :", message)
			localQueue[player] = nil
			setMatchDeparture(player, 0)
			setQueueState(player, "Idle")
			notify:FireClient(player, "La téléportation a échoué. Relance une recherche.", "Error")
		end
	end)
end

return Matchmaking

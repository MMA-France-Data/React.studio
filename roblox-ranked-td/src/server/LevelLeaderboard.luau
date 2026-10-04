-- CLASSEMENT DES NIVEAUX, de tous les temps et sur tous les serveurs. Demande du propriétaire (04/10/2026) : « rajoute
-- les panneaux au centre avec les niveaux des joueurs ». Les joueurs sont rangés par plus haut niveau réussi, puis par
-- nombre de victoires (Levels.boardScore). Affiché par Hub/LevelBoard.luau sur les deux panneaux de la place, avec la
-- liste des joueurs du serveur. Repris du classement solo de l'ancien jeu (étiquette git ancien-jeu-complet).
--
-- Un OrderedDataStore (STORE_NAME ; clé = UserId du joueur, en texte ; valeur = son score). Limites des DataStores
-- (par serveur et par minute : 60 + 10 x joueurs écritures, 5 + 2 x joueurs lectures triées) :
--   * un joueur n'est envoyé que si son score a MONTÉ depuis son dernier envoi, au plus une fois par minute
--     (SUBMIT_INTERVAL), et à son départ. UpdateAsync ne remplace jamais une valeur plus haute (écrite par un autre
--     serveur ou une session d'avant) : le classement garde le meilleur de chacun ;
--   * le classement est relu toutes les minutes (REFRESH_INTERVAL) : un seul GetSortedAsync.
-- Les joueurs du serveur sont relus toutes les CHECK_INTERVAL secondes (rien n'est écrit sans hausse).
-- Dans Studio : DataStore en mémoire (Config.Data.MOCK_IN_STUDIO), vide à chaque Play.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserService = game:GetService("UserService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Levels = require(Shared.Levels)
local MockDataStore = require(script.Parent.MockDataStore)

local LevelLeaderboard = {}

LevelLeaderboard.STORE_NAME = "LevelsTop"
LevelLeaderboard.SIZE = 10 -- joueurs affichés
LevelLeaderboard.SUBMIT_INTERVAL = 60 -- au plus un envoi par minute et par joueur (plus un à son départ)
LevelLeaderboard.CHECK_INTERVAL = 5 -- les joueurs du serveur sont relus toutes les 5 s
LevelLeaderboard.REFRESH_INTERVAL = 60 -- le classement est relu toutes les minutes

local useMock = RunService:IsStudio() and Config.Data.MOCK_IN_STUDIO
local store = if useMock then MockDataStore.newOrdered() else DataStoreService:GetOrderedDataStore(LevelLeaderboard.STORE_NAME)

local tracked = {} -- [Player] = { score = meilleur score vu, sent = score déjà écrit, lastSend = heure du dernier envoi }
local getValues = nil -- function(player) -> (plus haut niveau réussi, victoires), ou nil (données pas encore chargées)
local showEntries = nil -- function(kind, entries) : met un tableau à jour ("Top" : tous les serveurs, "Server" : ce serveur)
local nameCache = {} -- [UserId] = nom affiché
local serverShown = nil -- la liste du serveur affichée en dernier (en texte : rien à refaire si elle n'a pas changé)
local clockOffset = 0 -- tests Studio : décale l'horloge des envois (« une minute plus tard »)
local fakeKeys = {} -- tests Studio : clés des faux joueurs écrits dans le classement
local pendingSends = 0 -- envois partis mais pas encore finis (attendus à l'arrêt du serveur)

local function now(): number
	return os.clock() + clockOffset
end

-- Note le score actuel du joueur (on ne garde que le meilleur) et renvoie son suivi.
local function remember(player: Player, best: any, wins: any)
	local entry = tracked[player]
	if not entry then
		entry = { score = 0, sent = 0, lastSend = -math.huge }
		tracked[player] = entry
	end
	entry.score = math.max(entry.score, Levels.boardScore(best, wins) or 0)
	return entry
end

-- Écrit `value` pour ce joueur, sauf s'il y a déjà mieux (UpdateAsync : une seule décision). Renvoie vrai si c'est fait
-- (écrit, ou déjà mieux). Yield.
local function keepBest(userId: number, value: number): boolean
	local ok, err = pcall(function()
		store:UpdateAsync(tostring(userId), function(old)
			if type(old) == "number" and old >= value then
				return nil -- déjà mieux (autre serveur, session d'avant) : rien à écrire
			end
			return value
		end)
	end)
	if not ok then
		warn("[LevelLeaderboard] Envoi impossible :", err)
	end
	return ok
end

-- Envoie le score s'il a monté depuis le dernier envoi, dans une tâche à part (ne bloque rien). En cas d'échec, il
-- reste « à envoyer » : nouvel essai au prochain envoi permis (une minute plus tard).
local function send(player: Player, entry)
	entry.lastSend = now()
	local value = entry.score
	if value <= entry.sent then
		return
	end
	local userId = player.UserId
	task.spawn(function()
		pendingSends += 1
		if keepBest(userId, value) then
			entry.sent = math.max(entry.sent, value)
		end
		pendingSends -= 1
	end)
end

-- Noms affichés : ceux des joueurs de ce serveur d'abord, puis une seule demande à Roblox pour les autres. Gardés en
-- mémoire. Renvoie { [userId] = nom } (« Joueur 123 » si introuvable). Yield.
local function names(userIds: { number }): { [number]: string }
	local missing = {}
	for _, userId in userIds do
		if not nameCache[userId] then
			local player = Players:GetPlayerByUserId(userId)
			if player then
				nameCache[userId] = player.DisplayName
			elseif userId > 0 then
				table.insert(missing, userId)
			end
		end
	end
	if #missing > 0 then
		local ok, infos = pcall(function()
			return UserService:GetUserInfosByUserIdsAsync(missing)
		end)
		if ok then
			for _, info in infos do
				nameCache[info.Id] = info.DisplayName
			end
		end
	end
	local result = {}
	for _, userId in userIds do
		result[userId] = nameCache[userId] or ("Joueur " .. userId)
	end
	return result
end

local function display(kind: string, entries)
	if showEntries then
		local ok, err = pcall(showEntries, kind, entries)
		if not ok then
			warn("[LevelLeaderboard] Affichage impossible :", err)
		end
	end
end

-- Les joueurs du serveur dont les données sont chargées : { { userId, name, best, wins } }, du meilleur au moins bon
-- (même ordre que le classement ; un joueur qui n'a encore réussi aucun niveau est en bas).
local function serverEntries()
	local entries = {}
	for _, player in Players:GetPlayers() do
		local best, wins = getValues(player)
		if best ~= nil then
			table.insert(entries, {
				userId = player.UserId,
				name = player.DisplayName,
				best = math.floor(tonumber(best) or 0),
				wins = math.floor(tonumber(wins) or 0),
				score = Levels.boardScore(best, wins) or 0,
			})
		end
	end
	table.sort(entries, function(a, b)
		if a.score ~= b.score then
			return a.score > b.score
		end
		return a.name < b.name
	end)
	return entries
end

-- Un passage : relit le score de chaque joueur et envoie ceux qui ont monté (au plus une fois par SUBMIT_INTERVAL),
-- puis remet à jour le tableau du serveur s'il a changé.
local function step()
	for _, player in Players:GetPlayers() do
		local best, wins = getValues(player)
		if best ~= nil then
			local entry = remember(player, best, wins)
			if entry.score > entry.sent and now() - entry.lastSend >= LevelLeaderboard.SUBMIT_INTERVAL then
				send(player, entry)
			end
		end
	end
	local entries = serverEntries()
	local parts = {}
	for _, entry in entries do
		table.insert(parts, `{entry.userId}:{entry.name}:{entry.best}:{entry.wins}`)
	end
	local signature = table.concat(parts, "|")
	if signature ~= serverShown then
		serverShown = signature
		display("Server", entries)
	end
end

-- Les SIZE meilleurs de tous les serveurs : { { userId, name, best, wins } } du meilleur au moins bon, ou nil si la
-- lecture échoue. Yield.
local function fetchTop()
	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, LevelLeaderboard.SIZE)
	end)
	if not ok then
		warn("[LevelLeaderboard] Lecture impossible :", pages)
		return nil
	end
	local entries, userIds = {}, {}
	for _, item in pages:GetCurrentPage() do
		local userId = tonumber(item.key) or 0
		local best, wins = Levels.fromBoardScore(item.value)
		table.insert(entries, { userId = userId, best = best, wins = wins })
		table.insert(userIds, userId)
	end
	local found = names(userIds)
	for _, entry in entries do
		entry.name = found[entry.userId]
	end
	return entries
end

-- Relit le classement et l'affiche (illisible, en panne : l'affichage d'avant reste). Renvoie les entrées. Yield.
local function refresh()
	local entries = fetchTop()
	if entries then
		display("Top", entries)
	end
	return entries
end

-- Le joueur s'en va (Hub/init.luau, juste avant sa sauvegarde finale ; ne bloque pas) : son dernier score, envoyé tout
-- de suite s'il a monté (même moins d'une minute après son dernier envoi).
function LevelLeaderboard.leave(player: Player, best: any, wins: any)
	local entry = remember(player, best, wins)
	tracked[player] = nil
	if entry.score > entry.sent then
		send(player, entry)
	end
end

-- values(player) -> (plus haut niveau réussi, victoires), ou nil ; show(kind, entries) met un tableau à jour (kind =
-- "Top" ou "Server", entries = { { name, best, wins } } du meilleur au moins bon). Appelée une fois par Hub/init.luau.
function LevelLeaderboard.start(values, show)
	getValues, showEntries = values, show
	-- Oublié un peu après son départ : LevelLeaderboard.leave (appelé pendant le départ) passe d'abord.
	Players.PlayerRemoving:Connect(function(player)
		task.delay(5, function()
			tracked[player] = nil
		end)
	end)
	-- Arrêt du serveur : les derniers envois (départ des joueurs) ont le temps de finir (10 s au plus).
	game:BindToClose(function()
		task.wait(0.5) -- (le temps que PlayerData fasse partir les joueurs, donc leurs envois)
		local deadline = os.clock() + 10
		while pendingSends > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
	task.spawn(function()
		while true do
			local ok, err = pcall(step)
			if not ok then
				warn("[LevelLeaderboard] Erreur :", err)
			end
			task.wait(LevelLeaderboard.CHECK_INTERVAL)
		end
	end)
	task.spawn(function()
		while true do
			refresh()
			task.wait(LevelLeaderboard.REFRESH_INTERVAL)
		end
	end)
end

-- Tests Studio (StudioDebug « Board », Hub/init.luau ; jamais dans le jeu publié, où StudioDebug n'existe pas) :
--   "State"              -> { mock, score, sent, sinceSend } du joueur ; seulement { mock } s'il n'est pas encore suivi
--   "Tick"               -> un passage de la boucle (envois et tableau du serveur), tout de suite
--   "Clock", secondes    -> avance l'horloge des envois (61 = « une minute plus tard », 0 = remise à l'heure) ; renvoie
--                           le décalage
--   "Stored"             -> le score du joueur dans le classement (nil s'il n'y est pas)
--   "Refresh"            -> relit le classement et met le tableau à jour tout de suite ; renvoie ses entrées
--   "Fake", liste        -> faux joueurs { userId (négatif), name, best, wins } écrits dans le classement (DataStore en
--                           mémoire seulement : refusé avec le vrai) ; renvoie vrai
--   "ClearFakes"         -> faux joueurs retirés du classement et leurs noms oubliés
function LevelLeaderboard.debug(player: Player, action: string, ...)
	local first = ...
	if action == "State" then
		local entry = tracked[player]
		if not entry then
			return { mock = useMock }
		end
		return { mock = useMock, score = entry.score, sent = entry.sent, sinceSend = now() - entry.lastSend }
	elseif action == "Tick" then
		step()
		return true
	elseif action == "Clock" then
		clockOffset = if first == 0 then 0 else clockOffset + (tonumber(first) or 0)
		return clockOffset
	elseif action == "Stored" then
		local ok, value = pcall(function()
			return store:GetAsync(tostring(player.UserId))
		end)
		return if ok then value else nil
	elseif action == "Refresh" then
		return refresh()
	elseif action == "Fake" then
		if not useMock then
			return false -- jamais de faux joueurs dans le vrai classement
		end
		for _, fake in if type(first) == "table" then first else {} do
			local key = tostring(fake.userId)
			local score = Levels.boardScore(fake.best, fake.wins)
			if score then
				store:SetAsync(key, score)
			end
			nameCache[fake.userId] = fake.name
			fakeKeys[key] = fake.userId
		end
		return true
	elseif action == "ClearFakes" then
		if useMock then
			for key, userId in fakeKeys do
				store:RemoveAsync(key)
				nameCache[userId] = nil
			end
		end
		table.clear(fakeKeys)
		return true
	end
	return nil
end

return LevelLeaderboard

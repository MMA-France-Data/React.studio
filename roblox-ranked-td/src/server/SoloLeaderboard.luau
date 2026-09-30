-- Classement SOLO (mode infini) : de tous les temps et sur tous les serveurs. Séparé du classement ranked
-- (Leaderboard.luau, un par saison) : les saisons n'y touchent jamais. Affiché par Hub/SoloBoard.luau.
--
-- Deux OrderedDataStore (clé = UserId du joueur, en texte) :
--   « RankedTD_SoloWave » : record de vague de tous les temps (data.idle.highestWave, un nombre entier) ;
--   « RankedTD_SoloDps »  : meilleur DPS total de sa parcelle (PlotGame:totalDps, le nombre de « DPS TOTAL » du tableau
--                           du fief et de la colonne « DPS »), gardé en CODE.
-- Pourquoi un code : un OrderedDataStore ne garde que des nombres entiers (jusqu'à ~9,2e18) et un DPS peut dépasser
-- 1e100. Le code = exposant x 1000 + ses 3 premiers chiffres (NumberFormat.toRankCode : 1 234 567 -> 6123). Le tri
-- reste juste, et le tableau réaffiche exactement ce que montre NumberFormat.short (« 1.23M ») avec
-- NumberFormat.fromRankCode, sans rien lire d'autre (pas de 2e DataStore à relire).
--
-- Limites des DataStores (par serveur et par minute : 60 + 10 x joueurs écritures, 5 + 2 x joueurs lectures triées) :
--   * un joueur n'est envoyé que si son record ou son DPS a MONTÉ depuis son dernier envoi, au plus une fois par minute
--     (SUBMIT_INTERVAL), et à son départ. UpdateAsync ne remplace jamais une valeur plus haute (écrite par un autre
--     serveur ou une session d'avant) : le classement garde le meilleur de chacun ;
--   * le tableau est relu toutes les minutes (REFRESH_INTERVAL) : un seul GetSortedAsync par classement.
-- Dans Studio : DataStores en mémoire (Config.Data.MOCK_IN_STUDIO, comme le classement ranked), vides à chaque Play.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local NumberFormat = require(Shared.NumberFormat)
local Leaderboard = require(script.Parent.Leaderboard)
local MockDataStore = require(script.Parent.MockDataStore)

local SoloLeaderboard = {}

SoloLeaderboard.SIZE = 10 -- joueurs affichés dans chaque classement
SoloLeaderboard.SUBMIT_INTERVAL = 60 -- au plus un envoi par minute et par joueur (plus un à son départ)
SoloLeaderboard.CHECK_INTERVAL = 5 -- les valeurs des joueurs sont relues toutes les 5 s (rien n'est écrit sans hausse)
SoloLeaderboard.REFRESH_INTERVAL = 60 -- le tableau est relu toutes les minutes
SoloLeaderboard.KINDS = { "Wave", "Dps" } -- les deux classements : record de vague, DPS

local useMock = RunService:IsStudio() and Config.Data.MOCK_IN_STUDIO
local stores = {
	Wave = if useMock then MockDataStore.newOrdered() else DataStoreService:GetOrderedDataStore("RankedTD_SoloWave"),
	Dps = if useMock then MockDataStore.newOrdered() else DataStoreService:GetOrderedDataStore("RankedTD_SoloDps"),
}

-- Joueurs suivis : [Player] = { Wave = meilleur record vu, Dps = meilleur code DPS vu,
--   sent = { Wave, Dps } (déjà écrits dans le classement), lastSend = heure du dernier envoi (voir now) }
local tracked = {}
local getValues = nil -- function(player) -> (record de vague, DPS total) de sa parcelle, ou nil (pas de parcelle)
local showEntries = nil -- function(kind, entries) : met le tableau à jour
local clockOffset = 0 -- tests Studio : décale l'horloge des envois (« une minute plus tard »)
local fakeKeys = {} -- tests Studio : clés des faux joueurs écrits dans les classements
local pendingSends = 0 -- envois partis mais pas encore finis (attendus à l'arrêt du serveur)

local function now(): number
	return os.clock() + clockOffset
end

-- Record de vague à classer (nombre entier >= 1, sinon nil) et code du DPS (nil si DPS < 1 : aucune tour).
local function cleanValues(wave: any, dps: any): (number?, number?)
	local cleanWave = if type(wave) == "number" and wave == wave and wave >= 1 and wave < 2 ^ 53 then math.floor(wave) else nil
	return cleanWave, NumberFormat.toRankCode(dps)
end

-- Note les valeurs actuelles du joueur (on ne garde que les meilleures) et renvoie son suivi.
local function remember(player: Player, wave: any, dps: any)
	local entry = tracked[player]
	if not entry then
		entry = { Wave = 0, Dps = 0, sent = { Wave = 0, Dps = 0 }, lastSend = -math.huge }
		tracked[player] = entry
	end
	local cleanWave, dpsCode = cleanValues(wave, dps)
	if cleanWave then
		entry.Wave = math.max(entry.Wave, cleanWave)
	end
	if dpsCode then
		entry.Dps = math.max(entry.Dps, dpsCode)
	end
	return entry
end

local function improved(entry): boolean
	return entry.Wave > entry.sent.Wave or entry.Dps > entry.sent.Dps
end

-- Écrit `value` pour ce joueur dans un classement, sauf s'il y a déjà mieux (UpdateAsync : une seule décision).
-- Renvoie vrai si c'est fait (écrit, ou déjà mieux). Yield.
local function keepBest(kind: string, userId: number, value: number): boolean
	local ok, err = pcall(function()
		stores[kind]:UpdateAsync(tostring(userId), function(old)
			if type(old) == "number" and old >= value then
				return nil -- déjà mieux (autre serveur, session d'avant) : rien à écrire
			end
			return value
		end)
	end)
	if not ok then
		warn(`[SoloLeaderboard] Envoi impossible ({kind}) :`, err)
	end
	return ok
end

-- Envoie ce qui a monté depuis le dernier envoi, dans une tâche à part (ne bloque rien). En cas d'échec, la valeur
-- reste « à envoyer » : nouvel essai au prochain envoi permis (une minute plus tard).
local function send(player: Player, entry)
	entry.lastSend = now()
	local userId = player.UserId
	for _, kind in SoloLeaderboard.KINDS do
		local value = entry[kind]
		if value > entry.sent[kind] then
			task.spawn(function()
				pendingSends += 1
				if keepBest(kind, userId, value) then
					entry.sent[kind] = math.max(entry.sent[kind], value)
				end
				pendingSends -= 1
			end)
		end
	end
end

-- Un passage : relit les valeurs de chaque joueur et envoie celles qui ont monté, au plus une fois par SUBMIT_INTERVAL.
local function step()
	for _, player in Players:GetPlayers() do
		local wave, dps = getValues(player)
		if wave ~= nil then
			local entry = remember(player, wave, dps)
			if improved(entry) and now() - entry.lastSend >= SoloLeaderboard.SUBMIT_INTERVAL then
				send(player, entry)
			end
		end
	end
end

-- Les SIZE meilleurs d'un classement : { { userId, name, value } } du meilleur au moins bon (value = record de vague,
-- ou DPS retrouvé depuis son code). nil si la lecture échoue. Yield.
local function fetchTop(kind: string)
	local ok, pages = pcall(function()
		return stores[kind]:GetSortedAsync(false, SoloLeaderboard.SIZE)
	end)
	if not ok then
		warn(`[SoloLeaderboard] Lecture impossible ({kind}) :`, pages)
		return nil
	end
	local entries, userIds = {}, {}
	for _, item in pages:GetCurrentPage() do
		local userId = tonumber(item.key) or 0
		local value = if kind == "Dps" then NumberFormat.fromRankCode(item.value) else item.value
		table.insert(entries, { userId = userId, value = value })
		table.insert(userIds, userId)
	end
	local names = Leaderboard.names(userIds)
	for _, entry in entries do
		entry.name = names[entry.userId]
	end
	return entries
end

-- Relit les deux classements et les affiche. Un classement illisible (panne) garde son affichage d'avant.
-- Renvoie { Wave = entrées, Dps = entrées } (tests Studio). Yield.
local function refresh()
	local shown = {}
	for _, kind in SoloLeaderboard.KINDS do
		local entries = fetchTop(kind)
		if entries then
			shown[kind] = entries
			if showEntries then
				local ok, err = pcall(showEntries, kind, entries)
				if not ok then
					warn("[SoloLeaderboard] Affichage impossible :", err)
				end
			end
		end
	end
	return shown
end

-- Le joueur s'en va (Hub/init.luau, juste avant de fermer sa parcelle ; ne bloque pas) : ses dernières valeurs, envoyées
-- tout de suite si elles ont monté (même moins d'une minute après son dernier envoi).
function SoloLeaderboard.leave(player: Player, wave: any, dps: any)
	local entry = remember(player, wave, dps)
	tracked[player] = nil
	if improved(entry) then
		send(player, entry)
	end
end

-- values(player) -> (record de vague, DPS total) de sa parcelle, ou nil ; show(kind, entries) met le tableau à jour
-- (kind = "Wave" ou "Dps", entries = liste de fetchTop). Appelée une fois par Hub/init.luau.
function SoloLeaderboard.start(values, show)
	getValues, showEntries = values, show
	-- Oublié un peu après son départ : SoloLeaderboard.leave (appelé pendant le départ) passe d'abord.
	Players.PlayerRemoving:Connect(function(player)
		task.delay(5, function()
			tracked[player] = nil
		end)
	end)
	-- Arrêt du serveur : les derniers envois (départ des joueurs, PlayerData.luau) ont le temps de finir (10 s au plus).
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
				warn("[SoloLeaderboard] Erreur :", err)
			end
			task.wait(SoloLeaderboard.CHECK_INTERVAL)
		end
	end)
	task.spawn(function()
		while true do
			refresh()
			task.wait(SoloLeaderboard.REFRESH_INTERVAL)
		end
	end)
end

-- Tests Studio (StudioDebug « Solo », Hub/init.luau ; jamais dans le jeu publié, où StudioDebug n'existe pas) :
--   "State"               -> { mock, Wave, Dps, sentWave, sentDps, sinceSend } du joueur (codes DPS) ; seulement { mock }
--                            s'il n'est pas encore suivi (mock = DataStores en mémoire)
--   "Tick"                -> un passage de la boucle des envois, tout de suite (au lieu d'attendre CHECK_INTERVAL)
--   "Clock", secondes     -> avance l'horloge des envois (61 = « une minute plus tard », 0 = remise à l'heure) ; renvoie
--                            le décalage
--   "Submit", vague, dps  -> écrit ces valeurs pour le joueur comme un envoi (jamais plus bas que le classement ;
--                            DataStores en mémoire seulement)
--   "Stored"              -> { Wave, Dps } du joueur dans les deux classements (Dps = code)
--   "Refresh"             -> relit les classements et met le tableau à jour tout de suite ; renvoie { Wave, Dps }
--   "Fake", liste         -> faux joueurs { userId (négatif), name, wave, dps } écrits dans les classements (DataStores en
--                            mémoire seulement : refusé avec les vrais) ; renvoie vrai
--   "ClearFakes"          -> faux joueurs retirés des classements et leurs noms oubliés
function SoloLeaderboard.debug(player: Player, action: string, ...)
	local key = tostring(player.UserId)
	local first = ...
	if action == "State" then
		local entry = tracked[player]
		if not entry then
			return { mock = useMock }
		end
		return {
			mock = useMock,
			Wave = entry.Wave,
			Dps = entry.Dps,
			sentWave = entry.sent.Wave,
			sentDps = entry.sent.Dps,
			sinceSend = now() - entry.lastSend,
		}
	elseif action == "Tick" then
		step()
		return true
	elseif action == "Clock" then
		clockOffset = if first == 0 then 0 else clockOffset + (tonumber(first) or 0)
		return clockOffset
	elseif action == "Submit" then
		if not useMock then
			return false -- jamais de valeurs inventées dans les vrais classements
		end
		local wave, dpsCode = cleanValues(...)
		if wave then
			keepBest("Wave", player.UserId, wave)
		end
		if dpsCode then
			keepBest("Dps", player.UserId, dpsCode)
		end
		return true
	elseif action == "Stored" then
		local result = {}
		for _, kind in SoloLeaderboard.KINDS do
			local ok, value = pcall(function()
				return stores[kind]:GetAsync(key)
			end)
			result[kind] = if ok then value else nil
		end
		return result
	elseif action == "Refresh" then
		return refresh()
	elseif action == "Fake" then
		if not useMock then
			return false -- jamais de faux joueurs dans les vrais classements
		end
		for _, fake in if type(first) == "table" then first else {} do
			local fakeKey = tostring(fake.userId)
			local wave, dpsCode = cleanValues(fake.wave, fake.dps)
			if wave then
				stores.Wave:SetAsync(fakeKey, wave)
			end
			if dpsCode then
				stores.Dps:SetAsync(fakeKey, dpsCode)
			end
			Leaderboard.rememberName(fake.userId, fake.name)
			fakeKeys[fakeKey] = fake.userId
		end
		return true
	elseif action == "ClearFakes" then
		if useMock then
			for fakeKey, userId in fakeKeys do
				stores.Wave:RemoveAsync(fakeKey)
				stores.Dps:RemoveAsync(fakeKey)
				Leaderboard.rememberName(userId, nil)
			end
		end
		table.clear(fakeKeys)
		return true
	end
	return nil
end

return SoloLeaderboard

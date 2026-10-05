-- Sauvegarde des joueurs avec verrou de session : un seul serveur à la fois peut écrire les données d'un joueur
-- (un joueur qui change de serveur ne risque pas de voir ses progrès écrasés par l'ancien).
-- Chaque sauvegarde garde aussi la version du jeu qui l'a écrite (numéro de publication du lieu) : un ANCIEN serveur,
-- resté ouvert après une mise à jour, ne charge jamais des données écrites par une version plus récente (il ne
-- connaît pas tout ce qu'elles contiennent : sa remise en ordre, Levels.cleanData, effacerait les nouvelles tours,
-- les nouveaux œufs...) ; le joueur est invité à rejoindre une nouvelle partie.
-- Un joueur qui revient sur le même serveur pendant la sauvegarde finale de sa visite d'avant attend qu'elle soit
-- finie (sinon il chargerait des données d'avant cette sauvegarde).
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Lang = require(Shared.Lang) -- (messages de player:Kick : l'écran du joueur ne peut pas les traduire)
local Levels = require(Shared.Levels)
local Remotes = require(Shared.Remotes)
local Sounds = require(Shared.Sounds)
local MockDataStore = require(script.Parent.MockDataStore)

local PlayerData = {}

local useMock = RunService:IsStudio() and Config.Data.MOCK_IN_STUDIO
local store = if useMock then MockDataStore.new() else DataStoreService:GetDataStore(Config.Data.DATASTORE_NAME)

local profiles = {} -- [Player] = { data = table }
local releasing = {} -- [UserId] = nombre de sauvegardes finales (départs) en cours pour lui
local RELEASE_WAIT = 30 -- secondes d'attente au plus, à son arrivée, de la sauvegarde finale de sa visite d'avant
-- Version du jeu de ce serveur (numéro de publication du lieu). 0 dans Studio : pas de garde (tests : debug).
local placeVersion = if RunService:IsStudio() then 0 else game.PlaceVersion
local lastSettingAt = {} -- [Player] = heure du dernier réglage reçu (remote « Settings »)
local loadedCallbacks = {}
local beforeReleaseCallbacks = {}
local pendingWrites = 0

local function defaultData()
	return {
		-- Bouton « SON » : "All" (musique + effets), "Effects" (effets seuls) ou "Mute" (Sounds.MODES).
		soundMode = "All",
		-- NIVEAUX : plus haut niveau réussi, pièces de niveau, tours sorties des œufs, entraînement du camp
		-- (format : Shared/Levels.luau, « Données sauvegardées »).
		levels = Levels.defaultData(),
	}
end

-- Complète les champs manquants (utile quand tu ajoutes des champs plus tard) et nettoie les valeurs abîmées.
local function reconcile(data)
	for key, value in defaultData() do
		if data[key] == nil then
			data[key] = value
		end
	end
	if not table.find(Sounds.MODES, data.soundMode) then
		data.soundMode = "All"
	end
	data.levels = Levels.cleanData(data.levels)
	return data
end

local function keyFor(userId: number): string
	return "Player_" .. userId
end

-- Vrai si ces données ont été écrites par une version du jeu plus récente que ce serveur.
local function writtenByNewer(record): boolean
	return placeVersion > 0 and (tonumber(record.placeVersion) or 0) > placeVersion
end

-- Prend le verrou et lit les données. Retourne (ok, data, raison) ; data = nil pour un nouveau joueur ; raison =
-- "outdated" si ses données viennent d'une version du jeu plus récente que ce serveur (rien n'est pris ni écrit).
local function acquire(userId: number): (boolean, any, string?)
	local key = keyFor(userId)
	for attempt = 1, Config.Data.LOAD_RETRIES + 1 do
		local force = attempt > Config.Data.LOAD_RETRIES
		local lockedByOther = false
		local newer = false

		local ok, result = pcall(function()
			return store:UpdateAsync(key, function(record)
				lockedByOther = false
				newer = false
				record = record or {}
				if writtenByNewer(record) then
					newer = true
					return nil -- annule l'écriture
				end
				local lock = record.lock
				local lockIsFresh = lock and os.time() - (lock.time or 0) < Config.Data.LOCK_EXPIRY
				if not force and lock and lock.jobId ~= game.JobId and lockIsFresh then
					lockedByOther = true
					return nil -- annule l'écriture
				end
				record.lock = { jobId = game.JobId, time = os.time() }
				return record
			end)
		end)

		if ok and newer then
			warn(`[PlayerData] {userId} : données d'une version du jeu plus récente que ce serveur (version {placeVersion})`)
			return false, nil, "outdated"
		elseif ok and result then
			return true, result.data
		elseif not ok then
			warn(`[PlayerData] Chargement échoué pour {userId} (essai {attempt}) : {result}`)
		elseif lockedByOther then
			print(`[PlayerData] {userId} encore verrouillé par un autre serveur, nouvel essai...`)
		end
		task.wait(Config.Data.LOAD_RETRY_DELAY)
	end
	return false, nil
end

-- Écrit les données si on possède toujours le verrou. release = rend le verrou.
-- Retourne (succès, verrouPerdu).
local function write(userId: number, data, release: boolean): (boolean, boolean)
	pendingWrites += 1
	local lostLock = false
	local ok, err
	for attempt = 1, 3 do
		ok, err = pcall(function()
			store:UpdateAsync(keyFor(userId), function(record)
				lostLock = false
				record = record or {}
				if not record.lock or record.lock.jobId ~= game.JobId or writtenByNewer(record) then
					lostLock = true
					return nil
				end
				record.data = data
				record.placeVersion = math.max(tonumber(record.placeVersion) or 0, placeVersion)
				record.lock = if release then nil else { jobId = game.JobId, time = os.time() }
				return record
			end)
		end)
		if ok then
			break
		end
		warn(`[PlayerData] Sauvegarde échouée pour {userId} (essai {attempt}) : {err}`)
		task.wait(attempt)
	end
	pendingWrites -= 1

	if lostLock then
		warn(`[PlayerData] Verrou perdu pour {userId}, sauvegarde ignorée`)
		return false, true
	end
	return ok, false
end

-- Colonne de la liste des joueurs de Roblox (leaderstats) : « Level » = le plus haut niveau réussi (un mot anglais
-- pour tout le monde : Roblox ne traduit pas ces noms). Mise à jour par Hub/LevelsService.luau.
local function setupLeaderstats(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Parent = leaderstats
	leaderstats.Parent = player
end

function PlayerData.setLevel(player: Player, level: number)
	local leaderstats = player:FindFirstChild("leaderstats")
	local value = leaderstats and leaderstats:FindFirstChild("Level")
	if value and value:IsA("IntValue") then
		value.Value = level
	end
end

-- Met à jour les attributs visibles par les clients.
function PlayerData.refresh(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	local data = profile.data
	player:SetAttribute("SoundMode", data.soundMode) -- bouton « SON » (SoundManager.luau)
	player:SetAttribute("DataLoaded", true)
	PlayerData.setLevel(player, data.levels.best)
end

-- Vrai si une sauvegarde finale de ce joueur est en cours, ou si une autre session de lui est encore chargée ici.
local function busy(userId: number, except: Player?): boolean
	if releasing[userId] then
		return true
	end
	for other in profiles do
		if other ~= except and other.UserId == userId then
			return true
		end
	end
	return false
end

local function onPlayerAdded(player: Player)
	-- (revenu sur ce serveur pendant la sauvegarde finale de sa visite d'avant : on l'attend)
	local deadline = os.clock() + RELEASE_WAIT
	while busy(player.UserId, player) and player.Parent and os.clock() < deadline do
		task.wait(0.2)
	end
	local ok, data, why = acquire(player.UserId)

	if not player.Parent then
		-- Parti pendant le chargement : on rend le verrou tout de suite.
		if ok then
			write(player.UserId, data or defaultData(), true)
		end
		return
	end
	if why == "outdated" then
		player:Kick(Lang.translate("Le jeu vient d'être mis à jour : rejoins une nouvelle partie pour avoir la dernière version.", Lang.forPlayer(player)))
		return
	end
	if not ok then
		player:Kick(Lang.translate("Impossible de charger tes données. Réessaie dans une minute.", Lang.forPlayer(player)))
		return
	end

	data = reconcile(data or defaultData())
	profiles[player] = { data = data }

	setupLeaderstats(player)
	PlayerData.refresh(player)
	for _, callback in loadedCallbacks do
		task.spawn(callback, player, data)
	end
end

local function release(player: Player, isShutdown: boolean)
	local profile = profiles[player]
	if not profile then
		return
	end
	for _, callback in beforeReleaseCallbacks do
		local ok, err = pcall(callback, player, isShutdown)
		if not ok then
			warn("[PlayerData] Erreur dans onBeforeRelease :", err)
		end
	end
	profiles[player] = nil
	local userId = player.UserId
	releasing[userId] = (releasing[userId] or 0) + 1
	write(userId, profile.data, true)
	releasing[userId] -= 1
	if releasing[userId] <= 0 then
		releasing[userId] = nil
	end
end

function PlayerData.get(player: Player)
	local profile = profiles[player]
	return profile and profile.data
end

-- Sauvegarde immédiate (garde le verrou). À appeler après un changement important (fin d'un niveau).
function PlayerData.save(player: Player): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	local ok = write(player.UserId, profile.data, false)
	return ok
end

-- Tests Studio (StudioDebug « Data », ... ; seulement avec les fausses sauvegardes de Studio, jamais dans le jeu publié) :
--   "PlaceVersion", n          -> la version du jeu de ce serveur devient n (0 : pas de garde)
--   "Acquire", userId          -> { ok, why, data } : comme l'arrivée de ce joueur (prend le verrou)
--   "Write", userId, data, rendre -> { ok, lostLock } : une sauvegarde (rendre : avec le verrou rendu)
--   "Record", userId           -> la sauvegarde telle qu'elle est rangée (verrou, version, données)
--   "Releasing", userId, vrai/faux -> comme si sa sauvegarde finale était en cours (ou finie)
--   "Busy", userId             -> vrai si son arrivée attendrait (sauvegarde finale en cours)
function PlayerData.debug(action: string, ...)
	if not useMock then
		return nil
	end
	local first, second, third = ...
	if action == "PlaceVersion" then
		placeVersion = tonumber(first) or 0
		return placeVersion
	elseif action == "Acquire" then
		local ok, data, why = acquire(first)
		return { ok = ok, why = why, data = data }
	elseif action == "Write" then
		local ok, lostLock = write(first, second, third == true)
		return { ok = ok, lostLock = lostLock }
	elseif action == "Record" then
		return store:GetAsync(keyFor(first))
	elseif action == "Releasing" then
		releasing[first] = if second then 1 else nil
		return true
	elseif action == "Busy" then
		return busy(first, nil)
	end
	return nil
end

function PlayerData.onLoaded(callback: (Player, any) -> ())
	table.insert(loadedCallbacks, callback)
end

-- Appelé juste avant la sauvegarde finale du joueur (départ ou arrêt du serveur).
-- Les données sont encore modifiables à ce moment-là. Ne doit pas yield.
function PlayerData.onBeforeRelease(callback: (Player, boolean) -> ())
	table.insert(beforeReleaseCallbacks, callback)
end

function PlayerData.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		release(player, false)
		lastSettingAt[player] = nil
	end)

	-- Bouton « SON » (SoundManager.luau) : le choix est gardé dans les données du joueur et republié dans son
	-- attribut « SoundMode ». Valeurs connues seulement, un changement toutes les 0,2 s au plus.
	Remotes.get("Settings").OnServerEvent:Connect(function(player, key, value)
		local profile = profiles[player]
		local now = os.clock()
		if not profile or key ~= "SoundMode" or not table.find(Sounds.MODES, value) or now - (lastSettingAt[player] or 0) < 0.2 then
			return
		end
		lastSettingAt[player] = now
		profile.data.soundMode = value
		player:SetAttribute("SoundMode", value)
	end)

	task.spawn(function()
		while true do
			task.wait(Config.Data.AUTOSAVE_INTERVAL)
			for player, profile in profiles do
				task.spawn(function()
					local _, lostLock = write(player.UserId, profile.data, false)
					if lostLock and profiles[player] == profile then
						player:Kick(Lang.translate("Ta session a été ouverte sur un autre serveur.", Lang.forPlayer(player)))
					end
				end)
			end
		end
	end)

	game:BindToClose(function()
		for player in profiles do
			task.spawn(release, player, true)
		end
		local deadline = os.clock() + 25
		repeat
			task.wait(0.1)
		until (next(profiles) == nil and pendingWrites == 0) or os.clock() > deadline
	end)
end

return PlayerData

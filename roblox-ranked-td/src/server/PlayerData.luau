-- Sauvegarde des joueurs avec verrou de session : un seul serveur à la fois peut écrire
-- les données d'un joueur. Indispensable quand le joueur est téléporté lobby -> match -> lobby,
-- sinon un serveur pourrait écraser le MMR calculé par un autre.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local IdleConfig = require(Shared.IdleConfig)
local NumberFormat = require(Shared.NumberFormat)
local PlotLayout = require(Shared.PlotLayout)
local Ranks = require(Shared.Ranks)
local MockDataStore = require(script.Parent.MockDataStore)

local PlayerData = {}

local useMock = RunService:IsStudio() and Config.Data.MOCK_IN_STUDIO
local store = if useMock then MockDataStore.new() else DataStoreService:GetDataStore(Config.Data.DATASTORE_NAME)

local profiles = {} -- [Player] = { data = table }
local loadedCallbacks = {}
local beforeReleaseCallbacks = {}
local pendingWrites = 0

local function startingTowers()
	local towers = {}
	for _, towerType in IdleConfig.STARTING_TOWERS do
		towers[towerType] = true
	end
	return towers
end

local function defaultIdle()
	return {
		wave = 1, -- vague en cours
		bestWave = 1, -- meilleure vague de la run actuelle (depuis la dernière renaissance)
		highestWave = 1, -- meilleure vague de tous les temps
		-- Emplacements possédés, achetés dans n'importe quel ordre : [tostring(spotIndex)] = true.
		ownedSpots = PlotLayout.startingSpots(),
		unlockedSpots = PlotLayout.STARTING_SPOTS, -- NOMBRE d'emplacements possédés (recalculé depuis ownedSpots)
		towers = {}, -- [tostring(spotIndex)] = { type, level, spent }
		-- Bonus de pièces en %, gagné par les renaissances (IdleConfig.rebirthGain, PlotGame:rebirth).
		-- S'additionne : gain = base x (1 + bonus/100). Ex : ennemi à 3 pièces -> +100 % = 6, +200 % = 9.
		coinBonus = 0,
		rebirths = 0, -- nombre de renaissances (seules la vague et bestWave repartent à 1)
		-- Machines à sous
		unlockedTowers = startingTowers(), -- [type] = true
		towerDupes = {}, -- [type] = nombre de doublons (+5 % de dégâts chacun)
		pendingSpinTier = 0, -- lancer gratuit de la machine à tours (0 = aucun, sinon palier)
		bonuses = {}, -- inventaire de bonus (ids de IdleConfig.BONUSES)
		lastBonusSpinAt = 0, -- os.time() du dernier lancer payé en pièces
	}
end

local function defaultData()
	local start = Config.Ranked.START_MMR
	return {
		season = Config.SEASON,
		mmr = start,
		peakMmr = start,
		wins = 0,
		losses = 0,
		draws = 0,
		gamesPlayed = 0,
		lastMatchId = nil,
		history = {}, -- résultats des saisons passées
		-- Mode infini (parcelle). Les pièces ne sont jamais remises à zéro par les saisons.
		coins = IdleConfig.STARTING_COINS,
		idle = defaultIdle(),
		processedReceipts = {}, -- achats Robux déjà livrés (évite de donner deux fois)
	}
end

-- Emplacements possédés. Les anciennes sauvegardes n'ont que unlockedSpots = N, qui voulait dire
-- « emplacements 1 à N » (achetés dans l'ordre) : on les convertit en liste ownedSpots.
-- Les valeurs abîmées sont ignorées, les emplacements de départ toujours ajoutés, et
-- unlockedSpots est recalculé depuis la liste (c'est elle qui fait foi).
local function migrateSpots(idle)
	local owned = {}
	if typeof(idle.ownedSpots) == "table" then
		for key, value in idle.ownedSpots do
			local spotIndex = tonumber(key)
			if value == true and PlotLayout.isSpotIndex(spotIndex) then
				owned[tostring(spotIndex)] = true
			end
		end
	else
		local count = tonumber(idle.unlockedSpots) or 0
		if count ~= count then
			count = 0 -- NaN
		end
		for spotIndex = 1, math.clamp(math.floor(count), 0, #PlotLayout.SPOTS) do
			owned[tostring(spotIndex)] = true
		end
	end
	for key in PlotLayout.startingSpots() do
		owned[key] = true
	end

	local count = 0
	for _ in owned do
		count += 1
	end
	idle.ownedSpots = owned
	idle.unlockedSpots = count
end

-- Complète les champs manquants (utile quand tu ajoutes des champs plus tard).
local function reconcile(data)
	for key, value in defaultData() do
		if data[key] == nil then
			data[key] = value
		end
	end
	-- Avant de compléter data.idle : sinon ownedSpots serait rempli avec les 4 emplacements de départ
	-- et on perdrait ceux déjà achetés dans une ancienne sauvegarde.
	migrateSpots(data.idle)
	for key, value in defaultIdle() do
		if data.idle[key] == nil then
			data.idle[key] = value
		end
	end
	return data
end

local function applySeasonReset(data)
	if data.season == Config.SEASON then
		return
	end
	table.insert(data.history, {
		season = data.season,
		mmr = data.mmr,
		peakMmr = data.peakMmr,
		wins = data.wins,
		losses = data.losses,
		draws = data.draws,
	})
	while #data.history > 10 do
		table.remove(data.history, 1)
	end

	local start = Config.Ranked.START_MMR
	data.mmr = math.floor(start + (data.mmr - start) * Config.Ranked.SEASON_SOFT_RESET)
	data.peakMmr = data.mmr
	data.wins, data.losses, data.draws, data.gamesPlayed = 0, 0, 0, 0
	data.season = Config.SEASON
end

local function keyFor(userId: number): string
	return "Player_" .. userId
end

-- Prend le verrou et lit les données. Retourne (ok, data) ; data = nil pour un nouveau joueur.
local function acquire(userId: number): (boolean, any)
	local key = keyFor(userId)
	for attempt = 1, Config.Data.LOAD_RETRIES + 1 do
		local force = attempt > Config.Data.LOAD_RETRIES
		local lockedByOther = false

		local ok, result = pcall(function()
			return store:UpdateAsync(key, function(record)
				lockedByOther = false
				record = record or {}
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

		if ok and result then
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
				if not record.lock or record.lock.jobId ~= game.JobId then
					lostLock = true
					return nil
				end
				record.data = data
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

local function setupLeaderstats(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local rank = Instance.new("StringValue")
	rank.Name = "Rang"
	rank.Parent = leaderstats

	local mmr = Instance.new("IntValue")
	mmr.Name = "MMR"
	mmr.Parent = leaderstats

	local coins = Instance.new("StringValue")
	coins.Name = "Pièces"
	coins.Parent = leaderstats

	leaderstats.Parent = player
end

-- Met à jour les attributs / leaderstats visibles par les clients.
function PlayerData.refresh(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	local data = profile.data
	player:SetAttribute("Mmr", data.mmr)
	player:SetAttribute("PeakMmr", data.peakMmr)
	player:SetAttribute("Wins", data.wins)
	player:SetAttribute("Losses", data.losses)
	player:SetAttribute("Draws", data.draws)
	player:SetAttribute("GamesPlayed", data.gamesPlayed)
	player:SetAttribute("RankName", Ranks.label(data.mmr, data.gamesPlayed))
	player:SetAttribute("Coins", data.coins)
	player:SetAttribute("DataLoaded", true)

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		leaderstats.Rang.Value = Ranks.label(data.mmr, data.gamesPlayed)
		leaderstats.MMR.Value = data.mmr
		leaderstats["Pièces"].Value = NumberFormat.short(data.coins)
	end
end

local function onPlayerAdded(player: Player)
	local ok, data = acquire(player.UserId)

	if not player.Parent then
		-- Parti pendant le chargement : on rend le verrou tout de suite.
		if ok then
			write(player.UserId, data or defaultData(), true)
		end
		return
	end
	if not ok then
		player:Kick("Impossible de charger tes données. Réessaie dans une minute.")
		return
	end

	data = reconcile(data or defaultData())
	applySeasonReset(data)
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
	write(player.UserId, profile.data, true)
end

-- Ajoute (ou retire, si négatif) des pièces et met l'affichage à jour.
function PlayerData.addCoins(player: Player, amount: number)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.data.coins = math.max(0, profile.data.coins + amount)
	player:SetAttribute("Coins", profile.data.coins)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		leaderstats["Pièces"].Value = NumberFormat.short(profile.data.coins)
	end
end

function PlayerData.get(player: Player)
	local profile = profiles[player]
	return profile and profile.data
end

-- Attend que les données du joueur soient chargées (nil si timeout ou départ).
function PlayerData.waitFor(player: Player, timeout: number?)
	local deadline = os.clock() + (timeout or 30)
	while not profiles[player] and player.Parent and os.clock() < deadline do
		task.wait(0.1)
	end
	return PlayerData.get(player)
end

-- Sauvegarde immédiate (garde le verrou). À appeler après un changement important (fin de match).
function PlayerData.save(player: Player): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	local ok = write(player.UserId, profile.data, false)
	return ok
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
	end)

	task.spawn(function()
		while true do
			task.wait(Config.Data.AUTOSAVE_INTERVAL)
			for player, profile in profiles do
				task.spawn(function()
					local _, lostLock = write(player.UserId, profile.data, false)
					if lostLock and profiles[player] == profile then
						player:Kick("Ta session a été ouverte sur un autre serveur.")
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

-- Sauvegarde des joueurs avec verrou de session : un seul serveur à la fois peut écrire
-- les données d'un joueur. Indispensable quand le joueur est téléporté lobby -> match -> lobby,
-- sinon un serveur pourrait écraser le MMR calculé par un autre.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Challenges = require(Shared.Challenges)
local Config = require(Shared.Config)
local IdleConfig = require(Shared.IdleConfig)
local Lang = require(Shared.Lang) -- (messages de player:Kick : l'écran du joueur ne peut pas les traduire)
local NumberFormat = require(Shared.NumberFormat)
local PlotLayout = require(Shared.PlotLayout)
local Ranks = require(Shared.Ranks)
local Remotes = require(Shared.Remotes)
local Sounds = require(Shared.Sounds)
local MockDataStore = require(script.Parent.MockDataStore)

local PlayerData = {}

local useMock = RunService:IsStudio() and Config.Data.MOCK_IN_STUDIO
local store = if useMock then MockDataStore.new() else DataStoreService:GetDataStore(Config.Data.DATASTORE_NAME)

local profiles = {} -- [Player] = { data = table }
local lastSettingAt = {} -- [Player] = heure du dernier réglage reçu (remote « Settings »)
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
		-- [tostring(spotIndex)] = { type, level, spent, runes = { Damage = id, Speed = id } } : une rune de la forge
		-- par emplacement (dégâts, vitesse), sorte absente = pas de rune (voir migrateRunes).
		towers = {},
		-- Bonus de pièces en %, gagné par les renaissances (IdleConfig.rebirthGain, PlotGame:rebirth).
		-- S'additionne : gain = base x (1 + bonus/100). Ex : ennemi à 3 pièces -> +100 % = 6, +200 % = 9.
		coinBonus = 0,
		rebirths = 0, -- nombre de renaissances (seules la vague et bestWave repartent à 1)
		-- Machines à sous
		unlockedTowers = startingTowers(), -- [type] = true
		towerDupes = {}, -- [type] = nombre de doublons (IdleConfig.DUPLICATE_DAMAGE_BONUS de dégâts chacun)
		-- (plus de lancer gratuit par vague : les lancers de l'autel se paient en pièces, voir migrateFreeSpin)
		-- Lancers de l'autel achetés depuis toujours (x10 = 10). Jamais remis à zéro, ni à la renaissance ni
		-- chaque jour : chaque lancer acheté rend le suivant 0,05 % plus cher (IdleConfig.towerSpinCost).
		towerSpinsBought = 0,
		bonuses = {}, -- inventaire de bonus (ids de IdleConfig.BONUSES)
		-- Forge runique : lancers payés en PIÈCES depuis toujours (les lancers Robux ne comptent pas). Jamais
		-- remis à zéro, ni à la renaissance : le prix du prochain lancer en dépend (IdleConfig.forgeCoinPrice).
		-- Plus de délai entre deux lancers (l'ancien champ lastBonusSpinAt est supprimé, voir reconcile).
		forgeSpinsBought = 0,
		-- Gains d'absence (Hub/init.luau, réglages dans IdleConfig) :
		lastSeenAt = 0, -- os.time() de la dernière sauvegarde, map principale ou match (0 = jamais vu)
		matchDepartureAt = 0, -- os.time() du départ vers un match ranked (Matchmaking ; 0 = aucun)
		offlineDay = 0, -- jour UTC (AAAAMMJJ) du compteur ci-dessous
		offlineGainedToday = 0, -- pièces gagnées hors ligne ce jour-là (plafond : IdleConfig.offlineDailyCap)
		-- Pass Vitesse x2 : interrupteur choisi par le joueur (vrai = x2 allumé quand il possède le pass).
		speedX2 = true,
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
		-- Défis classés : progression comptée par le serveur de match, récompenses récupérées sur la map
		-- principale (format : Shared/Challenges.luau). Jamais remis à zéro par les saisons.
		challenges = Challenges.defaultData(),
		-- Bouton « SON » : "All" (musique + effets), "Effects" (effets seuls) ou "Mute" (Sounds.MODES).
		soundMode = "All",
		-- Tuto des nouveaux joueurs fini ou passé (Hub/Tutorial.luau, TutorialUI.luau) : faux pour un nouveau joueur.
		-- Les anciennes sauvegardes n'ont pas ce champ : voir migrateTutorial.
		tutorialDone = false,
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

-- Avant, chaque vague réussie donnait 1 lancer gratuit de l'autel (idle.pendingSpinTier > 0 = un lancer
-- en attente). Les lancers se paient maintenant en pièces : un lancer en attente dans une ancienne
-- sauvegarde est remboursé au prix de base d'un lancer à ton record (IdleConfig.towerSpinUnitCost,
-- toujours fini), puis le champ est supprimé. Une seule fois : sans le champ, il ne se passe plus rien.
local function migrateFreeSpin(data)
	local pending = data.idle.pendingSpinTier
	data.idle.pendingSpinTier = nil
	if typeof(pending) == "number" and pending > 0 and typeof(data.coins) == "number" then
		data.coins += IdleConfig.towerSpinUnitCost(data.idle.highestWave)
	end
end

-- Runes de la forge posées sur les tours. Avant : UNE seule rune par tour (champ bonus = son id, ex. "Speed2").
-- Maintenant : un emplacement par sorte, qui se cumulent (champ runes = { Damage = id, Speed = id }). L'ancienne
-- rune va dans l'emplacement de SA sorte, puis le champ bonus est supprimé : une seule fois (sans bonus, il ne
-- se passe plus rien). Toujours propre : ids inconnus retirés, que des textes (IdleConfig.runeIds).
local function migrateRunes(idle)
	if typeof(idle.towers) ~= "table" then
		return
	end
	for _, tower in idle.towers do
		if typeof(tower) == "table" then
			local ids = {}
			if typeof(tower.runes) == "table" then
				for _, id in tower.runes do
					table.insert(ids, id)
				end
			end
			if tower.bonus ~= nil then
				table.insert(ids, tower.bonus)
			end
			tower.runes = IdleConfig.runeIds(ids)
			tower.bonus = nil
		end
	end
end

-- Tuto des nouveaux joueurs (Hub/Tutorial.luau). Les sauvegardes d'avant le tuto n'ont pas le champ tutorialDone :
-- un joueur qui a déjà joué (record au-delà de la vague 1, une tour posée, un lancer de l'autel ou de la forge
-- acheté, une renaissance ou un match classé) compte comme « fini » et ne le verra jamais ; les autres le voient.
-- hadField = le champ était déjà dans la sauvegarde (sinon reconcile vient de le mettre à faux par défaut).
-- À appeler après le nettoyage des compteurs de lancers. Toujours vrai ou faux.
local function migrateTutorial(data, hadField: boolean)
	if not hadField then
		local idle = data.idle
		data.tutorialDone = (tonumber(idle.highestWave) or 1) > 1
			or (typeof(idle.towers) == "table" and next(idle.towers) ~= nil)
			or idle.towerSpinsBought > 0
			or idle.forgeSpinsBought > 0
			or (tonumber(idle.rebirths) or 0) > 0
			or (tonumber(data.gamesPlayed) or 0) > 0
	end
	data.tutorialDone = data.tutorialDone == true
end

-- Complète les champs manquants (utile quand tu ajoutes des champs plus tard).
local function reconcile(data)
	-- Avant de compléter : un champ absent du tuto veut dire « ancienne sauvegarde » (voir migrateTutorial).
	local hadTutorial = data.tutorialDone ~= nil
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
	-- Compteur des lancers de l'autel : absent dans les anciennes sauvegardes (-> 0 juste au-dessus),
	-- toujours un nombre entier, fini et positif (une valeur abîmée compte comme 0).
	data.idle.towerSpinsBought = IdleConfig.cleanSpinsBought(data.idle.towerSpinsBought)
	-- Forge runique : plus de délai de 30 minutes (lastBonusSpinAt ne sert plus, supprimé). Le compteur des
	-- lancers en pièces démarre à 0 dans les anciennes sauvegardes (-> 0 juste au-dessus), toujours propre.
	data.idle.lastBonusSpinAt = nil
	data.idle.forgeSpinsBought = IdleConfig.cleanSpinsBought(data.idle.forgeSpinsBought)
	-- Runes : 2 emplacements par tour (dégâts, vitesse) ; l'ancienne rune unique va dans celui de sa sorte.
	migrateRunes(data.idle)
	migrateFreeSpin(data)
	-- Défis classés : absents des anciennes sauvegardes (-> valeurs par défaut juste au-dessus), toujours
	-- propres (nombres entiers finis, défis connus). Les défis du jour sont tirés à la 1re utilisation.
	data.challenges = Challenges.cleanData(data.challenges)
	-- Réglage du son : absent des anciennes sauvegardes (-> "All" juste au-dessus), toujours une valeur connue.
	if not table.find(Sounds.MODES, data.soundMode) then
		data.soundMode = "All"
	end
	-- Tuto : absent des anciennes sauvegardes -> fini si le joueur a déjà joué, sinon à faire.
	migrateTutorial(data, hadTutorial)
	return data
end

-- Tests Studio (StudioDebug « ChallengeMigrate ») : complète et nettoie une copie d'ancienne sauvegarde,
-- exactement comme au chargement d'un joueur.
PlayerData.reconcile = reconcile

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

-- Gains d'absence : heure (os.time()) de la dernière visite, notée à chaque sauvegarde et au départ, sur la
-- map principale comme sur un serveur de match (sa dernière sauvegarde = la fin du match). Au retour sur la
-- map principale, Hub/init.luau paie le temps écoulé depuis. Pas au chargement : un joueur parti pendant le
-- chargement garde son absence à payer.
local function stampLastSeen(data)
	if typeof(data) == "table" and typeof(data.idle) == "table" then
		data.idle.lastSeenAt = os.time()
	end
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
	player:SetAttribute("SoundMode", data.soundMode) -- bouton « SON » (SoundManager.luau)
	player:SetAttribute("TutorialDone", data.tutorialDone == true) -- tuto des nouveaux joueurs (TutorialUI.luau)
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
		player:Kick(Lang.translate("Impossible de charger tes données. Réessaie dans une minute.", Lang.forPlayer(player)))
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
	stampLastSeen(profile.data)
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
	stampLastSeen(profile.data)
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
		lastSettingAt[player] = nil
	end)

	-- Bouton « SON » (SoundManager.luau, map principale et match) : le choix est gardé dans les données du joueur
	-- et republié dans son attribut « SoundMode ». Valeurs connues seulement, un changement toutes les 0,2 s au plus.
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
					stampLastSeen(profile.data)
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

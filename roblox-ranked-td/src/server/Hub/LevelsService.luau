-- NIVEAUX, côté serveur (règles et chiffres : Shared/Levels.luau).
-- Ce module fait tourner tout ce qui se passe AUTOUR du combat d'un niveau (le combat lui-même : LevelGame.luau,
-- la carte : LevelArena.luau) :
--   * lancer un niveau dans la zone de combat du joueur (la zone n° de sa parcelle), l'arrêter, enchaîner ;
--   * faire avancer les niveaux en cours à chaque image et envoyer monstres et tirs AU JOUEUR DU NIVEAU SEULEMENT
--     (paquets PlotSync / PlotShots, numéro de zone à la place du numéro de parcelle) ;
--   * la fin d'un niveau : pièces de niveau, niveau suivant débloqué, XP d'entraînement des tours posées ;
--   * la boutique à prix fixes, le camp d'entraînement (emplacements), l'ordre de la barre rapide ;
--   * publier l'état du joueur (attributs LevelsState, LevelArena : voir Remotes.luau, LevelAction).
-- Le client (LevelsUI.luau) ne décide rien : il envoie des demandes (remote LevelAction), tout est revérifié ici.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local IdleConfig = require(Shared.IdleConfig)
local IdleTowers = require(Shared.IdleTowers)
local Levels = require(Shared.Levels)
local Remotes = require(Shared.Remotes)
local PlayerData = require(script.Parent.Parent.PlayerData)
local LevelArena = require(script.Parent.LevelArena)
local LevelGame = require(script.Parent.LevelGame)

local LevelsService = {}

local ACTION_COOLDOWN = 0.08 -- secondes entre deux demandes d'un joueur (on améliore vite, pendant un niveau)
local TRAINING_INTERVAL = 20 -- secondes entre deux calculs de l'entraînement des joueurs présents
local SAVE_INTERVAL = 30 -- au plus une sauvegarde de fin de niveau toutes les 30 s par joueur (le reste : sauvegarde automatique)
local MAX_STEP = 0.1 -- une image plus longue que ça (à-coup du serveur) ne fait pas sauter les monstres : le niveau ralentit
local EMPTY_PACKET = buffer.create(0)

local sessions = {} -- [Player] = { game = LevelGame, slot, syncTimer, shotsTimer }
local lastAction = {} -- [Player] = heure de sa dernière demande
local lastSave = {} -- [Player] = heure de sa dernière sauvegarde de fin de niveau
local savingAllowed = true -- faux pendant le départ d'un joueur : sa sauvegarde finale suit, pas besoin d'une autre
local plotOf: (Player) -> number? = function()
	return nil
end
local clockOffset = 0 -- tests Studio : secondes ajoutées à l'heure (entraînement pendant une absence)

local changedCallbacks = {} -- appelées quand l'état d'un joueur est publié (Hub/init.luau : son camp suit)

local function now(): number
	return os.time() + clockOffset
end

local function notify(player: Player, message: string, kind: string?)
	if player.Parent then
		Remotes.get("Notify"):FireClient(player, message, kind or "Info", "Levels")
	end
end

----------------------------------------------------------------------
-- État publié
----------------------------------------------------------------------

-- Données des niveaux du joueur (data.levels), nil tant que sa sauvegarde n'est pas chargée.
local function levelsOf(player: Player)
	local data = PlayerData.get(player)
	return data and data.levels
end

local function round1(value: number): number
	return math.floor(value * 10 + 0.5) / 10
end

-- État du joueur pour son interface (attribut « LevelsState », JSON) : tout ce que les fenêtres affichent.
local function publish(player: Player)
	local levels = levelsOf(player)
	if not levels or not player.Parent then
		return
	end
	local xp = {}
	for _, towerType in IdleTowers.ORDER do
		xp[towerType] = round1(levels.xp[towerType] or 0)
	end
	player:SetAttribute("LevelsState", HttpService:JSONEncode({
		best = levels.best,
		coins = levels.coins,
		towers = Levels.ownedTowers(levels), -- tours débloquées, dans l'ordre de la barre rapide
		xp = xp,
		slots = levels.slots,
		wins = levels.wins,
		losses = levels.losses,
	}))
	PlayerData.setLevel(player, levels.best) -- colonne « Level » de la liste des joueurs
	for _, callback in changedCallbacks do
		task.spawn(callback, player, levels)
	end
end

-- callback(player, data.levels) à chaque publication de l'état d'un joueur (emplacements, XP, pièces...).
function LevelsService.onChanged(callback: (Player, any) -> ())
	table.insert(changedCallbacks, callback)
end

local closeLevel -- (défini plus bas)

-- Entraînement du camp jusqu'à maintenant (emplacements, même pendant une absence) : Levels.accrueTraining.
local function train(player: Player): boolean
	local levels = levelsOf(player)
	if not levels then
		return false
	end
	return next(Levels.accrueTraining(levels, now())) ~= nil
end

----------------------------------------------------------------------
-- Un niveau : lancer, finir, ranger
----------------------------------------------------------------------

-- Fin d'un niveau (victoire, défaite ou abandon), appelée une seule fois par LevelGame:finish : pièces de niveau,
-- niveau suivant débloqué, XP d'entraînement des tours posées. Le résumé part dans l'attribut « Result » de la zone
-- (écran de fin du client).
local function onLevelEnd(player: Player, game, won: boolean)
	local levels = levelsOf(player)
	if not levels then
		return
	end
	local level = game.level
	local firstClear = won and level > levels.best
	local progress = game:progress()
	local reward = Levels.reward(level, won, firstClear, progress)
	levels.coins += reward
	if won then
		levels.best = math.max(levels.best, level)
		levels.wins += 1
	else
		levels.losses += 1
	end

	-- XP : d'abord celle du camp jusqu'à maintenant, puis celle du niveau joué, pour chaque type de tour posé.
	train(player)
	local before = Levels.trainingLevels(levels)
	local xp = Levels.playXp(won, progress)
	local towers, perks = {}, {}
	for _, towerType in IdleTowers.ORDER do
		if game.usedTowers[towerType] then
			table.insert(towers, towerType)
			if xp > 0 then
				levels.xp[towerType] = (levels.xp[towerType] or 0) + xp
				for _, perk in Levels.perksBetween(towerType, before[towerType], Levels.trainingLevel(levels.xp[towerType])) do
					table.insert(perks, { tower = towerType, name = perk.name, text = perk.text })
				end
			end
		end
	end

	game.plot.folder:SetAttribute("Result", HttpService:JSONEncode({
		won = won,
		level = level,
		reward = reward,
		firstClear = firstClear,
		coins = levels.coins,
		kills = game.kills,
		total = #game.queue,
		lives = game.lives,
		xp = xp,
		towers = towers,
		perks = perks, -- améliorations d'entraînement débloquées par cette partie
		nextLevel = if won and level < Levels.COUNT then level + 1 else nil,
		seconds = math.floor(game.clock),
	}))
	publish(player)
	print(`[Niveaux] {player.Name} : niveau {level} {if won then "gagné" else "perdu"} ({game.kills}/{#game.queue} monstres, {game.lives} vies, {math.floor(game.clock)} s) -> +{reward} pièces de niveau`)
	local clock = os.clock()
	if savingAllowed and clock - (lastSave[player] or -math.huge) >= SAVE_INTERVAL then
		lastSave[player] = clock
		task.spawn(PlayerData.save, player)
	end
end

-- Range le niveau du joueur, s'il en a un. Encore en cours : c'est un abandon, compté comme une défaite
-- (récompense selon l'avancée). keepArena = un autre niveau démarre tout de suite dans la même zone (la carte et
-- la vue du joueur restent) ; sinon retour au camp : carte effacée, le joueur ne regarde plus la zone.
function closeLevel(player: Player, keepArena: boolean?)
	local session = sessions[player]
	if not session then
		return
	end
	sessions[player] = nil
	local game = session.game
	if game.state == "Running" then
		game:finish(false)
	end
	local arena = game.plot
	game:destroy()
	arena.folder:SetAttribute("Result", nil)
	if player.Parent then
		-- Le client efface tout de suite ce qu'il affichait de la zone (monstres, feu), comme pour une parcelle.
		Remotes.get("PlotSync"):FireClient(player, game.index, EMPTY_PACKET, 0, "Clear")
	end
	if not keepArena then
		LevelArena.clear(session.slot)
		if player.Parent then
			player:SetAttribute("LevelArena", nil)
			player.ReplicationFocus = nil
		end
	end
end

-- Lance le niveau `level` pour ce joueur. Renvoie (vrai) ou (faux, raison).
local function startLevel(player: Player, level: any): (boolean, string?)
	local levels = levelsOf(player)
	if not levels then
		return false, "Tes données ne sont pas encore chargées"
	end
	if typeof(level) ~= "number" or level ~= math.floor(level) or level < 1 or level > Levels.COUNT then
		return false, "Ce niveau n'existe pas encore"
	end
	if level > levels.best + 1 then
		return false, `Réussis d'abord le niveau {levels.best + 1}`
	end
	local slot = plotOf(player)
	if not slot or not LevelArena.get(slot) then
		return false, "Aucune zone de combat libre pour toi"
	end
	closeLevel(player, true)
	train(player)
	local definition = Levels.definition(level)
	local arena = LevelArena.build(slot, definition.map, definition.palier)
	local game = LevelGame.new(arena, player, {
		level = level,
		unlocked = table.clone(levels.towers),
		training = Levels.trainingLevels(levels),
		startingTower = level == 1,
		onEnd = function(finished, won)
			onLevelEnd(player, finished, won)
		end,
	})
	sessions[player] = { game = game, slot = slot, syncTimer = 0, shotsTimer = 0 }
	player.ReplicationFocus = arena.focus
	player:SetAttribute("LevelArena", arena.index)
	publish(player)
	return true, nil
end

----------------------------------------------------------------------
-- Boutique, camp d'entraînement, barre rapide
----------------------------------------------------------------------

local function buyTower(player: Player, levels, towerType: any): (boolean, string?)
	local price = if typeof(towerType) == "string" then Levels.SHOP[towerType] else nil
	local def = price and IdleTowers.Defs[towerType]
	if not def then
		return false, "Cette tour n'est pas en vente"
	end
	if levels.towers[towerType] then
		return false, `{def.displayName} est déjà à toi`
	end
	if levels.coins < price then
		return false, `Il te manque {price - levels.coins} pièces de niveau`
	end
	levels.coins -= price
	levels.towers[towerType] = true
	table.insert(levels.bar, towerType)
	notify(player, `Achat réussi : {def.displayName} rejoint ta barre de tours`, "Success")
	return true, nil
end

-- Met la tour `towerType` dans l'emplacement du camp ("" = le vider). Une tour ne s'entraîne que dans un seul
-- emplacement : si elle était ailleurs, elle change de place.
local function assignSlot(levels, slotIndex: any, towerType: any): (boolean, string?)
	local slot = if typeof(slotIndex) == "number" then levels.slots[slotIndex] else nil
	if not slot or typeof(towerType) ~= "string" then
		return false, "Emplacement inconnu"
	end
	if towerType ~= "" and not levels.towers[towerType] then
		return false, "Cette tour n'est pas encore à toi"
	end
	if towerType ~= "" then
		for _, other in levels.slots do
			if other ~= slot and other.tower == towerType then
				other.tower = ""
			end
		end
	end
	slot.tower = towerType
	return true, nil
end

local function upgradeSlot(levels, slotIndex: any): (boolean, string?)
	local slot = if typeof(slotIndex) == "number" then levels.slots[slotIndex] else nil
	if not slot then
		return false, "Emplacement inconnu"
	end
	local price = Levels.TRAINING.SLOT_UPGRADE_COST[slot.level]
	if not price then
		return false, "Cet emplacement est au niveau maximum"
	end
	if levels.coins < price then
		return false, `Il te manque {price - levels.coins} pièces de niveau`
	end
	levels.coins -= price
	slot.level += 1
	return true, nil
end

local function unlockSlot(levels): (boolean, string?)
	local price = Levels.TRAINING.SLOT_UNLOCK_COST[#levels.slots + 1]
	if not price then
		return false, "Tous les emplacements du camp sont ouverts"
	end
	if levels.coins < price then
		return false, `Il te manque {price - levels.coins} pièces de niveau`
	end
	levels.coins -= price
	table.insert(levels.slots, { tower = "", level = 1 })
	return true, nil
end

-- Ordre de la barre rapide : la liste du joueur (tours à lui, sans doublon), puis ses autres tours.
local function setBar(levels, list: any): (boolean, string?)
	if typeof(list) ~= "table" then
		return false, nil
	end
	local bar, seen = {}, {}
	for index = 1, math.min(#list, #IdleTowers.ORDER) do
		local towerType = list[index]
		if typeof(towerType) == "string" and levels.towers[towerType] and not seen[towerType] then
			seen[towerType] = true
			table.insert(bar, towerType)
		end
	end
	if #bar == 0 then
		return false, nil
	end
	levels.bar = bar
	levels.bar = Levels.ownedTowers(levels)
	return true, nil
end

----------------------------------------------------------------------
-- Demandes du joueur
----------------------------------------------------------------------

-- Une demande (remote LevelAction, ou tests Studio). Renvoie (réussie, raison du refus à montrer au joueur).
local function handle(player: Player, action: any, a: any, b: any, c: any): (boolean, string?)
	local levels = levelsOf(player)
	if not levels then
		return false, nil
	end
	if action == "Start" then
		return startLevel(player, a)
	elseif action == "Quit" then
		closeLevel(player, false)
		publish(player)
		return true, nil
	end

	-- Camp : boutique, emplacements, barre (l'entraînement est d'abord compté jusqu'à maintenant).
	local ok, reason
	if action == "Buy" then
		ok, reason = buyTower(player, levels, a)
	elseif action == "SlotAssign" then
		train(player)
		ok, reason = assignSlot(levels, a, b)
	elseif action == "SlotUpgrade" then
		train(player)
		ok, reason = upgradeSlot(levels, a)
	elseif action == "SlotUnlock" then
		ok, reason = unlockSlot(levels)
	elseif action == "Bar" then
		ok, reason = setBar(levels, a)
	end
	if ok ~= nil then
		if ok then
			publish(player)
		end
		return ok, reason
	end

	-- Pendant un niveau : tout est décidé par LevelGame (or, limites, emplacement).
	local session = sessions[player]
	local game = session and session.game
	if not game then
		return false, nil
	end
	if action == "Place" then
		if typeof(a) ~= "string" or typeof(b) ~= "number" or typeof(c) ~= "number" then
			return false, nil
		end
		local placed, why = game:placeTower(a, Vector3.new(b, 0, c))
		return placed, why
	elseif action == "Upgrade" then
		if typeof(a) ~= "number" then
			return false, nil
		end
		return game:upgradeTower(a)
	elseif action == "Sell" then
		if typeof(a) ~= "number" then
			return false, nil
		end
		return (game:sellTower(a)), nil
	elseif action == "Speed" then
		game:setSimSpeed(if a == IdleConfig.SPEED_PASS_FACTOR then IdleConfig.SPEED_PASS_FACTOR else 1)
		return true, nil
	end
	return false, nil
end

----------------------------------------------------------------------
-- Démarrage
----------------------------------------------------------------------

-- plots = Hub/Plots.luau : la zone de combat d'un joueur porte le numéro de sa parcelle (Plots.get).
function LevelsService.start(plots)
	plotOf = plots.get
	LevelArena.init()

	local function onLoaded(player: Player)
		train(player) -- entraînement pendant l'absence (première visite : l'heure est seulement notée)
		publish(player)
	end
	PlayerData.onLoaded(onLoaded)
	for _, player in Players:GetPlayers() do
		if PlayerData.get(player) then
			onLoaded(player)
		end
	end
	PlayerData.onBeforeRelease(function(player)
		-- Départ pendant un niveau : abandon (compté avant la sauvegarde finale, qui suit : pas de sauvegarde de fin
		-- de niveau en plus). L'entraînement du camp est compté jusqu'ici ; au retour, il reprendra de cette heure-là.
		savingAllowed = false
		local ok, err = pcall(closeLevel, player, false)
		savingAllowed = true
		if not ok then
			warn("[Niveaux] Niveau mal rangé au départ de", player.Name, ":", err)
		end
		train(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastAction[player] = nil
		lastSave[player] = nil
	end)

	Remotes.get("LevelAction").OnServerEvent:Connect(function(player, action, a, b, c)
		local clock = os.clock()
		if typeof(action) ~= "string" or clock - (lastAction[player] or 0) < ACTION_COOLDOWN then
			return
		end
		lastAction[player] = clock
		local ok, reason = handle(player, action, a, b, c)
		if not ok and reason then
			notify(player, reason, "Error")
		end
	end)

	-- Niveaux en cours : simulation à chaque image, monstres et tirs envoyés au joueur du niveau seulement.
	local syncRemote = Remotes.get("PlotSync")
	local shotsRemote = Remotes.get("PlotShots")
	RunService.Heartbeat:Connect(function(dt)
		local step = math.min(dt, MAX_STEP)
		for player, session in sessions do
			local game = session.game
			game:step(step)
			session.syncTimer += dt
			if session.syncTimer >= 1 / IdleConfig.SYNC_RATE then
				session.syncTimer = 0
				local packet, count = game:buildSyncPacket()
				if packet and player.Parent then
					syncRemote:FireClient(player, game.index, packet, count)
				end
			end
			session.shotsTimer += dt
			if session.shotsTimer >= 1 / IdleConfig.SHOTS_RATE then
				session.shotsTimer = 0
				local packet, count = game:takeShotsPacket()
				if packet and player.Parent then
					shotsRemote:FireClient(player, game.index, packet, count)
				end
			end
		end
	end)

	-- Entraînement des joueurs présents : compté régulièrement, pour que la fenêtre du camp avance.
	task.spawn(function()
		while true do
			task.wait(TRAINING_INTERVAL)
			for _, player in Players:GetPlayers() do
				if train(player) then
					publish(player)
				end
			end
		end
	end)
end

----------------------------------------------------------------------
-- Tests Studio (StudioDebug « Levels », Hub/init.luau) : jamais dans le jeu publié.
--   Invoke(player, "Levels", "State")            -> { levels (données sauvegardées), active (niveau en cours : level,
--                                                   state, gold, lives, kills, total, clock, towers, alive, simSpeed) }
--   Invoke(player, "Levels", "Action", "Start", 1) -> une demande, comme le remote LevelAction (sans l'anti-spam) ;
--                                                   renvoie (réussie, raison)
--   Invoke(player, "Levels", "Set", "coins", 500) -> change un champ de data.levels (puis nettoyage et publication)
--   Invoke(player, "Levels", "Gold", 100)        -> ajoute de l'or au niveau en cours
--   Invoke(player, "Levels", "Skip", 30)         -> le niveau en cours avance de 30 s d'un coup (pas de 1/30 s)
--   Invoke(player, "Levels", "KillAll")          -> tue tous les monstres présents ; renvoie leur nombre
--   Invoke(player, "Levels", "Finish", true)     -> finit le niveau tout de suite (true = gagné)
--   Invoke(player, "Levels", "Clock", 3600)      -> avance l'heure du serveur d'une heure (entraînement du camp), puis
--                                                   compte l'entraînement ; renvoie l'XP de chaque tour
--   Invoke(player, "Levels", "Bench", 6, 60, 12) -> 6 niveaux 10 joués en même temps pendant 60 s de jeu, 12 tours
--                                                   chacun, hors de la carte : { games, steps, enemiesPeak, averageMs,
--                                                   p99Ms, worstMs } (coût du serveur par image pour les 6 combats)
----------------------------------------------------------------------
function LevelsService.debug(player: Player, command: string, ...)
	local levels = levelsOf(player)
	local session = sessions[player]
	local game = session and session.game
	if command == "State" then
		local active = nil
		if game then
			local towers, alive = 0, 0
			for _ in game.towers do
				towers += 1
			end
			for _, enemy in game.enemies do
				if not enemy.dead then
					alive += 1
				end
			end
			active = {
				level = game.level,
				state = game.state,
				gold = game.gold,
				lives = game.lives,
				kills = game.kills,
				total = #game.queue,
				spawned = game.queueIndex - 1,
				clock = game.clock,
				towers = towers,
				alive = alive,
				simSpeed = game.simSpeed,
				index = game.index,
			}
		end
		return { levels = levels, active = active }
	elseif command == "Action" then
		return handle(player, ...)
	elseif command == "Set" and levels then
		local key, value = ...
		levels[key] = value
		local data = PlayerData.get(player)
		data.levels = Levels.cleanData(levels)
		publish(player)
		return data.levels
	elseif command == "Gold" and game then
		game.gold += ...
		return game.gold
	elseif command == "Skip" and game then
		local seconds = ...
		for _ = 1, math.floor((seconds or 1) * 30) do
			if game.state ~= "Running" then
				break
			end
			game:simulate(1 / 30)
		end
		game:syncAttributes()
		return game.state
	elseif command == "KillAll" and game then
		local count = 0
		for _, enemy in game.enemies do
			if not enemy.dead then
				game:damageEnemy(enemy, enemy.health + 1, false)
				count += 1
			end
		end
		return count
	elseif command == "Finish" and game then
		game:finish(... == true)
		game:syncAttributes()
		return game.state
	elseif command == "Clock" and levels then
		clockOffset += tonumber((...)) or 0
		train(player)
		publish(player)
		return table.clone(levels.xp)
	elseif command == "Bench" then
		local count, seconds, towerCount = ...
		return LevelsService.bench(count or Levels.ARENA_SLOTS, seconds or 60, towerCount)
	end
	return nil
end

-- Mesure : `count` niveaux 10 (le plus chargé) joués en même temps pendant `seconds` secondes de jeu, avec
-- `towerCount` tours posées (12 par défaut, de tous les types, niveau 1 ; moins de tours = plus de monstres en vie)
-- et des vies infinies (le combat ne s'arrête pas). Rien n'est affiché ni envoyé : seul le calcul du serveur est
-- mesuré, image par image (pas de 1/60 s), paquets réseau compris. Sert à vérifier que six combats dans le même
-- serveur tiennent. Renvoie le temps moyen par image, le temps sous lequel passent 99 % des images (p99Ms) et le
-- pire (une image isolée : souvent le ramasse-miettes de Roblox, pas le jeu).
function LevelsService.bench(count: number, seconds: number, towerCount: number?)
	local holder = Instance.new("Folder")
	local all = {}
	for index = 1, count do
		local folder = Instance.new("Folder")
		folder.Parent = holder
		all[index] = folder
	end
	local unlocked = {}
	for _, towerType in IdleTowers.ORDER do
		unlocked[towerType] = true
	end
	local games = {}
	local definition = Levels.definition(Levels.COUNT)
	for index, folder in all do
		local arena = { index = Levels.arenaIndex(index), folder = folder, cframe = Levels.arenaCFrame(index), map = definition.map }
		local game = LevelGame.new(arena, { UserId = -index, Parent = holder } :: any, { level = Levels.COUNT, unlocked = unlocked, training = {} })
		game.gold = 1e6
		game.lives = math.huge
		local spots = Levels.geometry(definition.map).map.spots
		for spotIndex, towerType in { "MachineGun", "Frost", "Bomb", "Tesla", "Rocket", "Laser", "Chain", "Orbital", "MachineGun", "Bomb", "Tesla", "Rocket" } do
			if spotIndex <= (towerCount or 12) then
				game:placeTower(towerType, spots[spotIndex])
			end
		end
		games[index] = game
	end
	local times, total, peak = {}, 0, 0
	local dt = 1 / 60
	for _ = 1, math.floor(seconds / dt) do
		local started = os.clock()
		local enemies = 0
		for _, game in games do
			game:step(dt)
			game:buildSyncPacket()
			game:takeShotsPacket()
			enemies += #game.enemies
		end
		local elapsed = os.clock() - started
		table.insert(times, elapsed)
		total += elapsed
		peak = math.max(peak, enemies)
	end
	for _, game in games do
		game:destroy()
	end
	holder:Destroy()
	table.sort(times)
	local steps = #times
	return {
		games = count,
		steps = steps,
		enemiesPeak = peak,
		averageMs = total / math.max(1, steps) * 1000,
		p99Ms = (times[math.max(1, math.floor(steps * 0.99))] or 0) * 1000,
		worstMs = (times[steps] or 0) * 1000,
	}
end

return LevelsService

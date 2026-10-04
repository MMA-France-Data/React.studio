-- NIVEAUX, côté serveur (règles et chiffres : Shared/Levels.luau).
-- Ce module fait tourner tout ce qui se passe AUTOUR du combat d'un niveau (le combat lui-même : LevelGame.luau,
-- la carte : LevelArena.luau) :
--   * lancer un niveau dans une zone de combat (celle de la parcelle du joueur quand elle est libre), l'arrêter,
--     enchaîner ;
--   * JOUER EN ÉQUIPE (Levels.luau) : une PARTIE (match) = un LevelGame, sa zone et ses joueurs : un joueur seul,
--     ou le chef d'une équipe (Hub/LevelTeams.luau : invitations) et ses coéquipiers. Le chef lance, tous jouent ;
--     celui qui s'en va abandonne pour lui seul ;
--   * faire avancer les parties à chaque image et envoyer monstres et tirs AUX JOUEURS DE LA PARTIE SEULEMENT
--     (paquets PlotSync / PlotShots, numéro de zone à la place du numéro de parcelle) ;
--   * la fin d'un niveau, pour chaque joueur : pièces de niveau (bonus d'équipe, bonus d'ami sur le serveur), niveau
--     suivant débloqué, XP d'entraînement des tours qu'il a posées ;
--   * LES AMIS (Levels.luau) : amis Roblox sur le serveur (attribut « FriendsHere »), récompenses d'invitation (un
--     ami venu grâce à une invitation : pour lui et pour celui qui l'a invité, tout de suite ou à son retour) ;
--   * la boutique à prix fixes, le camp d'entraînement (emplacements), l'ordre de la barre rapide ;
--   * LES ŒUFS (Levels.luau) : un œuf gagné à chaque victoire, les couveuses (poser, ouvrir, finir tout de suite,
--     acheter), la tour sortie (attribut « Hatch » du joueur) ;
--   * le tuto des nouveaux joueurs : son étape (champ `tutorial`, Levels.TUTORIAL), « Passer le tuto », et les
--     statistiques des nouveaux joueurs (Hub/Funnel.luau) ;
--   * publier l'état du joueur (attributs LevelsState, LevelArena : voir Remotes.luau, LevelAction).
-- Le client (LevelsUI.luau) ne décide rien : il envoie des demandes (remote LevelAction), tout est revérifié ici.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local IdleConfig = require(Shared.IdleConfig)
local IdleTowers = require(Shared.IdleTowers)
local Levels = require(Shared.Levels)
local Remotes = require(Shared.Remotes)
local MockDataStore = require(script.Parent.Parent.MockDataStore)
local PlayerData = require(script.Parent.Parent.PlayerData)
local Funnel = require(script.Parent.Funnel)
local LevelArena = require(script.Parent.LevelArena)
local LevelGame = require(script.Parent.LevelGame)
local LevelTeams = require(script.Parent.LevelTeams)

local LevelsService = {}

local ACTION_COOLDOWN = 0.08 -- secondes entre deux demandes d'un joueur (on améliore vite, pendant un niveau)
local TRAINING_INTERVAL = 20 -- secondes entre deux calculs de l'entraînement des joueurs présents
local SAVE_INTERVAL = 30 -- au plus une sauvegarde de fin de niveau toutes les 30 s par joueur (le reste : sauvegarde automatique)
local MAX_STEP = 0.1 -- une image plus longue que ça (à-coup du serveur) ne fait pas sauter les monstres : le niveau ralentit
local EMPTY_PACKET = buffer.create(0)

-- Parties en cours : match = { game = LevelGame, slot = n° de la zone, players = { Player } (le chef d'abord ; ceux
-- qui s'en vont en sont retirés), syncTimer, shotsTimer }. sessions[joueur] = sa partie.
local matches = {} -- [match] = vrai
local sessions = {} -- [Player] = match
-- Tests Studio : joueurs d'essai (tables qui imitent un Player, voir debug « TeamFake ») et leurs données.
local fakePlayers = {} -- [UserId] = joueur d'essai
local fakeData = {} -- [joueur d'essai] = ses données des niveaux
local lastAction = {} -- [Player] = heure de sa dernière demande
local lastSave = {} -- [Player] = heure de sa dernière sauvegarde de fin de niveau
local savingAllowed = true -- faux pendant le départ d'un joueur : sa sauvegarde finale suit, pas besoin d'une autre
local plotOf: (Player) -> number? = function()
	return nil
end
local clockOffset = 0 -- tests Studio : secondes ajoutées à l'heure (entraînement pendant une absence)
-- « LES AMIS » (Levels.luau).
local friendsHere = {} -- [Player] = { [Player] = true } : ses amis Roblox sur ce serveur (joueurs d'essai compris)
-- Récompenses d'invitation en attente : clé « Inviter_<UserId> » = { UserId des amis venus grâce à lui pendant son
-- absence }, prises à sa prochaine arrivée. Dans Studio : en mémoire, comme la sauvegarde (Config.Data).
local inviteStore = if RunService:IsStudio() and Config.Data.MOCK_IN_STUDIO then MockDataStore.new() else DataStoreService:GetDataStore(Config.Data.INVITES_DATASTORE_NAME)

local changedCallbacks = {} -- appelées quand l'état d'un joueur est publié (Hub/init.luau : son camp suit)

local function now(): number
	return os.time() + clockOffset
end

-- Vrai pour un vrai joueur (un joueur d'essai des tests Studio n'a ni client, ni sauvegarde, ni statistiques).
local function real(player): boolean
	return typeof(player) == "Instance"
end

local function notify(player: Player, message: string, kind: string?)
	if real(player) and player.Parent then
		Remotes.get("Notify"):FireClient(player, message, kind or "Info", "Levels")
	end
end

-- Le joueur de ce UserId (joueur d'essai compris), nil s'il n'est pas dans le serveur.
local function playerById(id: number): Player?
	return fakePlayers[id] or Players:GetPlayerByUserId(id)
end

----------------------------------------------------------------------
-- État publié
----------------------------------------------------------------------

-- Données des niveaux du joueur (data.levels), nil tant que sa sauvegarde n'est pas chargée.
local function levelsOf(player: Player)
	local fake = fakeData[player]
	if fake then
		return fake
	end
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
	-- Couveuses : l'œuf de chacune et le temps qui reste (secondes, à cet instant : le client décompte).
	local hatchers = {}
	for index, hatcher in levels.hatchers do
		hatchers[index] = { egg = hatcher.egg, readyIn = if hatcher.egg ~= "" then math.max(0, hatcher.readyAt - now()) else 0 }
	end
	player:SetAttribute("LevelsState", HttpService:JSONEncode({
		best = levels.best,
		coins = levels.coins,
		towers = Levels.ownedTowers(levels), -- tours débloquées, dans l'ordre de la barre rapide
		xp = xp,
		slots = levels.slots,
		wins = levels.wins,
		losses = levels.losses,
		tutorial = levels.tutorial, -- étape du tuto (Levels.TUTORIAL), lue par TutorialUI
		eggs = levels.eggs, -- œufs en réserve : { [type] = nombre }
		hatchers = hatchers, -- couveuses : { { egg, readyIn } }
	}))
	if real(player) then
		PlayerData.setLevel(player, levels.best) -- colonne « Level » de la liste des joueurs
		for _, callback in changedCallbacks do
			task.spawn(callback, player, levels, now())
		end
	end
	LevelTeams.refresh(player) -- (la fenêtre de l'équipe montre le niveau réussi de chacun)
end

-- callback(player, data.levels, heure du serveur) à chaque publication de l'état d'un joueur (emplacements, XP,
-- pièces, couveuses...). L'heure (os.time, plus le décalage des tests Studio) sert à décompter les couveuses.
function LevelsService.onChanged(callback: (Player, any) -> ())
	table.insert(changedCallbacks, callback)
end

-- Entraînement du camp jusqu'à maintenant (emplacements, même pendant une absence) : Levels.accrueTraining.
local function train(player: Player): boolean
	local levels = levelsOf(player)
	if not levels then
		return false
	end
	return next(Levels.accrueTraining(levels, now())) ~= nil
end

----------------------------------------------------------------------
-- Les amis (« LES AMIS », Levels.luau) : bonus d'ami sur le serveur, récompenses d'invitation
----------------------------------------------------------------------

-- Nombre d'amis Roblox de ce joueur sur ce serveur (attribut « FriendsHere » : son écran le montre).
local function friendCount(player): number
	local count = 0
	for other in friendsHere[player] or {} do
		if other.Parent then
			count += 1
		end
	end
	return count
end

local function setFriends(a, b)
	friendsHere[a] = friendsHere[a] or {}
	friendsHere[b] = friendsHere[b] or {}
	friendsHere[a][b] = true
	friendsHere[b][a] = true
	for _, player in { a, b } do
		if player.Parent then
			player:SetAttribute("FriendsHere", friendCount(player))
		end
	end
end

-- Un joueur arrive : est-il ami Roblox avec ceux qui sont déjà là ? (IsFriendsWith demande à Roblox : en tâche à
-- part, une réponse ratée = pas amis.)
local function findFriends(player: Player)
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local ok, friends = pcall(player.IsFriendsWith, player, other.UserId)
			if ok and friends and player.Parent and other.Parent then
				setFriends(player, other)
			end
		end
	end
	if player.Parent then
		player:SetAttribute("FriendsHere", friendCount(player))
	end
end

local function forgetFriends(player)
	for other in friendsHere[player] or {} do
		if friendsHere[other] then
			friendsHere[other][player] = nil
			if other.Parent then
				other:SetAttribute("FriendsHere", friendCount(other))
			end
		end
	end
	friendsHere[player] = nil
end

local function inviteKey(userId: number): string
	return "Inviter_" .. userId
end

-- Un ami (friendId) est venu grâce à `inviterId`, qui n'est pas sur ce serveur : noté pour sa prochaine arrivée.
local function storePendingInvite(inviterId: number, friendId: number)
	local ok, err = pcall(function()
		inviteStore:UpdateAsync(inviteKey(inviterId), function(list)
			list = if typeof(list) == "table" then list else {}
			if not table.find(list, friendId) and #list < Levels.FRIENDS.INVITE_MAX then
				table.insert(list, friendId)
			end
			return list
		end)
	end)
	if not ok then
		warn("[Niveaux] Récompense d'invitation pas notée :", err)
	end
end

-- Celui qui a invité reçoit sa récompense pour chaque ami venu grâce à lui (friendName : le nom de l'ami, s'il n'y
-- en a qu'un et qu'il est sur ce serveur). Renvoie le nombre de récompenses données.
local function rewardInviter(inviter: Player, friendIds: { number }, friendName: string?): number
	local levels = levelsOf(inviter)
	if not levels then
		return 0
	end
	local given = 0
	for _, friendId in friendIds do
		if Levels.claimInvite(levels, inviter.UserId, friendId) then
			given += 1
		end
	end
	local reward = Levels.FRIENDS.INVITE_REWARD
	if given == 1 and friendName then
		notify(inviter, `🎁 Ton ami {friendName} est venu grâce à ton invitation : +{reward} pièces de niveau !`, "Success")
	elseif given == 1 then
		notify(inviter, `🎁 Un ami est venu grâce à ton invitation : +{reward} pièces de niveau !`, "Success")
	elseif given > 1 then
		notify(inviter, `🎁 {given} amis sont venus grâce à tes invitations : +{given * reward} pièces de niveau !`, "Success")
	end
	if given > 0 then
		publish(inviter)
		print(`[Niveaux] {inviter.Name} : {given} ami(s) venu(s) grâce à ses invitations -> +{given * reward} pièces de niveau`)
	end
	return given
end

-- Amis venus grâce à ce joueur pendant qu'il n'était pas sur ce serveur (DataStore) : ses récompenses.
local function claimPendingInvites(player: Player): number
	local pending = {}
	local ok, err = pcall(function()
		inviteStore:UpdateAsync(inviteKey(player.UserId), function(list)
			pending = if typeof(list) == "table" then list else {}
			return if #pending > 0 then {} else nil -- (rien en attente : rien à écrire)
		end)
	end)
	if not ok then
		warn("[Niveaux] Récompenses d'invitation pas lues :", err)
		return 0
	end
	return rewardInviter(player, pending)
end

-- Un joueur arrive grâce à l'invitation de `inviterId` : sa récompense (une seule fois), puis celle de celui qui l'a
-- invité : tout de suite s'il est sur ce serveur (ses données chargées), sinon à sa prochaine arrivée.
local function welcomeInvited(player, inviterId: number): boolean
	local levels = levelsOf(player)
	if not levels or not Levels.claimArrival(levels, player.UserId, inviterId) then
		return false
	end
	local inviter = playerById(inviterId)
	local reward = Levels.FRIENDS.INVITE_REWARD
	notify(player, if inviter then `🎁 Tu es venu grâce à l'invitation de {inviter.DisplayName} : +{reward} pièces de niveau !` else `🎁 Tu es venu grâce à l'invitation d'un ami : +{reward} pièces de niveau !`, "Success")
	publish(player)
	print(`[Niveaux] {player.Name} : venu grâce à l'invitation de {inviterId} -> +{reward} pièces de niveau`)
	if inviter and levelsOf(inviter) then
		rewardInviter(inviter, { player.UserId }, player.DisplayName)
	else
		storePendingInvite(inviterId, player.UserId)
	end
	return true
end

-- Arrivée d'un vrai joueur (données chargées) : ses amis sur le serveur, les récompenses d'invitation qui
-- l'attendent, et la sienne s'il vient d'une invitation (Roblox : GetJoinData().ReferredByPlayerId).
local function onArrival(player: Player)
	findFriends(player)
	claimPendingInvites(player)
	local ok, joinData = pcall(player.GetJoinData, player)
	local inviterId = if ok and typeof(joinData) == "table" then math.floor(tonumber(joinData.ReferredByPlayerId) or 0) else 0
	if inviterId ~= 0 then
		welcomeInvited(player, inviterId)
	end
end

----------------------------------------------------------------------
-- Un niveau : lancer, finir, ranger
----------------------------------------------------------------------

-- Fin d'un niveau pour UN joueur de la partie (victoire, défaite ou abandon), une seule fois : pièces de niveau (avec
-- le bonus d'équipe et le bonus d'ami sur le serveur), niveau suivant débloqué, XP d'entraînement des types de tours qu'IL a posés. member = lui dans
-- la partie (LevelGame). showResult : le résumé part dans l'attribut « Result_<n°> » de la zone (« Result » aussi
-- pour le premier joueur) : l'écran de fin de son client. (Pas pour celui qui s'en va pendant que d'autres jouent.)
local function rewardMember(player: Player, game, won: boolean, member, showResult: boolean)
	local levels = levelsOf(player)
	if not levels or not member then
		return
	end
	local level = game.level
	local firstClear = won and level > levels.best
	local progress = game:progress()
	local friendHere = friendCount(player) > 0
	local reward = Levels.bonusReward(Levels.reward(level, won, firstClear, progress), game.teamSize, friendHere)
	levels.coins += reward
	local egg, eggKept = nil, false
	if won then
		-- « LES ŒUFS » : un œuf à chaque victoire (perdu si la réserve est pleine).
		egg = Levels.eggFor(level, firstClear)
		eggKept = Levels.addEgg(levels, egg)
		levels.best = math.max(levels.best, level)
		levels.wins += 1
		-- Tuto : le guide du premier niveau est fini, la flèche montrera la boutique dès qu'il pourra acheter une tour.
		levels.tutorial = math.max(levels.tutorial, Levels.TUTORIAL.SHOP)
		if real(player) then
			Funnel.reach(player, Funnel.STEP.Won)
		end
	else
		levels.losses += 1
	end

	-- XP : d'abord celle du camp jusqu'à maintenant, puis celle du niveau joué, pour chaque type de tour posé.
	train(player)
	local before = Levels.trainingLevels(levels)
	local xp = Levels.playXp(won, progress)
	local towers, perks = {}, {}
	for _, towerType in IdleTowers.ORDER do
		if member.usedTowers[towerType] then
			table.insert(towers, towerType)
			if xp > 0 then
				levels.xp[towerType] = (levels.xp[towerType] or 0) + xp
				for _, perk in Levels.perksBetween(towerType, before[towerType], Levels.trainingLevel(levels.xp[towerType])) do
					table.insert(perks, { tower = towerType, name = perk.name, text = perk.text })
				end
			end
		end
	end

	if showResult then
		local result = HttpService:JSONEncode({
		won = won,
		level = level,
		reward = reward,
		firstClear = firstClear,
		coins = levels.coins,
		kills = game.kills,
		total = #game.queue,
		lives = game.lives,
		bigLeaks = game.leakedBig, -- colosses et boss arrivés au château
		xp = xp,
		towers = towers,
		perks = perks, -- améliorations d'entraînement débloquées par cette partie
		nextLevel = if won and level < Levels.COUNT then level + 1 else nil,
		seconds = math.floor(game.clock),
		team = game.teamSize, -- joueurs de la partie (1 = seul) : l'écran de fin dit le bonus d'équipe
		friend = friendHere, -- un ami Roblox sur le serveur : l'écran de fin dit le bonus d'ami
		egg = egg, -- l'œuf gagné (nil : défaite)
		eggKept = eggKept, -- faux : réserve pleine, l'œuf est perdu
		})
		game:setAttr("Result_" .. member.key, result)
		if member == game then
			game:setAttr("Result", result)
		end
	end
	publish(player)
	local teamText = if game.teamSize > 1 then ` (équipe de {game.teamSize})` else ""
	print(`[Niveaux] {player.Name} : niveau {level} {if won then "gagné" else "perdu"}{teamText} ({game.kills}/{#game.queue} monstres, {game.lives} vies, {math.floor(game.clock)} s) -> +{reward} pièces de niveau`)
	local clock = os.clock()
	if real(player) and savingAllowed and clock - (lastSave[player] or -math.huge) >= SAVE_INTERVAL then
		lastSave[player] = clock
		task.spawn(PlayerData.save, player)
	end
end

-- Range une partie : tous ses joueurs en sortent. Encore en cours : c'est un abandon, compté comme une défaite pour
-- chacun (récompense selon l'avancée). keepSlot = un autre niveau démarre tout de suite dans la même zone (la carte
-- reste) ; stay = joueurs qui jouent ce nouveau niveau (leur vue ne bouge pas) ; les autres retournent au camp
-- (ils ne regardent plus la zone).
local function closeMatch(match, keepSlot: boolean?, stay: { [any]: boolean }?)
	if not matches[match] then
		return
	end
	matches[match] = nil
	local game = match.game
	if game.state == "Running" then
		game:finish(false)
	end
	for _, player in match.players do
		if sessions[player] == match then
			sessions[player] = nil
		end
	end
	game:destroy()
	for _, player in match.players do
		if real(player) and player.Parent then
			-- Le client efface tout de suite ce qu'il affichait de la zone (monstres, feu), comme pour une parcelle.
			Remotes.get("PlotSync"):FireClient(player, game.index, EMPTY_PACKET, 0, "Clear")
		end
		if player.Parent and not (stay and stay[player]) then
			player:SetAttribute("LevelArena", nil)
			player.ReplicationFocus = nil
		end
	end
	if not keepSlot then
		LevelArena.clear(match.slot)
	end
end

-- Le joueur quitte sa partie (bouton « Quitter », départ du jeu, ou son chef d'équipe lance un autre niveau). Seul
-- dans la partie : elle est rangée (abandon si elle était en cours). En équipe : abandon pour lui seul, les autres
-- continuent ; ses tours restent et tirent toujours.
local function leaveMatch(player: Player)
	local match = sessions[player]
	if not match then
		return
	end
	if #match.players <= 1 then
		closeMatch(match)
		return
	end
	local game = match.game
	local member = game:memberOf(player)
	local running = game.state == "Running"
	if running then
		rewardMember(player, game, false, member, false)
	end
	sessions[player] = nil
	table.remove(match.players, table.find(match.players, player))
	game:removeMember(member)
	if player.Parent then
		if real(player) then
			Remotes.get("PlotSync"):FireClient(player, game.index, EMPTY_PACKET, 0, "Clear")
		end
		player:SetAttribute("LevelArena", nil)
		player.ReplicationFocus = nil
	end
	if running then
		for _, other in match.players do
			notify(other, `{player.DisplayName} a quitté le niveau : ses tours restent et continuent de tirer`, "Info")
		end
	end
end

-- Une zone de combat libre : `preferred` si aucune partie ne l'occupe, sinon la première libre (nil : aucune).
local function freeSlot(preferred: number?): number?
	local used = {}
	for match in matches do
		used[match.slot] = true
	end
	if preferred and not used[preferred] and LevelArena.get(preferred) then
		return preferred
	end
	for slot = 1, Levels.ARENA_SLOTS do
		if not used[slot] and LevelArena.get(slot) then
			return slot
		end
	end
	return nil
end

-- Lance le niveau `level` pour ce joueur, et pour toute son équipe s'il en est le chef (ses coéquipiers quittent ce
-- qu'ils jouaient et le rejoignent). Renvoie (vrai) ou (faux, raison).
local function startLevel(player: Player, level: any): (boolean, string?)
	local levels = levelsOf(player)
	if not levels then
		return false, "Tes données ne sont pas encore chargées"
	end
	if typeof(level) ~= "number" or level ~= math.floor(level) or level < 1 or level > Levels.COUNT then
		return false, "Ce niveau n'existe pas encore"
	end
	local team = LevelTeams.teamOf(player)
	if team and team.leader ~= player then
		return false, `C'est {team.leader.DisplayName}, le chef de ton équipe, qui lance les niveaux (ou quitte l'équipe pour jouer seul)`
	end
	local group = LevelTeams.membersOf(player) -- (lui d'abord : il est le chef)
	local stay = {}
	for _, member in group do
		local data = levelsOf(member)
		if not data then
			return false, `Les données de {member.DisplayName} ne sont pas encore chargées`
		end
		if level > data.best + 1 then
			return false, if member == player then `Réussis d'abord le niveau {data.best + 1}` else `Le niveau {level} n'est pas encore ouvert pour {member.DisplayName}`
		end
		stay[member] = true
	end
	local current = sessions[player]
	for _, member in group do
		local match = sessions[member]
		if match and match ~= current and match.game.state == "Running" and #match.players > 1 then
			return false, `{member.DisplayName} joue encore un niveau avec d'autres joueurs : attends la fin`
		end
	end
	-- Chacun quitte ce qu'il jouait. La zone du chef resert si tous les joueurs de sa partie rejouent avec lui.
	local function allStay(match): boolean
		for _, other in match.players do
			if not stay[other] then
				return false
			end
		end
		return true
	end
	local reuse = if current and allStay(current) then current else nil
	for _, member in group do
		local match = sessions[member]
		if match and match ~= reuse then
			if allStay(match) then
				closeMatch(match, false, stay)
			else
				leaveMatch(member)
			end
		end
	end
	if reuse then
		closeMatch(reuse, true, stay)
	end
	local slot = if reuse then reuse.slot else freeSlot(plotOf(player))
	if not slot then
		return false, "Aucune zone de combat libre pour l'instant"
	end
	for _, member in group do
		train(member)
	end
	local definition = Levels.definition(level)
	-- En équipe : la carte d'équipe du territoire, un couloir par joueur (Levels.mapFor).
	local arena = LevelArena.build(slot, Levels.mapFor(level, #group), definition.palier)
	local others = {}
	for index = 2, #group do
		local data = levelsOf(group[index])
		table.insert(others, { player = group[index], unlocked = table.clone(data.towers), training = Levels.trainingLevels(data) })
	end
	local match = { slot = slot, players = group, syncTimer = 0, shotsTimer = 0 }
	match.game = LevelGame.new(arena, player, {
		level = level,
		unlocked = table.clone(levels.towers),
		training = Levels.trainingLevels(levels),
		startingTower = level == 1 and #group == 1,
		team = others,
		onEnd = function(finished, won)
			for _, member in match.players do
				rewardMember(member, finished, won, finished:memberOf(member), true)
			end
		end,
	})
	if #group > 1 then
		-- Les joueurs de la partie, pour l'écran du niveau (or de chacun, « Tour de ... ») : { { id, key, name } }.
		local names = {}
		for _, member in group do
			table.insert(names, { id = member.UserId, key = Levels.memberKey(member.UserId), name = member.DisplayName })
		end
		match.game:setAttr("Team", HttpService:JSONEncode(names))
	end
	-- Le nom de chacun au-dessus de la porte de son couloir (le joueur n défend le couloir n ; seul : aucun nom).
	local laneNames = {}
	if #group > 1 then
		for _, member in group do
			table.insert(laneNames, member.DisplayName)
		end
	end
	LevelArena.setLaneNames(slot, laneNames)
	matches[match] = true
	for _, member in group do
		sessions[member] = match
		if real(member) then
			Funnel.reach(member, Funnel.STEP.Started)
		end
		member.ReplicationFocus = arena.focus
		member:SetAttribute("LevelArena", arena.index)
		publish(member)
		if member ~= player then
			notify(member, `{player.DisplayName} lance le niveau {level} pour l'équipe`, "Info")
		end
	end
	return true, nil
end

----------------------------------------------------------------------
-- Les œufs (« LES ŒUFS », Levels.luau) : les poser dans une couveuse, les ouvrir, finir tout de suite, acheter
-- une couveuse. Les couveuses sont sur la parcelle du joueur (Hub/Camp.luau) et dans l'onglet Œufs (LevelsUI).
----------------------------------------------------------------------
local hatchRandom = Random.new()
local hatchCount = 0 -- n° de la dernière ouverture (attribut « Hatch » : le client montre la tour sortie)
local forcedHatch = {} -- [joueur] = tour qui sortira du prochain œuf (tests Studio : debug « EggForce »)

local function hatcherAt(levels, index: any)
	return if typeof(index) == "number" then levels.hatchers[index] else nil
end

-- Pose un œuf de sa réserve dans une couveuse vide : il éclot dans EGGS[type].seconds.
local function startEgg(levels, index: any, eggType: any): (boolean, string?)
	local hatcher = hatcherAt(levels, index)
	if not hatcher or typeof(eggType) ~= "string" or not Levels.EGGS[eggType] then
		return false, nil
	end
	if hatcher.egg ~= "" then
		return false, "Cette couveuse est déjà occupée"
	end
	if (levels.eggs[eggType] or 0) < 1 then
		return false, "Tu n'as plus d'œuf de ce type : gagne des niveaux pour en avoir"
	end
	levels.eggs[eggType] -= 1
	if levels.eggs[eggType] <= 0 then
		levels.eggs[eggType] = nil
	end
	hatcher.egg = eggType
	hatcher.readyAt = now() + Levels.EGGS[eggType].seconds
	return true, nil
end

-- Ouvre l'œuf prêt d'une couveuse : une tour au hasard (chances de l'œuf), nouvelle ou doublon (XP). Le résultat part
-- dans l'attribut « Hatch » du joueur : son écran le montre.
local function openEgg(player, levels, index: any): (boolean, string?)
	local hatcher = hatcherAt(levels, index)
	if not hatcher or hatcher.egg == "" then
		return false, nil
	end
	if now() < hatcher.readyAt then
		return false, "Cet œuf n'est pas encore prêt"
	end
	local eggType = hatcher.egg
	local tower = forcedHatch[player] or Levels.rollEgg(eggType, hatchRandom:NextNumber())
	forcedHatch[player] = nil
	local isNew, xp = Levels.hatchTower(levels, tower)
	if isNew then
		levels.tutorial = Levels.TUTORIAL.DONE -- (une nouvelle tour, comme un achat : le tuto est fini)
	end
	hatcher.egg, hatcher.readyAt = "", 0
	hatchCount += 1
	player:SetAttribute("Hatch", HttpService:JSONEncode({ n = hatchCount, egg = eggType, tower = tower, new = isNew, xp = xp }))
	print(`[Niveaux] {player.Name} : {eggType} ouvert -> {tower} ({if isNew then "nouvelle" else `doublon, +{xp} XP`})`)
	return true, nil
end

-- Finit tout de suite l'œuf d'une couveuse, avec des pièces de niveau (Levels.skipCost).
local function skipEgg(levels, index: any): (boolean, string?)
	local hatcher = hatcherAt(levels, index)
	if not hatcher or hatcher.egg == "" then
		return false, nil
	end
	local cost = Levels.skipCost(hatcher.readyAt - now())
	if cost <= 0 then
		return false, nil
	end
	if levels.coins < cost then
		return false, `Il te manque {cost - levels.coins} pièces de niveau`
	end
	levels.coins -= cost
	hatcher.readyAt = now()
	return true, nil
end

-- Achète la couveuse suivante (Levels.HATCHER_COST).
local function buyHatcher(player, levels): (boolean, string?)
	local index = #levels.hatchers + 1
	local price = Levels.HATCHER_COST[index]
	if not price then
		return false, "Tu as déjà toutes les couveuses"
	end
	if levels.coins < price then
		return false, `Il te manque {price - levels.coins} pièces de niveau`
	end
	levels.coins -= price
	table.insert(levels.hatchers, { egg = "", readyAt = 0 })
	notify(player, `Nouvelle couveuse : {index} œufs peuvent éclore en même temps`, "Success")
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
	levels.tutorial = Levels.TUTORIAL.DONE -- première tour achetée : le tuto est fini
	if real(player) then
		Funnel.reach(player, Funnel.STEP.Bought)
	end
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

-- Entraînement acheté avec des pièces (bouton ⚡ de l'onglet Entraînement) : l'XP qui manque à la tour pour son
-- prochain niveau d'entraînement (Levels.trainingPurchase).
local function buyTraining(levels, towerType: any): (boolean, string?)
	if typeof(towerType) ~= "string" or not levels.towers[towerType] then
		return false, "Cette tour n'est pas encore à toi"
	end
	local target, price = Levels.trainingPurchase(levels.xp[towerType])
	if not target or not price then
		return false, "Cette tour est déjà au maximum de son entraînement"
	end
	if levels.coins < price then
		return false, `Il te manque {price - levels.coins} pièces de niveau`
	end
	levels.coins -= price
	levels.xp[towerType] = target
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
		leaveMatch(player)
		publish(player)
		return true, nil
	elseif action == "TeamInvite" then
		return LevelTeams.invite(player, a)
	elseif action == "TeamAnswer" then
		return LevelTeams.answer(player, a, b == true)
	elseif action == "TeamLeave" then
		return LevelTeams.leave(player)
	elseif action == "Tutorial" then
		-- Bouton « Passer le tuto » (TutorialUI) : fini pour de bon.
		if a == "Skip" and levels.tutorial < Levels.TUTORIAL.DONE then
			if real(player) then
				Funnel.onSkip(player, levels.tutorial)
			end
			levels.tutorial = Levels.TUTORIAL.DONE
			publish(player)
			print(`[Niveaux] {player.Name} : tuto passé`)
		end
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
	elseif action == "TrainBuy" then
		train(player)
		ok, reason = buyTraining(levels, a)
	elseif action == "Bar" then
		ok, reason = setBar(levels, a)
	elseif action == "EggStart" then
		ok, reason = startEgg(levels, a, b)
	elseif action == "EggOpen" then
		ok, reason = openEgg(player, levels, a)
	elseif action == "EggSkip" then
		ok, reason = skipEgg(levels, a)
	elseif action == "HatcherBuy" then
		ok, reason = buyHatcher(player, levels)
	end
	if ok ~= nil then
		if ok then
			publish(player)
		end
		return ok, reason
	end

	-- Pendant un niveau : tout est décidé par LevelGame (or de ce joueur, ses limites, emplacement), pour lui.
	local match = sessions[player]
	local game = match and match.game
	local member = game and game:memberOf(player)
	if not game or not member then
		return false, nil
	end
	if action == "Place" then
		if typeof(a) ~= "string" or typeof(b) ~= "number" or typeof(c) ~= "number" then
			return false, nil
		end
		local placed, why = game:placeTower(a, Vector3.new(b, 0, c), member)
		if placed and real(player) then
			Funnel.reach(player, Funnel.STEP.Placed)
		end
		return placed, why
	elseif action == "Upgrade" then
		if typeof(a) ~= "number" then
			return false, nil
		end
		local upgraded, why = game:upgradeTower(a, member)
		if upgraded and real(player) then
			Funnel.reach(player, Funnel.STEP.Upgraded)
		end
		return upgraded, why
	elseif action == "Sell" then
		if typeof(a) ~= "number" then
			return false, nil
		end
		local sold, _, why = game:sellTower(a, member)
		return sold, why
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
	LevelTeams.init({ levelsOf = levelsOf, playerById = playerById, notify = notify })

	local function onLoaded(player: Player)
		train(player) -- entraînement pendant l'absence (première visite : l'heure est seulement notée)
		local levels = levelsOf(player)
		if levels then
			Funnel.onLoaded(player, levels.tutorial)
		end
		publish(player)
		task.spawn(onArrival, player) -- (amis, invitations : réponses de Roblox et DataStore, en tâche à part)
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
		local ok, err = pcall(leaveMatch, player)
		savingAllowed = true
		if not ok then
			warn("[Niveaux] Niveau mal rangé au départ de", player.Name, ":", err)
		end
		train(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastAction[player] = nil
		lastSave[player] = nil
		LevelTeams.removePlayer(player)
		forgetFriends(player)
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

	-- Parties en cours : simulation à chaque image, monstres et tirs envoyés à leurs joueurs seulement.
	local syncRemote = Remotes.get("PlotSync")
	local shotsRemote = Remotes.get("PlotShots")
	local function sendAll(match, remote: RemoteEvent, packet: buffer, count: number)
		for _, player in match.players do
			if real(player) and player.Parent then
				remote:FireClient(player, match.game.index, packet, count)
			end
		end
	end
	RunService.Heartbeat:Connect(function(dt)
		local step = math.min(dt, MAX_STEP)
		for match in matches do
			local game = match.game
			game:step(step)
			match.syncTimer += dt
			if match.syncTimer >= 1 / IdleConfig.SYNC_RATE then
				match.syncTimer = 0
				local packet, count = game:buildSyncPacket()
				if packet then
					sendAll(match, syncRemote, packet, count)
				end
			end
			match.shotsTimer += dt
			if match.shotsTimer >= 1 / IdleConfig.SHOTS_RATE then
				match.shotsTimer = 0
				local packet, count = game:takeShotsPacket()
				if packet then
					sendAll(match, shotsRemote, packet, count)
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
--                                                   state, gold (le sien), lives, kills, total, clock, towers, alive,
--                                                   simSpeed, team (joueurs au départ), players (encore là),
--                                                   members = { { id, gold, departed, towers } }, firstHealth),
--                                                   team (son équipe : { leader, members = { UserId } }) }
--   Invoke(player, "Levels", "Action", "Start", 1) -> une demande, comme le remote LevelAction (sans l'anti-spam) ;
--                                                   renvoie (réussie, raison)
--   Invoke(player, "Levels", "Set", "coins", 500) -> change un champ de data.levels (puis nettoyage et publication)
--   Invoke(player, "Levels", "Reset")           -> ses données des niveaux redeviennent celles d'un nouveau joueur
--                                                   (niveau en cours rangé) : le tuto recommence
--   Invoke(player, "Levels", "Funnel")          -> statistiques des nouveaux joueurs envoyées pendant cette visite
--                                                   (Hub/Funnel.luau, Funnel.debug)
--   Invoke(player, "Levels", "Gold", 100)        -> ajoute de l'or au niveau en cours (le sien)
--   Invoke(player, "Levels", "Skip", 30)         -> le niveau en cours avance de 30 s d'un coup (pas de 1/30 s)
--   Invoke(player, "Levels", "KillAll")          -> tue tous les monstres présents ; renvoie leur nombre
--   Invoke(player, "Levels", "Finish", true)     -> finit le niveau tout de suite (true = gagné)
--   Invoke(player, "Levels", "Clock", 3600)      -> avance l'heure du serveur d'une heure (entraînement du camp), puis
--                                                   compte l'entraînement ; renvoie l'XP de chaque tour
--   Invoke(player, "Levels", "TeamFake", "Robin", 5) -> un joueur d'essai (une table qui imite un Player : pas de
--                                                   client), qui a réussi 5 niveaux ; renvoie son UserId (négatif)
--   Invoke(player, "Levels", "TeamAs", id, "Start", 3) -> une demande faite par ce joueur d'essai (comme LevelAction)
--   Invoke(player, "Levels", "TeamFakeState", id) -> { levels, attributes, active } d'un joueur d'essai
--   Invoke(player, "Levels", "TeamGone", id)     -> ce joueur d'essai quitte le jeu (sa partie, son équipe)
--   Invoke(player, "Levels", "FriendFake", id)   -> ce joueur d'essai devient un ami Roblox du joueur ; renvoie
--                                                   FriendsHere du joueur
--   Invoke(player, "Levels", "InviteJoin", id)   -> ce joueur d'essai arrive grâce à l'invitation du joueur
--                                                   (welcomeInvited) ; renvoie vrai si sa récompense est donnée
--   Invoke(player, "Levels", "InvitePending", 9) -> l'ami 9 est venu grâce au joueur pendant son absence (noté)
--   Invoke(player, "Levels", "Egg", "Rare", 2)    -> 2 œufs rares de plus dans sa réserve ; renvoie la réserve
--   Invoke(player, "Levels", "EggForce", "Laser") -> le prochain œuf ouvert donnera cette tour
--   Invoke(player, "Levels", "InviteClaim")      -> le joueur prend ses récompenses d'invitation en attente ;
--                                                   renvoie leur nombre
--   Invoke(player, "Levels", "Bench", 6, 60, 12) -> 6 niveaux 10 joués en même temps pendant 60 s de jeu, 12 tours
--                                                   chacun, hors de la carte : { games, steps, enemiesPeak, averageMs,
--                                                   p99Ms, worstMs } (coût du serveur par image pour les 6 combats)
----------------------------------------------------------------------
-- Ce que les tests lisent d'une partie, pour un de ses joueurs.
local function describeMatch(player)
	local match = sessions[player]
	local game = match and match.game
	if not game then
		return nil
	end
	local member = game:memberOf(player)
	local towers, alive = 0, 0
	for _ in game.towers do
		towers += 1
	end
	for _, enemy in game.enemies do
		if not enemy.dead then
			alive += 1
		end
	end
	local members = {}
	for _, other in game.members do
		local count = 0
		for _, tower in game.towers do
			if tower.owner == other then
				count += 1
			end
		end
		table.insert(members, { id = other.userId, gold = other.gold, departed = other.departed, towers = count })
	end
	return {
		level = game.level,
		state = game.state,
		gold = if member then member.gold else game.gold,
		lives = game.lives,
		kills = game.kills,
		total = #game.queue,
		spawned = game.queueIndex - 1,
		clock = game.clock,
		towers = towers,
		alive = alive,
		simSpeed = game.simSpeed,
		index = game.index,
		team = game.teamSize,
		players = #match.players,
		members = members,
		firstHealth = game.queue[1] and game.queue[1].health,
	}
end

local fakeCount = 0
-- Un joueur d'essai pour les tests Studio du jeu en équipe : une table qui imite un Player (UserId négatif, nom,
-- attributs gardés dans `attributes`), avec les données d'un nouveau joueur qui a réussi `best` niveaux.
local function makeFake(name: string, best: number)
	fakeCount += 1
	local fake = { UserId = -1000 - fakeCount, Name = name, DisplayName = name, Parent = Players, ReplicationFocus = nil, attributes = {} }
	function fake:SetAttribute(key: string, value: any)
		self.attributes[key] = value
	end
	function fake:GetAttribute(key: string): any
		return self.attributes[key]
	end
	local data = Levels.defaultData()
	data.best = math.clamp(math.floor(best), 0, Levels.COUNT)
	data.tutorial = Levels.TUTORIAL.DONE
	fakePlayers[fake.UserId] = fake
	fakeData[fake] = data
	publish(fake :: any)
	return fake
end

function LevelsService.debug(player: Player, command: string, ...)
	local levels = levelsOf(player)
	local session = sessions[player]
	local game = session and session.game
	local member = game and game:memberOf(player)
	if command == "State" then
		local team = LevelTeams.teamOf(player)
		local ids = {}
		for _, other in if team then team.members else {} do
			table.insert(ids, other.UserId)
		end
		return { levels = levels, active = describeMatch(player), team = if team then { leader = team.leader.UserId, members = ids } else nil }
	elseif command == "TeamFake" then
		local name, best = ...
		return makeFake(tostring(name or "Robin"), tonumber(best) or 1).UserId
	elseif command == "TeamAs" then
		local id = ...
		local fake = fakePlayers[id]
		if not fake then
			return false, "joueur d'essai inconnu"
		end
		return handle(fake, select(2, ...))
	elseif command == "TeamFakeState" then
		local fake = fakePlayers[...]
		return if fake then { levels = fakeData[fake], attributes = table.clone(fake.attributes), active = describeMatch(fake) } else nil
	elseif command == "FriendFake" then
		local fake = fakePlayers[...]
		if fake then
			setFriends(player, fake)
		end
		return friendCount(player)
	elseif command == "InviteJoin" then
		local fake = fakePlayers[...]
		return fake ~= nil and welcomeInvited(fake, player.UserId)
	elseif command == "InvitePending" then
		storePendingInvite(player.UserId, math.floor(tonumber((...)) or 0))
		return true
	elseif command == "InviteClaim" then
		return claimPendingInvites(player)
	elseif command == "Egg" and levels then
		local eggType, count = ...
		for _ = 1, math.floor(tonumber(count) or 1) do
			Levels.addEgg(levels, eggType)
		end
		publish(player)
		return table.clone(levels.eggs)
	elseif command == "EggForce" then
		forcedHatch[player] = if IdleTowers.Defs[...] then ... else nil
		return forcedHatch[player]
	elseif command == "TeamGone" then
		local fake = fakePlayers[...]
		if fake then
			leaveMatch(fake)
			LevelTeams.removePlayer(fake)
			forgetFriends(fake)
			fake.Parent = nil
			fakePlayers[fake.UserId] = nil
			fakeData[fake] = nil
		end
		return fake ~= nil
	elseif command == "Action" then
		return handle(player, ...)
	elseif command == "Set" and levels then
		local key, value = ...
		levels[key] = value
		local data = PlayerData.get(player)
		data.levels = Levels.cleanData(levels)
		publish(player)
		return data.levels
	elseif command == "Reset" and levels then
		leaveMatch(player)
		local data = PlayerData.get(player)
		data.levels = Levels.defaultData()
		train(player)
		publish(player)
		return data.levels
	elseif command == "Funnel" then
		return Funnel.debug(player)
	elseif command == "Gold" and member then
		member.gold += ...
		return member.gold
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

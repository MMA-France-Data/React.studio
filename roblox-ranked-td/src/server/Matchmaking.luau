-- Matchmaking ranked entre tous les serveurs lobby : on s'inscrit dans le cercle de l'arène, on repart jouer,
-- et quand un adversaire est trouvé, les DEUX joueurs doivent ACCEPTER le match avant la téléportation.
--
-- Fonctionnement :
--   1. Inscription (bouton « ⚔ S'INSCRIRE AU CLASSÉ » dans le cercle, vérifié par Hub/init.luau) -> entrée dans
--      la file partagée (SortedMap triée par MMR). Le joueur peut partir jouer : il reste inscrit.
--   2. Un seul serveur lobby à la fois (le « leader », élu avec un verrou) lit la file et forme des paires : ceux
--      qui attendent depuis le plus longtemps choisissent d'abord, chacun avec le joueur de MMR le plus proche
--      dans la fourchette (elle s'élargit avec l'attente). Pour chaque paire, il écrit une PROPOSITION (réponses,
--      heure limite), puis une INVITATION par joueur, puis retire les deux joueurs de la file.
--   3. Le serveur de chaque joueur trouve son invitation : fenêtre « MATCH TROUVÉ ! » (ACCEPT_SECONDS pour
--      répondre). Chaque réponse est écrite dans la proposition avec UpdateAsync : une écriture à la fois, donc
--      jamais deux décisions différentes.
--   4. Le serveur du 2e joueur qui accepte crée le match comme avant : serveur réservé, infos du match
--      (RankedTD_Matches, lues par Match/init.luau à l'arrivée), puis la proposition passe à « Started » avec
--      le code d'accès.
--   5. Le serveur de chaque joueur lit « Started » et téléporte SON joueur, une seule fois.
--   Refus, départ du jeu ou temps écoulé : celui qui n'a pas accepté quitte la file ; l'autre y retourne tout
--   seul avec son heure d'inscription (son attente est gardée : il reste prioritaire).
--
-- États d'un joueur (attribut QueueState, affiché par LobbyUI) :
--   Idle         pas inscrit
--   Joining      inscription en cours (écriture dans la file)
--   Searching    inscrit, en attente d'un adversaire (il peut jouer n'importe où sur la map)
--   Pending      match proposé : fenêtre « MATCH TROUVÉ ! », il doit ACCEPTER ou REFUSER
--   Accepted     il a accepté : « En attente de l'adversaire… »
--   Found        les deux ont accepté : création du match
--   Teleporting  téléportation vers le match
--
--   Idle -> Joining -> Searching        bouton S'INSCRIRE (écriture ratée : retour à Idle)
--   Searching -> Idle                   ANNULER, départ du jeu
--   Searching -> Pending                le leader l'a mis en paire
--   Pending -> Accepted                 ACCEPTER (le 2e qui accepte passe directement à Found)
--   Pending -> Idle                     REFUSER, ANNULER, départ, temps écoulé sans accepter : retiré de la file
--   Accepted/Found -> Idle              départ du jeu (après ACCEPTER, plus d'annulation : on attend l'autre)
--   Pending/Accepted -> Searching       l'adversaire a refusé, est parti ou n'a pas accepté à temps
--   Accepted -> Found                   l'adversaire accepte aussi
--   Found -> Teleporting                match créé (Studio : départ seulement annoncé, puis Idle)
--   Found -> Searching                  création ratée, rien après START_TIMEOUT, ou l'adversaire a quitté le jeu
--   Teleporting -> Idle                 téléportation ratée, ou toujours là après TELEPORT_TIMEOUT
--
-- Statuts d'une proposition (partagée par les serveurs des deux joueurs) :
--   Waiting  -> Refused   un joueur a refusé ou est parti (out[joueur] = "Refused" | "Left")
--            -> Expired   heure limite passée (out[joueur] = "Timeout" pour chaque joueur qui n'a pas accepté)
--            -> Starting  les deux ont accepté (starter = le serveur qui crée le match)
--   Starting -> Started   match créé (code d'accès)   | Failed : réservation ratée, ou rien après START_TIMEOUT
--            -> Refused   un joueur a quitté le jeu avant la création du match (out[joueur] = "Left")
-- Tout a une limite de temps (heure limite, START_TIMEOUT, TELEPORT_TIMEOUT, expirations MemoryStore) :
-- personne ne reste bloqué, même si un serveur s'arrête en plein milieu ou si MemoryStore ne répond plus.
--
-- Où c'est rangé : MatchmakingBackend.luau (MemoryStore dans le jeu publié ; en mémoire dans Studio, sans
-- téléportation). Tests Studio : Matchmaking.debug, commandes « Ranked » de ServerStorage.StudioDebug.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local Backend = require(script.Parent.MatchmakingBackend)

local MM = Config.Matchmaking

local Matchmaking = {}

-- Créé dans Matchmaking.start() : une erreur de MemoryStoreService au chargement du module empêcherait tout le
-- lobby de démarrer.
local backend = nil

-- Places de CE serveur dans la file, par UserId : { userId, player, name, mmr, games, joinedAt (heure
-- d'inscription, gardée en revenant dans la file), state, since (heure du dernier changement d'état),
-- proposal = { id, deadline, localDeadline, opponent }, seen = { [id de proposition] = true }, nextCheckAt,
-- refreshAt, busy, answering }.
-- Tests Studio : un adversaire factice est une place sans joueur (player = nil), traitée exactement comme le
-- joueur d'un autre serveur.
local seats = {}
local lastSignUp = {} -- [UserId] = os.clock() de la dernière inscription (anti-spam)
local lastStart = nil -- dernier match créé par ce serveur (tests Studio)
local fakeCount = 0 -- adversaires factices créés (tests Studio)

local notify = Remotes.get("Notify")

local TEXT_SIGNED_UP = "Tu es inscrit au classé ! Tu peux partir jouer : on te propose le match dès qu'un adversaire est trouvé."
local TEXT_CANCELLED = "Tu n'es plus inscrit au classé"
local TEXT_REFUSED = "Tu as refusé le match"
local TEXT_TIMEOUT = "Match non accepté à temps : tu es retiré de la file"
local TEXT_OPPONENT_DECLINED = "Ton adversaire n'a pas accepté : retour dans la file"
local TEXT_START_FAILED = "Le match n'a pas pu être créé : retour dans la file"
local TEXT_TELEPORT_FAILED = "La téléportation a échoué. Réinscris-toi dans le cercle de l'arène."
local TEXT_STUDIO_START = "Studio : les deux joueurs ont accepté ! Dans le jeu publié, la téléportation vers le match partirait maintenant."

local TICK = 0.25 -- boucle de suivi des places (chaque place a ses propres intervalles)
-- La barre du joueur finit 1 s avant l'heure limite du serveur : un clic de la dernière seconde compte encore.
local SAFETY_MARGIN = 1
-- Une invitation vit un peu plus longtemps que le temps pour accepter, puis MemoryStore l'efface.
local INVITE_TTL = MM.ACCEPT_SECONDS + MM.ACCEPT_GRACE + 30
-- Attributs de l'adversaire proposé (fenêtre « MATCH TROUVÉ ! » de LobbyUI).
local OFFER_ATTRIBUTES = { "MatchOpponent", "MatchOpponentMmr", "MatchOpponentGames", "MatchAcceptEndsAt" }

-- Heure commune à tous les serveurs (secondes UTC, au millième) : heures d'inscription et heures limites.
local function worldTime(): number
	return DateTime.now().UnixTimestampMillis / 1000
end

local function keyOf(userId: number): string
	return tostring(userId)
end

local function searchRange(waitSeconds: number): number
	return math.min(MM.MAX_RANGE, MM.BASE_RANGE + MM.RANGE_GROWTH_PER_SECOND * math.max(0, waitSeconds))
end

----------------------------------------------------------------------
-- Places et attributs
----------------------------------------------------------------------

local function newSeat(fields)
	fields.state = "Joining"
	fields.since = worldTime()
	fields.seen = {}
	fields.nextCheckAt = 0
	fields.refreshAt = 0
	return fields
end

-- Joueur encore là (un adversaire factice n'en a pas).
local function hasPlayer(seat): boolean
	return seat.player ~= nil and seat.player.Parent ~= nil
end

local function tell(seat, message: string, kind: string)
	if hasPlayer(seat) then
		notify:FireClient(seat.player, message, kind)
	end
end

local function setState(seat, state: string)
	seat.state = state
	seat.since = worldTime()
	if hasPlayer(seat) and seats[seat.userId] == seat then
		seat.player:SetAttribute("QueueState", state)
	end
end

-- Adversaire proposé : nom, MMR et matchs joués (le client en tire son rang ou « Placement x/5 » avec Ranks),
-- et fin de la barre en heure du serveur de jeu (workspace:GetServerTimeNow(), celle que le client connaît).
local function publishOffer(seat)
	if not hasPlayer(seat) then
		return
	end
	local proposal = seat.proposal
	local player = seat.player
	player:SetAttribute("MatchOpponent", proposal.opponent.name)
	player:SetAttribute("MatchOpponentMmr", proposal.opponent.mmr)
	player:SetAttribute("MatchOpponentGames", proposal.opponent.games)
	player:SetAttribute("MatchAcceptEndsAt", workspace:GetServerTimeNow() + (proposal.localDeadline - worldTime()))
end

local function clearOffer(seat)
	if hasPlayer(seat) and (seats[seat.userId] == seat or seats[seat.userId] == nil) then
		for _, name in OFFER_ATTRIBUTES do
			seat.player:SetAttribute(name, nil)
		end
	end
end

-- Libère la place : le joueur n'est plus inscrit (Idle).
local function removeSeat(seat)
	local current = seats[seat.userId]
	seat.state = "Idle"
	seat.proposal = nil
	if current ~= nil and current ~= seat then
		return -- déjà réinscrit : les attributs appartiennent à sa nouvelle place
	end
	seats[seat.userId] = nil
	if hasPlayer(seat) then
		for _, name in OFFER_ATTRIBUTES do
			seat.player:SetAttribute(name, nil)
		end
		seat.player:SetAttribute("QueueState", "Idle")
		seat.player:SetAttribute("QueueStartedAt", nil)
	end
end

local function dropSeat(seat, message: string?, kind: string?)
	removeSeat(seat)
	if message then
		tell(seat, message, kind or "Warning")
	end
end

-- La place attend toujours la suite de cette proposition.
local function stillOn(seat, proposalId: string): boolean
	return seats[seat.userId] == seat and seat.proposal ~= nil and seat.proposal.id == proposalId
end

local function isSearching(seat): boolean
	return seats[seat.userId] == seat and seat.state == "Searching"
end

----------------------------------------------------------------------
-- File d'attente
----------------------------------------------------------------------

local function entryOf(seat)
	return {
		userId = seat.userId,
		mmr = seat.mmr,
		games = seat.games,
		name = seat.name,
		joinedAt = seat.joinedAt,
		jobId = game.JobId,
	}
end

-- Écrit (ou réécrit) l'entrée de la place dans la file, avec son heure d'inscription. Si la place a changé
-- pendant l'écriture (annulée, partie), l'entrée est retirée : jamais de joueur fantôme dans la file.
local function writeEntry(seat): boolean
	local key = keyOf(seat.userId)
	local ok, err = pcall(function()
		backend.queue:SetAsync(key, entryOf(seat), MM.QUEUE_ENTRY_TTL, seat.mmr)
	end)
	if seats[seat.userId] ~= seat or (seat.state ~= "Searching" and seat.state ~= "Joining") then
		pcall(function()
			backend.queue:RemoveAsync(key)
		end)
		return false
	end
	if not ok then
		warn("[Matchmaking] Impossible d'écrire dans la file :", err)
		return false
	end
	seat.refreshAt = worldTime() + MM.QUEUE_REFRESH_INTERVAL
	return true
end

----------------------------------------------------------------------
-- Propositions (match trouvé, à accepter)
----------------------------------------------------------------------

-- Renvoie (lecture réussie, proposition ou nil si elle n'existe plus).
local function readProposal(id: string)
	local ok, record = pcall(function()
		return backend.proposals:GetAsync(id)
	end)
	if not ok then
		warn("[Matchmaking] Lecture d'un match proposé impossible :", record)
		return false, nil
	end
	if typeof(record) == "table" then
		record.accepted = record.accepted or {}
		record.out = record.out or {}
	end
	return true, record
end

-- Change une proposition avec UpdateAsync : change(proposition) renvoie vrai s'il l'a changée (sinon rien
-- n'est écrit). Renvoie la proposition changée, ou nil (pas changée, disparue ou erreur).
local function updateProposal(id: string, change)
	local ok, result = pcall(function()
		return backend.proposals:UpdateAsync(id, function(record)
			if typeof(record) ~= "table" then
				return nil
			end
			record.accepted = record.accepted or {}
			record.out = record.out or {}
			if not change(record) then
				return nil
			end
			return record
		end, MM.PROPOSAL_TTL)
	end)
	if not ok then
		warn("[Matchmaking] Écriture d'un match proposé impossible :", result)
		return nil
	end
	return result
end

-- Refus (ou départ) d'un joueur : la proposition est décidée tout de suite, l'autre retourne dans la file.
-- Un départ du jeu annule aussi un match accepté par les deux mais pas encore créé (« Starting ») : l'adversaire
-- retourne dans la file au lieu d'aller attendre seul sur le serveur de match.
local function refuseProposal(id: string, userId: number, reason: string)
	updateProposal(id, function(record)
		if record.status ~= "Waiting" and not (reason == "Left" and record.status == "Starting") then
			return false
		end
		record.status = "Refused"
		record.out[keyOf(userId)] = reason
		return true
	end)
end

-- Heure limite passée : chaque joueur qui n'a pas accepté est retiré de la file (« Timeout »).
local function expireProposal(id: string)
	updateProposal(id, function(record)
		if record.status ~= "Waiting" or worldTime() <= record.deadline then
			return false
		end
		record.status = "Expired"
		for _, userId in record.players do
			if not record.accepted[keyOf(userId)] then
				record.out[keyOf(userId)] = "Timeout"
			end
		end
		return true
	end)
end

-- Les deux ont accepté, mais le serveur qui crée le match ne l'a pas fait à temps (arrêté ?) : raté.
local function failStart(id: string)
	updateProposal(id, function(record)
		if record.status ~= "Starting" or worldTime() <= (record.startingAt or 0) + MM.START_TIMEOUT then
			return false
		end
		record.status = "Failed"
		return true
	end)
end

-- Retour dans la file après un match proposé qui ne s'est pas fait : même heure d'inscription (attente gardée,
-- et le chrono de LobbyUI continue : QueueStartedAt ne change pas).
local function backToQueue(seat, message: string)
	if seat.proposal then
		seat.seen[seat.proposal.id] = true
	end
	seat.proposal = nil
	clearOffer(seat)
	setState(seat, "Searching")
	tell(seat, message, "Warning")
	writeEntry(seat)
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

local function teleportFailed(seat)
	if seats[seat.userId] ~= seat or seat.state ~= "Teleporting" then
		return
	end
	if seat.player then
		setMatchDeparture(seat.player, 0)
	end
	dropSeat(seat, TEXT_TELEPORT_FAILED, "Error")
end

-- Match créé : chaque serveur téléporte SES joueurs, une seule fois (état Teleporting avant tout appel).
local function teleportSeat(seat, record)
	if seat.state == "Teleporting" then
		return
	end
	seat.seen[record.id] = true
	clearOffer(seat)
	setState(seat, "Teleporting")
	local player = seat.player
	if not player then
		removeSeat(seat) -- adversaire factice (tests Studio) : personne à téléporter
		return
	end
	if backend.kind == "Studio" then
		-- Studio : pas de téléportation possible. On note seulement où il serait parti.
		backend.teleport(player, record.accessCode)
		dropSeat(seat, TEXT_STUDIO_START, "Success")
		return
	end
	tell(seat, "Match accepté ! Téléportation vers le match…", "Success")
	setMatchDeparture(player, os.time())
	for attempt = 1, 3 do
		local ok, err = pcall(backend.teleport, player, record.accessCode)
		if ok then
			return -- en route (si ça rate plus tard : TeleportInitFailed, ou TELEPORT_TIMEOUT)
		end
		warn(`[Matchmaking] Téléportation échouée (essai {attempt}) :`, err)
		task.wait(attempt)
		if not player.Parent or seats[seat.userId] ~= seat then
			return
		end
	end
	teleportFailed(seat)
end

-- Suite d'une place selon sa proposition (record = nil : elle n'existe plus dans MemoryStore).
local function applyDecision(seat, record)
	local now = worldTime()
	if record == nil then
		-- Disparue (expirée, serveur arrêté...) : on décide avec ce que la place sait, après ses propres limites.
		if seat.state == "Found" then
			if now > seat.since + MM.START_TIMEOUT then
				backToQueue(seat, TEXT_START_FAILED)
			end
		elseif now > seat.proposal.deadline then
			if seat.state == "Accepted" then
				backToQueue(seat, TEXT_OPPONENT_DECLINED)
			else
				dropSeat(seat, TEXT_TIMEOUT)
			end
		end
		return
	end
	local status = record.status
	if status == "Waiting" then
		if seat.state == "Pending" and record.accepted[keyOf(seat.userId)] then
			setState(seat, "Accepted") -- réponse écrite, mais sa confirmation s'était perdue
		end
	elseif status == "Refused" or status == "Expired" then
		local reason = record.out[keyOf(seat.userId)]
		if reason == nil then
			backToQueue(seat, TEXT_OPPONENT_DECLINED)
		elseif reason == "Timeout" then
			dropSeat(seat, TEXT_TIMEOUT)
		else
			dropSeat(seat, TEXT_REFUSED)
		end
	elseif status == "Starting" then
		if seat.state ~= "Found" then
			setState(seat, "Found")
		end
	elseif status == "Started" then
		teleportSeat(seat, record)
	elseif status == "Failed" then
		backToQueue(seat, TEXT_START_FAILED)
	end
end

-- Relit la proposition de la place et applique la décision. Heure limite passée ou création trop longue :
-- n'importe lequel des deux serveurs la décide (UpdateAsync : le premier gagne, l'autre lit sa décision).
local function checkProposal(seat)
	local proposal = seat.proposal
	if not proposal then
		return
	end
	local id = proposal.id
	local ok, record = readProposal(id)
	if not stillOn(seat, id) then
		return
	end
	if not ok then
		-- MemoryStore injoignable : on réessaie au prochain passage, mais pas indéfiniment. Passé l'heure limite et
		-- le temps de création du match, la place décide seule, comme pour une proposition disparue.
		if worldTime() > proposal.deadline + MM.START_TIMEOUT then
			applyDecision(seat, nil)
		end
		return
	end
	if record and record.status == "Waiting" and worldTime() > record.deadline then
		expireProposal(id)
		ok, record = readProposal(id)
	elseif record and record.status == "Starting" and worldTime() > (record.startingAt or 0) + MM.START_TIMEOUT then
		failStart(id)
		ok, record = readProposal(id)
	end
	if ok and stillOn(seat, id) then
		applyDecision(seat, record)
	end
end

-- Les deux ont accepté : CE serveur (celui du 2e qui a accepté) crée le match comme avant : serveur réservé,
-- infos du match (lues par le serveur de match, Match/init.luau), puis « Started » avec le code d'accès.
local function startMatch(id: string, record)
	local a = record.entries and record.entries[keyOf(record.players[1])]
	local b = record.entries and record.entries[keyOf(record.players[2])]
	local started, accessCode, privateServerId = false, nil, nil
	local matchId = HttpService:GenerateGUID(false)
	if typeof(a) == "table" and typeof(b) == "table" then
		local okReserve, code, serverId = pcall(backend.reserveServer)
		if okReserve then
			accessCode, privateServerId = code, serverId
			local okInfo, errInfo = pcall(function()
				backend.matches:SetAsync(privateServerId, {
					matchId = matchId,
					players = { a.userId, b.userId },
					mmr = { [keyOf(a.userId)] = a.mmr, [keyOf(b.userId)] = b.mmr },
					createdAt = os.time(),
				}, MM.MATCH_INFO_TTL)
			end)
			started = okInfo
			if not okInfo then
				warn("[Matchmaking] Impossible d'enregistrer le match :", errInfo)
			end
		else
			warn("[Matchmaking] ReserveServer a échoué :", code)
		end
	end
	updateProposal(id, function(current)
		if current.status ~= "Starting" or current.starter ~= game.JobId then
			return false
		end
		if started then
			current.status = "Started"
			current.accessCode = accessCode
			current.matchId = matchId
		else
			current.status = "Failed"
		end
		return true
	end)
	if started then
		lastStart = {
			matchId = matchId,
			proposalId = id,
			players = { a.userId, b.userId },
			accessCode = accessCode,
			privateServerId = privateServerId,
		}
		print(`[Matchmaking] Match {matchId} : {a.userId} ({a.mmr}) vs {b.userId} ({b.mmr})`)
	end
	-- Les joueurs de ce serveur : la suite tout de suite, sans attendre le prochain passage du suivi.
	for _, userId in record.players do
		local seat = seats[userId]
		if seat and stillOn(seat, id) then
			checkProposal(seat)
		end
	end
end

-- ACCEPTER : réponse écrite dans la proposition. Le 2e qui accepte la fait passer à « Starting » (une seule
-- écriture peut le faire) et c'est SON serveur qui crée le match.
local function acceptSeat(seat)
	local proposal = seat.proposal
	if seat.state ~= "Pending" or not proposal or seat.answering then
		return
	end
	seat.answering = true
	local id = proposal.id
	local key = keyOf(seat.userId)
	local starting = false
	local ok, record = pcall(function()
		return backend.proposals:UpdateAsync(id, function(current)
			starting = false -- (UpdateAsync peut relancer cette fonction : on repart de zéro à chaque fois)
			if typeof(current) ~= "table" or current.status ~= "Waiting" or worldTime() > current.deadline then
				return nil -- déjà décidée, ou trop tard : le suivi de la place lit la décision
			end
			current.accepted = current.accepted or {}
			current.out = current.out or {}
			current.accepted[key] = true
			local everyone = true
			for _, userId in current.players do
				everyone = everyone and current.accepted[keyOf(userId)] == true
			end
			if everyone then
				current.status = "Starting"
				current.starter = game.JobId
				current.startingAt = worldTime()
				starting = true
			end
			return current
		end, MM.PROPOSAL_TTL)
	end)
	seat.answering = false
	if not ok then
		warn("[Matchmaking] Réponse non écrite :", record)
		if stillOn(seat, id) then
			tell(seat, "Ta réponse n'est pas partie, réessaie", "Error")
		end
		return
	end
	if starting and not stillOn(seat, id) then
		-- Parti pendant l'écriture : pas de match, l'adversaire retourne tout de suite dans la file.
		updateProposal(id, function(current)
			if current.status ~= "Starting" or current.starter ~= game.JobId then
				return false
			end
			current.status = "Failed"
			return true
		end)
		return
	end
	if not stillOn(seat, id) then
		return
	end
	if record == nil then
		checkProposal(seat) -- déjà décidée (refus, temps écoulé...) : on applique la décision
	elseif starting then
		setState(seat, "Found")
		startMatch(id, record)
	elseif seat.state == "Pending" then
		setState(seat, "Accepted")
	end
end

-- ANNULER ("Cancel"), REFUSER ("Refused") ou départ du jeu ("Left").
local function leaveSeat(seat, reason: string)
	local state = seat.state
	if reason ~= "Left" and state ~= "Joining" and state ~= "Searching" and state ~= "Pending" then
		return -- après ACCEPTER, on attend l'adversaire : plus d'annulation (sauf en quittant le jeu)
	end
	if state == "Teleporting" then
		-- En route vers le match (ou déjà parti) : on l'oublie. Le serveur de match annule sans perte de MMR si un
		-- joueur n'arrive pas (Match/init.luau).
		removeSeat(seat)
		return
	end
	local proposal = seat.proposal
	removeSeat(seat)
	if proposal then
		-- Match proposé : c'est un refus ; l'adversaire retourne tout de suite dans la file.
		seat.seen[proposal.id] = true
		if reason ~= "Left" then
			tell(seat, TEXT_REFUSED, "Warning")
		end
		refuseProposal(proposal.id, seat.userId, if reason == "Left" then "Left" else "Refused")
		return
	end
	if reason == "Cancel" then
		tell(seat, TEXT_CANCELLED, "Info")
	end
	local key = keyOf(seat.userId)
	pcall(function()
		backend.queue:RemoveAsync(key)
	end)
	-- Une paire venait peut-être d'être formée avec lui (invitation pas encore lue) : on la refuse tout de suite,
	-- l'adversaire retourne dans la file sans attendre la fin du temps pour accepter.
	local ok, invite = pcall(function()
		return backend.invites:GetAsync(key)
	end)
	if ok and typeof(invite) == "table" and typeof(invite.proposalId) == "string" and not seat.seen[invite.proposalId] then
		refuseProposal(invite.proposalId, seat.userId, "Left")
		pcall(function()
			backend.invites:RemoveAsync(key)
		end)
	end
end

----------------------------------------------------------------------
-- Suivi des places de ce serveur
----------------------------------------------------------------------

-- Invitation trouvée : match proposé à ce joueur (fenêtre « MATCH TROUVÉ ! »).
local function offer(seat, invite)
	seat.seen[invite.proposalId] = true
	local now = worldTime()
	local opponent = if typeof(invite.opponent) == "table" then invite.opponent else {}
	seat.proposal = {
		id = invite.proposalId,
		deadline = invite.deadline,
		-- Barre du joueur : ACCEPT_SECONDS au plus, finie SAFETY_MARGIN avant l'heure limite du serveur.
		localDeadline = now + math.clamp(invite.deadline - now - SAFETY_MARGIN, 0, MM.ACCEPT_SECONDS),
		opponent = {
			userId = opponent.userId,
			name = if typeof(opponent.name) == "string" then string.sub(opponent.name, 1, 40) else "?",
			mmr = if typeof(opponent.mmr) == "number" then opponent.mmr else Config.Ranked.START_MMR,
			games = if typeof(opponent.games) == "number" then opponent.games else 0,
		},
	}
	publishOffer(seat)
	setState(seat, "Pending")
	local key = keyOf(seat.userId)
	pcall(function()
		backend.invites:RemoveAsync(key)
	end)
	pcall(function()
		backend.queue:RemoveAsync(key) -- déjà retirée par le leader, par sécurité (jamais deux paires)
	end)
end

-- Place inscrite : un match lui est-il proposé ? Renvoie vrai si oui.
local function checkInvite(seat): boolean
	local key = keyOf(seat.userId)
	local ok, invite = pcall(function()
		return backend.invites:GetAsync(key)
	end)
	if not ok or typeof(invite) ~= "table" or not isSearching(seat) then
		return false
	end
	if
		typeof(invite.proposalId) ~= "string"
		or seat.seen[invite.proposalId]
		or typeof(invite.deadline) ~= "number"
		or invite.deadline < worldTime()
	then
		pcall(function()
			backend.invites:RemoveAsync(key) -- vieille invitation (déjà traitée ou trop tard)
		end)
		return false
	end
	offer(seat, invite)
	return true
end

-- Garde l'entrée de la file en vie. UpdateAsync ne recrée PAS une entrée retirée par le leader (sinon un
-- joueur déjà en paire pourrait être mis en paire une 2e fois).
local function refreshEntry(seat)
	local found = false
	local ok = pcall(function()
		backend.queue:UpdateAsync(keyOf(seat.userId), function(value, sortKey)
			found = value ~= nil
			if value == nil then
				return nil
			end
			return value, sortKey
		end, MM.QUEUE_ENTRY_TTL)
	end)
	if not ok or not isSearching(seat) then
		return
	end
	if found then
		seat.refreshAt = worldTime() + MM.QUEUE_REFRESH_INTERVAL
		return
	end
	-- Entrée disparue : soit une paire vient d'être formée (l'invitation existe déjà : le leader l'écrit AVANT de
	-- retirer l'entrée), soit elle a expiré -> on la remet, avec la même heure d'inscription.
	if not checkInvite(seat) and isSearching(seat) then
		writeEntry(seat)
	end
end

-- Un passage pour une place (force = tests Studio : sans attendre son prochain passage).
local function checkSeat(seat, force: boolean?)
	local now = worldTime()
	if not force and now < seat.nextCheckAt then
		return
	end
	local state = seat.state
	if state == "Searching" then
		seat.nextCheckAt = now + MM.INVITE_POLL_INTERVAL
		if not checkInvite(seat) and isSearching(seat) and worldTime() >= seat.refreshAt then
			refreshEntry(seat)
		end
	elseif state == "Pending" or state == "Accepted" or state == "Found" then
		seat.nextCheckAt = now + MM.PROPOSAL_POLL_INTERVAL
		checkProposal(seat)
	elseif state == "Teleporting" then
		seat.nextCheckAt = now + 1
		if now > seat.since + MM.TELEPORT_TIMEOUT then
			teleportFailed(seat)
		end
	end
end

----------------------------------------------------------------------
-- Côté leader (un seul serveur à la fois forme les paires)
----------------------------------------------------------------------

local function tryBecomeLeader(): boolean
	local ok, result = pcall(function()
		return backend.leader:UpdateAsync("leader", function(current)
			if current == nil or current == game.JobId then
				return game.JobId
			end
			return nil
		end, MM.LEADER_TTL)
	end)
	return ok and result == game.JobId
end

local function validEntry(entry): boolean
	return typeof(entry) == "table"
		and typeof(entry.userId) == "number"
		and typeof(entry.mmr) == "number"
		and typeof(entry.joinedAt) == "number"
end

-- Toute la file, triée par MMR (nil si la lecture échoue).
local function readQueue()
	local entries = {}
	local lowerBound = nil
	for _ = 1, 5 do -- jusqu'à 1000 joueurs en file
		local ok, items = pcall(function()
			return backend.queue:GetRangeAsync(Enum.SortDirection.Ascending, 200, lowerBound)
		end)
		if not ok then
			warn("[Matchmaking] Lecture de la file impossible :", items)
			return nil
		end
		for _, item in items do
			if validEntry(item.value) then
				table.insert(entries, item.value)
			end
		end
		if #items < 200 then
			break
		end
		local last = items[#items]
		lowerBound = { key = last.key, sortKey = last.sortKey }
	end
	return entries
end

-- Une paire : proposition, puis invitations, puis retrait de la file (dans cet ordre : un serveur qui ne trouve
-- plus l'entrée de son joueur trouve toujours son invitation).
local function propose(a, b): boolean
	local id = HttpService:GenerateGUID(false)
	local now = worldTime()
	local record = {
		id = id,
		players = { a.userId, b.userId },
		entries = { [keyOf(a.userId)] = a, [keyOf(b.userId)] = b },
		accepted = {},
		out = {},
		status = "Waiting",
		createdAt = now,
		deadline = now + MM.ACCEPT_SECONDS + MM.ACCEPT_GRACE,
	}
	local ok, err = pcall(function()
		backend.proposals:SetAsync(id, record, MM.PROPOSAL_TTL)
	end)
	if not ok then
		warn("[Matchmaking] Impossible de proposer un match :", err)
		return false
	end
	for _, pair in { { a, b }, { b, a } } do
		local player, opponent = pair[1], pair[2]
		local okInvite, errInvite = pcall(function()
			backend.invites:SetAsync(keyOf(player.userId), {
				proposalId = id,
				deadline = record.deadline,
				opponent = { userId = opponent.userId, name = opponent.name, mmr = opponent.mmr, games = opponent.games },
			}, INVITE_TTL)
		end)
		if not okInvite then
			-- Proposition annulée ; les deux sont encore dans la file (celui qui a déjà son invitation y revient).
			warn("[Matchmaking] Invitation impossible :", errInvite)
			updateProposal(id, function(current)
				if current.status ~= "Waiting" then
					return false
				end
				current.status = "Failed"
				return true
			end)
			return false
		end
	end
	for _, entry in { a, b } do
		pcall(function()
			backend.queue:RemoveAsync(keyOf(entry.userId))
		end)
	end
	print(`[Matchmaking] Match proposé {id} : {a.userId} ({a.mmr}) vs {b.userId} ({b.mmr})`)
	return true
end

-- Paires : ceux qui attendent depuis le plus longtemps choisissent d'abord (priorité, par exemple à celui qui
-- revient dans la file parce que son adversaire n'a pas accepté), chacun avec le joueur libre de MMR le plus
-- proche, si l'écart tient dans la fourchette du plus patient des deux.
local function runMatcher()
	local entries = readQueue() -- triées par MMR
	if not entries or #entries < 2 then
		return
	end
	local position = {}
	for i, entry in entries do
		position[entry.userId] = i
	end
	local oldestFirst = table.clone(entries)
	table.sort(oldestFirst, function(x, y)
		if x.joinedAt ~= y.joinedAt then
			return x.joinedAt < y.joinedAt
		end
		return x.userId < y.userId
	end)
	local now = worldTime()
	local taken = {}
	for _, a in oldestFirst do
		if taken[a.userId] then
			continue
		end
		local best, bestGap = nil, math.huge
		for _, step in { -1, 1 } do
			-- Voisins de MMR de chaque côté, jusqu'à l'écart maximal.
			local j = position[a.userId] + step
			while entries[j] and math.abs(entries[j].mmr - a.mmr) <= MM.MAX_RANGE do
				local b = entries[j]
				local gap = math.abs(b.mmr - a.mmr)
				local range = math.max(searchRange(now - a.joinedAt), searchRange(now - b.joinedAt))
				if not taken[b.userId] and b.userId ~= a.userId and gap < bestGap and gap <= range then
					best, bestGap = b, gap
				end
				j += step
			end
		end
		if best then
			taken[a.userId], taken[best.userId] = true, true
			propose(a, best)
		end
	end
end

----------------------------------------------------------------------
-- Côté joueur (remote QueueAction, reçu par Hub/init.luau)
----------------------------------------------------------------------

function Matchmaking.isQueued(player: Player): boolean
	return seats[player.UserId] ~= nil
end

-- Inscription (bouton « S'INSCRIRE » : Hub/init.luau a déjà vérifié que le joueur est dans le cercle).
-- Renvoie (réussi, raison).
function Matchmaking.join(player: Player): (boolean, string)
	local userId = player.UserId
	if seats[userId] then
		notify:FireClient(player, "Tu es déjà inscrit au classé", "Info")
		return false, "déjà inscrit"
	end
	if not backend then
		notify:FireClient(player, "Le matchmaking est indisponible pour le moment.", "Error")
		return false, "indisponible"
	end
	local clock = os.clock()
	if lastSignUp[userId] and clock - lastSignUp[userId] < MM.SIGNUP_COOLDOWN then
		notify:FireClient(player, "Attends un instant avant de te réinscrire", "Warning")
		return false, "trop vite"
	end
	local data = PlayerData.get(player)
	if not data then
		notify:FireClient(player, "Tes données sont encore en cours de chargement.", "Warning")
		return false, "données pas chargées"
	end
	lastSignUp[userId] = clock

	local seat = newSeat({
		userId = userId,
		player = player,
		name = player.DisplayName,
		mmr = data.mmr,
		games = data.gamesPlayed,
		joinedAt = worldTime(),
	})
	seats[userId] = seat
	player:SetAttribute("QueueStartedAt", workspace:GetServerTimeNow())
	setState(seat, "Joining")
	-- Une vieille invitation (serveur arrêté pendant un match proposé...) ne sert pas à cette inscription.
	pcall(function()
		backend.invites:RemoveAsync(keyOf(userId))
	end)
	local written = seats[userId] == seat and writeEntry(seat)
	if seats[userId] ~= seat then
		return false, "annulé" -- ANNULER ou départ pendant l'écriture (writeEntry a retiré l'entrée)
	end
	if not written then
		removeSeat(seat)
		notify:FireClient(player, "Le matchmaking est indisponible, réessaie.", "Error")
		return false, "erreur"
	end
	setState(seat, "Searching")
	notify:FireClient(player, TEXT_SIGNED_UP, "Success")
	if backend.kind == "Studio" then
		print(`[Matchmaking] Studio : {player.Name} inscrit (file en mémoire, un seul serveur). Adversaire factice :`
			.. ` game.ServerStorage.StudioDebug:Invoke(game.Players:GetPlayers()[1], "Ranked", "FakeOpponent")`)
	end
	return true, "inscrit"
end

-- ANNULER (reason "Cancel", par défaut) ou départ du jeu ("Left"). Pendant un match proposé, c'est un refus.
function Matchmaking.leave(player: Player, reason: string?)
	local seat = seats[player.UserId]
	if seat then
		leaveSeat(seat, reason or "Cancel")
	end
end

-- Fenêtre « MATCH TROUVÉ ! » : ACCEPTER (true) ou REFUSER (false, seulement avant d'avoir accepté).
function Matchmaking.answer(player: Player, accept: boolean)
	local seat = seats[player.UserId]
	if not seat then
		return
	end
	if accept then
		acceptSeat(seat)
	elseif seat.state == "Pending" then
		leaveSeat(seat, "Refused")
	end
end

----------------------------------------------------------------------
-- Tests Studio (ServerStorage.StudioDebug, commande « Ranked » : liste dans Hub/init.luau). Rien de tout ça
-- ne marche dans le jeu publié.
----------------------------------------------------------------------

-- Un passage de suivi pour toutes les places, tout de suite (sans attendre les intervalles).
local function tickAll()
	local list = {}
	for _, seat in seats do
		table.insert(list, seat)
	end
	for _, seat in list do
		if seats[seat.userId] == seat then
			checkSeat(seat, true)
		end
	end
end

-- L'adversaire factice du match proposé au joueur.
local function fakeOpponentOf(seat)
	local opponentId = seat and seat.proposal and seat.proposal.opponent.userId
	local fake = opponentId and seats[opponentId]
	if fake and fake.player == nil then
		return fake
	end
	return nil
end

function Matchmaking.debug(player: Player, command: string, ...)
	if not RunService:IsStudio() or not backend then
		return nil
	end
	local seat = seats[player.UserId]
	if command == "State" then
		-- (Clés en texte partout : un tableau à trous ne passerait pas entier par la BindableFunction.)
		local queue = {}
		for _, entry in readQueue() or {} do
			queue[keyOf(entry.userId)] = { joinedAt = entry.joinedAt, mmr = entry.mmr }
		end
		local record = nil
		if seat and seat.proposal then
			local _, current = readProposal(seat.proposal.id)
			record = current
		end
		local opponents = {}
		for userId, other in seats do
			if other.player == nil then
				opponents[keyOf(userId)] = { state = other.state, joinedAt = other.joinedAt, proposalId = other.proposal and other.proposal.id }
			end
		end
		local teleports = {}
		for userId, code in backend.teleports or {} do
			teleports[keyOf(userId)] = code
		end
		return {
			state = if seat then seat.state else "Idle",
			joinedAt = seat and seat.joinedAt,
			proposalId = seat and seat.proposal and seat.proposal.id,
			localDeadline = seat and seat.proposal and seat.proposal.localDeadline,
			proposal = record,
			queue = queue,
			opponents = opponents,
			lastStart = lastStart,
			teleports = teleports,
			now = worldTime(),
		}
	elseif command == "FakeOpponent" then
		-- Un adversaire factice s'inscrit (depuis `wait` secondes), puis le leader forme les paires tout de suite
		-- (sauf pair = false : il attend seulement dans la file).
		local options = ... or {}
		fakeCount += 1
		local fake = newSeat({
			userId = -(1000 + fakeCount),
			player = nil,
			name = options.name or `Adversaire factice {fakeCount}`,
			mmr = options.mmr or (seat and seat.mmr) or Config.Ranked.START_MMR,
			games = options.games or 12,
			joinedAt = worldTime() - (options.wait or 0),
		})
		seats[fake.userId] = fake
		setState(fake, "Searching")
		writeEntry(fake)
		if options.pair ~= false and tryBecomeLeader() then
			runMatcher()
		end
		tickAll()
		local current = seats[player.UserId]
		return current and current.proposal and current.proposal.id, fake.userId
	elseif command == "OpponentAccept" or command == "OpponentRefuse" or command == "OpponentLeave" then
		local fake = fakeOpponentOf(seat)
		if not fake then
			return false
		end
		if command == "OpponentAccept" then
			acceptSeat(fake)
		else
			leaveSeat(fake, if command == "OpponentLeave" then "Left" else "Refused")
		end
		tickAll()
		return true
	elseif command == "Accept" or command == "Refuse" then
		Matchmaking.answer(player, command == "Accept")
		tickAll()
		return true
	elseif command == "Leave" then
		Matchmaking.leave(player, "Cancel")
		tickAll()
		return true
	elseif command == "Expire" then
		-- Heure limite de la proposition du joueur mise dans le passé : comme au bout de ACCEPT_SECONDS
		-- (waitLoop = true : sans passage forcé, la boucle normale du serveur doit s'en occuper toute seule).
		local waitLoop = ...
		local id = seat and seat.proposal and seat.proposal.id
		if not id then
			return false
		end
		local past = worldTime() - 1
		updateProposal(id, function(record)
			record.deadline = past
			return true
		end)
		for _, other in seats do
			if other.proposal and other.proposal.id == id then
				other.proposal.deadline = past
				other.proposal.localDeadline = past
			end
		end
		if not waitLoop then
			tickAll()
		end
		return true
	elseif command == "StuckStart" then
		-- Les deux ont accepté, mais le serveur qui crée le match a disparu depuis `age` secondes.
		local age = ... or 0
		local id = seat and seat.proposal and seat.proposal.id
		if not id then
			return false
		end
		updateProposal(id, function(record)
			if record.status ~= "Waiting" and record.status ~= "Starting" then
				return false
			end
			for _, userId in record.players do
				record.accepted[keyOf(userId)] = true
			end
			record.status = "Starting"
			record.starter = "serveur-disparu"
			record.startingAt = worldTime() - age
			return true
		end)
		tickAll()
		return true
	elseif command == "BreakReserve" then
		backend.failReserve = (...) == true
		return backend.failReserve
	elseif command == "Tick" then
		if tryBecomeLeader() then
			runMatcher()
		end
		tickAll()
		return true
	elseif command == "Reset" then
		-- Tout vidé : file, propositions, adversaires factices, anti-spam ; le joueur n'est plus inscrit.
		local list = {}
		for _, other in seats do
			table.insert(list, other)
		end
		for _, other in list do
			removeSeat(other)
		end
		if backend.clear then
			backend.clear()
		end
		backend.failReserve = false
		table.clear(lastSignUp)
		lastStart = nil
		return true
	end
	return nil
end

----------------------------------------------------------------------

function Matchmaking.start()
	Players.PlayerRemoving:Connect(function(player)
		Matchmaking.leave(player, "Left")
		lastSignUp[player.UserId] = nil
	end)

	local ok, result = pcall(Backend.create)
	if not ok then
		warn("[Matchmaking] MemoryStoreService indisponible :", result)
		return
	end
	backend = result

	-- Suivi des places de ce serveur : invitations, réponses, création du match, téléportation, limites de temps.
	task.spawn(function()
		while true do
			task.wait(TICK)
			local list = {}
			for _, seat in seats do
				table.insert(list, seat)
			end
			local now = worldTime()
			for _, seat in list do
				if not seat.busy and now >= seat.nextCheckAt and seats[seat.userId] == seat then
					seat.busy = true
					task.spawn(function()
						local okCheck, err = pcall(checkSeat, seat)
						seat.busy = false
						if not okCheck then
							warn("[Matchmaking] Suivi d'une place impossible :", err)
						end
					end)
				end
			end
		end
	end)

	-- Boucle du leader.
	task.spawn(function()
		while true do
			task.wait(MM.MATCHER_INTERVAL)
			if tryBecomeLeader() then
				local okMatcher, err = pcall(runMatcher)
				if not okMatcher then
					warn("[Matchmaking] Appariement impossible :", err)
				end
			end
		end
	end)

	TeleportService.TeleportInitFailed:Connect(function(player, _result, message)
		local seat = seats[player.UserId]
		if seat and seat.state == "Teleporting" then
			warn("[Matchmaking] TeleportInitFailed :", message)
			teleportFailed(seat)
		end
	end)
end

return Matchmaking

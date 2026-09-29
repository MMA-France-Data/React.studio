-- Où le matchmaking range ce qu'il partage (file d'attente, matchs proposés, infos des matchs, leader) et
-- comment il envoie les joueurs au match. Deux versions avec les mêmes fonctions, Matchmaking.luau ne sait
-- pas laquelle il utilise :
--   jeu publié : MemoryStoreService (partagé par TOUS les serveurs lobby) + TeleportService (serveur réservé) ;
--   Studio     : tout en mémoire (MockMemoryStore, un seul serveur, adversaires factices des tests) et JAMAIS
--                de téléportation : le départ vers le match est seulement noté (teleports) et annoncé au joueur.
local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local MockMemoryStore = require(script.Parent.MockMemoryStore)

local Backend = {}

-- Jeu publié. Noms en « _v2 » depuis le match à accepter (29/09/2026) : un vieux serveur encore ouvert pendant
-- une mise à jour garde sa file à lui et ne mélange pas ses joueurs avec ceux des nouveaux serveurs.
-- « RankedTD_Matches » ne change pas : le serveur de match y lit ses infos (Match/init.luau).
function Backend.real()
	local backend = {
		kind = "MemoryStore",
		queue = MemoryStoreService:GetSortedMap("RankedTD_Queue_v2_S" .. Config.SEASON), -- triée par MMR
		invites = MemoryStoreService:GetHashMap("RankedTD_Invites_v2"), -- [UserId] = match proposé à ce joueur
		proposals = MemoryStoreService:GetHashMap("RankedTD_Proposals_v2"), -- [id] = match proposé, réponses
		matches = MemoryStoreService:GetHashMap("RankedTD_Matches"), -- [PrivateServerId] = infos du match
		leader = MemoryStoreService:GetHashMap("RankedTD_Leader_v2"),
	}

	-- Serveur réservé pour le match : renvoie (code d'accès, PrivateServerId).
	function backend.reserveServer(): (string, string)
		return TeleportService:ReserveServer(game.PlaceId)
	end

	function backend.teleport(player: Player, accessCode: string)
		local options = Instance.new("TeleportOptions")
		options.ReservedServerAccessCode = accessCode
		TeleportService:TeleportAsync(game.PlaceId, { player }, options)
	end

	return backend
end

-- Studio : un seul serveur, tout en mémoire.
function Backend.memory()
	local backend = {
		kind = "Studio",
		teleports = {}, -- [UserId] = code d'accès du match où il serait parti (tests)
		failReserve = false, -- tests : la réservation du serveur de match échoue
	}

	-- Maps neuves (aussi pour tout vider entre deux tests Studio).
	function backend.clear()
		backend.queue = MockMemoryStore.sortedMap()
		backend.invites = MockMemoryStore.hashMap()
		backend.proposals = MockMemoryStore.hashMap()
		backend.matches = MockMemoryStore.hashMap()
		backend.leader = MockMemoryStore.hashMap()
		table.clear(backend.teleports)
	end
	backend.clear()

	function backend.reserveServer(): (string, string)
		if backend.failReserve then
			error("réservation du serveur de match ratée (test Studio)")
		end
		local id = HttpService:GenerateGUID(false)
		return "studio-code-" .. id, "studio-serveur-" .. id
	end

	-- Pas de téléportation dans Studio : on note seulement où le joueur serait parti.
	function backend.teleport(player: Player, accessCode: string)
		backend.teleports[player.UserId] = accessCode
	end

	return backend
end

-- Studio : en mémoire ; jeu publié : MemoryStore (peut échouer : l'appelant le protège avec pcall).
function Backend.create()
	if RunService:IsStudio() then
		return Backend.memory()
	end
	return Backend.real()
end

return Backend

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

local DEFINITIONS = {
	-- serveur -> clients : (numéro, buffer, count) positions des monstres d'une zone (format : Hub/Combat.luau,
	-- buildSyncPacket). numéro = celui de la parcelle pour un camp d'entraînement (envoyé à son propriétaire et aux
	-- joueurs proches, Hub/PlotInterest.luau), ou celui de la zone de combat pour un niveau (Levels.arenaIndex,
	-- envoyé au joueur du niveau seulement).
	-- (numéro, buffer vide, 0, "Clear") : ce client ne reçoit plus cette zone, il l'efface tout de suite.
	-- La vitesse de chaque monstre dans le paquet ne compte PAS le x2 : le client la multiplie par l'attribut
	-- « SimSpeed » du dossier de la zone (1 ou 2).
	-- Après les count x 11 octets des monstres : count octets « contrôle », un par monstre dans le même ordre :
	-- bits 0-6 = numéro dans IdleTowers.ORDER de la famille de la tour (sa tour de palier 1) dont le contrôle est en cours (0 = aucun ; Frost =
	-- ralenti par un Totem de givre, Tesla = ralenti par un Mage des tempêtes, Orbital = étourdi par le
	-- Trébuchet royal), bit 7 (128) = fragile (aura d'un Totem du blizzard). Voir le haut de Combat.luau.
	PlotSync = "RemoteEvent",
	-- serveur -> clients : (numéro, buffer, count) tirs, count x 27 octets, puis count x 4 octets : l'id u32 de
	-- la cible que suit chaque projectile (0 = aucune ; format : Combat.luau, takeShotsPacket).
	-- Baliste du dragon (type DragonBallista) : carreau perçant du départ au point d'arrivée, rayon 0 ; Trébuchet royal
	-- (type Orbital) : rayon = sa grande zone.
	PlotShots = "UnreliableRemoteEvent",
	-- NIVEAUX (règles : Shared/Levels.luau), client -> serveur :
	--   ("Start", niveau) | "Quit" (retour au camp ; pendant un niveau : abandon)
	--   | ("Place", type de tour, x, z) : pose libre, point de la zone de combat en coordonnées locales
	--   | ("Upgrade", id de la tour) | ("Sell", id) | ("Speed", 1 ou 2)
	--   | ("SlotAssign", emplacement du camp, type de tour ou "") | ("SlotUpgrade", emplacement) | "SlotUnlock"
	--   | ("TrainBuy", type de tour) : entraînement acheté avec des pièces (bouton ⚡ de l'onglet Entraînement)
	--   | ("Bar", { types de tours }) : ordre de la barre rapide
	--   | ("EggStart", couveuse, type d'œuf) | ("EggOpen", couveuse) | ("EggSkip", couveuse) | "HatcherBuy" : les œufs
	--     (toutes les tours en sortent ; plus de boutique de tours ; couveuse 3 = la couveuse royale)
	--   | ("EggSkipRobux", couveuse) | ("PassBuy", "Royal" | "Xp" | "Coins") : achats en Robux, la fenêtre d'achat de
	--     Roblox s'ouvre (Hub/Shop.luau)
	--   | ("Tutorial", "Skip") : bouton « Passer le tuto »
	--   | ("TeamInvite", UserId) | ("TeamAnswer", UserId de celui qui invite, vrai = accepter) | "TeamLeave" : jouer en
	--     équipe (Hub/LevelTeams.luau ; en équipe, « Start » ne vient que du chef et lance le niveau pour tous).
	-- Le serveur vérifie tout (Hub/LevelsService.luau). État publié en attributs :
	--   du joueur : LevelsState (JSON : best, coins, towers = ses tours dans l'ordre de sa barre rapide, xp, slots,
	--     wins, losses, tutorial = étape du tuto, eggs, hatchers, royal = la couveuse royale, shop = { passes = { [clé] =
	--     "owned" | "buy" | "soon" | "no" }, prices = prix de « Finir l'œuf » } ; absent tant que ses données ne sont pas
	--     chargées), RoyalHatcher (état du pass de la couveuse royale), XpBoost (1 ou 2 : pass XP x2),
	--     Hatch (JSON : la dernière tour sortie d'un œuf), LevelArena
	--     (numéro de sa zone de combat pendant un niveau, absent sinon), Team (JSON : leader, members = { { id, name,
	--     best } } ; absent : il joue seul), TeamInvite (JSON : from, name, seconds ; absent : pas d'invitation) ;
	--   du dossier de sa zone, workspace.Arenas.Arena<n> : Map, Level, State ("Running" | "Won" | "Lost"), Gold,
	--     Lives, Left, Total, Progress, SimSpeed, Training, TeamSize, et à la fin Result (JSON : won, level, reward,
	--     firstClear, coins, kills, total, lives, bigLeaks, xp, towers, evolutions, nextLevel, seconds, team, friend,
	--     coinsX2, xpX2, egg, eggKept, eggPlaced). En
	--     équipe, chaque joueur a aussi les siens : Gold_<n°>, Training_<n°>, Result_<n°> (n° = Levels.memberKey de
	--     son UserId), et Team (JSON : { { id, key, name } }) ; chaque tour posée porte OwnerId (UserId de son joueur).
	LevelAction = "RemoteEvent",
	-- serveur -> client : (message, kind, source). source = "Levels" pour un message d'un niveau.
	Notify = "RemoteEvent",
	-- Réglages du joueur, client -> serveur : ("SoundMode", "All" | "Effects" | "Mute") = bouton « SON »
	-- (SoundManager.luau). Sauvegardé avec ses données (PlayerData) et publié dans l'attribut « SoundMode » du joueur.
	Settings = "RemoteEvent",
}

local FOLDER_NAME = "Remotes"

-- Appelé une seule fois par le serveur au démarrage.
function Remotes.init()
	assert(RunService:IsServer(), "Remotes.init() doit être appelé côté serveur")
	local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end
	for name, className in DEFINITIONS do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new(className)
			remote.Name = name
			remote.Parent = folder
		end
	end
end

function Remotes.get(name: string): any
	assert(DEFINITIONS[name], "Remote inconnu : " .. name)
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
	return folder:WaitForChild(name)
end

return Remotes

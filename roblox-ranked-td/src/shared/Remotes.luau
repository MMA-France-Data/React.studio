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
	-- bits 0-3 = numéro dans IdleTowers.ORDER de la tour dont le contrôle est en cours (0 = aucun ; Frost =
	-- ralenti par un Totem de givre, Tesla = ralenti par un Mage des tempêtes, Orbital = étourdi par le
	-- Trébuchet royal), bit 7 (128) = fragile (aura d'un Totem de givre). Voir le haut de Combat.luau.
	PlotSync = "RemoteEvent",
	-- serveur -> clients : (numéro, buffer, count) tirs, count x 27 octets, puis count x 4 octets : l'id u32 de
	-- la cible que suit chaque projectile (0 = aucune ; format : Combat.luau, takeShotsPacket).
	-- Baliste lourde (type Rocket) : carreau perçant du départ au point d'arrivée, rayon 0 ; Trébuchet royal
	-- (type Orbital) : rayon = sa grande zone.
	PlotShots = "UnreliableRemoteEvent",
	-- NIVEAUX (règles : Shared/Levels.luau), client -> serveur :
	--   ("Start", niveau) | "Quit" (retour au camp ; pendant un niveau : abandon)
	--   | ("Place", type de tour, x, z) : pose libre, point de la zone de combat en coordonnées locales
	--   | ("Upgrade", id de la tour) | ("Sell", id) | ("Speed", 1 ou 2)
	--   | ("Buy", type de tour) : boutique à prix fixes, payée en pièces de niveau
	--   | ("SlotAssign", emplacement du camp, type de tour ou "") | ("SlotUpgrade", emplacement) | "SlotUnlock"
	--   | ("Bar", { types de tours }) : ordre de la barre rapide
	--   | ("Tutorial", "Skip") : bouton « Passer le tuto ».
	-- Le serveur vérifie tout (Hub/LevelsService.luau). État publié en attributs :
	--   du joueur : LevelsState (JSON : best, coins, towers = ses tours dans l'ordre de sa barre rapide, xp, slots,
	--     wins, losses, tutorial = étape du tuto ; absent tant que ses données ne sont pas chargées), LevelArena
	--     (numéro de sa zone de combat pendant un niveau, absent sinon) ;
	--   du dossier de sa zone, workspace.Arenas.Arena<n> : Map, Level, State ("Running" | "Won" | "Lost"), Gold,
	--     Lives, Left, Total, Progress, SimSpeed, Perks, Training, et à la fin Result (JSON : won, level, reward,
	--     firstClear, coins, kills, total, lives, bigLeaks, xp, towers, perks, nextLevel, seconds).
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

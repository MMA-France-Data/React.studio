local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

local DEFINITIONS = {
	-- Map principale (hub)
	-- Classé, client -> serveur : "Join" (bouton « ⚔ S'INSCRIRE AU CLASSÉ », dans le cercle de l'arène : revérifié
	-- par le serveur) | "Leave" (ANNULER) | "Accept" | "Refuse" (fenêtre « MATCH TROUVÉ ! »). Voir Matchmaking.luau.
	-- État publié en attributs du joueur : QueueState (Idle, Joining, Searching, Pending, Accepted, Found,
	-- Teleporting), QueueStartedAt (heure du serveur de l'inscription), InRankedCircle, et pendant un match
	-- proposé : MatchOpponent (nom), MatchOpponentMmr, MatchOpponentGames, MatchAcceptEndsAt (fin de la barre).
	QueueAction = "RemoteEvent",
	HubAction = "RemoteEvent", -- client -> serveur : "GoHome" | "GoRanked"
	-- Mode infini (parcelles)
	-- client -> serveur : ("Place", spot, type, typeRemplacé?) | ("Upgrade", spot) | ("Sell", spot) | ("BuySpot", spot) | "Rebirth"
	-- (typeRemplacé : seulement pour un remplacement confirmé ; sans lui, poser sur une tour est refusé)
	PlotAction = "RemoteEvent",
	-- serveur -> clients : (plotIndex, buffer, count) positions des ennemis (format : PlotGame:buildSyncPacket).
	-- La vitesse de chaque ennemi dans le paquet ne compte PAS le pass Vitesse x2 : le client la multiplie
	-- par l'attribut « SimSpeed » du dossier de la parcelle (1, ou 2 quand le pass est allumé).
	-- Après les count x 11 octets des ennemis : count octets « contrôle », un par ennemi dans le même ordre :
	-- bits 0-3 = numéro dans IdleTowers.ORDER de la tour dont le contrôle est en cours (0 = aucun ; Frost =
	-- ralenti par un Totem de givre, Tesla = ralenti par un Mage des tempêtes, Orbital = étourdi par le
	-- Trébuchet royal), bit 7 (128) = fragile (aura d'un Totem de givre). Voir le haut de PlotGame.luau.
	PlotSync = "RemoteEvent",
	-- serveur -> clients : (plotIndex, buffer, count) tirs, count x 27 octets, puis count x 4 octets : l'id u32 de
	-- la cible que suit chaque projectile (0 = aucune ; format : PlotGame:takeShotsPacket et le haut de PlotGame).
	-- Baliste lourde (type Rocket) : carreau perçant du départ au point d'arrivée, rayon 0 ; Trébuchet royal
	-- (type Orbital) : rayon = sa grande zone.
	PlotShots = "UnreliableRemoteEvent",
	CoinDrop = "RemoteEvent", -- serveur -> propriétaire : ("Set" | "Collect", id, position, montant)
	-- Machines à sous
	OpenMachine = "RemoteEvent", -- serveur -> client : ("Tower" | "Bonus") quand on active une machine
	-- client -> serveur : ("SpinTower", nombre de lancers : 1 si absent, voir IdleConfig.TOWER_SPIN_BULKS)
	--                    | "SpinBonusCoins" (forge en pièces, sans délai)
	--                    | ("ApplyBonus", spot, bonusId) (rune posée dans l'emplacement de sa sorte : dégâts ou vitesse)
	-- Forge : état publié en attributs du joueur (ForgeSpinsBought, ForgeCoinPrice (-1 = MAX), ForgeDrawable,
	-- ForgeBlocked), voir PlotGame:publishForge. Quand ForgeBlocked n'est pas vide, le client bloque aussi le
	-- bouton Robux (un reçu qui arrive quand même donne la meilleure rune).
	MachineAction = "RemoteEvent",
	-- serveur -> client : résultat d'un lancer. Autel des héros : { machine = "Tower", count, tower, rarity,
	-- isNew, dupes, results = { { tower, rarity, count, isNew } }, source = "Coins" | "Challenge" } (voir
	-- PlotGame:spinTower ; "Challenge" = lancers offerts par un défi classé).
	-- Forge runique : { machine = "Bonus", bonus, source = "Coins" | "Robux" | "Challenge", price (pièces payées,
	-- 0 en Robux ou offert), forgeSpinsBought } (voir PlotGame:grantBonusSpin).
	MachineResult = "RemoteEvent",
	-- Gains d'absence, serveur -> client, une fois en arrivant sur la map principale (Hub/init.luau) :
	-- (payload) = { amount, seconds, kind = "Offline" | "Match", capped, offlineAmount, offlineSeconds,
	-- matchAmount, matchSeconds, coinFactor }. amount = total versé, seconds = temps compté, kind = "Match" si tu
	-- reviens d'un match ranked, capped = plafond du jour atteint (gains hors ligne, voir IdleConfig),
	-- coinFactor = 2 si les montants (déjà multipliés) ont été doublés par le pass Pièces x2, sinon 1.
	OfflineGains = "RemoteEvent",
	-- Passes de jeu, client -> serveur : "ToggleSpeed" (allume / éteint la vitesse x2, pass Vitesse x2 requis).
	-- Possession publiée en attributs du joueur : PassAutoCollect, PassSpeedX2, PassCoinsX2, SpeedX2Enabled
	-- (x2 actif).
	PassAction = "RemoteEvent",
	-- Défis classés, client -> serveur : ("Claim", clé du défi "d1".."d3" | "w1" | "w2", numéro du jour ou de la
	-- semaine affiché) = bouton « Récupérer ». Le serveur revérifie tout (Hub/ChallengeRewards.luau). État publié
	-- en attributs du joueur : ChallengeState (JSON, voir Challenges.clientState) et ChallengesReady (nombre de
	-- récompenses à récupérer).
	ChallengeAction = "RemoteEvent",
	-- Commun
	Notify = "RemoteEvent", -- serveur -> client : (message, kind)
	-- Match
	PlaceTower = "RemoteEvent", -- client -> serveur : (towerType, position)
	UpgradeTower = "RemoteEvent", -- client -> serveur : (towerId)
	SellTower = "RemoteEvent", -- client -> serveur : (towerId)
	-- serveur -> client : (result). result.challenges = ligne des défis classés (« Défis : +1 match joué », ou
	-- pourquoi le match ne compte pas), absente pour un match annulé.
	MatchResult = "RemoteEvent",
	TowerFired = "UnreliableRemoteEvent", -- serveur -> clients : (from, to, towerType, radius, towerId)
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

-- Réglages centraux du jeu. Modifie les valeurs ici plutôt que dans le code.
local Config = {}

-- Change ce numéro pour lancer une nouvelle saison (soft reset du MMR + nouveau classement).
Config.SEASON = 1

-- Dans Studio, TeleportService ne marche pas : on ne peut pas tester le vrai matchmaking.
--   "Auto"  -> Lobby : map principale (parcelles + cercle ranked)
--   "Match" -> lance directement un match pour tester le gameplay
--              (Test > Clients and Servers > 2 joueurs, ou 1 joueur contre un bot)
Config.STUDIO_FORCE_MODE = "Auto"

-- Produits Robux (Developer Products), à créer dans le Creator Dashboard :
-- Monétisation > Developer Products, puis colle l'ID ici. 0 = pas encore configuré.
Config.Products = {
	BONUS_SPIN = 0, -- un lancer de la machine à bonus
}

-- Passes de jeu (Game Passes) : achetés une seule fois en Robux, gardés pour toujours. Mode solo
-- (ta parcelle) uniquement : rien ne change en ranked (mêmes tours, même or pour tout le monde).
-- Pour les créer : Creator Dashboard > ton expérience > Monétisation > Passes > « Créer un pass »
-- (image, nom, description) > Enregistrer. Ouvre le pass > Ventes : active « Article en vente » et
-- choisis le prix en Robux. Copie son ID (le nombre dans l'adresse de la page du pass) et colle-le ici.
-- 0 = pas encore créé : la boutique affiche « Bientôt disponible » (Monetization.luau).
Config.GamePasses = {
	AUTO_COLLECT = 0, -- Ramassage auto : les pièces tombées sur ta parcelle sont ramassées sans marcher
	SPEED_X2 = 0, -- Vitesse x2 : vagues et tirs deux fois plus rapides sur ta parcelle (bouton pour l'éteindre)
}

-- Distance (en studs) entre ton personnage et un objet sous laquelle son texte flottant s'affiche :
-- l'écran reste lisible, chaque étiquette n'apparaît que quand on s'approche (ProximityLabel.luau).
Config.LabelDistance = {
	Close = 25, -- niveaux des tours, prix des emplacements, montants des pièces, noms des autels
	Medium = 45, -- barres de vie sur les parcelles, panneaux des fiefs, badges des tours en match
	Far = 80, -- barres de vie et forteresses en match (on regarde son terrain de loin)
}

Config.Data = {
	DATASTORE_NAME = "RankedTD_PlayerData_v1",
	-- Dans Studio, utilise des DataStores en mémoire (rien n'est sauvegardé pour de vrai).
	MOCK_IN_STUDIO = true,
	AUTOSAVE_INTERVAL = 60,
	-- Un verrou de session plus vieux que ça est considéré comme abandonné (serveur crashé).
	LOCK_EXPIRY = 600,
	-- Si un autre serveur tient encore le verrou (ex : le lobby qui sauvegarde pendant la
	-- téléportation), on réessaie N fois avant de forcer.
	LOAD_RETRIES = 8,
	LOAD_RETRY_DELAY = 2.5,
}

Config.Ranked = {
	START_MMR = 1000,
	MIN_MMR = 0,
	K_FACTOR = 32,
	-- Les premiers matchs bougent plus le MMR pour placer le joueur plus vite.
	PLACEMENT_GAMES = 5,
	PLACEMENT_K_FACTOR = 48,
	-- Nouvelle saison : MMR = START + (ancien - START) * SEASON_SOFT_RESET
	SEASON_SOFT_RESET = 0.5,
	LEADERBOARD_SIZE = 20,
	LEADERBOARD_REFRESH = 60,
}

Config.Matchmaking = {
	-- Écart de MMR accepté : BASE_RANGE + RANGE_GROWTH_PER_SECOND * secondes d'attente (plafonné).
	BASE_RANGE = 75,
	RANGE_GROWTH_PER_SECOND = 8,
	MAX_RANGE = 600,
	QUEUE_ENTRY_TTL = 60,
	QUEUE_REFRESH_INTERVAL = 15,
	ASSIGNMENT_POLL_INTERVAL = 2,
	MATCHER_INTERVAL = 2,
	LEADER_TTL = 10,
	ASSIGNMENT_TTL = 120,
	MATCH_INFO_TTL = 3600,
}

Config.Match = {
	WAIT_FOR_PLAYERS = 45,
	-- Studio : délai avant de remplacer le 2e joueur absent par un bot (match non classé).
	STUDIO_SOLO_WAIT = 10,
	COUNTDOWN = 5,
	STARTING_GOLD = 500,
	BASE_HEALTH = 100,
	FIRST_WAVE_DELAY = 8,
	WAVE_INTERVAL = 22,
	BASE_INCOME = 100,
	MAX_DURATION = 20 * 60,
	RESULT_SCREEN_TIME = 10,
	MAX_TOWERS = 30,
	MAX_ENEMIES_PER_LANE = 250,
	SELL_REFUND = 0.6,
	ACTION_COOLDOWN = 0.15,
}

return Config

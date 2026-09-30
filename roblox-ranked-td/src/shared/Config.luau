-- Réglages centraux du jeu. Modifie les valeurs ici plutôt que dans le code.
local Config = {}

-- Change ce numéro pour lancer une nouvelle saison (soft reset du MMR + nouveau classement).
Config.SEASON = 1

-- LE CLASSÉ EST-IL OUVERT ? Sortie sans le classé, décidée le 30/09/2026 (« on va commencer sans la ranked et la
-- travailler encore ») ; mettre true pour l'ouvrir.
-- false : dans le cercle de l'arène, « BIENTÔT DISPONIBLE » à la place du bouton « S'INSCRIRE » ; le serveur refuse
-- toute inscription et ne fait aucun matchmaking (aucun appel à MemoryStore) ; bouton des défis classés caché ;
-- tableau du classement, plaques et carte de rang : « BIENTÔT DISPONIBLE » ; le tuto dit que le classé arrive bientôt.
-- Tout le jeu le lit avec Shared/RankedGate.luau (RankedGate.isOpen). Le serveur de match ne change pas.
Config.RANKED_OPEN = false

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
	COINS_X2 = 0, -- Pièces x2 : toutes les pièces gagnées sur ta parcelle sont doublées (ennemis tués, gains d'absence)
}

-- Tes parties de test dans Studio : ces passes sont donnés automatiquement à tous les joueurs quand tu
-- joues dans Studio (jamais dans le jeu publié, ni pendant les tests automatiques de tools/studio-test).
-- Mets false pour tester comme un joueur qui ne les a pas.
Config.STUDIO_TEST_PASSES = {
	AUTO_COLLECT = true,
	SPEED_X2 = true,
	COINS_X2 = true,
}

-- Galerie des ennemis (Studio seulement) : quand tu joues dans Studio, un bouton « GALERIE (Studio) »
-- t'emmène voir tous les ennemis du mode solo (6 types x 10 styles, un style par tranche de 10 vagues),
-- construits exactement comme en jeu (src/client/EnemyGallery.luau). Jamais dans le jeu publié.
-- Mets false pour ne plus la construire.
Config.STUDIO_ENEMY_GALLERY = true

-- Panneau des sons (Studio seulement) : quand tu joues dans Studio, un bouton « SONS (Studio) » ouvre la liste
-- de tous les sons du jeu (src/shared/Sounds.luau) avec un bouton « Jouer » pour écouter chacun
-- (src/client/SoundPanel.luau). Jamais dans le jeu publié. Mets false pour ne plus l'afficher.
Config.STUDIO_SOUND_PANEL = true

-- Scènes toutes prêtes (Studio seulement) : quand tu joues dans Studio, un bouton « SCÈNES (Studio) » remplit ta
-- parcelle de 22 tours et lance la vague du dragon (100) ou du boss de glace (40), avec ton personnage face à lui
-- (src/server/Hub/StudioScenes.luau) : pour voir ou filmer un boss sans jouer des heures. Jamais dans le jeu publié,
-- et tes données de Studio ne sont jamais sauvegardées. Mets false pour ne plus l'afficher.
Config.STUDIO_SCENES = true

-- Tuto des nouveaux joueurs (src/client/TutorialUI.luau) dans Studio : tes données y sont en mémoire, tu es donc un
-- nouveau joueur à chaque Play et le tuto s'affiche à chaque fois. Mets false pour ne plus le voir dans Studio
-- (rejouer quand même : barre de commande, vue Serveur,
-- game.ServerStorage.StudioDebug:Invoke(game.Players:GetPlayers()[1], "Tutorial", "Replay")).
-- Ne change rien au jeu publié : chaque nouveau joueur y voit le tuto une seule fois.
Config.STUDIO_TUTORIAL = true

-- Langue du jeu dans Studio (src/shared/Lang.luau). Dans le jeu publié, un joueur dont la langue Roblox est le
-- français voit le jeu en français, tous les autres en anglais.
--   "auto" -> comme dans le jeu publié (d'après la langue de ton Studio / de ton compte Roblox)
--   "fr"   -> toujours en français
--   "en"   -> toujours en anglais (pour vérifier la traduction)
-- Ne change rien au jeu publié. Les tests automatiques (tools/studio-test) démarrent toujours en français.
Config.STUDIO_LANGUAGE = "auto"

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

-- Matchmaking ranked (fonctionnement et états : en haut de src/server/Matchmaking.luau). Temps en secondes.
Config.Matchmaking = {
	-- Écart de MMR accepté : BASE_RANGE + RANGE_GROWTH_PER_SECOND * secondes d'attente (plafonné).
	BASE_RANGE = 75,
	RANGE_GROWTH_PER_SECOND = 8,
	MAX_RANGE = 600,
	QUEUE_ENTRY_TTL = 60,
	QUEUE_REFRESH_INTERVAL = 15,
	INVITE_POLL_INTERVAL = 2, -- un joueur inscrit : son serveur regarde toutes les 2 s si un match lui est proposé
	MATCHER_INTERVAL = 2,
	LEADER_TTL = 10,
	MATCH_INFO_TTL = 3600,
	-- Match trouvé : les deux joueurs doivent ACCEPTER avant la téléportation.
	ACCEPT_SECONDS = 15, -- temps pour accepter (barre de la fenêtre « MATCH TROUVÉ ! »)
	-- En plus, côté serveur seulement : le temps que la proposition arrive au serveur de chaque joueur (et un
	-- petit écart d'horloge entre deux serveurs). Personne ne voit ces secondes : la barre dure ACCEPT_SECONDS.
	ACCEPT_GRACE = 3,
	PROPOSAL_POLL_INTERVAL = 1, -- match proposé : on relit les réponses toutes les secondes
	PROPOSAL_TTL = 300, -- durée de vie d'une proposition dans MemoryStore (tout est fini bien avant)
	START_TIMEOUT = 30, -- les deux ont accepté mais le match n'est toujours pas créé : retour dans la file
	TELEPORT_TIMEOUT = 60, -- toujours sur ce serveur après ça : téléportation ratée, le joueur est libéré
	SIGNUP_COOLDOWN = 2, -- anti-spam : secondes entre deux inscriptions d'un même joueur
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

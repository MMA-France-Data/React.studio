-- Réglages centraux du jeu. Modifie les valeurs ici plutôt que dans le code.
-- Les règles et les chiffres des niveaux (monstres, prix, entraînement) sont dans src/shared/Levels.luau.
local Config = {}

-- Galerie des ennemis (Studio seulement) : quand tu joues dans Studio, un bouton « GALERIE (Studio) »
-- t'emmène voir tous les ennemis (6 types x 10 styles), construits exactement comme en jeu
-- (src/client/EnemyGallery.luau). Jamais dans le jeu publié. Mets false pour ne plus la construire.
Config.STUDIO_ENEMY_GALLERY = true

-- Panneau des sons (Studio seulement) : quand tu joues dans Studio, un bouton « SONS (Studio) » ouvre la liste
-- de tous les sons du jeu (src/shared/Sounds.luau) avec un bouton « Jouer » pour écouter chacun
-- (src/client/SoundPanel.luau). Jamais dans le jeu publié. Mets false pour ne plus l'afficher.
Config.STUDIO_SOUND_PANEL = true

-- Tuto des nouveaux joueurs dans Studio (src/client/TutorialUI.luau). Dans Studio, tes données ne sont pas
-- sauvegardées : tu es un nouveau joueur à chaque Play, et la flèche du tuto revient donc à chaque fois (le bouton
-- « Passer le tuto » l'arrête pour ce Play). Mets false pour ne plus la voir dans Studio. Ne change rien au jeu
-- publié : un nouveau joueur y voit toujours le tuto, une seule fois.
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
	Close = 25, -- niveaux des tours, noms des bâtiments du camp
	Medium = 45, -- barres de vie, étiquettes des socles d'entraînement
}

Config.Data = {
	-- Nom de la sauvegarde. Ce n'est PAS celui de l'ancien jeu (« RankedTD_PlayerData_v1 », jeu infini et classé) :
	-- même publié par erreur sur l'ancienne expérience, ce jeu ne lit et n'écrase jamais ses sauvegardes.
	DATASTORE_NAME = "Niveaux_PlayerData_v1",
	-- Dans Studio, utilise des DataStores en mémoire (rien n'est sauvegardé pour de vrai).
	MOCK_IN_STUDIO = true,
	AUTOSAVE_INTERVAL = 60,
	-- Un verrou de session plus vieux que ça est considéré comme abandonné (serveur crashé).
	LOCK_EXPIRY = 600,
	-- Si un autre serveur tient encore le verrou (le joueur vient de changer de serveur), on réessaie N fois avant
	-- de forcer.
	LOAD_RETRIES = 8,
	LOAD_RETRY_DELAY = 2.5,
}

return Config

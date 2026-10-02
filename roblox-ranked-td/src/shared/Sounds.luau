-- Tous les sons du jeu, au même endroit. Pour changer un son, remplace juste son numéro (id) : trouve un son
-- GRATUIT dans Studio (Boîte à outils > Audio) ou sur le Creator Store, copie son numéro et colle-le ici (voir la
-- partie « Sons » du README). Joués par src/client/SoundManager.luau, seulement chez le joueur (rien sur le
-- serveur). Dans Studio, le bouton « SONS (Studio) » fait écouter chaque son (src/client/SoundPanel.luau).
--
-- Tous ces sons sont gratuits et utilisables par n'importe quel jeu : sons de Roblox, et bibliothèques
-- sous licence de Roblox (Pro Sound Effects pour les bruitages, APM Music pour les musiques et les jingles),
-- vérifiés sur le Creator Store (gratuit, public, bon type, durée). Titre et créateur écrits à côté de chaque id.
--
-- Réglages d'un son :
--   name        = son nom en français (panneau « SONS (Studio) »)
--   id          = numéro du son (Creator Store)
--   volume      = 0 à 1 (le bouton « Son » du joueur coupe tout ou garde seulement les effets)
--   pitch       = hauteur (1 = normal, 0,8 = plus grave, 1,2 = plus aigu) ; facultatif
--   variation   = petite hauteur au hasard à chaque fois (0,08 = ± 8 %) : 50 flèches ne sonnent pas pareil
--   maxAtOnce   = nombre de fois qu'il peut jouer EN MÊME TEMPS au plus (au-delà, le nouveau est ignoré)
--   minInterval = secondes au moins entre deux départs de ce son (Vitesse x2 = 2 fois plus de tirs : ça tient)
--   range       = distance (studs) à laquelle on l'entend encore : son 3D, placé dans le monde (tours, impacts,
--                 morts). Sans range = son 2D d'interface, entendu pareil partout.
--   stopAfter   = coupe le son au bout de ces secondes (sons un peu longs) ; facultatif
--   loop        = son qui tourne en boucle (rayon du Sorcier des arcanes, musiques)
--   priority    = son 3D rare et important (mort d'un boss) : il joue même quand la limite MAX_COMBAT_SOUNDS est
--                 atteinte par les flèches et les rochers, et il n'y compte pas ; facultatif
local Sounds = {}

-- Sons 3D (tours, impacts, morts) qui jouent en même temps au plus, sur TOUTE la map. Les plus proches de la
-- caméra passent d'abord : des dizaines de monstres ne font jamais un brouhaha. (Un son
-- « priority », la mort d'un boss, passe toujours et ne compte pas.)
Sounds.MAX_COMBAT_SOUNDS = 10
-- Rayons des Sorciers des arcanes qui bourdonnent en même temps au plus (les plus proches).
Sounds.MAX_BEAM_LOOPS = 3
-- En dessous de cette distance (studs), un son 3D joue à plein volume ; il s'éteint à sa « range ».
Sounds.ROLLOFF_MIN_DISTANCE = 12
-- Musique : fondu (secondes) quand elle démarre ou s'arrête (bouton « Son »).
Sounds.MUSIC_FADE_TIME = 2

Sounds.SLOTS = {
	----------------------------------------------------------------------
	-- Tours (sons 3D : seulement près de la tour)
	----------------------------------------------------------------------
	-- « Arrow In And Hit 13 (SFX) », Pro Sound Effects (1 s)
	ArcherShot = { name = "Flèche de l'Archer du rempart", id = 9113161406, volume = 0.3, variation = 0.1, maxAtOnce = 4, minInterval = 0.09, range = 70 },
	-- « Ice Freeze Large Piece Crackles Liquid Nitro (SFX) », Pro Sound Effects (2 s)
	FrostPulse = { name = "Onde du Totem de givre", id = 9125611419, volume = 0.25, variation = 0.06, maxAtOnce = 2, minInterval = 0.5, range = 60, stopAfter = 1.2 },
	-- « Catapult Launch », Roblox (4 s)
	CatapultLaunch = { name = "Tir de la Catapulte", id = 17283613561, volume = 0.35, variation = 0.08, maxAtOnce = 3, minInterval = 0.25, range = 80, stopAfter = 2 },
	-- « Big Rock Hits Dirt 3 (SFX) », Pro Sound Effects (2 s)
	CatapultImpact = { name = "Impact du rocher (Catapulte)", id = 9113436467, volume = 0.4, variation = 0.08, maxAtOnce = 3, minInterval = 0.2, range = 80 },
	-- « Lightning Flashes Quick Electrical Bursts 13 (SFX) », Pro Sound Effects (1 s)
	StormLightning = { name = "Foudre du Mage des tempêtes", id = 9116275998, volume = 0.3, variation = 0.1, maxAtOnce = 3, minInterval = 0.15, range = 70 },
	-- « Crossbow Fire 12 (SFX) », Pro Sound Effects (1 s)
	BallistaShot = { name = "Tir de la Baliste lourde", id = 9114001369, volume = 0.45, variation = 0.06, maxAtOnce = 2, minInterval = 0.2, range = 80 },
	-- « Crossbow Bolts Impact 40 (SFX) », Pro Sound Effects (1 s)
	BallistaImpact = { name = "Impact du carreau (Baliste)", id = 9113999743, volume = 0.45, variation = 0.06, maxAtOnce = 2, minInterval = 0.2, range = 80 },
	-- « Electric Arcing 2 (SFX) », Pro Sound Effects (10 s, en boucle tant que le rayon touche)
	ArcaneBeam = { name = "Rayon du Sorcier des arcanes (boucle)", id = 9114236059, volume = 0.18, pitch = 1.1, range = 50, loop = true },
	-- « Electric Zaps 12 (SFX) », Pro Sound Effects (1 s)
	OracleChain = { name = "Éclair en chaîne de l'Oracle", id = 9114277757, volume = 0.35, variation = 0.08, maxAtOnce = 2, minInterval = 0.25, range = 80 },
	-- « Catapult Launch », Roblox (4 s), joué plus grave : bras plus lourd
	TrebuchetLaunch = { name = "Tir du Trébuchet royal", id = 17283613561, volume = 0.45, pitch = 0.75, variation = 0.04, maxAtOnce = 2, minInterval = 0.4, range = 100, stopAfter = 2.5 },
	-- « Dirt Explosion 3 (SFX) », Pro Sound Effects (3 s)
	TrebuchetImpact = { name = "Gros impact du Trébuchet royal", id = 9114086859, volume = 0.5, variation = 0.05, maxAtOnce = 2, minInterval = 0.4, range = 110 },

	----------------------------------------------------------------------
	-- Ennemis
	----------------------------------------------------------------------
	-- « Body Fall Thud 2 (SFX) », Pro Sound Effects (1 s)
	EnemyDeath = { name = "Mort d'un ennemi", id = 9113480915, volume = 0.3, variation = 0.12, maxAtOnce = 4, minInterval = 0.08, range = 60 },
	-- « Armor Metal Clanks To Ground 3 (SFX) », Pro Sound Effects (2 s)
	BigDeath = { name = "Mort d'un gros ennemi (chevalier, colosse)", id = 9113157634, volume = 0.45, pitch = 0.85, variation = 0.06, maxAtOnce = 2, minInterval = 0.2, range = 90 },
	-- « Thunder With Lion Roar Searing Blast Growl 3 (SFX) », Roblox (4 s)
	BossDeath = { name = "Mort d'un boss", id = 9120031442, volume = 0.55, maxAtOnce = 1, minInterval = 1, range = 160, priority = true },
	-- « Horn Call 3 - Remastered », APM Music (Alfred Kluten, 7 s) : son 2D, seulement dans ton niveau
	BossArrival = { name = "Arrivée d'un boss (cor de guerre)", id = 1838612394, volume = 0.5, maxAtOnce = 1, minInterval = 3 },
	-- « Boomy Footsteps Giant Thumpy Dinosaur Footst (SFX) », Pro Sound Effects (3 s) : 2D, dans ton niveau
	GiantArrival = { name = "Arrivée d'un chevalier colossal", id = 9125404769, volume = 0.5, maxAtOnce = 1, minInterval = 3 },

	----------------------------------------------------------------------
	-- Pendant un niveau (sons 2D)
	----------------------------------------------------------------------
	-- « Hammer Nail Into Wood 9 (SFX) », Pro Sound Effects (1 s)
	TowerPlaced = { name = "Tour posée", id = 9114756156, volume = 0.5, maxAtOnce = 2, minInterval = 0.1 },
	-- « Blacksmith Anvil Hammer Hits 16 (SFX) », Pro Sound Effects (1 s)
	TowerUpgraded = { name = "Tour améliorée", id = 9113447467, volume = 0.4, variation = 0.05, maxAtOnce = 2, minInterval = 0.08 },
	-- « Coin Throws 3 (SFX) », Pro Sound Effects (1 s)
	TowerSold = { name = "Tour vendue", id = 9113849651, volume = 0.45, maxAtOnce = 1, minInterval = 0.2 },
	-- « Victory Fanfare Sting », APM Music (Alan Hawkshaw, 10 s) : niveau gagné, tour qui évolue
	Victory = { name = "Victoire", id = 1836473422, volume = 0.5, maxAtOnce = 1, minInterval = 2 },
	-- « BOOM-Deep Boom 13 », APM Music (Aaron Frensley, 4 s)
	Defeat = { name = "Défaite", id = 1837830278, volume = 0.5, maxAtOnce = 1, minInterval = 2 },

	----------------------------------------------------------------------
	-- Interface
	----------------------------------------------------------------------
	-- « Roblox_UI_Small_Click », Roblox (moins d'1 s)
	Click = { name = "Clic sur un bouton", id = 15675032796, volume = 0.35, maxAtOnce = 2, minInterval = 0.05 },
	-- « Roblox GUI - Negative », Roblox (moins d'1 s)
	Error = { name = "Erreur / refusé", id = 17208353912, volume = 0.45, maxAtOnce = 1, minInterval = 0.25 },

	----------------------------------------------------------------------
	-- Musiques : plusieurs morceaux médiévaux qui s'enchaînent (Sounds.PLAYLISTS, dans un ordre au hasard, sans
	-- rejouer deux fois de suite le même), moins forts que les effets (demande du propriétaire : « musique un peu
	-- forte, et 3-4 musiques médiévales qui changent »). Coupées par le bouton « Son : effets seuls ».
	-- Toutes gratuites, de comptes vérifiés sous licence de Roblox (APMOfficial, DistrokidOfficial).
	----------------------------------------------------------------------
	-- « Courtly Dances », APM Music (Brian Whitehouse, 2 min 32)
	MusicHub1 = { name = "Map : danses de la cour", id = 1836393907, volume = 0.13, music = true },
	-- « Royal Court Background Music », Glenberric (DistrokidOfficial, 3 min 45)
	MusicHub2 = { name = "Map : cour royale", id = 139186694323000, volume = 0.13, music = true },
	-- « Cozy Tavern Background Music », Glenberric (DistrokidOfficial, 4 min 15)
	MusicHub3 = { name = "Map : taverne", id = 132846105965979, volume = 0.13, music = true },
	-- « The Ancient Lutes », Medieval Tavern Music | REDEEMED RUST (DistrokidOfficial, 4 min 05)
	MusicHub4 = { name = "Map : luths anciens", id = 137023744071437, volume = 0.13, music = true },
}

-- Morceaux joués à la suite, dans un ordre au hasard.
Sounds.PLAYLIST = { "MusicHub1", "MusicHub2", "MusicHub3", "MusicHub4" }

-- Ordre et titres du panneau « SONS (Studio) ».
Sounds.GROUPS = {
	{ title = "Tours", slots = { "ArcherShot", "FrostPulse", "CatapultLaunch", "CatapultImpact", "StormLightning", "BallistaShot", "BallistaImpact", "ArcaneBeam", "OracleChain", "TrebuchetLaunch", "TrebuchetImpact" } },
	{ title = "Ennemis", slots = { "EnemyDeath", "BigDeath", "BossDeath", "BossArrival", "GiantArrival" } },
	{ title = "Niveaux", slots = { "TowerPlaced", "TowerUpgraded", "TowerSold", "Victory", "Defeat" } },
	{ title = "Interface", slots = { "Click", "Error" } },
	{ title = "Musiques", slots = { "MusicHub1", "MusicHub2", "MusicHub3", "MusicHub4" } },
}

-- Réglage du bouton « Son » du joueur (sauvegardé avec ses données, voir PlayerData) :
--   All = musique + effets, Effects = effets seuls (pas de musique), Mute = aucun son du jeu (même les bruits
--   de pas des personnages, rangés dans le groupe « Effets » par SoundManager).
Sounds.MODES = { "All", "Effects", "Mute" }
Sounds.MODE_LABELS = { All = "tout", Effects = "effets seuls", Mute = "muet" }

-- Adresse Roblox d'un son (« rbxassetid://12345 »).
function Sounds.assetId(id: number): string
	return "rbxassetid://" .. tostring(id)
end

return Sounds

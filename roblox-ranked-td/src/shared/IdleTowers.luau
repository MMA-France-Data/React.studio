-- Les 16 TOURS du jeu : leurs stats de combat. Leur prix en or, leur prix à la boutique et leurs évolutions sont
-- dans Levels.luau ; le combat lui-même est dans Hub/Combat.luau.
-- (Ce fichier garde le nom qu'il avait dans l'ancien jeu.)
--
-- DEUX PALIERS. Demande du propriétaire (04/10/2026) : « archer, archer enflammé, déjà pas les mêmes » ; « la
-- première tour quasi obsolète après, une claire différence de niveau entre chaque tour de palier ».
--   * PALIER 1 (TIER1) : les 8 tours de départ et de la boutique (décrites juste en dessous) ;
--   * PALIER 2 (TIER2) : leurs 8 versions fortes, qu'on n'a QUE dans les œufs (« LES ŒUFS », Levels.luau). Une tour
--     de palier 2 a un champ base = sa tour de palier 1 : même rôle, même rareté, même silhouette (avec une parure
--     en plus, Hub/IdleTowerModel.luau), mais 2,3 à 3,5 fois ses dégâts par seconde, et ses pouvoirs (feu,
--     fragilité, carreau perçant...) sont déjà là : elle n'a pas d'améliorations d'entraînement (Levels.PERKS),
--     l'entraînement ne lui donne que des dégâts. Ses effets, ses sons et ses contrôles sont ceux de sa tour de base
--     (IdleTowers.baseOf).
--
-- Chaque tour de palier 1 a son rôle :
--   Archer du rempart   -> tireur rapide à longue portée (21) : fort contre les files de monstres ; ses flèches
--                          enflammées (évolution ★) laissent des zones de feu
--   Totem de givre      -> tour de CONTRÔLE : ralentit tout ce qui passe dans son aura et rend ces monstres
--                          FRAGILES (+X % de dégâts reçus des autres tours, sauf le Mage des tempêtes ; X monte
--                          avec son niveau) ; ses propres dégâts restent faibles
--   Catapulte           -> grosse zone contre les foules tassées
--   Mage des tempêtes   -> contrôle : petite zone (3) + ralentissement TRÈS fort (-90 %) mais court
--   Baliste lourde      -> gros carreaux PERÇANTS à longue portée (30) : vise le plus résistant (entre monstres
--                          presque aussi résistants, celui qui en aligne le plus), et le carreau transperce
--                          jusqu'à 3 monstres sur sa ligne (BALLISTA_PIERCE_MAX)
--   Sorcier des arcanes -> rayon qui monte : très fort contre les lents (boss, colosse, chevaliers lourds),
--                          faible contre les rapides
--   Oracle de la foudre -> un éclair qui touche 4 monstres
--   Trébuchet royal     -> écrase le plus gros groupe du chemin et l'étourdit (faible contre un boss seul)
-- Projectiles (flèches, rochers, carreaux, pierres) : la tour vise l'endroit où sera le monstre, et les dégâts
-- tombent à l'impact, pas au moment du tir (voir Combat.luau). Archer, Catapulte et Baliste SUIVENT leur
-- cible : à l'impact, l'effet tombe là où elle est vraiment (si elle vit encore et n'est pas trop loin du
-- point prévu, voir followDistance), même si un ralentissement arrivé pendant le vol l'a retardée. Le
-- Trébuchet royal garde son point prévu (il vise une foule, pas un monstre).
--
-- CONTRÔLES (règle du propriétaire : « aucun cumul de ralentissement ») : un monstre ne subit qu'UN SEUL effet
-- de contrôle à la fois (ralentissement du Totem de givre, ralentissement du Mage des tempêtes,
-- étourdissement du Trébuchet royal), et sa force ne se multiplie jamais. Un autre type de tour ne peut rien
-- tant que l'effet en cours dure (premier arrivé, premier servi). Totem de givre et Mage des tempêtes ne se
-- cumulent donc pas : le joueur choisit. La fragilité du Totem n'est PAS un contrôle (elle s'applique toujours).
-- FATIGUE des contrôles courts : le Mage et le Trébuchet ne prolongent JAMAIS leur effet en cours, et quand il
-- se termine, le monstre est immunisé contre ce type de tour pendant slowImmunity / stunImmunity secondes
-- (sinon beaucoup de Mages gèlent tout). Le Totem de givre (aura faite pour durer) n'a pas d'immunité : un
-- autre Totem prolonge son effet. Détails : applyControl dans Combat.luau.
--
-- Façons de toucher (kind) :
--   "Single" : une cible ; "Splash" : une zone autour du point d'impact (rayon `splash`) ;
--   "Pierce" : un carreau qui transperce les monstres sur la ligne tour -> point d'impact (demi-largeur
--   `pierceWidth`), BALLISTA_PIERCE_MAX au plus ;
--   "Aura" : tous les monstres à portée ; "Chain" : un éclair qui rebondit ; "Beam" : rayon continu.
-- Façons de viser (targeting) : "First" = le plus avancé, "Strongest" = le plus résistant (avec un carreau
-- perçant : entre monstres presque aussi résistants, celui qui en aligne le plus, voir BALLISTA_TIE_RATIO),
-- "Crowd" = le point du chemin où la zone touchera le plus de monstres (Trébuchet, voir Combat:pickCrowdTarget).
-- Avec projectileSpeed (studs par seconde), la tour lance un projectile (temps de vol : flightTime) ;
-- sans, elle touche tout de suite.
-- Effets : slow + slowDuration = ralentissement (contrôle) ; stunDuration = étourdissement (contrôle, vitesse
-- 0) ; slowImmunity / stunImmunity = contrôle COURT : jamais prolongé, puis immunité (fatigue, voir plus haut) ;
-- fragilityBase/PerLevel/Max = fragilité du Totem ; ignoresFragility = ses dégâts ne profitent pas de la
-- fragilité.
-- Changer un chiffre ici change la difficulté des niveaux : relancer tools\levels\run.ps1 -Tests, et au besoin
-- -Tune pour refaire les PV des niveaux.
local IdleConfig = require(script.Parent.IdleConfig)

local IdleTowers = {}

-- Toutes les tours : les 8 de palier 1, puis leurs 8 versions de palier 2 dans le même ordre. Leur numéro dans cette
-- liste voyage dans les paquets des tirs et des contrôles (Combat.luau) : ne jamais changer l'ordre, ajouter à la fin.
IdleTowers.ORDER = {
	"MachineGun", "Frost", "Bomb", "Tesla", "Rocket", "Laser", "Chain", "Orbital",
	"FireArcher", "BlizzardTotem", "MagmaCatapult", "StormArchmage", "DragonBallista", "VoidSorcerer", "ThunderOracle", "CelestialTrebuchet",
}
IdleTowers.TIER1 = { "MachineGun", "Frost", "Bomb", "Tesla", "Rocket", "Laser", "Chain", "Orbital" }
IdleTowers.TIER2 = { "FireArcher", "BlizzardTotem", "MagmaCatapult", "StormArchmage", "DragonBallista", "VoidSorcerer", "ThunderOracle", "CelestialTrebuchet" }

-- Temps de vol maximal d'un projectile, en secondes de simulation : il voyage sur 1 octet (en centièmes
-- de seconde, 2,55 s au plus) dans le paquet des tirs (Combat.luau). Un réglage plus long est coupé ici.
IdleTowers.MAX_FLIGHT_TIME = 2.5
-- Flèche dont la cible est morte pendant le vol : elle touche le monstre vivant le plus proche du point
-- d'impact s'il est à moins de ce rayon (en studs), sinon elle est perdue (mais enflamme quand même le sol).
IdleTowers.PROJECTILE_CATCH_RADIUS = 1.5
-- Projectiles qui SUIVENT leur cible (Archer, Catapulte, Baliste). À l'impact, l'effet tombe sur la position
-- réelle de la cible si elle vit encore et qu'elle est à moins de (sa zone + cette marge) studs du point prévu
-- au tir (voir followDistance) ; sinon au point prévu. 6 : le monstre le plus rapide (13 studs/s) arrêté juste
-- après le tir perd au plus ~13 studs sur le plus long vol de la Catapulte (~1 s) : zone 7 + 6 = 13.
IdleTowers.PROJECTILE_FOLLOW_MARGIN = 6
-- Zones de feu actives au plus dans une zone de combat (toutes tours confondues) : au-delà, la plus vieille s'éteint.
IdleTowers.FIRE_MAX_PER_PLOT = 30
-- Baliste lourde (demande du propriétaire : « viser le plus gros monstre ok, mais si plusieurs monstres sont
-- pareils, essayer de faire la meilleure zone »). Parmi les monstres qu'elle peut viser, ceux qui ont au moins
-- BALLISTA_TIE_RATIO fois les PV du plus résistant sont « pareils » (0,85 : 85 % de ses PV ou plus) ; elle vise
-- celui dont le carreau en transpercera le PLUS. À nombre égal : le plus résistant. Un monstre bien plus
-- résistant que les autres reste donc toujours sa cible. Voir Combat:pickPierceTarget.
IdleTowers.BALLISTA_TIE_RATIO = 0.85
-- Nombre de « pareils » comparés au plus à chaque tir de Baliste (le plus résistant compris) : le calcul reste
-- léger même devant une foule d'écuyers qui ont tous les mêmes PV.
IdleTowers.BALLISTA_MAX_CANDIDATES = 12
-- Le carreau de la Baliste transperce AU PLUS ce nombre de monstres (décision du propriétaire : « transperce 3
-- max »). Sa cible est toujours touchée, plus les premiers monstres que le carreau rencontre sur sa ligne (les
-- plus proches de la tour). Voir Combat:hitLine et countPierced. Une tour peut avoir sa propre limite : pierceMax
-- (la Baliste du dragon, palier 2 : 4).
IdleTowers.BALLISTA_PIERCE_MAX = 3
-- LIMITE DE TOURS IDENTIQUES posées dans un niveau, selon la rareté de la tour (Levels.MAX_COPIES peut fixer une
-- autre limite pour une tour précise). Voir maxCopies.
IdleTowers.MAX_COPIES = { Common = 5, Rare = 4, Epic = 3, Legendary = 2 }

IdleTowers.Defs = {
	MachineGun = {
		rarity = "Common",
		displayName = "Archer du rempart",
		kind = "Single",
		targeting = "First",
		color = Color3.fromRGB(72, 126, 70),
		damage = 3,
		range = 21,
		cooldown = 0.2,
		projectileSpeed = 90, -- flèche rapide : ~0,1 à 0,25 s de vol
		-- Flèches enflammées (évolution ★ de l'Archer dans les niveaux, Levels.PERKS) : chaque flèche laisse au
		-- sol, là où elle tombe, une petite zone de feu qui brûle tous les monstres dedans. Dégâts du feu par
		-- seconde = fireDamageRatio x dégâts de la flèche, un coup toutes les fireTick s. Une flèche qui tombe
		-- dans une zone de la même tour la ravive (elle repart pour fireDuration s) au lieu d'en créer une autre ;
		-- fireMaxPatches zones par tour au plus (la plus vieille s'éteint).
		fireRadius = 2.5,
		fireDuration = 2,
		fireDamageRatio = 0.4,
		fireTick = 0.5,
		fireMaxPatches = 5,
	},
	Frost = {
		rarity = "Common",
		displayName = "Totem de givre",
		kind = "Aura",
		color = Color3.fromRGB(150, 230, 255),
		-- Tour de CONTRÔLE d'abord : elle touche tous les monstres proches à chaque impulsion, mais ses dégâts
		-- restent faibles. Sa force vient de la fragilité, qui renforce les AUTRES tours.
		damage = 2,
		range = 11,
		cooldown = 1,
		-- Ralentissement (dans un niveau : Levels.TOWER_TWEAKS le règle à -40 %). Dure 2,5 s : plus que le temps
		-- entre deux impulsions (1 s), donc un monstre dans l'aura reste ralenti tout le temps, et encore un peu
		-- après. C'est un CONTRÔLE : un seul à la fois par monstre ; deux Totems ne s'additionnent pas.
		slow = 0.6,
		slowDuration = 2.5,
		-- FRAGILITÉ : les monstres dans l'aura prennent +X % de dégâts de TOUTES les AUTRES tours sauf le Mage des
		-- tempêtes. X monte avec le niveau du Totem :
		--   X = min(fragilityMax, fragilityBase + fragilityPerLevel x (niveau - 1))
		-- Deux Totems ne s'additionnent pas : le plus fort gagne. Elle suit l'aura : elle dure encore
		-- fragilityDuration s après la sortie (comme le ralentissement).
		fragilityBase = 0.1,
		fragilityPerLevel = 0.02,
		fragilityMax = 3,
		fragilityDuration = 2.5,
		-- Les dégâts des Totems ne profitent pas de la fragilité (ni la sienne, ni celle d'un autre Totem).
		ignoresFragility = true,
	},
	Bomb = {
		rarity = "Rare",
		displayName = "Catapulte",
		kind = "Splash",
		targeting = "First",
		color = Color3.fromRGB(240, 130, 50),
		damage = 17,
		range = 14,
		cooldown = 1.8,
		splash = 7,
		-- Tir en cloche : vol = distance / 24 studs par seconde, 0,45 s au moins (~0,45 à 0,65 s).
		projectileSpeed = 24,
		projectileMinFlight = 0.45,
	},
	Tesla = {
		rarity = "Rare",
		displayName = "Mage des tempêtes",
		-- La foudre tombe tout de suite (pas de projectile) sur le monstre de tête, et touche aussi ceux
		-- qui sont collés à lui : tous prennent les dégâts ET le ralentissement (s'ils ne subissent pas déjà
		-- le contrôle d'une autre tour, voir « CONTRÔLES » plus haut).
		kind = "Splash",
		targeting = "First",
		color = Color3.fromRGB(250, 230, 80),
		damage = 10,
		range = 16,
		cooldown = 0.8,
		splash = 3, -- petite zone : moins de la moitié de la Catapulte (7)
		-- Ralentissement COURT mais bien plus fort que celui du Totem : le joueur choisit entre le Totem et le
		-- Mage, ils ne se cumulent pas (un seul contrôle à la fois).
		slow = 0.9,
		slowDuration = 0.6,
		-- FATIGUE : un éclair ne prolonge jamais un ralentissement du Mage en cours, et quand il se termine, le
		-- monstre est immunisé contre les ralentissements du Mage pendant slowImmunity secondes (les dégâts
		-- tombent toujours). Donc 0,6 s ralenti sur 1,4 s au plus, quel que soit le nombre de Mages. Durée +
		-- immunité = 1,4 s, exprès pas un multiple de 0,8 s (le temps entre deux éclairs).
		slowImmunity = 0.8,
		-- Ses dégâts ne profitent pas de la fragilité du Totem de givre (pas de synergie Givre + Mage).
		ignoresFragility = true,
	},
	Rocket = {
		rarity = "Epic",
		displayName = "Baliste lourde",
		-- Carreau PERÇANT : la Baliste vise le monstre le plus résistant, mais à l'impact, les monstres à moins de
		-- pierceWidth studs du segment tour -> point d'impact prennent aussi les dégâts, BALLISTA_PIERCE_MAX au
		-- plus (3) : sa cible (touchée même si un ralentissement l'a fait dévier) et les premiers que le carreau
		-- rencontre.
		kind = "Pierce",
		targeting = "Strongest",
		color = Color3.fromRGB(200, 60, 60),
		-- RENFORCÉE (accord du propriétaire, 02/10/2026) : 120 dégâts au lieu de 50. Mesuré avec le joueur simulé
		-- (tools\levels\run.ps1 -Worth) : à 50, l'avoir ne permettait de battre des monstres plus résistants qu'au
		-- niveau 10 (+19 %, rien aux niveaux 6 et 8) ; à 120 : +20 %, +23 % et +59 % aux niveaux 6, 8 et 10, comme le
		-- Sorcier des arcanes (l'autre tour épique).
		damage = 120,
		range = 30,
		cooldown = 4, -- tire rarement : excellente contre les gros
		pierceWidth = 1.25, -- demi-largeur du carreau perçant, en studs
		projectileSpeed = 75, -- carreau lourd, tir tendu : ~0,15 à 0,45 s de vol
	},
	Laser = {
		rarity = "Epic",
		displayName = "Sorcier des arcanes",
		-- Rayon continu : il s'accroche au monstre le plus résistant à portée et le GARDE tant qu'il est
		-- vivant et à portée (il ne change jamais de cible pour un monstre plus fort : ça remettrait la
		-- montée à zéro). Dégâts par seconde = damage x montée, montée = min(beamRampMax, 1 + beamRampRate x
		-- secondes sur cette cible), à chaque pas de simulation. Les monstres lents (boss, colosses, chevaliers
		-- lourds, monstres gelés par le Totem) restent assez longtemps pour prendre la montée entière ; les
		-- cavaliers traversent sa portée avant qu'il chauffe. Il est plus fort dans un virage du chemin, où
		-- la cible reste longtemps à portée.
		kind = "Beam",
		targeting = "Strongest", -- seulement pour choisir une nouvelle cible
		color = Color3.fromRGB(255, 70, 200),
		damage = 7, -- dégâts PAR SECONDE au début du rayon (montée x1)
		range = 14,
		beamRampRate = 2, -- +2 par seconde sur la même cible
		beamRampMax = 25, -- x25 au plus, atteint après 12 s sur la même cible
	},
	Chain = {
		rarity = "Legendary",
		displayName = "Oracle de la foudre",
		kind = "Chain",
		targeting = "First",
		color = Color3.fromRGB(150, 110, 255),
		damage = 60, -- par monstre touché (4 monstres par éclair)
		range = 20,
		cooldown = 1.2,
		chains = 4,
	},
	Orbital = {
		rarity = "Legendary",
		displayName = "Trébuchet royal",
		-- Vise le point du chemin où sa GRANDE zone touchera le plus de monstres (positions prévues à l'arrivée
		-- de la pierre ; à égalité, le groupe le plus avancé), partout à portée (70 : tout le chemin). Contre un
		-- boss seul, elle est faible, exprès.
		kind = "Splash",
		targeting = "Crowd",
		color = Color3.fromRGB(120, 240, 255),
		-- RENFORCÉ (accord du propriétaire, 02/10/2026) : 100 dégâts au lieu de 35, étourdissement de 1 s au lieu de
		-- 0,5 s (immunité 2 s au lieu de 1,5 s : un monstre reste arrêté au plus 1 s sur 3). Mesuré avec le joueur
		-- simulé (tools\levels\run.ps1 -Worth) : avant, l'avoir apportait +12 %, 0 et +12 % aux niveaux 6, 8 et 10 ;
		-- maintenant +55 %, +34 % et +46 % : un peu plus que l'Oracle de la foudre (+47 %, +42 %, +29 %), l'autre
		-- tour légendaire, qui coûte deux fois moins cher à la boutique.
		damage = 100,
		range = 70,
		cooldown = 5,
		splash = 10, -- grande zone (la Catapulte : 7)
		-- Étourdit (vitesse 0) tous les monstres de la zone pendant stunDuration s. C'est un CONTRÔLE : refusé
		-- sur un monstre déjà ralenti par une autre tour (les dégâts, eux, tombent toujours).
		stunDuration = 1,
		-- FATIGUE (comme le Mage) : une pierre ne prolonge jamais un étourdissement en cours, et quand il se
		-- termine, le monstre est immunisé contre les étourdissements pendant stunImmunity secondes.
		stunImmunity = 2,
		-- Grande cloche : vol = distance / 45 studs par seconde, 0,8 s au moins (~0,8 à 1,6 s).
		projectileSpeed = 45,
		projectileMinFlight = 0.8,
	},

	----------------------------------------------------------------------
	-- PALIER 2 : seulement dans les œufs. base = la tour de palier 1 dont c'est la version forte (même rareté). Les
	-- chiffres sont les miens (2,3 à 3,5 fois les dégâts par seconde de la tour de base, ses pouvoirs déjà là) : ils
	-- se règlent avec tools\levels\run.ps1 -Worth, comme ceux du palier 1.
	----------------------------------------------------------------------
	FireArcher = {
		base = "MachineGun",
		rarity = "Common",
		displayName = "Archer enflammé",
		kind = "Single",
		targeting = "First",
		color = Color3.fromRGB(232, 98, 38),
		-- L'Archer du rempart avec tous ses pouvoirs (flèches enflammées, longue-vue, tir rapide) et des flèches 2,3 fois
		-- plus fortes : ~2,7 fois ses dégâts par seconde, et un feu plus large qui dure plus longtemps.
		damage = 7,
		range = 24,
		cooldown = 0.17,
		projectileSpeed = 100,
		fireRadius = 3,
		fireDuration = 2.5,
		fireDamageRatio = 0.5,
		fireTick = 0.5,
		fireMaxPatches = 6,
	},
	BlizzardTotem = {
		base = "Frost",
		rarity = "Common",
		displayName = "Totem du blizzard",
		kind = "Aura",
		color = Color3.fromRGB(96, 178, 255),
		-- Le Totem de givre en bien plus fort : ralentit de 50 % (le Totem : 40 % dans un niveau), une aura plus grande,
		-- et une fragilité deux fois plus forte dès le début (+20 %, +3 % par niveau). Ses contrôles comptent comme ceux
		-- du Totem de givre (Combat.luau : un seul ralentissement à la fois, le plus fort des deux).
		damage = 6,
		range = 13,
		cooldown = 1,
		slow = 0.5,
		slowDuration = 2.5,
		fragilityBase = 0.2,
		fragilityPerLevel = 0.03,
		fragilityMax = 3,
		fragilityDuration = 2.5,
		ignoresFragility = true,
	},
	MagmaCatapult = {
		base = "Bomb",
		rarity = "Rare",
		displayName = "Catapulte de magma",
		kind = "Splash",
		targeting = "First",
		color = Color3.fromRGB(255, 92, 28),
		-- Rochers de magma : 2,5 fois les dégâts de la Catapulte, plus loin, une zone plus large, et le sol BRÛLE là où
		-- ils tombent (une zone de feu, comme les flèches enflammées).
		damage = 42,
		range = 17,
		cooldown = 1.6,
		splash = 8.5,
		projectileSpeed = 26,
		projectileMinFlight = 0.45,
		fireRadius = 4,
		fireDuration = 2,
		fireDamageRatio = 0.25,
		fireTick = 0.5,
		fireMaxPatches = 3,
	},
	StormArchmage = {
		base = "Tesla",
		rarity = "Rare",
		displayName = "Archimage des tempêtes",
		kind = "Splash",
		targeting = "First",
		color = Color3.fromRGB(140, 228, 255),
		-- Le Mage des tempêtes en bien plus fort : 2,6 fois ses dégâts, zone et portée plus grandes, éclairs plus
		-- rapides. Ses ralentissements comptent comme ceux du Mage (même fatigue, voir « CONTRÔLES »).
		damage = 26,
		range = 19,
		cooldown = 0.7,
		splash = 4,
		slow = 0.9,
		slowDuration = 0.7,
		slowImmunity = 0.8,
		ignoresFragility = true,
	},
	DragonBallista = {
		base = "Rocket",
		rarity = "Epic",
		displayName = "Baliste du dragon",
		kind = "Pierce",
		targeting = "Strongest",
		color = Color3.fromRGB(224, 44, 58),
		-- Un carreau de 300 (la Baliste lourde : 120) qui transperce jusqu'à 4 monstres (pierceMax ; la Baliste : 3) et
		-- enflamme le sol là où il arrive.
		damage = 300,
		range = 35,
		cooldown = 3.4,
		pierceWidth = 1.5,
		pierceMax = 4,
		projectileSpeed = 85,
		fireRadius = 3,
		fireDuration = 3,
		fireDamageRatio = 0.1,
		fireTick = 0.5,
		fireMaxPatches = 2,
	},
	VoidSorcerer = {
		base = "Laser",
		rarity = "Epic",
		displayName = "Sorcier du néant",
		kind = "Beam",
		targeting = "Strongest",
		color = Color3.fromRGB(134, 58, 255),
		-- Rayon du néant : 2,3 fois le Sorcier des arcanes au départ, il chauffe plus vite (+3 par seconde) et monte plus
		-- haut (x30).
		damage = 16,
		range = 17,
		beamRampRate = 3,
		beamRampMax = 30,
	},
	ThunderOracle = {
		base = "Chain",
		rarity = "Legendary",
		displayName = "Oracle du tonnerre",
		kind = "Chain",
		targeting = "First",
		color = Color3.fromRGB(86, 146, 255),
		-- Un éclair de 130 (l'Oracle de la foudre : 60) qui rebondit sur 6 monstres (l'Oracle : 4).
		damage = 130,
		range = 23,
		cooldown = 1.1,
		chains = 6,
	},
	CelestialTrebuchet = {
		base = "Orbital",
		rarity = "Legendary",
		displayName = "Trébuchet céleste",
		kind = "Splash",
		targeting = "Crowd",
		color = Color3.fromRGB(255, 226, 128),
		-- Une pierre céleste de 240 (le Trébuchet royal : 100), une zone plus grande (12), et un étourdissement plus long
		-- (1,3 s ; même fatigue que le Trébuchet royal : ses étourdissements comptent comme les siens).
		damage = 240,
		range = 70,
		cooldown = 4.5,
		splash = 12,
		stunDuration = 1.3,
		stunImmunity = 2,
		projectileSpeed = 45,
		projectileMinFlight = 0.8,
	},
}

-- Tour de palier 1 d'une tour (elle-même pour une tour de palier 1, ou un type inconnu). Une tour de palier 2 a les
-- effets, les sons et la silhouette de sa tour de base (Effects, PlotRenderer, IdleTowerModel), et ses contrôles
-- comptent comme les siens (stats.family, Combat.luau).
function IdleTowers.baseOf(towerType: string): string
	local def = IdleTowers.Defs[towerType]
	return (def and def.base) or towerType
end

-- Palier d'une tour : 1 (départ, boutique) ou 2 (œufs).
function IdleTowers.tierOf(towerType: string): number
	local def = IdleTowers.Defs[towerType]
	return if def and def.base then 2 else 1
end

-- La version de palier 2 d'une tour de palier 1 (nil s'il n'y en a pas).
function IdleTowers.upgradeOf(towerType: string): string?
	for _, other in IdleTowers.TIER2 do
		if IdleTowers.Defs[other].base == towerType then
			return other
		end
	end
	return nil
end

local statsCache = {}

-- Fragilité donnée par une tour à ce niveau (0 si elle n'en donne pas) : +0,1 = +10 % de dégâts reçus.
--   min(fragilityMax, fragilityBase + fragilityPerLevel x (niveau - 1)), toujours un nombre fini.
function IdleTowers.fragilityAt(def, level: number): number
	if not def.fragilityBase then
		return 0
	end
	local steps = math.max(0, (tonumber(level) or 1) - 1)
	return math.clamp(def.fragilityBase + def.fragilityPerLevel * steps, 0, def.fragilityMax)
end

-- Stats d'une tour à un niveau donné (dégâts multipliés par le niveau : IdleConfig.UPGRADE_DAMAGE). En plus des
-- champs de sa définition : towerType (sa clé, ex. "Frost"), family (sa tour de palier 1, baseOf : la règle des
-- contrôles compare les familles, un Totem du blizzard compte comme un Totem de givre), level, et fragility (Totem
-- de givre, voir fragilityAt). Le tableau renvoyé ne doit jamais être modifié (il est partagé) : Levels.towerStats en
-- fait une copie avant d'y ajouter l'entraînement et les évolutions.
function IdleTowers.stats(towerType: string, level: number)
	local key = towerType .. ":" .. level
	local cached = statsCache[key]
	if cached then
		return cached
	end
	local def = IdleTowers.Defs[towerType]
	local stats = table.clone(def)
	stats.towerType = towerType
	stats.family = def.base or towerType
	stats.level = level
	stats.damage = def.damage * IdleConfig.UPGRADE_DAMAGE ^ (level - 1)
	if def.fragilityBase then
		stats.fragility = IdleTowers.fragilityAt(def, level)
	end
	statsCache[key] = stats
	return stats
end

-- Dégâts par seconde sur UNE cible (une Foudre en chaîne compte ses 4 cibles). Les tours de zone (Catapulte,
-- Mage, Trébuchet), la Baliste perçante et le Totem (aura) touchent souvent plusieurs monstres à chaque coup :
-- ce n'est pas compté ici. Rayon continu : au début (x1). Le feu des flèches n'est pas compté (voir fireDps),
-- la fragilité du Totem non plus (elle renforce les autres tours). Toujours un nombre fini.
function IdleTowers.dpsOf(stats): number
	if stats.kind == "Beam" then
		return stats.damage
	end
	return stats.damage * (stats.chains or 1) / stats.cooldown
end

----------------------------------------------------------------------
-- Rayon continu (Sorcier des arcanes)
----------------------------------------------------------------------

-- Multiplicateur de dégâts après `seconds` secondes sur la même cible : 1 au début, puis +beamRampRate
-- par seconde, jamais plus de beamRampMax.
function IdleTowers.beamRamp(stats, seconds: number): number
	return math.min(stats.beamRampMax, 1 + stats.beamRampRate * math.max(0, seconds))
end

----------------------------------------------------------------------
-- Projectiles et flèches enflammées
----------------------------------------------------------------------

-- Vrai si la tour lance un projectile (dégâts à l'impact) ; faux si elle touche tout de suite.
function IdleTowers.isProjectile(stats): boolean
	return stats.projectileSpeed ~= nil
end

-- Temps de vol, en secondes de simulation, jusqu'à un point à `distance` studs du haut de la tour.
function IdleTowers.flightTime(stats, distance: number): number
	local flight = math.max(stats.projectileMinFlight or 0, distance / stats.projectileSpeed)
	return math.clamp(flight, 0.05, IdleTowers.MAX_FLIGHT_TIME)
end

-- Vrai si le projectile de la tour SUIT sa cible (Archer, Catapulte, Baliste) : à l'impact, l'effet tombe là où
-- la cible est vraiment (voir followDistance). Faux pour les tirs instantanés et pour le Trébuchet royal
-- (« Crowd » : il vise le point de la foule, pas un monstre).
function IdleTowers.followsTarget(stats): boolean
	return stats.projectileSpeed ~= nil and stats.targeting ~= "Crowd"
end

-- Distance (en studs, à plat) jusqu'à laquelle un projectile suit sa cible : si, à l'impact, elle est plus loin
-- que ça du point prévu au tir, l'effet tombe au point prévu. = sa zone (rayon de la Catapulte, rayon du feu de
-- l'Archer, demi-largeur du carreau de la Baliste) + PROJECTILE_FOLLOW_MARGIN. Même règle pour le serveur
-- (impactCenter dans Combat.luau) et l'affichage (PlotRenderer).
function IdleTowers.followDistance(stats): number
	return math.max(stats.splash or 0, stats.fireRadius or 0, stats.pierceWidth or 0) + IdleTowers.PROJECTILE_FOLLOW_MARGIN
end

-- Dégâts par seconde d'une zone de feu (0 si la tour n'a pas de flèches enflammées).
function IdleTowers.fireDps(stats): number
	return if stats.fireRadius then stats.damage * stats.fireDamageRatio else 0
end

----------------------------------------------------------------------
-- Limite de tours identiques (MAX_COPIES, voir en haut du fichier)
----------------------------------------------------------------------

-- Nombre maximal d'exemplaires de cette tour, selon sa rareté : 5 (Commune), 4 (Rare), 3 (Épique), 2 (Légendaire).
function IdleTowers.maxCopies(towerType: string): number
	local def = IdleTowers.Defs[towerType]
	return (def and IdleTowers.MAX_COPIES[def.rarity]) or math.huge
end

-- Nombre de tours posées de chaque type : { [type] = nombre }. towers = n'importe quelle table dont les valeurs sont
-- des types de tours ("Frost") ou des tours avec un champ type ({ type = "Frost", ... }).
function IdleTowers.countCopies(towers): { [string]: number }
	local counts = {}
	for _, tower in towers or {} do
		local towerType = if type(tower) == "string" then tower elseif type(tower) == "table" then tower.type else nil
		if type(towerType) == "string" then
			counts[towerType] = (counts[towerType] or 0) + 1
		end
	end
	return counts
end

return IdleTowers

-- LES RÉGLAGES DU JEU « MONDE » : un monde ouvert fait de zones à thème. Dans chaque zone, des monstres (les animaux
-- sauvages de la zone) à combattre à l'épée, avec ses trois familiers. Ils donnent des pièces, de l'XP et des œufs.
-- Battre le boss d'une zone ouvre la suivante.
--
-- Ce qui rend le joueur plus fort (il n'y a plus de machines) :
--   son NIVEAU, qui monte avec l'XP des monstres (plus de vie, un peu plus de dégâts) ;
--   son ÉPÉE, améliorée avec des pièces à la forge (le gros des dégâts) ;
--   ses 3 FAMILIERS, qui frappent avec lui (plus ils valent cher, plus ils tapent fort).
local Config = {}

Config.WALK_SPEED = 22
Config.JUMP_HEIGHT = 7.5

-- LES ZONES, dans l'ordre. theme : le décor (Zones.luau). Les animaux d'une zone sont ceux de sa collection
-- (Pets.COLLECTIONS, même numéro) : les cinq premiers sont ses monstres, le sixième (le super rare) est son boss.
Config.ZONES = {
	{ theme = "Farm" },
	{ theme = "Forest" },
	{ theme = "Jungle" },
	{ theme = "Savanna" },
	{ theme = "Dino" },
}
Config.ZONE_SIZE = Vector3.new(300, 0, 300) -- largeur (X) et longueur (Z) d'une zone

-- LES MONSTRES. Par rang (1 à 5, puis 6 = le boss), dans la zone 1 :
Config.MONSTER = {
	-- (Retour du joueur, 07/10/2026 : « trop facile, je détruis les cochons alors que je suis niveau 2 avec juste
	-- un canard ». Chaque camp est maintenant bien plus solide et tape bien plus fort que le précédent.)
	-- LA RÈGLE (sa demande : « calcule sur 3 animaux, les gens se battront avec 3 animaux ») : un monstre de rang r
	-- est fait pour une équipe de TROIS familiers de ce rang, qui le battent en une dizaine de secondes pendant
	-- qu'il met environ 8 secondes à en coucher un. Avec des familiers d'un rang en dessous, c'est perdu : ils ne
	-- lui font presque rien et il les couche en deux coups.
	-- EXCEPTION, le premier camp (le canard) : on commence SANS familier, il doit donc se battre seul, à l'épée
	-- (40 de vie = une dizaine de secondes, et il enlève peu de vie au joueur).
	-- LE BOSS (sa règle) : il donne beaucoup, mais il reste PLUS FACILE que les premiers monstres du monde suivant.
	-- (08/10, sa demande : « modifie les valeurs de tout par 10, coûts et pièces gagnées, que t'aies vite l'impression
	-- d'avoir beaucoup de sous ; et dégâts aussi, santé ». TOUT est multiplié par 10 : la vie et les dégâts des
	-- monstres, des familiers, du joueur et des épées, les pièces et les prix. L'équilibre ne change pas.)
	hp = { 400, 3000, 7000, 15000, 32000, 90000 },
	damage = { 30, 150, 300, 600, 1250, 4000 },
	-- (Dans les mondes suivants, le premier camp n'a pas l'exception du canard : il suit l'échelle normale.)
	first = { hp = 1000, damage = 70 }, -- ce qu'un coup du monstre enlève (à un familier d'abord, au joueur en dernier)
	-- (Le boss revient en 3 secondes : il paie a peine plus qu une chevre, sinon le farmer en boucle au monde 1
	-- paierait l epee 4 en une heure et l argent ne serait plus un verrou.)
	-- (Le COMBAT paie quatre fois plus qu'avant, et l'enclos deux fois moins (Pets.INCOME) : sa demande du 08/10,
	-- « que ce soit plus lucratif, le farm ». Simulation : les trois quarts des pièces du monde 1 viennent du combat,
	-- contre un quart avant. Puis x 10 comme tout le reste.)
	coins = { 120, 320, 800, 2000, 5200, 8000 },
	-- (Son constat : « avec mes coqs niveau 7, j XP mieux au canard qu ailleurs ». L XP suit maintenant la solidite
	-- du monstre : le camp le plus fort qu on peut battre est toujours celui qui rapporte le plus d XP a la minute.)
	xp = { 4, 26, 60, 125, 260, 600 },
	-- Chance de lâcher SON œuf (un canard lâche un œuf de canard, un cochon un œuf de cochon...) : forte pour le
	-- canard, de plus en plus faible ensuite. La chance d'œuf rare du joueur la multiplie.
	-- (Le boss revient en 3 secondes : 2 % d'œuf suffisent, son familier est le plus fort du monde.)
	-- (Son choix du 07/10 au soir : 5 % pour TOUS les animaux sauf le canard, dans tous les mondes. La duree des
	-- mondes est tenue par l XP des familiers et le prix des epees, plus par la rarete des oeufs.)
	egg = { 0.20, 0.05, 0.05, 0.05, 0.05, 0.05 },
	-- (Les cinq camps grossis une fois et demie le 08/10, sa demande ; le boss reste à 4,5.)
	scale = { 2.25, 2.55, 2.85, 3.3, 3.75, 4.5 }, -- grosseur du modèle (un familier fait 1)
	speed = { 11, 12, 13, 14, 15, 13 },
}
-- D'une zone à la suivante : vie et dégâts x HP_ZONE, pièces x COIN_ZONE (comme la valeur des familiers), XP x XP_ZONE.
-- UN VRAI PALIER ENTRE DEUX MONDES (sa règle : « un vrai step entre chaque monde, t'es obligé de beaucoup farmer,
-- pas de monde 2 avant 3 heures de jeu minimum ») : les monstres du monde suivant sont 100 fois plus solides et
-- tapent 100 fois plus fort. Son premier camp est déjà plus dur que le boss du monde d'avant.
Config.HP_ZONE = 100
Config.DAMAGE_ZONE = 100
Config.COIN_ZONE = 100 -- (comme le reste : les pièces du monde 1 ne pèsent presque rien dans le monde 2)
Config.XP_ZONE = 10
-- Chaque monde dure plus longtemps que le precedent : les oeufs y sont LONG_EGG fois plus rares (et l XP des
-- familiers plus longue : Pets.LONG_XP). Simulation : monde 1 environ 3,5 heures, monde 2 environ 8 heures, monde 3 environ 10 heures.
-- Par monde : { monde 1, monde 2, monde 3 } ; ensuite le dernier chiffre, x 1,2 a chaque monde.
-- (Monde 1 : les œufs tombent une fois et demie plus souvent, pour un début rapide.)
Config.LONG_EGG = { 1 / 1.5, 1, 1 }
function Config.longEgg(zone: number): number
	local last = #Config.LONG_EGG
	return if zone <= last then Config.LONG_EGG[math.max(1, zone)] else Config.LONG_EGG[last]
end
-- Les epees d un monde au-dela de la table coutent 100 x LONG_PRICE fois celles du monde d avant.
Config.LONG_PRICE = 1.25
Config.RESPAWN = 2 -- secondes avant qu'un monstre revienne (son choix : 2 s, 3 s pour le boss : « si y a du monde ça sera rapide »)
Config.BOSS_RESPAWN = 3
Config.AGGRO = 22 -- distance à laquelle un monstre voit le joueur
Config.LEASH = 45 -- il abandonne au-delà de cette distance de chez lui
Config.RESET = 32 -- le joueur s'éloigne à plus de cette distance : le monstre abandonne, rentre et retrouve toute sa vie
Config.MONSTER_REACH = 5.5
Config.MONSTER_COOLDOWN = 1.3

-- LE NIVEAU AFFICHE DES MONSTRES suit celui du joueur (sa demande : « calculer mon niveau pour qu il soit coherent
-- au niveau des monstres que j affronte »). C est le niveau que le joueur a, dans la simulation
-- (tools/balance/mondes.py), au moment ou il devient capable de battre ce camp : il arrive donc devant des monstres
-- de son niveau, et le camp suivant est quelques niveaux au-dessus. { camps 1 a 5, puis le boss }, par monde.
-- (Si on change Config.xpNeed ou la difficulte, il faut refaire ce tableau.)
Config.LEVELS = {
	{ 1, 3, 6, 8, 13, 22 },
	{ 24, 25, 27, 32, 38, 53 },
	{ 56, 57, 59, 66, 74, 95 },
}
function Config.monsterLevel(zone: number, rank: number): number
	local last = #Config.LEVELS
	local row = Config.LEVELS[math.clamp(zone, 1, last)]
	-- (Au-dela du dernier monde regle : 42 niveaux de plus par monde.)
	return row[math.clamp(rank, 1, 6)] + math.max(0, zone - last) * 42
end
function Config.monster(zone: number, rank: number)
	local m = Config.MONSTER
	local hp, damage = m.hp[rank], m.damage[rank]
	if rank == 1 and zone > 1 then
		hp, damage = m.first.hp, m.first.damage
	end
	return {
		hp = math.floor(hp * Config.HP_ZONE ^ (zone - 1) + 0.5),
		damage = math.floor(damage * Config.DAMAGE_ZONE ^ (zone - 1) + 0.5),
		coins = math.floor(m.coins[rank] * Config.COIN_ZONE ^ (zone - 1) + 0.5),
		xp = math.floor(m.xp[rank] * Config.XP_ZONE ^ (zone - 1) + 0.5),
		egg = m.egg[rank] / Config.longEgg(zone),
		scale = m.scale[rank],
		speed = m.speed[rank],
		level = Config.monsterLevel(zone, rank),
	}
end

-- LES COFFRES : quelques-uns dans chaque zone. On les ouvre à coups d'épée ; ils ne se défendent pas et donnent
-- beaucoup de pièces, et souvent un œuf. Ils reviennent au bout de CHEST_RESPAWN secondes.
Config.CHEST = { hp = 500, coins = 150, xp = 30, egg = 0.4 }
Config.CHEST_RESPAWN = 75
function Config.chest(zone: number)
	local c = Config.CHEST
	return {
		hp = math.floor(c.hp * Config.HP_ZONE ^ (zone - 1) + 0.5),
		damage = 0,
		coins = math.floor(c.coins * Config.COIN_ZONE ^ (zone - 1) + 0.5),
		xp = math.floor(c.xp * Config.XP_ZONE ^ (zone - 1) + 0.5),
		egg = c.egg,
		scale = 1.6,
		speed = 0,
		level = Config.monsterLevel(zone, 3),
	}
end

-- LE JOUEUR.
Config.REGEN = 0.12 -- hors combat : part de sa vie que le joueur regagne chaque seconde
Config.REGEN_DELAY = 3 -- secondes sans combat avant que cette regeneration commence
Config.ATTACK_COOLDOWN = 0.42 -- secondes entre deux coups d'épée
-- Portee de l epee, comptee depuis le bord du monstre : la longueur du bras et de la lame, pas plus. Il faut un vrai
-- contact (retour du joueur : « je tape dans le vide devant le monstre qui est trop eloigne et ca touche »).
-- (7 depuis que les epees sont enormes : 8,3 studs de long, dont 7 de lame devant la main.)
Config.ATTACK_REACH = 7
Config.TEAM = 3 -- familiers qui se battent avec le joueur
Config.PET_REACH = 26 -- les familiers attaquent un monstre jusqu'à cette distance du joueur

-- XP qu'il faut pour passer du niveau `level` au suivant.
function Config.xpNeed(level: number): number
	-- (x 1,03 par niveau en plus : sans ca, le joueur prenait des dizaines de niveaux par monde et finissait avec
	-- plus de vie que ses familiers. Il arrive vers le niveau 22 au premier boss, 53 au deuxieme, 95 au troisieme.)
	return math.floor(30 * level ^ 1.7 * 1.03 ^ (level - 1))
end
function Config.maxHealth(level: number): number
	return math.floor(1000 * 1.1 ^ (level - 1))
end
-- LES ÉPÉES. Rien n'est verrouillé : on peut acheter la suivante dès qu'on a les pièces. C'est LE PRIX qui sert de
-- verrou (sa règle : « je veux pas que ça soit verrouillé mais que l'argent soit un verrou justement »).
-- CINQ épées au monde 1, puis TROIS par monde. Chaque épée tape environ 3,2 fois plus fort que celle d'avant (sa
-- règle). Le monde 1 en a cinq pour donner des achats rapprochés au début (sa demande du 08/10 : « je veux des
-- objectifs atteignables rapidement au début, que ça stimule à pas quitter ») : 2 min, 14 min, 37 min, puis le boss.
--   damage : dégâts d'un coup (deux coups par seconde environ). Calculé sur la progression simulée
--   (tools/balance/mondes.py) : à l'achat, le joueur tape à peu près comme ses trois familiers réunis ; puis ses
--   familiers progressent et chacun finit par le dépasser, jusqu'à l'épée suivante.
--   price : le prix pour l'obtenir. Les pièces valent 100 fois plus dans le monde suivant (COIN_ZONE) : l'épée 6
--   demanderait des heures de farm en plus au monde 1, et une demi-heure au monde 2.
Config.SWORDS = {
	{ damage = 30, price = 0 }, -- monde 1 : l'épée de départ (comme un canard)
	-- (La deuxième épée sert de TUTORIEL, sa demande : 30 pièces, soit une dizaine de canards.)
	{ damage = 80, price = 300 }, -- monde 1, après une minute
	{ damage = 250, price = 15000 }, -- monde 1, vers 9 minutes
	{ damage = 780, price = 150000 }, -- monde 1, vers 27 minutes
	{ damage = 2500, price = 1000000 }, -- monde 1, juste avant le boss (vers 55 minutes)
	{ damage = 11600, price = 25000000 }, -- monde 2, après 2 heures
	{ damage = 54000, price = 100000000 }, -- monde 2, après 4 h 30
	{ damage = 250000, price = 250000000 }, -- monde 2, juste avant le boss (après 7 h 30)
}
Config.SWORD_PER_ZONE = 3
-- (Au-delà de la huitième : les trois mêmes marches que le monde 2, 100 fois plus haut à chaque monde.)
local function swordStep(sword: number)
	local worlds = math.max(0, math.ceil((sword - #Config.SWORDS) / Config.SWORD_PER_ZONE))
	return Config.SWORDS[sword - worlds * Config.SWORD_PER_ZONE], 100 ^ worlds
end
-- (Plus de plafond : gardé pour l'écran, qui n'affiche donc jamais « MAX ».)
function Config.swordMax(_zone: number): number
	return math.huge
end
-- QUI DONNE QUOI (la règle du joueur) : monter de niveau SOI-MÊME = plus de vie, rien d'autre ; monter son ÉPÉE =
-- plus de dégâts pour soi ; monter le niveau d'un FAMILIER = ses dégâts et sa vie.
function Config.swordDamage(sword: number): number
	local step, factor = swordStep(math.max(1, sword))
	return step.damage * factor
end
function Config.hitDamage(sword: number, level: number): number
	local _ = level
	return math.floor(Config.swordDamage(sword) + 0.5)
end
-- Prix pour passer de l'épée `sword` à la suivante.
function Config.swordPrice(sword: number): number
	local step, factor = swordStep(sword + 1)
	local worlds = math.max(0, math.ceil((sword + 1 - #Config.SWORDS) / Config.SWORD_PER_ZONE))
	return step.price * factor * Config.LONG_PRICE ^ worlds
end
-- LES FAMILIERS AU COMBAT (leurs dégâts et leur vie : Pets.damageOf et Pets.healthOf). Les monstres s'en prennent
-- d'abord à eux, dans l'ordre de l'équipe, et au joueur en dernier.
-- Dès la fin du combat (jamais pendant), les familiers à terre se relèvent et toute l'équipe regagne PET_REGEN de
-- sa vie par seconde.
Config.PET_REGEN = 0.25
-- LE REVENU HORS LIGNE (sa règle du 08/10 : « un tiers du revenu pendant l'absence, soit 8 h max par jour ») :
-- quand le joueur revient, son enclos lui a rapporté OFFLINE_SHARE de ce qu'il rapporte en jeu, pendant toute son
-- absence, comptée jusqu'à OFFLINE_MAX secondes (24 h : au plus l'équivalent de 8 heures d'enclos par jour).
-- LE CADEAU DU TEMPS DE JEU (Rewards.luau) : un cadeau toutes les GIFT_EVERY secondes de jeu, dans cet ordre, puis on
-- recommence. coins = autant de pièces que ce nombre de monstres du camp du milieu de son monde ; egg = un œuf de
-- son monde, de ce rang (2 = peu commun, 4 = épique).
Config.GIFT_EVERY = 15 * 60
-- (Le tout premier cadeau d'un nouveau joueur arrive bien plus vite : il ouvre la fenêtre, et voit les suivants.)
Config.GIFT_FIRST = 150
-- (10/10, sa demande : « cadeau toutes les 15 mn mais limite 4 par jour », « pas d'œufs, que des potions, la 4e
-- le rang ». Ce sont les quatre cadeaux DU JOUR, dans cet ordre : le compte repart à zéro chaque jour (minuit UTC),
-- et après le quatrième il n'y en a plus jusqu'au lendemain.)
Config.GIFTS = { { potion = "coins" }, { potion = "xp" }, { potion = "damage" }, { potion = "rank" } }
-- LES POTIONS (sa demande du 09/10 : « une potion pour monter de rang (un rang de compagnon, A à S), une potion
-- double XP et une potion double argent, comme ça on pourra les vendre aussi en Robux, avec une potion double
-- dégâts »). Celles à durée s'additionnent : en boire une autre avant la fin rallonge le temps. (Potions.luau)
Config.POTIONS = {
	rank = {}, -- monte la NOTE d'un familier d'un cran (C → B → A → S) : Pets.raiseGrade
	xp = { mult = 2, seconds = 10 * 60 },
	coins = { mult = 2, seconds = 10 * 60 },
	damage = { mult = 2, seconds = 10 * 60 }, -- (pas dans les cadeaux : pour la boutique en Robux)
}
Config.POTION_ORDER = { "rank", "xp", "coins", "damage" }
-- LA BOUTIQUE EN ROBUX (Store.luau ; sa demande du 09/10 : « mettre dans la boutique les potions et XP x2, revenu
-- x2 » : les deux bonus sont À VIE, les potions durent un temps).
--   id : le numéro du pass ou du produit, créé par le créateur dans le tableau de bord de Roblox. 0 = pas encore
--        créé : l'article affiche « Bientôt » et ne peut pas être acheté.
--   robux : le prix affiché en attendant (le vrai prix est celui du tableau de bord : l'écran le relit chez Roblox).
--   passes : achetés une fois, pour toujours. coins = TOUTES les pièces (monstres, enclos, hors ligne) x PASS_MULT.
--   products : chaque achat donne `count` potions de cette sorte.
Config.STORE = {
	PASS_MULT = 2,
	-- (Ses prix du 09/10 : « x2 XP 199 et x2 argent 299, les potions à 10 sauf l'augmentation de note à 40 ».)
	passes = {
		-- (Ses numéros du 10/10/2026 : les pass « 2x XP » et « 2x Coins », les quatre produits des potions.)
		xp = { id = 2022266478, robux = 199 },
		coins = { id = 2024966437, robux = 299 },
	},
	products = {
		rank = { id = 3717474700, robux = 40, count = 1 },
		-- (Son choix du 09/10 : UNE potion par achat, 10 minutes, pas un lot de 3 : le « x3 » se confondait avec le x2.)
		xp = { id = 3717474831, robux = 10, count = 1 },
		coins = { id = 3717475499, robux = 10, count = 1 },
		damage = { id = 3717475723, robux = 10, count = 1 },
	},
}
Config.PASS_ORDER = { "xp", "coins" }
-- LES QUÊTES (Quests.luau) : pour chaque animal, trois quêtes à la suite. kills : les monstres à battre ; reward :
-- ce qu'elle donne. coins : autant de pièces que ce nombre de monstres du camp ; bossCoins : pareil pour la quête
-- du boss (en monstres du camp 5) ; potions : celles des quêtes « potion », à tour de rôle d'un camp à l'autre ;
-- grade : la note promise de l'œuf de la troisième quête (4 = S, sa demande : « rang S sur le cochon quand tu en
-- bats 30 »).
Config.QUESTS = {
	stages = { { kills = 10, reward = "coins" }, { kills = 20, reward = "potion" }, { kills = 30, reward = "egg" } },
	coins = 25, bossCoins = 50, potions = { "xp", "coins", "damage" }, grade = 4,
}
-- LES MONSTRES DORÉS (10/10, pour casser la répétition) : de temps en temps, un monstre d'un camp revient DORÉ, un
-- peu plus gros. chance : par retour d'un monstre (son chiffre : « sur 30 morts en moyenne ») ; coins : ses pièces
-- sont multipliées par ça ; hp : sa vie aussi (« deux fois plus dur à tuer »).
-- IL LÂCHE À COUP SÛR UN ŒUF DORÉ (« 100 % d'œuf doré, double stats avec animal doré ») : le familier qui en sort
-- est doré, et ses dégâts, sa vie, ses pièces par seconde et son prix de vente sont multipliés par Pets.GOLD.
-- (Pas d'XP en plus pour le monstre : c'est l'XP qui tient la durée des mondes.)
Config.GOLDEN = { chance = 1 / 30, coins = 10, hp = 2, scale = 1.25 }
-- LE CANARD DORÉ GÉANT (GoldenDuck.luau) : il apparaît dans l'allée de la base toutes les `every` secondes, l'alerte
-- passe `warn` secondes avant, et il reste `stay` secondes au plus.
--   hits : les coups qu'il faut (chaque coup compte pour 1), + hitsMore par joueur du serveur en plus du premier.
--   minHits : les coups à donner pour avoir la récompense.
--   LA RÉCOMPENSE (son choix du 10/10 : « full pièces, XP, rien d'autre, et suivant la progression du joueur ») :
--   coins et xp = autant de pièces et d'XP que ce nombre de monstres du CAMP LE PLUS FORT qu'il a déjà battu
--   (data.hz, data.hr). Pas d'œuf, pas de potion.
--   eggRadius / eggWarn : le rond des œufs qui tombent et le temps pour en sortir ; stompRadius / stompWarn : le
--   grand rond du coup de patte ; attackEvery : secondes entre deux attaques.
Config.DUCK = {
	every = 600, warn = 20, stay = 90,
	-- (Dans l'allée, entre la porte de l'aventure et la banderole : loin du point d'apparition et de la fontaine.)
	spot = Vector3.new(0, 0, -12), animal = "Duck", scale = 12,
	hits = 60, hitsMore = 40, hitsMax = 300,
	minHits = 10, coins = 15, xp = 15,
	-- (Son retour : « laisse un temps pour esquiver, hein » : 2,5 s pour sortir d'un rond d'œuf, 3,5 s pour le
	-- grand rond, et 6 s entre deux attaques.)
	eggRadius = 8, eggWarn = 2.5, stompRadius = 24, stompWarn = 3.5, attackEvery = 6, eggRange = 40,
}
-- LE MINI TUTORIEL des nouveaux joueurs (Tutorial.luau) : le nombre d'étapes.
Config.TUTORIAL_STEPS = 6
-- LES MONDES SONT TOUJOURS OUVERTS (sa demande du 09/10 : « ouvrir tous les mondes tout le temps permet de visiter ;
-- de toute manière ils ne géreront pas les monstres, à quoi bon les fermer »). Le monde CONQUIS (data.zone : le
-- dernier boss battu + 1) sert toujours pour la forge, les cadeaux et les œufs.
Config.FREE_TRAVEL = true
-- LES ÉVÉNEMENTS DE L'ADMIN (Admin.luau ; sa demande du 09/10 : « un mode uniquement pour moi, pour les admin
-- abuse ») : des bonus pour TOUS les joueurs de TOUS les serveurs, lancés par le créateur pour EVENT_MINUTES minutes.
-- mult : par combien c'est multiplié ; attr : l'attribut de workspace qui garde l'heure de fin (os.time).
--   coins : les pièces des monstres ; xp : l'XP des monstres ; eggs : la chance qu'un monstre lâche son œuf.
Config.EVENT = {
	coins = { mult = 2, attr = "EventCoinsUntil" },
	xp = { mult = 2, attr = "EventXpUntil" },
	eggs = { mult = 2, attr = "EventEggsUntil" },
}
Config.EVENT_ORDER = { "coins", "xp", "eggs" }
Config.EVENT_MINUTES = { 5, 15, 30 }
-- (Côté serveur.) Le multiplicateur du moment pour cette sorte : 1 quand aucun événement ne court.
function Config.eventMult(kind: string): number
	local def = Config.EVENT[kind]
	return if def and os.time() < (workspace:GetAttribute(def.attr) or 0) then def.mult else 1
end
-- LE BONUS D'AMIS : chaque ami Roblox dans le même serveur donne FRIEND_BONUS d'XP et de pièces de combat en plus,
-- jusqu'à FRIEND_MAX amis (sa règle : « + 10 % d'XP et de cash »).
-- LE BONUS « RESTE ENCORE » (Rewards.luau) : la première fois de la journée que le joueur ouvre le menu de Roblox
-- (pour partir), il reçoit STAY_XP d'XP en plus pendant STAY_SECONDS. Les fois suivantes : un simple au revoir.
Config.STAY_XP = 0.5
Config.STAY_SECONDS = 15 * 60
Config.FRIEND_BONUS = 0.10
Config.FRIEND_MAX = 3
Config.OFFLINE_SHARE = 1 / 3
Config.OFFLINE_MAX = 24 * 3600
Config.OFFLINE_MIN = 5 * 60 -- en dessous de cinq minutes d'absence : rien (un simple retour de connexion)
-- XP qu'il faut à un familier pour passer du niveau `level` au suivant.
function Config.petXpNeed(level: number): number
	return math.floor(15 * level ^ 1.6)
end
-- Tant qu'un familier tient debout, le monstre s'arrête à cette distance du joueur et frappe le familier.
Config.PET_GUARD = 13

return Config

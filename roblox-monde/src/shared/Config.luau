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
	hp = { 40, 300, 700, 1500, 3200, 9000 },
	damage = { 3, 15, 30, 60, 125, 400 },
	-- (Dans les mondes suivants, le premier camp n'a pas l'exception du canard : il suit l'échelle normale.)
	first = { hp = 100, damage = 7 }, -- ce qu'un coup du monstre enlève (à un familier d'abord, au joueur en dernier)
	coins = { 3, 8, 20, 50, 130, 2000 },
	xp = { 4, 10, 24, 55, 130, 600 },
	-- Chance de lâcher SON œuf (un canard lâche un œuf de canard, un cochon un œuf de cochon...) : forte pour le
	-- canard, de plus en plus faible ensuite. La chance d'œuf rare du joueur la multiplie.
	-- (Le boss revient en 3 secondes : 2 % d'œuf suffisent, son familier est le plus fort du monde.)
	egg = { 0.20, 0.05, 0.03, 0.02, 0.012, 0.02 },
	scale = { 1.5, 1.7, 1.9, 2.2, 2.5, 4.5 }, -- grosseur du modèle (un familier fait 1)
	speed = { 11, 12, 13, 14, 15, 13 },
}
-- D'une zone à la suivante : vie et dégâts x HP_ZONE, pièces x COIN_ZONE (comme la valeur des familiers), XP x XP_ZONE.
-- UN VRAI PALIER ENTRE DEUX MONDES (sa règle : « un vrai step entre chaque monde, t'es obligé de beaucoup farmer,
-- pas de monde 2 avant 3 heures de jeu minimum ») : les monstres du monde suivant sont 100 fois plus solides et
-- tapent 100 fois plus fort. Son premier camp est déjà plus dur que le boss du monde d'avant.
Config.HP_ZONE = 100
Config.DAMAGE_ZONE = 100
Config.COIN_ZONE = 10
Config.XP_ZONE = 10
Config.RESPAWN = 2 -- secondes avant qu'un monstre revienne (son choix : 2 s, 3 s pour le boss : « si y a du monde ça sera rapide »)
Config.BOSS_RESPAWN = 3
Config.AGGRO = 22 -- distance à laquelle un monstre voit le joueur
Config.LEASH = 45 -- il abandonne au-delà de cette distance de chez lui
Config.RESET = 32 -- le joueur s'éloigne à plus de cette distance : le monstre abandonne, rentre et retrouve toute sa vie
Config.MONSTER_REACH = 5.5
Config.MONSTER_COOLDOWN = 1.3

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
		egg = m.egg[rank],
		scale = m.scale[rank],
		speed = m.speed[rank],
		level = (zone - 1) * 10 + rank * 2 - 1,
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
		level = (zone - 1) * 10 + 5,
	}
end

-- LE JOUEUR.
Config.REGEN = 0.12 -- hors combat : part de sa vie que le joueur regagne chaque seconde
Config.REGEN_DELAY = 3 -- secondes sans combat avant que cette regeneration commence
Config.ATTACK_COOLDOWN = 0.42 -- secondes entre deux coups d'épée
Config.ATTACK_REACH = 10 -- portée de l'épée
Config.TEAM = 3 -- familiers qui se battent avec le joueur
Config.PET_REACH = 26 -- les familiers attaquent un monstre jusqu'à cette distance du joueur

-- XP qu'il faut pour passer du niveau `level` au suivant.
function Config.xpNeed(level: number): number
	return math.floor(30 * level ^ 1.7)
end
function Config.maxHealth(level: number): number
	return math.floor(100 * 1.1 ^ (level - 1))
end
-- L'ÉPÉE : chaque épée tape SWORD_STEP fois plus fort que la précédente. On ne peut en acheter que SWORD_PER_ZONE
-- par zone ouverte (battre un boss débloque les suivantes) : impossible de tout acheter d'un coup avec les pièces
-- de l'enclos. Prix : voir Config.swordPrice (8 000 puis 120 000 dans le monde 1).
-- (Ces prix, les chances d oeuf et l XP des familiers sont regles avec tools/balance/monde1.py pour qu un joueur
-- tres efficace mette environ 3 heures a battre le boss du monde 1.)
-- (Son choix : « moins d'evolutions mais plus de multiplicateur, x3,2 par epee ». Deux epees par zone = x10, comme
-- les monstres.)
Config.SWORD_PER_ZONE = 2 -- (son choix, confirme : « 2 epees par monde mais familiers qui ont du poids »)
-- (Sa demande : « calcule pour que mes familiers fassent chacun a peu pres mes degats ». Deux epees doivent
-- couvrir tout un monde, ou les familiers passent de 5 a 500 de degats : chaque epee tape donc 10 fois plus fort.
-- Epee 1 = un canard, epee 2 = un mouton, epee 3 = le familier du boss.)
Config.SWORD_STEP = 10
function Config.swordMax(zone: number): number
	return 1 + Config.SWORD_PER_ZONE * zone
end
-- QUI DONNE QUOI (la règle du joueur) : monter de niveau SOI-MÊME = plus de vie, rien d'autre ; monter son ÉPÉE =
-- plus de dégâts pour soi ; monter le niveau d'un FAMILIER = ses dégâts et sa vie.
function Config.swordDamage(sword: number): number
	-- (L'épée seule fait peu : la force vient surtout des trois familiers.)
	return 2.5 * Config.SWORD_STEP ^ (sword - 1)
end
function Config.hitDamage(sword: number, level: number): number
	local _ = level
	return math.floor(Config.swordDamage(sword) + 0.5)
end
-- Prix pour passer de l'épée `sword` à la suivante.
function Config.swordPrice(sword: number): number
	-- La premiere epee d un monde : 8 000 pieces (x 16 a chaque monde) ; la deuxieme : 15 fois plus.
	return math.floor(8000 * 16 ^ ((sword - 1) // 2) * (if (sword - 1) % 2 == 1 then 15 else 1))
end
-- LES FAMILIERS AU COMBAT (leurs dégâts et leur vie : Pets.damageOf et Pets.healthOf). Les monstres s'en prennent
-- d'abord à eux, dans l'ordre de l'équipe, et au joueur en dernier.
-- Dès la fin du combat (jamais pendant), les familiers à terre se relèvent et toute l'équipe regagne PET_REGEN de
-- sa vie par seconde.
Config.PET_REGEN = 0.25
-- XP qu'il faut à un familier pour passer du niveau `level` au suivant.
function Config.petXpNeed(level: number): number
	return math.floor(15 * level ^ 1.6)
end
-- Tant qu'un familier tient debout, le monstre s'arrête à cette distance du joueur et frappe le familier.
Config.PET_GUARD = 13

return Config

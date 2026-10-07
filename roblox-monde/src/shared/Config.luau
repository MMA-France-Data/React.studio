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
	hp = { 40, 300, 700, 1500, 3200, 12000 },
	damage = { 3, 15, 30, 60, 125, 300 }, -- ce qu'un coup du monstre enlève (à un familier d'abord, au joueur en dernier)
	coins = { 3, 8, 20, 50, 130, 2000 },
	xp = { 4, 10, 24, 55, 130, 600 },
	-- Chance de lâcher SON œuf (un canard lâche un œuf de canard, un cochon un œuf de cochon...) : forte pour le
	-- canard, de plus en plus faible ensuite. La chance d'œuf rare du joueur la multiplie.
	egg = { 0.25, 0.12, 0.08, 0.05, 0.03, 0.15 },
	scale = { 1.5, 1.7, 1.9, 2.2, 2.5, 4.5 }, -- grosseur du modèle (un familier fait 1)
	speed = { 11, 12, 13, 14, 15, 13 },
}
-- D'une zone à la suivante : vie et dégâts x HP_ZONE, pièces x COIN_ZONE (comme la valeur des familiers), XP x XP_ZONE.
Config.HP_ZONE = 10
Config.DAMAGE_ZONE = 10
Config.COIN_ZONE = 10
Config.XP_ZONE = 4
Config.RESPAWN = 6 -- secondes avant qu'un monstre revienne (le boss : BOSS_RESPAWN)
Config.BOSS_RESPAWN = 25
Config.AGGRO = 22 -- distance à laquelle un monstre voit le joueur
Config.LEASH = 45 -- il abandonne au-delà de cette distance de chez lui
Config.RESET = 32 -- le joueur s'éloigne à plus de cette distance : le monstre abandonne, rentre et retrouve toute sa vie
Config.MONSTER_REACH = 5.5
Config.MONSTER_COOLDOWN = 1.3

function Config.monster(zone: number, rank: number)
	local m = Config.MONSTER
	return {
		hp = math.floor(m.hp[rank] * Config.HP_ZONE ^ (zone - 1) + 0.5),
		damage = math.floor(m.damage[rank] * Config.DAMAGE_ZONE ^ (zone - 1) + 0.5),
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
-- L'ÉPÉE : +25 % de dégâts par niveau. Elle ne peut pas dépasser SWORD_PER_ZONE niveaux par zone ouverte (battre
-- un boss débloque les dix niveaux suivants) : on ne peut pas tout acheter d'un coup avec les pièces de l'enclos.
Config.SWORD_PER_ZONE = 10
function Config.swordMax(zone: number): number
	return Config.SWORD_PER_ZONE * zone
end
-- QUI DONNE QUOI (la règle du joueur) : monter de niveau SOI-MÊME = plus de vie, rien d'autre ; monter son ÉPÉE =
-- plus de dégâts pour soi ; monter le niveau d'un FAMILIER = ses dégâts et sa vie.
function Config.swordDamage(sword: number): number
	-- (L'épée seule fait peu : la force vient surtout des trois familiers.)
	return 3 * 1.25 ^ (sword - 1)
end
function Config.hitDamage(sword: number, level: number): number
	local _ = level
	return math.floor(Config.swordDamage(sword) + 0.5)
end
-- Prix pour passer de l'épée `sword` à la suivante.
function Config.swordPrice(sword: number): number
	return math.floor(40 * 1.45 ^ (sword - 1))
end
-- LES FAMILIERS AU COMBAT (leurs dégâts et leur vie : Pets.damageOf et Pets.healthOf). Les monstres s'en prennent
-- d'abord à eux, dans l'ordre de l'équipe, et au joueur en dernier.
Config.PET_REST = 5 -- secondes HORS COMBAT pour que les familiers se relèvent et se soignent (jamais pendant)
-- XP qu'il faut à un familier pour passer du niveau `level` au suivant.
function Config.petXpNeed(level: number): number
	return math.floor(15 * level ^ 1.6)
end
-- Tant qu'un familier tient debout, le monstre s'arrête à cette distance du joueur et frappe le familier.
Config.PET_GUARD = 13

return Config

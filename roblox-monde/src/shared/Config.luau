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
	hp = { 30, 60, 130, 300, 700, 6000 },
	damage = { 5, 8, 12, 18, 26, 40 }, -- ce qu'un coup du monstre enlève au joueur
	coins = { 3, 6, 14, 35, 90, 1500 },
	xp = { 4, 7, 12, 20, 35, 300 },
	egg = { 0.07, 0.08, 0.09, 0.11, 0.13, 1 }, -- chance de lâcher un œuf
	scale = { 1.5, 1.7, 1.9, 2.2, 2.5, 4.5 }, -- grosseur du modèle (un familier fait 1)
	speed = { 11, 12, 13, 14, 15, 13 },
}
-- D'une zone à la suivante : vie et dégâts x HP_ZONE, pièces x COIN_ZONE (comme la valeur des familiers), XP x XP_ZONE.
Config.HP_ZONE = 3.2
Config.DAMAGE_ZONE = 1.8
Config.COIN_ZONE = 10
Config.XP_ZONE = 3
Config.RESPAWN = 6 -- secondes avant qu'un monstre revienne (le boss : BOSS_RESPAWN)
Config.BOSS_RESPAWN = 25
Config.AGGRO = 22 -- distance à laquelle un monstre voit le joueur
Config.LEASH = 70 -- il abandonne au-delà de cette distance de chez lui
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
Config.CHEST = { hp = 220, coins = 120, xp = 15, egg = 0.4 }
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
	return 100 + 20 * (level - 1)
end
-- Dégâts d'un coup d'épée : l'épée, plus 6 % par niveau du joueur.
function Config.swordDamage(sword: number): number
	return 6 * 1.3 ^ (sword - 1)
end
function Config.hitDamage(sword: number, level: number): number
	return math.floor(Config.swordDamage(sword) * (1 + 0.06 * (level - 1)) + 0.5)
end
-- Prix pour passer de l'épée `sword` à la suivante.
function Config.swordPrice(sword: number): number
	return math.floor(40 * 2.1 ^ (sword - 1))
end
-- LES FAMILIERS AU COMBAT. Les monstres s'en prennent d'abord à eux (dans l'ordre de l'équipe), et au joueur en
-- dernier : le joueur a peu de vie, ses familiers encaissent. Chacun a ses dégâts par seconde et sa vie, tirés de
-- sa valeur (la racine carrée resserre l'écart : un super rare tape environ 40 fois plus fort qu'un commun, pas
-- 3 000 fois), et son NIVEAU, qui monte avec l'XP des monstres : +PET_LEVEL par niveau.
-- À niveau égal, le même animal de la zone suivante est toujours plus fort (sa valeur est 10 fois plus haute, donc
-- ses dégâts et sa vie 3,2 fois plus hauts).
Config.PET_LEVEL = 0.1
Config.PET_REST = 5 -- secondes sans prendre de coup pour que les familiers se relèvent et se soignent
function Config.petBoost(level: number?): number
	return 1 + Config.PET_LEVEL * ((level or 1) - 1)
end
function Config.petDamage(value: number, level: number?): number
	return math.max(1, math.floor(2 * math.sqrt(value / 100) * Config.petBoost(level) + 0.5))
end
function Config.petHealth(value: number, level: number?): number
	return math.max(10, math.floor(30 * math.sqrt(value / 100) * Config.petBoost(level) + 0.5))
end
-- XP qu'il faut à un familier pour passer du niveau `level` au suivant.
function Config.petXpNeed(level: number): number
	return math.floor(15 * level ^ 1.6)
end
-- Tant qu'un familier tient debout, le monstre s'arrête à cette distance du joueur et frappe le familier.
Config.PET_GUARD = 13

return Config

-- Réglages du mode infini (les vagues sur ta parcelle).
-- Les PV des ennemis et les pièces gagnées sont multipliés à chaque vague :
-- ça commence à quelques pièces et ça explose (milliards, trillions, quadrillions, et bien au-delà).
-- Les chiffres ci-dessous ont été réglés avec le simulateur tools/balance (voir tools/balance/RESULTS.md).
local IdleConfig = {}

IdleConfig.STARTING_COINS = 50 -- 25 avant : le début était trop dur
-- Pas de PV de base : UN SEUL ennemi qui atteint le bout du chemin = vague ratée (on redescend d'une
-- vague, voir PlotGame:step). Chaque ennemi compte, du petit écuyer au Seigneur de guerre.
IdleConfig.FIRST_WAVE_DELAY = 4
IdleConfig.WAVE_CLEAR_DELAY = 1.5
IdleConfig.WAVE_FAIL_DELAY = 3

-- Rythme « souvent bloqué, souvent débloqué » : les PV montent un peu plus vite que les gains.
-- Au mur, tu farmes les vagues d'avant jusqu'à pouvoir t'offrir l'amélioration qui te débloque.
-- Les grands nombres viennent des vagues elles-mêmes : chaque vague rapporte 25 % de plus que la précédente
-- (x9 toutes les 10 vagues). Joueur actif (simulateur, sans forge ni renaissance) : ~1 milliard (B) de
-- pièces par minute vers 14 h de jeu, ~1 trillion (T) vers 22 h, ~1 quadrillion (Qa) vers 29 h,
-- ~1 quintillion (Qi) vers 39 h, et ça continue (voir tools/balance/RESULTS.md).
-- Les PV montent aussi de x1,25 par vague, MULTIPLIÉS par un facteur qui dépend du numéro de la vague
-- (voir healthBudget plus bas) : au total, ils montent toujours un peu plus vite que les pièces.
IdleConfig.HEALTH_GROWTH = 1.25 -- PV x1,25 par vague (fois le facteur de HEALTH_WAVE_POWER)
IdleConfig.REWARD_GROWTH = 1.25 -- pièces x1,25 par vague

-- Améliorations des tours (niveaux illimités). Le prix ne dépend que du niveau, pas de la tour :
-- améliorer un Archer ou un Trébuchet niveau 10 coûte pareil. Les tours rares sont plus fortes
-- à niveau égal (voir IdleTowers.luau).
IdleConfig.UPGRADE_DAMAGE = 1.35 -- dégâts x1,35 par niveau
IdleConfig.UPGRADE_COST_BASE = 20 -- niveau 1 -> 2 : 20 pièces, pour toutes les tours
-- Chaque niveau suivant coûte x1,35, autant que le gain de dégâts : pour une tour donnée, une pièce
-- rapporte autant de dégâts à n'importe quel niveau. Une tour neuve vaut donc autant la peine d'être
-- améliorée qu'une vieille tour de haut niveau (avec un prix qui monte moins vite que les dégâts, tout
-- mettre sur une seule tour était toujours mieux).
IdleConfig.UPGRADE_COST_GROWTH = 1.35

-- Vitesse des ennemis sur les parcelles = vitesse de Enemies.luau x ENEMY_SPEED_MULTIPLIER x le facteur
-- de leur type (ENEMY_SPEED_FACTORS, 1 si absent). Réglages du mode infini seulement : le ranked garde
-- les vitesses de Enemies.luau.
IdleConfig.ENEMY_SPEED_MULTIPLIER = 1.35 -- 1,6 avant : les ennemis allaient un peu trop vite
IdleConfig.ENEMY_SPEED_FACTORS = {
	Fast = 0.7, -- cavaliers : toujours les plus rapides, mais plus des éclairs (13 studs/s au lieu de 22)
	-- écuyers : 13 studs/s au lieu de 19. Pas plus de 0,81 : les cavaliers doivent rester les plus rapides.
	Swarm = 0.8,
	-- Chevaliers lourds, colosse et Seigneur de guerre : freinés moins que les autres (7,4 / 4,7 / 5,4 studs/s,
	-- contre 8 / 4,8 / 5,6 avant). Plus lents, les vagues du début duraient trop longtemps (vague 10 après
	-- ~8 min) et une Garde colossale ratée faisait perdre 1 min 30 sans rapporter une pièce.
	Tank = 1.1,
	Giant = 1.15,
	Boss = 1.15,
}
-- Doit rester entre 0 et 2,5 : le facteur voyage sur 1 octet dans le paquet des positions (PlotGame).
function IdleConfig.enemySpeedFactor(enemyType: string): number
	return IdleConfig.ENEMY_SPEED_FACTORS[enemyType] or 1
end
IdleConfig.MAX_ENEMIES = 80 -- par parcelle
IdleConfig.SYNC_RATE = 6 -- envois de position des ennemis aux clients par seconde
IdleConfig.SHOTS_RATE = 10 -- envois des effets de tir par seconde
IdleConfig.MAX_SHOTS_PER_PACKET = 24

IdleConfig.PICKUP_RADIUS = 7 -- distance pour ramasser une pile de pièces
IdleConfig.MERGE_RADIUS = 6 -- les pièces tombées près d'une pile s'y ajoutent
IdleConfig.MAX_DROPS = 40

IdleConfig.SELL_REFUND = 0.5 -- part du prix rendue à la vente (prix des tours : IdleTowers.luau)

----------------------------------------------------------------------
-- Machine à tours (Autel des héros) : les lancers se paient en pièces, par 1, 10, 100, 1 000 ou 1 000 000.
-- Les chances dépendent de ton RECORD (idle.highestWave), exactement celles affichées par l'autel.
----------------------------------------------------------------------
IdleConfig.STARTING_TOWERS = { "MachineGun" }
-- +2 % de dégâts permanents par doublon. Les tours communes en reçoivent des centaines : à +5 %, elles
-- écrasaient les tours rares, et les grands nombres doivent venir des vagues, pas des doublons.
IdleConfig.DUPLICATE_DAMAGE_BONUS = 0.02

IdleConfig.RARITY_ORDER = { "Common", "Rare", "Epic", "Legendary" }
IdleConfig.RARITIES = {
	Common = { displayName = "Commune", color = Color3.fromRGB(190, 195, 205) },
	Rare = { displayName = "Rare", color = Color3.fromRGB(80, 150, 255) },
	Epic = { displayName = "Épique", color = Color3.fromRGB(180, 90, 255) },
	Legendary = { displayName = "Légendaire", color = Color3.fromRGB(255, 190, 50) },
}

-- Chances (en %) de chaque rareté selon ton record. Aux paliers hauts, les Épiques et les
-- Légendaires tombent plus souvent : les doublons se répartissent mieux entre les 8 tours.
-- Épiques 10 % dès la vague 10 et Légendaires 5 % dès la vague 25 (8 % et 3 % avant) : avec des lancers
-- payants, le joueur simulé ne débloquait les légendaires que vers la vague 50 (vers 35-45 maintenant).
IdleConfig.TOWER_SPIN_TIERS = {
	{ minWave = 1, odds = { Common = 80, Rare = 20, Epic = 0, Legendary = 0 } },
	{ minWave = 10, odds = { Common = 58, Rare = 32, Epic = 10, Legendary = 0 } },
	{ minWave = 25, odds = { Common = 43, Rare = 35, Epic = 17, Legendary = 5 } },
	{ minWave = 50, odds = { Common = 25, Rare = 35, Epic = 28, Legendary = 12 } },
	{ minWave = 100, odds = { Common = 15, Rare = 30, Epic = 35, Legendary = 20 } },
}

-- Palier de chances pour ce record (à appeler avec idle.highestWave, jamais avec la vague en cours).
function IdleConfig.towerSpinTier(wave: number): number
	local tier = 1
	for index, info in IdleConfig.TOWER_SPIN_TIERS do
		if wave >= info.minWave then
			tier = index
		end
	end
	return tier
end

-- Lancers proposés par l'autel, dans l'ordre des boutons : count = nombre de lancers d'un coup,
-- minWave = record nécessaire pour voir le bouton, price = prix du lot en nombre de lancers x1.
-- Chaque bouton apparaît quand son prix devient raisonnable (en vagues de gains à ton record) :
--   x100 (record 40) : ~7 vagues de gains ; x1 000 (record 150) : ~22 vagues, ~17 au record 200.
--   x1 000 000 (record 1 000) : ~4 000 vagues de gains. Il reste un objectif lointain, exprès.
-- ATTENTION, ne pas mettre de remise de gros (price plus petit que count), surtout sur x1 000 000.
-- Ici PV et pièces grandissent au même rythme (x1,25 par vague) : multiplier tous ses dégâts par M
-- fait avancer le record d'un facteur ~M^(1/2,4). Un million de lancers, c'est x1 500 à x3 500 de dégâts :
-- essayé à 5 000 lancers x1 le lot, le joueur simulé est passé de la vague 377 à la vague 600-1 000
-- en 6 h. Même x1 000 à moitié prix faisait arriver la vague 100 ~1 h 20 plus tôt.
IdleConfig.TOWER_SPIN_BULKS = {
	{ count = 1, minWave = 1, price = 1 },
	{ count = 10, minWave = 1, price = 10 },
	{ count = 100, minWave = 40, price = 100 },
	{ count = 1000, minWave = 150, price = 1000 },
	{ count = 1000000, minWave = 1000, price = 1000000 },
}

-- Prix d'UN lancer : TOWER_SPIN_COST_WAVES vague de gains à ton record jusqu'à la vague
-- TOWER_SPIN_DISCOUNT_WAVE, puis divisé par (record / 10)^0,9 : le prix suit les pièces, mais de moins
-- en moins vite. En vagues de gains à ton record (simulateur, tools/balance/RESULTS.md) :
--   record 1-10 : 1 lancer = 0,25 vague (x10 = 2,5)     record 40 : 0,07 (x100 = 7)
--   record 100  : 0,03 (x100 = 3)                        record 300 : 0,012     record 1 000 : 0,004
-- Attention en réglant : chaque doublon donne +2 % de dégâts (DUPLICATE_DAMAGE_BONUS). Avec des lancers
-- bien moins chers loin dans le jeu (avant : divisé par (record / 10)^2), les doublons (jusqu'à x2 300 de
-- dégâts sur une tour) écrasaient tout : vague 1 066 en 100 h au lieu de 376, des murs de plus en plus courts.
IdleConfig.TOWER_SPIN_COST_WAVES = 0.25
IdleConfig.TOWER_SPIN_DISCOUNT_WAVE = 10
IdleConfig.TOWER_SPIN_DISCOUNT_POWER = 0.9

-- Record « propre » pour les prix et les chances (une valeur abîmée compte comme la vague 1).
local function cleanRecord(highestWave: any): number
	if typeof(highestWave) ~= "number" or highestWave ~= highestWave then
		return 1
	end
	return math.clamp(math.floor(highestWave), 1, IdleConfig.MAX_SCALING_WAVE)
end

-- Prix d'un seul lancer à ce record (arrondi à 2 chiffres, au moins 1 pièce).
function IdleConfig.towerSpinUnitCost(highestWave: number): number
	local record = cleanRecord(highestWave)
	local discount = math.max(1, record / IdleConfig.TOWER_SPIN_DISCOUNT_WAVE) ^ IdleConfig.TOWER_SPIN_DISCOUNT_POWER
	local raw = IdleConfig.rewardBudget(record) * IdleConfig.TOWER_SPIN_COST_WAVES / discount
	if raw < 1 then
		return 1
	end
	local magnitude = 10 ^ math.max(0, math.floor(math.log10(raw)) - 1)
	return math.max(1, math.floor(raw / magnitude + 0.5) * magnitude)
end

-- Prix total de `count` lancers d'un coup à ce record : prix d'un lancer x `price` du lot
-- (TOWER_SPIN_BULKS ; count si le lot n'a pas de prix à lui). Toujours fini : les pièces arrêtent de
-- grandir à MAX_SCALING_WAVE.
function IdleConfig.towerSpinCost(highestWave: number, count: number): number
	local price = count
	for _, bulk in IdleConfig.TOWER_SPIN_BULKS do
		if bulk.count == count and bulk.price then
			price = bulk.price
		end
	end
	return IdleConfig.towerSpinUnitCost(highestWave) * price
end

-- Vrai si ce nombre de lancers est proposé (TOWER_SPIN_BULKS) et débloqué à ce record.
function IdleConfig.towerSpinBulkAvailable(highestWave: number, count: any): boolean
	for _, bulk in IdleConfig.TOWER_SPIN_BULKS do
		if bulk.count == count then
			return cleanRecord(highestWave) >= bulk.minWave
		end
	end
	return false
end

----------------------------------------------------------------------
-- Machine à bonus : le bonus obtenu va dans ton inventaire, puis se pose sur une tour
-- (un seul bonus par tour ; en poser un nouveau remplace l'ancien).
-- 1 lancer en pièces toutes les 30 minutes, lancers en Robux à volonté (Config.Products).
----------------------------------------------------------------------
IdleConfig.BONUS_SPIN_COOLDOWN = 30 * 60
IdleConfig.MAX_BONUS_INVENTORY = 50
IdleConfig.BONUSES = {
	{ id = "Damage2", displayName = "x2 dégâts", kind = "Damage", mult = 2, chance = 35 },
	{ id = "Speed2", displayName = "x2 vitesse d'attaque", kind = "Speed", mult = 2, chance = 30 },
	{ id = "Damage3", displayName = "x3 dégâts", kind = "Damage", mult = 3, chance = 18 },
	{ id = "Damage5", displayName = "x5 dégâts", kind = "Damage", mult = 5, chance = 10 },
	{ id = "Damage10", displayName = "x10 dégâts", kind = "Damage", mult = 10, chance = 5 },
	{ id = "Damage20", displayName = "x20 dégâts", kind = "Damage", mult = 20, chance = 1.5 },
	{ id = "Damage50", displayName = "x50 dégâts", kind = "Damage", mult = 50, chance = 0.4 },
	{ id = "Damage100", displayName = "x100 dégâts", kind = "Damage", mult = 100, chance = 0.1 },
}
IdleConfig.BONUS_BY_ID = {}
for _, bonus in IdleConfig.BONUSES do
	IdleConfig.BONUS_BY_ID[bonus.id] = bonus
end

-- Prix d'un lancer en pièces : ~15 vagues de gains à ton record, pour rester intéressant à tout moment.
function IdleConfig.bonusSpinCost(highestWave: number): number
	local raw = IdleConfig.rewardBudget(math.max(1, highestWave)) * 15
	local magnitude = 10 ^ math.max(0, math.floor(math.log10(raw)) - 1)
	return math.floor(raw / magnitude + 0.5) * magnitude
end

----------------------------------------------------------------------
-- Renaissance : possible dès que la meilleure vague de la run (idle.bestWave, remise à 1 à
-- chaque renaissance) atteint REBIRTH_MIN_WAVE. Seule la vague repart à 1 ; tout le reste est
-- gardé (pièces, tours, améliorations, emplacements, machines, record de tous les temps).
-- En échange, un bonus de pièces permanent qui s'ajoute à idle.coinBonus :
--   gain(w) = 1 + 6 x ((w - 15) / 85) ^ 0,8   (en %, arrondi à 0,1 %)
--   vague 15 -> +1 %, vague 50 -> +4 %, vague 100 -> +7 %, et ça continue de monter ensuite
--   (vague 200 -> +12,2 %, vague 500 -> +25,2 %).
-- Mode infini uniquement : le ranked n'en profite jamais.
----------------------------------------------------------------------
IdleConfig.REBIRTH_MIN_WAVE = 15
IdleConfig.REBIRTH_BASE_GAIN = 1 -- % gagnés à la vague minimale
IdleConfig.REBIRTH_GAIN_SCALE = 6 -- % en plus à la vague de référence (15 + 85 = vague 100 -> +7 %)
IdleConfig.REBIRTH_REFERENCE_WAVES = 85
IdleConfig.REBIRTH_GAIN_EXPONENT = 0.8 -- < 1 : les premières vagues au-dessus du minimum rapportent le plus

-- Arrondi à 0,1 % (évite les 12.300000001 % quand on additionne les gains).
function IdleConfig.roundPercent(value: number): number
	return math.floor(value * 10 + 0.5) / 10
end

-- Bonus de pièces (en %) gagné en renaissant avec cette meilleure vague ; 0 sous le minimum.
function IdleConfig.rebirthGain(bestWave: number): number
	if typeof(bestWave) ~= "number" or bestWave ~= bestWave or bestWave < IdleConfig.REBIRTH_MIN_WAVE then
		return 0
	end
	local progress = (bestWave - IdleConfig.REBIRTH_MIN_WAVE) / IdleConfig.REBIRTH_REFERENCE_WAVES
	return IdleConfig.roundPercent(
		IdleConfig.REBIRTH_BASE_GAIN + IdleConfig.REBIRTH_GAIN_SCALE * progress ^ IdleConfig.REBIRTH_GAIN_EXPONENT
	)
end

-- Affichage d'un pourcentage de bonus : 4 -> "4", 12.3 -> "12.3" (même séparateur que NumberFormat).
function IdleConfig.formatPercent(value: number): string
	local rounded = IdleConfig.roundPercent(value)
	if rounded == math.floor(rounded) then
		return string.format("%d", rounded)
	end
	return string.format("%.1f", rounded)
end

-- Chaque vague a un budget de PV total et un budget de pièces, qui grandissent à chaque vague.
-- Le type de vague décide comment ce budget est réparti : 40 petits écuyers ou un seul colosse énorme.
-- La difficulté reste donc comparable, mais ce ne sont pas les mêmes tours qui brillent.
--   PV totaux de la vague w = HEALTH_BUDGET x HEALTH_GROWTH^(w - 1) x ((w + 5) / 6)^2,4
--   pièces de la vague w    = REWARD_BUDGET x REWARD_GROWTH^(w - 1) x bonus de début (voir plus bas)
-- Le facteur ((w + 5) / 6)^2,4 fait monter les PV bien plus vite que les pièces au début, puis de moins
-- en moins : d'une vague à la suivante, PV x1,46 à la vague 10, x1,35 à la 25, x1,30 à la 50, x1,28 à la
-- 100, x1,26 à la 200 (pièces toujours x1,25).
-- Comme PV et pièces grandissent au même rythme (x1,25), seul ce facteur les sépare : multiplier tous ses
-- dégâts par M (doublons, forge, bonus de renaissance) fait avancer le record d'un facteur ~M^(1/2,4).
-- Résultat (simulateur, joueur actif sans forge ni renaissance, voir tools/balance/RESULTS.md) : vague 10
-- vers 7 min sans mur, premier mur vers la vague 15 (2 min), vague 25 vers 42 min, vague 50 vers 4 h 30,
-- vague 100 vers 16 h 30 ; murs de ~2 min (vagues 11-30), ~7 min (31-70), ~12 min (71-100) en médiane,
-- ~17 min après la vague 100 (mais 1 mur sur 5 dépasse 20 à 30 min dès la vague 31).
-- Exemples : vague 10 -> 1,2 K PV et 59 pièces (82 avec le bonus de début), vague 50 -> 205 M PV et 448 K pièces,
-- vague 100 -> 68 T PV et 31 B pièces, vague 200 -> 1,7 Sp PV et 154 Qi pièces.
-- Sans limite, les PV deviendraient infinis vers la vague 3 100 (au-delà de ~1,8e308, Luau passe à
-- l'infini et un DataStore ne sait pas le sauver) : à partir de MAX_SCALING_WAVE, PV et pièces arrêtent
-- de grandir.
IdleConfig.MAX_SCALING_WAVE = 3000
IdleConfig.HEALTH_BUDGET = 18 -- PV totaux de la vague 1
-- Forme de la courbe : plus grand = PV plus hauts partout, et de plus en plus loin dans le jeu. 2,4 (2,3
-- avant) : avec les lancers payants et la règle « une fuite = ratée », la vague 100 arrivait vers 13 h.
IdleConfig.HEALTH_WAVE_POWER = 2.4
IdleConfig.HEALTH_WAVE_OFFSET = 5 -- décale le facteur : plus grand = PV plus bas au début (courbe plus douce)
IdleConfig.REWARD_BUDGET = 8 -- pièces totales de la vague 1
-- Bonus de début : +50 % de pièces à la vague 1, qui fond jusqu'à 0 à la vague 40 (+32 % à la vague 15,
-- +19 % à la 25). Les premières vagues étaient trop dures, surtout 15 à 25 (et une seule fuite fait
-- maintenant rater la vague). Il ne change rien après la vague 40.
IdleConfig.EARLY_REWARD_BONUS = 0.5
IdleConfig.EARLY_REWARD_END_WAVE = 40

function IdleConfig.earlyRewardBonus(wave: number): number
	local left = (IdleConfig.EARLY_REWARD_END_WAVE - wave) / (IdleConfig.EARLY_REWARD_END_WAVE - 1)
	return 1 + IdleConfig.EARLY_REWARD_BONUS * math.clamp(left, 0, 1)
end

function IdleConfig.healthBudget(wave: number): number
	wave = math.min(wave, IdleConfig.MAX_SCALING_WAVE)
	local offset = IdleConfig.HEALTH_WAVE_OFFSET
	local waveFactor = ((wave + offset) / (1 + offset)) ^ IdleConfig.HEALTH_WAVE_POWER
	return IdleConfig.HEALTH_BUDGET * IdleConfig.HEALTH_GROWTH ^ (wave - 1) * waveFactor
end

function IdleConfig.rewardBudget(wave: number): number
	wave = math.min(wave, IdleConfig.MAX_SCALING_WAVE)
	return IdleConfig.REWARD_BUDGET * IdleConfig.REWARD_GROWTH ^ (wave - 1) * IdleConfig.earlyRewardBonus(wave)
end

-- Types de vagues. share = part du budget, count = nombre d'ennemis, gap = secondes entre deux.
-- Les parts sont réglées pour que chaque type bloque de temps en temps (murs variés) et que le Seigneur
-- de guerre reste le plus dur. Une seule fuite fait rater la vague : chaque ennemi, même le plus petit,
-- doit tomber. Le Totem de givre (zone + ralentissement) vient bien à bout des Levées et des Charges ;
-- un ennemi unique et énorme (colosse, Seigneur de guerre) ne peut compter que sur les tours qui le
-- visent, d'où sa plus petite part.
-- Les pièces suivent les mêmes parts. Attention : au mur d'une vague x6 (46, 56...), on farme la Garde
-- colossale d'avant, qui rapporte 2 fois moins qu'une Escarmouche : ces murs restent parmi les plus longs
-- avant la vague 100 (~25 min à 1 h vers les vagues 46-76, simulateur ; pire avec une part de 0,35-0,4).
-- Essayé : une Garde qui rapporte autant qu'une Escarmouche raccourcit ces murs, mais la vague 100 arrive
-- alors vers 14 h au lieu de 16 h 30.
IdleConfig.WAVE_TYPES = {
	Mixed = {
		displayName = "Escarmouche",
		hint = "Fantassins, cavaliers et garde lourde",
		groups = function(wave)
			return {
				{ enemy = "Normal", share = 0.5, count = 6 + math.min(wave // 8, 8), gap = 0.6 },
				{ enemy = "Fast", share = 0.2, count = 3 + math.min(wave // 10, 6), gap = 0.4 },
				{ enemy = "Tank", share = 0.37, count = 1 + math.min(wave // 12, 4), gap = 1.2 },
			}
		end,
	},
	Horde = {
		displayName = "Levée des écuyers",
		hint = "Une foule de jeunes soldats : les attaques de zone brillent",
		groups = function(wave)
			-- 15 écuyers au début (19 à la vague 13), jusqu'à 45 à partir de la vague 90. Part 0,75 (0,68 avant) :
			-- avec le Totem de givre renforcé, les Levées ne bloquaient presque plus jamais.
			return { { enemy = "Swarm", share = 0.75, count = 15 + math.min(wave // 3, 30), gap = 0.18 } }
		end,
	},
	Rush = {
		displayName = "Charge de cavalerie",
		hint = "Les cavaliers sont très rapides : ralentis-les !",
		groups = function(wave)
			-- Part 0,7 (0,6 avant) : les cavaliers sont moins rapides et le Totem les ralentit bien plus.
			return { { enemy = "Fast", share = 0.7, count = 12 + math.min(wave // 6, 12), gap = 0.3 } }
		end,
	},
	Giants = {
		displayName = "Garde colossale",
		hint = "Un chevalier colossal : concentre tes dégâts",
		groups = function(_wave)
			-- UN SEUL colosse (avant : 2 à 4 colosses et une part de 1,5). Part 0,5 : à 1 ou 1,5, seules
			-- les tours qui le visent comptent et ses murs dépassaient 30 min à 1 h dès la vague 25.
			return { { enemy = "Giant", share = 0.5, count = 1, gap = 0 } }
		end,
	},
	Boss = {
		displayName = "SEIGNEUR DE GUERRE",
		hint = "Un immense chevalier mène l'assaut : concentre toute ta puissance",
		groups = function(wave)
			-- UN SEUL Seigneur de guerre, escorté de 6 fantassins.
			-- Il grossit avec les vagues : 0,3 du budget à la vague 10 (premier boss facile), 0,5 à partir de
			-- la vague 20. Avant, 0,8 : seul, il bloquait 20 à 30 min dès la vague 30.
			return {
				{ enemy = "Normal", share = 0.4, count = 6, gap = 0.5 },
				{ enemy = "Boss", share = math.clamp(wave / 40, 0.3, 0.5), count = 1, gap = 0 },
			}
		end,
	},
}

local ROTATION = { "Mixed", "Horde", "Mixed", "Rush" }

-- Même type de vague pour tout le monde à une vague donnée. Les 10 premières vagues sont des
-- Escarmouches (sauf la Garde colossale à la 5 et le boss à la 10) : on démarre sans mur, les Levées
-- d'écuyers et les Charges de cavalerie arrivent ensuite (vagues 11, 13, 17, 21...).
-- La vague juste avant un boss (19, 29, 39...) est toujours une Escarmouche : c'est elle qu'on farme
-- quand le boss bloque, et elle rapporte plus qu'une Charge de cavalerie ou une Levée d'écuyers.
function IdleConfig.waveType(wave: number): string
	if wave % 10 == 0 then
		return "Boss"
	elseif wave % 5 == 0 then
		return "Giants"
	elseif wave <= 10 or wave % 10 == 9 then
		return "Mixed"
	end
	return ROTATION[wave % #ROTATION + 1]
end

-- Liste des ennemis à faire apparaître : { { enemy, health, reward, gap } }.
function IdleConfig.buildWave(wave: number)
	local healthBudget = IdleConfig.healthBudget(wave)
	local rewardBudget = IdleConfig.rewardBudget(wave)
	local list = {}
	for _, group in IdleConfig.WAVE_TYPES[IdleConfig.waveType(wave)].groups(wave) do
		local health = healthBudget * group.share / group.count
		local reward = rewardBudget * group.share / group.count
		for _ = 1, group.count do
			table.insert(list, { enemy = group.enemy, health = health, reward = reward, gap = group.gap })
		end
	end
	return list
end

----------------------------------------------------------------------
-- Gains d'absence : ta parcelle continue de rapporter un peu quand tu n'es pas là. Versés quand tu
-- reviens sur la map principale, avec le message « Pendant ton absence : +X » (Hub/init.luau).
--   revenu normal (pièces / s) = pièces de ta meilleure vague de la run (rewardBudget(idle.bestWave))
--                                x (1 + bonus de pièces / 100) / ABSENCE_WAVE_SECONDS
--   hors ligne (pas dans le jeu) : revenu normal x OFFLINE_RATE, au plus OFFLINE_MAX_SECONDS par absence,
--       et au plus OFFLINE_DAILY_RUNS runs complètes par jour (jour UTC, compteur remis à 0 à 00:00 UTC ;
--       les gains déjà reçus dans la journée comptent)
--   pendant un match ranked : revenu normal, hors plafond (au plus Config.Match.MAX_DURATION
--       + ABSENCE_MATCH_EXTRA_SECONDS)
--   run complète = pièces des vagues 1 à idle.bestWave (la vague où tu bloques) x (1 + bonus / 100)
-- Ordres de grandeur : une run vaut ~5 vagues de gains de ta meilleure vague (les gains font x1,25 par
-- vague), le plafond ~15 vagues, atteint après ~2 h d'absence (vague 15 et plus ; ~25 min à la vague 1).
-- Rien de tout ça ne compte en ranked.
----------------------------------------------------------------------
-- Durée « typique » d'une vague de gains : dans le simulateur (tools/balance, joueur actif, scénario
-- « base »), un joueur gagne ~1 vague de gains de son record toutes les 60 à 250 s (murs, vagues ratées
-- et entractes compris), ~100 s en médiane.
IdleConfig.ABSENCE_WAVE_SECONDS = 100
IdleConfig.OFFLINE_RATE = 0.2 -- hors ligne : 20 % du revenu normal
IdleConfig.OFFLINE_MAX_SECONDS = 24 * 3600 -- une absence compte au plus 24 h
IdleConfig.OFFLINE_DAILY_RUNS = 3 -- plafond des gains hors ligne par jour, en runs complètes
IdleConfig.ABSENCE_MATCH_EXTRA_SECONDS = 5 * 60 -- attente et téléportations, en plus de la durée max d'un match
-- Plus grand nombre de pièces renvoyé par ces calculs : toujours fini (un DataStore ne sait pas sauver l'infini).
local ABSENCE_MAX_COINS = 1e300

local function finiteCoins(value: number): number
	if value ~= value or value < 0 then
		return 0
	end
	return math.min(value, ABSENCE_MAX_COINS)
end

-- Vague de référence propre : entière, au moins 1 (une valeur abîmée compte comme la vague 1).
local function absenceWave(bestWave: any): number
	if typeof(bestWave) ~= "number" or bestWave ~= bestWave then
		return 1
	end
	return math.clamp(math.floor(bestWave), 1, 1e9)
end

-- Multiplicateur du bonus de pièces : 1 + bonus / 100 (bonus abîmé ou négatif = 0).
local function absenceBonus(coinBonus: any): number
	if typeof(coinBonus) ~= "number" or coinBonus ~= coinBonus or coinBonus < 0 then
		return 1
	end
	return 1 + math.min(coinBonus, 1e9) / 100
end

-- Revenu normal estimé, en pièces par seconde (voir plus haut).
function IdleConfig.normalCoinRate(bestWave: any, coinBonus: any): number
	local wave = absenceWave(bestWave)
	return finiteCoins(IdleConfig.rewardBudget(wave) * absenceBonus(coinBonus) / IdleConfig.ABSENCE_WAVE_SECONDS)
end

-- Pièces d'une run complète : vagues 1 à bestWave (au-delà de MAX_SCALING_WAVE, chaque vague rapporte
-- autant que MAX_SCALING_WAVE), bonus compris.
function IdleConfig.runCoins(bestWave: any, coinBonus: any): number
	local wave = absenceWave(bestWave)
	local total = 0
	for w = 1, math.min(wave, IdleConfig.MAX_SCALING_WAVE) do
		total += IdleConfig.rewardBudget(w)
	end
	if wave > IdleConfig.MAX_SCALING_WAVE then
		total += (wave - IdleConfig.MAX_SCALING_WAVE) * IdleConfig.rewardBudget(IdleConfig.MAX_SCALING_WAVE)
	end
	return finiteCoins(total * absenceBonus(coinBonus))
end

-- Plafond des gains hors ligne sur une journée UTC (arrondi à la pièce).
function IdleConfig.offlineDailyCap(bestWave: any, coinBonus: any): number
	return math.floor(finiteCoins(IdleConfig.runCoins(bestWave, coinBonus) * IdleConfig.OFFLINE_DAILY_RUNS))
end

----------------------------------------------------------------------
-- Passes de jeu (Config.GamePasses), mode solo uniquement
----------------------------------------------------------------------
-- Ramassage auto : une pile de pièces est ramassée toute seule après ce délai (secondes), le temps de la voir.
IdleConfig.AUTO_COLLECT_DELAY = 0.5
-- Vitesse x2 : toute la simulation de la parcelle tourne ce nombre de fois plus vite (ennemis, apparitions,
-- tirs, entractes). Nombre ENTIER : le serveur fait ce nombre de pas de simulation par image (PlotGame:step).
IdleConfig.SPEED_PASS_FACTOR = 2

return IdleConfig

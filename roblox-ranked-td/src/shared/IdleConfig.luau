-- Réglages du mode infini (les vagues sur ta parcelle).
-- Les PV des ennemis et les pièces gagnées sont multipliés à chaque vague :
-- ça commence à quelques pièces et ça explose (milliards, trillions, quadrillions, et bien au-delà).
-- Les chiffres ci-dessous ont été réglés avec le simulateur tools/balance (voir tools/balance/RESULTS.md).
local IdleConfig = {}

IdleConfig.STARTING_COINS = 25
-- PV de la base, remis à neuf à chaque vague. 10 (et non 20) : chaque type de vague peut être raté
-- (avant, les Escarmouches et les Charges de cavalerie ne faisaient presque jamais assez de dégâts,
-- et seuls les boss bloquaient).
IdleConfig.BASE_HEALTH = 10
IdleConfig.FIRST_WAVE_DELAY = 4
IdleConfig.WAVE_CLEAR_DELAY = 1.5
IdleConfig.WAVE_FAIL_DELAY = 3

-- Rythme « souvent bloqué, souvent débloqué » : les PV montent un peu plus vite que les gains.
-- Au mur, tu farmes les vagues d'avant jusqu'à pouvoir t'offrir l'amélioration qui te débloque.
-- Les grands nombres viennent des vagues elles-mêmes : chaque vague rapporte 25 % de plus que la précédente
-- (x9 toutes les 10 vagues). Joueur actif (simulateur, sans forge ni renaissance) : ~1 milliard (B) de
-- pièces par minute vers 16 h de jeu, ~1 trillion (T) vers 30 h, ~1 quadrillion (Qa) vers 50 h,
-- ~1 quintillion (Qi) vers 75 h, et ça continue (voir tools/balance/RESULTS.md).
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

IdleConfig.ENEMY_SPEED_MULTIPLIER = 1.6 -- les ennemis vont plus vite sur les parcelles qu'en ranked
IdleConfig.MAX_ENEMIES = 80 -- par parcelle
IdleConfig.SYNC_RATE = 6 -- envois de position des ennemis aux clients par seconde
IdleConfig.SHOTS_RATE = 10 -- envois des effets de tir par seconde
IdleConfig.MAX_SHOTS_PER_PACKET = 24

IdleConfig.PICKUP_RADIUS = 7 -- distance pour ramasser une pile de pièces
IdleConfig.MERGE_RADIUS = 6 -- les pièces tombées près d'une pile s'y ajoutent
IdleConfig.MAX_DROPS = 40

IdleConfig.SELL_REFUND = 0.5 -- part du prix rendue à la vente (prix des tours : IdleTowers.luau)

----------------------------------------------------------------------
-- Machine à tours : 1 lancer gratuit à chaque vague réussie, sans cumul.
-- Plus la vague réussie est haute, meilleures sont les chances (le lancer garde le meilleur palier).
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

-- Chances (en %) de chaque rareté selon la vague réussie. Aux paliers hauts, les Épiques et les
-- Légendaires tombent plus souvent : les doublons se répartissent mieux entre les 8 tours.
IdleConfig.TOWER_SPIN_TIERS = {
	{ minWave = 1, odds = { Common = 80, Rare = 20, Epic = 0, Legendary = 0 } },
	{ minWave = 10, odds = { Common = 60, Rare = 32, Epic = 8, Legendary = 0 } },
	{ minWave = 25, odds = { Common = 45, Rare = 35, Epic = 17, Legendary = 3 } },
	{ minWave = 50, odds = { Common = 25, Rare = 35, Epic = 28, Legendary = 12 } },
	{ minWave = 100, odds = { Common = 15, Rare = 30, Epic = 35, Legendary = 20 } },
}

function IdleConfig.towerSpinTier(wave: number): number
	local tier = 1
	for index, info in IdleConfig.TOWER_SPIN_TIERS do
		if wave >= info.minWave then
			tier = index
		end
	end
	return tier
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
-- Le type de vague décide comment ce budget est réparti : 40 petites nuées ou 3 géants énormes.
-- La difficulté reste donc comparable, mais ce ne sont pas les mêmes tours qui brillent.
--   PV totaux de la vague w = HEALTH_BUDGET x HEALTH_GROWTH^(w - 1) x ((w + 5) / 6)^2,3
--   pièces de la vague w    = REWARD_BUDGET x REWARD_GROWTH^(w - 1)
-- Le facteur ((w + 5) / 6)^2,3 fait monter les PV bien plus vite que les pièces au début, puis de moins
-- en moins : d'une vague à la suivante, PV x1,45 à la vague 10, x1,35 à la 25, x1,30 à la 50, x1,28 à la
-- 100, x1,26 à la 200 (pièces toujours x1,25). Résultat (simulateur) : les 10 premières vagues passent
-- sans mur, les murs commencent vers la vague 13 (quelques minutes), durent ~10-15 min vers les vagues
-- 30-70, puis s'allongent : ~15 min en médiane vers 71-100 (mais 1 mur sur 7 y dépasse 1 h, surtout Garde
-- colossale et Seigneur de guerre), ~20-35 min en médiane après la vague 100.
-- Exemples : vague 10 -> 1,1 K PV et 59 pièces, vague 50 -> 164 M PV et 448 K pièces,
-- vague 100 -> 51 T PV et 31 B pièces, vague 200 -> 1,2 Sp PV et 154 Qi pièces.
-- Sans limite, les PV deviendraient infinis vers la vague 3 100 (au-delà de ~1,8e308, Luau passe à
-- l'infini et un DataStore ne sait pas le sauver) : à partir de MAX_SCALING_WAVE, PV et pièces arrêtent
-- de grandir. Avec la forge et les renaissances, le simulateur atteint les vagues 750 à 1 200 vers 100 h de jeu.
IdleConfig.MAX_SCALING_WAVE = 3000
IdleConfig.HEALTH_BUDGET = 18 -- PV totaux de la vague 1
IdleConfig.HEALTH_WAVE_POWER = 2.3 -- forme de la courbe : plus grand = début plus dur, fin plus douce
IdleConfig.HEALTH_WAVE_OFFSET = 5 -- décale le facteur : plus grand = premières vagues plus dures
IdleConfig.REWARD_BUDGET = 8 -- pièces totales de la vague 1

function IdleConfig.healthBudget(wave: number): number
	wave = math.min(wave, IdleConfig.MAX_SCALING_WAVE)
	local offset = IdleConfig.HEALTH_WAVE_OFFSET
	local waveFactor = ((wave + offset) / (1 + offset)) ^ IdleConfig.HEALTH_WAVE_POWER
	return IdleConfig.HEALTH_BUDGET * IdleConfig.HEALTH_GROWTH ^ (wave - 1) * waveFactor
end

function IdleConfig.rewardBudget(wave: number): number
	wave = math.min(wave, IdleConfig.MAX_SCALING_WAVE)
	return IdleConfig.REWARD_BUDGET * IdleConfig.REWARD_GROWTH ^ (wave - 1)
end

-- Types de vagues. share = part du budget, count = nombre d'ennemis, gap = secondes entre deux.
-- Les parts sont réglées pour que chaque type bloque de temps en temps (murs variés) et que le Seigneur
-- de guerre reste le plus dur : les cavaliers et les écuyers sont rapides (moins de temps sous le feu des
-- tours), ils ont donc une plus petite part du budget ; les colosses sont lents, ils en ont une plus grosse.
-- Les pièces suivent les mêmes parts (une Garde colossale rapporte plus qu'une Charge de cavalerie).
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
			-- 15 écuyers au début (19 à la vague 13), jusqu'à 45 à partir de la vague 90
			return { { enemy = "Swarm", share = 0.68, count = 15 + math.min(wave // 3, 30), gap = 0.18 } }
		end,
	},
	Rush = {
		displayName = "Charge de cavalerie",
		hint = "Les cavaliers sont très rapides : ralentis-les !",
		groups = function(wave)
			return { { enemy = "Fast", share = 0.6, count = 12 + math.min(wave // 6, 12), gap = 0.3 } }
		end,
	},
	Giants = {
		displayName = "Garde colossale",
		hint = "De gigantesques chevaliers : concentre tes dégâts",
		groups = function(wave)
			return { { enemy = "Giant", share = 1.5, count = 2 + math.min(wave // 25, 2), gap = 3 } }
		end,
	},
	Boss = {
		displayName = "SEIGNEUR DE GUERRE",
		hint = "Un immense chevalier mène l'assaut : concentre toute ta puissance",
		groups = function(wave)
			-- Le Seigneur de guerre grossit avec les vagues : 0,4 du budget à la vague 10 (premier boss
			-- facile), 0,8 à partir de la vague 20 ; en plus de ses 6 fantassins. Plus, et ses murs
			-- dépassaient 2 h vers les vagues 70-100.
			return {
				{ enemy = "Normal", share = 0.4, count = 6, gap = 0.5 },
				{ enemy = "Boss", share = math.clamp(wave / 25, 0.4, 0.8), count = 1, gap = 0 },
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

return IdleConfig

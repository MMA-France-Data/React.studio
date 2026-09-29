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
-- Vague écrasée (demande du propriétaire : après une renaissance, remonter était lent, les ennemis mettaient
-- du temps à sortir même tués d'un coup) : quand plus AUCUN ennemi n'est en vie sur la parcelle et qu'il en
-- reste à faire apparaître, le suivant arrive TOUT DE SUITE (l'attente qui restait est sautée ; les écarts
-- entre les suivants ne changent pas). Jamais plus lent qu'avant. Une vague tuée dès la sortie des ennemis
-- se termine en ~1 pas de simulation par ennemi ; sinon chaque ennemi doit encore marcher jusqu'à la portée
-- de tes tours. Une vague dure (des ennemis encore en vie) garde son rythme normal. Horloge de la
-- simulation : marche aussi en Vitesse x2 (PlotGame:simulate). false = rythme normal toujours.
IdleConfig.COMPRESS_EMPTY_SPAWNS = true
-- Une unité meurt -> la suivante sort TOUT DE SUITE (demande du propriétaire : « quand une unité meurt, l'autre
-- sort instant »), même s'il reste d'autres ennemis en vie. Chaque mort fait sortir UN ennemi de la file en
-- avance (l'attente qui lui restait est sautée ; la suite de la file avance d'autant, les écarts entre les
-- suivants ne changent pas). Les ennemis sortent toujours aussi à l'heure normale : plus tu tues vite, plus la
-- vague sort vite ; si personne ne meurt, rythme normal. Les ennemis ne marchent pas plus vite (pas de
-- rattrapage). Une fuite ne fait rien sortir (elle termine la vague). Avec cette règle, la vague écrasée
-- ci-dessus ne sert presque plus (seulement si plus personne n'est en vie ET qu'aucune mort n'attend son
-- ennemi). false = seulement la vague écrasée.
IdleConfig.SPAWN_NEXT_ON_KILL = true

-- Rythme « souvent bloqué, souvent débloqué » : les PV montent un peu plus vite que les gains.
-- Au mur, tu farmes les vagues d'avant jusqu'à pouvoir t'offrir l'amélioration qui te débloque.
-- Les grands nombres viennent des vagues elles-mêmes : chaque vague rapporte 25 % de plus que la précédente
-- (x9 toutes les 10 vagues). Joueur actif (simulateur, sans forge ni renaissance) : ~1 milliard (B) de
-- pièces par minute vers 13 h de jeu, ~1 trillion (T) vers 23 h, ~1 quadrillion (Qa) vers 34 h,
-- ~1 quintillion (Qi) vers 46 h, et ça continue (voir tools/balance/RESULTS.md).
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
-- Machine à tours (Autel des héros) : les lancers se paient en pièces, par 1, 10, 100, 1 000, 10 000
-- ou 1 000 000. Chaque lancer acheté rend le suivant 0,05 % plus cher, pour toujours (voir towerSpinCost).
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
-- Les tours légendaires (dorées) sont RARES (demande du propriétaire : « les dorées doivent être plus rares ») :
-- aucune avant le record 60, puis 1 %, 2,5 % au record 100 et 4 % au record 200 (avant : 5 % dès la vague 25,
-- 12 % à la 50, 20 % à la 100 ; le joueur simulé avait sa 1re légendaire vers la vague 33-40). Maintenant
-- (tools/balance/RESULTS.md) : la 1re vers la vague 65-75, après ~8 h de jeu. Les Épiques sont un peu plus
-- rares aussi (8 % dès la vague 10, 26 % au plus). Les nombres peuvent avoir une virgule (2,5) : ce sont
-- des poids, l'autel affiche « 2.5 % ».
IdleConfig.TOWER_SPIN_TIERS = {
	{ minWave = 1, odds = { Common = 80, Rare = 20, Epic = 0, Legendary = 0 } },
	{ minWave = 10, odds = { Common = 62, Rare = 30, Epic = 8, Legendary = 0 } },
	{ minWave = 25, odds = { Common = 52, Rare = 34, Epic = 14, Legendary = 0 } },
	{ minWave = 45, odds = { Common = 46, Rare = 35, Epic = 19, Legendary = 0 } },
	{ minWave = 60, odds = { Common = 44, Rare = 35, Epic = 20, Legendary = 1 } },
	{ minWave = 100, odds = { Common = 39, Rare = 35, Epic = 23.5, Legendary = 2.5 } },
	{ minWave = 200, odds = { Common = 35, Rare = 35, Epic = 26, Legendary = 4 } },
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
-- minWave = record nécessaire pour voir le bouton.
-- Un lot coûte EXACTEMENT la somme des prix des lancers qu'il contient (voir towerSpinCost) : x100 coûte
-- autant que 100 x1 achetés un par un. Les gros boutons évitent juste de cliquer 100 000 fois.
-- ATTENTION, ne pas remettre de remise de gros, surtout sur x1 000 000.
-- Ici PV et pièces grandissent au même rythme (x1,25 par vague) : multiplier tous ses dégâts par M
-- fait avancer le record d'un facteur ~M^(1/2,55). Un million de lancers, c'est x1 500 à x3 500 de dégâts :
-- essayé à 5 000 lancers x1 le lot, le joueur simulé est passé de la vague 377 à la vague 600-1 000
-- en 6 h. Même x1 000 à moitié prix faisait arriver la vague 100 ~1 h 20 plus tôt.
-- Avec +0,05 % par lancer, un lot coûte toujours le même nombre de fois le prix du PROCHAIN lancer :
-- x10 = 10,02 ; x100 = 102,5 ; x1 000 = 1 297 ; x10 000 = 294 456 ; x1 000 000 = ~2,5e220 (« MAX » : ce total
-- dépasse les plus grands nombres possibles). Un joueur qui achète régulièrement garde le prix d'un lancer
-- vers 0,03 vague de gains (simulateur) : x100 ≈ 3 vagues de gains (un achat courant, dès le record 40 ;
-- le joueur simulé en achète dès le record ~60), x1 000 ≈ 40 vagues (~1 h de farm : un gros achat pour
-- joueur avancé, dès le record 150), x10 000 ≈ 9 000 vagues (un objectif à très long terme, dès le record
-- 300), x1 000 000 : presque mythique (record 1 000, toujours « MAX »).
IdleConfig.TOWER_SPIN_BULKS = {
	{ count = 1, minWave = 1 },
	{ count = 10, minWave = 1 },
	{ count = 100, minWave = 40 },
	{ count = 1000, minWave = 150 },
	{ count = 10000, minWave = 300 },
	{ count = 1000000, minWave = 1000 },
}

-- Prix de base d'UN lancer (towerSpinUnitCost, avant la hausse de +0,05 % par lancer déjà acheté) :
-- TOWER_SPIN_COST_WAVES vague de gains à ton record jusqu'à la vague TOWER_SPIN_DISCOUNT_WAVE, puis divisé
-- par (record / 10)^1,05 : le prix suit les pièces, mais de moins en moins vite. Il monte avec ton record,
-- pour que l'autel reste intéressant. En vagues de gains à ton record, avant la hausse (x1,0005 par lancer
-- acheté : x1,65 après 1 000 lancers, x3 après 2 200) :
--   record 1-10 : 1 lancer = 0,25 vague (x10 = 2,5)     record 40 : 0,059 (x100 = 6)
--   record 100  : 0,022 (x100 = 2,3)                     record 300 : 0,007     record 1 000 : 0,002
-- Réglé avec tools/balance (voir RESULTS.md) : c'est le réglage qui décide combien de lancers le joueur
-- achète, donc combien de doublons il a (chaque doublon donne +2 % de dégâts, DUPLICATE_DAMAGE_BONUS), donc
-- la vitesse de la partie. Puissance 0,9 : vague 100 vers 22 h mais des murs d'1 h vers les vagues 71-100 ;
-- 1,05 : vague 100 vers 15 h ; 1,3 : vers 12 h (trop tôt) ; 1,5 : vers 11 h. La hausse de +0,05 % par
-- lancer limite déjà les doublons (voir le rapport : lancers achetés à 1, 10, 25, 50 et 100 h).
IdleConfig.TOWER_SPIN_COST_WAVES = 0.25
IdleConfig.TOWER_SPIN_DISCOUNT_WAVE = 10
IdleConfig.TOWER_SPIN_DISCOUNT_POWER = 1.05

-- Record « propre » pour les prix et les chances (une valeur abîmée compte comme la vague 1).
local function cleanRecord(highestWave: any): number
	if typeof(highestWave) ~= "number" or highestWave ~= highestWave then
		return 1
	end
	return math.clamp(math.floor(highestWave), 1, IdleConfig.MAX_SCALING_WAVE)
end

-- Prix de base d'un lancer à ce record (arrondi à 2 chiffres, au moins 1 pièce). Toujours fini : les
-- pièces arrêtent de grandir à MAX_SCALING_WAVE.
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

-- Hausse des prix : chaque lancer acheté rend le suivant 0,05 % plus cher (x1,0005), POUR TOUJOURS.
-- Le compteur (idle.towerSpinsBought, lancers achetés depuis toujours) ne repart jamais à zéro : ni à la
-- renaissance, ni chaque jour. Les lots marchent pareil : x10 = les 10 prochains prix additionnés.
--   prix du n-ième lancer acheté (n = 0, 1, 2...) = prix de base (towerSpinUnitCost) x 1,0005^n
-- Exemples : après 1 000 lancers, un lancer coûte x1,65 ; après 10 000, x148 ; après 20 000, x22 000.
IdleConfig.TOWER_SPIN_PRICE_GROWTH = 1.0005
-- Plus grand compteur gardé (un nombre entier exact, sauvegardable). Bien avant, le prix est « MAX » :
-- 1,0005^n dépasse ~1,8e308 vers n = 1,4 million.
IdleConfig.TOWER_SPINS_BOUGHT_MAX = 1e15

-- Compteur « propre » : entier, entre 0 et TOWER_SPINS_BOUGHT_MAX (une valeur abîmée, NaN, négative ou
-- pas un nombre, compte comme 0).
function IdleConfig.cleanSpinsBought(bought: any): number
	if typeof(bought) ~= "number" or bought ~= bought or bought < 0 then
		return 0
	end
	return math.min(math.floor(bought), IdleConfig.TOWER_SPINS_BOUGHT_MAX)
end

-- Prix total de `count` lancers d'un coup à ce record, quand `bought` lancers ont déjà été achetés
-- (rien = 0) : la somme des `count` prochains prix.
--   prix = prix de base x 1,0005^bought x (1,0005^count - 1) / (1,0005 - 1)
-- Ex. prix de base 100, 0 lancer acheté : x1 = 100, puis x1 = 100,05 ; x10 = 1 002,25.
-- Renvoie math.huge si le total dépasse les plus grands nombres possibles (ou si count n'est pas un
-- nombre entier de lancers) : cet achat est impossible (le serveur refuse, l'autel affiche « MAX »).
function IdleConfig.towerSpinCost(highestWave: number, count: number, bought: number?): number
	if typeof(count) ~= "number" or count ~= count or count < 1 or count ~= math.floor(count) or count == math.huge then
		return math.huge
	end
	local growth = IdleConfig.TOWER_SPIN_PRICE_GROWTH
	-- Somme de 1 + g + g^2 + ... + g^(count - 1). Divisé par (growth - 1) tel que calculé : x1 = 1 tout juste.
	local sum = if growth == 1 then count else (growth ^ count - 1) / (growth - 1)
	local cost = IdleConfig.towerSpinUnitCost(highestWave) * growth ^ IdleConfig.cleanSpinsBought(bought) * sum
	if cost ~= cost or cost >= math.huge then
		return math.huge
	end
	return cost
end

-- Prix du prochain lancer (x1) quand `bought` lancers ont déjà été achetés.
function IdleConfig.towerSpinPrice(highestWave: number, bought: number?): number
	return IdleConfig.towerSpinCost(highestWave, 1, bought)
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
-- Forge runique (machine à bonus) : la rune obtenue va dans ton inventaire, puis se pose sur une tour
-- (une seule rune par tour ; en poser une nouvelle remplace l'ancienne).
-- Lancers en pièces : PLUS de délai d'attente (avant : 1 toutes les 30 minutes). Le prix monte à chaque
-- lancer en pièces, POUR TOUJOURS (compteur idle.forgeSpinsBought, jamais remis à zéro, ni à la renaissance) :
--   1er lancer : FORGE_FIRST_PRICE (100 K), puis x5 à chaque lancer tant que le prix est sous 1 T, puis x2 :
--   100 K, 500 K, 2,5 M, 12,5 M, 62,5 M, 312 M, 1,56 B, 7,81 B, 39 B, 195 B, 976 B (11e), 4,88 T (12e),
--   9,76 T, 19,5 T, 39 T... (voir forgeCoinPrice).
-- Lancers en Robux (Config.Products.BONUS_SPIN) : à volonté ; ils ne comptent pas et ne font pas monter le prix.
-- Tirage : une rune n'est tirée que si elle AMÉLIORE au moins une tour posée (voir forgeDrawableRunes), avec
-- les chances des runes restantes remises sur 100 %. Les runes de l'inventaire ne comptent pas.
----------------------------------------------------------------------
IdleConfig.MAX_BONUS_INVENTORY = 50
IdleConfig.FORGE_FIRST_PRICE = 100e3 -- prix du tout premier lancer en pièces
IdleConfig.FORGE_FAST_GROWTH = 5 -- x5 par lancer tant que le prix est sous FORGE_GROWTH_SWITCH
IdleConfig.FORGE_SLOW_GROWTH = 2 -- puis x2 par lancer
IdleConfig.FORGE_GROWTH_SWITCH = 1e12 -- 1 T
-- Messages quand aucune rune ne peut améliorer une tour : la forge est bloquée (pièces ET Robux).
IdleConfig.FORGE_NO_TOWER = "Pose d'abord une tour"
IdleConfig.FORGE_ALL_BEST = "Toutes tes tours ont le meilleur bonus"
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

-- Prix du prochain lancer de la forge en pièces quand `bought` lancers en pièces ont déjà été achetés
-- (0 = le tout premier) : FORGE_FIRST_PRICE, x FORGE_FAST_GROWTH par lancer tant que le prix est sous
-- FORGE_GROWTH_SWITCH, puis x FORGE_SLOW_GROWTH par lancer.
--   bought = 0 -> 100 K, 1 -> 500 K, 10 -> 976 B, 11 -> 4,88 T, 12 -> 9,76 T, 13 -> 19,5 T...
-- Un compteur abîmé compte comme 0 (cleanSpinsBought). Renvoie math.huge quand le prix dépasse les plus
-- grands nombres possibles (vers 1 000 lancers) : achat impossible, la forge affiche « MAX ».
-- Le serveur calcule le prix avec SES données (PlotGame:spinBonusWithCoins) et le publie dans l'attribut
-- ForgeCoinPrice du joueur ; la forge du client peut aussi l'appeler avec l'attribut ForgeSpinsBought.
function IdleConfig.forgeCoinPrice(bought: any): number
	local left = IdleConfig.cleanSpinsBought(bought)
	local price = IdleConfig.FORGE_FIRST_PRICE
	-- Phase x5 : une dizaine de tours de boucle au plus (le prix dépasse vite 1 T).
	while left > 0 and price < IdleConfig.FORGE_GROWTH_SWITCH and IdleConfig.FORGE_FAST_GROWTH > 1 do
		price *= IdleConfig.FORGE_FAST_GROWTH
		left -= 1
	end
	price *= IdleConfig.FORGE_SLOW_GROWTH ^ left
	if price ~= price or price >= math.huge then
		return math.huge
	end
	return price
end

-- Valeur de la rune posée sur une tour (bonusId = son id, nil = pas de rune) : son multiplicateur, 1 sans
-- rune. La rune x2 vitesse d'attaque compte comme x2 dégâts (palier 2).
function IdleConfig.runeValue(bonusId: any): number
	local bonus = typeof(bonusId) == "string" and IdleConfig.BONUS_BY_ID[bonusId]
	return if bonus then bonus.mult else 1
end

-- Runes que la forge peut tirer. weakestRune = la plus petite valeur de rune (runeValue) parmi les tours
-- POSÉES, nil s'il n'y a aucune tour. Une rune n'est tirable que si elle améliore au moins une tour : sa
-- valeur doit dépasser weakestRune (une rune de valeur m est exclue quand toutes les tours posées ont déjà
-- une rune de valeur >= m). Renvoie (liste des runes tirables, dans l'ordre de BONUSES ; raison du blocage,
-- nil si la liste n'est pas vide : FORGE_NO_TOWER ou FORGE_ALL_BEST).
function IdleConfig.forgeDrawableRunes(weakestRune: number?)
	local list = {}
	if weakestRune == nil then
		return list, IdleConfig.FORGE_NO_TOWER
	end
	for _, bonus in IdleConfig.BONUSES do
		if bonus.mult > weakestRune then
			table.insert(list, bonus)
		end
	end
	if #list == 0 then
		return list, IdleConfig.FORGE_ALL_BEST
	end
	return list, nil
end

-- Chances affichées par la forge, en %, pour une liste de runes tirables (chances remises sur 100 %) :
-- { [id] = pourcentage }. Liste vide -> {}.
function IdleConfig.forgeOdds(drawable): { [string]: number }
	local total = 0
	for _, bonus in drawable do
		total += bonus.chance
	end
	local odds = {}
	for _, bonus in drawable do
		odds[bonus.id] = if total > 0 then bonus.chance / total * 100 else 0
	end
	return odds
end

-- La meilleure rune (plus grand multiplicateur) : donnée par un achat Robux qui arrive quand la forge est
-- bloquée (le bouton Robux est bloqué côté client, mais un achat payé n'est jamais perdu).
function IdleConfig.bestRune()
	local best = IdleConfig.BONUSES[1]
	for _, bonus in IdleConfig.BONUSES do
		if bonus.mult > best.mult then
			best = bonus
		end
	end
	return best
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
--   PV totaux de la vague w = HEALTH_BUDGET x HEALTH_GROWTH^(w - 1) x ((w + 5) / 6)^2,55
--   pièces de la vague w    = REWARD_BUDGET x REWARD_GROWTH^(w - 1) x bonus de début (voir plus bas)
-- Le facteur ((w + 5) / 6)^2,55 fait monter les PV bien plus vite que les pièces au début, puis de moins
-- en moins : d'une vague à la suivante, PV x1,47 à la vague 10, x1,36 à la 25, x1,31 à la 50, x1,28 à la
-- 100, x1,27 à la 200 (pièces toujours x1,25).
-- Comme PV et pièces grandissent au même rythme (x1,25), seul ce facteur les sépare : multiplier tous ses
-- dégâts par M (doublons, forge, bonus de renaissance) fait avancer le record d'un facteur ~M^(1/2,55).
-- Résultat (simulateur, joueur actif sans forge ni renaissance, voir tools/balance/RESULTS.md) : vague 10
-- vers 6 min sans mur, premier mur vers la vague 16 (2 min), vague 25 vers 33 min, vague 50 vers 4 h 20,
-- vague 100 vers 16 h 30 ; murs de ~2 min (vagues 11-30), ~9 min (31-70), ~16 min (71-100) en médiane,
-- ~29 min après la vague 100 (mais 1 mur sur 5 dépasse 22 min pour 31-70 et 33 min pour 71-100).
-- Exemples : vague 10 -> 1,4 K PV et 59 pièces (82 avec le bonus de début), vague 50 -> 286 M PV et 448 K pièces,
-- vague 100 -> 104 T PV et 31 B pièces, vague 200 -> 2,8 Sp PV et 154 Qi pièces.
-- Sans limite, les PV deviendraient infinis vers la vague 3 100 (au-delà de ~1,8e308, Luau passe à
-- l'infini et un DataStore ne sait pas le sauver) : à partir de MAX_SCALING_WAVE, PV et pièces arrêtent
-- de grandir.
IdleConfig.MAX_SCALING_WAVE = 3000
IdleConfig.HEALTH_BUDGET = 18 -- PV totaux de la vague 1
-- Forme de la courbe : plus grand = PV plus hauts partout, et de plus en plus loin dans le jeu. 2,55 (2,4
-- avant) : avec le colosse et le Seigneur de guerre plus légers (GIANT_SHARE, BOSS_SHARE_MAX), la vague 100
-- arrivait vers 11 h (tools/balance/RESULTS.md).
IdleConfig.HEALTH_WAVE_POWER = 2.55
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
-- colossale d'avant, qui rapporte 3 fois moins qu'une Escarmouche : ces murs restent parmi les plus longs
-- avant la vague 100 (simulateur). Essayé (tools/balance) : une Garde qui rapporte 0,8 à 1 fois une
-- Escarmouche raccourcit les murs des vagues 31-70, pas ceux des vagues 71-100, et la vague 100 arrive
-- plus tôt : gardé tel quel.
IdleConfig.WAVE_TYPES = {
	Mixed = {
		displayName = "Escarmouche",
		hint = "Fantassins, cavaliers et garde lourde",
		groups = function(wave)
			return {
				{ enemy = "Normal", share = 0.5, count = 6 + math.min(wave // 8, 8), gap = 0.6 },
				{ enemy = "Fast", share = 0.2, count = 3 + math.min(wave // 10, 6), gap = 0.4 },
				{ enemy = "Tank", share = IdleConfig.MIXED_TANK_SHARE, count = 1 + math.min(wave // 12, 4), gap = 1.2 },
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
			-- UN SEUL colosse (avant : 2 à 4 colosses et une part de 1,5). Part GIANT_SHARE (plus bas) : à 1 ou
			-- 1,5, seules les tours qui le visent comptent et ses murs dépassaient 30 min à 1 h dès la vague 25.
			return { { enemy = "Giant", share = IdleConfig.GIANT_SHARE, count = 1, gap = 0 } }
		end,
	},
	Boss = {
		displayName = "SEIGNEUR DE GUERRE",
		hint = "Un immense chevalier mène l'assaut : concentre toute ta puissance",
		groups = function(wave)
			-- UN SEUL Seigneur de guerre, escorté de 6 fantassins.
			-- Il grossit avec les vagues : BOSS_SHARE_MIN du budget à la vague 10 (premier boss facile), puis
			-- wave / 40, jusqu'à BOSS_SHARE_MAX (plus bas). Avant, 0,8 : seul, il bloquait 20 à 30 min dès la vague 30.
			return {
				{ enemy = "Normal", share = 0.4, count = 6, gap = 0.5 },
				{ enemy = "Boss", share = math.clamp(wave / 40, IdleConfig.BOSS_SHARE_MIN, IdleConfig.BOSS_SHARE_MAX), count = 1, gap = 0 },
			}
		end,
	},
}
-- Parts du budget de PV (et de pièces) des chevaliers lourds d'une Escarmouche, du colosse et du Seigneur de
-- guerre. Réglées avec tools/balance (voir RESULTS.md) : colosse et Seigneur de guerre 0,5 -> 0,33. Avec la
-- règle « une unité meurt, la suivante sort », la visée « foule » du Trébuchet et le Trébuchet moins fort
-- contre un ennemi seul, leurs murs duraient 40 min à plus d'1 h vers les vagues 60-100.
IdleConfig.MIXED_TANK_SHARE = 0.37
IdleConfig.GIANT_SHARE = 0.33
IdleConfig.BOSS_SHARE_MIN = 0.3
IdleConfig.BOSS_SHARE_MAX = 0.33

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

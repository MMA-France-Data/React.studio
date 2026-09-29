-- Tours du mode infini (ta parcelle). Indépendantes des tours du ranked.
-- Au départ seul l'Archer du rempart est débloqué ; les autres se gagnent à la machine à tours
-- (rareté = chance de l'obtenir). Doublons et bonus de la machine à bonus s'appliquent en plus.
--
-- Équilibrage (réglé avec tools/balance, qui simule maintenant les projectiles, le feu des flèches, la petite
-- zone du Mage et le rayon du Sorcier exactement comme PlotGame.luau : voir tools/balance/RESULTS.md). Toutes
-- les tours ont le même prix d'amélioration à un niveau donné, donc à niveau égal on compare leurs stats.
-- Chacune a son rôle (banc d'essai, une seule fuite = vague ratée) :
--   Archer du rempart   -> tireur rapide à longue portée (21) et flèches enflammées : fort contre les files
--                          d'ennemis et sur les vagues de boss (il tue aussi l'escorte) ; garde un vrai rôle
--                          toute la partie (le joueur simulé l'améliore encore après la vague 100)
--   Totem de givre      -> ralentit tout (-60 %) : le meilleur soutien, surtout contre Levées et Charges
--   Catapulte           -> grosse zone contre les foules tassées
--   Mage des tempêtes   -> contrôle : petite zone (2,5) + ralentissement pour les ennemis collés
--   Baliste lourde      -> gros carreaux à longue portée (30), la tour « à tout faire » du joueur simulé
--   Sorcier des arcanes -> rayon qui monte : bat la Baliste contre les lents (boss, colosse, chevaliers
--                          lourds), perd contre les rapides ; très fort avec un Totem de givre
--   Oracle / Trébuchet  -> légendaires, rares : bien plus fortes à niveau égal (elles ont peu de doublons)
-- Les tours communes reçoivent beaucoup plus de doublons que les légendaires, ce qui les garde utiles.
-- La portée compte énormément : 30 pour la Baliste couvre ~2 fois plus de chemin que 21 pour l'Archer,
-- 70 pour le Trébuchet couvre tout le chemin ; ces tours ont donc moins de dégâts par seconde.
-- Projectiles (flèches, rochers, carreaux, pierres) : la tour vise l'endroit où sera l'ennemi, et les dégâts
-- tombent à l'impact, pas au moment du tir (voir PlotGame.luau).
-- Façons de toucher (kind) :
--   "Single" : une cible ; "Splash" : une zone autour du point d'impact (rayon `splash`) ;
--   "Aura" : tous les ennemis à portée ; "Chain" : un éclair qui rebondit ; "Beam" : rayon continu.
-- Avec projectileSpeed (studs par seconde), la tour lance un projectile (temps de vol : flightTime) ;
-- sans, elle touche tout de suite.
local IdleConfig = require(script.Parent.IdleConfig)

local IdleTowers = {}

IdleTowers.ORDER = { "MachineGun", "Frost", "Bomb", "Tesla", "Rocket", "Laser", "Chain", "Orbital" }

-- Temps de vol maximal d'un projectile, en secondes de simulation : il voyage sur 1 octet (en centièmes
-- de seconde, 2,55 s au plus) dans le paquet des tirs (PlotGame.luau). Un réglage plus long est coupé ici.
IdleTowers.MAX_FLIGHT_TIME = 2.5
-- Flèche dont la cible est morte pendant le vol : elle touche l'ennemi vivant le plus proche du point
-- d'impact s'il est à moins de ce rayon (en studs), sinon elle est perdue (mais enflamme quand même le sol).
IdleTowers.PROJECTILE_CATCH_RADIUS = 1.5
-- Zones de feu actives au plus sur une parcelle (toutes tours confondues) : au-delà, la plus vieille s'éteint.
IdleTowers.FIRE_MAX_PER_PLOT = 30

IdleTowers.Defs = {
	MachineGun = {
		rarity = "Common",
		displayName = "Archer du rempart",
		description = "", -- écrite plus bas (elle cite fireDamageRatio)
		kind = "Single",
		targeting = "First",
		color = Color3.fromRGB(72, 126, 70),
		placeCost = 10,
		damage = 3,
		-- 21 (15 avant) : le banc d'essai le laissait au niveau 1 vers la vague 40, le Mage et le Sorcier
		-- faisaient plus de dégâts par pièce. Il couvre maintenant ~2 fois plus de chemin.
		range = 21,
		cooldown = 0.2,
		projectileSpeed = 90, -- flèche rapide : ~0,1 à 0,25 s de vol
		-- Flèches enflammées : chaque flèche laisse au sol, là où elle tombe, une petite zone de feu qui
		-- brûle tous les ennemis dedans. Dégâts du feu par seconde = fireDamageRatio x dégâts de la flèche
		-- (niveaux, doublons et runes de dégâts comptent donc aussi pour le feu), un coup toutes les fireTick s.
		-- Une flèche qui tombe dans une zone de la même tour la ravive (elle repart pour fireDuration s) au
		-- lieu d'en créer une autre ; fireMaxPatches zones par tour au plus (la plus vieille s'éteint).
		-- Réglé avec tools/balance (voir tools/balance/RESULTS.md) : à 10 % par seconde et rayon 2,25, le feu ne
		-- changeait presque rien (+5 % de puissance contre les files d'ennemis) ; à 40 % et rayon 2,5, il rend
		-- l'Archer ~30 % plus fort contre les Escarmouches, les Charges et les Levées. Rayon < 4 : un ennemi à
		-- 4 studs de l'impact ne brûle pas (test Studio).
		fireRadius = 2.5,
		fireDuration = 2,
		fireDamageRatio = 0.4,
		fireTick = 0.5,
		fireMaxPatches = 5,
	},
	Frost = {
		rarity = "Common",
		displayName = "Totem de givre",
		description = "Une rune glaciale blesse et ralentit fortement les troupes proches.",
		kind = "Aura",
		color = Color3.fromRGB(150, 230, 255),
		placeCost = 25,
		-- Touche tous les ennemis proches à chaque seconde : la meilleure tour contre les Levées d'écuyers et
		-- les Charges de cavalerie, et la plus forte de toutes au début (simulateur). 6 dégâts (4,2 avant,
		-- « il ne fait presque pas de dégâts ») : comme les ennemis restent 2 fois plus longtemps dans son
		-- aura, chaque passage fait ~2 fois plus de dégâts qu'avant. Plus (8 dégâts, portée 12, -65 %), il
		-- était la meilleure tour contre presque tout jusqu'à la vague 100 : les autres ne servaient plus.
		damage = 6,
		range = 11,
		cooldown = 1,
		-- -60 % de vitesse (25 % avant, presque invisible). Dure 2,5 s : plus que le temps entre deux
		-- impulsions (1 s), donc un ennemi dans l'aura reste ralenti tout le temps, et encore un peu après.
		-- Les ralentissements ne s'additionnent pas : le plus fort gagne (applySlow dans PlotGame.luau).
		slow = 0.6,
		slowDuration = 2.5,
	},
	Bomb = {
		rarity = "Rare",
		displayName = "Catapulte",
		description = "Projette des rochers sur une zone : idéale contre les hordes.",
		kind = "Splash",
		targeting = "First",
		color = Color3.fromRGB(240, 130, 50),
		placeCost = 40,
		damage = 17, -- ses rochers écrasent les foules : bonne contre les Levées d'écuyers dès le début
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
		description = "Foudroie une petite zone : blesse et ralentit les ennemis collés les uns aux autres.",
		-- La foudre tombe tout de suite (pas de projectile) sur l'ennemi de tête, et touche aussi ceux
		-- qui sont collés à lui : tous prennent les dégâts ET le ralentissement (le plus fort gagne).
		kind = "Splash",
		targeting = "First",
		color = Color3.fromRGB(250, 230, 80),
		placeCost = 50,
		-- Réglé avec tools/balance : avec sa zone, le ralentissement touche plusieurs ennemis à chaque éclair.
		-- À 14 dégâts, -60 % pendant 1,2 s et rayon 3, plusieurs Mages ralentissaient TOUTE la vague : il était
		-- 4 à 10 fois meilleur que les autres tours contre les Escarmouches, Levées et Charges (banc d'essai) et
		-- remplaçait tout, Catapulte comprise. Maintenant : parmi les 2-3 meilleures contre les Levées et les
		-- Charges, un vrai soutien (ralentissement), sans écraser le Totem ni la Catapulte.
		damage = 10,
		range = 16,
		cooldown = 0.8,
		splash = 2.5, -- vraiment petite : un tiers de la Catapulte (7) ; touche les ennemis collés à sa cible
		slow = 0.3, -- -30 % (le Totem : -60 %) ; les ralentissements ne s'additionnent pas, le plus fort gagne
		slowDuration = 0.8,
	},
	Rocket = {
		rarity = "Epic",
		displayName = "Baliste lourde",
		description = "Un trait dévastateur à longue portée contre chevaliers lourds et boss.",
		kind = "Splash",
		targeting = "Strongest",
		color = Color3.fromRGB(200, 60, 60),
		placeCost = 80,
		-- 50 (40 avant) : le Sorcier des arcanes, aussi Épique, faisait mieux qu'elle contre tous les types de
		-- vague (banc d'essai) ; maintenant elle le bat contre les Levées d'écuyers au début.
		damage = 50,
		range = 30,
		cooldown = 4, -- tire rarement : excellente contre les gros, faible contre les foules
		splash = 2,
		projectileSpeed = 75, -- carreau lourd, tir tendu : ~0,15 à 0,45 s de vol
	},
	Laser = {
		rarity = "Epic",
		displayName = "Sorcier des arcanes",
		description = "", -- écrite plus bas (elle cite beamRampMax)
		-- Rayon continu : il s'accroche à l'ennemi le plus résistant à portée et le GARDE tant qu'il est
		-- vivant et à portée (il ne change jamais de cible pour un ennemi plus fort : ça remettrait la
		-- montée à zéro). Dégâts par seconde = damage x montée, montée = min(beamRampMax, 1 + beamRampRate x
		-- secondes sur cette cible), à chaque pas de simulation. Les ennemis lents (boss, colosses, chevaliers
		-- lourds, ennemis gelés par le Totem) restent assez longtemps pour prendre la montée entière ; les
		-- cavaliers traversent sa portée avant qu'il chauffe. Il est plus fort dans un virage du chemin, où
		-- la cible reste longtemps à portée.
		-- Niveaux, doublons et runes de dégâts multiplient `damage` ; la rune x2 vitesse d'attaque double la
		-- vitesse de montée, voir effectiveStats.
		-- Réglé avec tools/balance (duels du rapport : UNE tour contre UN ennemi qui traverse tout le chemin,
		-- même niveau, 3 meilleurs emplacements). Montée lente et haute : peu de dégâts au début (7/s, moins
		-- que la Baliste), beaucoup après quelques secondes sur la même cible. Les ennemis lents restent assez
		-- longtemps pour la prendre, les rapides non. Duels contre la Baliste lourde : Seigneur de guerre x1,7,
		-- colosse x2,1, chevalier lourd x1,35, mais fantassin x0,95, cavalier x0,8, écuyer x0,8 ; avec un Totem
		-- de givre à côté : x3 contre les boss. Sur une vraie vague de boss (6 fantassins d'escorte à tuer aussi,
		-- une seule fuite = ratée), il fait à peu près comme la Baliste : pas de victoire automatique.
		-- Avant : 20/s, +1,5/s, x6 : il battait la Baliste contre TOUT, cavaliers compris (x1,75). À 6,5/s, le
		-- joueur simulé ne s'en servait plus après la vague 50 ; à 7,5/s, il devenait presque aussi bon que la
		-- Baliste contre les cavaliers (x0,85).
		kind = "Beam",
		targeting = "Strongest", -- seulement pour choisir une nouvelle cible
		color = Color3.fromRGB(255, 70, 200),
		placeCost = 120,
		damage = 7, -- dégâts PAR SECONDE au début du rayon (montée x1) : la Baliste fait 12,5/s
		range = 14, -- 18 avant : les ennemis rapides la traversent plus vite
		beamRampRate = 2, -- +2 par seconde sur la même cible
		beamRampMax = 25, -- x25 au plus (175/s au niveau 1), atteint après 12 s sur la même cible
	},
	Chain = {
		rarity = "Legendary",
		displayName = "Oracle de la foudre",
		description = "Un éclair ancien rebondit entre quatre ennemis.",
		kind = "Chain",
		targeting = "First",
		color = Color3.fromRGB(150, 110, 255),
		placeCost = 250,
		-- par ennemi touché (4 ennemis par éclair). 50 (18 avant) : les légendaires sont maintenant rares (la
		-- première vers la vague 65-70, IdleConfig.TOWER_SPIN_TIERS) et ont très peu de doublons, alors que les
		-- tours communes en ont des centaines à ce moment-là (+200 à +600 % de dégâts). À 18, 32 ou 40, le joueur
		-- simulé ne la posait jamais (0 % des dégâts). À niveau égal et sans doublons, elle est la meilleure
		-- contre les Escarmouches, les Levées, les Charges et les boss ; avec les doublons du joueur, à égalité
		-- avec le Totem de givre.
		damage = 50,
		range = 20,
		cooldown = 1.2,
		chains = 4,
	},
	Orbital = {
		rarity = "Legendary",
		displayName = "Trébuchet royal",
		description = "Une pierre runique frappe l'ennemi le plus résistant, où qu'il soit.",
		kind = "Splash",
		targeting = "Strongest",
		color = Color3.fromRGB(120, 240, 255),
		placeCost = 400,
		-- 70 (40 avant) : légendaire rare, peu de doublons (voir l'Oracle). Il touche tout le chemin (portée 70) :
		-- le meilleur contre la Garde colossale à niveau égal, le Sorcier reste devant avec ses doublons.
		damage = 70,
		range = 70,
		cooldown = 5,
		splash = 5,
		-- Grande cloche : vol = distance / 45 studs par seconde, 0,8 s au moins (~0,8 à 1,6 s).
		projectileSpeed = 45,
		projectileMinFlight = 0.8,
	},
}

-- Nombre écrit à la française : 0.1 -> "0,1", 7 -> "7".
local function frenchNumber(value: number): string
	return (string.gsub(string.format("%g", value), "%.", ","))
end

-- Textes qui citent des réglages : écrits ici pour rester justes quand on change les chiffres.
do
	local archer = IdleTowers.Defs.MachineGun
	archer.description = `Flèches enflammées : chaque flèche laisse une petite zone de feu qui brûle les ennemis ({frenchNumber(archer.fireDamageRatio * 100)} % de ses dégâts par seconde).`
	local sorcerer = IdleTowers.Defs.Laser
	sorcerer.description = `Rayon continu : ses dégâts montent tant qu'il reste sur la même cible (jusqu'à x{frenchNumber(sorcerer.beamRampMax)}). Terrible contre les boss et les colosses, faible contre les ennemis rapides.`
end

-- Améliorations : niveaux illimités. Chaque niveau multiplie les dégâts, et chaque
-- amélioration coûte plus cher que la précédente (réglages dans IdleConfig).
-- Le prix est le même pour toutes les tours : avant, il suivait le prix de pose, et à dépense égale
-- l'Archer (10 pièces) finissait 5 fois plus fort qu'un Trébuchet (400 pièces).
local statsCache = {}

-- Stats effectives d'une tour à un niveau donné (dégâts multipliés par le niveau).
function IdleTowers.stats(towerType: string, level: number)
	local key = towerType .. ":" .. level
	local cached = statsCache[key]
	if cached then
		return cached
	end
	local def = IdleTowers.Defs[towerType]
	local stats = table.clone(def)
	stats.damage = def.damage * IdleConfig.UPGRADE_DAMAGE ^ (level - 1)
	statsCache[key] = stats
	return stats
end

-- Prix pour passer du niveau `level` au niveau `level + 1` : 20, 27, 36... (x1,35 par niveau), le même
-- pour toutes les tours. towerType est gardé pour les appels existants (PlotGame, PlotUI).
-- Niveau 100 -> 160 T, niveau 1000 -> 3,2e131 : toujours un nombre fini.
function IdleTowers.upgradeCost(_towerType: string, level: number): number
	local raw = IdleConfig.UPGRADE_COST_BASE * IdleConfig.UPGRADE_COST_GROWTH ^ (level - 1)
	if raw >= math.huge then
		-- Au-delà du niveau ~2 350 le prix devient infini : « MAX », jamais payable (sans ce test, l'arrondi
		-- ci-dessous donnerait NaN : « pièces < NaN » est faux, l'achat passerait et les pièces deviendraient NaN).
		return math.huge
	end
	local magnitude = 10 ^ math.max(0, math.floor(math.log10(raw)) - 1)
	return math.floor(raw / magnitude + 0.5) * magnitude
end

-- Stats finales d'une tour posée : niveau + doublons (+2 % chacun, IdleConfig.DUPLICATE_DAMAGE_BONUS)
-- + bonus de la machine à bonus. Le tableau renvoyé ne doit jamais être modifié (il peut être partagé).
function IdleTowers.effectiveStats(towerType: string, level: number, dupes: number?, bonusId: string?)
	local base = IdleTowers.stats(towerType, level)
	local bonus = bonusId and IdleConfig.BONUS_BY_ID[bonusId]
	if (dupes or 0) == 0 and not bonus then
		return base
	end
	local stats = table.clone(base)
	stats.damage *= 1 + (dupes or 0) * IdleConfig.DUPLICATE_DAMAGE_BONUS
	if bonus and bonus.kind == "Damage" then
		stats.damage *= bonus.mult
	elseif bonus and bonus.kind == "Speed" then
		if stats.kind == "Beam" then
			-- Rayon continu : pas de coups à accélérer, la rune fait chauffer le rayon plus vite
			-- (x2 vitesse : la montée va 2 fois plus vite, le maximum ne change pas).
			stats.beamRampRate *= bonus.mult
		else
			stats.cooldown /= bonus.mult
		end
	end
	return stats
end

-- Dégâts par seconde (une Foudre en chaîne compte toutes ses cibles). Rayon continu : au début (x1),
-- voir beamMaxDps pour le maximum. Le feu des flèches n'est pas compté (voir fireDps).
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

-- Dégâts par seconde quand le rayon est au maximum.
function IdleTowers.beamMaxDps(stats): number
	return stats.damage * stats.beamRampMax
end

-- Secondes sur la même cible pour atteindre le maximum.
function IdleTowers.beamRampSeconds(stats): number
	return (stats.beamRampMax - 1) / stats.beamRampRate
end

-- Dégâts totaux du rayon entre 0 et `seconds` secondes sur la même cible (intégrale de la montée).
-- Sert aux tests et au banc d'essai ; le jeu applique la même chose pas à pas (PlotGame:beamStep).
function IdleTowers.beamDamage(stats, seconds: number): number
	seconds = math.max(0, seconds)
	local rampTime = IdleTowers.beamRampSeconds(stats)
	if seconds <= rampTime then
		return stats.damage * (seconds + stats.beamRampRate * seconds * seconds / 2)
	end
	local rising = rampTime + stats.beamRampRate * rampTime * rampTime / 2
	return stats.damage * (rising + (seconds - rampTime) * stats.beamRampMax)
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

-- Dégâts par seconde d'une zone de feu (0 si la tour n'a pas de flèches enflammées).
function IdleTowers.fireDps(stats): number
	return if stats.fireRadius then stats.damage * stats.fireDamageRatio else 0
end

function IdleTowers.dps(towerType: string, level: number): number
	return IdleTowers.dpsOf(IdleTowers.stats(towerType, level))
end

function IdleTowers.ofRarity(rarity: string): { string }
	local list = {}
	for _, towerType in IdleTowers.ORDER do
		if IdleTowers.Defs[towerType].rarity == rarity then
			table.insert(list, towerType)
		end
	end
	return list
end

return IdleTowers

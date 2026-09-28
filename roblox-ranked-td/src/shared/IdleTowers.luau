-- Tours du mode infini (ta parcelle). Indépendantes des tours du ranked.
-- Au départ seul l'Archer du rempart est débloqué ; les autres se gagnent à la machine à tours
-- (rareté = chance de l'obtenir). Doublons et bonus de la machine à bonus s'appliquent en plus.
--
-- Équilibrage (réglé avec le banc d'essai de tools/balance) : toutes les tours ont le même prix
-- d'amélioration à un niveau donné, donc à niveau égal on compare directement leurs stats.
-- Plus une tour est rare, plus elle est forte, et chaque type de vague a sa meilleure tour (banc d'essai) :
--   Escarmouche et Charge de cavalerie -> l'Archer au début, puis l'Oracle de la foudre (éclairs sur 4 ennemis)
--   Levée des écuyers                  -> Totem de givre et Catapulte au début, puis Trébuchet et Oracle
--   Garde colossale                    -> l'Archer au début, puis le Sorcier des arcanes (vise le plus résistant)
--   Seigneur de guerre                 -> le Mage des tempêtes (son ralentissement garde le boss sous le feu),
--                                         puis le Trébuchet royal ; la Baliste lourde aide beaucoup en soutien
-- Le joueur simulé change de tours au fil du jeu : Archer, Totem, Mage et Baliste au début, Trébuchet et
-- Oracle vers les vagues 26-50, Catapulte et Trébuchet vers 51-100, Sorcier et Baliste après la vague 100.
-- Les tours communes reçoivent beaucoup plus de doublons que les légendaires, ce qui les garde utiles.
-- La portée compte énormément : 30 pour la Baliste couvre ~3 fois plus de chemin que 15 pour l'Archer,
-- 70 pour le Trébuchet couvre tout le chemin ; ces tours ont donc moins de dégâts par seconde.
local IdleConfig = require(script.Parent.IdleConfig)

local IdleTowers = {}

IdleTowers.ORDER = { "MachineGun", "Frost", "Bomb", "Tesla", "Rocket", "Laser", "Chain", "Orbital" }

IdleTowers.Defs = {
	MachineGun = {
		rarity = "Common",
		displayName = "Archer du rempart",
		description = "Décoche rapidement ses flèches sur l'assaillant de tête.",
		kind = "Single",
		targeting = "First",
		color = Color3.fromRGB(72, 126, 70),
		placeCost = 10,
		damage = 3,
		range = 15,
		cooldown = 0.2,
	},
	Frost = {
		rarity = "Common",
		displayName = "Totem de givre",
		description = "Une rune glaciale blesse et ralentit les troupes proches.",
		kind = "Aura",
		color = Color3.fromRGB(150, 230, 255),
		placeCost = 25,
		damage = 4.2, -- touche tous les ennemis proches à chaque seconde : bon contre les hordes
		range = 12,
		cooldown = 1,
		slow = 0.25,
		slowDuration = 1.5,
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
	},
	Tesla = {
		rarity = "Rare",
		displayName = "Mage des tempêtes",
		description = "Foudroie et ralentit une cible : parfait contre les cavaliers et les boss.",
		kind = "Single",
		targeting = "First",
		color = Color3.fromRGB(250, 230, 80),
		placeCost = 50,
		damage = 14, -- assez de dégâts pour compter contre les boss, en plus de son ralentissement
		range = 16,
		cooldown = 0.8,
		slow = 0.6,
		slowDuration = 1.2,
	},
	Rocket = {
		rarity = "Epic",
		displayName = "Baliste lourde",
		description = "Un trait dévastateur à longue portée contre chevaliers lourds et boss.",
		kind = "Splash",
		targeting = "Strongest",
		color = Color3.fromRGB(200, 60, 60),
		placeCost = 80,
		damage = 40,
		range = 30,
		cooldown = 4, -- tire rarement : excellente contre les gros, faible contre les foules
		splash = 2,
	},
	Laser = {
		rarity = "Epic",
		displayName = "Sorcier des arcanes",
		description = "Canalise un rayon magique qui consume l'ennemi le plus résistant.",
		kind = "Single",
		targeting = "Strongest",
		color = Color3.fromRGB(255, 70, 200),
		placeCost = 120,
		damage = 9,
		range = 18,
		cooldown = 0.25,
	},
	Chain = {
		rarity = "Legendary",
		displayName = "Oracle de la foudre",
		description = "Un éclair ancien rebondit entre quatre ennemis.",
		kind = "Chain",
		targeting = "First",
		color = Color3.fromRGB(150, 110, 255),
		placeCost = 250,
		damage = 15, -- par ennemi touché (4 ennemis par éclair)
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
		damage = 40, -- peu par coup, mais il touche tout le chemin (portée 70)
		range = 70,
		cooldown = 5,
		splash = 5,
	},
}

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
-- + bonus de la machine à bonus.
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
		stats.cooldown /= bonus.mult
	end
	return stats
end

-- Dégâts par seconde (une Foudre en chaîne compte toutes ses cibles).
function IdleTowers.dpsOf(stats): number
	return stats.damage * (stats.chains or 1) / stats.cooldown
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

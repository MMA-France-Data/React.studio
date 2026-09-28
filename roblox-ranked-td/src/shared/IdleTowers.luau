-- Tours du mode infini (ta parcelle). Indépendantes des tours du ranked.
-- Au départ seul le Mitrailleur est débloqué ; les autres se gagnent à la machine à tours
-- (rareté = chance de l'obtenir). Doublons et bonus de la machine à bonus s'appliquent en plus.
local IdleConfig = require(script.Parent.IdleConfig)

local IdleTowers = {}

IdleTowers.ORDER = { "MachineGun", "Frost", "Bomb", "Tesla", "Rocket", "Laser", "Chain", "Orbital" }

IdleTowers.Defs = {
	MachineGun = {
		rarity = "Common",
		displayName = "Mitrailleur",
		description = "Rafales très rapides sur l'ennemi le plus avancé.",
		kind = "Single",
		targeting = "First",
		color = Color3.fromRGB(90, 160, 255),
		placeCost = 10,
		damage = 3,
		range = 15,
		cooldown = 0.2,
	},
	Frost = {
		rarity = "Common",
		displayName = "Givre",
		description = "Zone glacée : blesse et ralentit un peu tout ce qui passe.",
		kind = "Aura",
		color = Color3.fromRGB(150, 230, 255),
		placeCost = 25,
		damage = 2,
		range = 12,
		cooldown = 1,
		slow = 0.25,
		slowDuration = 1.5,
	},
	Bomb = {
		rarity = "Rare",
		displayName = "Bombe",
		description = "Explosions de zone : idéale contre les hordes.",
		kind = "Splash",
		targeting = "First",
		color = Color3.fromRGB(240, 130, 50),
		placeCost = 40,
		damage = 12,
		range = 14,
		cooldown = 1.8,
		splash = 7,
	},
	Tesla = {
		rarity = "Rare",
		displayName = "Électrique",
		description = "Électrocute une cible et la ralentit fortement : parfait contre les rush et les boss.",
		kind = "Single",
		targeting = "First",
		color = Color3.fromRGB(250, 230, 80),
		placeCost = 50,
		damage = 8,
		range = 16,
		cooldown = 0.8,
		slow = 0.6,
		slowDuration = 1.2,
	},
	Rocket = {
		rarity = "Epic",
		displayName = "Lance-roquettes",
		description = "Longue portée, grosse explosion sur l'ennemi le plus résistant : contre géants et boss.",
		kind = "Splash",
		targeting = "Strongest",
		color = Color3.fromRGB(200, 60, 60),
		placeCost = 80,
		damage = 45,
		range = 30,
		cooldown = 3,
		splash = 4,
	},
	Laser = {
		rarity = "Epic",
		displayName = "Laser",
		description = "Rayon continu qui fait fondre une cible.",
		kind = "Single",
		targeting = "First",
		color = Color3.fromRGB(255, 70, 200),
		placeCost = 120,
		damage = 6,
		range = 18,
		cooldown = 0.1,
	},
	Chain = {
		rarity = "Legendary",
		displayName = "Foudre en chaîne",
		description = "L'éclair rebondit sur 4 ennemis à la fois.",
		kind = "Chain",
		targeting = "First",
		color = Color3.fromRGB(150, 110, 255),
		placeCost = 250,
		damage = 30,
		range = 20,
		cooldown = 1.2,
		chains = 4,
	},
	Orbital = {
		rarity = "Legendary",
		displayName = "Frappe orbitale",
		description = "Énorme explosion n'importe où sur le chemin, sur l'ennemi le plus résistant.",
		kind = "Splash",
		targeting = "Strongest",
		color = Color3.fromRGB(120, 240, 255),
		placeCost = 400,
		damage = 220,
		range = 70,
		cooldown = 5,
		splash = 10,
	},
}

-- Améliorations : niveaux illimités. Chaque niveau multiplie les dégâts, et chaque
-- amélioration coûte plus cher que la précédente (réglages dans IdleConfig).
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

-- Prix pour passer du niveau `level` au niveau `level + 1`.
function IdleTowers.upgradeCost(towerType: string, level: number): number
	local raw = IdleTowers.Defs[towerType].placeCost * IdleConfig.UPGRADE_COST_BASE * IdleConfig.UPGRADE_COST_GROWTH ^ (level - 1)
	local magnitude = 10 ^ math.max(0, math.floor(math.log10(raw)) - 1)
	return math.floor(raw / magnitude + 0.5) * magnitude
end

-- Stats finales d'une tour posée : niveau + doublons (+5 % chacun) + bonus de la machine à bonus.
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

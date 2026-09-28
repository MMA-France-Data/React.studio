-- Tours du mode infini (ta parcelle). Indépendantes des tours du ranked.
-- Toutes disponibles pour l'instant ; la boutique gérera le déblocage et la machine à sous
-- les bonus.
local IdleConfig = require(script.Parent.IdleConfig)

local IdleTowers = {}

IdleTowers.ORDER = { "MachineGun", "Frost", "Bomb", "Tesla", "Rocket" }

IdleTowers.Defs = {
	MachineGun = {
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

function IdleTowers.dps(towerType: string, level: number): number
	local stats = IdleTowers.stats(towerType, level)
	return stats.damage / stats.cooldown
end

return IdleTowers

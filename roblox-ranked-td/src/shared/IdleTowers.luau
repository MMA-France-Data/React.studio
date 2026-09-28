-- Tours du mode infini (ta parcelle). Indépendantes des tours du ranked.
-- Toutes disponibles pour l'instant ; la boutique (étape 3) gérera le déblocage,
-- les améliorations et les bonus de la machine à sous.
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

-- Stats effectives (l'étape 3 ajoutera les niveaux d'amélioration et les bonus de la machine à sous).
function IdleTowers.stats(towerType: string, _level: number)
	return IdleTowers.Defs[towerType]
end

function IdleTowers.dps(towerType: string, level: number): number
	local stats = IdleTowers.stats(towerType, level)
	return stats.damage / stats.cooldown
end

return IdleTowers

-- Définition des tours. levels[1].cost = prix de pose, levels[n].cost = prix de l'amélioration vers n.
local Towers = {}

Towers.ORDER = { "Gunner", "Sniper", "Mortar", "Freezer" }

Towers.Defs = {
	Gunner = {
		displayName = "Mitrailleur",
		description = "Tir rapide sur l'ennemi le plus avancé.",
		kind = "Single",
		targeting = "First",
		color = Color3.fromRGB(90, 140, 255),
		levels = {
			{ cost = 150, damage = 18, range = 18, cooldown = 0.5 },
			{ cost = 125, damage = 28, range = 20, cooldown = 0.45 },
			{ cost = 250, damage = 45, range = 22, cooldown = 0.38 },
		},
	},
	Sniper = {
		displayName = "Sniper",
		description = "Très longue portée, vise l'ennemi le plus résistant.",
		kind = "Single",
		targeting = "Strongest",
		color = Color3.fromRGB(70, 200, 110),
		levels = {
			{ cost = 300, damage = 100, range = 45, cooldown = 2.2 },
			{ cost = 250, damage = 180, range = 50, cooldown = 2.0 },
			{ cost = 500, damage = 350, range = 55, cooldown = 1.8 },
		},
	},
	Mortar = {
		displayName = "Mortier",
		description = "Dégâts de zone autour de la cible.",
		kind = "Splash",
		targeting = "First",
		color = Color3.fromRGB(235, 130, 50),
		levels = {
			{ cost = 400, damage = 45, range = 26, cooldown = 2.5, splash = 7 },
			{ cost = 300, damage = 70, range = 28, cooldown = 2.3, splash = 8 },
			{ cost = 550, damage = 120, range = 30, cooldown = 2.0, splash = 9 },
		},
	},
	Freezer = {
		displayName = "Givreur",
		description = "Ralentit et blesse tous les ennemis à portée.",
		kind = "Aura",
		color = Color3.fromRGB(120, 220, 255),
		levels = {
			{ cost = 250, damage = 6, range = 16, cooldown = 1.0, slow = 0.35, slowDuration = 1.5 },
			{ cost = 200, damage = 10, range = 18, cooldown = 0.9, slow = 0.45, slowDuration = 2.0 },
			{ cost = 350, damage = 16, range = 20, cooldown = 0.8, slow = 0.55, slowDuration = 2.5 },
		},
	},
}

function Towers.stats(towerType: string, level: number)
	local def = Towers.Defs[towerType]
	return def and def.levels[level]
end

function Towers.maxLevel(towerType: string): number
	return #Towers.Defs[towerType].levels
end

function Towers.upgradeCost(towerType: string, currentLevel: number): number?
	local nextLevel = Towers.Defs[towerType].levels[currentLevel + 1]
	return nextLevel and nextLevel.cost
end

-- Or total investi dans une tour jusqu'à ce niveau (pour le remboursement à la vente).
function Towers.totalCost(towerType: string, level: number): number
	local total = 0
	for i = 1, level do
		total += Towers.Defs[towerType].levels[i].cost
	end
	return total
end

return Towers

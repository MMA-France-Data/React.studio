-- Les 7 types de monstres : leur nom, leur allure, leur vitesse et leur taille de base.
-- Leurs PV, l'or qu'ils donnent et les vies qu'ils coûtent dans un niveau sont dans Levels.luau (Levels.ENEMY).
-- Vitesse réelle = speed x IdleConfig.ENEMY_SPEED_MULTIPLIER x le facteur de son type (IdleConfig.ENEMY_SPEED_FACTORS).
local Enemies = {}

-- Ordre fixe : sert à encoder le type de monstre sur 1 octet dans les paquets réseau.
Enemies.ORDER = { "Normal", "Fast", "Tank", "Boss", "Swarm", "Giant", "Colossus" }
-- Cet octet porte aussi le COULOIR du monstre (cartes d'équipe : Levels.luau) : octet = numéro dans ORDER +
-- (couloir - 1) x LANE_STEP. Couloir 1 (et partout ailleurs qu'en équipe) : l'octet est le numéro seul.
Enemies.LANE_STEP = 64

-- displayName = son nom ; visual = sa silhouette en blocs (MedievalModels) ; speed = studs par seconde avant les
-- facteurs ; size = taille de base en studs (les niveaux l'affichent plus gros : Levels.ENEMY_SCALE) ; color = sa
-- couleur de base.
Enemies.Defs = {
	Normal = { displayName = "Fantassin", visual = "Infantry", speed = 8, size = 2, color = Color3.fromRGB(170, 48, 42) },
	Fast = { displayName = "Cavalier", visual = "Cavalry", speed = 14, size = 1.8, color = Color3.fromRGB(196, 142, 62) },
	Tank = { displayName = "Chevalier lourd", visual = "Heavy", speed = 5, size = 3, color = Color3.fromRGB(92, 101, 112) },
	Boss = { displayName = "Seigneur de guerre", visual = "Warlord", speed = 3.5, size = 5, color = Color3.fromRGB(92, 30, 34) },
	Swarm = { displayName = "Écuyer", visual = "Infantry", speed = 12, size = 1.25, color = Color3.fromRGB(126, 139, 68) },
	Giant = { displayName = "Chevalier colossal", visual = "Heavy", speed = 3, size = 4.5, color = Color3.fromRGB(70, 75, 84) },
	-- Idée du propriétaire (04/10/2026) : « un gros colosse plus fort qui apparaît à un couloir aléatoire ». Le mini-boss
	-- des niveaux 15, 25 et 35 : un seul colosse, plus grand, plus lent et bien plus résistant (Levels.ENEMY).
	Colossus = { displayName = "Colosse géant", visual = "Heavy", speed = 2.7, size = 5.2, color = Color3.fromRGB(64, 58, 78) },
}

return Enemies

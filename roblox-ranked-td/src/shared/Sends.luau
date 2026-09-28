-- Envois d'ennemis chez l'adversaire : c'est ce qui rend le 1v1 interactif.
-- Chaque envoi coûte de l'or mais augmente ton revenu par vague (+income).
local Sends = {}

Sends.ORDER = { "Swarm", "Rush", "Heavy", "Titan" }

Sends.COOLDOWN = 0.4
Sends.SPAWN_GAP = 0.35

Sends.Defs = {
	Swarm = { displayName = "Essaim", enemy = "Normal", count = 6, cost = 60, income = 4, minWave = 1 },
	Rush = { displayName = "Rush", enemy = "Fast", count = 6, cost = 90, income = 6, minWave = 2 },
	Heavy = { displayName = "Blindés", enemy = "Tank", count = 2, cost = 180, income = 12, minWave = 4 },
	Titan = { displayName = "Titan", enemy = "Boss", count = 1, cost = 1200, income = 70, minWave = 10 },
}

return Sends

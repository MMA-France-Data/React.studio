-- Réglages du COMBAT, communs aux niveaux et au camp d'entraînement (les règles et les chiffres d'un niveau : PV des
-- monstres, or, prix des tours... sont dans Levels.luau ; les tours elles-mêmes dans IdleTowers.luau).
-- (Ce fichier garde le nom qu'il avait dans l'ancien jeu.)
local IdleConfig = {}

-- Dégâts d'une tour multipliés par ce nombre à chaque niveau (IdleTowers.stats).
IdleConfig.UPGRADE_DAMAGE = 1.35

-- Vitesse d'un monstre = vitesse de Enemies.luau x ENEMY_SPEED_MULTIPLIER x le facteur de son type
-- (ENEMY_SPEED_FACTORS, 1 si absent).
IdleConfig.ENEMY_SPEED_MULTIPLIER = 1.35
IdleConfig.ENEMY_SPEED_FACTORS = {
	Fast = 0.7, -- cavaliers : toujours les plus rapides, mais plus des éclairs (13 studs/s au lieu de 22)
	-- écuyers : 13 studs/s au lieu de 19. Pas plus de 0,81 : les cavaliers doivent rester les plus rapides.
	Swarm = 0.8,
	-- Chevaliers lourds, colosse et Seigneur de guerre : freinés moins que les autres (7,4 / 4,7 / 5,4 studs/s).
	Tank = 1.1,
	Giant = 1.15,
	Boss = 1.15,
}
-- Doit rester entre 0 et 2,5 : le facteur voyage sur 1 octet dans le paquet des positions (Hub/Combat.luau).
function IdleConfig.enemySpeedFactor(enemyType: string): number
	return IdleConfig.ENEMY_SPEED_FACTORS[enemyType] or 1
end

IdleConfig.MAX_ENEMIES = 80 -- monstres en vie au plus dans une zone de combat
IdleConfig.SYNC_RATE = 6 -- envois de position des monstres aux clients par seconde
IdleConfig.SHOTS_RATE = 10 -- envois des effets de tir par seconde
IdleConfig.MAX_SHOTS_PER_PACKET = 24

-- Bouton « x2 » d'un niveau : toute la simulation tourne ce nombre de fois plus vite (monstres, apparitions, tirs).
-- Nombre ENTIER : le serveur fait ce nombre de pas de simulation par image (LevelGame:step).
IdleConfig.SPEED_PASS_FACTOR = 2

return IdleConfig

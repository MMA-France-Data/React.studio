-- Tous les chiffres du jeu : machines de la salle de sport, salles, pièces.
-- Pour régler la difficulté, c'est ici qu'on change les nombres (voir README.md).
local Config = {}

-- LA SALLE DE SPORT ---------------------------------------------------------------------------------------------
-- Trois machines, six niveaux chacune. Le niveau 1 est gratuit (tout le monde l'a au départ).
Config.MACHINES = { "Speed", "Jump", "Force" }
Config.MAX_LEVEL = 6
-- Prix pour passer du niveau N au niveau N + 1.
Config.PRICES = { 500, 1500, 4000, 10000, 25000 }

function Config.price(level: number): number?
	return Config.PRICES[level]
end

-- Tapis de course : +8 % de vitesse par niveau (16 au départ, 22,4 au niveau 6).
function Config.walkSpeed(level: number): number
	return 16 * (1 + 0.08 * (level - 1))
end

-- Trampoline : +15 % de hauteur de saut par niveau (7,2 studs au départ, 14,5 au niveau 6 : deux fois plus haut).
function Config.jumpHeight(level: number): number
	return 7.2 * 1.15 ^ (level - 1)
end

-- Musculation : 10 de force par niveau. Elle sert à repousser le plafond qui tombe (chaque appui pousse plus fort).
function Config.force(level: number): number
	return 10 * level
end

-- Hauteur d'une grande marche dans une salle de lave faite pour un saut de niveau `level`.
-- Mesuré dans Studio (tools/studio-test, test « jump ») : un personnage grimpe une marche jusqu'à sa hauteur de
-- saut + 1,8 stud environ (ses jambes ne cognent pas). Avec « saut + 1 », le niveau demandé passe avec un saut
-- correct, et le niveau d'en dessous (15 % de saut en moins) ne passe pas. Au niveau 1, la marche est facile.
function Config.stepHeight(level: number): number
	if level <= 1 then
		return 0.85 * Config.jumpHeight(1)
	end
	return Config.jumpHeight(level) + 1
end

-- LES MANCHES ---------------------------------------------------------------------------------------------------
Config.PREPARE = 10 -- secondes pour se préparer
Config.DURATION = 60 -- secondes à survivre
Config.HALF = 30 -- mort après ce temps : la moitié des pièces
Config.OPEN = 12 -- secondes pendant lesquelles la porte du bout reste ouverte

-- Pièces : multipliées par le numéro de la salle (salle 3 réussie = 300).
Config.REWARD_FULL = 100
Config.REWARD_HALF = 50
Config.FINAL_BONUS = 1000 -- en plus, pour la dernière salle

-- Raccourcis de la salle de sport : { salle à avoir réussie }. Le raccourci mène devant la salle suivante.
Config.SHORTCUTS = { 5 }

Config.DAMAGE = {
	Lava = 34, -- toutes les 0,4 s dans la lave
	Meteor = 45,
	Explosion = 60,
}

-- LES SALLES ----------------------------------------------------------------------------------------------------
-- events : les événements de la salle, lancés ensemble.
-- Lava      : segments = longueur du parcours (lignes droites de la spirale, 8 au plus), jump = niveau de saut
--             qu'il faut pour les grandes marches, finish = seconde où la lave arrive en haut (57 si absent).
-- Meteors   : every = secondes entre deux pluies, count = météorites par pluie, warn = secondes d'avertissement,
--             radius = rayon de l'explosion, aimed = part des météorites qui visent un joueur (0 à 1).
-- Explosions: every = secondes entre deux vagues, warn = secondes d'avertissement, safe = dalles sûres (sur 16).
-- Ceiling   : toujours avec Lava (et écrit après). at = seconde où le plafond commence à descendre, need = force
--             qui l'arrête à 5 appuis par seconde. Il faut environ les deux tiers pour tenir jusqu'au bout.
Config.ROOMS = {
	{ events = { "Lava" }, Lava = { segments = 3, jump = 1 } },
	{ events = { "Meteors" }, Meteors = { every = 1.1, count = 2, warn = 1.5, radius = 9, aimed = 0.5 } },
	{ events = { "Explosions" }, Explosions = { every = 4.5, warn = 2.2, safe = 6 } },
	{
		events = { "Lava", "Ceiling" },
		Lava = { segments = 3, jump = 1, finish = 28 },
		Ceiling = { at = 30, need = 28 },
	},
	{
		events = { "Lava", "Meteors" },
		Lava = { segments = 4, jump = 2 },
		Meteors = { every = 2.6, count = 1, warn = 1.5, radius = 6, aimed = 1 },
	},
	{
		events = { "Explosions", "Meteors" },
		Explosions = { every = 4, warn = 1.9, safe = 4 },
		Meteors = { every = 1.7, count = 1, warn = 1.4, radius = 8, aimed = 0.6 },
	},
	{
		events = { "Lava", "Ceiling" },
		Lava = { segments = 3, jump = 2, finish = 28 },
		Ceiling = { at = 30, need = 55 },
	},
	{
		events = { "Lava", "Meteors" },
		Lava = { segments = 6, jump = 4 },
		Meteors = { every = 2.1, count = 1, warn = 1.3, radius = 6, aimed = 1 },
	},
	{
		events = { "Explosions", "Meteors" },
		Explosions = { every = 3.3, warn = 1.6, safe = 3 },
		Meteors = { every = 1, count = 2, warn = 1.3, radius = 8, aimed = 0.6 },
	},
	{
		events = { "Lava", "Ceiling", "Meteors" },
		Lava = { segments = 4, jump = 4, finish = 28 },
		Ceiling = { at = 30, need = 68 },
		Meteors = { every = 3, count = 1, warn = 1.5, radius = 5, aimed = 1 },
	},
}

return Config

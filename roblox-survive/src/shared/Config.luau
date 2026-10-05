-- Tous les chiffres du jeu : machines de la salle de sport, salles, pièces.
-- Pour régler la difficulté, c'est ici qu'on change les nombres (voir README.md).
local Config = {}

-- LA SALLE DE SPORT ---------------------------------------------------------------------------------------------
-- Trois machines, six niveaux chacune. Tout le monde commence au niveau 0 ; le niveau 1 est gratuit.
-- Pour monter d'un niveau, le joueur monte sur la machine et s'entraîne quelques secondes.
Config.MACHINES = { "Speed", "Jump", "Force" }
Config.MAX_LEVEL = 6
-- Prix du niveau 1, du niveau 2, etc.
Config.PRICES = { 0, 500, 1500, 4000, 10000, 25000 }
Config.WORKOUT_SECONDS = 4 -- durée d'un entraînement sur une machine

-- Prix pour passer du niveau `level` au suivant (nil au maximum).
function Config.price(level: number): number?
	return Config.PRICES[level + 1]
end

-- Chaque niveau est un vrai palier : une salle faite pour le niveau N ne se passe pas au niveau N - 1.
-- Tapis de course : +15 % de vitesse par niveau (16 au départ, 37 au niveau 6).
function Config.walkSpeed(level: number): number
	return 16 * 1.15 ^ level
end

-- Trampoline : +15 % de hauteur de saut par niveau (7,2 studs au départ, 16,7 au niveau 6).
function Config.jumpHeight(level: number): number
	return 7.2 * 1.15 ^ level
end

-- Musculation : +50 % de force par niveau (10 au départ, 114 au niveau 6). Elle sert à repousser le plafond.
function Config.force(level: number): number
	return 10 * 1.5 ^ level
end

-- CE QUI REND UNE SALLE IMPOSSIBLE SANS LE BON NIVEAU -----------------------------------------------------------------
-- SAUT : hauteur d'une grande marche dans une salle de lave faite pour un saut de niveau `level`.
-- Mesuré dans Studio (tools/studio-test, test « jump ») : un personnage grimpe une marche jusqu'à sa hauteur de
-- saut + 1,8 stud environ (ses jambes ne cognent pas). Avec « saut + 1 », le niveau demandé passe avec un saut
-- correct, et le niveau d'en dessous (15 % de saut en moins) ne passe pas. Au niveau 0, la marche est facile.
function Config.stepHeight(level: number): number
	if level <= 0 then
		return 0.85 * Config.jumpHeight(0)
	end
	return Config.jumpHeight(level) + 1
end

-- FORCE : force qui arrête le plafond à 5 appuis par seconde, pour une salle faite pour une force de niveau `level`.
-- Il faut 60 % de cette valeur pour tenir 30 secondes : le niveau demandé en a 70 % (un peu de marge), le niveau
-- d'en dessous seulement 47 %, et même en appuyant au plus vite (6 appuis comptés par seconde) il n'arrive qu'à
-- 56 % : écrasé.
function Config.ceilingNeed(level: number): number
	return Config.force(level) / 0.7
end

-- VITESSE : secondes laissées pour courir `distance` studs jusqu'à la zone verte, dans une salle faite pour une
-- vitesse de niveau `level` : le temps qu'il faut à ce niveau, plus 0,3 seconde pour réagir. Au niveau d'en
-- dessous (15 % plus lent), il manque environ 4 studs à l'arrivée.
Config.RUSH_REACTION = 0.3
function Config.rushSeconds(level: number, distance: number): number
	return distance / Config.walkSpeed(level) + Config.RUSH_REACTION
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
	Melody = 25, -- fausse note
	Rush = 100, -- hors de la zone verte quand la grande pluie de météorites tombe
}

-- LES SALLES ----------------------------------------------------------------------------------------------------
-- need   : les niveaux qu'il FAUT pour réussir la salle seul (écrits sur le panneau de la salle). Les réglages des
--          événements en dessous doivent dire la même chose (jump, level).
-- egg    : l'animal dont la salle donne l'œuf (voir Pets.luau).
-- events : les événements de la salle, lancés ensemble.
-- Lava      : segments = longueur du parcours (lignes droites de la spirale, 8 au plus), jump = niveau de saut
--             qu'il faut pour les grandes marches, finish = seconde où la lave arrive en haut (57 si absent).
-- Meteors   : every = secondes entre deux pluies (absent = pas de météorites au hasard), count = météorites par
--             pluie, warn = secondes d'avertissement, radius = rayon de l'explosion, aimed = part des météorites
--             qui visent un joueur (0 à 1).
--             rush = la GRANDE PLUIE : toute la salle explose sauf un rond vert, à l'autre bout de la salle à
--             chaque fois. level = niveau de vitesse qu'il faut pour y arriver à temps, rest = secondes de repos
--             entre deux grandes pluies.
-- Explosions: every = secondes entre deux vagues, warn = secondes d'avertissement, safe = dalles sûres (sur 16).
-- Melody    : salle casse-tête. start = notes de la première suite, rounds = manches à réussir (une note de plus
--             à chaque manche). Réussir ouvre la porte tout de suite ; ne pas finir à temps élimine tout le monde.
-- Ceiling   : toujours avec Lava (et écrit après). at = seconde où le plafond commence à descendre, level = niveau
--             de force qu'il faut pour le tenir (Config.ceilingNeed).
--
-- LA PROGRESSION (pièces gagnées : 100 x le numéro de la salle) :
--   salles 1 à 4  : rien à payer, seulement les niveaux 1 gratuits (une visite aux machines).   Gain : 1 000
--   salle 5       : saut 2 (500).                                                               Gain : 500
--   salle 7       : saut 3 et force 2 (2 000 de plus).
--   salle 8       : vitesse 3 (2 000 de plus).
--   salle 9       : saut 4 (4 000 de plus).
--   salle 10      : saut 5 et force 4 (15 500 de plus).
-- Les premières salles s'ouvrent en une ou deux parties ; chaque palier suivant coûte plus cher que ce que
-- rapportent les salles déjà ouvertes : il faut rejouer de plus en plus pour avancer.
Config.ROOMS = {
	{ egg = "Dragon", need = {}, events = { "Lava" }, Lava = { segments = 3, jump = 0 } },
	{ egg = "Rock", need = { Speed = 1 }, events = { "Meteors" }, Meteors = { rush = { level = 1, rest = 3.5 } } },
	{ egg = "Rabbit", need = {}, events = { "Explosions" }, Explosions = { every = 4.5, warn = 2.2, safe = 6 } },
	{
		egg = "Golem",
		need = { Jump = 1, Force = 1 },
		events = { "Lava", "Ceiling" },
		Lava = { segments = 3, jump = 1, finish = 28 },
		Ceiling = { at = 30, level = 1 },
	},
	{
		egg = "Dragon",
		need = { Jump = 2 },
		events = { "Lava", "Meteors" },
		Lava = { segments = 4, jump = 2 },
		Meteors = { every = 2.6, count = 1, warn = 1.5, radius = 6, aimed = 1 },
	},
	{ egg = "Owl", need = {}, events = { "Melody" }, Melody = { start = 3, rounds = 3 } },
	{
		egg = "Golem",
		need = { Jump = 3, Force = 2 },
		events = { "Lava", "Ceiling" },
		Lava = { segments = 3, jump = 3, finish = 28 },
		Ceiling = { at = 30, level = 2 },
	},
	{
		egg = "Rabbit",
		need = { Speed = 3 },
		events = { "Meteors" },
		Meteors = { every = 2.2, count = 1, warn = 1.2, radius = 5, aimed = 1, rush = { level = 3, rest = 3 } },
	},
	{
		egg = "Dragon",
		need = { Jump = 4 },
		events = { "Lava", "Meteors" },
		Lava = { segments = 6, jump = 4 },
		Meteors = { every = 2.1, count = 1, warn = 1.3, radius = 6, aimed = 1 },
	},
	{
		egg = "Golem",
		need = { Jump = 5, Force = 4 },
		events = { "Lava", "Ceiling", "Meteors" },
		Lava = { segments = 4, jump = 5, finish = 28 },
		Ceiling = { at = 30, level = 4 },
		Meteors = { every = 3, count = 1, warn = 1.5, radius = 5, aimed = 1 },
	},
}

return Config

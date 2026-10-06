-- Tous les chiffres du jeu : machines de la salle de sport, salles, pièces.
-- Pour régler la difficulté, c'est ici qu'on change les nombres (voir README.md).
local Config = {}

-- LES MACHINES ET LES STATS ----------------------------------------------------------------------------------------
-- Trois stats : la vitesse, le saut et la force. Ce sont des NOMBRES DE POINTS, qu'on fait monter en s'entraînant.
-- Le joueur monte sur sa machine (tapis de course, trampoline, banc) et s'entraîne tant qu'il veut : à chaque pas
-- (toutes les STEP_SECONDS), il gagne des points. Améliorer la machine, avec des pièces, augmente seulement le
-- nombre de points gagnés à chaque pas (Config.GAINS).
--
-- UN NIVEAU DE MACHINE TOUTES LES 3 SALLES (demandes du joueur : les 10 premières salles en 2 à 3 heures de jeu,
-- puis une journée de jeu (5 heures) par nouvelle salle ; « aucun joueur ne doit avoir fini le jeu » ; « au moins
-- 200 heures pour la machine max » ; « je veux pas qu'il y ait forcément une amélioration de tapis à chaque niveau,
-- par ex la salle 4 et 5 peuvent être speed 10 k et saut 15 k »).
--   Le niveau 2 se paie avec les familiers de la salle 2 et sert pour les salles 3, 4, 5 ; le niveau 3 se paie avec
--   ceux de la salle 5 (salles 6, 7, 8) ; le niveau 4 avec ceux de la salle 8 ; etc. Les familiers valent 10 fois
--   plus à chaque salle (Pets.ROOM_FACTOR).
--   Chaque niveau donne 20 fois plus de points par pas (1, 20, 400, 8 000...) : ce que demandent ses trois salles
--   s'entraîne en quelques minutes avec lui (10 000 points au niveau 2 = 4 minutes), 20 fois plus sans lui.
-- Les deux tableaux sont CALCULÉS par tools/balance/machines.py : on y règle les heures, puis on recopie ici.
Config.MACHINES = { "Speed", "Jump", "Force" }
-- Prix pour passer la machine du niveau 1 au 2, du 2 au 3, etc.
Config.PRICES = { 170000, 570000000, 1500000000000, 3800000000000000, 32000000000000000, 280000000000000000, 2400000000000000000, 20000000000000000000, 170000000000000000000, 1400000000000000000000, 12000000000000000000000, 100000000000000000000000, 840000000000000000000000, 7000000000000000000000000, 59000000000000000000000000, 490000000000000000000000000, 4000000000000000000000000000, 32000000000000000000000000000, 260000000000000000000000000000 }
-- Points gagnés à chaque pas, par niveau de machine.
Config.GAINS = { 1, 20, 400, 8000, 160000, 3200000, 64000000, 1280000000, 25600000000, 512000000000, 10240000000000, 204800000000000, 4096000000000000, 81920000000000000, 1638400000000000000, 32768000000000000000, 655360000000000000000, 13107200000000000000000, 262144000000000000000000, 5242880000000000000000000 }
Config.MACHINE_MAX = #Config.GAINS
Config.STEP_SECONDS = 0.5

-- Prix pour améliorer une machine de niveau `level` (nil au maximum).
function Config.price(level: number): number?
	return Config.PRICES[level]
end

-- Points gagnés à chaque pas sur une machine de ce niveau.
function Config.gain(level: number): number
	return Config.GAINS[math.clamp(math.floor(level), 1, Config.MACHINE_MAX)]
end

-- LES PALIERS : le nombre de points qui donne le palier 1, 2, 3... d'une stat. Les salles sont réglées sur ces
-- paliers (« Vitesse 2 500 recommandé » = palier 2). Avec une machine du même niveau que le palier visé, chaque
-- palier demande DEUX FOIS PLUS de temps que celui d'avant : 1 minute pour le premier (avant la salle 2), puis
-- 2, 4, 8, 16 et 32 minutes. On peut toujours s'entraîner sans améliorer sa machine, mais c'est DIX FOIS plus long
-- (20 minutes au lieu de 2 pour le palier 2) : les pièces des salles et des familiers font gagner ce temps.
Config.POINTS = { 120, 2500, 50000, 1000000, 20000000, 400000000 }
Config.MAX_LEVEL = #Config.POINTS

-- Points qu'il faut pour le palier `level` (0 pour le palier 0).
function Config.pointsFor(level: number): number
	return Config.POINTS[math.clamp(math.floor(level), 0, Config.MAX_LEVEL)] or 0
end

-- Le palier (avec des décimales) que donnent ces points : 100 -> 1 ; 500 -> 2 ; entre les deux, on avance en
-- proportion (en multipliant) ; sous le premier palier, en ligne droite. Les formules de vitesse, de saut et de
-- force ci-dessous prennent ce palier.
function Config.levelOf(points: number): number
	local list = Config.POINTS
	if points < list[1] then
		return math.max(0, points) / list[1]
	end
	for level = 1, #list - 1 do
		if points < list[level + 1] then
			return level + math.log(points / list[level]) / math.log(list[level + 1] / list[level])
		end
	end
	-- Au-delà du dernier palier, ça continue du même pas (un palier de plus à chaque fois que les points sont
	-- multipliés par 20) : la vitesse de course n'a pas de plafond. Le saut, lui, s'arrête au dernier palier.
	return #list + math.log(points / list[#list]) / math.log(list[#list] / list[#list - 1])
end

-- MARCHER ET COURIR (le joueur : « on peut laisser la vitesse de base en vitesse de base et le sprint infini de
-- vitesse si on veut ») : sans courir, le personnage marche TOUJOURS à BASE_SPEED, quels que soient ses points (il
-- reste facile à diriger). Tant que le joueur tient la touche Maj (ou a appuyé sur « COURIR »), il court à la
-- vitesse que donnent ses points de vitesse, sans plafond.
Config.BASE_SPEED = 16
Config.WALK_RATIO = 0.7 -- (n'est plus utilisé par le jeu ; gardé pour les anciens tests)

-- Vitesse de COURSE : +10 par palier, sans plafond (16 à 0 point, 26 à 120 points, 36 à 2 500, 46 à 50 000, 56 à
-- 1 000 000...). Entre deux paliers, chaque fois que les points doublent on gagne environ 2,3. Ainsi 300 points
-- (29), 1 000 (33) et 10 000 (41) ne se ressemblent pas : il trouvait que « ça change pas assez ».
function Config.walkSpeed(level: number): number
	return Config.BASE_SPEED + 10 * level
end

-- Saut : +15 % de hauteur par palier (7,2 studs au départ, 16,7 au palier 6, le maximum).
function Config.jumpHeight(level: number): number
	return 7.2 * 1.15 ^ math.min(level, Config.MAX_LEVEL)
end

-- Force : +50 % par palier (10 au départ, 114 au palier 6). Elle sert à repousser le plafond.
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
-- vitesse de niveau `level` : le temps qu'il faut à ce niveau, plus 6 % (voir RUSH_SLACK). Le joueur voit le rond
-- d'arrivée avant le départ et ne peut pas partir en avance (Meteors.luau) : il n'a donc pas à réagir, seulement à
-- courir. Au niveau d'en dessous (15 % plus lent), il manque environ 6 studs à l'arrivée.
-- VITESSE (salle de course) : vitesse du monstre dans une salle faite pour une vitesse de niveau `level`. Il va 5 %
-- plus vite qu'un joueur du niveau d'en dessous qui court (il finit par l'attraper), et 9 % moins vite qu'un joueur
-- du niveau demandé (qui garde une dizaine de studs d'avance en tournant en grand cercle).
function Config.chaseSpeed(level: number): number
	return Config.walkSpeed(level - 1) * 1.05
end

-- VITESSE (le prédateur) : vitesse du prédateur dans une salle faite pour une vitesse de palier `level`. Il suit
-- la trace du joueur (même chemin que lui) : il va 8 % moins vite qu'un joueur de ce palier qui court. Salle 2
-- (palier 1) : le prédateur court à 19,3 ; un joueur à 0 point court à 16 (rattrapé en une dizaine de secondes), à
-- 60 points 18,5 (rattrapé aussi), à 120 points 21 (il le distance), à 2 500 points 26 (il le sème largement).
-- Pourquoi 8 % : un vrai joueur hésite, se cogne, lâche la touche un instant. À 3 %, un joueur au bon palier qui
-- perdait 0,3 seconde toutes les 6 secondes se faisait rattraper (mesuré).
-- 100 % : le choix du joueur (« loup met 100% », après avoir trouvé qu'à 150 points il le semait trop facilement à
-- 92 %). Le prédateur court donc EXACTEMENT à la vitesse du palier demandé : au palier pile, on garde son avance
-- tant qu'on ne s'arrête pas ; chaque hésitation le rapproche.
Config.HUNTER_RATIO = 1
-- (Dans Studio, le panneau de réglages peut changer ce rapport : attribut « HunterRatio » du Workspace.)
function Config.hunterSpeed(level: number): number
	return Config.walkSpeed(level) * (workspace:GetAttribute("HunterRatio") or Config.HUNTER_RATIO)
end

Config.RUSH_SLACK = 1.06
function Config.rushSeconds(level: number, distance: number): number
	return distance / Config.walkSpeed(level) * Config.RUSH_SLACK
end

-- LES MANCHES ---------------------------------------------------------------------------------------------------
Config.PREPARE = 10 -- secondes pour se préparer
Config.DURATION = 60 -- secondes à survivre
Config.HALF = 30 -- le milieu de la manche (le plafond commence à descendre)
Config.OPEN = 12 -- secondes pendant lesquelles la porte du bout reste ouverte

-- Une salle réussie ne donne PAS de pièces : seulement un ticket de la salle (voir Eggs.luau). Les pièces viennent
-- des familiers de l'enclos.

-- LA FERMETURE DE LA PORTE (voir Cycle.luau) : toutes les `every` secondes, la porte du lobby se ferme `closed`
-- secondes. Pendant ce temps les œufs couvent `speed` fois plus vite. À la réouverture, une salle au hasard reçoit
-- un bonus de chance tiré dans `luck` (2 = +100 % de chances d'un œuf rare, 6 = +500 %), jusqu'à la fermeture suivante.
Config.CYCLE = { every = 300, closed = 10, speed = 10, luck = { 2, 3, 4, 5, 6 } }

-- Raccourcis de la salle de sport : { salle à avoir réussie }. Le raccourci mène devant la salle suivante.
Config.SHORTCUTS = { 5 }

Config.DAMAGE = {
	Lava = 34, -- toutes les 0,4 s dans la lave
	Meteor = 45,
	Explosion = 60,
	Melody = 25, -- fausse note
	Rush = 100, -- hors de la zone verte quand la grande pluie de météorites tombe
	Chase = 100, -- attrapé par le monstre
}

-- LES SALLES ----------------------------------------------------------------------------------------------------
-- need   : les niveaux qu'il FAUT pour réussir la salle seul (écrits sur le panneau de la salle). Les réglages des
--          événements en dessous doivent dire la même chose (jump, level).
-- egg    : l'animal dont la salle donne l'œuf (voir Pets.luau).
-- events : les événements de la salle, lancés ensemble.
-- Bomb      : un parcours à grimper (sol sûr) et une bombe en haut. segments et jump comme Lava ; fuse = secondes
--             avant l'explosion ; hold = secondes à tenir E pour couper son fil. Chaque joueur coupe le sien.
-- Lava      : segments = longueur du parcours (lignes droites du zigzag, 6 au plus), jump = niveau de saut
--             qu'il faut pour les grandes marches, finish = seconde où la lave arrive en haut (57 si absent).
-- Meteors   : every = secondes entre deux pluies (absent = pas de météorites au hasard), count = météorites par
--             pluie, warn = secondes d'avertissement, radius = rayon de l'explosion, aimed = part des météorites
--             qui visent un joueur (0 à 1).
--             rush = la GRANDE PLUIE : toute la salle explose sauf un rond vert, à l'autre bout de la salle à
--             chaque fois. level = niveau de vitesse qu'il faut pour y arriver à temps, rest = secondes de repos
--             entre deux grandes pluies.
-- Chase     : salle de course. Un monstre poursuit les joueurs. level = niveau de vitesse qu'il faut pour le
--             distancer en courant (Config.chaseSpeed), delay = secondes avant qu'il parte.
-- Explosions: every = secondes entre deux vagues, warn = secondes d'avertissement, safe = dalles sûres (sur 16).
-- Melody    : salle casse-tête. start = notes de la première suite, rounds = manches à réussir (une note de plus
--             à chaque manche). Réussir ouvre la porte tout de suite ; ne pas finir à temps élimine tout le monde.
-- Ceiling   : toujours avec Lava (et écrit après). at = seconde où le plafond commence à descendre, level = niveau
--             de force qu'il faut pour le tenir (Config.ceilingNeed).
--
-- LA PROGRESSION : les paliers se gagnent en s'entraînant ; les pièces (salles, familiers) servent à améliorer les
-- machines pour s'entraîner plus vite, et à agrandir l'enclos.
--   salles 1 à 4  : paliers 1 (120 points : une minute par machine au départ).
--   salle 5       : saut palier 2 (2 500 points).
--   salle 7       : saut palier 3 (50 000) et force palier 2.
--   salle 8       : vitesse palier 3.
--   salle 9       : saut palier 4 (1 000 000).
--   salle 10      : saut palier 5 (20 000 000) et force palier 4.
Config.ROOMS = {
	-- Salle 1 FACILE (sa copine ne la passait pas sur téléphone : « des enfants, ça sera pas mieux ») : des trous de
	-- 3,5 au lieu de 5,5 et des poutres de 4,5 de large au lieu de 2,2. Elle reste à 1 minute (« laisse 1 mn »).
	{ egg = "Dragon", need = {}, events = { "Bomb" }, Bomb = { segments = 3, jump = 0, fuse = 60, hold = 3, gap = 3.5, beam = 4.5 } },
	-- (points : ce que la salle demande, en POINTS de stat, quand ce n'est pas un palier rond : c'est ce nombre qui
	-- est écrit sur son panneau. Demandes du joueur : 150 de vitesse pour la salle 2.)
	{ egg = "Rock", need = { Speed = 1 }, points = { Speed = 150 }, events = { "Hunter" }, Hunter = { level = Config.levelOf(150) } },
	-- Salle 3 : 7 200 de force = 3 minutes de banc avec la machine niveau 2 (20 points par pas, 2 pas par seconde).
	-- (5 minutes au premier essai ; il a demande 3 minutes : "qu'on ecoeure pas les gens".)
	-- Son idée : à ce moment le joueur améliore ses trois machines au niveau 2 (500 pièces chacune).
	{ egg = "Rabbit", need = { Force = 2 }, points = { Force = 7200 }, events = { "Avalanche" }, Avalanche = { points = 7200 } },
	-- Salle 4 : 10 000 de vitesse = 4 minutes de tapis avec la machine niveau 2 (son chiffre).
	{ egg = "Golem", need = { Speed = 2 }, points = { Speed = 10000 }, events = { "Valves" }, Valves = { points = 10000 } },
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
	{ egg = "Rabbit", need = { Speed = 3 }, events = { "Chase" }, Chase = { level = 3, delay = 4 } },
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

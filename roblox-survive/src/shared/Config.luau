-- Tous les chiffres du jeu : machines de la salle de sport, salles, pièces.
-- Pour régler la difficulté, c'est ici qu'on change les nombres (voir README.md).
local Config = {}

-- LES MACHINES ET LES STATS ----------------------------------------------------------------------------------------
-- Trois stats : la vitesse, le saut et la force. Ce sont des NOMBRES DE POINTS, qu'on fait monter en s'entraînant.
-- Le joueur monte sur sa machine (tapis de course, trampoline, banc) et s'entraîne tant qu'il veut : à chaque pas
-- (toutes les STEP_SECONDS), il gagne des points. Améliorer la machine, avec des pièces, augmente seulement le
-- nombre de points gagnés à chaque pas (Config.GAINS).
--
-- UN NIVEAU DE MACHINE PAR SALLE (demandes du joueur : les 10 premières salles en 2 à 3 heures de jeu, puis une
-- journée de jeu (5 heures) par nouvelle salle car il en sort une par jour ; « aucun joueur ne doit avoir fini le
-- jeu » ; « au moins 200 heures pour la machine max »).
--   Niveaux 1 à 10  : les 10 premières salles. Le niveau N se paie avec les familiers de la salle N - 1 (ils valent
--                     10 fois plus à chaque salle, Pets.ROOM_FACTOR). Niveaux 4, 6, 8, 10 : ceux qu'il faut pour
--                     les paliers de stat 2, 3, 4, 5 (environ 3 minutes d'entraînement avec eux).
--   Niveaux 11 à 50 : un par salle à venir, une journée de jeu chacun (le niveau 50 vers 200 heures). Tant que la
--                     salle suivante n'est pas sortie, le revenu ne monte plus : chaque niveau demande alors deux
--                     fois plus de temps que le précédent (5 h, 10 h, 20 h, 40 h...), il reste toujours un but.
-- Les deux tableaux sont CALCULÉS par tools/balance/machines.py : on y règle les heures, puis on recopie ici.
Config.MACHINES = { "Speed", "Jump", "Force" }
-- Prix pour passer la machine du niveau 1 au 2, du 2 au 3, etc.
Config.PRICES = { 500, 8100, 140000, 2000000, 27000000, 350000000, 4500000000, 72000000000, 970000000000, 87000000000000, 180000000000000, 370000000000000, 750000000000000, 1500000000000000, 3100000000000000, 6400000000000000, 13000000000000000, 27000000000000000, 55000000000000000, 110000000000000000, 230000000000000000, 470000000000000000, 950000000000000000, 1900000000000000000, 3900000000000000000, 8000000000000000000, 16000000000000000000, 33000000000000000000, 68000000000000000000, 140000000000000000000, 280000000000000000000, 570000000000000000000, 1200000000000000000000, 2300000000000000000000, 4800000000000000000000, 9700000000000000000000, 20000000000000000000000, 40000000000000000000000, 81000000000000000000000, 160000000000000000000000, 330000000000000000000000, 680000000000000000000000, 1400000000000000000000000, 2800000000000000000000000, 5600000000000000000000000, 11000000000000000000000000, 23000000000000000000000000, 47000000000000000000000000, 95000000000000000000000000 }
-- Points gagnés à chaque pas, par niveau de machine.
Config.GAINS = { 1, 2, 3, 7, 31, 140, 630, 2800, 12000, 56000, 84000, 130000, 190000, 280000, 430000, 640000, 960000, 1400000, 2200000, 3200000, 4800000, 7300000, 11000000, 16000000, 25000000, 37000000, 55000000, 83000000, 120000000, 190000000, 280000000, 420000000, 630000000, 940000000, 1400000000, 2100000000, 3200000000, 4800000000, 7200000000, 11000000000, 16000000000, 24000000000, 36000000000, 54000000000, 82000000000, 120000000000, 180000000000, 280000000000, 410000000000, 620000000000 }
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
	return #list
end

-- MARCHER ET COURIR : le personnage marche à WALK_RATIO de sa vitesse ; il court à pleine vitesse tant que le joueur
-- tient la touche Maj (ou a appuyé sur le bouton « COURIR » de l'écran).
Config.WALK_RATIO = 0.7

-- Chaque palier compte : une salle faite pour le palier N ne se passe pas au palier N - 1.
-- Vitesse : +5 par palier (16 au départ, 21 au palier 1, 26 au palier 2... 46 au palier 6). Le premier palier fait
-- donc +31 % d'un coup : un palier de plus se SENT (« à 2 500 je m'attends à détruire le boss »), et l'écart entre
-- deux paliers est assez grand pour régler les salles de vitesse.
function Config.walkSpeed(level: number): number
	return 16 + 5 * level
end

-- Saut : +15 % de hauteur par palier (7,2 studs au départ, 16,7 au palier 6).
function Config.jumpHeight(level: number): number
	return 7.2 * 1.15 ^ level
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
Config.HUNTER_RATIO = 0.92
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
	{ egg = "Dragon", need = {}, events = { "Bomb" }, Bomb = { segments = 3, jump = 0, fuse = 60, hold = 3 } },
	{ egg = "Rock", need = { Speed = 1 }, events = { "Hunter" }, Hunter = { level = 1 } },
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

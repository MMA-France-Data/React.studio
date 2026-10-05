--!optimize 2
-- Joueur simulé des niveaux : il joue un niveau avec le VRAI moteur (LevelGame.luau) et renvoie le résultat.
-- Il n'est ni parfait ni mauvais. À chaque décision, il regarde tous ses achats possibles (poser une tour de plus,
-- améliorer une tour posée), estime ce que chacun ajoute de dégâts par seconde, et prend celui qui en donne le plus
-- par pièce d'or ; s'il n'a pas encore l'or, il économise, sauf quand un monstre approche du château (il prend alors
-- le meilleur achat payable tout de suite). Il pose ses tours sur les emplacements conseillés de la carte.
-- Il sert à comparer des réglages et des profils de joueurs (quelles tours débloquées, quel entraînement), pas à
-- trouver la meilleure stratégie possible. Il joue aussi en ÉQUIPE (Bot.playTeam : plusieurs joueurs simulés dans
-- la même partie, chacun avec son or et ses tours).
local Env = require("./env")
local Levels = require("./gen/shared/Levels")
local IdleTowers = require("./gen/shared/IdleTowers")
local LevelGame = require("./gen/server/Hub/LevelGame")
local Shim = require("./shim")

local Bot = {}

Bot.DT = 1 / 30 -- pas de simulation (comme une image du serveur)
Bot.DECISION_INTERVAL = 0.4 -- secondes entre deux décisions du joueur simulé
Bot.MAX_SECONDS = 900
Bot.DANGER = 0.55 -- part du chemin au-delà de laquelle un monstre fait acheter tout de suite
-- Ce que vaut le premier Totem de givre pour le joueur simulé : part des dégâts de ses autres tours gagnée pour un
-- ralentissement qui double le temps passé sous les tirs (s / (1 - s) = 1, soit -50 %). Les suivants : 30 % de ça.
Bot.FROST_GAIN = 0.23
-- Goût du joueur simulé pour un type de tour (outils de réglage) : { [type] = multiplicateur de la valeur qu'il lui
-- donne }. 0 = il ne la pose jamais, 3 = il la préfère. Sert à mesurer ce qu'une tour apporte vraiment.
Bot.VALUE_SCALE = {}

-- Emplacements essayés dans l'ordre : ceux de la carte, puis tous les points valides d'une grille (les plus proches
-- du chemin d'abord).
local function candidateSpots(mapName: string)
	local geometry = Levels.geometry(mapName)
	local map = geometry.map
	local spots = table.clone(map.spots)
	local extra = {}
	for x = -map.width / 2 + 4, map.width / 2 - 4, 5 do
		for z = -map.depth / 2 + 4, map.depth / 2 - 4, 5 do
			local point = Shim.Vector3.new(x, 0, z)
			if Levels.checkPlacement(mapName, point, spots) then
				table.insert(extra, { point = point, distance = geometry.distanceToPath(point) })
			end
		end
	end
	table.sort(extra, function(a, b)
		return a.distance < b.distance
	end)
	for _, entry in extra do
		table.insert(spots, entry.point)
	end
	return spots
end

-- Dégâts par seconde estimés d'une tour (ordre de grandeur : zones et carreaux comptent plusieurs cibles ; le feu
-- au sol, deux ; les ronces du Lance-ronces, plus : leur poison continue après).
local function estimate(towerType: string, level: number, training: number): number
	local stats = Levels.towerStats(towerType, level, training)
	local dps
	if stats.kind == "Beam" then
		dps = stats.damage * 9
	elseif stats.kind == "Aura" then
		dps = stats.damage / stats.cooldown * 3
	elseif stats.kind == "Chain" then
		dps = stats.damage * stats.chains / stats.cooldown
	elseif stats.kind == "Splash" then
		dps = stats.damage / stats.cooldown * (1 + stats.splash / 3)
	elseif stats.kind == "Pierce" then
		dps = stats.damage / stats.cooldown * 2.2
	else
		dps = stats.damage / stats.cooldown
	end
	if stats.fireRadius then
		dps += IdleTowers.fireDps(stats) * (if stats.poisonDuration then 2 + stats.poisonDuration * 0.5 else 2)
	end
	return dps
end

-- Façons de jouer essayées (Bot.play garde la meilleure partie) :
--   patience = il économise pour son meilleur achat (au lieu de prendre le meilleur achat payable) quand ce
--              meilleur achat vaut au moins `patience` fois plus par pièce d'or (math.huge = il n'économise jamais) ;
--   archers = nombre d'Archers posés avant tout le reste (des dégâts sûrs dès le début) ;
--   danger = part du chemin au-delà de laquelle un monstre lui fait tout dépenser tout de suite (Bot.DANGER si
--            absent ; 2 = jamais : il garde son sang-froid et continue d'économiser pour son meilleur achat).
Bot.POLICIES = {
	{ patience = math.huge, archers = 0 },
	{ patience = 1.2, archers = 3 },
	{ patience = 1.2, archers = 5 },
	{ patience = 1.6, archers = 3 },
	{ patience = 1.6, archers = 5 },
	{ patience = 1.2, archers = 3, danger = 0.85 },
	{ patience = 1.2, archers = 3, danger = 2 },
	{ patience = 1.05, archers = 2, danger = 2 },
	{ patience = 1.05, archers = 0, danger = 2 },
}

-- Ce qu'un joueur a dans sa BARRE quand il joue chaque niveau (le joueur de RÉFÉRENCE, pour qui les niveaux 1 à
-- Levels.OPEN_COUNT sont réglés : tune.luau). Depuis le 04/10/2026, plus de boutique : toutes les tours sortent des
-- ŒUFS (« LES ŒUFS », Levels.luau), au hasard. On attend donc les tours que PRESQUE TOUS les joueurs ont quand ils
-- gagnent chaque niveau une fois, dans l'ordre, et ouvrent leurs œufs (en les finissant avec leurs pièces) :
--   * 1er territoire : l'Archer (donné), puis la Catapulte (le premier œuf, au niveau 1). Les tours des premiers
--     œufs communs (Totem, Mage...) sont un bonus : un nouveau joueur n'est jamais bloqué par la chance ;
--   * 2e territoire : en plus, le Totem de givre et le Mage des tempêtes, les tours les plus fréquentes des œufs
--     communs (7 œufs communs et 1 rare avant le niveau 11 : 3 joueurs sur 4 ont les deux), et l'Arc carmin (la tour
--     spéciale du boss du niveau 10 : son œuf est donné à coup sûr) ; puis, à partir du niveau 16, une tour de PALIER 2 :
--     la Catapulte de magma (l'œuf doré du niveau 10 : 3 chances sur 4 d'une tour de palier 2). Le boss du niveau 20
--     la demande vraiment (blocage voulu par le propriétaire : « que des niveaux tu sois vraiment bloqué, obligé de
--     rechercher les tourelles ») ;
--   * 3e territoire : en plus, l'Arbalète de cuivre (boss du niveau 20), une 2e tour de palier 2, l'Archimage des
--     tempêtes (l'œuf doré du niveau 20), puis la Baliste lourde (au fil des œufs) à partir du niveau 26 ;
--   * 4e territoire et désert : en plus, le Lance-ronces (boss du niveau 30) puis la Catapulte de givre (boss du
--     niveau 40). PAS de tour épique de palier 2 ni de légendaire : voir « LA CHANCE » plus bas.
-- Un joueur moins chanceux rejoue des niveaux : chaque victoire donne encore un œuf (et des pièces pour les finir).
-- LA CHANCE (mesurée le 05/10/2026). Avec la barre, une seule tour compte beaucoup, et les œufs sont tirés au sort :
-- en arrivant au niveau 31, 76 % des joueurs ont une tour RARE de palier 2, 74 % une ÉPIQUE de palier 2 (48 % la
-- Baliste du dragon), 44 % une légendaire, 97 % au moins une rare ou une épique de palier 2. Or la Baliste du dragon
-- permet de battre des monstres 45 % plus résistants au 4e territoire (une légendaire de palier 2 : +35 % au 3e) :
-- réglé pour elle, le niveau 31 restait impossible aux autres, même entraînés au maximum. Les niveaux sont donc
-- réglés pour la barre que presque tout le monde peut former (une rare de palier 2, pas d'épique de palier 2, pas de
-- légendaire) : personne n'est bloqué sans solution ; celui qui a eu de la chance trouve la suite plus facile. Pour
-- que ce soit « dur » pour tout le monde, il faudrait que les tours clés ne dépendent plus de la chance (question
-- posée au propriétaire le 05/10/2026 : les œufs dorés des boss).
-- LA BARRE (05/10/2026, « LA BARRE DE TOURS », Levels.luau) : dans un niveau, UNE tour par rareté. towers = la
-- MEILLEURE barre que ce joueur peut former avec ses tours à ce niveau (une commune, une rare, une épique dès qu'il
-- en a une, une spéciale ; pas de légendaire : trop rare pour être attendue), trouvée par essais : toutes ses barres
-- possibles jouées par le joueur simulé, la plus forte gardée (voir « RÉGLER » dans le README de ce dossier).
-- L'ENTRAÎNEMENT, « DUR PARTOUT » (choix du propriétaire le 05/10/2026 : chaque niveau demande presque la
-- meilleure équipe et des tours entraînées, on rejoue souvent d'anciens niveaux) : ce que ses parties lui ont donné
-- (8 XP par victoire pour chaque tour posée, +10 % de dégâts par niveau d'entraînement ; une tour qui vient de
-- sortir d'un œuf n'est pas encore entraînée) PLUS UN NIVEAU pour chaque tour de la barre à partir du niveau 11,
-- DEUX à partir du niveau 31 (Bot.extraTraining : là, le joueur attendu n'a pas la tour épique de palier 2 qu'ont 3
-- joueurs sur 4) : celui qui arrive à un niveau pour la première fois doit d'abord entraîner ses tours (camp,
-- niveaux rejoués, ⚡).
-- training = entraînement de l'Archer et de la Catapulte ; trainings = celui d'une tour à part.
-- pace = le RYTHME demandé par ce niveau : secondes entre deux achats du joueur de référence, celui pour qui le
-- niveau est réglé (tune.luau). Le premier niveau laisse un peu de temps, les derniers demandent un achat toutes
-- les 3,5 secondes (un humain choisit moins bien que le joueur simulé : il doit aller un peu plus vite que ça).
-- Niveaux 41 à 100 : fermés pour l'instant (Levels.OPEN_COUNT). Les lignes des niveaux 41 à 50 sont réglées comme
-- celles des niveaux ouverts (la barre, « dur partout ») ; celles des niveaux 51 à 100 datent de la boutique (huit
-- tours de palier 1, bien plus qu'une barre) : à refaire avant de les ouvrir.
-- Crans d'entraînement que Bot.EXPECTED compte EN PLUS de ce que les parties donnent (« dur partout ») : 1 à partir
-- du niveau 11, 2 à partir du niveau 31. (tests.luau s'en sert pour retrouver « celui qui arrive ».)
function Bot.extraTraining(level: number): number
	return if level > 3 * Levels.TERRITORY_SIZE then 2 elseif level > Levels.TERRITORY_SIZE then 1 else 0
end

local MG, BOMB, FROST, TESLA, ROCKET, LASER, CHAIN, ORBITAL = "MachineGun", "Bomb", "Frost", "Tesla", "Rocket", "Laser", "Chain", "Orbital"
local MAGMA, STORM = "MagmaCatapult", "StormArchmage"
local CRIMSON, COPPER = "CrimsonBow", "CopperCrossbow"
local EIGHT = { MG, BOMB, FROST, TESLA, ROCKET, LASER, CHAIN, ORBITAL }
Bot.EXPECTED = {
	-- 1er territoire
	{ towers = { MG }, training = 0, pace = 5 },
	{ towers = { MG, BOMB }, training = 0, pace = 4.5 },
	{ towers = { MG, BOMB }, training = 0, pace = 4 },
	{ towers = { MG, BOMB }, training = 1, pace = 4 },
	{ towers = { MG, BOMB }, training = 1, pace = 4 },
	{ towers = { MG, BOMB }, training = 1, pace = 3.5 },
	{ towers = { MG, BOMB }, training = 1, pace = 3.5 },
	{ towers = { MG, BOMB }, training = 2, pace = 3.5 },
	{ towers = { MG, BOMB }, training = 2, pace = 3.5 },
	{ towers = { MG, BOMB }, training = 2, pace = 3.5 },
	-- 2e territoire
	{ towers = { MG, TESLA, CRIMSON }, training = 3, trainings = { Tesla = 1, CrimsonBow = 1 }, pace = 3.5 },
	{ towers = { MG, TESLA, CRIMSON }, training = 3, trainings = { Tesla = 1, CrimsonBow = 1 }, pace = 3.5 },
	{ towers = { FROST, BOMB, CRIMSON }, training = 3, trainings = { Frost = 1, CrimsonBow = 1 }, pace = 3.5 },
	{ towers = { FROST, BOMB, CRIMSON }, training = 3, trainings = { Frost = 2, CrimsonBow = 2 }, pace = 3.5 },
	{ towers = { FROST, BOMB, CRIMSON }, training = 3, trainings = { Frost = 2, CrimsonBow = 2 }, pace = 3.5 },
	{ towers = { FROST, MAGMA, CRIMSON }, training = 3, trainings = { Frost = 2, MagmaCatapult = 1, CrimsonBow = 2 }, pace = 3.5 },
	{ towers = { FROST, MAGMA, CRIMSON }, training = 3, trainings = { Frost = 2, MagmaCatapult = 1, CrimsonBow = 2 }, pace = 3.5 },
	{ towers = { FROST, MAGMA, CRIMSON }, training = 3, trainings = { Frost = 2, MagmaCatapult = 1, CrimsonBow = 2 }, pace = 3.5 },
	{ towers = { FROST, MAGMA, CRIMSON }, training = 3, trainings = { Frost = 2, MagmaCatapult = 2 }, pace = 3.5 },
	{ towers = { FROST, MAGMA, CRIMSON }, training = 3, trainings = { Frost = 2, MagmaCatapult = 2 }, pace = 3.5 },
	-- 3e territoire
	{ towers = { MG, STORM, COPPER }, training = 4, trainings = { StormArchmage = 1, CopperCrossbow = 1 }, pace = 3.5 },
	{ towers = { MG, STORM, COPPER }, training = 4, trainings = { StormArchmage = 1, CopperCrossbow = 1 }, pace = 3.5 },
	{ towers = { FROST, MAGMA, COPPER }, training = 4, trainings = { Frost = 3, MagmaCatapult = 2, CopperCrossbow = 1 }, pace = 3.5 },
	{ towers = { MG, STORM, COPPER }, training = 4, trainings = { StormArchmage = 2, CopperCrossbow = 2 }, pace = 3.5 },
	{ towers = { MG, STORM, COPPER }, training = 4, trainings = { StormArchmage = 2, CopperCrossbow = 2 }, pace = 3.5 },
	{ towers = { MG, STORM, ROCKET, COPPER }, training = 4, trainings = { StormArchmage = 2, Rocket = 1, CopperCrossbow = 2 }, pace = 3.5 },
	{ towers = { MG, STORM, ROCKET, COPPER }, training = 4, trainings = { StormArchmage = 2, Rocket = 1, CopperCrossbow = 2 }, pace = 3.5 },
	{ towers = { FROST, MAGMA, ROCKET, COPPER }, training = 4, trainings = { Frost = 3, MagmaCatapult = 3, Rocket = 1, CopperCrossbow = 2 }, pace = 3.5 },
	{ towers = { MG, STORM, ROCKET, COPPER }, training = 4, trainings = { StormArchmage = 3, Rocket = 2, CopperCrossbow = 3 }, pace = 3.5 },
	{ towers = { MG, STORM, ROCKET, COPPER }, training = 4, trainings = { StormArchmage = 3, Rocket = 2, CopperCrossbow = 3 }, pace = 3.5 },
	-- 4e territoire
	{ towers = { FROST, STORM, ROCKET, COPPER }, training = 5, trainings = { StormArchmage = 4, Rocket = 3, CopperCrossbow = 4 }, pace = 3.5 },
	{ towers = { FROST, STORM, ROCKET, COPPER }, training = 5, trainings = { StormArchmage = 4, Rocket = 3, CopperCrossbow = 4 }, pace = 3.5 },
	{ towers = { FROST, STORM, ROCKET, COPPER }, training = 5, trainings = { StormArchmage = 4, Rocket = 3, CopperCrossbow = 4 }, pace = 3.5 },
	{ towers = { FROST, STORM, ROCKET, COPPER }, training = 5, trainings = { StormArchmage = 4, Rocket = 4, CopperCrossbow = 4 }, pace = 3.5 },
	{ towers = { FROST, STORM, ROCKET, COPPER }, training = 5, trainings = { StormArchmage = 4, Rocket = 4, CopperCrossbow = 4 }, pace = 3.5 },
	{ towers = { FROST, STORM, ROCKET, COPPER }, training = 5, trainings = { StormArchmage = 4, Rocket = 4, CopperCrossbow = 4 }, pace = 3.5 },
	{ towers = { FROST, STORM, ROCKET, COPPER }, training = 5, trainings = { Rocket = 4, CopperCrossbow = 4 }, pace = 3.5 },
	{ towers = { FROST, STORM, ROCKET, COPPER }, training = 5, trainings = { Rocket = 4, CopperCrossbow = 4 }, pace = 3.5 },
	{ towers = { MG, STORM, ROCKET, COPPER }, training = 5, trainings = { Rocket = 4 }, pace = 3.5 },
	{ towers = { MG, STORM, ROCKET, COPPER }, training = 5, trainings = { Rocket = 4 }, pace = 3.5 },
	-- 5e territoire (toujours fermé : Levels.OPEN_COUNT). Les mêmes tours qu'au 4e territoire, plus la Catapulte de
	-- givre (boss du niveau 40). Elles s'entraînent au fil des parties.
	{ towers = { MG, STORM, ROCKET, COPPER }, training = 6, trainings = { StormArchmage = 5, Rocket = 4, CopperCrossbow = 5 }, pace = 3.5 },
	{ towers = { MG, STORM, ROCKET, COPPER }, training = 6, trainings = { StormArchmage = 5, Rocket = 4, CopperCrossbow = 5 }, pace = 3.5 },
	{ towers = { MG, STORM, ROCKET, COPPER }, training = 6, trainings = { StormArchmage = 5, Rocket = 4, CopperCrossbow = 5 }, pace = 3.5 },
	{ towers = { MG, STORM, ROCKET, COPPER }, training = 6, trainings = { StormArchmage = 5, Rocket = 4, CopperCrossbow = 5 }, pace = 3.5 },
	{ towers = { FROST, STORM, ROCKET, COPPER }, training = 6, trainings = { Frost = 5, StormArchmage = 5, Rocket = 5, CopperCrossbow = 5 }, pace = 3.5 },
	{ towers = { FROST, STORM, ROCKET, COPPER }, training = 6, trainings = { Frost = 5, StormArchmage = 5, Rocket = 5, CopperCrossbow = 5 }, pace = 3.5 },
	{ towers = { MG, STORM, ROCKET, COPPER }, training = 6, trainings = { StormArchmage = 5, Rocket = 5, CopperCrossbow = 5 }, pace = 3.5 },
	{ towers = { FROST, STORM, ROCKET, COPPER }, training = 6, trainings = { StormArchmage = 5, Rocket = 5, CopperCrossbow = 5 }, pace = 3.5 },
	{ towers = { MG, STORM, ROCKET, COPPER }, training = 6, trainings = { StormArchmage = 5, Rocket = 5, CopperCrossbow = 5 }, pace = 3.5 },
	{ towers = { FROST, MAGMA, ROCKET, COPPER }, training = 6, trainings = { Rocket = 5, CopperCrossbow = 5 }, pace = 3.5 },
	-- 6e territoire
	{ towers = EIGHT, training = 4, trainings = { Laser = 3, Chain = 3, Orbital = 1 }, pace = 3.5 },
	{ towers = EIGHT, training = 4, trainings = { Laser = 3, Chain = 3, Orbital = 1 }, pace = 3.5 },
	{ towers = EIGHT, training = 4, trainings = { Laser = 3, Chain = 3, Orbital = 1 }, pace = 3.5 },
	{ towers = EIGHT, training = 4, trainings = { Laser = 3, Chain = 3, Orbital = 2 }, pace = 3.5 },
	{ towers = EIGHT, training = 4, trainings = { Laser = 3, Chain = 3, Orbital = 2 }, pace = 3.5 },
	{ towers = EIGHT, training = 4, trainings = { Chain = 3, Orbital = 2 }, pace = 3.5 },
	{ towers = EIGHT, training = 4, trainings = { Chain = 3, Orbital = 2 }, pace = 3.5 },
	{ towers = EIGHT, training = 4, trainings = { Chain = 3, Orbital = 2 }, pace = 3.5 },
	{ towers = EIGHT, training = 4, trainings = { Chain = 3, Orbital = 2 }, pace = 3.5 },
	{ towers = EIGHT, training = 4, trainings = { Chain = 3, Orbital = 2 }, pace = 3.5 },
	-- 7e territoire
	{ towers = EIGHT, training = 4, trainings = { Chain = 3, Orbital = 2 }, pace = 3.5 },
	{ towers = EIGHT, training = 4, trainings = { Chain = 3, Orbital = 2 }, pace = 3.5 },
	{ towers = EIGHT, training = 4, trainings = { Chain = 3, Orbital = 2 }, pace = 3.5 },
	{ towers = EIGHT, training = 4, trainings = { Chain = 3, Orbital = 3 }, pace = 3.5 },
	{ towers = EIGHT, training = 4, trainings = { Chain = 3, Orbital = 3 }, pace = 3.5 },
	{ towers = EIGHT, training = 4, trainings = { Chain = 3, Orbital = 3 }, pace = 3.5 },
	{ towers = EIGHT, training = 4, trainings = { Chain = 3, Orbital = 3 }, pace = 3.5 },
	{ towers = EIGHT, training = 4, trainings = { Chain = 3, Orbital = 3 }, pace = 3.5 },
	{ towers = EIGHT, training = 4, trainings = { Orbital = 3 }, pace = 3.5 },
	{ towers = EIGHT, training = 4, trainings = { Orbital = 3 }, pace = 3.5 },
	-- 8e territoire
	{ towers = EIGHT, training = 4, trainings = { Orbital = 3 }, pace = 3.5 },
	{ towers = EIGHT, training = 4, trainings = { Orbital = 3 }, pace = 3.5 },
	{ towers = EIGHT, training = 4, trainings = { Orbital = 3 }, pace = 3.5 },
	{ towers = EIGHT, training = 4, trainings = { Orbital = 3 }, pace = 3.5 },
	{ towers = EIGHT, training = 4, trainings = { Orbital = 3 }, pace = 3.5 },
	{ towers = EIGHT, training = 4, trainings = { MachineGun = 5, Bomb = 5, Orbital = 3 }, pace = 3.5 },
	{ towers = EIGHT, training = 4, trainings = { MachineGun = 5, Bomb = 5, Orbital = 3 }, pace = 3.5 },
	{ towers = EIGHT, training = 4, trainings = { MachineGun = 5, Bomb = 5, Frost = 5, Orbital = 3 }, pace = 3.5 },
	{ towers = EIGHT, training = 4, trainings = { MachineGun = 5, Bomb = 5, Frost = 5, Orbital = 3 }, pace = 3.5 },
	{ towers = EIGHT, training = 4, trainings = { MachineGun = 5, Bomb = 5, Frost = 5, Orbital = 3 }, pace = 3.5 },
	-- 9e territoire
	{ towers = EIGHT, training = 4, trainings = { MachineGun = 5, Bomb = 5, Frost = 5, Tesla = 5, Orbital = 3 }, pace = 3.5 },
	{ towers = EIGHT, training = 4, trainings = { MachineGun = 5, Bomb = 5, Frost = 5, Tesla = 5, Orbital = 3 }, pace = 3.5 },
	{ towers = EIGHT, training = 4, trainings = { MachineGun = 5, Bomb = 5, Frost = 5, Tesla = 5, Orbital = 3 }, pace = 3.5 },
	{ towers = EIGHT, training = 4, trainings = { MachineGun = 5, Bomb = 5, Frost = 5, Tesla = 5 }, pace = 3.5 },
	{ towers = EIGHT, training = 4, trainings = { MachineGun = 5, Bomb = 5, Frost = 5, Tesla = 5 }, pace = 3.5 },
	{ towers = EIGHT, training = 4, trainings = { MachineGun = 5, Bomb = 5, Frost = 5, Tesla = 5, Rocket = 5 }, pace = 3.5 },
	{ towers = EIGHT, training = 4, trainings = { MachineGun = 5, Bomb = 5, Frost = 5, Tesla = 5, Rocket = 5 }, pace = 3.5 },
	{ towers = EIGHT, training = 4, trainings = { MachineGun = 5, Bomb = 5, Frost = 5, Tesla = 5, Rocket = 5 }, pace = 3.5 },
	{ towers = EIGHT, training = 4, trainings = { MachineGun = 5, Bomb = 5, Frost = 5, Tesla = 5, Rocket = 5 }, pace = 3.5 },
	{ towers = EIGHT, training = 4, trainings = { MachineGun = 5, Bomb = 5, Frost = 5, Tesla = 5, Rocket = 5 }, pace = 3.5 },
	-- 10e territoire
	{ towers = EIGHT, training = 4, trainings = { MachineGun = 5, Bomb = 5, Frost = 5, Tesla = 5, Rocket = 5 }, pace = 3.5 },
	{ towers = EIGHT, training = 4, trainings = { MachineGun = 5, Bomb = 5, Frost = 5, Tesla = 5, Rocket = 5 }, pace = 3.5 },
	{ towers = EIGHT, training = 4, trainings = { MachineGun = 5, Bomb = 5, Frost = 5, Tesla = 5, Rocket = 5, Laser = 5 }, pace = 3.5 },
	{ towers = EIGHT, training = 4, trainings = { MachineGun = 5, Bomb = 5, Frost = 5, Tesla = 5, Rocket = 5, Laser = 5 }, pace = 3.5 },
	{ towers = EIGHT, training = 4, trainings = { MachineGun = 5, Bomb = 5, Frost = 5, Tesla = 5, Rocket = 5, Laser = 5 }, pace = 3.5 },
	{ towers = EIGHT, training = 4, trainings = { MachineGun = 5, Bomb = 5, Frost = 5, Tesla = 5, Rocket = 5, Laser = 5 }, pace = 3.5 },
	{ towers = EIGHT, training = 4, trainings = { MachineGun = 5, Bomb = 5, Frost = 5, Tesla = 5, Rocket = 5, Laser = 5 }, pace = 3.5 },
	{ towers = EIGHT, training = 4, trainings = { MachineGun = 5, Bomb = 5, Frost = 5, Tesla = 5, Rocket = 5, Laser = 5 }, pace = 3.5 },
	{ towers = EIGHT, training = 4, trainings = { MachineGun = 5, Bomb = 5, Frost = 5, Tesla = 5, Rocket = 5, Laser = 5 }, pace = 3.5 },
	{ towers = EIGHT, training = 4, trainings = { MachineGun = 5, Bomb = 5, Frost = 5, Tesla = 5, Rocket = 5, Laser = 5 }, pace = 3.5 },
}
-- Toutes les tours du jeu (les 21, tours spéciales comprises), pour les outils de mesure : plus qu'une barre, aucun
-- joueur ne peut les poser toutes dans un niveau.
Bot.ALL_TOWERS = table.clone(IdleTowers.ORDER)
-- La barre de celui qui a TOUT : une tour par rareté, des tours de palier 2 et une légendaire (« tout débloqué »).
Bot.FULL_BAR = { "FireArcher", "StormArchmage", "DragonBallista", "ThunderOracle", "CopperCrossbow" }
-- Ce qu'a un joueur sans aucune chance aux œufs : l'Archer (donné) et la Catapulte (l'œuf du niveau 1).
Bot.NO_EGG_TOWERS = { "MachineGun", "Bomb" }

-- Profil d'un joueur qui arrive à ce niveau avec les tours attendues. pace = secondes entre deux achats (un achat
-- à la fois) ; "reference" = le rythme demandé par le niveau ; absent = joueur très actif (il dépense tout, tout
-- de suite).
function Bot.profile(level: number, pace: (number | string)?)
	local expected = Bot.EXPECTED[level]
	local interval = if pace == "reference" then expected.pace else pace
	return { towers = expected.towers, training = expected.training, trainings = expected.trainings, interval = interval, actions = if interval then 1 else nil }
end

-- profile = { towers = { types débloqués }, training = niveau d'entraînement de toutes les tours (0 à 6),
--             trainings = { [type] = entraînement de cette tour-là, à la place de `training` },
--             interval = secondes entre deux décisions (0,4 par défaut : un joueur très actif),
--             actions = achats au plus par décision (20 par défaut : il dépense tout ce qu'il peut) }
-- Un joueur « moyen » (interval 3, actions 1) ou « lent » (interval 8, actions 1) sert à vérifier qu'un niveau
-- oblige à rester actif : il doit s'en sortir bien moins bien que le joueur actif.
-- Renvoie la meilleure partie parmi Bot.POLICIES : { won, ended, lives, seconds, kills, total, earned, spent,
--           towers = nombre posé, levels = somme des niveaux, build = texte « 5 MachineGun (3,3,2,2,2) ... » }.
-- enough(result) = vrai dès qu'une partie suffit à l'appelant : les autres façons de jouer ne sont pas essayées
-- (tests : « il gagne avec au moins 8 vies » n'a pas besoin de la meilleure des 9 parties).
function Bot.play(level: number, profile, enough: ((any) -> boolean)?)
	local best = nil
	for _, policy in Bot.POLICIES do
		local result = Bot.playWith(level, profile, policy)
		local better = best == nil
			or (result.won and not best.won)
			or (result.won == best.won and (if result.won then result.lives > best.lives else result.kills > best.kills))
		if better then
			best = result
		end
		if enough and enough(best) then
			break
		end
	end
	return best
end

-- Joueur qui pose ces tours dans l'ordre (sur les emplacements conseillés) dès qu'il a l'or, n'améliore jamais
-- rien, puis attend. towers = toutes les tours posées, celle offerte au niveau 1 comprise (la première de la
-- liste). Renvoie { won, lives, kills, total, seconds }.
function Bot.playLazy(level: number, towers: { string })
	local definition = Levels.definition(level)
	local arena = { index = Levels.arenaIndex(1), folder = Env.fakeInstance("Arena"), cframe = Levels.arenaCFrame(1), map = definition.map }
	local unlocked = {}
	for _, towerType in towers do
		unlocked[towerType] = true
	end
	local game = LevelGame.new(arena, { UserId = 1, Parent = {} }, { level = level, unlocked = unlocked, training = {}, startingTower = level == 1 })
	local spots = Levels.geometry(definition.map).map.spots
	-- (niveau 1 : la première tour de la liste est l'Archer offert, déjà posé au premier emplacement)
	local placed = if level == 1 then 1 else 0
	while game.state == "Running" and game.clock < Bot.MAX_SECONDS do
		local nextType = towers[placed + 1]
		if nextType and game.gold >= Levels.placeCost(nextType) and game:placeTower(nextType, spots[placed + 1]) then
			placed += 1
		end
		game:simulate(Bot.DT)
	end
	return { won = game.state == "Won", lives = game.lives, kills = game.kills, total = #game.queue, seconds = game.clock }
end

-- Ce qu'il faut aux joueurs simulés pour choisir où poser sur une carte : les emplacements à essayer, dans l'ordre
-- (candidateSpots), et les points de chaque couloir tous les 2 studs (longueur de chemin à portée d'une tour ; sur
-- une carte d'équipe, la partie commune est dans tous les couloirs : elle compte autant de fois qu'elle voit passer
-- de monstres).
local function mapContext(mapName: string)
	local geometry = Levels.geometry(mapName)
	local laneSamples = {}
	for index, lane in geometry.lanes do
		local samples = {}
		for distance = 0, lane.PATH_LENGTH, 2 do
			table.insert(samples, (lane.pointAt(distance)))
		end
		laneSamples[index] = samples
	end
	return { map = mapName, spots = candidateSpots(mapName), laneSamples = laneSamples, pathLength = geometry.PATH_LENGTH }
end

-- Tours posées d'une famille (une tour de palier 1 et sa version de palier 2 : IdleTowers.baseOf).
local function familyCopies(copies, family: string): number
	local count = 0
	for towerType, number in copies do
		if IdleTowers.baseOf(towerType) == family then
			count += number
		end
	end
	return count
end

local function near(a, b, range: number): boolean
	local dx, dz = a.X - b.X, a.Z - b.Z
	return dx * dx + dz * dz <= range * range
end

-- Le cerveau d'un joueur simulé dans une partie : la fonction renvoyée fait ses achats du moment (voir Bot.play),
-- avec SON or et SES tours. member = lui dans la partie (LevelGame : la partie elle-même pour un joueur seul, un des
-- game.members en équipe) ; ses tours débloquées et son entraînement sont les siens (member.unlocked, member.training).
-- Sur une carte d'équipe, il tient d'abord à SON couloir (celui de son rang dans la partie : il compte double),
-- comme un vrai joueur qui voit son nom à l'entrée ; la partie commune compte pour tous les couloirs à la fois.
local function makeDecider(game, member, profile, policy, context)
	local training, unlocked = member.training, member.unlocked
	local spots, pathLength = context.spots, context.pathLength
	local ownLane = table.find(game.members, member) or 1
	local samples = {} -- { { point, weight } }
	for index, laneSamples in context.laneSamples do
		for _, point in laneSamples do
			table.insert(samples, { point = point, weight = if index == ownLane then 2 else 1 })
		end
	end

	local function freeSpot()
		local positions = game:towerPositions()
		for _, spot in spots do
			if Levels.checkPlacement(context.map, spot, positions) then
				return spot
			end
		end
		return nil
	end

	-- Meilleur emplacement libre pour cette tour, comme le ferait un joueur attentif : celui d'où elle voit le plus
	-- de chemin. Totem de givre (et Totem du blizzard) : le plus de chemin déjà couvert par les autres tours (il les
	-- renforce).
	local function bestSpot(towerType: string)
		local positions = game:towerPositions()
		local range = Levels.towerStats(towerType, 1, training[towerType]).range
		local best, bestScore = nil, -1
		for _, spot in spots do
			if Levels.checkPlacement(context.map, spot, positions) then
				local score = 0
				for _, sample in samples do
					if near(sample.point, spot, range) then
						if IdleTowers.baseOf(towerType) == "Frost" then
							local covered = false
							for _, tower in game.towers do
								if IdleTowers.baseOf(tower.type) ~= "Frost" and near(sample.point, tower.localPosition, game:statsOf(tower).range) then
									covered = true
									break
								end
							end
							score += sample.weight * (if covered then 1 else 0.25)
						else
							score += sample.weight
						end
					end
				end
				if score > bestScore then
					best, bestScore = spot, score
				end
			end
		end
		return best
	end

	return function()
		for _ = 1, profile.actions or 20 do
			local total = 0
			local copies = game:copiesOf(member)
			for _, tower in game.towers do
				total += estimate(tower.type, tower.level, tower.owner.training[tower.type])
			end
			local danger = false
			for _, enemy in game.enemies do
				if not enemy.dead and enemy.distance + (enemy.laneOffset or 0) > pathLength * (policy.danger or Bot.DANGER) then
					danger = true
					break
				end
			end
			local spot = freeSpot()
			local options = {}
			if spot then
				for _, towerType in profile.towers do
					if (copies[towerType] or 0) < Levels.maxCopies(towerType) then
						local value = estimate(towerType, 1, training[towerType])
						local family = IdleTowers.baseOf(towerType)
						if family == "Frost" then
							-- Le Totem ralentit : il renforce toutes les autres tours (le premier surtout). Un monstre
							-- ralenti de s reste 1 / (1 - s) fois plus longtemps sous les tirs : le gain suit s / (1 - s).
							local slow = Levels.towerStats(towerType, 1, training[towerType]).slow or 0
							local gain = slow / math.max(0.05, 1 - slow) * Bot.FROST_GAIN
							value += total * gain * (if familyCopies(copies, family) == 0 then 1 else 0.3)
						elseif family == "Tesla" then
							-- Le Mage freine très fort, un court instant : les autres tours tirent plus longtemps.
							value += total * (if familyCopies(copies, family) == 0 then 0.15 else 0.05)
						else
							-- Catapulte de givre : elle ralentit les monstres qu'elle frappe (comme un Totem, mais seulement dans
							-- sa zone d'impact) : la moitié du gain d'un Totem.
							local stats = Levels.towerStats(towerType, 1, training[towerType])
							if stats.family == "Frost" and stats.slow then
								local gain = stats.slow / math.max(0.05, 1 - stats.slow) * Bot.FROST_GAIN * 0.5
								value += total * gain * (if (copies[towerType] or 0) == 0 then 1 else 0.3)
							end
						end
						value *= Bot.VALUE_SCALE[towerType] or 1
						table.insert(options, { cost = Levels.placeCost(towerType), value = value, place = towerType })
					end
				end
			end
			for id, tower in game.towers do
				local cost = if tower.owner == member then Levels.upgradeCost(tower.type, tower.level) else nil
				if cost then
					local value = estimate(tower.type, tower.level + 1, training[tower.type]) - estimate(tower.type, tower.level, training[tower.type])
					value *= Bot.VALUE_SCALE[tower.type] or 1
					table.insert(options, { cost = cost, value = value, upgrade = id })
				end
			end
			-- Des Archers d'abord (dégâts sûrs dès le début), si cette façon de jouer le demande.
			if spot and unlocked.MachineGun and (copies.MachineGun or 0) < math.min(policy.archers, Levels.maxCopies("MachineGun")) then
				if member.gold < Levels.placeCost("MachineGun") then
					return
				end
				game:placeTower("MachineGun", bestSpot("MachineGun") or spot, member)
				continue
			end
			local best, bestScore = nil, 0
			local affordable, affordableScore = nil, 0
			for _, option in options do
				local score = option.value / option.cost
				if score > bestScore then
					best, bestScore = option, score
				end
				if option.cost <= member.gold and score > affordableScore then
					affordable, affordableScore = option, score
				end
			end
			local choice = affordable
			if best and best.cost > member.gold and not danger and bestScore >= policy.patience * affordableScore then
				return -- il économise pour son meilleur achat
			end
			if not choice then
				return
			end
			if choice.place then
				game:placeTower(choice.place, bestSpot(choice.place) or spot, member)
			else
				game:upgradeTower(choice.upgrade, member)
			end
		end
	end
end

-- Tours posées par type (« 5 MachineGun (3,3,2,2,2) ... »), seulement celles de `owner` s'il est donné.
local function buildText(game, owner): (string, number, number)
	local levels, count = 0, 0
	local byType = {}
	for _, tower in game.towers do
		if owner == nil or tower.owner == owner then
			levels += tower.level
			count += 1
			byType[tower.type] = byType[tower.type] or {}
			table.insert(byType[tower.type], tower.level)
		end
	end
	local parts = {}
	for _, towerType in IdleTowers.ORDER do
		local list = byType[towerType]
		if list then
			table.sort(list, function(a, b)
				return a > b
			end)
			table.insert(parts, `{#list} {towerType} ({table.concat(list, ",")})`)
		end
	end
	return table.concat(parts, " "), count, levels
end

-- Tours débloquées et entraînement d'un profil (voir Bot.playWith).
local function profileSetup(profile)
	local unlocked, training = {}, {}
	for _, towerType in profile.towers do
		unlocked[towerType] = true
		training[towerType] = (profile.trainings and profile.trainings[towerType]) or profile.training or 0
	end
	return unlocked, training
end

-- observe(game, dégâts par seconde estimés de ses tours) : appelée après chaque décision (outils de réglage).
function Bot.playWith(level: number, profile, policy, observe: ((any, number) -> ())?)
	local definition = Levels.definition(level)
	local unlocked, training = profileSetup(profile)
	local arena = { index = Levels.arenaIndex(1), folder = Env.fakeInstance("Arena"), cframe = Levels.arenaCFrame(1), map = definition.map }
	local player = { UserId = 1, Parent = {} }
	local ended: boolean? = nil
	local game = LevelGame.new(arena, player, {
		level = level,
		unlocked = unlocked,
		training = training,
		startingTower = level == 1,
		onEnd = function(_, won)
			ended = won
		end,
	})
	local decide = makeDecider(game, game, profile, policy, mapContext(definition.map))
	local nextDecision = 0
	while ended == nil and game.clock < Bot.MAX_SECONDS do
		if game.clock >= nextDecision then
			nextDecision = game.clock + (profile.interval or Bot.DECISION_INTERVAL)
			decide()
			if observe then
				local total = 0
				for _, tower in game.towers do
					total += estimate(tower.type, tower.level, training[tower.type])
				end
				observe(game, total)
			end
		end
		game:simulate(Bot.DT)
	end
	local build, count, levels = buildText(game, nil)
	return {
		won = ended == true,
		ended = ended ~= nil,
		lives = game.lives,
		seconds = game.clock,
		kills = game.kills,
		total = #game.queue,
		earned = game.goldEarned,
		spent = game.goldSpent,
		towers = count,
		levels = levels,
		build = build,
	}
end

-- Une partie EN ÉQUIPE (« JOUER EN ÉQUIPE », Levels.luau) : un joueur simulé par profil, dans la même partie, chacun
-- avec son or et ses tours, qui décide à son propre rythme (profile.interval). Tous jouent de la même façon (policy).
-- Les monstres sont ceux d'une équipe de #profiles joueurs (Levels.TEAM_HEALTH), sur la carte d'équipe du territoire
-- (un couloir chacun : Levels.mapFor). Pas de tour offerte au niveau 1.
-- Renvoie { won, ended, lives, seconds, kills, total, towers = nombre posé, builds = { texte des tours de chacun } }.
function Bot.playTeamWith(level: number, profiles, policy)
	local definition = Levels.definition(level)
	local unlocked, training = profileSetup(profiles[1])
	local team = {}
	for index = 2, #profiles do
		local otherUnlocked, otherTraining = profileSetup(profiles[index])
		table.insert(team, { player = { UserId = index, Parent = {} }, unlocked = otherUnlocked, training = otherTraining })
	end
	local mapName = Levels.mapFor(level, #profiles)
	local arena = { index = Levels.arenaIndex(1), folder = Env.fakeInstance("Arena"), cframe = Levels.arenaCFrame(1), map = mapName }
	local ended: boolean? = nil
	local game = LevelGame.new(arena, { UserId = 1, Parent = {} }, {
		level = level,
		unlocked = unlocked,
		training = training,
		startingTower = level == 1 and #profiles == 1,
		team = team,
		onEnd = function(_, won)
			ended = won
		end,
	})
	local context = mapContext(mapName)
	local bots = {}
	for index, member in game.members do
		bots[index] = { decide = makeDecider(game, member, profiles[index], policy, context), interval = profiles[index].interval or Bot.DECISION_INTERVAL, nextDecision = 0 }
	end
	while ended == nil and game.clock < Bot.MAX_SECONDS do
		for _, bot in bots do
			if game.clock >= bot.nextDecision then
				bot.nextDecision = game.clock + bot.interval
				bot.decide()
			end
		end
		game:simulate(Bot.DT)
	end
	local builds, count = {}, 0
	for index, member in game.members do
		local build, towers = buildText(game, member)
		builds[index] = build
		count += towers
	end
	return {
		won = ended == true,
		ended = ended ~= nil,
		lives = game.lives,
		seconds = game.clock,
		kills = game.kills,
		total = #game.queue,
		towers = count,
		builds = builds,
	}
end

-- Comme Bot.play, pour une équipe : la meilleure partie parmi Bot.POLICIES (enough : voir Bot.play).
function Bot.playTeam(level: number, profiles, enough: ((any) -> boolean)?)
	local best = nil
	for _, policy in Bot.POLICIES do
		local result = Bot.playTeamWith(level, profiles, policy)
		local better = best == nil
			or (result.won and not best.won)
			or (result.won == best.won and (if result.won then result.lives > best.lives else result.kills > best.kills))
		if better then
			best = result
		end
		if enough and enough(best) then
			break
		end
	end
	return best
end

-- Une équipe de `size` joueurs simulés qui ont tous le même profil (Bot.profile : pace = rythme, voir là-bas).
function Bot.teamProfiles(level: number, size: number, pace: (number | string)?)
	local profiles = {}
	for _ = 1, size do
		table.insert(profiles, Bot.profile(level, pace))
	end
	return profiles
end

return Bot

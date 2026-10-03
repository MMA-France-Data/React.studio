--!optimize 2
-- Joueur simulé des niveaux : il joue un niveau avec le VRAI moteur (LevelGame.luau) et renvoie le résultat.
-- Il n'est ni parfait ni mauvais. À chaque décision, il regarde tous ses achats possibles (poser une tour de plus,
-- améliorer une tour posée), estime ce que chacun ajoute de dégâts par seconde, et prend celui qui en donne le plus
-- par pièce d'or ; s'il n'a pas encore l'or, il économise, sauf quand un monstre approche du château (il prend alors
-- le meilleur achat payable tout de suite). Il pose ses tours sur les emplacements conseillés de la carte.
-- Il sert à comparer des réglages et des profils de joueurs (quelles tours débloquées, quel entraînement), pas à
-- trouver la meilleure stratégie possible.
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

-- Dégâts par seconde estimés d'une tour (ordre de grandeur : zones et carreaux comptent plusieurs cibles).
local function estimate(towerType: string, level: number, training: number): number
	local stats = Levels.towerStats(towerType, level, training)
	if stats.kind == "Beam" then
		return stats.damage * 9
	elseif stats.kind == "Aura" then
		return stats.damage / stats.cooldown * 3
	elseif stats.kind == "Chain" then
		return stats.damage * stats.chains / stats.cooldown
	elseif stats.kind == "Splash" then
		return stats.damage / stats.cooldown * (1 + stats.splash / 3)
	elseif stats.kind == "Pierce" then
		return stats.damage / stats.cooldown * 2.2
	end
	local dps = stats.damage / stats.cooldown
	if stats.fireRadius then
		dps += IdleTowers.fireDps(stats) * 2
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

-- Ce qu'un joueur a quand il arrive à chaque niveau, sans rejouer ni attendre :
--   * tours : Totem (150 pièces) avant le niveau 3, Mage (400) avant le 6, payés avec les pièces de la première
--     victoire des niveaux d'avant (180 après le niveau 2, 740 après le 5). La Baliste (1 200) n'est jamais
--     attendue : elle se paie après le niveau 10 (ou en rejouant), comme toutes les tours suivantes ;
--   * entraînement : 8 XP par victoire pour chaque tour posée, soit le niveau 1 (20 XP) après 3 victoires et le
--     niveau 2 (60 XP) après 7 ou 8, le camp aidant.
-- pace = le RYTHME demandé par ce niveau : secondes entre deux achats du joueur de référence, celui pour qui le
-- niveau est réglé (tune.luau). Le premier niveau laisse un peu de temps, les derniers demandent un achat toutes
-- les 3,5 secondes (un humain choisit moins bien que le joueur simulé : il doit aller un peu plus vite que ça).
-- 2e territoire (niveaux 11 à 20) :
--   * la Baliste (1 200 pièces) est achetée en arrivant : les 10 premiers niveaux donnent 2 180 pièces, moins le
--     Totem et le Mage (550) ;
--   * le Sorcier (3 000) avant le niveau 18, avec les pièces des niveaux 11 à 17 (2 620) ;
--   * trainings = entraînement d'une tour à part : une tour qui vient d'être achetée n'est pas encore entraînée
--     (la Baliste n'a donc pas encore son carreau perçant, qui vient à l'entraînement 2).
-- 3e et 4e territoires (niveaux 21 à 40) :
--   * il reste 2 110 pièces en arrivant au niveau 21 ; les niveaux 21 à 30 en donnent 7 180 : l'Oracle (8 000) est
--     acheté en arrivant au niveau 31. Le Trébuchet (15 000) n'est jamais attendu : les 40 niveaux réussis une fois
--     ne le paient pas (il faut rejouer) ;
--   * entraînement : 8 XP par victoire pour chaque tour posée, sans compter le camp. La Baliste (achetée au niveau
--     11) passe à l'entraînement 3 au niveau 29 ; le Sorcier (niveau 18) à 1 au 21, 2 au 26, 3 au 36 ; l'Oracle
--     (niveau 31) à 1 au 34, 2 au 39 ; l'Archer et la Catapulte (dès le niveau 1) à 4 au 39 ; les autres restent à 3.
-- 5e et 6e territoires (niveaux 41 à 60) :
--   * il reste 10 970 pièces en arrivant au niveau 41 ; avec les niveaux 41 à 45 (5 140), le Trébuchet (15 000) est
--     acheté en arrivant au niveau 46 : toutes les tours sont à lui ;
--   * entraînement (8 XP par victoire, sans le camp) : le Totem à 4 au niveau 41, le Mage au 44, la Baliste au 49, le
--     Sorcier au 56 ; l'Oracle à 3 au 49 ; le Trébuchet à 1 au 49, 2 au 54.
local MG, BOMB, FROST, TESLA, ROCKET, LASER, CHAIN, ORBITAL = "MachineGun", "Bomb", "Frost", "Tesla", "Rocket", "Laser", "Chain", "Orbital"
local SIX = { MG, BOMB, FROST, TESLA, ROCKET, LASER }
local SEVEN = { MG, BOMB, FROST, TESLA, ROCKET, LASER, CHAIN }
local EIGHT = { MG, BOMB, FROST, TESLA, ROCKET, LASER, CHAIN, ORBITAL }
Bot.EXPECTED = {
	{ towers = { MG, BOMB }, training = 0, pace = 5 },
	{ towers = { MG, BOMB }, training = 0, pace = 4.5 },
	{ towers = { MG, BOMB, FROST }, training = 0, pace = 4 },
	{ towers = { MG, BOMB, FROST }, training = 1, pace = 4 },
	{ towers = { MG, BOMB, FROST }, training = 1, pace = 4 },
	{ towers = { MG, BOMB, FROST, TESLA }, training = 1, pace = 3.5 },
	{ towers = { MG, BOMB, FROST, TESLA }, training = 1, pace = 3.5 },
	{ towers = { MG, BOMB, FROST, TESLA }, training = 2, pace = 3.5 },
	{ towers = { MG, BOMB, FROST, TESLA }, training = 2, pace = 3.5 },
	{ towers = { MG, BOMB, FROST, TESLA }, training = 2, pace = 3.5 },
	-- 2e territoire
	{ towers = { MG, BOMB, FROST, TESLA, ROCKET }, training = 2, trainings = { Rocket = 0 }, pace = 3.5 },
	{ towers = { MG, BOMB, FROST, TESLA, ROCKET }, training = 2, trainings = { Rocket = 0 }, pace = 3.5 },
	{ towers = { MG, BOMB, FROST, TESLA, ROCKET }, training = 2, trainings = { Rocket = 0 }, pace = 3.5 },
	{ towers = { MG, BOMB, FROST, TESLA, ROCKET }, training = 2, trainings = { Rocket = 1 }, pace = 3.5 },
	{ towers = { MG, BOMB, FROST, TESLA, ROCKET }, training = 2, trainings = { Rocket = 1 }, pace = 3.5 },
	{ towers = { MG, BOMB, FROST, TESLA, ROCKET }, training = 2, trainings = { Rocket = 1 }, pace = 3.5 },
	{ towers = { MG, BOMB, FROST, TESLA, ROCKET }, training = 2, trainings = { Rocket = 1 }, pace = 3.5 },
	{ towers = { MG, BOMB, FROST, TESLA, ROCKET, LASER }, training = 3, trainings = { Rocket = 2, Laser = 0 }, pace = 3.5 },
	{ towers = { MG, BOMB, FROST, TESLA, ROCKET, LASER }, training = 3, trainings = { Rocket = 2, Laser = 0 }, pace = 3.5 },
	{ towers = { MG, BOMB, FROST, TESLA, ROCKET, LASER }, training = 3, trainings = { Rocket = 2, Laser = 0 }, pace = 3.5 },
	-- 3e territoire
	{ towers = SIX, training = 3, trainings = { Rocket = 2, Laser = 1 }, pace = 3.5 },
	{ towers = SIX, training = 3, trainings = { Rocket = 2, Laser = 1 }, pace = 3.5 },
	{ towers = SIX, training = 3, trainings = { Rocket = 2, Laser = 1 }, pace = 3.5 },
	{ towers = SIX, training = 3, trainings = { Rocket = 2, Laser = 1 }, pace = 3.5 },
	{ towers = SIX, training = 3, trainings = { Rocket = 2, Laser = 1 }, pace = 3.5 },
	{ towers = SIX, training = 3, trainings = { Rocket = 2, Laser = 2 }, pace = 3.5 },
	{ towers = SIX, training = 3, trainings = { Rocket = 2, Laser = 2 }, pace = 3.5 },
	{ towers = SIX, training = 3, trainings = { Rocket = 2, Laser = 2 }, pace = 3.5 },
	{ towers = SIX, training = 3, trainings = { Rocket = 3, Laser = 2 }, pace = 3.5 },
	{ towers = SIX, training = 3, trainings = { Rocket = 3, Laser = 2 }, pace = 3.5 },
	-- 4e territoire
	{ towers = SEVEN, training = 3, trainings = { Rocket = 3, Laser = 2, Chain = 0 }, pace = 3.5 },
	{ towers = SEVEN, training = 3, trainings = { Rocket = 3, Laser = 2, Chain = 0 }, pace = 3.5 },
	{ towers = SEVEN, training = 3, trainings = { Rocket = 3, Laser = 2, Chain = 0 }, pace = 3.5 },
	{ towers = SEVEN, training = 3, trainings = { Rocket = 3, Laser = 2, Chain = 1 }, pace = 3.5 },
	{ towers = SEVEN, training = 3, trainings = { Rocket = 3, Laser = 2, Chain = 1 }, pace = 3.5 },
	{ towers = SEVEN, training = 3, trainings = { Rocket = 3, Laser = 3, Chain = 1 }, pace = 3.5 },
	{ towers = SEVEN, training = 3, trainings = { Rocket = 3, Laser = 3, Chain = 1 }, pace = 3.5 },
	{ towers = SEVEN, training = 3, trainings = { Rocket = 3, Laser = 3, Chain = 1 }, pace = 3.5 },
	{ towers = SEVEN, training = 3, trainings = { MachineGun = 4, Bomb = 4, Rocket = 3, Laser = 3, Chain = 2 }, pace = 3.5 },
	{ towers = SEVEN, training = 3, trainings = { MachineGun = 4, Bomb = 4, Rocket = 3, Laser = 3, Chain = 2 }, pace = 3.5 },
	-- 5e territoire
	{ towers = SEVEN, training = 3, trainings = { MachineGun = 4, Bomb = 4, Frost = 4, Rocket = 3, Laser = 3, Chain = 2 }, pace = 3.5 },
	{ towers = SEVEN, training = 3, trainings = { MachineGun = 4, Bomb = 4, Frost = 4, Rocket = 3, Laser = 3, Chain = 2 }, pace = 3.5 },
	{ towers = SEVEN, training = 3, trainings = { MachineGun = 4, Bomb = 4, Frost = 4, Rocket = 3, Laser = 3, Chain = 2 }, pace = 3.5 },
	{ towers = SEVEN, training = 4, trainings = { Rocket = 3, Laser = 3, Chain = 2 }, pace = 3.5 },
	{ towers = SEVEN, training = 4, trainings = { Rocket = 3, Laser = 3, Chain = 2 }, pace = 3.5 },
	{ towers = EIGHT, training = 4, trainings = { Rocket = 3, Laser = 3, Chain = 2, Orbital = 0 }, pace = 3.5 },
	{ towers = EIGHT, training = 4, trainings = { Rocket = 3, Laser = 3, Chain = 2, Orbital = 0 }, pace = 3.5 },
	{ towers = EIGHT, training = 4, trainings = { Rocket = 3, Laser = 3, Chain = 2, Orbital = 0 }, pace = 3.5 },
	{ towers = EIGHT, training = 4, trainings = { Laser = 3, Chain = 3, Orbital = 1 }, pace = 3.5 },
	{ towers = EIGHT, training = 4, trainings = { Laser = 3, Chain = 3, Orbital = 1 }, pace = 3.5 },
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
}
Bot.ALL_TOWERS = { "MachineGun", "Frost", "Bomb", "Tesla", "Rocket", "Laser", "Chain", "Orbital" }

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
-- liste). Seulement les tours de départ. Renvoie { won, lives, kills, total, seconds }.
function Bot.playLazy(level: number, towers: { string })
	local definition = Levels.definition(level)
	local arena = { index = Levels.arenaIndex(1), folder = Env.fakeInstance("Arena"), cframe = Levels.arenaCFrame(1), map = definition.map }
	local unlocked = {}
	for _, towerType in Levels.STARTING_TOWERS do
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

-- Joueur qui SUIT LE GUIDE du tuto (Levels.coachAdvice, la flèche de TutorialUI) : chaque achat que la flèche lui
-- montre, il met `delay` secondes à le faire (deux appuis : prendre la tour puis toucher un « + », ou toucher une
-- tour puis « Améliorer »). Il pose toujours sur le premier emplacement conseillé encore libre : celui que la flèche
-- montre. Quand il n'a pas de quoi payer, rien ne lui est montré : il attend.
-- towers = ses tours (celles de départ si absent), training = leur entraînement (0 si absent).
-- Renvoie { won, lives, kills, total, seconds, purchases, build }.
function Bot.playCoached(level: number, delay: number, towers: { string }?, training: number?)
	local definition = Levels.definition(level)
	local owned = towers or Levels.STARTING_TOWERS
	local unlocked, trained = {}, {}
	for _, towerType in owned do
		unlocked[towerType] = true
		trained[towerType] = training or 0
	end
	local arena = { index = Levels.arenaIndex(1), folder = Env.fakeInstance("Arena"), cframe = Levels.arenaCFrame(1), map = definition.map }
	local game = LevelGame.new(arena, { UserId = 1, Parent = {} }, { level = level, unlocked = unlocked, training = trained, startingTower = level == 1 })
	local spots = Levels.geometry(definition.map).map.spots
	local shownAt: number? = nil -- heure où la flèche a commencé à montrer un achat
	local purchases = 0
	while game.state == "Running" and game.clock < Bot.MAX_SECONDS do
		local list = {}
		for _, tower in game.towers do
			table.insert(list, tower)
		end
		table.sort(list, function(a, b)
			return a.id < b.id
		end)
		local advice = Levels.coachAdvice(owned, list, game.gold, trained)
		if not advice then
			shownAt = nil
		elseif not shownAt then
			shownAt = game.clock
		elseif game.clock - shownAt >= delay then
			local done = false
			if advice.kind == "Place" then
				local positions = game:towerPositions()
				for _, spot in spots do
					if Levels.checkPlacement(definition.map, spot, positions) then
						done = game:placeTower(advice.tower, spot)
						break
					end
				end
			else
				done = game:upgradeTower(list[advice.index].id)
			end
			if done then
				purchases += 1
			end
			shownAt = nil
		end
		game:simulate(Bot.DT)
	end
	local byType = {}
	for _, tower in game.towers do
		byType[tower.type] = byType[tower.type] or {}
		table.insert(byType[tower.type], tower.level)
	end
	local parts = {}
	for _, towerType in IdleTowers.ORDER do
		local levels = byType[towerType]
		if levels then
			table.sort(levels, function(a, b)
				return a > b
			end)
			table.insert(parts, `{#levels} {towerType} ({table.concat(levels, ",")})`)
		end
	end
	return {
		won = game.state == "Won",
		lives = game.lives,
		kills = game.kills,
		total = #game.queue,
		seconds = game.clock,
		purchases = purchases,
		unspent = math.floor(game.gold),
		build = table.concat(parts, " "),
	}
end

-- observe(game, dégâts par seconde estimés de ses tours) : appelée après chaque décision (outils de réglage).
function Bot.playWith(level: number, profile, policy, observe: ((any, number) -> ())?)
	local definition = Levels.definition(level)
	local unlocked, training = {}, {}
	for _, towerType in profile.towers do
		unlocked[towerType] = true
		training[towerType] = (profile.trainings and profile.trainings[towerType]) or profile.training or 0
	end
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

	local spots = candidateSpots(definition.map)
	local geometry = Levels.geometry(definition.map)
	local pathLength = geometry.PATH_LENGTH
	local nextDecision = 0

	-- Points du chemin, tous les 2 studs : sert à choisir où poser (longueur de chemin à portée d'une tour).
	local samples = {}
	for distance = 0, pathLength, 2 do
		table.insert(samples, (geometry.pointAt(distance)))
	end
	local function near(a, b, range: number): boolean
		local dx, dz = a.X - b.X, a.Z - b.Z
		return dx * dx + dz * dz <= range * range
	end

	local function freeSpot()
		local positions = game:towerPositions()
		for _, spot in spots do
			if Levels.checkPlacement(definition.map, spot, positions) then
				return spot
			end
		end
		return nil
	end

	-- Meilleur emplacement libre pour cette tour, comme le ferait un joueur attentif : celui d'où elle voit le plus
	-- de chemin. Totem de givre : le plus de chemin déjà couvert par les autres tours (il les renforce).
	local function bestSpot(towerType: string)
		local positions = game:towerPositions()
		local range = Levels.towerStats(towerType, 1, training[towerType]).range
		local best, bestScore = nil, -1
		for _, spot in spots do
			if Levels.checkPlacement(definition.map, spot, positions) then
				local score = 0
				for _, sample in samples do
					if near(sample, spot, range) then
						if towerType == "Frost" then
							local covered = false
							for _, tower in game.towers do
								if tower.type ~= "Frost" and near(sample, tower.localPosition, game:statsOf(tower).range) then
									covered = true
									break
								end
							end
							score += if covered then 1 else 0.25
						else
							score += 1
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

	local function decide()
		for _ = 1, profile.actions or 20 do
			local total = 0
			local copies = IdleTowers.countCopies(game.towers)
			for _, tower in game.towers do
				total += estimate(tower.type, tower.level, training[tower.type])
			end
			local danger = false
			for _, enemy in game.enemies do
				if not enemy.dead and enemy.distance > pathLength * (policy.danger or Bot.DANGER) then
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
						if towerType == "Frost" then
							-- Le Totem ralentit : il renforce toutes les autres tours (le premier surtout). Un monstre
							-- ralenti de s reste 1 / (1 - s) fois plus longtemps sous les tirs : le gain suit s / (1 - s).
							local slow = Levels.towerStats("Frost", 1, training.Frost).slow or 0
							local gain = slow / math.max(0.05, 1 - slow) * Bot.FROST_GAIN
							value += total * gain * (if (copies.Frost or 0) == 0 then 1 else 0.3)
						elseif towerType == "Tesla" then
							-- Le Mage freine très fort, un court instant : les autres tours tirent plus longtemps.
							value += total * (if (copies.Tesla or 0) == 0 then 0.15 else 0.05)
						end
						value *= Bot.VALUE_SCALE[towerType] or 1
						table.insert(options, { cost = Levels.placeCost(towerType), value = value, place = towerType })
					end
				end
			end
			for id, tower in game.towers do
				local cost = Levels.upgradeCost(tower.type, tower.level)
				if cost then
					local value = estimate(tower.type, tower.level + 1, training[tower.type]) - estimate(tower.type, tower.level, training[tower.type])
					value *= Bot.VALUE_SCALE[tower.type] or 1
					table.insert(options, { cost = cost, value = value, upgrade = id })
				end
			end
			-- Des Archers d'abord (dégâts sûrs dès le début), si cette façon de jouer le demande.
			if spot and unlocked.MachineGun and (copies.MachineGun or 0) < math.min(policy.archers, Levels.maxCopies("MachineGun")) then
				if game.gold < Levels.placeCost("MachineGun") then
					return
				end
				game:placeTower("MachineGun", bestSpot("MachineGun") or spot)
				continue
			end
			local best, bestScore = nil, 0
			local affordable, affordableScore = nil, 0
			for _, option in options do
				local score = option.value / option.cost
				if score > bestScore then
					best, bestScore = option, score
				end
				if option.cost <= game.gold and score > affordableScore then
					affordable, affordableScore = option, score
				end
			end
			local choice = affordable
			if best and best.cost > game.gold and not danger and bestScore >= policy.patience * affordableScore then
				return -- il économise pour son meilleur achat
			end
			if not choice then
				return
			end
			if choice.place then
				game:placeTower(choice.place, bestSpot(choice.place) or spot)
			else
				game:upgradeTower(choice.upgrade)
			end
		end
	end

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

	local levels, count = 0, 0
	local byType = {}
	for _, tower in game.towers do
		levels += tower.level
		count += 1
		byType[tower.type] = byType[tower.type] or {}
		table.insert(byType[tower.type], tower.level)
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
		build = table.concat(parts, " "),
	}
end

return Bot

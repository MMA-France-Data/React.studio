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
local Shim = require("../balance/idle/shim")

local Bot = {}

Bot.DT = 1 / 30 -- pas de simulation (comme une image du serveur)
Bot.DECISION_INTERVAL = 0.4 -- secondes entre deux décisions du joueur simulé
Bot.MAX_SECONDS = 900
Bot.DANGER = 0.55 -- part du chemin au-delà de laquelle un monstre fait acheter tout de suite

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
--   archers = nombre d'Archers posés avant tout le reste (des dégâts sûrs dès le début).
Bot.POLICIES = {
	{ patience = math.huge, archers = 0 },
	{ patience = 1.2, archers = 3 },
	{ patience = 1.2, archers = 5 },
	{ patience = 1.6, archers = 3 },
	{ patience = 1.6, archers = 5 },
}

-- profile = { towers = { types débloqués }, training = niveau d'entraînement de toutes les tours (0 à 6) }
-- Renvoie la meilleure partie parmi Bot.POLICIES : { won, ended, lives, seconds, kills, total, earned, spent,
--           towers = nombre posé, levels = somme des niveaux, build = texte « 5 MachineGun (3,3,2,2,2) ... » }.
function Bot.play(level: number, profile)
	local best = nil
	for _, policy in Bot.POLICIES do
		local result = Bot.playWith(level, profile, policy)
		local better = best == nil
			or (result.won and not best.won)
			or (result.won == best.won and (if result.won then result.lives > best.lives else result.kills > best.kills))
		if better then
			best = result
		end
	end
	return best
end

function Bot.playWith(level: number, profile, policy)
	local definition = Levels.definition(level)
	local unlocked, training = {}, {}
	for _, towerType in profile.towers do
		unlocked[towerType] = true
		training[towerType] = profile.training or 0
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
		for _ = 1, 20 do
			local total = 0
			local copies = IdleTowers.countCopies(game.towers)
			for _, tower in game.towers do
				total += estimate(tower.type, tower.level, training[tower.type])
			end
			local danger = false
			for _, enemy in game.enemies do
				if not enemy.dead and enemy.distance > pathLength * Bot.DANGER then
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
							-- Le Totem ralentit : il renforce toutes les autres tours (le premier surtout).
							value += total * (if (copies.Frost or 0) == 0 then 0.35 else 0.1)
						end
						table.insert(options, { cost = Levels.placeCost(towerType), value = value, place = towerType })
					end
				end
			end
			for id, tower in game.towers do
				local cost = Levels.upgradeCost(tower.type, tower.level)
				if cost then
					local value = estimate(tower.type, tower.level + 1, training[tower.type]) - estimate(tower.type, tower.level, training[tower.type])
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
			nextDecision = game.clock + Bot.DECISION_INTERVAL
			decide()
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

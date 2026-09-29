--!optimize 2
-- Vérification du moteur du simulateur (run.ps1 -Verifier) : le VRAI PlotGame.luau (serveur) et Engine.luau
-- jouent les mêmes vagues avec les mêmes tours, et doivent donner le même résultat (réussie ou ratée) et
-- presque la même durée. À relancer après chaque changement de combat dans PlotGame.luau.
-- Pas de temps : 1/32 s dans les deux (un nombre exact en binaire : sans ça, 0,2 - 4 x 0,05 vaut un tout petit
-- peu plus que 0 et PlotGame attend un pas de plus que le moteur, qui a une petite marge ; les deux ne
-- joueraient plus exactement la même partie).
-- La parcelle est placée au centre du monde (RING_RADIUS = 0) : le jeu calcule les distances en coordonnées
-- du monde (ex. 140 + z), le moteur en coordonnées de la parcelle (z) ; les deux donnent la même chose à un
-- chouïa près, mais un chouïa suffit parfois à garder ou lâcher une cible un pas plus tôt.
local Extra = require("./extra")
require("../gen/verif/shared/PlotLayout").RING_RADIUS = 0
local PlotGame = require("../gen/verif/server/Hub/PlotGame")
local Engine = require("../Engine")
-- Pas de marge d'arrondi dans le moteur : avec un pas exact en binaire, il doit faire EXACTEMENT comme le jeu.
Engine.EPS = 0

local DT = 1 / 32

local function newGame()
	local data = {
		coins = 0,
		idle = {
			towers = {},
			ownedSpots = {},
			unlockedTowers = {},
			towerDupes = {},
			bonuses = {},
			coinBonus = 0,
			rebirths = 0,
			wave = 1,
			bestWave = 1,
			highestWave = 1,
			unlockedSpots = 22,
			forgeSpinsBought = 0,
			towerSpinsBought = 0,
		},
	}
	for spot = 1, 22 do
		data.idle.ownedSpots[tostring(spot)] = true
	end
	local player = { UserId = 1, Parent = {}, __data = data }
	function player:SetAttribute() end
	return PlotGame.new({ index = 1, folder = Extra.fakeInstance("Plot") }, player, data)
end

-- La vague dans le vrai jeu : réussie ?, durée, pièces tombées.
local function realWave(team, wave: number)
	local game = newGame()
	-- Posées dans l'ordre des emplacements : la table des tours les parcourt alors dans cet ordre, comme le
	-- moteur (sinon deux tours peuvent tirer dans l'autre ordre au même pas, et une vague ratée de justesse
	-- peut rater quelques secondes plus tôt ou plus tard).
	local sorted = table.clone(team)
	table.sort(sorted, function(a, b)
		return a.spot < b.spot
	end)
	for _, member in sorted do
		game:createTower(member.spot, member.type, member.level, 0, member.runes)
	end
	game.idle.wave = wave
	game:clearEnemies()
	game:startWave()
	local start = game.clock
	local steps = 0
	while game.state == "Running" and steps < 400000 do
		game:step(DT)
		steps += 1
	end
	local coins = 0
	for _, drop in game.drops do
		coins += drop.amount
	end
	return game.idle.wave == wave + 1, game.clock - start, coins
end

-- La même vague dans le moteur du simulateur.
local function engineWave(team, wave: number)
	local sorted = table.clone(team)
	table.sort(sorted, function(a, b)
		return a.spot < b.spot
	end)
	local towers = {}
	for _, member in sorted do
		table.insert(towers, Engine.compileTower(member.spot, member.type, member.level, 0, member.runes))
	end
	local result = Engine.runWave(Engine.composition(wave), towers, nil, DT)
	return result.success, result.seconds, result.coins
end

-- Équipes : toutes les tours (avec des runes : x2 vitesse, x3 dégâts, et les deux cumulées sur l'Archer et
-- une Baliste), que des Archers (feu), des Sorciers avec Totem et Mage (rayon, ralentissements), Mages +
-- Catapultes + Baliste + Trébuchet (zones, projectiles lents), « contrôles » : 2 Totems, 2 Mages,
-- 2 Trébuchets, 2 Balistes et 2 Archers (un seul contrôle à la fois, fragilité, carreau perçant, visée des
-- foules, étourdissement), et la composition du propriétaire à la vague 148 : 4 Mages avec x2 vitesse et des
-- Catapultes (fatigue du ralentissement du Mage, projectiles qui suivent une cible ralentie pendant le vol).
-- runes = texte de l'attribut « Bonus » (IdleConfig.runeList).
local TEAMS = {
	{ name = "toutes les tours", members = {
		{ spot = 1, type = "MachineGun", runes = "Damage3,Speed2" }, { spot = 2, type = "Frost" }, { spot = 3, type = "Bomb" },
		{ spot = 4, type = "Tesla" }, { spot = 5, type = "Rocket" }, { spot = 6, type = "Laser", runes = "Speed2" },
		{ spot = 7, type = "Chain" }, { spot = 8, type = "Orbital", runes = "Damage3" },
	} },
	{ name = "Archers", members = {
		{ spot = 1, type = "MachineGun" }, { spot = 2, type = "MachineGun" }, { spot = 3, type = "MachineGun" },
		{ spot = 4, type = "MachineGun" }, { spot = 9, type = "MachineGun" }, { spot = 10, type = "MachineGun" },
	} },
	{ name = "Sorciers + ralentis", members = {
		{ spot = 1, type = "Laser" }, { spot = 2, type = "Frost" }, { spot = 5, type = "Laser" },
		{ spot = 6, type = "Laser" }, { spot = 3, type = "Tesla" },
	} },
	{ name = "zones et projectiles", members = {
		{ spot = 1, type = "Tesla" }, { spot = 2, type = "Tesla" }, { spot = 3, type = "Bomb" },
		{ spot = 4, type = "Bomb" }, { spot = 9, type = "Rocket" }, { spot = 10, type = "Orbital" },
	} },
	{ name = "contrôles", members = {
		{ spot = 1, type = "Frost" }, { spot = 2, type = "Tesla" }, { spot = 3, type = "Frost" },
		{ spot = 4, type = "Tesla" }, { spot = 5, type = "Orbital" }, { spot = 6, type = "Rocket" },
		{ spot = 9, type = "MachineGun" }, { spot = 10, type = "Orbital" }, { spot = 11, type = "Rocket", runes = "Damage2,Speed2" },
		{ spot = 12, type = "MachineGun" },
	} },
	{ name = "Mages x2 + Catapultes", members = {
		{ spot = 1, type = "Tesla", runes = "Speed2" }, { spot = 2, type = "Tesla", runes = "Speed2" },
		{ spot = 5, type = "Tesla", runes = "Speed2" }, { spot = 6, type = "Tesla", runes = "Speed2" },
		{ spot = 3, type = "Bomb" }, { spot = 4, type = "Bomb" }, { spot = 7, type = "Bomb" },
		{ spot = 9, type = "MachineGun" }, { spot = 10, type = "Rocket" },
	} },
}

local function withLevel(members, level: number)
	local team = {}
	for _, member in members do
		table.insert(team, { spot = member.spot, type = member.type, level = level, runes = member.runes })
	end
	return team
end

local total, same, worstGap, problems = 0, 0, 0, {}
for _, team in TEAMS do
	for _, wave in { 8, 12, 15, 20, 25, 30, 40, 50, 60 } do
		-- Le niveau qui rend la vague serrée (le premier qui réussit dans le moteur), puis un de moins et 3 de plus.
		local tight = 1
		for level = 1, 400 do
			if engineWave(withLevel(team.members, level), wave) then
				tight = level
				break
			end
		end
		for _, delta in { -1, 0, 3 } do
			local level = math.max(1, tight + delta)
			local okGame, timeGame, coinsGame = realWave(withLevel(team.members, level), wave)
			local okEngine, timeEngine, coinsEngine = engineWave(withLevel(team.members, level), wave)
			total += 1
			local gap = math.abs(timeGame - timeEngine)
			worstGap = math.max(worstGap, gap)
			if okGame == okEngine then
				same += 1
			end
			if okGame ~= okEngine or gap > 2 or (okGame and math.abs(coinsGame - coinsEngine) > 1e-6 * coinsGame) then
				table.insert(
					problems,
					string.format(
						"%s, vague %d, niveau %d : jeu %s en %.2f s (%.4g pièces), moteur %s en %.2f s (%.4g pièces)",
						team.name, wave, level, if okGame then "réussie" else "ratée", timeGame, coinsGame,
						if okEngine then "réussie" else "ratée", timeEngine, coinsEngine
					)
				)
			end
		end
	end
end

print(string.format("Vérification du moteur : %d vagues sur %d ont le même résultat dans PlotGame et dans le moteur ; plus grand écart de durée : %.2f s.", same, total, worstGap))

-- Essais « dégâts comptés » (projectiles qui suivent leur cible, fatigue des contrôles) : une vague faite à la
-- main, des ennemis presque immortels qui traversent le chemin sous les étourdissements des Trébuchets et les
-- éclairs des Mages, jusqu'à la première fuite. On additionne les dégâts de chaque type de tour (feu des
-- flèches compris) dans le jeu et dans le moteur : ils doivent être les mêmes. (Les vagues du dessus y sont peu
-- sensibles : un rocher qui ne suit pas sa cible la touche encore souvent grâce à sa zone.)
local HIT_TESTS = {
	{ name = "cavaliers étourdis", enemy = "Fast", count = 14, gap = 0.35, members = {
		{ spot = 8, type = "Orbital" }, { spot = 10, type = "Orbital" }, { spot = 3, type = "Bomb" },
		{ spot = 4, type = "Bomb" }, { spot = 6, type = "Rocket" }, { spot = 2, type = "MachineGun" },
	} },
	{ name = "Mages x2 et Catapultes", enemy = "Normal", count = 12, gap = 0.5, members = {
		{ spot = 1, type = "Tesla", runes = "Speed2" }, { spot = 2, type = "Tesla", runes = "Speed2" },
		{ spot = 3, type = "Bomb" }, { spot = 7, type = "Bomb" }, { spot = 5, type = "Rocket" }, { spot = 10, type = "Orbital" },
	} },
}

-- Dégâts de chaque type de tour dans le vrai jeu jusqu'à la première fuite (hitEnemy : un coup direct, de zone
-- ou de carreau ; burnFires : le feu, qui compte pour l'Archer, seule tour qui enflamme le sol), et durée de
-- la vague. Pas de Totem dans ces essais : pas de fragilité.
local function realHits(team, list)
	local game = newGame()
	local sorted = table.clone(team)
	table.sort(sorted, function(a, b)
		return a.spot < b.spot
	end)
	for _, member in sorted do
		game:createTower(member.spot, member.type, 1, 0, member.runes)
	end
	local hits = {}
	local originalHit, originalBurn, originalDamage = game.hitEnemy, game.burnFires, game.damageEnemy
	local burning = false
	game.hitEnemy = function(self, enemy, stats, now)
		hits[stats.towerType] = (hits[stats.towerType] or 0) + stats.damage
		return originalHit(self, enemy, stats, now)
	end
	game.burnFires = function(self, now)
		burning = true
		originalBurn(self, now)
		burning = false
	end
	game.damageEnemy = function(self, enemy, amount, fragile)
		if burning and not enemy.dead then
			hits.MachineGun = (hits.MachineGun or 0) + amount
		end
		return originalDamage(self, enemy, amount, fragile)
	end
	-- Comme startWave, mais avec la vague faite à la main.
	game:clearEnemies()
	local start = game.clock
	local at = start
	for _, item in list do
		table.insert(game.spawnQueue, { enemy = item.enemy, health = item.health, reward = 0, at = at })
		at += item.gap
	end
	game.state = "Running"
	local steps = 0
	while game.state == "Running" and steps < 400000 do
		game:step(DT)
		steps += 1
	end
	return hits, game.clock - start
end

-- Les mêmes dégâts dans le moteur : dégâts utiles de chaque tour (feu compris ; PV énormes : jamais plafonnés),
-- jusqu'à la première fuite.
local function engineHits(team, list)
	local sorted = table.clone(team)
	table.sort(sorted, function(a, b)
		return a.spot < b.spot
	end)
	local towers = {}
	for _, member in sorted do
		table.insert(towers, Engine.compileTower(member.spot, member.type, 1, 0, member.runes))
	end
	local result = Engine.runWave(Engine.customComposition(list), towers, nil, DT)
	local hits = {}
	for i, tower in towers do
		hits[tower.type] = (hits[tower.type] or 0) + result.useful[i]
	end
	return hits, result.seconds
end

local hitTotal, hitSame = 0, 0
for _, test in HIT_TESTS do
	local list = {}
	for _ = 1, test.count do
		table.insert(list, { enemy = test.enemy, health = 1e12, gap = test.gap })
	end
	local gameHits, gameTime = realHits(test.members, list)
	local engineHits_, engineTime = engineHits(test.members, list)
	hitTotal += 1
	local parts, identical = {}, math.abs(gameTime - engineTime) <= 1e-9
	for _, towerType in { "MachineGun", "Bomb", "Tesla", "Rocket", "Orbital" } do
		local a, b = gameHits[towerType] or 0, engineHits_[towerType] or 0
		if a > 0 or b > 0 then
			table.insert(parts, string.format("%s %.6g / %.6g", towerType, a, b))
		end
		identical = identical and math.abs(a - b) <= 1e-9 * math.max(1, a)
	end
	local line = string.format("%s : dégâts jeu / moteur : %s ; fuite à %.2f s / %.2f s", test.name, table.concat(parts, ", "), gameTime, engineTime)
	print("  " .. line)
	if identical then
		hitSame += 1
	else
		table.insert(problems, line)
	end
end
print(string.format("Dégâts comptés : %d essais sur %d identiques.", hitSame, hitTotal))

if #problems > 0 then
	print("DIFFÉRENCES (le moteur ne suit plus PlotGame.luau : voir Engine.luau) :")
	for _, line in problems do
		print("  " .. line)
	end
	error("le moteur du simulateur ne correspond plus au jeu")
end
print("OK : le moteur du simulateur joue comme PlotGame.luau.")

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
		game:createTower(member.spot, member.type, member.level, 0, member.bonus)
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
		table.insert(towers, Engine.compileTower(member.spot, member.type, member.level, 0, member.bonus))
	end
	local result = Engine.runWave(Engine.composition(wave), towers, nil, DT)
	return result.success, result.seconds, result.coins
end

-- Équipes : toutes les tours (avec deux runes), que des Archers (feu), des Sorciers avec Totem et Mage
-- (rayon, ralentissements), Mages + Catapultes + Baliste + Trébuchet (zones, projectiles lents), et
-- « contrôles » : 2 Totems, 2 Mages, 2 Trébuchets, 2 Balistes et 2 Archers (un seul contrôle à la fois,
-- fragilité, carreau perçant, visée des foules, étourdissement).
local TEAMS = {
	{ name = "toutes les tours", members = {
		{ spot = 1, type = "MachineGun", bonus = "Speed2" }, { spot = 2, type = "Frost" }, { spot = 3, type = "Bomb" },
		{ spot = 4, type = "Tesla" }, { spot = 5, type = "Rocket" }, { spot = 6, type = "Laser", bonus = "Speed2" },
		{ spot = 7, type = "Chain" }, { spot = 8, type = "Orbital", bonus = "Damage3" },
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
		{ spot = 9, type = "MachineGun" }, { spot = 10, type = "Orbital" }, { spot = 11, type = "Rocket", bonus = "Speed2" },
		{ spot = 12, type = "MachineGun" },
	} },
}

local function withLevel(members, level: number)
	local team = {}
	for _, member in members do
		table.insert(team, { spot = member.spot, type = member.type, level = level, bonus = member.bonus })
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
if #problems > 0 then
	print("DIFFÉRENCES (le moteur ne suit plus PlotGame.luau : voir Engine.luau) :")
	for _, line in problems do
		print("  " .. line)
	end
	error("le moteur du simulateur ne correspond plus au jeu")
end
print("OK : le moteur du simulateur joue comme PlotGame.luau.")

--!optimize 2
-- Vérification du moteur du simulateur (run.ps1 -Verifier) : le VRAI PlotGame.luau (serveur) et Engine.luau
-- jouent les mêmes vagues avec les mêmes tours, et doivent donner le même résultat (réussie ou ratée),
-- presque la même durée, et les mêmes carreaux de Baliste tir par tir (heure et cible : sa visée « entre
-- ennemis pareils, celui qui en aligne le plus » change rarement le résultat d'une vague). À relancer après
-- chaque changement de combat dans PlotGame.luau.
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

-- Carreaux de la Baliste lourde, tir par tir : { heure, distance de la cible sur le chemin, PV de la cible }. Sa
-- visée (le plus résistant, et entre ennemis « pareils » celui dont le carreau en transpercera le plus :
-- PlotGame:pickPierceTarget) doit choisir exactement les mêmes cibles dans le jeu et dans le moteur (les
-- résultats des vagues n'y sont pas assez sensibles). changed = tirs du jeu où elle n'a PAS visé le plus
-- résistant (la règle des « pareils » a changé sa cible) : montre que la règle est bien essayée.
local function watchGameBolts(game)
	local bolts = { changed = 0 }
	local originalFire = game.fireProjectile
	game.fireProjectile = function(self, tower, stats, target, muzzle, now, aim, flight)
		if stats.kind == "Pierce" then
			table.insert(bolts, { now, target.distance, target.health })
			if self:pickTarget(tower, stats, false) ~= target then
				bolts.changed += 1
			end
		end
		return originalFire(self, tower, stats, target, muzzle, now, aim, flight)
	end
	return bolts
end

-- Les mêmes carreaux dans le moteur (Engine.onProjectile), jusqu'à `limit` secondes exclues : dans le jeu, une
-- vague ratée s'arrête à la première fuite, avant les tirs de ce pas ; le moteur, lui, continue jusqu'au bout.
local function watchEngineBolts()
	local bolts = {}
	Engine.onProjectile = function(tower, target, now)
		if tower.pierceAim then
			table.insert(bolts, { now, target.dist, target.hp })
		end
	end
	return bolts
end

local function engineBoltsBefore(bolts, limit: number)
	Engine.onProjectile = nil
	local kept = {}
	for _, bolt in bolts do
		if bolt[1] < limit - 1e-9 then
			table.insert(kept, bolt)
		end
	end
	return kept
end

-- Premier carreau différent (heure, cible) entre le jeu et le moteur : son numéro, ou nil s'ils sont tous pareils.
local function firstBoltGap(a, b): number?
	for i = 1, math.max(#a, #b) do
		local bolt, other = a[i], b[i]
		if
			not bolt
			or not other
			or math.abs(bolt[1] - other[1]) > 1e-9
			or math.abs(bolt[2] - other[2]) > 1e-9
			or math.abs(bolt[3] - other[3]) > 1e-9 * math.max(1, math.abs(bolt[3]))
		then
			return i
		end
	end
	return nil
end

local function sameBolts(a, b): boolean
	return firstBoltGap(a, b) == nil
end

-- « carreau n° 3 : jeu à 12.34 s sur l'ennemi à 145.2 studs (1.2e3 PV), moteur à ... » (le premier différent).
local function describeBoltGap(a, b): string
	local i = firstBoltGap(a, b)
	if not i then
		return "mêmes carreaux"
	end
	local function one(bolt)
		return if bolt then string.format("à %.4f s sur l'ennemi à %.4f studs (%.6g PV)", bolt[1], bolt[2], bolt[3]) else "aucun"
	end
	return string.format("carreau n° %d : jeu %s, moteur %s", i, one(a[i]), one(b[i]))
end

-- Les tours de l'équipe dans l'ordre où le vrai jeu les fait tirer : celui de sa table self.towers (clés =
-- emplacements, tours posées dans l'ordre des emplacements). Avec des emplacements qui se suivent (1, 2, 3...),
-- c'est l'ordre des emplacements ; avec un trou (1 à 4, puis 9 et 10), Luau peut parcourir 10 avant 9. Deux tours
-- qui tirent au même pas sur le même ennemi tireraient alors dans l'autre ordre dans le moteur (vu grâce aux
-- carreaux comparés tir par tir : le Trébuchet de l'emplacement 10 tirait avant la Baliste du 9 dans le jeu,
-- après dans le moteur). Le moteur reçoit donc ses tours dans l'ordre du jeu.
local orderCache = {}
local function inGameOrder(team)
	local sorted = table.clone(team)
	table.sort(sorted, function(a, b)
		return a.spot < b.spot
	end)
	local spots = {}
	for _, member in sorted do
		table.insert(spots, member.spot)
	end
	local key = table.concat(spots, ",")
	local order = orderCache[key]
	if not order then
		local game = newGame()
		for _, member in sorted do
			game:createTower(member.spot, member.type, 1, 0, member.runes)
		end
		order = {}
		for spotIndex in game.towers do
			table.insert(order, spotIndex)
		end
		orderCache[key] = order
	end
	local bySpot = {}
	for _, member in team do
		bySpot[member.spot] = member
	end
	local list = {}
	for _, spot in order do
		table.insert(list, bySpot[spot])
	end
	return list
end

-- La vague dans le vrai jeu : réussie ?, durée, pièces tombées, carreaux de Baliste.
local function realWave(team, wave: number)
	local game = newGame()
	local bolts = watchGameBolts(game)
	-- Posées dans l'ordre des emplacements (le moteur reçoit ses tours dans l'ordre où la table des tours du
	-- jeu les parcourt ensuite : inGameOrder).
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
	return game.idle.wave == wave + 1, game.clock - start, coins, bolts
end

-- La même vague dans le moteur du simulateur (tours dans l'ordre de tir du jeu : inGameOrder).
local function engineWave(team, wave: number)
	local towers = {}
	for _, member in inGameOrder(team) do
		table.insert(towers, Engine.compileTower(member.spot, member.type, member.level, 0, member.runes))
	end
	local bolts = watchEngineBolts()
	local result = Engine.runWave(Engine.composition(wave), towers, nil, DT)
	bolts = engineBoltsBefore(bolts, if result.success then math.huge else result.seconds)
	return result.success, result.seconds, result.coins, bolts
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
-- Carreaux de Baliste comparés tir par tir : vagues avec au moins un carreau, identiques, carreaux, et carreaux
-- où la règle des « pareils » a changé la cible.
local boltWaves, boltSame, boltCount, boltChanged = 0, 0, 0, 0
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
			local okGame, timeGame, coinsGame, boltsGame = realWave(withLevel(team.members, level), wave)
			local okEngine, timeEngine, coinsEngine, boltsEngine = engineWave(withLevel(team.members, level), wave)
			if #boltsGame > 0 or #boltsEngine > 0 then
				boltWaves += 1
				boltCount += #boltsGame
				boltChanged += boltsGame.changed
				if sameBolts(boltsGame, boltsEngine) then
					boltSame += 1
				else
					table.insert(
						problems,
						string.format(
							"%s, vague %d, niveau %d : carreaux de Baliste différents (%d tirs dans le jeu, %d dans le moteur ; %s)",
							team.name, wave, level, #boltsGame, #boltsEngine, describeBoltGap(boltsGame, boltsEngine)
						)
					)
				end
			end
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
print(string.format(
	"Baliste, tir par tir : %d vagues sur %d avec les mêmes carreaux (%d carreaux, dont %d où elle n'a pas visé le plus résistant : règle des « pareils »).",
	boltSame, boltWaves, boltCount, boltChanged
))

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
	local bolts = watchGameBolts(game)
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
	return hits, game.clock - start, bolts
end

-- Les mêmes dégâts dans le moteur : dégâts utiles de chaque tour (feu compris ; PV énormes : jamais plafonnés),
-- jusqu'à la première fuite.
local function engineHits(team, list)
	local towers = {}
	for _, member in inGameOrder(team) do
		table.insert(towers, Engine.compileTower(member.spot, member.type, 1, 0, member.runes))
	end
	local bolts = watchEngineBolts()
	local result = Engine.runWave(Engine.customComposition(list), towers, nil, DT)
	bolts = engineBoltsBefore(bolts, if result.success then math.huge else result.seconds)
	local hits = {}
	for i, tower in towers do
		hits[tower.type] = (hits[tower.type] or 0) + result.useful[i]
	end
	return hits, result.seconds, bolts
end

local hitTotal, hitSame = 0, 0
for _, test in HIT_TESTS do
	local list = {}
	for _ = 1, test.count do
		table.insert(list, { enemy = test.enemy, health = 1e12, gap = test.gap })
	end
	local gameHits, gameTime, gameBolts = realHits(test.members, list)
	local engineHits_, engineTime, engineBolts = engineHits(test.members, list)
	hitTotal += 1
	-- Mêmes carreaux de Baliste, tir par tir (ennemis de mêmes PV : la règle des « pareils » joue à chaque tir).
	local parts, identical = {}, math.abs(gameTime - engineTime) <= 1e-9 and sameBolts(gameBolts, engineBolts)
	for _, towerType in { "MachineGun", "Bomb", "Tesla", "Rocket", "Orbital" } do
		local a, b = gameHits[towerType] or 0, engineHits_[towerType] or 0
		if a > 0 or b > 0 then
			table.insert(parts, string.format("%s %.6g / %.6g", towerType, a, b))
		end
		identical = identical and math.abs(a - b) <= 1e-9 * math.max(1, a)
	end
	local line = string.format(
		"%s : dégâts jeu / moteur : %s ; fuite à %.2f s / %.2f s ; carreaux de Baliste %d / %d (%s, %d sans viser le plus résistant)",
		test.name, table.concat(parts, ", "), gameTime, engineTime, #gameBolts, #engineBolts,
		if sameBolts(gameBolts, engineBolts) then "mêmes cibles" else "CIBLES DIFFÉRENTES", gameBolts.changed
	)
	print("  " .. line)
	if identical then
		hitSame += 1
	else
		table.insert(problems, line)
	end
end
print(string.format("Dégâts comptés : %d essais sur %d identiques.", hitSame, hitTotal))

-- Carreaux de la Baliste dans des vagues faites à la main, comparés tir par tir (avec la durée de la vague) :
-- des cas que les vagues du dessus n'essaient presque jamais. Vérifié en changeant le moteur seul : sans ces
-- deux essais, un moteur qui visait ou comptait un ennemi condamné, qui comparait 13 « pareils » au lieu de 12,
-- ou dont le seuil des « pareils » valait 0,9 au lieu de 0,85, passait inaperçu.
--   « Balistes et condamnés » : 60 fantassins de 50 PV très serrés et 3 Balistes (x2 vitesse) qui tirent souvent
--   au même pas. Un carreau les tue : sa cible est condamnée dès le tir, et les autres Balistes doivent l'écarter,
--   comme cible ET dans le compte de leur ligne. Plus de BALLISTA_MAX_CANDIDATES « pareils » à portée à la fois.
--   « seuil des pareils » : 50 fantassins de 120 PV, 2 Balistes, une Catapulte et un Archer : un rocher laisse
--   103 PV (86 % de 120), les flèches et le feu d'autres PV : des ennemis juste au-dessus et juste en dessous du
--   seuil (IdleTowers.BALLISTA_TIE_RATIO).
--   « lignes pleines » (carreau qui transperce 3 ennemis au plus, IdleTowers.BALLISTA_PIERCE_MAX) : 60 fantassins
--   par groupes de 3 au même endroit (écart 0, 0, puis 0,3 s), avec des PV différents, 3 Balistes, un Mage et une
--   Catapulte. Les lignes ont souvent plus de 3 ennemis : le carreau doit toucher les mêmes (les premiers
--   rencontrés ; à égalité, le premier de la liste). Vérifié en changeant le moteur seul : sans le plafond, sans le
--   tri le long du trait, avec le plus loin d'abord, les égalités à l'envers, la visée qui compte plus de 3 par
--   ligne, ou la cible en plus des 3, la vérification voit la différence (sans cet essai : pas les égalités).
--   « groupes serrés » (ajouté à la relecture du plafond) : 60 fantassins de 50 PV par groupes de 6 au même
--   endroit (écart 0, puis 0,4 s) et 3 Balistes (x2 vitesse). Un carreau tue tout ce qu'il touche : la cible d'un
--   carreau meurt souvent pendant son vol (tuée par le carreau d'une autre Baliste) avec 3 ennemis ou plus sur sa
--   ligne, et des ennemis condamnés (visés par un autre carreau encore en vol) sont souvent parmi les premiers
--   rencontrés. Ailleurs dans la vérification, ces deux cas n'arrivent jamais sur une ligne pleine (13 carreaux sur
--   une ligne pleine en tout, sur ~1 500 carreaux du jeu). Vérifié en changeant le moteur seul : sans cet essai,
--   une cible morte en vol qui garderait sa place ou des condamnés sautés à l'impact passaient inaperçus.
-- Les dégâts ne sont pas comparés ici : avec des PV normaux, le jeu (realHits) compte chaque coup en entier et le
-- moteur seulement les dégâts utiles.
local BOLT_TESTS = {
	{ name = "Balistes et condamnés", enemy = "Normal", count = 60, gap = 0.1, health = 50, members = {
		{ spot = 1, type = "Rocket", runes = "Speed2" }, { spot = 5, type = "Rocket", runes = "Speed2" },
		{ spot = 9, type = "Rocket", runes = "Speed2" },
	} },
	{ name = "seuil des pareils", enemy = "Normal", count = 50, gap = 0.1, health = 120, members = {
		{ spot = 1, type = "Rocket" }, { spot = 2, type = "Rocket", runes = "Speed2" }, { spot = 3, type = "Bomb" },
		{ spot = 4, type = "MachineGun" },
	} },
	-- gaps / healths : écarts et PV qui se répètent (ennemi n° i : élément n° i, puis on recommence la liste).
	{ name = "lignes pleines", enemy = "Normal", count = 60, gaps = { 0, 0, 0.3 }, healths = { 90, 140, 60, 110, 75, 130 }, members = {
		{ spot = 1, type = "Rocket", runes = "Speed2" }, { spot = 5, type = "Rocket", runes = "Speed2" },
		{ spot = 9, type = "Rocket", runes = "Speed2" }, { spot = 2, type = "Tesla" }, { spot = 3, type = "Bomb" },
	} },
	{ name = "groupes serrés", enemy = "Normal", count = 60, gaps = { 0, 0, 0, 0, 0, 0.4 }, health = 50, members = {
		{ spot = 1, type = "Rocket", runes = "Speed2" }, { spot = 5, type = "Rocket", runes = "Speed2" },
		{ spot = 9, type = "Rocket", runes = "Speed2" },
	} },
}
local boltTestSame = 0
for _, test in BOLT_TESTS do
	local list = {}
	for i = 1, test.count do
		local health = if test.healths then test.healths[(i - 1) % #test.healths + 1] else test.health
		local gap = if test.gaps then test.gaps[(i - 1) % #test.gaps + 1] else test.gap
		table.insert(list, { enemy = test.enemy, health = health, gap = gap })
	end
	local _, gameTime, gameBolts = realHits(test.members, list)
	local _, engineTime, engineBolts = engineHits(test.members, list)
	local identical = math.abs(gameTime - engineTime) <= 1e-9 and sameBolts(gameBolts, engineBolts)
	local line = string.format(
		"%s : carreaux de Baliste %d / %d (%s, %d sans viser le plus résistant) ; fin à %.2f s / %.2f s",
		test.name, #gameBolts, #engineBolts, describeBoltGap(gameBolts, engineBolts), gameBolts.changed, gameTime, engineTime
	)
	print("  " .. line)
	if identical then
		boltTestSame += 1
	else
		table.insert(problems, line)
	end
end
print(string.format("Carreaux de Baliste, vagues faites à la main : %d essais sur %d identiques.", boltTestSame, #BOLT_TESTS))

if #problems > 0 then
	print("DIFFÉRENCES (le moteur ne suit plus PlotGame.luau : voir Engine.luau) :")
	for _, line in problems do
		print("  " .. line)
	end
	error("le moteur du simulateur ne correspond plus au jeu")
end
print("OK : le moteur du simulateur joue comme PlotGame.luau.")

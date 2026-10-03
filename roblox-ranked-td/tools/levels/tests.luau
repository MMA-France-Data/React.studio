-- Vérifications des règles des NIVEAUX sans ouvrir Studio (run.ps1 -Tests) : les chiffres de Shared/Levels.luau et
-- le VRAI moteur d'un niveau (LevelGame.luau, qui hérite du vrai Combat.luau), avec les imitations de Roblox de
-- env.luau. Sortie 1 si un test rate.
local Env = require("./env")
local Levels = require("./gen/shared/Levels")
local IdleConfig = require("./gen/shared/IdleConfig")
local IdleTowers = require("./gen/shared/IdleTowers")
local LevelGame = require("./gen/server/Hub/LevelGame")
local Shim = require("./shim")
local Bot = require("./Bot")
local Vector3 = Shim.Vector3

local passed, failed = 0, 0
local function check(ok: any, message: string)
	if ok then
		passed += 1
	else
		failed += 1
		print("RATÉ : " .. message)
	end
end
local function near(a: number, b: number, tolerance: number?): boolean
	return math.abs(a - b) <= (tolerance or 1e-6)
end

-- Un niveau prêt à jouer, comme le lance LevelsService. towers = types débloqués, training = niveau d'entraînement
-- de toutes ces tours. Renvoie le niveau, sa zone (faux dossier : ses attributs) et le journal des fins.
local function newGame(level: number, towers: { string }, training: number?)
	local definition = Levels.definition(level)
	local unlocked, trained = {}, {}
	for _, towerType in towers do
		unlocked[towerType] = true
		trained[towerType] = training or 0
	end
	local arena = { index = Levels.arenaIndex(1), folder = Env.fakeInstance("Arena"), cframe = Levels.arenaCFrame(1), map = definition.map }
	local ends = {}
	local game = LevelGame.new(arena, { UserId = 1, Parent = {} }, {
		level = level,
		unlocked = unlocked,
		training = trained,
		startingTower = level == 1,
		onEnd = function(_, won)
			table.insert(ends, won)
		end,
	})
	return game, arena, ends
end

local function run(game, seconds: number)
	for _ = 1, math.floor(seconds * 30) do
		if game.state ~= "Running" then
			break
		end
		game:simulate(1 / 30)
	end
end

local function towerCount(game): number
	local count = 0
	for _ in game.towers do
		count += 1
	end
	return count
end

----------------------------------------------------------------------
-- 1) Les niveaux : 100 niveaux en 10 territoires de 10, mini-boss au milieu d'un territoire, boss à la fin, 2 à
--    3 minutes et demie, un FLOT CONTINU qui monte
----------------------------------------------------------------------
check(
	Levels.COUNT == 100 and #Levels.DEFINITIONS == 100 and #Levels.TERRITORIES == 10 and Levels.TERRITORY_SIZE == 10,
	`100 niveaux dans le jeu, en 10 territoires de 10 ({Levels.COUNT} niveaux, {#Levels.DEFINITIONS} fiches, {#Levels.TERRITORIES} territoires)`
)
check(
	Levels.territoryOf(1) == 1 and Levels.territoryOf(10) == 1 and Levels.territoryOf(11) == 2 and Levels.territoryOf(20) == 2
		and Levels.territoryOf(21) == 3 and Levels.territoryOf(30) == 3 and Levels.territoryOf(31) == 4 and Levels.territoryOf(40) == 4
		and Levels.definition(10).map == "Valley" and Levels.definition(11).map == "Pass" and Levels.definition(21).map == "Forest"
		and Levels.definition(31).map == "Glacier" and Levels.definition(11).palier == 1 and Levels.definition(21).palier == 2
		and Levels.definition(40).palier == 3 and Levels.territoryOf(41) == 5 and Levels.territoryOf(50) == 5 and Levels.territoryOf(51) == 6
		and Levels.territoryOf(60) == 6 and Levels.definition(41).map == "Desert" and Levels.definition(51).map == "Necropolis"
		and Levels.definition(41).palier == 4 and Levels.definition(60).palier == 5 and Levels.territoryOf(61) == 7
		and Levels.territoryOf(100) == 10 and Levels.definition(61).map == "Storm" and Levels.definition(71).map == "Obsidian"
		and Levels.definition(81).map == "Goblin" and Levels.definition(91).map == "Dragon" and Levels.definition(100).palier == 9,
	"territoires : la vallée, le col, la forêt, le glacier, le désert, la nécropole, la citadelle, le volcan, les marais, le repaire du dragon (10 niveaux chacun, chacun sa carte et la famille de monstres suivante)"
)
for level = 1, Levels.COUNT do
	local definition = Levels.definition(level)
	local source = Levels.DEFINITIONS[level]
	local queue = Levels.buildQueue(level)
	local types, lastAt, ordered = {}, -1, true
	local longestGap = 0
	for index, item in queue do
		types[item.enemy] = (types[item.enemy] or 0) + 1
		ordered = ordered and item.at >= lastAt and item.health > 0 and item.reward > 0
		if index > 1 then
			longestGap = math.max(longestGap, item.at - lastAt)
		end
		lastAt = item.at
	end
	local duration = Levels.duration(level)
	check(#queue >= 120 and ordered, `niveau {level} : {#queue} monstres, dans l'ordre de leur heure, PV et or positifs`)
	check(duration >= 100 and duration <= 200, `niveau {level} : dure {math.floor(duration)} s (entre 100 et 200)`)
	check(definition.gold >= Levels.placeCost("MachineGun"), `niveau {level} : l'or de départ ({definition.gold}) paie au moins un Archer`)
	check(
		definition.miniBoss == (level % 10 == 5) and definition.boss == (level % 10 == 0) and definition.territory == Levels.territoryOf(level)
			and definition.palier == definition.territory - 1 and Levels.MAPS[definition.map] ~= nil,
		`niveau {level} : territoire {definition.territory}, mini-boss {tostring(definition.miniBoss)}, boss {tostring(definition.boss)}`
	)
	if level == 5 then
		check(types.Giant == 1 and not types.Boss, "niveau 5 : un mini-boss (chevalier colossal) dans le flot, pas de boss")
	elseif level == 10 then
		check(types.Boss == 1 and queue[#queue].enemy == "Boss", "niveau 10 : le boss ferme le flot")
	elseif level == 15 then
		check(types.Giant == 2 and not types.Boss, "niveau 15 : deux mini-boss ensemble (chevaliers colossaux), pas de boss")
	elseif level == 20 then
		check(types.Boss == 1 and types.Giant == 2 and queue[#queue].enemy == "Boss", "niveau 20 : deux colosses dans le flot, puis le boss le ferme")
	elseif level == 25 then
		check(types.Giant == 3 and not types.Boss, "niveau 25 : trois colosses ensemble, pas de boss")
	elseif level == 30 then
		check(types.Boss == 1 and types.Giant == 3 and queue[#queue].enemy == "Boss", "niveau 30 : trois colosses dans le flot, puis le boss le ferme")
	elseif level == 35 then
		check(types.Giant == 4 and not types.Boss, "niveau 35 : deux paires de colosses, pas de boss")
	elseif level == 40 then
		check(types.Boss == 1 and types.Giant == 4 and queue[#queue].enemy == "Boss", "niveau 40 : quatre colosses dans le flot, puis le boss le ferme")
	elseif level == 45 then
		check(types.Giant == 4 and not types.Boss, "niveau 45 : quatre colosses à la file, pas de boss")
	elseif level == 50 then
		check(types.Boss == 1 and types.Giant == 4 and queue[#queue].enemy == "Boss", "niveau 50 : quatre colosses dans le flot, puis le boss le ferme")
	elseif level == 55 then
		check(types.Giant == 5 and not types.Boss, "niveau 55 : un trio puis une paire de colosses, pas de boss")
	elseif level == 60 then
		check(types.Boss == 1 and types.Giant == 5 and queue[#queue].enemy == "Boss", "niveau 60 : cinq colosses dans le flot, puis le boss le ferme")
	elseif level % 10 == 5 and level > 60 then
		check(types.Giant == 5 and not types.Boss, `niveau {level} : cinq colosses (mini-boss), pas de boss`)
	elseif level % 10 == 0 and level > 60 then
		check(types.Boss == 1 and types.Giant == 5 and queue[#queue].enemy == "Boss", `niveau {level} : cinq colosses dans le flot, puis le boss le ferme`)
	end
	-- Demande du propriétaire : « en continu », jamais par vagues. Aucune pause : l'écart le plus long entre deux
	-- monstres est l'écart du tout début.
	check(queue[1].at == 0 and longestGap <= source.gap[1] + 1e-6, `niveau {level} : flot continu, jamais plus de {source.gap[1]} s entre deux monstres ({string.format("%.2f", longestGap)} s au plus)`)
	-- « De plus en plus dur au fur et à mesure » : les monstres sortent de plus en plus serrés...
	local quarter = source.seconds / 4
	local firstQuarter, lastQuarter = 0, 0
	for _, item in queue do
		if item.at < quarter then
			firstQuarter += 1
		elseif item.at >= source.seconds - quarter then
			lastQuarter += 1
		end
	end
	check(lastQuarter >= 2 * firstQuarter, `niveau {level} : {firstQuarter} monstres dans le premier quart du niveau, {lastQuarter} dans le dernier (au moins 2 fois plus)`)
	-- ... et de plus en plus résistants : chaque fantassin a au moins autant de PV que le précédent.
	local firstNormal, lastNormal, rising = nil, nil, true
	for _, item in queue do
		if item.enemy == "Normal" then
			firstNormal = firstNormal or item.health
			rising = rising and (lastNormal == nil or item.health >= lastNormal)
			lastNormal = item.health
		end
	end
	check(firstNormal ~= nil and rising and lastNormal >= 10 * firstNormal, `niveau {level} : les fantassins passent de {firstNormal} à {lastNormal} PV, sans jamais redescendre (au moins x10)`)
	-- Chaque type n'entre qu'à partir de son moment du niveau.
	local early = true
	for _, item in queue do
		local from = (source.from or {})[item.enemy]
		if item.enemy ~= "Normal" and item.enemy ~= "Giant" and item.enemy ~= "Boss" then
			early = early and from ~= nil and item.at >= from * source.seconds - 1e-6
		end
	end
	check(early, `niveau {level} : aucun cavalier, écuyer ou chevalier lourd avant son moment`)
	-- Rien n'est tiré au hasard : deux fois le même flot.
	local again, same = Levels.buildQueue(level), true
	for index, item in queue do
		local other = again[index]
		same = same and other ~= nil and other.enemy == item.enemy and other.at == item.at and other.health == item.health
	end
	check(same and #again == #queue, `niveau {level} : toujours exactement le même flot`)
end
check(Levels.enemyHealth(10, "Boss") > Levels.enemyHealth(5, "Giant"), "le boss du niveau 10 est plus résistant que le mini-boss du niveau 5")
check(
	Levels.enemyHealth(20, "Boss") > Levels.enemyHealth(10, "Boss") and Levels.enemyHealth(11, "Normal") > Levels.enemyHealth(10, "Normal"),
	`2e territoire : des monstres plus résistants (fantassin {Levels.enemyHealth(10, "Normal")} PV au niveau 10, {Levels.enemyHealth(11, "Normal")} au niveau 11 ; boss {Levels.enemyHealth(10, "Boss")} puis {Levels.enemyHealth(20, "Boss")} PV)`
)
-- Chaque territoire est plus dur que le précédent : un de ses niveaux a en moyenne plus de PV en tout (tous ses
-- monstres, colosses compris), et son boss en a plus. (Les PV du seul fantassin ne suffisent pas : aux niveaux 51
-- à 60, cinq colosses par niveau demandent des fantassins un peu moins résistants qu'aux niveaux 41 à 50.)
do
	local function bossHealth(level: number): number
		for _, item in Levels.buildQueue(level) do
			if item.enemy == "Boss" then
				return item.health
			end
		end
		return 0
	end
	local averages, bosses, harder = {}, {}, true
	for territory in Levels.TERRITORIES do
		local total = 0
		for level = (territory - 1) * Levels.TERRITORY_SIZE + 1, territory * Levels.TERRITORY_SIZE do
			for _, item in Levels.buildQueue(level) do
				total += item.health
			end
		end
		averages[territory] = total / Levels.TERRITORY_SIZE
		bosses[territory] = bossHealth(territory * Levels.TERRITORY_SIZE)
		if territory > 1 then
			harder = harder and averages[territory] > averages[territory - 1] and bosses[territory] > bosses[territory - 1]
		end
	end
	local shown, shownBosses = {}, {}
	for territory, average in averages do
		table.insert(shown, `{math.floor(average)}`)
		table.insert(shownBosses, `{math.floor(bosses[territory])}`)
	end
	check(harder, `chaque territoire est plus dur que le précédent (PV de tous les monstres d'un niveau, en moyenne : {table.concat(shown, ", ")} ; PV des boss : {table.concat(shownBosses, ", ")})`)
end
check(not pcall(Levels.definition, Levels.COUNT + 1) and not pcall(Levels.buildQueue, 0), `un niveau inconnu (0, {Levels.COUNT + 1}) est refusé`)

----------------------------------------------------------------------
-- 2) La carte : chemin, pose libre
----------------------------------------------------------------------
local geometry = Levels.geometry("Valley")
local map = geometry.map
check(geometry.PATH_LENGTH == 204, `chemin de la vallée : {geometry.PATH_LENGTH} studs`)
check((geometry.pointAt(0) - map.path[1]).Magnitude < 1e-6 and (geometry.pointAt(1e9) - map.path[#map.path]).Magnitude < 1e-6, "pointAt : départ et bout du chemin")
check(near(geometry.distanceToPath(geometry.pointAt(77)), 0) and near(geometry.distanceToPath(Vector3.new(-23, 0, 0)), 11), "distanceToPath : 0 sur le chemin, 11 au premier emplacement conseillé")
check(Levels.geometry("Valley") == geometry and not pcall(Levels.geometry, "Nulle part"), "geometry : la même table à chaque appel, carte inconnue refusée")
local function refused(point, towers, expected: string): boolean
	local ok, reason = Levels.checkPlacement("Valley", point, towers or {})
	return ok == false and reason == expected
end
check(refused(geometry.pointAt(50), nil, "Trop près du chemin"), "pose refusée sur le chemin")
check(refused(Vector3.new(-23, 0, 4.5), nil, "Trop près du chemin") == false and Levels.checkPlacement("Valley", Vector3.new(-23, 0, 4.5), {}), "pose acceptée à 9,5 studs du chemin")
check(refused(Vector3.new(200, 0, 0), nil, "Hors du terrain") and refused(Vector3.new(0, 0, 25), nil, "Hors du terrain"), "pose refusée hors du terrain (et à moins de 3 studs du bord)")
check(refused(Vector3.new(52, 0, 3), nil, "Trop près du château") and Levels.checkPlacement("Valley", Vector3.new(52, 0, 6), {}), "pose refusée contre le château, acceptée à 8 studs de son centre")
check(refused(Vector3.new(-23, 0, 2), { Vector3.new(-23, 0, 0) }, "Trop près d'une autre tour"), "pose refusée à 2 studs d'une autre tour")
check(Levels.checkPlacement("Valley", Vector3.new(-23, 0, 5), { Vector3.new(-23, 0, 0) }), "pose acceptée à 5 studs d'une autre tour")
check(refused(Vector3.new(0 / 0, 0, 0), nil, "Position invalide"), "pose refusée pour une position abîmée (NaN)")
local placedSpots, spotsOk = {}, true
for _, spot in map.spots do
	spotsOk = spotsOk and Levels.checkPlacement("Valley", spot, placedSpots) == true
	table.insert(placedSpots, spot)
end
check(spotsOk and #map.spots >= 8, `les {#map.spots} emplacements conseillés sont tous posables, même tous occupés à la fois`)
-- Chaque territoire a sa carte : mêmes règles pour toutes.
for territory, mapName in Levels.TERRITORIES do
	local territoryGeometry = Levels.geometry(mapName)
	local territoryMap = territoryGeometry.map
	local placed, allFit = {}, true
	for _, spot in territoryMap.spots do
		allFit = allFit and Levels.checkPlacement(mapName, spot, placed) == true
		table.insert(placed, spot)
	end
	local straight = true
	for index = 2, #territoryMap.path do
		local delta = territoryMap.path[index] - territoryMap.path[index - 1]
		straight = straight and (delta.X == 0 or delta.Z == 0) and delta.Magnitude >= Levels.PATH_WIDTH
	end
	local last = territoryMap.path[#territoryMap.path]
	check(
		allFit and #territoryMap.spots >= 12 and straight and territoryMap.path[1].X == -territoryMap.width / 2
			and (territoryMap.base - last).Magnitude <= 5 and math.abs(territoryMap.base.X) < territoryMap.width / 2 and math.abs(territoryMap.base.Z) < territoryMap.depth / 2
			and territoryMap.width == 112 and territoryMap.depth == 52,
		`carte du territoire {territory} (« {territoryMap.displayName} ») : chemin de {territoryGeometry.PATH_LENGTH} studs en tronçons droits, entrée à gauche, château au bout, {#territoryMap.spots} emplacements conseillés tous posables`
	)
end
check(Levels.geometry("Pass").PATH_LENGTH == 282 and Levels.geometry("Pass").PATH_LENGTH > geometry.PATH_LENGTH, "le chemin du col est plus long que celui de la vallée (282 studs)")
check(Levels.geometry("Forest").PATH_LENGTH == 308 and Levels.geometry("Glacier").PATH_LENGTH == 266, "chemins de la forêt (308 studs) et du glacier (266 studs)")
do
	local longest = 0
	for _, mapName in Levels.TERRITORIES do
		longest = math.max(longest, Levels.geometry(mapName).PATH_LENGTH)
	end
	check(
		Levels.geometry("Storm").PATH_LENGTH == 252 and Levels.geometry("Obsidian").PATH_LENGTH == 270 and Levels.geometry("Goblin").PATH_LENGTH == 272
			and Levels.geometry("Dragon").PATH_LENGTH == 330 and longest == 330 and Levels.MAPS.Goblin.path[1].Z == 0,
		"chemins de la citadelle (252 studs), du volcan (270), des marais (272, entrée au milieu du bord) et du repaire du dragon (330 : le plus long du jeu)"
	)
end
check(
	Levels.geometry("Desert").PATH_LENGTH == 252 and Levels.geometry("Necropolis").PATH_LENGTH == 252
		and Levels.MAPS.Desert.base.X < 0 and math.abs(Levels.MAPS.Necropolis.base.X) < 10,
	"chemins du désert et de la nécropole (252 studs) ; château du désert à gauche, près de l'entrée ; château de la nécropole au centre"
)
-- Sur chaque carte, le premier emplacement conseillé est entre deux couloirs : une tour y est à portée des deux.
do
	local seen, allSee = {}, true
	for _, mapName in Levels.TERRITORIES do
		local territoryGeometry = Levels.geometry(mapName)
		local spot = territoryGeometry.map.spots[1]
		local reached = 0
		for distance = 0, territoryGeometry.PATH_LENGTH, 2 do
			if (territoryGeometry.pointAt(distance) - spot).Magnitude <= IdleTowers.Defs.MachineGun.range then
				reached += 2
			end
		end
		allSee = allSee and reached >= 70
		table.insert(seen, `{reached} ({mapName})`)
	end
	check(allSee, `un Archer au premier emplacement conseillé voit au moins 70 studs de chemin sur chaque carte : {table.concat(seen, ", ")}`)
end

----------------------------------------------------------------------
-- 3) Récompenses, prix, limites, or des monstres
----------------------------------------------------------------------
check(Levels.firstReward(1) == 80 and Levels.firstReward(4) == 140 and Levels.firstReward(5) == 300 and Levels.firstReward(10) == 600, "première victoire : 80 au niveau 1, 140 au 4, 300 au mini-boss, 600 au boss")
check(Levels.firstReward(11) == 280 and Levels.firstReward(15) == 600 and Levels.firstReward(20) == 1200 and Levels.reward(20, true, false) == 480, "2e territoire : 280 au niveau 11, 600 au mini-boss, 1 200 au boss (480 en le rejouant)")
check(
	Levels.firstReward(21) == 480 and Levels.firstReward(25) == 900 and Levels.firstReward(30) == 1800 and Levels.firstReward(31) == 680
		and Levels.firstReward(35) == 1200 and Levels.firstReward(40) == 2400 and Levels.reward(40, true, false) == 960,
	"3e et 4e territoires : 480 au niveau 21, 900 et 1 800 pour son mini-boss et son boss ; 680 au niveau 31, 1 200 et 2 400 (960 en le rejouant)"
)
check(
	Levels.firstReward(41) == 880 and Levels.firstReward(45) == 1500 and Levels.firstReward(50) == 3000 and Levels.firstReward(51) == 1080
		and Levels.firstReward(55) == 1800 and Levels.firstReward(60) == 3600 and Levels.reward(60, true, false) == 1440,
	"5e et 6e territoires : 880 au niveau 41, 1 500 et 3 000 pour son mini-boss et son boss ; 1 080 au niveau 51, 1 800 et 3 600 (1 440 en le rejouant)"
)
check(
	Levels.firstReward(61) == 1280 and Levels.firstReward(65) == 2100 and Levels.firstReward(70) == 4200 and Levels.firstReward(91) == 1880
		and Levels.firstReward(95) == 3000 and Levels.firstReward(100) == 6000 and Levels.reward(100, true, false) == 2400,
	"territoires 7 à 10 : 1 280 au niveau 61, 2 100 et 4 200 pour son mini-boss et son boss... 6 000 pour le dragon du niveau 100 (2 400 en le rejouant)"
)
check(Levels.reward(3, true, true) == 120 and Levels.reward(3, true, false) == 48, "niveau 3 : 120 la première fois, 48 en le rejouant (40 %)")
check(Levels.reward(3, false, false, 0.5) == 12 and Levels.reward(3, false, false, 0) == 0 and Levels.reward(3, false, true, 1) == 24, "défaite : une part de la récompense « rejouer » selon l'avancée (0 si rien n'est éliminé)")
check(Levels.reward(10, true, false) > Levels.reward(4, true, false) and Levels.reward(4, true, false) > Levels.reward(1, true, false), "rejouer un niveau plus haut rapporte plus")
check(Levels.placeCost("MachineGun") == 20 and Levels.upgradeCost("MachineGun", 1) == 15 and Levels.upgradeCost("MachineGun", 2) == 22, "Archer : 20 or, puis 15 et 22 pour ses deux premières améliorations")
check(Levels.upgradeCost("MachineGun", Levels.MAX_TOWER_LEVEL) == nil and Levels.upgradeCost("MachineGun", Levels.MAX_TOWER_LEVEL - 1) ~= nil, "pas d'amélioration au-delà du niveau maximum")
check(Levels.maxCopies("Frost") == 3 and Levels.maxCopies("MachineGun") == 5 and Levels.maxCopies("Orbital") == 2, "limites : 3 Totems, 5 Archers, 2 Trébuchets par niveau")
-- Demande du propriétaire : « commencer avec au moins deux tours, juste l'Archer c'est ennuyant ».
check(#Levels.STARTING_TOWERS == 2 and Levels.STARTING_TOWERS[1] == "MachineGun" and Levels.STARTING_TOWERS[2] == "Bomb", "deux tours possédées dès le départ : l'Archer et la Catapulte")
local shopOk = true
for _, towerType in IdleTowers.ORDER do
	local starting = table.find(Levels.STARTING_TOWERS, towerType) ~= nil
	shopOk = shopOk and Levels.TOWER_COST[towerType] ~= nil and (if starting then Levels.SHOP[towerType] == nil else Levels.SHOP[towerType] > 0)
end
check(shopOk, "boutique : un prix fixe pour chaque tour sauf les deux de départ (déjà possédées), et un prix en or pour toutes")
check(Levels.SHOP.Frost == 150 and Levels.SHOP.Tesla == 400, "boutique : Totem 150 pièces (payable après 2 niveaux), Mage 400")
-- Retour du propriétaire (02/10/2026) : « les prix des prochaines tours doivent être plus hauts, pas forcément les
-- basiques mais les légendaires surtout, car au niveau 10 tu les as en gros ? ». Les 10 premiers niveaux réussis
-- une fois paient le Totem, le Mage et la Baliste, pas plus ; les 20, le Sorcier en plus ; les 30, l'Oracle en
-- plus ; les 40 ne paient pas le Trébuchet ; les 45, si.
local firstTerritory, firstTwenty, firstThirty, allFirst, beforeLevel18, previousPrice, rising = 0, 0, 0, 0, 0, 0, true
local firstForty, firstFortyFive = 0, 0
for level = 1, Levels.COUNT do
	allFirst += Levels.firstReward(level)
	if level <= Levels.TERRITORY_SIZE then
		firstTerritory += Levels.firstReward(level)
	end
	if level <= 20 then
		firstTwenty += Levels.firstReward(level)
	end
	if level <= 30 then
		firstThirty += Levels.firstReward(level)
	end
	if level <= 40 then
		firstForty += Levels.firstReward(level)
	end
	if level <= 45 then
		firstFortyFive += Levels.firstReward(level)
	end
	if level < 18 then
		beforeLevel18 += Levels.firstReward(level)
	end
end
for _, towerType in IdleTowers.ORDER do
	local price = Levels.SHOP[towerType]
	if price then
		rising = rising and price > previousPrice
		previousPrice = price
	end
end
check(rising, "boutique : chaque tour coûte plus cher que la précédente")
check(
	firstTerritory == 2180 and firstTerritory >= Levels.SHOP.Frost + Levels.SHOP.Tesla + Levels.SHOP.Rocket
		and firstTerritory < Levels.SHOP.Frost + Levels.SHOP.Tesla + Levels.SHOP.Laser,
	`les 10 premiers niveaux réussis une fois ({firstTerritory} pièces) paient le Totem, le Mage et la Baliste, mais pas le Sorcier`
)
local fourTowers = Levels.SHOP.Frost + Levels.SHOP.Tesla + Levels.SHOP.Rocket + Levels.SHOP.Laser
check(
	firstTwenty == 6860 and firstTwenty >= fourTowers and firstTwenty < fourTowers + Levels.SHOP.Chain,
	`les 20 premiers niveaux réussis une fois ({firstTwenty} pièces) paient aussi le Sorcier ({fourTowers} pour les quatre), mais aucune légendaire`
)
local withOracle = fourTowers + Levels.SHOP.Chain
check(
	firstThirty == 14040 and firstThirty >= withOracle and firstThirty - Levels.firstReward(30) < withOracle,
	`les 30 premiers niveaux réussis une fois ({firstThirty} pièces) paient l'Oracle en plus ({withOracle} pour les cinq), pas avant le boss du niveau 30`
)
local allTowers = withOracle + Levels.SHOP.Orbital
check(
	firstForty == 23720 and firstForty < allTowers,
	`les 40 premiers niveaux réussis une fois ({firstForty} pièces) ne paient pas le Trébuchet ({allTowers} pour les six tours)`
)
check(
	firstFortyFive >= allTowers and firstFortyFive - Levels.firstReward(45) < allTowers and allFirst == 134300,
	`les 45 premiers niveaux réussis une fois ({firstFortyFive} pièces) paient le Trébuchet, pas avant le mini-boss du niveau 45 ; les {Levels.COUNT} en donnent {allFirst}`
)
-- Ce que le réglage des niveaux attend (Bot.EXPECTED) : la Baliste en arrivant au niveau 11, le Sorcier au 18,
-- l'Oracle au 31, le Trébuchet au 46.
check(beforeLevel18 >= fourTowers, `le Sorcier est payable avant le niveau 18 ({beforeLevel18} pièces gagnées du niveau 1 au 17, il en faut {fourTowers})`)
local replay10 = Levels.reward(10, true, false)
local replayLast = Levels.reward(Levels.COUNT, true, false)
check(
	IdleTowers.Defs.Chain.rarity == "Legendary" and IdleTowers.Defs.Orbital.rarity == "Legendary" and Levels.SHOP.Chain >= 30 * replay10
		and Levels.SHOP.Orbital >= 60 * replay10,
	`tours légendaires : l'Oracle vaut {math.ceil(Levels.SHOP.Chain / replay10)} parties rejouées au niveau 10 ou {math.ceil(Levels.SHOP.Chain / replayLast)} au niveau {Levels.COUNT}, le Trébuchet {math.ceil(Levels.SHOP.Orbital / replay10)} ou {math.ceil(Levels.SHOP.Orbital / replayLast)}`
)
check(Levels.ENEMY.Normal.gold == 6 and Levels.ENEMY.Swarm.gold == 2 and Levels.ENEMY.Tank.gold == 18 and Levels.ENEMY.Boss.leak == 10, "or des monstres : 6 le fantassin, 2 l'écuyer, 18 le chevalier lourd")
check(Levels.RUSH_GOLD_PER_SECOND == nil and Levels.GROUP_PAUSE == nil, "plus de pauses entre des groupes ni de bouton « envoyer la suite »")

----------------------------------------------------------------------
-- 4) Entraînement : niveaux, améliorations débloquées, stats
----------------------------------------------------------------------
check(Levels.trainingLevel(0) == 0 and Levels.trainingLevel(19.9) == 0 and Levels.trainingLevel(20) == 1 and Levels.trainingLevel(60) == 2 and Levels.trainingLevel(1e9) == 6 and Levels.trainingLevel("abc") == 0, "niveaux d'entraînement : 20 XP = 1, 60 = 2, jamais plus de 6")
-- Entraînement acheté avec des pièces (bouton ⚡) : l'XP qui manque pour le niveau suivant, 10 pièces par XP.
do
	local t0, p0 = Levels.trainingPurchase(0)
	local t1, p1 = Levels.trainingPurchase(20)
	local tHalf, pHalf = Levels.trainingPurchase(59.5)
	local t5, p5 = Levels.trainingPurchase(600)
	local tMax, pMax = Levels.trainingPurchase(1200)
	local tBad, pBad = Levels.trainingPurchase("abc")
	local total, xp = 0, 0
	for _ = 1, 10 do
		local target, price = Levels.trainingPurchase(xp)
		if not target then
			break
		end
		total += price
		xp = target
	end
	check(
		t0 == 20 and p0 == 200 and t1 == 60 and p1 == 400 and tHalf == 60 and pHalf == 5 and t5 == 1200 and p5 == 6000 and tMax == nil
			and pMax == nil and tBad == 20 and pBad == 200 and total == 12000 and Levels.trainingLevel(xp) == Levels.TRAINING.MAX_LEVEL,
		`entraînement acheté : 200 pièces pour le niveau 1, 400 pour le 2, 6 000 pour le 6, rien au maximum ; {total} pièces de 0 au maximum (★★★)`
	)
end
local done, needed = Levels.trainingProgress(30)
local maxDone, maxNeeded = Levels.trainingProgress(5000)
check(done == 10 and needed == 40 and maxDone == 0 and maxNeeded == 0, "progression : 30 XP = 10 sur 40 vers le niveau 2 ; au maximum : rien")
local archer0, archer2, archer4, archer6 = Levels.towerStats("MachineGun", 1, 0), Levels.towerStats("MachineGun", 1, 2), Levels.towerStats("MachineGun", 1, 4), Levels.towerStats("MachineGun", 1, 6)
check(archer0.fireRadius == nil and archer2.fireRadius ~= nil, "flèches enflammées : seulement à partir de l'entraînement 2")
check(near(archer0.damage, 3) and near(archer2.damage, 3.3) and near(archer6.damage, 3.9), "+5 % de dégâts par niveau d'entraînement (3 -> 3,3 -> 3,9)")
check(archer4.range == archer0.range + 3 and near(archer6.cooldown, archer0.cooldown / 1.2), "Archer : +3 de portée à l'entraînement 4, +20 % de vitesse au 6")
check(Levels.towerStats("Rocket", 1, 0).kind == "Single" and Levels.towerStats("Rocket", 1, 2).kind == "Pierce", "Baliste : carreau perçant à partir de l'entraînement 2")
check(Levels.towerStats("Frost", 3, 0).fragility == 0 and Levels.towerStats("Frost", 3, 2).fragility > 0, "Totem : fragilité à partir de l'entraînement 2")
-- Retour du propriétaire (02/10/2026) : « le ralentissement du givre est un peu cheaté » : -40 % dans les niveaux.
check(
	near(Levels.towerStats("Frost", 1, 0).slow, 0.4) and near(Levels.towerStats("Frost", 5, 5).slow, 0.4) and near(Levels.towerStats("Frost", 1, 6).slow, 0.5)
		and IdleTowers.stats("Frost", 1).slow == 0.6,
	"Totem : ralentit de 40 % dans les niveaux (50 % à l'entraînement 6), toujours 60 % sur la parcelle"
)
check(near(Levels.towerStats("MachineGun", 3, 0).damage, 3 * IdleConfig.UPGRADE_DAMAGE ^ 2), "une amélioration en niveau : dégâts x1,35")
check(Levels.towerStats("MachineGun", 1, 2) == archer2 and IdleTowers.stats("MachineGun", 1).fireRadius ~= nil, "towerStats garde ses tableaux et ne touche pas aux stats de la parcelle")
check(Levels.perkKeys({ MachineGun = 2, Rocket = 1, Frost = 6 }) == "MachineGun:Fire,Frost:Fragile" and Levels.perkKeys({}) == "", "perkKeys : seulement les effets débloqués")
local decoded = Levels.decodeTraining(Levels.encodeTraining({ MachineGun = 2, Orbital = 6, Inconnue = 3 }))
check(decoded.MachineGun == 2 and decoded.Orbital == 6 and decoded.Frost == 0 and decoded.Inconnue == nil and next(Levels.decodeTraining(nil)) == nil, "encodeTraining / decodeTraining : aller-retour, tour inconnue ignorée")
check(Levels.playXp(true) == 8 and Levels.playXp(false, 0.5) == 1.5 and Levels.playXp(false, 0) == 0 and Levels.playXp(false, 7) == 3, "XP d'une partie : 8 gagnée, 3 x l'avancée perdue (0 si on quitte tout de suite)")
local gainedPerks = Levels.perksBetween("MachineGun", 1, 4)
check(#gainedPerks == 2 and gainedPerks[1].name == "Flèches enflammées" and #Levels.perksBetween("MachineGun", 2, 2) == 0, "perksBetween : les améliorations gagnées entre deux niveaux d'entraînement")
for _, towerType in IdleTowers.ORDER do
	local perks = Levels.PERKS[towerType]
	local fine = perks ~= nil and #perks == 3
	for _, perk in perks or {} do
		fine = fine and perk.level >= 1 and perk.level <= Levels.TRAINING.MAX_LEVEL and perk.name ~= "" and perk.text ~= "" and (perk.on ~= nil or perk.off ~= nil)
	end
	-- (aucune amélioration ne plante sur les stats de sa tour)
	fine = fine and pcall(Levels.towerStats, towerType, 1, Levels.TRAINING.MAX_LEVEL)
	check(fine, `{towerType} : 3 améliorations d'entraînement, toutes applicables`)
end

----------------------------------------------------------------------
-- 5) Données du joueur
----------------------------------------------------------------------
local fresh = Levels.defaultData()
check(fresh.best == 0 and fresh.coins == 0 and fresh.tutorial == 0 and fresh.towers.MachineGun == true and fresh.towers.Bomb == true and fresh.towers.Frost == nil and #fresh.slots == 1 and fresh.slots[1].tower == "MachineGun" and table.concat(fresh.bar, ",") == "MachineGun,Bomb", "nouveau joueur : l'Archer et la Catapulte dans sa barre, un emplacement de camp, rien d'autre")
local archerOnly = Levels.cleanData({ best = 3, towers = { MachineGun = true }, bar = { "MachineGun" } })
check(archerOnly.towers.Bomb == true and table.concat(Levels.ownedTowers(archerOnly), ",") == "MachineGun,Bomb" and archerOnly.best == 3, "ancienne sauvegarde avec le seul Archer : la Catapulte est donnée, le reste est gardé")
local dirty = Levels.cleanData({
	best = 999,
	coins = -5,
	towers = { Frost = true, Dragon = true, Tesla = "oui" },
	xp = { Frost = 1 / 0, Dragon = 5, MachineGun = "12" },
	slots = { { tower = "Tesla", level = 99 }, "n'importe quoi", { tower = "Frost", level = 2 }, { tower = "Frost", level = 1 } },
	bar = { "Frost", "Frost", "Dragon", "MachineGun" },
	trainedAt = "hier",
})
check(dirty.best == Levels.COUNT and dirty.coins == 0 and dirty.trainedAt == 0, "sauvegarde abîmée : niveau, pièces et heure remis dans les clous")
check(dirty.towers.Frost and dirty.towers.MachineGun and dirty.towers.Bomb and not dirty.towers.Dragon and not dirty.towers.Tesla, "sauvegarde abîmée : seules les vraies tours possédées restent (celles de départ toujours)")
check(dirty.xp.Dragon == nil and dirty.xp.MachineGun == 12 and dirty.xp.Frost == 1e9, "sauvegarde abîmée : XP des vraies tours seulement, bornée")
check(#dirty.slots == 3 and dirty.slots[1].tower == "" and dirty.slots[1].level == 5 and dirty.slots[2].tower == "" and dirty.slots[3].tower == "Frost" and dirty.slots[3].level == 2, "sauvegarde abîmée : 3 emplacements au plus, tour non possédée retirée, niveau borné")
check(#dirty.bar == 2 and dirty.bar[1] == "Frost" and dirty.bar[2] == "MachineGun", "sauvegarde abîmée : barre sans doublon ni tour inconnue")
check(Levels.cleanData(nil).best == 0 and Levels.cleanData("x").towers.MachineGun == true, "pas de sauvegarde : un nouveau joueur")
local kept = Levels.cleanData({ coins = 100, towers = { MachineGun = true, Frost = true, Bomb = true, Tesla = true } })
check(kept.coins == 100 and kept.towers.Frost == true and kept.towers.Tesla == true and Levels.cleanData(Levels.defaultData()).coins == 0, "sauvegarde relue : pièces et tours gardées telles quelles")
local owned = Levels.ownedTowers({ bar = { "Bomb", "MachineGun" }, towers = { MachineGun = true, Bomb = true, Frost = true, Orbital = true } })
check(table.concat(owned, ",") == "Bomb,MachineGun,Frost,Orbital", "barre rapide : l'ordre du joueur, puis ses autres tours")

local camp = Levels.defaultData()
check(next(Levels.accrueTraining(camp, 1000)) == nil and camp.trainedAt == 1000 and camp.xp.MachineGun == nil, "entraînement : la première fois, l'heure est seulement notée")
local hour = Levels.accrueTraining(camp, 1000 + 3600)
check(near(hour.MachineGun, 60) and near(camp.xp.MachineGun, 60) and camp.trainedAt == 4600, "entraînement : 1 h dans un emplacement de niveau 1 = 60 XP")
camp.slots[1].level = 3
table.insert(camp.slots, { tower = "Frost", level = 1 }) -- (tour pas possédée : ne s'entraîne pas)
table.insert(camp.slots, { tower = "", level = 5 })
local week = Levels.accrueTraining(camp, 4600 + 7 * 86400)
check(near(week.MachineGun, 12 * 60 * 2.2) and week.Frost == nil, "entraînement : 12 h comptées au plus pour une absence d'une semaine ; tour non possédée et emplacement vide : rien")
check(next(Levels.accrueTraining(camp, 100)) == nil and camp.trainedAt == 100, "entraînement : une heure qui recule ne donne rien")
check(Levels.trainingLevels(camp).MachineGun == Levels.trainingLevel(camp.xp.MachineGun) and Levels.trainingLevels(camp).Orbital == 0, "trainingLevels : un niveau pour chaque tour")

----------------------------------------------------------------------
-- 6) Le moteur d'un niveau (LevelGame)
----------------------------------------------------------------------
do
	-- Niveau 1 : un Archer déjà posé au premier emplacement conseillé, qui tue tout de suite.
	local game, arena = newGame(1, Levels.STARTING_TOWERS)
	local starter = nil
	for _, tower in game.towers do
		starter = tower
	end
	check(towerCount(game) == 1 and starter.type == "MachineGun" and (starter.localPosition - map.spots[1]).Magnitude < 1e-6, "niveau 1 : un Archer offert au premier emplacement conseillé")
	check(game.gold == 60 and game.lives == 10 and game.state == "Running" and arena.folder:GetAttribute("State") == "Running" and arena.folder:GetAttribute("Level") == 1, "niveau 1 : 60 or, 10 vies, en cours (attributs publiés)")
	check(arena.folder:GetAttribute("Total") == #Levels.buildQueue(1) and arena.folder:GetAttribute("Left") == arena.folder:GetAttribute("Total") and arena.folder:GetAttribute("Progress") == 0, "niveau 1 : avancée publiée (tous les monstres restent, flot à 0 %)")
	check(arena.folder:GetAttribute("Perks") == "" and arena.folder:GetAttribute("Training") == Levels.encodeTraining({}), "niveau 1 sans entraînement : aucun effet débloqué publié")
	run(game, 12)
	game:syncAttributes()
	check(game.kills >= 5 and game.gold == 60 + 6 * game.kills and game.lives == 10, `l'Archer offert tue seul : {game.kills} monstres en 12 s, 6 or chacun, aucune vie perdue`)
	check(arena.folder:GetAttribute("Progress") == math.floor(game.clock / game.streamSeconds * 100) and arena.folder:GetAttribute("Progress") >= 10 and arena.folder:GetAttribute("Gold") == game.gold, `avancée du flot publiée : {arena.folder:GetAttribute("Progress")} % après 12 s`)

	-- Pose libre : refus (or, tour pas débloquée, chemin, trop près), puis une vraie pose.
	local before = game.gold
	game.gold = 5
	local ok, reason = game:placeTower("MachineGun", map.spots[2])
	check(ok == false and reason == "Pas assez d'or" and game.gold == 5, "pose refusée sans assez d'or, rien n'est dépensé")
	game.gold = 500
	ok, reason = game:placeTower("Frost", map.spots[2])
	check(ok == false and string.find(reason, "boutique", 1, true) ~= nil, "pose refusée pour une tour pas encore achetée")
	ok, reason = game:placeTower("MachineGun", (geometry.pointAt(30))) -- (pointAt renvoie aussi une direction : gardée hors de l'appel)
	check(ok == false and reason == "Trop près du chemin", "pose refusée sur le chemin")
	ok, reason = game:placeTower("MachineGun", map.spots[1] + Vector3.new(1, 0, 1))
	check(ok == false and reason == "Trop près d'une autre tour", "pose refusée sur une tour déjà posée")
	ok, reason = game:placeTower("Dragon", map.spots[2])
	check(ok == false and reason == "Tour inconnue", "pose refusée pour une tour qui n'existe pas")
	local placed, _, tower = game:placeTower("MachineGun", Vector3.new(-1, 7, 0)) -- (la hauteur envoyée est ignorée)
	check(placed and game.gold == 480 and towerCount(game) == 2 and tower.localPosition.Y == 0 and tower.level == 1 and tower.spent == 20, "pose libre acceptée : 20 or, tour au sol, niveau 1")
	check(tower.model:GetAttribute("TowerId") == tower.id and tower.model:GetAttribute("PlotIndex") == Levels.arenaIndex(1) and tower.model:GetAttribute("Level") == 1, "la tour posée publie son numéro, sa zone et son niveau")

	-- Améliorer, vendre.
	game.gold = 14
	check(game:upgradeTower(tower.id) == false and tower.level == 1, "amélioration refusée sans assez d'or")
	game.gold = 1e6
	check(game:upgradeTower(tower.id) == true and tower.level == 2 and tower.spent == 35 and tower.model:GetAttribute("Level") == 2 and game.gold == 1e6 - 15, "amélioration : 15 or, niveau 2 publié")
	for _ = 1, 20 do
		game:upgradeTower(tower.id)
	end
	local maxOk, maxReason = game:upgradeTower(tower.id)
	check(tower.level == Levels.MAX_TOWER_LEVEL and maxOk == false and maxReason == "Niveau maximum atteint", `amélioration : jamais au-delà du niveau {Levels.MAX_TOWER_LEVEL}`)
	check(game:upgradeTower(987654) == false, "amélioration d'une tour inconnue : refusée")
	local spent = tower.spent
	game.gold = 0
	local sold, refund = game:sellTower(tower.id)
	check(sold and refund == math.floor(spent * Levels.SELL_REFUND) and game.gold == refund and towerCount(game) == 1 and tower.model.destroyed, "vente : 60 % de l'or dépensé rendu, la tour disparaît")
	check(game:sellTower(tower.id) == false, "vente d'une tour déjà vendue : refusée")

	-- Limite de tours identiques.
	game.gold = 1e6
	local archers = 1
	for _, spot in map.spots do
		if game:placeTower("MachineGun", spot) then
			archers += 1
		end
	end
	local _, limitReason = game:placeTower("MachineGun", Vector3.new(40, 0, -15))
	check(archers == 5 and towerCount(game) == 5 and string.find(limitReason or "", "Maximum 5", 1, true) ~= nil, "5 Archers au plus dans un niveau")
	check(before >= 60, "(l'or n'a fait que monter pendant les 12 premières secondes)")

	-- Vitesse x2 : deux pas par image, la même partie jouée deux fois plus vite.
	local clock = game.clock
	game:setSimSpeed(2)
	game:step(1 / 30)
	check(near(game.clock - clock, 2 / 30) and arena.folder:GetAttribute("SimSpeed") == 2, "x2 : deux pas de simulation par image, publié")
	game:setSimSpeed(7)
	check(game.simSpeed == 1, "une vitesse inconnue remet x1")

	-- Paquets réseau : ceux des parcelles (PlotRenderer les lit tels quels).
	run(game, 3)
	local packet, count = game:buildSyncPacket()
	check(packet ~= nil and count == #game.enemies and buffer.len(packet) == count * 12, `paquet des monstres : {count} monstres, 12 octets chacun`)
	local shots, shotCount = game:takeShotsPacket()
	check(shots ~= nil and shotCount > 0 and buffer.len(shots) == shotCount * 31 and #game.shots == 0, `paquet des tirs : {shotCount} tirs, 31 octets chacun, vidé après l'envoi`)

	-- Rangement.
	game:destroy()
	check(arena.folder:GetAttribute("State") == nil and arena.folder:GetAttribute("Gold") == nil and game.towerFolder.destroyed and next(game.towers) == nil, "niveau rangé : attributs effacés, tours retirées")
end

do
	-- Défaite : sans tour, les monstres arrivent au château ; chaque fantassin coûte une vie.
	local game, arena, ends = newGame(2, Levels.STARTING_TOWERS)
	check(towerCount(game) == 0 and game.gold == 65, "niveau 2 : aucune tour offerte, 65 or")
	run(game, 120)
	check(game.state == "Lost" and game.lives == 0 and game.leaked == 10 and #ends == 1 and ends[1] == false, `sans tour : perdu quand 10 fantassins ont atteint le château (en {math.floor(game.clock)} s), fin annoncée une seule fois`)
	game:syncAttributes()
	check(#game.enemies == 0 and arena.folder:GetAttribute("State") == "Lost" and arena.folder:GetAttribute("Lives") == 0, "défaite : plus aucun monstre, état « Lost » publié")
	local clock = game.clock
	game:simulate(1)
	game:finish(true)
	check(game.clock == clock and game.state == "Lost" and #ends == 1, "un niveau fini ne bouge plus et ne se termine pas deux fois")
	check(game:placeTower("MachineGun", map.spots[1]) == false and game.rush == nil, "un niveau fini refuse les poses (et « envoyer la suite » n'existe plus)")
	check(near(game:progress(), game.kills / #game.queue) and game:progress() == 0, "avancée : part du flot éliminée (0 ici)")
end

do
	-- Un colosse qui passe coûte 5 vies, le boss 10.
	local game = newGame(5, Levels.STARTING_TOWERS)
	game:spawnEnemy({ enemy = "Giant", health = 1e9, reward = 40 })
	game.enemies[#game.enemies].distance = geometry.PATH_LENGTH - 0.01
	game:simulate(1 / 30)
	check(game.lives == 5 and game.state == "Running" and game.leakedBig == 1, "un mini-boss qui atteint le château coûte 5 vies (noté : l'écran de défaite donnera un conseil)")
	game:spawnEnemy({ enemy = "Boss", health = 1e9, reward = 100 })
	game.enemies[#game.enemies].distance = geometry.PATH_LENGTH - 0.01
	game:simulate(1 / 30)
	check(game.lives == 0 and game.state == "Lost" and game.leakedBig == 2 and game.leaked == 2, "un boss qui atteint le château : c'est perdu")
end

do
	-- Flot continu dans le moteur : chaque monstre sort à son heure, sans pause, jusqu'au dernier.
	local game = newGame(2, Levels.STARTING_TOWERS)
	game.lives = math.huge
	local queue = Levels.buildQueue(2)
	local onTime = true
	for _ = 1, 40 * 30 do
		game:simulate(1 / 30)
		local due = 0
		for _, item in queue do
			if item.at <= game.clock + 1e-6 then
				due += 1
			end
		end
		onTime = onTime and game.queueIndex - 1 == due
	end
	check(onTime and game.queueIndex > 30, `flot continu : après 40 s, {game.queueIndex - 1} monstres sortis, chacun à son heure`)
end

----------------------------------------------------------------------
-- 7) La difficulté. Retour du propriétaire (02/10/2026) : « beaucoup trop facile », « obligé d'être super actif
--    pendant le niveau : poser des tours, améliorer », « si juste 2 Archers gèrent le niveau, je passe mon temps
--    à attendre ». Chaque niveau, joué par les joueurs simulés (Bot.luau) avec les tours attendues à ce niveau.
----------------------------------------------------------------------
local function outcome(result): string
	return if result.won then `gagné avec {result.lives} vies` else `perdu à {math.floor(result.kills / result.total * 100 + 0.5)} %`
end
for level = 1, Levels.COUNT do
	-- Celui qui réinvestit son or sans arrêt gagne, avec presque toutes ses vies.
	local active = Bot.play(level, Bot.profile(level), function(result)
		return result.won and result.lives >= 8
	end)
	check(active.won and active.lives >= 8, `niveau {level} : le joueur très actif gagne avec au moins 8 vies ({outcome(active)})`)
	-- Le rythme demandé (Bot.EXPECTED : un achat toutes les 5 s au niveau 1, toutes les 3,5 s à la fin) suffit.
	local reference = Bot.play(level, Bot.profile(level, "reference"), function(result)
		return result.won and result.lives >= 5
	end)
	check(reference.won and reference.lives >= 5, `niveau {level} : un achat toutes les {Bot.EXPECTED[level].pace} s suffit ({outcome(reference)})`)
	-- Plus lent que ça, on perd : un achat toutes les 8 s, toutes les 15 s.
	local slow = Bot.play(level, Bot.profile(level, 8))
	check(not slow.won, `niveau {level} : un achat toutes les 8 s ne suffit pas ({outcome(slow)})`)
	local distracted = Bot.play(level, Bot.profile(level, 15))
	check(not distracted.won and distracted.kills <= slow.kills, `niveau {level} : un achat toutes les 15 s perd encore plus tôt ({outcome(distracted)})`)
	-- Poser quelques tours puis attendre : toujours perdu, et de plus en plus tard quand on en pose plus.
	local two = Bot.playLazy(level, { "MachineGun", "MachineGun" })
	local six = Bot.playLazy(level, { "MachineGun", "MachineGun", "Bomb", "MachineGun", "MachineGun", "Bomb" })
	check(not two.won and two.kills / two.total < 0.3, `niveau {level} : 2 Archers puis attendre : {outcome(two)} (avant 30 %)`)
	check(not six.won and six.kills > two.kills and six.kills / six.total < 0.6, `niveau {level} : 4 Archers et 2 Catapultes sans rien améliorer : {outcome(six)} (plus tard, avant 60 %)`)
	-- Les premières secondes laissent le temps de poser ses premières tours : celui qui attend tient un moment.
	check(two.seconds >= 35, `niveau {level} : celui qui pose 2 Archers puis attend tient au moins 35 s ({math.floor(two.seconds)} s)`)
end
do
	-- Sans la boutique, le joueur très actif passe les premiers niveaux ; à partir du niveau 6 il faut ses tours.
	-- Tout débloquer et tout entraîner rend le boss facile.
	local startOnly = { towers = Levels.STARTING_TOWERS, training = 0 }
	check(Bot.play(1, startOnly).won and Bot.play(2, startOnly).won, "sans boutique : les niveaux 1 et 2 se gagnent")
	local stuck = true
	for level = 6, Levels.COUNT do
		stuck = stuck and not Bot.play(level, startOnly).won
	end
	check(stuck, `sans boutique : les niveaux 6 à {Levels.COUNT} sont perdus, même en étant très actif`)
	-- Le Totem aide sans tout faire : au niveau 5, le joueur de référence gagne avec lui et perd sans lui.
	local withTotem = Bot.play(5, Bot.profile(5, "reference"))
	local withoutTotem = Bot.play(5, { towers = Levels.STARTING_TOWERS, training = 1, interval = Bot.EXPECTED[5].pace, actions = 1 })
	check(withTotem.won and not withoutTotem.won and withoutTotem.kills / withoutTotem.total >= 0.6, `niveau 5 au rythme demandé : {outcome(withTotem)} avec le Totem, {outcome(withoutTotem)} sans lui (il aide, il ne fait pas tout)`)
	local alone = Bot.play(10, startOnly)
	local full = Bot.play(10, { towers = Bot.ALL_TOWERS, training = 6 })
	check(not alone.won and full.won and full.lives == 10, "niveau 10 : perdu avec les deux tours de départ, gagné sans perdre de vie avec toutes les tours entraînées")
	local lastFull = Bot.play(Levels.COUNT, { towers = Bot.ALL_TOWERS, training = 6 })
	check(lastFull.won and lastFull.lives == 10, `niveau {Levels.COUNT} : gagné sans perdre de vie avec toutes les tours entraînées ({outcome(lastFull)})`)
	-- 2e territoire : la Baliste est attendue (les 10 premiers niveaux la paient). Sans elle, le niveau 12 (son
	-- premier colosse) se perd au rythme demandé.
	local noBallista = Bot.play(12, { towers = { "MachineGun", "Bomb", "Frost", "Tesla" }, training = 2, interval = Bot.EXPECTED[12].pace, actions = 1 })
	local withBallista = Bot.play(12, Bot.profile(12, "reference"))
	check(withBallista.won and (not noBallista.won or noBallista.lives < withBallista.lives), `niveau 12 au rythme demandé : {outcome(withBallista)} avec la Baliste, {outcome(noBallista)} sans elle`)
end

do
	-- Totem de givre dans le moteur : un monstre dans son aura avance à 60 % de sa vitesse (-40 %, pas -60 %).
	local game = newGame(3, { "MachineGun", "Bomb", "Frost" })
	game.gold = 1e6
	game.lives = math.huge
	local placed = game:placeTower("Frost", Vector3.new(-45, 0, -8))
	local slowed = nil
	for _ = 1, 10 * 30 do
		game:simulate(1 / 30)
		for _, enemy in game.enemies do
			if not enemy.dead and enemy.controlSource == "Frost" and game.clock < enemy.controlUntil then
				slowed = enemy
				break
			end
		end
		if slowed then
			break
		end
	end
	local before = if slowed then slowed.distance else 0
	game:simulate(1 / 30)
	local full = if slowed then slowed.def.speed * IdleConfig.ENEMY_SPEED_MULTIPLIER * slowed.speedScale / 30 else 1
	check(
		placed and slowed ~= nil and near(slowed.controlFactor, 0.4) and near((slowed.distance - before) / full, 0.6, 0.01),
		`Totem posé dans un niveau : le monstre dans son aura avance à {if slowed then math.floor((slowed.distance - before) / full * 100 + 0.5) else "?"} % de sa vitesse`
	)
end

do
	-- Entraînement : les flèches enflammées n'existent dans un niveau qu'à partir de l'entraînement 2.
	local plain = newGame(2, Levels.STARTING_TOWERS, 0)
	local trained, trainedArena = newGame(2, Levels.STARTING_TOWERS, 2)
	local most = {}
	for _, game in { plain, trained } do
		game.gold = 1e6
		game:placeTower("MachineGun", map.spots[1])
		most[game] = 0
		for _ = 1, 20 * 30 do
			game:simulate(1 / 30)
			most[game] = math.max(most[game], #game.firePatches)
		end
	end
	check(most[plain] == 0 and most[trained] > 0, `feu des flèches : aucune zone sans entraînement ({most[plain]}), des zones à l'entraînement 2 ({most[trained]} à la fois au plus)`)
	check(trainedArena.folder:GetAttribute("Perks") == "MachineGun:Fire", "effet débloqué publié pour l'affichage (« MachineGun:Fire »)")
	check(trained.kills >= plain.kills, `l'Archer entraîné tue au moins autant ({trained.kills} contre {plain.kills} en 20 s)`)
end

----------------------------------------------------------------------
-- 8) Évolutions et camp d'entraînement sur la parcelle. Demande du propriétaire (02/10/2026) : « tu peux gérer
--    toute la parcelle et le système d'évolution de tour ».
----------------------------------------------------------------------
check(
	Levels.evolutionStage("MachineGun", 0) == 0 and Levels.evolutionStage("MachineGun", 1) == 0 and Levels.evolutionStage("MachineGun", 2) == 1
		and Levels.evolutionStage("MachineGun", 5) == 2 and Levels.evolutionStage("MachineGun", 6) == 3 and Levels.evolutionStage("Dragon", 6) == 0,
	"évolutions : la 1re à l'entraînement 2, la 2e au 4, la 3e au 6"
)
check(Levels.stars(0) == "" and Levels.stars(2) == "★★" and Levels.stars(9) == "★★★", "étoiles : une par évolution, trois au plus")
local evolvingTowers = true
for _, towerType in IdleTowers.ORDER do
	evolvingTowers = evolvingTowers and Levels.evolutionStage(towerType, Levels.TRAINING.MAX_LEVEL) == #Levels.EVOLUTION_NAMES
end
check(evolvingTowers, "chacune des 8 tours a ses 3 évolutions")
do
	local level2 = newGame(2, Levels.STARTING_TOWERS, 4)
	level2.gold = 1e6
	local _, _, evolved = level2:placeTower("MachineGun", map.spots[1])
	check(evolved.model:GetAttribute("Stars") == 2, "dans un niveau, une tour entraînée au niveau 4 porte ses 2 étoiles")
end

local CampGame = require("./gen/server/Hub/CampGame")
local PlotLayout = require("./gen/shared/PlotLayout")
check(
	#Levels.CAMP.SPOTS >= #Levels.TRAINING.SLOT_UNLOCK_COST and PlotLayout.SPOTS[Levels.CAMP.SPOTS[1]] ~= nil and PlotLayout.SPOTS[Levels.CAMP.SPOTS[3]] ~= nil,
	"camp : un socle de la parcelle pour chaque emplacement d'entraînement"
)
do
	local levels = Levels.defaultData() -- (l'Archer est dans l'emplacement 1)
	local plot = { index = 2, folder = Env.fakeInstance("Plot2") }
	local camp = CampGame.new(plot, { UserId = 7, Parent = {} }, levels)
	local archer = camp.slotTowers[1]
	local pad = PlotLayout.SPOTS[Levels.CAMP.SPOTS[1]]
	check(
		archer ~= nil and archer.type == "MachineGun" and archer.stage == 0 and camp.slotTowers[2] == nil
			and near(archer.localPosition.X, pad.X) and near(archer.localPosition.Z, pad.Z) and archer.model:GetAttribute("CampSlot") == 1
			and archer.model:GetAttribute("SpotIndex") == nil,
		"camp : la tour de l'emplacement 1 (l'Archer) est posée sur son socle de la parcelle"
	)
	check(
		plot.folder:GetAttribute("Camp") == true and plot.folder:GetAttribute("State") == "Running" and plot.folder:GetAttribute("OwnerUserId") == 7
			and plot.folder:GetAttribute("Wave") == 1 and plot.folder:GetAttribute("Perks") == "",
		"camp : la parcelle publie qu'elle est un camp (attributs Camp, State, OwnerUserId) et aucun effet débloqué"
	)
	local coinsBefore, xpBefore, most = levels.coins, levels.xp.MachineGun, 0
	camp:step(1 / 30)
	local first = camp.enemies[1]
	check(
		#camp.enemies >= 10 and first ~= nil and first.health == Levels.CAMP.TARGET_SECONDS * 15 and near(first.speedScale, Levels.CAMP.TARGET_SPEED)
			and first.distance > PlotLayout.PATH_LENGTH - 40,
		`camp : des cibles roulent déjà sur tout le chemin à l'arrivée ({#camp.enemies} cibles de {first and first.health} PV, 2 s de tir de l'Archer)`
	)
	local earlyKills = 0
	for step = 1, 90 * 30 do
		camp:step(1 / 30)
		most = math.max(most, #camp.enemies)
		if step == 10 * 30 then
			earlyKills = camp.kills
		end
	end
	check(
		earlyKills >= 1 and camp.kills >= 20 and most >= 5 and most <= Levels.CAMP.MAX_TARGETS,
		`camp : l'Archer détruit {earlyKills} cible(s) dans les 10 premières secondes, {camp.kills} en 90 s ({most} cibles sur le chemin au plus)`
	)
	check(levels.coins == coinsBefore and levels.xp.MachineGun == xpBefore and camp.gold == 0, "camp : les cibles ne rapportent rien (ni pièces, ni or, ni XP)")
	local packet, count = camp:buildSyncPacket()
	local shots, shotCount = camp:takeShotsPacket()
	check(packet ~= nil and count == #camp.enemies and shots ~= nil and shotCount > 0, `camp : mêmes paquets réseau qu'une parcelle ({count} cibles, {shotCount} tirs)`)

	-- L'entraînement fait évoluer la tour : au niveau 2 (60 XP), l'Archer du camp est refait avec sa 1re évolution et
	-- se sert de son nouveau pouvoir (flèches enflammées) sur les cibles.
	local oldModel = archer.model
	levels.xp.MachineGun = 60
	local changed = camp:refresh(levels)
	local evolved = camp.slotTowers[1]
	local fires = 0
	for _ = 1, 30 * 30 do
		camp:step(1 / 30)
		fires = math.max(fires, #camp.firePatches)
	end
	check(
		changed and evolved ~= archer and evolved.stage == 1 and evolved.model:GetAttribute("Stars") == 1 and oldModel.destroyed == true and fires > 0
			and plot.folder:GetAttribute("Perks") == "MachineGun:Fire",
		`camp : à 60 XP l'Archer évolue (1 étoile) et ses flèches enflammées brûlent les cibles ({fires} zones de feu à la fois)`
	)
	check(camp:refresh(levels) == false and camp.slotTowers[1] == evolved, "camp : rien n'est refait quand rien ne change")
	-- +5 % de dégâts par niveau d'entraînement, sans refaire le modèle.
	levels.xp.MachineGun = 140
	check(camp:refresh(levels) == false and near(camp:statsOf(evolved).damage, 3 * 1.15), "camp : au niveau d'entraînement 3, +15 % de dégâts, même tour (pas de nouvelle évolution)")

	-- Emplacements : une 2e tour, puis l'emplacement 1 vidé.
	table.insert(levels.slots, { tower = "Bomb", level = 1 })
	camp:refresh(levels)
	local catapult = camp.slotTowers[2]
	local pad2 = PlotLayout.SPOTS[Levels.CAMP.SPOTS[2]]
	check(catapult ~= nil and catapult.type == "Bomb" and near(catapult.localPosition.X, pad2.X) and towerCount(camp) == 2, "camp : la Catapulte mise dans l'emplacement 2 apparaît sur le 2e socle")
	levels.slots[1].tower = ""
	camp:refresh(levels)
	check(camp.slotTowers[1] == nil and evolved.model.destroyed == true and towerCount(camp) == 1, "camp : une tour retirée de son emplacement quitte la parcelle")
	levels.slots[2].tower = "Frost" -- (tour pas possédée : personne sur le socle)
	camp:refresh(levels)
	check(camp.slotTowers[2] == nil and towerCount(camp) == 0, "camp : une tour pas possédée n'est jamais posée")
	local targets = #camp.enemies
	for _ = 1, 80 * 30 do
		camp:step(1 / 30)
	end
	check(targets > 0 and #camp.enemies == 0, "camp : sans tour à l'entraînement, plus aucune cible ne sort (les dernières s'en vont au bout du chemin)")

	camp:destroy()
	check(
		plot.folder:GetAttribute("Camp") == nil and plot.folder:GetAttribute("State") == nil and camp.towerFolder.destroyed == true and next(camp.towers) == nil,
		"camp rangé : la parcelle n'est plus un camp, tours retirées"
	)
end

----------------------------------------------------------------------
-- 9) Le tuto des nouveaux joueurs. Demande du propriétaire (02/10/2026) : « fais le tuto bien, je veux un jeu
--    sortable ». Son étape dans les données, et les DEUX PREMIERS GESTES du niveau 1 (Levels.firstSteps : ce que la
--    flèche montre, client/TutorialUI.luau ; « juste poser une tour, et améliorer, et fin », 03/10/2026).
----------------------------------------------------------------------
check(Levels.TUTORIAL.SHOP == 1 and Levels.TUTORIAL.DONE == 2 and Levels.defaultData().tutorial == 0, "tuto : un nouveau joueur est à l'étape 0 (1 = la boutique, 2 = fini)")
check(
	Levels.cleanData(Levels.defaultData()).tutorial == 0 and Levels.cleanData({ best = 0, tutorial = 1 }).tutorial == 1 and Levels.cleanData({ best = 5, tutorial = 0 }).tutorial == 0
		and Levels.cleanData({ tutorial = 2 }).tutorial == 2,
	"tuto : l'étape sauvegardée est relue telle quelle"
)
check(
	Levels.cleanData({ best = 3 }).tutorial == Levels.TUTORIAL.SHOP and Levels.cleanData({ best = 0 }).tutorial == 0
		and Levels.cleanData({ best = 1, towers = { Frost = true } }).tutorial == Levels.TUTORIAL.DONE,
	"tuto, sauvegarde d'avant le tuto : un niveau déjà gagné = pas de guide, une tour déjà achetée = tuto fini"
)
check(
	Levels.cleanData({ best = 4, tutorial = 99 }).tutorial == 2 and Levels.cleanData({ best = 4, tutorial = -3 }).tutorial == 0
		and Levels.cleanData({ best = 4, tutorial = "abc" }).tutorial == 1 and Levels.cleanData({ tutorial = 1.7 }).tutorial == 1,
	"tuto : une étape abîmée est remise dans les clous"
)
do
	local MG, BOMB = "MachineGun", "Bomb"
	local function placed(...)
		local list = {}
		for index = 1, select("#", ...), 2 do
			table.insert(list, { type = select(index, ...), level = select(index + 1, ...) })
		end
		return list
	end
	local function steps(towers, gold: number, owned: { string }?)
		return Levels.firstSteps(owned or Levels.STARTING_TOWERS, towers, gold)
	end
	local function says(result, kind: string, value: any): boolean
		return result ~= nil and result.kind == kind and (if kind == "Place" then result.tower == value else result.index == value)
	end
	-- 1er geste : POSER une tour (la flèche montre la première tour de sa barre qu'il peut payer ; il la pose où il veut).
	check(says(steps(placed(MG, 1), 60), "Place", MG), "tuto, 1er geste : au départ du niveau 1 (l'Archer offert, 60 or), poser une tour : la première de la barre")
	check(steps(placed(MG, 1), 19) == nil, "tuto, 1er geste : pas encore de quoi payer une tour : rien à montrer, l'or arrive")
	check(
		says(steps(placed(BOMB, 1), 50, { BOMB, MG }), "Place", BOMB) and says(steps(placed(MG, 1), 30, { BOMB, MG }), "Place", MG),
		"tuto, 1er geste : la première tour de sa barre qu'il peut payer (la Catapulte avec 50 or, l'Archer avec 30)"
	)
	check(says(steps({}, 65), "Place", MG) and says(steps(placed("Dragon", 1), 65), "Place", MG), "tuto, 1er geste : aucune tour posée (ou une tour inconnue) : poser une tour")
	-- 2e geste : AMÉLIORER une tour (la moins chère à améliorer).
	local second, secondDone = steps(placed(MG, 1, MG, 1), 40)
	check(says(second, "Upgrade", 1) and secondDone == false, "tuto, 2e geste : une tour posée en plus de l'Archer offert : améliorer une tour (la plus ancienne à prix égal)")
	check(says(steps(placed(BOMB, 1, MG, 1), 40), "Upgrade", 2), "tuto, 2e geste : la flèche montre la tour la moins chère à améliorer (l'Archer, pas la Catapulte)")
	check(steps(placed(MG, 1, MG, 1), 14) == nil, "tuto, 2e geste : pas encore de quoi payer l'amélioration : rien à montrer")
	-- Puis rien : le joueur se débrouille.
	local after, finished = steps(placed(MG, 2, MG, 1), 500)
	check(after == nil and finished == true, "tuto : une tour posée et une tour améliorée : fini, plus rien à montrer, même avec beaucoup d'or")
	local early, earlyDone = steps(placed(MG, 2), 500)
	check(says(early, "Place", MG) and earlyDone == false, "tuto : l'Archer offert amélioré avant d'avoir posé une tour : il reste à poser une tour")
end

----------------------------------------------------------------------
-- 10) Jouer en équipe. Demande du propriétaire (03/10/2026) : « jouer en équipe », « et même un bonus 10 % pièces,
--     et on pourrait faire trio et quad aussi avec 30 et 40 % ». Les règles (Levels), une partie à plusieurs
--     (LevelGame : chacun son or et ses tours), des équipes de joueurs simulés (Bot.playTeam).
----------------------------------------------------------------------
check(
	Levels.TEAM_MAX == 4 and Levels.teamBonus(1) == 0 and Levels.teamBonus(2) == 0.1 and Levels.teamBonus(3) == 0.3 and Levels.teamBonus(4) == 0.4,
	"équipe : 4 joueurs au plus ; pièces en plus : rien seul, +10 % à deux, +30 % à trois, +40 % à quatre (chiffres du propriétaire)"
)
check(
	Levels.teamReward(1000, 1) == 1000 and Levels.teamReward(1000, 2) == 1100 and Levels.teamReward(1000, 3) == 1300 and Levels.teamReward(1000, 4) == 1400
		and Levels.teamReward(80, 2) == 88 and Levels.teamReward(1000, nil) == 1000,
	"équipe : la récompense de chacun avec le bonus (1 000 -> 1 100, 1 300, 1 400 ; 80 -> 88 à deux)"
)
check(
	Levels.teamHealth(1) == 1 and Levels.teamHealth(nil) == 1 and Levels.teamHealth(2) > 1 and Levels.teamHealth(3) > Levels.teamHealth(2)
		and Levels.teamHealth(4) > Levels.teamHealth(3) and Levels.teamHealth(9) == Levels.teamHealth(4),
	`équipe : les monstres ont plus de vie à plusieurs (x{Levels.teamHealth(2)} à deux, x{Levels.teamHealth(3)} à trois, x{Levels.teamHealth(4)} à quatre)`
)
check(Levels.memberKey(123456) == "123456" and Levels.memberKey(-1001) == "m1001" and Levels.memberKey(nil) == "0", "équipe : n° d'un joueur dans les noms d'attributs (« m » devant un n° négatif)")
do
	local solo, duo = Levels.buildQueue(30), Levels.buildQueue(30, 2)
	local same = #solo == #duo
	for index, item in solo do
		local other = duo[index]
		if not other or other.at ~= item.at or other.enemy ~= item.enemy or other.reward ~= item.reward or math.abs(other.health - item.health * Levels.teamHealth(2)) > 0.06 then
			same = false
		end
	end
	check(same, "équipe : le même flot de monstres (mêmes heures, mêmes types, même or), PV x teamHealth")
end
do
	-- Une partie à deux : l'hôte (UserId 1) et un coéquipier (UserId 2, Archer entraîné au maximum, Totem acheté).
	local definition = Levels.definition(12)
	local arena = { index = Levels.arenaIndex(2), folder = Env.fakeInstance("Arena"), cframe = Levels.arenaCFrame(2), map = definition.map }
	local friendPlayer = { UserId = 2, Parent = {} }
	local game = LevelGame.new(arena, { UserId = 1, Parent = {} }, {
		level = 12,
		unlocked = { MachineGun = true, Bomb = true },
		training = { MachineGun = 0 },
		team = { { player = friendPlayer, unlocked = { MachineGun = true, Bomb = true, Frost = true }, training = { MachineGun = Levels.TRAINING.MAX_LEVEL } } },
	})
	local folder = arena.folder
	local friend = game:memberOf(friendPlayer)
	check(
		game.teamSize == 2 and friend ~= nil and friend ~= game and game:memberOf({}) == nil and game.gold == definition.gold and friend.gold == definition.gold,
		"partie à deux : chacun commence avec l'or du niveau"
	)
	check(
		folder:GetAttribute("TeamSize") == 2 and folder:GetAttribute("Gold_1") == definition.gold and folder:GetAttribute("Gold_2") == definition.gold
			and folder:GetAttribute("Training_2") == Levels.encodeTraining(friend.training) and string.find(folder:GetAttribute("Perks") or "", "MachineGun:Fire", 1, true) ~= nil,
		"partie à deux : attributs de la zone (or et entraînement de chacun ; effets des tours des deux joueurs)"
	)
	check(game.queue[1].health == Levels.buildQueue(12, 2)[1].health, "partie à deux : les monstres d'une équipe de deux")
	local spots = Levels.geometry(definition.map).map.spots
	local placed, _, tower = game:placeTower("MachineGun", spots[1], friend)
	check(
		placed and tower.owner == friend and friend.gold == definition.gold - Levels.placeCost("MachineGun") and game.gold == definition.gold
			and tower.model:GetAttribute("OwnerId") == 2,
		"partie à deux : le coéquipier pose avec SON or, la tour est à lui"
	)
	check(not game:placeTower("Frost", spots[2]) and (game:placeTower("Frost", spots[2], friend)), "partie à deux : chacun ses tours débloquées (le Totem du coéquipier n'est pas à l'hôte)")
	local upgraded, reason = game:upgradeTower(tower.id)
	local sold, _, why = game:sellTower(tower.id)
	check(
		not upgraded and reason == LevelGame.NOT_YOURS and not sold and why == LevelGame.NOT_YOURS and game.towers[tower.id] ~= nil and tower.level == 1,
		"partie à deux : l'hôte ne peut ni améliorer ni vendre la tour du coéquipier"
	)
	check((game:upgradeTower(tower.id, friend)) and tower.level == 2, "partie à deux : le coéquipier améliore la sienne")
	check(game:statsOf(tower).damage > Levels.towerStats("MachineGun", 2, 0).damage * 1.2, "partie à deux : sa tour a SON entraînement (l'Archer du coéquipier est entraîné au maximum)")
	-- Les limites par type valent pour chacun : 5 Archers à l'hôte, en plus de celui du coéquipier.
	game.gold, friend.gold = 10000, 10000
	local hostArchers = 0
	for index = 3, #spots do
		if game:placeTower("MachineGun", spots[index]) then
			hostArchers += 1
		end
	end
	check(
		hostArchers == Levels.maxCopies("MachineGun") and game:copiesOf(game).MachineGun == hostArchers and game:copiesOf(friend).MachineGun == 1,
		`partie à deux : chacun ses limites par type (l'hôte pose {hostArchers} Archers, en plus de celui du coéquipier)`
	)
	-- L'or d'un monstre tué va à chacun.
	local hostBefore, friendBefore = game.gold, friend.gold
	game:simulate(1 / 30)
	local enemy = game.enemies[1]
	game:damageEnemy(enemy, enemy.health + 1, false)
	check(game.gold == hostBefore + enemy.reward and friend.gold == friendBefore + enemy.reward, "partie à deux : l'or d'un monstre tué va à chacun, en entier")
	game:syncAttributes()
	check(folder:GetAttribute("Gold_2") == math.floor(friend.gold) and folder:GetAttribute("Gold") == math.floor(game.gold), "partie à deux : l'or de chacun est publié")
	-- Le coéquipier s'en va : il ne reçoit plus d'or et ne pose plus rien ; ses tours restent et tirent toujours.
	game:removeMember(friend)
	game:syncAttributes()
	local friendGold = friend.gold
	for _ = 1, 30 do
		game:simulate(1 / 30)
	end
	local another = game.enemies[1]
	if another then
		game:damageEnemy(another, another.health + 1, false)
	end
	local left = 0
	for _, other in game.towers do
		if other.owner == friend then
			left += 1
		end
	end
	check(
		friend.departed and friend.gold == friendGold and folder:GetAttribute("Gold_2") == nil and left == 2 and not game:placeTower("Bomb", spots[#spots], friend),
		`partie à deux : celui qui s'en va ne reçoit plus d'or et ne pose plus rien ; ses {left} tours restent`
	)
	game:destroy()
	check(folder:GetAttribute("Gold_1") == nil and folder:GetAttribute("Training_2") == nil and folder:GetAttribute("TeamSize") == nil, "partie à deux rangée : ses attributs sont effacés")
end
-- Équipes de joueurs simulés, avec les PV d'équipe : les joueurs de référence gagnent (au moins 5 vies), comme seuls.
for _, size in { 2, 3, 4 } do
	for _, level in { 10, 50, 100 } do
		local reference = Bot.playTeam(level, Bot.teamProfiles(level, size, "reference"), function(best)
			return best.won and best.lives >= 5
		end)
		check(reference.won and reference.lives >= 5, `équipe de {size}, niveau {level} : les joueurs de référence gagnent avec au moins 5 vies ({outcome(reference)})`)
	end
end

print(`{passed} tests réussis, {failed} ratés`)
if failed > 0 then
	error(`{failed} test(s) raté(s)`, 0)
end

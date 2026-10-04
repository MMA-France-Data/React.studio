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
		check(types.Colossus == 1 and not types.Giant and not types.Boss, "niveau 15 : le mini-boss est un colosse géant (un seul gros monstre), pas de boss")
	elseif level == 20 then
		check(types.Boss == 1 and types.Giant == 2 and queue[#queue].enemy == "Boss", "niveau 20 : deux colosses dans le flot, puis le boss le ferme")
	elseif level == 25 then
		check(types.Colossus == 1 and not types.Giant and not types.Boss, "niveau 25 : un colosse géant (à la place de trois colosses ensemble), pas de boss")
	elseif level == 30 then
		check(types.Boss == 1 and types.Giant == 3 and queue[#queue].enemy == "Boss", "niveau 30 : trois colosses dans le flot, puis le boss le ferme")
	elseif level == 35 then
		check(types.Colossus == 2 and not types.Giant and not types.Boss, "niveau 35 : deux colosses géants (à la place de deux paires de colosses), pas de boss")
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
		if item.enemy ~= "Normal" and item.enemy ~= "Giant" and item.enemy ~= "Colossus" and item.enemy ~= "Boss" then
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
-- Idée du propriétaire (04/10/2026) : « un gros colosse plus fort qui apparaît à un couloir aléatoire ».
do
	local Enemies = require("./gen/shared/Enemies")
	local colossus, giant = Enemies.Defs.Colossus, Enemies.Defs.Giant
	local function specialHealth(level: number, enemyType: string): number
		for _, item in Levels.buildQueue(level) do
			if item.enemy == enemyType then
				return item.health
			end
		end
		return 0
	end
	check(
		colossus ~= nil and table.find(Enemies.ORDER, "Colossus") == 7 and colossus.size > giant.size and colossus.speed < giant.speed
			and Levels.ENEMY.Colossus.leak == 10 and specialHealth(25, "Colossus") > specialHealth(24, "Giant") * 1.2,
		`colosse géant : plus grand et plus lent qu'un colosse, plus résistant ({specialHealth(25, "Colossus")} PV au niveau 25, un colosse du niveau 24 : {specialHealth(24, "Giant")}), il coûte toutes les vies s'il passe`
	)
end
check(
	Levels.enemyHealth(20, "Boss") > Levels.enemyHealth(10, "Boss") and Levels.enemyHealth(11, "Normal") > Levels.enemyHealth(10, "Normal"),
	`2e territoire : des monstres plus résistants (fantassin {Levels.enemyHealth(10, "Normal")} PV au niveau 10, {Levels.enemyHealth(11, "Normal")} au niveau 11 ; boss {Levels.enemyHealth(10, "Boss")} puis {Levels.enemyHealth(20, "Boss")} PV)`
)
-- Chaque territoire est plus dur que le précédent : un de ses niveaux a en moyenne plus de PV en tout (tous ses
-- monstres, colosses compris), et son boss en a plus. (Les PV du seul fantassin ne suffisent pas : aux niveaux 51
-- à 60, cinq colosses par niveau demandent des fantassins un peu moins résistants qu'aux niveaux 41 à 50.)
-- Seulement les territoires OUVERTS (Levels.OPEN_COUNT) : ceux d'après datent de la boutique, ils seront réglés de
-- nouveau avant d'ouvrir.
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
		if territory > 1 and (territory - 1) * Levels.TERRITORY_SIZE < Levels.OPEN_COUNT then
			harder = harder and averages[territory] > averages[territory - 1] and bosses[territory] > bosses[territory - 1]
		end
	end
	local shown, shownBosses = {}, {}
	for territory, average in averages do
		table.insert(shown, `{math.floor(average)}`)
		table.insert(shownBosses, `{math.floor(bosses[territory])}`)
	end
	check(harder, `chaque territoire ouvert est plus dur que le précédent (PV de tous les monstres d'un niveau, en moyenne : {table.concat(shown, ", ")} ; PV des boss : {table.concat(shownBosses, ", ")})`)
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
check(
	#map.lanes == 1 and map.lanes[1] == map.path and #geometry.lanes == 1 and geometry.lanes[1].PATH_LENGTH == 204 and geometry.pointAt == geometry.lanes[1].pointAt
		and Levels.mapFor(5) == "Valley" and Levels.mapFor(5, 1) == "Valley" and Levels.mapFor(5, 2) == "Valley_2" and Levels.mapFor(95, 4) == "Dragon_4",
	"une carte seule a un seul couloir (son chemin) ; Levels.mapFor : la carte du territoire seul, sa carte d'équipe à 2, 3 ou 4"
)
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
-- Décision du propriétaire (04/10/2026) : « ça serait mieux pas de tour en boutique, et le niveau 1 te donne un œuf de
-- catapulte qui éclot en 10 s ». L'Archer seul au départ ; toutes les autres tours sortent des œufs.
check(#Levels.STARTING_TOWERS == 1 and Levels.STARTING_TOWERS[1] == "MachineGun" and Levels.SHOP == nil, "départ : l'Archer seul, plus de boutique")
local inEggs, missingTowers = {}, {}
for _, eggType in Levels.EGG_ORDER do
	for _, entry in Levels.eggChances(eggType) do
		inEggs[entry.tower] = true
	end
end
for _, towerType in IdleTowers.ORDER do
	if not inEggs[towerType] or not Levels.TOWER_COST[towerType] then
		table.insert(missingTowers, towerType)
	end
end
check(#missingTowers == 0, `toutes les tours sortent des œufs et ont un prix en or (manquent : {table.concat(missingTowers, ", ")})`)
check(
	Levels.eggFor(1, true) == "Starter" and Levels.EGGS.Starter.tower == "Bomb" and Levels.EGGS.Starter.seconds == 10 and Levels.eggFor(1, false) == "Common",
	"niveau 1 gagné la première fois : l'œuf de catapulte (10 s, la Catapulte à coup sûr) ; en le rejouant : un œuf commun"
)
-- Pièces de niveau : les premières victoires (les tours ne s'achètent plus : elles servent au camp, aux couveuses et à
-- finir les œufs).
local firstTerritory, firstTwenty, firstThirty, firstForty, allFirst = 0, 0, 0, 0, 0
for level = 1, Levels.COUNT do
	local reward = Levels.firstReward(level)
	allFirst += reward
	firstTerritory += if level <= Levels.TERRITORY_SIZE then reward else 0
	firstTwenty += if level <= 20 then reward else 0
	firstThirty += if level <= 30 then reward else 0
	firstForty += if level <= 40 then reward else 0
end
check(
	firstTerritory == 2180 and firstTwenty == 6860 and firstThirty == 14040 and firstForty == 23720 and allFirst == 134300,
	`pièces des premières victoires : {firstTerritory} pour les 10 premiers niveaux, {firstTwenty} pour 20, {firstThirty} pour 30, {firstForty} pour 40`
)
-- De quoi finir ses œufs : les pièces du niveau 2 paient un œuf commun tout de suite (75), celles des 10 premiers niveaux
-- l'œuf doré du boss (1 200).
check(
	Levels.firstReward(2) >= Levels.skipCost(Levels.EGGS.Common.seconds) and firstTerritory >= Levels.skipCost(Levels.EGGS.Gold.seconds),
	`finir un œuf : un œuf commun ({Levels.skipCost(Levels.EGGS.Common.seconds)}) coûte moins que le niveau 2 n'en donne, l'œuf doré ({Levels.skipCost(Levels.EGGS.Gold.seconds)}) moins que les 10 premiers niveaux`
)
check(Levels.ENEMY.Normal.gold == 6 and Levels.ENEMY.Swarm.gold == 2 and Levels.ENEMY.Tank.gold == 18 and Levels.ENEMY.Boss.leak == 10, "or des monstres : 6 le fantassin, 2 l'écuyer, 18 le chevalier lourd")
check(Levels.RUSH_GOLD_PER_SECOND == nil and Levels.GROUP_PAUSE == nil, "plus de pauses entre des groupes ni de bouton « envoyer la suite »")

----------------------------------------------------------------------
-- 4) Entraînement : niveaux, dégâts, stats
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
local archer0, archer2, archer6 = Levels.towerStats("MachineGun", 1, 0), Levels.towerStats("MachineGun", 1, 2), Levels.towerStats("MachineGun", 1, 6)
-- Décision du propriétaire (04/10/2026) : « le terrain d'entraînement encore là mais pour du niveau dégâts » ; les
-- pouvoirs (feu, fragilité, carreau perçant) sont ceux des tours de palier 2.
check(near(archer0.damage, 3) and near(archer2.damage, 3.6) and near(archer6.damage, 4.8), "+10 % de dégâts par niveau d'entraînement (3 -> 3,6 -> 4,8)")
check(archer6.range == archer0.range and archer6.cooldown == archer0.cooldown, "l'entraînement ne donne que des dégâts (portée et vitesse inchangées)")
local noPowers = true
for _, towerType in IdleTowers.TIER1 do
	local trained = Levels.towerStats(towerType, 1, Levels.TRAINING.MAX_LEVEL)
	noPowers = noPowers and trained.fireRadius == nil and (trained.fragility or 0) == 0 and trained.kind ~= "Pierce"
end
check(noPowers, "tours de palier 1 : aucun pouvoir, même entraînées au maximum (ni feu, ni fragilité, ni carreau perçant)")
check(Levels.PERKS == nil and Levels.perkKeys == nil and Levels.perksBetween == nil, "plus d'améliorations d'entraînement")
-- Retour du propriétaire (02/10/2026) : « le ralentissement du givre est un peu cheaté » : -40 % dans les niveaux.
check(
	near(Levels.towerStats("Frost", 1, 0).slow, 0.4) and near(Levels.towerStats("Frost", 5, 6).slow, 0.4) and IdleTowers.stats("Frost", 1).slow == 0.6,
	"Totem : ralentit de 40 % dans les niveaux, quel que soit son entraînement (60 % sur la parcelle)"
)
check(near(Levels.towerStats("MachineGun", 3, 0).damage, 3 * IdleConfig.UPGRADE_DAMAGE ^ 2), "une amélioration en niveau : dégâts x1,35")
check(Levels.towerStats("MachineGun", 1, 2) == archer2 and IdleTowers.stats("MachineGun", 1).damage == 3, "towerStats garde ses tableaux et ne touche pas aux stats de la parcelle")
local decoded = Levels.decodeTraining(Levels.encodeTraining({ MachineGun = 2, Orbital = 6, Inconnue = 3 }))
check(decoded.MachineGun == 2 and decoded.Orbital == 6 and decoded.Frost == 0 and decoded.Inconnue == nil and next(Levels.decodeTraining(nil)) == nil, "encodeTraining / decodeTraining : aller-retour, tour inconnue ignorée")
check(Levels.playXp(true) == 8 and Levels.playXp(false, 0.5) == 1.5 and Levels.playXp(false, 0) == 0 and Levels.playXp(false, 7) == 3, "XP d'une partie : 8 gagnée, 3 x l'avancée perdue (0 si on quitte tout de suite)")

----------------------------------------------------------------------
-- 5) Données du joueur
----------------------------------------------------------------------
local fresh = Levels.defaultData()
check(fresh.best == 0 and fresh.coins == 0 and fresh.tutorial == 0 and fresh.towers.MachineGun == true and fresh.towers.Bomb == nil and #fresh.slots == 1 and fresh.slots[1].tower == "MachineGun" and table.concat(fresh.bar, ",") == "MachineGun", "nouveau joueur : l'Archer dans sa barre, un emplacement de camp, rien d'autre")
local archerOnly = Levels.cleanData({ best = 3, towers = { MachineGun = true, Bomb = true }, bar = { "MachineGun", "Bomb" } })
check(archerOnly.towers.Bomb == true and table.concat(Levels.ownedTowers(archerOnly), ",") == "MachineGun,Bomb" and archerOnly.best == 3, "ancienne sauvegarde (l'Archer et la Catapulte) : tout est gardé")
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
check(dirty.towers.Frost and dirty.towers.MachineGun and not dirty.towers.Dragon and not dirty.towers.Tesla, "sauvegarde abîmée : seules les vraies tours possédées restent (l'Archer toujours)")
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
	check(arena.folder:GetAttribute("Perks") == nil and arena.folder:GetAttribute("Training") == Levels.encodeTraining({}), "niveau 1 : l'entraînement publié (aucun)")
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
	check(ok == false and string.find(reason, "barre", 1, true) ~= nil, "pose refusée pour une tour qui n'est pas dans sa barre")
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
for level = 1, Levels.OPEN_COUNT do
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
	-- Les œufs (« LES ŒUFS ») : sans aucune chance (l'Archer et la Catapulte de l'œuf du niveau 1), le joueur très actif
	-- passe le 1er territoire ; ensuite il lui faut les tours des œufs. Un boss demande des tours de PALIER 2 (blocage
	-- voulu par le propriétaire : « que des niveaux tu sois vraiment bloqué, obligé de rechercher les tourelles »).
	check(Bot.play(1, { towers = { "MachineGun" }, training = 0 }).won, "l'Archer seul (offert) gagne le niveau 1")
	-- (le même joueur très actif, au même entraînement, sans les tours des œufs)
	local firstOk, laterLost, beaten = true, true, {}
	for level = 1, Levels.OPEN_COUNT do
		local result = Bot.play(level, { towers = Bot.NO_EGG_TOWERS, training = Bot.EXPECTED[level].training })
		if level <= Levels.TERRITORY_SIZE then
			firstOk = firstOk and result.won
		elseif result.won then
			laterLost = false
			table.insert(beaten, tostring(level))
		end
	end
	check(
		firstOk and laterLost,
		`sans chance aux œufs (l'Archer et la Catapulte) : les niveaux 1 à 10 se gagnent, les niveaux 11 à {Levels.OPEN_COUNT} non (gagnés quand même : {table.concat(beaten, ", ")})`
	)
	local function profileWithout(level: number, missing: { string })
		local profile = Bot.profile(level, "reference")
		local towers = {}
		for _, towerType in profile.towers do
			if not table.find(missing, towerType) then
				table.insert(towers, towerType)
			end
		end
		profile.towers = towers
		return profile
	end
	local boss20 = Bot.play(20, Bot.profile(20, "reference"))
	local boss20Without = Bot.play(20, profileWithout(20, { "MagmaCatapult" }))
	check(boss20.won and not boss20Without.won, `boss du niveau 20 au rythme demandé : {outcome(boss20)} avec la Catapulte de magma, {outcome(boss20Without)} sans tour de palier 2`)
	local boss30 = Bot.play(30, Bot.profile(30, "reference"))
	local boss30Without = Bot.play(30, profileWithout(30, { "StormArchmage" }))
	check(boss30.won and not boss30Without.won, `boss du niveau 30 : {outcome(boss30)} avec deux tours de palier 2, {outcome(boss30Without)} avec une seule`)
	local boss40 = Bot.play(40, Bot.profile(40, "reference"))
	local boss40Without = Bot.play(40, profileWithout(40, { "DragonBallista" }))
	check(boss40.won and not boss40Without.won, `boss du niveau 40 : {outcome(boss40)} avec trois tours de palier 2, {outcome(boss40Without)} avec deux`)
	local full = Bot.play(10, { towers = Bot.ALL_TOWERS, training = 6 })
	local lastFull = Bot.play(Levels.OPEN_COUNT, { towers = Bot.ALL_TOWERS, training = 6 })
	check(full.won and full.lives == 10 and lastFull.won and lastFull.lives == 10, `toutes les tours entraînées : les niveaux 10 et {Levels.OPEN_COUNT} gagnés sans perdre de vie ({outcome(lastFull)})`)
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
	-- Le feu au sol : l'Archer du rempart n'en a jamais (même entraîné au maximum) ; l'Archer enflammé, toujours.
	local plain = newGame(2, { "MachineGun", "FireArcher" }, Levels.TRAINING.MAX_LEVEL)
	local flaming = newGame(2, { "MachineGun", "FireArcher" }, 0)
	local most = {}
	for game, towerType in { [plain] = "MachineGun", [flaming] = "FireArcher" } do
		game.gold = 1e6
		game:placeTower(towerType, map.spots[1])
		most[game] = 0
		for _ = 1, 20 * 30 do
			game:simulate(1 / 30)
			most[game] = math.max(most[game], #game.firePatches)
		end
	end
	check(most[plain] == 0 and most[flaming] > 0, `feu au sol : aucun pour l'Archer entraîné au maximum ({most[plain]}), des zones pour l'Archer enflammé ({most[flaming]} à la fois au plus)`)
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
check(evolvingTowers, "chacune des 16 tours a ses 3 évolutions (ses étoiles d'entraînement)")
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
			and plot.folder:GetAttribute("Wave") == 1 and plot.folder:GetAttribute("Perks") == nil,
		"camp : la parcelle publie qu'elle est un camp (attributs Camp, State, OwnerUserId)"
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

	-- L'entraînement fait évoluer la tour : au niveau 2 (60 XP), l'Archer du camp est refait avec sa 1re évolution (1
	-- étoile, +20 % de dégâts ; plus de pouvoir : les flèches enflammées sont celles de l'Archer enflammé).
	local oldModel = archer.model
	levels.xp.MachineGun = 60
	local changed = camp:refresh(levels)
	local evolved = camp.slotTowers[1]
	check(
		changed and evolved ~= archer and evolved.stage == 1 and evolved.model:GetAttribute("Stars") == 1 and oldModel.destroyed == true
			and near(camp:statsOf(evolved).damage, 3 * 1.2),
		"camp : à 60 XP l'Archer évolue (1 étoile, +20 % de dégâts)"
	)
	check(camp:refresh(levels) == false and camp.slotTowers[1] == evolved, "camp : rien n'est refait quand rien ne change")
	-- +10 % de dégâts par niveau d'entraînement, sans refaire le modèle.
	levels.xp.MachineGun = 140
	check(camp:refresh(levels) == false and near(camp:statsOf(evolved).damage, 3 * 1.3), "camp : au niveau d'entraînement 3, +30 % de dégâts, même tour (pas de nouvelle évolution)")

	-- Emplacements : une 2e tour, puis l'emplacement 1 vidé.
	levels.towers.Bomb = true
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
check(Levels.TUTORIAL.EGG == 1 and Levels.TUTORIAL.DONE == 2 and Levels.defaultData().tutorial == 0, "tuto : un nouveau joueur est à l'étape 0 (1 = ouvrir l'œuf de catapulte, 2 = fini)")
check(
	Levels.cleanData(Levels.defaultData()).tutorial == 0 and Levels.cleanData({ best = 0, tutorial = 1 }).tutorial == 1 and Levels.cleanData({ best = 5, tutorial = 0 }).tutorial == 0
		and Levels.cleanData({ tutorial = 2 }).tutorial == 2,
	"tuto : l'étape sauvegardée est relue telle quelle"
)
check(
	Levels.cleanData({ best = 3 }).tutorial == Levels.TUTORIAL.DONE and Levels.cleanData({ best = 0 }).tutorial == 0
		and Levels.cleanData({ best = 0, towers = { Frost = true } }).tutorial == Levels.TUTORIAL.DONE,
	"tuto, sauvegarde d'avant le tuto : un niveau déjà gagné ou une tour en plus de l'Archer = tuto fini"
)
check(
	Levels.cleanData({ best = 4, tutorial = 99 }).tutorial == 2 and Levels.cleanData({ best = 4, tutorial = -3 }).tutorial == 0
		and Levels.cleanData({ best = 4, tutorial = "abc" }).tutorial == 2 and Levels.cleanData({ tutorial = 1.7 }).tutorial == 1,
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
	local same, bosses = #solo == #duo, 0
	for index, item in solo do
		local other = duo[index]
		-- (le boss et le colosse géant : PV moins multipliés, ils ne passent que dans un couloir)
		local boss = item.enemy == "Boss" or item.enemy == "Colossus"
		local scale = if boss then Levels.teamBossHealth(2) else Levels.teamHealth(2)
		bosses += if boss then 1 else 0
		if not other or other.at ~= item.at or other.enemy ~= item.enemy or other.reward ~= item.reward or math.abs(other.health - item.health * scale) > 0.06 then
			same = false
		end
	end
	check(
		same and bosses == 1 and Levels.teamBossHealth(1) == 1 and Levels.teamBossHealth(2) > 1 and Levels.teamBossHealth(2) < Levels.teamHealth(2),
		`équipe : le même flot de monstres (mêmes heures, mêmes types, même or), PV x teamHealth ; le boss x{Levels.teamBossHealth(2)} seulement à deux (il ne passe que dans un couloir)`
	)
end
do
	-- Une partie à deux : l'hôte (UserId 1) et un coéquipier (UserId 2, Archer entraîné au maximum, Totem acheté), sur la
	-- carte d'équipe du col (un couloir chacun).
	local definition = Levels.definition(12)
	local arena = { index = Levels.arenaIndex(2), folder = Env.fakeInstance("Arena"), cframe = Levels.arenaCFrame(2), map = Levels.mapFor(12, 2) }
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
			and folder:GetAttribute("Training_2") == Levels.encodeTraining(friend.training),
		"partie à deux : attributs de la zone (or et entraînement de chacun)"
	)
	check(game.queue[1].health == Levels.buildQueue(12, 2)[1].health, "partie à deux : les monstres d'une équipe de deux")
	local spots = Levels.geometry(arena.map).map.spots
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
----------------------------------------------------------------------
-- 11) Les cartes d'équipe. Demande du propriétaire (03/10/2026) : « chacun a son couloir qui se rejoint ensuite,
--     exemple à 2 ça fait une map un peu en Y, adapté à chaque monde ». Une carte par territoire et par nombre de
--     joueurs (Shared/TeamMaps.luau, écrit par tools/team-maps/generer.py), avec les mêmes règles que les cartes
--     seules ; le flot partagé entre les couloirs (Levels.buildQueue) ; chaque monstre suit son couloir (LevelGame).
----------------------------------------------------------------------
local RoadGeometry = require("./gen/shared/RoadGeometry")
local Enemies = require("./gen/shared/Enemies")
local MIN_GAP = 14 -- écart mini entre deux bouts de chemin qui ne se touchent pas (milieu à milieu)

local function same(a, b): boolean
	return (a - b).Magnitude < 1e-6
end
local function pointSegment(p, a, b): number
	local ab = b - a
	local t = math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
	return (p - (a + ab * t)).Magnitude
end
-- Écart entre deux tronçons droits (horizontaux ou verticaux) : 0 s'ils se coupent ou se chevauchent.
local function segmentGap(a1, b1, a2, b2): number
	local flat1, flat2 = a1.Z == b1.Z, a2.Z == b2.Z
	if flat1 ~= flat2 then
		local ha, hb = if flat1 then a1 else a2, if flat1 then b1 else b2
		local va, vb = if flat1 then a2 else a1, if flat1 then b2 else b1
		if va.X >= math.min(ha.X, hb.X) and va.X <= math.max(ha.X, hb.X) and ha.Z >= math.min(va.Z, vb.Z) and ha.Z <= math.max(va.Z, vb.Z) then
			return 0
		end
	end
	return math.min(pointSegment(a1, a2, b2), pointSegment(b1, a2, b2), pointSegment(a2, a1, b1), pointSegment(b2, a1, b1))
end

do
	local allOk, seen = true, {}
	for territory, soloName in Levels.TERRITORIES do
		local level = (territory - 1) * Levels.TERRITORY_SIZE + 1
		for size = 2, Levels.TEAM_MAX do
			local name = Levels.mapFor(level, size)
			local map = Levels.MAPS[name]
			local problems = {}
			local function problem(text: string)
				table.insert(problems, text)
			end
			if name ~= `{soloName}_{size}` or not map then
				allOk = false
				print(`  carte d'équipe absente : {soloName}_{size}`)
				continue
			end
			local geometry = Levels.geometry(name)
			local w, d = map.width, map.depth
			if #map.lanes ~= size or map.path ~= map.lanes[1] or #geometry.lanes ~= size then
				problem(`{#map.lanes} couloirs`)
			end
			local finish = map.lanes[1][#map.lanes[1]]
			local shortest, longest = math.huge, 0
			for index, lane in map.lanes do
				local entry, second = lane[1], lane[2]
				local inward = (entry.X == -w / 2 and second.X > entry.X)
					or (entry.X == w / 2 and second.X < entry.X)
					or (entry.Z == -d / 2 and second.Z > entry.Z)
					or (entry.Z == d / 2 and second.Z < entry.Z)
				if not inward then
					problem(`entrée du couloir {index} pas sur un bord`)
				end
				for i = 2, #lane do
					local delta = lane[i] - lane[i - 1]
					if not ((delta.X == 0 or delta.Z == 0) and delta.Magnitude >= Levels.PATH_WIDTH) then
						problem(`couloir {index} : tronçon {i - 1} pas droit ou trop court`)
					end
					if math.abs(lane[i].X) > w / 2 - 5 or math.abs(lane[i].Z) > d / 2 - 5 then
						problem(`couloir {index} : point {i} trop près du bord`)
					end
				end
				if not same(lane[#lane], finish) then
					problem(`couloir {index} : il ne finit pas au même endroit`)
				end
				-- Deux couloirs qui se rejoignent restent ensemble jusqu'au château.
				for otherIndex, other in map.lanes do
					if otherIndex ~= index then
						local meetI, meetJ = nil, nil
						for i, point in lane do
							for j, otherPoint in other do
								if same(point, otherPoint) then
									meetI, meetJ = i, j
									break
								end
							end
							if meetI then
								break
							end
						end
						local together = meetI ~= nil and #lane - meetI == #other - meetJ
						if together then
							for k = 0, #lane - meetI do
								together = together and same(lane[meetI + k], other[meetJ + k])
							end
						end
						if not together then
							problem(`couloirs {index} et {otherIndex} : ils ne restent pas ensemble après leur rencontre`)
						end
					end
				end
				shortest = math.min(shortest, geometry.lanes[index].PATH_LENGTH)
				longest = math.max(longest, geometry.lanes[index].PATH_LENGTH)
			end
			local lane1 = map.lanes[1]
			local direction = (lane1[#lane1] - lane1[#lane1 - 1]).Unit
			if not same(lane1[#lane1] + direction * 4, map.base) or math.abs(map.base.X) > w / 2 - 5 or math.abs(map.base.Z) > d / 2 - 5 then
				problem("château pas au bout du chemin, ou trop près du bord")
			end
			if longest > shortest * 1.15 or geometry.PATH_LENGTH ~= longest then
				problem(`couloirs de longueurs trop différentes ({math.floor(shortest)} à {math.floor(longest)})`)
			end
			local soloLength = Levels.geometry(soloName).PATH_LENGTH
			if longest < soloLength * 0.8 or longest > soloLength * 1.2 then
				problem(`longueur {math.floor(longest)} loin de la carte seule ({soloLength})`)
			end
			-- Écarts : deux bouts de chemin qui ne se touchent pas sont à au moins MIN_GAP studs (une tour tient entre
			-- les deux) ; deux bouts qui partent du même point ne repassent pas l'un sur l'autre.
			local segments = geometry.segments
			for i = 1, #segments do
				for j = i + 1, #segments do
					local s1, s2 = segments[i], segments[j]
					local shared = nil
					for _, p in { s1.a, s1.b } do
						for _, q in { s2.a, s2.b } do
							if same(p, q) then
								shared = p
							end
						end
					end
					if shared then
						local far1 = if same(s1.a, shared) then s1.b else s1.a
						local far2 = if same(s2.a, shared) then s2.b else s2.a
						if (far1 - shared).Unit:Dot((far2 - shared).Unit) > 0.999 then
							problem("deux bouts de chemin l'un sur l'autre")
						end
					elseif segmentGap(s1.a, s1.b, s2.a, s2.b) < MIN_GAP - 1e-6 then
						problem(`chemins trop proches ({math.floor(segmentGap(s1.a, s1.b, s2.a, s2.b) * 10) / 10} studs)`)
					end
				end
			end
			for i = 1, #map.lanes do
				for j = i + 1, #map.lanes do
					if (map.lanes[i][1] - map.lanes[j][1]).Magnitude < MIN_GAP then
						problem("deux entrées trop proches")
					end
				end
			end
			-- Les emplacements conseillés : tous posables, même tous occupés à la fois.
			local placed = {}
			for _, spot in map.spots do
				if Levels.checkPlacement(name, spot, placed) ~= true then
					problem("emplacement conseillé pas posable")
				end
				table.insert(placed, spot)
			end
			if #map.spots < 12 then
				problem(`{#map.spots} emplacements conseillés`)
			end
			-- Le chemin dessiné (LevelArena) : aucune dalle n'en recouvre une autre.
			local slabs = RoadGeometry.network(map.lanes, Levels.PATH_WIDTH)
			for i = 1, #slabs do
				for j = i + 1, #slabs do
					local a, b = slabs[i], slabs[j]
					local overlapX = math.min(a.center.X + a.size.X / 2, b.center.X + b.size.X / 2) - math.max(a.center.X - a.size.X / 2, b.center.X - b.size.X / 2)
					local overlapZ = math.min(a.center.Z + a.size.Z / 2, b.center.Z + b.size.Z / 2) - math.max(a.center.Z - a.size.Z / 2, b.center.Z - b.size.Z / 2)
					if overlapX > 1e-3 and overlapZ > 1e-3 then
						problem("deux dalles du chemin se recouvrent")
					end
				end
			end
			table.insert(seen, `{name} {math.floor(longest + 0.5)}`)
			if #problems > 0 then
				allOk = false
				print(`  {name} : {table.concat(problems, " ; ")}`)
			end
		end
	end
	check(
		allOk and #seen == #Levels.TERRITORIES * (Levels.TEAM_MAX - 1),
		`{#seen} cartes d'équipe (une par territoire à 2, 3 et 4 joueurs), mêmes règles que les cartes seules (tronçons droits, entrée sur un bord, couloirs qui restent ensemble après leur rencontre, à {MIN_GAP} studs l'un de l'autre, même château, longueurs proches de la carte seule, emplacements posables, dalles sans recouvrement) : {table.concat(seen, ", ")}`
	)
end
-- Le flot partagé entre les couloirs : chacun son tour, type par type.
do
	local fair, onlyOne = true, true
	for _, size in { 2, 3, 4 } do
		for _, level in { 10, 35, 100 } do
			local counts = {}
			for _, item in Levels.buildQueue(level, size) do
				if item.lane < 1 or item.lane > size then
					fair = false
				end
				counts[item.enemy] = counts[item.enemy] or {}
				counts[item.enemy][item.lane] = (counts[item.enemy][item.lane] or 0) + 1
			end
			for _, byLane in counts do
				local low, high = math.huge, 0
				for lane = 1, size do
					low = math.min(low, byLane[lane] or 0)
					high = math.max(high, byLane[lane] or 0)
				end
				fair = fair and high - low <= 1
			end
		end
	end
	for _, item in Levels.buildQueue(35) do
		onlyOne = onlyOne and item.lane == 1
	end
	local function bossLane(level: number, size: number): number?
		for _, item in Levels.buildQueue(level, size) do
			if item.enemy == "Boss" then
				return item.lane
			end
		end
		return nil
	end
	check(
		fair and onlyOne and bossLane(10, 2) == 1 and bossLane(20, 2) == 2 and bossLane(30, 2) == 1 and bossLane(30, 3) == 3 and bossLane(40, 4) == 4 and bossLane(50, 4) == 1,
		"en équipe, le flot est partagé entre les couloirs chacun son tour, type par type (même nombre de chaque type à 1 près) ; seul, tout passe par le seul couloir ; le boss change de couloir d'un territoire à l'autre"
	)
	-- Idée du propriétaire (04/10/2026) : « un gros colosse plus fort qui apparaît à un couloir aléatoire », « pareil
	-- pour les boss ». Avec le Random de la partie (LevelGame), chaque gros monstre (colosse, colosse géant, boss) sort
	-- dans un couloir tiré au sort ; les autres gardent le partage chacun son tour ; la file reste la même sinon.
	local bossLanes, colossusLanes, giantLanes, othersSame, balanced = {}, {}, {}, true, true
	for seed = 1, 16 do
		local random = Env.Random.new(seed)
		for _, size in { 3, 4 } do
			local bigs = {}
			for _, item in Levels.buildQueue(40, size, random) do
				if item.enemy == "Giant" or item.enemy == "Boss" then
					bigs[item.lane] = (bigs[item.lane] or 0) + 1
				end
			end
			local low, high = math.huge, 0
			for lane = 1, size do
				low, high = math.min(low, bigs[lane] or 0), math.max(high, bigs[lane] or 0)
			end
			balanced = balanced and high - low <= 1
		end
		for _, level in { 10, 25 } do
			local plain = Levels.buildQueue(level, 2)
			for index, item in Levels.buildQueue(level, 2, random) do
				local other = plain[index]
				othersSame = othersSame and other.enemy == item.enemy and other.at == item.at and other.health == item.health
				if item.enemy == "Boss" then
					bossLanes[item.lane] = true
				elseif item.enemy == "Colossus" then
					colossusLanes[item.lane] = true
				elseif item.enemy == "Giant" then
					giantLanes[item.lane] = true
				else
					othersSame = othersSame and other.lane == item.lane
				end
			end
		end
	end
	local soloSame = true
	for _, item in Levels.buildQueue(25, 1, Env.Random.new(3)) do
		soloSame = soloSame and item.lane == 1
	end
	check(
		othersSame and soloSame and balanced and bossLanes[1] and bossLanes[2] and colossusLanes[1] and colossusLanes[2] and giantLanes[1] and giantLanes[2],
		"en équipe, le boss, le colosse géant et les colosses sortent dans un couloir tiré au sort à chaque partie (les deux couloirs vus en 16 parties), chacun son tour dans un ordre au hasard (niveau 40 à 3 et 4 : jamais deux de plus dans un couloir que dans un autre) ; les autres monstres, les heures et les PV ne changent pas ; seul : toujours le seul couloir"
	)
	-- Les cartes d'équipe plus dures (mesuré) : leurs monstres ont un peu moins de PV.
	local factorsOk = true
	for name, factor in Levels.TEAM_MAP_HEALTH do
		factorsOk = factorsOk and Levels.MAPS[name] ~= nil and #Levels.MAPS[name].lanes > 1 and factor >= 0.5 and factor < 1
	end
	local passTeam, passSolo = Levels.buildQueue(12, 2)[1], Levels.buildQueue(12)[1]
	check(
		factorsOk and math.abs(passTeam.health - passSolo.health * Levels.teamHealth(2) * Levels.TEAM_MAP_HEALTH.Pass_2) <= 0.06
			and Levels.buildQueue(3, 2)[1].health == math.floor(Levels.buildQueue(3)[1].health * Levels.teamHealth(2) * 10 + 0.5) / 10,
		`cartes d'équipe plus dures : PV x{Levels.TEAM_MAP_HEALTH.Pass_2} en plus sur le col à deux ; rien sur les autres (la vallée à deux)`
	)
end
-- Le moteur : chaque monstre suit son couloir, un monstre au bout du sien coûte des vies, le paquet réseau dit son
-- couloir, « le plus avancé » se compare d'un couloir à l'autre.
do
	local mapName = Levels.mapFor(12, 2)
	local geometry = Levels.geometry(mapName)
	local arena = { index = Levels.arenaIndex(3), folder = Env.fakeInstance("Arena"), cframe = Levels.arenaCFrame(3), map = mapName }
	local game = LevelGame.new(arena, { UserId = 1, Parent = {} }, {
		level = 12,
		unlocked = { MachineGun = true },
		training = {},
		team = { { player = { UserId = 2, Parent = {} }, unlocked = { MachineGun = true }, training = {} } },
	})
	local seenLanes = {}
	for _ = 1, 900 do
		game:simulate(1 / 30)
		for _, enemy in game.enemies do
			seenLanes[enemy.lane] = true
		end
		if seenLanes[1] and seenLanes[2] and #game.enemies >= 3 then
			break
		end
	end
	local onLane = #game.enemies > 0
	for _, enemy in game.enemies do
		local expected = game.cframe:PointToWorldSpace((geometry.lanes[enemy.lane].pointAt(enemy.distance)))
		onLane = onLane and (expected - enemy.position).Magnitude < 1e-3
	end
	check(seenLanes[1] and seenLanes[2] and onLane and not seenLanes[3], `carte d'équipe à deux ({mapName}) : des monstres dans les deux couloirs, chacun sur le sien`)
	check(
		same(game:pathPoint(0, 2), game.cframe:PointToWorldSpace(geometry.map.lanes[2][1]))
			and same(game:pathPoint(0), game.cframe:PointToWorldSpace(geometry.map.lanes[1][1]))
			and same(game:pathPoint(1e9, 2), game:pathPoint(1e9, 1)),
		"pathPoint : le départ du couloir demandé (le premier s'il est absent), le même château au bout"
	)
	local packet, count = game:buildSyncPacket()
	local packetOk = packet ~= nil and count == #game.enemies
	for i = 0, count - 1 do
		local byte = buffer.readu8(packet, i * 11 + 4) -- (11 octets par monstre : Combat.luau, ENEMY_BYTES)
		local enemy = game.enemies[i + 1]
		packetOk = packetOk and byte % Enemies.LANE_STEP == enemy.typeIndex and byte // Enemies.LANE_STEP + 1 == enemy.lane
	end
	check(packetOk, "paquet PlotSync : l'octet du type porte aussi le couloir du monstre")
	local walker = nil
	for _, enemy in game.enemies do
		if enemy.lane == 2 then
			walker = enemy
		end
	end
	local livesBefore = game.lives
	if walker then
		walker.distance = geometry.lanes[2].PATH_LENGTH - 0.01
	end
	game:simulate(1 / 30)
	check(walker ~= nil and walker.dead and game.lives < livesBefore, "un monstre au bout de SON couloir arrive au château : il coûte des vies")
	game:destroy()

	-- « Le plus avancé » : celui qui est le plus près du château, d'un couloir à l'autre (couloirs de longueurs
	-- différentes : le col à trois, 250 / 246 / 250 studs).
	local arena3 = { index = Levels.arenaIndex(4), folder = Env.fakeInstance("Arena"), cframe = Levels.arenaCFrame(4), map = "Pass_3" }
	local game3 = LevelGame.new(arena3, { UserId = 1, Parent = {} }, { level = 12, unlocked = { MachineGun = true }, training = {} })
	game3.gold = 1000
	local _, _, tower = game3:placeTower("MachineGun", Levels.MAPS.Pass_3.spots[1])
	game3:spawnEnemy({ enemy = "Normal", health = 50, reward = 0, lane = 1 })
	game3:spawnEnemy({ enemy = "Normal", health = 50, reward = 0, lane = 2 })
	local first, second = game3.enemies[1], game3.enemies[2]
	first.distance, second.distance = 100, 97
	first.position, second.position = tower.position, tower.position
	local offset = Levels.geometry("Pass_3").PATH_LENGTH - Levels.geometry("Pass_3").lanes[2].PATH_LENGTH
	check(
		offset > 3 and second.laneOffset == offset and first.laneOffset == 0 and game3:pickTarget(tower, game3:statsOf(tower), false) == second,
		`« le plus avancé » se compare d'un couloir à l'autre : à 97 studs d'un couloir plus court de {offset} studs, il est plus près du château qu'à 100 studs d'un autre`
	)
	game3:destroy()
end

----------------------------------------------------------------------
-- 12) Les amis. Demande du propriétaire (04/10/2026) : « quand quelqu'un a un ami qui se connecte, ça envoie une
--     notif pour l'inviter, pour un bonus de pièces » ; « oui 1 2 3 ». Les règles (Levels) : bonus d'ami sur le
--     serveur, récompenses d'invitation (une fois par ami), données.
----------------------------------------------------------------------
do
	local friend = Levels.FRIENDS
	check(
		friend.INVITE_REWARD == 200 and friend.COIN_BONUS == 0.1 and Levels.bonusReward(1000, 1, false) == 1000 and Levels.bonusReward(1000, 1, true) == 1100
			and Levels.bonusReward(1000, 2, true) == 1200 and Levels.bonusReward(1000, 4, false) == Levels.teamReward(1000, 4) and Levels.bonusReward(80, nil, true) == 88,
		"amis : +10 % de pièces avec un ami sur le serveur, en plus du bonus d'équipe (1 000 -> 1 100 seul, 1 200 à deux) ; 200 pièces par ami invité"
	)
	local newcomer = Levels.defaultData()
	local first = Levels.claimArrival(newcomer, 50, 7)
	local again = Levels.claimArrival(newcomer, 50, 8)
	local selfInvite = Levels.claimArrival(Levels.defaultData(), 50, 50)
	check(
		first and not again and not selfInvite and newcomer.invitedBy == 7 and newcomer.coins == friend.INVITE_REWARD and not Levels.claimArrival(Levels.defaultData(), 50, 0),
		"amis : un joueur venu grâce à une invitation reçoit sa récompense une seule fois (jamais en s'invitant lui-même)"
	)
	local inviter = Levels.defaultData()
	local given = 0
	for friendId = 1, friend.INVITE_MAX + 3 do
		if Levels.claimInvite(inviter, 99, friendId) then
			given += 1
		end
	end
	check(
		given == friend.INVITE_MAX and inviter.coins == friend.INVITE_MAX * friend.INVITE_REWARD and not Levels.claimInvite(Levels.defaultData(), 99, 99)
			and (function()
				local twice = Levels.defaultData()
				return Levels.claimInvite(twice, 99, 5) and not Levels.claimInvite(twice, 99, 5) and twice.coins == friend.INVITE_REWARD
			end)(),
		`amis : celui qui invite est récompensé une fois par ami venu, {friend.INVITE_MAX} amis au plus`
	)
	local cleaned = Levels.cleanData({ invitedBy = 42, invited = { 3, 3, "x", 0, 9 } })
	local fresh = Levels.cleanData({})
	check(
		cleaned.invitedBy == 42 and #cleaned.invited == 2 and cleaned.invited[1] == 3 and cleaned.invited[2] == 9 and fresh.invitedBy == 0 and #fresh.invited == 0,
		"amis : données sauvegardées propres (qui l'a invité, amis venus grâce à lui sans doublon ; anciennes sauvegardes : rien)"
	)
end

----------------------------------------------------------------------
-- 13) Les œufs. Idée du propriétaire (04/10/2026) : « des œufs de tourelle quand tu finis les niveaux en gagnant,
--     et les mettre dans des générateurs qui donnent un temps ». Les règles (Levels) : œuf gagné, réserve,
--     chances, tour sortie (nouvelle ou doublon), finir tout de suite, données.
----------------------------------------------------------------------
do
	check(
		Levels.eggFor(2, true) == "Common" and Levels.eggFor(5, true) == "Rare" and Levels.eggFor(10, true) == "Gold"
			and Levels.eggFor(1, false) == "Common" and Levels.eggFor(5, false) == "Common" and Levels.eggFor(10, false) == "Rare",
		"œufs : première victoire = commun, rare au mini-boss, doré au boss (niveau 1 : l'œuf de catapulte) ; en rejouant = commun, rare au boss"
	)
	local reserve = Levels.defaultData()
	local kept = 0
	for _ = 1, Levels.EGG_MAX + 5 do
		if Levels.addEgg(reserve, "Common") then
			kept += 1
		end
	end
	check(kept == Levels.EGG_MAX and Levels.eggCount(reserve) == Levels.EGG_MAX and not Levels.addEgg(reserve, "Gold"), `œufs : {Levels.EGG_MAX} au plus en réserve, les suivants sont perdus`)
	local chancesOk, seen = true, {}
	for _, eggType in Levels.EGG_ORDER do
		local sum, rarities = 0, {}
		for _, entry in Levels.eggChances(eggType) do
			sum += entry.chance
			rarities[IdleTowers.Defs[entry.tower].rarity] = true
		end
		chancesOk = chancesOk and math.abs(sum - 1) < 1e-9 and Levels.EGGS[eggType].seconds > 0
		table.insert(seen, `{eggType} {#Levels.eggChances(eggType)} tours`)
		if eggType == "Common" then
			chancesOk = chancesOk and not rarities.Legendary
		elseif eggType == "Gold" then
			chancesOk = chancesOk and not rarities.Common and rarities.Legendary == true
		end
	end
	local first, last = Levels.rollEgg("Common", 0), Levels.rollEgg("Gold", 0.99999)
	check(
		chancesOk and IdleTowers.Defs[first].rarity == "Common" and IdleTowers.Defs[last].rarity == "Legendary"
			and Levels.EGGS.Common.seconds < Levels.EGGS.Rare.seconds and Levels.EGGS.Rare.seconds < Levels.EGGS.Gold.seconds,
		`œufs : chances qui font 100 % (un œuf commun ne donne jamais de légendaire, un doré jamais de commune), du plus court au plus long : {table.concat(seen, ", ")}`
	)
	local hatcher = Levels.defaultData()
	local isNew, xp = Levels.hatchTower(hatcher, "Laser")
	local again, xpAgain = Levels.hatchTower(hatcher, "Laser")
	local _, startXp = Levels.hatchTower(hatcher, "MachineGun")
	check(
		isNew and xp == 0 and hatcher.towers.Laser == true and table.find(hatcher.bar, "Laser") ~= nil and not again
			and xpAgain == Levels.DUPLICATE_XP.Epic and hatcher.xp.Laser == Levels.DUPLICATE_XP.Epic and startXp == Levels.DUPLICATE_XP.Common,
		"œufs : une tour nouvelle est au joueur (dans sa barre) ; un doublon donne de l'XP d'entraînement selon sa rareté"
	)
	check(Levels.skipCost(0) == 0 and Levels.skipCost(-5) == 0 and Levels.skipCost(15 * 60) == 15 * Levels.SKIP_COINS_PER_MINUTE and Levels.skipCost(61) == 2 * Levels.SKIP_COINS_PER_MINUTE, "œufs : finir tout de suite coûte des pièces par minute qui reste (minute entamée comptée)")
	local cleaned = Levels.cleanData({
		eggs = { Common = 3, Rare = -2, Gold = "x", Fake = 9 },
		hatchers = { { egg = "Rare", readyAt = 123 }, { egg = "Nope", readyAt = 9 }, { egg = "", readyAt = 5 }, { egg = "Gold", readyAt = 1 } },
	})
	local fresh = Levels.defaultData()
	check(
		cleaned.eggs.Common == 3 and cleaned.eggs.Rare == nil and cleaned.eggs.Gold == nil and cleaned.eggs.Fake == nil and #cleaned.hatchers == #Levels.HATCHER_COST
			and cleaned.hatchers[1].egg == "Rare" and cleaned.hatchers[1].readyAt == 123 and cleaned.hatchers[2].egg == "" and cleaned.hatchers[2].readyAt == 0
			and #fresh.hatchers == 1 and fresh.hatchers[1].egg == "" and Levels.HATCHER_COST[1] == 0,
		"œufs : données propres (réserve, couveuses : la 1re offerte, 3 au plus ; un œuf inconnu est enlevé)"
	)
end

----------------------------------------------------------------------
-- 14) Les tours de palier 2. Demande du propriétaire (04/10/2026) : « archer, archer enflammé, déjà pas les mêmes »,
--     « la première tour quasi obsolète après, une claire différence de niveau entre chaque tour de palier ». Elles
--     ne sortent que des œufs ; la barre rapide garde 8 tours (les autres en réserve).
----------------------------------------------------------------------
do
	local firstEight = table.concat(table.move(IdleTowers.ORDER, 1, 8, 1, {}), ",")
	local lastEight = table.concat(table.move(IdleTowers.ORDER, 9, 16, 1, {}), ",")
	check(
		#IdleTowers.ORDER == 16 and firstEight == "MachineGun,Frost,Bomb,Tesla,Rocket,Laser,Chain,Orbital"
			and firstEight == table.concat(IdleTowers.TIER1, ",") and lastEight == table.concat(IdleTowers.TIER2, ","),
		"16 tours : les 8 de palier 1 d'abord (mêmes numéros qu'avant dans les paquets), puis leurs 8 versions de palier 2"
	)
	local pairsOk, bases = true, {}
	for index, towerType in IdleTowers.TIER2 do
		local def, base = IdleTowers.Defs[towerType], IdleTowers.TIER1[index]
		pairsOk = pairsOk and def.base == base and IdleTowers.baseOf(towerType) == base and IdleTowers.upgradeOf(base) == towerType
			and IdleTowers.tierOf(towerType) == 2 and IdleTowers.tierOf(base) == 1 and IdleTowers.baseOf(base) == base
			and def.rarity == IdleTowers.Defs[base].rarity and not bases[base]
			-- (même façon de toucher, sauf le carreau qui transperce de la Baliste du dragon : son pouvoir de palier 2)
			and (def.kind == IdleTowers.Defs[base].kind or (towerType == "DragonBallista" and def.kind == "Pierce"))
			and string.match(towerType, "^%a+$") ~= nil -- (Levels.decodeTraining ne lit que des lettres)
		bases[base] = true
	end
	check(pairsOk and IdleTowers.upgradeOf("FireArcher") == nil, "palier 2 : chaque tour a sa tour de base (dans le même ordre), sa rareté et sa façon de toucher (la Baliste du dragon transperce)")
	local priceOk = true
	for _, towerType in IdleTowers.TIER2 do
		local base = IdleTowers.baseOf(towerType)
		priceOk = priceOk and Levels.TOWER_COST[towerType] == 2 * Levels.TOWER_COST[base] and Levels.maxCopies(towerType) == Levels.maxCopies(base)
	end
	check(priceOk, "palier 2 : deux fois le prix en or de sa tour de base, même limite par niveau")
	-- La claire différence : sans entraînement, au moins 2,2 fois les dégâts par seconde de sa tour de base, et au moins
	-- 1,6 fois ceux de sa tour de base entraînée au maximum (toutes ses évolutions).
	local stronger, ratios = true, {}
	for _, towerType in IdleTowers.TIER2 do
		local base = IdleTowers.baseOf(towerType)
		local mine = IdleTowers.dpsOf(Levels.towerStats(towerType, 1, 0))
		local plain = IdleTowers.dpsOf(Levels.towerStats(base, 1, 0))
		local trained = IdleTowers.dpsOf(Levels.towerStats(base, 1, Levels.TRAINING.MAX_LEVEL))
		stronger = stronger and mine >= 2.2 * plain and mine >= 1.6 * trained
		table.insert(ratios, string.format("%s x%.1f (x%.1f)", towerType, mine / plain, mine / trained))
	end
	check(stronger, `palier 2 : bien plus fort que sa tour de base, même entraînée au maximum : {table.concat(ratios, ", ")}`)
	local blizzard, frost = Levels.towerStats("BlizzardTotem", 1, 0), Levels.towerStats("Frost", 1, Levels.TRAINING.MAX_LEVEL)
	local dragon = Levels.towerStats("DragonBallista", 1, 0)
	check(
		Levels.towerStats("FireArcher", 1, 0).fireRadius ~= nil and Levels.towerStats("MagmaCatapult", 1, 0).fireRadius ~= nil
			and blizzard.fragility > (frost.fragility or 0) and blizzard.slow >= frost.slow and dragon.kind == "Pierce" and dragon.pierceMax == 4
			and dragon.fireRadius ~= nil,
		"palier 2 : les pouvoirs sont là sans entraînement (feu, fragilité, carreau qui transperce 4 monstres)"
	)
	check(
		blizzard.family == "Frost" and Levels.towerStats("StormArchmage", 1, 0).family == "Tesla" and Levels.towerStats("Frost", 1, 0).family == "Frost",
		"palier 2 : ses contrôles comptent comme ceux de sa tour de base (même famille)"
	)

	-- Les œufs donnent toutes les tours : chacune des 16 peut sortir ; la part des tours de palier 2 : aucune dans un
	-- œuf commun, 25 % dans un œuf rare, 75 % dans un œuf doré.
	local tier2Share, obtainable = {}, {}
	for _, eggType in Levels.EGG_ORDER do
		tier2Share[eggType] = 0
		for _, entry in Levels.eggChances(eggType) do
			if IdleTowers.tierOf(entry.tower) == 2 then
				tier2Share[eggType] += entry.chance
			end
			obtainable[entry.tower] = true
		end
	end
	local everyOne = true
	for _, towerType in IdleTowers.ORDER do
		everyOne = everyOne and obtainable[towerType] == true
	end
	check(
		everyOne and tier2Share.Common == 0 and near(tier2Share.Rare, 0.25) and near(tier2Share.Gold, 0.75),
		`œufs : chacune des 16 tours peut sortir ; tours de palier 2 : {math.floor(tier2Share.Common * 100 + 0.5)} % d'un œuf commun, {math.floor(tier2Share.Rare * 100 + 0.5)} % d'un rare, {math.floor(tier2Share.Gold * 100 + 0.5)} % d'un doré`
	)
	local starter = Levels.eggChances("Starter")
	check(#starter == 1 and starter[1].tower == "Bomb" and starter[1].chance == 1 and Levels.rollEgg("Starter", 0.99) == "Bomb", "œuf de catapulte : la Catapulte à coup sûr")

	-- Barre rapide (Levels.BAR_MAX = 8) : une tour achetée arrive à la fin ; une tour de palier 2 prend la place de sa
	-- tour de base, qui passe en réserve quand la barre est pleine.
	local data = Levels.defaultData()
	for _, towerType in IdleTowers.TIER1 do
		if not data.towers[towerType] then
			Levels.addTower(data, towerType)
		end
	end
	check(Levels.BAR_MAX == 8 and table.concat(Levels.ownedTowers(data), ",") == "MachineGun,Frost,Bomb,Tesla,Rocket,Laser,Chain,Orbital", "barre : une nouvelle tour arrive à la fin de la barre")
	local isNew = Levels.hatchTower(data, "MagmaCatapult")
	local list, bar = Levels.ownedTowers(data), Levels.barTowers(data)
	check(
		isNew and #list == 9 and list[3] == "MagmaCatapult" and list[9] == "Bomb" and bar.MagmaCatapult and not bar.Bomb and bar.MachineGun,
		"barre : la Catapulte de magma prend la place de la Catapulte, qui passe en réserve (barre pleine)"
	)
	local cleaned = Levels.cleanData(data)
	check(table.concat(Levels.ownedTowers(cleaned), ",") == table.concat(list, ",") and cleaned.towers.MagmaCatapult == true, "barre : l'ordre et les tours de palier 2 restent après une sauvegarde")
	local small = Levels.defaultData()
	Levels.hatchTower(small, "VoidSorcerer")
	check(table.concat(Levels.ownedTowers(small), ",") == "MachineGun,VoidSorcerer", "barre : sans sa tour de base, la tour de palier 2 arrive à la fin de la barre")
	local full = Levels.defaultData()
	for _, towerType in { "Bomb", "Frost", "Tesla", "Rocket", "Chain", "Orbital" } do
		Levels.addTower(full, towerType)
	end
	Levels.hatchTower(full, "FireArcher")
	Levels.hatchTower(full, "VoidSorcerer")
	local fullList, fullBar = Levels.ownedTowers(full), Levels.barTowers(full)
	check(
		fullList[1] == "FireArcher" and fullList[8] == "VoidSorcerer" and fullList[9] == "MachineGun" and fullBar.VoidSorcerer and not fullBar.MachineGun,
		"barre pleine : la nouvelle tour prend la dernière place de la barre (l'Archer, remplacé par l'Archer enflammé, est en réserve)"
	)

	-- Dans un niveau : une tour en réserve ne se pose pas ; une tour de palier 2 se pose, tire avec ses pouvoirs.
	local definition = Levels.definition(3)
	local arena = { index = Levels.arenaIndex(1), folder = Env.fakeInstance("Arena"), cframe = Levels.arenaCFrame(1), map = definition.map }
	local game = LevelGame.new(arena, { UserId = 1, Parent = {} }, { level = 3, unlocked = Levels.barTowers(data), training = Levels.trainingLevels(data) })
	game.gold = 1e6
	game.lives = math.huge
	local reserveOk = game:placeTower("Bomb", map.spots[1])
	local magmaOk, _, magma = game:placeTower("MagmaCatapult", map.spots[1])
	check(not reserveOk and magmaOk and magma.model:GetAttribute("TowerType") == "MagmaCatapult" and game.gold == 1e6 - 90, "niveau : la Catapulte en réserve ne se pose pas, la Catapulte de magma se pose (90 or)")
	local burnt = 0
	for _ = 1, 25 * 30 do
		game:simulate(1 / 30)
		burnt = math.max(burnt, #game.firePatches)
	end
	check(burnt > 0 and game.kills > 0, `niveau : la Catapulte de magma tue et laisse du feu au sol sans entraînement ({game.kills} monstres, {burnt} zones de feu à la fois)`)
end

do
	-- Contrôles d'une famille : le Totem du blizzard prolonge le gel d'un Totem de givre et garde le plus fort des
	-- deux ralentissements (jamais plus) ; la fatigue du Mage vaut pour l'Archimage.
	local game = newGame(3, { "MachineGun", "Bomb", "Frost", "BlizzardTotem", "Tesla", "StormArchmage" })
	game.gold = 1e6
	game.lives = math.huge
	local frostOk = game:placeTower("Frost", Vector3.new(-45, 0, -8))
	local blizzardOk = game:placeTower("BlizzardTotem", Vector3.new(-45, 0, 8))
	local strongest, frozen, family = 0, 0, true
	for _ = 1, 20 * 30 do
		game:simulate(1 / 30)
		for _, enemy in game.enemies do
			if not enemy.dead and game.clock < enemy.controlUntil then
				frozen += 1
				family = family and enemy.controlSource == "Frost"
				strongest = math.max(strongest, enemy.controlFactor)
			end
		end
	end
	check(frostOk and blizzardOk and frozen > 0 and family and near(strongest, 0.5),`Totem de givre + Totem du blizzard : un seul ralentissement, le plus fort ({math.floor(strongest * 100 + 0.5)} %)`)
end

-- Équipes de joueurs simulés, avec les PV d'équipe : les joueurs de référence gagnent (au moins 5 vies), comme seuls.
for _, size in { 2, 3, 4 } do
	for _, level in { 10, 25, Levels.OPEN_COUNT } do
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

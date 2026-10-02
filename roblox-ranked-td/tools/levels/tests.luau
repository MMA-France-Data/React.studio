-- Vérifications des règles des NIVEAUX sans ouvrir Studio (run.ps1 -Tests) : les chiffres de Shared/Levels.luau et
-- le VRAI moteur d'un niveau (LevelGame.luau, qui hérite du vrai PlotGame.luau), avec les imitations de Roblox de
-- env.luau. Sortie 1 si un test rate.
local Env = require("./env")
local Levels = require("./gen/shared/Levels")
local IdleConfig = require("./gen/shared/IdleConfig")
local IdleTowers = require("./gen/shared/IdleTowers")
local LevelGame = require("./gen/server/Hub/LevelGame")
local Shim = require("../balance/idle/shim")
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
-- 1) Les niveaux : 10 niveaux, mini-boss au 5, boss au 10, 2 à 3 minutes, un FLOT CONTINU qui monte
----------------------------------------------------------------------
check(Levels.COUNT == 10 and #Levels.DEFINITIONS == 10, `10 niveaux dans le prototype ({Levels.COUNT}, {#Levels.DEFINITIONS} fiches)`)
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
	check(definition.miniBoss == (level == 5) and definition.boss == (level == 10), `niveau {level} : mini-boss {tostring(definition.miniBoss)}, boss {tostring(definition.boss)}`)
	if level == 5 then
		check(types.Giant == 1 and not types.Boss, "niveau 5 : un mini-boss (chevalier colossal) dans le flot, pas de boss")
	elseif level == 10 then
		check(types.Boss == 1 and queue[#queue].enemy == "Boss", "niveau 10 : le boss ferme le flot")
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
check(not pcall(Levels.definition, 11) and not pcall(Levels.buildQueue, 0), "un niveau inconnu (0, 11) est refusé")

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

----------------------------------------------------------------------
-- 3) Récompenses, prix, limites, or des monstres
----------------------------------------------------------------------
check(Levels.firstReward(1) == 80 and Levels.firstReward(4) == 140 and Levels.firstReward(5) == 300 and Levels.firstReward(10) == 600, "première victoire : 80 au niveau 1, 140 au 4, 300 au mini-boss, 600 au boss")
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
-- basiques mais les légendaires surtout, car au niveau 10 tu les as en gros ? ». Les 10 niveaux réussis une fois
-- paient le Totem, le Mage et la Baliste, pas plus : les légendaires demandent de rejouer longtemps.
local allFirst, previousPrice, rising = 0, 0, true
for level = 1, Levels.COUNT do
	allFirst += Levels.firstReward(level)
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
	allFirst == 2180 and allFirst >= Levels.SHOP.Frost + Levels.SHOP.Tesla + Levels.SHOP.Rocket and allFirst < Levels.SHOP.Frost + Levels.SHOP.Tesla + Levels.SHOP.Laser,
	`les 10 niveaux réussis une fois ({allFirst} pièces) paient le Totem, le Mage et la Baliste, mais pas le Sorcier`
)
local replay10 = Levels.reward(Levels.COUNT, true, false)
check(
	IdleTowers.Defs.Chain.rarity == "Legendary" and IdleTowers.Defs.Orbital.rarity == "Legendary" and Levels.SHOP.Chain >= 30 * replay10
		and Levels.SHOP.Orbital >= 60 * replay10,
	`tours légendaires : l'Oracle vaut {math.ceil(Levels.SHOP.Chain / replay10)} parties rejouées au niveau 10, le Trébuchet {math.ceil(Levels.SHOP.Orbital / replay10)} (au moins 30 et 60)`
)
check(Levels.ENEMY.Normal.gold == 6 and Levels.ENEMY.Swarm.gold == 2 and Levels.ENEMY.Tank.gold == 18 and Levels.ENEMY.Boss.leak == 10, "or des monstres : 6 le fantassin, 2 l'écuyer, 18 le chevalier lourd")
check(Levels.RUSH_GOLD_PER_SECOND == nil and Levels.GROUP_PAUSE == nil, "plus de pauses entre des groupes ni de bouton « envoyer la suite »")

----------------------------------------------------------------------
-- 4) Entraînement : niveaux, améliorations débloquées, stats
----------------------------------------------------------------------
check(Levels.trainingLevel(0) == 0 and Levels.trainingLevel(19.9) == 0 and Levels.trainingLevel(20) == 1 and Levels.trainingLevel(60) == 2 and Levels.trainingLevel(1e9) == 6 and Levels.trainingLevel("abc") == 0, "niveaux d'entraînement : 20 XP = 1, 60 = 2, jamais plus de 6")
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
check(fresh.best == 0 and fresh.coins == 0 and fresh.towers.MachineGun == true and fresh.towers.Bomb == true and fresh.towers.Frost == nil and #fresh.slots == 1 and fresh.slots[1].tower == "MachineGun" and table.concat(fresh.bar, ",") == "MachineGun,Bomb", "nouveau joueur : l'Archer et la Catapulte dans sa barre, un emplacement de camp, rien d'autre")
local archerOnly = Levels.cleanData({ best = 3, towers = { MachineGun = true }, bar = { "MachineGun" } })
check(archerOnly.towers.Bomb == true and table.concat(Levels.ownedTowers(archerOnly), ",") == "MachineGun,Bomb" and archerOnly.best == 3, "ancienne sauvegarde avec le seul Archer : la Catapulte est donnée, le reste est gardé")
local dirty = Levels.cleanData({
	best = 99,
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
-- Première version du prototype : la Catapulte coûtait 350 pièces, le Mage 700 (400 aujourd'hui).
local firstVersion = Levels.cleanData({ coins = 100, towers = { MachineGun = true, Frost = true, Bomb = true, Tesla = true } })
check(firstVersion.coins == 100 + 350 + 300 and firstVersion.version == Levels.DATA_VERSION, `sauvegarde de la première version : la Catapulte (350) et l'écart de prix du Mage (300) sont rendus ({firstVersion.coins} pièces)`)
check(Levels.cleanData(firstVersion).coins == firstVersion.coins and Levels.cleanData(Levels.defaultData()).coins == 0, "... une seule fois, et rien pour un nouveau joueur")
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
	ok, reason = game:placeTower("MachineGun", geometry.pointAt(30))
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
	check(game.lives == 5 and game.state == "Running", "un mini-boss qui atteint le château coûte 5 vies")
	game:spawnEnemy({ enemy = "Boss", health = 1e9, reward = 100 })
	game.enemies[#game.enemies].distance = geometry.PATH_LENGTH - 0.01
	game:simulate(1 / 30)
	check(game.lives == 0 and game.state == "Lost", "un boss qui atteint le château : c'est perdu")
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
	check(stuck, "sans boutique : les niveaux 6 à 10 sont perdus, même en étant très actif")
	-- Le Totem aide sans tout faire : au niveau 5, le joueur de référence gagne avec lui et perd sans lui.
	local withTotem = Bot.play(5, Bot.profile(5, "reference"))
	local withoutTotem = Bot.play(5, { towers = Levels.STARTING_TOWERS, training = 1, interval = Bot.EXPECTED[5].pace, actions = 1 })
	check(withTotem.won and not withoutTotem.won and withoutTotem.kills / withoutTotem.total >= 0.6, `niveau 5 au rythme demandé : {outcome(withTotem)} avec le Totem, {outcome(withoutTotem)} sans lui (il aide, il ne fait pas tout)`)
	local alone = Bot.play(10, startOnly)
	local full = Bot.play(10, { towers = Bot.ALL_TOWERS, training = 6 })
	check(not alone.won and full.won and full.lives == 10, "niveau 10 : perdu avec les deux tours de départ, gagné sans perdre de vie avec toutes les tours entraînées")
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

print(`{passed} tests réussis, {failed} ratés`)
if failed > 0 then
	error(`{failed} test(s) raté(s)`, 0)
end

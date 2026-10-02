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
-- 1) Les niveaux : 10 niveaux, mini-boss au 5, boss au 10, 2 à 3 minutes
----------------------------------------------------------------------
check(Levels.COUNT == 10 and #Levels.DEFINITIONS == 10, `10 niveaux dans le prototype ({Levels.COUNT}, {#Levels.DEFINITIONS} fiches)`)
for level = 1, Levels.COUNT do
	local definition = Levels.definition(level)
	local queue = Levels.buildQueue(level)
	local types, lastAt, ordered = {}, -1, true
	for _, item in queue do
		types[item.enemy] = (types[item.enemy] or 0) + 1
		ordered = ordered and item.at >= lastAt and item.health > 0 and item.reward > 0
		lastAt = item.at
	end
	local duration = Levels.duration(level)
	check(#queue >= 60 and ordered, `niveau {level} : {#queue} monstres, dans l'ordre de leur heure, PV et or positifs`)
	check(duration >= 100 and duration <= 190, `niveau {level} : dure {math.floor(duration)} s (entre 100 et 190)`)
	check(definition.gold >= Levels.placeCost("MachineGun"), `niveau {level} : l'or de départ ({definition.gold}) paie au moins un Archer`)
	check(definition.miniBoss == (level == 5) and definition.boss == (level == 10), `niveau {level} : mini-boss {tostring(definition.miniBoss)}, boss {tostring(definition.boss)}`)
	if level == 5 then
		check(types.Giant == 1 and not types.Boss, "niveau 5 : un mini-boss (chevalier colossal) dans la vague, pas de boss")
	elseif level == 10 then
		check(types.Boss == 1 and queue[#queue].enemy == "Boss", "niveau 10 : le boss ferme la vague")
	end
	-- La vague monte en pression : le dernier groupe de fantassins a plus de PV que le premier.
	local firstNormal, lastNormal = nil, nil
	for _, item in queue do
		if item.enemy == "Normal" then
			firstNormal = firstNormal or item.health
			lastNormal = item.health
		end
	end
	check(firstNormal ~= nil and lastNormal > firstNormal, `niveau {level} : les fantassins passent de {firstNormal} à {lastNormal} PV`)
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
-- 3) Récompenses, prix, limites
----------------------------------------------------------------------
check(Levels.firstReward(1) == 80 and Levels.firstReward(4) == 140 and Levels.firstReward(5) == 300 and Levels.firstReward(10) == 600, "première victoire : 80 au niveau 1, 140 au 4, 300 au mini-boss, 600 au boss")
check(Levels.reward(3, true, true) == 120 and Levels.reward(3, true, false) == 48, "niveau 3 : 120 la première fois, 48 en le rejouant (40 %)")
check(Levels.reward(3, false, false, 0.5) == 12 and Levels.reward(3, false, false, 0) == 0 and Levels.reward(3, false, true, 1) == 24, "défaite : une part de la récompense « rejouer » selon l'avancée (0 si rien n'est éliminé)")
check(Levels.reward(10, true, false) > Levels.reward(4, true, false) and Levels.reward(4, true, false) > Levels.reward(1, true, false), "rejouer un niveau plus haut rapporte plus")
check(Levels.placeCost("MachineGun") == 20 and Levels.upgradeCost("MachineGun", 1) == 15 and Levels.upgradeCost("MachineGun", 2) == 22, "Archer : 20 or, puis 15 et 22 pour ses deux premières améliorations")
check(Levels.upgradeCost("MachineGun", Levels.MAX_TOWER_LEVEL) == nil and Levels.upgradeCost("MachineGun", Levels.MAX_TOWER_LEVEL - 1) ~= nil, "pas d'amélioration au-delà du niveau maximum")
check(Levels.maxCopies("Frost") == 3 and Levels.maxCopies("MachineGun") == 5 and Levels.maxCopies("Orbital") == 2, "limites : 3 Totems, 5 Archers, 2 Trébuchets par niveau")
local shopOk = Levels.SHOP.MachineGun == nil
for _, towerType in IdleTowers.ORDER do
	shopOk = shopOk and Levels.TOWER_COST[towerType] ~= nil and (towerType == "MachineGun" or Levels.SHOP[towerType] > 0)
end
check(shopOk, "boutique : un prix fixe pour chaque tour sauf l'Archer (déjà possédé), et un prix en or pour toutes")

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
check(fresh.best == 0 and fresh.coins == 0 and fresh.towers.MachineGun == true and #fresh.slots == 1 and fresh.slots[1].tower == "MachineGun" and fresh.bar[1] == "MachineGun", "nouveau joueur : l'Archer, un emplacement de camp, rien d'autre")
local dirty = Levels.cleanData({
	best = 99,
	coins = -5,
	towers = { Frost = true, Dragon = true, Bomb = "oui" },
	xp = { Frost = 1 / 0, Dragon = 5, MachineGun = "12" },
	slots = { { tower = "Bomb", level = 99 }, "n'importe quoi", { tower = "Frost", level = 2 }, { tower = "Frost", level = 1 } },
	bar = { "Frost", "Frost", "Dragon", "MachineGun" },
	trainedAt = "hier",
})
check(dirty.best == Levels.COUNT and dirty.coins == 0 and dirty.trainedAt == 0, "sauvegarde abîmée : niveau, pièces et heure remis dans les clous")
check(dirty.towers.Frost and dirty.towers.MachineGun and not dirty.towers.Dragon and not dirty.towers.Bomb, "sauvegarde abîmée : seules les vraies tours possédées restent (l'Archer toujours)")
check(dirty.xp.Dragon == nil and dirty.xp.MachineGun == 12 and dirty.xp.Frost == 1e9, "sauvegarde abîmée : XP des vraies tours seulement, bornée")
check(#dirty.slots == 3 and dirty.slots[1].tower == "" and dirty.slots[1].level == 5 and dirty.slots[2].tower == "" and dirty.slots[3].tower == "Frost" and dirty.slots[3].level == 2, "sauvegarde abîmée : 3 emplacements au plus, tour non possédée retirée, niveau borné")
check(#dirty.bar == 2 and dirty.bar[1] == "Frost" and dirty.bar[2] == "MachineGun", "sauvegarde abîmée : barre sans doublon ni tour inconnue")
check(Levels.cleanData(nil).best == 0 and Levels.cleanData("x").towers.MachineGun == true, "pas de sauvegarde : un nouveau joueur")
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
	local game, arena = newGame(1, { "MachineGun" })
	local starter = nil
	for _, tower in game.towers do
		starter = tower
	end
	check(towerCount(game) == 1 and starter.type == "MachineGun" and (starter.localPosition - map.spots[1]).Magnitude < 1e-6, "niveau 1 : un Archer offert au premier emplacement conseillé")
	check(game.gold == 25 and game.lives == 10 and game.state == "Running" and arena.folder:GetAttribute("State") == "Running" and arena.folder:GetAttribute("Level") == 1, "niveau 1 : 25 or, 10 vies, en cours (attributs publiés)")
	check(arena.folder:GetAttribute("Total") == #Levels.buildQueue(1) and arena.folder:GetAttribute("Left") == arena.folder:GetAttribute("Total"), "niveau 1 : avancée publiée (tous les monstres restent)")
	check(arena.folder:GetAttribute("Perks") == "" and arena.folder:GetAttribute("Training") == Levels.encodeTraining({}), "niveau 1 sans entraînement : aucun effet débloqué publié")
	run(game, 12)
	check(game.kills >= 1 and game.gold == 25 + 2 * game.kills and game.lives == 10, `l'Archer offert tue seul : {game.kills} monstres en 12 s, 2 or chacun, aucune vie perdue`)

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
	check(before >= 25, "(l'or n'a fait que monter pendant les 12 premières secondes)")

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
	local game, arena, ends = newGame(2, { "MachineGun" })
	check(towerCount(game) == 0 and game.gold == 45, "niveau 2 : aucune tour offerte, 45 or")
	run(game, 120)
	check(game.state == "Lost" and game.lives == 0 and game.leaked == 10 and #ends == 1 and ends[1] == false, `sans tour : perdu quand 10 fantassins ont atteint le château (en {math.floor(game.clock)} s), fin annoncée une seule fois`)
	game:syncAttributes()
	check(#game.enemies == 0 and arena.folder:GetAttribute("State") == "Lost" and arena.folder:GetAttribute("Lives") == 0, "défaite : plus aucun monstre, état « Lost » publié")
	local clock = game.clock
	game:simulate(1)
	game:finish(true)
	check(game.clock == clock and game.state == "Lost" and #ends == 1, "un niveau fini ne bouge plus et ne se termine pas deux fois")
	check(game:placeTower("MachineGun", map.spots[1]) == false and game:rush() == 0, "un niveau fini refuse les poses et « envoyer la suite »")
	check(near(game:progress(), game.kills / #game.queue) and game:progress() == 0, "avancée : part de la vague éliminée (0 ici)")
end

do
	-- Un colosse qui passe coûte 5 vies, le boss 10.
	local game = newGame(5, { "MachineGun" })
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
	-- « Envoyer la suite » : seulement pendant la pause entre deux groupes, contre un peu d'or.
	local game, arena = newGame(2, { "MachineGun" })
	game:simulate(1 / 30)
	check(game:rushSeconds() == 0 and game:rush() == 0, "pas d'« envoyer la suite » entre deux monstres d'un même groupe")
	local queue = Levels.buildQueue(2)
	local firstOfSecond = nil
	for index, item in queue do
		if item.enemy == "Fast" then
			firstOfSecond = index
			break
		end
	end
	game.lives = math.huge
	while game.queueIndex < firstOfSecond do
		game:simulate(1 / 30)
	end
	local wait = game:rushSeconds()
	local gold, spawned = game.gold, game.queueIndex
	local bonus = game:rush()
	game:simulate(1 / 30)
	game:syncAttributes()
	check(wait > 2.2 and bonus == math.floor(wait * Levels.RUSH_GOLD_PER_SECOND + 0.5) and game.gold >= gold + bonus and game.queueIndex == spawned + 1, `pause entre deux groupes : {wait} s sautées, +{bonus} or, le monstre suivant sort tout de suite`)
	check(arena.folder:GetAttribute("RushSeconds") == 0, "juste après : plus rien à sauter")
end

do
	-- Victoire : le joueur simulé gagne le niveau 1 avec le seul Archer, sans perdre de vie.
	local result = Bot.play(1, { towers = { "MachineGun" }, training = 0 })
	check(result.won and result.lives == 10 and result.kills == result.total, `niveau 1 gagné par le joueur simulé avec le seul Archer ({result.kills}/{result.total} monstres, {result.lives} vies, {math.floor(result.seconds)} s)`)
	-- ... et le niveau 10 est hors de portée de l'Archer seul, mais pas de toutes les tours entraînées.
	local alone = Bot.play(10, { towers = { "MachineGun" }, training = 0 })
	local full = Bot.play(10, { towers = table.clone(IdleTowers.ORDER), training = 6 })
	check(not alone.won and full.won, "niveau 10 : perdu avec l'Archer seul, gagné avec toutes les tours entraînées")
end

do
	-- Entraînement : les flèches enflammées n'existent dans un niveau qu'à partir de l'entraînement 2.
	local plain = newGame(2, { "MachineGun" }, 0)
	local trained, trainedArena = newGame(2, { "MachineGun" }, 2)
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

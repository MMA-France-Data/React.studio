--!optimize 2
-- Simulateur du mode infini : point d'entrée (lancé par run.ps1, voir tools/balance/README.md).
-- Arguments (après -a) : graines=3 heures=100 scenarios=base,forge,renaissance pas=0.05 journal=1
--                        regler=IdleConfig.HEALTH_GROWTH=1.2;IdleTowers.Defs.Frost.slow=0.3;Joueur.SAVE_SECONDS=600
-- Sorties (lignes lues par run.ps1) :
--   "CSV|..."     -> out/timeline.csv (une ligne par vague passée pour la première fois)
--   "HEURES|..."  -> out/heures.csv (une ligne par heure de jeu)
--   "JOURNAL|..." -> out/journal.txt (tout ce que fait le joueur simulé, première graine seulement)
--   "PROGRES|..." -> affiché pendant le calcul
--   le reste      -> out/rapport.txt
local Modules = require("./Modules")

----------------------------------------------------------------------
-- Arguments
----------------------------------------------------------------------
local options = {
	seeds = 3,
	firstSeed = 1, -- debut=4 : joue les graines 4, 5, 6... (pour lancer plusieurs calculs en parallèle)
	hours = 100,
	scenarios = { "base", "forge", "renaissance", "renaissance-seule", "sans-sorcier" },
	dt = 0.05,
	overrides = {},
	journal = false,
	-- Calcul en parallèle (run.ps1 -Paralleles, voir Dump.luau) : travail=1 -> joue les parties demandées et
	-- écrit chacune sur une ligne "PARTIE|..." (pas de rapport) ; assembler=gen/runs/a,gen/runs/b -> relit ces
	-- parties (modules Luau écrits par run.ps1) au lieu de les jouer, puis écrit le rapport.
	worker = false,
	assemble = nil :: { string }?,
}
for _, arg in { ... } do
	local key, value = string.match(arg, "^([%w_]+)=(.*)$")
	if key == "graines" then
		options.seeds = assert(tonumber(value), "graines : nombre attendu")
	elseif key == "debut" then
		options.firstSeed = assert(tonumber(value), "debut : nombre attendu")
	elseif key == "travail" then
		options.worker = value == "1" or value == "true"
	elseif key == "assembler" then
		options.assemble = string.split(value, ",")
	elseif key == "heures" then
		options.hours = assert(tonumber(value), "heures : nombre attendu")
	elseif key == "scenarios" then
		options.scenarios = string.split(value, ",")
	elseif key == "pas" then
		options.dt = assert(tonumber(value), "pas : nombre attendu")
	elseif key == "journal" then
		options.journal = value == "1" or value == "true"
	elseif key == "regler" then
		for _, item in string.split(value, ";") do
			if item ~= "" then
				table.insert(options.overrides, item)
			end
		end
	elseif key then
		error(`argument inconnu : {key}`)
	end
end

-- Réglages modifiés pour un essai : "Module.CHAMP=valeur" (IdleConfig, IdleTowers, PlotLayout, Enemies)
-- ou "Joueur.CHAMP=valeur" (réglages du joueur simulé, Run.POLICY).
local function applyOverride(item: string, roots)
	local path, raw = string.match(item, "^%s*([%w_%.]+)%s*=%s*(.-)%s*$")
	assert(path, `réglage mal écrit : {item} (exemple : IdleConfig.HEALTH_GROWTH=1.2)`)
	local keys = string.split(path, ".")
	local target = roots[keys[1]]
	if not target then
		return false
	end
	for i = 2, #keys - 1 do
		target = target[tonumber(keys[i]) or keys[i]]
		assert(type(target) == "table", `chemin inconnu : {path}`)
	end
	local last = tonumber(keys[#keys]) or keys[#keys]
	local value: any = tonumber(raw)
	if value == nil then
		value = if raw == "true" then true elseif raw == "false" then false else raw
	end
	assert(target[last] ~= nil, `réglage inconnu : {path}`)
	target[last] = value
	return true
end

-- Les modules du jeu d'abord (avant de charger le moteur, qui lit certaines valeurs au démarrage).
local playerOverrides = {}
for _, item in options.overrides do
	if not applyOverride(item, Modules) then
		table.insert(playerOverrides, item)
	end
end

local Engine = require("./Engine")
local Run = require("./Run")
local Report = require("./Report")
local Dump = require("./Dump")

for _, item in playerOverrides do
	if not applyOverride(item, { Joueur = Run.POLICY }) then
		error(`module inconnu dans « {item} » : IdleConfig, IdleTowers, PlotLayout, Enemies ou Joueur`)
	end
end
for _, id in options.scenarios do
	assert(
		Run.SCENARIOS[id],
		`scénario inconnu : {id} (base, forge, renaissance, renaissance-seule, sans-sorcier ; tout sur l'Archer : archer-x20, archer-x20-x2, archer-x20-x2-givre, archer-x20-renaissance, archer-x20-x2-renaissance, archer-sans-rune)`
	)
end

Engine.DT = options.dt
local IdleConfig = Modules.IdleConfig
local IdleTowers = Modules.IdleTowers
local PlotLayout = Modules.PlotLayout
local out, duration, mean, coins = Report.out, Report.duration, Report.mean, Report.coins
local shortNumber = Report.shortNumber

-- Valeur du milieu d'une liste (plus parlante qu'une moyenne pour des nombres qui changent d'échelle).
local function medianOf(list)
	if #list == 0 then
		return nil
	end
	local sorted = table.clone(list)
	table.sort(sorted)
	return sorted[math.floor((#sorted + 1) / 2)]
end

-- Heures où le rapport montre le compteur de lancers de l'autel et le prix du prochain achat.
local SPIN_HOURS = { 1, 10, 25, 50, 100 }

-- Prix d'un lot de l'autel (IdleConfig.towerSpinCost) avec son équivalent en vagues de gains au record, ou
-- la vague qui le débloque, ou « MAX ».
local function spinPriceText(record: number, count: number, bought: number): string
	if not IdleConfig.towerSpinBulkAvailable(record, count) then
		for _, bulk in IdleConfig.TOWER_SPIN_BULKS do
			if bulk.count == count then
				return `(vague {bulk.minWave})`
			end
		end
		return "-"
	end
	local cost = IdleConfig.towerSpinCost(record, count, bought)
	if cost >= math.huge then
		return "MAX"
	end
	local waves = Report.wavesOfRewards(cost, record)
	local wavesText = if waves >= 100 then shortNumber(waves) else string.format("%.3g", waves)
	return `{Modules.NumberFormat.price(cost)} ({wavesText})`
end

-- Première tour légendaire obtenue à l'autel : { t, wave } (nil si aucune).
local function firstLegendary(run)
	local first = nil
	for _, towerType in IdleTowers.ofRarity("Legendary") do
		local at = run.unlockedAt[towerType]
		if at and (not first or at.t < first.t) then
			first = at
		end
	end
	return first
end

----------------------------------------------------------------------
-- 1. Les parties
----------------------------------------------------------------------
local CHECKPOINTS = { 2, 5, 10, 20, 30, 40, 60, 80 }
-- Heures où le rapport explique pourquoi le joueur « tout sur l'Archer » bloque (en plus de la fin de la partie).
local ARCHER_DIAG_HOURS = { 1, 4, 12, 40 }
local runsByScenario = {}
local started = os.clock()
if not options.worker then
	Report.csvHeader()
end
-- Assembleur (calcul en parallèle) : les parties sont relues, pas jouées (même ordre : scénario puis graine).
if options.assemble then
	for _, path in options.assemble do
		local data = require(path) :: any
		local run = setmetatable(data, Run)
		run.scenario = assert(Run.SCENARIOS[data.scenarioId], `partie illisible : {path}`)
		runsByScenario[data.scenarioId] = runsByScenario[data.scenarioId] or {}
		table.insert(runsByScenario[data.scenarioId], run)
	end
	for _, scenarioId in options.scenarios do
		table.sort(runsByScenario[scenarioId] or {}, function(a, b)
			return a.seed < b.seed
		end)
	end
end
for scenarioIndex, scenarioId in (if options.assemble then {} else options.scenarios) do
	local runs = {}
	for seed = options.firstSeed, options.firstSeed + options.seeds - 1 do
		local run = Run.new(scenarioId, seed)
		run.hourly = {} -- [heure] = record
		run.hourlySpins = {} -- [heure] = lancers de la machine à tours depuis le début
		run.hourlyHighest = {} -- [heure] = record de tous les temps (idle.highestWave : prix et chances de l'autel)
		run.hourlyMoney = {} -- [heure] = { coins, income (par seconde), total gagné, record }
		run.checkpoints = {}
		if options.journal and scenarioIndex == 1 and seed == options.firstSeed then
			run.journal = {}
		end
		local cpu = os.clock()
		run:play(options.hours * 3600, function(r, hour)
			r.hourly[hour] = r.frontier
			r.hourlySpins[hour] = r.spins
			r.hourlyForge = r.hourlyForge or {}
			r.hourlyForge[hour] = r.forgeSpins
			r.hourlyHighest[hour] = r.highestWave
			r.hourlyMoney[hour] = { coins = r.coins, income = r.income, total = r.totalEarned, frontier = r.frontier }
			Report.csvHour(r, hour)
			if table.find(CHECKPOINTS, hour) then
				-- Copie des tours pour l'analyse « renaissance en boucle »
				local towers = {}
				for _, tower in r:compiled() do
					table.insert(towers, table.clone(tower))
				end
				-- layout : types, emplacements, niveaux et pièces dépensées (tableau « anti-méta »)
				local layout = {}
				for spot, tower in r.towers do
					table.insert(layout, { spot = spot, type = tower.type, level = tower.level, spent = tower.spent })
				end
				r.checkpoints[hour] = { towers = towers, frontier = r.frontier, coinBonus = r.coinBonus, layout = layout }
			end
			-- Joueur « tout sur l'Archer » : niveaux de l'Archer et du Totem à chaque heure, et pourquoi il bloque
			-- à quelques heures (Run:archerDiagnosis), pour la partie « TOUT SUR L'ARCHER » du rapport.
			if r.scenario.archer then
				local archerLevel, frostLevel = r:archerLevels()
				r.hourlyArcher = r.hourlyArcher or {}
				r.hourlyArcher[hour] = { archer = archerLevel, frost = frostLevel }
				if table.find(ARCHER_DIAG_HOURS, hour) then
					r.archerDiag = r.archerDiag or {}
					r.archerDiag[hour] = r:archerDiagnosis()
				end
			end
		end)
		if run.scenario.archer then
			run.archerDiag = run.archerDiag or {}
			run.archerDiag.fin = run:archerDiagnosis()
		end
		table.insert(runs, run)
		Report.csvRun(run)
		if run.journal then
			print(`JOURNAL|Journal du joueur simulé : scénario « {scenarioId} », graine {seed}, {options.hours} h de jeu.`)
			print("JOURNAL|Temps de jeu, pièces en poche après l'événement, événement.")
			for _, line in run.journal do
				print("JOURNAL|" .. line)
			end
			run.journal = nil
		end
		print(
			string.format(
				"PROGRES|%-18s graine %d%s : vague %d en %s (%.1f s de calcul)",
				scenarioId,
				seed,
				if options.worker then "" else `/{options.seeds}`,
				run.frontier,
				duration(run.endTime),
				os.clock() - cpu
			)
		)
		if options.worker then
			print("PARTIE|" .. Dump.run(run, scenarioId))
		end
	end
	runsByScenario[scenarioId] = runs
end
if options.worker then
	return -- travail=1 : pas de rapport, l'assembleur l'écrira
end

local reference = runsByScenario.base or runsByScenario[options.scenarios[1]]
local referenceId = if runsByScenario.base then "base" else options.scenarios[1]

----------------------------------------------------------------------
-- 2. En-tête
----------------------------------------------------------------------
Report.section("entete")
Report.header(options)

-- Une seule fuite = vague ratée : vitesse de chaque ennemi et temps qu'il passe sur le chemin (sans / avec
-- le ralentissement du Totem de givre pendant tout le trajet).
do
	local frost = IdleTowers.Defs.Frost
	local parts = {}
	for _, name in { "Normal", "Fast", "Tank", "Swarm", "Giant", "Boss" } do
		local speed = Engine.enemySpeed(name)
		table.insert(
			parts,
			string.format("%s %.1f studs/s (%.0f s", Modules.Enemies.Defs[name].displayName, speed, Engine.PATH_LENGTH / speed)
				.. (if frost.slow then string.format(", %.0f s ralenti", Engine.PATH_LENGTH / (speed * (1 - frost.slow))) else "")
				.. ")"
		)
	end
	out("Une seule fuite fait rater la vague. Vitesse des ennemis et temps pour parcourir tout le chemin (sans / avec")
	out(`le ralentissement du Totem de givre, -{math.floor((frost.slow or 0) * 100 + 0.5)} %, sur tout le trajet) : {table.concat(parts, ", ")}.`)
	out()
end

----------------------------------------------------------------------
-- 3. Lecture des réglages (calculée depuis src/shared, sans simulation)
----------------------------------------------------------------------
Report.section("analyse")
out(string.rep("=", 100))
out("LECTURE DES RÉGLAGES (calculs directs sur les valeurs de src/shared, sans simulation)")
out(string.rep("=", 100))
do
	local R, D, G = IdleConfig.REWARD_GROWTH, IdleConfig.UPGRADE_DAMAGE, IdleConfig.UPGRADE_COST_GROWTH
	-- Croissance réelle d'une vague à la suivante (lue dans les fonctions du jeu, quelle que soit leur formule).
	local function hpGrowth(wave: number): number
		return IdleConfig.healthBudget(wave + 1) / IdleConfig.healthBudget(wave)
	end
	local function rewardGrowth(wave: number): number
		return IdleConfig.rewardBudget(wave + 1) / IdleConfig.rewardBudget(wave)
	end
	-- Pour suivre une vague de plus, il faut hpGrowth de dégâts en plus, soit ln(hpGrowth) / ln(D) niveaux,
	-- qui coûtent G^niveaux de plus : le temps de farm est multiplié par G^niveaux / croissance des gains.
	local function farmGrowth(wave: number): number
		local levels = math.log(hpGrowth(wave)) / math.log(D)
		return G ^ levels / rewardGrowth(wave)
	end
	local function farmBetween(a: number, b: number): number
		local total = 0
		for wave = a, b - 1 do
			total += math.log(farmGrowth(wave))
		end
		return math.exp(total)
	end
	local parts = {}
	for _, wave in { 10, 25, 50, 100, 200 } do
		table.insert(parts, string.format("v%d : PV x%.3f, pièces x%.3f", wave, hpGrowth(wave), rewardGrowth(wave)))
	end
	out("- Croissance d'une vague à la suivante : " .. table.concat(parts, " ; ") .. ".")
	out(
		string.format(
			"- Améliorations : dégâts x%.2f et prix x%.2f par niveau. Pour suivre une vague de plus, le temps de farm est multiplié par",
			D,
			G
		)
	)
	out(
		string.format(
			"  x%.3f à la vague 15, x%.3f à la 50, x%.3f à la 100 : x%.1f de la vague 15 à la 50, x%.1f de la 50 à la 100, x%.1f de la 100 à la 200",
			farmGrowth(15),
			farmGrowth(50),
			farmGrowth(100),
			farmBetween(15, 50),
			farmBetween(50, 100),
			farmBetween(100, 200)
		)
	)
	out("  (sans compter les doublons, les emplacements, les nouvelles tours et les bonus, qui raccourcissent les murs).")
	out(
		string.format(
			"  Valeur « neutre » de UPGRADE_COST_GROWTH loin dans le jeu (farm constant d'une vague à l'autre) : %.3f.",
			math.exp(math.log(R) * math.log(D) / math.log(hpGrowth(1000)))
		)
	)
	local minRatio, maxRatio = math.huge, 0
	for spot = PlotLayout.STARTING_SPOTS + 2, #PlotLayout.SPOTS do
		local ratio = PlotLayout.spotCost(spot) / PlotLayout.spotCost(spot - 1)
		minRatio = math.min(minRatio, ratio)
		maxRatio = math.max(maxRatio, ratio)
	end
	out(
		string.format(
			"- Emplacements : chaque emplacement coûte x%.1f à x%.1f le précédent ; avec des gains x%.2f par vague, il faut %.1f à %.1f vagues de progression",
			minRatio,
			maxRatio,
			R,
			math.log(minRatio) / math.log(R),
			math.log(maxRatio) / math.log(R)
		)
	)
	out(
		string.format(
			"  entre deux emplacements pour qu'ils demandent le même temps de farm. Le 22e (%s) = %s vagues de gains à la vague 90.",
			coins(PlotLayout.spotCost(#PlotLayout.SPOTS)),
			shortNumber(Report.wavesOfRewards(PlotLayout.spotCost(#PlotLayout.SPOTS), 90))
		)
	)
	-- Autel des héros : prix d'un lancer et de chaque lot, en vagues de gains (prix / pièces d'une vague au record).
	do
		-- 3 chiffres significatifs (un lancer peut valoir 0,0003 vague de gains)
		local function waves3(value: number): string
			return if value >= 1000 then shortNumber(value) else string.format("%.3g", value)
		end
		local parts = {}
		for _, record in { 1, 10, 25, 60, 100, 150, 200, 300, 500, 1000 } do
			table.insert(parts, `v{record} : {waves3(Report.wavesOfRewards(IdleConfig.towerSpinUnitCost(record), record))}`)
		end
		out("- Autel des héros : prix d'UN lancer en vagues de gains au record : " .. table.concat(parts, ", ") .. ".")
		local bulks = {}
		for _, bulk in IdleConfig.TOWER_SPIN_BULKS do
			local texts, records = {}, { bulk.minWave }
			for _, record in { 100, 200, 500, 1000 } do
				if record > bulk.minWave then
					table.insert(records, record)
				end
			end
			for _, record in records do
				table.insert(
					texts,
					`{waves3(Report.wavesOfRewards(IdleConfig.towerSpinCost(record, bulk.count), record))} à la v{record}`
				)
			end
			table.insert(bulks, `x{Modules.NumberFormat.short(bulk.count)} (dès la v{bulk.minWave}) = {table.concat(texts, ", ")}`)
		end
		out("  Lots, en vagues de gains (aucun lancer encore acheté) : " .. table.concat(bulks, " ; ") .. ".")
		-- Hausse de +0,05 % par lancer acheté, jamais remise à zéro (IdleConfig.TOWER_SPIN_PRICE_GROWTH).
		local growth = IdleConfig.TOWER_SPIN_PRICE_GROWTH
		local multipliers = {}
		for _, bought in { 1000, 10000, 20000, 50000 } do
			table.insert(multipliers, `{shortNumber(bought)} -> x{waves3(growth ^ bought)}`)
		end
		out(
			string.format(
				"  Chaque lancer acheté rend le suivant x%s plus cher, pour toujours. Prix d'un lancer après n lancers achetés : %s ; « MAX » vers %s lancers.",
				tostring(growth),
				table.concat(multipliers, ", "),
				shortNumber(math.log(1.7976931348623157e308) / math.log(growth))
			)
		)
		out(
			string.format(
				"  Chaque doublon = +%s %% de dégâts sans limite. Au palier 1, %d %% de chances de tomber sur une Commune (2 tours).",
				IdleConfig.formatPercent(IdleConfig.DUPLICATE_DAMAGE_BONUS * 100),
				IdleConfig.TOWER_SPIN_TIERS[1].odds.Common
			)
		)
	end
	-- Puissance des tours à budget égal (budget = 12 vagues de gains de la vague 50), calculée avec les vrais prix.
	local budget = 12 * IdleConfig.rewardBudget(50)
	local texts, best, values = {}, 0, {}
	for _, towerType in IdleTowers.ORDER do
		local spent, level = IdleTowers.Defs[towerType].placeCost, 1
		while level < 5000 and spent + IdleTowers.upgradeCost(towerType, level) <= budget do
			spent += IdleTowers.upgradeCost(towerType, level)
			level += 1
		end
		local stats = IdleTowers.stats(towerType, level)
		-- Rayon du Sorcier : au maximum de sa montée (IdleTowers.beamMaxDps).
		local dps = if stats.kind == "Beam" then IdleTowers.beamMaxDps(stats) else stats.damage / stats.cooldown
		values[towerType] = { dps = dps, level = level }
		best = math.max(best, values[towerType].dps)
	end
	for _, towerType in IdleTowers.ORDER do
		table.insert(texts, `{Run.shortName(towerType)} {math.floor(values[towerType].dps / best * 100 + 0.5)} (niv {values[towerType].level})`)
	end
	out(`- À budget égal ({coins(budget)} par tour = 12 vagues de gains de la vague 50), dégâts par seconde sur UNE cible (100 = la meilleure ;`)
	out("  ignore la portée, la zone, la chaîne, le ralentissement et le feu des flèches ; Sorcier : rayon au maximum de sa")
	out("  montée ; voir le banc d'essai et les duels) : " .. table.concat(texts, ", "))
	out()
end

----------------------------------------------------------------------
-- 4. Détail de chaque scénario
----------------------------------------------------------------------
local order = { "entete", "objectifs", "analyse" }
for _, scenarioId in options.scenarios do
	local runs = runsByScenario[scenarioId]
	local scenario = Run.SCENARIOS[scenarioId]
	Report.section("scenario:" .. scenarioId)
	table.insert(order, "scenario:" .. scenarioId)
	out(string.rep("=", 100))
	out(`SCÉNARIO « {scenarioId} » : {scenario.label}`)
	out(string.rep("=", 100))
	local frontiers = {}
	for _, run in runs do
		table.insert(frontiers, run.frontier)
	end
	local lo, hi = Report.minMax(frontiers)
	out(`Record après {options.hours} h : vague {math.floor(mean(frontiers) + 0.5)} en moyenne ({lo} - {hi}).`)
	local spins, dupesEnd, maxDupes, maxDupesType, played, failed = {}, {}, {}, {}, {}, {}
	local spentBy = { upgrade = 0, place = 0, spot = 0, replace = 0, forge = 0, spin = 0 }
	for _, run in runs do
		table.insert(spins, run.spins)
		local total, best, bestType = 0, 0, nil
		for towerType, n in run.dupes do
			total += n
			if n > best then
				best, bestType = n, towerType
			end
		end
		table.insert(dupesEnd, total)
		table.insert(maxDupes, best)
		if bestType then
			maxDupesType[bestType] = (maxDupesType[bestType] or 0) + 1
		end
		table.insert(played, run.wavesPlayed)
		table.insert(failed, run.wavesFailed)
		for kind, amount in run.spentBy do
			spentBy[kind] += amount
		end
	end
	local mostDuped, mostCount = nil, 0
	for towerType, n in maxDupesType do
		if n > mostCount then
			mostDuped, mostCount = towerType, n
		end
	end
	out(
		string.format(
			"Autel des héros : %s lancers achetés en moyenne, %s doublons ; le plus sur une tour : %s (%s, soit +%s %% de dégâts).",
			shortNumber(mean(spins)),
			shortNumber(mean(dupesEnd)),
			shortNumber(mean(maxDupes)),
			if mostDuped then Run.shortName(mostDuped) else "-",
			shortNumber(mean(maxDupes) * IdleConfig.DUPLICATE_DAMAGE_BONUS * 100)
		)
	)
	do
		-- Lots achetés : combien de fois, et à quel record le premier achat (moyenne des graines qui l'ont fait).
		local parts = {}
		for _, bulk in IdleConfig.TOWER_SPIN_BULKS do
			local counts, firstWaves, firstTimes = {}, {}, {}
			for _, run in runs do
				local buys = run.spinBuys[bulk.count]
				table.insert(counts, if buys then buys.n else 0)
				if buys then
					table.insert(firstWaves, buys.firstWave)
					table.insert(firstTimes, buys.firstT)
				end
			end
			table.insert(
				parts,
				`x{Modules.NumberFormat.short(bulk.count)} : {shortNumber(mean(counts))} achats`
					.. (if #firstWaves > 0
						then ` (1er au record {math.floor(mean(firstWaves) + 0.5)}, {duration(mean(firstTimes))}{if #firstWaves < #runs then `, {#firstWaves}/{#runs}` else ""})`
						else " (jamais)")
			)
		end
		out("  Lots achetés : " .. table.concat(parts, " ; ") .. ".")
	end
	do
		-- Compteur de lancers (jamais remis à zéro) et prix du prochain achat, au fil des heures (médiane des graines).
		local rows = {}
		for _, hour in SPIN_HOURS do
			local spinsList, records = {}, {}
			for _, run in runs do
				if run.hourlySpins[hour] then
					table.insert(spinsList, run.hourlySpins[hour])
					table.insert(records, run.hourlyHighest[hour])
				end
			end
			if #spinsList > 0 then
				local bought, record = medianOf(spinsList), medianOf(records)
				local row = { `{hour} h`, tostring(record), shortNumber(bought) }
				for _, count in { 1, 100, 10000 } do
					table.insert(row, spinPriceText(record, count, bought))
				end
				table.insert(rows, row)
			end
		end
		if #rows > 0 then
			out("  Lancers achetés depuis le début et prix du prochain achat (médiane des graines ; entre parenthèses, en vagues de gains au record) :")
			Report.table({ "Temps", "Record", "Lancers achetés", "Prochain x1", "Prochain x100", "Prochain x10 000" }, rows)
		end
		-- Première tour légendaire (dorée) : quand et à quelle vague (médiane des graines qui en ont eu une).
		local times, waves = {}, {}
		for _, run in runs do
			local first = firstLegendary(run)
			if first then
				table.insert(times, first.t)
				table.insert(waves, first.wave)
			end
		end
		out(
			if #times > 0
				then `  Première tour légendaire : vers {duration(medianOf(times))}, vague {medianOf(waves)} (médiane de {#times}/{#runs} graines ; vagues {table.concat(waves, ", ")}).`
				else `  Première tour légendaire : jamais en {options.hours} h.`
		)
	end
	out(string.format("Vagues jouées : %.0f dont %.0f ratées.", mean(played), mean(failed)))
	local totalSpent = 0
	for _, amount in spentBy do
		totalSpent += amount
	end
	if totalSpent > 0 then
		out(
			string.format(
				"Dépenses : améliorations %.0f %%, emplacements %.0f %%, tours posées %.0f %%, remplacements %.0f %%, autel %.0f %%, forge %.0f %%.",
				spentBy.upgrade / totalSpent * 100,
				spentBy.spot / totalSpent * 100,
				spentBy.place / totalSpent * 100,
				spentBy.replace / totalSpent * 100,
				spentBy.spin / totalSpent * 100,
				spentBy.forge / totalSpent * 100
			)
		)
		-- Part de l'autel par tranche de vagues (chaque partie compte autant)
		local parts = {}
		for _, bucket in { "1-25", "26-50", "51-100", "101+" } do
			local shares = {}
			for _, run in runs do
				local row = run.spentByBucket[bucket]
				if row then
					local total = 0
					for _, amount in row do
						total += amount
					end
					if total > 0 then
						table.insert(shares, row.spin / total)
					end
				end
			end
			if #shares > 0 then
				table.insert(parts, `vagues {bucket} : {Report.pct(mean(shares))}`)
			end
		end
		out("  Part de l'autel dans les dépenses : " .. table.concat(parts, ", ") .. ".")
	end
	out()
	out("Jalons (premier passage de la vague ; moyenne des graines) :")
	Report.milestones(runs)
	out()
	out("Murs par tranche de vagues :")
	Report.walls(runs)
	Report.noPurchase(runs)
	out()
	out("Murs de plus de 2 min (durée moyenne par graine) :")
	Report.wallList(runs, 120)
	out()
	out("Emplacements achetés :")
	Report.spots(runs)
	out()
	out("Tours obtenues à la machine (vague moyenne du déblocage) :")
	Report.unlocks(runs)
	out()
	out("Part des dégâts utiles par tour (chaque partie compte autant ; « . » = moins de 1 %) :")
	Report.damageShare(runs)
	out("  (Dégâts utiles = sans ce qui dépasse les PV de l'ennemi. Le ralentissement du Totem et du Mage n'y apparaît pas.)")
	out()

	if scenario.forge then
		-- Runes posées à la fin : 2 emplacements par tour (dégâts, vitesse), qui se cumulent.
		local forgeSpins, spent, placed, speedShare = {}, {}, {}, {}
		for _, run in runs do
			table.insert(forgeSpins, run.forgeSpins)
			table.insert(spent, run.forgeSpent)
			local best, towers, withSpeed = 0, 0, 0
			for _, tower in run.towers do
				local runes = IdleConfig.parseRunes(tower.runes)
				towers += 1
				if runes.Damage then
					best = math.max(best, runes.Damage.mult)
				end
				if runes.Speed then
					withSpeed += 1
				end
			end
			table.insert(placed, best)
			table.insert(speedShare, if towers > 0 then 100 * withSpeed / towers else 0)
		end
		out(
			`Forge runique : {string.format("%.0f", mean(forgeSpins))} lancers en moyenne, {coins(mean(spent))} pièces dépensées ; meilleure rune de dégâts posée à la fin : x{string.format("%.0f", mean(placed))} en moyenne ; rune de vitesse sur {string.format("%.0f", mean(speedShare))} % des tours posées.`
		)
		-- Lancers en pièces achetés au fil du temps (prix 100 K, x5 sous 1 T, puis x2) et record à ces heures
		local parts = {}
		for _, hour in { 2, 6, 10, 25, 50, 100 } do
			if hour <= options.hours then
				local spins, records = {}, {}
				for _, run in runs do
					if run.hourlyForge and run.hourlyForge[hour] then
						table.insert(spins, run.hourlyForge[hour])
						table.insert(records, run.hourly[hour])
					end
				end
				if #spins > 0 then
					local s = medianOf(spins)
					table.insert(
						parts,
						string.format("%d h : %d lancers (record %d, prochain prix %s)", hour, s, medianOf(records), coins(IdleConfig.forgeCoinPrice(s)))
					)
				end
			end
		end
		out(`  Lancers de la forge au fil du temps (médiane) : {table.concat(parts, " ; ")}.`)
		out()
	end

	if scenario.rebirth then
		-- Remonter après une renaissance : temps pour revenir à 80 % de la meilleure vague de la run (médiane, par
		-- tranche de la vague d'origine). Sortie à chaque mort : IdleConfig.SPAWN_NEXT_ON_KILL ; vague écrasée :
		-- IdleConfig.COMPRESS_EMPTY_SPAWNS.
		local climb = {}
		for _, run in runs do
			for _, entry in run.rebirthLog do
				if entry.cycle80 then
					local bucket = if entry.fromWave < 40 then "vagues 15-39" elseif entry.fromWave < 80 then "vagues 40-79" elseif entry.fromWave < 150 then "vagues 80-149" else "vagues 150+"
					climb[bucket] = climb[bucket] or {}
					table.insert(climb[bucket], entry.cycle80)
				end
			end
		end
		local climbParts = {}
		for _, bucket in { "vagues 15-39", "vagues 40-79", "vagues 80-149", "vagues 150+" } do
			if climb[bucket] then
				table.insert(climbParts, `{bucket} : {duration(medianOf(climb[bucket]))} ({#climb[bucket]} renaissances)`)
			end
		end
		out(
			`Remonter à 80 % du record de la run après une renaissance (médiane ; sortie à chaque mort {if IdleConfig.SPAWN_NEXT_ON_KILL then "activée" else "désactivée"} ; vague écrasée {if IdleConfig.COMPRESS_EMPTY_SPAWNS then "activée" else "désactivée"}) : {table.concat(climbParts, " ; ")}.`
		)
		out("Renaissances (vague d'origine, gain, temps pour revenir à 80 % puis à 100 % du record de la run) :")
		for _, run in runs do
			local parts = {}
			for i, entry in run.rebirthLog do
				if i <= 10 then
					table.insert(
						parts,
						`v{entry.fromWave} +{IdleConfig.formatPercent(entry.gain)} % ({if entry.cycle80 then duration(entry.cycle80) else "…"} / {if entry.cycle then duration(entry.cycle) else "…"})`
					)
				end
			end
			out(
				`  graine {run.seed} : {run.rebirths} renaissances, bonus final +{IdleConfig.formatPercent(run.coinBonus)} % : `
					.. `{table.concat(parts, ", ")}{if #run.rebirthLog > 10 then ", …" else ""}`
			)
		end
		out()
	end
end

----------------------------------------------------------------------
-- 5. Comparaison des scénarios
----------------------------------------------------------------------
if #options.scenarios > 1 then
	Report.section("comparaison")
	table.insert(order, "comparaison")
	out(string.rep("=", 100))
	out("COMPARAISON DES SCÉNARIOS (temps moyen pour atteindre la vague ; « 3/5 » = graines qui l'ont atteinte)")
	out(string.rep("=", 100))
	local headers = { "Vague" }
	for _, id in options.scenarios do
		table.insert(headers, id)
	end
	local rows = {}
	for _, wave in Report.MILESTONES do
		local row, any = { tostring(wave) }, false
		for _, id in options.scenarios do
			local t, n = Report.reachTime(runsByScenario[id], wave)
			any = any or n > 0
			table.insert(row, if n == 0 then "-" elseif n < options.seeds then `{n}/{options.seeds} {duration(t)}` else duration(t))
		end
		if any then
			table.insert(rows, row)
		end
	end
	local row = { `record à {options.hours} h` }
	for _, id in options.scenarios do
		local list = {}
		for _, run in runsByScenario[id] do
			table.insert(list, run.frontier)
		end
		table.insert(row, string.format("%.0f", mean(list)))
	end
	table.insert(rows, row)
	Report.table(headers, rows)
	out()
end

----------------------------------------------------------------------
-- 5 ter. TOUT SUR L'ARCHER (scénarios avec `archer`, question du propriétaire du 01/10/2026 : la rune x20 dégâts
-- sur un Archer, un Totem de givre à côté, toutes les pièces dans l'Archer). Affiché juste après l'en-tête :
-- record au fil des heures et temps pour atteindre les vagues (avec les autres scénarios du même calcul, pour
-- comparer), runes, niveaux de l'Archer et du Totem, murs par type de vague, et pourquoi il bloque
-- (Run:archerDiagnosis).
----------------------------------------------------------------------
do
	local archerIds = {}
	for _, id in options.scenarios do
		if Run.SCENARIOS[id].archer then
			table.insert(archerIds, id)
		end
	end
	if #archerIds > 0 then
		Report.section("archer")
		table.insert(order, 2, "archer") -- juste après l'en-tête : c'est la question posée
		local enemyName = function(name: string): string
			return Modules.Enemies.Defs[name].displayName
		end
		-- k (multiplicateur de dégâts de l'Archer qu'il faudrait) en texte
		local function kText(k: number): string
			if k == math.huge then
				return "impossible même avec des dégâts infinis"
			elseif k <= 1 then
				return "déjà réussie"
			end
			return "x" .. (if k < 10 then string.format("%.2f", k) else shortNumber(k))
		end
		out(string.rep("=", 100))
		out("TOUT SUR L'ARCHER : que l'Archer du rempart (emplacement 1) et un Totem de givre juste à côté (emplacement 5), toutes")
		out("les pièces dans l'Archer. Runes forcées selon le scénario : x20 dégâts au 1er lancer de la forge (100 K), x2 vitesse au")
		out("2e (500 K), prix mis de côté dès qu'il vaut moins de 30 min de revenu ; ensuite plus de forge ni d'autel (voir Run.luau).")
		out("Comparé aux autres scénarios de ce calcul (base = le joueur normal, toutes les tours, sans forge).")
		out(string.rep("=", 100))
		-- Record au fil des heures (moyenne des graines [min - max])
		local hours = {}
		for _, hour in ARCHER_DIAG_HOURS do
			if hour <= options.hours then
				table.insert(hours, hour)
			end
		end
		if not table.find(hours, math.floor(options.hours)) and options.hours >= 1 then
			table.insert(hours, math.floor(options.hours))
		end
		local headers = { "Scénario" }
		for _, hour in hours do
			table.insert(headers, `record à {hour} h`)
		end
		local rows = {}
		for _, id in options.scenarios do
			local row = { id }
			for _, hour in hours do
				local list = {}
				for _, run in runsByScenario[id] do
					if run.hourly[hour] then
						table.insert(list, run.hourly[hour])
					end
				end
				if #list == 0 then
					table.insert(row, "-")
				else
					local lo, hi = Report.minMax(list)
					table.insert(row, string.format("%.0f", mean(list)) .. (if lo ~= hi then ` [{lo}-{hi}]` else ""))
				end
			end
			table.insert(rows, row)
		end
		out("Record (dernière vague réussie) au fil des heures de jeu (moyenne des graines [min - max]) :")
		Report.table(headers, rows, { "l" })
		out()
		-- Temps pour atteindre les vagues
		local targets = { 30, 50, 100, 150, 200, 300 }
		headers = { "Scénario" }
		for _, wave in targets do
			table.insert(headers, `vague {wave}`)
		end
		rows = {}
		for _, id in options.scenarios do
			local row = { id }
			for _, wave in targets do
				local t, n = Report.reachTime(runsByScenario[id], wave)
				local count = #runsByScenario[id]
				table.insert(row, if n == 0 then "jamais" elseif n < count then `{n}/{count} {duration(t)}` else duration(t))
			end
			table.insert(rows, row)
		end
		out(`Temps de jeu pour atteindre la vague (moyenne ; « jamais » = pas en {options.hours} h ; « 2/3 » = graines qui l'ont atteinte) :`)
		Report.table(headers, rows, { "l" })
		out()
		for _, id in archerIds do
			local runs = runsByScenario[id]
			local plan = Run.SCENARIOS[id].archer
			out(`« {id} » : {Run.SCENARIOS[id].label}`)
			-- Runes (lancers de forge forcés) et Totem débloqué à l'autel
			local runeParts = {}
			for index, runeId in plan.runes do
				local times, waves = {}, {}
				for _, run in runs do
					local entry = run.bonusLog[index]
					if entry then
						table.insert(times, entry.t)
						table.insert(waves, entry.wave)
					end
				end
				table.insert(
					runeParts,
					`{IdleConfig.BONUS_BY_ID[runeId].displayName} ({coins(IdleConfig.forgeCoinPrice(index - 1))}) `
						.. (if #times > 0 then `à {duration(mean(times))}, record {math.floor(mean(waves) + 0.5)}` else "jamais")
						.. (if #times > 0 and #times < #runs then ` ({#times}/{#runs})` else "")
				)
			end
			local spins, frostTimes = {}, {}
			for _, run in runs do
				table.insert(spins, run.spins)
				if run.unlockedAt.Frost then
					table.insert(frostTimes, run.unlockedAt.Frost.t)
				end
			end
			out(
				`  Forge : {if #runeParts > 0 then table.concat(runeParts, " ; ") else "aucun lancer"}. Autel : {string.format("%.1f", mean(spins))} lancers x1 pour débloquer le Totem`
					.. (if #frostTimes > 0 then ` (à {duration(mean(frostTimes))})` else " (jamais débloqué)")
					.. "."
			)
			-- Niveaux de l'Archer et du Totem au fil des heures (moyenne des graines)
			local levelParts = {}
			for _, hour in hours do
				local archers, frosts = {}, {}
				for _, run in runs do
					local levels = run.hourlyArcher and run.hourlyArcher[hour]
					if levels then
						table.insert(archers, levels.archer)
						table.insert(frosts, levels.frost)
					end
				end
				if #archers > 0 then
					table.insert(levelParts, string.format("%d h : Archer niv %.0f, Totem niv %.0f", hour, mean(archers), mean(frosts)))
				end
			end
			out(`  Niveaux : {table.concat(levelParts, " ; ")}.`)
			-- Murs d'au moins 1 min (vagues 11 et plus) par type de vague, mur en cours à la fin compris
			local byType, total = {}, 0
			for _, run in runs do
				local function add(wave: number, seconds: number)
					if wave >= 11 and seconds >= 60 then
						local waveType = IdleConfig.waveType(wave)
						byType[waveType] = byType[waveType] or {}
						table.insert(byType[waveType], seconds)
						total += 1
					end
				end
				for _, wall in run.walls do
					add(wall.wave, wall.seconds)
				end
				add(run.frontier + 1, run.openWall)
			end
			local wallParts = {}
			for _, waveType in Report.WAVE_TYPE_ORDER do
				local list = byType[waveType]
				if list then
					local _, hi = Report.minMax(list)
					table.insert(
						wallParts,
						`{Report.waveTypeName(waveType)} {string.format("%.1f", #list / #runs)} (médiane {duration(medianOf(list))}, max {duration(hi)})`
					)
				end
			end
			out(
				`  Murs d'au moins 1 min (vagues 11+, par partie, mur en cours à la fin compris) : {if total > 0 then table.concat(wallParts, " ; ") else "aucun"}.`
			)
			-- Pourquoi il bloque : graine 1 à quelques heures, puis chaque graine à la fin
			local function describe(label: string, diag)
				if not diag then
					return
				end
				local climb = if diag.climbing
					then ` (en train de remonter après sa renaissance n° {diag.rebirths} : vague {diag.currentWave} ; bonus de pièces +{IdleConfig.formatPercent(diag.coinBonus)} %)`
					else ""
				out(
					`  {label} : bloqué à la vague {diag.blocked} ({Report.waveTypeName(diag.blockedType)}){climb}. Archer niv {diag.archerLevel}`
						.. `{if diag.runes ~= "" then ` ({diag.runes})` else ""}, {diag.dupes} doublon(s) : {coins(diag.damage)} dégâts par flèche,`
						.. ` {string.format("%.0f", diag.attacksPerSecond)} flèches/s (DPS {coins(diag.dps)} ; feu {coins(diag.fireDps)}/s par zone) ;`
						.. ` Totem niv {diag.frostLevel} (+{string.format("%.0f", diag.fragility * 100)} % de dégâts reçus) ; revenu à son record {coins(diag.income * 60)}/min.`
				)
				local leakParts = {}
				for _, leak in diag.leaks do
					if leak.leaked > 0 then
						table.insert(leakParts, `{leak.leaked} {enemyName(leak.name)} sur {leak.count}`)
					end
				end
				local toughest, toughestName = 0, "-"
				for _, leak in diag.leaks do
					if leak.hp > toughest then
						toughest, toughestName = leak.hp, enemyName(leak.name)
					end
				end
				out(
					"      Un essai de cette vague avec ses tours : "
						.. (if diag.success
							then "réussie (il vient de s'améliorer)"
							else `passent : {table.concat(leakParts, ", ")} (le 1er après {duration(diag.leakSeconds)})`)
						.. ` ; le plus résistant ({toughestName}, {coins(toughest)} PV) = {shortNumber(diag.toughestArrows)} flèches ;`
						.. ` toute la vague = {shortNumber(diag.waveArrows)} flèches ({duration(diag.waveArrows / diag.attacksPerSecond)} de tir sans pause, sans fragilité ni feu).`
				)
				local needParts = {}
				for _, entry in diag.waves do
					local text = `{Report.waveTypeName(entry.type)}{if entry.actual then " (la vraie)" else ""} {kText(entry.k)}`
					if entry.k > 1 and entry.k < math.huge then
						text ..= ` = {entry.levels} niv. ({coins(entry.cost)}, {duration(entry.hours * 3600)} de revenu)`
					end
					table.insert(needParts, text)
				end
				out(`      Vague {diag.blocked} construite comme chaque type, dégâts de l'Archer qu'il faudrait (x k, à 3 % près) : ` .. table.concat(needParts, " ; ") .. ".")
			end
			for _, hour in hours do
				local first = runs[1]
				if hour < options.hours and first.archerDiag and first.archerDiag[hour] then
					describe(`À {hour} h (graine {first.seed})`, first.archerDiag[hour])
				end
			end
			for _, run in runs do
				describe(`Fin ({options.hours} h, graine {run.seed})`, run.archerDiag and run.archerDiag.fin)
			end
			out()
		end
		out("  (k = de combien il faudrait multiplier les dégâts de l'Archer pour réussir la vague avec ses tours actuelles ; la vague")
		out("   qui bloque est construite comme chaque type (même numéro, mêmes PV au total), « la vraie » = son vrai type ;")
		out("   « niv. » = améliorations de l'Archer qui donnent ce x k, leur prix et le temps pour le gagner à son revenu à son record ;")
		out("   « impossible » = un ennemi passe même avec des dégâts infinis : il manque des tirs ou du temps, pas des dégâts.)")
		out()
	end
end

----------------------------------------------------------------------
-- 5 bis. Grands nombres : pièces en poche, revenu et total gagné au fil des heures, puis les limites
-- des nombres (au-delà de ~1,8e308, un nombre devient « infini » et les DataStores refusent de le sauver).
----------------------------------------------------------------------
local function isFinite(value: number): boolean
	return value == value and value < math.huge and value > -math.huge
end

-- Première heure (moyenne des graines qui y arrivent) où le revenu par minute atteint `threshold`.
local function hourReaching(runs, threshold: number)
	local hours = {}
	for _, run in runs do
		for hour = 1, math.floor(options.hours) do
			local money = run.hourlyMoney[hour]
			if money and money.income * 60 >= threshold then
				table.insert(hours, hour)
				break
			end
		end
	end
	return mean(hours), #hours
end

-- Médianes (sur les graines) à une heure donnée : record, pièces en poche, revenu par minute, total gagné.
local function moneyAt(runs, hour: number)
	local frontier, pocket, income, total = {}, {}, {}, {}
	for _, run in runs do
		local money = run.hourlyMoney[hour]
		if money then
			table.insert(frontier, money.frontier)
			table.insert(pocket, money.coins)
			table.insert(income, money.income * 60)
			table.insert(total, money.total)
		end
	end
	if #frontier == 0 then
		return nil
	end
	return { frontier = medianOf(frontier), coins = medianOf(pocket), income = medianOf(income), total = medianOf(total) }
end

local BIG_THRESHOLDS = {
	{ 1e6, "1 M (million)" },
	{ 1e9, "1 B (milliard)" },
	{ 1e12, "1 T (trillion)" },
	{ 1e15, "1 Qa" },
	{ 1e18, "1 Qi" },
	{ 1e21, "1 Sx" },
	{ 1e24, "1 Sp" },
	{ 1e27, "1 Oc" },
	{ 1e30, "1 No" },
	{ 1e33, "1 Dc" },
}

-- Limites des nombres : première vague (et premier niveau d'amélioration) où un montant devient infini.
local overflow = {}
do
	local function waveIsFinite(wave: number): boolean
		if
			not isFinite(IdleConfig.healthBudget(wave))
			or not isFinite(IdleConfig.rewardBudget(wave))
		then
			return false
		end
		for _, item in IdleConfig.buildWave(wave) do
			-- Pièces d'un ennemi avec un énorme bonus de renaissance (+10 000 %) : toujours fini ?
			if not isFinite(item.health) or not isFinite(item.reward * 101) then
				return false
			end
		end
		return true
	end
	local function levelIsFinite(level: number): boolean
		for _, towerType in IdleTowers.ORDER do
			if not isFinite(IdleTowers.upgradeCost(towerType, level)) then
				return false
			end
			-- Pire cas : runes x100 dégâts ET x2 vitesse de la forge (elles se cumulent) et 10 000 doublons
			local stats = IdleTowers.effectiveStats(towerType, level, 10000, "Damage100,Speed2")
			if not isFinite(IdleTowers.dpsOf(stats)) then
				return false
			end
		end
		return true
	end
	-- Recherche par dichotomie (les montants ne font que grandir avec la vague et le niveau).
	local function firstInfinite(check, limit: number): number?
		if check(limit) then
			return nil
		end
		local lo, hi = 1, limit
		while hi - lo > 1 do
			local mid = (lo + hi) // 2
			if check(mid) then
				lo = mid
			else
				hi = mid
			end
		end
		return hi
	end
	overflow.wave = firstInfinite(waveIsFinite, 1000000)
	overflow.level = firstInfinite(levelIsFinite, 1000000)
	overflow.spots = true
	for n = 1, #PlotLayout.SPOTS do
		if not isFinite(PlotLayout.spotCost(n)) then
			overflow.spots = false
		end
	end
	-- Niveau qui garde le même rapport dégâts / PV qu'à la vague 1 avec une tour niveau 1.
	overflow.matchingLevel = function(wave: number): number
		return 1 + math.ceil(math.log(IdleConfig.healthBudget(wave) / IdleConfig.healthBudget(1)) / math.log(IdleConfig.UPGRADE_DAMAGE))
	end
	-- Première vague où le plus gros ennemi dépasse 10^96 PV : NumberFormat.short passe en notation scientifique.
	local wave = 1
	while wave < 100000 do
		local biggest = 0
		for _, item in IdleConfig.buildWave(wave) do
			biggest = math.max(biggest, item.health)
		end
		if biggest >= 1e96 then
			break
		end
		wave += 1
	end
	overflow.scientificWave = wave
end

Report.section("grands")
table.insert(order, "grands")
out(string.rep("=", 100))
out("GRANDS NOMBRES : les pièces au fil des heures (valeur du milieu des graines) et les limites des nombres")
out(string.rep("=", 100))
for _, scenarioId in options.scenarios do
	local runs = runsByScenario[scenarioId]
	local rows = {}
	for _, hour in { 1, 5, 10, 25, 50, 80, 90, 100, 150, 200 } do
		local money = hour <= options.hours and moneyAt(runs, hour)
		if money then
			table.insert(rows, {
				`{hour} h`,
				tostring(money.frontier),
				coins(money.coins),
				coins(money.income),
				coins(money.total),
			})
		end
	end
	if #rows > 0 then
		out(`Scénario « {scenarioId} » :`)
		Report.table({ "Temps", "Record", "Pièces en poche", "Revenu / min", "Total gagné depuis le début" }, rows)
		local parts = {}
		for _, threshold in BIG_THRESHOLDS do
			local hour, n = hourReaching(runs, threshold[1])
			if n > 0 then
				table.insert(parts, `{threshold[2]} vers {math.floor(hour + 0.5)} h{if n < #runs then ` ({n}/{#runs})` else ""}`)
			end
		end
		if #parts > 0 then
			out("  Revenu par minute qui atteint : " .. table.concat(parts, ", "))
		end
		out()
	end
end
out("Limites des nombres (Luau : au-delà de ~1,8e308 un nombre devient infini ; un DataStore ne sait pas le sauver) :")
do
	local biggest = 0
	for _, item in IdleConfig.buildWave(1500) do
		biggest = math.max(biggest, item.health)
	end
	out(
		`- PV et pièces des vagues : {if overflow.wave then `infinis à partir de la vague {overflow.wave}` else "finis jusqu'à la vague 1 000 000"}`
			.. ` ; vague 1500 : ennemi le plus gros {coins(biggest)} PV, {coins(IdleConfig.rewardBudget(1500))} pièces par vague.`
	)
end
out(
	`- Améliorations (prix, dégâts avec bonus x100 et 10 000 doublons) : {if overflow.level then `infinies à partir du niveau {overflow.level}` else "finies jusqu'au niveau 1 000 000"}`
		.. ` ; niveau 1000 : amélioration de l'Archer {coins(IdleTowers.upgradeCost("MachineGun", 1000))}, du Trébuchet {coins(IdleTowers.upgradeCost("Orbital", 1000))}.`
)
do
	local level = overflow.matchingLevel(1500)
	out(
		`- Pour suivre la vague 1500, il faut des tours vers le niveau {level} : amélioration de l'Archer {coins(IdleTowers.upgradeCost("MachineGun", level))}`
			.. ` (fini : {if isFinite(IdleTowers.upgradeCost("Orbital", level)) then "oui" else "NON"}).`
	)
end
out(`- Emplacements : prix {if overflow.spots then "tous finis" else "INFINIS"} (le 22e : {coins(PlotLayout.spotCost(#PlotLayout.SPOTS))}).`)
out(
	`- Affichage (NumberFormat.short) : suffixes jusqu'à Tg (10^93), puis notation scientifique (« 1.23e96 ») ; les PV d'un ennemi y passent vers la vague {overflow.scientificWave}.`
)
out()

----------------------------------------------------------------------
-- 6. Banc d'essai des tours : N tours du même type (N = emplacements du joueur simulé à cette vague), chacune
-- sur les emplacements qui couvrent le plus de chemin pour sa portée, même budget chacune.
-- Mesure : le multiplicateur de dégâts minimal pour que ces N tours passent la vague (k), avec les vraies
-- règles (une seule fuite = vague ratée). La puissance relative est 100 x k(meilleure) / k(tour) : 100 = la
-- meilleure, 50 = deux fois moins forte.
----------------------------------------------------------------------
Report.section("banc")
table.insert(order, "banc")
local BENCH_WAVES = { 10, 25, 50, 75, 100, 150 }
local BEST_SPOTS = Run.SPOTS_BY_COVERAGE
local function levelForBudget(towerType: string, budget: number): number
	local spent, level = IdleTowers.Defs[towerType].placeCost, 1
	while level < 5000 do
		local nextCost = IdleTowers.upgradeCost(towerType, level)
		if spent + nextCost > budget then
			break
		end
		spent += nextCost
		level += 1
	end
	return level
end

-- team = { { type, level, spot }, ... } (sans doublons ni bonus). Les tours tirent dans l'ordre des emplacements.
local function passes(comp, team, mult: number): boolean
	local towers = {}
	for _, member in team do
		local tower = Engine.compileTower(member.spot, member.type, member.level, 0, nil)
		tower.damage *= mult
		table.insert(towers, tower)
	end
	table.sort(towers, function(a, b)
		return a.spot < b.spot
	end)
	return Engine.runWave(comp, towers, "strict").success
end

-- Plus petit multiplicateur de dégâts (à 3 % près) qui fait réussir l'épreuve ; math.huge si aucun
-- (la tour ne tire pas assez souvent pour tuer tout le monde, même avec des dégâts infinis).
local function requiredMultiplier(comp, team): number
	local lo, hi
	if passes(comp, team, 1) then
		lo, hi = 0.5, 1
		while passes(comp, team, lo) do
			hi = lo
			lo /= 2
			if lo < 1e-6 then
				return lo
			end
		end
	else
		lo, hi = 1, 2
		while not passes(comp, team, hi) do
			lo = hi
			hi *= 2
			if hi > 1e8 then
				return math.huge
			end
		end
	end
	while hi / lo > 1.03 do
		local mid = math.sqrt(lo * hi)
		if passes(comp, team, mid) then
			hi = mid
		else
			lo = mid
		end
	end
	return hi
end

-- count tours du même type sur leurs meilleurs emplacements.
local function sameTeam(towerType: string, level: number, count: number)
	local team = {}
	for i = 1, count do
		team[i] = { type = towerType, level = level, spot = BEST_SPOTS[towerType][i] }
	end
	return team
end

-- Vrai si l'équipe ({ { type, ... } }) dépasse la limite de tours identiques (IdleTowers.MAX_COPIES : 5 par tour
-- commune, 4 rare, 3 épique, 2 légendaire) : composition IMPOSSIBLE en jeu. Le banc d'essai et l'anti-méta
-- comparent quand même ces équipes (pour mesurer les tours), le rapport les marque « ! ».
local function overLimit(team): boolean
	for towerType, n in IdleTowers.countCopies(team) do
		if n > IdleTowers.maxCopies(towerType) then
			return true
		end
	end
	return false
end
local LIMIT_TEXT = `limite de tours identiques : {IdleTowers.MAX_COPIES.Common} par Commune, {IdleTowers.MAX_COPIES.Rare} par Rare, {IdleTowers.MAX_COPIES.Epic} par Épique, {IdleTowers.MAX_COPIES.Legendary} par Légendaire`

local function powerText(power: number): string
	return if power <= 0 then "0" else shortNumber(power)
end

-- Soutien : 3 exemplaires d'une autre tour (sur ses meilleurs emplacements) + N - 3 exemplaires de la tour la
-- plus forte en moyenne. Montre ce que les tours de soutien (ralentissement, zone) apportent à côté de la tour
-- principale. Note cells[tour][type].support (100 = aussi fort que N tours principales), renvoie la tour principale.
local function benchSupport(wave: number, budget: number, cells, count: number)
	local main, mainScore = nil, -math.huge
	for _, towerType in IdleTowers.ORDER do
		local score, count = 0, 0
		for _, waveType in Report.WAVE_TYPE_ORDER do
			local cell = cells[towerType][waveType]
			if not cell.tooExpensive and cell.k < math.huge then
				score -= math.log(cell.k)
				count += 1
			end
		end
		if count == #Report.WAVE_TYPE_ORDER and score > mainScore then
			main, mainScore = towerType, score
		end
	end
	if not main then
		return nil
	end
	local mainName = Run.shortName(main)
	local mainLevel = levelForBudget(main, budget)
	local rows = {}
	for _, towerType in IdleTowers.ORDER do
		if towerType ~= main and IdleTowers.Defs[towerType].placeCost <= budget then
			local row = { Run.shortName(towerType) }
			local rowOver = false -- équipe au-delà de la limite de tours identiques (impossible en jeu)
			for _, waveType in Report.WAVE_TYPE_ORDER do
				local team, used = {}, {}
				for i = 1, math.min(3, count - 1) do
					local spot = BEST_SPOTS[towerType][i]
					used[spot] = true
					table.insert(team, { type = towerType, level = levelForBudget(towerType, budget), spot = spot })
				end
				for _, spot in BEST_SPOTS[main] do
					if #team >= count then
						break
					end
					if not used[spot] then
						table.insert(team, { type = main, level = mainLevel, spot = spot })
					end
				end
				rowOver = rowOver or overLimit(team)
				local k = requiredMultiplier(Engine.composition(wave, waveType), team)
				local value = if k == math.huge then 0 else 100 * cells[main][waveType].k / k
				cells[towerType][waveType].support = value
				table.insert(row, powerText(value) .. (if value > 100 then " +" else "  "))
			end
			if rowOver then
				row[1] ..= " !"
			end
			table.insert(rows, row)
		end
	end
	if #rows > 0 then
		out(`  Soutien : {count - 3} {mainName} + 3 exemplaires d'une autre tour (100 = aussi fort que {count} {mainName} ;`)
		out(`  « + » = l'équipe est plus forte qu'avec {count} {mainName}, la tour est utile en soutien ; « ! » = équipe`)
		out(`  impossible en jeu, au-delà de la {LIMIT_TEXT}) :`)
		local headers = { `{count - 3} {mainName} + 3` }
		for _, waveType in Report.WAVE_TYPE_ORDER do
			table.insert(headers, Report.waveTypeName(waveType))
		end
		Report.table(headers, rows, { "l" })
	end
	return main
end

local benchResults = {}
out(string.rep("=", 100))
out("BANC D'ESSAI DES TOURS : N tours du même type sur leurs meilleurs emplacements, même budget par tour")
out(string.rep("=", 100))
out(`N = emplacements du joueur simulé (scénario « {referenceId} ») à cette vague ; budget par tour = sa dépense moyenne par tour.`)
out("Chaque tour va sur les emplacements qui couvrent le plus de chemin pour SA portée. Épreuve : réussir la vague (vraies")
out("règles : une seule fuite = vague ratée), construite comme ce type. Case = puissance relative sans doublons / avec")
out("les doublons moyens de ce moment. 100 = la meilleure tour sans doublons contre ce type de vague ; 50 = il lui faudrait 2 fois")
out("plus de dégâts. * = la meilleure. « k » = multiplicateur de dégâts dont la meilleure tour a besoin pour réussir")
out("(k < 1 : elle réussit avec de la marge).")
out(`« ! » après le nom = N tours de ce type, au-delà de la {LIMIT_TEXT} : équipe IMPOSSIBLE`)
out("en jeu (le banc compare quand même les tours entre elles ; le joueur simulé, lui, respecte la limite).")
for _, wave in BENCH_WAVES do
	local budgets, dupeSums, spotCounts, n = {}, {}, {}, 0
	for _, run in reference do
		local snap = run.firstClear[wave]
		if snap and snap.towers > 0 then
			n += 1
			table.insert(budgets, snap.spent / snap.towers)
			table.insert(spotCounts, snap.spots)
			for towerType, count in snap.dupesByType do
				dupeSums[towerType] = (dupeSums[towerType] or 0) + count
			end
		end
	end
	if n == 0 then
		out()
		out(`Vague {wave} : pas atteinte par le scénario de référence, pas de banc d'essai.`)
		break
	end
	local budget = mean(budgets)
	local count = math.max(4, math.floor(mean(spotCounts) + 0.5))
	local levels = {}
	for _, towerType in IdleTowers.ORDER do
		table.insert(levels, `{Run.shortName(towerType)} {levelForBudget(towerType, budget)}`)
	end
	out()
	out(`Vague {wave} : {count} tours, budget {coins(budget)} par tour -> niveaux {table.concat(levels, ", ")}`)
	local cells, bestK = {}, {}
	for _, towerType in IdleTowers.ORDER do
		cells[towerType] = {}
		local dupes = (dupeSums[towerType] or 0) / n
		for _, waveType in Report.WAVE_TYPE_ORDER do
			if IdleTowers.Defs[towerType].placeCost > budget then
				cells[towerType][waveType] = { tooExpensive = true }
			else
				local comp = Engine.composition(wave, waveType)
				local k = requiredMultiplier(comp, sameTeam(towerType, levelForBudget(towerType, budget), count))
				-- Les doublons ne changent que les dégâts : k avec doublons = k / (1 + doublons x bonus).
				local kDupes = k / (1 + dupes * IdleConfig.DUPLICATE_DAMAGE_BONUS)
				cells[towerType][waveType] = { k = k, kDupes = kDupes }
				bestK[waveType] = math.min(bestK[waveType] or math.huge, k)
			end
		end
	end
	local rows = {}
	for _, towerType in IdleTowers.ORDER do
		local over = if count > IdleTowers.maxCopies(towerType) then " !" else ""
		local row = { Run.shortName(towerType) .. " (" .. IdleConfig.RARITIES[IdleTowers.Defs[towerType].rarity].displayName .. ")" .. over }
		for _, waveType in Report.WAVE_TYPE_ORDER do
			local cell = cells[towerType][waveType]
			if cell.tooExpensive then
				table.insert(row, "trop chère ")
			else
				cell.power = if cell.k == math.huge then 0 else 100 * bestK[waveType] / cell.k
				cell.powerDupes = if cell.k == math.huge then 0 else 100 * bestK[waveType] / cell.kDupes
				local mark = if cell.k <= bestK[waveType] then "*" else " "
				table.insert(row, `{powerText(cell.power)} / {powerText(cell.powerDupes)}{mark}`)
			end
		end
		table.insert(rows, row)
	end
	local kRow = { "k de la meilleure" }
	for _, waveType in Report.WAVE_TYPE_ORDER do
		table.insert(kRow, if bestK[waveType] == math.huge then "-" else `x{shortNumber(bestK[waveType])} `)
	end
	table.insert(rows, kRow)
	local headers = { "Tour" }
	for _, waveType in Report.WAVE_TYPE_ORDER do
		table.insert(headers, Report.waveTypeName(waveType))
	end
	Report.table(headers, rows, { "l" })
	out("  (0 = impossible même avec des dégâts infinis : ces tours ne tirent pas assez souvent, un ennemi atteint la base.)")
	local main = benchSupport(wave, budget, cells, count)
	benchResults[wave] = { cells = cells, bestK = bestK, main = main }
end
out()

----------------------------------------------------------------------
-- 6 bis. Anti-méta : compositions extrêmes contre une défense mélangée, même budget.
-- À plusieurs moments d'une vraie partie (scénario de référence, chaque graine) : on prend le nombre de tours
-- du joueur simulé et ses pièces dépensées dans ses tours (sans doublons ni runes), et on construit :
--   « mélange du joueur »  = ses tours à ses emplacements, avec ses vrais niveaux ;
--   « mélange, budget égal » = les mêmes types et emplacements, le budget réparti également ;
--   extrêmes = N tours d'un seul type (ou moitié / moitié) sur leurs meilleurs emplacements, budget réparti
--              également.
-- Épreuve : jouer les vagues 1, 2, 3... dans l'ordre avec cette défense FIXE (vraies règles : une seule fuite =
-- vague ratée). Résultat = dernière vague réussie avant le premier échec (médiane des graines). Le mélange doit
-- aller plus loin que chaque composition extrême (règle du propriétaire : pas de partie « tout X »).
----------------------------------------------------------------------
local ANTI_META_HOURS = { 5, 10, 20, 40, 80 }
-- runes (facultatif) = runes de la forge posées sur chaque tour de ce type (texte de l'attribut « Bonus »).
local EXTREMES = {
	{ name = "Tout Trébuchet", types = { "Orbital" } },
	{ name = "Tout givre", types = { "Frost" } },
	{ name = "Trébuchet + givre", types = { "Orbital", "Frost" } },
	{ name = "Tout Sorcier", types = { "Laser" } },
	{ name = "Tout Catapulte", types = { "Bomb" } },
	{ name = "Givre + Mage", types = { "Frost", "Tesla" } },
	{ name = "Tout Mage", types = { "Tesla" } },
	-- La composition du propriétaire à la vague 148 : plein de Mages avec la rune x2 vitesse (comme lui) et des
	-- Catapultes. Seule composition AVEC des runes : elle a donc un avantage sur le mélange (sans runes).
	{ name = "Mages x2 + Catapultes", types = { "Tesla", "Bomb" }, runes = { Tesla = "Speed2" } },
	{ name = "Tout Archer", types = { "MachineGun" } },
	{ name = "Tout Baliste", types = { "Rocket" } },
}
local antiMeta = {} -- [heure] = { mixed, mixedEqual, [nom extrême] = vague }
do
	-- Dernière vague réussie avant le premier échec, défense fixe (limite : `limit`).
	local function reachedWave(team, limit: number): number
		local towers = {}
		for _, member in team do
			table.insert(towers, Engine.compileTower(member.spot, member.type, member.level, 0, member.runes))
		end
		table.sort(towers, function(a, b)
			return a.spot < b.spot
		end)
		for wave = 1, limit do
			if not Engine.runWave(Engine.composition(wave), towers, "strict").success then
				return wave - 1
			end
		end
		return limit
	end
	-- count tours des types donnés (à tour de rôle) sur leurs meilleurs emplacements, sans doublon d'emplacement.
	-- runes = { [type de tour] = runes } ou nil.
	local function extremeTeam(types, count: number, budget: number, runes)
		local team, used, nextIndex = {}, {}, {}
		for _, towerType in types do
			nextIndex[towerType] = 1
		end
		local i = 0
		while #team < count and i < count * 10 do
			i += 1
			local towerType = types[(i - 1) % #types + 1]
			local list = BEST_SPOTS[towerType]
			while nextIndex[towerType] <= #list and used[list[nextIndex[towerType]]] do
				nextIndex[towerType] += 1
			end
			local spot = list[nextIndex[towerType]]
			if spot then
				used[spot] = true
				table.insert(team, { type = towerType, spot = spot, level = levelForBudget(towerType, budget), runes = runes and runes[towerType] })
			end
		end
		return team
	end
	local anyRow = false
	local rows = {}
	for _, hour in ANTI_META_HOURS do
		if hour > options.hours then
			break
		end
		local perSeed = {}
		for _, run in reference do
			local checkpoint = run.checkpoints[hour]
			if checkpoint and checkpoint.layout and #checkpoint.layout > 0 then
				local total, count = 0, #checkpoint.layout
				for _, member in checkpoint.layout do
					total += member.spent
				end
				local budget = total / count
				local limit = math.max(60, checkpoint.frontier * 2 + 30)
				-- over[nom] = vrai si cette équipe dépasse la limite de tours identiques (impossible en jeu, « ! »).
				local result = { frontier = checkpoint.frontier, over = { mixed = overLimit(checkpoint.layout) } }
				result.mixed = reachedWave(checkpoint.layout, limit)
				local equal = {}
				for _, member in checkpoint.layout do
					table.insert(equal, { type = member.type, spot = member.spot, level = levelForBudget(member.type, budget) })
				end
				result.mixedEqual = reachedWave(equal, limit)
				for _, extreme in EXTREMES do
					local team = extremeTeam(extreme.types, count, budget, extreme.runes)
					result.over[extreme.name] = overLimit(team)
					result[extreme.name] = reachedWave(team, limit)
				end
				result.count, result.budget = count, budget
				local types = {}
				for _, member in checkpoint.layout do
					types[member.type] = (types[member.type] or 0) + 1
				end
				local parts = {}
				for _, towerType in IdleTowers.ORDER do
					if types[towerType] then
						table.insert(parts, `{types[towerType]} {Run.shortName(towerType)}`)
					end
				end
				result.composition = table.concat(parts, ", ")
				table.insert(perSeed, result)
			end
		end
		if #perSeed > 0 then
			anyRow = true
			local summary = { hour = hour, composition = perSeed[1].composition }
			local function med(key)
				local list = {}
				for _, result in perSeed do
					table.insert(list, result[key])
				end
				return medianOf(list)
			end
			summary.frontier = med("frontier")
			summary.count = med("count")
			summary.budget = med("budget")
			summary.mixed = med("mixed")
			summary.mixedEqual = med("mixedEqual")
			-- « ! » : équipe au-delà de la limite de tours identiques dans au moins une graine (impossible en jeu).
			summary.over = {}
			local function overMark(key): string
				for _, result in perSeed do
					if result.over[key] then
						summary.over[key] = true
						return " !"
					end
				end
				return ""
			end
			local row = {
				`{hour} h (record {summary.frontier}, {summary.count} tours)`,
				tostring(summary.mixed) .. overMark("mixed"),
				tostring(summary.mixedEqual) .. overMark("mixed"),
			}
			local bestExtreme, bestExtremeName = -1, ""
			for _, extreme in EXTREMES do
				local value = med(extreme.name)
				summary[extreme.name] = value
				table.insert(row, tostring(value) .. overMark(extreme.name))
				if value > bestExtreme then
					bestExtreme, bestExtremeName = value, extreme.name
				end
			end
			summary.bestExtreme, summary.bestExtremeName = bestExtreme, bestExtremeName
			-- Nombre de graines où le mélange (vrais niveaux) va plus loin que TOUS les extrêmes
			local wins = 0
			for _, result in perSeed do
				local best = -1
				for _, extreme in EXTREMES do
					best = math.max(best, result[extreme.name])
				end
				if result.mixed > best then
					wins += 1
				end
			end
			summary.wins, summary.seeds = wins, #perSeed
			table.insert(row, `{wins}/{#perSeed}`)
			table.insert(rows, row)
			antiMeta[hour] = summary
		end
	end
	out(string.rep("=", 100))
	out("ANTI-MÉTA : compositions extrêmes contre la défense mélangée du joueur simulé, même budget (sans doublons ni runes,")
	out("sauf « Mages x2 + Catapultes » : la composition du propriétaire, ses Mages ont la rune x2 vitesse)")
	out(string.rep("=", 100))
	out("Dernière vague réussie en jouant les vagues 1, 2, 3... avec une défense FIXE (médiane des graines). « Mélange » = les")
	out("tours du joueur simulé à ce moment (vrais niveaux) ; « égal » = mêmes tours, budget réparti également ; les extrêmes")
	out("ont le même nombre de tours et le même budget par tour, sur leurs meilleurs emplacements. Dernière colonne : graines")
	out("où le mélange va plus loin que TOUTES les compositions extrêmes.")
	out(`« ! » = équipe au-delà de la {LIMIT_TEXT} (dans au moins une graine) :`)
	out("IMPOSSIBLE en jeu, mesurée quand même pour comparer. Le mélange du joueur simulé respecte la limite.")
	if anyRow then
		local headers = { "Moment", "Mélange", "Égal" }
		for _, extreme in EXTREMES do
			table.insert(headers, extreme.name)
		end
		table.insert(headers, "Mélange devant")
		Report.table(headers, rows, { "l" })
		for _, hour in ANTI_META_HOURS do
			local summary = antiMeta[hour]
			if summary then
				out(`  {hour} h : tours du joueur (graine 1) : {summary.composition} ; budget {coins(summary.budget)} par tour.`)
			end
		end
	else
		out("  (aucun moment disponible : parties trop courtes)")
	end
	out()
end

-- Duels : UNE tour contre UN ennemi (immortel) qui traverse tout le chemin, même niveau pour toutes les tours
-- (même prix d'amélioration : même investissement, à la pose près). Chaque tour sur ses 3 emplacements qui
-- couvrent le plus de chemin (valeur du milieu). « Avec Totem » : un Totem de givre sans dégâts sur
-- l'emplacement le plus proche (seulement son ralentissement). Résultat : dégâts / dégâts de la Baliste lourde.
local DUEL_ENEMIES = { "Boss", "Giant", "Tank", "Normal", "Fast", "Swarm" }
local duelResults = { alone = {}, frost = {} }
do
	local SPOTS = PlotLayout.SPOTS
	local function nearestSpot(spot: number): number
		local best, bestDistance = spot, math.huge
		for other, position in SPOTS do
			local distance = (position - SPOTS[spot]).Magnitude
			if other ~= spot and distance < bestDistance then
				best, bestDistance = other, distance
			end
		end
		return best
	end
	local function duelDamage(towerType: string, enemy: string, frost: boolean): number
		local list = {}
		for i = 1, 3 do
			local spot = BEST_SPOTS[towerType][i]
			local towers = { Engine.compileTower(spot, towerType, 1, 0, nil) }
			if frost then
				local totem = Engine.compileTower(nearestSpot(spot), "Frost", 1, 0, nil)
				totem.damage = 0
				table.insert(towers, totem)
			end
			local comp = Engine.customComposition({ { enemy = enemy, health = 1e300 } })
			table.insert(list, Engine.runWave(comp, towers, "ignore").useful[1])
		end
		table.sort(list)
		return list[2]
	end
	local ballista = { alone = {}, frost = {} }
	for _, enemy in DUEL_ENEMIES do
		ballista.alone[enemy] = duelDamage("Rocket", enemy, false)
		ballista.frost[enemy] = duelDamage("Rocket", enemy, true)
	end
	local headers = { "Tour" }
	for _, enemy in DUEL_ENEMIES do
		table.insert(headers, Modules.Enemies.Defs[enemy].displayName)
	end
	for _, mode in { "alone", "frost" } do
		local rows = {}
		for _, towerType in IdleTowers.ORDER do
			if towerType ~= "Frost" then
				local row = { Run.shortName(towerType) }
				duelResults[mode][towerType] = {}
				for _, enemy in DUEL_ENEMIES do
					local ratio = duelDamage(towerType, enemy, mode == "frost") / ballista[mode][enemy]
					duelResults[mode][towerType][enemy] = ratio
					table.insert(row, string.format("%.2f", ratio))
				end
				table.insert(rows, row)
			end
		end
		out(
			if mode == "alone"
				then "DUELS : une tour contre un seul ennemi qui traverse tout le chemin, même niveau (1 = autant que la Baliste lourde) :"
				else "  ... avec un Totem de givre voisin (son ralentissement seulement) :"
		)
		Report.table(headers, rows, { "l" })
	end
	out("  (Chaque tour sur ses 3 meilleurs emplacements, valeur du milieu. Le rayon du Sorcier monte tant qu'il garde sa cible :")
	out("   il bat la Baliste contre les ennemis lents et perd contre les rapides.)")
	out("   Avec le Totem voisin, les tours profitent aussi de sa fragilité (niveau 1 : +" .. string.format("%.0f", IdleTowers.fragilityAt(IdleTowers.Defs.Frost, 1) * 100) .. " %), sauf le Mage.")

	-- Foules : UNE tour (même niveau) contre une Levée de 30 écuyers immortels ; dégâts / ceux de la Catapulte.
	-- Le Totem de givre est une tour de contrôle : il ne doit jamais faire plus de dégâts que la Catapulte ici.
	local crowd = {}
	for _ = 1, 30 do
		table.insert(crowd, { enemy = "Swarm", health = 1e300, gap = 0.18 })
	end
	local crowdComp = Engine.customComposition(crowd)
	local function crowdDamage(towerType: string): number
		local list = {}
		for i = 1, 3 do
			local towers = { Engine.compileTower(BEST_SPOTS[towerType][i], towerType, 1, 0, nil) }
			table.insert(list, Engine.runWave(crowdComp, towers, "ignore").useful[1])
		end
		table.sort(list)
		return list[2]
	end
	local catapult = crowdDamage("Bomb")
	local parts = {}
	duelResults.crowd = {}
	for _, towerType in IdleTowers.ORDER do
		local ratio = crowdDamage(towerType) / catapult
		duelResults.crowd[towerType] = ratio
		table.insert(parts, string.format("%s %.2f", Run.shortName(towerType), ratio))
	end
	out("FOULE : une tour contre 30 écuyers qui traversent tout le chemin, même niveau (1 = autant que la Catapulte) :")
	out("  " .. table.concat(parts, ", ") .. ".")
	out()
end

----------------------------------------------------------------------
-- 7. Renaissance en boucle : combien de temps pour rejouer 1..N avec les tours d'un moment donné ?
----------------------------------------------------------------------
Report.section("renaissance")
table.insert(order, "renaissance")
out(string.rep("=", 100))
out(`RENAISSANCE EN BOUCLE (tours du scénario « {referenceId} » à différents moments, aucun achat pendant la boucle)`)
out(string.rep("=", 100))
out("Rejouer 1..N = temps pour repasser les vagues 1 à N juste après une renaissance (le « cycle »), et ce que ça rapporte :")
out("le bonus de pièces (%/h de boucle). À comparer à une heure de jeu normal à ce moment : vagues gagnées, hausse du revenu.")
local DT = Engine.DT
local function replay(towers, lastWave: number)
	local total = Engine.delaySteps(IdleConfig.FIRST_WAVE_DELAY) * DT
	for wave = 1, lastWave do
		local result = Engine.runWave(Engine.composition(wave), towers, "strict")
		if not result.success then
			return nil
		end
		total += result.seconds + Engine.delaySteps(IdleConfig.WAVE_CLEAR_DELAY) * DT
	end
	return total
end
local rebirthSummary = {}
for _, hour in CHECKPOINTS do
	local byN, frontiers, progress = {}, {}, {}
	for _, run in reference do
		local cp = run.checkpoints[hour]
		if cp then
			table.insert(frontiers, cp.frontier)
			for _, lastWave in { 15, 25, 50, 75, 100, 150, 200 } do
				if lastWave <= cp.frontier then
					local t = replay(cp.towers, lastWave)
					if t then
						byN[lastWave] = byN[lastWave] or {}
						table.insert(byN[lastWave], t)
					end
				end
			end
			-- Progression moyenne sur les heures suivantes (jusqu'à 10 h : lisse les longs murs)
			for window = 10, 1, -1 do
				local later = run.hourly[hour + window]
				if later then
					table.insert(progress, (later - cp.frontier) / window)
					break
				end
			end
		end
	end
	if #frontiers > 0 then
		local parts, bestRate, bestCycle = {}, 0, nil
		for _, lastWave in { 15, 25, 50, 75, 100, 150, 200 } do
			local list = byN[lastWave]
			if list and #list > 0 then
				local t = mean(list)
				local gain = IdleConfig.rebirthGain(lastWave)
				local rate = gain / (t / 3600)
				if rate > bestRate then
					bestRate, bestCycle = rate, { wave = lastWave, t = t }
				end
				table.insert(parts, `1..{lastWave} : {duration(t)} (+{IdleConfig.formatPercent(gain)} %, {string.format("%.1f", rate)} %/h)`)
			end
		end
		local wavesPerHour = mean(progress)
		local growth = if wavesPerHour then (IdleConfig.REWARD_GROWTH ^ wavesPerHour - 1) * 100 else nil
		out()
		out(`À {hour} h (record moyen : vague {math.floor(mean(frontiers) + 0.5)}) :`)
		out("  " .. table.concat(parts, "  |  "))
		if wavesPerHour then
			out(
				string.format(
					"  jeu normal : %.1f vagues/h -> revenu +%.0f %%/h ; meilleure boucle : +%.1f %%/h de bonus",
					wavesPerHour,
					growth,
					bestRate
				)
			)
		end
		table.insert(rebirthSummary, {
			hour = hour,
			bestRate = bestRate,
			growth = growth,
			bestCycle = bestCycle,
		})
	end
end
out()

----------------------------------------------------------------------
-- 8. Comparaison aux objectifs (affichée en premier)
----------------------------------------------------------------------
Report.section("objectifs")
out(string.rep("=", 100))
out(`COMPARAISON AUX OBJECTIFS DU MODE SOLO (scénario « {referenceId} » sauf mention ; moyenne de {options.seeds} graine(s))`)
out(string.rep("=", 100))
local rows = {}
local function row(goal: string, target: string, measured: string, verdict: string)
	table.insert(rows, { goal, target, measured, verdict })
end
local function between(value: number?, lo: number, hi: number, low: string?, high: string?): string
	if not value then
		return "PAS ATTEINT"
	elseif value < lo then
		return low or "TROP TÔT"
	elseif value > hi then
		return high or "TROP TARD"
	end
	return "OK"
end
local function reach(runs, wave)
	return Report.reachTime(runs, wave)
end
local function median(list)
	if #list == 0 then
		return nil
	end
	local sorted = table.clone(list)
	table.sort(sorted)
	return sorted[math.floor((#sorted + 1) / 2)]
end

-- Murs d'une tranche de vagues (toutes graines) : liste de { wave, seconds }, mur en cours compris.
local function wallsIn(runs, a: number, b: number, minSeconds: number)
	local list = {}
	for _, run in runs do
		for _, wall in run.walls do
			if wall.wave >= a and wall.wave <= b and wall.seconds >= minSeconds then
				table.insert(list, wall)
			end
		end
		local open = run.frontier + 1
		if run.openWall >= minSeconds and open >= a and open <= b then
			table.insert(list, { wave = open, seconds = run.openWall, open = true })
		end
	end
	return list
end
local function wallSummary(list)
	if #list == 0 then
		return "aucun mur", nil
	end
	local seconds, worst = {}, list[1]
	for _, wall in list do
		table.insert(seconds, wall.seconds)
		if wall.seconds > worst.seconds then
			worst = wall
		end
	end
	return `{#list} murs, médiane {duration(median(seconds))}, max {duration(worst.seconds)} (vague {worst.wave} {Report.waveTypeName(IdleConfig.waveType(worst.wave))})`,
		worst.seconds
end

-- Vagues 1 à 10
do
	local t10 = reach(reference, 10)
	local blocked = {}
	for _, run in reference do
		local total = 0
		for _, wall in run.walls do
			if wall.wave <= 10 then
				total += wall.seconds
			end
		end
		table.insert(blocked, total)
	end
	local b = mean(blocked)
	local verdict = between(t10 and t10 / 60, 4, 7, "TROP RAPIDE", "TROP LENT")
	if b >= 30 then
		verdict = if verdict == "OK" then "MUR" else verdict .. " + MUR"
	end
	row("Vagues 1 à 10 fluides", "4-7 min, sans mur", `vague 10 à {duration(t10)}, dont {duration(b)} bloqué`, verdict)
end

-- Premier vrai mur : vers les vagues 12-16, et court (1-3 min)
do
	local firstWalls, firstDurations = {}, {}
	for _, run in reference do
		for _, wall in run.walls do
			if wall.seconds >= 60 then
				table.insert(firstWalls, wall.wave)
				table.insert(firstDurations, wall.seconds)
				break
			end
		end
	end
	local firstWall = mean(firstWalls)
	local verdict = between(firstWall, 12, 16)
	if verdict == "OK" and mean(firstDurations) > 3 * 60 then
		verdict = "TROP LONG"
	end
	row(
		"Premier vrai mur (>= 1 min)",
		"vers les vagues 12-16, court (1-3 min)",
		if firstWall then `vague {table.concat(firstWalls, ", ")} ({duration(mean(firstDurations))} en moyenne)` else "aucun",
		verdict
	)
end

-- Vague 15 (pas de cible chiffrée : entre la vague 10 et la vague 25)
do
	local t15 = reach(reference, 15)
	row("Vague 15 (renaissance possible)", "à mesurer", duration(t15), "info")
end

-- Murs au début et plus tard. On juge la médiane (mur « typique ») et le mur que 80 % des murs ne dépassent
-- pas : un seul très long mur sur une graine ne doit pas tout faire rater, mais des murs longs trop souvent, si.
do
	local function percentile(list, p: number)
		local sorted = table.clone(list)
		table.sort(sorted)
		return sorted[math.max(1, math.ceil(#sorted * p))]
	end
	local function describe(list)
		local seconds, bossFree = {}, {}
		for _, wall in list do
			table.insert(seconds, wall.seconds)
			if IdleConfig.waveType(wall.wave) ~= "Boss" then
				table.insert(bossFree, wall.seconds)
			end
		end
		local text, _ = wallSummary(list)
		if #seconds == 0 then
			return text, nil, nil
		end
		text ..= ` ; 80 % des murs font moins de {duration(percentile(seconds, 0.8))}`
		if #bossFree > 0 and #bossFree < #seconds then
			text ..= ` ; médiane sans les boss {duration(median(bossFree))}`
		end
		return text, median(seconds), percentile(seconds, 0.8)
	end
	-- « UN PEU LONGS » seulement si la médiane ET les 80 % restent proches de la cible ; sinon « TROP LONGS »
	-- (une bonne médiane ne doit pas cacher 20 % de murs de plus d'une heure).
	local function judge(med: number?, p80: number?, okMedian: number, okP80: number): string
		if not med then
			return "OK"
		elseif med <= okMedian and p80 <= okP80 then
			return "OK"
		elseif med <= okMedian * 1.3 and p80 <= okP80 * 1.5 then
			return "UN PEU LONGS"
		end
		return "TROP LONGS"
	end
	local earlyText, earlyMedian, earlyP80 = describe(wallsIn(reference, 11, 30, 30))
	row("Murs du début (vagues 11-30)", "1-5 min de farm", earlyText, judge(earlyMedian, earlyP80, 5 * 60, 8 * 60))
	-- Deux tranches : sur 31-100 d'un bloc, les murs courts des vagues 31-70 cachaient les murs d'une heure
	-- et plus des vagues 71-100. Cible : ~10-20 min au plus, 80 % des murs sous 20 min.
	local midText, midMedian, midP80 = describe(wallsIn(reference, 31, 70, 30))
	row("Murs plus tard (vagues 31-70)", "~10-20 min au plus (80 % sous 20 min)", midText, judge(midMedian, midP80, 15 * 60, 20 * 60))
	local lateText, lateMedian, lateP80 = describe(wallsIn(reference, 71, 100, 30))
	row("Murs plus tard (vagues 71-100)", "~10-20 min au plus (80 % sous 20 min)", lateText, judge(lateMedian, lateP80, 15 * 60, 20 * 60))
	local afterText = describe(wallsIn(reference, 101, 100000, 30))
	row("Murs après la vague 100", "à mesurer (idle : ils s'allongent)", afterText, "info")
end

-- Murs variés : pas seulement les Seigneurs de guerre (murs d'au moins 1 min, vagues 11 à 100)
do
	local byType, all = {}, 0
	for _, run in reference do
		for _, wall in run.walls do
			if wall.seconds >= 60 and wall.wave >= 11 and wall.wave <= 100 then
				local waveType = IdleConfig.waveType(wall.wave)
				byType[waveType] = byType[waveType] or {}
				table.insert(byType[waveType], wall.seconds)
				all += 1
			end
		end
	end
	local parts, varied, bossHardest = {}, 0, true
	local bossMedian = if byType.Boss then median(byType.Boss) else 0
	for _, waveType in Report.WAVE_TYPE_ORDER do
		local list = byType[waveType]
		if list then
			local share = #list / all
			table.insert(parts, `{Report.waveTypeName(waveType)} {Report.pct(share)} (médiane {duration(median(list))})`)
			if share >= 0.1 then
				varied += 1
			end
			if waveType ~= "Boss" and median(list) > bossMedian then
				bossHardest = false
			end
		end
	end
	row(
		"Murs variés (pas que des boss)",
		"plusieurs types de vague ; les boss les plus durs",
		if all == 0 then "aucun mur d'au moins 1 min" else `murs d'au moins 1 min (vagues 11-100) par type : {table.concat(parts, ", ")}`,
		if all == 0 then "AUCUN MUR"
			elseif varied < 3 then `PEU VARIÉ ({varied} type(s))`
			elseif not bossHardest then "BOSS PAS LES PLUS DURS"
			else "OK"
	)
	-- Une seule fuite = vague ratée : les vagues rapides ou nombreuses (Charge, Levée) ne doivent pas devenir
	-- des murs absurdes. Leur médiane doit rester sous 1,5 fois celle des Escarmouches et des Gardes colossales.
	local others = {}
	for _, waveType in { "Mixed", "Giants" } do
		for _, seconds in byType[waveType] or {} do
			table.insert(others, seconds)
		end
	end
	local reference_ = if #others > 0 then median(others) else nil
	local texts, absurd = {}, {}
	for _, waveType in { "Rush", "Horde" } do
		local list = byType[waveType]
		if list and #list > 0 then
			table.insert(texts, `{Report.waveTypeName(waveType)} : {#list} murs, médiane {duration(median(list))}, max {duration(math.max(table.unpack(list)))}`)
			if reference_ and median(list) > 1.5 * reference_ then
				table.insert(absurd, Report.waveTypeName(waveType))
			end
		else
			table.insert(texts, `{Report.waveTypeName(waveType)} : aucun mur d'au moins 1 min`)
		end
	end
	row(
		"Une fuite = ratée : Charge et Levée pas absurdes",
		"murs de Charge et de Levée pas plus longs (médiane < 1,5x Escarmouche + Garde)",
		table.concat(texts, " ; ") .. (if reference_ then ` ; Escarmouche + Garde : médiane {duration(reference_)}` else ""),
		if #absurd > 0 then `TROP DURES ({table.concat(absurd, ", ")})` else "OK"
	)
end

-- Zone morte : longue période sans rien acheter
do
	local gaps, waves = {}, {}
	for _, run in reference do
		local gap = math.max(run.longestNoPurchase, run.endTime - run.lastPurchaseAt)
		table.insert(gaps, gap)
		table.insert(waves, tostring(if gap == run.longestNoPurchase then run.longestNoPurchaseAt else run.frontier + 1))
	end
	local _, hi = Report.minMax(gaps)
	row(
		"Pas de zone morte",
		"jamais 1 h sans achat utile",
		`plus longue période sans achat : {duration(mean(gaps))} en moyenne, max {duration(hi)} (vagues {table.concat(waves, ", ")})`,
		if hi >= 3600 then "ZONE MORTE" else "OK"
	)
end

-- Longue traîne
for _, target in { { 25, 0.5, 0.75, "30-45 min" }, { 50, 3, 6, "3-6 h" }, { 100, 15, 30, "15-30 h" } } do
	local wave = target[1]
	local cells = {}
	local refT, refN = reach(reference, wave)
	for _, id in options.scenarios do
		local t, n = reach(runsByScenario[id], wave)
		table.insert(cells, `{id} {if n == 0 then "jamais" else duration(t)}{if n > 0 and n < options.seeds then ` ({n}/{options.seeds})` else ""}`)
	end
	row(
		`Vague {wave}`,
		target[4],
		table.concat(cells, " ; "),
		if refN < #reference then (if refN == 0 then "PAS ATTEINT" else "PAS TOUJOURS ATTEINT") else between(refT / 3600, target[2], target[3])
	)
end

-- Emplacements
do
	local at50, at100, spotsEnd, lastSpotWave = {}, {}, {}, {}
	for _, run in reference do
		table.insert(spotsEnd, run.unlockedSpots)
		if run.firstClear[50] then
			table.insert(at50, run.firstClear[50].spots)
		end
		if run.firstClear[100] then
			table.insert(at100, run.firstClear[100].spots)
		end
		local info = run.spotTimes[#PlotLayout.SPOTS]
		if info then
			table.insert(lastSpotWave, info.wave)
		end
	end
	local parts = {}
	if #at50 > 0 then
		table.insert(parts, string.format("%.1f à la vague 50", mean(at50)))
	end
	if #at100 > 0 then
		table.insert(parts, string.format("%.1f à la vague 100", mean(at100)))
	end
	table.insert(parts, string.format("%.1f à la fin (%d h)", mean(spotsEnd), options.hours))
	if #lastSpotWave > 0 then
		table.insert(parts, `22e à la vague {math.floor(mean(lastSpotWave))}`)
	end
	row(
		"22 emplacements achetés peu à peu",
		"le dernier vers la vague 80-100",
		table.concat(parts, ", "),
		if #lastSpotWave == #reference then between(mean(lastSpotWave), 80, 100) else "TROP CHERS (22e jamais acheté)"
	)
end

-- Tours utiles (dégâts réels du joueur simulé)
do
	local maxShare = {}
	for _, run in reference do
		for _, damageRow in run.damage do
			local total = 0
			for _, v in damageRow do
				total += v
			end
			for towerType, v in damageRow do
				if total > 0 then
					maxShare[towerType] = math.max(maxShare[towerType] or 0, v / total)
				end
			end
		end
	end
	local parts, unused = {}, 0
	for _, towerType in IdleTowers.ORDER do
		local share = maxShare[towerType] or 0
		-- Totem de givre : tour de CONTRÔLE, ses dégâts sont faibles exprès (décision du propriétaire) ; il est
		-- jugé par l'objectif « Totem de givre : tour de contrôle » (posé, amélioré, fragilité), pas ici.
		local control = IdleTowers.Defs[towerType].fragilityBase ~= nil
		table.insert(parts, `{Run.shortName(towerType)} {Report.pct(share)}{if control then " (contrôle, jugé plus bas)" else ""}`)
		if share < 0.1 and not control then
			unused += 1
		end
	end
	row(
		"Les 8 tours utiles à un moment",
		"chacune >= 10 % des dégâts quelque part (sauf le Totem de givre, tour de contrôle)",
		"meilleure part des dégâts utiles (tranche x type de vague) : " .. table.concat(parts, ", "),
		if unused > 0 then `NON ({unused} tours jamais utiles)` else "OK"
	)
end

-- Banc d'essai : tours différentes selon le type de vague, tours dominées, légendaires
do
	local winners, winnerParts = {}, {}
	local dominatedEverywhere = { k = {}, kDupes = {} }
	for _, towerType in IdleTowers.ORDER do
		dominatedEverywhere.k[towerType] = true
		dominatedEverywhere.kDupes[towerType] = true
	end
	local legendaryRatios = {}
	local benchCount = 0
	for _, wave in BENCH_WAVES do
		local bench = benchResults[wave]
		if bench then
			benchCount += 1
			local names = {}
			for _, waveType in Report.WAVE_TYPE_ORDER do
				for _, towerType in IdleTowers.ORDER do
					local cell = bench.cells[towerType][waveType]
					if not cell.tooExpensive and cell.k <= bench.bestK[waveType] then
						winners[towerType] = true
						table.insert(names, `{string.sub(waveType, 1, 1)}:{Run.shortName(towerType)}`)
						break
					end
				end
			end
			table.insert(winnerParts, `v{wave} {table.concat(names, " ")}`)
			-- Tour dominée : une autre tour fait mieux contre tous les types de vague, sans doublons (k) et avec
			-- les doublons moyens du joueur simulé à ce moment (kDupes : les communes en ont des centaines, les
			-- légendaires, rares, presque aucun).
			for _, key in { "k", "kDupes" } do
				for _, towerType in IdleTowers.ORDER do
					local mine = bench.cells[towerType]
					local dominated = false
					if mine[Report.WAVE_TYPE_ORDER[1]].tooExpensive then
						dominated = true
					else
						for _, other in IdleTowers.ORDER do
							if other ~= towerType and not bench.cells[other][Report.WAVE_TYPE_ORDER[1]].tooExpensive then
								local better = true
								for _, waveType in Report.WAVE_TYPE_ORDER do
									if bench.cells[other][waveType][key] >= mine[waveType][key] then
										better = false
										break
									end
								end
								if better then
									dominated = true
									break
								end
							end
						end
					end
					-- Utile en soutien (3 tours principales + celle-ci font mieux que 4 principales) : pas dominée
					if not mine[Report.WAVE_TYPE_ORDER[1]].tooExpensive then
						for _, waveType in Report.WAVE_TYPE_ORDER do
							if (mine[waveType].support or 0) > 100 then
								dominated = false
							end
						end
					end
					if not dominated then
						dominatedEverywhere[key][towerType] = false
					end
				end
			end
			-- Légendaires contre les autres
			if wave >= 50 then
				for _, waveType in Report.WAVE_TYPE_ORDER do
					local bestLegendary, bestOther = math.huge, math.huge
					for _, towerType in IdleTowers.ORDER do
						local cell = bench.cells[towerType][waveType]
						if not cell.tooExpensive then
							if IdleTowers.Defs[towerType].rarity == "Legendary" then
								bestLegendary = math.min(bestLegendary, cell.k)
							else
								bestOther = math.min(bestOther, cell.k)
							end
						end
					end
					if bestLegendary < math.huge and bestOther < math.huge then
						table.insert(legendaryRatios, bestOther / bestLegendary)
					end
				end
			end
		end
	end
	local count = 0
	for _ in winners do
		count += 1
	end
	if benchCount > 0 then
		row(
			"Chaque type de vague a sa tour",
			"Horde, Rush, Géants, Boss favorisent des tours différentes",
			`meilleure tour au banc d'essai (M/H/R/G/B = Escarmouche/Horde/Rush/Géants/Boss) : {table.concat(winnerParts, " ; ")}`,
			if count >= 3 then `OK ({count} tours différentes)` else `PEU VARIÉ ({count} tour(s))`
		)
		local function dominatedList(key: string)
			local names = {}
			for _, towerType in IdleTowers.ORDER do
				if dominatedEverywhere[key][towerType] then
					table.insert(names, Run.shortName(towerType))
				end
			end
			return names
		end
		local withoutDupes, withDupes = dominatedList("k"), dominatedList("kDupes")
		row(
			"Aucune tour dominée pour toujours",
			"pas de tour moins bonne partout, tout le temps (avec les doublons du joueur : ce qu'il a vraiment en main)",
			`moins bonnes qu'une autre tour contre tous les types de vague, et inutiles en soutien, à chaque vague du banc d'essai : `
				.. `avec les doublons du joueur : {if #withDupes > 0 then table.concat(withDupes, ", ") else "aucune"} ; `
				.. `sans doublons : {if #withoutDupes > 0 then table.concat(withoutDupes, ", ") else "aucune"}`,
			if #withDupes > 0 then "NON" elseif #withoutDupes > 0 then "OK (avec doublons)" else "OK"
		)
		if #legendaryRatios > 0 then
			local lo, hi = Report.minMax(legendaryRatios)
			row(
				"Légendaires fortes, pas écrasantes",
				"meilleures sans écraser (x1 à x3)",
				string.format("à budget égal (vagues 50+), meilleure légendaire = x%.2f à x%.2f la meilleure autre tour selon le type", lo, hi),
				if hi < 1 then "TROP FAIBLES" elseif lo > 3 then "ÉCRASANTES" else "OK"
			)
		end
	end
end

-- Totem de givre : il doit VRAIMENT ralentir et faire de vrais dégâts (demande du propriétaire), donc valoir
-- sa place : posé par le joueur simulé, une vraie part des dégâts quelque part, fort au banc d'essai.
do
	local frost = IdleTowers.Defs.Frost
	-- Meilleure part des dégâts utiles (tranche x type de vague) et nombre moyen de Totems posés aux jalons
	local bestShare, bestKey = 0, "-"
	for _, run in reference do
		for key, damageRow in run.damage do
			local total = 0
			for _, v in damageRow do
				total += v
			end
			if total > 0 and (damageRow.Frost or 0) / total > bestShare then
				bestShare, bestKey = damageRow.Frost / total, key
			end
		end
	end
	local placed = {}
	for _, wave in { 10, 25, 50, 100 } do
		local counts = {}
		for _, run in reference do
			local snap = run.firstClear[wave]
			if snap then
				table.insert(counts, if snap.byType.Frost then snap.byType.Frost.n else 0)
			end
		end
		if #counts > 0 then
			table.insert(placed, string.format("v%d : %.1f", wave, mean(counts)))
		end
	end
	-- Banc d'essai : meilleure puissance (seul) et meilleur soutien du Totem
	local benchParts, bestPower, bestSupport = {}, 0, 0
	for _, wave in BENCH_WAVES do
		local bench = benchResults[wave]
		if bench then
			local powerMax, supportMax, powerType = 0, 0, "-"
			for _, waveType in Report.WAVE_TYPE_ORDER do
				local cell = bench.cells.Frost[waveType]
				if not cell.tooExpensive then
					if (cell.power or 0) > powerMax then
						powerMax, powerType = cell.power, Report.waveTypeName(waveType)
					end
					supportMax = math.max(supportMax, cell.support or 0)
				end
			end
			bestPower = math.max(bestPower, powerMax)
			bestSupport = math.max(bestSupport, supportMax)
			table.insert(benchParts, `v{wave} {math.floor(powerMax + 0.5)} ({powerType}) / soutien {math.floor(supportMax + 0.5)}`)
		end
	end
	-- Tour de CONTRÔLE : posée et améliorée (la fragilité monte avec son niveau), utile en soutien, et ses
	-- propres dégâts ne dépassent jamais ceux de la Catapulte contre une foule (même niveau).
	local levels = {}
	for _, wave in { 25, 50, 75, 100, 150 } do
		local list = {}
		for _, run in reference do
			local snap = run.firstClear[wave]
			if snap and snap.byType.Frost then
				table.insert(list, snap.byType.Frost.max)
			end
		end
		if #list > 0 then
			local level = medianOf(list)
			table.insert(levels, string.format("v%d niv %d (+%.0f %%)", wave, level, IdleTowers.fragilityAt(frost, level) * 100))
		end
	end
	local crowdRatio = duelResults.crowd and duelResults.crowd.Frost or 0
	row(
		"Totem de givre : tour de contrôle",
		"posé et amélioré (fragilité), utile en soutien (> 100), dégâts contre une foule < Catapulte (même niveau)",
		string.format(
			"-%d %% de vitesse pendant %.1f s, %s dégâts/s en zone, fragilité +%.0f %% +%.1f %%/niveau (max +%.0f %%) ; Totems posés %s ; plus haut niveau %s ; foule : %.2f x la Catapulte ; meilleure part des dégâts %s (%s) ; banc d'essai (seul / soutien) : %s",
			math.floor(frost.slow * 100 + 0.5),
			frost.slowDuration,
			shortNumber(frost.damage / frost.cooldown),
			frost.fragilityBase * 100,
			frost.fragilityPerLevel * 100,
			frost.fragilityMax * 100,
			table.concat(placed, ", "),
			table.concat(levels, ", "),
			crowdRatio,
			Report.pct(bestShare),
			bestKey,
			table.concat(benchParts, " ; ")
		),
		if bestSupport > 100 and crowdRatio < 1 and #levels > 0 then "OK" elseif crowdRatio >= 1 then "TROP DE DÉGÂTS" else "PAS ASSEZ UTILE"
	)
end

-- Baliste lourde et Trébuchet royal : utiles à partir du milieu de partie (part des dégâts et niveaux).
-- Appelé plus bas, après la définition de towerShare (passée en paramètre).
local function midGameRow(towerShare)
	local parts, ok = {}, true
	for _, towerType in { "Rocket", "Orbital" } do
		local shares = {}
		for _, bucket in { "26-50", "51-100", "101+" } do
			local best = 0
			for _, waveType in Report.WAVE_TYPE_ORDER do
				local share = towerShare(reference, bucket, waveType, towerType)
				if share and share == share and share > best then
					best = share
				end
			end
			table.insert(shares, `{bucket} : {Report.pct(best)}`)
			if bucket == "51-100" and best < 0.1 then
				ok = false
			end
		end
		local levels = {}
		for _, wave in { 50, 75, 100, 150 } do
			local counts, maxLevels = {}, {}
			for _, run in reference do
				local snap = run.firstClear[wave]
				if snap then
					local entry = snap.byType[towerType]
					table.insert(counts, if entry then entry.n else 0)
					table.insert(maxLevels, if entry then entry.max else 0)
				end
			end
			if #counts > 0 then
				table.insert(levels, string.format("v%d : %.1f posé(s), niv %d", wave, mean(counts), medianOf(maxLevels)))
			end
		end
		table.insert(parts, `{Run.shortName(towerType)} : meilleure part des dégâts {table.concat(shares, ", ")} ; {table.concat(levels, ", ")}`)
	end
	row(
		"Baliste et Trébuchet utiles au milieu de partie",
		">= 10 % des dégâts contre un type de vague (vagues 51-100)",
		table.concat(parts, " || "),
		if ok then "OK" else "NON"
	)
end

-- Part moyenne des dégâts utiles d'une tour sur un type de vague, dans une tranche (chaque partie compte autant).
local function towerShare(runs, bucket: string, waveType: string, towerType: string): number?
	local shares = {}
	for _, run in runs do
		local damageRow = run.damage[bucket .. "|" .. waveType]
		if damageRow then
			local total = 0
			for _, v in damageRow do
				total += v
			end
			if total > 0 then
				table.insert(shares, (damageRow[towerType] or 0) / total)
			end
		end
	end
	return mean(shares)
end
midGameRow(towerShare)

-- Puissance relative (banc d'essai) : k de la Baliste / k du Sorcier (> 1 = le Sorcier est plus fort).
local function benchRatio(bench, towerType: string, other: string, waveType: string): number?
	local mine, theirs = bench.cells[towerType][waveType], bench.cells[other][waveType]
	if mine.tooExpensive or theirs.tooExpensive then
		return nil
	elseif mine.k == math.huge then
		return 0
	elseif theirs.k == math.huge then
		return math.huge
	end
	return theirs.k / mine.k
end

local BUCKETS_ORDER = { "1-25", "26-50", "51-100", "101+" }

-- Sorcier des arcanes (rayon) : à niveau égal, plus fort que la Baliste lourde contre les ennemis lents (boss,
-- colosse, chevaliers lourds), bien moins bon contre les rapides (demande du propriétaire).
do
	local alone, frost = duelResults.alone.Laser, duelResults.frost.Laser
	local parts, rushWorst, giantsWorst = {}, 0, math.huge
	for _, wave in BENCH_WAVES do
		local bench = benchResults[wave]
		if bench and wave >= 25 then
			local giants, boss, rush = benchRatio(bench, "Laser", "Rocket", "Giants"), benchRatio(bench, "Laser", "Rocket", "Boss"), benchRatio(bench, "Laser", "Rocket", "Rush")
			if giants and boss and rush then
				table.insert(parts, string.format("v%d : colosse x%.2f, boss x%.2f, cavalerie x%.2f", wave, giants, boss, rush))
				rushWorst = math.max(rushWorst, rush)
				giantsWorst = math.min(giantsWorst, giants)
			end
		end
	end
	local slowMin = math.min(alone.Boss, alone.Giant, alone.Tank)
	row(
		"Sorcier : bat la Baliste contre les lents",
		"duel à niveau égal : boss, colosse et chevalier lourd >= x1,2 la Baliste ; cavalier <= x0,8 ; banc d'essai : Charge <= x0,8, colosse > x1",
		string.format(
			"duel : boss x%.2f, colosse x%.2f, chevalier lourd x%.2f, fantassin x%.2f, cavalier x%.2f, écuyer x%.2f ; avec un Totem : boss x%.2f, colosse x%.2f, cavalier x%.2f ; banc d'essai (Sorcier / Baliste) : %s",
			alone.Boss, alone.Giant, alone.Tank, alone.Normal, alone.Fast, alone.Swarm, frost.Boss, frost.Giant, frost.Fast,
			if #parts > 0 then table.concat(parts, " ; ") else "-"
		),
		if slowMin < 1.2 then "PAS ASSEZ FORT CONTRE LES LENTS"
			elseif alone.Fast > 0.8 or rushWorst > 0.8 then "TROP FORT CONTRE LES RAPIDES"
			elseif giantsWorst <= 1 then "PAS MIEUX QUE LA BALISTE (colosse)"
			else "OK"
	)
end

-- Sorcier : pas de victoire automatique contre les boss. Sur les vagues de boss, il ne doit pas faire la majorité
-- des dégâts dans toutes les tranches ; les murs de boss et de colosses restent de vrais murs (comparés au
-- scénario « sans-sorcier » quand il a tourné).
do
	local shareParts, majority, reached = {}, 0, 0
	for _, bucket in BUCKETS_ORDER do
		local boss = towerShare(reference, bucket, "Boss", "Laser")
		local giants = towerShare(reference, bucket, "Giants", "Laser")
		if boss then
			reached += 1
			if boss > 0.5 then
				majority += 1
			end
			table.insert(shareParts, `{bucket} : boss {Report.pct(boss)}, colosse {if giants then Report.pct(giants) else "-"}`)
		end
	end
	-- Murs d'au moins 30 s par type (vagues 11 à 150) : nombre de vagues de ce type qui ont bloqué et médiane.
	local function wallsOf(runs, waveType: string)
		local list, reachedWaves = {}, 0
		for _, run in runs do
			for wave = 11, math.min(150, run.frontier) do
				if IdleConfig.waveType(wave) == waveType then
					reachedWaves += 1
				end
			end
			for _, wall in run.walls do
				if wall.wave >= 11 and wall.wave <= 150 and wall.seconds >= 30 and IdleConfig.waveType(wall.wave) == waveType then
					table.insert(list, wall.seconds)
				end
			end
		end
		return median(list), #list, reachedWaves
	end
	local wallParts, collapsed = {}, false
	local without = runsByScenario["sans-sorcier"]
	for _, waveType in { "Boss", "Giants" } do
		local med, count, waves = wallsOf(reference, waveType)
		local text = `{Report.waveTypeName(waveType)} : {count}/{waves} vagues bloquent, médiane {duration(med)}`
		if without then
			local medWithout, countWithout, wavesWithout = wallsOf(without, waveType)
			text ..= ` (sans Sorcier : {countWithout}/{wavesWithout}, médiane {duration(medWithout)})`
			if medWithout and (not med or med < 0.3 * medWithout) then
				collapsed = true
			end
		end
		table.insert(wallParts, text)
	end
	row(
		"Sorcier : pas d'autowin contre les boss",
		"sur les vagues de boss, pas la majorité des dégâts dans toutes les tranches ; murs de boss et de colosses pas écrasés (>= 30 % de ceux sans Sorcier)",
		`part du Sorcier (dégâts utiles) : {table.concat(shareParts, " ; ")} ; murs (vagues 11-150) : {table.concat(wallParts, " ; ")}`
			.. (if without then "" else " ; (lance aussi le scénario « sans-sorcier » pour comparer)"),
		if reached >= 2 and majority == reached then "TROP FORT (majorité partout)" elseif collapsed then "MURS ÉCRASÉS" else "OK"
	)
end

-- Archer du rempart et Mage des tempêtes : ni l'un ni l'autre ne doit être la tour la plus faible, chacun a un
-- domaine où il fait partie des meilleurs choix, et le joueur simulé les garde (améliorés) après la vague 40.
do
	local function describe(towerType: string)
		-- Banc d'essai (vagues 50+) : types de vague où elle est dans les 3 meilleures (puissance >= 60),
		-- et vagues où elle est la plus faible en moyenne (moyenne géométrique des 5 types).
		local niches, weakestAt = {}, {}
		for _, wave in BENCH_WAVES do
			local bench = benchResults[wave]
			if bench and wave >= 50 then
				local means = {}
				for _, tt in IdleTowers.ORDER do
					local cells = bench.cells[tt]
					if not cells.Mixed.tooExpensive then
						local total = 0
						for _, waveType in Report.WAVE_TYPE_ORDER do
							total += math.log(math.max(cells[waveType].power or 0, 0.1))
						end
						means[tt] = total / #Report.WAVE_TYPE_ORDER
					end
				end
				local lowest, lowestValue = nil, math.huge
				for tt, value in means do
					if value < lowestValue then
						lowest, lowestValue = tt, value
					end
				end
				if lowest == towerType then
					table.insert(weakestAt, `v{wave}`)
				end
				-- Rang parmi les tours non légendaires (celles que le joueur a presque tout le temps : la première
				-- légendaire arrive vers la vague 60-90), puissance >= 60 % de la meilleure de ces tours.
				for _, waveType in Report.WAVE_TYPE_ORDER do
					local cell = bench.cells[towerType][waveType]
					if not cell.tooExpensive then
						local rank, bestK = 1, cell.k
						for _, tt in IdleTowers.ORDER do
							local other = bench.cells[tt][waveType]
							if tt ~= towerType and not other.tooExpensive and IdleTowers.Defs[tt].rarity ~= "Legendary" then
								if other.k < cell.k then
									rank += 1
								end
								bestK = math.min(bestK, other.k)
							end
						end
						if rank <= 3 and bestK / cell.k >= 0.6 then
							table.insert(niches, `v{wave} {Report.waveTypeName(waveType)} ({rank}e)`)
						end
					end
				end
			end
		end
		-- Joueur simulé : meilleure part des dégâts après la vague 40 (tranches 51-100 et 101+ ; 26-50 à part)
		-- et nombre posé / niveau moyen aux vagues 50, 75, 100.
		local bestLate, bestLateKey = 0, "-"
		for _, bucket in { "51-100", "101+" } do
			for _, waveType in Report.WAVE_TYPE_ORDER do
				local share = towerShare(reference, bucket, waveType, towerType)
				if share and share > bestLate then
					bestLate, bestLateKey = share, `{bucket} {Report.waveTypeName(waveType)}`
				end
			end
		end
		local mid = 0
		for _, waveType in Report.WAVE_TYPE_ORDER do
			mid = math.max(mid, towerShare(reference, "26-50", waveType, towerType) or 0)
		end
		local placed = {}
		for _, wave in { 50, 75, 100, 150 } do
			local counts, levels = {}, {}
			for _, run in reference do
				local snap = run.firstClear[wave]
				if snap then
					local entry = snap.byType[towerType]
					table.insert(counts, if entry then entry.n else 0)
					if entry then
						table.insert(levels, (entry.min + entry.max) / 2)
					end
				end
			end
			if #counts > 0 then
				table.insert(placed, string.format("v%d : %.1f posé(s)%s", wave, mean(counts), if #levels > 0 then string.format(" niv %.0f", mean(levels)) else ""))
			end
		end
		local text = `{Run.shortName(towerType)} : banc d'essai, dans les 3 meilleures (hors légendaires) : {if #niches > 0 then table.concat(niches, ", ") else "nulle part"}`
			.. (if #weakestAt > 0 then ` ; LA PLUS FAIBLE en moyenne à {table.concat(weakestAt, ", ")}` else " ; jamais la plus faible en moyenne")
			.. ` ; part des dégâts : {Report.pct(mid)} (26-50), {Report.pct(bestLate)} après la vague 50 ({bestLateKey}) ; {table.concat(placed, ", ")}`
		local ok = #niches > 0 and #weakestAt == 0 and math.max(bestLate, mid) >= 0.1
		return text, ok
	end
	local archerText, archerOk = describe("MachineGun")
	local mageText, mageOk = describe("Tesla")
	row(
		"Archer et Mage : pas les plus faibles",
		"jamais la tour la plus faible (banc d'essai, vagues 50+), dans les 3 meilleures (hors légendaires) contre un type de vague, >= 10 % des dégâts du joueur après la vague 40",
		archerText .. " || " .. mageText,
		if archerOk and mageOk then "OK" elseif not archerOk and not mageOk then "NON (Archer, Mage)" elseif not archerOk then "NON (Archer)" else "NON (Mage)"
	)
end

-- Anti-méta : le mélange du joueur va plus loin que chaque composition extrême (tableau « ANTI-MÉTA »).
do
	local parts, allOk, any = {}, true, false
	for _, hour in ANTI_META_HOURS do
		local summary = antiMeta[hour]
		if summary then
			any = true
			if summary.mixed <= summary.bestExtreme then
				allOk = false
			end
			-- « ! » : cet extrême dépasse la limite de tours identiques (impossible en jeu, voir le tableau ANTI-MÉTA).
			local mark = if summary.over and summary.over[summary.bestExtremeName] then " !" else ""
			table.insert(parts, `{hour} h : mélange {summary.mixed}, meilleur extrême {summary.bestExtremeName}{mark} {summary.bestExtreme}`)
		end
	end
	if any then
		row(
			"Anti-méta : le mélange bat les extrêmes",
			"le mélange va plus loin que tout Trébuchet, tout givre, Trébuchet + givre, tout Sorcier, tout Catapulte, givre + Mage... (« ! » = extrême impossible en jeu depuis la limite de tours identiques)",
			table.concat(parts, " ; "),
			if allOk then "OK" else "NON"
		)
	end
end

-- Tours légendaires (dorées) rares : la première vers les vagues 60-90 (plusieurs heures de jeu), pas avant ~50 ;
-- ensuite, peu de chances même aux records hauts.
do
	local times, waves = {}, {}
	for _, run in reference do
		local first = firstLegendary(run)
		if first then
			table.insert(times, first.t)
			table.insert(waves, first.wave)
		end
	end
	local topOdds = 0
	local oddsParts = {}
	for _, tier in IdleConfig.TOWER_SPIN_TIERS do
		local total = 0
		for _, rarity in IdleConfig.RARITY_ORDER do
			total += tier.odds[rarity] or 0
		end
		local legendary = (tier.odds.Legendary or 0) / total * 100
		topOdds = math.max(topOdds, legendary)
		table.insert(oddsParts, `v{tier.minWave} : {IdleConfig.formatPercent(legendary)} %`)
	end
	local medianWave = medianOf(waves)
	local lowest = if #waves > 0 then math.min(table.unpack(waves)) else nil
	row(
		"Légendaires rares",
		"1re légendaire vers les vagues 60-90 (plusieurs heures), pas avant ~50 ; ensuite <= 6 % de chances",
		(if #times > 0
				then `1re légendaire vers {duration(medianOf(times))}, vague {medianWave} (médiane ; vagues {table.concat(waves, ", ")})`
				else "aucune légendaire")
			.. ` ; chances de Légendaire par palier : {table.concat(oddsParts, ", ")}`,
		if topOdds > 6 then "TROP DE CHANCES"
			elseif not medianWave then "JAMAIS"
			elseif medianWave < 55 or (lowest and lowest < 40) then "TROP TÔT"
			elseif medianWave > 95 then "TROP TARD"
			else "OK"
	)
end

-- Autel des héros : acheté régulièrement (déblocages au début, doublons ensuite) sans être le seul achat ;
-- les gros lots (x100, x1 000, x10 000) doivent servir aux joueurs avancés ; x1 000 000 reste presque impossible.
do
	-- Par tranche de vagues : part des pièces dépensées à l'autel et nombre d'achats pour 10 vagues
	-- (« régulièrement » = au moins 2 achats toutes les 10 vagues, dans chaque tranche atteinte).
	local BUCKETS = { { "1-25", 1, 25 }, { "26-50", 26, 50 }, { "51-100", 51, 100 }, { "101+", 101, math.huge } }
	local shares, parts, rates = {}, {}, {}
	for _, info in BUCKETS do
		local bucket = info[1]
		local list, perTen = {}, {}
		for _, run in reference do
			local spent = run.spentByBucket[bucket]
			if spent then
				local total = 0
				for _, amount in spent do
					total += amount
				end
				if total > 0 then
					table.insert(list, spent.spin / total)
				end
			end
			local waves = math.min(run.frontier, info[3]) - info[2] + 1
			if waves >= 5 then
				table.insert(perTen, (run.spinBuysByBucket[bucket] or 0) / waves * 10)
			end
		end
		if #list > 0 then
			shares[bucket] = mean(list)
			rates[bucket] = mean(perTen) or 0
			table.insert(parts, `{bucket} : {Report.pct(shares[bucket])} des pièces, {string.format("%.1f", rates[bucket])} achats / 10 vagues`)
		end
	end
	-- Gros lots : combien de parties les achètent (tous scénarios), à quel record le premier achat, combien de
	-- fois. x100, x1 000 et x10 000 doivent servir aux joueurs avancés (le scénario de référence ou un autre) ;
	-- x1 000 000 peut rester presque impossible (chaque lancer coûte +0,05 % de plus que le précédent).
	local bulkParts, bigUnused = {}, {}
	for _, bulk in IdleConfig.TOWER_SPIN_BULKS do
		local buyers, total, firstWaves, buys = 0, 0, {}, 0
		for _, id in options.scenarios do
			for _, run in runsByScenario[id] do
				total += 1
				local info = run.spinBuys[bulk.count]
				if info then
					buyers += 1
					buys += info.n
					table.insert(firstWaves, info.firstWave)
				end
			end
		end
		table.insert(
			bulkParts,
			`x{Modules.NumberFormat.short(bulk.count)} : {buyers}/{total} parties`
				.. (if buyers > 0 then `, {shortNumber(buys / buyers)} achats chacune, 1er au record {medianOf(firstWaves)}` else "")
		)
		if bulk.count >= 100 and bulk.count <= 10000 and buyers == 0 then
			table.insert(bigUnused, `x{Modules.NumberFormat.short(bulk.count)}`)
		end
	end
	local regular, dominant = true, false
	for bucket, share in shares do
		if rates[bucket] < 2 then
			regular = false
		end
		if share > 0.7 then
			dominant = true
		end
	end
	row(
		"Autel des héros acheté régulièrement",
		"acheté à chaque étape (>= 2 achats / 10 vagues), pas le seul achat (<= 70 % des pièces), x100 / x1 000 / x10 000 achetés par les joueurs avancés (x1 M : défi presque impossible)",
		`par tranche (référence) : {table.concat(parts, " ; ")} ; lots (tous scénarios) : {table.concat(bulkParts, " ; ")}`,
		if not regular then "PAS ASSEZ ACHETÉ"
			elseif dominant then "TROP DOMINANT"
			elseif #bigUnused > 0 then `GROS LOTS JAMAIS ACHETÉS ({table.concat(bigUnused, ", ")})`
			else "OK"
	)
end

-- Grands nombres : au moins des trillions (T) par minute vers 80-90 h de jeu
do
	local parts = {}
	for _, hour in { 25, 50, 80, 90, 100 } do
		local money = hour <= options.hours and moneyAt(reference, hour)
		if money then
			table.insert(parts, `{hour} h : {coins(money.income)}/min (vague {money.frontier})`)
		end
	end
	local tHour, tCount = hourReaching(reference, 1e12)
	local check = moneyAt(reference, 90) or moneyAt(reference, 80)
	row(
		"Grands nombres (des trillions vers 80-90 h)",
		"revenu d'au moins 1 T par minute vers 80-90 h, puis ça explose",
		`revenu par minute : {if #parts > 0 then table.concat(parts, ", ") else "(simulation trop courte)"} ; 1 T/min vers {if tCount > 0 then duration(tHour * 3600) else "jamais"}`,
		if not check then "À MESURER (-Heures 100)" elseif check.income >= 1e12 then "OK" else "TROP PETIT"
	)
end

-- Aucun montant ne devient infini avant la vague 1500 et le niveau 1000
row(
	"Nombres finis (pas d'infini)",
	"PV, pièces et prix finis jusqu'à la vague 1500 et au niveau 1000",
	(if overflow.wave then `vagues : infinies à partir de la {overflow.wave}` else "vagues : toujours finies (vérifié jusqu'à la 1 000 000)")
		.. (if overflow.level then ` ; améliorations : infinies à partir du niveau {overflow.level}` else " ; améliorations : toujours finies"),
	if (overflow.wave and overflow.wave <= 1500) or (overflow.level and overflow.level <= 1000) or not overflow.spots then "INFINI TROP TÔT" else "OK"
)

-- Renaissance
do
	local base, solo = runsByScenario.base, runsByScenario["renaissance-seule"]
	if base and solo then
		local function finalWave(runs)
			local list = {}
			for _, run in runs do
				table.insert(list, run.frontier)
			end
			return mean(list)
		end
		local bonuses, rebirths, spinsSolo, spinsBase = {}, {}, {}, {}
		for _, run in solo do
			table.insert(bonuses, run.coinBonus)
			table.insert(rebirths, run.rebirths)
			table.insert(spinsSolo, run.spins)
		end
		for _, run in base do
			table.insert(spinsBase, run.spins)
		end
		-- Accélération : temps moyen de base / temps avec renaissance, au plus haut jalon atteint par les deux
		local speedup, atWave = nil, nil
		for _, wave in Report.MILESTONES do
			local tB, nB = reach(base, wave)
			local tR, nR = reach(solo, wave)
			if nB == #base and nR == #solo and wave >= 25 then
				speedup, atWave = tB / tR, wave
			end
		end
		row(
			"Renaissance : bonus petit mais utile",
			"+1 % (v15), +4 % (v50), +7 % (v100)",
			string.format(
				"renaissance-seule : %.0f renaissances, bonus +%s %% ; record à %d h : %.0f contre %.0f sans ; %s ; lancers de l'autel achetés x%.1f",
				mean(rebirths),
				IdleConfig.formatPercent(mean(bonuses)),
				options.hours,
				finalWave(solo),
				finalWave(base),
				if speedup then string.format("vague %d %.0f %% plus tôt", atWave, (1 - 1 / speedup) * 100) else "pas de jalon commun",
				mean(spinsSolo) / math.max(1, mean(spinsBase))
			),
			-- Règle voulue par le propriétaire (renaître aussi souvent qu'on veut) : on la mesure sans la juger.
			"info : " .. (if not speedup then "?" elseif speedup > 1.3 then "forte" elseif speedup < 1.03 then "presque sans effet" else "modérée")
		)
		local cycles = {}
		for _, run in solo do
			for _, entry in run.rebirthLog do
				if entry.cycle then
					table.insert(cycles, entry.cycle)
				end
			end
		end
		if #cycles > 0 then
			row("Durée d'un cycle de renaissance", "à mesurer", `revenir au record après une renaissance : {duration(mean(cycles))} en moyenne ({#cycles} cycles)`, "info")
		end
	end
	local parts, loopBetter = {}, 0
	for _, summary in rebirthSummary do
		if summary.growth then
			table.insert(parts, string.format("%d h : +%.1f contre +%.0f %%/h", summary.hour, summary.bestRate, summary.growth))
			if summary.bestRate > summary.growth then
				loopBetter += 1
			end
		end
	end
	if #parts > 0 then
		row(
			"Farmer les renaissances",
			"à mesurer (accepté même si la boucle rapporte plus)",
			"boucle contre jeu normal (bonus de pièces contre hausse du revenu) : " .. table.concat(parts, " ; "),
			-- Accepté par le propriétaire : renaître en boucle peut rapporter plus que progresser. Mesuré, pas jugé.
			if loopBetter > 0 then `info : boucle mieux payée ({loopBetter} fois, accepté)` else "info"
		)
	end
end

-- Forge (machine à bonus)
if runsByScenario.forge and runsByScenario.base then
	local function finalWave(runs)
		local list = {}
		for _, run in runs do
			table.insert(list, run.frontier)
		end
		return mean(list)
	end
	row(
		"Forge runique (100 K, x5 puis x2, sans délai)",
		"option (pas d'objectif chiffré)",
		string.format("record à %d h : %.0f avec la forge contre %.0f sans", options.hours, finalWave(runsByScenario.forge), finalWave(runsByScenario.base)),
		"info"
	)
end

-- Un bloc par objectif (plus lisible qu'un tableau très large)
local okCount, checked = 0, 0
for index, r in rows do
	local goal, target, measured, verdict = r[1], r[2], r[3], r[4]
	if string.sub(verdict, 1, 4) ~= "info" then
		checked += 1
		if verdict == "OK" or string.sub(verdict, 1, 3) == "OK " then
			okCount += 1
		end
	end
	local title = string.format("%2d. %s ", index, goal)
	local dots = math.max(3, 60 - (utf8.len(title) or #title))
	out(title .. string.rep(".", dots) .. " " .. verdict)
	out("    cible  : " .. target)
	out("    mesuré : " .. measured)
end
out()
out(`=> {okCount} objectif(s) atteint(s) sur {checked}.`)
out()
out("Hypothèses : joueur connecté en continu et actif (ramasse tout, achète entre les vagues, lancers de l'autel compris),")
out("sans Robux. Les scénarios « forge » et « renaissance » ajoutent la forge runique en pièces et/ou la renaissance (voir README).")
out()

Report.section("fin")
table.insert(order, "fin")
out(string.format("Calcul total : %.0f s.", os.clock() - started))
Report.flush(order)

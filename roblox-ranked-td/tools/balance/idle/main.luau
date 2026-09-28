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
	hours = 100,
	scenarios = { "base", "forge", "renaissance", "renaissance-seule" },
	dt = 0.05,
	overrides = {},
	journal = false,
}
for _, arg in { ... } do
	local key, value = string.match(arg, "^([%w_]+)=(.*)$")
	if key == "graines" then
		options.seeds = assert(tonumber(value), "graines : nombre attendu")
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

for _, item in playerOverrides do
	if not applyOverride(item, { Joueur = Run.POLICY }) then
		error(`module inconnu dans « {item} » : IdleConfig, IdleTowers, PlotLayout, Enemies ou Joueur`)
	end
end
for _, id in options.scenarios do
	assert(Run.SCENARIOS[id], `scénario inconnu : {id} (base, forge, renaissance, renaissance-seule)`)
end

Engine.DT = options.dt
local IdleConfig = Modules.IdleConfig
local IdleTowers = Modules.IdleTowers
local PlotLayout = Modules.PlotLayout
local out, duration, mean, coins = Report.out, Report.duration, Report.mean, Report.coins
local shortNumber = Report.shortNumber

----------------------------------------------------------------------
-- 1. Les parties
----------------------------------------------------------------------
local CHECKPOINTS = { 2, 5, 10, 20, 30, 40, 60, 80 }
local runsByScenario = {}
local started = os.clock()
Report.csvHeader()
for scenarioIndex, scenarioId in options.scenarios do
	local runs = {}
	for seed = 1, options.seeds do
		local run = Run.new(scenarioId, seed)
		run.hourly = {} -- [heure] = record
		run.hourlySpins = {} -- [heure] = lancers de la machine à tours depuis le début
		run.hourlyMoney = {} -- [heure] = { coins, income (par seconde), total gagné, record }
		run.checkpoints = {}
		if options.journal and scenarioIndex == 1 and seed == 1 then
			run.journal = {}
		end
		local cpu = os.clock()
		run:play(options.hours * 3600, function(r, hour)
			r.hourly[hour] = r.frontier
			r.hourlySpins[hour] = r.spins
			r.hourlyMoney[hour] = { coins = r.coins, income = r.income, total = r.totalEarned, frontier = r.frontier }
			Report.csvHour(r, hour)
			if table.find(CHECKPOINTS, hour) then
				-- Copie des tours pour l'analyse « renaissance en boucle »
				local towers = {}
				for _, tower in r:compiled() do
					table.insert(towers, table.clone(tower))
				end
				r.checkpoints[hour] = { towers = towers, frontier = r.frontier, coinBonus = r.coinBonus }
			end
		end)
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
				"PROGRES|%-18s graine %d/%d : vague %d en %s (%.1f s de calcul)",
				scenarioId,
				seed,
				options.seeds,
				run.frontier,
				duration(run.endTime),
				os.clock() - cpu
			)
		)
	end
	runsByScenario[scenarioId] = runs
end

local reference = runsByScenario.base or runsByScenario[options.scenarios[1]]
local referenceId = if runsByScenario.base then "base" else options.scenarios[1]

----------------------------------------------------------------------
-- 2. En-tête
----------------------------------------------------------------------
Report.section("entete")
Report.header(options)

-- Vagues impossibles à rater : tous leurs ennemis réunis font moins de BASE_HEALTH dégâts à la base.
do
	local firstFailable, safeCount = {}, 0
	for wave = 1, 100 do
		local comp = Engine.composition(wave)
		if comp.failable then
			firstFailable[comp.waveType] = firstFailable[comp.waveType] or wave
		else
			safeCount += 1
		end
	end
	local parts = {}
	for _, waveType in Report.WAVE_TYPE_ORDER do
		local wave = firstFailable[waveType]
		table.insert(parts, `{Report.waveTypeName(waveType)} dès la {if wave then wave else "(jamais avant 100)"}`)
	end
	out(`Vagues qu'on peut rater (tous leurs ennemis réunis font au moins {IdleConfig.BASE_HEALTH} dégâts à la base) : {table.concat(parts, ", ")}.`)
	out(`=> {safeCount} vagues sur 100 passent même sans aucune tour : les murs ne peuvent venir que des autres.`)
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
	out("- Machine à tours : 1 lancer par vague réussie, y compris en farmant (vague N-1 réussie, N ratée : 1 lancer toutes les 2 vagues) ;")
	out(
		string.format(
			"  chaque doublon = +%s %% de dégâts sans limite. Au palier 1, %d %% de chances de tomber sur une Commune (2 tours) : l'Archer en reçoit beaucoup.",
			IdleConfig.formatPercent(IdleConfig.DUPLICATE_DAMAGE_BONUS * 100),
			IdleConfig.TOWER_SPIN_TIERS[1].odds.Common
		)
	)
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
		values[towerType] = { dps = stats.damage / stats.cooldown, level = level }
		best = math.max(best, values[towerType].dps)
	end
	for _, towerType in IdleTowers.ORDER do
		table.insert(texts, `{Run.shortName(towerType)} {math.floor(values[towerType].dps / best * 100 + 0.5)} (niv {values[towerType].level})`)
	end
	out(`- À budget égal ({coins(budget)} par tour = 12 vagues de gains de la vague 50), dégâts par seconde sur UNE cible (100 = la meilleure ;`)
	out("  ignore la portée, la zone, la chaîne et le ralentissement, voir le banc d'essai) : " .. table.concat(texts, ", "))
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
	local spentBy = { upgrade = 0, place = 0, spot = 0, replace = 0, forge = 0 }
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
			"Machine à tours : %.0f lancers (%.0f par heure), %.0f doublons ; le plus sur une tour : %.0f (%s, soit +%.0f %% de dégâts).",
			mean(spins),
			mean(spins) / options.hours,
			mean(dupesEnd),
			mean(maxDupes),
			if mostDuped then Run.shortName(mostDuped) else "-",
			mean(maxDupes) * IdleConfig.DUPLICATE_DAMAGE_BONUS * 100
		)
	)
	out(string.format("Vagues jouées : %.0f dont %.0f ratées.", mean(played), mean(failed)))
	local totalSpent = 0
	for _, amount in spentBy do
		totalSpent += amount
	end
	if totalSpent > 0 then
		out(
			string.format(
				"Dépenses : améliorations %.0f %%, emplacements %.0f %%, tours posées %.0f %%, remplacements %.0f %%, forge %.0f %%.",
				spentBy.upgrade / totalSpent * 100,
				spentBy.spot / totalSpent * 100,
				spentBy.place / totalSpent * 100,
				spentBy.replace / totalSpent * 100,
				spentBy.forge / totalSpent * 100
			)
		)
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
		local forgeSpins, spent, placed = {}, {}, {}
		for _, run in runs do
			table.insert(forgeSpins, run.forgeSpins)
			table.insert(spent, run.forgeSpent)
			local best = 0
			for _, tower in run.towers do
				local bonus = tower.bonus and IdleConfig.BONUS_BY_ID[tower.bonus]
				if bonus and bonus.kind == "Damage" then
					best = math.max(best, bonus.mult)
				end
			end
			table.insert(placed, best)
		end
		out(
			`Forge runique : {string.format("%.0f", mean(forgeSpins))} lancers en moyenne, {coins(mean(spent))} pièces dépensées ; meilleur bonus de dégâts posé à la fin : x{string.format("%.0f", mean(placed))} en moyenne.`
		)
		out()
	end

	if scenario.rebirth then
		out("Renaissances (vague d'origine, gain, temps pour revenir au record) :")
		for _, run in runs do
			local parts = {}
			for i, entry in run.rebirthLog do
				if i <= 10 then
					table.insert(
						parts,
						`v{entry.fromWave} +{IdleConfig.formatPercent(entry.gain)} % ({if entry.cycle then duration(entry.cycle) else "…"})`
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
-- 5 bis. Grands nombres : pièces en poche, revenu et total gagné au fil des heures, puis les limites
-- des nombres (au-delà de ~1,8e308, un nombre devient « infini » et les DataStores refusent de le sauver).
----------------------------------------------------------------------
-- Valeur du milieu d'une liste (plus parlante qu'une moyenne pour des nombres qui changent d'échelle).
local function medianOf(list)
	if #list == 0 then
		return nil
	end
	local sorted = table.clone(list)
	table.sort(sorted)
	return sorted[math.floor((#sorted + 1) / 2)]
end

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
			or not isFinite(IdleConfig.bonusSpinCost(wave))
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
			-- Pire cas : bonus x100 de la forge et 10 000 doublons
			local stats = IdleTowers.effectiveStats(towerType, level, 10000, "Damage100")
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
-- règles (la base a BASE_HEALTH PV). La puissance relative est 100 x k(meilleure) / k(tour) : 100 = la
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
	return Engine.runWave(comp, towers).success
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
				local k = requiredMultiplier(Engine.composition(wave, waveType), team)
				local value = if k == math.huge then 0 else 100 * cells[main][waveType].k / k
				cells[towerType][waveType].support = value
				table.insert(row, powerText(value) .. (if value > 100 then " +" else "  "))
			end
			table.insert(rows, row)
		end
	end
	if #rows > 0 then
		out(`  Soutien : {count - 3} {mainName} + 3 exemplaires d'une autre tour (100 = aussi fort que {count} {mainName} ;`)
		out(`  « + » = l'équipe est plus forte qu'avec {count} {mainName}, la tour est utile en soutien) :`)
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
out("règles : la base a " .. IdleConfig.BASE_HEALTH .. " PV), construite comme ce type. Case = puissance relative sans doublons / avec")
out("les doublons moyens de ce moment. 100 = la meilleure tour sans doublons contre ce type de vague ; 50 = il lui faudrait 2 fois")
out("plus de dégâts. * = la meilleure. « k » = multiplicateur de dégâts dont la meilleure tour a besoin pour réussir")
out("(k < 1 : elle réussit avec de la marge).")
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
		local row = { Run.shortName(towerType) .. " (" .. IdleConfig.RARITIES[IdleTowers.Defs[towerType].rarity].displayName .. ")" }
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
	out("  (0 = impossible même avec des dégâts infinis : ces tours ne tirent pas assez souvent, trop d'ennemis atteignent la base.)")
	local main = benchSupport(wave, budget, cells, count)
	benchResults[wave] = { cells = cells, bestK = bestK, main = main }
end
out()

----------------------------------------------------------------------
-- 7. Renaissance en boucle : combien de temps pour rejouer 1..N avec les tours d'un moment donné ?
----------------------------------------------------------------------
Report.section("renaissance")
table.insert(order, "renaissance")
out(string.rep("=", 100))
out(`RENAISSANCE EN BOUCLE (tours du scénario « {referenceId} » à différents moments, aucun achat pendant la boucle)`)
out(string.rep("=", 100))
out("Rejouer 1..N = temps pour repasser les vagues 1 à N juste après une renaissance (le « cycle »), et ce que ça rapporte :")
out("le bonus de pièces (%/h de boucle) et les lancers de la machine à tours (1 par vague réussie).")
out("À comparer à une heure de jeu normal à ce moment : vagues gagnées, hausse du revenu, lancers.")
local DT = Engine.DT
local function replay(towers, lastWave: number)
	local total = Engine.delaySteps(IdleConfig.FIRST_WAVE_DELAY) * DT
	for wave = 1, lastWave do
		local result = Engine.runWave(Engine.composition(wave), towers)
		if not result.success then
			return nil
		end
		total += result.seconds + Engine.delaySteps(IdleConfig.WAVE_CLEAR_DELAY) * DT
	end
	return total
end
local rebirthSummary = {}
for _, hour in CHECKPOINTS do
	local byN, frontiers, progress, spinRates = {}, {}, {}, {}
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
					table.insert(spinRates, (run.hourlySpins[hour + window] - run.hourlySpins[hour]) / window)
					break
				end
			end
		end
	end
	if #frontiers > 0 then
		local parts, bestRate, bestSpins, bestCycle = {}, 0, 0, nil
		for _, lastWave in { 15, 25, 50, 75, 100, 150, 200 } do
			local list = byN[lastWave]
			if list and #list > 0 then
				local t = mean(list)
				local gain = IdleConfig.rebirthGain(lastWave)
				local rate = gain / (t / 3600)
				if rate > bestRate then
					bestRate, bestCycle = rate, { wave = lastWave, t = t }
				end
				bestSpins = math.max(bestSpins, lastWave / (t / 3600))
				table.insert(parts, `1..{lastWave} : {duration(t)} (+{IdleConfig.formatPercent(gain)} %, {string.format("%.1f", rate)} %/h)`)
			end
		end
		local wavesPerHour = mean(progress)
		local growth = if wavesPerHour then (IdleConfig.REWARD_GROWTH ^ wavesPerHour - 1) * 100 else nil
		local normalSpins = mean(spinRates)
		out()
		out(`À {hour} h (record moyen : vague {math.floor(mean(frontiers) + 0.5)}) :`)
		out("  " .. table.concat(parts, "  |  "))
		if wavesPerHour then
			out(
				string.format(
					"  jeu normal : %.1f vagues/h -> revenu +%.0f %%/h, %.0f lancers/h ; meilleure boucle : +%.1f %%/h de bonus, jusqu'à %.0f lancers/h",
					wavesPerHour,
					growth,
					normalSpins,
					bestRate,
					bestSpins
				)
			)
		end
		table.insert(rebirthSummary, {
			hour = hour,
			bestRate = bestRate,
			growth = growth,
			bestCycle = bestCycle,
			normalSpins = normalSpins,
			loopSpins = bestSpins,
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
	local verdict = between(t10 and t10 / 60, 5, 8, "TROP RAPIDE", "TROP LENT")
	if b >= 30 then
		verdict = if verdict == "OK" then "MUR" else verdict .. " + MUR"
	end
	row("Vagues 1 à 10 fluides", "5-8 min, sans mur", `vague 10 à {duration(t10)}, dont {duration(b)} bloqué`, verdict)
end

-- Premier vrai mur
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
	row(
		"Premier vrai mur (>= 1 min)",
		"vers les vagues 12-16",
		if firstWall then `vague {table.concat(firstWalls, ", ")} ({duration(mean(firstDurations))} en moyenne)` else "aucun",
		between(firstWall, 12, 16)
	)
end

-- Vague 15
do
	local t15 = reach(reference, 15)
	row("Vague 15 (renaissance possible)", "20-30 min", duration(t15), between(t15 and t15 / 60, 20, 30))
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
	-- et plus des vagues 71-100.
	local midText, midMedian, midP80 = describe(wallsIn(reference, 31, 70, 30))
	row("Murs plus tard (vagues 31-70)", "10-20 min au plus", midText, judge(midMedian, midP80, 20 * 60, 30 * 60))
	local lateText, lateMedian, lateP80 = describe(wallsIn(reference, 71, 100, 30))
	row("Murs plus tard (vagues 71-100)", "10-20 min au plus", lateText, judge(lateMedian, lateP80, 20 * 60, 30 * 60))
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
for _, target in { { 25, 0.75, 1.5, "~1 h" }, { 50, 4, 8, "4-8 h" }, { 100, 20, 40, "20-40 h" } } do
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
		table.insert(parts, `{Run.shortName(towerType)} {Report.pct(share)}`)
		if share < 0.1 then
			unused += 1
		end
	end
	row(
		"Les 8 tours utiles à un moment",
		"chacune >= 10 % des dégâts quelque part",
		"meilleure part des dégâts utiles (tranche x type de vague) : " .. table.concat(parts, ", "),
		if unused > 0 then `NON ({unused} tours jamais utiles)` else "OK"
	)
end

-- Banc d'essai : tours différentes selon le type de vague, tours dominées, légendaires
do
	local winners, winnerParts = {}, {}
	local dominatedEverywhere = {}
	for _, towerType in IdleTowers.ORDER do
		dominatedEverywhere[towerType] = true
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
			-- Tour dominée : une autre tour fait mieux contre tous les types de vague (sans doublons)
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
								if bench.cells[other][waveType].k >= mine[waveType].k then
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
					dominatedEverywhere[towerType] = false
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
		local dominatedNames = {}
		for _, towerType in IdleTowers.ORDER do
			if dominatedEverywhere[towerType] then
				table.insert(dominatedNames, Run.shortName(towerType))
			end
		end
		row(
			"Aucune tour dominée pour toujours",
			"pas de tour moins bonne partout, tout le temps",
			if #dominatedNames > 0
				then `moins bonnes qu'une autre tour contre tous les types de vague, et inutiles en soutien, à chaque vague du banc d'essai : {table.concat(dominatedNames, ", ")}`
				else "aucune",
			if #dominatedNames > 0 then "NON" else "OK"
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
				"renaissance-seule : %.0f renaissances, bonus +%s %% ; record à %d h : %.0f contre %.0f sans ; %s ; lancers de machine x%.1f",
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
	local parts, loopBetter, spinsBetter = {}, 0, 0
	for _, summary in rebirthSummary do
		if summary.growth then
			table.insert(
				parts,
				string.format(
					"%d h : +%.1f contre +%.0f %%/h, %.0f contre %.0f lancers/h",
					summary.hour,
					summary.bestRate,
					summary.growth,
					summary.loopSpins,
					summary.normalSpins
				)
			)
			if summary.bestRate > summary.growth then
				loopBetter += 1
			end
			if summary.loopSpins > 3 * summary.normalSpins then
				spinsBetter += 1
			end
		end
	end
	if #parts > 0 then
		row(
			"Farmer les renaissances",
			"à mesurer (accepté même si la boucle rapporte plus)",
			"boucle contre jeu normal (bonus contre hausse du revenu, lancers de machine) : " .. table.concat(parts, " ; "),
			-- Accepté par le propriétaire : renaître en boucle peut rapporter plus que progresser. Mesuré, pas jugé.
			if loopBetter > 0 then `info : boucle mieux payée ({loopBetter} fois, accepté)`
				elseif spinsBetter > 0 then `info : lancers x3+ en boucle ({spinsBetter} fois, accepté)`
				else "info"
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
		"Forge runique (1 lancer / 30 min)",
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
out("Hypothèses : joueur connecté en continu et actif (ramasse tout, machine à tours à chaque vague, achats entre les vagues),")
out("sans Robux. Les scénarios « forge » et « renaissance » ajoutent la forge runique en pièces et/ou la renaissance (voir README).")
out()

Report.section("fin")
table.insert(order, "fin")
out(string.format("Calcul total : %.0f s.", os.clock() - started))
Report.flush(order)

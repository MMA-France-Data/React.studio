-- Mise en forme du rapport texte et du CSV (moyennes sur les graines).
local Modules = require("./Modules")
local Engine = require("./Engine")
local Run = require("./Run")

local IdleConfig = Modules.IdleConfig
local IdleTowers = Modules.IdleTowers
local PlotLayout = Modules.PlotLayout
local NumberFormat = Modules.NumberFormat

local Report = {}

-- Le rapport est écrit par parties (Report.section), puis affiché dans l'ordre voulu (Report.flush) :
-- le résumé des objectifs en premier, même s'il est calculé en dernier.
local sections = {}
local current = "main"
local function out(text: string?)
	local lines = sections[current]
	if not lines then
		lines = {}
		sections[current] = lines
	end
	table.insert(lines, text or "")
end
Report.out = out

function Report.section(name: string)
	current = name
end

function Report.flush(order: { string })
	for _, name in order do
		for _, line in sections[name] or {} do
			print(line)
		end
	end
	table.clear(sections)
end

----------------------------------------------------------------------
-- Petits formats
----------------------------------------------------------------------
local function width(text: string): number
	return utf8.len(text) or #text
end

local function pad(text: string, n: number): string
	return text .. string.rep(" ", math.max(0, n - width(text)))
end

local function padLeft(text: string, n: number): string
	return string.rep(" ", math.max(0, n - width(text))) .. text
end

-- Tableau aligné : rows = liste de listes de textes, align = "l"/"r" par colonne.
local function table_(headers, rows, align)
	local widths = {}
	for i, header in headers do
		widths[i] = width(header)
	end
	for _, row in rows do
		for i, cell in row do
			widths[i] = math.max(widths[i] or 0, width(cell))
		end
	end
	local function render(row)
		local parts = {}
		for i, cell in row do
			parts[i] = if align and align[i] == "l" then pad(cell, widths[i]) else padLeft(cell, widths[i])
		end
		return "  " .. table.concat(parts, "  ")
	end
	out(render(headers))
	local rule = {}
	for i in headers do
		rule[i] = string.rep("-", widths[i])
	end
	out(render(rule))
	for _, row in rows do
		out(render(row))
	end
end
Report.table = table_

function Report.duration(seconds: number?): string
	if not seconds then
		return "-"
	end
	if seconds < 60 then
		return string.format("%d s", math.floor(seconds + 0.5))
	elseif seconds < 3600 then
		return string.format("%d min", math.floor(seconds / 60 + 0.5))
	end
	local minutes = math.floor(seconds / 60 + 0.5)
	return string.format("%d h %02d", minutes // 60, minutes % 60)
end
local duration = Report.duration

local function coins(value: number?): string
	return if value then NumberFormat.short(value) else "-"
end

local function mean(list)
	if #list == 0 then
		return nil
	end
	local total = 0
	for _, v in list do
		total += v
	end
	return total / #list
end
Report.mean = mean

local function minMax(list)
	local lo, hi = math.huge, -math.huge
	for _, v in list do
		lo = math.min(lo, v)
		hi = math.max(hi, v)
	end
	return lo, hi
end

local function pct(value: number): string
	return string.format("%d %%", math.floor(value * 100 + 0.5))
end

-- Nombre pour le CSV (virgule décimale : s'ouvre directement dans Excel en français).
local function csvNumber(value: number): string
	if value == math.floor(value) and math.abs(value) < 1e15 then
		return string.format("%d", value)
	end
	return (string.gsub(string.format("%.6g", value), "%.", ","))
end

local WAVE_TYPE_ORDER = { "Mixed", "Horde", "Rush", "Giants", "Boss" }
Report.WAVE_TYPE_ORDER = WAVE_TYPE_ORDER
local function waveTypeName(waveType: string): string
	return IdleConfig.WAVE_TYPES[waveType].displayName
end
Report.waveTypeName = waveTypeName

----------------------------------------------------------------------
-- Réglages lus
----------------------------------------------------------------------
function Report.header(options)
	out("RAPPORT DU SIMULATEUR DU MODE INFINI (mode solo, ta parcelle)")
	out(string.rep("=", 100))
	out(
		`Simulation : {options.seeds} graine(s) par scénario, {options.hours} h de jeu par partie, pas de {options.dt} s.`
			.. ` Scénarios : {table.concat(options.scenarios, ", ")}.`
	)
	if #options.overrides > 0 then
		out("ESSAI DE RÉGLAGES (src/ n'est pas modifié) : " .. table.concat(options.overrides, " ; "))
	end
	out(
		string.format(
			"Réglages lus dans src/shared : PV x%.2f / vague, pièces x%.2f / vague, amélioration dégâts x%.2f pour prix x%.2f,",
			IdleConfig.HEALTH_GROWTH,
			IdleConfig.REWARD_GROWTH,
			IdleConfig.UPGRADE_DAMAGE,
			IdleConfig.UPGRADE_COST_GROWTH
		)
	)
	-- Facteurs de vitesse différents de 1 (tous les types d'ennemis, lus dans IdleConfig)
	local factors = {}
	for _, name in Modules.Enemies.ORDER do
		if IdleConfig.enemySpeedFactor(name) ~= 1 then
			table.insert(factors, `{name} x{IdleConfig.enemySpeedFactor(name)}`)
		end
	end
	out(
		`  une seule fuite = vague ratée, {coins(IdleConfig.STARTING_COINS)} pièces au départ, chemin {math.floor(PlotLayout.PATH_LENGTH)} studs, `
			.. `ennemis x{IdleConfig.ENEMY_SPEED_MULTIPLIER} ({table.concat(factors, ", ")}), `
			.. `emplacements {PlotLayout.STARTING_SPOTS} gratuits puis {coins(PlotLayout.spotCost(PlotLayout.STARTING_SPOTS + 1))} -> {coins(PlotLayout.spotCost(#PlotLayout.SPOTS))} `
			.. `(achetés {if Run.POLICY.SPOTS_ANY_ORDER then "dans n'importe quel ordre" else "dans l'ordre"}), `
			.. `doublon +{IdleConfig.DUPLICATE_DAMAGE_BONUS * 100} %.`
	)
	out("Joueur simulé : actif, ramasse toutes les pièces tout de suite, achète entre les vagues au meilleur rapport")
	out("gain / prix, lancers de l'autel des héros compris (voir tools/balance/README.md).")
	out("Temps = temps de jeu cumulé depuis le tout début (joueur connecté en continu). Moyennes sur les graines.")
	out()
end

----------------------------------------------------------------------
-- Jalons
----------------------------------------------------------------------
Report.MILESTONES = { 5, 10, 15, 20, 25, 30, 40, 50, 60, 70, 80, 90, 100, 120, 150, 200, 250, 300 }

-- Composition moyenne des tours à un jalon : "Archer 7.2 (niv 30), Mage 1 (niv 3)".
local function compositionText(snapshots)
	local sums = {}
	for _, snap in snapshots do
		for towerType, entry in snap.byType do
			local sum = sums[towerType]
			if not sum then
				sum = { n = 0, level = 0 }
				sums[towerType] = sum
			end
			sum.n += entry.n
			sum.level += (entry.min + entry.max) / 2 * entry.n
		end
	end
	local parts = {}
	for _, towerType in IdleTowers.ORDER do
		local sum = sums[towerType]
		if sum and sum.n > 0 then
			local count = sum.n / #snapshots
			local text = if count == math.floor(count) then tostring(count) else string.format("%.1f", count)
			table.insert(parts, `{Run.shortName(towerType)} {text} (niv {math.floor(sum.level / sum.n + 0.5)})`)
		end
	end
	return table.concat(parts, ", ")
end

function Report.milestones(runs)
	local rows = {}
	for _, wave in Report.MILESTONES do
		local snaps = {}
		for _, run in runs do
			if run.firstClear[wave] then
				table.insert(snaps, run.firstClear[wave])
			end
		end
		if #snaps > 0 then
			local times, coinList, incomes, spots, dupes, blocked, longest, walls = {}, {}, {}, {}, {}, {}, {}, {}
			for _, s in snaps do
				table.insert(times, s.t)
				table.insert(coinList, s.coins)
				table.insert(incomes, s.income * 60)
				table.insert(spots, s.spots)
				table.insert(dupes, s.dupes)
				table.insert(blocked, s.blocked)
				table.insert(longest, s.longest)
				table.insert(walls, s.wall)
			end
			local lo, hi = minMax(times)
			table.insert(rows, {
				tostring(wave),
				(if #snaps < #runs then `{#snaps}/{#runs} ` else "") .. duration(mean(times)),
				`{duration(lo)} - {duration(hi)}`,
				coins(mean(coinList)),
				coins(mean(incomes)),
				string.format("%.1f", mean(spots)),
				string.format("%.0f", mean(dupes)),
				if mean(walls) > 0 then duration(mean(walls)) else "-",
				duration(mean(blocked)),
				duration(mean(longest)),
				compositionText(snaps),
			})
		else
			table.insert(rows, { tostring(wave), `0/{#runs}`, "", "", "", "", "", "", "", "", "pas atteinte" })
			break
		end
	end
	table_(
		{
			"Vague",
			"Atteinte",
			"[min - max]",
			"Pièces",
			"Revenu/min",
			"Empl.",
			"Doublons",
			"Mur ici",
			"Bloqué total",
			"Plus long mur",
			"Tours posées (nombre moyen, niveau moyen)",
		},
		rows,
		{ "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "l" }
	)
	out("  (Pièces = en poche au passage ; Mur ici = temps bloqué à cette vague ; Bloqué total / Plus long mur = depuis le début.)")
end

----------------------------------------------------------------------
-- Murs
----------------------------------------------------------------------
local RANGES = {
	{ 1, 10 },
	{ 11, 20 },
	{ 21, 30 },
	{ 31, 40 },
	{ 41, 50 },
	{ 51, 60 },
	{ 61, 70 },
	{ 71, 80 },
	{ 81, 90 },
	{ 91, 100 },
	{ 101, 150 },
	{ 151, 200 },
	{ 201, 400 },
}

function Report.walls(runs)
	local rows = {}
	for _, range in RANGES do
		local a, b = range[1], range[2]
		local spent, blocked, longest, count, reached = {}, {}, {}, {}, 0
		local longestWave = {}
		for _, run in runs do
			local startT = if a == 1 then 0 else (run.firstClear[a - 1] and run.firstClear[a - 1].t)
			if startT then
				local endSnap = run.firstClear[b]
				local endT = if endSnap then endSnap.t else run.endTime
				if endSnap then
					reached += 1
				end
				table.insert(spent, endT - startT)
				local blockedHere, maxWall, maxWave, n = 0, 0, 0, 0
				for _, wall in run.walls do
					if wall.wave >= a and wall.wave <= b then
						blockedHere += wall.seconds
						n += 1
						if wall.seconds > maxWall then
							maxWall, maxWave = wall.seconds, wall.wave
						end
					end
				end
				-- Mur encore en cours à la fin de la simulation
				local open = run.frontier + 1
				if not endSnap and open >= a and open <= b and run.openWall > 0 then
					blockedHere += run.openWall
					n += 1
					if run.openWall > maxWall then
						maxWall, maxWave = run.openWall, open
					end
				end
				table.insert(blocked, blockedHere)
				table.insert(longest, maxWall)
				table.insert(count, n)
				if maxWave > 0 then
					longestWave[maxWave] = (longestWave[maxWave] or 0) + 1
				end
			end
		end
		if #spent == 0 then
			break
		end
		local worst, worstCount = nil, 0
		for wave, n in longestWave do
			if n > worstCount or (n == worstCount and wave < (worst or math.huge)) then
				worst, worstCount = wave, n
			end
		end
		table.insert(rows, {
			`{a}-{b}`,
			(if reached < #runs then `{reached}/{#runs} ` else "") .. duration(mean(spent)),
			duration(mean(blocked)),
			string.format("%.1f", mean(count)),
			duration(mean(longest)),
			if worst then `{worst} ({waveTypeName(IdleConfig.waveType(worst))})` else "-",
		})
	end
	table_(
		{ "Vagues", "Temps passé", "Dont bloqué", "Nb murs", "Plus long mur", "Mur le plus long le plus souvent" },
		rows,
		{ "l", "r", "r", "r", "r", "l" }
	)
	out("  (Temps passé : du premier passage de la vague avant la tranche au premier passage de la dernière vague ;")
	out("   « a/b » = graines qui ont fini la tranche. Mur = temps entre le premier échec d'une vague et sa réussite.)")
end

-- Liste des murs (moyenne sur les graines, 0 quand la vague passe du premier coup).
function Report.wallList(runs, minSeconds: number)
	local byWave = {}
	local maxWave = 0
	for _, run in runs do
		for _, wall in run.walls do
			byWave[wall.wave] = byWave[wall.wave] or {}
			table.insert(byWave[wall.wave], wall.seconds)
			maxWave = math.max(maxWave, wall.wave)
		end
		if run.openWall > 0 then
			local wave = run.frontier + 1
			byWave[wave] = byWave[wave] or {}
			table.insert(byWave[wave], run.openWall)
			maxWave = math.max(maxWave, wave)
		end
	end
	local parts = {}
	for wave = 1, maxWave do
		local list = byWave[wave]
		if list then
			local total = 0
			for _, v in list do
				total += v
			end
			local avg = total / #runs
			if avg >= minSeconds then
				table.insert(parts, `{wave} {string.sub(IdleConfig.waveType(wave), 1, 1)}: {duration(avg)}`)
			end
		end
	end
	for i = 1, #parts, 8 do
		out("  " .. table.concat(parts, "  |  ", i, math.min(#parts, i + 7)))
	end
	out("  (M = Escarmouche, H = Levée des écuyers, R = Charge de cavalerie, G = Garde colossale, B = Seigneur de guerre)")
end

-- Plus longue période sans aucun achat
function Report.noPurchase(runs)
	local gaps, waves = {}, {}
	for _, run in runs do
		local gap = math.max(run.longestNoPurchase, run.endTime - run.lastPurchaseAt)
		table.insert(gaps, gap)
		table.insert(waves, tostring(if gap == run.longestNoPurchase then run.longestNoPurchaseAt else run.frontier + 1))
	end
	local lo, hi = minMax(gaps)
	out(
		`  Plus longue période sans rien acheter : {duration(mean(gaps))} en moyenne ({duration(lo)} - {duration(hi)}), au mur des vagues {table.concat(waves, ", ")}.`
	)
end

----------------------------------------------------------------------
-- Emplacements et tours débloquées
----------------------------------------------------------------------
-- Nombre de vagues de gains (sans bonus de pièces) que représente un prix à une vague donnée.
local function wavesOfRewards(price: number, wave: number): number
	return price / IdleConfig.rewardBudget(wave)
end
Report.wavesOfRewards = wavesOfRewards

local function shortNumber(value: number): string
	if value >= 1000 then
		return NumberFormat.short(value)
	elseif value >= 10 then
		return string.format("%.0f", value)
	end
	return string.format("%.1f", value)
end
Report.shortNumber = shortNumber

-- Un rang par emplacement acheté : le n-ième coûte PlotLayout.spotCost(n), quel que soit celui choisi.
function Report.spots(runs)
	local rows = {}
	for nth = PlotLayout.STARTING_SPOTS + 1, #PlotLayout.SPOTS do
		local times, waves, chosen = {}, {}, {}
		for _, run in runs do
			local info = run.spotTimes[nth]
			if info then
				table.insert(times, info.t)
				table.insert(waves, info.wave)
				if not table.find(chosen, info.spot) then
					table.insert(chosen, info.spot)
				end
			end
		end
		table.sort(chosen)
		local price = PlotLayout.spotCost(nth)
		local wave = if #waves > 0 then mean(waves) else nil
		table.insert(rows, {
			`{nth}e`,
			coins(price),
			`{#times}/{#runs}`,
			if #times > 0 then duration(mean(times)) else "-",
			if wave then string.format("%.0f", wave) else "-",
			if wave then shortNumber(wavesOfRewards(price, wave)) else "-",
			shortNumber(wavesOfRewards(price, 100)),
			if #chosen > 0 then table.concat(chosen, ", ") else "-",
		})
	end
	table_(
		{ "Achat", "Prix", "Acheté", "Quand (moy.)", "Vague à battre", "= vagues de gains", "= vagues de gains à la 100", "Emplacement choisi" },
		rows,
		{ "r", "r", "r", "r", "r", "r", "r", "l" }
	)
	out("  (« vagues de gains » : prix / pièces d'une vague entière à cette vague, sans bonus. Ex. 10 = 10 vagues à farmer.)")
end

function Report.unlocks(runs)
	local parts = {}
	for _, towerType in IdleTowers.ORDER do
		local waves = {}
		for _, run in runs do
			if run.unlockedAt[towerType] then
				table.insert(waves, run.unlockedAt[towerType].wave)
			end
		end
		local rarity = IdleConfig.RARITIES[IdleTowers.Defs[towerType].rarity].displayName
		if table.find(IdleConfig.STARTING_TOWERS, towerType) then
			table.insert(parts, `{Run.shortName(towerType)} ({rarity}) : dès le départ`)
		elseif #waves > 0 then
			table.insert(parts, `{Run.shortName(towerType)} ({rarity}) : vague {math.floor(mean(waves) + 0.5)} ({#waves}/{#runs})`)
		else
			table.insert(parts, `{Run.shortName(towerType)} ({rarity}) : jamais`)
		end
	end
	for i = 1, #parts, 4 do
		out("  " .. table.concat(parts, "  |  ", i, math.min(#parts, i + 3)))
	end
end

----------------------------------------------------------------------
-- Part des dégâts utiles par tour et par type de vague
----------------------------------------------------------------------
function Report.damageShare(runs)
	local rows = {}
	for _, bucket in { "1-25", "26-50", "51-100", "101+" } do
		for _, waveType in WAVE_TYPE_ORDER do
			local key = bucket .. "|" .. waveType
			local total, byType = 0, {}
			for _, run in runs do
				local row = run.damage[key]
				if row then
					for towerType, amount in row do
						-- Chaque partie compte autant (sinon les grosses vagues écrasent tout)
						local runTotal = 0
						for _, v in row do
							runTotal += v
						end
						if runTotal > 0 then
							byType[towerType] = (byType[towerType] or 0) + amount / runTotal
						end
					end
				end
			end
			for _, v in byType do
				total += v
			end
			if total > 0 then
				local row = { bucket, waveTypeName(waveType) }
				for _, towerType in IdleTowers.ORDER do
					local share = (byType[towerType] or 0) / total
					table.insert(row, if share > 0.005 then pct(share) else ".")
				end
				table.insert(rows, row)
			end
		end
	end
	local headers = { "Vagues", "Type" }
	for _, towerType in IdleTowers.ORDER do
		table.insert(headers, Run.shortName(towerType))
	end
	table_(headers, rows, { "l", "l" })
end

----------------------------------------------------------------------
-- CSV
----------------------------------------------------------------------
function Report.csvHeader()
	print(
		"CSV|scenario;graine;vague;type;temps_s;temps_h;pieces;revenu_par_min;emplacements;tours;niveaux_total;doublons;lancers_machine;bonus_pieces_pct;renaissances;mur_s;bloque_total_s;plus_long_mur_s;bonus_forge_poses;composition"
	)
	print(
		"HEURES|scenario;graine;heure;record;vague_en_cours;pieces;revenu_par_min;total_gagne;emplacements;tours;niveaux_total;doublons;lancers_machine;bonus_pieces_pct;renaissances"
	)
end

-- Une ligne par heure de jeu (fichier heures.csv) : pour tracer la progression en fonction du temps.
function Report.csvHour(run, hour: number)
	local towers, levels = 0, 0
	for _, tower in run.towers do
		towers += 1
		levels += tower.level
	end
	local dupes = 0
	for _, n in run.dupes do
		dupes += n
	end
	print(
		"HEURES|"
			.. table.concat({
				run.scenario.id,
				tostring(run.seed),
				tostring(hour),
				tostring(run.frontier),
				tostring(run.wave),
				csvNumber(run.coins),
				csvNumber(run.income * 60),
				csvNumber(run.totalEarned),
				tostring(run.unlockedSpots),
				tostring(towers),
				tostring(levels),
				tostring(dupes),
				tostring(run.spins),
				csvNumber(run.coinBonus),
				tostring(run.rebirths),
			}, ";")
	)
end

function Report.csvRun(run)
	for wave = 1, run.frontier do
		local s = run.firstClear[wave]
		if s then
			local parts = {}
			for _, towerType in IdleTowers.ORDER do
				local entry = s.byType[towerType]
				if entry then
					table.insert(parts, `{Run.shortName(towerType)}x{entry.n}:{entry.min}-{entry.max}`)
				end
			end
			print(
				"CSV|"
					.. table.concat({
						run.scenario.id,
						tostring(run.seed),
						tostring(wave),
						s.waveType,
						csvNumber(math.floor(s.t)),
						csvNumber(math.floor(s.t / 36) / 100),
						csvNumber(s.coins),
						csvNumber(s.income * 60),
						tostring(s.spots),
						tostring(s.towers),
						tostring(s.levels),
						tostring(s.dupes),
						tostring(s.spins),
						csvNumber(s.coinBonus),
						tostring(s.rebirths),
						csvNumber(math.floor(s.wall)),
						csvNumber(math.floor(s.blocked)),
						csvNumber(math.floor(s.longest)),
						tostring(s.bonuses),
						table.concat(parts, " "),
					}, ";")
			)
		end
	end
end

-- Temps moyen pour atteindre une vague (nil si aucune graine ne l'a atteinte), et nb de graines.
function Report.reachTime(runs, wave: number)
	local times = {}
	for _, run in runs do
		if run.firstClear[wave] then
			table.insert(times, run.firstClear[wave].t)
		end
	end
	return mean(times), #times
end

Report.coins = coins
Report.pct = pct
Report.minMax = minMax

return Report

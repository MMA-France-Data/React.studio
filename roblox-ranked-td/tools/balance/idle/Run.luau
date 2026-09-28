--!optimize 2
-- Une partie du mode infini jouée par un joueur simulé, du début jusqu'à la durée demandée.
-- Règles reprises de PlotGame.luau : vague réussie -> vague suivante + 1 lancer de la machine à tours
-- (palier de la vague réussie, sans cumul), vague ratée -> une vague plus bas, délais entre vagues,
-- prix des emplacements (le n-ième coûte PlotLayout.spotCost(n), achetés dans n'importe quel ordre),
-- des tours, des améliorations, revente à 50 %, bonus de pièces.
--
-- Le joueur simulé (réglages dans Run.POLICY) :
--   * ramasse toutes les pièces tout de suite (joueur actif) ;
--   * lance la machine à tours après chaque vague réussie ;
--   * pendant chaque entracte, dépense ses pièces sur l'achat qui a le meilleur rapport gain / prix :
--       - améliorer une tour,
--       - poser une tour sur un emplacement vide,
--       - acheter un emplacement + y poser une tour (il choisit l'emplacement le mieux placé pour cette tour),
--       - remplacer une des tours les plus faibles (50 % remboursés).
--     (scénarios avec forge : le prix du lancer de la forge est mis de côté avant tout, voir forgeReserve)
--     Le « gain » d'une tour neuve compte aussi ses améliorations suivantes (on la juge au niveau où elle
--     devient rentable). Le gain est mesuré contre les prochaines vagues qui peuvent être ratées (ou contre
--     la vague qui bloque, en visant les ennemis qui ont vraiment atteint la base) grâce aux vagues
--     « immortelles » d'Engine.hits : coups que chaque tour peut porter, x dégâts (plafonnés aux PV de
--     l'ennemi, un gros tir sur un petit écuyer est gâché).
--   * si le meilleur achat est trop cher mais payable en moins de SAVE_SECONDS de farm, il économise ;
--     sinon il achète le meilleur achat abordable ;
--   * au mur, il essaie avec le vrai moteur une tour qui ralentit à la place d'une autre (Run:wallSolver).
local Modules = require("./Modules")
local Engine = require("./Engine")
local Rng = require("./Rng")

local IdleConfig = Modules.IdleConfig
local IdleTowers = Modules.IdleTowers
local PlotLayout = Modules.PlotLayout

local Run = {}
Run.__index = Run

Run.POLICY = {
	SAVE_SECONDS = 300, -- économise pour le meilleur achat s'il est payable en moins de 5 min de farm
	FALLBACK_MIN_RATIO = 0.25, -- sinon achète le meilleur achat abordable s'il vaut au moins 25 % du meilleur
	FOCUS_WAVES = 4, -- nombre de prochaines vagues « ratables » visées par les achats
	FOCUS_WEIGHTS = { 1, 0.7, 0.5, 0.35 },
	BLOCKED_NEXT_WEIGHT = 0.3, -- au mur : poids des vagues suivantes (la vague qui bloque compte pour 1)
	REPLACE_CANDIDATES = 3, -- on n'envisage de remplacer que les 3 tours qui rapportent le moins
	REPLACE_FACTOR = 0.8, -- un remplacement doit être nettement meilleur (évite les allers-retours)
	-- On ne remplace pas une tour posée il y a moins de 2 h, et au plus une tour par entracte : sans ça, au mur,
	-- le joueur simulé revendait en boucle des tours de haut niveau (perte de 50 % à chaque fois), ce qu'un
	-- vrai joueur ne fait pas.
	REPLACE_MIN_AGE = 2 * 3600,
	-- Au mur, essaie une tour qui ralentit à la place d'une autre (Run:wallSolver). Désactivé : les murs de
	-- boss raccourcissent, mais moins d'Archers = farm plus lent, et la progression totale est moins bonne
	-- (vague 80 vers 40 h au lieu de 32 h). À essayer avec -Regler "Joueur.SOLVER=true".
	SOLVER = false,
	SOLVER_AFTER = 120, -- ... quand il est bloqué depuis 2 min
	SOLVER_EVERY = 1800, -- ... puis au plus toutes les 30 min
	SOLVER_MIN_GAIN = 0.85, -- ... si l'écart à la réussite baisse d'au moins 15 %
	UPGRADE_SUPPORT = false, -- n'améliore pas ces tours de soutien (leur ralentissement ne dépend pas du niveau)
	-- Emplacements achetés dans n'importe quel ordre (le prix ne dépend que du nombre déjà possédé) si le
	-- jeu le permet (PlotLayout.startingSpots existe), sinon dans l'ordre 5, 6, 7...
	SPOTS_ANY_ORDER = PlotLayout.startingSpots ~= nil,
	SPOT_CHOICES = 3, -- ... il compare alors, pour chaque tour, les 3 emplacements libres les mieux placés
	LONG_FOCUS = 8, -- un remplacement est jugé sur les 8 prochaines vagues ratables
	PACKAGE_COST_CAP = 30, -- une tour neuve est jugée jusqu'à 30x ce qu'on peut payer bientôt
	FORGE_SAVE_SECONDS = 1800, -- forge : met de côté le prix du lancer s'il vaut moins de 30 min de revenu
	REBIRTH_STUCK = 15 * 60, -- scénario « renaissance » : renaît après 15 min bloqué au record
	MAX_WAVE = 3000,
}

Run.SCENARIOS = {
	base = {
		id = "base",
		label = "joueur actif : machine à tours à chaque vague, achats au meilleur rapport, sans forge ni renaissance",
		forge = false,
		rebirth = false,
	},
	forge = {
		id = "forge",
		label = "base + la forge runique en pièces dès qu'elle est prête (1 lancer / 30 min, prix mis de côté), bonus sur la meilleure tour",
		forge = true,
		rebirth = false,
	},
	renaissance = {
		id = "renaissance",
		label = "forge + renaissance dès que bloqué 15 min au record (vague >= 15)",
		forge = true,
		rebirth = true,
	},
	["renaissance-seule"] = {
		id = "renaissance-seule",
		label = "base + renaissance dès que bloqué 15 min au record, sans forge (effet de la renaissance seule)",
		forge = false,
		rebirth = true,
	},
}

local P = Run.POLICY
local SPOT_COUNT = #PlotLayout.SPOTS

-- Pour chaque tour : les emplacements triés par longueur de chemin à portée (le mieux placé d'abord).
-- Sert à choisir quel emplacement acheter quand l'ordre est libre.
local SPOTS_BY_COVERAGE = {}
do
	local samples = {}
	for distance = 0, PlotLayout.PATH_LENGTH, 0.5 do
		table.insert(samples, (PlotLayout.pointAt(distance)))
	end
	for _, towerType in IdleTowers.ORDER do
		local range = IdleTowers.Defs[towerType].range
		local coverage, order = {}, {}
		for spot, position in PlotLayout.SPOTS do
			local count = 0
			for _, point in samples do
				local dx, dz = point.X - position.X, point.Z - position.Z
				if dx * dx + dz * dz <= range * range then
					count += 1
				end
			end
			coverage[spot] = count
			table.insert(order, spot)
		end
		table.sort(order, function(a, b)
			if coverage[a] ~= coverage[b] then
				return coverage[a] > coverage[b]
			end
			return a < b
		end)
		SPOTS_BY_COVERAGE[towerType] = order
	end
end

Run.SPOTS_BY_COVERAGE = SPOTS_BY_COVERAGE

-- Caches partagés par toutes les parties : coups portés en vague immortelle.
local LAYOUT_HITS = {}
local SOLO_HITS = {}

local function layoutHits(typesBySpot, layoutKey: string, comp)
	local key = layoutKey .. "|" .. comp.key
	local cached = LAYOUT_HITS[key]
	if cached then
		return cached
	end
	local towers, spots = {}, {}
	for spot = 1, SPOT_COUNT do
		local towerType = typesBySpot[spot]
		if towerType then
			table.insert(towers, Engine.compileTower(spot, towerType, 1, 0, nil))
			table.insert(spots, spot)
		end
	end
	local bySpot = {}
	if #towers > 0 then
		local hits = Engine.hits(comp, towers)
		for i, spot in spots do
			bySpot[spot] = hits[i]
		end
	end
	LAYOUT_HITS[key] = bySpot
	return bySpot
end

local function soloHits(spot: number, towerType: string, comp)
	local key = spot .. towerType .. "|" .. comp.key
	local cached = SOLO_HITS[key]
	if cached then
		return cached
	end
	local hits = Engine.hits(comp, { Engine.compileTower(spot, towerType, 1, 0, nil) })[1]
	SOLO_HITS[key] = hits
	return hits
end

-- Nom court d'une tour : premier mot du nom affiché (Archer, Totem, Catapulte...).
function Run.shortName(towerType: string): string
	local name = IdleTowers.Defs[towerType].displayName
	return (string.match(name, "^(%S+)") or name)
end

----------------------------------------------------------------------
-- Création
----------------------------------------------------------------------
function Run.new(scenarioId: string, seed: number)
	local scenario = assert(Run.SCENARIOS[scenarioId], `scénario inconnu : {scenarioId}`)
	local self = setmetatable({}, Run)
	self.scenario = scenario
	self.seed = seed
	-- Même graine = mêmes tirages dans tous les scénarios (les écarts viennent du scénario, pas du hasard).
	self.rng = Rng.new(seed)

	-- État du joueur (mêmes champs que PlayerData.defaultIdle)
	self.t = 0
	self.coins = IdleConfig.STARTING_COINS
	self.wave = 1
	self.bestWave = 1
	self.highestWave = 1
	self.unlockedSpots = PlotLayout.STARTING_SPOTS -- NOMBRE d'emplacements possédés
	self.owned = {} -- [emplacement] = true (les STARTING_SPOTS premiers au départ, comme PlotLayout.startingSpots)
	for spot = 1, PlotLayout.STARTING_SPOTS do
		self.owned[spot] = true
	end
	self.towers = {} -- [spot] = { type, level, spent, bonus, placedAt }
	self.unlocked = {}
	for _, towerType in IdleConfig.STARTING_TOWERS do
		self.unlocked[towerType] = true
	end
	self.dupes = {}
	self.pendingSpinTier = 0
	self.bonuses = {}
	self.lastBonusSpinAt = -math.huge
	self.coinBonus = 0
	self.rebirths = 0

	-- Caches
	self.version = 0
	self.layoutVersion = 0

	-- Statistiques
	self.frontier = 0 -- meilleure vague réussie de tous les temps
	self.firstClear = {} -- [vague] = instantané au premier passage
	self.wallStart = {} -- [vague] = fin du premier échec de cette vague
	self.failLeak = {} -- [vague] = dégâts reçus par groupe au dernier échec
	self.totalBlocked = 0
	self.longestWall, self.longestWallWave = 0, 0
	self.walls = {} -- { wave, seconds }
	self.lastPurchaseAt = 0
	self.longestNoPurchase, self.longestNoPurchaseAt = 0, 0
	self.purchases = { upgrade = 0, place = 0, spot = 0, replace = 0, forge = 0 }
	self.unlockedAt = {}
	self.spins = 0
	self.forgeSpins, self.forgeSpent = 0, 0
	self.bonusLog = {}
	self.damage = {} -- [tranche|typeDeVague][typeDeTour] = dégâts utiles
	self.recent = {} -- dernières vagues : { coins, seconds } pour estimer le revenu
	self.income = 0
	self.totalEarned = 0 -- pièces gagnées depuis le tout début (dépensées ou non)
	self.wavesPlayed, self.wavesFailed = 0, 0
	self.rebirthLog = {} -- { t, fromWave, gain, cycle }
	self.runWallSince = nil
	self.pendingCycle = nil
	self.spotTimes = {} -- [n] = { t, wave, spot } : quand le n-ième emplacement a été acheté, et lequel
	self.spentBy = { upgrade = 0, place = 0, spot = 0, replace = 0, forge = 0 } -- pièces dépensées par type d'achat
	self.journal = nil -- liste de lignes si le journal détaillé est demandé (run.ps1 -Journal)
	return self
end

-- Temps de jeu lisible pour le journal : 1:02:03
local function clock(seconds: number): string
	local s = math.floor(seconds)
	return string.format("%d:%02d:%02d", s // 3600, (s // 60) % 60, s % 60)
end

-- Une ligne du journal détaillé (seulement si demandé).
function Run:log(text: string)
	if self.journal then
		table.insert(self.journal, string.format("%9s  pièces %-7s  %s", clock(self.t), Modules.NumberFormat.short(self.coins), text))
	end
end

----------------------------------------------------------------------
-- Tours posées
----------------------------------------------------------------------
function Run:changed(layout: boolean?)
	self.version += 1
	if layout then
		self.layoutVersion += 1
	end
end

function Run:compiled()
	if self.compiledVersion ~= self.version then
		local list, parts = {}, {}
		for spot = 1, SPOT_COUNT do
			local tower = self.towers[spot]
			if tower then
				local dupes = self.dupes[tower.type] or 0
				table.insert(list, Engine.compileTower(spot, tower.type, tower.level, dupes, tower.bonus))
				table.insert(parts, `{spot}:{tower.type}:{tower.level}:{tower.bonus or ""}:{dupes}`)
			end
		end
		self.compiledList = list
		self.configKey = table.concat(parts, ",")
		self.compiledVersion = self.version
		self.memo = {}
	end
	return self.compiledList
end

function Run:typesBySpot()
	if self.typesVersion ~= self.layoutVersion then
		local types, parts = {}, {}
		for spot = 1, SPOT_COUNT do
			local tower = self.towers[spot]
			types[spot] = tower and tower.type
			parts[spot] = tower and tower.type or "-"
		end
		self.typesCache = types
		self.layoutKeyCache = table.concat(parts, ",")
		self.typesVersion = self.layoutVersion
	end
	return self.typesCache, self.layoutKeyCache
end

-- Dégâts effectifs et multiplicateur de cadence (bonus x2 vitesse) d'une tour.
function Run:power(towerType: string, level: number, bonus: string?)
	local stats = IdleTowers.effectiveStats(towerType, level, self.dupes[towerType] or 0, bonus)
	return stats.damage, IdleTowers.Defs[towerType].cooldown / stats.cooldown
end

----------------------------------------------------------------------
-- Valeur des achats
----------------------------------------------------------------------

-- Vagues visées : la vague qui bloque (et ce qui a fui), sinon les prochaines vagues ratables.
-- long = true : les LONG_FOCUS prochaines vagues ratables à poids égal (pour les remplacements, qui
-- doivent valoir le coup sur la durée et pas seulement contre le mur du moment).
function Run:buildFocus(long: boolean?)
	local focus = {}
	local start = math.max(self.wave, self.frontier + 1)
	local function add(wave: number, weight: number, leak)
		local comp = Engine.composition(wave)
		local lambda, total = {}, 0
		for g, group in comp.groups do
			local potential = group.count * group.damage
			local value = if leak then leak[g] + 0.1 * potential else potential
			lambda[g] = value
			total += value
		end
		local eps = {}
		for g, group in comp.groups do
			lambda[g] /= total
			eps[g] = 1e-6 * group.count * group.hp
		end
		table.insert(focus, { wave = wave, comp = comp, weight = weight, lambda = lambda, eps = eps })
	end

	local blockedLeak = if long then nil else self.failLeak[start]
	local wave, added = start, 0
	if blockedLeak then
		add(start, 1, blockedLeak)
		wave = start + 1
	end
	local wanted = if long then P.LONG_FOCUS elseif blockedLeak then 3 else P.FOCUS_WAVES
	while added < wanted and wave < start + 80 do
		if Engine.composition(wave).failable then
			added += 1
			local weight = if long then 1 elseif blockedLeak then P.BLOCKED_NEXT_WEIGHT else P.FOCUS_WEIGHTS[added]
			add(wave, weight, nil)
		end
		wave += 1
	end
	-- Poids ramenés à un total de 1 : les gains des deux listes restent comparables.
	local total = 0
	for _, f in focus do
		total += f.weight
	end
	for _, f in focus do
		f.weight /= total
	end
	return focus
end

-- Puissance utile actuelle U[g] contre chaque vague visée, et part de chaque tour.
function Run:evaluate(focus)
	local typesBySpot, layoutKey = self:typesBySpot()
	local powers = {}
	for spot, tower in self.towers do
		local damage, speed = self:power(tower.type, tower.level, tower.bonus)
		powers[spot] = { damage = damage, speed = speed }
	end
	for _, f in focus do
		local groups = f.comp.groups
		f.hits = layoutHits(typesBySpot, layoutKey, f.comp)
		local U = table.create(#groups, 0)
		f.contrib = {}
		for spot, power in powers do
			local row = f.hits[spot]
			local contrib = table.create(#groups, 0)
			for g, group in groups do
				local value = row[g] * power.speed * math.min(power.damage, group.hp)
				contrib[g] = value
				U[g] += value
			end
			f.contrib[spot] = contrib
		end
		f.U = U
	end
	self.powers = powers
end

-- log(1 + x), précis même pour un x minuscule (math.log(1 + x) vaut 0 dès que x < 1e-16).
local function log1p(x: number): number
	if x > -1e-4 and x < 1e-4 then
		return x * (1 - x * (0.5 - x / 3))
	end
	return math.log(1 + x)
end

-- Gain en score quand la puissance utile U d'un groupe change de `delta` :
--   log(max(U + delta, 0) + eps) - log(U + eps)
-- calculé SANS soustraire deux grands nombres. Loin dans le jeu, U vaut 1e20 et plus, et une tour neuve
-- ou de bas niveau n'en apporte que 1e-16 : avec math.log(U + delta) - math.log(U), son gain tombait
-- à 0 (arrondi), le joueur simulé ne l'améliorait plus jamais et finissait avec 21 tours niveau 1.
local function logGain(U: number, eps: number, delta: number): number
	local base = U + eps
	if U + delta <= 0 then
		return math.log(eps / base)
	end
	return log1p(delta / base)
end

-- Gain (en score) si la contribution de `spot` devient : hits[g] x speed x min(damage, PV).
local function gainReplacingSpot(focus, spot: number, hitsFor, damage: number, speed: number): number
	local gain = 0
	for fi, f in focus do
		local groups = f.comp.groups
		local old = f.contrib[spot]
		local hits = hitsFor(fi, f)
		for g, group in groups do
			local new = hits[g] * speed * math.min(damage, group.hp)
			local delta = new - (if old then old[g] else 0)
			gain += f.weight * f.lambda[g] * logGain(f.U[g], f.eps[g], delta)
		end
	end
	return gain
end

function Run:upgradeOptions(focus, options)
	for spot, tower in self.towers do
		if tower.support and not P.UPGRADE_SUPPORT then
			continue -- une tour de soutien sert à ralentir : ses dégâts comptent peu
		end
		local cost = IdleTowers.upgradeCost(tower.type, tower.level)
		local damage, speed = self:power(tower.type, tower.level + 1, tower.bonus)
		local gain = gainReplacingSpot(focus, spot, function(_, f)
			return f.hits[spot]
		end, damage, speed)
		if gain > 0 then
			table.insert(options, { kind = "upgrade", spot = spot, cost = cost, ratio = gain / cost, gain = gain })
		end
	end
end

-- Tour neuve `towerType` sur `spot` (emplacement vide, emplacement suivant à acheter, ou remplacement),
-- jugée au niveau où son rapport gain / prix total (pose + améliorations) est le meilleur.
function Run:packageOption(focus, spot: number, towerType: string, newSpot: boolean)
	local def = IdleTowers.Defs[towerType]
	local existing = self.towers[spot]
	local refund = if existing then math.floor(existing.spent * IdleConfig.SELL_REFUND) else 0
	local firstCost = def.placeCost + (if newSpot then PlotLayout.spotCost(self.unlockedSpots + 1) else 0) - refund

	-- Coups de la nouvelle tour, et contribution des autres tours (qui change si la nouvelle ou l'ancienne
	-- tour ralentit les ennemis : on rejoue alors la vague immortelle avec la nouvelle disposition).
	-- baseDelta[fi][g] : de combien U change sans la contribution de la nouvelle tour (ancienne tour retirée,
	-- ralentissements changés) ; gardé en écart plutôt qu'en total pour ne pas perdre les petits gains (logGain).
	local newHits, baseDelta = {}, {}
	if def.slow or (existing and IdleTowers.Defs[existing.type].slow) then
		local types = table.clone((self:typesBySpot()))
		types[spot] = towerType
		local parts = {}
		for s = 1, SPOT_COUNT do
			parts[s] = types[s] or "-"
		end
		local key = table.concat(parts, ",")
		for fi, f in focus do
			local hits = layoutHits(types, key, f.comp)
			newHits[fi] = hits[spot]
			local u = table.create(#f.comp.groups, 0)
			for s, power in self.powers do
				if s ~= spot then
					local row = hits[s]
					for g, group in f.comp.groups do
						u[g] += row[g] * power.speed * math.min(power.damage, group.hp)
					end
				end
			end
			for g in u do
				u[g] -= f.U[g]
			end
			baseDelta[fi] = u
		end
	else
		for fi, f in focus do
			newHits[fi] = soloHits(spot, towerType, f.comp)
			local d = table.create(#f.comp.groups, 0)
			local old = f.contrib[spot]
			if old then
				for g in d do
					d[g] = -math.min(old[g], f.U[g])
				end
			end
			baseDelta[fi] = d
		end
	end

	local cap = P.PACKAGE_COST_CAP * math.max(self.coins, self.income * P.SAVE_SECONDS, def.placeCost)
	local dupes = self.dupes[towerType] or 0
	-- Le remboursement de l'ancienne tour n'est pas compté comme un gain (joueur prudent : il perd la
	-- moitié de ce qu'il y avait mis) ; il sert seulement à savoir si le remplacement est payable.
	local cost = firstCost + refund
	local best, bestLevel, bestGain = -math.huge, 1, 0
	-- Les doublons multiplient les dégâts du même facteur à tous les niveaux : on le calcule une fois avec
	-- la vraie fonction du jeu (effectiveStats), puis on lit les stats en cache de chaque niveau (plus rapide).
	local dupeFactor = IdleTowers.effectiveStats(towerType, 1, dupes, nil).damage / IdleTowers.stats(towerType, 1).damage
	for level = 1, 5000 do
		if level > 1 then
			cost += IdleTowers.upgradeCost(towerType, level - 1)
			if cost > cap then
				break
			end
		end
		local damage = IdleTowers.stats(towerType, level).damage * dupeFactor
		local gain = 0
		for fi, f in focus do
			local hits, d = newHits[fi], baseDelta[fi]
			for g, group in f.comp.groups do
				local delta = d[g] + hits[g] * math.min(damage, group.hp)
				gain += f.weight * f.lambda[g] * logGain(f.U[g], f.eps[g], delta)
			end
		end
		local ratio = gain / cost
		if ratio > best then
			best, bestLevel, bestGain = ratio, level, gain
		end
	end
	if existing and best > 0 then
		best *= P.REPLACE_FACTOR
	end
	return {
		kind = if newSpot then "spot" elseif existing then "replace" else "place",
		spot = spot,
		type = towerType,
		cost = firstCost,
		ratio = best,
		gain = bestGain,
		level = bestLevel,
	}
end

-- replacements = false : emplacements vides et emplacement suivant ; true : remplacer une tour faible.
function Run:packageOptions(focus, options, replacements: boolean)
	local candidates = {}
	if not replacements then
		-- Emplacements vides déjà débloqués
		for spot = 1, SPOT_COUNT do
			if self.owned[spot] and not self.towers[spot] then
				table.insert(candidates, { spot = spot, newSpot = false })
			end
		end
		-- Emplacement à acheter : le suivant dans l'ordre, ou (si le jeu permet n'importe quel ordre, même
		-- prix pour tous) pour chaque tour les SPOT_CHOICES emplacements libres qui couvrent le plus de chemin.
		if P.SPOTS_ANY_ORDER then
			for _, towerType in IdleTowers.ORDER do
				if self.unlocked[towerType] then
					local found = 0
					for _, spot in SPOTS_BY_COVERAGE[towerType] do
						if not self.owned[spot] then
							table.insert(candidates, { spot = spot, newSpot = true, onlyType = towerType })
							found += 1
							if found >= P.SPOT_CHOICES then
								break
							end
						end
					end
				end
			end
		else
			for spot = 1, SPOT_COUNT do
				if not self.owned[spot] then
					table.insert(candidates, { spot = spot, newSpot = true })
					break
				end
			end
		end
	else
		-- Les tours qui rapportent le moins
		local shares = {}
		for spot, tower in self.towers do
			-- Les tours de soutien posées par Run:wallSolver ne sont pas remplacées ici (elles servent
			-- contre les vagues qui bloquent, pas contre la moyenne des vagues).
			if self.t - tower.placedAt >= P.REPLACE_MIN_AGE and not tower.support then
				local share = 0
				for _, f in focus do
					for g in f.comp.groups do
						if f.U[g] > 0 then
							share += f.weight * f.lambda[g] * f.contrib[spot][g] / f.U[g]
						end
					end
				end
				table.insert(shares, { spot = spot, share = share })
			end
		end
		table.sort(shares, function(a, b)
			return a.share < b.share
		end)
		for i = 1, math.min(P.REPLACE_CANDIDATES, #shares) do
			table.insert(candidates, { spot = shares[i].spot, newSpot = false })
		end
	end

	for _, candidate in candidates do
		local existing = self.towers[candidate.spot]
		for _, towerType in IdleTowers.ORDER do
			if
				self.unlocked[towerType]
				and not (existing and existing.type == towerType)
				and (candidate.onlyType == nil or candidate.onlyType == towerType)
			then
				local option = self:packageOption(focus, candidate.spot, towerType, candidate.newSpot)
				if option.ratio > 0 then
					table.insert(options, option)
				end
			end
		end
	end
end

----------------------------------------------------------------------
-- Actions (mêmes règles que PlotGame:placeTower / upgradeTower / buySpot)
----------------------------------------------------------------------
function Run:purchased(kind: string)
	self.purchases[kind] += 1
	local gap = self.t - self.lastPurchaseAt
	if gap > self.longestNoPurchase then
		self.longestNoPurchase, self.longestNoPurchaseAt = gap, self.frontier + 1
	end
	self.lastPurchaseAt = self.t
end

function Run:removeTower(spot: number)
	local tower = self.towers[spot]
	if tower and tower.bonus and #self.bonuses < IdleConfig.MAX_BONUS_INVENTORY then
		table.insert(self.bonuses, tower.bonus)
	end
	self.towers[spot] = nil
end

function Run:execute(option)
	if option.kind == "upgrade" then
		local tower = self.towers[option.spot]
		local cost = IdleTowers.upgradeCost(tower.type, tower.level)
		assert(self.coins >= cost)
		self.coins -= cost
		tower.level += 1
		tower.spent += cost
		self.spentBy.upgrade += cost
		self:changed(false)
		self:purchased("upgrade")
		self:log(`achat : amélioration {Run.shortName(tower.type)} (empl. {option.spot}) niv {tower.level} pour {Modules.NumberFormat.short(cost)}`)
		return
	end

	local spot = option.spot
	if option.kind == "spot" then
		-- Même règle que PlotGame:buySpot : le prix ne dépend que du nombre d'emplacements déjà possédés.
		local nth = self.unlockedSpots + 1
		local cost = PlotLayout.spotCost(nth)
		assert(not self.owned[spot] and self.coins >= cost)
		self.coins -= cost
		self.owned[spot] = true
		self.unlockedSpots = nth
		self.spotTimes[nth] = { t = self.t, wave = self.frontier + 1, spot = spot }
		self.spentBy.spot += cost
		self:purchased("spot")
		self:log(`achat : emplacement {spot} pour {Modules.NumberFormat.short(cost)}`)
	end
	local def = IdleTowers.Defs[option.type]
	local existing = self.towers[spot]
	local refund = if existing then math.floor(existing.spent * IdleConfig.SELL_REFUND) else 0
	assert(self.coins + refund >= def.placeCost)
	if existing then
		self:removeTower(spot)
		self.coins += refund
		self:log(`revente : {Run.shortName(existing.type)} niv {existing.level} (empl. {spot}) +{Modules.NumberFormat.short(refund)}`)
	end
	self.coins = math.max(0, self.coins - def.placeCost)
	self.towers[spot] = { type = option.type, level = 1, spent = def.placeCost, bonus = nil, placedAt = self.t }
	self.spentBy[if existing then "replace" else "place"] += def.placeCost
	self:changed(true)
	self:purchased(if existing then "replace" else "place")
	self:log(`achat : pose {Run.shortName(option.type)} sur l'empl. {spot} pour {Modules.NumberFormat.short(def.placeCost)}`)
end

-- Scénarios avec forge : le joueur lance la forge en pièces dès qu'elle est disponible. Pour ça il
-- met son prix de côté (il passe avant les autres achats), si ce prix vaut moins de FORGE_SAVE_SECONDS
-- de revenu (sinon il attend d'avoir un meilleur revenu). Jugée seulement sur son gain immédiat, la forge
-- (~15 vagues de gains) ne serait presque jamais achetée ; ce scénario mesure ce qu'elle apporte.
function Run:forgeReserve(): number
	if not self.scenario.forge then
		return 0
	end
	if self.t - self.lastBonusSpinAt < IdleConfig.BONUS_SPIN_COOLDOWN then
		return 0
	end
	if #self.bonuses >= IdleConfig.MAX_BONUS_INVENTORY or next(self.towers) == nil then
		return 0
	end
	local cost = IdleConfig.bonusSpinCost(self.highestWave)
	if cost > self.income * P.FORGE_SAVE_SECONDS then
		return 0
	end
	return cost
end

-- Lance la forge si le prix est de côté.
function Run:useForge()
	local reserve = self:forgeReserve()
	if reserve > 0 and self.coins >= reserve then
		self:spinForge()
		self:purchased("forge")
	end
end

-- Dépense les pièces (plusieurs achats de suite, en réévaluant après chacun).
function Run:spend()
	local focus = self:buildFocus(false)
	local longFocus = nil
	local reserve = self:forgeReserve()
	local replaced = false -- au plus un remplacement par entracte
	for _ = 1, 400 do
		local available = self.coins - reserve
		if available <= 0 then
			return
		end
		local options = {}
		-- Remplacements, jugés sur les vagues à venir (seulement s'il y a une tour assez ancienne)
		local oldTower = false
		for _, tower in self.towers do
			if self.t - tower.placedAt >= P.REPLACE_MIN_AGE then
				oldTower = true
				break
			end
		end
		if oldTower and not replaced then
			longFocus = longFocus or self:buildFocus(true)
			self:evaluate(longFocus)
			self:packageOptions(longFocus, options, true)
		end
		self:evaluate(focus)
		self:upgradeOptions(focus, options)
		self:packageOptions(focus, options, false)
		local best, bestAffordable = nil, nil
		for _, option in options do
			if not best or option.ratio > best.ratio then
				best = option
			end
			if option.cost <= available and (not bestAffordable or option.ratio > bestAffordable.ratio) then
				bestAffordable = option
			end
		end
		if not best then
			return
		end
		local choice = best
		if best.cost > available then
			local wait = if self.income > 0 then (best.cost - available) / self.income else math.huge
			if wait <= P.SAVE_SECONDS then
				return -- économise pour le meilleur achat
			end
			-- Trop long à économiser : il prend le meilleur achat abordable, s'il vaut au moins
			-- FALLBACK_MIN_RATIO fois le meilleur (sinon il économise quand même).
			if not bestAffordable or bestAffordable.ratio < P.FALLBACK_MIN_RATIO * best.ratio then
				return
			end
			choice = bestAffordable
		end
		if choice.kind == "replace" then
			replaced = true
		end
		self:execute(choice)
	end
end

----------------------------------------------------------------------
-- Machines
----------------------------------------------------------------------

-- Machine à tours (PlotGame:spinTower)
function Run:spinTower()
	local tier = self.pendingSpinTier
	if tier <= 0 then
		return
	end
	self.pendingSpinTier = 0
	self.spins += 1
	local odds = IdleConfig.TOWER_SPIN_TIERS[tier].odds
	local rarity = self.rng:weighted(IdleConfig.RARITY_ORDER, function(name)
		return odds[name] or 0
	end)
	local choices = IdleTowers.ofRarity(rarity)
	local towerType = choices[self.rng:int(1, #choices)]
	if not self.unlocked[towerType] then
		self.unlocked[towerType] = true
		self.unlockedAt[towerType] = { t = self.t, wave = self.frontier }
		self:log(`machine à tours (palier {tier}) : NOUVELLE TOUR {Run.shortName(towerType)} ({IdleConfig.RARITIES[rarity].displayName})`)
	else
		self.dupes[towerType] = (self.dupes[towerType] or 0) + 1
		self:changed(false)
		self:log(`machine à tours (palier {tier}) : doublon {Run.shortName(towerType)} n°{self.dupes[towerType]}`)
	end
end

-- Forge runique, lancer en pièces (PlotGame:spinBonusWithCoins)
function Run:spinForge()
	if self.t - self.lastBonusSpinAt < IdleConfig.BONUS_SPIN_COOLDOWN then
		return
	end
	if #self.bonuses >= IdleConfig.MAX_BONUS_INVENTORY then
		return
	end
	local cost = IdleConfig.bonusSpinCost(self.highestWave)
	if self.coins < cost then
		return
	end
	self.coins -= cost
	self.lastBonusSpinAt = self.t
	self.forgeSpins += 1
	self.forgeSpent += cost
	self.spentBy.forge += cost
	local bonus = self.rng:weighted(IdleConfig.BONUSES, function(entry)
		return entry.chance
	end)
	table.insert(self.bonuses, bonus.id)
	table.insert(self.bonusLog, { t = self.t, id = bonus.id, cost = cost })
	self:log(`forge runique pour {Modules.NumberFormat.short(cost)} : {bonus.displayName}`)
end

-- Pose les bonus de l'inventaire là où ils rapportent le plus (le bonus remplacé est perdu, comme en jeu).
function Run:applyBonuses()
	if #self.bonuses == 0 or next(self.towers) == nil then
		return
	end
	local focus = self:buildFocus(true)
	local index = 1
	while index <= #self.bonuses do
		self:evaluate(focus)
		local bonusId = self.bonuses[index]
		local bestSpot, bestGain = nil, 0
		for spot, tower in self.towers do
			if tower.bonus ~= bonusId then
				local damage, speed = self:power(tower.type, tower.level, bonusId)
				local gain = gainReplacingSpot(focus, spot, function(_, f)
					return f.hits[spot]
				end, damage, speed)
				if gain > bestGain then
					bestSpot, bestGain = spot, gain
				end
			end
		end
		if bestSpot then
			table.remove(self.bonuses, index)
			local tower = self.towers[bestSpot]
			self:log(
				`bonus {IdleConfig.BONUS_BY_ID[bonusId].displayName} posé sur {Run.shortName(tower.type)} (empl. {bestSpot})`
					.. (if tower.bonus then ` à la place de {IdleConfig.BONUS_BY_ID[tower.bonus].displayName}` else "")
			)
			tower.bonus = bonusId
			self:changed(false)
		else
			index += 1
		end
	end
end

----------------------------------------------------------------------
-- Renaissance (PlotGame:rebirth)
----------------------------------------------------------------------
function Run:rebirth(): boolean
	local gain = IdleConfig.rebirthGain(self.bestWave)
	if gain <= 0 then
		return false
	end
	table.insert(self.rebirthLog, { t = self.t, fromWave = self.bestWave, gain = gain })
	self.pendingCycle = { t = self.t, target = self.bestWave, entry = self.rebirthLog[#self.rebirthLog] }
	self.coinBonus = IdleConfig.roundPercent(self.coinBonus + gain)
	self.rebirths += 1
	self.wave = 1
	self.bestWave = 1
	self.runWallSince = nil
	self:log(`RENAISSANCE n°{self.rebirths} : +{IdleConfig.formatPercent(gain)} % -> bonus de pièces +{IdleConfig.formatPercent(self.coinBonus)} %, retour à la vague 1`)
	return true
end

----------------------------------------------------------------------
-- Déroulement
----------------------------------------------------------------------
local function bucketOf(wave: number): string
	if wave <= 25 then
		return "1-25"
	elseif wave <= 50 then
		return "26-50"
	elseif wave <= 100 then
		return "51-100"
	end
	return "101+"
end
Run.bucketOf = bucketOf

function Run:snapshot(wave: number, wall: number)
	local byType, spent, levels, count = {}, 0, 0, 0
	for spot = 1, SPOT_COUNT do
		local tower = self.towers[spot]
		if tower then
			count += 1
			spent += tower.spent
			levels += tower.level
			local entry = byType[tower.type]
			if not entry then
				entry = { n = 0, min = math.huge, max = 0 }
				byType[tower.type] = entry
			end
			entry.n += 1
			entry.min = math.min(entry.min, tower.level)
			entry.max = math.max(entry.max, tower.level)
		end
	end
	local dupes = 0
	for _, n in self.dupes do
		dupes += n
	end
	local bonuses = 0
	for _, tower in self.towers do
		if tower.bonus then
			bonuses += 1
		end
	end
	return {
		wave = wave,
		waveType = IdleConfig.waveType(wave),
		t = self.t,
		coins = self.coins,
		spots = self.unlockedSpots,
		towers = count,
		byType = byType,
		spent = spent,
		levels = levels,
		dupes = dupes,
		dupesByType = table.clone(self.dupes),
		coinBonus = self.coinBonus,
		rebirths = self.rebirths,
		blocked = self.totalBlocked,
		longest = self.longestWall,
		wall = wall,
		bonuses = bonuses,
		forgeSpins = self.forgeSpins,
		income = self.income, -- pièces par seconde (moyenne des 10 dernières vagues, entractes compris)
		spins = self.spins,
		unlockedCount = (function()
			local n = 0
			for _ in self.unlocked do
				n += 1
			end
			return n
		end)(),
	}
end

function Run:runWave(comp)
	local towers = self:compiled()
	local cached = self.memo[comp.wave]
	if cached then
		return cached
	end
	local result = Engine.runWave(comp, towers)
	result.towerTypes = {}
	for i, tower in towers do
		result.towerTypes[i] = tower.type
	end
	self.memo[comp.wave] = result
	return result
end

function Run:endWave(wave: number, comp, result): number
	self.wavesPlayed += 1
	if result.success then
		self.bestWave = math.max(self.bestWave, wave)
		self.highestWave = math.max(self.highestWave, wave)
		self.wave = wave + 1
		local tier = IdleConfig.towerSpinTier(wave)
		if tier > self.pendingSpinTier then
			self.pendingSpinTier = tier
		end
		if wave > self.frontier then
			self.frontier = wave
			local wall = 0
			if self.wallStart[wave] then
				wall = self.t - self.wallStart[wave]
				self.totalBlocked += wall
				table.insert(self.walls, { wave = wave, seconds = wall })
				if wall > self.longestWall then
					self.longestWall, self.longestWallWave = wall, wave
				end
			end
			self.firstClear[wave] = self:snapshot(wave, wall)
			self.runWallSince = nil
		end
		if self.pendingCycle and self.bestWave >= self.pendingCycle.target then
			self.pendingCycle.entry.cycle = self.t - self.pendingCycle.t
			self.pendingCycle = nil
		end
		return IdleConfig.WAVE_CLEAR_DELAY
	end

	self.wavesFailed += 1
	self.failLeak[wave] = result.leak
	if wave == self.frontier + 1 then
		if not self.wallStart[wave] then
			self.wallStart[wave] = self.t
		end
		if not self.runWallSince then
			self.runWallSince = self.t
		end
	end
	self.wave = math.max(1, wave - 1)
	return IdleConfig.WAVE_FAIL_DELAY
end

-- Tours qui ralentissent (Totem de givre, Mage des tempêtes...) : lues dans IdleTowers.
local SLOW_TOWERS = {}
for _, towerType in IdleTowers.ORDER do
	if IdleTowers.Defs[towerType].slow then
		table.insert(SLOW_TOWERS, towerType)
	end
end

-- Au mur : le calcul de « gain » des achats (vagues immortelles) voit mal ce qu'apporte un ralentissement
-- contre un Seigneur de guerre ou une Garde colossale. Quand le joueur est bloqué depuis SOLVER_AFTER,
-- puis toutes les SOLVER_EVERY, il essaie avec le vrai moteur de remplacer une tour par une tour qui
-- ralentit (ou d'en poser une sur un emplacement vide), et garde le meilleur essai s'il rapproche
-- nettement de la réussite de la vague qui bloque. Ces tours de soutien ne sont plus remplacées ensuite.
function Run:wallSolver()
	local wave = math.max(self.wave, self.frontier + 1)
	local since = self.wallStart[wave]
	if not P.SOLVER or not since or self.t - since < P.SOLVER_AFTER then
		return
	end
	if self.solverAt and self.t - self.solverAt < P.SOLVER_EVERY then
		return
	end
	self.solverAt = self.t
	local comp = Engine.composition(wave)
	local function score(towersBySpot): number
		local list = {}
		for spot = 1, SPOT_COUNT do
			local tower = towersBySpot[spot]
			if tower then
				table.insert(list, Engine.compileTower(spot, tower.type, tower.level, self.dupes[tower.type] or 0, tower.bonus))
			end
		end
		return Engine.runWave(comp, list, "ignore").leakScore
	end
	local current = score(self.towers)
	if current <= 0 then
		return
	end
	local best, bestScore = nil, current * P.SOLVER_MIN_GAIN
	for _, towerType in SLOW_TOWERS do
		if self.unlocked[towerType] then
			local placeCost = IdleTowers.Defs[towerType].placeCost
			for spot = 1, SPOT_COUNT do
				local existing = self.towers[spot]
				local refund = if existing then math.floor(existing.spent * IdleConfig.SELL_REFUND) else 0
				if
					self.owned[spot]
					and not (existing and IdleTowers.Defs[existing.type].slow)
					and self.coins + refund >= placeCost
				then
					local copy = table.clone(self.towers)
					copy[spot] = { type = towerType, level = 1 }
					local value = score(copy)
					if value < bestScore then
						best, bestScore = { spot = spot, type = towerType }, value
					end
				end
			end
		end
	end
	if best then
		self:log(
			string.format(
				"au mur de la vague %d : %s de soutien sur l'empl. %d (écart à la réussite %.1f -> %.1f)",
				wave,
				Run.shortName(best.type),
				best.spot,
				current,
				bestScore
			)
		)
		self:execute({ kind = if self.towers[best.spot] then "replace" else "place", spot = best.spot, type = best.type })
		self.towers[best.spot].support = true
		self.solverUses = (self.solverUses or 0) + 1
	end
end

-- Entracte : machines, bonus, renaissance, achats. Renvoie true si le joueur est reparti de la vague 1.
function Run:intermission(): boolean
	self:spinTower()
	self:useForge()
	self:applyBonuses()
	local rebirthed = false
	if
		self.scenario.rebirth
		and self.bestWave >= IdleConfig.REBIRTH_MIN_WAVE
		and self.bestWave >= self.frontier
		and self.runWallSince
		and self.t - self.runWallSince >= P.REBIRTH_STUCK
	then
		rebirthed = self:rebirth()
	end
	if not rebirthed then
		self:wallSolver()
	end
	self:spend()
	self:applyBonuses()
	return rebirthed
end

function Run:recordDamage(comp, result)
	local key = bucketOf(comp.wave) .. "|" .. comp.waveType
	local row = self.damage[key]
	if not row then
		row = {}
		self.damage[key] = row
	end
	for i, amount in result.useful do
		local towerType = result.towerTypes[i]
		row[towerType] = (row[towerType] or 0) + amount
	end
end

function Run:trackIncome(coins: number, seconds: number)
	table.insert(self.recent, { coins = coins, seconds = seconds })
	if #self.recent > 10 then
		table.remove(self.recent, 1)
	end
	local c, s = 0, 0
	for _, entry in self.recent do
		c += entry.coins
		s += entry.seconds
	end
	self.income = if s > 0 then c / s else 0
end

-- Joue jusqu'à `maxSeconds` de jeu. onHour(run, heure) est appelé à chaque heure pleine.
function Run:play(maxSeconds: number, onHour: ((any, number) -> ())?)
	local dt = Engine.DT
	self.t = Engine.delaySteps(IdleConfig.FIRST_WAVE_DELAY) * dt
	self:intermission()
	local nextHour = 3600
	while self.t < maxSeconds and self.frontier < P.MAX_WAVE do
		local wave = self.wave
		local comp = Engine.composition(wave)
		local result = self:runWave(comp)
		self.t += result.seconds
		local earned = result.coins * (1 + self.coinBonus / 100)
		self.coins += earned
		self.totalEarned += earned
		if self.journal then
			local leaked = 0
			for _, damage in result.leak do
				leaked += damage
			end
			self:log(
				string.format(
					"vague %d (%s) %s en %.0f s, +%s pièces%s",
					wave,
					IdleConfig.WAVE_TYPES[comp.waveType].displayName,
					if result.success then "réussie" else "RATÉE",
					result.seconds,
					Modules.NumberFormat.short(earned),
					if result.success then "" else ` (la base a pris {leaked} dégâts)`
				)
			)
		end
		self:recordDamage(comp, result)
		local delay = self:endWave(wave, comp, result)
		if self:intermission() then
			delay = IdleConfig.FIRST_WAVE_DELAY
		end
		local pause = Engine.delaySteps(delay) * dt
		self.t += pause
		self:trackIncome(earned, result.seconds + pause)
		while onHour and self.t >= nextHour do
			onHour(self, nextHour / 3600)
			nextHour += 3600
		end
	end
	-- Mur en cours à la fin de la simulation
	local open = self.wallStart[self.frontier + 1]
	self.openWall = if open then self.t - open else 0
	self.endTime = self.t
end

return Run

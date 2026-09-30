--!optimize 2
-- Une partie du mode infini jouée par un joueur simulé, du début jusqu'à la durée demandée.
-- Règles reprises de PlotGame.luau : vague réussie -> vague suivante, vague ratée (UN SEUL ennemi au bout
-- du chemin) -> une vague plus bas, délais entre vagues, prix des emplacements (le n-ième coûte
-- PlotLayout.spotCost(n), achetés dans n'importe quel ordre), des tours, des améliorations, revente à 50 %,
-- bonus de pièces, lancers de l'autel des héros payés en pièces (x1, x10, x100... aux chances du record).
--
-- Le joueur simulé (réglages dans Run.POLICY) :
--   * ramasse toutes les pièces tout de suite (joueur actif) ;
--   * pendant chaque entracte, dépense ses pièces sur l'achat qui a le meilleur rapport gain / prix :
--       - améliorer une tour,
--       - poser une tour sur un emplacement vide,
--       - acheter un emplacement + y poser une tour (il choisit l'emplacement le mieux placé pour cette tour),
--       - remplacer une des tours les plus faibles (50 % remboursés),
--       - acheter des lancers à l'autel des héros (Run:spinOptions : doublons des tours posées + chance de
--         débloquer une tour qui vaut mieux que les achats actuels ; prix avec le compteur de lancers, +0,05 %
--         par lancer) ; à rapport presque égal, il prend le plus gros lot qu'il peut payer (x10 plutôt que
--         10 fois x1), ou attend quelques minutes pour l'avoir.
--     (scénarios avec forge : le prix du lancer de la forge est mis de côté avant tout, voir forgeReserve)
--     Le « gain » d'une tour neuve compte aussi ses améliorations suivantes (on la juge au niveau où elle
--     devient rentable). Le gain est mesuré contre les prochaines vagues (ou contre la vague qui bloque, en
--     visant les ennemis qui l'ont vraiment traversée) grâce aux vagues « immortelles » d'Engine.hits :
--     coups que chaque tour peut porter, x dégâts (plafonnés aux PV de l'ennemi, un gros tir sur un petit
--     écuyer est gâché) ; feu des flèches et rayon du Sorcier : voir Run.valueOf. Une seule fuite fait rater
--     la vague : chaque groupe d'ennemis compte d'autant plus que les tours en viennent mal à bout (voir
--     Run:evaluate).
--   * si le meilleur achat est trop cher mais payable en moins de SAVE_SECONDS de farm (BIG_SPIN_SAVE_SECONDS
--     pour un lot x1 000 ou plus de l'autel), il économise ; sinon il achète le meilleur achat abordable ;
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
	-- Autel des héros : à rapport gain / prix presque égal (au moins 90 % du meilleur lot), il prend le plus
	-- gros lot qu'il peut payer.
	SPIN_BULK_TOLERANCE = 0.9,
	-- ... 75 % pour x1 000 et plus : chaque lancer coûtant +0,05 % de plus que le précédent, 1 000 lancers d'un
	-- coup coûtent 1 297 fois le prix du prochain (30 % de plus que 1 000 fois ce prix)
	SPIN_BIG_BULK_TOLERANCE = 0.75,
	BIG_SPIN_SAVE_SECONDS = 1800, -- ... et il économise jusqu'à 30 min de revenu pour un lot x1 000 ou plus
	-- (5 min, SAVE_SECONDS, pour un x100)
	BLOCKED_LEAK_WEIGHT = 0.7, -- au mur : part des ennemis qui ont vraiment fui dans le poids des groupes
	REBIRTH_STUCK = 15 * 60, -- scénario « renaissance » : renaît après 15 min bloqué au record
	MAX_WAVE = 3000,
}

Run.SCENARIOS = {
	base = {
		id = "base",
		label = "joueur actif : achats au meilleur rapport (lancers de l'autel compris), sans forge ni renaissance",
		forge = false,
		rebirth = false,
	},
	forge = {
		id = "forge",
		label = "base + la forge runique en pièces dès que son prix vaut moins de 30 min de revenu (100 K, x5 sous 1 T, puis x2 ; prix mis de côté), rune sur la meilleure tour",
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
	-- Pour mesurer ce qu'apporte le Sorcier des arcanes (rayon) : même joueur que « base », mais il ne pose
	-- jamais de Sorcier. Les murs des Seigneurs de guerre et des Gardes colossales se comparent à « base ».
	["sans-sorcier"] = {
		id = "sans-sorcier",
		label = "base, mais le joueur ne pose jamais de Sorcier des arcanes (pour comparer les murs des boss et des colosses)",
		forge = false,
		rebirth = false,
		banned = { Laser = true },
	},
	-- « TOUT SUR L'ARCHER » (question du propriétaire, 01/10/2026 : sa copine a eu la rune x20 dégâts au tout
	-- premier lancer de la forge et l'a mise sur un Archer). Un joueur qui ne joue QUE l'Archer du rempart et un
	-- Totem de givre posé juste à côté, et qui met toutes ses pièces dans l'Archer (voir Run:archerIntermission).
	-- Pas de forge « normale » ni d'autre tour. archer = son plan :
	--   runes = les runes que donnent ses premiers lancers de forge en pièces, dans l'ordre (FORCÉES : le 1er lancer,
	--           100 K, donne toujours x20 dégâts ; le 2e, 500 K, x2 vitesse), toutes posées sur l'Archer ; ensuite il
	--           ne relance plus la forge. {} = jamais de forge (pour comparer : le même joueur sans rune) ;
	--   upgradeFrost = le Totem est aussi amélioré (il choisit entre l'Archer et le Totem au meilleur rapport gain /
	--                  prix, comme le joueur « base ») ; false = le Totem reste niveau 1 (juste posé).
	-- Ces scénarios ne sont pas dans la liste par défaut de run.ps1 : -Scenarios base,forge,archer-x20-x2,...
	["archer-x20"] = {
		id = "archer-x20",
		label = "que l'Archer + un Totem de givre à côté (niveau 1), 1er lancer de forge = x20 dégâts sur l'Archer, tout le reste dans l'Archer",
		forge = false,
		rebirth = false,
		archer = { runes = { "Damage20" }, upgradeFrost = false },
	},
	["archer-x20-x2"] = {
		id = "archer-x20-x2",
		label = "comme archer-x20, + 2e lancer de forge = x2 vitesse d'attaque sur l'Archer",
		forge = false,
		rebirth = false,
		archer = { runes = { "Damage20", "Speed2" }, upgradeFrost = false },
	},
	["archer-x20-x2-givre"] = {
		id = "archer-x20-x2-givre",
		label = "comme archer-x20-x2, mais le Totem de givre est aussi amélioré (meilleur rapport gain / prix entre l'Archer et le Totem)",
		forge = false,
		rebirth = false,
		archer = { runes = { "Damage20", "Speed2" }, upgradeFrost = true },
	},
	["archer-x20-renaissance"] = {
		id = "archer-x20-renaissance",
		label = "archer-x20 + renaissance dès que bloqué 15 min au record (vague >= 15)",
		forge = false,
		rebirth = true,
		archer = { runes = { "Damage20" }, upgradeFrost = false },
	},
	["archer-x20-x2-renaissance"] = {
		id = "archer-x20-x2-renaissance",
		label = "archer-x20-x2 + renaissance dès que bloqué 15 min au record (vague >= 15)",
		forge = false,
		rebirth = true,
		archer = { runes = { "Damage20", "Speed2" }, upgradeFrost = false },
	},
	["archer-sans-rune"] = {
		id = "archer-sans-rune",
		label = "le même joueur (que l'Archer + un Totem de givre niveau 1, tout dans l'Archer) mais SANS aucune rune : pour voir ce qu'apporte le x20",
		forge = false,
		rebirth = false,
		archer = { runes = {}, upgradeFrost = false },
	},
}

-- Emplacements du joueur « tout sur l'Archer » (scénarios avec `archer`). Choisis au vrai moteur (analyse du
-- 01/10/2026) parmi toutes les paires : Archer sur l'emplacement 1 (gratuit, au milieu de deux allers du chemin)
-- et Totem sur l'emplacement 5, juste à sa gauche, au coin du chemin : son aura couvre deux allers ET le virage,
-- tous dans la portée de l'Archer. Un ennemi à 10 studs/s y reste ~18 s à portée de l'Archer au lieu de ~9 s sans
-- Totem (15 s avec le Totem sur l'emplacement 2, gratuit : cette paire demande ~25 % de dégâts en plus). Le 5e
-- emplacement coûte 100 pièces.
Run.ARCHER_SPOTS = { archer = 1, frost = 5 }

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

-- Tours de contrôle : elles ralentissent, étourdissent ou fragilisent, donc changent les coups des autres.
local CONTROL_TOWERS = {}
for _, towerType in IdleTowers.ORDER do
	local def = IdleTowers.Defs[towerType]
	if def.slow or def.stunDuration or def.fragilityBase then
		CONTROL_TOWERS[towerType] = true
	end
end
Run.CONTROL_TOWERS = CONTROL_TOWERS

-- Coups d'une tour seule (niveau 1), avec les tours de contrôle `context` ({ { spot, type } }, clé contextKey)
-- déjà posées : leurs ralentissements, étourdissements et leur fragilité comptent (row.frag).
local function soloHits(spot: number, towerType: string, comp, context, contextKey: string?)
	local key = spot .. towerType .. "|" .. (contextKey or "") .. "|" .. comp.key
	local cached = SOLO_HITS[key]
	if cached then
		return cached
	end
	local towers = {}
	local index = 1
	if context then
		for _, entry in context do
			table.insert(towers, Engine.compileTower(entry.spot, entry.type, 1, 0, nil))
		end
		-- Même ordre que le jeu (ordre des emplacements)
		table.insert(towers, Engine.compileTower(spot, towerType, 1, 0, nil))
		table.sort(towers, function(a, b)
			return a.spot < b.spot
		end)
		for i, tower in towers do
			if tower.spot == spot then
				index = i
			end
		end
	else
		towers[1] = Engine.compileTower(spot, towerType, 1, 0, nil)
	end
	local hits = Engine.hits(comp, towers)[index]
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
	-- [spot] = { type, level, spent, runes = { Damage = id, Speed = id }, placedAt } : une rune de la forge par
	-- emplacement (dégâts, vitesse), qui se cumulent, comme dans le jeu (PlotGame).
	self.towers = {}
	self.unlocked = {}
	for _, towerType in IdleConfig.STARTING_TOWERS do
		self.unlocked[towerType] = true
	end
	self.dupes = {}
	self.bonuses = {}
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
	self.purchases = { upgrade = 0, place = 0, spot = 0, replace = 0, forge = 0, spin = 0 }
	self.unlockedAt = {}
	self.spins = 0 -- lancers de l'autel achetés (x10 = 10 lancers)
	self.spinBuys = {} -- [nombre du lot] = { n = achats, firstWave = record au 1er achat, firstT }
	self.spinBuysByBucket = {} -- [tranche de vagues] = nombre d'achats à l'autel (tous lots confondus)
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
	self.spentBy = { upgrade = 0, place = 0, spot = 0, replace = 0, forge = 0, spin = 0 } -- pièces dépensées par type d'achat
	self.spentByBucket = {} -- [tranche de vagues] = { [type d'achat] = pièces } (tranche = record au moment de l'achat)
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
				table.insert(list, Engine.compileTower(spot, tower.type, tower.level, dupes, tower.runes))
				table.insert(parts, `{spot}:{tower.type}:{tower.level}:{IdleConfig.runeList(tower.runes)}:{dupes}`)
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

-- Tours de contrôle posées (sauf sur `except`) : liste { { spot, type } } et clé (pour le cache de soloHits).
function Run:controlContext(except: number?)
	local list, parts = {}, {}
	for spot = 1, SPOT_COUNT do
		local tower = self.towers[spot]
		if tower and spot ~= except and CONTROL_TOWERS[tower.type] then
			table.insert(list, { spot = spot, type = tower.type })
			table.insert(parts, spot .. tower.type)
		end
	end
	if #list == 0 then
		return nil, ""
	end
	return list, table.concat(parts, ",")
end

-- Dégâts effectifs et multiplicateur de cadence (rune x2 vitesse) d'une tour, avec ces runes (format de
-- IdleConfig.parseRunes ; les runes de dégâts et de vitesse se cumulent). Rayon du Sorcier : pas de cadence
-- (la rune de vitesse fait monter le rayon plus vite, ce que les estimations ignorent) : 1.
function Run:power(towerType: string, level: number, runes: any?)
	local stats = IdleTowers.effectiveStats(towerType, level, self.dupes[towerType] or 0, runes)
	local cooldown = IdleTowers.Defs[towerType].cooldown
	return stats.damage, if cooldown then cooldown / stats.cooldown else 1
end

-- Vrai si le scénario interdit cette tour (scénario « sans-sorcier »).
function Run:banned(towerType: string): boolean
	return self.scenario.banned ~= nil and self.scenario.banned[towerType] == true
end

-- Rayon : secondes pour infliger `x` fois ses dégâts de base (IdleTowers.beamDamage à l'envers).
local function beamKillTime(x: number, rate: number, max: number): number
	local rampTime = (max - 1) / rate
	local rising = rampTime + rate * rampTime * rampTime / 2
	if x <= rising then
		-- racine de x = t + rate t² / 2, écrite sans soustraction (précise même pour un x minuscule)
		return 2 * x / (1 + math.sqrt(1 + 2 * rate * x))
	end
	return rampTime + (x - rising) / max
end

-- Dégâts utiles estimés d'une tour contre le groupe g (vagues immortelles d'Engine.hits) : coups x dégâts
-- (plafonnés aux PV de l'ennemi : un gros tir sur un petit écuyer est gâché) x cadence.
--   Rayon : dégâts de base x montée x secondes (row[g]), mais pas plus que ce qu'il peut infliger en tuant
--   ses cibles l'une après l'autre (la montée repart de x1 à chaque nouvelle cible : contre des petits
--   ennemis, il ne chauffe jamais).
--   Flèches enflammées : + coups de feu x (fireDamageRatio x fireTick x dégâts), plafonnés aux PV.
--   fragility (Totem de givre, 0 si absent) : les coups tombés sur un ennemi fragile (row.frag, row.fireFrag)
--   font x (1 + fragility). Les coups sont comptés avec des tours niveau 1 ; `fragility` est celle des
--   Totems du joueur à leur niveau actuel (Run:evaluate : la plus forte).
function Run.valueOf(row, g: number, group, damage: number, speed: number, fragility: number?): number
	local F = fragility or 0
	local hp = group.hp
	local value = 0
	local contact = row.contact
	local frag = row.frag
	if contact then
		local ramped = row[g]
		if ramped > 0 and damage > 0 then
			-- Part de la montée sur un ennemi fragile : dégâts moyens x (1 + F x cette part)
			local effective = damage
			if F > 0 and frag then
				effective = damage * (1 + F * frag[g] / ramped)
			end
			local killRate = hp / beamKillTime(hp / effective, row.beamRampRate, row.beamRampMax)
			value = math.min(effective * ramped, contact[g] * killRate)
		end
	else
		local hits = row[g]
		local fragileHits = if F > 0 and frag then frag[g] else 0
		value = (hits - fragileHits) * speed * (if damage < hp then damage else hp)
		if fragileHits > 0 then
			local boosted = damage * (1 + F)
			value += fragileHits * speed * (if boosted < hp then boosted else hp)
		end
	end
	local fire = row.fire
	if fire then
		local burn = damage * row.fireHit
		local fragileBurns = if F > 0 and row.fireFrag then row.fireFrag[g] else 0
		value += (fire[g] - fragileBurns) * (if burn < hp then burn else hp)
		if fragileBurns > 0 then
			local boosted = burn * (1 + F)
			value += fragileBurns * (if boosted < hp then boosted else hp)
		end
	end
	return value
end
local valueOf = Run.valueOf

----------------------------------------------------------------------
-- Valeur des achats
----------------------------------------------------------------------

-- Vagues visées : la vague qui bloque (et ce qui a fui), sinon les prochaines vagues ratables.
-- long = true : les LONG_FOCUS prochaines vagues ratables à poids égal (pour les remplacements, qui
-- doivent valoir le coup sur la durée et pas seulement contre le mur du moment).
function Run:buildFocus(long: boolean?)
	local focus = {}
	local start = math.max(self.wave, self.frontier + 1)
	-- Le poids de chaque groupe d'ennemis (lambda) est calculé par Run:evaluate, selon la puissance actuelle.
	-- leak = ennemis qui ont vraiment fui au dernier échec de cette vague (au mur seulement).
	local function add(wave: number, weight: number, leak)
		local comp = Engine.composition(wave)
		local eps, leakShare = {}, nil
		for g, group in comp.groups do
			eps[g] = 1e-6 * group.need
		end
		if leak then
			local total = 0
			for g in comp.groups do
				total += leak[g]
			end
			if total > 0 then
				leakShare = {}
				for g in comp.groups do
					leakShare[g] = leak[g] / total
				end
			end
		end
		table.insert(focus, { wave = wave, comp = comp, weight = weight, lambda = {}, eps = eps, leakShare = leakShare })
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

-- Fragilité des Totems de givre posés (la plus forte : deux Totems ne s'additionnent pas), sans compter
-- l'emplacement `except` (tour remplacée), avec, si donnée, une tour de ce type et de ce niveau en plus.
function Run:fragilityOf(except: number?, extraType: string?, extraLevel: number?): number
	local best = 0
	for spot, tower in self.towers do
		if spot ~= except then
			best = math.max(best, IdleTowers.fragilityAt(IdleTowers.Defs[tower.type], tower.level))
		end
	end
	if extraType then
		best = math.max(best, IdleTowers.fragilityAt(IdleTowers.Defs[extraType], extraLevel or 1))
	end
	return best
end

-- Puissance utile actuelle U[g] contre chaque vague visée, et part de chaque tour.
function Run:evaluate(focus)
	local typesBySpot, layoutKey = self:typesBySpot()
	local powers = {}
	for spot, tower in self.towers do
		local damage, speed = self:power(tower.type, tower.level, tower.runes)
		powers[spot] = { damage = damage, speed = speed }
	end
	local F = self:fragilityOf()
	self.fragility = F
	for _, f in focus do
		local groups = f.comp.groups
		f.hits = layoutHits(typesBySpot, layoutKey, f.comp)
		local U = table.create(#groups, 0)
		f.contrib = {}
		for spot, power in powers do
			local row = f.hits[spot]
			local contrib = table.create(#groups, 0)
			for g, group in groups do
				local value = valueOf(row, g, group, power.damage, power.speed, F)
				contrib[g] = value
				U[g] += value
			end
			f.contrib[spot] = contrib
		end
		f.U = U
		-- Poids des groupes : une seule fuite fait rater la vague, donc c'est le groupe dont les tours viennent
		-- le moins bien à bout qui compte (PV à infliger / puissance utile, au carré). Au mur, on vise aussi
		-- les ennemis qui ont vraiment fui (BLOCKED_LEAK_WEIGHT).
		local total = 0
		for g, group in groups do
			local lack = group.need / math.max(U[g], f.eps[g])
			f.lambda[g] = lack * lack
			total += f.lambda[g]
		end
		for g in groups do
			f.lambda[g] /= total
			if f.leakShare then
				f.lambda[g] = P.BLOCKED_LEAK_WEIGHT * f.leakShare[g] + (1 - P.BLOCKED_LEAK_WEIGHT) * f.lambda[g]
			end
		end
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

-- Gain (en score) si la contribution de `spot` devient : valueOf(hits, g, dégâts, cadence).
-- F = fragilité des Totems (Run:evaluate). newF (Totem amélioré) : la fragilité change aussi pour TOUTES les
-- autres tours (leurs coups sur des ennemis fragiles), ajoutée au gain.
local function gainReplacingSpot(focus, spot: number, hitsFor, damage: number, speed: number, F: number, newF: number?, powers): number
	local gain = 0
	for fi, f in focus do
		local groups = f.comp.groups
		local old = f.contrib[spot]
		local hits = hitsFor(fi, f)
		for g, group in groups do
			local new = valueOf(hits, g, group, damage, speed, newF or F)
			local delta = new - (if old then old[g] else 0)
			if newF and powers then
				for s, power in powers do
					if s ~= spot then
						delta += valueOf(f.hits[s], g, group, power.damage, power.speed, newF) - f.contrib[s][g]
					end
				end
			end
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
		local damage, speed = self:power(tower.type, tower.level + 1, tower.runes)
		-- Totem de givre : son niveau fait monter la fragilité, qui renforce les autres tours.
		local newF = nil
		if IdleTowers.Defs[tower.type].fragilityBase then
			local nextF = self:fragilityOf(spot, tower.type, tower.level + 1)
			if nextF > self.fragility then
				newF = nextF
			end
		end
		local gain = gainReplacingSpot(focus, spot, function(_, f)
			return f.hits[spot]
		end, damage, speed, self.fragility, newF, self.powers)
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
	-- Fragilité après ce changement (ancienne tour retirée, nouveau Totem jugé à son niveau 1).
	local F = self:fragilityOf(spot, if def.fragilityBase then towerType else nil, 1)
	-- Rayon du Sorcier : ses dégâts montent avec le temps passé sur la cible, donc avec les ralentissements
	-- des autres tours (Totem, Mage) : on le juge aussi dans la vraie disposition, pas tout seul. Pareil pour
	-- une tour de contrôle (ralentit, étourdit ou fragilise : elle change les coups des autres tours).
	if CONTROL_TOWERS[towerType] or def.kind == "Beam" or (existing and CONTROL_TOWERS[existing.type]) then
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
						u[g] += valueOf(row, g, group, power.damage, power.speed, F)
					end
				end
			end
			for g in u do
				u[g] -= f.U[g]
			end
			baseDelta[fi] = u
		end
	else
		-- Les autres tours : jugées seules, mais avec les tours de contrôle déjà posées (ralentissements,
		-- étourdissements et fragilité comptent pour elles aussi).
		local contextSpots, contextKey = self:controlContext(spot)
		for fi, f in focus do
			newHits[fi] = soloHits(spot, towerType, f.comp, contextSpots, contextKey)
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
				local delta = d[g] + valueOf(hits, g, group, damage, 1, F)
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
				if self.unlocked[towerType] and not self:banned(towerType) then
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

	-- Limite de tours identiques (IdleTowers.MAX_COPIES, comme PlotGame:placeTower) : pas de tour de plus d'un type
	-- déjà posé au maximum (un remplacement compte la tour remplacée seulement si c'est le même type).
	local copies = IdleTowers.countCopies(self.towers)
	for _, candidate in candidates do
		local existing = self.towers[candidate.spot]
		for _, towerType in IdleTowers.ORDER do
			if
				self.unlocked[towerType]
				and not self:banned(towerType)
				and not (existing and existing.type == towerType)
				and (candidate.onlyType == nil or candidate.onlyType == towerType)
				and IdleTowers.canPlaceCopy(copies, towerType, existing and existing.type)
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
-- Pièces dépensées, par type d'achat et par tranche de vagues (record + 1 au moment de l'achat).
function Run:addSpent(kind: string, cost: number)
	self.spentBy[kind] += cost
	local bucket = Run.bucketOf(self.frontier + 1)
	local row = self.spentByBucket[bucket]
	if not row then
		row = { upgrade = 0, place = 0, spot = 0, replace = 0, forge = 0, spin = 0 }
		self.spentByBucket[bucket] = row
	end
	row[kind] += cost
end

function Run:purchased(kind: string)
	self.purchases[kind] += 1
	local gap = self.t - self.lastPurchaseAt
	if gap > self.longestNoPurchase then
		self.longestNoPurchase, self.longestNoPurchaseAt = gap, self.frontier + 1
	end
	self.lastPurchaseAt = self.t
end

-- Comme PlotGame:removeTower : les runes de la tour retournent dans l'inventaire (dégâts d'abord) tant qu'il
-- y a de la place.
function Run:removeTower(spot: number)
	local tower = self.towers[spot]
	if tower then
		for _, slot in IdleConfig.RUNE_SLOTS do
			local runeId = tower.runes[slot.kind]
			if runeId and #self.bonuses < IdleConfig.MAX_BONUS_INVENTORY then
				table.insert(self.bonuses, runeId)
			end
		end
	end
	self.towers[spot] = nil
end

function Run:execute(option)
	if option.kind == "spin" then
		self:buySpins(option.count)
		self:purchased("spin")
		return
	end
	if option.kind == "upgrade" then
		local tower = self.towers[option.spot]
		local cost = IdleTowers.upgradeCost(tower.type, tower.level)
		assert(self.coins >= cost)
		self.coins -= cost
		tower.level += 1
		tower.spent += cost
		self:addSpent("upgrade", cost)
		self:changed(false)
		self:purchased("upgrade")
		self:log(`achat : amélioration {Run.shortName(tower.type)} (empl. {option.spot}) niv {tower.level} pour {Modules.NumberFormat.short(cost)}`)
		return
	end

	local spot = option.spot
	-- Même règle que PlotGame:placeTower : limite de tours identiques (IdleTowers.MAX_COPIES). Les options qui la
	-- dépassent ne sont jamais proposées (packageOptions, wallSolver) : vérifié ici avant tout achat.
	local replacedType = if self.towers[spot] then self.towers[spot].type else nil
	assert(
		IdleTowers.canPlaceCopy(IdleTowers.countCopies(self.towers), option.type, replacedType),
		`limite de tours identiques dépassée : {option.type}`
	)
	if option.kind == "spot" then
		-- Même règle que PlotGame:buySpot : le prix ne dépend que du nombre d'emplacements déjà possédés.
		local nth = self.unlockedSpots + 1
		local cost = PlotLayout.spotCost(nth)
		assert(not self.owned[spot] and self.coins >= cost)
		self.coins -= cost
		self.owned[spot] = true
		self.unlockedSpots = nth
		self.spotTimes[nth] = { t = self.t, wave = self.frontier + 1, spot = spot }
		self:addSpent("spot", cost)
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
	self.towers[spot] = { type = option.type, level = 1, spent = def.placeCost, runes = {}, placedAt = self.t }
	self:addSpent(if existing then "replace" else "place", def.placeCost)
	self:changed(true)
	self:purchased(if existing then "replace" else "place")
	self:log(`achat : pose {Run.shortName(option.type)} sur l'empl. {spot} pour {Modules.NumberFormat.short(def.placeCost)}`)
end

-- Runes que la forge peut tirer (PlotGame:forgeDrawable) : celles qui améliorent au moins une tour POSÉE dans
-- l'emplacement de leur sorte (dégâts ou vitesse : IdleConfig.weakestRunes puis forgeDrawableRunes ;
-- l'inventaire ne compte pas).
function Run:forgeDrawable()
	local placed = {}
	for _, tower in self.towers do
		table.insert(placed, tower.runes)
	end
	return IdleConfig.forgeDrawableRunes(IdleConfig.weakestRunes(placed))
end

-- Scénarios avec forge : le joueur lance la forge en pièces dès que c'est possible (plus de délai). Pour ça
-- il met son prix de côté (il passe avant les autres achats), si ce prix vaut moins de FORGE_SAVE_SECONDS
-- de revenu (sinon il attend d'avoir un meilleur revenu). Prix IdleConfig.forgeCoinPrice(lancers en pièces
-- déjà achetés, self.forgeSpins, jamais remis à zéro : 100 K, x5 sous 1 T, puis x2). Forge bloquée (aucune
-- rune n'améliorerait une tour posée) : rien. Jugée seulement sur son gain immédiat, la forge ne serait
-- presque jamais achetée ; ce scénario mesure ce qu'elle apporte.
function Run:forgeReserve(): number
	if not self.scenario.forge then
		return 0
	end
	if #self.bonuses >= IdleConfig.MAX_BONUS_INVENTORY or next(self.towers) == nil then
		return 0
	end
	if #(self:forgeDrawable()) == 0 then
		return 0
	end
	local cost = IdleConfig.forgeCoinPrice(self.forgeSpins)
	if cost >= math.huge or cost > self.income * P.FORGE_SAVE_SECONDS then
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
	self.unlockValues = nil -- valeur des tours à débloquer : recalculée une fois par entracte
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
		-- Autel des héros : comparé aux autres achats (le meilleur rapport actuel sert à juger les déblocages)
		local bestRatio = 0
		for _, option in options do
			bestRatio = math.max(bestRatio, option.ratio)
		end
		self:spinOptions(focus, options, bestRatio)
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
			-- Un gros lot de l'autel (x1 000 et plus) vaut qu'on économise plus longtemps (comme un vrai joueur).
			local patience = if best.kind == "spin" and best.count >= 1000 then P.BIG_SPIN_SAVE_SECONDS else P.SAVE_SECONDS
			if wait <= patience then
				return -- économise pour le meilleur achat
			end
			-- Trop long à économiser : il prend le meilleur achat abordable, s'il vaut au moins
			-- FALLBACK_MIN_RATIO fois le meilleur (sinon il économise quand même).
			if not bestAffordable or bestAffordable.ratio < P.FALLBACK_MIN_RATIO * best.ratio then
				return
			end
			choice = bestAffordable
		end
		if choice.kind == "spin" then
			-- À rapport presque égal, le plus gros lot payable (comme un vrai joueur : x100 plutôt que 100 x1).
			-- Un lot pas encore payable mais presque aussi bon : il attend quelques minutes pour l'avoir (5 min de
			-- revenu pour x100, BIG_SPIN_SAVE_SECONDS pour x1 000 et plus) plutôt que de cliquer x1 en boucle.
			-- Avec +0,05 % par lancer, 1 000 lancers coûtent 1 297 fois le prix du prochain : à partir de x1 000,
			-- il accepte un rapport un peu moins bon (SPIN_BIG_BULK_TOLERANCE), le prix de la commodité.
			local waitFor = nil
			local bestCount = choice.count
			for _, option in options do
				local tolerance = if option.kind == "spin" and option.count >= 1000 then P.SPIN_BIG_BULK_TOLERANCE else P.SPIN_BULK_TOLERANCE
				if option.kind == "spin" and option.count > bestCount and option.ratio >= tolerance * choice.ratio then
					if option.cost <= available then
						choice = option
						bestCount = option.count
						waitFor = nil
					else
						local patience = if option.count >= 1000 then P.BIG_SPIN_SAVE_SECONDS else P.SAVE_SECONDS
						local wait = if self.income > 0 then (option.cost - available) / self.income else math.huge
						if wait <= patience then
							waitFor = option
							bestCount = option.count
						end
					end
				end
			end
			if waitFor then
				return -- économise pour le plus gros lot
			end
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

-- Tirages des lots de l'autel : mêmes lois que PlotGame (binomialRoll / splitRolls), avec le Rng du simulateur.
-- Jusqu'à EXACT_SPINS essais : un tirage par essai ; au-delà : loi normale (ou de Poisson s'il y a peu de succès).
local EXACT_SPINS = 1000

function Run:normalRoll(): number
	local u1 = 1 - self.rng:next()
	local u2 = self.rng:next()
	return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
end

function Run:poissonRoll(mean: number): number
	local limit, count, product = math.exp(-mean), 0, self.rng:next()
	while product > limit do
		count += 1
		product *= self.rng:next()
	end
	return count
end

function Run:binomialRoll(trials: number, chance: number): number
	if trials <= 0 or chance <= 0 then
		return 0
	elseif chance >= 1 then
		return trials
	elseif trials <= EXACT_SPINS then
		local hits = 0
		for _ = 1, trials do
			if self.rng:next() < chance then
				hits += 1
			end
		end
		return hits
	end
	local mean = trials * chance
	if mean < 30 then
		return math.min(trials, self:poissonRoll(mean))
	elseif trials - mean < 30 then
		return math.max(0, trials - self:poissonRoll(trials - mean))
	end
	local roll = math.floor(mean + math.sqrt(mean * (1 - chance)) * self:normalRoll() + 0.5)
	return math.clamp(roll, 0, trials)
end

function Run:splitRolls(total: number, weights: { number }): { number }
	local counts = table.create(#weights, 0)
	local last, weightLeft = 0, 0
	for i, weight in weights do
		if weight > 0 then
			last = i
			weightLeft += weight
		end
	end
	local left = total
	for i, weight in weights do
		if weight <= 0 then
			continue
		elseif i == last then
			counts[i] = left
			break
		end
		local got = self:binomialRoll(left, weight / weightLeft)
		counts[i] = got
		left -= got
		weightLeft -= weight
	end
	return counts
end

-- Chance (0 à 1) de chaque tour à UN lancer, aux chances du record (IdleConfig.towerSpinTier(record)).
function Run:spinChances(): { [string]: number }
	local odds = IdleConfig.TOWER_SPIN_TIERS[IdleConfig.towerSpinTier(self.highestWave)].odds
	local total = 0
	for _, rarity in IdleConfig.RARITY_ORDER do
		total += odds[rarity] or 0
	end
	local chances = {}
	for _, rarity in IdleConfig.RARITY_ORDER do
		local choices = IdleTowers.ofRarity(rarity)
		for _, towerType in choices do
			chances[towerType] = (odds[rarity] or 0) / total / #choices
		end
	end
	return chances
end

-- Autel des héros : `count` lancers payés en pièces (PlotGame:spinTower : nombre proposé ET débloqué au
-- record, prix IdleConfig.towerSpinCost avec le compteur des lancers déjà achetés (self.spins, comme
-- idle.towerSpinsBought : jamais remis à zéro), chances du record, tirage par rareté puis par tour).
function Run:buySpins(count: number)
	local cost = IdleConfig.towerSpinCost(self.highestWave, count, self.spins)
	assert(IdleConfig.towerSpinBulkAvailable(self.highestWave, count) and cost < math.huge and self.coins >= cost)
	self.coins -= cost
	self.spins += count
	self:addSpent("spin", cost)
	local buys = self.spinBuys[count]
	if not buys then
		buys = { n = 0, firstWave = self.highestWave, firstT = self.t, spent = 0 }
		self.spinBuys[count] = buys
	end
	buys.n += 1
	buys.spent += cost
	local bucket = Run.bucketOf(self.frontier + 1)
	self.spinBuysByBucket[bucket] = (self.spinBuysByBucket[bucket] or 0) + 1
	local tier = IdleConfig.towerSpinTier(self.highestWave)
	local odds = IdleConfig.TOWER_SPIN_TIERS[tier].odds
	local rarityWeights = {}
	for index, rarity in IdleConfig.RARITY_ORDER do
		rarityWeights[index] = odds[rarity] or 0
	end
	local perRarity = self:splitRolls(count, rarityWeights)
	local parts = {}
	for index = #IdleConfig.RARITY_ORDER, 1, -1 do
		local rarity = IdleConfig.RARITY_ORDER[index]
		local choices = IdleTowers.ofRarity(rarity)
		local perTower = self:splitRolls(perRarity[index], table.create(#choices, 1))
		for i, towerType in choices do
			local got = perTower[i]
			if got > 0 then
				local isNew = not self.unlocked[towerType]
				if isNew then
					self.unlocked[towerType] = true
					self.unlockedAt[towerType] = { t = self.t, wave = self.frontier }
				end
				local dupes = if isNew then got - 1 else got
				if dupes > 0 then
					self.dupes[towerType] = (self.dupes[towerType] or 0) + dupes
				end
				table.insert(parts, `{Run.shortName(towerType)} x{Modules.NumberFormat.short(got)}{if isNew then " (NOUVELLE)" else ""}`)
			end
		end
	end
	self:changed(false)
	self.unlockValues = nil -- les tours débloquées ont peut-être changé
	self:log(`autel x{Modules.NumberFormat.short(count)} (palier {tier}) pour {Modules.NumberFormat.short(cost)} : {table.concat(parts, ", ")}`)
end

-- Valeur de débloquer chaque tour encore verrouillée : ce que sa meilleure pose rapporte EN PLUS de ce que
-- les mêmes pièces rapporteraient avec le meilleur achat actuel (bestRatio). 0 si elle ne ferait pas mieux.
-- Calculé une fois par entracte (c'est long), remis à zéro après un lancer.
function Run:computeUnlockValues(focus, bestRatio: number)
	local values = {}
	local weakest, weakestShare = nil, math.huge
	for spot in self.towers do
		local share = 0
		for _, f in focus do
			for g in f.comp.groups do
				if f.U[g] > 0 then
					share += f.weight * f.lambda[g] * f.contrib[spot][g] / f.U[g]
				end
			end
		end
		if share < weakestShare then
			weakest, weakestShare = spot, share
		end
	end
	for _, towerType in IdleTowers.ORDER do
		if not self.unlocked[towerType] and self:banned(towerType) then
			values[towerType] = 0 -- scénario « sans-sorcier » : il ne la posera jamais
		elseif not self.unlocked[towerType] then
			local candidates = {}
			for spot = 1, SPOT_COUNT do
				if self.owned[spot] and not self.towers[spot] then
					table.insert(candidates, { spot = spot, newSpot = false })
					break
				end
			end
			for _, spot in SPOTS_BY_COVERAGE[towerType] do
				if not self.owned[spot] then
					table.insert(candidates, { spot = spot, newSpot = true })
					break
				end
			end
			if weakest then
				table.insert(candidates, { spot = weakest, newSpot = false })
			end
			local best = 0
			for _, candidate in candidates do
				local option = self:packageOption(focus, candidate.spot, towerType, candidate.newSpot)
				if option.ratio > 0 then
					-- Coût du paquet jugé (pose + améliorations jusqu'au niveau retenu) = gain / rapport
					local packageCost = option.gain / option.ratio
					best = math.max(best, option.gain - bestRatio * packageCost)
				end
			end
			values[towerType] = best
		end
	end
	return values
end

-- Options d'achat à l'autel : un lot par nombre proposé et débloqué au record (IdleConfig.TOWER_SPIN_BULKS).
-- Gain d'un lot de n lancers = doublons attendus sur les tours posées (+2 % de dégâts chacun) + meilleure
-- tour débloquée attendue (valeur de computeUnlockValues x chance d'en tomber au moins une).
function Run:spinOptions(focus, options, bestRatio: number)
	local chances = self:spinChances()
	local anyLocked = false
	for _, towerType in IdleTowers.ORDER do
		if not self.unlocked[towerType] then
			anyLocked = true
		end
	end
	if anyLocked and not self.unlockValues then
		self.unlockValues = self:computeUnlockValues(focus, bestRatio)
	end
	-- Tours verrouillées, de la plus utile à la moins utile
	local locked = {}
	if anyLocked then
		for towerType, value in self.unlockValues do
			if value > 0 and chances[towerType] > 0 then
				table.insert(locked, { type = towerType, value = value })
			end
		end
		table.sort(locked, function(a, b)
			return a.value > b.value
		end)
	end
	local bonus = IdleConfig.DUPLICATE_DAMAGE_BONUS
	for _, bulk in IdleConfig.TOWER_SPIN_BULKS do
		local n = bulk.count
		-- Prix « MAX » (trop grand pour être compté) : achat impossible, comme dans le jeu.
		local cost = IdleConfig.towerSpinCost(self.highestWave, n, self.spins)
		if IdleConfig.towerSpinBulkAvailable(self.highestWave, n) and cost < math.huge then
			-- Débloquer : espérance de la meilleure tour obtenue (on ne pose que la meilleure d'abord)
			local unlockGain, noneYet = 0, 1
			for _, entry in locked do
				local got = 1 - (1 - chances[entry.type]) ^ n
				unlockGain += entry.value * got * noneYet
				noneYet *= 1 - got
			end
			-- Doublons : dégâts des tours posées x (1 + (d + k) x 2 %) / (1 + d x 2 %), k = n x chance
			local factor = {}
			for towerType in self.unlocked do
				local d = self.dupes[towerType] or 0
				factor[towerType] = (1 + (d + n * chances[towerType]) * bonus) / (1 + d * bonus)
			end
			local dupeGain = 0
			for _, f in focus do
				for g, group in f.comp.groups do
					local delta = 0
					for spot, tower in self.towers do
						local power = self.powers[spot]
						local row = f.hits[spot]
						if row[g] > 0 or (row.fire and row.fire[g] > 0) then
							local old = valueOf(row, g, group, power.damage, power.speed, self.fragility)
							local new = valueOf(row, g, group, power.damage * factor[tower.type], power.speed, self.fragility)
							delta += new - old
						end
					end
					if delta > 0 then
						dupeGain += f.weight * f.lambda[g] * logGain(f.U[g], f.eps[g], delta)
					end
				end
			end
			local gain = unlockGain + dupeGain
			if gain > 0 then
				table.insert(options, { kind = "spin", count = n, cost = cost, ratio = gain / cost, gain = gain })
			end
		end
	end
end

-- Forge runique, lancer en pièces (PlotGame:spinBonusWithCoins)
function Run:spinForge()
	if #self.bonuses >= IdleConfig.MAX_BONUS_INVENTORY then
		return
	end
	local drawable = self:forgeDrawable()
	if #drawable == 0 then
		return
	end
	local cost = IdleConfig.forgeCoinPrice(self.forgeSpins)
	if cost >= math.huge or self.coins < cost then
		return
	end
	self.coins -= cost
	self.forgeSpins += 1
	self.forgeSpent += cost
	self:addSpent("forge", cost)
	-- Seulement les runes tirables, chances remises sur 100 % (tirage pondéré, comme rollWeighted du jeu)
	local bonus = self.rng:weighted(drawable, function(entry)
		return entry.chance
	end)
	table.insert(self.bonuses, bonus.id)
	table.insert(self.bonusLog, { t = self.t, id = bonus.id, cost = cost })
	self:log(`forge runique pour {Modules.NumberFormat.short(cost)} : {bonus.displayName}`)
end

-- Pose les runes de l'inventaire là où elles rapportent le plus. Comme en jeu (PlotGame:applyBonus), une rune
-- va dans l'emplacement de SA sorte (dégâts ou vitesse) : elle ne remplace que la rune de la même sorte (qui
-- est perdue), l'autre rune de la tour reste et se cumule.
function Run:applyBonuses()
	if #self.bonuses == 0 or next(self.towers) == nil then
		return
	end
	local focus = self:buildFocus(true)
	local index = 1
	while index <= #self.bonuses do
		self:evaluate(focus)
		local bonusId = self.bonuses[index]
		local rune = IdleConfig.BONUS_BY_ID[bonusId]
		local bestSpot, bestGain = nil, 0
		for spot, tower in self.towers do
			if tower.runes[rune.kind] ~= bonusId then
				local candidate = table.clone(tower.runes)
				candidate[rune.kind] = bonusId
				local damage, speed = self:power(tower.type, tower.level, candidate)
				local gain = gainReplacingSpot(focus, spot, function(_, f)
					return f.hits[spot]
				end, damage, speed, self.fragility)
				if gain > bestGain then
					bestSpot, bestGain = spot, gain
				end
			end
		end
		if not bestSpot then
			-- Aucun gain estimé, mais la rune améliore l'emplacement de sa sorte sur une tour : un vrai joueur la
			-- pose quand même (ex. x2 vitesse sur le Sorcier des arcanes : son rayon chauffe 2 fois plus vite, ce
			-- que l'estimation ne voit pas). Sinon elle dormirait dans l'inventaire et la forge continuerait de la
			-- tirer (elle compte comme utile tant qu'une tour ne l'a pas). Sur la tour de plus haut niveau.
			local bestLevel = -1
			for spot, tower in self.towers do
				if
					IdleConfig.runeValue(tower.runes[rune.kind]) < rune.mult
					and (tower.level > bestLevel or (tower.level == bestLevel and spot < bestSpot))
				then
					bestSpot, bestLevel = spot, tower.level
				end
			end
		end
		if bestSpot then
			table.remove(self.bonuses, index)
			local tower = self.towers[bestSpot]
			local old = tower.runes[rune.kind]
			self:log(
				`bonus {rune.displayName} posé sur {Run.shortName(tower.type)} (empl. {bestSpot})`
					.. (if old then ` à la place de {IdleConfig.BONUS_BY_ID[old].displayName}` else "")
			)
			tower.runes[rune.kind] = bonusId
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
	-- cycle = temps pour revenir à la meilleure vague de la run ; cycle80 = pour revenir à 80 % de celle-ci
	self.pendingCycle = {
		t = self.t,
		target = self.bestWave,
		target80 = math.ceil(0.8 * self.bestWave),
		entry = self.rebirthLog[#self.rebirthLog],
	}
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
	local bonuses = 0 -- runes posées (0 à 2 par tour : dégâts, vitesse)
	for _, tower in self.towers do
		for _ in tower.runes do
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
		if self.pendingCycle and not self.pendingCycle.entry.cycle80 and self.bestWave >= self.pendingCycle.target80 then
			self.pendingCycle.entry.cycle80 = self.t - self.pendingCycle.t
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
				table.insert(list, Engine.compileTower(spot, tower.type, tower.level, self.dupes[tower.type] or 0, tower.runes))
			end
		end
		return Engine.runWave(comp, list, "ignore").leakScore
	end
	local current = score(self.towers)
	if current <= 0 then
		return
	end
	local best, bestScore = nil, current * P.SOLVER_MIN_GAIN
	local copies = IdleTowers.countCopies(self.towers) -- limite de tours identiques (IdleTowers.MAX_COPIES)
	for _, towerType in SLOW_TOWERS do
		if self.unlocked[towerType] and not self:banned(towerType) then
			local placeCost = IdleTowers.Defs[towerType].placeCost
			for spot = 1, SPOT_COUNT do
				local existing = self.towers[spot]
				local refund = if existing then math.floor(existing.spent * IdleConfig.SELL_REFUND) else 0
				if
					self.owned[spot]
					and not (existing and IdleTowers.Defs[existing.type].slow)
					and self.coins + refund >= placeCost
					and IdleTowers.canPlaceCopy(copies, towerType, existing and existing.type)
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

----------------------------------------------------------------------
-- Joueur « tout sur l'Archer » (scénarios avec `archer`, voir Run.SCENARIOS)
----------------------------------------------------------------------

-- Lancer de forge en pièces qui donne la rune `runeId` (forcée), posée tout de suite sur l'Archer, dans
-- l'emplacement de sa sorte (dégâts ou vitesse : les deux se cumulent, comme dans le jeu). Même prix et même
-- compteur que le jeu (IdleConfig.forgeCoinPrice : 100 K, puis x5...).
function Run:archerForge(runeId: string, cost: number)
	local archer = self.towers[Run.ARCHER_SPOTS.archer]
	local rune = IdleConfig.BONUS_BY_ID[runeId]
	self.coins -= cost
	self.forgeSpins += 1
	self.forgeSpent += cost
	self:addSpent("forge", cost)
	self:purchased("forge")
	archer.runes[rune.kind] = runeId
	table.insert(self.bonusLog, { t = self.t, id = runeId, cost = cost, wave = self.frontier })
	self:changed(false)
	self:log(`forge runique pour {Modules.NumberFormat.short(cost)} : {rune.displayName} (forcée), posée sur l'Archer`)
end

-- Achats de l'entracte, dans cet ordre (il s'arrête dès qu'il lui manque des pièces : il économise) :
--   1. l'Archer sur son emplacement (Run.ARCHER_SPOTS) ;
--   2. des lancers x1 à l'autel jusqu'à débloquer le Totem de givre (il faut l'avoir pour le poser ; seuls ces
--      quelques lancers sont achetés, leurs doublons comptent), puis plus jamais l'autel ;
--   3. le Totem de givre juste à côté (il achète cet emplacement : le 5e, 100 pièces) ;
--   4. la forge : comme le scénario « forge », il met de côté le prix du prochain lancer dès qu'il vaut moins de
--      FORGE_SAVE_SECONDS (30 min) de revenu, puis lance ; les lancers donnent les runes du plan (forcées) ;
--   5. tout le reste dans l'Archer : une amélioration dès qu'il peut la payer. Avec upgradeFrost, il choisit
--      entre l'Archer et le Totem au meilleur rapport gain / prix (mêmes calculs que le joueur « base »).
function Run:archerSpend()
	local plan = self.scenario.archer
	local spots = Run.ARCHER_SPOTS
	-- 1. L'Archer
	if not self.towers[spots.archer] then
		if self.coins < IdleTowers.Defs.MachineGun.placeCost then
			return
		end
		self:execute({ kind = "place", spot = spots.archer, type = "MachineGun" })
	end
	-- 2. L'autel, seulement pour débloquer le Totem de givre
	while not self.unlocked.Frost do
		local cost = IdleConfig.towerSpinCost(self.highestWave, 1, self.spins)
		if cost >= math.huge or self.coins < cost then
			return
		end
		self:buySpins(1)
		self:purchased("spin")
	end
	-- 3. Le Totem, juste à côté de l'Archer
	if not self.towers[spots.frost] then
		local owned = self.owned[spots.frost] == true
		local cost = IdleTowers.Defs.Frost.placeCost + (if owned then 0 else PlotLayout.spotCost(self.unlockedSpots + 1))
		if self.coins < cost then
			return
		end
		self:execute({ kind = if owned then "place" else "spot", spot = spots.frost, type = "Frost" })
	end
	-- 4. La forge : les lancers du plan, prix mis de côté quand il vaut moins de 30 min de revenu
	local reserve = 0
	while self.forgeSpins < #plan.runes do
		local cost = IdleConfig.forgeCoinPrice(self.forgeSpins)
		if cost >= math.huge or cost > self.income * P.FORGE_SAVE_SECONDS then
			break -- trop cher pour l'instant : il n'économise pas encore
		end
		if self.coins < cost then
			reserve = cost -- il met ce prix de côté (pas d'amélioration avec ces pièces)
			break
		end
		self:archerForge(plan.runes[self.forgeSpins + 1], cost)
	end
	-- 5. Tout le reste dans l'Archer
	local archer = self.towers[spots.archer]
	if not plan.upgradeFrost then
		while true do
			local cost = IdleTowers.upgradeCost(archer.type, archer.level)
			if cost >= math.huge or self.coins - reserve < cost then
				return
			end
			self:execute({ kind = "upgrade", spot = spots.archer })
		end
	end
	-- upgradeFrost : Archer ou Totem, au meilleur rapport gain / prix (même règle que Run:spend : il économise
	-- pour le meilleur achat s'il peut le payer en moins de SAVE_SECONDS, sinon il prend l'autre s'il vaut au moins
	-- FALLBACK_MIN_RATIO fois le meilleur).
	local focus = self:buildFocus(false)
	for _ = 1, 400 do
		local available = self.coins - reserve
		if available <= 0 then
			return
		end
		self:evaluate(focus)
		local options = {}
		self:upgradeOptions(focus, options)
		local best, bestAffordable = nil, nil
		for _, option in options do
			if option.cost < math.huge then
				if not best or option.ratio > best.ratio then
					best = option
				end
				if option.cost <= available and (not bestAffordable or option.ratio > bestAffordable.ratio) then
					bestAffordable = option
				end
			end
		end
		if not best then
			return
		end
		local choice = best
		if best.cost > available then
			local wait = if self.income > 0 then (best.cost - available) / self.income else math.huge
			if wait <= P.SAVE_SECONDS or not bestAffordable or bestAffordable.ratio < P.FALLBACK_MIN_RATIO * best.ratio then
				return
			end
			choice = bestAffordable
		end
		self:execute(choice)
	end
end

-- Entracte du joueur « tout sur l'Archer » : renaissance (scénarios « …-renaissance », même règle que le
-- scénario « renaissance » : bloqué 15 min à son record, vague >= 15), puis ses achats (Run:archerSpend).
function Run:archerIntermission(): boolean
	-- Revenu quand il joue à son record (pas en train de remonter après une renaissance) : sert au rapport
	-- (Run:archerDiagnosis) pour dire combien de temps de farm il faudrait.
	if self.bestWave >= self.frontier then
		self.archerRecordIncome = self.income
	end
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
	self:archerSpend()
	return rebirthed
end

-- Niveaux de l'Archer et du Totem en ce moment (0 = pas posé), pour le rapport.
function Run:archerLevels(): (number, number)
	local archer = self.towers[Run.ARCHER_SPOTS.archer]
	local frost = self.towers[Run.ARCHER_SPOTS.frost]
	return if archer then archer.level else 0, if frost then frost.level else 0
end

-- Pourquoi il bloque (scénarios « archer » ; main.luau l'appelle à quelques heures et à la fin de la partie).
-- La vague qui bloque (record + 1) est construite comme chacun des 5 types de vague (même numéro, donc mêmes PV
-- au total, comme le banc d'essai) : de combien il faudrait multiplier les dégâts de l'Archer (k) pour la
-- réussir avec ses tours actuelles (vraies règles : une seule fuite = ratée ; à 3 % près), et ce que ça fait en
-- niveaux d'Archer, en pièces et en heures de son revenu à son record. k = math.huge : même avec des dégâts
-- infinis un ennemi passe (plus une question de dégâts, mais de tirs et de temps) ; k <= 1 : il la réussit déjà.
-- Plus : ce qui fuit à la vague qui bloque (un essai avec ses tours, joué jusqu'au bout), après combien de
-- secondes le premier ennemi passe, et les PV de l'ennemi le plus résistant et de toute la vague en flèches.
local WAVE_TYPES_ORDER = { "Mixed", "Horde", "Rush", "Giants", "Boss" }
function Run:archerDiagnosis()
	local archer = self.towers[Run.ARCHER_SPOTS.archer]
	if not archer then
		return nil
	end
	local function towersWith(mult: number)
		local list = {}
		for spot = 1, SPOT_COUNT do
			local tower = self.towers[spot]
			if tower then
				local compiled = Engine.compileTower(spot, tower.type, tower.level, self.dupes[tower.type] or 0, tower.runes)
				if tower.type == "MachineGun" then
					compiled.damage *= mult
				end
				table.insert(list, compiled)
			end
		end
		return list
	end
	local function passes(comp, mult: number): boolean
		return Engine.runWave(comp, towersWith(mult), "strict").success
	end
	-- Plus petit multiplicateur (à 3 % près) qui fait réussir la vague (comme requiredMultiplier dans main.luau)
	local function needed(comp): number
		local lo, hi
		if passes(comp, 1) then
			lo, hi = 0.5, 1
			while passes(comp, lo) do
				hi = lo
				lo /= 2
				if lo < 1e-9 then
					return lo
				end
			end
		else
			lo, hi = 1, 2
			while not passes(comp, hi) do
				lo = hi
				hi *= 2
				if hi > 1e30 then
					return math.huge
				end
			end
		end
		while hi / lo > 1.03 do
			local mid = math.sqrt(lo * hi)
			if passes(comp, mid) then
				hi = mid
			else
				lo = mid
			end
		end
		return hi
	end
	local blocked = self.frontier + 1
	-- Revenu à son record (après une renaissance, il remonte : son revenu du moment est plus petit)
	local climbing = self.bestWave < self.frontier
	local income = if climbing then (self.archerRecordIncome or self.income) else self.income
	local waves = {}
	for _, waveType in WAVE_TYPES_ORDER do
		local k = needed(Engine.composition(blocked, waveType))
		local levels = if k == math.huge then math.huge elseif k <= 1 then 0 else math.ceil(math.log(k) / math.log(IdleConfig.UPGRADE_DAMAGE) - 1e-9)
		local cost = if levels == math.huge then math.huge else 0
		for i = 0, (if levels == math.huge then 0 else levels) - 1 do
			cost += IdleTowers.upgradeCost(archer.type, archer.level + i)
		end
		table.insert(waves, {
			type = waveType,
			actual = waveType == IdleConfig.waveType(blocked), -- le vrai type de la vague qui bloque
			k = k,
			levels = levels,
			cost = cost,
			hours = if cost == 0 then 0 elseif income > 0 then cost / income / 3600 else math.huge,
		})
	end
	-- Ce qui fuit à la vague qui bloque
	local comp = Engine.composition(blocked)
	local result = Engine.runWave(comp, towersWith(1))
	local stats = IdleTowers.effectiveStats(archer.type, archer.level, self.dupes[archer.type] or 0, archer.runes)
	local leaks, toughest = {}, 0
	for g, group in comp.groups do
		table.insert(leaks, { name = group.name, count = group.count, leaked = result.leak[g], hp = group.hp })
		toughest = math.max(toughest, group.hp)
	end
	local _, frostLevel = self:archerLevels()
	return {
		hour = self.t / 3600,
		blocked = blocked,
		blockedType = IdleConfig.waveType(blocked),
		climbing = climbing, -- en train de remonter après une renaissance
		currentWave = self.wave,
		rebirths = self.rebirths,
		coinBonus = self.coinBonus,
		success = result.success,
		leakSeconds = result.seconds,
		leaks = leaks,
		toughestArrows = toughest / stats.damage,
		waveArrows = comp.totalHp / stats.damage, -- flèches pour toute la vague (sans fragilité ni feu)
		waves = waves,
		archerLevel = archer.level,
		damage = stats.damage,
		attacksPerSecond = 1 / stats.cooldown,
		dps = IdleTowers.dpsOf(stats),
		fireDps = IdleTowers.fireDps(stats),
		dupes = self.dupes[archer.type] or 0,
		runes = IdleConfig.runeList(archer.runes),
		frostLevel = frostLevel,
		fragility = if frostLevel > 0 then IdleTowers.fragilityAt(IdleTowers.Defs.Frost, frostLevel) else 0,
		income = income,
	}
end

-- Entracte : machines, bonus, renaissance, achats. Renvoie true si le joueur est reparti de la vague 1.
function Run:intermission(): boolean
	-- Joueur « tout sur l'Archer » : ses propres règles (Run:archerIntermission)
	if self.scenario.archer then
		return self:archerIntermission()
	end
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
					if result.success then "" else ` ({leaked} ennemi(s) auraient atteint la base)`
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

-- Défis classés : 3 défis par jour et 2 par semaine, faits en match CLASSÉ, récompensés dans le mode SOLO
-- (pièces, lancers de l'Autel des héros, lancers de la Forge runique). Les mêmes défis pour tout le monde :
-- ils sont tirés dans les listes plus bas avec le numéro du jour (ou de la semaine) comme graine.
--
-- Règle du propriétaire : « Le ranked doit rester équitable. Mêmes tours et même or pour tout le monde. »
-- Les défis ne changent RIEN dans un match classé : le serveur de match ne fait que compter, à la fin.
--
-- Qui fait quoi :
--   * serveur de match (Match/init.luau) : à la fin d'un match classé, Challenges.recordMatch pour les deux
--     joueurs, puis sauvegarde (comme le MMR) ;
--   * map principale (Hub/ChallengeRewards.luau) : publie l'état au client et donne les récompenses
--     (bouton « Récupérer » : Challenges.findClaimable, puis la récompense de Challenges.rewardFor) ;
--   * interface (client/ChallengeUI.luau) : affiche les défis avec les textes et récompenses d'ici.
--
-- Sauvegarde (data.challenges, petite et toujours propre, voir cleanData) :
--   day, week = numéros du jour et de la semaine des défis enregistrés ;
--   daily, weekly = { { id = défi, p = progression, c = récompense récupérée } } ;
--   opp = matchs comptés aujourd'hui contre chaque adversaire ([userId en texte] = nombre) ;
--   last = identifiant du dernier match compté (un même match n'est jamais compté deux fois).
-- Toutes les fonctions reçoivent l'heure `now` (os.time() du serveur, en UTC) : rien ne dépend de l'ordinateur
-- du joueur, et les tests Studio peuvent avancer l'horloge.
local IdleConfig = require(script.Parent.IdleConfig)
local NumberFormat = require(script.Parent.NumberFormat)

local Challenges = {}

----------------------------------------------------------------------
-- Remises à zéro (heures UTC, comme le plafond des gains hors ligne)
----------------------------------------------------------------------
-- Nouveau jour à 00:00 UTC (2 h du matin en France l'été, 1 h l'hiver) : nouveaux défis du jour.
Challenges.DAY_SECONDS = 24 * 60 * 60
-- Nouvelle semaine le lundi à 00:00 UTC. os.time() compte depuis le jeudi 1er janvier 1970 : on ajoute 3 jours
-- pour que chaque semaine commence un lundi (jeudi + 3 jours = dimanche, le lundi suivant ouvre la semaine 1).
Challenges.WEEK_DAYS = 7
Challenges.WEEK_START_SHIFT_DAYS = 3
-- Écart toléré (secondes) entre les horloges de deux serveurs Roblox : juste après minuit, un serveur un peu
-- en retard ne fait jamais revenir les défis à la veille (voir currentPeriod).
Challenges.CLOCK_TOLERANCE = 120

----------------------------------------------------------------------
-- Anti-abus : quels matchs comptent
----------------------------------------------------------------------
-- Un match compte seulement s'il a duré au moins 3 minutes (depuis le début de la partie, après le compte à
-- rebours). Un joueur qui ne pose aucune tour perd vers 2 min 57 : il faut vraiment jouer.
Challenges.MIN_MATCH_SECONDS = 3 * 60
-- Contre le même adversaire, au plus 2 matchs comptés par jour (pour chaque joueur).
Challenges.MAX_MATCHES_PER_OPPONENT = 2
-- Adversaires retenus par jour au plus (la sauvegarde reste petite). Au-delà (60 adversaires différents dans
-- la journée), un nouvel adversaire compte encore mais n'est plus retenu.
Challenges.MAX_OPPONENTS_KEPT = 60
-- Les matchs contre un bot (tests Studio) ne comptent jamais : seuls les vrais matchs classés comptent.

----------------------------------------------------------------------
-- Récompenses (mode solo uniquement)
----------------------------------------------------------------------
-- Pièces = vagues de gains à ton RECORD (idle.highestWave) avec la formule des vagues du mode solo
-- (IdleConfig.rewardBudget) et ton bonus de pièces des renaissances, compté une seule fois. Un joueur actif
-- gagne ~1 vague de gains toutes les 100 s (IdleConfig.ABSENCE_WAVE_SECONDS) :
--   défi du jour : 8 vagues ≈ 13 min de farm à ton record ;
--   défi de la semaine : 25 vagues ≈ 40 min de farm, + 1 lancer de la Forge runique.
-- Le pass Pièces x2 ne les double pas (ce ne sont pas des pièces gagnées sur ta parcelle).
Challenges.DAILY_COIN_WAVES = 8
Challenges.WEEKLY_COIN_WAVES = 25
-- Minimum pour les nouveaux joueurs (au record 1, une vague ne vaut que 12 pièces).
Challenges.DAILY_MIN_COINS = 250
Challenges.WEEKLY_MIN_COINS = 1000
-- Lancers offerts : l'Autel des héros tire comme un lancer payé (chances de ton record) mais ne fait PAS monter
-- ses prix (compteur idle.towerSpinsBought inchangé) ; la Forge runique marche comme un lancer Robux.
Challenges.ALTAR_SPINS = 10
Challenges.FORGE_SPINS = 1
-- Plus grand nombre de pièces donné d'un coup : toujours fini (un DataStore ne sait pas sauver l'infini).
Challenges.MAX_COINS = 1e300

Challenges.DAILY_COUNT = 3
Challenges.WEEKLY_COUNT = 2

----------------------------------------------------------------------
-- Les défis
----------------------------------------------------------------------
-- kind = ce qui est compté à chaque match classé qui compte :
--   play     : +1 par match (gagné ou perdu)
--   win      : +1 par victoire (une égalité n'est pas une victoire)
--   hold     : +1 par match qui dure au moins `seconds` (gagné ou perdu : ta base tient jusque-là)
--   minutes  : + la durée du match, en secondes (target en secondes, affiché en minutes)
--   towers   : + les tours posées pendant le match (même revendues ensuite)
--   upgrades : + les améliorations faites pendant le match
--   variety  : +1 par victoire avec au moins `types` types de tours différents posés
-- Les défis tirés le même jour ont toujours des `kind` différents. Tout se fait en jouant normalement
-- (~20 à 40 min de ranked par jour) : aucun défi ne demande de perdre ou de mal jouer.
Challenges.DAILY = {
	{ id = "play2", kind = "play", target = 2, text = "Joue 2 matchs classés" },
	{ id = "win1", kind = "win", target = 1, text = "Gagne 1 match classé", altarSpins = Challenges.ALTAR_SPINS },
	{ id = "hold6", kind = "hold", seconds = 6 * 60, target = 1, text = "Tiens 6 minutes dans un match classé" },
	{ id = "towers15", kind = "towers", target = 15, text = "Pose 15 tours en match classé" },
	{ id = "upgrades10", kind = "upgrades", target = 10, text = "Améliore tes tours 10 fois en match classé" },
	{
		id = "variety3",
		kind = "variety",
		types = 3,
		target = 1,
		text = "Gagne un match avec 3 types de tours différents",
		altarSpins = Challenges.ALTAR_SPINS,
	},
	{ id = "minutes15", kind = "minutes", target = 15 * 60, text = "Tiens 15 minutes au total en match classé" },
}
Challenges.WEEKLY = {
	{ id = "play10", kind = "play", target = 10, text = "Joue 10 matchs classés" },
	{ id = "win5", kind = "win", target = 5, text = "Gagne 5 matchs classés" },
	{ id = "minutes45", kind = "minutes", target = 45 * 60, text = "Tiens 45 minutes au total en match classé" },
	{ id = "towers60", kind = "towers", target = 60, text = "Pose 60 tours en match classé" },
	{ id = "upgrades40", kind = "upgrades", target = 40, text = "Améliore tes tours 40 fois en match classé" },
	{ id = "variety3x3", kind = "variety", types = 3, target = 3, text = "Gagne 3 matchs avec 3 types de tours différents" },
}
Challenges.DAILY_BY_ID = {}
Challenges.WEEKLY_BY_ID = {}
Challenges.BY_ID = {} -- les deux listes (ids tous différents)
for _, def in Challenges.DAILY do
	def.period = "day"
	Challenges.DAILY_BY_ID[def.id] = def
	Challenges.BY_ID[def.id] = def
end
for _, def in Challenges.WEEKLY do
	def.period = "week"
	def.forgeSpins = def.forgeSpins or Challenges.FORGE_SPINS
	Challenges.WEEKLY_BY_ID[def.id] = def
	Challenges.BY_ID[def.id] = def
end

----------------------------------------------------------------------
-- Jours et semaines
----------------------------------------------------------------------

-- Numéro du jour UTC de cette heure (0 = 1er janvier 1970).
function Challenges.dayNumber(time: number): number
	return math.floor(time / Challenges.DAY_SECONDS)
end

-- Numéro de la semaine (du lundi 00:00 UTC au lundi suivant) de cette heure.
function Challenges.weekNumber(time: number): number
	return math.floor((Challenges.dayNumber(time) + Challenges.WEEK_START_SHIFT_DAYS) / Challenges.WEEK_DAYS)
end

-- Heure (os.time()) de la fin de ce jour, et de cette semaine (lundi 00:00 UTC suivant).
function Challenges.dayEndsAt(day: number): number
	return (day + 1) * Challenges.DAY_SECONDS
end
function Challenges.weekEndsAt(week: number): number
	return ((week + 1) * Challenges.WEEK_DAYS - Challenges.WEEK_START_SHIFT_DAYS) * Challenges.DAY_SECONDS
end

----------------------------------------------------------------------
-- Tirage des défis (le même sur tous les serveurs)
----------------------------------------------------------------------

-- Petit générateur de nombres « au hasard » maison (xorshift 32 bits) : même graine = même suite, sur
-- n'importe quel serveur et à n'importe quelle date.
local function xorshift(x: number): number
	x = bit32.bxor(x, bit32.lshift(x, 13))
	x = bit32.bxor(x, bit32.rshift(x, 17))
	x = bit32.bxor(x, bit32.lshift(x, 5))
	return x
end

-- Mélange la liste avec la graine, puis garde les `count` premiers défis de `kind` différents.
local function pick(pool, count: number, seed: number): { string }
	-- Graine mélangée (multiplication de Knuth, exacte pour les numéros de jour : bien sous 2^53).
	local x = (seed * 2654435761 + 12345) % 4294967296
	if x == 0 then
		x = 1
	end
	for _ = 1, 8 do
		x = xorshift(x)
	end
	local order = {}
	for index = 1, #pool do
		order[index] = index
	end
	for index = #order, 2, -1 do
		x = xorshift(x)
		local other = x % index + 1
		order[index], order[other] = order[other], order[index]
	end
	local picked, kinds, taken = {}, {}, {}
	for _, index in order do
		local def = pool[index]
		if #picked < count and not kinds[def.kind] then
			kinds[def.kind] = true
			taken[index] = true
			table.insert(picked, def.id)
		end
	end
	-- (Pas assez de sortes différentes dans la liste : on complète quand même.)
	for _, index in order do
		if #picked < count and not taken[index] then
			table.insert(picked, pool[index].id)
		end
	end
	return picked
end

-- Tirages déjà faits (quelques-uns seulement : vidé au-delà de 50).
local pickCache = {}
local pickCacheSize = 0
local function cachedPick(pool, count: number, seed: number, cacheKey: string): { string }
	local key = `{cacheKey}:{seed}`
	local picked = pickCache[key]
	if not picked then
		if pickCacheSize >= 50 then
			table.clear(pickCache)
			pickCacheSize = 0
		end
		picked = pick(pool, count, seed)
		pickCache[key] = picked
		pickCacheSize += 1
	end
	return picked
end

-- Les 3 défis de ce jour (ids), les mêmes pour tout le monde.
function Challenges.dailyPicks(day: number): { string }
	return table.clone(cachedPick(Challenges.DAILY, Challenges.DAILY_COUNT, day, "day"))
end

-- Les 2 défis de cette semaine (ids). Graine différente de celle des jours.
function Challenges.weeklyPicks(week: number): { string }
	return table.clone(cachedPick(Challenges.WEEKLY, Challenges.WEEKLY_COUNT, week * 7919 + 17, "week"))
end

----------------------------------------------------------------------
-- Sauvegarde : valeurs par défaut et nettoyage
----------------------------------------------------------------------

-- Nombre entier fini entre 0 et max ; une valeur abîmée (NaN, infini, pas un nombre) compte comme 0.
local function cleanInteger(value: any, max: number): number
	if typeof(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return 0
	end
	return math.clamp(math.floor(value), 0, max)
end

-- Clé d'un adversaire dans `opp` (userId en texte), nil pour une valeur abîmée. (Dans Studio, les joueurs de
-- test ont des userId négatifs : -1, -2... Un match contre le bot n'est de toute façon jamais classé.)
local function opponentKey(userId: any): string?
	if typeof(userId) ~= "number" or userId ~= userId or userId == 0 or math.abs(userId) >= 2 ^ 53 or userId ~= math.floor(userId) then
		return nil
	end
	return string.format("%d", userId)
end

-- Données des défis d'un nouveau joueur (les défis du jour sont tirés au premier passage de sync).
function Challenges.defaultData()
	return { day = 0, week = 0, daily = {}, weekly = {}, opp = {}, last = "" }
end

local function cleanSlots(raw: any, byId, count: number)
	local list = {}
	if typeof(raw) ~= "table" then
		return list
	end
	for index = 1, count do
		local slot = raw[index]
		local def = typeof(slot) == "table" and typeof(slot.id) == "string" and byId[slot.id]
		if not def then
			break
		end
		table.insert(list, { id = def.id, p = cleanInteger(slot.p, def.target), c = slot.c == true })
	end
	return list
end

-- Copie propre des données des défis (anciennes sauvegardes, valeurs abîmées) : que des nombres entiers
-- finis, des textes courts et des booléens. Les défis inconnus sont retirés (sync les remplace).
function Challenges.cleanData(raw: any)
	local clean = Challenges.defaultData()
	if typeof(raw) ~= "table" then
		return clean
	end
	clean.day = cleanInteger(raw.day, 1e9)
	clean.week = cleanInteger(raw.week, 1e9)
	clean.daily = cleanSlots(raw.daily, Challenges.DAILY_BY_ID, Challenges.DAILY_COUNT)
	clean.weekly = cleanSlots(raw.weekly, Challenges.WEEKLY_BY_ID, Challenges.WEEKLY_COUNT)
	if typeof(raw.opp) == "table" then
		local kept = 0
		for key, value in raw.opp do
			local id = opponentKey(tonumber(key))
			local count = cleanInteger(value, Challenges.MAX_MATCHES_PER_OPPONENT)
			if id and count > 0 and kept < Challenges.MAX_OPPONENTS_KEPT then
				clean.opp[id] = count
				kept += 1
			end
		end
	end
	if typeof(raw.last) == "string" and #raw.last <= 100 then
		clean.last = raw.last
	end
	return clean
end

----------------------------------------------------------------------
-- Changement de jour / de semaine
----------------------------------------------------------------------

-- Période (jour ou semaine) en cours. Jamais de retour en arrière : si les défis enregistrés sont d'une
-- période à peine plus tard (horloge d'un autre serveur un peu en avance, CLOCK_TOLERANCE), on les garde.
local function currentPeriod(stored: number, numberOf: (number) -> number, now: number): number
	local current = numberOf(now)
	if stored > current and stored <= numberOf(now + Challenges.CLOCK_TOLERANCE) then
		return stored
	end
	return current
end

-- Défis de la période : ceux enregistrés s'ils sont complets, sinon ceux du tirage (en gardant la
-- progression d'un défi déjà là).
local function ensureSlots(slots, picks: { string }, count: number)
	local seen, valid = {}, #slots == count
	for _, slot in slots do
		if seen[slot.id] then
			valid = false
		end
		seen[slot.id] = true
	end
	if valid then
		return slots
	end
	local list = {}
	for _, id in picks do
		local kept = nil
		for _, slot in slots do
			if slot.id == id then
				kept = slot
				break
			end
		end
		table.insert(list, kept or { id = id, p = 0, c = false })
	end
	return list
end

-- Met les défis du joueur à l'heure `now` et les renvoie (data.challenges, nettoyé). Nouveau jour : nouveaux
-- défis du jour, progression, récompenses récupérées et adversaires du jour remis à zéro. Nouvelle semaine :
-- pareil pour les défis de la semaine. Une récompense pas récupérée à temps est perdue.
function Challenges.sync(data, now: number)
	local state = Challenges.cleanData(data.challenges)
	data.challenges = state
	local day = currentPeriod(state.day, Challenges.dayNumber, now)
	local week = currentPeriod(state.week, Challenges.weekNumber, now)
	if state.day ~= day then
		state.day = day
		state.daily = {}
		state.opp = {}
	end
	if state.week ~= week then
		state.week = week
		state.weekly = {}
	end
	state.daily = ensureSlots(state.daily, Challenges.dailyPicks(day), Challenges.DAILY_COUNT)
	state.weekly = ensureSlots(state.weekly, Challenges.weeklyPicks(week), Challenges.WEEKLY_COUNT)
	return state
end

----------------------------------------------------------------------
-- Fin d'un match classé (serveur de match ; tests Studio : StudioDebug « ChallengeMatch »)
----------------------------------------------------------------------

local function durationText(seconds: number): string
	local minutes, rest = seconds // 60, seconds % 60
	if rest == 0 then
		return `{minutes} min`
	end
	return `{minutes} min {rest} s`
end

-- Raisons affichées quand un match ne compte pas (fin du match : ligne du résultat et message).
Challenges.REASON_UNRANKED = "match non classé (contre un bot), il ne compte pas"
Challenges.REASON_SHORT = `match de moins de {durationText(Challenges.MIN_MATCH_SECONDS)}, il ne compte pas`
Challenges.REASON_OPPONENT = `déjà {Challenges.MAX_MATCHES_PER_OPPONENT} matchs comptés contre ce joueur aujourd'hui, celui-ci ne compte pas`
Challenges.REASON_ALREADY = "ce match est déjà compté"

-- Ligne des règles (fenêtre des défis).
function Challenges.rulesText(): string
	return `Seuls les matchs classés d'au moins {durationText(Challenges.MIN_MATCH_SECONDS)} comptent ; le même adversaire compte {Challenges.MAX_MATCHES_PER_OPPONENT} fois par jour au plus`
end

-- Ce qu'un match fait avancer pour ce défi (voir kind plus haut).
local function gainFor(def, stats): number
	local kind = def.kind
	if kind == "play" then
		return 1
	elseif kind == "win" then
		return if stats.won then 1 else 0
	elseif kind == "hold" then
		return if stats.seconds >= def.seconds then 1 else 0
	elseif kind == "minutes" then
		return stats.seconds
	elseif kind == "towers" then
		return stats.towersPlaced
	elseif kind == "upgrades" then
		return stats.upgrades
	elseif kind == "variety" then
		return if stats.won and stats.towerTypes >= def.types then 1 else 0
	end
	return 0
end

-- Compte un match terminé pour UN joueur, dans ses données (sans rien attendre : appelé aussi pendant le
-- départ d'un joueur, juste avant sa dernière sauvegarde). stats (tout est revérifié ici) :
--   ranked (vrai seulement pour un vrai match classé), matchId, seconds (durée de la partie), won,
--   opponentId (userId de l'adversaire), towersPlaced, upgrades, towerTypes (types de tours différents posés).
-- Renvoie { counted, reason (si pas compté), completed = { ids des défis terminés par ce match }, text = la
-- ligne affichée à la fin du match }.
function Challenges.recordMatch(data, stats, now: number)
	local state = Challenges.sync(data, now)
	local raw = if typeof(stats) == "table" then stats else {}
	local s = {
		ranked = raw.ranked == true,
		matchId = if typeof(raw.matchId) == "string" then string.sub(raw.matchId, 1, 100) else "",
		seconds = cleanInteger(raw.seconds, 24 * 60 * 60),
		won = raw.won == true,
		towersPlaced = cleanInteger(raw.towersPlaced, 1000),
		upgrades = cleanInteger(raw.upgrades, 1000),
		towerTypes = cleanInteger(raw.towerTypes, 100),
	}
	local function refused(reason: string)
		return { counted = false, reason = reason, completed = {}, text = `Défis : {reason}` }
	end

	local key = opponentKey(raw.opponentId)
	if not s.ranked or not key then
		return refused(Challenges.REASON_UNRANKED)
	elseif s.matchId ~= "" and s.matchId == state.last then
		return refused(Challenges.REASON_ALREADY)
	elseif s.seconds < Challenges.MIN_MATCH_SECONDS then
		return refused(Challenges.REASON_SHORT)
	end
	local already = state.opp[key] or 0
	if already >= Challenges.MAX_MATCHES_PER_OPPONENT then
		return refused(Challenges.REASON_OPPONENT)
	end

	-- Le match compte.
	local known = 0
	for _ in state.opp do
		known += 1
	end
	if state.opp[key] ~= nil or known < Challenges.MAX_OPPONENTS_KEPT then
		state.opp[key] = already + 1
	end
	state.last = s.matchId
	local completed = {}
	for _, list in { state.daily, state.weekly } do
		for _, slot in list do
			local def = Challenges.BY_ID[slot.id]
			if def and not slot.c and slot.p < def.target then
				slot.p = math.min(def.target, slot.p + gainFor(def, s))
				if slot.p >= def.target then
					table.insert(completed, def.id)
				end
			end
		end
	end
	local text = "Défis : +1 match joué"
	if #completed == 1 then
		text ..= " • 1 défi terminé !"
	elseif #completed > 1 then
		text ..= ` • {#completed} défis terminés !`
	end
	return { counted = true, completed = completed, text = text }
end

----------------------------------------------------------------------
-- Récompenses
----------------------------------------------------------------------

-- Pièces de `waves` vagues de gains à ce record, bonus de pièces compris une fois, au moins `minimum`.
-- Toujours un nombre entier et fini.
function Challenges.coinReward(waves: number, highestWave: any, coinBonus: any, minimum: number): number
	local record = 1
	if typeof(highestWave) == "number" and highestWave == highestWave then
		record = math.clamp(math.floor(highestWave), 1, IdleConfig.MAX_SCALING_WAVE)
	end
	local bonus = 0
	if typeof(coinBonus) == "number" and coinBonus == coinBonus and coinBonus > 0 then
		bonus = math.min(coinBonus, 1e9)
	end
	local coins = math.floor(waves * IdleConfig.rewardBudget(record) * (1 + bonus / 100))
	if coins ~= coins then
		coins = 0
	end
	return math.min(math.max(coins, minimum), Challenges.MAX_COINS)
end

-- Récompense d'un défi pour ce joueur (record = idle.highestWave, bonus = idle.coinBonus) :
-- { coins, altarSpins, forgeSpins }.
function Challenges.rewardFor(def, highestWave: any, coinBonus: any)
	local weekly = def.period == "week"
	local waves = def.waves or (if weekly then Challenges.WEEKLY_COIN_WAVES else Challenges.DAILY_COIN_WAVES)
	local minimum = if weekly then Challenges.WEEKLY_MIN_COINS else Challenges.DAILY_MIN_COINS
	return {
		coins = Challenges.coinReward(waves, highestWave, coinBonus, minimum),
		altarSpins = def.altarSpins or 0,
		forgeSpins = def.forgeSpins or 0,
	}
end

-- « 💰 1.2M  +10 lancers d'autel » (fenêtre des défis).
function Challenges.rewardText(reward): string
	local parts = { "💰 " .. NumberFormat.short(reward.coins) }
	if reward.altarSpins > 0 then
		table.insert(parts, `+{reward.altarSpins} lancer{if reward.altarSpins > 1 then "s" else ""} d'autel`)
	end
	if reward.forgeSpins > 0 then
		table.insert(parts, `+{reward.forgeSpins} lancer{if reward.forgeSpins > 1 then "s" else ""} de forge`)
	end
	return table.concat(parts, "  ")
end

-- « +1.2M pièces • +10 lancers d'autel » (message après « Récupérer »).
function Challenges.rewardToast(reward): string
	local parts = { `+{NumberFormat.short(reward.coins)} pièces` }
	if reward.altarSpins > 0 then
		table.insert(parts, `+{reward.altarSpins} lancer{if reward.altarSpins > 1 then "s" else ""} d'autel`)
	end
	if reward.forgeSpins > 0 then
		table.insert(parts, `+{reward.forgeSpins} lancer{if reward.forgeSpins > 1 then "s" else ""} de forge`)
	end
	return table.concat(parts, " • ")
end

-- Progression affichée : « 1/2 », ou « 12/45 min » pour les minutes.
function Challenges.progressText(def, progress: number): string
	if def.kind == "minutes" then
		return `{progress // 60}/{def.target // 60} min`
	end
	return `{progress}/{def.target}`
end

-- Nombre de récompenses prêtes à récupérer (pastille du bouton « DÉFIS »).
function Challenges.readyCount(state): number
	local count = 0
	for _, list in { state.daily, state.weekly } do
		for _, slot in list do
			local def = Challenges.BY_ID[slot.id]
			if def and not slot.c and slot.p >= def.target then
				count += 1
			end
		end
	end
	return count
end

-- Bouton « Récupérer » : key = "d1" à "d3" (défis du jour) ou "w1", "w2" (de la semaine), period = numéro du
-- jour (ou de la semaine) que le client affichait. Vérifie : même jour / même semaine, défi terminé, pas encore
-- récupéré. Renvoie (défi enregistré, sa définition) ou (nil, nil, message d'erreur). Ne donne rien :
-- l'appelant marque slot.c = true puis donne Challenges.rewardFor (Hub/ChallengeRewards.luau).
function Challenges.findClaimable(data, key: any, period: any, now: number)
	local state = Challenges.sync(data, now)
	local letter, number = nil, nil
	if typeof(key) == "string" then
		letter, number = string.match(key, "^([dw])(%d)$")
	end
	local list = if letter == "d" then state.daily elseif letter == "w" then state.weekly else nil
	local slot = list and list[tonumber(number) or 0]
	local def = slot and Challenges.BY_ID[slot.id]
	if not slot or not def then
		return nil, nil, "Défi inconnu"
	end
	local current = if letter == "d" then state.day else state.week
	if typeof(period) ~= "number" or period ~= current then
		return nil, nil, "Ces défis sont terminés : voici les nouveaux défis"
	end
	if slot.c then
		return nil, nil, "Récompense déjà récupérée"
	end
	if slot.p < def.target then
		return nil, nil, `Défi pas encore terminé ({Challenges.progressText(def, slot.p)})`
	end
	return slot, def, nil
end

-- État envoyé au client (attribut ChallengeState du joueur, en JSON) : numéros du jour et de la semaine,
-- heures de fin (heure réelle du serveur, comme workspace:GetServerTimeNow() ; clockOffset = décalage de
-- l'horloge des tests Studio, 0 sinon) et les défis { key, id, p, c }. Textes et récompenses : ce module.
function Challenges.clientState(state, clockOffset: number?)
	local offset = clockOffset or 0
	local function slots(list, prefix: string)
		local out = {}
		for index, slot in list do
			table.insert(out, { key = prefix .. index, id = slot.id, p = slot.p, c = slot.c })
		end
		return out
	end
	return {
		day = state.day,
		week = state.week,
		dayEndsAt = Challenges.dayEndsAt(state.day) - offset,
		weekEndsAt = Challenges.weekEndsAt(state.week) - offset,
		daily = slots(state.daily, "d"),
		weekly = slots(state.weekly, "w"),
	}
end

return Challenges

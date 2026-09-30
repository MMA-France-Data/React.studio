-- Chances affichées par la Forge runique : elles doivent faire EXACTEMENT 100 % (règle de Roblox pour les objets
-- aléatoires payants : le lancer Robux de la forge donne une rune au hasard). Voir IdleConfig.roundedOdds et
-- IdleConfig.forgeOdds. Sans Studio, depuis le dossier roblox-ranked-td :
--   luau.exe tools/odds/tests.luau
-- 1) Pour CHAQUE groupe possible de runes tirables (toutes les sous-listes non vides de IdleConfig.BONUSES : 255 pour
--    8 runes), les chances arrondies font 10000 centièmes de % tout juste (100,00 %), chacune est à 0,01 % au plus
--    de la vraie (chance / total), elle s'écrit avec 2 chiffres après la virgule au plus, et elle est exactement celle
--    du même calcul refait en nombres entiers (aucune erreur de virgule : à égalité de reste, l'ordre d'affichage).
-- 2) Quelques cas faits à la main (égalités : l'ordre d'affichage gagne), et les chances de base (sans arrondi).
-- Sortie 1 si un test rate.
local IdleConfig = require("../../src/shared/IdleConfig")

local passed, failed = 0, 0
local function check(ok: boolean, message: string)
	if ok then
		passed += 1
	else
		failed += 1
		print("RATÉ : " .. message)
	end
end

-- Centièmes de % d'une chance arrondie (35.04 -> 3504) : un nombre entier, sinon nil.
local function hundredths(value: number): number?
	local units = math.floor(value * 100 + 0.5)
	if math.abs(value * 100 - units) > 1e-6 then
		return nil -- plus de 2 chiffres après la virgule
	end
	return units
end

-- Le plus grand reste refait en nombres ENTIERS (chances x1000 : 35 -> 35000, 0.1 -> 100 ; aucune virgule, donc aucune
-- erreur d'arrondi) : centièmes de % de chaque rune, dans l'ordre de la liste. À égalité de reste, la première dans
-- l'ordre d'affichage. nil si une chance a plus de 3 chiffres après la virgule (pas prévu ici).
local function exactUnits(drawable): { number }?
	local weights, total = {}, 0
	for index, bonus in drawable do
		local weight = math.floor(bonus.chance * 1000 + 0.5)
		if math.abs(bonus.chance * 1000 - weight) > 1e-6 then
			return nil
		end
		weights[index] = weight
		total += weight
	end
	local units, rests, order, given = {}, {}, {}, 0
	for index, weight in weights do
		units[index] = (weight * 10000) // total
		rests[index] = weight * 10000 - units[index] * total -- (un nombre entier : comparaisons exactes)
		given += units[index]
		table.insert(order, index)
	end
	table.sort(order, function(a, b)
		if rests[a] ~= rests[b] then
			return rests[a] > rests[b]
		end
		return a < b
	end)
	for rank = 1, 10000 - given do
		units[order[rank]] += 1
	end
	return units
end

-- 1) Toutes les sous-listes non vides de BONUSES (dans l'ordre d'affichage, comme la forge).
local bonuses = IdleConfig.BONUSES
local count = #bonuses
local subsets, worstGap = 0, 0
for mask = 1, 2 ^ count - 1 do
	local drawable = {}
	for index = 1, count do
		if bit32.btest(mask, 2 ^ (index - 1)) then
			table.insert(drawable, bonuses[index])
		end
	end
	subsets += 1
	local total = 0
	for _, bonus in drawable do
		total += bonus.chance
	end
	local odds = IdleConfig.forgeOdds(drawable)
	local expected = exactUnits(drawable)
	local sum, problems = 0, {}
	if expected == nil then
		table.insert(problems, "une chance a plus de 3 chiffres après la virgule : calcul en nombres entiers impossible")
	end
	for index, bonus in drawable do
		local shown = odds[bonus.id]
		local exact = bonus.chance / total * 100
		local units = if typeof(shown) == "number" then hundredths(shown) else nil
		if units == nil then
			table.insert(problems, `{bonus.id} = {tostring(shown)} (pas au 0,01 % près)`)
		else
			sum += units
			local gap = math.abs(shown - exact)
			worstGap = math.max(worstGap, gap)
			if gap > 0.01 + 1e-9 then
				table.insert(problems, `{bonus.id} : {shown} % affiché pour {exact} % (écart {gap})`)
			end
			if expected and units ~= expected[index] then
				table.insert(problems, `{bonus.id} : {shown} % au lieu de {expected[index] / 100} % (calcul en nombres entiers)`)
			end
		end
	end
	local extra = 0
	for id in odds do
		if not table.find(drawable, IdleConfig.BONUS_BY_ID[id]) then
			extra += 1
		end
	end
	if extra > 0 then
		table.insert(problems, `{extra} rune(s) en trop`)
	end
	if sum ~= 10000 then
		table.insert(problems, `somme = {sum} centièmes de % (attendu 10000)`)
	end
	local ids = {}
	for _, bonus in drawable do
		table.insert(ids, bonus.id)
	end
	check(#problems == 0, `runes {table.concat(ids, ",")} : {table.concat(problems, " ; ")}`)
end
print(`{subsets} groupes de runes vérifiés (attendu {2 ^ count - 1}) ; plus grand écart avec la vraie chance : {string.format("%.4f", worstGap)} %`)
check(subsets == 2 ^ count - 1, "toutes les sous-listes de runes ont été vérifiées")

-- 2) Cas faits à la main.
local function same(odds, expected): boolean
	for id, value in expected do
		if math.abs((odds[id] or -1) - value) > 1e-9 then
			return false
		end
	end
	for id in odds do
		if expected[id] == nil then
			return false
		end
	end
	return true
end
local function show(odds, ids)
	local parts = {}
	for _, id in ids do
		table.insert(parts, `{id}={tostring(odds[id])}`)
	end
	return table.concat(parts, " ")
end

-- Chances de base : elles font déjà 100 % : rien ne bouge.
local base = IdleConfig.forgeOdds(bonuses)
local baseOk = true
for _, bonus in bonuses do
	baseOk = baseOk and math.abs(base[bonus.id] - bonus.chance) < 1e-9
end
check(baseOk, "chances de base de la forge inchangées (35, 30, 18, 10, 5, 1.5, 0.4, 0.1)")

-- 35 / 18 / 10 sur 63 : 55.555… / 28.571… / 15.873… -> 55.56 / 28.57 / 15.87 (le plus grand reste prend le centième).
local three = IdleConfig.roundedOdds({ "a", "b", "c" }, { a = 35, b = 18, c = 10 })
check(same(three, { a = 55.56, b = 28.57, c = 15.87 }), `35/18/10 -> 55.56/28.57/15.87 ({show(three, { "a", "b", "c" })})`)

-- Trois chances égales : 33.33 x 3 = 99.99 -> le centième qui manque va à la PREMIÈRE dans l'ordre d'affichage.
local thirds = IdleConfig.roundedOdds({ "x", "y", "z" }, { x = 1, y = 1, z = 1 })
check(same(thirds, { x = 33.34, y = 33.33, z = 33.33 }), `3 chances égales -> 33.34/33.33/33.33 ({show(thirds, { "x", "y", "z" })})`)
local thirdsOther = IdleConfig.roundedOdds({ "z", "y", "x" }, { x = 1, y = 1, z = 1 })
check(same(thirdsOther, { z = 33.34, y = 33.33, x = 33.33 }), `ordre inverse : le centième va à « z », affichée en premier ({show(thirdsOther, { "z", "y", "x" })})`)

-- Chances DIFFÉRENTES avec le même reste (vrai groupe de la forge : x3, x5, x20, x50 et x100 dégâts, total 30) : 10,
-- 0.4 et 0.1 sur 30 font 33.333… / 1.333… / 0.333… %, un tiers de centième de reste chacune, mais les calculs à
-- virgule ne tombent pas pile pareil. Le centième qui manque va à la première affichée (x5 : 33.34), jamais à x50.
local sameRestIds = { "Damage3", "Damage5", "Damage20", "Damage50", "Damage100" }
local sameRest = IdleConfig.roundedOdds(sameRestIds, { Damage3 = 18, Damage5 = 10, Damage20 = 1.5, Damage50 = 0.4, Damage100 = 0.1 })
check(
	same(sameRest, { Damage3 = 60, Damage5 = 33.34, Damage20 = 5, Damage50 = 1.33, Damage100 = 0.33 }),
	`même reste, chances différentes -> le centième va à la première affichée : 60/33.34/5/1.33/0.33 ({show(sameRest, sameRestIds)})`
)

-- Sept chances égales : 14.2857… -> 14.28 x 7 = 99.96 : les 4 premières prennent un centième (14.29 x 4, 14.28 x 3).
local sevenIds = { "a", "b", "c", "d", "e", "f", "g" }
local sevenWeights = {}
for _, id in sevenIds do
	sevenWeights[id] = 1
end
local seven = IdleConfig.roundedOdds(sevenIds, sevenWeights)
check(
	same(seven, { a = 14.29, b = 14.29, c = 14.29, d = 14.29, e = 14.28, f = 14.28, g = 14.28 }),
	`7 chances égales -> 14.29 x 4 puis 14.28 x 3 ({show(seven, sevenIds)})`
)

-- Une seule rune tirable : 100 % (ex. x2 vitesse, quand toutes les tours ont x100 dégâts).
local single = IdleConfig.forgeOdds({ IdleConfig.BONUS_BY_ID.Speed2 })
check(same(single, { Speed2 = 100 }), `une seule rune -> 100 % ({show(single, { "Speed2" })})`)

-- Liste vide, ou aucune chance positive : rien, ou 0 partout.
check(next(IdleConfig.forgeOdds({})) == nil, "aucune rune tirable -> aucune chance")
local zero = IdleConfig.roundedOdds({ "a", "b" }, { a = 0, b = 0 })
check(same(zero, { a = 0, b = 0 }), `aucune chance positive -> 0 partout ({show(zero, { "a", "b" })})`)

print(`{passed} tests réussis, {failed} ratés`)
if failed > 0 then
	error(`{failed} test(s) raté(s)`, 0)
end

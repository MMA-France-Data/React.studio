--!optimize 2
-- La meilleure BARRE de chaque niveau (run.ps1 -Barre). Dans un niveau, le joueur ne pose qu'UNE tour par rareté
-- (« LA BARRE DE TOURS », Levels.luau) : pour régler un niveau, il faut d'abord savoir quelle barre le joueur attendu
-- y emmène. Pour chaque niveau demandé :
--   1. toutes les barres qu'il peut former avec ses tours (OWNED : une commune, une rare, une épique dès qu'il en a
--      une, une spéciale ; pas de légendaire : trop rare pour être attendue) ;
--   2. chacune jouée par le joueur simulé au rythme demandé, à des PV d'essai difficiles (ceux du niveau x 1,7) : les
--      2 meilleures sont gardées ;
--   3. pour ces 2 barres, les PV les plus hauts où il gagne encore avec `vies` vies (la recherche de tune.luau) ;
--   4. la plus forte des deux est affichée, avec son entraînement : c'est la ligne à mettre dans Bot.EXPECTED. Puis
--      run.ps1 -Tune donne les PV au plus juste (par pas de 2 %).
-- L'ENTRAÎNEMENT de chaque tour : celui que ses parties lui ont donné (NATURAL, les tours spéciales : 8 XP par niveau
-- gagné depuis leur boss), PLUS UN NIVEAU à partir du niveau 11, DEUX à partir du niveau 31 (extraOf : « dur
-- partout », choix du propriétaire le 05/10/2026 : il faut avoir entraîné ses tours, au camp ou en rejouant des
-- niveaux).
-- QUI EST LE JOUEUR ATTENDU (OWNED) ? Celui qui n'a PAS eu de chance aux œufs dorés : une tour RARE de palier 2 à
-- partir du niveau 16, jamais de tour épique de palier 2 ni de légendaire. Mesuré le 05/10/2026 (gen/barvar.luau, un
-- fichier de travail) : avec la barre, la chance compte énormément. La Baliste du dragon (1 joueur sur 2 l'a au
-- niveau 31) permet de battre des monstres 45 % plus résistants ; sans elle, le niveau 31 réglé pour elle restait
-- impossible même avec des tours entraînées au maximum. Les niveaux sont donc réglés pour la barre que presque tout
-- le monde peut former (97 % des joueurs ont une tour rare ou épique de palier 2 au niveau 31) : personne n'est
-- bloqué sans solution ; celui qui a une tour épique de palier 2 ou une légendaire trouve la suite plus facile (aux
-- niveaux 21 à 30 : la Baliste du dragon +17 %, une légendaire de palier 2 +35 % ; au 4e territoire, c'est encore
-- plus : d'où les DEUX crans d'entraînement demandés là).
--   luau bar.luau -a "niveaux=12" "vies=5"
local Levels = require("./gen/shared/Levels")
local Bot = require("./Bot")
local Settings = require("./settings")

Settings.apply(Levels, ...)

local onlyLevels = {}
for number in string.gmatch(Settings.argument("niveaux", ...) or "", "%d+") do
	table.insert(onlyLevels, tonumber(number))
end
assert(#onlyLevels > 0, 'Usage : bar.luau -a "niveaux=12,13" ["vies=5"]')
local targetLives = tonumber(Settings.argument("vies", ...)) or 5

-- Niveaux d'entraînement en plus de NATURAL : 1 à partir du niveau 11, 2 à partir du niveau 31.
local extraOf = Bot.extraTraining
local PROBE = 1.7 -- PV d'essai du classement des barres : ceux du niveau x PROBE

-- Les tours du joueur attendu, par place de la barre : { à partir de quel niveau, tour }. Une tour de palier 2
-- remplace sa tour de base (replaces) : plus personne ne garde la Catapulte quand il a la Catapulte de magma.
-- (Voir le texte de Bot.EXPECTED, et « QUI EST LE JOUEUR ATTENDU » plus haut.)
local OWNED = {
	{ { 1, "MachineGun" }, { 11, "Frost" } },
	{ { 2, "Bomb" }, { 11, "Tesla" }, { 16, "MagmaCatapult", replaces = "Bomb" }, { 21, "StormArchmage", replaces = "Tesla" } },
	{ { 26, "Rocket" } },
	{ { 11, "CrimsonBow" }, { 21, "CopperCrossbow" }, { 31, "ThornSpitter" }, { 41, "FrostCatapult" } },
}
-- Niveau du boss qui donne chaque tour spéciale (son entraînement : 8 XP par niveau gagné depuis).
local SPECIAL_BOSS = { CrimsonBow = 10, CopperCrossbow = 20, ThornSpitter = 30, FrostCatapult = 40 }
-- Entraînement que ses parties ont donné à chaque tour : { à partir de quel niveau, entraînement }.
local NATURAL = {
	MachineGun = { { 1, 0 }, { 4, 1 }, { 8, 2 }, { 21, 3 }, { 41, 4 } },
	Bomb = { { 1, 0 }, { 4, 1 }, { 8, 2 }, { 21, 3 }, { 41, 4 } },
	Frost = { { 11, 0 }, { 14, 1 }, { 21, 2 }, { 31, 3 }, { 47, 4 } },
	Tesla = { { 11, 0 }, { 14, 1 }, { 21, 2 }, { 31, 3 }, { 47, 4 } },
	MagmaCatapult = { { 16, 0 }, { 19, 1 }, { 24, 2 }, { 34, 3 }, { 49, 4 } },
	StormArchmage = { { 21, 0 }, { 24, 1 }, { 29, 2 }, { 37, 3 } },
	Rocket = { { 26, 0 }, { 29, 1 }, { 34, 2 }, { 45, 3 } },
}

local function trainingOf(level: number, towerType: string): number
	local base = 0
	local boss = SPECIAL_BOSS[towerType]
	if boss then
		base = Levels.trainingLevel(math.max(0, level - boss - 1) * Levels.TRAINING.XP_PER_WIN)
	else
		for _, step in NATURAL[towerType] do
			if level >= step[1] then
				base = step[2]
			end
		end
	end
	return math.min(Levels.TRAINING.MAX_LEVEL, base + extraOf(level))
end

-- Toutes les barres possibles à ce niveau : une tour par place (une place sans tour est sautée).
local function barsOf(level: number): { { string } }
	local bars = { {} }
	for _, slot in OWNED do
		local choices, replaced = {}, {}
		for _, entry in slot do
			if level >= entry[1] then
				table.insert(choices, entry[2])
				if entry.replaces then
					replaced[entry.replaces] = true
				end
			end
		end
		local kept = {}
		for _, towerType in choices do
			if not replaced[towerType] then
				table.insert(kept, towerType)
			end
		end
		if #kept > 0 then
			local nextBars = {}
			for _, bar in bars do
				for _, towerType in kept do
					local copy = table.clone(bar)
					table.insert(copy, towerType)
					table.insert(nextBars, copy)
				end
			end
			bars = nextBars
		end
	end
	return bars
end

print(`Le joueur de référence doit garder {targetLives} vies au moins.`)
print(string.format("%-6s %6s %6s  %-58s %s", "Niveau", "PV", "avant", "meilleure barre (entraînement)", "les 2 barres essayées jusqu'au bout"))
for _, level in onlyLevels do
	local source = Levels.DEFINITIONS[level]
	local original = source.health
	local pace = Bot.EXPECTED[level].pace
	local function profileOf(bar: { string })
		local trainings = {}
		for _, towerType in bar do
			trainings[towerType] = trainingOf(level, towerType)
		end
		return { towers = bar, training = 0, trainings = trainings, interval = pace, actions = 1 }
	end
	local function enough(result): boolean
		return result.won and result.lives >= targetLives
	end
	local function winsAt(bar: { string }, health: number): boolean
		source.health = health
		return enough(Bot.play(level, profileOf(bar), enough))
	end

	-- Classement des barres aux PV d'essai : gagné (vies), sinon part des monstres éliminés.
	local ranked = {}
	for _, bar in barsOf(level) do
		source.health = math.floor(original * PROBE)
		local result = Bot.play(level, profileOf(bar), enough)
		table.insert(ranked, { bar = bar, score = if result.won then 1000 + result.lives else result.kills / result.total * 100 })
	end
	table.sort(ranked, function(a, b)
		return a.score > b.score
	end)

	-- Les PV les plus hauts d'une barre : grille grossière (x1,3), puis fine (x1,06), comme tune.luau.
	local function maxHealth(bar: { string }): number
		local coarse, lastWin, misses = {}, nil, 0
		local value = 20
		while value <= 4000 do
			table.insert(coarse, value)
			value *= 1.3
		end
		for index, candidate in coarse do
			if winsAt(bar, math.floor(candidate)) then
				lastWin, misses = index, 0
			else
				misses += 1
				if lastWin and misses >= 2 then
					break
				end
			end
		end
		local health = 5
		if lastWin then
			health = math.floor(coarse[lastWin] / 1.3)
			local previous = false
			value = coarse[lastWin] / 1.3
			while value <= coarse[lastWin] * 1.3 do
				local wins = winsAt(bar, math.floor(value))
				if wins and previous then
					health = math.floor(value)
				end
				previous = wins
				value *= 1.06
			end
		end
		return health
	end

	local best, bestHealth = ranked[1].bar, 0
	local tried = {}
	for index = 1, math.min(2, #ranked) do
		local health = maxHealth(ranked[index].bar)
		table.insert(tried, `{table.concat(ranked[index].bar, "+")} : {health}`)
		if health > bestHealth then
			best, bestHealth = ranked[index].bar, health
		end
	end
	source.health = original
	local parts = {}
	for _, towerType in best do
		table.insert(parts, `{towerType} {trainingOf(level, towerType)}`)
	end
	print(string.format("%-6d %6d %6d  %-58s %s (%d barres possibles)", level, bestHealth, original, table.concat(parts, ", "), table.concat(tried, " | "), #ranked))
end

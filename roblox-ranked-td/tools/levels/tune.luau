--!optimize 2
-- Réglage des PV de chaque niveau (run.ps1 -Tune) : pour chaque niveau, cherche les PV du fantassin les plus hauts
-- avec lesquels le joueur simulé de RÉFÉRENCE gagne encore avec au moins `vies` vies. Puis montre, avec ces PV, ce
-- que deviennent les autres joueurs : très actif, lent, distrait, sans boutique, tout débloqué, et ceux qui posent
-- quelques tours puis attendent.
-- C'est la réponse à la demande du propriétaire (02/10/2026) : « beaucoup trop facile », « obligé d'être super
-- actif », « si juste 2 Archers gèrent le niveau, je passe mon temps à attendre ».
-- Le joueur de référence a les tours attendues à ce niveau et fait un achat toutes les `pace` secondes
-- (Bot.EXPECTED : 6 s au niveau 1, 3 s au niveau 10). Le niveau est aussi dur que possible pour lui : un joueur qui
-- agit moins souvent perd, un joueur très actif garde presque toutes ses vies.
--   luau tune.luau -a "regler=Levels.DEFINITIONS.3.gap.2=0.3"   (essai de réglages avant la recherche)
--   luau tune.luau -a "regler=Levels.DEFINITIONS.*.ramp.1=0.5" "niveaux=1,3,6"   (* = tous les niveaux ; quelques niveaux seulement)
--   luau tune.luau -a "rythme=3" "vies=8"   (autre rythme de référence pour tous les niveaux ; autre nombre de vies)
local Levels = require("./gen/shared/Levels")
local Bot = require("./Bot")
local Settings = require("./settings")

Settings.apply(Levels, ...)

-- "niveaux=1,3,6" : seulement ces niveaux (réglage plus rapide).
local onlyLevels = nil
local list = Settings.argument("niveaux", ...)
if list then
	onlyLevels = {}
	for number in string.gmatch(list, "%d+") do
		onlyLevels[tonumber(number)] = true
	end
end
local fixedPace = tonumber(Settings.argument("rythme", ...))
local targetLives = tonumber(Settings.argument("vies", ...)) or 5

local function cell(result): string
	if result.won then
		return `G {result.lives}`
	end
	return `P {math.floor(result.kills / result.total * 100 + 0.5)} %`
end

-- Joueur qui pose ces tours dans l'ordre dès qu'il a l'or, sans rien améliorer, puis attend.
local function lazy(level: number, towers: { string }): string
	return cell(Bot.playLazy(level, towers))
end

print(`Le joueur de référence doit garder {targetLives} vies au moins.`)
print(string.format("%-6s %5s %5s %5s %5s | %-7s | %-11s | %-9s | %-9s | %-10s | %-9s | %-9s | %-9s | %-9s | %s", "Niveau", "PV", "monst", "durée", "or", "Actif", "Référence", "Moyen 3s", "Lent 8s", "Distr. 15s", "Sans bout", "Tout e.6", "2 Archers", "4A + 2C", "achats du joueur actif"))
local found = {}
for level = 1, Levels.COUNT do
	if onlyLevels and not onlyLevels[level] then
		continue
	end
	local source = Levels.DEFINITIONS[level]
	local pace = fixedPace or Bot.EXPECTED[level].pace
	local function winsAt(health: number): boolean
		source.health = health
		local result = Bot.play(level, Bot.profile(level, pace))
		return result.won and result.lives >= targetLives
	end
	-- Le joueur simulé n'est pas parfaitement régulier (un peu plus de PV peut, par hasard, mieux lui réussir) : une
	-- grille grossière (x1,3) encadre d'abord, puis une grille fine (x1,06) garde les PV les plus hauts où il gagne
	-- aussi au pas d'avant.
	local coarse, lastWin, misses = {}, nil, 0
	local value = 20
	while value <= 2500 do
		table.insert(coarse, value)
		value *= 1.3
	end
	for index, candidate in coarse do
		if winsAt(math.floor(candidate)) then
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
			local wins = winsAt(math.floor(value))
			if wins and previous then
				health = math.floor(value)
			end
			previous = wins
			value *= 1.06
		end
	end
	source.health = health
	found[level] = health
	local queue = Levels.buildQueue(level)
	local gold = Levels.definition(level).gold
	for _, item in queue do
		gold += item.reward
	end
	local active = Bot.play(level, Bot.profile(level))
	local reference = Bot.play(level, Bot.profile(level, pace))
	local medium = Bot.play(level, Bot.profile(level, 3))
	local slow = Bot.play(level, Bot.profile(level, 8))
	local distracted = Bot.play(level, Bot.profile(level, 15))
	local noShop = Bot.play(level, { towers = Levels.STARTING_TOWERS, training = 0 })
	local everything = Bot.play(level, { towers = Bot.ALL_TOWERS, training = 6 })
	-- Achats du joueur actif : chaque tour posée et chaque amélioration compte pour un.
	local purchases = active.levels - (if level == 1 then 1 else 0)
	print(string.format(
		"%-6d %5d %5d %4.0fs %5d | %-7s | %-11s | %-9s | %-9s | %-10s | %-9s | %-9s | %-9s | %-9s | %d tours, %d achats (un toutes les %.1f s)",
		level,
		health,
		#queue,
		Levels.duration(level),
		gold,
		cell(active),
		`{cell(reference)} ({pace} s)`,
		cell(medium),
		cell(slow),
		cell(distracted),
		cell(noShop),
		cell(everything),
		lazy(level, { "MachineGun", "MachineGun" }),
		lazy(level, { "MachineGun", "MachineGun", "Bomb", "MachineGun", "MachineGun", "Bomb" }),
		active.towers,
		purchases,
		source.seconds / math.max(1, purchases)
	))
end
print("")
local healths = {}
for level = 1, Levels.COUNT do
	table.insert(healths, tostring(found[level] or "-"))
end
print("PV trouvés : " .. table.concat(healths, ", "))

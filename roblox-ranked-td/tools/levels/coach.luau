--!optimize 2
-- Le TUTO joué par un joueur simulé (run.ps1 -Coach) : il suit le guide du premier niveau (Levels.coachAdvice : la
-- flèche de client/TutorialUI.luau), plus ou moins vite. Sert à vérifier que suivre la flèche suffit pour gagner le
-- niveau 1, même sans se presser.
--   luau coach.luau -a "regler=Levels.DEFINITIONS.1.health=60" "niveaux=1,2"
local Levels = require("./gen/shared/Levels")
local Bot = require("./Bot")
local Settings = require("./settings")

Settings.apply(Levels, ...)

local levels = {}
for text in string.gmatch(Settings.argument("niveaux", ...) or "1", "%d+") do
	table.insert(levels, tonumber(text))
end

-- Secondes que le joueur met à faire chaque achat montré par la flèche (deux appuis).
local DELAYS = { 1, 2, 3, 4, 5, 6, 7, 8, 10 }

for _, level in levels do
	print(`Niveau {level} : le joueur suit la flèche du guide`)
	print(string.format("%-18s | %-24s | %-7s | %-8s | %s", "Temps par achat", "Résultat", "Achats", "Or gardé", "Tours à la fin"))
	for _, delay in DELAYS do
		local result = Bot.playCoached(level, delay)
		local text = if result.won
			then `GAGNÉ, {result.lives} vies`
			else `perdu à {math.floor(result.kills / result.total * 100 + 0.5)} % ({math.floor(result.seconds)} s)`
		print(string.format("%-18s | %-24s | %-7d | %-8d | %s", `{delay} s`, text, result.purchases, result.unspent, result.build))
	end
	print("")
end
print("Le guide : une 2e tour, une première amélioration, puis toujours l'achat payable le plus rentable.")

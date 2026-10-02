--!optimize 2
-- Les niveaux joués par un joueur qui ne fait (presque) RIEN, avec le vrai moteur (run.ps1 -Lazy) : il pose
-- quelques tours dès qu'il a l'or, sans jamais rien améliorer, puis il attend.
-- Retour du propriétaire (02/10/2026) : « si juste 2 Archers gèrent le niveau, je passe mon temps à attendre ».
-- Tous ces joueurs doivent donc PERDRE, de plus en plus tard quand ils posent plus de tours : un niveau ne se gagne
-- qu'en continuant à poser et à améliorer jusqu'à la fin.
--   luau lazy.luau -a "regler=Levels.DEFINITIONS.1.health=10"   (essai de réglages, comme sim.luau)
local Levels = require("./gen/shared/Levels")
local Bot = require("./Bot")
local Settings = require("./settings")

Settings.apply(Levels, ...)

-- Tours posées en tout (celle offerte au niveau 1 comprise), dans l'ordre, sur les emplacements conseillés.
local PLANS = {
	{ name = "Rien de plus", towers = { "MachineGun" } },
	{ name = "2 Archers", towers = { "MachineGun", "MachineGun" } },
	{ name = "3 Archers", towers = { "MachineGun", "MachineGun", "MachineGun" } },
	{ name = "2 Archers + Catapulte", towers = { "MachineGun", "MachineGun", "Bomb" } },
	{ name = "4 Archers + 2 Catapultes", towers = { "MachineGun", "MachineGun", "Bomb", "MachineGun", "MachineGun", "Bomb" } },
}

local header = string.format("%-7s", "Niveau")
for _, plan in PLANS do
	header ..= string.format(" | %-24s", plan.name)
end
print(header)
for level = 1, Levels.COUNT do
	local line = string.format("%-7d", level)
	for _, plan in PLANS do
		local result = Bot.playLazy(level, plan.towers)
		local text = if result.won
			then `GAGNÉ, {result.lives} vies`
			else `perdu à {math.floor(result.kills / result.total * 100 + 0.5)} % ({math.floor(result.seconds)} s)`
		line ..= string.format(" | %-24s", text)
	end
	print(line)
end
print("")
print("Aucune amélioration, tours posées dès que l'or le permet. Niveau 1 : le premier Archer est offert, déjà posé.")

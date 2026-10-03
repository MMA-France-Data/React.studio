--!optimize 2
-- JOUER EN ÉQUIPE : réglage des PV des monstres selon le nombre de joueurs (Levels.TEAM_HEALTH), run.ps1 -Equipe.
-- Une équipe de `taille` joueurs simulés de RÉFÉRENCE (chacun avec les tours attendues au niveau et un achat toutes
-- les `pace` secondes, comme le joueur seul pour qui le niveau est réglé : Bot.EXPECTED) joue le niveau avec des
-- monstres x m. On cherche le m le plus haut avec lequel l'équipe gagne encore avec au moins `vies` vies : la
-- difficulté « juste » pour cette taille d'équipe. Puis, avec le réglage actuel (TEAM_HEALTH[taille]), on montre
-- l'équipe très active et l'équipe lente (un achat toutes les 8 s chacun : seul, ce joueur perd toujours).
-- Une ligne par niveau : taille, niveau, m trouvé, équipe très active, équipe lente (« G 7 » = gagné avec 7 vies,
-- « P 62 % » = perdu après avoir éliminé 62 % des monstres).
--   luau team.luau -a "taille=2" "niveaux=10,20" "vies=5"
local Levels = require("./gen/shared/Levels")
local Bot = require("./Bot")
local Settings = require("./settings")

Settings.apply(Levels, ...)
local size = tonumber(Settings.argument("taille", ...)) or 2
local targetLives = tonumber(Settings.argument("vies", ...)) or 5
local levels = {}
for number in string.gmatch(Settings.argument("niveaux", ...) or "10", "%d+") do
	table.insert(levels, tonumber(number))
end

local function cell(result): string
	if result.won then
		return `G {result.lives}`
	end
	return `P {math.floor(result.kills / result.total * 100 + 0.5)} %`
end

local current = Levels.TEAM_HEALTH[size]
for _, level in levels do
	local function winsAt(multiplier: number): boolean
		Levels.TEAM_HEALTH[size] = multiplier
		local result = Bot.playTeam(level, Bot.teamProfiles(level, size, "reference"), function(best)
			return best.won and best.lives >= targetLives
		end)
		return result.won and result.lives >= targetLives
	end
	-- Le joueur simulé n'est pas parfaitement régulier : une grille grossière (x1,25) encadre, puis une grille fine
	-- (x1,05) garde le plus haut m où l'équipe gagne aussi au pas d'avant.
	local found = 0
	if winsAt(1) then
		found = 1
		while found < 12 and winsAt(found * 1.25) do
			found *= 1.25
		end
		while winsAt(found * 1.05) do
			found *= 1.05
		end
	end
	Levels.TEAM_HEALTH[size] = current
	local active = Bot.playTeam(level, Bot.teamProfiles(level, size, nil))
	local slow = Bot.playTeam(level, Bot.teamProfiles(level, size, 8))
	print(string.format("%d\t%d\t%.2f\t%s\t%s", size, level, found, cell(active), cell(slow)))
end

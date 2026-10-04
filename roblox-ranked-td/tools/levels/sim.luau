--!optimize 2
-- Tableau de la difficulté des niveaux (run.ps1) : chaque niveau joué par plusieurs joueurs simulés, avec le vrai
-- moteur. « G 7 » = gagné avec 7 vies, « P 62 % » = perdu après avoir éliminé 62 % des monstres.
-- Les colonnes répondent à la demande du propriétaire (02/10/2026 : « beaucoup trop facile », « obligé d'être super
-- actif », « si juste 2 Archers gèrent le niveau, je passe mon temps à attendre ») :
--   Actif         = les tours attendues à ce niveau, un joueur qui dépense son or tout de suite : il doit GAGNER ;
--   Référence     = les mêmes tours, un achat toutes les `pace` secondes (Bot.EXPECTED : le rythme demandé par le
--                   niveau, 5 s au niveau 1, 3 s au niveau 10) : il doit GAGNER, de peu ;
--   Lent          = les mêmes tours, un achat toutes les 8 s : il doit PERDRE (sinon on peut attendre) ;
--   Distrait      = un achat toutes les 15 s : il doit PERDRE tôt ;
--   Sans œuf      = seulement l'Archer et la Catapulte (aucune chance aux œufs), joueur actif : dit à partir de quand
--                   les tours des œufs deviennent nécessaires ;
--   Tout entr.6   = toutes les tours, entraînées à fond, joueur actif : la récompense de celui qui a tout débloqué.
-- (Les joueurs qui posent quelques tours puis attendent : run.ps1 -Lazy.)
--   luau sim.luau -a "regler=Levels.DEFINITIONS.3.health=20;Levels.DEFINITIONS.3.gap.2=0.45"   (essai de réglages)
local Levels = require("./gen/shared/Levels")
local Bot = require("./Bot")
local Settings = require("./settings")

Settings.apply(Levels, ...)

local COLUMNS = {
	{ name = "Actif", make = function(level)
		return Bot.profile(level)
	end },
	{ name = "Référence", make = function(level)
		return Bot.profile(level, "reference")
	end },
	{ name = "Lent (8 s)", make = function(level)
		return Bot.profile(level, 8)
	end },
	{ name = "Distrait (15 s)", make = function(level)
		return Bot.profile(level, 15)
	end },
	{ name = "Sans œuf", make = function()
		return { towers = Bot.NO_EGG_TOWERS, training = 0 }
	end },
	{ name = "Tout entr.6", make = function()
		return { towers = Bot.ALL_TOWERS, training = 6 }
	end },
}

local function cell(result): string
	if result.won then
		return `G {result.lives}`
	elseif not result.ended then
		return "?"
	end
	return `P {math.floor(result.kills / result.total * 100 + 0.5)} %`
end

local header = string.format("%-6s %4s %5s %5s %5s", "Niveau", "PV", "monst", "durée", "or")
for _, column in COLUMNS do
	header ..= string.format(" | %-15s", column.name)
end
print(header)
local builds = {}
for level = 1, Levels.OPEN_COUNT do
	local definition = Levels.definition(level)
	local queue = Levels.buildQueue(level)
	local gold = definition.gold
	for _, item in queue do
		gold += item.reward
	end
	local line = string.format("%-6d %4.0f %5d %4.0fs %5d", level, Levels.enemyHealth(level, "Normal"), #queue, Levels.duration(level), gold)
	for _, column in COLUMNS do
		local result = Bot.play(level, column.make(level))
		line ..= string.format(" | %-15s", cell(result))
		if column.name == "Actif" then
			table.insert(builds, `  niveau {level} : {cell(result)} : {result.build} (or dépensé {result.spent})`)
		end
	end
	print(line)
end
print("")
print("PV = PV d'un fantassin quand la montée vaut 1 ; monst = monstres du niveau ; durée = durée prévue ; or = or de départ + or de tous les monstres.")
print("Tours posées à la fin par le joueur actif (nombre, type, niveaux) :")
for _, line in builds do
	print(line)
end

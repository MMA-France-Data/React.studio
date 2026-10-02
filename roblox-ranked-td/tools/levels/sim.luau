--!optimize 2
-- Tableau de la difficulté des niveaux (run.ps1) : chaque niveau joué par plusieurs joueurs types, avec le vrai
-- moteur. Une ligne par niveau, une colonne par joueur : « G 7 » = gagné avec 7 vies, « P 62 % » = perdu après avoir
-- éliminé 62 % de la vague.
--   luau sim.luau -a "regler=Levels.HEALTH_GROWTH=1.25;Levels.BASE_HEALTH=10"   (essai de réglages)
local Levels = require("./gen/shared/Levels")
local Bot = require("./Bot")

-- Réglages essayés sans toucher à src : "Levels.CHAMP=valeur;Levels.Autre.champ=valeur".
for index = 1, select("#", ...) do
	local argument = select(index, ...)
	local settings = string.match(argument, "^regler=(.*)$")
	if settings then
		for assignment in string.gmatch(settings, "[^;]+") do
			local path, value = string.match(assignment, "^%s*Levels%.([%w_%.]+)%s*=%s*([^%s]+)%s*$")
			assert(path, "Réglage illisible : " .. assignment)
			local target = Levels
			local keys = string.split(path, ".")
			for i = 1, #keys - 1 do
				target = target[tonumber(keys[i]) or keys[i]]
			end
			local key = keys[#keys]
			target[tonumber(key) or key] = tonumber(value)
			print(`Réglage : Levels.{path} = {value}`)
		end
	end
end

local ALL = { "MachineGun", "Frost", "Bomb", "Tesla", "Rocket", "Laser", "Chain", "Orbital" }
local PROFILES = {
	{ name = "Archer seul", towers = { "MachineGun" }, training = 0 },
	{ name = "Archer entr.2", towers = { "MachineGun" }, training = 2 },
	{ name = "+Totem", towers = { "MachineGun", "Frost" }, training = 0 },
	{ name = "+Catapulte", towers = { "MachineGun", "Frost", "Bomb" }, training = 0 },
	{ name = "+Cata entr.2", towers = { "MachineGun", "Frost", "Bomb" }, training = 2 },
	{ name = "+Mage", towers = { "MachineGun", "Frost", "Bomb", "Tesla" }, training = 2 },
	{ name = "+Baliste", towers = { "MachineGun", "Frost", "Bomb", "Tesla", "Rocket" }, training = 3 },
	{ name = "Tout entr.0", towers = ALL, training = 0 },
	{ name = "Tout entr.6", towers = ALL, training = 6 },
}

local function cell(result): string
	if result.won then
		return `G {result.lives}`
	elseif not result.ended then
		return "?"
	end
	return `P {math.floor(result.kills / result.total * 100 + 0.5)} %`
end

local header = string.format("%-7s %5s %5s %4s", "Niveau", "PV", "durée", "or")
for _, profile in PROFILES do
	header ..= string.format(" | %-13s", profile.name)
end
print(header)
local builds = {}
for level = 1, Levels.COUNT do
	local definition = Levels.definition(level)
	local queue = Levels.buildQueue(level)
	local gold = definition.gold
	for _, item in queue do
		gold += item.reward
	end
	local line = string.format("%-7d %5.0f %4.0fs %4d", level, Levels.enemyHealth(level, "Normal"), Levels.duration(level), gold)
	for index, profile in PROFILES do
		local result = Bot.play(level, profile)
		line ..= string.format(" | %-13s", cell(result))
		if level >= 4 then
			table.insert(builds, `  niveau {level}, {profile.name} : {cell(result)} : {result.build} (or dépensé {result.spent})`)
		end
	end
	print(line)
end
print("")
print("PV = PV d'un fantassin ; durée = durée prévue du niveau ; or = or de départ + or de tous les monstres.")
print("Tours posées à la fin (nombre, type, niveaux) :")
for _, line in builds do
	print(line)
end

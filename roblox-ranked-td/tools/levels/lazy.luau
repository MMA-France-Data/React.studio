--!optimize 2
-- Les premiers niveaux joués par un joueur qui ne fait (presque) RIEN, avec le vrai moteur (run.ps1 -Lazy) :
--   « Rien »            : il ne pose et n'améliore rien (au niveau 1 : seulement l'Archer offert) ;
--   « 1 tour de plus »  : il pose un Archer au 2e emplacement conseillé dès qu'il a l'or, puis plus rien ;
--   « 2 tours de plus » : pareil, puis un 3e Archer au 3e emplacement.
-- Sert à régler le tout début : le niveau 1 ne doit pas se perdre sans rien faire, mais agir doit se voir.
--   luau lazy.luau -a "regler=Levels.DEFINITIONS.1.health=10"   (essai de réglages, comme sim.luau)
local Env = require("./env")
local Levels = require("./gen/shared/Levels")
local LevelGame = require("./gen/server/Hub/LevelGame")

for index = 1, select("#", ...) do
	local settings = string.match(select(index, ...), "^regler=(.*)$")
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

local function play(level: number, extraTowers: number)
	local definition = Levels.definition(level)
	local arena = { index = Levels.arenaIndex(1), folder = Env.fakeInstance("Arena"), cframe = Levels.arenaCFrame(1), map = definition.map }
	local game = LevelGame.new(arena, { UserId = 1, Parent = {} }, {
		level = level,
		unlocked = { MachineGun = true },
		training = {},
		startingTower = level == 1,
	})
	local spots = Levels.geometry(definition.map).map.spots
	local placed = 0
	local firstSpot = if level == 1 then 2 else 1
	while game.state == "Running" and game.clock < 900 do
		if placed < extraTowers and game.gold >= Levels.placeCost("MachineGun") then
			if game:placeTower("MachineGun", spots[firstSpot + placed]) then
				placed += 1
			end
		end
		game:simulate(1 / 30)
	end
	return game
end

print(string.format("%-7s | %-22s | %-22s | %-22s", "Niveau", "Rien", "1 tour de plus", "2 tours de plus"))
for level = 1, 4 do
	local line = string.format("%-7d", level)
	for extra = 0, 2 do
		local game = play(level, extra)
		local text = if game.state == "Won"
			then `gagné, {game.lives} vies`
			else `perdu à {math.floor(game.kills / #game.queue * 100 + 0.5)} % ({math.floor(game.clock)} s)`
		line ..= string.format(" | %-22s", text)
	end
	print(line)
end
print("")
print("Niveau 1 : l'Archer offert est déjà posé. Niveaux suivants : « Rien » = aucune tour du tout.")

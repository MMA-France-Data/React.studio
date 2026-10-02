--!optimize 2
-- Outil de réglage : ce qu'une tour de la boutique APPORTE dans un niveau. Pour un niveau et une tour, cherche les
-- PV des monstres les plus hauts que le joueur de référence peut battre avec les tours attendues à ce niveau PLUS
-- cette tour, selon le goût du joueur simulé pour elle (0 = il ne la pose jamais : c'est la base ; 1 = il la juge
-- à ses dégâts estimés ; 3 et 8 = il la préfère). Le gain d'une tour = le meilleur résultat comparé à la base.
--   luau --codegen -O2 worth.luau -a <niveau> <tour> <goût> ["regler=..."]
-- Lancé pour toutes les tours par run.ps1 -Worth (un processus par mesure).
local Levels = require("./gen/shared/Levels")
local Bot = require("./Bot")
local Settings = require("./settings")

Settings.apply(Levels, ...)
local level = tonumber((select(1, ...)))
local towerType = select(2, ...)
local taste = tonumber((select(3, ...)))
assert(level and Levels.TOWER_COST[towerType] and taste, "Usage : worth.luau -a <niveau> <tour> <goût>")

local expected = Bot.EXPECTED[level]
local towers = table.clone(expected.towers)
if not table.find(towers, towerType) then
	table.insert(towers, towerType)
end
Bot.VALUE_SCALE = { [towerType] = taste }
local profile = { towers = towers, training = expected.training, interval = expected.pace, actions = 1 }
local source = Levels.DEFINITIONS[level]

local function winsAt(health: number): boolean
	source.health = health
	local result = Bot.play(level, profile)
	return result.won and result.lives >= 5
end
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
local result = Bot.play(level, profile)
print(string.format("%d\t%s\t%g\t%d\t%s", level, towerType, taste, health, result.build))

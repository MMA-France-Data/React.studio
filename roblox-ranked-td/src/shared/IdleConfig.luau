-- Réglages du mode infini (les vagues sur ta parcelle).
-- Les PV des ennemis et les pièces gagnées sont multipliés à chaque vague :
-- ça commence à quelques pièces et ça finit en trillions.
local IdleConfig = {}

IdleConfig.STARTING_COINS = 25
IdleConfig.BASE_HEALTH = 20 -- PV de la base, remis à neuf à chaque vague
IdleConfig.FIRST_WAVE_DELAY = 4
IdleConfig.WAVE_CLEAR_DELAY = 1.5
IdleConfig.WAVE_FAIL_DELAY = 3

IdleConfig.HEALTH_GROWTH = 1.15 -- PV x1,15 par vague  (vague 100 : x1 million)
IdleConfig.REWARD_GROWTH = 1.15 -- pièces x1,15 par vague

IdleConfig.MAX_ENEMIES = 80 -- par parcelle
IdleConfig.SYNC_RATE = 6 -- envois de position des ennemis aux clients par seconde
IdleConfig.SHOTS_RATE = 10 -- envois des effets de tir par seconde
IdleConfig.MAX_SHOTS_PER_PACKET = 24

IdleConfig.PICKUP_RADIUS = 7 -- distance pour ramasser une pile de pièces
IdleConfig.MERGE_RADIUS = 6 -- les pièces tombées près d'une pile s'y ajoutent
IdleConfig.MAX_DROPS = 40

IdleConfig.SELL_REFUND = 0.5 -- part du prix rendue à la vente (prix des tours : IdleTowers.luau)

-- Chaque vague a un budget de PV total et un budget de pièces, qui grandissent à chaque vague.
-- Le type de vague décide comment ce budget est réparti : 40 petites nuées ou 3 géants énormes.
-- La difficulté reste donc comparable, mais ce ne sont pas les mêmes tours qui brillent.
IdleConfig.HEALTH_BUDGET = 60 -- PV totaux de la vague 1
IdleConfig.REWARD_BUDGET = 6 -- pièces totales de la vague 1

function IdleConfig.healthBudget(wave: number): number
	return IdleConfig.HEALTH_BUDGET * IdleConfig.HEALTH_GROWTH ^ (wave - 1)
end

function IdleConfig.rewardBudget(wave: number): number
	return IdleConfig.REWARD_BUDGET * IdleConfig.REWARD_GROWTH ^ (wave - 1)
end

-- Types de vagues. share = part du budget, count = nombre d'ennemis, gap = secondes entre deux.
IdleConfig.WAVE_TYPES = {
	Mixed = {
		displayName = "Mixte",
		hint = "Un peu de tout",
		groups = function(wave)
			return {
				{ enemy = "Normal", share = 0.5, count = 6 + math.min(wave // 8, 8), gap = 0.6 },
				{ enemy = "Fast", share = 0.2, count = 3 + math.min(wave // 10, 6), gap = 0.4 },
				{ enemy = "Tank", share = 0.3, count = 1 + math.min(wave // 12, 4), gap = 1.2 },
			}
		end,
	},
	Horde = {
		displayName = "Horde",
		hint = "Une masse d'ennemis fragiles : les tours de zone brillent",
		groups = function(wave)
			return { { enemy = "Swarm", share = 1, count = 25 + math.min(wave // 4, 20), gap = 0.18 } }
		end,
	},
	Rush = {
		displayName = "Rush",
		hint = "Très rapides : ralentis-les !",
		groups = function(wave)
			return { { enemy = "Fast", share = 1, count = 12 + math.min(wave // 6, 12), gap = 0.3 } }
		end,
	},
	Giants = {
		displayName = "Géants",
		hint = "Lents mais énormes : il faut des gros dégâts",
		groups = function(wave)
			return { { enemy = "Giant", share = 1.2, count = 2 + math.min(wave // 25, 2), gap = 3 } }
		end,
	},
	Boss = {
		displayName = "BOSS",
		hint = "Un boss unique : c'est ton DPS qui fera la différence",
		groups = function(wave)
			return {
				{ enemy = "Normal", share = 0.3, count = 6, gap = 0.5 },
				{ enemy = "Boss", share = 1.5, count = 1, gap = 0 },
			}
		end,
	},
}

local ROTATION = { "Mixed", "Horde", "Mixed", "Rush" }

-- Même type de vague pour tout le monde à une vague donnée.
function IdleConfig.waveType(wave: number): string
	if wave % 10 == 0 then
		return "Boss"
	elseif wave % 5 == 0 then
		return "Giants"
	elseif wave <= 3 then
		return "Mixed"
	end
	return ROTATION[wave % #ROTATION + 1]
end

-- Liste des ennemis à faire apparaître : { { enemy, health, reward, gap } }.
function IdleConfig.buildWave(wave: number)
	local healthBudget = IdleConfig.healthBudget(wave)
	local rewardBudget = IdleConfig.rewardBudget(wave)
	local list = {}
	for _, group in IdleConfig.WAVE_TYPES[IdleConfig.waveType(wave)].groups(wave) do
		local health = healthBudget * group.share / group.count
		local reward = rewardBudget * group.share / group.count
		for _ = 1, group.count do
			table.insert(list, { enemy = group.enemy, health = health, reward = reward, gap = group.gap })
		end
	end
	return list
end

return IdleConfig

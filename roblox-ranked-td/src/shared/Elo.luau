local Config = require(script.Parent.Config)

local Elo = {}

-- Probabilité que A batte B.
function Elo.expected(ratingA: number, ratingB: number): number
	return 1 / (1 + 10 ^ ((ratingB - ratingA) / 400))
end

function Elo.kFactor(gamesPlayed: number): number
	if gamesPlayed < Config.Ranked.PLACEMENT_GAMES then
		return Config.Ranked.PLACEMENT_K_FACTOR
	end
	return Config.Ranked.K_FACTOR
end

-- scoreA : 1 = A gagne, 0 = A perd, 0.5 = égalité. Retourne les nouveaux MMR de A et B.
function Elo.compute(ratingA: number, ratingB: number, scoreA: number, gamesA: number, gamesB: number): (number, number)
	local expectedA = Elo.expected(ratingA, ratingB)
	local deltaA = Elo.kFactor(gamesA) * (scoreA - expectedA)
	local deltaB = Elo.kFactor(gamesB) * ((1 - scoreA) - (1 - expectedA))

	local newA = math.max(Config.Ranked.MIN_MMR, math.floor(ratingA + deltaA + 0.5))
	local newB = math.max(Config.Ranked.MIN_MMR, math.floor(ratingB + deltaB + 0.5))
	return newA, newB
end

return Elo

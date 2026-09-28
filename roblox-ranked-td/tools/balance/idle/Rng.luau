-- Tirages aléatoires reproductibles (xorshift32) : même graine = même partie.
local Rng = {}
Rng.__index = Rng

function Rng.new(seed: number)
	local state = (math.floor(seed) * 2654435761 + 12345) % 4294967296
	if state == 0 then
		state = 1
	end
	return setmetatable({ state = state }, Rng)
end

-- Nombre dans [0, 1[
function Rng:next(): number
	local x = self.state
	x = bit32.bxor(x, bit32.lshift(x, 13))
	x = bit32.bxor(x, bit32.rshift(x, 17))
	x = bit32.bxor(x, bit32.lshift(x, 5))
	self.state = x
	return x / 4294967296
end

-- Entier dans [a, b]
function Rng:int(a: number, b: number): number
	return a + math.floor(self:next() * (b - a + 1))
end

-- Même tirage que rollWeighted dans PlotGame.luau
function Rng:weighted(entries, weightOf)
	local total = 0
	for _, entry in entries do
		total += weightOf(entry)
	end
	local roll = self:next() * total
	for _, entry in entries do
		roll -= weightOf(entry)
		if roll <= 0 then
			return entry
		end
	end
	return entries[#entries]
end

return Rng

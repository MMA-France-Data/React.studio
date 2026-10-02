-- DataStore en mémoire pour tester dans Studio sans activer l'accès aux API.
-- N'implémente que les méthodes utilisées par le jeu.
local MockDataStore = {}

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

function MockDataStore.new()
	local data = {}
	local store = {}

	function store:GetAsync(key: string)
		return deepCopy(data[key])
	end

	function store:SetAsync(key: string, value)
		data[key] = deepCopy(value)
	end

	function store:UpdateAsync(key: string, transform)
		local result = transform(deepCopy(data[key]))
		if result ~= nil then
			data[key] = deepCopy(result)
		end
		return deepCopy(result)
	end

	return store
end

return MockDataStore

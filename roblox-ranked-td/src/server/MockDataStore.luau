-- DataStores en mémoire pour tester dans Studio sans activer l'accès aux API.
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

function MockDataStore.newOrdered()
	local data = {}
	local store = {}

	function store:SetAsync(key: string, value: number)
		data[key] = value
	end

	function store:GetAsync(key: string)
		return data[key]
	end

	-- Comme le vrai : transform reçoit l'ancienne valeur (nil si aucune) ; renvoyer nil annule l'écriture.
	function store:UpdateAsync(key: string, transform)
		local result = transform(data[key])
		if result ~= nil then
			data[key] = result
		end
		return result
	end

	function store:RemoveAsync(key: string)
		local old = data[key]
		data[key] = nil
		return old
	end

	function store:GetSortedAsync(ascending: boolean, pageSize: number)
		local entries = {}
		for key, value in data do
			table.insert(entries, { key = key, value = value })
		end
		table.sort(entries, function(a, b)
			if ascending then
				return a.value < b.value
			end
			return a.value > b.value
		end)
		local page = {}
		for i = 1, math.min(pageSize, #entries) do
			page[i] = entries[i]
		end
		return {
			GetCurrentPage = function()
				return page
			end,
		}
	end

	return store
end

return MockDataStore

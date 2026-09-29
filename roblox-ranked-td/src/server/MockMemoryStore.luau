-- MemoryStore en mémoire pour tester le matchmaking dans Studio (un seul serveur), comme MockDataStore pour
-- les sauvegardes. N'implémente que les méthodes utilisées par Matchmaking.luau, avec les mêmes arguments que
-- MemoryStoreService : SortedMap (file triée) et HashMap, expirations comprises.
-- Rien ne fait attendre (pas de yield) : chaque appel, UpdateAsync compris, se fait donc d'un seul coup.
local MockMemoryStore = {}

-- Les valeurs sont copiées à l'entrée et à la sortie, comme le vrai service qui les enregistre en JSON :
-- modifier une table lue ne change pas ce qui est rangé.
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

-- Ordre de la file triée : clé de tri (sans clé d'abord, puis les nombres, puis les textes), puis la clé.
local function sortRank(sortKey): number
	if sortKey == nil then
		return 0
	end
	return if type(sortKey) == "number" then 1 else 2
end

local function before(aKey: string, aSort, bKey: string, bSort): boolean
	local aRank, bRank = sortRank(aSort), sortRank(bSort)
	if aRank ~= bRank then
		return aRank < bRank
	end
	if aSort ~= bSort then
		return aSort < bSort
	end
	return aKey < bKey
end

local function newMap(sorted: boolean)
	local items = {} -- [clé] = { value, sortKey, expiresAt }
	local map = {}

	-- L'élément s'il n'a pas expiré (un élément expiré est effacé, comme dans MemoryStore).
	local function live(key: string)
		local item = items[key]
		if item and os.clock() >= item.expiresAt then
			items[key] = nil
			return nil
		end
		return item
	end

	function map:GetAsync(key: string)
		local item = live(key)
		if not item then
			return nil
		end
		return deepCopy(item.value), item.sortKey
	end

	function map:SetAsync(key: string, value, expiration: number, sortKey)
		local isNew = live(key) == nil
		items[key] = { value = deepCopy(value), sortKey = if sorted then sortKey else nil, expiresAt = os.clock() + expiration }
		return isNew
	end

	-- transform(valeur, cléDeTri) renvoie la nouvelle valeur (et la clé de tri) ; nil = rien ne change.
	function map:UpdateAsync(key: string, transform, expiration: number)
		local item = live(key)
		local newValue, newSortKey = transform(if item then deepCopy(item.value) else nil, if item then item.sortKey else nil)
		if newValue == nil then
			return nil
		end
		items[key] = { value = deepCopy(newValue), sortKey = if sorted then newSortKey else nil, expiresAt = os.clock() + expiration }
		return deepCopy(newValue), if sorted then newSortKey else nil
	end

	function map:RemoveAsync(key: string)
		items[key] = nil
	end

	if sorted then
		-- Bornes exclues : { key = ..., sortKey = ... } (comme MemoryStoreSortedMap:GetRangeAsync).
		function map:GetRangeAsync(direction: Enum.SortDirection, count: number, lowerBound, upperBound)
			local list = {}
			for key in items do
				local item = live(key)
				if item then
					local afterLower = lowerBound == nil or before(lowerBound.key, lowerBound.sortKey, key, item.sortKey)
					local beforeUpper = upperBound == nil or before(key, item.sortKey, upperBound.key, upperBound.sortKey)
					if afterLower and beforeUpper then
						table.insert(list, { key = key, value = deepCopy(item.value), sortKey = item.sortKey })
					end
				end
			end
			table.sort(list, function(a, b)
				return before(a.key, a.sortKey, b.key, b.sortKey)
			end)
			if direction == Enum.SortDirection.Descending then
				local reversed = {}
				for i = #list, 1, -1 do
					table.insert(reversed, list[i])
				end
				list = reversed
			end
			local page = {}
			for i = 1, math.min(count, #list) do
				page[i] = list[i]
			end
			return page
		end
	end

	return map
end

function MockMemoryStore.sortedMap()
	return newMap(true)
end

function MockMemoryStore.hashMap()
	return newMap(false)
end

return MockMemoryStore

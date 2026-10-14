-- LE MARCHÉ DES ZOOS (sa demande, 14/10 : « un onglet d'achat à d'autres zoos fictifs où je leur achète mâle, femelle
-- ou bébé, et pareil des fois faire des échanges entre zoos pour la reproduction, éviter la consanguinité »).
--   Chaque matin, chaque zoo de Config.MARKET.zoos propose quelques animaux (mâles, femelles, bébés, au prix de
--   Config.marketPrice), et quelques échanges : un de leurs adultes contre un des tiens, de la même espèce et du même
--   sexe. L'animal qui arrive est de leur famille : du sang neuf pour tes couples (Animals.related).
--   Un animal acheté va dans un espace construit pour son espèce, qui a encore de la place.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Animals = require(script.Parent.Animals)
local Config = require(ReplicatedStorage.Shared.Config)
local Zoo = require(script.Parent.Zoo)

local Market = {}

local M = Config.MARKET
local random = Random.new()
local offers = {} -- { id, zoo, species, sex, baby, price }
local swaps = {} -- { id, zoo, species, sex }
local nextId = 1
local version = 0

-- (L'écran relit le Marché quand ce numéro change.)
local function bump()
	version += 1
	Zoo.shared:SetAttribute("MarketVersion", version)
end

-- Toutes les espèces qu'on peut avoir (celles des espaces), et celles que le zoo peut déjà accueillir.
local ALL = {}
for _, habitat in Config.HABITATS do
	for _, species in habitat.species do
		if not table.find(ALL, species) then
			table.insert(ALL, species)
		end
	end
end
local function housed(): { string }
	local list = {}
	for plotId, habitatId in Zoo.state.plots do
		local habitat = Config.HABITAT_BY_ID[habitatId]
		for _, species in habitat and habitat.species or {} do
			if not table.find(list, species) then
				table.insert(list, species)
			end
		end
		_ = plotId
	end
	return list
end

-- L'espace où ira un animal de cette espèce : construit pour elle, avec encore de la place (le moins rempli).
function Market.homeFor(species: string): string?
	local best, bestCount = nil, math.huge
	for plotId, habitatId in Zoo.state.plots do
		local habitat = Config.HABITAT_BY_ID[habitatId]
		if habitat and table.find(habitat.species, species) then
			local count = #Animals.inSpace(plotId)
			if count < habitat.capacity and count < bestCount then
				best, bestCount = plotId, count
			end
		end
	end
	return best
end

-- Le nom de l'espace qu'il faut construire pour cette espèce.
local function habitatName(species: string): string
	for _, habitat in Config.HABITATS do
		if table.find(habitat.species, species) then
			return habitat.name
		end
	end
	return species
end

-- LES OFFRES DU JOUR
function Market.refresh()
	table.clear(offers)
	table.clear(swaps)
	local mine = housed()
	for _, zoo in M.zoos do
		for _ = 1, M.offersPerZoo do
			-- (La moitié des offres pour des espèces que le zoo peut déjà accueillir.)
			local pool = if #mine > 0 and random:NextNumber() < 0.5 then mine else ALL
			local species = pool[random:NextInteger(1, #pool)]
			local sex = if random:NextNumber() < 0.5 then "m" else "f"
			local baby = random:NextNumber() < M.baby
			table.insert(offers, { id = nextId, zoo = zoo, species = species, sex = sex, baby = baby, price = Config.marketPrice(species, sex, baby) })
			nextId += 1
		end
	end
	-- Les échanges : pour des espèces dont le zoo a des adultes.
	local adults = {}
	for _, animal in Zoo.state.animals do
		if Animals.adult(animal) then
			table.insert(adults, animal)
		end
	end
	for _ = 1, M.swaps do
		if #adults == 0 then
			break
		end
		local pick = adults[random:NextInteger(1, #adults)]
		local zoo = M.zoos[random:NextInteger(1, #M.zoos)]
		local exists = false
		for _, swap in swaps do
			if swap.species == pick.s and swap.sex == pick.x then
				exists = true
			end
		end
		if not exists then
			table.insert(swaps, { id = nextId, zoo = zoo, species = pick.s, sex = pick.x })
			nextId += 1
		end
	end
	bump()
end

local function find(list, id)
	for index, item in list do
		if item.id == id then
			return index, item
		end
	end
	return nil, nil
end

-- Acheter une offre. Renvoie true si c'est fait.
function Market.buy(player: Player?, id: number): boolean
	local index, offer = find(offers, id)
	if not offer then
		if player then
			Zoo.notify(player, "offerGone")
		end
		return false
	end
	local home = Market.homeFor(offer.species)
	if not home then
		if player then
			Zoo.notify(player, "needSpace", habitatName(offer.species))
		end
		return false
	end
	if not Zoo.spend(offer.price, "animals", player) then
		return false
	end
	table.remove(offers, index)
	local def = Config.SPECIES[offer.species]
	local birth = if offer.baby then Zoo.days() - def.grow * 0.3 else Zoo.days() - 30
	local animal = Animals.add(home, offer.species, offer.sex, birth, { fam = offer.zoo })
	Animals.publishAll()
	Zoo.notify(nil, "bought", Animals.nameOf(animal), offer.zoo, if player then player.Name else "")
	bump()
	return true
end

-- Faire un échange : leur adulte contre le mien (le numéro `mine`, ou celui qui a le plus de famille proche).
function Market.swap(player: Player?, id: number, mine: number?): boolean
	local index, swap = find(swaps, id)
	if not swap then
		return false
	end
	local animal = if mine then Animals.byId(mine) else nil
	if not animal then
		local best, bestRelatives = nil, -1
		for _, candidate in Zoo.state.animals do
			if candidate.s == swap.species and candidate.x == swap.sex and Animals.adult(candidate) and not candidate.k then
				local relatives = 0
				for _, other in Animals.inSpace(candidate.sp) do
					if other ~= candidate and Animals.related(candidate, other) then
						relatives += 1
					end
				end
				if relatives > bestRelatives then
					best, bestRelatives = candidate, relatives
				end
			end
		end
		animal = best
	end
	if not animal or animal.s ~= swap.species or animal.x ~= swap.sex or not Animals.adult(animal) or animal.k then
		if player then
			Zoo.notify(player, "cantSwap")
		end
		return false
	end
	table.remove(swaps, index)
	local given = Animals.nameOf(animal) .. " n°" .. animal.id
	local plot = animal.sp
	Animals.remove(animal)
	local newcomer = Animals.add(plot, swap.species, swap.sex, Zoo.days() - 30, { fam = swap.zoo })
	Animals.publishAll()
	Zoo.notify(nil, "swapped", given, Animals.nameOf(newcomer), swap.zoo)
	bump()
	return true
end

function Market.start()
	local getMarket = Instance.new("RemoteFunction")
	getMarket.Name = "GetMarket"
	getMarket.OnServerInvoke = function()
		return { offers = offers, swaps = swaps }
	end
	getMarket.Parent = ReplicatedStorage:WaitForChild("Remotes")
	Zoo.remotes.marketBuy.OnServerEvent:Connect(function(player, id)
		if typeof(id) == "number" then
			Market.buy(player, id)
		end
	end)
	Zoo.remotes.marketSwap.OnServerEvent:Connect(function(player, id, mine)
		if typeof(id) == "number" and (mine == nil or typeof(mine) == "number") then
			Market.swap(player, id, mine)
		end
	end)
	Market.refresh()
end

-- (Pour les tests : une offre ou un échange précis.)
Market.offers = offers
Market.swaps = swaps
function Market.addOffer(species: string, sex: string, baby: boolean): number
	table.insert(offers, { id = nextId, zoo = M.zoos[1], species = species, sex = sex, baby = baby, price = Config.marketPrice(species, sex, baby) })
	nextId += 1
	bump()
	return nextId - 1
end
function Market.addSwap(species: string, sex: string): number
	table.insert(swaps, { id = nextId, zoo = M.zoos[2], species = species, sex = sex })
	nextId += 1
	bump()
	return nextId - 1
end

return Market

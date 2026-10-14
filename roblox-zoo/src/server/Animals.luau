-- LES ANIMAUX (côté serveur : qui ils sont et comment ils vont ; l'écran de chaque joueur les dessine et les fait
-- se promener, AnimalsView.luau).
--   Un animal : { id, s = espèce, x = sexe (« m » / « f »), sp = son espace, b = sa naissance (en jours du zoo),
--   h = sa faim (0 à 100), k = malade depuis (en jours du zoo, nil s'il va bien), p = heures depuis sa dernière crotte }.
--   Ce que l'écran voit : un dossier ReplicatedStorage.ZooAnimals, une Configuration par animal (attributs Species,
--   Sex, Space, Growth, Sick, Happy, Hunger).
--   Sa demande (14/10) : « 2 animaux de chaque espèce, mâle et femelle, et ils se reproduiront ».
--   LA FAMILLE (sa demande, 14/10 : « des échanges entre zoos pour la reproduction, éviter la consanguinité ») : fam =
--   d'où vient sa famille (« Ferme », le nom du zoo où on l'a acheté, ou celle de sa mère), pa / ma = les numéros de
--   son père et de sa mère, c = consanguin (ses parents étaient de la même famille proche : frère et sœur, ou parent
--   et enfant). Un bébé consanguin tombe 3 fois plus souvent malade et se vend moitié prix. Les couples qui ne sont
--   pas de la même famille proche ont leurs petits en premier.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Enclosures = require(script.Parent.Enclosures)
local Zoo = require(script.Parent.Zoo)

local Animals = {}

local NEEDS = Config.NEEDS
local folder = Instance.new("Folder")
folder.Name = "ZooAnimals"
folder.Parent = ReplicatedStorage

local random = Random.new()
local shown = {} -- [id] = Configuration

-- Les animaux choisis pour une parcelle (Config.HABITATS), ou nil.
function Animals.habitatOf(plotId: string)
	local id = Zoo.state.plots[plotId]
	return id and Config.HABITAT_BY_ID[id]
end

-- 0 (nouveau-né) à 1 (adulte).
function Animals.growth(animal): number
	local def = Config.SPECIES[animal.s]
	return math.clamp((Zoo.days() - animal.b) / def.grow, 0, 1)
end
function Animals.adult(animal): boolean
	return Animals.growth(animal) >= 1
end

function Animals.inSpace(id: string): { any }
	local list = {}
	for _, animal in Zoo.state.animals do
		if animal.sp == id then
			table.insert(list, animal)
		end
	end
	return list
end

function Animals.byId(id: number)
	for _, animal in Zoo.state.animals do
		if animal.id == id then
			return animal
		end
	end
	return nil
end

-- Le bonheur d'un animal (0 à 100) : nourri, propre, en bonne santé, pas trop serré.
function Animals.happiness(animal, crowd: number?): number
	local space = Enclosures.spaces[animal.sp]
	local poops = if space then #space.poops else 0
	local food = 100 - animal.h
	local clean = math.max(0, 100 - poops * 9)
	local health = if animal.k then 15 else 100
	local habitat = Animals.habitatOf(animal.sp)
	local roomy = if habitat and (crowd or 0) > habitat.capacity then 50 else 100
	return math.floor(food * 0.35 + clean * 0.25 + health * 0.3 + roomy * 0.1 + 0.5)
end

-- Le bonheur moyen des animaux d'un espace (ce que voient les visiteurs). nil s'il est vide.
function Animals.spaceHappiness(id: string): number?
	local list = Animals.inSpace(id)
	if #list == 0 then
		return nil
	end
	local total = 0
	for _, animal in list do
		total += Animals.happiness(animal, #list)
	end
	return total / #list
end

local function publish(animal, crowd: number?)
	local item = shown[animal.id]
	if not item then
		item = Instance.new("Configuration")
		item.Name = tostring(animal.id)
		item:SetAttribute("Species", animal.s)
		item:SetAttribute("Sex", animal.x)
		item:SetAttribute("Space", animal.sp)
		item:SetAttribute("Fam", animal.fam or "")
		item:SetAttribute("Father", animal.pa or 0)
		item:SetAttribute("Mother", animal.ma or 0)
		item:SetAttribute("Consang", animal.c == true)
		item.Parent = folder
		shown[animal.id] = item
	end
	item:SetAttribute("Growth", math.floor(Animals.growth(animal) * 20 + 0.5) / 20)
	item:SetAttribute("Sick", animal.k ~= nil)
	item:SetAttribute("Hunger", math.floor(animal.h + 0.5))
	item:SetAttribute("Happy", Animals.happiness(animal, crowd))
	item:SetAttribute("Price", Animals.price(animal))
end

function Animals.publishAll()
	local counts = {}
	for _, animal in Zoo.state.animals do
		counts[animal.sp] = (counts[animal.sp] or 0) + 1
	end
	for _, animal in Zoo.state.animals do
		publish(animal, counts[animal.sp])
	end
end

-- info : { fam = sa famille, pa = son père, ma = sa mère, c = consanguin }.
function Animals.add(spaceId: string, species: string, sex: string, birth: number, info: any?)
	local state = Zoo.state
	local extra = info or {}
	local animal = { id = state.nextId, s = species, x = sex, sp = spaceId, b = birth, h = 0, p = random:NextNumber(0, 2), fam = extra.fam or "Zoo", pa = extra.pa, ma = extra.ma, c = extra.c }
	state.nextId += 1
	table.insert(state.animals, animal)
	publish(animal)
	return animal
end

function Animals.remove(animal)
	local index = table.find(Zoo.state.animals, animal)
	if index then
		table.remove(Zoo.state.animals, index)
	end
	local item = shown[animal.id]
	if item then
		item:Destroy()
		shown[animal.id] = nil
	end
end

-- Le couple de départ d'un espace qu'on vient d'ouvrir : un mâle et une femelle adultes de chaque espèce.
function Animals.addStarter(spaceId: string)
	local habitat = Animals.habitatOf(spaceId)
	local adult = Zoo.days() - 30
	for _, species in habitat and habitat.species or {} do
		-- (Le mâle et la femelle du départ viennent de deux fermes différentes : pas de la même famille.)
		Animals.add(spaceId, species, "m", adult, { fam = "Ferme du Moulin" })
		Animals.add(spaceId, species, "f", adult, { fam = "Ferme des Saules" })
	end
end

-- Soigner un animal malade. Renvoie true s'il l'était.
function Animals.treat(animal): boolean
	if not animal or not animal.k then
		return false
	end
	animal.k = nil
	publish(animal)
	return true
end

-- Ce qu'un autre zoo paie pour cet animal (moitié prix pour un petit, et encore moitié s'il est consanguin).
function Animals.price(animal): number
	local price = Config.SPECIES[animal.s].sell
	if not Animals.adult(animal) then
		price *= 0.5
	end
	if animal.c then
		price *= 0.5
	end
	return math.floor(price)
end

-- Deux animaux de la même famille proche : l'un est le parent de l'autre, ou ils ont un parent en commun.
function Animals.related(a, b): boolean
	if a.id == b.pa or a.id == b.ma or b.id == a.pa or b.id == a.ma then
		return true
	end
	return (a.pa ~= nil and a.pa == b.pa) or (a.ma ~= nil and a.ma == b.ma)
end

-- Vendre un animal (pas malade) à un autre zoo. Renvoie le prix, ou nil.
function Animals.sell(id: number): number?
	local animal = Animals.byId(id)
	if not animal or animal.k then
		return nil
	end
	local price = Animals.price(animal)
	Animals.remove(animal)
	Zoo.addMoney(price, "sales")
	return price
end

-- LE TEMPS QUI PASSE (appelé par Day.luau pendant les heures d'ouverture) : les animaux mangent, ont faim si la
-- mangeoire est vide, font leurs crottes, tombent parfois malades. hours : les heures de jeu écoulées.
function Animals.tick(hours: number)
	local counts, eaters = {}, {}
	for _, animal in Zoo.state.animals do
		counts[animal.sp] = (counts[animal.sp] or 0) + 1
	end
	-- 1. Ce que chaque mangeoire perd.
	for _, animal in Zoo.state.animals do
		local def = Config.SPECIES[animal.s]
		local key = animal.sp .. "|" .. def.food
		eaters[key] = (eaters[key] or 0) + def.eat * (0.5 + 0.5 * Animals.growth(animal))
	end
	for key, amount in eaters do
		local spaceId, food = string.match(key, "^(.-)|(.+)$")
		local space = Enclosures.spaces[spaceId]
		local trough = space and space.troughs[food]
		if trough and trough.level > 0 then
			Enclosures.setLevel(spaceId, food, trough.level - amount * hours)
		end
	end
	-- 2. Chaque animal.
	local now = Zoo.days()
	local lost = {}
	for _, animal in Zoo.state.animals do
		local def = Config.SPECIES[animal.s]
		local space = Enclosures.spaces[animal.sp]
		local trough = space and space.troughs[def.food]
		if trough and trough.level > 0 then
			animal.h = math.max(0, animal.h - NEEDS.hungerFall * hours)
		else
			animal.h = math.min(100, animal.h + NEEDS.hungerRise * hours)
		end
		animal.p += hours
		if animal.p >= def.poop then
			animal.p = 0
			Enclosures.addPoop(animal.sp)
		end
		if animal.k then
			if now - animal.k >= NEEDS.sickDays then
				table.insert(lost, animal)
			end
		else
			local dirty = space and #space.poops >= 6
			local chance = NEEDS.sickChance + (if dirty then NEEDS.sickDirty else 0) + (if animal.h > 60 then NEEDS.sickHungry else 0)
			if animal.c then
				chance *= 3 -- (un consanguin est fragile)
			end
			local perHour = chance / (Config.CLOSE_HOUR - Config.OPEN_HOUR)
			if random:NextNumber() < perHour * hours then
				animal.k = now
				local habitat = Animals.habitatOf(animal.sp)
				Zoo.notify(nil, "sick", Animals.nameOf(animal), if habitat then habitat.name else "")
			end
		end
	end
	for _, animal in lost do
		Zoo.today.lost = (Zoo.today.lost or 0) + 1
		Zoo.notify(nil, "lost", Animals.nameOf(animal))
		Animals.remove(animal)
	end
	Animals.publishAll()
end

-- Le nom d'un animal (« Biche », « Faon »).
function Animals.nameOf(animal): string
	local def = Config.SPECIES[animal.s]
	if not Animals.adult(animal) then
		return def.baby
	end
	return if animal.x == "m" then def.m else def.f
end

-- LA NUIT : les couples heureux ont des petits (tous les `repro` jours, s'il reste de la place).
function Animals.night(): { string }
	local births = {}
	local state = Zoo.state
	for _, plot in Config.PLOTS do
		local habitat = Animals.habitatOf(plot.id)
		if habitat then
			local space = { id = plot.id, capacity = habitat.capacity, species = habitat.species }
			local list = Animals.inSpace(space.id)
			local room = space.capacity - #list
			for _, species in space.species do
				local def = Config.SPECIES[species]
				local males, females = {}, {}
				for _, animal in list do
					if animal.s == species and Animals.adult(animal) and not animal.k and Animals.happiness(animal, #list) >= NEEDS.happyToBreed then
						table.insert(if animal.x == "m" then males else females, animal)
					end
				end
				-- Le couple : d'abord un mâle et une femelle qui ne sont pas de la même famille proche.
				local father, mother = nil, nil
				for _, male in males do
					for _, female in females do
						if not father or (Animals.related(father, mother) and not Animals.related(male, female)) then
							father, mother = male, female
						end
					end
				end
				local key = space.id .. "|" .. species
				if father and mother and room > 0 then
					state.breed[key] = (state.breed[key] or 0) + 1
					if state.breed[key] >= def.repro then
						state.breed[key] = 0
						local count = math.min(room, random:NextInteger(def.litter[1], def.litter[2]))
						local consanguine = Animals.related(father, mother)
						for _ = 1, count do
							Animals.add(space.id, species, if random:NextNumber() < 0.5 then "m" else "f", state.day + 1, { fam = mother.fam, pa = father.id, ma = mother.id, c = consanguine or nil })
							room -= 1
							state.born += 1
							Zoo.today.births = (Zoo.today.births or 0) + 1
						end
						if count > 0 then
							table.insert(births, def.baby .. (if count > 1 then " x" .. count else "") .. (if consanguine then " (consanguin)" else ""))
							if consanguine then
								Zoo.notify(nil, "consanguine", def.baby)
							end
						end
					end
				end
			end
		end
	end
	Animals.publishAll()
	return births
end

function Animals.start()
	-- (Une parcelle achetée est construite VIDE : sa demande du 14/10, « faire le terrain mais pas avoir d'animaux
	-- dedans » ; les animaux s'achètent au Marché, Market.luau.)
	-- Un zoo tout neuf : la mini-ferme et ses trois couples.
	if #Zoo.state.animals == 0 then
		Animals.addStarter("farm")
	end
	Animals.publishAll()
	Zoo.remotes.sell.OnServerEvent:Connect(function(player, id)
		local animal = typeof(id) == "number" and Animals.byId(id)
		if not animal then
			return
		end
		local name = Animals.nameOf(animal)
		local price = Animals.sell(id)
		if price then
			Zoo.notify(nil, "sold", name, price, player.Name)
		else
			Zoo.notify(player, "cantSell")
		end
	end)
end

return Animals

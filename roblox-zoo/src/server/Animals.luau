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
--   LA VIE (sa demande du 15/10, « 4 ») : g = le jour prévu de la naissance quand une femelle est enceinte (gf / gn /
--   gc = le père, son prénom, consanguin) ; r = elle se repose jusqu'à ce jour-là ; l'âge vient de b et de
--   Config.LIFE (vieux à 80 %, mort de vieillesse au bout) ; d = sa maladie (Config.DISEASES), e = examiné.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Config = require(ReplicatedStorage.Shared.Config)
local Enclosures = require(script.Parent.Enclosures)
local Weather = require(script.Parent.Weather)
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
	-- Les jeux de son espace (jusqu'à 3).
	local toys = Zoo.state.toys[animal.sp]
	local fun = 40 + 20 * math.min(3, if toys then #toys else 0)
	return math.floor(food * 0.3 + clean * 0.2 + health * 0.25 + roomy * 0.1 + fun * 0.15 + 0.5)
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
		item:SetAttribute("Birth", animal.b)
		item:SetAttribute("Origin", animal.o or "born")
		item:SetAttribute("OriginZoo", animal.oz or "")
		item:SetAttribute("Arrival", animal.od or 0)
		item:SetAttribute("FatherName", animal.pn or "")
		item:SetAttribute("MotherName", animal.mn or "")
		item.Parent = folder
		shown[animal.id] = item
	end
	item:SetAttribute("Growth", math.floor(Animals.growth(animal) * 20 + 0.5) / 20)
	item:SetAttribute("Sick", animal.k ~= nil)
	item:SetAttribute("Hunger", math.floor(animal.h + 0.5))
	item:SetAttribute("Happy", Animals.happiness(animal, crowd))
	item:SetAttribute("Price", Animals.price(animal))
	item:SetAttribute("Name", animal.n or "")
	item:SetAttribute("Pregnant", animal.g or 0)
	item:SetAttribute("PregnantFather", animal.gn or "")
	item:SetAttribute("Disease", animal.d or "")
	item:SetAttribute("Examined", animal.e == true)
	item:SetAttribute("Old", Animals.old(animal))
	item:SetAttribute("Life", Animals.life(animal))
end

-- L'âge (en jours), la durée de vie de son espèce, et s'il est vieux (80 % de sa vie).
function Animals.age(animal): number
	return Zoo.days() - animal.b
end
function Animals.life(animal): number
	return Config.LIFE[animal.s] or 60
end
function Animals.old(animal): boolean
	return Animals.age(animal) >= Animals.life(animal) * 0.8
end

-- Un prénom au hasard, si possible pas déjà pris dans le zoo.
function Animals.newName(sex: string): string
	local list = Config.NAMES[sex] or Config.NAMES.m
	local used = {}
	for _, animal in Zoo.state.animals do
		if animal.n then
			used[animal.n] = true
		end
	end
	for _ = 1, 12 do
		local name = list[random:NextInteger(1, #list)]
		if not used[name] then
			return name
		end
	end
	return list[random:NextInteger(1, #list)]
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

-- info : { fam = sa famille, pa / ma = son père / sa mère (numéros), pn / mn = leurs prénoms, c = consanguin,
-- n = son prénom, o = d'où il vient (« born » né ici, « start » du départ, « bought » acheté, « swap » échangé),
-- oz = le zoo d'où il vient }. od = le jour de son arrivée.
function Animals.add(spaceId: string, species: string, sex: string, birth: number, info: any?)
	local state = Zoo.state
	local extra = info or {}
	local animal = {
		id = state.nextId, s = species, x = sex, sp = spaceId, b = birth, h = 0, p = random:NextNumber(0, 2),
		fam = extra.fam or "Zoo", pa = extra.pa, ma = extra.ma, pn = extra.pn, mn = extra.mn, c = extra.c,
		n = extra.n or Animals.newName(sex), o = extra.o or "born", oz = extra.oz, od = state.day,
	}
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
	local adult = Zoo.days() - 6
	for _, species in habitat and habitat.species or {} do
		-- (Le mâle et la femelle du départ viennent de deux fermes différentes : pas de la même famille.)
		Animals.add(spaceId, species, "m", adult - random:NextInteger(1, 8), { fam = "Ferme du Moulin", o = "start", oz = "Ferme du Moulin" })
		Animals.add(spaceId, species, "f", adult - random:NextInteger(1, 8), { fam = "Ferme des Saules", o = "start", oz = "Ferme des Saules" })
	end
end

-- Soigner un animal malade avec un médicament (med : nil = n'importe lequel, pour les vieilles commandes de test).
-- Renvoie true s'il est guéri, false si ce n'est pas le bon médicament (ou s'il n'était pas malade).
function Animals.treat(animal, med: string?): boolean
	if not animal or not animal.k then
		return false
	end
	local disease = Config.DISEASES[animal.d or ""]
	if med and disease and disease.med ~= med then
		return false
	end
	animal.k, animal.d, animal.e = nil, nil, nil
	publish(animal)
	return true
end

-- L'examiner : on sait alors ce qu'il a.
function Animals.examine(animal): boolean
	if not animal or not animal.k then
		return false
	end
	animal.e = true
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
	if Animals.old(animal) then
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
	local appetite = Weather.factor("troughs")
	for key, amount in eaters do
		amount *= appetite
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
			if Animals.old(animal) then
				chance *= 2
			end
			local perHour = chance / (Config.CLOSE_HOUR - Config.OPEN_HOUR)
			if random:NextNumber() < perHour * hours then
				Animals.makeSick(animal)
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

-- Il tombe malade : une maladie au hasard, pas encore examinée.
function Animals.makeSick(animal, disease: string?)
	animal.k = Zoo.days()
	animal.d = disease or Config.DISEASE_ORDER[random:NextInteger(1, #Config.DISEASE_ORDER)]
	animal.e = nil
	local habitat = Animals.habitatOf(animal.sp)
	Zoo.notify(nil, "sick", animal.n or Animals.nameOf(animal), if habitat then habitat.name else "", Config.DISEASES[animal.d].hint)
	publish(animal)
end

-- Le nom d'un animal (« Biche », « Faon »).
function Animals.nameOf(animal): string
	local def = Config.SPECIES[animal.s]
	if not Animals.adult(animal) then
		return def.baby
	end
	return if animal.x == "m" then def.m else def.f
end

-- LA NUIT (sa demande du 15/10, « 4 ») : les vieux animaux meurent au bout de leur vie ; les femelles enceintes ont
-- leurs petits le jour prévu ; les couples heureux font de nouveaux petits (la femelle est enceinte Config.SPECIES.repro
-- jours ; d'abord avec un mâle qui n'est pas de sa famille proche). Renvoie la liste des naissances.
Animals.conceiveChance = 0.6
function Animals.night(): { string }
	local births = {}
	local state = Zoo.state
	local tomorrow = state.day + 1
	-- 1. La vieillesse.
	for _, animal in table.clone(state.animals) do
		if Animals.age(animal) >= Animals.life(animal) + (animal.id % 5) then
			Zoo.today.old = (Zoo.today.old or 0) + 1
			Zoo.notify(nil, "oldDeath", animal.n or Animals.nameOf(animal), math.floor(Animals.age(animal)))
			Animals.remove(animal)
		end
	end
	for _, plot in Config.PLOTS do
		local habitat = Animals.habitatOf(plot.id)
		if habitat then
			local list = Animals.inSpace(plot.id)
			local expected = 0
			for _, animal in list do
				if animal.g then
					expected += 1
				end
			end
			local room = habitat.capacity - #list
			for _, species in habitat.species do
				local def = Config.SPECIES[species]
				-- 2. Les naissances du jour.
				for _, mother in list do
					if mother.s == species and mother.g and mother.g <= tomorrow then
						local count = math.min(math.max(room, 0), random:NextInteger(def.litter[1], def.litter[2]))
						for _ = 1, count do
							Animals.add(plot.id, species, if random:NextNumber() < 0.5 then "m" else "f", tomorrow, { fam = mother.fam, pa = mother.gf, ma = mother.id, pn = mother.gn, mn = mother.n, c = mother.gc or nil })
							room -= 1
							state.born += 1
							Zoo.today.births = (Zoo.today.births or 0) + 1
						end
						if count > 0 then
							table.insert(births, def.baby .. (if count > 1 then " x" .. count else "") .. " (" .. (mother.n or "?") .. ")" .. (if mother.gc then " consanguin" else ""))
							if mother.gc then
								Zoo.notify(nil, "consanguine", def.baby)
							end
						end
						mother.g, mother.gf, mother.gn, mother.gc = nil, nil, nil, nil
						mother.r = tomorrow + 1
						expected -= 1
					end
				end
				-- 3. Les nouveaux petits en route.
				for _, mother in list do
					local ready = mother.s == species and mother.x == "f" and not mother.g and Animals.adult(mother) and not Animals.old(mother)
						and not mother.k and (mother.r or 0) <= tomorrow and Animals.happiness(mother, #list) >= NEEDS.happyToBreed
					if ready and room - expected > 0 then
						local father = nil
						for _, male in list do
							if male.s == species and male.x == "m" and Animals.adult(male) and not Animals.old(male) and not male.k and Animals.happiness(male, #list) >= NEEDS.happyToBreed then
								if not father or (Animals.related(father, mother) and not Animals.related(male, mother)) then
									father = male
								end
							end
						end
						if father and random:NextNumber() < Animals.conceiveChance then
							mother.g = tomorrow + def.repro
							mother.gf, mother.gn = father.id, father.n
							mother.gc = Animals.related(father, mother) or nil
							expected += 1
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
	-- (Les animaux d'une vieille sauvegarde, sans prénom : on leur en donne un.)
	for _, animal in Zoo.state.animals do
		if not animal.n then
			animal.n = Animals.newName(animal.x)
		end
	end
	Animals.publishAll()
	-- Renommer un animal (sur sa fiche) : le prénom est filtré par Roblox (les autres joueurs le voient).
	Zoo.remotes.rename.OnServerEvent:Connect(function(player, id, text)
		local animal = typeof(id) == "number" and Animals.byId(id)
		if not animal or typeof(text) ~= "string" then
			return
		end
		text = string.sub((string.gsub(text, "^%s+", ""):gsub("%s+$", "")), 1, 20)
		if #text < 1 then
			return
		end
		local ok, filtered = pcall(function()
			return TextService:FilterStringAsync(text, player.UserId, Enum.TextFilterContext.PublicChat):GetNonChatStringForBroadcastAsync()
		end)
		if ok and filtered and not string.find(filtered, "#", 1, true) then
			animal.n = filtered
			Animals.publishAll()
		else
			Zoo.notify(player, "badName")
		end
	end)
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

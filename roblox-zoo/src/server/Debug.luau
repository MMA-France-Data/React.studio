-- LES COMMANDES DE TEST (seulement dans Studio) : ServerStorage.ZooDebug:Invoke(action, ...).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Animals = require(script.Parent.Animals)
local Day = require(script.Parent.Day)
local Market = require(script.Parent.Market)
local Enclosures = require(script.Parent.Enclosures)
local Staff = require(script.Parent.Staff)
local Visitors = require(script.Parent.Visitors)
local Shops = require(script.Parent.Shops)
local Stock = require(script.Parent.Stock)
local Weather = require(script.Parent.Weather)
local Zoo = require(script.Parent.Zoo)

local Debug = {}

local ACTIONS = {}
function ACTIONS.Money(amount)
	Zoo.addMoney(amount or 10000, "test")
	return Zoo.state.money
end
function ACTIONS.Speed(value)
	Day.speed = value or 1
	return Day.speed
end
function ACTIONS.Buy(id, habitatId)
	local habitat = Config.HABITAT_BY_ID[habitatId]
	Zoo.state.money += if habitat then habitat.price else 0
	return Enclosures.buy(nil, id, habitatId)
end
function ACTIONS.Hire(role)
	Zoo.state.money += 1000
	return Staff.hire(nil, role)
end
function ACTIONS.Fire(role)
	return Staff.fire(nil, role)
end
function ACTIONS.Poop(id, count)
	for _ = 1, count or 3 do
		Enclosures.addPoop(id or "farm")
	end
	return #Enclosures.spaces[id or "farm"].poops
end
function ACTIONS.Sick(id, disease)
	for _, animal in Zoo.state.animals do
		if animal.sp == (id or "farm") and not animal.k then
			Animals.makeSick(animal, disease)
			return animal.id
		end
	end
	return nil
end
function ACTIONS.Level(id, food, level)
	Enclosures.setLevel(id, food, level)
	return true
end
function ACTIONS.Scan()
	return Visitors.scan(nil)
end
function ACTIONS.Queue()
	return Visitors.queueLength(), Visitors.count()
end
function ACTIONS.NextDay()
	Day.nextDay()
	return true
end
function ACTIONS.State()
	return Zoo.state
end
function ACTIONS.Parts()
	local count = 0
	for _, item in workspace:GetDescendants() do
		if item:IsA("BasePart") then
			count += 1
		end
	end
	return count
end
-- Le Marché : la liste des offres, acheter la première d'une espèce, faire le premier échange.
function ACTIONS.Offers()
	return Market.offers, Market.swaps
end
function ACTIONS.MarketBuy(species)
	for _, offer in Market.offers do
		if not species or offer.species == species then
			Zoo.state.money += offer.price
			return Market.buy(nil, offer.id)
		end
	end
	return false
end
function ACTIONS.MarketSwap()
	local swap = Market.swaps[1]
	return swap and Market.swap(nil, swap.id, nil) or false
end
function ACTIONS.Offer(species, sex, baby)
	return Market.addOffer(species, sex, baby == true)
end
function ACTIONS.BuyOffer(id)
	Zoo.state.money += 100000
	return Market.buy(nil, id)
end
function ACTIONS.SwapOffer(species, sex)
	return Market.addSwap(species, sex)
end
function ACTIONS.DoSwap(id, mine)
	return Market.swap(nil, id, mine)
end
function ACTIONS.Give(plot, species, sex, fam, pa, ma)
	local animal = Animals.add(plot, species, sex, Zoo.days() - 30, { fam = fam, pa = pa, ma = ma })
	return animal.id
end
function ACTIONS.InSpace(plot)
	return Animals.inSpace(plot)
end
function ACTIONS.Breed(plot, species, value)
	Zoo.state.breed[plot .. "|" .. species] = value
	return true
end
function ACTIONS.Today()
	return Zoo.today
end
function ACTIONS.Refresh()
	Market.refresh()
	return #Market.offers, #Market.swaps
end
-- Une naissance consanguine : un frère et une sœur adultes, seuls dans leur espace, puis la nuit.
function ACTIONS.Animals()
	return Zoo.state.animals
end
-- Le stock, les commandes, les stands, la météo, la vie des animaux (le test « life »).
function ACTIONS.Stock(item)
	return Stock.get(item)
end
function ACTIONS.SetStock(item, amount)
	Zoo.state.stock[item] = amount
	Stock.publishAll()
	return amount
end
function ACTIONS.Order(cart, seconds)
	Config.DELIVERY_SECONDS = seconds or 2
	Zoo.state.money += 100000
	return Stock.order(nil, cart)
end
function ACTIONS.Boxes()
	return #Stock.boxes
end
function ACTIONS.BuildShop(id, kind)
	Zoo.state.money += 100000
	return Shops.build(nil, id, kind)
end
function ACTIONS.Shop(id)
	return Zoo.state.shops[id]
end
function ACTIONS.Restock(id, amount)
	return Shops.restock(id, amount)
end
function ACTIONS.Price(key, value)
	Zoo.state.prices[key] = value
	Zoo.publish()
	return true
end
function ACTIONS.Weather(weather, event)
	Weather.force(weather, event)
	return true
end
function ACTIONS.Examine(id)
	return Animals.examine(Animals.byId(id))
end
function ACTIONS.Treat(id, med)
	return Animals.treat(Animals.byId(id), med)
end
function ACTIONS.Animal(id)
	return Animals.byId(id)
end
function ACTIONS.Pregnant(mother, father, due)
	local female = Animals.byId(mother)
	female.g, female.gf, female.gn = due or Zoo.state.day + 1, father, "Père"
	Animals.publishAll()
	return true
end
-- (La naissance d'une femelle déjà enceinte : cette nuit.)
function ACTIONS.Due(id)
	local female = Animals.byId(id)
	if female and female.g then
		female.g = Zoo.state.day + 1
		return true
	end
	return false
end
function ACTIONS.Age(id, days)
	local animal = Animals.byId(id)
	animal.b = Zoo.days() - days
	Animals.publishAll()
	return true
end
function ACTIONS.Conceive(value)
	Animals.conceiveChance = value
	return true
end
function ACTIONS.Toy(plot, toy)
	Zoo.state.money += 10000
	return Enclosures.buyToy(nil, plot, toy)
end
function ACTIONS.Visitors()
	local list = {}
	for _, visitor in Visitors.list() do
		table.insert(list, { scanned = visitor.scanned == true, needs = visitor.needs, kind = visitor.kind })
	end
	return list
end
function ACTIONS.Thirsty()
	for _, visitor in Visitors.list() do
		visitor.needs.thirst = 100
	end
	return #Visitors.list()
end
function ACTIONS.SpawnVisitor(kind)
	Visitors.spawn(kind)
	return true
end
function ACTIONS.Bins()
	local list = {}
	for _, bin in Shops.bins do
		table.insert(list, bin.fill)
	end
	return list
end
function ACTIONS.Night()
	return Animals.night()
end

function Debug.start()
	if not RunService:IsStudio() then
		return
	end
	local hook = Instance.new("BindableFunction")
	hook.Name = "ZooDebug"
	hook.OnInvoke = function(action, ...)
		local run = ACTIONS[action]
		if not run then
			return nil
		end
		return run(...)
	end
	hook.Parent = ServerStorage
end

return Debug

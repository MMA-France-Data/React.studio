-- LES COMMANDES DE TEST (seulement dans Studio) : ServerStorage.ZooDebug:Invoke(action, ...).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Animals = require(script.Parent.Animals)
local Day = require(script.Parent.Day)
local Enclosures = require(script.Parent.Enclosures)
local Staff = require(script.Parent.Staff)
local Visitors = require(script.Parent.Visitors)
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
function ACTIONS.Build(id)
	Zoo.state.money += 100000
	return Enclosures.buyBuilding(nil, id)
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
function ACTIONS.Sick(id)
	for _, animal in Zoo.state.animals do
		if animal.sp == (id or "farm") and not animal.k then
			animal.k = Zoo.days()
			Animals.publishAll()
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

-- Démarrage du serveur : construit le décor, puis lance la sauvegarde, la base, les œufs et les monstres.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Pets = require(ReplicatedStorage.Shared.Pets)
local PlayerData = require(script.Parent.PlayerData)
local World = require(script.Parent.World)
local Gym = require(script.Parent.Gym)
local Eggs = require(script.Parent.Eggs)
local Monsters = require(script.Parent.Monsters)

Players.RespawnTime = 2

-- Messages envoyés à l'écran d'un joueur.
local notifyEvent = Instance.new("RemoteEvent")
notifyEvent.Name = "Notify"
notifyEvent.Parent = ReplicatedStorage
local function notify(player: Player, key: string, ...)
	notifyEvent:FireClient(player, key, ...)
end

-- PAS DE CHANGEMENT D'ÉQUIPE EN COMBAT (retour du joueur : « je peux équiper un familier pendant le combat, faudrait
-- désactiver ») : équiper, déséquiper, « les meilleurs » et nourrir sont refusés tant que le combat dure.
local function calm(player: Player): boolean
	if Monsters.inCombat(player) then
		notify(player, "inCombat")
		return false
	end
	return true
end

-- Le bouton de la liste des familiers : ajoute ce familier à l'équipe de combat, ou l'en retire.
local equipEvent = Instance.new("RemoteEvent")
equipEvent.Name = "Equip"
equipEvent.Parent = ReplicatedStorage
equipEvent.OnServerEvent:Connect(function(player, spot)
	if typeof(spot) == "number" and calm(player) then
		Eggs.follow(player, spot)
		Monsters.publishTeam(player)
	end
end)

-- Les deux boutons du bas de la fenêtre des familiers.
for name, action in { EquipBest = Eggs.equipBest, UnequipAll = Eggs.unequipAll } do
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = ReplicatedStorage
	event.OnServerEvent:Connect(function(player)
		if not calm(player) then
			return
		end
		action(player)
		Monsters.publishTeam(player)
	end)
end

-- Le sac : ranger un familier de l'enclos, ou en ressortir un.
for name, action in { BagPet = Eggs.toBag, UnbagPet = Eggs.fromBag } do
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = ReplicatedStorage
	event.OnServerEvent:Connect(function(player, which)
		if typeof(which) == "number" and calm(player) then
			action(player, math.floor(which))
			Monsters.publishTeam(player)
		end
	end)
end

-- Nourrir un familier avec un autre.
local feedEvent = Instance.new("RemoteEvent")
feedEvent.Name = "FeedPet"
feedEvent.Parent = ReplicatedStorage
feedEvent.OnServerEvent:Connect(function(player, eater, food)
	if typeof(eater) == "number" and typeof(food) == "number" and calm(player) then
		Eggs.feed(player, eater, food)
		Monsters.publishTeam(player)
	end
end)

-- Poser l'œuf qu'on porte, là où on se tient dans son enclos.
local placeEvent = Instance.new("RemoteEvent")
placeEvent.Name = "PlaceEgg"
placeEvent.Parent = ReplicatedStorage
-- (position : là où le joueur a cliqué, dans le monde ; sans elle, là où il se tient.)
local function local2(player: Player, position: any): (number?, number?)
	local plot = Gym.plotOf(player)
	if plot and typeof(position) == "Vector3" then
		return position.X - plot.origin.X, position.Z - plot.origin.Z
	end
	return nil, nil
end
placeEvent.OnServerEvent:Connect(function(player, position)
	Eggs.place(player, local2(player, position))
end)
-- Sortir un œuf de son sac (ou le rentrer), et poser le familier qu'on porte là où on clique dans son enclos.
local takeEvent = Instance.new("RemoteEvent")
takeEvent.Name = "TakeEgg"
takeEvent.Parent = ReplicatedStorage
takeEvent.OnServerEvent:Connect(function(player, animal, rank)
	if typeof(animal) == "string" and typeof(rank) == "number" then
		Eggs.take(player, animal, rank)
	end
end)
local putEvent = Instance.new("RemoteEvent")
putEvent.Name = "PutPet"
putEvent.Parent = ReplicatedStorage
putEvent.OnServerEvent:Connect(function(player, position)
	local x, z = local2(player, position)
	if x and z then
		Eggs.putDown(player, x, z)
	end
end)
-- Le bouton « Vendre » de la liste : le joueur PREND le familier dans ses bras et le porte jusqu'au stand
-- « VENDRE ». Un 2e appui le repose dans l'enclos.
local sellEvent = Instance.new("RemoteEvent")
sellEvent.Name = "SellPet"
sellEvent.Parent = ReplicatedStorage
sellEvent.OnServerEvent:Connect(function(player, spot)
	if typeof(spot) == "number" then
		Eggs.hold(player, spot)
	end
end)
-- Le bouton « +1 place » de la liste.
local upgradeEvent = Instance.new("RemoteEvent")
upgradeEvent.Name = "UpgradePen"
upgradeEvent.Parent = ReplicatedStorage
upgradeEvent.OnServerEvent:Connect(function(player)
	Eggs.buyPlace(player)
end)

local world = World.build()
PlayerData.start()
Gym.start(world, notify)
Eggs.start(world, notify, Gym.owns, Gym.plotOf)
Monsters.start(world, notify)

-- (Un nouveau joueur commence SANS familier : il bat des canards à l'épée, qui lâchent souvent leur œuf.)
local _ = Pets

if RunService:IsStudio() then
	require(script.Parent.Debug)(world)
end

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

-- Le bouton de la liste des familiers : ajoute ce familier à l'équipe de combat, ou l'en retire.
local equipEvent = Instance.new("RemoteEvent")
equipEvent.Name = "Equip"
equipEvent.Parent = ReplicatedStorage
equipEvent.OnServerEvent:Connect(function(player, spot)
	if typeof(spot) == "number" then
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
		action(player)
		Monsters.publishTeam(player)
	end)
end

-- Poser l'œuf qu'on porte, là où on se tient dans son enclos.
local placeEvent = Instance.new("RemoteEvent")
placeEvent.Name = "PlaceEgg"
placeEvent.Parent = ReplicatedStorage
placeEvent.OnServerEvent:Connect(function(player)
	Eggs.place(player)
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

-- Démarrage du serveur : construit le décor, puis lance la sauvegarde, la salle de sport et les salles.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PlayerData = require(script.Parent.PlayerData)
local World = require(script.Parent.World)
local Gym = require(script.Parent.Gym)
local Eggs = require(script.Parent.Eggs)
local Rooms = require(script.Parent.Rooms)

Players.RespawnTime = 2

-- Messages envoyés à l'écran d'un joueur (« +300 pièces », « Il te manque... »).
local notifyEvent = Instance.new("RemoteEvent")
notifyEvent.Name = "Notify"
notifyEvent.Parent = ReplicatedStorage
local function notify(player: Player, key: string, ...)
	notifyEvent:FireClient(player, key, ...)
end

-- Appui sur E pour repousser le plafond.
local pushEvent = Instance.new("RemoteEvent")
pushEvent.Name = "Push"
pushEvent.Parent = ReplicatedStorage
pushEvent.OnServerEvent:Connect(function(player)
	Rooms.push(player)
end)

-- Choix de l'animal équipé, depuis la fenêtre « Animaux ».
local equipEvent = Instance.new("RemoteEvent")
equipEvent.Name = "Equip"
equipEvent.Parent = ReplicatedStorage
equipEvent.OnServerEvent:Connect(function(player, animal)
	if typeof(animal) == "string" then
		Eggs.equip(player, animal)
	end
end)

local world = World.build()
PlayerData.start()
Gym.start(world, notify)
Eggs.start(world, notify, Gym.applyStats)
Rooms.start(world, notify)

if RunService:IsStudio() then
	require(script.Parent.Debug)(world)
end

-- Démarrage du serveur : construit le décor, puis lance la sauvegarde, la salle de sport et les salles.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PlayerData = require(script.Parent.PlayerData)
local World = require(script.Parent.World)
local Gym = require(script.Parent.Gym)
local Eggs = require(script.Parent.Eggs)
local Cycle = require(script.Parent.Cycle)
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
	-- L'heure de l'appui : l'écran de tous les joueurs y joue le coup de poing (Poses.luau).
	player:SetAttribute("PunchAt", workspace:GetServerTimeNow())
	Rooms.push(player)
end)

-- Choix du familier qui suit le joueur (par sa place dans l'enclos), depuis la fenêtre « Animaux ».
local equipEvent = Instance.new("RemoteEvent")
equipEvent.Name = "Equip"
equipEvent.Parent = ReplicatedStorage
equipEvent.OnServerEvent:Connect(function(player, spot)
	if typeof(spot) == "number" then
		Eggs.follow(player, spot)
	end
end)

-- Poser l'œuf qu'on porte, là où on se tient dans son enclos ; vendre un familier (par sa place).
local placeEvent = Instance.new("RemoteEvent")
placeEvent.Name = "PlaceEgg"
placeEvent.Parent = ReplicatedStorage
placeEvent.OnServerEvent:Connect(function(player)
	Eggs.place(player)
end)
local sellEvent = Instance.new("RemoteEvent")
sellEvent.Name = "SellPet"
sellEvent.Parent = ReplicatedStorage
-- (Le bouton « Vendre » de la liste ne vend plus tout de suite : le joueur PREND le familier dans ses bras et le
-- porte jusqu'au stand « VENDRE ». Un 2e appui le repose dans l'enclos.)
sellEvent.OnServerEvent:Connect(function(player, spot)
	if typeof(spot) == "number" then
		Eggs.hold(player, spot)
	end
end)

-- Le bouton « +1 place » de la fenêtre des familiers (comme le panneau « Améliorer l'enclos »).
local upgradeEvent = Instance.new("RemoteEvent")
upgradeEvent.Name = "UpgradePen"
upgradeEvent.Parent = ReplicatedStorage
upgradeEvent.OnServerEvent:Connect(function(player)
	Eggs.buyPlace(player)
end)

-- Le bouton « ARRÊTER » pendant un entraînement.
local stopEvent = Instance.new("RemoteEvent")
stopEvent.Name = "StopTraining"
stopEvent.Parent = ReplicatedStorage
stopEvent.OnServerEvent:Connect(function(player)
	Gym.stop(player)
end)

local world = World.build()
PlayerData.start()
Gym.start(world, notify)
Eggs.start(world, notify, Gym.owns, Gym.plotOf)
Cycle.start(world)
Rooms.start(world, notify)

if RunService:IsStudio() then
	require(script.Parent.Debug)(world)
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

local DEFINITIONS = {
	-- Map principale (hub)
	QueueAction = "RemoteEvent", -- client -> serveur : "Join" | "Leave"
	HubAction = "RemoteEvent", -- client -> serveur : "GoHome" | "GoRanked"
	-- Mode infini (parcelles)
	PlotAction = "RemoteEvent", -- client -> serveur : ("Place", spot, type) | ("Upgrade", spot) | ("Sell", spot) | ("BuySpot", spot) | "Rebirth"
	PlotSync = "RemoteEvent", -- serveur -> clients : (plotIndex, buffer, count) positions des ennemis
	PlotShots = "UnreliableRemoteEvent", -- serveur -> clients : (plotIndex, buffer, count) tirs
	CoinDrop = "RemoteEvent", -- serveur -> propriétaire : ("Set" | "Collect", id, position, montant)
	-- Machines à sous
	OpenMachine = "RemoteEvent", -- serveur -> client : ("Tower" | "Bonus") quand on active une machine
	MachineAction = "RemoteEvent", -- client -> serveur : "SpinTower" | "SpinBonusCoins" | ("ApplyBonus", spot, bonusId)
	MachineResult = "RemoteEvent", -- serveur -> client : résultat d'un lancer
	-- Commun
	Notify = "RemoteEvent", -- serveur -> client : (message, kind)
	-- Match
	PlaceTower = "RemoteEvent", -- client -> serveur : (towerType, position)
	UpgradeTower = "RemoteEvent", -- client -> serveur : (towerId)
	SellTower = "RemoteEvent", -- client -> serveur : (towerId)
	SendEnemies = "RemoteEvent", -- client -> serveur : (sendId)
	MatchResult = "RemoteEvent", -- serveur -> client : (result)
	TowerFired = "UnreliableRemoteEvent", -- serveur -> clients : (from, to, towerType, radius, towerId)
}

local FOLDER_NAME = "Remotes"

-- Appelé une seule fois par le serveur au démarrage.
function Remotes.init()
	assert(RunService:IsServer(), "Remotes.init() doit être appelé côté serveur")
	local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end
	for name, className in DEFINITIONS do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new(className)
			remote.Name = name
			remote.Parent = folder
		end
	end
end

function Remotes.get(name: string): any
	assert(DEFINITIONS[name], "Remote inconnu : " .. name)
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
	return folder:WaitForChild(name)
end

return Remotes

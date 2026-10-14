-- LE DÉMARRAGE DU ZOO : le parc, puis le zoo de l'hôte (dans Studio : le premier joueur), ses espaces, ses animaux,
-- les tâches, les visiteurs, le personnel et la journée.
-- (Le hall, avec les parties solo / duo / trio, viendra ensuite : il décidera qui est l'hôte de ce serveur.)
local Players = game:GetService("Players")

local Npc = require(script.Parent.Npc)
local Paths = require(script.Parent.Paths)
local Map = require(script.Parent.Map)
local Zoo = require(script.Parent.Zoo)
local Enclosures = require(script.Parent.Enclosures)
local Animals = require(script.Parent.Animals)
local Tasks = require(script.Parent.Tasks)
local Scanner = require(script.Parent.Scanner)
local Market = require(script.Parent.Market)
local Visitors = require(script.Parent.Visitors)
local Staff = require(script.Parent.Staff)
local Day = require(script.Parent.Day)
local Debug = require(script.Parent.Debug)

-- Les joueurs ne se cognent pas aux visiteurs ni au personnel.
local function character(player: Player)
	local function setup(model: Model)
		-- (Le zoo est grand : le joueur marche plus vite que d'habitude.)
		local humanoid = model:FindFirstChildOfClass("Humanoid") or model:WaitForChild("Humanoid", 5)
		if humanoid and humanoid:IsA("Humanoid") then
			humanoid.WalkSpeed = 26
		end
		for _, item in model:GetDescendants() do
			if item:IsA("BasePart") then
				item.CollisionGroup = "Player"
			end
		end
		model.DescendantAdded:Connect(function(item)
			if item:IsA("BasePart") then
				item.CollisionGroup = "Player"
			end
		end)
	end
	if player.Character then
		setup(player.Character)
	end
	player.CharacterAdded:Connect(setup)
end

Npc.init()
Paths.build()
Players.PlayerAdded:Connect(character)
for _, player in Players:GetPlayers() do
	character(player)
end

local started = os.clock()
Map.build()
print(string.format("[ZOO] parc construit en %.1f s", os.clock() - started))

-- L'hôte : le premier joueur arrivé.
local host = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
Zoo.load(host.UserId, host.DisplayName)
Map.setName("Zoo de " .. host.DisplayName)
Enclosures.build()
Animals.start()
Tasks.start()
Scanner.start()
Visitors.start()
Market.start()
Staff.start()
Day.start()
Zoo.startSaving()
Debug.start()
Zoo.shared:SetAttribute("Ready", true)
print(string.format("[ZOO] zoo de %s prêt en %.1f s", host.DisplayName, os.clock() - started))

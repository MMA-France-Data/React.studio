-- La salle de sport : acheter un niveau sur une machine, donner au personnage sa vitesse et son saut, et le
-- raccourci vers les salles déjà atteintes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerData = require(script.Parent.PlayerData)
local World = require(script.Parent.World)

local Gym = {}

local notify = function(_player: Player, _key: string, ...) end
local spawnPosition = Vector3.new(0, 4, -16)

local function prompt(part: BasePart, kind: string, distance: number): ProximityPrompt
	local item = Instance.new("ProximityPrompt")
	item.Name = "Prompt"
	item.HoldDuration = 0.25
	item.MaxActivationDistance = distance
	item.RequiresLineOfSight = false
	item.AutoLocalize = false
	item.ObjectText = ""
	item.ActionText = ""
	item:SetAttribute("Kind", kind)
	item.Parent = part
	return item
end

-- Vitesse et saut du personnage selon les niveaux du joueur.
function Gym.applyStats(player: Player)
	local data = PlayerData.get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not data or not humanoid then
		return
	end
	humanoid.UseJumpPower = false
	humanoid.WalkSpeed = Config.walkSpeed(data.levels.Speed)
	humanoid.JumpHeight = Config.jumpHeight(data.levels.Jump)
end

-- Achète le niveau suivant d'une machine. Renvoie true, ou false et la raison (« max », « poor »).
function Gym.buy(player: Player, machine: string): (boolean, string?)
	local data = PlayerData.get(player)
	if not data or not table.find(Config.MACHINES, machine) then
		return false, "data"
	end
	local level = data.levels[machine]
	local price = Config.price(level)
	if not price then
		return false, "max"
	end
	if data.coins < price then
		notify(player, "poor", price - data.coins)
		return false, "poor"
	end
	PlayerData.addCoins(player, -price)
	PlayerData.setLevel(player, machine, level + 1)
	Gym.applyStats(player)
	notify(player, "bought", machine, level + 1)
	return true
end

local function teleport(player: Player, position: Vector3)
	local character = player.Character
	if character and character.PrimaryPart then
		character:PivotTo(CFrame.new(position))
	end
end

-- Raccourci : mène devant la salle qui suit `cleared`, si le joueur a déjà réussi cette salle.
function Gym.shortcut(player: Player, cleared: number): boolean
	local data = PlayerData.get(player)
	if not data or not table.find(Config.SHORTCUTS, cleared) then
		return false
	end
	if data.best < cleared then
		notify(player, "shortcutLocked", cleared)
		return false
	end
	teleport(player, World.sasCenter(cleared))
	return true
end

function Gym.toGym(player: Player)
	teleport(player, spawnPosition)
end

function Gym.start(world, notifier)
	notify = notifier
	for name, model in world.gym.machines do
		local item = prompt(model.PrimaryPart, "Machine", 14)
		item:SetAttribute("Machine", name)
		item.Triggered:Connect(function(player)
			Gym.buy(player, name)
		end)
	end
	for cleared, pad in world.gym.shortcuts do
		local item = prompt(pad, "Shortcut", 10)
		item:SetAttribute("Cleared", cleared)
		item.Triggered:Connect(function(player)
			Gym.shortcut(player, cleared)
		end)
	end
	prompt(world.final.back, "Back", 12).Triggered:Connect(Gym.toGym)

	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid")
			Gym.applyStats(player)
		end)
		Gym.applyStats(player)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	-- Les données arrivent après le personnage : on redonne les bonnes valeurs à ce moment-là.
	PlayerData.onLoaded(Gym.applyStats)
end

return Gym

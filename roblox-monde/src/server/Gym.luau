-- LA BASE : chaque joueur y reçoit son espace (son enclos) et y apparaît. On y améliore son épée à la forge.
-- (Le dossier s'appelle encore « Gym » : c'était la salle de sport du jeu d'où vient ce code.)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerData = require(script.Parent.PlayerData)

local Gym = {}

local notify = function(_player: Player, _key: string, ...) end
local plots = {} -- les espaces construits par World
local owners = {} -- [numéro de l'espace] = joueur

-- L'espace du joueur (nil s'il n'en a pas : serveur plein, cas impossible avec 6 joueurs au plus).
function Gym.plotOf(player: Player)
	return plots[player:GetAttribute("Plot") or 0]
end

-- Vrai si cet espace est celui du joueur ; sinon le lui dit.
function Gym.owns(player: Player, index: number): boolean
	if player:GetAttribute("Plot") == index then
		return true
	end
	notify(player, "notYours")
	return false
end

local function assign(player: Player)
	for index, plot in plots do
		if not owners[index] then
			owners[index] = player
			player:SetAttribute("Plot", index)
			plot.folder:SetAttribute("OwnerId", player.UserId)
			plot.folder:SetAttribute("Owner", player.DisplayName)
			return
		end
	end
end

local function release(player: Player)
	for index, owner in owners do
		if owner == player then
			owners[index] = nil
			plots[index].folder:SetAttribute("OwnerId", 0)
			plots[index].folder:SetAttribute("Owner", "")
		end
	end
end

-- Vitesse, saut et vie du personnage (la vie monte avec le niveau). full : remet aussi la vie au maximum.
function Gym.applyStats(player: Player, full: boolean?)
	local data = PlayerData.get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not data or not humanoid then
		return
	end
	humanoid.UseJumpPower = false
	humanoid.WalkSpeed = Config.WALK_SPEED
	humanoid.JumpHeight = Config.JUMP_HEIGHT
	local maxHealth = Config.maxHealth(data.level)
	if humanoid.MaxHealth ~= maxHealth or full then
		humanoid.MaxHealth = maxHealth
		humanoid.Health = maxHealth
	end
end

-- LA FORGE : améliore l'épée d'un niveau, avec des pièces. Renvoie true, ou false et la raison (« poor »).
function Gym.buySword(player: Player): (boolean, string?)
	local data = PlayerData.get(player)
	if not data then
		return false, "data"
	end
	local price = Config.swordPrice(data.sword)
	if data.coins < price then
		notify(player, "poor", price - data.coins)
		return false, "poor"
	end
	data.sword += 1
	PlayerData.addCoins(player, -price)
	notify(player, "swordUp", data.sword, Config.hitDamage(data.sword, data.level))
	return true
end

local function teleport(player: Player, position: Vector3)
	local character = player.Character
	if character and character.PrimaryPart then
		character:PivotTo(CFrame.new(position))
	end
end

-- Pose le joueur dans son espace.
function Gym.toGym(player: Player)
	local plot = Gym.plotOf(player)
	if plot then
		teleport(player, plot.spawn)
	end
end

function Gym.start(world, notifier)
	notify = notifier
	plots = world.gym.plots
	local forge = Instance.new("ProximityPrompt")
	forge.Name = "Prompt"
	forge.HoldDuration = 0.2
	forge.MaxActivationDistance = 14
	forge.RequiresLineOfSight = false
	forge.AutoLocalize = false
	forge:SetAttribute("Kind", "Forge")
	forge.Parent = world.gym.forge
	forge.Triggered:Connect(Gym.buySword)

	local function arrive(player: Player, character: Model)
		character:WaitForChild("Humanoid")
		character:WaitForChild("HumanoidRootPart")
		Gym.applyStats(player, true)
		-- Laisse Roblox finir de poser le personnage au point d'apparition, puis le met dans son espace.
		task.wait()
		if player.Character == character then
			Gym.toGym(player)
		end
	end
	local function watch(player: Player)
		assign(player)
		player.CharacterAdded:Connect(function(character)
			arrive(player, character)
		end)
		if player.Character then
			task.spawn(arrive, player, player.Character)
		end
	end
	Players.PlayerRemoving:Connect(release)
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	-- Les données arrivent après le personnage : on redonne les bonnes valeurs à ce moment-là.
	PlayerData.onLoaded(function(player)
		Gym.applyStats(player, true)
	end)
end

return Gym

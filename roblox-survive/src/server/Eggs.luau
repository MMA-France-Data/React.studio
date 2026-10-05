-- Les œufs, les couveuses et les animaux.
-- Finir une salle donne l'œuf de son animal. On le pose dans une couveuse de la salle de sport ; après le temps de
-- couvaison (qui continue même quand le joueur est parti), on l'ouvre : la rareté est tirée à ce moment-là.
-- Un animal déjà possédé en aussi bien ou mieux donne des pièces à la place.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Pets = require(ReplicatedStorage.Shared.Pets)
local PlayerData = require(script.Parent.PlayerData)

local Eggs = {}

local random = Random.new()
local notify = function(_player: Player, _key: string, ...) end
local onEquip = function(_player: Player) end

-- Donne l'œuf de la salle (s'il reste de la place).
function Eggs.give(player: Player, room: number): boolean
	local data = PlayerData.get(player)
	local animal = Config.ROOMS[room] and Config.ROOMS[room].egg
	if not data or not animal then
		return false
	end
	if #data.eggs >= Pets.MAX_EGGS then
		notify(player, "eggFull")
		return false
	end
	table.insert(data.eggs, { a = animal, r = room })
	PlayerData.changed(player)
	notify(player, "egg", animal)
	return true
end

function Eggs.equip(player: Player, animal: string): boolean
	local data = PlayerData.get(player)
	if not data or (animal ~= "" and not data.pets[animal]) then
		return false
	end
	-- Choisir l'animal déjà équipé le range.
	data.equipped = if data.equipped == animal then "" else animal
	PlayerData.changed(player)
	onEquip(player)
	return true
end

-- Ajoute un animal à la collection (éclosion, ou test). Renvoie true s'il est nouveau ou plus rare qu'avant.
function Eggs.grant(player: Player, animal: string, rarity: number): boolean
	local data = PlayerData.get(player)
	if not data or not Pets.DEFS[animal] then
		return false
	end
	local better = (data.pets[animal] or 0) < rarity
	if better then
		data.pets[animal] = rarity
		if data.equipped == "" then
			data.equipped = animal
		end
		PlayerData.changed(player)
		onEquip(player)
	end
	return better
end

-- Le joueur touche la couveuse n : pose son plus vieil œuf, ou ouvre l'œuf prêt.
-- Renvoie ce qui s'est passé : "placed", "wait", "hatched", "duplicate", "none".
function Eggs.use(player: Player, slot: number): string
	local data = PlayerData.get(player)
	if not data or slot < 1 or slot > Pets.SLOTS then
		return "none"
	end
	local key = tostring(slot)
	local egg = data.slots[key]
	if not egg then
		local waiting = table.remove(data.eggs, 1)
		if not waiting then
			notify(player, "noEgg")
			return "none"
		end
		data.slots[key] = { a = waiting.a, r = waiting.r, t = os.time() + Pets.hatchSeconds(waiting.r) }
		PlayerData.changed(player)
		notify(player, "placed", waiting.a)
		return "placed"
	end
	if os.time() < egg.t then
		notify(player, "wait", egg.t - os.time())
		return "wait"
	end
	data.slots[key] = nil
	local rarity = Pets.roll(random, egg.r)
	if Eggs.grant(player, egg.a, rarity) then
		PlayerData.changed(player)
		notify(player, "hatched", egg.a, rarity)
		return "hatched"
	end
	local coins = Pets.DUPLICATE_COINS[rarity]
	PlayerData.addCoins(player, coins)
	notify(player, "duplicate", egg.a, rarity, coins)
	return "duplicate"
end

function Eggs.start(world, notifier, equipCallback)
	notify = notifier
	onEquip = equipCallback
	for slot, model in world.gym.incubators do
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "Prompt"
		prompt.HoldDuration = 0.25
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.AutoLocalize = false
		prompt:SetAttribute("Kind", "Incubator")
		prompt:SetAttribute("Slot", slot)
		prompt.Parent = model.PrimaryPart
		prompt.Triggered:Connect(function(player)
			Eggs.use(player, slot)
		end)
	end
end

return Eggs

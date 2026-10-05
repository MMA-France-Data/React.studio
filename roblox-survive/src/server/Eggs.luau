-- Les œufs et la collection de familiers.
-- Finir une salle donne l'œuf de son animal. Il va tout seul dans l'enclos du joueur et y couve (30 secondes × le
-- numéro de la salle, même quand le joueur est parti) ; autant d'œufs qu'on veut couvent en même temps. À la fin,
-- il éclot tout seul : la rareté est tirée à ce moment-là.
-- Un familier nouveau entre dans la collection et se pose dans l'enclos du joueur : il rapporte des pièces à chaque
-- seconde tant que le joueur est dans le jeu. Un familier déjà trouvé donne des pièces d'un coup à la place.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Pets = require(ReplicatedStorage.Shared.Pets)
local PlayerData = require(script.Parent.PlayerData)

local Eggs = {}

-- Les tests coupent le revenu des familiers et les éclosions pour compter les pièces des salles au plus juste.
Eggs.incomePaused = false
Eggs.hatchPaused = false

local random = Random.new()
local notify = function(_player: Player, _key: string, ...) end

-- Choisit le familier qui suit le joueur (le même une 2e fois : plus aucun ne le suit).
function Eggs.equip(player: Player, animal: string): boolean
	local data = PlayerData.get(player)
	if not data or (animal ~= "" and Pets.best(data.pets[animal]) == 0) then
		return false
	end
	data.equipped = if data.equipped == animal then "" else animal
	PlayerData.changed(player)
	return true
end

-- Ajoute un familier à la collection (éclosion, ou test). Renvoie true s'il est nouveau.
function Eggs.grant(player: Player, animal: string, rarity: number): boolean
	local data = PlayerData.get(player)
	if not data or not Pets.DEFS[animal] or not Pets.RARITIES[rarity] then
		return false
	end
	local list = data.pets[animal]
	if not list then
		list = {}
		for i = 1, #Pets.RARITIES do
			list[i] = false
		end
		data.pets[animal] = list
	end
	if list[rarity] then
		return false
	end
	list[rarity] = true
	if data.equipped == "" then
		data.equipped = animal
	end
	PlayerData.changed(player)
	return true
end

-- Salle réussie : son œuf va couver dans l'enclos du joueur. Autant d'œufs qu'on veut couvent en même temps.
function Eggs.give(player: Player, room: number): boolean
	local data = PlayerData.get(player)
	local animal = Config.ROOMS[room] and Config.ROOMS[room].egg
	if not data or not animal or #data.eggs >= Pets.MAX_EGGS then
		return false
	end
	local seconds = Pets.hatchSeconds(room)
	table.insert(data.eggs, { a = animal, r = room, t = os.time() + seconds })
	PlayerData.changed(player)
	notify(player, "egg", animal, seconds)
	return true
end

-- Fait éclore les œufs du joueur qui ont fini de couver (tous si `all`). La rareté est tirée ; un familier nouveau
-- va dans la collection (donc sur son socle), un familier déjà trouvé donne des pièces à la place.
-- Renvoie le nombre d'œufs éclos.
function Eggs.hatch(player: Player, all: boolean?): number
	local data = PlayerData.get(player)
	if not data then
		return 0
	end
	local now, hatched = os.time(), 0
	for i = #data.eggs, 1, -1 do
		local egg = data.eggs[i]
		if all or now >= egg.t then
			table.remove(data.eggs, i)
			hatched += 1
			local rarity = Pets.roll(random, egg.r)
			if Eggs.grant(player, egg.a, rarity) then
				notify(player, "hatched", egg.a, rarity)
			else
				local coins = Pets.DUPLICATE_COINS[rarity]
				PlayerData.addCoins(player, coins)
				notify(player, "duplicate", egg.a, rarity, coins)
			end
		end
	end
	if hatched > 0 then
		PlayerData.changed(player)
	end
	return hatched
end

function Eggs.start(_world, notifier)
	notify = notifier

	-- Chaque seconde : les œufs qui ont fini de couver éclosent, et la collection de chaque joueur lui rapporte ses
	-- pièces (les centimes s'accumulent).
	local owed = {}
	Players.PlayerRemoving:Connect(function(player)
		owed[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				if not Eggs.hatchPaused then
					Eggs.hatch(player)
				end
				local data = PlayerData.get(player)
				if data and not Eggs.incomePaused then
					local total = (owed[player] or 0) + Pets.income(data.pets)
					local coins = math.floor(total)
					owed[player] = total - coins
					if coins > 0 then
						PlayerData.addCoins(player, coins)
					end
				end
			end
		end
	end)
end

return Eggs

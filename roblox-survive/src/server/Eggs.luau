-- Les tickets, les œufs et l'enclos (voir le chemin d'un familier en haut de Pets.luau).
--   Salle réussie -> un ticket de la salle.
--   Boutique du lobby -> chaque ticket devient un œuf de l'animal de la salle (rareté tirée à ce moment-là).
--   Enclos -> le joueur pose l'œuf sur une place libre ; il y couve ; à l'éclosion le familier reçoit sa valeur
--   cachée et rapporte des pièces à chaque seconde, tant que le joueur est dans le jeu.
--   Une place occupée par un familier peut être vendue ; la place suivante de l'enclos s'achète.
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

-- Salle réussie : un ticket de cette salle.
function Eggs.give(player: Player, room: number): boolean
	local data = PlayerData.get(player)
	if not data or not Config.ROOMS[room] or not Config.ROOMS[room].egg then
		return false
	end
	local key = tostring(room)
	data.tickets[key] = (data.tickets[key] or 0) + 1
	PlayerData.changed(player)
	notify(player, "ticket", room)
	return true
end

-- À la boutique : tous les tickets du joueur deviennent des œufs (tant qu'il a de la place pour les garder).
-- Renvoie le nombre d'œufs reçus.
function Eggs.exchange(player: Player): number
	local data = PlayerData.get(player)
	if not data then
		return 0
	end
	local received = 0
	for room = 1, #Config.ROOMS do
		local key = tostring(room)
		while (data.tickets[key] or 0) > 0 and #data.bag < Pets.MAX_BAG do
			data.tickets[key] -= 1
			table.insert(data.bag, { a = Config.ROOMS[room].egg, q = Pets.roll(random, room), r = room })
			received += 1
		end
		if data.tickets[key] == 0 then
			data.tickets[key] = nil
		end
	end
	if received > 0 then
		PlayerData.changed(player)
		notify(player, "exchanged", received)
	else
		notify(player, "noTicket")
	end
	return received
end

-- Pose le plus vieil œuf du joueur sur cette place de son enclos.
function Eggs.place(player: Player, spot: number): boolean
	local data = PlayerData.get(player)
	local key = tostring(spot)
	if not data or spot < 1 or spot > data.places or data.spots[key] then
		return false
	end
	local egg = table.remove(data.bag, 1)
	if not egg then
		notify(player, if next(data.tickets) then "goShop" else "noEgg")
		return false
	end
	local seconds = Pets.hatchSeconds(egg.r, egg.q)
	data.spots[key] = { a = egg.a, q = egg.q, r = egg.r, t = os.time() + seconds }
	PlayerData.changed(player)
	notify(player, "placed", egg.a, egg.q, seconds)
	return true
end

-- Fait éclore les œufs du joueur qui ont fini de couver (tous si `all`) : le familier reçoit sa valeur cachée.
-- Renvoie le nombre d'œufs éclos.
function Eggs.hatch(player: Player, all: boolean?): number
	local data = PlayerData.get(player)
	if not data then
		return 0
	end
	local now, hatched = os.time(), 0
	for key, spot in data.spots do
		if spot.t and (all or now >= spot.t) then
			local value = Pets.rollValue(random, spot.q)
			data.spots[key] = { a = spot.a, q = spot.q, v = value }
			hatched += 1
			if data.equipped == "" then
				data.equipped = key
			end
			notify(player, "hatched", spot.a, spot.q, Pets.incomeOf(spot.a, value))
		end
	end
	if hatched > 0 then
		PlayerData.changed(player)
	end
	return hatched
end

-- Vend le familier de cette place : des pièces, et la place est libre.
function Eggs.sell(player: Player, spot: number): boolean
	local data = PlayerData.get(player)
	local key = tostring(spot)
	local pet = data and data.spots[key]
	if not pet or not pet.v then
		return false
	end
	local coins = Pets.sellPrice(pet.a, pet.v)
	data.spots[key] = nil
	if data.equipped == key then
		data.equipped = ""
	end
	PlayerData.addCoins(player, coins)
	notify(player, "sold", pet.a, coins)
	return true
end

-- Achète la place suivante de l'enclos.
function Eggs.buyPlace(player: Player): boolean
	local data = PlayerData.get(player)
	local price = data and Pets.spotPrice(data.places)
	if not price then
		return false
	end
	if data.coins < price then
		notify(player, "poor", price - data.coins)
		return false
	end
	data.places += 1
	PlayerData.addCoins(player, -price)
	notify(player, "placeBought", data.places)
	return true
end

-- Le joueur appuie sur E devant une place de son enclos : selon ce qu'il y a dessus, il achète la place, pose un
-- œuf, ou vend le familier. Renvoie ce qui s'est passé ("bought", "placed", "wait", "sold", "none").
function Eggs.use(player: Player, spot: number): string
	local data = PlayerData.get(player)
	if not data then
		return "none"
	end
	local occupant = data.spots[tostring(spot)]
	if spot == data.places + 1 then
		return if Eggs.buyPlace(player) then "bought" else "none"
	elseif spot > data.places then
		return "none"
	elseif not occupant then
		return if Eggs.place(player, spot) then "placed" else "none"
	elseif occupant.t then
		notify(player, "wait", math.max(0, occupant.t - os.time()))
		return "wait"
	end
	return if Eggs.sell(player, spot) then "sold" else "none"
end

-- Choisit le familier qui suit le joueur, par sa place (le même une 2e fois : plus aucun ne le suit).
function Eggs.follow(player: Player, spot: number): boolean
	local data = PlayerData.get(player)
	local key = tostring(spot)
	if not data or not data.spots[key] or not data.spots[key].v then
		return false
	end
	data.equipped = if data.equipped == key then "" else key
	PlayerData.changed(player)
	return true
end

-- owns(joueur, numéro de l'espace) : vrai si c'est son espace (Gym.owns).
function Eggs.start(world, notifier, owns)
	notify = notifier
	local function prompt(part: BasePart, kind: string): ProximityPrompt
		local item = Instance.new("ProximityPrompt")
		item.Name = "Prompt"
		item.HoldDuration = 0.25
		item.MaxActivationDistance = 9
		item.RequiresLineOfSight = false
		item.AutoLocalize = false
		item:SetAttribute("Kind", kind)
		item.Parent = part
		return item
	end
	for index, plot in world.gym.plots do
		for spot, pad in plot.pens do
			local item = prompt(pad, "Spot")
			item:SetAttribute("Plot", index)
			item:SetAttribute("Spot", spot)
			item.Triggered:Connect(function(player)
				if owns(player, index) then
					Eggs.use(player, spot)
				end
			end)
		end
	end
	local shop = prompt(world.gym.shop, "Shop")
	shop.MaxActivationDistance = 14
	shop.Triggered:Connect(Eggs.exchange)

	-- Chaque seconde : les œufs qui ont fini de couver éclosent, et l'enclos de chaque joueur lui rapporte ses
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
					local total = (owed[player] or 0) + Pets.income(data.spots)
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

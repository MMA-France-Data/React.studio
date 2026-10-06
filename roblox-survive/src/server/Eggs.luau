-- Les tickets, les œufs et l'enclos (voir le chemin d'un familier en haut de Pets.luau).
--   Salle réussie -> un ticket de la salle.
--   Boutique du lobby -> chaque ticket devient un œuf de la salle : son rang est tiré à ce moment-là, et dans une
--   salle à collection ce rang donne l'animal (un des six de la salle).
--   Le joueur porte l'œuf sur la tête jusqu'à son enclos et le pose par terre, où il veut. L'œuf y couve ; à
--   l'éclosion le familier reçoit sa valeur cachée, se promène dans l'enclos et rapporte des pièces à chaque
--   seconde, tant que le joueur est dans le jeu.
--   L'enclos a un nombre de places (son niveau) : on l'améliore au panneau de sa clôture. Un familier se vend.
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
local plotOf = function(_player: Player): any
	return nil
end

-- Le bonus de chance d'une salle en ce moment (1 = aucun). Cycle.luau le remplace par le sien.
Eggs.luckOf = function(_room: number): number
	return 1
end

-- Salle réussie : un ticket de cette salle. Le ticket garde la chance du moment (clé « salle:chance ») : celle de
-- la salle si elle est chanceuse, plus celle du familier qui suit le joueur. Elle servira quand le ticket deviendra
-- un œuf. Exemple : salle à +300 % (4) et familier à +25 % = 4,25.
function Eggs.give(player: Player, room: number): boolean
	local data = PlayerData.get(player)
	if not data or not Config.ROOMS[room] or not Config.ROOMS[room].egg then
		return false
	end
	local luck = math.floor((Eggs.luckOf(room) + Pets.luckOf(data.spots[data.equipped]) / 100) * 100 + 0.5) / 100
	local key = if luck > 1 then room .. ":" .. luck else tostring(room)
	data.tickets[key] = (data.tickets[key] or 0) + 1
	PlayerData.changed(player)
	notify(player, "ticket", room, luck)
	return true
end

-- Fait avancer la couvaison de tous les œufs de tous les joueurs (pendant la fermeture de la porte).
function Eggs.accelerate(seconds: number)
	for _, player in Players:GetPlayers() do
		local data = PlayerData.get(player)
		local changed = false
		for _, spot in data and data.spots or {} do
			if spot.t then
				spot.t -= seconds
				changed = true
			end
		end
		if changed then
			PlayerData.changed(player)
		end
	end
end

-- À la boutique : tous les tickets du joueur deviennent des œufs (tant qu'il a de la place pour les garder).
-- Renvoie le nombre d'œufs reçus.
function Eggs.exchange(player: Player): number
	local data = PlayerData.get(player)
	if not data then
		return 0
	end
	local received = 0
	local keys = {}
	for key in data.tickets do
		table.insert(keys, key)
	end
	table.sort(keys)
	for _, key in keys do
		-- « 3 » = un ticket de la salle 3 ; « 3:4 » = gagné quand la salle 3 avait un bonus de chance de 4.
		local room, luck = string.match(key, "^(%d+):?([%d%.]*)$")
		room, luck = tonumber(room), tonumber(luck) or 1
		while (data.tickets[key] or 0) > 0 and #data.bag < Pets.MAX_BAG do
			data.tickets[key] -= 1
			local rank = Pets.roll(random, room, luck)
			-- La valeur cachée du futur familier est tirée ICI (`b`, celle de la salle 1) : l'œuf est d'autant plus
			-- gros qu'elle est haute dans le palier de son rang.
			table.insert(data.bag, { a = Pets.animalOf(room, rank, Config.ROOMS[room].egg), q = rank, r = room, b = Pets.rollValue(random, rank) })
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

-- Pose l'œuf que le joueur porte, là où il se tient dans son enclos (x, z : par rapport au milieu de son espace ;
-- sans eux, c'est la place du personnage). Renvoie true, ou false et la raison.
function Eggs.place(player: Player, x: number?, z: number?): (boolean, string?)
	local data = PlayerData.get(player)
	local plot = plotOf(player)
	if not data or not plot then
		return false, "data"
	end
	if not x or not z then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root then
			return false, "data"
		end
		x, z = root.Position.X - plot.origin.X, root.Position.Z - plot.origin.Z
	end
	if #data.bag == 0 then
		notify(player, if next(data.tickets) then "goShop" else "noEgg")
		return false, "noEgg"
	end
	local pen = Pets.PEN
	if x < pen.minX - 1 or x > pen.maxX + 1 or z < pen.minZ - 1 or z > pen.maxZ + 1 then
		notify(player, "notInPen")
		return false, "notInPen"
	end
	-- Une place libre parmi celles du niveau de l'enclos.
	local key
	for index = 1, data.places do
		if not data.spots[tostring(index)] then
			key = tostring(index)
			break
		end
	end
	if not key then
		notify(player, "penFull")
		return false, "penFull"
	end
	local egg = table.remove(data.bag, 1)
	local seconds = Pets.hatchSeconds(egg.r, egg.q)
	data.spots[key] = {
		a = egg.a,
		q = egg.q,
		r = egg.r,
		b = egg.b,
		t = os.time() + seconds,
		d = seconds,
		x = math.clamp(x, pen.minX, pen.maxX),
		z = math.clamp(z, pen.minZ, pen.maxZ),
	}
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
			local base = spot.b or Pets.rollValue(random, spot.q)
			local value = base * Pets.roomFactor(spot.r or 1)
			data.spots[key] = { a = spot.a, q = spot.q, v = value, l = Pets.luckPercent(base, spot.r or 1), x = spot.x, z = spot.z }
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

-- Améliore l'enclos d'un niveau : une place de plus.
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
	notify(player, "placeBought", Pets.penLevel(data.places), data.places)
	return true
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

-- owns(joueur, numéro de l'espace) : vrai si c'est son espace ; plotFor(joueur) : son espace (Gym.owns, Gym.plotOf).
function Eggs.start(world, notifier, owns, plotFor)
	notify = notifier
	plotOf = plotFor
	local function prompt(part: BasePart, kind: string, distance: number): ProximityPrompt
		local item = Instance.new("ProximityPrompt")
		item.Name = "Prompt"
		item.HoldDuration = 0.25
		item.MaxActivationDistance = distance
		item.RequiresLineOfSight = false
		item.AutoLocalize = false
		item:SetAttribute("Kind", kind)
		item.Parent = part
		return item
	end
	-- Le panneau « Améliorer l'enclos » de chaque espace.
	for index, plot in world.gym.plots do
		local item = prompt(plot.upgrade, "PenUpgrade", 12)
		item:SetAttribute("Plot", index)
		item.Triggered:Connect(function(player)
			if owns(player, index) then
				Eggs.buyPlace(player)
			end
		end)
	end
	-- La boutique des œufs, et le stand « VENDRE » (qui ouvre la fenêtre des familiers).
	prompt(world.gym.shop, "Shop", 14).Triggered:Connect(Eggs.exchange)
	prompt(world.gym.sell, "Sell", 14).Triggered:Connect(function(player)
		notify(player, "openPets")
	end)

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

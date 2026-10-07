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

-- La chance d'œuf rare du joueur : 1, plus celle du meilleur de ses familiers de combat.
function Eggs.luck(player: Player): number
	return 1 + (player:GetAttribute("PetLuck") or 0) / 100
end

-- UN MONSTRE LÂCHE UN ŒUF de sa zone : le rang est tiré ici (avec la chance du joueur), il donne l'animal, et la
-- valeur cachée du futur familier est tirée aussi (`b`) : l'œuf est d'autant plus gros qu'elle est haute.
-- Renvoie l'œuf, ou nil si le joueur ne peut plus en porter.
-- rank : le rang de l'œuf (un monstre lâche l'œuf de SON animal) ; sans lui (un coffre), le rang est tiré au sort.
function Eggs.drop(player: Player, zone: number, rank: number?)
	local data = PlayerData.get(player)
	if not data or not Pets.COLLECTIONS[zone] or #data.bag >= Pets.MAX_BAG then
		return nil
	end
	rank = rank or Pets.roll(random, zone, Eggs.luck(player))
	local egg = { a = Pets.COLLECTIONS[zone][rank], q = rank, r = zone, b = Pets.rollValue(random, rank) }
	table.insert(data.bag, egg)
	PlayerData.changed(player)
	notify(player, "eggDrop", egg.a, egg.q)
	return egg
end

-- SORTIR UN ŒUF DE SON SAC, OU LE RENTRER (demande du joueur : « pouvoir sortir celui que je veux sur ma tête et le
-- rentrer »). Cliquer sur un œuf de la fenêtre le met sur la tête du joueur ; recliquer dessus le range. Tant qu'il
-- n'est pas sorti, un œuf ne se voit pas et ne se pose pas.
function Eggs.take(player: Player, animal: string, rank: number): boolean
	local data = PlayerData.get(player)
	if not data then
		return false
	end
	local first = data.bag[1]
	if player:GetAttribute("Carrying") and first and first.a == animal and first.q == rank then
		player:SetAttribute("Carrying", false)
		PlayerData.changed(player)
		return true
	end
	for index, egg in data.bag do
		if egg.a == animal and egg.q == rank then
			table.insert(data.bag, 1, table.remove(data.bag, index))
			Eggs.release(player)
			player:SetAttribute("Carrying", true)
			PlayerData.changed(player)
			notify(player, "eggOut", egg.a, egg.q)
			return true
		end
	end
	return false
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
	if #data.bag == 0 or not player:GetAttribute("Carrying") then
		notify(player, "noEgg")
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
	player:SetAttribute("Carrying", false)
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
			data.spots[key] = { a = spot.a, q = spot.q, v = value, l = Pets.luckPercent(base, spot.r or 1), x = spot.x, z = spot.z, lv = 1, xp = 0 }
			hatched += 1
			-- Il rejoint l'équipe de combat s'il y reste une place.
			if #data.team < Config.TEAM then
				table.insert(data.team, key)
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
	local member = table.find(data.team, key)
	if member then
		table.remove(data.team, member)
	end
	PlayerData.addCoins(player, coins)
	notify(player, "sold", pet.a, coins)
	return true
end

-- PORTER UN FAMILIER POUR LE VENDRE : le joueur prend le familier de cette place dans ses bras (attributs « Held »
-- = la place, « HeldPet » = « animal:rang:grosseur » pour que les écrans le dessinent au-dessus de sa tête). Il va
-- au stand « VENDRE » et y appuie sur E. Rappeler avec la même place : il le repose dans l'enclos.
local held = {} -- [joueur] = clé de la place
local function setHeld(player: Player, key: string?)
	held[player] = key
	local data = PlayerData.get(player)
	local pet = key and data and data.spots[key]
	player:SetAttribute("Held", if pet then key else "")
	player:SetAttribute("HeldPet", if pet then pet.a .. ":" .. pet.q .. ":" .. math.floor(Pets.alongOf(pet) * 100 + 0.5) else "")
end
-- Repose sans rien dire le familier porté (quand le joueur sort un œuf à la place).
function Eggs.release(player: Player)
	if held[player] then
		setHeld(player, nil)
	end
end
-- POSER LE FAMILIER PORTÉ là où le joueur clique dans son enclos (x, z : par rapport au milieu de son espace).
function Eggs.putDown(player: Player, x: number, z: number): boolean
	local data = PlayerData.get(player)
	local key = held[player]
	local pet = key and data and data.spots[key]
	if not pet then
		return false
	end
	local pen = Pets.PEN
	if x < pen.minX - 1 or x > pen.maxX + 1 or z < pen.minZ - 1 or z > pen.maxZ + 1 then
		notify(player, "notInPen")
		return false
	end
	pet.x, pet.z = math.clamp(x, pen.minX, pen.maxX), math.clamp(z, pen.minZ, pen.maxZ)
	setHeld(player, nil)
	PlayerData.changed(player)
	return true
end
function Eggs.hold(player: Player, spot: number): boolean
	local data = PlayerData.get(player)
	local key = tostring(spot)
	local pet = data and data.spots[key]
	if not pet or not pet.v then
		return false
	end
	-- (On ne porte qu'une chose à la fois : l'œuf sorti retourne dans le sac.)
	if player:GetAttribute("Carrying") then
		player:SetAttribute("Carrying", false)
		PlayerData.changed(player)
	end
	if held[player] == key then
		setHeld(player, nil)
		return true
	end
	setHeld(player, key)
	notify(player, "holdPet", pet.a, Pets.sellPrice(pet.a, pet.v))
	return true
end
-- Au stand « VENDRE » : vend le familier porté. Renvoie false si le joueur ne porte rien.
function Eggs.sellHeld(player: Player): boolean
	local key = held[player]
	if not key then
		return false
	end
	setHeld(player, nil)
	return Eggs.sell(player, tonumber(key) :: number)
end
Players.PlayerRemoving:Connect(function(player)
	held[player] = nil
end)

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

-- L'ÉQUIPE DE COMBAT : jusqu'à Config.TEAM familiers suivent le joueur et se battent avec lui. Le bouton de la
-- liste ajoute ce familier à l'équipe, ou l'en retire. Équipe pleine : il prend la place du plus ancien.
function Eggs.follow(player: Player, spot: number): boolean
	local data = PlayerData.get(player)
	local key = tostring(spot)
	if not data or not data.spots[key] or not data.spots[key].v then
		return false
	end
	local member = table.find(data.team, key)
	if member then
		table.remove(data.team, member)
		notify(player, "teamLeft", data.spots[key].a)
	else
		if #data.team >= Config.TEAM then
			table.remove(data.team, 1)
		end
		table.insert(data.team, key)
		notify(player, "teamJoined", data.spots[key].a, Pets.damageOf(data.spots[key]))
	end
	PlayerData.changed(player)
	return true
end

-- NOURRIR (demande du joueur : « quand j'ai un nouveau mieux, il mange les anciens et récupère 75 % de son XP ») :
-- le familier `eater` mange le familier `food`, qui disparaît ; il reçoit Pets.FEED de toute l'XP que l'autre avait
-- gagnée. Renvoie l'XP reçue, ou nil.
function Eggs.feed(player: Player, eater: number, food: number): number?
	local data = PlayerData.get(player)
	local eaterKey, foodKey = tostring(eater), tostring(food)
	local pet, meal = data and data.spots[eaterKey], data and data.spots[foodKey]
	if not pet or not meal or not pet.v or not meal.v or eaterKey == foodKey then
		return nil
	end
	local gain = math.floor(Pets.totalXp(meal) * Pets.FEED)
	if held[player] == foodKey then
		setHeld(player, nil)
	end
	data.spots[foodKey] = nil
	local member = table.find(data.team, foodKey)
	if member then
		table.remove(data.team, member)
	end
	pet.xp = (pet.xp or 0) + gain
	pet.lv = pet.lv or 1
	while pet.xp >= Pets.xpNeed(pet) do
		pet.xp -= Pets.xpNeed(pet)
		pet.lv += 1
	end
	PlayerData.changed(player)
	notify(player, "fed", pet.a, meal.a, gain, Pets.levelOf(pet))
	return gain
end

-- « Équiper les meilleurs » : l'équipe devient les familiers qui tapent le plus fort. « Tout déséquiper » : plus
-- personne dans l'équipe.
function Eggs.equipBest(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	local keys = {}
	for key, spot in data.spots do
		if spot.v then
			table.insert(keys, key)
		end
	end
	table.sort(keys, function(a, b)
		local x, y = Pets.damageOf(data.spots[a]), Pets.damageOf(data.spots[b])
		return if x == y then tonumber(a) < tonumber(b) else x > y
	end)
	data.team = {}
	for i = 1, math.min(Config.TEAM, #keys) do
		data.team[i] = keys[i]
	end
	PlayerData.changed(player)
end
function Eggs.unequipAll(player: Player)
	local data = PlayerData.get(player)
	if data then
		data.team = {}
		PlayerData.changed(player)
	end
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
	-- Le stand « VENDRE » (qui ouvre la fenêtre des familiers).
	prompt(world.gym.sell, "Sell", 14).Triggered:Connect(function(player)
		-- Avec un familier dans les bras : il est vendu. Sinon : la fenêtre des familiers, pour en choisir un.
		if not Eggs.sellHeld(player) then
			notify(player, "openPets")
		end
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

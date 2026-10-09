-- Seulement dans Studio : commandes pour les tests automatiques (ServerStorage.SurviveDebug:Invoke(action, ...)).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Pets = require(ReplicatedStorage.Shared.Pets)
local Config = require(ReplicatedStorage.Shared.Config)
local PlayerData = require(script.Parent.PlayerData)
local Gym = require(script.Parent.Gym)
local Eggs = require(script.Parent.Eggs)
local Monsters = require(script.Parent.Monsters)

return function(world)
	local debug = Instance.new("BindableFunction")
	debug.Name = "SurviveDebug"
	debug.OnInvoke = function(action: string, a, b, c)
		local player = Players:GetPlayers()[1]
		local data = PlayerData.get(player)
		if action == "Data" then
			return data and { coins = data.coins, level = data.level, xp = data.xp, sword = data.sword, zone = data.zone, bag = #data.bag, team = table.clone(data.team), spots = data.spots }
		elseif action == "Give" then
			PlayerData.addCoins(player, a)
		elseif action == "Leaving" then
			-- Comme si le joueur ouvrait le menu de Roblox. a = true : comme si c'était un nouveau jour.
			if a then
				data.sd = 0
			end
			return require(script.Parent.Rewards).leaving(player)
		elseif action == "EggNow" then
			-- Pose d'un clic l'œuf de l'animal a et du rang b (comme la fenêtre des œufs).
			return Eggs.placeNow(player, a, b)
		elseif action == "Swap" then
			-- Le familier numéro a du sac prend la place b de l'enclos.
			return Eggs.swap(player, a, b)
		elseif action == "SellPen" then
			-- Vend le familier de la place a de l'enclos (comme le vendeur).
			return Eggs.sell(player, a)
		elseif action == "SellBag" then
			return Eggs.sellStored(player, a)
		elseif action == "Buy" then
			-- Comme un achat en Robux réussi du produit a (rank, xp, coins, damage), sans passer par Roblox.
			return require(script.Parent.Store).grant(player, a)
		elseif action == "Pass" then
			-- Donne (b = true) ou enlève le pass à vie a (xp, coins).
			PlayerData.setPass(player, a, b)
			return true
		elseif action == "Event" then
			-- L'admin lance l'événement a (coins, xp, eggs) pour b minutes (0 = l'arrêter).
			return require(script.Parent.Admin).launch(player, a, b)
		elseif action == "Potion" then
			-- Donne b potions de la sorte a (rank, xp, coins, damage).
			return require(script.Parent.Potions).give(player, a, b)
		elseif action == "Drink" then
			-- Boit une potion de la sorte a (b = la place du familier, pour la potion de rang).
			return require(script.Parent.Potions).use(player, a, b)
		elseif action == "Gift" then
			-- Le cadeau du temps de jeu : prêt dans a secondes (0 = tout de suite) ; « Claim » le réclame.
			data.gt = Config.GIFT_EVERY - (a or 0)
			player:SetAttribute("GiftIn", a or 0)
			-- (b : le numéro du prochain cadeau dans Config.GIFTS.)
			if b then
				data.gs = b
				player:SetAttribute("GiftStep", b)
			end
			return true
		elseif action == "Claim" then
			return require(script.Parent.Rewards).claim(player)
		elseif action == "Offline" then
			-- Comme si le joueur revenait après `a` secondes d'absence (même calcul que PlayerData au chargement).
			local away = math.clamp(a, 0, Config.OFFLINE_MAX)
			local earned = math.floor(Pets.income(data.spots) * away * Config.OFFLINE_SHARE)
			PlayerData.addCoins(player, earned)
			player:SetAttribute("OfflineTime", away)
			player:SetAttribute("Offline", earned)
			return earned
		elseif action == "Reset" then
			PlayerData.reset(player)
			Gym.applyStats(player, true)
		elseif action == "Plot" then
			local plot = Gym.plotOf(player)
			return plot and { index = plot.index, origin = plot.origin }
		elseif action == "Zones" then
			local list = {}
			for index, zone in world.zones do
				list[index] = { zMin = zone.zMin, zMax = zone.zMax, boss = zone.boss }
			end
			return list
		elseif action == "Income" then
			Eggs.incomePaused = not a
		elseif action == "Hatching" then
			Eggs.hatchPaused = not a
		elseif action == "Peaceful" then
			Monsters.peaceful = a
		elseif action == "Monsters" then
			return Monsters.list()
		elseif action == "Attack" then
			-- Un coup d'épée, comme le bouton. Renvoie l'animal touché.
			local monster = Monsters.attack(player)
			return monster and monster.animal
		elseif action == "Travel" then
			return Monsters.travel(player, a)
		elseif action == "Hurt" then
			Monsters.hurt(player, a, b)
		elseif action == "TeamDamage" then
			return Monsters.teamDamage(player)
		elseif action == "BuySword" then
			return Gym.buySword(player)
		elseif action == "Zone" then
			-- Ouvre les zones jusqu'à a.
			data.zone = a
			PlayerData.changed(player)
		elseif action == "Level" then
			data.level = a
			PlayerData.changed(player)
			Gym.applyStats(player, true)
		elseif action == "Sword" then
			data.sword = a
			PlayerData.changed(player)
		elseif action == "Pet" then
			-- Pose directement un familier a de rang b (valeur au milieu de son palier, x c = facteur de zone) sur la
			-- première place vide, et le met dans l'équipe.
			for spot = 1, Pets.SPOTS_MAX do
				local key = tostring(spot)
				if not data.spots[key] then
					data.places = math.max(data.places, spot)
					local range = Pets.VALUE[b]
					local base = (range[1] + range[2]) // 2
					local room = Pets.DEFS[a].room or 1
					data.spots[key] = { a = a, q = b, v = base * Pets.roomFactor(room), l = Pets.luckPercent(base, room), x = 10, z = 16, lv = 1, xp = 0 }
					PlayerData.changed(player)
					Eggs.follow(player, spot)
					Monsters.publishTeam(player)
					return true
				end
			end
			return false
		elseif action == "Egg" then
			-- Un œuf de la zone a (et du rang b, sinon tiré au sort).
			return Eggs.drop(player, a or 1, b) ~= nil
		elseif action == "Place" then
			player:SetAttribute("Carrying", true)
			return Eggs.place(player, a, b)
		elseif action == "ToBag" then
			return Eggs.toBag(player, a)
		elseif action == "FromBag" then
			return Eggs.fromBag(player, a)
		elseif action == "Feed" then
			return Eggs.feed(player, a, b)
		elseif action == "Take" then
			return Eggs.take(player, a, b)
		elseif action == "PutDown" then
			return Eggs.putDown(player, a, b)
		elseif action == "Hold" then
			return Eggs.hold(player, a)
		elseif action == "Hatch" then
			return Eggs.hatch(player, true)
		end
		return nil
	end
	debug.Parent = ServerStorage

	-- LE BOUTON « VISITER » (dans Studio seulement) : ouvre toutes les zones au joueur, pour aller voir les mondes
	-- suivants sans battre les boss. Les monstres n attaquent jamais les premiers : on peut se promener partout.
	local visit = Instance.new("RemoteEvent")
	visit.Name = "DebugVisit"
	visit.OnServerEvent:Connect(function(player)
		local data = PlayerData.get(player)
		if data then
			data.zone = #world.zones
			PlayerData.changed(player)
		end
	end)
	visit.Parent = ReplicatedStorage

	-- LA MOLETTE (dans Studio seulement) : passe a l epee suivante ou precedente, de 1 a 8, pour les essayer.
	local swap = Instance.new("RemoteEvent")
	swap.Name = "DebugSword"
	swap.OnServerEvent:Connect(function(player, step)
		local data = PlayerData.get(player)
		if data and (step == 1 or step == -1) then
			data.sword = (data.sword - 1 + step) % 16 + 1
			PlayerData.changed(player)
		end
	end)
	swap.Parent = ReplicatedStorage
end

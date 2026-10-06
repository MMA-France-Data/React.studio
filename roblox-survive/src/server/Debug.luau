-- Seulement dans Studio : commandes pour les tests automatiques (ServerStorage.SurviveDebug:Invoke(action, ...)).
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local PlayerData = require(script.Parent.PlayerData)
local Gym = require(script.Parent.Gym)
local Rooms = require(script.Parent.Rooms)
local Eggs = require(script.Parent.Eggs)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Pets = require(ReplicatedStorage.Shared.Pets)
local World = require(script.Parent.World)

return function(_world)
	local debug = Instance.new("BindableFunction")
	debug.Name = "SurviveDebug"
	debug.OnInvoke = function(action: string, a, b, c)
		local player = Players:GetPlayers()[1]
		if action == "Data" then
			local data = PlayerData.get(player)
			-- Speed, Jump, Force : les points de chaque stat ; machines : le niveau de chaque machine.
			return data and { coins = data.coins, best = data.best, Speed = data.points.Speed, Jump = data.points.Jump, Force = data.points.Force, machines = table.clone(data.machines) }
		elseif action == "Give" then
			PlayerData.addCoins(player, a)
		elseif action == "Reset" then
			PlayerData.reset(player)
			Gym.applyStats(player)
		elseif action == "Level" then
			PlayerData.setLevel(player, a, b)
			Gym.applyStats(player)
		elseif action == "Best" then
			PlayerData.setBest(player, a)
		elseif action == "Buy" then
			local ok, reason = Gym.buy(player, a)
			return ok, reason
		elseif action == "Defuse" then
			-- Comme le bouton de la bombe de la salle a.
			local room = Rooms.get(a)
			return room.defuse ~= nil and room.defuse(player)
		elseif action == "Stop" then
			return Gym.stop(player)
		elseif action == "Points" then
			-- Met la stat a à b points.
			PlayerData.get(player).points[a] = b
			PlayerData.changed(player)
			Gym.applyStats(player)
		elseif action == "Train" then
			local ok, reason = Gym.train(player, a)
			return ok, reason
		elseif action == "Shortcut" then
			return Gym.shortcut(player, a)
		elseif action == "Scale" then
			Rooms.timeScale = a
		elseif action == "Room" then
			local room = Rooms.get(a)
			local pillars = {}
			for i, top in room.pillars or {} do
				pillars[i] = top
			end
			return {
				state = room.state,
				elapsed = room.elapsed,
				center = room.center,
				zMin = room.zMin,
				zMax = room.zMax,
				pillars = pillars,
				melody = room.melody,
				rush = room.rush,
				hunter = room.hunter,
				chaser = room.chaser,
				melodyPads = (function()
					local list = {}
					for i, pad in room.melodyPads or {} do
						list[i] = pad.Position
					end
					return list
				end)(),
				exitOpen = room.exit:GetAttribute("Open"),
				entryOpen = room.entry:GetAttribute("Open"),
			}
		elseif action == "Push" then
			-- a = nombre d'appuis, b = true pour ignorer la limite d'appuis par seconde. Renvoie ceux qui ont compté.
			local counted = 0
			for _ = 1, a do
				if Rooms.push(player, b) then
					counted += 1
				end
			end
			return counted
		elseif action == "Eggs" then
			-- tickets, œufs à poser (bag), places, familiers et œufs de l'enclos, revenu, place du familier qui suit.
			local data = PlayerData.get(player)
			local tickets = 0
			for _, count in data.tickets do
				tickets += count
			end
			local pets, eggs = Pets.count(data.spots)
			local spots = {}
			for key, spot in data.spots do
				spots[key] = { a = spot.a, q = spot.q, v = spot.v, l = spot.l, t = spot.t, x = spot.x, z = spot.z, d = spot.d }
			end
			local lucky = 0
			for key, count in data.tickets do
				if string.find(key, ":") then
					lucky += count
				end
			end
			local keys = {}
			for key in data.tickets do
				table.insert(keys, key)
			end
			table.sort(keys)
			return { keys = table.concat(keys, " "), lucky = lucky, tickets = tickets, bag = #data.bag, first = data.bag[1] and data.bag[1].a or "", places = data.places, pets = pets, eggs = eggs, income = Pets.income(data.spots), equipped = data.equipped, spots = spots }
		elseif action == "EmptyBag" then
			-- Jette les œufs à poser.
			table.clear(PlayerData.get(player).bag)
			PlayerData.changed(player)
		elseif action == "Ticket" then
			-- Donne un ticket de la salle a (comme une salle réussie).
			return Eggs.give(player, a)
		elseif action == "Exchange" then
			return Eggs.exchange(player)
		elseif action == "Place" then
			-- Pose l'œuf porté à l'endroit (a, b) de l'enclos (par rapport au milieu de l'espace) ; sans a et b : là
			-- où se tient le joueur. Renvoie true, ou false et la raison.
			local ok, reason = Eggs.place(player, a, b)
			return ok, reason
		elseif action == "Upgrade" then
			-- Comme le panneau « Améliorer l'enclos ».
			return Eggs.buyPlace(player)
		elseif action == "Sell" then
			-- Vend le familier de la place a.
			return Eggs.sell(player, a)
		elseif action == "Hatch" then
			-- Fait éclore tout de suite tous les œufs qui couvent. Renvoie leur nombre.
			return Eggs.hatch(player, true)
		elseif action == "Ripen" then
			-- Tous les œufs ont fini de couver (ils écloront tout seuls à la prochaine seconde).
			for _, spot in PlayerData.get(player).spots do
				if spot.t then
					spot.t = 0
				end
			end
			PlayerData.changed(player)
		elseif action == "Hatching" then
			-- a = false : les œufs n'éclosent plus tout seuls ; true : ils éclosent de nouveau.
			Eggs.hatchPaused = not a
		elseif action == "Cycle" then
			-- "pause" : plus de fermeture prévue ; "close" : ferme la porte du lobby tout de suite ;
			-- "luck", salle, bonus : pose le bonus de chance.
			-- Renvoie l'état : { state, room, luck, gateOpen }.
			local Cycle = require(script.Parent.Cycle)
			if a == "pause" then
				Cycle.paused = true
			elseif a == "close" then
				Cycle.force()
			elseif a == "luck" then
				Cycle.setLuck(b, c)
			end
			return Cycle.state()
		elseif action == "OpenPets" then
			-- Ouvre la fenêtre des familiers du joueur (comme le stand « VENDRE »), pour une photo.
			ReplicatedStorage.Notify:FireClient(player, "openPets")
		elseif action == "Clear" then
			-- Vide l'enclos (sans rien vendre).
			local data = PlayerData.get(player)
			table.clear(data.spots)
			data.equipped = ""
			PlayerData.changed(player)
		elseif action == "Egg" then
			-- Ajoute un œuf de l'animal a, de rareté b, aux œufs à poser.
			table.insert(PlayerData.get(player).bag, { a = a, q = b, r = 1 })
			PlayerData.changed(player)
		elseif action == "Pet" then
			-- Pose directement un familier a de rareté b (valeur au milieu de son palier) sur la première place vide,
			-- en ouvrant des places s'il le faut, et le fait suivre le joueur. "" : plus aucun ne le suit.
			local data = PlayerData.get(player)
			if a == "" then
				data.equipped = ""
			else
				local key
				for spot = 1, Pets.SPOTS_MAX do
					if not data.spots[tostring(spot)] then
						key = tostring(spot)
						data.places = math.max(data.places, spot)
						break
					end
				end
				if not key then
					return false
				end
				local range = Pets.VALUE[b]
				local value = (range[1] + range[2]) // 2
				data.spots[key] = { a = a, q = b, v = value, l = Pets.luckPercent(value, 1), x = 10, z = 16 }
				data.equipped = key
			end
			PlayerData.changed(player)
			return true
		elseif action == "Income" then
			-- a = false : coupe le revenu des familiers ; true : le remet.
			Eggs.incomePaused = not a
		elseif action == "Plot" then
			local plot = Gym.plotOf(player)
			return plot and { index = plot.index, origin = plot.origin, spawn = plot.spawn }
		elseif action == "Sas" then
			return World.sasCenter(a)
		end
		return nil
	end
	debug.Parent = ServerStorage
end

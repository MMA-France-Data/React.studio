-- Seulement dans Studio : commandes pour les tests automatiques (ServerStorage.SurviveDebug:Invoke(action, ...)).
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local PlayerData = require(script.Parent.PlayerData)
local Gym = require(script.Parent.Gym)
local Rooms = require(script.Parent.Rooms)
local Eggs = require(script.Parent.Eggs)
local World = require(script.Parent.World)

return function(_world)
	local debug = Instance.new("BindableFunction")
	debug.Name = "SurviveDebug"
	debug.OnInvoke = function(action: string, a, b)
		local player = Players:GetPlayers()[1]
		if action == "Data" then
			local data = PlayerData.get(player)
			return data and { coins = data.coins, best = data.best, Speed = data.levels.Speed, Jump = data.levels.Jump, Force = data.levels.Force }
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
				melodyPads = (function()
					local list = {}
					for i, pad in room.melodyPads or {} do
						list[i] = pad.Position
					end
					return list
				end)(),
				shield = room.shields[player],
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
			local data = PlayerData.get(player)
			local slots = {}
			for slot = 1, 2 do
				local egg = data.slots[tostring(slot)]
				slots[slot] = if egg then egg.a else ""
			end
			return { eggs = #data.eggs, first = data.eggs[1] and data.eggs[1].a or "", slots = slots, equipped = data.equipped, pets = table.clone(data.pets) }
		elseif action == "Slot" then
			return Eggs.use(player, a)
		elseif action == "Hatch" then
			-- Les œufs des couveuses sont prêts tout de suite.
			for _, egg in PlayerData.get(player).slots do
				egg.t = 0
			end
			PlayerData.changed(player)
		elseif action == "Pet" then
			-- Donne l'animal a à la rareté b et l'équipe ("" = aucun animal équipé).
			local data = PlayerData.get(player)
			if a ~= "" then
				data.pets[a] = b
			end
			data.equipped = a
			PlayerData.changed(player)
			Gym.applyStats(player)
		elseif action == "Sas" then
			return World.sasCenter(a)
		end
		return nil
	end
	debug.Parent = ServerStorage
end

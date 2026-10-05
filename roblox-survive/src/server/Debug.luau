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
			-- pets : la meilleure rareté trouvée pour chaque animal ; bits : la collection (« Dragon:1010 »).
			local best = {}
			for name, list in data.pets do
				best[name] = Pets.best(list)
			end
			return { eggs = #data.eggs, first = data.eggs[1] and data.eggs[1].a or "", equipped = data.equipped, pets = best, bits = Pets.encode(data.pets), income = Pets.income(data.pets), count = Pets.count(data.pets) }
		elseif action == "Hatch" then
			-- Fait éclore tout de suite tous les œufs. Renvoie leur nombre.
			return Eggs.hatch(player, true)
		elseif action == "Ripen" then
			-- Tous les œufs ont fini de couver (ils écloront tout seuls à la prochaine seconde).
			for _, egg in PlayerData.get(player).eggs do
				egg.t = 0
			end
			PlayerData.changed(player)
		elseif action == "Hatching" then
			-- a = false : les œufs n'éclosent plus tout seuls ; true : ils éclosent de nouveau.
			Eggs.hatchPaused = not a
		elseif action == "Pet" then
			-- Ajoute le familier a de rareté b à la collection et le fait suivre le joueur ("" = aucun ne le suit).
			local data = PlayerData.get(player)
			if a ~= "" then
				Eggs.grant(player, a, b)
			end
			data.equipped = a
			PlayerData.changed(player)
			-- Pour les photos : la rareté montrée derrière le joueur est celle demandée.
			if a ~= "" then
				player:SetAttribute("PetRarity", b)
			end
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

-- PETIT TEST (une trentaine de secondes), sans rejouer tout le jeu.
--   powershell -ExecutionPolicy Bypass -File tools/studio-test/run.ps1 -Test photo -Seconds 40
-- Ici : un œuf posé d'un clic (Eggs.placeNow), et la fenêtre « enclos plein : qui remplacer ? » puis l'échange.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

return function(log)
	local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
	while not player:GetAttribute("Loaded") do
		task.wait(0.1)
	end
	local debug = ServerStorage:WaitForChild("SurviveDebug")
	task.wait(8)
	local function state(): string
		local data = debug:Invoke("Data")
		local pets, eggs, names = 0, 0, {}
		for key, spot in data.spots do
			if spot.v then
				pets += 1
				table.insert(names, key .. "=" .. spot.a)
			else
				eggs += 1
			end
		end
		table.sort(names)
		return "enclos " .. pets .. " (" .. table.concat(names, " ") .. "), œufs qui couvent " .. eggs .. ", œufs au sac " .. data.bag .. ", équipe " .. table.concat(data.team, ",")
	end
	-- Une chèvre épique part au sac, puis l'enclos est rempli (5 places).
	debug:Invoke("Pet", "Goat", 5)
	debug:Invoke("ToBag", 1)
	for _, pet in { { "Duck", 1 }, { "Rooster", 2 }, { "Pig", 3 }, { "Sheep", 4 }, { "Duck", 1 } } do
		debug:Invoke("Pet", pet[1], pet[2])
	end
	debug:Invoke("Egg", 1, 2)
	debug:Invoke("Egg", 1, 1)
	task.wait(1)
	log("Info", "[PHOTO] départ : " .. state())
	log("Info", "[PHOTO] œuf posé d'un clic : " .. tostring(debug:Invoke("EggNow", "Rooster", 2)) .. " → " .. state())
	workspace:SetAttribute("OpenReplace", 1)
	task.wait(2)
	log("Info", "SHOT:photo_remplacer")
	task.wait(1.5)
	log("Info", "[PHOTO] échange (sac 1 ↔ place 1) : " .. tostring(debug:Invoke("Swap", 1, 1)) .. " → " .. state())
	task.wait(1.5)
	workspace:SetAttribute("OpenPanel", "BagPanel")
	task.wait(1.5)
	log("Info", "SHOT:photo_remplacer_apres")
	task.wait(1.2)
	log("Info", "[SURVIVE] TEST:done")
end

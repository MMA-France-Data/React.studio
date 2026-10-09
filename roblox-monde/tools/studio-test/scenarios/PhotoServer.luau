-- PETIT TEST (une trentaine de secondes), sans rejouer tout le jeu.
--   powershell -ExecutionPolicy Bypass -File tools/studio-test/run.ps1 -Test photo -Seconds 30
-- Ici : la vente au vendeur d'un familier de l'ENCLOS (elle plantait), d'un familier de l'ÉQUIPE, et d'un du SAC.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

return function(log)
	local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
	while not player:GetAttribute("Loaded") do
		task.wait(0.1)
	end
	local debug = ServerStorage:WaitForChild("SurviveDebug")
	task.wait(8)
	debug:Invoke("Pet", "Pig", 3)
	debug:Invoke("Pet", "Duck", 1)
	debug:Invoke("Pet", "Sheep", 2)
	debug:Invoke("ToBag", 3)
	task.wait(1)
	local function state(): string
		local data = debug:Invoke("Data")
		local pets = 0
		for _, spot in data.spots do
			if spot.v then
				pets += 1
			end
		end
		return "pièces " .. data.coins .. ", enclos " .. pets .. ", équipe " .. #data.team
	end
	log("Info", "[PHOTO] départ : " .. state())
	local ok1, sold1 = pcall(function()
		return debug:Invoke("SellPen", 2)
	end)
	log("Info", "[PHOTO] vente enclos (canard, place 2) : " .. tostring(ok1) .. " " .. tostring(sold1) .. " → " .. state())
	local ok2, sold2 = pcall(function()
		return debug:Invoke("SellPen", 1)
	end)
	log("Info", "[PHOTO] vente enclos (cochon de l'équipe, place 1) : " .. tostring(ok2) .. " " .. tostring(sold2) .. " → " .. state())
	local ok3, sold3 = pcall(function()
		return debug:Invoke("SellBag", 1)
	end)
	log("Info", "[PHOTO] vente sac (mouton) : " .. tostring(ok3) .. " " .. tostring(sold3) .. " → " .. state())
	log("Info", "[SURVIVE] TEST:done")
end

-- PETIT TEST (une trentaine de secondes), sans rejouer tout le jeu.
--   powershell -ExecutionPolicy Bypass -File tools/studio-test/run.ps1 -Test photo -Seconds 35
-- Ici : la NOTE (C, B, A, S) écrite sur les œufs qui couvent, dans la fenêtre des œufs : elle doit être celle du
-- serveur (elle affichait toujours « A »).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Pets = require(ReplicatedStorage.Shared.Pets)

return function(log)
	local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
	while not player:GetAttribute("Loaded") do
		task.wait(0.1)
	end
	local debug = ServerStorage:WaitForChild("SurviveDebug")
	task.wait(8)
	debug:Invoke("Tuto", 0)
	for _ = 1, 12 do
		debug:Invoke("Egg", 1, 1)
		debug:Invoke("EggNow", "Duck", 1)
	end
	for _ = 1, 3 do
		debug:Invoke("Egg", 1, 2)
	end
	task.wait(1)
	local grades = {}
	for key, spot in debug:Invoke("Data").spots do
		if not spot.v then
			table.insert(grades, Pets.gradeOf(spot))
		end
	end
	table.sort(grades)
	log("Info", "[PHOTO] notes des œufs côté serveur : " .. table.concat(grades, " "))
	workspace:SetAttribute("OpenPanel", "EggPanel")
	task.wait(2)
	log("Info", "SHOT:photo_oeufs_notes")
	task.wait(1.5)
	log("Info", "[SURVIVE] TEST:done")
end

-- PETIT TEST (une quarantaine de secondes), sans rejouer tout le jeu.
--   powershell -ExecutionPolicy Bypass -File tools/studio-test/run.ps1 -Test photo -Seconds 55
-- Ici : le mini tutoriel d'un nouveau joueur, étape par étape (Tutorial.luau), avec une photo de chaque étape.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

return function(log)
	local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
	while not player:GetAttribute("Loaded") do
		task.wait(0.1)
	end
	local debug = ServerStorage:WaitForChild("SurviveDebug")
	task.wait(8)
	local function shot(name: string, what: string)
		task.wait(1.6)
		log("Info", "[PHOTO] " .. what .. " → étape " .. tostring(player:GetAttribute("Tutorial")) .. ", potions " .. tostring(player:GetAttribute("Potions")))
		log("Info", "SHOT:photo_tuto_" .. name)
		task.wait(1.2)
	end
	shot("1", "nouveau joueur")
	debug:Invoke("Level", 2)
	debug:Invoke("Egg", 1, 1)
	shot("2", "un canard battu, un œuf dans le sac")
	debug:Invoke("EggNow", "Duck", 1)
	shot("3", "œuf posé")
	debug:Invoke("Hatch")
	shot("4", "œuf éclos")
	debug:Invoke("Give", 300)
	shot("5", "300 pièces")
	debug:Invoke("Sword", 2)
	shot("6", "épée 2")
	debug:Invoke("Gift", 0)
	debug:Invoke("Claim")
	shot("fin", "cadeau pris")
	log("Info", "[SURVIVE] TEST:done")
end

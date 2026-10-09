-- PETIT TEST EN IMAGES (une trentaine de secondes) : seulement des photos, sans rejouer tout le jeu.
--   powershell -ExecutionPolicy Bypass -File tools/studio-test/run.ps1 -Test photo -Seconds 55
-- Ici : chaque fenêtre du jeu, l'une après l'autre (le sac sur ses deux onglets).
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

return function(log)
	local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
	while not player:GetAttribute("Loaded") do
		task.wait(0.1)
	end
	local debug = ServerStorage:WaitForChild("SurviveDebug")
	task.wait(8)
	debug:Invoke("Potion", "rank", 2)
	debug:Invoke("Potion", "xp", 3)
	debug:Invoke("Pet", "Pig", 3)
	debug:Invoke("Pet", "Duck", 1)
	debug:Invoke("Egg", 1, 2)
	debug:Invoke("Egg", 1, 1)
	debug:Invoke("ToBag", 2)
	debug:Invoke("Give", 50000)
	task.wait(1)
	for _, panel in { "ShopPanel", "BagPanel", "BagPotions", "EggPanel", "PetPanel", "SwordPanel", "SettingsPanel", "SellPanel" } do
		workspace:SetAttribute("OpenPanel", panel)
		task.wait(1.5)
		log("Info", "SHOT:photo_" .. string.lower(panel))
		task.wait(1.2)
	end
	log("Info", "[SURVIVE] TEST:done")
end

-- PETIT TEST EN IMAGES (une trentaine de secondes) : seulement des photos, sans rejouer tout le jeu.
--   powershell -ExecutionPolicy Bypass -File tools/studio-test/run.ps1 -Test photo -Seconds 45
-- Ici : l'écran, la boutique et la fenêtre de l'épée avec beaucoup de pièces (les nombres en court).
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

return function(log)
	local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
	while not player:GetAttribute("Loaded") do
		task.wait(0.1)
	end
	task.wait(8)
	local debug = ServerStorage:WaitForChild("SurviveDebug")
	local function shot(name: string)
		task.wait(1)
		log("Info", "SHOT:photo_" .. name)
		task.wait(1.2)
	end
	debug:Invoke("Pet", "Goat", 5)
	debug:Invoke("Give", 25400)
	debug:Invoke("Sword", 2)
	task.wait(3)
	shot("nombres_ecran")
	for _, panel in { "SwordPanel", "ShopPanel", "PetPanel" } do
		workspace:SetAttribute("OpenPanel", panel)
		shot("nombres_" .. panel)
	end
	workspace:SetAttribute("OpenPanel", "")
	log("Info", "[SURVIVE] TEST:done")
end

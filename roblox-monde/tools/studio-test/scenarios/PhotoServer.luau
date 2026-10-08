-- PETIT TEST EN IMAGES (une trentaine de secondes) : seulement des photos, sans rejouer tout le jeu.
--   powershell -ExecutionPolicy Bypass -File tools/studio-test/run.ps1 -Test photo -Seconds 40
-- Ici : l'écran des téléphones (BASE et pièces tout en haut) et la pastille des œufs. À changer selon le besoin.
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
	workspace:SetAttribute("PhoneHud", true)
	debug:Invoke("Egg", 1, 1)
	shot("tel_oeuf_nouveau")
	workspace:SetAttribute("OpenPanel", "EggPanel")
	task.wait(1)
	workspace:SetAttribute("OpenPanel", "")
	shot("tel_apres_ouverture")
	workspace:SetAttribute("PhoneHud", nil)
	log("Info", "[SURVIVE] TEST:done")
end

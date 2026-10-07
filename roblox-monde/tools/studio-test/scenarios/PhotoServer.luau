-- PETIT TEST EN IMAGES (une trentaine de secondes) : seulement des photos, sans rejouer tout le jeu.
--   powershell -ExecutionPolicy Bypass -File tools/studio-test/run.ps1 -Test photo -Seconds 40
-- Ici : l'écran sur PC, la fenêtre de l'épée, puis l'écran des téléphones. À changer selon le besoin.
local Players = game:GetService("Players")

return function(log)
	local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
	while not player:GetAttribute("Loaded") do
		task.wait(0.1)
	end
	task.wait(8)
	local function shot(name: string)
		task.wait(1)
		log("Info", "SHOT:photo_" .. name)
		task.wait(1.2)
	end
	shot("ecran_pc")
	workspace:SetAttribute("OpenPanel", "SwordPanel")
	shot("epee")
	workspace:SetAttribute("OpenPanel", "")
	workspace:SetAttribute("PhoneHud", true)
	shot("ecran_tel")
	workspace:SetAttribute("PhoneHud", nil)
	log("Info", "[SURVIVE] TEST:done")
end

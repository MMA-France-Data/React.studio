-- PETIT TEST EN IMAGES (une trentaine de secondes) : seulement des photos, sans rejouer tout le jeu.
--   powershell -ExecutionPolicy Bypass -File tools/studio-test/run.ps1 -Test photo -Seconds 40
-- Ici : l'écran avec la roue dentée, puis la fenêtre des réglages (PC et téléphone).
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
	log("Info", "[DIAG] reglages : musique " .. tostring(player:GetAttribute("VolMusic")) .. ", sons " .. tostring(player:GetAttribute("VolFx")))
	shot("reglages_ecran")
	workspace:SetAttribute("OpenPanel", "SettingsPanel")
	shot("reglages_fenetre")
	workspace:SetAttribute("PhoneHud", true)
	shot("reglages_tel")
	workspace:SetAttribute("PhoneHud", nil)
	workspace:SetAttribute("OpenPanel", "")
	log("Info", "[SURVIVE] TEST:done")
end

-- PETIT TEST EN IMAGES (une trentaine de secondes) : seulement des photos, sans rejouer tout le jeu.
--   powershell -ExecutionPolicy Bypass -File tools/studio-test/run.ps1 -Test photo -Seconds 60
-- Ici : les icônes des épées (SwordPalette.icons) dans « Mon épée », la boutique et le bouton du menu, pour
-- plusieurs épées à la suite.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

return function(log)
	local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
	while not player:GetAttribute("Loaded") do
		task.wait(0.1)
	end
	local debug = ServerStorage:WaitForChild("SurviveDebug")
	task.wait(10)
	debug:Invoke("Zone", 5)
	debug:Invoke("Give", 1e12)
	for _, sword in { 1, 3, 5, 7, 10, 13, 15 } do
		debug:Invoke("Sword", sword)
		workspace:SetAttribute("OpenPanel", "SwordPanel")
		task.wait(1.6)
		log("Info", "SHOT:photo_epee_" .. sword)
		task.wait(1.2)
	end
	workspace:SetAttribute("OpenPanel", "ShopPanel")
	task.wait(1.6)
	log("Info", "SHOT:photo_epee_boutique")
	task.wait(1.2)
	log("Info", "[SURVIVE] TEST:done")
end

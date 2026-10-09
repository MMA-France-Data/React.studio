-- PETIT TEST EN IMAGES (une trentaine de secondes) : seulement des photos, sans rejouer tout le jeu.
--   powershell -ExecutionPolicy Bypass -File tools/studio-test/run.ps1 -Test photo -Seconds 40
-- Ici : la fenêtre des cadeaux gratuits (en attente, prêt, après l'avoir pris, sur téléphone).
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

return function(log)
	local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
	while not player:GetAttribute("Loaded") do
		task.wait(0.1)
	end
	local debug = ServerStorage:WaitForChild("SurviveDebug")
	task.wait(8)
	log("Info", "[PHOTO] nouveau joueur : cadeau dans " .. tostring(player:GetAttribute("GiftIn")) .. " s")
	workspace:SetAttribute("OpenPanel", "GiftPanel")
	task.wait(1.5)
	log("Info", "SHOT:photo_cadeaux_attente")
	task.wait(1.5)
	debug:Invoke("Gift", 0)
	task.wait(1)
	log("Info", "SHOT:photo_cadeaux_pret")
	task.wait(1.5)
	log("Info", "[PHOTO] pris : " .. tostring(debug:Invoke("Claim")) .. ", prochain dans " .. tostring(player:GetAttribute("GiftIn")) .. " s")
	task.wait(1.5)
	log("Info", "SHOT:photo_cadeaux_pris")
	task.wait(1.5)
	log("Info", "[SURVIVE] TEST:done")
end

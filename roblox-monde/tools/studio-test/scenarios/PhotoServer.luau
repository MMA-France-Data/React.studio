-- PETIT TEST EN IMAGES (une trentaine de secondes) : seulement des photos, sans rejouer tout le jeu.
--   powershell -ExecutionPolicy Bypass -File tools\studio-test\run.ps1 -Test photo -Seconds 45
-- Ici : les epees 4, 5 et 6 (glace, feu, foudre) dans la main, pour voir leurs auras. A changer selon le besoin.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

return function(log)
	local debug = ServerStorage:WaitForChild("SurviveDebug", 30)
	local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
	while not player:GetAttribute("Loaded") do
		task.wait(0.1)
	end
	task.wait(3)
	for _, sword in { 4, 5, 6 } do
		debug:Invoke("Sword", sword)
		task.wait(2.5)
		local root = player.Character.HumanoidRootPart.Position
		workspace:SetAttribute("ShotCam", CFrame.lookAt(root + Vector3.new(9, 5, -6), root + Vector3.new(0, 4, -1)))
		task.wait(0.9)
		workspace:SetAttribute("Diag", sword)
		log("Info", "SHOT:photo_aura_" .. sword)
		task.wait(1.2)
	end
	workspace:SetAttribute("ShotCam", nil)
	log("Info", "[SURVIVE] TEST:done")
end

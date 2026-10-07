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
	-- Le stand des epees, contre le mur de la grande porte.
	workspace:SetAttribute("ShotCam", CFrame.lookAt(Vector3.new(-2, 8, 2), Vector3.new(-16, 6, 26)))
	task.wait(0.9)
	log("Info", "SHOT:photo_stand")
	task.wait(1.2)
	workspace:SetAttribute("ShotCam", CFrame.lookAt(Vector3.new(2, 8, 2), Vector3.new(16, 6, 26)))
	task.wait(0.9)
	log("Info", "SHOT:photo_stand_vente")
	task.wait(1.2)
	workspace:SetAttribute("ShotCam", CFrame.lookAt(Vector3.new(0, 14, -14), Vector3.new(0, 7, 28)))
	task.wait(0.9)
	log("Info", "SHOT:photo_porte")
	task.wait(1.2)
	for _, sword in {} do
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

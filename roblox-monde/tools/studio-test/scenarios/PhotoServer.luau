-- PETIT TEST EN IMAGES (une trentaine de secondes) : seulement des photos, sans rejouer tout le jeu.
--   powershell -ExecutionPolicy Bypass -File tools/studio-test/run.ps1 -Test photo -Seconds 35
-- Ici : la banderole « tu gagnes des pièces hors ligne » au-dessus de l'allée de la base.
local Players = game:GetService("Players")

return function(log)
	local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
	while not player:GetAttribute("Loaded") do
		task.wait(0.1)
	end
	task.wait(8)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = CFrame.new(0, 4, -100)
	end
	task.wait(1)
	workspace:SetAttribute("ShotCam", CFrame.lookAt(Vector3.new(0, 9, -100), Vector3.new(0, 14, -52)))
	task.wait(1)
	log("Info", "SHOT:photo_banderole")
	task.wait(1.5)
	workspace:SetAttribute("ShotCam", nil)
	log("Info", "[SURVIVE] TEST:done")
end

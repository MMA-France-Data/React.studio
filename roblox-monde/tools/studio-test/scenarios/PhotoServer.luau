-- PETIT TEST EN IMAGES (une trentaine de secondes) : seulement des photos, sans rejouer tout le jeu.
--   powershell -ExecutionPolicy Bypass -File tools/studio-test/run.ps1 -Test photo -Seconds 40
-- Ici : les trois familiers de l'équipe derrière le joueur, pour juger leur taille. À changer selon le besoin.
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
	debug:Invoke("Pet", "Pig", 3)
	debug:Invoke("Pet", "Goat", 5)
	debug:Invoke("Pet", "Wolf", 5)
	debug:Invoke("Zone", 1)
	debug:Invoke("Peaceful", true)
	debug:Invoke("Travel", 1)
	task.wait(4)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then
		local at = root.Position
		workspace:SetAttribute("ShotCam", CFrame.lookAt(at + root.CFrame.LookVector * 20 + Vector3.new(6, 8, 0), at + Vector3.new(0, 2, 0) - root.CFrame.LookVector * 4))
		shot("equipe_face")
		workspace:SetAttribute("ShotCam", CFrame.lookAt(at - root.CFrame.LookVector * 26 + Vector3.new(0, 10, 0), at + Vector3.new(0, 2, 0)))
		shot("equipe_dos")
	end
	workspace:SetAttribute("ShotCam", nil)
	log("Info", "[SURVIVE] TEST:done")
end

-- PETIT TEST EN IMAGES (une trentaine de secondes) : seulement des photos, sans rejouer tout le jeu.
--   powershell -ExecutionPolicy Bypass -File tools/studio-test/run.ps1 -Test photo -Seconds 40
-- Ici : la nouvelle épée or (épée 3) dans la main, de face et de côté. À changer selon le besoin.
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
	local function look(side: number)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			local at = root.Position
			workspace:SetAttribute("ShotCam", CFrame.lookAt(at + root.CFrame.LookVector * 11 + root.CFrame.RightVector * side + Vector3.new(0, 3, 0), at + Vector3.new(0, 3, 0)))
		end
	end
	debug:Invoke("Sword", 3)
	task.wait(2.5)
	look(0)
	shot("or_face")
	look(8)
	shot("or_cote")
	workspace:SetAttribute("ShotCam", nil)
	workspace:SetAttribute("OpenPanel", "SwordPanel")
	shot("or_fenetre")
	log("Info", "[SURVIVE] TEST:done")
end

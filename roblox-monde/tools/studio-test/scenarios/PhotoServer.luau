-- PETIT TEST EN IMAGES (une trentaine de secondes) : seulement des photos, sans rejouer tout le jeu.
--   powershell -ExecutionPolicy Bypass -File tools/studio-test/run.ps1 -Test photo -Seconds 40
-- Ici : les épées 7 (feu et glace) et 8 (doubles lames violettes) dans la main. À changer selon le besoin.
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
			local front = root.CFrame.LookVector
			local right = root.CFrame.RightVector
			workspace:SetAttribute("ShotCam", CFrame.lookAt(at + front * 13 + right * side + Vector3.new(0, 3, 0), at + Vector3.new(0, 2.5, 0)))
		end
	end
	for _, tier in { 7, 8 } do
		debug:Invoke("Sword", tier)
		task.wait(2.5)
		look(0)
		shot("epee" .. tier .. "_face")
		workspace:SetAttribute("Diag", os.clock())
		look(9)
		shot("epee" .. tier .. "_cote")
	end
	workspace:SetAttribute("ShotCam", nil)
	workspace:SetAttribute("OpenPanel", "SwordPanel")
	shot("fenetre")
	log("Info", "[SURVIVE] TEST:done")
end

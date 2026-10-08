-- PETIT TEST EN IMAGES (une trentaine de secondes) : seulement des photos, sans rejouer tout le jeu.
--   powershell -ExecutionPolicy Bypass -File tools/studio-test/run.ps1 -Test photo -Seconds 60
-- Ici : quelques épées (TIERS) dans la main, de face et de côté. À changer selon le besoin.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local TIERS = { 11, 14, 15, 16 }

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
			workspace:SetAttribute("ShotCam", CFrame.lookAt(at + root.CFrame.LookVector * 13 + root.CFrame.RightVector * side + Vector3.new(0, 4, 0), at + Vector3.new(0, 3.5, 0)))
		end
	end
	for _, tier in TIERS do
		debug:Invoke("Sword", tier)
		task.wait(2.5)
		look(0)
		shot("epee" .. tier .. "_face")
		look(10)
		shot("epee" .. tier .. "_cote")
	end
	workspace:SetAttribute("ShotCam", nil)
	log("Info", "[SURVIVE] TEST:done")
end

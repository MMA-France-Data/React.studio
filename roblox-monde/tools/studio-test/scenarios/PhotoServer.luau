-- PETIT TEST EN IMAGES (une trentaine de secondes) : seulement des photos, sans rejouer tout le jeu.
--   powershell -ExecutionPolicy Bypass -File tools/studio-test/run.ps1 -Test photo -Seconds 45
-- Ici : les nouveaux animaux du monde 2 (sanglier, loup, ours...), un camp après l'autre. À changer selon le besoin.
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
	debug:Invoke("Zone", 2)
	debug:Invoke("Peaceful", true)
	debug:Invoke("Travel", 2)
	task.wait(2)
	local seen = {}
	for _, monster in debug:Invoke("Monsters") do
		if monster.zone == 2 and not seen[monster.rank] then
			seen[monster.rank] = monster
		end
	end
	for rank = 1, 6 do
		local monster = seen[rank]
		if monster then
			local at = monster.position
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root then
				root.CFrame = CFrame.new(at + Vector3.new(0, 4, -40))
			end
			task.wait(1.5)
			workspace:SetAttribute("ShotCam", CFrame.lookAt(at + Vector3.new(6, 7, -16), at + Vector3.new(0, 2.5, 0)))
			shot("monde2_" .. rank .. "_" .. monster.animal)
		end
	end
	workspace:SetAttribute("ShotCam", nil)
	log("Info", "[SURVIVE] TEST:done")
end

-- PETIT TEST EN IMAGES (une trentaine de secondes) : seulement des photos, sans rejouer tout le jeu.
--   powershell -ExecutionPolicy Bypass -File tools/studio-test/run.ps1 -Test photo -Seconds 70
-- Ici : quelques animaux choisis (LIST : { monde, camp }), photographiés de côté, pour juger leur assemblage.
-- À changer selon le besoin.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local LIST = { { 1, 1 }, { 1, 2 }, { 1, 3 }, { 1, 4 }, { 1, 5 }, { 1, 6 }, { 3, 5 }, { 3, 6 } }

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
	debug:Invoke("Zone", 4)
	debug:Invoke("Peaceful", true)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local zone = 0
	for _, pick in LIST do
		if pick[1] ~= zone then
			zone = pick[1]
			debug:Invoke("Travel", zone)
			task.wait(2)
		end
		local monster
		for _, item in debug:Invoke("Monsters") do
			if item.zone == pick[1] and item.rank == pick[2] then
				monster = item
				break
			end
		end
		if monster then
			local at = monster.position
			if root then
				root.CFrame = CFrame.new(at + Vector3.new(0, 4, -45))
			end
			task.wait(1.5)
			local far = if pick[2] == 6 then 3.2 else 1.9
			workspace:SetAttribute("ShotCam", CFrame.lookAt(at + Vector3.new(7, 2.5, -4) * far, at + Vector3.new(0, 1.1 * far, 0)))
			shot("pres_" .. monster.animal)
		end
	end
	workspace:SetAttribute("ShotCam", nil)
	log("Info", "[SURVIVE] TEST:done")
end

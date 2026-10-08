-- PETIT TEST EN IMAGES (une trentaine de secondes) : seulement des photos, sans rejouer tout le jeu.
--   powershell -ExecutionPolicy Bypass -File tools/studio-test/run.ps1 -Test photo -Seconds 55
-- Ici : les animaux d'un monde (ZONE), un camp après l'autre, puis la zone vue d'en haut. À changer selon le besoin.
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
	local ZONE = 4
	debug:Invoke("Zone", ZONE)
	debug:Invoke("Peaceful", true)
	debug:Invoke("Travel", ZONE)
	task.wait(2)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local entry = if root then root.Position else Vector3.zero
	local seen = {}
	for _, monster in debug:Invoke("Monsters") do
		if monster.zone == ZONE and not seen[monster.rank] then
			seen[monster.rank] = monster
		end
	end
	for rank = 1, 6 do
		local monster = seen[rank]
		if monster then
			local at = monster.position
			if root then
				root.CFrame = CFrame.new(at + Vector3.new(0, 4, -40))
			end
			task.wait(1.5)
			workspace:SetAttribute("ShotCam", CFrame.lookAt(at + Vector3.new(7, 8, -19), at + Vector3.new(0, 3, 0)))
			shot("monde" .. ZONE .. "_" .. rank .. "_" .. monster.animal)
		end
	end
	if root then
		root.CFrame = CFrame.new(entry + Vector3.new(0, 3, 100))
	end
	task.wait(1.5)
	workspace:SetAttribute("ShotCam", CFrame.lookAt(entry + Vector3.new(-150, 120, -30), entry + Vector3.new(0, 0, 140)))
	shot("monde" .. ZONE .. "_haut")
	workspace:SetAttribute("ShotCam", nil)
	log("Info", "[SURVIVE] TEST:done")
end

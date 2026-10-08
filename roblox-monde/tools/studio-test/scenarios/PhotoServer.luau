-- PETIT TEST EN IMAGES : seulement des photos, sans rejouer tout le jeu.
--   powershell -ExecutionPolicy Bypass -File tools/studio-test/run.ps1 -Test photo -Seconds 70
-- Ici : chaque camp d'un monde (ZONES) vu d'en haut, avec son décor et ses animaux, puis le coin du boss.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local ZONES = { 5 }

return function(log)
	local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
	while not player:GetAttribute("Loaded") do
		task.wait(0.1)
	end
	task.wait(8)
	local debug = ServerStorage:WaitForChild("SurviveDebug")
	local function shot(name: string)
		task.wait(0.8)
		log("Info", "SHOT:photo_" .. name)
		task.wait(1.1)
	end
	debug:Invoke("Zone", 5)
	debug:Invoke("Peaceful", true)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	for _, zone in ZONES do
		debug:Invoke("Travel", zone)
		task.wait(2)
		local sums, counts, animals = {}, {}, {}
		for _, monster in debug:Invoke("Monsters") do
			if monster.zone == zone then
				sums[monster.rank] = (sums[monster.rank] or Vector3.zero) + monster.position
				counts[monster.rank] = (counts[monster.rank] or 0) + 1
				animals[monster.rank] = monster.animal
			end
		end
		for rank = 1, 6 do
			if counts[rank] then
				local at = sums[rank] / counts[rank]
				local side = if at.X > 0 then -1 else 1
				if root then
					root.CFrame = CFrame.new(at + Vector3.new(side * 70, 5, -30))
				end
				task.wait(1.2)
				workspace:SetAttribute("ShotCam", CFrame.lookAt(at + Vector3.new(side * 30, 18, -24), at + Vector3.new(0, 3, 0)))
				shot("camp_" .. zone .. "_" .. rank .. "_" .. animals[rank])
			end
		end
	end
	workspace:SetAttribute("ShotCam", nil)
	log("Info", "[SURVIVE] TEST:done")
end

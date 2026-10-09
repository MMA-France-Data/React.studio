-- PETIT TEST EN IMAGES (une trentaine de secondes) : seulement des photos, sans rejouer tout le jeu.
--   powershell -ExecutionPolicy Bypass -File tools/studio-test/run.ps1 -Test photo -Seconds 45
-- Ici : un monstre meurt, ses pièces tombent, attendent, puis filent vers le joueur (trois photos de suite).
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

return function(log)
	local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
	while not player:GetAttribute("Loaded") do
		task.wait(0.1)
	end
	task.wait(8)
	local debug = ServerStorage:WaitForChild("SurviveDebug")
	debug:Invoke("Peaceful", true)
	debug:Invoke("Travel", 1)
	task.wait(2)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local target
	for _, monster in debug:Invoke("Monsters") do
		if monster.zone == 1 and monster.rank == 1 then
			target = monster
			break
		end
	end
	root.CFrame = CFrame.new(target.position + Vector3.new(-12, 3, 0))
	task.wait(1)
	workspace:SetAttribute("ShotCam", CFrame.lookAt(target.position + Vector3.new(-6, 12, -22), target.position + Vector3.new(-6, 1, 0)))
	task.wait(1)
	for index, wait in { 0.75, 1.12, 1.22 } do
		for _, monster in debug:Invoke("Monsters") do
			if monster.zone == 1 and monster.rank == 1 and not monster.dead then
				target = monster
				break
			end
		end
		root.CFrame = CFrame.new(target.position + Vector3.new(-12, 3, 0))
		workspace:SetAttribute("ShotCam", CFrame.lookAt(target.position + Vector3.new(-6, 12, -22), target.position + Vector3.new(-6, 1, 0)))
		task.wait(1.5)
		debug:Invoke("Hurt", target.id, 1e9)
		task.wait(wait)
		log("Info", "SHOT:photo_pieces" .. index)
		task.wait(2.5)
	end
	workspace:SetAttribute("ShotCam", nil)
	log("Info", "[SURVIVE] TEST:done")
end

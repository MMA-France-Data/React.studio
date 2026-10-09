-- PETIT TEST EN IMAGES (une trentaine de secondes) : seulement des photos, sans rejouer tout le jeu.
--   powershell -ExecutionPolicy Bypass -File tools/studio-test/run.ps1 -Test photo -Seconds 40
-- Ici : le panneau de l'espace du joueur, avec la vignette de son propriétaire, et un espace libre à côté.
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
	local plot = debug:Invoke("Plot")
	local origin: Vector3 = plot.origin
	local side = if origin.X > 0 then 1 else -1
	local sign = origin + Vector3.new(-side * 34, 14, 0)
	workspace:SetAttribute("ShotCam", CFrame.lookAt(sign + Vector3.new(-side * 30, 2, 0), sign))
	shot("espace_vignette")
	workspace:SetAttribute("ShotCam", CFrame.lookAt(Vector3.new(0, 18, origin.Z + 60), Vector3.new(0, 10, origin.Z - 60)))
	shot("espace_allee")
	workspace:SetAttribute("ShotCam", nil)
	log("Info", "[SURVIVE] TEST:done")
end

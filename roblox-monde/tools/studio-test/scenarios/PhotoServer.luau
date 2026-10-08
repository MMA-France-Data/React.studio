-- PETIT TEST EN IMAGES (une trentaine de secondes) : seulement des photos, sans rejouer tout le jeu.
--   powershell -ExecutionPolicy Bypass -File tools/studio-test/run.ps1 -Test photo -Seconds 45
-- Ici : l'enclos plein de familiers (un de chaque animal de la ferme, et deux gros du monde 2), pour juger leur
-- taille. À changer selon le besoin.
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
	for rank, animal in { "Duck", "Rooster", "Pig", "Sheep", "Goat", "Horse" } do
		debug:Invoke("Pet", animal, rank)
	end
	debug:Invoke("Pet", "Wolf", 5)
	debug:Invoke("Pet", "Bear", 6)
	task.wait(6)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local plot = debug:Invoke("Plot")
	local origin = if typeof(plot) == "table" and plot.origin then plot.origin elseif root then root.Position else Vector3.zero
	if root then
		root.CFrame = CFrame.new(origin + Vector3.new(10, 3, 0))
	end
	task.wait(1)
	workspace:SetAttribute("ShotCam", CFrame.lookAt(origin + Vector3.new(10, 22, -22), origin + Vector3.new(10, 2, 16)))
	shot("enclos_haut")
	workspace:SetAttribute("ShotCam", CFrame.lookAt(origin + Vector3.new(-14, 7, 2), origin + Vector3.new(12, 3, 18)))
	shot("enclos_pres")
	workspace:SetAttribute("ShotCam", nil)
	log("Info", "[SURVIVE] TEST:done")
end

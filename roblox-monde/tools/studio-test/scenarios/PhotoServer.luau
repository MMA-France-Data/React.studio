-- PETIT TEST EN IMAGES (une trentaine de secondes) : seulement des photos, sans rejouer tout le jeu.
--   powershell -ExecutionPolicy Bypass -File tools/studio-test/run.ps1 -Test photo -Seconds 45
-- Ici : le décor d'une zone (attribut de test : mettre le thème voulu sur la zone 3 dans Config le temps de la
-- photo), vu de l'entrée, d'en haut et de près. À changer selon le besoin.
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
	local ZONE = 3
	debug:Invoke("Zone", ZONE)
	debug:Invoke("Peaceful", true)
	debug:Invoke("Travel", ZONE)
	task.wait(2.5)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local at = if root then root.Position else Vector3.zero
	-- (L'entrée de la zone : le joueur y arrive, la zone s'étend vers les Z qui montent.)
	local views = {
		entree = { Vector3.new(0, 16, -6), Vector3.new(0, 4, 90) },
		haut = { Vector3.new(-150, 120, -30), Vector3.new(0, 0, 140) },
		eau = { Vector3.new(30, 14, 60), Vector3.new(78, 2, 86) },
		baobab = { Vector3.new(-50, 12, 30), Vector3.new(-100, 10, 58) },
	}
	for _, name in { "entree", "haut", "eau", "baobab" } do
		local view = views[name]
		if root then
			root.CFrame = CFrame.new(at + view[1] * Vector3.new(1, 0, 1) + Vector3.new(0, 3, 0))
		end
		task.wait(1)
		workspace:SetAttribute("ShotCam", CFrame.lookAt(at + view[1], at + view[2]))
		shot("decor_" .. name)
	end
	workspace:SetAttribute("ShotCam", nil)
	log("Info", "[SURVIVE] TEST:done")
end

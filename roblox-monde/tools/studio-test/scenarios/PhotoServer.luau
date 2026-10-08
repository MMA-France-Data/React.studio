-- PETIT TEST EN IMAGES : seulement des photos, sans rejouer tout le jeu.
--   powershell -ExecutionPolicy Bypass -File tools/studio-test/run.ps1 -Test photo -Seconds 60
-- Ici : le décor d'une zone (ZONE) : vue d'en haut, de l'entrée, et de chaque camp. Pour un thème pas encore en
-- jeu, le mettre sur la zone le temps de la photo (Config.ZONES) et donner aux camps les habitats voulus
-- (attribut de test « Habitats » : voir Zones.luau).
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local ZONE = 4
local CAMPS = { { -52, 48 }, { 56, 92 }, { -60, 138 }, { 58, 184 }, { -50, 226 }, { 50, 258 } }

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
	debug:Invoke("Zone", ZONE)
	debug:Invoke("Peaceful", true)
	debug:Invoke("Travel", ZONE)
	task.wait(2.5)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local entry = if root then root.Position else Vector3.zero
	local zMin = entry.Z - 10
	local function view(name: string, from: Vector3, to: Vector3)
		if root then
			root.CFrame = CFrame.new(Vector3.new(from.X, 6, from.Z))
		end
		task.wait(1.2)
		workspace:SetAttribute("ShotCam", CFrame.lookAt(from, to))
		shot("dino_" .. name)
	end
	view("haut", Vector3.new(-150, 130, zMin - 20), Vector3.new(0, 0, zMin + 150))
	view("entree", Vector3.new(0, 14, zMin + 4), Vector3.new(10, 6, zMin + 90))
	view("volcan", Vector3.new(30, 30, zMin + 10), Vector3.new(108, 20, zMin + 40))
	for index, camp in CAMPS do
		local at = Vector3.new(camp[1], 0, zMin + camp[2])
		local side = if camp[1] > 0 then -1 else 1
		view("camp" .. index, at + Vector3.new(side * 44, 34, -30), at + Vector3.new(0, 2, 0))
	end
	workspace:SetAttribute("ShotCam", nil)
	log("Info", "[SURVIVE] TEST:done")
end

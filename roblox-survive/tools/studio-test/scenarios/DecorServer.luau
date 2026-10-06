-- Petit test en images : les décors (lobby, espace d'un joueur, couloir, salles), la chance des familiers à l'écran,
-- et les machines qui démarrent quand on marche dessus.
--   powershell -ExecutionPolicy Bypass -File tools\studio-test\run.ps1 -Test decor -Seconds 120
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

return function(log)
	local debug = ServerStorage:WaitForChild("SurviveDebug", 30)
	local function D(...)
		return debug:Invoke(...)
	end
	local function check(condition, name, detail)
		log("Info", (if condition then "[PASS] " else "[FAIL] ") .. name .. (if detail then "  (" .. tostring(detail) .. ")" else ""))
	end
	local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
	while not player:GetAttribute("Loaded") do
		task.wait(0.1)
	end
	D("Cycle", "pause")
	D("Income", false)
	D("Hatching", false)
	local function shot(name: string, from: Vector3?, target: Vector3?)
		if from and target then
			workspace:SetAttribute("ShotCam", CFrame.lookAt(from, target))
		end
		task.wait(0.9)
		log("Info", "SHOT:decor_" .. name)
		task.wait(1.2)
		workspace:SetAttribute("ShotCam", nil)
	end
	task.wait(2)
	local origin = D("Plot").origin

	-- 1. LES MACHINES : marcher dessus suffit.
	for _, case in { { "Speed", Vector3.new(-22, 4, -18) }, { "Force", Vector3.new(22, 4, -14) }, { "Jump", Vector3.new(0, 4, -11) } } do
		player.Character:PivotTo(CFrame.new(origin + case[2]))
		task.wait(0.8)
		check(player:GetAttribute("Workout") == case[1], "marcher sur la machine la met en route : " .. case[1], player:GetAttribute("Workout"))
		D("Stop")
		task.wait(0.8)
		check((player:GetAttribute("Workout") or "") == "", "en descendre ne la relance pas : " .. case[1], player:GetAttribute("Workout"))
	end
	player.Character:PivotTo(CFrame.new(origin + Vector3.new(-13, 4, -3)))

	-- 2. LA CHANCE : sans familier, puis avec un familier qui suit, et la fenêtre des familiers.
	local function face()
		local root = player.Character.HumanoidRootPart.Position
		return root + Vector3.new(-6, 5, -12), root + Vector3.new(0, 2.5, 0)
	end
	local from, target = face()
	shot("chance_0", from, target)
	D("Pet", "Bunny", 1)
	D("Pet", "Dog", 4)
	D("Pet", "Fox", 6)
	check((player:GetAttribute("PetLuck") or 0) >= 50, "le renard qui suit donne sa chance", player:GetAttribute("PetLuck"))
	workspace:SetAttribute("OpenPets", true)
	shot("chance_liste", from, target)
	workspace:SetAttribute("OpenPets", false)
	task.wait(0.3)

	-- 3. LES DÉCORS.
	shot("lobby_haut", Vector3.new(0, 95, -175), Vector3.new(0, 0, -50))
	shot("lobby_allee", Vector3.new(4, 12, -140), Vector3.new(0, 8, 30))
	shot("lobby_porte", Vector3.new(-6, 8, -22), Vector3.new(0, 8, 30))
	shot("espace", origin + Vector3.new(0, 26, -52), origin + Vector3.new(0, 2, 4))
	shot("espace_enclos", origin + Vector3.new(-18, 9, -4), origin + Vector3.new(12, 2, 16))
	shot("couloir", Vector3.new(0, 7, 33), Vector3.new(0, 8, 60))
	for room = 1, 5 do
		local z = 50 + (room - 1) * 100
		player.Character:PivotTo(CFrame.new(0, 4, z - 10))
		shot("salle" .. room, Vector3.new(-28, 26, z + 4), Vector3.new(6, 4, z + 46))
	end
	log("Info", "[SURVIVE] TEST:done")
end

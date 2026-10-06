-- Petit test en images : la taille des œufs et des familiers selon leur valeur.
--   powershell -ExecutionPolicy Bypass -File tools\studio-test\run.ps1 -Test eggs -Seconds 90
-- Pose dans l'enclos trois œufs de lapin et trois œufs de renard (valeur tout en bas, au milieu, tout en haut de leur
-- palier), les photographie, puis les fait éclore et photographie les familiers.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

return function(log)
	local debug = ServerStorage:WaitForChild("SurviveDebug", 30)
	local function D(...)
		return debug:Invoke(...)
	end
	local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
	while not player:GetAttribute("Loaded") do
		task.wait(0.1)
	end
	D("Cycle", "pause")
	D("Income", false)
	D("Hatching", false)
	local function shot(name: string, from: Vector3, target: Vector3)
		workspace:SetAttribute("ShotCam", CFrame.lookAt(from, target))
		task.wait(0.8)
		log("Info", "SHOT:eggs_" .. name)
		task.wait(1.2)
		workspace:SetAttribute("ShotCam", nil)
	end
	task.wait(2)
	local plot = D("Plot")
	local origin = plot.origin
	-- Le joueur se met à l'écart, hors du champ.
	player.Character:PivotTo(CFrame.new(origin + Vector3.new(-14, 4, -8)))

	-- Six œufs : lapin (commun) devant, renard (super rare) derrière ; de gauche à droite : le pire, le moyen, le meilleur.
	D("Give", 1e9)
	D("Upgrade")
	D("Upgrade")
	local placed = 0
	for row, animal in { { "Bunny", 1, 8 }, { "Fox", 6, 20 } } do
		for column, along in { 0, 0.5, 1 } do
			D("Egg", animal[1], animal[2], along)
			if D("Place", 3 + (column - 1) * 9, animal[3]) == true then
				placed += 1
			end
		end
	end
	log("Info", (if placed == 6 then "[PASS] " else "[FAIL] ") .. "six œufs posés (lapin et renard ; pire, moyen, meilleur)  (" .. placed .. ")")
	task.wait(1.5)
	shot("oeufs", origin + Vector3.new(12, 13, -9), origin + Vector3.new(12, 2, 14))
	shot("oeufs_pres", origin + Vector3.new(12, 6, -2), origin + Vector3.new(12, 2, 10))
	-- Un œuf sur la tête : le meilleur renard.
	D("Egg", "Fox", 6, 1)
	player.Character:PivotTo(CFrame.new(origin + Vector3.new(12, 4, -6), origin + Vector3.new(12, 4, -30)))
	task.wait(1.5)
	shot("oeuf_porte", origin + Vector3.new(12, 6, -18), origin + Vector3.new(12, 6, -6))
	player.Character:PivotTo(CFrame.new(origin + Vector3.new(-14, 4, -8)))
	-- Éclosion : les six familiers.
	local hatched = D("Hatch")
	log("Info", (if hatched == 6 then "[PASS] " else "[FAIL] ") .. "les six œufs éclosent  (" .. tostring(hatched) .. ")")
	task.wait(1.2)
	shot("familiers", origin + Vector3.new(12, 13, -9), origin + Vector3.new(12, 2, 14))
	task.wait(3)
	shot("familiers_2", origin + Vector3.new(12, 16, -12), origin + Vector3.new(12, 2, 16))
	log("Info", "[SURVIVE] TEST:done")
end

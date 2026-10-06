-- Petit test en images : les gestes des bras (porter un œuf, porter un familier, frapper, soulever la barre).
--   powershell -ExecutionPolicy Bypass -File tools\studio-test\run.ps1 -Test poses -Seconds 90
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
	local function shot(name: string, from: Vector3, target: Vector3)
		workspace:SetAttribute("ShotCam", CFrame.lookAt(from, target))
		task.wait(0.8)
		log("Info", "SHOT:poses_" .. name)
		task.wait(1.2)
		workspace:SetAttribute("ShotCam", nil)
	end
	task.wait(2)
	local origin = D("Plot").origin
	-- Au milieu de l'enclos (de l'herbe, rien devant) ; la caméra est devant le joueur, de trois quarts.
	local stand = origin + Vector3.new(10, 4, 18)
	local function face()
		player.Character:PivotTo(CFrame.lookAt(stand, stand + Vector3.new(0, 0, -1)))
		task.wait(0.8)
		local root = player.Character.HumanoidRootPart.Position
		return root + Vector3.new(-5, 3, -9), root + Vector3.new(0, 2.5, 0)
	end

	-- 1. Porter un œuf.
	D("Egg", "Bunny", 1, 0.5)
	local from, target = face()
	shot("oeuf", from, target)
	D("EmptyBag")

	-- 2. Porter un familier pour aller le vendre, puis le vendre au stand.
	D("Pet", "Dog", 4)
	D("Pet", "")
	check(D("Hold", 1) == true and player:GetAttribute("Held") == "1" and string.match(player:GetAttribute("HeldPet") or "", "^Dog:4:%d+$") ~= nil, "prendre un familier dans ses bras", player:GetAttribute("HeldPet"))
	from, target = face()
	shot("familier", from, target)
	local coins = D("Data").coins
	check(D("SellHeld") == true and D("Data").coins > coins and player:GetAttribute("Held") == "" and D("Eggs").pets == 0, "au stand, le familier porté est vendu", D("Data").coins - coins)
	check(D("SellHeld") == false, "sans familier dans les bras, rien à vendre")
	D("Pet", "Dog", 4)
	D("Pet", "")
	D("Hold", 1)
	check(D("Hold", 1) == true and player:GetAttribute("Held") == "" and D("Eggs").pets == 1, "un 2e appui repose le familier dans l'enclos")

	-- 3. Frapper : le poing part à chaque appui (on en donne plusieurs pour la photo).
	-- (Le chien reposé dans l'enclos cacherait le joueur : on le vend d'abord.)
	D("Hold", 1)
	D("SellHeld")
	task.wait(0.5)
	from, target = face()
	local punching = true
	task.spawn(function()
		while punching do
			player:SetAttribute("PunchAt", workspace:GetServerTimeNow() - 0.14)
			task.wait(0.05)
		end
	end)
	shot("frappe", from, target)
	punching = false

	-- 4. Soulever la barre sur le banc de force.
	check(D("Train", "Force") == true, "le joueur monte sur le banc de force")
	task.wait(1)
	local root = player.Character.HumanoidRootPart.Position
	shot("banc", root + Vector3.new(-4, 5, -3), root + Vector3.new(0, 1, 0))
	task.wait(0.3)
	shot("banc_2", root + Vector3.new(3, 6, 4), root + Vector3.new(0, 1, 0))
	D("Stop")
	log("Info", "[SURVIVE] TEST:done")
end

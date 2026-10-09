-- PETIT TEST EN IMAGES (une trentaine de secondes) : seulement des photos, sans rejouer tout le jeu.
--   powershell -ExecutionPolicy Bypass -File tools/studio-test/run.ps1 -Test photo -Seconds 60
-- Ici : une épée (TIER) de très près, des deux côtés, au repos puis pendant des coups (le joueur est posé devant un
-- monstre et frappe). À changer selon le besoin.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local TIER = 11

return function(log)
	local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
	while not player:GetAttribute("Loaded") do
		task.wait(0.1)
	end
	task.wait(8)
	local debug = ServerStorage:WaitForChild("SurviveDebug")
	local function shot(name: string, wait: number?)
		task.wait(wait or 1)
		log("Info", "SHOT:photo_" .. name)
		task.wait(1.2)
	end
	debug:Invoke("Sword", TIER)
	task.wait(3)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local function look(offset: Vector3, target: Vector3)
		local frame = root.CFrame
		workspace:SetAttribute("ShotCam", CFrame.lookAt(frame:PointToWorldSpace(offset), frame:PointToWorldSpace(target)))
	end
	-- L'épée est dans la main droite, pointe vers le ciel : à droite du joueur, au-dessus de sa tête.
	-- (L'épée se tient de profil : ses deux faces regardent à gauche et à droite du joueur.)
	look(Vector3.new(-9, 5, 0), Vector3.new(1.5, 5, 0))
	shot("tigre_face_gauche")
	look(Vector3.new(11, 5, 0), Vector3.new(1.5, 5, 0))
	shot("tigre_face_droite")
	look(Vector3.new(-3.2, 2.4, -0.4), Vector3.new(1.5, 2.4, -0.4))
	shot("tigre_crane")
	look(Vector3.new(-5, 6.5, -0.5), Vector3.new(1.5, 6.5, -0.5))
	shot("tigre_lame")
	-- Des coups : un canard à côté, et on frappe.
	debug:Invoke("Zone", 5)
	debug:Invoke("Peaceful", true)
	debug:Invoke("Travel", 5)
	task.wait(2)
	local target
	for _, monster in debug:Invoke("Monsters") do
		if monster.zone == 5 and monster.rank == 6 then
			target = monster
		end
	end
	if target and root then
		root.CFrame = CFrame.lookAt(target.position + Vector3.new(0, 3, -9), target.position + Vector3.new(0, 3, 0))
		task.wait(1)
		look(Vector3.new(-11, 5, -2), Vector3.new(0, 4, -2))
		for index = 1, 4 do
			debug:Invoke("Attack")
			task.wait(0.12 + index * 0.05)
			log("Info", "SHOT:photo_tigre_coup" .. index)
			task.wait(1.1)
		end
	end
	workspace:SetAttribute("ShotCam", nil)
	log("Info", "[SURVIVE] TEST:done")
end

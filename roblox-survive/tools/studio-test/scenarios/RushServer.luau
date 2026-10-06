-- Petit test, côté serveur : seulement LA GRANDE PLUIE de la salle 2 (la course d'un rond vert à l'autre).
--   powershell -ExecutionPolicy Bypass -File tools\studio-test\run.ps1 -Test rush -Seconds 200
-- Le test fait avancer le personnage lui-même, en temps réel, à la vitesse d'un niveau donné.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local SCALE = 8
local ROOM = 2

return function(log)
	local function check(condition, name, detail)
		log("Info", (if condition then "[PASS] " else "[FAIL] ") .. name .. (if detail then "  (" .. tostring(detail) .. ")" else ""))
	end
	local debug = ServerStorage:WaitForChild("SurviveDebug", 30)
	local function D(...)
		return debug:Invoke(...)
	end
	local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
	while not player:GetAttribute("Loaded") do
		task.wait(0.1)
	end
	D("Cycle", "pause")

	local known = nil
	local function alive()
		while true do
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 and character:FindFirstChild("HumanoidRootPart") then
				if character ~= known then
					known = character
					task.wait(0.6)
				end
				return character, humanoid, character.HumanoidRootPart
			end
			task.wait(0.1)
		end
	end
	local function waitState(state: string, timeout: number): boolean
		local limit = os.clock() + timeout
		while os.clock() < limit do
			if D("Room", ROOM).state == state then
				return true
			end
			task.wait(0.05)
		end
		return false
	end
	local function shot(name: string, from: Vector3, target: Vector3)
		workspace:SetAttribute("ShotCam", CFrame.lookAt(from, target))
		task.wait(0.4)
		log("Info", "SHOT:rush_" .. name)
		task.wait(0.8)
		workspace:SetAttribute("ShotCam", nil)
	end

	local def = Config.ROOMS[ROOM].Meteors.rush
	check(def ~= nil and def.level == 1, "la salle 2 est une grande pluie faite pour la vitesse de palier 1")

	-- Une manche : le personnage court à `speed`. leave = true : après la 1re course, il sort du rond de départ
	-- avant le départ (il essaie de partir en avance). Renvoie : en vie à la fin, nombre de courses finies, et ce
	-- que le sol lui a fait perdre hors du rond.
	local shots = {}
	local function run(speed: number, leave: boolean?): (boolean, number, number)
		D("Scale", SCALE)
		local room = D("Room", ROOM)
		local character = alive()
		character:PivotTo(CFrame.new(Vector3.new(0, 4, room.zMin + 8)))
		waitState("Countdown", 3)
		waitState("Event", Config.PREPARE / SCALE + 3)
		D("Scale", 1)
		local runner, body
		character, runner, body = alive()
		local waves, burned = 0, 0
		local previous = os.clock()
		while runner.Health > 0 and waves < 3 do
			local now = os.clock()
			local dt = now - previous
			previous = now
			local info = D("Room", ROOM)
			if info.state ~= "Event" then
				break
			end
			local rush = info.rush
			waves = rush.waves
			if leave and waves >= 1 and rush.phase ~= "warn" then
				-- Il part en avance : au milieu de la salle, hors du rond de départ. On ne le soigne plus.
				character:PivotTo(CFrame.new(Vector3.new(info.center.X, body.Position.Y, info.center.Z)))
				burned = math.max(burned, runner.MaxHealth - runner.Health)
			else
				-- Soigné à chaque image : seule la grande pluie (100 dégâts d'un coup) le tue.
				runner.Health = runner.MaxHealth
				if rush.phase == "ready" and rush.hold then
					-- Avant le départ : au bord du rond de départ, du côté du rond d'arrivée (comme un bon joueur).
					local toward = Vector3.new(rush.target.X - rush.hold.X, 0, rush.target.Z - rush.hold.Z).Unit
					character:PivotTo(CFrame.new(Vector3.new(rush.hold.X, body.Position.Y, rush.hold.Z) + toward * 6))
					if not shots.ready then
						shots.ready = true
						task.spawn(shot, "pret", info.center + Vector3.new(-30, 34, 0), info.center)
					end
				elseif rush.phase == "warn" then
					local position = body.Position
					local delta = Vector3.new(rush.target.X - position.X, 0, rush.target.Z - position.Z)
					if delta.Magnitude > 5 then
						character:PivotTo(CFrame.new(position + delta.Unit * math.min(speed * dt, delta.Magnitude - 5)))
					end
					if rush.hold and not shots.go then
						shots.go = true
						task.spawn(shot, "partez", info.center + Vector3.new(-30, 34, 0), info.center)
					end
				end
			end
			task.wait()
		end
		local survived = runner.Health > 0
		if survived then
			runner.Health = 0
		end
		D("Scale", SCALE)
		waitState("Idle", 4)
		return survived, waves, burned
	end

	local info = D("Room", ROOM)
	local seconds
	local survived, waves = run(Config.walkSpeed(1))
	seconds = D("Room", ROOM).rush and D("Room", ROOM).rush.seconds
	check(survived and waves >= 3, "vitesse de palier 1 (120 points) : arrive à temps aux 3 courses", waves)
	survived, waves = run(Config.walkSpeed(0))
	check(not survived and waves >= 1 and waves < 3, "vitesse 0 : passe la 1re course (temps en plus), puis n'arrive pas à temps", waves)
	survived, waves = run(Config.walkSpeed(0) * 1.07)
	check(not survived, "à mi-chemin du palier 1 (60 points) : n'arrive pas non plus", waves)
	local burned
	survived, waves, burned = run(Config.walkSpeed(3), true)
	check(not survived and waves == 1, "partir en avance (sortir du rond de départ) : le sol tue, même très rapide", "courses finies : " .. waves .. " ; dégâts du sol : " .. math.floor(burned))
	log("Info", string.format("[SURVIVE] grande pluie : %.2f s par course, centre %s", seconds or -1, tostring(info.center)))

	log("Info", "[SURVIVE] TEST:done")
end

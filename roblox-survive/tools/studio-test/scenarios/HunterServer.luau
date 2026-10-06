-- Petit test, côté serveur : seulement LE PRÉDATEUR de la salle 2.
--   powershell -ExecutionPolicy Bypass -File tools\studio-test\run.ps1 -Test hunter -Seconds 220
-- Le test fait courir le personnage lui-même autour du rocher, sur la corde (le meilleur chemin possible), à la
-- vitesse d'un palier donné. Il fuit son prédateur, et à chaque feinte il fait demi-tour après un temps de réaction.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local SCALE = 4
local ROOM = 2
local HALF_X, HALF_Z = 18.3, 23.3 -- la corde du joueur : à 1,3 stud du rocher (17 x 22)

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
	D("Income", false)
	local id = tostring(player.UserId)

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
		task.wait(0.5)
		log("Info", "SHOT:hunter_" .. name)
		task.wait(0.9)
		workspace:SetAttribute("ShotCam", nil)
	end

	-- La corde du joueur : le même rectangle que le circuit du prédateur, parcouru par une distance s.
	local info = D("Room", ROOM)
	local center = info.center
	local sides = { HALF_X * 2, HALF_Z * 2, HALF_X * 2, HALF_Z * 2 }
	local length = 2 * (sides[1] + sides[2])
	local corners = { Vector3.new(-HALF_X, 0, -HALF_Z), Vector3.new(HALF_X, 0, -HALF_Z), Vector3.new(HALF_X, 0, HALF_Z), Vector3.new(-HALF_X, 0, HALF_Z) }
	local function pointAt(s: number): Vector3
		s %= length
		for i = 1, 4 do
			if s <= sides[i] then
				return center + corners[i] + (corners[i % 4 + 1] - corners[i]).Unit * s
			end
			s -= sides[i]
		end
		return center + corners[1]
	end
	local function gap(a: number, b: number): number
		return (b - a + length / 2) % length - length / 2
	end

	local def = Config.ROOMS[ROOM]
	check(def.events[1] == "Hunter" and def.need.Speed == 1, "la salle 2 est le prédateur, faite pour la vitesse de palier 1")
	local mesa = workspace.Rooms["Room" .. ROOM]:FindFirstChild("Mesa", true)
	check(mesa ~= nil and mesa.Size.Y > Config.jumpHeight(Config.MAX_LEVEL) + 3, "le rocher du milieu est plus haut que le meilleur saut du jeu", mesa and mesa.Size.Y)
	local hunterSpeed = Config.hunterSpeed(def.Hunter.level)
	check(hunterSpeed < Config.walkSpeed(1) and hunterSpeed > Config.walkSpeed(0.5), "le prédateur va moins vite que le palier 1 et plus vite qu'un joueur à mi-chemin", hunterSpeed)

	-- Une manche : le personnage fuit à `speed` ; à chaque feinte il fait demi-tour après `reaction` secondes.
	-- speed = 0 : il ne bouge pas. Renvoie : salle gagnée, moment de la mort (ou 60), plus petite avance, feintes.
	local photographed = {}
	local function run(speed: number, reaction: number): (boolean, number, number, number)
		D("Scale", 8)
		local character = alive()
		character:PivotTo(CFrame.new(Vector3.new(center.X, 4, info.zMin + 8), Vector3.new(center.X + 10, 4, info.zMin + 8)))
		waitState("Countdown", 3)
		waitState("Event", Config.PREPARE / 8 + 3)
		D("Scale", SCALE)
		local runner, body
		character, runner, body = alive()
		local s = HALF_X -- le milieu du côté de l'entrée (là où le joueur arrive)
		local last = D("Room", ROOM).elapsed
		local direction, digStart, closest, feints, died = 1, nil, math.huge, 0, Config.DURATION
		while runner.Health > 0 do
			local room = D("Room", ROOM)
			if room.state ~= "Event" then
				break
			end
			local dt = room.elapsed - last
			last = room.elapsed
			died = room.elapsed
			local hunter = room.hunter and room.hunter.players[id]
			if hunter and speed > 0 then
				feints = hunter.feints
				local scale = length / room.hunter.length
				if hunter.mode == "dig" then
					digStart = digStart or room.elapsed
					-- Après son temps de réaction, il fuit la sortie du terrier.
					if room.elapsed - digStart >= reaction then
						direction = if gap(hunter.exitS * scale, s) >= 0 then 1 else -1
					end
					if not photographed.feint then
						photographed.feint = true
						D("Scale", 0.05)
						local spot = pointAt(s)
						shot("feinte", Vector3.new(spot.X, 14, spot.Z) + (Vector3.new(spot.X, 0, spot.Z) - center).Unit * 14, pointAt(hunter.exitS * scale) + Vector3.new(0, 4, 0))
						D("Scale", SCALE)
						last = D("Room", ROOM).elapsed
					end
				else
					digStart = nil
					direction = if gap(hunter.s * scale, s) >= 0 then 1 else -1
					if hunter.mode == "run" then
						closest = math.min(closest, hunter.distance)
					end
					if not photographed.chase and hunter.mode == "run" and room.elapsed > 5 then
						photographed.chase = true
						D("Scale", 0.05)
						local spot = pointAt(s)
						shot("chasse", Vector3.new(spot.X, 12, spot.Z) + (Vector3.new(spot.X, 0, spot.Z) - center).Unit * 12, hunter.position + Vector3.new(0, 3, 0))
						D("Scale", SCALE)
						last = D("Room", ROOM).elapsed
					end
				end
				s = (s + direction * speed * dt) % length
				local spot = pointAt(s)
				character:PivotTo(CFrame.new(spot.X, body.Position.Y, spot.Z))
			end
			task.wait()
		end
		local won = runner.Health > 0 and D("Room", ROOM).state == "Open"
		D("Scale", 8)
		if runner.Health > 0 then
			runner.Health = 0
		end
		waitState("Idle", 6)
		return won, if won then Config.DURATION else died, closest, feints
	end

	local function report(won, died, closest, feints): string
		return string.format("%s à %.0f s ; plus petite avance %.0f studs ; %d feintes", if won then "gagné" else "attrapé", died, closest, feints)
	end
	local tickets = D("Eggs").tickets
	local won, died, closest, feints = run(Config.walkSpeed(1), 0.45)
	check(won and feints >= 3, "vitesse de palier 1 (120 points), demi-tour en 0,45 s : survit aux 60 secondes", report(won, died, closest, feints))
	check(D("Eggs").tickets == tickets + 1, "la salle gagnée donne son ticket", D("Eggs").tickets)
	won, died, closest, feints = run(Config.walkSpeed(1), 0.25)
	check(won, "palier 1, très bon réflexe (0,25 s) : survit", report(won, died, closest, feints))
	won, died, closest, feints = run(Config.walkSpeed(1), 0.8)
	log("Info", "[SURVIVE] palier 1, réflexe lent (0,8 s) : " .. report(won, died, closest, feints))
	tickets = D("Eggs").tickets
	won, died, closest, feints = run(Config.walkSpeed(0), 0.25)
	check(not won and died < 40, "vitesse 0, même avec un très bon réflexe : attrapé", report(won, died, closest, feints))
	check(D("Eggs").tickets == tickets, "pas de ticket pour un joueur attrapé", D("Eggs").tickets)
	won, died, closest, feints = run(Config.walkSpeed(0.5), 0.45)
	check(not won, "à mi-chemin du palier 1 (60 points) : attrapé avant la fin", report(won, died, closest, feints))
	won, died = run(0, 0)
	check(not won and died < 6, "sans bouger, contre le mur d'en face : attrapé en quelques secondes", string.format("%.1f s", died))
	won, died, closest, feints = run(Config.walkSpeed(2), 0.8)
	check(won, "palier 2, réflexe lent : survit largement", report(won, died, closest, feints))

	log("Info", "[SURVIVE] TEST:done")
end

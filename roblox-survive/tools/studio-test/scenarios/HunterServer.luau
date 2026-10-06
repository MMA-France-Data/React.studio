-- Petit test, côté serveur : seulement LE PRÉDATEUR de la salle 2.
--   powershell -ExecutionPolicy Bypass -File tools\studio-test\run.ps1 -Test hunter -Seconds 260
-- Le test fait courir le personnage lui-même autour du bloc, à la vitesse d'un palier donné. Le prédateur suit sa
-- trace : le test vérifie qu'un joueur au bon palier survit MÊME s'il court large ou hésite, et qu'un joueur trop
-- lent est rattrapé même sur le meilleur chemin.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local SCALE = 4
local ROOM = 2
local BLOCK_X, BLOCK_Z = 17, 22

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

	local info = D("Room", ROOM)
	local center = info.center
	-- Le chemin du joueur : un rectangle autour du bloc, à `offset` studs de lui (1,3 = à la corde ; 9 = au milieu
	-- du couloir, virages très larges).
	local function lane(offset: number)
		local halfX, halfZ = BLOCK_X + offset, BLOCK_Z + offset
		local sides = { halfX * 2, halfZ * 2, halfX * 2, halfZ * 2 }
		local corners = { Vector3.new(-halfX, 0, -halfZ), Vector3.new(halfX, 0, -halfZ), Vector3.new(halfX, 0, halfZ), Vector3.new(-halfX, 0, halfZ) }
		local length = 2 * (sides[1] + sides[2])
		return length, halfX, function(s: number): Vector3
			s %= length
			for i = 1, 4 do
				if s <= sides[i] then
					return center + corners[i] + (corners[i % 4 + 1] - corners[i]).Unit * s
				end
				s -= sides[i]
			end
			return center + corners[1]
		end
	end

	-- Le panneau de reglages : l'ecran du joueur regle sa vitesse a 2 500 points avec une jauge (HunterClient).
	local limit = os.clock() + 12
	while D("Data").Speed ~= 2500 and os.clock() < limit do
		task.wait(0.2)
	end
	local _, tuned = alive()
	check(D("Data").Speed == 2500 and player:GetAttribute("Speed") == 2, "panneau de reglages : la jauge de vitesse met 2 500 points (palier 2)", D("Data").Speed)
	shot("reglages", Vector3.new(0, 14, -30), Vector3.new(0, 4, 20))
	D("Points", "Speed", 0)
	local def = Config.ROOMS[ROOM]
	check(def.events[1] == "Hunter" and def.need.Speed == 1, "la salle 2 est le prédateur, faite pour la vitesse de palier 1")
	local mesa = workspace.Rooms["Room" .. ROOM]:FindFirstChild("Mesa", true)
	check(mesa ~= nil and mesa.Size.Y > Config.jumpHeight(Config.MAX_LEVEL) + 3 and mesa.Transparency > 0.7, "le bloc du milieu est transparent et plus haut que le meilleur saut du jeu", mesa and mesa.Size.Y)
	local hunterSpeed = Config.hunterSpeed(def.Hunter.level)
	check(hunterSpeed < Config.walkSpeed(1) and hunterSpeed > Config.walkSpeed(0), "le prédateur va moins vite que le palier 1 et plus vite que le palier 0", hunterSpeed)

	-- Une manche : le personnage court à `speed` sur le chemin à `offset` studs du bloc. pause : il s'arrête ce
	-- nombre de secondes toutes les 6 secondes (une hésitation). speed = 0 : il ne bouge pas.
	-- Renvoie : salle gagnée, moment de la mort (ou 60), plus petite avance sur le prédateur, avance à la fin.
	local photographed = false
	local function run(speed: number, offset: number, pause: number?): (boolean, number, number, number)
		local length, halfX, pointAt = lane(offset)
		D("Scale", 8)
		local character = alive()
		character:PivotTo(CFrame.new(Vector3.new(center.X, 4, info.zMin + 8), Vector3.new(center.X + 10, 4, info.zMin + 8)))
		waitState("Countdown", 3)
		waitState("Event", Config.PREPARE / 8 + 3)
		D("Scale", SCALE)
		local runner, body
		character, runner, body = alive()
		local s = halfX -- le milieu du côté de l'entrée (là où le joueur arrive)
		local last = D("Room", ROOM).elapsed
		local closest, lead, died, started = math.huge, 0, Config.DURATION, false
		while runner.Health > 0 do
			local room = D("Room", ROOM)
			if room.state ~= "Event" then
				break
			end
			local dt = room.elapsed - last
			last = room.elapsed
			died = room.elapsed
			local hunter = room.hunter and room.hunter.players[id]
			if hunter then
				lead = hunter.lead
				started = started or hunter.moving
				if started then
					closest = math.min(closest, lead)
				end
				local resting = pause ~= nil and room.elapsed % 6 < pause and room.elapsed > 6
				if speed > 0 and not resting then
					s = (s + speed * dt) % length
					local spot = pointAt(s)
					character:PivotTo(CFrame.new(spot.X, body.Position.Y, spot.Z))
				end
				if not photographed and room.elapsed > 6 and speed > 0 then
					photographed = true
					D("Scale", 0.05)
					local spot = pointAt(s)
					local out = (Vector3.new(spot.X, 0, spot.Z) - Vector3.new(center.X, 0, center.Z)).Unit
					shot("chasse", Vector3.new(spot.X, 11, spot.Z) + out * 9, hunter.position + Vector3.new(0, 3, 0))
					D("Scale", SCALE)
					last = D("Room", ROOM).elapsed
				end
			end
			task.wait()
		end
		local won = runner.Health > 0 and D("Room", ROOM).state == "Open"
		D("Scale", 8)
		if runner.Health > 0 then
			runner.Health = 0
		end
		waitState("Idle", 6)
		return won, if won then Config.DURATION else died, closest, lead
	end

	local function report(won, died, closest, lead): string
		return string.format("%s à %.0f s ; plus petite avance %.0f studs ; avance à la fin %.0f", if won then "gagné" else "attrapé", died, closest, lead)
	end
	local tickets = D("Eggs").tickets
	local won, died, closest, lead = run(Config.walkSpeed(1), 9)
	check(won and closest > 12, "palier 1 (120 points) en courant au MILIEU du couloir (virages très larges) : survit", report(won, died, closest, lead))
	check(D("Eggs").tickets == tickets + 1, "la salle gagnée donne son ticket", D("Eggs").tickets)
	won, died, closest, lead = run(Config.walkSpeed(1), 1.3)
	check(won and closest > 12, "palier 1 à la corde : survit pareil (le chemin choisi ne change rien)", report(won, died, closest, lead))
	won, died, closest, lead = run(Config.walkSpeed(1), 5, 0.3)
	check(won and closest > 12, "palier 1 avec une hésitation de 0,3 s toutes les 6 secondes : survit", report(won, died, closest, lead))
	won, died, closest, lead = run(Config.walkSpeed(1), 5, 0.6)
	log("Info", "[SURVIVE] palier 1 avec une hésitation de 0,6 s toutes les 6 secondes : " .. report(won, died, closest, lead))
	tickets = D("Eggs").tickets
	won, died, closest, lead = run(Config.walkSpeed(0), 1.3)
	check(not won and died < 20, "vitesse 0, même à la corde : attrapé vite", report(won, died, closest, lead))
	check(D("Eggs").tickets == tickets, "pas de ticket pour un joueur attrapé", D("Eggs").tickets)
	won, died, closest, lead = run(Config.walkSpeed(0), 9, 0.3)
	check(not won and died < 35, "vitesse 0, comme un vrai joueur (couloir, hésitations) : attrapé plus vite", report(won, died, closest, lead))
	won, died, closest, lead = run(Config.walkSpeed(0.5), 1.3)
	check(not won, "à mi-chemin du palier 1 (60 points), sans faute : attrapé avant la fin", report(won, died, closest, lead))
	won, died, closest, lead = run(Config.walkSpeed(2), 9, 1)
	check(won and lead > 40, "palier 2 (2 500 points), même en s'arrêtant 1 s toutes les 6 s : sème le prédateur", report(won, died, closest, lead))
	won, died = run(0, 9)
	check(not won and died < 6, "sans bouger : attrapé en quelques secondes", string.format("%.1f s", died))
	won, died, closest, lead = run(Config.walkSpeed(4), 5)
	check(won and lead < 75, "palier 4 (très rapide) : survit, et le prédateur reste à moins d'un demi-tour (pas de tour d'avance)", report(won, died, closest, lead))

	log("Info", "[SURVIVE] TEST:done")
end

-- Petit test, côté serveur : seulement LES VANNES de la salle 4.
--   powershell -ExecutionPolicy Bypass -File tools\studio-test\run.ps1 -Test valves -Seconds 320
-- Le test déplace le personnage lui-même, en ligne droite, à la vitesse que donnent des points de vitesse. Il va
-- toujours vers la vanne la plus urgente (celle à qui il reste le moins de temps, une fois le trajet compté).
-- `late` : secondes perdues à chaque fois qu'il change de vanne (un joueur qui hésite).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local SCALE = 4
local ROOM = 4

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
		log("Info", "SHOT:valves_" .. name)
		task.wait(0.9)
		workspace:SetAttribute("ShotCam", nil)
	end

	local info = D("Room", ROOM)
	local center = info.center
	local def = Config.ROOMS[ROOM]
	check(def.events[1] == "Valves" and def.points.Speed == 10000, "la salle 4 est les vannes, faite pour 10 000 points de vitesse")
	check(workspace.Rooms["Room" .. ROOM]:GetAttribute("Needs") == "Speed:10000", "le panneau de la salle 4 demande Vitesse 10 000", workspace.Rooms["Room" .. ROOM]:GetAttribute("Needs"))

	-- Une manche avec `points` de vitesse. Renvoie : salle gagnée, moment de la mort (ou 60), vannes fermées,
	-- explosions.
	local photographed = false
	local function run(points: number, late: number): (boolean, number, number, number)
		D("Points", "Speed", points)
		local speed = Config.walkSpeed(Config.levelOf(points))
		D("Scale", 8)
		local character = alive()
		character:PivotTo(CFrame.new(Vector3.new(center.X, 4, info.zMin + 8)))
		waitState("Countdown", 3)
		waitState("Event", Config.PREPARE / 8 + 3)
		D("Scale", SCALE)
		local runner, body
		character, runner, body = alive()
		local position = Vector3.new(center.X, 0, info.zMin + 8)
		local last = D("Room", ROOM).elapsed
		local died, closed, bursts = Config.DURATION, 0, 0
		local target, wait = 0, 0
		while runner.Health > 0 do
			local room = D("Room", ROOM)
			if room.state ~= "Event" then
				break
			end
			local dt = room.elapsed - last
			last = room.elapsed
			died = room.elapsed
			local valves = room.valves
			local state = valves and valves.players[id]
			if state then
				closed, bursts = state.closed, state.bursts
				-- La vanne la plus urgente : le moins de temps restant, une fois le trajet compté.
				local best, bestSlack = 1, math.huge
				for index, spot in valves.spots do
					local travel = (Vector3.new(spot.X, 0, spot.Z) - position).Magnitude / speed
					local left = (1 - state.pressure[index]) * state.fills[index] * valves.lap
					if left - travel < bestSlack then
						best, bestSlack = index, left - travel
					end
				end
				-- Il va jusqu'au bout de son choix : il ne change de vanne qu'une fois la sienne fermee (sinon il
				-- hesiterait sans fin au milieu de la salle).
				local arrived = target == 0 or (Vector3.new(valves.spots[target].X, 0, valves.spots[target].Z) - position).Magnitude <= 3.5
				if arrived and best ~= target then
					target, wait = best, late
				end
				wait -= dt
				if wait <= 0 then
					local spot = valves.spots[target]
					local offset = Vector3.new(spot.X, 0, spot.Z) - position
					if offset.Magnitude > 3 then
						position += offset.Unit * math.min(offset.Magnitude - 3, speed * dt)
					end
				end
				character:PivotTo(CFrame.new(position.X, body.Position.Y, position.Z))
				if not photographed and room.elapsed > 14 then
					photographed = true
					D("Scale", 0.05)
					shot("vannes", Vector3.new(center.X, 46, center.Z - 44), Vector3.new(center.X, 0, center.Z + 4))
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
		return won, if won then Config.DURATION else died, closed, bursts
	end
	local function report(points, won, died, closed, bursts): string
		return string.format("court à %.1f ; %s à %.0f s ; %d vannes fermées ; %d explosions", Config.walkSpeed(Config.levelOf(points)), if won then "gagné" else "mort", died, closed, bursts)
	end

	local need = def.points.Speed
	local tickets = D("Eggs").tickets
	local won, died, closed, bursts = run(need, 0)
	check(won and bursts <= 1, "vitesse demandée, sans hésiter : survit", report(need, won, died, closed, bursts))
	check(D("Eggs").tickets == tickets + 1, "la salle gagnée donne son ticket", D("Eggs").tickets)
	won, died, closed, bursts = run(need, 0.4)
	check(won, "vitesse demandée, en hésitant 0,4 s à chaque changement de vanne : survit", report(need, won, died, closed, bursts))
	won, died, closed, bursts = run(need, 0.8)
	log("Info", "[SURVIVE] vitesse demandée, 0,8 s d'hésitation : " .. report(need, won, died, closed, bursts))
	tickets = D("Eggs").tickets
	won, died, closed, bursts = run(need - 1, 0)
	check(not won and closed == 0 and bursts >= 2 and died < 30, "un point de vitesse en moins : aucune vanne ne se ferme, mort à la 3e explosion (la 3e n'est pas lue : elle tue dans la même image)", report(need - 1, won, died, closed, bursts))
	check(D("Eggs").tickets == tickets, "pas de ticket pour un joueur mort", D("Eggs").tickets)
	won, died, closed, bursts = run(0, 0)
	check(not won and closed == 0, "vitesse 0 : aucune vanne ne se ferme, mort", report(0, won, died, closed, bursts))
	D("Points", "Speed", 0)

	log("Info", "[SURVIVE] TEST:done")
end

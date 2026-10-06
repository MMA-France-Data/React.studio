-- Petit test, côté serveur : seulement L'AVALANCHE de la salle 3.
--   powershell -ExecutionPolicy Bypass -File tools\studio-test\run.ps1 -Test rocks -Seconds 300
-- Le test déplace le personnage lui-même, à la vitesse de marche d'un joueur sans vitesse (16), devant la ligne
-- rouge : il va vers le rocher le plus proche de la ligne et le frappe dès qu'il est à portée. Il a la force qu'on
-- lui donne. `late` : il réagit en retard (secondes perdues avant de bouger vers chaque nouveau rocher).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local SCALE = 4
local ROOM = 3

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
		log("Info", "SHOT:rocks_" .. name)
		task.wait(0.9)
		workspace:SetAttribute("ShotCam", nil)
	end

	local info = D("Room", ROOM)
	local center = info.center
	local def = Config.ROOMS[ROOM]
	check(def.events[1] == "Avalanche" and def.points.Force == 7200, "la salle 3 est l'avalanche, faite pour 7 200 points de force (3 minutes de banc niveau 2)")
	local sign = workspace.Rooms["Room" .. ROOM]:GetAttribute("Needs")
	check(sign == "Force:7200" and Config.gain(2) == 20 and 7200 / (Config.gain(2) / Config.STEP_SECONDS) == 180, "le panneau demande Force 7 200 : 3 minutes avec la machine niveau 2 (+20 par pas)", sign)
	check(workspace.Rooms.Room2:GetAttribute("Needs") == "Speed:150", "le panneau de la salle 2 demande Vitesse 150", workspace.Rooms.Room2:GetAttribute("Needs"))

	-- Une manche avec `force` points de force. Renvoie : salle gagnée, moment de la mort (ou 60), rochers cassés,
	-- rochers passés.
	local photographed = false
	local function run(force: number, late: number): (boolean, number, number, number)
		D("Points", "Force", force)
		D("Scale", 8)
		local character = alive()
		character:PivotTo(CFrame.new(Vector3.new(center.X, 4, info.zMin + 8)))
		waitState("Countdown", 3)
		waitState("Event", Config.PREPARE / 8 + 3)
		D("Scale", SCALE)
		local runner, body
		character, runner, body = alive()
		local x = center.X
		local last = D("Room", ROOM).elapsed
		local died, broken, leaks = Config.DURATION, 0, 0
		local target, wait = nil, 0
		while runner.Health > 0 do
			local room = D("Room", ROOM)
			if room.state ~= "Event" then
				break
			end
			local dt = room.elapsed - last
			last = room.elapsed
			died = room.elapsed
			local state = room.avalanche and room.avalanche.players[id]
			if state then
				broken, leaks = state.broken, state.leaks
				local line = room.avalanche.line
				local z = line + 4
				-- Le rocher le plus proche de la ligne.
				local nearest = nil
				for _, rock in state.rocks do
					if not nearest or rock.z < nearest.z then
						nearest = rock
					end
				end
				if nearest then
					-- Un nouveau rocher à viser : le joueur perd `late` secondes avant de bouger.
					local key = math.floor(nearest.x * 10)
					if key ~= target then
						target, wait = key, late
					end
					wait -= dt
					if wait <= 0 then
						local offset = nearest.x - x
						x += math.sign(offset) * math.min(math.abs(offset), Config.walkSpeed(0) * dt)
					end
					character:PivotTo(CFrame.new(x, body.Position.Y, z))
					local distance = math.sqrt((nearest.x - x) ^ 2 + (nearest.z - z) ^ 2)
					if distance <= room.avalanche.reach - 0.5 and state.ready then
						D("Push", 1)
					end
					if not photographed and room.elapsed > 8 and #state.rocks >= 2 then
						photographed = true
						D("Scale", 0.05)
						shot("avalanche", Vector3.new(center.X - 6, 15, line - 6), Vector3.new(center.X, 2, line + 30))
						D("Scale", SCALE)
						last = D("Room", ROOM).elapsed
					end
				else
					character:PivotTo(CFrame.new(x, body.Position.Y, z))
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
		return won, if won then Config.DURATION else died, broken, leaks
	end
	local function report(won, died, broken, leaks): string
		return string.format("%s à %.0f s ; %d rochers cassés ; %d passés", if won then "gagné" else "mort", died, broken, leaks)
	end

	local need = def.points.Force
	local tickets = D("Eggs").tickets
	local won, died, broken, leaks = run(need, 0)
	check(won and leaks == 0 and broken >= 8, "force demandée, sans vitesse : casse tous les rochers d'un coup, survit", report(won, died, broken, leaks))
	check(D("Eggs").tickets == tickets + 1, "la salle gagnée donne son ticket", D("Eggs").tickets)
	won, died, broken, leaks = run(need, 1)
	check(won, "force demandée, en réagissant avec 1 seconde de retard à chaque rocher : survit", report(won, died, broken, leaks))
	won, died, broken, leaks = run(need, 2)
	log("Info", "[SURVIVE] force demandée, 2 secondes de retard à chaque rocher : " .. report(won, died, broken, leaks))
	tickets = D("Eggs").tickets
	won, died, broken, leaks = run(need - 1, 0)
	check(not won and broken == 0 and leaks >= 3, "un point de force en moins : aucun rocher ne casse, mort", report(won, died, broken, leaks))
	check(D("Eggs").tickets == tickets, "pas de ticket pour un joueur mort", D("Eggs").tickets)
	won, died, broken, leaks = run(0, 0)
	check(not won and broken == 0, "force 0 : aucun rocher ne casse, mort", report(won, died, broken, leaks))
	D("Points", "Force", 0)

	log("Info", "[SURVIVE] TEST:done")
end

-- LE PERSONNEL. Sa demande (14/10) : « petit à petit avec l'argent prendre des employés qui le font, un peu comme
-- Supermarket Simulator ». Chaque employé est payé le soir (Config.STAFF) et fait UNE tâche tout seul :
--   caissier : scanne les billets au guichet ;
--   soigneur : va chercher la nourriture à la réserve (payée) et remplit les mangeoires presque vides ;
--   agent d'entretien : ramasse les crottes et les papiers ;
--   vétérinaire : prend une trousse (payée) et soigne les animaux malades ;
--   serveur : sert les clients du café (le premier) et du bar (le deuxième).
-- Ils marchent par les allées (la grande boucle), et passent les clôtures par la porte « Personnel ».
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Animals = require(script.Parent.Animals)
local Config = require(ReplicatedStorage.Shared.Config)
local Enclosures = require(script.Parent.Enclosures)
local Map = require(script.Parent.Map)
local Npc = require(script.Parent.Npc)
local Paths = require(script.Parent.Paths)
local Tasks = require(script.Parent.Tasks)
local Visitors = require(script.Parent.Visitors)
local Zoo = require(script.Parent.Zoo)

local Staff = {}

local v3 = Vector3.new
local random = Random.new()
local workers = {} -- [rôle] = { { npc, alive } ... }
local claimed = {} -- ce qu'un employé est déjà parti faire (une mangeoire, une crotte...)

-- SE DÉPLACER PAR LES ALLÉES ------------------------------------------------------------------------------------------
local insideOf: (Vector3) -> string?
local PLAZA_DOOR = v3(0, 0, 124)

local function inPlaza(position: Vector3): boolean
	local plaza = Config.PLAZA
	return position.X >= plaza.min.X - 8 and position.X <= plaza.max.X + 8 and position.Z >= plaza.min.Z - 2 and position.Z <= plaza.max.Z + 2
end

-- Le chemin d'un point à un autre : direct si c'est près ; sinon par les allées, le plus court (Paths.luau).
local function route(from: Vector3, to: Vector3): { Vector3 }
	local points = {}
	if (to - from).Magnitude < 45 or (inPlaza(from) and inPlaza(to)) then
		table.insert(points, to)
		return points
	end
	local start = if inPlaza(from) then Config.PATH_START else Paths.nearest(from)
	local finish = if inPlaza(to) then Config.PATH_START else Paths.nearest(to)
	if inPlaza(from) then
		table.insert(points, PLAZA_DOOR)
	end
	table.insert(points, Paths.position(start))
	for _, point in Paths.route(start, finish) do
		table.insert(points, point)
	end
	if inPlaza(to) then
		table.insert(points, PLAZA_DOOR)
	end
	table.insert(points, to)
	return points
end

-- La parcelle où se trouve l'employé (nil s'il est dehors).
function insideOf(position: Vector3): string?
	for id, space in Enclosures.spaces do
		if space.open and Enclosures.distanceTo(id, position) <= 0 then
			return id
		end
	end
	return nil
end

-- Sortir d'une parcelle : par le chemin de sa porte, à l'envers (la rampe de la fosse aux ours).
local function leave(worker)
	local id = insideOf(worker.npc.root.Position)
	local space = id and Enclosures.spaces[id]
	if not space then
		return
	end
	for index = #space.path, 1, -1 do
		Npc.walkTo(worker.npc, space.path[index], 2, 20)
	end
end

local function travel(worker, target: Vector3, near: number?): boolean
	leave(worker)
	local points = route(worker.npc.root.Position, target)
	for index, point in points do
		if not worker.alive then
			return false
		end
		local last = index == #points
		if not Npc.walkTo(worker.npc, point, if last then near or 2 else 3, 40) and not worker.alive then
			return false
		end
	end
	return worker.alive
end

-- Aller dans une parcelle : par sa porte « Personnel » (et la rampe de la fosse).
local function enter(worker, spaceId: string, target: Vector3): boolean
	local space = Enclosures.spaces[spaceId]
	if not space then
		return false
	end
	if insideOf(worker.npc.root.Position) ~= spaceId then
		if not travel(worker, space.path[1] or space.gate, 2) then
			return false
		end
		for index = 2, #space.path do
			Npc.walkTo(worker.npc, space.path[index], 2, 20)
		end
	end
	return Npc.walkTo(worker.npc, target, 2, 25)
end

-- Le point où l'on prend une chose, à la réserve la plus proche (devant le comptoir).
local function storeSpot(kind: string, near: Vector3): Vector3
	local best, bestDistance = nil, math.huge
	for _, store in Map.stores do
		local counter = store[kind]
		local spot = v3(counter.Position.X, 0, counter.Position.Z) + store.facing * 2.5
		local distance = (spot - near).Magnitude
		if distance < bestDistance then
			best, bestDistance = spot, distance
		end
	end
	return best
end

local IDLE_SPOT = v3(-24, 0, 176)

-- LES TÂCHES DE CHAQUE MÉTIER -----------------------------------------------------------------------------------------
local JOBS = {}

function JOBS.cashier(worker)
	local booth = Config.GATE.booth
	worker.npc.root.CFrame = CFrame.lookAt(booth + v3(0.5, 3, 0), booth + v3(5, 3, 0))
	while worker.alive do
		task.wait(Config.STAFF.cashier.every)
		Visitors.scan(nil)
	end
end

function JOBS.keeper(worker)
	while worker.alive do
		-- La mangeoire la plus vide (sous 40 %) que personne d'autre n'est parti remplir.
		local best, bestLevel = nil, 40
		for spaceId, space in Enclosures.spaces do
			if space.open then
				for food, trough in space.troughs do
					local key = "trough|" .. spaceId .. "|" .. food
					if not claimed[key] and trough.level < bestLevel then
						best, bestLevel = { space = spaceId, food = food, key = key, trough = trough }, trough.level
					end
				end
			end
		end
		if not best then
			travel(worker, IDLE_SPOT + v3(random:NextNumber(-4, 4), 0, random:NextNumber(-4, 4)), 2)
			task.wait(3)
			continue
		end
		claimed[best.key] = true
		local ok = travel(worker, storeSpot(best.food, best.trough.position), 2)
		if ok and Zoo.spend(Config.FOODS[best.food].price, "food") then
			task.wait(0.8)
			if enter(worker, best.space, best.trough.position + (best.trough.base.LookVector * -2.5)) then
				task.wait(1.2)
				Enclosures.setLevel(best.space, best.food, Config.TROUGH_MAX)
			end
		else
			task.wait(5)
		end
		claimed[best.key] = nil
	end
end

function JOBS.cleaner(worker)
	while worker.alive do
		local here = worker.npc.root.Position
		local best, bestDistance = nil, math.huge
		for _, item in Enclosures.allPoops() do
			if not claimed[item] and item.Parent then
				local distance = (item.Position - here).Magnitude
				if distance < bestDistance then
					best, bestDistance = item, distance
				end
			end
		end
		for _, item in Tasks.trash() do
			if not claimed[item] and item.Parent then
				local distance = (item.Position - here).Magnitude * 0.8
				if distance < bestDistance then
					best, bestDistance = item, distance
				end
			end
		end
		if not best then
			travel(worker, IDLE_SPOT + v3(random:NextNumber(-4, 4), 0, random:NextNumber(-4, 4)), 2)
			task.wait(3)
			continue
		end
		claimed[best] = true
		local spaceId = best:GetAttribute("Space")
		local ok = if spaceId then enter(worker, spaceId, best.Position) else travel(worker, best.Position, 2)
		if ok and best.Parent then
			task.wait(0.8)
			if spaceId then
				Enclosures.removePoop(best)
			else
				Tasks.removeTrash(best)
			end
		end
		claimed[best] = nil
	end
end

function JOBS.vet(worker)
	while worker.alive do
		local patient = nil
		for _, animal in Zoo.state.animals do
			if animal.k and not claimed["vet|" .. animal.id] then
				patient = animal
				break
			end
		end
		if not patient then
			travel(worker, IDLE_SPOT + v3(random:NextNumber(-4, 4), 0, random:NextNumber(-4, 4)), 2)
			task.wait(3)
			continue
		end
		local key = "vet|" .. patient.id
		claimed[key] = true
		if travel(worker, storeSpot("kit", Enclosures.spaces[patient.sp].plot.center), 2) and Zoo.spend(Config.KIT.price, "care") then
			task.wait(0.8)
			if enter(worker, patient.sp, Enclosures.randomPoint(patient.sp, 5)) then
				task.wait(1.5)
				if Animals.treat(patient) then
					Zoo.notify(nil, "treatedBy", Animals.nameOf(patient))
				end
			end
		else
			task.wait(5)
		end
		claimed[key] = nil
	end
end

function JOBS.waiter(worker)
	-- Le premier serveur tient le café, le deuxième le bar.
	local list = workers.waiter or {}
	local id = if table.find(list, worker) == 2 then "bar" else "cafe"
	while worker.alive do
		local building = Enclosures.buildings[id]
		if building and building.open then
			if (worker.npc.root.Position - building.counter).Magnitude > 3 then
				travel(worker, building.counter, 1.5)
				Npc.face(worker.npc, building.queueFirst)
			end
			Visitors.serve(id, nil)
			task.wait(Config.STAFF.waiter.every)
		else
			task.wait(3)
		end
	end
end

-- EMBAUCHER, RENVOYER -------------------------------------------------------------------------------------------------
local function spawnWorker(role: string)
	local def = Config.STAFF[role]
	local npc = Npc.make(role, Config.STORES[1].center + v3(8, 0, 0), def.fr)
	if not npc then
		return
	end
	npc.humanoid.WalkSpeed = Config.STAFF_SPEED
	local worker = { npc = npc, alive = true, role = role }
	workers[role] = workers[role] or {}
	table.insert(workers[role], worker)
	task.spawn(function()
		local ok, problem = pcall(JOBS[role], worker)
		if not ok then
			warn("[ZOO] " .. role .. " : " .. tostring(problem))
		end
	end)
end

local function removeWorker(role: string)
	local list = workers[role]
	local worker = list and table.remove(list)
	if worker then
		worker.alive = false
		worker.npc.model:Destroy()
	end
end

function Staff.hire(player: Player?, role: string): boolean
	local def = Config.STAFF[role]
	if not def then
		return false
	end
	local count = Zoo.state.staff[role] or 0
	if count >= def.max then
		if player then
			Zoo.notify(player, "staffFull", def.fr)
		end
		return false
	end
	if role == "waiter" and not (Zoo.state.buildings.cafe or Zoo.state.buildings.bar) then
		if player then
			Zoo.notify(player, "needCafe")
		end
		return false
	end
	Zoo.state.staff[role] = count + 1
	Zoo.publish()
	spawnWorker(role)
	Zoo.notify(nil, "hired", def.fr, if player then player.Name else "")
	return true
end

function Staff.fire(player: Player?, role: string): boolean
	local def = Config.STAFF[role]
	if not def or (Zoo.state.staff[role] or 0) <= 0 then
		return false
	end
	Zoo.state.staff[role] -= 1
	Zoo.publish()
	removeWorker(role)
	Zoo.notify(nil, "fired", def.fr, if player then player.Name else "")
	return true
end

-- Les salaires du jour (le soir).
function Staff.payroll(): number
	local total = 0
	for _, role in Config.STAFF_ORDER do
		total += (Zoo.state.staff[role] or 0) * Config.STAFF[role].salary
	end
	return total
end

function Staff.start()
	for _, role in Config.STAFF_ORDER do
		for _ = 1, Zoo.state.staff[role] or 0 do
			spawnWorker(role)
		end
	end
	Zoo.remotes.hire.OnServerEvent:Connect(function(player, role)
		if typeof(role) == "string" then
			Staff.hire(player, role)
		end
	end)
	Zoo.remotes.fire.OnServerEvent:Connect(function(player, role)
		if typeof(role) == "string" then
			Staff.fire(player, role)
		end
	end)
end

return Staff

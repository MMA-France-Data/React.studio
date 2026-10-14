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
local Shops = require(script.Parent.Shops)
local Stock = require(script.Parent.Stock)
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

-- (Un manque dans le stock : on le dit au joueur, pas plus d'une fois par minute pour chaque produit.)
local warned = {}
local function shortage(item: string)
	if os.clock() - (warned[item] or -999) > 60 then
		warned[item] = os.clock()
		Zoo.notify(nil, "staffShortage", Config.STOCK[item].fr)
	end
end

function JOBS.keeper(worker)
	while worker.alive do
		-- La mangeoire la plus vide (sous 40 %) que personne d'autre n'est parti remplir, s'il y a du stock pour elle.
		local best, bestLevel = nil, 40
		for spaceId, space in Enclosures.spaces do
			if space.open then
				for food, trough in space.troughs do
					local key = "trough|" .. spaceId .. "|" .. food
					if not claimed[key] and trough.level < bestLevel then
						if Stock.get(food) > 0 then
							best, bestLevel = { space = spaceId, food = food, key = key, trough = trough }, trough.level
						else
							shortage(food)
						end
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
		if ok and Stock.take(best.food, 1) > 0 then
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

-- L'agent d'entretien : les crottes, les papiers, les poubelles presque pleines, les toilettes sales (au plus près).
function JOBS.cleaner(worker)
	while worker.alive do
		local here = worker.npc.root.Position
		local best, bestDistance, bestKind = nil, math.huge, nil
		local function consider(item, position: Vector3, kind: string, weight: number)
			if not claimed[item] then
				local distance = (position - here).Magnitude * weight
				if distance < bestDistance then
					best, bestDistance, bestKind = item, distance, kind
				end
			end
		end
		for _, item in Enclosures.allPoops() do
			if item.Parent then
				consider(item, item.Position, "poop", 1)
			end
		end
		for _, item in Tasks.trash() do
			if item.Parent then
				consider(item, item.Position, "trash", 0.8)
			end
		end
		for _, bin in Shops.fullBins(Config.BIN_MAX - 6) do
			consider(bin, bin.part.Position, "bin", 0.6)
		end
		for id, spot in Shops.spots do
			local shop = Zoo.state.shops[id]
			if spot.open and shop and shop.t == "toilets" and shop.d >= 40 then
				consider(spot, spot.front, "toilets", 0.5)
			end
		end
		if not best then
			travel(worker, IDLE_SPOT + v3(random:NextNumber(-4, 4), 0, random:NextNumber(-4, 4)), 2)
			task.wait(3)
			continue
		end
		claimed[best] = true
		if bestKind == "poop" then
			if enter(worker, best:GetAttribute("Space"), best.Position) and best.Parent then
				task.wait(0.8)
				Enclosures.removePoop(best)
			end
		elseif bestKind == "trash" then
			if travel(worker, best.Position, 2) and best.Parent then
				task.wait(0.8)
				Tasks.removeTrash(best)
			end
		elseif bestKind == "bin" then
			if travel(worker, best.part.Position, 2.5) then
				task.wait(1)
				Shops.empty(best)
			end
		else
			if travel(worker, best.front, 2) then
				task.wait(2)
				Shops.clean(best.def.id)
			end
		end
		claimed[best] = nil
	end
end

-- Le vétérinaire : il examine l'animal malade, prend le bon médicament à la réserve, et le soigne.
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
		-- 1. L'examen (s'il n'a pas déjà été fait).
		if not patient.e and enter(worker, patient.sp, Enclosures.randomPoint(patient.sp, 5)) then
			task.wait(2)
			Animals.examine(patient)
		end
		-- 2. Le bon médicament, puis le soin.
		local disease = Config.DISEASES[patient.d or ""]
		local med = disease and disease.med
		if med and patient.k then
			if Stock.get(med) <= 0 then
				shortage(med)
				task.wait(5)
			elseif travel(worker, storeSpot("pharmacy", Enclosures.spaces[patient.sp].plot.center), 2) and Stock.take(med, 1) > 0 then
				task.wait(0.8)
				if enter(worker, patient.sp, Enclosures.randomPoint(patient.sp, 5)) then
					task.wait(1.5)
					if Animals.treat(patient, med) then
						Zoo.notify(nil, "treatedBy", patient.n or Animals.nameOf(patient))
					end
				end
			end
		end
		claimed[key] = nil
	end
end

-- Le magasinier : il range les cartons du quai dans la réserve, et remplit les stands presque vides.
function JOBS.storekeeper(worker)
	while worker.alive do
		local done = false
		-- 1. Un carton sur le quai.
		for _, box in Stock.boxes do
			if not claimed[box] and box.Parent then
				claimed[box] = true
				local item, amount = box:GetAttribute("Item"), box:GetAttribute("Amount")
				if travel(worker, box.Position, 3) and box.Parent and Stock.removeBox(box) then
					task.wait(0.6)
					travel(worker, (Map.stores[1].shelf :: BasePart).Position, 3)
					task.wait(0.8)
					local stored = Stock.add(item, amount)
					if stored < amount then
						Stock.returnBox(item, amount - stored)
						shortage(item)
					end
				end
				claimed[box] = nil
				done = true
				break
			end
		end
		-- 2. Un stand presque vide (s'il y a des produits en stock).
		if not done then
			for id, spot in Shops.spots do
				local product, missing = Shops.need(id)
				if product and missing >= Config.SHOP_STOCK - 8 and not claimed[spot] then
					if Stock.get(product) > 0 then
						claimed[spot] = true
						if travel(worker, storeSpot("shop", spot.front), 2) then
							local got = Stock.take(product, math.min(missing, Config.STOCK[product].pack))
							if got > 0 then
								task.wait(0.8)
								if travel(worker, spot.front, 2) then
									task.wait(1)
									local added = Shops.restock(id, got)
									if added < got then
										Stock.add(product, got - added)
									end
								else
									Stock.add(product, got)
								end
							end
						end
						claimed[spot] = nil
						done = true
						break
					else
						shortage(product)
					end
				end
			end
		end
		if not done then
			travel(worker, IDLE_SPOT + v3(random:NextNumber(-4, 4), 0, random:NextNumber(-4, 4)), 2)
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

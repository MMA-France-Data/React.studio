-- LES VISITEURS. Sa demande (14/10) : « au début faudra faire nous-mêmes l'entrée des clients, scanner les tickets ».
--   Ils descendent du bus, font la queue au guichet et attendent qu'on scanne leur billet (le joueur au comptoir de la
--   cabine, ou le caissier). Trop d'attente : ils repartent fâchés. Une fois entrés, ils font le tour du zoo et
--   s'arrêtent devant chaque espace ouvert ; ils passent au café et au bar s'ils existent (il faut les servir) ; certains
--   jettent un papier par terre. En sortant, chacun donne une note au zoo (Config.NOTE_BLEND, Day.luau).
--   Combien par jour : Config.visitorsPerDay (plus d'espaces, meilleure note = plus de visiteurs).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Animals = require(script.Parent.Animals)
local Config = require(ReplicatedStorage.Shared.Config)
local Enclosures = require(script.Parent.Enclosures)
local Map = require(script.Parent.Map)
local Npc = require(script.Parent.Npc)
local Paths = require(script.Parent.Paths)
local Scanner = require(script.Parent.Scanner)
local Tasks = require(script.Parent.Tasks)
local Zoo = require(script.Parent.Zoo)

local Visitors = {}

local V = Config.VISITORS
local GATE = Config.GATE
local v3 = Vector3.new
local random = Random.new()

local visitors = {} -- tous les visiteurs en vie
local queue = {} -- la file du guichet (dans l'ordre)
local counters = {} -- [bâtiment] = la file du café ou du bar
local schedule = {} -- les heures d'arrivée du jour qui restent
local closing = false

-- LE TOUR DU ZOO ------------------------------------------------------------------------------------------------------
-- Une étape : un point de passage, ou l'arrêt devant un espace (space) ou un bâtiment (building).
local function stop(kind: string, id: string)
	return { [kind] = id }
end
local PLAZA_TOUR = {
	v3(8, 0, 188), v3(7, 0, 172), v3(14, 0, 160), v3(22, 0, 156), stop("space", "farm"), v3(21, 0, 155),
	v3(10, 0, 136), v3(-10, 0, 136), v3(-21, 0, 151), stop("space", "s1"), v3(-21, 0, 149), v3(-10, 0, 136),
	v3(0, 0, 128),
}
local EXIT_TOUR = { v3(0, 0, 132), v3(-14, 0, 142), v3(-14, 0, 160), v3(-8, 0, 178), v3(-8, 0, 188), GATE.exit, GATE.exit + v3(0, 0, 10), v3(-14, 0, 230), Config.LEAVE }

-- LES ARRÊTS SUR LES ALLÉES : chaque parcelle (sauf celles de la place) et chaque bâtiment a son point sur le
-- réseau des allées (Paths.attach, au démarrage). Le tour d'un visiteur passe par tous les arrêts ouverts, du plus
-- proche au plus proche, puis revient à la place : il ne fait pas les allées où il n'y a rien à voir.
local stops = {} -- { node, space = parcelle } ou { node, building = bâtiment }

local function networkTour(): { any }
	local targets = {}
	for _, item in stops do
		if item.space and Enclosures.spaces[item.space] and Enclosures.spaces[item.space].open then
			table.insert(targets, item)
		elseif item.building and Enclosures.buildings[item.building] and Enclosures.buildings[item.building].open then
			table.insert(targets, item)
		end
	end
	local tour = {}
	if #targets == 0 then
		return tour
	end
	table.insert(tour, v3(0, 0, 116))
	table.insert(tour, Paths.position(Config.PATH_START))
	local current = Config.PATH_START
	while #targets > 0 do
		local best, bestDistance = 1, math.huge
		for index, item in targets do
			local distance = Paths.distance(current, item.node)
			if distance < bestDistance then
				best, bestDistance = index, distance
			end
		end
		local item = table.remove(targets, best)
		for _, point in Paths.route(current, item.node) do
			table.insert(tour, point)
		end
		table.insert(tour, item)
		current = item.node
	end
	for _, point in Paths.route(current, Config.PATH_START) do
		table.insert(tour, point)
	end
	return tour
end

-- LE GUICHET ----------------------------------------------------------------------------------------------------------
local function queueSpot(index: number): Vector3
	local count = GATE.queueCount
	if index <= count then
		return GATE.queueFirst + GATE.queueStep * (index - 1)
	end
	-- (Au-delà de la dernière place : ils attendent en petit groupe au bout de la file.)
	local last = GATE.queueFirst + GATE.queueStep * (count - 1)
	return last + v3(((index - count) % 3 - 1) * 2.2, 0, 3 + math.floor((index - count) / 3) * 2.4)
end

local boothAlert: BillboardGui
local boothAlertText: TextLabel

local function refreshGate()
	local ready = queue[1] ~= nil and queue[1].ready == true
	Scanner.showTicket(ready)
	Zoo.shared:SetAttribute("Queue", #queue)
	local cashier = (Zoo.state.staff.cashier or 0) > 0
	boothAlert.Enabled = #queue > 0 and not cashier
	boothAlertText.Text = if #queue == 1 then "1 visiteur attend !" else #queue .. " visiteurs attendent !"
end

-- Scanne le billet du premier de la file (by : le joueur, ou nil pour le caissier). Renvoie true si c'est fait.
function Visitors.scan(by: Player?): boolean
	local visitor = queue[1]
	if not visitor or not visitor.ready then
		return false
	end
	table.remove(queue, 1)
	visitor.scanned = true
	local price = Config.ticketPrice(Zoo.state.stars)
	Zoo.addMoney(price, "tickets")
	Zoo.today.visitors += 1
	Zoo.state.visitors += 1
	Zoo.popup(Map.scanner.Position + v3(0, 2.5, 0), "+" .. price .. " $", Color3.fromRGB(110, 230, 120))
	Map.scannerScreen.Color = Color3.fromRGB(80, 255, 120)
	task.delay(0.25, function()
		Map.scannerScreen.Color = Color3.fromRGB(60, 220, 120)
	end)
	refreshGate()
	if by and Tasks.onDone then
		Tasks.onDone(by, "scan")
	end
	return true
end

-- LE CAFÉ ET LE BAR ---------------------------------------------------------------------------------------------------
local function refreshCounter(id: string)
	local building = Enclosures.buildings[id]
	if not building or not building.open then
		return
	end
	local line = counters[id] or {}
	building.prompt.Enabled = line[1] ~= nil and line[1].ready == true
	local waiter = (Zoo.state.staff.waiter or 0) >= (if id == "cafe" then 1 else 2)
	building.alert.Enabled = #line > 0 and not waiter
	building.alertText.Text = if #line == 1 then "1 client attend !" else #line .. " clients attendent !"
end

function Visitors.serve(id: string, by: Player?): boolean
	local line = counters[id]
	local visitor = line and line[1]
	if not visitor or not visitor.ready then
		return false
	end
	table.remove(line, 1)
	visitor.served = true
	local def = Config.BUILDING_BY_ID[id]
	Zoo.addMoney(def.sale, "shops")
	local building = Enclosures.buildings[id]
	Zoo.popup(building.prompt.Parent.Position + v3(0, 2.5, 0), "+" .. def.sale .. " $", Color3.fromRGB(110, 230, 120))
	refreshCounter(id)
	if by and Tasks.onDone then
		Tasks.onDone(by, "serve")
	end
	return true
end

-- Combien de clients attendent à ce comptoir (pour le serveur).
function Visitors.waiting(id: string): number
	return if counters[id] then #counters[id] else 0
end

-- LA VIE D'UN VISITEUR ------------------------------------------------------------------------------------------------
local function despawn(visitor)
	local index = table.find(visitors, visitor)
	if index then
		table.remove(visitors, index)
	end
	local inQueue = table.find(queue, visitor)
	if inQueue then
		table.remove(queue, inQueue)
		refreshGate()
	end
	for id, line in counters do
		local at = table.find(line, visitor)
		if at then
			table.remove(line, at)
			refreshCounter(id)
		end
	end
	if visitor.npc and visitor.npc.model.Parent then
		visitor.npc.model:Destroy()
	end
	Zoo.shared:SetAttribute("Visitors", #visitors)
end

-- Attend sa place dans une file (le guichet ou un comptoir) jusqu'à être servi. Renvoie false s'il est parti avant.
local function waitInLine(visitor, line, spotOf, patience: number, onChange): boolean
	table.insert(line, visitor)
	onChange()
	local joined = os.clock()
	local lastIndex = -1
	while visitor.npc.model.Parent do
		if visitor.scanned and line == queue then
			return true
		end
		if visitor.served and line ~= queue then
			return true
		end
		local index = table.find(line, visitor)
		if not index then
			return visitor.scanned or visitor.served or false
		end
		if index ~= lastIndex then
			lastIndex = index
			visitor.ready = false
			onChange()
			Npc.walkTo(visitor.npc, spotOf(index), 1.2, 20)
			if index == 1 then
				visitor.ready = true
				Npc.face(visitor.npc, if line == queue then GATE.booth else spotOf(0))
				onChange()
			end
		end
		visitor.waited = os.clock() - joined
		if visitor.waited > patience or closing then
			table.remove(line, table.find(line, visitor) :: number)
			onChange()
			return false
		end
		task.wait(0.3)
	end
	return false
end

local function watchSpace(visitor, id: string)
	local space = Enclosures.spaces[id]
	if not space or not space.open then
		return
	end
	local happy = Animals.spaceHappiness(id)
	if not happy then
		return
	end
	local plot = space.plot
	local toward = (plot.center - plot.view)
	toward = v3(toward.X, 0, toward.Z).Unit
	local spot = plot.view + v3(toward.Z, 0, -toward.X) * random:NextNumber(-4, 4) + toward * random:NextNumber(0, 2)
	Npc.walkTo(visitor.npc, spot, 1.5, 25)
	Npc.face(visitor.npc, plot.center)
	if not closing then
		task.wait(random:NextNumber(V.watch[1], V.watch[2]))
	end
	table.insert(visitor.scores, happy / 20)
end

local function visitBuilding(visitor, id: string)
	local building = Enclosures.buildings[id]
	if closing or not building or not building.open or random:NextNumber() > building.def.chance then
		return
	end
	counters[id] = counters[id] or {}
	if #counters[id] >= building.queueCount then
		return
	end
	local function spotOf(index: number): Vector3
		if index <= 0 then
			return building.counter
		end
		return building.queueFirst + building.queueStep * (index - 1)
	end
	-- (Par l'allée, pas à travers les buissons.)
	local entry = v3(building.def.center.X, 0, 108)
	Npc.walkTo(visitor.npc, entry, 2, 20)
	if waitInLine(visitor, counters[id], spotOf, 40, function()
		refreshCounter(id)
	end) then
		visitor.bonus += 0.3
		task.wait(1)
	end
	Npc.walkTo(visitor.npc, entry, 2, 20)
end

local function rate(visitor): number
	local score = 2.5
	if #visitor.scores > 0 then
		local total = 0
		for _, value in visitor.scores do
			total += value
		end
		score = total / #visitor.scores
	end
	score -= math.min(1.5, #Tasks.trash() * 0.1)
	if visitor.queueWait > 50 then
		score -= 1.2
	elseif visitor.queueWait > 30 then
		score -= 0.6
	end
	score += visitor.bonus
	return math.clamp(score, 0.5, 5)
end

local function life(visitor)
	local npc = visitor.npc
	-- 1. Du bus à la file du guichet.
	local ok = waitInLine(visitor, queue, queueSpot, V.patience, refreshGate)
	visitor.queueWait = visitor.waited or 0
	if not ok then
		-- Parti fâché (ou le zoo ferme).
		if not closing then
			Zoo.today.angry += 1
			table.insert(Zoo.today.ratings, 0.5)
			Zoo.notify(nil, "angry")
		end
		npc.humanoid.WalkSpeed = V.walk * 1.3
		Npc.walkTo(npc, Config.LEAVE, 3, 40)
		despawn(visitor)
		return
	end
	-- 2. Le tour du zoo.
	local tour = table.clone(PLAZA_TOUR)
	for _, item in networkTour() do
		table.insert(tour, item)
	end
	for _, item in EXIT_TOUR do
		table.insert(tour, item)
	end
	local dropAt = if random:NextNumber() < V.trash then random:NextInteger(3, #tour - 4) else -1
	for index, item in tour do
		if not npc.model.Parent then
			break
		end
		if closing then
			npc.humanoid.WalkSpeed = V.walk * 1.6
		end
		if typeof(item) == "Vector3" then
			Npc.walkTo(npc, item + v3(random:NextNumber(-1.5, 1.5), 0, random:NextNumber(-1.5, 1.5)), 2, 40)
		elseif item.space then
			if not closing then
				watchSpace(visitor, item.space)
			end
		elseif item.building then
			visitBuilding(visitor, item.building)
		end
		if index == dropAt and not closing then
			Tasks.addTrash(npc.root.Position + v3(random:NextNumber(-2, 2), 0, random:NextNumber(-2, 2)))
		end
		-- 3. En passant la sortie : sa note.
		if item == GATE.exit and not visitor.rated then
			visitor.rated = true
			table.insert(Zoo.today.ratings, rate(visitor))
		end
	end
	if not visitor.rated then
		table.insert(Zoo.today.ratings, rate(visitor))
	end
	despawn(visitor)
end

local function spawnOne()
	local kind = if random:NextNumber() < V.kids then "kid" else "visitor"
	local npc = Npc.make(kind, Config.BUS + v3(random:NextNumber(-3, 3), 0, random:NextNumber(-2, 2)))
	if not npc then
		return
	end
	npc.humanoid.WalkSpeed = V.walk * random:NextNumber(0.85, 1.15)
	local visitor = { npc = npc, scores = {}, bonus = 0, queueWait = 0 }
	table.insert(visitors, visitor)
	Zoo.shared:SetAttribute("Visitors", #visitors)
	task.spawn(life, visitor)
end

-- LA JOURNÉE (appelé par Day.luau) -----------------------------------------------------------------------------------
-- Le matin : les heures d'arrivée de tous les visiteurs du jour.
function Visitors.morning(): number
	closing = false
	local count = Config.visitorsPerDay(Enclosures.openCount(), Zoo.state.stars)
	schedule = {}
	for _ = 1, count do
		table.insert(schedule, random:NextNumber(Config.OPEN_HOUR, Config.LAST_ARRIVAL))
	end
	table.sort(schedule)
	return count
end

-- À chaque instant de la journée : ceux dont c'est l'heure arrivent (s'il y a de la place dans le zoo).
function Visitors.update(clock: number)
	while schedule[1] and schedule[1] <= clock and #visitors < V.inside do
		table.remove(schedule, 1)
		spawnOne()
	end
end

-- 18 h : plus personne n'entre ; ceux qui sont dedans se dépêchent de sortir.
function Visitors.close()
	closing = true
	schedule = {}
end

-- Tous les visiteurs sont-ils partis ?
function Visitors.count(): number
	return #visitors
end

-- La nuit : ceux qui traînent encore disparaissent.
function Visitors.clear()
	for _, visitor in table.clone(visitors) do
		if not visitor.rated and visitor.scanned then
			table.insert(Zoo.today.ratings, rate(visitor))
		end
		despawn(visitor)
	end
	table.clear(queue)
	for _, line in counters do
		table.clear(line)
	end
	refreshGate()
end

function Visitors.queueLength(): number
	return #queue
end

function Visitors.start()
	-- Les arrêts sur les allées (les parcelles de la place sont dans PLAZA_TOUR).
	for _, plot in Config.PLOTS do
		if plot.id ~= "farm" and plot.id ~= "s1" then
			table.insert(stops, { node = Paths.attach(plot.view), space = plot.id })
		end
	end
	for _, building in Config.BUILDINGS do
		table.insert(stops, { node = Paths.attach(v3(building.center.X, 0, 108)), building = building.id })
	end
	Paths.prepare()
	Scanner.onScan = function(player)
		return Visitors.scan(player)
	end
	boothAlert, boothAlertText = Enclosures.alertBoard(Map.scanner, "Des visiteurs attendent !", Color3.fromRGB(230, 140, 40), 6)
	Enclosures.handlers.serve = function(player, id)
		Visitors.serve(id, player)
	end
	refreshGate()
end

return Visitors

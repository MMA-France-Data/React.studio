-- LES VISITEURS. Sa demande (14/10) : « au début faudra faire nous-mêmes l'entrée des clients, scanner les tickets » ;
-- et le 15/10 : leurs besoins, les prix, les événements.
--   Ils descendent du bus et regardent le prix du billet (Shops.ticketPrice) : trop cher, ils repartent. Sinon ils font la
--   queue au guichet et attendent qu'on scanne leur billet (le joueur au scanner, ou le caissier) ; trop d'attente :
--   ils repartent fâchés. Une fois entrés, ils font le tour des espaces ouverts (le plus court chemin, Paths.luau).
--   LEURS BESOINS (Config.VISITOR_NEEDS) : la faim, la soif, l'envie d'aller aux toilettes montent ; au-dessus du seuil,
--   ils vont au stand le plus proche qui peut les aider (Shops.luau). Pas de stand, stand vide, trop cher, toilettes
--   sales : ils le disent (une bulle au-dessus de leur tête) et leur note baisse.
--   Leurs papiers vont dans une poubelle proche, ou par terre si elle est pleine ou trop loin.
--   En sortant, chacun donne une note au zoo (Day.luau en fait la moyenne). L'inspecteur et le journaliste
--   (Weather.luau) sont des visiteurs à part.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Animals = require(script.Parent.Animals)
local Config = require(ReplicatedStorage.Shared.Config)
local Enclosures = require(script.Parent.Enclosures)
local Map = require(script.Parent.Map)
local Npc = require(script.Parent.Npc)
local Paths = require(script.Parent.Paths)
local Scanner = require(script.Parent.Scanner)
local Shops = require(script.Parent.Shops)
local Tasks = require(script.Parent.Tasks)
local Weather = require(script.Parent.Weather)
local Zoo = require(script.Parent.Zoo)

local Visitors = {}

local V = Config.VISITORS
local NEEDS = Config.VISITOR_NEEDS
local GATE = Config.GATE
local v3 = Vector3.new
local random = Random.new()

local visitors = {} -- tous les visiteurs en vie
local queue = {} -- la file du guichet (dans l'ordre)
local schedule = {} -- les heures d'arrivée du jour qui restent
local specials = {} -- les visiteurs à part du jour : { hour, kind }
local closing = false

-- LE TOUR DU ZOO ------------------------------------------------------------------------------------------------------
local function stop(kind: string, id: string)
	return { [kind] = id }
end
local PLAZA_TOUR = {
	v3(8, 0, 188), v3(7, 0, 172), v3(14, 0, 160), v3(22, 0, 156), stop("space", "farm"), v3(21, 0, 155),
	v3(10, 0, 136), v3(-10, 0, 136), v3(-21, 0, 151), stop("space", "s1"), v3(-21, 0, 149), v3(-10, 0, 136),
	v3(0, 0, 128),
}
local EXIT_TOUR = { v3(0, 0, 132), v3(-14, 0, 142), v3(-14, 0, 160), v3(-8, 0, 178), v3(-8, 0, 188), GATE.exit, GATE.exit + v3(0, 0, 10), v3(-14, 0, 230), Config.LEAVE }

-- Les arrêts sur les allées : chaque parcelle (sauf celles de la place) a son point sur le réseau des allées.
local stops = {} -- { node, space = parcelle }

-- Le tour des espaces ouverts, du plus proche au plus proche, puis retour au carrefour de la place.
local function networkTour(): { any }
	local targets = {}
	for _, item in stops do
		if Enclosures.spaces[item.space] and Enclosures.spaces[item.space].open then
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

-- LES BULLES au-dessus de la tête.
local function say(visitor, message: string, color: Color3?)
	local head = visitor.npc.model:FindFirstChild("Head")
	if not head then
		return
	end
	local gui = visitor.bubble
	if not gui then
		gui = Instance.new("BillboardGui")
		gui.Name = "Bubble"
		gui.Size = UDim2.fromOffset(170, 40)
		gui.StudsOffsetWorldSpace = v3(0, 3.2, 0)
		gui.MaxDistance = 70
		gui.AlwaysOnTop = true
		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = Color3.new(1, 1, 1)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.4, 0)
		corner.Parent = label
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft, pad.PaddingRight, pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8), UDim.new(0, 4), UDim.new(0, 4)
		pad.Parent = label
		gui.Parent = head
		visitor.bubble = gui
	end
	local label = gui:FindFirstChild("Text") :: TextLabel
	label.Text = message
	label.TextColor3 = color or Color3.fromRGB(50, 40, 30)
	gui.Enabled = true
	visitor.bubbleUntil = os.clock() + 3.5
	task.delay(3.6, function()
		if visitor.bubble and os.clock() >= (visitor.bubbleUntil or 0) then
			visitor.bubble.Enabled = false
		end
	end)
end
local RED = Color3.fromRGB(200, 50, 40)
local GREEN = Color3.fromRGB(40, 140, 60)

-- LE GUICHET ----------------------------------------------------------------------------------------------------------
local function queueSpot(index: number): Vector3
	local count = GATE.queueCount
	if index <= count then
		return GATE.queueFirst + GATE.queueStep * (index - 1)
	end
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
	local price = Shops.ticketPrice()
	local fair = Config.ticketPrice(Zoo.state.stars)
	if price < fair * 0.85 then
		visitor.bonus += 0.3
	elseif price > fair * 1.2 then
		visitor.bonus -= 0.4
	end
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
	if visitor.npc and visitor.npc.model.Parent then
		visitor.npc.model:Destroy()
	end
	Zoo.shared:SetAttribute("Visitors", #visitors)
end

-- Attend sa place dans la file du guichet jusqu'à ce que son billet soit scanné. Renvoie false s'il est parti avant.
local function waitInLine(visitor): boolean
	table.insert(queue, visitor)
	refreshGate()
	local joined = os.clock()
	local lastIndex = -1
	while visitor.npc.model.Parent do
		if visitor.scanned then
			return true
		end
		local index = table.find(queue, visitor)
		if not index then
			return visitor.scanned == true
		end
		if index ~= lastIndex then
			lastIndex = index
			visitor.ready = false
			refreshGate()
			Npc.walkTo(visitor.npc, queueSpot(index), 1.2, 20)
			if index == 1 then
				visitor.ready = true
				Npc.face(visitor.npc, GATE.booth)
				refreshGate()
			end
		end
		visitor.waited = os.clock() - joined
		if visitor.waited > V.patience or closing then
			table.remove(queue, table.find(queue, visitor) :: number)
			refreshGate()
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
	if happy >= 85 and random:NextNumber() < 0.25 then
		say(visitor, "Trop mignons !", GREEN)
	elseif happy < 45 and random:NextNumber() < 0.5 then
		say(visitor, "Ils ont l'air tristes…", RED)
	end
end

-- Jeter un papier : dans une poubelle proche, sinon par terre.
local function throwTrash(visitor)
	local position = visitor.npc.root.Position
	if not Shops.throw(position) then
		Tasks.addTrash(position + v3(random:NextNumber(-2, 2), 0, random:NextNumber(-2, 2)))
	end
end

-- Ce que dit un visiteur selon son besoin.
local NEED_WORDS = {
	hunger = { want = "J'ai faim !", none = "Pas de quoi manger ?!" },
	thirst = { want = "J'ai soif !", none = "Rien à boire ?!" },
	bladder = { want = "Où sont les toilettes ?", none = "Pas de toilettes ?!" },
	gift = { want = "Un souvenir !", none = "" },
}

-- Aller au stand le plus proche pour ce besoin, puis revenir sur l'allée.
local function visitShop(visitor, need: string)
	local npc = visitor.npc
	local from = Paths.nearest(npc.root.Position)
	local spot, distance = Shops.find(need, from)
	local words = NEED_WORDS[need]
	if not spot or distance > 450 then
		if need ~= "gift" then
			say(visitor, words.none, RED)
			visitor.bonus -= 0.4
			visitor.needs[need] = 20
		end
		return
	end
	if need ~= "gift" then
		say(visitor, words.want)
	end
	for _, point in Paths.route(from, spot.node) do
		Npc.walkTo(npc, point + v3(random:NextNumber(-1, 1), 0, random:NextNumber(-1, 1)), 2, 40)
	end
	Npc.walkTo(npc, spot.front, 1.5, 20)
	Npc.face(npc, spot.def.center)
	task.wait(1.5)
	local result, calmed = Shops.use(spot.def.id)
	if result == "ok" or result == "cheap" or result == "yuck" then
		for key, amount in calmed or {} do
			visitor.needs[key] = math.max(0, (visitor.needs[key] or 0) - amount)
		end
		if result == "cheap" then
			say(visitor, "Pas cher !", GREEN)
			visitor.bonus += 0.15
		elseif result == "yuck" then
			say(visitor, "Beurk, c'est sale !", RED)
			visitor.bonus -= 0.4
		elseif need == "gift" then
			say(visitor, "Super souvenir !", GREEN)
			visitor.bonus += 0.2
		else
			say(visitor, "Miam !", GREEN)
		end
		-- (Après avoir mangé ou bu : un papier à jeter.)
		if need ~= "bladder" and random:NextNumber() < 0.6 then
			task.delay(random:NextNumber(4, 10), function()
				if npc.model.Parent then
					throwTrash(visitor)
				end
			end)
		end
	elseif result == "dear" then
		say(visitor, "Trop cher !", RED)
		visitor.bonus -= 0.3
		if need ~= "gift" then
			visitor.needs[need] = 30
		end
	elseif result == "dirty" then
		say(visitor, "Toilettes trop sales !", RED)
		visitor.bonus -= 0.6
		visitor.needs[need] = 30
	else
		say(visitor, "C'est vide !", RED)
		visitor.bonus -= 0.4
		if need ~= "gift" then
			visitor.needs[need] = 30
		end
	end
	for _, point in Paths.route(spot.node, from) do
		Npc.walkTo(npc, point, 2, 40)
	end
end

-- Le besoin le plus pressant (au-dessus du seuil), ou nil.
local function urgentNeed(visitor): string?
	local best, value = nil, NEEDS.urgent
	for key, amount in visitor.needs do
		if amount >= value then
			best, value = key, amount
		end
	end
	return best
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
	score -= math.min(1.5, #Tasks.trash() * 0.08)
	if visitor.queueWait > 50 then
		score -= 1.2
	elseif visitor.queueWait > 30 then
		score -= 0.6
	end
	score += visitor.bonus
	return math.clamp(score, 0.5, 5)
end

local function addRating(visitor)
	if visitor.rated then
		return
	end
	visitor.rated = true
	local value = rate(visitor)
	-- (Le journaliste compte pour 10 visiteurs.)
	for _ = 1, if visitor.kind == "journalist" then 10 else 1 do
		table.insert(Zoo.today.ratings, value)
	end
	if visitor.kind == "journalist" then
		Zoo.today.journalist = value
		Zoo.notify(nil, "journalist", math.floor(value * 10 + 0.5) / 10)
	end
end

-- L'INSPECTEUR : en sortant, il note la propreté et la santé du zoo (Config.EVENTS « inspection »).
local function inspect()
	local score = 100
	score -= 3 * #Tasks.trash()
	score -= 2 * #Enclosures.allPoops()
	for _, shop in Zoo.state.shops do
		if shop.t == "toilets" and shop.d >= 50 then
			score -= 10
		end
	end
	score -= 5 * #Shops.fullBins(Config.BIN_MAX)
	for _, animal in Zoo.state.animals do
		if animal.k then
			score -= 8
		end
		if animal.h > 60 then
			score -= 6
		end
	end
	local grade, money, stars
	if score >= 85 then
		grade, money, stars = "A", 600, 0.3
	elseif score >= 70 then
		grade, money, stars = "B", 200, 0.1
	elseif score >= 50 then
		grade, money, stars = "C", 0, 0
	elseif score >= 30 then
		grade, money, stars = "D", -300, -0.2
	else
		grade, money, stars = "E", -800, -0.5
	end
	if money ~= 0 then
		Zoo.addMoney(money, "inspection")
	end
	Zoo.state.stars = math.clamp(Zoo.state.stars + stars, 0, 5)
	Zoo.publish()
	Zoo.today.inspection = grade
	Zoo.notify(nil, "inspected", grade, money, math.max(0, math.floor(score)))
end

local function life(visitor)
	local npc = visitor.npc
	local special = visitor.kind ~= "visitor"
	-- 1. Le prix du billet (affiché au guichet) : trop cher, il repart.
	if not special then
		local price, fair = Shops.ticketPrice(), Config.ticketPrice(Zoo.state.stars)
		Npc.walkTo(npc, queueSpot(#queue + 1) + v3(0, 0, 6), 3, 20)
		if random:NextNumber() > Config.buyChance(price, fair) then
			say(visitor, "Le billet est trop cher !", RED)
			Zoo.today.refused = (Zoo.today.refused or 0) + 1
			table.insert(Zoo.today.ratings, 1.5)
			task.wait(1.5)
			npc.humanoid.WalkSpeed = V.walk * 1.2
			Npc.walkTo(npc, Config.LEAVE, 3, 40)
			despawn(visitor)
			return
		end
		-- 2. La file du guichet.
		local ok = waitInLine(visitor)
		visitor.queueWait = visitor.waited or 0
		if not ok then
			if not closing then
				Zoo.today.angry += 1
				table.insert(Zoo.today.ratings, 0.5)
				Zoo.notify(nil, "angry")
				say(visitor, "J'en ai marre d'attendre !", RED)
			end
			npc.humanoid.WalkSpeed = V.walk * 1.3
			Npc.walkTo(npc, Config.LEAVE, 3, 40)
			despawn(visitor)
			return
		end
	else
		-- (L'inspecteur et le journaliste ont un badge : ils entrent par la sortie, sans billet.)
		Npc.walkTo(npc, GATE.exit + v3(0, 0, 8), 2, 40)
		Npc.walkTo(npc, GATE.exit + v3(0, 0, -6), 2, 20)
	end
	-- 3. Le tour du zoo.
	local tour = table.clone(PLAZA_TOUR)
	local networkStart = #tour + 1
	for _, item in networkTour() do
		table.insert(tour, item)
	end
	local exitStart = #tour + 1
	for _, item in EXIT_TOUR do
		table.insert(tour, item)
	end
	local trashChance = V.trash * (if Weather.is("school") then 1.6 else 1)
	local dropAt = if random:NextNumber() < trashChance and not special then random:NextInteger(3, math.max(4, #tour - 4)) else -1
	local wantsGift = not special and random:NextNumber() < 0.35
	for index, item in tour do
		if not npc.model.Parent then
			break
		end
		if closing then
			npc.humanoid.WalkSpeed = V.walk * 1.6
		end
		-- (Sur les allées : il va au stand dès qu'un besoin presse.)
		if not special and not closing and index >= networkStart and index < exitStart and typeof(item) == "Vector3" then
			local need = urgentNeed(visitor)
			if need then
				visitShop(visitor, need)
			end
		end
		if index == exitStart and wantsGift and not closing then
			visitShop(visitor, "gift")
		end
		if typeof(item) == "Vector3" then
			Npc.walkTo(npc, item + v3(random:NextNumber(-1.5, 1.5), 0, random:NextNumber(-1.5, 1.5)), 2, 40)
		elseif item.space then
			if not closing then
				watchSpace(visitor, item.space)
			end
		end
		if index == dropAt and not closing then
			throwTrash(visitor)
		end
		-- 4. En passant la sortie : sa note (ou celle de l'inspecteur).
		if item == GATE.exit then
			if visitor.kind == "inspector" then
				if not visitor.rated then
					visitor.rated = true
					inspect()
				end
			else
				addRating(visitor)
			end
		end
	end
	if visitor.kind == "inspector" and not visitor.rated then
		visitor.rated = true
		inspect()
	elseif visitor.kind ~= "inspector" then
		addRating(visitor)
	end
	despawn(visitor)
end

local function spawnOne(kind: string?)
	local special = kind == "inspector" or kind == "journalist"
	local kids = if Weather.is("school") then 0.75 else V.kids
	local look = if special then "visitor" elseif random:NextNumber() < kids then "kid" else "visitor"
	local npc = Npc.make(look, Config.BUS + v3(random:NextNumber(-3, 3), 0, random:NextNumber(-2, 2)), if kind == "inspector" then "Inspecteur" elseif kind == "journalist" then "Journaliste" else nil)
	if not npc then
		return
	end
	if special then
		-- (Un costume sombre.)
		for _, name in { "UpperTorso", "LowerTorso", "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg" } do
			local item = npc.model:FindFirstChild(name)
			if item and item:IsA("BasePart") then
				item.Color = if kind == "inspector" then Color3.fromRGB(40, 44, 56) else Color3.fromRGB(120, 40, 50)
			end
		end
	end
	npc.humanoid.WalkSpeed = V.walk * (if special then 1.5 else random:NextNumber(0.85, 1.15))
	local visitor = {
		npc = npc, scores = {}, bonus = 0, queueWait = 0, kind = kind or "visitor",
		needs = { hunger = random:NextNumber(0, 35), thirst = random:NextNumber(0, 35), bladder = random:NextNumber(0, 30) },
	}
	table.insert(visitors, visitor)
	Zoo.shared:SetAttribute("Visitors", #visitors)
	task.spawn(life, visitor)
end

-- LA JOURNÉE (appelé par Day.luau) -----------------------------------------------------------------------------------
-- Le matin : les heures d'arrivée de tous les visiteurs du jour (selon la météo et l'événement), et des invités.
function Visitors.morning(): number
	closing = false
	local count = math.floor(Config.visitorsPerDay(Enclosures.openCount(), Zoo.state.stars) * Weather.factor("visitors") + 0.5)
	schedule = {}
	for _ = 1, count do
		table.insert(schedule, random:NextNumber(Config.OPEN_HOUR, Config.LAST_ARRIVAL))
	end
	table.sort(schedule)
	specials = {}
	if Weather.event and Weather.event.hour then
		table.insert(specials, { hour = Weather.event.hour, kind = if Weather.event.id == "inspection" then "inspector" else "journalist" })
	end
	return count
end

-- À chaque instant de la journée : ceux dont c'est l'heure arrivent (s'il y a de la place), et leurs besoins montent.
local lastNeeds = os.clock()
function Visitors.update(clock: number)
	while schedule[1] and schedule[1] <= clock and #visitors < V.inside do
		table.remove(schedule, 1)
		spawnOne(nil)
	end
	for index = #specials, 1, -1 do
		if specials[index].hour <= clock then
			spawnOne(table.remove(specials, index).kind)
		end
	end
	local now = os.clock()
	local dt = math.min(now - lastNeeds, 2)
	lastNeeds = now
	local thirst = Weather.factor("thirst")
	for _, visitor in visitors do
		if visitor.scanned then
			visitor.needs.hunger += NEEDS.hunger * dt
			visitor.needs.thirst += NEEDS.thirst * dt * thirst
			visitor.needs.bladder += NEEDS.bladder * dt
		end
	end
end

-- 18 h : plus personne n'entre ; ceux qui sont dedans se dépêchent de sortir.
function Visitors.close()
	closing = true
	schedule = {}
	specials = {}
end

function Visitors.count(): number
	return #visitors
end

-- La nuit : ceux qui traînent encore disparaissent.
function Visitors.clear()
	for _, visitor in table.clone(visitors) do
		if visitor.scanned or visitor.kind ~= "visitor" then
			if visitor.kind == "inspector" then
				if not visitor.rated then
					visitor.rated = true
					inspect()
				end
			else
				addRating(visitor)
			end
		end
		despawn(visitor)
	end
	table.clear(queue)
	refreshGate()
end

function Visitors.queueLength(): number
	return #queue
end

-- (Pour les tests : les visiteurs en vie, et en faire venir un tout de suite.)
function Visitors.list()
	return visitors
end
function Visitors.spawn(kind: string?)
	spawnOne(kind)
end

function Visitors.start()
	for _, plot in Config.PLOTS do
		if plot.id ~= "farm" and plot.id ~= "s1" then
			table.insert(stops, { node = Paths.attach(plot.view), space = plot.id })
		end
	end
	Paths.prepare()
	Scanner.onScan = function(player)
		return Visitors.scan(player)
	end
	boothAlert, boothAlertText = Enclosures.alertBoard(Map.scanner, "Des visiteurs attendent !", Color3.fromRGB(230, 140, 40), 6)
	refreshGate()
end

return Visitors

-- LA JOURNÉE DU ZOO : le matin (8 h 30 → 9 h, on prépare), l'ouverture (9 h → 18 h, Config.DAY_SECONDS), le soir (les
-- derniers visiteurs sortent), la nuit (le bilan du jour, les salaires, les naissances, la sauvegarde ; le jour
-- suivant commence avec le bouton du bilan, ou tout seul après Config.NIGHT_AUTO secondes).
-- Les animaux n'ont faim et ne vieillissent que pendant les heures d'ouverture.
-- Les CONSEILS DU DÉBUT (Zoo.state.tuto) : 1 scanner un billet, 2 remplir une mangeoire, 3 ramasser une crotte,
-- 4 acheter l'espace des cerfs, 5 embaucher quelqu'un ; 0 = finis.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Animals = require(script.Parent.Animals)
local Config = require(ReplicatedStorage.Shared.Config)
local Map = require(script.Parent.Map)
local Market = require(script.Parent.Market)
local Weather = require(script.Parent.Weather)
local Staff = require(script.Parent.Staff)
local Tasks = require(script.Parent.Tasks)
local Visitors = require(script.Parent.Visitors)
local Zoo = require(script.Parent.Zoo)

local Day = {}

local shared = Zoo.shared
local HOURS_PER_SECOND = (Config.CLOSE_HOUR - Config.OPEN_HOUR) / Config.DAY_SECONDS
Day.speed = 1 -- (les tests accélèrent le temps)
local wantNext = false

local function setClock(clock: number)
	shared:SetAttribute("Clock", clock)
	Map.setClock(clock)
end
local function setPhase(phase: string)
	shared:SetAttribute("Phase", phase)
end

local TUTO_TASKS = { "scan", "feed", "clean" }
local function tutoCheck()
	local state = Zoo.state
	local plots = 0
	for _ in state.plots do
		plots += 1
	end
	if state.tuto == 4 and plots > 1 then
		state.tuto = 5
	end
	if state.tuto == 5 then
		for _, role in Config.STAFF_ORDER do
			if (state.staff[role] or 0) > 0 then
				state.tuto = 0
				Zoo.notify(nil, "tutoDone")
				break
			end
		end
	end
	shared:SetAttribute("Tuto", state.tuto)
end

-- LE BILAN DU SOIR
local function night()
	setPhase("night")
	Visitors.clear()
	setClock(21)
	local state, today = Zoo.state, Zoo.today
	-- Les salaires.
	local salaries = Staff.payroll()
	if salaries > 0 then
		state.money -= salaries
		today.money.salaries = -salaries
		shared:SetAttribute("Money", state.money)
	end
	-- La note du zoo : elle se rapproche de la moyenne des notes des visiteurs du jour.
	local before = state.stars
	if #today.ratings > 0 then
		local total = 0
		for _, value in today.ratings do
			total += value
		end
		local average = total / #today.ratings
		state.stars = math.clamp(state.stars + (average - state.stars) * Config.NOTE_BLEND, 0, 5)
		state.stars = math.floor(state.stars * 10 + 0.5) / 10
	end
	-- Les naissances de la nuit.
	local births = Animals.night()
	local total = 0
	for _, amount in today.money do
		total += amount
	end
	Zoo.publish()
	Zoo.remotes.bilan:FireAllClients({
		day = state.day,
		visitors = today.visitors,
		angry = today.angry,
		money = today.money,
		total = total,
		births = births,
		lost = today.lost or 0,
		old = today.old or 0,
		refused = today.refused or 0,
		weather = Weather.weather.fr,
		event = if Weather.event then Weather.event.fr else nil,
		inspection = today.inspection,
		journalist = today.journalist,
		starsBefore = before,
		starsAfter = state.stars,
		balance = state.money,
	})
	Zoo.save(false)
end

local function morning()
	Zoo.resetToday()
	setPhase("morning")
	setClock(Config.OPEN_HOUR - 0.5)
	-- La météo et l'événement du jour (Weather.luau), avant de savoir combien de visiteurs viendront.
	Weather.morning(Zoo.state.day)
	local expected = Visitors.morning()
	Market.refresh() -- (les autres zoos ont de nouveaux animaux chaque matin)
	-- (La tempête a renversé des poubelles : des papiers partout.)
	if Weather.weather.trash then
		local random = Random.new()
		for _ = 1, Weather.weather.trash do
			local edge = Config.PATH_EDGES[random:NextInteger(1, #Config.PATH_EDGES)]
			local a, b = Config.PATH_NODES[edge[1]], Config.PATH_NODES[edge[2]]
			Tasks.addTrash(a:Lerp(b, random:NextNumber()) + Vector3.new(random:NextNumber(-4, 4), 0, random:NextNumber(-4, 4)))
		end
	end
	shared:SetAttribute("Expected", expected)
	Zoo.notify(nil, "morning", Zoo.state.day, expected)
end

function Day.nextDay()
	wantNext = true
end

function Day.start()
	Zoo.resetToday()
	Tasks.onDone = function(_player, kind)
		local state = Zoo.state
		if state.tuto >= 1 and state.tuto <= 3 and TUTO_TASKS[state.tuto] == kind then
			state.tuto += 1
			tutoCheck()
		end
	end
	Zoo.remotes.nextDay.OnServerEvent:Connect(function()
		if shared:GetAttribute("Phase") == "night" then
			wantNext = true
		end
	end)
	task.spawn(function()
		morning()
		local clock = Config.OPEN_HOUR - 0.5
		local phaseStart = os.clock()
		local last = os.clock()
		while true do
			task.wait(0.25)
			local now = os.clock()
			local dt = (now - last) * Day.speed
			last = now
			local phase = shared:GetAttribute("Phase")
			if phase == "morning" then
				clock += dt * HOURS_PER_SECOND * 3
				if clock >= Config.OPEN_HOUR then
					clock = Config.OPEN_HOUR
					setPhase("open")
					Zoo.notify(nil, "open")
				end
				setClock(clock)
			elseif phase == "open" then
				local hours = dt * HOURS_PER_SECOND
				clock += hours
				Animals.tick(hours)
				Visitors.update(clock)
				if clock >= Config.CLOSE_HOUR then
					clock = Config.CLOSE_HOUR
					Visitors.close()
					setPhase("evening")
					phaseStart = now
					Zoo.notify(nil, "closing")
				end
				setClock(clock)
			elseif phase == "evening" then
				clock = math.min(clock + dt * HOURS_PER_SECOND, Config.CLOSE_HOUR + 1)
				setClock(clock)
				if Visitors.count() == 0 or (now - phaseStart) * Day.speed > Config.EVENING_MAX then
					night()
					phaseStart = now
					wantNext = false
				end
			elseif phase == "night" then
				if wantNext or (now - phaseStart) * Day.speed > Config.NIGHT_AUTO then
					wantNext = false
					Zoo.state.day += 1
					Zoo.publish()
					clock = Config.OPEN_HOUR - 0.5
					morning()
				end
			end
			tutoCheck()
		end
	end)
end

return Day

-- LA MÉTÉO ET LES ÉVÉNEMENTS DU JOUR (sa demande du 15/10, « 5 »). Tirés chaque matin (Day.luau) :
--   la météo (Config.WEATHER) : soleil, nuages, pluie (moins de visiteurs), canicule (les visiteurs ont très soif, les
--   mangeoires se vident plus vite), tempête (peu de visiteurs, des papiers partout) ;
--   un événement, parfois (Config.EVENTS) : une sortie scolaire, une inspection sanitaire (Visitors.luau fait venir
--   l'inspecteur), un journaliste (sa note compte pour 10).
-- L'écran les montre (attributs Weather et Event) et dessine la pluie (Main.client.luau).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Zoo = require(script.Parent.Zoo)

local Weather = {}

local random = Random.new()
Weather.weather = Config.WEATHER[1]
Weather.event = nil

local function pick(list)
	local roll = random:NextNumber()
	for _, item in list do
		roll -= item.chance
		if roll <= 0 then
			return item
		end
	end
	return nil
end

-- Le matin : la météo et l'événement du jour. (Le premier jour : beau temps, pas d'événement.)
function Weather.morning(day: number)
	Weather.weather = if day <= 1 then Config.WEATHER[1] else pick(Config.WEATHER) or Config.WEATHER[1]
	Weather.event = if day <= 2 then nil else pick(Config.EVENTS)
	Zoo.shared:SetAttribute("Weather", Weather.weather.id)
	Zoo.shared:SetAttribute("Event", if Weather.event then Weather.event.id else "")
	Zoo.notify(nil, "weather", Weather.weather.id)
	if Weather.event then
		Zoo.notify(nil, "event", Weather.event.id)
	end
end

-- Un réglage du jour : la météo d'abord, puis l'événement (1 s'il n'y a rien).
function Weather.factor(key: string): number
	local value = (Weather.weather[key] or 1)
	if Weather.event and Weather.event[key] then
		value *= Weather.event[key]
	end
	return value
end

function Weather.is(id: string): boolean
	return Weather.weather.id == id or (Weather.event ~= nil and Weather.event.id == id)
end

-- (Pour les tests : forcer la météo et l'événement.)
function Weather.force(weatherId: string?, eventId: string?)
	for _, item in Config.WEATHER do
		if item.id == weatherId then
			Weather.weather = item
		end
	end
	Weather.event = nil
	for _, item in Config.EVENTS do
		if item.id == eventId then
			Weather.event = item
		end
	end
	Zoo.shared:SetAttribute("Weather", Weather.weather.id)
	Zoo.shared:SetAttribute("Event", if Weather.event then Weather.event.id else "")
end

return Weather

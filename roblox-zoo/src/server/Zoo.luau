-- L'ÉTAT DU ZOO (un seul zoo par serveur : celui de l'hôte) : l'argent, le jour, la note, les espaces achetés, le
-- personnel, les animaux. Tout est sauvegardé sous le numéro de l'hôte (DataStore « Zoo_v1 », clé « z<numéro> »).
-- Ce que l'écran doit afficher est posé en attributs sur ReplicatedStorage.ZooState (Money, Day, Clock, Stars...).
--   LE VERROU (repris de MONDE) : tant que le zoo est ouvert dans un serveur, sa sauvegarde porte `lk` = { serveur,
--   heure }. Un autre serveur qui l'ouvre juste après attend que le premier ait fini d'écrire.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local Zoo = {}

local STORE_NAME = "Zoo_v1"
local LOCK_SECONDS = 200
local LOCK_WAIT = 2
local LOCK_TRIES = 6
local SAVE_EVERY = 60

local store = nil
if not RunService:IsStudio() then
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	store = if ok then result else nil
elseif workspace:GetAttribute("FakeStore") == true then
	-- (Le test de la sauvegarde dans Studio : une fausse sauvegarde en mémoire, aller-retour en JSON comme Roblox.)
	local memory = {}
	Zoo.fake = memory
	store = {
		GetAsync = function(_, key)
			return if memory[key] then HttpService:JSONDecode(memory[key]) else nil
		end,
		SetAsync = function(_, key, value)
			memory[key] = HttpService:JSONEncode(value)
		end,
	}
end
local freshRead = Instance.new("DataStoreGetOptions")
freshRead.UseCache = false

Zoo.state = nil
Zoo.hostId = 0
Zoo.hostName = ""
Zoo.canSave = false
Zoo.today = {}

-- Ce que l'écran voit.
local shared = Instance.new("Folder")
shared.Name = "ZooState"
shared.Parent = ReplicatedStorage
Zoo.shared = shared

-- LES MESSAGES (serveur → écran, et écran → serveur).
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage
local function remote(name: string): RemoteEvent
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = remotes
	return event
end
Zoo.remotes = {
	notify = remote("Notify"), -- (clé du message, valeurs) : un message en haut de l'écran
	bilan = remote("Bilan"), -- le bilan du soir
	hire = remote("Hire"), -- (rôle) embaucher
	fire = remote("Fire"), -- (rôle) renvoyer
	sell = remote("Sell"), -- (numéro de l'animal) le vendre à un autre zoo
	rename = remote("Rename"), -- (numéro de l'animal, prénom) le renommer
	marketBuy = remote("MarketBuy"), -- (numéro de l'offre) acheter un animal à un autre zoo
	marketSwap = remote("MarketSwap"), -- (numéro de l'échange, numéro de mon animal) échanger avec un autre zoo
	nextDay = remote("NextDay"), -- commencer le jour suivant
	treat = remote("Treat"), -- (numéro de l'animal) le soigner
	drop = remote("Drop"), -- poser ce qu'on porte
	popup = remote("Popup"), -- (position, texte, couleur) un « +10 $ » qui s'envole
	choose = remote("ChoosePlot"), -- (parcelle) ouvre la fenêtre du choix des animaux
	buyPlot = remote("BuyPlot"), -- (parcelle, animaux) acheter une parcelle pour ces animaux
}

-- Un message en haut de l'écran : à un joueur, ou à tous (player = nil).
function Zoo.notify(player: Player?, key: string, ...)
	if player then
		Zoo.remotes.notify:FireClient(player, key, ...)
	else
		Zoo.remotes.notify:FireAllClients(key, ...)
	end
end
function Zoo.popup(position: Vector3, text: string, color: Color3?)
	Zoo.remotes.popup:FireAllClients(position, text, color)
end

local function defaults()
	return {
		v = 1,
		money = Config.START_MONEY,
		day = 1,
		stars = Config.START_STARS,
		plots = { farm = "farm" }, -- [parcelle] = les animaux choisis (Config.HABITATS)
		buildings = {},
		staff = {},
		animals = {},
		nextId = 1,
		troughs = {},
		breed = {},
		poops = {},
		visitors = 0, -- visiteurs depuis le début
		born = 0, -- naissances depuis le début
		tuto = 1, -- l'étape des conseils du début (0 = finis)
	}
end

-- Remet d'aplomb des données lues (une vieille sauvegarde, un champ manquant).
local function clean(data)
	local fresh = defaults()
	if type(data) ~= "table" then
		return fresh
	end
	for key, value in fresh do
		if type(data[key]) ~= type(value) then
			data[key] = value
		end
	end
	data.plots.farm = "farm"
	for id, habitat in data.plots do
		if not Config.PLOT_BY_ID[id] or not Config.HABITAT_BY_ID[habitat] then
			data.plots[id] = nil
		end
	end
	for _, role in Config.STAFF_ORDER do
		data.staff[role] = math.clamp(math.floor(tonumber(data.staff[role]) or 0), 0, Config.STAFF[role].max)
	end
	local animals = {}
	for _, animal in data.animals do
		if type(animal) == "table" and Config.SPECIES[animal.s] and data.plots[animal.sp] then
			table.insert(animals, animal)
		end
	end
	data.animals = animals
	data.lk = nil
	return data
end

-- LA SAUVEGARDE --------------------------------------------------------------------------------------------------------
local function key(): string
	return "z" .. Zoo.hostId
end

local function readSaved(): (boolean, any)
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			return store:GetAsync(key())
		end)
		if ok then
			local tries = 0
			while tries < LOCK_TRIES
				and type(result) == "table"
				and type(result.lk) == "table"
				and result.lk[1] ~= game.JobId
				and os.time() - (tonumber(result.lk[2]) or 0) < LOCK_SECONDS
			do
				tries += 1
				task.wait(LOCK_WAIT)
				local again, fresh = pcall(function()
					return store:GetAsync(key(), freshRead)
				end)
				if again then
					result = fresh
				end
			end
			return true, result
		end
		warn(`[ZOO] lecture du zoo {key()} ratée ({attempt}/3) : {result}`)
		task.wait(2)
	end
	return false, nil
end

-- Charge le zoo de l'hôte. (Studio sans fausse sauvegarde : un zoo tout neuf, jamais enregistré.)
function Zoo.load(hostId: number, hostName: string)
	Zoo.hostId = hostId
	Zoo.hostName = hostName
	local data, canSave = defaults(), store == nil
	if store then
		local ok, result = readSaved()
		if ok then
			data, canSave = clean(result), true
		end
	end
	Zoo.state = data
	Zoo.canSave = canSave and store ~= nil
	shared:SetAttribute("HostId", hostId)
	shared:SetAttribute("HostName", hostName)
	Zoo.publish()
	return data
end

-- final : la dernière sauvegarde (le zoo ferme) : elle enlève le verrou.
function Zoo.save(final: boolean?): boolean
	if not Zoo.canSave or not Zoo.state or not store then
		return false
	end
	Zoo.state.lk = if final then nil else { game.JobId, os.time() }
	local ok, problem = pcall(function()
		store:SetAsync(key(), Zoo.state)
	end)
	if not ok then
		warn(`[ZOO] sauvegarde ratée : {problem}`)
	end
	return ok
end

function Zoo.startSaving()
	task.spawn(function()
		while true do
			task.wait(SAVE_EVERY)
			Zoo.save(false)
		end
	end)
	game:BindToClose(function()
		local done = false
		task.spawn(function()
			Zoo.save(true)
			done = true
		end)
		local deadline = os.clock() + 20
		while not done and os.clock() < deadline do
			task.wait(0.2)
		end
	end)
	if Zoo.fake then
		Zoo.test = { read = readSaved, clean = clean }
	end
end

-- L'ARGENT --------------------------------------------------------------------------------------------------------------
-- Les comptes du jour, pour le bilan du soir : today[raison] = somme (positive = gagné, négative = dépensé).
function Zoo.resetToday()
	Zoo.today = { money = {}, visitors = 0, angry = 0, births = 0, lost = 0, ratings = {}, startStars = Zoo.state.stars }
end

local function count(reason: string, amount: number)
	local money = Zoo.today.money
	if money then
		money[reason] = (money[reason] or 0) + amount
	end
end

function Zoo.addMoney(amount: number, reason: string)
	Zoo.state.money += amount
	count(reason, amount)
	shared:SetAttribute("Money", Zoo.state.money)
end

-- Paie si le zoo a assez d'argent. Renvoie true si c'est payé.
function Zoo.spend(amount: number, reason: string, player: Player?): boolean
	if Zoo.state.money < amount then
		if player then
			Zoo.notify(player, "noMoney", amount)
		end
		return false
	end
	Zoo.state.money -= amount
	count(reason, -amount)
	shared:SetAttribute("Money", Zoo.state.money)
	return true
end

-- Le temps du zoo en jours (le jour, plus la part de la journée d'ouverture déjà passée).
function Zoo.days(): number
	local clock = shared:GetAttribute("Clock") or Config.OPEN_HOUR
	local part = math.clamp((clock - Config.OPEN_HOUR) / (Config.CLOSE_HOUR - Config.OPEN_HOUR), 0, 1)
	return Zoo.state.day + part
end

-- Met l'écran à jour (argent, jour, note, espaces, personnel).
function Zoo.publish()
	local state = Zoo.state
	shared:SetAttribute("Money", state.money)
	shared:SetAttribute("Day", state.day)
	shared:SetAttribute("Stars", state.stars)
	shared:SetAttribute("Tuto", state.tuto)
	for _, plot in Config.PLOTS do
		shared:SetAttribute("Plot_" .. plot.id, state.plots[plot.id] or "")
	end
	for _, building in Config.BUILDINGS do
		shared:SetAttribute("Building_" .. building.id, state.buildings[building.id] == true)
	end
	for _, role in Config.STAFF_ORDER do
		shared:SetAttribute("Staff_" .. role, state.staff[role] or 0)
	end
end

-- 1500 -> « 1 500 ».
function Zoo.format(value: number): string
	local text = tostring(math.floor(math.abs(value) + 0.5))
	local out = text:reverse():gsub("(%d%d%d)", "%1 "):reverse()
	out = out:gsub("^ ", "")
	return (if value < 0 then "-" else "") .. out
end

-- Les joueurs du serveur (l'hôte et ses invités).
function Zoo.players(): { Player }
	return Players:GetPlayers()
end

return Zoo

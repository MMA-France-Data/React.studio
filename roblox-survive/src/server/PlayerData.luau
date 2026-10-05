-- Sauvegarde de chaque joueur : ses pièces, le niveau de ses trois machines, la meilleure salle réussie, ses
-- tickets, ses œufs et son enclos.
-- Dans Studio, rien n'est écrit chez Roblox : les données restent en mémoire le temps du test.
-- Les valeurs sont aussi posées en attributs sur le joueur (Coins, Speed, Jump, Force, Best, Tickets,
-- Bag, Places, Spots, Pet, PetRarity, PetSpot, Income) : l'écran les lit là.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Pets = require(ReplicatedStorage.Shared.Pets)

local PlayerData = {}

local STORE_NAME = "Survive_v1"
local SAVE_EVERY = 120

local store = nil
if not RunService:IsStudio() then
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	store = if ok then result else nil
end

-- [joueur] = { data = {...}, canSave = bool, dirty = bool }
local sessions = {}
local loadedCallbacks = {}

local function defaults()
	return {
		coins = 0,
		levels = { Speed = 0, Jump = 0, Force = 0 },
		best = 0,
		tickets = {}, -- tickets gagnés dans les salles : ["3"] = nombre de tickets de la salle 3
		bag = {}, -- œufs pas encore posés : { a = animal, q = rareté, r = salle }
		places = Pets.SPOTS_FREE, -- places de l'enclos
		-- places occupées : ["1"] = { a, q, r, t = heure d'éclosion (os.time) } pour un œuf qui couve,
		-- ou { a, q, v = valeur cachée } pour un familier
		spots = {},
		equipped = "", -- numéro de la place du familier qui suit le joueur
	}
end

-- Remet d'aplomb des données lues (champ manquant, valeur impossible).
local function clean(raw)
	local data = defaults()
	if type(raw) ~= "table" then
		return data
	end
	if type(raw.coins) == "number" and raw.coins >= 0 then
		data.coins = math.floor(raw.coins)
	end
	if type(raw.best) == "number" then
		data.best = math.clamp(math.floor(raw.best), 0, #Config.ROOMS)
	end
	if type(raw.levels) == "table" then
		for _, name in Config.MACHINES do
			local level = raw.levels[name]
			if type(level) == "number" then
				data.levels[name] = math.clamp(math.floor(level), 0, Config.MAX_LEVEL)
			end
		end
	end
	if type(raw.tickets) == "table" then
		for room = 1, #Config.ROOMS do
			local count = raw.tickets[tostring(room)]
			if type(count) == "number" and count >= 1 then
				data.tickets[tostring(room)] = math.floor(count)
			end
		end
	end
	local function validEgg(egg): boolean
		return type(egg) == "table" and Pets.DEFS[egg.a] ~= nil and type(egg.q) == "number" and Pets.RARITIES[egg.q] ~= nil
	end
	if type(raw.bag) == "table" then
		for _, egg in raw.bag do
			if validEgg(egg) and #data.bag < Pets.MAX_BAG then
				table.insert(data.bag, { a = egg.a, q = egg.q, r = if type(egg.r) == "number" then egg.r else 1 })
			end
		end
	end
	if type(raw.places) == "number" then
		data.places = math.clamp(math.floor(raw.places), Pets.SPOTS_FREE, Pets.SPOTS_MAX)
	end
	if type(raw.spots) == "table" then
		for index = 1, data.places do
			local spot = raw.spots[tostring(index)]
			if validEgg(spot) then
				if type(spot.v) == "number" then
					data.spots[tostring(index)] = { a = spot.a, q = spot.q, v = math.floor(spot.v) }
				elseif type(spot.t) == "number" then
					data.spots[tostring(index)] = { a = spot.a, q = spot.q, r = spot.r, t = spot.t }
				end
			end
		end
	end
	if type(raw.equipped) == "string" and data.spots[raw.equipped] and data.spots[raw.equipped].v then
		data.equipped = raw.equipped
	end
	return data
end

local function publish(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	local data = session.data
	player:SetAttribute("Coins", data.coins)
	player:SetAttribute("Best", data.best)
	for _, name in Config.MACHINES do
		player:SetAttribute(name, data.levels[name])
	end
	local tickets = 0
	for _, count in data.tickets do
		tickets += count
	end
	player:SetAttribute("Tickets", tickets)
	player:SetAttribute("Bag", #data.bag)
	player:SetAttribute("Places", data.places)
	player:SetAttribute("Spots", Pets.encode(data.spots))
	local follower = data.spots[data.equipped]
	player:SetAttribute("Pet", if follower and follower.v then follower.a else "")
	player:SetAttribute("PetRarity", if follower and follower.v then follower.q else 0)
	player:SetAttribute("PetSpot", data.equipped)
	player:SetAttribute("Income", Pets.income(data.spots))
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		stats.Room.Value = data.best
		stats.Coins.Value = data.coins
	end
end

local function load(player: Player)
	local data, canSave = defaults(), store == nil
	if store then
		for attempt = 1, 3 do
			local ok, result = pcall(function()
				return store:GetAsync("p" .. player.UserId)
			end)
			if ok then
				data, canSave = clean(result), true
				break
			end
			warn(`[Survive] lecture des données de {player.Name} ratée ({attempt}/3) : {result}`)
			task.wait(2)
		end
	end
	if not player:IsDescendantOf(Players) then
		return
	end
	-- Lecture impossible : le joueur joue quand même, mais rien n'est enregistré (sinon on écraserait sa sauvegarde).
	sessions[player] = { data = data, canSave = canSave, dirty = false }

	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local room = Instance.new("IntValue")
	room.Name = "Room"
	room.Parent = stats
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Parent = stats
	stats.Parent = player

	publish(player)
	player:SetAttribute("Loaded", true)
	for _, callback in loadedCallbacks do
		task.spawn(callback, player)
	end
end

local function save(player: Player)
	local session = sessions[player]
	if not session or not session.canSave or not session.dirty or not store then
		return
	end
	session.dirty = false
	local ok, result = pcall(function()
		store:SetAsync("p" .. player.UserId, session.data)
	end)
	if not ok then
		session.dirty = true
		warn(`[Survive] sauvegarde de {player.Name} ratée : {result}`)
	end
end

function PlayerData.get(player: Player)
	local session = sessions[player]
	return session and session.data
end

function PlayerData.onLoaded(callback: (Player) -> ())
	table.insert(loadedCallbacks, callback)
	for player in sessions do
		task.spawn(callback, player)
	end
end

local function touch(player: Player)
	sessions[player].dirty = true
	publish(player)
end

-- À appeler après avoir changé les données à la main (œufs, animaux) : sauvegarde et mise à jour de l'écran.
function PlayerData.changed(player: Player)
	if sessions[player] then
		touch(player)
	end
end

function PlayerData.addCoins(player: Player, amount: number)
	local data = PlayerData.get(player)
	if data then
		data.coins = math.max(0, data.coins + math.floor(amount))
		touch(player)
	end
end

function PlayerData.setLevel(player: Player, machine: string, level: number)
	local data = PlayerData.get(player)
	if data then
		data.levels[machine] = math.clamp(level, 0, Config.MAX_LEVEL)
		touch(player)
	end
end

function PlayerData.setBest(player: Player, room: number)
	local data = PlayerData.get(player)
	if data and room > data.best then
		data.best = room
		touch(player)
	end
end

-- Pour les tests dans Studio : remet le joueur à zéro.
function PlayerData.reset(player: Player)
	local session = sessions[player]
	if session then
		session.data = defaults()
		touch(player)
	end
end

function PlayerData.start()
	Players.PlayerAdded:Connect(load)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		save(player)
		sessions[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(SAVE_EVERY)
			for player in sessions do
				task.spawn(save, player)
			end
		end
	end)
	game:BindToClose(function()
		for player in sessions do
			task.spawn(save, player)
		end
		task.wait(2)
	end)
end

return PlayerData

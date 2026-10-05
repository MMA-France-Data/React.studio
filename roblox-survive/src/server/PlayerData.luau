-- Sauvegarde de chaque joueur : ses pièces, le niveau de ses trois machines, la meilleure salle réussie, ses œufs
-- qui couvent et sa collection de familiers.
-- Dans Studio, rien n'est écrit chez Roblox : les données restent en mémoire le temps du test.
-- Les valeurs sont aussi posées en attributs sur le joueur (Coins, Speed, Jump, Force, Best, Eggs,
-- EggCount, Pets, Pet, PetRarity, Income) : l'écran les lit là.
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
		eggs = {}, -- œufs qui couvent dans l'enclos : { a = animal, r = salle, t = heure d'éclosion (os.time) }
		pets = {}, -- la collection : [animal] = { true/false pour chaque rareté }
		equipped = "", -- l'animal qui suit le joueur
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
	if type(raw.eggs) == "table" then
		for _, egg in raw.eggs do
			if type(egg) == "table" and Pets.DEFS[egg.a] and type(egg.r) == "number" and type(egg.t) == "number" and #data.eggs < Pets.MAX_EGGS then
				table.insert(data.eggs, { a = egg.a, r = egg.r, t = egg.t })
			end
		end
	end
	if type(raw.pets) == "table" then
		for _, name in Pets.ORDER do
			local saved = raw.pets[name]
			if type(saved) == "table" then
				local list = {}
				for rarity = 1, #Pets.RARITIES do
					list[rarity] = saved[rarity] == true
				end
				data.pets[name] = list
			end
		end
	end
	if type(raw.equipped) == "string" and Pets.best(data.pets[raw.equipped]) > 0 then
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
	-- Les œufs : « Dragon|1759680000,Rock|1759680060 » (animal et heure d'éclosion), pour les montrer dans l'enclos.
	local eggs = {}
	for i = 1, math.min(#data.eggs, Pets.NEST) do
		eggs[i] = data.eggs[i].a .. "|" .. data.eggs[i].t
	end
	player:SetAttribute("Eggs", table.concat(eggs, ","))
	player:SetAttribute("EggCount", #data.eggs)
	player:SetAttribute("Pets", Pets.encode(data.pets))
	player:SetAttribute("Pet", data.equipped)
	player:SetAttribute("PetRarity", Pets.best(data.pets[data.equipped]))
	player:SetAttribute("Income", Pets.income(data.pets))
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

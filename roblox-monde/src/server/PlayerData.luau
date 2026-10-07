-- Sauvegarde de chaque joueur : ses pièces, son niveau et son XP, son épée, la dernière zone ouverte, ses œufs, son
-- enclos et son équipe de combat.
-- Dans Studio, rien n'est écrit chez Roblox : les données restent en mémoire le temps du test.
-- Les valeurs sont aussi posées en attributs sur le joueur (Coins, Level, Xp, XpNeed, Sword, Zone, Bag, BagNext,
-- Places, Spots, Team, TeamPets, PetLuck, Income) : l'écran les lit là.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Pets = require(ReplicatedStorage.Shared.Pets)

local PlayerData = {}

local STORE_NAME = "Monde_v1"
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
		level = 1,
		xp = 0, -- XP gagnée dans le niveau en cours
		sword = 1, -- niveau de l'épée
		zone = 1, -- la zone la plus lointaine ouverte (battre le boss de la zone n ouvre la n + 1)
		bag = {}, -- œufs pas encore posés : { a = animal, q = rang, r = zone, b = valeur tirée }
		places = Pets.SPOTS_FREE, -- places de l'enclos
		-- places occupées : ["1"] = { a, q, r, t = heure d'éclosion (os.time) } pour un œuf qui couve,
		-- ou { a, q, v = valeur cachée } pour un familier
		spots = {},
		team = {}, -- les places des familiers qui se battent avec le joueur (Config.TEAM au plus)
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
	if type(raw.level) == "number" then
		data.level = math.max(1, math.floor(raw.level))
	end
	if type(raw.xp) == "number" and raw.xp >= 0 then
		data.xp = math.floor(raw.xp)
	end
	if type(raw.sword) == "number" then
		data.sword = math.max(1, math.floor(raw.sword))
	end
	if type(raw.zone) == "number" then
		data.zone = math.clamp(math.floor(raw.zone), 1, #Config.ZONES)
	end
	local function validEgg(egg): boolean
		return type(egg) == "table" and Pets.DEFS[egg.a] ~= nil and type(egg.q) == "number" and Pets.RARITIES[egg.q] ~= nil
	end
	if type(raw.bag) == "table" then
		for _, egg in raw.bag do
			if validEgg(egg) and #data.bag < Pets.MAX_BAG then
				table.insert(data.bag, { a = egg.a, q = egg.q, r = if type(egg.r) == "number" then egg.r else 1, b = if type(egg.b) == "number" then egg.b else nil })
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
					data.spots[tostring(index)] = { a = spot.a, q = spot.q, v = math.floor(spot.v), l = if type(spot.l) == "number" then math.clamp(math.floor(spot.l), 0, 10000) else nil, x = tonumber(spot.x), z = tonumber(spot.z), lv = if type(spot.lv) == "number" then math.max(1, math.floor(spot.lv)) else 1, xp = if type(spot.xp) == "number" then math.max(0, math.floor(spot.xp)) else 0 }
				elseif type(spot.t) == "number" then
					data.spots[tostring(index)] = { a = spot.a, q = spot.q, r = spot.r, b = if type(spot.b) == "number" then spot.b else nil, t = spot.t, d = tonumber(spot.d) or 0, x = tonumber(spot.x) or 10, z = tonumber(spot.z) or 16 }
				end
			end
		end
	end
	if type(raw.team) == "table" then
		for _, key in raw.team do
			if type(key) == "string" and data.spots[key] and data.spots[key].v and not table.find(data.team, key) and #data.team < Config.TEAM then
				table.insert(data.team, key)
			end
		end
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
	player:SetAttribute("Level", data.level)
	player:SetAttribute("Xp", data.xp)
	player:SetAttribute("XpNeed", Config.xpNeed(data.level))
	player:SetAttribute("Sword", data.sword)
	player:SetAttribute("Zone", data.zone)
	player:SetAttribute("Bag", #data.bag)
	-- Le prochain œuf à poser (« Fox:6:73 » : l'animal, son rang, et la grosseur de l'œuf de 0 à 100).
	local first = data.bag[1]
	-- (Seulement si le joueur l'a SORTI de son sac : attribut « Carrying », posé par Eggs.take.)
	if not player:GetAttribute("Carrying") then
		first = nil
	end
	player:SetAttribute("BagNext", if first then first.a .. ":" .. first.q .. ":" .. math.floor((if first.b then Pets.along(first.q, first.b) else 0.5) * 100 + 0.5) else "")
	-- Les œufs du sac, groupés pour la fenêtre des œufs (« Duck:1:12,Pig:3:2 » : animal, rang, nombre).
	local groups, order = {}, {}
	for _, egg in data.bag do
		local key = egg.a .. ":" .. egg.q
		if not groups[key] then
			groups[key] = 0
			table.insert(order, key)
		end
		groups[key] += 1
	end
	for i, key in order do
		order[i] = key .. ":" .. groups[key]
	end
	player:SetAttribute("BagList", table.concat(order, ","))
	player:SetAttribute("Places", data.places)
	player:SetAttribute("Spots", Pets.encode(data.spots))
	-- L'équipe de combat : les places (« 2,5,1 »), et de quoi dessiner chaque familier (« Fox:6:73;Dog:4:20 »).
	local members, luck = {}, 0
	for _, key in data.team do
		local pet = data.spots[key]
		if pet and pet.v then
			table.insert(members, pet.a .. ":" .. pet.q .. ":" .. math.floor(Pets.alongOf(pet) * 100 + 0.5) .. ":" .. (pet.lv or 1))
			luck = math.max(luck, Pets.luckOf(pet))
		end
	end
	player:SetAttribute("Team", table.concat(data.team, ","))
	player:SetAttribute("TeamPets", table.concat(members, ";"))
	-- Le bonus de chance d'œuf rare (en %) : celui du meilleur familier de l'équipe.
	player:SetAttribute("PetLuck", luck)
	player:SetAttribute("Income", Pets.income(data.spots))
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		stats.Level.Value = data.level
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
			warn(`[Monde] lecture des données de {player.Name} ratée ({attempt}/3) : {result}`)
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
	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Parent = stats
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
		warn(`[Monde] sauvegarde de {player.Name} ratée : {result}`)
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

-- Ajoute de l'XP. Renvoie le nombre de niveaux gagnés.
function PlayerData.addXp(player: Player, amount: number): number
	local data = PlayerData.get(player)
	if not data then
		return 0
	end
	data.xp += math.floor(amount)
	local gained = 0
	while data.xp >= Config.xpNeed(data.level) do
		data.xp -= Config.xpNeed(data.level)
		data.level += 1
		gained += 1
	end
	touch(player)
	return gained
end

-- Ouvre la zone `zone` (si elle existe et n'est pas déjà ouverte). Renvoie true si elle vient d'être ouverte.
function PlayerData.openZone(player: Player, zone: number): boolean
	local data = PlayerData.get(player)
	if data and zone > data.zone and Config.ZONES[zone] then
		data.zone = zone
		touch(player)
		return true
	end
	return false
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

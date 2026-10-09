-- Sauvegarde de chaque joueur : ses pièces, son niveau et son XP, son épée, la dernière zone ouverte, ses œufs, son
-- enclos et son équipe de combat.
-- Dans Studio, rien n'est écrit chez Roblox : les données restent en mémoire le temps du test.
-- Les valeurs sont aussi posées en attributs sur le joueur (Coins, Level, Xp, XpNeed, Sword, Zone, Bag, BagNext,
-- Places, Spots, Team, TeamPets, PetLuck, Income) : l'écran les lit là.
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
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

-- LES PASS À VIE (Store.luau) : XP x2 et pièces x2. Roblox garde l'achat ; il est posé en attribut sur le joueur à
-- son arrivée (load) et lu ici. coins : TOUTES les pièces (monstres, enclos, hors ligne).
local PASS_ATTR = { xp = "PassXp", coins = "PassCoins" }
function PlayerData.passMult(player: Player, kind: string): number
	return if player:GetAttribute(PASS_ATTR[kind]) == true then Config.STORE.PASS_MULT else 1
end

local function defaults()
	return {
		coins = 0,
		level = 1,
		xp = 0, -- XP gagnée dans le niveau en cours
		sword = 1, -- niveau de l'épée
		sv = 3, -- version de la liste des épées (3 = cinq épées au monde 1)
		mv = 2, -- version de la monnaie (2 = tout est multiplié par 10)
		seen = 0, -- heure (os.time) de la dernière sauvegarde : sert au revenu hors ligne
		played = 0, -- temps de jeu, en secondes (compté par Leaderboards.luau, pour le classement)
		sd = 0, -- bonus « reste encore » : le jour (os.time() // 86400) où il a été donné en dernier
		bx = 0, -- ... et l'heure (os.time) où le bonus d'XP s'arrête
		po = { rank = 0, xp = 0, coins = 0, damage = 0 }, -- les potions en réserve (Potions.luau)
		rc = {}, -- les reçus des derniers achats en Robux déjà comptés (Store.luau)
		tu = 1, -- l'étape du mini tutoriel (Tutorial.luau) ; 0 = pas de tutoriel, ou fini
		px = 0, -- ... et l'heure (os.time) où s'arrêtent celles qui ont été bues : XP, pièces, dégâts
		pc = 0,
		pd = 0,
		gt = Config.GIFT_EVERY - Config.GIFT_FIRST, -- cadeau du temps de jeu : secondes jouées depuis le dernier cadeau (Rewards.luau)
		gs = 1, -- ... et le numéro du prochain cadeau (Config.GIFTS)
		vm = 60, -- réglages du joueur : volume de la musique et des sons, de 0 à 100 (Sounds.luau)
		vf = 10,
		vv = 2, -- version de ces réglages (2 = départ à 60 et 10)
		cv = 3, -- version des collections (3 = la jungle a le gorille et le tigre)
		zone = 1, -- la zone la plus lointaine ouverte (battre le boss de la zone n ouvre la n + 1)
		bag = {}, -- œufs pas encore posés : { a = animal, q = rang, r = zone, b = valeur tirée }
		places = Pets.SPOTS_FREE, -- places de l'enclos
		-- places occupées : ["1"] = { a, q, r, t = heure d'éclosion (os.time) } pour un œuf qui couve,
		-- ou { a, q, v = valeur cachée } pour un familier
		spots = {},
		store = {}, -- LE SAC : les familiers rangés hors de l'enclos ({ a, q, v, l, lv, xp }) ; ils n'y rapportent rien
		team = {}, -- les places des familiers qui se battent avec le joueur (Config.TEAM au plus)
	}
end

-- Remet d'aplomb des données lues (champ manquant, valeur impossible).
local function clean(raw)
	local data = defaults()
	if type(raw) ~= "table" then
		return data
	end
	-- (08/10 : les animaux du monde 2 ont changé. Les œufs et les familiers des anciens, hérisson et compagnie,
	-- deviennent l'animal du même rang de la nouvelle liste : ils gardent leur force.)
	-- (Puis la jungle : chaque ancien animal devient celui du même rang de la nouvelle liste.)
	if raw.cv ~= 3 then
		local swap = { Toucan = "Anaconda", Monkey = "Crocodile", Anaconda = "Jaguar", Crocodile = "Gorilla", Jaguar = "Tiger" }
		for _, list in { raw.bag, raw.spots, raw.store } do
			if type(list) == "table" then
				for _, item in list do
					if type(item) == "table" and swap[item.a] then
						item.a = swap[item.a]
					end
				end
			end
		end
	end
	if raw.cv ~= 2 and raw.cv ~= 3 then
		local swap = { Hedgehog = "Boar", Squirrel = "Ram", Skunk = "Deer", Beaver = "Lynx", Raccoon = "Wolf", Badger = "Bear" }
		for _, list in { raw.bag, raw.spots, raw.store } do
			if type(list) == "table" then
				for _, item in list do
					if type(item) == "table" and swap[item.a] then
						item.a = swap[item.a]
					end
				end
			end
		end
	end
	if type(raw.coins) == "number" and raw.coins >= 0 then
		-- (08/10 : tous les prix ont été multipliés par 10 ; les pièces des anciennes sauvegardes aussi.)
		data.coins = math.floor(raw.coins * (if raw.mv == 2 then 1 else 10))
	end
	if type(raw.level) == "number" then
		data.level = math.max(1, math.floor(raw.level))
	end
	if type(raw.xp) == "number" and raw.xp >= 0 then
		data.xp = math.floor(raw.xp)
	end
	if type(raw.sword) == "number" then
		data.sword = math.max(1, math.floor(raw.sword))
		-- (Une épée a été glissée entre la 2 et la 3 le 08/10 : les anciennes sauvegardes gardent leurs dégâts.)
		-- (Une autre le même jour, encore entre la 2 et la 3 : sv 3.)
		if data.sword >= 3 and raw.sv ~= 3 then
			data.sword += if raw.sv == 2 then 1 else 2
		end
	end
	if type(raw.zone) == "number" then
		data.zone = math.clamp(math.floor(raw.zone), 1, #Config.ZONES)
	end
	if type(raw.seen) == "number" then
		data.seen = math.floor(raw.seen)
	end
	if type(raw.played) == "number" and raw.played >= 0 then
		data.played = math.floor(raw.played)
	end
	for _, key in { "sd", "bx", "px", "pc", "pd" } do
		if type(raw[key]) == "number" and raw[key] >= 0 then
			data[key] = math.floor(raw[key])
		end
	end
	-- (Une sauvegarde d'avant le tutoriel : seul celui qui n'a encore rien fait le voit.)
	if type(raw.tu) == "number" then
		data.tu = math.clamp(math.floor(raw.tu), 0, Config.TUTORIAL_STEPS)
	else
		data.tu = if (tonumber(raw.level) or 1) <= 1 and (tonumber(raw.sword) or 1) <= 1 then 1 else 0
	end
	if type(raw.rc) == "table" then
		for _, id in raw.rc do
			if type(id) == "string" and #data.rc < 40 then
				table.insert(data.rc, id)
			end
		end
	end
	if type(raw.po) == "table" then
		for kind in Config.POTIONS do
			if type(raw.po[kind]) == "number" and raw.po[kind] >= 0 then
				data.po[kind] = math.floor(raw.po[kind])
			end
		end
	end
	if type(raw.gt) == "number" and raw.gt >= 0 then
		data.gt = math.floor(raw.gt)
	end
	if type(raw.gs) == "number" then
		data.gs = math.clamp(math.floor(raw.gs), 1, #Config.GIFTS)
	end
	-- (Un joueur resté sur les anciens réglages de départ, 30 et 70, passe aux nouveaux.)
	local untouched = raw.vv ~= 2 and raw.vm == 30 and raw.vf == 70
	for _, key in { "vm", "vf" } do
		if type(raw[key]) == "number" and not untouched then
			data[key] = math.clamp(math.floor(raw[key]), 0, 100)
		end
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
		local keys = {}
		for index = 1, data.places do
			table.insert(keys, index)
		end
		for index = Pets.EGG_FIRST, Pets.EGG_FIRST + Pets.EGG_SPOTS - 1 do
			table.insert(keys, index)
		end
		for _, index in keys do
			local spot = raw.spots[tostring(index)]
			if validEgg(spot) and (index <= data.places or type(spot.t) == "number") then
				if type(spot.v) == "number" then
					data.spots[tostring(index)] = { a = spot.a, q = spot.q, v = math.floor(spot.v), l = if type(spot.l) == "number" then math.clamp(math.floor(spot.l), 0, 10000) else nil, x = tonumber(spot.x), z = tonumber(spot.z), lv = if type(spot.lv) == "number" then math.max(1, math.floor(spot.lv)) else 1, xp = if type(spot.xp) == "number" then math.max(0, math.floor(spot.xp)) else 0 }
				elseif type(spot.t) == "number" then
					data.spots[tostring(index)] = { a = spot.a, q = spot.q, r = spot.r, b = if type(spot.b) == "number" then spot.b else nil, t = spot.t, d = tonumber(spot.d) or 0, x = tonumber(spot.x) or 10, z = tonumber(spot.z) or 16 }
				end
			end
		end
	end
	if type(raw.store) == "table" then
		for _, pet in raw.store do
			if validEgg(pet) and type(pet.v) == "number" and #data.store < Pets.STORE_MAX then
				table.insert(data.store, { a = pet.a, q = pet.q, v = math.floor(pet.v), l = if type(pet.l) == "number" then math.floor(pet.l) else nil, lv = if type(pet.lv) == "number" then math.max(1, math.floor(pet.lv)) else 1, xp = if type(pet.xp) == "number" then math.max(0, math.floor(pet.xp)) else 0 })
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
	player:SetAttribute("Store", Pets.encodeStore(data.store))
	-- L'équipe de combat : les places (« 2,5,1 »), et de quoi dessiner chaque familier (« Fox:6:73;Dog:4:20 »).
	local members, luck = {}, 0
	for _, key in data.team do
		local pet = data.spots[key]
		if pet and pet.v then
			table.insert(members, pet.a .. ":" .. pet.q .. ":" .. math.floor(Pets.alongOf(pet) * 100 + 0.5) .. ":" .. Pets.levelOf(pet))
			luck = math.max(luck, Pets.luckOf(pet))
		end
	end
	player:SetAttribute("Team", table.concat(data.team, ","))
	player:SetAttribute("TeamPets", table.concat(members, ";"))
	-- Le bonus de chance d'œuf rare (en %) : celui du meilleur familier de l'équipe.
	player:SetAttribute("PetLuck", luck)
	player:SetAttribute("Income", Pets.income(data.spots) * PlayerData.passMult(player, "coins"))
	player:SetAttribute("XpBoostUntil", data.bx)
	player:SetAttribute("Tutorial", data.tu or 0)
	player:SetAttribute("Potions", string.format("rank:%d,xp:%d,coins:%d,damage:%d", data.po.rank or 0, data.po.xp or 0, data.po.coins or 0, data.po.damage or 0))
	player:SetAttribute("PotXpUntil", data.px)
	player:SetAttribute("PotCoinsUntil", data.pc)
	player:SetAttribute("PotDamageUntil", data.pd)
	player:SetAttribute("VolMusic", data.vm)
	player:SetAttribute("VolFx", data.vf)
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
	-- SES PASS À VIE (avant de compter les pièces hors ligne, que le pass des pièces double aussi).
	for kind, pass in Config.STORE.passes do
		local owns = false
		if pass.id ~= 0 then
			for attempt = 1, 2 do
				local ok, result = pcall(function()
					return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
				end)
				if ok then
					owns = result == true
					break
				end
				task.wait(1)
			end
		end
		player:SetAttribute(PASS_ATTR[kind], owns)
	end
	if not player:IsDescendantOf(Players) then
		return
	end
	-- LE REVENU HORS LIGNE : ce que l'enclos a rapporté pendant l'absence (Config.OFFLINE_SHARE, OFFLINE_MAX).
	-- L'écran du joueur le lui annonce (attributs « Offline » et « OfflineTime »).
	local away = if data.seen > 0 then math.clamp(os.time() - data.seen, 0, Config.OFFLINE_MAX) else 0
	local earned = 0
	if canSave and away >= Config.OFFLINE_MIN then
		earned = math.floor(Pets.income(data.spots) * away * Config.OFFLINE_SHARE * PlayerData.passMult(player, "coins"))
		data.coins += earned
	end
	data.seen = os.time()
	player:SetAttribute("Offline", earned)
	player:SetAttribute("OfflineTime", away)
	-- Lecture impossible : le joueur joue quand même, mais rien n'est enregistré (sinon on écraserait sa sauvegarde).
	sessions[player] = { data = data, canSave = canSave, dirty = earned > 0 }

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
	session.data.seen = os.time()
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

-- Le joueur vient d'acheter (ou d'avoir, pour un test) ce pass : il sert tout de suite.
function PlayerData.setPass(player: Player, kind: string, owns: boolean)
	if PASS_ATTR[kind] then
		player:SetAttribute(PASS_ATTR[kind], owns == true)
		if sessions[player] then
			publish(player)
		end
	end
end

-- Sauvegarde tout de suite (après un achat en Robux). Renvoie true si c'est bien enregistré.
function PlayerData.saveNow(player: Player): boolean
	local session = sessions[player]
	if not session then
		return false
	end
	if not store then
		return true -- (Studio : rien n'est écrit chez Roblox)
	end
	if not session.canSave then
		return false
	end
	session.dirty = true
	save(player)
	return not session.dirty
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
		-- (Toujours enregistrer l'heure du départ : c'est d'elle que part le revenu hors ligne.)
		if sessions[player] then
			sessions[player].dirty = true
		end
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

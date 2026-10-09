-- LES TROIS CLASSEMENTS de la base (demande du créateur, 09/10 : « les tableaux avec temps de jeu / argent / dps
-- par seconde en comptant les 3 meilleurs familiers plus l'épée ») : trois grands panneaux au fond de l'allée.
--   time  : le temps de jeu (secondes, compté ici) ;
--   coins : les pièces que le joueur possède ;
--   power : ses dégâts par seconde = son épée + ses trois familiers les plus forts (enclos et sac compris).
-- Le classement est MONDIAL (un OrderedDataStore par panneau, écrit une fois par minute) ; les joueurs présents y
-- sont toujours à jour. Sans sauvegarde (un test dans Studio) : seulement les joueurs présents.
-- Ici, on calcule et on pose le résultat sur chaque panneau (attribut « Rows » : « nom<TAB>valeur » par ligne) ;
-- c'est l'écran de chaque joueur qui l'écrit, dans sa langue (étiquette « Leaderboard »).
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Pets = require(ReplicatedStorage.Shared.Pets)
local Build = require(script.Parent.Build)
local PlayerData = require(script.Parent.PlayerData)

local Leaderboards = {}

local TOP = 10
local WRITE_EVERY, SHOW_EVERY, COUNT_EVERY = 60, 10, 5
local NAVY = Color3.fromRGB(34, 40, 70)
local KINDS = {
	{ key = "time", store = "MondeTop_Time_v1", color = Color3.fromRGB(80, 200, 255) },
	{ key = "coins", store = "MondeTop_Coins_v2", color = Color3.fromRGB(255, 205, 60) },
	{ key = "power", store = "MondeTop_Power_v2", color = Color3.fromRGB(255, 90, 90) },
}

-- Les dégâts par seconde d'un joueur : son épée, plus ses trois meilleurs familiers.
function Leaderboards.power(data): number
	local best = {}
	for _, spot in data.spots do
		if spot.v then
			table.insert(best, Pets.damageOf(spot))
		end
	end
	for _, pet in data.store do
		table.insert(best, Pets.damageOf(pet))
	end
	table.sort(best, function(a, b)
		return a > b
	end)
	local total = Config.hitDamage(data.sword, data.level) / Config.ATTACK_COOLDOWN
	for index = 1, math.min(3, #best) do
		total += best[index]
	end
	return math.floor(total)
end

local function valueOf(kind: string, data): number
	local value = if kind == "time" then data.played or 0 elseif kind == "coins" then data.coins else Leaderboards.power(data)
	return math.clamp(math.floor(value), 0, 9e18)
end

function Leaderboards.start(world)
	-- Les panneaux : au fond de l'allée, côte à côte, tournés vers la grande porte.
	local folder = Instance.new("Folder")
	folder.Name = "Leaderboards"
	folder.Parent = world.gym.folder
	local boards, stores, global, names = {}, {}, {}, {}
	for index, kind in KINDS do
		local at = Vector3.new((index - 2) * 17.5, 0, -148)
		for _, x in { -6.6, 6.6 } do
			Build.part(folder, "TopPost", Vector3.new(1, 21, 1), at + Vector3.new(x, 10.5, 0), NAVY).CanQuery = false
		end
		Build.part(folder, "TopHead", Vector3.new(15.4, 1.2, 1.4), at + Vector3.new(0, 21.4, 0), kind.color).CanQuery = false
		local board = Build.part(folder, "TopBoard", Vector3.new(14.2, 17.6, 0.6), at + Vector3.new(0, 12, 0), Color3.fromRGB(20, 24, 44))
		board.CanQuery = false
		board:SetAttribute("Kind", kind.key)
		board:SetAttribute("Rows", "")
		board:AddTag("Leaderboard")
		boards[kind.key] = board
		global[kind.key] = {}
		local ok, result = pcall(function()
			return DataStoreService:GetOrderedDataStore(kind.store)
		end)
		stores[kind.key] = if ok then result else nil
	end

	local function nameOf(userId: number): string
		if not names[userId] then
			local player = Players:GetPlayerByUserId(userId)
			local ok, result = pcall(function()
				return if player then player.Name else Players:GetNameFromUserIdAsync(userId)
			end)
			names[userId] = if ok and result then result else "?"
		end
		return names[userId]
	end

	-- Ce qu'on affiche : le classement mondial lu en dernier, où les joueurs présents ont leur valeur du moment.
	local function show()
		for _, kind in KINDS do
			local values = {}
			for userId, value in global[kind.key] do
				values[userId] = value
			end
			for _, player in Players:GetPlayers() do
				local data = PlayerData.get(player)
				if data then
					values[player.UserId] = valueOf(kind.key, data)
					names[player.UserId] = player.Name
				end
			end
			local list = {}
			for userId, value in values do
				if value > 0 then
					table.insert(list, { userId = userId, value = value })
				end
			end
			table.sort(list, function(a, b)
				return if a.value == b.value then a.userId < b.userId else a.value > b.value
			end)
			local rows = {}
			for index = 1, math.min(TOP, #list) do
				table.insert(rows, nameOf(list[index].userId) .. "\t" .. string.format("%.0f", list[index].value))
			end
			boards[kind.key]:SetAttribute("Rows", table.concat(rows, "\n"))
		end
	end

	-- Le temps de jeu.
	task.spawn(function()
		while true do
			task.wait(COUNT_EVERY)
			for _, player in Players:GetPlayers() do
				local data = PlayerData.get(player)
				if data then
					data.played = (data.played or 0) + COUNT_EVERY
				end
			end
		end
	end)
	-- L'affichage, souvent (aucun appel à la sauvegarde).
	task.spawn(function()
		while true do
			pcall(show)
			task.wait(SHOW_EVERY)
		end
	end)
	-- La sauvegarde mondiale : on écrit la valeur de chaque joueur présent, puis on relit les premiers.
	task.spawn(function()
		while true do
			for _, kind in KINDS do
				local store = stores[kind.key]
				if store then
					for _, player in Players:GetPlayers() do
						local data = PlayerData.get(player)
						if data then
							pcall(function()
								store:SetAsync(tostring(player.UserId), valueOf(kind.key, data))
							end)
						end
					end
					local ok, pages = pcall(function()
						return store:GetSortedAsync(false, TOP)
					end)
					if ok and pages then
						local fresh = {}
						for _, entry in pages:GetCurrentPage() do
							local userId = tonumber(entry.key)
							if userId then
								fresh[userId] = entry.value
							end
						end
						global[kind.key] = fresh
					end
				end
			end
			task.wait(WRITE_EVERY)
		end
	end)
end

return Leaderboards

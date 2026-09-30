-- Classement global de la saison (OrderedDataStore).
-- (Le classement SOLO, de tous les temps, est à part : SoloLeaderboard.luau. Il se sert des noms d'ici.)
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserService = game:GetService("UserService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local MockDataStore = require(script.Parent.MockDataStore)

local Leaderboard = {}

local useMock = RunService:IsStudio() and Config.Data.MOCK_IN_STUDIO
local store = if useMock
	then MockDataStore.newOrdered()
	else DataStoreService:GetOrderedDataStore("RankedTD_Leaderboard_S" .. Config.SEASON)

local nameCache = {}

-- N'enregistre que les joueurs qui ont fini leurs matchs de placement.
function Leaderboard.submit(userId: number, mmr: number)
	task.spawn(function()
		local ok, err = pcall(function()
			store:SetAsync(tostring(userId), mmr)
		end)
		if not ok then
			warn("[Leaderboard] Échec de l'envoi :", err)
		end
	end)
end

-- Noms affichés des joueurs (tableaux du classé et du classement solo) : ceux qui sont sur ce serveur d'abord, puis
-- une seule demande à Roblox pour les autres. Gardés en mémoire. Renvoie { [userId] = nom } (« Joueur 123 » si
-- introuvable). Yield.
function Leaderboard.names(userIds: { number }): { [number]: string }
	local missing = {}
	for _, userId in userIds do
		if not nameCache[userId] then
			local player = Players:GetPlayerByUserId(userId)
			if player then
				nameCache[userId] = player.DisplayName
			elseif userId > 0 then
				table.insert(missing, userId)
			end
		end
	end
	if #missing > 0 then
		local ok, infos = pcall(function()
			return UserService:GetUserInfosByUserIdsAsync(missing)
		end)
		if ok then
			for _, info in infos do
				nameCache[info.Id] = info.DisplayName
			end
		end
	end
	local names = {}
	for _, userId in userIds do
		names[userId] = nameCache[userId] or ("Joueur " .. userId)
	end
	return names
end

-- Tests Studio (faux joueurs du classement solo) : retient ce nom pour ce numéro (nil = l'oublie).
function Leaderboard.rememberName(userId: number, name: string?)
	nameCache[userId] = name
end

-- Retourne { { userId, name, mmr } } trié du meilleur au moins bon. Yield.
function Leaderboard.fetchTop(count: number)
	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, count)
	end)
	if not ok then
		warn("[Leaderboard] Lecture impossible :", pages)
		return {}
	end

	local entries = {}
	local userIds = {}
	for _, item in pages:GetCurrentPage() do
		local userId = tonumber(item.key) or 0
		table.insert(userIds, userId)
		table.insert(entries, { userId = userId, mmr = item.value })
	end

	local names = Leaderboard.names(userIds)
	for _, entry in entries do
		entry.name = names[entry.userId]
	end
	return entries
end

return Leaderboard

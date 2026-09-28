-- Classement global de la saison (OrderedDataStore).
local DataStoreService = game:GetService("DataStoreService")
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

local function resolveNames(userIds: { number })
	local missing = {}
	for _, userId in userIds do
		if not nameCache[userId] and userId > 0 then
			table.insert(missing, userId)
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

	resolveNames(userIds)
	for _, entry in entries do
		entry.name = nameCache[entry.userId] or ("Joueur " .. entry.userId)
	end
	return entries
end

return Leaderboard

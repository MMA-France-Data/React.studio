-- LE MODE ADMIN (demande du créateur, 09/10 : « un mode uniquement pour moi, pour les admin abuse » ; il a choisi :
-- des BONUS POUR TOUS, dans TOUS LES SERVEURS à la fois).
--   Seul le créateur du jeu peut s'en servir (Admin.is) : le serveur le vérifie à chaque demande, un autre joueur ne
--   peut rien lancer même en trichant. (Dans Studio, tout le monde est admin : pour essayer.)
--   Un événement = une sorte (Config.EVENT : coins, xp, eggs) et une heure de fin (os.time). L'heure de fin est
--   posée en attribut sur workspace (« EventCoinsUntil »...) : Monsters.luau la lit quand il paie un monstre
--   (Config.eventMult), et l'écran de chaque joueur affiche le bandeau et le temps qu'il reste.
--   POUR TOUS LES SERVEURS : MessagingService prévient tout de suite les serveurs ouverts ; et l'heure de fin est
--   gardée dans un MemoryStore (elle s'efface toute seule à la fin), relu au démarrage et toutes les minutes : un
--   serveur qui s'ouvre pendant l'événement, ou qui a raté le message, le rattrape.
local MemoryStoreService = game:GetService("MemoryStoreService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local Admin = {}

local TOPIC = "MondeEvent_v1"
local notify
local store

function Admin.is(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId
	end
	-- (Jeu d'un groupe : son propriétaire.)
	local ok, rank = pcall(function()
		return player:GetRankInGroup(game.CreatorId)
	end)
	return ok and rank == 255
end

-- Pose l'heure de fin d'un événement dans CE serveur.
local function apply(kind: any, untilTime: any)
	local def = type(kind) == "string" and Config.EVENT[kind]
	if def and type(untilTime) == "number" then
		workspace:SetAttribute(def.attr, math.floor(untilTime))
	end
end

-- L'admin lance l'événement `kind` pour `minutes` minutes (0 = l'arrêter). Renvoie true si c'est parti.
function Admin.launch(player: Player, kind: string, minutes: number): boolean
	if not Admin.is(player) or not Config.EVENT[kind] or not table.find(Config.EVENT_MINUTES, minutes) and minutes ~= 0 then
		return false
	end
	local untilTime = if minutes > 0 then os.time() + minutes * 60 else 0
	apply(kind, untilTime)
	task.spawn(function()
		pcall(function()
			store:SetAsync(kind, untilTime, math.max(120, minutes * 60))
		end)
		pcall(function()
			MessagingService:PublishAsync(TOPIC, { kind = kind, t = untilTime })
		end)
	end)
	notify(player, if minutes > 0 then "adminSent" else "adminStopped")
	return true
end

function Admin.start(notifier)
	notify = notifier
	-- (Sans accès aux services du jeu, par exemple un fichier pas publié : l'événement ne vaut que pour ce serveur.)
	pcall(function()
		store = MemoryStoreService:GetSortedMap("MondeEvents_v1")
	end)
	local event = Instance.new("RemoteEvent")
	event.Name = "AdminEvent"
	event.Parent = ReplicatedStorage
	event.OnServerEvent:Connect(function(player, kind, minutes)
		if type(kind) == "string" and typeof(minutes) == "number" then
			Admin.launch(player, kind, minutes)
		end
	end)
	-- (L'attribut « Admin » ne sert qu'à montrer le bouton : le serveur revérifie à chaque demande.)
	local function mark(player: Player)
		if Admin.is(player) then
			player:SetAttribute("Admin", true)
		end
	end
	Players.PlayerAdded:Connect(mark)
	for _, player in Players:GetPlayers() do
		task.spawn(mark, player)
	end
	task.spawn(function()
		pcall(function()
			MessagingService:SubscribeAsync(TOPIC, function(message)
				local data = message.Data
				if type(data) == "table" then
					apply(data.kind, data.t)
				end
			end)
		end)
		while true do
			for kind in Config.EVENT do
				local ok, untilTime = pcall(function()
					return store:GetAsync(kind)
				end)
				if ok and type(untilTime) == "number" then
					apply(kind, untilTime)
				end
			end
			task.wait(60)
		end
	end)
end

return Admin

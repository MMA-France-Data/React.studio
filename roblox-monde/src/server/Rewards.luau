-- CE QUI FAIT REVENIR ET INVITER (demande du créateur, 09/10 : « une récompense toutes les 15 mn de jeu, inviter les
-- amis, ton ami est en ligne, ajoute-le pour + 10 % d'XP et de cash, tout ce marketing-là »).
--   1. LE CADEAU DU TEMPS DE JEU : toutes les Config.GIFT_EVERY secondes de jeu (comptées même d'une session à
--      l'autre), un cadeau à réclamer, QUATRE PAR JOUR au plus (Config.GIFTS : les quatre du jour, dans l'ordre ;
--      que des potions, la quatrième est la potion de rang). Le temps ne compte plus tant qu'un cadeau attend, ni
--      quand ceux du jour sont tous pris. Le compte repart à zéro chaque jour (data.gd, data.gc).
--   2. LE BONUS D'AMIS : chaque ami Roblox présent dans le même serveur donne Config.FRIEND_BONUS d'XP et de pièces
--      de combat en plus, jusqu'à Config.FRIEND_MAX amis. (Attribut « FriendBonus » : le bonus en %, lu par
--      Monsters.luau quand il paie un monstre battu.)
-- L'invitation elle-même (la fenêtre de Roblox) et le message « ton ami est en ligne » sont faits par l'écran du joueur.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Eggs = require(script.Parent.Eggs)
local PlayerData = require(script.Parent.PlayerData)
local Potions = require(script.Parent.Potions)

local Rewards = {}

local notify

local function today(): number
	return os.time() // 86400
end
-- Combien de cadeaux il a déjà pris AUJOURD'HUI (le compte repart à zéro chaque jour).
local function taken(data): number
	return if (data.gd or 0) == today() then (data.gc or 0) else 0
end

-- Attributs du joueur : « GiftIn » = secondes de jeu avant le prochain (0 = prêt) ; « GiftsTaken » = pris
-- aujourd'hui ; « GiftStep » = le numéro du prochain ; « GiftReset » = l'heure (os.time) des cadeaux de demain.
local function publish(player: Player)
	local data = PlayerData.get(player)
	if data then
		player:SetAttribute("GiftIn", math.max(0, Config.GIFT_EVERY - (data.gt or 0)))
		player:SetAttribute("GiftsTaken", taken(data))
		player:SetAttribute("GiftStep", taken(data) + 1)
		player:SetAttribute("GiftReset", (today() + 1) * 86400)
	end
end

-- Le joueur réclame son cadeau. Renvoie true s'il l'a reçu.
function Rewards.claim(player: Player): boolean
	local data = PlayerData.get(player)
	if not data then
		return false
	end
	local count = taken(data)
	if count >= #Config.GIFTS then
		notify(player, "giftDayDone", #Config.GIFTS)
		return false
	end
	if (data.gt or 0) < Config.GIFT_EVERY then
		return false
	end
	local gift = Config.GIFTS[count + 1]
	data.gt = 0
	data.gd, data.gc = today(), count + 1
	data.gs = data.gc + 1
	if gift.coins then
		-- (En pièces du monde où il est arrivé : autant que `coins` monstres de son camp du milieu.)
		local amount = Config.monster(data.zone, 3).coins * gift.coins
		PlayerData.addCoins(player, amount)
		notify(player, "giftCoins", amount)
	elseif gift.egg then
		Eggs.drop(player, data.zone, gift.egg)
		PlayerData.changed(player)
		notify(player, "giftEgg")
	else
		Potions.give(player, gift.potion, 1)
		notify(player, "giftPotion", gift.potion)
	end
	publish(player)
	return true
end

-- LE JOUEUR OUVRE LE MENU DE ROBLOX (il va peut-être partir). La première fois de la journée : + Config.STAY_XP d'XP
-- pendant Config.STAY_SECONDS, tout de suite (demande du créateur, 09/10). Renvoie true si le bonus vient d'être donné.
function Rewards.leaving(player: Player): boolean
	local data = PlayerData.get(player)
	if not data then
		return false
	end
	local today = os.time() // 86400
	if (data.sd or 0) >= today then
		notify(player, "stayBye")
		return false
	end
	data.sd = today
	data.bx = os.time() + Config.STAY_SECONDS
	PlayerData.changed(player)
	notify(player, "stayBonus", math.floor(Config.STAY_XP * 100 + 0.5), Config.STAY_SECONDS // 60)
	return true
end

-- Le bonus d'amis de chaque joueur, recompté à chaque arrivée ou départ. `joined` : celui qui vient d'arriver.
local function countFriends(joined: Player?)
	local players = Players:GetPlayers()
	for _, player in players do
		local friends = 0
		for _, other in players do
			if other ~= player then
				local ok, result = pcall(function()
					return player:IsFriendsWith(other.UserId)
				end)
				if ok and result then
					friends += 1
					if joined and (other == joined or player == joined) and other ~= player then
						notify(player, "friendHere", (if player == joined then other else joined).Name, math.floor(Config.FRIEND_BONUS * 100 + 0.5))
					end
				end
			end
		end
		if player:IsDescendantOf(Players) then
			player:SetAttribute("FriendBonus", math.floor(math.min(friends, Config.FRIEND_MAX) * Config.FRIEND_BONUS * 100 + 0.5))
		end
	end
end

function Rewards.start(notifier)
	notify = notifier
	local claim = Instance.new("RemoteEvent")
	claim.Name = "ClaimGift"
	claim.Parent = ReplicatedStorage
	claim.OnServerEvent:Connect(function(player)
		Rewards.claim(player)
	end)
	local leaving = Instance.new("RemoteEvent")
	leaving.Name = "Leaving"
	leaving.Parent = ReplicatedStorage
	local asked = {}
	leaving.OnServerEvent:Connect(function(player)
		-- (Pas plus d'une fois toutes les 20 secondes : le menu s'ouvre et se ferme à volonté.)
		if os.clock() - (asked[player] or -100) > 20 then
			asked[player] = os.clock()
			Rewards.leaving(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		asked[player] = nil
	end)
	PlayerData.onLoaded(function(player)
		publish(player)
		task.spawn(countFriends, player)
	end)
	Players.PlayerRemoving:Connect(function()
		task.defer(countFriends)
	end)
	-- Le temps de jeu, seconde après seconde.
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local data = PlayerData.get(player)
				-- (Le temps ne compte plus quand un cadeau attend, ni quand les cadeaux du jour sont tous pris.)
				if data and (data.gt or 0) < Config.GIFT_EVERY and taken(data) < #Config.GIFTS then
					data.gt = (data.gt or 0) + 1
					if data.gt >= Config.GIFT_EVERY then
						PlayerData.changed(player)
						notify(player, "giftReady")
					end
				end
				publish(player) -- (toutes les secondes : un nouveau jour remet le compte à zéro)
			end
		end
	end)
end

return Rewards

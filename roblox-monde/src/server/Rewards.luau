-- CE QUI FAIT REVENIR ET INVITER (demande du créateur, 09/10 : « une récompense toutes les 15 mn de jeu, inviter les
-- amis, ton ami est en ligne, ajoute-le pour + 10 % d'XP et de cash, tout ce marketing-là »).
--   1. LE CADEAU DU TEMPS DE JEU : toutes les Config.GIFT_EVERY secondes de jeu (comptées même d'une session à
--      l'autre), un cadeau à réclamer : des pièces, puis un œuf, puis plus de pièces, puis un œuf rare ; et ça
--      recommence. Le temps ne compte plus tant qu'un cadeau attend : il faut venir le prendre.
--      (Attributs du joueur : « GiftIn » = secondes avant le prochain, 0 = prêt ; « GiftStep » = lequel, 1 à 4.)
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

local function publish(player: Player)
	local data = PlayerData.get(player)
	if data then
		player:SetAttribute("GiftIn", math.max(0, Config.GIFT_EVERY - (data.gt or 0)))
		player:SetAttribute("GiftStep", data.gs or 1)
	end
end

-- Le joueur réclame son cadeau. Renvoie true s'il l'a reçu.
function Rewards.claim(player: Player): boolean
	local data = PlayerData.get(player)
	if not data or (data.gt or 0) < Config.GIFT_EVERY then
		return false
	end
	local step = math.clamp(data.gs or 1, 1, #Config.GIFTS)
	local gift = Config.GIFTS[step]
	data.gt = 0
	data.gs = step % #Config.GIFTS + 1
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
				if data and (data.gt or 0) < Config.GIFT_EVERY then
					data.gt = (data.gt or 0) + 1
					publish(player)
					if data.gt >= Config.GIFT_EVERY then
						PlayerData.changed(player)
						notify(player, "giftReady")
					end
				end
			end
		end
	end)
end

return Rewards

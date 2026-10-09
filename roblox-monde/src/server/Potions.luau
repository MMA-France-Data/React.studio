-- LES POTIONS (demande du créateur, 09/10 : « une potion pour monter de rang (un rang de compagnon, A à S), une
-- potion double XP et une potion double argent, comme ça on pourra les vendre aussi en Robux, avec une potion double
-- dégâts »).
--   Elles arrivent par les cadeaux gratuits (Rewards.luau), s'entassent dans data.po, et se boivent par la remote
--   « UsePotion » (kind, et la place du familier pour la potion de rang).
--   rank : monte la NOTE d'un familier de l'enclos d'un cran (C → B → A → S : Pets.raiseGrade).
--   xp, coins, damage : x Config.POTIONS[kind].mult pendant Config.POTIONS[kind].seconds. data.px, pc, pd gardent
--   l'heure (os.time) où ça s'arrête ; Monsters.luau les lit quand il paie un monstre ou compte un coup. En boire
--   une autre avant la fin rallonge le temps.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Pets = require(ReplicatedStorage.Shared.Pets)
local PlayerData = require(script.Parent.PlayerData)
local Monsters = require(script.Parent.Monsters)

local Potions = {}

local notify
local UNTIL = { xp = "px", coins = "pc", damage = "pd" }

-- Donne `count` potions de cette sorte (les cadeaux, et plus tard la boutique en Robux).
function Potions.give(player: Player, kind: string, count: number?): boolean
	local data = PlayerData.get(player)
	if not data or not Config.POTIONS[kind] then
		return false
	end
	data.po[kind] = (data.po[kind] or 0) + math.max(1, math.floor(count or 1))
	PlayerData.changed(player)
	return true
end

-- Boit une potion. `spot` : la place du familier, pour la potion de rang. Renvoie true si elle a été bue.
function Potions.use(player: Player, kind: string, spot: number?): boolean
	local data = PlayerData.get(player)
	local def = Config.POTIONS[kind]
	if not data or not def then
		return false
	end
	if (data.po[kind] or 0) <= 0 then
		notify(player, "potionNone")
		return false
	end
	if kind == "rank" then
		local pet = data.spots[tostring(spot)]
		if not pet or not pet.v then
			return false
		end
		if not Pets.raiseGrade(pet) then
			notify(player, "potionMax", pet.a)
			return false
		end
		data.po.rank -= 1
		PlayerData.changed(player)
		Monsters.publishTeam(player)
		notify(player, "potionRank", pet.a, Pets.gradeOf(pet))
		return true
	end
	local field = UNTIL[kind]
	local now = os.time()
	data[field] = math.max(now, data[field] or 0) + def.seconds
	data.po[kind] -= 1
	PlayerData.changed(player)
	notify(player, "potionDrunk", kind, math.floor((data[field] - now) / 60 + 0.5))
	return true
end

function Potions.start(notifier)
	notify = notifier
	local event = Instance.new("RemoteEvent")
	event.Name = "UsePotion"
	event.Parent = ReplicatedStorage
	event.OnServerEvent:Connect(function(player, kind, spot)
		if type(kind) == "string" and (spot == nil or typeof(spot) == "number") then
			Potions.use(player, kind, spot)
		end
	end)
end

return Potions

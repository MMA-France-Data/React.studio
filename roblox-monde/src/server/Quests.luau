-- LES QUÊTES (demande du créateur, 10/10, contre la répétition : « mets les quêtes, simples, pour de l'argent et des
-- potions, et des œufs des fois, mais correspondant au monstre de la quête, pas du n'importe quoi ; avec des rangs
-- promis, exemple rang S sur le cochon quand tu en bats 30, pour certaines quêtes »).
--   Une seule quête à la fois, toujours affichée en haut de l'écran, qui s'enchaîne toute seule. Elle suit les camps
--   dans l'ordre : pour chaque animal du monde du joueur, trois quêtes à la suite (Config.QUESTS.stages) :
--     1. bats 10 fois cet animal  → des pièces (autant que `coins` monstres de ce camp) ;
--     2. bats-en 20 de plus      → une potion (XP, pièces ou dégâts, à tour de rôle) ;
--     3. bats-en 30 de plus      → UN ŒUF DE CET ANIMAL, NOTE S GARANTIE.
--   Après les cinq animaux : « bats le boss » → une potion de rang et des pièces ; puis le monde suivant.
--   data.q = { z = monde, r = camp (1 à 5, 6 = le boss), s = quête (1 à 3), n = monstres déjà battus } ; nil avant
--   la fin du tutoriel ; z = 0 quand tout est fini. Attribut du joueur « Quest » : « z:r:s:n » (vide = pas de quête).
--   Monsters.luau appelle Quests.onKill à chaque monstre battu.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Pets = require(ReplicatedStorage.Shared.Pets)
local Eggs = require(script.Parent.Eggs)
local Monsters = require(script.Parent.Monsters)
local PlayerData = require(script.Parent.PlayerData)
local Potions = require(script.Parent.Potions)

local Quests = {}

local Q = Config.QUESTS
local notify

local function publish(player: Player)
	local data = PlayerData.get(player)
	local q = data and data.q
	player:SetAttribute("Quest", if q and q.z > 0 then string.format("%d:%d:%d:%d", q.z, q.r, q.s, q.n) else "")
end

-- Combien de monstres demande la quête en cours.
function Quests.need(q): number
	return if q.r >= 6 then 1 else Q.stages[q.s].kills
end

-- La quête d'un joueur qui vient de finir le tutoriel (ou d'une sauvegarde d'avant les quêtes) : le premier camp du
-- dernier monde qu'il a ouvert.
local function ensure(player: Player)
	local data = PlayerData.get(player)
	if data and not data.q and (data.tu or 0) == 0 then
		data.q = { z = data.zone, r = 1, s = 1, n = 0 }
		PlayerData.changed(player)
	end
end

-- Donne la récompense de la quête finie et passe à la suivante. Renvoie false si elle n'a pas pu être donnée (sac
-- d'œufs plein) : la quête reste finie, on réessaiera au prochain monstre.
local function finish(player: Player, data): boolean
	local q = data.q
	local animal = Pets.COLLECTIONS[q.z][q.r]
	if q.r >= 6 then
		local coins = Config.monster(q.z, 5).coins * Q.bossCoins
		PlayerData.addCoins(player, coins)
		Potions.give(player, "rank", 1)
		notify(player, "questBoss", animal, coins)
	else
		local stage = Q.stages[q.s]
		if stage.reward == "coins" then
			local coins = Config.monster(q.z, q.r).coins * Q.coins
			PlayerData.addCoins(player, coins)
			notify(player, "questCoins", coins)
		elseif stage.reward == "potion" then
			local kind = Q.potions[(q.r - 1) % #Q.potions + 1]
			Potions.give(player, kind, 1)
			notify(player, "questPotion", kind)
		else
			-- L'œuf de CET animal, avec la note promise. Il est donné même si le sac d'œufs est plein.
			if not Eggs.drop(player, q.z, q.r, Q.grade, false, true) then
				notify(player, "questBagFull")
				return false
			end
			notify(player, "questEgg", animal, Pets.GRADES[Q.grade])
		end
	end
	-- La suivante.
	if q.r >= 6 then
		data.q = if Config.ZONES[q.z + 1] then { z = q.z + 1, r = 1, s = 1, n = 0 } else { z = 0, r = 1, s = 1, n = 0 }
	elseif q.s < #Q.stages then
		data.q = { z = q.z, r = q.r, s = q.s + 1, n = 0 }
	else
		data.q = { z = q.z, r = q.r + 1, s = 1, n = 0 }
	end
	PlayerData.changed(player)
	return true
end

-- Un monstre de ce monde et de ce camp vient d'être battu par ce joueur.
function Quests.onKill(player: Player, zone: number, rank: number)
	local data = PlayerData.get(player)
	local q = data and data.q
	if not q or q.z <= 0 or q.z ~= zone or q.r ~= rank then
		return
	end
	q.n = math.min(q.n + 1, Quests.need(q))
	if q.n >= Quests.need(q) then
		finish(player, data)
	end
	publish(player)
end

function Quests.start(notifier)
	notify = notifier
	Monsters.onKill = Quests.onKill
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				ensure(player)
				-- (Une quête restée « finie » sans sa récompense : on la redonne ici, sans attendre un monstre.)
				local data = PlayerData.get(player)
				local q = data and data.q
				if q and q.z > 0 and q.n >= Quests.need(q) then
					finish(player, data)
				end
				publish(player)
			end
		end
	end)
end

return Quests

-- LE MINI TUTORIEL (demande du créateur, 09/10 : « prépare quand même un mini tuto : le gars va taper du canard,
-- évolue l'épée, pose les œufs, etc. »). Six étapes, pour un NOUVEAU joueur seulement ; l'étape en cours est gardée
-- dans data.tu (0 = pas de tutoriel, ou fini) et posée en attribut « Tutorial » : l'écran affiche l'objectif et
-- entoure le bouton à cliquer (Main.client.luau).
--   1. battre un canard                 → il a gagné de l'XP
--   2. poser son œuf (bouton Œufs)       → un œuf couve dans l'enclos (le premier monstre battu lâche toujours le sien)
--   3. attendre l'éclosion               → il a un familier (il rejoint l'équipe tout seul)
--   4. gagner de quoi payer l'épée 2     → assez de pièces
--   5. améliorer l'épée (Boutique)       → épée 2
--   6. prendre le cadeau gratuit         → le premier cadeau est pris (il arrive après Config.GIFT_FIRST secondes)
-- À la fin : une potion double XP, pour découvrir les potions du sac.
-- Une étape déjà remplie est sautée : le joueur n'est jamais bloqué par le tutoriel, il peut tout faire dans
-- l'ordre qu'il veut.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerData = require(script.Parent.PlayerData)
local Potions = require(script.Parent.Potions)

local Tutorial = {}

local notify

local function done(step: number, data): boolean
	if step == 1 then
		return data.xp > 0 or data.level > 1 or data.sword > 1
	elseif step == 2 then
		return next(data.spots) ~= nil or #data.store > 0
	elseif step == 3 then
		for _, spot in data.spots do
			if spot.v then
				return true
			end
		end
		return #data.store > 0
	elseif step == 4 then
		return data.sword > 1 or data.coins >= Config.swordPrice(1)
	elseif step == 5 then
		return data.sword > 1
	elseif step == 6 then
		return (data.gd or 0) > 0 -- (il a déjà pris un cadeau, un jour)
	end
	return true
end

-- Fait avancer le tutoriel de ce joueur autant que possible. Renvoie true s'il a changé d'étape.
function Tutorial.advance(player: Player): boolean
	local data = PlayerData.get(player)
	local step = data and data.tu or 0
	if step <= 0 then
		return false
	end
	local before = step
	while step <= Config.TUTORIAL_STEPS and done(step, data) do
		step += 1
	end
	if step == before then
		return false
	end
	if step > Config.TUTORIAL_STEPS then
		data.tu = 0
		Potions.give(player, "xp", 1) -- (enregistre et met l'écran à jour)
		notify(player, "tutoDone")
	else
		data.tu = step
		PlayerData.changed(player)
		notify(player, "tutoStep", step)
	end
	return true
end

function Tutorial.start(notifier)
	notify = notifier
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, player in Players:GetPlayers() do
				Tutorial.advance(player)
			end
		end
	end)
end

return Tutorial

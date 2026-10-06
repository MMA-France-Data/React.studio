-- LA FERMETURE DE LA PORTE : toutes les quelques minutes, la porte du lobby vers les salles se ferme un court moment.
--   Pendant la fermeture, les œufs de tous les enclos couvent beaucoup plus vite (10 secondes en valent 100).
--   À la réouverture, une salle tirée au hasard reçoit un bonus de chance, lui aussi tiré au hasard : les œufs des
--   tickets gagnés dans cette salle ont plus de chances d'être rares. Le bonus dure jusqu'à la fermeture suivante.
-- Un joueur déjà parti dans les salles n'est pas gêné : seule la sortie du lobby est fermée.
-- L'état est posé en attributs sur le Workspace (CycleState, CycleEnds, LuckRoom, Luck) : l'écran des joueurs les lit.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Eggs = require(script.Parent.Eggs)
local World = require(script.Parent.World)

local Cycle = {}

local random = Random.new()
local state, luckRoom, luck = "Open", 0, 1
local forced = false
-- Les tests arrêtent les fermetures prévues (ils en déclenchent une eux-mêmes avec Cycle.force).
Cycle.paused = false
local gate: Part? = nil

-- Le bonus de chance des œufs de cette salle en ce moment (1 = aucun).
function Cycle.luckOf(room: number): number
	return if room == luckRoom then luck else 1
end

-- Pour les tests : ferme la porte tout de suite (sans attendre l'heure prévue).
function Cycle.force()
	forced = true
end

-- Pour les tests : pose le bonus de chance sur cette salle.
function Cycle.setLuck(room: number, value: number)
	luckRoom, luck = room, value
	workspace:SetAttribute("LuckRoom", luckRoom)
	workspace:SetAttribute("Luck", luck)
end

function Cycle.state()
	return { state = state, room = luckRoom, luck = luck, gateOpen = gate ~= nil and gate:GetAttribute("Open") == true }
end

function Cycle.start(world)
	local settings = Config.CYCLE
	gate = world.gym.gate
	Eggs.luckOf = Cycle.luckOf
	workspace:SetAttribute("CycleState", state)
	workspace:SetAttribute("CycleEnds", workspace:GetServerTimeNow() + settings.every)
	workspace:SetAttribute("LuckRoom", 0)
	workspace:SetAttribute("Luck", 1)
	task.spawn(function()
		local nextClose = os.clock() + settings.every
		while true do
			task.wait(0.25)
			if Cycle.paused then
				nextClose = os.clock() + settings.every
				workspace:SetAttribute("CycleEnds", workspace:GetServerTimeNow() + settings.every)
			end
			if forced or os.clock() >= nextClose then
				forced = false
				-- La porte se ferme ; le bonus de la salle d'avant s'arrête.
				state = "Closed"
				Cycle.setLuck(0, 1)
				World.setDoor(gate, false)
				workspace:SetAttribute("CycleEnds", workspace:GetServerTimeNow() + settings.closed)
				workspace:SetAttribute("CycleState", state)
				for _ = 1, settings.closed do
					task.wait(1)
					-- Chaque seconde compte pour `speed` secondes de couvaison.
					Eggs.accelerate(settings.speed - 1)
				end
				-- La porte se rouvre : une salle au hasard reçoit son bonus de chance.
				state = "Open"
				World.setDoor(gate, true)
				Cycle.setLuck(random:NextInteger(1, #Config.ROOMS), settings.luck[random:NextInteger(1, #settings.luck)])
				nextClose = os.clock() + settings.every
				workspace:SetAttribute("CycleEnds", workspace:GetServerTimeNow() + settings.every)
				workspace:SetAttribute("CycleState", state)
			end
		end
	end)
end

return Cycle

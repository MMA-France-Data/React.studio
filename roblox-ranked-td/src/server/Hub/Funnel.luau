-- Entonnoir des nouveaux joueurs, pour les statistiques de Roblox : à quelle étape partent-ils ?
-- (Hub Création > Analytique > Entonnoirs, « Onboarding ».) Leçon de l'ancien jeu (01/10/2026) : « le didacticiel
-- fait fuir les gens avant même qu'ils commencent à jouer ». Ce compteur permet de le VOIR au lieu de deviner.
-- Étapes, dans l'ordre (Funnel.STEP) :
--   1. Arrivée : ses données sont chargées (nouveau joueur seulement : tuto pas commencé) ;
--   2. Niveau 1 lancé ;
--   3. 1re tour posée (en plus de l'Archer offert) ;
--   4. 1re amélioration ;
--   5. 1er niveau gagné ;
--   6. 1er œuf ouvert : l'œuf de catapulte du niveau 1 (fin du tuto).
-- Chaque étape n'est envoyée qu'une fois par visite, dans l'ordre : atteindre une étape envoie aussi celles d'avant
-- qui ne l'étaient pas encore (l'entonnoir dit « est arrivé au moins jusque-là »).
-- « Passer le tuto » : un événement à part, « TutoPasse », dont la valeur est l'étape du tuto (Levels.TUTORIAL) où le
-- joueur l'a passé.
-- Tout est décidé par le serveur (Hub/LevelsService.luau) : le client n'envoie rien. Rien ne change pour le joueur.
-- Dans Studio, rien n'est envoyé à Roblox : les étapes sont seulement gardées pour les tests (Funnel.debug).
local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Levels = require(ReplicatedStorage:WaitForChild("Shared").Levels)

local Funnel = {}

Funnel.STEP = { Arrived = 1, Started = 2, Placed = 3, Upgraded = 4, Won = 5, Hatched = 6 }
-- Noms des étapes dans les statistiques (sans accents : ils sont affichés tels quels dans le Hub Création).
Funnel.STEPS = { "Arrivee", "Niveau 1 lance", "1re tour posee", "1re amelioration", "1er niveau gagne", "1er oeuf ouvert" }
Funnel.SKIP_EVENT = "TutoPasse"

local reached = {} -- [Player] = numéro de la dernière étape envoyée ; nil = joueur pas suivi (tuto déjà fini en arrivant)
local history = {} -- [Player] = { steps = { noms envoyés pendant cette visite }, skipped = étape du « Passer » ou nil }

local function send(player: Player, step: number)
	local name = Funnel.STEPS[step]
	table.insert(history[player].steps, name)
	if RunService:IsStudio() then
		return
	end
	local ok, err = pcall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, name)
	end)
	if not ok then
		warn("[Entonnoir] étape non envoyée :", err)
	end
end

-- Le joueur a atteint cette étape (Funnel.STEP) : elle est envoyée, avec celles d'avant qui manquaient. Ne fait rien
-- pour un joueur qui n'est pas suivi, ni pour une étape déjà envoyée.
function Funnel.reach(player: Player, step: number)
	local last = reached[player]
	if not last or step <= last then
		return
	end
	for index = last + 1, math.min(step, #Funnel.STEPS) do
		send(player, index)
	end
	reached[player] = math.min(step, #Funnel.STEPS)
end

-- Données chargées. tutorial = l'étape du tuto du joueur (Levels.TUTORIAL) : un nouveau joueur (0) est suivi depuis
-- l'étape 1 ; celui qui revient après avoir gagné le niveau 1 reprend où il en était (seul le 1er œuf ouvert lui
-- manque) ; celui qui a fini le tuto n'est pas suivi.
function Funnel.onLoaded(player: Player, tutorial: number)
	if reached[player] or tutorial >= Levels.TUTORIAL.DONE then
		return
	end
	history[player] = { steps = {}, skipped = nil }
	if tutorial >= Levels.TUTORIAL.EGG then
		reached[player] = Funnel.STEP.Won
	else
		reached[player] = 0
		Funnel.reach(player, Funnel.STEP.Arrived)
	end
end

-- « Passer le tuto », à l'étape `tutorial` du tuto. Le joueur n'est plus suivi ensuite.
function Funnel.onSkip(player: Player, tutorial: number)
	if not reached[player] then
		return
	end
	history[player].skipped = tutorial
	if not RunService:IsStudio() then
		local ok, err = pcall(function()
			AnalyticsService:LogCustomEvent(player, Funnel.SKIP_EVENT, tutorial)
		end)
		if not ok then
			warn("[Entonnoir] « Passer » non envoyé :", err)
		end
	end
	reached[player] = nil
end

-- Tests Studio (StudioDebug « Levels », « Funnel ») : { steps = noms des étapes envoyées pendant cette visite, dans
-- l'ordre, skipped = étape du « Passer » ou nil, tracked = encore suivi, api = les deux fonctions de Roblox existent }.
function Funnel.debug(player: Player)
	local past = history[player]
	local api = pcall(function()
		return AnalyticsService.LogOnboardingFunnelStepEvent, AnalyticsService.LogCustomEvent
	end)
	return {
		steps = if past then table.clone(past.steps) else {},
		skipped = past and past.skipped,
		tracked = reached[player] ~= nil,
		api = api,
	}
end

Players.PlayerRemoving:Connect(function(player)
	reached[player] = nil
	history[player] = nil
end)

return Funnel

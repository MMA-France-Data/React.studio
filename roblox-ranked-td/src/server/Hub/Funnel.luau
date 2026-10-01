-- Entonnoir des nouveaux joueurs, pour les statistiques de Roblox : à quelle étape partent-ils ?
-- Demande du propriétaire (01/10/2026) : « le didacticiel fait fuir les gens avant même qu'ils commencent à jouer ».
-- Ce compteur d'étapes permet de le VOIR au lieu de deviner : Hub Création > Analytique > Entonnoirs (« Onboarding »).
-- Étapes, dans l'ordre :
--   1. Arrivée : ses données sont chargées (nouveau joueur seulement : tuto pas encore fait) ;
--   2. 1re tour posée ;
--   3. 1re amélioration (une tour au niveau 2) ;
--   4. 1er lancer de l'Autel des héros ;
--   5. Tuto terminé (jusqu'au bout, pas « passé »).
-- Chaque étape n'est envoyée qu'une fois par visite, et seulement après les précédentes (un joueur qui lance l'autel
-- avant de poser une tour reste à l'étape 1 tant qu'il n'a pas posé et amélioré une tour).
-- « Passer » : un événement à part, « TutoPasse », dont la valeur est l'étape du tuto où le joueur l'a passé.
-- Tout est décidé par le serveur avec ses propres données (tours posées, niveaux, lancers achetés) : le client
-- n'envoie rien. Rien ne change pour le joueur, ni en ranked.
-- Dans Studio, rien n'est envoyé à Roblox : les étapes sont seulement gardées pour les tests (Funnel.debug).
local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Funnel = {}

-- Noms des étapes dans les statistiques (sans accents : ils sont affichés tels quels dans le Hub Création).
Funnel.STEPS = { "Arrivee", "1re tour posee", "1re amelioration", "1er lancer de l'autel", "Tuto termine" }
Funnel.SKIP_EVENT = "TutoPasse"

local reached = {} -- [Player] = numéro de la dernière étape envoyée ; nil = joueur pas suivi (tuto déjà fait en arrivant)
local history = {} -- [Player] = { steps = { noms envoyés }, skipped = étape du « Passer » ou nil } (tests Studio)

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

-- Étape atteinte d'après les données du joueur (idle = data.idle). Fonction pure (vérifiée par les tests).
-- finished = le tuto vient d'être terminé jusqu'au bout.
function Funnel.stepOf(idle, finished: boolean): number
	local placed, upgraded = false, false
	for _, tower in idle.towers or {} do
		placed = true
		if typeof(tower) == "table" and (tonumber(tower.level) or 1) >= 2 then
			upgraded = true
		end
	end
	if not placed then
		return 1
	elseif not upgraded then
		return 2
	elseif (tonumber(idle.towerSpinsBought) or 0) <= 0 then
		return 3
	end
	return if finished then 5 else 4
end

-- Envoie les étapes nouvellement atteintes (après une tour posée, une amélioration, un lancer de l'autel, la fin du
-- tuto). Ne fait rien pour un joueur qui n'est pas suivi.
function Funnel.update(player: Player, data, finished: boolean?)
	local last = reached[player]
	if not last or not data then
		return
	end
	local now = Funnel.stepOf(data.idle, finished == true)
	for step = last + 1, now do
		send(player, step)
	end
	reached[player] = math.max(last, now)
end

-- Données chargées : un nouveau joueur (tuto pas encore fait) est suivi, à partir de l'étape 1.
function Funnel.onLoaded(player: Player, data)
	if not data or data.tutorialDone == true or reached[player] then
		return
	end
	reached[player] = 0
	history[player] = { steps = {}, skipped = nil }
	Funnel.update(player, data)
end

-- Fin du tuto (Hub/Tutorial.luau) : « Done » = terminé jusqu'au bout, « Skip » = passé à l'étape `step` du tuto.
-- Le joueur n'est plus suivi ensuite.
function Funnel.onTutorialEnd(player: Player, data, action: string, step: number?)
	if not reached[player] then
		return
	end
	if action == "Done" then
		Funnel.update(player, data, true)
	else
		history[player].skipped = step or 0
		if not RunService:IsStudio() then
			local ok, err = pcall(function()
				AnalyticsService:LogCustomEvent(player, Funnel.SKIP_EVENT, step or 0)
			end)
			if not ok then
				warn("[Entonnoir] « Passer » non envoyé :", err)
			end
		end
	end
	reached[player] = nil
end

-- Tests Studio (StudioDebug « Funnel », Hub/init.luau) : { steps = noms des étapes envoyées dans l'ordre, skipped =
-- étape du « Passer » ou nil, tracked = encore suivi, api = les deux fonctions de Roblox existent bien }.
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

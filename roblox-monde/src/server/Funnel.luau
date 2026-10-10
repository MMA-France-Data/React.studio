-- L'ENTONNOIR DES NOUVEAUX JOUEURS (demande du créateur, 10/10, après sa première publicité : savoir À QUELLE ÉTAPE
-- les nouveaux joueurs partent). Le jeu signale à Roblox chaque étape franchie par un nouveau joueur
-- (AnalyticsService:LogOnboardingFunnelStepEvent) ; le tableau de bord du créateur (Analytique → Entonnoirs →
-- Intégration) montre alors combien de joueurs arrivent à chaque marche, et combien abandonnent entre deux.
--   Seuls les NOUVEAUX joueurs comptent : data.fn = la dernière étape signalée (0 au départ ; -1 = un joueur d'avant
--   l'entonnoir, qu'on ne compte pas, sinon il fausserait les premières marches).
--   Une marche est signalée une seule fois, dans l'ordre, et seulement quand toutes celles d'avant sont faites.
--   Exception : le cadeau (il achète l'épée 3 sans jamais prendre son cadeau : la marche du cadeau est rattrapée).
--   Rien ne change pour le joueur : ce module ne fait que compter.
local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerData = require(script.Parent.PlayerData)

local Funnel = {}

local function hasPet(data): boolean
	for _, spot in data.spots do
		if spot.v then
			return true
		end
	end
	return #data.store > 0
end

-- Les marches, dans l'ordre où un joueur les franchit d'habitude (les temps : tools/balance/mondes.py).
-- NE PAS changer l'ordre ni en enlever une fois le jeu publié : Roblox les compte par leur numéro.
Funnel.STEPS = {
	{ name = "01 Arrive dans le jeu", done = function() return true end },
	-- (Un vrai monstre battu, data.hz ; pas l'XP ni l'épée, que le canard doré géant permet d'avoir aussi.)
	{ name = "02 Premier canard battu", done = function(data) return (data.hz or 0) > 0 or #data.bag > 0 or next(data.spots) ~= nil or #data.store > 0 end },
	{ name = "03 Premier oeuf pose", done = function(data) return next(data.spots) ~= nil or #data.store > 0 end },
	{ name = "04 Premier familier eclos", done = hasPet },
	{ name = "05 A les pieces de l'epee 2", done = function(data) return data.sword > 1 or data.coins >= Config.swordPrice(1) end },
	{ name = "06 Epee 2 achetee (30 s)", done = function(data) return data.sword >= 2 end },
	{ name = "07 Premier cadeau pris (2 min 30)", optional = true, done = function(data) return (data.gd or 0) > 0 end },
	{ name = "08 Epee 3 achetee (12 min)", done = function(data) return data.sword >= 3 end },
	{ name = "09 Epee 4 achetee (30 min)", done = function(data) return data.sword >= 4 end },
	{ name = "10 Epee 5 achetee (1 h)", done = function(data) return data.sword >= 5 end },
	{ name = "11 Boss du monde 1 battu", done = function(data) return data.zone >= 2 end },
	{ name = "12 Epee 6 achetee (3 h)", done = function(data) return data.sword >= 6 end },
	{ name = "13 Boss du monde 2 battu (7 h)", done = function(data) return data.zone >= 3 end },
}

-- (Dans Studio, rien n'est envoyé à Roblox : les marches signalées sont gardées ici, pour les tests.)
Funnel.logged = {}

local function send(player: Player, step: number, name: string)
	if RunService:IsStudio() then
		table.insert(Funnel.logged, step)
		return
	end
	local ok, problem = pcall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, name)
	end)
	if not ok then
		warn(`[Monde] entonnoir, marche {step} : {problem}`)
	end
end

-- Signale les marches que ce joueur vient de franchir. Renvoie le nombre de marches signalées.
function Funnel.advance(player: Player): number
	local data = PlayerData.get(player)
	local at = data and data.fn or -1
	if at < 0 or at >= #Funnel.STEPS then
		return 0
	end
	-- Les marches se franchissent UNE PAR UNE, dans l'ordre : on ne saute pas une marche pas faite. (Un nouveau
	-- joueur qui gagne les pièces du canard doré géant a « de quoi payer l'épée 2 » sans avoir battu un seul
	-- monstre : il reste à la marche 1.) Seule une marche `optional` (le cadeau) est rattrapée quand la suivante
	-- est franchie.
	local reached = at
	while reached < #Funnel.STEPS do
		local step = Funnel.STEPS[reached + 1]
		local after = Funnel.STEPS[reached + 2]
		if step.done(data) or (step.optional and after and after.done(data)) then
			reached += 1
		else
			break
		end
	end
	for step = at + 1, reached do
		send(player, step, Funnel.STEPS[step].name)
	end
	if reached > at then
		data.fn = reached
		PlayerData.changed(player)
	end
	return reached - at
end

function Funnel.start()
	task.spawn(function()
		while true do
			task.wait(2)
			for _, player in Players:GetPlayers() do
				Funnel.advance(player)
			end
		end
	end)
end

return Funnel

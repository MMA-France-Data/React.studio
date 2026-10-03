--!optimize 2
-- Outil de réglage (run.ps1 -Curve) : la PRESSION d'un niveau au fil du temps, tous les 10 % du niveau.
--   dégâts/s  = ce que le joueur simulé peut se payer à ce moment (dégâts par seconde estimés de ses tours), mesuré
--               avec des monstres très faibles : tout meurt, son or ne dépend donc que du flot ;
--   PV/s      = les PV de monstres qui sortent par seconde à ce moment, avec les vrais réglages ;
--   pression  = PV/s divisé par dégâts/s. Elle doit monter du début à la fin du niveau : douce au début (le temps de
--               poser ses premières tours), de plus en plus tendue ensuite.
-- Sert à dessiner la montée des PV (Levels.STREAM : RAMP, RAMP_CURVE).
--   luau --codegen -O2 curve.luau -a "regler=Levels.STREAM.RAMP_CURVE=1.3" "rythme=3"
--   (rythme = secondes entre deux achats du joueur simulé ; absent = joueur très actif ; tours attendues : Bot.EXPECTED)
local Levels = require("./gen/shared/Levels")
local Bot = require("./Bot")
local Settings = require("./settings")

Settings.apply(Levels, ...)
local pace = tonumber(Settings.argument("rythme", ...))

for _, level in { 1, 3, 6, 10, 11, 15, 20, 21, 25, 30, 31, 35, 40, 41, 45, 50, 51, 55, 60, 61, 70, 71, 80, 81, 90, 91, 100 } do
	local source = Levels.DEFINITIONS[level]
	-- PV qui sortent par seconde autour de chaque dixième du niveau (fenêtre de 10 % du niveau), vrais réglages.
	local demand = {}
	local queue = Levels.buildQueue(level)
	for bucket = 0, 10 do
		local from = math.max(0, (bucket / 10 - 0.05) * source.seconds)
		local to = math.min(source.seconds, (bucket / 10 + 0.05) * source.seconds)
		local total = 0
		for _, item in queue do
			if item.at >= from and item.at < to and item.enemy ~= "Giant" and item.enemy ~= "Boss" then
				total += item.health
			end
		end
		demand[bucket] = total / (to - from)
	end

	local health = source.health
	source.health = 1 -- (monstres très faibles : tout meurt, l'or du joueur ne dépend que du flot)
	local profile = Bot.profile(level, pace)
	local trace = {}
	Bot.playWith(level, profile, Bot.POLICIES[2], function(game, estimateTotal)
		local progress = math.min(1, game.clock / source.seconds)
		local bucket = math.floor(progress * 10 + 1e-6)
		if trace[bucket] == nil then
			trace[bucket] = { dps = estimateTotal, spent = game.goldSpent }
		end
	end)
	source.health = health

	print(`Niveau {level} ({#queue} monstres, flot de {source.seconds} s, PV {health}) :`)
	local lines = { "  avancée    ", "  dégâts/s   ", "  or dépensé ", "  PV/s       ", "  pression   " }
	for bucket = 0, 10 do
		local entry = trace[bucket] or { dps = 0, spent = 0 }
		lines[1] ..= string.format(" %5d%%", bucket * 10)
		lines[2] ..= string.format(" %6.0f", entry.dps)
		lines[3] ..= string.format(" %6.0f", entry.spent)
		lines[4] ..= string.format(" %6.0f", demand[bucket])
		lines[5] ..= string.format(" %6.2f", if entry.dps > 0 then demand[bucket] / entry.dps else 0)
	end
	for _, line in lines do
		print(line)
	end
end

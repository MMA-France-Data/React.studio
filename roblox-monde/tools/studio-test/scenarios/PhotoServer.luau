-- PETIT TEST (une trentaine de secondes), sans rejouer tout le jeu.
--   powershell -ExecutionPolicy Bypass -File tools/studio-test/run.ps1 -Test photo -Seconds 35
-- Ici : l'entonnoir des nouveaux joueurs (Funnel.luau) : les marches signalées, dans l'ordre, une seule fois, avec le
-- rattrapage d'une marche sautée, et un ancien joueur qui n'est pas compté.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

return function(log)
	local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
	while not player:GetAttribute("Loaded") do
		task.wait(0.1)
	end
	local debug = ServerStorage:WaitForChild("SurviveDebug")
	task.wait(6)
	local passed, failed = 0, 0
	local function check(what: string, expected: string)
		local got = debug:Invoke("Funnel").logged
		local ok = got == expected
		if ok then
			passed += 1
		else
			failed += 1
		end
		log(if ok then "Info" else "Error", "[ENTONNOIR] " .. (if ok then "OK   " else "RATÉ ") .. what .. " → marches signalées : " .. got .. (if ok then "" else "  (attendu : " .. expected .. ")"))
	end
	check("un nouveau joueur arrive", "1")
	debug:Invoke("Level", 2)
	check("premier canard battu", "1 2")
	debug:Invoke("Egg", 1, 1)
	debug:Invoke("EggNow", "Duck", 1)
	check("œuf posé", "1 2 3")
	debug:Invoke("Hatch")
	check("familier éclos", "1 2 3 4")
	debug:Invoke("Give", 300)
	check("300 pièces", "1 2 3 4 5")
	debug:Invoke("Sword", 2)
	check("épée 2", "1 2 3 4 5 6")
	check("rien de neuf : rien n'est signalé deux fois", "1 2 3 4 5 6")
	debug:Invoke("Sword", 3)
	check("épée 3 SANS avoir pris le cadeau : la marche 7 est rattrapée", "1 2 3 4 5 6 7 8")
	debug:Invoke("Zone", 2)
	check("boss du monde 1 battu avec l'épée 3 : les marches 9 et 10 sont rattrapées", "1 2 3 4 5 6 7 8 9 10 11")
	debug:Invoke("Funnel", -1)
	debug:Invoke("Sword", 6)
	check("un joueur d'avant l'entonnoir (-1) n'est jamais compté", "1 2 3 4 5 6 7 8 9 10 11")
	-- (La fonction de Roblox existe bien sous ce nom : dans Studio on ne l'appelle pas, on vérifie seulement.)
	local okName, kind = pcall(function()
		return typeof(game:GetService("AnalyticsService").LogOnboardingFunnelStepEvent)
	end)
	log("Info", "[ENTONNOIR] AnalyticsService.LogOnboardingFunnelStepEvent : " .. tostring(okName) .. " " .. tostring(kind))
	log("Info", "[ENTONNOIR] BILAN : " .. passed .. " réussis, " .. failed .. " ratés")
	log("Info", "[SURVIVE] TEST:done")
end

-- PETIT TEST EN IMAGES (une trentaine de secondes) : seulement des photos, sans rejouer tout le jeu.
--   powershell -ExecutionPolicy Bypass -File tools/studio-test/run.ps1 -Test photo -Seconds 40
-- Ici : le revenu hors ligne. Huit chèvres dans l'enclos, puis un retour après une nuit de 10 heures et après
-- trois jours (compté 24 h au plus) : le message et les pièces gagnées.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

return function(log)
	local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
	while not player:GetAttribute("Loaded") do
		task.wait(0.1)
	end
	task.wait(8)
	local debug = ServerStorage:WaitForChild("SurviveDebug")
	local function shot(name: string)
		task.wait(1)
		log("Info", "SHOT:photo_" .. name)
		task.wait(1.2)
	end
	for _ = 1, 8 do
		debug:Invoke("Pet", "Goat", 5)
	end
	task.wait(2)
	local income = player:GetAttribute("Income")
	local night = debug:Invoke("Offline", 10 * 3600)
	log("Info", string.format("[DIAG] revenu de l'enclos %.1f par seconde ; 10 h d'absence = %d pieces (attendu %d)", income, night, math.floor(income * 36000 / 3)))
	shot("horsligne_nuit")
	task.wait(6)
	local long = debug:Invoke("Offline", 72 * 3600)
	log("Info", string.format("[DIAG] 72 h d'absence = %d pieces (attendu, plafond de 24 h : %d)", long, math.floor(income * 86400 / 3)))
	shot("horsligne_3jours")
	log("Info", "[SURVIVE] TEST:done")
end

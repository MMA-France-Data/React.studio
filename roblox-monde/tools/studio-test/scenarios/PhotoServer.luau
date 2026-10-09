-- PETIT TEST EN IMAGES (une trentaine de secondes) : seulement des photos, sans rejouer tout le jeu.
--   powershell -ExecutionPolicy Bypass -File tools/studio-test/run.ps1 -Test photo -Seconds 45
-- Ici : le cadeau du temps de jeu (compte à rebours, prêt, réclamé quatre fois) et le bouton des amis, PC et téléphone.
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
	log("Info", "[DIAG] cadeau dans " .. tostring(player:GetAttribute("GiftIn")) .. " s, etape " .. tostring(player:GetAttribute("GiftStep")) .. ", amis " .. tostring(player:GetAttribute("FriendBonus")))
	shot("cadeau_attente")
	debug:Invoke("Gift", 2)
	task.wait(3.5)
	shot("cadeau_pret")
	for step = 1, 4 do
		debug:Invoke("Gift", 0)
		task.wait(1.2)
		local before = debug:Invoke("Data")
		local ok = debug:Invoke("Claim")
		local after = debug:Invoke("Data")
		log("Info", string.format("[DIAG] cadeau %d : recu %s, pieces %d -> %d, oeufs au sac %d -> %d, prochain dans %s s", step, tostring(ok), before.coins, after.coins, before.bag, after.bag, tostring(player:GetAttribute("GiftIn"))))
	end
	shot("cadeau_recu")
	workspace:SetAttribute("PhoneHud", true)
	shot("cadeau_tel")
	workspace:SetAttribute("PhoneHud", nil)
	log("Info", "[SURVIVE] TEST:done")
end

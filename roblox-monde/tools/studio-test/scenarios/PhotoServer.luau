-- PETIT TEST (une quarantaine de secondes), sans rejouer tout le jeu.
--   powershell -ExecutionPolicy Bypass -File tools/studio-test/run.ps1 -Test photo -Seconds 50
-- Ici : les cadeaux gratuits : quatre par jour, que des potions (la quatrième : la potion de rang), puis « demain »,
-- et le compte qui repart à zéro le lendemain.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

return function(log)
	local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
	while not player:GetAttribute("Loaded") do
		task.wait(0.1)
	end
	local debug = ServerStorage:WaitForChild("SurviveDebug")
	task.wait(8)
	debug:Invoke("Tuto", 0)
	local function state(): string
		return "pris aujourd'hui " .. tostring(player:GetAttribute("GiftsTaken")) .. ", prochain dans " .. tostring(player:GetAttribute("GiftIn")) .. " s, potions " .. tostring(player:GetAttribute("Potions"))
	end
	workspace:SetAttribute("OpenPanel", "GiftPanel")
	task.wait(1.5)
	log("Info", "[PHOTO] nouveau joueur : " .. state())
	log("Info", "SHOT:photo_cadeaux_jour_0")
	task.wait(1.2)
	log("Info", "[PHOTO] pris trop tôt : " .. tostring(debug:Invoke("Claim")))
	debug:Invoke("Gift", 0)
	task.wait(1.2)
	log("Info", "[PHOTO] 1er pris : " .. tostring(debug:Invoke("Claim")))
	task.wait(1.5)
	log("Info", "[PHOTO] → " .. state())
	log("Info", "SHOT:photo_cadeaux_jour_1")
	task.wait(1.2)
	for index = 2, 4 do
		debug:Invoke("Gift", 0)
		task.wait(1.1)
		log("Info", "[PHOTO] " .. index .. "e pris : " .. tostring(debug:Invoke("Claim")))
	end
	task.wait(1.5)
	log("Info", "[PHOTO] → " .. state())
	debug:Invoke("Gift", 0)
	task.wait(1.1)
	log("Info", "[PHOTO] 5e refusé : " .. tostring(debug:Invoke("Claim")) .. " → " .. state())
	log("Info", "SHOT:photo_cadeaux_jour_4")
	task.wait(1.2)
	debug:Invoke("GiftDay", 1)
	task.wait(2)
	log("Info", "[PHOTO] le lendemain : " .. state())
	log("Info", "[PHOTO] 1er du lendemain pris : " .. tostring(debug:Invoke("Claim")) .. " → " .. state())
	log("Info", "[SURVIVE] TEST:done")
end

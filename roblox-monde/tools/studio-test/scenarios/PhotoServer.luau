-- PETIT TEST EN IMAGES (une trentaine de secondes) : seulement des photos, sans rejouer tout le jeu.
--   powershell -ExecutionPolicy Bypass -File tools/studio-test/run.ps1 -Test photo -Seconds 45
-- Ici : la boutique en Robux (onglet « Bonus » : les deux pass à vie et les potions), un achat simulé et un pass.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

return function(log)
	local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
	while not player:GetAttribute("Loaded") do
		task.wait(0.1)
	end
	local debug = ServerStorage:WaitForChild("SurviveDebug")
	task.wait(8)
	debug:Invoke("Pet", "Pig", 3)
	task.wait(1)
	log("Info", "[PHOTO] avant : revenu " .. tostring(player:GetAttribute("Income")) .. ", potions " .. tostring(player:GetAttribute("Potions")) .. ", pass " .. tostring(player:GetAttribute("PassXp")) .. " " .. tostring(player:GetAttribute("PassCoins")))
	workspace:SetAttribute("OpenPanel", "ShopPanel")
	task.wait(1.6)
	log("Info", "SHOT:photo_boutique_ameliorer")
	task.wait(1.2)
	workspace:SetAttribute("OpenPanel", "ShopBonus")
	task.wait(1.6)
	log("Info", "SHOT:photo_boutique_bonus")
	task.wait(1.2)
	log("Info", "[PHOTO] achats simulés : " .. tostring(debug:Invoke("Buy", "xp")) .. " " .. tostring(debug:Invoke("Buy", "rank")) .. ", produit inconnu : " .. tostring(debug:Invoke("Buy", "rien")))
	debug:Invoke("Pass", "coins", true)
	task.wait(1.6)
	log("Info", "[PHOTO] après : revenu " .. tostring(player:GetAttribute("Income")) .. ", potions " .. tostring(player:GetAttribute("Potions")) .. ", pass " .. tostring(player:GetAttribute("PassXp")) .. " " .. tostring(player:GetAttribute("PassCoins")))
	log("Info", "SHOT:photo_boutique_bonus_achete")
	task.wait(1.2)
	workspace:SetAttribute("PhoneHud", true)
	task.wait(1.6)
	log("Info", "SHOT:photo_boutique_bonus_tel")
	task.wait(1.2)
	log("Info", "[SURVIVE] TEST:done")
end

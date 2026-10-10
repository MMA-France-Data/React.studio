-- PETIT TEST EN IMAGES (une demi-minute), sans rejouer tout le jeu.
--   powershell -ExecutionPolicy Bypass -File tools/studio-test/run.ps1 -Test photo -Seconds 40
-- Ici : sur TÉLÉPHONE, les pastilles de gauche (niveau, chance, cadeau, inviter) sont en haut à gauche, loin du pouce
-- qui déplace le personnage ; avec des bonus en plus (potions, événement) ; et le PC, qui ne doit pas avoir changé.
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
	local function shot(name: string)
		task.wait(1.8)
		log("Info", "SHOT:photo_gauche_" .. name)
		task.wait(1.2)
	end
	shot("pc")
	workspace:SetAttribute("PhoneHud", true)
	shot("tel")
	-- Avec des bonus allumés : deux potions et un événement de l'admin.
	debug:Invoke("Potion", "xp", 1)
	debug:Invoke("Potion", "coins", 1)
	debug:Invoke("Drink", "xp")
	debug:Invoke("Drink", "coins")
	debug:Invoke("Event", "eggs", 5)
	shot("tel_bonus")
	log("Info", "[SURVIVE] TEST:done")
end

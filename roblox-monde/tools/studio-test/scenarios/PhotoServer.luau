-- PETIT TEST EN IMAGES (une trentaine de secondes) : seulement des photos, sans rejouer tout le jeu.
--   powershell -ExecutionPolicy Bypass -File tools/studio-test/run.ps1 -Test photo -Seconds 45
-- Ici : le mode admin (le bouton, la fenêtre, un événement lancé : le bandeau et les pastilles ; puis arrêté).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)

return function(log)
	local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
	while not player:GetAttribute("Loaded") do
		task.wait(0.1)
	end
	local debug = ServerStorage:WaitForChild("SurviveDebug")
	task.wait(8)
	log("Info", "[PHOTO] admin : " .. tostring(player:GetAttribute("Admin")) .. ", multiplicateurs avant : " .. Config.eventMult("coins") .. " " .. Config.eventMult("xp") .. " " .. Config.eventMult("eggs"))
	workspace:SetAttribute("OpenPanel", "AdminPanel")
	task.wait(1.5)
	log("Info", "SHOT:photo_admin")
	task.wait(1.5)
	log("Info", "[PHOTO] lancé : " .. tostring(debug:Invoke("Event", "coins", 15)) .. " " .. tostring(debug:Invoke("Event", "eggs", 5)))
	log("Info", "[PHOTO] durée refusée (7 min) : " .. tostring(debug:Invoke("Event", "xp", 7)))
	task.wait(2)
	log("Info", "[PHOTO] multiplicateurs pendant : " .. Config.eventMult("coins") .. " " .. Config.eventMult("xp") .. " " .. Config.eventMult("eggs"))
	log("Info", "SHOT:photo_admin_lance")
	task.wait(1.5)
	workspace:SetAttribute("OpenPanel", "")
	task.wait(1.5)
	log("Info", "SHOT:photo_admin_bandeau")
	task.wait(1.5)
	log("Info", "[PHOTO] arrêté : " .. tostring(debug:Invoke("Event", "coins", 0)))
	task.wait(2)
	log("Info", "[PHOTO] multiplicateurs après l'arrêt des pièces : " .. Config.eventMult("coins") .. " " .. Config.eventMult("xp") .. " " .. Config.eventMult("eggs"))
	log("Info", "[SURVIVE] TEST:done")
end

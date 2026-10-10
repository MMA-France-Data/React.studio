-- PETIT TEST EN IMAGES (une demi-minute), sans rejouer tout le jeu.
--   powershell -ExecutionPolicy Bypass -File tools/studio-test/run.ps1 -Test photo -Seconds 45
-- Ici : le cadre de la quête, discret : ouvert puis replié, sur PC puis sur téléphone ; et le cadre du tutoriel sur
-- téléphone.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

return function(log)
	local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
	while not player:GetAttribute("Loaded") do
		task.wait(0.1)
	end
	local debug = ServerStorage:WaitForChild("SurviveDebug")
	task.wait(8)
	local function shot(name: string)
		task.wait(1.6)
		log("Info", "SHOT:photo_quete_" .. name)
		task.wait(1.2)
	end
	workspace:SetAttribute("PhoneHud", true)
	shot("tuto_tel")
	workspace:SetAttribute("PhoneHud", false)
	debug:Invoke("Tuto", 0)
	debug:Invoke("Quest", 1, 3, { 3, 12 })
	task.wait(1.5)
	shot("pc_ouverte")
	workspace:SetAttribute("QuestOpen", false)
	shot("pc_repliee")
	workspace:SetAttribute("PhoneHud", true)
	workspace:SetAttribute("QuestOpen", true)
	shot("tel_ouverte")
	workspace:SetAttribute("QuestOpen", false)
	shot("tel_repliee")
	log("Info", "[SURVIVE] TEST:done")
end

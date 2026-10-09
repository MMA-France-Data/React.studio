-- PETIT TEST EN IMAGES (une trentaine de secondes) : seulement des photos, sans rejouer tout le jeu.
--   powershell -ExecutionPolicy Bypass -File tools/studio-test/run.ps1 -Test photo -Seconds 50
-- Ici : les trois classements du fond de l'allée, et la fenêtre de vente du vendeur (enclos + sac).
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
	for rank, animal in { "Duck", "Rooster", "Pig", "Sheep", "Goat" } do
		debug:Invoke("Pet", animal, rank)
	end
	debug:Invoke("ToBag", 1)
	debug:Invoke("ToBag", 2)
	debug:Invoke("Give", 123456)
	task.wait(12)
	-- Les sons se chargent-ils ?
	for _, id in { "rbxassetid://12222216", "rbxassetid://12222208", "rbxassetid://12222225", "rbxasset://sounds/volume_slider.ogg", "rbxasset://sounds/impact_water.mp3", "rbxasset://sounds/impact_explosion_03.mp3", "rbxasset://sounds/action_get_up.mp3", "rbxasset://sounds/action_jump_land.mp3" } do
		local sound = Instance.new("Sound")
		sound.SoundId = id
		sound.Parent = workspace
		local waited = 0
		while not sound.IsLoaded and waited < 4 do
			waited += task.wait(0.2)
		end
		log("Info", string.format("[DIAG] son %s : charge %s, duree %.2f s", id, tostring(sound.IsLoaded), sound.TimeLength))
		sound:Destroy()
	end
	local found = workspace:FindFirstChild("Leaderboards", true)
	log("Info", "[DIAG] dossier des classements : " .. tostring(found and found:GetFullName()) .. " ; pieces " .. tostring(found and #found:GetChildren()))
	for _, board in game:GetService("CollectionService"):GetTagged("Leaderboard") do
		log("Info", "[DIAG] panneau " .. tostring(board:GetAttribute("Kind")) .. " a " .. tostring(board.Position) .. " : " .. string.gsub(board:GetAttribute("Rows") or "", "%c", " / "))
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = CFrame.new(0, 4, -105)
	end
	task.wait(1)
	workspace:SetAttribute("ShotCam", CFrame.lookAt(Vector3.new(0, 13, -112), Vector3.new(0, 12, -148)))
	shot("classements")
	workspace:SetAttribute("ShotCam", nil)
	workspace:SetAttribute("OpenPanel", "SellPanel")
	shot("vente")
	workspace:SetAttribute("OpenPanel", "")
	log("Info", "[SURVIVE] TEST:done")
end

-- PETIT TEST (quelques secondes) : les sons du jeu se chargent-ils ? Sans photo.
local Players = game:GetService("Players")

local IDS = {
	"rbxassetid://70527060448610", -- AmberSugar_Attack
	"rbxassetid://91185515112249", -- Sniff1
	"rbxassetid://130394521743523", -- damage
}

return function(log)
	local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
	while not player:GetAttribute("Loaded") do
		task.wait(0.1)
	end
	task.wait(4)
	for _, id in IDS do
		local sound = Instance.new("Sound")
		sound.SoundId = id
		sound.Parent = workspace
		local waited = 0
		while not sound.IsLoaded and waited < 8 do
			waited += task.wait(0.2)
		end
		log("Info", string.format("[DIAG] son %s : charge %s, duree %.1f s", id, tostring(sound.IsLoaded), sound.TimeLength))
		sound:Destroy()
	end
	log("Info", "[SURVIVE] TEST:done")
end

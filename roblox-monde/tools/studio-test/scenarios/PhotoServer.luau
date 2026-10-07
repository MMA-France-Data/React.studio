-- PETIT TEST EN IMAGES (une vingtaine de secondes) : seulement des photos, sans rejouer tout le jeu.
--   powershell -ExecutionPolicy Bypass -File tools\studio-test\run.ps1 -Test photo -Seconds 40
-- Les vues a prendre sont dans SHOTS : { nom, d ou on regarde, ce qu on regarde }. A changer selon le besoin.
local Players = game:GetService("Players")

local SHOTS = {
	{ "stand", Vector3.new(0, 9, -6), Vector3.new(-12, 6, 26) },
	{ "stand_haut", Vector3.new(0, 45, -25), Vector3.new(0, 4, 22) },
}

return function(log)
	local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
	while not player:GetAttribute("Loaded") do
		task.wait(0.1)
	end
	task.wait(3)
	for _, shot in SHOTS do
		workspace:SetAttribute("ShotCam", CFrame.lookAt(shot[2], shot[3]))
		task.wait(0.9)
		log("Info", "SHOT:photo_" .. shot[1])
		task.wait(1.2)
	end
	workspace:SetAttribute("ShotCam", nil)
	log("Info", "[SURVIVE] TEST:done")
end

-- Petit test des décors en images, côté joueur : place la caméra pour les captures demandées par le serveur
-- (attribut « ShotCam » du Workspace) et ouvre la fenêtre des familiers quand il le demande (« OpenPets »).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

return function(_log)
	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		local wanted = workspace:GetAttribute("ShotCam")
		if wanted then
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = wanted
		elseif camera.CameraType == Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Custom
		end
		local panel = Players.LocalPlayer.PlayerGui:FindFirstChild("PetPanel", true)
		local open = workspace:GetAttribute("OpenPets")
		if panel and open ~= nil then
			panel.Visible = open
		end
	end)
end

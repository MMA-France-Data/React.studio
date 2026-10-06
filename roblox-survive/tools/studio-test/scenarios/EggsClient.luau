-- Petit test des œufs en images, côté joueur : place seulement la caméra pour les captures demandées par le serveur
-- (attribut « ShotCam » du Workspace).
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
	end)
end

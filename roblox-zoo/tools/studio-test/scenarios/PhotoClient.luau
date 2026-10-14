-- Test photo, côté joueur : la caméra des captures (attribut « ShotCam » posé par le serveur), ou la caméra qui suit
-- un animal (attribut « ShotFollow » = son espèce : on le regarde de près).
local RunService = game:GetService("RunService")

return function(_log)
	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		local follow = workspace:GetAttribute("ShotFollow")
		local wanted = workspace:GetAttribute("ShotCam")
		if follow then
			local view = workspace:FindFirstChild("ZooAnimalsView")
			local model = view and view:FindFirstChild(follow)
			if model and model:IsA("Model") then
				local at = model:GetPivot().Position
				camera.CameraType = Enum.CameraType.Scriptable
				local distance = workspace:GetAttribute("ShotDistance") or 9
				camera.CFrame = CFrame.lookAt(at + Vector3.new(distance * 0.8, distance * 0.45, distance * 0.6), at)
				return
			end
		end
		if wanted then
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = wanted
		elseif camera.CameraType == Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Custom
		end
	end)
end

-- Petit test de l'avalanche, côté joueur : place seulement la caméra pour les captures demandées par le serveur
-- (attribut « ShotCam » du Workspace).
local RunService = game:GetService("RunService")

return function(log)
	task.spawn(function()
		local player = game:GetService("Players").LocalPlayer
		local character = player.Character or player.CharacterAdded:Wait()
		local humanoid = character:WaitForChild("Humanoid", 10)
		task.wait(3)
		local names = {}
		for _, item in character:GetDescendants() do
			if item:IsA("Motor6D") or item:IsA("Constraint") or item:IsA("JointInstance") then
				table.insert(names, item.Parent.Name .. "." .. item.Name .. "(" .. item.ClassName .. ")")
			end
		end
		log("Info", "[SURVIVE] personnage : " .. tostring(humanoid and humanoid.RigType) .. " ; articulations : " .. table.concat(names, ", "))
	end)
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

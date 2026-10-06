-- Petit test du prédateur, côté joueur : place seulement la caméra pour les captures demandées par le
-- serveur (attribut « ShotCam » du Workspace).
local RunService = game:GetService("RunService")

return function(log)
	-- Le panneau de reglages (Studio) : il existe, il a ses sept jauges, et une jauge regle bien la stat.
	task.spawn(function()
		local player = game:GetService("Players").LocalPlayer
		local gui = player:WaitForChild("PlayerGui"):WaitForChild("DebugPanel", 15)
		local panel = gui and gui:WaitForChild("Panel", 5)
		local bars = 0
		for _, child in if panel then panel:GetChildren() else {} do
			if child:IsA("TextButton") then
				bars += 1
			end
		end
		log("Info", (if bars == 7 then "[PASS] " else "[FAIL] ") .. "ecran : le panneau de reglages a ses sept jauges  (" .. bars .. ")")
		if panel then
			panel.Visible = true
			game:GetService("ReplicatedStorage"):WaitForChild("DebugSet"):FireServer("Speed", 2500)
			task.wait(9)
			panel.Visible = false
		end
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

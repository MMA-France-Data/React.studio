-- Test du Marché, côté joueur : la caméra des photos, aller dans la cabine du guichet (« GoBooth »), et viser le billet
-- avec le scanner puis cliquer (« DoScan » : le même message que le clic du joueur).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

return function(log)
	local player = Players.LocalPlayer
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
	workspace:GetAttributeChangedSignal("GoBooth"):Connect(function()
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and workspace:GetAttribute("GoBooth") then
			local state = ReplicatedStorage:WaitForChild("ZooState")
			_ = state
			local booth = Vector3.new(0, 0, 197)
			root.CFrame = CFrame.lookAt(booth + Vector3.new(-0.5, 3, 1.2), booth + Vector3.new(5, 4.2, 1.6))
		end
	end)
	workspace:GetAttributeChangedSignal("DoRename"):Connect(function()
		local remote = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("Rename")
		remote:FireServer(workspace:GetAttribute("DoRename"), "Biscuit")
	end)
	workspace:GetAttributeChangedSignal("DoScan"):Connect(function()
		local ticket = workspace:FindFirstChild("Park") and workspace.Park:FindFirstChild("Ticket")
		local remote = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("ScanTicket")
		if ticket and remote then
			remote:FireServer(ticket)
			log("Info", "[ZOO] billet visé et scanné")
		end
	end)
end

-- Test du jeu « Monde », côté joueur : place la caméra pour les captures demandées par le serveur (attribut
-- « ShotCam » du Workspace).
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
		local panel = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("PetPanel", true)
		local open = workspace:GetAttribute("OpenPets")
		if panel and open ~= nil then
			panel.Visible = open
		end
		local eggsPanel = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("EggPanel", true)
		local openEggs = workspace:GetAttribute("OpenEggs")
		if eggsPanel and openEggs ~= nil then
			eggsPanel.Visible = openEggs
		end
		local shop = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("ShopPanel", true)
		local openShop = workspace:GetAttribute("OpenShop")
		if shop and openShop ~= nil then
			shop.Visible = openShop
		end
	end)
end

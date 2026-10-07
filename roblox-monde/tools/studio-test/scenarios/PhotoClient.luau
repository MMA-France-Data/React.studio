-- Petit test photo, cote joueur : la camera des captures, et un diagnostic des effets de l epee (attribut « Diag »).
local RunService = game:GetService("RunService")

return function(log)
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
	workspace:GetAttributeChangedSignal("Diag"):Connect(function()
		for _, sword in workspace:GetChildren() do
			if sword.Name == "Sword" and sword:IsA("Model") then
				local counts, on = {}, 0
				for _, item in sword:GetDescendants() do
					counts[item.ClassName] = (counts[item.ClassName] or 0) + 1
					if (item:IsA("ParticleEmitter") or item:IsA("Beam")) and item.Enabled then
						on += 1
					end
				end
				local parts = {}
				for class, count in counts do
					table.insert(parts, class .. "=" .. count)
				end
				local base, tip = sword:FindFirstChild("TrailBase", true), sword:FindFirstChild("TrailTip", true)
				log("Info", "[DIAG] epee : " .. table.concat(parts, " ") .. " ; effets allumes=" .. on .. " ; lame=" .. tostring(base and tip and (base.WorldPosition - tip.WorldPosition).Magnitude) .. " ; camera=" .. tostring(base and (workspace.CurrentCamera.CFrame.Position - base.WorldPosition).Magnitude))
			end
		end
	end)
end

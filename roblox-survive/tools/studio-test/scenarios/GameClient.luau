-- Test du jeu, côté joueur : place la caméra pour les captures demandées par le serveur (attribut « ShotCam » du
-- Workspace) et vérifie que l'écran et les textes du décor sont bien remplis.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

return function(log)
	local function check(condition, name, detail)
		log("Info", (if condition then "[PASS] " else "[FAIL] ") .. name .. (if detail then "  (" .. tostring(detail) .. ")" else ""))
	end
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

	local hud = player:WaitForChild("PlayerGui"):WaitForChild("Hud", 20)
	check(hud ~= nil, "écran : le HUD existe")
	task.wait(4)
	check(hud.Side.Coins.Text == "0", "écran : 0 pièce affichée", hud.Side.Coins.Text)
	check(hud.Side.Speed.Label.Text ~= "", "écran : niveau de vitesse affiché", hud.Side.Speed.Label.Text)
	local label = workspace.Gym.Speed.Base.Label
	check(label.Title.Text ~= "" and label.Level.Text ~= "" and label.Info.Text ~= "", "écran : étiquette du tapis de course remplie", label.Title.Text .. " / " .. label.Level.Text .. " / " .. label.Info.Text)
	local sign = workspace.Rooms.Room5.Sign:FindFirstChildOfClass("SurfaceGui").Label
	check(sign.Text:find("5") ~= nil, "écran : panneau de la salle 5 rempli", sign.Text)
	local prompt = workspace.Gym.Force.Base.Prompt
	check(prompt.ActionText ~= "" and prompt.ObjectText ~= "", "écran : bouton de la musculation rempli", prompt.ObjectText .. " : " .. prompt.ActionText)

	-- Pendant une salle : le bandeau.
	local seen = {}
	while true do
		local room = player:GetAttribute("Room") or 0
		if room > 0 and hud.Banner.Visible and not seen[room] and tonumber(hud.Banner.Timer.Text) then
			seen[room] = true
			if room == 1 or room == 4 then
				check(hud.Banner.Title.Text ~= "", "écran : bandeau de la salle " .. room, hud.Banner.Title.Text .. " | " .. hud.Banner.Hint.Text)
			end
			if room == 4 then
				task.wait(0.5)
				check(hud.Ceiling.Visible and hud.Ceiling.Label.Text ~= "", "écran : jauge du plafond dans la salle 4", hud.Ceiling.Label.Text)
			end
		end
		if room == 4 and hud.Push.Visible and not seen.push then
			seen.push = true
			check(hud.Push.Label.Text ~= "", "écran : bouton pour pousser le plafond", hud.Push.Label.Text .. " / " .. hud.Ceiling.Label.Text)
		end
		task.wait(0.2)
	end
end

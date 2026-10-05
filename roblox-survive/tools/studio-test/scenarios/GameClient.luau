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
	local mine = workspace.Gym:WaitForChild("Plot" .. (player:GetAttribute("Plot") or 1))
	local label = mine.Speed.Base.Label
	check(label.Title.Text ~= "" and label.Level.Text ~= "" and label.Info.Text ~= "", "écran : étiquette du tapis de course remplie", label.Title.Text .. " / " .. label.Level.Text .. " / " .. label.Info.Text)
	local sign = workspace.Rooms.Room5.Sign:FindFirstChildOfClass("SurfaceGui").Label
	check(sign.Text:find("5") ~= nil, "écran : panneau de la salle 5 rempli", sign.Text)
	local prompt = mine.Force.Base.Prompt
	check(prompt.ActionText ~= "" and prompt.ObjectText ~= "" and prompt.Enabled, "écran : bouton de la musculation rempli", prompt.ObjectText .. " : " .. prompt.ActionText)
	local other = workspace.Gym:FindFirstChild("Plot" .. (if mine.Name == "Plot1" then 2 else 1))
	check(other.Force.Base.Prompt.Enabled == false and other.Force.Base.Label.Level.Text == "", "écran : les machines d'un autre espace sont éteintes")
	local plotSign = mine.Sign:FindFirstChildOfClass("SurfaceGui").Label
	check(string.find(plotSign.Text, player.DisplayName, 1, true) ~= nil, "écran : le panneau de l'espace porte le nom du joueur", plotSign.Text)

	check(hud.Side.Pets.Label.Text ~= "", "écran : bouton des animaux", hud.Side.Pets.Label.Text)

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
		if (player:GetAttribute("EggCount") or 0) >= 1 and not seen.egg then
			seen.egg = true
			task.wait(0.8)
			local egg = workspace:FindFirstChild("Pets") and workspace.Pets:FindFirstChild("Egg")
			local nest = mine.Enclosure:GetAttribute("Nest")
			check(egg ~= nil and (egg.Position - nest).Magnitude < 6 and egg.BillboardGui.Label.Text ~= "", "écran : l'œuf est dans le nid de l'enclos, avec son temps", egg and egg.BillboardGui.Label.Text)
			check(string.find(mine.Enclosure.Title.Label.Level.Text, "1", 1, true) ~= nil, "écran : le panneau de l'enclos compte l'œuf", mine.Enclosure.Title.Label.Level.Text)
		end
		if player:GetAttribute("Pet") == "Dragon" and not seen.pet then
			seen.pet = true
			task.wait(0.5)
			task.wait(0.8)
			local pets = workspace:FindFirstChild("Pets")
			check(pets ~= nil and pets:FindFirstChild("Follower_Dragon") ~= nil, "écran : le dragon suit le joueur")
			local rarity = player:GetAttribute("PetRarity")
			local inPen = pets and pets:FindFirstChild("Enclosure_Dragon" .. rarity)
			local pedestal = mine.Enclosure:FindFirstChild("Ped_Dragon_" .. rarity)
			check(inPen ~= nil and pedestal ~= nil and (inPen:GetPivot().Position - pedestal.Position).Magnitude < 8, "écran : le dragon est sur son socle dans l'enclos")
			local row = hud.PetsPanel.Dragon
			check(row.Follow.Visible and row["Rarity" .. rarity].Label.Text ~= "?", "écran : la collection montre le dragon et ce qu'il rapporte", hud.PetsPanel.Title.Text .. " / " .. row["Rarity" .. rarity].Label.Text .. " / " .. hud.PetsPanel.Income.Text)
			check(hud.Side.Income.Visible and hud.Side.Income.Text ~= "", "écran : le revenu est affiché sous les pièces", hud.Side.Income.Text)
			check(string.find(mine.Enclosure.Title.Label.Info.Text, "%d") ~= nil, "écran : le panneau de l'enclos dit le revenu", mine.Enclosure.Title.Label.Level.Text .. " / " .. mine.Enclosure.Title.Label.Info.Text)
		end
		if room == 6 and hud.Banner.Visible and not seen.melody and string.find(hud.Banner.Hint.Text, "/") then
			seen.melody = true
			check(true, "écran : bandeau de la mélodie", hud.Banner.Title.Text .. " | " .. hud.Banner.Hint.Text)
		end
		if room == 4 and hud.Push.Visible and not seen.push then
			seen.push = true
			check(hud.Push.Label.Text ~= "", "écran : bouton pour pousser le plafond", hud.Push.Label.Text .. " / " .. hud.Ceiling.Label.Text)
		end
		task.wait(0.2)
	end
end

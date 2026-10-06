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
	local walker = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	-- (Si le test du serveur a déjà mis le joueur sur une machine, on attend qu'il en redescende : dessus, il ne
	-- marche pas.)
	local machineLimit = os.clock() + 12
	while (player:GetAttribute("Workout") or "") ~= "" and os.clock() < machineLimit do
		task.wait(0.1)
	end
	task.wait(0.2)
	check(walker ~= nil and math.abs(walker.WalkSpeed - 16 * 0.7) < 0.01, "écran : sans courir, le personnage marche à 70 % de sa vitesse", walker and walker.WalkSpeed)
	check(hud.Run.Label.Text ~= "", "écran : bouton pour courir", hud.Run.Label.Text)
	check(hud.Side.Speed.Label.Text ~= "", "écran : niveau de vitesse affiché", hud.Side.Speed.Label.Text)
	local mine = workspace.Gym:WaitForChild("Plot" .. (player:GetAttribute("Plot") or 1))
	local label = mine.Speed.Base.Label
	check(label.Title.Text ~= "" and string.find(label.Level.Text, "1") ~= nil, "écran : étiquette du tapis de course (son nom, ses points par pas)", label.Title.Text .. " / " .. label.Level.Text)
	local machineSign
	for _, child in mine:GetChildren() do
		if child.Name == "UpgradeSign" and child:GetAttribute("Machine") == "Speed" then
			machineSign = child
		end
	end
	check(machineSign ~= nil and machineSign.Label.Title.Text ~= "" and string.find(machineSign.Label.Level.Text, "2") ~= nil and string.find(machineSign.Label.Button.Info.Text, "500") ~= nil, "écran : panneau « Améliorer » du tapis (niveau 1 > 2, 500)", machineSign and (machineSign.Label.Title.Text .. " / " .. machineSign.Label.Level.Text .. " / " .. machineSign.Label.Button.Info.Text))
	check(machineSign.Prompt.Enabled and machineSign.Prompt.ActionText ~= "", "écran : bouton pour améliorer le tapis", machineSign.Prompt.ActionText)
	local penSign = mine.Enclosure.Upgrade.Label
	check(penSign.Title.Text ~= "" and string.find(penSign.Level.Text, "2") ~= nil and string.find(penSign.Button.Info.Text, "000") ~= nil, "écran : panneau « Améliorer l'enclos » (niveau 1 > 2, 1 000)", penSign.Title.Text .. " / " .. penSign.Level.Text .. " / " .. penSign.Button.Info.Text)
	local sign = workspace.Rooms.Room5.Sign:FindFirstChildOfClass("SurfaceGui").Label
	check(sign.Text:find("5") ~= nil and sign.Text:find("2[,.]5K") ~= nil, "écran : panneau de la salle 5 avec le palier conseillé (saut 2,5K)", sign.Text)
	local prompt = mine.Force.Base.Prompt
	check(prompt.ActionText ~= "" and prompt.ObjectText ~= "" and prompt.Enabled, "écran : bouton de la musculation rempli", prompt.ObjectText .. " : " .. prompt.ActionText)
	local other = workspace.Gym:FindFirstChild("Plot" .. (if mine.Name == "Plot1" then 2 else 1))
	check(other.Force.Base.Prompt.Enabled == false and other.Force.Base.Label.Level.Text == "", "écran : les machines d'un autre espace sont éteintes")
	local plotSign = mine.Sign:FindFirstChildOfClass("SurfaceGui").Label
	check(string.find(plotSign.Text, player.DisplayName, 1, true) ~= nil, "écran : le panneau de l'espace porte le nom du joueur", plotSign.Text)

	check(hud:FindFirstChild("EggButton") ~= nil and hud:FindFirstChild("PawButton") ~= nil and not hud.EggPanel.Visible and not hud.PetPanel.Visible, "écran : boutons œuf et patte à droite, panneaux repliés")

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
		local spots = player:GetAttribute("Spots") or ""
		if (player:GetAttribute("Workout") or "") ~= "" and not seen.workout then
			seen.workout = true
			task.wait(0.3)
			check(hud.StopTraining.Visible, "écran : bouton « ARRÊTER » pendant l'entraînement")
			task.wait(1.2)
			check(string.find(hud.Side.Speed.Label.Text, "%d") ~= nil and hud.Side.Speed.Label.Text ~= "", "écran : les points de vitesse montent", hud.Side.Speed.Label.Text)
		end
		if (player:GetAttribute("BagNext") or "") ~= "" and not seen.carry then
			seen.carry = true
			task.wait(0.5)
			local egg = workspace:FindFirstChild("Pets") and workspace.Pets:FindFirstChild("CarriedEgg")
			local head = player.Character and player.Character:FindFirstChild("Head")
			check(egg ~= nil and head ~= nil and (egg.Position - head.Position).Magnitude < 5, "écran : le joueur porte son œuf sur la tête")
			check(hud.EggButton.Badge.Visible and hud.EggButton.Badge.Label.Text == "1", "écran : la pastille du bouton œuf compte 1", hud.EggButton.Badge.Label.Text)
		end
		if hud.PlaceEgg.Visible and not seen.place then
			seen.place = true
			check(true, "écran : bouton « POSER L'ŒUF » quand le joueur est dans son enclos avec un œuf", hud.PlaceEgg.Label.Text)
		end
		if string.find(spots, ":t:") and not seen.egg then
			seen.egg = true
			task.wait(0.8)
			local origin = mine:GetAttribute("Origin")
			local egg = workspace:FindFirstChild("Pets") and workspace.Pets:FindFirstChild("Egg")
			check(egg ~= nil and (egg.Position - (origin + Vector3.new(6, 2, 12))).Magnitude < 4, "écran : l'œuf est par terre dans l'enclos, là où il a été posé")
			check(egg.Tag.Top.Text ~= "" and string.find(egg.Tag.Bottom.Text, "%d") ~= nil, "écran : l'œuf montre son nom et son temps", egg.Tag.Top.Text .. " | " .. egg.Tag.Bottom.Text)
			local row = hud.EggPanel.Egg1
			check(row.Visible and row.Track.Label.Text ~= "" and row.Rarity.Text ~= "", "écran : « Œufs en croissance » montre l'œuf avec sa barre", hud.EggPanel.Header.Title.Text .. " | " .. row.Track.Label.Text .. " | " .. row.Rarity.Text)
			check(other.Enclosure.Upgrade.Prompt.Enabled == false, "écran : pas de bouton sur l'enclos d'un autre espace")
			local shop = workspace.Gym.Shop.Prompt
			check(shop.ActionText ~= "" and shop.ObjectText ~= "", "écran : la boutique des œufs a son bouton", shop.ObjectText .. " : " .. shop.ActionText)
			check(workspace.Gym.Sell.Prompt.ActionText ~= "", "écran : le stand « VENDRE » a son bouton", workspace.Gym.Sell.Prompt.ActionText)
		end
		if (player:GetAttribute("Pet") or "") ~= "" and not seen.pet then
			seen.pet = true
			-- Le premier familier vient d'un œuf de la salle 1 : un des six animaux de sa collection.
			local animal = player:GetAttribute("Pet")
			task.wait(0.8)
			local pets = workspace:FindFirstChild("Pets")
			check(pets ~= nil and pets:FindFirstChild("Follower_" .. animal) ~= nil, "écran : le familier suit le joueur", animal)
			local rarity = player:GetAttribute("PetRarity")
			local inPen = pets and pets:FindFirstChild("Pen_" .. animal .. rarity)
			local joints = 0
			for _, child in if inPen then inPen:GetDescendants() else {} do
				if child:IsA("Motor6D") then
					joints += 1
				end
			end
			check(inPen ~= nil and inPen:GetAttribute("Starter") == true and joints >= 5 and inPen:FindFirstChild("Walk", true) ~= nil, "écran : c'est un animal articulé de la collection, avec son animation de marche", animal .. " : " .. joints .. " articulations")
			local origin = mine:GetAttribute("Origin")
			local where = inPen and inPen:GetPivot().Position - origin
			check(inPen ~= nil and where.X > -9 and where.X < 29 and where.Z > 2 and where.Z < 31, "écran : le familier est dans l'enclos", tostring(where))
			local start = inPen and inPen:GetPivot().Position
			task.wait(6)
			local again = pets and pets:FindFirstChild("Pen_" .. animal .. rarity)
			local detail = inPen and string.format("bouge de %.2f ; meme modele %s ; parent %s ; camera a %.0f ; nouveau a %.2f", (inPen:GetPivot().Position - start).Magnitude, tostring(again == inPen), tostring(inPen.Parent), (workspace.CurrentCamera.CFrame.Position - start).Magnitude, if again then (again:GetPivot().Position - start).Magnitude else -1)
			check(inPen ~= nil and (inPen:GetPivot().Position - start).Magnitude > 1, "écran : le familier se promène dans l'enclos", detail)
			-- Les pattes bougent-elles vraiment ? On suit chaque pièce articulée par rapport au centre de l'animal
			-- pendant 4 secondes : la plus grande rotation et le plus grand déplacement vus.
			local turn, shift, walked = 0, 0, 0
			if inPen then
				local rigRoot = inPen.PrimaryPart
				local rest = {}
				for _, joint in inPen:GetDescendants() do
					if joint:IsA("Motor6D") and joint.Part1 then
						rest[joint.Part1] = rigRoot.CFrame:ToObjectSpace(joint.Part1.CFrame)
					end
				end
				local last = rigRoot.Position
				local limit = os.clock() + 4
				while os.clock() < limit do
					RunService.RenderStepped:Wait()
					walked += (rigRoot.Position - last).Magnitude
					last = rigRoot.Position
					for part, first in rest do
						local now = rigRoot.CFrame:ToObjectSpace(part.CFrame)
						local _, angle = (first:Inverse() * now):ToAxisAngle()
						turn = math.max(turn, math.deg(angle))
						shift = math.max(shift, (now.Position - first.Position).Magnitude)
					end
				end
			end
			check(turn > 22, "écran : les pattes du familier bougent quand il marche (il ne glisse pas)", string.format("rotation %.1f degres ; deplacement %.2f ; marche %.1f studs", turn, shift, walked))
			local petTag = inPen and inPen.PrimaryPart:FindFirstChild("Tag")
			check(petTag ~= nil and petTag.Top.Text ~= "" and string.find(petTag.Bottom.Text, "/") ~= nil, "écran : le familier montre son nom et ce qu'il rapporte", petTag and (petTag.Top.Text .. " | " .. petTag.Bottom.Text))
			local row = hud.PetPanel.List:FindFirstChild("Pet1")
			check(row ~= nil and row.Visible and row.Animal.Text ~= "" and row.Info.Text ~= "" and row.Sell.Text ~= "" and row.Follow.Text ~= "", "écran : la liste des familiers montre le familier, avec « Suivre » et « Vendre »", row and (hud.PetPanel.Header.Title.Text .. " | " .. row.Animal.Text .. " | " .. row.Info.Text))
			check(hud.PetPanel.Header.AddPlace.Visible and string.find(hud.PetPanel.Header.AddPlace.Text, "000") ~= nil, "écran : bouton « +1 place » avec son prix", hud.PetPanel.Header.AddPlace.Text)
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

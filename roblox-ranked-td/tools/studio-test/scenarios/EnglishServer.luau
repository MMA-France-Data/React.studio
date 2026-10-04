-- Test de la VERSION ANGLAISE, côté serveur : tools/studio-test/run.ps1 -Test english (et -Test page : les images
-- de la page du jeu, scenarios/PageClient.luau).
-- Il obéit au scénario du client (scenarios/EnglishClient.luau), qui ouvre tous les écrans en anglais : la
-- RemoteFunction ReplicatedStorage.__EnglishTest lui donne les commandes de ServerStorage.StudioDebug dont il a
-- besoin pour montrer tous les textes (un joueur riche, un niveau perdu, gagné, le dernier niveau...).
-- StudioDebug n'existe que dans Studio.
return function(log)
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local dbg = game:GetService("ServerStorage"):WaitForChild("StudioDebug", 30)

	local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
	for _ = 1, 150 do
		if dbg:Invoke(player, "Data") and typeof(player:GetAttribute("Plot")) == "number" and player:GetAttribute("LevelsState") ~= nil then
			break
		end
		task.wait(0.2)
	end
	local function levels(...)
		return dbg:Invoke(player, "Levels", ...)
	end

	local remote = Instance.new("RemoteFunction")
	remote.Name = "__EnglishTest"
	remote.OnServerInvoke = function(who, command, a, b)
		if who ~= player then
			return nil
		end
		if command == "Set" then
			-- a = { champ = valeur } de data.levels
			for key, value in a do
				levels("Set", key, value)
			end
			return true
		elseif command == "Gold" then
			return levels("Gold", a)
		elseif command == "Finish" then
			return levels("Finish", a == true)
		elseif command == "Reset" then
			return levels("Reset") ~= nil
		elseif command == "Action" then
			return levels("Action", a, b)
		elseif command == "Do" then
			-- a = { demande, arguments... } : comme le remote LevelAction, sans l'anti-spam
			return levels("Action", table.unpack(a))
		elseif command == "Skip" then
			return levels("Skip", a)
		elseif command == "Fake" then
			-- Un joueur d'essai (jouer en équipe) : a = son nom, b = niveaux réussis ; renvoie son UserId
			return levels("TeamFake", a, b)
		elseif command == "As" then
			-- a = { UserId du joueur d'essai, demande, arguments... } : une demande faite par lui
			return levels("TeamAs", table.unpack(a))
		elseif command == "Gone" then
			return levels("TeamGone", a)
		elseif command == "Shop" then
			-- a = { commande, arguments... } : les achats en Robux (Hub/Shop.luau, faux numéros)
			return levels("Shop", table.unpack(a))
		end
		return nil
	end
	remote.Parent = ReplicatedStorage
	log("Info", "[EN] serveur du test prêt")
end

-- VIDÉO DE LA PAGE DU JEU, côté serveur : tools/studio-test/video.ps1 (pas un test).
-- Il obéit au scénario du client (scenarios/VideoClient.luau), qui met en scène les plans de la vidéo : la
-- RemoteFunction ReplicatedStorage.__VideoTest lui donne les commandes de ServerStorage.StudioDebug dont il a besoin
-- (un joueur qui a tout, de l'or, avancer un niveau, le finir, un œuf prêt dans une couveuse...).
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

	-- Les plans du tournage et les images de la page posent plus de sortes de tours qu'une barre (une par rareté,
	-- « LA BARRE DE TOURS », Levels.luau) : la règle est levée pour ce joueur, dans Studio seulement.
	levels("FreeBar", true)

	local remote = Instance.new("RemoteFunction")
	remote.Name = "__VideoTest"
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
		elseif command == "Do" then
			-- a = { demande, arguments... } : comme le remote LevelAction, sans l'anti-spam
			return levels("Action", table.unpack(a))
		elseif command == "Skip" then
			return levels("Skip", a)
		elseif command == "Finish" then
			return levels("Finish", a == true)
		elseif command == "State" then
			return levels("State")
		elseif command == "EggForce" then
			return levels("EggForce", a)
		elseif command == "Clock" then
			return levels("Clock", a)
		end
		return nil
	end
	remote.Parent = ReplicatedStorage
	log("Info", "[VIDEO] serveur du tournage prêt")
end

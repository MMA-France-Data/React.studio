-- Test du TUTO, côté serveur : tools/studio-test/run.ps1 -Test tutorial.
-- Il vérifie ce que le serveur garde d'un nouveau joueur (étape du tuto, statistiques des nouveaux joueurs), puis il
-- obéit au scénario du client (scenarios/TutorialClient.luau), qui joue le tuto avec la vraie interface : la
-- RemoteFunction ReplicatedStorage.__TutorialTest lui donne les commandes de ServerStorage.StudioDebug dont il a
-- besoin (finir un niveau, redevenir un nouveau joueur, lire les statistiques). StudioDebug n'existe que dans Studio.
return function(log)
	local HttpService = game:GetService("HttpService")
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local dbg = game:GetService("ServerStorage"):WaitForChild("StudioDebug", 30)
	local Levels = require(ReplicatedStorage:WaitForChild("Shared").Levels)

	local function check(ok, message)
		log(if ok then "Info" else "Error", `[{if ok then "PASS" else "FAIL"}] tuto (serveur) : {message}`)
	end

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
	local function published()
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(player:GetAttribute("LevelsState"))
		end)
		return if ok then decoded else {}
	end

	local start = levels("State")
	local funnel = levels("Funnel")
	check(
		start.levels.tutorial == 0 and published().tutorial == 0 and start.levels.best == 0 and Levels.TUTORIAL.DONE == 2,
		`nouveau joueur : tuto à l'étape 0, dans ses données et dans l'état publié ({tostring(published().tutorial)})`
	)
	check(
		funnel.tracked == true and funnel.api == true and table.concat(funnel.steps, " > ") == "Arrivee" and funnel.skipped == nil,
		`statistiques des nouveaux joueurs : il est suivi depuis son arrivée (« {table.concat(funnel.steps, " > ")} » ; les fonctions de Roblox existent : {tostring(funnel.api)})`
	)

	local remote = Instance.new("RemoteFunction")
	remote.Name = "__TutorialTest"
	remote.OnServerInvoke = function(who, command, value)
		if who ~= player then
			return nil
		end
		if command == "State" then
			return levels("State")
		elseif command == "Funnel" then
			return levels("Funnel")
		elseif command == "Finish" then
			return levels("Finish", value == true)
		elseif command == "Reset" then
			return levels("Reset") ~= nil
		end
		return nil
	end
	remote.Parent = ReplicatedStorage
end

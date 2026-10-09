-- VIDÉO DE LA PAGE DU JEU, côté serveur : tools/studio-test/video.ps1 (pas un test).
-- Il obéit au scénario du client (scenarios/VideoClient.luau), qui met en scène les plans : la RemoteFunction
-- ReplicatedStorage.__VideoTest lui donne les commandes de ServerStorage.SurviveDebug (un familier, une épée, ouvrir
-- les zones, voyager...). SurviveDebug n'existe que dans Studio.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

return function(log)
	local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
	while not player:GetAttribute("Loaded") do
		task.wait(0.1)
	end
	local debug = ServerStorage:WaitForChild("SurviveDebug")
	local remote = Instance.new("RemoteFunction")
	remote.Name = "__VideoTest"
	remote.OnServerInvoke = function(who, action, a, b, c)
		if who ~= player then
			return nil
		end
		return debug:Invoke(action, a, b, c)
	end
	remote.Parent = ReplicatedStorage
	log("Info", "[VIDEO] serveur du tournage prêt")
end

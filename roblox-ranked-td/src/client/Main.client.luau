-- Point d'entrée client : charge l'interface du lobby ou celle du match selon le serveur.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local UI = require(script.Parent.UI)

local mode = ReplicatedStorage:GetAttribute("ServerMode")
while not mode do
	ReplicatedStorage:GetAttributeChangedSignal("ServerMode"):Wait()
	mode = ReplicatedStorage:GetAttribute("ServerMode")
end

Remotes.get("Notify").OnClientEvent:Connect(function(message: string, kind: string?)
	UI.toast(message, kind)
end)

if mode == "Match" then
	local TowerPlacement = require(script.Parent.TowerPlacement)
	TowerPlacement.start()
	require(script.Parent.MatchUI).start(TowerPlacement)
	require(script.Parent.Effects).start()
else
	require(script.Parent.LobbyUI).start()
	require(script.Parent.PlotRenderer).start()
	require(script.Parent.PlotUI).start()
	require(script.Parent.MachineUI).start()
end

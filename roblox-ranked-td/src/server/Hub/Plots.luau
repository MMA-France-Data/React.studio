-- Attribution des parcelles : chaque joueur reçoit une parcelle libre en arrivant.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlotLayout = require(ReplicatedStorage:WaitForChild("Shared").PlotLayout)

local Plots = {}

local plots = {} -- construits par HubMap
local owners = {} -- [plotIndex] = Player

function Plots.init(builtPlots)
	plots = builtPlots
end

function Plots.get(player: Player): number?
	for index, owner in owners do
		if owner == player then
			return index
		end
	end
	return nil
end

function Plots.owner(plotIndex: number): Player?
	return owners[plotIndex]
end

function Plots.plot(plotIndex: number)
	return plots[plotIndex]
end

-- Point d'apparition du joueur sur sa parcelle, tourné vers le chemin.
function Plots.homeCFrame(plotIndex: number): CFrame
	local position = PlotLayout.toWorld(plotIndex, PlotLayout.PLAYER_SPAWN)
	local forward = PlotLayout.cframe(plotIndex):VectorToWorldSpace(Vector3.zAxis)
	return CFrame.lookAt(position, position + forward)
end

function Plots.assign(player: Player): number?
	local existing = Plots.get(player)
	if existing then
		return existing
	end
	for index = 1, #plots do
		if not owners[index] then
			owners[index] = player
			player:SetAttribute("Plot", index)
			plots[index].ownerLabel.Text = "🏠 " .. player.DisplayName
			return index
		end
	end
	warn("[Plots] Aucune parcelle libre pour", player.Name, "(règle la taille du serveur à 6 joueurs)")
	return nil
end

function Plots.release(player: Player)
	local index = Plots.get(player)
	if index then
		owners[index] = nil
		plots[index].ownerLabel.Text = "Parcelle libre"
	end
end

function Plots.sendHome(player: Player)
	local index = Plots.get(player)
	local character = player.Character
	if index and character then
		character:PivotTo(Plots.homeCFrame(index))
	end
end

function Plots.start()
	local function onPlayerAdded(player: Player)
		Plots.assign(player)
		player.CharacterAdded:Connect(function(character)
			task.defer(function()
				if character:WaitForChild("HumanoidRootPart", 10) then
					Plots.sendHome(player)
				end
			end)
		end)
		if player.Character then
			Plots.sendHome(player)
		end
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(Plots.release)
end

return Plots

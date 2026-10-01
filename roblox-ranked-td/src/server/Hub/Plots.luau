-- Attribution des parcelles : chaque joueur reçoit une parcelle libre en arrivant.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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

-- Première parcelle essayée : la 1. Tests Studio seulement : la place de test « téléphone » (objet __AutoTestPlot de
-- ReplicatedStorage, ajouté par tools/studio-test/mkproj.cjs) fait commencer à une autre parcelle, pour vérifier
-- qu'un joueur qui n'est PAS sur la parcelle 1 (le 2e arrivé sur un serveur, par exemple) est bien guidé vers la
-- sienne. Jamais dans le jeu publié : RunService:IsStudio() y est toujours faux, et cet objet n'y existe pas.
local function firstPlot(): number
	if RunService:IsStudio() then
		local marker = ReplicatedStorage:FindFirstChild("__AutoTestPlot")
		if marker and marker:IsA("IntValue") and plots[marker.Value] ~= nil then
			return marker.Value
		end
	end
	return 1
end

-- Donne au joueur la première parcelle libre (son numéro part dans son attribut « Plot » : tout le client s'en
-- sert pour savoir laquelle est la sienne, tuto compris).
function Plots.assign(player: Player): number?
	local existing = Plots.get(player)
	if existing then
		return existing
	end
	-- (2 passages : d'abord seulement à partir de firstPlot(), qui vaut 1 hors des tests, puis toutes)
	local first = firstPlot()
	for pass = 1, 2 do
		for index = 1, #plots do
			if not owners[index] and (pass == 2 or index >= first) then
				owners[index] = player
				player:SetAttribute("Plot", index)
				plots[index].ownerLabel.Text = "🏠 " .. player.DisplayName
				return index
			end
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

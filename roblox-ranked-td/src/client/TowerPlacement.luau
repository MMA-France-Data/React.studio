-- Pose et sélection des tours côté client.
-- Le client prévisualise (fantôme vert/rouge), le serveur valide et crée la tour.
--   Clic / tap : poser (en mode pose) ou sélectionner une de tes tours
--   1-4 : choisir une tour • E : améliorer • X : vendre • Q / Retour arrière : annuler
--   Maj enfoncée : rester en mode pose après avoir posé
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Placement = require(Shared.Placement)
local Remotes = require(Shared.Remotes)
local Towers = require(Shared.Towers)
local UI = require(script.Parent.UI)

local TowerPlacement = {}

-- Déclenché quand le type en cours de pose ou la tour sélectionnée change.
local changed = Instance.new("BindableEvent")
TowerPlacement.Changed = changed.Event

local player = Players.LocalPlayer
local matchState: Instance
local placingType: string? = nil
local selectedModel: Model? = nil
local ghost: Part
local rangeRing: Part
local ghostPosition: Vector3? = nil
local ghostReason: string? = nil
local usingTouch = false
local lastTouchPosition: Vector3? = nil

local floorParams = RaycastParams.new()
floorParams.FilterType = Enum.RaycastFilterType.Include
local towerParams = RaycastParams.new()
towerParams.FilterType = Enum.RaycastFilterType.Include

local function myLane(): number?
	return player:GetAttribute("Lane")
end

local function myGold(): number
	local lane = myLane()
	return if lane then (matchState:GetAttribute(`Lane{lane}Gold`) :: number?) or 0 else 0
end

function TowerPlacement.getPlacingType(): string?
	return placingType
end

function TowerPlacement.getSelected(): Model?
	return selectedModel
end

local function ownTowerPositions(): { Vector3 }
	local positions = {}
	for _, model in workspace.Towers:GetChildren() do
		if model:GetAttribute("Lane") == myLane() then
			table.insert(positions, model:GetPivot().Position)
		end
	end
	return positions
end

local function currentRay(): Ray
	local camera = workspace.CurrentCamera
	if usingTouch and lastTouchPosition then
		return camera:ScreenPointToRay(lastTouchPosition.X, lastTouchPosition.Y)
	end
	local mouse = UserInputService:GetMouseLocation()
	return camera:ViewportPointToRay(mouse.X, mouse.Y)
end

local function showRing(position: Vector3, range: number, color: Color3)
	rangeRing.Size = Vector3.new(0.2, range * 2, range * 2)
	rangeRing.CFrame = CFrame.new(position.X, 0.25, position.Z) * CFrame.Angles(0, 0, math.rad(90))
	rangeRing.Color = color
	rangeRing.Parent = workspace
end

local function hideVisuals()
	ghost.Parent = nil
	rangeRing.Parent = nil
end

function TowerPlacement.cancel()
	placingType = nil
	selectedModel = nil
	ghostPosition = nil
	hideVisuals()
	changed:Fire()
end

function TowerPlacement.startPlacing(towerType: string)
	if not Towers.Defs[towerType] or not myLane() then
		return
	end
	selectedModel = nil
	placingType = if placingType == towerType then nil else towerType
	if not placingType then
		hideVisuals()
	end
	changed:Fire()
end

function TowerPlacement.select(model: Model?)
	placingType = nil
	selectedModel = model
	hideVisuals()
	changed:Fire()
end

function TowerPlacement.upgradeSelected()
	if selectedModel then
		Remotes.get("UpgradeTower"):FireServer(selectedModel:GetAttribute("TowerId"))
	end
end

function TowerPlacement.sellSelected()
	if selectedModel then
		Remotes.get("SellTower"):FireServer(selectedModel:GetAttribute("TowerId"))
		TowerPlacement.select(nil)
	end
end

local function updateGhost()
	local lane = myLane()
	if not placingType or not lane then
		return
	end
	local ray = currentRay()
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 1000, floorParams)
	if not hit then
		ghostPosition = nil
		hideVisuals()
		return
	end

	local position = Vector3.new(hit.Position.X, 0, hit.Position.Z)
	local stats = Towers.stats(placingType, 1)
	local ok, reason = Placement.check(lane, position, ownTowerPositions())
	if ok and myGold() < stats.cost then
		ok, reason = false, "Pas assez d'or"
	end

	ghostPosition = position
	ghostReason = if ok then nil else reason
	local color = if ok then UI.Colors.Success else UI.Colors.Error
	ghost.Color = color
	ghost.CFrame = CFrame.new(position + Vector3.new(0, 1.5, 0))
	ghost.Parent = workspace
	showRing(position, stats.range, color)
end

local function tryPlace()
	if matchState:GetAttribute("Phase") ~= "Playing" then
		UI.toast("La partie n'a pas encore commencé", "Warning")
		return
	end
	updateGhost()
	if not ghostPosition or not placingType then
		return
	end
	if ghostReason then
		UI.toast(ghostReason, "Error")
		return
	end
	Remotes.get("PlaceTower"):FireServer(placingType, ghostPosition)
	if not UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
		TowerPlacement.cancel()
	end
end

local function trySelect()
	local ray = currentRay()
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 1000, towerParams)
	local model = hit and hit.Instance:FindFirstAncestorOfClass("Model")
	if model and model:GetAttribute("TowerId") and model:GetAttribute("Lane") == myLane() then
		TowerPlacement.select(model)
	elseif selectedModel then
		TowerPlacement.select(nil)
	end
end

local HOTKEYS = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
}

function TowerPlacement.start()
	matchState = ReplicatedStorage:WaitForChild("MatchState")
	floorParams.FilterDescendantsInstances = { workspace:WaitForChild("Map") }
	towerParams.FilterDescendantsInstances = { workspace:WaitForChild("Towers") }

	ghost = Instance.new("Part")
	ghost.Name = "TowerGhost"
	ghost.Size = Vector3.new(2.4, 3, 2.4)
	ghost.Anchored = true
	ghost.CanCollide = false
	ghost.CanQuery = false
	ghost.Transparency = 0.4
	ghost.Material = Enum.Material.Neon

	rangeRing = Instance.new("Part")
	rangeRing.Name = "RangeRing"
	rangeRing.Shape = Enum.PartType.Cylinder
	rangeRing.Anchored = true
	rangeRing.CanCollide = false
	rangeRing.CanQuery = false
	rangeRing.Transparency = 0.75
	rangeRing.Material = Enum.Material.Neon

	UserInputService.InputBegan:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.Touch then
			usingTouch = true
			lastTouchPosition = input.Position
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			usingTouch = false
		end
		if processed then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if placingType then
				tryPlace()
			else
				trySelect()
			end
		elseif input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.Backspace then
			TowerPlacement.cancel()
		elseif HOTKEYS[input.KeyCode] then
			TowerPlacement.startPlacing(Towers.ORDER[HOTKEYS[input.KeyCode]])
		elseif input.KeyCode == Enum.KeyCode.E then
			TowerPlacement.upgradeSelected()
		elseif input.KeyCode == Enum.KeyCode.X then
			TowerPlacement.sellSelected()
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			usingTouch = false
		elseif input.UserInputType == Enum.UserInputType.Touch then
			lastTouchPosition = input.Position
		end
	end)

	RunService.RenderStepped:Connect(function()
		if placingType then
			updateGhost()
		elseif selectedModel then
			if not selectedModel.Parent then
				TowerPlacement.select(nil)
				return
			end
			local towerType = selectedModel:GetAttribute("TowerType") :: string
			local stats = Towers.stats(towerType, (selectedModel:GetAttribute("Level") :: number?) or 1)
			if stats then
				showRing(selectedModel:GetPivot().Position, stats.range, UI.Colors.Accent)
			end
		end
	end)
end

return TowerPlacement

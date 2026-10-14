-- LES TÂCHES À FAIRE À LA MAIN (sa demande, 14/10 : « gérer beaucoup de choses soi-même : médical, nourrir,
-- entretenir le parc »).
--   NOURRIR : on prend du foin, du grain ou de la viande à la réserve (payé tout de suite), on le porte, et on le vide
--   dans la mangeoire qui en mange.
--   SOIGNER : on prend une trousse à la réserve, et on la porte jusqu'à l'animal malade (sa croix rouge).
--   NETTOYER : on ramasse les crottes dans les espaces et les papiers que les visiteurs jettent dans les allées.
--   On ne porte qu'une chose à la fois (l'attribut « Carry » du joueur, et la chose dans ses bras).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Animals = require(script.Parent.Animals)
local Config = require(ReplicatedStorage.Shared.Config)
local Enclosures = require(script.Parent.Enclosures)
local Map = require(script.Parent.Map)
local Props = require(script.Parent.Props)
local Zoo = require(script.Parent.Zoo)

local Tasks = {}

local M = Enum.Material
local rgb = Props.rgb
local v3 = Vector3.new

local carrying = {} -- [joueur] = « hay », « grain », « meat » ou « kit »
local trash = {} -- les papiers par terre
local trashFolder = Instance.new("Folder")
trashFolder.Name = "Trash"
trashFolder.Parent = workspace

local PRICES = { hay = Config.FOODS.hay.price, grain = Config.FOODS.grain.price, meat = Config.FOODS.meat.price, kit = Config.KIT.price }
local NAMES = { hay = Config.FOODS.hay.fr, grain = Config.FOODS.grain.fr, meat = Config.FOODS.meat.fr, kit = Config.KIT.fr }

function Tasks.carrying(player: Player): string?
	return carrying[player]
end

-- Ce que le joueur a dans les bras (un bloc soudé devant lui).
local function holding(player: Player, kind: string?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if character then
		local old = character:FindFirstChild("Carried")
		if old then
			old:Destroy()
		end
	end
	if not kind or not root then
		return
	end
	local item: BasePart
	if kind == "hay" then
		item = Props.part(character, "Carried", v3(2.6, 1.5, 1.8), root.CFrame, Config.FOODS.hay.color, M.Grass)
	elseif kind == "grain" then
		item = Props.part(character, "Carried", v3(2, 2.2, 1.4), root.CFrame, rgb(222, 206, 166), M.Fabric)
	elseif kind == "meat" then
		item = Props.part(character, "Carried", v3(2.4, 1.4, 1.6), root.CFrame, Config.FOODS.meat.color, M.SmoothPlastic)
	else
		item = Props.part(character, "Carried", v3(2.2, 1.6, 1.2), root.CFrame, rgb(246, 246, 246), M.SmoothPlastic)
		Props.label(item, Enum.NormalId.Back, "+", rgb(220, 50, 50))
		Props.label(item, Enum.NormalId.Front, "+", rgb(220, 50, 50))
	end
	item.Name = "Carried"
	item.Anchored = false
	item.Massless = true
	item.CanCollide = false
	item.CFrame = root.CFrame * CFrame.new(0, 0.4, -1.7)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = item
	weld.Parent = item
end

local function setCarry(player: Player, kind: string?)
	carrying[player] = kind
	player:SetAttribute("Carry", kind or "")
	holding(player, kind)
end
Tasks.setCarry = setCarry

-- LA RÉSERVE ----------------------------------------------------------------------------------------------------------
local function take(player: Player, kind: string)
	if carrying[player] == kind then
		Zoo.notify(player, "alreadyCarry", NAMES[kind])
		return
	end
	if not Zoo.spend(PRICES[kind], if kind == "kit" then "care" else "food", player) then
		return
	end
	setCarry(player, kind)
	Zoo.notify(player, "took", kind)
end

-- LES PAPIERS DANS LES ALLÉES -----------------------------------------------------------------------------------------
local TRASH_COLORS = { rgb(240, 240, 236), rgb(220, 70, 60), rgb(70, 120, 210), rgb(240, 200, 60) }
local trashRandom = Random.new()
function Tasks.addTrash(position: Vector3): BasePart?
	if #trash >= 30 then
		return nil
	end
	local paper = Props.part(trashFolder, "Paper", v3(0.9, 0.25, 0.7), CFrame.new(position.X, 0.15, position.Z) * CFrame.Angles(0, trashRandom:NextNumber(0, 3), 0), TRASH_COLORS[trashRandom:NextInteger(1, #TRASH_COLORS)], M.SmoothPlastic)
	paper.CanQuery = true
	table.insert(trash, paper)
	local item = Enclosures.prompt(paper, "Ramasser", "Papier", 0.2, 8)
	item.Triggered:Connect(function()
		Tasks.removeTrash(paper)
	end)
	Zoo.shared:SetAttribute("Trash", #trash)
	return paper
end
function Tasks.removeTrash(paper: BasePart): boolean
	local index = table.find(trash, paper)
	if not index then
		return false
	end
	table.remove(trash, index)
	paper:Destroy()
	Zoo.shared:SetAttribute("Trash", #trash)
	return true
end
function Tasks.trash(): { BasePart }
	return trash
end

function Tasks.start()
	-- Les quatre points du comptoir de la réserve.
	for kind, counter in Map.store do
		local item = Enclosures.prompt(counter, "Prendre", NAMES[kind] .. " (" .. PRICES[kind] .. " $)", 0, 8)
		item.Triggered:Connect(function(player)
			take(player, kind)
		end)
	end
	-- Remplir une mangeoire.
	Enclosures.handlers.trough = function(player: Player, spaceId: string, food: string)
		if carrying[player] ~= food then
			Zoo.notify(player, "needFood", Config.FOODS[food].fr)
			return
		end
		Enclosures.setLevel(spaceId, food, Config.TROUGH_MAX)
		setCarry(player, nil)
		Zoo.notify(player, "filled", Config.FOODS[food].fr)
		Tasks.done(player, "feed")
	end
	-- Ramasser une crotte.
	Enclosures.handlers.poop = function(player: Player, main: BasePart)
		if Enclosures.removePoop(main) then
			Tasks.done(player, "clean")
		end
	end
	-- Soigner un animal (l'écran envoie son numéro quand on appuie sur « Soigner »).
	Zoo.remotes.treat.OnServerEvent:Connect(function(player, id)
		local animal = typeof(id) == "number" and Animals.byId(id)
		if not animal or not animal.k then
			return
		end
		if carrying[player] ~= "kit" then
			Zoo.notify(player, "needKit")
			return
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root or Enclosures.distanceTo(animal.sp, root.Position) > 8 then
			return
		end
		Animals.treat(animal)
		setCarry(player, nil)
		Zoo.notify(nil, "treated", Animals.nameOf(animal), player.Name)
		Tasks.done(player, "treat")
	end)
	Zoo.remotes.drop.OnServerEvent:Connect(function(player)
		setCarry(player, nil)
	end)
	Players.PlayerRemoving:Connect(function(player)
		carrying[player] = nil
	end)
	-- (Le joueur qui meurt ou réapparaît perd ce qu'il portait.)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			setCarry(player, nil)
		end)
	end)
	for _, player in Players:GetPlayers() do
		player.CharacterAdded:Connect(function()
			setCarry(player, nil)
		end)
	end
end

-- Une tâche faite par un joueur : les conseils du début avancent (Day.luau les suit), et un invité gagne un petit
-- salaire pour son propre zoo (plus tard, avec le hall).
Tasks.onDone = nil :: ((Player, string) -> ())?
function Tasks.done(player: Player, kind: string)
	if Tasks.onDone then
		Tasks.onDone(player, kind)
	end
end

return Tasks

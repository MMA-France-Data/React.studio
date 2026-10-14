-- LES TÂCHES À FAIRE À LA MAIN (sa demande, 14/10 : « gérer beaucoup de choses soi-même : médical, nourrir,
-- entretenir le parc » ; et le 15/10 : le stock, les stands, les maladies).
--   On ne porte qu'une chose à la fois : carrying[joueur] = { kind, item, amount } (attributs « Carry » et
--   « CarryAmount » du joueur, et la chose dans ses bras) :
--     « food » : une ration de foin, de grain ou de viande (prise au comptoir d'une réserve, dans le stock) ;
--     « med » : un médicament (la pharmacie de la réserve : fenêtre de choix) ;
--     « box » : un carton livré par le camion (à ranger dans une réserve, coin « Cartons ») ;
--     « product » : un carton de produits pour un stand (pris à la réserve, rayon « produits »).
--   NOURRIR : la ration dans la mangeoire qui en mange. SOIGNER : examiner l'animal, puis le bon médicament.
--   NETTOYER : les crottes, les papiers, les toilettes, les poubelles.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Animals = require(script.Parent.Animals)
local Config = require(ReplicatedStorage.Shared.Config)
local Enclosures = require(script.Parent.Enclosures)
local Map = require(script.Parent.Map)
local Props = require(script.Parent.Props)
local Shops = require(script.Parent.Shops)
local Stock = require(script.Parent.Stock)
local Zoo = require(script.Parent.Zoo)

local Tasks = {}

local M = Enum.Material
local rgb = Props.rgb
local v3 = Vector3.new

local carrying = {} -- [joueur] = { kind, item, amount }
local trash = {} -- les papiers par terre
local trashFolder = Instance.new("Folder")
trashFolder.Name = "Trash"
trashFolder.Parent = workspace

function Tasks.carrying(player: Player)
	return carrying[player]
end

-- Ce que le joueur a dans les bras (un bloc soudé devant lui). (Rangé hors du personnage : en vue à la première
-- personne, Roblox cache tout ce qui est dans le personnage.)
local carriedFolder = Instance.new("Folder")
carriedFolder.Name = "Carried"
carriedFolder.Parent = workspace
local carriedParts = {}
local function holding(player: Player, held)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if carriedParts[player] then
		carriedParts[player]:Destroy()
		carriedParts[player] = nil
	end
	if not held or not root then
		return
	end
	local def = Config.STOCK[held.item]
	local item: BasePart
	if held.kind == "box" or held.kind == "product" then
		item = Props.part(carriedFolder, "Carried", v3(2.4, 1.6, 2), root.CFrame, rgb(186, 146, 96), M.Cardboard)
		Props.part(item, "Tape", v3(2.42, 0.3, 0.5), root.CFrame, def.color, M.SmoothPlastic)
		Props.label(item, Enum.NormalId.Back, def.fr .. " x" .. held.amount, rgb(60, 40, 20))
	elseif held.item == "hay" then
		item = Props.part(carriedFolder, "Carried", v3(2.6, 1.5, 1.8), root.CFrame, def.color, M.Grass)
	elseif held.item == "grain" then
		item = Props.part(carriedFolder, "Carried", v3(2, 2.2, 1.4), root.CFrame, rgb(222, 206, 166), M.Fabric)
	elseif held.item == "meat" then
		item = Props.part(carriedFolder, "Carried", v3(2.4, 1.4, 1.6), root.CFrame, def.color, M.SmoothPlastic)
	else
		item = Props.part(carriedFolder, "Carried", v3(1.2, 1.6, 1.2), root.CFrame, def.color, M.SmoothPlastic)
		Props.label(item, Enum.NormalId.Back, "+", rgb(220, 50, 50))
	end
	item.Anchored = false
	item.Massless = true
	item.CanCollide = false
	item.CanQuery = false
	for _, child in item:GetChildren() do
		if child:IsA("BasePart") then
			child.Anchored, child.Massless, child.CanCollide, child.CanQuery = false, true, false, false
			child.CFrame = item.CFrame * CFrame.new(0, 0.66, 0)
			local weld = Instance.new("WeldConstraint")
			weld.Part0, weld.Part1 = item, child
			weld.Parent = child
		end
	end
	item.CFrame = root.CFrame * CFrame.new(0, 0.4, -1.9)
	for _, child in item:GetChildren() do
		if child:IsA("BasePart") then
			child.CFrame = item.CFrame * CFrame.new(0, 0.66, 0)
		end
	end
	carriedParts[player] = item
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = item
	weld.Parent = item
end

local function setCarry(player: Player, held)
	carrying[player] = held
	player:SetAttribute("Carry", if held then held.kind .. ":" .. held.item else "")
	player:SetAttribute("CarryAmount", if held then held.amount else 0)
	holding(player, held)
end
Tasks.setCarry = setCarry

-- (Ce qu'on pose n'est pas perdu : une ration ou un médicament retourne dans le stock, un carton retourne sur le quai.)
local function drop(player: Player)
	local held = carrying[player]
	if held and held.kind == "box" then
		Stock.returnBox(held.item, held.amount)
	elseif held then
		Stock.add(held.item, held.amount)
	end
	setCarry(player, nil)
end

local function near(player: Player, part: BasePart, distance: number): boolean
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and (root.Position - part.Position).Magnitude <= distance
end

-- LA RÉSERVE ----------------------------------------------------------------------------------------------------------
-- Prendre une ration (foin, grain, viande), un médicament (une unité), ou un carton de produits (jusqu'à un carton).
local function take(player: Player, item: string)
	local def = Config.STOCK[item]
	if not def then
		return
	end
	local held = carrying[player]
	if held then
		Zoo.notify(player, "handsFull")
		return
	end
	local wanted = if def.kind == "shop" then def.pack else 1
	local got = Stock.take(item, wanted)
	if got <= 0 then
		Zoo.notify(player, "outOfStock", def.fr)
		return
	end
	setCarry(player, { kind = if def.kind == "shop" then "product" else def.kind, item = item, amount = got })
	Zoo.notify(player, "took", item, got)
end

-- Ranger le carton qu'on porte dans une réserve.
local function store(player: Player)
	local held = carrying[player]
	if not held or held.kind ~= "box" then
		Zoo.notify(player, "needBox")
		return
	end
	local stored = Stock.add(held.item, held.amount)
	if stored <= 0 then
		Zoo.notify(player, "storeFull", Config.STOCK[held.item].fr)
		return
	end
	if stored < held.amount then
		held.amount -= stored
		setCarry(player, held)
		Zoo.notify(player, "storeFull", Config.STOCK[held.item].fr)
	else
		setCarry(player, nil)
		Zoo.notify(player, "stored", Config.STOCK[held.item].fr, stored)
	end
	Tasks.done(player, "store")
end

-- LES PAPIERS DANS LES ALLÉES -----------------------------------------------------------------------------------------
local TRASH_COLORS = { rgb(240, 240, 236), rgb(220, 70, 60), rgb(70, 120, 210), rgb(240, 200, 60) }
local trashRandom = Random.new()
function Tasks.addTrash(position: Vector3): BasePart?
	if #trash >= 40 then
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
	-- Le comptoir de chaque réserve : la nourriture directement, la pharmacie et les produits avec une fenêtre de choix.
	for _, point in Map.stores do
		for _, item in { "hay", "grain", "meat" } do
			local prompt = Enclosures.prompt(point[item], "Prendre", Config.STOCK[item].fr, 0, 8)
			prompt.Triggered:Connect(function(player)
				take(player, item)
			end)
		end
		local pharmacy = Enclosures.prompt(point.pharmacy, "Pharmacie", "Médicaments", 0, 8)
		pharmacy.Triggered:Connect(function(player)
			Zoo.remotes.open:FireClient(player, "store", "med")
		end)
		local shop = Enclosures.prompt(point.shop, "Produits", "Cartons pour les stands", 0, 8)
		shop.Triggered:Connect(function(player)
			Zoo.remotes.open:FireClient(player, "store", "shop")
		end)
		local shelf = Enclosures.prompt(point.shelf, "Ranger le carton", "Réserve", 0.4, 9)
		shelf.Triggered:Connect(function(player)
			store(player)
		end)
	end
	-- (La fenêtre de la pharmacie ou des produits : le joueur doit être devant un comptoir.)
	Zoo.remotes.take.OnServerEvent:Connect(function(player, item)
		if typeof(item) ~= "string" or not Config.STOCK[item] then
			return
		end
		local close = false
		for _, point in Map.stores do
			if near(player, point.pharmacy, 14) then
				close = true
			end
		end
		if close then
			take(player, item)
		end
	end)
	-- Porter un carton du quai.
	Stock.handlers.pick = function(player: Player, box: BasePart)
		if carrying[player] then
			Zoo.notify(player, "handsFull")
			return
		end
		local item, amount = box:GetAttribute("Item"), box:GetAttribute("Amount")
		if Stock.removeBox(box) then
			setCarry(player, { kind = "box", item = item, amount = amount })
		end
	end
	-- Remplir une mangeoire.
	Enclosures.handlers.trough = function(player: Player, spaceId: string, food: string)
		local held = carrying[player]
		if not held or held.kind ~= "food" or held.item ~= food then
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
	-- Remplir un stand, nettoyer des toilettes, vider une poubelle.
	Shops.handlers.restock = function(player: Player, id: string)
		local held = carrying[player]
		local product = Shops.need(id)
		if not held or held.kind ~= "product" or held.item ~= product then
			Zoo.notify(player, "needProduct", if product then Config.STOCK[product].fr else "")
			return
		end
		local added = Shops.restock(id, held.amount)
		if added <= 0 then
			Zoo.notify(player, "shopFull")
			return
		end
		local rest = held.amount - added
		if rest > 0 then
			Stock.add(held.item, rest)
		end
		setCarry(player, nil)
		Zoo.notify(player, "restocked", Config.STOCK[held.item].fr, added)
		Tasks.done(player, "restock")
	end
	Shops.handlers.clean = function(player: Player, id: string)
		if Shops.clean(id) then
			Zoo.notify(player, "toiletsClean")
			Tasks.done(player, "clean")
		end
	end
	Shops.handlers.empty = function(player: Player, bin)
		if Shops.empty(bin) then
			Tasks.done(player, "clean")
		end
	end
	-- Examiner et soigner un animal (l'écran envoie son numéro).
	local function closeTo(player: Player, animal): boolean
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		return root ~= nil and Enclosures.distanceTo(animal.sp, root.Position) <= 8
	end
	Zoo.remotes.examine.OnServerEvent:Connect(function(player, id)
		local animal = typeof(id) == "number" and Animals.byId(id)
		if animal and animal.k and closeTo(player, animal) and Animals.examine(animal) then
			Zoo.notify(player, "examined", animal.n or Animals.nameOf(animal), Config.DISEASES[animal.d].fr, Config.STOCK[Config.DISEASES[animal.d].med].fr)
		end
	end)
	Zoo.remotes.treat.OnServerEvent:Connect(function(player, id)
		local animal = typeof(id) == "number" and Animals.byId(id)
		if not animal or not animal.k or not closeTo(player, animal) then
			return
		end
		local held = carrying[player]
		if not held or held.kind ~= "med" then
			Zoo.notify(player, "needMed")
			return
		end
		if not Animals.treat(animal, held.item) then
			Zoo.notify(player, "wrongMed", Config.STOCK[held.item].fr)
			return
		end
		setCarry(player, nil)
		Zoo.notify(nil, "treated", animal.n or Animals.nameOf(animal), player.Name)
		Tasks.done(player, "treat")
	end)
	Zoo.remotes.drop.OnServerEvent:Connect(function(player)
		drop(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		if carrying[player] then
			drop(player)
		end
		carrying[player] = nil
		if carriedParts[player] then
			carriedParts[player]:Destroy()
			carriedParts[player] = nil
		end
	end)
	-- (Le joueur qui meurt ou réapparaît pose ce qu'il portait : ça retourne dans le stock.)
	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			if carrying[player] then
				drop(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

-- Une tâche faite par un joueur : les conseils du début avancent (Day.luau les suit).
Tasks.onDone = nil :: ((Player, string) -> ())?
function Tasks.done(player: Player, kind: string)
	if Tasks.onDone then
		Tasks.onDone(player, kind)
	end
end

return Tasks

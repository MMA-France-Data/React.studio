-- LE STOCK ET LES COMMANDES (sa demande du 15/10, « 1 » : comme Supermarket Simulator).
--   Les réserves n'ont plus tout à l'infini : Zoo.state.stock dit combien il reste de chaque produit (Config.STOCK).
--   On commande sur l'ordinateur de la réserve de l'entrée (par cartons, moins cher en gros) ; Config.DELIVERY_SECONDS
--   plus tard, le camion arrive et dépose les cartons sur le quai (Map.dock). Il faut les porter jusqu'au coin
--   « Cartons » d'une réserve pour les ranger (Tasks.luau) ; le magasinier le fait tout seul (Staff.luau).
--   Les cartons pas encore rangés sont gardés dans la sauvegarde (Zoo.state.dock).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Map = require(script.Parent.Map)
local Props = require(script.Parent.Props)
local Zoo = require(script.Parent.Zoo)

local Stock = {}

local M = Enum.Material
local rgb = Props.rgb
local v3 = Vector3.new

Stock.boxes = {} -- les cartons sur le quai (des blocs, attributs Item et Amount)
Stock.handlers = {} -- pick(player, carton) : rempli par Tasks.luau
local dockFolder = Instance.new("Folder")
dockFolder.Name = "Dock"
dockFolder.Parent = workspace
local pending = 0 -- cartons en route

-- LE STOCK --------------------------------------------------------------------------------------------------------------
function Stock.get(item: string): number
	return Zoo.state.stock[item] or 0
end

local function publish(item: string)
	local amount = Stock.get(item)
	Zoo.shared:SetAttribute("Stock_" .. item, amount)
	-- Les panneaux au-dessus du comptoir des réserves.
	local def = Config.STOCK[item]
	local kind = if def.kind == "med" then "pharmacy" elseif def.kind == "shop" then "shop" else item
	for _, store in Map.stores do
		local label = store.labels[kind]
		if label then
			if kind == "pharmacy" or kind == "shop" then
				local parts = {}
				for _, other in Config.STOCK_ORDER do
					if Config.STOCK[other].kind == def.kind then
						table.insert(parts, Stock.get(other))
					end
				end
				label.Text = table.concat(parts, " · ")
			else
				label.Text = def.fr .. " " .. amount
			end
			label.TextColor3 = if amount <= 2 then rgb(255, 130, 110) else rgb(255, 236, 170)
		end
	end
end
function Stock.publishAll()
	for _, item in Config.STOCK_ORDER do
		publish(item)
	end
end

-- Prend jusqu'à `amount` unités ; renvoie combien on a pu prendre.
function Stock.take(item: string, amount: number): number
	local have = Stock.get(item)
	local taken = math.min(have, amount)
	if taken > 0 then
		Zoo.state.stock[item] = have - taken
		publish(item)
	end
	return taken
end

-- Range `amount` unités (au plus jusqu'à la place des réserves) ; renvoie combien ont été rangées.
function Stock.add(item: string, amount: number): number
	local def = Config.STOCK[item]
	local have = Stock.get(item)
	local stored = math.max(0, math.min(amount, def.cap - have))
	Zoo.state.stock[item] = have + stored
	publish(item)
	return stored
end

-- LES CARTONS SUR LE QUAI -----------------------------------------------------------------------------------------------
local function dockSpot(index: number): CFrame
	local column = (index - 1) % 4
	local row = math.floor((index - 1) / 4) % 3
	local level = math.floor((index - 1) / 12)
	return CFrame.new(Map.dock + v3((column - 1.5) * 3, 0.9 + level * 1.7, (row - 1) * 3))
end

local function placeBox(item: string, amount: number): BasePart
	local def = Config.STOCK[item]
	local box = Props.part(dockFolder, "Box", v3(2.4, 1.6, 2), dockSpot(#Stock.boxes + 1), rgb(186, 146, 96), M.Cardboard, true)
	box.CanQuery = true
	box:SetAttribute("Item", item)
	box:SetAttribute("Amount", amount)
	local tape = Props.part(box, "Tape", v3(2.42, 0.3, 0.5), box.CFrame * CFrame.new(0, 0.66, 0), def.color, M.SmoothPlastic)
	_ = tape
	Props.label(box, Enum.NormalId.Front, def.fr .. " x" .. amount, rgb(60, 40, 20))
	Props.label(box, Enum.NormalId.Back, def.fr .. " x" .. amount, rgb(60, 40, 20))
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Porter"
	prompt.ObjectText = "Carton : " .. def.fr .. " x" .. amount
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = box
	prompt.Triggered:Connect(function(player)
		if Stock.handlers.pick then
			Stock.handlers.pick(player, box)
		end
	end)
	table.insert(Stock.boxes, box)
	return box
end

local function saveDock()
	local list = {}
	for _, box in Stock.boxes do
		table.insert(list, { box:GetAttribute("Item"), box:GetAttribute("Amount") })
	end
	Zoo.state.dock = list
	Zoo.shared:SetAttribute("Dock", #list)
end

-- Enlève un carton du quai (quelqu'un l'a pris) ; les autres se resserrent.
function Stock.removeBox(box: BasePart): boolean
	local index = table.find(Stock.boxes, box)
	if not index then
		return false
	end
	table.remove(Stock.boxes, index)
	box:Destroy()
	for position, other in Stock.boxes do
		other.CFrame = dockSpot(position)
	end
	saveDock()
	return true
end

-- Un carton reposé (le joueur le pose, ou quitte le jeu) retourne sur le quai.
function Stock.returnBox(item: string, amount: number)
	placeBox(item, amount)
	saveDock()
end

-- LE CAMION ---------------------------------------------------------------------------------------------------------------
local truck: Model
local function buildTruck()
	truck = Instance.new("Model")
	truck.Name = "Truck"
	local body = Props.part(truck, "Cargo", v3(8, 8, 16), CFrame.new(0, 5.4, 2), rgb(236, 236, 230), M.SmoothPlastic, true)
	Props.label(body, Enum.NormalId.Left, "ZOO LIVRAISONS", rgb(60, 120, 70))
	Props.label(body, Enum.NormalId.Right, "ZOO LIVRAISONS", rgb(60, 120, 70))
	Props.part(truck, "Cab", v3(8, 6, 5), CFrame.new(0, 4.4, -8.5), rgb(70, 130, 80), M.SmoothPlastic, true)
	Props.part(truck, "Windshield", v3(7, 2.4, 0.2), CFrame.new(0, 5.8, -11.05), rgb(40, 52, 64), M.Glass)
	for _, z in { -8, 6 } do
		for _, x in { -3.8, 3.8 } do
			local wheel = Props.part(truck, "Wheel", v3(1.2, 3, 3), CFrame.new(x, 1.5, z) * CFrame.Angles(0, 0, math.rad(90)), rgb(30, 30, 32), M.Rubber)
			wheel.Shape = Enum.PartType.Cylinder
		end
	end
	truck.WorldPivot = CFrame.new() -- (le pivot au sol, sous le camion)
	truck:PivotTo(CFrame.new(-24, 0, 420))
	truck.Parent = workspace
end

local function drive(from: Vector3, to: Vector3, seconds: number)
	local value = Instance.new("CFrameValue")
	value.Value = CFrame.lookAt(from, to)
	local goal = CFrame.lookAt(to, to + (to - from))
	value.Changed:Connect(function(cframe)
		truck:PivotTo(cframe)
	end)
	local tween = TweenService:Create(value, TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Value = goal })
	tween:Play()
	tween.Completed:Wait()
	value:Destroy()
end

-- LES COMMANDES --------------------------------------------------------------------------------------------------------
-- Le prix d'une commande : { [produit] = cartons }.
function Stock.price(cart): number
	local total = 0
	for item, packs in cart do
		local def = Config.STOCK[item]
		if def then
			local cost = def.price * packs
			if packs >= Config.BULK.packs then
				cost *= 1 - Config.BULK.discount
			end
			total += cost
		end
	end
	return math.floor(total + 0.5)
end

function Stock.order(player: Player?, cart): boolean
	local clean, count = {}, 0
	for item, packs in cart do
		if typeof(item) == "string" and Config.STOCK[item] and typeof(packs) == "number" and packs >= 1 then
			clean[item] = math.min(math.floor(packs), 20)
			count += clean[item]
		end
	end
	if count == 0 then
		return false
	end
	local cost = Stock.price(clean)
	if not Zoo.spend(cost, "orders", player) then
		return false
	end
	pending += count
	Zoo.shared:SetAttribute("Pending", pending)
	Zoo.notify(nil, "ordered", count, cost, Config.DELIVERY_SECONDS)
	task.delay(Config.DELIVERY_SECONDS, function()
		-- Le camion arrive par la route, s'arrête derrière la réserve, et repart.
		local road, stop = v3(-24, 0, 420), v3(-24, 0, 214)
		drive(road, stop, 6)
		for item, packs in clean do
			for _ = 1, packs do
				placeBox(item, Config.STOCK[item].pack)
			end
		end
		pending -= count
		Zoo.shared:SetAttribute("Pending", pending)
		saveDock()
		Zoo.notify(nil, "delivered", count)
		task.wait(3)
		drive(stop, road, 6)
	end)
	return true
end

function Stock.start()
	buildTruck()
	for _, entry in Zoo.state.dock do
		if type(entry) == "table" and Config.STOCK[entry[1]] then
			placeBox(entry[1], tonumber(entry[2]) or Config.STOCK[entry[1]].pack)
		end
	end
	saveDock()
	Stock.publishAll()
	-- L'ordinateur des commandes.
	local computer = Map.stores[1].computer
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Commander"
	prompt.ObjectText = "Ordinateur"
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = computer
	prompt.Triggered:Connect(function(player)
		Zoo.remotes.open:FireClient(player, "orders")
	end)
	Zoo.remotes.order.OnServerEvent:Connect(function(player, cart)
		if typeof(cart) == "table" then
			Stock.order(player, cart)
		end
	end)
end

return Stock

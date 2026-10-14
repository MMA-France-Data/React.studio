-- LES STANDS, LES TOILETTES, LES POUBELLES ET LES PRIX (sa demande du 15/10, « 2 » : les visiteurs ont des besoins, et
-- c'est le joueur qui fixe les prix).
--   10 emplacements le long des allées (Config.SHOP_SPOTS) : on y construit une buvette, un glacier, une friterie, un
--   café, une boutique de souvenirs (des stands en libre-service : il faut leur apporter des cartons de produits, pris
--   à la réserve) ou des toilettes (qui se salissent : on les nettoie).
--   Les poubelles le long des allées se remplissent : pleines, les papiers tombent par terre ; on les vide.
--   Les prix : Zoo.state.prices (fenêtre « Prix ») ; un visiteur achète moins quand c'est cher (Config.buyChance).
--   Zoo.state.shops[emplacement] = { t = type, n = produits dans le stand, d = saleté des toilettes }.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Enclosures = require(script.Parent.Enclosures)
local Map = require(script.Parent.Map)
local Paths = require(script.Parent.Paths)
local Props = require(script.Parent.Props)
local Zoo = require(script.Parent.Zoo)

local Shops = {}

local M = Enum.Material
local rgb = Props.rgb
local part = Props.part
local v3 = Vector3.new

Shops.spots = {} -- [emplacement] = { def, folder, node, front, open, alert, alertText }
Shops.bins = {} -- { part, fill, alert, prompt }
Shops.handlers = {} -- restock(player, emplacement), clean(player, emplacement), empty(player, poubelle) : Tasks.luau

local root = Instance.new("Folder")
root.Name = "Shops"
root.Parent = workspace

-- LES PRIX ----------------------------------------------------------------------------------------------------------------
function Shops.ticketPrice(): number
	return Zoo.state.prices.ticket or Config.ticketPrice(Zoo.state.stars)
end
function Shops.priceOf(kind: string): number
	return Zoo.state.prices[kind] or Config.SHOP_TYPES[kind].sale or 0
end

-- LES STANDS --------------------------------------------------------------------------------------------------------------
local function shopOf(id: string)
	return Zoo.state.shops[id]
end

local function refresh(id: string)
	local spot = Shops.spots[id]
	local shop = shopOf(id)
	if not spot or not spot.open or not shop then
		return
	end
	local def = Config.SHOP_TYPES[shop.t]
	if def.product then
		spot.alert.Enabled = shop.n <= 3
		spot.alertText.Text = if shop.n <= 0 then "Vide !" else "Presque vide"
		spot.stockLabel.Text = shop.n .. " / " .. Config.SHOP_STOCK
	else
		spot.alert.Enabled = shop.d >= 40
		spot.alertText.Text = if shop.d >= 90 then "Fermées : trop sales !" else "Sales !"
		spot.stockLabel.Text = "Propreté " .. math.max(0, 100 - math.floor(shop.d)) .. " %"
	end
	Zoo.shared:SetAttribute("ShopStock_" .. id, if def.product then shop.n else 100 - shop.d)
end

-- Un stand : une petite cabane en bois avec un auvent rayé de sa couleur et son enseigne ; les toilettes : une maisonnette.
local function buildShop(spot, kind: string)
	local def = Config.SHOP_TYPES[kind]
	local spotDef = spot.def
	local folder = spot.folder
	local base = CFrame.lookAt(spotDef.center, spotDef.center + spotDef.facing)
	local size = Config.SHOP_SIZE
	if def.product then
		Props.lodge(folder, base, size.X - 2, size.Y - 3, 8, { openFront = true, title = string.upper(def.fr), rise = 4, roof = def.color, roofMaterial = M.Fabric })
		-- L'auvent rayé au-dessus du comptoir.
		for i = 0, 5 do
			local stripe = part(folder, "Awning", v3((size.X - 2) / 6, 0.2, 3), base * CFrame.new(-(size.X - 2) / 2 + (i + 0.5) * (size.X - 2) / 6, 7.4, -(size.Y - 3) / 2 - 1.4) * CFrame.Angles(math.rad(-18), 0, 0), if i % 2 == 0 then def.color else rgb(250, 248, 240), M.Fabric)
			stripe.CastShadow = false
		end
		-- Les produits en vitrine.
		for i = -2, 2 do
			Props.ball(folder, "Product", 0.7, (base * CFrame.new(i * 1.6, 4.4, -(size.Y - 3) / 2 + 0.3)).Position, Config.STOCK[def.product].color, M.SmoothPlastic)
		end
	else
		Props.lodge(folder, base, size.X - 2, size.Y - 3, 8, { door = 4, title = "TOILETTES", rise = 4, wall = rgb(214, 226, 230) })
	end
	local counter = part(folder, "Counter", v3(3, 1, 1), base * CFrame.new(0, 3.6, -(size.Y - 3) / 2 - 0.6), Props.WOOD_LIGHT, M.Wood)
	counter.Transparency = if def.product then 0 else 1
	counter.CanQuery = true
	local alert, alertText = Enclosures.alertBoard(counter, "Vide !", rgb(214, 70, 60), 7)
	spot.alert, spot.alertText = alert, alertText
	local board = part(folder, "StockBoard", v3(4, 1, 0.2), base * CFrame.new(0, 2.2, -(size.Y - 3) / 2 - 1.2), Props.WOOD, M.WoodPlanks)
	spot.stockLabel = Props.label(board, Enum.NormalId.Front, "", rgb(255, 236, 170))
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = if def.product then "Remplir" else "Nettoyer"
	prompt.ObjectText = def.fr
	prompt.HoldDuration = if def.product then 0.3 else 1.5
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter
	prompt.Triggered:Connect(function(player)
		if def.product then
			if Shops.handlers.restock then
				Shops.handlers.restock(player, spotDef.id)
			end
		elseif Shops.handlers.clean then
			Shops.handlers.clean(player, spotDef.id)
		end
	end)
	spot.open = true
	refresh(spotDef.id)
end

-- L'emplacement libre : un panneau, et le bouton pour choisir ce qu'on y construit.
local function forSale(spot)
	local spotDef = spot.def
	local folder = Instance.new("Folder")
	folder.Name = "ForSale"
	folder.Parent = spot.folder
	spot.forSale = folder
	local front = spotDef.center + spotDef.facing * (Config.SHOP_SIZE.Y / 2 - 1)
	local board = Props.sign(folder, front, spotDef.facing, "EMPLACEMENT\nstand ou toilettes", 8, rgb(255, 228, 140))
	board.Size = v3(8, 3.4, 0.4)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Construire"
	prompt.ObjectText = "Emplacement libre"
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = board
	prompt.Triggered:Connect(function(player)
		Zoo.remotes.open:FireClient(player, "buildShop", spotDef.id)
	end)
end

function Shops.build(player: Player?, id: string, kind: string): boolean
	local spot = Shops.spots[id]
	local def = Config.SHOP_TYPES[kind]
	if not spot or spot.open or not def then
		return false
	end
	if not Zoo.spend(def.price, "spaces", player) then
		return false
	end
	if spot.forSale then
		spot.forSale:Destroy()
		spot.forSale = nil
	end
	Zoo.state.shops[id] = { t = kind, n = 0, d = 0 }
	buildShop(spot, kind)
	Zoo.publish()
	Zoo.notify(nil, "shopBuilt", def.fr, if player then player.Name else "")
	return true
end

-- Ajoute des produits dans un stand ; renvoie combien ont tenu.
function Shops.restock(id: string, amount: number): number
	local shop = shopOf(id)
	if not shop or not Config.SHOP_TYPES[shop.t].product then
		return 0
	end
	local added = math.max(0, math.min(amount, Config.SHOP_STOCK - shop.n))
	shop.n += added
	refresh(id)
	return added
end

function Shops.clean(id: string): boolean
	local shop = shopOf(id)
	if not shop or Config.SHOP_TYPES[shop.t].product then
		return false
	end
	shop.d = 0
	refresh(id)
	return true
end

-- Le produit qu'il faut à un stand, et combien il en manque (nil si ce n'est pas un stand).
function Shops.need(id: string): (string?, number)
	local shop = shopOf(id)
	local def = shop and Config.SHOP_TYPES[shop.t]
	if not def or not def.product then
		return nil, 0
	end
	return def.product, Config.SHOP_STOCK - shop.n
end

-- POUR LES VISITEURS --------------------------------------------------------------------------------------------------
-- Le stand le plus proche (par les allées) qui calme ce besoin et qui peut servir. need : hunger, thirst, bladder, gift.
function Shops.find(need: string, from: number)
	local best, bestDistance = nil, math.huge
	for id, spot in Shops.spots do
		local shop = shopOf(id)
		if spot.open and shop then
			local def = Config.SHOP_TYPES[shop.t]
			local useful = (need == "gift" and shop.t == "souvenirs") or (def.needs[need] or 0) > 0
			if useful then
				local distance = Paths.distance(from, spot.node)
				if distance < bestDistance then
					best, bestDistance = spot, distance
				end
			end
		end
	end
	return best, bestDistance
end

-- Un visiteur au comptoir. Renvoie : « ok », « empty » (plus rien), « dear » (trop cher), « dirty » (toilettes sales),
-- et les besoins calmés.
function Shops.use(id: string): (string, any)
	local shop = shopOf(id)
	if not shop then
		return "empty", nil
	end
	local def = Config.SHOP_TYPES[shop.t]
	if not def.product then
		if shop.d >= 90 then
			return "dirty", nil
		end
		shop.d = math.min(100, shop.d + 3.5)
		refresh(id)
		return if shop.d >= 50 then "yuck" else "ok", def.needs
	end
	if shop.n <= 0 then
		return "empty", nil
	end
	local price = Shops.priceOf(shop.t)
	if Random.new():NextNumber() > Config.buyChance(price, def.fair) then
		return "dear", nil
	end
	shop.n -= 1
	refresh(id)
	Zoo.addMoney(price, "shops")
	local spot = Shops.spots[id]
	Zoo.popup(spot.front + v3(0, 6, 0), "+" .. price .. " $", rgb(110, 230, 120))
	return if price < def.fair * 0.85 then "cheap" else "ok", def.needs
end

-- LES POUBELLES ---------------------------------------------------------------------------------------------------------
local function refreshBin(bin)
	bin.alert.Enabled = bin.fill >= Config.BIN_MAX - 2
	bin.alertText.Text = if bin.fill >= Config.BIN_MAX then "Pleine !" else "Presque pleine"
	bin.prompt.Enabled = bin.fill >= 4
end

-- Un visiteur jette un papier : dans une poubelle pas pleine à moins de 30 de lui (true), sinon par terre (false).
function Shops.throw(position: Vector3): boolean
	local best, bestDistance = nil, 30
	for _, bin in Shops.bins do
		local distance = (bin.part.Position - position).Magnitude
		if bin.fill < Config.BIN_MAX and distance < bestDistance then
			best, bestDistance = bin, distance
		end
	end
	if not best then
		return false
	end
	best.fill += 1
	refreshBin(best)
	return true
end

function Shops.empty(bin): boolean
	if bin.fill <= 0 then
		return false
	end
	bin.fill = 0
	refreshBin(bin)
	return true
end

-- Les poubelles à vider (pour l'agent d'entretien).
function Shops.fullBins(minimum: number): { any }
	local list = {}
	for _, bin in Shops.bins do
		if bin.fill >= minimum then
			table.insert(list, bin)
		end
	end
	return list
end

-- Une poubelle le long des allées, tous les 70 environ, du côté libre.
local function buildBins()
	local function add(position: Vector3)
		local item = Props.bin(root, position)
		item.CanQuery = true
		local bin = { part = item, fill = 0 }
		bin.alert, bin.alertText = Enclosures.alertBoard(item, "Pleine !", rgb(214, 70, 60), 3)
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Vider"
		prompt.ObjectText = "Poubelle"
		prompt.HoldDuration = 0.8
		prompt.MaxActivationDistance = 8
		prompt.RequiresLineOfSight = false
		prompt.Parent = item
		bin.prompt = prompt
		prompt.Triggered:Connect(function(player)
			if Shops.handlers.empty then
				Shops.handlers.empty(player, bin)
			end
		end)
		table.insert(Shops.bins, bin)
		refreshBin(bin)
	end
	-- Sur la place.
	add(v3(12, 0, 188))
	add(v3(-22, 0, 142))
	add(v3(22, 0, 142))
	for _, edge in Config.PATH_EDGES do
		local a, b = Config.PATH_NODES[edge[1]], Config.PATH_NODES[edge[2]]
		local length = (b - a).Magnitude
		local direction = (b - a).Unit
		local side = v3(-direction.Z, 0, direction.X)
		local count = math.floor(length / 70)
		for i = 1, count do
			local along = a + direction * (i - 0.5) * length / count
			for _, sign in { 1, -1 } do
				local spot = along + side * sign * (Config.PATH_WIDTH / 2 + 1.4)
				if Map.isFree(spot.X, spot.Z, 0) then
					add(spot)
					break
				end
			end
		end
	end
end

function Shops.start()
	for _, spotDef in Config.SHOP_SPOTS do
		local folder = Instance.new("Folder")
		folder.Name = spotDef.id
		folder.Parent = root
		local front = spotDef.center + spotDef.facing * (Config.SHOP_SIZE.Y / 2 + 2.5)
		local spot = { def = spotDef, folder = folder, open = false, front = front, node = Paths.attach(front) }
		Shops.spots[spotDef.id] = spot
		local shop = Zoo.state.shops[spotDef.id]
		if shop and Config.SHOP_TYPES[shop.t] then
			shop.n = tonumber(shop.n) or 0
			shop.d = tonumber(shop.d) or 0
			buildShop(spot, shop.t)
		else
			Zoo.state.shops[spotDef.id] = nil
			forSale(spot)
		end
	end
	buildBins()
	Zoo.remotes.buyShop.OnServerEvent:Connect(function(player, id, kind)
		if typeof(id) == "string" and typeof(kind) == "string" then
			Shops.build(player, id, kind)
		end
	end)
	Zoo.remotes.setPrice.OnServerEvent:Connect(function(_player, key, value)
		if typeof(key) ~= "string" or typeof(value) ~= "number" then
			return
		end
		local limits = if key == "ticket" then Config.PRICE_LIMITS.ticket else Config.PRICE_LIMITS.shop
		if key ~= "ticket" and not Config.SHOP_TYPES[key] then
			return
		end
		Zoo.state.prices[key] = math.clamp(math.floor(value + 0.5), limits[1], limits[2])
		Zoo.publish()
	end)
end

return Shops

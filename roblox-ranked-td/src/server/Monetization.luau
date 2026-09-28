-- Achats Robux (Developer Products). Chaque achat n'est livré qu'une seule fois : son PurchaseId
-- est enregistré dans les données du joueur et sauvegardé avant de confirmer l'achat à Roblox.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local PlayerData = require(script.Parent.PlayerData)

local Monetization = {}

local MAX_RECEIPTS_KEPT = 100
local handlers = {} -- [productId] = function(player): boolean

-- handler(player) doit livrer l'achat et renvoyer true, ou false si c'est impossible pour l'instant.
function Monetization.onProduct(productId: number, handler: (Player) -> boolean)
	if productId ~= 0 then
		handlers[productId] = handler
	end
end

local function processReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local data = player and PlayerData.get(player)
	local handler = handlers[receipt.ProductId]
	if not player or not data or not handler then
		-- Roblox réessaiera plus tard (par exemple quand le joueur revient sur la map principale).
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if table.find(data.processedReceipts, receipt.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local ok, delivered = pcall(handler, player)
	if not ok or not delivered then
		warn("[Monetization] Livraison impossible :", delivered)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	table.insert(data.processedReceipts, receipt.PurchaseId)
	while #data.processedReceipts > MAX_RECEIPTS_KEPT do
		table.remove(data.processedReceipts, 1)
	end
	PlayerData.save(player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function Monetization.start()
	MarketplaceService.ProcessReceipt = processReceipt
	if Config.Products.BONUS_SPIN == 0 then
		print("[Monetization] Config.Products.BONUS_SPIN = 0 : l'achat Robux de la machine à bonus est désactivé")
	end
end

return Monetization

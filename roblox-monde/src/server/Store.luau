-- LA BOUTIQUE EN ROBUX (demande du créateur, 09/10 : « il faut qu'on mette dans la boutique les potions et XP x2,
-- revenu x2 » ; ses choix : les potions se paient en Robux et durent un temps, les deux bonus x2 sont à vie, et
-- « revenu x2 » double TOUTES les pièces : monstres, enclos et hors ligne).
--   LES PASS (Config.STORE.passes : xp, coins) : achetés une fois, pour toujours. Roblox garde l'achat ; on le lui
--   demande à l'arrivée du joueur (PlayerData.luau, avant de compter ses pièces hors ligne) et il est posé en
--   attribut (« PassXp », « PassCoins »). PlayerData.passMult le lit.
--   LES POTIONS (Config.STORE.products : rank, xp, coins, damage) : un produit par sorte, qui donne `count` potions
--   (Potions.give). Roblox confirme chaque achat par ProcessReceipt ; le reçu est noté dans data.rc et sauvegardé
--   avant de répondre « accordé » : un achat n'est jamais compté deux fois, ni perdu.
--   Tant qu'un numéro vaut 0 dans Config.STORE (pas encore créé dans le tableau de bord), l'article affiche
--   « Bientôt » et rien ne peut être acheté.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerData = require(script.Parent.PlayerData)
local Potions = require(script.Parent.Potions)

local Store = {}

local RECEIPTS_MAX = 40
local notify

-- Donne ce que vend le produit `kind` (les tests s'en servent aussi, sans passer par Roblox).
function Store.grant(player: Player, kind: string): boolean
	local product = Config.STORE.products[kind]
	if not product or not Potions.give(player, kind, product.count) then
		return false
	end
	notify(player, "storeBought", kind, product.count)
	return true
end

local function kindOf(productId: number): string?
	for kind, product in Config.STORE.products do
		if product.id ~= 0 and product.id == productId then
			return kind
		end
	end
	return nil
end

local function processReceipt(receipt): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	-- (Un achat renvoyé par Roblox pendant le chargement de ses données : on les attend un peu.)
	local deadline = os.clock() + 15
	while player and not PlayerData.get(player) and player.Parent == Players and os.clock() < deadline do
		task.wait(0.5)
	end
	local data = player and PlayerData.get(player)
	if not player or not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- (Roblox le renverra à sa prochaine visite)
	end
	local receiptId = tostring(receipt.PurchaseId)
	if not table.find(data.rc, receiptId) then
		local kind = kindOf(receipt.ProductId)
		if not kind then
			warn(`[Monde] produit inconnu : {receipt.ProductId}`)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		Store.grant(player, kind)
		table.insert(data.rc, receiptId)
		while #data.rc > RECEIPTS_MAX do
			table.remove(data.rc, 1)
		end
		PlayerData.changed(player)
	end
	-- (Accordé seulement une fois la sauvegarde faite ; sinon Roblox le renverra, et le reçu noté évite le doublon.)
	return if PlayerData.saveNow(player) then Enum.ProductPurchaseDecision.PurchaseGranted else Enum.ProductPurchaseDecision.NotProcessedYet
end

function Store.start(notifier)
	notify = notifier
	MarketplaceService.ProcessReceipt = processReceipt
	-- Un pass acheté pendant la partie sert tout de suite.
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, bought)
		if not bought then
			return
		end
		for kind, pass in Config.STORE.passes do
			if pass.id ~= 0 and pass.id == passId then
				PlayerData.setPass(player, kind, true)
				notify(player, "passBought", kind)
			end
		end
	end)
end

return Store

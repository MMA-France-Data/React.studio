-- PETIT TEST (une trentaine de secondes), sans rejouer tout le jeu.
--   powershell -ExecutionPolicy Bypass -File tools/studio-test/run.ps1 -Test photo -Seconds 40
-- Ici : les numéros de la boutique en Robux (Config.STORE) : on demande à Roblox le nom et le prix de chacun, et on
-- prend en photo l'onglet « Bonus » avec les vrais prix.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)

return function(log)
	local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
	while not player:GetAttribute("Loaded") do
		task.wait(0.1)
	end
	local debug = ServerStorage:WaitForChild("SurviveDebug")
	task.wait(6)
	debug:Invoke("Tuto", 0)
	for _, group in { { "pass", Config.STORE.passes, Enum.InfoType.GamePass }, { "produit", Config.STORE.products, Enum.InfoType.Product } } do
		for kind, item in group[2] do
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(item.id, group[3])
			end)
			if ok and type(info) == "table" then
				log("Info", "[PHOTO] " .. group[1] .. " " .. kind .. " " .. item.id .. " → « " .. tostring(info.Name) .. " », " .. tostring(info.PriceInRobux) .. " Robux, en vente : " .. tostring(info.IsForSale) .. " (attendu " .. item.robux .. ")")
			else
				log("Info", "[PHOTO] " .. group[1] .. " " .. kind .. " " .. item.id .. " → ERREUR : " .. tostring(info))
			end
		end
	end
	log("Info", "[PHOTO] pass du joueur : XP " .. tostring(player:GetAttribute("PassXp")) .. ", pièces " .. tostring(player:GetAttribute("PassCoins")))
	workspace:SetAttribute("OpenPanel", "ShopBonus")
	task.wait(4)
	log("Info", "SHOT:photo_boutique_prix")
	task.wait(1.5)
	log("Info", "[SURVIVE] TEST:done")
end

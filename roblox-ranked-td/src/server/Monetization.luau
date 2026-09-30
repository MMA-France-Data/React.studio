-- Achats Robux (Developer Products). Chaque achat n'est livré qu'une seule fois : son PurchaseId
-- est enregistré dans les données du joueur et sauvegardé avant de confirmer l'achat à Roblox.
-- Forge runique (Config.Products.BONUS_SPIN, livrée par Hub/init.luau -> PlotGame:grantBonusSpin) : un achat
-- payé est toujours livré, même si la forge est bloquée entre-temps (les 2 emplacements de rune, dégâts et
-- vitesse, de toutes les tours posées ont déjà la meilleure rune : la meilleure rune, x100 dégâts, est alors
-- donnée) ; il ne compte pas dans le prix des lancers en pièces.
-- Plus bas : les passes de jeu (Game Passes), achetés une fois et gardés pour toujours (mode solo), et la règle de
-- Roblox sur les objets aléatoires payants (PolicyService).
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
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

----------------------------------------------------------------------
-- Passes de jeu (Config.GamePasses). Mode solo uniquement : le ranked ne les lit jamais.
-- La possession est demandée à Roblox à l'arrivée du joueur (UserOwnsGamePassAsync, gardée en mémoire),
-- puis mise à jour tout de suite après un achat (PromptGamePassPurchaseFinished). Elle est publiée en
-- attributs du joueur (PassAutoCollect, PassSpeedX2, PassCoinsX2) pour l'interface ; Hub/init.luau
-- applique les effets.
----------------------------------------------------------------------
-- nom du pass -> clé dans Config.GamePasses, attribut du joueur, nom affiché
local PASSES = {
	AutoCollect = { configKey = "AUTO_COLLECT", attribute = "PassAutoCollect", displayName = "Ramassage auto" },
	SpeedX2 = { configKey = "SPEED_X2", attribute = "PassSpeedX2", displayName = "Vitesse x2" },
	CoinsX2 = { configKey = "COINS_X2", attribute = "PassCoinsX2", displayName = "Pièces x2" },
}
local ownedPasses = {} -- [Player] = { [nom] = true } : réponse de Roblox (un pass n'est jamais retiré)
local studioPasses = {} -- [Player] = { [nom] = bool } : passes donnés ou retirés pour les tests, Studio uniquement
-- [Player] = { [nom] = true tant que la réponse de Roblox à l'arrivée est attendue } (voir Monetization.passKnown).
local arrivalChecks = {}
local passCallbacks = {}

-- ID du pass (0 = pas encore créé). Même lecture que la boutique (ShopUI.luau) : un ID collé entre
-- guillemets marche aussi, une valeur abîmée compte comme 0.
local function passId(name: string): number
	local id = tonumber(Config.GamePasses[PASSES[name].configKey])
	if not id or id ~= id or id <= 0 or id == math.huge then
		return 0
	end
	return math.floor(id)
end

-- Vrai si le joueur possède ce pass (ou si un test Studio le lui a donné).
function Monetization.ownsPass(player: Player, name: string): boolean
	local override = studioPasses[player] and studioPasses[player][name]
	if override ~= nil then
		return override
	end
	return ownedPasses[player] ~= nil and ownedPasses[player][name] == true
end

-- Vrai quand on sait si le joueur possède ce pass : la vérification de son arrivée est finie (réponse de
-- Roblox, pass pas encore créé, ou 3 essais ratés) ou un test Studio l'a donné / retiré. Juste à l'arrivée,
-- c'est faux quelques instants : ownsPass dirait « non » même à un acheteur.
function Monetization.passKnown(player: Player, name: string): boolean
	if studioPasses[player] and studioPasses[player][name] ~= nil then
		return true
	end
	local checks = arrivalChecks[player]
	return checks ~= nil and checks[name] == nil
end

-- Attend (au plus `timeout` secondes) que la possession du pass soit connue, puis renvoie ownsPass.
-- Faux si le joueur part avant.
function Monetization.waitForPass(player: Player, name: string, timeout: number): boolean
	local deadline = os.clock() + timeout
	while not Monetization.passKnown(player, name) and player.Parent and os.clock() < deadline do
		task.wait(0.1)
	end
	return player.Parent ~= nil and Monetization.ownsPass(player, name)
end

-- callback(player, nom, possédé) : appelé quand la possession d'un pass est connue ou change.
function Monetization.onPassChanged(callback: (Player, string, boolean) -> ())
	table.insert(passCallbacks, callback)
end

local function publishPass(player: Player, name: string)
	if not player.Parent then
		return
	end
	local owned = Monetization.ownsPass(player, name)
	player:SetAttribute(PASSES[name].attribute, owned)
	for _, callback in passCallbacks do
		task.spawn(callback, player, name, owned)
	end
end

local function grantPass(player: Player, name: string)
	if not player.Parent then
		return -- parti pendant la vérification : rien à garder en mémoire
	end
	ownedPasses[player] = ownedPasses[player] or {}
	ownedPasses[player][name] = true
	publishPass(player, name)
end

-- Demande à Roblox si le joueur possède le pass. En cas d'erreur, on réessaie un peu plus tard (3 essais) :
-- une panne passagère ne doit pas priver un acheteur de son pass. Jamais de retrait.
local function checkPass(player: Player, name: string)
	local id = passId(name)
	if id == 0 then
		return
	end
	for attempt = 1, 3 do
		if not player.Parent then
			return
		end
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
		end)
		if ok then
			if owns then
				grantPass(player, name)
			end
			return
		end
		warn(`[Monetization] Vérification du pass {name} impossible pour {player.Name} (essai {attempt}) :`, owns)
		if attempt < 3 then
			task.wait(attempt * 5)
		end
	end
end

----------------------------------------------------------------------
-- Objets aléatoires payants (règle de Roblox : questionnaire de maturité, « PolicyService = oui ») : le lancer Robux
-- de la forge runique donne une rune au hasard. Dans certains pays, Roblox interdit de vendre ça à certains joueurs :
-- on le demande à Roblox à l'arrivée de chaque joueur (PolicyService:GetPolicyInfoForPlayerAsync).
-- Attribut du joueur « PaidRandomRestricted » (lu par MachineUI.luau) : false = achat autorisé (bouton Robux de la
-- forge affiché) ; true = interdit (bouton caché). Il vaut true tant que la réponse n'est pas arrivée, et reste true
-- si Roblox ne répond pas après 3 essais : on cache l'achat plutôt que de prendre le risque.
-- Un reçu qui arrive quand même est livré comme d'habitude (un paiement n'est jamais perdu).
-- Dans Studio : false (toujours pareil, pour les tests) ; StudioDebug « PaidRandom » le change.
----------------------------------------------------------------------
Monetization.PAID_RANDOM_ATTRIBUTE = "PaidRandomRestricted"
local POLICY_TRIES = 3

local function checkPaidRandomPolicy(player: Player)
	if RunService:IsStudio() then
		player:SetAttribute(Monetization.PAID_RANDOM_ATTRIBUTE, false)
		return
	end
	player:SetAttribute(Monetization.PAID_RANDOM_ATTRIBUTE, true) -- (caché tant qu'on ne sait pas)
	for attempt = 1, POLICY_TRIES do
		if not player.Parent then
			return
		end
		local ok, info = pcall(function()
			return PolicyService:GetPolicyInfoForPlayerAsync(player)
		end)
		if ok and typeof(info) == "table" then
			if player.Parent then
				-- (un champ absent compte comme « interdit »)
				player:SetAttribute(Monetization.PAID_RANDOM_ATTRIBUTE, info.ArePaidRandomItemsRestricted ~= false)
			end
			return
		end
		warn(`[Monetization] Règles de Roblox (PolicyService) illisibles pour {player.Name} (essai {attempt}) :`, info)
		if attempt < POLICY_TRIES then
			task.wait(attempt * 5)
		end
	end
	-- Tous les essais ont raté : l'attribut reste à true (achat caché).
end

-- Tests dans Studio uniquement (ServerStorage.StudioDebug, commande « PaidRandom ») : restricted = true fait comme un
-- joueur à qui Roblox interdit ces achats. Ne fait rien dans le jeu publié. Renvoie la valeur de l'attribut.
function Monetization.setStudioPaidRandom(player: Player, restricted: boolean): boolean?
	if not RunService:IsStudio() then
		return nil
	end
	player:SetAttribute(Monetization.PAID_RANDOM_ATTRIBUTE, restricted == true)
	return player:GetAttribute(Monetization.PAID_RANDOM_ATTRIBUTE)
end

local function onPlayerAdded(player: Player)
	task.spawn(checkPaidRandomPolicy, player)
	-- Parties de test dans Studio : passes offerts selon Config.STUDIO_TEST_PASSES (pas dans le jeu publié,
	-- ni pendant les tests automatiques, qui partent d'un joueur sans pass).
	local isAutoTest = game:GetService("ReplicatedStorage"):FindFirstChild("__AutoPlayTest") ~= nil
	if RunService:IsStudio() and not isAutoTest then
		for name, pass in PASSES do
			if Config.STUDIO_TEST_PASSES and Config.STUDIO_TEST_PASSES[pass.configKey] == true then
				studioPasses[player] = studioPasses[player] or {}
				studioPasses[player][name] = true
			end
		end
	end
	local checks = {}
	arrivalChecks[player] = checks
	for name in PASSES do
		publishPass(player, name) -- false tant que Roblox n'a pas répondu
		checks[name] = true
		task.spawn(function()
			-- Tests automatiques (place de test de tools/studio-test seulement) : on ne demande pas à Roblox. Le
			-- joueur de test est le propriétaire du jeu, et le créateur d'un pass le possède toujours : les tests
			-- « sans pass » échouaient dès que les vrais numéros ont été mis dans Config.GamePasses (30/09/2026).
			if not isAutoTest then
				local ok, err = pcall(checkPass, player, name)
				if not ok then
					warn(`[Monetization] Erreur pendant la vérification du pass {name} :`, err)
				end
			end
			checks[name] = nil -- possession connue (Monetization.passKnown)
		end)
	end
end

-- Tests dans Studio uniquement (ServerStorage.StudioDebug, commande « Pass ») : donne (true) ou retire
-- (false) un pass sans l'acheter. Ne fait rien dans le jeu publié.
function Monetization.setStudioPass(player: Player, name: string, owned: boolean): boolean
	if not RunService:IsStudio() or not PASSES[name] then
		return false
	end
	studioPasses[player] = studioPasses[player] or {}
	studioPasses[player][name] = owned == true
	publishPass(player, name)
	return true
end

function Monetization.start()
	MarketplaceService.ProcessReceipt = processReceipt
	if Config.Products.BONUS_SPIN == 0 then
		print("[Monetization] Config.Products.BONUS_SPIN = 0 : l'achat Robux de la machine à bonus est désactivé")
	end

	for name, pass in PASSES do
		if passId(name) == 0 then
			print(`[Monetization] Config.GamePasses.{pass.configKey} = 0 : le pass {pass.displayName} n'est pas encore en vente`)
		end
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		ownedPasses[player] = nil
		studioPasses[player] = nil
		arrivalChecks[player] = nil
	end)

	-- Achat depuis la boutique : effet immédiat. wasPurchased vient de Roblox (le client ne peut pas
	-- déclencher cet évènement) ; sinon on redemande à Roblox, au cas où il le possédait déjà.
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, wasPurchased)
		for name, pass in PASSES do
			local id = passId(name)
			if id ~= 0 and gamePassId == id then
				if wasPurchased then
					grantPass(player, name)
					Remotes.get("Notify"):FireClient(player, `Merci ! Pass {pass.displayName} activé`, "Success")
				else
					task.spawn(checkPass, player, name)
				end
			end
		end
	end)
end

return Monetization

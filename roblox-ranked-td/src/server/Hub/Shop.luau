-- LES ACHATS EN ROBUX (numéros des pass et des produits : Shared/Monetization.luau). Demandes du propriétaire
-- (04/10/2026) : « passer le temps des couveuses en Robux aussi, 1 Robux les 5 min », « une 3e couveuse d'une autre
-- couleur, incubation 2 fois plus rapide, à payer en Robux, 99 Robux », « mets-la en or », « x2 XP 99 Robux aussi,
-- et x2 argent 199 Robux ».
--   * les pass (Monetization.PASSES : la couveuse royale, XP x2, argent x2) : Roblox dit qui les a
--     (UserOwnsGamePassAsync, à l'arrivée ; s'il ne répond pas, on redemande, et l'entraînement du camp attend la
--     réponse) ; un achat dans le jeu compte tout de suite (PromptGamePassPurchaseFinished). Leurs effets :
--     Hub/LevelsService.luau (Shop.owns) ;
--   * les produits « Finir l'œuf » : le serveur choisit le produit (Levels.robuxSkipPrice), note la couveuse visée (et
--     l'heure où son œuf devait être prêt) et ouvre la fenêtre d'achat ; quand Roblox confirme l'achat (ProcessReceipt),
--     cet œuf finit tout de suite (LevelsService, finishEgg) ; si l'œuf a changé entre-temps, le temps payé avance
--     seulement un œuf. Chaque reçu n'est compté qu'une fois (son numéro est gardé dans la sauvegarde,
--     data.levels.receipts) et n'est accepté qu'une fois la sauvegarde faite (sinon Roblox le renvoie). Un reçu qui
--     arrive pendant le chargement de ses données (Roblox renvoie les achats pas encore comptés à l'arrivée du joueur)
--     attend ces données ;
--   * la couveuse royale et « Finir l'œuf » ne sont jamais proposés là où Roblox interdit les objets aléatoires payants
--     (PolicyService : un œuf donne une tour au hasard ; ou si Roblox ne répond pas) ; aucun achat avec un numéro à 0,
--     ni un produit dont le prix sur Roblox n'est pas celui attendu.
-- Studio : les achats de Studio sont de faux achats (aucun Robux) ; les tests automatiques passent par StudioDebug
-- (« Levels », « Shop », ... : en bas). Dans Studio, les pass ne sont PAS demandés à Roblox : le compte du créateur
-- du jeu les a tous (vu le 05/10/2026 : les tests trouvaient des pièces déjà doublées) ; un achat de test de Studio,
-- ou le debug « Owned », les donne.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Levels = require(Shared.Levels)
local Monetization = require(Shared.Monetization)

local Shop = {}

-- Les pass liés aux œufs (une tour au hasard) : pas proposés là où les objets aléatoires payants sont interdits.
local EGG_PASSES = { Royal = true }
-- Message quand un pass vient d'être acheté.
local BOUGHT = {
	Royal = "👑 Couveuse royale débloquée : tes œufs y éclosent 2 fois plus vite !",
	Xp = "⭐ XP x2 : toute l'XP d'entraînement de tes tours est doublée !",
	Coins = "💵 Argent x2 : les pièces des niveaux sont doublées !",
}

-- Fonctions de Hub/LevelsService.luau : levelsOf(player), publish(player), notify(player, texte, genre),
-- finishEgg(player, levels, prix, couveuse, readyAt) -> texte du message, save(player) -> vrai si la sauvegarde est
-- faite, passBought(player, clé) (un pass vient d'être acheté, ou Roblox vient de dire qu'il l'a : l'XP du camp,
-- etc.), readyAt(player, couveuse) -> heure où l'œuf de cette couveuse sera prêt (tests Studio).
local hooks = nil
local owners = {} -- [clé du pass] = { [Player] = vrai }
local passIds = {} -- [clé du pass] = son numéro (Monetization.PASSES ; tests Studio : de faux numéros, debug « Pass »)
for key, pass in Monetization.PASSES do
	owners[key] = {}
	passIds[key] = pass.id
end
local checked = {} -- [Player] = vrai : Roblox a répondu (pays, pass)
local restricted = {} -- [Player] = vrai : objets aléatoires payants interdits chez lui (ou pas encore su)
-- [Player] = { [prix] = { index = couveuse visée par le dernier achat « Finir » ouvert à ce prix, readyAt = heure où
-- son œuf devait être prêt à ce moment-là } }
local pending = {}
local verified = {} -- [prix] = numéro du produit « Finir l'œuf », vérifié sur Roblox (le bon prix)

local PASS_TRIES = 3 -- essais de suite pour savoir s'il a un pass (Roblox ne répond pas toujours du premier coup)
local CHECK_ROUNDS = 10 -- tours de questions au plus (un toutes les CHECK_RETRY s) avant de le croire sans le pass
local CHECK_RETRY = 30
local RECEIPT_WAIT = 60 -- secondes d'attente de ses données pour un achat qui arrive pendant leur chargement
local checkRetry, tryWait = CHECK_RETRY, 2 -- (tests Studio : plus courts, debug « Check »)
local simulated = {} -- [Player] = réponses de Roblox imitées, une par question : true, false ou "none" (tests Studio)
local VERIFY_ROUNDS = 5 -- tours de vérification des produits au démarrage (Roblox peut ne pas répondre)

local function real(player): boolean
	return typeof(player) == "Instance"
end

-- Le prix d'un produit « Finir l'œuf », d'après son numéro (nil : pas un de nos produits). Un de nos produits pas
-- encore vérifié sur ce serveur (Roblox n'a pas répondu) compte quand même : il a été acheté ailleurs.
local function priceOf(productId: any): number?
	for price, id in verified do
		if id == productId then
			return price
		end
	end
	for price, id in Monetization.SKIP_PRODUCTS do
		if id ~= 0 and id == productId then
			return price
		end
	end
	return nil
end

-- Vrai s'il a ce pass ("Royal", "Xp", "Coins").
function Shop.owns(player: Player, key: string): boolean
	return owners[key] ~= nil and owners[key][player] == true
end

-- Vrai quand Roblox a répondu pour ce joueur (ses pass sont connus : l'XP de son camp peut être comptée). Un joueur
-- d'essai des tests Studio : tout de suite.
function Shop.ready(player: Player): boolean
	return not real(player) or checked[player] == true
end

-- État d'un pass pour ce joueur : "owned" (il l'a), "buy" (il peut l'acheter), "soon" (pas encore créé sur le Hub
-- Création : numéro à 0), "no" (pas proposé chez lui).
function Shop.passState(player: Player, key: string): string
	if Shop.owns(player, key) then
		return "owned"
	elseif EGG_PASSES[key] and restricted[player] then
		return "no"
	elseif not real(player) or not checked[player] then
		return "no"
	elseif (passIds[key] or 0) == 0 then
		return "soon"
	end
	return "buy"
end

-- Les prix des produits « Finir l'œuf » proposés à ce joueur (vérifiés, du moins cher au plus cher ; vide : aucun).
function Shop.skipPrices(player: Player): { number }
	local prices = {}
	if restricted[player] or not checked[player] then
		return prices
	end
	for price in verified do
		table.insert(prices, price)
	end
	table.sort(prices)
	return prices
end

-- Ouvre la fenêtre d'achat d'un pass.
function Shop.promptPass(player: Player, key: any): (boolean, string?)
	if typeof(key) ~= "string" or not passIds[key] then
		return false, nil
	end
	local state = Shop.passState(player, key)
	if state == "owned" then
		return false, "Tu as déjà ce pass"
	elseif state ~= "buy" then
		return false, nil
	end
	MarketplaceService:PromptGamePassPurchase(player, passIds[key])
	return true, nil
end

-- Ouvre la fenêtre d'achat « Finir l'œuf » pour la couveuse `index`, dont l'œuf doit encore couver `seconds` s (il
-- sera prêt à l'heure `readyAt` : seul CET œuf pourra finir d'un coup). dryRun (tests Studio) : tout pareil, sans
-- ouvrir la fenêtre. Renvoie (fait, raison, prix, numéro du produit).
function Shop.promptSkip(player: Player, index: number, seconds: number, readyAt: number?, dryRun: boolean?): (boolean, string?, number?, number?)
	local prices = Shop.skipPrices(player)
	local price = if #prices > 0 then Levels.robuxSkipPrice(seconds, prices) else 0
	local productId = verified[price]
	if price <= 0 or not productId then
		return false, nil, nil, nil
	end
	pending[player] = pending[player] or {}
	pending[player][price] = { index = index, readyAt = readyAt }
	if not dryRun then
		MarketplaceService:PromptProductPurchase(player, productId)
	end
	return true, nil, price, productId
end

-- Roblox confirme un achat de produit (MarketplaceService.ProcessReceipt) : l'œuf finit, le reçu est noté et sauvegardé.
local function processReceipt(receipt): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local levels = player and hooks.levelsOf(player)
	-- (achat renvoyé par Roblox à son arrivée, pendant le chargement de ses données : on les attend)
	local deadline = os.clock() + RECEIPT_WAIT
	while player and not levels and player.Parent == Players and os.clock() < deadline do
		task.wait(0.5)
		levels = hooks.levelsOf(player)
	end
	if not player or not levels then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- (Roblox le renverra à sa prochaine visite)
	end
	local receiptId = tostring(receipt.PurchaseId)
	if table.find(levels.receipts, receiptId) then
		-- (déjà compté ; accepté seulement une fois la sauvegarde faite : la première a pu rater)
		return if hooks.save(player) then Enum.ProductPurchaseDecision.PurchaseGranted else Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local price = priceOf(receipt.ProductId)
	if not price then
		warn(`[Boutique] Produit inconnu : {receipt.ProductId}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local target = pending[player] and pending[player][price]
	if pending[player] then
		pending[player][price] = nil
	end
	local message = hooks.finishEgg(player, levels, price, target and target.index, target and target.readyAt)
	table.insert(levels.receipts, receiptId)
	while #levels.receipts > Levels.RECEIPTS_MAX do
		table.remove(levels.receipts, 1)
	end
	hooks.publish(player)
	hooks.notify(player, message, "Success")
	print(`[Boutique] {player.Name} : « Finir l'œuf » à {price} Robux`)
	if not hooks.save(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- (le reçu est noté : rien ne sera compté deux fois)
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- Vrai ou faux s'il a ce pass ; nil si Roblox n'a pas répondu (après PASS_TRIES essais).
local function ownsPass(player: Player, id: number): boolean?
	for attempt = 1, PASS_TRIES do
		local ok, owns
		local answers = simulated[player]
		if answers then
			local answer = table.remove(answers, 1)
			ok, owns = answer == true or answer == false, answer == true
		else
			ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
			end)
		end
		if ok then
			return owns == true
		end
		if attempt < PASS_TRIES and player.Parent == Players then
			task.wait(attempt * tryWait)
		end
	end
	return nil
end

-- Ses achats possibles : pays (objets aléatoires payants), pass déjà achetés. Appelé à son arrivée, données chargées.
-- Si Roblox ne répond pas pour un pass, on redemande toutes les CHECK_RETRY s (CHECK_ROUNDS fois au plus) : en
-- attendant, Shop.ready reste faux et l'entraînement du camp attend (sinon ses heures d'absence seraient comptées
-- sans son XP x2, pour de bon), et rien ne lui est proposé à l'achat.
local function checkPlayer(player: Player, onChecked, round: number?)
	local ok, info = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)
	restricted[player] = not ok or typeof(info) ~= "table" or info.ArePaidRandomItemsRestricted == true or nil
	local unanswered = false
	for key, id in passIds do
		if id ~= 0 and player.Parent == Players and (not RunService:IsStudio() or simulated[player]) and not owners[key][player] then
			local owns = ownsPass(player, id)
			if owns == nil then
				unanswered = true
			elseif owns then
				owners[key][player] = true
			end
		end
	end
	if player.Parent ~= Players then
		return
	end
	local current = round or 1
	if unanswered and current < CHECK_ROUNDS then
		warn(`[Boutique] Roblox ne dit pas encore quels pass a {player.Name} : nouvel essai dans {checkRetry} s`)
		task.delay(checkRetry, checkPlayer, player, onChecked, current + 1)
		return
	end
	checked[player] = true
	if onChecked then
		onChecked()
	end
	hooks.publish(player)
end

-- Les produits « Finir l'œuf » qui ont bien leur prix sur Roblox (au démarrage du serveur ; ceux pour lesquels Roblox
-- ne répond pas sont redemandés, VERIFY_ROUNDS tours au plus, de plus en plus espacés).
local function verifyProducts()
	local waiting = {} -- [prix] = numéro : pas encore de réponse de Roblox
	for price, id in Monetization.SKIP_PRODUCTS do
		if id ~= 0 then
			waiting[price] = id
		end
	end
	for round = 1, VERIFY_ROUNDS do
		for price, id in waiting do
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(id, Enum.InfoType.Product)
			end)
			if ok and typeof(info) == "table" then
				waiting[price] = nil
				if info.PriceInRobux == price then
					verified[price] = id
				else
					warn(`[Boutique] Produit {id} : {price} Robux attendus, {tostring(info.PriceInRobux)} sur Roblox : pas proposé`)
				end
			end
		end
		for _, player in Players:GetPlayers() do
			hooks.publish(player)
		end
		if next(waiting) == nil then
			return
		end
		if round < VERIFY_ROUNDS then
			task.wait(round * 10)
		end
	end
	for price, id in waiting do
		warn(`[Boutique] Produit {id} ({price} Robux) : Roblox ne répond pas, pas proposé sur ce serveur`)
	end
end

-- hookFunctions : voir `hooks` en haut. Appelée une fois par Hub/LevelsService.luau.
function Shop.start(hookFunctions)
	hooks = hookFunctions
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased or passId == 0 then
			return
		end
		for key, id in passIds do
			if id == passId and not owners[key][player] then
				owners[key][player] = true
				hooks.passBought(player, key)
				hooks.publish(player)
				hooks.notify(player, BOUGHT[key] or "Merci !", "Success")
			end
		end
	end)
	task.spawn(verifyProducts)
end

-- Le joueur est arrivé et ses données sont chargées (Hub/LevelsService.luau). onChecked() : quand Roblox a répondu.
function Shop.onLoaded(player: Player, onChecked)
	task.spawn(checkPlayer, player, onChecked)
end

function Shop.removePlayer(player: Player)
	for _, list in owners do
		list[player] = nil
	end
	checked[player] = nil
	restricted[player] = nil
	pending[player] = nil
	simulated[player] = nil
end

-- Tests Studio (StudioDebug « Levels », « Shop », ... ; jamais dans le jeu publié) :
--   "Owned", clé, vrai/faux    -> le joueur a (ou n'a pas) ce pass ("Royal", "Xp", "Coins"), sans rien acheter
--   "Restricted", vrai/faux    -> objets aléatoires payants interdits (ou permis) chez lui
--   "Pass", clé, numéro        -> un faux numéro pour ce pass (0 : pas encore créé, « bientôt »)
--   "Products", { [prix] = numéro } -> produits « Finir l'œuf » vérifiés (faux numéros), à la place de ceux du Hub
--   "Prompt", couveuse, secondes -> comme le bouton « Finir » en Robux, sans ouvrir la fenêtre : { ok, price, product }
--   "Receipt", numéro du produit, numéro du reçu -> comme si Roblox confirmait cet achat : la décision, en texte
--   "State"                    -> { passes = { [clé] = état }, prices, pending, ready }
--   "Check", réponses, secondes -> refait les questions de son arrivée (pays, pass), avec ces réponses de Roblox
--                                 imitées (true, false ou "none" = pas de réponse, une par question) et
--                                 `secondes` entre deux tours (sans attente entre deux essais)
function Shop.debug(player: Player, action: string, ...)
	local first, second = ...
	if action == "Owned" then
		if owners[first] then
			owners[first][player] = if second then true else nil
			if second then
				hooks.passBought(player, first)
			end
		end
	elseif action == "Restricted" then
		restricted[player] = if first then true else nil
		checked[player] = true
	elseif action == "Pass" then
		if passIds[first] then
			passIds[first] = tonumber(second) or 0
		end
	elseif action == "Products" then
		table.clear(verified)
		for price, id in if type(first) == "table" then first else {} do
			verified[tonumber(price) or 0] = id
		end
	elseif action == "Prompt" then
		local readyAt = if hooks and hooks.readyAt then hooks.readyAt(player, first) else nil
		local ok, _, price, productId = Shop.promptSkip(player, first, tonumber(second) or 0, readyAt, true)
		return { ok = ok, price = price, product = productId }
	elseif action == "Receipt" then
		return processReceipt({ PlayerId = player.UserId, ProductId = first, PurchaseId = second }).Name
	elseif action == "Check" then
		simulated[player] = if type(first) == "table" then table.clone(first) else {}
		checkRetry, tryWait = tonumber(second) or CHECK_RETRY, 0
		checked[player] = nil
		task.spawn(checkPlayer, player, nil, 1)
		return true
	elseif action == "State" then
		local passes = {}
		for key in passIds do
			passes[key] = Shop.passState(player, key)
		end
		return { passes = passes, prices = Shop.skipPrices(player), pending = pending[player], ready = Shop.ready(player) }
	end
	if hooks then
		hooks.publish(player)
	end
	return true
end

return Shop

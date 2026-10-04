-- Test des ŒUFS, côté serveur : tools/studio-test/run.ps1 -Test eggs.
-- 1) Seul (le client attend) : un œuf gagné à chaque victoire (doré au boss, commun en rejouant, rien en perdant,
--    perdu si la réserve est pleine), poser un œuf (couveuse vide et œuf en réserve seulement), pas d'ouverture avant
--    son temps (l'heure du serveur avance avec le debug « Clock »), la tour sortie (nouvelle : debug « EggForce » ;
--    une tour de palier 2 prend la place de sa tour de base dans la barre ; doublon : XP d'entraînement ; attribut
--    « Hatch » du joueur ; au hasard, un œuf commun : toujours une tour de palier 1), finir tout de suite avec des
--    pièces, acheter
--    la 2e couveuse, et les couveuses de la parcelle (l'œuf de sa couleur, l'étiquette, l'invite vers l'onglet Œufs).
--    LA COUVEUSE ROYALE et LES ACHATS EN ROBUX (Hub/Shop.luau, faux numéros, aucune vraie fenêtre d'achat : debug
--    « Shop ») : pas d'œuf sans le pass, dorée et couronnée sur la parcelle, 2 fois plus rapide ; « Finir » en Robux au
--    bon prix, l'achat confirmé par Roblox (debug « Receipt ») : l'œuf prêt, un reçu compté une fois, un œuf déjà fini
--    (le temps va à un autre œuf, sinon des pièces), un produit inconnu refusé ; XP x2 et Argent x2 à la fin d'un
--    niveau ; les états des pass (bientôt, pas proposé, à acheter).
--    Les ŒUFS SPÉCIAUX : l'œuf carmin en plus de l'œuf doré au boss du niveau 10 (la 1re fois ; en rejouant : debug
--    « BonusForce »), jamais perdu même réserve pleine, il donne l'Arc carmin ; ses motifs en 3D (œuf des ronces).
-- 2) Il donne la main au client (attribut EggsTestPhase = "Client" de ReplicatedStorage) et répond à ses demandes par
--    la RemoteFunction ReplicatedStorage.__EggsTest.
-- StudioDebug n'existe que dans Studio.
return function(log)
	local HttpService = game:GetService("HttpService")
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local dbg = game:GetService("ServerStorage"):WaitForChild("StudioDebug", 30)
	local Levels = require(ReplicatedStorage:WaitForChild("Shared").Levels)
	local IdleTowers = require(ReplicatedStorage.Shared.IdleTowers)

	local function check(ok, message)
		log(if ok then "Info" else "Error", `[{if ok then "PASS" else "FAIL"}] œufs (serveur) : {message}`)
	end

	local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
	for _ = 1, 150 do
		if dbg:Invoke(player, "Data") and typeof(player:GetAttribute("Plot")) == "number" and player:GetAttribute("LevelsState") ~= nil then
			break
		end
		task.wait(0.2)
	end
	local function levels(...)
		return dbg:Invoke(player, "Levels", ...)
	end
	local function action(...)
		return levels("Action", ...)
	end
	local function data()
		return levels("State").levels
	end
	local function decode(raw)
		if typeof(raw) ~= "string" then
			return nil
		end
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(raw)
		end)
		return if ok then decoded else nil
	end
	local function arenaFolder()
		local index = player:GetAttribute("LevelArena")
		local arenas = workspace:FindFirstChild("Arenas")
		return if typeof(index) == "number" and arenas then arenas:FindFirstChild("Arena" .. Levels.slotOf(index)) else nil
	end
	local function win(level, won)
		action("Start", level)
		levels("Finish", won)
		local arena = arenaFolder()
		local result = decode(arena and arena:GetAttribute("Result")) or {}
		action("Quit")
		return result
	end
	local function eggs(eggType)
		return data().eggs[eggType] or 0
	end

	-- Le joueur a réussi 9 niveaux, a 10 000 pièces, l'Archer et la Catapulte (sortie de l'œuf du niveau 1), aucun œuf,
	-- une couveuse.
	for key, value in {
		best = 9,
		coins = 10000,
		eggs = {},
		hatchers = { { egg = "", readyAt = 0 } },
		towers = { MachineGun = true, Bomb = true },
		bar = { "MachineGun", "Bomb" },
		xp = {},
		tutorial = Levels.TUTORIAL.DONE,
	} do
		levels("Set", key, value)
	end

	------------------------------------------------------------------
	-- Un œuf à chaque victoire
	------------------------------------------------------------------
	local result = win(10, true)
	check(result.egg == "Gold" and result.eggKept == true and eggs("Gold") == 1, `niveau 10 (boss) réussi pour la première fois : un œuf doré ({tostring(result.egg)})`)
	check(
		result.bonusEgg == "Crimson" and result.bonusKept == true and eggs("Crimson") == 1,
		`... et, en plus, l'œuf spécial du territoire : l'œuf carmin ({tostring(result.bonusEgg)}, {eggs("Crimson")} en réserve)`
	)
	result = win(3, true)
	check(result.egg == "Common" and eggs("Common") == 1, `niveau 3 rejoué : un œuf commun ({tostring(result.egg)})`)
	result = win(3, false)
	check(result.egg == nil and eggs("Common") == 1, "une défaite ne donne pas d'œuf")
	levels("Egg", "Common", Levels.EGG_MAX)
	result = win(3, true)
	check(result.egg == "Common" and result.eggKept == false and Levels.eggCount(data()) == Levels.EGG_MAX, `réserve pleine ({Levels.EGG_MAX} œufs) : l'œuf gagné est perdu, et l'écran de fin le dira`)
	levels("BonusForce", true)
	result = win(10, true)
	check(
		result.egg == "Rare" and result.eggKept == false and result.bonusEgg == "Crimson" and result.bonusKept == true and eggs("Crimson") == 2,
		`boss du niveau 10 rejoué (le tirage de 1 sur 10 gagné) : l'œuf carmin, gardé même réserve pleine ({eggs("Crimson")} en réserve) ; l'œuf rare, lui, est perdu`
	)
	levels("BonusForce", false)
	result = win(10, true)
	check(result.bonusEgg == nil and eggs("Crimson") == 2, "boss du niveau 10 rejoué (tirage perdu) : pas d'œuf spécial")
	levels("Set", "eggs", { Gold = 1, Common = 3 })

	------------------------------------------------------------------
	-- Couver, ouvrir
	------------------------------------------------------------------
	local ok, why = action("EggStart", 1, "Gold")
	local hatcher = data().hatchers[1]
	check(ok and hatcher.egg == "Gold" and eggs("Gold") == 0, "l'œuf doré est posé dans la couveuse 1 (il quitte la réserve)")
	ok, why = action("EggStart", 1, "Common")
	check(not ok and why == "Cette couveuse est déjà occupée", `une couveuse occupée refuse un autre œuf (« {tostring(why)} »)`)
	ok, why = action("EggOpen", 1)
	check(not ok and why == "Cet œuf n'est pas encore prêt", `pas d'ouverture avant son temps (« {tostring(why)} »)`)
	levels("Clock", Levels.EGGS.Gold.seconds - 60)
	ok = action("EggOpen", 1)
	check(not ok and data().hatchers[1].egg == "Gold", "une minute avant : toujours pas prêt")
	levels("Clock", 61)
	levels("EggForce", "VoidSorcerer")
	ok = action("EggOpen", 1)
	local hatch = decode(player:GetAttribute("Hatch")) or {}
	local mine = data()
	check(
		ok and hatch.tower == "VoidSorcerer" and hatch.new == true and hatch.egg == "Gold" and mine.towers.VoidSorcerer == true
			and table.find(mine.bar, "VoidSorcerer") ~= nil and mine.hatchers[1].egg == "",
		`4 h plus tard, l'œuf doré s'ouvre : une nouvelle tour de palier 2, le Sorcier du néant (attribut Hatch : {tostring(hatch.tower)}, nouvelle : {tostring(hatch.new)}), dans sa barre`
	)
	-- Une tour de palier 2 prend la place de sa tour de base dans la barre (l'Archer passe au bout).
	action("EggStart", 1, "Common")
	levels("Clock", Levels.EGGS.Common.seconds + 1)
	levels("EggForce", "FireArcher")
	action("EggOpen", 1)
	hatch = decode(player:GetAttribute("Hatch")) or {}
	local bar = Levels.ownedTowers(data())
	check(
		hatch.tower == "FireArcher" and hatch.new == true and bar[1] == "FireArcher" and bar[#bar] == "MachineGun" and data().towers.MachineGun == true,
		`l'Archer enflammé prend la place de l'Archer dans la barre : {table.concat(bar, ", ")}`
	)
	-- Un doublon donne de l'XP d'entraînement à cette tour ; « Finir » tout de suite.
	local coinsBefore = data().coins
	local xpBefore = data().xp.FireArcher or 0
	action("EggStart", 1, "Common")
	ok = action("EggSkip", 1)
	local skipCost = Levels.skipCost(Levels.EGGS.Common.seconds)
	levels("EggForce", "FireArcher")
	local opened = action("EggOpen", 1)
	hatch = decode(player:GetAttribute("Hatch")) or {}
	check(
		hatch.tower == "FireArcher" and hatch.new == false and hatch.xp == Levels.DUPLICATE_XP.Common
			and math.abs((data().xp.FireArcher or 0) - xpBefore - Levels.DUPLICATE_XP.Common) < 1e-6,
		`un doublon (l'Archer enflammé, déjà à lui) : +{tostring(hatch.xp)} XP d'entraînement pour lui`
	)
	check(ok and opened and data().coins == coinsBefore - skipCost, `« Finir » tout de suite : {skipCost} pièces, puis l'œuf s'ouvre`)
	-- Un œuf commun ouvert au hasard donne toujours une tour de palier 1 (les tours de palier 2 sortent des œufs rares
	-- et dorés : Levels.EGGS[type].tier2).
	levels("Egg", "Common", 6)
	local tierOne = true
	for _ = 1, 6 do
		action("EggStart", 1, "Common")
		action("EggSkip", 1)
		action("EggOpen", 1)
		hatch = decode(player:GetAttribute("Hatch")) or {}
		tierOne = tierOne and IdleTowers.tierOf(hatch.tower or "") == 1 and IdleTowers.Defs[hatch.tower] ~= nil
	end
	check(tierOne, "6 œufs communs ouverts au hasard : toujours une tour de palier 1")
	-- L'œuf carmin donne toujours l'Arc carmin (une tour spéciale : à la fin de la barre).
	levels("Set", "eggs", { Crimson = 1 })
	local crimsonStarted = action("EggStart", 1, "Crimson")
	levels("Clock", Levels.EGGS.Crimson.seconds + 1)
	local crimsonOpened = action("EggOpen", 1)
	hatch = decode(player:GetAttribute("Hatch")) or {}
	local crimsonBar = Levels.ownedTowers(data())
	check(
		crimsonStarted and crimsonOpened and hatch.tower == "CrimsonBow" and hatch.new == true and hatch.egg == "Crimson" and data().towers.CrimsonBow == true
			and table.find(crimsonBar, "CrimsonBow") ~= nil and (data().eggs.Crimson or 0) == 0,
		`l'œuf carmin couve 1 h puis donne l'Arc carmin (attribut Hatch : {tostring(hatch.tower)}) ; barre : {table.concat(crimsonBar, ", ")}`
	)

	------------------------------------------------------------------
	-- Acheter des couveuses : la 2e avec des pièces ; la 3e est la COUVEUSE ROYALE (pass en Robux)
	------------------------------------------------------------------
	coinsBefore = data().coins
	local bought2 = action("HatcherBuy")
	local bought3, why3 = action("HatcherBuy")
	check(
		bought2 and not bought3 and why3 == "Tu as déjà toutes les couveuses" and #data().hatchers == 2 and #Levels.HATCHER_COST == 2
			and data().coins == coinsBefore - Levels.HATCHER_COST[2],
		`couveuses à pièces : la 2e ({Levels.HATCHER_COST[2]}), pas de 3e (« {tostring(why3)} » : la 3e est la couveuse royale, en Robux)`
	)
	levels("Shop", "Restricted", false) -- (achats en Robux d'œufs permis chez lui)
	levels("Set", "eggs", { Gold = 1 })
	local royalRefused = action("EggStart", Levels.ROYAL.index, "Gold")
	check(not royalRefused and (data().eggs.Gold or 0) == 1 and data().royal.egg == "", "la couveuse royale : pas d'œuf sans le pass")
	levels("Shop", "Owned", "Royal", true) -- (comme s'il avait acheté le pass « Couveuse royale »)

	------------------------------------------------------------------
	-- Les couveuses de la parcelle
	------------------------------------------------------------------
	levels("Set", "eggs", { Rare = 1, Common = 2, Bramble = 1 })
	action("EggStart", 2, "Rare")
	action("EggStart", 3, "Bramble")
	task.wait(1.5)
	local plots = workspace:FindFirstChild("Hub") and workspace.Hub:FindFirstChild("Plots")
	local plot = plots and plots:FindFirstChild("Plot" .. player:GetAttribute("Plot"))
	local function hatcherModel(index)
		return plot and plot:FindFirstChild("Hatcher" .. index)
	end
	local model1, model2 = hatcherModel(1), hatcherModel(2)
	local egg2 = model2 and model2:FindFirstChild("Egg")
	local label2 = model2 and model2:FindFirstChild("HatcherLabel")
	local prompt1 = model1 and model1:FindFirstChild("HatcherPedestal") and model1.HatcherPedestal:FindFirstChild("HatcherPrompt")
	check(
		model1 ~= nil and model2 ~= nil and hatcherModel(3) ~= nil and egg2 ~= nil and egg2.Transparency == 0 and egg2.Color == Levels.EGGS.Rare.color
			and model1.Egg.Transparency == 1 and label2 ~= nil and label2.Panel.Title.Text == "COUVEUSE 2" and label2.Panel.Sub.Text == "Œuf rare"
			and string.match(label2.Panel.Timer.Text, "^%d+:%d%d$") ~= nil and prompt1 ~= nil and prompt1:GetAttribute("CampTab") == "Œufs" and prompt1.Enabled,
		`la parcelle a 3 couveuses : l'œuf rare dans la 2e (sa couleur, « {label2 and label2.Panel.Sub.Text or "?"} », {label2 and label2.Panel.Timer.Text or "?"}), une invite vers l'onglet Œufs`
	)
	local decor1, decor2 = model1 and model1:FindFirstChild("EggDecor"), model2 and model2:FindFirstChild("EggDecor")
	check(
		decor1 ~= nil and decor2 ~= nil and #decor1:GetChildren() == 0 and #decor2:GetChildren() > 0,
		`l'œuf rare de la parcelle a ses motifs ({decor2 and #decor2:GetChildren() or 0} pièces : bande et points) ; la couveuse vide n'en a pas`
	)
	local model3 = hatcherModel(3)
	local decor3 = model3 and model3:FindFirstChild("EggDecor")
	local kinds = {}
	for _, piece in if decor3 then decor3:GetChildren() else {} do
		kinds[piece.Name] = (kinds[piece.Name] or 0) + 1
	end
	check(
		model3 ~= nil and model3.Egg.Transparency == 0 and model3.Egg.Color == Levels.EGGS.Bramble.color and (kinds.EggStripe or 0) >= 10
			and (kinds.Thorn or 0) > 0 and (kinds.Leaf or 0) > 0 and model3.HatcherLabel.Panel.Sub.Text == "Œuf des ronces",
		`l'œuf des ronces dans la 3e couveuse de la parcelle : vert, avec ses ronces en 3D ({kinds.EggStripe or 0} traits, {kinds.Thorn or 0} épines, {kinds.Leaf or 0} feuilles)`
	)
	-- La 3e couveuse est la couveuse royale : dorée, couronnée ; l'œuf y couve 2 fois moins longtemps.
	local function published()
		return decode(player:GetAttribute("LevelsState")) or {}
	end
	local crowns = 0
	for _, part in if model3 then model3:GetChildren() else {} do
		if part.Name == "RoyalCrownPoint" then
			crowns += 1
		end
	end
	local royalNow = published().royal or {}
	check(
		model3 ~= nil and model3.HatcherLabel.Panel.Title.Text == "👑 COUVEUSE ROYALE" and model3.HatcherPedestal.Color == Color3.fromRGB(214, 164, 52)
			and crowns == 6 and royalNow.egg == "Bramble" and math.abs((tonumber(royalNow.readyIn) or 0) - Levels.EGGS.Bramble.seconds / 2) <= 5,
		`la 3e couveuse de la parcelle est la couveuse royale (dorée, {crowns} pointes de couronne) : l'œuf des ronces y couve {math.floor((tonumber(royalNow.readyIn) or 0) / 60)} min au lieu de {Levels.EGGS.Bramble.seconds // 60}`
	)
	levels("Clock", Levels.EGGS.Rare.seconds + 1)
	task.wait(1.5)
	check(
		label2 ~= nil and label2.Panel.Sub.Text == "Œuf rare : prêt !" and label2.Panel.Timer.Text == "" and egg2.Material == Enum.Material.Neon and egg2.PointLight.Enabled,
		"l'œuf prêt brille sur la parcelle (« Œuf rare : prêt ! »)"
	)
	action("EggOpen", 2)
	task.wait(0.5)
	check(egg2 ~= nil and egg2.Transparency == 1 and label2.Panel.Sub.Text == "Vide : pose un œuf", "ouvert : la couveuse de la parcelle est vide")

	------------------------------------------------------------------
	-- Les ACHATS EN ROBUX (Hub/Shop.luau ; faux numéros de produits, aucune vraie fenêtre d'achat ; les confirmations
	-- de Roblox sont imitées par le debug « Receipt »)
	------------------------------------------------------------------
	levels("Shop", "Products", { ["1"] = 101, ["2"] = 102, ["3"] = 103, ["6"] = 106, ["12"] = 112, ["24"] = 124, ["48"] = 148 })
	levels("Set", "eggs", { Gold = 1, Rare = 1 })
	action("EggOpen", Levels.ROYAL.index) -- (l'œuf des ronces, prêt depuis l'heure avancée)
	action("EggStart", Levels.ROYAL.index, "Gold")
	local goldIn = tonumber((published().royal or {}).readyIn) or 0
	local prompt = levels("Shop", "Prompt", Levels.ROYAL.index, goldIn)
	local coinsNow = data().coins
	local firstReceipt = levels("Shop", "Receipt", 124, "TEST-1")
	local finishedIn = tonumber((published().royal or {}).readyIn) or -1
	local again = levels("Shop", "Receipt", 124, "TEST-1")
	check(
		math.abs(goldIn - 2 * 3600) <= 5 and prompt.ok and prompt.price == 24 and prompt.product == 124 and firstReceipt == "PurchaseGranted" and finishedIn == 0
			and again == "PurchaseGranted" and table.find(data().receipts, "TEST-1") ~= nil and data().coins == coinsNow,
		`œuf doré dans la couveuse royale ({math.floor(goldIn / 60)} min) : « Finir » à {tostring(prompt.price)} Robux (produit {tostring(prompt.product)}) ; achat confirmé : prêt ({finishedIn} s) ; le même reçu encore : « {tostring(again)} », rien de plus`
	)
	-- Un reçu pour un œuf déjà fini : le temps payé avance l'œuf qui a le plus à attendre ; plus aucun œuf qui couve :
	-- rendu en pièces de niveau. Un produit inconnu : pas accepté (Roblox le renverra).
	action("EggStart", 2, "Rare")
	local rareBefore = tonumber(((published().hatchers or {})[2] or {}).readyIn) or 0
	levels("Shop", "Prompt", Levels.ROYAL.index, 1800) -- (prix 6, pour la couveuse royale, déjà prête)
	local moved = levels("Shop", "Receipt", 106, "TEST-2")
	local rareAfter = tonumber(((published().hatchers or {})[2] or {}).readyIn) or 0
	action("EggSkip", 2) -- (en pièces : prêt)
	local coinsBefore3 = data().coins
	local refunded = levels("Shop", "Receipt", 101, "TEST-3")
	local unknown = levels("Shop", "Receipt", 999, "TEST-4")
	check(
		moved == "PurchaseGranted" and math.abs((rareBefore - rareAfter) - 6 * Levels.ROBUX_SKIP_SECONDS) <= 3 and refunded == "PurchaseGranted"
			and data().coins == coinsBefore3 + Levels.skipCost(Levels.ROBUX_SKIP_SECONDS) and unknown == "NotProcessedYet",
		`reçu d'un œuf déjà fini : l'œuf rare avance de {math.floor((rareBefore - rareAfter) / 60)} min ; plus aucun œuf : +{data().coins - coinsBefore3} pièces ; produit inconnu : « {tostring(unknown)} »`
	)
	-- Pass XP x2 et Argent x2 : la fin d'un niveau (pièces et XP doublées, dit sur l'écran de fin).
	local plain = win(5, true)
	levels("Shop", "Owned", "Coins", true)
	levels("Shop", "Owned", "Xp", true)
	local boosted = win(5, true)
	levels("Shop", "Owned", "Coins", false)
	levels("Shop", "Owned", "Xp", false)
	check(
		(tonumber(plain.reward) or 0) > 0 and boosted.reward == plain.reward * 2 and boosted.xp == (plain.xp or 0) * 2 and boosted.coinsX2 == true
			and boosted.xpX2 == true and plain.coinsX2 == false,
		`pass Argent x2 et XP x2 : niveau 5 rejoué, {tostring(plain.reward)} pièces et {tostring(plain.xp)} XP sans les pass, {tostring(boosted.reward)} et {tostring(boosted.xp)} avec`
	)
	-- Les états des pass : pas encore créés sur le Hub Création (numéro 0) : « bientôt » ; là où les achats en Robux
	-- d'œufs sont interdits : la couveuse royale n'est pas proposée, ni « Finir » en Robux (XP x2 et Argent x2 : si).
	action("EggOpen", Levels.ROYAL.index)
	levels("Shop", "Owned", "Royal", false)
	local soon = levels("Shop", "State")
	levels("Shop", "Restricted", true)
	local restrictedState = levels("Shop", "State")
	levels("Shop", "Restricted", false)
	levels("Shop", "Pass", "Royal", 777)
	local buyable = levels("Shop", "State")
	task.wait(1)
	local sale = model3 and model3.HatcherLabel.Panel.Sub.Text
	check(
		soon.passes.Royal == "soon" and soon.passes.Xp == "soon" and soon.passes.Coins == "soon" and restrictedState.passes.Royal == "no"
			and #restrictedState.prices == 0 and restrictedState.passes.Xp == "soon" and buyable.passes.Royal == "buy" and #buyable.prices == 7
			and model3 ~= nil and model3.HatcherPedestal.Transparency == 0 and sale == "2 fois plus rapide • 99 R$",
		`pass : pas encore créés « {tostring(soon.passes.Royal)} », achats d'œufs interdits « {tostring(restrictedState.passes.Royal)} » ({#restrictedState.prices} prix), à acheter « {tostring(buyable.passes.Royal)} » ; la couveuse royale reste sur la parcelle : « {tostring(sale)} »`
	)

	------------------------------------------------------------------
	-- Le client prend la main
	------------------------------------------------------------------
	for key, value in {
		coins = 10000,
		eggs = { Common = 2, Gold = 1, Copper = 1 },
		hatchers = { { egg = "", readyAt = 0 } },
		towers = { MachineGun = true, Bomb = true },
		bar = { "MachineGun", "Bomb" },
	} do
		levels("Set", key, value)
	end
	local remote = Instance.new("RemoteFunction")
	remote.Name = "__EggsTest"
	remote.OnServerInvoke = function(who, command, ...)
		if who ~= player then
			return nil
		end
		if command == "Clock" then
			return levels("Clock", ...)
		elseif command == "Force" then
			return levels("EggForce", ...)
		elseif command == "Set" then
			return levels("Set", ...) ~= nil
		elseif command == "Win" then
			local level = ...
			action("Start", level)
			levels("Finish", true)
			return true
		elseif command == "Lose" then
			local level = ...
			action("Start", level)
			levels("Finish", false)
			return true
		elseif command == "Play" then
			-- (un niveau lancé pour de vrai, avec de quoi tout poser)
			local level = ...
			action("Start", level)
			levels("Gold", 1e6)
			return true
		elseif command == "Place" then
			return action("Place", ...)
		elseif command == "Skip" then
			return levels("Skip", ...)
		elseif command == "Quit" then
			return action("Quit")
		elseif command == "State" then
			return data()
		elseif command == "Shop" then
			return levels("Shop", ...)
		end
		return nil
	end
	remote.Parent = ReplicatedStorage
	ReplicatedStorage:SetAttribute("EggsTestPhase", "Client")
	log("Info", "[OEUFS] serveur du test prêt, le client prend la main")
end

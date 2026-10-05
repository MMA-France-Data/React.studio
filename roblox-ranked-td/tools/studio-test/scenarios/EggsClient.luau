-- Test des ŒUFS, côté client (la vraie interface) : tools/studio-test/run.ps1 -Test eggs.
-- Il attend que le serveur (scenarios/EggsServer.luau) ait fini ses vérifications, puis :
--   1) l'onglet « Œufs » : les trois œufs (nom, nombre, temps, chances), les couveuses (vide : « Poser »), l'aide ;
--   2) poser un œuf commun : la couveuse dit son œuf et le temps qui reste, « Finir : 75 💵 » ;
--   3) l'heure du serveur avance : « Prêt : ouvre-le ! », « OUVRIR ! » ; ouvert (Baliste du dragon, palier 2, nouvelle) :
--      le panneau de la tour sortie (sa tour de base, ce qu'elle fait) ; un doublon : « DOUBLON » et son XP ;
--   4) acheter la 2e couveuse : « COUVEUSE 2 (vide) », la 3e à acheter ; la pastille « ! » de l'onglet ;
--   5) gagner un niveau : l'écran de fin dit l'œuf gagné ; puis les 8 tours de palier 2 posées dans un niveau (la barre
--      de 8 tours, les autres en réserve ; leur parure ; captures palier2_niveau et palier2_pres) ;
--   6) à la taille d'un téléphone (750 x 332) : l'onglet Œufs tient dans la fenêtre.
-- Les ŒUFS SPÉCIAUX : leurs cartes (l'œuf de cuivre en réserve, « COUVER » ; les autres « 🔒 Boss du niveau N »), le
-- bouton « COUVER », la tour spéciale sortie (« 🌟 TOUR SPÉCIALE ! »), l'écran de fin du boss (l'œuf carmin en plus),
-- les 4 tours spéciales dans un niveau (leur parure ; captures speciales_niveau et speciales_pres).
-- « BLOQUÉ ? » : deux défaites de suite au même niveau : le conseil de l'écran de fin et le bouton qui relance le
-- niveau d'avant (capture bloque).
-- « SHOT:nom » = capture (out\eggs_<nom>.png) ; « PHONE:want=... » = run.ps1 redimensionne la fenêtre de Studio.
return function(log)
	local GuiService = game:GetService("GuiService")
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Levels = require(Shared.Levels)
	local IdleTowers = require(Shared.IdleTowers)
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local function say(message)
		log("Info", "[OEUFS] " .. message)
	end
	local function shot(name)
		say("SHOT:eggs_" .. name)
		task.wait(1.6)
	end
	local function check(ok, message)
		log(if ok then "Info" else "Error", `[{if ok then "PASS" else "FAIL"}] œufs : {message}`)
	end
	local function waitFor(condition, seconds)
		local deadline = os.clock() + seconds
		while os.clock() < deadline do
			if condition() then
				return true
			end
			task.wait(0.1)
		end
		return condition()
	end
	local function finish()
		say("EGGS:client=done")
		task.wait(1.5)
		say("PHONE:done")
	end

	local ready = waitFor(function()
		return ReplicatedStorage:GetAttribute("EggsTestPhase") == "Client"
	end, 240)
	local test = ReplicatedStorage:FindFirstChild("__EggsTest")
	local campGui = playerGui:WaitForChild("Levels", 30)
	local hudGui = playerGui:WaitForChild("LevelHud", 30)
	local revealGui = playerGui:WaitForChild("HatchReveal", 30)
	if not ready or not test or not campGui or not hudGui or not revealGui then
		check(false, `test impossible (serveur prêt : {tostring(ready)}, écrans : {tostring(campGui ~= nil)}, {tostring(hudGui ~= nil)}, {tostring(revealGui ~= nil)})`)
		finish()
		return
	end
	local window = campGui:WaitForChild("Window")
	local topBar = (GuiService:GetGuiInset()).Y
	local function screenSize()
		local viewport = workspace.CurrentCamera.ViewportSize
		return Vector2.new(viewport.X, viewport.Y - topBar)
	end
	local counter = 0
	local function act(gui, command)
		counter += 1
		gui:SetAttribute("TestAction", `{command}#{counter}`)
		task.wait(0.25)
	end
	local function rect(object)
		local position, size = object.AbsolutePosition, object.AbsoluteSize
		return position.X, position.Y, position.X + size.X, position.Y + size.Y
	end
	local function inside(object, container)
		local l, t, r, b = rect(object)
		local cl, ct, cr, cb = rect(container)
		return l >= cl - 1 and t >= ct - 1 and r <= cr + 1 and b <= cb + 1
	end
	local function onScreen(object)
		local screen = screenSize()
		local l, t, r, b = rect(object)
		return l >= -1 and t >= -1 and r <= screen.X + 1 and b <= screen.Y + 1
	end

	task.spawn(function()
		pcall(function()
			game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
		end)
	end)
	task.wait(0.5)
	-- (la partie serveur du test a ouvert des œufs : le panneau de la dernière tour sortie est encore là)
	act(campGui, "RevealClose")

	------------------------------------------------------------------
	-- 1) L'onglet « Œufs »
	------------------------------------------------------------------
	act(campGui, "Tab:Œufs")
	local page = window:WaitForChild("Page4")
	task.wait(0.4)
	local tab = window:FindFirstChild("Tab4")
	local common, gold = page:WaitForChild("Egg_Common"), page:WaitForChild("Egg_Gold")
	local row1, row2, row3 = page:WaitForChild("Hatcher1"), page:WaitForChild("Hatcher2"), page:WaitForChild("Hatcher3")
	check(
		page.Visible and tab ~= nil and tab.Text == "Œufs" and page.EggsTitle.Text == `TES ŒUFS (3/{Levels.EGG_MAX})` and common.EggName.Text == "Œuf commun"
			and common.Count.Text == "×2" and gold.Count.Text == "×1" and common.Time.Text == "Éclot en 15 min" and gold.Time.Text == "Éclot en 4 h"
			and common.Chances.Text == "Chances :\nCommune 70 % • Rare 25 % • Épique 5 %",
		`onglet « {tab and tab.Text or "?"} » : « {page.EggsTitle.Text} », œuf commun « {common.Count.Text} » « {common.Time.Text} », chances « {string.gsub(common.Chances.Text, "\n", " ⏎ ")} »`
	)
	check(
		row1.Visible and row1.Title.Text == "COUVEUSE 1 (vide)" and row1.Status.Text == "Pose un œuf :" and row1.Put_Common.Visible and row1.Put_Gold.Visible
			and not row1.Put_Rare.Visible and row1.Put_Common.Text == "Œuf commun" and row2.Visible and row2.Title.Text == "🔒 COUVEUSE 2"
			and row2.Action.Text == `Acheter : {Levels.HATCHER_COST[2]} 💵` and row3.Visible and row3.Title.Text == "👑 COUVEUSE ROYALE"
			and row3.Status.Text == "Tes œufs y éclosent 2 fois plus vite" and row3.Action.Text == "Acheter : 99 R$",
		`couveuses : « {row1.Title.Text} » « {row1.Status.Text} » (boutons « {row1.Put_Common.Text} » et « {row1.Put_Gold.Text} », sur une seule ligne : {tostring(row1.Put_Common.TextFits)}), « {row2.Title.Text} » « {row2.Action.Text} », la couveuse royale « {row3.Title.Text} » « {row3.Action.Text} »`
	)
	-- L'allure des œufs (demande du propriétaire, 04/10/2026 : « vrai style, les plus rares un peu violets ») : chaque
	-- carte a la vignette de son œuf dessiné ; des rayons derrière l'œuf rare et l'œuf doré, pas derrière le commun.
	local commonTile, goldTile = common:FindFirstChild("Icon"), gold:FindFirstChild("Icon")
	local rareTile = page:WaitForChild("Egg_Rare"):FindFirstChild("Icon")
	check(
		commonTile ~= nil and goldTile ~= nil and rareTile ~= nil and commonTile:FindFirstChild("EggArt") ~= nil and goldTile:FindFirstChild("EggArt") ~= nil
			and commonTile:FindFirstChild("Rays") == nil and goldTile:FindFirstChild("Rays") ~= nil and rareTile:FindFirstChild("Rays") ~= nil
			and goldTile.EggArt:FindFirstChild("Crown") ~= nil and commonTile.EggArt:FindFirstChild("Spot") ~= nil
			and #commonTile.EggArt:GetChildren() > 30, -- (la forme d'œuf : une rangée de ronds, son contour et son ombre)
		"cartes des œufs : chaque œuf est dessiné sur sa vignette (taches pour le commun, couronne violette pour le doré), rayons derrière le rare et le doré"
	)
	check(row1.Icon:FindFirstChild("Empty") ~= nil and row1.Icon:FindFirstChild("EggArt") == nil, "couveuse vide : un ovale sombre à la place de l'œuf")
	-- Les œufs spéciaux : une carte chacun (l'œuf de cuivre, en réserve : « COUVER » ; les autres, assombris, disent le
	-- boss qui les donne) ; chacun son dessin (zigzag doré, rivets, ronces, flocons), des rayons derrière.
	local crimsonCard, copperCard = page:WaitForChild("Special_Crimson"), page:WaitForChild("Special_Copper")
	local brambleCard, rimeCard = page:WaitForChild("Special_Bramble"), page:WaitForChild("Special_Rime")
	check(
		page.SpecialTitle.Text == "ŒUFS SPÉCIAUX" and copperCard.Count.Text == "×1" and copperCard.Put.Text == "COUVER" and not copperCard.Icon.Locked.Visible
			and copperCard.EggName.Text == "Œuf de cuivre" and copperCard.Tower.Text == "Arbalète de cuivre" and crimsonCard.Count.Text == ""
			and crimsonCard.Put.Text == "🔒 Boss du niveau 10" and crimsonCard.Icon.Locked.Visible and rimeCard.Put.Text == "🔒 Boss du niveau 40"
			and crimsonCard.Icon.EggArt:FindFirstChild("Zigzag") ~= nil and copperCard.Icon.EggArt:FindFirstChild("Rivet") ~= nil
			and brambleCard.Icon.EggArt:FindFirstChild("Vine") ~= nil and rimeCard.Icon.EggArt:FindFirstChild("Flake") ~= nil
			and crimsonCard.Icon:FindFirstChild("Rays") ~= nil and row1.AbsolutePosition.Y > copperCard.AbsolutePosition.Y + copperCard.AbsoluteSize.Y,
		`œufs spéciaux : « {copperCard.EggName.Text} » {copperCard.Count.Text} « {copperCard.Put.Text} » ; « {crimsonCard.Put.Text} », « {rimeCard.Put.Text} » ; les couveuses en dessous`
	)
	-- L'œuf des dunes (le désert, niveaux 41 à 50) attend l'ouverture de son territoire : pas de carte avant.
	local desertOpen = Levels.specialEggOpen("Dune")
	check(
		(page:FindFirstChild("Special_Dune") ~= nil) == desertOpen,
		`l'œuf des dunes : {if desertOpen then "sa carte est là (désert ouvert)" else "pas de carte tant que le désert est fermé"} (niveaux ouverts : {Levels.OPEN_COUNT})`
	)
	shot("onglet")

	------------------------------------------------------------------
	-- 2) Poser un œuf
	------------------------------------------------------------------
	act(campGui, "EggStart:1:Common")
	local placed = waitFor(function()
		return row1.Title.Text == "COUVEUSE 1 : Œuf commun"
	end, 4)
	task.wait(1.2)
	check(
		placed and string.match(row1.Status.Text, "^Encore 1[45]:%d%d$") ~= nil and row1.Action.Visible and row1.Action.Text == `Finir : {Levels.skipCost(Levels.EGGS.Common.seconds)} 💵`
			and not row1.Put_Common.Visible and common.Count.Text == "×1" and row1.Icon:FindFirstChild("EggArt") ~= nil
			and row1.RobuxSkip.Visible and row1.RobuxSkip.Text == "Finir : 3 R$",
		`œuf commun posé (dessiné dans la couveuse) : « {row1.Title.Text} », « {row1.Status.Text} », « {row1.Action.Text} », en Robux « {row1.RobuxSkip.Text} »`
	)
	shot("couve")
	-- Sur la parcelle : la couveuse 1 et son œuf, devant le point d'arrivée (fenêtre fermée).
	act(campGui, "Close")
	task.wait(1.5)
	shot("parcelle")
	act(campGui, "Tab:Œufs")

	------------------------------------------------------------------
	-- 3) Prêt, ouvert : nouvelle tour, puis doublon
	------------------------------------------------------------------
	test:InvokeServer("Clock", Levels.EGGS.Common.seconds + 1)
	local isReady = waitFor(function()
		return row1.Status.Text == "Prêt : ouvre-le !" and row1.Action.Text == "OUVRIR !"
	end, 5)
	check(isReady, `l'heure avance : « {row1.Status.Text} », « {row1.Action.Text} »`)
	test:InvokeServer("Force", "DragonBallista")
	act(campGui, "EggOpen:1")
	local revealed = waitFor(function()
		return revealGui.Enabled
	end, 5)
	task.wait(0.6)
	local panel = revealGui:WaitForChild("Panel")
	local role = `Carreau géant qui transperce {IdleTowers.Defs.DragonBallista.pierceMax} monstres et brûle le sol.`
	check(
		revealed and panel.Title.Text == "🎉 NOUVELLE TOUR !" and panel.TowerName.Text == "Baliste du dragon"
			and panel.Detail.Text == `Palier 2 de : Baliste lourde\n{role}\nÉpique : elle rejoint ta barre de tours`
			and panel.Ok.Text == "Super !" and onScreen(panel) and panel.Detail.TextFits,
		`la tour sortie (palier 2) : « {panel.Title.Text} », « {panel.TowerName.Text} », « {string.gsub(panel.Detail.Text, "\n", " ⏎ ")} »`
	)
	shot("nouvelle_tour")
	act(campGui, "RevealClose")
	check(not revealGui.Enabled and row1.Title.Text == "COUVEUSE 1 (vide)", "« Super ! » ferme le panneau ; la couveuse est vide")
	act(campGui, "EggStart:1:Common")
	test:InvokeServer("Clock", Levels.EGGS.Common.seconds + 1)
	test:InvokeServer("Force", "DragonBallista")
	waitFor(function()
		return row1.Action.Text == "OUVRIR !"
	end, 5)
	act(campGui, "EggOpen:1")
	waitFor(function()
		return revealGui.Enabled
	end, 5)
	task.wait(0.4)
	check(
		revealGui.Enabled and panel.Title.Text == "DOUBLON" and panel.TowerName.Text == "Baliste du dragon"
			and panel.Detail.Text == `Palier 2 de : Baliste lourde\n{role}\nÉpique : +{Levels.DUPLICATE_XP.Epic} XP d'entraînement pour cette tour`,
		`un doublon : « {panel.Title.Text} », « {panel.TowerName.Text} », « {string.gsub(panel.Detail.Text, "\n", " ⏎ ")} »`
	)
	shot("doublon")
	act(campGui, "RevealClose")

	------------------------------------------------------------------
	-- 4) Acheter la 2e couveuse ; la pastille de l'onglet
	------------------------------------------------------------------
	act(campGui, "HatcherBuy")
	local bought = waitFor(function()
		return row2.Title.Text == "COUVEUSE 2 (vide)" and row3.Visible
	end, 4)
	check(
		bought and row3.Title.Text == "👑 COUVEUSE ROYALE" and row3.Action.Text == "Acheter : 99 R$",
		`2e couveuse achetée : « {row2.Title.Text} », puis la couveuse royale « {row3.Title.Text} » « {row3.Action.Text} » (en Robux)`
	)
	act(campGui, "Tab:Entraînement")
	local badge = tab and tab:FindFirstChild("Badge")
	check(badge ~= nil and badge.Visible, "dans un autre onglet : la pastille « ! » de l'onglet Œufs dit qu'un œuf attend (couveuse vide, œuf en réserve)")
	-- « Mes tours » : la tour de palier 2 sortie de l'œuf (sa vignette 3D, ce qu'elle fait) ; celles qu'il n'a pas encore
	-- attendent « dans les œufs », avec un bouton vers l'onglet Œufs.
	act(campGui, "Tab:Mes tours")
	task.wait(1)
	local towerList = window.Page3.Towers
	local dragonRow, lockedFire = towerList:FindFirstChild("Tower_DragonBallista"), towerList:FindFirstChild("Locked_FireArcher")
	local dragonTexts = {}
	for _, child in (if dragonRow then dragonRow:GetDescendants() else {}) do
		if child:IsA("TextLabel") then
			table.insert(dragonTexts, child.Text)
		end
	end
	local dragonText = table.concat(dragonTexts, " | ")
	check(
		dragonRow ~= nil and dragonRow.Visible and string.find(dragonText, "Baliste du dragon", 1, true) ~= nil and string.find(dragonText, role, 1, true) ~= nil
			and lockedFire ~= nil and lockedFire.Visible and lockedFire.Price.Text == "Palier 2 de : Archer du rempart • dans les œufs" and lockedFire.Eggs.Text == "ŒUFS",
		`« Mes tours » : « {dragonText} » ; pas encore à lui : « {lockedFire and lockedFire.Price.Text or "?"} » « {lockedFire and lockedFire.Eggs.Text or "?"} »`
	)
	shot("mes_tours_palier2")
	-- Une tour spéciale pas encore à lui : son œuf et le boss qui le donne.
	local lockedCrimson = towerList:FindFirstChild("Locked_CrimsonBow")
	check(
		lockedCrimson ~= nil and lockedCrimson.Visible and lockedCrimson.Price.Text == "Spéciale • Œuf carmin • boss du niveau 10",
		`« Mes tours », tour spéciale pas encore à lui : « {lockedCrimson and lockedCrimson.Price.Text or "?"} »`
	)
	-- Le bouton « COUVER » de l'œuf de cuivre : dans la première couveuse vide ; 1 h plus tard, l'Arbalète de cuivre.
	act(campGui, "Tab:Œufs")
	local copperCard = page.Special_Copper
	act(campGui, "SpecialPut:Copper")
	local copperPlaced = waitFor(function()
		return row1.Title.Text == "COUVEUSE 1 : Œuf de cuivre" or row2.Title.Text == "COUVEUSE 2 : Œuf de cuivre"
		end, 4)
	task.wait(0.6)
	local copperRow = if row1.Title.Text == "COUVEUSE 1 : Œuf de cuivre" then 1 else 2
	check(
		copperPlaced and copperCard.Count.Text == "" and copperCard.Put.Text == "🔒 Boss du niveau 20" and copperCard.Icon.Locked.Visible,
		`« COUVER » : l'œuf de cuivre couve dans la couveuse {copperRow} ; sa carte : « {copperCard.Put.Text} »`
	)
	shot("oeuf_special_couve")
	-- Sur la parcelle : l'œuf de cuivre en 3D (sa bande rivetée), fenêtre fermée.
	act(campGui, "Close")
	task.wait(1.5)
	shot("parcelle_oeuf_special")
	act(campGui, "Tab:Œufs")
	test:InvokeServer("Clock", Levels.EGGS.Copper.seconds + 1)
	waitFor(function()
		return (if copperRow == 1 then row1 else row2).Action.Text == "OUVRIR !"
	end, 5)
	act(campGui, `EggOpen:{copperRow}`)
	local specialRevealed = waitFor(function()
		return revealGui.Enabled
	end, 5)
	task.wait(0.6)
	local copperRole = `Ses carreaux transpercent {IdleTowers.Defs.CopperCrossbow.pierceMax} monstres alignés.`
	check(
		specialRevealed and panel.Title.Text == "🌟 TOUR SPÉCIALE !" and panel.TowerName.Text == "Arbalète de cuivre"
			and panel.Detail.Text == `Le col des Pillards de cuivre\n{copperRole}\nSpéciale : elle rejoint ta barre de tours` and panel.Detail.TextFits,
		`la tour spéciale sortie : « {panel.Title.Text} », « {panel.TowerName.Text} », « {string.gsub(panel.Detail.Text, "\n", " ⏎ ")} »`
	)
	shot("tour_speciale")
	act(campGui, "RevealClose")

	-- La COUVEUSE ROYALE (pass en Robux, faux numéros : debug « Shop » du serveur) : un œuf doré y couve 2 h, « Finir »
	-- en Robux à 24 ; la page « 🛒 BOUTIQUE » : les 3 pass.
	test:InvokeServer("Shop", "Owned", "Royal", true)
	local royalOwned = waitFor(function()
		return row3.Title.Text == "👑 COUVEUSE ROYALE (vide)"
	end, 4)
	act(campGui, "EggStart:3:Gold")
	local royalGold = waitFor(function()
		return row3.Title.Text == "👑 COUVEUSE ROYALE : Œuf doré"
	end, 4)
	task.wait(1.2)
	check(
		royalOwned and royalGold and string.match(row3.Status.Text, "^Encore [12]:%d%d:%d%d$") ~= nil and row3.RobuxSkip.Visible and row3.RobuxSkip.Text == "Finir : 24 R$",
		`couveuse royale : « {row3.Title.Text} », « {row3.Status.Text} » (2 h au lieu de 4), « {row3.RobuxSkip.Text} »`
	)
	shot("couveuse_royale")
	act(campGui, "Tab:Boutique")
	local shopPage = window:WaitForChild("PageShop")
	task.wait(0.5)
	local royalCard, xpCard, coinsCard = shopPage:WaitForChild("Pass_Royal"), shopPage:WaitForChild("Pass_Xp"), shopPage:WaitForChild("Pass_Coins")
	check(
		shopPage.Visible and royalCard.Buy.Text == "✓ À TOI" and xpCard.Buy.Text == "Bientôt" and coinsCard.Buy.Text == "Bientôt" and xpCard.Title.Text == "XP x2"
			and coinsCard.Title.Text == "Argent x2" and window.StoreButton.Text == "🛒 BOUTIQUE" and onScreen(coinsCard),
		`boutique : « {royalCard.Title.Text} » « {royalCard.Buy.Text} », « {xpCard.Title.Text} » « {xpCard.Buy.Text} », « {coinsCard.Title.Text} » « {coinsCard.Buy.Text} »`
	)
	test:InvokeServer("Shop", "Pass", "Xp", 778)
	local xpBuyable = waitFor(function()
		return xpCard.Buy.Text == "99 R$"
	end, 4)
	test:InvokeServer("Shop", "Owned", "Coins", true)
	local coinsOwned = waitFor(function()
		return coinsCard.Buy.Text == "✓ À TOI"
	end, 4)
	check(xpBuyable and coinsOwned, `boutique : un pass créé sur le Hub Création « {xpCard.Buy.Text} », un pass à lui « {coinsCard.Buy.Text} »`)
	shot("boutique")
	test:InvokeServer("Shop", "Owned", "Coins", false)
	test:InvokeServer("Shop", "Pass", "Xp", 0)
	act(campGui, "Close")

	------------------------------------------------------------------
	-- 5) Gagner un niveau : l'écran de fin dit l'œuf gagné
	------------------------------------------------------------------
	test:InvokeServer("Set", "best", 9)
	test:InvokeServer("Win", 10)
	local endScreen = hudGui:WaitForChild("EndScreen")
	waitFor(function()
		return endScreen.Visible
	end, 8)
	task.wait(0.6)
	check(
		endScreen.Visible and string.find(endScreen.Panel.Details.Text, "🥚 Œuf doré gagné ! Pose-le dans une couveuse.", 1, true) ~= nil
			and string.find(endScreen.Panel.Details.Text, "🌟 Œuf spécial gagné : Œuf carmin (tour : Arc carmin)", 1, true) ~= nil,
		`écran de fin du niveau 10 : « {string.gsub(endScreen.Panel.Details.Text, "\n", " ⏎ ")} »`
	)
	shot("fin_de_niveau")
	test:InvokeServer("Quit")
	waitFor(function()
		return player:GetAttribute("LevelArena") == nil
	end, 5)
	task.wait(0.8)

	-- « BLOQUÉ ? » (Levels.STUCK_LOSSES) : le niveau 11 perdu une fois, rien de plus ; perdu une 2e fois de suite :
	-- l'écran de fin dit comment devenir plus fort (ici : ses œufs qui attendent) et propose de rejouer le niveau 10.
	local function currentLevel()
		local index = player:GetAttribute("LevelArena")
		local arenas = workspace:FindFirstChild("Arenas")
		local arena = if typeof(index) == "number" and arenas then arenas:FindFirstChild("Arena" .. Levels.slotOf(index)) else nil
		return if arena then arena:GetAttribute("Level") else nil, if arena then arena:GetAttribute("State") else nil
	end
	local function loseOnce(levelNumber)
		test:InvokeServer("Lose", levelNumber)
		waitFor(function()
			return endScreen.Visible and endScreen.Panel.Title.Text == "DÉFAITE"
		end, 8)
		task.wait(0.6)
		return endScreen.Panel.Details.Text, endScreen.Panel.Replay.Visible
	end
	local firstLoss, firstReplay = loseOnce(11)
	test:InvokeServer("Quit")
	waitFor(function()
		return player:GetAttribute("LevelArena") == nil
	end, 5)
	task.wait(0.8)
	local stuckDetails = loseOnce(11)
	local endPanel = endScreen.Panel
	check(
		string.find(firstLoss, "Bloqué", 1, true) == nil and not firstReplay
			and string.find(stuckDetails, "🔁 Bloqué ? Rejoue un niveau déjà réussi : chaque victoire donne un œuf et des pièces.", 1, true) ~= nil
			and string.find(stuckDetails, "🥚 Des œufs t'attendent : ouvre-les dans l'onglet Œufs pour avoir de nouvelles tours.", 1, true) ~= nil
			and string.find(stuckDetails, "Les œufs et le camp d'entraînement aident aussi.", 1, true) == nil
			and endPanel.Replay.Visible and endPanel.Replay.Text == "◀ Rejouer le niveau 10" and endPanel.Next.Text == "Réessayer" and endPanel.Details.TextFits,
		`« Bloqué ? » : 1re défaite au niveau 11 sans conseil ; 2e de suite : « {string.gsub(stuckDetails, "\n", " ⏎ ")} », bouton « {endPanel.Replay.Text} »`
	)
	shot("bloque")
	act(hudGui, "Replay")
	local replayed = waitFor(function()
		local levelNumber, levelState = currentLevel()
		return levelNumber == 10 and levelState == "Running" and not endScreen.Visible
	end, 8)
	check(replayed, `« ◀ Rejouer le niveau 10 » relance le niveau 10 (niveau en cours : {tostring((currentLevel()))})`)
	test:InvokeServer("Quit")
	waitFor(function()
		return player:GetAttribute("LevelArena") == nil
	end, 5)
	task.wait(0.8)

	-- LA BARRE DE TOURS dans « Mes tours » (une tour par rareté) : le bouton « CHOISIR » d'une tour de la réserve la
	-- met à la place de celle de sa rareté ; dans un niveau, la barre ne montre que ces tours-là.
	do
		test:InvokeServer("Set", "towers", { MachineGun = true, Frost = true, Bomb = true, DragonBallista = true })
		test:InvokeServer("Set", "bar", { "MachineGun", "Frost", "Bomb", "DragonBallista" })
		act(campGui, "Tab:Mes tours")
		task.wait(1)
		local list = window.Page3.Towers
		local archerRow, frostRow = list.Tower_MachineGun, list.Tower_Frost
		local function texts(row): string
			local found = {}
			for _, child in row:GetDescendants() do
				if child:IsA("TextLabel") then
					table.insert(found, child.Text)
				end
			end
			return table.concat(found, " | ")
		end
		local function y(instance): number
			return instance.AbsolutePosition.Y
		end
		check(
			list.Rarity_Common.Text == "Commune" and list.Rarity_Rare.Text == "Rare" and list.Rarity_Epic.Text == "Épique"
				and list.Rarity_Legendary.Text == "Légendaire • aucune tour : cherche dans les œufs"
				and list.Rarity_Special.Text == "Spéciale • aucune tour : bats le boss d'un territoire"
				and y(list.Rarity_Common) < y(archerRow) and y(archerRow) < y(frostRow) and y(frostRow) < y(list.Locked_FireArcher)
				and y(list.Locked_FireArcher) < y(list.Rarity_Rare) and y(list.Rarity_Rare) < y(list.Tower_Bomb) and y(list.Tower_Bomb) < y(list.Rarity_Epic),
			`« Mes tours », rareté par rareté : « {list.Rarity_Common.Text} » (sa tour de la barre, sa réserve, puis celles pas encore à lui), « {list.Rarity_Legendary.Text} », « {list.Rarity_Special.Text} »`
		)
		check(
			archerRow.Choose.Text == "✓ CHOISIE" and string.find(texts(archerRow), "1. Archer du rempart", 1, true) ~= nil and frostRow.Choose.Text == "CHOISIR"
				and string.find(texts(frostRow), "Réserve • Totem de givre", 1, true) ~= nil and list.Tower_Bomb.Choose.Text == "✓ CHOISIE"
				and string.find(texts(list.Tower_Bomb), "2. Catapulte", 1, true) ~= nil and string.find(texts(list.Tower_DragonBallista), "3. Baliste du dragon", 1, true) ~= nil
				and archerRow.Choose.TextFits and frostRow.Choose.TextFits,
			`la barre : « {texts(archerRow)} » [{archerRow.Choose.Text}] ; en réserve : « {texts(frostRow)} » [{frostRow.Choose.Text}]`
		)
		shot("mes_tours_barre")
		act(campGui, "Choose:Frost")
		local swapped = waitFor(function()
			return frostRow.Choose.Text == "✓ CHOISIE"
		end, 4)
		task.wait(0.5)
		check(
			swapped and archerRow.Choose.Text == "CHOISIR" and string.find(texts(frostRow), "1. Totem de givre", 1, true) ~= nil
				and string.find(texts(archerRow), "Réserve • Archer du rempart", 1, true) ~= nil and y(frostRow) < y(archerRow),
			`« CHOISIR » le Totem : il prend la place de l'Archer dans la barre (« {texts(frostRow)} » [{frostRow.Choose.Text}], l'Archer : [{archerRow.Choose.Text}])`
		)
		shot("mes_tours_barre_choisie")
		-- Une tour sort d'un œuf alors que sa rareté est déjà prise dans la barre (l'Archimage, rare comme la Catapulte) :
		-- elle attend en réserve, et le panneau dit où la choisir. (Ses œufs et ses couveuses sont remis ensuite.)
		local before = test:InvokeServer("State") or {}
		test:InvokeServer("Set", "eggs", { Common = 1 })
		test:InvokeServer("Set", "hatchers", { { egg = "", readyAt = 0 } })
		act(campGui, "Tab:Œufs")
		task.wait(0.8)
		act(campGui, "EggStart:1:Common")
		waitFor(function()
			return row1.Title.Text == "COUVEUSE 1 : Œuf commun"
		end, 4)
		test:InvokeServer("Clock", Levels.EGGS.Common.seconds + 1)
		test:InvokeServer("Force", "StormArchmage")
		waitFor(function()
			return row1.Action.Text == "OUVRIR !"
		end, 5)
		act(campGui, "EggOpen:1")
		local reserveRevealed = waitFor(function()
			return revealGui.Enabled
		end, 5)
		task.wait(0.6)
		check(
			reserveRevealed and panel.Title.Text == "🎉 NOUVELLE TOUR !" and panel.TowerName.Text == "Archimage des tempêtes"
				and string.find(panel.Detail.Text, "Palier 2 de : Mage des tempêtes", 1, true) ~= nil
				and string.find(panel.Detail.Text, "Rare : choisis-la dans « Mes tours » pour la prendre", 1, true) ~= nil and panel.Detail.TextFits,
			`une tour dont la rareté est déjà prise dans la barre : « {string.gsub(panel.Detail.Text, "\n", " ⏎ ")} »`
		)
		shot("nouvelle_tour_reserve")
		act(campGui, "RevealClose")
		test:InvokeServer("Set", "eggs", before.eggs or {})
		test:InvokeServer("Set", "hatchers", before.hatchers or { { egg = "", readyAt = 0 } })
		task.wait(0.5)
		-- Dans un niveau : le Totem, la Catapulte et la Baliste du dragon dans la barre ; l'Archer, en réserve, ne se pose pas.
		test:InvokeServer("Play", 2)
		local inBarLevel = waitFor(function()
			return player:GetAttribute("LevelArena") ~= nil
		end, 8)
		task.wait(1.5)
		local hudBar = hudGui:FindFirstChild("TowerBar")
		local barSpots = Levels.geometry(Levels.definition(2).map).map.spots
		local archerPlaced = test:InvokeServer("Place", "MachineGun", barSpots[1].X, barSpots[1].Z)
		local frostPlaced = test:InvokeServer("Place", "Frost", barSpots[1].X, barSpots[1].Z)
		check(
			inBarLevel and hudBar ~= nil and hudBar.Tower_Frost.Visible and hudBar.Tower_Bomb.Visible and hudBar.Tower_DragonBallista.Visible
				and not hudBar.Tower_MachineGun.Visible and not hudBar.Tower_StormArchmage.Visible and not archerPlaced and frostPlaced == true,
			`dans un niveau : la barre montre le Totem, la Catapulte et la Baliste du dragon, pas l'Archer (en réserve : il ne se pose pas, {tostring(archerPlaced)})`
		)
		shot("barre_niveau")
		test:InvokeServer("Quit")
		waitFor(function()
			return player:GetAttribute("LevelArena") == nil
		end, 5)
		task.wait(0.8)
	end

	-- Les 8 tours de palier 2 dans un niveau : leurs silhouettes à leurs couleurs avec leur parure, leurs tirs. La barre
	-- n'en montre qu'UNE PAR RARETÉ (« LA BARRE DE TOURS », Levels.luau) : pour les poser toutes, le test lève la règle
	-- (debug « FreeBar », Studio seulement).
	local everything, order = {}, table.clone(IdleTowers.TIER2)
	for _, towerType in IdleTowers.ORDER do
		everything[towerType] = true
	end
	for _, towerType in IdleTowers.TIER1 do
		table.insert(order, towerType)
	end
	test:InvokeServer("Set", "towers", everything)
	test:InvokeServer("Set", "bar", order)
	test:InvokeServer("FreeBar", true)
	local expectedBar = Levels.barList(test:InvokeServer("State"))
	test:InvokeServer("Play", 10)
	local inLevel = waitFor(function()
		return player:GetAttribute("LevelArena") ~= nil
	end, 8)
	task.wait(1)
	local spots = Levels.geometry(Levels.definition(10).map).map.spots
	local placed, spotIndex = 0, 1
	for _, towerType in IdleTowers.TIER2 do
		while spotIndex <= #spots do
			local spot = spots[spotIndex]
			spotIndex += 1
			if test:InvokeServer("Place", towerType, spot.X, spot.Z) then
				placed += 1
				break
			end
		end
	end
	task.wait(1.5)
	local towerBar = hudGui:FindFirstChild("TowerBar")
	local barOk = towerBar ~= nil
	for _, towerType in IdleTowers.ORDER do
		local button = towerBar and towerBar:FindFirstChild("Tower_" .. towerType)
		barOk = barOk and button ~= nil and button.Visible == (table.find(expectedBar, towerType) ~= nil)
	end
	barOk = barOk and #expectedBar == Levels.BAR_MAX and expectedBar[1] == "FireArcher" and IdleTowers.isSpecial(expectedBar[5])
	local adorned = 0
	local arenas = workspace:FindFirstChild("Arenas")
	for _, model in (if arenas then arenas:GetDescendants() else {}) do
		if model:IsA("Model") and IdleTowers.tierOf(tostring(model:GetAttribute("TowerType"))) == 2 and model:FindFirstChild("TierRing") then
			adorned += 1
		end
	end
	check(
		inLevel and placed == 8 and barOk and adorned == 8,
		`niveau 10 avec les 8 tours de palier 2 : {placed} posées, {adorned} avec leur parure ; la barre : une tour par rareté ({table.concat(expectedBar, ", ")} : {barOk})`
	)
	task.wait(6) -- (les monstres arrivent, les tours tirent)
	shot("palier2_niveau")
	act(hudGui, "Zoom:2.5")
	task.wait(1.5)
	shot("palier2_pres")
	act(hudGui, "Zoom:1")
	test:InvokeServer("Quit")
	waitFor(function()
		return player:GetAttribute("LevelArena") == nil
	end, 5)
	task.wait(0.8)

	-- Les tours spéciales dans un niveau (toutes, même celle du désert, encore fermé : posées ici pour le test, règle
	-- de la barre levée) : leur parure (anneau d'or et joyaux), leurs tirs (flèches carmin, carreaux de cuivre, ronces
	-- au sol, blocs de glace, tempête de sable). Dans la barre : une seule tour spéciale, la première de sa liste.
	local specialOrder = table.clone(IdleTowers.SPECIAL)
	for _, towerType in IdleTowers.TIER1 do
		table.insert(specialOrder, towerType)
	end
	test:InvokeServer("Set", "bar", specialOrder)
	local specialExpected = Levels.barList(test:InvokeServer("State"))
	test:InvokeServer("Play", 10)
	local inSpecialLevel = waitFor(function()
		return player:GetAttribute("LevelArena") ~= nil
	end, 8)
	task.wait(1)
	local specialPlaced, specialSpot = 0, 3
	for _, towerType in IdleTowers.SPECIAL do
		while specialSpot <= #spots do
			local spot = spots[specialSpot]
			specialSpot += 1
			if test:InvokeServer("Place", towerType, spot.X, spot.Z) then
				specialPlaced += 1
				break
			end
		end
	end
	task.wait(1.5)
	local specialBar = towerBar ~= nil and specialExpected[#specialExpected] == IdleTowers.SPECIAL[1]
	for _, towerType in IdleTowers.SPECIAL do
		local button = towerBar and towerBar:FindFirstChild("Tower_" .. towerType)
		specialBar = specialBar and button ~= nil and button.Visible == (towerType == IdleTowers.SPECIAL[1])
	end
	local specialAdorned = 0
	for _, model in (if arenas then arenas:GetDescendants() else {}) do
		if model:IsA("Model") and IdleTowers.isSpecial(tostring(model:GetAttribute("TowerType"))) and model:FindFirstChild("SpecialRing") and model:FindFirstChild("SpecialGem") then
			specialAdorned += 1
		end
	end
	check(
		inSpecialLevel and specialPlaced == #IdleTowers.SPECIAL and specialBar and specialAdorned == #IdleTowers.SPECIAL,
		`niveau 10 avec les {#IdleTowers.SPECIAL} tours spéciales : {specialPlaced} posées, {specialAdorned} avec leur parure ; dans la barre, une seule ({table.concat(specialExpected, ", ")} : {specialBar})`
	)
	-- (le niveau avance de 40 s d'un coup : les monstres sont sur tout le chemin, les tours tirent : ronces au sol,
	-- blocs de glace, carreaux, flèches carmin)
	test:InvokeServer("Skip", 40)
	task.wait(4)
	shot("speciales_niveau")
	act(hudGui, "Zoom:1.7")
	task.wait(1.5)
	shot("speciales_pres")
	act(hudGui, "Zoom:1")
	test:InvokeServer("Quit")
	test:InvokeServer("FreeBar", false)
	waitFor(function()
		return player:GetAttribute("LevelArena") == nil
	end, 5)
	task.wait(0.8)
	-- (gros plans pour le propriétaire, sur la parcelle : le Totem des sables, la tour du désert encore fermé, au 1er
	-- emplacement du camp, et un œuf des dunes dans la 1re couveuse ; puis tout redevient comme avant)
	do
		local PlotLayout = require(Shared.PlotLayout)
		local saved = test:InvokeServer("State") or {}
		local owned = table.clone(saved.towers or {})
		owned.SandTotem = true
		test:InvokeServer("Set", "towers", owned)
		test:InvokeServer("Set", "slots", { { tower = "SandTotem", level = 3 } })
		-- (prêt dans un jour : l'horloge du serveur a été avancée plus haut, un œuf prêt brille et cache son dessin)
		test:InvokeServer("Set", "hatchers", { { egg = "Dune", readyAt = os.time() + 86400 } })
		act(campGui, "Close")
		task.wait(2)
		local plotIndex = player:GetAttribute("Plot")
		if typeof(plotIndex) == "number" then
			local camera = workspace.CurrentCamera
			local before = camera.CFrame
			local function look(from: Vector3, at: Vector3)
				camera.CameraType = Enum.CameraType.Scriptable
				camera.CFrame = CFrame.lookAt(PlotLayout.toWorld(plotIndex, from), PlotLayout.toWorld(plotIndex, at))
				camera.Focus = CFrame.new(PlotLayout.toWorld(plotIndex, at))
			end
			local spot = PlotLayout.SPOTS[1]
			look(spot + Vector3.new(4, 6.5, -10), spot + Vector3.new(0, 3.6, 0))
			task.wait(2.5)
			look(spot + Vector3.new(4, 6.5, -10), spot + Vector3.new(0, 3.6, 0))
			shot("totem_des_sables")
			local hatcher = PlotLayout.HATCHERS[1]
			look(hatcher + Vector3.new(2.5, 5, -7.5), hatcher + Vector3.new(0, 3.3, 0))
			task.wait(1.5)
			shot("oeuf_des_dunes")
			camera.CameraType = Enum.CameraType.Custom
			camera.CFrame = before
		end
		-- (et son dessin de l'onglet Œufs, en grand : sa carte n'apparaît qu'à l'ouverture du désert)
		local client = player:FindFirstChild("PlayerScripts") and player.PlayerScripts:FindFirstChild("Client")
		local eggArtModule = client and client:FindFirstChild("EggArt")
		local okArt, EggArt = false, nil
		if eggArtModule then
			okArt, EggArt = pcall(require, eggArtModule)
		end
		if okArt and EggArt then
			local preview = Instance.new("ScreenGui")
			preview.Name = "DuneEggPreview"
			preview.DisplayOrder = 60
			preview.ResetOnSpawn = false
			preview:SetAttribute("NoTranslate", true)
			preview.Parent = playerGui
			for index, eggType in { "Rime", "Dune" } do
				EggArt.tile(eggType, { Size = UDim2.fromOffset(240, 240), Position = UDim2.new(0.5, (index - 2) * 260 + 10, 0.5, -120), Parent = preview })
			end
			task.wait(1)
			shot("oeuf_des_dunes_dessin")
			preview:Destroy()
		end
		for _, key in { "towers", "slots", "hatchers" } do
			if saved[key] then
				test:InvokeServer("Set", key, saved[key])
			end
		end
		task.wait(0.5)
	end

	------------------------------------------------------------------
	-- 6) À la taille d'un téléphone (750 x 332)
	------------------------------------------------------------------
	local function fitTo(width, height)
		local stableSince, deadline = nil, os.clock() + 90
		while os.clock() < deadline do
			local size = screenSize()
			if math.abs(size.X - width) <= 6 and math.abs(size.Y - height) <= 6 then
				stableSince = stableSince or os.clock()
				if os.clock() - stableSince >= 4 then
					return true
				end
				task.wait(0.25)
			else
				stableSince = nil
				say(`PHONE:want={width}x{height};have={math.floor(size.X)}x{math.floor(size.Y)}`)
				task.wait(0.9)
			end
		end
		return false
	end
	local phone = fitTo(750, 332)
	check(phone, `fenêtre de Studio à la taille d'un téléphone ({math.floor(screenSize().X)} x {math.floor(screenSize().Y)})`)
	if phone then
		act(campGui, "Tab:Œufs")
		task.wait(0.8)
		check(
			onScreen(window) and inside(common, page) and inside(gold, page) and onScreen(tab) and common.Count.TextBounds.Y > 0,
			`téléphone : l'onglet Œufs tient dans la fenêtre (cartes des œufs de {math.floor(common.AbsoluteSize.X)} x {math.floor(common.AbsoluteSize.Y)} px)`
		)
		shot("tel_onglet")
		act(campGui, "Close")
	end
	finish()
end

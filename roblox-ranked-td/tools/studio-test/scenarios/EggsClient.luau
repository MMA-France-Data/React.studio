-- Test des ŒUFS, côté client (la vraie interface) : tools/studio-test/run.ps1 -Test eggs.
-- Il attend que le serveur (scenarios/EggsServer.luau) ait fini ses vérifications, puis :
--   1) l'onglet « Œufs » : les trois œufs (nom, nombre, temps, chances), les couveuses (vide : « Poser »), l'aide ;
--   2) poser un œuf commun : la couveuse dit son œuf et le temps qui reste, « Finir : 75 🏅 » ;
--   3) l'heure du serveur avance : « Prêt : ouvre-le ! », « OUVRIR ! » ; ouvert (Baliste du dragon, palier 2, nouvelle) :
--      le panneau de la tour sortie (sa tour de base, ce qu'elle fait) ; un doublon : « DOUBLON » et son XP ;
--   4) acheter la 2e couveuse : « COUVEUSE 2 (vide) », la 3e à acheter ; la pastille « ! » de l'onglet ;
--   5) gagner un niveau : l'écran de fin dit l'œuf gagné ; puis les 8 tours de palier 2 posées dans un niveau (la barre
--      de 8 tours, les autres en réserve ; leur parure ; captures palier2_niveau et palier2_pres) ;
--   6) à la taille d'un téléphone (750 x 332) : l'onglet Œufs tient dans la fenêtre.
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
	local page = window:WaitForChild("Page5")
	task.wait(0.4)
	local tab = window:FindFirstChild("Tab5")
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
			and not row1.Put_Rare.Visible and row1.Put_Common.Text == "Poser : Œuf commun" and row2.Visible and row2.Title.Text == "🔒 COUVEUSE 2"
			and row2.Action.Text == `Acheter : {Levels.HATCHER_COST[2]} 🏅` and not row3.Visible,
		`couveuses : « {row1.Title.Text} » (poser un œuf commun ou doré), « {row2.Title.Text} » « {row2.Action.Text} », la 3e cachée`
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
		placed and string.match(row1.Status.Text, "^Encore 1[45]:%d%d$") ~= nil and row1.Action.Visible and row1.Action.Text == `Finir : {Levels.skipCost(Levels.EGGS.Common.seconds)} 🏅`
			and not row1.Put_Common.Visible and common.Count.Text == "×1",
		`œuf commun posé : « {row1.Title.Text} », « {row1.Status.Text} », « {row1.Action.Text} »`
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
		bought and row3.Title.Text == "🔒 COUVEUSE 3" and string.find(row3.Action.Text, "Acheter : ", 1, true) == 1 and string.find(row3.Action.Text, "🏅", 1, true) ~= nil,
		`2e couveuse achetée : « {row2.Title.Text} », puis « {row3.Title.Text} » « {row3.Action.Text} »`
	)
	act(campGui, "Tab:Boutique")
	local badge = tab and tab:FindFirstChild("Badge")
	check(badge ~= nil and badge.Visible, "dans un autre onglet : la pastille « ! » de l'onglet Œufs dit qu'un œuf attend (couveuse vide, œuf en réserve)")
	-- « Mes tours » : la tour de palier 2 sortie de l'œuf (sa vignette 3D, ce qu'elle fait) ; celles qu'il n'a pas encore
	-- attendent « dans les œufs », avec un bouton vers l'onglet Œufs.
	act(campGui, "Tab:Mes tours")
	task.wait(1)
	local towerList = window.Page4.Towers
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
			and lockedFire ~= nil and lockedFire.Visible and lockedFire.Price.Text == "Palier 2 de : Archer du rempart • dans les œufs" and lockedFire.Shop.Text == "ŒUFS",
		`« Mes tours » : « {dragonText} » ; pas encore à lui : « {lockedFire and lockedFire.Price.Text or "?"} » « {lockedFire and lockedFire.Shop.Text or "?"} »`
	)
	shot("mes_tours_palier2")
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
		endScreen.Visible and string.find(endScreen.Panel.Details.Text, "🥚 Œuf doré gagné ! Pose-le dans une couveuse.", 1, true) ~= nil,
		`écran de fin du niveau 10 : « {string.gsub(endScreen.Panel.Details.Text, "\n", " ⏎ ")} »`
	)
	shot("fin_de_niveau")
	test:InvokeServer("Quit")
	waitFor(function()
		return player:GetAttribute("LevelArena") == nil
	end, 5)
	task.wait(0.8)

	-- Les 8 tours de palier 2 dans un niveau : seulement elles dans la barre (les 8 tours de la boutique, après elles,
	-- sont en réserve), leurs silhouettes à leurs couleurs avec leur parure, leurs tirs.
	local everything, order = {}, table.clone(IdleTowers.TIER2)
	for _, towerType in IdleTowers.ORDER do
		everything[towerType] = true
	end
	for _, towerType in IdleTowers.TIER1 do
		table.insert(order, towerType)
	end
	test:InvokeServer("Set", "towers", everything)
	test:InvokeServer("Set", "bar", order)
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
		barOk = barOk and button ~= nil and button.Visible == (IdleTowers.tierOf(towerType) == 2)
	end
	local adorned = 0
	local arenas = workspace:FindFirstChild("Arenas")
	for _, model in (if arenas then arenas:GetDescendants() else {}) do
		if model:IsA("Model") and IdleTowers.tierOf(tostring(model:GetAttribute("TowerType"))) == 2 and model:FindFirstChild("TierRing") then
			adorned += 1
		end
	end
	check(
		inLevel and placed == 8 and barOk and adorned == 8,
		`niveau 10 avec les 8 tours de palier 2 : {placed} posées, {adorned} avec leur parure, barre des 8 tours de palier 2 (celles de la boutique en réserve : {barOk})`
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

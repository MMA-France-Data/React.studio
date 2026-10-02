-- Test des NIVEAUX (prototype de la nouvelle formule), côté client : tools/studio-test/phone.ps1 -Mode levels.
-- Il attend que le serveur ait fini ses propres vérifications (attribut LevelsTestPhase = "Client"), puis joue avec
-- la VRAIE interface (src/client/LevelsUI.luau) : un plugin ne peut pas cliquer, il passe donc par l'attribut
-- « TestAction » des deux écrans, qui lance les mêmes fonctions que les boutons et les appuis (un appui sur le
-- terrain passe par le vrai chemin : point de l'écran -> rayon de la caméra -> sol).
--   1) à la taille normale de Studio : fenêtre du camp et ses 4 onglets, niveau 1 (vue d'en haut, Archer offert,
--      « + » conseillés, pose libre, amélioration, refus sur le chemin, x2), victoire, « Niveau suivant », abandon ;
--   2) à la taille d'un téléphone (750 x 332) : un niveau et la fenêtre du camp, rien ne sort de l'écran.
-- « SHOT:nom » = capture (out\levels_<nom>.png) ; « PHONE:want=... » = phone.ps1 redimensionne la fenêtre de Studio.
return function(log)
	local GuiService = game:GetService("GuiService")
	local HttpService = game:GetService("HttpService")
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Levels = require(ReplicatedStorage:WaitForChild("Shared").Levels)
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local function say(message)
		log("Info", "[LEVELS] " .. message)
	end
	local function shot(name)
		say("SHOT:levels_" .. name)
		task.wait(1.6)
	end
	local function check(ok, message)
		log(if ok then "Info" else "Error", `[{if ok then "PASS" else "FAIL"}] niveaux (écran) : {message}`)
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
	local function shown(object)
		local current = object
		while current and not current:IsA("LayerCollector") do
			if current:IsA("GuiObject") and not current.Visible then
				return false
			end
			current = current.Parent
		end
		return current ~= nil and current:IsA("ScreenGui") and current.Enabled
	end
	local function rect(object)
		local position, size = object.AbsolutePosition, object.AbsoluteSize
		return position.X, position.Y, position.X + size.X, position.Y + size.Y
	end

	if not waitFor(function()
		return ReplicatedStorage:GetAttribute("LevelsTestPhase") == "Client"
	end, 150) then
		check(false, "le serveur n'a jamais donné la main au client")
		return
	end
	local campGui = playerGui:WaitForChild("Levels", 30)
	local hudGui = playerGui:WaitForChild("LevelHud", 30)
	if not campGui or not hudGui then
		check(false, "écrans des niveaux introuvables (« Levels », « LevelHud »)")
		return
	end
	local counter = 0
	local function act(gui, command)
		counter += 1
		gui:SetAttribute("TestAction", `{command}#{counter}`)
		task.wait(0.15)
	end
	local levelAction = ReplicatedStorage.Remotes.LevelAction
	local window = campGui:WaitForChild("Window")
	local openButton = campGui:WaitForChild("LevelsButton")
	local topBar = (GuiService:GetGuiInset()).Y
	-- (toujours la caméra du moment : Roblox peut la remplacer pendant le chargement)
	local function cam()
		return workspace.CurrentCamera
	end

	local function screenSize()
		local viewport = cam().ViewportSize
		return Vector2.new(viewport.X, viewport.Y - topBar)
	end
	local function onScreen(object)
		local screen = screenSize()
		local l, t, r, b = rect(object)
		return l >= -1 and t >= -topBar - 1 and r <= screen.X + 1 and b <= screen.Y + 1
	end
	local function published()
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(player:GetAttribute("LevelsState"))
		end)
		return if ok then decoded else {}
	end

	local slot = player:GetAttribute("Plot")
	local arena = workspace:WaitForChild("Arenas"):WaitForChild("Arena" .. tostring(slot))
	local arenaCFrame = Levels.arenaCFrame(slot)
	local map = Levels.MAPS.Valley
	local function towers()
		local folder = arena:FindFirstChild("Towers")
		local list = {}
		for _, model in if folder then folder:GetChildren() else {} do
			if model:IsA("Model") then
				table.insert(list, model)
			end
		end
		return list
	end
	local function towerAt(x, z)
		for _, model in towers() do
			local point = arenaCFrame:PointToObjectSpace(model:GetAttribute("RestCFrame").Position)
			if math.abs(point.X - x) < 0.6 and math.abs(point.Z - z) < 0.6 then
				return model
			end
		end
		return nil
	end
	-- Monstres affichés dans la zone (PlotRenderer) et barres de vie allumées.
	local function enemies()
		local folder = workspace:FindFirstChild("PlotEnemies")
		local count, bars = 0, 0
		for _, part in if folder then folder:GetChildren() else {} do
			if part:IsA("BasePart") and (part.Position - arenaCFrame.Position).Magnitude < 90 then
				count += 1
				local bar = part:FindFirstChildOfClass("BillboardGui")
				if bar and bar.Enabled then
					bars += 1
				end
			end
		end
		return count, bars
	end
	-- Le terrain à l'écran : ses 4 coins (dans l'image de la caméra, en px).
	local function fieldOnScreen()
		local minX, maxX, minY, maxY, visible = math.huge, -math.huge, math.huge, -math.huge, true
		for _, corner in {
			Vector3.new(-map.width / 2, 0, -map.depth / 2),
			Vector3.new(map.width / 2, 0, -map.depth / 2),
			Vector3.new(-map.width / 2, 0, map.depth / 2),
			Vector3.new(map.width / 2, 0, map.depth / 2),
		} do
			local point, seen = cam():WorldToViewportPoint(arenaCFrame:PointToWorldSpace(corner))
			visible = visible and seen
			minX, maxX = math.min(minX, point.X), math.max(maxX, point.X)
			minY, maxY = math.min(minY, point.Y), math.max(maxY, point.Y)
		end
		return visible, minX, maxX, minY, maxY
	end
	-- La carte tient entre le bandeau du haut et la barre des tours, et elle remplit bien la place.
	local function checkView(label)
		local strip, hint = hudGui.TopStrip, hudGui.Hint
		local viewport = cam().ViewportSize
		local visible, minX, maxX, minY, maxY = fieldOnScreen()
		local _, _, _, stripBottom = rect(strip)
		local _, hintTop = rect(hint)
		local freeTop, freeBottom = math.max(topBar, stripBottom + topBar), hintTop + topBar
		local fits = visible and minX >= 0 and maxX <= viewport.X and minY >= freeTop - 2 and maxY <= freeBottom + 2
		local fill = math.max((maxX - minX) / viewport.X, (maxY - minY) / math.max(1, freeBottom - freeTop))
		check(
			cam().CameraType == Enum.CameraType.Scriptable and fits and fill >= 0.75,
			`{label} : vue d'en haut, toute la carte tient entre le bandeau et la barre des tours (terrain de {math.floor(minX)},{math.floor(minY)} à {math.floor(maxX)},{math.floor(maxY)} px dans une image de {math.floor(viewport.X)} x {math.floor(viewport.Y)}, place libre de {math.floor(freeTop)} à {math.floor(freeBottom)} px, remplie à {math.floor(fill * 100)} %)`
		)
	end
	-- Écrans du jeu actuel encore allumés (ils doivent être cachés pendant un niveau).
	local function otherGuis()
		local names = {}
		for _, gui in playerGui:GetChildren() do
			if gui:IsA("ScreenGui") and gui.Enabled and gui.Name ~= "LevelHud" and gui.Name ~= "Toasts" then
				table.insert(names, gui.Name)
			end
		end
		table.sort(names)
		return names
	end
	local function hudButtons()
		local list = {}
		for _, object in hudGui:GetDescendants() do
			if object:IsA("GuiButton") and shown(object) and object.Name ~= "EndScreen" and object.AbsoluteSize.X > 2 then
				table.insert(list, object)
			end
		end
		return list
	end
	local function overlapping(objects)
		local found = {}
		for i = 1, #objects do
			for j = i + 1, #objects do
				local a, b = objects[i], objects[j]
				if not a:IsDescendantOf(b) and not b:IsDescendantOf(a) then
					local al, at, ar, ab = rect(a)
					local bl, bt, br, bb = rect(b)
					if math.min(ar, br) - math.max(al, bl) > 2 and math.min(ab, bb) - math.max(at, bt) > 2 then
						table.insert(found, `{a.Name} sur {b.Name}`)
					end
				end
			end
		end
		return found
	end

	task.spawn(function()
		pcall(function()
			game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
		end)
	end)
	task.wait(1)
	-- Studio doit vraiment afficher le jeu : écran du PC éteint (veille), l'image fait 1 x 1 pixel et plus rien n'est
	-- dessiné. Les tests de l'écran n'auraient aucun sens : on s'arrête là (awake.ps1 garde l'écran allumé).
	local viewport = cam().ViewportSize
	if viewport.X < 400 or viewport.Y < 250 then
		check(false, `Studio n'affiche pas le jeu (image de {viewport.X} x {viewport.Y} px : écran du PC éteint ?) : test de l'écran abandonné`)
		say("LEVELS:client=done")
		task.wait(1.5)
		say("PHONE:done")
		return
	end

	------------------------------------------------------------------
	-- 1) Fenêtre du camp
	------------------------------------------------------------------
	-- (elle s'ouvre toute seule au retour d'un niveau : le serveur vient d'en jouer plusieurs pour ses tests)
	act(campGui, "Close")
	check(shown(openButton) and not window.Visible and openButton.Text == "⚔ NIVEAUX" and onScreen(openButton), "bouton « ⚔ NIVEAUX » affiché sur la map principale, fenêtre fermée")
	local guisBefore = otherGuis()
	act(campGui, "Open")
	local page1 = window:FindFirstChild("Page1")
	local firstCard = page1 and page1:FindFirstChild("Level1")
	local secondCard = page1 and page1:FindFirstChild("Level2")
	check(
		window.Visible and page1 ~= nil and page1.Visible and firstCard ~= nil and firstCard.Play.Text == "▶ JOUER" and secondCard.Play.Text == "🔒"
			and string.find(window.Coins.Text, "0", 1, true) ~= nil and onScreen(window),
		`fenêtre du camp ouverte sur « Niveaux » : niveau 1 « {firstCard and firstCard.Play.Text} », niveau 2 « {secondCard and secondCard.Play.Text} », pièces « {window.Coins.Text} »`
	)
	shot("camp_niveaux")
	act(campGui, "Tab:Boutique")
	local shopPage = window.Page2
	local frostCard = shopPage:FindFirstChild("Shop_Frost")
	local archerCard = shopPage:FindFirstChild("Shop_MachineGun")
	check(
		shopPage.Visible and not page1.Visible and archerCard.Buy.Text == "✓ À TOI" and string.find(frostCard.Buy.Text, "150", 1, true) ~= nil
			and string.find(frostCard.Buy.Text, "manque", 1, true) ~= nil,
		`onglet « Boutique » : Archer « {archerCard.Buy.Text} », Totem « {frostCard.Buy.Text} » (prix fixe, aucun hasard)`
	)
	shot("camp_boutique")
	act(campGui, "Tab:Entraînement")
	local trainPage = window.Page3
	local slot1, slot2 = trainPage:FindFirstChild("Slot1"), trainPage:FindFirstChild("Slot2")
	local archerRow = trainPage.Towers:FindFirstChild("Train_MachineGun")
	check(
		trainPage.Visible and slot1 ~= nil and slot2 ~= nil and slot2.Action.Visible and string.find(slot2.Action.Text, "400", 1, true) ~= nil
			and archerRow.Visible and not trainPage.Towers.Train_Frost.Visible,
		`onglet « Entraînement » : un emplacement avec l'Archer, le 2e à ouvrir (« {slot2 and slot2.Action.Text} »), seules les tours possédées sont listées`
	)
	shot("camp_entrainement")
	act(campGui, "Tab:Mes tours")
	local towersPage = window.Page4
	check(towersPage.Visible and towersPage.Towers.Tower_MachineGun.Visible and not towersPage.Towers.Tower_Orbital.Visible, "onglet « Mes tours » : l'inventaire (l'Archer seul pour l'instant)")
	shot("camp_tours")
	act(campGui, "Close")
	check(not window.Visible, "fenêtre du camp fermée")

	------------------------------------------------------------------
	-- 2) Niveau 1 : les 10 premières secondes
	------------------------------------------------------------------
	levelAction:FireServer("Start", 1) -- (le bouton « ▶ JOUER » de la carte du niveau 1 envoie cette demande)
	local entered = waitFor(function()
		return hudGui.Enabled and arena:GetAttribute("State") == "Running" and #towers() >= 1 and cam().CameraType == Enum.CameraType.Scriptable
	end, 15)
	task.wait(0.6)
	check(
		entered and hudGui.Enabled and #otherGuis() == 0 and not campGui.Enabled,
		`niveau 1 lancé : écran du niveau affiché, écrans de la parcelle cachés ({#guisBefore} avant, {#otherGuis()} pendant : {table.concat(otherGuis(), ", ")})`
	)
	checkView("niveau 1")
	local starter = towers()[1]
	check(
		#towers() == 1 and starter:GetAttribute("TowerType") == "MachineGun" and towerAt(map.spots[1].X, map.spots[1].Z) == starter,
		"un Archer est déjà posé à l'arrivée, au premier emplacement conseillé"
	)
	check(
		hudGui:GetAttribute("Placing") == "MachineGun" and string.find(hudGui.Hint.Text, "+", 1, true) ~= nil,
		`premier niveau : l'Archer est déjà choisi dans la barre et le conseil montre les « + » (« {hudGui.Hint.Text} »)`
	)
	local helpers = workspace:FindFirstChild("LevelHelpers")
	local plus = 0
	for _, child in if helpers then helpers:GetChildren() else {} do
		if string.sub(child.Name, 1, 4) == "Plus" then
			plus += 1
		end
	end
	check(plus >= 4, `{plus} « + » affichés aux emplacements conseillés encore libres`)
	local strip = hudGui.TopStrip
	check(
		strip.Level.Text == "NIVEAU 1" and string.find(strip.Gold.Text, "25", 1, true) ~= nil and string.find(strip.Lives.Text, "10", 1, true) ~= nil
			and string.find(strip.Progress.ProgressText.Text, tostring(arena:GetAttribute("Total")), 1, true) ~= nil,
		`bandeau : « {strip.Level.Text} », « {strip.Lives.Text} », « {strip.Gold.Text} », « {strip.Progress.ProgressText.Text} »`
	)
	local bar = hudGui.TowerBar
	check(shown(bar.Tower_MachineGun) and not bar.Tower_Frost.Visible and bar.Tower_MachineGun.Cost.Text == "20 💰", `barre rapide : seulement l'Archer (« {bar.Tower_MachineGun.Cost.Text} »)`)
	-- L'Archer offert tire tout de suite : un monstre tué en moins de 10 secondes.
	local startedAt = os.clock()
	local firstKill = waitFor(function()
		return (arena:GetAttribute("Gold") or 0) > 25
	end, 12)
	check(firstKill and os.clock() - startedAt <= 10, string.format("premier monstre tué %.1f s après l'arrivée dans le niveau (l'Archer offert tire seul)", os.clock() - startedAt))
	waitFor(function()
		local count, withBar = enemies()
		return count >= 1 and withBar >= 1
	end, 8)
	local seen, bars = enemies()
	check(seen >= 1 and bars >= 1, `{seen} monstres affichés sur le chemin de la zone, {bars} barres de vie visibles (personnage resté sur la place)`)
	-- Le combat s'entend : un son de flèche (3D) a été joué dans la zone. La caméra est à ~100 studs, plus loin que la
	-- portée de ce son (70) : LevelsUI place l'écoute près du terrain (SoundManager.setListener).
	local function arenaSound(name)
		for _, child in workspace.Terrain:GetChildren() do
			if child:IsA("Attachment") and child.Name == "Son_" .. name and (child.WorldPosition - arenaCFrame.Position).Magnitude < 90 then
				return true
			end
		end
		return false
	end
	check(
		waitFor(function()
			return arenaSound("ArcherShot")
		end, 8),
		`on entend le combat pendant un niveau : le son des flèches joue dans la zone (caméra à {math.floor((cam().CFrame.Position - arenaCFrame.Position).Magnitude)} studs du centre)`
	)
	-- L'or gagné se voit sur le terrain : un « +2 » doré au-dessus d'un monstre tué.
	check(
		waitFor(function()
			local helpersNow = workspace:FindFirstChild("LevelHelpers")
			return helpersNow ~= nil and helpersNow:FindFirstChild("GoldPopup") ~= nil
		end, 8),
		"un « +2 » doré s'envole au-dessus du monstre tué (or gagné)"
	)
	shot("depart")

	------------------------------------------------------------------
	-- 3) Poser, améliorer, refus
	------------------------------------------------------------------
	local goldBefore = arena:GetAttribute("Gold")
	-- Un appui tout près d'un « + » (à 1,2 stud) pose exactement dessus.
	act(hudGui, `Tap:{map.spots[2].X + 1.2},{map.spots[2].Z}`)
	local placed = waitFor(function()
		return towerAt(map.spots[2].X, map.spots[2].Z) ~= nil
	end, 4)
	check(
		placed and #towers() == 2 and arena:GetAttribute("Gold") >= goldBefore - 20 and arena:GetAttribute("Gold") < goldBefore + 20
			and hudGui:GetAttribute("Placing") == "",
		`un appui près d'un « + » pose un 2e Archer exactement dessus ({#towers()} tours, {tostring(arena:GetAttribute("Gold"))} or), la pose se termine`
	)
	-- Toucher une tour : son petit menu, à côté d'elle.
	local second = towerAt(map.spots[2].X, map.spots[2].Z)
	act(hudGui, `Tap:{map.spots[2].X},{map.spots[2].Z}`)
	local menu = hudGui.TowerMenu
	check(
		second ~= nil and hudGui:GetAttribute("Selected") == second:GetAttribute("TowerId") and waitFor(function()
			return menu.Visible
		end, 2) and onScreen(menu) and string.find(menu.Upgrade.Text, "15", 1, true) ~= nil,
		`toucher la tour ouvre son menu (« {menu.Title.Text} », « {menu.Upgrade.Text} », « {menu.Sell.Text} »)`
	)
	if not second then
		check(false, "2e tour introuvable : suite du test impossible")
		say("LEVELS:client=done")
		task.wait(1.5)
		say("PHONE:done")
		return
	end
	waitFor(function()
		return (arena:GetAttribute("Gold") or 0) >= 15
	end, 20)
	act(hudGui, "Upgrade")
	local upgraded = waitFor(function()
		return second:GetAttribute("Level") == 2
	end, 4)
	task.wait(0.5)
	local tag = second:FindFirstChild("LevelTag")
	local tagLabel = tag and tag:FindFirstChildOfClass("TextLabel")
	check(upgraded and tag ~= nil and tag.Enabled and tagLabel ~= nil and tagLabel.Text == "Niv. 2", `« Améliorer » : la tour passe au niveau 2, son étiquette « {if tagLabel then tagLabel.Text else "?"} » est visible d'en haut`)
	shot("menu_tour")
	-- Pose libre ailleurs qu'un « + », quand l'or est là.
	waitFor(function()
		return (arena:GetAttribute("Gold") or 0) >= 20
	end, 30)
	act(hudGui, "Select:MachineGun")
	check(hudGui:GetAttribute("Placing") == "MachineGun" and hudGui:GetAttribute("Selected") == 0 and not menu.Visible, "choisir une tour dans la barre : mode pose, le menu se ferme")
	act(hudGui, "Tap:-23,6")
	check(
		waitFor(function()
			return towerAt(-23, 6) ~= nil
		end, 4) and #towers() == 3,
		"pose libre : un 3e Archer là où on a touché l'herbe (pas sur un emplacement conseillé)"
	)
	-- Zoom (molette ou pincement) et déplacement de la vue : la carte déborde de l'écran, un appui vise toujours juste.
	local _, wideMinX, wideMaxX = fieldOnScreen()
	act(hudGui, "Zoom:2")
	task.wait(0.3)
	local _, zoomMinX, zoomMaxX = fieldOnScreen()
	check(
		hudGui:GetAttribute("Zoom") == 2 and (zoomMaxX - zoomMinX) > (wideMaxX - wideMinX) * 1.8,
		`zoom x2 : la carte fait {math.floor(zoomMaxX - zoomMinX)} px de large à l'écran au lieu de {math.floor(wideMaxX - wideMinX)}`
	)
	act(hudGui, "Pan:400,0")
	task.wait(0.3)
	local _, panMinX = fieldOnScreen()
	check(panMinX > zoomMinX + 200, `glisser de 400 px vers la droite : la carte suit le doigt (bord gauche de {math.floor(zoomMinX)} à {math.floor(panMinX)} px)`)
	act(hudGui, "Pan:99999,0")
	task.wait(0.3)
	local _, edgeMinX = fieldOnScreen()
	check(edgeMinX < cam().ViewportSize.X * 0.5, `la vue ne sort jamais de la carte (glissement énorme : bord gauche à {math.floor(edgeMinX)} px, pas plus loin que le milieu de l'écran)`)
	waitFor(function()
		return (arena:GetAttribute("Gold") or 0) >= 20
	end, 30)
	act(hudGui, "Select:MachineGun")
	act(hudGui, "Tap:-45,-3")
	check(
		waitFor(function()
			return towerAt(-45, -3) ~= nil
		end, 4),
		"vue zoomée et déplacée : un appui pose bien la tour à l'endroit touché (emplacement conseillé près de l'entrée)"
	)
	act(hudGui, "Zoom:1")
	task.wait(0.3)
	local _, backMinX, backMaxX = fieldOnScreen()
	check(math.abs(backMinX - wideMinX) < 3 and math.abs(backMaxX - wideMaxX) < 3, "zoom remis à 1 : toute la carte, comme au départ")
	-- Trois inclinaisons de la caméra à comparer (question du propriétaire : « pourquoi la vue n'est pas vraiment
	-- au-dessus ? ») : la même scène vue comme d'habitude, plus plongeante, et pile au-dessus.
	local usual = hudGui:GetAttribute("Pitch")
	for _, degrees in { 70, 90 } do
		act(hudGui, `Pitch:{degrees}`)
		task.wait(0.4)
		local seenAll, pitchMinX, pitchMaxX = fieldOnScreen()
		check(
			hudGui:GetAttribute("Pitch") == degrees and seenAll and pitchMinX >= 0 and pitchMaxX <= cam().ViewportSize.X,
			`caméra à {degrees}° : toute la carte reste à l'écran ({math.floor(pitchMaxX - pitchMinX)} px de large ; {tostring(usual)}° d'habitude : {math.floor(wideMaxX - wideMinX)} px)`
		)
		shot("vue_" .. degrees)
	end
	act(hudGui, "Pitch:")
	task.wait(0.4)
	check(hudGui:GetAttribute("Pitch") == usual, `inclinaison normale remise ({tostring(usual)}°)`)
	shot("vue_normale")
	-- Sur le chemin : refusé, rien n'est posé.
	waitFor(function()
		return (arena:GetAttribute("Gold") or 0) >= 20
	end, 30)
	act(hudGui, "Select:MachineGun")
	act(hudGui, "Tap:-34,0")
	task.wait(0.8)
	local toasts = playerGui:FindFirstChild("Toasts")
	local refusal = false
	for _, label in if toasts then toasts:GetDescendants() else {} do
		if label:IsA("TextLabel") and string.find(label.Text, "chemin", 1, true) then
			refusal = true
		end
	end
	check(#towers() == 4 and refusal and hudGui:GetAttribute("Placing") == "MachineGun", "toucher le chemin : refusé avec un message (« Trop près du chemin »), la tour reste à poser")
	act(hudGui, "Select:")
	shot("combat")

	------------------------------------------------------------------
	-- 4) x2, victoire, écran de fin
	------------------------------------------------------------------
	act(hudGui, "Speed")
	check(waitFor(function()
		return arena:GetAttribute("SimSpeed") == 2 and strip.Speed.Text == "x2"
	end, 3), "bouton x2 : tout va deux fois plus vite")
	-- Pendant la vague : dépenser l'or qui arrive (améliorer les tours), comme un joueur.
	local wonLevel = waitFor(function()
		local gold = arena:GetAttribute("Gold") or 0
		for _, model in towers() do
			local cost = Levels.upgradeCost("MachineGun", model:GetAttribute("Level") or 1)
			if cost and gold >= cost then
				levelAction:FireServer("Upgrade", model:GetAttribute("TowerId"))
				break
			end
		end
		return arena:GetAttribute("State") ~= "Running"
	end, 120)
	local endScreen = hudGui.EndScreen
	local endOk = waitFor(function()
		return endScreen.Visible
	end, 5)
	local panel = endScreen.Panel
	check(
		wonLevel and arena:GetAttribute("State") == "Won" and endOk and panel.Title.Text == "VICTOIRE !" and string.find(panel.Reward.Text, "80", 1, true) ~= nil
			and panel.Next.Text == "Niveau 2 ▶" and shown(panel.Replay) and shown(panel.Camp) and onScreen(panel),
		`niveau 1 gagné en jouant (état « {tostring(arena:GetAttribute("State"))} », {tostring(arena:GetAttribute("Lives"))} vies) : écran de fin « {panel.Title.Text} », « {panel.Reward.Text} », bouton « {panel.Next.Text} »`
	)
	shot("victoire")
	check(published().best == 1 and published().coins == 80, `pièces de niveau reçues : {tostring(published().coins)}, niveau 2 débloqué`)

	-- « Niveau suivant » : le niveau 2 démarre dans la même zone, sans repasser par le camp.
	act(hudGui, "Next")
	local next2 = waitFor(function()
		return arena:GetAttribute("Level") == 2 and arena:GetAttribute("State") == "Running" and not endScreen.Visible
	end, 6)
	task.wait(0.5)
	check(
		next2 and #towers() == 0 and string.find(strip.Gold.Text, "45", 1, true) ~= nil and strip.Level.Text == "NIVEAU 2" and hudGui:GetAttribute("Placing") == ""
			and cam().CameraType == Enum.CameraType.Scriptable,
		`« Niveau suivant » : niveau 2 en cours, aucune tour gardée, « {strip.Gold.Text} » (l'or repart du montant de départ)`
	)
	-- Défaite : sans aucune tour, les monstres arrivent au château (x2 pour aller vite).
	act(hudGui, "Speed")
	local lost = waitFor(function()
		return arena:GetAttribute("State") == "Lost" and endScreen.Visible
	end, 40)
	check(
		lost and panel.Title.Text == "DÉFAITE" and panel.Next.Text == "Réessayer" and not panel.Replay.Visible and shown(panel.Camp)
			and string.find(strip.Lives.Text, "0", 1, true) ~= nil,
		`niveau 2 sans tour : perdu (« {strip.Lives.Text} »), écran de fin « {panel.Title.Text} », « {panel.Reward.Text} », bouton « {panel.Next.Text} »`
	)
	shot("defaite")
	-- Pendant le niveau, la parcelle du joueur (sans tour, restée sur la place) a raté sa vague : son message
	-- « Vague 1 ratée » ne doit PAS s'afficher par-dessus le niveau. Un message du niveau, lui, s'affiche.
	local function toastWith(word)
		local gui = playerGui:FindFirstChild("Toasts")
		for _, label in if gui then gui:GetDescendants() else {} do
			if label:IsA("TextLabel") and string.find(label.Text, word, 1, true) then
				return label.Text
			end
		end
		return nil
	end
	local plotFolder = workspace.Hub.Plots:FindFirstChild("Plot" .. tostring(slot))
	check(
		toastWith("ratée") == nil and plotFolder ~= nil and plotFolder:GetAttribute("State") ~= nil,
		`pendant un niveau, les messages de la parcelle restée sur la place ne s'affichent pas (parcelle : état « {tostring(plotFolder and plotFolder:GetAttribute("State"))} », message affiché : {tostring(toastWith("ratée"))})`
	)
	act(hudGui, "Next")
	check(
		waitFor(function()
			return arena:GetAttribute("Level") == 2 and arena:GetAttribute("State") == "Running" and not endScreen.Visible
		end, 6) and arena:GetAttribute("Lives") == 10 and arena:GetAttribute("SimSpeed") == 1,
		"« Réessayer » : le niveau 2 repart de zéro (10 vies, vitesse x1)"
	)
	levelAction:FireServer("Place", "Frost", 21, 0) -- (tour pas achetée : le serveur refuse et l'explique)
	check(
		waitFor(function()
			return toastWith("boutique") ~= nil
		end, 3),
		`pendant un niveau, les messages du niveau s'affichent (« {tostring(toastWith("boutique"))} »)`
	)
	-- « Quitter » : un premier appui demande confirmation, le deuxième abandonne.
	act(hudGui, "Select:MachineGun")
	act(hudGui, `Tap:{map.spots[1].X},{map.spots[1].Z}`)
	waitFor(function()
		return #towers() == 1
	end, 4)
	act(hudGui, "Quit")
	task.wait(0.4)
	local stillIn = player:GetAttribute("LevelArena") ~= nil and strip.Quit.Text == "X ?"
	act(hudGui, "Quit")
	local left = waitFor(function()
		return player:GetAttribute("LevelArena") == nil and not hudGui.Enabled
	end, 5)
	task.wait(0.6)
	local guisAfter = otherGuis()
	check(stillIn and left, "« X » : un premier appui demande confirmation, le deuxième abandonne le niveau")
	check(
		cam().CameraType ~= Enum.CameraType.Scriptable and #guisAfter >= #guisBefore and window.Visible and string.find(window.Coins.Text, "8", 1, true) ~= nil
			and window.Page1.Level2.Play.Text == "▶ JOUER" and window.Page1.Level1.Play.Text == "REJOUER",
		`retour au camp : la caméra revient au personnage, les écrans de la parcelle sont remis ({#guisAfter}), la fenêtre des niveaux s'ouvre (« {window.Coins.Text} », niveau 1 « {window.Page1.Level1.Play.Text} », niveau 2 « {window.Page1.Level2.Play.Text} »)`
	)
	local seenAfter = enemies()
	check(seenAfter == 0 and workspace:FindFirstChild("LevelHelpers") == nil, "plus rien de la zone de combat n'est affiché après le retour")
	shot("retour_camp")
	act(campGui, "Close")

	------------------------------------------------------------------
	-- 5) À la taille d'un téléphone (750 x 332)
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
		check(shown(openButton) and onScreen(openButton), `téléphone : bouton « ⚔ NIVEAUX » dans l'écran ({math.floor(openButton.AbsolutePosition.X)},{math.floor(openButton.AbsolutePosition.Y)}, {math.floor(openButton.AbsoluteSize.X)} x {math.floor(openButton.AbsoluteSize.Y)} px)`)
		act(campGui, "Open")
		task.wait(0.5)
		check(window.Visible and onScreen(window), `téléphone : la fenêtre du camp tient dans l'écran ({math.floor(window.AbsoluteSize.X)} x {math.floor(window.AbsoluteSize.Y)} px)`)
		shot("tel_camp")
		act(campGui, "Close")
		levelAction:FireServer("Start", 1)
		waitFor(function()
			return hudGui.Enabled and arena:GetAttribute("State") == "Running" and #towers() >= 1
		end, 15)
		task.wait(1)
		checkView("téléphone, niveau 1")
		act(hudGui, `Tap:{map.spots[2].X},{map.spots[2].Z}`)
		waitFor(function()
			return #towers() == 2
		end, 4)
		act(hudGui, `Tap:{map.spots[1].X},{map.spots[1].Z}`)
		task.wait(0.6)
		local outside = {}
		for _, object in hudButtons() do
			if not onScreen(object) then
				table.insert(outside, object.Name)
			end
		end
		local clashes = overlapping(hudButtons())
		check(#outside == 0 and #clashes == 0 and menu.Visible and onScreen(menu), `téléphone : tous les boutons du niveau sont dans l'écran et ne se recouvrent pas ({#hudButtons()} boutons ; dehors : {table.concat(outside, ", ")} ; recouvrements : {table.concat(clashes, " ; ")})`)
		task.wait(4)
		shot("tel_combat")
		for _, degrees in { 70, 90 } do
			act(hudGui, `Pitch:{degrees}`)
			task.wait(0.6)
			shot("tel_vue_" .. degrees)
		end
		act(hudGui, "Pitch:")
		task.wait(0.4)
		act(hudGui, `Tap:{map.spots[3].X},{map.spots[3].Z + 9}`) -- (herbe vide : le menu se ferme)
		act(hudGui, "Zoom:1.8")
		act(hudGui, "Pan:260,0")
		task.wait(1)
		local _, phoneMinX, phoneMaxX = fieldOnScreen()
		check(hudGui:GetAttribute("Zoom") == 1.8 and (phoneMaxX - phoneMinX) > cam().ViewportSize.X, `téléphone, zoom x1,8 : la carte ({math.floor(phoneMaxX - phoneMinX)} px) est plus large que l'écran, on la parcourt en glissant`)
		shot("tel_zoom")
		act(hudGui, "Quit")
		act(hudGui, "Quit")
		waitFor(function()
			return player:GetAttribute("LevelArena") == nil
		end, 5)
	end

	say("LEVELS:client=done")
	task.wait(1.5)
	say("PHONE:done")
end

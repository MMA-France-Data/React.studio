-- Test du JEU (niveaux et camp d'entraînement), côté client : tools/studio-test/run.ps1.
-- Il attend que le serveur ait fini ses propres vérifications (attribut LevelsTestPhase = "Client"), puis joue avec
-- la VRAIE interface (src/client/LevelsUI.luau) : un plugin ne peut pas cliquer, il passe donc par l'attribut
-- « TestAction » des deux écrans, qui lance les mêmes fonctions que les boutons et les appuis (un appui sur le
-- terrain passe par le vrai chemin : point de l'écran -> rayon de la caméra -> sol).
--   0) la place centrale et la PARCELLE du joueur, son camp d'entraînement : plus aucun écran de l'ancien jeu, tour
--      posée sur son socle, cibles d'entraînement sur le chemin, invite d'un socle -> onglet Entraînement et ses
--      évolutions, bouton « SON » ;
--   1) à la taille normale de Studio : fenêtre du camp et ses 4 onglets, niveau 1 (vue d'en haut, Archer offert,
--      « + » conseillés, pose libre, bouton « ANNULER » de la tour en main, amélioration, refus sur le chemin, x2),
--      DÉFAITE de celui qui pose 4 Archers puis attend, « Réessayer », victoire en posant et en améliorant sans
--      arrêt, « Niveau suivant », abandon ;
--   2) à la taille d'un téléphone (750 x 332) : un niveau (dont « ANNULER ») et la fenêtre du camp, rien ne sort
--      de l'écran.
-- « SHOT:nom » = capture (out\levels_<nom>.png) ; « PHONE:want=... » = run.ps1 redimensionne la fenêtre de Studio.
return function(log)
	local GuiService = game:GetService("GuiService")
	local HttpService = game:GetService("HttpService")
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Levels = require(ReplicatedStorage:WaitForChild("Shared").Levels)
	local NumberFormat = require(ReplicatedStorage:WaitForChild("Shared").NumberFormat)
	local PlotLayout = require(ReplicatedStorage:WaitForChild("Shared").PlotLayout)
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
			local rest = model:GetAttribute("RestCFrame")
			local point = if rest then arenaCFrame:PointToObjectSpace(rest.Position) else nil
			if point and math.abs(point.X - x) < 0.6 and math.abs(point.Z - z) < 0.6 then
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
	-- Le bouclier (AutoTranslate.luau) : la traduction automatique de Roblox ne doit toucher aucun texte du jeu. Compte
	-- les écrans, les panneaux du monde et les invites, et liste ceux qui lui restent ouverts (AutoLocalize pas coupé).
	local function robloxTranslation()
		local total, open = 0, {}
		for _, root in { playerGui, workspace } do
			for _, object in root:GetDescendants() do
				if object:IsA("LayerCollector") or object:IsA("ProximityPrompt") then
					total += 1
					if object.AutoLocalize ~= false then
						table.insert(open, object:GetFullName())
					end
				end
			end
		end
		return total, open
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
	-- 0) La parcelle est le camp d'entraînement (demande du propriétaire, 02/10/2026 : « tu peux gérer toute la
	--    parcelle et le système d'évolution de tour »)
	------------------------------------------------------------------
	act(campGui, "Close")
	local plotFolder = workspace.Hub.Plots:FindFirstChild("Plot" .. tostring(slot))
	local plotCFrame = PlotLayout.cframe(slot)
	waitFor(function()
		return plotFolder ~= nil and plotFolder:GetAttribute("Camp") == true
	end, 6)
	-- Les écrans de l'ancien jeu (parcelle à vagues, autel, forge, renaissance, boutique des passes, défis, tuto,
	-- classé) n'existent plus du tout.
	local stillOn = {}
	for _, name in {
		"Plot", "Machines", "Rebirth", "RebirthButton", "ShopButton", "Shop", "ChallengesButton", "Challenges", "Tutorial", "TutorialPointer",
		"ShortcutsToggle", "Lobby", "Match", "Admin", "Offline",
	} do
		if playerGui:FindFirstChild(name) then
			table.insert(stillOn, name)
		end
	end
	local gameGuis = {}
	for _, gui in playerGui:GetChildren() do
		if gui:IsA("ScreenGui") and gui.Enabled then
			table.insert(gameGuis, gui.Name)
		end
	end
	table.sort(gameGuis)
	local plusOn = 0
	for _, child in playerGui:GetChildren() do
		if child:IsA("BillboardGui") and string.sub(child.Name, 1, 8) == "FreeSpot" and child.Enabled then
			plusOn += 1
		end
	end
	check(
		plotFolder ~= nil and plotFolder:GetAttribute("Camp") == true and #stillOn == 0 and plusOn == 0,
		`la parcelle est le camp d'entraînement ; plus aucun écran de l'ancien jeu (restes : {table.concat(stillOn, ", ")} ; boutons « + » : {plusOn} ; écrans du jeu : {table.concat(gameGuis, ", ")})`
	)
	-- Capture de la place centrale, vue d'en haut : la rosace et ses torches, plus de cercle du classé.
	local usualView = cam().CFrame
	cam().CameraType = Enum.CameraType.Scriptable
	cam().CFrame = CFrame.lookAt(Vector3.new(0, 105, 85), Vector3.new(0, 0, 5))
	cam().Focus = CFrame.new(0, 0, 5)
	task.wait(0.6)
	shot("place")
	-- (la caméra du joueur repart de sa direction d'avant : sinon elle garderait cette vue plongeante)
	cam().CameraType = Enum.CameraType.Custom
	cam().CFrame = usualView
	task.wait(0.4)
	local hudCoins = campGui:FindFirstChild("HudCoins")
	check(
		hudCoins ~= nil and shown(hudCoins) and onScreen(hudCoins) and string.find(hudCoins.Text, "🏅", 1, true) ~= nil and shown(openButton),
		`pièces de niveau affichées à côté du bouton « ⚔ NIVEAUX » (« {if hudCoins then hudCoins.Text else "?"} »)`
	)
	-- Bouton « SON » : à droite des pièces, sans rien recouvrir.
	local soundGui = playerGui:FindFirstChild("SoundButton")
	local soundButton = soundGui and soundGui:FindFirstChild("SoundButton")
	check(
		soundButton ~= nil and hudCoins ~= nil and shown(soundButton) and onScreen(soundButton) and #overlapping({ openButton, hudCoins, soundButton }) == 0
			and soundButton.AbsolutePosition.X >= hudCoins.AbsolutePosition.X + hudCoins.AbsoluteSize.X,
		`bouton « SON » à droite des pièces de niveau, sans recouvrir les autres boutons ({if soundButton then math.floor(soundButton.AbsolutePosition.X) else "?"} px, {if soundButton then math.floor(soundButton.AbsoluteSize.X) else "?"} x {if soundButton then math.floor(soundButton.AbsoluteSize.Y) else "?"} px)`
	)
	-- La tour à l'entraînement est sur son socle, des cibles (mannequins de paille) roulent sur le chemin.
	local function campModel(slotIndex)
		local folder = plotFolder and plotFolder:FindFirstChild("Towers")
		for _, model in if folder then folder:GetChildren() else {} do
			if model:GetAttribute("CampSlot") == slotIndex then
				return model
			end
		end
		return nil
	end
	local function campTargets()
		local folder = workspace:FindFirstChild("PlotEnemies")
		local targets, monsters = 0, 0
		for _, part in if folder then folder:GetChildren() else {} do
			if part:IsA("BasePart") and (part.Position - plotCFrame.Position).Magnitude < 90 then
				if part:FindFirstChild("StrawBody") then
					targets += 1
				else
					monsters += 1
				end
			end
		end
		return targets, monsters
	end
	waitFor(function()
		return campModel(1) ~= nil and campTargets() >= 4
	end, 12)
	local targets, monsters = campTargets()
	local model1 = campModel(1)
	local padPart = plotFolder.Spots:FindFirstChild("Spot" .. tostring(Levels.CAMP.SPOTS[1]))
	local padLabel = padPart and padPart:FindFirstChild("CampLabel")
	check(
		model1 ~= nil and model1:GetAttribute("TowerType") == "MachineGun" and targets >= 4 and monsters == 0,
		`sur la parcelle : l'Archer à l'entraînement sur son socle, {targets} cibles de paille sur le chemin, {monsters} monstre`
	)
	check(
		waitFor(function()
			return padLabel ~= nil and padLabel.Enabled
		end, 4) and string.find(padLabel.Panel.Title.Text, "Archer", 1, true) ~= nil,
		`étiquette du socle visible depuis le point d'arrivée (« {if padLabel then padLabel.Panel.Title.Text else "?"} », « {if padLabel then padLabel.Panel.Sub.Text else "?"} »)`
	)
	-- Le combat du camp se voit : une flèche tirée sur une cible (son de l'Archer joué sur la parcelle).
	local function plotSound(name)
		for _, child in workspace.Terrain:GetChildren() do
			if child:IsA("Attachment") and child.Name == "Son_" .. name and (child.WorldPosition - plotCFrame.Position).Magnitude < 90 then
				return true
			end
		end
		return false
	end
	check(
		waitFor(function()
			return plotSound("ArcherShot")
		end, 15),
		"l'Archer du camp tire sur les cibles (son de ses flèches sur la parcelle)"
	)
	shot("camp_parcelle")
	-- L'invite « Gérer » du socle ouvre l'onglet Entraînement sur cet emplacement ; chaque tour y montre ses évolutions.
	act(campGui, "Slot:1")
	local trainingPage = window.Page3
	local archerTraining = trainingPage.Towers:FindFirstChild("Train_MachineGun")
	check(
		window.Visible and trainingPage.Visible and archerTraining ~= nil and string.find(archerTraining.Evolution1.Text, "Flèches enflammées", 1, true) ~= nil
			and string.find(archerTraining.Evolution1.Text, "🔒", 1, true) ~= nil and string.find(archerTraining.Evolution3.Text, "Tir rapide", 1, true) ~= nil
			and string.find(archerTraining.NextEvolution.Text, "entraînement 2", 1, true) ~= nil and string.find(archerTraining.Level.Text, "Entraînement 0/6", 1, true) ~= nil,
		`invite du socle : onglet « Entraînement », évolutions de l'Archer « {archerTraining and archerTraining.Evolution1.Text} », « {archerTraining and archerTraining.Evolution2.Text} », « {archerTraining and archerTraining.Evolution3.Text} » ; « {archerTraining and archerTraining.NextEvolution.Text} »`
	)
	shot("camp_evolutions")

	------------------------------------------------------------------
	-- 1) Fenêtre du camp
	------------------------------------------------------------------
	-- (elle s'ouvre toute seule au retour d'un niveau : le serveur vient d'en jouer plusieurs pour ses tests)
	act(campGui, "Close")
	local openBadge = openButton:FindFirstChild("Badge")
	check(
		shown(openButton) and not window.Visible and openButton.Text == "⚔ NIVEAUX" and onScreen(openButton) and openBadge ~= nil and not openBadge.Visible,
		"bouton « ⚔ NIVEAUX » affiché sur la map principale, fenêtre fermée, sans pastille « ! » (0 pièce : rien à acheter)"
	)
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
	-- 40 niveaux en 4 territoires : la page défile, chaque territoire est fermé tant que le dernier niveau du précédent
	-- n'est pas réussi.
	local headers, headerTexts = {}, {}
	for territory in Levels.TERRITORIES do
		headers[territory] = page1:FindFirstChild("Territory" .. territory)
	end
	local headersOk = #headers == #Levels.TERRITORIES
	for territory, header in headers do
		local map = Levels.MAPS[Levels.TERRITORIES[territory]]
		headersOk = headersOk and string.find(header.Text, `TERRITOIRE {territory}`, 1, true) ~= nil and string.find(header.Text, map.displayName, 1, true) ~= nil
			and (territory == 1 or string.find(header.Text, `réussis le niveau {(territory - 1) * Levels.TERRITORY_SIZE}`, 1, true) ~= nil)
		table.insert(headerTexts, `« {header.Text} »`)
	end
	local card11, cardLast = page1:FindFirstChild("Level11"), page1:FindFirstChild("Level" .. Levels.COUNT)
	check(
		headersOk and card11 ~= nil and cardLast ~= nil and page1:FindFirstChild("Level" .. (Levels.COUNT + 1)) == nil
			and card11.Play.Text == "🔒" and page1.CanvasPosition.Y == 0 and page1.AbsoluteCanvasSize.Y > page1.AbsoluteSize.Y + 100,
		`onglet « Niveaux » : {Levels.COUNT} niveaux en {#Levels.TERRITORIES} territoires ({table.concat(headerTexts, ", ")}), la page défile ({math.floor(page1.AbsoluteCanvasSize.Y)} px pour {math.floor(page1.AbsoluteSize.Y)} affichés)`
	)
	page1.CanvasPosition = Vector2.new(0, 5000)
	task.wait(0.4)
	local bossLabel = nil
	for _, child in if cardLast then cardLast:GetChildren() else {} do
		if child:IsA("TextLabel") and string.find(child.Text, "BOSS", 1, true) then
			bossLabel = child.Text
		end
	end
	check(
		cardLast ~= nil and bossLabel ~= nil and string.find(cardLast.Reward.Text, NumberFormat.short(Levels.firstReward(Levels.COUNT)), 1, true) ~= nil and onScreen(cardLast)
			and cardLast.AbsolutePosition.Y + cardLast.AbsoluteSize.Y <= page1.AbsolutePosition.Y + page1.AbsoluteSize.Y + 1,
		`page défilée jusqu'en bas : la carte du niveau {Levels.COUNT} est entière dans la fenêtre (« {tostring(bossLabel)} », « {if cardLast then string.gsub(cardLast.Reward.Text, "\n", " ") else "?"} »)`
	)
	shot("camp_dernier_territoire")
	page1.CanvasPosition = Vector2.new(0, 0)
	act(campGui, "Tab:Boutique")
	local shopPage = window.Page2
	local frostCard = shopPage:FindFirstChild("Shop_Frost")
	local archerCard = shopPage:FindFirstChild("Shop_MachineGun")
	local bombCard = shopPage:FindFirstChild("Shop_Bomb")
	check(
		shopPage.Visible and not page1.Visible and archerCard.Buy.Text == "✓ À TOI" and bombCard.Buy.Text == "✓ À TOI"
			and string.find(frostCard.Buy.Text, "150", 1, true) ~= nil and string.find(frostCard.Buy.Text, "manque", 1, true) ~= nil,
		`onglet « Boutique » : Archer « {archerCard.Buy.Text} », Catapulte « {bombCard.Buy.Text} » (les deux tours de départ), Totem « {frostCard.Buy.Text} » (prix fixe, aucun hasard)`
	)
	local oracleCard, trebuchetCard = shopPage:FindFirstChild("Shop_Chain"), shopPage:FindFirstChild("Shop_Orbital")
	check(
		string.find(frostCard.Role.Text, "40 %", 1, true) ~= nil and string.find(oracleCard.Buy.Text, NumberFormat.short(8000), 1, true) ~= nil
			and string.find(trebuchetCard.Buy.Text, NumberFormat.short(15000), 1, true) ~= nil,
		`boutique : Totem « {frostCard.Role.Text} », Oracle « {oracleCard.Buy.Text} », Trébuchet « {trebuchetCard.Buy.Text} » (les légendaires sont des buts à long terme)`
	)
	local limits = frostCard:FindFirstChild("Limits")
	local limitsGap = if limits then frostCard.Buy.AbsolutePosition.Y - (limits.AbsolutePosition.Y + limits.AbsoluteSize.Y) else -1
	local frostPreview = frostCard:FindFirstChild("TowerPreview")
	check(
		limitsGap >= 6 and frostPreview ~= nil and frostPreview:FindFirstChildOfClass("Model") ~= nil,
		`boutique : la tour est dessinée en 3D sur sa carte, et la dernière ligne ne touche pas le bouton ({math.floor(limitsGap)} px d'écart)`
	)
	shot("camp_boutique")
	act(campGui, "Tab:Entraînement")
	local trainPage = window.Page3
	local slot1, slot2 = trainPage:FindFirstChild("Slot1"), trainPage:FindFirstChild("Slot2")
	local archerRow = trainPage.Towers:FindFirstChild("Train_MachineGun")
	check(
		trainPage.Visible and slot1 ~= nil and slot2 ~= nil and slot2.Action.Visible and string.find(slot2.Action.Text, "400", 1, true) ~= nil
			and archerRow.Visible and trainPage.Towers.Train_Bomb.Visible and not trainPage.Towers.Train_Frost.Visible,
		`onglet « Entraînement » : un emplacement avec l'Archer, le 2e à ouvrir (« {slot2 and slot2.Action.Text} »), seules les tours possédées sont listées (Archer, Catapulte)`
	)
	local lockedFrost = trainPage.Towers:FindFirstChild("Locked_Frost")
	local lockedArcher = trainPage.Towers:FindFirstChild("Locked_MachineGun")
	local archerTile = archerRow:FindFirstChild("PreviewTile")
	check(
		lockedFrost ~= nil and lockedFrost.Visible and lockedArcher ~= nil and not lockedArcher.Visible and string.find(lockedFrost.Price.Text, "150", 1, true) ~= nil
			and archerTile ~= nil and archerTile.AbsoluteSize.X >= 56 and archerTile:FindFirstChild("TowerPreview") ~= nil,
		`onglet « Entraînement » : vignette de l'Archer dans un cadre de {if archerTile then math.floor(archerTile.AbsoluteSize.X) else "?"} px, les tours à acheter sont en gris à la suite (Totem « {if lockedFrost then lockedFrost.Price.Text else "?"} »)`
	)
	-- Bouton ⚡ (entraînement acheté avec des pièces) : au-dessus du bouton « ENTRAÎNER », sans le recouvrir.
	local boost, trainButton = archerRow:FindFirstChild("Boost"), archerRow:FindFirstChild("Train")
	-- (prix : 200 pièces pour le niveau 1, moins l'XP que l'Archer a déjà gagnée au camp, où il s'entraîne)
	local shownPrice = if boost then tonumber(string.match(boost.Text, "\n(%d+)")) else nil
	check(
		boost ~= nil and trainButton ~= nil and shown(boost) and string.find(boost.Text, "+1 NIVEAU", 1, true) ~= nil
			and shownPrice ~= nil and shownPrice >= 150 and shownPrice <= 200 and #overlapping({ boost, trainButton }) == 0
			and boost.AbsolutePosition.Y + boost.AbsoluteSize.Y <= trainButton.AbsolutePosition.Y,
		`onglet « Entraînement » : bouton ⚡ « {if boost then string.gsub(boost.Text, "\n", " ") else "?"} » au-dessus du bouton « {if trainButton then trainButton.Text else "?"} », sans le recouvrir`
	)
	shot("camp_entrainement")
	act(campGui, "Tab:Mes tours")
	local towersPage = window.Page4
	check(towersPage.Visible and towersPage.Towers.Tower_MachineGun.Visible and towersPage.Towers.Tower_Bomb.Visible and not towersPage.Towers.Tower_Orbital.Visible, "onglet « Mes tours » : l'inventaire (l'Archer et la Catapulte pour l'instant)")
	local lockedTrebuchet = towersPage.Towers:FindFirstChild("Locked_Orbital")
	local lockedBomb = towersPage.Towers:FindFirstChild("Locked_Bomb")
	check(
		lockedTrebuchet ~= nil and lockedTrebuchet.Visible and lockedBomb ~= nil and not lockedBomb.Visible
			and string.find(lockedTrebuchet.Price.Text, NumberFormat.short(15000), 1, true) ~= nil and lockedTrebuchet.Shop.Text == "BOUTIQUE",
		`onglet « Mes tours » : les tours pas encore achetées sont en gris à la suite (Trébuchet « {if lockedTrebuchet then lockedTrebuchet.Price.Text else "?"} », bouton « {if lockedTrebuchet then lockedTrebuchet.Shop.Text else "?"} »)`
	)
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
	local shielded, openToRoblox = robloxTranslation()
	check(
		shielded >= 10 and #openToRoblox == 0,
		`joueur français : la traduction automatique de Roblox ne touche aucun texte du jeu ({shielded} écrans, panneaux et invites, tous avec AutoLocalize coupé ; oubliés : {#openToRoblox} {table.concat(openToRoblox, ", ")})`
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
		strip.Level.Text == "NIVEAU 1" and string.find(strip.Gold.Text, "60", 1, true) ~= nil and string.find(strip.Lives.Text, "10", 1, true) ~= nil
			and string.find(strip.Progress.ProgressText.Text, tostring(arena:GetAttribute("Total")), 1, true) ~= nil and strip:FindFirstChild("Rush") == nil,
		`bandeau : « {strip.Level.Text} », « {strip.Lives.Text} », « {strip.Gold.Text} », « {strip.Progress.ProgressText.Text} » (plus de bouton « envoyer la suite » : le flot est continu)`
	)
	local fill = strip.Progress.Fill
	local fillAtStart = fill.BackgroundColor3
	local bar = hudGui.TowerBar
	check(
		shown(bar.Tower_MachineGun) and shown(bar.Tower_Bomb) and not bar.Tower_Frost.Visible and bar.Tower_Bomb.Cost.Text == "45 💰"
			and bar.Tower_MachineGun.Cost.Text == "ANNULER",
		`barre rapide : deux tours dès le départ, l'Archer (déjà en main : « {bar.Tower_MachineGun.Cost.Text} ») et la Catapulte (« {bar.Tower_Bomb.Cost.Text} »)`
	)
	-- L'Archer offert tire tout de suite : un monstre tué en moins de 10 secondes.
	local startedAt = os.clock()
	local firstKill = waitFor(function()
		return (arena:GetAttribute("Gold") or 0) > 60
	end, 12)
	check(firstKill and os.clock() - startedAt <= 10, string.format("premier monstre tué %.1f s après l'arrivée dans le niveau (l'Archer offert tire seul)", os.clock() - startedAt))
	waitFor(function()
		local count, withBar = enemies()
		return count >= 1 and withBar >= 1
	end, 8)
	local seen, bars = enemies()
	check(seen >= 1 and bars >= 1, `{seen} monstres affichés sur le chemin de la zone, {bars} barres de vie visibles (personnage resté sur la place)`)
	-- Monstres grossis dans un niveau (Levels.ENEMY_SCALE) pour être vus de haut : le fantassin fait 1,8 fois sa
	-- taille de base.
	local Enemies = require(ReplicatedStorage:WaitForChild("Shared").Enemies)
	local footSize = nil
	local enemyFolder = workspace:FindFirstChild("PlotEnemies")
	for _, part in if enemyFolder then enemyFolder:GetChildren() else {} do
		if part:IsA("BasePart") and part:GetAttribute("EnemyType") == "Normal" and (part.Position - arenaCFrame.Position).Magnitude < 90 then
			footSize = part.Size.X
			break
		end
	end
	check(
		footSize ~= nil and Levels.enemyScale("Normal") >= 1.5 and math.abs(footSize - Enemies.Defs.Normal.size * Levels.enemyScale("Normal")) < 0.05,
		`les monstres d'un niveau sont affichés plus gros pour être vus de haut (fantassin : {if footSize then string.format("%.1f", footSize) else "?"} studs, {Enemies.Defs.Normal.size} de base)`
	)
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
	-- L'or gagné se voit sur le terrain : un « +6 » doré au-dessus d'un monstre tué.
	check(
		waitFor(function()
			local helpersNow = workspace:FindFirstChild("LevelHelpers")
			return helpersNow ~= nil and helpersNow:FindFirstChild("GoldPopup") ~= nil
		end, 8),
		"un « +6 » doré s'envole au-dessus du monstre tué (or gagné)"
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
	-- Retour du propriétaire (02/10/2026) : « quand je clique sur une tour pour la poser, il faut que je puisse annuler
	-- mon action ». La tour en main : son bouton devient rouge et dit « ANNULER » ; un appui dessus annule tout.
	local goldHeld, towersHeld = arena:GetAttribute("Gold") or 0, #towers()
	local heldButton = bar.Tower_Bomb
	act(hudGui, "Bar:Bomb")
	task.wait(0.2)
	local red = heldButton.BackgroundColor3
	check(
		hudGui:GetAttribute("Placing") == "Bomb" and heldButton.Cost.Text == "ANNULER" and red.R > red.G * 2 and red.R > red.B * 2
			and string.find(hudGui.Hint.Text, "Annuler", 1, true) ~= nil and bar.Tower_MachineGun.Cost.Text == "20 💰",
		`prendre la Catapulte dans la barre : son bouton devient rouge et dit « {heldButton.Cost.Text} », le conseil aussi (« {hudGui.Hint.Text} »)`
	)
	shot("annuler")
	act(hudGui, "Bar:Bomb")
	task.wait(0.2)
	check(
		hudGui:GetAttribute("Placing") == "" and heldButton.Cost.Text == "45 💰" and #towers() == towersHeld and (arena:GetAttribute("Gold") or 0) >= goldHeld
			and heldButton.BackgroundColor3 ~= red,
		`un appui sur « ANNULER » : la pose est annulée, rien n'est posé, aucun or dépensé (bouton de nouveau « {heldButton.Cost.Text} »)`
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
	-- 4) Celui qui attend PERD : conseil « ne garde pas ton or », x2, barre qui rougit, écran de défaite
	------------------------------------------------------------------
	-- 4 Archers posés (dont un amélioré), puis plus aucun achat : l'or s'entasse, le conseil le dit.
	check(
		waitFor(function()
			return string.find(hudGui.Hint.Text, "Ne garde pas ton or", 1, true) ~= nil
		end, 10),
		`or gardé sans rien acheter ({tostring(arena:GetAttribute("Gold"))} or) : le conseil le dit (« {hudGui.Hint.Text} »)`
	)
	act(hudGui, "Speed")
	check(waitFor(function()
		return arena:GetAttribute("SimSpeed") == 2 and strip.Speed.Text == "x2"
	end, 3), "bouton x2 : tout va deux fois plus vite")
	-- Retour du propriétaire : « si juste 2 Archers gèrent le niveau, je passe mon temps à attendre ». Le flot monte,
	-- les monstres passent : le niveau est perdu.
	local endScreen = hudGui.EndScreen
	local panel = endScreen.Panel
	local function levelResult()
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(arena:GetAttribute("Result"))
		end)
		return if ok and typeof(decoded) == "table" then decoded else {}
	end
	local lostLevel = waitFor(function()
		return arena:GetAttribute("State") == "Lost" and endScreen.Visible
	end, 90)
	local lostResult = levelResult()
	local fillAtEnd = fill.BackgroundColor3
	check(
		lostLevel and panel.Title.Text == "DÉFAITE" and panel.Next.Text == "Réessayer" and not panel.Replay.Visible and shown(panel.Camp) and onScreen(panel)
			and string.find(strip.Lives.Text, "0", 1, true) ~= nil and string.find(panel.Details.Text, "Il te restait", 1, true) ~= nil and string.find(panel.Details.Text, "sans arrêt", 1, true) ~= nil
			and lostResult.won == false and (lostResult.kills or 0) < (lostResult.total or 0) * 0.6,
		`4 Archers puis attendre : niveau 1 PERDU après {tostring(lostResult.kills)}/{tostring(lostResult.total)} monstres (« {strip.Lives.Text} »), écran de fin « {panel.Title.Text} », « {panel.Reward.Text} », bouton « {panel.Next.Text} »`
	)
	check(
		fillAtEnd.R > fillAtStart.R + 0.2 and fillAtEnd.G < fillAtStart.G,
		string.format("la barre d'avancée passe du vert au rouge pendant le niveau (rouge %.2f -> %.2f, vert %.2f -> %.2f)", fillAtStart.R, fillAtEnd.R, fillAtStart.G, fillAtEnd.G)
	)
	shot("defaite")
	check(
		published().best == 0 and published().losses == 1 and published().coins == lostResult.reward,
		`défaite comptée : niveau 1 toujours à faire, {tostring(published().coins)} pièce(s) de niveau pour l'avancée`
	)
	-- Petit message affiché qui contient ce mot (nil si aucun).
	local function toastWith(word)
		local gui = playerGui:FindFirstChild("Toasts")
		for _, label in if gui then gui:GetDescendants() else {} do
			if label:IsA("TextLabel") and string.find(label.Text, word, 1, true) then
				return label.Text
			end
		end
		return nil
	end

	------------------------------------------------------------------
	-- 5) « Réessayer », victoire en restant actif, « Niveau suivant »
	------------------------------------------------------------------
	act(hudGui, "Next")
	check(
		waitFor(function()
			return arena:GetAttribute("Level") == 1 and arena:GetAttribute("State") == "Running" and not endScreen.Visible and #towers() == 1
		end, 6) and arena:GetAttribute("Lives") == 10 and arena:GetAttribute("SimSpeed") == 1 and (arena:GetAttribute("Gold") or 0) <= 72,
		`« Réessayer » : le niveau 1 repart de zéro (10 vies, {tostring(arena:GetAttribute("Gold"))} or, vitesse x1, un seul Archer)`
	)
	act(hudGui, "Select:")
	act(hudGui, "Speed")
	-- Jouer comme il faut, par les mêmes demandes que les boutons : poser ses 5 Archers, ses 4 Catapultes, et
	-- améliorer sans arrêt la tour la moins chère (une action toutes les 0,25 s, soit 0,5 s de jeu en x2).
	local nextAct = 0
	local function playActively()
		if os.clock() < nextAct then
			return
		end
		nextAct = os.clock() + 0.25
		local gold = arena:GetAttribute("Gold") or 0
		local list = towers()
		local counts = { MachineGun = 0, Bomb = 0 }
		for _, model in list do
			local towerType = model:GetAttribute("TowerType")
			counts[towerType] = (counts[towerType] or 0) + 1
		end
		local wanted = if counts.MachineGun < 5 then "MachineGun" elseif counts.Bomb < 4 then "Bomb" else nil
		if wanted then
			local free = nil
			for _, spot in map.spots do
				if not towerAt(spot.X, spot.Z) then
					free = spot
					break
				end
			end
			if free and gold >= Levels.placeCost(wanted) then
				levelAction:FireServer("Place", wanted, free.X, free.Z)
				return
			end
			if wanted == "MachineGun" then
				return
			end
		end
		local best, bestCost = nil, math.huge
		for _, model in list do
			local cost = Levels.upgradeCost(model:GetAttribute("TowerType"), model:GetAttribute("Level") or 1)
			if cost and cost < bestCost then
				best, bestCost = model, cost
			end
		end
		if best and gold >= bestCost then
			levelAction:FireServer("Upgrade", best:GetAttribute("TowerId"))
		end
	end
	local midShot = false
	local wonLevel = waitFor(function()
		playActively()
		if not midShot and (arena:GetAttribute("Progress") or 0) >= 70 then
			midShot = true
			say("SHOT:levels_fin_de_niveau")
		end
		return arena:GetAttribute("State") ~= "Running"
	end, 150)
	local endOk = waitFor(function()
		return endScreen.Visible
	end, 5)
	local wonResult = levelResult()
	check(
		wonLevel and arena:GetAttribute("State") == "Won" and endOk and panel.Title.Text == "VICTOIRE !" and string.find(panel.Reward.Text, "80", 1, true) ~= nil
			and panel.Next.Text == "Niveau 2 ▶" and shown(panel.Replay) and shown(panel.Camp) and onScreen(panel) and #towers() == 9,
		`niveau 1 gagné en posant et en améliorant sans arrêt (état « {tostring(arena:GetAttribute("State"))} », {tostring(arena:GetAttribute("Lives"))} vies, {#towers()} tours) : écran de fin « {panel.Title.Text} », « {panel.Reward.Text} », bouton « {panel.Next.Text} »`
	)
	shot("victoire")
	check(
		published().best == 1 and published().coins == (lostResult.reward or 0) + 80 and wonResult.won == true,
		`pièces de niveau reçues : {tostring(published().coins)}, niveau 2 débloqué`
	)

	-- « Niveau suivant » : le niveau 2 démarre dans la même zone, sans repasser par le camp.
	act(hudGui, "Next")
	local next2 = waitFor(function()
		return arena:GetAttribute("Level") == 2 and arena:GetAttribute("State") == "Running" and not endScreen.Visible
	end, 6)
	task.wait(0.5)
	check(
		next2 and #towers() == 0 and string.find(strip.Gold.Text, "65", 1, true) ~= nil and strip.Level.Text == "NIVEAU 2" and hudGui:GetAttribute("Placing") == ""
			and arena:GetAttribute("SimSpeed") == 1 and cam().CameraType == Enum.CameraType.Scriptable,
		`« Niveau suivant » : niveau 2 en cours, aucune tour gardée, « {strip.Gold.Text} » (l'or repart du montant de départ), vitesse x1`
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
		cam().CameraType ~= Enum.CameraType.Scriptable and #guisAfter >= #guisBefore and window.Visible and string.find(window.Coins.Text, tostring(published().coins), 1, true) ~= nil
			and published().coins >= 80
			and window.Page1.Level2.Play.Text == "▶ JOUER" and window.Page1.Level1.Play.Text == "REJOUER",
		`retour au camp : la caméra revient au personnage, les écrans de la parcelle sont remis ({#guisAfter}), la fenêtre des niveaux s'ouvre (« {window.Coins.Text} », niveau 1 « {window.Page1.Level1.Play.Text} », niveau 2 « {window.Page1.Level2.Play.Text} »)`
	)
	local seenAfter = enemies()
	check(seenAfter == 0 and workspace:FindFirstChild("LevelHelpers") == nil, "plus rien de la zone de combat n'est affiché après le retour")
	shot("retour_camp")
	act(campGui, "Close")

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
		check(shown(openButton) and onScreen(openButton), `téléphone : bouton « ⚔ NIVEAUX » dans l'écran ({math.floor(openButton.AbsolutePosition.X)},{math.floor(openButton.AbsolutePosition.Y)}, {math.floor(openButton.AbsoluteSize.X)} x {math.floor(openButton.AbsoluteSize.Y)} px)`)
		-- Le camp sur la parcelle, à la taille du téléphone : pièces à côté du bouton, sans se recouvrir.
		local phoneCoins = campGui:FindFirstChild("HudCoins")
		local buttonRight = openButton.AbsolutePosition.X + openButton.AbsoluteSize.X
		check(
			phoneCoins ~= nil and shown(phoneCoins) and onScreen(phoneCoins) and phoneCoins.AbsolutePosition.X >= buttonRight,
			`téléphone : pièces de niveau à droite du bouton « ⚔ NIVEAUX », dans l'écran ({if phoneCoins then math.floor(phoneCoins.AbsolutePosition.X) else "?"} px, bouton jusqu'à {math.floor(buttonRight)} px)`
		)
		-- Bouton « SON » : une petite icône dans la barre du haut de Roblox, contre le bord droit.
		local phoneSound = if soundGui then soundGui:FindFirstChild("SoundButton") else nil
		check(
			phoneSound ~= nil and phoneCoins ~= nil and shown(phoneSound) and onScreen(phoneSound) and phoneSound.AbsoluteSize.X <= 44 and phoneSound.AbsoluteSize.Y <= 38
				and phoneSound.AbsolutePosition.X + phoneSound.AbsoluteSize.X >= screenSize().X - 16 and #overlapping({ openButton, phoneCoins, phoneSound }) == 0,
			`téléphone : bouton « SON » en petite icône contre le bord droit ({if phoneSound then math.floor(phoneSound.AbsolutePosition.X) else "?"},{if phoneSound then math.floor(phoneSound.AbsolutePosition.Y) else "?"}, {if phoneSound then math.floor(phoneSound.AbsoluteSize.X) else "?"} x {if phoneSound then math.floor(phoneSound.AbsoluteSize.Y) else "?"} px), sans recouvrir les autres boutons`
		)
		shot("tel_parcelle")
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
		-- La tour en main dit « ANNULER », en entier dans l'écran ; un appui dessus annule.
		act(hudGui, "Bar:Bomb")
		task.wait(0.3)
		local phoneHeld = bar.Tower_Bomb
		check(
			hudGui:GetAttribute("Placing") == "Bomb" and phoneHeld.Cost.Text == "ANNULER" and onScreen(phoneHeld) and phoneHeld.AbsoluteSize.X >= 60
				and phoneHeld.AbsoluteSize.Y >= 36 and onScreen(hudGui.Hint) and string.find(hudGui.Hint.Text, "Annuler", 1, true) ~= nil,
			`téléphone : la tour en main dit « {phoneHeld.Cost.Text} » sur un bouton de {math.floor(phoneHeld.AbsoluteSize.X)} x {math.floor(phoneHeld.AbsoluteSize.Y)} px, conseil « {hudGui.Hint.Text} »`
		)
		shot("tel_annuler")
		act(hudGui, "Bar:Bomb")
		task.wait(0.3)
		check(hudGui:GetAttribute("Placing") == "" and phoneHeld.Cost.Text ~= "ANNULER" and #towers() == 1, "téléphone : un appui sur « ANNULER » annule la pose, rien n'est posé")
		act(hudGui, "Bar:MachineGun")
		act(hudGui, `Tap:{map.spots[2].X},{map.spots[2].Z}`)
		check(
			waitFor(function()
				return #towers() == 2
			end, 4) and hudGui:GetAttribute("Placing") == "",
			"téléphone : prendre l'Archer puis toucher un « + » le pose"
		)
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
		-- Menu de la tour sur téléphone : petit, dans un coin du bas, loin de la tour choisie ; vignettes de la barre
		-- assez grandes pour reconnaître la tour.
		local chosen = towerAt(map.spots[1].X, map.spots[1].Z)
		local rest = chosen and chosen:GetAttribute("RestCFrame")
		local towerPoint = if rest then cam():WorldToScreenPoint(rest.Position) else nil
		local ml, mt, mr, mb = rect(menu)
		check(
			towerPoint ~= nil and menu.AbsoluteSize.X <= 220 and menu.AbsoluteSize.Y <= 124
				and (towerPoint.X < ml - 20 or towerPoint.X > mr + 20 or towerPoint.Y < mt - 20 or towerPoint.Y > mb + 20),
			`téléphone : le menu de la tour est petit ({math.floor(menu.AbsoluteSize.X)} x {math.floor(menu.AbsoluteSize.Y)} px) et ne cache pas la tour choisie (tour à {if towerPoint then math.floor(towerPoint.X) else "?"},{if towerPoint then math.floor(towerPoint.Y) else "?"} ; menu de {math.floor(ml)},{math.floor(mt)} à {math.floor(mr)},{math.floor(mb)})`
		)
		local barPreview = bar.Tower_Bomb:FindFirstChild("TowerPreview")
		check(
			barPreview ~= nil and barPreview.AbsoluteSize.Y >= 36 and barPreview:FindFirstChildOfClass("Model") ~= nil,
			`téléphone : la vignette de la barre des tours fait {if barPreview then math.floor(barPreview.AbsoluteSize.Y) else "?"} px de haut`
		)
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

-- Test « téléphone » (tools/studio-test/phone.ps1), côté client : le jeu affiché dans une fenêtre de la taille d'un
-- écran de téléphone. Les autres tests ne font que des calculs avec de fausses tailles ; ici phone.ps1 réduit VRAIMENT
-- la fenêtre de Studio jusqu'à ce que l'écran du jeu (ScreenGui) ait la taille voulue, puis ce scénario ouvre chaque
-- fenêtre, vérifie que rien ne sort de l'écran ni ne se chevauche, et prend une capture (out\phone_<taille>_<nom>.png).
--   « PHONE:want=645x268;have=1740x737 » dans la sortie = phone.ps1 redimensionne la fenêtre de Studio ;
--   « SHOT:nom » = capture.
-- Tailles = la zone du jeu (ScreenGui) : l'écran moins la barre du haut de Roblox (58 px) et les bords arrondis /
-- l'encoche du téléphone.
--   a = le téléphone du propriétaire, mesuré sur sa capture du 01/10/2026 (1536 x 709 px, 2 px par point : compteur
--       de pièces de 160 x 64 = 317 x 127 px ; panneau des tours de 205 points de haut = écran de 300 ; boutons de
--       gauche réduits à x0,50) : 706 x 300 ;
--   b = grand téléphone à encoche (844 x 390 : 750 x 332) ; c = petit téléphone sans encoche (568 x 320 : 568 x 262) ;
--   d = petit écran large (645 x 268).
return function(log)
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local SIZES = { { "a", 706, 300 }, { "b", 750, 332 }, { "c", 568, 262 }, { "d", 645, 268 } }
	local TOLERANCE = 6 -- px d'écart acceptés entre la taille voulue et la taille obtenue
	local FREE_SPOT, TOWER_SPOT, LOCKED_SPOT = 4, 1, 9 -- (parcelle préparée par PhoneServer.luau)

	local function say(message)
		log("Info", "[PHONE] " .. message)
	end
	local function shot(name)
		say("SHOT:" .. name)
		task.wait(1.6)
	end
	local function check(ok, message)
		log(if ok then "Info" else "Error", `[{if ok then "PASS" else "FAIL"}] téléphone : {message}`)
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

	local plotGui = playerGui:WaitForChild("Plot", 60)
	local panel = plotGui and plotGui:WaitForChild("TowerPanel", 30)
	if not panel then
		check(false, "panneau des tours (PlotUI « TowerPanel ») introuvable")
		return
	end
	-- Sur un téléphone, la liste des joueurs de Roblox est repliée : on la cache (dans Studio elle couvre le haut à
	-- droite des captures). Dans sa propre tâche : le scénario regarde le tuto dès le début.
	task.spawn(function()
		for _ = 1, 20 do
			if pcall(function()
				game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
			end) then
				break
			end
			task.wait(0.2)
		end
	end)

	-- Vraiment affiché : lui et ses parents visibles, dans un écran (ScreenGui) allumé.
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
	local function where(object)
		local left, top, right, bottom = rect(object)
		return `{object.Name} [{math.floor(left)},{math.floor(top)} -> {math.floor(right)},{math.floor(bottom)}]`
	end
	-- L'objet tient-il dans ce rectangle (à 1 px près) ?
	local function within(object, left, top, right, bottom)
		local l, t, r, b = rect(object)
		return l >= left - 1 and t >= top - 1 and r <= right + 1 and b <= bottom + 1
	end
	local function insideOf(object, container)
		return within(object, rect(container))
	end
	-- Dans l'écran : la zone de jeu, ou au-dessus d'elle dans la barre du haut de Roblox (le compteur de pièces, SON
	-- et « ▲ » y sont sur téléphone : hauteurs négatives, UI.phoneTopRight).
	local topBar = (game:GetService("GuiService"):GetGuiInset()).Y
	local function onScreen(object)
		local screen = plotGui.AbsoluteSize
		return within(object, 0, -topBar, screen.X, screen.Y)
	end
	-- Boutons (et cadres donnés) affichés qui se recouvrent de plus de 2 px, sans être l'un dans l'autre.
	local function overlaps(objects)
		local found = {}
		for i = 1, #objects do
			for j = i + 1, #objects do
				local a, b = objects[i], objects[j]
				if not a:IsDescendantOf(b) and not b:IsDescendantOf(a) then
					local al, at, ar, ab = rect(a)
					local bl, bt, br, bb = rect(b)
					if math.min(ar, br) - math.max(al, bl) > 2 and math.min(ab, bb) - math.max(at, bt) > 2 then
						table.insert(found, `{where(a)} sur {where(b)}`)
					end
				end
			end
		end
		return found
	end
	local function shownButtons(root)
		local list = {}
		for _, object in root:GetDescendants() do
			if object:IsA("GuiButton") and shown(object) and object.AbsoluteSize.X > 2 and object.AbsoluteSize.Y > 2 then
				table.insert(list, object)
			end
		end
		return list
	end
	local function selectSpot(spotIndex)
		plotGui:SetAttribute("TestSelectSpot", 0)
		task.wait(0.2)
		if spotIndex > 0 then
			plotGui:SetAttribute("TestSelectSpot", spotIndex)
			task.wait(0.8)
		end
	end
	-- Fenêtres ouvertes comme par leur bouton (un plugin ne peut pas cliquer) : voile « Overlay » de leur écran.
	local function setOverlay(guiName, open)
		local gui = playerGui:FindFirstChild(guiName)
		local overlay = gui and gui:FindFirstChild("Overlay")
		if overlay and overlay:IsA("GuiObject") then
			overlay.Visible = open
			return overlay
		end
		return nil
	end
	local function closeMachines()
		local machines = playerGui:FindFirstChild("Machines")
		if machines then
			machines:SetAttribute("OpenMachine", nil)
		end
		setOverlay("Machines", false)
	end
	-- La fenêtre d'un écran : le plus grand cadre affiché sous son voile.
	local function windowOf(overlay)
		local best = nil
		for _, child in overlay:GetChildren() do
			if child:IsA("GuiObject") and child.Visible and (best == nil or child.AbsoluteSize.X * child.AbsoluteSize.Y > best.AbsoluteSize.X * best.AbsoluteSize.Y) then
				best = child
			end
		end
		return best
	end
	-- Une fenêtre : entière dans l'écran, et ses boutons affichés dedans, sans chevauchement.
	local function checkWindow(label, window)
		if not window then
			check(false, `{label} : fenêtre introuvable`)
			return
		end
		local buttons = shownButtons(window)
		local outside = {}
		for _, button in buttons do
			if not onScreen(button) then
				table.insert(outside, where(button))
			end
		end
		local crossed = overlaps(buttons)
		check(
			onScreen(window) and #outside == 0 and #crossed == 0,
			`{label} : {where(window)} dans l'écran, {#buttons} boutons, {#outside} hors de l'écran, {#crossed} chevauchement(s)`
				.. (if #outside > 0 then " ; hors écran : " .. table.concat(outside, ", ", 1, math.min(#outside, 4)) else "")
				.. (if #crossed > 0 then " ; " .. table.concat(crossed, " | ", 1, math.min(#crossed, 4)) else "")
		)
	end

	-- phone.ps1 redimensionne la fenêtre de Studio jusqu'à la taille voulue (au plus près sinon). La taille doit TENIR
	-- 4 s : le journal arrive à phone.ps1 avec ~1 s de retard, une correction en retard peut encore changer la fenêtre
	-- juste après la bonne taille (elle est alors redemandée). Renvoie vrai si la taille est obtenue.
	local function fitTo(width, height)
		local stableSince, deadline = nil, os.clock() + 90
		while os.clock() < deadline do
			local size = plotGui.AbsoluteSize
			if math.abs(size.X - width) <= TOLERANCE and math.abs(size.Y - height) <= TOLERANCE then
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

	-- Le panneau du tuto sur un téléphone (TutorialUI.panelPlace) : affiché, entier, dans le BAS de l'écran, à gauche du
	-- bouton de saut de Roblox (96 px du bord droit), sans aucun bouton dessous. Renvoie vrai ou faux, et les boutons
	-- qu'il recouvre.
	local function tutorialLow(tutorialPanel)
		local screen = plotGui.AbsoluteSize
		local list = shownButtons(playerGui)
		table.insert(list, tutorialPanel)
		local crossed = {}
		for _, crossing in overlaps(list) do
			if string.find(crossing, "Panel", 1, true) then
				table.insert(crossed, crossing)
			end
		end
		local _, top, right = rect(tutorialPanel)
		local ok = shown(tutorialPanel) and onScreen(tutorialPanel) and #crossed == 0 and top >= screen.Y / 2 and right <= screen.X - 95
		return ok, crossed
	end

	----------------------------------------------------------------------
	-- 0) NOUVEAU JOUEUR, avant que le serveur de test prépare la parcelle du joueur avancé. Dans cette place de test
	-- le tuto démarre tout seul, comme dans le jeu publié (objet __AutoTestNewPlayer, TutorialUI.luau). Le classé est
	-- fermé : pas d'étape « zone classée », le tuto commence par un mot d'accueil sur sa parcelle (« TUTO 1/5 • TA
	-- PARCELLE », sans « ✓ BRAVO ! » : le joueur n'a rien fait), puis « POSE UNE TOUR » tout seul. À la taille du
	-- téléphone du propriétaire : ce que voit un nouveau joueur (flèche « ICI », boutons « + » de ses 4 emplacements),
	-- le « + » touché (panneau des tours, carte de l'Archer entourée d'or), l'Archer posé (remote PlotAction, comme la
	-- carte) puis « Améliorer » entouré d'or, et enfin « Passer » (remote TutorialAction, comme le bouton).
	-- Dans sa propre fonction (limite des 200 variables locales de Luau).
	----------------------------------------------------------------------
	local function newPlayer()
		local name, width, height = SIZES[1][1], SIZES[1][2], SIZES[1][3]
		local tag = `phone_{name}_`
		local tutorialGui = playerGui:WaitForChild("Tutorial", 30)
		local tutorialPanel = tutorialGui and tutorialGui:WaitForChild("Panel", 10)
		local title = tutorialPanel and tutorialPanel:FindFirstChild("Title")
		local body = tutorialPanel and tutorialPanel:FindFirstChild("Text")
		local remotes = ReplicatedStorage:WaitForChild("Remotes", 30)
		local action = remotes and remotes:WaitForChild("TutorialAction", 10)
		local plotAction = remotes and remotes:WaitForChild("PlotAction", 10)
		if not (title and body and action and plotAction) then
			check(false, "nouveau joueur : panneau du tuto ou remotes introuvables")
			return
		end
		local function has(text, piece)
			return string.find(text, piece, 1, true) ~= nil
		end
		-- Tout ce que le panneau affiche depuis le début (le scénario démarre avant le tuto).
		local titles, texts = {}, {}
		local function note(list, label)
			if label.Text ~= "" and list[#list] ~= label.Text then
				table.insert(list, label.Text)
			end
		end
		local titleConnection = title:GetPropertyChangedSignal("Text"):Connect(function()
			note(titles, title)
		end)
		local bodyConnection = body:GetPropertyChangedSignal("Text"):Connect(function()
			note(texts, body)
		end)
		local started = waitFor(function()
			return shown(tutorialPanel)
		end, 60)
		note(titles, title)
		note(texts, body)
		check(
			started and has(titles[1] or "", "1/5") and has(titles[1] or "", "TA PARCELLE") and player:GetAttribute("TutorialDone") == false,
			`nouveau joueur : le tuto démarre tout seul ({started}) par « {titles[1]} » (classé fermé : pas d'étape de la zone classée)`
		)
		local placing = waitFor(function()
			return has(title.Text, "2/5")
		end, 25)
		titleConnection:Disconnect()
		bodyConnection:Disconnect()
		local bravo, welcome = false, false
		for _, text in titles do
			bravo = bravo or has(text, "BRAVO")
		end
		for _, text in texts do
			welcome = welcome or has(text, "Bienvenue ! Voici ta parcelle")
		end
		check(
			placing and has(title.Text, "POSE UNE TOUR") and welcome and not bravo,
			`nouveau joueur : mot d'accueil sur sa parcelle ({welcome}), puis « {title.Text} » tout seul, sans « BRAVO » (titres : {table.concat(titles, " | ")})`
		)

		-- À la taille du téléphone : le panneau du tuto en BAS de l'écran (en haut, il cachait les « + » et la flèche),
		-- entier, sans bouton dessous, à gauche du bouton de saut de Roblox ; la flèche « ICI » et un bouton « + » sur
		-- chacun des 4 emplacements de départ.
		local fits = fitTo(width, height)
		local screen = plotGui.AbsoluteSize
		task.wait(1)
		local lowOk, lowCrossed = tutorialLow(tutorialPanel)
		local plus = 0
		for _, child in playerGui:GetChildren() do
			if child:IsA("BillboardGui") and string.match(child.Name, "^FreeSpot%d+$") and child.Enabled and child.Adornee ~= nil
				and child:FindFirstChild("Plus") ~= nil then
				plus += 1
			end
		end
		local guide = workspace:FindFirstChild("TutorialGuide")
		local marker = guide and guide:FindFirstChild("Marker")
		local markerLabel = marker and marker:FindFirstChild("Label")
		check(
			fits and lowOk and plus == 4 and marker ~= nil and marker.Enabled and markerLabel ~= nil and markerLabel.Text == "ICI",
			`nouveau joueur {name} ({math.floor(screen.X)} x {math.floor(screen.Y)}) : {where(tutorialPanel)} en bas de l'écran, à gauche du bouton de saut, {#lowCrossed} bouton(s) dessous, {plus} bouton(s) « + », flèche « {markerLabel and markerLabel.Text} »`
				.. (if #lowCrossed > 0 then " : " .. table.concat(lowCrossed, " | ", 1, math.min(#lowCrossed, 3)) else "")
		)
		shot(tag .. "newplayer")

		-- SA parcelle, pas la 1 (question du propriétaire, 01/10/2026 : « quelqu'un qui arrive dans ma partie, le tuto le
		-- ramène bien à SA parcelle et pas à la mienne ? »). Dans cette place de test, le joueur reçoit la parcelle 2
		-- (objet __AutoTestPlot, Hub/Plots.luau), comme le 2e arrivé sur un serveur dont la 1 est prise. Il apparaît sur
		-- la 2 ; la flèche du tuto et les 4 boutons « + » sont sur la 2 ; les invites « Ouvrir » de l'autel et de la
		-- forge sont allumées sur la 2 et éteintes sur la 1 (PlotAccess.luau).
		local PlotLayout = require(ReplicatedStorage.Shared.PlotLayout)
		local myIndex = player:GetAttribute("Plot")
		local plotsFolder = workspace:FindFirstChild("Hub") and workspace.Hub:FindFirstChild("Plots")
		local myFolder = plotsFolder and plotsFolder:FindFirstChild("Plot" .. tostring(myIndex))
		local firstFolder = plotsFolder and plotsFolder:FindFirstChild("Plot1")
		-- Ce point est-il sur le sol de cette parcelle (ou juste devant son entrée, là où sont l'autel et la forge) ?
		local function onPlot(index, position)
			local at = PlotLayout.toLocal(index, position)
			return math.abs(at.X) <= PlotLayout.WIDTH / 2 + 2 and at.Z >= -PlotLayout.LENGTH / 2 - 14 and at.Z <= PlotLayout.LENGTH / 2 + 2
		end
		local function promptOn(folder, machineName)
			local machine = folder and folder:FindFirstChild(machineName)
			local prompt = machine and machine:FindFirstChildOfClass("ProximityPrompt")
			return prompt ~= nil and prompt.Enabled
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local plusMine, plusElsewhere = 0, 0
		for _, child in playerGui:GetChildren() do
			if child:IsA("BillboardGui") and string.match(child.Name, "^FreeSpot%d+$") and child.Enabled and child.Adornee ~= nil then
				if myFolder and child.Adornee:IsDescendantOf(myFolder) then
					plusMine += 1
				else
					plusElsewhere += 1
				end
			end
		end
		local spawnedHome = root ~= nil and onPlot(2, root.Position) and not onPlot(1, root.Position)
		local arrowHome = guide ~= nil and onPlot(2, guide.Position) and not onPlot(1, guide.Position)
		local promptsHome = promptOn(myFolder, "TowerMachine") and promptOn(myFolder, "BonusMachine")
		local promptsFirst = promptOn(firstFolder, "TowerMachine") or promptOn(firstFolder, "BonusMachine")
		check(
			myIndex == 2 and myFolder ~= nil and firstFolder ~= nil and spawnedHome and arrowHome and plusMine == 4 and plusElsewhere == 0
				and promptsHome and not promptsFirst,
			`nouveau joueur sur la parcelle {tostring(myIndex)} (pas la 1) : il apparaît sur SA parcelle ({spawnedHome}), la flèche du tuto y est ({arrowHome}), {plusMine} boutons « + » dessus et {plusElsewhere} ailleurs, invites de l'autel et de la forge allumées chez lui ({promptsHome}) et éteintes sur la parcelle 1 ({not promptsFirst})`
		)

		-- Fenêtre de l'autel ouverte (comme par son invite) : ses boutons de lancer sont en bas, le panneau du tuto
		-- monte donc en haut de l'écran, sans ses boutons ; fenêtre fermée : il redescend.
		say("CMD:OpenMachine:Tower")
		local machines = playerGui:FindFirstChild("Machines")
		local altarOpen = waitFor(function()
			return machines ~= nil and machines:GetAttribute("OpenMachine") == "Tower"
		end, 6)
		local movedUp = waitFor(function()
			local _, top, _, bottom = rect(tutorialPanel)
			return shown(tutorialPanel) and top >= 0 and bottom <= screen.Y / 2
		end, 3)
		local skipButton = tutorialPanel:FindFirstChild("SkipButton")
		local spinButton = machines and machines:FindFirstChild("Spin_1", true)
		local spinClear = spinButton ~= nil and shown(spinButton) and onScreen(spinButton)
		if spinClear then
			for _, crossing in overlaps({ spinButton, tutorialPanel }) do
				spinClear = false
				say(`autel : {crossing}`)
			end
		end
		check(
			altarOpen and movedUp and skipButton ~= nil and not shown(skipButton) and spinClear,
			`nouveau joueur {name} : autel ouvert -> le tuto monte en haut ({where(tutorialPanel)}), sans « Passer » ({skipButton ~= nil and not shown(skipButton)}), bouton x1 de l'autel dégagé ({spinClear})`
		)
		shot(tag .. "newplayer_altar")
		closeMachines()
		local movedDown = waitFor(function()
			return (tutorialLow(tutorialPanel))
		end, 3)
		check(movedDown, `nouveau joueur {name} : autel fermé -> le tuto redescend ({where(tutorialPanel)})`)

		-- Le « + » de l'emplacement 1 (celui sous la flèche) : le panneau des tours s'ouvre, le tuto se cache derrière
		-- lui, la carte de l'Archer est entourée d'or.
		selectSpot(1)
		local card = panel:FindFirstChild("Card_MachineGun", true)
		local ringed = waitFor(function()
			return card ~= nil and shown(card) and card:FindFirstChild("TutorialHighlight") ~= nil
		end, 4)
		check(
			shown(panel) and onScreen(panel) and ringed and card ~= nil and onScreen(card) and not shown(tutorialPanel),
			`nouveau joueur {name} : « + » -> {where(panel)} ouvert, carte de l'Archer entourée d'or ({ringed}), tuto caché derrière ({not shown(tutorialPanel)})`
		)
		shot(tag .. "newplayer_cards")

		-- L'Archer posé : la fiche de la tour remplace les cartes, puis l'étape suivante entoure « Améliorer » d'or.
		plotAction:FireServer("Place", 1, "MachineGun")
		local upgradeStep = waitFor(function()
			return has(title.Text, "3/5")
		end, 20)
		local upgradeButton = panel:FindFirstChild("UpgradeButton", true)
		local upgradeRinged = waitFor(function()
			return upgradeButton ~= nil and shown(upgradeButton) and upgradeButton:FindFirstChild("TutorialHighlight") ~= nil
		end, 4)
		check(
			upgradeStep and upgradeRinged and upgradeButton ~= nil and onScreen(upgradeButton),
			`nouveau joueur {name} : Archer posé -> « {title.Text} », bouton « Améliorer » entouré d'or sur sa fiche ({upgradeRinged})`
		)
		shot(tag .. "newplayer_upgrade")
		selectSpot(0)
		-- (la tour est posée sur SA parcelle, la 2 ; rien sur la 1 ; la flèche « TA TOUR » la montre)
		local function towerCount(folder)
			local towers = folder and folder:FindFirstChild("Towers")
			local count, model = 0, nil
			for _, child in (if towers then towers:GetChildren() else {}) do
				if typeof(child:GetAttribute("SpotIndex")) == "number" then
					count += 1
					model = child
				end
			end
			return count, model
		end
		local mine, placedModel = towerCount(myFolder)
		local onFirst = towerCount(firstFolder)
		local towerHome = placedModel ~= nil and placedModel:IsA("Model") and onPlot(2, placedModel:GetPivot().Position)
		local arrowOnTower = guide ~= nil and placedModel ~= nil and placedModel:IsA("Model")
			and (Vector3.new(guide.Position.X, 0, guide.Position.Z) - Vector3.new(placedModel:GetPivot().Position.X, 0, placedModel:GetPivot().Position.Z)).Magnitude < 1.5
		check(
			mine == 1 and onFirst == 0 and towerHome and arrowOnTower,
			`nouveau joueur sur la parcelle {tostring(myIndex)} : son Archer est posé sur SA parcelle ({mine} tour, {towerHome}), aucune tour sur la parcelle 1 ({onFirst}), la flèche du tuto montre sa tour ({arrowOnTower})`
		)

		-- « Passer » sur téléphone (appuis faits par l'attribut de test TestSkipTap : un plugin ne peut pas toucher
		-- l'écran) : le bouton est à côté du bouton de saut, un appui par erreur ne doit pas faire perdre le tuto. Un
		-- 1er appui ne passe rien (« Confirmer ? »), il s'annule tout seul au bout de 3 s ; deux appuis de suite passent
		-- le tuto. Le serveur de test prépare ensuite la parcelle du joueur avancé.
		local function tapSkip()
			tutorialGui:SetAttribute("TestSkipTap", (tutorialGui:GetAttribute("TestSkipTap") or 0) + 1)
			task.wait(0.3)
		end
		tapSkip()
		local armedText = if skipButton then skipButton.Text else "?"
		local stillRunning = shown(tutorialPanel) and player:GetAttribute("TutorialDone") == false
		local disarmed = waitFor(function()
			return skipButton ~= nil and skipButton.Text == "Passer"
		end, 5)
		check(
			armedText == "Confirmer ?" and stillRunning and disarmed and player:GetAttribute("TutorialDone") == false,
			`nouveau joueur : 1er appui sur « Passer » -> « {armedText} », le tuto continue ({stillRunning}) ; 3 s sans 2e appui -> de nouveau « {skipButton and skipButton.Text} » ({disarmed})`
		)
		tapSkip()
		tapSkip()
		local skipped = waitFor(function()
			return not shown(tutorialPanel) and player:GetAttribute("TutorialDone") == true
		end, 8)
		check(skipped, `nouveau joueur : deux appuis sur « Passer » -> tuto fermé (TutorialDone = {tostring(player:GetAttribute("TutorialDone"))})`)
	end
	newPlayer()

	if not waitFor(function()
		return ReplicatedStorage:GetAttribute("PhoneTestReady") == true
	end, 90) then
		check(false, "le serveur de test n'a pas préparé la parcelle")
		return
	end
	task.wait(4)

	for _, entry in SIZES do
		local name, width, height = entry[1], entry[2], entry[3]
		closeMachines()
		for _, guiName in { "Shop", "Challenges", "Rebirth" } do
			setOverlay(guiName, false)
		end
		selectSpot(0)

		-- 1) La fenêtre de Studio à la taille voulue (fitTo).
		local fits = fitTo(width, height)
		local screen = plotGui.AbsoluteSize
		check(fits, `taille {name} : voulu {width} x {height}, obtenu {math.floor(screen.X)} x {math.floor(screen.Y)}`)
		local tag = `phone_{name}_`

		-- 2) L'écran de jeu, rien d'ouvert : boutons et compteur de pièces dans l'écran, sans chevauchement, et rien
		--    au milieu de la vue. Chacun est soit dans la barre du haut de Roblox (au-dessus de la zone de jeu : pièces,
		--    « ▲ », SON), soit contre le bord droit au-dessus du bouton de saut (icônes de l'autel et de la forge,
		--    bouton Renaissance), soit dans le coin en haut à gauche (bouton Boutique).
		local hud = shownButtons(playerGui)
		local wallet = plotGui:FindFirstChild("Wallet")
		if wallet and shown(wallet) then
			table.insert(hud, wallet)
		end
		local outside, inView, lowest = {}, {}, 0
		for _, object in hud do
			local left, _, right, bottom = rect(object)
			if not onScreen(object) then
				table.insert(outside, where(object))
			end
			local inTopBar = bottom <= 0
			local atRight = left >= screen.X - 131 and bottom <= screen.Y - 90
			local topLeft = right <= 130 and bottom <= 50
			if not (inTopBar or atRight or topLeft) then
				table.insert(inView, where(object))
			end
			lowest = math.max(lowest, bottom)
			say(`écran {name} : {where(object)}`)
		end
		local crossed = overlaps(hud)
		check(
			#outside == 0 and #crossed == 0 and #inView == 0,
			`écran de jeu {name} : {#hud} boutons, {#outside} hors de l'écran, {#crossed} chevauchement(s), {#inView} sur la vue, le plus bas à {math.floor(lowest)} px sur {math.floor(screen.Y)}`
				.. (if #outside > 0 then " ; hors écran : " .. table.concat(outside, ", ", 1, math.min(#outside, 4)) else "")
				.. (if #crossed > 0 then " ; " .. table.concat(crossed, " | ", 1, math.min(#crossed, 4)) else "")
				.. (if #inView > 0 then " ; sur la vue : " .. table.concat(inView, ", ", 1, math.min(#inView, 4)) else "")
		)
		shot(tag .. "hud")

		-- Bouton « ▲ » (demande du propriétaire : cacher les icônes sans jamais perdre le bouton qui les remet) : un
		-- appui cache les icônes et SON, le bouton reste à sa place avec le compteur de pièces (« ▼ ») ; un 2e appui
		-- les remet.
		local toggleGui = playerGui:FindFirstChild("ShortcutsToggle")
		local toggle = toggleGui and toggleGui:FindFirstChild("ToggleButton")
		if toggle then
			local function shortcuts()
				local count = 0
				for _, object in shownButtons(playerGui) do
					if object:FindFirstChild("ColumnScale") then
						count += 1
					end
				end
				return count
			end
			local function press()
				toggleGui:SetAttribute("TestToggle", (toggleGui:GetAttribute("TestToggle") or 0) + 1)
				task.wait(0.4)
			end
			-- (le bouton SON se cache avec les raccourcis ; le compteur de pièces reste toujours)
			local soundGui = playerGui:FindFirstChild("SoundButton")
			local sound = soundGui and soundGui:FindFirstChild("SoundButton")
			local before, shownBefore, textBefore, placeBefore = shortcuts(), shown(toggle) and onScreen(toggle), toggle.Text, where(toggle)
			local soundBefore = sound ~= nil and shown(sound)
			press()
			local hiddenCount, stays, textHidden, placeHidden = shortcuts(), shown(toggle) and onScreen(toggle), toggle.Text, where(toggle)
			local soundHidden = sound ~= nil and not shown(sound)
			local walletStays = wallet ~= nil and shown(wallet)
			shot(tag .. "hidden")
			press()
			local after = shortcuts()
			check(
				before >= 4 and shownBefore and soundBefore and hiddenCount == 0 and stays and placeHidden == placeBefore
					and soundHidden and walletStays and textHidden ~= textBefore and after == before and shown(toggle)
					and sound ~= nil and shown(sound),
				`bouton « ▲ » {name} : {before} icônes affichées (« {textBefore} ») ; un appui -> {hiddenCount} icône, SON caché ({soundHidden}), pièces affichées ({walletStays}) et le bouton reste à sa place (« {textHidden} », {placeHidden}) ; 2e appui -> {after} icônes`
			)
		else
			check(false, `bouton « ▲ » {name} : introuvable (PlayerGui.ShortcutsToggle.ToggleButton)`)
		end

		-- Tuto des nouveaux joueurs sur téléphone, à chaque taille : relancé (« Replay », Studio seulement), son panneau
		-- est en bas de la zone de jeu, entier, à gauche du bouton de saut, sans toucher aucun bouton ; puis « Passer ».
		do
			local remotes = ReplicatedStorage:FindFirstChild("Remotes")
			local action = remotes and remotes:FindFirstChild("TutorialAction")
			local tutorialGui = playerGui:FindFirstChild("Tutorial")
			local tutorialPanel = tutorialGui and tutorialGui:FindFirstChild("Panel")
			if action and tutorialPanel then
				action:FireServer("Replay")
				local started = waitFor(function()
					return shown(tutorialPanel)
				end, 8)
				task.wait(0.6)
				local lowOk, tutorialCrossed = tutorialLow(tutorialPanel)
				check(
					started and lowOk,
					`tuto {name} : panneau affiché ({started}), {where(tutorialPanel)} en bas de l'écran, à gauche du bouton de saut, {#tutorialCrossed} bouton(s) dessous`
						.. (if #tutorialCrossed > 0 then " : " .. table.concat(tutorialCrossed, " | ", 1, math.min(#tutorialCrossed, 3)) else "")
				)
				shot(tag .. "tutorial")
				action:FireServer("Skip", 1)
				waitFor(function()
					return not shown(tutorialPanel)
				end, 5)
			else
				check(false, `tuto {name} : remote TutorialAction ou panneau introuvable`)
			end
		end

		-- 3) Emplacement libre : les cartes des tours, page par page.
		selectSpot(FREE_SPOT)
		local cardRow = panel:FindFirstChild("TowerChoices")
		local pager = panel:FindFirstChild("TowerPages")
		local pageLabel = pager and pager:FindFirstChild("PageNumber")
		local pages = tonumber(pageLabel and string.match(pageLabel.Text, "/%s*(%d+)")) or 1
		local seen, total = {}, 0
		for _, child in (if cardRow then cardRow:GetChildren() else {}) do
			if child:IsA("GuiButton") then
				total += 1
			end
		end
		for page = 1, pages do
			plotGui:SetAttribute("TestTowerPage", page)
			task.wait(0.5)
			local cut, visibleCards, cardSize = {}, 0, nil
			for _, card in (if cardRow then cardRow:GetChildren() else {}) do
				if card:IsA("GuiButton") and shown(card) then
					visibleCards += 1
					seen[card.Name] = true
					cardSize = card.AbsoluteSize
					if not insideOf(card, cardRow) or not onScreen(card) then
						table.insert(cut, where(card))
					end
					-- Les textes de la carte tiennent dans la carte (nom, dégâts, prix...), sans se chevaucher.
					local labels = {}
					for _, label in card:GetChildren() do
						if label:IsA("TextLabel") and label.Visible then
							table.insert(labels, label)
							if not insideOf(label, card) then
								table.insert(cut, `{card.Name}.{where(label)}`)
							end
						end
					end
					for _, crossing in overlaps(labels) do
						table.insert(cut, `{card.Name} : {crossing}`)
					end
				end
			end
			check(
				shown(panel) and onScreen(panel) and visibleCards > 0 and #cut == 0,
				`cartes {name}, page {page}/{pages} : {where(panel)}, {visibleCards} carte(s) de {if cardSize then `{math.floor(cardSize.X)} x {math.floor(cardSize.Y)}` else "?"} px, {#cut} coupée(s)`
					.. (if #cut > 0 then " : " .. table.concat(cut, ", ", 1, math.min(#cut, 4)) else "")
			)
			if page <= 2 or page == pages then
				shot(`{tag}cards{page}`)
			end
		end
		local seenCount = 0
		for _ in seen do
			seenCount += 1
		end
		check(seenCount == total and total > 0, `cartes {name} : {seenCount} tours sur {total} visibles en feuilletant les {pages} page(s)`)
		checkWindow(`panneau des cartes {name}`, panel)
		plotGui:SetAttribute("TestTowerPage", 1)

		-- 4) Tour posée (Archer, 2 runes posées, 4 runes dans l'inventaire) : la fiche, puis « Détails & effets ».
		selectSpot(TOWER_SPOT)
		checkWindow(`fiche de la tour {name}`, panel)
		shot(tag .. "tower")
		local towerInfo = panel:FindFirstChild("TowerInfo")
		local detailsButton = towerInfo and towerInfo:FindFirstChild("DetailsButton")
		if detailsButton and shown(detailsButton) then
			plotGui:SetAttribute("TestTowerDetails", true)
			task.wait(0.5)
			checkWindow(`détails de la tour {name}`, panel)
			shot(tag .. "details")
			plotGui:SetAttribute("TestTowerDetails", false)
		else
			say(`taille {name} : pas de bouton « Détails & effets » (tout est sur la fiche)`)
		end

		-- 5) Emplacement à acheter.
		selectSpot(LOCKED_SPOT)
		checkWindow(`emplacement à acheter {name}`, panel)
		shot(tag .. "locked")
		selectSpot(0)

		-- 6) Autel et forge (ouverts comme par leur invite : commande du plugin), boutique, défis, renaissance.
		for _, machine in { "Tower", "Bonus" } do
			say(`CMD:OpenMachine:{machine}`)
			local machines = playerGui:FindFirstChild("Machines")
			local opened = waitFor(function()
				return machines ~= nil and machines:GetAttribute("OpenMachine") == machine
			end, 6)
			task.wait(0.8)
			local overlay = machines and machines:FindFirstChild("Overlay")
			if opened and overlay then
				checkWindow(`{if machine == "Tower" then "autel" else "forge"} {name}`, windowOf(overlay))
			else
				check(false, `{machine} {name} : la machine ne s'est pas ouverte`)
			end
			shot(tag .. (if machine == "Tower" then "altar" else "forge"))
		end
		closeMachines()
		for _, window in { { "Shop", "shop" }, { "Challenges", "challenges" }, { "Rebirth", "rebirth" } } do
			local overlay = setOverlay(window[1], true)
			task.wait(0.8)
			if overlay then
				checkWindow(`{window[2]} {name}`, windowOf(overlay))
			else
				check(false, `{window[2]} {name} : écran introuvable`)
			end
			shot(tag .. window[2])
			setOverlay(window[1], false)
		end
	end
	say("PHONE:done")
end

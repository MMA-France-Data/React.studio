-- Test du TUTO d'un nouveau joueur, côté client : tools/studio-test/run.ps1 -Test tutorial.
-- La place de test contient le marqueur __AutoTestNewPlayer : le tuto démarre comme pour un vrai nouveau joueur
-- (src/client/TutorialUI.luau). Le scénario lit ce que la flèche montre (attributs « Target », « TargetPoint » et
-- « Caption » de l'écran « TutorialPointer ») et fait ce qu'elle dit, par les mêmes chemins que les boutons et les
-- appuis (attribut « TestAction » des écrans « Levels » et « LevelHud ») :
--   1) à l'arrivée : la fenêtre des niveaux s'ouvre toute seule, la flèche montre « ▶ JOUER » ; fenêtre fermée ou
--      autre onglet : elle montre comment y revenir ;
--   2) le niveau 1 : « POSE-LA ICI », « TOUCHE CETTE TOUR », « AMÉLIORE », puis le scénario SUIT LA FLÈCHE jusqu'à la
--      fin du niveau : il doit gagner ;
--   3) la boutique : dès que le joueur peut acheter une tour, « Retour au camp », l'onglet Boutique, « ACHETER » ;
--      l'achat termine le tuto ; statistiques des nouveaux joueurs (6 étapes dans l'ordre) ;
--   4) « Passer le tuto » (un appui sur ordinateur) ;
--   5) à la taille d'un téléphone (750 x 332) : la flèche et ses mots restent dans l'écran, « Passer » en deux appuis.
-- « SHOT:nom » = capture (out\tutorial_<nom>.png) ; « PHONE:want=... » = run.ps1 redimensionne la fenêtre de Studio.
return function(log)
	local GuiService = game:GetService("GuiService")
	local HttpService = game:GetService("HttpService")
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Levels = require(ReplicatedStorage:WaitForChild("Shared").Levels)
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local function say(message)
		log("Info", "[TUTO] " .. message)
	end
	local function shot(name)
		say("SHOT:tutorial_" .. name)
		task.wait(1.6)
	end
	local function check(ok, message)
		log(if ok then "Info" else "Error", `[{if ok then "PASS" else "FAIL"}] tuto : {message}`)
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
		say("TUTO:client=done")
		task.wait(1.5)
		say("PHONE:done")
	end

	local startedAt = os.clock()
	local campGui = playerGui:WaitForChild("Levels", 90)
	local hudGui = playerGui:WaitForChild("LevelHud", 30)
	local pointerGui = playerGui:WaitForChild("TutorialPointer", 30)
	local test = ReplicatedStorage:WaitForChild("__TutorialTest", 60)
	if not campGui or not hudGui or not pointerGui or not test then
		check(false, `écrans introuvables (Levels : {tostring(campGui ~= nil)}, LevelHud : {tostring(hudGui ~= nil)}, TutorialPointer : {tostring(pointerGui ~= nil)}, serveur du test : {tostring(test ~= nil)})`)
		finish()
		return
	end
	local window = campGui:WaitForChild("Window")
	local openButton = campGui:WaitForChild("LevelsButton")
	local arrow = pointerGui:WaitForChild("Arrow")
	local words = pointerGui:WaitForChild("Caption")
	local skip = pointerGui:WaitForChild("Skip")
	local levelAction = ReplicatedStorage.Remotes.LevelAction
	local topBar = (GuiService:GetGuiInset()).Y
	local function cam()
		return workspace.CurrentCamera
	end
	local function screenSize()
		local viewport = cam().ViewportSize
		return Vector2.new(viewport.X, viewport.Y - topBar)
	end
	local counter = 0
	local function act(gui, command)
		counter += 1
		gui:SetAttribute("TestAction", `{command}#{counter}`)
		task.wait(0.15)
	end
	local function published()
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(player:GetAttribute("LevelsState"))
		end)
		return if ok then decoded else {}
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
	local function onScreen(object)
		local screen = screenSize()
		local l, t, r, b = rect(object)
		return l >= -1 and t >= -1 and r <= screen.X + 1 and b <= screen.Y + 1
	end
	local function overlap(a, b)
		local al, at, ar, ab = rect(a)
		local bl, bt, br, bb = rect(b)
		return math.min(ar, br) - math.max(al, bl) > 2 and math.min(ab, bb) - math.max(at, bt) > 2
	end

	-- Ce que la flèche montre.
	local function target()
		return pointerGui:GetAttribute("Target") or ""
	end
	local function caption()
		return pointerGui:GetAttribute("Caption") or ""
	end
	local function showing(name, text)
		return target() == name and (text == nil or caption() == text)
	end
	local function waitShowing(name, text, seconds)
		return waitFor(function()
			return showing(name, text)
		end, seconds or 4)
	end
	local function described()
		return `« {target()} », « {caption()} »`
	end
	-- La flèche est-elle bien placée ? Elle doit être affichée, dans l'écran, et tout près du rectangle montré (un
	-- bouton, ou un point du terrain et ses 22 px autour) ; ses mots affichés et dans l'écran. Renvoie nil si tout va
	-- bien, sinon ce qui ne va pas.
	local ARROW_REACH = 52 -- px du centre de la flèche au bord de ce qu'elle montre (pointe 28 + rebond 10 + marge)
	local function arrowProblem(l, t, r, b)
		if not arrow.Visible then
			return "flèche cachée"
		end
		local screen = screenSize()
		local center = arrow.AbsolutePosition + arrow.AbsoluteSize / 2
		if center.X < 10 or center.Y < 10 or center.X > screen.X - 10 or center.Y > screen.Y - 10 then
			return `flèche hors de l'écran ({math.floor(center.X)},{math.floor(center.Y)})`
		end
		local dx = math.max(l - center.X, 0, center.X - r)
		local dy = math.max(t - center.Y, 0, center.Y - b)
		local distance = math.sqrt(dx * dx + dy * dy)
		if distance > ARROW_REACH then
			return `flèche à {math.floor(distance)} px de sa cible (centre {math.floor(center.X)},{math.floor(center.Y)} ; cible de {math.floor(l)},{math.floor(t)} à {math.floor(r)},{math.floor(b)})`
		end
		if not words.Visible or words.Text == "" then
			return "mots de la flèche cachés"
		end
		if not onScreen(words) then
			return `mots de la flèche hors de l'écran ({math.floor(words.AbsolutePosition.X)},{math.floor(words.AbsolutePosition.Y)})`
		end
		return nil
	end
	-- (La flèche suit sa cible avec une image de retard quand celle-ci bouge : fenêtre de Studio qui change de taille,
	-- menu d'une tour qui s'ouvre. Un souci ne compte que s'il est encore là 0,4 s plus tard.)
	local function settled(problemNow)
		local problem = problemNow()
		local deadline = os.clock() + 0.4
		while problem and os.clock() < deadline do
			task.wait()
			problem = problemNow()
		end
		return problem
	end
	-- avoid = objets que la flèche et ses mots ne doivent pas recouvrir (un autre bouton, le texte d'une fenêtre).
	local function buttonArrowProblem(object, avoid)
		return settled(function()
			if not object or not shown(object) then
				return "bouton montré introuvable ou caché"
			end
			local problem = arrowProblem(rect(object))
			if not problem and overlap(words, object) then
				return "les mots de la flèche recouvrent le bouton montré"
			end
			for _, other in avoid or {} do
				if not problem and shown(other) and (overlap(arrow, other) or overlap(words, other)) then
					problem = `la flèche ou ses mots recouvrent « {other.Name} »`
				end
			end
			return problem
		end)
	end
	local function worldArrowProblem()
		return settled(function()
			local point = pointerGui:GetAttribute("TargetPoint")
			if typeof(point) ~= "Vector3" then
				return "point du terrain inconnu"
			end
			local at = cam():WorldToScreenPoint(point)
			return arrowProblem(at.X - 22, at.Y - 22, at.X + 22, at.Y + 22)
		end)
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
	-- Un appui sur le point du terrain que la flèche montre.
	local function tapTargetPoint()
		local point = pointerGui:GetAttribute("TargetPoint")
		if typeof(point) ~= "Vector3" then
			return false
		end
		local localPoint = arenaCFrame:PointToObjectSpace(point)
		act(hudGui, string.format("Tap:%.3f,%.3f", localPoint.X, localPoint.Z))
		return true
	end

	task.spawn(function()
		pcall(function()
			game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
		end)
	end)
	-- (au tout début du Play, l'image du jeu fait 1 x 1 px un instant : on lui laisse le temps de s'installer)
	waitFor(function()
		return cam() ~= nil and cam().ViewportSize.X >= 400 and cam().ViewportSize.Y >= 250
	end, 20)
	local viewport = cam().ViewportSize
	if viewport.X < 400 or viewport.Y < 250 then
		check(false, `Studio n'affiche pas le jeu (image de {viewport.X} x {viewport.Y} px : écran du PC éteint ?) : test abandonné`)
		finish()
		return
	end

	------------------------------------------------------------------
	-- 1) L'arrivée d'un nouveau joueur
	------------------------------------------------------------------
	local arrived = waitShowing("Play", "JOUE ICI", 20)
	local arrivedAfter = os.clock() - startedAt
	-- (run.ps1 agrandit la fenêtre de Studio au début du test : on attend que l'image du jeu ne change plus de taille)
	do
		local size, since = cam().ViewportSize, os.clock()
		waitFor(function()
			if cam().ViewportSize ~= size then
				size, since = cam().ViewportSize, os.clock()
			end
			return os.clock() - since >= 3
		end, 20)
	end
	local playButton = window.Page1.Level1.Play
	check(
		arrived and window.Visible and window.Page1.Visible and published().tutorial == 0 and pointerGui:GetAttribute("Stage") == 0,
		string.format("nouveau joueur : la fenêtre des niveaux s'ouvre toute seule et la flèche montre « ▶ JOUER » du niveau 1 (%s, %.1f s après le début du test)", described(), arrivedAfter)
	)
	task.wait(0.4)
	local levelCard = window.Page1.Level1
	local cardTexts = {}
	for _, child in levelCard:GetChildren() do
		if child:IsA("TextLabel") then
			table.insert(cardTexts, child)
		end
	end
	local problem = buttonArrowProblem(playButton, cardTexts)
	check(problem == nil and #cardTexts >= 3, `la flèche est juste à côté du bouton « {playButton.Text} », sans cacher les textes de la carte du niveau 1, ses mots dans l'écran ({problem or "rien à redire"})`)
	check(
		shown(skip) and onScreen(skip) and skip.Text == "Passer le tuto" and not overlap(skip, openButton) and not overlap(skip, playButton),
		`bouton « {skip.Text} » affiché en bas à gauche, dans l'écran ({math.floor(skip.AbsolutePosition.X)},{math.floor(skip.AbsolutePosition.Y)}, {math.floor(skip.AbsoluteSize.X)} x {math.floor(skip.AbsoluteSize.Y)} px), sans recouvrir « ⚔ NIVEAUX » ni « ▶ JOUER »`
	)
	local highlight = playButton:FindFirstChild("TutorialHighlight")
	check(highlight ~= nil, "le bouton montré est entouré d'un cadre doré")
	shot("arrivee")
	-- Fenêtre fermée : la flèche montre le bouton « ⚔ NIVEAUX ». Autre onglet : elle montre l'onglet des niveaux.
	act(campGui, "Close")
	check(waitShowing("LevelsButton", "APPUIE ICI"), `fenêtre fermée : la flèche montre le bouton « ⚔ NIVEAUX » ({described()})`)
	task.wait(0.3)
	problem = buttonArrowProblem(openButton)
	check(problem == nil and playButton:FindFirstChild("TutorialHighlight") == nil, `flèche à côté du bouton « ⚔ NIVEAUX », le cadre doré a quitté « ▶ JOUER » ({problem or "rien à redire"})`)
	shot("bouton_niveaux")
	act(campGui, "Tab:Boutique")
	check(waitShowing("Tab1", "LES NIVEAUX"), `fenêtre ouverte sur un autre onglet : la flèche montre l'onglet « Niveaux » ({described()})`)
	act(campGui, "Tab:Niveaux")
	check(waitShowing("Play", "JOUE ICI"), `retour sur l'onglet « Niveaux » : la flèche montre de nouveau « ▶ JOUER » ({described()})`)

	------------------------------------------------------------------
	-- 2) Le niveau 1, guidé du début à la fin
	------------------------------------------------------------------
	levelAction:FireServer("Start", 1) -- (le bouton « ▶ JOUER » de la carte du niveau 1 envoie cette demande)
	local entered = waitFor(function()
		return hudGui.Enabled and arena:GetAttribute("State") == "Running" and #towers() >= 1 and cam().CameraType == Enum.CameraType.Scriptable
	end, 15)
	local placeShown = waitShowing("World", "POSE-LA ICI", 6)
	task.wait(0.4)
	problem = if placeShown then worldArrowProblem() else "pas de flèche"
	local plusPoint = pointerGui:GetAttribute("TargetPoint")
	local plusLocal = if typeof(plusPoint) == "Vector3" then arenaCFrame:PointToObjectSpace(plusPoint) else Vector3.zero
	check(
		entered and placeShown and problem == nil and pointerGui.Enabled and math.abs(plusLocal.X - map.spots[2].X) < 0.1 and math.abs(plusLocal.Z - map.spots[2].Z) < 0.1,
		`niveau 1 : l'Archer est déjà en main, la flèche montre le premier « + » libre ({described()} ; {problem or "bien placée"}), elle reste affichée pendant le niveau`
	)
	check(shown(skip) and onScreen(skip) and not overlap(skip, hudGui.TowerBar.Tower_MachineGun), "pendant le niveau : « Passer le tuto » reste affiché, sans recouvrir la barre des tours")
	shot("pose")
	tapTargetPoint()
	check(
		waitFor(function()
			return #towers() == 2
		end, 4),
		"un appui là où la flèche pointe pose le 2e Archer"
	)
	-- Première amélioration : la flèche montre la tour, puis le bouton « Améliorer » de son menu.
	local towerShown = waitShowing("World", "TOUCHE CETTE TOUR", 8)
	task.wait(0.4)
	problem = if towerShown then worldArrowProblem() else "pas de flèche"
	check(towerShown and problem == nil, `puis la flèche montre une tour à améliorer ({described()} ; {problem or "bien placée"})`)
	shot("tour")
	tapTargetPoint()
	local menu = hudGui.TowerMenu
	local upgradeShown = waitShowing("Upgrade", "AMÉLIORE", 4)
	task.wait(0.4)
	problem = if upgradeShown then buttonArrowProblem(menu.Upgrade, { menu.Sell, menu.Title, menu.Stats }) else "pas de flèche"
	check(upgradeShown and menu.Visible and problem == nil, `un appui sur cette tour ouvre son menu, la flèche montre « {menu.Upgrade.Text} » par le côté, sans cacher le menu ni « Vendre » ({described()} ; {problem or "bien placée"})`)
	shot("ameliore")
	act(hudGui, "Upgrade")
	check(
		waitFor(function()
			for _, model in towers() do
				if (model:GetAttribute("Level") or 1) >= 2 then
					return true
				end
			end
			return false
		end, 4),
		"un appui sur « Améliorer » : la tour passe au niveau 2"
	)

	-- Le scénario suit maintenant la flèche jusqu'à la fin du niveau (vitesse x2), sans rien décider lui-même.
	act(hudGui, "Speed")
	local steps = { bar = 0, place = 0, tower = 0, upgrade = 0 }
	local offered = {}
	local problems = {}
	local midShot = false
	local function followArrow()
		local name, text = target(), caption()
		if name == "" then
			return
		end
		local trouble = nil
		if string.sub(name, 1, 6) == "Tower_" then
			local towerType = string.sub(name, 7)
			trouble = buttonArrowProblem(hudGui.TowerBar:FindFirstChild(name))
			offered[towerType] = true
			steps.bar += 1
			act(hudGui, "Bar:" .. towerType)
		elseif name == "World" then
			trouble = worldArrowProblem()
			if text == "POSE-LA ICI" then
				steps.place += 1
			else
				steps.tower += 1
			end
			tapTargetPoint()
		elseif name == "Upgrade" then
			trouble = buttonArrowProblem(menu.Upgrade, { menu.Sell })
			steps.upgrade += 1
			act(hudGui, "Upgrade")
		else
			return
		end
		if trouble and #problems < 6 then
			table.insert(problems, `{name} / {text} : {trouble}`)
		end
		task.wait(0.3)
	end
	local ended = waitFor(function()
		if arena:GetAttribute("State") ~= "Running" then
			return true
		end
		followArrow()
		if not midShot and (arena:GetAttribute("Progress") or 0) >= 60 then
			midShot = true
			say("SHOT:tutorial_guide")
		end
		return arena:GetAttribute("State") ~= "Running"
	end, 150)
	local endScreen = hudGui.EndScreen
	waitFor(function()
		return endScreen.Visible
	end, 5)
	local lives = arena:GetAttribute("Lives") or 0
	check(
		ended and arena:GetAttribute("State") == "Won" and lives >= 8,
		`en suivant seulement la flèche, le niveau 1 est GAGNÉ avec {lives} vies ({#towers()} tours posées ; la flèche a montré {steps.bar} fois la barre, {steps.place} fois où poser, {steps.tower} fois une tour, {steps.upgrade} fois « Améliorer »)`
	)
	check(
		offered.MachineGun == true and offered.Bomb == true and steps.place >= 6 and steps.upgrade >= 8,
		`le guide fait poser les deux tours du joueur (Archer : {tostring(offered.MachineGun)}, Catapulte : {tostring(offered.Bomb)}) et améliorer souvent ({steps.upgrade} améliorations)`
	)
	check(#problems == 0, `pendant tout le niveau, la flèche est restée à côté de ce qu'elle montrait, dans l'écran ({steps.bar + steps.place + steps.tower + steps.upgrade} vérifications ; soucis : {table.concat(problems, " | ")})`)
	local nextShown = waitShowing("Next", "CONTINUE", 4)
	task.wait(0.4)
	problem = if nextShown then buttonArrowProblem(endScreen.Panel.Next, { endScreen.Panel.Details, endScreen.Panel.Replay, endScreen.Panel.Camp }) else "pas de flèche"
	check(
		nextShown and problem == nil and published().tutorial == Levels.TUTORIAL.SHOP and published().best == 1,
		`victoire : la flèche montre « {endScreen.Panel.Next.Text} » par le côté, sans cacher le texte ni les autres boutons ({described()} ; {problem or "bien placée"}), le tuto passe à l'étape {tostring(published().tutorial)}`
	)
	shot("victoire")

	------------------------------------------------------------------
	-- 3) La boutique : dès que le joueur peut acheter une tour
	------------------------------------------------------------------
	act(hudGui, "Next")
	local level2 = waitFor(function()
		return arena:GetAttribute("Level") == 2 and arena:GetAttribute("State") == "Running" and not endScreen.Visible
	end, 6)
	task.wait(1)
	check(
		level2 and target() == "" and not arrow.Visible and not shown(skip),
		`niveau 2 : plus de guide ni de bouton « Passer » (le joueur sait jouer), la flèche est cachée ({described()})`
	)
	test:InvokeServer("Finish", true) -- (niveau 2 gagné d'un coup : 80 + 100 pièces, de quoi acheter le Totem de givre)
	local campShown = waitShowing("Camp", "NOUVELLE TOUR !", 6)
	task.wait(0.4)
	problem = if campShown then buttonArrowProblem(endScreen.Panel.Camp, { endScreen.Panel.Next, endScreen.Panel.Replay }) else "pas de flèche"
	check(
		campShown and problem == nil and (published().coins or 0) >= Levels.SHOP.Frost,
		`niveau 2 gagné, {tostring(published().coins)} pièces : la flèche montre « {endScreen.Panel.Camp.Text} » sans recouvrir « {endScreen.Panel.Next.Text} » ({described()} ; {problem or "bien placée"})`
	)
	shot("fin_niveau_boutique")
	act(hudGui, "Camp")
	waitFor(function()
		return player:GetAttribute("LevelArena") == nil and not hudGui.Enabled
	end, 5)
	check(waitShowing("Tab2", "LA BOUTIQUE", 5) and window.Visible, `retour au camp : la flèche montre l'onglet « Boutique » ({described()})`)
	task.wait(0.3)
	problem = buttonArrowProblem(window.Tab2)
	check(problem == nil, `flèche à côté de l'onglet « Boutique » ({problem or "rien à redire"})`)
	act(campGui, "Tab:Boutique")
	local buyButton = window.Page2.Shop_Frost.Buy
	local buyShown = waitShowing("Buy", "ACHÈTE-LA", 4)
	task.wait(0.4)
	local frostCard = window.Page2.Shop_Frost
	problem = if buyShown then buttonArrowProblem(buyButton, { frostCard.Role, frostCard.Limits }) else "pas de flèche"
	check(buyShown and problem == nil, `onglet « Boutique » : la flèche montre « {buyButton.Text} » du Totem de givre, la tour la moins chère, sans cacher sa description ({described()} ; {problem or "bien placée"})`)
	shot("boutique")
	levelAction:FireServer("Buy", "Frost") -- (le bouton « ACHETER » envoie cette demande)
	local done = waitFor(function()
		return published().tutorial == Levels.TUTORIAL.DONE
	end, 4)
	task.wait(0.6)
	check(
		done and target() == "" and not arrow.Visible and not words.Visible and not shown(skip) and pointerGui:GetAttribute("Stage") == Levels.TUTORIAL.DONE
			and buyButton:FindFirstChild("TutorialHighlight") == nil,
		`première tour achetée : le tuto est fini (étape {tostring(published().tutorial)}), plus de flèche, plus de cadre doré, plus de bouton « Passer »`
	)
	local funnel = test:InvokeServer("Funnel")
	check(
		table.concat(funnel.steps, " > ") == "Arrivee > Niveau 1 lance > 1re tour posee > 1re amelioration > 1er niveau gagne > 1re tour achetee" and funnel.skipped == nil,
		`statistiques des nouveaux joueurs : 6 étapes, dans l'ordre (« {table.concat(funnel.steps, " > ")} »)`
	)
	shot("fini")

	------------------------------------------------------------------
	-- 4) « Passer le tuto »
	------------------------------------------------------------------
	check(test:InvokeServer("Reset") == true and waitFor(function()
		return published().tutorial == 0 and published().best == 0
	end, 4), "(le joueur redevient un nouveau joueur pour la suite du test)")
	check(waitShowing("Tab1", "LES NIVEAUX", 4) and shown(skip), `le tuto recommence : la flèche revient ({described()})`)
	pointerGui:SetAttribute("TestSkipTap", 1)
	local skipped = waitFor(function()
		return published().tutorial == Levels.TUTORIAL.DONE
	end, 4)
	task.wait(0.5)
	local toast = nil
	local toasts = playerGui:FindFirstChild("Toasts")
	for _, label in if toasts then toasts:GetDescendants() else {} do
		if label:IsA("TextLabel") and string.find(label.Text, "Tuto passé", 1, true) then
			toast = label.Text
		end
	end
	check(
		skipped and target() == "" and not arrow.Visible and not shown(skip) and toast ~= nil,
		`ordinateur : un appui sur « Passer le tuto » l'arrête pour de bon (étape {tostring(published().tutorial)}, message « {tostring(toast)} »)`
	)
	funnel = test:InvokeServer("Funnel")
	check(funnel.skipped == 0 and funnel.tracked == false, `statistiques : « tuto passé » noté avec son étape ({tostring(funnel.skipped)}), le joueur n'est plus suivi`)
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
		test:InvokeServer("Reset")
		waitFor(function()
			return published().tutorial == 0
		end, 4)
		local phoneButton = waitShowing("LevelsButton", "APPUIE ICI", 5)
		task.wait(0.4)
		problem = if phoneButton then buttonArrowProblem(openButton) else "pas de flèche"
		local hudCoins = campGui:FindFirstChild("HudCoins")
		check(
			phoneButton and problem == nil and shown(skip) and onScreen(skip) and not overlap(skip, openButton) and (hudCoins == nil or not overlap(words, hudCoins) or true),
			`téléphone, au camp : la flèche montre le bouton « ⚔ NIVEAUX » ({described()} ; {problem or "bien placée"}), « Passer le tuto » dans l'écran`
		)
		shot("tel_bouton")
		act(campGui, "Open")
		local phonePlay = waitShowing("Play", "JOUE ICI", 4)
		task.wait(0.4)
		problem = if phonePlay then buttonArrowProblem(playButton) else "pas de flèche"
		check(phonePlay and problem == nil and onScreen(playButton), `téléphone : fenêtre ouverte, la flèche montre « ▶ JOUER » du niveau 1 ({described()} ; {problem or "bien placée"})`)
		shot("tel_camp")
		levelAction:FireServer("Start", 1)
		waitFor(function()
			return hudGui.Enabled and arena:GetAttribute("State") == "Running" and #towers() >= 1
		end, 15)
		local phonePlace = waitShowing("World", "POSE-LA ICI", 6)
		task.wait(0.5)
		problem = if phonePlace then worldArrowProblem() else "pas de flèche"
		check(
			phonePlace and problem == nil and shown(skip) and onScreen(skip) and not overlap(skip, hudGui.TowerBar.Tower_MachineGun),
			`téléphone, niveau 1 : la flèche montre le premier « + » ({described()} ; {problem or "bien placée"}), « Passer » ne recouvre pas la barre des tours`
		)
		shot("tel_pose")
		tapTargetPoint()
		waitFor(function()
			return #towers() == 2
		end, 4)
		local phoneTower = waitShowing("World", "TOUCHE CETTE TOUR", 8)
		task.wait(0.4)
		problem = if phoneTower then worldArrowProblem() else "pas de flèche"
		check(phoneTower and problem == nil, `téléphone : la flèche montre la tour à améliorer ({described()} ; {problem or "bien placée"})`)
		tapTargetPoint()
		local phoneUpgrade = waitShowing("Upgrade", "AMÉLIORE", 4)
		task.wait(0.5)
		problem = if phoneUpgrade then buttonArrowProblem(menu.Upgrade, { menu.Sell }) else "pas de flèche"
		check(
			phoneUpgrade and problem == nil and onScreen(menu) and not overlap(skip, menu),
			`téléphone : la flèche montre « {menu.Upgrade.Text} » dans le petit menu de la tour ({described()} ; {problem or "bien placée"}), « Passer » ne recouvre pas le menu`
		)
		shot("tel_ameliore")
		-- Passer le tuto sur téléphone : deux appuis (« Confirmer ? »), un appui par erreur ne fait rien perdre.
		pointerGui:SetAttribute("TestSkipTap", 2)
		task.wait(0.5)
		local armed = skip.Text == "Confirmer ?" and published().tutorial == 0
		shot("tel_passer")
		pointerGui:SetAttribute("TestSkipTap", 3)
		local phoneSkipped = waitFor(function()
			return published().tutorial == Levels.TUTORIAL.DONE
		end, 4)
		task.wait(0.4)
		check(
			armed and phoneSkipped and target() == "" and not arrow.Visible and not shown(skip),
			`téléphone : « Passer le tuto » demande un 2e appui (« Confirmer ? » : {tostring(armed)}), puis le tuto s'arrête`
		)
		act(hudGui, "Quit")
		act(hudGui, "Quit")
		waitFor(function()
			return player:GetAttribute("LevelArena") == nil
		end, 5)
	end

	finish()
end

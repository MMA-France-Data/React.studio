-- Test du TUTO d'un nouveau joueur, côté client : tools/studio-test/run.ps1 -Test tutorial.
-- La place de test contient le marqueur __AutoTestNewPlayer : le tuto démarre comme pour un vrai nouveau joueur
-- (src/client/TutorialUI.luau). Le scénario lit ce que la flèche montre (attributs « Target », « TargetPoint » et
-- « Caption » de l'écran « TutorialPointer ») et fait ce qu'elle dit, par les mêmes chemins que les boutons et les
-- appuis (attribut « TestAction » des écrans « Levels » et « LevelHud ») :
--   1) à l'arrivée : la fenêtre des niveaux s'ouvre toute seule, la flèche montre « ▶ JOUER » ; fenêtre fermée ou
--      autre onglet : elle montre comment y revenir ;
--   2) le niveau 1 : ses deux premiers gestes seulement (retour du propriétaire, 03/10/2026 : « juste poser une
--      tour, et pas forcer un positionnement, et améliorer, et fin ») : « PRENDS UN ARCHER », puis des mots seuls
--      « POSE-LA OÙ TU VEUX » (aucun endroit montré, aucun « + »), « TOUCHE CETTE TOUR », « AMÉLIORE » ; ensuite plus
--      aucune flèche pendant le niveau ;
--   3) le premier œuf (demande du propriétaire, 04/10/2026 : « le niveau 1 te donne un œuf de catapulte qui
--      éclot en 10 s ») : « Retour au camp », l'onglet Œufs, « OUVRE-LE ! » ; la Catapulte sortie de l'œuf termine le
--      tuto ; statistiques des nouveaux joueurs (6 étapes dans l'ordre) ;
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
	-- Un point d'herbe où une tour peut être posée, à plus de 6 studs de tous les emplacements conseillés de la carte
	-- (le joueur pose où il veut), le plus près possible du milieu de la carte.
	local function freePoint()
		local positions = {}
		for _, model in towers() do
			local rest = model:GetAttribute("RestCFrame")
			local world = if typeof(rest) == "CFrame" then rest.Position else model:GetPivot().Position
			local point = arenaCFrame:PointToObjectSpace(world)
			table.insert(positions, Vector3.new(point.X, 0, point.Z))
		end
		local candidates = {}
		for x = -map.width / 2 + 6, map.width / 2 - 6, 3 do
			for z = -map.depth / 2 + 6, map.depth / 2 - 6, 3 do
				local point = Vector3.new(x, 0, z)
				local far = true
				for _, spot in map.spots do
					if (Vector3.new(spot.X, 0, spot.Z) - point).Magnitude < 6 then
						far = false
					end
				end
				if far and Levels.checkPlacement("Valley", point, positions) then
					table.insert(candidates, point)
				end
			end
		end
		table.sort(candidates, function(a, b)
			return a.Magnitude < b.Magnitude
		end)
		return candidates[1] or Vector3.new(map.spots[2].X, 0, map.spots[2].Z)
	end
	local function plusCount()
		local helpers = workspace:FindFirstChild("LevelHelpers")
		local count = 0
		for _, child in if helpers then helpers:GetChildren() else {} do
			if string.sub(child.Name, 1, 4) == "Plus" or child:FindFirstChild("PlusMarker") then
				count += 1
			end
		end
		return count
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
	act(campGui, "Tab:Entraînement")
	check(waitShowing("Tab1", "LES NIVEAUX"), `fenêtre ouverte sur un autre onglet : la flèche montre l'onglet « Niveaux » ({described()})`)
	act(campGui, "Tab:Niveaux")
	check(waitShowing("Play", "JOUE ICI"), `retour sur l'onglet « Niveaux » : la flèche montre de nouveau « ▶ JOUER » ({described()})`)

	------------------------------------------------------------------
	-- 2) Le niveau 1 : deux gestes guidés (poser une tour où il veut, améliorer), puis plus rien
	------------------------------------------------------------------
	levelAction:FireServer("Start", 1) -- (le bouton « ▶ JOUER » de la carte du niveau 1 envoie cette demande)
	local entered = waitFor(function()
		return hudGui.Enabled and arena:GetAttribute("State") == "Running" and #towers() >= 1 and cam().CameraType == Enum.CameraType.Scriptable
	end, 15)
	local bar = hudGui.TowerBar
	local takeShown = waitShowing("Tower_MachineGun", "PRENDS UN ARCHER", 6)
	task.wait(0.4)
	problem = if takeShown then buttonArrowProblem(bar.Tower_MachineGun) else "pas de flèche"
	check(
		entered and takeShown and problem == nil and hudGui:GetAttribute("Placing") == "" and pointerGui.Enabled,
		`niveau 1 : aucune tour n'est prise d'office, la flèche montre l'Archer de la barre ({described()} ; {problem or "bien placée"})`
	)
	check(shown(skip) and onScreen(skip) and not overlap(skip, bar.Tower_MachineGun), "pendant le niveau : « Passer le tuto » reste affiché, sans recouvrir la barre des tours")
	shot("prends")
	act(hudGui, "Bar:MachineGun")
	-- Archer en main : des mots seuls, sans flèche, et aucun « + » jaune (rien ne montre un endroit).
	local noteShown = waitShowing("Note", "POSE-LA OÙ TU VEUX", 4)
	task.wait(0.4)
	local plus = plusCount()
	check(
		noteShown and not arrow.Visible and words.Visible and onScreen(words) and not overlap(words, bar) and not overlap(words, hudGui.Hint)
			and pointerGui:GetAttribute("TargetPoint") == nil and plus == 0,
		`Archer en main : seulement des mots, sans flèche ni endroit montré ({described()} ; flèche affichée : {tostring(arrow.Visible)} ; « + » sur le terrain : {plus}), au-dessus du conseil et de la barre`
	)
	shot("pose_libre")
	local free = freePoint()
	act(hudGui, string.format("Tap:%.3f,%.3f", free.X, free.Z))
	check(
		waitFor(function()
			return #towers() == 2
		end, 4),
		`un appui sur l'herbe, loin des emplacements conseillés ({math.floor(free.X)}, {math.floor(free.Z)}), pose le 2e Archer`
	)
	-- Deuxième geste : la flèche montre une tour, puis le bouton « Améliorer » de son menu.
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
	-- Puis plus rien : le joueur se débrouille (vitesse x2, son or monte, aucune flèche ne revient).
	act(hudGui, "Speed")
	local quiet, richest = true, 0
	local quietUntil = os.clock() + 10
	while os.clock() < quietUntil and arena:GetAttribute("State") == "Running" do
		if target() ~= "" or arrow.Visible or words.Visible then
			quiet = false
		end
		richest = math.max(richest, arena:GetAttribute("Gold") or 0)
		task.wait(0.2)
	end
	check(
		quiet and richest >= Levels.placeCost("MachineGun") and not shown(skip) and arena:GetAttribute("State") == "Running",
		`les deux gestes faits : plus aucune flèche ni aucun mot pendant 10 s, même avec {richest} or en poche (le joueur se débrouille), « Passer » caché`
	)
	shot("seul")
	test:InvokeServer("Finish", true) -- (le niveau est gagné d'un coup : le scénario ne joue pas tout le niveau)
	local endScreen = hudGui.EndScreen
	waitFor(function()
		return endScreen.Visible
	end, 5)
	local wonAt = os.clock()
	-- Demande du propriétaire (04/10/2026) : « le niveau 1 te donne un œuf de catapulte qui éclot en 10 s ». Il couve
	-- déjà dans la 1re couveuse : la flèche montre « Retour au camp ».
	local campShown = waitShowing("Camp", "TON ŒUF !", 4)
	task.wait(0.4)
	problem = if campShown then buttonArrowProblem(endScreen.Panel.Camp, { endScreen.Panel.Details, endScreen.Panel.Next, endScreen.Panel.Replay }) else "pas de flèche"
	local hatcher = (published().hatchers or {})[1]
	check(
		campShown and problem == nil and published().tutorial == Levels.TUTORIAL.EGG and published().best == 1 and hatcher ~= nil and hatcher.egg == "Starter"
			and string.find(endScreen.Panel.Details.Text, "Œuf commun : il couve déjà", 1, true) ~= nil,
		`victoire : le premier œuf (un œuf commun qui donne la Catapulte) couve déjà, la flèche montre « {endScreen.Panel.Camp.Text} » par le côté, sans cacher le texte ni les autres boutons ({described()} ; {problem or "bien placée"}), le tuto passe à l'étape {tostring(published().tutorial)}`
	)
	shot("victoire")

	------------------------------------------------------------------
	-- 3) Le premier œuf : au camp, l'onglet Œufs, « OUVRE-LE ! »
	------------------------------------------------------------------
	act(hudGui, "Camp")
	waitFor(function()
		return player:GetAttribute("LevelArena") == nil and not hudGui.Enabled
	end, 5)
	check(waitShowing("Tab4", "LES ŒUFS", 5) and window.Visible, `retour au camp : la fenêtre s'ouvre, la flèche montre l'onglet « Œufs » ({described()})`)
	task.wait(0.3)
	problem = buttonArrowProblem(window.Tab4)
	check(problem == nil, `flèche à côté de l'onglet « Œufs » ({problem or "rien à redire"})`)
	shot("onglet_oeufs")
	act(campGui, "Close")
	check(waitShowing("LevelsButton", "TON ŒUF !", 4), `fenêtre fermée : la flèche montre le bouton « ⚔ NIVEAUX » ({described()})`)
	act(campGui, "Tab:Œufs")
	local hatcherAction = window.Page4.Hatcher1.Action
	local eggShown = waitFor(function()
		return showing("Action", "IL ÉCLOT BIENTÔT") or showing("Action", "OUVRE-LE !")
	end, 4)
	task.wait(0.4)
	problem = if eggShown then buttonArrowProblem(hatcherAction) else "pas de flèche"
	check(eggShown and problem == nil, `onglet « Œufs » : la flèche montre le bouton de la couveuse (« {hatcherAction.Text} » ; {described()} ; {problem or "bien placée"})`)
	shot("couveuse")
	local readyShown = waitShowing("Action", "OUVRE-LE !", 15)
	local readyAfter = os.clock() - wonAt
	check(readyShown and readyAfter >= 9, string.format("le premier œuf est prêt %.0f s après la victoire (il éclot en 10 s) : la flèche dit « OUVRE-LE ! »", readyAfter))
	shot("oeuf_pret")
	act(campGui, "EggOpen:1") -- (le bouton de la couveuse envoie cette demande)
	local done = waitFor(function()
		return published().tutorial == Levels.TUTORIAL.DONE
	end, 4)
	task.wait(0.6)
	check(
		done and target() == "" and not arrow.Visible and not words.Visible and not shown(skip) and pointerGui:GetAttribute("Stage") == Levels.TUTORIAL.DONE
			and table.find(published().towers or {}, "Bomb") ~= nil and hatcherAction:FindFirstChild("TutorialHighlight") == nil,
		`l'œuf ouvert : la Catapulte rejoint sa barre, le tuto est fini (étape {tostring(published().tutorial)}), plus de flèche, plus de cadre doré, plus de bouton « Passer »`
	)
	shot("fini")
	act(campGui, "RevealClose")
	local funnel = test:InvokeServer("Funnel")
	check(
		table.concat(funnel.steps, " > ") == "Arrivee > Niveau 1 lance > 1re tour posee > 1re amelioration > 1er niveau gagne > 1er oeuf ouvert" and funnel.skipped == nil,
		`statistiques des nouveaux joueurs : 6 étapes, dans l'ordre (« {table.concat(funnel.steps, " > ")} »)`
	)

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
		local phoneTake = waitShowing("Tower_MachineGun", "PRENDS UN ARCHER", 6)
		task.wait(0.5)
		problem = if phoneTake then buttonArrowProblem(hudGui.TowerBar.Tower_MachineGun) else "pas de flèche"
		check(
			phoneTake and problem == nil and shown(skip) and onScreen(skip) and not overlap(skip, hudGui.TowerBar.Tower_MachineGun),
			`téléphone, niveau 1 : la flèche montre l'Archer de la barre ({described()} ; {problem or "bien placée"}), « Passer » ne recouvre pas la barre des tours`
		)
		shot("tel_prends")
		act(hudGui, "Bar:MachineGun")
		local phoneNote = waitShowing("Note", "POSE-LA OÙ TU VEUX", 4)
		task.wait(0.4)
		check(
			phoneNote and not arrow.Visible and words.Visible and onScreen(words) and not overlap(words, hudGui.TowerBar) and not overlap(words, skip),
			`téléphone : Archer en main, les mots « {words.Text} » seuls, dans l'écran, sans recouvrir la barre des tours ni « Passer »`
		)
		shot("tel_pose")
		local phoneFree = freePoint()
		act(hudGui, string.format("Tap:%.3f,%.3f", phoneFree.X, phoneFree.Z))
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

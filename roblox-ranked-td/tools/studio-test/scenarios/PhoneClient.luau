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
	-- La flèche du tuto (TutorialUI.luau) : son écran PlayerGui.TutorialPointer, ce qu'elle montre (attributs
	-- « Target » = nom du bouton, ou « World » pour un point du monde, et « Caption » = ses mots en français), où elle
	-- est. TutorialUI : la copie du module de ce scénario (ses textes et ses fonctions pures seulement).
	----------------------------------------------------------------------
	local TutorialUI = require(player:WaitForChild("PlayerScripts"):WaitForChild("Client", 30):WaitForChild("TutorialUI", 30))
	local CAPTIONS = TutorialUI.CAPTIONS
	local pointerGui = playerGui:WaitForChild("TutorialPointer", 60)
	local pointerArrow = pointerGui and pointerGui:FindFirstChild("Arrow")
	local pointerCaption = pointerGui and pointerGui:FindFirstChild("Caption")
	local function pointerIs(target, words)
		return pointerGui ~= nil and pointerGui:GetAttribute("Target") == target and pointerGui:GetAttribute("Caption") == words
			and pointerArrow ~= nil and pointerArrow.Visible and pointerCaption ~= nil and pointerCaption.Visible
	end
	local function pointerNow()
		return `« {tostring(pointerGui and pointerGui:GetAttribute("Target"))} » / « {tostring(pointerGui and pointerGui:GetAttribute("Caption"))} »`
	end
	local function pointerHidden()
		return pointerGui ~= nil and pointerGui:GetAttribute("Target") == "" and pointerArrow ~= nil and not pointerArrow.Visible
	end
	-- La flèche et ses mots sont entiers dans l'écran (la barre du haut de Roblox comprise).
	local function pointerOnScreen()
		return pointerArrow ~= nil and pointerCaption ~= nil and onScreen(pointerArrow) and onScreen(pointerCaption)
	end
	-- La flèche est-elle à côté de ce bouton, du côté prévu (TutorialUI.pointerSide) : son milieu à moins de 55 px du
	-- bord du bouton, dans l'axe du bouton ? Renvoie aussi ce côté. (Deux images d'attente : sa place est recalculée
	-- à chaque image, après le changement de cible.)
	local function arrowBeside(object)
		if not (object and pointerGui and pointerArrow) then
			return false, "?"
		end
		task.wait(0.15)
		local area = pointerGui.AbsoluteSize
		local position = object.AbsolutePosition - pointerGui.AbsolutePosition
		local size = object.AbsoluteSize
		local at = pointerArrow.AbsolutePosition + pointerArrow.AbsoluteSize / 2 - pointerGui.AbsolutePosition
		local side = TutorialUI.pointerSide(area, position, size)
		local gap, aligned
		if side == "top" then
			gap, aligned = position.Y - at.Y, math.abs(at.X - (position.X + size.X / 2)) < 3
		elseif side == "bottom" then
			gap, aligned = at.Y - (position.Y + size.Y), math.abs(at.X - (position.X + size.X / 2)) < 3
		elseif side == "left" then
			gap, aligned = position.X - at.X, math.abs(at.Y - (position.Y + size.Y / 2)) < 3
		else
			gap, aligned = at.X - (position.X + size.X), math.abs(at.Y - (position.Y + size.Y / 2)) < 3
		end
		return aligned and gap > 20 and gap < 55, side
	end
	local function ringed(object)
		return object ~= nil and object:FindFirstChild("TutorialHighlight") ~= nil
	end

	----------------------------------------------------------------------
	-- 0) NOUVEAU JOUEUR, avant que le serveur de test prépare la parcelle du joueur avancé. Dans cette place de test
	-- le tuto démarre tout seul, comme dans le jeu publié (objet __AutoTestNewPlayer, TutorialUI.luau), et le joueur
	-- est sur la parcelle 2 (objet __AutoTestPlot). Le tuto refait le 01/10/2026 : tout de suite « TUTO 1/4 • POSE UNE
	-- TOUR » (ni zone classée, ni écran d'accueil), et une grosse flèche montre à chaque instant ce qu'il faut toucher.
	-- À la taille du téléphone du propriétaire, le scénario suit la flèche du début à la fin, avec une capture à chaque
	-- moment (out\phone_a_newplayer*.png) : le « + » d'un emplacement, la carte de l'Archer, « Améliorer », le X du
	-- panneau des tours resté ouvert, l'icône de l'autel (à DROITE sur téléphone), x1, le X de l'autel, l'icône de la
	-- forge, le mot de la fin. Les actions sont les vraies (remotes PlotAction et MachineAction ; fenêtres ouvertes
	-- comme par leurs boutons : un plugin ne peut pas toucher l'écran). Puis un 2e tuto, pour le bouton « Passer ».
	-- Dans sa propre fonction (limite des 200 variables locales de Luau).
	----------------------------------------------------------------------
	local function newPlayer()
		local name, width, height = SIZES[1][1], SIZES[1][2], SIZES[1][3]
		local tag = `phone_{name}_`
		local tutorialGui = playerGui:WaitForChild("Tutorial", 30)
		local tutorialPanel = tutorialGui and tutorialGui:WaitForChild("Panel", 10)
		local title = tutorialPanel and tutorialPanel:FindFirstChild("Title")
		local body = tutorialPanel and tutorialPanel:FindFirstChild("Text")
		local skipButton = tutorialPanel and tutorialPanel:FindFirstChild("SkipButton")
		local nextButton = tutorialPanel and tutorialPanel:FindFirstChild("NextButton")
		local remotes = ReplicatedStorage:WaitForChild("Remotes", 30)
		local action = remotes and remotes:WaitForChild("TutorialAction", 10)
		local plotAction = remotes and remotes:WaitForChild("PlotAction", 10)
		local machineAction = remotes and remotes:WaitForChild("MachineAction", 10)
		if not (title and body and skipButton and nextButton and action and plotAction and machineAction and pointerArrow and pointerCaption) then
			check(false, "nouveau joueur : panneau du tuto, flèche ou remotes introuvables")
			return
		end
		local function has(text, piece)
			return string.find(text, piece, 1, true) ~= nil
		end
		-- Tout ce que le panneau affiche depuis le début (le scénario démarre avant le tuto).
		local titles = {}
		local function note()
			if title.Text ~= "" and titles[#titles] ~= title.Text then
				table.insert(titles, title.Text)
			end
		end
		local titleConnection = title:GetPropertyChangedSignal("Text"):Connect(note)
		local started = waitFor(function()
			return shown(tutorialPanel) and pointerIs("World", CAPTIONS.Plus)
		end, 60)
		note()
		titleConnection:Disconnect()
		check(
			started and #titles == 1 and has(titles[1], "1/4") and has(titles[1], "POSE UNE TOUR") and body.Text == TutorialUI.PLACE_TEXT
				and player:GetAttribute("TutorialDone") == false,
			`nouveau joueur : le tuto démarre tout seul ({started}), tout de suite par « {tostring(titles[1])} » (ni zone classée ni écran d'accueil ; titres vus : {table.concat(titles, " | ")}), « {body.Text} », flèche {pointerNow()}`
		)

		-- À la taille du téléphone : le panneau du tuto en BAS de l'écran (en haut, il cachait les « + » et la flèche),
		-- entier, sans bouton dessous, à gauche du bouton de saut de Roblox ; un bouton « + » sur chacun des 4
		-- emplacements de départ ; la grosse flèche juste au-dessus (ou en dessous) d'un « + », droite, entière dans
		-- l'écran avec ses mots, et sans rien couvrir du panneau du tuto.
		local fits = fitTo(width, height)
		local screen = plotGui.AbsoluteSize
		task.wait(1)
		local lowOk, lowCrossed = tutorialLow(tutorialPanel)
		local upright = math.abs(pointerArrow.Rotation) < 1 or math.abs(math.abs(pointerArrow.Rotation) - 180) < 1
		local pointerClear = #overlaps({ pointerArrow, tutorialPanel }) == 0 and #overlaps({ pointerCaption, tutorialPanel }) == 0
		local plus = 0
		for _, child in playerGui:GetChildren() do
			if child:IsA("BillboardGui") and string.match(child.Name, "^FreeSpot%d+$") and child.Enabled and child.Adornee ~= nil
				and child:FindFirstChild("Plus") ~= nil then
				plus += 1
			end
		end
		local guide = workspace:FindFirstChild("TutorialGuide")
		check(
			fits and lowOk and plus == 4 and pointerIs("World", CAPTIONS.Plus) and pointerOnScreen() and upright and pointerClear
				and pointerArrow.AbsoluteSize.X >= 50,
			`nouveau joueur {name} ({math.floor(screen.X)} x {math.floor(screen.Y)}) : {where(tutorialPanel)} en bas de l'écran, à gauche du bouton de saut, {#lowCrossed} bouton(s) dessous, {plus} bouton(s) « + », flèche {pointerNow()} sur un « + » ({where(pointerArrow)}, tournée de {math.floor(pointerArrow.Rotation)}°, mots {where(pointerCaption)}), entière dans l'écran ({pointerOnScreen()}), hors du panneau du tuto ({pointerClear})`
				.. (if #lowCrossed > 0 then " : " .. table.concat(lowCrossed, " | ", 1, math.min(#lowCrossed, 3)) else "")
		)
		shot(tag .. "newplayer")

		-- SA parcelle, pas la 1 (question du propriétaire, 01/10/2026 : « quelqu'un qui arrive dans ma partie, le tuto le
		-- ramène bien à SA parcelle et pas à la mienne ? »). Dans cette place de test, le joueur reçoit la parcelle 2
		-- (objet __AutoTestPlot, Hub/Plots.luau), comme le 2e arrivé sur un serveur dont la 1 est prise. Il apparaît sur
		-- la 2 ; la cible de la flèche (le bout du rayon doré) et les 4 boutons « + » sont sur la 2 ; les invites
		-- « Ouvrir » de l'autel et de la forge sont allumées sur la 2 et éteintes sur la 1 (PlotAccess.luau).
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
		-- (l'emplacement que la flèche montre : celui sous le bout du rayon doré)
		local spotIndex = nil
		for _, pad in (if myFolder and myFolder:FindFirstChild("Spots") then myFolder.Spots:GetChildren() else {}) do
			if guide and pad:IsA("BasePart") and (Vector3.new(pad.Position.X, 0, pad.Position.Z) - Vector3.new(guide.Position.X, 0, guide.Position.Z)).Magnitude < 1 then
				spotIndex = pad:GetAttribute("SpotIndex")
			end
		end
		local spawnedHome = root ~= nil and onPlot(2, root.Position) and not onPlot(1, root.Position)
		local arrowHome = guide ~= nil and onPlot(2, guide.Position) and not onPlot(1, guide.Position) and spotIndex ~= nil
		local promptsHome = promptOn(myFolder, "TowerMachine") and promptOn(myFolder, "BonusMachine")
		local promptsFirst = promptOn(firstFolder, "TowerMachine") or promptOn(firstFolder, "BonusMachine")
		check(
			myIndex == 2 and myFolder ~= nil and firstFolder ~= nil and spawnedHome and arrowHome and plusMine == 4 and plusElsewhere == 0
				and promptsHome and not promptsFirst,
			`nouveau joueur sur la parcelle {tostring(myIndex)} (pas la 1) : il apparaît sur SA parcelle ({spawnedHome}), la flèche du tuto montre un emplacement de sa parcelle (n° {tostring(spotIndex)} : {arrowHome}), {plusMine} boutons « + » dessus et {plusElsewhere} ailleurs, invites de l'autel et de la forge allumées chez lui ({promptsHome}) et éteintes sur la parcelle 1 ({not promptsFirst})`
		)
		spotIndex = spotIndex or 1

		-- Fenêtre de l'autel ouverte trop tôt (comme par son icône) : elle prend presque tout l'écran du téléphone. Le
		-- panneau du tuto se cache (il couvrait son titre et ses chances), et la flèche montre le X de la fenêtre
		-- (« FERME ») ; fenêtre fermée : le panneau revient en bas et la flèche retourne sur le « + ».
		say("CMD:OpenMachine:Tower")
		local machines = playerGui:FindFirstChild("Machines")
		local altarOpen = waitFor(function()
			return machines ~= nil and machines:GetAttribute("OpenMachine") == "Tower"
		end, 6)
		local machineClose = machines and machines:FindFirstChild("CloseButton", true)
		local hiddenBehind = waitFor(function()
			return not shown(tutorialPanel) and pointerIs("CloseButton", CAPTIONS.Close)
		end, 3)
		local spinButton = machines and machines:FindFirstChild("Spin_1", true)
		local spinClear = spinButton ~= nil and shown(spinButton) and onScreen(spinButton)
		local closeBeside, closeSide = arrowBeside(machineClose)
		check(
			altarOpen and hiddenBehind and spinClear and closeBeside and ringed(machineClose) and body.Text == TutorialUI.CLOSE_TEXT
				and pointerOnScreen(),
			`nouveau joueur {name} : autel ouvert trop tôt -> le panneau du tuto se cache ({hiddenBehind}), flèche {pointerNow()} à côté de son X (côté {closeSide} : {closeBeside}), bouton x1 visible ({spinClear})`
		)
		shot(tag .. "newplayer_altar")
		closeMachines()
		local movedDown = waitFor(function()
			return (tutorialLow(tutorialPanel)) and pointerIs("World", CAPTIONS.Plus)
		end, 3)
		check(movedDown, `nouveau joueur {name} : autel fermé -> le tuto revient en bas ({where(tutorialPanel)}), flèche {pointerNow()}`)

		-- 1) Le « + » de l'emplacement montré : le panneau des tours s'ouvre, le tuto se cache derrière lui, la flèche
		-- passe sur la carte de l'Archer, entourée d'or.
		selectSpot(spotIndex)
		local card = panel:FindFirstChild("Card_MachineGun", true)
		local cardPointed = waitFor(function()
			return card ~= nil and shown(card) and ringed(card) and pointerIs("Card_MachineGun", CAPTIONS.Card)
		end, 4)
		local cardBeside, cardSide = arrowBeside(card)
		check(
			shown(panel) and onScreen(panel) and cardPointed and cardBeside and card ~= nil and onScreen(card) and not shown(tutorialPanel)
				and onScreen(pointerArrow),
			`nouveau joueur {name} : « + » -> {where(panel)} ouvert, flèche {pointerNow()} à côté de la carte de l'Archer (côté {cardSide} : {cardBeside}), entourée d'or, tuto caché derrière ({not shown(tutorialPanel)})`
		)
		shot(tag .. "newplayer_cards")

		-- L'Archer posé : la fiche de la tour remplace les cartes, l'étape suivante arrive tout de suite et la flèche
		-- passe sur « Améliorer », entouré d'or.
		plotAction:FireServer("Place", spotIndex, "MachineGun")
		local upgradeButton = panel:FindFirstChild("UpgradeButton", true)
		local upgradePointed = waitFor(function()
			return has(title.Text, "2/4") and upgradeButton ~= nil and shown(upgradeButton) and ringed(upgradeButton)
				and pointerIs("UpgradeButton", CAPTIONS.Upgrade)
		end, 15)
		local upgradeBeside, upgradeSide = arrowBeside(upgradeButton)
		check(
			upgradePointed and upgradeBeside and upgradeButton ~= nil and onScreen(upgradeButton) and pointerOnScreen(),
			`nouveau joueur {name} : Archer posé -> « {title.Text} », flèche {pointerNow()} à côté du bouton « Améliorer » de sa fiche (côté {upgradeSide} : {upgradeBeside}), entouré d'or`
		)
		shot(tag .. "newplayer_upgrade")
		-- (la tour est posée sur SA parcelle, la 2 ; rien sur la 1)
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
		check(
			mine == 1 and onFirst == 0 and towerHome,
			`nouveau joueur sur la parcelle {tostring(myIndex)} : son Archer est posé sur SA parcelle ({mine} tour, {towerHome}), aucune tour sur la parcelle 1 ({onFirst})`
		)

		-- 2) La tour améliorée : étape de l'autel. Le panneau des tours est resté ouvert et couvre tout l'écran : la
		-- flèche montre d'abord son X (« FERME »).
		task.wait(0.3)
		plotAction:FireServer("Upgrade", spotIndex)
		local panelClose = panel:FindFirstChild("CloseButton")
		local closePointed = waitFor(function()
			return has(title.Text, "3/4") and pointerIs("CloseButton", CAPTIONS.Close) and ringed(panelClose)
		end, 15)
		local panelCloseBeside, panelCloseSide = arrowBeside(panelClose)
		check(
			closePointed and panelCloseBeside and pointerOnScreen(),
			`nouveau joueur {name} : tour améliorée -> « {title.Text} » ; le panneau des tours couvre l'écran : flèche {pointerNow()} à côté de son X (côté {panelCloseSide} : {panelCloseBeside})`
		)
		shot(tag .. "newplayer_close")
		-- Panneau fermé : la flèche montre l'icône de l'autel, contre le bord DROIT de l'écran (elle est à sa gauche et
		-- pointe vers la droite) ; le texte dit « à droite ».
		selectSpot(0)
		local altarIcon = machines and machines:FindFirstChild("TowerShortcut")
		local forgeIcon = machines and machines:FindFirstChild("BonusShortcut")
		local altarPointed = waitFor(function()
			return pointerIs("TowerShortcut", CAPTIONS.Altar) and ringed(altarIcon) and (tutorialLow(tutorialPanel))
		end, 4)
		local altarBeside, altarSide = arrowBeside(altarIcon)
		check(
			altarPointed and altarBeside and altarSide == "left" and body.Text == TutorialUI.ALTAR_TEXT_PHONE and pointerOnScreen(),
			`nouveau joueur {name} : panneau fermé -> « {body.Text} », flèche {pointerNow()} à côté de l'icône de l'autel (côté {altarSide} : {altarBeside} ; {where(pointerArrow)}), entourée d'or`
		)
		shot(tag .. "newplayer_altar_icon")
		-- L'icône touchée (l'autel s'ouvre) : la flèche passe sur x1, entouré d'or.
		say("CMD:OpenMachine:Tower")
		local spinPointed = waitFor(function()
			spinButton = machines and machines:FindFirstChild("Spin_1", true)
			return pointerIs("Spin_1", CAPTIONS.Spin) and ringed(spinButton)
		end, 6)
		local spinBeside, spinSide = arrowBeside(spinButton)
		check(
			spinPointed and spinBeside and pointerOnScreen(),
			`nouveau joueur {name} : autel ouvert -> flèche {pointerNow()} à côté du bouton x1 (côté {spinSide} : {spinBeside}), entouré d'or`
		)
		shot(tag .. "newplayer_spin")

		-- 3) Le lancer x1 : pendant que le rouleau tourne, plus de flèche ; puis l'étape de la forge. L'autel est encore
		-- ouvert : la flèche montre son X.
		task.wait(0.4)
		machineAction:FireServer("SpinTower", 1)
		local reelQuiet = waitFor(function()
			return pointerHidden() and has(title.Text, "3/4")
		end, 3)
		local forgeStep = waitFor(function()
			return has(title.Text, "4/4") and pointerIs("CloseButton", CAPTIONS.Close) and ringed(machineClose)
		end, 15)
		check(
			reelQuiet and forgeStep and body.Text == TutorialUI.CLOSE_TEXT and pointerOnScreen(),
			`nouveau joueur {name} : lancer x1 -> pas de flèche pendant que le rouleau tourne ({reelQuiet}), puis « {title.Text} » : « {body.Text} », flèche {pointerNow()} sur le X de l'autel`
		)
		shot(tag .. "newplayer_result")
		-- Autel fermé : la flèche montre l'icône de la forge, à droite.
		closeMachines()
		local forgePointed = waitFor(function()
			return pointerIs("BonusShortcut", CAPTIONS.Forge) and ringed(forgeIcon) and (tutorialLow(tutorialPanel)) and shown(nextButton)
		end, 4)
		local forgeBeside, forgeSide = arrowBeside(forgeIcon)
		check(
			forgePointed and forgeBeside and forgeSide == "left" and body.Text == TutorialUI.FORGE_TEXT_PHONE and nextButton.Text == "Terminer"
				and pointerOnScreen(),
			`nouveau joueur {name} : autel fermé -> « {body.Text} », flèche {pointerNow()} à côté de l'icône de la forge (côté {forgeSide} : {forgeBeside}), bouton « {nextButton.Text} »`
		)
		shot(tag .. "newplayer_forge_icon")

		-- 4) L'icône touchée (la forge s'ouvre) : « ✓ BRAVO ! » et le mot de la fin, sans flèche ; puis le tuto se
		-- ferme tout seul.
		say("CMD:OpenMachine:Bonus")
		local lastWord = waitFor(function()
			return shown(tutorialPanel) and has(title.Text, "BRAVO") and has(body.Text, "Les runes coûtent cher au début") and pointerHidden()
		end, 5)
		shot(tag .. "newplayer_end")
		local finished = waitFor(function()
			return not shown(tutorialPanel) and pointerHidden() and player:GetAttribute("TutorialDone") == true
		end, 15)
		check(
			lastWord and finished,
			`nouveau joueur {name} : forge ouverte -> mot de la fin sous « BRAVO » ({lastWord}), puis tuto terminé, flèche retirée (TutorialDone = {tostring(player:GetAttribute("TutorialDone"))})`
		)
		closeMachines()

		-- « Passer » sur téléphone, sur un 2e tuto (« Replay », Studio seulement ; les étapes déjà faites passent seules
		-- jusqu'à la forge). Appuis faits par l'attribut de test TestSkipTap (un plugin ne peut pas toucher l'écran).
		-- Le bouton est à côté du bouton de saut : un appui par erreur ne doit pas faire perdre le tuto. Un 1er appui ne
		-- passe rien (« Confirmer ? »), il s'annule tout seul au bout de 3 s ; deux appuis de suite passent le tuto.
		-- Le serveur de test prépare ensuite la parcelle du joueur avancé.
		task.wait(1.5) -- (le serveur lit d'abord la fin du 1er tuto ; anti-spam du serveur)
		action:FireServer("Replay")
		local replayed = waitFor(function()
			return has(title.Text, "4/4") and shown(skipButton) and pointerIs("BonusShortcut", CAPTIONS.Forge)
		end, 12)
		local function tapSkip()
			tutorialGui:SetAttribute("TestSkipTap", (tutorialGui:GetAttribute("TestSkipTap") or 0) + 1)
			task.wait(0.3)
		end
		tapSkip()
		local armedText = skipButton.Text
		local stillRunning = shown(tutorialPanel) and player:GetAttribute("TutorialDone") == false
		local disarmed = waitFor(function()
			return skipButton.Text == "Passer"
		end, 5)
		check(
			replayed and armedText == "Confirmer ?" and stillRunning and disarmed and player:GetAttribute("TutorialDone") == false,
			`nouveau joueur : 2e tuto, les étapes déjà faites passent seules jusqu'à « {title.Text} » ({replayed}) ; 1er appui sur « Passer » -> « {armedText} », le tuto continue ({stillRunning}) ; 3 s sans 2e appui -> de nouveau « {skipButton.Text} » ({disarmed})`
		)
		tapSkip()
		tapSkip()
		local skipped = waitFor(function()
			return not shown(tutorialPanel) and pointerHidden() and player:GetAttribute("TutorialDone") == true
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

		-- Tuto des nouveaux joueurs sur téléphone, à chaque taille : relancé (« Replay », Studio seulement). Tout est
		-- déjà fait sauf la forge : il s'arrête à sa dernière étape. Son panneau est en bas de la zone de jeu, entier, à
		-- gauche du bouton de saut, sans toucher aucun bouton ; la flèche montre l'icône de la forge, contre le bord
		-- droit (elle est à sa gauche), entière dans l'écran. Puis « Passer ».
		do
			local remotes = ReplicatedStorage:FindFirstChild("Remotes")
			local action = remotes and remotes:FindFirstChild("TutorialAction")
			local tutorialGui = playerGui:FindFirstChild("Tutorial")
			local tutorialPanel = tutorialGui and tutorialGui:FindFirstChild("Panel")
			local tutorialTitle = tutorialPanel and tutorialPanel:FindFirstChild("Title")
			local machinesGui = playerGui:FindFirstChild("Machines")
			local forgeIcon = machinesGui and machinesGui:FindFirstChild("BonusShortcut")
			if action and tutorialPanel and tutorialTitle then
				action:FireServer("Replay")
				local started = waitFor(function()
					return shown(tutorialPanel) and string.find(tutorialTitle.Text, "4/4", 1, true) ~= nil
						and pointerIs("BonusShortcut", CAPTIONS.Forge)
				end, 12)
				task.wait(0.4)
				local lowOk, tutorialCrossed = tutorialLow(tutorialPanel)
				local forgeBeside, forgeSide = arrowBeside(forgeIcon)
				check(
					started and lowOk and forgeBeside and forgeSide == "left" and pointerOnScreen(),
					`tuto {name} : « {tutorialTitle.Text} » ({started}), {where(tutorialPanel)} en bas de l'écran, à gauche du bouton de saut, {#tutorialCrossed} bouton(s) dessous ; flèche {pointerNow()} à côté de l'icône de la forge (côté {forgeSide} : {forgeBeside}), entière dans l'écran ({pointerOnScreen()})`
						.. (if #tutorialCrossed > 0 then " : " .. table.concat(tutorialCrossed, " | ", 1, math.min(#tutorialCrossed, 3)) else "")
				)
				shot(tag .. "tutorial")
				action:FireServer("Skip", 4)
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

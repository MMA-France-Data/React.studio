-- Test de la VERSION ANGLAISE, côté client : tools/studio-test/run.ps1 -Test english.
-- Le jeu écrit tous ses textes en français ; pour un joueur non francophone, AutoTranslate.luau les remplace par leur
-- traduction (dictionnaires src/shared/LangEN). Ici, le joueur passe en anglais en direct (son attribut « Lang »,
-- comme le serveur le met pour un joueur non francophone), puis tous les écrans sont ouverts l'un après l'autre :
-- fenêtre du camp (4 onglets, nouveau joueur puis joueur avancé), panneaux et invites de la parcelle, un niveau
-- (conseils, barre des tours, menu d'une tour, petits messages), les écrans de fin (défaite, victoire, dernier
-- niveau), les mots de la flèche du tuto.
-- À chaque écran, chaque texte affiché qui a encore l'air français (lettre accentuée ou mot français courant, sans
-- les noms des joueurs) est noté. À la fin : la liste « [EN] non traduit : ... », les textes que le traducteur n'a
-- pas trouvés (liste de Lang, lue par la BindableFunction « AutoTranslateStudio » du jeu), et une ligne [PASS] /
-- [FAIL]. Puis retour au français : chaque texte doit revenir.
-- « SHOT:nom » = capture (out\english_<nom>.png).
return function(log)
	local HttpService = game:GetService("HttpService")
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Levels = require(ReplicatedStorage:WaitForChild("Shared").Levels)
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local function say(message)
		log("Info", "[EN] " .. message)
	end
	local function shot(name)
		say("SHOT:english_" .. name)
		task.wait(1.6)
	end
	local function check(ok, message)
		log(if ok then "Info" else "Error", `[{if ok then "PASS" else "FAIL"}] anglais : {message}`)
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
		say("EN:client=done")
		task.wait(1.5)
		say("PHONE:done")
	end
	local function cam()
		return workspace.CurrentCamera
	end

	local campGui = playerGui:WaitForChild("Levels", 90)
	local hudGui = playerGui:WaitForChild("LevelHud", 30)
	local pointerGui = playerGui:WaitForChild("TutorialPointer", 30)
	local test = ReplicatedStorage:WaitForChild("__EnglishTest", 60)
	local studio = player:WaitForChild("AutoTranslateStudio", 30)
	if not campGui or not hudGui or not pointerGui or not test or not studio then
		check(false, "écrans, serveur du test ou AutoTranslateStudio introuvables")
		finish()
		return
	end
	waitFor(function()
		return cam() ~= nil and cam().ViewportSize.X >= 400 and cam().ViewportSize.Y >= 250
	end, 20)
	if cam().ViewportSize.X < 400 then
		check(false, "Studio n'affiche pas le jeu (écran du PC éteint ?) : test abandonné")
		finish()
		return
	end
	task.spawn(function()
		pcall(function()
			game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
		end)
	end)
	local window = campGui:WaitForChild("Window")
	local openButton = campGui:WaitForChild("LevelsButton")
	local levelAction = ReplicatedStorage.Remotes.LevelAction
	local counter = 0
	local function act(gui, command)
		counter += 1
		gui:SetAttribute("TestAction", `{command}#{counter}`)
		task.wait(0.15)
	end
	local function ask(...)
		local ok, result = pcall(studio.Invoke, studio, ...)
		return if ok then result else nil
	end
	local function published()
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(player:GetAttribute("LevelsState"))
		end)
		return if ok then decoded else {}
	end

	------------------------------------------------------------------
	-- Ce qui a encore l'air français : une lettre accentuée (é, è, à, ç, œ... mais pas « × »), ou un mot français
	-- courant qui n'existe pas dans nos textes anglais. Sans les noms des joueurs.
	------------------------------------------------------------------
	local FRENCH_WORDS = {}
	for word in string.gmatch(
		"de du des la le les et est sont une un au aux avec pour sur dans par pas ton ta tes tu te toi qui que quand mais "
			.. "chaque tous toutes tout rien jamais niveau niveaux niv tour tours monstre monstres boutique emplacement "
			.. "emplacements vies vie victoire victoires rejouer jouer joue retour ouvrir ouvre choisir choisis vendre poser "
			.. "atq continu suivant annuler confirmer passer tuto parcelle fief libre attente domaine seigneur accueillir "
			.. "disponible col pillards cuivre roi carmin encore appuie ici touche prends cette achat garde deviennent forts "
			.. "groupe gros rochers rayon carreau foudre pierre tireur rapide longue feu flot sans donnent gagner rapporte "
			.. "acheter autres mes ses son sa leur leurs il elle ils elles ne se en ou y ce ces cet dessus manque restait "
			.. "restantes premier dernier fois moins peu peuvent ordre celui barre droite gauche vide lancer partie "
			.. "territoire empl archers catapulte baliste sorcier oracle givre rempart tempetes arcanes lourde royal",
		"%a+"
	) do
		FRENCH_WORDS[word] = true
	end
	-- (mots identiques dans les deux langues, gardés tels quels : jamais comptés)
	for _, word in { "oracle", "royal", "en" } do
		FRENCH_WORDS[word] = nil
	end
	local function hasAccent(text)
		for lead, follow in string.gmatch(text, "([\195\197])([\128-\191])") do
			if lead == "\195" and follow ~= "\151" and follow ~= "\183" then
				return true
			elseif lead == "\197" and (follow == "\146" or follow == "\147") then
				return true
			end
		end
		return false
	end
	local function escapePattern(text)
		return (string.gsub(text, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"))
	end
	local function looksFrench(text)
		if typeof(text) ~= "string" or text == "" then
			return false
		end
		local clean = string.gsub(text, "<[^>]->", " ")
		for _, other in Players:GetPlayers() do
			for _, name in { other.DisplayName, other.Name } do
				if #name >= 3 then
					clean = string.gsub(clean, escapePattern(name), " ")
				end
			end
		end
		if hasAccent(clean) then
			return true
		end
		for word in string.gmatch(string.lower(clean), "%a+") do
			if FRENCH_WORDS[word] then
				return true
			end
		end
		return false
	end

	-- Textes trouvés encore en français (une fois chacun, avec l'écran où ils étaient), et nombre de textes vus.
	local found, foundList = {}, {}
	local seen, seenCount = {}, 0
	local translatedObjects = {} -- { object, property, english, french } : pour le retour au français
	local rememberedSet = {}
	local function note(text, where)
		if typeof(text) ~= "string" or text == "" then
			return
		end
		if not seen[text] then
			seen[text] = true
			seenCount += 1
		end
		if not found[text] and looksFrench(text) then
			found[text] = true
			table.insert(foundList, { text = text, where = where })
		end
	end
	local function remember(object, property)
		local key = rememberedSet[object]
		if key and key[property] then
			return
		end
		local english = object[property]
		local french = ask("Original", object, property)
		if typeof(french) == "string" and french ~= english then
			rememberedSet[object] = key or {}
			rememberedSet[object][property] = true
			table.insert(translatedObjects, { object = object, property = property, english = english, french = french })
		end
	end
	-- Outil Studio (attribut NoTranslate sur l'objet ou un parent) : ni traduit, ni compté.
	local function skipped(object)
		local current = object
		while current and current ~= game do
			if current:GetAttribute("NoTranslate") == true then
				return true
			end
			current = current.Parent
		end
		return false
	end
	local function onScreen(object)
		local current = object
		while current and not current:IsA("LayerCollector") do
			if current:IsA("GuiObject") and not current.Visible then
				return false
			end
			current = current.Parent
		end
		return current ~= nil and current.Enabled
	end
	local function scan(root, where, visibleOnly)
		for _, object in root:GetDescendants() do
			if object:IsA("TextLabel") or object:IsA("TextButton") then
				if object:FindFirstAncestorWhichIsA("LayerCollector") and not skipped(object) and (not visibleOnly or onScreen(object)) then
					note(object.Text, where)
					remember(object, "Text")
				end
			elseif object:IsA("ProximityPrompt") and not skipped(object) then
				note(object.ActionText, where)
				note(object.ObjectText, where)
				remember(object, "ActionText")
				remember(object, "ObjectText")
			end
		end
	end
	local function scanScreen(where)
		task.wait(0.35)
		scan(playerGui, where, true)
	end
	local function scanWorld(where)
		task.wait(0.35)
		scan(workspace, where, false)
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
	local function oneLine(text)
		return (string.gsub(text, "\n", " ⏎ "))
	end

	local slot = player:GetAttribute("Plot")
	local arena = workspace:WaitForChild("Arenas"):WaitForChild("Arena" .. tostring(slot))
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
	local function startLevel(level)
		levelAction:FireServer("Start", level)
		return waitFor(function()
			return hudGui.Enabled and arena:GetAttribute("State") == "Running" and arena:GetAttribute("Level") == level
		end, 15)
	end
	local endScreen = hudGui.EndScreen
	local function backToCamp()
		levelAction:FireServer("Quit")
		waitFor(function()
			return player:GetAttribute("LevelArena") == nil and not hudGui.Enabled
		end, 6)
		task.wait(0.5)
	end

	------------------------------------------------------------------
	-- 1) Passage en anglais, comme pour un joueur non francophone
	------------------------------------------------------------------
	waitFor(function()
		return pointerGui:GetAttribute("Target") == "Play"
	end, 20)
	check(openButton.Text == "⚔ NIVEAUX" and ask("Language") == "fr", `avant : le jeu est en français (« {openButton.Text} »)`)
	local shieldedBefore, openBefore = robloxTranslation()
	check(
		shieldedBefore >= 10 and #openBefore == 0,
		`avant, en français : la traduction automatique de Roblox ne touche aucun texte du jeu ({shieldedBefore} écrans, panneaux et invites, tous avec AutoLocalize coupé ; oubliés : {#openBefore} {table.concat(openBefore, ", ")})`
	)
	player:SetAttribute("Lang", "en")
	local english = waitFor(function()
		return ask("Language") == "en" and openButton.Text == "⚔ LEVELS"
	end, 5)
	task.wait(0.5)
	check(
		english and window.Tab1.Text == "Levels" and window.Tab2.Text == "Shop" and window.Tab3.Text == "Training" and window.Tab4.Text == "My towers"
			and ask("Original", openButton) == "⚔ NIVEAUX" and (ask("Tracked") or 0) > 100,
		`passage en anglais en direct : « {openButton.Text} », onglets « {window.Tab1.Text} », « {window.Tab2.Text} », « {window.Tab3.Text} », « {window.Tab4.Text} » ({tostring(ask("Tracked"))} textes suivis, le français d'origine est gardé)`
	)
	local problems = ask("Problems") or {}
	check(#problems == 0 and (ask("Entries") or 0) >= 200, `dictionnaires : {tostring(ask("Entries"))} traductions, {#problems} problème(s) {table.concat(problems, " | ")}`)

	------------------------------------------------------------------
	-- 2) Nouveau joueur : la fenêtre du camp, la flèche du tuto, la parcelle
	------------------------------------------------------------------
	local words = pointerGui:WaitForChild("Caption")
	local skip = pointerGui:WaitForChild("Skip")
	check(
		words.Text == "PLAY HERE" and skip.Text == "Skip tutorial" and pointerGui:GetAttribute("Caption") == "JOUE ICI",
		`tuto : les mots de la flèche sont en anglais (« {words.Text} », bouton « {skip.Text} »), le jeu garde son texte français (« {tostring(pointerGui:GetAttribute("Caption"))} »)`
	)
	local page1 = window.Page1
	check(
		string.find(page1.Territory1.Text, "TERRITORY 1", 1, true) ~= nil and string.find(page1.Territory1.Text, "The Crimson King's Valley", 1, true) ~= nil
			and string.find(page1.Territory2.Text, "clear level 10", 1, true) ~= nil and page1.Level1.Play.Text == "▶ PLAY",
		`onglet des niveaux : « {page1.Territory1.Text} », « {page1.Territory2.Text} », bouton « {page1.Level1.Play.Text} »`
	)
	scanScreen("camp, onglet Niveaux (nouveau joueur)")
	shot("niveaux")
	page1.CanvasPosition = Vector2.new(0, 2000)
	scanScreen("camp, onglet Niveaux (bas de la page)")
	page1.CanvasPosition = Vector2.new(0, 0)
	act(campGui, "Tab:Boutique")
	scanScreen("camp, onglet Boutique (nouveau joueur)")
	local frost = window.Page2.Shop_Frost
	check(
		string.find(frost.Role.Text, "Slows everything near it by 40%", 1, true) ~= nil and string.find(frost.Buy.Text, "need 150 more", 1, true) ~= nil
			and window.Page2.Shop_MachineGun.Buy.Text == "✓ OWNED",
		`boutique : « {frost.Role.Text} », « {frost.Buy.Text} », « {window.Page2.Shop_MachineGun.Buy.Text} »`
	)
	shot("boutique")
	act(campGui, "Tab:Entraînement")
	scanScreen("camp, onglet Entraînement (nouveau joueur)")
	shot("entrainement")
	act(campGui, "Tab:Mes tours")
	scanScreen("camp, onglet Mes tours (nouveau joueur)")
	shot("tours")
	act(campGui, "Close")
	scanScreen("camp, fenêtre fermée (flèche sur le bouton)")
	scanWorld("panneaux et invites de la parcelle (nouveau joueur)")

	------------------------------------------------------------------
	-- 3) Joueur avancé : tours achetées, évolutions, deux emplacements, 2e territoire ouvert
	------------------------------------------------------------------
	test:InvokeServer("Set", {
		tutorial = Levels.TUTORIAL.DONE,
		best = 10,
		coins = 5000,
		towers = { MachineGun = true, Bomb = true, Frost = true, Tesla = true },
		xp = { MachineGun = 70, Bomb = 1300, Frost = 10 },
		slots = { { tower = "MachineGun", level = 2 }, { tower = "", level = 1 } },
	})
	waitFor(function()
		return published().best == 10 and published().coins == 5000
	end, 4)
	act(campGui, "Open")
	scanScreen("camp, onglet Niveaux (joueur avancé)")
	check(
		page1.Level1.Play.Text == "REPLAY" and page1.Level11.Play.Text == "▶ PLAY" and string.find(page1.Territory2.Text, "The Copper Raiders' Pass", 1, true) ~= nil
			and page1.CanvasPosition.Y > 100,
		`joueur au niveau 11 : la page s'ouvre sur le 2e territoire (« {page1.Territory2.Text} », niveau 1 « {page1.Level1.Play.Text} », niveau 11 « {page1.Level11.Play.Text} »)`
	)
	local openBadge, shopBadge = openButton:FindFirstChild("Badge"), window.Tab2:FindFirstChild("Badge")
	check(
		openBadge ~= nil and shopBadge ~= nil and openBadge.Visible and shopBadge.Visible and openBadge.Text == "!",
		"5 000 pièces et des tours à acheter : une pastille « ! » sur le bouton des niveaux et sur l'onglet de la boutique"
	)
	shot("niveaux_territoire2")
	act(campGui, "Tab:Boutique")
	scanScreen("camp, onglet Boutique (joueur avancé)")
	check(string.find(window.Page2.Shop_Rocket.Buy.Text, "BUY", 1, true) ~= nil, `boutique : « {window.Page2.Shop_Rocket.Buy.Text} »`)
	act(campGui, "Slot:2")
	scanScreen("camp, onglet Entraînement (joueur avancé, emplacement 2 choisi)")
	local archerRow = window.Page3.Towers.Train_MachineGun
	check(
		string.find(archerRow.Level.Text, "Training 2/6", 1, true) ~= nil and string.find(archerRow.Evolution1.Text, "Flaming arrows", 1, true) ~= nil
			and string.find(archerRow.NextEvolution.Text, "Next evolution (training 4): Spyglass. +3 range.", 1, true) ~= nil,
		`entraînement : « {archerRow.Level.Text} », « {archerRow.Evolution1.Text} », « {archerRow.NextEvolution.Text} », bouton « {archerRow.Train.Text} »`
	)
	shot("entrainement_avance")
	act(campGui, "Slot:1")
	scanScreen("camp, onglet Entraînement (joueur avancé, emplacement 1 choisi)")
	act(campGui, "Tab:Mes tours")
	scanScreen("camp, onglet Mes tours (joueur avancé)")
	local archerTower = window.Page4.Towers.Tower_MachineGun
	local archerTexts = {}
	for _, child in archerTower:GetChildren() do
		if child:IsA("TextLabel") then
			table.insert(archerTexts, oneLine(child.Text))
		end
	end
	check(#archerTexts >= 2, `mes tours : {table.concat(archerTexts, " | ")}`)
	shot("tours_avance")
	act(campGui, "Close")
	task.wait(1)
	scanWorld("panneaux et invites de la parcelle (joueur avancé)")

	------------------------------------------------------------------
	-- 4) Un niveau, de nouveau comme un nouveau joueur (conseils du premier niveau, guide du tuto)
	------------------------------------------------------------------
	test:InvokeServer("Reset")
	waitFor(function()
		return published().best == 0 and published().tutorial == 0
	end, 4)
	local entered = startLevel(1)
	waitFor(function()
		return pointerGui:GetAttribute("Caption") == "POSE-LA ICI"
	end, 6)
	scanScreen("niveau 1, départ (conseil, barre, flèche)")
	local strip = hudGui.TopStrip
	check(
		entered and strip.Level.Text == "LEVEL 1" and string.find(strip.Progress.ProgressText.Text, "Monsters:", 1, true) ~= nil
			and hudGui.TowerBar.Tower_MachineGun.Cost.Text == "CANCEL" and hudGui.TowerBar.Tower_Bomb.TowerName.Text == "Catapult"
			and string.find(hudGui.Hint.Text, "Your Archer is already shooting", 1, true) ~= nil and words.Text == "PLACE IT HERE",
		`niveau : « {strip.Level.Text} », « {strip.Progress.ProgressText.Text} », barre « {hudGui.TowerBar.Tower_MachineGun.Cost.Text} » / « {hudGui.TowerBar.Tower_Bomb.TowerName.Text} », conseil « {hudGui.Hint.Text} », flèche « {words.Text} »`
	)
	shot("niveau")
	act(hudGui, `Tap:{map.spots[2].X},{map.spots[2].Z}`)
	waitFor(function()
		return #towers() == 2
	end, 4)
	scanScreen("niveau 1, 2e tour posée (conseil d'amélioration)")
	act(hudGui, `Tap:{map.spots[1].X},{map.spots[1].Z}`)
	local menu = hudGui.TowerMenu
	waitFor(function()
		return menu.Visible
	end, 3)
	scanScreen("niveau 1, menu d'une tour")
	check(
		string.find(menu.Title.Text, "Rampart Archer", 1, true) ~= nil and string.find(menu.Title.Text, "lv. 1", 1, true) ~= nil
			and string.find(menu.Stats.Text, "Damage 3", 1, true) ~= nil and string.find(menu.Stats.Text, "5 atk/s", 1, true) ~= nil
			and string.find(menu.Stats.Text, "Next level: damage 4.1", 1, true) ~= nil and string.find(menu.Upgrade.Text, "Upgrade 15", 1, true) ~= nil
			and string.find(menu.Sell.Text, "Sell +", 1, true) ~= nil,
		`menu d'une tour : « {menu.Title.Text} », « {oneLine(menu.Stats.Text)} », « {menu.Upgrade.Text} », « {menu.Sell.Text} »`
	)
	shot("menu")
	waitFor(function()
		return (arena:GetAttribute("Gold") or 0) >= 15
	end, 15)
	act(hudGui, "Upgrade")
	task.wait(0.6)
	scanScreen("niveau 1, tour améliorée")
	scanWorld("niveau 1, étiquettes des tours")
	local shielded, openToRoblox = robloxTranslation()
	check(
		shielded >= 10 and #openToRoblox == 0,
		`en anglais, pendant un niveau : la traduction automatique de Roblox ne touche aucun texte du jeu ({shielded} écrans, panneaux et invites ; oubliés : {#openToRoblox} {table.concat(openToRoblox, ", ")})`
	)
	act(hudGui, "Bar:Bomb")
	scanScreen("niveau 1, Catapulte en main (conseil de pose)")
	check(string.find(hudGui.Hint.Text, "to place: Catapult", 1, true) ~= nil, `conseil de pose : « {hudGui.Hint.Text} »`)
	act(hudGui, "Bar:Bomb")
	-- Petits messages : refus sur le chemin, abandon à confirmer.
	test:InvokeServer("Gold", 600)
	act(hudGui, "Select:MachineGun")
	act(hudGui, "Tap:-34,0")
	scanScreen("niveau 1, refus sur le chemin (petit message)")
	act(hudGui, "Select:")
	act(hudGui, "Quit")
	scanScreen("niveau 1, abandon à confirmer (petit message)")
	local toastTexts = {}
	local toasts = playerGui:FindFirstChild("Toasts")
	for _, label in if toasts then toasts:GetDescendants() else {} do
		if label:IsA("TextLabel") then
			table.insert(toastTexts, label.Text)
		end
	end
	check(
		table.find(toastTexts, "Too close to the path") ~= nil and table.find(toastTexts, "Tap X again to give up this level") ~= nil and strip.Quit.Text == "X?",
		`petits messages : {table.concat(toastTexts, " | ")} ; bouton « {strip.Quit.Text} »`
	)
	-- Or gardé : le conseil « ne garde pas ton or ».
	act(hudGui, `Tap:{map.spots[3].X},{map.spots[3].Z + 9}`) -- (herbe vide : le menu se ferme)
	waitFor(function()
		return string.find(hudGui.Hint.Text, "gold", 1, true) ~= nil and string.find(hudGui.Hint.Text, "stronger", 1, true) ~= nil
	end, 12)
	scanScreen("niveau 1, or gardé (conseil)")
	check(string.find(hudGui.Hint.Text, "Don't sit on your gold", 1, true) ~= nil, `conseil : « {hudGui.Hint.Text} »`)

	------------------------------------------------------------------
	-- 5) Écrans de fin : défaite, victoire (avec une évolution), dernier niveau
	------------------------------------------------------------------
	test:InvokeServer("Finish", false)
	waitFor(function()
		return endScreen.Visible
	end, 5)
	scanScreen("écran de fin : défaite")
	local panel = endScreen.Panel
	check(
		panel.Title.Text == "DEFEAT" and panel.Next.Text == "Try again" and string.find(panel.Details.Text, "monsters defeated", 1, true) ~= nil
			and string.find(panel.Camp.Text, "Back to camp", 1, true) ~= nil,
		`défaite : « {panel.Title.Text} », « {oneLine(panel.Details.Text)} », « {panel.Next.Text} », « {panel.Camp.Text} » ; flèche « {words.Text} »`
	)
	shot("defaite")
	-- (l'Archer est à 4 XP de sa 1re évolution : la victoire la lui donne)
	test:InvokeServer("Set", { xp = { MachineGun = 56 } })
	startLevel(1)
	task.wait(0.5)
	test:InvokeServer("Finish", true)
	waitFor(function()
		return endScreen.Visible and arena:GetAttribute("State") == "Won"
	end, 5)
	scanScreen("écran de fin : victoire")
	check(
		panel.Title.Text == "VICTORY!" and panel.Next.Text == "Level 2 ▶" and panel.Replay.Text == "Replay"
			and string.find(panel.Details.Text, "cleared for the first time", 1, true) ~= nil and string.find(panel.Details.Text, "Lives left: 10/10", 1, true) ~= nil
			and string.find(panel.Details.Text, "EVOLUTION! Rampart Archer: Flaming arrows", 1, true) ~= nil,
		`victoire : « {panel.Title.Text} », « {oneLine(panel.Details.Text)} », « {panel.Next.Text} », « {panel.Replay.Text} » ; flèche « {words.Text} »`
	)
	shot("victoire")
	test:InvokeServer("Set", { best = Levels.COUNT - 1, tutorial = Levels.TUTORIAL.DONE })
	startLevel(Levels.COUNT)
	task.wait(1)
	scanScreen("dernier niveau, départ")
	shot("niveau_20")
	test:InvokeServer("Finish", true)
	waitFor(function()
		return endScreen.Visible and arena:GetAttribute("State") == "Won"
	end, 5)
	scanScreen("écran de fin : dernier niveau gagné")
	check(
		panel.Next.Text == "All levels cleared!" and string.find(panel.Details.Text, "You can buy a new tower in the shop!", 1, true) ~= nil,
		`dernier niveau gagné : « {panel.Next.Text} », « {oneLine(panel.Details.Text)} »`
	)
	-- Fin du premier territoire : le suivant s'ouvre, l'écran de fin le dit.
	test:InvokeServer("Set", { best = 9 })
	startLevel(10)
	task.wait(0.5)
	test:InvokeServer("Finish", true)
	waitFor(function()
		return endScreen.Visible and arena:GetAttribute("State") == "Won" and panel.Next.Text == "Level 11 ▶"
	end, 5)
	scanScreen("écran de fin : niveau 10 gagné (nouveau territoire)")
	check(
		panel.Next.Text == "Level 11 ▶" and string.find(panel.Details.Text, "New territory unlocked: The Copper Raiders' Pass!", 1, true) ~= nil,
		`niveau 10 gagné : « {oneLine(panel.Details.Text)} », bouton « {panel.Next.Text} »`
	)
	shot("nouveau_territoire")
	backToCamp()
	scanScreen("retour au camp")
	-- Achat à la boutique : le message du serveur.
	test:InvokeServer("Set", { coins = 500 })
	levelAction:FireServer("Buy", "Frost")
	task.wait(0.8)
	levelAction:FireServer("Buy", "Frost")
	task.wait(0.8)
	scanScreen("achat à la boutique (petits messages)")
	scanWorld("panneaux de la parcelle après les niveaux")

	------------------------------------------------------------------
	-- 6) Bilan
	------------------------------------------------------------------
	-- Textes que le traducteur n'a pas trouvés (même s'ils n'étaient plus à l'écran pendant les relevés).
	local misses, noted = 0, 0
	for _, text in ask("Misses") or {} do
		noted += 1
		if not found[text] and looksFrench(text) then
			found[text] = true
			misses += 1
			table.insert(foundList, { text = text, where = "texte sans traduction noté par le traducteur" })
		end
	end
	for _, entry in foundList do
		log("Error", `[EN] non traduit : « {oneLine(entry.text)} » ({entry.where})`)
	end
	check(
		#foundList == 0 and seenCount >= 250 and #translatedObjects >= 250,
		`version anglaise : {#foundList} texte(s) encore en français sur {seenCount} textes différents relevés ({#translatedObjects} objets traduits ; le traducteur a noté {noted} texte(s) sans traduction, dont {misses} en français : les autres sont des noms de joueurs)`
	)

	------------------------------------------------------------------
	-- 7) Retour au français : chaque texte traduit revient
	------------------------------------------------------------------
	player:SetAttribute("Lang", "fr")
	local french = waitFor(function()
		return ask("Language") == "fr" and openButton.Text == "⚔ NIVEAUX"
	end, 5)
	task.wait(0.5)
	local wrong = 0
	local example = ""
	for _, entry in translatedObjects do
		local object = entry.object
		if object:IsDescendantOf(game) then
			local current = object[entry.property]
			-- (un texte qui a changé entre-temps est écrit en français par le jeu : il ne doit juste plus être l'anglais relevé,
			-- sauf si l'anglais et le français sont identiques)
			if current == entry.english and entry.english ~= entry.french then
				wrong += 1
				example = `{object:GetFullName()} : « {oneLine(current)} »`
			end
		end
	end
	check(french and wrong == 0, `retour au français en direct : « {openButton.Text} », {wrong} texte(s) resté(s) en anglais sur {#translatedObjects} {example}`)

	finish()
end

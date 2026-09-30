-- Scénario de test côté client (exécuté par le plugin AutoPlayTest, map principale et match).
-- « SHOT:nom » dans la sortie = run.ps1 prend une capture de Studio (out\nom.png).
-- Un plugin ne peut pas simuler de clic : on déplace la caméra, on affiche les fenêtres
-- directement et on envoie les actions par les vrais remotes.
return function(log)
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local player = Players.LocalPlayer
	local camera = workspace.CurrentCamera
	local mode = ReplicatedStorage:GetAttribute("ServerMode")

	local function say(message)
		log("Info", "[CTEST] " .. message)
	end
	local function shot(name)
		say("SHOT:" .. name)
		task.wait(1.2)
	end
	-- Les textes flottants (MaxDistance) se basent sur le point visé par la caméra (Focus), qui suit
	-- normalement le personnage : on le place sur la cible, comme si le joueur s'y trouvait.
	local function look(from, at)
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = CFrame.lookAt(from, at)
		camera.Focus = CFrame.new(at)
	end
	local function restoreCamera()
		camera.CameraType = Enum.CameraType.Custom
	end
	-- Premier bouton visible dont le texte (ou celui d'un de ses textes) contient le motif.
	local function findButton(pattern)
		for _, gui in player.PlayerGui:GetDescendants() do
			if (gui:IsA("TextButton") or gui:IsA("TextLabel")) and gui.Visible and gui.Text:find(pattern) then
				local button = gui
				while button and not button:IsA("GuiButton") do
					button = button.Parent
				end
				if button then
					return button
				end
			end
		end
		return nil
	end

	----------------------------------------------------------------------
	-- Version anglaise (src/shared/Lang.luau, src/client/AutoTranslate.luau, dictionnaires src/shared/LangEN). Appelée
	-- TOUT À LA FIN du scénario (map principale : après le tuto ; match : après la dernière capture) : les autres
	-- vérifications lisent les textes français. Le joueur passe en anglais en direct (son attribut « Lang », comme le
	-- serveur le met pour un joueur non francophone), les fenêtres principales s'ouvrent l'une après l'autre (captures
	-- english_*) et chaque texte qui a encore l'air français (lettre accentuée ou mot français courant, sans les noms des
	-- joueurs ni les nombres) est écrit « [CTEST] non traduit : ... » : textes de l'écran, des panneaux du monde et des
	-- invites, et ceux que le traducteur n'a pas trouvés (liste de Lang, lue par la BindableFunction
	-- « AutoTranslateStudio » du jeu : le test a sa propre copie des modules). Puis une ligne [PASS] / [FAIL]
	-- « version anglaise : N textes encore en français », le retour au français (chaque texte traduit doit revenir), et
	-- tout est refermé. place = "hub" (map principale) ou "match".
	-- Dans sa propre fonction (limite des 200 variables locales de Luau).
	----------------------------------------------------------------------
	local function englishAudit(place)
		local function report(ok, message)
			log(if ok then "Info" else "Error", `[{if ok then "PASS" else "FAIL"}] {message}`)
		end
		local function waitFor(condition, timeout)
			local deadline = os.clock() + timeout
			while os.clock() < deadline do
				if condition() then
					return true
				end
				task.wait(0.1)
			end
			return condition() == true
		end
		local studio = player:WaitForChild("AutoTranslateStudio", 10)
		if not studio then
			report(false, "version anglaise : BindableFunction « AutoTranslateStudio » introuvable dans le joueur (AutoTranslate.luau)")
			return
		end
		local function ask(...)
			local ok, result = pcall(studio.Invoke, studio, ...)
			return if ok then result else nil
		end
		local playerGui = player:WaitForChild("PlayerGui")
		local FAKE_OPPONENT = "TestBot"

		-- A l'air français : lettre accentuée (é, è, à, ç, œ... mais pas « × »), ou un mot français courant qui n'existe
		-- pas en anglais. Sans les balises RichText, les noms des joueurs et les nombres.
		local FRENCH_WORDS = {}
		for word in string.gmatch(
			"de du des la le les et est sont une un au aux avec pour sur dans par pas ton ta tes tu te toi vous nous qui que "
				.. "quand mais chaque tous toutes tout rien jamais aucun aucune vague vagues niveau niv lancer lancers "
				.. "doublon doublons emplacement emplacements autel parcelle parcelles fief fiefs tuto suivant passer terminer "
				.. "fermer ferme ouvrir ouvre acheter vendre remplacer poser annuler accepter refuser chargement adversaire "
				.. "inscription recherche saison cible cibles vitesse gratuit gratuits ennemi ennemis joueur joueurs "
				.. "classement boutique renaissance rang victoire partie effets effet muet seuls prochaine prochain temps "
				.. "attente vie vies argent platine diamant complet invoque disponible hors ligne rythme ralenti ralentit "
				.. "limite jour jours semaine aujourd hui cours nouveaux nouvelle nouvelles nouveau infini cercle sceau entre va "
				.. "vas ici rayon suis fois moins sa son sons ses mon ma mes ce cette ces il elle ils elles leur leurs ou y en ne "
				.. "se atq pv contre foule foules feu sol carreau perce gros groupe inventaire plein seulement pendant continuer "
				.. "produire atteinte heures secondes quelques fin forteresse connexion choisir plusieurs maj fait faire peux "
				.. "peut dois doit sera seront gagne gagner joue jouer tiens perdre retour offerts offert offerte offertes "
				.. "retourne",
			"%a+"
		) do
			FRENCH_WORDS[word] = true
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
		local names = {}
		local function refreshNames()
			table.clear(names)
			for _, other in Players:GetPlayers() do
				table.insert(names, other.DisplayName)
				table.insert(names, other.Name)
			end
			local opponent = player:GetAttribute("MatchOpponent")
			if typeof(opponent) == "string" then
				table.insert(names, opponent)
			end
			table.insert(names, FAKE_OPPONENT)
			table.sort(names, function(a, b)
				return #a > #b
			end)
		end
		refreshNames()
		local function looksFrench(text)
			if typeof(text) ~= "string" or text == "" then
				return false
			end
			local clean = string.gsub(text, "<[^>]->", " ")
			for _, name in names do
				if #name >= 3 then -- (un nom de 1 ou 2 lettres effacerait des morceaux de mots)
					clean = string.gsub(clean, escapePattern(name), " ")
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

		-- Textes trouvés : encore en français (une fois chacun), et traduits (pour le retour au français).
		local found, foundList = {}, {}
		local counts = { screen = 0, world = 0, missed = 0 }
		local translated, translatedSeen = {}, {}
		local function note(text, source)
			if typeof(text) == "string" and not found[text] and looksFrench(text) then
				found[text] = true
				table.insert(foundList, text)
				counts[source] += 1
			end
		end
		local function remember(object, property)
			local text = object[property]
			local original = ask("Original", object, property)
			local seen = translatedSeen[object] or {}
			translatedSeen[object] = seen
			if typeof(original) == "string" and original ~= text and not seen[property] then
				seen[property] = true
				table.insert(translated, { object = object, property = property, english = text, french = original })
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
		-- Vraiment à l'écran : lui et ses parents visibles, dans un écran allumé.
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
		local function scanTexts(root, source, visibleOnly)
			for _, object in root:GetDescendants() do
				if object:IsA("TextLabel") or object:IsA("TextButton") then
					if object:FindFirstAncestorWhichIsA("LayerCollector") and not skipped(object) and (not visibleOnly or onScreen(object)) then
						note(object.Text, source)
						remember(object, "Text")
					end
				elseif object:IsA("ProximityPrompt") and not skipped(object) then
					note(object.ActionText, source)
					note(object.ObjectText, source)
					remember(object, "ActionText")
					remember(object, "ObjectText")
				end
			end
		end
		local function scanScreen()
			scanTexts(playerGui, "screen", true)
		end
		local function oneLine(text)
			local line = string.gsub(text, "\n", " ⏎ ")
			if (utf8.len(line) or 0) > 220 then
				line = string.sub(line, 1, (utf8.offset(line, 221) or (#line + 1)) - 1) .. "…"
			end
			return line
		end

		-- Fenêtres (fermées à la fin comme par leur bouton X : les tests cachent le voile plein écran).
		local function hideOverlay(guiName)
			local gui = playerGui:FindFirstChild(guiName)
			local overlay = gui and gui:FindFirstChild("Overlay")
			if overlay and overlay:IsA("GuiObject") then
				overlay.Visible = false
			end
		end
		local function showOverlay(guiName)
			local gui = playerGui:FindFirstChild(guiName)
			local overlay = gui and gui:FindFirstChild("Overlay")
			if overlay and overlay:IsA("GuiObject") then
				overlay.Visible = true
				return true
			end
			return false
		end
		local function closeMachines()
			local machines = playerGui:FindFirstChild("Machines")
			if machines then
				machines:SetAttribute("OpenMachine", nil)
			end
			hideOverlay("Machines")
		end
		local function openMachine(machine)
			say(`CMD:OpenMachine:{machine}`)
			local machines = playerGui:FindFirstChild("Machines")
			return waitFor(function()
				return machines ~= nil and machines:GetAttribute("OpenMachine") == machine
			end, 6)
		end
		local plotGui = playerGui:FindFirstChild("Plot")
		local function selectSpot(spotIndex)
			if plotGui then
				plotGui:SetAttribute("TestSelectSpot", spotIndex)
			end
		end

		-- Map principale : attendre la fin du tuto côté serveur (le test « version anglaise » relance le tuto).
		local tutorialFree = true
		if place == "hub" then
			tutorialFree = waitFor(function()
				return ReplicatedStorage:GetAttribute("AutoTestTutorial") == "Server"
			end, 20)
			task.wait(1)
			closeMachines()
			for _, guiName in { "Shop", "Challenges", "Rebirth" } do
				hideOverlay(guiName)
			end
			selectSpot(0)
		end

		-- 1) Passage en anglais en direct.
		ask("ClearMisses")
		player:SetAttribute("Lang", "en")
		local switched = waitFor(function()
			return ask("Language") == "en"
		end, 5)
		task.wait(0.8)
		local tracked = ask("Tracked") or 0
		local archerOk, archerText = true, nil
		if place == "hub" then
			-- La carte de l'Archer (panneau des tours) : son nom vient du Glossaire.
			local card = plotGui and plotGui:FindFirstChild("Card_MachineGun", true)
			archerOk = false
			for _, label in (if card then card:GetDescendants() else {}) do
				if label:IsA("TextLabel") and ask("Original", label, "Text") == "Archer du rempart" then
					archerText = label.Text
					archerOk = label.Text == "Rampart Archer"
				end
			end
		end
		report(
			switched and tracked > 0 and archerOk,
			`version anglaise : passage en anglais en direct (langue affichée {tostring(ask("Language"))}, {tracked} textes suivis{if place == "hub" then `, carte de l'Archer : « {tostring(archerText)} »` else ""})`
		)
		local problems = ask("Problems") or {}
		report(#problems == 0, `version anglaise : dictionnaires chargés, {tostring(ask("Entries"))} traductions, {#problems} problème(s)`)
		for index, message in problems do
			if index > 30 then
				break
			end
			say("dictionnaire : " .. oneLine(message))
		end

		-- 2) L'écran, puis les fenêtres une par une.
		shot(`english_{if place == "hub" then "hud" else "match"}`)
		scanScreen()
		if place == "hub" then
			-- Panneau des tours : fiche de la tour posée par le tuto, cartes (emplacement libre), cadenas.
			local PlotLayout = require(ReplicatedStorage.Shared.PlotLayout)
			local plotIndex = player:GetAttribute("Plot")
			local plot = plotIndex and workspace.Hub.Plots:FindFirstChild("Plot" .. plotIndex)
			local towerSpot, freeSpot, lockedSpot = nil, nil, nil
			if plot then
				local owned, taken = {}, {}
				local raw = plot:GetAttribute("OwnedSpots")
				if typeof(raw) == "string" and raw ~= "" then
					for _, text in string.split(raw, ",") do
						if tonumber(text) then
							owned[tonumber(text)] = true
						end
					end
				else
					for spotIndex = 1, PlotLayout.STARTING_SPOTS do
						owned[spotIndex] = true
					end
				end
				local towers = plot:FindFirstChild("Towers")
				for _, model in (if towers then towers:GetChildren() else {}) do
					local spotIndex = model:GetAttribute("SpotIndex")
					if typeof(spotIndex) == "number" then
						taken[spotIndex] = true
						towerSpot = towerSpot or spotIndex
					end
				end
				for spotIndex = 1, #PlotLayout.SPOTS do
					freeSpot = freeSpot or (if owned[spotIndex] and not taken[spotIndex] then spotIndex else nil)
					lockedSpot = lockedSpot or (if not owned[spotIndex] then spotIndex else nil)
				end
			end
			if towerSpot then
				selectSpot(towerSpot)
				task.wait(0.6)
				shot("english_tower")
				scanScreen()
			end
			if freeSpot then
				selectSpot(freeSpot)
				task.wait(0.6)
				shot("english_cards")
				scanScreen()
			end
			if lockedSpot then
				selectSpot(lockedSpot)
				task.wait(0.4)
				scanScreen()
			end
			selectSpot(0)
			say(`version anglaise : panneau des tours vu (tour {tostring(towerSpot)}, libre {tostring(freeSpot)}, cadenas {tostring(lockedSpot)})`)

			-- Autel des héros et Forge runique (ouverts comme par leur invite).
			for _, machine in { "Tower", "Bonus" } do
				if openMachine(machine) then
					task.wait(0.6)
					shot(if machine == "Tower" then "english_altar" else "english_forge")
					scanScreen()
				else
					report(false, `version anglaise : la machine {machine} ne s'est pas ouverte (CMD:OpenMachine:{machine})`)
				end
			end
			closeMachines()

			-- Boutique, défis, renaissance (ouvertes comme par leur bouton de la colonne de gauche).
			for _, window in { { "Shop", "english_shop", 0.6 }, { "Challenges", "english_challenges", 1 }, { "Rebirth", "english_rebirth", 0.6 } } do
				if showOverlay(window[1]) then
					task.wait(window[3])
					shot(window[2])
					scanScreen()
					hideOverlay(window[1])
				else
					report(false, `version anglaise : fenêtre {window[1]} introuvable (PlayerGui.{window[1]}.Overlay)`)
				end
			end

			-- « Pendant ton absence » : le vrai ShopUI.showOfflineGains (copie du module du test : sa fenêtre est retirée
			-- juste après).
			local clientFolder = player:WaitForChild("PlayerScripts"):WaitForChild("Client", 10)
			local shopModule = clientFolder and clientFolder:FindFirstChild("ShopUI")
			if shopModule then
				local before = {}
				for _, child in playerGui:GetChildren() do
					before[child] = true
				end
				require(shopModule).showOfflineGains({ amount = 123456, seconds = 2 * 3600, kind = "Offline", capped = true })
				task.wait(1)
				shot("english_offline")
				scanScreen()
				for _, child in playerGui:GetChildren() do
					if not before[child] and child.Name == "OfflineGains" then
						local overlay = child:FindFirstChild("Overlay")
						if overlay and overlay:IsA("GuiObject") then
							overlay.Visible = false
						end
						child:Destroy()
					end
				end
			end

			-- Tuto (relancé comme « Replay », Studio seulement), avec sa flèche dans le monde, puis « Passer ».
			local tutorialGui = playerGui:FindFirstChild("Tutorial")
			local panel = tutorialGui and tutorialGui:FindFirstChild("Panel")
			if tutorialFree and panel then
				ReplicatedStorage.Remotes.TutorialAction:FireServer("Replay")
				local started = waitFor(function()
					return panel.Visible and tutorialGui.Enabled
				end, 8)
				task.wait(0.6)
				shot("english_tutorial")
				scanScreen()
				local guide = workspace:FindFirstChild("TutorialGuide")
				if guide then
					scanTexts(guide, "world", false)
				end
				task.wait(0.6) -- (anti-spam du serveur : un message toutes les 0,5 s)
				ReplicatedStorage.Remotes.TutorialAction:FireServer("Skip", 1)
				local ended = waitFor(function()
					return not panel.Visible and player:GetAttribute("TutorialDone") == true
				end, 8)
				if not (started and ended) then
					report(false, `version anglaise : tuto relancé ({started}) puis passé ({ended})`)
				end
			else
				say(`version anglaise : tuto pas relancé (main rendue par le serveur : {tutorialFree}, panneau {panel ~= nil})`)
			end

			-- Classé : bouton « S'INSCRIRE », recherche, « MATCH TROUVÉ ! », attente. Attributs changés chez ce client
			-- seulement (le serveur ne voit rien), puis remis comme avant.
			local ATTRIBUTES = { "InRankedCircle", "QueueState", "QueueStartedAt", "MatchOpponent", "MatchOpponentMmr", "MatchOpponentGames", "MatchAcceptEndsAt" }
			local saved = {}
			for _, name in ATTRIBUTES do
				saved[name] = player:GetAttribute(name)
			end
			player:SetAttribute("InRankedCircle", true)
			task.wait(0.5)
			scanScreen()
			player:SetAttribute("QueueStartedAt", workspace:GetServerTimeNow() - 42)
			player:SetAttribute("QueueState", "Searching")
			task.wait(0.5)
			scanScreen()
			player:SetAttribute("MatchOpponent", FAKE_OPPONENT)
			player:SetAttribute("MatchOpponentMmr", 1234)
			player:SetAttribute("MatchOpponentGames", 12)
			player:SetAttribute("MatchAcceptEndsAt", workspace:GetServerTimeNow() + 15)
			player:SetAttribute("QueueState", "Pending")
			task.wait(0.6)
			shot("english_ranked")
			scanScreen()
			player:SetAttribute("QueueState", "Accepted")
			task.wait(0.4)
			scanScreen()
			for _, name in ATTRIBUTES do
				player:SetAttribute(name, saved[name])
			end

			-- Le centre (classement, panneaux du classé) et ta parcelle, vus de près (textes flottants allumés).
			local plotFrame = plotIndex and PlotLayout.cframe(plotIndex)
			look(Vector3.new(0, 25, 70), Vector3.new(0, 4, 0))
			shot("english_center")
			if plotFrame then
				look(plotFrame:PointToWorldSpace(Vector3.new(32, 26, -45)), plotFrame:PointToWorldSpace(Vector3.new(0, 2, -18)))
				shot("english_plot")
			end
			restoreCamera()
		end

		-- 3) Panneaux du monde et invites (allumés ou non : chacun s'allume de près), puis ce que le traducteur n'a pas
		-- trouvé pendant tout ce temps (textes cachés, messages...).
		refreshNames()
		scanTexts(workspace, "world", false)
		for _, text in ask("Misses") or {} do
			note(text, "missed")
		end
		local MAX_LINES = 200
		for index, text in foundList do
			if index > MAX_LINES then
				say(`non traduit : … et {#foundList - MAX_LINES} autres`)
				break
			end
			say("non traduit : " .. oneLine(text))
			if index % 20 == 0 then
				task.wait(0.6) -- (la Sortie part par paquets : pas trop de lignes à la fois)
			end
		end
		report(
			#foundList == 0,
			`version anglaise : {#foundList} textes encore en français ({counts.screen} à l'écran, {counts.world} dans le monde et les invites, {counts.missed} autres vus par le traducteur)`
		)

		-- 4) Retour au français en direct : chaque texte traduit reprend son texte d'origine, plus rien n'est suivi.
		player:SetAttribute("Lang", "fr")
		local backOk = waitFor(function()
			return ask("Language") == "fr" and ask("Tracked") == 0
		end, 5)
		task.wait(0.3)
		local back, stuck, gone, stuckTexts = 0, 0, 0, {}
		for _, entry in translated do
			if not entry.object.Parent then
				gone += 1
			elseif entry.object[entry.property] == entry.english and entry.english ~= entry.french then
				stuck += 1
				if #stuckTexts < 5 then
					table.insert(stuckTexts, oneLine(entry.english))
				end
			else
				back += 1
			end
		end
		report(
			backOk and stuck == 0,
			`version anglaise : retour au français en direct ({back} textes traduits revenus en français, {stuck} restés en anglais{if #stuckTexts > 0 then " : " .. table.concat(stuckTexts, " | ") else ""}, {gone} disparus entre-temps ; plus rien de suivi : {backOk})`
		)
		if place == "hub" then
			closeMachines()
			selectSpot(0)
		end
	end

	if mode == "Match" then
		task.wait(8)
		-- Envois retirés : le HUD du match a sa boutique de tours mais aucun texte d'envoi.
		local function findText(pattern)
			for _, gui in player.PlayerGui:GetDescendants() do
				if (gui:IsA("TextButton") or gui:IsA("TextLabel")) and gui.Text:find(pattern) then
					return gui
				end
			end
			return nil
		end
		local hud = player.PlayerGui:FindFirstChild("Match")
		local shop, sends = findText("Archer"), findText("[Ee]nvo[iy]")
		local hudOk = hud ~= nil and shop ~= nil and sends == nil
		log(
			if hudOk then "Info" else "Error",
			`[{if hudOk then "PASS" else "FAIL"}] HUD du match sans panneau d'envois (HUD {hud ~= nil}, boutique {shop ~= nil}, texte d'envoi : {if sends then sends.Text else "aucun"})`
		)
		-- Téléphone : la fiche de tour (au-dessus de la boutique de tours, MatchUI.cardScale) garde sa taille sur l'écran
		-- du test, et tient entière entre le haut de l'écran et la boutique sur un téléphone en paysage (844 x 390 et
		-- 667 x 375, moins la barre du haut de Roblox) : avant, son haut passait sous cette barre.
		do
			local panel = hud and hud:FindFirstChild("TowerCardPanel")
			local fit = panel and panel:FindFirstChild("FitScale")
			local clientFolder = player:WaitForChild("PlayerScripts"):WaitForChild("Client", 10)
			local matchModule = clientFolder and clientFolder:FindFirstChild("MatchUI")
			if panel and fit and matchModule then
				local cardScale = require(matchModule).cardScale
				local size = Vector2.new(panel.Size.X.Offset, panel.Size.Y.Offset)
				local bottom = -panel.Position.Y.Offset -- (92 px au-dessus du bas de l'écran)
				local expected = cardScale(hud.AbsoluteSize, size)
				local realOk = math.abs(fit.Scale - expected) < 0.01
				log(
					if realOk then "Info" else "Error",
					`[{if realOk then "PASS" else "FAIL"}] fiche de tour du match sur l'écran du test ({math.floor(hud.AbsoluteSize.X)} x {math.floor(hud.AbsoluteSize.Y)}) : x{string.format("%.2f", fit.Scale)}{if fit.Scale > 0.999 then " (taille d'ordinateur)" else ""} (attendu x{string.format("%.2f", expected)})`
				)
				local topBar = math.max(58, (game:GetService("GuiService"):GetGuiInset()).Y)
				for _, phone in { Vector2.new(844, 390), Vector2.new(667, 375) } do
					local area = phone - Vector2.new(0, topBar)
					local scale = cardScale(area, size)
					local top = area.Y - bottom - size.Y * scale
					local ok = scale > 0.4 and top >= 8 - 0.5 and size.X * scale <= area.X - 16 + 0.5
					log(
						if ok then "Info" else "Error",
						`[{if ok then "PASS" else "FAIL"}] fiche de tour du match sur téléphone {math.floor(phone.X)} x {math.floor(phone.Y)} (écran utile {math.floor(area.X)} x {math.floor(area.Y)}) : x{string.format("%.2f", scale)}, de y {math.floor(top)} à {math.floor(area.Y - bottom)} (au-dessus de la boutique), {math.floor(size.X * scale)} px de large`
					)
				end
			else
				log("Error", "[FAIL] fiche de tour du match introuvable (PlayerGui.Match.TowerCardPanel, son FitScale, module MatchUI)")
			end
		end
		shot("match_player")
		look(Vector3.new(0, 140, 160), Vector3.new(0, 0, 0))
		shot("match_aerial")
		restoreCamera()
		task.wait(25)
		shot("match_fight")
		-- Tout à la fin : la version anglaise du HUD du match (voir englishAudit plus haut).
		englishAudit("match")
		return
	end

	-- Map principale : vue du joueur, vue aérienne, centre, ma parcelle
	task.wait(3)

	----------------------------------------------------------------------
	-- Sons (src/shared/Sounds.luau, src/client/SoundManager.luau) : le bouton « SON » ne couvre pas la carte de rang,
	-- chaque son se charge dans Studio (numéro valide, son public et gratuit), puis la limite des sons de combat
	-- tient : 200 tirs à la même image n'en font jouer que Sounds.MAX_COMBAT_SOUNDS au plus, et un seul par son
	-- (minInterval). Tout petit volume.
	-- Lancé à part (task.spawn, fonction sans nom : limite des 200 variables locales) : il ne retarde pas les
	-- autres tests.
	----------------------------------------------------------------------
	task.spawn(function()
		-- Bouton « SON » (SoundManager) : à gauche du compteur de pièces ou juste dessous, jamais sur la carte de
		-- rang (LobbyUI : 260 x 130 px à 16 px du bord en haut à gauche).
		local soundGui = player.PlayerGui:FindFirstChild("SoundButton")
		local soundButton = soundGui and soundGui:FindFirstChild("SoundButton")
		if soundButton then
			local at, size = soundButton.AbsolutePosition, soundButton.AbsoluteSize
			local clear = at.X >= 16 + 260 or at.Y >= 16 + 130
			log(
				if clear then "Info" else "Error",
				`[{if clear then "PASS" else "FAIL"}] bouton « SON » sans couvrir la carte de rang (x {math.floor(at.X)}, y {math.floor(at.Y)}, {math.floor(size.X)} x {math.floor(size.Y)} px, écran {math.floor(camera.ViewportSize.X)} px)`
			)
		else
			log("Error", "[FAIL] bouton « SON » introuvable (PlayerGui.SoundButton)")
		end

		local ContentProvider = game:GetService("ContentProvider")
		local SoundService = game:GetService("SoundService")
		local Sounds = require(ReplicatedStorage.Shared.Sounds)
		local testFolder = Instance.new("Folder")
		testFolder.Name = "__TestSons"
		testFolder.Parent = SoundService
		local names, list, byName = {}, {}, {}
		for name, def in Sounds.SLOTS do
			local sound = Instance.new("Sound")
			sound.Name = name
			sound.SoundId = Sounds.assetId(def.id)
			sound.Volume = 0
			sound.Parent = testFolder
			byName[name] = sound
			table.insert(list, sound)
			table.insert(names, name)
		end
		table.sort(names)
		task.spawn(function()
			pcall(function()
				ContentProvider:PreloadAsync(list)
			end)
		end)
		local deadline = os.clock() + 30
		local function allLoaded()
			for _, sound in list do
				if not (sound.IsLoaded and sound.TimeLength > 0) then
					return false
				end
			end
			return true
		end
		while os.clock() < deadline and not allLoaded() do
			task.wait(0.25)
		end
		local loaded = 0
		for _, name in names do
			local def, sound = Sounds.SLOTS[name], byName[name]
			local ok = sound.IsLoaded and sound.TimeLength > 0
			loaded += if ok then 1 else 0
			log(
				if ok then "Info" else "Error",
				`[{if ok then "PASS" else "FAIL"}] son « {def.name} » ({name}, id {def.id}) : {if ok then `chargé, {string.format("%.2f", sound.TimeLength)} s` else "ne se charge pas (numéro faux, son privé ou payant ?)"}`
			)
		end
		say(`sons chargés : {loaded}/{#names}`)
		testFolder:Destroy()

		-- Limite des sons de combat : 200 demandes à la même image, réparties sur tous les sons 3D (un seul départ
		-- par son, MAX_COMBAT_SOUNDS en tout au plus), puis 200 demandes d'un seul son (une seule voix démarre).
		local clientFolder = player:WaitForChild("PlayerScripts"):WaitForChild("Client", 10)
		local managerModule = clientFolder and clientFolder:FindFirstChild("SoundManager")
		if not managerModule then
			log("Error", "[FAIL] sons : module SoundManager introuvable (PlayerScripts.Client)")
			return
		end
		local SoundManager = require(managerModule)
		-- (Sans les sons « priority » : la mort d'un boss passe exprès au-delà de la limite.)
		local combat = {}
		for _, name in names do
			local def = Sounds.SLOTS[name]
			if def.range and not def.loop and not def.priority then
				table.insert(combat, name)
			end
		end
		local started, cap, active = SoundManager.testBurst(combat, 200)
		local capOk = started <= cap and active <= cap and (started >= 1 or active >= cap)
		log(
			if capOk then "Info" else "Error",
			`[{if capOk then "PASS" else "FAIL"}] sons : 200 tirs à la même image ({#combat} sons 3D) -> {started} démarrés, {active} en train de jouer (limite {cap})`
		)
		task.wait(6) -- les sons du test précédent sont finis
		local single = SoundManager.testBurst({ "ArcherShot" }, 200)
		log(
			if single <= 1 then "Info" else "Error",
			`[{if single <= 1 then "PASS" else "FAIL"}] sons : 200 flèches à la même image -> {single} son (1 au plus : un départ toutes les {Sounds.SLOTS.ArcherShot.minInterval} s)`
		)

		-- Musiques qui s'enchaînent (Sounds.PLAYLISTS.Hub) : on saute à 1 s de la fin du morceau en cours, un autre
		-- morceau de la liste doit démarrer tout seul (et avancer). Le Sound du jeu est cherché dans SoundService
		-- (dossier « SonsDuJeu » : le require du test n'a pas la même copie du module que Main.client).
		local function findMusic()
			for _, descendant in SoundService:GetDescendants() do
				if
					descendant:IsA("Sound")
					and descendant.Parent
					and descendant.Parent.Name == "SonsDuJeu"
					and table.find(Sounds.PLAYLISTS.Hub, descendant.Name)
				then
					return descendant
				end
			end
			return nil
		end
		local musicDeadline = os.clock() + 40
		local music = findMusic()
		while os.clock() < musicDeadline and not (music and music.IsPlaying and music.TimeLength > 0) do
			task.wait(0.25)
			music = music or findMusic()
		end
		if not music then
			log("Error", "[FAIL] musiques : pas de musique dans SoundService.SonsDuJeu")
			return
		end
		local before = music.Name
		if not (music.IsPlaying and music.TimeLength > 0) then
			log("Error", `[FAIL] musiques : « {before} » ne joue pas (bouton « SON » sur {player:GetAttribute("SoundMode") or "?"})`)
			return
		end
		-- (un Sound neuf par morceau : on cherche celui qui a pris la place)
		music.TimePosition = math.max(0, music.TimeLength - 1)
		musicDeadline = os.clock() + 30
		local current = music
		while os.clock() < musicDeadline do
			task.wait(0.25)
			current = findMusic()
			if current and current ~= music and current.IsPlaying and current.TimePosition > 0.5 then
				break
			end
		end
		local chained = current ~= nil
			and current ~= music
			and current.Name ~= before
			and table.find(Sounds.PLAYLISTS.Hub, current.Name) ~= nil
			and current.IsPlaying
			and current.TimePosition > 0.5
		log(
			if chained then "Info" else "Error",
			`[{if chained then "PASS" else "FAIL"}] musiques : fin de « {before} » -> « {if current then current.Name else "aucune"} » ({if current and current.IsPlaying then "joue" else "ne joue pas"}, {if current then string.format("%.1f", current.TimePosition) else "?"} s)`
		)
	end)

	shot("hub_player")
	-- HUD de la parcelle (PlotUI) : la vague, le record et les ennemis restants sont sur le tableau « CHRONIQUES DU
	-- FIEF » de la parcelle : plus de panneau de vague en haut de l'écran, seulement le compteur de pièces.
	do
		local plotGui = player.PlayerGui:FindFirstChild("Plot")
		local waveTexts, coinsLabel = {}, nil
		for _, gui in (if plotGui then plotGui:GetDescendants() else {}) do
			if gui:IsA("TextLabel") then
				local text = gui.Text
				if string.find(text, "^💰") then
					coinsLabel = gui
				elseif string.find(text, "^Vague %d") or string.find(text, "vague ratée") or string.find(text, "Ennemis restants") or string.find(text, "Prochaine vague") then
					table.insert(waveTexts, text)
				end
			end
		end
		local hudOk = plotGui ~= nil and coinsLabel ~= nil and coinsLabel.Visible and #waveTexts == 0
		log(
			if hudOk then "Info" else "Error",
			`[{if hudOk then "PASS" else "FAIL"}] HUD de la parcelle : compteur de pièces ({coinsLabel and coinsLabel.Text}), plus de panneau de vague ({#waveTexts} texte(s) de vague : {table.concat(waveTexts, " | ")})`
		)
	end
	-- Parcelles des autres (src/client/PlotAccess.luau) : chez ce joueur, seules les invites « Ouvrir » de SON autel
	-- et de SA forge sont allumées ; celles des autres parcelles (libres ici : un seul joueur) sont éteintes, et
	-- les prix des cadenas ne s'affichent que sur sa parcelle. Lancé à part : il ne retarde pas les autres tests.
	task.spawn(function()
		local plotsFolder = workspace:WaitForChild("Hub"):WaitForChild("Plots")
		local function access()
			local myIndex = player:GetAttribute("Plot")
			local result = { mine = 0, others = 0, wrong = {}, otherPrices = 0, wrongPrices = 0, plots = 0 }
			for _, plot in plotsFolder:GetChildren() do
				result.plots += 1
				local isMine = myIndex ~= nil and plot:GetAttribute("PlotIndex") == myIndex
				for _, descendant in plot:GetDescendants() do
					local parent = descendant.Parent
					if descendant:IsA("ProximityPrompt") then
						if isMine then
							result.mine += 1
						else
							result.others += 1
						end
						if descendant.Enabled ~= isMine then
							table.insert(result.wrong, `{plot.Name}.{parent and parent.Name}={descendant.Enabled}`)
						end
					elseif descendant:IsA("TextLabel") and descendant.Name == "Price" and parent and parent.Name == "Lock" then
						result.otherPrices += if isMine then 0 else 1
						result.wrongPrices += if descendant.Visible ~= isMine then 1 else 0
					end
				end
			end
			return result
		end
		local deadline = os.clock() + 15
		local state = access()
		while (#state.wrong > 0 or state.wrongPrices > 0 or state.mine == 0) and os.clock() < deadline do
			task.wait(0.25)
			state = access()
		end
		-- (5 autres parcelles x 2 invites ; au moins une, si Roblox n'envoyait pas encore les parcelles lointaines)
		local promptsOk = state.mine == 2 and state.others > 0 and state.others <= (state.plots - 1) * 2 and #state.wrong == 0
		log(
			if promptsOk then "Info" else "Error",
			`[{if promptsOk then "PASS" else "FAIL"}] invites des machines : les 2 de sa parcelle allumées ({state.mine}), les {state.others} des autres parcelles éteintes (fausses : {table.concat(state.wrong, " ")})`
		)
		local pricesOk = state.otherPrices > 0 and state.wrongPrices == 0
		log(
			if pricesOk then "Info" else "Error",
			`[{if pricesOk then "PASS" else "FAIL"}] prix des cadenas cachés sur les autres parcelles ({state.otherPrices} cachés, {state.wrongPrices} faux)`
		)
	end)
	look(Vector3.new(0, 230, 290), Vector3.new(0, 0, 0))
	shot("hub_aerial")
	look(Vector3.new(0, 25, 70), Vector3.new(0, 4, 0))
	shot("hub_center")
	local PlotLayout = require(ReplicatedStorage.Shared.PlotLayout)
	local plotIndex = player:GetAttribute("Plot")
	if plotIndex then
		local cf = PlotLayout.cframe(plotIndex)
		task.wait(8) -- tours posées par le scénario serveur, vague en cours
		look(cf:PointToWorldSpace(Vector3.new(32, 26, -45)), cf:PointToWorldSpace(Vector3.new(0, 2, -18)))
		shot("hub_plot_fight")
		look(cf:PointToWorldSpace(Vector3.new(-10, 12, -2)), cf:PointToWorldSpace(Vector3.new(6, 3, -22)))
		shot("hub_towers_close")
		-- Le personnage s'approche des tours (caméra normale) : les étiquettes proches doivent apparaître.
		restoreCamera()
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		-- Étiquettes « Niv. X » allumées (ProximityLabel) : aucune de loin, toutes de près.
		local function enabledLevelTags()
			local enabled, total = 0, 0
			for _, gui in workspace:GetDescendants() do
				if gui:IsA("BillboardGui") and gui.Name == "LevelTag" then
					total += 1
					enabled += if gui.Enabled then 1 else 0
				end
			end
			return enabled, total
		end
		if root then
			local home = root.CFrame
			root.CFrame = CFrame.new(cf:PointToWorldSpace(Vector3.new(-20, 4, -75))) -- loin des tours
			task.wait(0.8)
			local far, total = enabledLevelTags()
			log(if far == 0 then "Info" else "Error", `[{if far == 0 then "PASS" else "FAIL"}] loin des tours : {far}/{total} étiquettes affichées`)
			root.CFrame = CFrame.new(cf:PointToWorldSpace(Vector3.new(0, 4, -22))) -- au milieu des tours
			task.wait(0.8)
			local near = enabledLevelTags()
			log(if near == total and total > 0 then "Info" else "Error", `[{if near == total and total > 0 then "PASS" else "FAIL"}] près des tours : {near}/{total} étiquettes affichées`)
			shot("hub_near_towers")
			root.CFrame = home
		end
	end
	restoreCamera()
	task.wait(1)

	----------------------------------------------------------------------
	-- Fenêtres sur téléphone (UI.windowScale, UI.fitWindow : src/client/UI.luau). Chaque fenêtre est réduite juste
	-- assez pour tenir dans la zone de son ScreenGui (sous la barre du haut de Roblox), à UI.WINDOW_MARGIN px des
	-- bords, jamais agrandie. La vraie fenêtre affichée : entière sur l'écran du test avec tous ses boutons, à la place
	-- et à l'échelle calculées par le jeu (x1, sa taille d'ordinateur, quand l'écran est assez grand : captures
	-- inchangées). Puis la vraie fonction avec de fausses tailles de téléphone en paysage (844 x 390 et 667 x 375,
	-- moins la barre du haut) : la fenêtre réduite et chacun de ses boutons (à leur place dans la vraie fenêtre)
	-- restent dans l'écran. place(écran) -> (coin en haut à gauche, échelle) : placement propre à la fenêtre (défis),
	-- sinon centrée sur sa Position. besideColumn : sur téléphone, elle reste à droite de la colonne de gauche.
	----------------------------------------------------------------------
	local function checkPhoneFit(label, window, design, place, besideColumn)
		local clientFolder = player:WaitForChild("PlayerScripts"):WaitForChild("Client", 10)
		local uiModule = clientFolder and clientFolder:FindFirstChild("UI")
		local gui = window and window:FindFirstAncestorWhichIsA("ScreenGui")
		if not (uiModule and gui) then
			log("Error", `[FAIL] fenêtre « {label} » sur téléphone : fenêtre ou module UI introuvable`)
			return
		end
		local UI = require(uiModule)
		local margin = UI.WINDOW_MARGIN
		if not place then
			local center = Vector2.new(window.Position.X.Scale, window.Position.Y.Scale)
			place = function(screen)
				local scale = UI.windowScale(screen, design, center)
				return Vector2.new(center.X * screen.X, center.Y * screen.Y) - design * scale / 2, scale
			end
		end
		-- Vraiment affiché : lui et tous ses parents visibles, dans un ScreenGui allumé.
		local function shown(object)
			local current = object
			while current and current ~= gui do
				if current:IsA("GuiObject") and not current.Visible then
					return false
				end
				current = current.Parent
			end
			return current == gui and gui.Enabled
		end
		local screen = gui.AbsoluteSize
		local at = window.AbsolutePosition - gui.AbsolutePosition
		local size = window.AbsoluteSize
		local scale = size.X / design.X
		-- Boutons affichés, à leur place dans la fenêtre, en px « d'ordinateur » (échelle 1).
		local buttons = {}
		for _, descendant in window:GetDescendants() do
			if descendant:IsA("GuiButton") and shown(descendant) then
				local text = if descendant:IsA("TextButton") and descendant.Text ~= "" then descendant.Text else descendant.Name
				table.insert(buttons, {
					name = (string.gsub(text, "\n", " ")),
					at = (descendant.AbsolutePosition - window.AbsolutePosition) / scale,
					size = descendant.AbsoluteSize / scale,
				})
			end
		end
		local function inside(topLeft, bottomRight, area, edge)
			return topLeft.X >= edge - 1 and topLeft.Y >= edge - 1 and bottomRight.X <= area.X - edge + 1 and bottomRight.Y <= area.Y - edge + 1
		end
		-- Boutons hors de l'écran pour une fenêtre dont le coin est en topLeft, à cette échelle ; et le moins haut.
		local function buttonsOut(topLeft, factor, area)
			local out, smallest = {}, math.huge
			for _, button in buttons do
				local corner = topLeft + button.at * factor
				if not inside(corner, corner + button.size * factor, area, 0) then
					table.insert(out, button.name)
				end
				smallest = math.min(smallest, button.size.Y * factor)
			end
			return out, smallest
		end
		local function px(value)
			return math.floor(value + 0.5)
		end

		-- La vraie fenêtre, sur l'écran du test.
		local expectedAt, expectedScale = place(screen)
		local out = buttonsOut(at, scale, screen)
		local realOk = shown(window)
			and #buttons > 0
			and #out == 0
			and inside(at, at + size, screen, margin)
			and math.abs(scale - expectedScale) < 0.01
			and (at - expectedAt).Magnitude < 2
		log(
			if realOk then "Info" else "Error",
			`[{if realOk then "PASS" else "FAIL"}] fenêtre « {label} » sur l'écran du test ({px(screen.X)} x {px(screen.Y)}) : x{string.format("%.2f", scale)}{if scale > 0.999 then " (taille d'ordinateur)" else ""} (attendu x{string.format("%.2f", expectedScale)}), de ({px(at.X)}, {px(at.Y)}) à ({px(at.X + size.X)}, {px(at.Y + size.Y)}), {#buttons - #out}/{#buttons} boutons dans l'écran{if #out > 0 then " ; dehors : " .. table.concat(out, ", ") else ""}`
		)

		-- Fausses tailles de téléphone en paysage, moins la barre du haut de Roblox (58 px avec la nouvelle barre).
		local topBar = math.max(58, (game:GetService("GuiService"):GetGuiInset()).Y)
		for _, phone in { Vector2.new(844, 390), Vector2.new(667, 375) } do
			local area = phone - Vector2.new(0, topBar)
			local topLeft, phoneScale = place(area)
			local phoneOut, smallest = buttonsOut(topLeft, phoneScale, area)
			local column = UI.leftColumnRight(area)
			local columnOk = not besideColumn or topLeft.X >= column + margin - 1
			local ok = #buttons > 0
				and #phoneOut == 0
				and columnOk
				and phoneScale > UI.MIN_WINDOW_SCALE
				and inside(topLeft, topLeft + design * phoneScale, area, margin)
			log(
				if ok then "Info" else "Error",
				`[{if ok then "PASS" else "FAIL"}] fenêtre « {label} » sur téléphone {px(phone.X)} x {px(phone.Y)} (écran utile {px(area.X)} x {px(area.Y)}) : x{string.format("%.2f", phoneScale)} ({px(design.X * phoneScale)} x {px(design.Y * phoneScale)} px, coin en ({px(topLeft.X)}, {px(topLeft.Y)})), entière, {#buttons - #phoneOut}/{#buttons} boutons dans l'écran (le moins haut : {px(smallest)} px){if besideColumn then `, à droite de la colonne de gauche (bord à {px(column)} px) : {columnOk}` else ""}{if #phoneOut > 0 then " ; dehors : " .. table.concat(phoneOut, ", ") else ""}`
			)
		end
	end

	-- Fenêtres qui changent de TAILLE (UI.modalSize : autel et forge depuis le HUD de ChatGPT) au lieu d'être réduites
	-- par un UIScale : leur contenu défile, les boutons d'achat et de fermeture restent fixes. Sur l'écran du test :
	-- la taille attendue, centrée sur sa Position, entière à 8 px des bords, et tous ses boutons affichés dans la
	-- fenêtre. Sur téléphone (fausses tailles) : la taille calculée par UI.modalSize tient dans l'écran utile.
	local function checkModalFit(label, window, design)
		local clientFolder = player:WaitForChild("PlayerScripts"):WaitForChild("Client", 10)
		local uiModule = clientFolder and clientFolder:FindFirstChild("UI")
		local gui = window and window:FindFirstAncestorWhichIsA("ScreenGui")
		if not (uiModule and gui) then
			log("Error", `[FAIL] fenêtre « {label} » : fenêtre ou module UI introuvable`)
			return
		end
		local UI = require(uiModule)
		local function shown(object)
			local current = object
			while current and current ~= gui do
				if current:IsA("GuiObject") and not current.Visible then
					return false
				end
				current = current.Parent
			end
			return current == gui and gui.Enabled
		end
		local function px(value)
			return math.floor(value + 0.5)
		end
		local screen = gui.AbsoluteSize
		local at = window.AbsolutePosition - gui.AbsolutePosition
		local size = window.AbsoluteSize
		local expected = UI.modalSize(screen, design)
		local center = Vector2.new(window.Position.X.Scale * screen.X, window.Position.Y.Scale * screen.Y)
		local total, out = 0, {}
		for _, descendant in window:GetDescendants() do
			if descendant:IsA("GuiButton") and shown(descendant) then
				total += 1
				local topLeft = descendant.AbsolutePosition - gui.AbsolutePosition
				local bottomRight = topLeft + descendant.AbsoluteSize
				-- (dans une liste qui défile, un bouton peut être caché par le défilement : seul l'écran compte)
				if topLeft.X < -1 or topLeft.Y < -1 or bottomRight.X > screen.X + 1 or bottomRight.Y > screen.Y + 1 then
					table.insert(out, (string.gsub(if descendant:IsA("TextButton") then descendant.Text else descendant.Name, "\n", " ")))
				end
			end
		end
		local realOk = shown(window)
			and total > 0
			and #out == 0
			and (size - expected).Magnitude < 3
			and ((at + size / 2) - center).Magnitude < 3
			and at.X >= 7 and at.Y >= 7 and at.X + size.X <= screen.X - 7 and at.Y + size.Y <= screen.Y - 7
		log(
			if realOk then "Info" else "Error",
			`[{if realOk then "PASS" else "FAIL"}] fenêtre « {label} » sur l'écran du test ({px(screen.X)} x {px(screen.Y)}) : {px(size.X)} x {px(size.Y)} px (attendu {px(expected.X)} x {px(expected.Y)}), de ({px(at.X)}, {px(at.Y)}) à ({px(at.X + size.X)}, {px(at.Y + size.Y)}), {total - #out}/{total} boutons dans l'écran{if #out > 0 then " ; dehors : " .. table.concat(out, ", ") else ""}`
		)
		local topBar = math.max(58, (game:GetService("GuiService"):GetGuiInset()).Y)
		for _, phone in { Vector2.new(844, 390), Vector2.new(667, 375) } do
			local area = phone - Vector2.new(0, topBar)
			local phoneSize = UI.modalSize(area, design)
			local ok = phoneSize.X <= area.X - 16 + 0.5 and phoneSize.Y <= area.Y - 16 + 0.5 and phoneSize.X >= 160 and phoneSize.Y >= 160
			log(
				if ok then "Info" else "Error",
				`[{if ok then "PASS" else "FAIL"}] fenêtre « {label} » sur téléphone {px(phone.X)} x {px(phone.Y)} (écran utile {px(area.X)} x {px(area.Y)}) : {px(phoneSize.X)} x {px(phoneSize.Y)} px, entière (contenu qui défile)`
			)
		end
	end

	-- Renaissance (run à la vague 50 préparée par le scénario serveur)
	local rebirthButton = findButton("Renaissance")
	if rebirthButton then
		shot("hub_ui")
		local rebirthGui = player.PlayerGui:FindFirstChild("Rebirth")
		local overlay = rebirthGui and rebirthGui:FindFirstChildWhichIsA("TextButton")
		if overlay then
			overlay.Visible = true
			task.wait(0.8)
			shot("rebirth_window")
			checkPhoneFit("renaissance", overlay:FindFirstChild("Window"), Vector2.new(520, 440))
			overlay.Visible = false
		else
			log("Error", "[CTEST] fenêtre de renaissance introuvable")
		end
		ReplicatedStorage.Remotes.PlotAction:FireServer("Rebirth")
		task.wait(0.4)
		shot("rebirth_done")
	else
		log("Error", "[CTEST] bouton Renaissance introuvable")
	end

	-- Autel des héros (machine à tours) : fenêtre, puis un achat x10 et son résumé.
	-- (Ouverte par le plugin, via la commande « CMD:OpenMachine », comme son ProximityPrompt.)
	task.wait(1)
	say("CMD:OpenMachine:Tower")
	task.wait(1.5)
	shot("altar")
	ReplicatedStorage.Remotes.MachineAction:FireServer("SpinTower", 10)
	task.wait(3)
	shot("altar_x10")
	-- Sur téléphone : la fenêtre de l'autel (x1, x10... compris), puis la même fenêtre en forge (boutons pièces et
	-- Robux). L'autel est ensuite rouvert, comme avant (le tuto, plus bas, regarde quelle machine est ouverte).
	do
		local machinesGui = player.PlayerGui:FindFirstChild("Machines")
		local machineWindow = machinesGui and machinesGui:FindFirstChild("Window", true)
		-- Ouvre une machine et attend qu'elle soit vraiment ouverte (attribut OpenMachine de MachineUI) : la commande
		-- passe par le plugin et le serveur (jusqu'à ~0,5 s d'attente). Avec une attente fixe, un autel rouvert en
		-- retard passerait par-dessus la fenêtre des défis et les captures suivantes.
		local function openMachine(machine)
			say(`CMD:OpenMachine:{machine}`)
			local deadline = os.clock() + 6
			while os.clock() < deadline and not (machinesGui and machinesGui:GetAttribute("OpenMachine") == machine) do
				task.wait(0.1)
			end
			task.wait(0.3) -- (le temps que les boutons de la fenêtre soient placés)
			return machinesGui ~= nil and machinesGui:GetAttribute("OpenMachine") == machine
		end
		checkModalFit("autel", machineWindow, Vector2.new(660, 620))
		if openMachine("Bonus") then
			checkModalFit("forge", machineWindow, Vector2.new(660, 620))
		else
			log("Error", "[FAIL] fenêtre « forge » sur téléphone : la forge ne s'est pas ouverte (CMD:OpenMachine:Bonus)")
		end
		if not openMachine("Tower") then
			log("Error", "[FAIL] l'autel ne s'est pas rouvert après la forge (CMD:OpenMachine:Tower)")
		end
	end

	-- Défis classés : bouton « ⚔ DÉFIS » (colonne de gauche) et fenêtre (3 + 2 défis, bouton « X »), qui
	-- ne couvre ni le chat (en bas à gauche) ni la liste des joueurs (en haut à droite) sur un écran d'ordinateur.
	do
		-- L'autel est encore ouvert : son voile (plein écran) passerait par-dessus. (Les boutons de la colonne de
		-- gauche sont dans le même ScreenGui : on ne cache que le voile.)
		local machines = player.PlayerGui:FindFirstChild("Machines")
		for _, child in (if machines then machines:GetChildren() else {}) do
			if child:IsA("TextButton") and child.Size == UDim2.fromScale(1, 1) then
				child.Visible = false
			end
		end
		local challengesButton = findButton("DÉFIS")
		local challengesGui = player.PlayerGui:FindFirstChild("Challenges")
		local overlay = challengesGui and challengesGui:FindFirstChild("Overlay")
		local window = overlay and overlay:FindFirstChild("Window")
		local found = challengesButton ~= nil and window ~= nil
		log(if found then "Info" else "Error", `[{if found then "PASS" else "FAIL"}] bouton « DÉFIS » et fenêtre des défis présents`)
		if found then
			overlay.Visible = true
			task.wait(1)
			local claimButtons, closeFound = 0, false
			for _, descendant in window:GetDescendants() do
				if descendant:IsA("TextButton") then
					claimButtons += if descendant.Text == "Récupérer" then 1 else 0
					closeFound = closeFound or descendant.Text == "X"
				end
			end
			local rowsOk = claimButtons == 5 and closeFound
			log(if rowsOk then "Info" else "Error", `[{if rowsOk then "PASS" else "FAIL"}] fenêtre des défis : {claimButtons} lignes (attendu 5), bouton X {closeFound}`)
			local screen = challengesGui.AbsoluteSize
			if screen.X >= 1000 then
				local left, right = window.AbsolutePosition.X, window.AbsolutePosition.X + window.AbsoluteSize.X
				local top, bottom = window.AbsolutePosition.Y, window.AbsolutePosition.Y + window.AbsoluteSize.Y
				-- À droite du chat (500 px), et à gauche de la liste des joueurs (420 px de large) ou sous elle
				-- (310 px de haut) : réglages de ChallengeUI.luau.
				local placed = left >= 499 and (right <= screen.X - 419 or top >= 309) and bottom <= screen.Y + 1
				log(
					if placed then "Info" else "Error",
					`[{if placed then "PASS" else "FAIL"}] fenêtre des défis sans couvrir le chat ni la liste des joueurs (x de {math.floor(left)} à {math.floor(right)}, y de {math.floor(top)} à {math.floor(bottom)}, écran {math.floor(screen.X)} x {math.floor(screen.Y)})`
				)
			else
				say(`écran étroit ({math.floor(screen.X)} px) : fenêtre des défis seulement réduite`)
			end
			-- Sur téléphone : réduite, et à droite de la colonne de gauche (les boutons de l'autel et de la forge
			-- passent par-dessus cette fenêtre). Placement du jeu : ChallengeUI.placement.
			checkPhoneFit("défis", window, Vector2.new(560, 530), function(area)
				return require(player.PlayerScripts.Client.ChallengeUI).placement(area)
			end, true)
			shot("challenges_panel")
			overlay.Visible = false
		end
	end

	----------------------------------------------------------------------
	-- Téléphone, suite : la colonne de boutons de gauche (UI.leftColumnSlot : toute la colonne réduite quand l'écran
	-- est trop bas ; avant, la Boutique et les Défis sortaient de l'écran d'un téléphone en paysage), puis les
	-- fenêtres qui ne s'ouvrent pas ailleurs dans le test : la boutique (ShopUI) et le message « Pendant ton
	-- absence » (le vrai ShopUI.showOfflineGains, appelé comme au retour d'une absence ; sa fenêtre est retirée juste
	-- après). Dans sa propre fonction (limite des 200 variables locales de Luau).
	----------------------------------------------------------------------
	local function testPhoneWindows()
		local clientFolder = player:WaitForChild("PlayerScripts"):WaitForChild("Client", 10)
		local uiModule = clientFolder and clientFolder:FindFirstChild("UI")
		if not uiModule then
			log("Error", "[FAIL] téléphone : module UI introuvable (PlayerScripts.Client)")
			return
		end
		local UI = require(uiModule)
		local function report(ok, message)
			log(if ok then "Info" else "Error", `[{if ok then "PASS" else "FAIL"}] {message}`)
		end
		local function px(value)
			return math.floor(value + 0.5)
		end

		-- Colonne de gauche, sur l'écran du test : les 5 vrais boutons à leur place de toujours (une colonne, taille
		-- normale) quand l'écran est assez haut, sinon à la place calculée par le jeu.
		local columnButtons = {
			{ "Machines", "AUTEL DES HÉROS" },
			{ "Machines", "FORGE RUNIQUE" },
			{ "RebirthButton", nil },
			{ "ShopButton", "★ BOUTIQUE" },
			{ "ChallengesButton", "⚔ DÉFIS" },
		}
		local wrong, found, screenText = {}, 0, "?"
		for index, entry in columnButtons do
			local gui = player.PlayerGui:FindFirstChild(entry[1])
			local button = nil
			for _, child in (if gui then gui:GetChildren() else {}) do
				if
					child:IsA("GuiButton")
					and child:FindFirstChild("ColumnScale")
					and (entry[2] == nil or (child:IsA("TextButton") and child.Text == entry[2]))
				then
					button = child
				end
			end
			if button and gui then
				found += 1
				local screen = gui.AbsoluteSize
				screenText = `{px(screen.X)} x {px(screen.Y)}`
				local tall = screen.Y
					>= UI.LEFT_COLUMN_TOP + (UI.LEFT_COLUMN_COUNT - 1) * UI.LEFT_COLUMN_STEP + UI.LEFT_BUTTON_SIZE.Y + UI.WINDOW_MARGIN
				local expected, expectedScale = UI.leftColumnSlot(screen, index - 1)
				if tall then
					expected, expectedScale = Vector2.new(16, UI.LEFT_COLUMN_TOP + (index - 1) * UI.LEFT_COLUMN_STEP), 1
				end
				local at = button.AbsolutePosition - gui.AbsolutePosition
				local scale = button.AbsoluteSize.X / UI.LEFT_BUTTON_SIZE.X
				if (at - expected).Magnitude > 1.5 or math.abs(scale - expectedScale) > 0.01 then
					table.insert(wrong, `{entry[2] or entry[1]} en ({px(at.X)}, {px(at.Y)}) x{string.format("%.2f", scale)}`)
				end
			end
		end
		report(
			found == #columnButtons and #wrong == 0,
			`colonne de gauche sur l'écran du test ({screenText}) : {found}/{#columnButtons} boutons à leur place{if #wrong > 0 then " ; mal placés : " .. table.concat(wrong, ", ") else ""}`
		)
		-- Colonne de gauche sur téléphone (vraie fonction, fausses tailles) : les 5 boutons dans l'écran, sous la carte de
		-- rang (16 + 130 px) et pas plus larges qu'elle (16 + 260 px), sans se chevaucher.
		local topBar = math.max(58, (game:GetService("GuiService"):GetGuiInset()).Y)
		for _, phone in { Vector2.new(844, 390), Vector2.new(667, 375) } do
			local area = phone - Vector2.new(0, topBar)
			local problems, rects, height = {}, {}, 0
			for index = 0, UI.LEFT_COLUMN_COUNT - 1 do
				local corner, scale = UI.leftColumnSlot(area, index)
				local far = corner + UI.LEFT_BUTTON_SIZE * scale
				height = UI.LEFT_BUTTON_SIZE.Y * scale
				if corner.X < 0 or corner.Y < 16 + 130 or far.X > 16 + 260 + 0.5 or far.Y > area.Y - UI.WINDOW_MARGIN + 0.5 then
					table.insert(problems, `bouton {index + 1} de ({px(corner.X)}, {px(corner.Y)}) à ({px(far.X)}, {px(far.Y)})`)
				end
				for _, other in rects do
					if corner.X < other[2].X and other[1].X < far.X and corner.Y < other[2].Y and other[1].Y < far.Y then
						table.insert(problems, `bouton {index + 1} sur un autre`)
					end
				end
				table.insert(rects, { corner, far })
			end
			report(
				#problems == 0,
				`colonne de gauche sur téléphone {px(phone.X)} x {px(phone.Y)} (écran utile {px(area.X)} x {px(area.Y)}) : les {UI.LEFT_COLUMN_COUNT} boutons dans l'écran, sous la carte de rang et pas plus larges qu'elle, sans se chevaucher ({px(height)} px de haut){if #problems > 0 then " ; problèmes : " .. table.concat(problems, ", ") else ""}`
			)
		end

		-- Boutique (ShopUI) : ouverte comme par son bouton, puis refermée.
		local shopGui = player.PlayerGui:FindFirstChild("Shop")
		local shopOverlay = shopGui and shopGui:FindFirstChild("Overlay")
		if shopOverlay then
			shopOverlay.Visible = true
			task.wait(0.5)
			checkPhoneFit("boutique", shopOverlay:FindFirstChild("Window"), Vector2.new(820, 400))
			shopOverlay.Visible = false
		else
			report(false, "téléphone : fenêtre de la boutique introuvable (PlayerGui.Shop.Overlay)")
		end

		-- « Pendant ton absence » : le vrai ShopUI.showOfflineGains (copie du module chargée par le test : sa fenêtre est
		-- à part, dans un nouveau ScreenGui « OfflineGains », retiré juste après la vérification).
		local shopModule = clientFolder:FindFirstChild("ShopUI")
		if not shopModule then
			report(false, "téléphone : module ShopUI introuvable (PlayerScripts.Client)")
			return
		end
		local before = {}
		for _, child in player.PlayerGui:GetChildren() do
			before[child] = true
		end
		require(shopModule).showOfflineGains({ amount = 123456, seconds = 2 * 3600, kind = "Offline", capped = true })
		task.wait(1) -- (petite animation d'ouverture : 0,35 s)
		-- (le jeu peut avoir créé son propre écran « OfflineGains » entre-temps : on prend celui qui est affiché)
		local offlineGui = nil
		for _, child in player.PlayerGui:GetChildren() do
			if not before[child] and child.Name == "OfflineGains" then
				local overlay = child:FindFirstChild("Overlay")
				if not offlineGui or (overlay and overlay:IsA("GuiObject") and overlay.Visible) then
					offlineGui = child
				end
			end
		end
		checkPhoneFit("pendant ton absence", offlineGui and offlineGui:FindFirstChild("Window", true), Vector2.new(460, 270))
		if offlineGui then
			local offlineOverlay = offlineGui:FindFirstChild("Overlay")
			if offlineOverlay then
				offlineOverlay.Visible = false
			end
			offlineGui:Destroy()
		end
	end
	testPhoneWindows()

	----------------------------------------------------------------------
	-- Modèles perso des ennemis (ReplicatedStorage.EnemyModels, CustomModels.luau) : un modèle « Swarm »
	-- posé pendant la partie sert aux nouveaux écuyers, sans ses scripts (les vrais écuyers du projet sont mis
	-- de côté pendant ce temps) ; les autres types gardent leurs blocs ou leur vrai modèle du projet.
	-- Vérifié par le module (tous les cas), par la galerie Studio (construite avec) et par les
	-- ennemis des parcelles qui apparaissent pendant le test (PlotRenderer).
	----------------------------------------------------------------------
	local function check(ok, message)
		log(if ok then "Info" else "Error", `[{if ok then "PASS" else "FAIL"}] {message}`)
	end
	local Enemies = require(ReplicatedStorage.Shared.Enemies)
	local CustomModels = require(ReplicatedStorage.Shared.CustomModels)
	local modelsFolder = ReplicatedStorage:FindFirstChild("EnemyModels")
	check(modelsFolder ~= nil, "dossier ReplicatedStorage.EnemyModels présent (assets/EnemyModels via Rojo)")
	if not modelsFolder then
		modelsFolder = Instance.new("Folder")
		modelsFolder.Name = "EnemyModels"
		modelsFolder.Parent = ReplicatedStorage
	end
	-- Vrais modèles du projet (assets/EnemyModels, ex. le Roi carmin « Boss_0 ») : leur type les garde, les
	-- vérifications « blocs » ci-dessous en tiennent compte.
	local realModels = {}
	for _, child in modelsFolder:GetChildren() do
		if child:IsA("Model") or child:IsA("BasePart") then
			realModels[string.lower(child.Name)] = child.Name
		end
	end
	-- Nom du vrai modèle attendu pour ce type et ce palier (nil = blocs).
	local function realModelFor(enemyType, palier)
		return realModels[string.lower(`{enemyType}_{palier % 10}`)] or realModels[string.lower(enemyType)]
	end
	-- Vrais écuyers du projet (Swarm_0, Swarm_1...) : ils passeraient avant le modèle « Swarm » de test (nom
	-- exact du palier). Mis de côté pendant ses vérifications, remis dans le dossier pour celles des vrais
	-- modèles, puis à la fin.
	local realSwarms = {}
	for _, child in modelsFolder:GetChildren() do
		if (child:IsA("Model") or child:IsA("BasePart")) and string.match(string.lower(child.Name), "^swarm_?%d*$") then
			table.insert(realSwarms, child)
		end
	end
	local function hideRealSwarms(hidden)
		for _, model in realSwarms do
			model.Parent = if hidden then nil else modelsFolder
		end
		task.wait(0.1)
	end
	hideRealSwarms(true)
	local function scriptsIn(instance)
		local count = 0
		for _, descendant in instance:GetDescendants() do
			if descendant:IsA("LuaSourceContainer") then
				count += 1
			end
		end
		return count
	end
	-- Modèle de test façon Toolbox : pièces ancrées et avec collision, soudées entre elles (WeldConstraint),
	-- 3 scripts (désactivés) dedans. Pièces de 2 studs empilées : 2 * partCount studs de haut.
	local function testModel(name, partCount)
		local model = Instance.new("Model")
		model.Name = name
		for i = 1, partCount do
			local part = Instance.new("Part")
			part.Name = "Piece" .. i
			part.Anchored = true
			part.Size = Vector3.new(2, 2, 2)
			part.Position = Vector3.new(0, 1 + (i - 1) * 2, 0)
			part.Color = Color3.fromRGB(80, 200, 90)
			part.Parent = model
			if i > 1 then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = model:FindFirstChild("Piece1")
				weld.Part1 = part
				weld.Parent = part
			end
		end
		model.PrimaryPart = model:FindFirstChild("Piece1")
		for _, className in { "Script", "LocalScript", "ModuleScript" } do
			local code = Instance.new(className)
			if code:IsA("BaseScript") then
				code.Enabled = false
			end
			code.Parent = model.PrimaryPart
		end
		return model
	end
	-- Modèle utilisé pour ce type et ce palier (nil = blocs), d'après une copie faite par le module.
	local function usedModel(enemyType, palier)
		local root = CustomModels.spawn(enemyType, Enemies.Defs[enemyType], palier)
		local name = root and root:GetAttribute("CustomModel")
		if root then
			root:Destroy()
		end
		return name
	end

	-- 1) Module : modèle « Swarm » (2 pièces) posé pendant la partie.
	-- (task.wait après chaque changement du dossier : les événements peuvent arriver un peu après.)
	local swarmModel = testModel("Swarm", 2)
	swarmModel.Parent = modelsFolder
	task.wait(0.1)
	local swarmDef = Enemies.Defs.Swarm
	local root, entry = CustomModels.spawn("Swarm", swarmDef, 0)
	check(root ~= nil and root:GetAttribute("CustomModel") == "Swarm", "écuyer (Swarm) : le modèle perso « Swarm » remplace les blocs")
	if root and entry then
		local parts, anchored, solid = 0, 0, 0
		for _, descendant in root:GetDescendants() do
			if descendant:IsA("BasePart") then
				parts += 1
				anchored += if descendant.Anchored then 1 else 0
				solid += if descendant.CanCollide or descendant.CanQuery or descendant.CanTouch then 1 else 0
			end
		end
		check(
			scriptsIn(root) == 0 and scriptsIn(swarmModel) == 3,
			`scripts retirés de la copie ({scriptsIn(root)} restant ; l'original en garde {scriptsIn(swarmModel)})`
		)
		check(
			parts == 2 and anchored == 0 and solid == 0 and root.Anchored and root:FindFirstChildWhichIsA("WeldConstraint") ~= nil,
			`2 pièces non ancrées, sans collision, soudées à la racine ancrée ({parts} pièces, {anchored} ancrées, {solid} solides)`
		)
		local expected = CustomModels.targetHeight("Swarm", swarmDef)
		check(math.abs(entry.height - expected) < 0.05, `mis à l'échelle : {string.format("%.2f", entry.height)} studs de haut (attendu {string.format("%.2f", expected)}, 4 avant)`)
		root:Destroy()
	end
	-- Paliers : « Swarm_3 » passe avant « Swarm » aux vagues 31-40 (et 131-140), pas ailleurs.
	local swarm3 = testModel("Swarm_3", 3)
	swarm3.Parent = modelsFolder
	task.wait(0.1)
	local at3, at13, at2 = usedModel("Swarm", 3), usedModel("Swarm", 13), usedModel("Swarm", 2)
	check(at3 == "Swarm_3" and at13 == "Swarm_3" and at2 == "Swarm", `Swarm_3 avant Swarm (palier 3 : {at3}, palier 13 : {at13}, palier 2 : {at2})`)
	swarm3:Destroy()
	task.wait(0.1)
	local after = usedModel("Swarm", 3)
	check(after == "Swarm", `Swarm_3 retiré pendant la partie : retour à « Swarm » (obtenu {after})`)
	-- Les autres types gardent leurs blocs (ou leur vrai modèle du projet).
	local wrong = {}
	for _, enemyType in Enemies.ORDER do
		if enemyType ~= "Swarm" and usedModel(enemyType, 0) ~= realModelFor(enemyType, 0) then
			table.insert(wrong, enemyType)
		end
	end
	check(#wrong == 0, `autres types : blocs, ou leur vrai modèle du projet ({if #wrong == 0 then "tous" else table.concat(wrong, ", ") .. " avec un autre modèle"})`)

	-- Animations de marche et de mort : numéros écrits dans le code (CustomModels.SETTINGS) ou objets Animation
	-- du modèle (« Walking » / « Dead », les noms des exports Meshy). Animations de Roblox (marche et chute R15)
	-- pour le test : la mort doit se charger et se jouer.
	local WALK_TEST_ID, DEATH_TEST_ID = 507777826, 507767968
	-- (Swarm_5 et Swarm_6 peuvent aussi être de vrais écuyers, avec leurs réglages : ceux-ci sont mis de côté
	-- pendant le test puis remis, comme les modèles.)
	local realSettings5, realSettings6 = CustomModels.SETTINGS.swarm_5, CustomModels.SETTINGS.swarm_6
	CustomModels.SETTINGS.swarm_5 = { walk = WALK_TEST_ID, death = DEATH_TEST_ID }
	CustomModels.SETTINGS.swarm_6 = nil
	local swarm5 = testModel("Swarm_5", 2)
	swarm5.Parent = modelsFolder
	task.wait(0.1)
	local root5, entry5 = CustomModels.spawn("Swarm", swarmDef, 5)
	check(
		entry5 ~= nil
			and entry5.animation ~= nil
			and entry5.animation.AnimationId == `rbxassetid://{WALK_TEST_ID}`
			and entry5.deathAnimation ~= nil
			and entry5.deathAnimation.AnimationId == `rbxassetid://{DEATH_TEST_ID}`,
		"réglages du code (CustomModels.SETTINGS) : marche et mort de « Swarm_5 » lues"
	)
	if root5 and entry5 then
		root5.Parent = workspace
		local death = CustomModels.loadDeath(root5, entry5)
		local length = 0
		if death then
			death:Play()
			for _ = 1, 50 do
				length = death.Length
				if length > 0 then
					break
				end
				task.wait(0.1)
			end
			death:Stop(0)
			death:Destroy()
		end
		check(death ~= nil and length > 0, `animation de mort chargée et jouée (durée {string.format("%.2f", length)} s)`)
		root5:Destroy()
	end
	CustomModels.SETTINGS.swarm_5 = realSettings5
	swarm5:Destroy()
	local swarm6 = testModel("Swarm_6", 2)
	for name, id in { Walking = WALK_TEST_ID, Dead = DEATH_TEST_ID } do
		local animation = Instance.new("Animation")
		animation.Name = name
		animation.AnimationId = `rbxassetid://{id}`
		animation.Parent = swarm6
	end
	swarm6.Parent = modelsFolder
	task.wait(0.1)
	local root6, entry6 = CustomModels.spawn("Swarm", swarmDef, 6)
	check(
		entry6 ~= nil
			and entry6.animation ~= nil
			and entry6.animation.AnimationId == `rbxassetid://{WALK_TEST_ID}`
			and entry6.deathAnimation ~= nil
			and entry6.deathAnimation.AnimationId == `rbxassetid://{DEATH_TEST_ID}`,
		"objets Animation « Walking » et « Dead » du modèle reconnus (marche et mort)"
	)
	if root6 then
		root6:Destroy()
	end
	swarm6:Destroy()
	CustomModels.SETTINGS.swarm_6 = realSettings6
	hideRealSwarms(false)

	-- Vrais modèles du projet (assets/EnemyModels : Roi carmin « Boss_0 », troupes carmin...) : nom valable
	-- (<Type> ou <Type>_<palier>), à la bonne hauteur, tournés dans le sens de la marche (orteils, ou tête d'un
	-- cheval, vers -Z de la racine : CustomModels.frontDirection), leurs animations publiées
	-- (CustomModels.SETTINGS) se chargent.
	local realCount = 0
	for lowerName, realName in realModels do
		realCount += 1
		local enemyType, palierText = string.match(realName, "^(%a+)_?(%d*)$")
		local def = enemyType and Enemies.Defs[enemyType]
		if not def then
			check(false, `vrai modèle « {realName} » : nom inconnu (attendu <Type> ou <Type>_<palier>, ex. Boss_0)`)
			continue
		end
		local palier = tonumber(palierText) or 0
		local root, entry = CustomModels.spawn(enemyType, def, palier, CFrame.new(0, 200, 0))
		check(root ~= nil and entry ~= nil and root:GetAttribute("CustomModel") == realName, `« {realName} » : modèle perso utilisé ({enemyType}, palier {palier})`)
		if root and entry then
			local settings = CustomModels.SETTINGS[lowerName]
			local expected = CustomModels.targetHeight(enemyType, def) * (if settings and settings.height then settings.height else 1)
			check(math.abs(entry.height - expected) < 0.1, `« {realName} » : {string.format("%.2f", entry.height)} studs de haut (attendu {string.format("%.2f", expected)})`)
			root.Parent = workspace
			local front = CustomModels.frontDirection(root)
			if front then
				local forward = -root.CFrame:VectorToObjectSpace(front).Z
				check(forward > 0.9, `« {realName} » tourné dans le sens de la marche ({string.format("%.2f", forward)}, 1 = parfait)`)
			else
				say(`« {realName} » : pas d'os pour vérifier son sens de marche`)
			end
			local lengths, expectedTracks = {}, {}
			for label, pair in { marche = { CustomModels.loadWalk, entry.animation }, mort = { CustomModels.loadDeath, entry.deathAnimation } } do
				if not pair[2] then
					continue
				end
				table.insert(expectedTracks, label)
				local track = pair[1](root, entry)
				local length = 0
				if track then
					track:Play()
					for _ = 1, 80 do
						length = track.Length
						if length > 0 then
							break
						end
						task.wait(0.1)
					end
					track:Stop(0)
					track:Destroy()
				end
				lengths[label] = length
			end
			local loaded = 0
			for _, label in expectedTracks do
				loaded += if lengths[label] > 0 then 1 else 0
			end
			check(
				loaded == #expectedTracks,
				`« {realName} » : animations chargées {loaded}/{#expectedTracks} (marche {string.format("%.2f", lengths.marche or 0)} s, mort {string.format("%.2f", lengths.mort or 0)} s)`
			)
			root:Destroy()
		end
	end
	say(`vrais modèles du projet vérifiés : {realCount}`)

	-- Photos « walk_<modèle> » : chaque vrai modèle joue sa marche sur place (comme sur la parcelle), vu de
	-- côté, avec une flèche rouge au sol dans son sens de déplacement (-Z de sa racine, comme PlotRenderer) :
	-- son visage doit regarder vers la pointe de la flèche. Et le sens mesuré par ses os pendant l'animation
	-- (orteils vers l'avant), en chiffres.
	do
		local IdleConfig = require(ReplicatedStorage.Shared.IdleConfig)
		local hidden = {}
		for _, gui in player.PlayerGui:GetChildren() do
			if gui:IsA("ScreenGui") and gui.Enabled then
				gui.Enabled = false
				table.insert(hidden, gui)
			end
		end
		for _, realName in realModels do
			local enemyType, palierText = string.match(realName, "^(%a+)_?(%d*)$")
			local def = enemyType and Enemies.Defs[enemyType]
			if not def then
				continue
			end
			local origin = CFrame.new(40, 300, 40)
			local root, entry = CustomModels.spawn(enemyType, def, tonumber(palierText) or 0, origin)
			if not (root and entry and entry.animation) then
				if root then
					root:Destroy()
				end
				continue
			end
			root.Parent = workspace
			local arrow = Instance.new("Part")
			arrow.Anchored = true
			arrow.CanCollide = false
			arrow.Material = Enum.Material.Neon
			arrow.Color = Color3.fromRGB(230, 40, 40)
			arrow.Size = Vector3.new(0.25, 0.25, def.size * 2)
			arrow.CFrame = origin * CFrame.new(0, -def.size / 2 + 0.15, -def.size * 1.5)
			arrow.Parent = workspace
			local tip = Instance.new("Part")
			tip.Shape = Enum.PartType.Ball
			tip.Anchored = true
			tip.CanCollide = false
			tip.Material = Enum.Material.Neon
			tip.Color = arrow.Color
			tip.Size = Vector3.one * 0.8
			tip.CFrame = origin * CFrame.new(0, -def.size / 2 + 0.15, -def.size * 2.5)
			tip.Parent = workspace
			local speed = def.speed * IdleConfig.ENEMY_SPEED_MULTIPLIER * IdleConfig.enemySpeedFactor(enemyType)
			local track = CustomModels.loadWalk(root, entry)
			local forwardRaw, forwardFixed, earlyFlip, flip = nil, nil, nil, nil
			if track then
				-- Sens mesuré comme en jeu (CustomModels.measureFlip : à plusieurs moments du pas, jamais juste après
				-- Play, où les os sont encore au repos), remis à zéro pour le test. Sens affiché = moyenne sur
				-- plusieurs pas (à un moment du pas, les pieds peuvent pointer vers l'arrière).
				entry.flipWhenAnimated = nil
				entry.flipSamples = nil
				track:Play(0.2, 1, CustomModels.walkRate(entry, speed))
				earlyFlip = CustomModels.measureFlip(root, entry, track)
				task.wait(0.5)
				local rawSum, rawCount = 0, 0
				local deadline = os.clock() + 4
				while flip == nil and os.clock() < deadline do
					task.wait()
					flip = CustomModels.measureFlip(root, entry, track)
					local front = CustomModels.frontDirection(root)
					if front then
						rawSum += -origin:VectorToObjectSpace(front).Z
						rawCount += 1
					end
				end
				forwardRaw = if rawCount > 0 then rawSum / rawCount else nil
				-- Comme PlotRenderer : si l'animation retourne ce modèle, sa racine fait un demi-tour.
				if flip then
					root.CFrame = origin * CFrame.Angles(0, math.pi, 0)
				end
				task.wait(0.2)
				local fixedSum, fixedCount = 0, 0
				local stop = os.clock() + 1.2
				repeat
					task.wait()
					local front = CustomModels.frontDirection(root)
					if front then
						fixedSum += -origin:VectorToObjectSpace(front).Z
						fixedCount += 1
					end
				until os.clock() >= stop
				forwardFixed = if fixedCount > 0 then fixedSum / fixedCount else nil
			end
			local function two(x)
				return if x then string.format("%.2f", x) else "?"
			end
			check(
				forwardFixed ~= nil and forwardFixed > 0.5,
				`« {realName} » marche vers l'avant, animation jouée (en moyenne {two(forwardRaw)} sans correction, {two(forwardFixed)} avec ; 1 = vers l'avant, -1 = à reculons ; retourné : {tostring(flip)})`
			)
			check(earlyFlip == nil, `« {realName} » : sens pas mesuré juste après le lancement de sa marche (obtenu {tostring(earlyFlip)}, attendu nil)`)
			local side = def.size * 2.2 + 3
			look(origin.Position + origin.RightVector * side + Vector3.new(0, def.size * 0.3, 0), origin.Position + Vector3.new(0, 0, -def.size * 0.5))
			shot("walk_" .. realName)
			if track then
				track:Stop(0)
				track:Destroy()
			end
			root:Destroy()
			arrow:Destroy()
			tip:Destroy()
		end
		for _, gui in hidden do
			gui.Enabled = true
		end
		restoreCamera()
	end
	hideRealSwarms(true)

	-- 2) En jeu : les ennemis qui apparaissent sur les parcelles à partir de maintenant (PlotRenderer).
	local live = { swarm = 0, swarmBad = 0, other = 0, otherBad = 0 }
	local liveConnection = nil
	local enemiesFolder = workspace:FindFirstChild("PlotEnemies")
	if enemiesFolder then
		liveConnection = enemiesFolder.ChildAdded:Connect(function(child)
			local enemyType = child:GetAttribute("EnemyType")
			if enemyType == "Swarm" then
				live.swarm += 1
				if child:GetAttribute("CustomModel") ~= "Swarm" or scriptsIn(child) > 0 then
					live.swarmBad += 1
				end
			elseif enemyType then
				local blocks = 0
				for _, piece in child:GetChildren() do
					blocks += if piece:IsA("BasePart") then 1 else 0
				end
				live.other += 1
				-- Blocs, ou un vrai modèle du projet (ex. Normal_0 aux vagues 1-10) ; jamais un modèle de test.
				local custom = child:GetAttribute("CustomModel")
				if custom ~= nil then
					live.otherReal = (live.otherReal or 0) + 1
				end
				if (custom ~= nil and realModels[string.lower(custom)] == nil) or (custom == nil and blocks == 0) then
					live.otherBad += 1
				end
			end
		end)
	end
	local liveStart = os.clock()

	-- 3) Galerie Studio construite avec le modèle : 10 écuyers « modèle perso », les 50 autres en blocs (sauf
	-- les cases des vrais modèles du projet, ex. le boss des vagues 1-10 avec « Boss_0 »).
	if not ReplicatedStorage:FindFirstChild("__AutoTestGallery") then
		local request = Instance.new("BoolValue")
		request.Name = "__AutoTestGallery"
		request.Parent = ReplicatedStorage
	end
	for _ = 1, 100 do
		if ReplicatedStorage:GetAttribute("GalleryReady") then
			break
		end
		task.wait(0.2)
	end
	local gallery = workspace:FindFirstChild("EnemyGallery (Studio)")
	check(gallery ~= nil and ReplicatedStorage:GetAttribute("GalleryReady") == true, "galerie des ennemis construite")
	if gallery then
		local customSwarm, swarmTotal, customOther, otherTotal, galleryScripts = 0, 0, 0, 0, 0
		local plaques = { perso = 0, blocs = 0 }
		-- Cases des autres types qui doivent montrer un vrai modèle du projet (10 paliers dans la galerie).
		local expectedOther, unexpectedOther = 0, 0
		for _, enemyType in Enemies.ORDER do
			if enemyType ~= "Swarm" then
				for palier = 0, 9 do
					expectedOther += if realModelFor(enemyType, palier) then 1 else 0
				end
			end
		end
		-- Dans le Workspace : Piece1 juste sous le centre de la racine (le modèle suit sa racine) et Piece2
		-- toujours soudée au-dessus, à l'écart mis à l'échelle (hauteur visée / 2 pour 2 pièces).
		local expectedGap = CustomModels.targetHeight("Swarm", swarmDef) / 2
		local worstGap, worstOffset = 0, 0
		for _, child in gallery:GetChildren() do
			local enemyType = child:GetAttribute("EnemyType")
			if enemyType == "Swarm" then
				swarmTotal += 1
				customSwarm += if child:GetAttribute("CustomModel") == "Swarm" then 1 else 0
				galleryScripts += scriptsIn(child)
				local piece1, piece2 = child:FindFirstChild("Piece1", true), child:FindFirstChild("Piece2", true)
				if child:IsA("BasePart") and piece1 and piece2 then
					worstGap = math.max(worstGap, math.abs((piece2.Position - piece1.Position).Magnitude - expectedGap))
					local offset = child.CFrame:PointToObjectSpace(piece1.Position)
					worstOffset = math.max(worstOffset, Vector3.new(offset.X, 0, offset.Z).Magnitude)
				else
					worstGap = math.huge
				end
			elseif enemyType then
				otherTotal += 1
				local custom = child:GetAttribute("CustomModel")
				customOther += if custom ~= nil then 1 else 0
				unexpectedOther += if custom ~= nil and realModels[string.lower(custom)] == nil then 1 else 0
			elseif child.Name == "Plaque" then
				local label = child:FindFirstChildWhichIsA("TextLabel", true)
				local text = label and label.Text or ""
				if text:find("modèle perso") then
					plaques.perso += 1
				elseif text == "blocs" then
					plaques.blocs += 1
				end
			end
		end
		check(
			swarmTotal > 0
				and customSwarm == swarmTotal
				and galleryScripts == 0
				and otherTotal > 0
				and customOther == expectedOther
				and unexpectedOther == 0,
			`galerie : écuyers avec le modèle perso {customSwarm}/{swarmTotal} (scripts {galleryScripts}), autres : {customOther} avec leur vrai modèle (attendu {expectedOther}), {otherTotal - customOther} en blocs`
		)
		check(
			plaques.perso == swarmTotal + expectedOther and plaques.blocs == otherTotal - expectedOther,
			`galerie : plaques « modèle perso » {plaques.perso} (attendu {swarmTotal + expectedOther}) et « blocs » {plaques.blocs} (attendu {otherTotal - expectedOther})`
		)
		check(
			swarmTotal > 0 and worstGap < 0.05 and worstOffset < 0.05,
			`galerie : modèle perso porté par sa racine, pièces soudées restées ensemble après la mise à l'échelle (écart {string.format("%.3f", worstGap)}, décalage {string.format("%.3f", worstOffset)} studs)`
		)
		local row = ReplicatedStorage:GetAttribute("GalleryRow1")
		local lookDirection = ReplicatedStorage:GetAttribute("GalleryLook")
		if typeof(row) == "Vector3" and typeof(lookDirection) == "Vector3" then
			-- Captures sans les fenêtres du jeu (les autres tests en ouvrent pendant ce temps).
			local hidden = {}
			for _, gui in player.PlayerGui:GetChildren() do
				if gui:IsA("ScreenGui") and gui.Enabled then
					gui.Enabled = false
					table.insert(hidden, gui)
				end
			end
			look(row - lookDirection * 16 + Vector3.new(0, 9, 0), row)
			shot("gallery_custom_model")
			-- Le Roi carmin de près, de face (s'il est dans le projet).
			for _, child in gallery:GetChildren() do
				if child:IsA("BasePart") and child:GetAttribute("CustomModel") == "Boss_0" then
					look(child.Position - lookDirection * 13 + Vector3.new(0, 3, 0), child.Position + Vector3.new(0, 1, 0))
					shot("gallery_boss_0")
					break
				end
			end
			for _, gui in hidden do
				gui.Enabled = true
			end
			restoreCamera()
		end
	end

	-- Fin de l'observation des parcelles : au plus 30 s après la pose du modèle, moins si des ennemis d'autres
	-- types sont déjà apparus (les vagues du test n'ont pas forcément d'écuyers).
	while os.clock() - liveStart < 30 and live.other < 3 do
		task.wait(0.5)
	end
	if liveConnection then
		liveConnection:Disconnect()
	end
	if live.swarm > 0 then
		check(live.swarmBad == 0, `parcelles : nouveaux écuyers avec le modèle perso {live.swarm - live.swarmBad}/{live.swarm}`)
	else
		say("parcelles : aucun écuyer apparu pendant le test (pas de Levée) : modèle vérifié par le module et la galerie")
	end
	if live.other > 0 then
		check(
			live.otherBad == 0,
			`parcelles : nouveaux ennemis des autres types en blocs ou avec leur vrai modèle {live.other - live.otherBad}/{live.other} (dont {live.otherReal or 0} vrais modèles)`
		)
	else
		say("parcelles : aucun nouvel ennemi d'un autre type pendant le test")
	end
	swarmModel:Destroy()
	hideRealSwarms(false) -- le reste de la partie retrouve les vrais écuyers du projet (ou les blocs)

	----------------------------------------------------------------------
	-- Classé : bouton « ⚔ S'INSCRIRE AU CLASSÉ » seulement dans le cercle de l'arène, statut de la recherche (en
	-- bas à droite, au-dessus du panneau des tours s'il est ouvert) et fenêtre « MATCH TROUVÉ ! ». Le scénario
	-- serveur joue un adversaire factice (file en mémoire dans Studio, pas de téléportation) : il donne la main
	-- au client avec l'attribut AutoTestRanked de ReplicatedStorage (« Client »), puis attend son inscription
	-- et son ACCEPTER, envoyés par les vrais remotes (comme les boutons : un plugin ne peut pas cliquer).
	-- Dans sa propre fonction (limite des 200 variables locales de Luau).
	----------------------------------------------------------------------
	local function testRanked()
		local function waitFor(condition, timeout)
			local deadline = os.clock() + timeout
			while os.clock() < deadline do
				if condition() then
					return true
				end
				task.wait(0.1)
			end
			return condition() == true
		end
		-- Vraiment à l'écran : lui et tous ses parents visibles, dans un ScreenGui allumé.
		local function shown(object)
			local current = object
			while current and not current:IsA("ScreenGui") do
				if current:IsA("GuiObject") and not current.Visible then
					return false
				end
				current = current.Parent
			end
			return current ~= nil and current.Enabled
		end
		local function queueState()
			return player:GetAttribute("QueueState") or "Idle"
		end
		local function inCircle(value)
			return player:GetAttribute("InRankedCircle") == value
		end
		local lobby = player.PlayerGui:FindFirstChild("Lobby")
		local signUpButton = lobby and lobby:FindFirstChild("SignUpButton", true)
		local status = lobby and lobby:FindFirstChild("QueueStatus", true)
		local statusText = status and status:FindFirstChild("StatusText")
		local cancelButton = status and status:FindFirstChild("CancelButton")
		local acceptGui = player.PlayerGui:FindFirstChild("RankedAccept")
		local window = acceptGui and acceptGui:FindFirstChild("Window", true)
		local found = signUpButton ~= nil and statusText ~= nil and cancelButton ~= nil and window ~= nil
		check(found, "classé : bouton « S'INSCRIRE », statut de la recherche et fenêtre « MATCH TROUVÉ ! » présents")
		local turn = waitFor(function()
			return ReplicatedStorage:GetAttribute("AutoTestRanked") == "Client"
		end, 120)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not (found and turn and root) then
			check(false, `classé : test du client impossible (main donnée par le serveur : {turn}, personnage : {root ~= nil})`)
			return
		end
		restoreCamera()
		local home = root.CFrame
		local circle = PlotLayout.RANKED_CIRCLE_POSITION
		local inside = CFrame.new(circle + Vector3.new(0, 3, 0))
		local outside = CFrame.new(circle + Vector3.new(0, 3, PlotLayout.RANKED_CIRCLE_RADIUS + 12))

		-- Hors du cercle : pas de bouton. Dans le cercle : le bouton apparaît. Ressorti : il disparaît.
		root.CFrame = outside
		local outOk = waitFor(function()
			return inCircle(false)
		end, 3)
		check(outOk and not shown(signUpButton), `classé : hors du cercle, pas de bouton « S'INSCRIRE » (InRankedCircle = {player:GetAttribute("InRankedCircle")})`)
		root.CFrame = inside
		local inOk = waitFor(function()
			return inCircle(true) and shown(signUpButton)
		end, 3)
		check(
			inOk and string.find(signUpButton.Text, "S'INSCRIRE AU CLASSÉ", 1, true) ~= nil,
			`classé : dans le cercle, bouton « {signUpButton.Text} » affiché`
		)
		-- Ni sur la carte de rang et la colonne de gauche (x < 276), ni sur le panneau des tours (en bas à droite,
		-- ~316 px de haut), ni sur le chat (en bas à gauche, moins haut que le panneau des tours).
		local screen = lobby.AbsoluteSize
		if screen.X >= 1000 then
			local left, top = signUpButton.AbsolutePosition.X, signUpButton.AbsolutePosition.Y
			local bottom = top + signUpButton.AbsoluteSize.Y
			local placed = left >= 276 and bottom <= screen.Y - 316
			check(
				placed,
				`classé : bouton « S'INSCRIRE » sans couvrir la colonne de gauche, le chat ni le panneau des tours (x {math.floor(left)}, y de {math.floor(top)} à {math.floor(bottom)}, écran {math.floor(screen.X)} x {math.floor(screen.Y)})`
			)
		end
		shot("ranked_signup")
		root.CFrame = outside
		check(
			waitFor(function()
				return inCircle(false) and not shown(signUpButton)
			end, 3),
			"classé : ressorti du cercle, le bouton disparaît"
		)

		-- Inscription dans le cercle (vrai remote, comme le bouton) : statut « Recherche d'un adversaire… » + ANNULER.
		root.CFrame = inside
		waitFor(function()
			return inCircle(true)
		end, 3)
		ReplicatedStorage.Remotes.QueueAction:FireServer("Join")
		local searching = waitFor(function()
			return queueState() == "Searching" and shown(status)
		end, 5)
		task.wait(0.3)
		check(
			searching
				and string.find(statusText.Text, "Recherche d'un adversaire", 1, true) ~= nil
				and shown(cancelButton)
				and cancelButton.Text == "ANNULER"
				and not shown(signUpButton),
			`classé : inscrit -> « {statusText.Text} » et ANNULER en bas à droite, plus de bouton « S'INSCRIRE »`
		)
		shot("ranked_searching")
		-- Panneau des tours ouvert (PlotUI, en bas à droite) : le statut monte juste au-dessus.
		local plotGui = player.PlayerGui:FindFirstChild("Plot")
		local towerPanel = plotGui and plotGui:FindFirstChild("TowerPanel")
		if towerPanel then
			local wasVisible = towerPanel.Visible
			towerPanel.Visible = true
			task.wait(0.4)
			local statusBottom = status.AbsolutePosition.Y + status.AbsoluteSize.Y
			local panelTop = towerPanel.AbsolutePosition.Y
			check(
				statusBottom <= panelTop + 1,
				`classé : panneau des tours ouvert -> le statut passe au-dessus (bas du statut {math.floor(statusBottom)}, haut du panneau {math.floor(panelTop)})`
			)
			towerPanel.Visible = wasVisible
		else
			check(false, "classé : panneau des tours (PlotUI « TowerPanel ») introuvable")
		end

		-- Il repart jouer, toujours inscrit : le serveur fait s'inscrire un adversaire -> « MATCH TROUVÉ ! ».
		root.CFrame = home
		local pending = waitFor(function()
			return queueState() == "Pending" and shown(window)
		end, 20)
		task.wait(0.3)
		local title = window:FindFirstChild("Title")
		local opponent = window:FindFirstChild("Opponent")
		local acceptButton = window:FindFirstChild("AcceptButton")
		local refuseButton = window:FindFirstChild("RefuseButton")
		local timer = window:FindFirstChild("Timer")
		local waiting = window:FindFirstChild("Waiting")
		local opponentName = player:GetAttribute("MatchOpponent")
		check(
			pending
				and title and string.find(title.Text, "MATCH TROUVÉ", 1, true) ~= nil
				and typeof(opponentName) == "string" and opponent and string.find(opponent.Text, opponentName, 1, true) ~= nil
				and acceptButton and shown(acceptButton) and acceptButton.Text == "ACCEPTER"
				and refuseButton and shown(refuseButton) and refuseButton.Text == "REFUSER"
				and timer and shown(timer),
			`classé : fenêtre « {title and title.Text} » : « {opponent and opponent.Text} », barre du temps, ACCEPTER et REFUSER`
		)
		shot("ranked_accept")
		checkPhoneFit("MATCH TROUVÉ !", window, Vector2.new(470, 290)) -- (ACCEPTER et REFUSER dans l'écran d'un téléphone)
		ReplicatedStorage.Remotes.QueueAction:FireServer("Accept")
		local waitingOk = waitFor(function()
			return queueState() == "Accepted" and waiting ~= nil and shown(waiting)
				and string.find(waiting.Text, "En attente de l'adversaire", 1, true) ~= nil
		end, 5)
		check(
			waitingOk and not shown(acceptButton) and not shown(refuseButton),
			`classé : ACCEPTER -> « {waiting and waiting.Text} », plus de boutons`
		)

		-- L'adversaire accepte : le match partirait (Studio : pas de téléportation), fenêtre et statut se ferment.
		local closed = waitFor(function()
			return queueState() == "Idle" and not shown(window) and not shown(status)
		end, 15)
		check(closed, `classé : les deux ont accepté -> fenêtre et statut fermés, plus inscrit ({queueState()})`)
	end
	testRanked()

	----------------------------------------------------------------------
	-- Tuto des nouveaux joueurs (TutorialUI.luau, Hub/Tutorial.luau) : jamais tout seul pendant les tests
	-- automatiques (le joueur de test est pourtant nouveau). Le scénario serveur rend la parcelle « nouveau joueur »
	-- (aucune tour, record 1, aucun lancer, 50 pièces), puis donne la main (attribut AutoTestTutorial de
	-- ReplicatedStorage = « Client »). Le client relance le tuto (« Replay », Studio seulement), vérifie le panneau et
	-- le guide (capture tutorial_step1), puis valide chaque étape par les vraies actions : personnage dans le cercle,
	-- puis sur sa parcelle (mort et réapparition au passage : le rayon repart du nouveau personnage), une tour posée
	-- puis améliorée (remote PlotAction, comme PlotUI), un lancer x1 de l'autel (remote MachineAction), la forge
	-- ouverte comme par son invite (CMD:OpenMachine:Bonus). Fin : drapeau reçu du serveur, guide retiré. Puis
	-- « Passer » (le remote de ce bouton : un plugin ne peut pas cliquer) sur un 2e essai.
	-- Dans sa propre fonction (limite des 200 variables locales de Luau).
	----------------------------------------------------------------------
	local function testTutorial()
		local function waitFor(condition, timeout)
			local deadline = os.clock() + timeout
			while os.clock() < deadline do
				if condition() then
					return true
				end
				task.wait(0.1)
			end
			return condition() == true
		end
		-- Vraiment à l'écran : lui et tous ses parents visibles, dans un ScreenGui allumé.
		local function shown(object)
			local current = object
			while current and not current:IsA("ScreenGui") do
				if current:IsA("GuiObject") and not current.Visible then
					return false
				end
				current = current.Parent
			end
			return current ~= nil and current.Enabled
		end
		local tutorialGui = player.PlayerGui:FindFirstChild("Tutorial")
		local panel = tutorialGui and tutorialGui:FindFirstChild("Panel")
		local title = panel and panel:FindFirstChild("Title")
		local nextButton = panel and panel:FindFirstChild("NextButton")
		local skipButton = panel and panel:FindFirstChild("SkipButton")
		local found = panel ~= nil and title ~= nil and nextButton ~= nil and skipButton ~= nil
		check(found, "tuto : panneau présent (PlayerGui.Tutorial : titre, « Suivant », « Passer »)")
		check(
			found and not shown(panel) and workspace:FindFirstChild("TutorialGuide") == nil and player:GetAttribute("TutorialDone") == false,
			`tuto : jamais tout seul pendant les tests automatiques (nouveau joueur : TutorialDone = {tostring(player:GetAttribute("TutorialDone"))})`
		)
		local turn = waitFor(function()
			return ReplicatedStorage:GetAttribute("AutoTestTutorial") == "Client"
		end, 150)
		local plotIndex = player:GetAttribute("Plot")
		local plot = plotIndex and workspace.Hub.Plots:FindFirstChild("Plot" .. plotIndex)
		if not (found and turn and plot) then
			check(false, `tuto : test du client impossible (main donnée par le serveur : {turn}, parcelle {plotIndex})`)
			return
		end
		local remotes = ReplicatedStorage:WaitForChild("Remotes")
		local function rootNow()
			local character = player.Character
			return character and character:FindFirstChild("HumanoidRootPart")
		end
		local function titleHas(text)
			return shown(panel) and string.find(title.Text, text, 1, true) ~= nil
		end
		-- Guide : rayon doré de la HumanoidRootPart du personnage ACTUEL vers la cible, flèche ▼ au-dessus d'elle.
		local function guide()
			return workspace:FindFirstChild("TutorialGuide")
		end
		local function guideOk()
			local anchor, root = guide(), rootNow()
			local beam = anchor and anchor:FindFirstChild("Beam")
			local marker = anchor and anchor:FindFirstChild("Marker")
			local arrow = marker and marker:FindFirstChild("Arrow")
			return root ~= nil and beam ~= nil and beam.Enabled and beam.Attachment0 ~= nil and beam.Attachment0.Parent == root
				and beam.Attachment1 ~= nil and beam.Attachment1.Parent == anchor
				and marker ~= nil and marker.Enabled and arrow ~= nil and arrow.Text == "▼"
		end
		-- Distance au sol entre la cible du guide et ce point.
		local function guideTo(position)
			local anchor = guide()
			if not anchor or not position then
				return math.huge
			end
			local offset = anchor.Position - position
			return Vector3.new(offset.X, 0, offset.Z).Magnitude
		end
		local function guideGone()
			local root = rootNow()
			return guide() == nil and (root == nil or root:FindFirstChild("TutorialGuideRoot") == nil)
		end
		restoreCamera()

		-- Relance : étape 1, panneau en haut de l'écran, rayon et flèche vers le cercle classé. Le personnage est d'abord
		-- posé à un endroit neutre (30 studs derrière le cercle, loin de sa parcelle) : les tests d'avant (classé...)
		-- peuvent l'avoir laissé près du cercle ou chez lui, et une étape déjà faite se valide toute seule.
		local circle = PlotLayout.RANKED_CIRCLE_POSITION
		-- Les tests d'avant cachent les fenêtres des machines sans les fermer : aucune machine « ouverte » (sinon le
		-- tuto cache ses boutons, voir TutorialUI.refreshButtons).
		local machinesGui = player.PlayerGui:FindFirstChild("Machines")
		if machinesGui then
			machinesGui:SetAttribute("OpenMachine", nil)
		end
		local away = circle - PlotLayout.cframe(plotIndex).Position
		away = Vector3.new(away.X, 0, away.Z)
		away = if away.Magnitude > 1e-3 then away.Unit else Vector3.new(0, 0, 1)
		local neutralRoot = rootNow()
		if neutralRoot then
			neutralRoot.CFrame = CFrame.new(circle + away * 30 + Vector3.new(0, 3, 0))
			task.wait(0.5)
		end
		remotes.TutorialAction:FireServer("Replay")
		local started = waitFor(function()
			return titleHas("1/6") and guideOk() and shown(nextButton) and shown(skipButton)
		end, 8)
		check(
			started and guideTo(circle) < 1 and nextButton.Text == "Suivant" and skipButton.Text == "Passer",
			`tuto : relancé -> « {title.Text} », rayon et flèche vers le cercle classé (à {math.floor(math.min(guideTo(circle), 9999))} studs), boutons « {nextButton.Text} » et « {skipButton.Text} »`
		)
		local screen = tutorialGui.AbsoluteSize
		local at = panel.AbsolutePosition - tutorialGui.AbsolutePosition
		local size = panel.AbsoluteSize
		check(
			at.X >= 0 and at.Y >= 0 and at.X + size.X <= screen.X + 1 and at.Y <= screen.Y / 3 and at.Y + size.Y <= screen.Y
				and (at.X >= 16 + 260 or at.Y >= 16 + 130),
			`tuto : panneau en haut de l'écran, entier, sans couvrir la carte de rang (x {math.floor(at.X)}, y {math.floor(at.Y)}, {math.floor(size.X)} x {math.floor(size.Y)} px, écran {math.floor(screen.X)} x {math.floor(screen.Y)})`
		)
		shot("tutorial_step1")

		-- Téléphone : le panneau des tours (PlotUI) ouvert monte jusque sous le tuto -> le tuto se cache (cartes et
		-- boutons des tours visibles), puis revient quand il se ferme. L'écran du test est grand : le panneau des
		-- tours est placé en haut de l'écran le temps de la vérification, puis remis à sa place.
		local plotGui = player.PlayerGui:FindFirstChild("Plot")
		local towerPanel = plotGui and plotGui:FindFirstChild("TowerPanel")
		if towerPanel then
			local wasVisible, wasAnchor, wasPosition = towerPanel.Visible, towerPanel.AnchorPoint, towerPanel.Position
			towerPanel.AnchorPoint = Vector2.new(0.5, 0) -- centré, à 100 px du haut : sous le tuto, quel que soit l'écran
			towerPanel.Position = UDim2.new(0.5, 0, 0, 100)
			towerPanel.Visible = true
			local hidden = waitFor(function()
				return not shown(panel)
			end, 3)
			towerPanel.Visible = wasVisible
			towerPanel.AnchorPoint = wasAnchor
			towerPanel.Position = wasPosition
			local back = waitFor(function()
				return shown(panel) and titleHas("1/6")
			end, 3)
			check(
				hidden and back,
				`tuto : panneau des tours ouvert par-dessus (téléphone) -> tuto caché ({hidden}), puis de retour à sa fermeture ({back})`
			)
		else
			check(false, "tuto : panneau des tours (PlotUI « TowerPanel ») introuvable")
		end

		-- 1) La zone classée : le personnage entre dans le cercle -> étape 2, rayon vers sa parcelle.
		local root = rootNow()
		if root then
			root.CFrame = CFrame.new(circle + Vector3.new(0, 3, 0))
		end
		local step2 = waitFor(function()
			return titleHas("2/6") and guideOk() and guideTo(PlotLayout.toWorld(plotIndex, Vector3.new(0.5, 0, -22))) < 1
		end, 15)
		check(step2, `tuto : étape 1 validée dans le cercle -> « {title.Text} », rayon vers sa parcelle`)

		-- 2) Ta parcelle : retour chez lui (son point d'apparition).
		root = rootNow()
		if root then
			root.CFrame = CFrame.new(PlotLayout.toWorld(plotIndex, PlotLayout.PLAYER_SPAWN))
		end
		local step3 = waitFor(function()
			return titleHas("3/6") and guideOk()
		end, 15)
		check(step3, `tuto : étape 2 validée sur sa parcelle -> « {title.Text} »`)

		-- Mort et réapparition (comme « Réinitialiser ») : le tuto continue, le rayon repart du nouveau personnage.
		local oldCharacter = player.Character
		local humanoid = oldCharacter and oldCharacter:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Health = 0
			humanoid:ChangeState(Enum.HumanoidStateType.Dead)
		end
		local respawned = waitFor(function()
			return player.Character ~= oldCharacter and titleHas("3/6") and guideOk()
		end, 20)
		check(respawned, `tuto : après une mort, le rayon repart du nouveau personnage (étape gardée : « {title.Text} »)`)
		task.wait(0.5) -- le serveur le remet sur sa parcelle (Plots.sendHome)

		-- 3) Poser une tour (remote PlotAction, comme une carte de PlotUI) sur l'emplacement sous la flèche.
		local spotIndex = nil
		for _, pad in plot.Spots:GetChildren() do
			if pad:IsA("BasePart") and guideTo(pad.Position) < 1 then
				spotIndex = pad:GetAttribute("SpotIndex")
			end
		end
		local pad = spotIndex and plot.Spots:FindFirstChild("Spot" .. spotIndex)
		check(pad ~= nil and pad:GetAttribute("Unlocked") == true, `tuto : étape 3, la flèche montre un emplacement libre (n° {spotIndex})`)
		-- Panneau des tours ouvert (comme après un clic sur l'emplacement) : la carte de l'Archer est entourée d'or.
		local IdleTowers = require(ReplicatedStorage.Shared.IdleTowers)
		local body = panel:FindFirstChild("Text")
		local cardsGui = player.PlayerGui:FindFirstChild("Plot")
		local cardsPanel = cardsGui and cardsGui:FindFirstChild("TowerPanel")
		local archerCard = cardsPanel and cardsPanel:FindFirstChild("Card_MachineGun", true)
		if cardsPanel and archerCard then
			local wasVisible = cardsPanel.Visible
			cardsPanel.Visible = true
			local ringed = waitFor(function()
				local ring = archerCard:FindFirstChild("TutorialHighlight")
				return ring ~= nil and ring:FindFirstChildWhichIsA("UIStroke") ~= nil
			end, 3)
			local elsewhere = 0
			for _, descendant in cardsPanel:GetDescendants() do
				if descendant.Name == "TutorialHighlight" and descendant.Parent ~= archerCard then
					elsewhere += 1
				end
			end
			cardsPanel.Visible = wasVisible
			local cleared = waitFor(function()
				return archerCard:FindFirstChild("TutorialHighlight") == nil
			end, 3)
			check(
				ringed and elsewhere == 0 and cleared and body ~= nil and string.find(body.Text, IdleTowers.Defs.MachineGun.displayName, 1, true) ~= nil,
				`tuto : étape 3, texte « {IdleTowers.Defs.MachineGun.displayName} » et sa carte entourée d'or quand le panneau des tours est ouvert ({ringed}, ailleurs : {elsewhere}), cadre retiré à sa fermeture ({cleared})`
			)
		else
			check(false, "tuto : carte de l'Archer (PlotUI « Card_MachineGun ») introuvable")
		end
		spotIndex = spotIndex or 1
		remotes.PlotAction:FireServer("Place", spotIndex, "MachineGun")
		local step4 = waitFor(function()
			return titleHas("4/6") and guideOk() and guideTo(PlotLayout.toWorld(plotIndex, PlotLayout.SPOTS[spotIndex])) < 1
		end, 15)
		check(step4, `tuto : tour posée -> « {title.Text} », flèche sur la tour`)

		-- 4) L'améliorer (le serveur refuse 2 actions à moins de 0,15 s d'écart, 0,3 s pour les machines).
		task.wait(0.5)
		remotes.PlotAction:FireServer("Upgrade", spotIndex)
		local altar = plot:FindFirstChild("TowerMachine")
		local step5 = waitFor(function()
			return titleHas("5/6") and guideOk() and altar ~= nil and guideTo(altar.Position) < 1
		end, 15)
		check(step5, `tuto : tour améliorée -> « {title.Text} », flèche sur l'autel`)

		-- 5) Un lancer x1 de l'autel (3 pièces au record 1).
		task.wait(0.5)
		remotes.MachineAction:FireServer("SpinTower", 1)
		local forge = plot:FindFirstChild("BonusMachine")
		local body6 = panel:FindFirstChild("Text")
		local machines6 = player.PlayerGui:FindFirstChild("Machines")
		local step6 = waitFor(function()
			return titleHas("6/6") and guideOk() and forge ~= nil and guideTo(forge.Position) < 1
		end, 15)
		-- Fenêtre de l'autel ouverte par le résultat du lancer : « ferme d'abord l'autel » (son X entouré d'or), pas de
		-- « Terminer » ni de « Passer » tant qu'elle est ouverte ; fermée (comme MachineUI) : la forge et « Terminer ».
		local altarShown = machines6 ~= nil and machines6:GetAttribute("OpenMachine") == "Tower"
		local closeAsked = not altarShown
			or waitFor(function()
				local closeButton = machines6:FindFirstChild("CloseButton", true)
				return body6 ~= nil
					and string.find(body6.Text, "Ferme la fenêtre de l'autel", 1, true) ~= nil
					and not shown(nextButton)
					and not shown(skipButton)
					and closeButton ~= nil
					and closeButton:FindFirstChild("TutorialHighlight") ~= nil
			end, 5)
		if machines6 then
			machines6:SetAttribute("OpenMachine", nil)
			for _, child in machines6:GetChildren() do
				if child:IsA("TextButton") and child.Size == UDim2.fromScale(1, 1) then
					child.Visible = false
				end
			end
		end
		local forgeText = waitFor(function()
			return shown(nextButton) and nextButton.Text == "Terminer" and shown(skipButton) and body6 ~= nil
				and string.find(body6.Text, "Forge runique", 1, true) ~= nil
		end, 5)
		check(
			step6 and closeAsked and forgeText,
			`tuto : lancer de l'autel -> « {title.Text} », flèche sur la forge ; autel ouvert ({altarShown}) : « ferme l'autel », X entouré d'or, sans boutons ({closeAsked}) ; fermé : texte de la forge et « {nextButton.Text} » ({forgeText})`
		)
		-- Avec les parcelles des autres (PlotAccess.luau) : l'autel et la forge montrés par la flèche sont ceux de SA
		-- parcelle, et leurs invites « Ouvrir » restent allumées (seules celles des autres parcelles sont éteintes).
		local altarPrompt = altar and altar:FindFirstChildOfClass("ProximityPrompt")
		local forgePrompt = forge and forge:FindFirstChildOfClass("ProximityPrompt")
		check(
			altarPrompt ~= nil and altarPrompt.Enabled and forgePrompt ~= nil and forgePrompt.Enabled,
			`tuto : l'autel et la forge montrés par la flèche ont leur invite « Ouvrir » allumée (autel : {altarPrompt and altarPrompt.Enabled}, forge : {forgePrompt and forgePrompt.Enabled})`
		)

		-- 6) La forge, ouverte comme par son invite : tuto fini, drapeau reçu du serveur, plus rien à l'écran.
		task.wait(0.5)
		say("CMD:OpenMachine:Bonus")
		local finished = waitFor(function()
			return not shown(panel) and guideGone() and player:GetAttribute("TutorialDone") == true
		end, 15)
		check(
			finished,
			`tuto : forge ouverte -> tuto fini, panneau caché, guide retiré, drapeau reçu (TutorialDone = {tostring(player:GetAttribute("TutorialDone"))})`
		)
		-- Pendant que la forge est ouverte, le tuto n'a ni « Terminer » ni « Passer » (sinon le X d'une fenêtre réduite
		-- pouvait tomber dessus). Ici le tuto est fini ; on vérifie la règle au 2e essai ci-dessous.
		-- (fenêtre de la forge : son voile caché, comme pour les défis plus haut, et plus de machine ouverte)
		local machines = player.PlayerGui:FindFirstChild("Machines")
		for _, child in (if machines then machines:GetChildren() else {}) do
			if child:IsA("TextButton") and child.Size == UDim2.fromScale(1, 1) then
				child.Visible = false
			end
		end

		-- « Passer » sur un 2e essai : fini tout de suite, à l'étape 1. D'abord avec la forge encore « ouverte » :
		-- pas de « Passer » (ni « Suivant ») tant qu'une machine est ouverte ; puis machine fermée : il revient.
		task.wait(0.8) -- anti-spam du serveur (un message toutes les 0,5 s)
		remotes.TutorialAction:FireServer("Replay")
		local hiddenWhileOpen = machines ~= nil
			and machines:GetAttribute("OpenMachine") == "Bonus"
			and waitFor(function()
				return titleHas("1/6") and not shown(skipButton) and not shown(nextButton)
			end, 8)
		if machines then
			machines:SetAttribute("OpenMachine", nil) -- (comme MachineUI quand on ferme sa fenêtre)
		end
		local again = waitFor(function()
			return titleHas("1/6") and guideOk() and shown(skipButton) and shown(nextButton)
		end, 8)
		check(
			hiddenWhileOpen and again,
			`tuto : 2e essai -> « {title.Text} » ; forge ouverte : ni « Passer » ni « Suivant » ({hiddenWhileOpen}) ; fermée : « {skipButton.Text} » et « {nextButton.Text} » affichés ({again})`
		)
		task.wait(0.8)
		remotes.TutorialAction:FireServer("Skip", 1)
		local skipped = waitFor(function()
			return not shown(panel) and guideGone() and player:GetAttribute("TutorialDone") == true
		end, 8)
		check(
			skipped,
			`tuto : « Passer » -> tuto fini, panneau caché, guide retiré (TutorialDone = {tostring(player:GetAttribute("TutorialDone"))})`
		)
	end
	testTutorial()

	-- Tout à la fin (après tout le reste, pour ne rien changer aux autres vérifications) : la version anglaise
	-- (voir englishAudit en haut du fichier).
	englishAudit("hub")
end

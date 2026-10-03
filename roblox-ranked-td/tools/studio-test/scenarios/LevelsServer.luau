-- Test du JEU (niveaux et camp d'entraînement), côté serveur : tools/studio-test/run.ps1.
-- 0) Le jeu ne contient plus que les niveaux et le camp : données, remotes, map (plus rien de l'ancien jeu).
-- 1) La PARCELLE du joueur est son camp d'entraînement : sa tour posée sur un socle tire sur des cibles, étiquettes,
--    bâtiments, tableau, évolution d'une tour, 2e emplacement ; qui reçoit les cibles et les tirs de quel camp.
-- 2) Puis, seul (le client attend) : six combats en même temps (mesure), un niveau PERDU par celui qui pose 2 Archers
--    puis attend, le même niveau gagné en posant et en améliorant tout, récompenses, « Rejouer », niveau suivant,
--    abandon, boutique à prix fixes, camp d'entraînement (emplacements, absence), ordre de la barre rapide,
--    améliorations débloquées par l'entraînement, le 2e TERRITOIRE (niveaux 11 à 20 : autre carte, autres monstres,
--    plus de pièces). Tout passe par les mêmes demandes que le remote LevelAction (StudioDebug « Levels », « Action »).
-- 3) Il remet le joueur à zéro et donne la main au client (attribut LevelsTestPhase = "Client" de
--    ReplicatedStorage) : scenarios/LevelsClient.luau joue avec la vraie interface.
-- 4) Quand le client a fini (« LEVELS:client=done » dans son journal), il vérifie ce que le serveur a gardé.
-- StudioDebug n'existe que dans Studio.
return function(log)
	local HttpService = game:GetService("HttpService")
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local dbg = game:GetService("ServerStorage"):WaitForChild("StudioDebug", 30)
	local Levels = require(ReplicatedStorage:WaitForChild("Shared").Levels)
	local PlotLayout = require(ReplicatedStorage.Shared.PlotLayout)

	local function check(ok, message)
		log(if ok then "Info" else "Error", `[{if ok then "PASS" else "FAIL"}] niveaux : {message}`)
	end
	local function near(a, b, tolerance)
		return typeof(a) == "number" and math.abs(a - b) <= (tolerance or 0.5)
	end

	local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
	for _ = 1, 150 do
		if dbg:Invoke(player, "Data") and typeof(player:GetAttribute("Plot")) == "number" and player:GetAttribute("LevelsState") ~= nil then
			break
		end
		task.wait(0.2)
	end
	local function levels(...)
		return dbg:Invoke(player, "Levels", ...)
	end
	local function action(...)
		return levels("Action", ...)
	end
	local function saved()
		return levels("State").levels
	end
	local function published()
		local raw = player:GetAttribute("LevelsState")
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(raw)
		end)
		return if ok then decoded else {}
	end

	local plot = player:GetAttribute("Plot")
	local arenas = workspace:FindFirstChild("Arenas")
	local arena = arenas and arenas:FindFirstChild("Arena" .. tostring(plot))
	if not arena then
		check(false, "zone de combat du joueur introuvable (workspace.Arenas)")
		return
	end
	local function result()
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(arena:GetAttribute("Result"))
		end)
		return if ok then decoded else {}
	end
	local function towers()
		local folder = arena:FindFirstChild("Towers")
		return if folder then folder:GetChildren() else {}
	end

	------------------------------------------------------------------
	-- État de départ ; plus rien de l'ancien jeu (classé, autel, forge, vagues infinies, passes...)
	------------------------------------------------------------------
	local start = levels("State")
	check(
		start.levels.best == 0 and start.levels.coins == 0 and start.levels.towers.MachineGun == true and start.levels.towers.Bomb == true
			and #start.levels.slots == 1 and published().best == 0 and table.concat(published().towers, ",") == "MachineGun,Bomb" and start.active == nil,
		`nouveau joueur : aucun niveau réussi, 0 pièce de niveau, deux tours (l'Archer et la Catapulte), un emplacement de camp (publié : {tostring(player:GetAttribute("LevelsState"))})`
	)
	local data = dbg:Invoke(player, "Data")
	local dataKeys = {}
	for key in data do
		table.insert(dataKeys, tostring(key))
	end
	table.sort(dataKeys)
	check(
		table.concat(dataKeys, ",") == "levels,soundMode" and data.soundMode == "All" and player:GetAttribute("SoundMode") == "All"
			and player:GetAttribute("DataLoaded") == true,
		`sauvegarde du joueur : seulement ses niveaux et son réglage du son (champs : {table.concat(dataKeys, ", ")})`
	)
	local oldAttributes = {}
	for _, name in {
		"LevelsAccess", "PassSpeedX2", "PassCoinsX2", "PassAutoCollect", "SpeedX2Enabled", "TowerSpinsBought", "ForgeSpinsBought",
		"ForgeCoinPrice", "ForgeBlocked", "Rebirths", "TutorialStep", "RankedOpen", "Queued",
	} do
		if player:GetAttribute(name) ~= nil then
			table.insert(oldAttributes, name)
		end
	end
	local remoteNames = {}
	for _, remote in ReplicatedStorage:WaitForChild("Remotes"):GetChildren() do
		table.insert(remoteNames, remote.Name)
	end
	table.sort(remoteNames)
	check(
		#oldAttributes == 0 and table.concat(remoteNames, ",") == "LevelAction,Notify,PlotShots,PlotSync,Settings" and ReplicatedStorage:GetAttribute("ServerMode") == nil,
		`plus rien de l'ancien jeu côté réseau : remotes « {table.concat(remoteNames, ", ")} », attributs de l'ancien jeu encore là : {#oldAttributes} ({table.concat(oldAttributes, ", ")})`
	)
	local stats = player:FindFirstChild("leaderstats")
	local statNames = {}
	for _, stat in if stats then stats:GetChildren() else {} do
		table.insert(statNames, stat.Name)
	end
	check(
		table.concat(statNames, ",") == "Level" and stats.Level.Value == 0,
		`liste des joueurs : une seule colonne, « Level » (le plus haut niveau réussi : {if stats and stats:FindFirstChild("Level") then stats.Level.Value else "?"})`
	)
	local hub = workspace:WaitForChild("Hub")
	local plotCount, badPlots = 0, {}
	for _, folder in hub.Plots:GetChildren() do
		plotCount += 1
		local spots = folder:FindFirstChild("Spots")
		if not folder:FindFirstChild("ShopBuilding") or not folder:FindFirstChild("LevelsBuilding") or folder:FindFirstChild("TowerMachine")
			or folder:FindFirstChild("BonusMachine") or not spots or #spots:GetChildren() ~= #PlotLayout.SPOTS
		then
			table.insert(badPlots, folder.Name)
		end
	end
	-- Place centrale : seulement le sol, le décor, la rosace et ses torches (plus de cercle ni de tableaux du classé).
	local plazaParts = { Ground = true, KingdomDecor = true, Plaza = true, PlazaRosette = true, PlazaRing = true, Torch = true, Flame = true, SpawnLocation = true, Plots = true }
	local oldPlaza = {}
	for _, child in hub:GetChildren() do
		if not plazaParts[child.Name] and not table.find(oldPlaza, child.Name) then
			table.insert(oldPlaza, child.Name)
		end
	end
	check(
		plotCount == PlotLayout.COUNT and #badPlots == 0 and #PlotLayout.SPOTS == 3 and hub:FindFirstChild("PlazaRosette") ~= nil and #oldPlaza == 0
			and workspace:FindFirstChild("Map") == nil,
		`map : {plotCount} parcelles avec leur boutique, leur porte des niveaux et 3 socles ; place centrale sans cercle ni tableau du classé (objets en trop : {table.concat(oldPlaza, ", ")} ; parcelles à revoir : {table.concat(badPlots, ", ")})`
	)
	local folders, clean = 0, true
	for slot = 1, Levels.ARENA_SLOTS do
		local folder = arenas:FindFirstChild("Arena" .. slot)
		if folder then
			folders += 1
			clean = clean and folder:GetAttribute("PlotIndex") == Levels.arenaIndex(slot) and folder:GetAttribute("Map") == nil
				and folder:FindFirstChild("Map") == nil and folder:FindFirstChild("Focus") ~= nil
		end
	end
	check(folders == Levels.ARENA_SLOTS and clean, `{folders} zones de combat prêtes et vides (aucune carte chargée tant que personne ne joue)`)
	check(
		(arena.Focus.Position - Levels.arenaCFrame(plot).Position).Magnitude < 1 and arena.Focus.Position.Magnitude > 2000,
		`la zone du joueur est loin de la place ({math.floor(arena.Focus.Position.Magnitude)} studs du centre)`
	)

	------------------------------------------------------------------
	-- La parcelle est le CAMP D'ENTRAÎNEMENT. Demande du propriétaire (02/10/2026) : « tu peux gérer toute la parcelle
	-- et le système d'évolution de tour ».
	------------------------------------------------------------------
	local plotFolder = hub:WaitForChild("Plots"):WaitForChild("Plot" .. tostring(plot))
	local function campState()
		return dbg:Invoke(player, "Camp")
	end
	local function pad(slot)
		return plotFolder.Spots:FindFirstChild("Spot" .. tostring(Levels.CAMP.SPOTS[slot]))
	end
	local function padLabel(slot)
		local gui = pad(slot):FindFirstChild("CampLabel")
		local panel = gui and gui:FindFirstChild("Panel")
		return if panel then { title = panel.Title.Text, sub = panel.Sub.Text, xp = panel.Bar.Xp.Text, bar = panel.Bar.Visible, shown = panel.Visible } else {}
	end
	local function campTower(slot)
		local folder = plotFolder:FindFirstChild("Towers")
		for _, model in if folder then folder:GetChildren() else {} do
			if model:GetAttribute("CampSlot") == slot then
				return model
			end
		end
		return nil
	end
	local function buildingTitle(name)
		local cabinet = plotFolder:FindFirstChild(name)
		local billboard = cabinet and cabinet:FindFirstChildOfClass("BillboardGui")
		local label = billboard and billboard:FindFirstChildOfClass("TextLabel")
		local prompt = cabinet and cabinet:FindFirstChildOfClass("ProximityPrompt")
		return if label then label.Text else nil, if prompt then prompt:GetAttribute("CampTab") else nil
	end
	local function countPads()
		local shown, hidden = 0, 0
		for _, part in plotFolder.Spots:GetChildren() do
			if part.Transparency >= 1 then
				hidden += 1
			else
				shown += 1
			end
		end
		return shown, hidden
	end

	local camp = campState()
	check(
		camp.camp == true and camp.towers[1] ~= nil and camp.towers[1].type == "MachineGun" and camp.towers[1].stage == 0
			and plotFolder:GetAttribute("Camp") == true and plotFolder:GetAttribute("OwnerUserId") == player.UserId,
		"la parcelle du joueur est son camp d'entraînement : l'Archer de l'emplacement 1 est posé dessus"
	)
	local archerModel = campTower(1)
	local padPosition = pad(1).Position
	local shown, hidden = countPads()
	check(
		archerModel ~= nil and archerModel:GetAttribute("TowerType") == "MachineGun" and archerModel:GetAttribute("SpotIndex") == nil
			and (Vector3.new(archerModel:GetPivot().Position.X, 0, archerModel:GetPivot().Position.Z) - Vector3.new(padPosition.X, 0, padPosition.Z)).Magnitude < 1,
		"l'Archer à l'entraînement est debout sur le 1er socle du camp"
	)
	check(
		pad(1).Transparency == 0 and pad(2).Transparency > 0 and pad(2).Transparency < 1 and pad(3).Transparency == 1 and shown == 2 and hidden == 1,
		`socles : le 1er ouvert, le 2e à ouvrir, le 3e caché ({shown} visibles, {hidden} caché)`
	)
	local label1, label2 = padLabel(1), padLabel(2)
	check(
		string.find(label1.title or "", "Archer", 1, true) ~= nil and string.find(label1.sub or "", "Entraînement 0/6", 1, true) ~= nil
			and string.find(label1.sub or "", "+1 XP/min", 1, true) ~= nil and label1.bar == true and string.find(label1.xp or "", "/ 20 XP", 1, true) ~= nil,
		`étiquette du 1er socle : « {tostring(label1.title)} », « {tostring(label1.sub)} », « {tostring(label1.xp)} »`
	)
	check(
		string.find(label2.title or "", "EMPLACEMENT 2", 1, true) ~= nil and string.find(label2.sub or "", "400", 1, true) ~= nil and label2.bar == false
			and pad(1).CampPrompt:GetAttribute("CampSlot") == 1 and pad(1).CampPrompt.ActionText == "Gérer" and pad(2).CampPrompt.ActionText == "Ouvrir"
			and pad(3).CampPrompt.Enabled == false and padLabel(3).shown == false and label2.shown == true,
		`étiquette du 2e socle : « {tostring(label2.title)} », « {tostring(label2.sub)} » ; invites « Gérer » et « Ouvrir »`
	)
	local shopTitle, shopTab = buildingTitle("ShopBuilding")
	local gateTitle, gateTab = buildingTitle("LevelsBuilding")
	check(
		shopTitle == "BOUTIQUE DES TOURS" and shopTab == "Boutique" and gateTitle == "PORTE DES NIVEAUX" and gateTab == "Niveaux",
		`les deux bâtiments de l'entrée : « {tostring(shopTitle)} » et « {tostring(gateTitle)} »`
	)
	local boardPanel = plotFolder.Decor.FiefBoard.FiefDisplay.Panel
	task.wait(0.3)
	check(
		boardPanel.Heading.Text == "CAMP D'ENTRAÎNEMENT" and boardPanel.WaveCard.Title.Text == "NIVEAUX RÉUSSIS" and boardPanel.WaveCard.Value.Text == `0 / {Levels.COUNT}`
			and boardPanel.RecordCard.Value.Text == "2 / 8" and string.find(boardPanel.BattleState.Text, "1 tour", 1, true) ~= nil,
		`tableau de la parcelle : « {boardPanel.Heading.Text} », « {boardPanel.WaveCard.Title.Text} {boardPanel.WaveCard.Value.Text} », tours « {boardPanel.RecordCard.Value.Text} », « {boardPanel.BattleState.Text} »`
	)
	-- Les tours s'entraînent pour de vrai : des cibles roulent sur le chemin, l'Archer les détruit.
	local deadline = os.clock() + 20
	while campState().kills < 2 and os.clock() < deadline do
		task.wait(0.25)
	end
	camp = campState()
	check(camp.kills >= 2 and camp.targets >= 5, `l'Archer du camp tire sur les cibles d'entraînement : {camp.kills} détruites, {camp.targets} sur le chemin`)
	-- Une autre tour dans l'emplacement : elle remplace la première sur le socle.
	check(
		action("SlotAssign", 1, "Bomb") == true and campState().towers[1].type == "Bomb" and campTower(1) ~= archerModel and campTower(1):GetAttribute("TowerType") == "Bomb"
			and string.find(padLabel(1).title, "Catapulte", 1, true) ~= nil,
		`la Catapulte mise dans l'emplacement 1 remplace l'Archer sur le socle (étiquette « {padLabel(1).title} »)`
	)
	-- ÉVOLUTION : l'entraînement monte, la tour change (étoiles, anneau, fanions) et garde son nouveau pouvoir.
	levels("Set", "xp", { MachineGun = 300 })
	action("SlotAssign", 1, "MachineGun")
	local evolved = campTower(1)
	camp = campState()
	check(
		camp.towers[1].type == "MachineGun" and camp.towers[1].stage == 2 and evolved ~= nil and evolved:GetAttribute("Stars") == 2
			and evolved:FindFirstChild("EvolutionRing") ~= nil and evolved:FindFirstChild("EvolutionPennant") ~= nil and evolved:FindFirstChild("EvolutionHalo") == nil
			and string.find(padLabel(1).title, "★★", 1, true) ~= nil and string.find(padLabel(1).sub, "Entraînement 4/6", 1, true) ~= nil,
		`Archer entraîné au niveau 4 : 2e évolution sur la parcelle (étiquette « {padLabel(1).title} », « {padLabel(1).sub} », anneau et fanions sur le modèle)`
	)
	levels("Set", "xp", { MachineGun = 1200 })
	local maxed = campTower(1)
	check(
		campState().towers[1].stage == 3 and maxed ~= evolved and maxed:GetAttribute("Stars") == 3 and maxed:FindFirstChild("EvolutionHalo") ~= nil
			and string.find(padLabel(1).xp, "MAX", 1, true) ~= nil,
		`entraînement 6 : 3e évolution, la tour est refaite avec son halo doré (« {padLabel(1).title} », « {padLabel(1).xp} »)`
	)
	-- 2e emplacement : ouvert avec les pièces de niveau, une 2e tour s'entraîne à côté.
	levels("Set", "coins", 400)
	check(
		action("SlotUnlock") == true and pad(2).Transparency == 0 and pad(3).Transparency > 0 and pad(3).Transparency < 1
			and string.find(padLabel(3).sub, "1.5K", 1, true) ~= nil and action("SlotAssign", 2, "Bomb") == true and campState().towers[2].type == "Bomb"
			and campTower(2) ~= nil,
		`2e emplacement ouvert (400 pièces) : la Catapulte s'y entraîne, le 3e socle apparaît à son tour (« {padLabel(3).sub} »)`
	)
	task.wait(4)
	log("Info", "[LEVELS] SHOT:levels_camp_evolue")
	task.wait(1.8)
	-- Retour à un nouveau joueur pour la suite du test.
	levels("Set", "xp", {})
	levels("Set", "coins", 0)
	levels("Set", "slots", { { tower = "MachineGun", level = 1 } })
	check(campState().towers[1].stage == 0 and campState().towers[2] == nil and pad(2).Transparency > 0, "camp remis à zéro pour la suite du test (un Archer sans évolution)")

	------------------------------------------------------------------
	-- Camps reçus (Hub/PlotInterest.luau) : les cibles et les tirs d'un camp ne vont qu'à son propriétaire (toujours)
	-- et aux joueurs qui s'en approchent. D'abord la règle avec de fausses positions (la vraie fonction du jeu), puis
	-- le vrai joueur (Hub/init.luau, vrais remotes) : sa position compte ailleurs quelques secondes (StudioDebug
	-- « Interest »), sans bouger son personnage.
	------------------------------------------------------------------
	do
		local PlotInterest = require(game:GetService("ServerScriptService").Server.Hub.PlotInterest)
		local at = PlotLayout.toWorld
		local ENTER, LEAVE = PlotInterest.ENTER_MARGIN, PlotInterest.LEAVE_MARGIN
		local function has(list, key)
			return table.find(list, key) ~= nil
		end
		-- Faux joueurs : A possède la parcelle 1, B la parcelle 2 (sa voisine), C n'en a pas.
		local memory = {}
		local function step(a, b, c)
			return PlotInterest.compute({
				{ key = "A", position = a, plot = 1 },
				{ key = "B", position = b, plot = 2 },
				{ key = "C", position = c, plot = nil },
			}, memory)
		end
		local function leavingText(leaving)
			local parts = {}
			for _, gone in leaving do
				table.insert(parts, `{gone.key}:{gone.plotIndex}`)
			end
			return table.concat(parts, " ")
		end
		local homeB = at(2, Vector3.new(0, 3, 0))

		-- A très loin (sur la parcelle 4), B chez lui, C sans personnage.
		local r, leaving = step(at(4, Vector3.new(0, 3, 0)), homeB, nil)
		check(
			has(r[1], "A") and not has(r[1], "B") and not has(r[1], "C") and has(r[2], "B") and not has(r[2], "A") and #leaving == 0,
			`camps reçus : le propriétaire loin de sa parcelle la reçoit toujours, le voisin chez lui non (parcelle 1 : {table.concat(r[1], ",")} ; parcelle 2 : {table.concat(r[2], ",")})`
		)
		check(has(r[4], "A") and not has(r[4], "C"), `camps reçus : A, debout sur la parcelle 4, la reçoit ; C, sans personnage, rien ({table.concat(r[4], ",")})`)

		-- B sur SA parcelle ou devant SES bâtiments, même dans le coin le plus proche de la parcelle 1 (à ~20 studs
		-- d'elle) : il ne reçoit aucune autre parcelle.
		local half = PlotLayout.LENGTH / 2
		local wrong = {}
		for _, spot in {
			{ "coin vers la parcelle 1", Vector3.new(-PlotLayout.WIDTH / 2, 3, -half) },
			{ "coin vers la parcelle 3", Vector3.new(PlotLayout.WIDTH / 2, 3, -half) },
			{ "boutique", Vector3.new(-20, 3, -half - 8) },
			{ "porte des niveaux", Vector3.new(20, 3, -half - 8) },
			{ "devant la boutique (12 studs)", Vector3.new(-20, 3, -half - 20) },
			{ "château", PlotLayout.BASE_POSITION + Vector3.new(0, 3, 0) },
		} do
			r = step(at(4, Vector3.new(0, 3, 0)), at(2, spot[2]), nil)
			for plotIndex = 1, PlotLayout.COUNT do
				if plotIndex ~= 2 and has(r[plotIndex], "B") then
					table.insert(wrong, `{spot[1]} : parcelle {plotIndex}`)
				end
			end
			if not has(r[2], "B") then
				table.insert(wrong, `{spot[1]} : pas la sienne`)
			end
		end
		check(#wrong == 0, `camps reçus : B chez lui (coins de sa parcelle, boutique, porte des niveaux, château) ne reçoit que la sienne ({table.concat(wrong, " ; ")})`)

		-- B marche sur la parcelle 1 : il la reçoit (et toujours la sienne).
		r, leaving = step(at(4, Vector3.new(0, 3, 0)), at(1, Vector3.new(0, 3, 0)), nil)
		check(has(r[1], "B") and has(r[2], "B") and #leaving == 0, `camps reçus : B debout sur la parcelle 1 la reçoit (parcelle 1 : {table.concat(r[1], ",")})`)
		-- ... puis rentre chez lui : la parcelle 1 est à effacer chez lui, et seulement chez lui.
		r, leaving = step(at(4, Vector3.new(0, 3, 0)), homeB, nil)
		check(
			not has(r[1], "B") and #leaving == 1 and leaving[1].key == "B" and leaving[1].plotIndex == 1,
			`camps reçus : B rentre chez lui -> la parcelle 1 est à effacer chez lui (« Clear » : {leavingText(leaving)})`
		)

		-- Bord de la parcelle 1 (côté extérieur, loin de la parcelle 2) : on commence à la recevoir à ENTER studs,
		-- on arrête plus loin (LEAVE studs) : pas de clignotement quand on marche sur le bord.
		local function outside(distance)
			return at(1, Vector3.new(0, 3, half + distance))
		end
		local between = (ENTER + LEAVE) / 2
		r, leaving = step(nil, outside(between), nil)
		local okFar = not has(r[1], "B")
		r, leaving = step(nil, outside(ENTER - 2), nil)
		local okEnter = has(r[1], "B")
		r, leaving = step(nil, outside(between), nil)
		local okStay = has(r[1], "B") and #leaving == 0
		r, leaving = step(nil, outside(LEAVE + 2), nil)
		local okLeave = not has(r[1], "B") and #leaving == 1 and leaving[1].key == "B" and leaving[1].plotIndex == 1
		check(
			okFar and okEnter and okStay and okLeave,
			`camps reçus : hystérésis au bord (à {between} studs en arrivant : {not okFar and "reçue" or "non"} ; à {ENTER - 2} : {okEnter and "reçue" or "NON"} ; retour à {between} : {okStay and "toujours reçue" or "PERDUE"} ; à {LEAVE + 2} : {okLeave and "effacée" or "PAS effacée"})`
		)
		check(has(r[1], "A") and not has(r[1], "C"), `camps reçus : A sans personnage reçoit toujours sa parcelle ({table.concat(r[1], ",")})`)

		-- B perd son personnage sur la parcelle 1 : effacée chez lui ; C sans parcelle ; un joueur parti est oublié.
		step(nil, at(1, Vector3.new(0, 3, 0)), at(3, Vector3.new(0, 3, 0)))
		r, leaving = step(nil, nil, at(3, Vector3.new(0, 3, 0)))
		check(
			has(r[2], "B") and not has(r[1], "B") and has(r[3], "C") and leavingText(leaving) == "B:1",
			`camps reçus : B sans personnage -> parcelle 1 effacée, garde la sienne ; C (sans parcelle) reçoit la parcelle 3 (Clear : {leavingText(leaving)})`
		)
		PlotInterest.compute({ { key = "A", position = nil, plot = 1 } }, memory)
		check(memory.B == nil and memory.C == nil and memory.A ~= nil, "camps reçus : les joueurs partis sont oubliés")

		-- Le vrai joueur (un seul joueur dans le test : les autres parcelles sont libres).
		local function interestWait(predicate)
			local limit = os.clock() + 8
			local info = dbg:Invoke(player, "Interest")
			while not predicate(info) and os.clock() < limit do
				task.wait(0.1)
				info = dbg:Invoke(player, "Interest")
			end
			return info, predicate(info)
		end
		local other = plot % PlotLayout.COUNT + 1
		dbg:Invoke(player, "Interest", "Position", at(plot, Vector3.new(0, 3, 0)))
		local info, ok = interestWait(function(i)
			return i ~= nil and i.receivesOwn and #i.receives == 0
		end)
		check(ok and info.own == plot, `camps reçus (vrai joueur) : chez lui, sa parcelle {plot} seulement (autres : {info and table.concat(info.receives, ",")})`)
		local clearsBefore = info and info.clears or 0
		dbg:Invoke(player, "Interest", "Position", at(other, Vector3.new(0, 3, 0)))
		info, ok = interestWait(function(i)
			return i ~= nil and table.find(i.receives, other) ~= nil
		end)
		check(
			ok and #info.receives == 1 and info.receivesOwn,
			`camps reçus (vrai joueur) : sur la parcelle {other}, il la reçoit et garde la sienne (reçues : {info and table.concat(info.receives, ",")}, la sienne : {info and info.receivesOwn})`
		)
		dbg:Invoke(player, "Interest", "Position", at(plot, Vector3.new(0, 3, 0)))
		info, ok = interestWait(function(i)
			return i ~= nil and #i.receives == 0
		end)
		check(
			ok and info.clears == clearsBefore + 1,
			`camps reçus (vrai joueur) : rentré chez lui, la parcelle {other} n'est plus envoyée et un « Clear » est parti ({info and info.clears - clearsBefore} paquet(s))`
		)
		dbg:Invoke(player, "Interest", "Position", nil)
	end

	------------------------------------------------------------------
	-- Six combats dans le même serveur : coût du calcul
	------------------------------------------------------------------
	-- 12 tours par joueur (un combat normal), puis 3 tours seulement (les monstres s'entassent : le pire cas).
	for _, case in { { 12, "12 tours chacun" }, { 3, "3 tours chacun : la carte pleine de monstres" } } do
		-- (170 s : presque tout le flot du dernier niveau, dont la fin, le moment le plus chargé : 3,3 monstres par
		-- seconde sur le plus long chemin)
		local bench = levels("Bench", 6, 170, case[1])
		check(
			bench.games == 6 and bench.enemiesPeak >= 100 and bench.averageMs < 2 and bench.p99Ms < 4,
			string.format(
				"six niveaux %d joués en même temps pendant 170 s de jeu (%s) : %.2f ms par image en moyenne, %.2f ms pour 99 %% des images, %.1f ms pour la pire (une image du serveur = 16,7 ms), jusqu'à %d monstres à la fois",
				Levels.COUNT,
				case[2],
				bench.averageMs,
				bench.p99Ms,
				bench.worstMs,
				bench.enemiesPeak
			)
		)
	end

	------------------------------------------------------------------
	-- Demandes refusées
	------------------------------------------------------------------
	local farOk, farReason = action("Start", 3)
	check(farOk == false and farReason == "Réussis d'abord le niveau 1", `niveau 3 refusé tant que le niveau 1 n'est pas réussi (« {tostring(farReason)} »)`)
	local unknownOk, unknownReason = action("Start", Levels.COUNT + 1)
	check(
		action("Start", 0) == false and unknownOk == false and unknownReason == "Ce niveau n'existe pas encore" and action("Start", 1.5) == false and action("Start", "1") == false,
		`niveaux inconnus refusés (0, {Levels.COUNT + 1} : « {tostring(unknownReason)} », 1,5, texte)`
	)
	check(action("Place", "MachineGun", 0, 0) == false and action("Upgrade", 1) == false and action("Rush") == false, "hors d'un niveau : poser et améliorer ne font rien (et l'ancienne demande « envoyer la suite » n'existe plus)")

	------------------------------------------------------------------
	-- Un niveau en entier
	------------------------------------------------------------------
	check(action("Start", 1) == true, "niveau 1 lancé")
	local map = arena:FindFirstChild("Map")
	check(
		player:GetAttribute("LevelArena") == Levels.arenaIndex(plot) and arena:GetAttribute("Map") == "Valley" and map ~= nil
			and #map:GetChildren() > 20 and player.ReplicationFocus == arena.Focus,
		`le joueur regarde sa zone (LevelArena = {tostring(player:GetAttribute("LevelArena"))}), la carte « {tostring(arena:GetAttribute("Map"))} » est construite ({if map then #map:GetChildren() else 0} pièces)`
	)
	check(
		arena:GetAttribute("State") == "Running" and arena:GetAttribute("Level") == 1 and arena:GetAttribute("Gold") == 60
			and arena:GetAttribute("Lives") == 10 and arena:GetAttribute("Total") == #Levels.buildQueue(1) and #towers() == 1
			and arena:GetAttribute("Progress") == 0,
		`niveau 1 : en cours, {tostring(arena:GetAttribute("Gold"))} or, {tostring(arena:GetAttribute("Lives"))} vies, {tostring(arena:GetAttribute("Total"))} monstres, {#towers()} Archer déjà posé`
	)
	local frostOk, frostReason = action("Place", "Frost", -1, 0)
	check(frostOk == false and string.find(tostring(frostReason), "boutique", 1, true) ~= nil, `une tour pas achetée ne se pose pas (« {tostring(frostReason)} »)`)
	local pathOk, pathReason = action("Place", "MachineGun", -34, 0)
	check(pathOk == false and pathReason == "Trop près du chemin", "poser sur le chemin est refusé")
	check(action("Place", "MachineGun", -1, 0) == true and #towers() == 2 and levels("State").active.gold == 40, "pose libre : un 2e Archer à l'endroit choisi, 20 or dépensés")
	local poorOk, poorReason = action("Place", "Bomb", 21, 0)
	check(poorOk == false and poorReason == "Pas assez d'or" and #towers() == 2, "40 or : pas assez pour une Catapulte (45), la pose est refusée")
	check(action("Speed", 2) == true and levels("State").active.simSpeed == 2 and action("Speed", 1) == true, "x2 allumé puis éteint (pour tout le monde, sans pass)")
	-- Retour du propriétaire (02/10/2026) : « si juste 2 Archers gèrent le niveau, je passe mon temps à attendre ».
	-- 2 Archers, puis plus rien : le flot monte, le niveau est PERDU.
	local state = levels("Skip", 200)
	local lost = result()
	local after = saved()
	local lostProgress = (lost.kills or 0) / math.max(1, lost.total or 1)
	check(
		state == "Lost" and arena:GetAttribute("State") == "Lost" and arena:GetAttribute("Lives") == 0 and levels("State").active.clock < 80,
		`2 Archers puis attendre : le niveau 1 est PERDU (au bout de {math.floor(levels("State").active.clock)} s de jeu)`
	)
	check(
		lost.won == false and lost.level == 1 and lost.kills < lost.total * 0.3 and lost.reward == Levels.reward(1, false, false, lostProgress)
			and lost.nextLevel == nil and lost.firstClear == false,
		`résultat publié : défaite après {tostring(lost.kills)}/{tostring(lost.total)} monstres, +{tostring(lost.reward)} pièces de niveau, +{tostring(lost.xp)} XP`
	)
	check(
		after.best == 0 and after.losses == 1 and after.wins == 0 and after.coins == lost.reward and near(after.xp.MachineGun, Levels.playXp(false, lostProgress), 0.5),
		`sauvegarde : niveau 1 toujours à faire, une défaite, {after.coins} pièces, {tostring(after.xp.MachineGun)} XP pour l'Archer`
	)
	check(action("Place", "MachineGun", 21, 0) == false, "niveau fini : plus aucune pose")

	-- « Réessayer » : le même niveau, joué comme il faut. Toutes les tours posées et améliorées (l'or est donné par
	-- le test : ici on vérifie la victoire et ses récompenses, pas la difficulté, réglée dans tools/levels).
	check(
		action("Start", 1) == true and arena:FindFirstChild("Map") == map and arena:GetAttribute("Level") == 1 and arena:GetAttribute("Result") == nil
			and #towers() == 1 and arena:GetAttribute("Gold") == 60 and arena:GetAttribute("Lives") == 10,
		"« Réessayer » : le niveau 1 repart de zéro dans la même zone (même carte, 60 or, 10 vies, un seul Archer)"
	)
	levels("Gold", 3000)
	local spots = Levels.MAPS.Valley.spots
	for index = 2, 5 do
		action("Place", "MachineGun", spots[index].X, spots[index].Z)
	end
	for index = 6, 9 do
		action("Place", "Bomb", spots[index].X, spots[index].Z)
	end
	local upgrades = 0
	for _, model in towers() do
		for _ = 1, 4 do
			if action("Upgrade", model:GetAttribute("TowerId")) then
				upgrades += 1
			end
		end
	end
	check(#towers() == 9 and upgrades == 36, `5 Archers et 4 Catapultes posés, tous améliorés au niveau 5 ({#towers()} tours, {upgrades} améliorations)`)
	local limitOk, limitReason = action("Place", "MachineGun", spots[10].X, spots[10].Z)
	check(limitOk == false and string.find(tostring(limitReason), "Maximum 5", 1, true) ~= nil, `6e Archer refusé (« {tostring(limitReason)} »)`)
	state = levels("Skip", 200)
	local won = result()
	after = saved()
	check(state == "Won" and arena:GetAttribute("State") == "Won", "le niveau 1 se gagne avec toutes ses tours posées et améliorées (200 s de jeu passées d'un coup)")
	check(
		won.won == true and won.level == 1 and won.reward == 80 and won.firstClear == true and won.nextLevel == 2 and won.kills == won.total and won.xp == 8
			and won.lives == 10,
		`résultat publié : victoire, +{tostring(won.reward)} pièces de niveau, première fois, niveau suivant {tostring(won.nextLevel)}, {tostring(won.kills)}/{tostring(won.total)} monstres, {tostring(won.lives)} vies, +{tostring(won.xp)} XP`
	)
	check(
		after.best == 1 and after.coins == lost.reward + 80 and after.wins == 1 and near(after.xp.MachineGun, Levels.playXp(false, lostProgress) + 8, 0.5)
			and near(after.xp.Bomb, 8, 0.5) and player.leaderstats.Level.Value == 1,
		`sauvegarde : niveau 1 réussi, {after.coins} pièces, {tostring(after.xp.MachineGun)} XP pour l'Archer, {tostring(after.xp.Bomb)} pour la Catapulte ; colonne « Level » de la liste des joueurs : {player.leaderstats.Level.Value}`
	)

	-- « Niveau suivant » sans repasser par le camp : la carte reste (pas de clignotement).
	check(action("Start", 2) == true and arena:FindFirstChild("Map") == map and arena:GetAttribute("Level") == 2 and arena:GetAttribute("Result") == nil and #towers() == 0 and arena:GetAttribute("Gold") == 65, "« Niveau suivant » : niveau 2 dans la même zone, même carte, or remis à 65, aucune tour gardée")
	-- Abandon en cours de niveau : compté comme une défaite, petite récompense selon l'avancée.
	action("Place", "MachineGun", -23, 0)
	action("Place", "MachineGun", -1, 0)
	levels("Skip", 25)
	local before = levels("State")
	local expected = Levels.reward(2, false, false, before.active.kills / before.active.total)
	local coinsBefore, xpBefore2 = after.coins, after.xp.MachineGun
	check(action("Quit") == true, "« Quitter » pendant le niveau 2")
	after = saved()
	check(
		before.active.kills > 0 and before.active.state == "Running" and after.losses == 2 and after.coins == coinsBefore + expected and after.best == 1
			and near(after.xp.MachineGun, xpBefore2 + Levels.playXp(false, before.active.kills / before.active.total), 0.5),
		`abandon après {before.active.kills} monstres sur {before.active.total} : une défaite de plus, +{expected} pièces, un peu d'XP ({tostring(after.xp.MachineGun)})`
	)
	check(
		player:GetAttribute("LevelArena") == nil and arena:GetAttribute("Map") == nil and arena:FindFirstChild("Map") == nil
			and arena:GetAttribute("State") == nil and player.ReplicationFocus == nil and levels("State").active == nil,
		"retour au camp : la carte est effacée, la zone est vide, le joueur ne la regarde plus"
	)
	-- « Rejouer » un niveau réussi : moins de pièces.
	action("Start", 1)
	levels("Finish", true)
	local replay = result()
	check(replay.won == true and replay.firstClear == false and replay.reward == 32 and saved().coins == after.coins + 32 and saved().best == 1, `rejouer le niveau 1 : +{tostring(replay.reward)} pièces (au lieu de 80), niveau 2 toujours à faire`)
	action("Quit")

	------------------------------------------------------------------
	-- Boutique à prix fixes
	------------------------------------------------------------------
	levels("Set", "coins", 1000)
	local buyOk = action("Buy", "Frost")
	after = saved()
	check(buyOk == true and after.coins == 850 and after.towers.Frost == true and table.concat(published().towers, ",") == "MachineGun,Bomb,Frost", "boutique : Totem de givre acheté 150 pièces, ajouté au bout de la barre")
	local againOk, againReason = action("Buy", "Frost")
	local richOk, richReason = action("Buy", "Orbital")
	check(againOk == false and string.find(tostring(againReason), "déjà", 1, true) ~= nil and richOk == false and string.find(tostring(richReason), "manque", 1, true) ~= nil and saved().coins == 850, `boutique : déjà possédée (« {tostring(againReason)} ») ou trop chère (« {tostring(richReason)} ») : refusé, rien n'est dépensé`)
	check(action("Buy", "MachineGun") == false and action("Buy", "Bomb") == false and action("Buy", "Dragon") == false and action("Buy", 5) == false and saved().coins == 850, "boutique : les deux tours de départ et les tours inconnues ne sont pas en vente")
	-- Retour du propriétaire (02/10/2026) : les tours légendaires doivent coûter bien plus cher que les premières,
	-- et le ralentissement du Totem de givre était « un peu cheaté » (-40 % au lieu de -60 %).
	levels("Set", "coins", 7999)
	local oracleOk, oracleReason = action("Buy", "Chain")
	levels("Set", "coins", 8000)
	local oracleBought = action("Buy", "Chain")
	check(
		oracleOk == false and string.find(tostring(oracleReason), "manque 1 ", 1, true) ~= nil and oracleBought == true and saved().coins == 0
			and saved().towers.Chain == true and Levels.SHOP.Orbital == 15000,
		`boutique : l'Oracle (légendaire) coûte 8 000 pièces (« {tostring(oracleReason)} » avec 7 999), le Trébuchet 15 000`
	)
	local frostStats = Levels.towerStats("Frost", 1, 0)
	check(math.abs(frostStats.slow - 0.4) < 1e-6, `Totem de givre : ralentit de {frostStats.slow * 100} %`)
	levels("Set", "towers", { MachineGun = true, Bomb = true, Frost = true })
	levels("Set", "coins", 850)

	------------------------------------------------------------------
	-- Camp d'entraînement
	------------------------------------------------------------------
	local xpBefore = saved().xp.MachineGun
	check(action("SlotAssign", 1, "Frost") == true and saved().slots[1].tower == "Frost", "camp : le Totem prend l'emplacement 1")
	local xp = levels("Clock", 3600)
	check(near(xp.Frost, 60, 1) and near(xp.MachineGun, xpBefore, 0.5), `camp : 1 h plus tard, le Totem a {tostring(xp.Frost)} XP (60 attendus), l'Archer n'a pas bougé`)
	check(action("SlotUpgrade", 1) == true and saved().slots[1].level == 2 and saved().coins == 730, "camp : emplacement 1 amélioré au niveau 2 pour 120 pièces")
	check(action("SlotUnlock") == true and #saved().slots == 2 and saved().coins == 330, "camp : 2e emplacement ouvert pour 400 pièces")
	check(action("SlotUnlock") == false and #saved().slots == 2, "camp : pas assez de pièces pour le 3e emplacement (1 500)")
	action("SlotAssign", 2, "MachineGun")
	xp = levels("Clock", 600)
	check(near(xp.Frost, 75, 1.5) and near(xp.MachineGun, xpBefore + 10, 1), `camp : 10 min plus tard, +15 XP pour le Totem (emplacement niveau 2) et +10 pour l'Archer ({tostring(xp.Frost)} et {tostring(xp.MachineGun)})`)
	check(action("SlotAssign", 2, "Frost") == true and saved().slots[2].tower == "Frost" and saved().slots[1].tower == "", "camp : une tour ne s'entraîne que dans un emplacement à la fois (elle change de place)")
	check(action("SlotAssign", 1, "Tesla") == false and action("SlotAssign", 9, "Frost") == false, "camp : tour pas possédée ou emplacement inconnu refusés")
	xp = levels("Clock", 7 * 86400)
	check(near(xp.Frost, 75 + 12 * 60, 2), `camp : une semaine d'absence ne compte que 12 h ({tostring(xp.Frost)} XP)`)

	------------------------------------------------------------------
	-- Barre rapide, améliorations d'entraînement dans un niveau
	------------------------------------------------------------------
	check(action("Bar", { "Frost", "MachineGun" }) == true and table.concat(published().towers, ",") == "Frost,MachineGun,Bomb", "barre rapide : nouvel ordre gardé (Totem, Archer, puis le reste)")
	check(action("Bar", { "Dragon" }) == false and action("Bar", "Frost") == false and published().towers[1] == "Frost", "barre rapide : liste invalide refusée")
	levels("Set", "xp", { MachineGun = 60, Frost = 0 })
	action("Start", 1)
	check(
		arena:GetAttribute("Perks") == "MachineGun:Fire" and string.find(tostring(arena:GetAttribute("Training")), "MachineGun=2", 1, true) ~= nil,
		`Archer à l'entraînement 2 : flèches enflammées débloquées dans le niveau (« {tostring(arena:GetAttribute("Perks"))} »)`
	)
	levels("Gold", 100)
	check(action("Place", "Frost", -1, 0) == true and levels("State").active.gold == 160 - Levels.placeCost("Frost"), "le Totem acheté à la boutique se pose dans le niveau (40 or)")
	action("Quit")

	------------------------------------------------------------------
	-- 2e territoire (niveaux 11 à 20). Demande du propriétaire (02/10/2026) : « ajoute des niveaux ».
	------------------------------------------------------------------
	do
		local lockedOk, lockedReason = action("Start", 11)
		check(lockedOk == false and lockedReason == `Réussis d'abord le niveau {saved().best + 1}`, `le niveau 11 est fermé tant que le premier territoire n'est pas fini (« {tostring(lockedReason)} »)`)
		levels("Set", "best", 10)
		levels("Set", "coins", 0)
		levels("Set", "towers", { MachineGun = true, Bomb = true, Frost = true, Tesla = true, Rocket = true })
		check(action("Start", 11) == true, "niveau 11 lancé (premier territoire réussi)")
		local passMap = arena:FindFirstChild("Map")
		local rocks, crowns = 0, 0
		for _, part in if passMap then passMap:GetChildren() else {} do
			if part.Name == "Rock" then
				rocks += 1
			end
		end
		local field = passMap and passMap:FindFirstChild("Field")
		check(
			arena:GetAttribute("Map") == "Pass" and arena:GetAttribute("Level") == 11 and arena:GetAttribute("Wave") == 11 and arena:GetAttribute("Gold") == 115
				and #towers() == 0 and arena:GetAttribute("Total") == #Levels.buildQueue(11) and rocks >= 10 and field ~= nil and field.Color.R > field.Color.G,
			`niveau 11 : la carte du 2e territoire (« {tostring(arena:GetAttribute("Map"))} ») est construite, terre rousse et {rocks} rochers, {tostring(arena:GetAttribute("Gold"))} or, {tostring(arena:GetAttribute("Total"))} monstres de la famille suivante (attribut Wave = {tostring(arena:GetAttribute("Wave"))})`
		)
		-- La pose suit le chemin de CETTE carte : un point libre de la vallée est sur le chemin du col, et l'inverse.
		local onPathOk, onPathReason = action("Place", "MachineGun", -23, 0)
		local passSpots = Levels.MAPS.Pass.spots
		check(
			onPathOk == false and onPathReason == "Trop près du chemin" and action("Place", "MachineGun", passSpots[1].X, passSpots[1].Z) == true and #towers() == 1,
			`col : le premier emplacement de la vallée est sur le chemin (« {tostring(onPathReason)} »), le premier emplacement du col est libre`
		)
		levels("Gold", 4000)
		for index, towerType in { "MachineGun", "MachineGun", "MachineGun", "Bomb", "Frost", "Bomb", "Tesla", "Rocket", "Rocket", "MachineGun", "Bomb" } do
			action("Place", towerType, passSpots[index + 1].X, passSpots[index + 1].Z)
		end
		for _, model in towers() do
			for _ = 1, 3 do
				action("Upgrade", model:GetAttribute("TowerId"))
			end
		end
		check(#towers() == 12, `les 12 emplacements conseillés du col sont tous posables ({#towers()} tours posées)`)
		-- (le client du joueur regarde ce niveau : une capture du col en plein combat)
		task.wait(1.5)
		levels("Skip", 70)
		task.wait(3)
		log("Info", "[LEVELS] SHOT:levels_territoire2")
		task.wait(1.8)
		levels("Finish", true)
		local first = result()
		check(
			first.won == true and first.level == 11 and first.reward == 280 and first.firstClear == true and first.nextLevel == 12 and saved().best == 11
				and saved().coins == 280,
			`niveau 11 gagné : +{tostring(first.reward)} pièces de niveau, niveau suivant {tostring(first.nextLevel)}`
		)
		check(action("Start", 12) == true and arena:FindFirstChild("Map") == passMap and arena:GetAttribute("Level") == 12, "« Niveau suivant » dans le même territoire : la carte du col reste (pas de clignotement)")
		-- Mini-boss et boss du 2e territoire : deux fois plus de pièces qu'au premier.
		levels("Set", "best", 14)
		action("Start", 15)
		levels("Finish", true)
		local mini = result()
		levels("Set", "best", 19)
		local coinsBefore20 = saved().coins
		action("Start", 20)
		local bossQueue = Levels.buildQueue(20)
		levels("Finish", true)
		local boss20 = result()
		check(
			mini.reward == 600 and boss20.won == true and boss20.reward == 1200 and boss20.nextLevel == 21 and saved().best == 20
				and saved().coins == coinsBefore20 + 1200 and player.leaderstats.Level.Value == 20 and bossQueue[#bossQueue].enemy == "Boss",
			`mini-boss du niveau 15 : +{tostring(mini.reward)} pièces ; boss du niveau 20 : +{tostring(boss20.reward)} pièces, niveau suivant {tostring(boss20.nextLevel)}, colonne « Level » : {player.leaderstats.Level.Value}`
		)
		-- Retour au premier territoire : la carte de la vallée est refaite.
		check(action("Start", 3) == true and arena:GetAttribute("Map") == "Valley" and arena:FindFirstChild("Map") ~= passMap, "rejouer un niveau du premier territoire : la carte de la vallée revient")
		action("Quit")
	end

	------------------------------------------------------------------
	-- 3e et 4e territoires (niveaux 21 à 40). Demande du propriétaire (03/10/2026) : « continue les niveaux jusqu'à 40 ».
	------------------------------------------------------------------
	do
		levels("Set", "towers", { MachineGun = true, Bomb = true, Frost = true, Tesla = true, Rocket = true, Laser = true, Chain = true })
		for _, case in {
			{ level = 21, map = "Forest", name = "forêt", shot = "levels_territoire3" },
			{ level = 31, map = "Glacier", name = "glacier", shot = "levels_territoire4" },
		} do
			levels("Set", "best", case.level - 1)
			check(action("Start", case.level) == true, `niveau {case.level} lancé (le territoire d'avant est réussi)`)
			local built = arena:FindFirstChild("Map")
			local rocks, crowns = 0, 0
			for _, part in if built then built:GetChildren() else {} do
				if part.Name == "Rock" then
					rocks += 1
				elseif part.Name == "TreeCrown" then
					crowns += 1
				end
			end
			local field = built and built:FindFirstChild("Field")
			-- (forêt : un vrai bois, terrain vert ; glacier : terrain de neige)
			local themeOk = if case.map == "Forest"
				then field ~= nil and field.Color.G > field.Color.R and crowns >= 45
				else field ~= nil and field.Material == Enum.Material.Snow and field.Color.B > 0.8
			check(
				arena:GetAttribute("Map") == case.map and arena:GetAttribute("Level") == case.level and arena:GetAttribute("Gold") == Levels.definition(case.level).gold
					and #towers() == 0 and arena:GetAttribute("Total") == #Levels.buildQueue(case.level) and rocks >= 10 and themeOk,
				`niveau {case.level} : la carte du {case.name} (« {tostring(arena:GetAttribute("Map"))} ») est construite avec son décor ({crowns} feuillages d'arbres, {rocks} rochers), {tostring(arena:GetAttribute("Gold"))} or, {tostring(arena:GetAttribute("Total"))} monstres`
			)
			-- Les 12 emplacements conseillés de cette carte sont tous posables, même tous occupés.
			local spots = Levels.MAPS[case.map].spots
			levels("Gold", 6000)
			for index, towerType in { "MachineGun", "MachineGun", "Laser", "Bomb", "Frost", "Rocket", "Chain", "Tesla", "Rocket", "MachineGun", "Bomb", "Laser" } do
				action("Place", towerType, spots[index].X, spots[index].Z)
			end
			for _, model in towers() do
				for _ = 1, 3 do
					action("Upgrade", model:GetAttribute("TowerId"))
				end
			end
			check(#towers() == 12, `{case.name} : les 12 emplacements conseillés sont tous posables ({#towers()} tours posées)`)
			-- (le client du joueur regarde ce niveau : une capture en plein combat)
			task.wait(1.5)
			levels("Skip", 70)
			task.wait(3)
			log("Info", `[LEVELS] SHOT:{case.shot}`)
			task.wait(1.8)
			levels("Finish", true)
			local won = result()
			check(
				won.won == true and won.level == case.level and won.reward == Levels.firstReward(case.level) and won.nextLevel == case.level + 1 and saved().best == case.level,
				`niveau {case.level} gagné : +{tostring(won.reward)} pièces de niveau, niveau suivant {tostring(won.nextLevel)}`
			)
		end
		-- Le dernier niveau : le boss du glacier ferme le flot, plus de niveau suivant.
		levels("Set", "best", Levels.COUNT - 1)
		local coinsBefore = saved().coins
		action("Start", Levels.COUNT)
		local lastQueue = Levels.buildQueue(Levels.COUNT)
		levels("Finish", true)
		local last = result()
		check(
			last.won == true and last.reward == Levels.firstReward(Levels.COUNT) and last.nextLevel == nil and saved().best == Levels.COUNT
				and saved().coins == coinsBefore + last.reward and player.leaderstats.Level.Value == Levels.COUNT and lastQueue[#lastQueue].enemy == "Boss",
			`boss du niveau {Levels.COUNT} : +{tostring(last.reward)} pièces, plus de niveau suivant, colonne « Level » : {player.leaderstats.Level.Value}`
		)
		action("Quit")
	end

	------------------------------------------------------------------
	-- Le client prend la main, comme un nouveau joueur
	------------------------------------------------------------------
	for key, value in {
		best = 0,
		coins = 0,
		wins = 0,
		losses = 0,
		xp = {},
		towers = { MachineGun = true, Bomb = true },
		slots = { { tower = "MachineGun", level = 1 } },
		bar = { "MachineGun", "Bomb" },
	} do
		levels("Set", key, value)
	end
	local reset = saved()
	check(reset.best == 0 and reset.coins == 0 and reset.losses == 0 and reset.towers.Frost == nil and reset.towers.Bomb == true and #reset.slots == 1, "joueur remis à zéro pour le test de l'interface")
	local clientDone = false
	local relay = ReplicatedStorage:WaitForChild("__AutoTestLog", 10)
	if relay then
		relay.OnServerEvent:Connect(function(_, text)
			if typeof(text) == "string" and string.find(text, "LEVELS:client=done", 1, true) then
				clientDone = true
			end
		end)
	end
	ReplicatedStorage:SetAttribute("LevelsTestPhase", "Client")

	for _ = 1, 3000 do -- (au plus 5 min)
		if clientDone then
			break
		end
		task.wait(0.1)
	end
	local final = levels("State")
	check(
		clientDone and final.levels.best >= 1 and final.levels.wins >= 1 and final.levels.losses >= 1 and final.levels.coins >= 80
			and (final.levels.xp.MachineGun or 0) >= 8 and (final.levels.xp.Bomb or 0) >= 8,
		`après le test de l'interface : niveau {final.levels.best} réussi, {final.levels.wins} victoire(s), {final.levels.losses} défaite(s), {final.levels.coins} pièces de niveau, {tostring(final.levels.xp.MachineGun)} XP pour l'Archer, {tostring(final.levels.xp.Bomb)} pour la Catapulte`
	)
end

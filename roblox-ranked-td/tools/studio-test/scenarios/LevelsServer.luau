-- Test des NIVEAUX (prototype de la nouvelle formule), côté serveur : tools/studio-test/phone.ps1 -Mode levels.
-- 1) D'abord, seul (le client attend) : accès, six combats en même temps (mesure), un niveau PERDU par celui qui
--    pose 2 Archers puis attend, le même niveau gagné en posant et en améliorant tout, récompenses, « Rejouer »,
--    niveau suivant, abandon, boutique à prix fixes, camp d'entraînement (emplacements, absence), ordre de la barre
--    rapide, améliorations débloquées par l'entraînement. Tout passe par les mêmes demandes que le remote
--    LevelAction (StudioDebug « Levels », « Action »).
-- 2) Puis il remet le joueur à zéro et donne la main au client (attribut LevelsTestPhase = "Client" de
--    ReplicatedStorage) : scenarios/LevelsClient.luau joue avec la vraie interface.
-- 3) Quand le client a fini (« LEVELS:client=done » dans son journal), il vérifie ce que le serveur a gardé.
-- Uniquement dans la place de test des niveaux (StudioDebug n'existe que dans Studio).
return function(log)
	local HttpService = game:GetService("HttpService")
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local dbg = game:GetService("ServerStorage"):WaitForChild("StudioDebug", 30)
	local Levels = require(ReplicatedStorage:WaitForChild("Shared").Levels)

	local function check(ok, message)
		log(if ok then "Info" else "Error", `[{if ok then "PASS" else "FAIL"}] niveaux : {message}`)
	end
	local function near(a, b, tolerance)
		return typeof(a) == "number" and math.abs(a - b) <= (tolerance or 0.5)
	end

	local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
	for _ = 1, 150 do
		if dbg:Invoke(player, "Data") and typeof(player:GetAttribute("Plot")) == "number" and player:GetAttribute("LevelsAccess") ~= nil then
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
	-- Accès et état de départ
	------------------------------------------------------------------
	local start = levels("State")
	check(
		player:GetAttribute("LevelsAccess") == true and start.access == true and start.active == nil,
		`dans la place de test des niveaux, le joueur de test y a droit (attribut LevelsAccess = {tostring(player:GetAttribute("LevelsAccess"))})`
	)
	check(
		start.levels.best == 0 and start.levels.coins == 0 and start.levels.towers.MachineGun == true and start.levels.towers.Bomb == true
			and #start.levels.slots == 1 and published().best == 0 and table.concat(published().towers, ",") == "MachineGun,Bomb",
		`nouveau joueur des niveaux : aucun niveau réussi, 0 pièce de niveau, deux tours (l'Archer et la Catapulte), un emplacement de camp (publié : {tostring(player:GetAttribute("LevelsState"))})`
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
	-- Six combats dans le même serveur : coût du calcul
	------------------------------------------------------------------
	-- 12 tours par joueur (un combat normal), puis 3 tours seulement (les monstres s'entassent : le pire cas).
	for _, case in { { 12, "12 tours chacun" }, { 3, "3 tours chacun : la carte pleine de monstres" } } do
		-- (170 s : tout le flot du niveau 10, dont la fin, le moment le plus chargé : 3,5 monstres par seconde)
		local bench = levels("Bench", 6, 170, case[1])
		check(
			bench.games == 6 and bench.enemiesPeak >= 100 and bench.averageMs < 2 and bench.p99Ms < 4,
			string.format(
				"six niveaux 10 joués en même temps pendant 170 s de jeu (%s) : %.2f ms par image en moyenne, %.2f ms pour 99 %% des images, %.1f ms pour la pire (une image du serveur = 16,7 ms), jusqu'à %d monstres à la fois",
				case[2],
				bench.averageMs,
				bench.p99Ms,
				bench.worstMs,
				bench.enemiesPeak
			)
		)
	end

	------------------------------------------------------------------
	-- Accès fermé, demandes refusées
	------------------------------------------------------------------
	levels("Access", "Off")
	local closedOk = action("Start", 1)
	check(player:GetAttribute("LevelsAccess") == false and closedOk == false and player:GetAttribute("LevelArena") == nil, "accès fermé : attribut à faux, lancer un niveau est refusé")
	levels("Access", nil)
	check(player:GetAttribute("LevelsAccess") == true, "accès rouvert")
	local farOk, farReason = action("Start", 3)
	check(farOk == false and farReason == "Réussis d'abord le niveau 1", `niveau 3 refusé tant que le niveau 1 n'est pas réussi (« {tostring(farReason)} »)`)
	check(action("Start", 0) == false and action("Start", 11) == false and action("Start", 1.5) == false and action("Start", "1") == false, "niveaux inconnus refusés (0, 11, 1,5, texte)")
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
	check(action("Speed", 2) == true and levels("State").active.simSpeed == 2 and action("Speed", 1) == true, "x2 allumé puis éteint")
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
			and near(after.xp.Bomb, 8, 0.5),
		`sauvegarde : niveau 1 réussi, {after.coins} pièces, {tostring(after.xp.MachineGun)} XP pour l'Archer, {tostring(after.xp.Bomb)} pour la Catapulte`
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
	-- Le client prend la main, comme un nouveau joueur des niveaux
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

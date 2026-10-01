-- Test « téléphone » (tools/studio-test/phone.ps1), côté serveur.
-- 1) D'abord, rien : le joueur de test est un NOUVEAU joueur, et dans cette place de test le tuto démarre tout seul
--    comme dans le jeu publié (objet __AutoTestNewPlayer, lu par TutorialUI.luau). Le client regarde ses premières
--    étapes à la taille du téléphone, pose un Archer, puis passe le tuto (« Passer ») : le serveur attend ce moment.
-- 2) Puis il prépare une parcelle de joueur avancé pour que le client regarde toutes les fenêtres à la taille d'un
--    écran de téléphone : tuto déjà fait, 8 emplacements, 3 tours posées (un Archer avec ses 2 runes), des runes dans
--    l'inventaire, toutes les tours débloquées, 22,6 M de pièces.
-- Uniquement dans la place de test construite par phone.ps1 (StudioDebug n'existe que dans Studio).
return function(log)
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local dbg = game:GetService("ServerStorage"):WaitForChild("StudioDebug", 30)
	local IdleTowers = require(ReplicatedStorage:WaitForChild("Shared").IdleTowers)

	local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
	for _ = 1, 150 do
		if dbg:Invoke(player, "Data") and typeof(player:GetAttribute("Plot")) == "number" then
			break
		end
		task.wait(0.2)
	end
	local data = dbg:Invoke(player, "Data")
	if not data then
		log("Error", "[FAIL] téléphone : données du joueur introuvables")
		return
	end

	-- 1) Le nouveau joueur : ses données de départ, tuto pas encore fait. Le client fait tout le tuto en suivant sa
	--    flèche (une tour posée, améliorée, un lancer de l'autel, la forge ouverte) : le drapeau tutorialDone arrive
	--    ici (remote TutorialAction, Hub/Tutorial.luau), et l'entonnoir des statistiques a ses 5 étapes dans l'ordre
	--    (Hub/Funnel.luau). Puis il relance le tuto et le passe (« Passer », deux appuis sur téléphone).
	--    (« Data » renvoie une copie des données : on la redemande pour voir ce qui a changé.)
	--    Il est sur la parcelle 2, pas la 1 (objet __AutoTestPlot de cette place de test, lu par Hub/Plots.luau), comme
	--    le 2e joueur arrivé sur un serveur : le client vérifie que le tuto le guide vers SA parcelle.
	local fresh = data.tutorialDone == false and next(data.idle.towers) == nil and player:GetAttribute("TutorialDone") == false
		and player:GetAttribute("Plot") == 2
	log(
		if fresh then "Info" else "Error",
		`[{if fresh then "PASS" else "FAIL"}] téléphone : le joueur de test arrive en nouveau joueur, sur la parcelle {tostring(player:GetAttribute("Plot"))} (tuto fait : {tostring(data.tutorialDone)}, aucune tour : {next(data.idle.towers) == nil}, {data.coins} pièces)`
	)
	-- Défilé d'accueil (IdleConfig.NEW_PLAYER_PARADE, PlotGame:startParade) : dès l'arrivée du nouveau joueur, des
	-- fantassins marchent déjà sur tout le chemin (les emplacements gratuits sont au bout, vers 205-300 studs), et
	-- rien ne « rate » tant qu'aucune tour n'est posée. Plus bas : la première tour posée tue dans les 2 secondes.
	local plots = workspace:FindFirstChild("Hub") and workspace.Hub:FindFirstChild("Plots")
	local plotFolder = plots and plots:FindFirstChild("Plot" .. tostring(player:GetAttribute("Plot")))
	local arrival = dbg:Invoke(player, "Progress") or {}
	local paradeOk = arrival.parade == true and (arrival.alive or 0) >= 8 and (arrival.lead or 0) >= 250
		and plotFolder ~= nil and plotFolder:GetAttribute("State") == "Running" and plotFolder:GetAttribute("Wave") == 1
	log(
		if paradeOk then "Info" else "Error",
		`[{if paradeOk then "PASS" else "FAIL"}] téléphone : défilé d'accueil du nouveau joueur ({tostring(arrival.parade)}) -> {tostring(arrival.alive)} ennemis déjà en marche, le plus avancé à {math.floor(arrival.lead or 0)} studs sur 358, état « {tostring(plotFolder and plotFolder:GetAttribute("State"))} », vague {tostring(plotFolder and plotFolder:GetAttribute("Wave"))}`
	)
	local funnelStart = dbg:Invoke(player, "Funnel") or {}
	local finished = false
	local towersFolder = plotFolder and plotFolder:FindFirstChild("Towers")
	local firstTowerAt, firstKillAfter, killsAtTower, paradeAfter = nil, nil, 0, nil
	local stoppedBefore = false -- (une vague « ratée » avant la première tour : l'état quitterait « Running »)
	for _ = 1, 2400 do -- (au plus 4 min : le client attend la taille du téléphone avant ses captures)
		if not firstKillAfter then
			if not firstTowerAt then
				if plotFolder and plotFolder:GetAttribute("State") ~= "Running" then
					stoppedBefore = true
				end
				if towersFolder and #towersFolder:GetChildren() > 0 then
					firstTowerAt = os.clock()
					killsAtTower = (dbg:Invoke(player, "Progress") or {}).kills or 0
				end
			else
				local progress = dbg:Invoke(player, "Progress") or {}
				if (progress.kills or 0) > killsAtTower then
					firstKillAfter = os.clock() - firstTowerAt
					paradeAfter = progress.parade
				elseif os.clock() - firstTowerAt > 10 then
					firstKillAfter = math.huge
				end
			end
		end
		if player:GetAttribute("TutorialDone") == true then
			finished = true
			break
		end
		task.wait(0.1)
	end
	local quickOk = firstTowerAt ~= nil and firstKillAfter ~= nil and firstKillAfter <= 2 and killsAtTower == 0
		and not stoppedBefore and paradeAfter == false
	log(
		if quickOk then "Info" else "Error",
		`[{if quickOk then "PASS" else "FAIL"}] téléphone : la première tour du nouveau joueur tue un ennemi {if firstKillAfter then string.format("%.1f", firstKillAfter) else "?"} s après avoir été posée (2 s au plus ; avant le défilé : 10 à 20 s), aucune vague ratée avant ({tostring(not stoppedBefore)}), défilé fini et vraie vague 1 lancée ({tostring(paradeAfter == false)})`
	)
	local tutorial = dbg:Invoke(player, "Tutorial") or {}
	local after = dbg:Invoke(player, "Data")
	local placed, count = nil, 0
	for _, saved in (if after then after.idle.towers else {}) do
		placed = saved
		count += 1
	end
	local ok = finished and tutorial.done == true and tutorial.lastAction == "Done" and tutorial.lastStep == 4 and tutorial.steps == 4
		and count == 1 and placed.type == "MachineGun" and placed.level == 2 and after.idle.towerSpinsBought == 1
	log(
		if ok then "Info" else "Error",
		`[{if ok then "PASS" else "FAIL"}] téléphone : le nouveau joueur a fait tout le tuto (« {tostring(tutorial.lastAction)} » à l'étape {tostring(tutorial.lastStep)}/{tostring(tutorial.steps)}, tutorialDone sauvegardé = {tostring(tutorial.done)}) : {count} tour ({placed and placed.type} niveau {placed and placed.level}), {after and after.idle.towerSpinsBought} lancer de l'autel`
	)
	-- Statistiques : les 5 étapes de l'entonnoir, dans l'ordre, et rien d'autre ; le joueur n'est plus suivi ensuite.
	local funnel = dbg:Invoke(player, "Funnel") or {}
	local wanted = "Arrivee > 1re tour posee > 1re amelioration > 1er lancer de l'autel > Tuto termine"
	local got = table.concat(funnel.steps or {}, " > ")
	local funnelOk = funnelStart.tracked == true and (funnelStart.steps or {})[1] == "Arrivee" and #(funnelStart.steps or {}) == 1
		and got == wanted and funnel.tracked == false and funnel.skipped == nil and funnel.api == true
	log(
		if funnelOk then "Info" else "Error",
		`[{if funnelOk then "PASS" else "FAIL"}] téléphone : statistiques du nouveau joueur -> à l'arrivée « {table.concat(funnelStart.steps or {}, " > ")} », à la fin du tuto « {got} » (fonctions de Roblox présentes : {tostring(funnel.api)})`
	)
	-- Le 2e tuto du client (« Replay »), passé par le bouton « Passer » : à la dernière étape (les autres sont faites).
	local skipped = false
	for _ = 1, 450 do -- (au plus 90 s)
		local state = dbg:Invoke(player, "Tutorial") or {}
		if (state.replays or 0) >= 1 and state.done == true then
			skipped = true
			break
		end
		task.wait(0.2)
	end
	local second = dbg:Invoke(player, "Tutorial") or {}
	local skipOk = skipped and second.lastAction == "Skip" and second.lastStep == 4
	log(
		if skipOk then "Info" else "Error",
		`[{if skipOk then "PASS" else "FAIL"}] téléphone : 2e tuto passé par « Passer » (« {tostring(second.lastAction)} » à l'étape {tostring(second.lastStep)}/{tostring(second.steps)})`
	)

	-- 2) La parcelle du joueur avancé (tuto fini ; l'attribut, au cas où le client n'y serait pas arrivé).
	player:SetAttribute("TutorialDone", true)
	dbg:Invoke(player, "Set", "rebirthHintShown", true)

	local unlocked = {}
	for _, towerType in IdleTowers.ORDER do
		unlocked[towerType] = true
	end
	dbg:Invoke(player, "Set", "unlockedTowers", unlocked)
	local owned = {}
	for spotIndex = 1, 8 do
		owned[tostring(spotIndex)] = true
	end
	dbg:Invoke(player, "Set", "ownedSpots", owned)
	dbg:Invoke(player, "Call", "refreshSpots")
	dbg:Invoke(player, "Set", "highestWave", 63)
	dbg:Invoke(player, "Set", "bestWave", 63)
	dbg:Invoke(player, "Coins", 22.6e6)
	dbg:Invoke(player, "Set", "towers", {
		["1"] = { type = "MachineGun", level = 34, spent = 0, runes = { Damage = "Damage20", Speed = "Speed2" } },
		["2"] = { type = "Frost", level = 12, spent = 0, runes = {} },
		["3"] = { type = "Bomb", level = 20, spent = 0, runes = { Damage = "Damage3" } },
	})
	dbg:Invoke(player, "Call", "debugReloadTowers")
	dbg:Invoke(player, "Set", "bonuses", { "Damage5", "Damage2", "Speed2", "Damage10" })
	dbg:Invoke(player, "Call", "publishInventory")
	ReplicatedStorage:SetAttribute("PhoneTestReady", true)
	log("Info", "[PHONE] serveur prêt")
end

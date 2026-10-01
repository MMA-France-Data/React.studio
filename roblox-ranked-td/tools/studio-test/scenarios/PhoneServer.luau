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

	-- 1) Le nouveau joueur : ses données de départ, tuto pas encore fait. Le client fait le début du tuto et le passe
	--    (remote TutorialAction, Hub/Tutorial.luau) : le drapeau tutorialDone arrive ici.
	--    (« Data » renvoie une copie des données : on la redemande pour voir ce qui a changé.)
	--    Il est sur la parcelle 2, pas la 1 (objet __AutoTestPlot de cette place de test, lu par Hub/Plots.luau), comme
	--    le 2e joueur arrivé sur un serveur : le client vérifie que le tuto le guide vers SA parcelle.
	local fresh = data.tutorialDone == false and next(data.idle.towers) == nil and player:GetAttribute("TutorialDone") == false
		and player:GetAttribute("Plot") == 2
	log(
		if fresh then "Info" else "Error",
		`[{if fresh then "PASS" else "FAIL"}] téléphone : le joueur de test arrive en nouveau joueur, sur la parcelle {tostring(player:GetAttribute("Plot"))} (tuto fait : {tostring(data.tutorialDone)}, aucune tour : {next(data.idle.towers) == nil}, {data.coins} pièces)`
	)
	local skipped = false
	for _ = 1, 900 do -- (au plus 3 min : le client attend la taille du téléphone avant ses captures)
		if player:GetAttribute("TutorialDone") == true then
			skipped = true
			break
		end
		task.wait(0.2)
	end
	local tutorial = dbg:Invoke(player, "Tutorial") or {}
	local after = dbg:Invoke(player, "Data")
	local placed = after and after.idle.towers["1"]
	local ok = skipped and tutorial.done == true and tutorial.lastAction == "Skip" and tutorial.lastStep == 3 and tutorial.steps == 5
		and placed ~= nil and placed.type == "MachineGun"
	log(
		if ok then "Info" else "Error",
		`[{if ok then "PASS" else "FAIL"}] téléphone : le nouveau joueur a posé son Archer ({placed and placed.type}) puis passé le tuto (« {tostring(tutorial.lastAction)} » à l'étape {tostring(tutorial.lastStep)}/{tostring(tutorial.steps)}, tutorialDone sauvegardé = {tostring(tutorial.done)})`
	)

	-- 2) La parcelle du joueur avancé (tuto fini : le client l'a passé ; l'attribut, au cas où il n'y serait pas arrivé).
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

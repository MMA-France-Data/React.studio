-- Test « téléphone » (tools/studio-test/phone.ps1), côté serveur : prépare une parcelle de joueur avancé pour que
-- le client regarde toutes les fenêtres à la taille d'un écran de téléphone : tuto déjà fait, 8 emplacements, 3 tours
-- posées (un Archer avec ses 2 runes), des runes dans l'inventaire, toutes les tours débloquées, 22,6 M de pièces.
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
	data.tutorialDone = true
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

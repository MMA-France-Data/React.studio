-- Scénario de test côté serveur (map principale), exécuté par le plugin AutoPlayTest.
-- Il pilote la partie avec ServerStorage.StudioDebug (Hub/init.luau, uniquement dans Studio) et
-- écrit [PASS] / [FAIL] dans la sortie.
return function(log)
	local Players = game:GetService("Players")
	local dbg = game:GetService("ServerStorage"):WaitForChild("StudioDebug", 30)
	local function say(msg) log("Info", "[TEST] " .. msg) end
	local function check(ok, msg) log(ok and "Info" or "Error", (ok and "[PASS] " or "[FAIL] ") .. msg) end
	local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
	local data
	for _ = 1, 150 do
		data = dbg:Invoke(player, "Data")
		if data then break end
		task.wait(0.2)
	end
	assert(data, "données jamais chargées")
	say(`données chargées : coins={data.coins} wave={data.idle.wave}`)
	task.wait(3)

	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local PlotLayout = require(ReplicatedStorage.Shared.PlotLayout)
	local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)

	local function owns(d, spotIndex)
		return d.idle.ownedSpots[tostring(spotIndex)] == true
	end
	-- Emplacements possédés, triés : "1,2,3,4,6,15"
	local function ownedList(d)
		local list = {}
		for spotIndex = 1, #PlotLayout.SPOTS do
			if owns(d, spotIndex) then
				table.insert(list, spotIndex)
			end
		end
		return table.concat(list, ",")
	end

	local function state()
		local d = dbg:Invoke(player, "Data")
		local towers, count = {}, 0
		for k, t in d.idle.towers do
			count += 1
			table.insert(towers, `{k}:{t.type}@{t.level}{t.bonus and ("+" .. t.bonus) or ""}`)
		end
		table.sort(towers)
		say(`état : coins={d.coins} wave={d.idle.wave} best={d.idle.bestWave} highest={d.idle.highestWave} bonus={d.idle.coinBonus} rebirths={d.idle.rebirths} spots={d.idle.unlockedSpots} [{ownedList(d)}] spin={d.idle.pendingSpinTier} towers={table.concat(towers, " ")}`)
		return d, count
	end
	state()

	-- Tout débloquer et poser les 8 tours, quelques niveaux
	dbg:Invoke(player, "Coins", 1e9)
	dbg:Invoke(player, "Set", "unlockedTowers", { MachineGun = true, Frost = true, Bomb = true, Tesla = true, Rocket = true, Laser = true, Chain = true, Orbital = true })

	-- Emplacements dans n'importe quel ordre : le n-ième emplacement possédé coûte spotCost(n),
	-- quel que soit celui qu'on choisit.
	local plotFolder = workspace.Hub.Plots:FindFirstChild("Plot" .. tostring(player:GetAttribute("Plot")))
	-- Cadenas de la map : seuls les emplacements non possédés en ont un, tous au même prix (le prochain).
	local function checkPads(label)
		local d = dbg:Invoke(player, "Data")
		local price = "🔒 " .. NumberFormat.short(PlotLayout.spotCost(d.idle.unlockedSpots + 1))
		local wrong = {}
		for _, pad in plotFolder.Spots:GetChildren() do
			local owned = owns(d, pad:GetAttribute("SpotIndex"))
			local lock = pad:FindFirstChild("Lock")
			local priceLabel = lock and lock:FindFirstChild("Price")
			if pad:GetAttribute("Unlocked") ~= owned or (owned and lock) or (not owned and (not priceLabel or priceLabel.Text ~= price)) then
				table.insert(wrong, pad.Name)
			end
		end
		check(#wrong == 0, `{label} : cadenas à jour, tous à « {price} » (faux : {table.concat(wrong, " ")})`)
		check(plotFolder:GetAttribute("OwnedSpots") == ownedList(d), `{label} : attribut OwnedSpots = {ownedList(d)} (obtenu {plotFolder:GetAttribute("OwnedSpots")})`)
	end
	local function buyAndCheck(spotIndex)
		local d0 = dbg:Invoke(player, "Data")
		local count = d0.idle.unlockedSpots
		local cost = PlotLayout.spotCost(count + 1)
		dbg:Invoke(player, "Call", "buySpot", spotIndex)
		local d1 = dbg:Invoke(player, "Data")
		check(owns(d1, spotIndex) and d1.idle.unlockedSpots == count + 1, `emplacement {spotIndex} acheté ({count} -> {d1.idle.unlockedSpots} possédés)`)
		check(d0.coins - d1.coins == cost, `emplacement {spotIndex} payé spotCost({count + 1}) = {cost} (payé {d0.coins - d1.coins})`)
	end
	local function refusedBuy(spotIndex, label)
		local d0 = dbg:Invoke(player, "Data")
		dbg:Invoke(player, "Call", "buySpot", spotIndex)
		local d1 = dbg:Invoke(player, "Data")
		check(d1.coins == d0.coins and d1.idle.unlockedSpots == d0.idle.unlockedSpots and ownedList(d1) == ownedList(d0), `achat refusé : {label} (pièces et emplacements inchangés)`)
	end

	checkPads("départ")
	buyAndCheck(15)
	buyAndCheck(6)
	local d = dbg:Invoke(player, "Data")
	check(owns(d, 15) and owns(d, 6) and not owns(d, 5), `15 et 6 achetés dans le désordre, 5 encore verrouillé [{ownedList(d)}]`)
	checkPads("après 15 et 6")
	refusedBuy(15, "emplacement 15 déjà possédé")
	refusedBuy(1, "emplacement de départ 1")
	refusedBuy(0, "numéro 0")
	refusedBuy(23, "numéro 23")
	refusedBuy(2.5, "numéro 2.5")
	refusedBuy("x", "numéro \"x\"")
	refusedBuy(nil, "sans numéro")
	-- Les emplacements 5, 7 et 8 pour poser les 8 tours ci-dessous.
	for _, spotIndex in { 5, 7, 8 } do
		buyAndCheck(spotIndex)
	end
	checkPads("après 5, 7 et 8")

	-- Une tour sur l'emplacement 15 (acheté hors ordre), puis revendue : elle est loin des autres
	-- et le scénario client vérifie que toutes les étiquettes de niveau s'allument près des tours 1 à 8.
	dbg:Invoke(player, "Call", "placeTower", 15, "MachineGun")
	d = dbg:Invoke(player, "Data")
	check(d.idle.towers["15"] ~= nil and d.idle.towers["15"].type == "MachineGun", "tour posée sur l'emplacement 15 (acheté hors ordre)")
	dbg:Invoke(player, "Call", "sellTower", 15)
	dbg:Invoke(player, "Call", "placeTower", 9, "MachineGun")
	d = dbg:Invoke(player, "Data")
	check(d.idle.towers["15"] == nil, "tour de l'emplacement 15 revendue")
	check(d.idle.towers["9"] == nil, "pose refusée sur l'emplacement 9 (verrouillé)")

	local types = { "MachineGun", "Frost", "Bomb", "Tesla", "Rocket", "Laser", "Chain", "Orbital" }
	for i, t in types do dbg:Invoke(player, "Call", "placeTower", i, t) end
	for _ = 1, 5 do for i = 1, 8 do dbg:Invoke(player, "Call", "upgradeTower", i) end end
	-- Une tour de haut niveau pour voir les paliers visuels
	for _ = 1, 30 do dbg:Invoke(player, "Call", "upgradeTower", 6) end
	dbg:Invoke(player, "Set", "bonuses", { "Damage10", "Speed2" })
	dbg:Invoke(player, "Call", "applyBonus", 1, "Damage10")
	dbg:Invoke(player, "Call", "applyBonus", 2, "Speed2")
	dbg:Invoke(player, "Set", "pendingSpinTier", 4)
	-- Run à la vague 50 : le client ouvre la fenêtre de renaissance puis clique « Renaître »
	dbg:Invoke(player, "Set", "bestWave", 50)
	local before, towerCount = state()

	-- Attendre la renaissance faite par le client (via le vrai remote)
	for _ = 1, 60 do
		task.wait(1)
		d = dbg:Invoke(player, "Data")
		if d.idle.rebirths >= 1 then break end
	end
	local after, afterCount = state()
	check(after.idle.rebirths == 1, "renaissance faite depuis l'interface")
	check(after.idle.coinBonus == 4, `bonus après renaissance vague 50 = 4 (obtenu {after.idle.coinBonus})`)
	check(after.idle.bestWave == 1 and after.idle.wave <= 2, `vague et run remises à 1 (wave={after.idle.wave} best={after.idle.bestWave})`)
	check(afterCount == towerCount, `tours gardées ({afterCount}/{towerCount})`)
	check(after.coins >= before.coins, `pièces gardées ({after.coins} >= {before.coins})`)
	check(
		after.idle.unlockedSpots == before.idle.unlockedSpots and ownedList(after) == ownedList(before) and owns(after, 15),
		`emplacements gardés [{ownedList(after)}]`
	)
	check(after.idle.towers["6"] and after.idle.towers["6"].level == before.idle.towers["6"].level, "améliorations gardées")

	-- Refus sous la vague 15
	dbg:Invoke(player, "Set", "bestWave", 10)
	dbg:Invoke(player, "Call", "rebirth")
	d = dbg:Invoke(player, "Data")
	check(d.idle.rebirths == 1 and d.idle.coinBonus == 4, "renaissance refusée à la vague 10")
	-- Vague 100 : +7 % -> 11 %
	dbg:Invoke(player, "Set", "bestWave", 100)
	dbg:Invoke(player, "Call", "rebirth")
	d = dbg:Invoke(player, "Data")
	check(d.idle.rebirths == 2 and d.idle.coinBonus == 11, `vague 100 : bonus total 11 (obtenu {d.idle.coinBonus})`)
	-- Vague 15 : +1 % -> 12 %
	dbg:Invoke(player, "Set", "bestWave", 15)
	dbg:Invoke(player, "Call", "rebirth")
	d = dbg:Invoke(player, "Data")
	check(d.idle.coinBonus == 12, `vague 15 : bonus total 12 (obtenu {d.idle.coinBonus})`)

	for _ = 1, 4 do
		task.wait(5)
		state()
	end
end

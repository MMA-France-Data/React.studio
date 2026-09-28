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

	local function state()
		local d = dbg:Invoke(player, "Data")
		local towers, count = {}, 0
		for k, t in d.idle.towers do
			count += 1
			table.insert(towers, `{k}:{t.type}@{t.level}{t.bonus and ("+" .. t.bonus) or ""}`)
		end
		table.sort(towers)
		say(`état : coins={d.coins} wave={d.idle.wave} best={d.idle.bestWave} highest={d.idle.highestWave} bonus={d.idle.coinBonus} rebirths={d.idle.rebirths} spots={d.idle.unlockedSpots} spin={d.idle.pendingSpinTier} towers={table.concat(towers, " ")}`)
		return d, count
	end
	state()

	-- Tout débloquer et poser les 8 tours, quelques niveaux
	dbg:Invoke(player, "Coins", 1e9)
	dbg:Invoke(player, "Set", "unlockedTowers", { MachineGun = true, Frost = true, Bomb = true, Tesla = true, Rocket = true, Laser = true, Chain = true, Orbital = true })
	for _ = 1, 4 do dbg:Invoke(player, "Call", "buySpot") end
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
	local d
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
	check(after.idle.unlockedSpots == before.idle.unlockedSpots, "emplacements gardés")
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

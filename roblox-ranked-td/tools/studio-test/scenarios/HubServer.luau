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
	local IdleConfig = require(ReplicatedStorage.Shared.IdleConfig)

	-- Nouveau joueur : pièces de départ, plus de lancer gratuit en attente (lancers payés en pièces).
	check(data.coins == IdleConfig.STARTING_COINS, `pièces de départ = {IdleConfig.STARTING_COINS} (obtenu {data.coins})`)
	check(data.idle.pendingSpinTier == nil, "plus de champ pendingSpinTier dans les données")
	-- Nouveau joueur : aucun lancer de l'autel acheté (compteur des prix à 0, publié pour l'autel du client).
	check(
		data.idle.towerSpinsBought == 0 and player:GetAttribute("TowerSpinsBought") == 0,
		`compteur de lancers de l'autel à 0 (données {data.idle.towerSpinsBought}, attribut {player:GetAttribute("TowerSpinsBought")})`
	)
	-- Forge runique : plus de délai (plus de champ lastBonusSpinAt), compteur des lancers en pièces à 0, 1er prix
	-- 100 K ; sans tour posée, la forge est bloquée (« Pose d'abord une tour »).
	check(
		data.idle.forgeSpinsBought == 0
			and data.idle.lastBonusSpinAt == nil
			and player:GetAttribute("ForgeSpinsBought") == 0
			and player:GetAttribute("ForgeCoinPrice") == IdleConfig.FORGE_FIRST_PRICE
			and player:GetAttribute("LastBonusSpinAt") == nil,
		`forge : compteur à 0 (données {data.idle.forgeSpinsBought}, attribut {player:GetAttribute("ForgeSpinsBought")}), prix {player:GetAttribute("ForgeCoinPrice")}, plus de délai`
	)
	check(
		player:GetAttribute("ForgeBlocked") == IdleConfig.FORGE_NO_TOWER and player:GetAttribute("ForgeDrawable") == "",
		`forge sans tour posée : bloquée (« {player:GetAttribute("ForgeBlocked")} »)`
	)

	-- Gains d'absence : première connexion = rien (pas encore d'heure de dernière visite), puis l'heure est notée.
	local firstAbsence = dbg:Invoke(player, "LastAbsence")
	check(
		firstAbsence ~= nil and firstAbsence.amount == 0 and firstAbsence.seconds == 0,
		`première connexion : aucun gain d'absence (obtenu {firstAbsence and firstAbsence.amount})`
	)
	local firstSeen = dbg:Invoke(player, "Data").idle.lastSeenAt
	check(typeof(firstSeen) == "number" and math.abs(firstSeen - os.time()) < 120, `heure de dernière visite notée à l'arrivée ({firstSeen})`)
	-- Passes de jeu : pas encore créés (IDs à 0) -> non possédés, vitesse normale.
	local startPlot = workspace.Hub.Plots:FindFirstChild("Plot" .. tostring(player:GetAttribute("Plot")))
	check(
		player:GetAttribute("PassAutoCollect") == false
			and player:GetAttribute("PassSpeedX2") == false
			and player:GetAttribute("SpeedX2Enabled") == false
			and startPlot ~= nil
			and startPlot:GetAttribute("SimSpeed") == 1,
		`sans pass : PassAutoCollect={player:GetAttribute("PassAutoCollect")} PassSpeedX2={player:GetAttribute("PassSpeedX2")} SpeedX2Enabled={player:GetAttribute("SpeedX2Enabled")} SimSpeed={startPlot and startPlot:GetAttribute("SimSpeed")}`
	)
	check(
		player:GetAttribute("PassCoinsX2") == false and startPlot ~= nil and startPlot:GetAttribute("CoinMultiplier") == 1,
		`sans pass Pièces x2 : PassCoinsX2={player:GetAttribute("PassCoinsX2")} CoinMultiplier={startPlot and startPlot:GetAttribute("CoinMultiplier")}`
	)

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
			-- Runes posées (2 emplacements : dégâts, vitesse), ex. 1:MachineGun@6+Damage10+Speed2
			local runes = IdleConfig.runeList(t.runes)
			table.insert(towers, `{k}:{t.type}@{t.level}{if runes ~= "" then "+" .. string.gsub(runes, ",", "+") else ""}`)
		end
		table.sort(towers)
		local dupes = {}
		for towerType, n in d.idle.towerDupes do
			table.insert(dupes, `{towerType}:{NumberFormat.short(n)}`)
		end
		table.sort(dupes)
		say(`état : coins={NumberFormat.short(d.coins)} wave={d.idle.wave} best={d.idle.bestWave} highest={d.idle.highestWave} bonus={d.idle.coinBonus} rebirths={d.idle.rebirths} spots={d.idle.unlockedSpots} [{ownedList(d)}] doublons=[{table.concat(dupes, " ")}] towers={table.concat(towers, " ")}`)
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
	-- Remplacement : jamais par accident. Poser sur une tour existante est refusé, sauf si le client nomme
	-- la tour remplacée (4e argument, envoyé seulement par la confirmation de PlotUI).
	dbg:Invoke(player, "Call", "placeTower", 3, "Frost")
	dbg:Invoke(player, "Call", "placeTower", 3, "Frost", "Tesla")
	d = dbg:Invoke(player, "Data")
	check(d.idle.towers["3"].type == "Bomb", "pose sur une tour existante refusée sans confirmation (ou avec la mauvaise tour)")
	dbg:Invoke(player, "Call", "placeTower", 3, "Frost", "Bomb")
	d = dbg:Invoke(player, "Data")
	check(d.idle.towers["3"].type == "Frost", "remplacement confirmé (Catapulte -> Totem de givre) accepté")
	dbg:Invoke(player, "Call", "placeTower", 3, "Bomb", "Frost") -- on remet la Catapulte pour la suite
	for _ = 1, 5 do for i = 1, 8 do dbg:Invoke(player, "Call", "upgradeTower", i) end end
	-- Une tour de haut niveau pour voir les paliers visuels
	for _ = 1, 30 do dbg:Invoke(player, "Call", "upgradeTower", 6) end
	dbg:Invoke(player, "Set", "bonuses", { "Damage10", "Speed2" })
	dbg:Invoke(player, "Call", "applyBonus", 1, "Damage10")
	dbg:Invoke(player, "Call", "applyBonus", 2, "Speed2")
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

	----------------------------------------------------------------------
	-- Une seule fuite = vague ratée (plus de PV de base)
	----------------------------------------------------------------------
	check(
		plotFolder:GetAttribute("BaseHealth") == nil and plotFolder:GetAttribute("MaxBaseHealth") == nil,
		"plus d'attributs BaseHealth / MaxBaseHealth sur la parcelle"
	)
	-- Vague 301 : des PV astronomiques, les tours ne peuvent rien contre le premier ennemi.
	dbg:Invoke(player, "StartWave", 301)
	task.wait(0.5)
	d = dbg:Invoke(player, "Data")
	check(
		d.idle.wave == 301 and plotFolder:GetAttribute("State") == "Running",
		`vague 301 en cours tant que personne n'a atteint la base (wave={d.idle.wave} state={plotFolder:GetAttribute("State")})`
	)
	local leaked = dbg:Invoke(player, "Leak")
	task.wait(0.3)
	d = dbg:Invoke(player, "Data")
	check(
		leaked == true and d.idle.wave == 300 and plotFolder:GetAttribute("State") == "Intermission",
		`un seul ennemi au bout du chemin : vague ratée, retour à la 300 (wave={d.idle.wave} state={plotFolder:GetAttribute("State")})`
	)

	----------------------------------------------------------------------
	-- Garde colossale = un seul colosse, Seigneur de guerre = un seul boss
	----------------------------------------------------------------------
	for _, w in { 5, 15, 25, 105, 305, 2995 } do
		local list = IdleConfig.buildWave(w)
		check(
			IdleConfig.waveType(w) == "Giants" and #list == 1 and list[1].enemy == "Giant",
			`vague {w} ({IdleConfig.waveType(w)}) : un seul chevalier colossal ({#list} ennemi(s))`
		)
	end
	for _, w in { 10, 20, 100, 310, 3000 } do
		local bosses = 0
		for _, item in IdleConfig.buildWave(w) do
			bosses += if item.enemy == "Boss" then 1 else 0
		end
		check(IdleConfig.waveType(w) == "Boss" and bosses == 1, `vague {w} ({IdleConfig.waveType(w)}) : un seul boss ({bosses})`)
	end
	-- Vitesses du mode infini (IdleConfig ; le ranked garde celles de Enemies.luau) : les cavaliers restent
	-- les plus rapides, mais plus des éclairs. Le Totem de givre ralentit fortement, sans trou entre deux impulsions.
	local Enemies = require(ReplicatedStorage.Shared.Enemies)
	local function idleSpeed(name)
		return Enemies.Defs[name].speed * IdleConfig.ENEMY_SPEED_MULTIPLIER * IdleConfig.enemySpeedFactor(name)
	end
	local fastest = true
	for name in Enemies.Defs do
		if name ~= "Fast" and idleSpeed(name) >= idleSpeed("Fast") then
			fastest = false
		end
	end
	check(fastest and idleSpeed("Fast") <= 15, `cavaliers : {string.format("%.1f", idleSpeed("Fast"))} studs/s (22,4 avant), toujours les plus rapides`)
	local frost = require(ReplicatedStorage.Shared.IdleTowers).Defs.Frost
	check(
		frost.slow >= 0.5 and frost.slowDuration > frost.cooldown,
		`Totem de givre : -{math.floor(frost.slow * 100 + 0.5)} % de vitesse pendant {frost.slowDuration} s, une impulsion toutes les {frost.cooldown} s`
	)
	-- Sur la parcelle : la vague 305 ne fait apparaître qu'un ennemi. Son colosse (PV astronomiques) ne
	-- meurt pas pendant les tests de l'autel : aucune pièce ne tombe, les comptes de pièces restent exacts.
	dbg:Invoke(player, "StartWave", 305)
	task.wait(0.3)
	check(
		plotFolder:GetAttribute("Wave") == 305 and plotFolder:GetAttribute("EnemiesLeft") == 1,
		`vague 305 sur la parcelle : {plotFolder:GetAttribute("EnemiesLeft")} ennemi restant (1 attendu)`
	)

	----------------------------------------------------------------------
	-- Autel des héros : lancers payés en pièces, aux chances du RECORD
	----------------------------------------------------------------------
	local RARITY_INDEX = {}
	for index, rarity in IdleConfig.RARITY_ORDER do
		RARITY_INDEX[rarity] = index
	end
	-- Tours débloquées + doublons : chaque lancer en ajoute exactement 1.
	local function inventoryTotal(dd)
		local total = 0
		for _, unlocked in dd.idle.unlockedTowers do
			total += if unlocked then 1 else 0
		end
		for _, n in dd.idle.towerDupes do
			total += n
		end
		return total
	end
	-- Égalité à 1e-9 près (les très grands nombres de pièces ne sont pas exacts au dernier chiffre).
	local function near(a, b)
		return math.abs(a - b) <= math.max(1e-9 * math.abs(b), 1e-9)
	end
	local function setCoins(amount)
		dbg:Invoke(player, "Coins", -1e308) -- remet à 0
		-- Jamais l'infini (prix « MAX ») : les pièces doivent rester sauvegardables.
		dbg:Invoke(player, "Coins", math.min(amount, 1e300))
	end
	-- Compteur des lancers déjà achetés : entier, fini, jamais négatif ni NaN (sauvegardable).
	local function cleanCounter(n)
		return typeof(n) == "number" and n == n and n >= 0 and n < math.huge and n == math.floor(n)
	end
	local GROWTH = IdleConfig.TOWER_SPIN_PRICE_GROWTH
	-- Prix attendu de `count` lancers après `bought` lancers : la somme des prochains prix, un par un
	-- (prix du n-ième lancer = prix de base x 1,0005^n), sans passer par la formule de IdleConfig.
	local function sumOfPrices(record, count, bought)
		local unit, total = IdleConfig.towerSpinUnitCost(record), 0
		for i = 0, count - 1 do
			total += unit * GROWTH ^ (bought + i)
		end
		return total
	end
	-- Renvoie (résultat, données avant, données après, pièces payées).
	local function spin(count)
		local n = count or 1
		local d0 = dbg:Invoke(player, "Data")
		local record = d0.idle.highestWave
		local bought = d0.idle.towerSpinsBought
		local cost = IdleConfig.towerSpinCost(record, n, bought)
		local result = dbg:Invoke(player, "Call", "spinTower", count)
		local d1 = dbg:Invoke(player, "Data")
		local paid = d0.coins - d1.coins
		check(
			result ~= nil and near(paid, cost),
			`x{n} au record {record}, {NumberFormat.short(bought)} lancers déjà achetés : payé {NumberFormat.price(paid)}, towerSpinCost = {NumberFormat.price(cost)}`
		)
		local attribute = player:GetAttribute("TowerSpinsBought")
		check(
			d1.idle.towerSpinsBought == bought + n and attribute == bought + n and cleanCounter(d1.idle.towerSpinsBought),
			`x{n} : compteur {bought} -> {d1.idle.towerSpinsBought} (+{n}), attribut TowerSpinsBought = {attribute}`
		)
		if not result then
			return nil, d0, d1, paid
		end
		local total, sorted, consistent = 0, true, true
		for i, entry in result.results do
			total += entry.count
			if entry.count <= 0 or entry.count ~= math.floor(entry.count) then
				consistent = false
			end
			if i > 1 and RARITY_INDEX[entry.rarity] > RARITY_INDEX[result.results[i - 1].rarity] then
				sorted = false
			end
			-- Nouvelle = pas encore débloquée avant ; débloquée après ; doublons = exemplaires en plus.
			local before, after = d0.idle.towerDupes[entry.tower] or 0, d1.idle.towerDupes[entry.tower] or 0
			local wasUnlocked = d0.idle.unlockedTowers[entry.tower] == true
			if entry.isNew == wasUnlocked or not d1.idle.unlockedTowers[entry.tower]
				or after - before ~= (if entry.isNew then entry.count - 1 else entry.count) then
				consistent = false
			end
		end
		local gained = inventoryTotal(d1) - inventoryTotal(d0)
		check(total == n and gained == n and result.count == n, `x{n} : {total} résultats, {gained} tours/doublons gagnés (attendu {n})`)
		check(sorted and consistent, `x{n} : résultats triés du plus rare au plus commun, nouveautés et doublons cohérents`)
		local first = result.results[1]
		check(
			first and result.rarity == first.rarity and result.dupes == (d1.idle.towerDupes[result.tower] or 0),
			`x{n} : tour mise en avant = la plus rare ({result.tower}, {result.rarity}, doublons {result.dupes})`
		)
		return result, d0, d1, paid
	end
	local function refusedSpin(count, label)
		local d0 = dbg:Invoke(player, "Data")
		local result = dbg:Invoke(player, "Call", "spinTower", count)
		local d1 = dbg:Invoke(player, "Data")
		check(
			result == nil
				and d1.coins == d0.coins
				and inventoryTotal(d1) == inventoryTotal(d0)
				and d1.idle.towerSpinsBought == d0.idle.towerSpinsBought,
			`lancer refusé : {label} (pièces, tours et compteur de lancers inchangés)`
		)
	end
	local function spinsBoughtNow()
		return dbg:Invoke(player, "Data").idle.towerSpinsBought
	end
	local function rarityCounts(result)
		local counts = { Common = 0, Rare = 0, Epic = 0, Legendary = 0 }
		for _, entry in result.results do
			counts[entry.rarity] += entry.count
		end
		return counts
	end

	-- Record 5 : seuls x1 et x10 (et ce que le réglage débloque dès la vague 5), chances du palier 1.
	dbg:Invoke(player, "Set", "highestWave", 5)
	dbg:Invoke(player, "Set", "unlockedTowers", { MachineGun = true })
	dbg:Invoke(player, "Set", "towerDupes", {})
	setCoins(1e6)
	for _, bulk in IdleConfig.TOWER_SPIN_BULKS do
		if bulk.minWave > 5 then
			refusedSpin(bulk.count, `x{bulk.count} pas débloqué au record 5 (vague {bulk.minWave})`)
		end
	end
	refusedSpin(7, "x7 n'est pas proposé")
	refusedSpin(0, "x0")
	refusedSpin(-10, "x-10")
	refusedSpin(2.5, "x2.5")
	refusedSpin("10", "\"10\" en texte")
	refusedSpin(math.huge, "x infini")
	-- Pas assez de pièces : 1 de moins que le prix, refusé ; le prix exact, accepté (reste 0).
	local cost10 = IdleConfig.towerSpinCost(5, 10, spinsBoughtNow())
	setCoins(cost10 - 1)
	refusedSpin(10, `pas assez de pièces ({cost10 - 1} pour un prix de {cost10})`)
	setCoins(cost10)
	local _, _, afterExact = spin(10)
	check(afterExact.coins == 0, `x10 payé avec exactement le prix : il reste {afterExact.coins} pièce(s)`)
	-- Sans nombre = 1 lancer
	setCoins(1e6)
	spin(nil)

	-- Chaque lancer acheté rend le suivant 0,05 % plus cher : deux x1 d'affilée.
	local price1 = IdleConfig.towerSpinPrice(5, spinsBoughtNow())
	setCoins(price1 * 3) -- petits montants : pièces payées exactes à ~1e-15 près
	local _, _, _, paid1 = spin(1)
	local _, _, _, paid2 = spin(1)
	check(
		paid1 > 0 and near(paid2 / paid1, GROWTH),
		`x1 puis x1 : {string.format("%.6f", paid1)} puis {string.format("%.6f", paid2)} pièces (x{string.format("%.6f", paid2 / paid1)}, attendu x{GROWTH})`
	)
	-- x10 = exactement la somme des 10 prochains prix, et le compteur avance de 10.
	local boughtBefore10 = spinsBoughtNow()
	local expected10 = sumOfPrices(5, 10, boughtBefore10)
	setCoins(expected10 * 2)
	local _, _, after10, paid10 = spin(10)
	check(
		near(paid10, expected10) and after10.idle.towerSpinsBought == boughtBefore10 + 10,
		`x10 après {boughtBefore10} lancers = somme des 10 prochains prix = {string.format("%.6f", expected10)} (payé {string.format("%.6f", paid10)}), compteur {boughtBefore10} -> {after10.idle.towerSpinsBought}`
	)
	-- Compteur abîmé (NaN, négatif, texte, à virgule) : compté comme un nombre propre, jamais NaN ni négatif.
	local savedCounter = spinsBoughtNow()
	for _, case in { { "NaN", 0 / 0 }, { "négatif", -50 }, { "en texte", "abc" }, { "à virgule", 12.5 } } do
		dbg:Invoke(player, "Set", "towerSpinsBought", case[2])
		local counted = IdleConfig.cleanSpinsBought(case[2])
		setCoins(1e6)
		local d0 = dbg:Invoke(player, "Data")
		local result = dbg:Invoke(player, "Call", "spinTower", 1)
		local d1 = dbg:Invoke(player, "Data")
		check(
			result ~= nil
				and near(d0.coins - d1.coins, IdleConfig.towerSpinPrice(5, counted))
				and d1.idle.towerSpinsBought == counted + 1
				and cleanCounter(d1.idle.towerSpinsBought)
				and player:GetAttribute("TowerSpinsBought") == counted + 1,
			`compteur abîmé ({case[1]}) : compté comme {counted}, puis {d1.idle.towerSpinsBought} après x1`
		)
	end
	dbg:Invoke(player, "Set", "towerSpinsBought", savedCounter)
	-- Palier 1 (record 5) : 0 % d'Épiques et de Légendaires, même en 60 lancers.
	setCoins(1e6)
	local epic, legendary = 0, 0
	for _ = 1, 6 do
		local result = spin(10)
		if result then
			local counts = rarityCounts(result)
			epic += counts.Epic
			legendary += counts.Legendary
		end
	end
	check(epic == 0 and legendary == 0, `record 5 : aucune Épique ni Légendaire (Épiques {epic}, Légendaires {legendary})`)

	-- Record haut, vague en cours basse : les chances sont celles du RECORD (avant, c'était la vague réussie).
	local topRecord = 150
	for _, tier in IdleConfig.TOWER_SPIN_TIERS do
		topRecord = math.max(topRecord, tier.minWave)
	end
	for _, bulk in IdleConfig.TOWER_SPIN_BULKS do
		topRecord = math.max(topRecord, bulk.minWave)
		if bulk.minWave > 1 then
			-- Juste sous le record demandé : refusé, même avec assez de pièces.
			dbg:Invoke(player, "Set", "highestWave", bulk.minWave - 1)
			setCoins(IdleConfig.towerSpinCost(bulk.minWave, bulk.count, spinsBoughtNow()) * 10)
			refusedSpin(bulk.count, `x{bulk.count} au record {bulk.minWave - 1} (il faut la vague {bulk.minWave})`)
		end
	end

	-- x10 000 (joueurs avancés) : proposé dès son record, prix = somme des 10 000 prochains prix.
	local bulk10k = nil
	for _, bulk in IdleConfig.TOWER_SPIN_BULKS do
		if bulk.count == 10000 then
			bulk10k = bulk
		end
	end
	check(bulk10k ~= nil, `lot x10000 proposé par l'autel (record {bulk10k and bulk10k.minWave})`)
	if bulk10k then
		dbg:Invoke(player, "Set", "highestWave", bulk10k.minWave)
		local bought = spinsBoughtNow()
		local expected = sumOfPrices(bulk10k.minWave, 10000, bought)
		local formula = IdleConfig.towerSpinCost(bulk10k.minWave, 10000, bought)
		check(
			IdleConfig.towerSpinBulkAvailable(bulk10k.minWave, 10000) and formula < math.huge and near(formula, expected),
			`x10000 au record {bulk10k.minWave} après {bought} lancers : towerSpinCost {NumberFormat.price(formula)} = somme des prix {NumberFormat.price(expected)}`
		)
		setCoins(expected * 2)
		local result, _, after, paid = spin(10000)
		check(
			result ~= nil and near(paid, expected) and after.idle.towerSpinsBought == bought + 10000,
			`x10000 acheté au record {bulk10k.minWave} : payé {NumberFormat.price(paid)}, compteur {bought} -> {after.idle.towerSpinsBought}`
		)
	end

	dbg:Invoke(player, "Set", "highestWave", topRecord)
	dbg:Invoke(player, "Set", "wave", 1)
	check(IdleConfig.towerSpinTier(topRecord) == #IdleConfig.TOWER_SPIN_TIERS, `record {topRecord} : meilleur palier de chances`)
	for _, bulk in IdleConfig.TOWER_SPIN_BULKS do
		local cost = IdleConfig.towerSpinCost(topRecord, bulk.count, spinsBoughtNow())
		if cost >= math.huge then
			-- Prix trop grand pour être compté (x1 000 000 : ~2,5e220 prix d'un lancer) : « MAX », refusé
			-- sans rien dépenser, même avec énormément de pièces.
			check(NumberFormat.price(cost) == "MAX", `x{NumberFormat.short(bulk.count)} au record {topRecord} : prix affiché « {NumberFormat.price(cost)} »`)
			setCoins(1e300)
			refusedSpin(bulk.count, `x{NumberFormat.short(bulk.count)} au record {topRecord} : prix MAX`)
			continue
		end
		setCoins(cost * 3)
		local result = spin(bulk.count)
		if result and bulk.count >= 1000 then
			local counts = rarityCounts(result)
			check(
				counts.Epic > 0 and counts.Legendary > 0,
				`x{bulk.count} au record {topRecord} (vague en cours 1) : Épiques {NumberFormat.short(counts.Epic)}, Légendaires {NumberFormat.short(counts.Legendary)}`
			)
		end
		if result and bulk.count >= 10000 then
			-- Tirage statistique des gros lots : chaque rareté à 5 écarts-types près des chances affichées
			-- (~2 points de % sur 10 000 lancers, ~0,2 point sur un million).
			local odds = IdleConfig.TOWER_SPIN_TIERS[IdleConfig.towerSpinTier(topRecord)].odds
			local totalOdds = 0
			for _, rarity in IdleConfig.RARITY_ORDER do
				totalOdds += odds[rarity] or 0
			end
			local counts, parts, close = rarityCounts(result), {}, true
			for _, rarity in IdleConfig.RARITY_ORDER do
				local chance = (odds[rarity] or 0) / totalOdds
				local share = counts[rarity] / bulk.count
				close = close and math.abs(share - chance) <= 5 * math.sqrt(chance * (1 - chance) / bulk.count) + 1e-9
				table.insert(parts, `{rarity} {string.format("%.2f", share * 100)} % (attendu {odds[rarity] or 0})`)
			end
			check(close, `x{NumberFormat.short(bulk.count)} : raretés conformes aux chances — {table.concat(parts, ", ")}`)
		end
	end

	-- Prix qui dépasserait les plus grands nombres (2 millions de lancers déjà achetés) : « MAX », refusé
	-- sans rien dépenser, compteur inchangé.
	local savedBought = spinsBoughtNow()
	dbg:Invoke(player, "Set", "towerSpinsBought", 2e6)
	check(IdleConfig.towerSpinCost(topRecord, 1, 2e6) == math.huge, "x1 après 2 millions de lancers : prix trop grand (math.huge)")
	setCoins(1e300)
	refusedSpin(1, "x1 après 2 millions de lancers (prix MAX)")
	local shownBought = player:GetAttribute("TowerSpinsBought")
	check(
		shownBought == 2e6 and NumberFormat.price(IdleConfig.towerSpinCost(topRecord, 1, shownBought)) == "MAX",
		`l'autel du client affiche « MAX » (attribut TowerSpinsBought = {shownBought})`
	)
	dbg:Invoke(player, "Set", "towerSpinsBought", savedBought)
	dbg:Invoke(player, "Call", "publishInventory") -- l'attribut du client suit le compteur remis en place

	-- Données toujours sauvegardables : doublons entiers et finis, compteur de lancers propre.
	d = dbg:Invoke(player, "Data")
	local clean = true
	for _, n in d.idle.towerDupes do
		if n ~= n or n == math.huge or n ~= math.floor(n) or n < 0 then
			clean = false
		end
	end
	check(clean and d.coins == d.coins and d.coins < math.huge, "doublons entiers et finis, pièces finies")
	check(
		cleanCounter(d.idle.towerSpinsBought) and player:GetAttribute("TowerSpinsBought") == d.idle.towerSpinsBought,
		`compteur de lancers entier, fini, jamais négatif ni NaN ({d.idle.towerSpinsBought}), publié au client`
	)

	----------------------------------------------------------------------
	-- Gains d'absence : hors ligne (revenu réduit, plafond du jour UTC) et match ranked (revenu normal)
	----------------------------------------------------------------------
	task.wait(2) -- le scénario client a fini ses achats à l'autel
	local Config = require(ReplicatedStorage.Shared.Config)
	local function finite(x)
		return typeof(x) == "number" and x == x and x < math.huge and x > -math.huge
	end
	local function coinsNow()
		return dbg:Invoke(player, "Data").coins
	end
	-- Fausse une absence (champs de data.idle), verse les gains au « retour » à l'heure `now`, vérifie le
	-- versement et renvoie (résumé, données après).
	local function absence(fields, now, label, silent)
		local before = coinsNow()
		local result = dbg:Invoke(player, "Absence", now, silent, fields)
		local after = dbg:Invoke(player, "Data")
		local ok = result ~= nil and finite(result.amount) and finite(result.seconds) and finite(after.coins)
		check(
			ok and near(after.coins - before, result.amount) and typeof(result.kind) == "string" and typeof(result.capped) == "boolean",
			`{label} : +{ok and NumberFormat.short(result.amount) or "?"} versé (pièces +{NumberFormat.short(after.coins - before)})`
		)
		return result or { amount = -1, seconds = -1, offlineAmount = -1, matchAmount = -1, matchSeconds = -1, offlineSeconds = -1 }, after
	end

	local savedBest = dbg:Invoke(player, "Data").idle.bestWave
	local absenceWave = 40
	dbg:Invoke(player, "Set", "bestWave", absenceWave)
	setCoins(0) -- montants exacts (les grands nombres de l'autel perdraient les petites unités)
	local bonus = dbg:Invoke(player, "Data").idle.coinBonus
	local rate = IdleConfig.normalCoinRate(absenceWave, bonus)
	local cap = IdleConfig.offlineDailyCap(absenceWave, bonus)
	local twoHours = math.floor(rate * IdleConfig.OFFLINE_RATE * 7200)
	say(`gains d'absence à la vague {absenceWave}, bonus {bonus} % : revenu normal {NumberFormat.short(rate)}/s, 2 h hors ligne {NumberFormat.short(twoHours)}, plafond du jour {NumberFormat.short(cap)}`)
	check(finite(rate) and rate > 0 and finite(cap) and twoHours < cap, "réglages : 2 h hors ligne restent sous le plafond du jour à la vague 40")
	local dayStart = os.time() // 86400 * 86400 -- 00:00 UTC aujourd'hui
	local noon = dayStart + 12 * 3600

	-- 1. Absence de 2 h : revenu normal x OFFLINE_RATE x 7 200 s (le seul message envoyé au client pendant les tests).
	local r1, d1 = absence({ lastSeenAt = noon - 7200, matchDepartureAt = 0, offlineDay = 0, offlineGainedToday = 0 }, noon, "absence de 2 h", false)
	check(
		r1.kind == "Offline" and not r1.capped and r1.offlineSeconds == 7200 and r1.seconds == 7200
			and near(r1.amount, twoHours) and math.abs(r1.amount - rate * IdleConfig.OFFLINE_RATE * 7200) <= 1,
		`2 h hors ligne = {NumberFormat.short(rate)}/s x {IdleConfig.OFFLINE_RATE} x 7 200 s = {NumberFormat.short(twoHours)} (obtenu {NumberFormat.short(r1.amount)}, {r1.kind})`
	)
	check(
		near(d1.idle.offlineGainedToday, r1.amount) and d1.idle.lastSeenAt == noon and d1.idle.matchDepartureAt == 0,
		`compteur du jour = {NumberFormat.short(d1.idle.offlineGainedToday)}, heure de visite et départ consommés`
	)
	-- 2. Deuxième absence de 2 h le même jour : on ne dépasse pas le plafond.
	local r2, d2 = absence({ lastSeenAt = noon + 3 * 3600 - 7200 }, noon + 3 * 3600, "2e absence de 2 h le même jour", true)
	check(
		r2.capped and r2.amount < r1.amount and near(r1.amount + r2.amount, cap) and near(d2.idle.offlineGainedToday, cap),
		`plafond du jour : {NumberFormat.short(r1.amount)} + {NumberFormat.short(r2.amount)} = {NumberFormat.short(r1.amount + r2.amount)} (plafond {NumberFormat.short(cap)})`
	)
	-- 3. Plafond atteint : plus rien le même jour.
	local r3 = absence({ lastSeenAt = noon + 6 * 3600 - 3600 }, noon + 6 * 3600, "3e absence le même jour", true)
	check(r3.amount == 0 and r3.capped == true, `plafond atteint : rien de plus le même jour (obtenu {r3.amount})`)
	-- 4. Le lendemain (compteur remis à 0 à 00:00 UTC) : de nouveau 2 h complètes.
	local tomorrow = noon + 86400
	local r4, d4 = absence({ lastSeenAt = tomorrow - 7200 }, tomorrow, "absence de 2 h le lendemain", true)
	check(
		not r4.capped and near(r4.amount, twoHours) and near(d4.idle.offlineGainedToday, twoHours) and d4.idle.offlineDay ~= d2.idle.offlineDay,
		`nouveau jour : compteur remis à zéro (jour {d2.idle.offlineDay} -> {d4.idle.offlineDay}, +{NumberFormat.short(r4.amount)})`
	)
	-- 5. Retour d'un match ranked de 10 min, plafond du jour déjà atteint : le match paie au revenu NORMAL,
	--    hors plafond ; seules les 30 s après le match comptent comme hors ligne (et le plafond les bloque).
	local back = tomorrow + 3600
	local r5, d5 = absence({ offlineGainedToday = cap, lastSeenAt = back - 30, matchDepartureAt = back - 30 - 600 }, back, "retour d'un match de 10 min", true)
	check(
		r5.kind == "Match" and r5.matchSeconds == 600 and near(r5.matchAmount, math.floor(rate * 600)),
		`match ranked : revenu normal {NumberFormat.short(rate)}/s x 600 s = {NumberFormat.short(math.floor(rate * 600))} (obtenu {NumberFormat.short(r5.matchAmount)}, {r5.kind})`
	)
	check(
		r5.offlineAmount == 0 and r5.capped and near(r5.amount, r5.matchAmount) and near(d5.idle.offlineGainedToday, cap) and d5.idle.matchDepartureAt == 0,
		"match : payé même plafond atteint, pas compté dans le plafond du jour, départ consommé"
	)
	-- 6. Match impossible (5 h) : au plus la durée max d'un match + la marge.
	local maxMatch = Config.Match.MAX_DURATION + IdleConfig.ABSENCE_MATCH_EXTRA_SECONDS
	local back2 = back + 3600
	local r6 = absence({ lastSeenAt = back2 - 10, matchDepartureAt = back2 - 10 - 5 * 3600 }, back2, "match de 5 h", true)
	check(r6.matchSeconds == maxMatch and near(r6.matchAmount, math.floor(rate * maxMatch)), `match de 5 h : {r6.matchSeconds} s comptées (max {maxMatch})`)
	-- 7. Absence de 3 jours : 24 h comptées au plus (puis le plafond du jour).
	local back3 = back2 + 3 * 86400
	local r7 = absence({ lastSeenAt = back3 - 3 * 86400, matchDepartureAt = 0 }, back3, "absence de 3 jours", true)
	check(r7.offlineSeconds == IdleConfig.OFFLINE_MAX_SECONDS and r7.capped and near(r7.amount, cap), `3 jours d'absence : {r7.offlineSeconds} s comptées, plafonné à {NumberFormat.short(r7.amount)}`)
	-- 8. Heures abîmées : rien du tout.
	local back4 = back3 + 86400
	local garbage = {
		{ "en texte", "abc" },
		{ "négative", -3600 },
		{ "zéro (jamais vu)", 0 },
		{ "dans le futur", back4 + 1e6 },
		{ "NaN", 0 / 0 },
		{ "infinie", math.huge },
		{ "table", {} },
	}
	for _, case in garbage do
		local r = absence({ lastSeenAt = case[2], matchDepartureAt = back4 - 600 }, back4, `dernière visite {case[1]}`, true)
		check(r.amount == 0 and r.seconds == 0, `dernière visite {case[1]} : aucun gain (obtenu {r.amount})`)
	end
	dbg:Invoke(player, "Set", "lastSeenAt", nil)
	local rNil = absence({ matchDepartureAt = back4 - 600 }, back4, "dernière visite absente", true)
	check(rNil.amount == 0 and rNil.seconds == 0, `dernière visite absente : aucun gain (obtenu {rNil.amount})`)
	for _, case in { { "en texte", "x" }, { "dans le futur", back4 + 1e6 }, { "après la dernière visite", back4 - 30 } } do
		local r = absence({ lastSeenAt = back4 - 60, matchDepartureAt = case[2] }, back4, `départ en match {case[1]}`, true)
		check(r.kind == "Offline" and r.matchSeconds == 0 and r.offlineSeconds == 60, `départ en match {case[1]} : pas de gains de match ({r.matchSeconds} s)`)
	end
	-- 9. Tout reste fini, même à une vague et un bonus absurdes.
	dbg:Invoke(player, "Set", "bestWave", 1e9)
	dbg:Invoke(player, "Set", "coinBonus", 1e6)
	local r9, d9 = absence({ lastSeenAt = back4, offlineDay = 0 }, back4 + 86400, "absence de 24 h à la vague 1e9", true)
	check(
		finite(r9.amount) and r9.amount > 0 and finite(d9.coins) and finite(d9.idle.offlineGainedToday),
		`vague 1e9, bonus 1e6 % : montants finis (+{NumberFormat.short(r9.amount)}, pièces {NumberFormat.short(d9.coins)})`
	)
	check(
		finite(IdleConfig.normalCoinRate(0 / 0, "x")) and finite(IdleConfig.offlineDailyCap(math.huge, math.huge)) and finite(IdleConfig.runCoins(-5, -5)),
		"formules finies avec des valeurs abîmées"
	)
	-- Remise en état : vraie heure de visite, compteur vide, vague et bonus d'avant.
	dbg:Invoke(player, "Set", "coinBonus", bonus)
	dbg:Invoke(player, "Set", "bestWave", savedBest)
	dbg:Invoke(player, "Absence", os.time(), true, { lastSeenAt = os.time(), offlineDay = 0, offlineGainedToday = 0, matchDepartureAt = 0 })
	setCoins(0)

	----------------------------------------------------------------------
	-- Pass Ramassage auto : les pièces de la parcelle sont ramassées sans marcher
	----------------------------------------------------------------------
	local dropId, dropDistance = dbg:Invoke(player, "Drop", 1234)
	task.wait(1.5)
	check(
		dropDistance > IdleConfig.PICKUP_RADIUS + 10 and dbg:Invoke(player, "HasDrop", dropId) == true,
		`sans pass : pile à {math.floor(dropDistance)} studs du personnage toujours au sol`
	)
	dbg:Invoke(player, "Pass", "AutoCollect", true)
	check(player:GetAttribute("PassAutoCollect") == true, "pass Ramassage auto donné (test Studio) : attribut PassAutoCollect")
	task.wait(1.5)
	local collected = coinsNow()
	check(dbg:Invoke(player, "HasDrop", dropId) == false and collected >= 1234, `avec le pass : pile ramassée sans marcher (pièces {NumberFormat.short(collected)})`)
	local dropId2 = dbg:Invoke(player, "Drop", 10)
	check(dbg:Invoke(player, "HasDrop", dropId2) == true, "nouvelle pile visible un instant avant d'être ramassée")
	task.wait(1.5)
	check(dbg:Invoke(player, "HasDrop", dropId2) == false and coinsNow() >= collected + 10, "avec le pass : nouvelle pile ramassée toute seule")
	dbg:Invoke(player, "Pass", "AutoCollect", false)
	check(player:GetAttribute("PassAutoCollect") == false, "pass Ramassage auto retiré")

	----------------------------------------------------------------------
	-- Pass Vitesse x2 : toute la parcelle va deux fois plus vite
	----------------------------------------------------------------------
	check(dbg:Invoke(player, "ToggleSpeed") == nil and plotFolder:GetAttribute("SimSpeed") == 1, "bouton x2 refusé sans le pass (SimSpeed = 1)")
	-- Vague 303 : Charge de cavalerie (un cavalier toutes les 0,3 s), PV astronomiques : personne ne meurt.
	local function measure()
		dbg:Invoke(player, "StartWave", 303)
		local p0 = dbg:Invoke(player, "Progress")
		local t0 = os.clock()
		task.wait(3)
		local p1 = dbg:Invoke(player, "Progress")
		local real = os.clock() - t0
		return { rate = (p1.clock - p0.clock) / real, spawned = p1.spawned, lead = p1.lead, speed = p1.simSpeed }
	end
	local normal = measure()
	dbg:Invoke(player, "Pass", "SpeedX2", true)
	check(
		player:GetAttribute("PassSpeedX2") == true and player:GetAttribute("SpeedX2Enabled") == true and plotFolder:GetAttribute("SimSpeed") == 2,
		`pass Vitesse x2 donné : allumé par défaut (SimSpeed = {plotFolder:GetAttribute("SimSpeed")})`
	)
	local fast = measure()
	say(`x1 : horloge x{string.format("%.2f", normal.rate)}, {normal.spawned} apparus, tête à {string.format("%.1f", normal.lead)} studs • x2 : horloge x{string.format("%.2f", fast.rate)}, {fast.spawned} apparus, tête à {string.format("%.1f", fast.lead)} studs`)
	check(math.abs(normal.rate - 1) < 0.15 and math.abs(fast.rate - 2) < 0.3, `horloge de la parcelle : x{string.format("%.2f", normal.rate)} sans pass, x{string.format("%.2f", fast.rate)} avec`)
	local spawnRatio = fast.spawned / math.max(1, normal.spawned)
	check(spawnRatio > 1.6 and spawnRatio < 2.4, `apparitions en 3 s : {normal.spawned} -> {fast.spawned} (x{string.format("%.2f", spawnRatio)})`)
	local leadRatio = fast.lead / math.max(0.001, normal.lead)
	check(leadRatio > 1.6 and leadRatio < 2.4, `ennemi de tête après 3 s : {string.format("%.1f", normal.lead)} -> {string.format("%.1f", fast.lead)} studs (x{string.format("%.2f", leadRatio)})`)
	-- Entracte aussi deux fois plus court (compte à rebours NextWaveAt en temps réel).
	dbg:Invoke(player, "Leak")
	task.wait(0.2)
	local waitLeft = (plotFolder:GetAttribute("NextWaveAt") or 0) - workspace:GetServerTimeNow()
	check(
		plotFolder:GetAttribute("State") == "Intermission" and waitLeft > 0 and waitLeft <= IdleConfig.WAVE_FAIL_DELAY / 2 + 0.1,
		`x2 : entracte de {string.format("%.1f", waitLeft)} s (au lieu de {IdleConfig.WAVE_FAIL_DELAY} s)`
	)
	-- Bouton x2 : éteint puis rallumé, choix gardé dans les données.
	local off = dbg:Invoke(player, "ToggleSpeed")
	check(
		off == false and player:GetAttribute("SpeedX2Enabled") == false and plotFolder:GetAttribute("SimSpeed") == 1 and dbg:Invoke(player, "Data").idle.speedX2 == false,
		"bouton x2 : éteint -> vitesse normale (SimSpeed = 1), choix sauvegardé"
	)
	local on = dbg:Invoke(player, "ToggleSpeed")
	check(
		on == true and player:GetAttribute("SpeedX2Enabled") == true and plotFolder:GetAttribute("SimSpeed") == 2 and dbg:Invoke(player, "Data").idle.speedX2 == true,
		"bouton x2 : rallumé -> SimSpeed = 2"
	)
	dbg:Invoke(player, "Pass", "SpeedX2", false)
	check(
		player:GetAttribute("PassSpeedX2") == false and player:GetAttribute("SpeedX2Enabled") == false and plotFolder:GetAttribute("SimSpeed") == 1,
		"pass Vitesse x2 retiré : vitesse normale"
	)

	----------------------------------------------------------------------
	-- Autel : le compteur des lancers achetés n'est jamais remis à zéro, même par une renaissance
	-- (ici, à la fin : le scénario client a fini depuis longtemps, sa capture de l'autel reste propre).
	----------------------------------------------------------------------
	d = dbg:Invoke(player, "Data")
	local spinRecord = d.idle.highestWave
	local priceBefore = IdleConfig.towerSpinPrice(spinRecord, d.idle.towerSpinsBought)
	dbg:Invoke(player, "Set", "bestWave", IdleConfig.REBIRTH_MIN_WAVE)
	dbg:Invoke(player, "Call", "rebirth")
	local reborn = dbg:Invoke(player, "Data")
	check(
		reborn.idle.rebirths == d.idle.rebirths + 1
			and d.idle.towerSpinsBought > 0
			and reborn.idle.towerSpinsBought == d.idle.towerSpinsBought
			and player:GetAttribute("TowerSpinsBought") == d.idle.towerSpinsBought
			and IdleConfig.towerSpinPrice(spinRecord, reborn.idle.towerSpinsBought) == priceBefore,
		`renaissance : compteur de l'autel gardé ({NumberFormat.short(d.idle.towerSpinsBought)} -> {NumberFormat.short(reborn.idle.towerSpinsBought)} lancers), prix d'un lancer inchangé ({NumberFormat.price(priceBefore)})`
	)
	-- Remise en état : bonus et renaissances d'avant.
	dbg:Invoke(player, "Set", "coinBonus", d.idle.coinBonus)
	dbg:Invoke(player, "Set", "rebirths", d.idle.rebirths)

	----------------------------------------------------------------------
	-- Combat : projectiles (visée anticipée, dégâts à l'impact), flèches enflammées, petite zone du Mage des
	-- tempêtes, rayon continu du Sorcier des arcanes. Dans une « arène » (PlotGame:debugArena) : vague vidée,
	-- ennemis posés à la main (immobiles ou non), seules les tours choisies tirent d'elles-mêmes.
	-- Tours posées plus haut : 1 Archer (rune x10 dégâts), 3 Catapulte, 4 Mage des tempêtes, 6 Sorcier,
	-- 8 Trébuchet.
	----------------------------------------------------------------------
	local IdleTowers = require(ReplicatedStorage.Shared.IdleTowers)
	local function call(method, ...)
		return dbg:Invoke(player, "Call", method, ...)
	end
	local function clockNow()
		return call("debugEnemy", -1).clock
	end
	-- Attend que l'horloge de la simulation atteigne `target` (au plus `timeout` secondes réelles).
	local function waitClock(target, timeout)
		local started = os.clock()
		while clockNow() < target and os.clock() - started < (timeout or 20) do
			task.wait(0.03)
		end
	end
	-- Égalité à `tolerance` près, en proportion (0.01 = 1 %).
	local function close(a, b, tolerance)
		return typeof(a) == "number" and typeof(b) == "number" and math.abs(a - b) <= tolerance * math.max(math.abs(b), 1e-9)
	end
	local function flat(a, b)
		return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
	end
	local function fmt(x)
		return string.format("%.2f", x or -1)
	end
	-- Distance sur le chemin (entre from et to) du point le plus proche d'un emplacement.
	local function pathNear(spotIndex, from, to)
		local spot = PlotLayout.SPOTS[spotIndex]
		local best, bestGap = from, math.huge
		for distance = from, to, 0.5 do
			local gap = flat(PlotLayout.pointAt(distance), spot)
			if gap < bestGap then
				best, bestGap = distance, gap
			end
		end
		return best
	end
	-- Rangée z = -4 (de x = 22 à -22) : distances 198 à 242 ; rangée z = -22 (de x = -22 à 22) : 260 à 304.
	local archerDistance = pathNear(1, 198, 242) -- devant l'Archer (emplacement 1)
	local beamDistance = pathNear(6, 198, 242) -- devant le Sorcier (emplacement 6)
	local catapultDistance = pathNear(3, 260, 304) -- devant la Catapulte (emplacement 3)
	local stormDistance = pathNear(4, 260, 304) -- devant le Mage des tempêtes (emplacement 4)

	-- Réglages demandés : Archer plus loin, Sorcier plus court, Mage des tempêtes en toute petite zone.
	local defs = IdleTowers.Defs
	check(defs.MachineGun.range > 15 and defs.Laser.range < 18, `portées : Archer {defs.MachineGun.range} (15 avant), Sorcier {defs.Laser.range} (18 avant)`)
	check(
		defs.Tesla.kind == "Splash" and defs.Tesla.splash < defs.Bomb.splash and defs.Tesla.slow ~= nil,
		`Mage des tempêtes : petite zone de rayon {defs.Tesla.splash} (Catapulte {defs.Bomb.splash}) qui ralentit`
	)
	check(
		defs.Laser.kind == "Beam" and defs.Laser.beamRampMax > 1 and defs.Laser.beamRampRate > 0,
		`Sorcier : rayon continu x1 -> x{defs.Laser.beamRampMax} en {fmt(IdleTowers.beamRampSeconds(defs.Laser))} s`
	)

	-- Projectile tiré sur un ennemi qui marche tout droit : PV inchangés au départ, dégâts à l'arrivée,
	-- au bout du temps de vol (/ SimSpeed en temps réel), et point visé ~ position de l'ennemi à l'impact.
	local function projectileCheck(spot, enemyName, distance, label)
		call("debugArena", {})
		local speed = plotFolder:GetAttribute("SimSpeed") or 1
		local id = call("debugSpawn", enemyName, distance, 1e9, false)
		local shot = call("debugFire", spot)
		local right = call("debugEnemy", id)
		check(
			shot ~= nil and shot.fired and shot.targetId == id and shot.flight > 0 and right.health == 1e9,
			`{label} : tir parti, PV de la cible inchangés juste après le tir (vol prévu {fmt(shot and shot.flight)} s)`
		)
		if not (shot and shot.fired) then
			return
		end
		local started, landedAfter = os.clock(), nil
		while os.clock() - started < 5 do
			local now = call("debugEnemy", id)
			if not now.alive or now.health < 1e9 then
				landedAfter = os.clock() - started
				break
			end
			task.wait(0.02)
		end
		local after = call("debugEnemy", id)
		local expected = shot.flight / speed
		check(
			landedAfter ~= nil and after.alive and close(1e9 - after.health, shot.damage, 1e-4) and math.abs(landedAfter - expected) <= 0.15,
			`{label} : {NumberFormat.short(shot.damage)} dégâts à l'impact, après {fmt(landedAfter)} s réelles (vol {fmt(shot.flight)} s / SimSpeed {speed} = {fmt(expected)} s)`
		)
		local impact = call("debugLastImpact")
		local miss = if impact then flat(impact.aim, impact.targetPosition) else math.huge
		check(
			impact ~= nil and impact.targetId == id and impact.targetAlive and miss <= 2,
			`{label} : point visé à {fmt(miss)} studs de la cible au moment de l'impact (2 au plus)`
		)
	end
	projectileCheck(3, "Normal", catapultDistance - 8, "Catapulte")
	projectileCheck(8, "Fast", 262, "Trébuchet (cavalier)")

	-- Flèche en vol qui suffit à tuer : l'ennemi est « condamné », l'Archer ne tire pas une 2e fois dessus.
	call("debugArena", {})
	local archer = call("debugTower", 1)
	local weak = call("debugSpawn", "Normal", archerDistance, archer.damage * 0.5, true)
	local firstArrow = call("debugFire", 1)
	local secondArrow = call("debugFire", 1)
	check(
		firstArrow.fired and not secondArrow.fired,
		`flèche mortelle en vol : pas de 2e flèche sur la même cible (1er tir {firstArrow.fired}, 2e {secondArrow.fired})`
	)
	waitClock(firstArrow.clock + firstArrow.flight + 0.1)
	check(not call("debugEnemy", weak).alive, "l'ennemi condamné meurt à l'arrivée de la flèche")

	-- Flèches enflammées : la flèche, puis 4 coups de feu de 0,5 s (2 s) = fireDamageRatio x dégâts par seconde.
	-- L'ennemi posé à 4 studs de l'impact (hors de la zone) ne brûle pas.
	call("debugArena", {})
	local fireDef = defs.MachineGun
	local burning = call("debugSpawn", "Tank", archerDistance, 1e9, true)
	local aside = call("debugSpawn", "Tank", archerDistance - 4, 1e9, true)
	local arrow = call("debugFire", 1)
	check(arrow.fired and arrow.targetId == burning, "Archer : flèche tirée sur l'ennemi de tête")
	waitClock(arrow.clock + arrow.flight + 0.05)
	local fires = call("debugFires")
	local patch = fires.patches[1]
	check(
		fires.count == 1 and patch ~= nil and close(patch.dps, archer.damage * fireDef.fireDamageRatio, 1e-6) and patch.radius == fireDef.fireRadius,
		`flèche enflammée : 1 zone de feu de rayon {patch and patch.radius}, {NumberFormat.short(patch and patch.dps or 0)} dégâts/s = {fireDef.fireDamageRatio} x {NumberFormat.short(archer.damage)}`
	)
	waitClock(arrow.clock + arrow.flight + fireDef.fireDuration + 0.3)
	local burnt = call("debugEnemy", burning)
	local fireLoss = (1e9 - burnt.health) - archer.damage
	local burnPerSecond = fireLoss / fireDef.fireDuration
	check(
		close(burnPerSecond, archer.damage * fireDef.fireDamageRatio, 0.01),
		`ennemi dans le feu : {NumberFormat.short(burnPerSecond)} dégâts/s pendant {fireDef.fireDuration} s (attendu {NumberFormat.short(archer.damage * fireDef.fireDamageRatio)}), en plus de la flèche`
	)
	check(call("debugEnemy", aside).health == 1e9, "ennemi à 4 studs de l'impact : pas brûlé")
	check(call("debugFires").count == 0, `zone de feu éteinte après {fireDef.fireDuration} s`)

	-- Mage des tempêtes : 2 ennemis collés (1 stud) foudroyés ET ralentis, un 3e à 6 studs ni l'un ni l'autre.
	call("debugArena", {})
	local storm = call("debugTower", 4)
	local stuckA = call("debugSpawn", "Tank", stormDistance, 1e9, true)
	local stuckB = call("debugSpawn", "Tank", stormDistance + 1, 1e9, true) -- le plus avancé : la cible
	local alone = call("debugSpawn", "Tank", stormDistance - 6, 1e9, true)
	local zap = call("debugFire", 4)
	local a, b, c = call("debugEnemy", stuckA), call("debugEnemy", stuckB), call("debugEnemy", alone)
	check(
		zap.fired and zap.flight == 0 and close(1e9 - a.health, storm.damage, 1e-4) and close(1e9 - b.health, storm.damage, 1e-4),
		`Mage des tempêtes : 2 ennemis collés foudroyés tout de suite ({NumberFormat.short(storm.damage)} dégâts chacun)`
	)
	check(
		a.slowed and b.slowed and a.slowFactor == defs.Tesla.slow and b.slowFactor == defs.Tesla.slow,
		`Mage des tempêtes : les 2 ennemis collés ralentis de {math.floor(defs.Tesla.slow * 100 + 0.5)} %`
	)
	check(c.health == 1e9 and not c.slowed, "Mage des tempêtes : ennemi à 6 studs ni blessé ni ralenti")

	-- Sorcier des arcanes (emplacement 6) : rayon continu dont les dégâts montent sur la même cible.
	local beamModel = nil
	for _, model in plotFolder.Towers:GetChildren() do
		if model:GetAttribute("SpotIndex") == 6 then
			beamModel = model
		end
	end
	-- Dégâts du rayon attendus entre deux relevés de debugTower (même cible), avec la formule de IdleTowers.
	local function beamExpected(s0, s1)
		local stats = { damage = s1.damage, beamRampRate = s1.beamRampRate, beamRampMax = s1.beamRampMax }
		return IdleTowers.beamDamage(stats, s1.beamTime) - IdleTowers.beamDamage(stats, s0.beamTime)
	end
	local function waitBeamOn(id)
		local started = os.clock()
		local s = call("debugTower", 6)
		while s.beamTargetId ~= id and os.clock() - started < 5 do
			task.wait(0.03)
			s = call("debugTower", 6)
		end
		return s
	end
	call("debugArena", { 6 })
	local first = call("debugSpawn", "Giant", beamDistance, 1e15, true)
	local s0 = waitBeamOn(first)
	check(s0.beamTargetId == first and s0.beamTime < 0.5, `Sorcier : rayon accroché à la cible (depuis {fmt(s0.beamTime)} s)`)
	task.wait(1)
	local s1 = call("debugTower", 6)
	local firstSecond = (s0.targetHealth - s1.targetHealth) / (s1.beamTime - s0.beamTime)
	check(
		s1.beamTargetId == first and close(s0.targetHealth - s1.targetHealth, beamExpected(s0, s1), 0.02),
		`Sorcier : dégâts de la 1re seconde = formule (dégâts x montée) : {NumberFormat.short(s0.targetHealth - s1.targetHealth)} / {NumberFormat.short(beamExpected(s0, s1))}`
	)
	check(
		beamModel ~= nil and beamModel:GetAttribute("BeamTarget") == first and (beamModel:GetAttribute("BeamRamp") or 0) >= 1,
		`Sorcier : rayon publié aux clients (BeamTarget = {beamModel and beamModel:GetAttribute("BeamTarget")}, BeamRamp = {beamModel and beamModel:GetAttribute("BeamRamp")})`
	)
	waitClock(s0.clock + (3 - s0.beamTime))
	local s2 = call("debugTower", 6)
	task.wait(1)
	local s3 = call("debugTower", 6)
	local laterSecond = (s2.targetHealth - s3.targetHealth) / (s3.beamTime - s2.beamTime)
	check(
		s3.beamTargetId == first and laterSecond > firstSecond * 1.5,
		`Sorcier : après 3 s sur la même cible, {NumberFormat.short(laterSecond)} dégâts/s contre {NumberFormat.short(firstSecond)} la 1re seconde (montée x{fmt(s3.beamRamp)})`
	)
	-- Un ennemi BEAUCOUP plus résistant arrive à portée : le rayon garde sa cible (sa montée continue).
	local stronger = call("debugSpawn", "Boss", beamDistance - 2, 1e16, true)
	task.wait(0.5)
	local s4 = call("debugTower", 6)
	check(
		s4.beamTargetId == first and s4.beamTime > s3.beamTime and call("debugEnemy", stronger).health == 1e16,
		`Sorcier : garde sa cible quand un ennemi plus résistant arrive (cible {s4.beamTargetId}, {fmt(s4.beamTime)} s dessus, montée x{fmt(s4.beamRamp)})`
	)
	-- Sa cible meurt : il passe à l'autre, et la montée repart de x1.
	call("debugKill", first)
	local s5 = waitBeamOn(stronger)
	check(
		s5.beamTargetId == stronger and s5.beamTime < 0.5 and s5.beamRamp < 1 + s5.beamRampRate * 0.5 + 1e-6,
		`Sorcier : nouvelle cible -> montée remise à zéro ({fmt(s5.beamTime)} s dessus, montée x{fmt(s5.beamRamp)})`
	)
	-- Un niveau de plus : dégâts x UPGRADE_DAMAGE, et le rayon suit la formule avec les nouveaux dégâts.
	setCoins(1e15)
	call("upgradeTower", 6)
	local s6 = call("debugTower", 6)
	task.wait(0.8)
	local s7 = call("debugTower", 6)
	check(
		close(s6.damage, s5.damage * IdleConfig.UPGRADE_DAMAGE, 1e-9) and s7.beamTargetId == stronger
			and close(s6.targetHealth - s7.targetHealth, beamExpected(s6, s7), 0.02),
		`Sorcier : niveau {s5.level} -> {s6.level}, rayon {NumberFormat.short(s5.damage)} -> {NumberFormat.short(s6.damage)} dégâts/s à x1, dégâts mesurés = formule`
	)
	setCoins(0)
	-- Au maximum de la montée : x1 puis Vitesse x2 -> deux fois plus de dégâts par seconde RÉELLE.
	waitClock(s7.clock + IdleTowers.beamRampSeconds(s7) - s7.beamTime + 0.3)
	local function realRate()
		local before, t0 = call("debugTower", 6), os.clock()
		task.wait(1)
		local after, t1 = call("debugTower", 6), os.clock()
		return (before.targetHealth - after.targetHealth) / (t1 - t0), (before.targetHealth - after.targetHealth) / (after.clock - before.clock), after
	end
	local rateX1, simRateX1, sMax = realRate()
	check(
		close(sMax.beamRamp, sMax.beamRampMax, 1e-9) and close(simRateX1, sMax.damage * sMax.beamRampMax, 0.03),
		`Sorcier au maximum (x{fmt(sMax.beamRamp)}) : {NumberFormat.short(simRateX1)} dégâts par seconde de jeu (attendu {NumberFormat.short(sMax.damage * sMax.beamRampMax)})`
	)
	dbg:Invoke(player, "Pass", "SpeedX2", true)
	task.wait(0.2)
	local rateX2, simRateX2 = realRate()
	check(
		rateX2 / rateX1 > 1.7 and rateX2 / rateX1 < 2.3 and close(simRateX2, simRateX1, 0.03),
		`Sorcier en Vitesse x2 : {NumberFormat.short(rateX2)} dégâts par seconde réelle contre {NumberFormat.short(rateX1)} (x{fmt(rateX2 / rateX1)}), les mêmes par seconde de jeu`
	)
	-- Les projectiles aussi en x2 : impact au bout de vol / 2 secondes réelles, toujours bien visé.
	projectileCheck(3, "Normal", catapultDistance - 8, "Catapulte en Vitesse x2")
	dbg:Invoke(player, "Pass", "SpeedX2", false)
	call("debugEndArena")
	check(plotFolder:GetAttribute("SimSpeed") == 1, "fin des tests de combat : vitesse normale, arène fermée")

	----------------------------------------------------------------------
	-- Contrôles (un seul à la fois par ennemi), fragilité du Totem de givre, Mage des tempêtes, Baliste
	-- perçante, Trébuchet royal (plus gros groupe + étourdissement), puis vague écrasée. Arènes où aucune tour ne
	-- tire d'elle-même : chaque tour tire avec debugFire. Ennemis immobiles (frozen) : les contrôles
	-- s'appliquent quand même. Totem 2 = emplacement 2 (5, -13), niveau 6 et rune x2 vitesse ; 2e Totem posé
	-- sur l'emplacement 10 (5, 5).
	-- Dans sa propre fonction : la fonction principale du scénario est à la limite des 200 variables locales
	-- de Luau (« Out of local registers »).
	----------------------------------------------------------------------
	local function testControlsAndSpawns()
		dbg:Invoke(player, "Set", "unlockedTowers", { MachineGun = true, Frost = true, Bomb = true, Tesla = true, Rocket = true, Laser = true, Chain = true, Orbital = true })
		setCoins(1e15)
		if not dbg:Invoke(player, "Data").idle.ownedSpots["10"] then
			call("buySpot", 10)
		end
		call("placeTower", 10, "Frost")
		check(dbg:Invoke(player, "Data").idle.towers["10"] ~= nil, "2e Totem de givre posé sur l'emplacement 10")
		setCoins(0)
		local frostDef, mageDef = defs.Frost, defs.Tesla
		local pct = function(x)
			return math.floor(x * 100 + 0.5)
		end
		-- Rangée z = -4 : distance 215 = (5, -4), dans les deux auras (9 studs de chaque Totem) et à 12,7 de l'Archer.
		-- Rangée z = -22 : distance 287 = (5, -22), dans l'aura du Totem 2 et à portée du Mage (9 studs).
		local bothAuras, frostAndMage = 215, 287
		local frostMain, frostSecond = call("debugTower", 2), call("debugTower", 10)
		check(
			defs.Frost.damage < defs.Bomb.damage and frostMain.fragility > frostSecond.fragility and frostSecond.fragility > 0,
			`Totem de givre : {frostDef.damage} dégâts de base (Catapulte {defs.Bomb.damage}), fragilité +{pct(frostSecond.fragility)} % au niveau {frostSecond.level}, +{pct(frostMain.fragility)} % au niveau {frostMain.level}`
		)

		-- Règle 1 : deux Totems = UN SEUL ralentissement de 60 %, la même source prolonge sans renforcer.
		call("debugArena", {})
		local iced = call("debugSpawn", "Tank", bothAuras, 1e9, true)
		call("debugFire", 2)
		call("debugFire", 10)
		local s1 = call("debugEnemy", iced)
		check(
			s1.controlSource == "Frost" and s1.slowFactor == frostDef.slow,
			`deux Totems de givre : un seul ralentissement de {pct(s1.slowFactor)} % (source {s1.controlSource}), jamais cumulé`
		)
		check(
			close(s1.fragility, frostMain.fragility, 1e-9),
			`deux Totems : fragilité = la plus forte seulement (+{pct(s1.fragility)} %, Totems à +{pct(frostMain.fragility)} % et +{pct(frostSecond.fragility)} %)`
		)
		waitClock(s1.clock + 0.6)
		local s2 = call("debugEnemy", iced)
		call("debugFire", 10)
		local s3 = call("debugEnemy", iced)
		check(
			s2.controlLeft < s1.controlLeft - 0.4 and s3.controlLeft > s2.controlLeft + 0.4 and s3.slowFactor == frostDef.slow and close(s3.fragility, frostMain.fragility, 1e-9),
			`même type de tour : durée prolongée ({fmt(s2.controlLeft)} -> {fmt(s3.controlLeft)} s), force inchangée ({pct(s3.slowFactor)} %), fragilité gardée`
		)
		-- Fragilité : une flèche de l'Archer fait +X % sur un ennemi dans l'aura.
		local archerNow = call("debugTower", 1)
		local healthBefore = call("debugEnemy", iced).health
		local fragileArrow = call("debugFire", 1)
		waitClock(fragileArrow.clock + fragileArrow.flight + 0.05)
		local arrowLoss = healthBefore - call("debugEnemy", iced).health
		check(
			fragileArrow.fired and close(arrowLoss, archerNow.damage * (1 + frostMain.fragility), 1e-6),
			`fragilité : flèche de l'Archer {NumberFormat.short(arrowLoss)} dégâts = {NumberFormat.short(archerNow.damage)} x {fmt(1 + frostMain.fragility)}`
		)

		-- Givre puis Mage : le ralentissement du Mage est refusé tant que le Totem gèle l'ennemi ; ses dégâts, sans
		-- bonus de fragilité, tombent quand même.
		call("debugArena", {})
		local frozenFirst = call("debugSpawn", "Tank", frostAndMage, 1e9, true)
		call("debugFire", 2)
		local beforeZap = call("debugEnemy", frozenFirst)
		local mageNow = call("debugTower", 4)
		call("debugFire", 4)
		local afterZap = call("debugEnemy", frozenFirst)
		check(
			afterZap.controlSource == "Frost" and afterZap.slowFactor == frostDef.slow,
			`Totem puis Mage : ralentissement du Mage refusé (toujours {pct(afterZap.slowFactor)} % du Totem)`
		)
		check(
			beforeZap.fragility > 0 and close(beforeZap.health - afterZap.health, mageNow.damage, 1e-6),
			`Mage sur un ennemi fragile : {NumberFormat.short(beforeZap.health - afterZap.health)} dégâts = ses dégâts normaux ({NumberFormat.short(mageNow.damage)}), pas de fragilité`
		)

		-- Mage puis Givre : le Totem ne remplace pas le ralentissement du Mage tant qu'il dure (fragilité, oui).
		-- Le Mage : bien plus fort (-90 % contre -60 %) mais bien plus court que le Totem.
		call("debugArena", {})
		local zappedFirst = call("debugSpawn", "Tank", frostAndMage, 1e9, true)
		local zapFirst = call("debugFire", 4)
		local z1 = call("debugEnemy", zappedFirst)
		check(
			z1.controlSource == "Tesla" and z1.slowFactor == mageDef.slow and mageDef.slow > frostDef.slow
				and mageDef.slowDuration < frostDef.slowDuration and z1.controlLeft <= mageDef.slowDuration + 1e-6,
			`Mage des tempêtes : -{pct(z1.slowFactor)} % pendant {mageDef.slowDuration} s (Totem : -{pct(frostDef.slow)} % pendant {frostDef.slowDuration} s)`
		)
		call("debugFire", 2)
		local z2 = call("debugEnemy", zappedFirst)
		check(
			z2.controlSource == "Tesla" and z2.slowFactor == mageDef.slow and z2.fragility > 0,
			`Mage puis Totem : le Totem ne remplace pas le ralentissement du Mage (source {z2.controlSource}), fragilité quand même (+{pct(z2.fragility)} %)`
		)
		waitClock(zapFirst.clock + mageDef.slowDuration + 0.05)
		local z3 = call("debugEnemy", zappedFirst)
		call("debugFire", 2)
		local z4 = call("debugEnemy", zappedFirst)
		check(
			not z3.slowed and z4.controlSource == "Frost" and z4.slowFactor == frostDef.slow,
			`fin du ralentissement du Mage (ralenti : {z3.slowed}), puis le Totem prend le relais ({z4.controlSource}, {pct(z4.slowFactor)} %)`
		)

		-- Baliste lourde (emplacement 5, (-13, -13)) : carreau perçant. Cible = la plus résistante, A (-13, 14) sur
		-- la rangée z = 14 ; le trait vertical x = -13 traverse la rangée z = -4 : B (-13, -4) dessus, C (-14, -4) à
		-- 1 stud, D (-18, -4) à 5 studs (hors du trait).
		call("debugArena", {})
		local boltA = call("debugSpawn", "Tank", 145, 1e12, true)
		local boltB = call("debugSpawn", "Normal", 233, 1e9, true)
		local boltC = call("debugSpawn", "Normal", 234, 1e9, true)
		local boltD = call("debugSpawn", "Normal", 238, 1e9, true)
		local bolt = call("debugFire", 5)
		check(bolt ~= nil and bolt.fired and bolt.targetId == boltA, `Baliste : vise le plus résistant (cible {bolt and bolt.targetId}, A = {boltA})`)
		if bolt and bolt.fired then
			waitClock(bolt.clock + bolt.flight + 0.05)
			local lossA = 1e12 - call("debugEnemy", boltA).health
			local lossB = 1e9 - call("debugEnemy", boltB).health
			local lossC = 1e9 - call("debugEnemy", boltC).health
			local lossD = 1e9 - call("debugEnemy", boltD).health
			check(
				close(lossA, bolt.damage, 1e-6) and close(lossB, bolt.damage, 1e-6) and close(lossC, bolt.damage, 1e-6),
				`Baliste perçante : 3 ennemis alignés touchés ({NumberFormat.short(lossA)}, {NumberFormat.short(lossB)}, {NumberFormat.short(lossC)} ; {NumberFormat.short(bolt.damage)} attendus)`
			)
			check(lossD == 0, `Baliste perçante : ennemi à 5 studs du trait pas touché ({lossD})`)
		end

		-- Trébuchet royal (emplacement 8, (14, -31)) : une foule de 4 fantassins (distances 262 à 265, x = -20 à -17)
		-- contre un Seigneur de guerre seul et bien plus résistant (330, (14, -40)) -> il vise la foule, la blesse
		-- et l'étourdit ; le boss n'est pas touché.
		call("debugArena", {})
		local crowd = {}
		for i = 0, 3 do
			table.insert(crowd, call("debugSpawn", "Normal", 262 + i, 1e9, true))
		end
		local loneBoss = call("debugSpawn", "Boss", 330, 1e15, true)
		local stone = call("debugFire", 8)
		check(
			stone ~= nil and stone.fired and table.find(crowd, stone.targetId) ~= nil,
			`Trébuchet : vise la foule plutôt que le boss seul (cible {stone and stone.targetId}, boss {loneBoss})`
		)
		if stone and stone.fired then
			waitClock(stone.clock + stone.flight + 0.05)
			local hit, stunned = 0, 0
			for _, id in crowd do
				local st = call("debugEnemy", id)
				hit += if close(1e9 - st.health, stone.damage, 1e-6) then 1 else 0
				stunned += if st.stunned and st.controlSource == "Orbital" then 1 else 0
			end
			check(
				hit == #crowd and stunned == #crowd and call("debugEnemy", loneBoss).health == 1e15,
				`Trébuchet : {hit}/{#crowd} touchés, {stunned}/{#crowd} étourdis ({defs.Orbital.stunDuration} s, zone {defs.Orbital.splash}), boss intact`
			)
		end
		-- Étourdissement soumis à la règle 1 : des ennemis déjà gelés par le Totem prennent les dégâts, pas l'étourdissement.
		call("debugArena", {})
		local frostCrowd = {}
		for i = 0, 2 do
			table.insert(frostCrowd, call("debugSpawn", "Normal", 286 + i, 1e9, true))
		end
		call("debugFire", 2)
		local stone2 = call("debugFire", 8)
		if stone2 and stone2.fired then
			waitClock(stone2.clock + stone2.flight + 0.05)
			local damaged, stayedFrost = 0, 0
			for _, id in frostCrowd do
				local st = call("debugEnemy", id)
				damaged += if 1e9 - st.health >= stone2.damage * (1 - 1e-9) then 1 else 0
				stayedFrost += if st.controlSource == "Frost" and not st.stunned then 1 else 0
			end
			check(
				damaged == #frostCrowd and stayedFrost == #frostCrowd,
				`Trébuchet sur des ennemis gelés : {damaged}/{#frostCrowd} blessés, {stayedFrost}/{#frostCrowd} restent au ralentissement du Totem (pas d'étourdissement)`
			)
		else
			check(false, "Trébuchet : pas de tir sur la foule gelée")
		end

		-- FATIGUE des contrôles courts (retour du propriétaire à la vague 148 : plein de Mages avec x2 vitesse
		-- gelaient toute la vague) et projectiles qui SUIVENT leur cible (sa Catapulte tirait trop loin quand
		-- l'ennemi était ralenti pendant le vol). Dans sa propre fonction (limite des registres de Luau).
		local function testFatigueAndFollow()
			local mage, trebuchet = defs.Tesla, defs.Orbital
			-- 1) « Plein de Mages » : le Mage (emplacement 4) foudroie le même ennemi à CHAQUE image pendant 4 s de
			-- jeu, bien plus souvent que 20 Mages avec la rune x2 vitesse. Chaque relevé donne la fin exacte du
			-- ralentissement en cours (heure + temps restant) : on retrouve chaque ralentissement, l'écart avec le
			-- suivant, et la part du temps passée ralenti.
			call("debugArena", {})
			local victim = call("debugSpawn", "Tank", frostAndMage, 1e12, true)
			local mageNow = call("debugTower", 4)
			local strikes, ends, extended = 0, {}, false
			local startClock = clockNow()
			local lastClock, lastSeen = startClock, nil
			while lastClock - startClock < 4 do
				if call("debugFire", 4).fired then
					strikes += 1
				end
				local st = call("debugEnemy", victim)
				lastClock, lastSeen = st.clock, st
				if st.controlSource == "Tesla" then
					local endAt = st.clock + st.controlLeft
					-- Une nouvelle fin moins de (durée + immunité) après la précédente = ralentissement prolongé, ou
					-- repris pendant l'immunité : interdit.
					if #ends > 0 and endAt > ends[#ends] + 1e-6 and endAt < ends[#ends] + mage.slowDuration + mage.slowImmunity - 1e-6 then
						extended = true
					end
					if #ends == 0 or math.abs(endAt - ends[#ends]) > 1e-6 then
						table.insert(ends, endAt)
					end
				end
				task.wait()
			end
			local window = lastClock - startClock
			-- Part du temps ralenti sur des cycles COMPLETS (du début du 1er ralentissement au début du dernier : à
			-- chaque fois un ralentissement, l'immunité, puis l'éclair suivant). Le bord de la fenêtre de 4 s ne compte
			-- pas : il peut couper un cycle juste après un ralentissement (l'ancienne mesure affichait « 45 % (au plus
			-- 43 %) »). Avec la fatigue, elle ne peut pas dépasser durée / (durée + immunité).
			local cycles = #ends - 1
			local fraction = if cycles > 0 then cycles * mage.slowDuration / math.max(ends[#ends] - ends[1], 1e-9) else 0
			local maxFraction = mage.slowDuration / (mage.slowDuration + mage.slowImmunity)
			check(
				#ends >= 2 and not extended and fraction <= maxFraction + 0.001 and fraction >= maxFraction * 0.5,
				`fatigue du Mage : {strikes} éclairs en {fmt(window)} s sur le même ennemi, {#ends} ralentissements de {mage.slowDuration} s jamais prolongés, ralenti {math.floor(fraction * 100 + 0.5)} % du temps sur {cycles} cycles complets (au plus {math.floor(maxFraction * 100 + 0.5)} % ; 100 % avant la fatigue)`
			)
			check(
				lastSeen ~= nil and close(1e12 - lastSeen.health, strikes * mageNow.damage, 1e-6),
				`fatigue du Mage : les dégâts tombent à chaque éclair ({NumberFormat.short(1e12 - (lastSeen and lastSeen.health or 1e12))} = {strikes} x {NumberFormat.short(mageNow.damage)})`
			)

			-- 2) Trébuchet (emplacement 8) : pas d'enchaînement d'étourdissements. La 2e pierre, tirée dès l'arrivée
			-- de la 1re, tombe après la fin de l'étourdissement, pendant l'immunité : dégâts, pas d'étourdissement.
			-- Après l'immunité, une 3e pierre étourdit de nouveau (et garde son point prévu : pas de suivi).
			call("debugArena", {})
			for i = 0, 3 do
				call("debugSpawn", "Normal", 262 + i, 1e9, true)
			end
			local firstStone = call("debugFire", 8)
			if not (firstStone and firstStone.fired) then
				check(false, "fatigue du Trébuchet : pas de tir")
				return
			end
			local stunnedId = firstStone.targetId
			waitClock(firstStone.clock + firstStone.flight + 0.02)
			local afterFirst = call("debugEnemy", stunnedId)
			local secondStone = call("debugFire", 8)
			waitClock(secondStone.clock + secondStone.flight + 0.02)
			local afterSecond = call("debugEnemy", stunnedId)
			local stunEnd = afterFirst.clock + afterFirst.controlLeft
			local immuneLeft = afterSecond.immuneLeft and afterSecond.immuneLeft.Orbital or 0
			check(
				afterFirst.stunned and afterFirst.controlLeft <= trebuchet.stunDuration + 1e-6
					and secondStone.clock + secondStone.flight > stunEnd
					and not afterSecond.stunned and immuneLeft > 0
					and close(afterFirst.health - afterSecond.health, secondStone.damage, 1e-6),
				`fatigue du Trébuchet : 1re pierre -> étourdi {trebuchet.stunDuration} s ; 2e pierre ({fmt(secondStone.clock + secondStone.flight - stunEnd)} s après la fin) -> {NumberFormat.short(afterFirst.health - afterSecond.health)} dégâts mais pas d'étourdissement (immunisé encore {fmt(immuneLeft)} s sur {trebuchet.stunImmunity})`
			)
			waitClock(afterSecond.clock + immuneLeft + 0.02)
			local thirdStone = call("debugFire", 8)
			waitClock(thirdStone.clock + thirdStone.flight + 0.02)
			local afterThird = call("debugEnemy", stunnedId)
			local stoneImpact = call("debugLastImpact")
			check(
				afterThird.stunned and afterThird.controlSource == "Orbital" and stoneImpact ~= nil and flat(stoneImpact.center, stoneImpact.aim) < 1e-6,
				`fatigue du Trébuchet : après l'immunité, la 3e pierre étourdit de nouveau ({afterThird.controlSource}) ; elle tombe sur son point prévu (pas de suivi)`
			)

			-- 3) Rocher de la Catapulte (emplacement 3) qui suit sa cible : un cavalier qui court (rangée z = -22,
			-- distance 284) est visé, puis s'arrête net juste après le tir (debugFreeze : comme un étourdissement que
			-- la visée ne pouvait pas deviner). Le point prévu est alors plus loin que la zone du rocher : avant, le
			-- rocher tombait devant lui. Maintenant, les dégâts tombent sur lui.
			call("debugArena", {})
			local rider = call("debugSpawn", "Fast", 284, 1e9, false)
			local rock = call("debugFire", 3)
			call("debugFreeze", rider)
			if not (rock and rock.fired) then
				check(false, "Catapulte qui suit sa cible : pas de tir")
				return
			end
			waitClock(rock.clock + rock.flight + 0.05)
			local hitRider = call("debugEnemy", rider)
			local rockImpact = call("debugLastImpact")
			local lag = if rockImpact then flat(rockImpact.aim, rockImpact.targetPosition) else 0
			check(
				rock.targetId == rider and rockImpact ~= nil and lag > defs.Bomb.splash
					and flat(rockImpact.center, rockImpact.targetPosition) < 1e-3
					and close(1e9 - hitRider.health, rock.damage, 1e-6),
				`Catapulte : cavalier arrêté pendant le vol, point prévu à {fmt(lag)} studs de lui (zone {defs.Bomb.splash}) : le rocher le suit et le touche ({NumberFormat.short(1e9 - hitRider.health)} dégâts, {NumberFormat.short(rock.damage)} attendus)`
			)
		end
		testFatigueAndFollow()
		call("debugEndArena")

		-- Vague écrasée : quand personne n'est en vie, l'ennemi suivant sort tout de suite
		-- (IdleConfig.COMPRESS_EMPTY_SPAWNS). La vague 1 (Escarmouche, 10 ennemis sur ~5 s) est jouée d'un coup
		-- par debugRunWave, sans aucune tour.
		local waveBeforeRuns = dbg:Invoke(player, "Data").idle.wave
		local crushed = call("debugRunWave", 1, "OneShot", 1 / 60, 600)
		check(
			crushed.ended and crushed.steps <= crushed.count + 2,
			`vague de {crushed.count} ennemis tués dès leur sortie : finie en {crushed.steps} pas ({fmt(crushed.seconds)} s de jeu au lieu de {fmt(crushed.expectedTimes[crushed.count])} s d'apparitions)`
		)
		-- Sortie à chaque mort (IdleConfig.SPAWN_NEXT_ON_KILL) : le plus ancien ennemi meurt dès qu'un autre est
		-- en vie ; chaque mort fait sortir le suivant au pas d'après (0,05 s), sans attendre son heure normale.
		local chained = call("debugRunWave", 1, "KillOldest", 0.05, 60)
		local instant = #chained.spawnTimes == chained.count
		for i = 3, #chained.spawnTimes do
			instant = instant and chained.spawnTimes[i] - chained.spawnTimes[i - 1] <= 0.05 + 1e-6
		end
		local lastChained = chained.spawnTimes[#chained.spawnTimes] or math.huge
		check(
			IdleConfig.SPAWN_NEXT_ON_KILL and instant and lastChained < chained.expectedTimes[chained.count] - 1,
			`une mort fait sortir le suivant tout de suite (d'autres ennemis en vie) : {#chained.spawnTimes}/{chained.count} sortis, le dernier à {fmt(lastChained)} s au lieu de {fmt(chained.expectedTimes[chained.count])} s`
		)
		local survived = call("debugRunWave", 1, "Survive", 0.05, 110)
		local onTime = #survived.spawnTimes == survived.count
		for i, t in survived.spawnTimes do
			onTime = onTime and t >= survived.expectedTimes[i] - 1e-6 and t <= survived.expectedTimes[i] + 0.05 + 1e-6
		end
		check(
			onTime and not survived.ended,
			`vague où les ennemis survivent : {#survived.spawnTimes}/{survived.count} apparitions aux heures normales (dernier à {fmt(survived.spawnTimes[#survived.spawnTimes])} s, prévu {fmt(survived.expectedTimes[survived.count])} s)`
		)
		local waveAfterRuns = dbg:Invoke(player, "Data").idle.wave
		check(
			waveAfterRuns == waveBeforeRuns and plotFolder:GetAttribute("State") == "Intermission",
			`après les vagues de test : vague remise ({waveBeforeRuns} -> {waveAfterRuns}), parcelle en entracte`
		)
	end
	testControlsAndSpawns()

	----------------------------------------------------------------------
	-- Pass Pièces x2 : toutes les pièces gagnées sur la parcelle sont doublées (ennemis tués, gains d'absence)
	----------------------------------------------------------------------
	-- Arène où aucune tour ne tire. Le Ramassage auto vide d'abord le sol : chaque ennemi tué ci-dessous
	-- fait une nouvelle pile (16 studs entre elles, sur la rangée droite z = -4), montants exacts.
	call("debugArena", {})
	dbg:Invoke(player, "Pass", "AutoCollect", true)
	task.wait(IdleConfig.AUTO_COLLECT_DELAY + 1)
	dbg:Invoke(player, "Pass", "AutoCollect", false)
	setCoins(0)
	local coinsBonus = dbg:Invoke(player, "Data").idle.coinBonus
	local ENEMY_REWARD = 1000
	-- Pièces posées au sol par la mort d'un ennemi à ENEMY_REWARD pièces, tué à `distance` sur le chemin.
	local function killedDrop(distance)
		local id = call("debugSpawn", "Normal", distance, 10, true, ENEMY_REWARD)
		return call("debugKill", id)
	end
	local expectedX1 = ENEMY_REWARD * (1 + coinsBonus / 100)
	local dropX1 = killedDrop(204)
	check(
		dropX1 == expectedX1,
		`Pièces x2 — sans pass : ennemi à {ENEMY_REWARD} pièces, bonus +{coinsBonus} % -> {dropX1} au sol (attendu {expectedX1})`
	)
	dbg:Invoke(player, "Pass", "CoinsX2", true)
	check(
		player:GetAttribute("PassCoinsX2") == true and plotFolder:GetAttribute("CoinMultiplier") == 2,
		`pass Pièces x2 donné (test Studio) : PassCoinsX2={player:GetAttribute("PassCoinsX2")} CoinMultiplier={plotFolder:GetAttribute("CoinMultiplier")}`
	)
	local dropX2 = killedDrop(220)
	check(dropX1 > 0 and dropX2 == 2 * dropX1, `avec le pass : le même ennemi lâche {dropX2} pièces = 2 x {dropX1} (bonus de renaissance compris)`)
	dbg:Invoke(player, "Pass", "CoinsX2", false)
	check(
		player:GetAttribute("PassCoinsX2") == false and plotFolder:GetAttribute("CoinMultiplier") == 1,
		`pass Pièces x2 retiré : PassCoinsX2={player:GetAttribute("PassCoinsX2")} CoinMultiplier={plotFolder:GetAttribute("CoinMultiplier")}`
	)
	local dropBack = killedDrop(236)
	check(dropBack == dropX1, `pass retiré : de nouveau x1 ({dropBack} au sol, {dropX1} avant le pass)`)
	-- Ramassage : chaque pile est versée telle quelle (pas doublée une 2e fois).
	dbg:Invoke(player, "Pass", "AutoCollect", true)
	task.wait(IdleConfig.AUTO_COLLECT_DELAY + 1)
	dbg:Invoke(player, "Pass", "AutoCollect", false)
	local pickedUp = coinsNow()
	check(
		near(pickedUp, dropX1 + dropX2 + dropBack),
		`piles ramassées : +{NumberFormat.short(pickedUp)} pièces = {dropX1} + {dropX2} + {dropBack}`
	)

	-- Gains d'absence : les mêmes absences sans le pass, avec, puis de nouveau sans (vague 40, compteur du jour vide).
	local savedBestX2 = dbg:Invoke(player, "Data").idle.bestWave
	dbg:Invoke(player, "Set", "bestWave", 40)
	local passNoon = os.time() // 86400 * 86400 + 12 * 3600
	local offlineFields = { lastSeenAt = passNoon - 7200, matchDepartureAt = 0, offlineDay = 0, offlineGainedToday = 0 }
	local matchFields = { lastSeenAt = passNoon - 30, matchDepartureAt = passNoon - 30 - 600, offlineDay = 0, offlineGainedToday = 0 }
	local offlineX1 = absence(offlineFields, passNoon, "Pièces x2 — sans pass : absence de 2 h", true)
	local matchX1 = absence(matchFields, passNoon, "Pièces x2 — sans pass : match de 10 min", true)
	check(
		offlineX1.amount > 0 and matchX1.matchAmount > 0 and offlineX1.coinFactor == 1 and matchX1.coinFactor == 1,
		`sans pass : 2 h hors ligne +{NumberFormat.short(offlineX1.amount)}, match +{NumberFormat.short(matchX1.amount)} (coinFactor {offlineX1.coinFactor})`
	)
	dbg:Invoke(player, "Pass", "CoinsX2", true)
	local offlineX2, dOffline = absence(offlineFields, passNoon, "avec le pass Pièces x2 : absence de 2 h", true)
	check(
		offlineX2.amount == 2 * offlineX1.amount and offlineX2.offlineAmount == 2 * offlineX1.offlineAmount and offlineX2.coinFactor == 2,
		`avec le pass : 2 h hors ligne +{NumberFormat.short(offlineX2.amount)} = 2 x {NumberFormat.short(offlineX1.amount)} (coinFactor {offlineX2.coinFactor})`
	)
	check(
		dOffline.idle.offlineGainedToday == offlineX1.offlineAmount,
		`avec le pass : plafond du jour compté en pièces x1 (compteur {NumberFormat.short(dOffline.idle.offlineGainedToday)}, x1 = {NumberFormat.short(offlineX1.offlineAmount)})`
	)
	local matchX2 = absence(matchFields, passNoon, "avec le pass Pièces x2 : match de 10 min", true)
	check(
		matchX2.matchAmount == 2 * matchX1.matchAmount and matchX2.amount == 2 * matchX1.amount and matchX2.coinFactor == 2,
		`avec le pass : match ranked +{NumberFormat.short(matchX2.matchAmount)} = 2 x {NumberFormat.short(matchX1.matchAmount)} (total {NumberFormat.short(matchX2.amount)})`
	)
	dbg:Invoke(player, "Pass", "CoinsX2", false)
	local offlineBack = absence(offlineFields, passNoon, "pass Pièces x2 retiré : absence de 2 h", true)
	check(
		offlineBack.amount == offlineX1.amount and offlineBack.coinFactor == 1,
		`pass retiré : gains d'absence de nouveau x1 (+{NumberFormat.short(offlineBack.amount)})`
	)
	-- Remise en état : vague d'avant, vraie heure de visite, compteur vide, pièces à 0, arène fermée.
	dbg:Invoke(player, "Set", "bestWave", savedBestX2)
	dbg:Invoke(player, "Absence", os.time(), true, { lastSeenAt = os.time(), offlineDay = 0, offlineGainedToday = 0, matchDepartureAt = 0 })
	setCoins(0)
	call("debugEndArena")

	----------------------------------------------------------------------
	-- Forge runique : prix qui monte à chaque lancer en pièces (x5 jusqu'à 1 T, puis x2), plus de délai, 2 runes
	-- par tour qui se cumulent (dégâts + vitesse), runes tirées seulement si elles améliorent une tour posée dans
	-- l'emplacement de leur sorte, forge bloquée sinon, lancers Robux hors compteur, anciennes sauvegardes.
	-- Dans sa propre fonction (limite des 200 variables locales de Luau, voir plus haut).
	----------------------------------------------------------------------
	local function testForge()
		local FIRST = IdleConfig.FORGE_FIRST_PRICE
		check(
			IdleConfig.forgeCoinPrice(0) == 100e3 and IdleConfig.forgeCoinPrice(1) == 500e3 and FIRST == 100e3,
			`forge : 1er lancer {NumberFormat.price(IdleConfig.forgeCoinPrice(0))}, 2e {NumberFormat.price(IdleConfig.forgeCoinPrice(1))}`
		)
		local p11, p12, p13, p14 = IdleConfig.forgeCoinPrice(10), IdleConfig.forgeCoinPrice(11), IdleConfig.forgeCoinPrice(12), IdleConfig.forgeCoinPrice(13)
		check(
			p11 == FIRST * 5 ^ 10 and p11 < 1e12 and p12 == p11 * 5 and p12 >= 1e12 and p13 == p12 * 2 and p14 == p13 * 2,
			`forge : 11e lancer {NumberFormat.price(p11)} (sous 1 T, x5), 12e {NumberFormat.price(p12)}, puis x2 : {NumberFormat.price(p13)}, {NumberFormat.price(p14)}`
		)
		check(
			IdleConfig.forgeCoinPrice(5000) == math.huge and IdleConfig.forgeCoinPrice(0 / 0) == FIRST and IdleConfig.forgeCoinPrice(-3) == FIRST,
			"forge : prix MAX (math.huge) après des milliers de lancers, compteur abîmé = 0"
		)
		local function forgeState()
			return call("forgeState")
		end
		-- Lancer en pièces sur le serveur : renvoie (résultat, données avant, données après).
		local function forgeSpin()
			local f0 = dbg:Invoke(player, "Data")
			local result = call("spinBonusWithCoins")
			return result, f0, dbg:Invoke(player, "Data")
		end
		dbg:Invoke(player, "Set", "forgeSpinsBought", 0)
		dbg:Invoke(player, "Set", "bonuses", {})
		-- Au moins une tour sans rune (le 2e Totem) : la forge marche.
		call("publishInventory")
		check(player:GetAttribute("ForgeBlocked") == "" and player:GetAttribute("ForgeCoinPrice") == FIRST, `forge ouverte, prochain prix publié {player:GetAttribute("ForgeCoinPrice")}`)
		setCoins(FIRST)
		local r1, f0, f1 = forgeSpin()
		check(
			r1 ~= nil and f0.coins - f1.coins == FIRST and f1.idle.forgeSpinsBought == 1 and #f1.idle.bonuses == 1 and r1.price == FIRST,
			`forge : 1er lancer payé {NumberFormat.price(f0.coins - f1.coins)}, compteur {f1.idle.forgeSpinsBought}, rune {r1 and r1.bonus}`
		)
		check(
			player:GetAttribute("ForgeSpinsBought") == 1 and player:GetAttribute("ForgeCoinPrice") == IdleConfig.forgeCoinPrice(1),
			`forge : attributs ForgeSpinsBought = {player:GetAttribute("ForgeSpinsBought")}, ForgeCoinPrice = {player:GetAttribute("ForgeCoinPrice")}`
		)
		-- Plus de délai : un 2e lancer tout de suite.
		setCoins(IdleConfig.forgeCoinPrice(1))
		local r2, g0, g1 = forgeSpin()
		check(
			r2 ~= nil and g0.coins - g1.coins == IdleConfig.forgeCoinPrice(1) and g1.idle.forgeSpinsBought == 2,
			`forge : 2e lancer tout de suite (plus de délai), payé {NumberFormat.price(g0.coins - g1.coins)}`
		)
		-- Pas assez de pièces : refusé, rien ne change.
		setCoins(IdleConfig.forgeCoinPrice(2) - 1)
		local r3, h0, h1 = forgeSpin()
		check(
			r3 == nil and h1.coins == h0.coins and h1.idle.forgeSpinsBought == 2 and #h1.idle.bonuses == #h0.idle.bonuses,
			"forge : refusée sans assez de pièces (pièces, compteur et inventaire inchangés)"
		)
		-- Autour de 1 T : 11e, 12e et 13e lancers.
		dbg:Invoke(player, "Set", "forgeSpinsBought", 10)
		for _, expected in { p11, p12, p13 } do
			setCoins(expected)
			local r, k0, k1 = forgeSpin()
			check(
				r ~= nil and k0.coins - k1.coins == expected and k1.idle.forgeSpinsBought == k0.idle.forgeSpinsBought + 1,
				`forge : lancer n° {k0.idle.forgeSpinsBought + 1} payé {NumberFormat.price(k0.coins - k1.coins)} (attendu {NumberFormat.price(expected)})`
			)
		end
		-- Un achat Robux ne compte pas et ne fait pas monter le prix.
		local beforeRobux = forgeState()
		local robuxBefore = #dbg:Invoke(player, "Data").idle.bonuses
		local robux = call("grantBonusSpin", "Robux")
		local afterRobux = forgeState()
		check(
			robux ~= nil and robux.source == "Robux" and afterRobux.bought == beforeRobux.bought and afterRobux.price == beforeRobux.price
				and #dbg:Invoke(player, "Data").idle.bonuses == robuxBefore + 1,
			`forge : lancer Robux ({robux and robux.bonus}) sans changer le compteur ({beforeRobux.bought} -> {afterRobux.bought}) ni le prix`
		)

		-- DEUX emplacements de rune par tour, qui se cumulent : dégâts et vitesse. Runes de chaque tour dans la
		-- sauvegarde : idle.towers[emplacement].runes = { Damage = id, Speed = id }. Au départ du test : Archer
		-- (emplacement 1) x10 dégâts, Totem (2) x2 vitesse, les autres tours sans rune.
		-- Pose `runeId` sur ces emplacements (inventaire rempli juste pour ça, puis vidé).
		local function applyTo(spots, runeId)
			local inventory = {}
			for _ in spots do
				table.insert(inventory, runeId)
			end
			dbg:Invoke(player, "Set", "bonuses", inventory)
			for _, spot in spots do
				call("applyBonus", spot, runeId)
			end
			dbg:Invoke(player, "Set", "bonuses", {})
			call("publishInventory")
		end
		-- Pose `runeId` sur toutes les tours posées (onlyWeaker : seulement celles dont la rune de la MÊME sorte
		-- est plus faible).
		local function applyToAll(runeId, onlyWeaker)
			local kind = IdleConfig.BONUS_BY_ID[runeId].kind
			local list = {}
			for key, tower in dbg:Invoke(player, "Data").idle.towers do
				if not onlyWeaker or IdleConfig.runeValue(tower.runes[kind]) < IdleConfig.runeValue(runeId) then
					table.insert(list, tonumber(key))
				end
			end
			applyTo(list, runeId)
		end
		-- Vrai si toutes les tours posées ont ces runes (nil = peu importe cette sorte).
		local function allTowersHave(damageId, speedId)
			for _, tower in dbg:Invoke(player, "Data").idle.towers do
				if (damageId and tower.runes.Damage ~= damageId) or (speedId and tower.runes.Speed ~= speedId) then
					return false
				end
			end
			return true
		end

		-- Runes cumulées sur UNE tour (Archer, emplacement 1) : dégâts x la rune de dégâts, attaques par seconde
		-- x la rune de vitesse. Chiffres exacts : dégâts du niveau x doublons x rune, temps entre deux flèches / 2.
		local archerDef = IdleTowers.Defs.MachineGun
		local archerModel = nil
		for _, model in plotFolder.Towers:GetChildren() do
			if model:GetAttribute("SpotIndex") == 1 then
				archerModel = model
			end
		end
		local a0 = call("debugTower", 1)
		local archerDupes = dbg:Invoke(player, "Data").idle.towerDupes.MachineGun or 0
		local plain = IdleTowers.stats("MachineGun", a0.level).damage * (1 + archerDupes * IdleConfig.DUPLICATE_DAMAGE_BONUS)
		check(
			a0.runes == "Damage10" and close(a0.damage, plain * 10, 1e-9) and close(a0.cooldown, archerDef.cooldown, 1e-9),
			`Archer avec x10 dégâts seulement : {NumberFormat.short(a0.damage)} dégâts (= 10 x {NumberFormat.short(plain)}), {fmt(1 / a0.cooldown)} atq/s`
		)
		applyTo({ 1 }, "Speed2")
		local a1 = call("debugTower", 1)
		local a1Saved = dbg:Invoke(player, "Data").idle.towers["1"].runes
		check(
			a1.runes == "Damage10,Speed2" and a1Saved.Damage == "Damage10" and a1Saved.Speed == "Speed2"
				and close(a1.damage, plain * 10, 1e-9) and close(a1.cooldown, archerDef.cooldown / 2, 1e-9),
			`x2 vitesse posée sur l'Archer qui a x10 dégâts : les deux se cumulent ({NumberFormat.short(a1.damage)} dégâts, {fmt(1 / a1.cooldown)} atq/s = 2 x {fmt(1 / archerDef.cooldown)})`
		)
		local sharedStats = IdleTowers.effectiveStats("MachineGun", a1.level, archerDupes, "Damage10,Speed2")
		check(
			close(sharedStats.damage, a1.damage, 1e-12) and close(sharedStats.cooldown, a1.cooldown, 1e-12)
				and close(IdleTowers.dpsOf(sharedStats), plain * 10 * 2 / archerDef.cooldown, 1e-9)
				and archerModel ~= nil and archerModel:GetAttribute("Bonus") == "Damage10,Speed2",
			`fiche et tableau du fief : mêmes stats avec l'attribut Bonus = « {archerModel and archerModel:GetAttribute("Bonus")} » (DPS x20)`
		)
		-- Une rune de dégâts ne remplace que la rune de dégâts (l'ancienne est perdue, pas rendue) : la vitesse reste.
		dbg:Invoke(player, "Set", "bonuses", { "Damage20" })
		call("applyBonus", 1, "Damage20")
		local a2 = call("debugTower", 1)
		local a2Data = dbg:Invoke(player, "Data")
		check(
			a2.runes == "Damage20,Speed2" and a2Data.idle.towers["1"].runes.Speed == "Speed2" and #a2Data.idle.bonuses == 0
				and close(a2.damage, plain * 20, 1e-9) and close(a2.cooldown, archerDef.cooldown / 2, 1e-9),
			`x20 dégâts posée : remplace x10 dégâts (perdue, inventaire {#a2Data.idle.bonuses}), x2 vitesse gardée ({a2.runes})`
		)

		-- Forge, emplacement par emplacement : toutes les tours à x2 dégâts ou mieux -> x2 dégâts n'est plus tirée,
		-- mais x2 vitesse l'est encore (des tours n'ont pas de rune de vitesse). 40 lancers : jamais x2 dégâts.
		applyToAll("Damage2", true)
		local stateX2 = forgeState()
		local publishedX2 = string.split(player:GetAttribute("ForgeDrawable") or "", ",") -- (« Damage2 » est dans « Damage20 »)
		check(
			table.find(stateX2.drawable, "Damage2") == nil and table.find(stateX2.drawable, "Speed2") ~= nil and stateX2.blocked == nil
				and table.find(publishedX2, "Damage2") == nil and table.find(publishedX2, "Speed2") ~= nil,
			`toutes les tours à x2 dégâts ou mieux : x2 dégâts exclue, x2 vitesse encore tirable ({table.concat(stateX2.drawable, ",")})`
		)
		dbg:Invoke(player, "Set", "forgeSpinsBought", 0) -- prix modestes pour 40 lancers
		setCoins(1e300)
		local drawnDamageX2, drawn, draws = 0, {}, 0
		for _ = 1, 40 do
			local r = call("spinBonusWithCoins")
			if r then
				draws += 1
				drawn[r.bonus] = (drawn[r.bonus] or 0) + 1
				if r.bonus == "Damage2" then
					drawnDamageX2 += 1
				end
			end
		end
		local drawnList = {}
		for id, n in drawn do
			table.insert(drawnList, `{id}:{n}`)
		end
		table.sort(drawnList)
		check(draws == 40 and drawnDamageX2 == 0, `40 lancers : aucune rune x2 dégâts tirée ({table.concat(drawnList, " ")})`)
		check(dbg:Invoke(player, "Data").idle.forgeSpinsBought == 40, "40 lancers en pièces comptés")

		-- Toutes les tours à x100 dégâts : la forge marche encore, avec la seule rune qui améliore une tour (x2
		-- vitesse, 100 %). Un lancer en pièces et un lancer offert (défi classé) donnent donc x2 vitesse.
		applyToAll("Damage100", true)
		local stateSpeed = forgeState()
		local speedOdds = IdleConfig.forgeOdds({ IdleConfig.BONUS_BY_ID.Speed2 })
		check(
			allTowersHave("Damage100", nil) and stateSpeed.blocked == nil and #stateSpeed.drawable == 1 and stateSpeed.drawable[1] == "Speed2"
				and player:GetAttribute("ForgeDrawable") == "Speed2" and player:GetAttribute("ForgeBlocked") == "" and speedOdds.Speed2 == 100,
			`x100 dégâts partout : seule x2 vitesse reste tirable ({table.concat(stateSpeed.drawable, ",")}, {speedOdds.Speed2} %), forge ouverte`
		)
		local speedSpin = call("spinBonusWithCoins")
		local freeSpeedSpin = call("grantBonusSpin", "Challenge")
		check(
			speedSpin ~= nil and speedSpin.bonus == "Speed2" and freeSpeedSpin ~= nil and freeSpeedSpin.bonus == "Speed2",
			`lancer en pièces ({speedSpin and speedSpin.bonus}) et lancer offert d'un défi ({freeSpeedSpin and freeSpeedSpin.bonus}) : x2 vitesse`
		)

		-- x2 vitesse posée partout : les runes de dégâts restent, et plus rien n'améliore une tour -> forge bloquée
		-- (pièces), un reçu Robux donne la meilleure rune (x100 dégâts).
		applyToAll("Speed2", true)
		local stateBest = forgeState()
		check(
			allTowersHave("Damage100", "Speed2") and stateBest.blocked == IdleConfig.FORGE_ALL_BEST and #stateBest.drawable == 0
				and player:GetAttribute("ForgeBlocked") == IdleConfig.FORGE_ALL_BEST and player:GetAttribute("ForgeDrawable") == "",
			`x100 dégâts ET x2 vitesse sur toutes les tours (vitesse posée sans toucher aux dégâts) : forge bloquée (« {player:GetAttribute("ForgeBlocked")} »)`
		)
		local blockedResult, b0, b1 = forgeSpin()
		check(
			blockedResult == nil and b1.coins == b0.coins and b1.idle.forgeSpinsBought == b0.idle.forgeSpinsBought and #b1.idle.bonuses == #b0.idle.bonuses,
			"forge bloquée : lancer en pièces refusé (pièces, compteur, inventaire inchangés)"
		)
		local lateReceipt = call("grantBonusSpin", "Robux")
		check(
			lateReceipt ~= nil and lateReceipt.bonus == IdleConfig.bestRune().id and dbg:Invoke(player, "Data").idle.forgeSpinsBought == b1.idle.forgeSpinsBought,
			`forge bloquée : un achat Robux arrivé quand même donne la meilleure rune ({lateReceipt and lateReceipt.bonus}), compteur inchangé`
		)
		-- Inventaire plein : une rune payée en Robux entre quand même (un achat n'est jamais perdu).
		local fullInventory = table.create(IdleConfig.MAX_BONUS_INVENTORY, "Damage2")
		dbg:Invoke(player, "Set", "bonuses", fullInventory)
		call("grantBonusSpin", "Robux")
		local afterFull = #dbg:Invoke(player, "Data").idle.bonuses
		check(
			afterFull == IdleConfig.MAX_BONUS_INVENTORY + 1,
			`inventaire plein ({IdleConfig.MAX_BONUS_INVENTORY}) : la rune Robux entre quand même ({afterFull} runes)`
		)
		local forgeEnd = dbg:Invoke(player, "Data")
		check(
			cleanCounter(forgeEnd.idle.forgeSpinsBought) and forgeEnd.idle.lastBonusSpinAt == nil,
			`compteur de la forge entier et fini ({forgeEnd.idle.forgeSpinsBought}), plus de lastBonusSpinAt`
		)

		-- Anciennes sauvegardes : UNE rune par tour (champ bonus) -> elle va dans l'emplacement de sa sorte, le
		-- champ bonus disparaît, un id inconnu est retiré ; le nouveau format ne bouge pas (une rune rangée sous la
		-- mauvaise clé retourne dans le bon emplacement). Complétées comme au chargement d'un joueur (StudioDebug
		-- « ChallengeMigrate » = PlayerData.reconcile).
		local migrated = dbg:Invoke(player, "ChallengeMigrate", {
			coins = 7,
			idle = {
				towers = {
					["1"] = { type = "MachineGun", level = 4, spent = 70, bonus = "Speed2" },
					["2"] = { type = "Frost", level = 2, spent = 45, bonus = "Damage20" },
					["3"] = { type = "Bomb", level = 1, spent = 40, bonus = "RuneInconnue" },
					["4"] = { type = "Tesla", level = 1, spent = 50 },
					["5"] = { type = "Rocket", level = 3, spent = 90, runes = { Damage = "Damage5", Speed = "Speed2" } },
					["6"] = { type = "Laser", level = 1, spent = 120, runes = { Damage = "Speed2" } },
				},
			},
		})
		local mt = migrated and migrated.idle and migrated.idle.towers
		local migrationOk = mt ~= nil
		if mt then
			for key, tower in mt do
				migrationOk = migrationOk and tower.bonus == nil and typeof(tower.runes) == "table"
					and (key ~= "1" or (tower.runes.Speed == "Speed2" and tower.runes.Damage == nil and tower.level == 4))
					and (key ~= "2" or (tower.runes.Damage == "Damage20" and tower.runes.Speed == nil))
					and ((key ~= "3" and key ~= "4") or next(tower.runes) == nil)
					and (key ~= "5" or (tower.runes.Damage == "Damage5" and tower.runes.Speed == "Speed2"))
					and (key ~= "6" or (tower.runes.Speed == "Speed2" and tower.runes.Damage == nil))
			end
		end
		check(
			migrationOk and migrated.coins == 7,
			"ancienne sauvegarde (1 rune par tour) : x2 vitesse -> emplacement vitesse, x20 dégâts -> emplacement dégâts, rune inconnue retirée, nouveau format gardé"
		)
		dbg:Invoke(player, "Set", "bonuses", {})
		call("publishInventory")
		setCoins(0)
	end
	testForge()

	----------------------------------------------------------------------
	-- Défis classés (Shared/Challenges.luau, Hub/ChallengeRewards.luau) : progression comptée par le même code
	-- que le serveur de match (StudioDebug « ChallengeMatch »), règle des 3 minutes, même adversaire 2 fois par
	-- jour au plus, récompense donnée une seule fois, lancers offerts sans hausse des prix, nouveau jour et
	-- nouvelle semaine (horloge décalée), anciennes sauvegardes. À la fin du test de la forge, toutes les tours
	-- ont x100 dégâts et x2 vitesse : la forge est bloquée (le lancer offert donne la meilleure rune, comme un
	-- reçu Robux ; le test de la forge vérifie aussi qu'un lancer offert suit les emplacements de rune).
	----------------------------------------------------------------------
	local function testChallenges()
		local HttpService = game:GetService("HttpService")
		local Challenges = require(ReplicatedStorage.Shared.Challenges)
		local function challengeState()
			return dbg:Invoke(player, "Challenges")
		end
		local function match(args)
			return dbg:Invoke(player, "ChallengeMatch", args)
		end
		local function claim(key, period)
			return dbg:Invoke(player, "ChallengeClaim", key, period)
		end
		local function ids(list)
			local out = {}
			for _, entry in list do
				table.insert(out, entry.id)
			end
			return table.concat(out, ",")
		end
		-- Doublons + tours débloquées : chaque lancer de l'autel en ajoute exactement 1.
		local function altarItems(d)
			local total = 0
			for _, n in d.idle.towerDupes do
				total += n
			end
			for _, unlocked in d.idle.unlockedTowers do
				total += if unlocked then 1 else 0
			end
			return total
		end
		local function allFinite(t)
			for _, value in t do
				if typeof(value) == "number" and (value ~= value or value == math.huge or value == -math.huge) then
					return false
				elseif typeof(value) == "table" and not allFinite(value) then
					return false
				end
			end
			return true
		end

		dbg:Invoke(player, "ChallengeClock", 0)
		local now = os.time()
		local s0 = challengeState()
		check(
			#s0.daily == Challenges.DAILY_COUNT and #s0.weekly == Challenges.WEEKLY_COUNT
				and s0.day == Challenges.dayNumber(now) and s0.week == Challenges.weekNumber(now),
			`défis classés : {#s0.daily} du jour (jour {s0.day}), {#s0.weekly} de la semaine (semaine {s0.week})`
		)
		check(
			ids(s0.daily) == table.concat(Challenges.dailyPicks(s0.day), ",") and ids(s0.weekly) == table.concat(Challenges.weeklyPicks(s0.week), ","),
			`défis tirés avec le numéro du jour et de la semaine, les mêmes pour tous ({ids(s0.daily)} | {ids(s0.weekly)})`
		)

		-- Défis connus pour la suite (progression à 0).
		local forced = dbg:Invoke(player, "ChallengeForce", { "play2", "win1", "towers15" }, { "play10", "minutes45" })
		check(ids(forced.daily) == "play2,win1,towers15" and ids(forced.weekly) == "play10,minutes45" and forced.ready == 0, "défis forcés pour le test, rien à récupérer")

		-- Progression : un match classé de 4 min gagné, 6 tours posées, 3 types, 4 améliorations.
		local r1 = match({ seconds = 240, won = true, opponentId = 1001, towersPlaced = 6, upgrades = 4, towerTypes = 3 })
		local s1 = challengeState()
		check(
			r1.counted and s1.daily[1].p == 1 and s1.daily[2].p == 1 and s1.daily[2].done and s1.daily[3].p == 6
				and s1.weekly[1].p == 1 and s1.weekly[2].p == 240,
			`match compté (« {r1.text} ») : matchs 1/2, victoire 1/1, tours 6/15, semaine 1/10 et 240 s`
		)
		check(s1.ready == 1 and player:GetAttribute("ChallengesReady") == 1, `pastille du bouton DÉFIS : {player:GetAttribute("ChallengesReady")} récompense prête`)

		-- Règle des 3 minutes : 179 s ne compte pas, 180 s compte.
		local short = match({ seconds = Challenges.MIN_MATCH_SECONDS - 1, won = true, opponentId = 1002, towersPlaced = 5 })
		local s2 = challengeState()
		check(
			not short.counted and short.reason == Challenges.REASON_SHORT and s2.daily[1].p == 1 and s2.daily[3].p == 6,
			`match de {Challenges.MIN_MATCH_SECONDS - 1} s : ne compte pas (« {short.text} »), progression inchangée`
		)
		local exact = match({ seconds = Challenges.MIN_MATCH_SECONDS, opponentId = 1002 })
		check(exact.counted and challengeState().daily[1].p == 2, `match de {Challenges.MIN_MATCH_SECONDS} s tout juste : compte (Joue 2 matchs : terminé)`)

		-- Même adversaire : 2 matchs comptés par jour au plus ; un autre adversaire compte toujours.
		local o1 = match({ seconds = 300, opponentId = 2002 })
		local o2 = match({ seconds = 300, opponentId = 2002 })
		local o3 = match({ seconds = 300, opponentId = 2002 })
		local o4 = match({ seconds = 300, opponentId = 3003 })
		check(
			o1.counted and o2.counted and not o3.counted and o3.reason == Challenges.REASON_OPPONENT and o4.counted,
			`même adversaire : 2 matchs comptés, le 3e refusé (« {o3.text} »), un autre adversaire compte`
		)
		local bot = match({ seconds = 600, won = true, opponentId = 4004, ranked = false })
		check(not bot.counted and bot.reason == Challenges.REASON_UNRANKED, `match non classé (bot) : ne compte jamais (« {bot.text} »)`)
		local twice1 = match({ seconds = 300, opponentId = 5005, matchId = "studio-double" })
		local twice2 = match({ seconds = 300, opponentId = 6006, matchId = "studio-double" })
		check(twice1.counted and not twice2.counted and twice2.reason == Challenges.REASON_ALREADY, "le même match n'est jamais compté deux fois")

		-- « Récupérer » : la récompense exacte, une seule fois.
		local d0 = dbg:Invoke(player, "Data")
		setCoins(0)
		local expected = Challenges.rewardFor(Challenges.BY_ID.play2, d0.idle.highestWave, d0.idle.coinBonus)
		local ok1, message1 = claim("d1")
		local coins1 = dbg:Invoke(player, "Data").coins
		check(
			ok1 and coins1 == expected.coins and expected.coins > 0,
			`« Récupérer » (Joue 2 matchs) : {NumberFormat.short(coins1)} pièces (attendu {NumberFormat.short(expected.coins)} = {Challenges.DAILY_COIN_WAVES} vagues au record {d0.idle.highestWave}) « {message1} »`
		)
		local ok2, message2 = claim("d1")
		check(not ok2 and dbg:Invoke(player, "Data").coins == coins1, `2e « Récupérer » refusé (« {message2} »), pièces inchangées`)
		local okTodo, messageTodo = claim("d3")
		check(not okTodo and challengeState().daily[3].c == false, `défi pas terminé : refusé (« {messageTodo} »)`)
		local okOld, messageOld = claim("d2", s0.day - 1)
		check(not okOld and challengeState().daily[2].c == false, `mauvais jour : refusé (« {messageOld} »)`)
		local okBad = claim("zz")
		check(not okBad, "clé de défi inconnue : refusée")

		-- Lancers d'autel offerts (Gagne 1 match) : +10 lancers, le prix de l'autel ne bouge pas.
		local a0 = dbg:Invoke(player, "Data")
		local priceBefore = IdleConfig.towerSpinPrice(a0.idle.highestWave, a0.idle.towerSpinsBought)
		local okSpin, messageSpin, spinDetails = claim("d2")
		local a1 = dbg:Invoke(player, "Data")
		check(
			okSpin and spinDetails and spinDetails.altar and spinDetails.altar.count == Challenges.ALTAR_SPINS
				and altarItems(a1) - altarItems(a0) == Challenges.ALTAR_SPINS,
			`« Récupérer » (Gagne 1 match) : {altarItems(a1) - altarItems(a0)} tours / doublons de l'autel (attendu {Challenges.ALTAR_SPINS}) « {messageSpin} »`
		)
		check(
			a1.idle.towerSpinsBought == a0.idle.towerSpinsBought
				and player:GetAttribute("TowerSpinsBought") == a0.idle.towerSpinsBought
				and IdleConfig.towerSpinPrice(a1.idle.highestWave, a1.idle.towerSpinsBought) == priceBefore,
			`lancers offerts : compteur de l'autel inchangé ({a0.idle.towerSpinsBought} -> {a1.idle.towerSpinsBought}), prix du prochain lancer inchangé`
		)

		-- Défi de la semaine (Joue 10 matchs) : terminé avec de nouveaux adversaires, puis pièces + 1 lancer de forge.
		for i = 1, 4 do
			match({ seconds = 300, opponentId = 7000 + i })
		end
		local sw = challengeState()
		check(sw.weekly[1].p == 10 and sw.weekly[1].done, `défi de la semaine : {sw.weekly[1].p}/10 matchs, terminé`)
		setCoins(0)
		local f0 = dbg:Invoke(player, "Data")
		local forge0 = call("forgeState")
		local okWeek, messageWeek, weekDetails = claim("w1")
		local f1 = dbg:Invoke(player, "Data")
		local forge1 = call("forgeState")
		local expectedWeek = Challenges.rewardFor(Challenges.BY_ID.play10, f0.idle.highestWave, f0.idle.coinBonus)
		check(
			okWeek and f1.coins == expectedWeek.coins and #f1.idle.bonuses == #f0.idle.bonuses + 1,
			`« Récupérer » (semaine) : {NumberFormat.short(f1.coins)} pièces (attendu {NumberFormat.short(expectedWeek.coins)}) + 1 rune « {messageWeek} »`
		)
		check(
			forge1.bought == forge0.bought and forge1.price == forge0.price and player:GetAttribute("ForgeSpinsBought") == forge0.bought,
			`lancer de forge offert : compteur ({forge0.bought} -> {forge1.bought}) et prix de la forge inchangés`
		)
		if forge0.blocked == IdleConfig.FORGE_ALL_BEST then
			check(
				weekDetails and weekDetails.forge and weekDetails.forge.bonus == IdleConfig.bestRune().id,
				`forge bloquée (x100 dégâts et x2 vitesse sur toutes les tours) : le lancer offert donne la meilleure rune, comme un reçu Robux ({weekDetails and weekDetails.forge and weekDetails.forge.bonus})`
			)
		end
		local okWeek2 = claim("w1")
		check(not okWeek2, "2e « Récupérer » du défi de la semaine refusé")

		-- Nouveau jour (horloge + 24 h) : défis du jour, progression, récompenses et adversaires remis à zéro.
		local before = challengeState()
		dbg:Invoke(player, "ChallengeClock", Challenges.DAY_SECONDS)
		local day2 = challengeState()
		local fresh = true
		for _, entry in day2.daily do
			fresh = fresh and entry.p == 0 and not entry.c
		end
		check(
			day2.day == before.day + 1 and fresh and next(day2.opp) == nil and ids(day2.daily) == table.concat(Challenges.dailyPicks(day2.day), ","),
			`nouveau jour : nouveaux défis ({ids(day2.daily)}), progression et récompenses remises à zéro`
		)
		if day2.week == before.week then
			check(
				day2.weekly[1].c == true and day2.weekly[2].p == before.weekly[2].p,
				"nouveau jour de la même semaine : les défis de la semaine sont gardés"
			)
		else
			say("le jour suivant est un lundi : la semaine change aussi (vérifiée juste après)")
		end
		local again = match({ seconds = 300, opponentId = 2002 })
		check(again.counted, "nouveau jour : l'adversaire déjà affronté 2 fois compte de nouveau")

		-- Nouvelle semaine (le lundi 00:00 UTC qui suit la semaine du « nouveau jour ») : défis de la semaine
		-- remis à zéro.
		dbg:Invoke(player, "ChallengeClock", Challenges.weekEndsAt(day2.week) - os.time() + 60)
		local week2 = challengeState()
		check(
			week2.week == day2.week + 1 and week2.weekly[1].p == 0 and not week2.weekly[1].c and week2.weekly[2].p == 0
				and ids(week2.weekly) == table.concat(Challenges.weeklyPicks(week2.week), ","),
			`nouvelle semaine : nouveaux défis ({ids(week2.weekly)}), progression remise à zéro`
		)
		dbg:Invoke(player, "ChallengeClock", 0)
		local back = challengeState()
		check(back.day == Challenges.dayNumber(os.time()) and back.offset == 0, "horloge des défis remise à l'heure réelle")

		-- État publié pour l'interface (attribut ChallengeState, en JSON).
		local okJson, published = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("ChallengeState") or "")
		check(
			okJson and typeof(published) == "table" and published.day == back.day and #published.daily == Challenges.DAILY_COUNT
				and published.daily[1].key == "d1" and #published.weekly == Challenges.WEEKLY_COUNT and typeof(published.dayEndsAt) == "number",
			"état des défis publié pour l'interface (ChallengeState)"
		)

		-- Anciennes sauvegardes : sans défis -> valeurs par défaut ; défis abîmés -> nettoyés (sauvegardables).
		local migrated = dbg:Invoke(player, "ChallengeMigrate", { coins = 123, mmr = 1100, idle = { wave = 3, bestWave = 3, highestWave = 3 } })
		local mc = migrated and migrated.challenges
		check(
			mc ~= nil and mc.day == 0 and mc.week == 0 and #mc.daily == 0 and #mc.weekly == 0 and next(mc.opp) == nil and mc.last == "" and migrated.coins == 123,
			"ancienne sauvegarde sans défis : défis ajoutés avec les valeurs par défaut, pièces gardées"
		)
		local broken = dbg:Invoke(player, "ChallengeMigrate", {
			coins = 5,
			idle = {},
			challenges = {
				day = 0 / 0,
				week = "x",
				daily = { { id = "play2", p = math.huge, c = "oui" }, { id = "inconnu", p = 3 } },
				opp = { ["2002"] = 0 / 0, ["77"] = 1 },
				last = 12,
			},
		})
		local bc = broken and broken.challenges
		check(
			bc ~= nil and bc.day == 0 and bc.week == 0 and #bc.daily == 1 and bc.daily[1].p == 0 and bc.daily[1].c == false
				and bc.opp["77"] == 1 and bc.opp["2002"] == nil and bc.last == "" and allFinite(broken),
			"défis abîmés dans une sauvegarde : nettoyés (nombres finis, défis inconnus retirés)"
		)
		setCoins(0)
	end
	testChallenges()

	-- Retour à une vague normale pour la fin
	dbg:Invoke(player, "StartWave", 1)

	for _ = 1, 4 do
		task.wait(5)
		state()
	end
end

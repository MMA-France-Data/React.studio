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
		dbg:Invoke(player, "Coins", amount)
	end
	local function spin(count)
		local n = count or 1
		local d0 = dbg:Invoke(player, "Data")
		local record = d0.idle.highestWave
		local cost = IdleConfig.towerSpinCost(record, n)
		local result = dbg:Invoke(player, "Call", "spinTower", count)
		local d1 = dbg:Invoke(player, "Data")
		local paid = d0.coins - d1.coins
		check(
			result ~= nil and near(paid, cost),
			`x{n} au record {record} : payé {NumberFormat.short(paid)}, towerSpinCost = {NumberFormat.short(cost)}`
		)
		if not result then
			return nil, d0, d1
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
		return result, d0, d1
	end
	local function refusedSpin(count, label)
		local d0 = dbg:Invoke(player, "Data")
		local result = dbg:Invoke(player, "Call", "spinTower", count)
		local d1 = dbg:Invoke(player, "Data")
		check(
			result == nil and d1.coins == d0.coins and inventoryTotal(d1) == inventoryTotal(d0),
			`lancer refusé : {label} (pièces et tours inchangées)`
		)
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
	local cost10 = IdleConfig.towerSpinCost(5, 10)
	setCoins(cost10 - 1)
	refusedSpin(10, `pas assez de pièces ({cost10 - 1} pour un prix de {cost10})`)
	dbg:Invoke(player, "Coins", 1)
	local _, _, afterExact = spin(10)
	check(afterExact.coins == 0, `x10 payé avec exactement le prix : il reste {afterExact.coins} pièce(s)`)
	-- Sans nombre = 1 lancer
	setCoins(1e6)
	spin(nil)
	-- Palier 1 (record 5) : 0 % d'Épiques et de Légendaires, même en 60 lancers.
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
			setCoins(IdleConfig.towerSpinCost(bulk.minWave, bulk.count) * 10)
			refusedSpin(bulk.count, `x{bulk.count} au record {bulk.minWave - 1} (il faut la vague {bulk.minWave})`)
		end
	end
	dbg:Invoke(player, "Set", "highestWave", topRecord)
	dbg:Invoke(player, "Set", "wave", 1)
	check(IdleConfig.towerSpinTier(topRecord) == #IdleConfig.TOWER_SPIN_TIERS, `record {topRecord} : meilleur palier de chances`)
	for _, bulk in IdleConfig.TOWER_SPIN_BULKS do
		setCoins(IdleConfig.towerSpinCost(topRecord, bulk.count) * 3)
		local result = spin(bulk.count)
		if result and bulk.count >= 1000 then
			local counts = rarityCounts(result)
			check(
				counts.Epic > 0 and counts.Legendary > 0,
				`x{bulk.count} au record {topRecord} (vague en cours 1) : Épiques {NumberFormat.short(counts.Epic)}, Légendaires {NumberFormat.short(counts.Legendary)}`
			)
		end
		if result and bulk.count >= 100000 then
			-- Tirage statistique des gros lots : chaque rareté à 1 point de % près des chances affichées
			-- (l'écart normal est ~0,05 point sur un million de lancers).
			local odds = IdleConfig.TOWER_SPIN_TIERS[IdleConfig.towerSpinTier(topRecord)].odds
			local counts, parts, close = rarityCounts(result), {}, true
			for _, rarity in IdleConfig.RARITY_ORDER do
				local share = counts[rarity] / bulk.count * 100
				close = close and math.abs(share - (odds[rarity] or 0)) < 1
				table.insert(parts, `{rarity} {string.format("%.2f", share)} % (attendu {odds[rarity] or 0})`)
			end
			check(close, `x{NumberFormat.short(bulk.count)} : raretés conformes aux chances — {table.concat(parts, ", ")}`)
		end
	end
	-- Données toujours sauvegardables : doublons entiers et finis.
	d = dbg:Invoke(player, "Data")
	local clean = true
	for _, n in d.idle.towerDupes do
		if n ~= n or n == math.huge or n ~= math.floor(n) or n < 0 then
			clean = false
		end
	end
	check(clean and d.coins == d.coins and d.coins < math.huge, "doublons entiers et finis, pièces finies")

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

	-- Retour à une vague normale pour la fin
	dbg:Invoke(player, "StartWave", 1)

	for _ = 1, 4 do
		task.wait(5)
		state()
	end
end

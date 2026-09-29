-- Scénario de test côté serveur (match ranked en solo contre le bot), exécuté par le plugin AutoPlayTest.
-- Le joueur de test ne pose aucune tour (Client.luau ne fait que des captures) : son or doit valoir
-- exactement l'or de départ + le revenu de base x le numéro de vague. Écrit [PASS] / [FAIL] dans la sortie.
return function(log)
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local startedAt = os.clock()
	local testDuration = ReplicatedStorage.__AutoPlayTest.Value
	local function say(msg) log("Info", "[TEST] " .. msg) end
	local function check(ok, msg) log(ok and "Info" or "Error", (ok and "[PASS] " or "[FAIL] ") .. msg) end
	-- Attend que predicate() soit vrai (au plus timeout secondes).
	local function waitFor(predicate, timeout)
		local deadline = os.clock() + timeout
		while not predicate() do
			if os.clock() > deadline then
				return false
			end
			task.wait(0.1)
		end
		return true
	end

	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Challenges = require(Shared.Challenges)
	local Config = require(Shared.Config)
	local Enemies = require(Shared.Enemies)
	local C = Config.Match
	-- Outil de test du serveur de match (Match/init.luau, Studio seulement) : défis classés.
	local dbg = game:GetService("ServerStorage"):WaitForChild("StudioDebug", 30)

	local matchState = ReplicatedStorage:WaitForChild("MatchState", 30)
	assert(matchState, "MatchState introuvable : la place n'est pas en mode match")
	check(ReplicatedStorage:GetAttribute("ServerMode") == "Match", `serveur en mode match (obtenu {ReplicatedStorage:GetAttribute("ServerMode")})`)

	-- Envois retirés : plus de remote SendEnemies ni de module Sends ; les remotes du match sont là.
	local remotes = ReplicatedStorage:WaitForChild("Remotes", 30)
	local missing = {}
	for _, name in { "PlaceTower", "UpgradeTower", "SellTower", "MatchResult", "TowerFired" } do
		if not remotes:FindFirstChild(name) then
			table.insert(missing, name)
		end
	end
	check(#missing == 0, `remotes du match présents (manquants : {table.concat(missing, " ")})`)
	check(remotes:FindFirstChild("SendEnemies") == nil, "pas de remote SendEnemies (envois retirés)")
	check(Shared:FindFirstChild("Sends") == nil, "pas de module Shared.Sends")

	-- Ennemis apparus sur chaque terrain, par type : spawned[terrain][type] = nombre.
	local spawned = { {}, {} }
	workspace:WaitForChild("Enemies", 30).ChildAdded:Connect(function(part)
		local counts = spawned[part:GetAttribute("Lane")]
		if counts then
			counts[part.Name] = (counts[part.Name] or 0) + 1
		end
	end)

	local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
	local playing = waitFor(function()
		return matchState:GetAttribute("Phase") == "Playing"
	end, 60)
	check(playing, `la partie commence (phase {matchState:GetAttribute("Phase")})`)
	if not playing then
		return
	end

	local function lane(index, key)
		return matchState:GetAttribute(`Lane{index}{key}`)
	end
	local me = player:GetAttribute("Lane")
	local bot = if me == 1 then 2 else 1
	check(me == 1 or me == 2, `joueur de test sur un terrain (Lane = {me})`)
	check(
		matchState:GetAttribute("Ranked") == false and lane(bot, "Name") == "Bot",
		`l'autre terrain est joué par le bot, match non classé (Ranked = {matchState:GetAttribute("Ranked")}, nom = {lane(bot, "Name")})`
	)

	local function towerCount(index)
		local count = 0
		for _, model in workspace.Towers:GetChildren() do
			if model:GetAttribute("Lane") == index then
				count += 1
			end
		end
		return count
	end
	-- Ennemis des vagues 1 à w, par type (Enemies.buildWave : la même vague pour les deux terrains).
	local function expectedUpTo(w)
		local counts = {}
		for wave = 1, w do
			for _, item in Enemies.buildWave(wave) do
				counts[item.enemy] = (counts[item.enemy] or 0) + 1
			end
		end
		return counts
	end
	local function describe(counts)
		local parts = {}
		for _, enemyType in Enemies.ORDER do
			if counts[enemyType] then
				table.insert(parts, `{enemyType}={counts[enemyType]}`)
			end
		end
		return table.concat(parts, " ")
	end
	local function sameCounts(a, b)
		for _, enemyType in Enemies.ORDER do
			if (a[enemyType] or 0) ~= (b[enemyType] or 0) then
				return false
			end
		end
		return true
	end

	-- 5 vagues (~2 min 10 de test) : jusqu'à la vague 8, une vague finit d'apparaître avant la suivante.
	local CHECK_WAVES = 5
	for wave = 1, CHECK_WAVES do
		local started = waitFor(function()
			return (matchState:GetAttribute("Wave") or 0) >= wave
		end, 40)
		if not started then
			check(false, `la vague {wave} commence (phase {matchState:GetAttribute("Phase")}, vague {matchState:GetAttribute("Wave")})`)
			return
		end
		task.wait(0.5) -- laisse le serveur publier l'or de la nouvelle vague

		local gold = lane(me, "Gold")
		local expectedGold = C.STARTING_GOLD + C.BASE_INCOME * wave
		if towerCount(me) == 0 then
			check(gold == expectedGold, `vague {wave} : or du joueur = {C.STARTING_GOLD} + {C.BASE_INCOME} x {wave} = {expectedGold} (obtenu {gold})`)
		else
			say(`vague {wave} : le joueur a posé des tours, vérification exacte de l'or sautée`)
		end
		check(
			lane(me, "Income") == C.BASE_INCOME and lane(bot, "Income") == C.BASE_INCOME,
			`vague {wave} : revenu de {C.BASE_INCOME}/vague pour les deux terrains (joueur {lane(me, "Income")}, bot {lane(bot, "Income")})`
		)

		-- Juste avant la vague suivante, cette vague est entièrement apparue : chaque terrain a reçu
		-- exactement les vagues 1 à `wave`, rien de plus.
		local nextWaveAt = matchState:GetAttribute("NextWaveAt")
		waitFor(function()
			return workspace:GetServerTimeNow() >= nextWaveAt - 1
		end, 30)
		local expected = expectedUpTo(wave)
		check(
			sameCounts(spawned[me], expected) and sameCounts(spawned[bot], expected),
			`vagues 1 à {wave} : mêmes ennemis sur les deux terrains (attendu {describe(expected)} ; joueur {describe(spawned[me])} ; bot {describe(spawned[bot])})`
		)
		say(`vague {wave} : bot {towerCount(bot)} tours, or {lane(bot, "Gold")}, base {lane(bot, "Health")} ; joueur : base {lane(me, "Health")}`)
	end
	check(towerCount(bot) > 0, `le bot pose des tours ({towerCount(bot)} tours)`)
	check(matchState:GetAttribute("Phase") == "Playing", `la partie continue après {CHECK_WAVES} vagues (phase {matchState:GetAttribute("Phase")})`)

	-- Défis classés : chiffres comptés sur chaque terrain pendant le match (Game:challengeStats), lus à la fin
	-- du match. Le bot ne vend jamais : tours posées = ses tours, améliorations = niveaux en plus.
	local stats = dbg and dbg:Invoke(player, "ChallengeStats")
	if stats then
		local botTowers, botTypes, botUpgrades, typeCount = 0, {}, 0, 0
		for _, model in workspace.Towers:GetChildren() do
			if model:GetAttribute("Lane") == bot then
				botTowers += 1
				botUpgrades += (model:GetAttribute("Level") or 1) - 1
				local towerType = model:GetAttribute("TowerType")
				if towerType and not botTypes[towerType] then
					botTypes[towerType] = true
					typeCount += 1
				end
			end
		end
		local botStats, myStats = stats.lanes[bot], stats.lanes[me]
		check(
			botStats.towersPlaced == botTowers and botStats.towerTypes == typeCount and botStats.upgrades == botUpgrades,
			`défis : terrain du bot compté ({botStats.towersPlaced} tours posées, {botStats.towerTypes} types, {botStats.upgrades} améliorations ; attendu {botTowers}, {typeCount}, {botUpgrades})`
		)
		check(
			myStats.towersPlaced == 0 and myStats.upgrades == 0 and myStats.towerTypes == 0 and stats.seconds > 60 and stats.seconds < C.MAX_DURATION,
			`défis : terrain du joueur sans tour (0 posée), durée de la partie {math.floor(stats.seconds)} s`
		)
	else
		check(false, "défis : StudioDebug du serveur de match introuvable")
	end

	-- Fin du match : sans tour, la base du joueur tombe pendant la vague 8, ~2 min 57 après le début de
	-- la partie (~3 min 15 après le début du test). Vérifiée seulement si le test dure assez (-Seconds 260).
	local ended = waitFor(function()
		return matchState:GetAttribute("Phase") == "Ended"
	end, math.max(0, testDuration - (os.clock() - startedAt) - 4))
	if ended then
		check(
			matchState:GetAttribute("EndReason") == "BaseDestroyed" and matchState:GetAttribute("Winner") == bot and lane(me, "Health") == 0,
			`fin du match : base du joueur détruite, le bot gagne (raison {matchState:GetAttribute("EndReason")}, gagnant {matchState:GetAttribute("Winner")}, base du joueur {lane(me, "Health")}, vague {matchState:GetAttribute("Wave")})`
		)
		-- Défis classés : un match contre le bot (non classé) ne compte jamais, et le joueur sait pourquoi.
		if dbg then
			local results = dbg:Invoke(player, "LastChallenges")
			local mine = results and results["lane" .. me]
			check(
				mine ~= nil and mine.counted == false and mine.reason == Challenges.REASON_UNRANKED,
				`défis : match contre le bot pas compté (« {mine and mine.text} »)`
			)
			local challengeData = dbg:Invoke(player, "ChallengeData")
			local progressed = 0
			for _, list in { challengeData and challengeData.daily or {}, challengeData and challengeData.weekly or {} } do
				for _, slot in list do
					progressed += slot.p
				end
			end
			check(
				challengeData ~= nil and progressed == 0 and next(challengeData.opp) == nil,
				"défis : aucune progression enregistrée après le match contre le bot"
			)
		end
	else
		say(`match pas fini à la vague {matchState:GetAttribute("Wave")} (base du joueur {lane(me, "Health")}) : relance avec -Seconds 260 -Timeout 420 pour vérifier aussi la fin`)
	end
end

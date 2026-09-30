-- Défis classés, côté map principale (règles, listes de défis et récompenses : Shared/Challenges.luau).
-- La progression est comptée par le serveur de match à la fin de chaque match classé (Match/init.luau) ; ici :
--   * l'état des défis du joueur est publié dans ses attributs (lus par client/ChallengeUI.luau) :
--       ChallengeState  = JSON de Challenges.clientState (jour, semaine, défis, progression, fins de période) ;
--       ChallengesReady = nombre de récompenses à récupérer (pastille du bouton « DÉFIS ») ;
--   * bouton « Récupérer » (remote ChallengeAction) : le serveur revérifie tout (même jour / même semaine, défi
--     terminé, pas encore récupéré), marque la récompense comme récupérée PUIS la donne : jamais deux fois ;
--   * nouveau jour (00:00 UTC) ou nouvelle semaine (lundi 00:00 UTC) pendant que le joueur est là : les
--     nouveaux défis sont publiés tout seuls (au plus CHECK_INTERVAL secondes après).
-- Les récompenses ne servent qu'au mode solo : rien ne change en ranked (mêmes tours, même or pour tous).
-- Classé fermé (Config.RANKED_OPEN = false, Shared/RankedGate.luau) : les défis se font en match classé, donc rien
-- n'est récupérable (« Récupérer » refusé), pas de message à l'arrivée, et le client cache le bouton « ⚔ DÉFIS ».
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Challenges = require(Shared.Challenges)
local RankedGate = require(Shared.RankedGate)
local Remotes = require(Shared.Remotes)
local PlayerData = require(script.Parent.Parent.PlayerData)

local ChallengeRewards = {}

-- Secondes entre deux clics « Récupérer » d'un même joueur (anti-spam ; un 2e clic serait refusé de toute façon).
local CLAIM_COOLDOWN = 0.5
-- Toutes les CHECK_INTERVAL secondes : nouveau jour ou nouvelle semaine ? (nouveaux défis publiés).
local CHECK_INTERVAL = 10
-- À l'arrivée, délai avant le message « récompenses à récupérer » (l'interface du client a le temps de démarrer).
local ANNOUNCE_DELAY = 5

-- Décalage de l'horloge des défis, en secondes : Studio seulement (StudioDebug « ChallengeClock »), 0 sinon.
local clockOffset = 0
local lastClaim = {} -- [Player] = os.clock() du dernier clic
-- Parcelle du joueur (PlotGame), donnée par Hub/init.luau : les lancers offerts passent par elle.
local getPlotGame: (Player) -> any = function()
	return nil
end
local debugMatches = 0 -- matchs simulés dans Studio (identifiants différents)

-- Heure des défis (os.time() du serveur, en UTC ; décalée seulement par les tests Studio).
function ChallengeRewards.now(): number
	return os.time() + clockOffset
end

-- Met les défis du joueur à l'heure (nouveau jour / nouvelle semaine) et publie leur état dans ses attributs.
function ChallengeRewards.publish(player: Player, data: any?)
	data = data or PlayerData.get(player)
	if not data or not player.Parent then
		return
	end
	local state = Challenges.sync(data, ChallengeRewards.now())
	player:SetAttribute("ChallengeState", HttpService:JSONEncode(Challenges.clientState(state, clockOffset)))
	player:SetAttribute("ChallengesReady", Challenges.readyCount(state))
end

-- Bouton « Récupérer » : key = "d1".."d3" ou "w1", "w2", period = numéro du jour (ou de la semaine) affiché par
-- le client. Renvoie (réussi, message pour le joueur, détails pour les tests : { reward, altar, forge }).
-- Rien n'attend (pas de yield) entre la vérification et le marquage « récupérée » : jamais deux fois.
function ChallengeRewards.claim(player: Player, key: any, period: any): (boolean, string, any?)
	if not RankedGate.isOpen() then
		return false, RankedGate.SOON_TEXT -- classé fermé : rien à récupérer
	end
	local data = PlayerData.get(player)
	if not data then
		return false, "Tes données sont encore en cours de chargement"
	end
	local slot, def, message = Challenges.findClaimable(data, key, period, ChallengeRewards.now())
	if not slot then
		ChallengeRewards.publish(player, data) -- le client se remet à jour (ex. de nouveaux défis sont arrivés)
		return false, message or "Défi inconnu"
	end
	local reward = Challenges.rewardFor(def, data.idle.highestWave, data.idle.coinBonus)
	-- Les lancers offerts passent par la parcelle (tirage, inventaire, résultat affiché par l'autel / la forge).
	local plotGame = getPlotGame(player)
	if (reward.altarSpins > 0 or reward.forgeSpins > 0) and not plotGame then
		return false, "Ton fief se prépare : réessaie dans un instant"
	end

	slot.c = true -- d'abord marquée récupérée : un 2e clic ne donne plus rien
	-- Pièces : jamais au-delà de Challenges.MAX_COINS au total (toujours sauvegardable).
	local room = Challenges.MAX_COINS - data.coins
	local coins = if room == room and room > 0 then math.min(reward.coins, room) else 0
	if coins > 0 then
		PlayerData.addCoins(player, coins)
	end
	local details = { reward = reward, coins = coins }
	if reward.altarSpins > 0 then
		-- Gratuits : le compteur des lancers achetés (prix de l'autel) ne bouge pas.
		details.altar = plotGame:grantFreeTowerSpins(reward.altarSpins)
	end
	for _ = 1, reward.forgeSpins do
		-- Comme un lancer Robux : ne compte pas dans le prix des lancers en pièces.
		details.forge = plotGame:grantBonusSpin("Challenge")
	end
	ChallengeRewards.publish(player, data)
	task.spawn(PlayerData.save, player)
	return true, `Défi réussi ! {Challenges.rewardToast(reward)}`, details
end

-- À l'arrivée sur la map principale (données chargées) : publie les défis et annonce les récompenses qui
-- attendent (par exemple celles gagnées pendant le match classé d'où le joueur revient).
function ChallengeRewards.onPlayerLoaded(player: Player, data)
	ChallengeRewards.publish(player, data)
	local ready = Challenges.readyCount(data.challenges)
	if ready > 0 and RankedGate.isOpen() then
		task.delay(ANNOUNCE_DELAY, function()
			if player.Parent then
				local text = if ready == 1 then "1 récompense à récupérer" else `{ready} récompenses à récupérer`
				Remotes.get("Notify"):FireClient(player, `Défis classés : {text} (bouton ⚔ DÉFIS)`, "Success")
			end
		end)
	end
end

----------------------------------------------------------------------
-- Outils de test (Studio seulement : ServerStorage.StudioDebug, voir Hub/init.luau)
----------------------------------------------------------------------

-- Décale l'horloge des défis de `seconds` (86400 = demain, 7 * 86400 = la semaine prochaine, 0 = heure réelle)
-- et republie les défis de tous les joueurs. Renvoie { day, week, offset }.
function ChallengeRewards.debugSetClock(seconds: any)
	if not RunService:IsStudio() then
		return nil
	end
	clockOffset = if typeof(seconds) == "number" and seconds == seconds and math.abs(seconds) < 1e9 then math.floor(seconds) else 0
	for _, player in Players:GetPlayers() do
		ChallengeRewards.publish(player)
	end
	local now = ChallengeRewards.now()
	return { day = Challenges.dayNumber(now), week = Challenges.weekNumber(now), offset = clockOffset }
end

-- Un match classé terminé, compté EXACTEMENT comme sur le serveur de match (Challenges.recordMatch).
-- args (tout est facultatif) : { seconds = 240, won = false, opponentId = 1, towersPlaced = 0, upgrades = 0,
-- towerTypes = 0, ranked = true, matchId = unique }. Renvoie { counted, reason, completed, text }.
function ChallengeRewards.debugMatch(player: Player, data, args: any)
	args = if typeof(args) == "table" then args else {}
	debugMatches += 1
	local result = Challenges.recordMatch(data, {
		ranked = if args.ranked == nil then true else args.ranked,
		matchId = args.matchId or `studio-{debugMatches}`,
		seconds = args.seconds or 240,
		won = args.won == true,
		opponentId = args.opponentId or 1,
		towersPlaced = args.towersPlaced or 0,
		upgrades = args.upgrades or 0,
		towerTypes = args.towerTypes or 0,
	}, ChallengeRewards.now())
	ChallengeRewards.publish(player, data)
	return result
end

-- Remplace les défis en cours par ceux-là (ids de Challenges.DAILY / WEEKLY, progression à 0), pour tester
-- des défis connus. Ils restent jusqu'au prochain jour / la prochaine semaine. Renvoie l'état (debugState).
function ChallengeRewards.debugForce(player: Player, data, dailyIds: any, weeklyIds: any)
	local state = Challenges.sync(data, ChallengeRewards.now())
	local function slots(ids, byId, count)
		if typeof(ids) ~= "table" or #ids ~= count then
			return nil
		end
		local list = {}
		for _, id in ids do
			if not byId[id] then
				return nil
			end
			table.insert(list, { id = id, p = 0, c = false })
		end
		return list
	end
	state.daily = slots(dailyIds, Challenges.DAILY_BY_ID, Challenges.DAILY_COUNT) or state.daily
	state.weekly = slots(weeklyIds, Challenges.WEEKLY_BY_ID, Challenges.WEEKLY_COUNT) or state.weekly
	ChallengeRewards.publish(player, data)
	return ChallengeRewards.debugState(player, data)
end

-- État complet (tests) : { day, week, offset, ready, opp, last, daily/weekly = { { key, id, p, c, target, done,
-- reward = { coins, altarSpins, forgeSpins } } } }.
function ChallengeRewards.debugState(_player: Player, data)
	local state = Challenges.sync(data, ChallengeRewards.now())
	local function describe(list, prefix)
		local out = {}
		for index, slot in list do
			local def = Challenges.BY_ID[slot.id]
			table.insert(out, {
				key = prefix .. index,
				id = slot.id,
				p = slot.p,
				c = slot.c,
				target = def.target,
				done = slot.p >= def.target,
				reward = Challenges.rewardFor(def, data.idle.highestWave, data.idle.coinBonus),
			})
		end
		return out
	end
	return {
		day = state.day,
		week = state.week,
		offset = clockOffset,
		ready = Challenges.readyCount(state),
		opp = table.clone(state.opp),
		last = state.last,
		daily = describe(state.daily, "d"),
		weekly = describe(state.weekly, "w"),
	}
end

----------------------------------------------------------------------
-- Démarrage (Hub/init.luau)
----------------------------------------------------------------------

-- plotGameOf(player) = sa parcelle (PlotGame) ou nil.
function ChallengeRewards.start(plotGameOf: (Player) -> any)
	getPlotGame = plotGameOf
	Players.PlayerRemoving:Connect(function(player)
		lastClaim[player] = nil
	end)

	Remotes.get("ChallengeAction").OnServerEvent:Connect(function(player, action, key, period)
		local now = os.clock()
		if now - (lastClaim[player] or 0) < CLAIM_COOLDOWN then
			return
		end
		lastClaim[player] = now
		if action == "Claim" then
			local ok, message = ChallengeRewards.claim(player, key, period)
			Remotes.get("Notify"):FireClient(player, message, if ok then "Success" else "Error")
		end
	end)

	-- Nouveau jour ou nouvelle semaine pendant que les joueurs sont là : nouveaux défis publiés.
	task.spawn(function()
		while true do
			task.wait(CHECK_INTERVAL)
			local now = ChallengeRewards.now()
			local day, week = Challenges.dayNumber(now), Challenges.weekNumber(now)
			for _, player in Players:GetPlayers() do
				local data = PlayerData.get(player)
				local state = data and data.challenges
				if typeof(state) == "table" and (state.day ~= day or state.week ~= week) then
					ChallengeRewards.publish(player, data)
				end
			end
		end
	end)
end

return ChallengeRewards

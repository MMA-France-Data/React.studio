-- Map principale (serveur public) : 6 parcelles, cercle ranked au centre, classement ranked et classement solo.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local IdleConfig = require(Shared.IdleConfig)
local NumberFormat = require(Shared.NumberFormat)
local PlotLayout = require(Shared.PlotLayout)
local RankedGate = require(Shared.RankedGate)
local Ranks = require(Shared.Ranks)
local Remotes = require(Shared.Remotes)
local Leaderboard = require(script.Parent.Leaderboard)
local Matchmaking = require(script.Parent.Matchmaking)
local Monetization = require(script.Parent.Monetization)
local PlayerData = require(script.Parent.PlayerData)
local SoloLeaderboard = require(script.Parent.SoloLeaderboard)
local PlotGame = require(script.PlotGame)
local ChallengeRewards = require(script.ChallengeRewards)
local HubMap = require(script.HubMap)
local PlotInterest = require(script.PlotInterest)
local Plots = require(script.Plots)
local SoloBoard = require(script.SoloBoard)
local StudioScenes = require(script.StudioScenes)
local AdminGifts = require(script.AdminGifts)
local Tutorial = require(script.Tutorial)

local Hub = {}

local games = {} -- [Player] = PlotGame

----------------------------------------------------------------------
-- Passes de jeu (possession : Monetization.luau). Mode solo uniquement.
----------------------------------------------------------------------

-- Applique les passes du joueur à sa parcelle et publie SpeedX2Enabled (vrai = x2 en marche :
-- pass Vitesse x2 possédé ET interrupteur allumé, data.idle.speedX2, allumé par défaut).
-- Pass Pièces x2 : pièces des ennemis tués doublées (PlotGame:setCoinMultiplier) ; les gains d'absence
-- le sont dans takeAbsenceGains.
local function refreshPasses(player: Player)
	local data = PlayerData.get(player)
	local speedOn = Monetization.ownsPass(player, "SpeedX2") and data ~= nil and data.idle.speedX2 ~= false
	if player.Parent then
		player:SetAttribute("SpeedX2Enabled", speedOn)
	end
	local plotGame = games[player]
	if plotGame then
		plotGame:setAutoCollect(Monetization.ownsPass(player, "AutoCollect"))
		plotGame:setSimSpeed(if speedOn then IdleConfig.SPEED_PASS_FACTOR else 1)
		plotGame:setCoinMultiplier(if Monetization.ownsPass(player, "CoinsX2") then PlotGame.COINS_PASS_FACTOR else 1)
	end
end

-- Bouton x2 du propriétaire du pass : allume / éteint (choix sauvegardé). Renvoie le nouvel état, nil si refusé.
local function toggleSpeed(player: Player): boolean?
	local data = PlayerData.get(player)
	if not data then
		return nil
	end
	if not Monetization.ownsPass(player, "SpeedX2") then
		Remotes.get("Notify"):FireClient(player, "Il te faut le pass Vitesse x2 (bouton « Boutique »)", "Error")
		return nil
	end
	data.idle.speedX2 = data.idle.speedX2 == false -- vrai par défaut : le premier clic l'éteint
	refreshPasses(player)
	local message = if data.idle.speedX2 then "Vitesse x2 allumée" else "Vitesse normale"
	Remotes.get("Notify"):FireClient(player, message, "Info")
	return data.idle.speedX2
end

local function startPlotGame(player: Player, data)
	if games[player] then
		return
	end
	local plotIndex = Plots.get(player)
	if not plotIndex or not player.Parent then
		return
	end
	games[player] = PlotGame.new(Plots.plot(plotIndex), player, data)
	refreshPasses(player)
end

----------------------------------------------------------------------
-- Gains d'absence (formules et réglages : IdleConfig, « Gains d'absence »)
----------------------------------------------------------------------
-- Écart toléré entre les horloges (os.time()) de deux serveurs Roblox, en secondes.
local CLOCK_TOLERANCE = 120
local lastAbsence = {} -- [Player] = dernier résumé calculé (lu par les tests Studio)

-- Heure valable (nombre fini, après 1970, pas dans le futur), sinon nil : une valeur abîmée ne donne rien.
local function validTime(value: any, now: number): number?
	if typeof(value) ~= "number" or value ~= value or value <= 0 or value > now + CLOCK_TOLERANCE then
		return nil
	end
	return value
end

-- Jour UTC de cette heure, ex. 20260929 : le compteur du plafond repart à 0 chaque jour à 00:00 UTC.
local function utcDay(time: number): number
	local date = os.date("!*t", time)
	return date.year * 10000 + date.month * 100 + date.day
end

-- Petit délai avant le message « Pendant ton absence » : l'interface du client a le temps de démarrer.
local ANNOUNCE_DELAY = 2
-- À l'arrivée, attente maximale (secondes) de la réponse de Roblox pour le pass Pièces x2 (3 essais en cas de panne).
local COINS_PASS_WAIT = 30

-- Pass Pièces x2 : double les montants du résumé et verse ce qui manque (les pièces x1 sont déjà versées).
-- Une seule fois par résumé. Le plafond du jour reste compté en pièces x1 (idle.offlineGainedToday) :
-- avec le pass, on reçoit donc aussi 2 fois le plafond.
local function doubleAbsenceGains(player: Player, result)
	if result.coinFactor ~= 1 or result.amount <= 0 or not Monetization.ownsPass(player, "CoinsX2") then
		return
	end
	local factor = PlotGame.COINS_PASS_FACTOR
	PlayerData.addCoins(player, result.amount * (factor - 1))
	result.coinFactor = factor
	result.offlineAmount *= factor
	result.matchAmount *= factor
	result.amount *= factor
end

-- Journal du serveur et message au client (sauf silent) après `delay` secondes.
local function announceAbsenceGains(player: Player, result, silent: boolean?, delay: number)
	if result.amount > 0 then
		local passText = if result.coinFactor > 1 then ", pass Pièces x" .. tostring(result.coinFactor) else ""
		print(
			`[Hub] Gains d'absence de {player.Name} : +{NumberFormat.short(result.amount)} (hors ligne {math.floor(result.offlineSeconds)} s`
				.. ` +{NumberFormat.short(result.offlineAmount)}{if result.capped then ", plafond du jour" else ""},`
				.. ` match {math.floor(result.matchSeconds)} s +{NumberFormat.short(result.matchAmount)}{passText})`
		)
	end
	if not silent and (result.amount > 0 or result.capped) then
		task.delay(delay, function()
			if player.Parent then
				Remotes.get("OfflineGains"):FireClient(player, result)
			end
		end)
	end
end

-- Verse les gains d'absence du joueur qui arrive sur la map principale (avant toute sauvegarde) :
--   match ranked : de idle.matchDepartureAt (noté par Matchmaking avant la téléportation) à idle.lastSeenAt
--     (dernière sauvegarde, faite par le serveur de match à la fin) : revenu normal, hors plafond,
--     au plus Config.Match.MAX_DURATION + IdleConfig.ABSENCE_MATCH_EXTRA_SECONDS ;
--   hors ligne : de idle.lastSeenAt à maintenant (au plus IdleConfig.OFFLINE_MAX_SECONDS) :
--     revenu normal x IdleConfig.OFFLINE_RATE, dans la limite du plafond du jour (IdleConfig.offlineDailyCap).
-- Les deux heures sont consommées (lastSeenAt = maintenant, matchDepartureAt = 0) : jamais payé deux fois.
-- Première visite (lastSeenAt = 0) ou heure abîmée : rien. `now` = os.time() (remplacé dans les tests
-- Studio), silent = pas de message au client. Renvoie le résumé (voir Remotes.luau, OfflineGains).
-- Pass Pièces x2 : tout le résumé est doublé (doubleAbsenceGains). Juste à l'arrivée, Roblox n'a parfois pas
-- encore dit si le joueur possède le pass : les pièces x1 sont versées tout de suite, le reste (et le
-- message) dès que la réponse arrive (au plus COINS_PASS_WAIT secondes).
local function takeAbsenceGains(player: Player, data, now: number, silent: boolean?)
	local idle = data.idle
	local lastSeen = validTime(idle.lastSeenAt, now)
	local departure = validTime(idle.matchDepartureAt, now)
	idle.lastSeenAt = now
	idle.matchDepartureAt = 0

	local result = {
		amount = 0,
		seconds = 0,
		kind = "Offline",
		capped = false,
		offlineAmount = 0,
		offlineSeconds = 0,
		matchAmount = 0,
		matchSeconds = 0,
		coinFactor = 1, -- 2 = montants doublés par le pass Pièces x2
	}
	lastAbsence[player] = result
	if not lastSeen then
		return result
	end
	local rate = IdleConfig.normalCoinRate(idle.bestWave, idle.coinBonus)

	-- Temps passé en match ranked : revenu normal, ne compte pas dans le plafond du jour.
	if departure and departure <= lastSeen then
		local maxSeconds = Config.Match.MAX_DURATION + IdleConfig.ABSENCE_MATCH_EXTRA_SECONDS
		result.kind = "Match"
		result.matchSeconds = math.min(lastSeen - departure, maxSeconds)
		result.matchAmount = math.floor(rate * result.matchSeconds)
	end

	-- Temps hors ligne : revenu réduit, plafonné par jour UTC.
	local away = math.min(now - lastSeen, IdleConfig.OFFLINE_MAX_SECONDS)
	if away > 0 then
		local day = utcDay(now)
		local gainedToday = idle.offlineGainedToday
		if idle.offlineDay ~= day or typeof(gainedToday) ~= "number" or not (gainedToday >= 0 and gainedToday < math.huge) then
			gainedToday = 0 -- nouveau jour (ou compteur abîmé)
		end
		local room = math.max(0, IdleConfig.offlineDailyCap(idle.bestWave, idle.coinBonus) - gainedToday)
		local raw = math.floor(rate * IdleConfig.OFFLINE_RATE * away)
		result.offlineSeconds = away
		result.offlineAmount = math.min(raw, room)
		result.capped = raw > room
		idle.offlineDay = day
		idle.offlineGainedToday = gainedToday + result.offlineAmount
	end

	result.amount = result.offlineAmount + result.matchAmount
	result.seconds = result.offlineSeconds + result.matchSeconds
	-- Pièces x1 versées tout de suite : rien n'est perdu si le joueur repart aussitôt.
	if result.amount > 0 then
		PlayerData.addCoins(player, result.amount)
	end
	if Monetization.passKnown(player, "CoinsX2") then
		doubleAbsenceGains(player, result)
		announceAbsenceGains(player, result, silent, ANNOUNCE_DELAY)
	else
		task.spawn(function()
			local started = os.clock()
			Monetization.waitForPass(player, "CoinsX2", COINS_PASS_WAIT)
			doubleAbsenceGains(player, result)
			announceAbsenceGains(player, result, silent, math.max(0, ANNOUNCE_DELAY - (os.clock() - started)))
		end)
	end
	return result
end

----------------------------------------------------------------------
-- Qui reçoit les ennemis et les tirs de chaque parcelle (règle et réglages : Hub/PlotInterest.luau) :
-- son propriétaire toujours, les autres joueurs seulement quand ils s'en approchent.
----------------------------------------------------------------------
local interest = {
	near = {}, -- mémoire de PlotInterest.compute : [Player] = { [plotIndex] = true }
	viewers = {}, -- [plotIndex] = joueurs qui reçoivent cette parcelle (propriétaire compris)
	positions = {}, -- tests Studio : [Player] = position utilisée à la place de son personnage
	clears = {}, -- tests Studio : [Player] = nombre de paquets « Clear » reçus
}
for plotIndex = 1, PlotLayout.COUNT do
	interest.viewers[plotIndex] = {}
end
local EMPTY_PACKET = buffer.create(0)

-- Position du personnage du joueur (nil = pas de personnage).
local function characterPosition(player: Player): Vector3?
	local override = interest.positions[player]
	if override then
		return override
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.Position else nil
end

-- Recalcule qui reçoit chaque parcelle (quelques fois par seconde, pas à chaque image). Un joueur qui vient
-- d'arrêter de recevoir une parcelle reçoit (lui seul) un paquet PlotSync « Clear » : son client efface tout
-- de suite ce qu'il en affichait (ennemis, zones de feu, rayons, corps). À son retour, les paquets suivants
-- redonnent tout (chaque paquet PlotSync contient tous les ennemis de la parcelle).
local function refreshInterest(syncRemote)
	local viewers = {}
	for _, player in Players:GetPlayers() do
		table.insert(viewers, { key = player, position = characterPosition(player), plot = Plots.get(player) })
	end
	local recipients, leaving = PlotInterest.compute(viewers, interest.near)
	interest.viewers = recipients
	for _, gone in leaving do
		local player = gone.key
		if player.Parent then
			syncRemote:FireClient(player, gone.plotIndex, EMPTY_PACKET, 0, "Clear")
			interest.clears[player] = (interest.clears[player] or 0) + 1
		end
	end
end

-- Envoie un paquet d'une parcelle à son propriétaire (toujours, même loin d'elle) et aux joueurs qui s'en
-- approchent (liste de refreshInterest).
local function sendToViewers(remote, plotGame, packet: buffer, count: number)
	local owner = plotGame.player
	if owner.Parent then
		remote:FireClient(owner, plotGame.index, packet, count)
	end
	for _, player in interest.viewers[plotGame.index] do
		if player ~= owner and player.Parent then
			remote:FireClient(player, plotGame.index, packet, count)
		end
	end
end

-- Boucle du mode infini : simulation à chaque frame, envois réseau quelques fois par seconde.
local function runPlotGames()
	local syncRemote = Remotes.get("PlotSync")
	local shotsRemote = Remotes.get("PlotShots")
	local syncTimer, shotsTimer, collectTimer = 0, 0, 0
	local interestTimer = PlotInterest.REFRESH_INTERVAL -- premier calcul tout de suite
	Players.PlayerRemoving:Connect(function(player)
		interest.positions[player] = nil
		interest.clears[player] = nil
	end)

	RunService.Heartbeat:Connect(function(dt)
		for _, plotGame in games do
			plotGame:step(dt)
		end

		interestTimer += dt
		if interestTimer >= PlotInterest.REFRESH_INTERVAL then
			interestTimer = 0
			refreshInterest(syncRemote)
		end

		syncTimer += dt
		if syncTimer >= 1 / IdleConfig.SYNC_RATE then
			syncTimer = 0
			for _, plotGame in games do
				local packet, count = plotGame:buildSyncPacket()
				if packet then
					sendToViewers(syncRemote, plotGame, packet, count)
				end
			end
		end

		shotsTimer += dt
		if shotsTimer >= 1 / IdleConfig.SHOTS_RATE then
			shotsTimer = 0
			for _, plotGame in games do
				local packet, count = plotGame:takeShotsPacket()
				if packet then
					sendToViewers(shotsRemote, plotGame, packet, count)
				end
			end
		end

		collectTimer += dt
		if collectTimer >= 0.2 then
			collectTimer = 0
			for _, plotGame in games do
				plotGame:collectDrops()
			end
		end
	end)
end

local function buildBoardGui(board: BasePart)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back -- face tournée vers le cercle ranked (+Z)
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = board

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0.1, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 215, 90)
	title.Text = `CLASSEMENT RANKED — SAISON {Config.SEASON}`
	title.Parent = gui

	local rows = {}
	local count = Config.Ranked.LEADERBOARD_SIZE
	for i = 1, count do
		local row = Instance.new("TextLabel")
		row.Size = UDim2.new(0.94, 0, 0.88 / count, 0)
		row.Position = UDim2.new(0.03, 0, 0.11 + (i - 1) * 0.88 / count, 0)
		row.BackgroundTransparency = if i % 2 == 0 then 1 else 0.85
		row.BackgroundColor3 = Color3.new(1, 1, 1)
		row.Font = Enum.Font.GothamMedium
		row.TextScaled = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = Color3.fromRGB(230, 230, 240)
		row.Text = ""
		row.Parent = gui
		rows[i] = row
	end
	-- Classé fermé (Config.RANKED_OPEN = false) : « BIENTÔT DISPONIBLE » en grand à la place des lignes (refreshBoard).
	-- (Attribut KeepStyle : RankedBoardDisplay ne les habille pas comme des lignes, mais les recopie au dos.)
	local soon = {}
	for _, info in {
		{ "RankedSoonTitle", RankedGate.SOON_TITLE, 0.32, 0.14, Enum.Font.GothamBlack, Color3.fromRGB(255, 215, 90) },
		{ "RankedSoonText", RankedGate.SOON_TEXT, 0.5, 0.08, Enum.Font.GothamMedium, Color3.fromRGB(230, 230, 240) },
	} do
		local label = Instance.new("TextLabel")
		label.Name = info[1]
		label.Text = info[2]
		label.Position = UDim2.new(0.05, 0, info[3], 0)
		label.Size = UDim2.new(0.9, 0, info[4], 0)
		label.Font = info[5]
		label.TextColor3 = info[6]
		label.BackgroundTransparency = 1
		label.TextScaled = true
		label.Visible = false
		label:SetAttribute("KeepStyle", true)
		label.Parent = gui
		table.insert(soon, label)
	end
	return { rows = rows, soon = soon }
end

-- Classement ranked du centre (board = résultat de buildBoardGui). Classé fermé : « BIENTÔT DISPONIBLE » à la place
-- des lignes, et rien n'est lu (aucun appel au DataStore du classement).
local function refreshBoard(board)
	local open = RankedGate.isOpen()
	for _, row in board.rows do
		row.Visible = open
	end
	for _, label in board.soon do
		label.Visible = not open
	end
	if not open then
		return
	end
	local rows = board.rows
	local entries = Leaderboard.fetchTop(#rows)
	for i, row in rows do
		local entry = entries[i]
		if entry then
			local rank = Ranks.get(entry.mmr)
			row.Text = `  #{i}   {entry.name}   —   {entry.mmr} MMR ({rank.name})`
			row.TextColor3 = if i <= 3 then rank.color else Color3.fromRGB(230, 230, 240)
		else
			row.Text = if i == 1 and #entries == 0 then "  Aucun joueur classé pour l'instant" else ""
		end
	end
end

----------------------------------------------------------------------
-- Cercle ranked (au centre de la map) : on s'y inscrit au classé avec un bouton, puis on peut partir
----------------------------------------------------------------------

-- Personnage vivant dans le cercle (même règle que le cercle dessiné : son rayon, et pas trop haut ni trop bas).
local function isInRankedCircle(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or (humanoid and humanoid.Health <= 0) then
		return false
	end
	local offset = root.Position - PlotLayout.RANKED_CIRCLE_POSITION
	return Vector3.new(offset.X, 0, offset.Z).Magnitude <= PlotLayout.RANKED_CIRCLE_RADIUS and math.abs(offset.Y) < 8
end

-- Entrer dans le cercle n'inscrit plus tout seul : le serveur publie l'attribut InRankedCircle du joueur, et
-- LobbyUI affiche le bouton « ⚔ S'INSCRIRE AU CLASSÉ » tant qu'il est vrai.
local function watchRankedCircle()
	while true do
		task.wait(0.25)
		for _, player in Players:GetPlayers() do
			local inside = isInRankedCircle(player)
			if player:GetAttribute("InRankedCircle") ~= inside then
				player:SetAttribute("InRankedCircle", inside)
			end
		end
	end
end

-- Demandes du classé refusées parce qu'il est fermé, par joueur (lu par les tests Studio : StudioDebug « RankedOpen »).
local closedRefusals = {}

-- Bouton « S'INSCRIRE » (remote QueueAction « Join ») : le serveur revérifie que le classé est ouvert
-- (Config.RANKED_OPEN, RankedGate.luau) et que le joueur est VRAIMENT dans le cercle (sa position à lui, pas ce que
-- dit le client) ; Matchmaking.join vérifie le reste (pas déjà inscrit, anti-spam, données chargées). Une fois
-- inscrit, il peut partir : il reste dans la file.
-- Renvoie (réussi, raison) pour les tests Studio.
local function signUp(player: Player): (boolean, string)
	if not RankedGate.isOpen() then
		closedRefusals[player] = (closedRefusals[player] or 0) + 1
		Remotes.get("Notify"):FireClient(player, RankedGate.SOON_TEXT, "Info")
		return false, "classé fermé"
	end
	if not isInRankedCircle(player) then
		Remotes.get("Notify"):FireClient(player, "Entre dans le cercle de l'arène pour t'inscrire au classé", "Warning")
		return false, "hors du cercle"
	end
	return Matchmaking.join(player)
end

-- Outil de test, uniquement dans Studio : ServerStorage.StudioDebug (BindableFunction), utilisable
-- depuis la barre de commande ou un plugin.
--   Invoke(player, "Coins", 1e6)                -> ajoute des pièces
--   Invoke(player, "Call", "placeTower", 1, "MachineGun") -> appelle une méthode de PlotGame
--   Invoke(player, "Call", "buySpot", 9)        -> achète l'emplacement 9 (n'importe lequel)
--   Invoke(player, "Set", "wave", 30)           -> change un champ de data.idle
--   Invoke(player, "Set", "bestWave", 50)       -> puis "Call", "rebirth" pour tester la renaissance
--   Invoke(player, "Call", "spinTower", 100)    -> 100 lancers de l'autel (renvoie le résultat)
--   Invoke(player, "Set", "towerSpinsBought", 0) -> change le compteur des lancers déjà achetés (prix de l'autel)
--   Invoke(player, "StartWave", 40)             -> lance tout de suite la vague 40 (vague en cours effacée)
--   Invoke(player, "GiftPass", userId, "SpeedX2", true) -> comme le panneau « 🎁 DONNER » du propriétaire (false =
--                                                  reprendre) ; attribut StudioNotOwner de ReplicatedStorage = pas le
--                                                  propriétaire (refusé) ; renvoie (réussi, raison)
--   Invoke(player, "Scene", "dragon")           -> scène toute prête (Hub/StudioScenes.luau, comme le bouton « SCÈNES
--                                                  (Studio) ») : 22 tours, vague du dragon (100) ou "glace" (Titan du
--                                                  givre, 40), personnage face à son chemin ; renvoie true si lancée
--   Invoke(player, "Leak")                      -> pousse le premier ennemi vivant au bout du chemin
--                                                  (test de la règle « une fuite = vague ratée »)
--   Invoke(player, "Data")                      -> renvoie les données du joueur
-- Gains d'absence et passes de jeu :
--   Invoke(player, "Absence", now?, silent?, { lastSeenAt = os.time() - 7200 })
--                                               -> change ces champs de data.idle (fausse absence de 2 h ; aussi
--                                                  matchDepartureAt, offlineDay, offlineGainedToday), puis verse les
--                                                  gains comme à l'arrivée (now = os.time() si absent) et renvoie le
--                                                  résumé (silent = pas de message au client)
--   Invoke(player, "LastAbsence")               -> résumé du dernier calcul (celui de l'arrivée au départ)
--   Invoke(player, "Pass", "SpeedX2", true)     -> donne (true) ou retire (false) un pass : "AutoCollect", "SpeedX2",
--                                                  "CoinsX2"
--   Invoke(player, "ToggleSpeed")               -> bouton x2 (comme le remote PassAction), renvoie le nouvel état
--   Invoke(player, "Drop", 100)                 -> pile de 100 pièces au point du chemin le plus loin du
--                                                  personnage, renvoie (id, distance au personnage)
--   Invoke(player, "HasDrop", id)               -> vrai si la pile est encore au sol
--   Invoke(player, "Progress")                  -> { clock, simSpeed, spawned, alive, lead } de la vague en cours
-- Parcelles reçues (ennemis et tirs, Hub/PlotInterest.luau) :
--   Invoke(player, "Interest")                  -> { own, receivesOwn, receives = { numéros des parcelles des autres
--                                                  qu'il reçoit }, clears = paquets « Clear » reçus depuis son arrivée }
--   Invoke(player, "Interest", "Position", pos) -> cette position compte à la place de son personnage (nil : de nouveau
--                                                  son personnage), au prochain calcul (PlotInterest.REFRESH_INTERVAL)
-- Forge runique :
--   Invoke(player, "Call", "spinBonusWithCoins") -> un lancer en pièces (renvoie le résultat, nil si refusé)
--   Invoke(player, "Call", "grantBonusSpin", "Robux") -> comme un achat Robux (ne change pas le prix)
--   Invoke(player, "Call", "forgeState")        -> { bought, price, drawable = { ids }, blocked }
--   Invoke(player, "Set", "forgeSpinsBought", 0) -> change le compteur des lancers en pièces (prix)
--   Invoke(player, "Set", "bonuses", { "Speed2" }) puis Invoke(player, "Call", "applyBonus", 1, "Speed2")
--                                               -> pose la rune sur la tour de l'emplacement 1 (dans son
--                                                  emplacement : dégâts ou vitesse) ; "debugTower", 1 -> ses stats
-- Combat (arène de test, voir PlotGame « Outils de test ») :
--   Invoke(player, "Call", "debugArena", { 6 }) puis "debugSpawn", "debugFire", "debugEnemy", "debugFreeze"...
--   Invoke(player, "Call", "debugRunWave", 1, "OneShot", 1 / 60, 600) -> vague écrasée (compression)
--   Invoke(player, "Call", "debugRunWave", 1, "KillOldest", 0.05, 60) -> sortie à chaque mort
-- Défis classés (Hub/ChallengeRewards.luau, règles dans Shared/Challenges.luau) :
--   Invoke(player, "ChallengeMatch", { seconds = 240, won = true, opponentId = 42, towersPlaced = 6,
--          towerTypes = 3, upgrades = 4 })   -> un match classé terminé, compté comme par le serveur de match
--                                                (aussi ranked = false, matchId) ; renvoie { counted, reason, completed, text }
--   Invoke(player, "ChallengeClock", 86400)    -> décale l'horloge des défis (86400 = demain, 7 * 86400 = semaine
--                                                prochaine, 0 = heure réelle) ; renvoie { day, week, offset }
--   Invoke(player, "Challenges")               -> état complet des défis (progression, récompenses calculées)
--   Invoke(player, "ChallengeForce", { "play2", "win1", "towers15" }, { "play10", "minutes45" })
--                                             -> ces défis-là à la place de ceux du jour / de la semaine (progression 0)
--   Invoke(player, "ChallengeClaim", "d1", jour?) -> bouton « Récupérer » (sans l'anti-spam ; jour absent = jour
--                                                en cours, ou semaine en cours pour "w1") ; renvoie (réussi, message, détails)
--   Invoke(player, "ChallengeMigrate", ancienneSauvegarde) -> la sauvegarde complétée comme au chargement
-- Classé : inscription dans le cercle et match à ACCEPTER (Matchmaking.luau). Dans Studio, la file tourne en
-- mémoire (un seul serveur, adversaires factices) et personne n'est jamais téléporté :
--   Invoke(player, "RankedSignUp")             -> bouton « S'INSCRIRE AU CLASSÉ » (mêmes vérifications que le remote :
--                                                dans le cercle, pas déjà inscrit, anti-spam) ; renvoie (réussi, raison)
--   Invoke(player, "RankedMove", true)         -> personnage au centre du cercle (false : renvoyé sur sa parcelle)
--   Invoke(player, "Ranked", "FakeOpponent", { name = "Bot", mmr = 1000, games = 12, wait = 30 })
--                                             -> un adversaire factice s'inscrit (depuis `wait` secondes) et les paires
--                                                sont formées tout de suite (pair = false : il attend seulement dans la
--                                                file) ; renvoie (id du match proposé au joueur, UserId de l'adversaire)
--   Invoke(player, "Ranked", "OpponentAccept") -> l'adversaire factice du match proposé accepte ("OpponentRefuse" : il
--                                                refuse, "OpponentLeave" : il quitte le jeu)
--   Invoke(player, "Ranked", "Accept")         -> ACCEPTER du joueur ("Refuse" : REFUSER, "Leave" : ANNULER)
--   Invoke(player, "Ranked", "Expire")         -> le temps pour accepter est écoulé (comme après ACCEPT_SECONDS ; avec
--                                                true, rien n'est forcé : la boucle du serveur doit le voir seule)
--   Invoke(player, "Ranked", "StuckStart", 40) -> les deux ont accepté, mais le serveur qui crée le match a disparu
--                                                depuis 40 s (0 = à l'instant : le joueur passe à « Found »)
--   Invoke(player, "Ranked", "BreakReserve", true) -> la réservation du serveur de match échoue (false : remarche)
--   Invoke(player, "Ranked", "Tick")           -> un passage du leader et du suivi, sans attendre
--   Invoke(player, "Ranked", "State")          -> { state, joinedAt, proposal, queue, opponents, lastStart, teleports }
--                                                (lastStart = le match qui partirait, teleports = qui serait téléporté)
--   Invoke(player, "Ranked", "Reset")          -> tout vidé (file, propositions, adversaires factices), joueur « Idle »
--   Invoke(player, "RankedOpen", false)        -> classé forcé FERMÉ (« BIENTÔT DISPONIBLE » partout, file vidée) ; true :
--                                                forcé ouvert (les tests automatiques le font au début) ; "Default" : de
--                                                nouveau Config.RANKED_OPEN ; sans valeur : ne change rien. Renvoie { open,
--                                                override, refused = demandes refusées car classé fermé } (RankedGate.luau)
-- Achats d'objets aléatoires (règle de Roblox, PolicyService : Monetization.luau) :
--   Invoke(player, "PaidRandom", true)         -> comme un joueur à qui Roblox interdit ces achats (attribut
--                                                PaidRandomRestricted : bouton Robux de la forge caché) ; false : autorisé
-- Tuto des nouveaux joueurs (Hub/Tutorial.luau, client : TutorialUI.luau) :
--   Invoke(player, "Tutorial", "Replay")       -> le tuto recommence à l'étape 1 (même pendant les tests automatiques)
--   Invoke(player, "Tutorial")                 -> { done, attribute, lastAction ("Done" | "Skip"), lastStep, replays }
-- Classement solo (SoloLeaderboard.luau, panneaux Hub/SoloBoard.luau) :
--   Invoke(player, "Solo", "Refresh")          -> relit les classements et met les panneaux à jour tout de suite
--   Invoke(player, "Solo", "Fake", { { userId = -1, name = "Bot", wave = 500, dps = 1e12 } }) -> faux joueurs (DataStores
--                                                en mémoire seulement), "ClearFakes" pour les retirer ; autres commandes
--                                                ("State", "Tick", "Clock", "Submit", "Stored") en bas de SoloLeaderboard.luau
local function setupStudioDebug()
	if not RunService:IsStudio() then
		return
	end
	-- Bouton « SCÈNES (Studio) » (Config.STUDIO_SCENES) : dragon ou boss de glace, tout prêt.
	StudioScenes.start(function(player)
		return games[player]
	end)
	local debug = Instance.new("BindableFunction")
	debug.Name = "StudioDebug"
	debug.OnInvoke = function(player: Player, command: string, ...)
		local plotGame = games[player]
		local data = PlayerData.get(player)
		if command == "Absence" and data then
			local now, silent, fields = ...
			for key, value in fields or {} do
				data.idle[key] = value
			end
			return takeAbsenceGains(player, data, now or os.time(), silent)
		elseif command == "LastAbsence" then
			return lastAbsence[player]
		elseif command == "Pass" then
			local name, owned = ...
			return Monetization.setStudioPass(player, name, owned)
		elseif command == "ToggleSpeed" then
			return toggleSpeed(player)
		elseif command == "Drop" and plotGame then
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local farthest, farthestDistance = nil, -1
			for distance = 0, PlotLayout.PATH_LENGTH, 10 do
				local point = plotGame.cframe:PointToWorldSpace((PlotLayout.pointAt(distance)))
				local away = 0
				if root then
					local offset = point - root.Position
					away = Vector3.new(offset.X, 0, offset.Z).Magnitude
				end
				if away > farthestDistance then
					farthest, farthestDistance = point, away
				end
			end
			local amount = ...
			local drop = plotGame:addDrop(farthest, amount or 1)
			return drop.id, farthestDistance
		elseif command == "HasDrop" and plotGame then
			return plotGame.drops[...] ~= nil
		elseif command == "Progress" and plotGame then
			local alive, lead = 0, 0
			for _, enemy in plotGame.enemies do
				if not enemy.dead then
					alive += 1
					lead = math.max(lead, enemy.distance)
				end
			end
			return {
				clock = plotGame.clock,
				simSpeed = plotGame.simSpeed,
				spawned = plotGame.spawnIndex - 1,
				alive = alive,
				lead = lead,
			}
		elseif command == "Coins" then
			PlayerData.addCoins(player, ...)
		elseif command == "Call" and plotGame then
			local method, rest = ..., table.pack(select(2, ...))
			return plotGame[method](plotGame, table.unpack(rest, 1, rest.n))
		elseif command == "Set" and data then
			local key, value = ...
			data.idle[key] = value
		elseif command == "StartWave" and plotGame then
			plotGame.idle.wave = ...
			plotGame:clearEnemies()
			plotGame:startWave()
		elseif command == "Scene" then
			return StudioScenes.apply(player, plotGame, ...)
		elseif command == "GiftPass" then
			-- Comme le panneau « 🎁 DONNER » : (UserId du joueur, nom du pass, true = offrir) -> (réussi, raison)
			return AdminGifts.handle(player, ...)
		elseif command == "Leak" and plotGame then
			for _, enemy in plotGame.enemies do
				if not enemy.dead then
					enemy.distance = PlotLayout.PATH_LENGTH -- au prochain pas, il dépasse le bout du chemin
					return true
				end
			end
			return false
		elseif command == "Data" then
			return data
		elseif command == "Interest" then
			local action, position = ...
			if action == "Position" then
				interest.positions[player] = if typeof(position) == "Vector3" then position else nil
				return true
			end
			local own = Plots.get(player)
			local receives, receivesOwn = {}, false
			for plotIndex, list in interest.viewers do
				if table.find(list, player) then
					if plotIndex == own then
						receivesOwn = true
					else
						table.insert(receives, plotIndex)
					end
				end
			end
			table.sort(receives)
			return { own = own, receivesOwn = receivesOwn, receives = receives, clears = interest.clears[player] or 0 }
		elseif command == "ChallengeMatch" and data then
			return ChallengeRewards.debugMatch(player, data, ...)
		elseif command == "ChallengeClock" then
			return ChallengeRewards.debugSetClock(...)
		elseif command == "Challenges" and data then
			return ChallengeRewards.debugState(player, data)
		elseif command == "ChallengeForce" and data then
			return ChallengeRewards.debugForce(player, data, ...)
		elseif command == "ChallengeClaim" and data then
			local key, period = ...
			if period == nil then
				local state = ChallengeRewards.debugState(player, data)
				period = if typeof(key) == "string" and string.sub(key, 1, 1) == "w" then state.week else state.day
			end
			return ChallengeRewards.claim(player, key, period)
		elseif command == "ChallengeMigrate" then
			local old = ...
			return PlayerData.reconcile(if typeof(old) == "table" then old else {})
		elseif command == "RankedSignUp" then
			return signUp(player)
		elseif command == "RankedMove" then
			local character = player.Character
			local toCircle = ...
			if not character then
				return false
			end
			if toCircle then
				character:PivotTo(CFrame.new(PlotLayout.RANKED_CIRCLE_POSITION + Vector3.new(0, 3, 0)))
			else
				Plots.sendHome(player)
			end
			return true
		elseif command == "Ranked" then
			return Matchmaking.debug(player, ...)
		elseif command == "RankedOpen" then
			local value = ...
			if value == false and RankedGate.isOpen() then
				Matchmaking.debug(player, "Reset") -- on ferme : plus personne dans la file
			end
			if typeof(value) == "boolean" then
				RankedGate.setStudioOverride(value)
			elseif value == "Default" then
				RankedGate.setStudioOverride(nil)
			end
			return {
				open = RankedGate.isOpen(),
				override = ReplicatedStorage:GetAttribute(RankedGate.STUDIO_ATTRIBUTE),
				refused = closedRefusals[player] or 0,
			}
		elseif command == "PaidRandom" then
			return Monetization.setStudioPaidRandom(player, (...) == true)
		elseif command == "Tutorial" and data then
			return Tutorial.debug(player, data, ...)
		elseif command == "Solo" then
			return SoloLeaderboard.debug(player, ...)
		end
		return nil
	end
	debug.Parent = game:GetService("ServerStorage")
end

function Hub.start()
	local map = HubMap.build()
	Plots.init(map.plots)
	Plots.start()

	local rankedBoard = buildBoardGui(map.board)
	-- Classement solo : les 2 panneaux de la place (face vers le centre, et le dos), remplis par SoloLeaderboard.
	for _, solo in map.soloBoards do
		SoloBoard.attach(solo.board, solo.front)
	end
	Matchmaking.start()

	-- Une partie infinie par joueur, dès que ses données sont chargées. D'abord les gains d'absence, tout de
	-- suite (sans attendre) : une sauvegarde changerait l'heure de sa dernière visite.
	local function onDataLoaded(player: Player, data)
		local ok, err = pcall(takeAbsenceGains, player, data, os.time())
		if not ok then
			warn("[Hub] Gains d'absence impossibles :", err) -- la parcelle démarre quand même
		end
		startPlotGame(player, data)
		-- Défis classés : état publié pour le bouton « DÉFIS », message si des récompenses attendent.
		local challengesOk, challengesErr = pcall(ChallengeRewards.onPlayerLoaded, player, data)
		if not challengesOk then
			warn("[Hub] Défis classés indisponibles :", challengesErr)
		end
	end
	PlayerData.onLoaded(onDataLoaded)
	for _, player in Players:GetPlayers() do
		local data = PlayerData.get(player)
		if data then
			onDataLoaded(player, data)
		end
	end
	PlayerData.onBeforeRelease(function(player)
		local plotGame = games[player]
		if plotGame then
			-- Classement solo : ses dernières valeurs, envoyées si elles ont monté (sans attendre), avant de fermer.
			SoloLeaderboard.leave(player, plotGame.idle.highestWave, plotGame:totalDps())
			games[player] = nil
			plotGame:destroy()
		end
	end)
	-- Classement solo (tous les serveurs, de tous les temps) : record de vague et DPS total de chaque parcelle, envoyés
	-- quand ils montent (au plus une fois par minute et par joueur), panneaux relus chaque minute.
	SoloLeaderboard.start(function(player: Player)
		local plotGame = games[player]
		if plotGame then
			return plotGame.idle.highestWave, plotGame:totalDps()
		end
		return nil
	end, SoloBoard.show)
	runPlotGames()
	setupStudioDebug()
	-- Défis classés : bouton « Récupérer » (remote ChallengeAction) et nouveaux défis à minuit UTC. Les lancers
	-- offerts passent par la parcelle du joueur.
	ChallengeRewards.start(function(player: Player)
		return games[player]
	end)
	-- Tuto des nouveaux joueurs : fin ou « Passer » (remote TutorialAction), drapeau tutorialDone (Hub/Tutorial.luau).
	Tutorial.start()
	-- Panneau « 🎁 DONNER » du propriétaire du jeu : offrir un pass à un joueur du serveur (Hub/AdminGifts.luau).
	AdminGifts.start()

	local lastPlotAction = {}
	local lastPassAction = {}
	Players.PlayerRemoving:Connect(function(player)
		lastPlotAction[player] = nil
		lastPassAction[player] = nil
		lastAbsence[player] = nil
	end)
	Remotes.get("PlotAction").OnServerEvent:Connect(function(player, action, spotIndex, towerType, replaceType)
		local plotGame = games[player]
		local now = os.clock()
		if not plotGame or now - (lastPlotAction[player] or 0) < 0.15 then
			return
		end
		lastPlotAction[player] = now
		if action == "Place" then
			-- replaceType = la tour remplacée (remplacement confirmé), sinon rien : placeTower refuse alors
			-- un emplacement déjà occupé.
			plotGame:placeTower(spotIndex, towerType, replaceType)
		elseif action == "Upgrade" then
			plotGame:upgradeTower(spotIndex)
		elseif action == "Sell" then
			plotGame:sellTower(spotIndex)
		elseif action == "BuySpot" then
			-- N'importe quel emplacement verrouillé : buySpot vérifie le numéro, la possession et les pièces.
			plotGame:buySpot(spotIndex)
		elseif action == "Rebirth" then
			-- Renaissance : le serveur vérifie lui-même la vague minimale (PlotGame:rebirth).
			plotGame:rebirth()
		end
	end)

	-- Machines à sous : chaque joueur n'utilise que les machines de SA parcelle.
	for plotIndex, plot in map.plots do
		for machine, prompt in plot.machines do
			prompt.Triggered:Connect(function(player)
				if Plots.get(player) == plotIndex then
					Remotes.get("OpenMachine"):FireClient(player, machine)
				else
					Remotes.get("Notify"):FireClient(player, "Cet autel appartient à un autre fief !", "Warning")
				end
			end)
		end
	end
	Remotes.get("MachineAction").OnServerEvent:Connect(function(player, action, arg1, arg2)
		local plotGame = games[player]
		local now = os.clock()
		if not plotGame or now - (lastPlotAction[player] or 0) < 0.3 then
			return
		end
		lastPlotAction[player] = now
		if action == "SpinTower" then
			-- arg1 = nombre de lancers (rien = 1) : spinTower vérifie qu'il est proposé à ce record, calcule le
			-- prix avec les données du serveur (compteur des lancers déjà achetés, jamais celui du client) et
			-- vérifie les pièces.
			plotGame:spinTower(arg1)
		elseif action == "SpinBonusCoins" then
			-- Forge runique en pièces (plus de délai) : spinBonusWithCoins vérifie qu'une rune peut améliorer une
			-- tour posée (dans l'emplacement de sa sorte), calcule le prix avec le compteur du serveur
			-- (idle.forgeSpinsBought) et vérifie les pièces.
			plotGame:spinBonusWithCoins()
		elseif action == "ApplyBonus" then
			-- arg1 = emplacement, arg2 = id de la rune (posée dans l'emplacement de sa sorte : dégâts ou vitesse)
			plotGame:applyBonus(arg1, arg2)
		end
	end)

	-- Achat Robux : un lancer de la forge runique. Il ne compte pas dans le prix des lancers en pièces. Si la
	-- forge est bloquée (aucune rune n'améliorerait une tour : x100 dégâts et x2 vitesse partout ; le client
	-- bloque alors le bouton Robux), un reçu qui arrive quand même donne la meilleure rune : un achat payé n'est
	-- jamais perdu (PlotGame:grantBonusSpin).
	-- Pas encore de parcelle (joueur en train d'arriver) : false, Roblox redonnera le reçu plus tard.
	Monetization.onProduct(Config.Products.BONUS_SPIN, function(player)
		local plotGame = games[player]
		if not plotGame then
			return false
		end
		plotGame:grantBonusSpin("Robux")
		return true
	end)
	-- Passes de jeu : effet immédiat dès que la possession est connue (arrivée, achat, test Studio).
	Monetization.onPassChanged(refreshPasses)
	Monetization.start()
	Remotes.get("PassAction").OnServerEvent:Connect(function(player, action)
		local now = os.clock()
		if now - (lastPassAction[player] or 0) < 0.3 then
			return
		end
		lastPassAction[player] = now
		if action == "ToggleSpeed" then
			toggleSpeed(player)
		end
	end)

	-- Classé : « S'INSCRIRE » (dans le cercle), « ANNULER », et la fenêtre « MATCH TROUVÉ ! » (ACCEPTER / REFUSER).
	-- Le serveur vérifie tout (Matchmaking.luau) ; un clic toutes les 0,25 s au plus.
	local lastQueueAction = {}
	Players.PlayerRemoving:Connect(function(player)
		lastQueueAction[player] = nil
		closedRefusals[player] = nil
	end)
	Remotes.get("QueueAction").OnServerEvent:Connect(function(player, action)
		local now = os.clock()
		if typeof(action) ~= "string" or now - (lastQueueAction[player] or 0) < 0.25 then
			return
		end
		lastQueueAction[player] = now
		if action == "Join" then
			signUp(player) -- (refusée si le classé est fermé)
		elseif not RankedGate.isOpen() then
			-- Classé fermé : aucune autre demande n'est acceptée (le client n'affiche d'ailleurs aucun de ces boutons).
			closedRefusals[player] = (closedRefusals[player] or 0) + 1
		elseif action == "Leave" then
			Matchmaking.leave(player, "Cancel")
		elseif action == "Accept" then
			Matchmaking.answer(player, true)
		elseif action == "Refuse" then
			Matchmaking.answer(player, false)
		end
	end)

	Remotes.get("HubAction").OnServerEvent:Connect(function(player, action)
		local character = player.Character
		if not character then
			return
		end
		if action == "GoHome" then
			Plots.sendHome(player)
		elseif action == "GoRanked" then
			local position = PlotLayout.RANKED_CIRCLE_POSITION + Vector3.new(0, 3, 0)
			character:PivotTo(CFrame.new(position))
		end
	end)

	task.spawn(watchRankedCircle)
	task.spawn(function()
		while true do
			refreshBoard(rankedBoard)
			task.wait(Config.Ranked.LEADERBOARD_REFRESH)
		end
	end)
	-- Classé ouvert ou fermé pendant la partie (Studio seulement, RankedGate.luau) : tableau mis à jour tout de suite.
	RankedGate.onChanged(function()
		task.spawn(refreshBoard, rankedBoard)
	end)
end

return Hub

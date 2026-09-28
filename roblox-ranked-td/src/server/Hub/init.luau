-- Map principale (serveur public) : 6 parcelles, cercle ranked au centre, classement.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local IdleConfig = require(Shared.IdleConfig)
local NumberFormat = require(Shared.NumberFormat)
local PlotLayout = require(Shared.PlotLayout)
local Ranks = require(Shared.Ranks)
local Remotes = require(Shared.Remotes)
local Leaderboard = require(script.Parent.Leaderboard)
local Matchmaking = require(script.Parent.Matchmaking)
local Monetization = require(script.Parent.Monetization)
local PlayerData = require(script.Parent.PlayerData)
local PlotGame = require(script.PlotGame)
local HubMap = require(script.HubMap)
local Plots = require(script.Plots)

local Hub = {}

local games = {} -- [Player] = PlotGame

----------------------------------------------------------------------
-- Passes de jeu (possession : Monetization.luau). Mode solo uniquement.
----------------------------------------------------------------------

-- Applique les passes du joueur à sa parcelle et publie SpeedX2Enabled (vrai = x2 en marche :
-- pass Vitesse x2 possédé ET interrupteur allumé, data.idle.speedX2, allumé par défaut).
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

-- Verse les gains d'absence du joueur qui arrive sur la map principale (avant toute sauvegarde) :
--   match ranked : de idle.matchDepartureAt (noté par Matchmaking avant la téléportation) à idle.lastSeenAt
--     (dernière sauvegarde, faite par le serveur de match à la fin) : revenu normal, hors plafond,
--     au plus Config.Match.MAX_DURATION + IdleConfig.ABSENCE_MATCH_EXTRA_SECONDS ;
--   hors ligne : de idle.lastSeenAt à maintenant (au plus IdleConfig.OFFLINE_MAX_SECONDS) :
--     revenu normal x IdleConfig.OFFLINE_RATE, dans la limite du plafond du jour (IdleConfig.offlineDailyCap).
-- Les deux heures sont consommées (lastSeenAt = maintenant, matchDepartureAt = 0) : jamais payé deux fois.
-- Première visite (lastSeenAt = 0) ou heure abîmée : rien. `now` = os.time() (remplacé dans les tests
-- Studio), silent = pas de message au client. Renvoie le résumé (voir Remotes.luau, OfflineGains).
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
	if result.amount > 0 then
		PlayerData.addCoins(player, result.amount)
		print(
			`[Hub] Gains d'absence de {player.Name} : +{NumberFormat.short(result.amount)} (hors ligne {math.floor(result.offlineSeconds)} s`
				.. ` +{NumberFormat.short(result.offlineAmount)}{if result.capped then ", plafond du jour" else ""},`
				.. ` match {math.floor(result.matchSeconds)} s +{NumberFormat.short(result.matchAmount)})`
		)
	end
	if not silent and (result.amount > 0 or result.capped) then
		-- Petit délai : l'interface du client a le temps de démarrer et d'afficher le message.
		task.delay(2, function()
			if player.Parent then
				Remotes.get("OfflineGains"):FireClient(player, result)
			end
		end)
	end
	return result
end

-- Boucle du mode infini : simulation à chaque frame, envois réseau quelques fois par seconde.
local function runPlotGames()
	local syncRemote = Remotes.get("PlotSync")
	local shotsRemote = Remotes.get("PlotShots")
	local syncTimer, shotsTimer, collectTimer = 0, 0, 0

	RunService.Heartbeat:Connect(function(dt)
		for _, plotGame in games do
			plotGame:step(dt)
		end

		syncTimer += dt
		if syncTimer >= 1 / IdleConfig.SYNC_RATE then
			syncTimer = 0
			for _, plotGame in games do
				local packet, count = plotGame:buildSyncPacket()
				if packet then
					syncRemote:FireAllClients(plotGame.index, packet, count)
				end
			end
		end

		shotsTimer += dt
		if shotsTimer >= 1 / IdleConfig.SHOTS_RATE then
			shotsTimer = 0
			for _, plotGame in games do
				local packet, count = plotGame:takeShotsPacket()
				if packet then
					shotsRemote:FireAllClients(plotGame.index, packet, count)
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
	return rows
end

local function refreshBoard(rows)
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

-- Outil de test, uniquement dans Studio : ServerStorage.StudioDebug (BindableFunction), utilisable
-- depuis la barre de commande ou un plugin.
--   Invoke(player, "Coins", 1e6)                -> ajoute des pièces
--   Invoke(player, "Call", "placeTower", 1, "MachineGun") -> appelle une méthode de PlotGame
--   Invoke(player, "Call", "buySpot", 9)        -> achète l'emplacement 9 (n'importe lequel)
--   Invoke(player, "Set", "wave", 30)           -> change un champ de data.idle
--   Invoke(player, "Set", "bestWave", 50)       -> puis "Call", "rebirth" pour tester la renaissance
--   Invoke(player, "Call", "spinTower", 100)    -> 100 lancers de l'autel (renvoie le résultat)
--   Invoke(player, "StartWave", 40)             -> lance tout de suite la vague 40 (vague en cours effacée)
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
--   Invoke(player, "Pass", "SpeedX2", true)     -> donne (true) ou retire (false) un pass : "AutoCollect", "SpeedX2"
--   Invoke(player, "ToggleSpeed")               -> bouton x2 (comme le remote PassAction), renvoie le nouvel état
--   Invoke(player, "Drop", 100)                 -> pile de 100 pièces au point du chemin le plus loin du
--                                                  personnage, renvoie (id, distance au personnage)
--   Invoke(player, "HasDrop", id)               -> vrai si la pile est encore au sol
--   Invoke(player, "Progress")                  -> { clock, simSpeed, spawned, alive, lead } de la vague en cours
local function setupStudioDebug()
	if not RunService:IsStudio() then
		return
	end
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
		end
		return nil
	end
	debug.Parent = game:GetService("ServerStorage")
end

-- Entrer dans le cercle lance la recherche (une seule fois par entrée).
local function watchRankedCircle()
	local center = PlotLayout.RANKED_CIRCLE_POSITION
	local radius = PlotLayout.RANKED_CIRCLE_RADIUS
	local inside = {}

	Players.PlayerRemoving:Connect(function(player)
		inside[player] = nil
	end)

	while true do
		task.wait(0.25)
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local isInside = false
			if root then
				local offset = root.Position - center
				isInside = Vector3.new(offset.X, 0, offset.Z).Magnitude <= radius and math.abs(offset.Y) < 8
			end
			if isInside and not inside[player] then
				task.spawn(Matchmaking.join, player)
			end
			inside[player] = isInside
		end
	end
end

function Hub.start()
	local map = HubMap.build()
	Plots.init(map.plots)
	Plots.start()

	local rows = buildBoardGui(map.board)
	Matchmaking.start()

	-- Une partie infinie par joueur, dès que ses données sont chargées. D'abord les gains d'absence, tout de
	-- suite (sans attendre) : une sauvegarde changerait l'heure de sa dernière visite.
	local function onDataLoaded(player: Player, data)
		local ok, err = pcall(takeAbsenceGains, player, data, os.time())
		if not ok then
			warn("[Hub] Gains d'absence impossibles :", err) -- la parcelle démarre quand même
		end
		startPlotGame(player, data)
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
			games[player] = nil
			plotGame:destroy()
		end
	end)
	runPlotGames()
	setupStudioDebug()

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
			-- arg1 = nombre de lancers (rien = 1) : spinTower vérifie qu'il est proposé à ce record, et les pièces.
			plotGame:spinTower(arg1)
		elseif action == "SpinBonusCoins" then
			plotGame:spinBonusWithCoins()
		elseif action == "ApplyBonus" then
			-- arg1 = emplacement, arg2 = id du bonus
			plotGame:applyBonus(arg1, arg2)
		end
	end)

	-- Achat Robux : un lancer de la machine à bonus.
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

	Remotes.get("QueueAction").OnServerEvent:Connect(function(player, action)
		if action == "Join" then
			Matchmaking.join(player)
		elseif action == "Leave" then
			Matchmaking.leave(player)
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
			refreshBoard(rows)
			task.wait(Config.Ranked.LEADERBOARD_REFRESH)
		end
	end)
end

return Hub

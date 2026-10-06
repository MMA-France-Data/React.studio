-- Test de tout le jeu, côté serveur : décor, achats de la salle de sport, puis les 10 salles (perdre, gagner,
-- demi-récompense, portes, plafond repoussé ou non), le raccourci. Le temps des salles est accéléré 8 fois.
-- Le joueur de test est déplacé par le serveur ; un champ de force le protège quand le test doit gagner une salle
-- sans esquiver (le plafond, lui, écrase même avec le champ de force : il faut vraiment pousser avec la bonne force).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Pets = require(ReplicatedStorage.Shared.Pets)

local SCALE = 8

return function(log)
	local function check(condition, name, detail)
		log("Info", (if condition then "[PASS] " else "[FAIL] ") .. name .. (if detail then "  (" .. tostring(detail) .. ")" else ""))
	end
	local debug = ServerStorage:WaitForChild("SurviveDebug", 30)
	local function D(...)
		return debug:Invoke(...)
	end

	local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
	while not player:GetAttribute("Loaded") do
		task.wait(0.1)
	end

	-- Le personnage vivant (attend la réapparition s'il vient de mourir).
	local known = nil
	local function alive()
		while true do
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 and character:FindFirstChild("HumanoidRootPart") then
				if character ~= known then
					-- Nouveau personnage : le jeu le pose dans son espace juste après son apparition. On attend que
					-- ce soit fait, sinon il serait ramené là après un déplacement du test.
					known = character
					task.wait(0.6)
				end
				return character, humanoid, character.HumanoidRootPart
			end
			task.wait(0.1)
		end
	end
	local function tp(position: Vector3)
		local character = alive()
		character:PivotTo(CFrame.new(position))
	end
	local function god(on: boolean)
		local character, humanoid = alive()
		local field = character:FindFirstChildOfClass("ForceField")
		if on and not field then
			field = Instance.new("ForceField")
			field.Visible = false
			field.Parent = character
		elseif not on and field then
			field:Destroy()
		end
		if on then
			humanoid.Health = humanoid.MaxHealth
		end
	end
	local function shot(name: string, from: Vector3, target: Vector3)
		workspace:SetAttribute("ShotCam", CFrame.lookAt(from, target))
		task.wait(0.7)
		log("Info", "SHOT:game_" .. name)
		task.wait(1)
		workspace:SetAttribute("ShotCam", nil)
	end
	local function waitState(index: number, state: string, timeout: number): boolean
		local limit = os.clock() + timeout
		while os.clock() < limit do
			if D("Room", index).state == state then
				return true
			end
			task.wait(0.05)
		end
		return false
	end
	local function waitElapsed(index: number, seconds: number)
		while true do
			local room = D("Room", index)
			if room.state ~= "Event" or room.elapsed >= seconds then
				return
			end
			task.wait(0.05)
		end
	end
	-- Entre dans la salle et attend le début de l'événement.
	local function enter(index: number): any
		local room = D("Room", index)
		tp(Vector3.new(0, 4, room.zMin + 8))
		check(waitState(index, "Countdown", 3), `salle {index} : le compte à rebours part quand on entre`)
		check(waitState(index, "Event", Config.PREPARE / SCALE + 3), `salle {index} : l'événement commence`)
		check(player:GetAttribute("Room") == index, `salle {index} : le joueur est noté dans la salle`, player:GetAttribute("Room"))
		check(D("Room", index).entryOpen == false, `salle {index} : la porte d'entrée se ferme`)
		return room
	end
	-- Place sûre pour gagner la salle (avec le champ de force pour le reste).
	local function safeSpot(index: number, room): Vector3
		local def = Config.ROOMS[index]
		if def.Lava or def.Bomb then
			return room.pillars[#room.pillars] + Vector3.new(0, 4, 0)
		end
		return room.center + Vector3.new(0, 4, 0)
	end
	-- Appuie sur E `rate` fois par seconde (du temps de la salle) tant que l'événement dure. Le nombre d'appuis suit
	-- le temps de la salle, pas celui du PC : le test ne dépend pas de la vitesse de Studio.
	local function mash(index: number, rate: number)
		task.spawn(function()
			local last, owed, counted = D("Room", index).elapsed, 0, 0
			local folder = workspace.Rooms["Room" .. index]
			local nextLog = 30
			while true do
				local room = D("Room", index)
				if room.state ~= "Event" then
					break
				end
				owed += (room.elapsed - last) * rate
				last = room.elapsed
				local presses = math.floor(owed)
				owed -= presses
				if presses > 0 then
					counted += D("Push", presses, true)
				end
				if room.elapsed >= nextLog then
					nextLog += 10
					log("Info", string.format("[SURVIVE] salle %d t=%.0f : plafond %s, force %s, appuis comptés %d", index, room.elapsed, tostring(folder:GetAttribute("Ceiling")), tostring(player:GetAttribute("Force")), counted))
				end
				task.wait(0.05)
			end
		end)
	end
	-- Reste en haut du parcours (protégé) et pousse le plafond : renvoie true si le joueur est écrasé.
	local function crushed(index: number, rate: number): boolean
		local room = enter(index)
		god(true)
		tp(safeSpot(index, room))
		local _, humanoid = alive()
		if rate > 0 then
			mash(index, rate)
		end
		local limit = os.clock() + (Config.DURATION + 2) / SCALE
		while humanoid.Health > 0 and os.clock() < limit do
			task.wait(0.05)
		end
		local dead = humanoid.Health <= 0
		log("Info", string.format("[SURVIVE] salle %d, %d appuis/s : %s à %.1f s", index, rate, if dead then "écrasé" else "en vie", D("Room", index).elapsed))
		if not dead then
			humanoid.Health = 0
		end
		waitState(index, "Idle", 3)
		return dead
	end
	local function winRoom(index: number, snap: boolean?, bonus: number?)
		local before = D("Data").coins
		local room = enter(index)
		local def = Config.ROOMS[index]
		god(true)
		tp(safeSpot(index, room))
		if def.Ceiling then
			mash(index, 5)
		end
		if def.Bomb then
			-- En haut du parcours : le joueur coupe son fil (une seule fois).
			-- (La photo d'abord : seul dans la salle, couper son fil ouvre la porte tout de suite.)
			waitElapsed(index, 6)
			if snap then
				local spot = safeSpot(index, room)
				shot("salle" .. index, spot + Vector3.new(15, 5, -17), spot + Vector3.new(0, 1, 0))
			end
			check(D("Defuse", index) == true and player:GetAttribute("BombCut") == index, `salle {index} : en haut, le joueur coupe son fil`)
			check(D("Defuse", index) == false, `salle {index} : on ne coupe son fil qu'une fois`)
		end
		if snap and not def.Bomb then
			waitElapsed(index, if def.Ceiling then 44 else 34)
			local spot = safeSpot(index, room)
			if def.Ceiling then
				-- Sous le plafond, à côté de la dernière plateforme.
				shot("salle" .. index, spot + Vector3.new(15, 1, -17), spot + Vector3.new(0, 3, 0))
			else
				shot("salle" .. index, Vector3.new(-31, spot.Y + 16, room.zMin + 5), Vector3.new(6, math.max(2, spot.Y - 16), room.center.Z))
			end
		end
		local won = waitState(index, "Open", Config.DURATION / SCALE + 6)
		check(won, `salle {index} : gagnée`, D("Room", index).state)
		if def.Bomb then
			check(D("Room", index).elapsed < Config.DURATION - 5, `salle {index} : tous les fils coupés, la porte s'ouvre avant zéro`, D("Room", index).elapsed)
		end
		-- Une salle réussie ne donne aucune pièce : seulement son ticket.
		local gained = D("Data").coins - before
		check(gained == 0, `salle {index} : aucune pièce, seulement le ticket`, gained)
		check(D("Room", index).exitOpen == true, `salle {index} : la porte du bout s'ouvre`)
		god(false)
		if index < #Config.ROOMS then
			tp(D("Sas", index))
		else
			tp(Vector3.new(0, 4, room.zMax + 12))
		end
		check(waitState(index, "Idle", Config.OPEN / SCALE + 3), `salle {index} : redevient libre`)
		local after = D("Room", index)
		check(after.exitOpen == false and after.entryOpen == true, `salle {index} : portes remises (sortie fermée, entrée ouverte)`)
	end

	-- 1. LE DÉCOR ------------------------------------------------------------------------------------------------
	alive()
	task.wait(2)
	local gym = workspace:FindFirstChild("Gym")
	check(gym ~= nil, "le lobby existe")
	local rooms = workspace:FindFirstChild("Rooms")
	local count = 0
	for index = 1, #Config.ROOMS do
		local folder = rooms and rooms:FindFirstChild("Room" .. index)
		if folder and folder:GetAttribute("State") == "Idle" and folder.Entry:GetAttribute("Open") and not folder.Exit:GetAttribute("Open") then
			count += 1
		end
	end
	check(count == 10, "10 salles libres, entrée ouverte, sortie fermée", count)
	-- LE LOBBY : 6 espaces, le joueur a le sien et y apparaît.
	local spaces = 0
	for index = 1, 6 do
		local folder = gym and gym:FindFirstChild("Plot" .. index)
		if folder and folder:FindFirstChild("Speed") and folder:FindFirstChild("Jump") and folder:FindFirstChild("Force") and folder:FindFirstChild("Enclosure") then
			spaces += 1
		end
	end
	check(spaces == 6, "6 espaces avec machines et enclos", spaces)
	local plot = D("Plot")
	check(plot ~= nil and player:GetAttribute("Plot") == plot.index, "le joueur a reçu un espace", plot and plot.index)
	local plotFolder = gym["Plot" .. plot.index]
	check(plotFolder:GetAttribute("OwnerId") == player.UserId, "l'espace porte le nom de son joueur", plotFolder:GetAttribute("Owner"))
	local _, _, root = alive()
	check((root.Position - plot.spawn).Magnitude < 12, "le joueur apparaît dans son espace", root.Position)
	-- Le revenu des familiers est coupé pour compter les pièces des salles au plus juste (remis plus bas).
	D("Income", false)
	D("Hatching", false)
	-- Pas de fermeture de la porte au milieu du test : il en déclenche une lui-même à la fin.
	D("Cycle", "pause")
	shot("lobby", Vector3.new(0, 95, -175), Vector3.new(0, 0, -55))
	shot("espace", plot.origin + Vector3.new(34, 40, 44), plot.origin + Vector3.new(0, 0, -2))

	-- 2. LES MACHINES ET LES STATS ---------------------------------------------------------------------------------
	local data = D("Data")
	check(data.coins == 0 and data.Speed == 0 and data.Jump == 0 and data.Force == 0 and data.machines.Speed == 1 and data.best == 0, "nouveau joueur : 0 pièce, 0 point, machines niveau 1")
	local _, humanoid, gymRoot = alive()
	check(math.abs(humanoid.WalkSpeed - 16) < 0.01 and math.abs(humanoid.JumpHeight - 7.2) < 0.01, "vitesse 16 et saut 7,2 au départ", humanoid.WalkSpeed .. " / " .. humanoid.JumpHeight)

	-- S'entraîner en continu : on monte sur la machine, chaque pas donne des points, on redescend quand on veut.
	for _, machine in { "Speed", "Force", "Jump" } do
		local before = D("Data")[machine]
		check(D("Train", machine) == true, "on monte sur la machine : " .. machine)
		task.wait(0.4)
		check(player:GetAttribute("Workout") == machine and humanoid.WalkSpeed == 0, machine .. " : le joueur est sur la machine, sans pouvoir marcher", player:GetAttribute("Workout"))
		local busy, why = D("Train", if machine == "Speed" then "Jump" else "Speed")
		check(not busy and why == "busy", machine .. " : pas deux machines en même temps", why)
		task.wait(1)
		local place = plotFolder[machine].PrimaryPart.Position
		shot("entrainement_" .. machine, place + Vector3.new(if machine == "Force" then -13 else 13, 9, 13), place + Vector3.new(if machine == "Force" then -3 else 0, 3.5, 0))
		local gained = D("Data")[machine] - before
		check(gained >= 4 and gained <= 10, machine .. " : 1 point par pas, deux pas par seconde", gained)
		check(D("Train", machine) == true, machine .. " : rappuyer fait descendre de la machine")
		task.wait(0.3)
		check(player:GetAttribute("Workout") == "" and not gymRoot.Anchored and humanoid.WalkSpeed > 0, machine .. " : le joueur est redescendu et peut marcher")
		local stopped = D("Data")[machine]
		task.wait(0.9)
		check(D("Data")[machine] == stopped, machine .. " : plus de points une fois descendu")
	end
	-- Les points donnent les paliers : 120 points = palier 1 (+15 %), 2 500 = palier 2.
	local tier1, tier2 = Config.POINTS[1], Config.POINTS[2]
	check(tier1 == 120 and tier2 == 2500 and Config.POINTS[6] == 400000000, "paliers : 120 points pour le premier (1 minute), 400 000 000 pour le dernier", tier1)
	check((tier2 - tier1) / Config.gain(1) * Config.STEP_SECONDS >= 600, "sans améliorer sa machine, le palier 2 demande plus de 10 minutes")
	for level = 2, #Config.POINTS do
		-- Avec la machine du même niveau, chaque palier demande plus de temps que celui d'avant.
		local seconds = (Config.POINTS[level] - Config.POINTS[level - 1]) / Config.gain(level) * Config.STEP_SECONDS
		local previous = (Config.POINTS[level - 1] - (Config.POINTS[level - 2] or 0)) / Config.gain(level - 1) * Config.STEP_SECONDS
		check(seconds > previous * 1.7, "palier " .. level .. " : presque deux fois plus long que le précédent", math.floor(seconds) .. " s")
	end
	D("Points", "Speed", tier1 - 1)
	check(humanoid.WalkSpeed > 16 and humanoid.WalkSpeed < 16 * 1.15, "119 points de vitesse : presque le palier 1", humanoid.WalkSpeed)
	D("Points", "Speed", tier1)
	check(math.abs(humanoid.WalkSpeed - 16 * 1.15) < 0.01 and player:GetAttribute("Speed") == 1, "120 points de vitesse = palier 1 : +15 %", humanoid.WalkSpeed)
	D("Level", "Jump", 2)
	check(D("Data").Jump == tier2 and math.abs(humanoid.JumpHeight - 7.2 * 1.15 ^ 2) < 0.01, "2 500 points de saut = palier 2", humanoid.JumpHeight)
	check(player:GetAttribute("JumpPoints") == tier2 and player:GetAttribute("SpeedPoints") == tier1, "les points sont envoyés à l'écran")
	check(Pets.roomFactor(1) == 1 and Pets.roomFactor(2) == 3 and Pets.roomFactor(10) == 3 ^ 9, "les familiers d'une salle valent 3 fois ceux de la salle d'avant")
	-- Améliorer une machine : avec des pièces, elle donne plus de points à chaque pas.
	local ok, reason = D("Buy", "Speed")
	check(not ok and reason == "poor", "améliorer le tapis coûte 500 pièces : refusé sans pièces", reason)
	D("Give", 500)
	ok = D("Buy", "Speed")
	data = D("Data")
	check(ok and data.machines.Speed == 2 and data.coins == 0 and player:GetAttribute("SpeedMachine") == 2, "tapis de course niveau 2 pour 500 pièces", data.coins)
	local before = data.Speed
	D("Train", "Speed")
	task.wait(1.3)
	D("Stop")
	local gained = D("Data").Speed - before
	check(gained >= 20 and gained % 10 == 0, "tapis niveau 2 : 10 points par pas", gained)
	D("Give", 777500)
	for _ = 1, 5 do
		D("Buy", "Jump")
	end
	data = D("Data")
	check(data.machines.Jump == 6 and data.coins == 0, "trampoline niveau 6 pour 777 500 pièces en tout (500, puis 6 fois plus à chaque niveau)", data.coins)
	check(Config.gain(6) == 100000, "machine niveau 6 : 100 000 points par pas")
	ok, reason = D("Buy", "Jump")
	check(not ok and reason == "max", "pas de niveau 7", reason)
	D("Reset")
	check(not D("Shortcut", 5), "raccourci fermé tant que la salle 5 n'est pas réussie")

	-- 3. LES SALLES ------------------------------------------------------------------------------------------------
	D("Scale", SCALE)

	-- Le style de chaque salle : une photo de la salle vide, depuis un coin en hauteur.
	for index = 1, #Config.ROOMS do
		local info = D("Room", index)
		shot("style" .. index, Vector3.new(-29, 24, info.zMin + 6), Vector3.new(10, 5, info.center.Z + 10))
	end
	-- Le parcours de lave, vu avant que la lave monte (salle 1, puis la salle 9, la plus longue).
	for _, index in { 1, 9 } do
		local info = D("Room", index)
		local top = info.pillars[#info.pillars].Y
		shot("parcours" .. index, Vector3.new(33, top + 14, info.zMin + 3), Vector3.new(-6, top * 0.35, info.center.Z + 6))
	end

	-- Salle 1 (la bombe). Rester par terre : le sol ne fait pas mal, on ne peut pas couper son fil d'en bas, et à
	-- zéro la bombe élimine le joueur, sans pièces.
	local bombRoom = enter(1)
	local _, lavaHumanoid = alive()
	waitElapsed(1, 30)
	check(lavaHumanoid.Health == 100, "salle 1 : rester par terre ne fait plus mal (plus de lave)", lavaHumanoid.Health)
	check(D("Defuse", 1) == false, "salle 1 : impossible de couper son fil depuis le sol")
	shot("bombe", bombRoom.pillars[#bombRoom.pillars] + Vector3.new(16, 6, -16), bombRoom.pillars[#bombRoom.pillars] + Vector3.new(0, 4, 0))
	local limit = os.clock() + 40 / SCALE
	while lavaHumanoid.Health > 0 and os.clock() < limit do
		task.wait(0.05)
	end
	check(lavaHumanoid.Health <= 0 and D("Room", 1).elapsed >= 58, "salle 1 : à zéro, la bombe élimine le joueur qui n'a pas coupé son fil", D("Room", 1).elapsed)
	check(D("Data").coins == 0, "salle 1 : éliminé par la bombe = 0 pièce", D("Data").coins)
	check(waitState(1, "Idle", 3), "salle 1 : redevient libre quand tout le monde est mort")
	_, _, root = alive()
	task.wait(0.5)
	check((root.Position - plot.spawn).Magnitude < 14, "le mort réapparaît dans son espace", root.Position)
	winRoom(1, true)
	check(D("Data").best == 1, "meilleure salle = 1", D("Data").best)

	-- LE TICKET, LA BOUTIQUE, L'ENCLOS. La salle 1 réussie a donné un ticket de la salle 1.
	local pen = D("Eggs")
	check(pen.tickets == 1 and pen.bag == 0 and pen.places == 5 and pen.pets == 0, "salle 1 réussie = un ticket ; l'enclos a 5 places, vides", pen.tickets)
	check(player:GetAttribute("Tickets") == 1, "le ticket est envoyé à l'écran", player:GetAttribute("Tickets"))
	local placed, why = D("Place", 10, 16)
	check(not placed and why == "noEgg", "sans œuf, rien à poser dans l'enclos", why)
	-- À la boutique, le ticket devient un œuf de dragon ; sa rareté est tirée là. Le joueur le porte sur la tête.
	check(D("Exchange") == 1, "boutique : le ticket devient un œuf")
	pen = D("Eggs")
	check(pen.tickets == 0 and pen.bag == 1 and table.find(Pets.COLLECTIONS[1], pen.first) ~= nil, "le joueur a un œuf d'un des six animaux de la salle 1", pen.first)
	check(string.match(player:GetAttribute("BagNext") or "", "^%a+:%d$") ~= nil, "l'œuf porté est envoyé à l'écran", player:GetAttribute("BagNext"))
	check(D("Exchange") == 0, "boutique : rien à échanger sans ticket")
	-- (Le temps que l'écran du joueur montre l'œuf porté sur sa tête : le test de l'écran le vérifie.)
	task.wait(1.5)
	placed, why = D("Place", -22, -18)
	check(not placed and why == "notInPen", "on ne pose pas un œuf hors de son enclos", why)
	-- Le joueur va dans son enclos et pose l'œuf à ses pieds.
	tp(plot.origin + Vector3.new(6, 4, 12))
	task.wait(0.6)
	check(D("Place") == true, "l'œuf est posé là où se tient le joueur")
	pen = D("Eggs")
	local laid = pen.spots["1"]
	check(pen.bag == 0 and pen.eggs == 1 and laid ~= nil and Pets.DEFS[laid.a].room == 1 and Pets.DEFS[laid.a].rank == laid.q and laid.t ~= nil, "il couve dans l'enclos")
	check(math.abs(laid.x - 6) < 1.5 and math.abs(laid.z - 12) < 1.5, "il est bien à l'endroit où le joueur l'a posé", laid.x .. " ; " .. laid.z)
	check(laid.d == Pets.hatchSeconds(1, laid.q) and laid.t - os.time() <= laid.d and laid.t - os.time() >= laid.d - 3, "temps de couvaison selon la rareté", laid.t - os.time())
	check(player:GetAttribute("BagNext") == "", "le joueur ne porte plus d'œuf")
	tp(plot.origin + Vector3.new(-2, 4, 6))
	task.wait(1)
	shot("oeuf", plot.origin + Vector3.new(-3, 7, 2), plot.origin + Vector3.new(6, 2, 12))
	-- Quand il a fini de couver, il éclot tout seul à la seconde suivante : le familier reçoit sa valeur cachée.
	D("Ripen")
	D("Hatching", true)
	task.wait(1.6)
	D("Hatching", false)
	pen = D("Eggs")
	local born = pen.spots["1"]
	local range = born and Pets.VALUE[born.q]
	check(born ~= nil and born.v ~= nil and born.v >= range[1] and born.v <= range[2], "éclosion : la valeur cachée est dans le palier de sa rareté", born and born.v)
	check(born ~= nil and born.l == Pets.luckPercent(born.v, 1), "éclosion : le familier reçoit son bonus de chance (valeur / 16)", born and born.l)
	check(pen.pets == 1 and pen.equipped == "1" and math.abs(pen.income - Pets.incomeOf(born.a, born.v)) < 0.001, "le familier rapporte selon sa valeur, et suit le joueur", pen.income)
	check(player:GetAttribute("Pet") == born.a and player:GetAttribute("PetRarity") == born.q and player:GetAttribute("Income") == pen.income, "le familier et le revenu sont envoyés à l'écran")
	-- Le joueur reste près de son enclos le temps que le test de l'écran voie le familier s'y promener (de loin,
	-- les familiers ne bougent plus).
	task.wait(8)

	-- Salle 2 (météorites) : rester immobile fait perdre de la vie.
	enter(2)
	local _, meteorHumanoid = alive()
	limit = os.clock() + 40 / SCALE
	while meteorHumanoid.Health >= 100 and os.clock() < limit do
		task.wait(0.05)
	end
	check(meteorHumanoid.Health < 100, "salle 2 : une météorite blesse un joueur immobile", meteorHumanoid.Health)
	meteorHumanoid.Health = 0
	waitState(2, "Idle", 3)
	winRoom(2, true)

	-- Salle 3 (explosions) : immobile = blessé ; puis mort après 30 secondes = moitié des pièces.
	enter(3)
	local _, blastHumanoid = alive()
	limit = os.clock() + 40 / SCALE
	while blastHumanoid.Health >= 100 and os.clock() < limit do
		task.wait(0.05)
	end
	check(blastHumanoid.Health < 100, "salle 3 : une explosion blesse un joueur immobile", blastHumanoid.Health)
	god(true)
	waitElapsed(3, 36)
	local before = D("Data").coins
	god(false)
	blastHumanoid.Health = 0
	task.wait(0.5)
	check(D("Data").coins - before == 0, "salle 3 : mort après 30 secondes = aucune pièce", D("Data").coins - before)
	waitState(3, "Idle", 3)
	winRoom(3, true)

	-- Salle 4 (lave + plafond). Sans pousser : écrasé. Les appuis ne comptent que sur la dernière plateforme, et
	-- pas plus de 8 par seconde.
	local room = enter(4)
	god(true)
	tp(safeSpot(4, room))
	waitElapsed(4, 33)
	check(workspace.Rooms.Room4:GetAttribute("Pushing") == true, "salle 4 : le plafond descend après 30 secondes")
	check(D("Push", 60, false) <= 2, "salle 4 : 60 appuis d'un coup = 1 ou 2 comptés (limite de 8 par seconde)")
	tp(room.pillars[#room.pillars - 3] + Vector3.new(0, 4, 0))
	task.wait(0.3)
	check(D("Push", 1, true) == 0, "salle 4 : pousser loin de la dernière plateforme ne compte pas")
	tp(safeSpot(4, room))
	local _, crushHumanoid = alive()
	limit = os.clock() + 40 / SCALE
	while crushHumanoid.Health > 0 and os.clock() < limit do
		task.wait(0.05)
	end
	check(crushHumanoid.Health <= 0, "salle 4 : sans pousser, le plafond écrase", D("Room", 4).elapsed)
	waitState(4, "Idle", 3)
	check(crushed(4, 5), "salle 4 : force 0 à 5 appuis par seconde = écrasé")
	check(crushed(4, 6), "salle 4 : force 0 même en appuyant au plus vite (6 par seconde) = écrasé")
	D("Level", "Force", 1)
	winRoom(4, true)
	check(workspace.Rooms.Room4:GetAttribute("Ceiling") == 1, "salle 4 : le plafond remonte après la manche", workspace.Rooms.Room4:GetAttribute("Ceiling"))

	winRoom(5, true)

	-- Salle 6 (la mélodie). Ne rien faire : éliminé à la fin du temps.
	enter(6)
	local _, idleHumanoid = alive()
	limit = os.clock() + (Config.DURATION + 4) / SCALE
	while idleHumanoid.Health > 0 and os.clock() < limit do
		task.wait(0.05)
	end
	check(idleHumanoid.Health <= 0, "salle 6 : mélodie pas finie à temps = éliminé")
	waitState(6, "Idle", 3)
	-- Une fausse note blesse ; puis la bonne suite, manche après manche, ouvre la porte avant la fin du temps.
	local melodyBefore = D("Data").coins
	local melodyRoom = enter(6)
	local function waitPlay(): any
		local stop = os.clock() + 6
		while os.clock() < stop do
			local info = D("Room", 6)
			if info.state ~= "Event" or (info.melody and info.melody.phase == "Play") then
				return info
			end
			task.wait(0.03)
		end
		return D("Room", 6)
	end
	local function step(note: number)
		tp(melodyRoom.melodyPads[note] + Vector3.new(0, 4, 0))
		task.wait(0.12)
		tp(melodyRoom.center + Vector3.new(0, 4, 0))
		task.wait(0.12)
	end
	local info = waitPlay()
	check(info.melody ~= nil and #info.melody.sequence == 3, "salle 6 : la première suite a 3 notes", info.melody and #info.melody.sequence)
	local _, melodyHumanoid = alive()
	step(if info.melody.sequence[1] == 1 then 2 else 1)
	check(melodyHumanoid.Health == 100 - Config.DAMAGE.Melody, "salle 6 : une fausse note blesse", melodyHumanoid.Health)
	local snapped = false
	while true do
		info = waitPlay()
		if info.state ~= "Event" or not info.melody or info.melody.phase ~= "Play" then
			break
		end
		if not snapped and info.melody.round == 2 then
			snapped = true
			shot("salle6", Vector3.new(-28, 16, melodyRoom.zMin + 6), Vector3.new(4, 6, melodyRoom.center.Z + 14))
			info = waitPlay()
		end
		for i = info.melody.index, #info.melody.sequence do
			step(info.melody.sequence[i])
		end
	end
	info = D("Room", 6)
	check(info.state == "Open" and info.elapsed < Config.DURATION, "salle 6 : la mélodie réussie ouvre la porte avant la fin", info.state .. " à " .. math.floor(info.elapsed) .. " s")
	local melodyGain = D("Data").coins - melodyBefore
	check(melodyGain == 0, "salle 6 : aucune pièce, seulement le ticket", melodyGain)
	tp(D("Sas", 6))
	waitState(6, "Idle", Config.OPEN / SCALE + 3)
	D("Level", "Force", 1)
	check(crushed(7, 6), "salle 7 : force 1 même en appuyant au plus vite = écrasé")
	D("Level", "Force", 2)
	winRoom(7)
	winRoom(8, true)
	winRoom(9, true)
	D("Level", "Force", 3)
	check(crushed(10, 6), "salle 10 : force 3 même en appuyant au plus vite = écrasé")
	D("Level", "Force", 4)
	winRoom(10, true)
	check(D("Data").best == 10, "meilleure salle = 10", D("Data").best)
	-- Un ticket par salle réussie depuis le début.
	local tickets = D("Eggs").tickets
	check(tickets >= 9, "chaque salle réussie a donné son ticket", tickets)
	check(D("Exchange") == tickets and D("Eggs").bag == tickets, "boutique : tous les tickets deviennent des œufs")

	-- L'ENCLOS : 5 places au départ (niveau 1). Plein, on l'améliore ; chaque niveau coûte 6 fois le précédent.
	for i = 1, 4 do
		check(D("Place", 2 + i * 5, 20) == true, "œuf posé dans l'enclos (" .. i .. ")")
	end
	pen = D("Eggs")
	check(pen.pets == 1 and pen.eggs == 4, "l'enclos est plein : le dragon et 4 œufs qui couvent", pen.pets + pen.eggs)
	placed, why = D("Place", 10, 8)
	check(not placed and why == "penFull", "enclos plein : impossible de poser un œuf de plus", why)
	check(Pets.spotPrice(5) == 1000 and Pets.spotPrice(6) == 6000 and Pets.spotPrice(7) == 36000 and Pets.spotPrice(Pets.SPOTS_MAX) == nil, "prix des niveaux de l'enclos : 1 000, 6 000, 36 000...")
	D("Give", -D("Data").coins)
	check(D("Upgrade") == false and D("Eggs").places == 5, "pas d'amélioration de l'enclos sans les 1 000 pièces")
	D("Give", 1000)
	check(D("Upgrade") == true and D("Eggs").places == 6 and D("Data").coins == 0 and player:GetAttribute("Places") == 6, "enclos niveau 2 pour 1 000 pièces : 6 places")
	check(D("Place", 12, 8) == true, "un œuf est posé sur la nouvelle place")
	D("Hatch")
	pen = D("Eggs")
	check(pen.pets == 6 and pen.eggs == 0, "les 6 œufs sont éclos", pen.pets)
	-- Deux familiers de la même rareté ne rapportent pas pareil ; le revenu est la somme de l'enclos.
	local sum = 0
	for _, spot in pen.spots do
		sum += Pets.incomeOf(spot.a, spot.v)
	end
	check(math.abs(sum - pen.income) < 0.001 and player:GetAttribute("Income") == pen.income, "le revenu = la somme des familiers de l'enclos", pen.income)
	-- Vendre un familier : des pièces, et sa place est libre (les doublons se gèrent comme ça).
	local sold = pen.spots["1"]
	check(D("Sell", 1) == true and D("Data").coins == Pets.sellPrice(sold.a, sold.v) and D("Eggs").pets == 5, "vendre un familier rapporte ce qu'il vaut", D("Data").coins)
	check(D("Place", 20, 20) == true, "la place libérée reçoit un nouvel œuf")
	-- Le revenu tombe chaque seconde quand il n'est pas coupé.
	D("Clear")
	D("Pet", "Golem", 5)
	D("Pet", "Golem", 5)
	pen = D("Eggs")
	check(pen.pets == 2 and math.abs(pen.income - 2 * Pets.incomeOf("Golem", 600)) < 0.001, "on peut avoir deux fois le même familier (deux golems légendaires)", pen.income)
	local coinsBefore = D("Data").coins
	D("Income", true)
	task.wait(3.3)
	D("Income", false)
	local earned = D("Data").coins - coinsBefore
	check(earned >= pen.income * 2 and earned <= pen.income * 4.5, "en 3 secondes, l'enclos a rapporté environ 3 fois son revenu", earned .. " pour " .. pen.income .. " par seconde")

	-- LA GRANDE PLUIE DE MÉTÉORITES : un joueur qui court à la vitesse du niveau demandé arrive dans le rond vert,
	-- celui du niveau d'en dessous n'arrive pas. Le test fait avancer le personnage lui-même, en temps réel.
	local function rushRun(index: number, speed: number): (boolean, number)
		D("Scale", SCALE)
		enter(index)
		D("Scale", 1)
		local character, runner, body = alive()
		local waves = 0
		local previous = os.clock()
		while runner.Health > 0 and waves < 3 do
			local now = os.clock()
			local dt = now - previous
			previous = now
			local info = D("Room", index)
			if info.state ~= "Event" then
				break
			end
			local rush = info.rush
			waves = rush.waves
			-- Soigné à chaque image : une petite météorite ne le tue pas, la grande pluie (100 dégâts) si.
			runner.Health = runner.MaxHealth
			if rush.phase == "ready" and rush.hold then
				-- Avant le départ : au bord du rond de départ, du côté du rond d'arrivée (comme un bon joueur).
				local toward = Vector3.new(rush.target.X - rush.hold.X, 0, rush.target.Z - rush.hold.Z).Unit
				character:PivotTo(CFrame.new(Vector3.new(rush.hold.X, body.Position.Y, rush.hold.Z) + toward * 6))
			elseif rush.phase == "warn" then
				-- Court tout droit vers le rond vert et s'arrête 5 studs avant son milieu.
				local position = body.Position
				local delta = Vector3.new(rush.target.X - position.X, 0, rush.target.Z - position.Z)
				if delta.Magnitude > 5 then
					character:PivotTo(CFrame.new(position + delta.Unit * math.min(speed * dt, delta.Magnitude - 5)))
				end
			end
			task.wait()
		end
		local survived = runner.Health > 0
		if survived then
			runner.Health = 0
		end
		D("Scale", SCALE)
		waitState(index, "Idle", 3)
		return survived, waves
	end
	for _, case in { { 2, 1 } } do
		local index, level = case[1], case[2]
		local survived, waves = rushRun(index, Config.walkSpeed(level))
		check(survived and waves >= 3, `salle {index} : la vitesse du niveau {level} suffit pour 3 grandes pluies`, waves)
		survived, waves = rushRun(index, Config.walkSpeed(level - 1))
		check(not survived, `salle {index} : la vitesse du niveau {level - 1} n'arrive pas à temps`, waves)
	end
	-- LA SALLE DE COURSE (salle 8) : le joueur tourne en grand cercle autour de la salle. À la vitesse du niveau
	-- demandé, le monstre ne le rattrape pas ; à celle du niveau d'en dessous, il l'attrape.
	local function chaseRun(index: number, speed: number, seconds: number): (boolean, number)
		D("Scale", SCALE)
		enter(index)
		D("Scale", 1)
		local character, runner, body = alive()
		local center = D("Room", index).center
		local radius, angle = 27, -math.pi / 2
		local started, previous = os.clock(), os.clock()
		local closest = math.huge
		while runner.Health > 0 and os.clock() - started < seconds do
			local now = os.clock()
			angle += speed * (now - previous) / radius
			previous = now
			character:PivotTo(CFrame.new(center + Vector3.new(math.cos(angle) * radius, 3, math.sin(angle) * radius)))
			local info = D("Room", index)
			if info.state ~= "Event" then
				break
			end
			if info.chaser and info.chaser.moving then
				closest = math.min(closest, info.chaser.distance)
			end
			task.wait()
		end
		local survived = runner.Health > 0
		if survived then
			runner.Health = 0
		end
		D("Scale", SCALE)
		waitState(index, "Idle", 3)
		return survived, closest
	end
	local need = Config.ROOMS[8].need.Speed
	local escaped, closest = chaseRun(8, Config.walkSpeed(need), 32)
	check(escaped, `salle 8 : en courant à la vitesse du niveau {need}, le monstre ne rattrape pas le joueur en 30 secondes`, string.format("au plus près : %.1f studs", closest))
	escaped, closest = chaseRun(8, Config.walkSpeed(need - 1), 52)
	check(not escaped, `salle 8 : à la vitesse du niveau {need - 1}, le monstre attrape le joueur`, string.format("au plus près : %.1f studs", closest))
	escaped = chaseRun(8, Config.walkSpeed(need) * Config.WALK_RATIO, 40)
	check(not escaped, `salle 8 : en marchant sans courir, même au niveau {need}, le monstre attrape le joueur`)
	D("Scale", 1)
	-- Une photo de chaque animal dans ses 4 raretés, à côté du joueur dans l'allée.
	for _, name in { "Dragon", "Rock", "Rabbit", "Golem", "Owl" } do
		D("Clear")
		for _, rarity in { 1, 2, 3, 4 } do
			D("Pet", name, rarity)
			tp(Vector3.new(0, 4, 6))
			task.wait(0.9)
			local _, _, body = alive()
			local view = body.CFrame
			shot("animal_" .. name .. rarity, (view * CFrame.new(1.5, 2.5, -11)).Position, (view * CFrame.new(1.6, 0.4, 1.3)).Position)
		end
	end
	-- Les animaux en mouvement : le joueur marche tout droit, la photo est prise pendant qu'il avance.
	for _, name in { "Dragon", "Rock", "Rabbit", "Golem", "Owl" } do
		D("Clear")
		D("Pet", name, 3)
		tp(Vector3.new(0, 4, -22))
		task.wait(0.8)
		local _, walker, body = alive()
		walker:MoveTo(Vector3.new(0, 0, 27))
		task.wait(0.5)
		-- shot() attend 0,7 s avant la photo : la caméra vise l'endroit où le joueur sera à ce moment-là.
		local ahead = body.Position + Vector3.new(0, 0, walker.WalkSpeed * Config.WALK_RATIO * 0.7)
		shot("marche_" .. name, ahead + Vector3.new(11, 3, 7), ahead + Vector3.new(-2, -0.5, -1))
		check(body.Position.Z > -14, "le joueur a marché pendant la photo de " .. name, body.Position.Z)
	end
	-- Un enclos bien rempli : des familiers de toutes les raretés qui se promènent, et deux œufs qui couvent.
	D("Clear")
	for i, name in { "Dragon", "Rock", "Rabbit", "Golem", "Owl", "Dragon", "Golem", "Owl" } do
		D("Pet", name, (i - 1) % 4 + 1)
	end
	D("Egg", "Rabbit", 3)
	D("Egg", "Dragon", 5)
	D("Give", -D("Data").coins)
	D("Give", 216000 + 1296000)
	check(D("Upgrade") == true and D("Upgrade") == true and D("Eggs").places == 10 and D("Data").coins == 0, "deux niveaux d'enclos de plus : 216 000 puis 1 296 000 pièces, 10 places")
	check(D("Place", 2, 8) == true and D("Place", 22, 26) == true, "deux œufs posés dans l'enclos")
	tp(plot.origin + Vector3.new(-13, 4, -3))
	task.wait(5)
	shot("enclos", plot.origin + Vector3.new(10, 26, -16), plot.origin + Vector3.new(10, 1, 16))
	shot("enclos_pres", plot.origin + Vector3.new(-12, 7, -4), plot.origin + Vector3.new(8, 2, 14))
	D("OpenPets")
	task.wait(0.6)
	shot("fenetre_familiers", plot.origin + Vector3.new(-12, 7, -4), plot.origin + Vector3.new(8, 2, 14))
	shot("stands", Vector3.new(0, 9, -22), Vector3.new(0, 5, 14))
	shot("gagnants", Vector3.new(-14, 12, 1036), Vector3.new(2, 5, 1058))

	-- 4. LE RACCOURCI ----------------------------------------------------------------------------------------------
	tp(plot.spawn)
	task.wait(0.5)
	check(D("Shortcut", 5) == true, "raccourci ouvert après la salle 5")
	task.wait(0.5)
	_, _, root = alive()
	check(math.abs(root.Position.Z - D("Sas", 5).Z) < 6, "le raccourci mène devant la salle 6", root.Position)
	shot("couloir", Vector3.new(0, 9, D("Sas", 5).Z - 9), Vector3.new(0, 10, D("Sas", 5).Z + 10))

	-- 5. LA FERMETURE DE LA PORTE ET LA SALLE CHANCEUSE -----------------------------------------------------------
	tp(plot.spawn)
	task.wait(0.5)
	D("Clear")
	local cycle = D("Cycle")
	check(cycle.state == "Open" and cycle.gateOpen and cycle.room == 0 and cycle.luck == 1, "la porte du lobby est ouverte, aucune salle chanceuse au début", cycle.state)
	local every = workspace:GetAttribute("CycleEnds") - workspace:GetServerTimeNow()
	check(every > Config.CYCLE.every - 5 and every <= Config.CYCLE.every + 1, "la fermeture est prévue dans 5 minutes", every)
	-- Un œuf légendaire couve dans l'enclos : la fermeture doit le faire avancer de 100 secondes en 10.
	D("Egg", "Dragon", 5)
	check(D("Place", 10, 16) == true, "un œuf légendaire est posé avant la fermeture")
	local before = D("Eggs").spots["1"].t - os.time()
	D("Cycle", "close")
	task.wait(1.2)
	cycle = D("Cycle")
	check(cycle.state == "Closed" and not cycle.gateOpen and workspace:GetAttribute("CycleState") == "Closed", "la porte du lobby se ferme", cycle.state)
	check(gym.Gate.CanCollide == true, "la porte fermée arrête les joueurs")
	shot("porte_fermee", Vector3.new(0, 14, -16), Vector3.new(0, 7, 30))
	task.wait(Config.CYCLE.closed + 0.5)
	cycle = D("Cycle")
	check(cycle.state == "Open" and cycle.gateOpen and gym.Gate.CanCollide == false, "elle se rouvre 10 secondes plus tard", cycle.state)
	local after = D("Eggs").spots["1"].t - os.time()
	local won = before - after
	local wanted = Config.CYCLE.closed * Config.CYCLE.speed
	check(won >= wanted - 4 and won <= wanted + 6, "pendant la fermeture, l'œuf a couvé 10 fois plus vite", won)
	check(cycle.room >= 1 and cycle.room <= #Config.ROOMS and cycle.luck >= 2 and cycle.luck <= 6, "une salle au hasard reçoit un bonus de chance", cycle.room .. " x" .. cycle.luck)
	check(workspace:GetAttribute("LuckRoom") == cycle.room and workspace:GetAttribute("Luck") == cycle.luck, "le bonus est envoyé à l'écran")
	task.wait(1)
	shot("salle_chanceuse", Vector3.new(0, 14, -16), Vector3.new(0, 7, 30))
	-- Un ticket gagné dans la salle chanceuse garde le bonus ; ailleurs, c'est un ticket normal.
	D("Cycle", "luck", 3, 6)
	D("Ticket", 3)
	D("Ticket", 2)
	pen = D("Eggs")
	check(pen.tickets == 2 and pen.lucky == 1, "seul le ticket de la salle chanceuse est chanceux", pen.lucky)
	check(D("Exchange") == 2 and D("Eggs").bag == pen.bag + 2 and D("Eggs").tickets == 0, "les deux tickets deviennent des œufs", D("Eggs").bag)
	-- Le bonus +500 % multiplie par 6 les chances de tout ce qui n'est pas commun.
	local plain, lucky = Pets.odds(3), Pets.odds(3, 6)
	check(lucky[1] == plain[1] and lucky[2] == plain[2] * 6 and lucky[4] == plain[4] * 6, "bonus +500 % : 6 fois plus de chances d'un œuf rare", lucky[4])
	local rares, total = 0, 4000
	local dice = Random.new(7)
	for _ = 1, total do
		if Pets.roll(dice, 3, 6) >= 3 then
			rares += 1
		end
	end
	local share = (lucky[3] + lucky[4] + lucky[5] + lucky[6]) / (lucky[1] + lucky[2] + lucky[3] + lucky[4] + lucky[5] + lucky[6])
	check(math.abs(rares / total - share) < 0.04, "le tirage suit bien ces chances", rares / total)
	-- LE FAMILIER QUI SUIT donne un bonus de chance selon sa valeur cachée, x 1,15 par salle ; il s'ajoute à la salle.
	check(Pets.luckPercent(96, 1) == 6 and Pets.luckPercent(800, 1) == 50 and Pets.luckPercent(800, 2) == 57 and Pets.luckPercent(1, 1) == 0 and Pets.luckPercent(800, 10) < 180, "bonus du familier : valeur / 16, x 1,15 par salle, moins de 180 % à la salle 10", Pets.luckPercent(800, 10))
	D("Exchange")
	D("Pet", "Dragon", 5)
	pen = D("Eggs")
	local follower = pen.spots[pen.equipped]
	check(follower ~= nil and follower.l == 38 and player:GetAttribute("PetLuck") == 38, "un légendaire de valeur 600 qui suit : +38 % de chance", follower and follower.l)
	check(string.find(player:GetAttribute("Spots"), ":38$") ~= nil and Pets.decode(player:GetAttribute("Spots"))[pen.equipped].l == 38, "le bonus du familier est envoyé à l'écran", player:GetAttribute("Spots"))
	D("Ticket", 3)
	check(D("Eggs").keys == "3:6.38", "salle à +500 % et familier à +38 % : le ticket garde 6,38", D("Eggs").keys)
	D("Cycle", "luck", 0, 1)
	D("Ticket", 2)
	check(D("Eggs").keys == "2:1.38 3:6.38", "sans salle chanceuse, le familier seul donne un ticket à 1,38", D("Eggs").keys)
	local income = D("Eggs").income
	check(income > 0, "le familier qui suit rapporte quand même ses pièces", income)
	check(D("Exchange") == 2 and D("Eggs").tickets == 0, "les tickets chanceux deviennent des œufs")
	D("Pet", "")
	D("Ticket", 2)
	check(D("Eggs").keys == "2", "sans familier qui suit ni salle chanceuse : ticket normal", D("Eggs").keys)
	D("Exchange")

	-- 6. LES COLLECTIONS : six animaux par salle (salles 1 à 3), du plus courant au super rare ----------------------
	check(#Pets.ODDS == 6 and #Pets.VALUE == 6 and #Pets.HATCH == 6 and #Pets.RARITIES == 6, "six rangs, du commun au super rare")
	local oddsTotal = 0
	for _, weight in Pets.odds(1) do
		oddsTotal += weight
	end
	check(oddsTotal == 100 and Pets.ODDS[1] == 45 and Pets.ODDS[6] == 0.5, "chances : 45 % pour le plus courant, 0,5 % pour le super rare", oddsTotal)
	check(Pets.VALUE[1][2] == 50 and Pets.VALUE[6][1] == 1600 and Pets.VALUE[6][2] == 3200, "valeurs : 1 à 50 pour le plus courant, 1 600 à 3 200 pour le super rare")
	check(Pets.animalOf(1, 6, "x") == "Fox" and Pets.animalOf(2, 6, "x") == "Badger" and Pets.animalOf(3, 6, "x") == "Horse", "super rares : renard, blaireau, cheval")
	check(Pets.animalOf(1, 1, "x") == "Bunny" and Pets.animalOf(4, 6, "x") == "Bear" and Pets.animalOf(5, 6, "x") == "Jaguar" and Pets.animalOf(6, 6, "Owl") == "Owl", "ours et jaguar super rares ; salle sans collection : l'animal de la salle")
	check(Pets.luckPercent(3200, 1) == 100 and Pets.luckPercent(1600, 1) == 50, "bonus de chance d'un super rare qui suit : 50 à 100 %", Pets.luckPercent(3200, 1))
	local visuals = game:GetService("ReplicatedStorage"):FindFirstChild("PetVisuals")
	for room, list in Pets.COLLECTIONS do
		local missing = {}
		for rank, name in list do
			local model = visuals and visuals:FindFirstChild(name)
			local def = Pets.DEFS[name]
			if not (model and model:FindFirstChild("RigRoot") and model:FindFirstChild("Walk", true) and model:FindFirstChild("Idle", true) and def and def.room == room and def.rank == rank) then
				table.insert(missing, name)
			end
		end
		check(#list == 6 and #missing == 0, `collection de la salle {room} : six modèles articulés avec repos et marche`, table.concat(missing, " "))
	end
	-- Un ticket de la salle 2 devient un œuf d'un des six animaux de la salle 2, celui du rang tiré.
	D("Pet", "")
	D("Clear")
	D("EmptyBag")
	for _ = 1, 12 do
		D("Ticket", 2)
	end
	D("Exchange")
	local wrong = 0
	for _ = 1, 12 do
		local egg = D("Eggs")
		local def = Pets.DEFS[egg.first]
		if not def or def.room ~= 2 then
			wrong += 1
		end
		D("Place", 10, 16)
		local laidEgg = D("Eggs").spots["1"]
		if not laidEgg or laidEgg.a ~= egg.first or (def and def.rank ~= laidEgg.q) then
			wrong += 1
		end
		D("Clear")
	end
	check(wrong == 0 and D("Eggs").bag == 0, "12 tickets de la salle 2 : 12 œufs d'animaux de la salle 2, l'animal suit le rang", wrong)
	-- Les photos : les six animaux de chaque collection dans l'enclos.
	tp(plot.origin + Vector3.new(-2, 4, 6))
	for room, list in Pets.COLLECTIONS do
		D("Clear")
		for rank, name in list do
			D("Pet", name, rank)
		end
		check(D("Eggs").pets == 6, `les six animaux de la salle {room} sont dans l'enclos`)
		task.wait(5)
		shot("collection" .. room, plot.origin + Vector3.new(10, 16, -6), plot.origin + Vector3.new(10, 1, 16))
	end
	D("Pet", "")
	D("Clear")

	log("Info", "[SURVIVE] TEST:done")
end

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
		if def.Lava then
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
		if snap then
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
		check(won, `salle {index} : gagnée après 60 secondes`, D("Room", index).state)
		local expected = Config.REWARD_FULL * index + if index == #Config.ROOMS then Config.FINAL_BONUS else 0
		expected = math.floor(expected * (bonus or 1) + 0.5)
		-- Un familier déjà trouvé donne des pièces en plus (100, 300, 1 000 ou 5 000).
		local gained = D("Data").coins - before
		check(gained == expected or table.find(Pets.DUPLICATE_COINS, gained - expected) ~= nil, `salle {index} : +{expected} pièces`, gained)
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
	shot("lobby", Vector3.new(0, 95, -175), Vector3.new(0, 0, -55))
	shot("espace", plot.origin + Vector3.new(34, 40, 44), plot.origin + Vector3.new(0, 0, -2))

	-- 2. LA SALLE DE SPORT -----------------------------------------------------------------------------------------
	local data = D("Data")
	check(data.coins == 0 and data.Speed == 0 and data.Jump == 0 and data.Force == 0 and data.best == 0, "nouveau joueur : 0 pièce, niveaux 0")
	local _, humanoid, gymRoot = alive()
	check(math.abs(humanoid.WalkSpeed - 16) < 0.01 and math.abs(humanoid.JumpHeight - 7.2) < 0.01, "vitesse 16 et saut 7,2 au départ", humanoid.WalkSpeed .. " / " .. humanoid.JumpHeight)

	-- S'entraîner sur chaque machine : le niveau 1 est gratuit, le joueur est posé sur la machine quelques secondes.
	for _, machine in { "Speed", "Force", "Jump" } do
		local ok = D("Train", machine)
		check(ok == true, "entraînement gratuit accepté : " .. machine)
		task.wait(0.4)
		check(player:GetAttribute("Workout") == machine and humanoid.WalkSpeed == 0, machine .. " : le joueur est sur la machine, sans pouvoir marcher", player:GetAttribute("Workout"))
		local busy, why = D("Train", machine)
		check(not busy and why == "busy", machine .. " : pas deux entraînements en même temps", why)
		task.wait(1.2)
		local place = plotFolder[machine].PrimaryPart.Position
		shot("entrainement_" .. machine, place + Vector3.new(if machine == "Force" then -13 else 13, 9, 13), place + Vector3.new(if machine == "Force" then -3 else 0, 3.5, 0))
		task.wait(Config.WORKOUT_SECONDS - 2.6)
		check(D("Data")[machine] == 1 and player:GetAttribute("Workout") == "" and not gymRoot.Anchored, machine .. " : niveau 1 gagné à la fin de l'entraînement", D("Data")[machine])
	end
	check(math.abs(humanoid.WalkSpeed - 16 * 1.15) < 0.01 and math.abs(humanoid.JumpHeight - 7.2 * 1.15) < 0.01, "niveau 1 : +15 % de vitesse et de saut", humanoid.WalkSpeed .. " / " .. humanoid.JumpHeight)
	local ok, reason = D("Train", "Speed")
	check(not ok and reason == "poor", "le niveau 2 coûte 500 pièces : entraînement refusé sans pièces", reason)
	D("Give", 500)
	ok = D("Buy", "Speed")
	data = D("Data")
	check(ok and data.Speed == 2 and data.coins == 0, "tapis de course niveau 2 pour 500 pièces", data.coins)
	check(math.abs(humanoid.WalkSpeed - 16 * 1.15 ^ 2) < 0.01, "vitesse du niveau 2", humanoid.WalkSpeed)
	D("Give", 41000)
	for _ = 1, 5 do
		D("Buy", "Jump")
	end
	data = D("Data")
	check(data.Jump == 6 and data.coins == 0, "trampoline niveau 6 pour 41 000 pièces en tout", data.coins)
	check(math.abs(humanoid.JumpHeight - 7.2 * 1.15 ^ 6) < 0.01, "saut du niveau 6", humanoid.JumpHeight)
	ok, reason = D("Buy", "Jump")
	check(not ok and reason == "max", "pas de niveau 7", reason)
	check(player:GetAttribute("Jump") == 6 and player.leaderstats.Coins.Value == 0, "niveaux et pièces envoyés à l'écran")
	D("Reset")
	check(not D("Shortcut", 5), "raccourci fermé tant que la salle 5 n'est pas réussie")

	-- 3. LES SALLES ------------------------------------------------------------------------------------------------
	D("Scale", SCALE)

	-- Le parcours de lave, vu avant que la lave monte (salle 1, puis la salle 9, la plus longue).
	for _, index in { 1, 9 } do
		local info = D("Room", index)
		local top = info.pillars[#info.pillars].Y
		shot("parcours" .. index, Vector3.new(33, top + 14, info.zMin + 3), Vector3.new(-6, top * 0.35, info.center.Z + 6))
	end

	-- Salle 1 (lave) : rester par terre = mourir, sans pièces.
	enter(1)
	local _, lavaHumanoid = alive()
	local limit = os.clock() + 30 / SCALE
	while lavaHumanoid.Health > 0 and os.clock() < limit do
		task.wait(0.05)
	end
	check(lavaHumanoid.Health <= 0, "salle 1 : rester par terre dans la lave tue")
	check(D("Data").coins == 0, "salle 1 : mort avant 30 secondes = 0 pièce", D("Data").coins)
	check(waitState(1, "Idle", 3), "salle 1 : redevient libre quand tout le monde est mort")
	_, _, root = alive()
	task.wait(0.5)
	check((root.Position - plot.spawn).Magnitude < 14, "le mort réapparaît dans son espace", root.Position)
	winRoom(1, true)
	check(D("Data").best == 1, "meilleure salle = 1", D("Data").best)

	-- L'ŒUF DE LA SALLE : la salle 1 réussie a mis un œuf de dragon dans l'enclos, où il couve.
	local eggs = D("Eggs")
	check(eggs.eggs == 1 and eggs.first == "Dragon" and eggs.count == 0, "salle 1 réussie = un œuf de dragon qui couve dans l'enclos", eggs.eggs .. " " .. eggs.first)
	check(string.match(player:GetAttribute("Eggs") or "", "^Dragon|%d+$") ~= nil and player:GetAttribute("EggCount") == 1, "l'œuf est envoyé à l'écran", player:GetAttribute("Eggs"))
	tp(plot.spawn)
	task.wait(1)
	shot("nid", plot.origin + Vector3.new(4, 9, -8), plot.origin + Vector3.new(0, 1, 6))
	-- Quand il a fini de couver, il éclot tout seul à la seconde suivante.
	D("Ripen")
	D("Hatching", true)
	task.wait(1.6)
	D("Hatching", false)
	eggs = D("Eggs")
	check(eggs.eggs == 0 and (eggs.pets.Dragon or 0) >= 1 and eggs.equipped == "Dragon", "l'œuf éclot tout seul : le dragon entre dans la collection et suit le joueur", tostring(eggs.pets.Dragon))
	check(eggs.count == 1 and math.abs(eggs.income - Pets.incomeOf("Dragon", eggs.pets.Dragon)) < 0.001, "la collection a 1 familier, avec son revenu", eggs.income)
	check(player:GetAttribute("Pet") == "Dragon" and player:GetAttribute("PetRarity") == eggs.pets.Dragon and player:GetAttribute("Income") == eggs.income, "le familier et le revenu sont envoyés à l'écran")

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
	check(D("Data").coins - before == 150, "salle 3 : mort après 30 secondes = 150 pièces", D("Data").coins - before)
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
	check(melodyGain == 600 or table.find(Pets.DUPLICATE_COINS, melodyGain - 600) ~= nil, "salle 6 : +600 pièces", melodyGain)
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
	-- Autant d'œufs qu'on veut couvent en même temps : un par salle réussie depuis le début.
	local waiting = D("Eggs").eggs
	check(waiting >= 9, "tous les œufs des salles réussies couvent en même temps dans l'enclos", waiting)
	check(D("Hatch") == waiting and D("Eggs").eggs == 0 and D("Eggs").count >= 3, "ils éclosent tous : la collection se remplit", D("Eggs").bits)

	-- LA COLLECTION ET LE REVENU. Un familier nouveau compte une fois ; le même une 2e fois ne change rien.
	local before = D("Eggs")
	D("Pet", "Golem", 4)
	local after = D("Eggs")
	check(after.count == before.count + 1 and math.abs(after.income - before.income - Pets.incomeOf("Golem", 4)) < 0.001, "golem légendaire : +60 pièces par seconde", after.income - before.income)
	D("Pet", "Golem", 4)
	check(D("Eggs").count == after.count, "le même familier une 2e fois ne compte pas deux fois")
	check(math.abs(after.income - Pets.income(Pets.decode(after.bits))) < 0.001, "le revenu = la somme de la collection", after.bits)
	-- Le revenu tombe chaque seconde quand il n'est pas coupé.
	local coinsBefore = D("Data").coins
	D("Income", true)
	task.wait(3.3)
	D("Income", false)
	local earned = D("Data").coins - coinsBefore
	check(earned >= after.income * 2 and earned <= after.income * 4.5, "en 3 secondes, la collection a rapporté environ 3 fois son revenu", earned .. " pour " .. after.income .. " par seconde")

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
			if rush.phase == "warn" then
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
	for _, case in { { 2, 1 }, { 8, 3 } } do
		local index, level = case[1], case[2]
		local survived, waves = rushRun(index, Config.walkSpeed(level))
		check(survived and waves >= 3, `salle {index} : la vitesse du niveau {level} suffit pour 3 grandes pluies`, waves)
		survived, waves = rushRun(index, Config.walkSpeed(level - 1))
		check(not survived, `salle {index} : la vitesse du niveau {level - 1} n'arrive pas à temps`, waves)
	end
	D("Scale", 1)
	-- Une photo de chaque animal dans ses 4 raretés, à côté du joueur dans l'allée (la collection se remplit).
	for _, name in { "Dragon", "Rock", "Rabbit", "Golem", "Owl" } do
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
		D("Pet", name, 3)
		tp(Vector3.new(0, 4, -22))
		task.wait(0.8)
		local _, walker, body = alive()
		walker:MoveTo(Vector3.new(0, 0, 27))
		task.wait(0.5)
		-- shot() attend 0,7 s avant la photo : la caméra vise l'endroit où le joueur sera à ce moment-là.
		local ahead = body.Position + Vector3.new(0, 0, walker.WalkSpeed * 0.7)
		shot("marche_" .. name, ahead + Vector3.new(11, 3, 7), ahead + Vector3.new(-2, -0.5, -1))
		check(body.Position.Z > 0, "le joueur a marché pendant la photo de " .. name, body.Position.Z)
	end
	-- Toute la collection est trouvée : l'enclos est plein.
	local full = D("Eggs")
	check(full.count == 20 and math.abs(full.income - 285) < 0.001, "collection complète : 20 familiers, 285 pièces par seconde", full.income)
	tp(plot.origin + Vector3.new(-13, 4, 2))
	task.wait(1.5)
	shot("enclos", plot.origin + Vector3.new(10, 20, -14), plot.origin + Vector3.new(10, 1, 18))
	shot("enclos_pres", plot.origin + Vector3.new(-13, 6, 0), plot.origin + Vector3.new(6, 2, 14))
	shot("gagnants", Vector3.new(-14, 12, 1036), Vector3.new(2, 5, 1058))

	-- 4. LE RACCOURCI ----------------------------------------------------------------------------------------------
	tp(plot.spawn)
	task.wait(0.5)
	check(D("Shortcut", 5) == true, "raccourci ouvert après la salle 5")
	task.wait(0.5)
	_, _, root = alive()
	check(math.abs(root.Position.Z - D("Sas", 5).Z) < 6, "le raccourci mène devant la salle 6", root.Position)
	shot("couloir", Vector3.new(0, 9, D("Sas", 5).Z - 9), Vector3.new(0, 10, D("Sas", 5).Z + 10))

	log("Info", "[SURVIVE] TEST:done")
end

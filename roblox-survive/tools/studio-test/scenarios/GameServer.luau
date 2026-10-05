-- Test de tout le jeu, côté serveur : décor, achats de la salle de sport, puis les 10 salles (perdre, gagner,
-- demi-récompense, portes, plafond repoussé ou non), le raccourci. Le temps des salles est accéléré 8 fois.
-- Le joueur de test est déplacé par le serveur ; un champ de force le protège quand le test doit gagner une salle
-- sans esquiver (le plafond, lui, écrase même avec le champ de force : il faut vraiment pousser avec la bonne force).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)

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
	local function alive()
		while true do
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 and character:FindFirstChild("HumanoidRootPart") then
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
		check(D("Data").coins - before == expected, `salle {index} : +{expected} pièces`, D("Data").coins - before)
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
	check(gym ~= nil and gym:FindFirstChild("Speed") and gym:FindFirstChild("Jump") and gym:FindFirstChild("Force"), "la salle de sport a ses 3 machines")
	local rooms = workspace:FindFirstChild("Rooms")
	local count = 0
	for index = 1, #Config.ROOMS do
		local folder = rooms and rooms:FindFirstChild("Room" .. index)
		if folder and folder:GetAttribute("State") == "Idle" and folder.Entry:GetAttribute("Open") and not folder.Exit:GetAttribute("Open") then
			count += 1
		end
	end
	check(count == 10, "10 salles libres, entrée ouverte, sortie fermée", count)
	local _, _, root = alive()
	check(math.abs(root.Position.X) < 40 and math.abs(root.Position.Z) < 30, "le joueur apparaît dans la salle de sport", root.Position)
	shot("salle_de_sport", Vector3.new(0, 26, -27), Vector3.new(0, 0, 14))
	shot("tapis", Vector3.new(-8, 9, -2), Vector3.new(-26, 3, -14))
	shot("trampoline", Vector3.new(-6, 10, 26), Vector3.new(-26, 2, 12))
	shot("musculation", Vector3.new(8, 9, -2), Vector3.new(26, 3, -14))

	-- 2. LA SALLE DE SPORT -----------------------------------------------------------------------------------------
	local data = D("Data")
	check(data.coins == 0 and data.Speed == 1 and data.Jump == 1 and data.Force == 1 and data.best == 0, "nouveau joueur : 0 pièce, niveaux 1")
	local _, humanoid = alive()
	check(math.abs(humanoid.WalkSpeed - 16) < 0.01 and math.abs(humanoid.JumpHeight - 7.2) < 0.01, "vitesse 16 et saut 7,2 au départ", humanoid.WalkSpeed .. " / " .. humanoid.JumpHeight)
	local ok, reason = D("Buy", "Speed")
	check(not ok and reason == "poor", "achat refusé sans pièces", reason)
	D("Give", 500)
	ok = D("Buy", "Speed")
	data = D("Data")
	check(ok and data.Speed == 2 and data.coins == 0, "tapis de course niveau 2 pour 500 pièces", data.coins)
	check(math.abs(humanoid.WalkSpeed - 17.28) < 0.01, "vitesse +8 %", humanoid.WalkSpeed)
	D("Give", 41000)
	for _ = 1, 5 do
		D("Buy", "Jump")
	end
	data = D("Data")
	check(data.Jump == 6 and data.coins == 0, "trampoline niveau 6 pour 41 000 pièces en tout", data.coins)
	check(math.abs(humanoid.JumpHeight - 7.2 * 1.15 ^ 5) < 0.01, "saut deux fois plus haut au niveau 6", humanoid.JumpHeight)
	ok, reason = D("Buy", "Jump")
	check(not ok and reason == "max", "pas de niveau 7", reason)
	check(player:GetAttribute("Jump") == 6 and player.leaderstats.Coins.Value == 0, "niveaux et pièces envoyés à l'écran")
	D("Reset")
	check(not D("Shortcut", 5), "raccourci fermé tant que la salle 5 n'est pas réussie")

	-- 3. LES SALLES ------------------------------------------------------------------------------------------------
	D("Scale", SCALE)

	-- Le parcours de lave, vu avant que la lave monte (salle 1, puis la salle 8, la plus haute).
	for _, index in { 1, 8 } do
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
	check(math.abs(root.Position.Z) < 30, "le mort réapparaît dans la salle de sport", root.Position)
	winRoom(1, true)
	check(D("Data").best == 1, "meilleure salle = 1", D("Data").best)

	-- LES ŒUFS ET LA COUVEUSE : la salle 1 a donné un œuf de dragon.
	local eggs = D("Eggs")
	check(eggs.eggs == 1 and eggs.first == "Dragon", "salle 1 réussie = un œuf de dragon de lave", eggs.eggs .. " " .. eggs.first)
	check(D("Slot", 1) == "placed", "couveuse 1 : l'œuf est posé")
	eggs = D("Eggs")
	check(eggs.eggs == 0 and eggs.slots[1] == "Dragon", "l'œuf est dans la couveuse, plus dans la réserve", eggs.slots[1])
	check(string.match(player:GetAttribute("Slot1") or "", "^Dragon|%d+$") ~= nil, "couveuse 1 : envoyée à l'écran", player:GetAttribute("Slot1"))
	check(D("Slot", 1) == "wait", "couveuse 1 : pas encore prête, il faut attendre")
	check(D("Slot", 2) == "none", "couveuse 2 : rien à poser sans œuf")
	tp(Vector3.new(0, 4, -14))
	task.wait(0.6)
	shot("couveuses", Vector3.new(0, 9, -9), Vector3.new(0, 4, -26))
	D("Hatch")
	check(D("Slot", 1) == "hatched", "couveuse 1 : l'œuf prêt s'ouvre")
	eggs = D("Eggs")
	check((eggs.pets.Dragon or 0) >= 1 and eggs.equipped == "Dragon" and eggs.slots[1] == "", "le dragon de lave est gagné et équipé tout seul", tostring(eggs.pets.Dragon))
	check(player:GetAttribute("Pet") == "Dragon" and player:GetAttribute("PetRarity") == eggs.pets.Dragon, "l'animal équipé est envoyé à l'écran")
	D("Pet", "Dragon", 4)
	task.wait(0.8)
	shot("dragon", Vector3.new(7, 6, -4), Vector3.new(1, 3, -14))

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
	check(crushed(4, 5), "salle 4 : force 1 à 5 appuis par seconde = écrasé")
	D("Level", "Force", 2)
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
	check(D("Data").coins - melodyBefore == 600, "salle 6 : +600 pièces", D("Data").coins - melodyBefore)
	tp(D("Sas", 6))
	waitState(6, "Idle", Config.OPEN / SCALE + 3)
	D("Level", "Force", 3)
	check(crushed(7, 5), "salle 7 : force 3 à 5 appuis par seconde = écrasé")
	D("Level", "Force", 4)
	winRoom(7)
	winRoom(8, true)
	winRoom(9, true)
	D("Level", "Force", 5)
	winRoom(10, true)
	check(D("Data").best == 10, "meilleure salle = 10", D("Data").best)
	check(D("Eggs").eggs >= 8, "chaque salle réussie a donné son œuf", D("Eggs").eggs)

	-- LES POUVOIRS DES ANIMAUX (légendaires, donnés par le test).
	D("Pet", "Owl", 4)
	winRoom(2, false, 1.25)
	D("Pet", "Rock", 4)
	enter(2)
	local _, rockHumanoid = alive()
	limit = os.clock() + 40 / SCALE
	while (D("Room", 2).shield or 160) >= 160 and os.clock() < limit do
		task.wait(0.03)
	end
	local shield = D("Room", 2).shield
	check(shield ~= nil and shield < 160, "caillou légendaire : le bouclier encaisse le coup", shield)
	check(shield == 0 or rockHumanoid.Health == 100, "caillou légendaire : pas de vie perdue tant que le bouclier tient", rockHumanoid.Health)
	rockHumanoid.Health = 0
	waitState(2, "Idle", 3)
	D("Level", "Force", 1)
	D("Pet", "Golem", 4)
	check(not crushed(4, 5), "golem légendaire : force 1 + 15 tient le plafond de la salle 4")
	D("Scale", 1)
	D("Pet", "Rabbit", 4)
	local _, rabbitHumanoid = alive()
	task.wait(0.3)
	check(math.abs(rabbitHumanoid.WalkSpeed - Config.walkSpeed(D("Data").Speed) * 1.15) < 0.01, "lapin légendaire : +15 % de vitesse", rabbitHumanoid.WalkSpeed)
	-- Dragon : tomber de haut, sans puis avec le vol plané.
	D("Pet", "Dragon", 4)
	local function fall(glide: boolean): number
		tp(Vector3.new(0, 70, 8))
		task.wait(0.2)
		if glide then
			player:SetAttribute("DebugGlide", os.clock())
		end
		local started = os.clock()
		local _, _, body = alive()
		while body.Position.Y > 6 and os.clock() - started < 9 do
			task.wait(0.03)
		end
		return os.clock() - started
	end
	local plain = fall(false)
	task.wait(1)
	local held = fall(true)
	check(held > plain + 2, "dragon légendaire : le vol plané retient la chute 3 secondes", string.format("%.1f s sans, %.1f s avec", plain, held))
	shot("gagnants", Vector3.new(-14, 12, 1036), Vector3.new(2, 5, 1058))

	-- 4. LE RACCOURCI ----------------------------------------------------------------------------------------------
	tp(Vector3.new(0, 4, -16))
	task.wait(0.5)
	check(D("Shortcut", 5) == true, "raccourci ouvert après la salle 5")
	task.wait(0.5)
	_, _, root = alive()
	check(math.abs(root.Position.Z - D("Sas", 5).Z) < 6, "le raccourci mène devant la salle 6", root.Position)
	shot("couloir", Vector3.new(0, 9, D("Sas", 5).Z - 9), Vector3.new(0, 10, D("Sas", 5).Z + 10))

	log("Info", "[SURVIVE] TEST:done")
end

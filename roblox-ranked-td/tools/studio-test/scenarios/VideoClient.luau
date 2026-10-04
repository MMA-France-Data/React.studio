-- VIDÉO DE LA PAGE DU JEU : tools/studio-test/video.ps1 (pas un test). Demande du propriétaire (04/10/2026) :
-- « faut refaire une vidéo du jeu avec des rushs de 3/4 s, une vidéo de 16 s ». Le scénario met en scène de vraies
-- parties, en anglais (la vidéo d'une page Roblox : textes et son en anglais), et pilote OBS par la Sortie :
--   « CALIBRATE »        : un écran magenta plein cadre : OBS repère la vue 3D de Studio (obs.cjs calibrate) ;
--   « REC:START »        : OBS commence un plan ; « REC:STOP:<nom> » : il l'arrête, rangé dans out/video/<nom>.mp4 ;
--   « VIDEO:done »       : fini (video.ps1 ferme Studio et OBS, puis montage.py coupe et colle les plans).
-- Les plans (chacun enregistré environ 6 s ; montage.py en garde 3 à 4 s) :
--   r1 : le colosse géant (niveau 15, le col) qui avance sous les tirs des tours spéciales, de près, sans l'interface ;
--   r2 : un niveau du glacier (38) en entier, avec l'interface : plein de tours et de monstres, deux améliorées ;
--   r3 : le boss du glacier (niveau 40), de près (retour du propriétaire : « filme un autre boss, comme celui de
--        glace, il rend mieux » ; celui de la forêt était trop sombre) ;
--   r4 : l'œuf carmin qui s'ouvre : « 🌟 SPECIAL TOWER! » ;
--   r5 : la victoire au boss du niveau 20 (« Special egg won »).
-- Les commandes viennent du serveur du tournage (scenarios/VideoServer.luau, RemoteFunction __VideoTest).
return function(log)
	local HttpService = game:GetService("HttpService")
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local StarterGui = game:GetService("StarterGui")
	local UserInputService = game:GetService("UserInputService")
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local IdleTowers = require(Shared.IdleTowers)
	local Levels = require(Shared.Levels)
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local function say(message)
		log("Info", "[VIDEO] " .. message)
	end
	local function waitFor(condition, seconds)
		local deadline = os.clock() + seconds
		while os.clock() < deadline do
			if condition() then
				return true
			end
			task.wait(0.1)
		end
		return condition()
	end
	local function cam()
		return workspace.CurrentCamera
	end
	-- Les boutons de Roblox (menu, liste des joueurs, discussion) : cachés pour la vidéo. (LevelsUI rallume la liste des
	-- joueurs au retour d'un niveau : on recommence avant chaque plan.)
	local function hideCore()
		pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
		end)
		pcall(function()
			StarterGui:SetCore("TopbarEnabled", false)
		end)
	end

	local campGui = playerGui:WaitForChild("Levels", 90)
	local hudGui = playerGui:WaitForChild("LevelHud", 30)
	local revealGui = playerGui:WaitForChild("HatchReveal", 30)
	local test = ReplicatedStorage:WaitForChild("__VideoTest", 60)
	if not campGui or not hudGui or not revealGui or not test then
		log("Error", "[FAIL] vidéo : écrans ou serveur du tournage introuvables")
		say("VIDEO:done")
		return
	end
	waitFor(function()
		return cam() ~= nil and cam().ViewportSize.X >= 400 and cam().ViewportSize.Y >= 250
	end, 20)
	-- (video.ps1 agrandit la fenêtre de Studio au début : on attend que l'image du jeu ne change plus de taille)
	do
		local size, since = cam().ViewportSize, os.clock()
		waitFor(function()
			if cam().ViewportSize ~= size then
				size, since = cam().ViewportSize, os.clock()
			end
			return os.clock() - since >= 3
		end, 25)
	end
	hideCore()
	UserInputService.MouseIconEnabled = false
	-- La vidéo de la page est en anglais : le jeu passe en anglais tout de suite (comme pour un joueur non francophone).
	player:SetAttribute("Lang", "en")
	local levelAction = ReplicatedStorage.Remotes.LevelAction
	local counter = 0
	local function act(gui, command)
		counter += 1
		gui:SetAttribute("TestAction", `{command}#{counter}`)
		task.wait(0.15)
	end
	local function published()
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(player:GetAttribute("LevelsState"))
		end)
		return if ok and typeof(decoded) == "table" then decoded else {}
	end
	local slot = player:GetAttribute("Plot")
	local arena = workspace:WaitForChild("Arenas"):WaitForChild("Arena" .. tostring(slot))
	local arenaCFrame = Levels.arenaCFrame(slot)
	local function towers()
		local folder = arena:FindFirstChild("Towers")
		local list = {}
		for _, model in if folder then folder:GetChildren() else {} do
			if model:IsA("Model") then
				table.insert(list, model)
			end
		end
		return list
	end
	local function running()
		return arena:GetAttribute("State") == "Running"
	end
	local function startLevel(level, bar)
		test:InvokeServer("Set", { bar = bar })
		task.wait(0.4)
		levelAction:FireServer("Start", level)
		return waitFor(function()
			return hudGui.Enabled and running() and arena:GetAttribute("Level") == level
		end, 15)
	end
	local function quitLevel()
		levelAction:FireServer("Quit")
		waitFor(function()
			return player:GetAttribute("LevelArena") == nil
		end, 8)
		task.wait(1)
	end
	-- Pose ces tours sur les emplacements conseillés de la carte du niveau (le suivant libre pour chacune), améliore
	-- chacune `upgrades` fois, puis ne laisse que `gold` or (sous 80 : pas de conseil « ne garde pas ton or » à l'écran).
	local function build(level, list, upgrades, gold)
		test:InvokeServer("Gold", 50000)
		local spots = Levels.geometry(Levels.definition(level).map).map.spots
		local spotIndex = 1
		for _, towerType in list do
			while spotIndex <= #spots do
				local spot = spots[spotIndex]
				spotIndex += 1
				if test:InvokeServer("Do", { "Place", towerType, spot.X, spot.Z }) then
					break
				end
			end
		end
		task.wait(0.4)
		for _, model in towers() do
			for _ = 1, upgrades do
				test:InvokeServer("Do", { "Upgrade", model:GetAttribute("TowerId") })
			end
		end
		task.wait(0.3)
		test:InvokeServer("Gold", (gold or 30) - (arena:GetAttribute("Gold") or 0))
	end
	-- Le plus gros monstre affiché dans la zone de ce type (Colossus, Boss...), ou nil.
	local function enemyOf(kind)
		local folder = workspace:FindFirstChild("PlotEnemies")
		for _, part in if folder then folder:GetChildren() else {} do
			if part:IsA("BasePart") and part:GetAttribute("EnemyType") == kind and (part.Position - arenaCFrame.Position).Magnitude < 120 then
				return part
			end
		end
		return nil
	end
	-- Avance le niveau par pas de `step` s jusqu'à ce que `condition()` soit vraie (ou la fin du niveau).
	local function skipUntil(condition, step, maxSeconds)
		local skipped = 0
		while skipped < maxSeconds and running() and not condition() do
			test:InvokeServer("Skip", step)
			skipped += step
			task.wait(0.5) -- (les positions arrivent au client)
		end
		return condition()
	end
	-- Amène ce point du terrain au milieu de l'écran (vue zoomée) : glissements successifs, comme un doigt.
	local function centerOn(point)
		for _ = 1, 6 do
			local at = cam():WorldToViewportPoint(point)
			local size = cam().ViewportSize
			local dx, dy = size.X / 2 - at.X, size.Y / 2 - at.Y
			if math.abs(dx) < 4 and math.abs(dy) < 4 then
				break
			end
			act(hudGui, string.format("Pan:%.1f,%.1f", dx, dy))
			task.wait(0.1)
		end
	end
	-- Où sera ce monstre dans `seconds` s (deux positions à 0,4 s d'écart) : la caméra se centre là, pour qu'il reste
	-- au milieu du plan pendant qu'il avance (le centrage et le début de l'enregistrement prennent ~1,5 s).
	local function aheadOf(part, seconds)
		local first = part.Position
		task.wait(0.4)
		local second = part.Position
		return second + (second - first) / 0.4 * seconds
	end
	-- Cadre ce monstre (colosse, boss) : zoom, puis la caméra se centre là où il sera au MILIEU du morceau que garde
	-- montage.py (environ 3,5 s plus tard : le centrage, le départ d'OBS, la seconde coupée au début, la moitié du
	-- morceau). Près du bord de la carte, la caméra ne peut pas aller plus loin (ce point ne serait pas au milieu de
	-- l'image, et le monstre resterait coupé) : le niveau avance alors de 1,5 s et on recommence.
	local function frameOn(kind, zoom)
		act(hudGui, `Zoom:{zoom}`)
		task.wait(0.4)
		for _ = 1, 16 do
			local part = enemyOf(kind)
			if not part then
				return false
			end
			local target = aheadOf(part, 3.5)
			centerOn(target)
			task.wait(0.2)
			local size = cam().ViewportSize
			local aim = cam():WorldToViewportPoint(target)
			local now = cam():WorldToViewportPoint(part.Position)
			local centered = math.abs(aim.X - size.X / 2) < size.X * 0.08 and math.abs(aim.Y - size.Y / 2) < size.Y * 0.1
			if centered and now.X > size.X * 0.15 and now.X < size.X * 0.85 and now.Y > size.Y * 0.25 and now.Y < size.Y * 0.85 then
				return true
			end
			test:InvokeServer("Skip", 1.5)
			task.wait(0.4)
		end
		return enemyOf(kind) ~= nil
	end
	-- Boutons du haut de l'écran du camp (cachés pour la vidéo).
	local function setTopButtons(visible)
		for _, name in { "LevelsButton", "HudCoins" } do
			local object = campGui:FindFirstChild(name)
			if object then
				object.Visible = visible
			end
		end
		local sound = playerGui:FindFirstChild("SoundButton")
		if sound then
			sound.Enabled = visible
		end
	end
	local function setToasts(visible)
		local toasts = playerGui:FindFirstChild("Toasts")
		if toasts then
			toasts.Enabled = visible
		end
	end
	-- Un plan : OBS enregistre `seconds` s (plus le temps qu'il met à démarrer) ; `during` se joue pendant le plan.
	local function record(name, seconds, during)
		hideCore()
		say("REC:START")
		task.wait(0.9) -- (OBS démarre son enregistrement : environ une demi-seconde)
		if during then
			task.spawn(during)
		end
		task.wait(seconds)
		say("REC:STOP:" .. name)
		task.wait(2.5) -- (OBS range le fichier)
	end

	-- Calibrage : un écran magenta plein cadre (obs.cjs y trouve le rectangle de l'image du jeu dans Studio).
	local marker = Instance.new("ScreenGui")
	marker.Name = "VideoCalibration"
	marker.IgnoreGuiInset = true
	marker.DisplayOrder = 1000
	marker.ResetOnSpawn = false
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(255, 0, 255)
	fill.BorderSizePixel = 0
	fill.Parent = marker
	marker.Parent = playerGui
	task.wait(0.8)
	say("CALIBRATE")
	task.wait(9) -- (video.ps1 met Studio devant, puis OBS repère l'image : quelques secondes)
	marker:Destroy()

	-- Un joueur qui a tout : les 20 tours, des étoiles d'entraînement, tous les niveaux ouverts jusqu'au 40.
	local everything = {}
	for _, towerType in IdleTowers.ORDER do
		everything[towerType] = true
	end
	test:InvokeServer("Set", { towers = everything })
	local xp = {}
	for _, towerType in IdleTowers.ORDER do
		xp[towerType] = 320 -- (entraînement 4 : ★★)
	end
	xp.CrimsonBow, xp.FrostCatapult, xp.DragonBallista = 1250, 1250, 650
	test:InvokeServer("Set", { tutorial = Levels.TUTORIAL.DONE, best = 40, coins = 18400, xp = xp })
	waitFor(function()
		return published().best == 40
	end, 5)
	act(campGui, "Close")
	setToasts(false)

	------------------------------------------------------------------
	-- r1 : le colosse géant du col (niveau 15), de près, sous les tirs
	------------------------------------------------------------------
	-- (des tours qui ne ralentissent pas, sans amélioration : le colosse avance comme prévu et vit tout le plan)
	local special = { "CrimsonBow", "CopperCrossbow", "ThornSpitter", "MagmaCatapult", "FireArcher", "DragonBallista", "FrostCatapult", "StormArchmage" }
	if startLevel(15, special) then
		build(15, { "ThornSpitter", "CrimsonBow", "CopperCrossbow", "ThornSpitter", "CrimsonBow", "MagmaCatapult" }, 0, 30)
		local found = skipUntil(function()
			return enemyOf("Colossus") ~= nil
		end, 4, 220)
		task.wait(0.6)
		hudGui.Enabled = false
		local framed = found and frameOn("Colossus", 1.6)
		say(`colosse géant {if framed then "au milieu de l'image" elseif found then "pas au milieu" else "ABSENT"}`)
		record("r1", 5.5, function()
			-- (au milieu du morceau que garde montage.py : où est-il à l'image ?)
			task.wait(2.8)
			local colossus = enemyOf("Colossus")
			if colossus then
				local at = cam():WorldToViewportPoint(colossus.Position)
				say(`colosse au milieu du plan : à {math.floor(at.X / cam().ViewportSize.X * 100)} %, {math.floor(at.Y / cam().ViewportSize.Y * 100)} % de l'image`)
			else
				say("colosse au milieu du plan : plus là (tué ?)")
			end
		end)
		hudGui.Enabled = true
		act(hudGui, "Zoom:1")
		quitLevel()
	else
		log("Error", "[FAIL] vidéo : niveau 15 pas lancé")
	end

	------------------------------------------------------------------
	-- r2 : le glacier (niveau 38) en entier, avec l'interface
	------------------------------------------------------------------
	local glacier = { "CrimsonBow", "ThornSpitter", "FrostCatapult", "CopperCrossbow", "BlizzardTotem", "VoidSorcerer", "ThunderOracle", "CelestialTrebuchet" }
	if startLevel(38, glacier) then
		build(38, { "CrimsonBow", "FrostCatapult", "ThornSpitter", "CopperCrossbow", "VoidSorcerer", "ThunderOracle", "BlizzardTotem", "CelestialTrebuchet", "CrimsonBow", "ThornSpitter" }, 1, 40)
		test:InvokeServer("Skip", 45)
		task.wait(1.2)
		record("r2", 5.5, function()
			-- (deux tours améliorées pendant le plan ; l'or donné juste avant est repris tout de suite : pas de conseil
			-- « ne garde pas ton or » à l'écran)
			local list = towers()
			for index = 1, math.min(2, #list) do
				test:InvokeServer("Gold", 5000)
				test:InvokeServer("Do", { "Upgrade", list[index]:GetAttribute("TowerId") })
				test:InvokeServer("Gold", 40 - (arena:GetAttribute("Gold") or 0))
				task.wait(1.2)
			end
		end)
		quitLevel()
	else
		log("Error", "[FAIL] vidéo : niveau 38 pas lancé")
	end

	------------------------------------------------------------------
	-- r3 : le boss du glacier (niveau 40), de près
	------------------------------------------------------------------
	local frozen = { "FrostCatapult", "ThornSpitter", "CopperCrossbow", "CrimsonBow", "DragonBallista", "VoidSorcerer", "MagmaCatapult", "StormArchmage" }
	if startLevel(40, frozen) then
		build(40, { "FrostCatapult", "ThornSpitter", "CopperCrossbow", "CrimsonBow", "FrostCatapult", "ThornSpitter", "CopperCrossbow", "CrimsonBow", "DragonBallista", "VoidSorcerer", "MagmaCatapult" }, 3, 30)
		local found = skipUntil(function()
			return enemyOf("Boss") ~= nil
		end, 5, 340)
		task.wait(0.6)
		hudGui.Enabled = false
		local framed = found and frameOn("Boss", 1.7)
		say(`boss {if framed then "au milieu de l'image" elseif found then "pas au milieu" else "ABSENT"}`)
		record("r3", 5.5)
		hudGui.Enabled = true
		act(hudGui, "Zoom:1")
		quitLevel()
	else
		log("Error", "[FAIL] vidéo : niveau 40 pas lancé")
	end

	------------------------------------------------------------------
	-- r4 : l'œuf carmin qui s'ouvre (« 🌟 SPECIAL TOWER! »)
	------------------------------------------------------------------
	local withoutCrimson = table.clone(everything)
	withoutCrimson.CrimsonBow = nil
	test:InvokeServer("Set", { towers = withoutCrimson })
	test:InvokeServer("Set", {
		eggs = { Common = 2, Gold = 1, Copper = 1 },
		hatchers = { { egg = "Crimson", readyAt = 0 }, { egg = "Common", readyAt = os.time() + 9 * 60 } },
	})
	waitFor(function()
		local hatchers = published().hatchers
		return typeof(hatchers) == "table" and hatchers[1] ~= nil and hatchers[1].egg == "Crimson"
	end, 5)
	setTopButtons(false)
	act(campGui, "Tab:Œufs")
	task.wait(1.5)
	record("r4", 5.5, function()
		task.wait(0.6)
		act(campGui, "EggOpen:1")
	end)
	act(campGui, "RevealClose")
	act(campGui, "Close")
	setTopButtons(true)
	task.wait(0.5)

	------------------------------------------------------------------
	-- r5 : la victoire au boss du niveau 20 (la première fois : l'œuf de cuivre en plus)
	------------------------------------------------------------------
	test:InvokeServer("Set", { best = 19 })
	local pass = { "CrimsonBow", "CopperCrossbow", "ThornSpitter", "FrostCatapult", "MagmaCatapult", "StormArchmage", "FireArcher", "DragonBallista" }
	if startLevel(20, pass) then
		build(20, { "CrimsonBow", "CopperCrossbow", "ThornSpitter", "FrostCatapult", "MagmaCatapult", "StormArchmage", "FireArcher", "DragonBallista" }, 3, 30)
		test:InvokeServer("Skip", 40)
		task.wait(1.2)
		record("r5", 5.5, function()
			task.wait(0.6)
			test:InvokeServer("Finish", true)
		end)
		quitLevel()
	else
		log("Error", "[FAIL] vidéo : niveau 20 pas lancé")
	end

	setToasts(true)
	UserInputService.MouseIconEnabled = true
	say("VIDEO:done")
end

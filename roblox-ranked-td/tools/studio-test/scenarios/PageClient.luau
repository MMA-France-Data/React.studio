-- IMAGES POUR LA PAGE ROBLOX DU JEU : tools/studio-test/run.ps1 -Test page, puis tools/studio-test/page.ps1.
-- Ce n'est pas un test : le scénario met en scène de vraies parties (en anglais, la langue de la plupart des
-- joueurs) et demande des captures « page_<nom> ». page.ps1 les recadre ensuite sur l'image du jeu (sans les
-- menus de Studio) et les met aux tailles de Roblox dans assets/page : miniatures 1920 x 1080 et icône 512 x 512.
--   calibrage : un écran rose plein cadre, pour que page.ps1 trouve où est l'image du jeu dans la fenêtre de Studio ;
--   combat    : niveau 8 (la vallée), les 8 tours posées et améliorées, le flot et un colosse ;
--   zoom      : la même partie vue de près, centrée sur le colosse, sans l'interface (sert aussi pour l'icône) ;
--   boss      : niveau 20 (le col), le boss entre pendant que les derniers monstres passent ;
--   victoire  : l'écran de victoire ;
--   camp      : la parcelle du joueur, trois tours évoluées à l'entraînement ;
--   oeufs, niveaux : la fenêtre du camp d'un joueur en cours de route (ses œufs et ses couveuses, le 2e territoire
--   ouvert).
-- Les commandes viennent du serveur de test (scenarios/EnglishServer.luau, RemoteFunction __EnglishTest).
return function(log)
	local HttpService = game:GetService("HttpService")
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local StarterGui = game:GetService("StarterGui")
	local UserInputService = game:GetService("UserInputService")
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Levels = require(Shared.Levels)
	local PlotLayout = require(Shared.PlotLayout)
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local function say(message)
		log("Info", "[PAGE] " .. message)
	end
	local function shot(name)
		say("SHOT:page_" .. name)
		task.wait(1.8)
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
	local function finish()
		say("PAGE:client=done")
		task.wait(1.5)
		say("PHONE:done")
	end
	local function cam()
		return workspace.CurrentCamera
	end
	-- (LevelsUI rallume la liste des joueurs de Roblox au retour d'un niveau : on la recoupe avant chaque capture)
	local function hidePlayerList()
		pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
		end)
	end

	local campGui = playerGui:WaitForChild("Levels", 90)
	local hudGui = playerGui:WaitForChild("LevelHud", 30)
	local test = ReplicatedStorage:WaitForChild("__EnglishTest", 60)
	if not campGui or not hudGui or not test then
		log("Error", "[FAIL] page : écrans ou serveur du test introuvables")
		finish()
		return
	end
	waitFor(function()
		return cam() ~= nil and cam().ViewportSize.X >= 400 and cam().ViewportSize.Y >= 250
	end, 20)
	-- (run.ps1 agrandit la fenêtre de Studio au début : on attend que l'image du jeu ne change plus de taille)
	do
		local size, since = cam().ViewportSize, os.clock()
		waitFor(function()
			if cam().ViewportSize ~= size then
				size, since = cam().ViewportSize, os.clock()
			end
			return os.clock() - since >= 3
		end, 25)
	end
	hidePlayerList()
	UserInputService.MouseIconEnabled = false
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
		return if ok then decoded else {}
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
	local function startLevel(level)
		levelAction:FireServer("Start", level)
		return waitFor(function()
			return hudGui.Enabled and arena:GetAttribute("State") == "Running" and arena:GetAttribute("Level") == level
		end, 15)
	end
	-- Pose ces tours sur les emplacements conseillés de la carte, dans l'ordre, améliore chacune `upgrades` fois, puis
	-- ne laisse que 30 or (sinon le conseil « ne garde pas ton or » s'affiche sur la capture).
	local function build(mapName, list, upgrades)
		test:InvokeServer("Gold", 15000)
		local spots = Levels.MAPS[mapName].spots
		for index, towerType in list do
			test:InvokeServer("Do", { "Place", towerType, spots[index].X, spots[index].Z })
		end
		task.wait(0.4)
		for _, model in towers() do
			for _ = 1, upgrades do
				test:InvokeServer("Do", { "Upgrade", model:GetAttribute("TowerId") })
			end
		end
		task.wait(0.3)
		test:InvokeServer("Gold", 30 - (arena:GetAttribute("Gold") or 30))
	end
	-- Le plus gros monstre affiché dans la zone (colosse ou boss), ou nil.
	local function bigEnemy()
		local folder = workspace:FindFirstChild("PlotEnemies")
		for _, part in if folder then folder:GetChildren() else {} do
			local enemyType = part:IsA("BasePart") and part:GetAttribute("EnemyType")
			if (enemyType == "Giant" or enemyType == "Boss") and (part.Position - arenaCFrame.Position).Magnitude < 90 then
				return part
			end
		end
		return nil
	end
	-- Amène ce point du terrain au milieu de l'écran (vue zoomée) : glissements successifs, comme un doigt.
	local function centerOn(point)
		for _ = 1, 5 do
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
	-- Boutons du haut de l'écran (cachés pour une capture : le recadrage en 16:9 les couperait en deux).
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

	-- Calibrage : un écran rose plein cadre (page.ps1 y trouve le rectangle de l'image du jeu).
	local marker = Instance.new("ScreenGui")
	marker.Name = "PageCalibration"
	marker.IgnoreGuiInset = true
	marker.DisplayOrder = 1000
	marker.ResetOnSpawn = false
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(255, 0, 255)
	fill.BorderSizePixel = 0
	fill.Parent = marker
	marker.Parent = playerGui
	task.wait(0.6)
	shot("calibrage")
	marker:Destroy()

	-- Le jeu en anglais, un joueur qui a tout : les 8 tours (d'abord : un emplacement du camp ne garde qu'une tour
	-- possédée), des évolutions, trois emplacements au camp.
	player:SetAttribute("Lang", "en")
	test:InvokeServer("Set", {
		towers = { MachineGun = true, Bomb = true, Frost = true, Tesla = true, Rocket = true, Laser = true, Chain = true, Orbital = true },
	})
	test:InvokeServer("Set", {
		tutorial = Levels.TUTORIAL.DONE,
		best = 19,
		coins = 4260,
		xp = { MachineGun = 1250, Bomb = 320, Frost = 320, Tesla = 80, Rocket = 320, Laser = 80, Chain = 650, Orbital = 320 },
		slots = { { tower = "MachineGun", level = 3 }, { tower = "Chain", level = 2 }, { tower = "Orbital", level = 1 } },
	})
	waitFor(function()
		return published().best == 19
	end, 5)
	act(campGui, "Close")

	-- 1) Combat dans la vallée (niveau 8) : toutes les tours, le flot, un colosse.
	startLevel(8)
	build("Valley", { "MachineGun", "Frost", "Bomb", "Tesla", "Rocket", "Laser", "Chain", "Orbital", "MachineGun", "Bomb", "Tesla", "MachineGun" }, 3)
	task.wait(1)
	test:InvokeServer("Skip", 88)
	task.wait(3)
	hidePlayerList()
	shot("combat")
	-- 2) La même partie vue de près, centrée sur le colosse, sans l'interface (l'icône du jeu en est tirée).
	act(hudGui, "Zoom:3")
	hudGui.Enabled = false
	local toasts = playerGui:FindFirstChild("Toasts")
	if toasts then
		toasts.Enabled = false
	end
	local giant = bigEnemy()
	if giant then
		centerOn(giant.Position + Vector3.new(0, 2, 0))
		task.wait(0.3)
		giant = bigEnemy() or giant
		centerOn(giant.Position + Vector3.new(0, 2, 0))
	end
	task.wait(0.4)
	shot("zoom")
	hudGui.Enabled = true
	act(hudGui, "Zoom:1")

	-- 3) Le boss du col (niveau 20) : il entre pendant que les derniers monstres du flot passent.
	startLevel(20)
	build("Pass", { "MachineGun", "Frost", "Bomb", "Rocket", "Chain", "Tesla", "Laser", "Orbital", "MachineGun", "Bomb", "Rocket", "MachineGun" }, 3)
	task.wait(1)
	test:InvokeServer("Skip", 146)
	task.wait(4.5)
	hidePlayerList()
	shot("boss")
	-- 4) Victoire.
	test:InvokeServer("Finish", true)
	waitFor(function()
		return hudGui.EndScreen.Visible
	end, 5)
	task.wait(0.8)
	shot("victoire")

	-- 5) Le camp : la parcelle du joueur, ses trois tours évoluées à l'entraînement.
	levelAction:FireServer("Quit")
	waitFor(function()
		return player:GetAttribute("LevelArena") == nil and not hudGui.Enabled
	end, 6)
	act(campGui, "Close")
	hidePlayerList()
	setTopButtons(false)
	task.wait(1)
	local before = cam().CFrame
	cam().CameraType = Enum.CameraType.Scriptable
	cam().CFrame = CFrame.lookAt(PlotLayout.toWorld(slot, Vector3.new(-4, 10.5, -50)), PlotLayout.toWorld(slot, Vector3.new(-4, 5, -31)))
	cam().Focus = CFrame.new(PlotLayout.toWorld(slot, Vector3.new(-4, 3, -31)))
	task.wait(5)
	shot("camp")
	cam().CameraType = Enum.CameraType.Custom
	cam().CFrame = before
	task.wait(0.4)

	-- 6) La fenêtre du camp d'un joueur en cours de route : ses œufs (un prêt, un qui couve ; l'œuf carmin du boss du
	-- niveau 10, tout juste battu), le 2e territoire tout juste ouvert.
	test:InvokeServer("Set", {
		best = 10,
		coins = 1350,
		slots = { { tower = "MachineGun", level = 2 } },
	})
	test:InvokeServer("Set", {
		towers = { MachineGun = true, Bomb = true, Frost = true, Tesla = true },
		eggs = { Common = 3, Rare = 1, Gold = 1, Crimson = 1 },
		hatchers = { { egg = "Rare", readyAt = 0 }, { egg = "Common", readyAt = os.time() + 9 * 60 } },
	})
	waitFor(function()
		return published().coins == 1350 and #(published().towers or {}) == 4
	end, 5)
	act(campGui, "Tab:Œufs")
	hidePlayerList()
	task.wait(1.2)
	shot("oeufs")
	act(campGui, "Tab:Niveaux")
	local page1 = campGui.Window.Page1
	page1.CanvasPosition = Vector2.new(0, 0)
	task.wait(1.2)
	shot("niveaux")

	setTopButtons(true)
	UserInputService.MouseIconEnabled = true
	finish()
end

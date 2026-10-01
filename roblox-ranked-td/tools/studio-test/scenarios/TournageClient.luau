-- Mode tournage (tools/studio-test/tournage.ps1), côté client : caméra de cinéma et marqueurs pour OBS.
--   « CALIBRATE »                 -> OBS repère la vue 3D de Studio (écran magenta plein cadre quelques secondes)
--   « REC:START » / « REC:STOP:nom » -> OBS démarre / arrête l'enregistrement (vidéo nom.mp4)
--   « REC:PAUSE » / « REC:RESUME »   -> pause / reprise : coupes nettes entre les plans de la compilation
--   « IMG:nom »                   -> image 1920 x 1080 (nom.png)
--   « CROP:left » / « CROP:center »  -> image prise à gauche de la vue 3D (avec la colonne de boutons) ou au centre
-- Demande du propriétaire (30/09/2026) : des plans courts (« rushs » de 3 à 5 s) et une compilation. Deux passages :
-- 1) la compilation (un seul fichier, pause entre les plans, 30 s au plus : règle de Roblox pour les vidéos) ;
-- 2) les mêmes plans rejoués, un fichier par plan (rush_1_parcelle.mp4...), avec les images.
-- Les scènes sont préparées par le serveur (TournageServer.luau, ReplicatedStorage.__Tournage) : vraies mécaniques du
-- jeu (tours, vagues, effets), seule la caméra est pilotée, interface cachée (sauf l'image « interface »). Jeu en
-- anglais (autre règle de Roblox : textes et son en anglais). Uniquement dans la place de test de tournage.ps1.
return function(log)
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")
	local StarterGui = game:GetService("StarterGui")
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local PlotLayout = require(Shared.PlotLayout)

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local remote = ReplicatedStorage:WaitForChild("__Tournage", 90)
	local function server(...)
		return remote:InvokeServer(...)
	end
	-- Marqueur envoyé tout de suite par le serveur à logserver.cjs (~0,3 s jusqu'à OBS au lieu de ~1,5 s).
	local function mark(text: string)
		server("mark", text)
	end
	local LATENCY = 0.5 -- temps laissé à OBS après un marqueur de début ou de fin de plan

	local plot
	for _ = 1, 300 do
		plot = player:GetAttribute("Plot")
		if typeof(plot) == "number" then
			break
		end
		task.wait(0.1)
	end
	local base = PlotLayout.cframe(plot)
	-- Point de la parcelle (coordonnées locales : x = largeur, z = profondeur, -z = côté place centrale).
	local function W(x, y, z)
		return base:PointToWorldSpace(Vector3.new(x, y, z))
	end
	local function offset(x, y, z)
		return base:VectorToWorldSpace(Vector3.new(x, y, z))
	end

	----------------------------------------------------------------------
	-- Interface : tout caché pendant les plans de cinéma (et les boutons « (Studio) » toujours cachés)
	----------------------------------------------------------------------
	local uiHidden = false
	local function applyUI()
		for _, gui in playerGui:GetChildren() do
			if gui:IsA("ScreenGui") and gui.Name ~= "TournageCalibration" then
				if uiHidden then
					gui.Enabled = false
				else
					-- Boutons réservés à Studio (« GALERIE (Studio) », « SONS (Studio) ») : jamais à l'image.
					for _, item in gui:GetDescendants() do
						if item:IsA("TextButton") and string.find(item.Text, "(Studio)", 1, true) then
							item.Visible = false
						end
					end
				end
			end
		end
		pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
		end)
	end
	local savedEnabled = {}
	local function hideUI()
		uiHidden = true
		for _, gui in playerGui:GetChildren() do
			if gui:IsA("ScreenGui") and savedEnabled[gui] == nil then
				savedEnabled[gui] = gui.Enabled
			end
		end
		applyUI()
	end
	local function showUI()
		uiHidden = false
		for gui, enabled in savedEnabled do
			if gui.Parent then
				gui.Enabled = enabled
			end
		end
		applyUI()
	end
	task.spawn(function()
		while true do
			if uiHidden then
				applyUI()
			end
			task.wait(0.5)
		end
	end)

	----------------------------------------------------------------------
	-- Caméra : toujours « Scriptable » (au premier essai, elle est repassée en caméra normale, derrière le
	-- personnage) : remise à chaque image, sur la caméra actuelle de workspace.
	----------------------------------------------------------------------
	local camPos = W(0, 80, -100)
	local camLook = W(0, 0, 25)
	local function apply()
		local camera = workspace.CurrentCamera
		if camera.CameraType ~= Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Scriptable
		end
		camera.FieldOfView = 60
		camera.CFrame = CFrame.lookAt(camPos, camLook)
	end
	RunService:BindToRenderStep("TournageCamera", Enum.RenderPriority.Last.Value, apply)
	local function snap(pos: Vector3, look: Vector3)
		camPos, camLook = pos, look
		apply()
	end
	local function ease(t: number): number
		return t * t * (3 - 2 * t)
	end
	-- Mouvement doux d'un point de vue à un autre.
	local function move(toPos: Vector3, toLook: Vector3, duration: number)
		local fromPos, fromLook = camPos, camLook
		local start = os.clock()
		while true do
			local t = math.clamp((os.clock() - start) / duration, 0, 1)
			local s = ease(t)
			camPos = fromPos:Lerp(toPos, s)
			camLook = fromLook:Lerp(toLook, s)
			if t >= 1 then
				break
			end
			RunService.RenderStepped:Wait()
		end
	end
	-- Suit une cible : positionOf() et lookOf() donnent le point de vue voulu à chaque image, la caméra le rejoint
	-- en douceur. S'arrête après `duration` secondes.
	local function follow(positionOf, lookOf, duration: number, smooth: number?)
		local start = os.clock()
		local k = smooth or 2.2
		while os.clock() - start < duration do
			local dt = RunService.RenderStepped:Wait()
			local targetPos, targetLook = positionOf(), lookOf()
			if targetPos and targetLook then
				camPos = camPos:Lerp(targetPos, 1 - math.exp(-dt * k))
				camLook = camLook:Lerp(targetLook, 1 - math.exp(-dt * 4))
			end
		end
	end

	----------------------------------------------------------------------
	-- Ennemis (dossier workspace.PlotEnemies de PlotRenderer)
	----------------------------------------------------------------------
	local function positionOf(item: Instance?): Vector3?
		if item and item.Parent then
			if item:IsA("BasePart") then
				return item.Position
			elseif item:IsA("Model") then
				return item:GetPivot().Position
			end
		end
		return nil
	end
	local function enemies(): { Instance }
		local folder = workspace:FindFirstChild("PlotEnemies")
		return if folder then folder:GetChildren() else {}
	end
	local function findBoss(): Instance?
		for _, child in enemies() do
			if child:GetAttribute("EnemyType") == "Boss" then
				return child
			end
		end
		return nil
	end
	local function waitForBoss(timeout: number): Instance?
		local deadline = os.clock() + timeout
		local boss = findBoss()
		while not boss and os.clock() < deadline do
			task.wait(0.1)
			boss = findBoss()
		end
		return boss
	end

	----------------------------------------------------------------------
	-- Scènes : niveau des 22 tours et vague (horde d'orcs, Titan du givre, dragon)
	----------------------------------------------------------------------
	local boss: Instance? = nil
	local function bossAt(dx, dy, dz)
		return function()
			local p = positionOf(boss)
			return p and p + offset(dx, dy, dz)
		end
	end
	local function bossLook(dy)
		return function()
			local p = positionOf(boss)
			return p and p + Vector3.new(0, dy, 0)
		end
	end
	local SCENES = {
		-- Niveaux baissés le 01/10/2026 avec les PV des vagues (59 -> 50, 28 -> 23, 74 -> 62) : même temps sous le feu.
		-- Vague 81 : 42 orcs ; tours niveau 50 (la horde tient quelques dizaines de secondes).
		horde = { level = 50, wave = 81, ready = function()
			task.wait(5)
		end },
		-- Vague 40 : le Titan du givre et son escorte ; tours niveau 23 (il tombe en 15 à 20 s).
		titan = { level = 23, wave = 40, ready = function()
			boss = waitForBoss(8)
			task.wait(1)
		end },
		-- Vague 100 : le dragon ; tours niveau 62 (il tient un moment sous le feu).
		dragon = { level = 62, wave = 100, ready = function()
			boss = waitForBoss(10)
			task.wait(1.5)
		end },
	}
	local currentScene = nil
	local function prepare(name: string)
		if currentScene == name then
			return
		end
		local scene = SCENES[name]
		boss = nil
		server("clear")
		local deadline = os.clock() + 8
		while #enemies() > 0 and os.clock() < deadline do
			task.wait(0.1) -- plus aucun ennemi de la scène d'avant (ni même en train de mourir)
		end
		server("towers", scene.level)
		server("wave", scene.wave)
		scene.ready()
		currentScene = name
	end

	----------------------------------------------------------------------
	-- Plans (« rushs ») : start() place la caméra sur la première image, run(d) joue le plan pendant d secondes.
	-- Compilation = total des plans (23 s) + ~0,5 s par plan (début et fin immobiles le temps de la réaction d'OBS) :
	-- ~26,5 s, 30 s au plus.
	----------------------------------------------------------------------
	local RUSHES = {
		{
			name = "parcelle", scene = "horde", seconds = 3.5, image = "parcelle",
			start = function()
				snap(W(0, 78, -98), W(0, 0, 22))
			end,
			run = function(d)
				move(W(0, 44, -54), W(0, 0, 28), d)
			end,
		},
		{
			name = "horde", scene = "horde", seconds = 3, image = "horde",
			start = function()
				snap(W(34, 7, 20), W(-8, 2, 14))
			end,
			run = function(d)
				move(W(26, 6, 6), W(-14, 2, 18), d)
			end,
		},
		{
			name = "titan_arrivee", scene = "titan", seconds = 3, image = "titan_arrivee",
			start = function()
				local p = positionOf(boss)
				snap(W(30, 5, 44), if p then p + Vector3.new(0, 4, 0) else W(0, 4, 50))
			end,
			run = function(d)
				follow(function()
					return W(30, 5, 44)
				end, bossLook(4), d)
			end,
		},
		{
			name = "titan_combat", scene = "titan", seconds = 3.5, image = "titan_combat",
			start = function()
				local p = positionOf(boss)
				if p then
					snap(p + offset(12, 12, -16), p + Vector3.new(0, 3, 0))
				end
			end,
			run = function(d)
				follow(bossAt(12, 12, -16), bossLook(3), d)
			end,
		},
		{
			-- Caméra basse et fixe entre deux rangées de tours ; elle regarde le dragon arriver (au 2e essai, placée
			-- par rapport au dragon, elle finissait derrière le muret de la parcelle).
			name = "dragon", scene = "dragon", seconds = 3.5, image = "dragon",
			start = function()
				local p = positionOf(boss)
				snap(W(10, 3, 36), if p then p + Vector3.new(0, 6, 0) else W(-10, 8, 50))
			end,
			run = function(d)
				follow(function()
					return W(10, 3, 36)
				end, bossLook(6), d)
			end,
		},
		{
			name = "dragon_tour", scene = "dragon", seconds = 3, image = "dragon_tour",
			start = function()
				local p = positionOf(boss)
				if p then
					snap(p + Vector3.new(16, 10, 0), p + Vector3.new(0, 6, 0))
				end
			end,
			run = function(d)
				local start = os.clock()
				follow(function()
					local p = positionOf(boss)
					local angle = (os.clock() - start) * 0.7
					return p and p + Vector3.new(math.cos(angle) * 16, 10, math.sin(angle) * 16)
				end, bossLook(6), d, 6)
			end,
		},
		{
			name = "carte", scene = "dragon", seconds = 3.5, image = "carte",
			start = function()
				snap(W(0, 42, 24), W(0, 0, -8))
			end,
			run = function(d)
				move(W(0, 150, 190), W(0, 0, -150), d)
			end,
		},
	}

	local function playRush(rush, startMarker: string, endMarker: string, withImage: boolean)
		prepare(rush.scene)
		rush.start()
		task.wait(0.15)
		mark(startMarker)
		task.wait(LATENCY) -- OBS démarre (ou reprend) : le plan commence sur sa première image
		if withImage and rush.image then
			task.delay(rush.seconds / 2, function()
				mark("IMG:" .. rush.image)
			end)
		end
		rush.run(rush.seconds)
		mark(endMarker)
		task.wait(LATENCY + 0.2) -- la caméra reste sur la dernière image le temps qu'OBS s'arrête
	end

	----------------------------------------------------------------------
	-- Tournage
	----------------------------------------------------------------------
	server("setup")
	hideUI()
	task.wait(3)

	-- Repérage d'OBS : écran magenta plein cadre.
	do
		local gui = Instance.new("ScreenGui")
		gui.Name = "TournageCalibration"
		gui.IgnoreGuiInset = true
		gui.ScreenInsets = Enum.ScreenInsets.None
		gui.DisplayOrder = 100000
		local frame = Instance.new("Frame")
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundColor3 = Color3.fromRGB(255, 0, 255)
		frame.BorderSizePixel = 0
		frame.Parent = gui
		gui.Parent = playerGui
		task.wait(1)
		mark("CALIBRATE")
		task.wait(10) -- Studio mis au premier plan (1,5 s), puis repérage par OBS
		gui:Destroy()
	end

	-- 1) La compilation : un seul fichier, en pause entre les plans.
	for index, rush in RUSHES do
		local startMarker = if index == 1 then "REC:START" else "REC:RESUME"
		local endMarker = if index == #RUSHES then "REC:STOP:compilation" else "REC:PAUSE"
		playRush(rush, startMarker, endMarker, false)
	end
	task.wait(2)

	-- 2) Les rushs : les mêmes plans rejoués, un fichier par plan, avec une image au milieu de chacun.
	currentScene = nil
	for index, rush in RUSHES do
		playRush(rush, "REC:START", `REC:STOP:rush_{index}_{rush.name}`, true)
		task.wait(1.5) -- le fichier est rangé
	end

	-- 3) Image avec l'interface du jeu (pièces, boutons de gauche), vue de joueur, pendant la horde ; prise à gauche
	-- de la vue 3D pour garder la colonne de boutons (la vue de Studio est plus large que 16:9).
	do
		currentScene = nil
		prepare("horde")
		snap(W(0, 34, -80), W(0, 0, -8))
		showUI()
		mark("CROP:left")
		task.wait(3)
		mark("IMG:interface")
		task.wait(1.5)
		mark("CROP:center")
		hideUI()
		task.wait(1)
	end

	RunService:UnbindFromRenderStep("TournageCamera")
	log("Info", `[TOURNAGE] fini ({#enemies()} ennemis encore sur la parcelle)`)
end

-- Mode tournage (tools/studio-test/tournage.ps1), côté client : caméra de cinéma et marqueurs pour OBS.
--   « CALIBRATE »        -> OBS repère la vue 3D de Studio (écran magenta plein cadre pendant quelques secondes)
--   « REC:START »        -> OBS démarre l'enregistrement ; « REC:STOP:nom » -> l'arrête (vidéo nom.mp4)
--   « IMG:nom »          -> image 1920 x 1080 (nom.png)
-- Les scènes sont préparées par le serveur (TournageServer.luau, ReplicatedStorage.__Tournage). Ce sont les
-- vraies mécaniques du jeu (tours, vagues, effets) : seule la caméra est pilotée, et l'interface est cachée
-- (sauf pour l'image « interface »). Uniquement dans la place de test de tournage.ps1.
return function(log)
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")
	local StarterGui = game:GetService("StarterGui")
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local PlotLayout = require(Shared.PlotLayout)

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local camera = workspace.CurrentCamera
	local remote = ReplicatedStorage:WaitForChild("__Tournage", 90)
	local function server(...)
		return remote:InvokeServer(...)
	end
	local function mark(text)
		log("Info", text)
	end

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
	-- Caméra
	----------------------------------------------------------------------
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = 60
	local camPos = W(0, 80, -100)
	local camLook = W(0, 0, 25)
	local function apply()
		camera.CFrame = CFrame.lookAt(camPos, camLook)
	end
	local function snap(pos: Vector3, look: Vector3)
		camPos, camLook = pos, look
		apply()
	end
	local function ease(t: number): number
		return t * t * (3 - 2 * t)
	end
	-- Mouvement doux d'un plan à un autre.
	local function move(toPos: Vector3, toLook: Vector3, duration: number)
		local fromPos, fromLook = camPos, camLook
		local start = os.clock()
		while true do
			local t = math.clamp((os.clock() - start) / duration, 0, 1)
			local s = ease(t)
			camPos = fromPos:Lerp(toPos, s)
			camLook = fromLook:Lerp(toLook, s)
			apply()
			if t >= 1 then
				break
			end
			RunService.RenderStepped:Wait()
		end
	end
	-- Suit une cible : positionOf() et lookOf() donnent le plan voulu à chaque image, la caméra le rejoint en
	-- douceur (sans à-coups). S'arrête après `duration` secondes, ou quand stop() est vrai.
	local function follow(positionOf, lookOf, duration: number, stop, onHalf)
		local start = os.clock()
		local halfDone = false
		while os.clock() - start < duration do
			local dt = RunService.RenderStepped:Wait()
			if stop and stop() then
				break
			end
			local targetPos, targetLook = positionOf(), lookOf()
			if targetPos and targetLook then
				local k = 1 - math.exp(-dt * 2.2)
				camPos = camPos:Lerp(targetPos, k)
				camLook = camLook:Lerp(targetLook, 1 - math.exp(-dt * 4))
				apply()
			end
			if onHalf and not halfDone and os.clock() - start > duration / 2 then
				halfDone = true
				task.spawn(onHalf)
			end
		end
	end

	----------------------------------------------------------------------
	-- Ennemis (dossier workspace.PlotEnemies de PlotRenderer)
	----------------------------------------------------------------------
	local function positionOf(item: Instance): Vector3?
		if item:IsA("BasePart") then
			return item.Position
		elseif item:IsA("Model") then
			return item:GetPivot().Position
		end
		return nil
	end
	local function findBoss(): Instance?
		local folder = workspace:FindFirstChild("PlotEnemies")
		if folder then
			for _, child in folder:GetChildren() do
				if child:GetAttribute("EnemyType") == "Boss" then
					return child
				end
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
	local function enemyCount(): number
		local folder = workspace:FindFirstChild("PlotEnemies")
		return if folder then #folder:GetChildren() else 0
	end

	----------------------------------------------------------------------
	-- Scènes
	----------------------------------------------------------------------
	server("setup")
	server("towers", 23)
	server("clear")
	hideUI()
	task.wait(3)

	-- 1. Calibrage d'OBS : écran magenta plein cadre.
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

	-- 2. Vidéo : le Titan du givre (boss de la vague 40) face à toutes les tours.
	do
		snap(W(0, 82, -104), W(0, 0, 26))
		task.wait(1)
		mark("REC:START")
		task.wait(3)
		server("wave", 40)
		move(W(0, 52, -64), W(0, 0, 30), 7)
		local boss = waitForBoss(10)
		local function bossPos()
			return if boss and boss.Parent then positionOf(boss) else nil
		end
		local function dead()
			return boss == nil or boss.Parent == nil
		end
		if boss then
			-- Arrivée du boss : plan bas au bord du chemin, la caméra le suit du regard.
			follow(function()
				return W(30, 6, 46)
			end, function()
				local p = bossPos()
				return p and p + Vector3.new(0, 4, 0)
			end, 7, dead, function()
				mark("IMG:boss_glace_arrivee")
			end)
			-- Travelling : devant lui et au-dessus, pendant que les tours le frappent.
			follow(function()
				local p = bossPos()
				return p and p + base:VectorToWorldSpace(Vector3.new(12, 13, -17))
			end, function()
				local p = bossPos()
				return p and p + Vector3.new(0, 3, 0)
			end, 22, dead, function()
				mark("IMG:boss_glace_combat")
			end)
			-- Tour complet autour de lui jusqu'à sa chute.
			local angle = 0
			follow(function()
				local p = bossPos()
				angle += 0.012
				return p and p + Vector3.new(math.cos(angle) * 18, 9, math.sin(angle) * 18)
			end, function()
				local p = bossPos()
				return p and p + Vector3.new(0, 3, 0)
			end, 25, dead, function()
				mark("IMG:boss_glace_tour")
			end)
			task.wait(2.5)
		end
		-- Fin : la caméra s'élève et montre toute la parcelle.
		move(W(0, 60, -70), W(0, 0, 18), 5)
		task.wait(1)
		mark("REC:STOP:boss_de_glace")
		task.wait(3)
	end

	-- 3. Images : le dragon (boss de la vague 100).
	do
		server("clear")
		server("towers", 78)
		snap(W(-34, 10, 44), W(0, 8, 50))
		server("wave", 100)
		local boss = waitForBoss(12)
		if boss then
			local function bossPos()
				return if boss.Parent then positionOf(boss) else nil
			end
			follow(function()
				local p = bossPos()
				return p and p + base:VectorToWorldSpace(Vector3.new(-16, 3, -20))
			end, function()
				local p = bossPos()
				return p and p + Vector3.new(0, 6, 0)
			end, 6, nil, function()
				mark("IMG:dragon_1")
			end)
			follow(function()
				local p = bossPos()
				return p and p + base:VectorToWorldSpace(Vector3.new(20, 16, 14))
			end, function()
				local p = bossPos()
				return p and p + Vector3.new(0, 2, 0)
			end, 6, nil, function()
				mark("IMG:dragon_2")
			end)
		end
		task.wait(2)
	end

	-- 4. Images : une horde d'orcs (vague 81, 42 ennemis) sous le feu de toutes les tours (niveau 59 : elle tient
	-- quelques dizaines de secondes).
	do
		server("clear")
		server("towers", 59)
		snap(W(36, 30, -6), W(-2, 0, 24))
		server("wave", 81)
		task.wait(7)
		mark("IMG:horde_1")
		task.wait(2.5)
		move(W(-32, 15, 34), W(6, 0, 12), 3)
		task.wait(1)
		mark("IMG:horde_2")
		task.wait(2.5)
		-- Avec l'interface du jeu (pièces, boutons), vue de joueur.
		snap(W(0, 34, -80), W(0, 0, -8))
		showUI()
		task.wait(2)
		mark("IMG:interface")
		task.wait(2.5)
		hideUI()
	end

	-- 5. Image : la carte vue du ciel (ta parcelle devant, la place centrale et les autres fiefs derrière).
	do
		snap(W(0, 110, 150), W(0, 0, -150))
		task.wait(2)
		mark("IMG:carte")
		task.wait(2.5)
	end

	mark(`[TOURNAGE] fini ({enemyCount()} ennemis encore sur la parcelle)`)
end

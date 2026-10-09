-- VIDÉO DE LA PAGE DU JEU, côté joueur : tools/studio-test/video.ps1 (pas un test). Le jeu est en anglais (attribut
-- « Lang » du Workspace, posé par mkproj.cjs). Ce scénario met en scène cinq plans et parle à video.ps1 par la Sortie :
--   « CALIBRATE »        : un écran magenta plein cadre : OBS repère la vue 3D de Studio (obs.cjs calibrate) ;
--   « REC:START »        : OBS commence un plan ; « REC:STOP:<nom> » : il l'arrête, rangé dans out/video/<nom>.mp4 ;
--   « VIDEO:done »       : fini (video.ps1 ferme Studio et OBS, puis montage.py coupe et colle les plans).
-- LES PLANS, ceux que le créateur a demandés le 09/10 (la caméra est DANS LE DOS du personnage, sa demande) :
--   r1 « tuez des monstres »            : on le voit finir des cochons à la ferme ;
--   r2 « gagnez des œufs »              : un œuf dans l'enclos, qui éclot ;
--   r3 « équipez-vous de familiers »    : il court dans la savane, ses trois familiers derrière lui ;
--   r4 « améliorez vos épées »          : il frappe avec les doubles lames violettes ;
--   r5 « combattez des monstres épiques »: il court au milieu des dinosaures avec ses trois familiers.
-- Environ 7 s filmées par plan ; le montage en garde 3,2 s, à partir de la première seconde.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

-- Pour ne refilmer qu'un seul plan (les autres fichiers sont gardés par celui qui lance le tournage) : son nom ici.
local ONLY: string? = nil

return function(log)
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local function say(text: string)
		log("Info", text)
	end
	while not player:GetAttribute("Loaded") do
		task.wait(0.1)
	end
	local remote = ReplicatedStorage:WaitForChild("__VideoTest", 30)
	if not remote then
		say("[VIDEO] pas de serveur de tournage")
		say("VIDEO:done")
		return
	end
	local function D(...)
		return remote:InvokeServer(...)
	end
	task.wait(6)

	-- LA CAMÉRA : `shotCamera` (une fonction du temps écoulé depuis le début du plan) la place à chaque image.
	local shotCamera: ((number) -> CFrame)? = nil
	local shotStart = os.clock()
	RunService:BindToRenderStep("VideoCamera", Enum.RenderPriority.Camera.Value + 5, function()
		local camera = workspace.CurrentCamera
		if shotCamera then
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = shotCamera(os.clock() - shotStart)
			camera.FieldOfView = 62
		end
	end)
	local function film(path: (number) -> CFrame)
		shotStart = os.clock()
		shotCamera = path
	end
	local function root(): BasePart?
		return player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	end
	local function teleport(cframe: CFrame)
		local part = root()
		if part then
			part.CFrame = cframe
			part.AssemblyLinearVelocity = Vector3.zero
		end
	end
	-- La caméra DANS LE DOS du personnage : `back` studs derrière lui, `up` au-dessus, un peu sur le côté, et elle
	-- regarde `ahead` studs devant lui. Elle suit en douceur (pas de saccades quand il tourne).
	local function behind(back: number, up: number, side: number, ahead: number): (number) -> CFrame
		local smooth: CFrame? = nil
		return function()
			local part = root()
			if not part then
				return workspace.CurrentCamera.CFrame
			end
			local look = part.CFrame.LookVector * Vector3.new(1, 0, 1)
			look = if look.Magnitude > 0.1 then look.Unit else Vector3.zAxis
			local right = Vector3.yAxis:Cross(look) * -1
			local eye = part.Position - look * back + Vector3.yAxis * up + right * side
			local wanted = CFrame.lookAt(eye, part.Position + look * ahead + Vector3.yAxis * 2)
			smooth = if smooth then smooth:Lerp(wanted, 0.12) else wanted
			return smooth
		end
	end
	-- Fait courir le personnage vers ce point (l'ordre est redonné toutes les 2 s : MoveTo s'arrête après 8 s).
	local running: Vector3? = nil
	task.spawn(function()
		while true do
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if running and humanoid then
				humanoid:MoveTo(running)
			end
			task.wait(2)
		end
	end)
	local function run(to: Vector3?)
		running = to
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local part = root()
		if humanoid and part then
			humanoid:MoveTo(to or part.Position)
		end
	end
	local function hideCore()
		pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
		end)
	end
	local function hud(visible: boolean)
		local gui = playerGui:FindFirstChild("Hud")
		if gui and gui:IsA("ScreenGui") then
			gui.Enabled = visible
		end
	end
	-- Un plan : OBS enregistre `seconds` s (plus le temps qu'il met à démarrer) ; `during` se joue pendant le plan.
	local function record(name: string, seconds: number, during: (() -> ())?)
		-- (ONLY : pour ne refilmer qu'un plan ; les autres sont mis en scène sans être enregistrés, en plus court.)
		if ONLY and name ~= ONLY then
			if during then
				task.spawn(during)
			end
			task.wait(3)
			return
		end
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
	-- Le milieu d'un camp : la moyenne des monstres de ce rang dans cette zone.
	local function camp(zone: number, rank: number): Vector3
		local sum, count = Vector3.zero, 0
		for _, monster in D("Monsters") do
			if monster.zone == zone and monster.rank == rank then
				sum += monster.position
				count += 1
			end
		end
		return if count > 0 then sum / count else Vector3.zero
	end

	-- Calibrage : un écran magenta plein cadre (obs.cjs y trouve le rectangle de l'image du jeu dans Studio).
	hideCore()
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

	-- Le joueur du tournage : tout est ouvert, les monstres ne lui font rien.
	D("Zone", 5)
	D("Peaceful", true)

	-- PLAN 1 : TUEZ DES MONSTRES. Seul, à l'épée de feu, sur le camp des cochons : trois coups par cochon, ils tombent
	-- l'un après l'autre et leurs pièces filent vers lui.
	D("Sword", 5)
	D("Travel", 1)
	task.wait(2)
	local pigs = camp(1, 3)
	teleport(CFrame.lookAt(pigs + Vector3.new(0, 3, -30), pigs + Vector3.new(0, 3, 0)))
	task.wait(1.5)
	hud(true)
	film(behind(15, 8, 4, 8))
	workspace:SetAttribute("AutoAttack", true)
	task.wait(1.6)
	record("r1", 7)
	workspace:SetAttribute("AutoAttack", false)

	-- PLAN 2 : GAGNEZ DES ŒUFS. Un œuf épique posé dans l'enclos, vu de près ; il éclot au milieu du plan.
	hud(false)
	D("Travel", "base")
	task.wait(2)
	local plot = D("Plot")
	local origin: Vector3 = plot.origin
	teleport(CFrame.lookAt(origin + Vector3.new(4, 3, 2), origin + Vector3.new(12, 3, 16)))
	-- (Les œufs gagnés au plan 1 sont déjà dans le sac : on en ajoute, et on en pose quatre côte à côte.)
	for _, rank in { 5, 4, 3, 2 } do
		D("Egg", 1, rank)
	end
	task.wait(0.5)
	for _, x in { 6, 10, 14, 18 } do
		D("Place", x, 13)
		task.wait(0.2)
	end
	task.wait(1.5)
	film(function(t)
		local angle = 4.25 + t * 0.07
		local eggs = origin + Vector3.new(12, 0, 13)
		return CFrame.lookAt(eggs + Vector3.new(math.cos(angle) * 15, 5.5, math.sin(angle) * 15), eggs + Vector3.new(0, 2.4, 0))
	end)
	task.wait(0.8)
	record("r2", 7, function()
		task.wait(1.7)
		D("Hatch")
	end)

	-- Les trois familiers de la suite : le tigre, le lion et l'ours (ils rejoignent l'équipe à leur création).
	ReplicatedStorage:WaitForChild("UnequipAll"):FireServer()
	task.wait(0.5)
	for _, pet in { { "Tiger", 6 }, { "Lion", 6 }, { "Bear", 6 } } do
		D("Pet", pet[1], pet[2])
	end

	-- PLAN 3 : ÉQUIPEZ-VOUS DE FAMILIERS. Il court sur le chemin de la savane, ses trois familiers derrière lui.
	D("Sword", 7)
	D("Travel", 4)
	task.wait(3)
	local start4 = root()
	local savanna = if start4 then start4.Position else Vector3.zero
	teleport(CFrame.lookAt(savanna + Vector3.new(0, 0, 14), savanna + Vector3.new(0, 0, 200)))
	task.wait(1.5)
	film(behind(20, 15, 0, 16))
	run(savanna + Vector3.new(0, 0, 230))
	task.wait(1.8)
	record("r3", 7)
	run(nil)

	-- PLAN 4 : AMÉLIOREZ VOS ÉPÉES. Les doubles lames violettes, contre les hyènes de la savane (petites : on voit
	-- bien le personnage et ses deux lames ; elles encaissent plusieurs coups).
	ReplicatedStorage:WaitForChild("UnequipAll"):FireServer()
	D("Sword", 8)
	task.wait(1)
	local hyenas = camp(4, 1)
	teleport(CFrame.lookAt(hyenas + Vector3.new(0, 3, -30), hyenas + Vector3.new(0, 3, 0)))
	task.wait(1.5)
	hud(true)
	film(behind(11, 6, 4, 6))
	workspace:SetAttribute("AutoAttack", true)
	task.wait(2.2)
	record("r4", 7)
	workspace:SetAttribute("AutoAttack", false)

	-- PLAN 5 : COMBATTEZ DES MONSTRES ÉPIQUES. Il court au milieu des dinosaures avec ses trois familiers (places 1, 2
	-- meilleurs), la griffe du tigre à la main, vers l'arène du T-rex.
	hud(false)
	D("Sword", 11)
	D("Travel", 5)
	-- (« Équiper les meilleurs » : le tigre, le lion et l'ours. Le serveur refuse de changer l'équipe pendant un
	-- combat : on attend d'en être sorti, après le voyage, et on redemande.)
	for _ = 1, 3 do
		task.wait(3)
		ReplicatedStorage:WaitForChild("EquipBest"):FireServer()
	end
	task.wait(1)
	local start5 = root()
	local dinos = if start5 then start5.Position else Vector3.zero
	teleport(CFrame.lookAt(dinos + Vector3.new(0, 0, 100), dinos + Vector3.new(0, 0, 300)))
	task.wait(1.5)
	film(behind(22, 17, 0, 20))
	run(dinos + Vector3.new(0, 0, 250))
	task.wait(1.8)
	record("r5", 7)
	run(nil)

	shotCamera = nil
	say("VIDEO:done")
end

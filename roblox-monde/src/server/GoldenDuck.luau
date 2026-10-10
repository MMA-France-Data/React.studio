-- LE CANARD DORÉ GÉANT (demande du créateur, 10/10, pour casser la répétition : « oui vas-y, fais le canard doré » ;
-- « spawn dans 20 secondes après l'alerte », « une icône en haut avec un timer » ; « mets-lui des attaques, mais si
-- tu meurs ça ne t'enlève pas ta progression, tu revis et tu peux repartir combattre ; avec des zones à esquiver,
-- par exemple des cercles, et un œuf de canard qui tombe »).
--   Toutes les Config.DUCK.every secondes, un canard doré géant apparaît dans la grande allée de la BASE (le seul
--   endroit commun à tous les joueurs, où qu'ils soient dans les mondes). Attributs de workspace : « DuckAt » =
--   l'heure (os.time) de la prochaine apparition ; « DuckUntil » = l'heure où il repart (0 quand il n'est pas là).
--   L'écran affiche le minuteur, et l'alerte Config.DUCK.warn secondes avant.
--   C'EST UNE PIÑATA : chaque coup compte pour 1, quelle que soit l'épée (Monsters.spawnEvent) : un débutant sert
--   autant qu'un ancien. Il faut `hits` coups, plus `hitsMore` par joueur du serveur en plus du premier.
--   SES ATTAQUES, annoncées par un rond rouge au sol : des œufs géants qui tombent sur les joueurs (rond de
--   eggRadius), et un coup de patte tout autour de lui (rond de stompRadius). Qui reste dans le rond à la fin meurt,
--   réapparaît dans son espace 2 secondes après, et revient taper : son compte de coups est GARDÉ.
--   RÉCOMPENSE, s'il est battu avant Config.DUCK.stay secondes : chaque joueur qui a donné au moins minHits coups
--   gagne des pièces et de l'XP, et rien d'autre, selon SA progression (le camp le plus fort qu'il a déjà battu).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Gym = require(script.Parent.Gym)
local Monsters = require(script.Parent.Monsters)
local PlayerData = require(script.Parent.PlayerData)

local Duck = {}

local D = Config.DUCK
local random = Random.new()
local notify
local folder: Folder
local forced: number? = nil -- (tests) : l'heure imposée de la prochaine apparition

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- UNE ZONE À ESQUIVER : un rond rouge au sol pendant `warn` secondes, de plus en plus vif ; puis tout joueur encore
-- dedans meurt. egg : un œuf géant tombe du ciel et s'écrase à la fin.
local function danger(center: Vector3, radius: number, warn: number, egg: boolean)
	local ground = Vector3.new(center.X, 0.35, center.Z)
	local disc = Instance.new("Part")
	disc.Name = "DuckDanger"
	disc.Shape = Enum.PartType.Cylinder
	disc.Size = Vector3.new(0.3, radius * 2, radius * 2)
	disc.CFrame = CFrame.new(ground) * CFrame.Angles(0, 0, math.pi / 2)
	disc.Anchored = true
	disc.CanCollide = false
	disc.CanQuery = false
	disc.CanTouch = false
	disc.Material = Enum.Material.Neon
	disc.Color = Color3.fromRGB(255, 40, 40)
	disc.Transparency = 0.8
	disc.Parent = folder
	TweenService:Create(disc, TweenInfo.new(warn, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 0.3 }):Play()
	task.delay(math.max(0, warn - 0.55), function()
		if not egg then
			return
		end
		local shell = Instance.new("Part")
		shell.Name = "DuckEgg"
		shell.Size = Vector3.new(radius * 1.1, radius * 1.5, radius * 1.1)
		shell.Position = ground + Vector3.new(0, 80, 0)
		shell.Anchored = true
		shell.CanCollide = false
		shell.CanQuery = false
		shell.CanTouch = false
		shell.Color = Color3.fromRGB(255, 236, 170)
		shell.Material = Enum.Material.SmoothPlastic
		local shape = Instance.new("SpecialMesh")
		shape.MeshType = Enum.MeshType.Sphere
		shape.Parent = shell
		shell.Parent = folder
		TweenService:Create(shell, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = ground + Vector3.new(0, radius * 0.6, 0) }):Play()
		task.delay(0.6, shell.Destroy, shell)
	end)
	task.delay(warn, function()
		for _, player in Players:GetPlayers() do
			local root = rootOf(player)
			if root and Vector3.new(root.Position.X - ground.X, 0, root.Position.Z - ground.Z).Magnitude <= radius then
				local humanoid = root.Parent and root.Parent:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid.Health = 0
				end
			end
		end
		-- L'éclat : le rond devient jaune et s'efface.
		disc.Color = Color3.fromRGB(255, 220, 60)
		disc.Transparency = 0.15
		TweenService:Create(disc, TweenInfo.new(0.35), { Transparency = 1 }):Play()
		task.delay(0.4, disc.Destroy, disc)
	end)
end

-- Des œufs géants : un sur chaque joueur venu se battre (à moins de eggRange du canard : pas sur ceux qui sont
-- restés dans leur enclos), et deux au hasard autour du canard.
local function eggs()
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if root and (root.Position - D.spot).Magnitude < D.eggRange then
			danger(root.Position, D.eggRadius, D.eggWarn, true)
		end
	end
	for _ = 1, 2 do
		local angle, away = random:NextNumber(0, math.pi * 2), random:NextNumber(14, 26)
		danger(D.spot + Vector3.new(math.cos(angle) * away, 0, math.sin(angle) * away), D.eggRadius, D.eggWarn, true)
	end
end

-- Le coup de patte : un grand rond tout autour de lui.
local function stomp()
	danger(D.spot, D.stompRadius, D.stompWarn, false)
end

-- Un passage du canard. Renvoie true s'il a été battu.
function Duck.run(): boolean
	local count = #Players:GetPlayers()
	if count == 0 then
		return false
	end
	local need = math.min(D.hitsMax, D.hits + D.hitsMore * (count - 1))
	local won, over = false, false
	local boss = Monsters.spawnEvent({
		animal = D.animal,
		scale = D.scale,
		hits = need,
		position = D.spot,
		folder = folder,
		onDown = function()
			won, over = true, true
		end,
	})
	for _, player in Players:GetPlayers() do
		player:SetAttribute("DuckHits", 0)
	end
	workspace:SetAttribute("DuckUntil", os.time() + D.stay)
	local started = os.clock()
	local nextAttack, turn = started + 3, 0
	while not over and os.clock() - started < D.stay do
		task.wait(0.2)
		if not over and os.clock() >= nextAttack then
			nextAttack = os.clock() + D.attackEvery
			turn += 1
			if turn % 3 == 0 then
				stomp()
			else
				eggs()
			end
		end
	end
	workspace:SetAttribute("DuckUntil", 0)
	if not won then
		Monsters.removeEvent(boss)
	end
	-- Les récompenses.
	for player, hits in boss.hitters do
		local data = player:IsDescendantOf(Players) and PlayerData.get(player)
		if data then
			if not won then
				notify(player, "duckLost")
			elseif hits < D.minHits then
				notify(player, "duckFew", hits, D.minHits)
			else
				-- Des pièces et de l'XP, selon SA progression : le camp le plus fort qu'il a déjà battu.
				local zone, rank = data.hz or 0, data.hr or 0
				if zone < 1 or rank < 1 then
					zone, rank = data.zone, 1
				end
				local def = Config.monster(zone, math.min(rank, 5))
				local coins = math.floor(def.coins * D.coins * PlayerData.passMult(player, "coins") + 0.5)
				local xp = math.floor(def.xp * D.xp * PlayerData.passMult(player, "xp") + 0.5)
				PlayerData.addCoins(player, coins)
				local levels = Monsters.giveXp(player, xp)
				Monsters.publishTeam(player)
				if levels > 0 then
					Gym.applyStats(player, true)
					notify(player, "playerLevel", data.level)
				end
				notify(player, "duckWon", coins, xp, hits)
			end
		end
	end
	return won
end

-- (Tests.) Le prochain canard arrive dans `seconds` secondes.
function Duck.force(seconds: number)
	forced = os.time() + seconds
	workspace:SetAttribute("DuckAt", forced)
end

function Duck.start(notifier)
	notify = notifier
	folder = Instance.new("Folder")
	folder.Name = "GoldenDuck"
	folder.Parent = workspace
	workspace:SetAttribute("DuckUntil", 0)
	task.spawn(function()
		while true do
			local at = os.time() + D.every
			forced = nil
			workspace:SetAttribute("DuckAt", at)
			while os.time() < (forced or at) do
				task.wait(0.5)
			end
			local ok, problem = pcall(Duck.run)
			if not ok then
				warn("[Monde] canard doré : " .. tostring(problem))
				workspace:SetAttribute("DuckUntil", 0)
			end
		end
	end)
end

return Duck

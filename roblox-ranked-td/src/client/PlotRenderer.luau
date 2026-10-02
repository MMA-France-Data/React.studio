-- Affichage du mode infini côté client : ennemis des parcelles, tirs des tours, pièces à ramasser.
-- Le serveur envoie la position des ennemis quelques fois par seconde ; entre deux paquets,
-- le client les fait avancer lui-même pour que le mouvement reste fluide.
-- Parcelles reçues : la tienne toujours, celles des autres seulement quand tu t'en approches (règle côté
-- serveur : Hub/PlotInterest.luau). Quand tu t'en éloignes, le serveur envoie un paquet « Clear » et la
-- parcelle est effacée tout de suite (clearPlot).
-- Vitesse x2 (pass de jeu) : le serveur publie l'attribut « SimSpeed » (1 ou 2) sur le dossier de la
-- parcelle et toute sa simulation va SimSpeed fois plus vite. Le facteur de vitesse du paquet ne
-- contient PAS ce x2 : c'est ici qu'on le multiplie (voir simSpeedOf).
-- Projectiles : chaque tir du paquet dit combien de temps il lui reste à voler (en secondes de simulation,
-- format dans PlotGame.luau) ; le projectile est animé jusqu'au point d'impact prévu par le serveur en
-- vol / SimSpeed secondes, et l'impact (explosion, zone de feu des flèches) apparaît quand les dégâts tombent.
-- Flèches, rochers de la Catapulte et carreaux de la Baliste SUIVENT leur cible (id envoyé après les tirs) :
-- pendant le vol, ils vont vers l'ennemi affiché (même règle que le serveur, voir followTarget), et l'impact
-- tombe sur lui ; s'il disparaît (tué par une autre tour), ils retombent sur le point prévu.
-- Rayon du Sorcier des arcanes : lu sur les attributs « BeamTarget » / « BeamRamp » de sa tour, dessiné à
-- chaque image jusqu'à l'ennemi affiché ici (voir updateBeams).
-- Styles des ennemis : un par tranche de 10 vagues (MedievalModels.decorateEnemy avec le palier, voir palierOf).
-- Contrôles et fragilité : après les positions, le paquet PlotSync contient un octet « contrôle » par ennemi
-- (format dans PlotGame.luau). Effets distincts : brume et éclats de givre aux pieds, étincelles de foudre,
-- étoiles dorées au-dessus d'un ennemi étourdi, motes violettes quand il est fragile. Le contour violet de
-- la barre de vie est conservé. Les ancres sont créées une fois, soudées, et nettoyées avec l'ennemi.
-- Baliste lourde : à l'impact de son carreau perçant, une traînée montre la ligne touchée (largeur du serveur).
-- Modèles perso (CustomModels.luau) : si le propriétaire a mis un modèle pour ce type (et ce palier) dans
-- ReplicatedStorage.EnemyModels, l'ennemi est une copie de ce modèle soudée à la même racine invisible que les
-- blocs (déplacée pareil). Sa marche (Animation « Marche ») n'est jouée que près de la caméra, avec un nombre
-- maximal de pistes, à la vitesse de l'ennemi (ralenti = plus lent, étourdi = figé, Vitesse x2 = 2 fois plus
-- vite) : voir updateAnimations. Tué, il joue son animation de mort s'il en a une (startDeath, updateDying).
-- Sons (SoundManager, réglages dans Sounds.luau) : tirs et impacts (SHOT_SOUNDS), morts, arrivée d'un boss ou d'un
-- colosse sur ta parcelle, pièces ramassées, bourdonnement du rayon du Sorcier.
-- CAMP D'ENTRAÎNEMENT (nouvelle formule) : une parcelle dont le dossier porte l'attribut « Camp » n'a plus de monstres
-- mais des cibles d'entraînement (MedievalModels.trainingTarget), sur lesquelles tirent les tours du camp.
-- NIVEAUX (prototype de la nouvelle formule, Shared/Levels.luau) : la zone de combat d'un niveau s'affiche comme une
-- parcelle de plus. Son numéro (Levels.isArena) donne son centre (Levels.arenaCFrame) ; son chemin est celui de sa
-- carte (attribut « Map » de son dossier, workspace.Arenas.Arena<n>) au lieu de celui des parcelles : voir
-- plotState et refreshLayout. Tout le reste (monstres, tirs, rayons, feu, étiquettes) est le même code.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local CustomModels = require(Shared.CustomModels)
local Enemies = require(Shared.Enemies)
local IdleConfig = require(Shared.IdleConfig)
local IdleTowers = require(Shared.IdleTowers)
local Levels = require(Shared.Levels)
local MedievalModels = require(Shared.MedievalModels)
local NumberFormat = require(Shared.NumberFormat)
local PlotLayout = require(Shared.PlotLayout)
local ProximityLabel = require(Shared.ProximityLabel)
local Remotes = require(Shared.Remotes)
local Effects = require(script.Parent.Effects)
local SoundManager = require(script.Parent.SoundManager)

local PlotRenderer = {}

-- Appelée quand un ennemi affiché vient d'être tué : (numéro de la parcelle ou de la zone, type d'ennemi, position).
-- LevelsUI s'en sert pour montrer l'or gagné au-dessus du monstre, pendant un niveau. Rien par défaut.
PlotRenderer.onEnemyKilled = nil :: ((number, string, Vector3) -> ())?

-- Sons (Sounds.luau, joués par SoundManager, 3D : seulement près de la caméra, avec des limites) :
-- launch = au départ, à la tour ; strike = foudre instantanée, sur la cible ; impact = à l'arrivée du
-- projectile (quand les dégâts tombent).
local SHOT_SOUNDS = {
	MachineGun = { launch = "ArcherShot" },
	Frost = { launch = "FrostPulse" },
	Bomb = { launch = "CatapultLaunch", impact = "CatapultImpact" },
	Tesla = { strike = "StormLightning" },
	Rocket = { launch = "BallistaShot", impact = "BallistaImpact" },
	Chain = { strike = "OracleChain" },
	Orbital = { launch = "TrebuchetLaunch", impact = "TrebuchetImpact" },
}
-- Mort d'un ennemi (les autres types : EnemyDeath).
local DEATH_SOUNDS = { Boss = "BossDeath", Giant = "BigDeath", Tank = "BigDeath" }
-- Boss ou colosse qui vient d'apparaître (à moins de ça du début du chemin) sur TA parcelle : son 2D.
local ARRIVAL_SOUNDS = { Boss = "BossArrival", Giant = "GiantArrival" }
local ARRIVAL_DISTANCE = 15

local ENEMY_BYTES = 11
-- Octet « contrôle » (un par ennemi, après les count x ENEMY_BYTES octets, même ordre) : bits 0-3 = numéro
-- (IdleTowers.ORDER) de la tour dont le contrôle est en cours (0 = aucun), bit 7 = fragile.
local CONTROL_SOURCE_MASK = 16 -- control % 16 = bits 0-3
local CONTROL_FRAGILE_FLAG = 128
local FRAGILE_COLOR = Color3.fromRGB(196, 130, 255) -- fragile (aura du Totem de givre)
local SHOT_BYTES = 27 -- départ 3xf32, arrivée 3xf32, type u8, rayon u8, vol restant u8 (centièmes de s)
-- Après les count x SHOT_BYTES octets : l'id u32 de la cible suivie par chaque tir (0 = aucune), même ordre.
local SHOT_TARGET_BYTES = 4
local SNAP_DISTANCE = 4 -- au-delà, on replace l'ennemi directement à la position du serveur (x SimSpeed)
-- Un ennemi qui disparaît à moins de ça du bout du chemin est PARTI, pas mort (fantassin du défilé d'accueil d'un
-- nouveau joueur, PlotGame:startParade) : ni son ni animation de mort.
local EXIT_DISTANCE = 8
local MAX_FIRE_VISUALS = 10 -- zones de feu affichées au plus par parcelle (la plus vieille disparaît)
local FIRE_FADE_TIME = 0.25
local BEAM_HEAT_SPEED = 8 -- vitesse à laquelle l'épaisseur du rayon suit sa montée
local MAX_SIM_SPEED = 4 -- garde-fou : une valeur abîmée ne fait pas s'envoler les ennemis
-- Pièces ramassées à distance (pass Ramassage auto) : plus loin que ça du joueur, la pile s'envole vers lui.
local REMOTE_PICKUP_DISTANCE = IdleConfig.PICKUP_RADIUS + 4
local REMOTE_GAIN_DELAY = 0.6 -- les gains des piles arrivées ensemble s'affichent en un seul « +X »
-- Marche des modèles perso : jouée seulement à moins de ANIM_DISTANCE studs de la caméra, ANIM_MAX_TRACKS
-- pistes à la fois au plus (au-delà, le modèle avance figé), vérifié toutes les ANIM_CHECK_INTERVAL s.
local ANIM_DISTANCE = 150
local ANIM_MAX_TRACKS = 120
local ANIM_CHECK_INTERVAL = 0.25
local ANIM_RATE_STEP = 0.02 -- écart de vitesse sous lequel on ne touche pas à la piste
-- Sens d'un modèle que son animation retourne (CustomModels.measureFlip) : mesuré seulement sur une marche qui
-- joue sans interruption depuis au moins ce temps (juste après un Play, les os sont encore au repos).
local FLIP_MEASURE_DELAY = 0.5
-- Modèles dont le sens est en cours de mesure : [modèle préparé] = l'ennemi qui sert à la mesure.
local flipSamplers = {}
-- Mort des modèles perso qui ont une animation de mort (CustomModels : « Mort », « Dead »...) : jouée une fois
-- là où l'ennemi est tombé (tué pendant la vague, pas quand la vague est ratée ou arrêtée), seulement à moins
-- de ANIM_DISTANCE studs de la caméra et DEATH_MAX_ACTIVE corps à la fois (boss et colosses toujours). La
-- dernière pose est gardée, puis le corps s'efface en DEATH_FADE_TIME s (au plus DEATH_MAX_TIME s d'animation).
local DEATH_MAX_ACTIVE = 12
local DEATH_MAX_TIME = 3
local DEATH_DEFAULT_TIME = 1.2 -- animation pas encore chargée : durée inconnue
local DEATH_FADE_TIME = 0.6
local DEATH_HOLD_MARGIN = 0.05 -- figée juste avant sa fin (sinon Roblox remet la pose de départ)
local DEATH_ALWAYS = { Boss = true, Giant = true }

local folder = Instance.new("Folder")
folder.Name = "PlotEnemies"
local coinFolder = Instance.new("Folder")
coinFolder.Name = "Coins"

local plotsFolder: Instance? = nil -- workspace.Hub.Plots (trouvé dans start)
-- [plotIndex] = { cframe, folder, enemies = { [id] = enemy }, fires = { zone de feu }, generation, cleared,
--                 pointAt, pathLength (son chemin), arena (zone de combat d'un niveau), mapName (carte de la zone) }
-- (generation et cleared : voir clearPlot)
local plots = {}
local beams = {} -- [modèle de tour à rayon] = { plotIndex, def, muzzle, targetId, ramp, heat, handle }
local coins = {} -- [id] = { part, label }
local flyingCoins = {} -- piles ramassées à distance, en vol vers le joueur : { part, from, size, started, duration }
local remoteGain = 0
local remoteGainPending = false
local playingTracks = 0 -- pistes de marche en cours (modèles perso)
local animClock = 0
local dying = {} -- corps qui jouent leur animation de mort : { part, track, rate, started, fadeAt, plotIndex }
-- Réutilisées à chaque image (pas de nouvelles tables) : racines à déplacer et leurs CFrames.
local movedParts: { BasePart } = {}
local movedCFrames: { CFrame } = {}

local function plotState(plotIndex: number)
	local state = plots[plotIndex]
	if not state then
		local arena = Levels.isArena(plotIndex)
		state = {
			cframe = if arena then Levels.arenaCFrame(Levels.slotOf(plotIndex)) else PlotLayout.cframe(plotIndex),
			-- Chemin : celui des parcelles ; pour une zone de combat, celui de sa carte (refreshLayout).
			pointAt = PlotLayout.pointAt,
			pathLength = PlotLayout.PATH_LENGTH,
			arena = arena,
			mapName = nil,
			enemies = {},
			fires = {},
			generation = 0,
			cleared = false,
		}
		plots[plotIndex] = state
	end
	return state
end

-- Dossier de la parcelle (workspace.Hub.Plots.Plot<n>) ou de la zone de combat (workspace.Arenas.Arena<n>) : ses
-- attributs (SimSpeed, Wave, State...) sont publiés par le serveur.
local function folderOf(plotIndex: number, state): Instance?
	local plotFolder = state.folder
	if not plotFolder or not plotFolder.Parent then
		if state.arena then
			local arenas = workspace:FindFirstChild("Arenas")
			plotFolder = arenas and arenas:FindFirstChild("Arena" .. Levels.slotOf(plotIndex))
		else
			plotFolder = plotsFolder and plotsFolder:FindFirstChild("Plot" .. plotIndex)
		end
		state.folder = plotFolder
	end
	return plotFolder
end

-- Zone de combat d'un niveau : son chemin est celui de sa carte (attribut « Map » de son dossier). Renvoie faux
-- tant que la carte n'est pas connue (l'attribut arrive juste avant les premiers monstres).
local function refreshLayout(plotIndex: number, state): boolean
	if not state.arena then
		return true
	end
	local arenaFolder = folderOf(plotIndex, state)
	local mapName = arenaFolder and arenaFolder:GetAttribute("Map")
	if typeof(mapName) == "string" and mapName ~= state.mapName and Levels.MAPS[mapName] then
		local geometry = Levels.geometry(mapName)
		state.mapName = mapName
		state.pointAt = geometry.pointAt
		state.pathLength = geometry.PATH_LENGTH
	end
	return state.mapName ~= nil
end

-- Vitesse de la simulation de cette parcelle : 1 (normal) ou 2 (pass Vitesse x2 activé), lue sur
-- l'attribut « SimSpeed » du dossier de la parcelle (publié par le serveur, PlotGame).
local function simSpeedOf(plotIndex: number, state): number
	local plotFolder = folderOf(plotIndex, state)
	local speed = plotFolder and plotFolder:GetAttribute("SimSpeed")
	if typeof(speed) ~= "number" or speed ~= speed then
		return 1
	end
	return math.clamp(speed, 1, MAX_SIM_SPEED)
end

local function characterRoot(): BasePart?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Style des ennemis : un par tranche de 10 vagues (palier 0 = vagues 1-10, 1 = 11-20 ... 9 = 91-100, puis
-- MedievalModels recommence), lu sur l'attribut « Wave » du dossier de la parcelle quand l'ennemi apparaît.
local WAVES_PER_STYLE = 10

local function palierOf(plotIndex: number, state): number
	simSpeedOf(plotIndex, state) -- retrouve le dossier de la parcelle si besoin
	local wave = state.folder and state.folder:GetAttribute("Wave")
	if typeof(wave) ~= "number" or wave ~= wave or wave < 1 or wave == math.huge then
		return 0
	end
	return math.floor((wave - 1) / WAVES_PER_STYLE)
end

-- Hauteur du haut du modèle au-dessus du centre de sa racine (couronne, cornes...) : la barre de vie
-- se pose juste au-dessus. Calculé une fois, à la création.
local function modelTop(root: BasePart): number
	local top = root.Size.Y / 2
	local rootY = root.Position.Y
	for _, child in root:GetChildren() do
		if child:IsA("BasePart") then
			local cf, size = child.CFrame, child.Size
			local halfY = math.abs(cf.RightVector.Y) * size.X / 2 + math.abs(cf.UpVector.Y) * size.Y / 2 + math.abs(cf.LookVector.Y) * size.Z / 2
			top = math.max(top, cf.Position.Y - rootY + halfY)
		end
	end
	return top
end

-- Monstres d'un NIVEAU : la carte est vue de haut et de loin, ils sont affichés plus gros (Levels.ENEMY_SCALE).
-- Affichage seulement : une copie de la fiche du type, avec sa taille multipliée (modèle, barre de vie, effets,
-- hauteur au-dessus du chemin en découlent). Le combat, côté serveur, ne connaît que leur place sur le chemin.
local arenaDefs = {}
local function arenaDef(enemyType: string, def)
	local scaled = arenaDefs[enemyType]
	if not scaled then
		scaled = table.clone(def)
		scaled.size = def.size * Levels.enemyScale(enemyType)
		arenaDefs[enemyType] = scaled
	end
	return scaled
end

-- palier : style du mode solo (voir palierOf). Les ennemis du ranked gardent leur appel sans palier (Match).
-- camp = parcelle devenue camp d'entraînement (attribut « Camp » de son dossier, Hub/CampGame.luau) : ce qui suit le
-- chemin n'est pas un monstre mais une CIBLE d'entraînement (mannequin de paille sur un chariot).
-- Renvoie la racine (déplacée à chaque image), la barre de vie, son contour et le modèle perso (nil = blocs).
local function createEnemy(enemyType: string, def, palier: number, camp: boolean?)
	-- Modèle perso du propriétaire pour ce type et ce palier (ReplicatedStorage.EnemyModels), sinon les blocs.
	local part, custom = nil, nil
	if not camp then
		part, custom = CustomModels.spawn(enemyType, def, palier)
	end
	local top
	if part and custom then
		top = custom.top
	else
		part = Instance.new("Part")
		part.Size = Vector3.one * def.size
		part.Color = def.color
		part.Material = Enum.Material.SmoothPlastic
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		if camp then
			MedievalModels.trainingTarget(part, def)
		else
			MedievalModels.decorateEnemy(part, def, palier)
		end
		top = modelTop(part)
	end
	part:SetAttribute("EnemyType", enemyType)

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(math.max(30, def.size * 12), 5)
	billboard.StudsOffset = Vector3.new(0, math.max(def.size / 2, top) + 0.8, 0)
	ProximityLabel.register(billboard, Config.LabelDistance.Medium)
	billboard.AlwaysOnTop = true
	billboard.Parent = part
	local background = Instance.new("Frame")
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	background.BorderSizePixel = 0
	background.Parent = billboard
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(90, 220, 90)
	fill.BorderSizePixel = 0
	fill.Parent = background
	-- Contour violet quand l'ennemi est fragile (voir setStatus).
	local stroke = Instance.new("UIStroke")
	stroke.Color = FRAGILE_COLOR
	stroke.Thickness = 1.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Transparency = 1
	stroke.Parent = background

	part.Parent = folder
	return part, fill, stroke, custom
end

-- Animation de mort d'un modèle perso tué (voir DEATH_MAX_ACTIVE) : le corps reste à sa place (il n'est plus
-- déplacé), sans barre de vie ni disque ; updateDying le fige à la fin puis l'efface. Faux = pas d'animation
-- (pas de modèle perso, pas d'animation de mort, trop loin, trop de corps) : l'appelant le retire.
local function startDeath(enemy): boolean
	local custom = enemy.custom
	if not custom or not custom.deathAnimation then
		return false
	end
	if #dying >= DEATH_MAX_ACTIVE and not DEATH_ALWAYS[enemy.part:GetAttribute("EnemyType")] then
		return false
	end
	local camera = workspace.CurrentCamera
	if not camera or (enemy.part.Position - camera.CFrame.Position).Magnitude > ANIM_DISTANCE then
		return false
	end
	local track = CustomModels.loadDeath(enemy.part, custom)
	if not track then
		return false
	end
	for _, child in enemy.part:GetChildren() do
		if child:IsA("BillboardGui") or child.Name == "StatusRing" then
			child:Destroy()
		end
	end
	enemy.part:SetAttribute("Dying", true)
	-- Modèle que ses animations retournent (CustomModels.measureFlip) : racine d'un demi-tour pendant sa mort
	-- aussi (elle l'est déjà s'il marchait).
	if custom.flipWhenAnimated and not enemy.rootFlipped then
		enemy.part.CFrame = enemy.part.CFrame * CFrame.Angles(0, math.pi, 0)
	end
	local rate = enemy.simSpeed or 1
	track:Play(if custom.flipWhenAnimated then 0 else 0.1, 1, rate)
	table.insert(dying, { part = enemy.part, track = track, rate = rate, started = os.clock(), fadeAt = nil, plotIndex = enemy.plotIndex })
	return true
end

-- Retire un ennemi (mort ou arrivé à la base) : sa piste de marche d'abord, puis la racine et tout le modèle.
-- died = tué pendant la vague : son animation de mort s'il en a une (startDeath).
local function removeEnemy(enemy, died: boolean?)
	if enemy.track then
		if enemy.walking then
			playingTracks -= 1
		end
		enemy.walking = false
		enemy.track:Stop(0)
		enemy.track:Destroy()
		enemy.track = nil
	end
	if died and startDeath(enemy) then
		return
	end
	enemy.part:Destroy()
end

-- Corps des animations de mort : figés juste avant la fin de leur animation (dernière pose), puis effacés.
local function updateDying(now: number)
	for i = #dying, 1, -1 do
		local body = dying[i]
		if not body.part.Parent then
			body.track:Destroy()
			table.remove(dying, i)
		elseif not body.fadeAt then
			local track = body.track
			-- Mort publiée en boucle : Roblox peut remettre Looped à vrai quand elle finit de se charger.
			if track.Looped then
				track.Looped = false
			end
			local length = track.Length
			local duration = if length > 0 then length / body.rate else DEATH_DEFAULT_TIME
			if now - body.started >= math.min(duration - DEATH_HOLD_MARGIN, DEATH_MAX_TIME) then
				track:AdjustSpeed(0)
				body.fadeAt = now
				for _, piece in body.part:GetDescendants() do
					if piece:IsA("BasePart") and piece.Transparency < 1 then
						TweenService:Create(piece, TweenInfo.new(DEATH_FADE_TIME), { Transparency = 1 }):Play()
					end
				end
			end
		elseif now - body.fadeAt >= DEATH_FADE_TIME then
			body.track:Destroy()
			body.part:Destroy()
			table.remove(dying, i)
		end
	end
end

-- Ancre invisible, nom conservé pour le nettoyage des morts ; plus de disque plein provisoire.
local function createStatusRing(enemy): BasePart
	return Effects.createStatusVisual(enemy.part, enemy.def.size, if enemy.custom then enemy.custom.top else nil)
end

-- Contrôle en cours (type de tour, nil = aucun) et fragilité, lus dans l'octet « contrôle » du paquet.
-- Ne touche aux pièces que si quelque chose change.
local function setStatus(enemy, source: string?, fragile: boolean)
	if enemy.statusSource == source and enemy.statusFragile == fragile then
		return
	end
	enemy.statusSource = source
	enemy.statusFragile = fragile
	if source or fragile then
		enemy.ring = enemy.ring or createStatusRing(enemy)
		Effects.setStatusVisual(enemy.ring, source, fragile)
	elseif enemy.ring then
		Effects.setStatusVisual(enemy.ring, nil, false)
	end
	enemy.stroke.Transparency = if fragile then 0 else 1
end

-- Paquet « Clear » (serveur, Hub/PlotInterest.luau) : on ne reçoit plus cette parcelle (on s'en est éloigné, ou
-- son propriétaire est parti). Tout ce qu'on en affichait disparaît tout de suite, sans animation de mort ni son
-- (ces ennemis ne sont pas tués : on ne les voit plus) : ennemis, zones de feu, corps des animations de mort.
-- Les rayons des Sorciers s'éteignent seuls (plus d'ennemi visé, voir updateBeams). Les tirs déjà en vol ne
-- font plus de zone de feu ni de traînée (generation), et les paquets de tirs arrivés en retard sont ignorés
-- (cleared) jusqu'au prochain paquet des ennemis : il contient tous les ennemis de la parcelle, qui réapparaît
-- donc entière quand on revient près d'elle.
local function clearPlot(plotIndex: number)
	local state = plotState(plotIndex)
	state.generation += 1
	state.cleared = true
	for _, enemy in state.enemies do
		removeEnemy(enemy, false)
	end
	table.clear(state.enemies)
	for _, fire in state.fires do
		Effects.fadeOut(fire.part, FIRE_FADE_TIME)
	end
	table.clear(state.fires)
	for i = #dying, 1, -1 do
		local body = dying[i]
		if body.plotIndex == plotIndex then
			body.track:Destroy()
			body.part:Destroy()
			table.remove(dying, i)
		end
	end
end

-- kind = "Clear" : paquet vide qui efface la parcelle (clearPlot) ; rien = paquet normal.
local function onSync(plotIndex: number, packet: buffer, count: number, kind: string?)
	if kind == "Clear" then
		clearPlot(plotIndex)
		return
	end
	local state = plotState(plotIndex)
	if not refreshLayout(plotIndex, state) then
		return -- zone de combat dont la carte n'est pas encore connue : le paquet suivant redonnera tout
	end
	state.cleared = false
	-- En x2, les ennemis font 2 fois plus de chemin entre deux paquets : même tolérance en temps.
	local snapDistance = SNAP_DISTANCE * simSpeedOf(plotIndex, state)
	-- Octets « contrôle » après les positions (absents d'un ancien paquet : aucun contrôle).
	local controlStart = count * ENEMY_BYTES
	local hasControl = buffer.len(packet) >= controlStart + count
	local seen = {}
	for i = 0, count - 1 do
		local offset = i * ENEMY_BYTES
		local id = buffer.readu32(packet, offset)
		local enemyType = Enemies.ORDER[buffer.readu8(packet, offset + 4)]
		local def = Enemies.Defs[enemyType]
		local distance = buffer.readf32(packet, offset + 5)
		local health = buffer.readu8(packet, offset + 9) / 255
		local speedFactor = buffer.readu8(packet, offset + 10) / 100
		if not def then
			continue
		end
		seen[id] = true

		local enemy = state.enemies[id]
		if not enemy then
			local palier = palierOf(plotIndex, state)
			local camp = state.folder ~= nil and state.folder:GetAttribute("Camp") == true
			if state.arena then
				def = arenaDef(enemyType, def)
			end
			local part, fill, stroke, custom = createEnemy(enemyType, def, palier, camp)
			enemy = { def = def, part = part, fill = fill, stroke = stroke, distance = distance, statusFragile = false }
			enemy.enemyType = enemyType
			enemy.camp = camp -- cible d'entraînement : détruite sans cri ni or
			enemy.plotIndex = plotIndex -- (son corps, s'il joue sa mort, est effacé avec la parcelle : clearPlot)
			-- Cor de guerre (boss) ou pas lourds (colosse) quand il arrive sur ta parcelle.
			-- (pendant un niveau, seule la zone de combat compte : la parcelle, restée sur la place, se tait)
			local arenaIndex = Players.LocalPlayer:GetAttribute("LevelArena")
			local mine = if arenaIndex ~= nil then plotIndex == arenaIndex else plotIndex == Players.LocalPlayer:GetAttribute("Plot")
			if ARRIVAL_SOUNDS[enemyType] and distance < ARRIVAL_DISTANCE and mine then
				SoundManager.play(ARRIVAL_SOUNDS[enemyType])
			end
			-- Vague où il est apparu : à sa disparition, dit s'il a été tué ou retiré (vague ratée, voir plus bas).
			local wave = state.folder and state.folder:GetAttribute("Wave")
			enemy.wave = if typeof(wave) == "number" then wave else nil
			enemy.custom = custom -- modèle perso (marche, mort), nil = blocs
			if custom and custom.animation then
				-- Modèle perso qui sait marcher (updateAnimations) : vitesse de lecture à sa vitesse normale,
				-- et son facteur de type (le facteur du paquet = type x contrôle).
				local typeFactor = IdleConfig.enemySpeedFactor(enemyType)
				enemy.typeFactor = math.max(typeFactor, 0.01)
				enemy.walkBase = CustomModels.walkRate(custom, def.speed * IdleConfig.ENEMY_SPEED_MULTIPLIER * typeFactor)
			end
			state.enemies[id] = enemy
		elseif math.abs(enemy.distance - distance) > snapDistance then
			enemy.distance = distance
		else
			enemy.distance += (distance - enemy.distance) * 0.5
		end
		enemy.speedFactor = speedFactor
		enemy.fill.Size = UDim2.fromScale(health, 1)
		local control = if hasControl then buffer.readu8(packet, controlStart + i) else 0
		setStatus(enemy, IdleTowers.ORDER[control % CONTROL_SOURCE_MASK], control >= CONTROL_FRAGILE_FLAG)
	end

	-- Absents du paquet = tués, ou retirés (vague ratée, renaissance ; le départ du joueur et une parcelle dont on
	-- s'éloigne envoient un « Clear » à la place, voir clearPlot). Tué = la vague continue
	-- (« Running ») ou vient d'être gagnée (entracte avec une vague plus haute que la sienne) : animation de mort
	-- des modèles perso qui en ont une.
	local runState = state.folder and state.folder:GetAttribute("State")
	local plotWave = state.folder and state.folder:GetAttribute("Wave")
	local simSpeed = simSpeedOf(plotIndex, state)
	for id, enemy in state.enemies do
		if not seen[id] then
			-- (Niveau : « Won » = le dernier monstre vient de tomber ; « Lost » = ils sont retirés, pas tués.)
			local died = runState == "Running"
				or (runState == "Intermission" and typeof(plotWave) == "number" and enemy.wave ~= nil and plotWave > enemy.wave)
				or (state.arena and runState == "Won")
			-- Disparu au bout du chemin pendant que la partie continue : il est parti (défilé d'accueil, ou monstre
			-- d'un niveau arrivé au château), pas mort.
			if died and enemy.distance >= state.pathLength - EXIT_DISTANCE then
				died = false
			end
			enemy.simSpeed = simSpeed
			if died and not enemy.camp then
				SoundManager.playAt(DEATH_SOUNDS[enemy.enemyType] or "EnemyDeath", enemy.part.Position)
				if PlotRenderer.onEnemyKilled then
					PlotRenderer.onEnemyKilled(plotIndex, enemy.enemyType, enemy.part.Position)
				end
			end
			removeEnemy(enemy, died)
			state.enemies[id] = nil
		end
	end
end

----------------------------------------------------------------------
-- Marche des modèles perso (CustomModels) : seulement près de la caméra, ANIM_MAX_TRACKS pistes au plus
----------------------------------------------------------------------

-- Vitesse de lecture du moment : vitesse normale du modèle x (vitesse de l'ennemi / vitesse normale de son
-- type) x Vitesse x2 ; 0 quand il est étourdi (la marche se fige).
local function walkRate(enemy, simSpeed: number): number
	return enemy.walkBase * (enemy.speedFactor or 1) / enemy.typeFactor * simSpeed
end

local function updateAnimations()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local eye = camera.CFrame.Position
	-- 1) Pistes en cours : arrêtées loin de la caméra (place libérée), sinon vitesse mise à jour.
	for plotIndex, state in plots do
		local simSpeed = simSpeedOf(plotIndex, state)
		for _, enemy in state.enemies do
			if not enemy.walking then
				continue
			end
			-- Modèle que son animation retourne : pas de fondu (sinon il pivoterait d'un demi-tour à vue).
			local fade = if enemy.custom.flipWhenAnimated then 0 else 0.2
			if (enemy.part.Position - eye).Magnitude > ANIM_DISTANCE then
				enemy.walking = false
				playingTracks -= 1
				enemy.track:Stop(fade)
			else
				local track = enemy.track
				local rate = walkRate(enemy, simSpeed)
				-- Marche publiée sans boucle : Roblox peut remettre Looped à faux quand l'animation finit de se
				-- charger (après notre Play), et la piste s'arrête au bout d'un pas. On la remet en boucle.
				if not track.Looped then
					track.Looped = true
				end
				if not track.IsPlaying then
					track:Play(fade / 2, 1, rate)
					enemy.walkRateNow = rate
					enemy.walkPlayedAt = os.clock()
				elseif math.abs(rate - enemy.walkRateNow) > ANIM_RATE_STEP then
					enemy.walkRateNow = rate
					track:AdjustSpeed(rate)
				end
				-- Son animation le retourne-t-elle ? Mesuré une fois par modèle, sur un de ses ennemis qui marche
				-- (échantillons à chaque image : voir flipSamplers dans la boucle d'affichage).
				if enemy.custom.flipWhenAnimated == nil and flipSamplers[enemy.custom] == nil then
					flipSamplers[enemy.custom] = enemy
				end
			end
		end
	end
	-- 2) Modèles près de la caméra pas encore animés : on lance leur marche tant qu'il reste de la place.
	for plotIndex, state in plots do
		local simSpeed = simSpeedOf(plotIndex, state)
		for _, enemy in state.enemies do
			if playingTracks >= ANIM_MAX_TRACKS then
				return
			end
			if not enemy.walkBase or enemy.walking or enemy.walkFailed or (enemy.part.Position - eye).Magnitude > ANIM_DISTANCE then
				continue
			end
			if not enemy.track then
				enemy.track = CustomModels.loadWalk(enemy.part, enemy.custom)
				if not enemy.track then
					enemy.walkFailed = true -- pas d'Animator ou animation refusée : il avance figé
					continue
				end
			end
			local rate = walkRate(enemy, simSpeed)
			enemy.track:Play(if enemy.custom.flipWhenAnimated then 0 else 0.2, 1, rate)
			enemy.walkRateNow = rate
			enemy.walkPlayedAt = os.clock()
			enemy.walking = true
			playingTracks += 1
		end
	end
end

local function nearestTower(plotIndex: number, towerType: string, from: Vector3): Model?
	local plotFolder = folderOf(plotIndex, plotState(plotIndex))
	if not plotFolder then
		return nil
	end
	local nearest, nearestDistance = nil, math.huge
	for _, candidate in plotFolder:GetDescendants() do
		if candidate:IsA("Model") and candidate:GetAttribute("TowerType") == towerType then
			local anchor = candidate.PrimaryPart or candidate:FindFirstChild("Base")
			if anchor and anchor:IsA("BasePart") then
				local distance = (anchor.Position - from).Magnitude
				if distance < nearestDistance then
					nearest = candidate
					nearestDistance = distance
				end
			end
		end
	end
	return nearest
end

----------------------------------------------------------------------
-- Zones de feu des flèches enflammées (seulement l'affichage : les dégâts sont calculés par le serveur)
----------------------------------------------------------------------

local function horizontalDistance(a: Vector3, b: Vector3): number
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

-- Une flèche enflammée touche le sol : même règle que le serveur (PlotGame:addFirePatch), une flèche qui
-- tombe dans une zone la ravive au lieu d'en créer une autre. Durée en secondes réelles (/ SimSpeed).
local function addFire(plotIndex: number, position: Vector3, def)
	local state = plotState(plotIndex)
	local now = os.clock()
	local expiresAt = now + def.fireDuration / simSpeedOf(plotIndex, state)
	for _, fire in state.fires do
		if horizontalDistance(fire.position, position) <= def.fireRadius then
			fire.expiresAt = math.max(fire.expiresAt, expiresAt)
			return
		end
	end
	if #state.fires >= MAX_FIRE_VISUALS then
		Effects.fadeOut(table.remove(state.fires, 1).part, FIRE_FADE_TIME)
	end
	table.insert(state.fires, { part = Effects.firePatch(position, def.fireRadius), position = position, expiresAt = expiresAt })
end

-- Éteint les zones de feu arrivées au bout (toutes, si la vague est finie : le serveur les a effacées).
local function updateFires(plotIndex: number, state, now: number)
	if #state.fires == 0 then
		return
	end
	simSpeedOf(plotIndex, state) -- retrouve le dossier de la parcelle si besoin
	local running = state.folder ~= nil and state.folder:GetAttribute("State") == "Running"
	for i = #state.fires, 1, -1 do
		local fire = state.fires[i]
		if not running or now >= fire.expiresAt then
			Effects.fadeOut(fire.part, FIRE_FADE_TIME)
			table.remove(state.fires, i)
		end
	end
end

-- Projectile qui suit sa cible : renvoie la fonction que Effects appelle à chaque image pour savoir où il doit
-- tomber. Même règle que le serveur (PlotGame impactCenter) : l'ennemi visé tel qu'il est affiché ici (au sol)
-- tant qu'il est là et à moins de maxDistance studs (IdleTowers.followDistance) du point prévu par le serveur ;
-- sinon (tué, disparu, trop loin) le point prévu. Une fonction par tir ; aucune table ni fonction créée image
-- par image.
local function followTarget(state, targetId: number, predicted: Vector3, maxDistance: number): () -> Vector3
	return function(): Vector3
		local enemy = state.enemies[targetId]
		if enemy then
			local center = enemy.part.Position
			local ground = Vector3.new(center.X, predicted.Y, center.Z)
			if horizontalDistance(ground, predicted) <= maxDistance then
				return ground
			end
		end
		return predicted
	end
end

-- Arrivée d'une flèche enflammée : sa zone de feu là où elle tombe (sur sa cible si elle la suit).
-- generation = celle de la parcelle au départ du tir : effacée entre-temps (clearPlot), pas de zone de feu.
local function landFire(plotIndex: number, generation: number, predicted: Vector3, def, follow: (() -> Vector3)?)
	if plotState(plotIndex).generation ~= generation then
		return
	end
	addFire(plotIndex, if follow then follow() else predicted, def)
end

-- Arrivée d'un carreau perçant (Baliste lourde) : la ligne touchée par le serveur, de la tour (sous le départ du
-- tir) au point d'impact (sa cible si elle la suit), sur toute sa largeur (2 x pierceWidth). Pas de traînée si
-- la parcelle a été effacée pendant le vol (generation, comme landFire).
local function landPierce(plotIndex: number, generation: number, from: Vector3, predicted: Vector3, def, follow: (() -> Vector3)?)
	if plotState(plotIndex).generation ~= generation then
		return
	end
	Effects.pierceTrail(from, if follow then follow() else predicted, def.pierceWidth, def.color)
end

local function onShots(plotIndex: number, packet: buffer, count: number)
	local state = plotState(plotIndex)
	if state.cleared then
		return -- paquet arrivé après le « Clear » de cette parcelle (voir clearPlot)
	end
	local simSpeed = simSpeedOf(plotIndex, state)
	-- Niveau : le feu des flèches et le carreau perçant ne s'affichent que s'ils sont débloqués par l'entraînement
	-- (attribut « Perks » de la zone, ex. « MachineGun:Fire,Rocket:Pierce » : Levels.perkKeys). Parcelle : toujours.
	-- (Pareil sur une parcelle devenue camp d'entraînement : ses tours ont les stats des niveaux.)
	local perks = nil
	if state.arena or (state.folder ~= nil and state.folder:GetAttribute("Camp") == true) then
		local value = state.folder and state.folder:GetAttribute("Perks")
		perks = if typeof(value) == "string" then value else ""
	end
	-- Ids des cibles suivies, après les tirs (absents d'un ancien paquet : aucun projectile ne suit sa cible).
	local targetStart = count * SHOT_BYTES
	local hasTargets = buffer.len(packet) >= targetStart + count * SHOT_TARGET_BYTES
	for i = 0, count - 1 do
		local offset = i * SHOT_BYTES
		local from = Vector3.new(buffer.readf32(packet, offset), buffer.readf32(packet, offset + 4), buffer.readf32(packet, offset + 8))
		local to = Vector3.new(buffer.readf32(packet, offset + 12), buffer.readf32(packet, offset + 16), buffer.readf32(packet, offset + 20))
		local towerType = IdleTowers.ORDER[buffer.readu8(packet, offset + 24)]
		local def = IdleTowers.Defs[towerType]
		local radius = buffer.readu8(packet, offset + 25)
		-- Vol restant en secondes réelles : le projectile arrive quand le serveur applique les dégâts.
		local flight = buffer.readu8(packet, offset + 26) / 100 / simSpeed
		if not def then
			continue
		end
		local targetId = if hasTargets then buffer.readu32(packet, targetStart + i * SHOT_TARGET_BYTES) else 0
		local follow = if targetId ~= 0 and flight > 0 then followTarget(state, targetId, to, IdleTowers.followDistance(def)) else nil
		Effects.playTowerShot(from, to, towerType, radius, def.color, def.kind, nearestTower(plotIndex, towerType, from), flight, follow)
		-- Sons : ignorés tout de suite loin de la caméra ; l'impact n'est programmé que s'il sera entendu.
		local sounds = SHOT_SOUNDS[towerType]
		if sounds then
			if sounds.launch then
				SoundManager.playAt(sounds.launch, from)
			end
			if sounds.strike then
				SoundManager.playAt(sounds.strike, to)
			end
			if sounds.impact and SoundManager.isAudible(sounds.impact, to) then
				task.delay(flight, SoundManager.playAt, sounds.impact, to)
			end
		end
		if def.fireRadius and (not perks or string.find(perks, towerType .. ":Fire", 1, true)) then
			task.delay(flight, landFire, plotIndex, state.generation, to, def, follow)
		end
		if def.kind == "Pierce" and def.pierceWidth and (not perks or string.find(perks, towerType .. ":Pierce", 1, true)) then
			task.delay(flight, landPierce, plotIndex, state.generation, from, to, def, follow)
		end
	end
end

----------------------------------------------------------------------
-- Rayon continu du Sorcier des arcanes (visible par tout le monde)
----------------------------------------------------------------------

-- Suit une tour à rayon : ses attributs BeamTarget (id de l'ennemi, 0 = éteint) et BeamRamp (montée).
local function watchBeamTower(model: Instance)
	-- Déjà suivie, ou déjà retirée avant cet appel (task.defer) : AncestryChanged ne viendrait plus l'effacer.
	if beams[model] or not model:IsA("Model") or not model:IsDescendantOf(workspace) then
		return
	end
	local def = IdleTowers.Defs[model:GetAttribute("TowerType")]
	local plotIndex = model:GetAttribute("PlotIndex")
	if not def or def.kind ~= "Beam" or typeof(plotIndex) ~= "number" then
		return
	end
	local entry = { plotIndex = plotIndex, def = def, heat = 0, targetId = 0, ramp = 0, handle = nil, muzzle = nil }
	beams[model] = entry
	local function read()
		local targetId = model:GetAttribute("BeamTarget")
		local ramp = model:GetAttribute("BeamRamp")
		entry.targetId = if typeof(targetId) == "number" then targetId else 0
		entry.ramp = if typeof(ramp) == "number" and ramp == ramp then ramp else 0
	end
	read()
	model:GetAttributeChangedSignal("BeamTarget"):Connect(read)
	model:GetAttributeChangedSignal("BeamRamp"):Connect(read)
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) then
			if entry.handle then
				Effects.destroyBeam(entry.handle)
				entry.handle = nil
			end
			SoundManager.removeLoop(model)
			beams[model] = nil
		end
	end)
end

-- Dessine les rayons (après le déplacement des ennemis de cette image, pour les suivre sans retard).
local function updateBeams(dt: number, t: number)
	for model, entry in beams do
		local state = plots[entry.plotIndex]
		local enemy = if state and entry.targetId ~= 0 then state.enemies[entry.targetId] else nil
		if not enemy then
			if entry.handle then
				Effects.hideBeam(entry.handle)
			end
			entry.heat = 0
			SoundManager.setLoop(model, "ArcaneBeam", nil, false)
			continue
		end
		-- 0 = rayon qui démarre (x1), 1 = rayon au maximum (beamRampMax de la tour, sans rune).
		local goal = math.clamp((entry.ramp - 1) / math.max(0.001, entry.def.beamRampMax - 1), 0, 1)
		entry.heat += (goal - entry.heat) * math.min(1, dt * BEAM_HEAT_SPEED)
		if not entry.muzzle or not entry.muzzle.Parent then
			local shard = model:FindFirstChild("ArcaneShard2", true)
			entry.muzzle = if shard and shard:IsA("BasePart") then shard else nil
		end
		local from = if entry.muzzle then entry.muzzle.Position else model:GetPivot().Position + Vector3.new(0, 6, 0)
		entry.handle = entry.handle or Effects.createBeam(entry.def.color)
		Effects.updateBeam(entry.handle, from, enemy.part.Position, entry.heat, t)
		-- Bourdonnement du rayon, à la tour : plus fort et plus aigu quand il monte (SoundManager choisit les plus
		-- proches de la caméra).
		SoundManager.setLoop(model, "ArcaneBeam", entry.muzzle or model.PrimaryPart, true, entry.heat)
	end
end

----------------------------------------------------------------------
-- Pièces (visibles seulement par le propriétaire de la parcelle)
----------------------------------------------------------------------

local function floatingText(position: Vector3, text: string)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	anchor.Position = position
	anchor.Parent = coinFolder

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(140, 34)
	billboard.AlwaysOnTop = true
	billboard.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 215, 80)
	label.TextStrokeTransparency = 0.2
	label.Text = text
	label.Parent = billboard

	TweenService:Create(anchor, TweenInfo.new(0.9), { Position = position + Vector3.new(0, 4, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(0.9), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(1, function()
		anchor:Destroy()
	end)
end

-- Pendant un NIVEAU (LevelsUI.luau : attribut LevelArena du joueur), l'écran montre la zone de combat : les pièces
-- de la parcelle, restée sur la place, sont ramassées sans bruit.
local function inLevel(): boolean
	return Players.LocalPlayer:GetAttribute("LevelArena") ~= nil
end

-- Gains des piles ramassées à distance : additionnés, puis un seul « +X » au-dessus du joueur quand
-- les pièces arrivent (sinon, en x2 avec beaucoup d'ennemis, l'écran serait couvert de « +X »).
local function addRemoteGain(amount: number)
	remoteGain += amount
	if remoteGainPending then
		return
	end
	remoteGainPending = true
	task.delay(REMOTE_GAIN_DELAY, function()
		remoteGainPending = false
		local total = remoteGain
		remoteGain = 0
		local root = characterRoot()
		if root and total > 0 then
			floatingText(root.Position + Vector3.new(0, 3.5, 0), "+" .. NumberFormat.short(total))
			if not inLevel() then
				SoundManager.play("CoinAutoCollect") -- un petit son doux par groupe de piles arrivées
			end
		end
	end)
end

local function onCoinDrop(action: string, id: number, position: Vector3, amount: number)
	local coin = coins[id]
	if action == "Collect" then
		local root = characterRoot()
		local offset = if root then position - root.Position else Vector3.zero
		if not root or Vector3.new(offset.X, 0, offset.Z).Magnitude <= REMOTE_PICKUP_DISTANCE then
			-- Ramassée en marchant dessus : « +X » sur place.
			if coin then
				coin.part:Destroy()
				coins[id] = nil
			end
			floatingText(position, "+" .. NumberFormat.short(amount))
			if not inLevel() then
				SoundManager.play("CoinPickup")
			end
			return
		end
		-- Ramassée à distance (pass Ramassage auto) : la pile s'envole vers le joueur et rétrécit.
		if coin then
			coins[id] = nil
			local billboard = coin.part:FindFirstChildOfClass("BillboardGui")
			if billboard then
				billboard:Destroy() -- son montant ne vole pas avec elle
			end
			table.insert(flyingCoins, {
				part = coin.part,
				from = coin.part.Position,
				size = coin.part.Size,
				started = os.clock(),
				duration = math.clamp(offset.Magnitude / 90, 0.35, 0.8),
			})
		end
		addRemoteGain(amount)
		return
	end

	if not coin then
		local part = Instance.new("Part")
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(0.4, 2, 2)
		part.Color = Color3.fromRGB(255, 200, 60)
		part.Material = Enum.Material.Neon
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Position = position

		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.fromOffset(90, 22)
		billboard.StudsOffset = Vector3.new(0, 1.8, 0)
		ProximityLabel.register(billboard, Config.LabelDistance.Close)
		billboard.Parent = part
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(255, 225, 120)
		label.TextStrokeTransparency = 0.3
		label.Parent = billboard

		part.Parent = coinFolder
		coin = { part = part, label = label, base = position }
		coins[id] = coin
	end
	coin.label.Text = NumberFormat.short(amount)
	-- Les grosses piles grossissent un peu.
	local size = math.clamp(1.6 + math.log10(math.max(1, amount)) * 0.15, 1.6, 3.5)
	coin.part.Size = Vector3.new(0.4, size, size)
end

----------------------------------------------------------------------

-- Étiquette « Niv. X » au pied de chaque tour des parcelles (mise à jour à chaque amélioration).
local function addLevelTag(model: Instance)
	if not model:IsA("Model") or not model:GetAttribute("SpotIndex") then
		return
	end
	local def = IdleTowers.Defs[model:GetAttribute("TowerType")]
	local anchor = model:WaitForChild("Base", 5)
	if not def or not anchor or not anchor:IsA("BasePart") or model:FindFirstChild("LevelTag") then
		return
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "LevelTag"
	billboard.Size = UDim2.fromOffset(64, 22)
	-- Sous la tour, collée à son pied (le socle « Base », au centre de l'emplacement).
	-- Pas de StudsOffsetWorldSpace : il suit l'orientation de la pièce, et « Base » est un cylindre
	-- redressé (tourné de 90°) qui pivote en plus quand la tour vise. L'ancien décalage « vers le haut »
	-- partait donc sur le côté : les étiquettes flottaient à 10-20 studs à droite des tours.
	-- StudsOffset suit la caméra : toujours un peu plus bas à l'écran, sans aucun décalage horizontal.
	billboard.StudsOffset = Vector3.new(0, -1.2, 0)
	billboard.AlwaysOnTop = true -- par-dessus le modèle ; ne s'affiche que de près (ProximityLabel)
	ProximityLabel.register(billboard, Config.LabelDistance.Close)
	billboard.Adornee = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	label.BackgroundTransparency = 0.25
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = def.color:Lerp(Color3.new(1, 1, 1), 0.4)
	label.Parent = billboard
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = label

	-- Étoiles = évolutions de la tour (niveaux : attribut « Stars », Hub/IdleTowerModel.addEvolution).
	local function update()
		local stars = tonumber(model:GetAttribute("Stars")) or 0
		label.Text = if stars > 0 then `{string.rep("★", stars)} Niv. {model:GetAttribute("Level") or 1}` else `Niv. {model:GetAttribute("Level") or 1}`
		billboard.Size = UDim2.fromOffset(64 + 13 * stars, 22)
	end
	update()
	model:GetAttributeChangedSignal("Level"):Connect(update)
	model:GetAttributeChangedSignal("Stars"):Connect(update)
	billboard.Parent = model
end

function PlotRenderer.start()
	local plotsRoot = workspace:WaitForChild("Hub"):WaitForChild("Plots")
	plotsFolder = plotsRoot
	plotsRoot.DescendantAdded:Connect(function(instance)
		if instance:IsA("Model") then
			task.defer(addLevelTag, instance)
			task.defer(watchBeamTower, instance)
		end
	end)
	for _, instance in plotsRoot:GetDescendants() do
		if instance:IsA("Model") then
			task.spawn(addLevelTag, instance)
			watchBeamTower(instance)
		end
	end
	-- Tours des zones de combat des niveaux (workspace.Arenas, créé par le serveur de la map principale) : mêmes
	-- étiquettes « Niv. X » et mêmes rayons.
	task.spawn(function()
		local arenasRoot = workspace:WaitForChild("Arenas", 60)
		if not arenasRoot then
			return
		end
		arenasRoot.DescendantAdded:Connect(function(instance)
			if instance:IsA("Model") then
				task.defer(addLevelTag, instance)
				task.defer(watchBeamTower, instance)
			end
		end)
		for _, instance in arenasRoot:GetDescendants() do
			if instance:IsA("Model") then
				task.spawn(addLevelTag, instance)
				watchBeamTower(instance)
			end
		end
	end)

	folder.Parent = workspace
	coinFolder.Parent = workspace

	Remotes.get("PlotSync").OnClientEvent:Connect(onSync)
	Remotes.get("PlotShots").OnClientEvent:Connect(onShots)
	Remotes.get("CoinDrop").OnClientEvent:Connect(onCoinDrop)

	RunService.RenderStepped:Connect(function(dt)
		table.clear(movedParts)
		table.clear(movedCFrames)
		for plotIndex, state in plots do
			-- Même vitesse que la simulation du serveur : x2 si le pass Vitesse x2 est activé sur cette parcelle.
			local simDt = dt * simSpeedOf(plotIndex, state)
			for _, enemy in state.enemies do
				enemy.distance = math.min(state.pathLength, enemy.distance + enemy.def.speed * IdleConfig.ENEMY_SPEED_MULTIPLIER * (enemy.speedFactor or 1) * simDt)
				local localPosition, direction = state.pointAt(enemy.distance)
				local position = state.cframe:PointToWorldSpace(localPosition) + Vector3.new(0, enemy.def.size / 2, 0)
				local worldDirection = state.cframe:VectorToWorldSpace(direction)
				-- Modèle perso que son animation retourne (CustomModels.measureFlip) : racine tournée d'un demi-tour
				-- tant que sa marche joue, pour qu'il regarde quand même devant lui.
				local flipped = enemy.walking == true and enemy.custom ~= nil and enemy.custom.flipWhenAnimated == true
				enemy.rootFlipped = flipped
				table.insert(movedParts, enemy.part)
				table.insert(movedCFrames, CFrame.lookAt(position, position + (if flipped then -worldDirection else worldDirection)))
			end
		end
		if #movedParts > 0 then
			workspace:BulkMoveTo(movedParts, movedCFrames, Enum.BulkMoveMode.FireCFrameChanged)
		end

		-- Sens des modèles perso pas encore mesuré : un échantillon par image sur un de leurs ennemis qui marche
		-- (plusieurs moments de son pas, CustomModels.measureFlip), racine encore dans le sens normal.
		for custom, enemy in flipSamplers do
			if custom.flipWhenAnimated ~= nil or not enemy.walking or enemy.rootFlipped or enemy.part.Parent == nil then
				flipSamplers[custom] = nil
			elseif os.clock() - (enemy.walkPlayedAt or 0) >= FLIP_MEASURE_DELAY then
				CustomModels.measureFlip(enemy.part, custom, enemy.track)
			end
		end

		-- Marche des modèles perso : quelques fois par seconde suffit (distance, vitesse).
		animClock += dt
		if animClock >= ANIM_CHECK_INTERVAL then
			animClock = 0
			updateAnimations()
		end

		local t = os.clock()
		-- Corps des animations de mort (modèles perso)
		if #dying > 0 then
			updateDying(t)
		end
		-- Rayons des Sorciers (jusqu'aux ennemis qu'on vient de déplacer) et zones de feu.
		updateBeams(dt, t)
		for plotIndex, state in plots do
			updateFires(plotIndex, state, t)
		end

		-- Pièces qui tournent et flottent.
		for id, coin in coins do
			local bob = math.sin(t * 3 + id) * 0.3
			coin.part.CFrame = CFrame.new(coin.base + Vector3.new(0, bob, 0)) * CFrame.Angles(0, t * 2 + id, 0)
		end

		-- Piles ramassées à distance : elles volent en arc vers le joueur (qui peut bouger), de plus en
		-- plus vite, en rétrécissant, puis disparaissent.
		if #flyingCoins > 0 then
			local root = characterRoot()
			for i = #flyingCoins, 1, -1 do
				local flying = flyingCoins[i]
				local alpha = (t - flying.started) / flying.duration
				if alpha >= 1 or not root then
					flying.part:Destroy()
					table.remove(flyingCoins, i)
					continue
				end
				local target = root.Position + Vector3.new(0, 1.5, 0)
				local arc = Vector3.new(0, math.sin(alpha * math.pi) * 5, 0)
				flying.part.Size = flying.size * (1 - 0.6 * alpha)
				flying.part.CFrame = CFrame.new(flying.from:Lerp(target, alpha * alpha) + arc) * CFrame.Angles(0, t * 12, 0)
			end
		end
	end)
end

return PlotRenderer

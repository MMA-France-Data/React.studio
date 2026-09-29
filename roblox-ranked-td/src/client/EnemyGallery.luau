-- Galerie des ennemis (Studio seulement) : tous les ennemis du mode solo, pour les voir avant les joueurs.
-- 10 rangées, une par style de MedievalModels (vagues 1-10, 11-20 ... 91-100 ; après la vague 100, les
-- styles recommencent), et 6 ennemis par rangée : Fantassin, Cavalier, Chevalier lourd, Écuyer, Chevalier
-- colossal et Seigneur de guerre. Chaque ennemi est construit avec MedievalModels.decorateEnemy et le même
-- palier que sur les parcelles (PlotRenderer : palier = math.floor((vague - 1) / 10)) : c'est exactement ce
-- que verront les joueurs. Les ennemis pivotent doucement (±25°) pour montrer leurs côtés.
-- Modèles perso (ReplicatedStorage.EnemyModels, voir CustomModels.luau) : un ennemi qui a le sien est montré
-- avec ce modèle (et sa marche, s'il en a une), comme sur les parcelles ; une plaque à ses pieds dit
-- « modèle perso : <nom du modèle> » ou « blocs ». La galerie est construite une fois : pour revoir un modèle
-- changé, relance la partie.
--
-- Où ? Autour du centre de la map, il n'y a pas de place libre assez grande (place centrale, routes des
-- fiefs, jardins, machines, parcelles et villages entre les parcelles) : la galerie est construite
-- derrière les montagnes du décor, en diagonale, à ~415 studs du centre, loin de tout (aucune parcelle,
-- aucun chemin, ni le cercle ranked, ni les panneaux des fiefs). Le bouton « GALERIE (Studio) » de la
-- colonne de gauche t'y emmène, « ← RETOUR » te ramène là où tu étais.
--
-- Seulement dans Studio (RunService:IsStudio()) avec Config.STUDIO_ENEMY_GALLERY = true : jamais dans le
-- jeu publié. Pas pendant les tests automatiques (ReplicatedStorage.__AutoPlayTest), sauf si le test la
-- demande avec ReplicatedStorage.__AutoTestGallery (créé avant ou pendant le test, même par le scénario
-- client) : elle est alors construite tout de suite, immobile, et ReplicatedStorage reçoit les attributs
--   « GalleryCenter »  (Vector3) : centre de la galerie,
--   « GalleryCamera »  (Vector3) : point de vue d'où on la voit en entier (regarder GalleryCenter),
--   « GalleryRow1 » à « GalleryRow10 » (Vector3) : centre de chaque rangée (pour les gros plans),
--   « GalleryLook »    (Vector3) : direction du regard du visiteur (une rangée entière, vue d'en haut
--                                  par-dessus la rangée de devant : caméra en GalleryRowN - GalleryLook * 24
--                                  + (0, 20, 0), qui regarde GalleryRowN),
--   « GalleryReady »   (true)    : tout est posé.
-- Tout est créé par ce client (rien sur le serveur) : les autres joueurs ne la voient pas.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local CustomModels = require(Shared.CustomModels)
local Enemies = require(Shared.Enemies)
local IdleConfig = require(Shared.IdleConfig)
local MedievalModels = require(Shared.MedievalModels)
local UI = require(script.Parent.UI)

local EnemyGallery = {}

-- Colonnes, de gauche à droite.
local TYPES = { "Normal", "Fast", "Tank", "Swarm", "Giant", "Boss" }
local WAVES_PER_STYLE = 10 -- un style par tranche de 10 vagues (même calcul que PlotRenderer)

-- Emplacement : direction depuis le centre de la map (même convention que PlotLayout.cframe : 0° = +Z,
-- 90° = +X) et distance du fond de la galerie au centre. Les montagnes du décor (MedievalModels.landscape,
-- à 328 studs du centre) finissent vers 395 studs ; dans cette diagonale, le sol (950 x 950) va jusqu'à
-- ~670 studs. Le joueur regarde vers le centre de la map : les montagnes font le fond.
local DIRECTION_DEGREES = 225
local BACK_RADIUS = 415

local COLUMN_GAP = 1.5 -- espace entre deux ennemis d'une rangée
local MIN_HALF_WIDTH = 1.9 -- demi-largeur minimale d'une colonne (place pour son nom)
local AISLE = 3 -- allée devant chaque rangée (on peut y marcher)
local STEP_RISE = 1.2 -- chaque rangée est un peu plus haute que la précédente (gradins)
local BASE_HEIGHT = 0.4 -- hauteur de la première marche
local SIGN_WIDTH = 9 -- panneau « Vagues 1-10 : ... » à gauche de chaque rangée
local FRONT_MARGIN = 3 -- devant la 1re rangée : noms des colonnes
local BACK_MARGIN = 2
local VIEW_DISTANCE = 12 -- où arrive le joueur : devant la galerie
local SWAY_ANGLE = math.rad(25) -- ±25° : on voit l'avant et les côtés
local SWAY_SPEED = 0.7 -- radians par seconde (un aller-retour toutes les ~9 s)
local SWAY_SAMPLES = 7 -- angles testés pour réserver la place d'un ennemi qui pivote
local ACTIVE_DISTANCE = 300 -- caméra plus loin que ça : les ennemis ne bougent pas (aucun calcul)
-- Modèles perso avec une animation de mort : toutes les DEATH_DEMO_EVERY s, ils la jouent une fois (dernière
-- pose gardée DEATH_DEMO_HOLD s), puis leur marche reprend. Pour la voir dans Studio.
local DEATH_DEMO_EVERY = 6
local DEATH_DEMO_HOLD = 1
local DEATH_DEMO_MAX = 3 -- durée maximale de l'animation montrée

local PLAQUE_WIDTH = 4 -- plaque « modèle perso » / « blocs » aux pieds de chaque ennemi (au plus)
local PLAQUE_HEIGHT = 0.55

local STONE = Color3.fromRGB(104, 100, 90)
local STONE_LIGHT = Color3.fromRGB(138, 131, 114)
local WOOD = Color3.fromRGB(70, 48, 32)
local GOLD = Color3.fromRGB(231, 190, 100)
local IVORY = Color3.fromRGB(240, 230, 205)

local built = false
local building = false
local frozen = false -- test automatique : les ennemis restent de face, immobiles
local viewpoint: CFrame? = nil -- où le bouton emmène le joueur
local center = Vector3.zero
local roots: { BasePart } = {}
local bases: { CFrame } = {}
local phases: { number } = {}
local cframes: { CFrame } = {}
local walkTracks: { AnimationTrack } = {} -- marches des modèles perso (gardées en boucle dans animate)

-- Repère de la galerie : posé devant la 1re rangée, au sol ; LookVector = vers le fond de la galerie (le
-- regard du visiteur), RightVector = sa droite. Un point à `depth` studs vers le fond : CFrame.new(x, y, -depth).
local function galleryFrame(totalDepth: number): CFrame
	local angle = math.rad(DIRECTION_DEGREES)
	local outward = Vector3.new(math.sin(angle), 0, math.cos(angle))
	local front = outward * (BACK_RADIUS + totalDepth)
	return CFrame.lookAt(front, front - outward)
end

local function block(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material, collide: boolean): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = collide
	part.CanTouch = false
	if not collide then
		part.CanQuery = false -- (possible seulement pour une pièce sans collision)
	end
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Texte sur la face d'un panneau tournée vers le visiteur (face Back : +Z du repère de la galerie).
local function signText(board: BasePart, lines: { { text: string, color: Color3, weight: number } })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = board
	local total = 0
	for _, line in lines do
		total += line.weight
	end
	local y = 0
	for _, line in lines do
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.new(0.04, 0, y / total, 0)
		label.Size = UDim2.new(0.92, 0, line.weight / total, 0)
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		label.TextWrapped = true
		label.TextColor3 = line.color
		label.Text = line.text
		label.Parent = gui
		y += line.weight
	end
end

-- Coins de toutes les pièces visibles d'un ennemi, dans le repère de sa racine.
local function cornersOf(root: BasePart): { Vector3 }
	local corners = {}
	local rootFrame = root.CFrame
	local parts = { root }
	for _, child in root:GetDescendants() do
		if child:IsA("BasePart") then
			table.insert(parts, child)
		end
	end
	for _, part in parts do
		if part.Transparency >= 1 then
			continue -- racine invisible (grands ennemis) : seul l'habillage compte
		end
		local relative = rootFrame:ToObjectSpace(part.CFrame)
		local half = part.Size / 2
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					table.insert(corners, relative * Vector3.new(sx * half.X, sy * half.Y, sz * half.Z))
				end
			end
		end
	end
	return corners
end

-- Place prise par un ennemi tourné vers le visiteur, pour tous les angles de son pivotement :
-- left / right (vers la gauche / la droite du visiteur), front / back (vers le visiteur / vers le fond),
-- top (hauteur au-dessus du centre de la racine).
local function extentsOf(corners: { Vector3 })
	local extents = { left = 0, right = 0, front = 0, back = 0, top = 0 }
	local samples = if frozen then 1 else SWAY_SAMPLES
	for i = 0, samples - 1 do
		local sway = if samples == 1 then 0 else -SWAY_ANGLE + 2 * SWAY_ANGLE * i / (samples - 1)
		local rotation = CFrame.Angles(0, math.pi + sway, 0)
		for _, corner in corners do
			local point = rotation * corner
			extents.left = math.max(extents.left, -point.X)
			extents.right = math.max(extents.right, point.X)
			extents.front = math.max(extents.front, point.Z)
			extents.back = math.max(extents.back, -point.Z)
			extents.top = math.max(extents.top, point.Y)
		end
	end
	return extents
end

-- Un ennemi exactement comme sur les parcelles (PlotRenderer.createEnemy), sans barre de vie. Construit
-- en `at` (sous le sol, invisible) : il sera déplacé à sa place une fois toute la galerie mesurée.
-- Renvoie sa racine, les coins de ses pièces (repère de la racine) et son modèle perso (nil = blocs).
local function createEnemy(enemyType: string, def, palier: number, parent: Instance, at: CFrame): (BasePart, { Vector3 }, any)
	-- Modèle perso du propriétaire (racine et modèle posés ensemble en `at`, avant d'entrer dans le Workspace).
	local custom, entry = CustomModels.spawn(enemyType, def, palier, at)
	if custom and entry then
		local corners = cornersOf(custom)
		custom.Parent = parent
		return custom, corners, entry
	end
	local part = Instance.new("Part")
	part.CFrame = at -- avant l'habillage : ses pièces sont soudées à cette position
	part.Size = Vector3.one * def.size
	part.Color = def.color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	MedievalModels.decorateEnemy(part, def, palier)
	part:SetAttribute("EnemyType", enemyType)
	part.Parent = parent
	return part, cornersOf(part), nil
end

-- Pivotement doux des ennemis (à chaque image), seulement quand la caméra est près de la galerie.
local function animate()
	if not built or frozen or #roots == 0 then
		return
	end
	-- Marche publiée sans boucle : Roblox peut remettre Looped à faux quand elle finit de se charger (comme
	-- sur les parcelles, PlotRenderer.updateAnimations) : remise en boucle, même loin (sinon elle serait
	-- déjà arrêtée quand le joueur arrive).
	for _, track in walkTracks do
		if not track.Looped then
			track.Looped = true
		end
	end
	local camera = workspace.CurrentCamera
	if not camera or (camera.CFrame.Position - center).Magnitude > ACTIVE_DISTANCE then
		return
	end
	local t = os.clock()
	for i, base in bases do
		cframes[i] = base * CFrame.Angles(0, SWAY_ANGLE * math.sin(t * SWAY_SPEED + phases[i]), 0)
	end
	workspace:BulkMoveTo(roots, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

local function build()
	if built or building then
		return
	end
	building = true
	local root = Instance.new("Folder")
	root.Name = "EnemyGallery (Studio)"
	root.Parent = workspace

	-- 1) Tous les ennemis, construits à l'écart, puis mesurés (la place qu'ils prennent en pivotant).
	local styleCount = MedievalModels.ENEMY_STYLE_COUNT or 10
	-- Sous le sol, à l'endroit de la galerie : rien n'apparaît au milieu de la map pendant la construction.
	local staging = CFrame.new(galleryFrame(30).Position - Vector3.new(0, 40, 0))
	local rows = {}
	local customCount = 0 -- ennemis montrés avec un modèle perso
	for palier = 0, styleCount - 1 do
		local row = { palier = palier, models = {}, name = nil }
		for column, enemyType in TYPES do
			local def = Enemies.Defs[enemyType]
			if not def then
				continue
			end
			local model, corners, custom = createEnemy(enemyType, def, palier, root, staging)
			row.models[column] = { def = def, root = model, extents = extentsOf(corners), custom = custom }
			row.name = row.name or model:GetAttribute("EnemyStyleName") -- (pas sur un modèle perso)
			if custom then
				customCount += 1
			end
		end
		table.insert(rows, row)
		task.wait() -- une rangée par image : pas de gros ralentissement
	end

	-- 2) Colonnes : chacune aussi large que le plus large de ses 10 ennemis.
	-- columnX = position des ennemis ; la colonne va de columnX - left à columnX + right.
	local columnX, columnCenter, columnWidth = {}, {}, {}
	local cursor = SIGN_WIDTH + 1
	for column in TYPES do
		local left, right = MIN_HALF_WIDTH, MIN_HALF_WIDTH
		for _, row in rows do
			local entry = row.models[column]
			if entry then
				left = math.max(left, entry.extents.left)
				right = math.max(right, entry.extents.right)
			end
		end
		columnX[column] = cursor + left
		columnCenter[column] = cursor + (left + right) / 2
		columnWidth[column] = left + right
		cursor = columnX[column] + right + COLUMN_GAP
	end
	local width = cursor - COLUMN_GAP
	local offsetX = -width / 2

	-- 3) Rangées : une allée devant chacune, puis la place de son ennemi le plus profond.
	local depth = FRONT_MARGIN
	local tallest = 0
	for index, row in rows do
		local front, back = 0, 0
		for _, entry in row.models do
			front = math.max(front, entry.extents.front)
			back = math.max(back, entry.extents.back)
			tallest = math.max(tallest, entry.extents.top + entry.def.size / 2)
		end
		row.stepStart = depth
		row.depth = depth + AISLE + front
		row.top = BASE_HEIGHT + (index - 1) * STEP_RISE
		depth = row.depth + back
		row.stepEnd = depth
	end
	local totalDepth = depth + BACK_MARGIN
	rows[#rows].stepEnd = totalDepth
	local frame = galleryFrame(totalDepth)

	-- 4) Dalle d'accueil, gradins, panneaux, puis chaque ennemi à sa place.
	-- Parvis : de la 1re marche (noms des colonnes compris) jusque derrière le point d'arrivée du joueur.
	local plazaDepth = FRONT_MARGIN + VIEW_DISTANCE + 6
	block(root, "Parvis", Vector3.new(width + 4, 0.3, plazaDepth), frame * CFrame.new(0, -0.1, plazaDepth / 2 - FRONT_MARGIN), STONE, Enum.Material.Slate, true)
	for index, row in rows do
		local height = row.top + 0.2 -- du sol (y = -0,2) au dessus de la marche
		local stepDepth = row.stepEnd - row.stepStart
		local color = if index % 2 == 0 then STONE_LIGHT else STONE
		block(root, "Gradin" .. index, Vector3.new(width + 2, height, stepDepth), frame * CFrame.new(0, row.top - height / 2, -(row.stepStart + stepDepth / 2)), color, Enum.Material.Slate, true)
		block(root, "Liseré", Vector3.new(width + 2, 0.12, 0.3), frame * CFrame.new(0, row.top + 0.01, -row.stepStart - 0.15), GOLD, Enum.Material.Metal, false)

		-- Panneau « Vagues 1-10 : Chevaliers carmin » à gauche de la rangée.
		local first = row.palier * WAVES_PER_STYLE + 1
		local styleName = row.name or `Style {row.palier + 1}`
		local signX = offsetX + 0.5 + SIGN_WIDTH / 2
		local board = block(root, "Panneau", Vector3.new(SIGN_WIDTH, 2.6, 0.3), frame * CFrame.new(signX, row.top + 1.9, -row.depth), WOOD, Enum.Material.Wood, false)
		signText(board, {
			{ text = `Vagues {first}-{first + WAVES_PER_STYLE - 1} : {styleName}`, color = GOLD, weight = 1 },
		})
		for _, side in { -1, 1 } do
			block(root, "Pied", Vector3.new(0.3, 0.7, 0.3), frame * CFrame.new(signX + side * (SIGN_WIDTH / 2 - 0.8), row.top + 0.3, -row.depth), WOOD, Enum.Material.Wood, false)
		end

		for column, entry in row.models do
			local base = frame * CFrame.new(offsetX + columnX[column], row.top + entry.def.size / 2, -row.depth) * CFrame.Angles(0, math.pi, 0)
			table.insert(roots, entry.root)
			table.insert(bases, base)
			table.insert(phases, column * 0.5 + index * 0.3)
			table.insert(cframes, base)

			-- Plaque à ses pieds, juste devant lui (dans l'allée) : modèle perso (et lequel) ou blocs.
			local plaqueWidth = math.min(PLAQUE_WIDTH, columnWidth[column] - 0.2)
			local plaqueZ = -(row.depth - entry.extents.front - 0.4)
			local plaque = block(root, "Plaque", Vector3.new(plaqueWidth, PLAQUE_HEIGHT, 0.12), frame * CFrame.new(offsetX + columnX[column], row.top + PLAQUE_HEIGHT / 2, plaqueZ), WOOD, Enum.Material.Wood, false)
			signText(plaque, {
				if entry.custom
					then { text = `modèle perso : {entry.custom.name}`, color = GOLD, weight = 1 }
					else { text = "blocs", color = IVORY, weight = 1 },
			})
		end
		row.center = frame:PointToWorldSpace(Vector3.new(0, row.top + 2, -row.depth))
	end

	-- Noms des colonnes, devant la 1re rangée.
	for column, enemyType in TYPES do
		local def = Enemies.Defs[enemyType]
		if def then
			local header = block(root, "Colonne", Vector3.new(columnWidth[column], 1.1, 0.2), frame * CFrame.new(offsetX + columnCenter[column], 0.75, -1), WOOD, Enum.Material.Wood, false)
			signText(header, { { text = def.displayName, color = IVORY, weight = 1 } })
		end
	end

	-- Grand panneau au fond, au-dessus de la dernière rangée.
	local last = rows[#rows]
	local titleY = last.top + tallest + 3
	local titleWidth = math.min(width, 40)
	local title = block(root, "Titre", Vector3.new(titleWidth, 5, 0.4), frame * CFrame.new(0, titleY, -(totalDepth - 0.6)), WOOD, Enum.Material.Wood, false)
	signText(title, {
		{ text = "GALERIE DES ENNEMIS (Studio seulement)", color = GOLD, weight = 1.3 },
		{ text = "Mode solo : un style par tranche de 10 vagues, puis les styles recommencent après la vague 100", color = IVORY, weight = 1 },
		{ text = `Modèles perso (ReplicatedStorage.EnemyModels) : {customCount} ennemi(s) sur {#rows * #TYPES}`, color = IVORY, weight = 0.8 },
	})
	for _, side in { -1, 1 } do
		block(root, "Poteau", Vector3.new(0.6, titleY - last.top, 0.6), frame * CFrame.new(side * (titleWidth / 2 - 1), (titleY + last.top) / 2, -(totalDepth - 0.6)), WOOD, Enum.Material.Wood, false)
	end

	-- Tous les ennemis à leur place, de face (l'habillage soudé suit la racine).
	workspace:BulkMoveTo(roots, bases, Enum.BulkMoveMode.FireCFrameChanged)

	-- Modèles perso qui savent marcher : leur marche en boucle, à leur vitesse normale (pas en test : immobiles).
	-- Ceux qui ont une animation de mort la montrent de temps en temps (DEATH_DEMO_EVERY).
	if not frozen then
		local deathDemos = {} -- { death = piste de mort, walk = piste de marche ou nil, walkRate }
		for _, row in rows do
			for _, entry in row.models do
				local track = entry.custom and CustomModels.loadWalk(entry.root, entry.custom)
				local walkRate = 1
				if track then
					local normalSpeed = entry.def.speed * IdleConfig.ENEMY_SPEED_MULTIPLIER * IdleConfig.enemySpeedFactor(entry.root:GetAttribute("EnemyType"))
					walkRate = CustomModels.walkRate(entry.custom, normalSpeed)
					track:Play(0.2, 1, walkRate)
					table.insert(walkTracks, track)
				end
				local death = entry.custom and CustomModels.loadDeath(entry.root, entry.custom)
				if death then
					table.insert(deathDemos, { death = death, walk = track, walkRate = walkRate })
				end
			end
		end
		if #deathDemos > 0 then
			task.spawn(function()
				while true do
					task.wait(DEATH_DEMO_EVERY)
					local longest = 0
					for _, demo in deathDemos do
						if demo.walk then
							demo.walk:Stop(0.2)
						end
						demo.death.Looped = false
						demo.death:Play(0.1)
						longest = math.max(longest, demo.death.Length)
					end
					task.wait(math.clamp(longest - 0.05, 0.5, DEATH_DEMO_MAX))
					for _, demo in deathDemos do
						demo.death:AdjustSpeed(0)
					end
					task.wait(DEATH_DEMO_HOLD)
					for _, demo in deathDemos do
						demo.death:Stop(0.3)
						if demo.walk then
							demo.walk:Play(0.3, 1, demo.walkRate)
						end
					end
				end
			end)
		end
	end

	center = frame:PointToWorldSpace(Vector3.new(0, last.top / 2 + 3, -totalDepth / 2))
	viewpoint = frame * CFrame.new(0, 3.5, VIEW_DISTANCE)
	ReplicatedStorage:SetAttribute("GalleryCenter", center)
	ReplicatedStorage:SetAttribute("GalleryCamera", frame:PointToWorldSpace(Vector3.new(0, totalDepth * 0.35 + 10, totalDepth * 0.25 + 10)))
	ReplicatedStorage:SetAttribute("GalleryLook", frame.LookVector)
	for index, row in rows do
		ReplicatedStorage:SetAttribute("GalleryRow" .. index, row.center)
	end
	ReplicatedStorage:SetAttribute("GalleryReady", true)
	built = true
	building = false
	if not frozen then
		RunService.RenderStepped:Connect(animate)
	end
	print(`[Galerie] {#roots} ennemis posés ({#rows} styles x {#TYPES} types, {customCount} avec un modèle perso), centre {center}`)
end

-- Bouton de la colonne de gauche (sous « Boutique ») : emmène à la galerie, puis ramène.
local function createButton()
	local player = Players.LocalPlayer
	local gui = UI.screen("EnemyGallery")
	local button = UI.button({
		Position = UDim2.new(0, 16, 0, UI.LEFT_COLUMN_TOP + 6 * UI.LEFT_COLUMN_STEP),
		Size = UDim2.fromOffset(180, 46),
		BackgroundColor3 = UI.Colors.PanelLight,
		Text = "GALERIE (Studio)",
		MaxTextSize = 18,
		Parent = gui,
	})
	local returnTo: CFrame? = nil
	local function refresh()
		button.Text = if returnTo then "← RETOUR" else "GALERIE (Studio)"
	end
	player.CharacterAdded:Connect(function()
		returnTo = nil -- réapparu au point de départ : le bouton remmène à la galerie
		refresh()
	end)
	button.Activated:Connect(function()
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if not character or not rootPart then
			return
		end
		if returnTo then
			character:PivotTo(returnTo)
			returnTo = nil
			refresh()
			return
		end
		if not built then
			if building then
				UI.toast("La galerie se construit, réessaie dans une seconde", "Info")
				return
			end
			build()
		end
		if viewpoint then
			returnTo = rootPart.CFrame
			character:PivotTo(viewpoint)
			refresh()
		end
	end)
end

function EnemyGallery.start()
	if not RunService:IsStudio() then
		return -- jamais dans le jeu publié
	end
	local function requested(): boolean
		return ReplicatedStorage:FindFirstChild("__AutoTestGallery") ~= nil
	end
	if requested() then
		frozen = true
		task.spawn(build)
		return
	end
	if ReplicatedStorage:FindFirstChild("__AutoPlayTest") then
		-- Test automatique : pas de galerie, sauf si le test la demande pendant la partie.
		local connection
		connection = ReplicatedStorage.ChildAdded:Connect(function(child)
			if child.Name == "__AutoTestGallery" then
				connection:Disconnect()
				frozen = true
				task.spawn(build)
			end
		end)
		return
	end
	if Config.STUDIO_ENEMY_GALLERY ~= true then
		return
	end
	createButton()
	task.delay(3, build) -- après le chargement de la map : prête quand tu cliques
end

return EnemyGallery

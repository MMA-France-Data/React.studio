-- La PARCELLE d'un joueur est son CAMP D'ENTRAÎNEMENT (demande du propriétaire, 02/10/2026 : « tu peux gérer toute
-- la parcelle et le système d'évolution de tour ») :
--   * trois SOCLES d'entraînement (PlotLayout.SPOTS). Sur chacun : la tour qu'il y a mise (Hub/CampGame.luau : elle
--     tire sur des cibles roulantes), une étiquette (nom, étoiles d'évolution, niveau d'entraînement, barre d'XP,
--     XP par minute) et une invite « Gérer » qui ouvre l'onglet Entraînement de sa fenêtre (LevelsUI lit l'attribut
--     CampSlot de l'invite) ;
--   * trois COUVEUSES (« LES ŒUFS », Levels.luau ; PlotLayout.HATCHERS) : l'œuf de chacune et le temps qui reste,
--     une invite qui ouvre l'onglet Œufs ; la 3e est la COUVEUSE ROYALE (Levels.ROYAL), dorée et couronnée, toujours
--     visible : à acheter en Robux tant qu'il n'a pas le pass (attribut RoyalHatcher du joueur, Hub/LevelsService) ;
--   * devant l'entrée, LES ŒUFS et la PORTE DES NIVEAUX (construites par Hub/HubMap.luau) : leur invite
--     ouvre l'onglet de ce nom (attribut CampTab) ;
--   * le tableau du fond affiche le camp (Hub/PlotBoard.luau lit les attributs Camp... de la parcelle).
-- Rien n'est sauvegardé ici : tout vient de data.levels (Hub/LevelsService.luau), relu à chaque changement
-- (Camp.refresh). Quand le joueur part, la parcelle redevient libre.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local IdleTowers = require(Shared.IdleTowers)
local Levels = require(Shared.Levels)
local MedievalModels = require(Shared.MedievalModels)
local Monetization = require(Shared.Monetization)
local NumberFormat = require(Shared.NumberFormat)
local PlotLayout = require(Shared.PlotLayout)
local ProximityLabel = require(Shared.ProximityLabel)
local CampGame = require(script.Parent.CampGame)
local HubMap = require(script.Parent.HubMap)
local IdleTowerModel = require(script.Parent.IdleTowerModel)

local Camp = {}

-- [Player] = son CampGame. Hub/init.luau les fait avancer et envoie leurs paquets (cibles, tirs) au joueur et à ceux
-- qui s'approchent de sa parcelle.
Camp.games = {}

local LABEL_DISTANCE = Config.LabelDistance.Medium + 20 -- lisible depuis le point d'arrivée du joueur
-- Étiquettes en studs (socles, couveuses) : cachées quand la caméra est à moins de ça d'elles (ProximityLabel), sinon
-- elles remplissaient la moitié de l'écran.
local LABEL_HIDE_NEAR = 10
local LABEL_HEIGHT = 11.5 -- studs au-dessus du socle (la plus haute tour, le Trébuchet, fait ~10 studs)
local LABEL_HEIGHT_EMPTY = 4
local OPEN_COLOR, LOCKED_COLOR = Color3.fromRGB(132, 124, 106), Color3.fromRGB(49, 47, 43)
local GOLD, IVORY, MUTED = Color3.fromRGB(255, 217, 61), Color3.new(1, 1, 1), Color3.fromRGB(220, 229, 244)
-- La couveuse royale : « mets-la en or » (demande du propriétaire, 04/10/2026).
local ROYAL_GOLD, ROYAL_RIM = Color3.fromRGB(214, 164, 52), Color3.fromRGB(255, 214, 102)
local INK = Color3.fromRGB(10, 12, 21)

-- Les vignettes des fenêtres montrent les VRAIES tours, sans images à publier. Un modèle statique par tour (16),
-- créés une fois, hors du Workspace : aucun tir, cible, évolution, invite ou effet de gameplay.
local function preparePreviews()
	if ReplicatedStorage:FindFirstChild("CampTowerPreviews") then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "CampTowerPreviews"
	for _, towerType in IdleTowers.ORDER do
		local model = IdleTowerModel.create(towerType, CFrame.new(), folder, {})
		local parts = 0
		for _, child in model:GetDescendants() do
			if child:IsA("BasePart") then
				parts += 1
				child.CanCollide = false
				child.CanTouch = false
				child.CanQuery = false
			end
		end
		model:SetAttribute("PreviewPartCount", parts)
	end
	folder.Parent = ReplicatedStorage
end

-- [Player] = { plot, slots = { [i] = { pad, gui, title, sub, bar, fill, xp, prompt } }, hatchers = { [i] = couveuse },
--              signature, clockDelta (heure du serveur de jeu - os.time : décalage des tests Studio) }
local dressings = {}

local function text(parent: Instance, name: string, position: UDim2, size: UDim2, color: Color3, font: Enum.Font): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 1
	label.Font = font
	label.TextColor3 = color
	label.TextScaled = true
	label.TextStrokeColor3 = INK
	label.TextStrokeTransparency = 0
	label.Text = ""
	label.Parent = parent
	return label
end

-- Étiquette et invite d'un socle d'entraînement.
local function dressPad(pad: BasePart, slotIndex: number)
	local gui = Instance.new("BillboardGui")
	gui.Name = "CampLabel"
	-- Taille en studs (pas en pixels) : de loin les étiquettes de deux socles voisins (9 studs) ne se recouvrent pas ;
	-- de très près, elle ne grossit plus (DistanceLowerLimit).
	gui.Size = UDim2.fromScale(8.4, 2.7)
	gui.DistanceLowerLimit = 18
	gui.AlwaysOnTop = true
	ProximityLabel.register(gui, LABEL_DISTANCE, LABEL_HIDE_NEAR)
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = Color3.fromRGB(35, 38, 53)
	panel.BackgroundTransparency = 0
	panel.BorderSizePixel = 0
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 5)
	corner.Parent = panel
	local edge = Instance.new("UIStroke")
	edge.Color = INK
	edge.Thickness = 3
	edge.Parent = panel
	local header = Instance.new("Frame")
	header.Name = "HeaderBand"
	header.Size = UDim2.fromScale(1, 0.4)
	header.BackgroundColor3 = Color3.fromRGB(0, 176, 255)
	header.BorderSizePixel = 0
	header.Parent = panel
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(134, 164, 213))
	gradient.Rotation = 90
	gradient.Parent = header
	local title = text(panel, "Title", UDim2.fromScale(0.03, 0.025), UDim2.fromScale(0.94, 0.36), IVORY, Enum.Font.FredokaOne)
	local sub = text(panel, "Sub", UDim2.fromScale(0.03, 0.43), UDim2.fromScale(0.94, 0.24), MUTED, Enum.Font.BuilderSansBold)
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Position = UDim2.fromScale(0.04, 0.7)
	bar.Size = UDim2.fromScale(0.92, 0.22)
	bar.BackgroundColor3 = INK
	bar.BorderSizePixel = 0
	bar.Parent = panel
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.fromRGB(91, 224, 26)
	fill.BorderSizePixel = 0
	fill.Parent = bar
	local xp = text(bar, "Xp", UDim2.new(), UDim2.fromScale(1, 1), IVORY, Enum.Font.FredokaOne)
	xp.ZIndex = 2
	gui.Parent = pad

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CampPrompt"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("CampSlot", slotIndex)
	prompt.Parent = pad
	return { pad = pad, gui = gui, panel = panel, title = title, sub = sub, bar = bar, fill = fill, xp = xp, prompt = prompt }
end

local function setLabelHeight(entry, height: number)
	-- StudsOffsetWorldSpace suit l'orientation du socle (un cylindre couché) : on lui donne la verticale du monde
	-- dans son repère.
	entry.gui.StudsOffsetWorldSpace = entry.pad.CFrame:VectorToObjectSpace(Vector3.new(0, height, 0))
end

----------------------------------------------------------------------
-- Couveuses (« LES ŒUFS », Levels.luau) : sur la parcelle, devant le point d'arrivée (PlotLayout.HATCHERS). Un
-- socle de pierre, un nid, l'œuf de la couveuse (sa couleur dit son type ; il brille quand il est prêt), une
-- étiquette (nom, œuf, temps qui reste) et une invite qui ouvre l'onglet Œufs de la fenêtre (attribut CampTab).
-- Seules les couveuses du joueur sont montrées, plus la suivante à acheter (à moitié transparente).
----------------------------------------------------------------------
local function clockText(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	local hours, minutes, rest = seconds // 3600, (seconds % 3600) // 60, seconds % 60
	return if hours > 0 then string.format("%d:%02d:%02d", hours, minutes, rest) else string.format("%d:%02d", minutes, rest)
end

-- Les MOTIFS des œufs en 3D (Levels.EGGS[type].art : les mêmes que les œufs dessinés de l'onglet, client/EggArt.luau) :
-- des pastilles posées sur la coquille, une bande autour, une couronne violette et des étincelles pour l'œuf doré ; et
-- pour les œufs spéciaux : un zigzag doré (carmin), une bande rivetée (cuivre), des ronces (ronces), des flocons
-- (givre). La coquille est une ellipse de demi-axes EGG_A (largeur) et EGG_B (hauteur).
local EGG_A, EGG_B = 1.15, 1.5

-- Point de la coquille (theta : le tour, de 0 à 2 pi ; phi : du haut, 0, au bas, pi) et sa normale (repère de l'œuf).
local function eggSurface(theta: number, phi: number): (Vector3, Vector3)
	local point = Vector3.new(EGG_A * math.sin(phi) * math.cos(theta), EGG_B * math.cos(phi), EGG_A * math.sin(phi) * math.sin(theta))
	local normal = Vector3.new(point.X / (EGG_A * EGG_A), point.Y / (EGG_B * EGG_B), point.Z / (EGG_A * EGG_A)).Unit
	return point, normal
end

-- Une pastille plate posée sur la coquille.
local function eggDisk(folder: Instance, center: CFrame, theta: number, phi: number, diameter: number, color: Color3)
	local point, normal = eggSurface(theta, phi)
	local at = center:PointToWorldSpace(point * 0.99)
	local disk = MedievalModels.sceneryPart(folder, "EggSpot", Vector3.new(0.08, diameter, diameter),
		CFrame.lookAt(at, center:PointToWorldSpace(point + normal)) * CFrame.Angles(0, math.pi / 2, 0), color, Enum.Material.SmoothPlastic)
	disk.Shape = Enum.PartType.Cylinder
	return disk
end

-- Une bande tout autour de la coquille, à la hauteur y (repère de l'œuf).
local function eggBand(folder: Instance, center: CFrame, y: number, thickness: number, color: Color3)
	local radius = EGG_A * math.sqrt(math.max(0, 1 - (y / EGG_B) ^ 2))
	local band = MedievalModels.sceneryPart(folder, "EggBand", Vector3.new(thickness, radius * 2 + 0.06, radius * 2 + 0.06),
		center * CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.pi / 2), color, Enum.Material.SmoothPlastic)
	band.Shape = Enum.PartType.Cylinder
	return band
end

-- Un trait posé sur la coquille, du point (thetaA, phiA) au point (thetaB, phiB) (les segments des zigzags et des
-- ronces : courts, ils suivent la coquille).
local function eggSegment(folder: Instance, center: CFrame, thetaA: number, phiA: number, thetaB: number, phiB: number, width: number, color: Color3)
	local a, normalA = eggSurface(thetaA, phiA)
	local b, normalB = eggSurface(thetaB, phiB)
	local normal = (normalA + normalB).Unit
	local middle = (a + b) / 2 + normal * 0.03
	return MedievalModels.sceneryPart(folder, "EggStripe", Vector3.new(width, 0.08, (b - a).Magnitude + width * 0.5),
		center * CFrame.lookAt(middle, b, normal), color, Enum.Material.SmoothPlastic)
end

-- Un petit objet posé sur la coquille au point (theta, phi), tourné de `spin` autour de la normale (flocons, épines).
local function eggPiece(folder: Instance, center: CFrame, name: string, theta: number, phi: number, size: Vector3, spin: number, color: Color3, material: Enum.Material)
	local point, normal = eggSurface(theta, phi)
	return MedievalModels.sceneryPart(folder, name, size, center * CFrame.lookAt(point + normal * 0.03, point + normal * 2) * CFrame.Angles(0, 0, spin), color, material)
end

local EGG_DECOR = {}
-- Des taches (œuf commun).
function EGG_DECOR.spots(folder: Instance, center: CFrame, art)
	for _, spot in { { 0.4, 0.9, 0.5 }, { 2, 1.2, 0.42 }, { 3.4, 0.7, 0.36 }, { 4.6, 1.5, 0.5 }, { 5.6, 1.1, 0.4 }, { 1.2, 2, 0.44 }, { 2.8, 2.2, 0.4 }, { 4.2, 2.4, 0.36 }, { 5.4, 2, 0.42 }, { 0.2, 2.5, 0.34 } } do
		eggDisk(folder, center, spot[1], spot[2], spot[3], art.detail)
	end
end
-- Une bande claire et des points (œuf rare).
function EGG_DECOR.cross(folder: Instance, center: CFrame, art)
	eggBand(folder, center, 0.15, 0.32, art.detail)
	for index = 0, 5 do
		eggDisk(folder, center, index * math.pi / 3 + 0.3, 0.75, 0.3, art.detail)
		eggDisk(folder, center, index * math.pi / 3, 2.15, 0.3, art.detail)
	end
end
-- Une couronne violette (une bande et ses pointes) et des étincelles (œuf doré, le plus rare).
function EGG_DECOR.crown(folder: Instance, center: CFrame, art)
	eggBand(folder, center, -0.62, 0.4, art.detail)
	for index = 0, 7 do
		local point = eggSurface(index * math.pi / 4, 1.88)
		local tip = MedievalModels.sceneryPart(folder, "CrownPoint", Vector3.new(0.34, 0.34, 0.34), center * CFrame.new(point * 0.98), art.detail, Enum.Material.SmoothPlastic)
		tip.Shape = Enum.PartType.Ball
	end
	for _, sparkle in { { 0.8, 0.8 }, { 2.9, 0.6 }, { 4.7, 1 } } do
		local glint = MedievalModels.sceneryPart(folder, "Sparkle", Vector3.new(0.18, 0.18, 0.18), center * CFrame.new((eggSurface(sparkle[1], sparkle[2]))), Color3.new(1, 1, 1), Enum.Material.Neon)
		glint.Shape = Enum.PartType.Ball
	end
end
-- Une bande dorée en zigzag tout autour, et des points dorés (œuf carmin).
function EGG_DECOR.zigzag(folder: Instance, center: CFrame, art)
	local points = 16
	for index = 0, points - 1 do
		local thetaA, thetaB = index / points * math.pi * 2, (index + 1) / points * math.pi * 2
		local phiA, phiB = if index % 2 == 0 then 1.3 else 1.62, if index % 2 == 0 then 1.62 else 1.3
		eggSegment(folder, center, thetaA, phiA, thetaB, phiB, 0.22, art.detail)
	end
	for _, spot in { { 0.5, 2.1 }, { 1.9, 2.3 }, { 3.3, 2.05 }, { 4.6, 2.35 }, { 5.7, 2.15 }, { 2.6, 0.75 } } do
		eggDisk(folder, center, spot[1], spot[2], 0.32, art.detail)
	end
end
-- Une bande sombre tout autour, ses rivets clairs, et deux points sombres (œuf de cuivre).
function EGG_DECOR.rivets(folder: Instance, center: CFrame, art)
	eggBand(folder, center, -0.25, 0.42, art.detail)
	local phi = math.acos(-0.25 / EGG_B)
	for index = 0, 7 do
		local point = eggSurface(index * math.pi / 4, phi)
		local rivet = MedievalModels.sceneryPart(folder, "Rivet", Vector3.new(0.22, 0.22, 0.22), center * CFrame.new(point * 1.05), art.accent or Color3.new(1, 1, 1), Enum.Material.Metal)
		rivet.Shape = Enum.PartType.Ball
	end
	eggDisk(folder, center, 1, 0.75, 0.34, art.detail)
	eggDisk(folder, center, 3.9, 2.4, 0.38, art.detail)
end
-- Deux ronces ondulées tout autour, leurs épines et des feuilles claires (œuf des ronces).
function EGG_DECOR.thorns(folder: Instance, center: CFrame, art)
	local points = 10
	for _, vine in { { 1, 0 }, { 2.1, 1.4 } } do
		for index = 0, points - 1 do
			local thetaA, thetaB = index / points * math.pi * 2, (index + 1) / points * math.pi * 2
			eggSegment(folder, center, thetaA, vine[1] + math.sin(thetaA * 3 + vine[2]) * 0.16, thetaB, vine[1] + math.sin(thetaB * 3 + vine[2]) * 0.16, 0.13, art.detail)
		end
		for index = 0, 2 do
			local theta = index * math.pi * 2 / 3 + 0.5 + vine[2]
			eggPiece(folder, center, "Thorn", theta, vine[1] + math.sin(theta * 3 + vine[2]) * 0.16 - 0.12, Vector3.new(0.2, 0.2, 0.12), math.pi / 4, art.detail, Enum.Material.SmoothPlastic)
		end
	end
	for _, leaf in { { 0.3, 1.25 }, { 2.4, 1.75 }, { 4.2, 1.3 }, { 5.4, 2.4 } } do
		eggPiece(folder, center, "Leaf", leaf[1], leaf[2], Vector3.new(0.42, 0.22, 0.06), 0.4, art.accent or Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
	end
end
-- Trois flocons blancs et des points blancs (œuf de givre).
function EGG_DECOR.flakes(folder: Instance, center: CFrame, art)
	for _, spot in { { 0.4, 1.1, 0.7 }, { 2.5, 1.9, 0.55 }, { 4.4, 1.3, 0.62 } } do
		for _, angle in { 0, math.pi / 3, -math.pi / 3 } do
			eggPiece(folder, center, "Flake", spot[1], spot[2], Vector3.new(spot[3], 0.08, 0.06), angle, art.detail, Enum.Material.SmoothPlastic)
		end
	end
	for _, spot in { { 1.5, 0.8 }, { 3.5, 2.3 }, { 5.6, 2 }, { 1.2, 2.4 } } do
		eggDisk(folder, center, spot[1], spot[2], 0.2, art.detail)
	end
end

-- Deux dunes ondulées tout autour, et deux soleils dorés et leurs rayons (œuf des dunes).
function EGG_DECOR.dunes(folder: Instance, center: CFrame, art)
	local points = 12
	for _, dune in { { 1.55, 0 }, { 2.05, 1.1 } } do
		for index = 0, points - 1 do
			local thetaA, thetaB = index / points * math.pi * 2, (index + 1) / points * math.pi * 2
			eggSegment(folder, center, thetaA, dune[1] + math.sin(thetaA * 2 + dune[2]) * 0.14, thetaB, dune[1] + math.sin(thetaB * 2 + dune[2]) * 0.14, 0.2, art.detail)
		end
	end
	local sun = art.accent or Color3.new(1, 1, 1)
	for _, spot in { { 0.6, 0.85 }, { 3.7, 0.85 } } do
		eggDisk(folder, center, spot[1], spot[2], 0.42, sun)
		for _, angle in { 0, math.pi / 3, -math.pi / 3 } do
			eggPiece(folder, center, "SunRay", spot[1], spot[2], Vector3.new(1.15, 0.07, 0.05), angle, sun, Enum.Material.SmoothPlastic)
		end
	end
end

-- Remet les motifs de l'œuf d'une couveuse (rien quand elle est vide) ; ne refait rien si l'œuf n'a pas changé.
local function decorateEgg(entry, eggType: string)
	if entry.decorType == eggType then
		return
	end
	entry.decorType = eggType
	entry.decor:ClearAllChildren()
	local egg = Levels.EGGS[eggType]
	if egg and egg.art then
		(EGG_DECOR[egg.art.pattern] or EGG_DECOR.spots)(entry.decor, entry.egg.CFrame, egg.art)
	end
end

local function setIfChanged(object: any, property: string, value: any)
	if object[property] ~= value then
		object[property] = value
	end
end

local function buildHatcher(plot, index: number)
	local origin = PlotLayout.worldCFrame(plot.index, PlotLayout.HATCHERS[index])
	local model = Instance.new("Model")
	model.Name = "Hatcher" .. index
	local pedestal = Instance.new("Part")
	pedestal.Name = "HatcherPedestal"
	pedestal.Shape = Enum.PartType.Cylinder
	pedestal.Size = Vector3.new(1.2, 4.4, 4.4)
	pedestal.CFrame = origin * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0, math.rad(90))
	pedestal.Anchored = true
	pedestal.Material = Enum.Material.Cobblestone
	pedestal.Color = OPEN_COLOR
	pedestal.TopSurface = Enum.SurfaceType.Smooth
	pedestal.BottomSurface = Enum.SurfaceType.Smooth
	pedestal.Parent = model
	local royal = index == Levels.ROYAL.index
	if royal then
		pedestal.Material = Enum.Material.Metal
		pedestal.Color = ROYAL_GOLD
	end
	local rim = MedievalModels.sceneryPart(model, "HatcherRim", Vector3.new(0.3, 4.8, 4.8), origin * CFrame.new(0, 1.25, 0) * CFrame.Angles(0, 0, math.rad(90)), if royal then ROYAL_RIM else GOLD, Enum.Material.Metal)
	rim.Shape = Enum.PartType.Cylinder
	if royal then
		-- (une couronne : 6 pointes dorées autour du bord)
		for point = 0, 5 do
			local angle = point / 6 * math.pi * 2
			local spike = MedievalModels.sceneryPart(model, "RoyalCrownPoint", Vector3.new(0.5, 1, 0.5),
				origin * CFrame.new(math.cos(angle) * 2.25, 1.85, math.sin(angle) * 2.25) * CFrame.Angles(0, -angle, 0), ROYAL_RIM, Enum.Material.Metal)
			spike.CanCollide = false
		end
	end
	local nest = MedievalModels.sceneryPart(model, "HatcherNest", Vector3.new(0.7, 3.2, 3.2), origin * CFrame.new(0, 1.6, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(120, 86, 52), Enum.Material.Wood)
	nest.Shape = Enum.PartType.Cylinder
	-- L'œuf : une sphère étirée (SpecialMesh : une pièce « Ball » reste ronde).
	local egg = MedievalModels.sceneryPart(model, "Egg", Vector3.new(2.3, 3, 2.3), origin * CFrame.new(0, 3.3, 0), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = egg
	-- (ses motifs : EGG_DECOR, dans un dossier à part : la boucle qui cache la couveuse ne les touche pas)
	local decor = Instance.new("Folder")
	decor.Name = "EggDecor"
	decor.Parent = model
	local light = Instance.new("PointLight")
	light.Range = 12
	light.Brightness = 2.5
	light.Enabled = false
	light.Parent = egg
	-- Étiquette au-dessus.
	local gui = Instance.new("BillboardGui")
	gui.Name = "HatcherLabel"
	gui.Size = UDim2.fromScale(6.2, 2.4)
	gui.DistanceLowerLimit = 18
	gui.AlwaysOnTop = true
	gui.StudsOffsetWorldSpace = Vector3.new(0, 5.4, 0)
	ProximityLabel.register(gui, LABEL_DISTANCE, LABEL_HIDE_NEAR)
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = Color3.fromRGB(35, 38, 53)
	panel.BorderSizePixel = 0
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 5)
	corner.Parent = panel
	local edge = Instance.new("UIStroke")
	edge.Color = INK
	edge.Thickness = 3
	edge.Parent = panel
	local title = text(panel, "Title", UDim2.fromScale(0.04, 0.03), UDim2.fromScale(0.92, 0.34), GOLD, Enum.Font.FredokaOne)
	local sub = text(panel, "Sub", UDim2.fromScale(0.04, 0.38), UDim2.fromScale(0.92, 0.28), MUTED, Enum.Font.BuilderSansBold)
	local timer = text(panel, "Timer", UDim2.fromScale(0.04, 0.66), UDim2.fromScale(0.92, 0.3), IVORY, Enum.Font.FredokaOne)
	timer:SetAttribute("NoTranslate", true) -- (que des chiffres)
	gui.Adornee = egg
	gui.Parent = model
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HatcherPrompt"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("CampTab", "Œufs")
	prompt.Parent = pedestal
	model.Parent = plot.folder
	return { model = model, pedestal = pedestal, egg = egg, decor = decor, decorType = "", light = light, panel = panel, title = title, sub = sub, timer = timer, prompt = prompt, eggType = "", readyAt = 0, royal = royal }
end

-- Temps qui reste sur l'étiquette d'une couveuse occupée (appelé chaque seconde) ; l'œuf brille quand il est prêt.
local function tickHatcher(entry, clockDelta: number)
	if entry.eggType == "" then
		return
	end
	local egg = Levels.EGGS[entry.eggType]
	local left = entry.readyAt - (os.time() + clockDelta)
	local ready = left <= 0
	setIfChanged(entry.sub, "Text", if ready then `{egg.displayName} : prêt !` else egg.displayName)
	setIfChanged(entry.timer, "Text", if ready then "" else clockText(left))
	setIfChanged(entry.light, "Enabled", ready)
	setIfChanged(entry.egg, "Material", if ready then Enum.Material.Neon else Enum.Material.SmoothPlastic)
end

-- Remet les couveuses d'accord avec les données du joueur. royalState = état de son pass « Couveuse royale »
-- ("owned", "buy", "soon", "no" : Hub/Shop.luau).
local function refreshHatchers(dressing, levels, royalState: string?)
	for index, entry in dressing.hatchers do
		local owned
		if entry.royal then
			owned = if royalState == "owned" or levels.royal.egg ~= "" then levels.royal else nil
		else
			owned = levels.hatchers[index]
		end
		local isNext = not entry.royal and owned == nil and index == #levels.hatchers + 1
		local forSale = entry.royal and owned == nil and (royalState == "buy" or royalState == "soon")
		local shown = owned ~= nil or isNext or forSale
		entry.pedestal.Transparency = if owned or forSale then 0 elseif isNext then 0.45 else 1
		entry.pedestal.Color = if entry.royal then ROYAL_GOLD elseif owned then OPEN_COLOR else LOCKED_COLOR
		entry.pedestal.CanCollide = shown
		entry.pedestal.CanQuery = shown
		for _, child in entry.model:GetChildren() do
			if child:IsA("BasePart") and child ~= entry.pedestal and child ~= entry.egg then
				child.Transparency = if shown then 0 else 1
			end
		end
		entry.panel.Visible = shown
		entry.prompt.Enabled = shown
		entry.prompt.ObjectText = if entry.royal then "Couveuse royale" else `Couveuse {index}`
		entry.prompt.ActionText = if owned then "Ouvrir" elseif royalState == "soon" and forSale then "Voir" else "Acheter"
		entry.eggType = if owned then owned.egg else ""
		entry.readyAt = if owned then owned.readyAt else 0
		local egg = Levels.EGGS[entry.eggType]
		entry.egg.Transparency = if egg then 0 else 1
		if egg then
			entry.egg.Color = egg.color
		end
		-- (lumière de l'œuf prêt : la couleur de sa vignette pour les plus rares, violette pour l'œuf doré)
		entry.light.Color = if egg and egg.art and egg.art.rays then egg.art.frame elseif egg then egg.color else Color3.new(1, 1, 1)
		decorateEgg(entry, if egg then entry.eggType else "")
		entry.light.Enabled = false
		entry.egg.Material = Enum.Material.SmoothPlastic
		entry.title.Text = if entry.royal then "👑 COUVEUSE ROYALE" elseif owned then `COUVEUSE {index}` else `🔒 COUVEUSE {index}`
		entry.timer.Text = ""
		if forSale then
			entry.sub.Text = if royalState == "buy" then `2 fois plus rapide • {Monetization.PASSES.Royal.price} R$` else "2 fois plus rapide • bientôt"
		elseif isNext then
			entry.sub.Text = `Acheter : {NumberFormat.short(Levels.HATCHER_COST[index] or 0)} pièces de niveau`
		elseif owned and not egg then
			entry.sub.Text = "Vide : pose un œuf"
		end
		tickHatcher(entry, dressing.clockDelta)
	end
end

local function decimal(value: number): string
	local rounded = math.floor(value * 10 + 0.5) / 10
	return (string.gsub(tostring(rounded), "%.", ","))
end

-- Remet tout d'accord avec les données du joueur (emplacements, XP, pièces, couveuses) : tours posées, étiquettes,
-- invites, tableau. Appelé à chaque publication de son état (Hub/LevelsService.luau, avec l'heure du serveur de
-- jeu) ; ne fait rien si rien n'a changé.
function Camp.refresh(player: Player, levels, serverNow: number?)
	local game = Camp.games[player]
	local dressing = dressings[player]
	if not game or not dressing or not levels then
		return
	end
	dressing.clockDelta = (serverNow or os.time()) - os.time()
	local royalState = player:GetAttribute("RoyalHatcher")
	local xpBoost = tonumber(player:GetAttribute("XpBoost")) or 1 -- (pass XP x2 : l'XP par minute des socles)
	local parts = { tostring(levels.best), tostring(levels.coins), tostring(#levels.slots),
		`royal:{levels.royal.egg}:{levels.royal.readyAt}:{tostring(royalState)}:{xpBoost}` }
	for index, hatcher in levels.hatchers do
		table.insert(parts, `h{index}:{hatcher.egg}:{hatcher.readyAt}`)
	end
	for index, slot in levels.slots do
		table.insert(parts, `{index}:{slot.tower}:{slot.level}:{math.floor((levels.xp[slot.tower] or 0) * 10 + 0.5)}`)
	end
	local owned = 0
	for _ in levels.towers do
		owned += 1
	end
	table.insert(parts, tostring(owned))
	local signature = table.concat(parts, "|")
	if signature == dressing.signature then
		return
	end
	dressing.signature = signature

	refreshHatchers(dressing, levels, if typeof(royalState) == "string" then royalState else nil)
	game:refresh(levels)
	local training = Levels.trainingLevels(levels)
	local summary = {}
	for slotIndex, entry in dressing.slots do
		local slot = levels.slots[slotIndex]
		local pad = entry.pad
		local isNext = slotIndex == #levels.slots + 1
		local shown = slot ~= nil or isNext
		pad.Transparency = if slot then 0 elseif isNext then 0.35 else 1
		pad.Color = if slot then OPEN_COLOR else LOCKED_COLOR
		pad.CanCollide = shown
		pad.CanQuery = shown
		-- (gui.Enabled appartient à ProximityLabel, qui allume l'étiquette de près : on cache son contenu)
		entry.panel.Visible = shown
		entry.prompt.Enabled = shown
		entry.bar.Visible = false
		if slot then
			local def = IdleTowers.Defs[slot.tower]
			local rate = Levels.TRAINING.SLOT_RATE[slot.level] or 0
			entry.prompt.ObjectText = `Emplacement d'entraînement {slotIndex}`
			entry.prompt.ActionText = if def then "Gérer" else "Choisir une tour"
			if def then
				local xp = levels.xp[slot.tower] or 0
				local trained = training[slot.tower] or 0
				local stars = Levels.stars(Levels.evolutionStage(slot.tower, trained))
				local done, needed = Levels.trainingProgress(xp)
				entry.title.Text = if stars ~= "" then `{def.displayName} {stars}` else def.displayName
				entry.title.TextColor3 = IVORY
				entry.sub.Text = `Entraînement {trained}/{Levels.TRAINING.MAX_LEVEL} • +{decimal(rate * xpBoost)} XP/min`
				entry.bar.Visible = true
				entry.fill.Size = UDim2.fromScale(if needed > 0 then math.clamp(done / needed, 0, 1) else 1, 1)
				entry.xp.Text = if needed > 0 then `{math.floor(done)} / {needed} XP` else "ENTRAÎNEMENT MAX"
				setLabelHeight(entry, LABEL_HEIGHT)
				table.insert(summary, if stars ~= "" then `{def.displayName} {stars}` else def.displayName)
			else
				entry.title.Text = `EMPLACEMENT {slotIndex}`
				entry.title.TextColor3 = IVORY
				entry.sub.Text = "Libre : choisis une tour à entraîner"
				setLabelHeight(entry, LABEL_HEIGHT_EMPTY)
			end
		elseif isNext then
			local price = Levels.TRAINING.SLOT_UNLOCK_COST[slotIndex] or 0
			entry.title.Text = `🔒 EMPLACEMENT {slotIndex}`
			entry.title.TextColor3 = GOLD
			entry.sub.Text = `Ouvrir : {NumberFormat.short(price)} pièces de niveau`
			entry.prompt.ObjectText = `Emplacement d'entraînement {slotIndex}`
			entry.prompt.ActionText = "Ouvrir"
			setLabelHeight(entry, LABEL_HEIGHT_EMPTY)
		end
	end
	-- Tableau du fond de la parcelle (Hub/PlotBoard.luau).
	game:setAttr("CampBest", levels.best)
	game:setAttr("CampCoins", levels.coins)
	game:setAttr("CampTowers", owned)
	game:setAttr("CampTraining", table.concat(summary, "  ·  "))
end

-- La parcelle `plot` (Hub/HubMap.luau) de ce joueur devient son camp. levels = data.levels.
function Camp.start(player: Player, plot, levels)
	if Camp.games[player] then
		return
	end
	preparePreviews()
	local dressing = { plot = plot, slots = {}, hatchers = {}, signature = nil, clockDelta = 0 }
	for index = 1, #PlotLayout.HATCHERS do
		dressing.hatchers[index] = buildHatcher(plot, index)
	end
	-- Socles d'entraînement : chacun reçoit son étiquette et son invite.
	local campSpot = {}
	for slotIndex, spotIndex in Levels.CAMP.SPOTS do
		campSpot[spotIndex] = slotIndex
	end
	for _, pad in plot.spots:GetChildren() do
		local slotIndex = if pad:IsA("BasePart") then campSpot[pad:GetAttribute("SpotIndex")] else nil
		if slotIndex and slotIndex <= #Levels.TRAINING.SLOT_UNLOCK_COST then
			dressing.slots[slotIndex] = dressPad(pad, slotIndex)
		end
	end
	dressings[player] = dressing
	Camp.games[player] = CampGame.new(plot, player, levels)
	Camp.refresh(player, levels)
end

-- Fin du camp (le joueur part) : la parcelle redevient libre, ses socles vides.
function Camp.stop(player: Player)
	local game = Camp.games[player]
	local dressing = dressings[player]
	Camp.games[player] = nil
	dressings[player] = nil
	if game then
		game:destroy()
	end
	if not dressing then
		return
	end
	for _, entry in dressing.slots do
		entry.gui:Destroy()
		entry.prompt:Destroy()
	end
	for _, entry in dressing.hatchers do
		entry.model:Destroy()
	end
	HubMap.resetPads(dressing.plot)
end

-- Le temps qui reste sur les couveuses de toutes les parcelles, chaque seconde.
task.spawn(function()
	while true do
		task.wait(1)
		for _, dressing in dressings do
			for _, entry in dressing.hatchers do
				tickHatcher(entry, dressing.clockDelta)
			end
		end
	end
end)

return Camp

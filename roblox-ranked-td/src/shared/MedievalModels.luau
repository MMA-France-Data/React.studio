-- Habillage médiéval : les monstres en blocs, la cible d'entraînement du camp, et le décor (map et niveaux).
-- La racine d'un monstre reste une Part légère déplacée par l'affichage ; les éléments visuels
-- sont soudés dessus afin de conserver BulkMoveTo.
local MedievalModels = {}

local IRON = Color3.fromRGB(92, 98, 108)
local DARK_IRON = Color3.fromRGB(48, 51, 58)
local LEATHER = Color3.fromRGB(91, 57, 35)
local WOOD = Color3.fromRGB(101, 65, 38)
local SKIN = Color3.fromRGB(213, 166, 119)
local HORSE = Color3.fromRGB(93, 59, 38)
local GOLD = Color3.fromRGB(218, 168, 62)

local function piece(root: BasePart, name: string, size: Vector3, relative: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = root.CFrame * relative
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Shape = shape or Enum.PartType.Block
	part.Anchored = false
	part.Massless = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = root
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
	return part
end

-- Styles des monstres : un par territoire de 10 niveaux (palier 0 = niveaux 1-10, palier 9 = 91-100, puis ça
-- recommence). Le palier est donné par celui qui affiche le monstre (PlotRenderer, EnemyGallery).
local ENEMY_STYLES = {
	{ name = "Chevaliers carmin", cloth = Color3.fromRGB(155, 42, 46), armor = IRON, skin = SKIN, mount = HORSE, boss = "king" },
	{ name = "Pillards de cuivre", cloth = Color3.fromRGB(168, 96, 38), armor = Color3.fromRGB(123, 80, 49), skin = SKIN, mount = Color3.fromRGB(62, 44, 35), boss = "raider" },
	{ name = "Gardiens des ronces", cloth = Color3.fromRGB(52, 104, 57), armor = Color3.fromRGB(92, 113, 67), skin = Color3.fromRGB(143, 169, 97), mount = Color3.fromRGB(128, 108, 68), boss = "forest" },
	{ name = "Legion du givre", cloth = Color3.fromRGB(72, 162, 190), armor = Color3.fromRGB(164, 203, 214), skin = Color3.fromRGB(188, 222, 231), mount = Color3.fromRGB(168, 188, 200), boss = "ice" },
	{ name = "Gardes des dunes", cloth = Color3.fromRGB(213, 168, 78), armor = Color3.fromRGB(166, 128, 57), skin = Color3.fromRGB(174, 119, 78), mount = Color3.fromRGB(171, 131, 84), boss = "desert" },
	{ name = "Legion des os", cloth = Color3.fromRGB(106, 83, 134), armor = Color3.fromRGB(110, 109, 118), skin = Color3.fromRGB(224, 214, 177), mount = Color3.fromRGB(183, 180, 158), boss = "undead" },
	{ name = "Garde de la tempete", cloth = Color3.fromRGB(75, 91, 179), armor = Color3.fromRGB(107, 126, 172), skin = SKIN, mount = Color3.fromRGB(75, 78, 104), boss = "storm" },
	{ name = "Chevaliers d'obsidienne", cloth = Color3.fromRGB(209, 75, 40), armor = Color3.fromRGB(48, 44, 53), skin = Color3.fromRGB(137, 119, 112), mount = Color3.fromRGB(47, 43, 48), boss = "obsidian" },
	-- (Décision du propriétaire, 30/09/2026 : le dragon est le dernier boss, la horde gobeline passe avant.)
	{ name = "Horde gobeline", cloth = Color3.fromRGB(130, 71, 41), armor = Color3.fromRGB(94, 101, 66), skin = Color3.fromRGB(111, 156, 62), mount = Color3.fromRGB(72, 83, 48), boss = "goblin" },
	{ name = "Couvee du dragon", cloth = Color3.fromRGB(153, 46, 42), armor = Color3.fromRGB(117, 51, 43), skin = Color3.fromRGB(174, 116, 63), mount = Color3.fromRGB(103, 59, 43), boss = "dragon" },
}

MedievalModels.ENEMY_STYLE_COUNT = #ENEMY_STYLES

local function styleIndex(palier: number): number
	if palier ~= palier or math.abs(palier) == math.huge then return 1 end
	return math.max(0, math.floor(palier)) % #ENEMY_STYLES + 1
end

-- Nom de la famille de monstres d'un palier (« Chevaliers carmin »...).
function MedievalModels.enemyStyleName(palier: number): string
	return ENEMY_STYLES[styleIndex(palier)].name
end

local function tierEnemy(root: BasePart, def, index: number)
	local style = ENEMY_STYLES[index]
	local s = def.size / 2
	local heavy = def.visual == "Heavy"
	local boss = def.visual == "Warlord"
	-- Giant et Tank partagent Heavy : la taille distingue uniquement leur habillage.
	local giant = heavy and def.size >= 4
	local bone = Color3.fromRGB(229, 216, 174)
	local dark = Color3.fromRGB(31, 34, 38)
	local function p(name, size, position, color, material, rotation, shape)
		return piece(root, name, size * s, CFrame.new(position * s) * (rotation or CFrame.identity), color, material, shape)
	end
	local function beam(name, a, b, width, color, material)
		return piece(root, name, Vector3.new(width, width, (b - a).Magnitude) * s,
			CFrame.lookAt((a + b) * s / 2, b * s), color, material)
	end
	local function spike(name, size, position, color, rotation)
		local part = p(name, size, position, color, Enum.Material.SmoothPlastic, rotation)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Wedge
		mesh.Parent = part
		return part
	end
	local function eyes(y, z, spacing, color)
		for _, side in { -1, 1 } do
			p("Eye", Vector3.new(0.12, 0.11, 0.07), Vector3.new(side * spacing, y, z), color, Enum.Material.SmoothPlastic)
		end
	end

	if boss and style.boss == "dragon" then
		-- Dragon terrestre : ailes repliées, pas de vol ni de modification du chemin.
		p("DragonBody", Vector3.new(1.65, 1.35, 2.3), Vector3.new(0, 0, 0.15), style.armor, Enum.Material.Slate, nil, Enum.PartType.Ball)
		p("BreastScales", Vector3.new(0.95, 0.85, 0.85), Vector3.new(0, -0.1, -0.77), style.skin, Enum.Material.SmoothPlastic, nil, Enum.PartType.Ball)
		beam("DragonNeck", Vector3.new(0, 0.35, -0.7), Vector3.new(0, 1.05, -1.3), 0.7, style.armor, Enum.Material.Slate)
		p("DragonSkull", Vector3.new(0.98, 0.65, 1.12), Vector3.new(0, 1.1, -1.53), style.armor, Enum.Material.Slate)
		p("DragonMuzzle", Vector3.new(0.72, 0.34, 0.7), Vector3.new(0, 0.97, -2.18), style.skin, Enum.Material.SmoothPlastic)
		p("Jaw", Vector3.new(0.68, 0.14, 0.85), Vector3.new(0, 0.73, -2.08), style.armor, Enum.Material.Slate)
		eyes(1.22, -2.11, 0.34, GOLD)
		for _, side in { -1, 1 } do
			spike("DragonHorn", Vector3.new(0.24, 0.7, 0.28), Vector3.new(side * 0.4, 1.62, -1.2), bone, CFrame.Angles(0.3, 0, side * -0.3))
			spike("Fang", Vector3.new(0.1, 0.23, 0.13), Vector3.new(side * 0.26, 0.77, -2.37), bone, CFrame.Angles(0, 0, math.pi))
			for _, z in { -0.65, 0.85 } do
				beam("DragonLeg", Vector3.new(side * 0.65, -0.25, z), Vector3.new(side * 0.92, -0.78, z - 0.16), 0.34, style.armor, Enum.Material.Slate)
				p("ClawedFoot", Vector3.new(0.45, 0.22, 0.63), Vector3.new(side * 0.92, -0.86, z - 0.3), bone, Enum.Material.SmoothPlastic)
			end
			beam("WingBone", Vector3.new(side * 0.6, 0.5, 0.1), Vector3.new(side * 1.75, 1.5, 0.25), 0.16, style.skin, Enum.Material.SmoothPlastic)
			spike("WingMembrane", Vector3.new(0.12, 1.65, 1.95), Vector3.new(side * 1.18, 0.74, 0.68), style.cloth, CFrame.Angles(0.18, 0, side * -0.5))
		end
		beam("TailBase", Vector3.new(0, 0.1, 1), Vector3.new(0.25, 0.05, 2.02), 0.46, style.armor, Enum.Material.Slate)
		beam("TailTip", Vector3.new(0.25, 0.05, 2.02), Vector3.new(0.72, 0.3, 2.75), 0.22, style.armor, Enum.Material.Slate)
		for i = 1, 3 do
			spike("DorsalSpine", Vector3.new(0.18, 0.42, 0.38), Vector3.new(0, 0.83, -0.35 + i * 0.5), GOLD)
		end
		return
	end

	if boss or giant then
		local goblin = style.boss == "goblin" or style.boss == "forest"
		local bodyColor = if goblin then style.skin else style.armor
		p("ColossusTorso", Vector3.new(1.5, 1.45, 0.92), Vector3.new(0, 0.22, 0), bodyColor, if goblin then Enum.Material.SmoothPlastic else Enum.Material.Metal)
		p("Belt", Vector3.new(1.58, 0.2, 1), Vector3.new(0, -0.25, 0), LEATHER, Enum.Material.Fabric)
		p("Buckle", Vector3.new(0.3, 0.27, 0.12), Vector3.new(0, -0.24, -0.56), GOLD, Enum.Material.Metal)
		p("Head", Vector3.new(0.92, 0.86, 0.8), Vector3.new(0, 1.26, -0.06), style.skin, Enum.Material.SmoothPlastic)
		eyes(1.4, -0.49, 0.22, dark)
		for _, side in { -1, 1 } do
			p("Boot", Vector3.new(0.52, 0.72, 0.62), Vector3.new(side * 0.4, -0.65, -0.02), LEATHER, Enum.Material.Fabric)
			p("Arm", Vector3.new(0.48, 1.12, 0.52), Vector3.new(side * 0.98, 0.15, 0), bodyColor, Enum.Material.SmoothPlastic, CFrame.Angles(0, 0, side * 0.13))
			p("Pauldron", Vector3.new(0.68, 0.38, 0.78), Vector3.new(side * 0.92, 0.72, 0), style.armor, Enum.Material.Metal)
		end
		p("ClubHandle", Vector3.new(0.18, 1.75, 0.18), Vector3.new(1.18, 0.4, -0.35), WOOD, Enum.Material.Wood)
		p("MaceHead", Vector3.new(0.62, 0.68, 0.62), Vector3.new(1.18, 1.26, -0.35), style.armor, Enum.Material.Metal)
		if not boss then return end -- colosse : 15 pièces, racine comprise
		p("RoyalCape", Vector3.new(1.35, 1.9, 0.14), Vector3.new(0, 0.1, 0.55), style.cloth, Enum.Material.Fabric, CFrame.Angles(-0.13, 0, 0))
		p("CrownBand", Vector3.new(1.03, 0.16, 0.88), Vector3.new(0, 1.73, -0.04), GOLD, Enum.Material.Metal)
		for _, x in { -0.36, 0, 0.36 } do
			spike("CrownPoint", Vector3.new(0.17, if x == 0 then 0.55 else 0.38, 0.18), Vector3.new(x, 1.98, -0.28), GOLD)
		end
		if goblin then
			p("GoblinMuzzle", Vector3.new(0.65, 0.3, 0.35), Vector3.new(0, 1.07, -0.55), style.skin, Enum.Material.SmoothPlastic)
			for _, side in { -1, 1 } do
				spike("PointedEar", Vector3.new(0.64, 0.36, 0.18), Vector3.new(side * 0.64, 1.4, -0.02), style.skin, CFrame.Angles(0, 0, side * -0.3))
				spike("GoblinTusk", Vector3.new(0.14, 0.34, 0.13), Vector3.new(side * 0.26, 1.17, -0.76), bone)
			end
		elseif style.boss == "ice" or style.boss == "obsidian" or style.boss == "storm" then
			for _, side in { -1, 1 } do
				spike("ShoulderCrystal", Vector3.new(0.4, 1, 0.42), Vector3.new(side * 1.05, 1.15, 0), style.cloth, CFrame.Angles(0, 0, side * -0.4))
			end
			p("CoreGem", Vector3.new(0.44, 0.44, 0.18), Vector3.new(0, 0.48, -0.52), style.cloth, Enum.Material.Neon, CFrame.Angles(0, 0, math.pi / 4))
		elseif style.boss == "undead" then
			p("SkullJaw", Vector3.new(0.62, 0.23, 0.2), Vector3.new(0, 0.92, -0.49), bone, Enum.Material.SmoothPlastic)
			for _, side in { -1, 1 } do
				p("EyeSocket", Vector3.new(0.22, 0.22, 0.09), Vector3.new(side * 0.23, 1.4, -0.52), dark, Enum.Material.SmoothPlastic)
			end
		else
			p("TowerShield", Vector3.new(0.2, 1.6, 1.1), Vector3.new(-1.18, 0.18, -0.24), style.cloth, Enum.Material.Metal)
			p("ShieldCrest", Vector3.new(0.08, 0.58, 0.58), Vector3.new(-1.3, 0.22, -0.24), GOLD, Enum.Material.Metal, CFrame.Angles(math.pi / 4, 0, 0))
		end
		return
	end

	-- La racine sert aussi de torse/corps : 6 pièces TOTALES pour les troupes,
	-- 10 pour les lourds. Pas d'émetteur, lumière, texture distante ou boucle par ennemi.
	root.Transparency = 0
	root.Color = if heavy then style.armor else style.cloth
	root.Material = if heavy then Enum.Material.Metal else Enum.Material.Fabric
	root.Size = Vector3.new(1.05, 1.15, 0.72) * s
	if def.visual == "Cavalry" then
		root.Size = Vector3.new(0.95, 0.8, 2.1) * s
		root.Color = style.mount
		root.Material = Enum.Material.SmoothPlastic
		p("HorseNeckHead", Vector3.new(0.54, 1.05, 0.85), Vector3.new(0, 0.55, -1), style.mount, Enum.Material.SmoothPlastic, CFrame.Angles(-0.35, 0, 0))
		for _, z in { -0.65, 0.7 } do
			p("PairedHorseLegs", Vector3.new(0.73, 0.65, 0.22), Vector3.new(0, -0.66, z), style.mount:Lerp(dark, 0.3), Enum.Material.SmoothPlastic)
		end
		p("Rider", Vector3.new(0.64, 0.78, 0.52), Vector3.new(0, 0.77, 0.12), style.cloth, Enum.Material.Fabric)
		p("RiderHelm", Vector3.new(0.53, 0.55, 0.55), Vector3.new(0, 1.43, 0.07), if index == 10 then style.skin else style.armor, Enum.Material.SmoothPlastic)
		return
	end
	p("Helm", Vector3.new(0.7, if index % 3 == 0 then 0.88 else 0.68, 0.7), Vector3.new(0, 0.91, 0), if index == 6 or index == 10 then style.skin else style.armor, Enum.Material.SmoothPlastic, nil, if index % 3 == 1 then Enum.PartType.Ball else Enum.PartType.Block)
	for _, side in { -1, 1 } do
		p("Boot", Vector3.new(0.34, 0.6, 0.42), Vector3.new(side * 0.3, -0.76, 0), LEATHER, Enum.Material.Fabric)
	end
	p("Shield", Vector3.new(0.16, if index % 2 == 0 then 1.2 else 0.9, 0.85), Vector3.new(-0.67, 0.1, -0.18), style.cloth, Enum.Material.Metal, nil, if index % 2 == 0 then Enum.PartType.Block else Enum.PartType.Cylinder)
	p("Weapon", Vector3.new(0.12, if index % 3 == 0 then 2.2 else 1.45, 0.19), Vector3.new(0.68, 0.38, -0.23), style.armor:Lerp(bone, 0.4), Enum.Material.Metal, CFrame.Angles(-0.2, 0, 0))
	if heavy then
		for _, side in { -1, 1 } do
			p("Pauldron", Vector3.new(0.46, 0.42, 0.82), Vector3.new(side * 0.65, 0.38, 0), style.armor, Enum.Material.Metal)
		end
		p("Visor", Vector3.new(0.73, 0.12, 0.1), Vector3.new(0, 0.91, -0.36), dark, Enum.Material.Metal)
		p("Cape", Vector3.new(0.92, 1.28, 0.12), Vector3.new(0, 0, 0.42), style.cloth, Enum.Material.Fabric)
	end
end

-- Habille la racine d'un monstre dans le style de son territoire (palier, voir ENEMY_STYLES).
function MedievalModels.decorateEnemy(root: BasePart, def, palier: number?)
	root.Transparency = 1
	root.Color = def.color
	root.Material = Enum.Material.SmoothPlastic
	root.CastShadow = false
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	local index = styleIndex(palier or 0)
	root:SetAttribute("EnemyStyle", index - 1)
	root:SetAttribute("EnemyStyleName", ENEMY_STYLES[index].name)
	tierEnemy(root, def, index)
end

-- CIBLE D'ENTRAÎNEMENT du camp (Hub/CampGame.luau) : un mannequin de paille sur un chariot, que
-- les tours à l'entraînement prennent pour cible. Habille la même racine qu'un ennemi (elle suit le chemin de la
-- parcelle) ; on le reconnaît de tous les côtés : rien à voir avec un vrai monstre.
function MedievalModels.trainingTarget(root: BasePart, def)
	root.Transparency = 1
	root.CastShadow = false
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	local s = def.size / 2
	local straw = Color3.fromRGB(214, 184, 106)
	local red, white = Color3.fromRGB(190, 52, 46), Color3.fromRGB(236, 232, 220)
	local sideways = CFrame.Angles(0, math.rad(90), 0) -- cylindre couché dans l'axe de la marche
	-- Chariot et ses 4 roues.
	piece(root, "Cart", Vector3.new(1.5, 0.2, 1.9) * s, CFrame.new(0, -0.6 * s, 0), WOOD, Enum.Material.WoodPlanks)
	for _, x in { -0.84, 0.84 } do
		for _, z in { -0.6, 0.6 } do
			piece(root, "CartWheel", Vector3.new(0.18, 0.72, 0.72) * s, CFrame.new(x * s, -0.64 * s, z * s), LEATHER, Enum.Material.Wood, Enum.PartType.Cylinder)
		end
	end
	-- Croix de bois, corps et tête de paille.
	piece(root, "Post", Vector3.new(0.2, 1.7, 0.2) * s, CFrame.new(0, 0.3 * s, 0), WOOD, Enum.Material.Wood)
	piece(root, "Arms", Vector3.new(1.7, 0.18, 0.18) * s, CFrame.new(0, 0.62 * s, 0), WOOD, Enum.Material.Wood)
	piece(root, "StrawBody", Vector3.new(0.95, 1.05, 0.62) * s, CFrame.new(0, 0.28 * s, 0), straw, Enum.Material.Fabric)
	piece(root, "StrawHead", Vector3.one * 0.62 * s, CFrame.new(0, 1.2 * s, 0), straw, Enum.Material.Fabric, Enum.PartType.Ball)
	piece(root, "Rope", Vector3.new(1, 0.1, 0.68) * s, CFrame.new(0, 0.74 * s, 0), LEATHER, Enum.Material.Fabric)
	-- Cible peinte sur la poitrine et dans le dos.
	for _, side in { -1, 1 } do
		piece(root, "TargetRing", Vector3.new(0.08, 0.78, 0.78) * s, CFrame.new(0, 0.3 * s, side * 0.33 * s) * sideways, white, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		piece(root, "TargetCore", Vector3.new(0.1, 0.4, 0.4) * s, CFrame.new(0, 0.3 * s, side * 0.36 * s) * sideways, red, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	end
end

-- Décor statique partagé : aucun script, collision, événement tactile ou boucle par objet.
-- Les cartes conservent leurs sols et leurs zones de jeu ; cet habillage est purement visuel.
function MedievalModels.sceneryPart(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, className: string?): BasePart
	local p = Instance.new(className or "Part") :: BasePart
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local scenery = MedievalModels.sceneryPart
local STONE = Color3.fromRGB(151, 151, 139)
local TRIM = Color3.fromRGB(194, 184, 157)
local ROOF = Color3.fromRGB(43, 82, 94)

function MedievalModels.roof(parent: Instance, cf: CFrame, width: number, depth: number, height: number, color: Color3)
	for _, side in { -1, 1 } do
		scenery(parent, "RoofSlope", Vector3.new(width, height, depth / 2), cf * CFrame.new(0, height / 2, side * depth / 4) * CFrame.Angles(0, if side < 0 then 0 else math.pi, 0), color, Enum.Material.Slate, "WedgePart")
	end
	scenery(parent, "RidgeCap", Vector3.new(width + 0.15, 0.2, 0.28), cf * CFrame.new(0, height + 0.05, 0), color:Lerp(TRIM, 0.25), Enum.Material.Metal)
end

function MedievalModels.banner(parent: Instance, cf: CFrame, color: Color3, scale: number)
	scenery(parent, "StandardPole", Vector3.new(0.16, 6, 0.16) * scale, cf * CFrame.new(0, 3 * scale, 0), WOOD, Enum.Material.Wood)
	scenery(parent, "StandardCrossbar", Vector3.new(2, 0.14, 0.14) * scale, cf * CFrame.new(0, 5.6 * scale, 0), GOLD, Enum.Material.Metal)
	scenery(parent, "StandardCloth", Vector3.new(1.65, 2.65, 0.1) * scale, cf * CFrame.new(0, 4.15 * scale, 0), color, Enum.Material.Fabric)
	scenery(parent, "StandardSigil", Vector3.new(0.54, 0.54, 0.12) * scale, cf * CFrame.new(0, 4.55 * scale, -0.09 * scale) * CFrame.Angles(0, 0, math.pi / 4), GOLD, Enum.Material.Metal)
	for _, side in { -1, 1 } do
		scenery(parent, "StandardHem", Vector3.new(0.08, 2.65, 0.12) * scale, cf * CFrame.new(side * 0.78 * scale, 4.15 * scale, -0.04 * scale), GOLD, Enum.Material.Fabric)
	end
end

function MedievalModels.tree(parent: Instance, cf: CFrame, scale: number, autumn: boolean?)
	local bark = scenery(parent, "TreeTrunk", Vector3.new(1.1, 6, 1.1) * scale, cf * CFrame.new(0, 3 * scale, 0), WOOD, Enum.Material.Wood)
	bark.CastShadow = false
	local leaf = if autumn then Color3.fromRGB(170, 112, 47) else Color3.fromRGB(58, 100, 69)
	for i, data in {
		{ Vector3.new(-1.8, 7, 0), Vector3.new(6.5, 6, 6) },
		{ Vector3.new(1.8, 8.5, 0.7), Vector3.new(6, 7, 6) },
		{ Vector3.new(0, 11, -0.3), Vector3.new(5.5, 6, 5.5) },
	} do
		local crown = scenery(parent, "TreeCrown", data[2] * scale, cf * CFrame.new(data[1] * scale) * CFrame.Angles(0, i * 0.7, 0.13), leaf:Lerp(TRIM, (i - 1) * 0.07), Enum.Material.Grass)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = crown
	end
end

function MedievalModels.cottage(parent: Instance, cf: CFrame, color: Color3)
	scenery(parent, "Cottage", Vector3.new(11, 7, 9), cf * CFrame.new(0, 3.5, 0), Color3.fromRGB(200, 184, 147), Enum.Material.Plaster)
	scenery(parent, "CottageFooting", Vector3.new(11.4, 1.1, 9.4), cf * CFrame.new(0, 0.55, 0), STONE, Enum.Material.Cobblestone)
	for _, x in { -5.3, 0, 5.3 } do
		scenery(parent, "Timber", Vector3.new(0.4, 7, 0.3), cf * CFrame.new(x, 3.5, -4.55), WOOD, Enum.Material.Wood)
	end
	scenery(parent, "TimberBeam", Vector3.new(11, 0.35, 0.3), cf * CFrame.new(0, 5.8, -4.55), WOOD, Enum.Material.Wood)
	scenery(parent, "Door", Vector3.new(2.1, 3.5, 0.18), cf * CFrame.new(0, 1.8, -4.7), LEATHER, Enum.Material.WoodPlanks)
	for _, x in { -3.3, 3.3 } do
		scenery(parent, "WindowFrame", Vector3.new(2, 2.2, 0.2), cf * CFrame.new(x, 4, -4.65), WOOD, Enum.Material.Wood)
		scenery(parent, "Window", Vector3.new(1.45, 1.65, 0.22), cf * CFrame.new(x, 4, -4.75), Color3.fromRGB(231, 177, 94), Enum.Material.SmoothPlastic)
		scenery(parent, "RearWindowFrame", Vector3.new(2, 2.2, 0.2), cf * CFrame.new(x, 4, 4.65), WOOD, Enum.Material.Wood)
		scenery(parent, "RearWindow", Vector3.new(1.45, 1.65, 0.22), cf * CFrame.new(x, 4, 4.75), Color3.fromRGB(231, 177, 94), Enum.Material.SmoothPlastic)
	end
	MedievalModels.roof(parent, cf * CFrame.new(0, 7, 0), 13, 11, 4, color)
	scenery(parent, "Chimney", Vector3.new(1.6, 5.5, 1.6), cf * CFrame.new(3.2, 8, 1.5), STONE, Enum.Material.Brick)
end

function MedievalModels.keepDetails(parent: Instance, cf: CFrame, color: Color3, halfWidth: number)
	-- Habillage des donjons existants, sans toucher à leur racine de gameplay.
	scenery(parent, "KeepCornice", Vector3.new(halfWidth * 2 + 0.9, 0.65, halfWidth * 2 + 0.9), cf * CFrame.new(0, 7.1, 0), TRIM, Enum.Material.Limestone)
	MedievalModels.roof(parent, cf * CFrame.new(0, 7.4, 0), halfWidth * 2 + 1, halfWidth * 2 + 1, 3.4, ROOF)
	for _, x in { -halfWidth, halfWidth } do
		for _, z in { -halfWidth, halfWidth } do
			scenery(parent, "TurretCoping", Vector3.new(3.1, 0.55, 3.1), cf * CFrame.new(x, 8.7, z), TRIM, Enum.Material.Limestone)
			MedievalModels.roof(parent, cf * CFrame.new(x, 9, z), 3.5, 3.5, 2.4, ROOF)
		end
	end
	for _, z in { -halfWidth - 0.04, halfWidth + 0.04 } do
		for _, x in { -2.4, 2.4 } do
			scenery(parent, "ArrowSlit", Vector3.new(0.45, 1.8, 0.12), cf * CFrame.new(x, 4.8, z), DARK_IRON, Enum.Material.Slate)
		end
	end
	scenery(parent, "KeepDoorFrame", Vector3.new(3.9, 5.1, 0.3), cf * CFrame.new(0, 2.55, halfWidth + 0.1), TRIM, Enum.Material.Limestone)
	scenery(parent, "KeepDoor", Vector3.new(3.1, 4.4, 0.35), cf * CFrame.new(0, 2.2, halfWidth + 0.25), WOOD, Enum.Material.WoodPlanks)
	MedievalModels.banner(parent, cf * CFrame.new(halfWidth + 2.5, 0, 0), color, 1.4)
end

function MedievalModels.landscape(parent: Instance, radius: number, seed: number)
	local random = Random.new(seed)
	local sceneryFolder = Instance.new("Folder")
	sceneryFolder.Name = "Landscape"
	sceneryFolder.Parent = parent
	-- Deux couronnes fixes ; toute la géométrie reste hors du terrain constructible.
	for i = 1, 52 do
		local angle = i / 52 * math.pi * 2
		local r = radius + random:NextNumber(0, 34)
		local cf = CFrame.new(math.sin(angle) * r, -0.2, math.cos(angle) * r) * CFrame.Angles(0, angle, 0)
		MedievalModels.tree(sceneryFolder, cf, random:NextNumber(1.1, 2.2), i % 7 == 0)
	end
	for i = 1, 22 do
		local angle = i / 22 * math.pi * 2
		local height = random:NextNumber(40, 78)
		local r = radius + 100
		local cf = CFrame.new(math.sin(angle) * r, 0, math.cos(angle) * r) * CFrame.Angles(0, angle, 0)
		local rockColor = Color3.fromRGB(91, 119, 113):Lerp(STONE, random:NextNumber(0, 0.2))
		local rock = scenery(sceneryFolder, "DistantMountain", Vector3.new(random:NextNumber(95, 130), height * 1.6, 105), cf * CFrame.new(0, 3, 0) * CFrame.Angles(0.12, 0, -0.12), rockColor, Enum.Material.Rock) :: Part
		rock.Shape = Enum.PartType.Ball
		local foothill = scenery(sceneryFolder, "Foothill", Vector3.new(100, height * 0.65, 75), cf * CFrame.new(28, 0, -32), Color3.fromRGB(101, 130, 82), Enum.Material.Grass) :: Part
		foothill.Shape = Enum.PartType.Ball
	end
end

return MedievalModels

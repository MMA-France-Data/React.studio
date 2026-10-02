-- Modèles perso des ennemis du mode solo (« emplacements de modèles »). Le propriétaire dépose un vrai
-- modèle 3D (Toolbox / Creator Store, générateur 3D + Mixamo, artiste...) dans ReplicatedStorage.EnemyModels :
-- les ennemis de ce type l'utilisent à la place des blocs de MedievalModels, sur les parcelles
-- (PlotRenderer) et dans la galerie Studio (EnemyGallery). Le ranked n'est pas concerné (ses ennemis sont
-- des pièces du serveur, Match/Game.luau).
--
-- Où mettre les modèles :
--   * dossier du projet assets/EnemyModels (Rojo : chaque fichier .rbxm / .rbxmx = un modèle, qui prend le
--     nom du fichier) : c'est ce qui les garde dans la place construite (rojo build) et sur GitHub ;
--   * ou directement ReplicatedStorage.EnemyModels dans Studio, pour essayer sans Rojo (crée le Folder
--     « EnemyModels » s'il n'existe pas). Ajoutés, renommés ou retirés pendant une partie : pris en compte
--     pour les ennemis suivants.
-- Noms (majuscules / minuscules sans importance) :
--   1. « <Type>_<palier> » : palier = tranche de 10 vagues, comme les styles de MedievalModels (Swarm_0 =
--      vagues 1-10, Boss_9 = vagues 91-100 ; ensuite ça recommence : vagues 101-110 = _0...) ;
--   2. sinon « <Type> » : toutes les vagues ;
--   3. sinon les blocs habituels.
--   Types (clés de Enemies.ORDER) : Normal = Fantassin, Fast = Cavalier, Tank = Chevalier lourd,
--   Boss = Seigneur de guerre, Swarm = Écuyer, Giant = Chevalier colossal.
-- Attributs facultatifs, à mettre sur le modèle dans Studio (Propriétés > Attributs > +, type Number) :
--   FacingOffset (degrés) : le devant attendu est -Z du pivot du modèle (son LookVector, comme partout dans
--       Roblox) ; s'il marche à reculons, mets 180 ; de côté : 90 ou -90. Personnage à os (Mixamo, Meshy,
--       KayKit, cheval...) sans FacingOffset : le devant est trouvé tout seul (frontDirection : du côté de ses
--       orteils, sinon de sa tête plutôt que de sa queue).
--   HeightScale (1 par défaut) : plus grand (1.3) ou plus petit (0.8) que la hauteur prévue pour ce type.
--   AnimSpeed (1 par défaut) : animation de marche plus rapide ou plus lente (si les pieds glissent).
--
-- Préparation, une seule fois par modèle (ensuite une simple copie par ennemi, Clone d'un modèle en cache) :
--   * copie du modèle ; on retire tous les scripts (Script, LocalScript, ModuleScript : protection contre les
--     portes dérobées de la Toolbox, avec un avertissement dans la Sortie), les sons et les objets cliquables ;
--     le modèle d'origine n'est pas modifié ;
--   * pièces sans collision, non ancrées et soudées à une racine invisible (Part de la taille du type) : comme
--     pour les blocs, PlotRenderer ne déplace que la racine (BulkMoveTo) et tout le modèle suit ; barre de vie,
--     disque de contrôle et contour « fragile » restent sur la racine. Les articulations (Motor6D d'un
--     personnage animé) sont gardées : on soude seulement une pièce par groupe de pièces déjà reliées (ses
--     WeldConstraint sont refaites après la mise à l'échelle, voir refreshJoints) ;
--   * mise à l'échelle (Model:ScaleTo) : hauteur = taille du type x HEIGHT_FACTORS (boss et colosses plus
--     grands, comme les blocs), pieds posés au sol, devant tourné vers -Z de la racine (le sens de marche).
-- Animation de marche : une Animation nommée « Marche » (ou « Walk », « Walking », ou « WalkAnim » du script
--   Animate de Roblox) dans le modèle, jouée en boucle par l'Animator de son Humanoid ou de son
--   AnimationController (créés s'il le faut). L'animation doit appartenir au créateur du jeu (ou à Roblox) :
--   sinon Roblox refuse de la jouer et le modèle avance sans bouger les jambes. Qui joue quoi et à quelle
--   vitesse : PlotRenderer (distance à la caméra, nombre maximal d'animations) et EnemyGallery.
-- Animation de mort (facultative) : une Animation nommée « Mort » (ou « Dead », « Death », « Die ») : jouée une
--   fois quand l'ennemi est tué, le corps reste un instant puis s'efface (PlotRenderer, startDeath).
-- Réglages dans le code (CustomModels.SETTINGS, plus bas) : le propriétaire donne juste les numéros de ses
--   animations publiées, sans rien ajouter au modèle dans Studio.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MedievalModels = require(script.Parent.MedievalModels)

local CustomModels = {}

CustomModels.FOLDER_NAME = "EnemyModels"

-- Réglages écrits dans le code, par modèle : [nom du modèle en minuscules] = {
--   walk = numéro de l'animation de marche publiée (Animation Editor > Publier sur Roblox),
--   death = numéro de l'animation de mort,
--   facing = degrés (comme l'attribut FacingOffset : 180 s'il marche à reculons),
--   height = comme l'attribut HeightScale, animSpeed = comme l'attribut AnimSpeed }.
-- Tout est facultatif. Ces réglages passent avant les objets Animation et les attributs du modèle.
CustomModels.SETTINGS = {
	-- Roi carmin (ChatGPT, assets/enemies/crimson-king) : boss des vagues 10, 110, 210... Animations
	-- « Walking » et « Dead » publiées par le propriétaire. animSpeed : sa marche est une vraie marche (Meshy),
	-- bien plus ample qu'une marche Roblox (WALK_REFERENCE) : ~3,8 fois plus vite pour que ses pieds suivent.
	boss_0 = { walk = 87099435097618, death = 90573475248434, animSpeed = 3.8 },
	-- Chef pillard de cuivre (ChatGPT, assets/enemies/copper-chieftain) : boss des vagues 20, 120, 220...
	-- Importé en FBX (les GLB retournaient sa tête). Même genre de marche que le Roi carmin.
	boss_1 = { walk = 71788744458869, death = 101510645677440, animSpeed = 3.8 },
	-- Gardien des ronces (ChatGPT) : boss des vagues 30, 130, 230...
	boss_2 = { walk = 91047716376652, death = 135721159652622, animSpeed = 3.8 },
	-- Titan de glace (ChatGPT) : boss des vagues 40, 140, 240...
	boss_3 = { walk = 72114228775968, death = 108006752796153, animSpeed = 3.8 },
	-- Seigneur des dunes (ChatGPT) : boss des vagues 50, 150, 250...
	boss_4 = { walk = 106949813842936, death = 136502915373905, animSpeed = 3.8 },
	-- Seigneur de la tempête (vague 70) : le Titan de glace repeint, même squelette : ses animations.
	boss_6 = { walk = 72114228775968, death = 108006752796153, animSpeed = 3.8 },
	-- Seigneur d'obsidienne (vague 80) : le Roi carmin retouché, mais son squelette est 100 fois plus petit (les
	-- animations du roi le faisaient marcher à l'envers) : ses propres animations, publiées depuis ses FBX.
	boss_7 = { walk = 81844791793411, death = 98247649438268, animSpeed = 3.8 },
	-- Dragon (vague 100) : il vole (animation « fly » jouée à la place de la marche, à peu près à vitesse 1 ; pas
	-- encore d'animation de mort).
	boss_9 = { walk = 83377179082342, animSpeed = 4.3 },
	-- Troupes carmin (ChatGPT, assets/enemies/crimson-ranks, vagues 1-10) : les 3 chevaliers ont le même
	-- squelette (KayKit), donc les mêmes animations (publiées une fois depuis le fantassin). Fantassin et
	-- chevalier lourd vont vite pour leur taille : la course (Running_A) ; le colosse, lent : la marche
	-- (Walking_A). animSpeed : estimé d'après leur taille et leur vitesse (à revoir à l'œil si les pieds glissent).
	normal_0 = { walk = 123757346012656, death = 85477305596501, animSpeed = 2.4 },
	tank_0 = { walk = 123757346012656, death = 85477305596501, animSpeed = 2.4 },
	giant_0 = { walk = 96179510952913, death = 85477305596501, animSpeed = 5.3 },
	-- Variantes des troupes (ChatGPT, assets/enemies/copper-ranks et bramble-ranks) : même squelette KayKit que
	-- les chevaliers carmin, donc mêmes animations (course, marche, mort publiées depuis le fantassin carmin).
	-- L'écuyer (petit et rapide) court, comme le fantassin. Swarm_0 (vagues 1-10) : en attendant un vrai écuyer
	-- carmin, c'est une copie du fantassin carmin (Normal_0), mis à la taille d'un écuyer par le jeu.
	swarm_0 = { walk = 123757346012656, death = 85477305596501, animSpeed = 2.4 },
	swarm_1 ={ walk = 123757346012656, death = 85477305596501, animSpeed = 2.4 },
	normal_1 = { walk = 123757346012656, death = 85477305596501, animSpeed = 2.4 },
	tank_1 = { walk = 123757346012656, death = 85477305596501, animSpeed = 2.4 },
	giant_1 = { walk = 96179510952913, death = 85477305596501, animSpeed = 5.3 },
	swarm_2 = { walk = 123757346012656, death = 85477305596501, animSpeed = 2.4 },
	normal_2 = { walk = 123757346012656, death = 85477305596501, animSpeed = 2.4 },
	tank_2 = { walk = 123757346012656, death = 85477305596501, animSpeed = 2.4 },
	giant_2 = { walk = 96179510952913, death = 85477305596501, animSpeed = 5.3 },
	swarm_3 = { walk = 123757346012656, death = 85477305596501, animSpeed = 2.4 },
	normal_3 = { walk = 123757346012656, death = 85477305596501, animSpeed = 2.4 },
	tank_3 = { walk = 123757346012656, death = 85477305596501, animSpeed = 2.4 },
	giant_3 = { walk = 96179510952913, death = 85477305596501, animSpeed = 5.3 },
	swarm_4 = { walk = 123757346012656, death = 85477305596501, animSpeed = 2.4 },
	normal_4 = { walk = 123757346012656, death = 85477305596501, animSpeed = 2.4 },
	tank_4 = { walk = 123757346012656, death = 85477305596501, animSpeed = 2.4 },
	giant_4 = { walk = 96179510952913, death = 85477305596501, animSpeed = 5.3 },
	-- Vagues 51-60 : Légion des os (mêmes squelettes, donc mêmes animations).
	swarm_5 = { walk = 123757346012656, death = 85477305596501, animSpeed = 2.4 },
	normal_5 = { walk = 123757346012656, death = 85477305596501, animSpeed = 2.4 },
	tank_5 = { walk = 123757346012656, death = 85477305596501, animSpeed = 2.4 },
	giant_5 = { walk = 96179510952913, death = 85477305596501, animSpeed = 5.3 },
	-- Vagues 61-70 (tempête), 71-80 (obsidienne), 81-90 (orcs), 91-100 (soldats du dragon) : mêmes squelettes.
	swarm_6 = { walk = 123757346012656, death = 85477305596501, animSpeed = 2.4 },
	normal_6 = { walk = 123757346012656, death = 85477305596501, animSpeed = 2.4 },
	tank_6 = { walk = 123757346012656, death = 85477305596501, animSpeed = 2.4 },
	giant_6 = { walk = 96179510952913, death = 85477305596501, animSpeed = 5.3 },
	swarm_7 = { walk = 123757346012656, death = 85477305596501, animSpeed = 2.4 },
	normal_7 = { walk = 123757346012656, death = 85477305596501, animSpeed = 2.4 },
	tank_7 = { walk = 123757346012656, death = 85477305596501, animSpeed = 2.4 },
	giant_7 = { walk = 96179510952913, death = 85477305596501, animSpeed = 5.3 },
	swarm_8 = { walk = 123757346012656, death = 85477305596501, animSpeed = 2.4 },
	normal_8 = { walk = 123757346012656, death = 85477305596501, animSpeed = 2.4 },
	tank_8 = { walk = 123757346012656, death = 85477305596501, animSpeed = 2.4 },
	giant_8 = { walk = 96179510952913, death = 85477305596501, animSpeed = 5.3 },
	swarm_9 = { walk = 123757346012656, death = 85477305596501, animSpeed = 2.4 },
	normal_9 = { walk = 123757346012656, death = 85477305596501, animSpeed = 2.4 },
	tank_9 = { walk = 123757346012656, death = 85477305596501, animSpeed = 2.4 },
	giant_9 = { walk = 96179510952913, death = 85477305596501, animSpeed = 5.3 },
	-- Cavaliers (nouveau squelette du cheval, à 48 os, commun à toutes leurs variantes) : galop et mort publiés
	-- depuis le cavalier carmin. animSpeed : un galop couvre bien plus de terrain qu'une marche Roblox.
	fast_0 = { walk = 109710149140915, death = 89761902672237, animSpeed = 0.75 },
	fast_1 = { walk = 109710149140915, death = 89761902672237, animSpeed = 0.75 },
	fast_2 = { walk = 109710149140915, death = 89761902672237, animSpeed = 0.75 },
	fast_3 = { walk = 109710149140915, death = 89761902672237, animSpeed = 0.75 },
	fast_4 = { walk = 109710149140915, death = 89761902672237, animSpeed = 0.75 },
	fast_5 = { walk = 109710149140915, death = 89761902672237, animSpeed = 0.75 },
	fast_6 = { walk = 109710149140915, death = 89761902672237, animSpeed = 0.75 },
	fast_7 = { walk = 109710149140915, death = 89761902672237, animSpeed = 0.75 },
	fast_8 = { walk = 109710149140915, death = 89761902672237, animSpeed = 0.75 },
	fast_9 = { walk = 109710149140915, death = 89761902672237, animSpeed = 0.75 },
}

-- Paliers : même découpage que les styles de MedievalModels (10 tranches de 10 vagues, puis ça recommence).
local PALIER_COUNT = MedievalModels.ENEMY_STYLE_COUNT or 10

-- Hauteur visée = taille du type (Enemies.Defs[type].size) x ce facteur : à peu près la hauteur des modèles
-- en blocs (fantassin 2,3 studs, écuyer 1,4, colosse 6, Seigneur de guerre 8).
local HEIGHT_FACTORS = { Normal = 1.15, Fast = 1.35, Tank = 1.15, Boss = 1.6, Swarm = 1.15, Giant = 1.35 }
local DEFAULT_HEIGHT_FACTOR = 1.15
local MIN_HEIGHT = 0.05 -- modèle plus plat que ça (ou vide) : inutilisable, on garde les blocs

-- Vitesse de lecture de la marche : à vitesse 1, une animation de marche Roblox fait avancer un personnage
-- de 5 studs de haut d'environ 14,5 studs/s (script Animate) ; plus petit ou plus rapide = pas plus vifs.
local WALK_REFERENCE = 5 / 14.5
local MIN_WALK_RATE, MAX_WALK_RATE = 0.3, 3
-- Noms reconnus pour l'animation de marche, par ordre de préférence (comparés en minuscules).
local WALK_NAMES = { "marche", "walk", "walking", "walkanim" }
-- Noms reconnus pour l'animation de mort.
local DEATH_NAMES = { "mort", "dead", "death", "die", "dying" }
-- Sinon, un nom qui CONTIENT un de ces mots (l'importateur de Studio nomme les animations d'un fichier 3D
-- « Scene_Walking », « Scene_Dead »...). Pas « die » : « soldier » le contient.
local WALK_WORDS = { "marche", "walk" }
local DEATH_WORDS = { "mort", "dead", "death", "dying" }

-- Retirés de la copie : scripts (toutes sortes), sons (un bruit en boucle x 45 ennemis...), objets
-- cliquables ou interactifs, et les données d'édition des animations (clips gardés dans le modèle par
-- l'importateur ou l'Animation Editor : inutiles en jeu, recopiés pour chaque ennemi sinon).
local REMOVED_CLASSES = { "Sound", "ClickDetector", "ProximityPrompt", "DragDetector", "Dialog", "AnimationClip" }
-- Retirés aussi, par leur nom : dossiers d'édition de l'importateur de Studio (clips, poses de départ des os).
local REMOVED_NAMES = { AnimSaves = true, InitialPoses = true }

local watching = false
local folder: Instance? = nil
local folderConnections: { RBXScriptConnection } = {}
local sourceConnections: { RBXScriptConnection } = {}
local dirty = true -- dossier modifié : index et modèles préparés à refaire
local index: { [string]: Instance } = {} -- [nom en minuscules] = modèle d'origine
-- Un même modèle peut être demandé à deux tailles (les monstres d'un niveau sont affichés plus gros que ceux d'une
-- parcelle, Levels.ENEMY_SCALE) : un modèle préparé par taille (clé = taille du type x 100, voir sizeKey).
local entries = {} -- [modèle d'origine] = { [taille] = modèle préparé (voir prepare), ou false s'il est inutilisable }
local lookups = {} -- [type] = { [taille] = { [palier, -1 = sans palier] = modèle préparé ou false } }
local warned: { [string]: boolean } = {} -- un seul avertissement par sujet

local function warnOnce(key: string, message: string)
	if not warned[key] then
		warned[key] = true
		warn("[Modèles perso] " .. message)
	end
end

local function markDirty()
	dirty = true
end

local function disconnectAll(list: { RBXScriptConnection })
	for _, connection in list do
		connection:Disconnect()
	end
	table.clear(list)
end

local function setFolder(newFolder: Instance?)
	if newFolder == folder then
		return
	end
	disconnectAll(folderConnections)
	folder = newFolder
	dirty = true
	if newFolder then
		-- N'importe quel changement dans le dossier (modèle ajouté, retiré, fini de charger) : on refait tout
		-- au prochain ennemi (peu coûteux : juste un index et des modèles en cache).
		table.insert(folderConnections, newFolder.DescendantAdded:Connect(markDirty))
		table.insert(folderConnections, newFolder.DescendantRemoving:Connect(markDirty))
	end
end

-- Suit ReplicatedStorage.EnemyModels (créé par Rojo, ou à la main dans Studio, même pendant la partie).
local function watch()
	if watching then
		return
	end
	watching = true
	local function refresh()
		setFolder(ReplicatedStorage:FindFirstChild(CustomModels.FOLDER_NAME))
	end
	ReplicatedStorage.ChildAdded:Connect(function(child)
		if child.Name == CustomModels.FOLDER_NAME then
			refresh()
		end
	end)
	ReplicatedStorage.ChildRemoved:Connect(function(child)
		if child == folder then
			refresh()
		end
	end)
	refresh()
end

local function rebuild()
	dirty = false
	disconnectAll(sourceConnections)
	for _, bySize in entries do
		for _, entry in bySize do
			if entry then
				entry.template:Destroy() -- les ennemis déjà créés sont des copies : ils ne changent pas
			end
		end
	end
	table.clear(entries)
	table.clear(lookups)
	table.clear(index)
	if not folder then
		return
	end
	for _, child in folder:GetChildren() do
		if child:IsA("Model") or child:IsA("BasePart") then
			local key = string.lower(child.Name)
			if index[key] == nil then
				index[key] = child
			end
			-- Renommé ou attribut changé (FacingOffset, HeightScale...) : à refaire.
			table.insert(sourceConnections, child:GetPropertyChangedSignal("Name"):Connect(markDirty))
			table.insert(sourceConnections, child.AttributeChanged:Connect(markDirty))
		end
	end
end

-- Réglages du code pour ce modèle (CustomModels.SETTINGS), ou nil.
local function settingsOf(source: Instance)
	local settings = CustomModels.SETTINGS[string.lower(source.Name)]
	return if type(settings) == "table" then settings else nil
end

-- Réglage chiffré : celui du code (SETTINGS[key]), sinon l'attribut du modèle, sinon default.
local function numberSetting(source: Instance, key: string, attribute: string, default: number, low: number, high: number): number
	local settings = settingsOf(source)
	local value = settings and settings[key]
	if typeof(value) ~= "number" or value ~= value then
		value = source:GetAttribute(attribute)
	end
	if typeof(value) ~= "number" or value ~= value then
		return default
	end
	return math.clamp(value, low, high)
end

-- Numéro d'animation du code (123456789 ou "123456789") -> "rbxassetid://123456789" ; nil sinon.
local function assetId(value): string?
	if typeof(value) == "number" and value > 0 and value == math.floor(value) and value < 1e15 then
		return "rbxassetid://" .. string.format("%d", value)
	elseif typeof(value) == "string" and value ~= "" then
		return if string.match(value, "^%d+$") then "rbxassetid://" .. value else value
	end
	return nil
end

-- Hauteur visée pour ce type (sans l'attribut HeightScale du modèle).
function CustomModels.targetHeight(enemyType: string, def): number
	return def.size * (HEIGHT_FACTORS[enemyType] or DEFAULT_HEIGHT_FACTOR)
end

-- Taille visible d'une pièce (une SpecialMesh de forme simple la déforme ; pour un fichier 3D, on ne
-- connaît que la taille de la pièce : HeightScale corrige si besoin).
local function visualSize(part: BasePart): Vector3
	local mesh = part:FindFirstChildWhichIsA("DataModelMesh")
	if mesh and not (mesh:IsA("SpecialMesh") and mesh.MeshType == Enum.MeshType.FileMesh) then
		return part.Size * (mesh :: any).Scale
	end
	return part.Size
end

-- Bas et haut du modèle dans le repère `frame` (pièces visibles ; toutes si aucune ne l'est).
local function verticalRange(parts: { BasePart }, frame: CFrame): (number, number)
	local low, high = math.huge, -math.huge
	local function add(part: BasePart)
		local cf = frame:ToObjectSpace(part.CFrame)
		local size = visualSize(part)
		local halfY = math.abs(cf.RightVector.Y) * size.X / 2 + math.abs(cf.UpVector.Y) * size.Y / 2 + math.abs(cf.LookVector.Y) * size.Z / 2
		low = math.min(low, cf.Y - halfY)
		high = math.max(high, cf.Y + halfY)
	end
	for _, part in parts do
		if part.Transparency < 1 then
			add(part)
		end
	end
	if low > high then
		for _, part in parts do
			add(part)
		end
	end
	return low, high
end

-- Animation du modèle : AnimationId de la première Animation qui porte un de ces noms, dans l'ordre (marche :
-- « Marche », puis « Walk »... ; mort : « Mort », puis « Dead »...), sinon de la première dont le nom contient
-- un de ces mots (words). Cherchée avant de retirer les scripts (la marche du script Animate de Roblox est
-- dedans).
local function findAnimation(model: Instance, names: { string }, words: { string }): string?
	local found: { [string]: string } = {}
	local order: { string } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Animation") and descendant.AnimationId ~= "" then
			local key = string.lower(descendant.Name)
			if found[key] == nil then
				found[key] = descendant.AnimationId
				table.insert(order, key)
			end
		end
	end
	for _, name in names do
		if found[name] then
			return found[name]
		end
	end
	for _, word in words do
		for _, key in order do
			if string.find(key, word, 1, true) then
				return found[key]
			end
		end
	end
	return nil
end

-- Devant d'un personnage à os : ses orteils sont devant ses chevilles (os dont le nom contient « toe » et
-- dont l'os parent contient « foot » : Mixamo, Meshy, KayKit... ; pas les os de contrôle « toe-roll »). Sans
-- orteils (quadrupède : cheval...), sa tête est devant sa queue. Direction horizontale, ou nil sans tels os.
local function frontDirection(model: Instance): Vector3?
	local sum = Vector3.zero
	local head: Bone?, tail: Bone? = nil, nil
	for _, bone in model:GetDescendants() do
		if bone:IsA("Bone") then
			local name = string.lower(bone.Name)
			local parent = bone.Parent
			if
				string.find(name, "toe", 1, true)
				and parent
				and parent:IsA("Bone")
				and string.find(string.lower(parent.Name), "foot", 1, true)
			then
				local step = bone.WorldPosition - parent.WorldPosition
				sum += Vector3.new(step.X, 0, step.Z)
			elseif not head and string.sub(name, -4) == "head" then
				head = bone
			elseif not tail and string.find(name, "tail", 1, true) then
				tail = bone
			end
		end
	end
	if sum.Magnitude > 1e-4 then
		return sum.Unit
	end
	if head and tail then
		local step = head.WorldPosition - tail.WorldPosition
		local flat = Vector3.new(step.X, 0, step.Z)
		if flat.Magnitude > 1e-4 then
			return flat.Unit
		end
	end
	return nil
end
-- (pour les tests Studio : sens d'un modèle perso déjà posé)
CustomModels.frontDirection = frontDirection

-- Animation qui retourne le modèle : certains modèles importés (os rangés dans un seul MeshPart : Roi carmin,
-- fantassin carmin) se retrouvent tournés d'un demi-tour dès qu'une animation joue (l'import de Studio tourne
-- leur os de départ d'un demi-tour au repos, et leurs animations le défont). Mesuré une fois par modèle, sur un
-- ennemi dont la marche joue et dont la racine est encore dans le sens normal : entry.flipWhenAnimated =
-- vrai (retourné) ou faux ; nil tant que la mesure n'est pas finie. Ceux qui l'affichent (PlotRenderer,
-- EnemyGallery) tournent alors la racine d'un demi-tour pendant les animations.
-- Un appel = un échantillon (à refaire à chaque image jusqu'à la décision). À un moment du pas, les pieds
-- peuvent pointer vers l'arrière : une seule mesure pouvait tomber là et laisser le modèle à reculons toute la
-- partie. On mesure donc à FLIP_PHASES_NEEDED moments différents du pas (sur FLIP_PHASES), et on décide avec
-- leur moyenne.
-- track : sa piste de marche. Pas d'échantillon tant qu'elle ne joue pas pour de bon (chargée, fondu d'entrée
-- fini, pas figée) : juste après un Play, les os sont encore au repos.
local FLIP_PHASES = 8
local FLIP_PHASES_NEEDED = 6
function CustomModels.measureFlip(root: BasePart, entry, track: AnimationTrack?): boolean?
	if entry.flipWhenAnimated ~= nil then
		return entry.flipWhenAnimated
	end
	if not track or not (track.IsPlaying and track.Length > 0 and track.WeightCurrent > 0.99 and track.Speed > 0.05) then
		return nil
	end
	local front = frontDirection(root)
	if not front then
		entry.flipWhenAnimated = false -- pas d'os pour le savoir : on ne touche à rien
		return false
	end
	local phase = math.clamp(math.floor(track.TimePosition / track.Length * FLIP_PHASES), 0, FLIP_PHASES - 1) + 1
	local samples = entry.flipSamples
	if not samples then
		samples = {}
		entry.flipSamples = samples
	end
	if samples[phase] == nil then
		samples[phase] = -root.CFrame:VectorToObjectSpace(front).Z -- 1 = vers l'avant, -1 = à reculons
	end
	local count, sum = 0, 0
	for _, forward in samples do
		count += 1
		sum += forward
	end
	if count >= FLIP_PHASES_NEEDED then
		entry.flipWhenAnimated = sum / count < 0
		entry.flipSamples = nil
	end
	return entry.flipWhenAnimated
end

-- Soudures internes du modèle, une fois mis à l'échelle et placé : chaque WeldConstraint est refaite (une
-- soudure neuve enregistre les positions du moment, comme celles des blocs de MedievalModels ; hors du
-- Workspace, rien ne garantit que ScaleTo mette à jour l'écart enregistré par l'ancienne, et le modèle se
-- disloquerait en entrant dans le Workspace). Une articulation vers une pièce hors du modèle (soudé au sol
-- dans Studio...) est retirée : elle accrocherait l'ennemi à cette pièce.
local function refreshJoints(model: Instance, parts: { BasePart })
	local inModel: { [Instance]: boolean } = {}
	for _, part in parts do
		inModel[part] = true
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("JointInstance") or descendant:IsA("WeldConstraint") then
			local joint = descendant :: any
			local part0, part1 = joint.Part0, joint.Part1
			if (part0 and not inModel[part0]) or (part1 and not inModel[part1]) then
				descendant:Destroy()
			elseif descendant:IsA("WeldConstraint") and joint.Enabled and part0 and part1 and part0 ~= part1 then
				local fresh = Instance.new("WeldConstraint")
				fresh.Name = descendant.Name
				fresh.Part0 = part0
				fresh.Part1 = part1
				fresh.Parent = descendant.Parent
				descendant:Destroy()
			end
		end
	end
end

-- Soude le modèle à la racine sans casser ses articulations : les pièces déjà reliées entre elles (Motor6D,
-- Weld, WeldConstraint, RigidConstraint...) forment un groupe ; on soude à la racine UNE pièce par groupe :
-- la HumanoidRootPart, sinon la base de ses Motor6D (jamais au bout d'un bras), sinon la plus grosse.
local function weldToRoot(model: Instance, parts: { BasePart }, root: BasePart)
	local parent: { [BasePart]: BasePart } = {}
	for _, part in parts do
		parent[part] = part
	end
	local function find(part: BasePart): BasePart
		while parent[part] ~= part do
			parent[part] = parent[parent[part]]
			part = parent[part]
		end
		return part
	end
	local motorChild: { [BasePart]: boolean } = {}
	for _, descendant in model:GetDescendants() do
		local a, b = nil, nil
		if descendant:IsA("JointInstance") or descendant:IsA("WeldConstraint") then
			if (descendant :: any).Enabled then
				a, b = (descendant :: any).Part0, (descendant :: any).Part1
			end
			if descendant:IsA("Motor6D") and descendant.Part1 then
				motorChild[descendant.Part1] = true
			end
		elseif descendant:IsA("RigidConstraint") or descendant:IsA("AnimationConstraint") then
			local constraint = descendant :: any
			if constraint.Enabled and constraint.Attachment0 and constraint.Attachment1 then
				a, b = constraint.Attachment0.Parent, constraint.Attachment1.Parent
			end
		end
		if a and b and parent[a] and parent[b] then
			local rootA, rootB = find(a), find(b)
			if rootA ~= rootB then
				parent[rootA] = rootB
			end
		end
	end
	local best: { [BasePart]: BasePart } = {}
	local function score(part: BasePart): number
		local size = part.Size
		return (if part.Name == "HumanoidRootPart" then 2e9 else 0)
			+ (if motorChild[part] then 0 else 1e9)
			+ math.min(size.X * size.Y * size.Z, 1e8)
	end
	for _, part in parts do
		local group = find(part)
		if not best[group] or score(part) > score(best[group]) then
			best[group] = part
		end
	end
	for _, part in best do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = root
	end
end

-- Prépare un modèle d'origine pour ce type : renvoie { template, name, height, top, animation, animSpeed }
-- (template = racine + modèle soudé, en CFrame.identity, jamais dans le Workspace), ou nil s'il est
-- inutilisable (on garde alors les blocs).
local function prepare(source: Instance, enemyType: string, def)
	-- 1) Copie (les objets non « Archivable » ne seraient pas copiés : on les autorise, sur ce client).
	if not source.Archivable then
		source.Archivable = true
	end
	for _, descendant in source:GetDescendants() do
		if not descendant.Archivable then
			descendant.Archivable = true
		end
	end
	local copy = source:Clone()
	if not copy then
		return nil
	end
	local model: Model
	if copy:IsA("Model") then
		model = copy
	else
		-- Une seule pièce (MeshPart...) : on l'emballe dans un modèle.
		model = Instance.new("Model")
		model.Name = source.Name
		copy.Parent = model
		model.PrimaryPart = copy :: BasePart
	end

	-- 2) Animations de marche et de mort (réglages du code d'abord), puis nettoyage : scripts, sons, objets
	-- cliquables.
	local settings = settingsOf(source)
	local walkId = (settings and assetId(settings.walk)) or findAnimation(model, WALK_NAMES, WALK_WORDS)
	local deathId = (settings and assetId(settings.death)) or findAnimation(model, DEATH_NAMES, DEATH_WORDS)
	local scripts = 0
	for _, descendant in model:GetDescendants() do
		if descendant.Parent == nil then
			continue -- déjà retiré avec son parent
		end
		if descendant:IsA("LuaSourceContainer") then
			scripts += 1
			descendant:Destroy()
			continue
		end
		if REMOVED_NAMES[descendant.Name] and not descendant:IsA("BasePart") and not descendant:IsA("Bone") then
			descendant:Destroy()
			continue
		end
		for _, className in REMOVED_CLASSES do
			if descendant:IsA(className) then
				descendant:Destroy()
				break
			end
		end
	end
	if scripts > 0 then
		warnOnce(
			"scripts:" .. source.Name,
			`{scripts} script(s) retiré(s) du modèle « {source.Name} » (sécurité : un modèle de la Toolbox peut cacher une porte dérobée). Supprime-les aussi dans Studio avant d'enregistrer le modèle.`
		)
	end

	-- 3) Pièces purement visuelles ; Humanoid silencieux et bon marché.
	local parts: { BasePart } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false -- (avant CanQuery : possible seulement sans collision)
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
			if descendant.Transparency >= 1 then
				descendant.CastShadow = false
			end
			table.insert(parts, descendant)
		elseif descendant:IsA("Humanoid") then
			local humanoid = descendant
			pcall(function()
				humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None -- pas de nom au-dessus
				humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
				humanoid.BreakJointsOnDeath = false
				humanoid.RequiresNeck = false
				humanoid.MaxHealth = math.max(humanoid.MaxHealth, 1)
				humanoid.Health = humanoid.MaxHealth
				humanoid.EvaluateStateMachine = false -- pas de physique de personnage : il est porté par la racine
			end)
		end
	end
	if #parts == 0 then
		warnOnce("empty:" .. source.Name, `le modèle « {source.Name} » ne contient aucune pièce : blocs gardés.`)
		model:Destroy()
		return nil
	end

	-- 4) Repère « devant » : pivot du modèle, debout, tourné de FacingOffset degrés ; son -Z = le devant.
	-- Personnage à os (Mixamo, Meshy, KayKit, cheval...) sans réglage « facing » ni attribut FacingOffset : le
	-- devant est trouvé par ses os (frontDirection : orteils, sinon tête et queue), quel que soit son pivot.
	local facing = math.rad(numberSetting(source, "facing", "FacingOffset", 0, -360, 360))
	local explicitFacing = (settings ~= nil and typeof(settings.facing) == "number")
		or typeof(source:GetAttribute("FacingOffset")) == "number"
	local frontLocal: Vector3? = nil
	if not explicitFacing then
		local front = frontDirection(model)
		frontLocal = front and model:GetPivot():VectorToObjectSpace(front)
	end
	local function frontFrame(): CFrame
		local pivot = model:GetPivot()
		local look = if frontLocal then pivot:VectorToWorldSpace(frontLocal) else pivot.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude < 0.1 then
			flat = Vector3.new(0, 0, -1) -- pivot qui regarde en l'air : -Z du monde
		end
		return CFrame.lookAt(pivot.Position, pivot.Position + flat.Unit) * CFrame.Angles(0, facing, 0)
	end

	-- 5) Mise à l'échelle : hauteur visée pour ce type (x HeightScale).
	local low, high = verticalRange(parts, frontFrame())
	if high - low < MIN_HEIGHT then
		warnOnce("flat:" .. source.Name, `le modèle « {source.Name} » est trop petit pour être mesuré : blocs gardés.`)
		model:Destroy()
		return nil
	end
	local height = CustomModels.targetHeight(enemyType, def) * numberSetting(source, "height", "HeightScale", 1, 0.05, 20)
	local scaled = pcall(function()
		model:ScaleTo(model:GetScale() * height / (high - low))
	end)
	if not scaled then
		warnOnce("scale:" .. source.Name, `impossible de mettre le modèle « {source.Name} » à l'échelle : blocs gardés.`)
		model:Destroy()
		return nil
	end
	local frame = frontFrame()
	low, high = verticalRange(parts, frame)

	-- 6) Racine invisible, comme celle des blocs : c'est elle que PlotRenderer déplace (son -Z = sens de
	-- marche, son centre à taille / 2 au-dessus du chemin). Le modèle : pivot au centre, pieds au sol.
	local root = Instance.new("Part")
	root.Name = "EnemyRoot"
	root.Size = Vector3.one * def.size
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CastShadow = false
	root.CFrame = CFrame.identity
	root:SetAttribute("EnemyType", enemyType)
	root:SetAttribute("CustomModel", source.Name)
	local placed = CFrame.new(0, -def.size / 2 - low, 0)
	model:PivotTo(placed * frame:Inverse() * model:GetPivot())
	refreshJoints(model, parts)
	model.Parent = root
	weldToRoot(model, parts, root)

	-- 7) Animations de marche et de mort : un Animator sous le Humanoid ou l'AnimationController (créés s'il
	-- le faut).
	local animation: Animation? = nil
	local deathAnimation: Animation? = nil
	if walkId or deathId then
		local controller: Instance? = model:FindFirstChildWhichIsA("Humanoid", true) or model:FindFirstChildWhichIsA("AnimationController", true)
		if not controller then
			controller = Instance.new("AnimationController")
			controller.Parent = model
		end
		if controller and not controller:FindFirstChildWhichIsA("Animator") then
			Instance.new("Animator").Parent = controller
		end
	end
	if walkId then
		animation = Instance.new("Animation")
		animation.Name = "Marche"
		animation.AnimationId = walkId
	end
	if deathId then
		deathAnimation = Instance.new("Animation")
		deathAnimation.Name = "Mort"
		deathAnimation.AnimationId = deathId
	end

	return {
		template = root,
		name = source.Name,
		height = high - low, -- hauteur finale du modèle (studs)
		top = -def.size / 2 + (high - low), -- haut du modèle au-dessus du centre de la racine (barre de vie)
		animation = animation, -- nil : pas d'animation de marche
		deathAnimation = deathAnimation, -- nil : pas d'animation de mort (l'ennemi disparaît d'un coup)
		animSpeed = numberSetting(source, "animSpeed", "AnimSpeed", 1, 0.05, 10),
	}
end

local function palierKey(palier: number?): number
	if palier == nil then
		return -1
	end
	if palier ~= palier or math.abs(palier) == math.huge then
		return 0
	end
	return math.max(0, math.floor(palier)) % PALIER_COUNT
end

-- Modèle préparé pour ce type et ce palier (nil = pas de modèle perso : blocs).
function CustomModels.find(enemyType: string, def, palier: number?)
	watch()
	if dirty then
		rebuild()
	end
	if next(index) == nil then
		return nil
	end
	local key = palierKey(palier)
	local sizeKey = math.floor(def.size * 100 + 0.5)
	local byType = lookups[enemyType]
	if not byType then
		byType = {}
		lookups[enemyType] = byType
	end
	local byPalier = byType[sizeKey]
	if not byPalier then
		byPalier = {}
		byType[sizeKey] = byPalier
	end
	local cached = byPalier[key]
	if cached ~= nil then
		return cached or nil
	end
	local source = (if key >= 0 then index[string.lower(`{enemyType}_{key}`)] else nil) or index[string.lower(enemyType)]
	local entry = false
	if source then
		local bySize = entries[source]
		if not bySize then
			bySize = {}
			entries[source] = bySize
		end
		entry = bySize[sizeKey]
		if entry == nil then
			-- Modèle imprévu (Toolbox...) qui ferait échouer la préparation : blocs gardés, sans casser
			-- l'affichage des autres ennemis (appelé pendant la lecture d'un paquet, PlotRenderer).
			local ok, prepared = pcall(prepare, source, enemyType, def)
			if not ok then
				warnOnce("error:" .. source.Name, `le modèle « {source.Name} » n'a pas pu être préparé ({prepared}) : blocs gardés.`)
			end
			entry = if ok and prepared then prepared else false
			bySize[sizeKey] = entry
		end
	end
	byPalier[key] = entry
	return entry or nil
end

-- Nouvel ennemi avec le modèle perso de ce type et de ce palier : racine (Part invisible, ancrée, pas encore
-- dans le Workspace) avec le modèle soudé, et son modèle préparé ; nil s'il n'y a pas de modèle perso.
-- at : où la poser (racine ET modèle déplacés ensemble, avant d'entrer dans le Workspace) ; sinon à l'origine.
function CustomModels.spawn(enemyType: string, def, palier: number?, at: CFrame?)
	local entry = CustomModels.find(enemyType, def, palier)
	if not entry then
		return nil, nil
	end
	local root = entry.template:Clone()
	if at then
		local model = root:FindFirstChildWhichIsA("Model")
		if model then
			model:PivotTo(at * model:GetPivot())
		end
		root.CFrame = at
	end
	return root, entry
end

-- Vitesse de lecture de la marche pour ce modèle quand l'ennemi avance normalement à normalSpeed studs/s
-- (sans ralentissement ni Vitesse x2 : à multiplier ensuite par la vitesse du moment / la vitesse normale).
function CustomModels.walkRate(entry, normalSpeed: number): number
	return math.clamp(WALK_REFERENCE * normalSpeed / math.max(entry.height, MIN_HEIGHT) * entry.animSpeed, MIN_WALK_RATE, MAX_WALK_RATE)
end

-- Charge l'animation de marche sur un ennemi créé par spawn (dans le Workspace) : piste en boucle, pas encore
-- jouée, ou nil (pas d'animation, pas d'Animator, refusée par Roblox).
function CustomModels.loadWalk(root: BasePart, entry): AnimationTrack?
	if not entry.animation then
		return nil
	end
	local animator = root:FindFirstChildWhichIsA("Animator", true)
	if not animator then
		return nil
	end
	local ok, track = pcall(function()
		return animator:LoadAnimation(entry.animation)
	end)
	if not ok or not track then
		warnOnce("anim:" .. entry.name, `l'animation de marche du modèle « {entry.name} » n'a pas pu être chargée : il avancera sans bouger les jambes.`)
		return nil
	end
	track.Looped = true
	track.Priority = Enum.AnimationPriority.Movement
	return track
end

-- Charge l'animation de mort sur un ennemi créé par spawn (dans le Workspace) : piste jouée une fois (au-dessus
-- de la marche), pas encore jouée, ou nil (pas d'animation, pas d'Animator, refusée par Roblox).
function CustomModels.loadDeath(root: BasePart, entry): AnimationTrack?
	if not entry.deathAnimation then
		return nil
	end
	local animator = root:FindFirstChildWhichIsA("Animator", true)
	if not animator then
		return nil
	end
	local ok, track = pcall(function()
		return animator:LoadAnimation(entry.deathAnimation)
	end)
	if not ok or not track then
		warnOnce("death:" .. entry.name, `l'animation de mort du modèle « {entry.name} » n'a pas pu être chargée : il disparaîtra d'un coup.`)
		return nil
	end
	track.Looped = false
	track.Priority = Enum.AnimationPriority.Action
	return track
end

-- Serveur (Main.server.luau) : retire les scripts des modèles perso au démarrage et à chaque ajout, avec un
-- avertissement. Un Script réglé en RunContext « Server » ou « Client » tourne même rangé dans
-- ReplicatedStorage, et ce nettoyage peut arriver trop tard pour un script piégé : il faut donc toujours
-- supprimer les scripts dans Studio avant d'enregistrer le modèle (voir assets/EnemyModels/README.txt).
function CustomModels.sanitizeSources()
	local function clean(container: Instance, descendant: Instance)
		if not descendant:IsA("LuaSourceContainer") or descendant.Parent == nil then
			return
		end
		local owner = descendant
		while owner.Parent and owner.Parent ~= container do
			owner = owner.Parent
		end
		-- L'animation de marche du script « Animate » d'un personnage Roblox (walk > WalkAnim) est gardée :
		-- rangée directement dans le modèle avant de supprimer le script.
		if owner ~= descendant then
			for _, animation in descendant:GetDescendants() do
				if animation:IsA("Animation") and table.find(WALK_NAMES, string.lower(animation.Name)) then
					animation.Parent = owner
				end
			end
		end
		warnOnce(
			"server:" .. owner.Name,
			`script « {descendant.Name} » supprimé du modèle « {owner.Name} » (ReplicatedStorage.{CustomModels.FOLDER_NAME}) : un modèle d'ennemi ne doit contenir aucun script. Supprime-les dans Studio et réenregistre le modèle.`
		)
		descendant:Destroy()
	end
	local function watchContainer(container: Instance)
		for _, descendant in container:GetDescendants() do
			clean(container, descendant)
		end
		container.DescendantAdded:Connect(function(descendant)
			clean(container, descendant)
		end)
	end
	local existing = ReplicatedStorage:FindFirstChild(CustomModels.FOLDER_NAME)
	if existing then
		watchContainer(existing)
	end
	ReplicatedStorage.ChildAdded:Connect(function(child)
		if child.Name == CustomModels.FOLDER_NAME then
			watchContainer(child)
		end
	end)
end

return CustomModels

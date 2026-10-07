-- Les familiers. Le chemin d'un familier :
--   1. une salle réussie donne un TICKET de cette salle ;
--   2. à la boutique du lobby, le ticket s'échange contre un ŒUF de la salle : sa rareté (6 rangs, du commun au
--      super rare) est tirée là. Dans une salle à COLLECTION (Pets.COLLECTIONS), le rang donne l'animal : six
--      animaux par salle, du plus courant au super rare. Ailleurs, c'est l'animal de la salle, peint selon le rang ;
--   3. le joueur POSE l'œuf lui-même sur une place libre de son enclos ; il y couve (plus il est rare, plus c'est long) ;
--   4. à l'éclosion, le familier reçoit une VALEUR cachée tirée dans le palier de sa rareté : c'est elle qui décide
--      de ce qu'il rapporte à chaque seconde. Deux familiers de la même rareté ne rapportent donc pas pareil, et on
--      peut avoir plusieurs fois le même.
-- L'enclos a peu de places : on en achète, et on peut vendre un familier pour libérer la sienne.
-- Les familiers ne donnent aucun bonus dans les salles. Le joueur peut en choisir un qui le suit, pour le plaisir.
local AssetService = game:GetService("AssetService")

local Pets = {}
local gradient
local PetModels = require(script.Parent.PetModels)

Pets.ORDER = { "Dragon", "Rock", "Rabbit", "Golem", "Owl" }

-- income : ce que l'animal rapporte par rapport au dragon (les animaux des salles plus lointaines rapportent plus).
-- size : grosseur de l'animal quand il suit le joueur (1 si absent).
-- move : comment il bouge (voir Animals.luau) : fly = vole, bounce = rebondit, hop = saute quand le joueur avance,
--        walk = marche en balançant bras et jambes.
Pets.DEFS = {
	Dragon = { income = 1, size = 1.8, move = "fly" }, -- salles 1, 5, 9
	Rock = { income = 1.5, move = "bounce" }, -- salle 2
	Rabbit = { income = 2, move = "hop" }, -- salles 3, 8
	Golem = { income = 3, move = "walk" }, -- salles 4, 7, 10
	Owl = { income = 2.5, move = "fly" }, -- salle 6
}

-- LES COLLECTIONS : les six animaux d'une salle, du plus courant (rang 1) au SUPER RARE (rang 6). L'œuf d'une de ces
-- salles tire un rang, qui donne l'animal. (Bunny et Owlet : le lapin et la chouette des collections, pour ne pas
-- les confondre avec les anciens Rabbit et Owl des salles du fond.)
-- (Jeu « Monde » : l'ordre est celui des ZONES : 1 la ferme, 2 la forêt, 3 la jungle. Les deux dernières
-- collections attendent leurs zones.)
Pets.COLLECTIONS = {
	{ "Duck", "Rooster", "Pig", "Sheep", "Goat", "Horse" },
	{ "Hedgehog", "Squirrel", "Skunk", "Beaver", "Raccoon", "Badger" },
	{ "Capybara", "Toucan", "Monkey", "Anaconda", "Crocodile", "Jaguar" },
	{ "Boar", "Ram", "Deer", "Lynx", "Wolf", "Bear" },
	{ "Bunny", "Turtle", "Cat", "Dog", "Owlet", "Fox" },
}
for room, list in Pets.COLLECTIONS do
	for rank, name in list do
		Pets.DEFS[name] = { income = 1, move = "walk", room = room, rank = rank }
	end
end
-- L'animal d'un œuf de cette salle et de ce rang (fallback : l'animal de la salle, s'il n'y a pas de collection).
function Pets.animalOf(room: number, rank: number, fallback: string): string
	local list = Pets.COLLECTIONS[room]
	return list and list[rank] or fallback
end

-- LA VALEUR CACHÉE : le palier de chaque rang (commun, peu commun, rare, épique, légendaire, super rare), en
-- centièmes de pièce par seconde. Demandes du joueur : « le minimum soit deux pièces » (le pire familier de la
-- salle 1 rapporte 2 pièces par seconde) et « le super rare de la salle 1 paie quand même bien plus qu'un commun
-- de la salle 3, voire 4 ». Salle 1, en pièces par seconde : commun 2 à 5, peu commun 5 à 15, rare 15 à 60, épique
-- 60 à 300, légendaire 300 à 1 500, super rare 6 000 à 15 000 (un commun de la salle 4 : 2 000 à 5 000).
Pets.VALUE = { { 200, 500 }, { 500, 1500 }, { 1500, 6000 }, { 6000, 30000 }, { 30000, 150000 }, { 600000, 1500000 } }
-- Ces paliers sont ceux de la salle 1 : chaque salle suivante les multiplie par ROOM_FACTOR (salle 2 : commun 10 à
-- 500 ; salle 3 : 100 à 5 000... salle 10 : x 1 milliard), puis par LATE_FACTOR après la salle LATE_ROOM (les
-- salles à venir). Les prix des machines sont calculés là-dessus (tools/balance/machines.py) : si on change ces
-- chiffres, il faut les recalculer.
Pets.ROOM_FACTOR = 100 -- (jeu « Monde » : x 100 par monde, comme les monstres et les prix)
Pets.LATE_ROOM = 10
Pets.LATE_FACTOR = 2
function Pets.roomFactor(room: number): number
	room = math.max(1, room)
	return Pets.ROOM_FACTOR ^ (math.min(room, Pets.LATE_ROOM) - 1) * Pets.LATE_FACTOR ^ math.max(0, room - Pets.LATE_ROOM)
end
-- LE FAMILIER QUI SUIT LE JOUEUR lui donne un bonus de chance d'œuf rare, en %, selon sa place dans les paliers
-- de valeur (sa valeur de la salle 1, avant ROOM_FACTOR) : commun 0 à 3 %, peu commun 3 à 6 %, rare 6 à 12 %,
-- épique 12 à 25 %, légendaire 25 à 50 %, super rare 50 à 100 % ; multiplié par LUCK_ROOM à chaque salle.
-- Le bonus est tiré à l'éclosion et gardé dans la place (`l`). Le familier rapporte quand même ses pièces.
Pets.LUCK = { { 0, 3 }, { 3, 6 }, { 6, 12 }, { 12, 25 }, { 25, 50 }, { 50, 100 } }
Pets.LUCK_ROOM = 1.15
function Pets.luckPercent(baseValue: number, room: number): number
	local rank = 1
	for index, range in Pets.VALUE do
		if baseValue >= range[1] then
			rank = index
		end
	end
	local range, luck = Pets.VALUE[rank], Pets.LUCK[rank]
	local along = math.clamp((baseValue - range[1]) / (range[2] - range[1]), 0, 1)
	return math.floor((luck[1] + (luck[2] - luck[1]) * along) * Pets.LUCK_ROOM ^ (math.max(1, room) - 1) + 0.5)
end
-- Le bonus de chance (en %) du familier de cette place (un familier d'avant ce bonus : d'après sa valeur).
function Pets.luckOf(spot): number
	if not spot or not spot.v then
		return 0
	end
	return spot.l or Pets.luckPercent(spot.v, 1)
end
-- Ce qu'un familier rapporte par seconde = sa valeur / VALUE_PER_COIN x le facteur de son animal.
-- Exemples (salle 1) : lapin commun 2 à 5 par seconde ; renard super rare 6 000 à 15 000 par seconde.
-- (Jeu « Monde » : dix fois moins que dans SURVIVE!. Retour du joueur : « je monte trop vite en pièces, j'ai déjà
-- 5 000, je suis juste au coq, j'en ai qu'un et j'ai déjà l'épée 3 ». Un canard rapporte 0,2 à 0,5 pièce par seconde.)
Pets.VALUE_PER_COIN = 1000
-- Couvaison : secondes selon le rang, multipliées par (0,5 + numéro de la salle / 10).
-- Exemples : commun de la salle 1 = 18 s ; super rare de la salle 1 = 12 min ; légendaire de la salle 10 = 15 min.
Pets.HATCH = { 30, 60, 150, 300, 600, 1200 }

-- L'ENCLOS : son niveau donne le nombre de places (niveau 1 = SPOTS_FREE places, +1 par niveau). Le prix de chaque
-- place est CALCULÉ par tools/balance/machines.py, comme ceux des machines, sur ce que rapportent les familiers :
-- les 5 premières places en plus se paient pendant les 10 premières salles (la 6e dès la salle 2),
-- les suivantes une toutes les 20 heures, la 20e vers 200 heures.
Pets.SPOTS_FREE = 5
Pets.SPOTS_MAX = 20
-- Prix de la 6e place, de la 7e, etc.
Pets.SPOT_PRICES = { 400, 1800, 8100, 36450, 164025, 738112, 3321506, 14946778, 67260501, 302672257, 1362025156, 6129113204, 27581009421, 124114542398, 558515440794 } -- jeu « Monde » : 400 pièces, puis x 4,5 à chaque place
Pets.MAX_BAG = 60 -- œufs gardés en attente d'être posés
-- La zone de l'enclos où marchent les familiers et où on pose les œufs, par rapport au milieu de l'espace du joueur.
Pets.PEN = { minX = -7, maxX = 27, minZ = 4, maxZ = 29 }

-- Niveau de l'enclos quand il a `places` places.
function Pets.penLevel(places: number): number
	return places - Pets.SPOTS_FREE + 1
end

-- Chaque rareté a son MÉLANGE de couleurs, peint sur l'animal lui-même : un dégradé de toute la palette recouvre
-- son corps (plusieurs couleurs visibles en même temps).
-- commun = ses couleurs d'origine ; peu commun = bleu, turquoise, vert ; rare = doré, orange, rose ;
-- épique = rose, rouge, orange ; légendaire = violet, rose, bleu, turquoise, et des étincelles ; super rare =
-- arc-en-ciel. Les animaux des collections ne sont PAS repeints (leur animal dit déjà leur rang) : ils gardent
-- seulement la grosseur, la lumière et les étincelles de leur rang.
-- color : la couleur de la rareté dans les textes ; tint : force du voile de couleur si le dégradé ne peut pas
-- être peint (voir gradient plus bas).
Pets.RARITIES = {
	{ key = "Common", color = Color3.fromRGB(200, 204, 214), scale = 1, tint = 0 },
	{
		key = "Uncommon",
		color = Color3.fromRGB(60, 150, 255),
		scale = 1.12,
		tint = 0.4,
		palette = { Color3.fromRGB(40, 110, 255), Color3.fromRGB(50, 225, 255), Color3.fromRGB(60, 235, 150) },
	},
	{
		key = "Rare",
		color = Color3.fromRGB(255, 200, 40),
		scale = 1.25,
		tint = 0.45,
		palette = { Color3.fromRGB(255, 210, 40), Color3.fromRGB(255, 120, 30), Color3.fromRGB(255, 80, 150) },
	},
	{
		key = "Epic",
		color = Color3.fromRGB(255, 90, 200),
		scale = 1.32,
		tint = 0.45,
		palette = { Color3.fromRGB(255, 70, 200), Color3.fromRGB(255, 60, 90), Color3.fromRGB(255, 150, 60) },
	},
	{
		key = "Legendary",
		color = Color3.fromRGB(190, 90, 255),
		scale = 1.4,
		tint = 0.5,
		palette = {
			Color3.fromRGB(160, 70, 255),
			Color3.fromRGB(255, 80, 210),
			Color3.fromRGB(70, 110, 255),
			Color3.fromRGB(50, 235, 225),
		},
	},
	{
		key = "Mythic",
		color = Color3.fromRGB(255, 80, 60),
		scale = 1.55,
		tint = 0.5,
		palette = {
			Color3.fromRGB(255, 60, 60),
			Color3.fromRGB(255, 200, 40),
			Color3.fromRGB(70, 230, 90),
			Color3.fromRGB(50, 200, 255),
			Color3.fromRGB(170, 80, 255),
		},
	},
}
Pets.COLOR_SECONDS = 1.3 -- temps pour passer d'une couleur de la palette à la suivante

-- Chances de chaque rang (sur 100), les mêmes dans toutes les salles : commun 45 %, peu commun 30 %, rare 14 %,
-- épique 7 %, légendaire 3,5 %, super rare 0,5 %.
Pets.ODDS = { 45, 30, 14, 7, 3.5, 0.5 }

-- luck : la chance du ticket (1 = aucune). Elle multiplie les chances de tout ce qui n'est pas commun.
function Pets.odds(_room: number, luck: number?): { number }
	local odds = {}
	for i, base in Pets.ODDS do
		odds[i] = base * if i > 1 then (luck or 1) else 1
	end
	return odds
end

-- Tire un rang (1 à 6) pour un œuf de cette salle.
function Pets.roll(random: Random, room: number, luck: number?): number
	local odds = Pets.odds(room, luck)
	local total = 0
	for _, weight in odds do
		total += weight
	end
	local pick = random:NextNumber(0, total)
	for i, weight in odds do
		pick -= weight
		if pick <= 0 then
			return i
		end
	end
	return 1
end

-- Tire la valeur cachée d'un familier dans le palier de sa rareté.
-- (Jeu « Monde » : on tire d'abord la NOTE, avec GRADE_ODDS, puis une valeur dans le quart du palier de cette note.)
function Pets.rollValue(random: Random, rarity: number): number
	local range = Pets.VALUE[math.clamp(rarity, 1, #Pets.VALUE)]
	local pick, grade = random:NextNumber(0, 100), #Pets.GRADES
	for index, odds in Pets.GRADE_ODDS do
		pick -= odds
		if pick <= 0 then
			grade = index
			break
		end
	end
	local along = (grade - 1 + random:NextNumber(0.04, 0.96)) / #Pets.GRADES
	return math.floor(range[1] + (range[2] - range[1]) * along + 0.5)
end

-- Où se place cette valeur (celle de la salle 1) dans le palier de son rang : 0 = tout en bas, 1 = tout en haut.
-- C'est ce qui donne la GROSSEUR de l'œuf, puis du familier (le joueur : « chaque animal donne entre tant et tant,
-- la taille de l'œuf serait par rapport à ça ; un gros œuf de renard donne le renard max pièces »).
function Pets.along(rarity: number, baseValue: number): number
	local range = Pets.VALUE[math.clamp(rarity, 1, #Pets.VALUE)]
	return math.clamp((baseValue - range[1]) / (range[2] - range[1]), 0, 1)
end
-- La même chose pour une place de l'enclos (œuf qui couve : sa valeur est déjà tirée, `b` ; familier : `v`).
function Pets.alongOf(spot): number
	if spot.v then
		local def = Pets.DEFS[spot.a]
		return Pets.along(spot.q, spot.v / Pets.roomFactor(def and def.room or 1))
	end
	return if spot.b then Pets.along(spot.q, spot.b) else 0.5
end

-- AU COMBAT (jeu « Monde ») : les dégâts par seconde et la vie d'un familier. Ils dépendent de son RANG (FIGHT_DMG,
-- FIGHT_HP : un rang de plus = environ deux fois plus fort), de sa place dans le palier de son rang (de -30 % à
-- +30 %), de sa ZONE (x FIGHT_ZONE par zone : à niveau égal, le même animal de la zone suivante est toujours plus
-- fort) et de son NIVEAU (+FIGHT_LEVEL par niveau, gagné avec l'XP des monstres).
-- Le familier du BOSS (rang 6) est un peu au-dessus du premier animal du monde suivant (5 x 100 = 500 de dégâts,
-- 45 x 100 = 4 500 de vie) : c'est lui qui aide à y entrer.
Pets.FIGHT_DMG = { 5, 10, 20, 40, 85, 600 }
Pets.FIGHT_HP = { 45, 90, 180, 360, 760, 5400 }
Pets.FIGHT_ZONE = 100
-- L'XP que demande un niveau dépend du rang de l'animal (comme l'XP que donnent les monstres de son camp) : monter
-- un cochon en battant des cochons prend autant de combats que monter un canard en battant des canards.
Pets.RANK_XP = { 1, 2.5, 6, 14, 32, 80 }
-- Chaque niveau multiplie la force par FIGHT_LEVEL : l'écart grandit à chaque niveau (niveau 10 : x 2,4 ; niveau
-- 20 : x 6 ; niveau 30 : x 16). Et chaque niveau demande XP_LEVEL fois plus d'XP que le précédent.
Pets.FIGHT_LEVEL = 1.1
Pets.XP_LEVEL = 1.3
local function fightFactor(spot): number
	local def = Pets.DEFS[spot.a]
	return (0.7 + 0.6 * Pets.alongOf(spot)) * Pets.FIGHT_ZONE ^ ((def and def.room or 1) - 1) * Pets.FIGHT_LEVEL ^ ((spot.lv or 1) - 1)
end
-- LA NOTE d'un familier : C, B, A ou S selon sa TAILLE (sa place dans le palier de son animal), pas selon son rang.
-- Un petit canard est C, un gros canard est S ; un petit cochon est C lui aussi. GRADE_ODDS : la chance de chaque
-- note quand un œuf est trouvé (sur 100) ; elle est écrite sur le panneau de chaque camp.
Pets.GRADES = { "C", "B", "A", "S" }
-- (Son retour : « 5 % de S c'est beaucoup trop, ça doit être supra rare, genre 0,1 % » par monstre battu. Avec la
-- chance d'œuf du canard (25 %), 0,4 % de S par œuf = 0,1 % par canard battu : un S tous les 1 000 canards.)
Pets.GRADE_ODDS = { 70, 25, 4.6, 0.4 }
function Pets.gradeOf(spot): string
	return Pets.GRADES[math.clamp(math.floor(Pets.alongOf(spot) * #Pets.GRADES) + 1, 1, #Pets.GRADES)]
end
function Pets.damageOf(spot): number
	return math.max(1, math.floor(Pets.FIGHT_DMG[math.clamp(spot.q, 1, 6)] * fightFactor(spot) + 0.5))
end
function Pets.healthOf(spot): number
	return math.max(10, math.floor(Pets.FIGHT_HP[math.clamp(spot.q, 1, 6)] * fightFactor(spot) + 0.5))
end
-- XP gagnée dans son niveau, et XP qu'il faut pour le suivant (x FIGHT_ZONE par zone, comme l'XP des monstres... en
-- moins vite : un familier d'une zone lointaine monte un peu plus lentement).
function Pets.xpNeed(spot): number
	local def = Pets.DEFS[spot.a]
	local rank = math.clamp(spot.q or (def and def.rank) or 1, 1, 6)
	return math.floor(60 * Pets.XP_LEVEL ^ ((spot.lv or 1) - 1) * Pets.RANK_XP[rank] * 10 ^ ((def and def.room or 1) - 1))
end
-- Toute l'XP qu'un familier a gagnée depuis sa naissance (celle de ses niveaux passés, plus celle du niveau en cours).
function Pets.totalXp(spot): number
	local total = spot.xp or 0
	for level = 1, (spot.lv or 1) - 1 do
		total += Pets.xpNeed({ a = spot.a, q = spot.q, lv = level })
	end
	return total
end
-- NOURRIR : la part de l'XP du familier mangé que reçoit celui qui le mange.
Pets.FEED = 0.75

-- Temps de couvaison d'un œuf, en secondes.
function Pets.hatchSeconds(room: number, rarity: number): number
	return math.floor(Pets.HATCH[math.clamp(rarity, 1, #Pets.HATCH)] * (0.5 + room / 10) + 0.5)
end

-- Grosseur de cet animal par rapport aux autres.
function Pets.size(name: string): number
	local def = Pets.DEFS[name]
	return def and def.size or 1
end

-- Pièces par seconde d'un familier de cette valeur.
function Pets.incomeOf(name: string, value: number): number
	local def = Pets.DEFS[name]
	return if def then value / Pets.VALUE_PER_COIN * def.income else 0
end

-- Pièces reçues en vendant un familier (ce qu'il rapporte en 20 secondes : un canard, 4 à 10 pièces).
function Pets.sellPrice(name: string, value: number): number
	return math.max(1, math.floor(Pets.incomeOf(name, value) * 20 + 0.5))
end

-- Prix de la place suivante quand on en a `places` (nil au maximum).
function Pets.spotPrice(places: number): number?
	if places >= Pets.SPOTS_MAX then
		return nil
	end
	return Pets.SPOT_PRICES[math.max(1, places - Pets.SPOTS_FREE + 1)]
end

-- LES PLACES DE L'ENCLOS : { [numéro] = { a = animal, q = rareté, t = heure d'éclosion } pour un œuf qui couve,
-- ou { a = animal, q = rareté, v = valeur } pour un familier }.
-- Pièces par seconde de tout un enclos.
function Pets.income(spots): number
	local total = 0
	for _, spot in spots do
		if spot.v then
			total += Pets.incomeOf(spot.a, spot.v)
		end
	end
	return total
end

-- Nombre de familiers (éclos) et d'œufs qui couvent dans un enclos.
function Pets.count(spots): (number, number)
	local pets, eggs = 0, 0
	for _, spot in spots do
		if spot.v then
			pets += 1
		else
			eggs += 1
		end
	end
	return pets, eggs
end

-- Les places en texte, pour les envoyer à l'écran des joueurs : pour chaque place occupée,
-- « numéro:animal:rareté:v ou t:valeur ou heure d'éclosion:x:z:durée » (x, z = où l'œuf est posé dans l'enclos, en
-- dixièmes de stud ; durée = temps total de couvaison, pour la barre du panneau ; pour un familier, ce nombre est
-- son bonus de chance en %), puis « :grosseur » = sa place dans le palier de son rang, de 0 à 100 (Pets.alongOf).
function Pets.encode(spots): string
	local parts = {}
	for index = 1, Pets.SPOTS_MAX do
		local spot = spots[tostring(index)]
		if spot then
			table.insert(parts, string.format("%d:%s:%d:%s:%d:%d:%d:%d:%d:%d:%d", index, spot.a, spot.q, if spot.v then "v" else "t", spot.v or spot.t, math.round((spot.x or 0) * 10), math.round((spot.z or 0) * 10), if spot.v then Pets.luckOf(spot) else spot.d or 0, math.floor(Pets.alongOf(spot) * 100 + 0.5), spot.lv or 1, spot.xp or 0))
		end
	end
	return table.concat(parts, ",")
end

function Pets.decode(text: string?)
	local spots = {}
	-- (Le dernier nombre : le niveau du familier.)
	for index, name, rarity, kind, number, x, z, duration, size, level, xp in string.gmatch(text or "", "(%d+):(%a+):(%d):([vt]):(%d+):(-?%d+):(-?%d+):(%d+):(%d+):(%d+):(%d+)") do
		local spot = { a = name, q = tonumber(rarity), x = tonumber(x) / 10, z = tonumber(z) / 10, d = tonumber(duration), s = tonumber(size) / 100, lv = tonumber(level), xp = tonumber(xp) }
		spot[kind] = tonumber(number)
		if kind == "v" then
			spot.l, spot.d = spot.d, nil
		end
		spots[tostring(index)] = spot
	end
	return spots
end

-- MODÈLES DE SECOURS pour les anciennes places sans assets/pets --------------------------------------------------
local function piece(model: Model, name: string, size: Vector3, offset: CFrame | Vector3, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = if typeof(offset) == "Vector3" then CFrame.new(offset) else offset
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Shape = shape or Enum.PartType.Block
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	return part
end

local BLACK = Color3.fromRGB(20, 20, 26)
local WHITE = Color3.fromRGB(250, 250, 250)

local function eyes(model: Model, x: number, y: number, z: number, size: number)
	for _, side in { -1, 1 } do
		piece(model, "Eye", Vector3.new(size, size, 0.15), Vector3.new(side * x, y, z), WHITE)
		piece(model, "Pupil", Vector3.new(size * 0.5, size * 0.5, 0.16), Vector3.new(side * x, y, z - 0.03), BLACK)
	end
end

-- Tous les modèles regardent vers -Z (l'avant d'un personnage Roblox).
local BUILDERS = {
	Dragon = function(model: Model)
		local red, dark = Color3.fromRGB(230, 70, 40), Color3.fromRGB(150, 36, 24)
		piece(model, "Body", Vector3.new(1.8, 1.4, 3), Vector3.new(0, 0, 0), red)
		piece(model, "Belly", Vector3.new(1.4, 0.3, 2.4), Vector3.new(0, -0.6, 0), Color3.fromRGB(255, 190, 80))
		piece(model, "Head", Vector3.new(1.4, 1.2, 1.4), Vector3.new(0, 0.6, -2), red)
		piece(model, "Snout", Vector3.new(0.9, 0.6, 0.7), Vector3.new(0, 0.35, -2.9), dark)
		eyes(model, 0.4, 0.85, -2.72, 0.4)
		for _, side in { -1, 1 } do
			piece(model, "Horn", Vector3.new(0.25, 0.7, 0.25), CFrame.new(side * 0.45, 1.45, -1.7) * CFrame.Angles(math.rad(25), 0, 0), Color3.fromRGB(255, 225, 150))
			piece(model, "Wing", Vector3.new(2.6, 0.15, 1.9), CFrame.new(side * 2, 0.7, 0.1) * CFrame.Angles(0, 0, math.rad(side * 18)), dark)
		end
		piece(model, "Tail", Vector3.new(0.7, 0.6, 1.8), CFrame.new(0, 0.1, 2.2) * CFrame.Angles(math.rad(-15), 0, 0), red)
		piece(model, "Flame", Vector3.new(0.6, 0.6, 0.6), Vector3.new(0, 0.5, 3.1), Color3.fromRGB(255, 150, 30), Enum.Material.Neon, Enum.PartType.Ball)
	end,
	Rock = function(model: Model)
		local stone = Color3.fromRGB(96, 90, 92)
		piece(model, "Body", Vector3.new(2.4, 2.4, 2.4), Vector3.new(0, 0, 0), stone, Enum.Material.Slate, Enum.PartType.Ball)
		for i, spot in { Vector3.new(0.7, 0.8, 0.5), Vector3.new(-0.9, -0.2, 0.6), Vector3.new(0.2, -0.9, -0.5), Vector3.new(-0.5, 0.9, -0.4) } do
			piece(model, "Ember" .. i, Vector3.new(0.5, 0.5, 0.5), spot, Color3.fromRGB(255, 130, 30), Enum.Material.Neon, Enum.PartType.Ball)
		end
		eyes(model, 0.45, 0.25, -1.15, 0.45)
	end,
	Rabbit = function(model: Model)
		piece(model, "Body", Vector3.new(1.5, 1.4, 1.9), Vector3.new(0, 0, 0), WHITE)
		piece(model, "Head", Vector3.new(1.3, 1.2, 1.2), Vector3.new(0, 0.9, -0.9), WHITE)
		for _, side in { -1, 1 } do
			piece(model, "Ear", Vector3.new(0.35, 1.5, 0.25), CFrame.new(side * 0.35, 2.1, -0.8) * CFrame.Angles(0, 0, math.rad(-side * 8)), WHITE)
			piece(model, "InnerEar", Vector3.new(0.18, 1.1, 0.26), CFrame.new(side * 0.35, 2.1, -0.82) * CFrame.Angles(0, 0, math.rad(-side * 8)), Color3.fromRGB(255, 160, 190))
			piece(model, "Foot", Vector3.new(0.5, 0.3, 0.9), Vector3.new(side * 0.5, -0.8, -0.3), WHITE)
		end
		eyes(model, 0.32, 1.05, -1.52, 0.3)
		piece(model, "Nose", Vector3.new(0.22, 0.18, 0.15), Vector3.new(0, 0.8, -1.55), Color3.fromRGB(255, 120, 160))
		piece(model, "Tail", Vector3.new(0.6, 0.6, 0.6), Vector3.new(0, 0.1, 1.1), WHITE, nil, Enum.PartType.Ball)
	end,
	Golem = function(model: Model)
		local stone, moss = Color3.fromRGB(120, 124, 132), Color3.fromRGB(90, 170, 90)
		piece(model, "Body", Vector3.new(2, 2, 1.4), Vector3.new(0, 0, 0), stone, Enum.Material.Slate)
		piece(model, "Head", Vector3.new(1.2, 1, 1.1), Vector3.new(0, 1.5, -0.1), stone, Enum.Material.Slate)
		piece(model, "Moss", Vector3.new(1.3, 0.25, 1.2), Vector3.new(0, 2.05, -0.1), moss)
		for _, side in { -1, 1 } do
			piece(model, "Arm", Vector3.new(0.8, 2, 0.9), Vector3.new(side * 1.5, -0.2, 0), stone, Enum.Material.Slate)
			piece(model, "Fist", Vector3.new(1, 0.8, 1.1), Vector3.new(side * 1.5, -1.4, 0), Color3.fromRGB(96, 100, 108), Enum.Material.Slate)
			piece(model, "Leg", Vector3.new(0.8, 0.9, 0.9), Vector3.new(side * 0.55, -1.4, 0), stone, Enum.Material.Slate)
		end
		for _, side in { -1, 1 } do
			piece(model, "Eye", Vector3.new(0.3, 0.25, 0.15), Vector3.new(side * 0.3, 1.55, -0.68), Color3.fromRGB(90, 255, 200), Enum.Material.Neon)
		end
	end,
	Owl = function(model: Model)
		local brown, cream = Color3.fromRGB(140, 96, 60), Color3.fromRGB(240, 220, 180)
		piece(model, "Body", Vector3.new(1.9, 2.2, 1.7), Vector3.new(0, 0, 0), brown)
		piece(model, "Chest", Vector3.new(1.3, 1.3, 0.2), Vector3.new(0, -0.3, -0.82), cream)
		for _, side in { -1, 1 } do
			piece(model, "Tuft", Vector3.new(0.4, 0.6, 0.4), CFrame.new(side * 0.7, 1.3, 0) * CFrame.Angles(0, 0, math.rad(-side * 20)), brown)
			piece(model, "Wing", Vector3.new(0.3, 1.5, 1.2), CFrame.new(side * 1.1, -0.1, 0.1) * CFrame.Angles(0, 0, math.rad(side * 10)), Color3.fromRGB(110, 74, 46))
			piece(model, "Foot", Vector3.new(0.5, 0.2, 0.6), Vector3.new(side * 0.45, -1.2, -0.3), Color3.fromRGB(255, 180, 40))
		end
		eyes(model, 0.45, 0.55, -0.87, 0.7)
		piece(model, "Beak", Vector3.new(0.3, 0.35, 0.3), Vector3.new(0, 0.15, -0.95), Color3.fromRGB(255, 180, 40))
	end,
}

-- Pièces qui gardent leur couleur quelle que soit la rareté (yeux, braises...).
local KEEP_COLOR = { Eye = true, Pupil = true, Nose = true, Beak = true }

-- Couleur à la position `position` d'une palette (0 = la 1re couleur, 1 = la 2e...) : glisse de l'une à l'autre.
local function along(palette: { Color3 }, position: number): Color3
	position %= #palette
	local index = math.floor(position)
	return palette[index + 1]:Lerp(palette[(index + 1) % #palette + 1], position - index)
end

-- L'image du dégradé d'une rareté, fabriquée par le jeu lui-même (aucune image à mettre en ligne) : des bandes
-- ondulées de toutes les couleurs de la palette. Elle est faite une seule fois et sert à tous les animaux de
-- cette rareté. Si Roblox refuse de créer l'image (réglage du jeu, vieil appareil), renvoie nil : l'animal reçoit
-- alors seulement un voile de couleur.
local gradients = {}
function gradient(rarity: number): any
	if gradients[rarity] ~= nil then
		return gradients[rarity] or nil
	end
	local palette = Pets.RARITIES[rarity].palette
	local ok, content = pcall(function()
		local size = 64
		local image = AssetService:CreateEditableImage({ Size = Vector2.new(size, size) })
		local pixels = buffer.create(size * size * 4)
		for y = 0, size - 1 do
			for x = 0, size - 1 do
				local u, v = x / size, y / size
				local wave = 0.25 * math.sin(v * math.pi * 4) + 0.25 * math.sin(u * math.pi * 6)
				local color = along(palette, (u * 2 + v * 2 + wave) * #palette)
				local offset = (y * size + x) * 4
				buffer.writeu8(pixels, offset, math.floor(color.R * 255))
				buffer.writeu8(pixels, offset + 1, math.floor(color.G * 255))
				buffer.writeu8(pixels, offset + 2, math.floor(color.B * 255))
				buffer.writeu8(pixels, offset + 3, 255)
			end
		end
		image:WritePixelsBuffer(Vector2.zero, Vector2.new(size, size), pixels)
		return Content.fromObject(image)
	end)
	if not ok then
		warn("[Survive] dégradé des animaux impossible : " .. tostring(content))
	end
	gradients[rarity] = if ok then content else false
	return if ok then content else nil
end

-- Construit le modèle d'un animal (ancré, sans collision). Sa pièce principale s'appelle « Body » (« RigRoot »
-- pour un animal des collections).
-- display : pour l'enclos (tous les animaux à la même grosseur, sans lumière).
function Pets.build(name: string, rarity: number, display: boolean?): Model
	local model = PetModels.build(name)
	if not model then
		model = Instance.new("Model")
		model.Name = name
		local builder = BUILDERS[name] or BUILDERS.Rock
		builder(model)
	end
	local starter = model:GetAttribute("Starter") == true
	local body = (model:FindFirstChild("Body") or model:FindFirstChild("RigRoot")) :: BasePart
	model.PrimaryPart = body

	local info = Pets.RARITIES[math.clamp(rarity, 1, #Pets.RARITIES)]
	if info.palette then
		-- 1) Le corps : le dégradé de la palette remplace la texture de chaque maillage ; les pièces simples
		--    (blocs) prennent chacune une couleur de la palette.
		local content = gradient(rarity)
		local count = 0
		for _, part in model:GetDescendants() do
			if part:IsA("MeshPart") and content then
				for _, child in part:GetChildren() do
					if child:IsA("SurfaceAppearance") then
						child:Destroy()
					end
				end
				part.TextureContent = content
				part.Color = Color3.new(1, 1, 1)
				part.Material = Enum.Material.SmoothPlastic
			elseif part:IsA("BasePart") and part ~= body and not KEEP_COLOR[part.Name] and not starter then
				count += 1
				part.Color = info.palette[count % #info.palette + 1]
			end
		end
		-- 2) Si le dégradé n'a pas pu être peint : un voile de la couleur de la rareté à la place. (Roblox n'affiche
		--    qu'une trentaine de voiles à la fois : pas dans les enclos.)
		if not content and not display and not starter then
			local tint = Instance.new("Highlight")
			tint.Name = "Tint"
			tint.FillTransparency = 1 - info.tint
			tint.OutlineTransparency = 0
			tint.DepthMode = Enum.HighlightDepthMode.Occluded
			tint.Parent = model
		end
		-- 3) Un peu de lumière de la couleur de la rareté, pour celui qui suit le joueur.
		if not display then
			local light = Instance.new("PointLight")
			light.Name = "RarityLight"
			light.Range = 5 + rarity
			light.Brightness = 0.5
			light.Parent = body
		end
		model:SetAttribute("Rarity", rarity)
	end
	if rarity >= 5 then
		local sparkles = Instance.new("Sparkles")
		sparkles.Parent = body
	end
	-- La taille de base du rig importé n'est pas forcément 1 ; mêmes tailles relatives et mêmes pouvoirs.
	model:ScaleTo((model:GetAttribute("VisualBaseScale") or 1) * info.scale * if display then 1 else Pets.size(name))
	Pets.shimmer(model, 0)
	return model
end

-- Couleur d'une palette à l'instant t (décalé de `offset` couleurs).
local function blend(palette: { Color3 }, t: number, offset: number): Color3
	return along(palette, t / Pets.COLOR_SECONDS + offset)
end

-- À appeler à chaque image pour un animal rare ou mieux : fait tourner les couleurs du contour et de
-- la lumière (le dégradé du corps, lui, ne bouge pas).
function Pets.shimmer(model: Model, t: number)
	local info = Pets.RARITIES[model:GetAttribute("Rarity") or 1]
	local palette = info and info.palette
	if not palette then
		return
	end
	local first, second, third = blend(palette, t, 0), blend(palette, t, 1), blend(palette, t, 2)
	for _, child in model:GetChildren() do
		if child.Name == "Tint" then
			child.FillColor = first
			child.OutlineColor = third
		end
	end
	local body = model.PrimaryPart
	local light = body and body:FindFirstChild("RarityLight")
	if light then
		light.Color = first
	end
	local sparkles = body and body:FindFirstChildOfClass("Sparkles")
	if sparkles then
		sparkles.SparkleColor = second
	end
end

return Pets

-- TOUS LES RÉGLAGES DU ZOO (prix, durées, animaux, plan du parc). Le reste du code ne contient presque aucun chiffre.
-- Les demandes du créateur (14/10/2026) :
--   « gérer un zoo, acheter l'espace tigre, l'espace lion, agrandir le zoo, le gérer vraiment à la main au début avec
--   peu d'animaux, un budget de départ, gérer beaucoup de choses soi-même : médical, nourrir, entretenir le parc, et
--   petit à petit avec l'argent prendre des employés qui le font, un peu comme Supermarket Simulator » ;
--   « réaliste, pas de dino » ; « au début faudra faire nous-mêmes l'entrée des clients, scanner les tickets » ;
--   « tu commences avec juste la mini-ferme (chèvre, cochon, poule mélangés), 2 animaux de chaque espèce, mâle et
--   femelle, et ils se reproduiront, et t'as de quoi acheter un spot au jour 1, un truc cerf / biche » ;
--   le décor dans le style de son image (Planet Zoo : verdure, rochers, eau, bâtiments en bois sombre) ; « on mettra
--   espaces à acheter, café, bar, un vrai zoo en endgame ».
local Config = {}

-- L'ARGENT ---------------------------------------------------------------------------------------------------------
Config.START_MONEY = 1500 -- assez pour l'espace des cerfs (300) et un cerf et une biche (860) dès le jour 1
Config.START_STARS = 2.5 -- la note du zoo au départ (de 0 à 5 étoiles)

-- LA JOURNÉE -------------------------------------------------------------------------------------------------------
-- Le zoo ouvre à 9 h et ferme à 18 h. Une journée d'ouverture dure DAY_SECONDS secondes de vrai temps.
Config.OPEN_HOUR = 9
Config.CLOSE_HOUR = 18
Config.LAST_ARRIVAL = 16.5 -- plus aucun visiteur n'arrive après 16 h 30
Config.DAY_SECONDS = 600 -- 10 minutes de 9 h à 18 h (le zoo est grand : sa demande du 14/10, des parcs bien plus grands)
Config.EVENING_MAX = 40 -- secondes, après 18 h, pour que les derniers visiteurs sortent (puis le bilan)
Config.NIGHT_AUTO = 45 -- le jour suivant commence tout seul après ce temps de nuit (ou avant, avec le bouton)

-- LES VISITEURS ----------------------------------------------------------------------------------------------------
Config.VISITORS = {
	base = 16, -- par jour, au minimum
	perSpace = 7, -- en plus, par espace ouvert (la mini-ferme compte)
	perStar = 5, -- en plus, par étoile de la note
	max = 140,
	inside = 32, -- au plus dans le zoo en même temps (les autres attendent dehors)
	walk = 8, -- vitesse de marche
	watch = { 5, 9 }, -- secondes devant un espace ouvert
	patience = 60, -- secondes d'attente au guichet avant de repartir fâché (le trajet depuis le bus compte)
	trash = 0.35, -- un visiteur sur trois jette un papier par terre
	kids = 0.3, -- part d'enfants
}
-- Le prix du billet monte avec la note.
function Config.ticketPrice(stars: number): number
	return math.floor(8 + stars * 1.6 + 0.5)
end
function Config.visitorsPerDay(spaces: number, stars: number): number
	local v = Config.VISITORS
	return math.min(v.max, math.floor(v.base + v.perSpace * spaces + v.perStar * stars))
end

local v3 = Vector3.new

-- LA NOURRITURE DES ANIMAUX (prise à la réserve : une unité de stock remplit une mangeoire) ------------------------------
Config.FOODS = {
	hay = { fr = "Foin", color = Color3.fromRGB(222, 196, 96) },
	grain = { fr = "Grain", color = Color3.fromRGB(214, 168, 92) },
	meat = { fr = "Viande", color = Color3.fromRGB(176, 62, 54) },
}
Config.FOOD_ORDER = { "hay", "grain", "meat" }
Config.TROUGH_MAX = 100 -- une mangeoire pleine

-- LE STOCK ET LES COMMANDES (sa demande du 15/10, « 1 » : comme Supermarket Simulator). La réserve n'est plus infinie :
-- on commande sur l'ordinateur de la réserve, le camion livre des cartons devant la réserve de l'entrée, on les porte et
-- on les range. pack : unités dans un carton ; price : le prix d'un carton ; cap : ce que les réserves peuvent contenir ;
-- kind : food (mangeoires), med (soins), shop (pour les stands des visiteurs).
Config.STOCK = {
	hay = { fr = "Foin", pack = 10, price = 40, cap = 60, kind = "food", color = Color3.fromRGB(222, 196, 96) },
	grain = { fr = "Grain", pack = 10, price = 30, cap = 60, kind = "food", color = Color3.fromRGB(214, 168, 92) },
	meat = { fr = "Viande", pack = 6, price = 60, cap = 36, kind = "food", color = Color3.fromRGB(176, 62, 54) },
	syrup = { fr = "Sirop", pack = 4, price = 40, cap = 16, kind = "med", color = Color3.fromRGB(230, 120, 60) },
	vermi = { fr = "Vermifuge", pack = 4, price = 50, cap = 16, kind = "med", color = Color3.fromRGB(110, 170, 90) },
	bandage = { fr = "Bandage", pack = 4, price = 30, cap = 16, kind = "med", color = Color3.fromRGB(240, 236, 226) },
	drinks = { fr = "Boissons", pack = 24, price = 36, cap = 96, kind = "shop", color = Color3.fromRGB(70, 150, 220) },
	icecream = { fr = "Glaces", pack = 20, price = 40, cap = 80, kind = "shop", color = Color3.fromRGB(250, 180, 210) },
	fries = { fr = "Frites", pack = 20, price = 40, cap = 80, kind = "shop", color = Color3.fromRGB(250, 200, 70) },
	coffee = { fr = "Café et gâteaux", pack = 20, price = 50, cap = 80, kind = "shop", color = Color3.fromRGB(140, 96, 64) },
	souvenirs = { fr = "Souvenirs", pack = 10, price = 60, cap = 40, kind = "shop", color = Color3.fromRGB(200, 90, 160) },
}
Config.STOCK_ORDER = { "hay", "grain", "meat", "syrup", "vermi", "bandage", "drinks", "icecream", "fries", "coffee", "souvenirs" }
Config.START_STOCK = { hay = 20, grain = 20, meat = 6, syrup = 2, vermi = 2, bandage = 2 }
Config.DELIVERY_SECONDS = 25 -- le temps que met le camion
Config.BULK = { packs = 5, discount = 0.1 } -- 10 % de moins à partir de 5 cartons du même produit

-- LES MALADIES (sa demande du 15/10, « 4 ») : on examine l'animal malade pour savoir ce qu'il a, puis on lui donne le
-- bon médicament. hint : ce qu'on voit avant de l'examiner.
Config.DISEASES = {
	cold = { fr = "Rhume", med = "syrup", hint = "il éternue" },
	worms = { fr = "Parasites", med = "vermi", hint = "il maigrit" },
	wound = { fr = "Blessure", med = "bandage", hint = "il boite" },
}
Config.DISEASE_ORDER = { "cold", "worms", "wound" }

-- LES JEUX DES ANIMAUX (« 4 ») : chaque espace peut en recevoir (Config.HABITATS.toys) ; chacun rend les animaux plus
-- heureux (jusqu'à 3).
Config.TOYS = {
	salt = { fr = "Pierre à lécher", price = 60 },
	brush = { fr = "Brosse à gratter", price = 80 },
	ball = { fr = "Ballon géant", price = 100 },
	log = { fr = "Tronc à griffer", price = 140 },
	platform = { fr = "Plateforme en bois", price = 220 },
	ropes = { fr = "Cordes et hamac", price = 200 },
	pool = { fr = "Bassin pour se rafraîchir", price = 260 },
}

-- LES STANDS ET LES TOILETTES (sa demande du 15/10, « 2 » : les visiteurs ont faim, soif, envie d'aller aux toilettes).
-- On les construit sur des emplacements le long des allées (Config.SHOP_SPOTS). Un stand vend un produit du stock
-- (à lui apporter en cartons) ; les toilettes se salissent. price : la construction ; sale : le prix de vente au départ
-- (on le change dans la fenêtre Prix) ; fair : le prix que les visiteurs trouvent normal ; needs : ce que ça calme.
Config.SHOP_TYPES = {
	drinks = { fr = "Buvette", product = "drinks", price = 1200, sale = 2, fair = 2, cost = 1.5, needs = { thirst = 100 }, color = Color3.fromRGB(70, 150, 220) },
	icecream = { fr = "Glacier", product = "icecream", price = 1500, sale = 3, fair = 3, cost = 2, needs = { hunger = 35, thirst = 35 }, color = Color3.fromRGB(240, 150, 190) },
	fries = { fr = "Friterie", product = "fries", price = 1800, sale = 4, fair = 4, cost = 2, needs = { hunger = 100 }, color = Color3.fromRGB(230, 180, 50) },
	coffee = { fr = "Café", product = "coffee", price = 3000, sale = 5, fair = 5, cost = 2.5, needs = { hunger = 60, thirst = 60 }, color = Color3.fromRGB(140, 96, 64) },
	toilets = { fr = "Toilettes", price = 1000, needs = { bladder = 100 }, color = Color3.fromRGB(110, 170, 200) },
	souvenirs = { fr = "Boutique de souvenirs", product = "souvenirs", price = 4000, sale = 9, fair = 9, cost = 6, needs = {}, color = Color3.fromRGB(200, 90, 160) },
}
Config.SHOP_ORDER = { "drinks", "icecream", "fries", "coffee", "toilets", "souvenirs" }
-- Les emplacements : au bord des allées ; facing : vers l'allée.
Config.SHOP_SPOTS = {
	{ id = "k1", center = v3(-54, 0, 78), facing = v3(0, 0, 1) },
	{ id = "k2", center = v3(54, 0, 78), facing = v3(0, 0, 1) },
	{ id = "k3", center = v3(-150, 0, 90), facing = v3(0, 0, 1) },
	{ id = "k4", center = v3(150, 0, 90), facing = v3(0, 0, 1) },
	{ id = "k5", center = v3(-194, 0, 30), facing = v3(-1, 0, 0) },
	{ id = "k6", center = v3(194, 0, 30), facing = v3(1, 0, 0) },
	{ id = "k7", center = v3(-70, 0, -488), facing = v3(0, 0, 1) },
	{ id = "k8", center = v3(70, 0, -488), facing = v3(0, 0, 1) },
	{ id = "k9", center = v3(-238, 0, -152), facing = v3(1, 0, 0) },
	{ id = "k10", center = v3(238, 0, -152), facing = v3(-1, 0, 0) },
}
Config.SHOP_SIZE = Vector2.new(14, 10) -- largeur (le long de l'allée), profondeur
Config.SHOP_STOCK = 30 -- un stand contient au plus 30 produits
-- Les besoins des visiteurs (0 à 100) : ce qu'ils gagnent par seconde ; au-dessus de 70, ils cherchent un stand.
Config.VISITOR_NEEDS = { hunger = 0.22, thirst = 0.28, bladder = 0.2, urgent = 70 }
Config.BIN_MAX = 20 -- une poubelle pleine déborde (les papiers tombent par terre)

-- LES PRIX (« 2 ») : le joueur fixe le prix du billet et de chaque produit. Les visiteurs comparent au prix normal :
-- plus c'est cher, moins ils achètent (et ils râlent).
Config.PRICE_LIMITS = { ticket = { 1, 200 }, shop = { 1, 60 } }
function Config.buyChance(price: number, fair: number): number
	local ratio = price / math.max(fair, 0.1)
	if ratio <= 1 then
		return 1
	elseif ratio >= 1.8 then
		return 0.05
	end
	return 1 - (ratio - 1) / 0.8 * 0.95
end

-- LA MÉTÉO ET LES ÉVÉNEMENTS (« 5 ») : tirés chaque matin.
Config.WEATHER = {
	{ id = "sun", fr = "Soleil", icon = "☀", chance = 0.5, visitors = 1.1 },
	{ id = "clouds", fr = "Nuageux", icon = "☁", chance = 0.2, visitors = 1 },
	{ id = "rain", fr = "Pluie", icon = "☂", chance = 0.15, visitors = 0.7, about = "Moins de visiteurs aujourd'hui." },
	{ id = "heat", fr = "Canicule", icon = "♨", chance = 0.1, visitors = 1, thirst = 2, troughs = 1.3, about = "Les visiteurs ont très soif, les animaux mangent plus." },
	{ id = "storm", fr = "Tempête", icon = "⚡", chance = 0.05, visitors = 0.5, trash = 12, about = "Le vent a renversé des poubelles !" },
}
Config.EVENTS = {
	{ id = "school", fr = "Sortie scolaire", chance = 0.15, visitors = 1.4, kids = 0.75, about = "Beaucoup d'enfants aujourd'hui (et beaucoup de papiers) !" },
	{ id = "inspection", fr = "Inspection sanitaire", chance = 0.12, hour = 13, about = "Un inspecteur visite le zoo cet après-midi : tout doit être propre !" },
	{ id = "journalist", fr = "Journaliste", chance = 0.1, hour = 11, about = "Un journaliste visite le zoo : sa note compte pour 10 visiteurs !" },
}

-- LA VIE DES ANIMAUX (« 4 ») : combien de jours ils vivent (vieux à 80 %), et les jours d'attente d'une femelle enceinte
-- (gestation = repro).
Config.LIFE = {
	Rooster = 30, Goat = 40, Pig = 40, Sheep = 40, Deer = 50, Boar = 50, Capybara = 45, Wolf = 55, Lynx = 55, Hyena = 55,
	Crocodile = 90, Bear = 70, Buffalo = 60, Cheetah = 55, Gorilla = 80, Jaguar = 60, Tiger = 65, Rhino = 85, Lion = 60,
	Elephant = 120, Horse = 60, Duck = 30, Ram = 45,
}

-- LES BESOINS DES ANIMAUX ------------------------------------------------------------------------------------------
Config.NEEDS = {
	hungerRise = 14, -- faim gagnée par heure de jeu quand la mangeoire est vide (100 = affamé)
	hungerFall = 40, -- faim perdue par heure quand il mange
	poopMax = 12, -- crottes au plus dans un espace
	sickChance = 0.06, -- chance par jour de tomber malade (plus si sale ou affamé)
	sickDirty = 0.08,
	sickHungry = 0.1,
	sickDays = 1.5, -- un animal malade pas soigné au bout de ce temps est emmené par les services vétérinaires
	happyToBreed = 60, -- bonheur minimum pour avoir des petits
}

-- LES ANIMAUX ------------------------------------------------------------------------------------------------------
-- m / f : le nom du mâle et de la femelle ; group : le nom de l'espèce au pluriel ; food : ce qu'il mange ;
-- height : sa hauteur adulte (le joueur mesure 5 ; un peu plus grand que nature, pour bien les voir) ; speed : sa marche ; eat : nourriture mangée par heure de jeu ;
-- poop : heures entre deux crottes ; repro : jours entre deux naissances (un couple adulte, heureux) ; litter : petits
-- par naissance ; grow : jours pour devenir adulte ; sell : prix de vente d'un adulte ; femaleHide / maleHide : les
-- pièces du modèle cachées (les cornes du bouc, la crête du coq) ; antlers : bois du cerf ajoutés au mâle.
Config.SPECIES = {
	Goat = { m = "Bouc", f = "Chèvre", baby = "Chevreau", group = "Chèvres", food = "hay", height = 4.2, speed = 3.2, eat = 3, poop = 3, repro = 2, litter = { 1, 2 }, grow = 2, sell = 80, femaleHide = { "HornBaseL", "HornBaseR" } },
	Pig = { m = "Cochon", f = "Truie", baby = "Porcelet", group = "Cochons", food = "grain", height = 3.6, speed = 2.6, eat = 3, poop = 2.5, repro = 2, litter = { 1, 3 }, grow = 2, sell = 90 },
	Rooster = { m = "Coq", f = "Poule", baby = "Poussin", group = "Poules", food = "grain", height = 2.2, speed = 2.4, eat = 1, poop = 4, repro = 1, litter = { 1, 2 }, grow = 1, sell = 20, femaleHide = { "Wattle", "Comb3", "Comb2" }, femaleScale = 0.85 },
	Deer = { m = "Cerf", f = "Biche", baby = "Faon", group = "Cerfs", food = "hay", height = 6, speed = 4, eat = 4, poop = 3, repro = 3, litter = { 1, 1 }, grow = 3, sell = 260, antlers = true, femaleScale = 0.9 },
	Boar = { m = "Sanglier", f = "Laie", baby = "Marcassin", group = "Sangliers", food = "grain", height = 3.9, speed = 3.2, eat = 4, poop = 2.5, repro = 3, litter = { 1, 3 }, grow = 3, sell = 300, femaleHide = { "TuskBase1" } },
	Capybara = { m = "Capybara", f = "Capybara", baby = "Petit capybara", group = "Capybaras", food = "hay", height = 3.1, speed = 2.2, eat = 3, poop = 3, repro = 3, litter = { 1, 2 }, grow = 3, sell = 420 },
	Wolf = { m = "Loup", f = "Louve", baby = "Louveteau", group = "Loups", food = "meat", height = 4.3, speed = 4.5, eat = 3, poop = 3, repro = 4, litter = { 1, 2 }, grow = 3, sell = 700, femaleScale = 0.92 },
	Crocodile = { m = "Crocodile", f = "Crocodile", baby = "Bébé crocodile", group = "Crocodiles", food = "meat", height = 2.6, speed = 1.6, eat = 3, poop = 4, repro = 5, litter = { 1, 2 }, grow = 4, sell = 1000 },
	Bear = { m = "Ours", f = "Ourse", baby = "Ourson", group = "Ours", food = "meat", height = 7.2, speed = 3, eat = 6, poop = 2.5, repro = 5, litter = { 1, 2 }, grow = 4, sell = 1500, femaleScale = 0.9 },
	Cheetah = { m = "Guépard", f = "Guépard femelle", baby = "Bébé guépard", group = "Guépards", food = "meat", height = 4.4, speed = 5, eat = 4, poop = 3, repro = 5, litter = { 1, 2 }, grow = 4, sell = 2000 },
	Gorilla = { m = "Gorille", f = "Gorille femelle", baby = "Bébé gorille", group = "Gorilles", food = "hay", height = 6.8, speed = 2.6, eat = 5, poop = 3, repro = 6, litter = { 1, 1 }, grow = 5, sell = 2600, femaleScale = 0.85 },
	Tiger = { m = "Tigre", f = "Tigresse", baby = "Bébé tigre", group = "Tigres", food = "meat", height = 5.5, speed = 4, eat = 6, poop = 3, repro = 6, litter = { 1, 2 }, grow = 5, sell = 3500, femaleScale = 0.9 },
	Sheep = { m = "Bélier", f = "Brebis", baby = "Agneau", group = "Moutons", food = "hay", height = 4, speed = 2.8, eat = 3, poop = 3, repro = 2, litter = { 1, 2 }, grow = 2, sell = 120 },
	Lynx = { m = "Lynx", f = "Lynx femelle", baby = "Bébé lynx", group = "Lynx", food = "meat", height = 3.6, speed = 4, eat = 3, poop = 3, repro = 4, litter = { 1, 2 }, grow = 3, sell = 900 },
	Hyena = { m = "Hyène", f = "Hyène femelle", baby = "Bébé hyène", group = "Hyènes", food = "meat", height = 4, speed = 4, eat = 4, poop = 3, repro = 4, litter = { 1, 2 }, grow = 3, sell = 1300 },
	Buffalo = { m = "Buffle", f = "Bufflonne", baby = "Bufflon", group = "Buffles", food = "hay", height = 6, speed = 3, eat = 7, poop = 2.5, repro = 5, litter = { 1, 1 }, grow = 4, sell = 1700 },
	Jaguar = { m = "Jaguar", f = "Jaguar femelle", baby = "Bébé jaguar", group = "Jaguars", food = "meat", height = 4, speed = 4, eat = 5, poop = 3, repro = 6, litter = { 1, 2 }, grow = 5, sell = 3000, femaleScale = 0.9 },
	Rhino = { m = "Rhinocéros", f = "Rhinocéros femelle", baby = "Bébé rhinocéros", group = "Rhinocéros", food = "hay", height = 7, speed = 2.6, eat = 8, poop = 2, repro = 7, litter = { 1, 1 }, grow = 6, sell = 4000 },
	Elephant = { m = "Éléphant", f = "Éléphante", baby = "Éléphanteau", group = "Éléphants", food = "hay", height = 12, speed = 2.4, eat = 12, poop = 1.5, repro = 8, litter = { 1, 1 }, grow = 6, sell = 6500 },
	Lion = { m = "Lion", f = "Lionne", baby = "Lionceau", group = "Lions", food = "meat", height = 6, speed = 4, eat = 6, poop = 3, repro = 6, litter = { 1, 3 }, grow = 5, sell = 4500, femaleScale = 0.9 },
}

-- LE PLAN DU ZOO ---------------------------------------------------------------------------------------------------
-- x vers l'est, z vers le sud (l'entrée est au sud). Le sol du parc est à la hauteur 0.
local v3 = Vector3.new
Config.SPAWN = v3(0, 3, 172)
Config.BUS = v3(14, 0, 300) -- les visiteurs descendent du bus ici...
Config.LEAVE = v3(-14, 0, 300) -- ... et y remontent
-- Le guichet : les visiteurs font la queue dehors, au sud, jusqu'au tourniquet, où le caissier scanne leur billet.
Config.GATE = {
	turnstile = v3(8, 0, 196), -- le tourniquet d'entrée
	exit = v3(-8, 0, 196), -- la sortie
	queueFirst = v3(8, 0, 199.5), -- la première place de la queue (juste devant la fenêtre de la cabine)
	queueStep = v3(0, 0, 3.4), -- de place en place, vers le sud
	queueCount = 13,
	booth = v3(0, 0, 197), -- la cabine du caissier (entre l'entrée et la sortie)
}
-- La place derrière l'entrée.
Config.PLAZA = { min = v3(-50, 0, 122), max = v3(50, 0, 200) }
-- Les réserves (nourriture et trousses) : une dans le coin sud-ouest de la place, une au milieu du zoo.
Config.STORES = {
	{ center = v3(-38, 0, 182), facing = v3(1, 0, 0) },
	{ center = v3(36, 0, 10), facing = v3(-1, 0, 0) },
}
-- LES ALLÉES (sa demande du 14/10 : « 3 fois plus de terrain, des parcs bien plus grands ») : une grande boucle, une
-- avenue au milieu du sud au nord, et une rue en travers ; les visiteurs et le personnel prennent le plus court chemin
-- (Paths.luau). PATH_START : le carrefour où la place rejoint les allées.
Config.PATH_WIDTH = 11
Config.PATH_NODES = {
	v3(0, 0, 108), v3(215, 0, 108), v3(215, 0, -180), v3(215, 0, -470), v3(0, 0, -470),
	v3(-215, 0, -470), v3(-215, 0, -180), v3(-215, 0, 108), v3(0, 0, -180),
}
Config.PATH_EDGES = { { 1, 2 }, { 2, 3 }, { 3, 4 }, { 4, 5 }, { 5, 6 }, { 6, 7 }, { 7, 8 }, { 8, 1 }, { 1, 9 }, { 9, 5 }, { 7, 9 }, { 9, 3 } }
Config.PATH_START = 1
-- Le terrain plat du zoo (au-delà : les montagnes).
Config.ZOO_RECT = { minX = -352, maxX = 352, minZ = -604, maxZ = 212 }
-- Le lac, avec sa cascade (au sud-ouest du milieu).
Config.LAKE = { center = v3(-120, 0, 10), radius = 40 }

-- LES PARCELLES (sa demande du 14/10 : « de base ce serait des parcelles vides, et la déco change quand tu choisis,
-- par exemple tigre à cet endroit, ça devient le décor tigre »). Une parcelle vide a un panneau « À vendre » : on y
-- choisit ses animaux (Config.HABITATS), et elle se construit pour eux. La mini-ferme est la parcelle du départ.
-- Chaque parcelle : ses bords (x0, x1 d'ouest en est, z0, z1 du nord au sud), le côté qui donne sur l'allée (side :
-- « x- » = le côté ouest...) et où les visiteurs regardent (view, sur l'allée).
local function plot(id: string, x0: number, x1: number, z0: number, z1: number, side: string, view: Vector3, fixed: string?)
	return { id = id, center = v3((x0 + x1) / 2, 0, (z0 + z1) / 2), size = Vector2.new(x1 - x0, z1 - z0), side = side, view = view, fixed = fixed }
end
Config.PLOTS = {
	plot("farm", 55, 113, 126, 192, "x-", v3(46, 0, 159), "farm"),
	-- Au sud, de chaque côté de l'entrée.
	plot("s1", -200, -58, 124, 202, "x+", v3(-48, 0, 152)),
	plot("s2", 125, 205, 124, 202, "z-", v3(165, 0, 113)),
	-- À l'ouest, le long de la grande boucle (dehors).
	plot("w1", -340, -230, -12, 98, "x+", v3(-219, 0, 43)),
	plot("w2", -340, -230, -142, -32, "x+", v3(-219, 0, -87)),
	plot("w3", -340, -230, -272, -162, "x+", v3(-219, 0, -217)),
	plot("w4", -340, -230, -402, -292, "x+", v3(-219, 0, -347)),
	-- À l'est (dehors).
	plot("e1", 230, 340, -12, 98, "x-", v3(219, 0, 43)),
	plot("e2", 230, 340, -142, -32, "x-", v3(219, 0, -87)),
	plot("e3", 230, 340, -272, -162, "x-", v3(219, 0, -217)),
	plot("e4", 230, 340, -402, -292, "x-", v3(219, 0, -347)),
	-- Au nord (dehors).
	plot("n1", -200, -80, -592, -482, "z+", v3(-140, 0, -476)),
	plot("n2", -60, 60, -592, -482, "z+", v3(0, 0, -476)),
	plot("n3", 80, 200, -592, -482, "z+", v3(140, 0, -476)),
	-- Dedans, entre la boucle, l'avenue et la rue.
	plot("c1", -200, -90, -165, -55, "z-", v3(-145, 0, -176)),
	plot("c2", 90, 200, -165, -55, "z-", v3(145, 0, -176)),
	plot("c3", -197, -117, -315, -195, "x-", v3(-209, 0, -255)),
	plot("c4", -97, -17, -315, -195, "x+", v3(-4, 0, -255)),
	plot("c5", -197, -117, -455, -335, "x-", v3(-209, 0, -395)),
	plot("c6", -97, -17, -455, -335, "x+", v3(-4, 0, -395)),
	plot("c7", 17, 97, -315, -195, "x-", v3(4, 0, -255)),
	plot("c8", 117, 197, -315, -195, "x+", v3(209, 0, -255)),
	plot("c9", 17, 97, -455, -335, "x-", v3(4, 0, -395)),
	plot("c10", 117, 197, -455, -335, "x+", v3(209, 0, -395)),
}
Config.PLOT_BY_ID = {}
for index, plot in Config.PLOTS do
	plot.index = index
	Config.PLOT_BY_ID[plot.id] = plot
end

-- LES ANIMAUX QU'ON PEUT METTRE SUR UNE PARCELLE. Le prix : l'espace seul, construit vide (sa demande du 14/10 :
-- « faire le terrain mais pas avoir d'animaux dedans ») ; les animaux s'achètent au Marché des autres zoos.
-- decor : le décor (Enclosures.luau) ; security (sa demande, 14/10 : « plus de sécurité pour les animaux dangereux,
-- par exemple fosse aux ours où ils sont en bas, truc plus sécurisé ») :
--   fence : une clôture en bois (animaux calmes) ;
--   wall : de hauts rondins, une vitre côté visiteurs ;
--   moat : un fossé profond entre les visiteurs et les animaux, une vitre, de hauts rondins ailleurs ;
--   pit : une fosse, les animaux en bas, les visiteurs en haut derrière une rambarde.
-- capacity : animaux au plus (les naissances s'arrêtent).
Config.HABITATS = {
	{ id = "farm", name = "Mini-ferme", species = { "Goat", "Pig", "Rooster" }, price = 0, decor = "farm", security = "fence", capacity = 14, hidden = true, toys = { "salt", "brush", "ball" } },
	{ id = "sheep", name = "Moutons", species = { "Sheep" }, price = 200, decor = "meadow", security = "fence", capacity = 15, toys = { "salt", "brush" } },
	{ id = "deer", name = "Cerfs", species = { "Deer" }, price = 300, decor = "forest", security = "fence", capacity = 12, toys = { "salt", "brush", "log" } },
	{ id = "boar", name = "Sangliers", species = { "Boar" }, price = 600, decor = "mud", security = "fence", capacity = 12, toys = { "ball", "log", "pool" } },
	{ id = "capy", name = "Capybaras", species = { "Capybara" }, price = 900, decor = "pond", security = "fence", capacity = 15, toys = { "pool", "salt", "ball" } },
	{ id = "wolf", name = "Loups", species = { "Wolf" }, price = 1500, decor = "forest", security = "wall", capacity = 10, toys = { "log", "ball", "platform" } },
	{ id = "lynx", name = "Lynx", species = { "Lynx" }, price = 1800, decor = "forest", security = "wall", capacity = 9, toys = { "log", "platform", "ropes" } },
	{ id = "croc", name = "Crocodiles", species = { "Crocodile" }, price = 2500, decor = "river", security = "moat", capacity = 9, toys = { "pool", "log" } },
	{ id = "hyena", name = "Hyènes", species = { "Hyena" }, price = 3000, decor = "savanna", security = "wall", capacity = 10, toys = { "log", "ball", "platform" } },
	{ id = "bear", name = "Ours", species = { "Bear" }, price = 3500, decor = "rocks", security = "pit", capacity = 8, toys = { "log", "pool", "ball", "platform" } },
	{ id = "buffalo", name = "Buffles", species = { "Buffalo" }, price = 4000, decor = "savanna", security = "moat", capacity = 9, toys = { "salt", "brush", "pool" } },
	{ id = "cheetah", name = "Guépards", species = { "Cheetah" }, price = 4500, decor = "savanna", security = "moat", capacity = 9, toys = { "platform", "log", "ball" } },
	{ id = "gorilla", name = "Gorilles", species = { "Gorilla" }, price = 6000, decor = "jungle", security = "moat", capacity = 9, toys = { "ropes", "ball", "platform" } },
	{ id = "jaguar", name = "Jaguars", species = { "Jaguar" }, price = 7000, decor = "jungle", security = "moat", capacity = 8, toys = { "log", "ropes", "platform" } },
	{ id = "tiger", name = "Tigres", species = { "Tiger" }, price = 8000, decor = "jungle", security = "moat", capacity = 8, toys = { "pool", "log", "ball" } },
	{ id = "rhino", name = "Rhinocéros", species = { "Rhino" }, price = 10000, decor = "savanna", security = "moat", capacity = 6, toys = { "pool", "brush", "salt" } },
	{ id = "lion", name = "Lions", species = { "Lion" }, price = 11000, decor = "savanna", security = "moat", capacity = 9, toys = { "platform", "log", "ball" } },
	{ id = "elephant", name = "Éléphants", species = { "Elephant" }, price = 15000, decor = "savanna", security = "moat", capacity = 6, toys = { "pool", "ball", "brush" } },
}
Config.HABITAT_BY_ID = {}
for _, habitat in Config.HABITATS do
	Config.HABITAT_BY_ID[habitat.id] = habitat
end
Config.MOAT = 8 -- la largeur du fossé (côté visiteurs)

-- LE MARCHÉ (sa demande du 14/10 : « un onglet d'achat à d'autres zoos fictifs où je leur achète mâle, femelle ou
-- bébé, et des fois des échanges entre zoos pour la reproduction, éviter la consanguinité »). Chaque matin, chaque zoo
-- propose de nouveaux animaux, et quelques échanges (un de leurs animaux contre un des tiens, de la même espèce et du
-- même sexe : du sang neuf pour tes couples).
-- Chaque zoo a sa couleur, son blason (deux lettres), sa ville, sa présentation et sa spécialité : il propose surtout
-- les animaux de sa liste (sa demande du 15/10 : « un meilleur interface pour les autres zoos »).
Config.MARKET = {
	zoos = {
		{ name = "Zoo de la Vallée", badge = "ZV", color = Color3.fromRGB(96, 160, 72), city = "Vallée verte", about = "Un petit zoo familial, au bord d'une rivière. Ses fermiers élèvent aussi des cerfs et des sangliers.", species = { "Goat", "Pig", "Rooster", "Sheep", "Deer", "Boar" } },
		{ name = "Parc des Cimes", badge = "PC", color = Color3.fromRGB(92, 120, 168), city = "Haute montagne", about = "Un parc dans les montagnes et les sapins, spécialiste des animaux de la forêt.", species = { "Wolf", "Lynx", "Bear", "Deer", "Boar", "Sheep" } },
		{ name = "Safari du Soleil", badge = "SS", color = Color3.fromRGB(214, 150, 54), city = "Grande savane", about = "Un immense safari où les animaux de la savane vivent en liberté.", species = { "Lion", "Cheetah", "Hyena", "Buffalo", "Rhino", "Elephant" } },
		{ name = "Zoo des Îles", badge = "ZI", color = Color3.fromRGB(46, 160, 160), city = "Archipel tropical", about = "Un zoo dans la jungle des îles : fauves, grands singes et animaux d'eau.", species = { "Tiger", "Jaguar", "Gorilla", "Crocodile", "Capybara" } },
		{ name = "Domaine des Grands Lacs", badge = "GL", color = Color3.fromRGB(150, 96, 170), city = "Pays des lacs", about = "Un grand domaine qui échange un peu de tout avec les autres zoos.", species = {} },
	},
	offersPerZoo = 6,
	swaps = 4,
	baby = 0.3, -- part des bébés dans les offres
}
Config.ZOO_BY_NAME = {}
for _, zoo in Config.MARKET.zoos do
	Config.ZOO_BY_NAME[zoo.name] = zoo
end

-- LES PRÉNOMS (sa demande du 15/10 : « une vraie fiche perso sur chaque animal ») : chaque animal en reçoit un à sa
-- naissance ou à son arrivée ; on peut le changer sur sa fiche.
Config.NAMES = {
	m = { "Max", "Léo", "Oscar", "Simba", "Rocky", "Hugo", "Milo", "Tom", "Noé", "Gaspard", "Félix", "Arthur", "Zeus", "Titan", "Kiko", "Bruno", "Jules", "Sacha", "Marius", "Pablo", "Elio", "Basile", "Nino", "Timo", "Caramel", "Moka", "Pépito", "Rango", "Kenzo", "Ulysse", "Balou", "Filou", "Gribouille", "Hector", "Igor", "Kaïo" },
	f = { "Lila", "Nala", "Lola", "Mia", "Rosa", "Zoé", "Luna", "Perle", "Daisy", "Jade", "Iris", "Nina", "Kiara", "Bella", "Olive", "Capucine", "Praline", "Suzie", "Maya", "Élise", "Fleur", "Pomme", "Lili", "Noisette", "Cléo", "Ambre", "Vanille", "Myrtille", "Tara", "Zina", "Biscotte", "Cannelle", "Dune", "Gaïa", "Hermine", "Isis" },
}
-- Le prix d'un animal au Marché : plus cher qu'à la vente (une femelle plus qu'un mâle, un bébé moins cher).
function Config.marketPrice(species: string, sex: string, baby: boolean): number
	local sell = Config.SPECIES[species].sell
	local price = sell * (if sex == "f" then 1.8 else 1.5) * (if baby then 0.55 else 1)
	return math.floor(price / 5 + 0.5) * 5
end
Config.PIT = 10 -- la profondeur de la fosse aux ours


-- LE PERSONNEL (payé chaque soir) ------------------------------------------------------------------------------------
Config.STAFF = {
	cashier = { fr = "Caissier", salary = 60, max = 1, every = 2.6, about = "Scanne les billets à l'entrée." },
	keeper = { fr = "Soigneur", salary = 80, max = 4, about = "Remplit les mangeoires avec le stock de la réserve." },
	cleaner = { fr = "Agent d'entretien", salary = 70, max = 4, about = "Crottes, papiers, poubelles et toilettes." },
	vet = { fr = "Vétérinaire", salary = 120, max = 2, about = "Examine et soigne les malades (avec les médicaments du stock)." },
	storekeeper = { fr = "Magasinier", salary = 70, max = 3, about = "Range les cartons livrés et remplit les stands." },
}
Config.STAFF_ORDER = { "cashier", "keeper", "cleaner", "vet", "storekeeper" }
Config.STAFF_SPEED = 13

-- LA NOTE DU ZOO ---------------------------------------------------------------------------------------------------
-- Chaque visiteur repart avec une note sur 5 (le bonheur des animaux qu'il a vus, la propreté des allées, l'attente au
-- guichet). Le soir, la note du zoo se rapproche de la moyenne du jour.
Config.NOTE_BLEND = 0.4

return Config

-- Géométrie de la map principale : 6 parcelles en cercle autour de la place centrale (cercle ranked).
-- Coordonnées locales d'une parcelle : X = largeur, Z = profondeur.
--   Z négatif = entrée, côté place centrale (là où se trouve la base à défendre)
--   Z positif = fond de la parcelle (là où apparaissent les ennemis)
local PlotLayout = {}

PlotLayout.COUNT = 6
PlotLayout.RING_RADIUS = 140 -- distance entre le centre de la map et le centre d'une parcelle
PlotLayout.WIDTH = 64
PlotLayout.LENGTH = 130
PlotLayout.PATH_WIDTH = 6

PlotLayout.RANKED_CIRCLE_RADIUS = 9
PlotLayout.RANKED_CIRCLE_POSITION = Vector3.new(0, 0, 20)

-- 6 allers-retours : un long chemin (~360 studs) pour laisser le temps aux tours de travailler.
PlotLayout.PATH = {
	Vector3.new(-22, 0, 62),
	Vector3.new(-22, 0, 50),
	Vector3.new(22, 0, 50),
	Vector3.new(22, 0, 32),
	Vector3.new(-22, 0, 32),
	Vector3.new(-22, 0, 14),
	Vector3.new(22, 0, 14),
	Vector3.new(22, 0, -4),
	Vector3.new(-22, 0, -4),
	Vector3.new(-22, 0, -22),
	Vector3.new(22, 0, -22),
	Vector3.new(22, 0, -40),
	Vector3.new(0, 0, -40),
	Vector3.new(0, 0, -54),
}

-- Longueurs cumulées du chemin, pour placer un ennemi selon la distance parcourue.
local cumulative = { 0 }
for i = 2, #PlotLayout.PATH do
	cumulative[i] = cumulative[i - 1] + (PlotLayout.PATH[i] - PlotLayout.PATH[i - 1]).Magnitude
end
PlotLayout.PATH_LENGTH = cumulative[#cumulative]

-- Position locale et direction sur le chemin après `distance` studs.
function PlotLayout.pointAt(distance: number): (Vector3, Vector3)
	local path = PlotLayout.PATH
	if distance <= 0 then
		return path[1], (path[2] - path[1]).Unit
	end
	for i = 2, #path do
		if distance <= cumulative[i] then
			local direction = (path[i] - path[i - 1]).Unit
			return path[i - 1] + direction * (distance - cumulative[i - 1]), direction
		end
	end
	return path[#path], (path[#path] - path[#path - 1]).Unit
end

PlotLayout.BASE_POSITION = Vector3.new(0, 0, -59)
-- Point d'apparition du joueur sur sa parcelle (il regarde vers le fond : Plots.homeCFrame). Z = -50 et plus -60
-- (01/10/2026) : la caméra de départ est 12,5 studs derrière le personnage, donc en plein dans l'Autel des héros
-- (devant l'entrée, x = -20, z = -73) quand on apparaissait à -60. La première image du jeu avait une large bande
-- dorée en bas de l'écran : le linteau de l'autel, collé à la caméra (un cinquième de l'écran sur téléphone).
PlotLayout.PLAYER_SPAWN = Vector3.new(-20, 3, -50)

-- Emplacements de tours.
-- 22 emplacements : les STARTING_SPOTS premiers sont gratuits (possédés dès le départ), les autres
-- s'achètent avec des pièces, dans n'importe quel ordre (le joueur choisit lequel).
PlotLayout.STARTING_SPOTS = 4
PlotLayout.SPOTS = {
	Vector3.new(-4, 0, -13),
	Vector3.new(5, 0, -13),
	Vector3.new(-4, 0, -31),
	Vector3.new(5, 0, -31),
	Vector3.new(-13, 0, -13),
	Vector3.new(14, 0, -13),
	Vector3.new(-13, 0, -31),
	Vector3.new(14, 0, -31),
	Vector3.new(-4, 0, 5),
	Vector3.new(5, 0, 5),
	Vector3.new(-13, 0, 5),
	Vector3.new(14, 0, 5),
	Vector3.new(-14, 0, -56),
	Vector3.new(14, 0, -56),
	Vector3.new(-4, 0, 23),
	Vector3.new(5, 0, 23),
	Vector3.new(-13, 0, 23),
	Vector3.new(14, 0, 23),
	Vector3.new(-4, 0, 41),
	Vector3.new(5, 0, 41),
	Vector3.new(-13, 0, 41),
	Vector3.new(14, 0, 41),
}

-- Hauteur (studs) du socle de pierre d'un emplacement, posé sur le sol. 1 au lieu de 0,3 (demande du propriétaire,
-- 01/10/2026 : deux nouveaux joueurs sont partis à l'étape « pose une tour » du tuto, sans en poser) : un socle
-- surélevé se voit mieux et se touche plus facilement, surtout sur téléphone où la caméra regarde le sol de biais.
-- La tour est posée dessus (PlotGame:createTower) ; rien ne change pour le combat (portées et vols se calculent
-- comme avant).
PlotLayout.SPOT_PAD_HEIGHT = 1

-- Vrai si `value` est un numéro d'emplacement qui existe (nombre entier de 1 à 22).
-- Le serveur s'en sert pour vérifier ce qu'envoie le client.
function PlotLayout.isSpotIndex(value: any): boolean
	return typeof(value) == "number" and value == math.floor(value) and value >= 1 and value <= #PlotLayout.SPOTS
end

-- Emplacements possédés au départ, au format des sauvegardes : { ["1"] = true, ["2"] = true, ... }
-- (clés en texte, comme data.idle.towers).
function PlotLayout.startingSpots(): { [string]: boolean }
	local owned = {}
	for spotIndex = 1, PlotLayout.STARTING_SPOTS do
		owned[tostring(spotIndex)] = true
	end
	return owned
end

-- Prix des emplacements à débloquer : de plus en plus cher.
-- Le prix ne dépend PAS de l'emplacement choisi, seulement du nombre d'emplacements déjà possédés :
-- spotCost(n) = prix pour posséder son n-ième emplacement (n = possédés + 1).
-- 5e emplacement : 100 pièces, puis x2,6 par emplacement … 22e : ~1,1 B (1,1 milliard).
-- x2,6, c'est la hausse des gains en ~4,3 vagues (x1,25 par vague) : le joueur simulé achète un
-- emplacement toutes les 4-5 vagues environ, le 5e vers la vague 15 et le 22e vers la vague 95-100
-- (la tour à y poser et ses améliorations coûtent bien plus que l'emplacement lui-même).
PlotLayout.SPOT_BASE_COST = 100
PlotLayout.SPOT_COST_GROWTH = 2.6
PlotLayout.SPOT_COST_ACCELERATION = 1 -- 1 = pas d'accélération (x2,6 à chaque emplacement)

function PlotLayout.spotCost(nth: number): number
	local k = nth - PlotLayout.STARTING_SPOTS - 1
	if k < 0 then
		return 0
	end
	local raw = PlotLayout.SPOT_BASE_COST * PlotLayout.SPOT_COST_GROWTH ^ k * PlotLayout.SPOT_COST_ACCELERATION ^ (k * k)
	-- Arrondi à 2 chiffres significatifs pour des prix lisibles.
	local magnitude = 10 ^ math.max(0, math.floor(math.log10(raw)) - 1)
	return math.floor(raw / magnitude + 0.5) * magnitude
end

-- CFrame de l'origine d'une parcelle : son axe +Z pointe vers l'extérieur de la map.
function PlotLayout.cframe(plotIndex: number): CFrame
	local angle = (plotIndex - 1) * 2 * math.pi / PlotLayout.COUNT
	local outward = Vector3.new(math.sin(angle), 0, math.cos(angle))
	local center = outward * PlotLayout.RING_RADIUS
	return CFrame.lookAt(center, center - outward)
end

function PlotLayout.toWorld(plotIndex: number, localPosition: Vector3): Vector3
	return PlotLayout.cframe(plotIndex):PointToWorldSpace(localPosition)
end

function PlotLayout.toLocal(plotIndex: number, worldPosition: Vector3): Vector3
	return PlotLayout.cframe(plotIndex):PointToObjectSpace(worldPosition)
end

-- CFrame monde d'un point local, orienté comme la parcelle.
function PlotLayout.worldCFrame(plotIndex: number, localPosition: Vector3): CFrame
	return PlotLayout.cframe(plotIndex) * CFrame.new(localPosition)
end

return PlotLayout

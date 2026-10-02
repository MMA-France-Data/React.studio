-- Géométrie de la map principale : 6 parcelles en cercle autour de la place centrale. La parcelle d'un joueur est
-- son camp d'entraînement (Hub/Camp.luau).
-- Coordonnées locales d'une parcelle : X = largeur, Z = profondeur.
--   Z négatif = entrée, côté place centrale (là où se trouve le château)
--   Z positif = fond de la parcelle (là où apparaissent les cibles d'entraînement)
local PlotLayout = {}

PlotLayout.COUNT = 6
PlotLayout.RING_RADIUS = 140 -- distance entre le centre de la map et le centre d'une parcelle
PlotLayout.WIDTH = 64
PlotLayout.LENGTH = 130
PlotLayout.PATH_WIDTH = 6

-- 6 allers-retours : un long chemin (~360 studs) que les cibles d'entraînement suivent du fond jusqu'au château.
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

-- Longueurs cumulées du chemin, pour placer une cible selon la distance parcourue.
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
-- Point d'apparition du joueur sur sa parcelle (il regarde vers le fond : Plots.homeCFrame). Z = -50 et pas -60 :
-- la caméra de départ est 12,5 studs derrière le personnage, donc en plein dans le bâtiment de gauche de l'entrée
-- (x = -20, z = -73) quand on apparaissait à -60 : son linteau cachait un cinquième de l'écran sur téléphone.
PlotLayout.PLAYER_SPAWN = Vector3.new(-20, 3, -50)

-- Socles d'entraînement du camp : une rangée face au chemin, juste devant le point d'arrivée du joueur. Le socle n
-- porte la tour de l'emplacement d'entraînement n (Levels.CAMP.SPOTS).
PlotLayout.SPOTS = {
	Vector3.new(-13, 0, -31),
	Vector3.new(-4, 0, -31),
	Vector3.new(5, 0, -31),
}

-- Hauteur (studs) du socle de pierre, posé sur le sol : la tour est posée dessus (Hub/CampGame.luau). Rien ne change
-- pour le combat (portées et vols se calculent à partir du sol).
PlotLayout.SPOT_PAD_HEIGHT = 1

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

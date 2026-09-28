-- Géométrie de la map principale : 6 parcelles en cercle autour de la place centrale (cercle ranked).
-- Coordonnées locales d'une parcelle : X = largeur, Z = profondeur.
--   Z négatif = entrée, côté place centrale (là où se trouve la base à défendre)
--   Z positif = fond de la parcelle (là où apparaissent les ennemis)
local PlotLayout = {}

PlotLayout.COUNT = 6
PlotLayout.RING_RADIUS = 125 -- distance entre le centre de la map et le centre d'une parcelle
PlotLayout.WIDTH = 64
PlotLayout.LENGTH = 90
PlotLayout.PATH_WIDTH = 6

PlotLayout.RANKED_CIRCLE_RADIUS = 9
PlotLayout.RANKED_CIRCLE_POSITION = Vector3.new(0, 0, 20)

PlotLayout.PATH = {
	Vector3.new(-22, 0, 42),
	Vector3.new(-22, 0, 26),
	Vector3.new(22, 0, 26),
	Vector3.new(22, 0, 8),
	Vector3.new(-22, 0, 8),
	Vector3.new(-22, 0, -10),
	Vector3.new(22, 0, -10),
	Vector3.new(22, 0, -26),
	Vector3.new(0, 0, -26),
	Vector3.new(0, 0, -34),
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

PlotLayout.BASE_POSITION = Vector3.new(0, 0, -39)
PlotLayout.PLAYER_SPAWN = Vector3.new(-20, 3, -40)

-- Emplacements de tours, dans l'ordre de déblocage.
-- 22 emplacements : les STARTING_SPOTS premiers sont gratuits, les autres s'achètent avec des pièces.
PlotLayout.STARTING_SPOTS = 4
PlotLayout.SPOTS = {
	Vector3.new(-4, 0, -1),
	Vector3.new(5, 0, -1),
	Vector3.new(-5, 0, -18),
	Vector3.new(4, 0, -18),
	Vector3.new(-14, 0, -36),
	Vector3.new(14, 0, -36),
	Vector3.new(-13, 0, -1),
	Vector3.new(14, 0, -1),
	Vector3.new(-14, 0, -18),
	Vector3.new(13, 0, -18),
	Vector3.new(-5, 0, 17),
	Vector3.new(4, 0, 17),
	Vector3.new(-14, 0, 17),
	Vector3.new(13, 0, 17),
	Vector3.new(-10, 0, 34),
	Vector3.new(4, 0, 34),
	Vector3.new(-28, 0, 17),
	Vector3.new(28, 0, 17),
	Vector3.new(-28, 0, -18),
	Vector3.new(28, 0, -18),
	Vector3.new(14, 0, 34),
	Vector3.new(24, 0, 40),
}

-- Prix des emplacements à débloquer : de plus en plus cher, et la hausse elle-même accélère.
-- 5e emplacement : 500 pièces … 22e : ~1,1 Qa (un quadrillion).
PlotLayout.SPOT_BASE_COST = 500
PlotLayout.SPOT_COST_GROWTH = 3.8
PlotLayout.SPOT_COST_ACCELERATION = 1.02

function PlotLayout.spotCost(spotIndex: number): number
	local k = spotIndex - PlotLayout.STARTING_SPOTS - 1
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

-- Géométrie de la carte, partagée serveur/client (le client s'en sert pour prévisualiser la pose).
-- Chaque joueur a sa propre "lane". Coordonnées locales : X = largeur, Z = longueur.
-- Les ennemis partent de +Z et avancent vers la base en -Z.
local MapLayout = {}

MapLayout.LANE_WIDTH = 80
MapLayout.LANE_LENGTH = 130
MapLayout.LANE_SPACING = 100
MapLayout.PATH_WIDTH = 6
MapLayout.TOWER_CLEARANCE = 5 -- distance mini entre le centre d'une tour et le centre du chemin
MapLayout.TOWER_SPACING = 4.5 -- distance mini entre deux tours
MapLayout.BUILD_MARGIN = 3 -- distance mini au bord de la lane
MapLayout.BASE_CLEARANCE = 8

MapLayout.PATH = {
	Vector3.new(-28, 0, 62),
	Vector3.new(-28, 0, 38),
	Vector3.new(28, 0, 38),
	Vector3.new(28, 0, 12),
	Vector3.new(-28, 0, 12),
	Vector3.new(-28, 0, -14),
	Vector3.new(28, 0, -14),
	Vector3.new(28, 0, -40),
	Vector3.new(0, 0, -40),
	Vector3.new(0, 0, -54),
}

MapLayout.BASE_POSITION = Vector3.new(0, 0, -58)
MapLayout.PLAYER_SPAWN = Vector3.new(-18, 3, -58)

-- Longueurs cumulées pour positionner un ennemi selon la distance parcourue.
local cumulative = { 0 }
for i = 2, #MapLayout.PATH do
	cumulative[i] = cumulative[i - 1] + (MapLayout.PATH[i] - MapLayout.PATH[i - 1]).Magnitude
end
MapLayout.PATH_LENGTH = cumulative[#cumulative]

function MapLayout.laneOrigin(laneIndex: number): Vector3
	local x = if laneIndex == 1 then -MapLayout.LANE_SPACING / 2 else MapLayout.LANE_SPACING / 2
	return Vector3.new(x, 0, 0)
end

function MapLayout.toWorld(laneIndex: number, localPosition: Vector3): Vector3
	return MapLayout.laneOrigin(laneIndex) + localPosition
end

function MapLayout.toLocal(laneIndex: number, worldPosition: Vector3): Vector3
	return worldPosition - MapLayout.laneOrigin(laneIndex)
end

-- Position locale et direction sur le chemin après `distance` studs.
function MapLayout.pointAt(distance: number): (Vector3, Vector3)
	local path = MapLayout.PATH
	if distance <= 0 then
		return path[1], (path[2] - path[1]).Unit
	end
	for i = 2, #path do
		if distance <= cumulative[i] then
			local segmentStart = path[i - 1]
			local direction = (path[i] - segmentStart).Unit
			return segmentStart + direction * (distance - cumulative[i - 1]), direction
		end
	end
	local last = path[#path]
	return last, (last - path[#path - 1]).Unit
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Distance horizontale entre un point local et le chemin.
function MapLayout.distanceToPath(localPosition: Vector3): number
	local p = flat(localPosition)
	local best = math.huge
	for i = 2, #MapLayout.PATH do
		local a, b = MapLayout.PATH[i - 1], MapLayout.PATH[i]
		local ab = b - a
		local t = math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
		best = math.min(best, (p - (a + ab * t)).Magnitude)
	end
	return best
end

function MapLayout.isInsideLane(localPosition: Vector3, margin: number): boolean
	return math.abs(localPosition.X) <= MapLayout.LANE_WIDTH / 2 - margin
		and math.abs(localPosition.Z) <= MapLayout.LANE_LENGTH / 2 - margin
end

return MapLayout

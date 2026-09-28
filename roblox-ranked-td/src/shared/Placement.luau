-- Règles de pose des tours. Le client s'en sert pour la prévisualisation,
-- le serveur pour valider (le serveur a toujours le dernier mot).
local MapLayout = require(script.Parent.MapLayout)

local Placement = {}

function Placement.check(laneIndex: number, worldPosition: Vector3, existingTowerPositions: { Vector3 }): (boolean, string?)
	if worldPosition.X ~= worldPosition.X or worldPosition.Z ~= worldPosition.Z then
		return false, "Position invalide"
	end

	local localPosition = MapLayout.toLocal(laneIndex, worldPosition)
	if not MapLayout.isInsideLane(localPosition, MapLayout.BUILD_MARGIN) then
		return false, "Tu ne peux construire que sur ton terrain"
	end
	if MapLayout.distanceToPath(localPosition) < MapLayout.TOWER_CLEARANCE then
		return false, "Trop proche du chemin"
	end

	local toBase = localPosition - MapLayout.BASE_POSITION
	if Vector3.new(toBase.X, 0, toBase.Z).Magnitude < MapLayout.BASE_CLEARANCE then
		return false, "Trop proche de la base"
	end

	for _, other in existingTowerPositions do
		local offset = other - worldPosition
		if Vector3.new(offset.X, 0, offset.Z).Magnitude < MapLayout.TOWER_SPACING then
			return false, "Trop proche d'une autre tour"
		end
	end

	return true, nil
end

return Placement

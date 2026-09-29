-- Pavage des chemins orthogonaux : un carré par virage et des tronçons raccourcis.
-- Les faces supérieures se rejoignent bord à bord, sans surface coplanaire superposée.
-- Le tracé, sa largeur et les points de déplacement du gameplay restent inchangés.
local RoadGeometry = {}

function RoadGeometry.rectangles(path: { Vector3 }, width: number)
	assert(width > 0, "Largeur de chemin invalide")
	local rectangles = {}
	for _, point in path do
		table.insert(rectangles, { center = point, size = Vector3.new(width, 0.2, width) })
	end
	for i = 2, #path do
		local a, b = path[i - 1], path[i]
		local delta = b - a
		assert(math.abs(delta.Y) < 0.001 and (math.abs(delta.X) < 0.001 or math.abs(delta.Z) < 0.001), "Chemin non orthogonal")
		local length = delta.Magnitude - width
		assert(length >= 0, "Tronçon plus court que sa largeur")
		if length > 0 then
			table.insert(rectangles, {
				center = (a + b) / 2,
				size = if math.abs(delta.X) > 0.001 then Vector3.new(length, 0.2, width) else Vector3.new(width, 0.2, length),
			})
		end
	end
	return rectangles
end

return RoadGeometry

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

-- Plusieurs chemins qui se rejoignent (couloirs d'une carte d'équipe) : chaque dalle une seule fois (les couloirs
-- partagent les mêmes points après leur rencontre), pour qu'aucune dalle n'en recouvre une autre.
function RoadGeometry.network(paths: { { Vector3 } }, width: number)
	local rectangles, seen = {}, {}
	for _, path in paths do
		for _, slab in RoadGeometry.rectangles(path, width) do
			local key = `{slab.center.X},{slab.center.Z}:{slab.size.X},{slab.size.Z}`
			if not seen[key] then
				seen[key] = true
				table.insert(rectangles, slab)
			end
		end
	end
	return rectangles
end

return RoadGeometry

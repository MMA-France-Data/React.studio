-- Mesure la hauteur du sol (terrain) à quelques endroits du parc.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

return function(log)
	local state = ReplicatedStorage:WaitForChild("ZooState")
	while not state:GetAttribute("Ready") do
		task.wait(0.2)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	for _, spot in { Vector3.new(0, 0, 150), Vector3.new(84, 0, 159), Vector3.new(-84, 0, 159), Vector3.new(0, 0, 60), Vector3.new(30, 0, 150), Vector3.new(150, 0, 0) } do
		local hit = workspace:Raycast(spot + Vector3.new(0, 60, 0), Vector3.new(0, -120, 0), params)
		log("Info", string.format("[ZOO] sol en (%d, %d) : %s %s", spot.X, spot.Z, tostring(hit and hit.Position.Y), tostring(hit and hit.Material)))
	end
	local region = Region3.new(Vector3.new(0, -8, 148), Vector3.new(4, 8, 152)):ExpandToGrid(4)
	local materials, occupancy = workspace.Terrain:ReadVoxels(region, 4)
	for y = 1, materials.Size.Y do
		log("Info", string.format("[ZOO] case %d : %s %.2f", y, tostring(materials[1][y][1]), occupancy[1][y][1]))
	end
	log("Info", "[ZOO] TEST:done")
end

-- LE PARC : la lumière, le terrain (le sol du zoo, les allées, le lac et sa cascade, les montagnes autour, la route du
-- bus), l'entrée avec son guichet, la place, la réserve, et toute la végétation.
-- Style demandé par le créateur (14/10, son image) : un zoo luxuriant à la Planet Zoo, avec des rochers, de l'eau, des
-- palmiers, des bâtiments en bois sombre aux grands toits et des allées claires.
-- Les espaces des animaux et les bâtiments à acheter sont construits par Enclosures.luau.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Props = require(script.Parent.Props)

local Map = {}

local M = Enum.Material
local rgb = Props.rgb
local part = Props.part
local v3 = Vector3.new

local terrain = workspace.Terrain
local folder: Folder

local RES = 4
local EXTENT = 452 -- le terrain va de -EXTENT à +EXTENT (en x et en z)
local ZOO = 204 -- le parc est plat dans le carré de côté 2 x ZOO ; les montagnes commencent au-delà
local BOTTOM = -24

-- LA LUMIÈRE : un bel après-midi tropical, un peu de brume dans les montagnes.
local function light()
	Lighting.ClockTime = 14
	Lighting.GeographicLatitude = 18
	Lighting.Brightness = 2.4
	Lighting.Ambient = rgb(74, 74, 84)
	Lighting.OutdoorAmbient = rgb(132, 132, 144)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 0.8
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.25
	Lighting.ColorShift_Top = rgb(255, 244, 222)
	local function effect(className: string, properties)
		local item = Lighting:FindFirstChildOfClass(className) or Instance.new(className)
		for key, value in properties do
			item[key] = value
		end
		item.Parent = Lighting
	end
	effect("Atmosphere", { Density = 0.22, Offset = 0.05, Color = rgb(206, 218, 226), Decay = rgb(112, 136, 150), Glare = 0.25, Haze = 1.4 })
	effect("BloomEffect", { Intensity = 0.5, Size = 24, Threshold = 1.7 })
	effect("SunRaysEffect", { Intensity = 0.05, Spread = 0.7 })
	effect("ColorCorrectionEffect", { Saturation = 0.14, Contrast = 0.06, Brightness = 0.01, TintColor = rgb(255, 250, 240) })
	local clouds = terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.55
	clouds.Color = rgb(255, 255, 255)
	clouds.Parent = terrain
end

-- LES COULEURS DU TERRAIN
local function colors()
	terrain:SetMaterialColor(M.Grass, rgb(98, 144, 62))
	terrain:SetMaterialColor(M.LeafyGrass, rgb(84, 132, 56))
	terrain:SetMaterialColor(M.Rock, rgb(118, 112, 100))
	terrain:SetMaterialColor(M.Ground, rgb(116, 94, 70))
	terrain:SetMaterialColor(M.Sand, rgb(216, 198, 154))
	terrain:SetMaterialColor(M.Pavement, rgb(204, 192, 168))
	terrain:SetMaterialColor(M.Mud, rgb(100, 78, 58))
	terrain:SetMaterialColor(M.Asphalt, rgb(84, 84, 88))
	terrain:SetMaterialColor(M.Cobblestone, rgb(156, 146, 130))
	terrain:SetMaterialColor(M.Slate, rgb(110, 104, 98))
	terrain.WaterColor = rgb(48, 124, 122)
	terrain.WaterTransparency = 0.55
	terrain.WaterReflectance = 0.45
	terrain.WaterWaveSize = 0.08
	terrain.WaterWaveSpeed = 6
end

-- LES FORMES DU SOL ------------------------------------------------------------------------------------------------------
-- Distance d'un point (x, z) au segment a-b (vus du ciel).
local function segmentDistance(x: number, z: number, a: Vector3, b: Vector3): number
	local abx, abz = b.X - a.X, b.Z - a.Z
	local length = abx * abx + abz * abz
	local t = if length > 0 then math.clamp(((x - a.X) * abx + (z - a.Z) * abz) / length, 0, 1) else 0
	local dx, dz = x - (a.X + abx * t), z - (a.Z + abz * t)
	return math.sqrt(dx * dx + dz * dz)
end

-- Les morceaux d'allée en plus de la boucle : { de, à, largeur }.
local LINKS = {
	{ v3(0, 0, 124), v3(0, 0, 104), 15 }, -- de la place à la boucle
	{ v3(-54, 0, 88), v3(-54, 0, 106), 9 }, -- devant le café
	{ v3(54, 0, 88), v3(54, 0, 106), 9 }, -- devant le bar
}
-- La place (voir onPath) et le chemin des visiteurs dessus (Visitors.luau).
local PLAZA_CENTER = v3(0, 0, 150)
local PLAZA_LINKS = {
	{ v3(0, 0, 188), v3(0, 0, 166), 18 }, -- l'avenue de l'entrée
	{ v3(16, 0, 155), v3(50, 0, 159), 10 }, -- vers la mini-ferme
	{ v3(-16, 0, 151), v3(-50, 0, 152), 10 }, -- vers l'espace des cerfs
	{ v3(0, 0, 134), v3(0, 0, 104), 15 }, -- vers la grande boucle
}
local PLAZA_RECTS = {
	{ -18, 18, 184, 201 }, -- devant l'entrée
	{ -34, -9, 172, 194 }, -- la cour de la réserve
}
-- Les petits belvédères ronds où les visiteurs s'arrêtent devant chaque espace (en plus de l'allée).
local BAYS = {}
for _, plot in Config.PLOTS do
	table.insert(BAYS, plot.view)
end

local function onPath(x: number, z: number): boolean
	local half = Config.PATH_WIDTH / 2
	local loop = Config.LOOP
	for i = 1, #loop - 1 do
		if segmentDistance(x, z, loop[i], loop[i + 1]) <= half then
			return true
		end
	end
	for _, link in LINKS do
		if segmentDistance(x, z, link[1], link[2]) <= link[3] / 2 then
			return true
		end
	end
	for _, bay in BAYS do
		local dx, dz = x - bay.X, z - bay.Z
		if dx * dx + dz * dz <= 36 then
			return true
		end
	end
	-- La place : un rond autour de la fontaine, une avenue depuis l'entrée, des allées vers la mini-ferme, l'espace des
	-- cerfs et la grande boucle, la cour de la réserve ; le reste est en herbe et en fleurs.
	local dx, dz = x, z - PLAZA_CENTER.Z
	if dx * dx + dz * dz <= 20 * 20 then
		return true
	end
	for _, link in PLAZA_LINKS do
		if segmentDistance(x, z, link[1], link[2]) <= link[3] / 2 then
			return true
		end
	end
	for _, rect in PLAZA_RECTS do
		if x >= rect[1] and x <= rect[2] and z >= rect[3] and z <= rect[4] then
			return true
		end
	end
	return false
end
Map.onPath = onPath

-- La route du bus (au sud, dans la vallée) et la file d'attente.
local function onRoad(x: number, z: number): boolean
	if z < 198 then
		return false
	end
	return math.abs(x) <= 20 and z <= EXTENT
end

-- Le lac : son bord est un peu irrégulier.
local function lakeRadius(x: number, z: number): (number, number)
	local lake = Config.LAKE
	local dx, dz = x - lake.center.X, z - lake.center.Z
	local angle = math.atan2(dz, dx)
	local radius = lake.radius + math.sin(angle * 3) * 3 + math.cos(angle * 5) * 2
	return math.sqrt(dx * dx + dz * dz), radius
end

-- La hauteur du sol (0 dans le parc ; les montagnes autour).
local function groundHeight(x: number, z: number): number
	local d = math.max(math.abs(x), math.abs(z))
	if d <= ZOO then
		return 0
	end
	local t = d - ZOO
	local ramp = math.clamp(t / 60, 0, 1)
	local hills = math.noise(x / 120, z / 120, 0.37) * 60 + math.noise(x / 40, z / 40, 4.1) * 12
	local h = t * 0.62 + hills * ramp + 6 * ramp
	-- La vallée de la route, au sud.
	if z > ZOO - 4 then
		h *= math.clamp((math.abs(x) - 30) / 70, 0, 1)
	end
	return math.clamp(h, 0, 200)
end
Map.groundHeight = groundHeight

-- LE TERRAIN, écrit par morceaux (WriteVoxels).
local function buildTerrain()
	local cells = EXTENT * 2 / RES
	local CHUNK = 32
	for cx = 0, cells - 1, CHUNK do
		for cz = 0, cells - 1, CHUNK do
			local nx, nz = math.min(CHUNK, cells - cx), math.min(CHUNK, cells - cz)
			-- La hauteur et le sol de chaque colonne du morceau.
			local heights, tops, maxHeight = {}, {}, 0
			for ix = 1, nx do
				heights[ix], tops[ix] = {}, {}
				for iz = 1, nz do
					local x = -EXTENT + (cx + ix - 0.5) * RES
					local z = -EXTENT + (cz + iz - 0.5) * RES
					local h = groundHeight(x, z)
					local top = M.Grass
					local water = nil
					local distance, radius = lakeRadius(x, z)
					if distance < radius then
						-- Le lac : un fond en cuvette, l'eau jusqu'à 1 sous le sol.
						local depth = 9 * (1 - (distance / radius) ^ 2) + 1.5
						h = -depth
						top = M.Sand
						water = -1
					elseif distance < radius + 4 then
						top = M.Sand
						h = -1 + (distance - radius) / 4
					elseif onRoad(x, z) then
						top = M.Asphalt
					elseif math.max(math.abs(x), math.abs(z)) <= ZOO and onPath(x, z) then
						top = M.Pavement
					elseif h > 0 then
						local slope = (math.abs(groundHeight(x + RES, z) - groundHeight(x - RES, z)) + math.abs(groundHeight(x, z + RES) - groundHeight(x, z - RES))) / (RES * 2)
						top = if slope > 1.25 or h > 150 then M.Rock elseif slope > 0.95 then M.Ground else M.LeafyGrass
					elseif math.max(math.abs(x), math.abs(z)) > ZOO - 18 then
						top = M.LeafyGrass
					end
					heights[ix][iz] = { h = h, top = top, water = water }
					maxHeight = math.max(maxHeight, h)
				end
			end
			local ny = math.ceil((maxHeight - BOTTOM) / RES) + 1
			local materials, occupancy = {}, {}
			for ix = 1, nx do
				materials[ix], occupancy[ix] = {}, {}
				for iy = 1, ny do
					materials[ix][iy], occupancy[ix][iy] = {}, {}
					local y0 = BOTTOM + (iy - 1) * RES
					for iz = 1, nz do
						local column = heights[ix][iz]
						-- (Une case pleine sous une case vide fait un sol au MILIEU de la case vide : le sol est à
						-- « milieu de la dernière case pleine + remplissage x 4 ». Pour un sol à h, la case dont le
						-- milieu est juste sous h est remplie de (h - milieu) / 4.)
						local fill = math.clamp((column.h - (y0 + RES / 2)) / RES, 0, 1)
						local material = M.Air
						local amount = 0
						if fill > 0 then
							material = if column.h - y0 <= RES then column.top elseif column.h - y0 <= RES * 3 and column.top ~= M.Rock then M.Ground else M.Rock
							amount = fill
						elseif column.water and y0 + RES / 2 < column.water then
							material = M.Water
							amount = math.clamp((column.water - (y0 + RES / 2)) / RES, 0, 1)
						end
						-- (Au fond de l'eau, la case de sol est pleine : pas d'air entre le sol et l'eau.)
						if fill > 0 and column.water then
							material, amount = column.top, 1
						end
						materials[ix][iy][iz] = material
						occupancy[ix][iy][iz] = amount
					end
				end
			end
			local corner = v3(-EXTENT + cx * RES, BOTTOM, -EXTENT + cz * RES)
			local region = Region3.new(corner, corner + v3(nx * RES, ny * RES, nz * RES))
			terrain:WriteVoxels(region, RES, materials, occupancy)
		end
		task.wait()
	end
end

-- LE LAC : des rochers autour, une falaise au nord avec sa cascade, des nénuphars.
local function buildLake(random: Random)
	local lake = Config.LAKE
	local center = lake.center
	-- La falaise de la cascade, au nord du lac.
	local cliff = center + v3(0, 0, -lake.radius - 2)
	for i = 1, 9 do
		local spot = cliff + v3(random:NextNumber(-14, 14), random:NextNumber(0, 14), random:NextNumber(-6, 3))
		terrain:FillBall(spot, random:NextNumber(6, 10), M.Rock)
	end
	terrain:FillBall(cliff + v3(-4, 18, -2), 8, M.Rock)
	terrain:FillBall(cliff + v3(5, 17, -3), 7, M.Rock)
	terrain:FillBall(cliff + v3(0, 22, -5), 6, M.LeafyGrass)
	-- Le creux d'où sort l'eau, puis la chute.
	local top = cliff + v3(0, 21, 4)
	local fall = part(folder, "Waterfall", v3(7, 22, 1.2), CFrame.new(cliff + v3(0, 10.5, 6.4)) * CFrame.Angles(math.rad(-8), 0, 0), rgb(196, 232, 240), M.Glass)
	fall.Transparency = 0.35
	fall.CastShadow = false
	local foam = part(folder, "Foam", v3(10, 0.6, 6), cliff + v3(0, -0.6, 9), rgb(240, 250, 255), M.Snow)
	foam.Transparency = 0.2
	local mist = Instance.new("ParticleEmitter")
	mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
	mist.Color = ColorSequence.new(rgb(255, 255, 255))
	mist.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	mist.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 8) })
	mist.Lifetime = NumberRange.new(1.5, 2.5)
	mist.Rate = 14
	mist.Speed = NumberRange.new(2, 4)
	mist.SpreadAngle = Vector2.new(60, 60)
	mist.Parent = foam
	local stream = Instance.new("ParticleEmitter")
	stream.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	stream.Color = ColorSequence.new(rgb(220, 245, 255))
	stream.Transparency = NumberSequence.new(0.4)
	stream.Size = NumberSequence.new(0.6)
	stream.Lifetime = NumberRange.new(1, 1.2)
	stream.Rate = 30
	stream.Speed = NumberRange.new(14, 18)
	stream.Acceleration = v3(0, -20, 0)
	stream.EmissionDirection = Enum.NormalId.Bottom
	stream.Parent = fall
	_ = top
	-- Des rochers sur le bord.
	for i = 1, 14 do
		local angle = i / 14 * math.pi * 2 + random:NextNumber(-0.2, 0.2)
		if math.sin(angle) > -0.6 then -- (pas devant la falaise)
			local _, radius = lakeRadius(center.X + math.cos(angle), center.Z + math.sin(angle))
			local spot = center + v3(math.cos(angle) * (radius + 1), -0.5, math.sin(angle) * (radius + 1))
			terrain:FillBall(spot, random:NextNumber(2, 3.6), M.Rock)
		end
	end
	-- Des nénuphars.
	for _ = 1, 12 do
		local angle, distance = random:NextNumber(0, math.pi * 2), random:NextNumber(6, lake.radius - 6)
		local pad = part(folder, "LilyPad", v3(0.2, 2.6, 2.6), CFrame.new(center + v3(math.cos(angle) * distance, -0.85, math.sin(angle) * distance)) * CFrame.Angles(0, 0, math.rad(90)), rgb(70, 140, 60), M.Grass)
		pad.Shape = Enum.PartType.Cylinder
		pad.CastShadow = false
		if random:NextNumber() < 0.4 then
			Props.ball(folder, "Lily", 0.8, pad.Position + v3(0.4, 0.3, 0), rgb(250, 210, 230))
		end
	end
	-- Un petit pont de bois au sud du lac ? (Non : le lac est entouré de jardin, les visiteurs le voient de la boucle.)
end

-- L'ENTRÉE : deux pavillons, un grand portique avec l'enseigne, la cabine du caissier entre l'entrée et la sortie, les
-- tourniquets et les barrières de la file d'attente.
local entranceSign: TextLabel? = nil
local function buildEntrance()
	local gate = Config.GATE
	local z = gate.booth.Z
	local south = v3(0, 0, 1)
	-- Les deux pavillons (le magasin de souvenirs et les bureaux, pour le décor).
	for _, x in { -26, 26 } do
		Props.lodge(folder, CFrame.lookAt(v3(x, 0, z), v3(x, 0, z) + south), 20, 12, 10, { door = 4, rise = 6 })
	end
	-- Le portique : quatre grands poteaux, une poutre, un toit, l'enseigne.
	for _, x in { -15, -3.5, 3.5, 15 } do
		part(folder, "GatePost", v3(1.8, 16, 1.8), v3(x, 8, z + 4), Props.WOOD, M.Wood, true)
		part(folder, "GatePost", v3(1.8, 16, 1.8), v3(x, 8, z - 4), Props.WOOD, M.Wood, true)
	end
	part(folder, "GateBeam", v3(33, 1.4, 1.6), v3(0, 15.5, z + 4), Props.WOOD, M.Wood)
	part(folder, "GateBeam", v3(33, 1.4, 1.6), v3(0, 15.5, z - 4), Props.WOOD, M.Wood)
	part(folder, "Eave", v3(36, 0.6, 13), v3(0, 16.5, z), Props.WOOD, M.Wood)
	Props.roof(folder, CFrame.new(0, 16.8, z), 38, 14, 6.5, Props.THATCH, M.Grass)
	local board = part(folder, "ZooSign", v3(22, 4.4, 0.6), v3(0, 12.4, z + 5.2), Props.WOOD, M.WoodPlanks)
	entranceSign = Props.label(board, Enum.NormalId.Back, "ZOO")
	local inside = part(folder, "ZooSignIn", v3(16, 3, 0.6), v3(0, 12.4, z - 5.2), Props.WOOD, M.WoodPlanks)
	Props.label(inside, Enum.NormalId.Front, "À bientôt !")
	-- La cabine du caissier : un comptoir côté entrée (à l'est), une porte côté place (au nord).
	local booth = gate.booth
	part(folder, "BoothFloor", v3(7, 0.6, 9), booth + v3(0, 0.3, 0), Props.WOOD_LIGHT, M.WoodPlanks, true)
	part(folder, "BoothWall", v3(7, 8, 0.6), booth + v3(0, 4, 4.5), Props.WOOD, M.WoodPlanks, true) -- côté file
	part(folder, "BoothWall", v3(0.6, 8, 9), booth + v3(-3.5, 4, 0), Props.WOOD, M.WoodPlanks, true) -- côté sortie
	part(folder, "BoothWall", v3(0.6, 3.6, 9), booth + v3(3.5, 1.8, 0), Props.WOOD, M.WoodPlanks, true) -- sous le guichet
	part(folder, "BoothCounter", v3(1.8, 0.4, 9.4), booth + v3(3.6, 3.8, 0), Props.WOOD_LIGHT, M.Wood, true)
	part(folder, "BoothTop", v3(0.6, 1.4, 9), booth + v3(3.5, 7.3, 0), Props.WOOD, M.WoodPlanks, true)
	part(folder, "BoothRoof", v3(8.4, 0.5, 10.4), booth + v3(0, 8.2, 0), Props.ROOF, M.Slate)
	-- Le scanner sur le comptoir (son écran devient vert à chaque billet).
	local scanner = part(folder, "Scanner", v3(0.8, 0.9, 1.2), booth + v3(3.2, 4.45, -1.5), Props.IRON, M.Metal)
	local screen = part(folder, "ScannerScreen", v3(0.1, 0.6, 0.9), booth + v3(3.65, 4.5, -1.5), rgb(60, 220, 120), M.Neon)
	Map.scanner = scanner
	Map.scannerScreen = screen
	-- Les tourniquets.
	for _, spot in { gate.turnstile, gate.exit } do
		part(folder, "Turnstile", v3(1.2, 3.2, 1.2), spot + v3(-2.6, 1.6, 0), rgb(150, 154, 160), M.Metal, true)
		part(folder, "Turnstile", v3(1.2, 3.2, 1.2), spot + v3(2.6, 1.6, 0), rgb(150, 154, 160), M.Metal, true)
		part(folder, "TurnstileBar", v3(4, 0.25, 0.25), spot + v3(0, 2.6, 0), rgb(200, 204, 210), M.Metal)
	end
	-- Les barrières de la file d'attente (des poteaux et des cordes), jusqu'au bout de la queue.
	local first = gate.queueFirst
	local last = first + gate.queueStep * (gate.queueCount - 1)
	for _, x in { first.X - 3, first.X + 3 } do
		local count = math.ceil((last.Z - first.Z + 4) / 4.2)
		for i = 0, count do
			local spot = v3(x, 0, first.Z - 2 + i * 4.2)
			part(folder, "QueuePost", v3(0.5, 3.2, 0.5), spot + v3(0, 1.6, 0), rgb(196, 160, 60), M.Metal, true)
			if i < count then
				part(folder, "QueueRope", v3(0.25, 0.25, 4.2), spot + v3(0, 2.8, 2.1), rgb(150, 40, 46), M.Fabric).CastShadow = false
			end
		end
	end
	Props.sign(folder, v3(first.X + 9, 0, first.Z + 8), v3(-1, 0, 0), "Billets", 6)
	-- Le mur de la place, de chaque côté de l'entrée, jusqu'aux espaces.
	for _, x in { -1, 1 } do
		local from, to = v3(x * 36.5, 0, 199), v3(x * 54, 0, 199)
		part(folder, "Wall", v3((to - from).Magnitude, 4, 1.6), CFrame.lookAt((from + to) / 2 + v3(0, 2, 0), to + v3(0, 2, 0)) * CFrame.Angles(0, math.rad(90), 0), Props.STONE, M.Cobblestone, true)
	end
	-- Le bus des visiteurs.
	local bus = Instance.new("Model")
	bus.Name = "Bus"
	local busAt = v3(0, 0, Config.BUS.Z + 6)
	part(bus, "Body", v3(30, 9, 9), busAt + v3(0, 5.6, 0), rgb(236, 196, 70), M.SmoothPlastic, true)
	part(bus, "Windows", v3(28, 2.6, 9.2), busAt + v3(0, 7.4, 0), rgb(40, 52, 64), M.Glass)
	part(bus, "Stripe", v3(30.2, 0.8, 9.2), busAt + v3(0, 3.6, 0), rgb(46, 110, 70))
	for _, x in { -10, 10 } do
		for _, zz in { -4.6, 4.6 } do
			local wheel = part(bus, "Wheel", v3(1.2, 3.4, 3.4), busAt + v3(x, 1.7, zz), rgb(30, 30, 32), M.Rubber)
			wheel.Shape = Enum.PartType.Cylinder
			wheel.CFrame = CFrame.new(wheel.Position) * CFrame.Angles(0, math.rad(90), 0)
		end
	end
	bus.Parent = folder
end

-- LA PLACE : une fontaine au milieu d'un rond, des îlots d'herbe avec des palmiers, des fleurs, des bancs, des
-- lampadaires. (Rien sur le chemin des visiteurs : Visitors.luau, PLAZA_TOUR et EXIT_TOUR.)
local function buildPlaza(random: Random)
	local center = PLAZA_CENTER
	local basin = part(folder, "Fountain", v3(1.8, 18, 18), CFrame.new(center + v3(0, 0.9, 0)) * CFrame.Angles(0, 0, math.rad(90)), Props.STONE, M.Cobblestone, true)
	basin.Shape = Enum.PartType.Cylinder
	local water = part(folder, "FountainWater", v3(0.3, 16.2, 16.2), CFrame.new(center + v3(0, 1.7, 0)) * CFrame.Angles(0, 0, math.rad(90)), rgb(70, 150, 170), M.Glass)
	water.Shape = Enum.PartType.Cylinder
	water.Transparency = 0.3
	Props.stick(folder, "FountainPillar", center + v3(0, 1, 0), center + v3(0, 7, 0), 2.2, Props.STONE, M.Cobblestone, true)
	local bowl = part(folder, "FountainBowl", v3(0.8, 7, 7), CFrame.new(center + v3(0, 7, 0)) * CFrame.Angles(0, 0, math.rad(90)), Props.STONE, M.Cobblestone)
	bowl.Shape = Enum.PartType.Cylinder
	local jet = Instance.new("ParticleEmitter")
	jet.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	jet.Color = ColorSequence.new(rgb(210, 240, 255))
	jet.Size = NumberSequence.new(0.5)
	jet.Lifetime = NumberRange.new(1, 1.3)
	jet.Rate = 40
	jet.Speed = NumberRange.new(8, 10)
	jet.SpreadAngle = Vector2.new(12, 12)
	jet.Acceleration = v3(0, -16, 0)
	jet.Parent = bowl
	-- Un anneau de fleurs autour du bassin.
	for i = 1, 26 do
		local angle = i / 26 * math.pi * 2
		Props.ball(folder, "Flower", 0.9, center + v3(math.cos(angle) * 9.9, 1.9, math.sin(angle) * 9.9), if i % 2 == 0 then rgb(236, 84, 96) else rgb(252, 196, 64))
	end
	-- Les îlots d'herbe.
	for _, x in { -1, 1 } do
		Props.flowerBed(folder, v3(x * 33, 0, 138), 4.5, random)
		Props.palm(folder, v3(x * 44, 0, 127), random, 1)
		Props.tree(folder, v3(x * 27, 0, 126), random, 0.85)
		Props.bush(folder, v3(x * 45, 0, 142), random, 1.2, true)
		Props.bench(folder, v3(x * 25, 0, 139), v3(-x, 0, 0.4))
		Props.palm(folder, v3(x * 14, 0, 170), random, 0.85)
		Props.lamp(folder, v3(x * 12, 0, 182))
		Props.lamp(folder, v3(x * 24, 0, 160))
	end
	Props.flowerBed(folder, v3(33, 0, 182), 4, random)
	Props.palm(folder, v3(44, 0, 192), random, 1)
	Props.bush(folder, v3(26, 0, 174), random, 1.1, true)
	Props.bush(folder, v3(44, 0, 172), random, 1)
	Props.bench(folder, v3(28, 0, 166), v3(-0.6, 0, -1))
	Props.flowerBed(folder, v3(-42, 0, 164), 3, random)
	Props.bush(folder, v3(-14, 0, 176), random, 0.9, true)
	Props.bin(folder, v3(12, 0, 188))
	Props.bin(folder, v3(-22, 0, 142))
	Props.sign(folder, v3(24, 0, 193), v3(0, 0, -1), "Bienvenue au zoo !", 12)
end

-- LA RÉSERVE : le foin, le grain, la viande et les trousses de soins, sur un grand comptoir (les points où on les
-- prend sont dans Map.store, pour Tasks.luau).
Map.store = {}
local function buildStore()
	local store = Config.STORE
	local base = CFrame.lookAt(store.center, store.center + store.facing)
	Props.lodge(folder, base, 16, 10, 9, { openFront = true, title = "RÉSERVE", rise = 5 })
	-- Ce qu'il y a derrière le comptoir.
	local items = { "hay", "grain", "meat", "kit" }
	for i, kind in items do
		local x = -6 + (i - 1) * 4
		local spot = base * CFrame.new(x, 0, -2)
		if kind == "hay" then
			for j = 0, 2 do
				part(folder, "HayBale", v3(3, 1.6, 2.2), spot * CFrame.new(0, 1.6 + j * 1.6, 2), Config.FOODS.hay.color, M.Grass, true)
			end
		elseif kind == "grain" then
			for j = 0, 2 do
				Props.ball(folder, "GrainSack", 2.2, (spot * CFrame.new((j - 1) * 0.6, 1.8 + j * 0.9, 2)).Position, rgb(222, 206, 166), M.Fabric)
			end
		elseif kind == "meat" then
			part(folder, "Freezer", v3(3.4, 3.6, 2.4), spot * CFrame.new(0, 2.6, 2), rgb(236, 240, 244), M.Metal, true)
		else
			local box = part(folder, "Kit", v3(3, 2.2, 1.8), spot * CFrame.new(0, 2, 2), rgb(244, 244, 244), M.SmoothPlastic, true)
			Props.label(box, Enum.NormalId.Front, "+", rgb(220, 50, 50))
			_ = box
		end
		-- Le point du comptoir où l'on prend la chose (devant le comptoir, côté place).
		local counter = part(folder, "Take_" .. kind, v3(3.4, 0.4, 1.4), base * CFrame.new(x, 4.4, -5.6), Props.WOOD_LIGHT, M.Wood)
		counter.CanQuery = true
		Map.store[kind] = counter
	end
end

-- LA VÉGÉTATION : des forêts tropicales tout autour du parc, sur les pentes, le long des allées, autour du lac.
local slots = {}
local function insideSpace(x: number, z: number, margin: number): boolean
	for _, rect in slots do
		if math.abs(x - rect.center.X) <= rect.half.X + margin and math.abs(z - rect.center.Z) <= rect.half.Y + margin then
			return true
		end
	end
	return false
end
function Map.isFree(x: number, z: number, margin: number): boolean
	if insideSpace(x, z, margin) or onRoad(x, z) then
		return false
	end
	-- Pas sur les allées ni trop près.
	local half = Config.PATH_WIDTH / 2 + margin
	local loop = Config.LOOP
	for i = 1, #loop - 1 do
		if segmentDistance(x, z, loop[i], loop[i + 1]) <= half then
			return false
		end
	end
	for _, link in LINKS do
		if segmentDistance(x, z, link[1], link[2]) <= link[3] / 2 + margin then
			return false
		end
	end
	local plaza = Config.PLAZA
	if x >= plaza.min.X - margin and x <= plaza.max.X + margin and z >= plaza.min.Z - margin and z <= plaza.max.Z + margin then
		return false
	end
	local distance, radius = lakeRadius(x, z)
	return distance > radius + 3 + margin
end

local function buildPlants(random: Random)
	local plants = Instance.new("Folder")
	plants.Name = "Plants"
	plants.Parent = folder
	-- 1. La lisière de jungle tout autour du parc et sur le bas des pentes.
	local placed = 0
	for _ = 1, 2200 do
		if placed >= 300 then
			break
		end
		local x, z = random:NextNumber(-330, 330), random:NextNumber(-330, 330)
		local d = math.max(math.abs(x), math.abs(z))
		local h = groundHeight(x, z)
		if d > 188 and h < 70 and Map.isFree(x, z, 4) then
			local roll = random:NextNumber()
			local at = v3(x, h, z)
			if roll < 0.32 then
				Props.jungleTree(plants, at, random)
			elseif roll < 0.6 then
				Props.palm(plants, at, random, 1.1)
			elseif roll < 0.85 then
				Props.tree(plants, at, random, 1.1)
			else
				Props.bush(plants, at, random, 1.4)
			end
			placed += 1
		end
	end
	-- 2. Le long de la grande allée, des deux côtés : palmiers, arbres, buissons fleuris, fougères, lampadaires.
	local loop = Config.LOOP
	local lampCount = 0
	for i = 1, #loop - 1 do
		local a, b = loop[i], loop[i + 1]
		local length = (b - a).Magnitude
		local direction = (b - a).Unit
		local side = v3(-direction.Z, 0, direction.X)
		local count = math.floor(length / 13)
		for j = 1, count do
			local along = a + direction * (j - 0.5) * length / count
			for _, sign in { -1, 1 } do
				local spot = along + side * sign * (Config.PATH_WIDTH / 2 + random:NextNumber(2.5, 5))
				if Map.isFree(spot.X, spot.Z, 1) then
					local roll = random:NextNumber()
					if roll < 0.28 then
						Props.palm(plants, spot, random)
					elseif roll < 0.45 then
						Props.tree(plants, spot + side * sign * 3, random, 0.9)
					elseif roll < 0.75 then
						Props.bush(plants, spot, random, 1, random:NextNumber() < 0.5)
					else
						Props.fern(plants, spot, random, 1.2)
					end
				end
			end
			if j % 3 == 0 then
				lampCount += 1
				local spot = along + side * (if lampCount % 2 == 0 then 1 else -1) * (Config.PATH_WIDTH / 2 + 0.8)
				if Map.isFree(spot.X, spot.Z, 0) then
					Props.lamp(folder, spot)
				end
			end
		end
	end
	-- 3. Le jardin du lac, au milieu de la boucle : palmiers, fougères, parterres, bancs.
	local lake = Config.LAKE
	for i = 1, 22 do
		local angle = i / 22 * math.pi * 2 + random:NextNumber(-0.1, 0.1)
		local _, radius = lakeRadius(lake.center.X + math.cos(angle), lake.center.Z + math.sin(angle))
		local spot = lake.center + v3(math.cos(angle) * (radius + random:NextNumber(6, 12)), 0, math.sin(angle) * (radius + random:NextNumber(6, 12)))
		if Map.isFree(spot.X, spot.Z, 1) then
			if i % 3 == 0 then
				Props.palm(plants, spot, random, 1.15)
			elseif i % 3 == 1 then
				Props.fern(plants, spot, random, 1.4)
			else
				Props.bush(plants, spot, random, 1.2, true)
			end
		end
	end
	for _ = 1, 260 do
		local x, z = random:NextNumber(-100, 100), random:NextNumber(-100, 100)
		if Map.isFree(x, z, 2) then
			local roll = random:NextNumber()
			if roll < 0.2 then
				Props.tree(plants, v3(x, 0, z), random, 0.9)
			elseif roll < 0.4 then
				Props.palm(plants, v3(x, 0, z), random)
			elseif roll < 0.75 then
				Props.fern(plants, v3(x, 0, z), random, 1.3)
			else
				Props.bush(plants, v3(x, 0, z), random, 1, true)
			end
		end
	end
	-- 4. Entre les espaces et le bord : des buissons et des arbres, pour que les espaces paraissent dans la nature.
	for _ = 1, 500 do
		local x, z = random:NextNumber(-200, 200), random:NextNumber(-200, 200)
		local d = math.max(math.abs(x), math.abs(z))
		if d > 112 and d < 196 and Map.isFree(x, z, 3) then
			if random:NextNumber() < 0.5 then
				Props.bush(plants, v3(x, 0, z), random, 1.3)
			else
				Props.tree(plants, v3(x, 0, z), random)
			end
		end
	end
	-- 5. Des rochers sur les pentes.
	for _ = 1, 140 do
		local x, z = random:NextNumber(-EXTENT + 20, EXTENT - 20), random:NextNumber(-EXTENT + 20, EXTENT - 20)
		local h = groundHeight(x, z)
		if h > 6 then
			terrain:FillBall(v3(x, h, z), random:NextNumber(4, 11), M.Rock)
		end
	end
end

-- LE SOIR : les lampadaires s'allument, il fait nuit.
function Map.setClock(hours: number)
	Lighting.ClockTime = hours % 24
	local night = hours >= 18.6 or hours < 7
	if night == Map.night then
		return
	end
	Map.night = night
	for _, light in folder:GetDescendants() do
		if light:IsA("PointLight") and light.Name == "NightLight" then
			light.Enabled = night
		end
	end
end

-- Le nom du zoo sur l'enseigne de l'entrée (le zoo de l'hôte).
function Map.setName(name: string)
	if entranceSign then
		entranceSign.Text = name
	end
end

function Map.build()
	folder = Instance.new("Folder")
	folder.Name = "Park"
	folder.Parent = workspace
	Map.folder = folder
	for _, plot in Config.PLOTS do
		table.insert(slots, { center = plot.center, half = plot.size / 2 })
	end
	for _, building in Config.BUILDINGS do
		table.insert(slots, { center = building.center, half = building.size / 2 + Vector2.new(2, 2) })
	end
	table.insert(slots, { center = Config.STORE.center, half = Vector2.new(9, 11) })
	light()
	colors()
	buildTerrain()
	local random = Random.new(14102026)
	buildLake(random)
	buildEntrance()
	buildPlaza(random)
	buildStore()
	buildPlants(random)
	-- L'endroit où le joueur apparaît : sur la place, face au zoo.
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Size = v3(8, 1, 8)
	spawn.CFrame = CFrame.lookAt(Config.SPAWN, Config.SPAWN + v3(0, 0, -1))
	spawn.Anchored = true
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanQuery = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = folder
end

return Map

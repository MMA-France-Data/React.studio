-- L'HABILLAGE DU DÉCOR : la lumière du jeu, le paysage autour (herbe, arbres, collines, nuages), et tout ce qui rend
-- le lobby et les couloirs plus jolis (lampadaires, guirlandes de fanions, fontaine, grande porte des salles, tapis).
-- Rien ici ne change le jeu : presque tout se traverse, et les météorites ne le voient pas.
local Lighting = game:GetService("Lighting")

local Build = require(script.Parent.Build)

local Scenery = {}

local M = Enum.Material
local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end
local NAVY, GOLD, WARM = rgb(34, 40, 70), rgb(236, 176, 48), rgb(255, 226, 140)
local FLAGS = { rgb(255, 70, 70), rgb(255, 170, 40), rgb(255, 225, 60), rgb(80, 210, 90), rgb(60, 170, 255), rgb(180, 100, 255) }

-- Un bloc de décor : on passe à travers.
local function deco(parent: Instance, name: string, size: Vector3, cframe: CFrame | Vector3, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local part = Build.part(parent, name, size, cframe, color, material)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = size.Magnitude > 6
	if shape then
		part.Shape = shape
	end
	return part
end
local function ball(parent: Instance, name: string, diameter: number, position: Vector3, color: Color3, material: Enum.Material?): Part
	return deco(parent, name, Vector3.new(diameter, diameter, diameter), position, color, material, Enum.PartType.Ball)
end
local function pillar(parent: Instance, name: string, diameter: number, height: number, base: Vector3, color: Color3, material: Enum.Material?): Part
	local part = Build.disc(parent, name, diameter, height, base + Vector3.new(0, height / 2, 0), color, material)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	return part
end
local function glow(part: BasePart, range: number, brightness: number, color: Color3?)
	local light = Instance.new("PointLight")
	light.Color = color or WARM
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = part
end

-- LA LUMIÈRE : un bel après-midi, des couleurs vives, un peu de brume au loin et des nuages.
function Scenery.light()
	Lighting.ClockTime = 14.6
	Lighting.GeographicLatitude = 32
	Lighting.Brightness = 1.9
	Lighting.Ambient = rgb(118, 118, 132)
	Lighting.OutdoorAmbient = rgb(150, 152, 168)
	Lighting.ColorShift_Top = rgb(255, 240, 214)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.ShadowSoftness = 0.35
	Lighting.GlobalShadows = true
	local function effect(className: string, properties)
		local item = Lighting:FindFirstChildOfClass(className) or Instance.new(className)
		for name, value in properties do
			(item :: any)[name] = value
		end
		item.Parent = Lighting
	end
	effect("Atmosphere", { Density = 0.28, Offset = 0.2, Color = rgb(204, 228, 255), Decay = rgb(120, 170, 235), Glare = 0.15, Haze = 1.1 })
	effect("ColorCorrectionEffect", { Saturation = 0.08, Contrast = 0.05, Brightness = 0, TintColor = rgb(255, 250, 242) })
	effect("BloomEffect", { Intensity = 0.2, Size = 18, Threshold = 2.2 })
	effect("SunRaysEffect", { Intensity = 0.07, Spread = 0.7 })
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if terrain and not terrain:FindFirstChildOfClass("Clouds") then
		local clouds = Instance.new("Clouds")
		clouds.Cover = 0.52
		clouds.Density = 0.55
		clouds.Color = rgb(255, 255, 255)
		clouds.Parent = terrain
	end
end

-- Un arbre rond de dessin animé.
local function tree(parent: Instance, base: Vector3, scale: number, random: Random)
	local height = 13 * scale
	pillar(parent, "Trunk", 2.6 * scale, height, base, rgb(124, 82, 48), M.Wood)
	local greens = { rgb(64, 168, 70), rgb(82, 190, 80), rgb(50, 146, 64) }
	for i = 1, 3 do
		local offset = Vector3.new(random:NextNumber(-3, 3), random:NextNumber(-1, 4), random:NextNumber(-3, 3)) * scale
		ball(parent, "Leaves", random:NextNumber(13, 18) * scale, base + Vector3.new(0, height + 3 * scale, 0) + offset, greens[i], M.Grass)
	end
end

-- LE PAYSAGE autour du jeu : une grande prairie, des arbres derrière les murs du lobby, des collines au loin.
--   lobby : { halfX, back, front, wall } ; length : jusqu'où vont les salles (en Z).
function Scenery.land(parent: Instance, lobby, length: number)
	local folder = Instance.new("Folder")
	folder.Name = "Scenery"
	folder.Parent = parent
	local random = Random.new(7)
	local zMin, zMax = lobby.back - 380, length + 260
	local ground = deco(folder, "Ground", Vector3.new(1700, 4, zMax - zMin), Vector3.new(0, -2.3, (zMin + zMax) / 2), rgb(98, 190, 76), M.Grass)
	ground.CastShadow = false
	-- Deux rangées d'arbres le long des murs de côté et derrière le mur du fond.
	for ring = 1, 2 do
		local away = 6 + ring * 15
		for z = lobby.back - away, lobby.front + 30, 24 do
			for _, sign in { -1, 1 } do
				tree(folder, Vector3.new(sign * (lobby.halfX + away + random:NextNumber(-3, 3)), -0.3, z + random:NextNumber(-5, 5)), random:NextNumber(0.9, 1.25) + ring * 0.15, random)
			end
		end
		for x = -lobby.halfX, lobby.halfX, 24 do
			tree(folder, Vector3.new(x + random:NextNumber(-5, 5), -0.3, lobby.back - away - random:NextNumber(0, 4)), random:NextNumber(0.9, 1.25) + ring * 0.15, random)
		end
	end
	-- Les collines, loin : de très grosses boules à moitié enterrées, dans la brume.
	local hills = { rgb(96, 178, 96), rgb(78, 160, 98), rgb(112, 190, 104) }
	for i = 1, 14 do
		local side = if i % 2 == 0 then 1 else -1
		local size = random:NextNumber(260, 460)
		ball(folder, "Hill", size, Vector3.new(side * random:NextNumber(420, 640), -size * random:NextNumber(0.2, 0.32), zMin + 200 + (i - 1) * (zMax - zMin - 300) / 13), hills[i % 3 + 1], M.Grass).CastShadow = false
	end
	for i = 1, 4 do
		local size = random:NextNumber(300, 480)
		ball(folder, "Hill", size, Vector3.new(-450 + (i - 1) * 300, -size * 0.25, lobby.back - random:NextNumber(380, 460)), hills[i % 3 + 1], M.Grass).CastShadow = false
	end
	return folder
end

-- Un lampadaire avec, à son pied, un bac de fleurs.
local function lamp(parent: Instance, base: Vector3, random: Random)
	deco(parent, "LampPole", Vector3.new(0.8, 14, 0.8), base + Vector3.new(0, 7, 0), NAVY, M.Metal)
	deco(parent, "LampHead", Vector3.new(2.6, 0.6, 2.6), base + Vector3.new(0, 14.2, 0), NAVY, M.Metal)
	local bulb = ball(parent, "LampBulb", 1.9, base + Vector3.new(0, 13.2, 0), WARM, M.Neon)
	glow(bulb, 30, 0.9)
	local planter = Build.part(parent, "Planter", Vector3.new(4.2, 1.4, 4.2), base + Vector3.new(0, 0.7, 0), rgb(150, 96, 52), M.WoodPlanks)
	planter.CanQuery = false
	ball(parent, "Bush", 3.6, base + Vector3.new(0, 2.3, 0), rgb(70, 176, 74), M.Grass)
	for i = 1, 5 do
		local angle = i / 5 * math.pi * 2
		ball(parent, "Flower", 0.9, base + Vector3.new(math.cos(angle) * 1.5, 2.5 + random:NextNumber(0, 1.1), math.sin(angle) * 1.5), FLAGS[random:NextInteger(1, #FLAGS)])
	end
end

-- Une guirlande de fanions de toutes les couleurs, tendue entre deux points (elle pend un peu au milieu).
local function bunting(parent: Instance, from: Vector3, to: Vector3)
	local count = math.max(4, math.floor((to - from).Magnitude / 2))
	local previous = from
	for i = 1, count do
		local t = i / count
		local point = from:Lerp(to, t) - Vector3.new(0, math.sin(math.pi * t) * 2.2, 0)
		local middle = (previous + point) / 2
		deco(parent, "String", Vector3.new(0.12, 0.12, (point - previous).Magnitude), CFrame.lookAt(middle, point), rgb(250, 250, 250))
		if i < count then
			local flag = deco(parent, "Flag", Vector3.new(0.1, 1.9, 1.4), CFrame.lookAt(point, point + (to - from).Unit) * CFrame.new(0, -1, 0), FLAGS[(i - 1) % #FLAGS + 1])
			flag.CastShadow = false
		end
		previous = point
	end
end

-- LE LOBBY : le haut des murs et leurs piliers, les lampadaires et les guirlandes de l'allée, les bordures, la
-- fontaine, et la grande porte des salles (deux tours, un fronton à ampoules, un tapis rouge).
--   lobby : { halfX, back, front, wall, alley, doorWidth }
function Scenery.lobby(parent: Instance, lobby)
	local folder = Instance.new("Folder")
	folder.Name = "Decor"
	folder.Parent = parent
	local random = Random.new(11)
	local halfX, back, front, wall = lobby.halfX, lobby.back, lobby.front, lobby.wall
	local length = front - back

	-- Le haut des murs : un chapeau bleu nuit, une bande dorée, et un pilier à lanterne tous les 22 studs.
	local cream = rgb(250, 244, 226)
	for _, sign in { -1, 1 } do
		deco(folder, "WallCap", Vector3.new(3.4, 1.2, length + 4), Vector3.new(sign * (halfX + 0.75), wall + 0.6, (front + back) / 2), NAVY)
		deco(folder, "WallBand", Vector3.new(0.3, 1.4, length), Vector3.new(sign * (halfX - 0.1), wall - 2.4, (front + back) / 2), GOLD)
		deco(folder, "WallFoot", Vector3.new(0.5, 2.6, length), Vector3.new(sign * (halfX - 0.2), 1.3, (front + back) / 2), cream)
		for z = back + 11, front - 6, 22 do
			deco(folder, "WallPillar", Vector3.new(2.6, wall + 2.4, 2.6), Vector3.new(sign * (halfX + 0.2), (wall + 2.4) / 2, z), NAVY)
			glow(ball(folder, "Lantern", 2.2, Vector3.new(sign * (halfX + 0.2), wall + 3.4, z), WARM, M.Neon), 18, 0.6)
		end
	end
	for _, z in { back - 0.75, front + 0.75 } do
		deco(folder, "WallCap", Vector3.new(halfX * 2 + 7, 1.2, 3.4), Vector3.new(0, wall + 0.6, z), NAVY)
	end
	deco(folder, "WallBand", Vector3.new(halfX * 2, 1.4, 0.3), Vector3.new(0, wall - 2.4, back + 0.1), GOLD)
	deco(folder, "WallFoot", Vector3.new(halfX * 2, 2.6, 0.5), Vector3.new(0, 1.3, back + 0.2), cream)
	for x = -halfX + 12, halfX - 12, 24 do
		deco(folder, "WallPillar", Vector3.new(2.6, wall + 2.4, 2.6), Vector3.new(x, (wall + 2.4) / 2, back - 0.2), NAVY)
		glow(ball(folder, "Lantern", 2.2, Vector3.new(x, wall + 3.4, back - 0.2), WARM, M.Neon), 18, 0.6)
	end

	-- L'allée : une bordure claire de chaque côté, un chemin de dalles au milieu.
	for _, sign in { -1, 1 } do
		deco(folder, "Curb", Vector3.new(1, 0.3, length), Vector3.new(sign * (lobby.alley - 0.5), 0.15, (front + back) / 2), cream)
	end
	for z = back + 6, front - 6, 6 do
		deco(folder, "Slab", Vector3.new(9, 0.12, 4.4), Vector3.new(0, 0.06, z), rgb(236, 226, 200), M.Slate).CastShadow = false
	end

	-- Les lampadaires, des deux côtés de l'allée, et une guirlande de fanions de l'un à l'autre.
	local x = lobby.alley - 1.2
	for _, z in lobby.lamps do
		for _, sign in { -1, 1 } do
			lamp(folder, Vector3.new(sign * x, 0, z), random)
		end
		bunting(folder, Vector3.new(-x, 13.6, z), Vector3.new(x, 13.6, z))
	end
	-- Des guirlandes en biais, d'un lampadaire au suivant de l'autre côté.
	for i = 1, #lobby.lamps - 1 do
		local side = if i % 2 == 0 then 1 else -1
		-- (Pas au-dessus de la fontaine : la guirlande passerait dans son jet.)
		if lobby.fountain.Z < lobby.lamps[i] and lobby.fountain.Z > lobby.lamps[i + 1] then
			continue
		end
		bunting(folder, Vector3.new(side * x, 13.6, lobby.lamps[i]), Vector3.new(-side * x, 13.6, lobby.lamps[i + 1]))
	end

	-- La fontaine, au milieu de l'allée.
	local at = lobby.fountain
	local stone = rgb(214, 214, 224)
	local basin = Build.disc(folder, "Fountain", 18, 1.8, at + Vector3.new(0, 0.9, 0), stone, M.Marble)
	basin.CanQuery = false
	pillar(folder, "FountainRim", 19.4, 0.5, at + Vector3.new(0, 1.6, 0), NAVY)
	local water = pillar(folder, "Water", 16.4, 0.5, at + Vector3.new(0, 1.75, 0), rgb(70, 190, 255), M.Glass)
	water.Transparency = 0.15
	pillar(folder, "FountainStem", 2.6, 7, at + Vector3.new(0, 1.8, 0), stone, M.Marble)
	pillar(folder, "FountainBowl", 8, 0.9, at + Vector3.new(0, 8.4, 0), stone, M.Marble)
	pillar(folder, "Water", 6.6, 0.4, at + Vector3.new(0, 9.1, 0), rgb(70, 190, 255), M.Glass).Transparency = 0.15
	local top = ball(folder, "FountainTop", 2.4, at + Vector3.new(0, 10.8, 0), GOLD, M.Neon)
	local spray = Instance.new("ParticleEmitter")
	spray.Color = ColorSequence.new(rgb(190, 235, 255))
	spray.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.15) })
	spray.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	spray.Lifetime = NumberRange.new(1, 1.4)
	spray.Rate = 70
	spray.Speed = NumberRange.new(13, 17)
	spray.SpreadAngle = Vector2.new(22, 22)
	spray.Acceleration = Vector3.new(0, -34, 0)
	spray.EmissionDirection = Enum.NormalId.Top
	spray.LightEmission = 0.6
	spray.Parent = top

	-- LA GRANDE PORTE DES SALLES : deux tours, un fronton garni d'ampoules, des flammes et un tapis rouge.
	local door = lobby.doorWidth
	local towerX = lobby.alley
	for _, sign in { -1, 1 } do
		local base = Vector3.new(sign * towerX, 0, front - 4)
		local tower = Build.part(folder, "GateTower", Vector3.new(6, 26, 6), base + Vector3.new(0, 13, 0), NAVY)
		tower.CanQuery = false
		deco(folder, "GateTowerBand", Vector3.new(6.4, 1.2, 6.4), base + Vector3.new(0, 20, 0), GOLD)
		deco(folder, "GateTowerBand", Vector3.new(6.4, 1.2, 6.4), base + Vector3.new(0, 2, 0), GOLD)
		deco(folder, "GateTowerTop", Vector3.new(7.6, 1.4, 7.6), base + Vector3.new(0, 26.7, 0), GOLD)
		local flame = ball(folder, "GateFlame", 3.4, base + Vector3.new(0, 29.2, 0), rgb(255, 150, 40), M.Neon)
		glow(flame, 34, 1.4, rgb(255, 170, 70))
		local fire = Instance.new("Fire")
		fire.Size = 9
		fire.Heat = 12
		fire.Parent = flame
		-- Une bande de néon vert qui monte le long de la tour, du côté de la porte.
		deco(folder, "GateNeon", Vector3.new(0.4, 17, 0.8), base + Vector3.new(-sign * 3.1, 10.5, -1.5), rgb(90, 255, 110), M.Neon)
	end
	deco(folder, "GateBeam", Vector3.new(towerX * 2 + 6, 3.4, 5), Vector3.new(0, 22.4, front - 4), NAVY)
	deco(folder, "GateBeamBand", Vector3.new(towerX * 2 + 6.4, 0.6, 5.4), Vector3.new(0, 20.6, front - 4), GOLD)
	for i = 0, 10 do
		local bulb = ball(folder, "GateBulb", 1.1, Vector3.new(-towerX + 1 + i * (towerX * 2 - 2) / 10, 22.4, front - 6.7), if i % 2 == 0 then WARM else rgb(255, 255, 255), M.Neon)
		bulb.CastShadow = false
	end
	deco(folder, "Carpet", Vector3.new(door - 1, 0.14, 26), Vector3.new(0, 0.2, front - 13), rgb(206, 40, 56), M.Fabric).CastShadow = false
	for _, sign in { -1, 1 } do
		deco(folder, "CarpetEdge", Vector3.new(0.7, 0.16, 26), Vector3.new(sign * (door / 2 - 0.5), 0.21, front - 13), GOLD).CastShadow = false
	end
	return folder
end

-- UN COULOIR entre deux salles : un tapis rouge, deux arches avec une lampe, et des flèches vertes sur les murs.
function Scenery.sas(folder: Instance, zMin: number, length: number, half: number, height: number)
	deco(folder, "Carpet", Vector3.new(8, 0.14, length), Vector3.new(0, 0.07, zMin + length / 2), rgb(206, 40, 56), M.Fabric).CastShadow = false
	for _, sign in { -1, 1 } do
		deco(folder, "CarpetEdge", Vector3.new(0.6, 0.16, length), Vector3.new(sign * 4, 0.08, zMin + length / 2), GOLD).CastShadow = false
		deco(folder, "Skirting", Vector3.new(0.4, 1.6, length), Vector3.new(sign * (half - 0.2), 0.8, zMin + length / 2), NAVY)
	end
	for _, t in { 0.25, 0.75 } do
		local z = zMin + length * t
		deco(folder, "Arch", Vector3.new(half * 2, 1.4, 1.4), Vector3.new(0, height - 0.7, z), NAVY)
		for _, sign in { -1, 1 } do
			deco(folder, "ArchPost", Vector3.new(1.4, height, 1.4), Vector3.new(sign * (half - 0.7), height / 2, z), NAVY)
		end
		deco(folder, "LampRod", Vector3.new(0.25, 1.2, 0.25), Vector3.new(0, height - 2, z), NAVY, M.Metal)
		glow(ball(folder, "Lamp", 1.7, Vector3.new(0, height - 3.3, z), WARM, M.Neon), 24, 0.5)
	end
	-- Les flèches « par ici » : deux traits de néon qui se rejoignent vers la salle suivante.
	for _, t in { 0.5 } do
		local z = zMin + length * t
		for _, sign in { -1, 1 } do
			for _, tilt in { -1, 1 } do
				deco(folder, "Arrow", Vector3.new(0.3, 0.7, 3.4), CFrame.new(sign * (half - 0.2), 7 + tilt * 0.95, z) * CFrame.Angles(math.rad(tilt * 34), 0, 0), rgb(90, 255, 110), M.Neon).CastShadow = false
			end
		end
	end
end

return Scenery

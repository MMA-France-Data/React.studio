-- Le style de chaque salle : les matières du sol et des murs, les décors le long des murs, et l'habillage des
-- plateformes des parcours. Tout est fait de blocs et des matières fournies par Roblox (aucune image à mettre en
-- ligne). Les décors ne gênent jamais le jeu : on passe à travers, et les météorites ne les voient pas.
--
-- Pour changer le style d'une salle : changer son nom dans Themes.ROOMS. Pour retoucher un style : sa fiche dans
-- DEFS (matières, couleurs) et sa fonction `decor`.
local Themes = {}

-- Le style de la salle 1, de la salle 2, etc.
Themes.ROOMS = { "Warehouse", "Desert", "Bunker", "Volcano", "Jungle", "Concert", "Mine", "Crypt", "Ice", "Castle" }

local M = Enum.Material
local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end
local PURPLE = rgb(170, 100, 255) -- la couleur des grandes marches, dans toutes les salles

-- OUTILS DE DÉCOR -----------------------------------------------------------------------------------------------------
local function decorPart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or M.SmoothPlastic
	part.Shape = shape or Enum.PartType.Block
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function glow(part: BasePart, color: Color3, range: number, brightness: number?)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness or 1.2
	light.Shadows = false
	light.Parent = part
end

-- Ce qu'une fonction `decor` reçoit : la salle, et de quoi poser des choses le long des murs.
--   d.part(nom, taille, cframe, couleur, matière, forme) : un bloc de décor
--   d.walls(écart, fonction(cframe, n)) : appelle la fonction à intervalles réguliers le long des quatre murs ;
--       cframe est au pied du mur, tourné vers l'intérieur de la salle (hors des portes)
--   d.torch(cframe, couleur) : une torche accrochée au mur
--   d.top : hauteur jusqu'où décorer (les salles de parcours sont très hautes)
local function context(folder: Instance, room, def)
	local d = { room = room, def = def, top = math.min(room.height, 38) }
	local center, halfX, halfZ = room.center, 35, (room.zMax - room.zMin) / 2 - 0.75

	function d.part(name, size, cframe, color, material, shape)
		return decorPart(folder, name, size, cframe, color, material, shape)
	end

	function d.walls(spacing: number, callback: (CFrame, number) -> ())
		local n = 0
		-- Les deux murs de côté.
		local count = math.floor(halfZ * 2 / spacing)
		for i = 1, count do
			local z = center.Z - halfZ + (i - 0.5) * (halfZ * 2 / count)
			n += 1
			callback(CFrame.lookAt(Vector3.new(-halfX, 0, z), Vector3.new(0, 0, z)), n)
			n += 1
			callback(CFrame.lookAt(Vector3.new(halfX, 0, z), Vector3.new(0, 0, z)), n)
		end
		-- Les murs de l'entrée et de la sortie, sans leur porte.
		count = math.floor(halfX * 2 / spacing)
		for i = 1, count do
			local x = -halfX + (i - 0.5) * (halfX * 2 / count)
			if math.abs(x) > 10 then
				n += 1
				callback(CFrame.lookAt(Vector3.new(x, 0, center.Z - halfZ), Vector3.new(x, 0, center.Z)), n)
				n += 1
				callback(CFrame.lookAt(Vector3.new(x, 0, center.Z + halfZ), Vector3.new(x, 0, center.Z)), n)
			end
		end
	end

	function d.torch(cframe: CFrame, color: Color3)
		d.part("TorchArm", Vector3.new(0.4, 0.4, 1.4), cframe * CFrame.new(0, 9, -0.7), rgb(60, 50, 44), M.Metal)
		d.part("TorchCup", Vector3.new(1, 1.2, 1), cframe * CFrame.new(0, 9.4, -1.5), rgb(70, 60, 52), M.Metal)
		local flame = d.part("TorchFlame", Vector3.new(0.9, 1.3, 0.9), cframe * CFrame.new(0, 10.6, -1.5), color, M.Neon, Enum.PartType.Ball)
		glow(flame, color, 18, 1.1)
	end

	return d
end

-- LES STYLES ----------------------------------------------------------------------------------------------------------
-- floor    : { matière, couleur A, couleur B } du damier du sol
-- wall     : { matière, couleur }
-- trim     : { matière, couleur } de la plinthe, des piliers et de la frise des murs
-- accent   : couleur des lumières
-- platform : style des plateformes de parcours : style (metal, rock, wood, ice, stone, royal), matière, couleurs,
--            rim = couleur du bord, under = { matière, couleur } du dessous, beam = { matière, couleur } des poutres
-- decor    : fonction qui pose les décors propres à la salle
Themes.DEFS = {
	-- Salle 1 : un entrepôt. Briques, béton, caisses, bandes jaunes et noires, lampes d'atelier.
	Warehouse = {
		floor = { M.Concrete, rgb(120, 124, 132), rgb(132, 136, 144) },
		wall = { M.Brick, rgb(150, 82, 62) },
		trim = { M.Metal, rgb(70, 74, 84) },
		accent = rgb(255, 214, 110),
		platform = { style = "metal", material = M.DiamondPlate, colors = { rgb(150, 156, 168), rgb(128, 134, 148) }, rim = rgb(250, 200, 40), under = { M.Metal, rgb(60, 64, 74) }, beam = { M.Metal, rgb(250, 200, 40) } },
		decor = function(d)
			d.walls(11, function(cframe, n)
				if n % 3 == 0 then
					-- Une pile de caisses.
					d.part("Crate", Vector3.new(5, 5, 5), cframe * CFrame.new(0, 2.5, -3.2) * CFrame.Angles(0, 0.2, 0), rgb(176, 130, 80), M.WoodPlanks)
					d.part("Crate", Vector3.new(4, 4, 4), cframe * CFrame.new(0.6, 7, -3) * CFrame.Angles(0, -0.3, 0), rgb(160, 116, 70), M.WoodPlanks)
				elseif n % 3 == 1 then
					-- Une lampe d'atelier.
					d.part("LampArm", Vector3.new(0.4, 0.4, 2.4), cframe * CFrame.new(0, 17, -1.2), rgb(50, 54, 62), M.Metal)
					local lamp = d.part("Lamp", Vector3.new(2.4, 0.8, 2.4), cframe * CFrame.new(0, 16.5, -2.6), d.def.accent, M.Neon)
					glow(lamp, d.def.accent, 34, 1.4)
				else
					-- Un tuyau qui monte le long du mur.
					d.part("Pipe", Vector3.new(d.top - 2, 1, 1), cframe * CFrame.new(0, d.top / 2, -0.7) * CFrame.Angles(0, 0, math.rad(90)), rgb(190, 70, 50), M.Metal, Enum.PartType.Cylinder)
				end
				-- Bande de danger jaune et noire au pied du mur.
				d.part("Hazard", Vector3.new(5, 0.12, 1.4), cframe * CFrame.new(0, 0.07, -2.4), if n % 2 == 0 then rgb(250, 200, 40) else rgb(30, 30, 34))
			end)
		end,
	},
	-- Salle 2 : un canyon dans le désert. Sable, grès, rochers et cactus.
	Desert = {
		floor = { M.Sand, rgb(226, 196, 134), rgb(214, 182, 120) },
		wall = { M.Sandstone, rgb(204, 150, 96) },
		trim = { M.Sandstone, rgb(176, 122, 76) },
		accent = rgb(255, 200, 120),
		platform = { style = "rock", material = M.Sandstone, colors = { rgb(214, 168, 110), rgb(196, 150, 96) }, rim = rgb(160, 110, 70), under = { M.Rock, rgb(150, 106, 70) }, beam = { M.Wood, rgb(140, 100, 60) } },
		decor = function(d)
			d.walls(9, function(cframe, n)
				if n % 4 == 0 then
					-- Un cactus.
					d.part("Cactus", Vector3.new(7, 1.6, 1.6), cframe * CFrame.new(0, 3.5, -3) * CFrame.Angles(0, 0, math.rad(90)), rgb(70, 150, 80), M.Grass, Enum.PartType.Cylinder)
					d.part("CactusArm", Vector3.new(2.6, 1, 1), cframe * CFrame.new(1.4, 4, -3), rgb(70, 150, 80), M.Grass, Enum.PartType.Cylinder)
					d.part("CactusHand", Vector3.new(2.4, 1, 1), cframe * CFrame.new(2.4, 5, -3) * CFrame.Angles(0, 0, math.rad(90)), rgb(70, 150, 80), M.Grass, Enum.PartType.Cylinder)
				else
					-- Des rochers empilés, de tailles variées.
					local size = 3 + (n * 7 % 5)
					d.part("Boulder", Vector3.new(size + 2, size, size + 1), cframe * CFrame.new(0, size / 2 - 0.4, -2.4) * CFrame.Angles(0.1 * n, 0.7 * n, 0.2), rgb(190, 136, 90), M.Rock)
					if n % 2 == 0 then
						d.part("Boulder", Vector3.new(size, size * 0.8, size), cframe * CFrame.new(1, size + 0.6, -2) * CFrame.Angles(0.3, 0.4 * n, 0.1), rgb(204, 150, 100), M.Sandstone)
					end
				end
			end)
		end,
	},
	-- Salle 3 : un bunker. Béton gris-vert, plaques de métal, sacs de sable, gyrophares rouges.
	Bunker = {
		floor = { M.Concrete, rgb(96, 104, 96), rgb(108, 116, 106) },
		wall = { M.Concrete, rgb(96, 106, 94) },
		trim = { M.Metal, rgb(58, 62, 58) },
		accent = rgb(255, 70, 50),
		platform = { style = "metal", material = M.DiamondPlate, colors = { rgb(110, 118, 108) }, rim = rgb(255, 70, 50), under = { M.Metal, rgb(50, 54, 50) }, beam = { M.Metal, rgb(90, 96, 88) } },
		decor = function(d)
			d.walls(8, function(cframe, n)
				-- Deux rangées de sacs de sable.
				for row = 0, 1 do
					for i = -1, 1 do
						d.part("Sandbag", Vector3.new(2.5, 1.1, 1.5), cframe * CFrame.new(i * 2.5 + row * 1.2, 0.55 + row * 1.05, -1.6), rgb(170, 150, 110), M.Fabric)
					end
				end
				-- Une plaque de métal rivetée sur le mur.
				d.part("Plate", Vector3.new(5.6, 9, 0.3), cframe * CFrame.new(0, 8, -0.15), rgb(72, 80, 72), M.DiamondPlate)
				if n % 3 == 0 then
					local beacon = d.part("Beacon", Vector3.new(1.4, 1.4, 1.4), cframe * CFrame.new(0, 14, -1), d.def.accent, M.Neon, Enum.PartType.Ball)
					glow(beacon, d.def.accent, 14, 0.8)
					d.part("BeaconBase", Vector3.new(1.8, 0.6, 1.2), cframe * CFrame.new(0, 13, -0.6), rgb(40, 42, 40), M.Metal)
				end
			end)
		end,
	},
	-- Salle 4 : un volcan. Basalte, veines de lave dans les murs, pics de roche.
	Volcano = {
		floor = { M.Basalt, rgb(62, 54, 56), rgb(74, 62, 62) },
		wall = { M.Basalt, rgb(54, 44, 48) },
		trim = { M.Rock, rgb(40, 34, 38) },
		accent = rgb(255, 120, 40),
		platform = { style = "rock", material = M.Basalt, colors = { rgb(92, 80, 84), rgb(78, 68, 72) }, rim = rgb(255, 120, 40), under = { M.Rock, rgb(50, 42, 46) }, beam = { M.Basalt, rgb(120, 104, 108) } },
		decor = function(d)
			d.walls(7, function(cframe, n)
				-- Une veine de lave dans le mur, une fois sur trois : une fissure fine, en deux morceaux.
				if n % 3 == 0 then
					local length = 7 + (n % 4) * 2
					local vein = d.part("Vein", Vector3.new(0.45, length, 0.25), cframe * CFrame.new(-0.6, 3 + length / 2, -0.15) * CFrame.Angles(0, 0, 0.1), d.def.accent, M.Neon)
					d.part("Vein", Vector3.new(0.35, length * 0.6, 0.25), cframe * CFrame.new(0.5, 3 + length + length * 0.25, -0.15) * CFrame.Angles(0, 0, -0.18), d.def.accent, M.Neon)
					glow(vein, d.def.accent, 22, 1)
				end
				-- Un pic de roche au pied du mur.
				local size = 3 + n % 4
				d.part("Spike", Vector3.new(size * 0.9, size * 2, size * 0.9), cframe * CFrame.new(0, size - 0.6, -1.8) * CFrame.Angles(0.15, n, 0.1), rgb(46, 38, 42), M.Rock)
			end)
		end,
	},
	-- Salle 5 : un temple dans la jungle. Vieilles pierres, mousse, lianes, torches.
	Jungle = {
		floor = { M.Cobblestone, rgb(110, 124, 100), rgb(96, 112, 90) },
		wall = { M.Cobblestone, rgb(100, 112, 96) },
		trim = { M.Slate, rgb(74, 84, 72) },
		accent = rgb(255, 190, 90),
		platform = { style = "stone", material = M.Cobblestone, colors = { rgb(150, 156, 140), rgb(132, 140, 124) }, rim = rgb(80, 150, 70), under = { M.Slate, rgb(84, 92, 80) }, beam = { M.Wood, rgb(120, 86, 52) } },
		decor = function(d)
			d.walls(7, function(cframe, n)
				if n % 3 == 0 then
					d.torch(cframe, d.def.accent)
				end
				-- Des lianes qui pendent, de longueurs différentes.
				for i = -1, 1 do
					local length = 6 + ((n + i) * 5 % 9)
					d.part("Vine", Vector3.new(0.5, length, 0.3), cframe * CFrame.new(i * 2.1, d.top - 3 - length / 2, -0.4), rgb(60, 130 + (n % 3) * 15, 60), M.LeafyGrass)
				end
				-- De la mousse au pied du mur.
				d.part("Moss", Vector3.new(6, 1.2, 2.4), cframe * CFrame.new(0, 0.5, -1.2), rgb(70, 140, 70), M.LeafyGrass)
			end)
		end,
	},
	-- Salle 6 : une salle de concert. Rideaux, enceintes, projecteurs de couleur.
	Concert = {
		floor = { M.Marble, rgb(44, 40, 70), rgb(58, 52, 90) },
		wall = { M.Fabric, rgb(110, 50, 140) },
		trim = { M.Metal, rgb(30, 28, 44) },
		accent = rgb(255, 90, 220),
		platform = { style = "royal", material = M.Marble, colors = { rgb(70, 62, 110) }, rim = rgb(255, 90, 220), under = { M.Metal, rgb(30, 28, 44) }, beam = { M.Metal, rgb(255, 90, 220) } },
		decor = function(d)
			local spots = { rgb(255, 90, 220), rgb(80, 200, 255), rgb(255, 220, 80), rgb(120, 255, 140) }
			d.walls(7, function(cframe, n)
				-- Un pli de rideau.
				d.part("Curtain", Vector3.new(3.2, d.top - 2, 0.7), cframe * CFrame.new(0, d.top / 2, -0.5), if n % 2 == 0 then rgb(140, 60, 170) else rgb(96, 40, 124), M.Fabric)
				if n % 3 == 0 then
					-- Une pile d'enceintes.
					for level = 0, 1 do
						d.part("Speaker", Vector3.new(4, 5, 3), cframe * CFrame.new(0, 2.5 + level * 5, -2.2), rgb(26, 26, 32), M.Plastic)
						d.part("SpeakerCone", Vector3.new(0.3, 3, 3), cframe * CFrame.new(0, 2.5 + level * 5, -3.75) * CFrame.Angles(0, math.rad(90), 0), rgb(70, 70, 80), M.Metal, Enum.PartType.Cylinder)
					end
				elseif n % 3 == 1 then
					local color = spots[n % #spots + 1]
					local spot = d.part("Spot", Vector3.new(1.6, 1.6, 2.2), cframe * CFrame.new(0, d.top - 5, -1.6) * CFrame.Angles(-0.6, 0, 0), color, M.Neon)
					glow(spot, color, 40, 1.5)
				end
			end)
		end,
	},
	-- Salle 7 : une mine. Ardoise, étais en bois, lanternes, cristaux.
	Mine = {
		floor = { M.Slate, rgb(84, 80, 84), rgb(96, 92, 94) },
		wall = { M.Slate, rgb(72, 68, 76) },
		trim = { M.WoodPlanks, rgb(130, 92, 56) },
		accent = rgb(90, 230, 255),
		platform = { style = "wood", material = M.WoodPlanks, colors = { rgb(170, 124, 76), rgb(150, 108, 66) }, rim = rgb(96, 68, 42), under = { M.Wood, rgb(110, 78, 48) }, beam = { M.Wood, rgb(130, 92, 56) } },
		decor = function(d)
			d.walls(9, function(cframe, n)
				-- Un étai : deux poteaux et une poutre en travers.
				for _, x in { -3, 3 } do
					d.part("Prop", Vector3.new(1, 15, 1), cframe * CFrame.new(x, 7.5, -0.9), rgb(130, 92, 56), M.Wood)
				end
				d.part("PropBeam", Vector3.new(8, 1.2, 1.2), cframe * CFrame.new(0, 15.4, -0.9), rgb(120, 84, 50), M.Wood)
				if n % 2 == 0 then
					local lantern = d.part("Lantern", Vector3.new(1, 1.4, 1), cframe * CFrame.new(0, 13.6, -1), rgb(255, 200, 110), M.Neon)
					glow(lantern, rgb(255, 200, 110), 26, 1.4)
				else
					-- Un bouquet de cristaux qui brillent.
					for i = -1, 1 do
						local crystal = d.part("Crystal", Vector3.new(1, 3 + (n + i) % 3, 1), cframe * CFrame.new(i * 1.2, 1.4, -1.6) * CFrame.Angles(0.25 * i, n, 0.3 * i), d.def.accent, M.Neon)
						if i == 0 then
							glow(crystal, d.def.accent, 18, 1)
						end
					end
				end
			end)
		end,
	},
	-- Salle 8 : une crypte. Pavés sombres, briques grises, colonnes, torches, cercueils de pierre.
	Crypt = {
		floor = { M.Cobblestone, rgb(70, 66, 76), rgb(60, 56, 66) },
		wall = { M.Brick, rgb(86, 82, 94) },
		trim = { M.Slate, rgb(46, 44, 52) },
		accent = rgb(140, 255, 150),
		platform = { style = "stone", material = M.Slate, colors = { rgb(110, 106, 120) }, rim = rgb(140, 255, 150), under = { M.Slate, rgb(60, 58, 68) }, beam = { M.Slate, rgb(90, 86, 100) } },
		decor = function(d)
			d.walls(10, function(cframe, n)
				-- Une colonne contre le mur.
				d.part("Column", Vector3.new(d.top - 2, 2.6, 2.6), cframe * CFrame.new(0, d.top / 2, -1.4) * CFrame.Angles(0, 0, math.rad(90)), rgb(120, 116, 130), M.Marble, Enum.PartType.Cylinder)
				d.part("ColumnBase", Vector3.new(3.6, 1.4, 3.6), cframe * CFrame.new(0, 0.7, -1.4), rgb(100, 96, 110), M.Slate)
				if n % 2 == 0 then
					d.torch(cframe * CFrame.new(4.5, 0, 0), d.def.accent)
				else
					-- Un cercueil de pierre.
					d.part("Coffin", Vector3.new(3.4, 2, 7), cframe * CFrame.new(4.8, 1, -2.4) * CFrame.Angles(0, math.rad(90), 0), rgb(96, 92, 104), M.Slate)
					d.part("CoffinLid", Vector3.new(3.8, 0.5, 7.4), cframe * CFrame.new(4.8, 2.2, -2.4) * CFrame.Angles(0, math.rad(90), 0), rgb(120, 116, 130), M.Marble)
				end
			end)
		end,
	},
	-- Salle 9 : une grotte de glace. Neige, glacier, stalactites, cristaux bleus.
	Ice = {
		floor = { M.Snow, rgb(232, 240, 250), rgb(214, 228, 244) },
		wall = { M.Glacier, rgb(150, 200, 236) },
		trim = { M.Ice, rgb(190, 226, 250) },
		accent = rgb(120, 220, 255),
		platform = { style = "ice", material = M.Ice, colors = { rgb(170, 220, 250), rgb(196, 232, 252) }, rim = rgb(240, 250, 255), under = { M.Glacier, rgb(130, 190, 230) }, beam = { M.Ice, rgb(150, 210, 245) } },
		decor = function(d)
			d.walls(6, function(cframe, n)
				-- Des stalactites qui pendent du haut du mur.
				for i = -1, 1 do
					local length = 4 + ((n + i) * 3 % 7)
					d.part("Icicle", Vector3.new(1.1 - 0.2 * math.abs(i), length, 1), cframe * CFrame.new(i * 1.7, d.top - 2 - length / 2, -0.8), rgb(210, 236, 252), M.Ice)
				end
				if n % 3 == 0 then
					local crystal = d.part("IceCrystal", Vector3.new(1.8, 6, 1.8), cframe * CFrame.new(0, 2.4, -2) * CFrame.Angles(0.3, n, 0.35), d.def.accent, M.Neon)
					crystal.Transparency = 0.15
					glow(crystal, d.def.accent, 24, 1.2)
				else
					-- Un tas de neige.
					d.part("Snowdrift", Vector3.new(6, 6, 6), cframe * CFrame.new(0, -1.4, -1.6), rgb(240, 246, 252), M.Snow, Enum.PartType.Ball)
				end
			end)
		end,
	},
	-- Salle 10 : la salle du château. Marbre noir, or, bannières, braseros.
	Castle = {
		floor = { M.Marble, rgb(38, 36, 46), rgb(214, 208, 196) },
		wall = { M.Marble, rgb(52, 48, 60) },
		trim = { M.Metal, rgb(230, 180, 60) },
		accent = rgb(255, 170, 60),
		platform = { style = "royal", material = M.Marble, colors = { rgb(60, 56, 70), rgb(76, 70, 88) }, rim = rgb(230, 180, 60), under = { M.Marble, rgb(34, 32, 40) }, beam = { M.Metal, rgb(230, 180, 60) } },
		decor = function(d)
			d.walls(9, function(cframe, n)
				if n % 2 == 0 then
					-- Une bannière rouge à bord doré.
					d.part("BannerRod", Vector3.new(5, 0.4, 0.4), cframe * CFrame.new(0, 22, -0.8), rgb(230, 180, 60), M.Metal)
					d.part("Banner", Vector3.new(4.2, 13, 0.25), cframe * CFrame.new(0, 15.4, -0.7), rgb(170, 30, 40), M.Fabric)
					d.part("BannerEdge", Vector3.new(4.2, 1.2, 0.3), cframe * CFrame.new(0, 9.2, -0.7), rgb(230, 180, 60), M.Fabric)
					d.part("BannerCrest", Vector3.new(0.2, 2.2, 2.2), cframe * CFrame.new(0, 16.5, -0.9) * CFrame.Angles(0, math.rad(90), 0), rgb(230, 180, 60), M.Metal, Enum.PartType.Cylinder)
				else
					-- Un brasero.
					d.part("BrazierFoot", Vector3.new(0.8, 4, 0.8), cframe * CFrame.new(0, 2, -2.4), rgb(40, 38, 46), M.Metal)
					d.part("BrazierBowl", Vector3.new(1.4, 3.4, 3.4), cframe * CFrame.new(0, 4.4, -2.4) * CFrame.Angles(0, 0, math.rad(90)), rgb(230, 180, 60), M.Metal, Enum.PartType.Cylinder)
					local fire = d.part("BrazierFire", Vector3.new(2.2, 2.2, 2.2), cframe * CFrame.new(0, 5.8, -2.4), d.def.accent, M.Neon, Enum.PartType.Ball)
					glow(fire, d.def.accent, 30, 1.6)
				end
			end)
		end,
	},
}

function Themes.of(index: number)
	return Themes.DEFS[Themes.ROOMS[(index - 1) % #Themes.ROOMS + 1]]
end

-- Habille une salle déjà construite (sol et murs) : plinthe, piliers et frise le long des murs, puis les décors du
-- style. room = { center, zMin, zMax, height }.
function Themes.dress(static: Instance, room, def)
	local folder = Instance.new("Model")
	folder.Name = "Decor"
	folder.Parent = static
	local d = context(folder, room, def)
	local trimMaterial, trimColor = def.trim[1], def.trim[2]
	d.walls(5, function(cframe, _n)
		-- Plinthe, et frise à mi-hauteur.
		d.part("Baseboard", Vector3.new(7.2, 1.3, 0.5), cframe * CFrame.new(0, 0.65, -0.25), trimColor, trimMaterial)
		d.part("Frieze", Vector3.new(7.2, 0.9, 0.4), cframe * CFrame.new(0, d.top - 0.6, -0.2), trimColor, trimMaterial)
	end)
	d.walls(14, function(cframe, _n)
		d.part("Pilaster", Vector3.new(1.8, d.top, 0.9), cframe * CFrame.new(7, d.top / 2, -0.45), trimColor, trimMaterial)
	end)
	def.decor(d)
end

-- Habille une plateforme de parcours. `part` est le bloc sur lequel on marche (sa taille ne change pas) ;
-- kind = corner, pad, beam, steps, big ou final ; n = son numéro dans le parcours.
function Themes.platform(static: Instance, part: BasePart, kind: string, def, n: number)
	local style = def.platform
	local size, cframe = part.Size, part.CFrame
	local function add(name, partSize, offset, color, material, shape)
		return decorPart(static, name, partSize, cframe * offset, color, material, shape)
	end
	if kind == "final" then
		-- La plateforme d'arrivée reste verte et brillante dans toutes les salles, sur un socle du style.
		add("FinalBase", Vector3.new(size.X + 1.6, 1.4, size.Z + 1.6), CFrame.new(0, -1.3, 0), style.under[2], style.under[1])
		return
	end
	if kind == "beam" then
		part.Material, part.Color = style.beam[1], style.beam[2]
		return
	end
	part.Material = style.material
	part.Color = style.colors[n % #style.colors + 1]
	local rim = style.rim
	if kind == "big" then
		-- La grande marche garde sa couleur violette partout, avec un bord qui brille.
		part.Color = part.Color:Lerp(PURPLE, 0.6)
		rim = PURPLE
	end
	-- Le bord, tout autour.
	local rimMaterial = if kind == "big" then M.Neon else style.under[1]
	for _, side in { -1, 1 } do
		add("Rim", Vector3.new(size.X + 0.5, 0.5, 0.3), CFrame.new(0, size.Y / 2 - 0.3, side * (size.Z / 2 + 0.1)), rim, rimMaterial)
		add("Rim", Vector3.new(0.3, 0.5, size.Z + 0.5), CFrame.new(side * (size.X / 2 + 0.1), size.Y / 2 - 0.3, 0), rim, rimMaterial)
	end
	if kind == "steps" then
		return
	end
	-- Le dessous, selon le style.
	local underMaterial, underColor = style.under[1], style.under[2]
	local below = -size.Y / 2
	if style.style == "metal" then
		-- Des poutrelles en croix, et un pied jusqu'au sol sous les plateformes de coin.
		add("Girder", Vector3.new(size.X * 0.92, 0.7, 0.7), CFrame.new(0, below - 0.35, 0), underColor, underMaterial)
		add("Girder", Vector3.new(0.7, 0.7, size.Z * 0.92), CFrame.new(0, below - 0.35, 0), underColor, underMaterial)
		if kind == "corner" then
			local height = part.Position.Y + below
			if height > 1 then
				add("Leg", Vector3.new(height, 1, 1), CFrame.new(0, below - height / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), underColor, underMaterial, Enum.PartType.Cylinder)
			end
		end
	elseif style.style == "rock" then
		-- Un rocher qui s'amincit vers le bas, un peu de travers.
		add("Chunk", Vector3.new(size.X * 0.78, 1.8, size.Z * 0.78), CFrame.new(0, below - 0.8, 0) * CFrame.Angles(0, 0.2 * n, 0), underColor, underMaterial)
		add("Chunk", Vector3.new(size.X * 0.48, 2, size.Z * 0.48), CFrame.new(0.3, below - 2.5, -0.2) * CFrame.Angles(0.08, 0.5 * n, 0.06), underColor, underMaterial)
	elseif style.style == "wood" then
		-- Deux solives et quatre poteaux qui dépassent en dessous.
		for _, side in { -1, 1 } do
			add("Joist", Vector3.new(size.X * 0.96, 0.6, 0.6), CFrame.new(0, below - 0.3, side * size.Z * 0.3), underColor, underMaterial)
			for _, end_ in { -1, 1 } do
				add("Post", Vector3.new(0.7, 3.2, 0.7), CFrame.new(end_ * (size.X / 2 - 0.5), below - 1, side * (size.Z / 2 - 0.5)), underColor, underMaterial)
			end
		end
	elseif style.style == "ice" then
		-- Un bloc de glace et des stalactites.
		add("Chunk", Vector3.new(size.X * 0.74, 1.4, size.Z * 0.74), CFrame.new(0, below - 0.7, 0), underColor, underMaterial)
		for i = -1, 1 do
			local length = 2 + (n + i) % 3
			add("Icicle", Vector3.new(0.7, length, 0.7), CFrame.new(i * size.X * 0.24, below - 1.4 - length / 2, i * size.Z * 0.1), style.rim, M.Ice)
		end
	elseif style.style == "stone" then
		-- Un bloc de pierre taillée, et de la mousse sur le bord du dessus.
		add("Chunk", Vector3.new(size.X * 0.84, 1.4, size.Z * 0.84), CFrame.new(0, below - 0.7, 0), underColor, underMaterial)
		add("Chunk", Vector3.new(size.X * 0.56, 1.2, size.Z * 0.56), CFrame.new(0, below - 2, 0), underColor, underMaterial)
	else
		-- Royal : un socle sombre en deux étages.
		add("Chunk", Vector3.new(size.X * 0.86, 1, size.Z * 0.86), CFrame.new(0, below - 0.5, 0), underColor, underMaterial)
		add("Chunk", Vector3.new(size.X * 0.6, 1, size.Z * 0.6), CFrame.new(0, below - 1.5, 0), style.rim, M.Metal)
	end
end

return Themes

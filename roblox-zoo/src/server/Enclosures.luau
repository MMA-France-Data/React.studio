-- LES PARCELLES DES ANIMAUX ET LES BÂTIMENTS À ACHETER.
-- Sa demande (14/10) : « de base ce serait des parcelles vides, et la déco change quand tu choisis, par exemple tigre à
-- cet endroit, ça devient le décor tigre » ; « plus de sécurité pour les animaux dangereux, par exemple fosse aux
-- ours où ils sont en bas, truc plus sécurisé ».
--   Une parcelle vide : des herbes folles, des buissons, et un panneau « À vendre » : on y choisit ses animaux
--   (Config.HABITATS, la fenêtre est dans Main.client.luau). La parcelle se construit alors pour eux :
--     la sécurité (Config.HABITATS.security) : clôture en bois, hauts rondins avec une vitre, fossé profond devant les
--     visiteurs, ou fosse (les animaux 10 plus bas, une rampe pour le personnel) ;
--     le décor (ferme, prairie, forêt, boue, mare, rivière, rochers, savane, jungle), un abri, ses mangeoires.
--   Ce que l'écran doit savoir est posé en attributs sur le dossier de la parcelle : Habitat, Floor (la hauteur du sol
--   des animaux), Inner (« minX,maxX,minZ,maxZ » : où ils peuvent aller), Pools (les mares).
--   Les crottes des animaux apparaissent ici (Animals.luau dit quand) ; on les ramasse (Tasks.luau, Staff.luau).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Props = require(script.Parent.Props)
local Zoo = require(script.Parent.Zoo)

local Enclosures = {}

local M = Enum.Material
local rgb = Props.rgb
local part = Props.part
local v3 = Vector3.new
local terrain = workspace.Terrain

Enclosures.spaces = {} -- [parcelle] = { plot, habitat, folder, open, floor, inner, gate, path, troughs, poops, pools }
-- Ce que font les invites (rempli par Tasks.luau et Visitors.luau) : trough(player, parcelle, nourriture),
-- poop(player, crotte), serve(player, bâtiment).
Enclosures.handlers = {}
-- Appelé quand une parcelle vient d'être construite (Animals.luau y met le couple de départ).
Enclosures.onBought = nil :: ((string) -> ())?

local root = Instance.new("Folder")
root.Name = "Spaces"
root.Parent = workspace

local function prompt(parent: Instance, action: string, object: string, hold: number?, distance: number?): ProximityPrompt
	local item = Instance.new("ProximityPrompt")
	item.ActionText = action
	item.ObjectText = object
	item.HoldDuration = hold or 0
	item.MaxActivationDistance = distance or 9
	item.RequiresLineOfSight = false
	item.KeyboardKeyCode = Enum.KeyCode.E
	item.Parent = parent
	return item
end
Enclosures.prompt = prompt

local function alertBoard(adornee: BasePart, text: string, color: Color3, height: number): (BillboardGui, TextLabel)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Alert"
	gui.Size = UDim2.fromOffset(150, 40)
	gui.StudsOffsetWorldSpace = v3(0, height, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 90
	gui.Enabled = false
	gui.Parent = adornee
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = color
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = label
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = label
	return gui, label
end
Enclosures.alertBoard = alertBoard

-- GÉOMÉTRIE ------------------------------------------------------------------------------------------------------------
local function bounds(plot): (number, number, number, number)
	local half = plot.size / 2
	return plot.center.X - half.X, plot.center.X + half.X, plot.center.Z - half.Y, plot.center.Z + half.Y
end

-- Un point au hasard là où vont les animaux (à `margin` du bord), hors de l'eau (sauf si water).
function Enclosures.randomPoint(id: string, margin: number?, random: Random?, water: boolean?): Vector3
	local space = Enclosures.spaces[id]
	local inner = space.inner
	local m = margin or 2
	local rng = random or Random.new()
	local point = v3((inner[1] + inner[2]) / 2, space.floor, (inner[3] + inner[4]) / 2)
	for _ = 1, 20 do
		point = v3(rng:NextNumber(inner[1] + m, inner[2] - m), space.floor, rng:NextNumber(inner[3] + m, inner[4] - m))
		local wet = false
		for _, pool in space.pools do
			if (v3(point.X - pool.center.X, 0, point.Z - pool.center.Z)).Magnitude < pool.radius + 1.5 then
				wet = true
			end
		end
		if wet == (water == true) then
			return point
		end
	end
	return point
end

-- La distance (vue du ciel) d'une position à la parcelle (0 = dedans).
function Enclosures.distanceTo(id: string, position: Vector3): number
	local minX, maxX, minZ, maxZ = bounds(Enclosures.spaces[id].plot)
	local x = math.clamp(position.X, minX, maxX)
	local z = math.clamp(position.Z, minZ, maxZ)
	return (v3(position.X - x, 0, position.Z - z)).Magnitude
end

-- Un côté de la parcelle, en segment.
local function sideSegment(plot, side: string): (Vector3, Vector3)
	local minX, maxX, minZ, maxZ = bounds(plot)
	if side == "x-" then
		return v3(minX, 0, maxZ), v3(minX, 0, minZ)
	elseif side == "x+" then
		return v3(maxX, 0, minZ), v3(maxX, 0, maxZ)
	elseif side == "z-" then
		return v3(minX, 0, minZ), v3(maxX, 0, minZ)
	end
	return v3(maxX, 0, maxZ), v3(minX, 0, maxZ)
end
local OPPOSITE = { ["x-"] = "x+", ["x+"] = "x-", ["z-"] = "z+", ["z+"] = "z-" }
local INWARD = { ["x-"] = v3(1, 0, 0), ["x+"] = v3(-1, 0, 0), ["z-"] = v3(0, 0, 1), ["z+"] = v3(0, 0, -1) }

-- Le côté « de service » (perpendiculaire aux visiteurs), celui qui regarde vers le milieu du zoo : la porte des
-- animaux dangereux y est, loin des visiteurs.
local function serviceSide(plot): string
	local view = plot.side
	if view == "x-" or view == "x+" then
		return if plot.center.Z >= 0 then "z-" else "z+"
	end
	return if plot.center.X <= 0 then "x+" else "x-"
end

-- Rétrécit un rectangle { minX, maxX, minZ, maxZ } du côté donné.
local function shrink(rect, side: string, amount: number)
	if side == "x-" then
		rect[1] += amount
	elseif side == "x+" then
		rect[2] -= amount
	elseif side == "z-" then
		rect[3] += amount
	else
		rect[4] -= amount
	end
end

-- LE TERRAIN -----------------------------------------------------------------------------------------------------------
-- (Le sol du parc est à 0 : Map.luau. Une case de terrain pleine sous une case vide fait un sol 2 plus haut que le haut
-- de la case : on creuse donc toujours par cases de 4 alignées, et on repeint sans remplir.)
local function align(value: number, up: boolean): number
	return if up then math.ceil(value / 4) * 4 else math.floor(value / 4) * 4
end

-- Repeint le sol d'un rectangle (sans le creuser ni le monter).
local function repaint(space, from: Enum.Material, to: Enum.Material, rect: { number }?)
	local r = rect or space.inner
	local region = Region3.new(v3(r[1], space.floor - 10, r[3]), v3(r[2], space.floor + 4, r[4])):ExpandToGrid(4)
	terrain:ReplaceMaterial(region, 4, from, to)
end

-- Un rond de sol d'une autre matière (de la boue, du sable), à plat.
local PAINTABLE = { M.Grass, M.LeafyGrass, M.Ground, M.Sand, M.Mud }
local function patch(center: Vector3, radius: number, material: Enum.Material)
	for x = align(center.X - radius, false), center.X + radius, 4 do
		for z = align(center.Z - radius, false), center.Z + radius, 4 do
			if (v3(x + 2 - center.X, 0, z + 2 - center.Z)).Magnitude <= radius then
				local region = Region3.new(v3(x, center.Y - 8, z), v3(x + 4, center.Y + 4, z + 4))
				for _, from in PAINTABLE do
					if from ~= material then
						terrain:ReplaceMaterial(region, 4, from, material)
					end
				end
			end
		end
	end
end

-- Une mare : un creux, de l'eau jusqu'à 1 sous le sol, du sable autour.
local function pond(space, center: Vector3, radius: number, depth: number?)
	local d = depth or 6
	local y = center.Y
	patch(center, radius + 3, M.Sand)
	terrain:FillCylinder(CFrame.new(center.X, y + (4 - d) / 2, center.Z), d + 4, radius, M.Air)
	terrain:FillCylinder(CFrame.new(center.X, y - (d + 3) / 2, center.Z), d - 3, radius, M.Water)
	table.insert(space.pools, { center = v3(center.X, y, center.Z), radius = radius })
end

-- LES DÉCORS -----------------------------------------------------------------------------------------------------------
local HABITATS = {}

-- Un point de la zone des animaux (rx, rz de -1 à 1).
local function at(space, rx: number, rz: number): Vector3
	local inner = space.inner
	return v3((inner[1] + inner[2]) / 2 + rx * (inner[2] - inner[1]) / 2, space.floor, (inner[3] + inner[4]) / 2 + rz * (inner[4] - inner[3]) / 2)
end

-- Combien d'éléments de décor pour cette parcelle (les décors sont écrits pour une parcelle de 50 x 60 ; une grande
-- parcelle en a plus).
local function many(space, count: number): number
	local inner = space.inner
	local area = (inner[2] - inner[1]) * (inner[4] - inner[3])
	return math.max(1, math.round(count * math.clamp(area / 3000, 0.6, 4)))
end
-- La taille d'une mare, d'un rocher, selon la parcelle.
local function wide(space, value: number): number
	local inner = space.inner
	local area = (inner[2] - inner[1]) * (inner[4] - inner[3])
	return value * math.clamp(math.sqrt(area / 3000), 0.8, 1.8)
end

local function logs(folder, space, random, count: number)
	for _ = 1, many(space, count) do
		local spot = Enclosures.randomPoint(space.id, 6, random)
		Props.stick(folder, "Log", spot + v3(-3, 0.7, 0), spot + v3(3, 0.7, random:NextNumber(-1.5, 1.5)), 1.5, Props.WOOD_LIGHT, M.Wood, true)
	end
end
local function rocks(space, random, count: number, small: number, big: number)
	for _ = 1, many(space, count) do
		terrain:FillBall(Enclosures.randomPoint(space.id, 5, random) + v3(0, -0.5, 0), random:NextNumber(small, big), M.Rock)
	end
end

function HABITATS.farm(folder, space, random)
	pond(space, at(space, -0.45, -0.55), wide(space, 4.5), 4)
	for _ = 1, many(space, 5) do
		local spot = Enclosures.randomPoint(space.id, 6, random)
		part(folder, "HayBale", v3(3.2, 2, 2.4), CFrame.new(spot + v3(0, 1, 0)) * CFrame.Angles(0, random:NextNumber(0, 3), 0), rgb(222, 196, 106), M.Grass, true)
	end
	for _ = 1, many(space, 6) do
		Props.bush(folder, Enclosures.randomPoint(space.id, 3, random), random, 0.8, true)
	end
	-- Un petit poulailler.
	local coop = CFrame.lookAt(at(space, 0.55, -0.6), at(space, 0, 0))
	part(folder, "Coop", v3(6, 4, 5), coop * CFrame.new(0, 2.6, 0), rgb(150, 70, 56), M.WoodPlanks, true)
	Props.roof(folder, coop * CFrame.new(0, 4.6, 0), 7.5, 6.5, 2.4, Props.ROOF)
	for _, x in { -2.4, 2.4 } do
		for _, z in { -2, 2 } do
			part(folder, "CoopLeg", v3(0.5, 0.8, 0.5), coop * CFrame.new(x, 0.4, z), Props.WOOD, M.Wood)
		end
	end
	part(folder, "CoopRamp", v3(1.6, 0.2, 3.6), coop * CFrame.new(0, 0.6, -3.6) * CFrame.Angles(math.rad(22), 0, 0), Props.WOOD_LIGHT, M.Wood)
	Props.tree(folder, at(space, -0.8, 0.75), random, 0.9)
	Props.tree(folder, at(space, 0.8, 0.8), random, 0.8)
end

function HABITATS.meadow(folder, space, random)
	for _ = 1, many(space, 4) do
		local spot = Enclosures.randomPoint(space.id, 6, random)
		part(folder, "HayBale", v3(3.2, 2, 2.4), CFrame.new(spot + v3(0, 1, 0)) * CFrame.Angles(0, random:NextNumber(0, 3), 0), rgb(222, 196, 106), M.Grass, true)
	end
	for _ = 1, many(space, 30) do
		local spot = Enclosures.randomPoint(space.id, 2, random)
		Props.ball(folder, "Flower", 0.6, spot + v3(0, 0.3, 0), if random:NextNumber() < 0.5 then rgb(250, 250, 240) else rgb(250, 210, 70))
	end
	for _ = 1, many(space, 3) do
		Props.tree(folder, Enclosures.randomPoint(space.id, 5, random), random, 0.9)
	end
	rocks(space, random, 3, 1.5, 2.4)
end

function HABITATS.forest(folder, space, random)
	repaint(space, M.Grass, M.LeafyGrass)
	pond(space, at(space, 0.3, -0.5), wide(space, 4), 4)
	for _ = 1, many(space, 9) do
		local spot = Enclosures.randomPoint(space.id, 5, random)
		if random:NextNumber() < 0.6 then
			Props.pine(folder, spot, random, 0.9)
		else
			Props.tree(folder, spot, random, 0.9)
		end
	end
	for _ = 1, many(space, 8) do
		Props.fern(folder, Enclosures.randomPoint(space.id, 3, random), random, 1.2)
	end
	logs(folder, space, random, 3)
	rocks(space, random, 4, 1.6, 2.8)
end

function HABITATS.mud(folder, space, random)
	for _ = 1, many(space, 5) do
		patch(Enclosures.randomPoint(space.id, 8, random), random:NextNumber(5, 9), M.Mud)
	end
	for _ = 1, many(space, 6) do
		Props.tree(folder, Enclosures.randomPoint(space.id, 5, random), random, 0.95)
	end
	logs(folder, space, random, 4)
	for _ = 1, many(space, 8) do
		Props.bush(folder, Enclosures.randomPoint(space.id, 3, random), random, 1)
	end
end

function HABITATS.pond(folder, space, random)
	pond(space, at(space, 0, -0.1), wide(space, 11), 6)
	for _ = 1, many(space, 6) do
		Props.palm(folder, Enclosures.randomPoint(space.id, 4, random), random, 0.85)
	end
	for _ = 1, many(space, 6) do
		Props.tallGrass(folder, Enclosures.randomPoint(space.id, 3, random), random, rgb(92, 150, 70))
	end
	for _ = 1, many(space, 5) do
		Props.bush(folder, Enclosures.randomPoint(space.id, 3, random), random, 1, true)
	end
end

function HABITATS.river(folder, space, random)
	pond(space, at(space, -0.2, -0.35), wide(space, 11), 7)
	pond(space, at(space, 0.15, 0.3), wide(space, 9), 7)
	for _ = 1, many(space, 4) do
		patch(Enclosures.randomPoint(space.id, 6, random), random:NextNumber(4, 6), M.Sand)
	end
	for _ = 1, many(space, 6) do
		Props.palm(folder, Enclosures.randomPoint(space.id, 4, random), random)
	end
	for _ = 1, many(space, 6) do
		Props.fern(folder, Enclosures.randomPoint(space.id, 3, random), random, 1.4)
	end
	rocks(space, random, 4, 2, 3.5)
end

function HABITATS.rocks(folder, space, random)
	repaint(space, M.Ground, M.LeafyGrass)
	-- Des rochers au fond (avec une grotte), un bassin, des sapins.
	local back = at(space, 0, 0.55)
	for _ = 1, many(space, 6) do
		terrain:FillBall(back + v3(random:NextNumber(-12, 12), random:NextNumber(0, 4), random:NextNumber(-2, 2)), random:NextNumber(4, 6.5), M.Rock)
	end
	terrain:FillBall(back + v3(0, 2, -4), 3.5, M.Air)
	pond(space, at(space, 0.5, -0.4), wide(space, 5), 4)
	for _ = 1, many(space, 5) do
		Props.pine(folder, Enclosures.randomPoint(space.id, 5, random), random, 1)
	end
	logs(folder, space, random, 3)
end

-- Un acacia : un tronc qui se divise, une couronne large et plate.
local function acacia(folder, spot: Vector3, random: Random)
	local k = random:NextNumber(0.9, 1.3)
	local split = spot + v3(0, 7 * k, 0)
	Props.stick(folder, "Trunk", spot - v3(0, 1, 0), split, 1.3 * k, rgb(104, 84, 64), M.Wood, true)
	for i = 1, 3 do
		local angle = i * 2.1 + random:NextNumber(-0.3, 0.3)
		local tip = split + v3(math.cos(angle) * 4 * k, 4 * k, math.sin(angle) * 4 * k)
		Props.stick(folder, "Branch", split, tip, 0.7 * k, rgb(104, 84, 64), M.Wood)
		local crown = part(folder, "Crown", v3(2.2 * k, 9 * k, 9 * k), CFrame.new(tip + v3(0, 0.8, 0)) * CFrame.Angles(0, 0, math.rad(90)), rgb(110, 140, 64), M.Grass)
		crown.Shape = Enum.PartType.Cylinder
		crown.CastShadow = true
	end
end

function HABITATS.savanna(folder, space, random)
	repaint(space, M.Grass, M.Ground)
	for _ = 1, many(space, 6) do
		patch(Enclosures.randomPoint(space.id, 8, random), random:NextNumber(5, 9), M.Sand)
	end
	pond(space, at(space, -0.45, 0.3), wide(space, 5), 4)
	-- Le rocher des lions (un « kopje »).
	local rock = at(space, 0.35, -0.2)
	terrain:FillBall(rock, 6, M.Rock)
	terrain:FillBall(rock + v3(4, 2, -2), 4.5, M.Rock)
	terrain:FillBall(rock + v3(-3, 1, 3), 4, M.Rock)
	for _ = 1, many(space, 3) do
		acacia(folder, Enclosures.randomPoint(space.id, 6, random), random)
	end
	for _ = 1, many(space, 12) do
		Props.tallGrass(folder, Enclosures.randomPoint(space.id, 2, random), random)
	end
end

function HABITATS.jungle(folder, space, random)
	repaint(space, M.Grass, M.LeafyGrass)
	pond(space, at(space, 0.45, 0.1), wide(space, 6), 5)
	for _ = 1, many(space, 4) do
		Props.jungleTree(folder, Enclosures.randomPoint(space.id, 6, random), random, 0.9)
	end
	for _ = 1, many(space, 4) do
		Props.palm(folder, Enclosures.randomPoint(space.id, 4, random), random)
	end
	for _ = 1, many(space, 10) do
		Props.fern(folder, Enclosures.randomPoint(space.id, 3, random), random, 1.5)
	end
	-- Des troncs et des cordes pour grimper.
	local frame = at(space, -0.4, -0.2)
	for _, offset in { v3(-4, 0, -3), v3(4, 0, -3), v3(0, 0, 4) } do
		Props.stick(folder, "Pole", frame + offset - v3(0, 1, 0), frame + offset + v3(0, 10, 0), 1.2, Props.WOOD_LIGHT, M.Wood, true)
	end
	Props.stick(folder, "Beam", frame + v3(-4, 9, -3), frame + v3(4, 9, -3), 0.9, Props.WOOD_LIGHT, M.Wood)
	Props.stick(folder, "Beam", frame + v3(4, 9, -3), frame + v3(0, 9, 4), 0.9, Props.WOOD_LIGHT, M.Wood)
	Props.stick(folder, "Rope", frame + v3(0, 9, -3), frame + v3(0.5, 3, -3), 0.3, rgb(170, 150, 110), M.Fabric)
	rocks(space, random, 3, 2, 3.5)
end

-- LA SÉCURITÉ ----------------------------------------------------------------------------------------------------------
-- Un muret de pierre avec une rambarde en fer (le bord de la fosse aux ours).
local function parapet(folder, a: Vector3, b: Vector3)
	local length = (b - a).Magnitude
	if length < 0.5 then
		return
	end
	local along = CFrame.lookAt((a + b) / 2, b)
	part(folder, "Wall", v3(1.6, 3, length), along * CFrame.new(0, 1.5, 0), Props.STONE, M.Cobblestone, true)
	part(folder, "Rail", v3(0.4, 0.4, length), along * CFrame.new(0, 5, 0), Props.IRON, M.Metal, true)
	part(folder, "Rail", v3(0.3, 0.3, length), along * CFrame.new(0, 4, 0), Props.IRON, M.Metal, true)
	local count = math.max(1, math.round(length / 3))
	for i = 0, count do
		part(folder, "RailPost", v3(0.3, 2.2, 0.3), along * CFrame.new(0, 4, -length / 2 + length * i / count), Props.IRON, M.Metal, true)
	end
end

-- La porte « Personnel » : deux poteaux et une poutre avec le panneau.
local function gateFrame(folder, a: Vector3, b: Vector3, height: number)
	for _, post in { a, b } do
		part(folder, "GatePost", v3(1, height, 1), post + v3(0, height / 2, 0), Props.WOOD, M.Wood, true)
	end
	local beam = part(folder, "GateBeam", v3((b - a).Magnitude + 1, 1.6, 0.8), CFrame.lookAt((a + b) / 2 + v3(0, height - 0.8, 0), b + v3(0, height - 0.8, 0)) * CFrame.Angles(0, math.rad(90), 0), Props.WOOD, M.WoodPlanks, true)
	Props.label(beam, Enum.NormalId.Front, "Personnel", rgb(255, 220, 120))
	Props.label(beam, Enum.NormalId.Back, "Personnel", rgb(255, 220, 120))
end

-- Un côté de clôture, avec peut-être une porte en `gate` (le milieu de la porte).
local function fenceSide(folder, from: Vector3, to: Vector3, kind: string, gate: Vector3?)
	local function segment(a: Vector3, b: Vector3)
		if (b - a).Magnitude < 0.5 then
			return
		end
		if kind == "wood" then
			Props.woodFence(folder, a, b)
		elseif kind == "glass" then
			Props.wildFence(folder, a, b, true)
		elseif kind == "logs" then
			Props.wildFence(folder, a, b, false)
		else
			parapet(folder, a, b)
		end
	end
	if gate then
		local along = (to - from).Unit
		local t = (gate - from):Dot(along)
		local a, b = from + along * (t - 3.2), from + along * (t + 3.2)
		segment(from, a)
		segment(b, to)
		gateFrame(folder, a, b, if kind == "wood" then 6 elseif kind == "parapet" then 7 else 10.5)
	else
		segment(from, to)
	end
end

-- La porte sur un côté : à `fromBack` du coin du fond.
local function gateOn(plot, side: string, fromBack: number): Vector3
	local from, to = sideSegment(plot, side)
	local back = OPPOSITE[plot.side]
	local backFrom, backTo = sideSegment(plot, back)
	local backMiddle = (backFrom + backTo) / 2
	local near, far = from, to
	if (to - backMiddle).Magnitude < (from - backMiddle).Magnitude then
		near, far = to, from
	end
	return near + (far - near).Unit * fromBack
end

-- Construit la sécurité de la parcelle et décide où vont les animaux (inner), à quelle hauteur (floor), et le chemin du
-- personnel pour entrer (path, du dehors vers dedans).
local function security(space)
	local plot, habitat = space.plot, space.habitat
	local folder = Instance.new("Folder")
	folder.Name = "Security"
	folder.Parent = space.folder
	local kind = habitat.security
	local minX, maxX, minZ, maxZ = bounds(plot)
	space.inner = { minX + 3, maxX - 3, minZ + 3, maxZ - 3 }
	space.floor = 0
	local view, back, service = plot.side, OPPOSITE[plot.side], serviceSide(plot)
	if kind == "fence" then
		-- La porte côté visiteurs, loin de l'endroit où ils regardent.
		local from, to = sideSegment(plot, view)
		local along = (to - from).Unit
		local length = (to - from).Magnitude
		local a, b = from + along * length * 0.2, from + along * length * 0.8
		local gate = if (a - plot.view).Magnitude > (b - plot.view).Magnitude then a else b
		for _, side in { "x-", "x+", "z-", "z+" } do
			local s1, s2 = sideSegment(plot, side)
			fenceSide(folder, s1, s2, "wood", if side == view then gate else nil)
		end
		space.gate = gate
		space.path = { gate - INWARD[view] * 3, gate + INWARD[view] * 4 }
	elseif kind == "wall" or kind == "moat" then
		local gate = gateOn(plot, service, 9)
		for _, side in { "x-", "x+", "z-", "z+" } do
			local s1, s2 = sideSegment(plot, side)
			fenceSide(folder, s1, s2, if side == view then "glass" else "logs", if side == service then gate else nil)
		end
		space.gate = gate
		space.path = { gate - INWARD[service] * 3, gate + INWARD[service] * 4 }
		if kind == "moat" then
			-- LE FOSSÉ : une tranchée de Config.MOAT de large et 6 de profond, le long du côté des visiteurs (de l'eau
			-- au fond pour les crocodiles), avec des parois de rocher.
			local strip = { minX + 2, maxX - 2, minZ + 2, maxZ - 2 }
			if view == "x-" then
				strip[2] = minX + 2 + Config.MOAT
			elseif view == "x+" then
				strip[1] = maxX - 2 - Config.MOAT
			elseif view == "z-" then
				strip[4] = minZ + 2 + Config.MOAT
			else
				strip[3] = maxZ - 2 - Config.MOAT
			end
			local x0, x1, z0, z1 = align(strip[1], true), align(strip[2], false), align(strip[3], true), align(strip[4], false)
			terrain:ReplaceMaterial(Region3.new(v3(x0 - 4, -16, z0 - 4), v3(x1 + 4, 4, z1 + 4)), 4, M.Grass, M.Rock)
			terrain:ReplaceMaterial(Region3.new(v3(x0 - 4, -16, z0 - 4), v3(x1 + 4, 4, z1 + 4)), 4, M.Ground, M.Rock)
			terrain:FillBlock(CFrame.new((x0 + x1) / 2, -2, (z0 + z1) / 2), v3(x1 - x0, 12, z1 - z0), M.Air)
			if habitat.decor == "river" then
				terrain:FillBlock(CFrame.new((x0 + x1) / 2, -5.5, (z0 + z1) / 2), v3(x1 - x0, 5, z1 - z0), M.Water)
			end
			shrink(space.inner, view, Config.MOAT + 1)
		end
	else
		-- LA FOSSE : la zone des animaux est creusée de Config.PIT, avec des parois de rocher ; un muret et une rambarde
		-- tout autour ; une rampe le long du fond, depuis la porte du personnel.
		local x0, x1 = align(minX + 6, true), align(maxX - 6, false)
		local z0, z1 = align(minZ + 6, true), align(maxZ - 6, false)
		local depth = Config.PIT
		terrain:ReplaceMaterial(Region3.new(v3(x0 - 4, -24, z0 - 4), v3(x1 + 4, 4, z1 + 4)), 4, M.Grass, M.Rock)
		terrain:ReplaceMaterial(Region3.new(v3(x0 - 4, -24, z0 - 4), v3(x1 + 4, 4, z1 + 4)), 4, M.Ground, M.Rock)
		terrain:FillBlock(CFrame.new((x0 + x1) / 2, (4 - (depth + 2)) / 2, (z0 + z1) / 2), v3(x1 - x0, depth + 6, z1 - z0), M.Air)
		terrain:ReplaceMaterial(Region3.new(v3(x0, -depth - 8, z0), v3(x1, -depth + 4, z1)), 4, M.Rock, M.Ground)
		space.floor = -depth
		space.inner = { x0 + 2, x1 - 2, z0 + 2, z1 - 2 }
		local gate = gateOn(plot, service, 9)
		for _, side in { "x-", "x+", "z-", "z+" } do
			local s1, s2 = sideSegment(plot, side)
			-- (Le muret au bord du trou, pas au bord de la parcelle.)
			local inward = INWARD[side]
			local edge = if side == "x-" then minX - x0 elseif side == "x+" then x1 - maxX elseif side == "z-" then minZ - z0 else z1 - maxZ
			local shift = inward * (math.abs(edge) - 1)
			fenceSide(folder, s1 + shift, s2 + shift, "parapet", if side == service then gate + shift else nil)
		end
		-- La rampe : de la porte, le long du fond, jusqu'en bas.
		local inward = INWARD[service]
		local top = gate + inward * (math.abs(if service == "x-" then minX - x0 elseif service == "x+" then x1 - maxX elseif service == "z-" then minZ - z0 else z1 - maxZ) - 0.5)
		local length = depth * 2.6
		local bottom = top + inward * length - v3(0, depth, 0)
		local ramp = part(folder, "Ramp", v3(5, 1, (bottom - top).Magnitude), CFrame.lookAt((top + bottom) / 2, bottom) * CFrame.new(0, -0.5, 0), Props.WOOD_LIGHT, M.WoodPlanks, true)
		ramp.CollisionGroup = "Default"
		for _, side in { -1, 1 } do
			part(folder, "RampRail", v3(0.3, 0.3, (bottom - top).Magnitude), CFrame.lookAt((top + bottom) / 2, bottom) * CFrame.new(side * 2.4, 2.2, 0), Props.IRON, M.Metal)
		end
		space.gate = gate
		space.path = { gate - inward * 3, top, bottom + inward * 2 }
		-- (Les animaux restent loin de la rampe.)
		shrink(space.inner, back, 9)
	end
	-- Les clôtures arrêtent le joueur mais pas le personnel (Npc.luau : groupe « Fence »). Pas la rampe.
	for _, item in folder:GetDescendants() do
		if item:IsA("BasePart") and item.CanCollide and item.Name ~= "Ramp" then
			item.CollisionGroup = "Fence"
		end
	end
end

-- LES MANGEOIRES ------------------------------------------------------------------------------------------------------
-- Le niveau d'une mangeoire (0 à 100) : la nourriture monte ou descend dans le bac, et un panneau « Vide ! » apparaît.
function Enclosures.setLevel(id: string, food: string, level: number)
	local space = Enclosures.spaces[id]
	local trough = space and space.troughs[food]
	if not trough then
		return
	end
	level = math.clamp(level, 0, Config.TROUGH_MAX)
	trough.level = level
	Zoo.state.troughs[id] = Zoo.state.troughs[id] or {}
	Zoo.state.troughs[id][food] = level
	local fill = level / Config.TROUGH_MAX
	trough.food.Transparency = if fill <= 0.01 then 1 else 0
	trough.food.Size = v3(5.4, 0.1 + 0.9 * fill, 1.9)
	trough.food.CFrame = trough.base * CFrame.new(0, 1.05 + (0.1 + 0.9 * fill) / 2, 0)
	trough.box:SetAttribute("Level", level)
	trough.alert.Enabled = fill < 0.2
	trough.alertText.Text = if fill <= 0.01 then "Vide !" else "Presque vide"
end

-- Le long du fond de la zone des animaux, une mangeoire par nourriture, et un abreuvoir.
local function addTroughs(space)
	local foods, seen = {}, {}
	for _, species in space.habitat.species do
		local food = Config.SPECIES[species].food
		if not seen[food] then
			seen[food] = true
			table.insert(foods, food)
		end
	end
	local back = OPPOSITE[space.plot.side]
	local inner = space.inner
	local inward = INWARD[back]
	local middle = at(space, 0, 0)
	if back == "x-" then
		middle = v3(inner[1], space.floor, middle.Z)
	elseif back == "x+" then
		middle = v3(inner[2], space.floor, middle.Z)
	elseif back == "z-" then
		middle = v3(middle.X, space.floor, inner[3])
	else
		middle = v3(middle.X, space.floor, inner[4])
	end
	middle += inward * 2.5
	local along = v3(inward.Z, 0, -inward.X)
	for i, food in foods do
		local offset = (i - (#foods + 1) / 2) * 10
		local spot = middle + along * offset
		local base = CFrame.lookAt(spot, spot + inward) * CFrame.Angles(0, math.rad(90), 0)
		local model, foodPart = Props.trough(space.folder, base, Config.FOODS[food].color)
		local box = model:FindFirstChild("Box") :: BasePart
		box:SetAttribute("Space", space.id)
		box:SetAttribute("Food", food)
		local alert, alertText = alertBoard(box, "Vide !", rgb(214, 70, 60), 4)
		local trough = { box = box, food = foodPart, base = base, level = 0, alert = alert, alertText = alertText, position = base.Position }
		space.troughs[food] = trough
		local item = prompt(box, "Remplir", "Mangeoire (" .. Config.FOODS[food].fr .. ")", 0.4)
		item.Triggered:Connect(function(player)
			if Enclosures.handlers.trough then
				Enclosures.handlers.trough(player, space.id, food)
			end
		end)
		local saved = Zoo.state.troughs[space.id] and Zoo.state.troughs[space.id][food]
		Enclosures.setLevel(space.id, food, saved or 50)
	end
	-- Un abreuvoir (pour le décor).
	local water = middle - along * (#foods * 5 + 6)
	part(space.folder, "WaterTrough", v3(4, 1.4, 2.4), water + v3(0, 0.7, 0), Props.STONE, M.Cobblestone, true)
	local surface = part(space.folder, "Water", v3(3.4, 0.2, 1.8), water + v3(0, 1.35, 0), rgb(80, 150, 170), M.Glass)
	surface.Transparency = 0.2
	-- L'abri, dans le coin du fond (côté opposé à la porte du personnel).
	local big = Config.SPECIES[space.habitat.species[1]].height > 5.5
	local corner = middle + along * (#foods * 5 + 14) + inward * 4
	if (corner - (space.gate or corner)).Magnitude < 12 then
		corner = middle - along * (#foods * 5 + 18) + inward * 4
	end
	local decor = space.habitat.decor
	Props.shelter(space.folder, CFrame.lookAt(corner, corner + inward) * CFrame.Angles(0, math.rad(180), 0), if big then 15 else 10, if big then 10 else 7, decor == "savanna" or decor == "pond" or decor == "meadow")
end

-- LES CROTTES ---------------------------------------------------------------------------------------------------------
local poopRandom = Random.new()
function Enclosures.addPoop(id: string, position: Vector3?): BasePart?
	local space = Enclosures.spaces[id]
	if not space or not space.open or #space.poops >= Config.NEEDS.poopMax then
		return nil
	end
	local spot = position or Enclosures.randomPoint(id, 3, poopRandom)
	local size = if Config.SPECIES[space.habitat.species[1]].height > 5 then 1.4 else 1
	local main = Props.ball(space.folder, "Poop", 1.1 * size, spot + v3(0, 0.4 * size, 0), rgb(92, 66, 42), M.Ground)
	main.CanQuery = true
	Props.ball(main, "Bit", 0.8 * size, spot + v3(0.5 * size, 0.3 * size, 0.3 * size), rgb(84, 60, 38), M.Ground)
	Props.ball(main, "Bit", 0.7 * size, spot + v3(-0.3 * size, 0.7 * size, -0.2 * size), rgb(100, 72, 46), M.Ground)
	main:SetAttribute("Space", id)
	table.insert(space.poops, main)
	local item = prompt(main, "Ramasser", "Crotte", 0.3, 8)
	item.Triggered:Connect(function(player)
		if Enclosures.handlers.poop then
			Enclosures.handlers.poop(player, main)
		end
	end)
	Zoo.state.poops[id] = #space.poops
	return main
end

function Enclosures.removePoop(main: BasePart): boolean
	local id = main:GetAttribute("Space")
	local space = id and Enclosures.spaces[id]
	if not space then
		return false
	end
	local index = table.find(space.poops, main)
	if not index then
		return false
	end
	table.remove(space.poops, index)
	main:Destroy()
	Zoo.state.poops[id] = #space.poops
	return true
end

-- Toutes les crottes du zoo (pour les agents d'entretien).
function Enclosures.allPoops(): { BasePart }
	local list = {}
	for _, space in Enclosures.spaces do
		for _, item in space.poops do
			table.insert(list, item)
		end
	end
	return list
end

-- CONSTRUIRE UNE PARCELLE ---------------------------------------------------------------------------------------------
-- LES JEUX (sa demande du 15/10, « 4 ») : chacun se voit dans l'espace et rend ses animaux plus heureux (Animals.luau).
local TOY_BUILDERS = {}
function TOY_BUILDERS.salt(folder, at: Vector3)
	part(folder, "SaltPost", v3(0.8, 3, 0.8), at + v3(0, 1.5, 0), Props.WOOD, M.Wood, true)
	part(folder, "Salt", v3(1.8, 1.2, 1.8), at + v3(0, 3.4, 0), rgb(240, 236, 228), M.Salt)
end
function TOY_BUILDERS.brush(folder, at: Vector3)
	for _, x in { -1.8, 1.8 } do
		part(folder, "BrushPost", v3(0.8, 4, 0.8), at + v3(x, 2, 0), Props.WOOD, M.Wood, true)
	end
	part(folder, "Brush", v3(3, 1, 0.9), at + v3(0, 2.2, 0), rgb(200, 150, 80), M.Fabric, true)
end
function TOY_BUILDERS.ball(folder, at: Vector3)
	Props.ball(folder, "Ball", 3.2, at + v3(0, 1.6, 0), rgb(230, 70, 60), M.SmoothPlastic).CanCollide = true
	local stripe = part(folder, "BallStripe", v3(0.7, 3.26, 3.26), CFrame.new(at + v3(0, 1.6, 0)), rgb(250, 250, 250), M.SmoothPlastic)
	stripe.Shape = Enum.PartType.Cylinder
end
function TOY_BUILDERS.log(folder, at: Vector3)
	Props.stick(folder, "ScratchLog", at - v3(0, 1, 0), at + v3(0.6, 6, 0.4), 1.6, Props.WOOD_LIGHT, M.Wood, true)
	Props.stick(folder, "Rope", at + v3(0, 1, 0), at + v3(0.3, 3.4, 0.2), 1.75, rgb(190, 170, 120), M.Fabric)
end
function TOY_BUILDERS.platform(folder, at: Vector3)
	for _, x in { -2.6, 2.6 } do
		for _, z in { -2.6, 2.6 } do
			part(folder, "PlatformLeg", v3(0.8, 4.4, 0.8), at + v3(x, 2.2, z), Props.WOOD, M.Wood, true)
		end
	end
	part(folder, "Platform", v3(6.4, 0.6, 6.4), at + v3(0, 4.6, 0), Props.WOOD_LIGHT, M.WoodPlanks, true)
	part(folder, "PlatformRamp", v3(2, 0.4, 6), CFrame.new(at + v3(0, 2.3, 5.4)) * CFrame.Angles(math.rad(40), 0, 0), Props.WOOD_LIGHT, M.WoodPlanks, true)
end
function TOY_BUILDERS.ropes(folder, at: Vector3)
	for _, x in { -3, 3 } do
		Props.stick(folder, "Pole", at + v3(x, -1, 0), at + v3(x, 8, 0), 1, Props.WOOD_LIGHT, M.Wood, true)
	end
	Props.stick(folder, "Rope", at + v3(-3, 7.5, 0), at + v3(3, 7.5, 0), 0.35, rgb(190, 170, 120), M.Fabric)
	part(folder, "Hammock", v3(5, 0.3, 2.2), at + v3(0, 3.2, 0), rgb(200, 120, 70), M.Fabric)
	Props.stick(folder, "Rope", at + v3(-1, 7.4, 0), at + v3(-1, 1.5, 0), 0.3, rgb(190, 170, 120), M.Fabric)
end
function TOY_BUILDERS.pool(folder, at: Vector3)
	local rim = part(folder, "PoolRim", v3(1, 9, 9), CFrame.new(at + v3(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), Props.STONE, M.Cobblestone, true)
	rim.Shape = Enum.PartType.Cylinder
	local water = part(folder, "PoolWater", v3(0.2, 7.6, 7.6), CFrame.new(at + v3(0, 1.05, 0)) * CFrame.Angles(0, 0, math.rad(90)), rgb(80, 160, 190), M.Glass)
	water.Shape = Enum.PartType.Cylinder
	water.Transparency = 0.25
end

local function placeToy(space, toy: string, index: number)
	local builder = TOY_BUILDERS[toy]
	if not builder then
		return
	end
	local folder = space.folder:FindFirstChild("Toys") or Instance.new("Folder")
	folder.Name = "Toys"
	folder.Parent = space.folder
	local random = Random.new(space.plot.index * 131 + index * 17)
	builder(folder, Enclosures.randomPoint(space.id, 6, random))
end

function Enclosures.buyToy(player: Player?, id: string, toy: string): boolean
	local space = Enclosures.spaces[id]
	local def = Config.TOYS[toy]
	if not space or not space.open or not def or not table.find(space.habitat.toys or {}, toy) then
		return false
	end
	local owned = Zoo.state.toys[id] or {}
	if table.find(owned, toy) then
		return false
	end
	if not Zoo.spend(def.price, "toys", player) then
		return false
	end
	table.insert(owned, toy)
	Zoo.state.toys[id] = owned
	placeToy(space, toy, #owned)
	space.folder:SetAttribute("Toys", table.concat(owned, ","))
	Zoo.notify(nil, "toyBought", def.fr, space.habitat.name)
	return true
end

local function nameSign(space)
	local plot = space.plot
	local toward = plot.center - plot.view
	toward = v3(toward.X, 0, toward.Z).Unit
	local spot = plot.view + toward * 2.2 + v3(toward.Z, 0, -toward.X) * 7
	local sign = Props.sign(space.folder, spot, -toward, space.habitat.name, 9)
	sign.Name = "NameSign"
	-- Le bouton des jeux de l'espace (et de sa fiche).
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Jeux de l'espace"
	prompt.ObjectText = space.habitat.name
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = sign
	prompt.Triggered:Connect(function(player)
		Zoo.remotes.open:FireClient(player, "toys", space.id)
	end)
end

-- La parcelle construite pour ces animaux.
local function openSpace(space, habitatId: string)
	local habitat = Config.HABITAT_BY_ID[habitatId]
	space.habitat = habitat
	if space.forSale then
		space.forSale:Destroy()
		space.forSale = nil
	end
	local random = Random.new(space.plot.index * 7919 + #habitatId)
	security(space)
	local build = HABITATS[habitat.decor] or HABITATS.forest
	build(space.folder, space, random)
	addTroughs(space)
	nameSign(space)
	-- Les jeux déjà installés.
	for index, toy in Zoo.state.toys[space.id] or {} do
		placeToy(space, toy, index)
	end
	space.folder:SetAttribute("Toys", table.concat(Zoo.state.toys[space.id] or {}, ","))
	space.open = true
	-- (Pour l'écran : où vont les animaux, à quelle hauteur, où sont les mares.)
	local folder = space.folder
	folder:SetAttribute("Habitat", habitatId)
	folder:SetAttribute("Floor", space.floor)
	folder:SetAttribute("Inner", table.concat(space.inner, ","))
	local pools = {}
	for _, pool in space.pools do
		table.insert(pools, string.format("%.1f,%.1f,%.1f", pool.center.X, pool.center.Z, pool.radius))
	end
	folder:SetAttribute("Pools", table.concat(pools, ";"))
	folder:SetAttribute("Open", true)
	-- Les crottes laissées à la dernière sauvegarde.
	for _ = 1, math.min(Zoo.state.poops[space.id] or 0, Config.NEEDS.poopMax) do
		Enclosures.addPoop(space.id)
	end
end

-- La parcelle vide : herbes folles, buissons, le panneau « À vendre » où l'on choisit ses animaux.
local function forSale(space)
	local plot = space.plot
	local folder = Instance.new("Folder")
	folder.Name = "ForSale"
	folder.Parent = space.folder
	space.forSale = folder
	local random = Random.new(plot.index * 104729)
	space.inner = { plot.center.X - plot.size.X / 2 + 3, plot.center.X + plot.size.X / 2 - 3, plot.center.Z - plot.size.Y / 2 + 3, plot.center.Z + plot.size.Y / 2 - 3 }
	space.floor = 0
	-- (Peu de blocs : 23 parcelles vides, il ne faut pas que le téléphone rame.)
	for _ = 1, 12 do
		Props.tallGrass(folder, Enclosures.randomPoint(space.id, 2, random), random, rgb(140, 160, 80))
	end
	for _ = 1, 5 do
		Props.bush(folder, Enclosures.randomPoint(space.id, 3, random), random, 1.4)
	end
	-- Des piquets et une corde le long du côté des visiteurs.
	local from, to = sideSegment(plot, plot.side)
	local count = math.max(1, math.round((to - from).Magnitude / 8))
	for i = 0, count do
		local spot = from + (to - from) * (i / count)
		part(folder, "Stake", v3(0.5, 2.6, 0.5), spot + v3(0, 1.3, 0), Props.WOOD_LIGHT, M.Wood, true)
	end
	local rope = part(folder, "Rope", v3(0.2, 0.2, (to - from).Magnitude), CFrame.lookAt((from + to) / 2 + v3(0, 2.2, 0), to + v3(0, 2.2, 0)), rgb(196, 176, 120), M.Fabric)
	rope.CastShadow = false
	-- Le panneau « À vendre ».
	local toward = plot.center - plot.view
	toward = v3(toward.X, 0, toward.Z).Unit
	local board = Props.sign(folder, plot.view + toward * 3, -toward, "PARCELLE À VENDRE\nchoisis tes animaux", 12, rgb(255, 228, 140))
	board.Size = v3(12, 4.4, 0.4)
	board.CFrame = board.CFrame * CFrame.new(0, 0.9, 0)
	local item = prompt(board, "Choisir les animaux", "Parcelle à vendre", 0, 12)
	item.Triggered:Connect(function(player)
		Zoo.remotes.choose:FireClient(player, space.id)
	end)
end

-- Acheter une parcelle vide pour ces animaux. Renvoie true si c'est fait.
function Enclosures.buy(player: Player?, id: string, habitatId: string): boolean
	local space = Enclosures.spaces[id]
	local habitat = Config.HABITAT_BY_ID[habitatId]
	if not space or space.open or not habitat or habitat.hidden then
		return false
	end
	if not Zoo.spend(habitat.price, "spaces", player) then
		return false
	end
	Zoo.state.plots[id] = habitatId
	Zoo.publish()
	openSpace(space, habitatId)
	if Enclosures.onBought then
		Enclosures.onBought(id)
	end
	Zoo.notify(nil, "spaceBought", habitat.name, if player then player.Name else "")
	return true
end

-- Les parcelles ouvertes (avec des animaux).
function Enclosures.openCount(): number
	local count = 0
	for _, space in Enclosures.spaces do
		if space.open then
			count += 1
		end
	end
	return count
end

function Enclosures.build()
	for _, plot in Config.PLOTS do
		local folder = Instance.new("Folder")
		folder.Name = plot.id
		folder.Parent = root
		local space = { id = plot.id, plot = plot, folder = folder, troughs = {}, poops = {}, pools = {}, open = false, floor = 0, gate = plot.view, path = {} }
		Enclosures.spaces[plot.id] = space
		local habitatId = Zoo.state.plots[plot.id] or plot.fixed
		if habitatId and Config.HABITAT_BY_ID[habitatId] then
			Zoo.state.plots[plot.id] = habitatId
			openSpace(space, habitatId)
		else
			forSale(space)
		end
	end
	Zoo.remotes.buyPlot.OnServerEvent:Connect(function(player, id, habitatId)
		if typeof(id) == "string" and typeof(habitatId) == "string" then
			Enclosures.buy(player, id, habitatId)
		end
	end)
	Zoo.remotes.buyToy.OnServerEvent:Connect(function(player, id, toy)
		if typeof(id) == "string" and typeof(toy) == "string" then
			Enclosures.buyToy(player, id, toy)
		end
	end)
end

return Enclosures

-- Les ŒUFS dessinés de l'interface (onglet Œufs : les cartes des œufs et les couveuses). Style demandé par le
-- propriétaire (04/10/2026, avec l'image d'un autre jeu en exemple) : un œuf à motifs, un gros contour sombre, un
-- reflet blanc, posé sur une vignette de la couleur de sa rareté, avec des rayons qui tournent derrière les plus
-- rares ; « les plus rares, un peu violets » : l'œuf doré a une couronne et des taches violettes, sur une vignette
-- violette. Les ŒUFS SPÉCIAUX des territoires (Levels.SPECIAL_EGG_ORDER) ont les dessins montrés au propriétaire :
-- carmin à bande dorée en zigzag, cuivre à bande rivetée, vert à ronces, bleu glacé à flocons.
-- Rien à publier sur Roblox (aucune image) : tout est fait de cadres de l'interface. La FORME d'œuf (plus étroite en
-- haut) est une rangée de ronds qui se chevauchent, d'un petit rond en haut à un grand en bas : ensemble, ils
-- dessinent exactement la forme qui joint les deux (bords lisses, comme un vrai ovale). Le contour : la même forme,
-- un peu plus grande, en sombre, derrière ; l'ombre : la forme en plus foncé, puis la même un peu plus petite et
-- décalée vers le haut à gauche, en clair. Les motifs restent à l'intérieur de l'œuf.
-- Couleurs et motif de chaque œuf : Levels.EGGS[type].color et .art (les mêmes servent aux œufs en 3D des couveuses
-- de la parcelle, Hub/Camp.luau).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Levels = require(ReplicatedStorage:WaitForChild("Shared").Levels)
local UI = require(script.Parent.UI)

local EggArt = {}

-- L'œuf, en « unités d'œuf » (sa largeur = 1) : hauteur EGG_H, rond du haut TOP_R, rond du bas BOTTOM_R, contour
-- OUTLINE (épaisseur), DISKS ronds pour la forme.
local EGG_H, TOP_R, BOTTOM_R, OUTLINE, DISKS = 1.3, 0.38, 0.5, 0.075, 10
local FULL_W, FULL_H = 1 + 2 * OUTLINE, EGG_H + 2 * OUTLINE
EggArt.ASPECT = FULL_W / FULL_H -- largeur / hauteur de la place d'un œuf (contour compris)

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

-- Un cadre centré en (x, y), de largeur `width` et de hauteur `height` (unités d'œuf) ; rond aux bouts sauf `square`.
local function put(parent: Instance, name: string, x: number, y: number, width: number, height: number, color: Color3, zIndex: number, rotation: number?, square: boolean?)
	return UI.new("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale((x + OUTLINE) / FULL_W, (y + OUTLINE) / FULL_H),
		Size = UDim2.fromScale(width / FULL_W, height / FULL_H),
		Rotation = rotation or 0,
		BackgroundColor3 = color,
		ZIndex = zIndex,
		Parent = parent,
	}, if square then nil else { UI.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
end

-- Un rond de diamètre `size`.
local function dot(parent: Instance, name: string, x: number, y: number, size: number, color: Color3, zIndex: number)
	return put(parent, name, x, y, size, size, color, zIndex)
end

-- La forme de l'œuf, grossie de `grow`, réduite à `scale` autour de son centre et décalée de (dx, dy).
local function silhouette(parent: Instance, name: string, color: Color3, zIndex: number, grow: number, scale: number, dx: number, dy: number)
	local centerY = EGG_H / 2
	for index = 0, DISKS - 1 do
		local f = index / (DISKS - 1)
		local radius = (TOP_R + (BOTTOM_R - TOP_R) * f) * scale + grow
		local y = TOP_R + (EGG_H - BOTTOM_R - TOP_R) * f
		dot(parent, name, 0.5 + dx, centerY + (y - centerY) * scale + dy, radius * 2, color, zIndex)
	end
end

-- Une étincelle : deux barres fines en croix.
local function sparkle(parent: Instance, x: number, y: number, size: number, zIndex: number)
	put(parent, "Sparkle", x, y, size, size * 0.22, WHITE, zIndex, 45)
	put(parent, "Sparkle", x, y, size, size * 0.22, WHITE, zIndex, -45)
end

-- Une ligne brisée d'épaisseur `thickness` qui passe par les points { { x, y } } : une barre ronde aux bouts par
-- segment (elles se chevauchent aux coudes : la ligne reste continue).
local function line(parent: Instance, name: string, points: { { number } }, thickness: number, color: Color3, zIndex: number)
	for index = 2, #points do
		local a, b = points[index - 1], points[index]
		local dx, dy = b[1] - a[1], b[2] - a[2]
		put(parent, name, (a[1] + b[1]) / 2, (a[2] + b[2]) / 2, math.sqrt(dx * dx + dy * dy) + thickness, thickness, color, zIndex, math.deg(math.atan2(dy, dx)))
	end
end

-- Un flocon : trois barres qui se croisent (0°, 60°, -60°), de longueur `size`.
local function flake(parent: Instance, x: number, y: number, size: number, color: Color3, zIndex: number)
	for _, angle in { 90, 30, -30 } do
		put(parent, "Flake", x, y, size, size * 0.16, color, zIndex, angle)
	end
end

-- Les motifs (art.pattern), dans l'œuf (unités d'œuf : x de 0 à 1, y de 0 en haut à EGG_H en bas).
local PATTERNS = {}

-- Taches rondes (œuf commun).
function PATTERNS.spots(holder: Instance, art, zIndex: number)
	for _, spot in { { 0.32, 0.43, 0.22 }, { 0.66, 0.3, 0.16 }, { 0.7, 0.7, 0.26 }, { 0.34, 0.86, 0.2 }, { 0.57, 1.1, 0.16 }, { 0.19, 0.63, 0.12 }, { 0.84, 0.98, 0.14 } } do
		dot(holder, "Spot", spot[1], spot[2], spot[3], art.detail, zIndex)
	end
end

-- Une croix claire et deux points (œuf rare).
function PATTERNS.cross(holder: Instance, art, zIndex: number)
	put(holder, "Streak", 0.5, 0.74, 0.64, 0.11, art.detail, zIndex, 40)
	put(holder, "Streak", 0.5, 0.74, 0.64, 0.11, art.detail, zIndex, -40)
	dot(holder, "Spot", 0.27, 0.38, 0.1, art.detail, zIndex)
	dot(holder, "Spot", 0.77, 1.04, 0.09, art.detail, zIndex)
	dot(holder, "Spot", 0.66, 0.22, 0.07, art.detail, zIndex)
end

-- Une couronne violette (une bande et ses pointes), des taches violettes et des étincelles (œuf doré, le plus rare).
function PATTERNS.crown(holder: Instance, art, zIndex: number)
	put(holder, "Crown", 0.5, 0.99, 0.62, 0.13, art.detail, zIndex)
	for _, x in { 0.27, 0.42, 0.58, 0.73 } do
		put(holder, "CrownPoint", x, 0.92, 0.13, 0.13, art.detail, zIndex, 45, true)
	end
	dot(holder, "Jewel", 0.5, 0.99, 0.07, WHITE, zIndex + 1)
	dot(holder, "Spot", 0.24, 0.66, 0.1, art.detail, zIndex)
	dot(holder, "Spot", 0.78, 0.78, 0.08, art.detail, zIndex)
	dot(holder, "Spot", 0.5, 1.17, 0.07, art.detail, zIndex)
	sparkle(holder, 0.36, 0.46, 0.2, zIndex)
	sparkle(holder, 0.7, 0.34, 0.13, zIndex)
	sparkle(holder, 0.62, 0.64, 0.1, zIndex)
end

-- Une bande dorée en zigzag et des points dorés (œuf carmin, la vallée du Roi carmin).
function PATTERNS.zigzag(holder: Instance, art, zIndex: number)
	line(holder, "Zigzag", { { 0.12, 0.6 }, { 0.24, 0.48 }, { 0.37, 0.6 }, { 0.5, 0.48 }, { 0.63, 0.6 }, { 0.76, 0.48 }, { 0.88, 0.6 } }, 0.075, art.detail, zIndex)
	for _, spot in { { 0.33, 0.9, 0.095 }, { 0.64, 1.0, 0.083 }, { 0.8, 0.78, 0.07 }, { 0.19, 0.75, 0.07 } } do
		dot(holder, "Spot", spot[1], spot[2], spot[3], art.detail, zIndex)
	end
end

-- Une bande sombre à rivets clairs et deux points sombres (œuf de cuivre, le col des Pillards de cuivre).
function PATTERNS.rivets(holder: Instance, art, zIndex: number)
	put(holder, "Band", 0.5, 0.8, 0.88, 0.13, art.detail, zIndex)
	for _, x in { 0.19, 0.39, 0.61, 0.81 } do
		dot(holder, "Rivet", x, if x < 0.3 or x > 0.7 then 0.785 else 0.8, 0.062, art.accent or WHITE, zIndex + 1)
	end
	dot(holder, "Spot", 0.36, 0.36, 0.071, art.detail, zIndex)
	dot(holder, "Spot", 0.69, 1.04, 0.083, art.detail, zIndex)
end

-- Deux ronces ondulées avec leurs épines, et deux feuilles claires (œuf des ronces, la forêt des Gardiens des ronces).
function PATTERNS.thorns(holder: Instance, art, zIndex: number)
	line(holder, "Vine", { { 0.13, 0.44 }, { 0.26, 0.5 }, { 0.4, 0.45 }, { 0.56, 0.52 }, { 0.7, 0.56 }, { 0.82, 0.48 }, { 0.87, 0.4 } }, 0.055, art.detail, zIndex)
	line(holder, "Vine", { { 0.1, 0.93 }, { 0.24, 0.99 }, { 0.4, 0.93 }, { 0.57, 0.99 }, { 0.73, 1.05 }, { 0.86, 1 }, { 0.9, 0.92 } }, 0.055, art.detail, zIndex)
	for _, thorn in { { 0.31, 0.43 }, { 0.71, 0.5 }, { 0.42, 0.88 }, { 0.78, 1.0 } } do
		put(holder, "Thorn", thorn[1], thorn[2], 0.075, 0.075, art.detail, zIndex, 45, true)
	end
	put(holder, "Leaf", 0.5, 0.45, 0.12, 0.07, art.accent or WHITE, zIndex + 1, -15)
	put(holder, "Leaf", 0.22, 1.04, 0.12, 0.07, art.accent or WHITE, zIndex + 1, 20)
end

-- Deux flocons blancs et deux points (œuf de givre, le glacier de la Légion du givre).
function PATTERNS.flakes(holder: Instance, art, zIndex: number)
	flake(holder, 0.38, 0.51, 0.31, art.detail, zIndex)
	flake(holder, 0.67, 0.9, 0.22, art.detail, zIndex)
	dot(holder, "Spot", 0.21, 0.95, 0.071, art.detail, zIndex)
	dot(holder, "Spot", 0.74, 0.4, 0.06, art.detail, zIndex)
end

-- Un œuf dessiné, sans vignette. props = { Name, Size, Position, AnchorPoint, ZIndex (celui de l'œuf entier), Parent }.
-- Il garde sa forme d'œuf (ASPECT) dans la place qu'on lui donne.
function EggArt.egg(eggType: string, props: { [string]: any })
	local egg = Levels.EGGS[eggType] or Levels.EGGS.Common
	local art = egg.art
	local holder = UI.new("Frame", {
		Name = props.Name or "EggArt",
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5),
		Position = props.Position or UDim2.fromScale(0.5, 0.5),
		Size = props.Size or UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = props.ZIndex or 1,
		Parent = props.Parent,
	}, { UI.new("UIAspectRatioConstraint", { AspectRatio = EggArt.ASPECT }) })
	-- (ombre : un peu violette pour l'œuf doré)
	local shade = egg.color:Lerp(if art.pattern == "crown" then art.detail else BLACK, 0.24)
	silhouette(holder, "Outline", UI.Colors.Ink, 1, OUTLINE, 1, 0, 0)
	silhouette(holder, "Shade", shade, 2, 0, 1, 0, 0)
	silhouette(holder, "Shell", egg.color, 3, 0, 0.9, -0.035, -0.045)
	;(PATTERNS[art.pattern] or PATTERNS.spots)(holder, art, 4)
	put(holder, "Shine", 0.31, 0.36, 0.15, 0.27, WHITE, 6, -24)
	dot(holder, "Glint", 0.46, 0.17, 0.07, WHITE, 6)
	return holder
end

-- La vignette d'un œuf : un fond de la couleur de sa rareté (art.frame, en dégradé), des rayons qui tournent derrière
-- les plus rares (art.rays), l'œuf au milieu. props = { Name, Size, Position, AnchorPoint, Parent }.
function EggArt.tile(eggType: string, props: { [string]: any })
	local egg = Levels.EGGS[eggType] or Levels.EGGS.Common
	local art = egg.art
	local tile = UI.new("Frame", {
		Name = props.Name or "EggTile",
		AnchorPoint = props.AnchorPoint or Vector2.new(0, 0),
		Position = props.Position or UDim2.fromOffset(0, 0),
		Size = props.Size or UDim2.fromOffset(56, 56),
		BackgroundColor3 = WHITE,
		ClipsDescendants = true,
		Parent = props.Parent,
	}, {
		UI.corner(8),
		UI.stroke(UI.Colors.Ink, 2.5),
		UI.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(art.frame:Lerp(WHITE, 0.28), art.frame:Lerp(BLACK, 0.28)) }),
	})
	if art.rays then
		local rays = UI.new("Frame", {
			Name = "Rays",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1.7, 1.7),
			BackgroundTransparency = 1,
			ZIndex = 1,
			Parent = tile,
		}, { UI.new("UIAspectRatioConstraint", { AspectRatio = 1 }) })
		for index = 0, 5 do
			UI.new("Frame", {
				Name = "Ray",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.11, 1),
				Rotation = index * 30,
				BackgroundColor3 = WHITE,
				BackgroundTransparency = 0.72,
				Parent = rays,
			})
		end
		TweenService:Create(rays, TweenInfo.new(16, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), { Rotation = 360 }):Play()
		UI.new("Frame", {
			Name = "Glow",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.53),
			Size = UDim2.fromScale(0.72, 0.72),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.8,
			ZIndex = 2,
			Parent = tile,
		}, { UI.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }), UI.new("UIAspectRatioConstraint", { AspectRatio = 1 }) })
	end
	EggArt.egg(eggType, { Size = UDim2.fromScale(0.72, 0.84), Position = UDim2.fromScale(0.5, 0.52), ZIndex = 3, Parent = tile })
	return tile
end

return EggArt

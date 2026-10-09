-- DES DESSINS EN CADRES (pas d'images importées) : paquets cadeaux, fioles de potion, bonshommes, rayons qui tournent.
-- Pour les fenêtres « solides » que veut le créateur (09/10 : « travaille tes icônes, même les boutons font moche »,
-- avec en modèle la fenêtre « Cadeaux gratuits » d'un gros jeu Roblox). Chaque dessin tient dans un cadre de
-- 110 x 110, réduit ou agrandi par `scale`, centré sur `position`.
local Draw = {}

Draw.DARK = Color3.fromRGB(20, 20, 30)
local DARK = Draw.DARK
local RIBBON = Color3.fromRGB(255, 200, 40)

-- Les quatre potions (Config.POTIONS) : leur couleur et la lettre écrite sur la fiole.
Draw.POTIONS = {
	rank = { color = Color3.fromRGB(60, 220, 90), glyph = "S" },
	xp = { color = Color3.fromRGB(70, 140, 255), glyph = "XP" },
	coins = { color = Color3.fromRGB(255, 200, 40), glyph = "$" },
	damage = { color = Color3.fromRGB(240, 60, 70), glyph = "x2" },
}

-- Un rectangle arrondi (ou un rond, avec UDim.new(0.5, 0)), avec ou sans contour sombre.
function Draw.round(parent: Instance, name: string, size: UDim2, position: UDim2, color: Color3, radius: UDim, outline: number?): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = position
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius
	corner.Parent = frame
	if outline then
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = outline
		stroke.Color = DARK
		stroke.Parent = frame
	end
	frame.Parent = parent
	return frame
end

-- Un dégradé du haut (clair) vers le bas (sombre) : du relief sur un bouton ou une boîte.
function Draw.shade(frame: GuiObject, top: number, bottom: number): UIGradient
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(Color3.new(top, top, top), Color3.new(bottom, bottom, bottom))
	gradient.Parent = frame
	return gradient
end

local function holder(parent: Instance, name: string, position: UDim2, scale: number): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromOffset(110, 110)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = position
	local size = Instance.new("UIScale")
	size.Scale = scale
	size.Parent = frame
	frame.Parent = parent
	return frame
end

-- UN PAQUET CADEAU : la boîte, son couvercle, le ruban doré et son nœud. (`Body` et `Lid` : pour le recolorer.)
function Draw.gift(parent: Instance, position: UDim2, scale: number, color: Color3): Frame
	local box = holder(parent, "GiftBox", position, scale)
	local light = color:Lerp(Color3.new(1, 1, 1), 0.25)
	Draw.round(box, "BowLeft", UDim2.fromOffset(36, 26), UDim2.fromOffset(17, 6), RIBBON, UDim.new(0.5, 0), 3).Rotation = 24
	Draw.round(box, "BowRight", UDim2.fromOffset(36, 26), UDim2.fromOffset(57, 6), RIBBON, UDim.new(0.5, 0), 3).Rotation = -24
	Draw.shade(Draw.round(box, "Body", UDim2.fromOffset(84, 54), UDim2.fromOffset(13, 50), color, UDim.new(0, 8), 3), 1, 0.62)
	Draw.shade(Draw.round(box, "BandBody", UDim2.fromOffset(20, 54), UDim2.fromOffset(45, 50), RIBBON, UDim.new(0, 0)), 1, 0.7)
	Draw.shade(Draw.round(box, "Lid", UDim2.fromOffset(98, 24), UDim2.fromOffset(6, 30), light, UDim.new(0, 7), 3), 1, 0.8)
	Draw.round(box, "BandLid", UDim2.fromOffset(20, 24), UDim2.fromOffset(45, 30), RIBBON, UDim.new(0, 0))
	Draw.round(box, "Knot", UDim2.fromOffset(20, 20), UDim2.fromOffset(45, 13), Color3.fromRGB(255, 160, 20), UDim.new(0.5, 0), 3)
	Draw.round(box, "Shine", UDim2.fromOffset(8, 30), UDim2.fromOffset(22, 60), Color3.new(1, 1, 1), UDim.new(0.5, 0)).BackgroundTransparency = 0.6
	return box
end

-- UNE FIOLE DE POTION : le bouchon, le goulot de verre, la panse ronde pleine de potion, un reflet, deux bulles et
-- sa lettre (S, XP, $, x2). (`Body` et `Glyph` : pour la recolorer.)
function Draw.potion(parent: Instance, position: UDim2, scale: number, color: Color3, glyph: string?): Frame
	local flask = holder(parent, "Potion", position, scale)
	local glass = Color3.fromRGB(205, 235, 255)
	Draw.shade(Draw.round(flask, "Cork", UDim2.fromOffset(34, 18), UDim2.fromOffset(38, 2), Color3.fromRGB(160, 105, 55), UDim.new(0, 5), 3), 1, 0.7)
	Draw.shade(Draw.round(flask, "Neck", UDim2.fromOffset(30, 34), UDim2.fromOffset(40, 16), glass, UDim.new(0, 6), 3), 1, 0.85)
	Draw.shade(Draw.round(flask, "Body", UDim2.fromOffset(84, 84), UDim2.fromOffset(13, 26), color, UDim.new(0.5, 0), 3), 1, 0.55)
	Draw.round(flask, "Shine", UDim2.fromOffset(10, 34), UDim2.fromOffset(26, 40), Color3.new(1, 1, 1), UDim.new(0.5, 0)).BackgroundTransparency = 0.45
	Draw.round(flask, "Dot", UDim2.fromOffset(8, 8), UDim2.fromOffset(28, 80), Color3.new(1, 1, 1), UDim.new(0.5, 0)).BackgroundTransparency = 0.55
	Draw.round(flask, "Bubble1", UDim2.fromOffset(12, 12), UDim2.fromOffset(66, 56), Color3.new(1, 1, 1), UDim.new(0.5, 0)).BackgroundTransparency = 0.7
	Draw.round(flask, "Bubble2", UDim2.fromOffset(7, 7), UDim2.fromOffset(60, 76), Color3.new(1, 1, 1), UDim.new(0.5, 0)).BackgroundTransparency = 0.7
	local label = Instance.new("TextLabel")
	label.Name = "Glyph"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromOffset(60, 40)
	label.Position = UDim2.fromOffset(25, 50)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = glyph or ""
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = DARK
	stroke.Parent = label
	label.Parent = flask
	return flask
end

-- DEUX BONSHOMMES (des amis) : deux têtes rondes et deux épaules.
function Draw.people(parent: Instance, position: UDim2, scale: number): Frame
	local pair = holder(parent, "People", position, scale)
	for index, info in { { 64, Color3.fromRGB(120, 200, 255) }, { 28, Color3.fromRGB(255, 220, 120) } } do
		local x, color = info[1], info[2]
		Draw.shade(Draw.round(pair, "Body" .. index, UDim2.fromOffset(56, 40), UDim2.fromOffset(x - 10, 64), color, UDim.new(0, 18), 4), 1, 0.7)
		Draw.shade(Draw.round(pair, "Head" .. index, UDim2.fromOffset(40, 40), UDim2.fromOffset(x - 2, 22), color, UDim.new(0.5, 0), 4), 1, 0.75)
	end
	return pair
end

-- DES RAYONS derrière un objet (à faire tourner avec `.Rotation`).
function Draw.rays(parent: Instance, position: UDim2, color: Color3): Frame
	local star = Instance.new("Frame")
	star.Name = "Rays"
	star.BackgroundTransparency = 1
	star.Size = UDim2.fromOffset(2, 2)
	star.AnchorPoint = Vector2.new(0.5, 0.5)
	star.Position = position
	for index = 1, 6 do
		local ray = Instance.new("Frame")
		ray.AnchorPoint = Vector2.new(0.5, 0.5)
		ray.Position = UDim2.fromScale(0.5, 0.5)
		ray.Size = UDim2.fromOffset(18, 132)
		ray.Rotation = index * 30
		ray.BorderSizePixel = 0
		ray.BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.5)
		local fade = Instance.new("UIGradient")
		fade.Rotation = 90
		fade.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.55),
			NumberSequenceKeypoint.new(1, 1),
		})
		fade.Parent = ray
		ray.Parent = star
	end
	star.Parent = parent
	return star
end

-- UN ŒUF : la coquille, trois taches, un reflet.
function Draw.egg(parent: Instance, position: UDim2, scale: number, color: Color3?): Frame
	local egg = holder(parent, "Egg", position, scale)
	local shell = color or Color3.fromRGB(250, 240, 220)
	Draw.shade(Draw.round(egg, "Shell", UDim2.fromOffset(72, 92), UDim2.fromOffset(19, 9), shell, UDim.new(0.5, 0), 3), 1, 0.72)
	for index, spot in { { 36, 40, 14 }, { 58, 58, 11 }, { 44, 72, 9 } } do
		Draw.round(egg, "Spot" .. index, UDim2.fromOffset(spot[3], spot[3]), UDim2.fromOffset(spot[1], spot[2]), shell:Lerp(Color3.fromRGB(120, 80, 40), 0.35), UDim.new(0.5, 0)).BackgroundTransparency = 0.25
	end
	Draw.round(egg, "Shine", UDim2.fromOffset(10, 22), UDim2.fromOffset(32, 20), Color3.new(1, 1, 1), UDim.new(0.5, 0)).BackgroundTransparency = 0.45
	return egg
end

-- UNE PATTE : le coussinet et quatre doigts.
function Draw.paw(parent: Instance, position: UDim2, scale: number, color: Color3?): Frame
	local paw = holder(parent, "Paw", position, scale)
	local pad = color or Color3.fromRGB(255, 244, 222)
	for index, toe in { { 12, 34 }, { 34, 14 }, { 58, 14 }, { 80, 34 } } do
		Draw.shade(Draw.round(paw, "Toe" .. index, UDim2.fromOffset(22, 24), UDim2.fromOffset(toe[1], toe[2]), pad, UDim.new(0.5, 0), 3), 1, 0.75)
	end
	Draw.shade(Draw.round(paw, "Pad", UDim2.fromOffset(60, 50), UDim2.fromOffset(25, 50), pad, UDim.new(0.5, 0), 3), 1, 0.7)
	return paw
end

-- UN SAC : le corps, le rabat, la boucle et la bride.
function Draw.bag(parent: Instance, position: UDim2, scale: number, color: Color3?): Frame
	local bag = holder(parent, "Bag", position, scale)
	local cloth = color or Color3.fromRGB(225, 140, 55)
	Draw.round(bag, "Strap", UDim2.fromOffset(26, 22), UDim2.fromOffset(42, 6), cloth:Lerp(Color3.new(0, 0, 0), 0.3), UDim.new(0, 8), 3)
	Draw.shade(Draw.round(bag, "Body", UDim2.fromOffset(80, 74), UDim2.fromOffset(15, 30), cloth, UDim.new(0, 12), 3), 1, 0.65)
	Draw.shade(Draw.round(bag, "Flap", UDim2.fromOffset(86, 32), UDim2.fromOffset(12, 22), cloth:Lerp(Color3.new(1, 1, 1), 0.25), UDim.new(0, 10), 3), 1, 0.8)
	Draw.round(bag, "Buckle", UDim2.fromOffset(18, 18), UDim2.fromOffset(46, 46), RIBBON, UDim.new(0.5, 0), 3)
	return bag
end

-- UNE ÉPÉE (penchée) : la lame, la garde, la poignée, le pommeau.
function Draw.sword(parent: Instance, position: UDim2, scale: number, color: Color3?): Frame
	local sword = holder(parent, "Sword", position, scale)
	sword.Rotation = 40
	local steel = color or Color3.fromRGB(215, 220, 235)
	Draw.shade(Draw.round(sword, "Blade", UDim2.fromOffset(18, 68), UDim2.fromOffset(46, -2), steel, UDim.new(0, 5), 3), 1, 0.7)
	Draw.round(sword, "Edge", UDim2.fromOffset(4, 54), UDim2.fromOffset(50, 4), Color3.new(1, 1, 1), UDim.new(0.5, 0)).BackgroundTransparency = 0.4
	Draw.shade(Draw.round(sword, "Guard", UDim2.fromOffset(54, 12), UDim2.fromOffset(28, 64), RIBBON, UDim.new(0, 4), 3), 1, 0.7)
	Draw.shade(Draw.round(sword, "Grip", UDim2.fromOffset(16, 26), UDim2.fromOffset(47, 76), Color3.fromRGB(120, 70, 40), UDim.new(0, 4), 3), 1, 0.7)
	Draw.round(sword, "Pommel", UDim2.fromOffset(20, 20), UDim2.fromOffset(45, 98), RIBBON, UDim.new(0.5, 0), 3)
	return sword
end

-- UN CADDIE (la boutique) : le panier, la poignée, deux roues.
function Draw.cart(parent: Instance, position: UDim2, scale: number, color: Color3?): Frame
	local cart = holder(parent, "Cart", position, scale)
	local paint = color or Color3.fromRGB(245, 248, 255)
	Draw.round(cart, "Handle", UDim2.fromOffset(10, 46), UDim2.fromOffset(10, 22), paint:Lerp(Color3.new(0, 0, 0), 0.25), UDim.new(0, 4), 3).Rotation = 22
	Draw.shade(Draw.round(cart, "Basket", UDim2.fromOffset(70, 42), UDim2.fromOffset(24, 40), paint, UDim.new(0, 8), 3), 1, 0.65)
	for index, x in { 44, 62 } do
		Draw.round(cart, "Bar" .. index, UDim2.fromOffset(3, 32), UDim2.fromOffset(x, 45), Color3.new(0, 0, 0), UDim.new(0.5, 0)).BackgroundTransparency = 0.6
	end
	for index, x in { 30, 68 } do
		local wheel = Draw.round(cart, "Wheel" .. index, UDim2.fromOffset(20, 20), UDim2.fromOffset(x, 86), Color3.fromRGB(40, 40, 60), UDim.new(0.5, 0), 3)
		Draw.round(wheel, "Hub", UDim2.fromOffset(8, 8), UDim2.fromOffset(6, 6), Color3.fromRGB(200, 200, 215), UDim.new(0.5, 0))
	end
	return cart
end

-- UNE PIÈCE D'OR avec son « $ ».
function Draw.coin(parent: Instance, position: UDim2, scale: number, color: Color3?): Frame
	local coin = holder(parent, "Coin", position, scale)
	local gold = color or Color3.fromRGB(255, 205, 40)
	Draw.shade(Draw.round(coin, "Disc", UDim2.fromOffset(86, 86), UDim2.fromOffset(12, 12), gold, UDim.new(0.5, 0), 3), 1, 0.72)
	Draw.round(coin, "Ring", UDim2.fromOffset(66, 66), UDim2.fromOffset(22, 22), gold:Lerp(Color3.new(0, 0, 0), 0.18), UDim.new(0.5, 0))
	local label = Instance.new("TextLabel")
	label.Name = "Sign"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromOffset(60, 56)
	label.Position = UDim2.fromOffset(25, 27)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 240, 150)
	label.Text = "$"
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = DARK
	stroke.Parent = label
	label.Parent = coin
	return coin
end

-- UNE ROUE DENTÉE (les réglages) : huit dents, le disque, le trou du milieu.
function Draw.gear(parent: Instance, position: UDim2, scale: number, color: Color3?): Frame
	local gear = holder(parent, "Gear", position, scale)
	local metal = color or Color3.fromRGB(84, 92, 124)
	for index = 0, 7 do
		local angle = index * math.pi / 4
		local tooth = Draw.round(gear, "Tooth" .. index, UDim2.fromOffset(20, 18), UDim2.fromOffset(55 + math.cos(angle) * 40, 55 + math.sin(angle) * 40), metal, UDim.new(0, 4), 3)
		tooth.AnchorPoint = Vector2.new(0.5, 0.5)
		tooth.Rotation = math.deg(angle)
	end
	Draw.shade(Draw.round(gear, "Disc", UDim2.fromOffset(66, 66), UDim2.fromOffset(22, 22), metal, UDim.new(0.5, 0), 3), 1, 0.7)
	Draw.round(gear, "Hole", UDim2.fromOffset(26, 26), UDim2.fromOffset(42, 42), DARK, UDim.new(0.5, 0))
	return gear
end

-- L'ICÔNE PAR SON NOM (pour les bandeaux des fenêtres et les boutons du menu).
local ICONS = {
	gift = function(parent, position, scale, color)
		return Draw.gift(parent, position, scale, color or Color3.fromRGB(235, 50, 80))
	end,
	potion = function(parent, position, scale, color)
		return Draw.potion(parent, position, scale, color or Color3.fromRGB(255, 90, 220), "")
	end,
	people = function(parent, position, scale)
		return Draw.people(parent, position, scale)
	end,
	egg = Draw.egg,
	paw = Draw.paw,
	bag = Draw.bag,
	sword = Draw.sword,
	cart = Draw.cart,
	coin = Draw.coin,
	gear = Draw.gear,
}
function Draw.icon(parent: Instance, kind: string, position: UDim2, scale: number, color: Color3?): Frame
	return ICONS[kind](parent, position, scale, color)
end

return Draw

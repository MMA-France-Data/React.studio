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

return Draw

-- Petits outils pour construire le décor avec des blocs.
local Build = {}

function Build.part(parent: Instance, name: string, size: Vector3, cframe: CFrame | Vector3, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = if typeof(cframe) == "Vector3" then CFrame.new(cframe) else cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Cylindre debout (rond vu d'en haut).
function Build.disc(parent: Instance, name: string, diameter: number, height: number, position: Vector3, color: Color3, material: Enum.Material?): Part
	local part = Build.part(
		parent,
		name,
		Vector3.new(height, diameter, diameter),
		CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		material
	)
	part.Shape = Enum.PartType.Cylinder
	return part
end

-- Sol en damier : des carreaux de deux couleurs (et d'une matière), dessus à la hauteur de `center`.
function Build.checker(parent: Instance, name: string, center: Vector3, sizeX: number, sizeZ: number, cell: number, colorA: Color3, colorB: Color3, thickness: number?, material: Enum.Material?): Model
	local model = Instance.new("Model")
	model.Name = name
	local depth = thickness or 2
	local countX = math.max(1, math.round(sizeX / cell))
	local countZ = math.max(1, math.round(sizeZ / cell))
	local stepX, stepZ = sizeX / countX, sizeZ / countZ
	for ix = 1, countX do
		for iz = 1, countZ do
			local position = Vector3.new(
				center.X - sizeX / 2 + (ix - 0.5) * stepX,
				center.Y - depth / 2,
				center.Z - sizeZ / 2 + (iz - 0.5) * stepZ
			)
			Build.part(model, "Tile", Vector3.new(stepX, depth, stepZ), position, if (ix + iz) % 2 == 0 then colorA else colorB, material)
		end
	end
	model.Parent = parent
	return model
end

-- Gros texte blanc à contour noir (le style du jeu).
function Build.text(parent: Instance, name: string, size: UDim2, position: UDim2, color: Color3?): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Size = size
	label.Position = position
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.Text = ""
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Parent = label
	label.Parent = parent
	return label
end

-- Panneau écrit sur une face d'un bloc. Le texte est posé par le client (attribut « T » = clé|argument), dans la
-- langue du joueur.
function Build.sign(part: BasePart, face: Enum.NormalId, key: string, color: Color3?): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.AutoLocalize = false
	gui.LightInfluence = 0
	gui.Parent = part
	local label = Build.text(gui, "Label", UDim2.fromScale(0.94, 0.9), UDim2.fromScale(0.03, 0.05), color)
	label:SetAttribute("T", key)
	label:AddTag("T")
	return label
end

-- Étiquette qui flotte au-dessus d'un objet, avec deux lignes (« Title » et « Info »).
function Build.billboard(adornee: BasePart, height: number): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Adornee = adornee
	gui.Size = UDim2.fromScale(14, 5)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	gui.MaxDistance = 90
	gui.AutoLocalize = false
	gui.LightInfluence = 0
	gui.Parent = adornee
	Build.text(gui, "Title", UDim2.fromScale(1, 0.45), UDim2.fromScale(0, 0))
	Build.text(gui, "Level", UDim2.fromScale(1, 0.28), UDim2.fromScale(0, 0.45), Color3.fromRGB(255, 221, 51))
	Build.text(gui, "Info", UDim2.fromScale(1, 0.27), UDim2.fromScale(0, 0.73), Color3.fromRGB(120, 255, 110))
	return gui
end

return Build

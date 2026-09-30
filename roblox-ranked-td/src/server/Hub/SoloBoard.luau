-- Tableaux du classement SOLO (données : SoloLeaderboard.luau), séparés du classement ranked. Deux panneaux construits
-- par HubMap, un de chaque côté de la place centrale, tournés vers le centre. Recto verso : la face vers la place montre
-- un classement (« MEILLEURE VAGUE » à l'est, « MEILLEUR DPS » à l'ouest), le dos montre l'autre. Top 10 de tous les
-- serveurs : place, nom du joueur, valeur (NumberFormat.short). Même famille que les tableaux du classé et du fief :
-- fond sombre, titre doré, lignes arrondies. Rien d'autre ici : pas de sauvegarde, pas de règle du jeu.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local NumberFormat = require(Shared.NumberFormat)

local SoloBoard = {}

SoloBoard.ROWS = 10
SoloBoard.TITLES = { Wave = "MEILLEURE VAGUE", Dps = "MEILLEUR DPS" }
SoloBoard.COLUMNS = { Wave = "VAGUE", Dps = "DPS" }
SoloBoard.EMPTY = "Aucun record pour l'instant"

local GOLD = Color3.fromRGB(236, 192, 105)
local IVORY = Color3.fromRGB(238, 226, 197)
local MUTED = Color3.fromRGB(179, 190, 205)
local PODIUM = { Color3.fromRGB(255, 215, 90), Color3.fromRGB(214, 222, 232), Color3.fromRGB(222, 156, 98) } -- or, argent, bronze

-- Taille de l'écran d'une face, en pixels (panneau de 19 x 13 studs : 50 pixels par stud).
local WIDTH, HEIGHT = 950, 650
local ROW_TOP, ROW_HEIGHT = 150, 44

local faces = { Wave = {}, Dps = {} } -- [classement] = faces qui l'affichent : { rows = { { frame, rank, name, value } }, empty }

local function label(parent: Instance, name: string, text: string, x: number, y: number, width: number, height: number, size: number, color: Color3, font: Enum.Font?, align: Enum.TextXAlignment?)
	local item = Instance.new("TextLabel")
	item.Name = name
	item.BackgroundTransparency = 1
	item.Position = UDim2.fromOffset(x, y)
	item.Size = UDim2.fromOffset(width, height)
	item.Font = font or Enum.Font.GothamBold
	item.Text = text
	item.TextColor3 = color
	item.TextXAlignment = align or Enum.TextXAlignment.Center
	item.TextTruncate = Enum.TextTruncate.AtEnd
	item.TextScaled = true
	item.ZIndex = 3
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = size
	limit.MinTextSize = 12
	limit.Parent = item
	item.Parent = parent
	return item
end

-- Une face du panneau (Front = vers la place, Back = le dos) qui affiche le classement `kind` ("Wave" ou "Dps").
local function buildFace(board: BasePart, face: Enum.NormalId, kind: string)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Solo" .. kind .. face.Name -- ex. SoloWaveFront
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(WIDTH, HEIGHT)
	gui.LightInfluence, gui.Brightness, gui.AlwaysOnTop, gui.MaxDistance = 0, 1, false, 185
	gui:SetAttribute("SoloKind", kind)
	gui.Parent = board
	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = Color3.fromRGB(20, 28, 39)
	background.BorderSizePixel = 0
	background.ZIndex = 1
	background.Parent = gui

	label(background, "Heading", "CLASSEMENT SOLO", 30, 14, WIDTH - 60, 50, 46, GOLD, Enum.Font.GothamBlack)
	label(background, "Kind", SoloBoard.TITLES[kind], 30, 66, WIDTH - 60, 40, 34, IVORY, Enum.Font.GothamBlack)
	label(background, "RankHeader", "#", 28, 114, 80, 28, 22, MUTED)
	label(background, "NameHeader", "JOUEUR", 120, 114, 470, 28, 22, MUTED, nil, Enum.TextXAlignment.Left)
	label(background, "ValueHeader", SoloBoard.COLUMNS[kind], 600, 114, 318, 28, 22, MUTED, nil, Enum.TextXAlignment.Right)

	local rows = {}
	for i = 1, SoloBoard.ROWS do
		local frame = Instance.new("Frame")
		frame.Name = "Row" .. i
		frame.Position = UDim2.fromOffset(20, ROW_TOP + (i - 1) * ROW_HEIGHT)
		frame.Size = UDim2.fromOffset(WIDTH - 40, ROW_HEIGHT - 5)
		frame.BackgroundColor3 = Color3.fromRGB(39, 49, 64)
		frame.BackgroundTransparency = if i % 2 == 0 then 0.45 else 0.12
		frame.BorderSizePixel = 0
		frame.ZIndex = 2
		frame.Visible = false
		frame.Parent = background
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = frame
		rows[i] = {
			frame = frame,
			rank = label(frame, "Rank", "#" .. i, 8, 2, 80, ROW_HEIGHT - 9, 30, if i <= 3 then PODIUM[i] else MUTED, Enum.Font.GothamBlack),
			name = label(frame, "PlayerName", "", 100, 2, 480, ROW_HEIGHT - 9, 30, IVORY, nil, Enum.TextXAlignment.Left),
			value = label(frame, "Value", "", 590, 2, 308, ROW_HEIGHT - 9, 30, GOLD, Enum.Font.GothamBlack, Enum.TextXAlignment.Right),
		}
	end
	local empty = label(background, "Empty", SoloBoard.EMPTY, 30, ROW_TOP + 10, WIDTH - 60, 40, 30, MUTED)
	label(background, "Footer", "Tous les serveurs · mis à jour chaque minute", 30, HEIGHT - 50, WIDTH - 60, 32, 24, MUTED)
	table.insert(faces[kind], { rows = rows, empty = empty })
end

-- Habille un panneau : face vers la place = classement `front`, dos = l'autre.
function SoloBoard.attach(board: BasePart, front: string)
	local back = if front == "Wave" then "Dps" else "Wave"
	buildFace(board, Enum.NormalId.Front, front)
	buildFace(board, Enum.NormalId.Back, back)
end

-- Affiche un classement sur toutes ses faces. entries = { { name, value } } du meilleur au moins bon (SoloLeaderboard).
function SoloBoard.show(kind: string, entries)
	for _, face in faces[kind] or {} do
		for i, row in face.rows do
			local entry = entries[i]
			row.frame.Visible = entry ~= nil
			row.name.Text = if entry then tostring(entry.name) else ""
			row.value.Text = if entry then NumberFormat.short(tonumber(entry.value) or 0) else ""
		end
		face.empty.Visible = #entries == 0
	end
end

return SoloBoard

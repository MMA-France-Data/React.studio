-- Les deux PANNEAUX DE LA PLACE centrale (construits par HubMap, un de chaque côté, tournés vers le centre ; données :
-- LevelLeaderboard.luau). Demande du propriétaire (04/10/2026) : « rajoute les panneaux au centre avec les niveaux des
-- joueurs ». Recto verso : la face vers la place montre un tableau (« MEILLEURS JOUEURS » à l'est : tous les serveurs ;
-- « SUR CE SERVEUR » à l'ouest : les joueurs présents), le dos montre l'autre. Chaque ligne : place, nom du joueur, plus
-- haut niveau réussi, victoires (NumberFormat.short). Même famille que le tableau du camp : fond sombre, titre doré,
-- lignes arrondies. Les noms des joueurs ne sont jamais traduits (attribut NoTranslate, client/AutoTranslate.luau).
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local NumberFormat = require(Shared.NumberFormat)

local LevelBoard = {}

LevelBoard.ROWS = 10
LevelBoard.TITLES = { Top = "MEILLEURS JOUEURS", Server = "SUR CE SERVEUR" }
LevelBoard.FOOTERS = { Top = "Tous les serveurs · mis à jour chaque minute", Server = "Les joueurs présents en ce moment" }
LevelBoard.EMPTY = "Aucun joueur pour l'instant"

local GOLD = Color3.fromRGB(236, 192, 105)
local IVORY = Color3.fromRGB(238, 226, 197)
local MUTED = Color3.fromRGB(179, 190, 205)
local PODIUM = { Color3.fromRGB(255, 215, 90), Color3.fromRGB(214, 222, 232), Color3.fromRGB(222, 156, 98) } -- or, argent, bronze

-- Taille de l'écran d'une face, en pixels (panneau de 19 x 13 studs : 50 pixels par stud).
local WIDTH, HEIGHT = 950, 650
local ROW_TOP, ROW_HEIGHT = 150, 44

local faces = { Top = {}, Server = {} } -- [tableau] = faces qui l'affichent : { rows = { { frame, name, level, wins } }, empty }

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

-- Une face du panneau (Front = vers la place, Back = le dos) qui affiche le tableau `kind` ("Top" ou "Server").
local function buildFace(board: BasePart, face: Enum.NormalId, kind: string)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Board" .. kind .. face.Name -- ex. BoardTopFront
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(WIDTH, HEIGHT)
	gui.LightInfluence, gui.Brightness, gui.AlwaysOnTop, gui.MaxDistance = 0, 1, false, 185
	gui:SetAttribute("BoardKind", kind)
	gui.Parent = board
	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = Color3.fromRGB(20, 28, 39)
	background.BorderSizePixel = 0
	background.ZIndex = 1
	background.Parent = gui

	label(background, "Heading", "CLASSEMENT", 30, 14, WIDTH - 60, 50, 46, GOLD, Enum.Font.GothamBlack)
	label(background, "Kind", LevelBoard.TITLES[kind], 30, 66, WIDTH - 60, 40, 34, IVORY, Enum.Font.GothamBlack)
	label(background, "RankHeader", "#", 28, 114, 80, 28, 22, MUTED)
	label(background, "NameHeader", "JOUEUR", 120, 114, 410, 28, 22, MUTED, nil, Enum.TextXAlignment.Left)
	label(background, "LevelHeader", "NIVEAU", 540, 114, 170, 28, 22, MUTED)
	label(background, "WinsHeader", "VICTOIRES", 720, 114, 198, 28, 22, MUTED, nil, Enum.TextXAlignment.Right)

	local rows = {}
	for i = 1, LevelBoard.ROWS do
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
		label(frame, "Rank", "#" .. i, 8, 2, 80, ROW_HEIGHT - 9, 30, if i <= 3 then PODIUM[i] else MUTED, Enum.Font.GothamBlack)
		local name = label(frame, "PlayerName", "", 100, 2, 410, ROW_HEIGHT - 9, 30, IVORY, nil, Enum.TextXAlignment.Left)
		name:SetAttribute("NoTranslate", true) -- (un nom de joueur)
		rows[i] = {
			frame = frame,
			name = name,
			level = label(frame, "Level", "", 520, 2, 170, ROW_HEIGHT - 9, 30, GOLD, Enum.Font.GothamBlack),
			wins = label(frame, "Wins", "", 700, 2, 198, ROW_HEIGHT - 9, 28, IVORY, nil, Enum.TextXAlignment.Right),
		}
	end
	local empty = label(background, "Empty", LevelBoard.EMPTY, 30, ROW_TOP + 10, WIDTH - 60, 40, 30, MUTED)
	label(background, "Footer", LevelBoard.FOOTERS[kind], 30, HEIGHT - 50, WIDTH - 60, 32, 24, MUTED)
	table.insert(faces[kind], { rows = rows, empty = empty })
end

-- Habille un panneau : face vers la place = tableau `front` ("Top" ou "Server"), dos = l'autre.
function LevelBoard.attach(board: BasePart, front: string)
	buildFace(board, Enum.NormalId.Front, front)
	buildFace(board, Enum.NormalId.Back, if front == "Top" then "Server" else "Top")
end

-- Affiche un tableau sur toutes ses faces. entries = { { name, best, wins } } du meilleur au moins bon
-- (LevelLeaderboard).
function LevelBoard.show(kind: string, entries)
	for _, face in faces[kind] or {} do
		for i, row in face.rows do
			local entry = entries[i]
			row.frame.Visible = entry ~= nil
			row.name.Text = if entry then tostring(entry.name) else ""
			row.level.Text = if entry then tostring(math.floor(tonumber(entry.best) or 0)) else ""
			row.wins.Text = if entry then NumberFormat.short(tonumber(entry.wins) or 0) else ""
		end
		face.empty.Visible = #entries == 0
	end
end

return LevelBoard

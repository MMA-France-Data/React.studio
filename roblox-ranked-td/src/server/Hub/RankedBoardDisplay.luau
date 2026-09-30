-- Habillage et seconde face du classement existant. La source et la récupération des scores restent dans Hub/init.
-- Classé fermé (Config.RANKED_OPEN = false, Shared/RankedGate.luau) : les plaques disent « BIENTÔT DISPONIBLE » (et le
-- tableau aussi : Hub/init.luau, textes « RankedSoon... » recopiés au dos comme les lignes).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RankedGate = require(ReplicatedStorage:WaitForChild("Shared").RankedGate)

local RankedBoardDisplay = {}
local GOLD = Color3.fromRGB(236, 192, 105)
local MUTED = Color3.fromRGB(179, 190, 205)
local JOIN_HINT = "Rejoins le sceau\nau centre de la cour"

function RankedBoardDisplay.attach(board: BasePart)
	local alive = true
	local connections = {}
	local function mirror(source)
		if not source:IsA("SurfaceGui") or source:GetAttribute("RankedDisplayStyled") then return end
		task.defer(function()
			if not alive or source.Parent ~= board or source:GetAttribute("RankedDisplayStyled") then return end
			source:SetAttribute("RankedDisplayStyled", true)
			source.Name = "RankedLeaderboardBack"
			source.LightInfluence, source.Brightness, source.AlwaysOnTop, source.MaxDistance = 0, 1, false, 185
			local background = Instance.new("Frame")
			background.Name = "LeaderboardBackground"
			background.Size, background.BackgroundColor3, background.BorderSizePixel = UDim2.fromScale(1, 1), Color3.fromRGB(20, 28, 39), 0
			background.ZIndex, background.Parent = 1, source
			local rows = 0
			for _, child in source:GetChildren() do
				if not child:IsA("TextLabel") then continue end
				child.ZIndex = 2
				if child:GetAttribute("KeepStyle") then
					continue -- (« BIENTÔT DISPONIBLE » : déjà habillé par Hub/init.luau, recopié au dos plus bas)
				elseif string.find(child.Text, "CLASSEMENT", 1, true) then
					child.Name = "RankedHeading"
					child.TextColor3 = GOLD
				else
					rows += 1
					child.Name = "RankedRow" .. rows
					child.BackgroundColor3 = Color3.fromRGB(39, 49, 64)
					child.BackgroundTransparency = if rows % 2 == 0 then 0.45 else 0.12
					local corner = Instance.new("UICorner")
					corner.CornerRadius, corner.Parent = UDim.new(0, 8), child
				end
			end
			local reverse = source:Clone()
			reverse.Name, reverse.Face, reverse.Parent = "RankedLeaderboardFront", Enum.NormalId.Front, board
			for _, child in source:GetChildren() do
				if not child:IsA("TextLabel") then continue end
				local copy = reverse:FindFirstChild(child.Name)
				if copy then
					for _, property in { "Text", "TextColor3", "TextTransparency", "Visible" } do
						table.insert(connections, child:GetPropertyChangedSignal(property):Connect(function()
							if alive and copy.Parent then copy[property] = child[property] end
						end))
					end
				end
			end
			table.insert(connections, source.Destroying:Connect(function() reverse:Destroy() end))
		end)
	end
	table.insert(connections, board.ChildAdded:Connect(mirror))
	for _, child in board:GetChildren() do mirror(child) end
	board.Destroying:Once(function()
		alive = false
		for _, connection in connections do connection:Disconnect() end
	end)
end

function RankedBoardDisplay.sidePlaque(board: BasePart)
	local hints = {} -- dernière ligne de chaque face : « Rejoins le sceau… », ou « BIENTÔT DISPONIBLE » (classé fermé)
	for _, normal in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Name, gui.Face = "RankedMarker" .. normal.Name, normal
		gui.SizingMode, gui.CanvasSize = Enum.SurfaceGuiSizingMode.FixedSize, Vector2.new(360, 540)
		gui.LightInfluence, gui.Brightness, gui.AlwaysOnTop, gui.MaxDistance, gui.Parent = 0, 1, false, 140, board
		local background = Instance.new("Frame")
		background.Size, background.BackgroundColor3, background.BorderSizePixel, background.Parent = UDim2.fromScale(1, 1), Color3.fromRGB(20, 28, 39), 0, gui
		for _, info in {
			{ "I  ×  I", 38, 90, 62, GOLD }, { "RANKED", 160, 75, 48, GOLD },
			{ "DUEL ÉQUITABLE", 256, 50, 23, MUTED }, { JOIN_HINT, 350, 110, 26, Color3.fromRGB(245, 241, 230) },
		} do
			local text = Instance.new("TextLabel")
			text.Position, text.Size = UDim2.fromOffset(16, info[2]), UDim2.fromOffset(328, info[3])
			text.BackgroundTransparency, text.Font, text.TextColor3 = 1, Enum.Font.GothamBlack, info[5]
			text.Text, text.TextSize, text.TextWrapped, text.Parent = info[1], info[4], true, background
			if info[1] == JOIN_HINT then
				text.Name = "RankedMarkerHint"
				table.insert(hints, text)
			end
		end
	end
	local function refresh()
		for _, hint in hints do
			hint.Text = if RankedGate.isOpen() then JOIN_HINT else RankedGate.SOON_TITLE
			hint.TextColor3 = if RankedGate.isOpen() then Color3.fromRGB(245, 241, 230) else GOLD
		end
	end
	refresh()
	RankedGate.onChanged(refresh) -- (Studio seulement : le classé ne change jamais pendant une partie publiée)
end

return RankedBoardDisplay

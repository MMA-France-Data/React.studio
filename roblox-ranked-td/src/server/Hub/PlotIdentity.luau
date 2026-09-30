-- Panneau d'entrée en lecture seule : identité et vignette, jamais de sauvegarde ni d'attribution.
local Players = game:GetService("Players")
local PlotIdentity = {}
local GOLD = Color3.fromRGB(236, 192, 105)
local IVORY = Color3.fromRGB(245, 241, 230)
local MUTED = Color3.fromRGB(179, 190, 205)
local cache = {}

local function label(parent, name, position, size, fontSize, color)
	local text = Instance.new("TextLabel")
	text.Name, text.Position, text.Size = name, position, size
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextColor3, text.TextScaled, text.TextSize = color, true, fontSize
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.RichText = false
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize, limit.MinTextSize = fontSize, 16
	limit.Parent, text.Parent = text, parent
	return text
end

local function face(board, normal, index, accent)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "OwnerPlaque" .. normal.Name
	gui.Face, gui.SizingMode = normal, Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(1080, 420)
	gui.LightInfluence, gui.Brightness, gui.AlwaysOnTop, gui.MaxDistance = 0, 1, false, 160
	gui.Parent = board
	local panel = Instance.new("Frame")
	panel.Size, panel.BackgroundColor3, panel.BorderSizePixel = UDim2.fromScale(1, 1), Color3.fromRGB(20, 28, 39), 0
	panel.Parent = gui
	local stripe = Instance.new("Frame")
	stripe.Size, stripe.BackgroundColor3, stripe.BorderSizePixel = UDim2.new(1, 0, 0, 8), accent, 0
	stripe.Parent = panel
	local avatar = Instance.new("ImageLabel")
	avatar.Name = "Avatar"
	avatar.Position, avatar.Size = UDim2.fromOffset(36, 54), UDim2.fromOffset(310, 310)
	avatar.BackgroundColor3 = Color3.fromRGB(39, 49, 64)
	avatar.BorderSizePixel, avatar.Image, avatar.ScaleType = 0, "", Enum.ScaleType.Fit
	avatar.Parent = panel
	local corner = Instance.new("UICorner")
	corner.CornerRadius, corner.Parent = UDim.new(1, 0), avatar
	local rim = Instance.new("UIStroke")
	rim.Color, rim.Thickness, rim.Transparency, rim.Parent = GOLD, 3, 0.3, avatar
	local fallback = label(avatar, "Initial", UDim2.fromScale(0.1, 0.1), UDim2.fromScale(0.8, 0.8), 110, GOLD)
	fallback.TextXAlignment = Enum.TextXAlignment.Center
	fallback.Text = "?"
	local heading = label(panel, "Heading", UDim2.fromOffset(392, 44), UDim2.fromOffset(642, 50), 30, GOLD)
	heading.Text = string.format("FIEF %02d  /  DOMAINE", index)
	local owner = label(panel, "Owner", UDim2.fromOffset(392, 104), UDim2.fromOffset(642, 128), 76, IVORY)
	owner.Font = Enum.Font.GothamBlack
	local username = label(panel, "Username", UDim2.fromOffset(392, 234), UDim2.fromOffset(642, 50), 30, MUTED)
	local status = label(panel, "Status", UDim2.fromOffset(392, 313), UDim2.fromOffset(642, 50), 26, accent:Lerp(IVORY, 0.65))
	return { owner = owner, username = username, status = status, avatar = avatar, fallback = fallback }
end

function PlotIdentity.attach(plot: Folder, board: BasePart, index: number, accent: Color3): TextLabel
	local faces = { face(board, Enum.NormalId.Front, index, accent), face(board, Enum.NormalId.Back, index, accent) }
	-- Interface ownerLabel de Plots conservée sans modifier le module d'attribution.
	local bridge = Instance.new("TextLabel")
	bridge.Name, bridge.Visible, bridge.Text, bridge.Parent = "OwnerLabelBridge", false, "Parcelle libre", board
	local alive, revision, boundId = true, 0, nil
	local nameConnection = nil
	local connections = {}
	local function render(player)
		for _, item in faces do
			item.owner.Text = if player then player.DisplayName else "Fief libre"
			item.username.Text = if player then "@" .. player.Name else "Un domaine prêt à accueillir son seigneur"
			item.status.Text = if player then "DÉFENDS TON ROYAUME" else "PARCELLE DISPONIBLE"
			item.avatar.Image = if player then cache[player.UserId] or "" else ""
			item.fallback.Visible = item.avatar.Image == ""
			item.fallback.Text = if player and player.DisplayName ~= "" then utf8.char(utf8.codepoint(player.DisplayName, 1)) else "?"
		end
	end
	local function refresh()
		if not alive then return end
		local id = plot:GetAttribute("OwnerUserId")
		local player = if typeof(id) == "number" then Players:GetPlayerByUserId(id) else nil
		render(player)
		if id == boundId then return end
		boundId = id
		revision += 1
		if nameConnection then nameConnection:Disconnect(); nameConnection = nil end
		if not player then return end
		nameConnection = player:GetPropertyChangedSignal("DisplayName"):Connect(function() render(player) end)
		if cache[id] then return end
		local token = revision
		task.spawn(function()
			for attempt = 1, 3 do
				if not alive or revision ~= token then return end
				local ok, image, ready = pcall(function()
					return Players:GetUserThumbnailAsync(id, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
				end)
				if not alive or revision ~= token then return end
				if ok and ready and typeof(image) == "string" and image ~= "" then
					cache[id] = image
					render(player)
					return
				end
				if attempt < 3 then task.wait(attempt) end
			end
		end)
	end
	table.insert(connections, plot:GetAttributeChangedSignal("OwnerUserId"):Connect(refresh))
	table.insert(connections, bridge:GetPropertyChangedSignal("Text"):Connect(refresh))
	table.insert(connections, Players.PlayerAdded:Connect(function(player)
		if player.UserId == plot:GetAttribute("OwnerUserId") then boundId = nil; refresh() end
	end))
	board.Destroying:Once(function()
		alive = false
		revision += 1
		if nameConnection then nameConnection:Disconnect() end
		for _, connection in connections do connection:Disconnect() end
	end)
	refresh()
	return bridge
end

return PlotIdentity

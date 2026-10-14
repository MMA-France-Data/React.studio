-- LE VRAI SCANNER (sa demande, 14/10 : « je veux un vrai scanner, scanner les billets »).
--   Le joueur qui entre dans la cabine du guichet a le scanner en main (il disparaît quand il en sort). Le premier
--   visiteur de la file tend son billet à la fenêtre : on le vise et on clique (ou on le touche sur téléphone) ; l'écran
--   tire le laser rouge et fait « bip » (Main.client.luau), le serveur vérifie et fait passer le visiteur
--   (Visitors.scan). Le caissier, lui, scanne tout seul.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Map = require(script.Parent.Map)
local Props = require(script.Parent.Props)
local Zoo = require(script.Parent.Zoo)

local Scanner = {}

local M = Enum.Material
local rgb = Props.rgb
local v3 = Vector3.new
local GATE = Config.GATE

-- Appelé quand un joueur a scanné le billet (Visitors.luau le remplit).
Scanner.onScan = nil :: ((Player) -> boolean)?

-- LE BILLET tendu à la fenêtre de la cabine.
local ticket: Part
local function makeTicket()
	ticket = Props.part(Map.folder, "Ticket", v3(0.12, 0.8, 1.3), CFrame.new(GATE.booth + v3(4.7, 4.6, 1.6)) * CFrame.Angles(0, 0, math.rad(-12)), rgb(250, 248, 240), M.SmoothPlastic)
	ticket.CanQuery = true
	ticket.CastShadow = false
	for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 60
		gui.Parent = ticket
		local stripe = Instance.new("Frame")
		stripe.Size = UDim2.fromScale(1, 0.32)
		stripe.BackgroundColor3 = rgb(230, 130, 40)
		stripe.BorderSizePixel = 0
		stripe.Parent = gui
		local title = Instance.new("TextLabel")
		title.Size = UDim2.fromScale(1, 0.32)
		title.BackgroundTransparency = 1
		title.Text = "BILLET"
		title.Font = Enum.Font.FredokaOne
		title.TextScaled = true
		title.TextColor3 = Color3.new(1, 1, 1)
		title.Parent = gui
		local bars = Instance.new("TextLabel")
		bars.Size = UDim2.fromScale(0.9, 0.5)
		bars.Position = UDim2.fromScale(0.05, 0.42)
		bars.BackgroundTransparency = 1
		bars.Text = "▌▍▌▎▌▌▍▎▌▍"
		bars.Font = Enum.Font.Code
		bars.TextScaled = true
		bars.TextColor3 = rgb(20, 20, 20)
		bars.Parent = gui
	end
	local glow = Instance.new("Highlight")
	glow.FillTransparency = 1
	glow.OutlineColor = rgb(255, 220, 90)
	glow.DepthMode = Enum.HighlightDepthMode.Occluded
	glow.Parent = ticket
	ticket.Transparency = 1
	glow.Enabled = false
end

-- Le billet apparaît quand le premier visiteur est à la fenêtre, et disparaît une fois scanné.
function Scanner.showTicket(visible: boolean)
	if not ticket then
		return
	end
	ticket.Transparency = if visible then 0 else 1
	ticket.CanQuery = visible
	for _, item in ticket:GetChildren() do
		if item:IsA("SurfaceGui") or item:IsA("Highlight") then
			item.Enabled = visible
		end
	end
end

-- LE SCANNER (un outil tenu en main).
local template: Tool
local function makeTool()
	local tool = Instance.new("Tool")
	tool.Name = "Scanner"
	tool.ToolTip = "Scanner : vise le billet et clique"
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	-- (La poignée dans la main ; le corps du scanner vers l'avant ; la fenêtre rouge au bout.)
	-- La poignée (Handle) est tenue verticale dans la main ; le corps part vers l'avant, la fenêtre rouge au bout.
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = v3(0.3, 0.8, 0.35)
	handle.Color = rgb(40, 42, 46)
	handle.Material = M.SmoothPlastic
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	local function piece(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material): Part
		local item = Instance.new("Part")
		item.Name = name
		item.Size = size
		item.Color = color
		item.Material = material
		item.CanCollide, item.CanQuery, item.CanTouch, item.Massless = false, false, false, true
		item.CFrame = handle.CFrame * offset
		item.Parent = tool
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = item
		weld.Parent = item
		return item
	end
	piece("Body", v3(0.42, 0.36, 0.95), CFrame.new(0, 0.5, -0.3), rgb(240, 180, 40), M.SmoothPlastic)
	local window = piece("Window", v3(0.34, 0.26, 0.05), CFrame.new(0, 0.5, -0.79), rgb(255, 40, 40), M.Neon)
	local tip = Instance.new("Attachment")
	tip.Name = "Tip"
	tip.Position = v3(0, 0, -0.04)
	tip.Parent = window
	tool.Grip = CFrame.new(0, 0, 0)
	return tool
end

local function inBooth(player: Player): boolean
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local offset = root.Position - GATE.booth
	return math.abs(offset.X) < 3.4 and math.abs(offset.Z) < 4.8 and offset.Y < 8
end

function Scanner.start()
	makeTicket()
	template = makeTool()
	local scan = Instance.new("RemoteEvent")
	scan.Name = "ScanTicket"
	scan.Parent = ReplicatedStorage:WaitForChild("Remotes")
	scan.OnServerEvent:Connect(function(player, target)
		if target ~= ticket or ticket.Transparency > 0.5 or not inBooth(player) then
			return
		end
		if Scanner.onScan then
			Scanner.onScan(player)
		end
	end)
	-- Le scanner en main dans la cabine, rangé dehors.
	task.spawn(function()
		while true do
			task.wait(0.25)
			for _, player in Players:GetPlayers() do
				local character = player.Character
				if character then
					local held = character:FindFirstChild("Scanner")
					local stored = player:FindFirstChild("Backpack") and player.Backpack:FindFirstChild("Scanner")
					if inBooth(player) then
						if not held and not stored then
							template:Clone().Parent = character
						elseif stored and not held then
							stored.Parent = character
						end
					else
						if held then
							held:Destroy()
						end
						if stored then
							stored:Destroy()
						end
					end
				end
			end
		end
	end)
	_ = Zoo
end

return Scanner

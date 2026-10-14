-- LES PERSONNAGES DU ZOO (visiteurs et personnel) : des avatars Roblox (R15) avec leurs vêtements en couleur, qui
-- marchent avec les animations de Roblox. Ils ne se gênent pas entre eux ni avec les joueurs (groupe « Npc »), et le
-- personnel passe à travers les clôtures (groupe « Fence »).
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")

local Npc = {}

local folder = Instance.new("Folder")
folder.Name = "People"
folder.Parent = workspace
Npc.folder = folder

-- Les animations de Roblox (elles marchent dans tous les jeux).
local WALK = "rbxassetid://507777826"
local IDLE = "rbxassetid://507766666"

local SKINS = {
	Color3.fromRGB(255, 220, 190), Color3.fromRGB(234, 192, 158), Color3.fromRGB(198, 146, 108),
	Color3.fromRGB(150, 104, 76), Color3.fromRGB(104, 72, 54), Color3.fromRGB(250, 208, 170),
}
local SHIRTS = {
	Color3.fromRGB(230, 80, 70), Color3.fromRGB(70, 130, 210), Color3.fromRGB(250, 250, 245), Color3.fromRGB(250, 200, 60),
	Color3.fromRGB(90, 170, 100), Color3.fromRGB(200, 110, 190), Color3.fromRGB(40, 50, 70), Color3.fromRGB(255, 150, 80),
	Color3.fromRGB(120, 200, 220), Color3.fromRGB(160, 160, 166),
}
local PANTS = {
	Color3.fromRGB(50, 70, 110), Color3.fromRGB(40, 40, 46), Color3.fromRGB(180, 160, 120), Color3.fromRGB(90, 90, 96),
	Color3.fromRGB(110, 80, 60), Color3.fromRGB(60, 100, 160),
}
local HAIRS = { Color3.fromRGB(40, 30, 24), Color3.fromRGB(90, 60, 36), Color3.fromRGB(200, 160, 90), Color3.fromRGB(150, 70, 40), Color3.fromRGB(30, 30, 30) }

local template: Model? = nil
local random = Random.new()

function Npc.init()
	pcall(function()
		PhysicsService:RegisterCollisionGroup("Npc")
	end)
	pcall(function()
		PhysicsService:RegisterCollisionGroup("Fence")
	end)
	pcall(function()
		PhysicsService:RegisterCollisionGroup("Player")
	end)
	PhysicsService:CollisionGroupSetCollidable("Npc", "Npc", false)
	PhysicsService:CollisionGroupSetCollidable("Npc", "Fence", false)
	PhysicsService:CollisionGroupSetCollidable("Npc", "Player", false)
	local ok, result = pcall(function()
		local description = Instance.new("HumanoidDescription")
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if ok and result then
		template = result
		local colors = result:FindFirstChildOfClass("BodyColors")
		if colors then
			colors:Destroy()
		end
		for _, item in result:GetDescendants() do
			if item:IsA("Shirt") or item:IsA("Pants") or item:IsA("ShirtGraphic") or item:IsA("Accessory") then
				item:Destroy()
			end
		end
		local humanoid = result:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
			humanoid.BreakJointsOnDeath = false
			humanoid.RequiresNeck = false
		end
		local animate = result:FindFirstChild("Animate")
		if animate then
			animate:Destroy()
		end
	else
		warn("[ZOO] les personnages n'ont pas pu être créés : " .. tostring(result))
	end
end

local SKIN_PARTS = { "Head", "LeftHand", "RightHand", "LeftLowerArm", "RightLowerArm" }
local SHIRT_PARTS = { "UpperTorso", "LowerTorso", "LeftUpperArm", "RightUpperArm" }
local PANTS_PARTS = { "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg" }
local SHOE_PARTS = { "LeftFoot", "RightFoot" }

local function paint(model: Model, names: { string }, color: Color3)
	for _, name in names do
		local item = model:FindFirstChild(name)
		if item and item:IsA("BasePart") then
			item.Color = color
		end
	end
end

-- Un chapeau, une casquette ou des cheveux (de simples blocs soudés à la tête).
local function headwear(model: Model, kind: string, color: Color3)
	local head = model:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local item = Instance.new("Part")
	item.Name = "Headwear"
	item.CanCollide, item.CanQuery, item.CanTouch, item.Massless = false, false, false, true
	item.Color = color
	item.Material = Enum.Material.SmoothPlastic
	local offset = CFrame.new(0, head.Size.Y * 0.42, 0.05)
	if kind == "cap" then
		item.Size = Vector3.new(head.Size.X * 1.05, head.Size.Y * 0.3, head.Size.Z * 1.05)
		local visor = Instance.new("Part")
		visor.Name = "Visor"
		visor.CanCollide, visor.CanQuery, visor.CanTouch, visor.Massless = false, false, false, true
		visor.Color = color
		visor.Size = Vector3.new(head.Size.X * 0.9, 0.1, head.Size.Z * 0.6)
		visor.CFrame = head.CFrame * offset * CFrame.new(0, -head.Size.Y * 0.12, -head.Size.Z * 0.6)
		visor.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = head, visor
		weld.Parent = visor
	elseif kind == "hat" then
		item.Shape = Enum.PartType.Cylinder
		item.Size = Vector3.new(head.Size.Y * 0.12, head.Size.X * 1.8, head.Size.X * 1.8)
		offset *= CFrame.Angles(0, 0, math.rad(90))
		local crown = Instance.new("Part")
		crown.Name = "Crown"
		crown.Shape = Enum.PartType.Cylinder
		crown.CanCollide, crown.CanQuery, crown.CanTouch, crown.Massless = false, false, false, true
		crown.Color = color
		crown.Size = Vector3.new(head.Size.Y * 0.4, head.Size.X * 1.05, head.Size.X * 1.05)
		crown.CFrame = head.CFrame * CFrame.new(0, head.Size.Y * 0.62, 0) * CFrame.Angles(0, 0, math.rad(90))
		crown.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = head, crown
		weld.Parent = crown
	else
		item.Size = Vector3.new(head.Size.X * 1.08, head.Size.Y * 0.35, head.Size.Z * 1.08)
		offset = CFrame.new(0, head.Size.Y * 0.38, 0.08)
	end
	item.CFrame = head.CFrame * offset
	item.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = head, item
	weld.Parent = item
end

-- Un nouveau personnage. kind : « visitor », « kid » ou un rôle du personnel (uniforme du zoo).
function Npc.make(kind: string, position: Vector3, label: string?)
	if not template then
		return nil
	end
	local model = template:Clone()
	model.Name = kind
	local staff = kind ~= "visitor" and kind ~= "kid"
	paint(model, SKIN_PARTS, SKINS[random:NextInteger(1, #SKINS)])
	if staff then
		paint(model, SHIRT_PARTS, Color3.fromRGB(176, 160, 112))
		paint(model, PANTS_PARTS, Color3.fromRGB(70, 88, 60))
		paint(model, SHOE_PARTS, Color3.fromRGB(60, 44, 34))
	else
		paint(model, SHIRT_PARTS, SHIRTS[random:NextInteger(1, #SHIRTS)])
		paint(model, PANTS_PARTS, PANTS[random:NextInteger(1, #PANTS)])
		paint(model, SHOE_PARTS, if random:NextNumber() < 0.5 then Color3.fromRGB(240, 240, 240) else Color3.fromRGB(40, 40, 44))
	end
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			item.CollisionGroup = "Npc"
			item.CanQuery = false
			item.CanTouch = false
		end
	end
	if staff then
		headwear(model, "cap", Color3.fromRGB(70, 96, 64))
	else
		local roll = random:NextNumber()
		if roll < 0.25 then
			headwear(model, "cap", SHIRTS[random:NextInteger(1, #SHIRTS)])
		elseif roll < 0.4 then
			headwear(model, "hat", Color3.fromRGB(214, 190, 140))
		else
			headwear(model, "hair", HAIRS[random:NextInteger(1, #HAIRS)])
		end
	end
	if kind == "kid" then
		model:ScaleTo(0.68)
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	for _, state in { Enum.HumanoidStateType.Climbing, Enum.HumanoidStateType.Swimming, Enum.HumanoidStateType.FallingDown, Enum.HumanoidStateType.Ragdoll, Enum.HumanoidStateType.Seated, Enum.HumanoidStateType.Flying } do
		humanoid:SetStateEnabled(state, false)
	end
	model:PivotTo(CFrame.new(position + Vector3.new(0, 3.2, 0)))
	if label then
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(120, 24)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 3.4, 0)
		gui.MaxDistance = 60
		gui.Parent = model:FindFirstChild("Head")
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.FredokaOne
		text.TextScaled = true
		text.TextColor3 = Color3.fromRGB(255, 236, 170)
		text.TextStrokeTransparency = 0.3
		text.Text = label
		text.Parent = gui
	end
	model.Parent = folder
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	-- Les animations : marche quand il avance, repos sinon.
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	local walkAnimation = Instance.new("Animation")
	walkAnimation.AnimationId = WALK
	local idleAnimation = Instance.new("Animation")
	idleAnimation.AnimationId = IDLE
	local walk = animator:LoadAnimation(walkAnimation)
	local idle = animator:LoadAnimation(idleAnimation)
	walk.Looped, idle.Looped = true, true
	idle:Play()
	humanoid.Running:Connect(function(speed: number)
		if speed > 0.5 then
			if not walk.IsPlaying then
				walk:Play(0.2)
				idle:Stop(0.2)
			end
			walk:AdjustSpeed(speed / 12)
		elseif walk.IsPlaying then
			walk:Stop(0.25)
			idle:Play(0.25)
		end
	end)
	return { model = model, humanoid = humanoid, root = root }
end

-- Marche jusqu'à un point (en relançant l'ordre de Roblox, qui s'arrête au bout de 8 secondes). Renvoie true s'il y
-- est arrivé (à `near` près), false s'il est resté bloqué ou a disparu.
function Npc.walkTo(npc, target: Vector3, near: number?, timeout: number?): boolean
	local humanoid, root = npc.humanoid, npc.root
	local deadline = os.clock() + (timeout or 40)
	local close = near or 2
	local stuck, last = 0, root.Position
	while npc.model.Parent and os.clock() < deadline do
		local flat = Vector3.new(target.X - root.Position.X, 0, target.Z - root.Position.Z)
		if flat.Magnitude <= close then
			return true
		end
		humanoid:MoveTo(Vector3.new(target.X, root.Position.Y, target.Z))
		task.wait(0.4)
		if (root.Position - last).Magnitude < 0.2 then
			stuck += 1
			if stuck >= 8 then
				-- (Bloqué : on le pose un peu plus loin sur son chemin.)
				local step = flat.Unit * math.min(4, flat.Magnitude)
				root.CFrame = CFrame.new(root.Position + step + Vector3.new(0, 1, 0))
				stuck = 0
			end
		else
			stuck = 0
		end
		last = root.Position
	end
	return false
end

-- Tourne le personnage vers un point.
function Npc.face(npc, target: Vector3)
	local root = npc.root
	local flat = Vector3.new(target.X, root.Position.Y, target.Z)
	if (flat - root.Position).Magnitude > 0.1 then
		root.CFrame = CFrame.lookAt(root.Position, flat)
	end
end

return Npc

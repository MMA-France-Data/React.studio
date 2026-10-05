-- LA BOMBE : un parcours à grimper (le même que celui de la lave, mais le sol est sûr : si on tombe, on remonte).
-- Tout en haut, une bombe avec un gros compte à rebours. Chaque joueur doit monter couper SON fil (E maintenu).
-- À zéro, elle explose pour ceux qui n'ont pas coupé le leur : ils sont éliminés, les autres ont gagné.
-- Si tous les joueurs encore en vie ont coupé leur fil avant la fin, la porte s'ouvre tout de suite.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Build = require(script.Parent.Parent.Build)
local Lava = require(script.Parent.Lava)

local Bomb = {}

local REACH = 14 -- distance à la bombe pour pouvoir couper son fil
local EXPLOSION_SOUND = "rbxasset://sounds/impact_explosion_03.mp3"

function Bomb.new(ctx, params)
	local self = {}
	Lava.course(ctx, params)
	local top = ctx.room.finalTop
	local fuse = math.min(params.fuse or Config.DURATION, Config.DURATION - 1)
	local folder = ctx.room.folder

	-- La bombe : une boule noire, sa mèche, une lumière rouge qui clignote, et le compte à rebours au-dessus.
	local shell = Build.part(ctx.static, "Bomb", Vector3.new(4.4, 4.4, 4.4), top + Vector3.new(0, 2.4, 0), Color3.fromRGB(28, 28, 34))
	shell.Shape = Enum.PartType.Ball
	Build.part(ctx.static, "BombCap", Vector3.new(1.2, 0.8, 1.2), top + Vector3.new(0, 4.8, 0), Color3.fromRGB(120, 124, 134), Enum.Material.Metal)
	local spark = Build.part(ctx.static, "BombSpark", Vector3.new(0.7, 0.7, 0.7), top + Vector3.new(0, 5.6, 0), Color3.fromRGB(255, 60, 40), Enum.Material.Neon)
	spark.Shape = Enum.PartType.Ball
	spark.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 50, 40)
	light.Range = 18
	light.Parent = spark
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(14, 7)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 11, 0)
	gui.MaxDistance = 400
	gui.AlwaysOnTop = true
	gui.AutoLocalize = false
	gui.Enabled = false
	gui.Parent = shell
	local counter = Build.text(gui, "Counter", UDim2.fromScale(1, 0.62), UDim2.fromScale(0, 0), Color3.fromRGB(255, 80, 60))
	local wires = Build.text(gui, "Wires", UDim2.fromScale(1, 0.34), UDim2.fromScale(0, 0.64), Color3.fromRGB(255, 221, 51))
	local boom = Instance.new("Sound")
	boom.SoundId = EXPLOSION_SOUND
	boom.Volume = 1.5
	boom.RollOffMaxDistance = 300
	boom.Parent = shell

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Prompt"
	prompt.HoldDuration = params.hold or 3
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	prompt.AutoLocalize = false
	prompt.Enabled = false
	prompt:SetAttribute("Kind", "Bomb")
	prompt.Parent = shell

	local cut = {} -- [joueur] = true quand il a coupé son fil
	local running, exploded = false, false

	local function remaining(): number
		local count = 0
		for _, entry in ctx.players() do
			if not cut[entry.player] then
				count += 1
			end
		end
		return count
	end

	-- Le joueur coupe son fil (le bouton de la bombe). Renvoie true s'il a compté.
	function self.defuse(player: Player): boolean
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not running or exploded or cut[player] or not ctx.room.participants[player] or not root then
			return false
		end
		if (root.Position - shell.Position).Magnitude > REACH then
			return false
		end
		cut[player] = true
		-- Son écran éteint le bouton et lui dit qu'il est sauvé.
		player:SetAttribute("BombCut", ctx.room.index)
		ctx.notify(player, "wireCut")
		return true
	end
	prompt.Triggered:Connect(self.defuse)
	ctx.room.defuse = self.defuse

	function self.start()
		table.clear(cut)
		running, exploded = true, false
		for _, entry in ctx.players() do
			entry.player:SetAttribute("BombCut", 0)
		end
		prompt.Enabled = true
		gui.Enabled = true
		folder:SetAttribute("Fuse", fuse)
	end

	function self.update(_dt: number, elapsed: number)
		if exploded then
			return
		end
		local left = fuse - elapsed
		counter.Text = string.format("%d", math.max(0, math.ceil(left)))
		wires.Text = tostring(remaining())
		-- La lumière clignote de plus en plus vite.
		local rate = if left < 10 then 10 elseif left < 25 then 5 else 2.5
		local on = math.floor(elapsed * rate) % 2 == 0
		light.Brightness = if on then 3 else 0.3
		spark.Transparency = if on then 0 else 0.6
		if left <= 0 then
			exploded = true
			prompt.Enabled = false
			boom:Play()
			local explosion = Instance.new("Explosion")
			explosion.BlastPressure = 0
			explosion.DestroyJointRadiusPercent = 0
			explosion.BlastRadius = 30
			explosion.Position = shell.Position
			explosion.Parent = ctx.effects
			for _, entry in ctx.players() do
				if not cut[entry.player] then
					ctx.eliminate(entry.player)
				end
			end
		end
	end

	-- Gagné dès que tous les joueurs encore en vie ont coupé leur fil (ou, après l'explosion, pour ceux qui l'avaient
	-- coupé).
	function self.solved(): boolean
		if not running then
			return false
		end
		local safe = 0
		for _, entry in ctx.players() do
			if cut[entry.player] then
				safe += 1
			end
		end
		return safe > 0 and (exploded or remaining() == 0)
	end

	function self.stop()
		running = false
		prompt.Enabled = false
		gui.Enabled = false
		light.Brightness = 0.3
	end

	return self
end

return Bomb

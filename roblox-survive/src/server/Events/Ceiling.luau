-- LE PLAFOND TOMBE : toujours avec la lave. Les joueurs ont `at` secondes pour grimper le parcours ; ensuite le
-- plafond descend vers la dernière plateforme et écrase tout le monde s'il arrive en bas.
-- Pour le repousser, il faut être sur la dernière plateforme et appuyer très vite sur E (ou le bouton de l'écran).
-- Chaque appui le remonte un peu, d'autant plus que la force du joueur est haute. À plusieurs, tout s'additionne.
--
-- Réglage : avec la force `need` et 5 appuis par seconde, le plafond ne bouge plus. Sans personne, il écrase tout
-- en FALL secondes. Il faut à peu près les deux tiers de `need` (à 5 appuis par seconde) pour tenir jusqu'au bout.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Build = require(script.Parent.Parent.Build)

local Ceiling = {}

local ROOM, CRUSH = 28, 5.4 -- dessous du plafond au-dessus de la dernière plateforme : au départ, et quand il écrase
local FALL = 12 -- secondes pour tout écraser si personne ne pousse
local THICK = 3
local REACH = 9 -- distance (vue d'en haut) au milieu de la dernière plateforme pour pouvoir pousser
local PRESSES = 5 -- appuis par seconde qui arrêtent le plafond avec la force `need`
local MAX_PRESSES = 8 -- appuis par seconde comptés au plus (les clics automatiques ne servent à rien)

function Ceiling.new(ctx, params)
	local self = {}
	local platform = ctx.room.finalTop
	assert(platform, "le plafond a besoin de la lave dans la même salle (events = { \"Lava\", \"Ceiling\" })")
	local high, low = platform.Y + ROOM, platform.Y + CRUSH
	local speed = (high - low) / FALL

	local slab = Build.part(
		ctx.static,
		"Ceiling",
		Vector3.new(ctx.halfX * 2, THICK, ctx.halfZ * 2 - 1.6),
		ctx.center,
		Color3.fromRGB(58, 56, 70),
		Enum.Material.Slate
	)
	-- Dessous rouge qui brille : on le voit venir.
	local glow = Build.part(ctx.static, "CeilingGlow", Vector3.new(ctx.halfX * 2 - 6, 0.3, ctx.halfZ * 2 - 8), ctx.center, Color3.fromRGB(255, 60, 60), Enum.Material.Neon)
	glow.CanCollide = false
	glow.CanQuery = false
	glow.Transparency = 0.5

	-- L'endroit où pousser : un anneau jaune sur la dernière plateforme.
	local ring = Build.disc(ctx.static, "PushRing", 7, 0.2, platform + Vector3.new(0, 0.12, 0), Color3.fromRGB(255, 221, 51), Enum.Material.Neon)
	ring.CanCollide = false
	ring.CanQuery = false
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(12, 2.6)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 9, 0)
	gui.MaxDistance = 120
	gui.AutoLocalize = false
	gui.Parent = ring
	local label = Build.text(gui, "Label", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Color3.fromRGB(255, 221, 51))
	label:SetAttribute("T", "lift")
	label:AddTag("T")

	local bottom, active = high, false
	local lastPress = {}
	local folder = ctx.room.folder

	local function place(height: number)
		bottom = height
		slab.Position = Vector3.new(ctx.center.X, height + THICK / 2, ctx.center.Z)
		glow.Position = Vector3.new(ctx.center.X, height - 0.2, ctx.center.Z)
		folder:SetAttribute("Ceiling", math.floor((height - low) / (high - low) * 100) / 100)
	end
	place(high)
	ctx.topY = function()
		return bottom
	end

	function self.start()
		active = false
		table.clear(lastPress)
		place(high)
		folder:SetAttribute("Need", params.need)
		folder:SetAttribute("Pushing", false)
	end

	function self.update(dt: number, elapsed: number)
		if elapsed < params.at then
			return
		end
		if not active then
			active = true
			folder:SetAttribute("Pushing", true)
		end
		place(bottom - speed * dt)
		if bottom <= low then
			for _, entry in ctx.players() do
				ctx.kill(entry.player)
			end
		end
	end

	-- Un appui sur E. Renvoie true s'il a compté.
	function self.push(player: Player, elapsed: number, unlimited: boolean?): boolean
		if not active then
			return false
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then
			return false
		end
		local offset = root.Position - platform
		if Vector3.new(offset.X, 0, offset.Z).Magnitude > REACH or offset.Y < -1 then
			return false
		end
		if not unlimited then
			local last = lastPress[player]
			if last and elapsed - last < 1 / MAX_PRESSES then
				return false
			end
			lastPress[player] = elapsed
		end
		local force = Config.force(player:GetAttribute("Force") or 1)
		place(math.min(high, bottom + speed * force / (params.need * PRESSES)))
		return true
	end
	ctx.room.push = self.push

	function self.stop()
		active = false
		place(high)
		folder:SetAttribute("Need", 0)
		folder:SetAttribute("Pushing", false)
	end

	return self
end

return Ceiling

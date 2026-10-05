-- PLUIE DE MÉTÉORITES : un cercle rouge prévient, puis la météorite tombe dessus et explose. Une partie des
-- météorites vise un joueur, les autres tombent au hasard.
--
-- LA GRANDE PLUIE (params.rush) : toute la salle devient rouge sauf un rond vert, placé à l'autre bout de la salle
-- à chaque fois. Quand le compte à rebours du rond arrive à zéro, tout ce qui est hors du rond explose. Le temps
-- laissé est celui qu'il faut pour traverser en courant avec le niveau de vitesse demandé (Config.rushSeconds) :
-- sans ce niveau, on n'arrive pas à temps.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Build = require(script.Parent.Parent.Build)
local LibraryVisuals = require(script.Parent.Parent.LibraryVisuals)

local Meteors = {}

local RED = Color3.fromRGB(255, 40, 40)
local GREEN = Color3.fromRGB(70, 255, 90)
local SAFE_RADIUS = 6.5 -- rayon du rond vert
local SAFE_GRACE = 1 -- marge en plus au moment de l'impact (retard du réseau)
local FIRST_EXTRA = 2.5 -- secondes en plus pour la première grande pluie (les joueurs sont n'importe où)
-- Les deux places du rond vert, aux deux coins opposés de la salle (par rapport à son centre).
local CORNERS = { Vector3.new(-26, 0, -30), Vector3.new(26, 0, 30) }
local EXPLOSION_SOUND = "rbxasset://sounds/impact_explosion_03.mp3"

local function ghost(part: BasePart)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
end

function Meteors.new(ctx, params)
	local self = {}
	local random = Random.new()
	local active = {} -- { target, from, t, warn, ball, time, radius, harmless }
	local timer = 0

	local function randomSpot(margin: number): Vector3
		return Vector3.new(
			ctx.center.X + random:NextNumber(-ctx.halfX + margin, ctx.halfX - margin),
			0,
			ctx.center.Z + random:NextNumber(-ctx.halfZ + margin, ctx.halfZ - margin)
		)
	end

	-- Lance une météorite. harmless : seulement pour le spectacle (la grande pluie compte ses dégâts elle-même).
	local function launch(spot: Vector3?, time: number, radius: number, harmless: boolean?)
		local target = spot
		if not target then
			local players = ctx.players()
			if #players > 0 and random:NextNumber() < (params.aimed or 0.5) then
				local position = players[random:NextInteger(1, #players)].root.Position
				target = Vector3.new(position.X + random:NextNumber(-2.5, 2.5), 0, position.Z + random:NextNumber(-2.5, 2.5))
			else
				target = randomSpot(radius * 0.5)
			end
		end
		target = Vector3.new(target.X, ctx.surface(target.X, target.Z), target.Z)

		local warn
		if not harmless then
			warn = Build.disc(ctx.effects, "Warn", radius * 2, 0.25, target + Vector3.new(0, 0.2, 0), RED, Enum.Material.Neon)
			warn.Transparency = 0.45
			ghost(warn)
		end
		local from = Vector3.new(target.X + random:NextNumber(-10, 10), math.max(ctx.topY() - 3, target.Y + 6), target.Z)
		local ball = LibraryVisuals.meteor(ctx.effects, from)
		ghost(ball)
		local fire = Instance.new("Fire")
		fire.Size = 9
		fire.Heat = 0
		fire.Parent = ball
		table.insert(active, { target = target, from = from, t = 0, warn = warn, ball = ball, time = time, radius = radius, harmless = harmless })
	end

	local function impact(meteor)
		if meteor.warn then
			meteor.warn:Destroy()
		end
		meteor.ball:Destroy()
		local explosion = Instance.new("Explosion")
		explosion.BlastPressure = 0
		explosion.DestroyJointRadiusPercent = 0
		explosion.BlastRadius = meteor.radius
		explosion.Position = meteor.target
		explosion.Parent = ctx.effects
		Debris:AddItem(explosion, 2)
		if meteor.harmless then
			return
		end
		for _, entry in ctx.players() do
			local offset = entry.root.Position - meteor.target
			if Vector3.new(offset.X, 0, offset.Z).Magnitude <= meteor.radius and math.abs(offset.Y) < 14 then
				ctx.damage(entry.player, Config.DAMAGE.Meteor)
			end
		end
	end

	-- LA GRANDE PLUIE ---------------------------------------------------------------------------------------------
	local rush = params.rush
	local danger, safe, counter, boom
	local phase, rushTimer, side, waves, showered = "rest", 0, 1, 0, false
	local travel, rushTime = 0, 0
	if rush then
		-- Distance à courir : d'un rond à l'autre, moins les deux rayons (on part du bord, on s'arrête au bord).
		travel = (CORNERS[1] - CORNERS[2]).Magnitude - 2 * SAFE_RADIUS + 2
		rushTime = Config.rushSeconds(rush.level, travel)
		danger = Build.part(ctx.static, "Danger", Vector3.new(ctx.halfX * 2, 0.2, ctx.halfZ * 2 - 1.6), ctx.center + Vector3.new(0, 0.12, 0), RED, Enum.Material.Neon)
		danger.Transparency = 1
		ghost(danger)
		safe = Build.disc(ctx.static, "Safe", SAFE_RADIUS * 2, 0.3, ctx.center + CORNERS[1] + Vector3.new(0, 0.2, 0), GREEN, Enum.Material.Neon)
		safe.Transparency = 1
		ghost(safe)
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromScale(8, 5)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 9, 0)
		gui.MaxDistance = 200
		gui.AlwaysOnTop = true
		gui.AutoLocalize = false
		gui.Enabled = false
		gui.Parent = safe
		counter = Build.text(gui, "Label", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), GREEN)
		boom = Instance.new("Sound")
		boom.SoundId = EXPLOSION_SOUND
		boom.Volume = 1
		boom.RollOffMaxDistance = 250
		boom.Parent = danger
		ctx.room.folder:SetAttribute("Rush", rush.level)
	end

	local function publishRush()
		ctx.room.rush = { phase = phase, timer = rushTimer, target = ctx.center + CORNERS[side], waves = waves, seconds = rushTime }
	end
	local function hideRush()
		danger.Transparency = 1
		safe.Transparency = 1
		counter.Parent.Enabled = false
	end
	local function updateRush(dt: number, elapsed: number)
		rushTimer -= dt
		if phase == "rest" then
			-- Pas de nouvelle grande pluie si elle ne peut pas finir avant la fin de la manche.
			if rushTimer <= 0 and elapsed + rushTime + FIRST_EXTRA < Config.DURATION then
				side = if waves == 0 then 1 else 3 - side
				phase = "warn"
				rushTimer = rushTime + if waves == 0 then FIRST_EXTRA else 0
				showered = false
				safe.Position = ctx.center + CORNERS[side] + Vector3.new(0, 0.2, 0)
				safe.Transparency = 0.1
				counter.Parent.Enabled = true
			end
		else
			danger.Transparency = 0.75 - 0.25 * math.abs(math.sin(rushTimer * 5))
			counter.Text = string.format("%.1f", math.max(0, rushTimer))
			-- Le spectacle : les météorites partent pour arriver toutes en même temps que le compte à rebours.
			if not showered and rushTimer <= 0.9 then
				showered = true
				for _ = 1, 14 do
					local spot = randomSpot(4)
					if (Vector3.new(spot.X, 0, spot.Z) - Vector3.new(safe.Position.X, 0, safe.Position.Z)).Magnitude > SAFE_RADIUS + 5 then
						launch(spot, math.max(0.2, rushTimer), 9, true)
					end
				end
			end
			if rushTimer <= 0 then
				boom:Play()
				for _, entry in ctx.players() do
					local offset = entry.root.Position - safe.Position
					if Vector3.new(offset.X, 0, offset.Z).Magnitude > SAFE_RADIUS + SAFE_GRACE then
						ctx.damage(entry.player, Config.DAMAGE.Rush)
					end
				end
				waves += 1
				phase = "rest"
				rushTimer = rush.rest or 3
				hideRush()
			end
		end
		publishRush()
	end

	function self.start()
		timer = (params.every or 0) * 0.5
		if rush then
			phase, rushTimer, side, waves = "rest", 3, 1, 0
			hideRush()
			publishRush()
		end
	end

	function self.update(dt: number, elapsed: number)
		if params.every then
			timer -= dt
			if timer <= 0 then
				timer += params.every
				for _ = 1, params.count do
					launch(nil, params.warn, params.radius)
				end
			end
		end
		if rush then
			updateRush(dt, elapsed)
		end
		for i = #active, 1, -1 do
			local meteor = active[i]
			meteor.t += dt
			local alpha = math.min(1, meteor.t / meteor.time)
			meteor.ball.Position = meteor.from:Lerp(meteor.target, alpha * alpha)
			if meteor.warn then
				meteor.warn.Transparency = 0.55 - 0.35 * alpha
			end
			if alpha >= 1 then
				table.remove(active, i)
				impact(meteor)
			end
		end
	end

	function self.stop()
		for _, meteor in active do
			if meteor.warn then
				meteor.warn:Destroy()
			end
			meteor.ball:Destroy()
		end
		table.clear(active)
		if rush then
			phase = "rest"
			hideRush()
		end
	end

	return self
end

return Meteors

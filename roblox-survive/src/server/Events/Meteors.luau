-- PLUIE DE MÉTÉORITES : un cercle rouge prévient, puis la météorite tombe dessus et explose. Une partie des
-- météorites vise un joueur, les autres tombent au hasard.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Build = require(script.Parent.Parent.Build)
local LibraryVisuals = require(script.Parent.Parent.LibraryVisuals)

local Meteors = {}

local RED = Color3.fromRGB(255, 40, 40)

local function ghost(part: BasePart)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
end

function Meteors.new(ctx, params)
	local self = {}
	local random = Random.new()
	local active = {} -- { target, from, t, warn, ball }
	local timer = 0

	local function launch()
		local target
		local players = ctx.players()
		if #players > 0 and random:NextNumber() < (params.aimed or 0.5) then
			local position = players[random:NextInteger(1, #players)].root.Position
			target = Vector3.new(position.X + random:NextNumber(-2.5, 2.5), 0, position.Z + random:NextNumber(-2.5, 2.5))
		else
			local margin = params.radius * 0.5
			target = Vector3.new(
				ctx.center.X + random:NextNumber(-ctx.halfX + margin, ctx.halfX - margin),
				0,
				ctx.center.Z + random:NextNumber(-ctx.halfZ + margin, ctx.halfZ - margin)
			)
		end
		target = Vector3.new(target.X, ctx.surface(target.X, target.Z), target.Z)

		local warn = Build.disc(ctx.effects, "Warn", params.radius * 2, 0.25, target + Vector3.new(0, 0.2, 0), RED, Enum.Material.Neon)
		warn.Transparency = 0.45
		ghost(warn)
		local from = Vector3.new(target.X + random:NextNumber(-10, 10), math.max(ctx.topY() - 3, target.Y + 6), target.Z)
		local ball = LibraryVisuals.meteor(ctx.effects, from)
		ghost(ball)
		local fire = Instance.new("Fire")
		fire.Size = 9
		fire.Heat = 0
		fire.Parent = ball
		table.insert(active, { target = target, from = from, t = 0, warn = warn, ball = ball })
	end

	local function impact(meteor)
		meteor.warn:Destroy()
		meteor.ball:Destroy()
		local explosion = Instance.new("Explosion")
		explosion.BlastPressure = 0
		explosion.DestroyJointRadiusPercent = 0
		explosion.BlastRadius = params.radius
		explosion.Position = meteor.target
		explosion.Parent = ctx.effects
		Debris:AddItem(explosion, 2)
		for _, entry in ctx.players() do
			local offset = entry.root.Position - meteor.target
			if Vector3.new(offset.X, 0, offset.Z).Magnitude <= params.radius and math.abs(offset.Y) < 14 then
				ctx.damage(entry.player, Config.DAMAGE.Meteor)
			end
		end
	end

	function self.start()
		timer = params.every * 0.5
	end

	function self.update(dt: number, _elapsed: number)
		timer -= dt
		if timer <= 0 then
			timer += params.every
			for _ = 1, params.count do
				launch()
			end
		end
		for i = #active, 1, -1 do
			local meteor = active[i]
			meteor.t += dt
			local alpha = math.min(1, meteor.t / params.warn)
			meteor.ball.Position = meteor.from:Lerp(meteor.target, alpha * alpha)
			meteor.warn.Transparency = 0.55 - 0.35 * alpha
			if alpha >= 1 then
				table.remove(active, i)
				impact(meteor)
			end
		end
	end

	function self.stop()
		for _, meteor in active do
			meteor.warn:Destroy()
			meteor.ball:Destroy()
		end
		table.clear(active)
	end

	return self
end

return Meteors

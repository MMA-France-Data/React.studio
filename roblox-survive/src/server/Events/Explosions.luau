-- EXPLOSIONS : le sol est fait de 16 grandes dalles. À chaque vague, presque toutes clignotent en rouge puis
-- explosent : il faut courir sur une dalle restée calme.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Build = require(script.Parent.Parent.Build)
local Themes = require(script.Parent.Parent.Themes)

local Explosions = {}

local GRID = 4
local RED = Color3.fromRGB(255, 45, 45)
local FLASH = Color3.fromRGB(255, 230, 120)

function Explosions.new(ctx, params)
	local self = {}
	local random = Random.new()
	local sizeX, sizeZ = ctx.halfX * 2 / GRID, (ctx.halfZ * 2 - 1.6) / GRID
	local theme = Themes.of(ctx.room.index)
	local tiles = {}
	for ix = 1, GRID do
		for iz = 1, GRID do
			local position = ctx.center + Vector3.new(-ctx.halfX + (ix - 0.5) * sizeX, 0.15, -(sizeZ * GRID) / 2 + (iz - 0.5) * sizeZ)
			local color = if (ix + iz) % 2 == 0 then theme.floor[2]:Lerp(Color3.new(1, 1, 1), 0.18) else theme.floor[3]:Lerp(Color3.new(1, 1, 1), 0.3)
			local part = Build.part(ctx.static, "Tile", Vector3.new(sizeX - 0.4, 0.3, sizeZ - 0.4), position, color, theme.floor[1])
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			table.insert(tiles, { part = part, color = color, armed = false })
		end
	end
	ctx.room.tiles = tiles

	local timer, fuse, flash = 0, -1, 0

	local function reset()
		for _, tile in tiles do
			tile.armed = false
			tile.part.Color = tile.color
			tile.part.Material = theme.floor[1]
		end
	end

	local function arm()
		local order = table.clone(tiles)
		random:Shuffle(order)
		for i, tile in order do
			tile.armed = i > params.safe
		end
		fuse = params.warn
	end

	local function explode()
		for _, tile in tiles do
			if tile.armed then
				tile.part.Color = FLASH
				tile.part.Material = Enum.Material.Neon
				local explosion = Instance.new("Explosion")
				explosion.BlastPressure = 0
				explosion.DestroyJointRadiusPercent = 0
				explosion.BlastRadius = 8
				explosion.Position = tile.part.Position + Vector3.new(0, 2, 0)
				explosion.Parent = ctx.effects
				Debris:AddItem(explosion, 2)
			end
		end
		for _, entry in ctx.players() do
			local position = entry.root.Position
			if position.Y - 3 < 8 then
				for _, tile in tiles do
					local offset = position - tile.part.Position
					if tile.armed and math.abs(offset.X) <= sizeX / 2 and math.abs(offset.Z) <= sizeZ / 2 then
						ctx.damage(entry.player, Config.DAMAGE.Explosion)
						break
					end
				end
			end
		end
		flash = 0.35
	end

	function self.start()
		timer, fuse, flash = 2, -1, 0
		reset()
	end

	function self.update(dt: number, elapsed: number)
		if flash > 0 then
			flash -= dt
			if flash <= 0 then
				reset()
			end
		end
		if fuse > 0 then
			fuse -= dt
			-- Clignote de plus en plus vite.
			local on = math.floor((params.warn - fuse) * (3 + 5 * (1 - fuse / params.warn))) % 2 == 0
			for _, tile in tiles do
				if tile.armed then
					tile.part.Color = if on then RED else tile.color
					tile.part.Material = if on then Enum.Material.Neon else theme.floor[1]
				end
			end
			if fuse <= 0 then
				explode()
			end
			return
		end
		timer -= dt
		if timer <= 0 and flash <= 0 and elapsed < Config.DURATION - params.warn then
			timer = params.every - params.warn
			arm()
		end
	end

	function self.stop()
		fuse, flash = -1, 0
		reset()
	end

	return self
end

return Explosions

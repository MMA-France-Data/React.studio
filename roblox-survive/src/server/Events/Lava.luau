-- LA LAVE MONTE : un parcours qui grimpe en spirale le long des murs puis vers le centre. La lave monte jusque
-- sous la dernière plateforme (verte) : à la fin, c'est le seul endroit sûr.
--
-- Le parcours est fait de morceaux tirés au sort (toujours les mêmes pour une salle donnée) :
--   pad   : plateforme carrée, monte un peu
--   beam  : poutre étroite, à plat
--   steps : trois petites marches
--   big   : la GRANDE MARCHE, une par ligne droite. Sa hauteur dépend du niveau de saut demandé par la salle
--           (Config.stepHeight) : c'est elle qui oblige à améliorer le trampoline.
-- À chaque coin de la spirale, une plateforme de repos.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Build = require(script.Parent.Parent.Build)

local Lava = {}

-- Coins de la spirale (x, z) par rapport au centre de la salle. L'entrée de la salle est du côté z négatif.
local SPIRAL = {
	Vector3.new(-28, 0, -32),
	Vector3.new(28, 0, -32),
	Vector3.new(28, 0, 32),
	Vector3.new(-28, 0, 32),
	Vector3.new(-28, 0, -21),
	Vector3.new(17, 0, -21),
	Vector3.new(17, 0, 21),
	Vector3.new(-17, 0, 21),
	Vector3.new(-17, 0, -10),
}
Lava.MAX_SEGMENTS = #SPIRAL - 1

local CORNER, FINAL = 9, 12 -- côté d'une plateforme de coin, et de la dernière
local THICK = 1.2
local MAX_GAP = 5.5
local BIG_GAP = 3.5 -- le saut devant une grande marche est plus court
local START = 5 -- la lave commence à monter après ce temps
local TICK = 0.4

-- longueur, largeur, montée (en parts de la grande marche)
local KINDS = {
	pad = { length = 7, width = 7, rise = 0.25 },
	beam = { length = 13, width = 2.2, rise = 0 },
	steps = { length = 17, width = 4.5, rise = 0.3 },
	big = { length = 9, width = 9, rise = 1 },
}
local EXTRA = { "pad", "beam", "steps", "pad", "beam" }
local COLORS = {
	pad = { Color3.fromRGB(255, 170, 40), Color3.fromRGB(60, 200, 255), Color3.fromRGB(255, 110, 190), Color3.fromRGB(255, 225, 60) },
	beam = { Color3.fromRGB(245, 245, 250) },
	steps = { Color3.fromRGB(120, 230, 120), Color3.fromRGB(90, 210, 220) },
	big = { Color3.fromRGB(170, 100, 255) },
}

-- Calcule le parcours d'une salle sans rien construire : la liste des blocs et la hauteur du sommet.
-- (World s'en sert pour la hauteur des murs.)
function Lava.plan(index: number, params)
	local random = Random.new(1000 + index)
	local step = Config.stepHeight(params.jump)
	local blocks = {} -- { kind, center (x, dessus, z), size }
	local height = 0.6 * step -- première plateforme : on y monte depuis le sol

	local function add(kind: string, center: Vector3, along: Vector3, length: number, width: number)
		local size = if math.abs(along.X) > 0.5 then Vector3.new(length, THICK, width) else Vector3.new(width, THICK, length)
		table.insert(blocks, { kind = kind, top = Vector3.new(center.X, height, center.Z), size = size })
	end

	local segments = math.clamp(params.segments, 1, Lava.MAX_SEGMENTS)
	add("corner", SPIRAL[1], Vector3.xAxis, CORNER, CORNER)
	for s = 1, segments do
		local from, to = SPIRAL[s], SPIRAL[s + 1]
		local along = (to - from).Unit
		local last = s == segments
		local endHalf = if last then FINAL / 2 else CORNER / 2
		local usable = (to - from).Magnitude - CORNER / 2 - endHalf

		-- Les morceaux de cette ligne droite : une grande marche, puis ce qui rentre.
		local items = { "big" }
		local total = KINDS.big.length
		while true do
			local kind = EXTRA[random:NextInteger(1, #EXTRA)]
			if total + KINDS[kind].length + (#items + 2) * 4.2 > usable then
				kind = "pad"
				if total + KINDS.pad.length + (#items + 2) * 4.2 > usable then
					break
				end
			end
			table.insert(items, random:NextInteger(1, #items + 1), kind)
			total += KINDS[kind].length
		end
		-- Trous égaux entre les morceaux ; s'ils seraient trop grands, les morceaux sont allongés.
		local gap = (usable - total) / (#items + 1)
		local stretch = 0
		if gap > MAX_GAP then
			stretch = (gap - MAX_GAP) * (#items + 1) / #items
			gap = MAX_GAP
		end

		local cursor = CORNER / 2
		for _, kind in items do
			local def = KINDS[kind]
			local length = def.length + stretch
			local start = cursor + gap
			if kind == "big" then
				-- Allongée vers l'arrière pour raccourcir le saut.
				start -= math.max(0, gap - BIG_GAP)
				length += math.max(0, gap - BIG_GAP)
			end
			if kind == "steps" then
				local piece = (length - 5) / 3
				for i = 0, 2 do
					height += def.rise * step
					add(kind, from + along * (start + piece / 2 + i * (piece + 2.5)), along, piece, def.width)
				end
			else
				height += def.rise * step
				add(kind, from + along * (start + length / 2), along, length, def.width)
			end
			cursor = start + length
		end
		height += 0.25 * step
		add(if last then "final" else "corner", to, along, if last then FINAL else CORNER, if last then FINAL else CORNER)
	end
	return { blocks = blocks, top = height, step = step }
end

function Lava.new(ctx, params)
	local self = {}
	local plan = Lava.plan(ctx.room.index, params)
	local final = plan.top - 1.2 -- hauteur finale de la lave : juste sous la dernière plateforme
	local finish = params.finish or (Config.DURATION - 3)
	local tops = {}

	local counts = {}
	for i, block in plan.blocks do
		local center = ctx.center + Vector3.new(block.top.X, block.top.Y - THICK / 2, block.top.Z)
		local color, material = Color3.fromRGB(150, 154, 168), Enum.Material.SmoothPlastic
		if block.kind == "final" then
			color, material = Color3.fromRGB(70, 230, 110), Enum.Material.Neon
		elseif COLORS[block.kind] then
			counts[block.kind] = (counts[block.kind] or 0) + 1
			color = COLORS[block.kind][counts[block.kind] % #COLORS[block.kind] + 1]
		end
		Build.part(ctx.static, "Course" .. i, block.size, center, color, material)
		tops[i] = ctx.center + block.top
	end
	ctx.room.pillars = tops
	ctx.room.finalTop = tops[#tops]

	local lava = Build.part(
		ctx.static,
		"Lava",
		Vector3.new(ctx.halfX * 2, final + 4, ctx.halfZ * 2 - 1.6),
		ctx.center,
		Color3.fromRGB(255, 96, 20),
		Enum.Material.Neon
	)
	lava.CanCollide = false
	lava.CanQuery = false
	lava.CanTouch = false

	local top, tick = -2, 0
	local function place(height: number)
		top = height
		lava.Position = ctx.center + Vector3.new(0, height - lava.Size.Y / 2, 0)
		ctx.liquidY = height
		ctx.room.folder:SetAttribute("Lava", math.floor(height * 10) / 10)
	end
	place(-2)

	function self.start()
		tick = 0
		place(-2)
	end

	function self.update(dt: number, elapsed: number)
		place(if elapsed > START then 0.3 + final * math.clamp((elapsed - START) / (finish - START), 0, 1) else -2)
		tick += dt
		if tick < TICK then
			return
		end
		tick -= TICK
		for _, entry in ctx.players() do
			-- Pieds du personnage : 3 studs sous le milieu du corps.
			if entry.root.Position.Y - 3 < top - 0.3 then
				ctx.damage(entry.player, Config.DAMAGE.Lava)
			end
		end
	end

	function self.stop()
		place(-2)
	end

	return self
end

return Lava

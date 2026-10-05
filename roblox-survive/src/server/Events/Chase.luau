-- LE MONSTRE (salle de course) : un monstre fonce sur le joueur le plus proche. S'il le touche, c'est fini.
-- Il court un peu moins vite qu'un joueur au niveau de vitesse demandé par la salle, et plus vite qu'un joueur du
-- niveau d'en dessous (Config.chaseSpeed) : il faut le bon niveau ET courir à pleine vitesse tout le long.
-- En tournant en grands cercles, un joueur assez rapide n'est jamais rattrapé ; les petits cercles le font perdre.
--
-- Le serveur ne déplace qu'un bloc invisible (étiqueté « Chaser ») ; l'écran de chaque joueur dessine le monstre
-- dessus et l'anime (Animals.luau).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Build = require(script.Parent.Parent.Build)

local Chase = {}

local REACH = 4.5 -- distance (vue d'en haut) à laquelle le monstre attrape un joueur
local MARGIN = 5 -- le monstre reste à cette distance des murs
local GRACE = 1.5 -- secondes après son départ pendant lesquelles il ne peut encore attraper personne

function Chase.new(ctx, params)
	local self = {}
	local speed = Config.chaseSpeed(params.level)
	local start = ctx.center + Vector3.new(0, 0, ctx.halfZ - 10) -- au fond de la salle, loin de l'entrée
	local body: Part? = nil
	local position = start

	local function remove()
		if body then
			body:Destroy()
			body = nil
		end
		ctx.room.chaser = nil
	end

	function self.start()
		remove()
		position = start
		local part = Build.part(ctx.effects, "Chaser", Vector3.new(6, 12, 6), CFrame.lookAt(start + Vector3.new(0, 6, 0), ctx.center + Vector3.new(0, 6, 0)), Color3.fromRGB(200, 40, 40))
		part.Transparency = 1
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 50, 50)
		light.Range = 22
		light.Brightness = 2
		light.Parent = part
		part:AddTag("Chaser")
		body = part
	end

	function self.update(dt: number, elapsed: number)
		if not body then
			return
		end
		-- Le joueur le plus proche.
		local target, best = nil, math.huge
		for _, entry in ctx.players() do
			local offset = entry.root.Position - position
			local distance = Vector3.new(offset.X, 0, offset.Z).Magnitude
			if distance < best then
				target, best = entry, distance
			end
		end
		ctx.room.chaser = { position = position, speed = speed, distance = best, moving = elapsed >= params.delay }
		if not target or elapsed < params.delay then
			return
		end
		-- Il n'attrape personne pendant sa première seconde et demie : un joueur qui se trouvait juste à côté de lui
		-- quand il démarre a le temps de filer.
		if best <= REACH and elapsed >= params.delay + GRACE then
			ctx.damage(target.player, Config.DAMAGE.Chase)
			return
		end
		local offset = target.root.Position - position
		local direction = Vector3.new(offset.X, 0, offset.Z).Unit
		position += direction * math.min(speed * dt, best)
		position = Vector3.new(
			math.clamp(position.X, ctx.center.X - ctx.halfX + MARGIN, ctx.center.X + ctx.halfX - MARGIN),
			0,
			math.clamp(position.Z, ctx.center.Z - ctx.halfZ + MARGIN, ctx.center.Z + ctx.halfZ - MARGIN)
		)
		body.CFrame = CFrame.lookAt(position + Vector3.new(0, 6, 0), position + direction + Vector3.new(0, 6, 0))
	end

	function self.stop()
		remove()
	end

	return self
end

return Chase

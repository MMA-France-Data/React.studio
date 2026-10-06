-- LE PRÉDATEUR : un prédateur chasse chaque joueur pendant toute la manche. Il faut lui échapper jusqu'au bout.
--
-- La salle est un CIRCUIT : un gros rocher occupe le milieu, on court autour. Le prédateur court sur la corde (tout
-- contre le rocher) vers son joueur, par le plus court chemin. Il va un peu moins vite qu'un joueur au palier de
-- vitesse demandé, et plus vite qu'un joueur du palier d'en dessous (Config.hunterSpeed) : sans le palier, il vous
-- rattrape forcément, et on ne peut pas le semer en coupant (le rocher est trop haut pour sauter dessus).
--
-- LA FEINTE : de temps en temps il plonge dans un terrier du rocher et ressort DEVANT le joueur, de l'autre côté.
-- Un grand « ! » rouge montre la sortie une seconde avant : il faut faire demi-tour tout de suite. La sortie est
-- placée pour qu'un joueur qui réagit vite garde la même avance qu'avant ; celui qui réagit tard en perd.
--
-- CHACUN JOUE SEUL : le prédateur d'un joueur ne s'occupe que de lui, et les joueurs ne se cognent pas. Le serveur
-- ne déplace que des blocs invisibles étiquetés « Hunter » et « HunterExit » (attribut « Owner ») ; l'écran de
-- chaque joueur dessine SON prédateur et cache les autres joueurs (Animals.luau).
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Build = require(script.Parent.Parent.Build)

local Hunter = {}

-- Le rocher du milieu (demi-largeurs) et sa hauteur : plus haut que le meilleur saut du jeu.
local BLOCK_X, BLOCK_Z, BLOCK_HEIGHT = 17, 22, 26
-- Le prédateur court à cette distance du rocher : tout contre, pour que personne ne puisse passer plus à
-- l'intérieur que lui dans les virages (un personnage ne peut pas s'approcher à moins de 1 stud du rocher). Il est
-- DESSINÉ un peu plus loin (SHOWN), pour ne pas entrer dans le rocher.
local LANE, SHOWN = 1.2, 2.2
-- Il attrape son joueur quand il arrive à sa hauteur LE LONG DU CIRCUIT (à moins de REACH), même si le joueur est
-- collé au mur d'en face : il bondit de côté. Rester contre le mur extérieur ne protège donc pas.
local REACH = 3.5
local START = 22 -- au début, il apparaît à cette distance de son joueur, le long du circuit
local ROAR = 0.8 -- secondes au début pendant lesquelles il rugit sans bouger
local DIG = 1 -- secondes entre le plongeon dans le terrier et la sortie
local REACTION = 0.45 -- temps de réaction d'un joueur normal : avec lui, une feinte ne change pas l'avance
local FEINT_MIN, FEINT_MAX = 6, 10 -- secondes entre deux feintes
local FEINT_NEAR = 12 -- il ne feinte pas si son joueur est plus près que ça (il est en train de l'attraper)
-- La sortie du terrier est entre EXIT_MIN et EXIT_MAX studs devant le joueur : un joueur qui a pris beaucoup
-- d'avance la perd à chaque feinte (le prédateur reste toujours une menace).
local EXIT_MIN, EXIT_MAX = 10, 28
local GRACE = 0.35 -- secondes après sa sortie pendant lesquelles il n'attrape pas encore
local GROUP = "SurviveSolo"

-- Les joueurs d'une salle du prédateur ne se cognent pas entre eux.
pcall(function()
	PhysicsService:RegisterCollisionGroup(GROUP)
	PhysicsService:CollisionGroupSetCollidable(GROUP, GROUP, false)
end)
local function setGroup(character: Model?, group: string)
	for _, part in if character then character:GetDescendants() else {} do
		if part:IsA("BasePart") then
			part.CollisionGroup = group
		end
	end
end

function Hunter.new(ctx, params)
	local self = {}
	local random = Random.new()
	local speed = Config.hunterSpeed(params.level)
	local center = ctx.center

	-- LE DÉCOR : le gros bloc du milieu, avec un terrier sur chaque face.
	-- Il est TRANSPARENT (une cage de verre) : on voit toujours son predateur a travers, mais on ne passe pas.
	local rock = Build.part(ctx.static, "Mesa", Vector3.new(BLOCK_X * 2, BLOCK_HEIGHT, BLOCK_Z * 2), center + Vector3.new(0, BLOCK_HEIGHT / 2, 0), Color3.fromRGB(255, 244, 224), Enum.Material.SmoothPlastic)
	rock.Transparency = 0.88
	rock.CastShadow = false
	rock.TopSurface = Enum.SurfaceType.Smooth
	-- Son cadre : un socle, un rebord en haut et quatre montants, pour qu'on voie bien ou il est.
	for i, band in { 0.7, BLOCK_HEIGHT - 0.7 } do
		local rim = Build.part(ctx.static, "MesaRim" .. i, Vector3.new(BLOCK_X * 2 + 0.4, 1.4, BLOCK_Z * 2 + 0.4), center + Vector3.new(0, band, 0), Color3.fromRGB(170, 112, 70), Enum.Material.Sandstone)
		rim.CanCollide = false
		rim.Transparency = if i == 1 then 0 else 0.4
	end
	for i, corner in { Vector3.new(-1, 0, -1), Vector3.new(1, 0, -1), Vector3.new(1, 0, 1), Vector3.new(-1, 0, 1) } do
		local post = Build.part(ctx.static, "MesaPost" .. i, Vector3.new(1.2, BLOCK_HEIGHT, 1.2), center + Vector3.new(corner.X * (BLOCK_X - 0.5), BLOCK_HEIGHT / 2, corner.Z * (BLOCK_Z - 0.5)), Color3.fromRGB(170, 112, 70), Enum.Material.Sandstone)
		post.CanCollide = false
	end
	for i, hole in { Vector3.new(0, 0, -BLOCK_Z), Vector3.new(0, 0, BLOCK_Z), Vector3.new(-BLOCK_X, 0, 0), Vector3.new(BLOCK_X, 0, 0), Vector3.new(-BLOCK_X, 0, 12), Vector3.new(BLOCK_X, 0, -12) } do
		-- Un trou sombre, posé à plat sur la face du rocher.
		local onX = math.abs(hole.X) >= BLOCK_X
		local size = if onX then Vector3.new(0.5, 4.4, 6) else Vector3.new(6, 4.4, 0.5)
		local burrow = Build.part(ctx.static, "Burrow" .. i, size, center + hole + Vector3.new(0, 2.2, 0), Color3.fromRGB(30, 22, 18), Enum.Material.Slate)
		burrow.CanCollide = false
	end

	-- LE CIRCUIT du prédateur : un rectangle autour du rocher, parcouru par une distance `s` (0 à `length`).
	local halfX, halfZ = BLOCK_X + LANE, BLOCK_Z + LANE
	local sides = { halfX * 2, halfZ * 2, halfX * 2, halfZ * 2 }
	local length = 2 * (sides[1] + sides[2])
	local corners = {
		Vector3.new(-halfX, 0, -halfZ),
		Vector3.new(halfX, 0, -halfZ),
		Vector3.new(halfX, 0, halfZ),
		Vector3.new(-halfX, 0, halfZ),
	}
	-- Le point du circuit à la distance s, et la direction du circuit à cet endroit.
	local function pointAt(s: number): (Vector3, Vector3)
		s %= length
		for i = 1, 4 do
			if s <= sides[i] then
				local from, to = corners[i], corners[i % 4 + 1]
				local direction = (to - from).Unit
				return center + from + direction * s, direction
			end
			s -= sides[i]
		end
		return center + corners[1], Vector3.xAxis
	end
	-- La distance `s` du point du circuit le plus proche de cette position.
	local function nearest(position: Vector3): number
		local best, bestDistance, travelled = 0, math.huge, 0
		local point = Vector3.new(position.X - center.X, 0, position.Z - center.Z)
		for i = 1, 4 do
			local from, to = corners[i], corners[i % 4 + 1]
			local direction = (to - from).Unit
			local along = math.clamp((point - from):Dot(direction), 0, sides[i])
			local distance = (point - (from + direction * along)).Magnitude
			if distance < bestDistance then
				best, bestDistance = travelled + along, distance
			end
			travelled += sides[i]
		end
		return best
	end
	-- Écart le long du circuit, de a vers b, par le plus court : entre -length/2 et length/2.
	local function gap(a: number, b: number): number
		return (b - a + length / 2) % length - length / 2
	end
	-- La direction qui s'éloigne du rocher, à cet endroit du circuit.
	local function outwardAt(position: Vector3, direction: Vector3): Vector3
		local side = Vector3.new(direction.Z, 0, -direction.X)
		return if (position + side - center).Magnitude > (position - center).Magnitude then side else -side
	end

	local hunters = {} -- [joueur] = { s, sign, mode, timer, feint, grace, exitS, part, exit }
	local running = false

	local function ghost(part: BasePart)
		part.Transparency = 1
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
	end
	local function place(hunter)
		local position, direction = pointAt(hunter.s)
		local shown = position + outwardAt(position, direction) * SHOWN + Vector3.new(0, 2, 0)
		hunter.part.CFrame = CFrame.lookAt(shown, shown + direction * hunter.sign)
	end
	local function remove(player: Player)
		local hunter = hunters[player]
		if hunter then
			hunter.part:Destroy()
			if hunter.exit then
				hunter.exit:Destroy()
			end
			hunters[player] = nil
		end
	end

	function self.start()
		running = true
		for player in hunters do
			remove(player)
		end
		for _, entry in ctx.players() do
			local part = Build.part(ctx.effects, "Hunter", Vector3.new(4, 4, 4), center, Color3.fromRGB(120, 120, 130))
			ghost(part)
			part:SetAttribute("Owner", entry.player.UserId)
			part:AddTag("Hunter")
			-- Il apparaît derrière le joueur (du côté opposé à celui où il regarde le circuit).
			local playerS = nearest(entry.root.Position)
			local _, direction = pointAt(playerS)
			local look = entry.root.CFrame.LookVector
			local facing = if Vector3.new(look.X, 0, look.Z):Dot(direction) >= 0 then 1 else -1
			local hunter = {
				s = (playerS - facing * START) % length,
				sign = facing,
				mode = "roar",
				timer = ROAR,
				feint = ROAR + random:NextNumber(FEINT_MIN, FEINT_MAX),
				grace = 0,
				exitS = 0,
				part = part,
				feints = 0,
			}
			hunters[entry.player] = hunter
			place(hunter)
			setGroup(entry.player.Character, GROUP)
		end
		ctx.room.folder:SetAttribute("Hunter", true)
	end

	function self.update(dt: number, elapsed: number)
		if not running then
			return
		end
		local state = {}
		for _, entry in ctx.players() do
			local hunter = hunters[entry.player]
			if not hunter then
				continue
			end
			local root = entry.root.Position
			local playerS = nearest(root)
			local away = gap(hunter.s, playerS) -- du prédateur vers son joueur, par le plus court
			hunter.timer -= dt
			hunter.grace -= dt
			if hunter.mode == "roar" then
				-- Le début de la manche : il rugit sans bouger, le joueur voit de quel côté il est.
				hunter.sign = if away >= 0 then 1 else -1
				if hunter.timer <= 0 then
					hunter.mode = "run"
				end
				place(hunter)
			elseif hunter.mode == "dig" then
				-- Dans le terrier : il ressort à la sortie annoncée.
				if hunter.timer <= 0 then
					hunter.s = hunter.exitS
					hunter.mode = "run"
					hunter.grace = GRACE
					hunter.feint = random:NextNumber(FEINT_MIN, FEINT_MAX)
					hunter.sign = if gap(hunter.s, playerS) >= 0 then 1 else -1
					if hunter.exit then
						hunter.exit:Destroy()
						hunter.exit = nil
					end
					place(hunter)
				end
			else
				if math.abs(away) <= REACH and hunter.grace <= 0 then
					ctx.damage(entry.player, Config.DAMAGE.Chase)
				else
					hunter.sign = if away >= 0 then 1 else -1
					hunter.s = (hunter.s + hunter.sign * math.min(speed * dt, math.abs(away))) % length
					hunter.feint -= dt
					local distance = math.abs(away)
					if hunter.feint <= 0 and distance >= FEINT_NEAR and elapsed < Config.DURATION - DIG - 2 then
						-- LA FEINTE : il plonge et ressortira devant le joueur (qui fuit dans le sens `sign`). La
						-- sortie est à la bonne distance pour qu'un joueur qui fait demi-tour après REACTION
						-- secondes retrouve la même avance.
						local ahead = math.clamp(distance - (DIG - 2 * REACTION) * speed, EXIT_MIN, EXIT_MAX)
						hunter.exitS = (playerS + hunter.sign * ahead) % length
						hunter.mode = "dig"
						hunter.timer = DIG
						hunter.feints += 1
						local spot, direction = pointAt(hunter.exitS)
						local exit = Build.part(ctx.effects, "HunterExit", Vector3.new(2, 2, 2), spot + outwardAt(spot, direction) * SHOWN + Vector3.new(0, 2, 0), Color3.fromRGB(255, 40, 40))
						ghost(exit)
						exit:SetAttribute("Owner", entry.player.UserId)
						exit:AddTag("HunterExit")
						hunter.exit = exit
					end
					place(hunter)
				end
			end
			hunter.part:SetAttribute("Moving", hunter.mode == "run")
			hunter.part:SetAttribute("Hidden", hunter.mode == "dig")
			state[tostring(entry.player.UserId)] = {
				s = hunter.s,
				mode = hunter.mode,
				exitS = hunter.exitS,
				distance = math.abs(gap(hunter.s, playerS)),
				feints = hunter.feints,
				position = pointAt(hunter.s),
			}
		end
		ctx.room.hunter = { speed = speed, length = length, players = state }
	end

	function self.stop()
		running = false
		for player in hunters do
			setGroup(player.Character, "Default")
			remove(player)
		end
		ctx.room.hunter = nil
		ctx.room.folder:SetAttribute("Hunter", nil)
	end

	return self
end

return Hunter

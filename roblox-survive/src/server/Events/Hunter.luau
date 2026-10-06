-- LE PRÉDATEUR : un prédateur chasse chaque joueur pendant toute la manche. Il faut lui échapper jusqu'au bout.
--
-- La salle est un CIRCUIT : un gros bloc transparent occupe le milieu, on court autour (il est trop haut pour sauter
-- dessus, et on voit toujours son prédateur à travers).
--
-- LE PRÉDATEUR SUIT LA TRACE DE SON JOUEUR : il passe exactement là où le joueur est passé, virages larges compris.
-- Il fait donc le même chemin que lui, ni plus court ni plus long : seule la vitesse compte. Il va un peu moins vite
-- qu'un joueur au palier de vitesse demandé, et plus vite qu'un joueur du palier d'en dessous (Config.hunterSpeed) :
-- sans le palier, il vous rattrape forcément. (Avant, il courait à la corde du bloc : un joueur au bon palier qui
-- prenait ses virages un peu large se faisait rattraper.)
--
-- CHACUN JOUE SEUL : le prédateur d'un joueur ne s'occupe que de lui, et les joueurs ne se cognent pas. Le serveur
-- ne déplace que des blocs invisibles étiquetés « Hunter » (attribut « Owner ») ; l'écran de chaque joueur dessine
-- SON prédateur et cache les autres joueurs (Animals.luau).
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Build = require(script.Parent.Parent.Build)

local Hunter = {}

-- Le bloc du milieu (demi-largeurs) et sa hauteur : plus haut que le meilleur saut du jeu.
local BLOCK_X, BLOCK_Z, BLOCK_HEIGHT = 17, 22, 26
local LANE = 6 -- au début de la manche, le prédateur arrive par le milieu du couloir (à cette distance du bloc)
local REACH = 4 -- distance (vue d'en haut) à laquelle il attrape son joueur
local START = 14 -- au début, il apparaît à cette distance de son joueur, le long du circuit
local ROAR = 0.8 -- secondes au début pendant lesquelles il rugit sans bouger
local CRUMB = 1.5 -- une marque de la trace du joueur tous les ... studs
-- Un joueur bien plus rapide que lui finirait par faire un tour d'avance et lui rentrer dedans par derriere : au-dela
-- de FAR studs d'avance, le predateur accelere (CATCH_UP studs/s en plus par stud d'avance en trop). L'avance ne
-- depasse donc jamais un tiers de tour, et il reste toujours une menace.
local FAR, CATCH_UP = 55, 1.5
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
local function flat(position: Vector3): Vector3
	return Vector3.new(position.X, 0, position.Z)
end

function Hunter.new(ctx, params)
	local self = {}
	local speed = Config.hunterSpeed(params.level)
	local center = ctx.center

	-- LE DÉCOR : le gros bloc du milieu, transparent (une cage de verre) : on voit toujours son prédateur à travers,
	-- mais on ne passe pas.
	local rock = Build.part(ctx.static, "Mesa", Vector3.new(BLOCK_X * 2, BLOCK_HEIGHT, BLOCK_Z * 2), center + Vector3.new(0, BLOCK_HEIGHT / 2, 0), Color3.fromRGB(255, 244, 224), Enum.Material.SmoothPlastic)
	rock.Transparency = 0.88
	rock.CastShadow = false
	rock.TopSurface = Enum.SurfaceType.Smooth
	-- Son cadre : un socle, un rebord en haut et quatre montants, pour qu'on voie bien où il est.
	for i, band in { 0.7, BLOCK_HEIGHT - 0.7 } do
		local rim = Build.part(ctx.static, "MesaRim" .. i, Vector3.new(BLOCK_X * 2 + 0.4, 1.4, BLOCK_Z * 2 + 0.4), center + Vector3.new(0, band, 0), Color3.fromRGB(170, 112, 70), Enum.Material.Sandstone)
		rim.CanCollide = false
		rim.Transparency = if i == 1 then 0 else 0.4
	end
	for i, corner in { Vector3.new(-1, 0, -1), Vector3.new(1, 0, -1), Vector3.new(1, 0, 1), Vector3.new(-1, 0, 1) } do
		local post = Build.part(ctx.static, "MesaPost" .. i, Vector3.new(1.2, BLOCK_HEIGHT, 1.2), center + Vector3.new(corner.X * (BLOCK_X - 0.5), BLOCK_HEIGHT / 2, corner.Z * (BLOCK_Z - 0.5)), Color3.fromRGB(170, 112, 70), Enum.Material.Sandstone)
		post.CanCollide = false
	end

	-- Le milieu du couloir : un rectangle autour du bloc, parcouru par une distance `s`. Il ne sert qu'au tout
	-- début, pour amener le prédateur de son point de départ jusqu'à la trace du joueur.
	local halfX, halfZ = BLOCK_X + LANE, BLOCK_Z + LANE
	local sides = { halfX * 2, halfZ * 2, halfX * 2, halfZ * 2 }
	local length = 2 * (sides[1] + sides[2])
	local corners = {
		Vector3.new(-halfX, 0, -halfZ),
		Vector3.new(halfX, 0, -halfZ),
		Vector3.new(halfX, 0, halfZ),
		Vector3.new(-halfX, 0, halfZ),
	}
	local function pointAt(s: number): Vector3
		s %= length
		for i = 1, 4 do
			if s <= sides[i] then
				return flat(center) + corners[i] + (corners[i % 4 + 1] - corners[i]).Unit * s
			end
			s -= sides[i]
		end
		return flat(center) + corners[1]
	end
	local function nearest(position: Vector3): number
		local best, bestDistance, travelled = 0, math.huge, 0
		local point = flat(position) - flat(center)
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

	local hunters = {} -- [joueur] = { position, facing, trail, first, roar, part }
	local running = false

	local function place(hunter)
		local at = Vector3.new(hunter.position.X, center.Y + 2, hunter.position.Z)
		hunter.part.CFrame = CFrame.lookAt(at, at + hunter.facing)
	end
	local function remove(player: Player)
		local hunter = hunters[player]
		if hunter then
			hunter.part:Destroy()
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
			part.Transparency = 1
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			part:SetAttribute("Owner", entry.player.UserId)
			part:AddTag("Hunter")
			-- Il apparaît derrière le joueur (du côté opposé à celui où il regarde le circuit), au milieu du couloir,
			-- et rejoint sa trace en longeant le couloir.
			local playerS = nearest(entry.root.Position)
			local ahead = pointAt(playerS + 1) - pointAt(playerS)
			local look = entry.root.CFrame.LookVector
			local facing = if flat(look):Dot(ahead) >= 0 then 1 else -1
			local trail = {}
			for step = START - CRUMB, 0, -CRUMB do
				table.insert(trail, pointAt(playerS - facing * step))
			end
			table.insert(trail, flat(entry.root.Position))
			local hunter = {
				position = pointAt(playerS - facing * START),
				facing = (ahead * facing).Unit,
				trail = trail,
				first = 1, -- la prochaine marque à atteindre dans `trail`
				roar = ROAR,
				part = part,
			}
			hunters[entry.player] = hunter
			place(hunter)
			setGroup(entry.player.Character, GROUP)
		end
		ctx.room.folder:SetAttribute("Hunter", true)
	end

	function self.update(dt: number, _elapsed: number)
		if not running then
			return
		end
		local state = {}
		for _, entry in ctx.players() do
			local hunter = hunters[entry.player]
			if not hunter then
				continue
			end
			local root = flat(entry.root.Position)
			local trail = hunter.trail
			-- La trace : une marque à chaque fois que le joueur s'est éloigné de la dernière.
			if (root - trail[#trail]).Magnitude >= CRUMB then
				table.insert(trail, root)
			end
			hunter.roar -= dt
			local moving = hunter.roar <= 0
			if moving then
				if (root - hunter.position).Magnitude <= REACH then
					ctx.damage(entry.player, Config.DAMAGE.Chase)
				else
					-- Il avance le long de la trace, marque après marque, puis droit sur le joueur.
					local lead = math.max(0, #trail - hunter.first) * CRUMB + ((trail[hunter.first] or root) - hunter.position).Magnitude
					local left = (speed + math.max(0, lead - FAR) * CATCH_UP) * dt
					while left > 0 do
						local target = trail[hunter.first] or root
						local offset = target - hunter.position
						local distance = offset.Magnitude
						if distance > 0.001 then
							hunter.facing = offset.Unit
						end
						if distance <= left then
							hunter.position = target
							left -= distance
							if not trail[hunter.first] then
								break
							end
							hunter.first += 1
						else
							hunter.position += offset.Unit * left
							left = 0
						end
					end
					-- Les marques déjà passées sont jetées de temps en temps.
					if hunter.first > 64 then
						local kept = {}
						table.move(trail, hunter.first, #trail, 1, kept)
						hunter.trail = kept
						hunter.first = 1
						trail = kept
					end
				end
			end
			place(hunter)
			hunter.part:SetAttribute("Moving", moving)
			-- L'avance du joueur : le chemin qu'il reste au prédateur le long de la trace.
			local lead = math.max(0, #trail - hunter.first) * CRUMB + ((trail[hunter.first] or root) - hunter.position).Magnitude
			state[tostring(entry.player.UserId)] = { lead = lead, position = hunter.position + Vector3.new(0, center.Y, 0), moving = moving }
		end
		ctx.room.hunter = { speed = speed, players = state }
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

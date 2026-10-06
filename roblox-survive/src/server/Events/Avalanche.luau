-- L'AVALANCHE : des rochers roulent vers le joueur dans trois couloirs. Il doit les casser à coups de poing (touche E
-- ou bouton « FRAPPE ») avant qu'ils passent la ligne rouge. Chaque rocher qui passe la ligne le blesse : trois
-- rochers passés et c'est fini. Il faut tenir jusqu'à la fin de la manche.
--
-- LA FORCE : un rocher a la solidité de la force demandée par la salle (params.points de force). Avec cette force,
-- un coup le casse. Avec moins, le coup ne lui fait RIEN (« pas assez de force ») : la salle est impossible.
-- (Avant, un joueur plus faible le cassait en deux coups et devait être débordé par le nombre ; le joueur a trouvé
-- qu'il tombait beaucoup trop de rochers : « divise par 2 ». Avec deux fois moins de rochers, deux coups auraient
-- suffi à tout le monde, donc la force est devenue une vraie barrière.)
-- Les rochers arrivent assez espacés pour avoir le temps de changer de couloir et de frapper, avec une marge qui
-- diminue pendant la manche.
--
-- LE CERVEAU : les rochers arrivent dans les trois couloirs ; il faut aller dans le bon, au bon moment, et choisir
-- lequel casser d'abord quand deux sont proches.
--
-- CHACUN JOUE SEUL : chaque joueur a ses propres rochers (blocs invisibles étiquetés « Boulder », attribut
-- « Owner ») ; son écran dessine les siens et cache les autres joueurs (Animals.luau).
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Build = require(script.Parent.Parent.Build)

local Avalanche = {}

local LANES = { -18, 0, 18 } -- le milieu de chaque couloir (par rapport au milieu de la salle)
local LANE_WIDTH = 16
local LINE = -30 -- la ligne rouge (par rapport au milieu de la salle) : un rocher qui la passe blesse le joueur
local SPAWN = 34 -- là où les rochers apparaissent
local ROLL = 10 -- vitesse des rochers, en studs par seconde
local REACH = 9 -- distance (vue d'en haut) à laquelle on peut frapper un rocher
local HIT = 0.5 -- secondes entre deux coups de poing
local LEAK_DAMAGE = 34 -- un rocher qui passe la ligne : trois et le joueur est mort
-- Temps laissé entre deux rochers : LANE_TIME par couloir à traverser + HIT pour frapper + une marge, qui passe de
-- MARGIN_START à MARGIN_END pendant la manche. (Deux fois plus de temps qu'au premier essai : un rocher toutes les
-- 4 secondes en moyenne, une quinzaine dans la minute.)
local LANE_TIME = 2.2
local MARGIN_START, MARGIN_END = 1.9, 0.9
-- Puis 20 % de rochers en plus (le joueur : "c'est trop simple, ajoute plus de rochers mais pas trop, genre 20 %").
local RATE = 1.2
local FIRST = 2 -- secondes avant le premier rocher
local GROUP = "SurviveSolo"

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

function Avalanche.new(ctx, params)
	local self = {}
	local random = Random.new()
	local center = ctx.center
	-- La solidité d'un rocher : la force d'un joueur qui a les points demandés.
	local solidity = Config.force(Config.levelOf(params.points))

	-- LE DÉCOR : la ligne rouge, et les deux séparations entre les couloirs.
	local line = Build.part(ctx.static, "Line", Vector3.new(ctx.halfX * 2 - 2, 0.2, 1.2), center + Vector3.new(0, 0.15, LINE), Color3.fromRGB(255, 50, 50), Enum.Material.Neon)
	line.CanCollide = false
	for i, x in { -LANE_WIDTH / 2 - 1, LANE_WIDTH / 2 + 1 } do
		local strip = Build.part(ctx.static, "LaneStrip" .. i, Vector3.new(0.5, 0.2, SPAWN - LINE), center + Vector3.new(x, 0.12, (SPAWN + LINE) / 2), Color3.fromRGB(255, 221, 51), Enum.Material.Neon)
		strip.CanCollide = false
		strip.Transparency = 0.4
	end
	-- La pente du fond, d'où tombent les rochers (décor).
	local slope = Build.part(ctx.static, "Slope", Vector3.new(ctx.halfX * 2 - 4, 1, 14), CFrame.new(center + Vector3.new(0, 5, SPAWN + 3)) * CFrame.Angles(math.rad(-38), 0, 0), Color3.fromRGB(96, 90, 92), Enum.Material.Slate)
	slope.CanCollide = false

	local games = {} -- [joueur] = { rocks, next, lane, leaks, broken, lastHit }
	local running = false

	local function remove(player: Player)
		local game = games[player]
		if game then
			for _, rock in game.rocks do
				rock.part:Destroy()
			end
			games[player] = nil
		end
	end
	local function publish(player: Player, game)
		player:SetAttribute("RockLeaks", game.leaks)
		player:SetAttribute("RockBroken", game.broken)
	end

	-- Un coup de poing : frappe le rocher du joueur le plus proche de lui, s'il est à portée. Renvoie true s'il a
	-- touché un rocher.
	function self.push(player: Player, elapsed: number, _unlimited: boolean?): boolean
		local game = games[player]
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not running or not game or not root or elapsed - game.lastHit < HIT then
			return false
		end
		local best, bestDistance = nil, REACH
		for index, rock in game.rocks do
			local offset = root.Position - rock.position
			local distance = Vector3.new(offset.X, 0, offset.Z).Magnitude
			if distance <= bestDistance then
				best, bestDistance = index, distance
			end
		end
		if not best then
			return false
		end
		game.lastHit = elapsed
		local rock = game.rocks[best]
		if (player:GetAttribute("ForcePoints") or 0) < params.points then
			-- Pas assez de force : le poing rebondit sur le rocher.
			if elapsed - game.lastWeak > 2 then
				game.lastWeak = elapsed
				ctx.notify(player, "rockWeak")
			end
			return false
		end
		rock.part:Destroy()
		table.remove(game.rocks, best)
		game.broken += 1
		publish(player, game)
		return true
	end
	ctx.room.push = self.push

	function self.start()
		running = true
		for player in games do
			remove(player)
		end
		for _, entry in ctx.players() do
			local game = { rocks = {}, next = FIRST, lane = 2, leaks = 0, broken = 0, lastHit = -10, lastWeak = -10 }
			games[entry.player] = game
			publish(entry.player, game)
			setGroup(entry.player.Character, GROUP)
		end
		ctx.room.folder:SetAttribute("Avalanche", true)
		ctx.room.folder:SetAttribute("Solo", true)
	end

	function self.update(dt: number, elapsed: number)
		if not running then
			return
		end
		local margin = MARGIN_START + (MARGIN_END - MARGIN_START) * math.clamp(elapsed / Config.DURATION, 0, 1)
		local state = {}
		for _, entry in ctx.players() do
			local game = games[entry.player]
			if not game then
				continue
			end
			-- Un nouveau rocher : dans un couloir au hasard, assez tard pour qu'on ait le temps d'y aller.
			game.next -= dt
			if game.next <= 0 and elapsed < Config.DURATION - (SPAWN - LINE) / ROLL then
				local lane = random:NextInteger(1, #LANES)
				game.next = (math.abs(lane - game.lane) * LANE_TIME + HIT + margin) / RATE
				game.lane = lane
				local position = center + Vector3.new(LANES[lane] + random:NextNumber(-3, 3), 3.5, SPAWN)
				local part = Build.part(ctx.effects, "Boulder", Vector3.new(7, 7, 7), position, Color3.fromRGB(96, 90, 92), Enum.Material.Slate)
				part.Shape = Enum.PartType.Ball
				part.Transparency = 1
				part.CanCollide = false
				part.CanQuery = false
				part.CanTouch = false
				part.CastShadow = false
				part:SetAttribute("Owner", entry.player.UserId)
				part:SetAttribute("Hp", 1)
				part:AddTag("Boulder")
				table.insert(game.rocks, { part = part, position = position, hp = solidity, lane = lane })
			end
			-- Les rochers roulent vers la ligne.
			for index = #game.rocks, 1, -1 do
				local rock = game.rocks[index]
				rock.position -= Vector3.new(0, 0, ROLL * dt)
				rock.part.Position = rock.position
				if rock.position.Z <= center.Z + LINE then
					rock.part:Destroy()
					table.remove(game.rocks, index)
					game.leaks += 1
					publish(entry.player, game)
					ctx.notify(entry.player, "rockLeak", game.leaks)
					ctx.damage(entry.player, LEAK_DAMAGE)
				end
			end
			local rocks = {}
			for index, rock in game.rocks do
				rocks[index] = { x = rock.position.X, z = rock.position.Z, hp = rock.hp }
			end
			state[tostring(entry.player.UserId)] = { rocks = rocks, leaks = game.leaks, broken = game.broken, ready = elapsed - game.lastHit >= HIT }
		end
		ctx.room.avalanche = { solidity = solidity, line = center.Z + LINE, reach = REACH, players = state }
	end

	function self.stop()
		running = false
		for player in games do
			setGroup(player.Character, "Default")
			remove(player)
		end
		ctx.room.avalanche = nil
		ctx.room.folder:SetAttribute("Avalanche", nil)
		ctx.room.folder:SetAttribute("Solo", nil)
	end

	return self
end

return Avalanche

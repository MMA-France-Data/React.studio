-- LES VANNES DU VOLCAN : quatre vannes aux quatre coins de la salle. La pression monte dans chacune, à des vitesses
-- différentes (une jauge au-dessus le montre). Le joueur court en fermer une : sa jauge retombe à zéro, puis elle
-- remonte. Une vanne qui arrive au bout EXPLOSE : trois explosions et c'est fini. Il faut tenir toute la manche.
--
-- LA VITESSE : rien n'empêche de fermer une vanne, il faut juste y arriver à temps (le joueur : « c'est nul que je
-- puisse pas activer si j'ai pas la vitesse, je devrais juste échouer »). Les jauges sont réglées sur un joueur qui
-- court à la vitesse demandée par la salle (params.points) : le temps de remplissage d'une vanne est un multiple
-- du temps qu'il met à faire le tour des quatre coins. Plus lent, on finit débordé.
-- Les quatre vitesses de remplissage TOURNENT d'une vanne à la suivante toutes les SHUFFLE secondes, sans hasard
-- (seul le point de départ est tiré au sort). Avec un échange au hasard, le résultat d'une manche dépendait surtout
-- de la chance : le joueur a « failli réussir » avec 300 points alors qu'il « devrait se faire exterminer ». Sans
-- hasard, la limite est bien plus franche (simulation) : à 150 et 300 points on meurt toujours, à 600 une fois sur
-- deux, à 1 000 et plus on tient ; à 10 000 points on tient même en hésitant 0,6 seconde à chaque vanne.
--
-- LE CERVEAU : les quatre vannes ne se remplissent pas à la même vitesse, et ça change pendant la manche. Il faut
-- choisir laquelle aller fermer : la plus urgente n'est pas toujours la plus proche.
--
-- CHACUN JOUE SEUL : chaque joueur a ses propres jauges (attribut « Valves » du joueur, lu par son écran) ; les
-- autres joueurs de la salle sont cachés et ne se cognent pas.
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Build = require(script.Parent.Parent.Build)

local Valves = {}

-- Les quatre vannes (par rapport au milieu de la salle), dans l'ordre d'un tour de salle.
local SPOTS = { Vector3.new(-27, 0, -31), Vector3.new(27, 0, -31), Vector3.new(27, 0, 31), Vector3.new(-27, 0, 31) }
local CLOSE = 6 -- distance (vue d'en haut) à laquelle le joueur ferme une vanne
-- Temps de remplissage des quatre vannes, en « tours de salle » (le temps qu'un joueur à la vitesse demandée met à
-- passer par les quatre coins). Une rapide, deux moyennes, une lente ; elles s'échangent tous les SHUFFLE secondes.
local FILLS = { 1.13, 1.65, 1.65, 2.27 }
local SHUFFLE = 12
local GRACE = 3 -- secondes au début pendant lesquelles rien ne monte
local BURST_DAMAGE = 30 -- une vanne qui explose blesse ; à la troisième (STRIKES), le joueur est mort
local STRIKES = 3
local PUBLISH = 0.1 -- secondes entre deux envois des jauges à l'écran
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

function Valves.new(ctx, params)
	local self = {}
	local random = Random.new()
	local center = ctx.center
	-- Le tour de salle : la distance pour passer par les quatre coins, à la vitesse demandée.
	local perimeter = 0
	for index, spot in SPOTS do
		perimeter += (SPOTS[index % #SPOTS + 1] - spot).Magnitude
	end
	local lap = perimeter / Config.walkSpeed(Config.levelOf(params.points))

	-- LE DÉCOR : quatre vannes (un tuyau, un volant rouge). Les jauges sont dessinées par l'écran de chaque joueur.
	for index, spot in SPOTS do
		local pipe = Build.part(ctx.static, "Valve" .. index, Vector3.new(3, 9, 3), center + spot + Vector3.new(0, 4.5, 0), Color3.fromRGB(90, 94, 104), Enum.Material.Metal)
		pipe:SetAttribute("Index", index)
		pipe:AddTag("Valve")
		local wheel = Build.part(ctx.static, "ValveWheel" .. index, Vector3.new(0.8, 5, 5), center + spot + Vector3.new(0, 6.5, 0), Color3.fromRGB(220, 60, 50), Enum.Material.Metal)
		wheel.Shape = Enum.PartType.Cylinder
		wheel.CanCollide = false
		local ring = Build.disc(ctx.static, "ValveRing" .. index, CLOSE * 2, 0.2, center + spot + Vector3.new(0, 0.12, 0), Color3.fromRGB(255, 200, 40), Enum.Material.Neon)
		ring.Transparency = 0.6
		ring.CanCollide = false
	end

	local games = {} -- [joueur] = { pressure = {4}, fills = {4}, shuffle, bursts, closed, sent }
	local running = false

	-- Les quatre vitesses, décalées de `shift` crans autour de la salle.
	local function rotated(shift: number): { number }
		local list = {}
		-- (Dans Studio, le panneau de réglages peut ralentir ou accélérer les jauges : attribut « ValveFactor ».)
		local factor = workspace:GetAttribute("ValveFactor") or 1
		for index = 1, #FILLS do
			list[index] = FILLS[(index - 1 + shift) % #FILLS + 1] * factor
		end
		return list
	end
	local function publish(player: Player, game)
		player:SetAttribute("Valves", string.format("%.3f,%.3f,%.3f,%.3f", game.pressure[1], game.pressure[2], game.pressure[3], game.pressure[4]))
		player:SetAttribute("ValveBursts", game.bursts)
		player:SetAttribute("ValveClosed", game.closed)
	end

	function self.start()
		running = true
		table.clear(games)
		for _, entry in ctx.players() do
			local shift = random:NextInteger(0, #FILLS - 1)
			local game = { pressure = { 0, 0, 0, 0 }, fills = rotated(shift), shift = shift, shuffle = SHUFFLE, bursts = 0, closed = 0, sent = 0 }
			games[entry.player] = game
			publish(entry.player, game)
			setGroup(entry.player.Character, GROUP)
		end
		ctx.room.folder:SetAttribute("Valves", true)
		ctx.room.folder:SetAttribute("Solo", true)
	end

	function self.update(dt: number, elapsed: number)
		if not running then
			return
		end
		local state = {}
		for _, entry in ctx.players() do
			local game = games[entry.player]
			if not game then
				continue
			end
			game.shuffle -= dt
			if game.shuffle <= 0 then
				game.shuffle = SHUFFLE
				game.shift += 1
				game.fills = rotated(game.shift)
			end
			for index, spot in SPOTS do
				local offset = entry.root.Position - (center + spot)
				if Vector3.new(offset.X, 0, offset.Z).Magnitude <= CLOSE then
					-- Le joueur est à la vanne : elle est fermée.
					if game.pressure[index] > 0.08 then
						game.closed += 1
					end
					game.pressure[index] = 0
				elseif elapsed >= GRACE then
					game.pressure[index] += dt / (game.fills[index] * lap)
					if game.pressure[index] >= 1 then
						game.pressure[index] = 0
						game.bursts += 1
						ctx.notify(entry.player, "valveBurst", game.bursts)
						if game.bursts >= STRIKES then
							ctx.kill(entry.player)
						else
							ctx.damage(entry.player, BURST_DAMAGE)
						end
					end
				end
			end
			game.sent -= dt
			if game.sent <= 0 then
				game.sent = PUBLISH
				publish(entry.player, game)
			end
			state[tostring(entry.player.UserId)] = { pressure = table.clone(game.pressure), fills = table.clone(game.fills), bursts = game.bursts, closed = game.closed }
		end
		local spots = {}
		for index, spot in SPOTS do
			spots[index] = center + spot
		end
		ctx.room.valves = { lap = lap, spots = spots, players = state }
	end

	function self.stop()
		running = false
		for player in games do
			setGroup(player.Character, "Default")
			player:SetAttribute("Valves", nil)
		end
		table.clear(games)
		ctx.room.valves = nil
		ctx.room.folder:SetAttribute("Valves", nil)
		ctx.room.folder:SetAttribute("Solo", nil)
	end

	return self
end

return Valves

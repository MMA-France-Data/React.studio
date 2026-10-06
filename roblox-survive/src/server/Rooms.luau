-- Les salles. Chacune tourne toute seule :
--   Idle      : vide, porte d'entrée ouverte. Dès qu'un joueur entre, le compte à rebours part.
--   Countdown : 10 secondes pour se préparer ; d'autres joueurs peuvent encore entrer.
--   Event     : la porte d'entrée se ferme, les événements durent 60 secondes.
--   Open      : les survivants ont gagné, la porte du bout (« niveau suivant ») est ouverte quelques secondes.
-- Un joueur mort réapparaît dans la salle de sport. Les états sont posés en attributs sur le dossier de la salle
-- (State, Ends, Events...) : l'écran du joueur les lit là.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerData = require(script.Parent.PlayerData)
local Eggs = require(script.Parent.Eggs)
local Stats = require(script.Parent.Stats)
local World = require(script.Parent.World)

local EVENTS = {
	Lava = require(script.Parent.Events.Lava),
	Meteors = require(script.Parent.Events.Meteors),
	Explosions = require(script.Parent.Events.Explosions),
	Ceiling = require(script.Parent.Events.Ceiling),
	Melody = require(script.Parent.Events.Melody),
	Chase = require(script.Parent.Events.Chase),
	Bomb = require(script.Parent.Events.Bomb),
}

local Rooms = {}

-- Les tests dans Studio accélèrent le temps (1 = normal).
Rooms.timeScale = 1

local rooms = {}
local notify = function(_player: Player, _key: string, ...) end

local function body(player: Player): (Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and humanoid.Health > 0 then
		return humanoid, root
	end
	return nil, nil
end

local function inside(room, position: Vector3): boolean
	return math.abs(position.X) <= World.ROOM_HALF_X and position.Z > room.zMin + 1 and position.Z < room.zMax - 1 and position.Y > -6
end

-- Joueurs vivants dans la salle.
local function playersIn(room): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		local _, root = body(player)
		if root and inside(room, root.Position) then
			table.insert(list, player)
		end
	end
	return list
end

local function setState(room, state: string, duration: number)
	room.state = state
	room.t = duration
	room.folder:SetAttribute("Ends", workspace:GetServerTimeNow() + duration / Rooms.timeScale)
	room.folder:SetAttribute("State", state)
end

local function stopEvents(room)
	for _, event in room.events do
		event.stop()
	end
	room.effects:ClearAllChildren()
	for _, connection in room.connections do
		connection:Disconnect()
	end
	table.clear(room.connections)
end

local function toIdle(room)
	table.clear(room.participants)
	World.setDoor(room.exit, false)
	World.setDoor(room.entry, true)
	setState(room, "Idle", 0)
end

local function begin(room)
	local list = playersIn(room)
	if #list == 0 then
		toIdle(room)
		return
	end
	World.setDoor(room.entry, false)
	room.elapsed = 0
	table.clear(room.eliminated)
	for _, player in list do
		room.participants[player] = true
		local humanoid = body(player)
		table.insert(
			room.connections,
			humanoid.Died:Connect(function()
				if room.state ~= "Event" or not room.participants[player] then
					return
				end
				-- Un mort ne gagne rien : seule la salle réussie donne son ticket.
				room.participants[player] = nil
			end)
		)
	end
	for _, event in room.events do
		event.start()
	end
	setState(room, "Event", Config.DURATION)
end

local function win(room)
	stopEvents(room)
	local last = room.index == #rooms
	for player in room.participants do
		if body(player) then
			-- Une salle ne donne AUCUNE pièce : seulement son ticket (les pièces viennent des familiers).
			PlayerData.setBest(player, room.index)
			notify(player, "win", room.index)
			Eggs.give(player, room.index)
			if last then
				notify(player, "finished", #rooms)
			end
		end
	end
	World.setDoor(room.exit, true)
	setState(room, "Open", Config.OPEN)
end

-- Fin du temps d'ouverture : ceux qui traînent encore dans la salle sont posés dans le couloir suivant.
local function close(room)
	for _, player in playersIn(room) do
		if room.participants[player] then
			player.Character:PivotTo(CFrame.new(World.sasCenter(room.index)))
		end
	end
	toIdle(room)
end

local function update(room, dt: number)
	if room.state == "Idle" then
		if #playersIn(room) > 0 then
			setState(room, "Countdown", Config.PREPARE)
		end
	elseif room.state == "Countdown" then
		room.t -= dt
		if #playersIn(room) == 0 then
			toIdle(room)
		elseif room.t <= 0 then
			begin(room)
		end
	elseif room.state == "Event" then
		room.elapsed += dt
		-- Un mort est retiré par « Died » (qui donne aussi la moitié des pièces) ; ici, seulement ceux qui sont
		-- partis du jeu ou sortis de la salle.
		for player in room.participants do
			local _, root = body(player)
			if not player:IsDescendantOf(Players) or (root and not inside(room, root.Position)) then
				room.participants[player] = nil
			end
		end
		if next(room.participants) == nil then
			stopEvents(room)
			toIdle(room)
			return
		end
		local solved, failed = false, false
		for _, event in room.events do
			event.update(dt, room.elapsed)
			solved = solved or (event.solved ~= nil and event.solved())
		end
		if solved then
			-- Casse-tête réussi : la porte s'ouvre sans attendre la fin du temps.
			win(room)
		elseif room.elapsed >= Config.DURATION then
			for _, event in room.events do
				failed = failed or (event.timeout ~= nil and event.timeout())
			end
			if failed then
				-- Casse-tête pas fini à temps : tout le monde est éliminé.
				for player in room.participants do
					local humanoid = body(player)
					if humanoid then
						room.eliminated[player] = true
						humanoid.Health = 0
					end
				end
				stopEvents(room)
				toIdle(room)
			else
				win(room)
			end
		end
	elseif room.state == "Open" then
		room.t -= dt
		local remaining = false
		for _, player in playersIn(room) do
			remaining = remaining or room.participants[player] == true
		end
		if room.t <= 0 or not remaining then
			close(room)
		end
	end
end

local function create(geometry)
	local room = geometry
	room.state = "Idle"
	room.t = 0
	room.elapsed = 0
	room.participants = {}
	room.connections = {}
	room.eliminated = {} -- [joueur] = éliminé par la salle elle-même (pas de pièces de consolation)
	room.events = {}

	local parameters = RaycastParams.new()
	parameters.FilterType = Enum.RaycastFilterType.Include
	parameters.FilterDescendantsInstances = { room.static }

	local ctx = {
		room = room,
		static = room.static,
		effects = room.effects,
		center = room.center,
		halfX = World.ROOM_HALF_X,
		halfZ = World.ROOM_HALF_Z,
		liquidY = -2,
	}
	-- Participants encore en vie : { player, humanoid, root }.
	function ctx.players()
		local list = {}
		for player in room.participants do
			local humanoid, root = body(player)
			if humanoid then
				table.insert(list, { player = player, humanoid = humanoid, root = root })
			end
		end
		return list
	end
	function ctx.damage(player: Player, amount: number, _kind: string?)
		local humanoid = body(player)
		if humanoid and room.participants[player] then
			humanoid:TakeDamage(amount)
		end
	end
	-- Élimine le joueur sans pièces de consolation (bombe qui explose).
	function ctx.eliminate(player: Player)
		local humanoid = body(player)
		if humanoid and room.participants[player] then
			room.eliminated[player] = true
			humanoid.Health = 0
		end
	end
	function ctx.notify(player: Player, key: string, ...)
		notify(player, key, ...)
	end
	function ctx.force(player: Player): number
		return Stats.force(player)
	end
	function ctx.kill(player: Player)
		local humanoid = body(player)
		if humanoid and room.participants[player] then
			humanoid.Health = 0
		end
	end
	-- Hauteur d'où tombent les météorites (le plafond qui tombe la remplace par la sienne).
	function ctx.topY()
		return math.min(room.height, 70)
	end
	-- Hauteur du sol, d'un pilier ou de la lave à cet endroit.
	function ctx.surface(x: number, z: number): number
		local origin = Vector3.new(x, ctx.topY() - 0.5, z)
		local hit = workspace:Raycast(origin, Vector3.new(0, -400, 0), parameters)
		return math.max(if hit then hit.Position.Y else 0, ctx.liquidY)
	end

	for _, name in room.def.events do
		table.insert(room.events, EVENTS[name].new(ctx, room.def[name]))
	end
	return room
end

-- Un appui sur E d'un joueur : repousse le plafond de sa salle, s'il y en a un.
function Rooms.push(player: Player, unlimited: boolean?): boolean
	local room = rooms[player:GetAttribute("Room") or 0]
	if room and room.state == "Event" and room.push and room.participants[player] and body(player) then
		return room.push(player, room.elapsed, unlimited)
	end
	return false
end

-- Numéro de la salle où se trouve ce point (0 = aucune).
function Rooms.at(position: Vector3): number
	for _, room in rooms do
		if inside(room, position) then
			return room.index
		end
	end
	return 0
end

function Rooms.get(index: number)
	return rooms[index]
end

function Rooms.start(world, notifier)
	notify = notifier
	for index, geometry in world.rooms do
		rooms[index] = create(geometry)
	end
	RunService.Heartbeat:Connect(function(dt)
		local scaled = math.min(dt, 0.1) * Rooms.timeScale
		for _, room in rooms do
			update(room, scaled)
		end
	end)
	-- Attribut « Room » de chaque joueur : la salle où il est (pour son écran).
	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				local _, root = body(player)
				local index = if root then Rooms.at(root.Position) else 0
				if player:GetAttribute("Room") ~= index then
					player:SetAttribute("Room", index)
				end
			end
			task.wait(0.2)
		end
	end)
end

return Rooms

-- LES ALLÉES DU ZOO, en réseau : des carrefours (Config.PATH_NODES) reliés par des allées (Config.PATH_EDGES). On y
-- ajoute un point pour chaque endroit où l'on s'arrête (le belvédère d'une parcelle, l'entrée du café) : la parcelle
-- est alors « sur » l'allée. Les visiteurs et le personnel prennent toujours le plus court chemin (Dijkstra).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Paths = {}

local nodes = {} -- { pos, links = { [autre point] = distance } }

local function link(a: number, b: number)
	local distance = (nodes[a].pos - nodes[b].pos).Magnitude
	nodes[a].links[b] = distance
	nodes[b].links[a] = distance
end

function Paths.build()
	table.clear(nodes)
	for index, position in Config.PATH_NODES do
		nodes[index] = { pos = position, links = {} }
	end
	for _, edge in Config.PATH_EDGES do
		link(edge[1], edge[2])
	end
end

function Paths.position(index: number): Vector3
	return nodes[index].pos
end

-- Ajoute un point sur l'allée la plus proche de `position` (coupée en deux) ; renvoie son numéro.
function Paths.attach(position: Vector3): number
	local bestA, bestB, bestT, bestDistance = nil, nil, 0, math.huge
	for a, node in nodes do
		for b in node.links do
			if a < b then
				local from, to = node.pos, nodes[b].pos
				local along = to - from
				local t = math.clamp((position - from):Dot(along) / along:Dot(along), 0, 1)
				local point = from + along * t
				local distance = (Vector3.new(position.X - point.X, 0, position.Z - point.Z)).Magnitude
				if distance < bestDistance then
					bestA, bestB, bestT, bestDistance = a, b, t, distance
				end
			end
		end
	end
	if not bestA then
		return Config.PATH_START
	end
	local from, to = nodes[bestA].pos, nodes[bestB].pos
	if (from - to).Magnitude * bestT < 1 then
		return bestA
	elseif (from - to).Magnitude * (1 - bestT) < 1 then
		return bestB
	end
	local index = #nodes + 1
	nodes[index] = { pos = from + (to - from) * bestT, links = {} }
	nodes[bestA].links[bestB] = nil
	nodes[bestB].links[bestA] = nil
	link(bestA, index)
	link(index, bestB)
	return index
end

-- Le point du réseau le plus proche (à vol d'oiseau).
function Paths.nearest(position: Vector3): number
	local best, bestDistance = Config.PATH_START, math.huge
	for index, node in nodes do
		local distance = (Vector3.new(position.X - node.pos.X, 0, position.Z - node.pos.Z)).Magnitude
		if distance < bestDistance then
			best, bestDistance = index, distance
		end
	end
	return best
end

-- Le plus court chemin d'un point à un autre : la longueur, et les positions à suivre (sans le départ).
local function search(from: number, to: number): (number, { number })
	local distance, previous, done = { [from] = 0 }, {}, {}
	while true do
		local current, best = nil, math.huge
		for index, value in distance do
			if not done[index] and value < best then
				current, best = index, value
			end
		end
		if not current or current == to then
			break
		end
		done[current] = true
		for other, length in nodes[current].links do
			local candidate = best + length
			if candidate < (distance[other] or math.huge) then
				distance[other] = candidate
				previous[other] = current
			end
		end
	end
	local steps = {}
	local index = to
	while index and index ~= from do
		table.insert(steps, 1, index)
		index = previous[index]
	end
	return distance[to] or math.huge, steps
end

-- Les distances entre tous les points, calculées une fois (après les Paths.attach).
local distances = nil
function Paths.prepare()
	distances = {}
	for a in nodes do
		distances[a] = {}
		for b in nodes do
			distances[a][b] = if a == b then 0 else math.huge
		end
		for b, length in nodes[a].links do
			distances[a][b] = length
		end
	end
	for k in nodes do
		for a in nodes do
			local ak = distances[a][k]
			if ak < math.huge then
				for b in nodes do
					local candidate = ak + distances[k][b]
					if candidate < distances[a][b] then
						distances[a][b] = candidate
					end
				end
			end
		end
	end
end

function Paths.distance(from: number, to: number): number
	if from == to then
		return 0
	end
	if distances and distances[from] and distances[from][to] then
		return distances[from][to]
	end
	return (search(from, to))
end

function Paths.route(from: number, to: number): { Vector3 }
	local _, steps = search(from, to)
	local points = {}
	for _, index in steps do
		table.insert(points, nodes[index].pos)
	end
	return points
end

return Paths

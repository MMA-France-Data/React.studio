-- Imitations minimales des objets de Roblox (Vector3, Color3, CFrame, script) pour charger les
-- VRAIS modules de src/shared hors de Studio, avec la commande `luau`.
-- run.ps1 copie chaque module dans gen/shared/ en ajoutant au début de sa première ligne :
--   local __shim = require("../../shim"); local Vector3, Color3, CFrame, script = ...
-- (les numéros de ligne des erreurs restent donc les mêmes que dans src/shared).
local Shim = {}

----------------------------------------------------------------------
-- Vector3 : X, Y, Z, + - * /, Magnitude, Unit
----------------------------------------------------------------------
local Vector3 = {}
local vectorMeta = {}

local function newVector(x: number?, y: number?, z: number?)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, vectorMeta)
end

vectorMeta.__index = function(v, key)
	if key == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif key == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		return newVector(v.X / m, v.Y / m, v.Z / m)
	end
	return Vector3[key]
end
vectorMeta.__add = function(a, b)
	return newVector(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
vectorMeta.__sub = function(a, b)
	return newVector(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
vectorMeta.__mul = function(a, b)
	if type(a) == "number" then
		return newVector(b.X * a, b.Y * a, b.Z * a)
	elseif type(b) == "number" then
		return newVector(a.X * b, a.Y * b, a.Z * b)
	end
	return newVector(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
vectorMeta.__div = function(a, b)
	if type(b) == "number" then
		return newVector(a.X / b, a.Y / b, a.Z / b)
	end
	return newVector(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
vectorMeta.__unm = function(a)
	return newVector(-a.X, -a.Y, -a.Z)
end
vectorMeta.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
vectorMeta.__tostring = function(a)
	return `{a.X}, {a.Y}, {a.Z}`
end

Vector3.new = newVector
Vector3.zero = newVector(0, 0, 0)
Vector3.one = newVector(1, 1, 1)
Vector3.xAxis = newVector(1, 0, 0)
Vector3.yAxis = newVector(0, 1, 0)
Vector3.zAxis = newVector(0, 0, 1)

function Vector3.Dot(a, b)
	return a.X * b.X + a.Y * b.Y + a.Z * b.Z
end

function Vector3.Cross(a, b)
	return newVector(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
end

function Vector3.Lerp(a, b, alpha)
	return a + (b - a) * alpha
end

Shim.Vector3 = Vector3

----------------------------------------------------------------------
-- Color3 : juste de quoi construire les couleurs des modules (jamais affichées ici)
----------------------------------------------------------------------
Shim.Color3 = {
	new = function(r, g, b)
		return { R = r or 0, G = g or 0, B = b or 0 }
	end,
	fromRGB = function(r, g, b)
		return { R = (r or 0) / 255, G = (g or 0) / 255, B = (b or 0) / 255 }
	end,
	fromHSV = function(h, s, v)
		return { R = v, G = v, B = v, H = h, S = s }
	end,
}

----------------------------------------------------------------------
-- CFrame : translation seulement (la rotation est ignorée). Le simulateur n'en a pas besoin :
-- la distance horizontale entre une tour et un ennemi est la même en coordonnées locales de la parcelle.
----------------------------------------------------------------------
local CFrame = {}
local cframeMeta = {}
cframeMeta.__index = CFrame

local function newCFrame(position)
	return setmetatable({ Position = position }, cframeMeta)
end

function CFrame.new(x, y, z)
	if type(x) == "table" then
		return newCFrame(x)
	end
	return newCFrame(newVector(x, y, z))
end

function CFrame.lookAt(position)
	return newCFrame(position)
end

function CFrame:PointToWorldSpace(v)
	return self.Position + v
end

function CFrame:PointToObjectSpace(v)
	return v - self.Position
end

cframeMeta.__mul = function(a, b)
	if getmetatable(b) == cframeMeta then
		return newCFrame(a.Position + b.Position)
	end
	return a.Position + b
end

Shim.CFrame = CFrame

----------------------------------------------------------------------
-- script.Parent.X -> chemin "./X" : le module le passe à require, qui le résout depuis son dossier
-- (gen/shared/), donc tous les modules partagent la même copie (cache de require).
----------------------------------------------------------------------
Shim.script = {
	Parent = setmetatable({}, {
		__index = function(_, name)
			return "./" .. name
		end,
	}),
}

return Shim

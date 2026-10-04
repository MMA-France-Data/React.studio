-- Imitations de Roblox pour charger les VRAIS modules du serveur des niveaux (Combat.luau, LevelGame.luau,
-- CampGame.luau) hors de Studio, avec la commande `luau` (voir run.ps1). Les Vector3 / CFrame viennent de shim.luau.
-- run.ps1 copie chaque module dans gen/ en ajoutant ces imitations au début de sa première ligne (les numéros de
-- ligne des erreurs restent ceux de src/).
local Env = {}

-- Objet Roblox minimal : nom, parent, attributs, Destroy.
local function fakeInstance(name: string?)
	local instance = { Name = name or "Instance", Parent = nil, _attributes = {} }
	function instance:SetAttribute(key, value)
		self._attributes[key] = value
	end
	function instance:GetAttribute(key)
		return self._attributes[key]
	end
	function instance:Destroy()
		self.destroyed = true
	end
	function instance:FindFirstChild()
		return nil
	end
	return instance
end
Env.fakeInstance = fakeInstance

Env.Instance = {
	new = function(className)
		return fakeInstance(className)
	end,
}

-- ReplicatedStorage:WaitForChild("Shared").X -> chemin "../../shared/X" (depuis gen/server/Hub).
local sharedFolder = setmetatable({}, {
	__index = function(_, name)
		return "../../shared/" .. name
	end,
})

Env.game = {
	GetService = function(_, name)
		if name == "ReplicatedStorage" then
			return {
				WaitForChild = function(_, child)
					assert(child == "Shared")
					return sharedFolder
				end,
				FindFirstChild = function()
					return nil
				end,
			}
		end
		return {}
	end,
}

Env.workspace = {
	GetServerTimeNow = function()
		return os.clock()
	end,
}

-- script.Parent.X -> "./X" (dossier Hub), script.Parent.Parent.X -> "../X" (dossier server).
Env.serverScript = {
	Parent = setmetatable({
		Parent = setmetatable({}, {
			__index = function(_, name)
				return "../" .. name
			end,
		}),
	}, {
		__index = function(_, name)
			return "./" .. name
		end,
	}),
}

-- Random de Roblox, en REPRODUCTIBLE : chaque Random.new(graine) donne toujours la même suite (graine absente : la
-- même pour tous). Les tests et les réglages rejouent ainsi exactement les mêmes parties (couloir des gros monstres
-- en équipe : Levels.buildQueue). Générateur « minimal standard » (Park-Miller) : calculs exacts en nombres Luau.
local randomMeta = {}
randomMeta.__index = randomMeta
function randomMeta:NextNumber()
	self.state = (self.state * 48271) % 2147483647
	return self.state / 2147483647
end
function randomMeta:NextInteger(min: number, max: number): number
	return math.min(max, min + math.floor(self:NextNumber() * (max - min + 1)))
end
Env.Random = {
	new = function(seed: number?)
		local random = setmetatable({ state = math.floor(tonumber(seed) or 20261004) % 2147483646 + 1 }, randomMeta)
		for _ = 1, 4 do
			random:NextNumber() -- (une petite graine donne d'abord de tout petits nombres : ils sont passés)
		end
		return random
	end,
}

Env.task = {
	spawn = function() end,
	delay = function() end,
}

return Env

-- Imitations de Roblox en plus de shim.luau, pour charger le VRAI PlotGame.luau (serveur) hors de Studio.
-- Seulement pour la vérification du moteur (run.ps1 -Verifier) : PlotGame et le moteur du simulateur
-- jouent les mêmes vagues et doivent donner les mêmes résultats (verif/parity.luau).
-- run.ps1 copie PlotGame dans gen/verif/server/Hub/ en ajoutant ces imitations au début de sa 1re ligne.
local Extra = {}

-- Objet Roblox minimal : attributs, Destroy.
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
	return instance
end
Extra.fakeInstance = fakeInstance

Extra.Instance = {
	new = function(className)
		return fakeInstance(className)
	end,
}

-- ReplicatedStorage:WaitForChild("Shared").X -> chemin "../../shared/X" (depuis gen/verif/server/Hub).
local sharedFolder = setmetatable({}, {
	__index = function(_, name)
		return "../../shared/" .. name
	end,
})

Extra.game = {
	GetService = function(_, name)
		if name == "ReplicatedStorage" then
			return {
				WaitForChild = function(_, child)
					assert(child == "Shared")
					return sharedFolder
				end,
			}
		end
		return {}
	end,
}

Extra.workspace = {
	GetServerTimeNow = function()
		return os.clock()
	end,
}

-- script.Parent.X -> "./X" (dossier Hub), script.Parent.Parent.X -> "../X" (dossier server).
Extra.serverScript = {
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

local randomMeta = {}
randomMeta.__index = randomMeta
function randomMeta:NextNumber()
	return math.random()
end
Extra.Random = {
	new = function()
		return setmetatable({}, randomMeta)
	end,
}

Extra.task = {
	spawn = function() end,
	delay = function() end,
}

return Extra

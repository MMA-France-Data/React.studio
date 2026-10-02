-- Imitation de Hub/IdleTowerModel.luau hors de Studio : un modèle de tour = un objet à attributs.
local Env = require("../../../env")

return {
	create = function(towerType, _cframe, _parent, attributes)
		local model = Env.fakeInstance(towerType)
		for key, value in attributes do
			model:SetAttribute(key, value)
		end
		model:SetAttribute("TowerType", towerType)
		return model
	end,
}

-- Imitation de Hub/IdleTowerModel.luau pour la vérification du moteur : un modèle = un objet à attributs.
local Extra = require("../../../../verif/extra")

return {
	create = function(towerType, _cframe, _parent, attributes)
		local model = Extra.fakeInstance(towerType)
		for key, value in attributes do
			model:SetAttribute(key, value)
		end
		model:SetAttribute("TowerType", towerType)
		return model
	end,
}

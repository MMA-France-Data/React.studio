-- Imitation de Remotes.luau pour la vérification du moteur : les messages aux clients ne vont nulle part.
return {
	get = function()
		return { FireClient = function() end, FireAllClients = function() end }
	end,
}

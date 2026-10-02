-- Imitation de Remotes.luau hors de Studio : les messages aux clients ne vont nulle part.
return {
	get = function()
		return { FireClient = function() end, FireAllClients = function() end }
	end,
}

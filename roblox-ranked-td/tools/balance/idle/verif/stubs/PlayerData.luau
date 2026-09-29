-- Imitation de PlayerData.luau pour la vérification du moteur : les pièces vont dans player.__data.
return {
	addCoins = function(player, amount)
		player.__data.coins += amount
	end,
	save = function() end,
}

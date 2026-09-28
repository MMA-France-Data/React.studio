local Config = require(script.Parent.Config)

local Ranks = {}

-- Paliers triés par MMR minimum croissant.
Ranks.List = {
	{ name = "Bronze", min = 0, color = Color3.fromRGB(176, 112, 64) },
	{ name = "Argent", min = 900, color = Color3.fromRGB(192, 200, 210) },
	{ name = "Or", min = 1150, color = Color3.fromRGB(245, 196, 60) },
	{ name = "Platine", min = 1400, color = Color3.fromRGB(80, 210, 190) },
	{ name = "Diamant", min = 1650, color = Color3.fromRGB(110, 160, 255) },
	{ name = "Maître", min = 1900, color = Color3.fromRGB(190, 100, 255) },
	{ name = "Légende", min = 2200, color = Color3.fromRGB(255, 80, 90) },
}

function Ranks.get(mmr: number)
	local current = Ranks.List[1]
	for _, rank in Ranks.List do
		if mmr >= rank.min then
			current = rank
		end
	end
	return current
end

function Ranks.isPlacement(gamesPlayed: number): boolean
	return gamesPlayed < Config.Ranked.PLACEMENT_GAMES
end

-- Texte affiché au joueur (les joueurs en placement ne voient pas encore leur rang).
function Ranks.label(mmr: number, gamesPlayed: number): string
	if Ranks.isPlacement(gamesPlayed) then
		return string.format("Placement %d/%d", gamesPlayed, Config.Ranked.PLACEMENT_GAMES)
	end
	return Ranks.get(mmr).name
end

function Ranks.color(mmr: number, gamesPlayed: number): Color3
	if Ranks.isPlacement(gamesPlayed) then
		return Color3.fromRGB(170, 170, 170)
	end
	return Ranks.get(mmr).color
end

return Ranks

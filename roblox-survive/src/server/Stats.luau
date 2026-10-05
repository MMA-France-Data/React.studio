-- Les chiffres d'un joueur : vitesse, saut, force. Tout est lu dans les attributs du joueur (posés par PlayerData).
-- (Les familiers ne donnent plus de bonus : ils rapportent des pièces, voir Eggs.luau.)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Stats = {}

function Stats.walkSpeed(player: Player): number
	return Config.walkSpeed(player:GetAttribute("Speed") or 0)
end

function Stats.jumpHeight(player: Player): number
	return Config.jumpHeight(player:GetAttribute("Jump") or 0)
end

function Stats.force(player: Player): number
	return Config.force(player:GetAttribute("Force") or 0)
end

return Stats

-- Les chiffres d'un joueur une fois son animal compté : vitesse, force, pièces gagnées, bouclier.
-- Tout est lu dans les attributs du joueur (posés par PlayerData).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Pets = require(ReplicatedStorage.Shared.Pets)

local Stats = {}

-- Force du pouvoir `power` de l'animal équipé (0 si l'animal équipé a un autre pouvoir, ou s'il n'y en a pas).
function Stats.bonus(player: Player, power: string): number
	local def = Pets.DEFS[player:GetAttribute("Pet") or ""]
	if def and def.power == power then
		return Pets.value(player:GetAttribute("Pet"), player:GetAttribute("PetRarity") or 1)
	end
	return 0
end

function Stats.walkSpeed(player: Player): number
	return Config.walkSpeed(player:GetAttribute("Speed") or 1) * (1 + Stats.bonus(player, "speed") / 100)
end

function Stats.jumpHeight(player: Player): number
	return Config.jumpHeight(player:GetAttribute("Jump") or 1)
end

function Stats.force(player: Player): number
	return Config.force(player:GetAttribute("Force") or 1) + Stats.bonus(player, "force")
end

function Stats.coins(player: Player, amount: number): number
	return math.floor(amount * (1 + Stats.bonus(player, "coins") / 100) + 0.5)
end

return Stats

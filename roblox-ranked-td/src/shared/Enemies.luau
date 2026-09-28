local Enemies = {}

-- Ordre fixe : sert à encoder le type d'ennemi sur 1 octet dans les paquets réseau.
Enemies.ORDER = { "Normal", "Fast", "Tank", "Boss", "Swarm", "Giant" }

Enemies.Defs = {
	Normal = { displayName = "Soldat", health = 90, speed = 8, damage = 1, reward = 4, size = 2, color = Color3.fromRGB(220, 70, 70) },
	Fast = { displayName = "Éclaireur", health = 55, speed = 14, damage = 1, reward = 5, size = 1.6, color = Color3.fromRGB(250, 220, 70) },
	Tank = { displayName = "Blindé", health = 420, speed = 5, damage = 3, reward = 14, size = 3, color = Color3.fromRGB(110, 110, 120) },
	Boss = { displayName = "Titan", health = 3500, speed = 3.5, damage = 20, reward = 120, size = 5, color = Color3.fromRGB(150, 40, 200) },
	-- Utilisés par les vagues du mode infini
	Swarm = { displayName = "Nuée", health = 30, speed = 12, damage = 1, reward = 1, size = 1.2, color = Color3.fromRGB(120, 230, 90) },
	Giant = { displayName = "Géant", health = 2000, speed = 3, damage = 8, reward = 40, size = 4.5, color = Color3.fromRGB(140, 95, 60) },
}

-- Les ennemis deviennent plus résistants à chaque vague, puis très vite après la vague 20
-- pour que les matchs finissent toujours.
function Enemies.healthMultiplier(wave: number): number
	local late = math.max(0, wave - 20)
	return 1 + 0.15 * (wave - 1) + 0.05 * late * late
end

-- Composition d'une vague : liste de { enemy, gap } (gap = secondes avant l'ennemi suivant).
-- Les deux joueurs reçoivent exactement la même vague.
function Enemies.buildWave(wave: number)
	local list = {}
	local function add(enemyType: string, count: number, gap: number)
		for _ = 1, count do
			table.insert(list, { enemy = enemyType, gap = gap })
		end
	end

	add("Normal", 5 + wave * 2, 0.7)
	if wave >= 3 then
		add("Fast", math.floor(wave * 1.2), 0.45)
	end
	if wave >= 5 then
		add("Tank", math.floor((wave - 3) / 2), 1.2)
	end
	if wave % 10 == 0 then
		add("Boss", wave // 10, 2)
	end
	return list
end

return Enemies

--!native
--!optimize 2
-- Moteur de combat du simulateur : reproduit PlotGame:step (src/server/Hub/PlotGame.luau) à pas fixe.
--   apparitions (écarts de la vague, MAX_ENEMIES) -> déplacements (vitesse x ENEMY_SPEED_MULTIPLIER x facteur
--   du type d'ennemi, ralentissements) -> tirs des tours (dans l'ordre des emplacements) -> retrait des morts
--   -> fin de vague (UN SEUL ennemi au bout du chemin = vague ratée, pas de PV de base ; plus rien à faire
--   apparaître et plus d'ennemi = vague réussie).
-- Ralentissements comme applySlow dans PlotGame : ils ne s'additionnent pas, le plus fort gagne, un égal
-- prolonge, un plus faible est ignoré tant que l'actuel dure.
-- Deux usages :
--   Engine.runWave(comp, tours)  : vraie vague (les ennemis meurent, pièces, fuites vers la base)
--   Engine.hits(comp, tours)     : vague « immortelle » : les ennemis ne meurent jamais et on compte les coups
--                                  que chaque tour peut porter à chaque groupe d'ennemis. Le joueur simulé s'en
--                                  sert pour estimer ce que rapporte un achat (portée, zone, cibles, ralentis).
-- Différences voulues avec le jeu : pas de temps fixe (Engine.DT, 0,05 s) au lieu de ~1/60 s variable, petite
-- marge (1e-9) sur les temps de recharge et d'apparition pour éviter les erreurs d'arrondi, recharge des tours
-- remise à 0 au début de chaque vague (dans le jeu, une tour garde sa recharge d'une vague à l'autre : au pire
-- quelques secondes de retard sur son premier tir). Les temps de recharge des tours (0,2 / 0,25 / 0,8 / 1 / 1,2 /
-- 1,8 / 4 / 5 s, et leur moitié avec le bonus x2 vitesse) sont des multiples de 0,05 s, sauf 0,125 s (Sorcier
-- des arcanes avec x2 vitesse) : il tire alors toutes les 0,15 s au lieu de ~0,133 s dans le jeu (11 % de moins).
-- Les résultats changent de moins de 10 % entre des pas de 0,1 s, 0,05 s et 1/60 s.
local Modules = require("./Modules")
local IdleConfig = Modules.IdleConfig
local IdleTowers = Modules.IdleTowers
local PlotLayout = Modules.PlotLayout
local Enemies = Modules.Enemies

local Engine = {}

Engine.DT = 0.05 -- pas de la vraie simulation (s)
Engine.HITS_DT = 0.1 -- pas des vagues « immortelles » (estimations seulement)

local EPS = 1e-9
local MAX_ENEMIES = IdleConfig.MAX_ENEMIES
local SPEED_MULTIPLIER = IdleConfig.ENEMY_SPEED_MULTIPLIER

-- Vitesse d'un ennemi sur les parcelles (studs/s, sans ralentissement), comme PlotGame : vitesse de
-- Enemies.luau x ENEMY_SPEED_MULTIPLIER x facteur de son type (IdleConfig.enemySpeedFactor).
function Engine.enemySpeed(name: string): number
	return Enemies.Defs[name].speed * SPEED_MULTIPLIER * IdleConfig.enemySpeedFactor(name)
end

----------------------------------------------------------------------
-- Chemin précalculé (mêmes calculs que PlotLayout.pointAt, sans créer de Vector3)
----------------------------------------------------------------------
local PATH = PlotLayout.PATH
local PX, PZ, CUM, DIRX, DIRZ = {}, {}, {}, {}, {}
for i, point in PATH do
	PX[i], PZ[i] = point.X, point.Z
end
CUM[1] = 0
for i = 2, #PATH do
	local segment = PATH[i] - PATH[i - 1]
	CUM[i] = CUM[i - 1] + segment.Magnitude
	local unit = segment.Unit
	DIRX[i], DIRZ[i] = unit.X, unit.Z
end
local PATH_LENGTH = PlotLayout.PATH_LENGTH
Engine.PATH_LENGTH = PATH_LENGTH

----------------------------------------------------------------------
-- Composition d'une vague (IdleConfig.buildWave), regroupée par type d'ennemi
----------------------------------------------------------------------
local compositionCache = {}

-- forcedType : construit la vague `wave` comme si elle était de ce type (banc d'essai des tours).
function Engine.composition(wave: number, forcedType: string?)
	local cacheKey = (forcedType or "") .. "#" .. wave
	local cached = compositionCache[cacheKey]
	if cached then
		return cached
	end

	local waveType = forcedType or IdleConfig.waveType(wave)
	local list
	if forcedType then
		local original = IdleConfig.waveType
		IdleConfig.waveType = function()
			return forcedType
		end
		list = IdleConfig.buildWave(wave)
		IdleConfig.waveType = original
	else
		list = IdleConfig.buildWave(wave)
	end

	local groups, groupOf, items = {}, {}, {}
	local at = 0
	for i, item in list do
		local groupKey = item.enemy .. "@" .. item.health
		local g = groupOf[groupKey]
		if not g then
			g = #groups + 1
			groupOf[groupKey] = g
			groups[g] = {
				name = item.enemy,
				count = 0,
				hp = item.health,
				reward = item.reward,
				speed = Engine.enemySpeed(item.enemy),
			}
		end
		local group = groups[g]
		group.count += 1
		items[i] = { g = g, at = at, hp = item.health, reward = item.reward, speed = group.speed }
		at += item.gap
	end

	local totalHp, totalReward, parts = 0, 0, {}
	for g, group in groups do
		-- PV à infliger à tout le groupe : une seule fuite fait rater la vague, chaque ennemi doit tomber.
		group.need = group.count * group.hp
		totalHp += group.need
		totalReward += group.count * group.reward
		parts[g] = group.name .. group.count
	end

	local comp = {
		wave = wave,
		waveType = waveType,
		items = items,
		groups = groups,
		-- Pas de PV de base : un seul ennemi qui passe suffit, toutes les vagues peuvent être ratées.
		failable = true,
		totalHp = totalHp,
		totalReward = totalReward,
		-- Même clé = mêmes coups portés en vague immortelle (les PV relatifs des groupes ne changent pas).
		key = waveType .. ":" .. table.concat(parts, ","),
	}
	compositionCache[cacheKey] = comp
	return comp
end

----------------------------------------------------------------------
-- Tours
----------------------------------------------------------------------
local KIND = { Single = 1, Splash = 2, Aura = 3, Chain = 4 }

-- Une tour posée, avec ses stats finales (IdleTowers.effectiveStats : niveau, doublons, bonus).
function Engine.compileTower(spot: number, towerType: string, level: number, dupes: number?, bonus: string?)
	local stats = IdleTowers.effectiveStats(towerType, level, dupes, bonus)
	local position = PlotLayout.SPOTS[spot]
	local kind = KIND[stats.kind]
	assert(kind, `type de tour inconnu pour le simulateur : {stats.kind}`)
	return {
		spot = spot,
		type = towerType,
		x = position.X,
		z = position.Z,
		kind = kind,
		strongest = stats.targeting == "Strongest",
		damage = stats.damage,
		cooldown = stats.cooldown,
		range2 = stats.range * stats.range,
		splash2 = (stats.splash or 0) * (stats.splash or 0),
		slow = stats.slow,
		slowDuration = stats.slowDuration or 0,
		chains = stats.chains or 1,
		cd = 0,
	}
end

----------------------------------------------------------------------
-- Boucle de simulation
----------------------------------------------------------------------
local function byDistanceDesc(a, b)
	return a.dist > b.dist
end

-- Même règle que applySlow (PlotGame.luau) : le plus fort gagne, un égal prolonge, un plus faible est
-- ignoré tant que l'actuel dure.
local function applySlow(enemy, slow: number, duration: number, now: number)
	if now >= enemy.slowUntil or slow > enemy.slowFactor then
		enemy.slowFactor = slow
		enemy.slowUntil = now + duration
	elseif slow == enemy.slowFactor then
		local untilTime = now + duration
		if untilTime > enemy.slowUntil then
			enemy.slowUntil = untilTime
		end
	end
end

-- immortal = true : les ennemis ne perdent pas de PV, hitsOut[i][g] compte les coups de la tour i.
-- Sinon usefulOut[i] cumule les dégâts utiles de la tour i (sans les dégâts perdus sur un ennemi déjà presque mort).
-- baseMode : nil = comme le jeu (vague ratée dès la première fuite ; la simulation continue quand même jusqu'au
--                  bout pour savoir QUI aurait fui, mais le temps, les pièces et les dégâts rendus sont ceux
--                  du moment de la première fuite, comme dans le jeu) ;
--            "ignore" = la vague va jusqu'au bout (success dit si aucun ennemi n'a fui, leakScore de combien) ;
--            "strict" = s'arrête à la première fuite (plus rapide : banc d'essai des tours).
local function simulate(comp, towers, immortal: boolean, dt: number, hitsOut, usefulOut, leakOut, baseMode: string?)
	local items = comp.items
	local nItems = #items
	local nTowers = #towers
	local enemies = {}
	local n = 0
	local spawnIndex = 1
	local stopAtLeak = baseMode == "strict"
	local leaked = false
	local leakStep, leakCoins, leakUseful = nil, nil, nil
	local coins = 0
	local removed = 0
	local step = 0
	local leakScore = 0

	for i = 1, nTowers do
		towers[i].cd = 0
	end

	local function hitEnemy(enemy, amount: number, towerIndex: number)
		if immortal then
			local row = hitsOut[towerIndex]
			row[enemy.g] += 1
			return
		end
		if enemy.dead then
			return
		end
		local hp = enemy.hp
		usefulOut[towerIndex] += if amount < hp then amount else hp
		hp -= amount
		enemy.hp = hp
		if hp <= 0 then
			enemy.dead = true
			removed += 1
			coins += enemy.reward
		end
	end

	while true do
		step += 1
		if step > 2000000 then
			error("vague trop longue : simulation bloquée ?")
		end
		local now = step * dt

		-- Apparitions
		while spawnIndex <= nItems and n < MAX_ENEMIES do
			local item = items[spawnIndex]
			if item.at > now + EPS then
				break
			end
			spawnIndex += 1
			n += 1
			enemies[n] = {
				g = item.g,
				hp = item.hp,
				maxHp = item.hp,
				reward = item.reward,
				speed = item.speed,
				dist = 0,
				seg = 2,
				x = PX[1],
				z = PZ[1],
				slowUntil = 0,
				slowFactor = 0,
				dead = false,
			}
		end

		-- Déplacements
		for i = 1, n do
			local enemy = enemies[i]
			if not enemy.dead then
				local speed = enemy.speed
				if now < enemy.slowUntil then
					speed *= 1 - enemy.slowFactor
				end
				local distance = enemy.dist + speed * dt
				enemy.dist = distance
				if distance >= PATH_LENGTH then
					enemy.dead = true
					removed += 1
					if not immortal then
						-- Une seule fuite = vague ratée (PlotGame:step s'arrête là, les tours ne tirent plus).
						if not leaked then
							leaked = true
							leakStep, leakCoins = step, coins
							if usefulOut then
								leakUseful = table.clone(usefulOut)
							end
						end
						if stopAtLeak then
							return false, step, coins, 0, step, coins, nil
						end
						if leakOut then
							-- Nombre d'ennemis de ce groupe qui auraient fui
							leakOut[enemy.g] += 1
							-- Écart au succès, continu : un ennemi arrivé à la base avec 10 % de ses PV compte
							-- 0,1 (sert à comparer des achats quand la vague est ratée).
							leakScore += enemy.hp / enemy.maxHp
						end
					end
				else
					local seg = enemy.seg
					while distance > CUM[seg] do
						seg += 1
					end
					enemy.seg = seg
					local offset = distance - CUM[seg - 1]
					enemy.x = PX[seg - 1] + DIRX[seg] * offset
					enemy.z = PZ[seg - 1] + DIRZ[seg] * offset
				end
			end
		end

		-- Tours
		for ti = 1, nTowers do
			local tower = towers[ti]
			local cd = tower.cd - dt
			if cd <= EPS then
				local attacked = false
				local tx, tz, range2 = tower.x, tower.z, tower.range2
				local kind = tower.kind
				if kind == 3 then
					-- Aura : ralentit et blesse tout ce qui est à portée
					local slow, slowDuration, damage = tower.slow, tower.slowDuration, tower.damage
					for i = 1, n do
						local enemy = enemies[i]
						if not enemy.dead then
							local dx, dz = enemy.x - tx, enemy.z - tz
							if dx * dx + dz * dz <= range2 then
								attacked = true
								applySlow(enemy, slow, slowDuration, now)
								hitEnemy(enemy, damage, ti)
							end
						end
					end
				elseif kind == 4 then
					-- Chaîne : les N ennemis les plus avancés à portée
					local inRange = nil
					for i = 1, n do
						local enemy = enemies[i]
						if not enemy.dead then
							local dx, dz = enemy.x - tx, enemy.z - tz
							if dx * dx + dz * dz <= range2 then
								inRange = inRange or {}
								table.insert(inRange, enemy)
							end
						end
					end
					if inRange then
						attacked = true
						table.sort(inRange, byDistanceDesc)
						for i = 1, math.min(tower.chains, #inRange) do
							hitEnemy(inRange[i], tower.damage, ti)
						end
					end
				else
					-- Tir simple ou de zone : le plus avancé (First) ou le plus de PV (Strongest)
					local target, bestScore = nil, -math.huge
					local strongest = tower.strongest
					for i = 1, n do
						local enemy = enemies[i]
						if not enemy.dead then
							local dx, dz = enemy.x - tx, enemy.z - tz
							if dx * dx + dz * dz <= range2 then
								local score = if strongest then enemy.hp else enemy.dist
								if score > bestScore then
									target, bestScore = enemy, score
								end
							end
						end
					end
					if target then
						attacked = true
						if kind == 2 then
							local ix, iz, splash2, damage = target.x, target.z, tower.splash2, tower.damage
							for i = 1, n do
								local enemy = enemies[i]
								if not enemy.dead then
									local dx, dz = enemy.x - ix, enemy.z - iz
									if dx * dx + dz * dz <= splash2 then
										hitEnemy(enemy, damage, ti)
									end
								end
							end
						else
							local slow = tower.slow
							if slow then
								applySlow(target, slow, tower.slowDuration, now)
							end
							hitEnemy(target, tower.damage, ti)
						end
					end
				end
				cd = if attacked then tower.cooldown else 0
			end
			tower.cd = cd
		end

		-- Retrait des morts (l'ordre des vivants est gardé, comme table.remove dans le jeu)
		if removed > 0 then
			local j = 0
			for i = 1, n do
				local enemy = enemies[i]
				if not enemy.dead then
					j += 1
					enemies[j] = enemy
				end
			end
			for i = j + 1, n do
				enemies[i] = nil
			end
			n = j
			removed = 0
		end

		if spawnIndex > nItems and n == 0 then
			return not leaked, step, coins, leakScore, leakStep, leakCoins, leakUseful
		end
	end
end

-- Vraie vague. Renvoie { success, steps, seconds, coins (sans bonus de pièces), useful[i], leak[g], leakScore }.
-- baseMode : voir simulate. nil = comme le jeu : vague ratée = arrêtée à la première fuite (seconds, coins et
-- useful sont ceux de ce moment) ; leak[g] = nombre d'ennemis de chaque groupe qui auraient fui en allant
-- jusqu'au bout, leakScore = leurs PV restants (en ennemis entiers ; 0 = aucune fuite).
-- "strict" : s'arrête à la première fuite, sans leak ni leakScore (banc d'essai). dt : Engine.DT par défaut.
function Engine.runWave(comp, towers, baseMode: string?, dt: number?)
	local useful = table.create(#towers, 0)
	local leak = table.create(#comp.groups, 0)
	local step = dt or Engine.DT
	local success, steps, coins, leakScore, leakStep, leakCoins, leakUseful =
		simulate(comp, towers, false, step, nil, useful, leak, baseMode)
	if not success and baseMode == nil and leakStep then
		-- Comme le jeu : la vague s'arrête à la première fuite.
		steps, coins, useful = leakStep, leakCoins, leakUseful or useful
	end
	return {
		success = success,
		steps = steps,
		seconds = steps * step,
		coins = coins,
		useful = useful,
		leak = leak,
		leakScore = leakScore,
	}
end

-- Vague immortelle : hits[i][g] = nombre de coups de la tour i sur le groupe g pendant toute la vague.
function Engine.hits(comp, towers)
	local hits = {}
	for i = 1, #towers do
		hits[i] = table.create(#comp.groups, 0)
	end
	simulate(comp, towers, true, Engine.HITS_DT, hits, nil, nil)
	return hits
end

-- Nombre de pas pour attendre `seconds` (le jeu lance la vague à la première image après l'échéance).
function Engine.delaySteps(seconds: number): number
	return math.ceil(seconds / Engine.DT - EPS)
end

return Engine

--!native
--!optimize 2
-- Moteur de combat du simulateur : reproduit PlotGame:simulate (src/server/Hub/PlotGame.luau) à pas fixe.
--   apparitions (écarts de la vague, MAX_ENEMIES, sortie à chaque mort, vague écrasée) -> déplacements (vitesse x
--   ENEMY_SPEED_MULTIPLIER x facteur du type d'ennemi, contrôle en cours) -> projectiles qui arrivent (dégâts à
--   l'impact) -> tirs des tours (dans l'ordre des emplacements ; rayon du Sorcier à chaque pas) -> zones de feu
--   des flèches -> retrait des morts -> fin de vague (UN SEUL ennemi au bout du chemin = vague ratée, pas de PV
--   de base ; plus rien à faire apparaître et plus d'ennemi = vague réussie).
-- Comme PlotGame :
--   * une mort fait sortir le prochain ennemi tout de suite (IdleConfig.SPAWN_NEXT_ON_KILL) : chaque ennemi tué
--     fait sortir UN ennemi de la file au pas suivant, même si d'autres sont en vie (toute la suite de la file
--     avance d'autant) ; une fuite ne fait rien sortir ;
--   * vague écrasée (IdleConfig.COMPRESS_EMPTY_SPAWNS) : plus AUCUN ennemi en vie, encore des ennemis à faire
--     sortir et aucune mort qui attend son ennemi -> l'attente est sautée, le suivant sort à ce pas (toute la
--     suite de la file avance d'autant) ;
--   * CONTRÔLES (applyControl) : UN SEUL à la fois par ennemi (ralentissement du Totem de givre, du Mage des
--     tempêtes, étourdissement du Trébuchet royal). Le même type de tour prolonge son effet (force inchangée),
--     un autre type est refusé tant que l'effet dure (premier arrivé, premier servi) ;
--   * fragilité du Totem de givre (applyFragility) : +X % de dégâts reçus des tours qui n'ont pas
--     ignoresFragility (pas le Mage, pas les Totems) ; le plus fort des Totems gagne, un égal prolonge ;
--   * carreau perçant (Baliste, kind « Pierce ») : à l'impact, tous les ennemis à moins de pierceWidth du segment
--     tour -> point d'impact, et sa cible (hitLine) ;
--   * Trébuchet royal (targeting « Crowd ») : vise le point où sa zone touchera le plus d'ennemis
--     (pickCrowdTarget, mêmes positions prévues arrondies à CROWD_FLIGHT_STEP que le jeu) et étourdit ;
--   * projectiles (Archer, Catapulte, Baliste, Trébuchet : projectileSpeed) : la tour vise l'endroit où SERA
--     l'ennemi (predictImpact : sa vitesse, la fin de son ralentissement, le chemin), les dégâts tombent à
--     l'impact (IdleTowers.flightTime) ; une zone touche autour du point d'impact, une flèche touche sa cible
--     (ou, si elle est morte, l'ennemi le plus proche à PROJECTILE_CATCH_RADIUS studs au plus) ;
--   * dégâts « en attente » (pending, inFlight) : une tour à projectile ne vise pas un ennemi que les
--     projectiles déjà en vol vont tuer ; les autres le prennent seulement s'il n'y a personne d'autre ;
--   * flèches enflammées : zones de feu au sol (addFirePatch, burnFires : ravivées par la même tour,
--     fireMaxPatches par tour, FIRE_MAX_PER_PLOT en tout) ;
--   * Mage des tempêtes : foudre instantanée sur une petite zone, dégâts ET ralentissement (sauf s'il est
--     refusé : un seul contrôle à la fois) pour tous ;
--   * rayon du Sorcier (beamStep) : garde sa cible tant qu'elle vit et reste à portée, montée IdleTowers.beamRamp
--     au milieu du pas, repart de x1 sur une nouvelle cible.
-- Deux usages :
--   Engine.runWave(comp, tours)  : vraie vague (les ennemis meurent, pièces, fuites vers la base)
--   Engine.hits(comp, tours)     : vague « immortelle » : les ennemis ne meurent jamais et on compte les coups
--                                  que chaque tour peut porter à chaque groupe d'ennemis (plus, pour le rayon,
--                                  la montée et le temps passé sur chaque groupe, et pour les flèches, les coups
--                                  de leurs zones de feu ; et, à part, ceux qui tombent sur un ennemi fragile).
--                                  Le joueur simulé s'en sert pour estimer ce que rapporte un achat (Run.valueOf).
-- Différences voulues avec le jeu : pas de temps fixe (Engine.DT, 0,05 s) au lieu de ~1/60 s variable, petite
-- marge (1e-9) sur les temps de recharge pour éviter les erreurs d'arrondi (apparitions : 1e-6, comme le jeu), recharge des tours
-- remise à 0 au début de chaque vague (dans le jeu, une tour garde sa recharge d'une vague à l'autre : au pire
-- quelques secondes de retard sur son premier tir). Les temps de recharge des tours (0,2 / 0,8 / 1 / 1,2 / 1,8 /
-- 4 / 5 s, et leur moitié avec le bonus x2 vitesse) sont des multiples de 0,05 s. Les tours tirent dans l'ordre
-- des emplacements (dans le jeu, l'ordre de la table des tours). Les résultats changent de moins de 10 % entre
-- des pas de 0,1 s, 0,05 s et 1/60 s.
local Modules = require("./Modules")
local IdleConfig = Modules.IdleConfig
local IdleTowers = Modules.IdleTowers
local PlotLayout = Modules.PlotLayout
local Enemies = Modules.Enemies

local Engine = {}

Engine.DT = 0.05 -- pas de la vraie simulation (s)
Engine.HITS_DT = 0.1 -- pas des vagues « immortelles » (estimations seulement)

-- Petite marge sur les temps de recharge (erreurs d'arrondi ; les apparitions ont celle du jeu, TIME_EPSILON). run.ps1 -Verifier la met à 0
-- (Engine.EPS) pour comparer au vrai PlotGame pas à pas, sans aucune différence.
Engine.EPS = 1e-9
local EPS = Engine.EPS
local TIME_EPSILON = 1e-6 -- même marge que PlotGame pour les coups des zones de feu
local MAX_ENEMIES = IdleConfig.MAX_ENEMIES
local SPEED_MULTIPLIER = IdleConfig.ENEMY_SPEED_MULTIPLIER
-- Hauteur du départ d'un projectile au-dessus du chemin : la tour est posée à +0,3 (PlotGame:createTower) et
-- tire de 5 studs plus haut (PlotGame:towerAttack). Le temps de vol se calcule sur la vraie distance en 3D.
local MUZZLE_HEIGHT = 0.3 + 5
local MUZZLE_DY = 0 - MUZZLE_HEIGHT -- l'ennemi est au niveau du sol (Y = 0)

-- Vitesse d'un ennemi sur les parcelles (studs/s, sans ralentissement), comme PlotGame : vitesse de
-- Enemies.luau x ENEMY_SPEED_MULTIPLIER x facteur de son type (IdleConfig.enemySpeedFactor).
function Engine.enemySpeed(name: string): number
	return Enemies.Defs[name].speed * SPEED_MULTIPLIER * IdleConfig.enemySpeedFactor(name)
end

----------------------------------------------------------------------
-- Chemin précalculé (mêmes calculs que PlotLayout.pointAt, sans créer de Vector3)
----------------------------------------------------------------------
local PATH = PlotLayout.PATH
local NPATH = #PATH
local PX, PZ, CUM, DIRX, DIRZ = {}, {}, {}, {}, {}
for i, point in PATH do
	PX[i], PZ[i] = point.X, point.Z
end
CUM[1] = 0
for i = 2, NPATH do
	local segment = PATH[i] - PATH[i - 1]
	CUM[i] = CUM[i - 1] + segment.Magnitude
	local unit = segment.Unit
	DIRX[i], DIRZ[i] = unit.X, unit.Z
end
local PATH_LENGTH = PlotLayout.PATH_LENGTH
Engine.PATH_LENGTH = PATH_LENGTH

-- Point du chemin à `distance` studs du départ (PlotGame:pathPoint : coupé au bout du chemin).
local function pathPoint(distance: number): (number, number)
	if distance <= 0 then
		return PX[1], PZ[1]
	end
	if distance > PATH_LENGTH then
		distance = PATH_LENGTH
	end
	for i = 2, NPATH do
		if distance <= CUM[i] then
			local offset = distance - CUM[i - 1]
			return PX[i - 1] + DIRX[i] * offset, PZ[i - 1] + DIRZ[i] * offset
		end
	end
	return PX[NPATH], PZ[NPATH]
end
Engine.pathPoint = pathPoint

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
				baseSpeed = Enemies.Defs[item.enemy].speed * SPEED_MULTIPLIER,
				scale = IdleConfig.enemySpeedFactor(item.enemy),
			}
		end
		local group = groups[g]
		group.count += 1
		items[i] = { g = g, at = at, hp = item.health, reward = item.reward, speed = group.speed, baseSpeed = group.baseSpeed, scale = group.scale }
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

-- Vague d'essai faite à la main : `list` = { { enemy, health, gap } } (même forme que buildWave, sans pièces).
-- Sert aux duels du rapport (une tour contre un seul ennemi qui traverse tout le chemin).
function Engine.customComposition(list)
	local groups, items = {}, {}
	local at = 0
	for i, item in list do
		groups[i] = {
			name = item.enemy,
			count = 1,
			hp = item.health,
			reward = 0,
			speed = Engine.enemySpeed(item.enemy),
			baseSpeed = Enemies.Defs[item.enemy].speed * SPEED_MULTIPLIER,
			scale = IdleConfig.enemySpeedFactor(item.enemy),
			need = item.health,
		}
		items[i] = { g = i, at = at, hp = item.health, reward = 0, speed = groups[i].speed, baseSpeed = groups[i].baseSpeed, scale = groups[i].scale }
		at += item.gap or 0
	end
	return { wave = 0, waveType = "Custom", items = items, groups = groups, failable = true, totalHp = 0, totalReward = 0, key = "custom" }
end

----------------------------------------------------------------------
-- Tours
----------------------------------------------------------------------
local KIND = { Single = 1, Splash = 2, Aura = 3, Chain = 4, Beam = 5, Pierce = 6 }
Engine.KIND = KIND

-- Une tour posée, avec ses stats finales (IdleTowers.effectiveStats : niveau, doublons, bonus).
-- Les champs projectile*, fire* et beam* gardent les noms de IdleTowers : la tour compilée se passe
-- directement aux vraies fonctions du jeu (IdleTowers.flightTime, fireDps, beamRamp).
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
		crowd = stats.targeting == "Crowd", -- Trébuchet : le plus gros groupe (pickCrowdTarget)
		damage = stats.damage,
		cooldown = stats.cooldown or 0,
		range = stats.range,
		splash = stats.splash or 0,
		pierceWidth = stats.pierceWidth or 0,
		slow = stats.slow,
		slowDuration = stats.slowDuration or 0,
		stun = stats.stunDuration, -- étourdissement (contrôle de force 1), nil = aucun
		-- Fragilité donnée (Totem de givre), sa durée, et « ses dégâts ne profitent pas de la fragilité »
		fragility = stats.fragility or 0,
		fragilityDuration = stats.fragilityDuration or stats.slowDuration or 0,
		fragile = not stats.ignoresFragility,
		chains = stats.chains or 1,
		-- Projectile (nil = tir instantané)
		projectileSpeed = stats.projectileSpeed,
		projectileMinFlight = stats.projectileMinFlight,
		-- Flèches enflammées (nil = pas de feu)
		fireRadius = stats.fireRadius,
		fireDuration = stats.fireDuration,
		fireDamageRatio = stats.fireDamageRatio,
		fireTick = stats.fireTick,
		fireMaxPatches = stats.fireMaxPatches,
		-- Rayon continu
		beamRampRate = stats.beamRampRate,
		beamRampMax = stats.beamRampMax,
		cd = 0,
		beamTarget = nil,
		beamTime = 0,
	}
end

----------------------------------------------------------------------
-- Boucle de simulation
----------------------------------------------------------------------
local flightTime = IdleTowers.flightTime
local beamRamp = IdleTowers.beamRamp
local CATCH_RADIUS = IdleTowers.PROJECTILE_CATCH_RADIUS
local FIRE_MAX_PER_PLOT = IdleTowers.FIRE_MAX_PER_PLOT

local function byDistanceDesc(a, b)
	return a.dist > b.dist
end

-- Même règle que applyControl (PlotGame.luau) : UN SEUL contrôle à la fois. Aucun en cours -> le nouveau
-- s'applique ; en cours du MÊME type de tour -> prolongé (force inchangée) ; d'un AUTRE type -> refusé tant
-- qu'il dure. source = type de tour (ex. "Frost"), strength = 0 à 1 (1 = étourdi).
local function applyControl(enemy, source: string, strength: number, duration: number, now: number)
	if now < enemy.controlUntil then
		if enemy.controlSource ~= source then
			return
		end
		local untilTime = now + duration
		if untilTime > enemy.controlUntil then
			enemy.controlUntil = untilTime
		end
		return
	end
	enemy.controlSource = source
	enemy.controlFactor = math.clamp(strength, 0, 1)
	enemy.controlUntil = now + duration
end

-- Même règle que applyFragility (PlotGame.luau) : une plus forte remplace, une égale prolonge, une plus
-- faible est ignorée tant que l'actuelle dure.
local function applyFragility(enemy, fragility: number, duration: number, now: number)
	if fragility <= 0 then
		return
	end
	if now >= enemy.fragileUntil or fragility > enemy.fragility then
		enemy.fragility = fragility
		enemy.fragileUntil = now + duration
	elseif fragility == enemy.fragility then
		local untilTime = now + duration
		if untilTime > enemy.fragileUntil then
			enemy.fragileUntil = untilTime
		end
	end
end

-- Distance parcourue par l'ennemi en `seconds` (PlotGame travelDistance) : ralenti (ou arrêté s'il est
-- étourdi) tant que son contrôle actuel dure, puis à sa vitesse normale.
local function travelDistance(enemy, now: number, seconds: number): number
	local slowed = 0
	if now < enemy.controlUntil then
		slowed = enemy.controlUntil - now
		if slowed > seconds then
			slowed = seconds
		end
	end
	return enemy.speed * (slowed * (1 - enemy.controlFactor) + (seconds - slowed))
end

-- Distance (à plat) entre un point et le segment [a, b] (PlotGame segmentDistance).
local function segmentDistance(px: number, pz: number, ax: number, az: number, bx: number, bz: number): number
	local abx, abz = bx - ax, bz - az
	local apx, apz = px - ax, pz - az
	local lengthSquared = abx * abx + abz * abz
	local t = if lengthSquared > 0 then math.clamp((apx * abx + apz * abz) / lengthSquared, 0, 1) else 0
	local dx, dz = apx - abx * t, apz - abz * t
	return math.sqrt(dx * dx + dz * dz)
end

-- Trébuchet : positions prévues des ennemis rangées par temps de vol arrondi (PlotGame CROWD_FLIGHT_STEP).
local CROWD_FLIGHT_STEP = 0.05

-- immortal = true : les ennemis ne perdent pas de PV, hitsOut[i][g] compte les coups de la tour i (rayon :
-- la montée x secondes, voir beamHit ; feu : hitsOut[i].fire[g]). Sinon usefulOut[i] cumule les dégâts utiles
-- de la tour i (sans les dégâts perdus sur un ennemi déjà presque mort ; le feu compte pour l'Archer qui l'a allumé).
-- baseMode : nil = comme le jeu (vague ratée dès la première fuite ; la simulation continue quand même jusqu'au
--                  bout pour savoir QUI aurait fui, mais le temps, les pièces et les dégâts rendus sont ceux
--                  du moment de la première fuite, comme dans le jeu) ;
--            "ignore" = la vague va jusqu'au bout (success dit si aucun ennemi n'a fui, leakScore de combien) ;
--            "strict" = s'arrête à la première fuite (plus rapide : banc d'essai des tours).
local function simulate(comp, towers, immortal: boolean, dt: number, hitsOut, usefulOut, leakOut, baseMode: string?)
	local EPS = Engine.EPS
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
	local impacts = {} -- projectiles en vol : { at, ti, target, x, z }
	local nImpacts = 0
	local fires = {} -- zones de feu : { ti, x, z, fragile, radius, dps, tick, expiresAt, nextTick }
	-- Vague écrasée : secondes d'attente sautées dans la file (un ennemi sort à item.at - skipped). Lu à chaque
	-- vague : -Regler "IdleConfig.COMPRESS_EMPTY_SPAWNS=false" compare avec l'ancien rythme.
	local COMPRESS = IdleConfig.COMPRESS_EMPTY_SPAWNS == true
	local skipped = 0
	-- Une mort fait sortir le prochain ennemi de la file tout de suite (IdleConfig.SPAWN_NEXT_ON_KILL) :
	-- releases = morts qui n'ont pas encore fait sortir leur ennemi (PlotGame.spawnReleases). Pas dans une vague
	-- immortelle (personne ne meurt). -Regler "IdleConfig.SPAWN_NEXT_ON_KILL=false" compare sans la règle.
	local SPAWN_ON_KILL = IdleConfig.SPAWN_NEXT_ON_KILL == true
	local releases = 0

	for i = 1, nTowers do
		local tower = towers[i]
		tower.cd = 0
		tower.beamTarget = nil
		tower.beamTime = 0
	end

	-- fragile = ces dégâts profitent de la fragilité du Totem (PlotGame:damageEnemy) : x (1 + fragilité) tant
	-- qu'elle dure. Vague immortelle : le coup compte aussi dans row.frag s'il tombe sur un ennemi fragile
	-- (Run.valueOf le multiplie ensuite par la fragilité des Totems du joueur).
	local function hitEnemy(enemy, amount: number, towerIndex: number, fragile: boolean, now: number)
		if immortal then
			local row = hitsOut[towerIndex]
			row[enemy.g] += 1
			if fragile and now < enemy.fragileUntil then
				row.frag[enemy.g] += 1
			end
			return
		end
		if enemy.dead then
			return
		end
		if fragile and now < enemy.fragileUntil then
			amount *= 1 + enemy.fragility
		end
		local hp = enemy.hp
		usefulOut[towerIndex] += if amount < hp then amount else hp
		hp -= amount
		enemy.hp = hp
		if hp <= 0 then
			enemy.dead = true
			removed += 1
			coins += enemy.reward
			if SPAWN_ON_KILL then
				releases += 1
			end
		end
	end

	-- Un coup de la tour : son contrôle éventuel (ralentissement, étourdissement), puis ses dégâts
	-- (PlotGame:hitEnemy). Les dégâts tombent même si le contrôle est refusé.
	local function hitWith(enemy, tower, towerIndex: number, now: number)
		local slow = tower.slow
		if slow then
			applyControl(enemy, tower.type, slow, tower.slowDuration, now)
		end
		local stun = tower.stun
		if stun then
			applyControl(enemy, tower.type, 1, stun, now)
		end
		hitEnemy(enemy, tower.damage, towerIndex, tower.fragile, now)
	end

	-- Carreau perçant : tous les ennemis vivants à moins de pierceWidth du segment [origine, impact], et sa
	-- cible où qu'elle soit (PlotGame:hitLine). Chacun une seule fois.
	local function hitLine(ox: number, oz: number, ix: number, iz: number, tower, target, towerIndex: number, now: number)
		local width = tower.pierceWidth
		for i = 1, n do
			local enemy = enemies[i]
			if not enemy.dead and (enemy == target or segmentDistance(enemy.x, enemy.z, ox, oz, ix, iz) <= width) then
				hitWith(enemy, tower, towerIndex, now)
			end
		end
	end

	-- Coup de zone : tous les ennemis vivants à moins de splash studs du point (PlotGame:hitArea).
	local function hitArea(cx: number, cz: number, tower, towerIndex: number, now: number)
		local splash = tower.splash
		for i = 1, n do
			local enemy = enemies[i]
			if not enemy.dead then
				local dx, dz = enemy.x - cx, enemy.z - cz
				if math.sqrt(dx * dx + dz * dz) <= splash then
					hitWith(enemy, tower, towerIndex, now)
				end
			end
		end
	end

	-- Cible à portée (PlotGame:pickTarget) : la plus avancée ou la plus résistante, en évitant les ennemis
	-- condamnés (pending >= PV) ; allowDoomed = on les prend s'il n'y a personne d'autre.
	local function pickTarget(tower, allowDoomed: boolean)
		local tx, tz, range = tower.x, tower.z, tower.range
		local strongest = tower.strongest
		local best, bestScore = nil, -math.huge
		local fallback, fallbackScore = nil, -math.huge
		for i = 1, n do
			local enemy = enemies[i]
			if not enemy.dead then
				local dx, dz = enemy.x - tx, enemy.z - tz
				if math.sqrt(dx * dx + dz * dz) <= range then
					local score = if strongest then enemy.hp else enemy.dist
					if enemy.pending < enemy.hp then
						if score > bestScore then
							best, bestScore = enemy, score
						end
					elseif allowDoomed and score > fallbackScore then
						fallback, fallbackScore = enemy, score
					end
				end
			end
		end
		return best or fallback
	end

	-- Ennemi vivant le plus proche d'un point, à `radius` studs au plus (PlotGame:enemyNear).
	local function enemyNear(x: number, z: number, radius: number)
		local nearest, nearestDistance = nil, radius
		for i = 1, n do
			local enemy = enemies[i]
			if not enemy.dead then
				local dx, dz = enemy.x - x, enemy.z - z
				local distance = math.sqrt(dx * dx + dz * dz)
				if distance <= nearestDistance then
					nearest, nearestDistance = enemy, distance
				end
			end
		end
		return nearest
	end

	-- Visée anticipée (PlotGame:predictImpact), 2 itérations : point visé (x, z) et temps de vol.
	local function predictImpact(tower, target, now: number): (number, number, number)
		local fx, fz = tower.x, tower.z
		local dx, dz = target.x - fx, target.z - fz
		local flight = flightTime(tower, math.sqrt(dx * dx + MUZZLE_DY * MUZZLE_DY + dz * dz))
		for _ = 1, 2 do
			local ax, az = pathPoint(target.dist + travelDistance(target, now, flight))
			dx, dz = ax - fx, az - fz
			flight = flightTime(tower, math.sqrt(dx * dx + MUZZLE_DY * MUZZLE_DY + dz * dz))
		end
		local ax, az = pathPoint(target.dist + travelDistance(target, now, flight))
		return ax, az, flight
	end

	-- Lance un projectile (PlotGame:fireProjectile) ; ax, az, flight déjà calculés (Trébuchet) ou visée anticipée.
	local function fireProjectile(tower, towerIndex: number, target, now: number, ax: number?, az: number?, flight: number?)
		if not ax or not az or not flight then
			ax, az, flight = predictImpact(tower, target, now)
		end
		if not immortal then
			target.pending += tower.damage
		end
		target.inFlight += 1
		nImpacts += 1
		impacts[nImpacts] = { at = now + (flight :: number), ti = towerIndex, target = target, x = ax, z = az }
	end

	-- Trébuchet (PlotGame:pickCrowdTarget) : chaque ennemi à portée est un point d'impact possible (visée
	-- anticipée) ; on compte les ennemis NON condamnés qui seront à moins de splash studs de ce point à l'arrivée
	-- (positions prévues avec le temps de vol arrondi à CROWD_FLIGHT_STEP, comme le jeu). Le plus grand nombre
	-- gagne ; à égalité, le plus avancé. Renvoie (cible, x, z, vol) ou nil.
	local function pickCrowdTarget(tower, now: number)
		local tx, tz, range, splash = tower.x, tower.z, tower.range, tower.splash
		local candidates, counted = {}, {}
		for i = 1, n do
			local enemy = enemies[i]
			if not enemy.dead then
				local dx, dz = enemy.x - tx, enemy.z - tz
				if math.sqrt(dx * dx + dz * dz) <= range then
					table.insert(candidates, enemy)
				end
				if enemy.pending < enemy.hp then
					table.insert(counted, enemy)
				end
			end
		end
		if #candidates == 0 or #counted == 0 then
			return nil, 0, 0, 0
		end
		local predicted = {}
		local best, bestX, bestZ, bestFlight, bestCount, bestAhead = nil, 0, 0, 0, 0, -math.huge
		for _, candidate in candidates do
			local ax, az, flight = predictImpact(tower, candidate, now)
			local candidateMove = candidate.speed * flight
			local step = math.floor(flight / CROWD_FLIGHT_STEP + 0.5)
			local positions = predicted[step]
			if not positions then
				positions = {}
				predicted[step] = positions
			end
			local count = 0
			for _, other in counted do
				local dx, dz = candidate.x - other.x, candidate.z - other.z
				if math.sqrt(dx * dx + dz * dz) - candidateMove - other.speed * flight <= splash then
					local at = positions[other]
					if not at then
						local px, pz = pathPoint(other.dist + travelDistance(other, now, step * CROWD_FLIGHT_STEP))
						at = { px, pz }
						positions[other] = at
					end
					local ex, ez = ax - at[1], az - at[2]
					if math.sqrt(ex * ex + ez * ez) <= splash then
						count += 1
					end
				end
			end
			local ahead = candidate.dist + travelDistance(candidate, now, flight)
			if count > bestCount or (count == bestCount and count > 0 and ahead > bestAhead) then
				best, bestX, bestZ, bestFlight, bestCount, bestAhead = candidate, ax, az, flight, count, ahead
			end
		end
		return best, bestX, bestZ, bestFlight
	end

	-- Une flèche enflammée touche le sol (PlotGame:addFirePatch).
	local function addFirePatch(tower, towerIndex: number, x: number, z: number, now: number)
		local dps = tower.damage * tower.fireDamageRatio
		local mine, oldestMine, oldestAll = 0, nil, nil
		local count = #fires
		for index = 1, count do
			local patch = fires[index]
			if patch.ti == towerIndex then
				local dx, dz = patch.x - x, patch.z - z
				if math.sqrt(dx * dx + dz * dz) <= patch.radius then
					patch.expiresAt = now + tower.fireDuration
					if dps > patch.dps then
						patch.dps = dps
					end
					return
				end
				mine += 1
				if not oldestMine or patch.expiresAt < fires[oldestMine].expiresAt then
					oldestMine = index
				end
			end
			if not oldestAll or patch.expiresAt < fires[oldestAll].expiresAt then
				oldestAll = index
			end
		end
		if mine >= tower.fireMaxPatches and oldestMine then
			table.remove(fires, oldestMine)
		elseif count >= FIRE_MAX_PER_PLOT and oldestAll then
			table.remove(fires, oldestAll)
		end
		table.insert(fires, {
			ti = towerIndex,
			x = x,
			z = z,
			fragile = tower.fragile, -- le feu de l'Archer profite de la fragilité du Totem
			radius = tower.fireRadius,
			dps = dps,
			tick = tower.fireTick,
			expiresAt = now + tower.fireDuration,
			nextTick = now + tower.fireTick,
		})
	end

	-- Arrivée d'un projectile (PlotGame:landImpact).
	local function landImpact(impact, now: number)
		local tower = towers[impact.ti]
		local target = impact.target
		target.inFlight -= 1
		if not immortal then
			if target.inFlight <= 0 then
				target.pending = 0
			else
				local left = target.pending - tower.damage
				target.pending = if left > 0 then left else 0
			end
		end
		if tower.kind == 2 then
			hitArea(impact.x, impact.z, tower, impact.ti, now)
		elseif tower.kind == 6 then
			hitLine(tower.x, tower.z, impact.x, impact.z, tower, target, impact.ti, now)
		else
			local victim = if target.dead then enemyNear(impact.x, impact.z, CATCH_RADIUS) else target
			if victim then
				hitWith(victim, tower, impact.ti, now)
			end
		end
		if tower.fireRadius then
			addFirePatch(tower, impact.ti, impact.x, impact.z, now)
		end
	end

	-- Zones de feu (PlotGame:burnFires) : dps x tick à chaque coup, tant qu'elles durent.
	local function burnFires(now: number)
		for i = #fires, 1, -1 do
			local patch = fires[i]
			while patch.nextTick <= now + TIME_EPSILON and patch.nextTick <= patch.expiresAt + TIME_EPSILON do
				local amount = patch.dps * patch.tick
				local px, pz, radius, ti = patch.x, patch.z, patch.radius, patch.ti
				for k = 1, n do
					local enemy = enemies[k]
					if not enemy.dead then
						local dx, dz = enemy.x - px, enemy.z - pz
						if math.sqrt(dx * dx + dz * dz) <= radius then
							if immortal then
								local row = hitsOut[ti]
								row.fire[enemy.g] += 1
								if patch.fragile and now < enemy.fragileUntil then
									row.fireFrag[enemy.g] += 1
								end
							else
								hitEnemy(enemy, amount, ti, patch.fragile, now)
							end
						end
					end
				end
				patch.nextTick += patch.tick
			end
			if patch.nextTick > patch.expiresAt + TIME_EPSILON then
				table.remove(fires, i)
			end
		end
	end

	-- Un pas du rayon (PlotGame:beamStep).
	local function beamStep(tower, towerIndex: number, now: number)
		local target = tower.beamTarget
		if target then
			if target.dead then
				target = nil
			else
				local dx, dz = target.x - tower.x, target.z - tower.z
				if math.sqrt(dx * dx + dz * dz) > tower.range then
					target = nil
				elseif immortal then
					-- Vague immortelle (estimations) : dans le jeu, la cible meurt et le rayon passe à la suivante.
					-- Ici elle ne meurt jamais : sans ça, un petit fantassin immortel garderait le rayon pendant que
					-- le Seigneur de guerre passe. Il passe donc au plus résistant dès qu'il en arrive un (montée à
					-- zéro, comme après une mort) ; Run.valueOf plafonne ensuite les dégâts par la vitesse de mise à mort.
					local better = pickTarget(tower, true)
					if better and better.hp > target.hp then
						target = nil
					end
				end
			end
		end
		if not target then
			target = pickTarget(tower, true)
			tower.beamTarget = target
			tower.beamTime = 0
		end
		if not target then
			return
		end
		local startTime = tower.beamTime
		tower.beamTime = startTime + dt
		local ramp = beamRamp(tower, startTime + dt / 2)
		if immortal then
			-- Coups « en dégâts de base » : montée x secondes, et temps passé sur ce groupe (Run.valueOf) ;
			-- row.frag : la part de montée x secondes sur un ennemi fragile.
			local row = hitsOut[towerIndex]
			local g = target.g
			row[g] += ramp * dt
			row.contact[g] += dt
			if tower.fragile and now < target.fragileUntil then
				row.frag[g] += ramp * dt
			end
		else
			hitEnemy(target, tower.damage * ramp * dt, towerIndex, tower.fragile, now)
		end
	end

	while true do
		step += 1
		if step > 2000000 then
			error("vague trop longue : simulation bloquée ?")
		end
		local now = step * dt

		-- Apparitions (PlotGame:simulate). Chaque mort des pas d'avant (releases) fait sortir UN ennemi en avance
		-- (la suite de la file avance d'autant). Vague écrasée : plus aucun ennemi en vie (les morts sont retirés
		-- à la fin de chaque pas, donc n = vivants), encore des ennemis à faire sortir et aucune mort qui attend
		-- son ennemi -> l'attente est sautée.
		if COMPRESS and releases == 0 and spawnIndex <= nItems and n == 0 then
			local waitLeft = items[spawnIndex].at - skipped - now
			if waitLeft > 0 then
				skipped += waitLeft
			end
		end
		while spawnIndex <= nItems and n < MAX_ENEMIES do
			local item = items[spawnIndex]
			if item.at - skipped > now + TIME_EPSILON then
				if releases <= 0 then
					break
				end
				-- Pas encore son heure, mais un ennemi est mort : il sort maintenant.
				releases -= 1
				skipped += item.at - skipped - now
			end
			spawnIndex += 1
			n += 1
			enemies[n] = {
				g = item.g,
				hp = item.hp,
				maxHp = item.hp,
				reward = item.reward,
				speed = item.speed,
				baseSpeed = item.baseSpeed,
				scale = item.scale,
				dist = 0,
				seg = 2,
				x = PX[1],
				z = PZ[1],
				-- Contrôle en cours (un seul, applyControl) et fragilité du Totem (applyFragility)
				controlSource = nil,
				controlFactor = 0,
				controlUntil = 0,
				fragility = 0,
				fragileUntil = 0,
				pending = 0,
				inFlight = 0,
				dead = false,
			}
		end

		-- Déplacements
		for i = 1, n do
			local enemy = enemies[i]
			if not enemy.dead then
				-- Même calcul (et même ordre des multiplications) que PlotGame : vitesse x (facteur du type x contrôle).
				local factor = enemy.scale
				if now < enemy.controlUntil then
					factor = enemy.scale * (1 - enemy.controlFactor)
				end
				local speed = enemy.baseSpeed * factor
				local distance = enemy.dist + speed * dt
				enemy.dist = distance
				if distance >= PATH_LENGTH then
					enemy.dead = true
					removed += 1
					if not immortal then
						-- Une seule fuite = vague ratée (PlotGame:simulate s'arrête là, les tours ne tirent plus).
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

		-- Projectiles qui arrivent (retirés en mettant le dernier à leur place, comme PlotGame:resolveImpacts)
		if nImpacts > 0 then
			local i = 1
			while i <= nImpacts do
				local impact = impacts[i]
				if impact.at <= now then
					impacts[i] = impacts[nImpacts]
					impacts[nImpacts] = nil
					nImpacts -= 1
					landImpact(impact, now)
				else
					i += 1
				end
			end
		end

		-- Tours
		for ti = 1, nTowers do
			local tower = towers[ti]
			local kind = tower.kind
			if kind == 5 then
				beamStep(tower, ti, now)
				continue
			end
			local cd = tower.cd - dt
			if cd <= EPS then
				local attacked = false
				local tx, tz, range = tower.x, tower.z, tower.range
				if kind == 3 then
					-- Aura (Totem de givre) : ralentit (contrôle, refusé si une autre tour contrôle déjà l'ennemi),
					-- rend fragile (toujours), puis de petits dégâts (qui ne profitent pas de la fragilité).
					local slow, slowDuration, damage = tower.slow, tower.slowDuration, tower.damage
					local fragility, fragilityDuration, fragile, source = tower.fragility, tower.fragilityDuration, tower.fragile, tower.type
					for i = 1, n do
						local enemy = enemies[i]
						if not enemy.dead then
							local dx, dz = enemy.x - tx, enemy.z - tz
							if math.sqrt(dx * dx + dz * dz) <= range then
								attacked = true
								if slow then
									applyControl(enemy, source, slow, slowDuration, now)
								end
								applyFragility(enemy, fragility, fragilityDuration, now)
								hitEnemy(enemy, damage, ti, fragile, now)
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
							if math.sqrt(dx * dx + dz * dz) <= range then
								inRange = inRange or {}
								table.insert(inRange, enemy)
							end
						end
					end
					if inRange then
						attacked = true
						table.sort(inRange, byDistanceDesc)
						for i = 1, math.min(tower.chains, #inRange) do
							hitEnemy(inRange[i], tower.damage, ti, tower.fragile, now)
						end
					end
				elseif tower.crowd then
					-- Trébuchet royal : le plus gros groupe à portée (positions prévues à l'impact)
					local target, ax, az, flight = pickCrowdTarget(tower, now)
					if target then
						attacked = true
						fireProjectile(tower, ti, target, now, ax, az, flight)
					end
				else
					-- Une cible, une zone autour d'elle ou un carreau perçant. Les tours à projectile ne visent
					-- jamais un ennemi condamné ; les tirs instantanés (Mage) le prennent s'il n'y a personne d'autre.
					local projectile = tower.projectileSpeed ~= nil
					local target = pickTarget(tower, not projectile)
					if target then
						attacked = true
						if projectile then
							fireProjectile(tower, ti, target, now)
						elseif kind == 2 then
							hitArea(target.x, target.z, tower, ti, now)
						elseif kind == 6 then
							hitLine(tx, tz, target.x, target.z, tower, target, ti, now)
						else
							hitWith(target, tower, ti, now)
						end
					end
				end
				cd = if attacked then tower.cooldown else 0
			end
			tower.cd = cd
		end

		-- Zones de feu des flèches enflammées
		if #fires > 0 then
			burnFires(now)
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

-- Vague immortelle : hits[i][g] = coups de la tour i sur le groupe g pendant toute la vague.
--   Rayon : hits[i][g] = somme de montée x secondes (dégâts « en dégâts de base par seconde »),
--           hits[i].contact[g] = secondes passées sur ce groupe ; beamRampRate / beamRampMax de la tour.
--   Flèches enflammées : hits[i].fire[g] = coups de feu (un coup = fireDamageRatio x fireTick x dégâts),
--           hits[i].fireHit = fireDamageRatio x fireTick.
-- Run.valueOf transforme ces coups en dégâts utiles.
function Engine.hits(comp, towers)
	local hits = {}
	local groups = #comp.groups
	for i, tower in towers do
		local row = table.create(groups, 0)
		row.frag = table.create(groups, 0) -- coups (rayon : montée x secondes) sur un ennemi fragile
		if tower.kind == 5 then
			row.contact = table.create(groups, 0)
			row.beamRampRate = tower.beamRampRate
			row.beamRampMax = tower.beamRampMax
		end
		if tower.fireRadius then
			row.fire = table.create(groups, 0)
			row.fireFrag = table.create(groups, 0)
			row.fireHit = tower.fireDamageRatio * tower.fireTick
		end
		hits[i] = row
	end
	simulate(comp, towers, true, Engine.HITS_DT, hits, nil, nil)
	return hits
end

-- Nombre de pas pour attendre `seconds` (le jeu lance la vague à la première image après l'échéance).
function Engine.delaySteps(seconds: number): number
	return math.ceil(seconds / Engine.DT - EPS)
end

return Engine

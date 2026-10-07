-- LES MONSTRES ET LE COMBAT.
-- Chaque monstre est un bloc invisible que le serveur déplace (étiquette « Monster ») ; l'écran de chaque joueur
-- dessine l'animal par-dessus, avec sa barre de vie (attributs Animal, Rank, Scale, Boss, Level, Hp, MaxHp, HitAt).
--   Il se promène autour de chez lui, sans attaquer personne. Un joueur le frappe : il se défend. Il frappe D'ABORD LES FAMILIERS de
--   l'équipe du joueur (dans l'ordre), et le joueur seulement quand ils sont tous à terre. Trop loin de chez lui :
--   il rentre et se soigne. Les familiers se relèvent et se soignent après quelques secondes sans prendre de coup.
--   Le joueur frappe à l'épée (événement « Attack ») le monstre le plus proche à sa portée. Ses familiers d'équipe
--   frappent sa cible chaque seconde.
--   Monstre battu : chaque joueur qui l'a frappé reçoit ses pièces, son XP, et peut-être un œuf de la zone. Le
--   boss ouvre la zone suivante. Le monstre revient au bout de quelques secondes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Pets = require(ReplicatedStorage.Shared.Pets)
local PlayerData = require(script.Parent.PlayerData)
local Eggs = require(script.Parent.Eggs)
local Gym = require(script.Parent.Gym)

local Monsters = {}

local TICK = 0.1
local random = Random.new()
local notify = function(_player: Player, _key: string, ...) end
local zones = {}
local monsters = {} -- [id] = monstre
-- [joueur] = { target = id du monstre visé, last = heure du dernier coup, swing = heure du dernier coup d'épée,
--              hp = { [place] = vie du familier }, hurtAt = heure du dernier coup reçu par un familier }
local fights = {}
local lootEvent: RemoteEvent

-- Les tests coupent les coups des monstres pour mesurer le reste au calme.
Monsters.peaceful = false

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end
local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function fightOf(player: Player)
	local fight = fights[player]
	if not fight then
		fight = { last = 0, swing = 0, hp = {}, hurtAt = 0 }
		fights[player] = fight
	end
	return fight
end

-- L'équipe du joueur au combat, dans l'ordre : { key, pet, max, hp, damage } (hp = 0 : à terre).
local function teamOf(player: Player)
	local data = PlayerData.get(player)
	local fight = fightOf(player)
	local team = {}
	for _, key in data and data.team or {} do
		local pet = data.spots[key]
		if pet and pet.v then
			local max = Pets.healthOf(pet)
			table.insert(team, { key = key, pet = pet, max = max, hp = math.min(fight.hp[key] or max, max), damage = Pets.damageOf(pet) })
		end
	end
	return team
end
-- Dit à l'écran la vie de chaque familier de l'équipe (« 40/60;0/35 »).
local function publishTeam(player: Player)
	local parts = {}
	for _, member in teamOf(player) do
		table.insert(parts, member.hp .. "/" .. member.max)
	end
	player:SetAttribute("TeamHp", table.concat(parts, ";"))
end
Monsters.publishTeam = publishTeam

local function spawn(monster)
	monster.hp = monster.def.hp
	monster.position = monster.home
	monster.target = nil
	monster.hitters = {}
	monster.dead = false
	monster.nextWander = 0
	monster.part.CFrame = CFrame.new(monster.home)
	monster.part:SetAttribute("Hp", monster.hp)
end

-- rank : 1 à 5 = un monstre, 6 = le boss, 0 = un coffre.
local function create(zone, rank: number, home: Vector3)
	local def = if rank == 0 then Config.chest(zone.index) else Config.monster(zone.index, rank)
	local animal = if rank == 0 then "Chest" else Pets.COLLECTIONS[zone.index][rank]
	local part = Instance.new("Part")
	part.Name = "Monster_" .. animal
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(2, 2, 2)
	local id = #monsters + 1
	part:SetAttribute("Id", id)
	part:SetAttribute("Animal", animal)
	part:SetAttribute("Rank", rank)
	part:SetAttribute("Scale", def.scale)
	part:SetAttribute("Boss", rank == 6)
	part:SetAttribute("Chest", rank == 0)
	part:SetAttribute("Level", def.level)
	part:SetAttribute("MaxHp", def.hp)
	part:SetAttribute("HitAt", 0)
	part:AddTag("Monster")
	local monster = { id = id, zone = zone.index, rank = rank, animal = animal, def = def, part = part, home = home, boss = rank == 6, chest = rank == 0, reach = Config.MONSTER_REACH + def.scale }
	monsters[id] = monster
	spawn(monster)
	part.Parent = zone.folder
	return monster
end

-- CE QUE GAGNE UN JOUEUR QUI A FRAPPÉ LE MONSTRE (règle du joueur : « si plusieurs personnes tapent un monstre, XP
-- et or partagés suivant les dégâts infligés, et l'œuf à celui qui a infligé le plus de dégâts, les autres rien »).
--   share : sa part des dégâts, de 0 à 1 (1 quand il est seul) ; les pièces et l'XP sont multipliées par elle.
--   best : c'est lui qui a fait le plus de dégâts ; lui seul peut recevoir l'œuf.
local function reward(monster, player: Player, share: number, best: boolean)
	local def = monster.def
	local coins, xp = math.floor(def.coins * share + 0.5), math.floor(def.xp * share + 0.5)
	PlayerData.addCoins(player, coins)
	-- Chaque familier de l'équipe reçoit l'XP du monstre, lui aussi.
	local data = PlayerData.get(player)
	for _, key in data.team do
		local pet = data.spots[key]
		if pet and pet.v then
			pet.xp = (pet.xp or 0) + xp
			pet.lv = pet.lv or 1
			local before = pet.lv
			while pet.xp >= Pets.xpNeed(pet) do
				pet.xp -= Pets.xpNeed(pet)
				pet.lv += 1
			end
			if pet.lv > before then
				notify(player, "petLevel", pet.a, Pets.levelOf(pet))
			end
		end
	end
	local levels = PlayerData.addXp(player, xp)
	publishTeam(player)
	lootEvent:FireClient(player, monster.position, coins, xp)
	if levels > 0 then
		Gym.applyStats(player, true)
		notify(player, "playerLevel", PlayerData.get(player).level)
	end
	-- Un monstre lâche l'œuf de son animal ; un coffre, un œuf tiré au sort. La chance du joueur aide.
	-- LE TOUT PREMIER MONSTRE BATTU lache toujours son oeuf (un joueur qui n a encore ni oeuf ni familier) : on a son
	-- premier familier dans la premiere minute.
	local newcomer = next(data.spots) == nil and #data.bag == 0 and not monster.chest
	if best and (newcomer or random:NextNumber() < def.egg * Eggs.luck(player)) then
		Eggs.drop(player, monster.zone, if monster.chest then nil else monster.rank)
	end
	if monster.boss then
		if PlayerData.openZone(player, monster.zone + 1) then
			notify(player, "zoneOpen", monster.zone + 1)
		else
			notify(player, "bossDown", monster.animal)
		end
	end
end

local function die(monster)
	monster.dead = true
	monster.target = nil
	monster.part:SetAttribute("Hp", 0)
	-- La part de chacun, et celui qui a fait le plus de dégâts.
	local total, top, topDealt = 0, nil, 0
	for player, dealt in monster.hitters do
		if player:IsDescendantOf(Players) then
			total += dealt
			if dealt > topDealt then
				top, topDealt = player, dealt
			end
		end
	end
	for player, dealt in monster.hitters do
		if player:IsDescendantOf(Players) and total > 0 then
			reward(monster, player, dealt / total, player == top)
		end
		local fight = fights[player]
		if fight and fight.target == monster.id then
			fight.target = nil
			player:SetAttribute("Target", 0)
		end
	end
	task.delay(if monster.boss then Config.BOSS_RESPAWN elseif monster.chest then Config.CHEST_RESPAWN else Config.RESPAWN, function()
		spawn(monster)
	end)
end

-- Enlève de la vie au monstre, au nom de ce joueur. kind : « sword » ou « pet » (pour la couleur du chiffre).
local function hurt(monster, player: Player, amount: number, kind: string)
	if monster.dead then
		return
	end
	amount = math.min(amount, monster.hp)
	monster.hp -= amount
	monster.hitters[player] = (monster.hitters[player] or 0) + amount
	monster.part:SetAttribute("Hp", monster.hp)
	if not monster.chest then
		monster.target = monster.target or player
	end
	lootEvent:FireClient(player, monster.position, amount, 0, kind)
	if monster.hp <= 0 then
		die(monster)
	end
end

-- Le monstre vivant le plus proche du joueur, à moins de `reach` (plus la grosseur du monstre).
local function nearest(position: Vector3, reach: number)
	local best, bestDistance = nil, math.huge
	for _, monster in monsters do
		if not monster.dead then
			local distance = flat(monster.position - position).Magnitude - monster.def.scale
			if distance <= reach and distance < bestDistance then
				best, bestDistance = monster, distance
			end
		end
	end
	return best
end

-- Un coup d'épée du joueur. Renvoie le monstre touché (ou nil : trop tôt, ou personne à portée).
function Monsters.attack(player: Player)
	local data = PlayerData.get(player)
	local root = rootOf(player)
	if not data or not root then
		return nil
	end
	local now = os.clock()
	local fight = fightOf(player)
	if now - fight.swing < Config.ATTACK_COOLDOWN * 0.9 then
		return nil
	end
	fight.swing = now
	-- L'heure du coup : l'écran de tous les joueurs y joue le geste (Poses.luau).
	player:SetAttribute("PunchAt", workspace:GetServerTimeNow())
	-- Le monstre deja vise passe d abord, tant qu il est a portee ; sinon le plus proche.
	local current = fight.target and monsters[fight.target]
	local monster = nil
	if current and not current.dead and flat(current.position - root.Position).Magnitude - current.def.scale <= Config.ATTACK_REACH then
		monster = current
	else
		monster = nearest(root.Position, Config.ATTACK_REACH)
	end
	-- Et il faut l avoir devant soi : un coup donne dos au monstre part dans le vide.
	if monster then
		local toward = flat(monster.position - root.Position)
		if toward.Magnitude > 1 and toward.Unit:Dot(flat(root.CFrame.LookVector).Unit) < -0.25 then
			monster = nil
		end
	end
	if not monster then
		return nil
	end
	fight.target, fight.last = monster.id, now
	player:SetAttribute("Target", monster.id)
	hurt(monster, player, Config.hitDamage(data.sword, data.level), "sword")
	return monster
end

-- Les dégâts par seconde de l'équipe de familiers du joueur (ceux qui sont à terre ne frappent pas).
function Monsters.teamDamage(player: Player): number
	local total = 0
	for _, member in teamOf(player) do
		if member.hp > 0 then
			total += member.damage
		end
	end
	return total
end

-- Le monstre frappe ce joueur : le premier familier debout de son équipe encaisse ; s'ils sont tous à terre, c'est
-- le joueur. Renvoie true si un familier a encaissé.
local function strike(monster, player: Player, humanoid: Humanoid?): boolean
	local fight = fightOf(player)
	for _, member in teamOf(player) do
		if member.hp > 0 then
			fight.hp[member.key] = math.max(0, member.hp - monster.def.damage)
			if fight.hp[member.key] == 0 then
				notify(player, "petDown", member.pet.a)
			end
			publishTeam(player)
			return true
		end
	end
	if humanoid then
		humanoid:TakeDamage(monster.def.damage)
	end
	return false
end
-- Vrai si un familier du joueur tient encore debout.
local function guarded(player: Player): boolean
	for _, member in teamOf(player) do
		if member.hp > 0 then
			return true
		end
	end
	return false
end

local function stepMonster(monster, dt: number, now: number)
	local position = monster.position
	-- Sa cible est-elle toujours là ?
	local target, targetRoot = monster.target, nil
	if target then
		targetRoot = rootOf(target)
		if not targetRoot or flat(position - monster.home).Magnitude > Config.LEASH or flat(targetRoot.Position - position).Magnitude > Config.RESET then
			-- Le joueur est parti (ou mort) : le monstre abandonne, et retrouve toute sa vie tout de suite.
			local fight = fights[target]
			if fight and fight.target == monster.id then
				fight.target = nil
				target:SetAttribute("Target", 0)
			end
			monster.target, target, targetRoot = nil, nil, nil
			monster.hp = monster.def.hp
			monster.hitters = {}
			monster.part:SetAttribute("Hp", monster.hp)
		end
	end
	-- (Un monstre n'attaque JAMAIS le premier : il ne se bat que contre le joueur qui l'a frappé. Demande du joueur :
	-- « 1 par 1 pour les combats, pas les packs de monstres, que ceux que j'attaque ».)

	local goal, speed = nil, monster.def.speed
	if target and targetRoot then
		local away = flat(targetRoot.Position - position)
		-- Tant qu'un familier tient debout, le monstre s'arrête plus loin du joueur : ce sont eux qui viennent à lui.
		local reach = if guarded(target) then math.max(monster.reach, Config.PET_GUARD + monster.def.scale) else monster.reach
		if away.Magnitude > reach - 1.5 then
			goal = position + away.Unit * (away.Magnitude - reach + 2.5)
		elseif now >= (monster.nextHit or 0) and not Monsters.peaceful then
			monster.nextHit = now + Config.MONSTER_COOLDOWN
			monster.part:SetAttribute("HitAt", workspace:GetServerTimeNow())
			strike(monster, target, targetRoot.Parent and targetRoot.Parent:FindFirstChildOfClass("Humanoid"))
			-- Ses familiers le défendent : ils visent ce monstre s'il n'a pas déjà une cible.
			local fight = fightOf(target)
			fight.last = os.clock()
			if not fight.target then
				fight.target = monster.id
				target:SetAttribute("Target", monster.id)
			end
		end
		if away.Magnitude > 0.5 then
			monster.facing = away.Unit
		end
	else
		local fromHome = flat(monster.home - position)
		if fromHome.Magnitude > 12 then
			-- Il rentre chez lui, et se soigne en route.
			goal = monster.home
			if monster.hp < monster.def.hp then
				monster.hp = monster.def.hp
				monster.hitters = {}
				monster.part:SetAttribute("Hp", monster.hp)
			end
		else
			speed *= 0.35
			if now >= monster.nextWander then
				monster.nextWander = now + random:NextNumber(3, 7)
				local angle = random:NextNumber(0, math.pi * 2)
				monster.wander = if monster.boss then monster.home else monster.home + Vector3.new(math.cos(angle), 0, math.sin(angle)) * random:NextNumber(1, 4)
			end
			goal = monster.wander
		end
	end
	if goal then
		local away = flat(goal - position)
		if away.Magnitude > 0.6 then
			local move = math.min(away.Magnitude, speed * dt)
			position += away.Unit * move
			monster.facing = away.Unit
		end
	end
	if position ~= monster.position or target then
		monster.position = position
		monster.part.CFrame = CFrame.lookAt(position, position + (monster.facing or Vector3.zAxis))
	end
end

-- VOYAGER : le bouton « BASE » ramène le joueur dans son espace ; le bouton « ZONE » le pose à l'entrée de la zone
-- la plus lointaine qu'il a ouverte (ou d'une zone ouverte donnée). Le combat en cours est oublié.
function Monsters.travel(player: Player, where: any): boolean
	local data = PlayerData.get(player)
	if not data or not rootOf(player) then
		return false
	end
	local fight = fightOf(player)
	fight.target = nil
	player:SetAttribute("Target", 0)
	for _, monster in monsters do
		if monster.target == player then
			monster.target = nil
		end
	end
	if where == "base" then
		Gym.toGym(player)
		return true
	end
	local index = math.clamp(if type(where) == "number" then math.floor(where) else data.zone, 1, data.zone)
	player.Character:PivotTo(CFrame.new(0, 4, zones[index].zMin + 10) * CFrame.Angles(0, math.pi, 0))
	return true
end

-- EN COMBAT : le joueur vise un monstre, ou un monstre en a apres lui. (Pendant ce temps, on ne change pas son
-- equipe : sinon il remplacerait a volonte un familier a terre par un autre tout neuf.)
function Monsters.inCombat(player: Player): boolean
	local fight = fights[player]
	if fight and fight.target then
		return true
	end
	for _, monster in monsters do
		if monster.target == player and not monster.dead then
			return true
		end
	end
	return false
end

-- Pour les tests : la liste des monstres { id, zone, rank, animal, hp, dead, position }, et de quoi en blesser un.
function Monsters.list()
	local list = {}
	for id, monster in monsters do
		list[id] = { id = id, zone = monster.zone, rank = monster.rank, chest = monster.chest, animal = monster.animal, hp = monster.hp, max = monster.def.hp, dead = monster.dead, position = monster.position, boss = monster.boss }
	end
	return list
end
function Monsters.hurt(player: Player, id: number, amount: number)
	if monsters[id] then
		hurt(monsters[id], player, amount, "sword")
	end
end

function Monsters.start(world, notifier)
	notify = notifier
	zones = world.zones
	lootEvent = Instance.new("RemoteEvent")
	lootEvent.Name = "Loot"
	lootEvent.Parent = ReplicatedStorage
	local attackEvent = Instance.new("RemoteEvent")
	attackEvent.Name = "Attack"
	attackEvent.Parent = ReplicatedStorage
	attackEvent.OnServerEvent:Connect(function(player)
		Monsters.attack(player)
	end)
	-- La boutique : améliorer l'épée (le même achat qu'à la forge).
	local swordEvent = Instance.new("RemoteEvent")
	swordEvent.Name = "BuySword"
	swordEvent.Parent = ReplicatedStorage
	swordEvent.OnServerEvent:Connect(function(player)
		Gym.buySword(player)
	end)
	local travelEvent = Instance.new("RemoteEvent")
	travelEvent.Name = "Travel"
	travelEvent.Parent = ReplicatedStorage
	local traveled = {}
	travelEvent.OnServerEvent:Connect(function(player, where)
		-- (Pas plus d'un voyage par seconde.)
		if os.clock() - (traveled[player] or 0) > 1 then
			traveled[player] = os.clock()
			Monsters.travel(player, where)
		end
	end)

	for _, zone in zones do
		for _, point in zone.spawns do
			create(zone, point.rank, point.position)
		end
		create(zone, 6, zone.boss)
		for _, position in zone.chests do
			create(zone, 0, position)
		end
	end
	PlayerData.onLoaded(publishTeam)
	Players.PlayerRemoving:Connect(function(player)
		fights[player] = nil
		for _, monster in monsters do
			monster.hitters[player] = nil
			if monster.target == player then
				monster.target = nil
			end
		end
	end)

	-- Les monstres bougent dix fois par seconde.
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(TICK)
			local now = os.clock()
			local dt = math.min(now - last, 0.5)
			last = now
			for _, monster in monsters do
				if not monster.dead and not monster.chest then
					stepMonster(monster, dt, now)
				end
			end
		end
	end)

	-- Chaque seconde : les familiers frappent la cible de leur joueur ; la cible est oubliée quand le combat est
	-- fini ; et un joueur entré dans une zone qu'il n'a pas ouverte est reposé devant sa porte.
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.clock()
			for _, player in Players:GetPlayers() do
				local root = rootOf(player)
				local data = PlayerData.get(player)
				local fight = fights[player]
				-- Les familiers ne se relèvent JAMAIS pendant un combat : seulement après quelques secondes sans cible
				-- et sans monstre aux trousses.
				if fight then
					local busy = fight.target ~= nil
					if not busy then
						for _, monster in monsters do
							if monster.target == player and not monster.dead then
								busy = true
								break
							end
						end
					end
					if busy then
						fight.hurtAt = now
					end
				end
				-- HORS COMBAT, la vie du joueur remonte vite : REGEN de sa vie par seconde, apres REGEN_DELAY secondes
				-- sans combat. (Pendant un combat, seulement la petite regeneration de Roblox.)
				local calm = fight == nil or now - fight.hurtAt > Config.REGEN_DELAY
				local humanoid = root and root.Parent and root.Parent:FindFirstChildOfClass("Humanoid")
				if calm and humanoid and humanoid.Health > 0 and humanoid.Health < humanoid.MaxHealth then
					humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + humanoid.MaxHealth * Config.REGEN)
				end
				if fight and next(fight.hp) and fight.hurtAt ~= now then
					-- Le combat est fini : les familiers à terre se relèvent, et tous se soignent, seconde après seconde.
					for _, member in teamOf(player) do
						if fight.hp[member.key] then
							local hp = math.min(member.max, fight.hp[member.key] + math.ceil(member.max * Config.PET_REGEN))
							fight.hp[member.key] = if hp >= member.max then nil else hp
						end
					end
					publishTeam(player)
				end
				if fight and fight.target then
					local monster = monsters[fight.target]
					local fighting = root and monster and not monster.dead and now - fight.last < 8 and flat(monster.position - root.Position).Magnitude <= Config.PET_REACH
					if fighting then
						local damage = Monsters.teamDamage(player)
						if damage > 0 then
							fight.last = if monster.target == player then now else fight.last
							hurt(monster, player, damage, "pet")
						end
					else
						fight.target = nil
						player:SetAttribute("Target", 0)
					end
				end
				if root and data then
					for index, zone in zones do
						if index > data.zone and root.Position.Z > zone.zMin + 3 then
							player.Character:PivotTo(CFrame.new(0, 4, zones[data.zone].zMax - 14))
							notify(player, "zoneLocked", index)
							break
						end
					end
				end
			end
		end
	end)
end

return Monsters

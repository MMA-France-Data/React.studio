-- Test en images du jeu « Monde » : la base, les zones, un combat, les familiers qui encaissent, la forge, la porte.
--   powershell -ExecutionPolicy Bypass -File tools\studio-test\run.ps1 -Test world -Seconds 150
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

return function(log)
	local debug = ServerStorage:WaitForChild("SurviveDebug", 30)
	local function D(...)
		return debug:Invoke(...)
	end
	local function check(condition, name, detail)
		log("Info", (if condition then "[PASS] " else "[FAIL] ") .. name .. (if detail ~= nil then "  (" .. tostring(detail) .. ")" else ""))
	end
	local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
	while not player:GetAttribute("Loaded") do
		task.wait(0.1)
	end
	D("Income", false)
	D("Peaceful", true)
	local function shot(name: string, from: Vector3, target: Vector3)
		workspace:SetAttribute("ShotCam", CFrame.lookAt(from, target))
		task.wait(0.9)
		log("Info", "SHOT:world_" .. name)
		task.wait(1.2)
		workspace:SetAttribute("ShotCam", nil)
	end
	local function go(position: Vector3)
		player.Character:PivotTo(CFrame.new(position + Vector3.new(0, 4, 0)))
		task.wait(0.4)
	end
	local function humanoid()
		return player.Character:FindFirstChildOfClass("Humanoid")
	end
	task.wait(2)
	local zones = D("Zones")

	-- 1. Le départ : sans familier.
	local data = D("Data")
	check(#data.team == 0 and next(data.spots) == nil, "un nouveau joueur commence sans familier")
	check(#D("Monsters") == 3 * 30, "30 par zone : 5 camps de 5 monstres, le boss et 4 coffres", #D("Monsters"))

	-- 2. Les décors.
	shot("base", Vector3.new(0, 70, -130), Vector3.new(0, 0, 10))
	for index, zone in zones do
		go(Vector3.new(0, 0, zone.zMin + 20))
		shot("zone" .. index .. "_haut", Vector3.new(0, 150, zone.zMin - 70), Vector3.new(0, 0, zone.zMin + 130))
		shot("zone" .. index .. "_sol", Vector3.new(8, 9, zone.zMin + 6), Vector3.new(-20, 6, zone.zMin + 90))
	end

	-- 3. Un combat : à côté d'un monstre du premier camp, attaque automatique.
	local first
	for _, monster in D("Monsters") do
		if monster.zone == 1 and monster.rank == 1 then
			first = monster
			break
		end
	end
	D("Peaceful", false)
	go(first.position + Vector3.new(7, 0, 0))
	-- (Posé à 25 studs du canard : l'attaque automatique doit y aller toute seule.)
	go(first.position + Vector3.new(25, 0, 0))
	workspace:SetAttribute("AutoAttack", true)
	task.wait(1.6)
	local root = player.Character.HumanoidRootPart.Position
	shot("combat", root + Vector3.new(10, 8, -14), root + Vector3.new(-3, 2, 0))
	local started = os.clock()
	while os.clock() - started < 30 and D("Data").xp == 0 and D("Data").level == 1 do
		task.wait(0.5)
	end
	data = D("Data")
	check(data.coins > 0 and (data.xp > 0 or data.level > 1), "un monstre battu donne des pièces et de l'XP", data.coins .. " pièces, " .. data.xp .. " XP")
	check(humanoid().Health > 40, "seul, à l'épée, on bat un canard sans presque rien perdre", math.floor(humanoid().Health))
	workspace:SetAttribute("AutoAttack", false)
	-- Un canard lâche un œuf de canard.
	check(D("Egg", 1, 1) == true and (player:GetAttribute("BagNext") or "") == "", "un œuf trouvé va dans le sac, pas sur la tête")
	check(D("Take", "Duck", 1) == true and string.match(player:GetAttribute("BagNext") or "", "^Duck:1:") ~= nil, "cliquer sur l'œuf le sort sur la tête (un canard lâche un œuf de canard)", player:GetAttribute("BagNext"))
	check(D("Take", "Duck", 1) == true and (player:GetAttribute("BagNext") or "") == "", "recliquer dessus le range")
	D("Pet", "Duck", 1)

	-- 4. Les familiers encaissent d'abord : le joueur garde toute sa vie.
	D("Pet", "Goat", 5)
	D("Pet", "Sheep", 4)
	task.wait(5.5)
	local strong
	for _, monster in D("Monsters") do
		if monster.zone == 1 and monster.rank == 3 and not monster.dead then
			strong = monster
			break
		end
	end
	go(strong.position + Vector3.new(9, 0, 0))
	-- Un monstre n'attaque pas le premier : sans le frapper, rien ne se passe.
	task.wait(2.5)
	check((player:GetAttribute("Target") or 0) == 0 and string.match(player:GetAttribute("TeamHp") or "", "^(%d+)/(%d+)") ~= nil, "un monstre qu'on ne frappe pas n'attaque pas", player:GetAttribute("TeamHp"))
	local healthBefore = humanoid().Health
	D("Hurt", strong.id, 1)
	-- (On guette le premier coup : le combat est court, et les familiers se soignent vite ensuite.)
	local struck, seen = false, ""
	local since = os.clock()
	while os.clock() - since < 6 and not struck do
		local now, max = string.match(player:GetAttribute("TeamHp") or "", "^(%d+)/(%d+)")
		struck = tonumber(now) ~= nil and tonumber(now) < tonumber(max)
		seen = player:GetAttribute("TeamHp")
		task.wait(0.1)
	end
	root = player.Character.HumanoidRootPart.Position
	shot("equipe", root + Vector3.new(12, 9, -15), root + Vector3.new(-4, 2, 0))
	check(struck, "le monstre frappe d'abord le premier familier", seen)
	check(humanoid().Health >= healthBefore - 0.5, "le joueur n'a rien pris tant que ses familiers tiennent", humanoid().Health)
	check(D("TeamDamage") > 0, "l'équipe fait des dégâts", D("TeamDamage"))
	D("Peaceful", true)
	-- S'eloigner : le monstre abandonne et retrouve toute sa vie.
	local far
	for _, monster in D("Monsters") do
		if monster.zone == 1 and monster.rank == 5 and not monster.dead then
			far = monster
			break
		end
	end
	go(far.position + Vector3.new(8, 0, 0))
	D("Hurt", far.id, 500)
	task.wait(0.5)
	go(far.position + Vector3.new(60, 0, 0))
	task.wait(1.5)
	local after = D("Monsters")[far.id]
	check(after.hp == after.max and (player:GetAttribute("Target") or 0) == 0, "on s'eloigne : le monstre abandonne et retrouve toute sa vie", after.hp .. "/" .. after.max)

	-- Un coffre : il ne se défend pas, et donne beaucoup de pièces.
	local chest
	for _, monster in D("Monsters") do
		if monster.zone == 1 and monster.chest then
			chest = monster
			break
		end
	end
	go(chest.position + Vector3.new(7, 0, 0))
	task.wait(0.8)
	root = player.Character.HumanoidRootPart.Position
	shot("coffre", root + Vector3.new(8, 7, -12), chest.position + Vector3.new(0, 2, 0))
	local before = D("Data").coins
	D("Hurt", chest.id, 1e9)
	check(D("Data").coins >= before + 150, "un coffre ouvert donne ses pièces", D("Data").coins - before)

	-- Nourrir : le mouton (place 3) mange le canard (place 1) et reçoit 75 % de son XP.
	local before2 = D("Data")
	local duckXp, sheep = before2.spots["1"], before2.spots["3"]
	local fed = D("Feed", 3, 1)
	local after2 = D("Data")
	check(fed ~= nil and after2.spots["1"] == nil and after2.spots["3"] ~= nil, "nourrir : le familier mangé disparaît, l'autre reçoit son XP", tostring(fed) .. " XP, canard " .. tostring(duckXp and duckXp.a) .. ", mouton " .. tostring(sheep and sheep.a))

	-- 5. La forge.
	D("Give", 8000)
	check(D("BuySword") == true and D("Data").sword == 2, "la forge améliore l'épée", D("Data").sword)

	-- 6. La porte de la zone 2 : fermée, puis ouverte par le boss.
	go(Vector3.new(0, 0, zones[2].zMin + 12))
	task.wait(2.2)
	check(player.Character.HumanoidRootPart.Position.Z < zones[2].zMin, "zone 2 fermée : le joueur est reposé devant la porte", math.floor(player.Character.HumanoidRootPart.Position.Z))
	local boss
	for _, monster in D("Monsters") do
		if monster.zone == 1 and monster.boss then
			boss = monster
		end
	end
	go(boss.position + Vector3.new(14, 0, -6))
	task.wait(1)
	root = player.Character.HumanoidRootPart.Position
	shot("boss", root + Vector3.new(8, 10, -22), boss.position + Vector3.new(0, 6, 0))
	-- L attaque du boss (le cheval se cabre et retombe) : on le laisse frapper, et on le photographie de profil.
	D("Level", 60)
	D("Peaceful", false)
	go(boss.position + Vector3.new(9, 0, 0))
	D("Hurt", boss.id, 1)
	task.wait(1.5)
	for i = 1, 6 do
		local at = D("Monsters")[boss.id].position
		workspace:SetAttribute("ShotCam", CFrame.lookAt(at + Vector3.new(2, 7, -24), at + Vector3.new(2, 6, 0)))
		task.wait(0.25 + i * 0.17)
		log("Info", "SHOT:world_cheval_" .. i)
		task.wait(1.1)
	end
	workspace:SetAttribute("ShotCam", nil)
	D("Peaceful", true)
	-- Le coup d'epee en gros plan, contre le boss (il a beaucoup de vie : le combat dure).
	go(boss.position + Vector3.new(9, 0, 0))
	workspace:SetAttribute("AutoAttack", true)
	D("Attack")
	task.wait(1)
	root = player.Character.HumanoidRootPart.Position
	for i = 1, 4 do
		shot("frappe_" .. i, root + Vector3.new(5, 4, -9), root + Vector3.new(-1, 2, 0))
	end
	workspace:SetAttribute("AutoAttack", false)
	local bag = D("Data").bag
	D("Hurt", boss.id, 1e9)
	task.wait(0.5)
	data = D("Data")
	check(data.zone == 2, "battre le boss ouvre la zone 2", data.zone)
	local leveled = false
	for _, key in data.team do
		leveled = leveled or (data.spots[key].lv or 1) > 1 or (data.spots[key].xp or 0) > 0
	end
	check(leveled, "les familiers de l'équipe gagnent de l'XP aussi")
	local _ = bag
	go(Vector3.new(0, 0, zones[2].zMin + 12))
	task.wait(2.2)
	check(player.Character.HumanoidRootPart.Position.Z > zones[2].zMin, "zone 2 ouverte : le joueur y reste")
	-- La liste des familiers, puis l'ecran des telephones.
	root = player.Character.HumanoidRootPart.Position
	workspace:SetAttribute("OpenPets", true)
	shot("liste", root + Vector3.new(0, 7, -16), root + Vector3.new(0, 4, 20))
	workspace:SetAttribute("OpenPets", false)
	task.wait(1.2)
	-- La fenetre des oeufs : trois dans le sac, un qui couve.
	D("Egg", 1, 1)
	D("Egg", 1, 1)
	D("Egg", 1, 3)
	D("Egg", 1, 2)
	D("Place", 12, 16)
	workspace:SetAttribute("OpenEggs", true)
	shot("oeufs", root + Vector3.new(0, 7, -16), root + Vector3.new(0, 4, 20))
	workspace:SetAttribute("OpenEggs", false)
	task.wait(1.2)
	shot("panneau", Vector3.new(-10, 9, zones[1].zMin + 22), Vector3.new(-10, 10.5, zones[1].zMin + 41))
	workspace:SetAttribute("OpenShop", true)
	shot("boutique", root + Vector3.new(0, 7, -16), root + Vector3.new(0, 4, 20))
	workspace:SetAttribute("OpenShop", false)
	task.wait(1.2)
	workspace:SetAttribute("PhoneHud", true)
	shot("telephone", root + Vector3.new(0, 7, -16), root + Vector3.new(0, 4, 20))
	workspace:SetAttribute("PhoneHud", nil)

	-- 7. Les boutons de voyage.
	D("Travel", "base")
	task.wait(0.6)
	check(player.Character.HumanoidRootPart.Position.Z < zones[1].zMin, "le bouton BASE ramène dans son espace")
	D("Travel", 2)
	task.wait(0.6)
	local z = player.Character.HumanoidRootPart.Position.Z
	check(z > zones[2].zMin and z < zones[2].zMin + 30, "le bouton ZONE pose à l'entrée de la zone ouverte", math.floor(z))
	root = player.Character.HumanoidRootPart.Position
	shot("voyage", root + Vector3.new(0, 7, -16), root + Vector3.new(0, 4, 20))
	-- Les six epees, une par une, dans la main (de profil, au repos).
	D("Travel", "base")
	task.wait(1)
	for sword = 1, 6 do
		D("Sword", sword)
		task.wait(0.8)
		root = player.Character.HumanoidRootPart.Position
		shot("epee_" .. sword, root + Vector3.new(7, 2, -3), root + Vector3.new(0, 0.5, -1))
	end
	log("Info", "[SURVIVE] TEST:done")
end

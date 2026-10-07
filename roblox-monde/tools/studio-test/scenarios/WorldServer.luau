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

	-- 1. Le départ : un caneton dans l'équipe.
	local data = D("Data")
	check(#data.team == 1 and data.spots["1"] and data.spots["1"].a == "Duck", "un nouveau joueur a un caneton dans son équipe", data.spots["1"] and data.spots["1"].a)
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
	check((data.spots["1"].xp or 0) > 0 or (data.spots["1"].lv or 1) > 1, "le familier de l'équipe gagne de l'XP aussi", data.spots["1"].xp)
	workspace:SetAttribute("AutoAttack", false)

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
	D("Hurt", strong.id, 1)
	task.wait(5)
	root = player.Character.HumanoidRootPart.Position
	shot("equipe", root + Vector3.new(12, 9, -15), root + Vector3.new(-4, 2, 0))
	local now, max = string.match(player:GetAttribute("TeamHp") or "", "^(%d+)/(%d+)")
	check(tonumber(now) ~= nil and tonumber(now) < tonumber(max), "le monstre frappe d'abord le premier familier", player:GetAttribute("TeamHp"))
	check(humanoid().Health >= humanoid().MaxHealth - 0.5, "le joueur n'a rien pris tant que ses familiers tiennent", humanoid().Health)
	check(D("TeamDamage") > 0, "l'équipe fait des dégâts", D("TeamDamage"))
	D("Peaceful", true)

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
	check(D("Data").coins >= before + 120, "un coffre ouvert donne ses pièces", D("Data").coins - before)

	-- 5. La forge.
	D("Give", 1000)
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
	local bag = D("Data").bag
	D("Hurt", boss.id, 1e9)
	task.wait(0.5)
	data = D("Data")
	check(data.zone == 2, "battre le boss ouvre la zone 2", data.zone)
	check(data.bag == bag + 1, "le boss lâche toujours un œuf", data.bag)
	go(Vector3.new(0, 0, zones[2].zMin + 12))
	task.wait(2.2)
	check(player.Character.HumanoidRootPart.Position.Z > zones[2].zMin, "zone 2 ouverte : le joueur y reste")
	log("Info", "[SURVIVE] TEST:done")
end

-- PETIT TEST (une cinquantaine de secondes), sans rejouer tout le jeu.
--   powershell -ExecutionPolicy Bypass -File tools/studio-test/run.ps1 -Test photo -Seconds 60
-- Ici : le décor des camps (plus rien de dur là où vivent les monstres) : la distance entre chaque monstre des cinq
-- mondes et le décor dur le plus proche ; le camp des béliers vu d'en haut ; et l'attaque automatique lancée DERRIÈRE
-- le gros rocher du fond : elle doit le contourner et arriver au monstre.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

return function(log)
	local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
	while not player:GetAttribute("Loaded") do
		task.wait(0.1)
	end
	local debug = ServerStorage:WaitForChild("SurviveDebug")
	task.wait(8)
	debug:Invoke("Tuto", 0)
	debug:Invoke("Zone", 5)
	debug:Invoke("Peaceful", true)
	local zones = workspace:WaitForChild("Zones")
	-- 1. Tous les monstres : à combien du bord du décor dur le plus proche (rocher, arbre, clôture, cabane...) ?
	local solids = {}
	for _, item in zones:GetDescendants() do
		if item:IsA("BasePart") and item.CanCollide and item.Size.Y > 1.5 and math.max(item.Size.X, item.Size.Z) < 45 and item.Position.Y - item.Size.Y / 2 < 4 then
			table.insert(solids, item)
		end
	end
	local tight, total = 0, 0
	for _, monster in CollectionService:GetTagged("Monster") do
		if monster:GetAttribute("Boss") ~= true then
			total += 1
			for _, item in solids do
				local gap = (Vector3.new(item.Position.X - monster.Position.X, 0, item.Position.Z - monster.Position.Z)).Magnitude - math.max(item.Size.X, item.Size.Z) / 2
				if gap < 4 then
					tight += 1
					log("Info", string.format("[PHOTO]   %s rang %d : %.1f studs de %s", tostring(monster:GetAttribute("Animal")), monster:GetAttribute("Rank") or 0, gap, item.Name))
					break
				end
			end
		end
	end
	log("Info", "[PHOTO] monstres à moins de 4 studs d'un décor dur : " .. tight .. " sur " .. total)
	-- 2. Le camp des béliers (monde 2), vu d'en haut.
	local center = Vector3.new(56, 0, zones.Zone2:GetAttribute("ZMin") + 92)
	local root = player.Character:WaitForChild("HumanoidRootPart")
	root.CFrame = CFrame.new(center + Vector3.new(0, 4, 0))
	task.wait(2.5)
	workspace:SetAttribute("ShotCam", CFrame.lookAt(center + Vector3.new(0, 120, 0.5), center))
	task.wait(1.5)
	log("Info", "SHOT:photo_camp_beliers")
	task.wait(1.2)
	workspace:SetAttribute("ShotCam", nil)
	-- 3. L'attaque automatique avec un MUR entre le joueur et le monstre (trop haut pour sauter par-dessus) : elle
	-- doit le contourner. Le joueur est à 15 studs d'un bélier, du côté du dehors (ce bélier est donc le plus
	-- proche, c'est lui que l'AUTO choisit), le mur au milieu, en travers.
	local target
	for _, monster in CollectionService:GetTagged("Monster") do
		if (monster.Position - center).Magnitude < 40 then
			target = monster
			break
		end
	end
	local outward = Vector3.new(target.Position.X - center.X, 0, target.Position.Z - center.Z).Unit
	local start = Vector3.new(target.Position.X, 4, target.Position.Z) + outward * 15
	local wall = Instance.new("Part")
	wall.Name = "TestWall"
	wall.Anchored = true
	wall.Size = Vector3.new(14, 9, 2)
	wall.CFrame = CFrame.lookAt(Vector3.new(target.Position.X, 4.5, target.Position.Z) + outward * 8, Vector3.new(target.Position.X, 4.5, target.Position.Z))
	wall.Color = Color3.fromRGB(255, 60, 60)
	wall.Parent = workspace
	root.CFrame = CFrame.lookAt(start, Vector3.new(target.Position.X, 4, target.Position.Z))
	task.wait(2)
	local function nearest(): number
		return (Vector3.new(target.Position.X - root.Position.X, 0, target.Position.Z - root.Position.Z)).Magnitude
	end
	local before = nearest()
	workspace:SetAttribute("AutoAttack", true)
	task.wait(4)
	workspace:SetAttribute("ShotCam", CFrame.lookAt(wall.Position + Vector3.new(0, 60, 0.5), wall.Position))
	task.wait(0.6)
	log("Info", "SHOT:photo_auto_mur")
	task.wait(1)
	workspace:SetAttribute("ShotCam", nil)
	task.wait(6.4)
	local after = nearest()
	log("Info", "[PHOTO] attaque auto derrière un mur : le bélier est à " .. math.floor(before) .. " studs au départ, " .. math.floor(after * 10) / 10 .. " studs après 12 s ; cible : " .. tostring(player:GetAttribute("Target")))
	workspace:SetAttribute("AutoAttack", false)
	log("Info", "[SURVIVE] TEST:done")
end

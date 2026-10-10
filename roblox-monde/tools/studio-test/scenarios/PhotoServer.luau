-- PETIT TEST (une minute et demie), sans rejouer tout le jeu.
--   powershell -ExecutionPolicy Bypass -File tools/studio-test/run.ps1 -Test photo -Seconds 120
-- Ici : un NOUVEAU joueur, qui n'a jamais battu un seul monstre, vient taper le canard doré géant. Il doit recevoir la
-- récompense du tout premier camp, et son tutoriel et son entonnoir ne doivent PAS croire qu'il a battu un canard.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)

return function(log)
	local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
	while not player:GetAttribute("Loaded") do
		task.wait(0.1)
	end
	local debug = ServerStorage:WaitForChild("SurviveDebug")
	task.wait(8)
	local passed, failed = 0, 0
	local function check(what: string, ok: boolean, detail: string?)
		if ok then
			passed += 1
		else
			failed += 1
		end
		log(if ok then "Info" else "Error", "[TEST] " .. (if ok then "OK   " else "RATE ") .. what .. (if detail then " : " .. detail else ""))
	end
	local function data()
		return debug:Invoke("Data")
	end
	check("au depart : tutoriel a l etape 1, entonnoir a la marche 1", player:GetAttribute("Tutorial") == 1 and debug:Invoke("Funnel").at == 1, "tutoriel " .. tostring(player:GetAttribute("Tutorial")) .. ", entonnoir " .. tostring(debug:Invoke("Funnel").at))
	player.CharacterAdded:Connect(function(character)
		task.wait(0.8)
		if (workspace:GetAttribute("DuckUntil") or 0) > 0 then
			character:PivotTo(CFrame.lookAt(Config.DUCK.spot + Vector3.new(0, 4, 16), Config.DUCK.spot + Vector3.new(0, 4, 0)))
			workspace:SetAttribute("AutoAttack", false)
			task.wait(0.15)
			workspace:SetAttribute("AutoAttack", true)
		end
	end)
	debug:Invoke("Duck", 3)
	task.wait(4.5)
	player.Character:PivotTo(CFrame.lookAt(Config.DUCK.spot + Vector3.new(0, 4, 16), Config.DUCK.spot + Vector3.new(0, 4, 0)))
	task.wait(0.4)
	workspace:SetAttribute("AutoAttack", true)
	local before = data()
	for _ = 1, 190 do
		task.wait(0.5)
		if (workspace:GetAttribute("DuckUntil") or 0) == 0 then
			break
		end
	end
	workspace:SetAttribute("AutoAttack", false)
	task.wait(3)
	local after = data()
	local gained = after.coins - before.coins
	log("Info", "[TEST] canard battu par un nouveau joueur : " .. tostring(player:GetAttribute("DuckHits")) .. " coups, pieces +" .. gained .. ", niveau " .. after.level .. ", XP " .. after.xp)
	check("il recoit la recompense du premier camp (15 canards : 1800 pieces)", gained == 120 * Config.DUCK.coins, "+" .. gained)
	check("... et de l XP", after.level > before.level or after.xp > before.xp, "niveau " .. after.level .. ", XP " .. after.xp)
	-- (Dans Studio, la molette de la souris change l'épée du joueur : si elle a bougé pendant le test, on la remet,
	-- et l'entonnoir, qui regarde aussi les épées, ne peut plus être jugé.)
	local sword = after.sword
	log("Info", "[TEST] epee a la fin : " .. sword .. (if sword ~= 1 then " (la molette de Studio l a changee pendant le test)" else ""))
	check("son tutoriel lui demande toujours de battre un canard (etape 1)", player:GetAttribute("Tutorial") == 1, "etape " .. tostring(player:GetAttribute("Tutorial")))
	if sword == 1 then
		check("son entonnoir n a pas compte de canard battu (marche 1)", debug:Invoke("Funnel").at == 1, "marche " .. tostring(debug:Invoke("Funnel").at))
	end
	-- Et s'il s'achète l'épée 2 avec les pièces du canard, sans avoir battu de monstre : toujours l'étape 1.
	debug:Invoke("Sword", 2)
	task.wait(1.5)
	check("meme avec l epee 2 achetee, le tutoriel reste a l etape 1 (il n a pas d oeuf a poser)", player:GetAttribute("Tutorial") == 1, "etape " .. tostring(player:GetAttribute("Tutorial")))
	log("Info", "SHOT:photo_nouveau_apres_canard")
	task.wait(1.2)
	log("Info", "[TEST] BILAN : " .. passed .. " reussis, " .. failed .. " rates")
	log("Info", "[SURVIVE] TEST:done")
end

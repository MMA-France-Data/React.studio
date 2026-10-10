-- PETIT TEST (une demi-minute), sans rejouer tout le jeu.
--   powershell -ExecutionPolicy Bypass -File tools/studio-test/run.ps1 -Test photo -Seconds 35
-- Ici : la quête de l'œuf quand le SAC D'ŒUFS EST PLEIN (60 œufs). L'œuf promis doit être donné quand même, la quête
-- doit passer à la suivante ; et une quête restée bloquée « finie » (30 / 30) doit se débloquer toute seule.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Pets = require(ReplicatedStorage.Shared.Pets)

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
	debug:Invoke("Tuto", 0)
	for _ = 1, 70 do
		debug:Invoke("Egg", 1, 2)
	end
	check("le sac d oeufs est plein (60)", debug:Invoke("Data").bag == Pets.MAX_BAG, tostring(debug:Invoke("Data").bag))
	-- 1. Une quête restée bloquée « finie » (comme la sienne) : 30 / 30 sur les canards.
	debug:Invoke("Quest", 1, 1, { 3, 30 })
	task.wait(2.5)
	check("la quete bloquee a 30 / 30 se debloque toute seule", debug:Invoke("Quest") == "1:2:1:0", debug:Invoke("Quest"))
	check("l oeuf promis est donne meme sac plein", debug:Invoke("Data").bag == Pets.MAX_BAG + 1, tostring(debug:Invoke("Data").bag))
	check("il se pose en premier", debug:Invoke("EggNow", "Duck", 1) == true)
	debug:Invoke("Hatch")
	local grade = "?"
	for _, spot in debug:Invoke("Data").spots do
		if spot.v and spot.a == "Duck" then
			grade = Pets.gradeOf(spot)
		end
	end
	check("et c est bien un canard de note S", grade == "S", "note " .. grade)
	-- 2. La suivante, en jouant : 30 coqs, sac toujours plein.
	debug:Invoke("Quest", 1, 2, { 3, 0 })
	debug:Invoke("Kill", { 1, 2 }, 30)
	check("30 coqs sac plein : l oeuf arrive et la quete passe au camp suivant", debug:Invoke("Quest") == "1:3:1:0" and debug:Invoke("Data").bag == Pets.MAX_BAG + 1, debug:Invoke("Quest") .. ", sac " .. tostring(debug:Invoke("Data").bag))
	task.wait(1.5)
	log("Info", "[TEST] quete affichee au joueur : " .. tostring(player:GetAttribute("Quest")))
	log("Info", "[TEST] BILAN : " .. passed .. " reussis, " .. failed .. " rates")
	log("Info", "[SURVIVE] TEST:done")
end

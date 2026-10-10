-- PETIT TEST (deux minutes et demie), sans rejouer tout le jeu.
--   powershell -ExecutionPolicy Bypass -File tools/studio-test/run.ps1 -Test photo -Seconds 175
-- Ici : les QUÊTES (compte des monstres, récompenses, œuf de note S garantie, enchaînement), les MONSTRES DORÉS, et le
-- CANARD DORÉ GÉANT (ronds à esquiver, mort sans perdre ses coups, victoire et récompense).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
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
	local function root()
		return player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	end
	local function data()
		return debug:Invoke("Data")
	end
	local function potions(): string
		return tostring(player:GetAttribute("Potions"))
	end

	-- 1. LES QUÊTES.
	check("pas de quete pendant le tutoriel", (player:GetAttribute("Quest") or "") == "", tostring(player:GetAttribute("Quest")))
	debug:Invoke("Tuto", 0)
	task.wait(2.5)
	check("la premiere quete arrive a la fin du tutoriel (les canards)", player:GetAttribute("Quest") == "1:1:1:0", tostring(player:GetAttribute("Quest")))
	log("Info", "SHOT:photo_quete_1")
	task.wait(1.2)
	local coins = data().coins
	debug:Invoke("Kill", { 1, 3 }, 5)
	check("un autre animal ne compte pas", debug:Invoke("Quest") == "1:1:1:0", debug:Invoke("Quest"))
	debug:Invoke("Kill", { 1, 1 }, 10)
	check("10 canards : des pieces, puis la quete 2", debug:Invoke("Quest") == "1:1:2:0" and data().coins - coins == 120 * Config.QUESTS.coins, "+" .. (data().coins - coins) .. " pieces, quete " .. debug:Invoke("Quest"))
	debug:Invoke("Kill", { 1, 1 }, 20)
	check("20 canards : une potion, puis la quete 3", debug:Invoke("Quest") == "1:1:3:0" and string.find(potions(), "xp:1") ~= nil, potions() .. ", quete " .. debug:Invoke("Quest"))
	debug:Invoke("Kill", { 1, 1 }, 12)
	task.wait(1.5)
	log("Info", "SHOT:photo_quete_3")
	task.wait(1.2)
	local bag = data().bag
	debug:Invoke("Kill", { 1, 1 }, 18)
	check("30 canards : un oeuf, puis le camp suivant (coqs)", debug:Invoke("Quest") == "1:2:1:0" and data().bag == bag + 1, "oeufs au sac +" .. (data().bag - bag) .. ", quete " .. debug:Invoke("Quest"))
	debug:Invoke("EggNow", "Duck", 1)
	debug:Invoke("Hatch")
	local grade = "?"
	for _, spot in data().spots do
		if spot.v and spot.a == "Duck" then
			grade = Pets.gradeOf(spot)
		end
	end
	check("l oeuf de la quete donne bien un canard de note S", grade == "S", "note " .. grade)
	debug:Invoke("Quest", 1, 6)
	local before = data().coins
	debug:Invoke("Kill", { 1, 6 }, 1)
	check("le boss : potion de rang + pieces, puis le monde 2", debug:Invoke("Quest") == "2:1:1:0" and string.find(potions(), "rank:1") ~= nil and data().coins > before, potions() .. ", quete " .. debug:Invoke("Quest"))

	-- 2. LES MONSTRES DORÉS : tous dorés pour l'essai, dans le camp des canards.
	debug:Invoke("Golden", true)
	debug:Invoke("Peaceful", true)
	debug:Invoke("Sword", 3)
	local zmin = workspace.Zones.Zone1:GetAttribute("ZMin")
	root().CFrame = CFrame.new(-52, 4, zmin + 48)
	task.wait(1)
	workspace:SetAttribute("AutoAttack", true)
	local coins0, bag0 = data().coins, data().bag
	task.wait(9)
	workspace:SetAttribute("AutoAttack", false)
	local golden = 0
	for _, part in CollectionService:GetTagged("Monster") do
		if part:GetAttribute("Golden") and not part:GetAttribute("Event") and (part:GetAttribute("Hp") or 0) > 0 then
			golden += 1
		end
	end
	log("Info", "SHOT:photo_monstre_dore")
	task.wait(1.2)
	local gained = data().coins - coins0
	check("monstres dores : ils reviennent dores, paient x10 et lachent leur oeuf", golden > 0 and gained >= 1200 and data().bag > bag0, golden .. " dores vivants, +" .. gained .. " pieces, oeufs +" .. (data().bag - bag0))
	debug:Invoke("Golden", false)
	-- L'œuf d'un monstre doré est DORÉ, et le familier qui en sort a ses stats doublées.
	local list = tostring(player:GetAttribute("BagList"))
	check("l oeuf d un monstre dore est un oeuf dore (dans le sac)", string.find(list, "Duck:1:1:") ~= nil, list)
	check("un oeuf dore se pose d un clic", debug:Invoke("EggNow", "Duck", 1, true) == true)
	debug:Invoke("Hatch")
	local goldenPet
	for _, spot in data().spots do
		if spot.v and spot.g then
			goldenPet = spot
		end
	end
	if goldenPet then
		local plain = table.clone(goldenPet)
		plain.g = nil
		check("le canard dore tape 2 fois plus fort et a 2 fois plus de vie", math.abs(Pets.damageOf(goldenPet) - Pets.damageOf(plain) * 2) <= 1 and math.abs(Pets.healthOf(goldenPet) - Pets.healthOf(plain) * 2) <= 1, Pets.damageOf(plain) .. " -> " .. Pets.damageOf(goldenPet) .. " de degats, " .. Pets.healthOf(plain) .. " -> " .. Pets.healthOf(goldenPet) .. " de vie")
		check("il rapporte 2 fois plus de pieces", math.abs(Pets.incomeOf(goldenPet.a, goldenPet.v, true) - Pets.incomeOf(goldenPet.a, goldenPet.v) * 2) < 0.001)
		local seen = false
		for _, spot in Pets.decode(player:GetAttribute("Spots")) do
			if spot.v and spot.g then
				seen = true
			end
		end
		check("l ecran du joueur sait qu il est dore", seen)
	else
		check("un familier dore est ne de l oeuf dore", false)
	end
	task.wait(1)

	debug:Invoke("Travel", "base")
	task.wait(2)
	workspace:SetAttribute("OpenPanel", "PetPanel")
	task.wait(1.5)
	log("Info", "SHOT:photo_familier_dore")
	task.wait(1.2)
	workspace:SetAttribute("OpenPanel", "")

	-- 3. LE CANARD DORÉ GÉANT. Le joueur tape en AUTO sans jamais esquiver : il meurt, revient, et gagne quand même.
	local deaths = 0
	local function watch(character)
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.Died:Connect(function()
			deaths += 1
		end)
	end
	watch(player.Character)
	player.CharacterAdded:Connect(function(character)
		watch(character)
		task.wait(0.8)
		if (workspace:GetAttribute("DuckUntil") or 0) > 0 then
			-- (Comme un joueur qui revient à pied et relance l'AUTO sur place.)
			character:PivotTo(CFrame.lookAt(Config.DUCK.spot + Vector3.new(0, 4, 16), Config.DUCK.spot + Vector3.new(0, 4, 0)))
			workspace:SetAttribute("AutoAttack", false)
			task.wait(0.15)
			workspace:SetAttribute("AutoAttack", true)
		end
	end)
	debug:Invoke("Duck", 3)
	task.wait(4.5)
	local boss
	for _, part in CollectionService:GetTagged("Monster") do
		if part:GetAttribute("Event") then
			boss = part
		end
	end
	check("le canard apparait dans la base", boss ~= nil and (boss.Position - Config.DUCK.spot).Magnitude < 1, "coups a donner : " .. tostring(boss and boss:GetAttribute("MaxHp")))
	root().CFrame = CFrame.lookAt(Config.DUCK.spot + Vector3.new(0, 4, 16), Config.DUCK.spot + Vector3.new(0, 4, 0))
	task.wait(0.4)
	workspace:SetAttribute("AutoAttack", true)
	local coinsBefore, bagBefore, potionsBefore = data().coins, data().bag, potions()
	local xpBefore = data().level * 1000000 + data().xp
	local shot, lowest = false, math.huge
	local hitsWhenDead = -1
	for _ = 1, 200 do
		task.wait(0.5)
		local hits = player:GetAttribute("DuckHits") or 0
		if deaths > 0 and hitsWhenDead < 0 then
			hitsWhenDead = hits
		end
		if hitsWhenDead >= 0 then
			lowest = math.min(lowest, hits)
		end
		if not shot and #workspace.GoldenDuck:GetChildren() >= 4 then
			shot = true
			workspace:SetAttribute("ShotCam", CFrame.lookAt(Config.DUCK.spot + Vector3.new(30, 34, 52), Config.DUCK.spot + Vector3.new(0, 8, 0)))
			task.wait(0.4)
			log("Info", "SHOT:photo_canard_combat")
			task.wait(0.9)
			workspace:SetAttribute("ShotCam", nil)
		end
		if (workspace:GetAttribute("DuckUntil") or 0) == 0 then
			break
		end
	end
	workspace:SetAttribute("AutoAttack", false)
	task.wait(1.5)
	local after = data()
	log("Info", "[TEST] canard : " .. deaths .. " morts, coups au moment de la 1re mort " .. hitsWhenDead .. ", coups a la fin " .. tostring(player:GetAttribute("DuckHits")) .. ", pieces +" .. (after.coins - coinsBefore) .. ", oeufs +" .. (after.bag - bagBefore) .. ", potions " .. potionsBefore .. " -> " .. potions())
	check("les ronds tuent celui qui n esquive pas", deaths >= 1, deaths .. " morts")
	check("mourir ne fait pas perdre ses coups", hitsWhenDead >= 0 and lowest >= hitsWhenDead, "jamais descendu sous " .. hitsWhenDead)
	check("canard battu : des pieces selon sa progression (15 canards, son camp le plus fort)", after.coins - coinsBefore >= 120 * Config.DUCK.coins and after.coins - coinsBefore < 120 * Config.DUCK.coins + 400, "+" .. (after.coins - coinsBefore) .. " pieces")
	check("... et de l XP", after.level * 1000000 + after.xp > xpBefore, "niveau " .. after.level .. ", XP " .. after.xp)
	check("... et rien d autre (ni oeuf, ni potion)", after.bag == bagBefore and potions() == potionsBefore, "oeufs +" .. (after.bag - bagBefore) .. ", potions " .. potions())
	check("le minuteur repart pour le suivant", (workspace:GetAttribute("DuckAt") or 0) - os.time() > Config.DUCK.every - 30, tostring((workspace:GetAttribute("DuckAt") or 0) - os.time()) .. " s")
	log("Info", "[TEST] BILAN : " .. passed .. " reussis, " .. failed .. " rates")
	log("Info", "[SURVIVE] TEST:done")
end

-- TEST DE LA SAUVEGARDE (une minute), avec une fausse sauvegarde en mémoire (attribut « FakeStore », mkproj.cjs) :
--   powershell -ExecutionPolicy Bypass -File tools/studio-test/run.ps1 -Test save -Seconds 70
-- 1. Le joueur avance (pièces, familiers, œuf, potions, un cadeau pris, du temps de jeu), part et revient : ce que le
--    serveur relit doit être EXACTEMENT ce qu'il avait (surtout les cadeaux : data.gt et data.gs).
-- 2. Le verrou entre serveurs : un autre serveur tient encore la sauvegarde ; celui-ci doit attendre qu'il la
--    libère et lire les bonnes données, et ne jamais rester bloqué s'il ne la libère pas.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

return function(log)
	local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
	while not player:GetAttribute("Loaded") do
		task.wait(0.1)
	end
	local debug = ServerStorage:WaitForChild("SurviveDebug")
	task.wait(6)
	local passed, failed = 0, 0
	local function check(what: string, ok: boolean, detail: string?)
		if ok then
			passed += 1
		else
			failed += 1
		end
		log(if ok then "Info" else "Error", "[SAVE] " .. (if ok then "OK   " else "RATÉ ") .. what .. (if detail then " : " .. detail else ""))
	end

	-- 1. Avancer, puis partir et revenir.
	debug:Invoke("Pet", "Pig", 3)
	debug:Invoke("Pet", "Duck", 1)
	debug:Invoke("Pet", "Sheep", 4)
	debug:Invoke("ToBag", 3)
	debug:Invoke("Egg", 1, 2)
	debug:Invoke("Egg", 1, 1)
	debug:Invoke("EggNow", "Rooster", 2)
	debug:Invoke("Give", 5000)
	debug:Invoke("Sword", 3)
	debug:Invoke("Potion", "rank", 2)
	debug:Invoke("Potion", "xp", 1)
	debug:Invoke("Gift", 0)
	debug:Invoke("Claim") -- le premier cadeau est pris : le prochain est le n° 2, dans 15 minutes
	task.wait(5) -- du temps de jeu : le minuteur du cadeau a avancé
	local now = debug:Invoke("Data")
	local giftIn, giftStep = player:GetAttribute("GiftIn"), player:GetAttribute("GiftStep")
	local back = debug:Invoke("Saved")
	log("Info", "[SAVE] avant le départ : cadeau n° " .. tostring(giftStep) .. " dans " .. tostring(giftIn) .. " s, pièces " .. now.coins)
	log("Info", "[SAVE] relu au retour  : cadeau n° " .. tostring(back.gs) .. ", temps joué " .. tostring(back.gt) .. " s, pièces " .. tostring(back.coins) .. ", potions " .. tostring(back.potions))
	check("la lecture marche", back.read == true)
	check("le verrou est enlevé au départ", back.locked == false)
	check("le NUMÉRO du prochain cadeau est gardé", back.gs == giftStep and back.gc == giftStep - 1, tostring(back.gs) .. ", pris aujourd'hui " .. tostring(back.gc) .. " (attendu " .. tostring(giftStep) .. ")")
	check("le TEMPS du cadeau est gardé", math.abs((900 - back.gt) - giftIn) <= 2, "reste " .. tostring(900 - back.gt) .. " s (attendu " .. tostring(giftIn) .. ")")
	check("le temps du cadeau a bien avancé pendant le jeu", back.gt >= 4, tostring(back.gt) .. " s")
	check("les pièces sont gardées", math.abs(back.coins - now.coins) <= 60, tostring(back.coins) .. " (attendu " .. now.coins .. ")")
	check("l'épée et le niveau sont gardés", back.sword == now.sword and back.level == now.level)
	local rank, xp, coins, damage = string.match(player:GetAttribute("Potions") or "", "rank:(%d+),xp:(%d+),coins:(%d+),damage:(%d+)")
	local expected = tostring(rank) .. "/" .. tostring(xp) .. "/" .. tostring(coins) .. "/" .. tostring(damage)
	check("les potions sont gardées", back.potions == expected, tostring(back.potions) .. " (attendu " .. expected .. ")")
	check("les familiers, l'œuf et le sac sont gardés", back.pets == 2 and back.eggs == 1 and back.store == 1 and back.bag == 1, back.pets .. " familiers, " .. back.eggs .. " œuf qui couve, " .. back.store .. " au sac, " .. back.bag .. " œuf au sac")
	check("l'équipe est gardée", back.team == #now.team, tostring(back.team))

	-- 2. Le verrou : l'autre serveur libère au bout de 3 secondes.
	local quick = debug:Invoke("LockTest", 3)
	log("Info", "[SAVE] verrou libéré après 3 s : attendu " .. tostring(quick.waited) .. " s, pièces lues " .. tostring(quick.coins))
	check("on attend l'autre serveur, puis on lit SES données", quick.coins == 222 and quick.waited >= 3 and quick.waited <= 7, quick.waited .. " s")
	-- ... et s'il ne libère jamais : on continue quand même.
	local stuck = debug:Invoke("LockTest", 1000)
	log("Info", "[SAVE] verrou jamais libéré : attendu " .. tostring(stuck.waited) .. " s, pièces lues " .. tostring(stuck.coins))
	check("un verrou qui ne part pas ne bloque pas le joueur", stuck.waited >= 10 and stuck.waited <= 16, stuck.waited .. " s")

	log("Info", "[SAVE] BILAN : " .. passed .. " réussis, " .. failed .. " ratés")
	log("Info", "[SURVIVE] TEST:done")
end

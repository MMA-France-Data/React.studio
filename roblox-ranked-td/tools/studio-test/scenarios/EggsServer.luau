-- Test des ŒUFS, côté serveur : tools/studio-test/run.ps1 -Test eggs.
-- 1) Seul (le client attend) : un œuf gagné à chaque victoire (doré au boss, commun en rejouant, rien en perdant,
--    perdu si la réserve est pleine), poser un œuf (couveuse vide et œuf en réserve seulement), pas d'ouverture avant
--    son temps (l'heure du serveur avance avec le debug « Clock »), la tour sortie (nouvelle : debug « EggForce » ;
--    doublon : XP d'entraînement ; attribut « Hatch » du joueur), finir tout de suite avec des pièces, acheter les
--    couveuses, et les couveuses de la parcelle (l'œuf de sa couleur, l'étiquette, l'invite vers l'onglet Œufs).
-- 2) Il donne la main au client (attribut EggsTestPhase = "Client" de ReplicatedStorage) et répond à ses demandes par
--    la RemoteFunction ReplicatedStorage.__EggsTest.
-- StudioDebug n'existe que dans Studio.
return function(log)
	local HttpService = game:GetService("HttpService")
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local dbg = game:GetService("ServerStorage"):WaitForChild("StudioDebug", 30)
	local Levels = require(ReplicatedStorage:WaitForChild("Shared").Levels)

	local function check(ok, message)
		log(if ok then "Info" else "Error", `[{if ok then "PASS" else "FAIL"}] œufs (serveur) : {message}`)
	end

	local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
	for _ = 1, 150 do
		if dbg:Invoke(player, "Data") and typeof(player:GetAttribute("Plot")) == "number" and player:GetAttribute("LevelsState") ~= nil then
			break
		end
		task.wait(0.2)
	end
	local function levels(...)
		return dbg:Invoke(player, "Levels", ...)
	end
	local function action(...)
		return levels("Action", ...)
	end
	local function data()
		return levels("State").levels
	end
	local function decode(raw)
		if typeof(raw) ~= "string" then
			return nil
		end
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(raw)
		end)
		return if ok then decoded else nil
	end
	local function arenaFolder()
		local index = player:GetAttribute("LevelArena")
		local arenas = workspace:FindFirstChild("Arenas")
		return if typeof(index) == "number" and arenas then arenas:FindFirstChild("Arena" .. Levels.slotOf(index)) else nil
	end
	local function win(level, won)
		action("Start", level)
		levels("Finish", won)
		local arena = arenaFolder()
		local result = decode(arena and arena:GetAttribute("Result")) or {}
		action("Quit")
		return result
	end
	local function eggs(eggType)
		return data().eggs[eggType] or 0
	end

	-- Le joueur a réussi 9 niveaux, a 10 000 pièces, les deux tours de départ, aucun œuf, une couveuse.
	for key, value in {
		best = 9,
		coins = 10000,
		eggs = {},
		hatchers = { { egg = "", readyAt = 0 } },
		towers = { MachineGun = true, Bomb = true },
		bar = { "MachineGun", "Bomb" },
		xp = {},
		tutorial = Levels.TUTORIAL.DONE,
	} do
		levels("Set", key, value)
	end

	------------------------------------------------------------------
	-- Un œuf à chaque victoire
	------------------------------------------------------------------
	local result = win(10, true)
	check(result.egg == "Gold" and result.eggKept == true and eggs("Gold") == 1, `niveau 10 (boss) réussi pour la première fois : un œuf doré ({tostring(result.egg)})`)
	result = win(3, true)
	check(result.egg == "Common" and eggs("Common") == 1, `niveau 3 rejoué : un œuf commun ({tostring(result.egg)})`)
	result = win(3, false)
	check(result.egg == nil and eggs("Common") == 1, "une défaite ne donne pas d'œuf")
	levels("Egg", "Common", Levels.EGG_MAX)
	result = win(3, true)
	check(result.egg == "Common" and result.eggKept == false and Levels.eggCount(data()) == Levels.EGG_MAX, `réserve pleine ({Levels.EGG_MAX} œufs) : l'œuf gagné est perdu, et l'écran de fin le dira`)
	levels("Set", "eggs", { Gold = 1, Common = 3 })

	------------------------------------------------------------------
	-- Couver, ouvrir
	------------------------------------------------------------------
	local ok, why = action("EggStart", 1, "Gold")
	local hatcher = data().hatchers[1]
	check(ok and hatcher.egg == "Gold" and eggs("Gold") == 0, "l'œuf doré est posé dans la couveuse 1 (il quitte la réserve)")
	ok, why = action("EggStart", 1, "Common")
	check(not ok and why == "Cette couveuse est déjà occupée", `une couveuse occupée refuse un autre œuf (« {tostring(why)} »)`)
	ok, why = action("EggOpen", 1)
	check(not ok and why == "Cet œuf n'est pas encore prêt", `pas d'ouverture avant son temps (« {tostring(why)} »)`)
	levels("Clock", Levels.EGGS.Gold.seconds - 60)
	ok = action("EggOpen", 1)
	check(not ok and data().hatchers[1].egg == "Gold", "une minute avant : toujours pas prêt")
	levels("Clock", 61)
	levels("EggForce", "Laser")
	ok = action("EggOpen", 1)
	local hatch = decode(player:GetAttribute("Hatch")) or {}
	local mine = data()
	check(
		ok and hatch.tower == "Laser" and hatch.new == true and hatch.egg == "Gold" and mine.towers.Laser == true and table.find(mine.bar, "Laser") ~= nil
			and mine.hatchers[1].egg == "",
		`4 h plus tard, l'œuf doré s'ouvre : une nouvelle tour, le Sorcier des arcanes (attribut Hatch : {tostring(hatch.tower)}, nouvelle : {tostring(hatch.new)}), dans sa barre`
	)
	action("EggStart", 1, "Common")
	levels("Clock", Levels.EGGS.Common.seconds + 1)
	levels("EggForce", "MachineGun")
	-- (XP lue après le saut d'heure : l'Archer s'entraîne aussi dans le camp pendant ce temps)
	local xpBefore = data().xp.MachineGun or 0
	action("EggOpen", 1)
	hatch = decode(player:GetAttribute("Hatch")) or {}
	check(
		hatch.tower == "MachineGun" and hatch.new == false and hatch.xp == Levels.DUPLICATE_XP.Common
			and math.abs((data().xp.MachineGun or 0) - xpBefore - Levels.DUPLICATE_XP.Common) < 1,
		`un doublon (l'Archer, déjà à lui) : +{tostring(hatch.xp)} XP d'entraînement pour l'Archer`
	)
	local coinsBefore = data().coins
	action("EggStart", 1, "Common")
	ok = action("EggSkip", 1)
	local skipCost = Levels.skipCost(Levels.EGGS.Common.seconds)
	local opened = action("EggOpen", 1)
	check(ok and opened and data().coins == coinsBefore - skipCost, `« Finir » tout de suite : {skipCost} pièces, puis l'œuf s'ouvre`)

	------------------------------------------------------------------
	-- Acheter des couveuses
	------------------------------------------------------------------
	coinsBefore = data().coins
	local bought2 = action("HatcherBuy")
	local bought3 = action("HatcherBuy")
	local bought4, why4 = action("HatcherBuy")
	check(
		bought2 and bought3 and not bought4 and why4 == "Tu as déjà toutes les couveuses" and #data().hatchers == 3
			and data().coins == coinsBefore - Levels.HATCHER_COST[2] - Levels.HATCHER_COST[3],
		`couveuses achetées : la 2e ({Levels.HATCHER_COST[2]}), la 3e ({Levels.HATCHER_COST[3]}), pas de 4e (« {tostring(why4)} »)`
	)

	------------------------------------------------------------------
	-- Les couveuses de la parcelle
	------------------------------------------------------------------
	levels("Set", "eggs", { Rare = 1, Common = 2 })
	action("EggStart", 2, "Rare")
	task.wait(1.5)
	local plots = workspace:FindFirstChild("Hub") and workspace.Hub:FindFirstChild("Plots")
	local plot = plots and plots:FindFirstChild("Plot" .. player:GetAttribute("Plot"))
	local function hatcherModel(index)
		return plot and plot:FindFirstChild("Hatcher" .. index)
	end
	local model1, model2 = hatcherModel(1), hatcherModel(2)
	local egg2 = model2 and model2:FindFirstChild("Egg")
	local label2 = model2 and model2:FindFirstChild("HatcherLabel")
	local prompt1 = model1 and model1:FindFirstChild("HatcherPedestal") and model1.HatcherPedestal:FindFirstChild("HatcherPrompt")
	check(
		model1 ~= nil and model2 ~= nil and hatcherModel(3) ~= nil and egg2 ~= nil and egg2.Transparency == 0 and egg2.Color == Levels.EGGS.Rare.color
			and model1.Egg.Transparency == 1 and label2 ~= nil and label2.Panel.Title.Text == "COUVEUSE 2" and label2.Panel.Sub.Text == "Œuf rare"
			and string.match(label2.Panel.Timer.Text, "^%d+:%d%d$") ~= nil and prompt1 ~= nil and prompt1:GetAttribute("CampTab") == "Œufs" and prompt1.Enabled,
		`la parcelle a 3 couveuses : l'œuf rare dans la 2e (sa couleur, « {label2 and label2.Panel.Sub.Text or "?"} », {label2 and label2.Panel.Timer.Text or "?"}), une invite vers l'onglet Œufs`
	)
	levels("Clock", Levels.EGGS.Rare.seconds + 1)
	task.wait(1.5)
	check(
		label2 ~= nil and label2.Panel.Sub.Text == "Œuf rare : prêt !" and label2.Panel.Timer.Text == "" and egg2.Material == Enum.Material.Neon and egg2.PointLight.Enabled,
		"l'œuf prêt brille sur la parcelle (« Œuf rare : prêt ! »)"
	)
	action("EggOpen", 2)
	task.wait(0.5)
	check(egg2 ~= nil and egg2.Transparency == 1 and label2.Panel.Sub.Text == "Vide : pose un œuf", "ouvert : la couveuse de la parcelle est vide")

	------------------------------------------------------------------
	-- Le client prend la main
	------------------------------------------------------------------
	for key, value in {
		coins = 10000,
		eggs = { Common = 2, Gold = 1 },
		hatchers = { { egg = "", readyAt = 0 } },
		towers = { MachineGun = true, Bomb = true },
		bar = { "MachineGun", "Bomb" },
	} do
		levels("Set", key, value)
	end
	local remote = Instance.new("RemoteFunction")
	remote.Name = "__EggsTest"
	remote.OnServerInvoke = function(who, command, ...)
		if who ~= player then
			return nil
		end
		if command == "Clock" then
			return levels("Clock", ...)
		elseif command == "Force" then
			return levels("EggForce", ...)
		elseif command == "Set" then
			return levels("Set", ...) ~= nil
		elseif command == "Win" then
			local level = ...
			action("Start", level)
			levels("Finish", true)
			return true
		elseif command == "Quit" then
			return action("Quit")
		elseif command == "State" then
			return data()
		end
		return nil
	end
	remote.Parent = ReplicatedStorage
	ReplicatedStorage:SetAttribute("EggsTestPhase", "Client")
	log("Info", "[OEUFS] serveur du test prêt, le client prend la main")
end

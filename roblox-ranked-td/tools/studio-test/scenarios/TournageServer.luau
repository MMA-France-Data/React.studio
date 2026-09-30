-- Mode tournage (tools/studio-test/tournage.ps1), côté serveur : prépare les scènes que le client demande par
-- ReplicatedStorage.__Tournage (RemoteFunction créée ici) : parcelle débloquée, 22 tours au niveau voulu, vague
-- choisie, personnage mis hors du cadre. Uniquement dans la place de test construite par tournage.ps1 : rien de
-- tout ça n'existe dans le jeu publié (StudioDebug n'existe que dans Studio).
return function(log)
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local dbg = game:GetService("ServerStorage"):WaitForChild("StudioDebug", 30)
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local IdleTowers = require(Shared.IdleTowers)
	local PlotLayout = require(Shared.PlotLayout)

	local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
	for _ = 1, 150 do
		if dbg:Invoke(player, "Data") and typeof(player:GetAttribute("Plot")) == "number" then
			break
		end
		task.wait(0.2)
	end

	-- Les 22 emplacements (PlotLayout.SPOTS) : chaque rangée entre deux allers du chemin mélange les tours, pour
	-- que tous les effets (feu, givre, foudre, boulets, carreaux, rayon) se voient partout. Limites de tours
	-- identiques respectées (3 communes, 3 rares, 3 épiques et 2 légendaires de chaque).
	local LAYOUT = {
		[19] = "Frost", [20] = "MachineGun", [21] = "Tesla", [22] = "Laser", -- rangée du fond (z = 41)
		[15] = "Chain", [16] = "Bomb", [17] = "MachineGun", [18] = "Frost", -- z = 23
		[9] = "Rocket", [10] = "Orbital", [11] = "Tesla", [12] = "Laser", -- z = 5
		[1] = "Frost", [2] = "Chain", [5] = "Bomb", [6] = "Rocket", -- z = -13
		[3] = "Orbital", [4] = "Tesla", [7] = "MachineGun", [8] = "Laser", -- z = -31
		[13] = "Bomb", [14] = "Rocket", -- près de la base (z = -56)
	}

	local function setup()
		local unlocked = {}
		for _, towerType in IdleTowers.ORDER do
			unlocked[towerType] = true
		end
		dbg:Invoke(player, "Set", "unlockedTowers", unlocked)
		local owned = {}
		for spotIndex = 1, #PlotLayout.SPOTS do
			owned[tostring(spotIndex)] = true
		end
		dbg:Invoke(player, "Set", "ownedSpots", owned)
		dbg:Invoke(player, "Call", "refreshSpots")
		dbg:Invoke(player, "Set", "highestWave", 214)
		dbg:Invoke(player, "Set", "bestWave", 214)
		dbg:Invoke(player, "Coins", 4.2e15)
	end

	local function setTowers(level: number, runes: { [string]: string }?)
		local towers = {}
		for spotIndex, towerType in LAYOUT do
			towers[tostring(spotIndex)] = { type = towerType, level = level, spent = 0, runes = runes or {} }
		end
		dbg:Invoke(player, "Set", "towers", towers)
		dbg:Invoke(player, "Call", "debugReloadTowers")
	end

	-- Personnage posé loin derrière la base, hors du cadre (ancré pour qu'il ne tombe pas).
	local function hideCharacter()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			local plot = player:GetAttribute("Plot")
			character:PivotTo(CFrame.new(PlotLayout.toWorld(plot, Vector3.new(0, 3, -80))))
			root.Anchored = true
		end
	end

	local remote = Instance.new("RemoteFunction")
	remote.Name = "__Tournage"
	remote.OnServerInvoke = function(caller, command, a, b)
		if caller ~= player then
			return nil
		end
		if command == "setup" then
			setup()
			hideCharacter()
		elseif command == "towers" then
			setTowers(a, b)
		elseif command == "wave" then
			dbg:Invoke(player, "StartWave", a)
		elseif command == "clear" then
			dbg:Invoke(player, "Call", "clearEnemies")
		elseif command == "progress" then
			return dbg:Invoke(player, "Progress")
		end
		return true
	end
	remote.Parent = ReplicatedStorage
	log("Info", "[TOURNAGE] serveur prêt")
end

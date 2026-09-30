-- Scènes toutes prêtes pour tes parties dans Studio (bouton « SCÈNES (Studio) » de client/StudioScenes.luau, ou
-- commande StudioDebug « Scene ») : ta parcelle remplie de 22 tours, la vague d'un boss lancée tout de suite, et ton
-- personnage posé face à son chemin. Pour voir ou filmer un boss sans jouer des heures (demande du propriétaire,
-- 30/09/2026 : le dragon de la vague 100 et le boss de glace de la vague 40).
-- Seulement dans Studio (Config.STUDIO_SCENES) : le remote n'existe pas dans le jeu publié, et tes données de
-- Studio sont en mémoire (rien n'est sauvegardé, aucun classement n'est touché).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local IdleTowers = require(Shared.IdleTowers)
local PlotLayout = require(Shared.PlotLayout)

local StudioScenes = {}

-- Les 22 emplacements (PlotLayout.SPOTS) : chaque rangée entre deux allers du chemin mélange les tours, pour que tous
-- les effets (feu, givre, foudre, boulets, carreaux, rayon) se voient partout. Limites de tours identiques respectées
-- (3 de chaque commune, rare et épique, 2 de chaque légendaire). Le même placement que le mode tournage.
StudioScenes.LAYOUT = {
	[19] = "Frost", [20] = "MachineGun", [21] = "Tesla", [22] = "Laser", -- rangée du fond (z = 41)
	[15] = "Chain", [16] = "Bomb", [17] = "MachineGun", [18] = "Frost", -- z = 23
	[9] = "Rocket", [10] = "Orbital", [11] = "Tesla", [12] = "Laser", -- z = 5
	[1] = "Frost", [2] = "Chain", [5] = "Bomb", [6] = "Rocket", -- z = -13
	[3] = "Orbital", [4] = "Tesla", [7] = "MachineGun", [8] = "Laser", -- z = -31
	[13] = "Bomb", [14] = "Rocket", -- près de la base (z = -56)
}

-- wave = vague lancée ; level = niveau des 22 tours (le boss tient un moment sous le feu, puis tombe) ; stand = où
-- ton personnage est posé et look = ce qu'il regarde (coordonnées de la parcelle : x = largeur, z = profondeur, les
-- ennemis arrivent du fond, z = 62). Les deux points sont hors du chemin et des emplacements de tours.
StudioScenes.SCENES = {
	-- Le dragon (vague 100) : tu es au bord du chemin, du côté où il arrive, et tu le vois voler vers toi.
	dragon = { wave = 100, level = 74, stand = Vector3.new(28, 3, 41), look = Vector3.new(-12, 10, 50) },
	-- Le Titan du givre (vague 40) : même place ; il passe juste devant toi au premier virage.
	glace = { wave = 40, level = 28, stand = Vector3.new(28, 3, 41), look = Vector3.new(-12, 4, 50) },
}

-- Prépare la scène `name` sur la parcelle du joueur. Renvoie true si elle est lancée.
function StudioScenes.apply(player: Player, plotGame, name: string): boolean
	local scene = StudioScenes.SCENES[name]
	if not RunService:IsStudio() or not scene or not plotGame then
		return false
	end
	local idle = plotGame.idle
	local unlocked = {}
	for _, towerType in IdleTowers.ORDER do
		unlocked[towerType] = true
	end
	idle.unlockedTowers = unlocked
	local owned = {}
	for spotIndex = 1, #PlotLayout.SPOTS do
		owned[tostring(spotIndex)] = true
	end
	idle.ownedSpots = owned
	plotGame:refreshSpots()
	local towers = {}
	for spotIndex, towerType in StudioScenes.LAYOUT do
		towers[tostring(spotIndex)] = { type = towerType, level = scene.level, spent = 0, runes = {} }
	end
	idle.towers = towers
	plotGame:debugReloadTowers()
	idle.highestWave = math.max(idle.highestWave or 1, scene.wave)
	idle.wave = scene.wave
	plotGame:clearEnemies()
	plotGame:startWave()

	local character = player.Character
	if character then
		local stand = plotGame.cframe:PointToWorldSpace(scene.stand)
		local look = plotGame.cframe:PointToWorldSpace(scene.look)
		character:PivotTo(CFrame.lookAt(stand, Vector3.new(look.X, stand.Y, look.Z)))
	end
	return true
end

-- Remote du bouton « SCÈNES (Studio) » : créé seulement dans Studio, avec Config.STUDIO_SCENES.
function StudioScenes.start(getPlotGame: (Player) -> any)
	if not RunService:IsStudio() or Config.STUDIO_SCENES ~= true then
		return
	end
	local remote = Instance.new("RemoteEvent")
	remote.Name = "StudioScene"
	remote.OnServerEvent:Connect(function(player, name)
		if name == "lang:en" or name == "lang:fr" then
			-- Jeu en anglais pour t'enregistrer (Roblox n'accepte que des vidéos avec textes et son en anglais).
			player:SetAttribute("Lang", string.sub(name, 6))
		elseif typeof(name) == "string" then
			StudioScenes.apply(player, getPlotGame(player), name)
		end
	end)
	remote.Parent = ReplicatedStorage
end

return StudioScenes

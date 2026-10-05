-- Point d'entrée client : charge l'interface du jeu (niveaux et camp d'entraînement).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local UI = require(script.Parent.UI)

-- Messages du serveur (achat réussi, pas assez d'or...) : petite notification en haut de l'écran.
Remotes.get("Notify").OnClientEvent:Connect(function(message: string, kind: string?)
	UI.toast(message, kind)
end)

-- Traduction : un joueur qui ne joue pas en français voit les textes traduits en anglais, en espagnol ou en portugais
-- (AutoTranslate.luau, Shared/Lang.luau, dictionnaires Shared/LangEN, LangES, LangPT). Avant les interfaces. Rien ne
-- change pour un joueur francophone.
require(script.Parent.AutoTranslate).start()

-- Textes flottants (niveaux des tours, barres de vie...) visibles seulement quand on s'approche.
require(Shared.ProximityLabel).start()

-- Arrivée sur sa parcelle : le serveur pose le personnage à son point d'arrivée, tourné vers le fond de la parcelle
-- (Hub/Plots.luau, homeCFrame), juste après son apparition. La caméra de Roblox garde son orientation quand le
-- personnage est déplacé : si elle était placée avant ce déplacement, elle pouvait regarder l'entrée (vu dans un test
-- Studio : les étiquettes des couveuses sous le nez). Dès que le personnage est à son point d'arrivée (3 s au plus),
-- elle est remise derrière lui, une seule fois : le joueur la tourne ensuite comme il veut.
local PlotLayout = require(Shared.PlotLayout)
local function atHome(position: Vector3): boolean
	local plot = Players.LocalPlayer:GetAttribute("Plot")
	if typeof(plot) ~= "number" then
		return false
	end
	local home = PlotLayout.toWorld(plot, PlotLayout.PLAYER_SPAWN)
	return Vector2.new(position.X - home.X, position.Z - home.Z).Magnitude < 4
end
local function cameraBehind(character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not root then
		return
	end
	local deadline = os.clock() + 3
	while os.clock() < deadline and character.Parent and not atHome(root.Position) do
		task.wait(0.05)
	end
	local camera = workspace.CurrentCamera
	if character.Parent and atHome(root.Position) and camera and camera.CameraType == Enum.CameraType.Custom then
		task.wait(0.1)
		local look = root.CFrame.LookVector
		camera.CFrame = CFrame.lookAt(root.Position - look * 12 + Vector3.new(0, 5, 0), root.Position + look * 4)
	end
end
Players.LocalPlayer.CharacterAdded:Connect(cameraBehind)
if Players.LocalPlayer.Character then
	task.spawn(cameraBehind, Players.LocalPlayer.Character)
end

-- Sons (effets, musique, bouton « SON »), seulement chez ce joueur : avant les autres modules, qui les jouent.
-- Réglages dans src/shared/Sounds.luau.
require(script.Parent.SoundManager).start()

-- Monstres, cibles d'entraînement et tirs des tours.
require(script.Parent.PlotRenderer).start()
-- Invites des camps : seulement celles de ta parcelle.
task.spawn(function()
	require(script.Parent.PlotAccess).start()
end)
-- NIVEAUX : bouton « ⚔ NIVEAUX », fenêtre du camp (niveaux, entraînement, mes tours, œufs) et écran d'un niveau.
require(script.Parent.LevelsUI).start()
-- Tuto des nouveaux joueurs : une flèche montre quoi toucher (premier niveau guidé, puis le premier œuf).
require(script.Parent.TutorialUI).start()
-- Galerie des ennemis : seulement dans Studio (Config.STUDIO_ENEMY_GALLERY), jamais dans le jeu publié.
require(script.Parent.EnemyGallery).start()
-- Panneau « SONS (Studio) » pour écouter chaque son : seulement dans Studio (Config.STUDIO_SOUND_PANEL).
require(script.Parent.SoundPanel).start()

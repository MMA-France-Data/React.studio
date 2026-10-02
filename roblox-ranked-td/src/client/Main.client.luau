-- Point d'entrée client : charge l'interface du jeu (niveaux et camp d'entraînement).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local UI = require(script.Parent.UI)

-- Messages du serveur (achat réussi, pas assez d'or...) : petite notification en haut de l'écran.
Remotes.get("Notify").OnClientEvent:Connect(function(message: string, kind: string?)
	UI.toast(message, kind)
end)

-- Traduction : un joueur qui ne joue pas en français voit les textes traduits en anglais (AutoTranslate.luau,
-- Shared/Lang.luau, dictionnaires Shared/LangEN). Avant les interfaces. Rien ne change pour un joueur francophone.
require(script.Parent.AutoTranslate).start()

-- Textes flottants (niveaux des tours, barres de vie...) visibles seulement quand on s'approche.
require(Shared.ProximityLabel).start()

-- Sons (effets, musique, bouton « SON »), seulement chez ce joueur : avant les autres modules, qui les jouent.
-- Réglages dans src/shared/Sounds.luau.
require(script.Parent.SoundManager).start()

-- Monstres, cibles d'entraînement et tirs des tours.
require(script.Parent.PlotRenderer).start()
-- Invites des camps : seulement celles de ta parcelle.
task.spawn(function()
	require(script.Parent.PlotAccess).start()
end)
-- NIVEAUX : bouton « ⚔ NIVEAUX », fenêtre du camp (niveaux, boutique, entraînement, mes tours) et écran d'un niveau.
require(script.Parent.LevelsUI).start()
-- Galerie des ennemis : seulement dans Studio (Config.STUDIO_ENEMY_GALLERY), jamais dans le jeu publié.
require(script.Parent.EnemyGallery).start()
-- Panneau « SONS (Studio) » pour écouter chaque son : seulement dans Studio (Config.STUDIO_SOUND_PANEL).
require(script.Parent.SoundPanel).start()

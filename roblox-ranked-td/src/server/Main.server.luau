-- Point d'entrée serveur : la map principale (une parcelle par joueur, son camp d'entraînement) et les niveaux
-- (module Hub).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)

Remotes.init()

-- Langue de chaque joueur (attribut « Lang » : "fr" s'il joue en français, sinon "en"), dès son arrivée. Le client
-- traduit ce qui s'affiche (AutoTranslate, Shared/Lang.luau).
require(Shared.Lang).startServer()

-- Modèles perso des ennemis (ReplicatedStorage.EnemyModels) : aucun script n'y a sa place (sécurité, voir
-- CustomModels.sanitizeSources). Juste un filet : les scripts doivent être supprimés dans Studio.
pcall(function()
	require(Shared.CustomModels).sanitizeSources()
end)

PlayerData.start()

local ok, err = xpcall(function()
	require(script.Parent.Hub).start()
end, debug.traceback)
if not ok then
	warn(`[Jeu] Échec du démarrage :\n{err}`)
end

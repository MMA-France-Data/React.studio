-- Point d'entrée serveur. Une seule place Roblox sert à la fois de lobby et de serveur de match :
--   serveur public   -> Lobby : map principale avec les parcelles et le cercle ranked (module Hub)
--   serveur réservé  -> Match (créé par le matchmaking via TeleportService:ReserveServer)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)

local function detectMode(): string
	if RunService:IsStudio() and Config.STUDIO_FORCE_MODE ~= "Auto" then
		return Config.STUDIO_FORCE_MODE
	end
	-- Un serveur réservé a un PrivateServerId mais pas de propriétaire.
	if game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0 then
		return "Match"
	end
	return "Lobby"
end

Remotes.init()

-- Langue de chaque joueur (attribut « Lang » : "fr" s'il joue en français, sinon "en"), dès son arrivée, sur la map
-- principale comme sur un serveur de match. Le client traduit tout ce qui s'affiche (AutoTranslate, Shared/Lang.luau).
require(Shared.Lang).startServer()

-- Modèles perso des ennemis (ReplicatedStorage.EnemyModels) : aucun script n'y a sa place (sécurité, voir
-- CustomModels.sanitizeSources). Juste un filet : les scripts doivent être supprimés dans Studio.
pcall(function()
	require(Shared.CustomModels).sanitizeSources()
end)

local mode = detectMode()
ReplicatedStorage:SetAttribute("ServerMode", mode)
print("[RankedTD] Mode serveur :", mode)

PlayerData.start()

local ok, err = xpcall(function()
	if mode == "Match" then
		require(script.Parent.Match).start()
	else
		require(script.Parent.Hub).start()
	end
end, debug.traceback)
if not ok then
	warn(`[RankedTD] Échec du démarrage en mode {mode} :\n{err}`)
end

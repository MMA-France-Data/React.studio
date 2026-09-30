-- Le classé est-il ouvert ? Une seule fonction, lue par le serveur ET par le client : RankedGate.isOpen().
-- L'interrupteur est dans Config.luau : Config.RANKED_OPEN (false = sortie sans le classé, décidée le 30/09/2026).
--
-- Studio SEULEMENT (jamais dans le jeu publié : RunService:IsStudio() y est toujours faux, un joueur ne peut donc
-- rien ouvrir) : l'attribut « StudioRankedOpen » de ReplicatedStorage (true ou false), quand il existe, décide à la
-- place de Config.RANKED_OPEN. Les tests automatiques (tools/studio-test, scénario HubServer.luau) le mettent à true
-- dès le début, pour que tous les tests du classé et des défis continuent de tourner, puis à false pour tester le classé
-- fermé. Tu peux aussi t'en servir dans la barre de commande (vue Serveur) :
--   game.ServerStorage.StudioDebug:Invoke(game.Players:GetPlayers()[1], "RankedOpen", true)       -> ouvert
--   game.ServerStorage.StudioDebug:Invoke(game.Players:GetPlayers()[1], "RankedOpen", false)      -> fermé
--   game.ServerStorage.StudioDebug:Invoke(game.Players:GetPlayers()[1], "RankedOpen", "Default")  -> comme Config
-- Le serveur met l'attribut et le client le voit aussi (ReplicatedStorage est partagé) : les deux changent ensemble.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(script.Parent.Config)

local RankedGate = {}

RankedGate.STUDIO_ATTRIBUTE = "StudioRankedOpen"

-- Textes montrés quand le classé est fermé (cercle, tableau du classement, plaques, carte de rang, refus du serveur).
-- Traductions anglaises : LangEN/Social.luau.
RankedGate.SOON_TITLE = "BIENTÔT DISPONIBLE"
RankedGate.SOON_TEXT = "Les matchs classés 1v1 arrivent bientôt !"

-- Vrai si le classé est ouvert (voir en haut).
function RankedGate.isOpen(): boolean
	if RunService:IsStudio() then
		local override = ReplicatedStorage:GetAttribute(RankedGate.STUDIO_ATTRIBUTE)
		if typeof(override) == "boolean" then
			return override
		end
	end
	return Config.RANKED_OPEN == true
end

-- callback() quand le classé s'ouvre ou se ferme. Ça n'arrive que dans Studio (attribut « StudioRankedOpen ») : dans
-- le jeu publié, il ne change jamais pendant la partie.
function RankedGate.onChanged(callback: () -> ()): RBXScriptConnection
	return ReplicatedStorage:GetAttributeChangedSignal(RankedGate.STUDIO_ATTRIBUTE):Connect(callback)
end

-- Studio seulement (serveur, StudioDebug « RankedOpen ») : true / false = classé forcé ouvert / fermé, nil = de
-- nouveau le réglage normal. Ne fait rien dans le jeu publié. Renvoie RankedGate.isOpen().
function RankedGate.setStudioOverride(value: boolean?): boolean
	if RunService:IsStudio() then
		ReplicatedStorage:SetAttribute(RankedGate.STUDIO_ATTRIBUTE, value)
	end
	return RankedGate.isOpen()
end

return RankedGate

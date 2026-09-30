-- Point d'entrée client : charge l'interface du lobby ou celle du match selon le serveur.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local UI = require(script.Parent.UI)

local mode = ReplicatedStorage:GetAttribute("ServerMode")
while not mode do
	ReplicatedStorage:GetAttributeChangedSignal("ServerMode"):Wait()
	mode = ReplicatedStorage:GetAttribute("ServerMode")
end

Remotes.get("Notify").OnClientEvent:Connect(function(message: string, kind: string?)
	UI.toast(message, kind)
end)

-- Traduction : un joueur qui ne joue pas en français voit tous les textes en anglais, messages du serveur compris
-- (AutoTranslate.luau, Shared/Lang.luau, dictionnaires Shared/LangEN). Avant les interfaces. Rien ne change pour un
-- joueur francophone.
require(script.Parent.AutoTranslate).start()

-- Textes flottants (niveaux, prix, barres de vie...) visibles seulement quand on s'approche.
require(Shared.ProximityLabel).start()

-- Sons (effets, musique, bouton « SON »), seulement chez ce joueur : avant les autres modules, qui les jouent.
-- Réglages dans src/shared/Sounds.luau.
require(script.Parent.SoundManager).start(mode)

if mode == "Match" then
	-- La liste des joueurs de Roblox cacherait le panneau de l'adversaire (en haut à droite),
	-- qui affiche déjà les mêmes infos.
	pcall(function()
		game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	end)
	local TowerPlacement = require(script.Parent.TowerPlacement)
	TowerPlacement.start()
	require(script.Parent.MatchUI).start(TowerPlacement)
	require(script.Parent.Effects).start()
else
	require(script.Parent.LobbyUI).start()
	require(script.Parent.PlotRenderer).start()
	require(script.Parent.PlotUI).start()
	require(script.Parent.MachineUI).start()
	require(script.Parent.RebirthUI).start()
	-- Défis classés : bouton « DÉFIS » et fenêtre (récompenses pour le mode solo).
	require(script.Parent.ChallengeUI).start()
	-- Boutique (passes de jeu du mode infini) et message « Pendant ton absence : +X » au retour.
	local ShopUI = require(script.Parent.ShopUI)
	ShopUI.start()
	Remotes.get("OfflineGains").OnClientEvent:Connect(ShopUI.showOfflineGains)
	-- Galerie des ennemis : seulement dans Studio (Config.STUDIO_ENEMY_GALLERY), jamais dans le jeu publié.
	require(script.Parent.EnemyGallery).start()
	-- Panneau « SONS (Studio) » pour écouter chaque son : seulement dans Studio (Config.STUDIO_SOUND_PANEL).
	require(script.Parent.SoundPanel).start()
	-- Petit tuto des nouveaux joueurs (une seule fois, bouton « Passer ») : après les autres interfaces, qu'il montre.
	require(script.Parent.TutorialUI).start()
end

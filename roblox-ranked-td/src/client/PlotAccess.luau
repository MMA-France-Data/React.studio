-- Parcelles des autres joueurs : on les voit, mais on ne peut interagir qu'avec la sienne (demande du
-- propriétaire du jeu). Ici, côté client, on ne montre donc pas ce qui serait refusé :
--   * invites (ProximityPrompt) « Ouvrir » de l'AUTEL DES HÉROS et de la FORGE RUNIQUE : allumées seulement
--     devant TES machines ; chez toi, celles des autres parcelles et des parcelles libres sont éteintes ;
--   * prix des cadenas (« 🔒 prix » au-dessus des emplacements à acheter) : seulement sur ta parcelle.
-- Les clics sur les emplacements et les tours ne visent déjà que ta parcelle (PlotUI : le rayon du clic ne
-- regarde que son dossier). Le serveur reste le seul juge et revérifie tout (machines : « Cet autel appartient
-- à un autre fief ! » ; actions : seulement sur ta parcelle, Hub/init.luau).
-- Tenu à jour quand ta parcelle t'est donnée (attribut « Plot » du joueur) et quand des invites ou des cadenas
-- apparaissent (parcelle remise à zéro au départ d'un joueur, nouvel emplacement à vendre...).
local Players = game:GetService("Players")

local PlotAccess = {}

-- Numéro de la parcelle qui contient cet objet (attribut PlotIndex de son dossier « PlotN »), sinon nil.
local function plotIndexOf(instance: Instance, plotsFolder: Instance): number?
	local current: Instance? = instance
	while current and current.Parent ~= plotsFolder do
		current = current.Parent
	end
	local index = current and current:GetAttribute("PlotIndex")
	return if typeof(index) == "number" then index else nil
end

-- Démarré une seule fois (par PlotUI.start, map principale).
function PlotAccess.start()
	local player = Players.LocalPlayer
	local plotsFolder = workspace:WaitForChild("Hub"):WaitForChild("Plots")

	-- Allume (ta parcelle) ou éteint (les autres) une invite ou un prix de cadenas ; ignore tout le reste.
	local function apply(instance: Instance)
		local isPrompt = instance:IsA("ProximityPrompt")
		local parent = instance.Parent
		local isLockPrice = instance:IsA("TextLabel") and instance.Name == "Price" and parent ~= nil and parent.Name == "Lock"
		if not isPrompt and not isLockPrice then
			return
		end
		local index = plotIndexOf(instance, plotsFolder)
		if not index then
			return
		end
		local mine = index == player:GetAttribute("Plot")
		if isPrompt then
			(instance :: ProximityPrompt).Enabled = mine
		else
			(instance :: TextLabel).Visible = mine
		end
	end
	local function applyAll()
		for _, instance in plotsFolder:GetDescendants() do
			apply(instance)
		end
	end

	plotsFolder.DescendantAdded:Connect(apply)
	player:GetAttributeChangedSignal("Plot"):Connect(applyAll)
	applyAll()
end

return PlotAccess

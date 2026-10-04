-- Camps des autres joueurs : on les voit, mais on ne peut interagir qu'avec le sien (demande du propriétaire du
-- jeu). Ici, côté client, on ne montre donc pas ce qui ne servirait à rien : les invites (ProximityPrompt) des
-- socles d'entraînement, du bâtiment des œufs et de la porte des niveaux ne sont allumées que sur TA parcelle ;
-- celles des autres parcelles et des parcelles libres sont éteintes. (LevelsUI n'écoute de toute façon que celles
-- de ta parcelle, et le serveur revérifie tout.)
-- Tenu à jour quand ta parcelle t'est donnée (attribut « Plot » du joueur) et quand des invites apparaissent (un
-- joueur arrive, un socle s'ouvre).
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

-- Démarré une seule fois (Main.client.luau).
function PlotAccess.start()
	local player = Players.LocalPlayer
	local plotsFolder = workspace:WaitForChild("Hub"):WaitForChild("Plots")

	-- Allume (ta parcelle) ou éteint (les autres) une invite ; ignore tout le reste.
	local function apply(instance: Instance)
		if not instance:IsA("ProximityPrompt") then
			return
		end
		local index = plotIndexOf(instance, plotsFolder)
		if index then
			instance.Enabled = index == player:GetAttribute("Plot")
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

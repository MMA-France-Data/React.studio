-- La parcelle du joueur est-elle un CAMP D'ENTRAÎNEMENT (nouvelle formule) ? Le serveur le dit par l'attribut « Camp »
-- du dossier de sa parcelle (Hub/Camp.luau, Hub/CampGame.luau). Quand c'est le cas, tout ce qui appartient au jeu
-- infini se tait chez lui : écrans (LevelsUI les cache), clics sur les emplacements et boutons « + » (PlotUI), tuto
-- des nouveaux joueurs (TutorialUI). Les autres joueurs ne sont pas concernés.
local Players = game:GetService("Players")

local CampMode = {}

local plotsFolder: Instance? = nil

-- Dossier de la parcelle du joueur (workspace.Hub.Plots.Plot<n>), nil tant qu'elle n'est pas connue.
function CampMode.plotFolder(): Instance?
	local index = Players.LocalPlayer:GetAttribute("Plot")
	if typeof(index) ~= "number" then
		return nil
	end
	if not plotsFolder or not plotsFolder.Parent then
		local hub = workspace:FindFirstChild("Hub")
		plotsFolder = hub and hub:FindFirstChild("Plots")
	end
	return plotsFolder and plotsFolder:FindFirstChild("Plot" .. index)
end

function CampMode.active(): boolean
	local folder = CampMode.plotFolder()
	return folder ~= nil and folder:GetAttribute("Camp") == true
end

return CampMode

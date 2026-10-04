-- Textes flottants visibles seulement quand le personnage du joueur s'approche : l'écran reste lisible.
--
-- ProximityLabel.register(billboard, distance, hideNear) marque un BillboardGui (serveur ou client : les attributs
-- et le tag sont répliqués). Chaque client allume ou éteint ensuite les étiquettes selon la distance
-- entre SON personnage et le support de l'étiquette (Adornee, sinon le parent). Les distances
-- sont réglées dans Config.LabelDistance.
-- hideNear (studs, facultatif) : l'étiquette s'éteint aussi quand la CAMÉRA est à moins de hideNear studs d'elle.
-- Pour les étiquettes dont la taille est en studs (celles du camp : socles, couveuses) : la caméra juste dessus,
-- elles remplissaient la moitié de l'écran (vu au point d'arrivée de la parcelle, caméra tournée vers l'entrée).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local TAG = "ProximityLabel"
local REFRESH = 0.2 -- secondes entre deux mises à jour

local ProximityLabel = {}

-- Pendant un niveau (LevelsUI.luau), le joueur regarde sa zone de combat d'en haut alors que son personnage est
-- resté sur la place : les étiquettes à moins de focusRadius studs de ce point s'affichent aussi (toutes celles de
-- la zone : barres de vie, niveaux des tours). nil = seulement la règle du personnage.
local focusPosition: Vector3? = nil
local focusRadius = 0

function ProximityLabel.setFocus(position: Vector3?, radius: number?)
	focusPosition = position
	focusRadius = radius or 0
end

function ProximityLabel.register(billboard: BillboardGui, distance: number, hideNear: number?)
	billboard:SetAttribute("ShowWithin", distance)
	if hideNear then
		billboard:SetAttribute("HideNearCamera", hideNear)
	end
	CollectionService:AddTag(billboard, TAG)
end

local function anchorFrame(billboard: BillboardGui): CFrame?
	local anchor = billboard.Adornee or billboard.Parent
	if anchor and anchor:IsA("BasePart") then
		return anchor.CFrame
	elseif anchor and anchor:IsA("Model") then
		return anchor:GetPivot()
	end
	return nil
end

-- Côté client uniquement (appelé une fois par Main.client).
function ProximityLabel.start()
	local player = Players.LocalPlayer
	task.spawn(function()
		while true do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local camera = workspace.CurrentCamera
			for _, billboard in CollectionService:GetTagged(TAG) do
				local within = billboard:GetAttribute("ShowWithin")
				local frame = anchorFrame(billboard)
				if typeof(within) == "number" and frame then
					local position = frame.Position
					local shown = (root ~= nil and (root.Position - position).Magnitude <= within)
						or (focusPosition ~= nil and (focusPosition - position).Magnitude <= focusRadius)
					local hideNear = billboard:GetAttribute("HideNearCamera")
					if shown and typeof(hideNear) == "number" and camera then
						-- (StudsOffsetWorldSpace suit l'orientation du support : l'étiquette est là)
						local labelAt = frame:PointToWorldSpace(billboard.StudsOffsetWorldSpace)
						shown = (camera.CFrame.Position - labelAt).Magnitude >= hideNear
					end
					billboard.Enabled = shown
				end
			end
			task.wait(REFRESH)
		end
	end)
end

return ProximityLabel

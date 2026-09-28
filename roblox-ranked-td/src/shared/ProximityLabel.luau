-- Textes flottants visibles seulement quand le personnage du joueur s'approche : l'écran reste lisible.
--
-- ProximityLabel.register(billboard, distance) marque un BillboardGui (serveur ou client : l'attribut
-- et le tag sont répliqués). Chaque client allume ou éteint ensuite les étiquettes selon la distance
-- entre SON personnage et le support de l'étiquette (Adornee, sinon le parent). Les distances
-- sont réglées dans Config.LabelDistance.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local TAG = "ProximityLabel"
local REFRESH = 0.2 -- secondes entre deux mises à jour

local ProximityLabel = {}

function ProximityLabel.register(billboard: BillboardGui, distance: number)
	billboard:SetAttribute("ShowWithin", distance)
	CollectionService:AddTag(billboard, TAG)
end

local function anchorPosition(billboard: BillboardGui): Vector3?
	local anchor = billboard.Adornee or billboard.Parent
	if anchor and anchor:IsA("BasePart") then
		return anchor.Position
	elseif anchor and anchor:IsA("Model") then
		return anchor:GetPivot().Position
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
			for _, billboard in CollectionService:GetTagged(TAG) do
				local within = billboard:GetAttribute("ShowWithin")
				local position = anchorPosition(billboard)
				if typeof(within) == "number" and position then
					billboard.Enabled = root ~= nil and (root.Position - position).Magnitude <= within
				end
			end
			task.wait(REFRESH)
		end
	end)
end

return ProximityLabel

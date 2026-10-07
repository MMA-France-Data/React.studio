-- R15 grip follows the actual hand attachment, not the sword's bounding box.
-- Orientation belongs to the authored wrist (canonical blade axes -Z/Y/X).
local Grip = {}
function Grip.frame(hand: BasePart): CFrame
	local socket = hand:FindFirstChild(if hand.Name == "LeftHand" then "LeftGripAttachment" else "RightGripAttachment")
	local position = if socket and socket:IsA("Attachment") then socket.WorldPosition
		else hand.CFrame:PointToWorldSpace(Vector3.new(0, -0.25, 0))
	return CFrame.new(position) * hand.CFrame.Rotation
end
function Grip.place(model: Model, hand: BasePart): CFrame
	local primary = model.PrimaryPart
	assert(primary, "Épée : point de prise PrimaryPart requis")
	local target = Grip.frame(hand)
	-- Model PivotOffset / cached pivot must not move the HANDLE off the hand.
	local gripToPivot = primary.CFrame:ToObjectSpace(model:GetPivot())
	model:PivotTo(target * gripToPivot)
	return target
end
return Grip

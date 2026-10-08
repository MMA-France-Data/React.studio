-- Cosmetic dual-wield overlay. The server still processes ONE existing hit.
-- Reflect the entire authored right-hand cut, including hips and footwork,
-- rather than only moving the left wrist or replaying a right-arm animation.
local Dual = {}
-- Names select the active HAND, not the direction of the old one-hand clip.
-- SlashLeft is authored on the right arm: it starts on the right and crosses
-- the torso toward the left. Reflecting it gives the opposite left-arm cut.
Dual.sourceClip = "SlashLeft"
function Dual.activeHand(variant: string): string
	return if variant == "SlashLeft" then "Left" else "Right"
end
function Dual.mirrorName(name: string): string
	if string.sub(name, 1, 5) == "Right" then return "Left" .. string.sub(name, 6) end
	if string.sub(name, 1, 4) == "Left" then return "Right" .. string.sub(name, 5) end
	return name
end
-- Reflection through the character's sagittal plane: S * R * S, not a
-- negative-scale CFrame. This remains a proper rotation (determinant +1).
function Dual.mirrorComponents(v)
	return { -v[1], v[2], v[3], v[4], -v[5], -v[6], -v[7], v[8], v[9], -v[10], v[11], v[12] }
end
function Dual.mirror(pose)
	local result = {}
	for name, value in pose do
		result[Dual.mirrorName(name)] = CFrame.new(table.unpack(Dual.mirrorComponents({ value:GetComponents() })))
	end
	return result
end
function Dual.sample(motion, variant: string, elapsed: number)
	local pose = motion.sample(Dual.sourceClip, elapsed)
	if not pose or Dual.activeHand(variant) == "Right" then return pose end
	return Dual.mirror(pose)
end
return Dual

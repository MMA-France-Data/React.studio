local Dual = require("../../src/client/DualSwordMotion")
local Wisp = require("../../src/client/SwordWispProfile")
local Shadow = require("../../src/client/VoidAuraProfile")
local count = 0
local function check(ok, message)
	assert(ok, message)
	count += 1
end
for i = 1, 40 do
	check(Dual.activeHand(if i % 2 == 1 then "SlashRight" else "SlashLeft") == (if i % 2 == 1 then "Right" else "Left"), "Alternate active hands")
end
local sampledName, sampledTime = nil, nil
Dual.sample({sample = function(name, elapsed) sampledName, sampledTime = name, elapsed; return nil end}, "SlashRight", 0.18)
check(sampledName == "SlashLeft" and sampledTime == 0.18, "Right-hand inward cut must use the authored right-to-left clip")
Dual.sample({sample = function(name) sampledName = name; return nil end}, "SlashLeft", 0.18)
check(sampledName == "SlashLeft", "Left hand mirrors the same inward cut, not the outward clip")
for _, name in { "Root", "Waist", "Neck", "RightShoulder", "LeftShoulder", "RightElbow", "LeftElbow", "RightWrist", "LeftWrist", "RightHip", "LeftHip", "RightKnee", "LeftKnee", "RightAnkle", "LeftAnkle" } do
	check(Dual.mirrorName(Dual.mirrorName(name)) == name, "Mirror joint naming involution")
end
for _, values in {
	{1,2,3, 1,0,0, 0,1,0, 0,0,1},
	{1,2,3, 0,0,1, 0,1,0, -1,0,0},
	{-4,.2,8, .36,-.48,.8, .8,.6,0, -.48,.64,.6},
} do
	local reflected = Dual.mirrorComponents(values)
	local original = Dual.mirrorComponents(reflected)
	for i, value in values do check(math.abs(original[i] - value) < 1e-8, "Double reflection returns the original") end
	check(reflected[1] == -values[1] and reflected[2] == values[2] and reflected[3] == values[3], "Mirror lateral translation only")
	local a,b,c,d,e,f,g,h,k = table.unpack(reflected, 4)
	local determinant = a*(e*k-f*h) - b*(d*k-f*g) + c*(d*h-e*g)
	check(math.abs(determinant - 1) < 1e-6, "Proper rotation, no negative-scale distortion")
end
check(not Wisp.locked and Wisp.inheritance == 0, "Wisps drift freely instead of sticking to the sword")
check(Wisp.lifetime[2] <= 1 and Wisp.speed[1] > 0, "Moving short-lived smoke")
check(Wisp.transparency[1][2] == 1 and Wisp.transparency[#Wisp.transparency][2] == 1, "Fade from and back to invisible")
for _, points in { Wisp.size, Wisp.transparency } do
	local previous = -1
	for _, point in points do
		check(point[1] > previous and point[1] >= 0 and point[1] <= 1, "Ordered lifetime curve")
		check(point[2] >= 0 and point[2] <= 1, "Controlled smoke size / valid opacity")
		previous = point[1]
	end
end
for id, groups in Wisp.groups do
	local mobileLive = 3 * #groups * Wisp.rate * Wisp.mobileRate * Wisp.lifetime[2]
	check(mobileLive <= 15, "Maximum mobile particle budget per blade: " .. id)
	for _, group in groups do
		for _, rgb in {group.first, group.last} do
			for _, component in rgb do check(component >= 0 and component <= 255, "Valid smoke color") end
		end
	end
end
check(#Wisp.groups.Fusion == 2 and not Wisp.groups.Void, "Two-colored fusion; void has its own connected shroud")
check(Wisp.groups.Fusion[1].first[1] > Wisp.groups.Fusion[1].first[3], "Warm fire wisps")
check(Wisp.groups.Fusion[2].first[3] > Wisp.groups.Fusion[2].first[1], "Cold ice wisps")
check(math.abs(Shadow.nodes[#Shadow.nodes] - 1 - Shadow.lengthAbove) < 1e-8, "Smoke extends above the real blade tip")
check(Shadow.widthAt(1 + Shadow.lengthAbove, 0, 0) < 1e-8, "The upper end narrows completely")
check(math.abs(Shadow.opacityAt(1 + Shadow.lengthAbove, 0) - 1) < 1e-8, "The upper end becomes fully invisible")
for _, nodes in {Shadow.nodes, Shadow.mobileNodes} do
	local previous = -1
	for _, f in nodes do
		check(f > previous, "A continuous ordered smoke spine")
		previous = f
	end
end
check((#Shadow.mobileNodes - 1) * #Shadow.layers <= 10, "At most ten smoke segments per mobile blade")
check(Shadow.plume.mobileRate * Shadow.plume.lifetime[2] * 1.25 <= 8, "Mobile free-smoke budget even while attacking")
check(Shadow.plume.size[#Shadow.plume.size][2] == 0 and Shadow.plume.transparency[#Shadow.plume.transparency][2] == 1, "Detached smoke thins and dies")
for _, layer in Shadow.layers do
	check(layer.emission < 0.3, "Dark purple smoke, not a white/pink additive glow")
	check(layer.color[3] > layer.color[1] and layer.color[1] > layer.color[2], "Menacing violet palette")
end
for step = 0, 20 do
	local time = step * 0.2
	for _, f in Shadow.nodes do
		local width = Shadow.widthAt(f, time, 0.3)
		check(width >= 0 and width <= 1.16, "Bounded billowing silhouette")
		for _, layer in Shadow.layers do
			local opacity = Shadow.opacityAt(f, layer.fade)
			check(opacity >= 0 and opacity <= 1, "Valid opacity throughout the single cloud")
		end
	end
end
print("DUAL_AND_WISPS_OK", count)

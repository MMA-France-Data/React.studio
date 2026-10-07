local Dual = require("../../src/client/DualSwordMotion")
local Wisp = require("../../src/client/SwordWispProfile")
local count = 0
local function check(ok, message)
	assert(ok, message)
	count += 1
end
for i = 1, 40 do
	check(Dual.activeHand(if i % 2 == 1 then "SlashRight" else "SlashLeft") == (if i % 2 == 1 then "Right" else "Left"), "Alternate active hands")
end
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
		check(point[2] >= 0 and point[2] <= (if points == Wisp.size then .4 else 1), "Compact smoke size / valid opacity")
		previous = point[1]
	end
end
for id, groups in Wisp.groups do
	local mobileLive = 3 * #groups * Wisp.rate * Wisp.mobileRate * Wisp.lifetime[2]
	check(mobileLive <= 8, "Maximum mobile particle budget per blade: " .. id)
	for _, group in groups do
		for _, rgb in {group.first, group.last} do
			for _, component in rgb do check(component >= 0 and component <= 255, "Valid smoke color") end
		end
	end
end
check(#Wisp.groups.Fusion == 2 and #Wisp.groups.Void == 1, "Two-colored fusion, violet void")
check(Wisp.groups.Fusion[1].first[1] > Wisp.groups.Fusion[1].first[3], "Warm fire wisps")
check(Wisp.groups.Fusion[2].first[3] > Wisp.groups.Fusion[2].first[1], "Cold ice wisps")
print("DUAL_AND_WISPS_OK", count)

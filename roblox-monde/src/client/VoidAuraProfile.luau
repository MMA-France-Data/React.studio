-- One connected, billowing shroud: broad around the blade, thinning above it.
-- Pure data/math so continuity, taper and the mobile budget can be checked.
local Profile = {
	lengthAbove = 0.36,
	widthRatio = 0.36,
	widthMin = 1.35,
	widthMax = 2.15,
	textureLength = 1.8,
	flow = 0.26,
	nodes = { 0, 0.16, 0.34, 0.54, 0.76, 1, 1.16, 1.36 },
	mobileNodes = { 0, 0.25, 0.50, 0.76, 1, 1.36 },
	width = { {0, 0.42}, {0.16, 1}, {0.34, 0.93}, {0.54, 1}, {0.76, 0.85}, {1, 0.62}, {1.16, 0.32}, {1.36, 0} },
	opacity = { {0, 0.88}, {0.16, 0.39}, {0.54, 0.35}, {0.76, 0.42}, {1, 0.52}, {1.16, 0.72}, {1.36, 1} },
	-- Dark violet body, a subdued purple rim: neither white nor pink bloom.
	layers = {
		{ name = "DarkSmoke", color = {68, 12, 102}, width = 1, fade = 0, offset = 0, emission = 0.10 },
		{ name = "VioletSmoke", color = {125, 28, 186}, width = 1.12, fade = 0.18, offset = 0.47, emission = 0.22 },
	},
	plume = {
		rate = 8, mobileRate = 5, lifetime = {0.8, 1.25}, speed = {1.05, 1.65}, rise = 0.55,
		size = { {0, 0.72}, {0.12, 0.82}, {0.45, 0.56}, {0.78, 0.23}, {1, 0} },
		transparency = { {0, 1}, {0.12, 0.45}, {0.50, 0.62}, {0.82, 0.84}, {1, 1} },
		first = {113, 24, 165}, last = {42, 6, 70},
	},
}
function Profile.interpolate(points, x: number): number
	if x <= points[1][1] then return points[1][2] end
	for i = 2, #points do
		local a, b = points[i - 1], points[i]
		if x <= b[1] then return a[2] + (b[2] - a[2]) * ((x - a[1]) / (b[1] - a[1])) end
	end
	return points[#points][2]
end
function Profile.widthAt(fraction: number, time: number, phase: number): number
	local wave = 1 + 0.10 * math.sin(time * 1.9 - fraction * 7 + phase)
		+ 0.05 * math.sin(time * 3.1 + fraction * 11 + phase)
	return Profile.interpolate(Profile.width, fraction) * wave
end
function Profile.opacityAt(fraction: number, fade: number): number
	local opacity = Profile.interpolate(Profile.opacity, fraction)
	return opacity + (1 - opacity) * fade
end
return Profile

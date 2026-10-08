-- Smooth, unbroken smoke sheets. Never join independently camera-facing quads.
-- Void has ONE dark sheet; Fusion has one sheet per elemental side, not puffs.
local Profile = {
	lengthAbove = 0.36,
	widthRatio = 0.36,
	widthMin = 1.35,
	widthMax = 2.15,
	endWidth = 0.28, -- no zero-width triangular geometric cap; alpha hides the end
	segments = 24,
	mobileSegments = 16,
	curveStart = 0.65,
	curveEnd = 0.27,
	opacity = { {0, 1}, {0.12, 0.20}, {0.48, 0.16}, {0.68, 0.32}, {0.82, 0.70}, {1, 1} },
	layers = {
		-- No luminous overlay: it was making the violet pastel and translucent.
		{ name = "DarkSmoke", marker = "Shadow", first = {34, 3, 53}, middle = {54, 5, 84}, last = {21, 1, 33},
			width = 1, fade = 0, emission = 0, side = 0 },
	},
	fusionLayers = {
		{ name = "FireSmoke", marker = "Hot", first = {248, 96, 13}, middle = {255, 125, 23}, last = {164, 37, 8},
			width = 0.68, fade = 0.08, emission = 0.25, side = -0.15 },
		{ name = "IceSmoke", marker = "Cold", first = {37, 140, 218}, middle = {73, 184, 239}, last = {23, 98, 170},
			width = 0.68, fade = 0.08, emission = 0.15, side = 0.15 },
	},
	plume = {
		rate = 8, mobileRate = 5, lifetime = {0.8, 1.25}, speed = {1.05, 1.65}, rise = 0.55,
		size = { {0, 0.72}, {0.12, 0.82}, {0.45, 0.56}, {0.78, 0.23}, {1, 0} },
		transparency = { {0, 1}, {0.12, 0.38}, {0.50, 0.56}, {0.82, 0.82}, {1, 1} },
		first = {53, 5, 81}, last = {20, 1, 32}, emission = 0,
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
function Profile.widthAt(time: number, phase: number): number
	return 1 + 0.08 * math.sin(time * 1.9 + phase) + 0.04 * math.sin(time * 3.1 + phase)
end
function Profile.opacityAt(fraction: number, fade: number): number
	local opacity = Profile.interpolate(Profile.opacity, fraction)
	return opacity + (1 - opacity) * fade
end
function Profile.layersFor(id: string)
	return if id == "Fusion" then Profile.fusionLayers else Profile.layers
end
return Profile

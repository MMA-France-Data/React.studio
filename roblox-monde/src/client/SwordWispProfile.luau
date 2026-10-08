-- Pure cosmetic data, shared with the headless particle-budget/fade checks.
return {
	rate = 3.8,
	mobileRate = 0.55,
	lifetime = { 0.5, 0.95 },
	speed = { 0.22, 0.55 },
	size = { {0, 0.10}, {0.22, 0.85}, {0.62, 0.95}, {1, 0} },
	transparency = { {0, 1}, {0.16, 0.32}, {0.50, 0.52}, {1, 1} },
	locked = false,
	inheritance = 0,
	fractions = { 0.12, 0.36, 0.60, 0.84 },
	groups = {
		Fusion = {
			{ name = "Hot", first = {255, 167, 69}, last = {255, 82, 25}, rise = 0.16 },
			{ name = "Cold", first = {177, 245, 255}, last = {70, 183, 255}, rise = 0.06 },
		},
	},
}

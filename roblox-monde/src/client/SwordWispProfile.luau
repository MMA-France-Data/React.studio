-- Pure cosmetic data, shared with the headless particle-budget/fade checks.
return {
	rate = 2.8,
	mobileRate = 0.55,
	lifetime = { 0.45, 0.85 },
	speed = { 0.08, 0.22 },
	size = { {0, 0.05}, {0.22, 0.24}, {0.62, 0.38}, {1, 0.20} },
	transparency = { {0, 1}, {0.16, 0.54}, {0.50, 0.72}, {1, 1} },
	locked = false,
	inheritance = 0,
	fractions = { 0.12, 0.36, 0.60, 0.84 },
	groups = {
		Fusion = {
			{ name = "Hot", first = {255, 167, 69}, last = {255, 82, 25}, rise = 0.16 },
			{ name = "Cold", first = {177, 245, 255}, last = {70, 183, 255}, rise = 0.06 },
		},
		Void = {
			{ name = "Shadow", first = {187, 112, 255}, last = {116, 43, 202}, rise = 0.10 },
		},
	},
}

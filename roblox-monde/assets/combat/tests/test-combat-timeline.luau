local Timeline = require("../shared/AttackTimeline")
local tested = 0
local function check(ok, message)
	assert(ok, message)
	tested += 1
end
for _, duration in { 0.38, 1.0, 1.1, 1.12, 1.15, 1.38, 1.4, 1.42, 1.85 } do
	local rig = {}
	local hitTime = duration * 0.44
	check(Timeline.start(rig, 10, duration, hitTime), "First trigger")
	check(not Timeline.start(rig, 10.2, duration, hitTime), "No retrigger")
	local t, weight, impact, active = Timeline.sample(rig, 10)
	check(t == 0 and weight == 0 and not impact and active, "Smooth beginning")
	t, weight, impact, active = Timeline.sample(rig, 10 + hitTime + 0.01)
	check(impact and active and weight > 0.9, "Impact once")
	local _, _, twice = Timeline.sample(rig, 10 + hitTime + 0.02)
	check(not twice, "No double impact")
	t, weight, impact, active = Timeline.sample(rig, 10 + duration - 0.03)
	check(active and weight < 0.25 and weight > 0, "Smooth ending")
	t, weight, impact, active = Timeline.sample(rig, 10 + duration + 0.1)
	check(t == duration and weight == 0 and not impact and not active and not rig.attack, "Finished, no loop")
	for frame = 1, 20 do
		local elapsed, _, again, playing = Timeline.sample(rig, 12 + frame)
		check(elapsed == nil and not again and not playing, "Stays finished")
	end
	check(Timeline.start(rig, 40, duration, hitTime), "Restart after finish")
	Timeline.cancel(rig)
	local _, _, cancelled = Timeline.sample(rig, 41)
	check(not rig.attack and not cancelled, "Cancellation")
	check(Timeline.start(rig, 60, duration, hitTime), "Low-FPS start")
	check(not Timeline.start(rig, 70, duration, hitTime), "Pending event not overwritten")
	local _, _, late, still = Timeline.sample(rig, 70)
	check(late and not still and not rig.attack, "Late step preserves impact")
	local _, _, lateTwice = Timeline.sample(rig, 71)
	check(not lateTwice, "Late event only once")
end
local bad = {}
check(not pcall(function() Timeline.start(bad, 0 / 0, 1, 0.4) end), "Reject NaN")
check(not pcall(function() Timeline.start(bad, 0, math.huge, 0.4) end), "Reject infinite duration")
check(not pcall(function() Timeline.start(bad, 0, 1, 2) end), "Reject invalid impact")
print("COMBAT_TIMELINE_TESTS_OK", tested)

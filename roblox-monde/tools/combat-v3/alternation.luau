local Motion = require("../../src/client/CombatMotion")
local checks, state = 0, {}
local function check(condition, message)
	assert(condition, message)
	checks += 1
end
for i = 1, 40 do
	local expected = if i % 2 == 1 then "SlashRight" else "SlashLeft"
	check(Motion.observeAttack(state, 100 + i * 0.42, 0.01) == expected, "Alternation")
	check(Motion.observeAttack(state, 100 + i * 0.42, 0.2) == expected and state.attackIndex == i, "No duplicate event")
end
local pending = {}
check(Motion.observeAttack(pending, 200, -0.01) == "SlashRight" and not pending.lastAttackStamp, "Future stamp safe")
check(Motion.observeAttack(pending, 200, 0) == "SlashRight" and pending.attackIndex == 1, "Pending first strike")
check(Motion.observeAttack(pending, 201, 0.02) == "SlashLeft", "Reverse next strike")
check(Motion.observeAttack(pending, 202, 2) == "SlashLeft" and pending.attackIndex == 2, "Expired event skipped")
check(Motion.duration == 0.38, "Visual duration unchanged")
check(not Motion.trail(0) and not Motion.trail(0.38), "No idle/return trail")
check(Motion.trail(0.076) and Motion.trail(0.296), "Trail follows wide cut")
check(Motion.weight(0) == 0 and Motion.weight(0.38) == 0, "Locomotion endpoints")
check(Motion.weight(0.1) == 1 and Motion.weight(0.29) == 1, "Wrist override during cut")
print("WIDE_COMBAT_TIMING_OK", checks)

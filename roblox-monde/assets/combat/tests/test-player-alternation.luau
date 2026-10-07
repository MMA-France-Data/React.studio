local Motion = require("../personnage/src/client/CombatMotion")
local tests = 0
local function check(condition, message)
    assert(condition, message)
    tests += 1
end
local state = {}
check(Motion.observeAttack(state, 0, 100) == "SlashRight" and not state.attackIndex, "No invented attack")
for i = 1, 40 do
    local stamp = 100 + i * .42
    local expected = if i % 2 == 1 then "SlashRight" else "SlashLeft"
    check(Motion.observeAttack(state, stamp, .01) == expected, "Alternating at 420 ms cooldown")
    check(Motion.observeAttack(state, stamp, .17) == expected and state.attackIndex == i, "Same stamp selects only once")
end
local future = {}
check(Motion.observeAttack(future, 200, -.025) == "SlashRight" and not future.lastAttackStamp, "Future stamp not consumed")
check(Motion.observeAttack(future, 200, 0) == "SlashRight" and future.attackIndex == 1, "First pending cut")
check(Motion.observeAttack(future, 201, -.005) == "SlashRight" and future.attackIndex == 1, "Keep current cut while future")
check(Motion.observeAttack(future, 201, .01) == "SlashLeft" and future.attackIndex == 2, "Pending next cut alternates")
check(Motion.observeAttack(future, 202, 2) == "SlashLeft" and future.attackIndex == 2, "Expired unseen cut doesn't play or advance")
check(Motion.observeAttack(future, 203, .04) == "SlashRight" and future.attackIndex == 3, "Next visible cut after gap")
local respawn = {}
check(Motion.observeAttack(respawn, 204, .01) == "SlashRight", "New character starts left to right")
print("TWO_CIRCULAR_CUTS_ALTERNATION_OK", tests)

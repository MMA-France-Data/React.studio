-- Backwards-compatible wrapper: Attack remains the default, Bite is optional.
-- These helpers belong to the separate gallery, never to the live game.
local Base = require(script.Parent.CombatAnimator)
local Timeline = require(script.Parent.AttackTimeline)
local ActionAnimator = {}

function ActionAnimator.bind(model: Model)
	local rig = Base.bind(model)
	rig.defaultAttack = rig.clips.Attack
	if rig.clips.Bite then
		assert(not rig.clips.Bite.loop and rig.clips.Bite.impactTime, "Bite doit avoir un seul Impact et ne pas boucler")
	end
	return rig
end

function ActionAnimator.playAttack(rig, now: number, action: string?)
	local name = action or "Attack"
	assert(name == "Attack" or name == "Bite", "Action inconnue")
	local clip = if name == "Attack" then rig.defaultAttack else rig.clips.Bite
	if not clip then return false end
	-- Reject retriggers before changing the active track: the current hit must
	-- never be replaced or lost, even if the next frame arrives very late.
	if not Timeline.start(rig, now, clip.duration, clip.impactTime) then return false end
	rig.clips.Attack = clip
	return true
end

function ActionAnimator.cancelAttack(rig)
	Base.cancelAttack(rig)
	rig.clips.Attack = rig.defaultAttack
end

function ActionAnimator.step(rig, now: number, mode: string?)
	local impact, active = Base.step(rig, now, mode)
	if not active then rig.clips.Attack = rig.defaultAttack end
	return impact, active
end

return ActionAnimator

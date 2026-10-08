-- Pure timing logic: one-shot attacks, one Impact signal, no automatic retrigger.
local Timeline = {}

function Timeline.start(state, now: number, duration: number, impactTime: number)
	assert(now == now and math.abs(now) < math.huge, "Temps invalide")
	assert(duration > 0 and duration < math.huge, "Durée invalide")
	assert(impactTime > 0 and impactTime < duration, "Impact invalide")
	-- Even an expired action must be sampled before replacing it, so a low-FPS
	-- frame cannot silently discard the previous Impact signal.
	if state.attack then
		return false
	end
	state.attack = { started = now, duration = duration, impactTime = impactTime, fired = false }
	return true
end

function Timeline.sample(state, now: number)
	local attack = state.attack
	if not attack then return nil, 0, false, false end
	local elapsed = math.max(0, now - attack.started)
	local impact = false
	if not attack.fired and elapsed >= attack.impactTime then
		attack.fired = true
		impact = true
	end
	if elapsed >= attack.duration then
		state.attack = nil
		return attack.duration, 0, impact, false
	end
	local fadeIn = math.clamp(elapsed / 0.065, 0, 1)
	local fadeOut = math.clamp((attack.duration - elapsed) / 0.13, 0, 1)
	return elapsed, math.min(fadeIn, fadeOut), impact, true
end

function Timeline.cancel(state)
	state.attack = nil
end

return Timeline

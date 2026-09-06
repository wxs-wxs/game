class_name DayCycleService
extends RefCounted

## Advances the simulation clock without deciding what happens at dusk.
func advance(clock: TimeManager, phase: String, delta: float) -> Dictionary:
	var elapsed_before := float(clock.elapsed)
	var ticks := clock.advance(delta)
	var elapsed_after := float(clock.elapsed)
	return {
		"elapsed_before": elapsed_before,
		"elapsed_after": elapsed_after,
		"ticks": ticks,
		"finished": clock.is_finished() and phase == GameManager.PHASE_DAY
	}

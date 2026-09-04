extends SceneTree

## Regression coverage for the simulation/world-clock conversion.  In
## particular, a normal frame must advance a fraction of an in-game hour, not
## derive hours directly from the frame delta.
func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var timer := TimeManager.new()
	assert(TimeManager.REAL_SECONDS_PER_GAME_HOUR == 10.0)
	assert(TimeManager.DAY_SECONDS == 120.0)
	assert(TimeManager.WORK_INTERVAL > 0.0)
	assert(timer.world_hour() == TimeManager.DAY_START_HOUR)
	assert(timer.clock_text() == "06时")

	# Sixty small frames are still less than one world hour.  This catches the
	# old class of bug where each frame was converted as if it were an hour.
	var small_step_elapsed := 0.0
	for index in range(60):
		small_step_elapsed += 0.016
		timer.advance(0.016)
	assert(is_equal_approx(timer.elapsed, small_step_elapsed))
	assert(timer.world_hour() == TimeManager.DAY_START_HOUR)
	assert(timer.clock_text() == "06时")
	var micro_step := TimeManager.new()
	micro_step.advance(0.0000001)
	assert(micro_step.elapsed > 0.0)

	# One complete real-time hour of pacing moves the world clock by exactly one
	# hour at speed 1, while the display remains hour-only.
	timer.advance(TimeManager.REAL_SECONDS_PER_GAME_HOUR - small_step_elapsed)
	assert(timer.world_hour() == 7)
	assert(timer.clock_text() == "07时")

	# Pause freezes both elapsed time and work ticks.
	var paused_elapsed := timer.elapsed
	var paused_accumulator := timer.work_accumulator
	timer.paused = true
	assert(timer.advance(30.0) == 0)
	assert(is_equal_approx(timer.elapsed, paused_elapsed))
	assert(is_equal_approx(timer.work_accumulator, paused_accumulator))
	timer.paused = false

	# Speed is a multiplier on simulation seconds, not on the world-hour
	# conversion itself.  Three seconds at speed 3 equals nine seconds at speed
	# 1, and neither should skip a world-clock hour.
	var speed_one := TimeManager.new()
	var speed_three := TimeManager.new()
	speed_three.speed = 3
	speed_one.advance(3.0)
	speed_three.advance(3.0)
	assert(is_equal_approx(speed_three.elapsed, speed_one.elapsed * 3.0))
	assert(speed_one.world_hour() == speed_three.world_hour())
	var work_timer := TimeManager.new()
	var work_ticks := 0
	for index in range(TimeManager.WORK_TICKS_PER_DAY):
		work_ticks += work_timer.advance(TimeManager.WORK_INTERVAL)
	assert(work_ticks == TimeManager.WORK_TICKS_PER_DAY)
	assert(work_timer.is_finished())

	# A large catch-up frame is capped at dusk and cannot produce more than the
	# configured number of work ticks for one day.
	var ticks := timer.advance(TimeManager.DAY_SECONDS * 2.0)
	assert(timer.is_finished())
	assert(timer.world_hour() == TimeManager.DAY_END_HOUR)
	assert(timer.clock_text() == "18时")
	assert(ticks <= TimeManager.WORK_TICKS_PER_DAY)
	assert(timer.advance(1.0) == 0)

	# GameManager uses the same TimeManager path for exploration and respects its
	# pause state.
	var game := GameManager.new()
	game.start_exploration()
	game.advance_exploration(1.0)
	assert(is_equal_approx(game.time.elapsed, 1.0))
	game.time.paused = true
	game.advance_exploration(10.0)
	assert(is_equal_approx(game.time.elapsed, 1.0))

	print("TIME_MANAGER_REGRESSION_OK day_seconds=%.1f work_interval=%.3f clock=%s" % [TimeManager.DAY_SECONDS, TimeManager.WORK_INTERVAL, timer.clock_text()])
	quit()

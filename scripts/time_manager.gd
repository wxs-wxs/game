class_name TimeManager
extends RefCounted

## The playable day runs from dawn to dusk.  `elapsed` remains in real
## simulation seconds so callers can continue to pass the frame `delta`, while
## these constants make the world-time conversion explicit and easy to tune.
const DAY_START_HOUR: int = 6
const DAY_END_HOUR: int = 18
const WORLD_HOURS_PER_DAY: int = DAY_END_HOUR - DAY_START_HOUR
const REAL_SECONDS_PER_GAME_HOUR: float = 10.0
const WORK_TICKS_PER_DAY: int = 7
const DAY_SECONDS: float = REAL_SECONDS_PER_GAME_HOUR * float(WORLD_HOURS_PER_DAY)
const WORK_INTERVAL: float = DAY_SECONDS / float(WORK_TICKS_PER_DAY)
const _EPSILON: float = 0.000001

var elapsed: float = 0.0
var work_accumulator: float = 0.0
var speed: int = 1
var paused: bool = false

func reset_day() -> void:
	elapsed = 0.0
	work_accumulator = 0.0
	paused = false

func advance(delta: float) -> int:
	if paused or is_finished(): return 0
	# Frame deltas are expected to be non-negative.  Clamping here keeps a
	# delayed/invalid frame from moving the world clock backwards and limits a
	# large catch-up frame to the remaining portion of this day.
	var frame_delta := maxf(delta, 0.0)
	if frame_delta <= 0.0: return 0
	speed = clampi(speed, 1, 3)
	var adjusted := frame_delta * float(speed)
	var remaining := maxf(DAY_SECONDS - elapsed, 0.0)
	var applied := minf(adjusted, remaining)
	if applied <= 0.0:
		elapsed = DAY_SECONDS
		return 0
	elapsed += applied
	if elapsed >= DAY_SECONDS - _EPSILON: elapsed = DAY_SECONDS
	work_accumulator += applied
	var ticks := 0
	while work_accumulator + _EPSILON >= WORK_INTERVAL:
		work_accumulator -= WORK_INTERVAL
		ticks += 1
	if absf(work_accumulator) <= _EPSILON: work_accumulator = 0.0
	return ticks

func is_finished() -> bool:
	return elapsed >= DAY_SECONDS

func progress() -> float:
	return clampf(elapsed / DAY_SECONDS, 0.0, 1.0)

## Fractional world-clock hour, beginning at `DAY_START_HOUR`.
func world_time_hours() -> float:
	return float(DAY_START_HOUR) + progress() * float(WORLD_HOURS_PER_DAY)

## Current world-clock hour.  Minutes are intentionally not exposed in the
## display API: the HUD changes only when this integer changes.
func world_hour() -> int:
	return clampi(int(floor(world_time_hours())), DAY_START_HOUR, DAY_END_HOUR)

func clock_text() -> String:
	return "%02d时" % world_hour()

## Number of work ticks still due before the current day reaches dusk.
func remaining_work_ticks() -> int:
	if is_finished(): return 0
	var pending := (DAY_SECONDS - elapsed) + work_accumulator
	return maxi(0, int(ceil((pending - _EPSILON) / WORK_INTERVAL)))

func to_dict() -> Dictionary:
	return {"elapsed":elapsed,"work_accumulator":work_accumulator,"speed":speed,"paused":paused}

func from_dict(data: Dictionary) -> void:
	elapsed = clampf(float(data.get("elapsed", 0.0)), 0.0, DAY_SECONDS)
	work_accumulator = maxf(float(data.get("work_accumulator", 0.0)), 0.0)
	speed = clampi(int(data.get("speed", 1)), 1, 3)
	paused = bool(data.get("paused", false))

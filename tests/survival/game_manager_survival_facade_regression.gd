extends SceneTree

const AudioServiceResource = preload("res://scripts/audio_service.gd")

func _init() -> void:
	var game := GameManager.new()
	assert(game.get("_day_cycle_service") != null)
	assert(game.get("_temperature_service") != null)
	assert(game.get("_fire_state_service") != null)
	assert(game.get("_night_settlement_service") != null)
	game.start_exploration()
	game.time.elapsed = TimeManager.DAY_SECONDS
	game.advance_exploration(0.1)
	assert(game.day_return_required)
	var first := game.finish_exploration_day()
	assert(bool(first.get("ok", false)))
	assert(game.phase in [GameManager.PHASE_EVENT, GameManager.PHASE_REPORT, GameManager.PHASE_ENDED])
	var second := game.finish_exploration_day()
	assert(not bool(second.get("ok", false)))
	var audio := AudioServiceResource.new()
	audio.headless_mode = true
	root.add_child(audio)
	var doomed := GameManager.new()
	doomed.audio = audio
	doomed.start_exploration()
	doomed.day_return_required = true
	doomed.events.definitions = {}
	doomed.resources.amounts["food"] = 0
	doomed.get_protagonist().health = 10
	doomed.get_protagonist().hunger = 0
	var death := doomed.finish_exploration_day()
	assert(bool(death.get("ok", false)))
	assert(_count_audio(audio, "player.death") == 1)
	assert(_count_audio(audio, "game.over") == 1)
	print("GAME_MANAGER_SURVIVAL_FACADE_REGRESSION_OK")
	quit()

func _count_audio(audio: Node, event_id: String) -> int:
	var count := 0
	for record in audio.event_log:
		if str(record.get("event_id", "")) == event_id:
			count += 1
	return count

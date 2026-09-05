extends SceneTree

const DayCycleService = preload("res://scripts/domain/survival/day_cycle_service.gd")
const TemperatureService = preload("res://scripts/domain/survival/temperature_service.gd")
const FireStateService = preload("res://scripts/domain/survival/fire_state_service.gd")

func _init() -> void:
    var clock := TimeManager.new()
    var cycle := DayCycleService.new()
    var advanced := cycle.advance(clock, GameManager.PHASE_DAY, TimeManager.DAY_SECONDS)
    assert(bool(advanced.get("finished", false)))
    var fire := FireStateService.new()
    var states := fire.default_states()
    assert(not fire.is_active(states, "house_fireplace"))
    var resources := ResourceManager.new()
    var added := fire.add_fuel(states, "house_fireplace", 1, resources, {"wood_seconds": 30.0})
    assert(bool(added.get("ok", false)))
    assert(fire.is_active(states, "house_fireplace"))
    var temperature := TemperatureService.new()
    assert(temperature.environment_temperature("寒冷", true, states, {"warmth_bonus": 0.0}) < 10.0)
    print("SURVIVAL_DOMAIN_REGRESSION_OK")
    quit()

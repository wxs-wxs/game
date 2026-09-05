class_name TemperatureService
extends RefCounted

const FireStateServiceClass = preload("res://scripts/domain/survival/fire_state_service.gd")

const NORMAL_BODY_TEMPERATURE_C := 37.0
const BODY_TEMPERATURE_DAMAGE_THRESHOLD_C := 35.0
const BODY_TEMPERATURE_DAMAGE_INTERVAL := 8.0
const WEATHER_TEMPERATURES := {"晴朗": 16.0, "多云": 11.0, "浓雾": 7.0, "暴雨": 9.0, "寒冷": -5.0}
const DEFAULT_HOUSE_FIREPLACE_WARMTH := 7.0
const DEFAULT_CAMPFIRE_WARMTH := 6.0

func environment_temperature(weather: String, in_house: bool, fire_states: Dictionary, building_effects: Dictionary) -> float:
	var temperature := float(WEATHER_TEMPERATURES.get(weather, 12.0))
	temperature += float(building_effects.get("daylight_bonus", 0.0))
	if in_house:
		temperature += 10.0
		if FireStateServiceClass.new().is_active(fire_states, "house_fireplace"):
			var house_warmth := DEFAULT_HOUSE_FIREPLACE_WARMTH
			if building_effects.has("house_fireplace_warmth"):
				house_warmth = float(building_effects["house_fireplace_warmth"])
			elif building_effects.has("warmth_bonus"):
				house_warmth = float(building_effects["warmth_bonus"])
			temperature += house_warmth
	if bool(building_effects.get("fire_basin", false)):
		temperature += 4.0
	if not in_house and FireStateServiceClass.new().is_active(fire_states, "campfire"):
		var campfire_warmth := DEFAULT_CAMPFIRE_WARMTH
		if building_effects.has("campfire_warmth"):
			campfire_warmth = float(building_effects["campfire_warmth"])
		elif building_effects.has("warmth_bonus"):
			campfire_warmth = float(building_effects["warmth_bonus"])
		temperature += campfire_warmth
	return snappedf(temperature, 0.1)

func apply_damage(hero: Survivor, simulation_seconds: float, context: Dictionary) -> Dictionary:
	if hero == null or not hero.alive or simulation_seconds <= 0.0:
		return {"damage": 0, "body_temperature": hero.body_temperature if hero != null else NORMAL_BODY_TEMPERATURE_C, "accumulator": hero.temperature_damage_accumulator if hero != null else 0.0}
	var environment := float(context.get("environment_temperature", 12.0))
	var target := clampf(NORMAL_BODY_TEMPERATURE_C + (environment - 12.0) * 0.35, 28.0, NORMAL_BODY_TEMPERATURE_C)
	var response := 0.006 if target < NORMAL_BODY_TEMPERATURE_C else 0.009
	hero.body_temperature = clampf(hero.body_temperature + (target - hero.body_temperature) * response * simulation_seconds, -50.0, NORMAL_BODY_TEMPERATURE_C)
	var damage := 0
	if hero.body_temperature < BODY_TEMPERATURE_DAMAGE_THRESHOLD_C:
		hero.temperature_damage_accumulator += simulation_seconds
		while hero.temperature_damage_accumulator >= BODY_TEMPERATURE_DAMAGE_INTERVAL:
			hero.temperature_damage_accumulator -= BODY_TEMPERATURE_DAMAGE_INTERVAL
			hero.apply_change("health", -1)
			damage += 1
	else:
		hero.temperature_damage_accumulator = maxf(0.0, hero.temperature_damage_accumulator - simulation_seconds * 0.5)
	return {"damage": damage, "body_temperature": hero.body_temperature, "accumulator": hero.temperature_damage_accumulator, "alive": hero.alive}

func status(hero: Survivor, environment_temperature: float) -> Dictionary:
	return {"environment": environment_temperature, "body": float(hero.body_temperature) if hero != null else NORMAL_BODY_TEMPERATURE_C, "threshold": BODY_TEMPERATURE_DAMAGE_THRESHOLD_C}

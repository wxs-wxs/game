extends SceneTree

const AudioCatalogResource = preload("res://scripts/audio_catalog.gd")

const APPROVED_IDS := [
	"ui.open", "ui.close", "ui.confirm", "ui.cancel", "ui.invalid", "ui.save_complete", "ui.load_complete",
	"player.footstep", "player.hurt", "player.eat", "player.use_medicine", "player.cold_warning",
	"interaction.start", "interaction.cancel", "interaction.complete", "interaction.failed", "interaction.blocked",
	"gather.hit", "gather.collect", "fishing.cast", "fishing.catch", "craft.complete", "craft.failed",
	"build.place", "build.progress", "build.complete", "build.invalid", "house.upgrade",
	"door.open", "door.close", "fire.ignite", "fire.extinguish", "fire.fuel_low",
	"survival.food_warning", "survival.temperature_warning", "survival.threat_changed", "survival.raid",
	"day.dawn", "day.dusk_warning", "sleep.begin", "night.report", "event.reveal", "event.choice",
	"task.complete", "milestone.reached", "blueprint.unlocked",
	"player.death", "game.over"
]

const BUS_PARENTS := {
	"Master": "", "Music": "Master", "Ambience": "Master", "Environment": "Ambience",
	"Weather": "Ambience", "Fire": "Ambience", "SFX": "Master", "World": "SFX",
	"UI": "SFX", "Critical": "SFX", "Voice": "Master"
}

func _init() -> void:
	var catalog: AudioCatalog = AudioCatalogResource.load_from_path("res://data/audio_catalog.json")
	assert(catalog != null, "catalog should load")
	for cue_id in APPROVED_IDS:
		assert(catalog.has_cue(cue_id), "missing approved cue: %s" % cue_id)
	var errors: Array[String] = catalog.validate()
	assert(errors.is_empty(), "catalog validation errors: %s" % [errors])
	var missing_variant = catalog.get_cue("ui.open")
	assert(missing_variant != null)
	assert(catalog.fallback_for(missing_variant) != null, "cue fallback should resolve")
	assert(catalog.fallback_for(missing_variant).stream_paths.size() > 0)
	for bus_name in BUS_PARENTS:
		var bus_index := AudioServer.get_bus_index(bus_name)
		assert(bus_index >= 0, "missing audio bus: %s" % bus_name)
		assert(AudioServer.get_bus_send(bus_index) == BUS_PARENTS[bus_name], "wrong parent for bus: %s" % bus_name)
	print("AUDIO_CATALOG_OK cues=%d validation_errors=%d" % [APPROVED_IDS.size(), errors.size()])
	quit()

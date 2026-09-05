extends SceneTree

const AudioServiceResource = preload("res://scripts/audio_service.gd")
const SETTINGS_PATH := "user://audio_save_regression.cfg"

func _init() -> void:
	var service = root.get_node_or_null("AudioService")
	if service == null:
		service = AudioServiceResource.new()
		service.name = "AudioService"
		root.add_child(service)
	service.apply_settings({"master": 1.0, "music": 1.0, "ambience": 1.0, "sfx": 1.0, "sfx_enabled": true})
	assert(service.to_settings_dict().get("sfx_enabled", true), "音效默认应为开启")

	var game := GameManager.new()
	game.audio = service
	game.from_dict({
		"version": GameManager.SAVE_VERSION,
		"audio": {"music": 0.25, "sfx": 0.5, "ambience": 0.75},
	})
	var migrated: Dictionary = service.to_settings_dict()
	assert(is_equal_approx(float(migrated["music"]), 0.25))
	assert(is_equal_approx(float(migrated["sfx"]), 0.5))
	assert(is_equal_approx(float(migrated["ambience"]), 0.75))
	assert(is_equal_approx(float(migrated["master"]), 1.0), "legacy fields must not invent master")

	var save_data := game.to_dict()
	assert(not save_data.has("audio"), "new saves must omit global audio preferences")

	service.apply_settings({"master": 0.9, "music": 0.4, "ambience": 0.6, "sfx": 0.8})
	service.apply_settings({"sfx_enabled": false})
	var muted_data: Dictionary = service.to_settings_dict()
	assert(not bool(muted_data.get("sfx_enabled", true)), "关闭音效应保存独立开关")
	assert(is_equal_approx(float(muted_data["sfx"]), 0.8), "关闭音效不能丢失原音效音量")
	assert(float(service.last_snapshot_targets["Master"]) <= -79.0, "关闭游戏声音应静音主总线")
	assert(float(service.last_snapshot_targets["Music"]) <= -79.0, "关闭游戏声音应静音背景音乐")
	assert(float(service.last_snapshot_targets["Ambience"]) <= -79.0, "关闭游戏声音应静音环境声")
	assert(float(service.last_snapshot_targets["SFX"]) <= -79.0, "关闭游戏声音应静音操作音效")
	game.from_dict({"version": GameManager.SAVE_VERSION, "audio": {}})
	assert(is_equal_approx(float(service.to_settings_dict()["music"]), 0.4), "empty legacy audio must not overwrite settings")
	game.from_dict({"version": GameManager.SAVE_VERSION, "audio": {"sfx": 0.2}})
	var partial: Dictionary = service.to_settings_dict()
	assert(is_equal_approx(float(partial["music"]), 0.4), "missing legacy fields must be preserved")
	assert(is_equal_approx(float(partial["sfx"]), 0.2))

	var persisted := AudioServiceResource.new()
	persisted.apply_settings({"master": 0.7, "music": 0.3, "ambience": 0.5, "sfx": 0.9, "sfx_enabled": false})
	assert(persisted.settings.save_to_config(SETTINGS_PATH) == OK)
	var restored = AudioServiceResource.new()
	assert(restored.settings.load_from_config(SETTINGS_PATH))
	var restored_data: Dictionary = restored.to_settings_dict()
	assert(is_equal_approx(float(restored_data["master"]), 0.7))
	assert(is_equal_approx(float(restored_data["music"]), 0.3))
	assert(is_equal_approx(float(restored_data["ambience"]), 0.5))
	assert(is_equal_approx(float(restored_data["sfx"]), 0.9))
	assert(not bool(restored_data.get("sfx_enabled", true)), "音效关闭状态应跨启动保存")
	restored.apply_settings({"sfx_enabled": true})
	assert(float(restored.last_snapshot_targets["SFX"]) > -1.0, "重新开启音效应恢复保存的音量")
	assert(is_equal_approx(float(restored.last_snapshot_targets["Music"]), linear_to_db(0.3)), "重新开启声音应恢复保存的背景音乐音量")
	assert(is_equal_approx(float(restored.last_snapshot_targets["Ambience"]), linear_to_db(0.5)), "重新开启声音应恢复保存的环境声音量")

	print("AUDIO_SAVE_OK legacy=3 omitted_audio=true persistence=true safe_missing=true")
	for node in [restored, persisted]:
		if is_instance_valid(node):
			node.free()
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
	quit()

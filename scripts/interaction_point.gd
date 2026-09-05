class_name InteractionPoint
extends Area2D

signal interaction_completed(point: InteractionPoint, result: Dictionary)
signal interaction_started(point: InteractionPoint)
signal interaction_progress_changed(point: InteractionPoint, progress: float)

@export var unique_id: String = "interaction"
@export var display_name: String = "交互点"
@export var interaction_range: float = 28.0
@export var interaction_time: float = 1.5
@export var cooldown_time: float = 8.0
@export var required_resources: Dictionary = {}
@export var required_tools: Array[String] = []
@export var reward: Dictionary = {}
@export var failure_text: String = "什么也没有找到。"
@export_range(0.0, 1.0) var failure_chance: float = 0.0
@export var action_id: String = "interact"
@export var respawn_delay: float = 0.0

var cooldown_remaining: float = 0.0
var uses_left: int = -1
var game: GameManager
var pulse: float = 0.0
var interaction_progress: float = 0.0
var interacting := false
var respawn_remaining: float = 0.0
## Optional pixel art from the CC0 Ninja Adventure pack. Subclasses set this
## in _init(); the interaction/collision logic remains unchanged.
var art_texture: Texture2D
var art_scale := Vector2.ONE
var art_offset := Vector2.ZERO
var art_sprite: Sprite2D

func _ready() -> void:
	_refresh_art_sprite()
	queue_redraw()

func set_art(texture: Texture2D, scale_value := Vector2.ONE, offset := Vector2.ZERO) -> void:
	art_texture = texture
	art_scale = scale_value
	art_offset = offset
	_refresh_art_sprite()

func _refresh_art_sprite() -> void:
	if art_texture == null:
		return
	if art_sprite == null:
		art_sprite = Sprite2D.new()
		art_sprite.name = "ArtSprite"
		art_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		art_sprite.z_index = 1
		add_child(art_sprite)
	art_sprite.texture = art_texture
	art_sprite.position = art_offset
	art_sprite.scale = art_scale

func setup(manager: GameManager) -> void:
	game = manager
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = interaction_range
	shape.shape = circle
	add_child(shape)
	monitoring = true
	monitorable = true
	queue_redraw()

func _process(delta: float) -> void:
	if game == null or not game.time.paused: cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
	if respawn_remaining > 0.0 and (game == null or not game.time.paused):
		respawn_remaining = maxf(0.0, respawn_remaining - delta)
		if respawn_remaining <= 0.0:
			if game != null and game.exploration_world != null and game.exploration_world.has_method("respawn_point"):
				game.exploration_world.respawn_point(self)
			else:
				show()
	pulse += delta
	var art := get_node_or_null("ArtSprite") as Sprite2D
	if art != null:
		art.modulate = Color.WHITE if can_interact() else Color("53615d")
	queue_redraw()

func tick_interaction(delta: float) -> Dictionary:
	if not interacting or game == null or game.time.paused: return {}
	interaction_progress = minf(interaction_time, interaction_progress + delta)
	interaction_progress_changed.emit(self, interaction_progress / maxf(0.01, interaction_time))
	if interaction_progress < interaction_time: return {"active":true}
	interacting = false
	interaction_progress = 0.0
	_stop_player_action()
	var result := _complete_interaction()
	interaction_completed.emit(self, result)
	return result

func cancel_interaction() -> void:
	if interacting:
		interacting = false
		interaction_progress = 0.0
		if game != null and game.audio != null and game.audio.has_method("emit_event"):
			game.audio.emit_event("interaction.cancel")
		_stop_player_action()
		interaction_progress_changed.emit(self, 0.0)

func can_interact() -> bool:
	return visible and respawn_remaining <= 0.0 and cooldown_remaining <= 0.0 and (uses_left != 0) and has_required_tools()

func has_required_tools() -> bool:
	if game == null or required_tools.is_empty(): return true
	for tool_id in required_tools:
		if not game.resources.has_method("has_tool") or not game.resources.has_tool(str(tool_id)):
			return false
	return true

func missing_tools() -> Array[String]:
	var missing: Array[String] = []
	if game == null: return missing
	for tool_id in required_tools:
		var id := str(tool_id)
		if not game.resources.has_method("has_tool") or not game.resources.has_tool(id):
			missing.append(game.resources.tool_display_name(id) if game.resources.has_method("tool_display_name") else id)
	return missing

func missing_tools_text() -> String:
	var missing := missing_tools()
	if missing.is_empty(): return ""
	return "需要%s。先制作%s。" % ["、".join(missing), "、".join(missing)]

func prompt_text() -> String:
	if interacting: return "[E] %s（进行中）" % display_name
	if not has_required_tools():
		var missing := missing_tools()
		return "%s（需要%s）" % [display_name, "、".join(missing) if not missing.is_empty() else "工具"]
	if not can_interact(): return "%s（冷却中）" % display_name
	return "[E] %s" % display_name

func interact() -> Dictionary:
	if interacting: return {"ok":false, "reason":"交互正在进行。", "active":true}
	if game == null: return {"ok":false, "reason":"交互系统未准备好。"}
	if not has_required_tools():
		var tool_reason := missing_tools_text()
		if game.audio != null and game.audio.has_method("emit_event"):
			game.audio.emit_event("interaction.blocked")
		return {"ok":false, "reason":tool_reason, "locked":true, "failed":true, "required_tools":required_tools.duplicate()}
	if not can_interact(): return {"ok":false, "reason":"%s 还需要等待。" % display_name}
	if not game.resources.can_afford(required_resources):
		if game.audio != null and game.audio.has_method("emit_event"):
			game.audio.emit_event("interaction.blocked")
		return {"ok":false, "reason":game.resources.missing_cost_text(required_resources)}
	interacting = true
	interaction_progress = 0.0
	_start_player_action()
	interaction_started.emit(self)
	if game.audio != null:
		if game.audio.has_method("emit_event"):
			game.audio.emit_event("interaction.start")
			if unique_id.begins_with("river_fishing"):
				game.audio.emit_event("fishing.cast")
	return {"ok":true, "message":"开始%s" % display_name, "started":true}

func _complete_interaction() -> Dictionary:
	if not has_required_tools():
		return {"ok":false, "message":missing_tools_text(), "failed":true, "locked":true}
	if not game.resources.can_afford(required_resources):
		return {"ok":false, "message":game.resources.missing_cost_text(required_resources), "failed":true}
	if not reward.is_empty() and not game.resources.can_collect_rewards(reward):
		return {"ok":false, "message":"携带空间不足，请先整理背包。", "failed":true}
	var fire_was_lit := false
	if unique_id == "campfire":
		fire_was_lit = game.is_fire_active("campfire")
	elif unique_id == "house_fireplace":
		fire_was_lit = game.is_fire_active("house_fireplace")
	var result := perform_interaction()
	if not bool(result.get("ok", false)) or bool(result.get("failed", false)):
		if game.audio != null and game.audio.has_method("emit_event"):
			game.audio.emit_event("interaction.failed")
		return result
	var interaction_rewards: Dictionary = reward.duplicate(true)
	var result_rewards = result.get("rewards", {})
	if result_rewards is Dictionary and not result_rewards.is_empty():
		interaction_rewards = result_rewards.duplicate(true)
	if not interaction_rewards.is_empty():
		var collected: Dictionary = game.resources.collect_rewards_atomic(interaction_rewards, unique_id)
		if not bool(collected.get("ok", false)):
			if game.audio != null and game.audio.has_method("emit_event"):
				game.audio.emit_event("interaction.failed")
			return {"ok":false, "message":str(collected.get("reason", "携带空间不足，请先整理背包。")), "failed":true}
	game.resources.spend(required_resources)
	cooldown_remaining = cooldown_time
	if uses_left > 0: uses_left -= 1
	if respawn_delay > 0.0:
		respawn_remaining = respawn_delay
		hide()
	game.daily_log.append("%s：%s" % [display_name, str(result.get("message", "完成"))])
	if game.audio != null:
		if game.audio.has_method("emit_event"):
			game.audio.emit_event("interaction.complete")
			var specific_event := _specific_event_id()
			if not specific_event.is_empty() and not (specific_event == "fire.ignite" and fire_was_lit):
				game.audio.emit_event(specific_event)
	return result

func allow_reward_overflow() -> bool:
	return false

func _start_player_action() -> void:
	if game == null or game.exploration_world == null: return
	var player = game.exploration_world.player
	if player != null and player.has_method("start_action"):
		player.start_action(action_id, interaction_time)

func _stop_player_action() -> void:
	if game == null or game.exploration_world == null: return
	var player = game.exploration_world.player
	if player != null and player.has_method("stop_action"):
		player.stop_action()

func _specific_event_id() -> String:
	if unique_id.begins_with("river_fishing"):
		return "fishing.catch"
	if unique_id.begins_with("forest_") or unique_id.begins_with("old_ruins"):
		return "gather.collect"
	if unique_id == "house_door":
		return "door.open"
	if unique_id == "house_exit":
		return "door.close"
	if unique_id == "campfire" or unique_id == "house_fireplace":
		return "fire.ignite"
	if unique_id == "house_sleep":
		return "sleep.begin"
	return ""

func perform_interaction() -> Dictionary:
	if failure_chance > 0.0 and game.rng.randf() < failure_chance:
		return {"ok":true, "message":failure_text, "failed":true}
	return {"ok":true, "message":"获得 %s" % reward_text()}

func reward_text() -> String:
	var parts: Array[String] = []
	for key in reward: parts.append("%s +%d" % [game.resources.display_name(str(key)), int(reward[key])])
	return "、".join(parts) if not parts.is_empty() else "无"

func _draw() -> void:
	if is_instance_valid(get_node_or_null("ArtSprite")): return
	var tint := Color("db9c55") if can_interact() else Color("596969")
	draw_circle(Vector2.ZERO, 9.0 + sin(pulse * 3.0) * 1.0, Color(tint, 0.22))
	draw_arc(Vector2.ZERO, 10.0, 0.0, TAU, 16, tint, 1.0)
	draw_rect(Rect2(-3, -3, 6, 6), tint)

# Ember Camp Endless Survival Loop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在现有 Godot 单主角探索游戏中实现可长期运行的“清晨 -> 探索 -> 回床 -> 夜间结算 -> 事件/报告 -> 清晨”无限生存循环，并保持旧存档、现有地图和已有系统兼容。

**Architecture:** `GameManager` 继续负责阶段切换和夜间结算，`EventSystem` 负责事件候选与选择，`BuildingSystem` 负责唯一建造账本，`ResourceManager` 负责原子资源操作，`UIController` 只消费状态并显示界面。主场景每帧调用一个统一的 `GameManager.advance(delta)`，不新增第二个生存循环管理器。

**Tech Stack:** Godot 4.7.2, GDScript, JSON 数据文件, Godot headless regression scripts, native CanvasLayer/Control HUD.

**Spec:** `docs/superpowers/specs/2026-09-04-endless-survival-loop-design.md`

## Global Constraints

- 保持单主角探索为主循环；旧多人工作制接口只能兼容，不能重新成为主流程。
- 游戏无限生存；天数持续递增，不存在第 7 天节点、七天胜利、七天重置或七天挑战目标。
- 白天采集数量固定使用 1.0 倍天气倍率；天气只影响温度、威胁和事件权重。
- 水资源只保留兼容字段和雨水收集数据，不加入本阶段的消耗、配方、事件成本或主 HUD。
- 所有设施使用一张清单、一套地图预览和一个统一施工账本；同时只能有一个施工点。
- 玩家必须回到床边并按 `E` 才能结束当天；白天时间耗尽只进入“等待回床”。
- 篝火和室内火盆没有燃料时不提供保暖；燃料状态必须保存和恢复。
- 交互进度条放在底部提示附近，尺寸小且固定，不在画面中央显示大面板。
- 暂停型窗口打开时停止白天时间和交互进度，关闭时恢复打开前的暂停状态。
- HUD 使用 `960x540` 逻辑坐标、Fusion Pixel 字体、Kenney Pixel UI 九宫格和最近邻过滤；所有位置和尺寸为整数。
- 不引入 Web UI、第二套资源账本、第二套事件管理器或新的 `SurvivalLoop` 管理器。
- 每个任务先写失败测试，再实现最小改动，再运行该任务测试和相关回归；修改完成后运行 Godot 编辑器解析检查。

---

### Task 1: 日循环和回床结束当天

**Files:**
- Modify: `scripts/game_manager.gd`
- Modify: `scripts/main.gd`
- Modify: `scripts/bed_point.gd`
- Modify: `scripts/exploration_world.gd`
- Modify: `tests/smoke.gd`
- Modify: `tests/strategy_smoke.gd`
- Create: `tests/endless_day_flow_regression.gd`

**Interfaces:**
- Produces `GameManager.advance(delta: float) -> void` as the single frame entry point.
- Produces `GameManager.begin_morning() -> void` to clear transient night state without incrementing the day.
- Produces `GameManager.finish_exploration_day() -> Dictionary` returning `{ "ok": bool, "phase": String, "reason": String }`.
- Produces `GameManager.day_return_required: bool` and `GameManager.night_settlement_applied: bool`.
- Keeps `start_exploration()`, `advance_exploration()`, `tick()`, and `finish_day()` as compatibility wrappers.

- [ ] **Step 1: Write the failing day-flow test**

Add `tests/endless_day_flow_regression.gd` with these assertions:

```gdscript
extends SceneTree

func _init() -> void:
	var game := GameManager.new()
	assert(game.phase == GameManager.PHASE_MORNING)
	assert(game.day == 1)
	game.start_exploration()
	assert(game.phase == GameManager.PHASE_DAY)
	game.time.elapsed = TimeManager.DAY_SECONDS
	game.advance(0.1)
	assert(game.phase == GameManager.PHASE_DAY)
	assert(game.day_return_required)
	assert(not game.night_settlement_applied)
	var result := game.finish_exploration_day()
	assert(bool(result.get("ok", false)))
	assert(game.phase in [GameManager.PHASE_EVENT, GameManager.PHASE_REPORT, GameManager.PHASE_ENDED])
	var day_after := game.day
	var repeated := game.finish_exploration_day()
	assert(not bool(repeated.get("ok", false)))
	assert(game.day == day_after)
	print("ENDLESS_DAY_FLOW_REGRESSION_OK day=%d phase=%s" % [game.day, game.phase])
	quit()
```

- [ ] **Step 2: Run the test and verify it fails**

Run:

```powershell
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/endless_day_flow_regression.gd --quit-after 10
```

Expected: FAIL because a new game currently starts in `DAY`, `advance_exploration()` can settle immediately at the clock end, and no public bed-gated finish result exists.

- [ ] **Step 3: Add the morning and return-required state**

In `scripts/game_manager.gd`:

```gdscript
var day_return_required: bool = false
var night_settlement_applied: bool = false
var night_context: Dictionary = {}

func begin_morning() -> void:
	phase = PHASE_MORNING
	day_return_required = false
	night_settlement_applied = false
	night_context = {}
	time.reset_day()
	survival.begin_day(day, weather, self)

func advance(delta: float) -> void:
	if check_protagonist_health():
		return
	if exploration_mode:
		advance_exploration(delta)
	else:
		tick(delta)
```

Change `advance_exploration()` so reaching `TimeManager.DAY_SECONDS` sets `day_return_required = true`, pauses only the simulation clock, and does not call `_finish_exploration_day()`. Add:

```gdscript
func finish_exploration_day() -> Dictionary:
	if phase != PHASE_DAY or not day_return_required:
		return {"ok": false, "phase": phase, "reason": "请先回到床边。"}
	if night_settlement_applied:
		return {"ok": false, "phase": phase, "reason": "今天已经结算。"}
	return _resolve_night()
```

For this task only, add a temporary report-only `_resolve_night()` implementation so the day-flow slice is independently runnable. Task 2 replaces its body with the full event-aware implementation:

```gdscript
func _resolve_night() -> Dictionary:
	night_settlement_applied = true
	report_lines = _night_settlement()
	phase = PHASE_REPORT
	return {"ok": true, "phase": phase, "reason": "夜间结算完成。"}
```

Keep `start_exploration()` as a direct test/compatibility entry that sets `PHASE_DAY`, but make `Main._ready()` call `begin_morning()` after setup so a new game opens at the camp in the morning.

- [ ] **Step 4: Route the bed interaction through the public finish entry**

In `scripts/bed_point.gd`, preserve short rest before dusk, but when `game.day_return_required` is true, call `game.finish_exploration_day()` directly. Do not increment `day` inside `BedPoint`:

```gdscript
func perform_interaction() -> Dictionary:
	if game == null:
		return {"ok": false, "message": "没有可休息的主角。", "failed": true}
	var hero: Survivor = game.get_protagonist()
	if hero == null:
		return {"ok": false, "message": "没有可休息的主角。", "failed": true}
	if sleep_mode and game.day_return_required:
		var result: Dictionary = game.finish_exploration_day()
		return {"ok": bool(result.get("ok", false)), "message": str(result.get("reason", "进入夜间结算。")), "failed": not bool(result.get("ok", false))}
	if sleep_mode and game.phase != GameManager.PHASE_DAY:
		return {"ok": false, "message": "现在还不能睡觉。", "failed": true}
	hero.apply_change("energy", 20)
	hero.apply_change("health", 2)
	return {"ok": true, "message": "在床铺上稍作休整。"}
```

Make `ExplorationWorld.try_interact()` reject new timed gathering/building actions when `game.day_return_required` is true, while still allowing movement and the bed interaction.

- [ ] **Step 5: Run the focused and existing lifecycle tests**

Run:

```powershell
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/endless_day_flow_regression.gd --quit-after 10
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/smoke.gd --quit-after 10
```

Expected: `ENDLESS_DAY_FLOW_REGRESSION_OK` and `SMOKE_OK`; `smoke.gd` may continue to call `start_exploration()` because that compatibility path remains valid.

Update the existing lifecycle assertions in `tests/smoke.gd` and `tests/strategy_smoke.gd`: replace direct `_finish_exploration_day()` calls with `day_return_required = true` followed by `finish_exploration_day()`. When the result is `PHASE_EVENT`, select an affordable choice before asserting `PHASE_REPORT`; then call `continue_from_report()` and assert `PHASE_MORNING` with the incremented day. The old assertion that day 7 becomes day 8 must be replaced by a multi-day assertion with no victory flag.

- [ ] **Step 6: Commit the lifecycle slice**

```powershell
git add scripts/game_manager.gd scripts/main.gd scripts/bed_point.gd scripts/exploration_world.gd tests/endless_day_flow_regression.gd
git commit -m "feat: gate night settlement behind bed interaction"
```

### Task 2: 夜间结算、事件和无限天数

**Files:**
- Modify: `scripts/game_manager.gd`
- Modify: `scripts/event_system.gd`
- Modify: `scripts/survival_director.gd`
- Modify: `data/events.json`
- Modify: `data/survival_director.json`
- Create: `tests/event_flow_regression.gd`

**Interfaces:**
- Produces `GameManager._resolve_night() -> Dictionary` as the single idempotent night entry.
- Produces `EventSystem.create_weighted_event(rng: RandomNumberGenerator, context: Dictionary) -> Dictionary`.
- Produces `EventSystem.event_weight(event_id: String, context: Dictionary) -> int`.
- Produces `EventSystem._apply_choice_effect(index: int, game) -> Array[String]` for existing event-specific effects.
- Keeps `EventSystem.create_event()` as a compatibility wrapper that uses default weights.
- Produces `SurvivalDirector.event_context(game) -> Dictionary` and keeps `weather_effect()` as the source of weather values.

- [ ] **Step 1: Write the failing event-flow test**

Create `tests/event_flow_regression.gd`:

```gdscript
extends SceneTree

func _init() -> void:
	var game := GameManager.new()
	game.start_exploration()
	game.day_return_required = true
	var result := game.finish_exploration_day()
	assert(bool(result.get("ok", false)))
	assert(game.phase in [GameManager.PHASE_EVENT, GameManager.PHASE_REPORT, GameManager.PHASE_ENDED])
	var phase_after_first := game.phase
	var second := game.finish_exploration_day()
	assert(not bool(second.get("ok", false)))
	assert(game.phase == phase_after_first)
	if game.phase == GameManager.PHASE_EVENT:
		var unaffordable_index := -1
		for index in range(2):
			if not game.resources.can_afford(game.events.choice_cost(index)):
				unaffordable_index = index
				break
		if unaffordable_index >= 0:
			var before_food := game.resources.get_amount("food")
			var bad := game.choose_event(unaffordable_index)
			assert(not bool(bad.get("ok", false)))
			assert(game.resources.get_amount("food") == before_food)
		var good_index := _first_affordable_choice(game)
		if good_index >= 0:
			var chosen := game.choose_event(good_index)
			assert(bool(chosen.get("ok", false)))
			assert(game.phase == GameManager.PHASE_REPORT or game.phase == GameManager.PHASE_ENDED)
	print("EVENT_FLOW_REGRESSION_OK phase=%s day=%d" % [game.phase, game.day])
	quit()

func _first_affordable_choice(game: GameManager) -> int:
	for index in range(2):
		if game.resources.can_afford(game.events.choice_cost(index)):
			return index
	return -1
```

- [ ] **Step 2: Run the test and verify it fails**

```powershell
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/event_flow_regression.gd --quit-after 10
```

Expected: FAIL because exploration settlement bypasses `EventSystem`, repeated settlement has no guard, and event weights do not exist.

- [ ] **Step 3: Add the shared night-resolution function**

Move the common food, temperature, threat, goal and report work into `_resolve_night()` and have both the exploration bed path and legacy `finish_day()` call it:

```gdscript
func _resolve_night() -> Dictionary:
	if night_settlement_applied:
		return {"ok": false, "phase": phase, "reason": "今天已经结算。"}
	night_settlement_applied = true
	night_context = {
		"day": day,
		"weather": weather,
		"resource_before": resources.to_dict(),
		"threat_before": survival.threat,
		"temperature_before": environment_temperature,
		"completed_buildings": _canonical_built_ids()
	}
	report_lines = _night_settlement()
	report_lines.append_array(survival.settle_day(self))
	if check_protagonist_health():
		return {"ok": true, "phase": phase, "reason": "主角生命值归零，游戏结束。"}
	var context := {"weather": weather, "threat": survival.threat, "built_facilities": _canonical_built_ids(), "recent_actions": survival.action_counts.duplicate(true)}
	var created := events.create_weighted_event(rng, context)
	if created.is_empty():
		phase = PHASE_REPORT
	else:
		phase = PHASE_EVENT
	return {"ok": true, "phase": phase, "reason": "夜间结算完成。"}
```

Do not increment `day` or roll weather here. `continue_from_report()` alone increments the day, rolls weather, clears the event, and calls `begin_morning()`.

- [ ] **Step 4: Implement weighted event selection with legacy defaults**

In `scripts/event_system.gd`, add filtering and weighted selection. Missing `base_weight` defaults to 10; missing modifiers default to zero:

```gdscript
func event_weight(event_id: String, context: Dictionary) -> int:
	var definition: Dictionary = definitions.get(event_id, {})
	var weight := int(definition.get("base_weight", 10))
	var weather_bonus: Dictionary = definition.get("weather_bonus", {})
	weight += int(weather_bonus.get(str(context.get("weather", "")), 0))
	weight += int(round(float(definition.get("threat_bonus", 0)) * float(context.get("threat", 0)) / 100.0))
	var facility_bonus: Dictionary = definition.get("facility_bonus", {})
	for facility_id in context.get("built_facilities", []):
		weight += int(facility_bonus.get(str(facility_id), 0))
	return maxi(0, weight)

func create_weighted_event(random: RandomNumberGenerator, context: Dictionary) -> Dictionary:
	var candidates: Array[Dictionary] = []
	var total := 0
	var keys: Array = definitions.keys()
	keys.sort()
	for key in keys:
		var event_id := str(key)
		var weight := event_weight(event_id, context)
		if weight <= 0:
			continue
		candidates.append({"id": event_id, "weight": weight})
		total += weight
	if candidates.is_empty() or total <= 0:
		current_event = {}
		return {}
	var roll := random.randi_range(1, total)
	for candidate in candidates:
		roll -= int(candidate["weight"])
		if roll <= 0:
			var selected_id := str(candidate["id"])
			current_event = {"id": selected_id, "data": definitions[selected_id]}
			return current_event
	return {}
```

Add `base_weight`, weather and facility modifiers to `data/events.json` without removing existing titles, choices or costs. Keep a deterministic fallback so old definitions remain selectable.

Wrap the existing choice-specific `match` in an atomic transaction. The wrapper must check `game.resources.can_afford(cost)` before spending, call the existing effect branch only after the spend succeeds, and leave `current_event` intact on any failure. On success append the choice to `key_choices`, clear `current_event` once, and return the effect lines.

Use this shape around the existing event-specific effects:

```gdscript
func resolve_choice(index: int, game) -> Array[String]:
	if current_event.is_empty() or index < 0:
		return []
	var choices: Array = current_event.get("data", {}).get("choices", [])
	if index >= choices.size():
		return []
	var cost: Dictionary = choices[index].get("cost", {})
	if not game.resources.can_afford(cost):
		return ["资源不足，无法执行该选择。"]
	if not game.resources.spend(cost):
		return ["资源扣除失败，选择未执行。"]
	var lines: Array[String] = _apply_choice_effect(index, game)
	if lines.is_empty():
		for key in cost:
			game.resources.add(str(key), int(cost[key]))
		return ["事件选择无效，资源已退回。"]
	current_event = {}
	return lines
```

- [ ] **Step 5: Remove the obsolete seven-day goal and verify no gathering modifier**

Remove `week_survivor` from the active goal pool in `data/survival_director.json`. In `SurvivalDirector.from_dict()`, ignore that goal ID while preserving its historical completion string. Add the context helper used by future callers:

```gdscript
func event_context(game) -> Dictionary:
	var built_ids: Array[String] = []
	for key in game.buildings.built:
		built_ids.append(str(key))
	return {
		"weather": str(game.weather),
		"threat": threat,
		"built_facilities": built_ids,
		"recent_actions": action_counts.duplicate(true)
	}
```

Replace the inline dictionary in `GameManager._resolve_night()` with `survival.event_context(self)` after this helper exists. Do not apply `weather_effect().gather_multiplier` in any reward path.

- [ ] **Step 6: Run focused tests and commit**

```powershell
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/event_flow_regression.gd --quit-after 10
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/strategy_smoke.gd --quit-after 10
git add scripts/game_manager.gd scripts/event_system.gd scripts/survival_director.gd data/events.json data/survival_director.json tests/event_flow_regression.gd
git commit -m "feat: connect exploration nights to weighted events"
```

Expected markers: `EVENT_FLOW_REGRESSION_OK` and `STRATEGY_SMOKE_OK`.

### Task 3: 统一设施清单和地图建造

**Files:**
- Modify: `scripts/building_system.gd`
- Modify: `scripts/build_mode_controller.gd`
- Modify: `scripts/construction_site.gd`
- Modify: `scripts/exploration_world.gd`
- Modify: `scripts/ui_controller.gd`
- Modify: `data/buildings.json`
- Create: `tests/unified_construction_regression.gd`

**Interfaces:**
- Produces `BuildingSystem.construction_catalog() -> Array[Dictionary]` returning all facilities regardless of old context fields.
- Produces `BuildingSystem.start_unified_project(building_id: String, position: Vector2, resources: ResourceManager, skill_level: int) -> Dictionary`.
- Produces `BuildingSystem.cancel_active_project(resources: ResourceManager) -> Dictionary`.
- Produces `BuildingSystem.active_construction() -> Dictionary`.
- Produces `BuildingSystem.advance_active_project(delta: float) -> bool`.
- Produces `ConstructionSite._complete_once() -> void` as the only completion/effect path.
- Keeps `start_project()` and `start_world_project()` as wrappers to the unified method for old tests.

- [ ] **Step 1: Write the failing construction test**

Create `tests/unified_construction_regression.gd`:

```gdscript
extends SceneTree

func _init() -> void:
	var game := GameManager.new()
	game.begin_morning()
	var all := game.construction_catalog()
	assert(all.size() >= 9)
	var first_id := "storage_shelf"
	assert(game.buildings.get_definition(first_id).size() > 0)
	var world := ExplorationWorld.new()
	root.add_child(world)
	world.setup(game)
	world.player.position = Vector2(500, 500)
	var start := game.buildings.start_unified_project(first_id, Vector2(500, 500), game.resources, game.construction_skill.level)
	assert(bool(start.get("ok", false)))
	var second := game.buildings.start_unified_project(first_id, Vector2(520, 500), game.resources, game.construction_skill.level)
	assert(not bool(second.get("ok", false)))
	var cancelled := game.buildings.cancel_active_project(game.resources)
	assert(bool(cancelled.get("ok", false)))
	assert(game.buildings.active_construction().is_empty())
	print("UNIFIED_CONSTRUCTION_REGRESSION_OK catalog=%d" % all.size())
	quit()
```

- [ ] **Step 2: Run the test and verify it fails**

```powershell
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/unified_construction_regression.gd --quit-after 10
```

Expected: FAIL because the current catalog is filtered by `context`, build mode cycles only `catalog("exploration")`, and `BuildingSystem` has no unified cancellation API.

- [ ] **Step 3: Make the building ledger context-neutral**

In `BuildingSystem`, use one `active_project` dictionary for every facility with `id`, `position`, `progress`, `required`, `cost`, and `duration`. Keep `placement`/`placement_zone` only for validation. Implement:

```gdscript
func construction_catalog() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key in definitions.keys():
		result.append(definitions[key].duplicate(true))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("id", "")) < str(b.get("id", "")))
	return result

func active_construction() -> Dictionary:
	return active_project.duplicate(true)

func advance_active_project(delta: float) -> bool:
	if active_project.is_empty():
		return false
	active_project["progress"] = minf(float(active_project.get("required", 1.0)), float(active_project.get("progress", 0.0)) + maxf(0.0, delta))
	if float(active_project["progress"]) < float(active_project.get("required", 1.0)):
		return false
	var completed_id := str(active_project.get("id", ""))
	active_project = {}
	complete(completed_id)
	return true

func cancel_active_project(resources: ResourceManager) -> Dictionary:
	if active_project.is_empty():
		return {"ok": false, "reason": "当前没有施工项目。"}
	var project := active_project.duplicate(true)
	var cost: Dictionary = project.get("cost", {})
	for key in cost:
		resources.add(str(key), int(cost[key]))
	active_project = {}
	world_projects = {}
	return {"ok": true, "reason": "已取消建造并返还材料。", "project": project}
```

Route `start_project()` and `start_world_project()` to `start_unified_project()` and reject a second project before spending resources. The canonical `required` value must be the skill-adjusted duration used by both the site and save data.

- [ ] **Step 4: Replace the category filter in build mode and UI**

Change `BuildModeController.cycle_blueprint()` to iterate `world.game.buildings.construction_catalog()`:

```gdscript
func cycle_blueprint() -> void:
	var choices: Array[String] = []
	for definition in world.game.buildings.construction_catalog():
		var id := str(definition.get("id", ""))
		if world.game.buildings.is_unlocked(id, world.game.construction_skill.level) and not world.game.buildings.has(id):
			choices.append(id)
	if choices.is_empty():
		return
	var index := choices.find(selected_blueprint)
	selected_blueprint = choices[(index + 1) % choices.size()]
```

Update the selection panel to show one list of facility cards with cost, duration, skill, and status. Do not display context tabs. Keep the existing green/red placement preview and legal collision checks. `B` is available only in `MORNING`; `E` confirms the selected map position; `Esc` cancels without charging.

- [ ] **Step 5: Keep ConstructionSite and saved progress on one duration**

When creating a `ConstructionSite`, pass the exact `required` value returned by `start_unified_project()`. In `_process()`, advance `BuildingSystem.active_project` and mirror its progress; do not maintain a second fallback timer:

```gdscript
func _process(delta: float) -> void:
	if completed or game == null or game.time.paused:
		return
	if not game.buildings.active_project.is_empty():
		game.buildings.advance_active_project(delta)
		var project: Dictionary = game.buildings.active_project
		progress = float(project.get("progress", progress))
	if progress >= build_time and game.buildings.has(blueprint_id):
		_complete_once()
```

`_complete_once()` calls the existing effect guard exactly once. Restoring the world must recreate the site from the same saved `required` and `progress` values.

- [ ] **Step 6: Run construction regressions and commit**

```powershell
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/unified_construction_regression.gd --quit-after 10
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/construction_unification_regression.gd --quit-after 10
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/build_mode_regression.gd --quit-after 10
git add scripts/building_system.gd scripts/build_mode_controller.gd scripts/construction_site.gd scripts/exploration_world.gd scripts/ui_controller.gd data/buildings.json tests/unified_construction_regression.gd
git commit -m "feat: unify facility construction flow"
```

Expected markers: `UNIFIED_CONSTRUCTION_REGRESSION_OK`, `CONSTRUCTION_UNIFICATION_REGRESSION_OK`, and `BUILD_MODE_REGRESSION_OK`.

### Task 4: 篝火燃料和温度规则

**Files:**
- Modify: `scripts/game_manager.gd`
- Modify: `scripts/campfire_point.gd`
- Modify: `scripts/fireplace_point.gd`
- Modify: `scripts/exploration_world.gd`
- Modify: `scripts/house_interior.gd`
- Modify: `data/survival_director.json`
- Create: `tests/campfire_fuel_regression.gd`

**Interfaces:**
- Produces `GameManager.fire_states: Dictionary` with `campfire` and `house_fireplace` entries.
- Produces `GameManager.fire_state(source_id: String) -> Dictionary`.
- Produces `GameManager._default_fire_states() -> Dictionary` for new games and migration defaults.
- Produces `GameManager.add_fire_fuel(source_id: String, wood: int = 1) -> Dictionary`.
- Produces `GameManager.tick_fire(delta: float) -> void`.
- Produces `GameManager.is_fire_active(source_id: String) -> bool`.
- Keeps `house_fire_lit` as a synchronized compatibility alias.

- [ ] **Step 1: Write the failing fuel test**

Create `tests/campfire_fuel_regression.gd`:

```gdscript
extends SceneTree

func _init() -> void:
	var game := GameManager.new()
	assert(not game.is_fire_active("campfire"))
	game.resources.amounts["wood"] = 0
	var no_wood := game.add_fire_fuel("campfire", 1)
	assert(not bool(no_wood.get("ok", false)))
	game.resources.add("wood", 2)
	var lit := game.add_fire_fuel("campfire", 1)
	assert(bool(lit.get("ok", false)))
	assert(game.is_fire_active("campfire"))
	var remaining := float(game.fire_state("campfire").get("fuel_remaining", 0.0))
	game.tick_fire(remaining + 0.1)
	assert(not game.is_fire_active("campfire"))
	print("CAMPFIRE_FUEL_REGRESSION_OK")
	quit()
```

- [ ] **Step 2: Run the test and verify it fails**

```powershell
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/campfire_fuel_regression.gd --quit-after 10
```

Expected: FAIL because the current campfire only consumes wood per interaction and does not store fuel or an active state.

- [ ] **Step 3: Add a shared fuel state**

Initialize both fire entries in `new_game()` and restore them in `from_dict()`:

```gdscript
var fire_states: Dictionary = {
	"campfire": {"lit": false, "fuel_remaining": 0.0, "fuel_capacity": 360.0, "fuel_per_wood": 120.0},
	"house_fireplace": {"lit": false, "fuel_remaining": 0.0, "fuel_capacity": 360.0, "fuel_per_wood": 120.0}
}

func add_fire_fuel(source_id: String, wood: int = 1) -> Dictionary:
	if wood <= 0 or not fire_states.has(source_id):
		return {"ok": false, "reason": "无法添加燃料。"}
	var state: Dictionary = fire_states[source_id]
	if not resources.can_afford({"wood": wood}):
		return {"ok": false, "reason": resources.missing_cost_text({"wood": wood})}
	var per_wood := maxf(0.1, float(state.get("fuel_per_wood", 120.0)))
	var available := maxf(0.0, float(state.get("fuel_capacity", 360.0)) - float(state.get("fuel_remaining", 0.0)))
	var accepted_wood := mini(wood, int(ceil(available / per_wood)))
	var added := minf(float(accepted_wood) * per_wood, available)
	if accepted_wood <= 0 or added <= 0.0:
		return {"ok": false, "reason": "燃料已经满了。"}
	resources.spend({"wood": accepted_wood})
	state["fuel_remaining"] = float(state.get("fuel_remaining", 0.0)) + added
	state["lit"] = true
	fire_states[source_id] = state
	house_fire_lit = bool(fire_states["house_fireplace"].get("lit", false))
	return {"ok": true, "reason": "火焰重新燃旺。", "state": state.duplicate(true)}

func is_fire_active(source_id: String) -> bool:
	var state: Dictionary = fire_states.get(source_id, {})
	return bool(state.get("lit", false)) and float(state.get("fuel_remaining", 0.0)) > 0.0
```

Use one configured duration per wood and one maximum capacity; keep the values in a data/config section rather than repeating them in point scripts.

- [ ] **Step 4: Make both fire points use the shared state**

Change `CampfirePoint.perform_interaction()` and `FireplacePoint.perform_interaction()` to call `game.add_fire_fuel()` and refresh their visual only when `is_fire_active()` is true:

```gdscript
func perform_interaction() -> Dictionary:
	var result: Dictionary = game.add_fire_fuel("campfire")
	if not bool(result.get("ok", false)):
		return {"ok": false, "message": str(result.get("reason", "无法添柴。")), "failed": true}
	queue_redraw()
	return {"ok": true, "message": "篝火重新燃旺。"}
```

Remove the permanent `lit` assumption and set `required_resources = {}` on both fire points so the shared `add_fire_fuel()` call is the only wood deduction. `FireplacePoint.can_interact()` must allow adding fuel while the fire is active but below capacity; its prompt changes from “already lit” to “add wood” in that state. `get_environment_temperature()` must add the outdoor or indoor fire bonus only after `is_fire_active()` succeeds. `tick_fire()` subtracts simulation seconds while the day is running and marks a state unlit at zero.

- [ ] **Step 5: Run temperature and facility tests**

```powershell
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/campfire_fuel_regression.gd --quit-after 10
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/temperature_food_regression.gd --quit-after 10
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/house_fire_map_smoke.gd --quit-after 10
```

Expected markers: `CAMPFIRE_FUEL_REGRESSION_OK`, `TEMPERATURE_FOOD_REGRESSION_OK`, and `HOUSE_FIRE_MAP_SMOKE_OK`.

- [ ] **Step 6: Commit fire behavior**

```powershell
git add scripts/game_manager.gd scripts/campfire_point.gd scripts/fireplace_point.gd scripts/exploration_world.gd scripts/house_interior.gd data/survival_director.json tests/campfire_fuel_regression.gd
git commit -m "feat: track campfire fuel and warmth state"
```

### Task 5: 资源原子性和天气采集冻结

**Files:**
- Modify: `scripts/resource_manager.gd`
- Modify: `scripts/interaction_point.gd`
- Modify: `scripts/fishing_spot.gd`
- Modify: `scripts/forage_spot.gd`
- Modify: `scripts/ruin_spot.gd`
- Modify: `scripts/task_system.gd`
- Modify: `scripts/survival_director.gd`
- Create: `tests/resource_atomic_weather_regression.gd`

**Interfaces:**
- Produces `ResourceManager.collect_rewards_atomic(rewards: Dictionary, source_id: String = "") -> Dictionary` returning `{ "ok": bool, "reason": String, "added": Dictionary }`.
- Keeps `can_collect_rewards()` as the preflight predicate used by every interaction.
- Produces `SurvivalDirector.gather_multiplier(weather: String) -> float`, returning `1.0` for this phase while retaining `weather_effect()` data compatibility.

- [ ] **Step 1: Write the failing atomicity and weather test**

Create `tests/resource_atomic_weather_regression.gd`:

```gdscript
extends SceneTree

func _init() -> void:
	var game := GameManager.new()
	var resources := game.resources
	resources.backpack_capacity = 1
	resources.backpack = {"wood": 0}
	resources.storage = {}
	resources.amounts["stone"] = 0
	resources.amounts["fiber"] = 0
	resources.amounts["wood"] = 0
	resources.add("wood", 0)
	var rewards := {"stone": 2, "fiber": 2}
	var before_wood := resources.get_amount("wood")
	var result := resources.collect_rewards_atomic(rewards, "test")
	assert(not bool(result.get("ok", false)))
	assert(resources.get_amount("wood") == before_wood)
	assert(resources.get_amount("stone") == 0)
	assert(resources.get_amount("fiber") == 0)
	var director := game.survival
	assert(is_equal_approx(director.gather_multiplier("晴朗"), 1.0))
	assert(is_equal_approx(director.gather_multiplier("浓雾"), 1.0))
	assert(is_equal_approx(director.gather_multiplier("暴雨"), 1.0))
	print("RESOURCE_ATOMIC_WEATHER_REGRESSION_OK")
	quit()
```

- [ ] **Step 2: Run the test and verify it fails**

```powershell
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/resource_atomic_weather_regression.gd --quit-after 10
```

Expected: FAIL because not every reward path uses the same capacity check and `gather_multiplier` currently remains available to callers as a non-1.0 value.

- [ ] **Step 3: Implement the atomic reward method**

In `ResourceManager`, preflight every reward key against backpack/storage capacity, then mutate only after the complete check succeeds:

```gdscript
func collect_rewards_atomic(rewards: Dictionary, source_id: String = "") -> Dictionary:
	if rewards.is_empty():
		return {"ok": true, "reason": "没有奖励。", "added": {}}
	if not can_collect_rewards(rewards):
		return {"ok": false, "reason": "携带空间不足，请先整理背包。", "added": {}}
	var added: Dictionary = {}
	for key in rewards:
		var id := str(key)
		var amount := int(rewards[key])
		if amount <= 0:
			continue
		collect_from_source(id, amount, source_id)
		added[id] = amount
	return {"ok": true, "reason": "奖励已领取。", "added": added}
```

Route `InteractionPoint._complete_interaction()`, fishing, forage, ruin and task resolution through this method. A failed interaction must not spend required resources, reduce uses, start cooldown, or append a success log.

- [ ] **Step 4: Freeze gathering at 1.0**

Add this explicit strategy API and use it from `TaskSystem` and any exploration reward calculation:

```gdscript
func gather_multiplier(_weather: String) -> float:
	return 1.0
```

Do not delete the JSON `gather_multiplier` fields; `weather_effect()` may still expose them for compatibility, but no current reward calculation may multiply by them.

- [ ] **Step 5: Run resource-chain and interaction regressions**

```powershell
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/resource_atomic_weather_regression.gd --quit-after 10
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/inventory_action_regression.gd --quit-after 10
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/resource_chain_smoke.gd --quit-after 10
```

Expected markers: `RESOURCE_ATOMIC_WEATHER_REGRESSION_OK`, `INVENTORY_ACTION_REGRESSION_OK`, and `RESOURCE_CHAIN_SMOKE_OK`.

- [ ] **Step 6: Commit resource behavior**

```powershell
git add scripts/resource_manager.gd scripts/interaction_point.gd scripts/fishing_spot.gd scripts/forage_spot.gd scripts/ruin_spot.gd scripts/task_system.gd scripts/survival_director.gd tests/resource_atomic_weather_regression.gd
git commit -m "fix: make rewards atomic and freeze gathering weather bonus"
```

### Task 6: HUD、事件报告和暂停输入

**Files:**
- Modify: `scripts/ui_controller.gd`
- Modify: `scripts/main.gd`
- Modify: `project.godot`
- Modify: `tests/hud_layout_regression.gd`
- Modify: `tests/hud_icon_regression.gd`
- Create: `tests/hud_interaction_overlay_regression.gd`

**Interfaces:**
- Produces `UIController.show_event(event: Dictionary) -> void`.
- Produces `UIController.show_report(lines: Array[String], terminal: bool = false) -> void`.
- Produces `UIController.close_overlay() -> bool` that respects the overlay stack.
- Produces `UIController._open_pause_overlay(kind: String) -> void` and `_close_pause_overlay(kind: String) -> void`.
- Keeps the existing HUD top chips, `SurvivorCard`, objective card and no-details-drawer layout.

- [ ] **Step 1: Write the failing HUD and pause test**

Create `tests/hud_interaction_overlay_regression.gd`:

```gdscript
extends SceneTree

func _init() -> void:
	var game := GameManager.new()
	var world := ExplorationWorld.new()
	root.add_child(world)
	world.setup(game)
	var ui := UIController.new()
	root.add_child(ui)
	ui.setup(game, world)
	var bar := ui.interaction_progress_bar
	assert(bar != null)
	assert(bar.size.x <= 180.0)
	ui._on_interaction_progress("搜寻废墟", 0.45)
	assert(bar.value == 0.45)
	assert(bar.get_parent().visible)
	var before := game.time.paused
	ui._open_pause_overlay("backpack")
	assert(game.time.paused)
	ui._close_pause_overlay("backpack")
	assert(game.time.paused == before)
	print("HUD_INTERACTION_OVERLAY_REGRESSION_OK")
	quit()
```

- [ ] **Step 2: Run the test and verify it fails**

```powershell
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/hud_interaction_overlay_regression.gd --quit-after 10
```

Expected: FAIL because `_on_interaction_progress()` currently hides its parent panel every time and the overlay pause behavior is not shared by every panel.

- [ ] **Step 3: Replace the central progress panel with a small bottom bar**

In `_build_hud()`, use integer logical geometry near the prompt panel:

```gdscript
var interaction_panel := _panel(Vector2(360, 407), Vector2(240, 18), PANEL_DARK, hud)
interaction_panel.name = "InteractionPanel"
interaction_name_label = _label(Vector2(6, 2), Vector2(92, 14), "", 3, TEXT_ACCENT, interaction_panel)
interaction_progress_bar = _progress_bar(Vector2(104, 6), Vector2(126, 6), interaction_panel)
interaction_progress_bar.max_value = 1.0
interaction_detail_label = null
interaction_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
interaction_panel.visible = false
```

Update `_on_interaction_progress()` to show the parent only for `0.0 < progress < 1.0` or a non-empty action name, and hide it on zero after completion/cancel. Keep the bar width at 126 design pixels and never center it over the map.

- [ ] **Step 4: Add event and report panels**

Create native `Panel`/`Button` controls using the existing pixel theme. `show_event()` fills two fixed choice buttons, disables unaffordable choices, and sets a modal input blocker. `show_report()` fills a scroll-free fixed text area and shows one “进入清晨” button. Event and report panels call `game.time.paused = true` through the overlay stack and do not clear `game.events.current_event` until the choice succeeds.

- [ ] **Step 5: Implement one overlay pause stack and InputMap actions**

Add `shortcut_help` (H) and `build_cycle` (Q) actions to `project.godot`. Change `main.gd` to use `event.is_action_pressed("build_mode")`, `event.is_action_pressed("backpack_toggle")`, `event.is_action_pressed("shortcut_help")`, and `event.is_action_pressed("build_cycle")`; retain physical-key fallback only inside the input adapter.

Use a set/dictionary of open overlay kinds rather than one boolean:

```gdscript
var _overlay_pause_depth := 0
var _overlay_pause_was_paused := false

func _open_pause_overlay(_kind: String) -> void:
	if _overlay_pause_depth == 0:
		_overlay_pause_was_paused = bool(game.time.paused)
		game.time.paused = true
	_overlay_pause_depth += 1

func _close_pause_overlay(_kind: String) -> void:
	_overlay_pause_depth = maxi(0, _overlay_pause_depth - 1)
	if _overlay_pause_depth == 0:
		game.time.paused = _overlay_pause_was_paused
```

Route backpack, storage, fish processing, crafting, build selection, shortcut, log, event and report open/close calls through these methods. The pause menu remains a separate top-level state.

- [ ] **Step 6: Run HUD regressions and commit**

```powershell
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/hud_interaction_overlay_regression.gd --quit-after 10
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/hud_layout_regression.gd --quit-after 10
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/hud_icon_regression.gd --quit-after 10
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/ui_detail_close.gd --quit-after 10
git add scripts/ui_controller.gd scripts/main.gd project.godot tests/hud_layout_regression.gd tests/hud_icon_regression.gd tests/hud_interaction_overlay_regression.gd
git commit -m "feat: add compact interaction and night report HUD"
```

Expected markers: `HUD_INTERACTION_OVERLAY_REGRESSION_OK`, `HUD_LAYOUT_OK`, `HUD_ICONS_OK`, and `UI_DETAIL_REMOVED_OK`.

### Task 7: 存档、读档和旧版本迁移

**Files:**
- Modify: `scripts/game_manager.gd`
- Modify: `scripts/event_system.gd`
- Modify: `scripts/building_system.gd`
- Modify: `scripts/survival_director.gd`
- Modify: `scripts/save_system.gd`
- Modify: `scripts/exploration_world.gd`
- Create: `tests/save_phase_regression.gd`

**Interfaces:**
- Produces `GameManager.SAVE_VERSION := 8`.
- Extends `GameManager.to_dict()` and `from_dict(data: Dictionary)` with phase, return-required, night context, fire states, event resolution and unified construction fields.
- Produces `SaveSystem.migrate(data: Dictionary) -> Dictionary` for versions 0 through 7.
- Keeps unknown fields ignored and old resource/building/water fields readable.

- [ ] **Step 1: Write the failing phase-save test**

Create `tests/save_phase_regression.gd`:

```gdscript
extends SceneTree

func _init() -> void:
	var game := GameManager.new()
	game.start_exploration()
	game.day_return_required = true
	var before := game.to_dict()
	assert(int(before.get("version", 0)) >= 8)
	assert(bool(before.get("day_return_required", false)))
	var restored := GameManager.new()
	restored.from_dict(before)
	assert(restored.phase == GameManager.PHASE_DAY)
	assert(restored.day_return_required)
	assert(not restored.night_settlement_applied)
	game.finish_exploration_day()
	var night_data := game.to_dict()
	var night_restored := GameManager.new()
	night_restored.from_dict(night_data)
	assert(night_restored.phase == game.phase)
	assert(night_restored.events.current_event.get("id", "") == game.events.current_event.get("id", ""))
	var old := {"version": 2, "day": 9, "resources": {"amounts": {"food": 2, "wood": 1, "medicine": 0, "water": 4}}}
	var migrated := GameManager.new()
	migrated.from_dict(old)
	assert(migrated.day == 9)
	assert(migrated.resources.get_amount("water") == 4)
	print("SAVE_PHASE_REGRESSION_OK version=%d" % int(night_data.get("version", 0)))
	quit()
```

- [ ] **Step 2: Run the test and verify it fails**

```powershell
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/save_phase_regression.gd --quit-after 10
```

Expected: FAIL because save output is version 7 and does not include the return-required flag, night context, or fire state.

- [ ] **Step 3: Add the versioned save fields**

Add these top-level fields to `GameManager.to_dict()`:

```gdscript
"version": SAVE_VERSION,
"day_return_required": day_return_required,
"night_settlement_applied": night_settlement_applied,
"night_context": night_context,
"fire_states": fire_states,
```

Include the complete unified construction project under `buildings.active_project`, including skill-adjusted `required` and exact `progress`. Keep `events.current_event`, report lines, RNG state, `TimeManager` state, world position and water resource fields.

- [ ] **Step 4: Restore phase without triggering side effects**

In `from_dict()`, migrate the raw dictionary before constructing systems. Restore the new fields directly:

```gdscript
var migrated := saves.migrate(data)
phase = str(migrated.get("phase", PHASE_MORNING))
day_return_required = bool(migrated.get("day_return_required", false))
night_settlement_applied = bool(migrated.get("night_settlement_applied", false))
night_context = migrated.get("night_context", {}) if migrated.get("night_context", {}) is Dictionary else {}
fire_states = migrated.get("fire_states", _default_fire_states())
```

Do not call `finish_exploration_day()`, `continue_from_report()`, `begin_morning()`, or any effect-application function during load. After world setup, call only `exploration_world.restore_state()` and `_restore_construction_sites()`.

- [ ] **Step 5: Implement migration rules**

In `SaveSystem.migrate()`:

```gdscript
func migrate(data: Dictionary) -> Dictionary:
	var result := data.duplicate(true)
	var version := int(result.get("version", 0))
	if version < 8:
		result["day_return_required"] = bool(result.get("day_return_required", false))
		result["night_settlement_applied"] = false
		result["night_context"] = {}
		result["fire_states"] = {}
		version = 8
	result["version"] = version
	return result
```

Then extend the migration body with these exact rules:

- Versions below 8 receive `day_return_required = false`, `night_settlement_applied = false`, an empty `night_context`, and unlit zero-fuel fire states.
- Missing `fire_states` is reconstructed from the legacy `house_fire_lit` flag without inventing fuel; legacy `house_fire_lit = true` becomes a lit state with the configured compatibility starting fuel and is logged as migrated.
- Legacy `active_project` and `world_projects` are normalized to one project; if both exist, keep `active_project` and return the other materials once through a migration log.
- `week_survivor` is removed from the active goal pool while any historical completion entry remains in `unlocked_milestones` or the log.
- Unknown resources, facilities, events and fields are ignored; recognized water fields remain intact.
- `ENDED` saves remain `ENDED` and never become ordinary play.

- [ ] **Step 6: Run save, interior and construction tests, then commit**

```powershell
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/save_phase_regression.gd --quit-after 10
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/interior_regression.gd --quit-after 10
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/construction_unification_regression.gd --quit-after 10
git add scripts/game_manager.gd scripts/event_system.gd scripts/building_system.gd scripts/survival_director.gd scripts/save_system.gd scripts/exploration_world.gd tests/save_phase_regression.gd
git commit -m "feat: persist endless loop phase and fire state"
```

Expected markers: `SAVE_PHASE_REGRESSION_OK`, `INTERIOR_REGRESSION_OK`, and `CONSTRUCTION_UNIFICATION_REGRESSION_OK`.

### Task 8: 全量回归、启动检查和视觉验收

**Files:**
- Create: `tools/run_regressions.ps1`
- Create: `tests/endless_acceptance_regression.gd`
- Modify: `README.md`

**Interfaces:**
- Produces a PowerShell runner that exits non-zero on the first failed Godot test.
- Produces `tests/endless_acceptance_regression.gd` with a deterministic multi-day, event, fire, save and death path.
- Documents the exact parser, regression and runtime commands in `README.md`.

- [ ] **Step 1: Write the deterministic long-run acceptance test**

Create `tests/endless_acceptance_regression.gd`:

```gdscript
extends SceneTree

func _init() -> void:
	var game := GameManager.new()
	for expected_day in range(1, 6):
		if game.phase == GameManager.PHASE_MORNING:
			game.start_exploration()
		game.day_return_required = true
		var night := game.finish_exploration_day()
		assert(bool(night.get("ok", false)) or game.phase == GameManager.PHASE_ENDED)
		if game.phase == GameManager.PHASE_EVENT:
			var choice := 0
			if not game.resources.can_afford(game.events.choice_cost(choice)):
				choice = 1
			if game.resources.can_afford(game.events.choice_cost(choice)):
				game.choose_event(choice)
		if game.phase == GameManager.PHASE_REPORT:
			game.continue_from_report()
		assert(game.day >= expected_day)
		assert(game.day < 100000)
	assert(not game.won)
	assert(game.phase != GameManager.PHASE_ENDED)
	print("ENDLESS_ACCEPTANCE_REGRESSION_OK day=%d" % game.day)
	quit()
```

- [ ] **Step 2: Add the full test runner**

Create `tools/run_regressions.ps1`:

```powershell
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$godotConsole = Join-Path $projectRoot ".tools\godot\Godot_v4.7.2-stable_win64_console.exe"
$tests = @(
    "tests/endless_day_flow_regression.gd",
    "tests/event_flow_regression.gd",
    "tests/unified_construction_regression.gd",
    "tests/campfire_fuel_regression.gd",
    "tests/resource_atomic_weather_regression.gd",
    "tests/hud_interaction_overlay_regression.gd",
    "tests/save_phase_regression.gd",
    "tests/endless_acceptance_regression.gd",
    "tests/smoke.gd",
    "tests/resource_chain_smoke.gd",
    "tests/inventory_action_regression.gd",
    "tests/strategy_smoke.gd",
    "tests/construction_unification_regression.gd",
    "tests/blueprint_effects_regression.gd",
    "tests/crafting_regression.gd",
    "tests/build_mode_regression.gd",
    "tests/facility_regression.gd",
    "tests/interior_regression.gd",
    "tests/house_fire_map_smoke.gd",
    "tests/temperature_food_regression.gd",
    "tests/time_manager_regression.gd",
    "tests/hud_layout_regression.gd",
    "tests/hud_icon_regression.gd",
    "tests/ui_detail_close.gd",
    "tests/map_art_regression.gd",
    "tests/ninja_adventure_art_smoke.gd",
    "tests/player_motion_regression.gd",
    "tests/new_features_regression.gd",
    "tests/tool_selection_regression.gd",
    "tests/workbench_regression.gd"
)

foreach ($test in $tests) {
    Write-Host ("RUN " + $test)
    & $godotConsole --headless --path $projectRoot --script ("res://" + $test) --quit-after 12
    if ($LASTEXITCODE -ne 0) {
        Write-Error ("FAILED " + $test + " exit=" + $LASTEXITCODE)
        exit $LASTEXITCODE
    }
}
Write-Host "ALL_TESTS_OK count=$($tests.Count)"
```

- [ ] **Step 3: Run parser and focused acceptance checks**

```powershell
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --editor --quit
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/endless_acceptance_regression.gd --quit-after 15
```

Expected: editor exits 0 and prints `ENDLESS_ACCEPTANCE_REGRESSION_OK`.

- [ ] **Step 4: Run the complete regression suite**

```powershell
.\tools\run_regressions.ps1
```

Expected: every listed test exits 0 and the final line is `ALL_TESTS_OK count=30`. Godot ObjectDB/resource-leak warnings may remain as warnings, but any parse error, assertion failure, non-zero exit or missing expected marker fails the task.

- [ ] **Step 5: Perform the manual runtime check**

Start exactly one game window:

```powershell
& ".\start_game.cmd"
```

Check in this order:

1. New game opens at the camp in `MORNING`; `B` shows one complete facility list.
2. Place one facility on a legal tile; invalid tiles are red, confirmation spends materials once, and a second project is blocked.
3. Start exploring; `E` interactions show the small bottom progress bar and pause correctly when a window opens.
4. Let the clock end in the field; time stops, the player can walk home, and no event appears before using the bed.
5. Use the bed; food, temperature, threat and fire settle once, then one event or a report appears.
6. Choose an event; an unaffordable choice is disabled, the result appears in the report, and `H` opens the matching shortcut list.
7. Save and load in `DAY`, `EVENT` and `REPORT`; the phase, event, report, fire and construction progress remain the same.
8. Burn the fire out; approaching it no longer grants warmth.
9. Repeat enough days to confirm there is no victory screen, date reset or seven-day branch.
10. Check at `960x540` and the configured fullscreen output that text, icons, panels and the small progress bar do not overlap.

- [ ] **Step 6: Update README and commit the acceptance tooling**

Add the parser, focused test, full runner and launch commands to `README.md`, then run the commands once more after the README edit. Commit only the runner, acceptance test and README change:

```powershell
git add tools/run_regressions.ps1 tests/endless_acceptance_regression.gd README.md
git commit -m "test: add endless survival acceptance runner"
```

## Final Review Checklist

- [ ] Re-read `docs/superpowers/specs/2026-09-04-endless-survival-loop-design.md` and map every requirement to at least one task above.
- [ ] Search this plan for unfinished markers and vague boundary-handling instructions; none may remain.
- [ ] Confirm all interfaces used by later tasks match the names and return shapes produced by earlier tasks.
- [ ] Confirm no task reintroduces weather-based gathering, water consumption, seven-day logic, multiple simultaneous projects or a second loop manager.
- [ ] Confirm final verification includes parser exit code, all 30 test scripts, the new long-run acceptance test, one-window runtime inspection, `960x540` inspection and fullscreen inspection.

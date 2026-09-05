# Ember Camp Modular Refactor Survival Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将日循环、温度、火源和夜间结算从 `GameManager` 的具体实现中拆出，同时保持唯一的流程入口和现有生存结果。

**Architecture:** 新增 `DayCycleService`、`TemperatureService`、`FireStateService` 和 `NightSettlementService`。这些服务接收显式状态/依赖字典并返回稳定结果；`GameManager` 继续持有状态、决定调用顺序并提供旧入口。

**Tech Stack:** Godot 4.7.2 GDScript、`TimeManager`、`SurvivalDirector`、`EventSystem`、现有 headless regression scripts。

**Spec:** `docs/superpowers/specs/2026-09-05-modular-refactor-design.md`

## Global Constraints

- 不改变清晨 -> 探索 -> 回床 -> 夜间结算 -> 事件/报告 -> 清晨的流程。
- 主角生命值归零仍是唯一主动退出以外的终局条件；不恢复第 7 天结束。
- 保持体温阈值、火源燃料、天气效果、事件权重和 RNG 消耗顺序。
- `GameManager.advance(delta)`、`finish_exploration_day()`、`_night_settlement()` 等旧入口继续可用。
- 不提高 `SAVE_VERSION`；火源、温度、阶段和报告的现有存档字段保持兼容。

---

### Task 1: Define Survival Service Tests

**Files:**
- Create: `tests/survival/survival_domain_regression.gd`
- Read: `scripts/game_manager.gd`, `scripts/time_manager.gd`, `tests/temperature_food_regression.gd`, `tests/endless_day_flow_regression.gd`, `tests/endless_acceptance_regression.gd`

**Interfaces:**
- Test targets: `DayCycleService`, `TemperatureService`, `FireStateService` and the later `NightSettlementService` signatures.

- [ ] **Step 1: Write the failing service test**

```gdscript
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
```

- [ ] **Step 2: Run the test and verify it fails**

```powershell
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/survival/survival_domain_regression.gd --quit-after 10
```

Expected: script load failure because the survival service files do not exist.

### Task 2: Extract Day, Temperature, and Fire Services

**Files:**
- Create: `scripts/domain/survival/day_cycle_service.gd`
- Create: `scripts/domain/survival/temperature_service.gd`
- Create: `scripts/domain/survival/fire_state_service.gd`

**Interfaces:**
- `DayCycleService.advance(clock: TimeManager, phase: String, delta: float) -> Dictionary` returns `elapsed_before`, `elapsed_after`, `ticks`, and `finished` without settling the day.
- `TemperatureService.environment_temperature(weather: String, in_house: bool, fire_states: Dictionary, building_effects: Dictionary) -> float`
- `TemperatureService.apply_damage(hero: Survivor, simulation_seconds: float, context: Dictionary) -> Dictionary`
- `TemperatureService.status(hero: Survivor, environment_temperature: float) -> Dictionary`
- `FireStateService.default_states() -> Dictionary`
- `FireStateService.add_fuel(states: Dictionary, source_id: String, wood: int, resources: Object, config: Dictionary) -> Dictionary`
- `FireStateService.tick(states: Dictionary, delta: float) -> Array[String]`
- `FireStateService.is_active(states: Dictionary, source_id: String) -> bool`
- `FireStateService.to_dict(states: Dictionary) -> Dictionary` and `from_dict(states: Dictionary, data: Dictionary) -> Dictionary`

- [ ] **Step 1: Move only pure calculations and state transitions**

Copy the current temperature constants, fire defaults, fuel decrement, active checks and damage threshold logic into the services. Keep existing numeric constants as constructor/config values so there is one source of truth. `DayCycleService` must call the existing `TimeManager.advance()` and report its result; it must not call `GameManager.finish_day()` or emit audio.

- [ ] **Step 2: Preserve failure and mutation ordering**

`add_fuel` checks wood availability through the injected resource object before changing fire state. `apply_damage` changes the hero only after the accumulated simulation seconds cross the existing interval. `from_dict` filters unknown fire keys exactly as the current save path does.

- [ ] **Step 3: Run the focused service test**

```powershell
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/survival/survival_domain_regression.gd --quit-after 10
```

Expected: `SURVIVAL_DOMAIN_REGRESSION_OK`.

- [ ] **Step 4: Commit the calculation slice**

```powershell
git add scripts/domain/survival/day_cycle_service.gd scripts/domain/survival/temperature_service.gd scripts/domain/survival/fire_state_service.gd tests/survival/survival_domain_regression.gd
git commit -m "refactor: extract survival time temperature and fire services"
```

### Task 3: Extract Night Settlement

**Files:**
- Create: `scripts/domain/survival/night_settlement_service.gd`
- Create: `tests/survival/night_settlement_regression.gd`
- Read: current `GameManager._resolve_night()` and `_night_settlement()` implementations

**Interfaces:**
- `NightSettlementService.resolve(context: Dictionary) -> Dictionary`
- Required context keys: `day`, `weather`, `resources`, `survivors`, `buildings`, `survival`, `events`, `rng`, `fire_states`, `house_level`, `in_house`, `report_lines`.
- Result keys: `report_lines`, `phase`, `event`, `health_depleted`, `night_context`, `audio_events`.

- [ ] **Step 1: Write the failing settlement test**

```gdscript
extends SceneTree

const NightSettlementService = preload("res://scripts/domain/survival/night_settlement_service.gd")

func _init() -> void:
    var game := GameManager.new()
    game.start_exploration()
    var service := NightSettlementService.new()
    var result := service.resolve({
        "day": game.day, "weather": game.weather, "resources": game.resources,
        "survivors": game.survivors, "buildings": game.buildings,
        "survival": game.survival, "events": game.events, "rng": game.rng,
        "fire_states": game.fire_states, "house_level": game.house_level,
        "in_house": game.in_house, "report_lines": []
    })
    assert(result.has("report_lines"))
    assert(result.has("phase"))
    print("NIGHT_SETTLEMENT_REGRESSION_OK")
    quit()
```

- [ ] **Step 2: Run the test and verify it fails**

```powershell
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/survival/night_settlement_regression.gd --quit-after 10
```

Expected: load failure because `NightSettlementService` does not exist.

- [ ] **Step 3: Move the common resolution body without changing side effects**

Move food, temperature, fire, survival-director settlement, event selection and report construction in the same order as the current `_resolve_night()` path. The service may mutate the injected domain objects, but it must not access `Main`, UI nodes or scene-tree paths. Return all audio event IDs as data; `GameManager` remains responsible for calling `AudioService` in the existing order.

- [ ] **Step 4: Run focused settlement and existing lifecycle tests**

```powershell
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/survival/night_settlement_regression.gd --quit-after 10
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/endless_day_flow_regression.gd --quit-after 10
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/temperature_food_regression.gd --quit-after 10
```

Expected: `NIGHT_SETTLEMENT_REGRESSION_OK` and unchanged lifecycle/temperature markers.

- [ ] **Step 5: Commit the settlement slice**

```powershell
git add scripts/domain/survival/night_settlement_service.gd tests/survival/night_settlement_regression.gd
git commit -m "refactor: extract night settlement service"
```

### Task 4: Route GameManager Through Survival Services

**Files:**
- Modify: `scripts/game_manager.gd`
- Create: `tests/survival/game_manager_survival_facade_regression.gd`
- Read: `tests/strategy_smoke.gd`, `tests/endless_acceptance_regression.gd`, `tests/campfire_fuel_regression.gd`

**Interfaces:**
- `GameManager` retains `advance(delta)`, `advance_exploration(delta)`, `finish_exploration_day()`, `start_day()`, `tick(delta)`, `finish_day()`, `force_finish_day()`, `_night_settlement()`, `fire_state()`, `add_fire_fuel()`, `tick_fire()`, `get_environment_temperature()`, `get_temperature_status()` and `check_protagonist_health()`.
- New service instances are private fields initialized in `new_game()` and receive only explicit dependencies.

- [ ] **Step 1: Write the failing facade equivalence test**

```gdscript
extends SceneTree

func _init() -> void:
    var game := GameManager.new()
    game.start_exploration()
    game.time.elapsed = TimeManager.DAY_SECONDS
    game.advance_exploration(0.1)
    assert(game.day_return_required)
    var first := game.finish_exploration_day()
    assert(bool(first.get("ok", false)))
    assert(game.phase in [GameManager.PHASE_EVENT, GameManager.PHASE_REPORT, GameManager.PHASE_ENDED])
    var second := game.finish_exploration_day()
    assert(not bool(second.get("ok", false)))
    print("GAME_MANAGER_SURVIVAL_FACADE_REGRESSION_OK")
    quit()
```

- [ ] **Step 2: Delegate in small method groups**

Add service construction, then replace fire methods, temperature methods, day advancement and night resolution one group at a time. Keep compatibility constants as aliases to the service configuration. Do not rename `GameManager` or move its script path in this task. Preserve `check_protagonist_health()` as the single terminal-state entry and keep audio emission in the facade.

- [ ] **Step 3: Run focused and existing tests**

```powershell
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/survival/game_manager_survival_facade_regression.gd --quit-after 10
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/strategy_smoke.gd --quit-after 10
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/endless_acceptance_regression.gd --quit-after 15
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/campfire_fuel_regression.gd --quit-after 10
```

Expected: the new marker plus unchanged strategy, endless-loop and fire markers.

- [ ] **Step 4: Commit the compatibility migration**

```powershell
git add scripts/game_manager.gd tests/survival/game_manager_survival_facade_regression.gd
git commit -m "refactor: route game manager through survival services"
```

### Task 5: Survival Gate

**Files:**
- Read: all files changed by Tasks 1-4

**Interfaces:**
- Produces: a `GameManager` facade with unchanged lifecycle, temperature, fire, event and terminal-state behavior.

- [ ] **Step 1: Run editor parsing and the architecture checker**

```powershell
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --editor --quit
.\tools\check_architecture.ps1 -Root .
```

- [ ] **Step 2: Run all survival-focused regressions**

```powershell
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/endless_day_flow_regression.gd --quit-after 10
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/event_flow_regression.gd --quit-after 10
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/temperature_food_regression.gd --quit-after 10
```

- [ ] **Step 3: Inspect and commit only intended files**

```powershell
git diff --check
git status --short --branch
```

Do not stage concurrent audio assets or unrelated artifacts.

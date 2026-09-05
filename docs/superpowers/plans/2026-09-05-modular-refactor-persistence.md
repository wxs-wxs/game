# Ember Camp Modular Refactor Persistence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让存档文件读写与领域状态序列化解耦，并在最后统一接入输入路由、回归 runner、文档和完整运行时验收。

**Architecture:** `SaveSystem` 只处理文件和既有迁移规则；`SaveCoordinator` 接收一组有 `to_dict/from_dict` 的领域片段，负责组装/恢复而不改变现有顶层存档语义。最后一个集成切片才修改受保护的 `main.gd`、runner 和 README，并删除已经没有调用者的兼容代码。

**Tech Stack:** Godot 4.7.2 GDScript、JSON、PowerShell、现有 headless regression scripts 和兼容渲染检查。

**Spec:** `docs/superpowers/specs/2026-09-05-modular-refactor-design.md`

## Global Constraints

- `SAVE_VERSION` 保持当前值；现有顶层字段、旧存档迁移和未知字段保留策略不变。
- `SaveSystem` 不获得资源、世界、UI 或玩法规则。
- `SaveCoordinator` 不访问场景树，不写 `user://`，不吞掉模块恢复错误。
- 只有集成任务可以修改 `scripts/main.gd`、回归 runner、README 和项目设置。
- 不纳入当前 worktree 中已有的音频资源和音频脚本变更。

---

### Task 1: Capture the Existing Save Shape

**Files:**
- Create: `tests/persistence/save_shape_regression.gd`
- Read: `scripts/game_manager.gd`, `scripts/save_system.gd`, `tests/save_phase_regression.gd`, `tests/audio_save_regression.gd`, `tests/construction_unification_regression.gd`

**Interfaces:**
- Produces: a characterization assertion of `GameManager.to_dict()`, `GameManager.from_dict()`, `SaveSystem.migrate()` and current save version.

- [ ] **Step 1: Write the characterization test**

```gdscript
extends SceneTree

func _init() -> void:
    var game := GameManager.new()
    var state := game.to_dict()
    assert(int(state.get("version", -1)) == GameManager.SAVE_VERSION)
    assert(state.has("resources"))
    assert(state.has("survival"))
    assert(state.has("buildings"))
    var restored := GameManager.new()
    restored.from_dict(state)
    assert(restored.to_dict() == state)
    var migrated := SaveSystem.new().migrate({"version": 0, "resources": {}, "survival": {}})
    assert(int(migrated.get("version", -1)) == GameManager.SAVE_VERSION)
    print("SAVE_SHAPE_REGRESSION_OK")
    quit()
```

- [ ] **Step 2: Run the characterization test**

```powershell
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/persistence/save_shape_regression.gd --quit-after 10
```

Record the actual top-level keys; they are the compatibility target for the coordinator.

### Task 2: Implement SaveCoordinator

**Files:**
- Create: `scripts/infrastructure/persistence/save_coordinator.gd`
- Create: `tests/persistence/save_coordinator_regression.gd`

**Interfaces:**
- `SaveCoordinator.register_fragment(id: String, owner: Object, save_key: String) -> void`
- `SaveCoordinator.collect() -> Dictionary`
- `SaveCoordinator.restore(data: Dictionary) -> Dictionary`
- `SaveCoordinator.clear() -> void`

- [ ] **Step 1: Write the failing coordinator test**

```gdscript
extends SceneTree

const SaveCoordinator = preload("res://scripts/infrastructure/persistence/save_coordinator.gd")

class FakeFragment:
    var value := 1
    func to_dict() -> Dictionary: return {"value": value}
    func from_dict(data: Dictionary) -> void: value = int(data.get("value", 0))

func _init() -> void:
    var fragment := FakeFragment.new()
    var coordinator := SaveCoordinator.new()
    coordinator.register_fragment("fake", fragment, "resources")
    var saved := coordinator.collect()
    assert(saved == {"resources": {"value": 1}})
    fragment.value = 9
    var restored := coordinator.restore(saved)
    assert(bool(restored.get("ok", false)))
    assert(fragment.value == 1)
    print("SAVE_COORDINATOR_REGRESSION_OK")
    quit()
```

- [ ] **Step 2: Run the test and verify it fails**

```powershell
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/persistence/save_coordinator_regression.gd --quit-after 10
```

Expected: load failure because `SaveCoordinator` does not exist.

- [ ] **Step 3: Implement explicit fragment registration**

Store `{id, owner, save_key}` records. `collect()` calls each owner’s `to_dict()` and writes to the existing save key. Reject duplicate IDs or save keys with a failure result. `restore()` calls `from_dict()` only when the save key exists, returns a result with missing-key diagnostics, and does not erase unknown top-level keys. Do not add `version` handling here; `SaveSystem.migrate()` remains the only migration entry.

- [ ] **Step 4: Run the focused coordinator test**

```powershell
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/persistence/save_coordinator_regression.gd --quit-after 10
```

Expected: `SAVE_COORDINATOR_REGRESSION_OK`.

- [ ] **Step 5: Commit the coordinator slice**

```powershell
git add scripts/infrastructure/persistence/save_coordinator.gd tests/persistence/save_coordinator_regression.gd
git commit -m "refactor: add save fragment coordinator"
```

### Task 3: Route GameManager Serialization Through the Coordinator

**Files:**
- Modify: `scripts/game_manager.gd`
- Create: `tests/persistence/game_manager_save_facade_regression.gd`
- Read: `scripts/resource_manager.gd`, `scripts/building_system.gd`, `scripts/event_system.gd`, `scripts/survival_director.gd`, `scripts/task_system.gd`

**Interfaces:**
- `GameManager.to_dict() -> Dictionary` and `from_dict(data: Dictionary) -> void` retain their current signatures and top-level output.
- `GameManager` registers resource, survival, construction, event and task fragments with `SaveCoordinator` during `new_game()`; the world fragment is registered later by `attach_world(world: Object)` after `ExplorationWorld.setup(game)`.
- `GameManager.attach_world(world: Object) -> void` registers the world serializer when a world node is available and remains a no-op-safe compatibility method for headless tests.

- [ ] **Step 1: Write the failing round-trip test**

```gdscript
extends SceneTree

func _init() -> void:
    var game := GameManager.new()
    game.resources.backpack["wood"] = 2
    game.day = 4
    game.phase = GameManager.PHASE_DAY
    var saved := game.to_dict()
    var restored := GameManager.new()
    restored.from_dict(saved)
    assert(restored.day == 4)
    assert(restored.phase == GameManager.PHASE_DAY)
    assert(restored.resources.backpack.get("wood", 0) == 2)
    assert(restored.to_dict() == saved)
    print("GAME_MANAGER_SAVE_FACADE_REGRESSION_OK")
    quit()
```

- [ ] **Step 2: Delegate fragment serialization without changing the outer shape**

Keep session-only fields (`day`, `phase`, `weather`, `in_house`, terminal flags, report and log) in the GameManager session fragment. Register existing systems using their current `to_dict/from_dict` methods. `GameManager.to_dict()` merges coordinator output with session fields and preserves unknown top-level keys exactly as before. `from_dict()` calls `SaveSystem.migrate()` before restoring fragments and keeps legacy compatibility handling in the existing owner.

- [ ] **Step 3: Run save and phase regressions**

```powershell
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/persistence/game_manager_save_facade_regression.gd --quit-after 10
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/save_phase_regression.gd --quit-after 10
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/construction_unification_regression.gd --quit-after 10
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/audio_save_regression.gd --quit-after 10
```

Expected: the new marker and all existing save markers, with the current `SAVE_VERSION` unchanged.

- [ ] **Step 4: Commit the GameManager serialization slice**

```powershell
git add scripts/game_manager.gd tests/persistence/game_manager_save_facade_regression.gd
git commit -m "refactor: route game state serialization through coordinator"
```

### Task 4: Wire InputRouter and Finish the Protected Integration

**Files:**
- Modify: `scripts/main.gd`
- Modify: `tools/run_regressions.ps1`
- Modify: `README.md`
- Create: `tests/persistence/modular_refactor_integration_regression.gd`
- Read: `scripts/presentation/input/input_router.gd`, all earlier subplan outputs

**Interfaces:**
- `Main._input(event)` calls `InputRouter.route(event, state)` and dispatches the returned intent to the existing UI/world/game entry.
- Existing keyboard behavior remains: Space/Escape pause, K backpack, H shortcut help, B build, Q cycle, F5 save, F9 load, U upgrade, P policy, E interact, and Escape cancel.

- [ ] **Step 1: Write the failing integration test**

Instantiate `Main`, send synthetic `InputEventKey` events for K, B, F5 and Escape, and assert that the same UI/game state transitions occur as before. Assert that `main.gd` contains no direct resource or phase mutation after routing.

- [ ] **Step 2: Replace the input decision tree with router dispatch**

Keep the existing early-close and build-cancel precedence. `Main` supplies only `{overlay_open, build_active, paused}` to the router and handles the returned `kind` by calling the already-available UI facade methods. Do not modify `UIController` in this task; its `dispatch_intent(intent)` entry is provided by the presentation plan. Do not move gameplay rules into the router. Keep `Main._process()` as the only call to `game.advance(delta)` and the existing UI refresh cadence.

- [ ] **Step 3: Add new persistence tests to the runner without reordering existing tests**

Append `tests/persistence/save_shape_regression.gd`, `tests/persistence/save_coordinator_regression.gd`, `tests/persistence/game_manager_save_facade_regression.gd` and `tests/persistence/modular_refactor_integration_regression.gd` to the existing fail-fast runner. Preserve the runner’s current explicit exit-code and `SCRIPT ERROR` checks.

- [ ] **Step 4: Update README and ownership documentation**

Document the new `scripts/core`, `scripts/domain`, `scripts/world`, `scripts/presentation` and `scripts/infrastructure/persistence` responsibilities, the vertical worktree ownership template, the architecture checker command and the unchanged full regression commands. Do not claim test counts until the runner output has been captured.

- [ ] **Step 5: Run the focused integration test**

```powershell
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/persistence/modular_refactor_integration_regression.gd --quit-after 15
```

- [ ] **Step 6: Commit the protected integration slice**

```powershell
git add scripts/main.gd tools/run_regressions.ps1 README.md tests/persistence/modular_refactor_integration_regression.gd
git commit -m "refactor: integrate modular input and persistence boundaries"
```

### Task 5: Remove Only Proven-Dead Compatibility Code

**Files:**
- Modify: `scripts/game_manager.gd`
- Modify: `scripts/resource_manager.gd`
- Modify: `scripts/exploration_world.gd`
- Modify: `scripts/ui_controller.gd`
- Read: all scripts, tests and docs

**Interfaces:**
- Produces: no deleted method or field remains referenced by scripts, tests, scenes, data or README.

- [ ] **Step 1: Search all legacy entry points**

```powershell
rg -n "(deprecated|compatibility|legacy|toggle_backpack|finish_exploration_day|play_music|play_ambience|play_sfx)" scripts tests scenes README.md docs
```

- [ ] **Step 2: Delete only entries with zero references**

Remove a compatibility method only when the search is clean and its replacement contract test passes. Keep explicit legacy-save migration assertions and any public method still used by existing tests.

- [ ] **Step 3: Run parser, checker and full regression**

```powershell
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --editor --quit
.\tools\check_architecture.ps1 -Root .
.\tools\run_regressions.ps1
.\tools\run_audio_regressions.ps1
```

- [ ] **Step 4: Commit cleanup separately**

```powershell
git add scripts/game_manager.gd scripts/resource_manager.gd scripts/exploration_world.gd scripts/ui_controller.gd
git commit -m "refactor: remove proven-dead modular compatibility paths"
```

### Task 6: Final Runtime and Merge Exercise

**Files:**
- Create: `docs/superpowers/verification/2026-09-05-modular-refactor.md`
- Read: all subplan verification outputs and `docs/architecture/worktree-ownership.md`

**Interfaces:**
- Produces: a reproducible verification record and a demonstrated cross-directory feature merge procedure.

- [ ] **Step 1: Run the complete verification sequence**

```powershell
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --editor --quit
.\tools\check_architecture.ps1 -Root .
.\tools\run_regressions.ps1
.\tools\run_audio_regressions.ps1
```

- [ ] **Step 2: Perform the runtime state checklist**

Launch with `C:\projects\game\start_game.cmd` and inspect normal exploration, pause, backpack, storage, fish processing, crafting, build selection, facility placement, indoor bed/fire, night report, event choice, save/load and health-zero game-over at both 960x540 logical size and 1920x1080 integer output.

- [ ] **Step 3: Perform a merge exercise**

Create two temporary branches from the same integration commit. Branch A adds a cross-directory “fish processing” module and its tests; Branch B adds a “temperature warning” module and its tests. Merge both without editing each other’s internals, then record the touched files, conflict count and any protected-file adapter changes. Remove the temporary branches only after recording the result; do not delete user branches.

- [ ] **Step 4: Record evidence and commit the verification note**

Record exact commands, exit codes, runner markers, screenshot paths, merge exercise results, known ObjectDB/resource-leak warnings and any residual risk. Run `git diff --check` and `git status --short --branch`; stage only this verification note.

```powershell
git add docs/superpowers/verification/2026-09-05-modular-refactor.md
git commit -m "test: record modular refactor verification"
```

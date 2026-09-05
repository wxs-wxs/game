# Ember Camp Modular Refactor Presentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 `UIController` 的常驻 HUD、窗口、控件工厂和输入意图分开，保持现有 HUD 布局、像素资源、快捷键和公开 UI 方法。

**Architecture:** 子视图控制器只拥有自己的控件并消费 `Dictionary` 快照；用户操作通过 `intent_requested` 信号交给 `UIController`。`UIController` 仍是兼容门面和组装器，负责把当前 `GameManager`/`ExplorationWorld` 状态整理成快照。输入路由先独立测试，最终由集成阶段接入 `Main`。

**Tech Stack:** Godot 4.7.2 GDScript、CanvasLayer/Control、现有 `PixelTheme`、Fusion Pixel 字体、Kenney Pixel UI、headless regression scripts。

**Spec:** `docs/superpowers/specs/2026-09-05-modular-refactor-design.md`

## Global Constraints

- 不改变 960x540 HUD 坐标、控件位置/尺寸、快捷键、暂停深度和窗口行为。
- 所有新控件继续使用现有像素主题、最近邻纹理、整数几何和 Fusion Pixel 字体。
- 子视图不得直接引用 `GameManager`、`ExplorationWorld` 或修改资源/阶段字段。
- 旧方法 `toggle_backpack()`、`close_overlay()`、`show_event()`、`show_report()` 等继续可用。
- 不引入 Web UI 或第二套 UI 框架。

---

### Task 1: Capture UI Geometry and Interaction Behavior

**Files:**
- Create: `tests/presentation/ui_facade_regression.gd`
- Read: `scripts/ui_controller.gd`, `tests/hud_layout_regression.gd`, `tests/hud_icon_regression.gd`, `tests/hud_interaction_overlay_regression.gd`, `tests/ui_detail_close.gd`

**Interfaces:**
- Produces: characterization checks for root scale, key panel rectangles, overlay pause depth, icon textures, and existing public UI methods.

- [ ] **Step 1: Write the characterization test**

```gdscript
extends SceneTree

func _init() -> void:
    var main := load("res://scenes/Main.tscn").instantiate()
    root.add_child(main)
    await process_frame
    var ui: UIController = main.ui
    assert(ui.hud.scale == Vector2.ONE)
    assert(ui.backpack_panel != null)
    assert(ui.storage_panel != null)
    assert(ui.shortcut_panel != null)
    ui.toggle_backpack()
    assert(ui.close_overlay())
    print("UI_FACADE_REGRESSION_OK")
    quit()
```

- [ ] **Step 2: Run existing UI tests and record geometry**

```powershell
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/hud_layout_regression.gd --quit-after 10
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/hud_icon_regression.gd --quit-after 10
```

Use the current marker output as the expected values for later tasks; do not redesign layout during extraction.

### Task 2: Extract the Pixel UI Factory

**Files:**
- Create: `scripts/presentation/theme/ui_factory.gd`
- Create: `tests/presentation/ui_factory_regression.gd`
- Read: `scripts/pixel_ui_theme.gd` and the helper methods at the end of `scripts/ui_controller.gd`

**Interfaces:**
- `UiFactory.setup(theme: Theme) -> void`
- `UiFactory.label(parent: Control, position: Vector2, size: Vector2, text: String, font_size: int, color: Color) -> Label`
- `UiFactory.button(parent: Control, position: Vector2, size: Vector2, text: String) -> Button`
- `UiFactory.panel(parent: Control, position: Vector2, size: Vector2, color: Color) -> Panel`
- `UiFactory.icon(parent: Control, position: Vector2, size: Vector2, texture: Texture2D) -> TextureRect`
- `UiFactory.progress_bar(parent: Control, position: Vector2, size: Vector2, tint: Color) -> ProgressBar`

When `setup` receives `null`, the factory must use `PixelUITheme.create_theme()`; this keeps headless tests and runtime construction on the same theme path.

- [ ] **Step 1: Write the failing factory test**

```gdscript
extends SceneTree

const UiFactory = preload("res://scripts/presentation/theme/ui_factory.gd")

func _init() -> void:
    var host := Control.new()
    root.add_child(host)
    var factory := UiFactory.new()
    factory.setup(null)
    var panel := factory.panel(host, Vector2(12, 12), Vector2(120, 30), Color.WHITE)
    var label := factory.label(host, Vector2(15, 15), Vector2(80, 12), "测试", 10, Color.WHITE)
    assert(panel.position == Vector2(12, 12))
    assert(panel.size == Vector2(120, 30))
    assert(panel.scale == Vector2.ONE)
    assert(label.position == Vector2(15, 15))
    print("UI_FACTORY_REGRESSION_OK")
    quit()
```

- [ ] **Step 2: Move helper implementations without changing style values**

Copy `_label`, `_button`, `_panel`, `_icon`, `_progress_bar`, `_bar_style`, `_button_style`, `_set_progress_fill`, `_add_button_icon` and font configuration into `UiFactory`. Keep `PixelTheme` as the style/asset source. `UIController` temporarily forwards its helper methods to the factory so other code does not change.

- [ ] **Step 3: Run factory and HUD tests**

```powershell
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/presentation/ui_factory_regression.gd --quit-after 10
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/hud_layout_regression.gd --quit-after 10
```

- [ ] **Step 4: Commit the factory slice**

```powershell
git add scripts/presentation/theme/ui_factory.gd scripts/ui_controller.gd tests/presentation/ui_factory_regression.gd
git commit -m "refactor: extract pixel ui factory"
```

### Task 3: Extract HUD and Information Panels

**Files:**
- Create: `scripts/presentation/hud/hud_view.gd`
- Create: `tests/presentation/hud_view_regression.gd`
- Modify: `scripts/ui_controller.gd`

**Interfaces:**
- `HudView.setup(parent: Control, factory: Object) -> void`
- `HudView.refresh(snapshot: Dictionary) -> void`
- `HudView.required_snapshot_keys() -> Array[String]`
- Snapshot keys: `day`, `clock`, `weather`, `temperature`, `resources`, `survivor`, `objective`, `log`, `interaction`.

`HudView.setup` must create a default `UiFactory` when its `factory` argument is `null`, so the view contract is usable in an isolated headless test.

- [ ] **Step 1: Write the failing HUD view test**

```gdscript
extends SceneTree

const HudView = preload("res://scripts/presentation/hud/hud_view.gd")

func _init() -> void:
    var host := Control.new()
    root.add_child(host)
    var view := HudView.new()
    view.setup(host, null)
    view.refresh({
        "day": 1, "clock": "清晨", "weather": "晴朗", "temperature": 16.0,
        "resources": {}, "survivor": {}, "objective": {}, "log": [], "interaction": {}
    })
    assert(view.required_snapshot_keys().size() == 9)
    print("HUD_VIEW_REGRESSION_OK")
    quit()
```

- [ ] **Step 2: Move only persistent HUD construction and refresh**

Move top status chips, resource badges, survivor card, objective card, interaction prompt/progress and log summary into `HudView`. Do not move backpack, storage, crafting, build, pause, event or report controls in this task. Preserve every current position, size, color, font size, icon texture and tooltip.

- [ ] **Step 3: Route UIController refresh through one snapshot**

Add a private `_build_ui_snapshot()` in `UIController` that reads current state once and passes a deep copy to `HudView.refresh()`. Keep existing labels as compatibility references only while tests still access them.

- [ ] **Step 4: Run HUD and interaction overlay tests**

```powershell
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/presentation/hud_view_regression.gd --quit-after 10
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/hud_layout_regression.gd --quit-after 10
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/hud_resource_tooltip_regression.gd --quit-after 10
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/hud_interaction_overlay_regression.gd --quit-after 10
```

- [ ] **Step 5: Commit the HUD slice**

```powershell
git add scripts/presentation/hud/hud_view.gd scripts/ui_controller.gd tests/presentation/hud_view_regression.gd
git commit -m "refactor: extract persistent hud view"
```

### Task 4: Extract Overlay Controllers

**Files:**
- Create: `scripts/presentation/overlays/backpack_view.gd`
- Create: `scripts/presentation/overlays/storage_view.gd`
- Create: `scripts/presentation/overlays/crafting_view.gd`
- Create: `scripts/presentation/overlays/build_view.gd`
- Create: `scripts/presentation/overlays/event_report_view.gd`
- Create: `scripts/presentation/overlays/pause_overlay.gd`
- Create: `tests/presentation/overlay_contract_regression.gd`
- Modify: `scripts/ui_controller.gd`

**Interfaces:**
- Each view exposes `setup(parent: Control, factory: Object, callbacks: Dictionary) -> void`, `open(snapshot: Dictionary) -> void`, `refresh(snapshot: Dictionary) -> void`, `close() -> void`, and `is_open() -> bool`.
- Each view emits `signal intent_requested(intent: Dictionary)` and `signal close_requested`.
- Intent examples: `{ "kind": "use_item", "key": "fish_carp" }`, `{ "kind": "storage_move", "source": "backpack", "key": "wood" }`, `{ "kind": "choose_event", "index": 0 }`.
- `UIController.dispatch_intent(intent: Dictionary) -> void` is the single facade entry for child-view intents; it keeps the existing public action methods behind that entry.

Each view must use the same null-factory fallback as `HudView` and must treat an empty callback dictionary as a valid headless configuration.

- [ ] **Step 1: Write the overlay contract test**

```gdscript
extends SceneTree

const BackpackView = preload("res://scripts/presentation/overlays/backpack_view.gd")

func _init() -> void:
    var host := Control.new()
    root.add_child(host)
    var view := BackpackView.new()
    var intents: Array[Dictionary] = []
    view.intent_requested.connect(func(value: Dictionary): intents.append(value))
    view.setup(host, null, {})
    view.open({"items": [], "capacity": 12})
    assert(view.is_open())
    view.refresh({"items": [], "capacity": 12})
    view.close()
    assert(not view.is_open())
    print("OVERLAY_CONTRACT_REGRESSION_OK")
    quit()
```

Run the same lifecycle assertions for the storage, crafting, build, event/report and pause view classes, and trigger one button in each view to verify that only `intent_requested` is emitted.

- [ ] **Step 2: Extract one overlay at a time**

Move the existing build/refresh/input code in this order: backpack, storage, crafting, build selection/facility, event/report, pause. The parent view owns only its controls and local state. Preserve overlay pause depth, nested context menus, drag/drop payload shape, focus, disabled states and close behavior.

- [ ] **Step 3: Wire intents in UIController**

Connect every child signal once in `setup()`. UIController translates intents to the existing `GameManager`/`ExplorationWorld` calls and sends the returned message back as the next snapshot. No child receives a `GameManager` reference.

- [ ] **Step 4: Run all overlay regressions**

```powershell
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/presentation/overlay_contract_regression.gd --quit-after 10
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/backpack_redesign_regression.gd --quit-after 10
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/storage_drag_regression.gd --quit-after 10
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/build_mode_regression.gd --quit-after 10
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/event_flow_regression.gd --quit-after 10
```

- [ ] **Step 5: Commit the overlay slice**

```powershell
git add scripts/presentation/overlays scripts/ui_controller.gd tests/presentation/overlay_contract_regression.gd
git commit -m "refactor: extract hud overlay controllers"
```

### Task 5: Add an Input Intent Router

**Files:**
- Create: `scripts/presentation/input/input_router.gd`
- Create: `tests/presentation/input_router_regression.gd`
- Read: `scripts/main.gd`

**Interfaces:**
- `InputRouter.route(event: InputEvent, state: Dictionary) -> Dictionary`
- Result keys: `kind`, `handled`, and optional `action`/`payload`.
- Supported kinds: `pause`, `backpack`, `shortcut_help`, `build_mode`, `build_cycle`, `save`, `load`, `upgrade`, `policy`, `cancel`, `interact`.

- [ ] **Step 1: Write the failing input test**

```gdscript
extends SceneTree

const InputRouter = preload("res://scripts/presentation/input/input_router.gd")

func _init() -> void:
    var router := InputRouter.new()
    var event := InputEventKey.new()
    event.keycode = KEY_K
    event.pressed = true
    var result := router.route(event, {"overlay_open": false, "build_active": false})
    assert(result.get("kind", "") == "backpack")
    assert(bool(result.get("handled", false)))
    print("INPUT_ROUTER_REGRESSION_OK")
    quit()
```

- [ ] **Step 2: Implement mapping with the current fallback keys**

Preserve `InputMap` actions and direct-key fallbacks from `main.gd`. `route` must not call UI or game methods; it only translates an input event and current overlay/build state into an intent result.

- [ ] **Step 3: Run the router test**

```powershell
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/presentation/input_router_regression.gd --quit-after 10
```

- [ ] **Step 4: Commit the router slice**

```powershell
git add scripts/presentation/input/input_router.gd tests/presentation/input_router_regression.gd
git commit -m "refactor: add input intent router"
```

### Task 6: Presentation Gate

**Files:**
- Read: all files changed by Tasks 1-5

**Interfaces:**
- Produces: a `UIController` facade that owns composition and compatibility methods while child views consume snapshots and emit intents.

- [ ] **Step 1: Run parser and architecture checks**

```powershell
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --editor --quit
.\tools\check_architecture.ps1 -Root .
```

- [ ] **Step 2: Run all documented HUD and overlay checks**

Run `hud_layout_regression.gd`, `hud_icon_regression.gd`, `hud_resource_tooltip_regression.gd`, `hud_interaction_overlay_regression.gd`, `backpack_redesign_regression.gd`, `storage_drag_regression.gd`, `build_mode_regression.gd`, `tool_selection_regression.gd`, `ui_detail_close.gd`, and `event_flow_regression.gd`, then inspect compatibility-rendered 960x540/1920x1080 frames.

- [ ] **Step 3: Inspect the diff and commit the gate**

```powershell
git diff --check
git status --short --branch
```

Do not stage unrelated audio assets, map changes or generated artifacts.

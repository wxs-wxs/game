# Ember Camp Modular Refactor World Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 `ExplorationWorld` 的地图布局、绘制、碰撞、交互注册和室内生命周期拆开，同时保持空间常量、交互 ID、碰撞和进出屋行为。

**Architecture:** `ExplorationWorld` 仍是唯一的世界运行时门面和 `Node2D`。`WorldLayout` 提供纯布局计算；`WorldMapRenderer` 负责 `_draw` 和装饰；`WorldCollisionBuilder` 负责静态碰撞；`WorldInteractionRegistry` 负责交互点索引和状态恢复。现有 `InteractionPoint` 子类继续作为动作实现。

**Tech Stack:** Godot 4.7.2 GDScript、Node2D/StaticBody2D、现有 Ninja Adventure 资源和 headless regression scripts。

**Spec:** `docs/superpowers/specs/2026-09-05-modular-refactor-design.md`

## Global Constraints

- 保持 `MAP_SIZE = Vector2(1920, 1080)`、室内偏移、河岸、门位置和所有现有公开常量。
- 不改变世界节点名称、交互点 ID、交互信号、奖励、冷却、碰撞和室内隔离。
- `ExplorationWorld` 不创建或修改 HUD 控件。
- 地图绘制仍使用当前 Ninja Adventure 资源、最近邻过滤和现有 960x540 显示规则。

---

### Task 1: Capture World Facade Behavior

**Files:**
- Create: `tests/world/world_facade_regression.gd`
- Read: `scripts/exploration_world.gd`, `scripts/interaction_point.gd`, `tests/map_art_regression.gd`, `tests/interior_regression.gd`, `tests/house_fire_map_smoke.gd`

**Interfaces:**
- Produces: characterization assertions for current constants, point IDs, signals, bounds and indoor/outdoor transitions.

- [ ] **Step 1: Write the characterization test**

```gdscript
extends SceneTree

func _init() -> void:
    var game := GameManager.new()
    var world := ExplorationWorld.new()
    add_child(world)
    world.setup(game)
    assert(ExplorationWorld.MAP_SIZE == Vector2(1920, 1080))
    assert(ExplorationWorld.INTERIOR_OFFSET.x > ExplorationWorld.MAP_SIZE.x)
    assert(world.get_player_bounds().size.x > 0.0)
    assert(world.get_node_or_null("Player") != null)
    assert(world.get_node_or_null("HouseDoor") != null)
    assert(world.get_node_or_null("InteractionPoints") != null)
    print("WORLD_FACADE_REGRESSION_OK")
    quit()
```

- [ ] **Step 2: Run the characterization test before extraction**

```powershell
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/world/world_facade_regression.gd --quit-after 10
```

Record the current result and node names in the worktree ownership note.

### Task 2: Extract Layout and Collision Construction

**Files:**
- Create: `scripts/world/map/world_layout.gd`
- Create: `scripts/world/map/world_collision_builder.gd`
- Create: `tests/world/world_layout_regression.gd`

**Interfaces:**
- `WorldLayout.outdoor_bounds() -> Rect2`
- `WorldLayout.interior_bounds() -> Rect2`
- `WorldLayout.river_bank_x(y: float) -> float`
- `WorldLayout.safe_outdoor_position(value: Vector2) -> Vector2`
- `WorldCollisionBuilder.build(parent: Node2D, layout: WorldLayout) -> void`
- `WorldCollisionBuilder.clear(parent: Node2D) -> void`

- [ ] **Step 1: Write the failing layout test**

```gdscript
extends SceneTree

const WorldLayout = preload("res://scripts/world/map/world_layout.gd")

func _init() -> void:
    var layout := WorldLayout.new()
    assert(layout.outdoor_bounds() == Rect2(Vector2.ZERO, Vector2(1920, 1080)))
    assert(not layout.outdoor_bounds().intersects(layout.interior_bounds()))
    assert(layout.interior_bounds().position.x > layout.outdoor_bounds().end.x)
    assert(layout.safe_outdoor_position(Vector2(-50, 200)).x >= 12.0)
    assert(layout.river_bank_x(540.0) < 1920.0)
    print("WORLD_LAYOUT_REGRESSION_OK")
    quit()
```

- [ ] **Step 2: Run the test and verify it fails**

```powershell
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/world/world_layout_regression.gd --quit-after 10
```

Expected: load failure because `WorldLayout` does not exist.

- [ ] **Step 3: Implement layout as the single constant source**

Move `MAP_SIZE`, `INTERIOR_OFFSET`, `INTERIOR_ROOM_SIZE`, `RIVER_RECT`, `RIVER_BANK_SWING`, house door positions and bounds formulas into `WorldLayout`. In `ExplorationWorld`, retain constants with the same values as compatibility aliases until all tests stop referring to them directly. Do not move asset paths into layout; those remain renderer concerns.

- [ ] **Step 4: Move collision creation without changing shapes**

Copy `_build_collisions()`, `_add_wall()`, and `_add_water_collision()` into `WorldCollisionBuilder`. The builder may create `StaticBody2D` children under the world, but it must not create interaction points, player nodes or UI. Preserve collision layer/mask, rectangle positions, river curve and the absence of outer air walls.

- [ ] **Step 5: Run focused and existing map tests**

```powershell
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/world/world_layout_regression.gd --quit-after 10
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/map_art_regression.gd --quit-after 10
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/house_fire_map_smoke.gd --quit-after 10
```

Expected: the new layout marker plus unchanged map and house-fire markers.

- [ ] **Step 6: Commit the layout/collision slice**

```powershell
git add scripts/world/map/world_layout.gd scripts/world/map/world_collision_builder.gd tests/world/world_layout_regression.gd
git commit -m "refactor: extract world layout and collision builder"
```

### Task 3: Extract Map Rendering and Decorations

**Files:**
- Create: `scripts/world/map/world_map_renderer.gd`
- Modify: `scripts/exploration_world.gd`
- Create: `tests/world/world_renderer_regression.gd`

**Interfaces:**
- `WorldMapRenderer.setup(game: Object, layout: Object) -> void`
- `WorldMapRenderer.rebuild() -> void`
- `WorldMapRenderer.refresh_weather(weather: String) -> void`

- [ ] **Step 1: Write the renderer test**

```gdscript
extends SceneTree

const WorldLayout = preload("res://scripts/world/map/world_layout.gd")
const WorldMapRenderer = preload("res://scripts/world/map/world_map_renderer.gd")

func _init() -> void:
    var renderer := WorldMapRenderer.new()
    root.add_child(renderer)
    renderer.setup(null, WorldLayout.new())
    renderer.rebuild()
    assert(renderer.get_child_count() > 0)
    for child in renderer.get_children():
        if child is Sprite2D:
            assert(child.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
    print("WORLD_RENDERER_REGRESSION_OK")
    quit()
```

The implementation must keep the current atlas paths as renderer constants and must work with a null game object in this headless test.

- [ ] **Step 2: Move draw and sprite methods mechanically**

Move `_draw()`, `_draw_base_terrain()`, `_draw_tiled_atlas()`, `_draw_varied_grass()`, `_draw_scene_plan()`, `_draw_local_terrain_zones()`, `_draw_floor_patch()`, `_draw_organic_patch()`, `_draw_ground_shadows()`, `_draw_ground_details()`, `_draw_river()`, `_draw_interaction_markers()`, `_draw_zone_labels()`, `_draw_atmosphere()` and the rain/fog/cold/cloud helpers into the renderer. Move `_build_art_sprites()`, `_build_ground_decorations()` and `_add_world_sprite()` into the same owner. Keep coordinates and atlas regions unchanged.

- [ ] **Step 3: Keep world facade signals and weather forwarding**

`ExplorationWorld._process()` forwards the current weather and interaction marker state to the renderer. The renderer never calls `GameManager` methods beyond the explicitly injected state object and never emits gameplay results.

- [ ] **Step 4: Run renderer, art and player tests**

```powershell
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/world/world_renderer_regression.gd --quit-after 10
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/ninja_adventure_art_smoke.gd --quit-after 10
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/player_motion_regression.gd --quit-after 10
```

Expected: renderer/art/player markers remain unchanged and a compatibility-rendered screenshot shows the same terrain composition.

- [ ] **Step 5: Commit the renderer slice**

```powershell
git add scripts/world/map/world_map_renderer.gd scripts/exploration_world.gd tests/world/world_renderer_regression.gd
git commit -m "refactor: extract world map renderer"
```

### Task 4: Extract Interaction Registry and Route the Facade

**Files:**
- Create: `scripts/world/interaction/world_interaction_registry.gd`
- Modify: `scripts/exploration_world.gd`
- Modify: `scripts/interaction_point.gd` only where dependency injection is needed
- Create: `tests/world/world_interaction_registry_regression.gd`

**Interfaces:**
- `WorldInteractionRegistry.register(point: InteractionPoint) -> void`
- `WorldInteractionRegistry.unregister(point: InteractionPoint) -> void`
- `WorldInteractionRegistry.nearest(position: Vector2, radius: float) -> InteractionPoint`
- `WorldInteractionRegistry.serialize_state() -> Dictionary`
- `WorldInteractionRegistry.restore_state(data: Dictionary) -> void`

- [ ] **Step 1: Write the failing registry test**

```gdscript
extends SceneTree

const WorldInteractionRegistry = preload("res://scripts/world/interaction/world_interaction_registry.gd")

func _init() -> void:
    var registry := WorldInteractionRegistry.new()
    assert(registry.nearest(Vector2.ZERO, 40.0) == null)
    print("WORLD_INTERACTION_REGISTRY_REGRESSION_OK")
    quit()
```

- [ ] **Step 2: Move point collection and lookup**

Move `active_interaction`, point registration, availability checks, nearest-point selection, cooldown/respawn state serialization and construction-site restoration into the registry/coordinator. Keep `ExplorationWorld` as the owner of signals `interaction_changed`, `interaction_result`, `interaction_progress_changed`, `storage_open_requested` and `tool_selection_requested`.

- [ ] **Step 3: Inject services into InteractionPoint**

Replace any new upward lookup with an explicit setup dependency. Preserve the current `perform_interaction()` result dictionary, action duration, cancel path, capacity preflight and completion signal. No point subclass may call a UI method.

- [ ] **Step 4: Route indoor/outdoor lifecycle through existing interior classes**

Keep `InteriorManager`, `HouseInterior`, `HouseDoor`, `BedPoint` and `FireplacePoint` behavior unchanged. `enter_house()` and `exit_house()` remain facade methods that update player state, camera limits, bounds, audio context and registry state in the current order.

- [ ] **Step 5: Run world and interaction regressions**

```powershell
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/world/world_interaction_registry_regression.gd --quit-after 10
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/smoke.gd --quit-after 10
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/interior_regression.gd --quit-after 10
```

The required interaction behavior is covered by `smoke.gd`, `resource_chain_smoke.gd`, `new_features_regression.gd` and `hud_interaction_overlay_regression.gd`; do not invent a standalone `interaction_point.gd` runner.

- [ ] **Step 6: Commit the interaction slice**

```powershell
git add scripts/world/interaction/world_interaction_registry.gd scripts/exploration_world.gd scripts/interaction_point.gd tests/world/world_interaction_registry_regression.gd
git commit -m "refactor: extract world interaction registry"
```

### Task 5: World Gate

**Files:**
- Read: all files changed by Tasks 1-4

**Interfaces:**
- Produces: an `ExplorationWorld` facade with unchanged constants, signals, node names, movement bounds, save state and interaction behavior.

- [ ] **Step 1: Run parser and architecture checks**

```powershell
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --editor --quit
.\tools\check_architecture.ps1 -Root .
```

- [ ] **Step 2: Run world-focused regressions and capture frames**

Run `map_art_regression.gd`, `interior_regression.gd`, `house_fire_map_smoke.gd`, `ninja_adventure_art_smoke.gd`, `player_motion_regression.gd`, `smoke.gd`, and the compatibility-rendered 960x540/1920x1080 frame check. Compare node counts, constants, camera framing and collision positions with Task 1.

- [ ] **Step 3: Commit only intended world files**

```powershell
git diff --check
git status --short --branch
```

Do not stage audio, HUD, artifacts or unrelated worktree changes.

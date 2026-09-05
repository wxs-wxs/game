# Ember Camp Modular Refactor Inventory Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将资源目录、资源总账和背包/储物状态从 `ResourceManager` 拆出，同时保留所有旧字段和方法的行为。

**Architecture:** `ResourceCatalog` 提供资源、鱼、熟食和工具定义；`ResourceLedger` 负责数量、容量、成本和来源原子操作；`InventoryState` 负责背包/储物移动和槽位容量。`ResourceManager` 仍是兼容门面，并暴露旧的 `amounts`、`capacities`、`backpack`、`storage`、`tools` 属性。

**Tech Stack:** Godot 4.7.2 GDScript、现有 JSON 数据和 headless regression scripts。

**Spec:** `docs/superpowers/specs/2026-09-05-modular-refactor-design.md`

## Global Constraints

- 不改变资源数量、容量、背包槽位、鱼处理、工具制作、来源冷却和存档字段。
- 多物品奖励仍遵守全有或全无的容量预检，不自动转存储物架。
- 不修改 `GameManager` 的流程入口；旧 `ResourceManager` API 继续可用。
- 新领域脚本不引用 `UIController`、`ExplorationWorld` 或场景树。

---

### Task 1: Define Inventory Domain Tests

**Files:**
- Create: `tests/inventory/inventory_domain_regression.gd`
- Read: `scripts/resource_manager.gd`, `tests/resource_chain_smoke.gd`, `tests/inventory_action_regression.gd`, `tests/storage_drag_regression.gd`

**Interfaces:**
- Test targets: `ResourceCatalog`, `ResourceLedger`, `InventoryState` exact methods listed in Task 2.

- [ ] **Step 1: Write the failing domain test**

```gdscript
extends SceneTree

const ResourceCatalog = preload("res://scripts/domain/inventory/resource_catalog.gd")
const ResourceLedger = preload("res://scripts/domain/inventory/resource_ledger.gd")
const InventoryState = preload("res://scripts/domain/inventory/inventory_state.gd")

func _init() -> void:
    var catalog := ResourceCatalog.new()
    assert("fish_carp" in catalog.item_keys())
    assert(catalog.display_name("wood") != "wood")
    var ledger := ResourceLedger.new(catalog)
    assert(ledger.can_afford({"wood": 1}))
    var before := ledger.get_amount("wood")
    assert(ledger.spend({"wood": 1}))
    assert(ledger.get_amount("wood") == before - 1)
    var inventory := InventoryState.new(catalog)
    inventory.backpack["wood"] = 1
    assert(inventory.backpack_slots_used() == 1)
    assert(inventory.move_to_storage("wood", 1)["ok"])
    assert(inventory.backpack.get("wood", 0) == 0)
    assert(inventory.storage.get("wood", 0) == 1)
    print("INVENTORY_DOMAIN_REGRESSION_OK")
    quit()
```

- [ ] **Step 2: Run the test and verify it fails**

```powershell
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/inventory/inventory_domain_regression.gd --quit-after 10
```

Expected: load failure because the three domain scripts do not exist.

### Task 2: Implement Catalog, Ledger, and Inventory State

**Files:**
- Create: `scripts/domain/inventory/resource_catalog.gd`
- Create: `scripts/domain/inventory/resource_ledger.gd`
- Create: `scripts/domain/inventory/inventory_state.gd`

**Interfaces:**
- `ResourceCatalog.item_keys() -> Array[String]`
- `ResourceCatalog.display_name(key: String) -> String`
- `ResourceCatalog.fish_name(key: String) -> String`
- `ResourceCatalog.fish_food_value(key: String) -> int`
- `ResourceCatalog.cooked_fish_key(key: String) -> String`
- `ResourceCatalog.tool_definition(tool_id: String) -> Dictionary`
- `ResourceLedger.get_amount(key: String) -> int`
- `ResourceLedger.can_afford(cost: Dictionary) -> bool`
- `ResourceLedger.spend(cost: Dictionary) -> bool`
- `ResourceLedger.add(key: String, delta: int) -> int`
- `ResourceLedger.can_collect_rewards(rewards: Dictionary) -> bool`
- `ResourceLedger.collect_rewards_atomic(rewards: Dictionary, source_id: String = "") -> Dictionary`
- `ResourceLedger.to_dict() -> Dictionary` and `from_dict(data: Dictionary) -> void`
- `InventoryState.backpack_slots_used() -> int`
- `InventoryState.can_carry_item(key: String, amount: int = 1) -> bool`
- `InventoryState.move_to_backpack(key: String, amount: int = 1) -> Dictionary`
- `InventoryState.move_to_storage(key: String, amount: int = 1) -> Dictionary`
- `InventoryState.discard_from_backpack(key: String, amount: int = 1) -> Dictionary`
- `InventoryState.discard_from_storage(key: String, amount: int = 1) -> Dictionary`
- `InventoryState.to_dict() -> Dictionary` and `from_dict(data: Dictionary) -> void`

- [ ] **Step 1: Copy definitions without changing values**

Move the item keys, fish definitions, tool definitions, source rules, display names and capacity defaults from `ResourceManager` into `ResourceCatalog`. Keep `water` as a compatibility item and keep the current cooked-food keys. Do not edit `data/*.json` in this task.

- [ ] **Step 2: Implement ledger operations as direct state owners**

Move `amounts`, `capacities`, `total_collected` and source preflight/commit logic into `ResourceLedger`. Preserve the current all-or-nothing check: `can_collect_rewards` must simulate every reward key before `collect_rewards_atomic` changes any quantity. A failed result returns `{ok:false, reason:<existing reason>, changed:false, data:{}}` and leaves all values unchanged.

- [ ] **Step 3: Implement inventory operations as direct state owners**

Move `backpack`, `storage`, `backpack_capacity` and slot counting into `InventoryState`. Keep occupied-item counting rather than total quantity. `move_to_backpack` must reject a new key when the slot limit is reached and must never silently route the item to storage.

- [ ] **Step 4: Run the domain test**

```powershell
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/inventory/inventory_domain_regression.gd --quit-after 10
```

Expected: `INVENTORY_DOMAIN_REGRESSION_OK` and exit code 0.

- [ ] **Step 5: Commit the isolated domain slice**

```powershell
git add scripts/domain/inventory tests/inventory/inventory_domain_regression.gd
git commit -m "refactor: extract inventory domain state"
```

### Task 3: Convert ResourceManager into a Compatibility Facade

**Files:**
- Modify: `scripts/resource_manager.gd`
- Create: `tests/inventory/resource_manager_facade_regression.gd`
- Read: all current tests that instantiate `ResourceManager`

**Interfaces:**
- `ResourceManager` keeps `RESOURCE_KEYS`, `FISH_KEYS`, `COOKED_FISH_KEYS`, `ITEM_KEYS`, `TOOL_KEYS`, `BACKPACK_BASE_CAPACITY`, `BACKPACK_UPGRADED_CAPACITY` and all existing public methods.
- The facade exposes the delegate dictionaries as aliases so existing code that reads or writes `resources.amounts`, `resources.backpack`, `resources.storage`, `resources.capacities`, `resources.tools` continues to affect the delegate state.

- [ ] **Step 1: Write the failing facade equivalence test**

```gdscript
extends SceneTree

func _init() -> void:
    var legacy := ResourceManager.new()
    var direct := ResourceManager.new()
    var saved := legacy.to_dict()
    direct.from_dict(saved)
    assert(direct.to_dict() == saved)
    legacy.backpack["wood"] = 1
    assert(legacy.backpack_slots_used() == 1)
    var reward := {"medicine": 1, "metal": 1}
    legacy.backpack_capacity = legacy.backpack_slots_used()
    var blocked := legacy.collect_rewards_atomic(reward, "facade_test")
    assert(not bool(blocked.get("ok", false)))
    assert(legacy.backpack.get("medicine", 0) == 0)
    print("RESOURCE_MANAGER_FACADE_REGRESSION_OK")
    quit()
```

- [ ] **Step 2: Run the facade test and verify the new alias behavior is absent**

```powershell
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/inventory/resource_manager_facade_regression.gd --quit-after 10
```

Expected: failure after the test reaches the delegate/alias assertions or before the test file can load if the test is not yet present in the implementation branch.

- [ ] **Step 3: Add delegates without changing public methods**

Instantiate `ResourceCatalog`, `ResourceLedger` and `InventoryState` in `ResourceManager._init()`. Replace method bodies in groups: amount/cost/source methods call the ledger; backpack/storage methods call inventory; names and definitions call the catalog. Keep cooking and tool methods in the facade for this slice, but make them consume the catalog and delegate state. Ensure `from_dict()` repoints aliases after restoring data so old tests that mutate dictionaries still work.

- [ ] **Step 4: Run focused and existing inventory regressions**

```powershell
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/inventory/resource_manager_facade_regression.gd --quit-after 10
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/resource_chain_smoke.gd --quit-after 10
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/inventory_action_regression.gd --quit-after 10
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/storage_drag_regression.gd --quit-after 10
```

Expected: `RESOURCE_MANAGER_FACADE_REGRESSION_OK` and the existing resource/storage markers, with no behavior changes.

- [ ] **Step 5: Commit the facade slice**

```powershell
git add scripts/resource_manager.gd tests/inventory/resource_manager_facade_regression.gd
git commit -m "refactor: route resource manager through inventory services"
```

### Task 4: Inventory Gate

**Files:**
- Read: all files changed by Tasks 1-3

**Interfaces:**
- Produces: a `ResourceManager` facade whose `to_dict/from_dict`, atomic reward behavior, occupied-slot capacity and direct dictionary compatibility match the pre-refactor contract.

- [ ] **Step 1: Run parser and the inventory test set**

```powershell
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --editor --quit
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/inventory/inventory_domain_regression.gd --quit-after 10
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/inventory/resource_manager_facade_regression.gd --quit-after 10
```

- [ ] **Step 2: Run the architecture checker and inspect the diff**

```powershell
.\tools\check_architecture.ps1 -Root .
git diff --check
```

Expected: no new forbidden domain dependency and no whitespace errors.

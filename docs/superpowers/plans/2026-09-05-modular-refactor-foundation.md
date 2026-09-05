# Ember Camp Modular Refactor Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立模块重构共用的结果/快照契约、架构边界检查和 worktree ownership 记录，不改变任何游戏行为。

**Architecture:** 先添加无场景依赖的 `ResultContract` 和 `SnapshotContract`，再用静态脚本检查领域目录的禁止依赖。当前热点门面不搬动、不改名，后续子计划只依赖这些稳定约定。

**Tech Stack:** Godot 4.7.2 GDScript、PowerShell、现有 headless regression scripts。

**Spec:** `docs/superpowers/specs/2026-09-05-modular-refactor-design.md`

## Global Constraints

- 本计划不改变玩法、存档版本、公开入口、场景树或 HUD。
- 不新增全局单例或 `EventBus`。
- 新脚本使用显式 `preload()`；不依赖新增 `class_name` 的解析顺序。
- 架构检查失败时退出码必须为非零，并打印具体文件和规则。

---

### Task 1: Record a Clean Baseline

**Files:**
- Create: `docs/superpowers/verification/2026-09-05-modular-refactor-baseline.md`
- Read: `README.md`, `tools/run_regressions.ps1`, `tools/run_audio_regressions.ps1`

**Interfaces:**
- Produces: a dated record of the parser command, full regression command, audio regression command, exit codes, and any pre-existing warnings.

- [ ] **Step 1: Run the parser and both runners before code changes**

```powershell
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --editor --quit
.\tools\run_regressions.ps1
.\tools\run_audio_regressions.ps1
```

- [ ] **Step 2: Record exact results**

Write the commands, exit codes, runner summary lines, and known ObjectDB/resource-leak warnings into the verification note. Do not replace a failing baseline with a claim that it is expected; record the failure and stop this plan until the baseline is understood.

- [ ] **Step 3: Commit the baseline record**

```powershell
git add docs/superpowers/verification/2026-09-05-modular-refactor-baseline.md
git commit -m "docs: record modular refactor baseline"
```

### Task 2: Add Stable Result and Snapshot Contracts

**Files:**
- Create: `scripts/core/result_contract.gd`
- Create: `scripts/core/snapshot_contract.gd`
- Test: `tests/architecture/contract_regression.gd`

**Interfaces:**
- `ResultContract.ok(data: Dictionary = {}, reason: String = "") -> Dictionary`
- `ResultContract.fail(reason: String, data: Dictionary = {}) -> Dictionary`
- `ResultContract.is_valid(value: Variant) -> bool`
- `SnapshotContract.copy(data: Dictionary) -> Dictionary`
- `SnapshotContract.require_keys(data: Dictionary, keys: Array[String]) -> bool`

- [ ] **Step 1: Write the failing contract test**

```gdscript
extends SceneTree

const ResultContract = preload("res://scripts/core/result_contract.gd")
const SnapshotContract = preload("res://scripts/core/snapshot_contract.gd")

func _init() -> void:
    var success := ResultContract.ok({"amount": 2}, "done")
    assert(success == {"ok": true, "reason": "done", "changed": true, "data": {"amount": 2}})
    var failure := ResultContract.fail("inventory_full")
    assert(failure == {"ok": false, "reason": "inventory_full", "changed": false, "data": {}})
    assert(ResultContract.is_valid(success))
    assert(not ResultContract.is_valid({"ok": true}))
    var source := {"nested": {"value": 1}}
    var copy := SnapshotContract.copy(source)
    copy["nested"]["value"] = 9
    assert(source["nested"]["value"] == 1)
    assert(SnapshotContract.require_keys({"a": 1, "b": 2}, ["a", "b"]))
    assert(not SnapshotContract.require_keys({"a": 1}, ["a", "b"]))
    print("ARCHITECTURE_CONTRACT_REGRESSION_OK")
    quit()
```

- [ ] **Step 2: Run the test and verify it fails**

```powershell
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/architecture/contract_regression.gd --quit-after 10
```

Expected: a script parse/load failure because the two core scripts do not exist.

- [ ] **Step 3: Implement the two contracts**

`result_contract.gd` must always return exactly the four keys `ok`, `reason`, `changed`, and `data`. Implement `ok` with `changed = true` and `fail` with `changed = false`, while empty successful data remains a successful changed command. `is_valid` must check all four keys and the boolean types of `ok` and `changed`.

`snapshot_contract.gd` must deep-copy dictionaries with `duplicate(true)` and return false when any required key is absent. It must not mutate the source.

- [ ] **Step 4: Run the focused test and parser**

```powershell
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/architecture/contract_regression.gd --quit-after 10
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --editor --quit
```

Expected: `ARCHITECTURE_CONTRACT_REGRESSION_OK`, exit code 0, and no `Parse Error` or `SCRIPT ERROR`.

- [ ] **Step 5: Commit the contract slice**

```powershell
git add scripts/core/result_contract.gd scripts/core/snapshot_contract.gd tests/architecture/contract_regression.gd
git commit -m "refactor: add modular result and snapshot contracts"
```

### Task 3: Add Boundary Checks and Ownership Documentation

**Files:**
- Create: `tools/check_architecture.ps1`
- Create: `docs/architecture/dependency-rules.md`
- Create: `docs/architecture/worktree-ownership.md`

**Interfaces:**
- `tools/check_architecture.ps1 -Root <path> -> exit 0/1`
- The checker scans `scripts/core/` and `scripts/domain/` recursively and reports forbidden references to `UIController`, `ExplorationWorld`, `get_parent(`, `/root/Main`, direct `game.ui`, and direct writes to another module's `amounts`, `backpack`, `storage`, or `phase` fields.

- [ ] **Step 1: Write the checker test fixture**

Create a temporary fixture outside the project, for example `artifacts/architecture_fixture/`, containing one clean GDScript file and one file with `get_parent()`. The test command must assert that the clean fixture exits 0 and the forbidden fixture exits 1. Do not add the fixture to the repository.

- [ ] **Step 2: Run the checker test and verify it fails**

```powershell
.\tools\check_architecture.ps1 -Root .
```

Expected: command-not-found or missing-script failure because the checker does not exist.

- [ ] **Step 3: Implement the checker and rules document**

Use `Get-ChildItem -Recurse -Filter *.gd` and `Select-String` with explicit regular expressions. Ignore `.uid` files and report every violation as `ARCHITECTURE_BOUNDARY_FAIL <path>:<line> <rule>`. Return 1 when any violation exists and 0 otherwise. The rules document must list the allowed dependency direction, protected files, and the vertical worktree ownership template:

```text
主功能:
可自由修改:
最小适配文件:
稳定接口:
潜在冲突入口:
验证命令:
```

- [ ] **Step 4: Run the checker and inspect its output**

```powershell
.\tools\check_architecture.ps1 -Root .
```

Expected: exit 0 for the current tree, or a list of pre-existing violations that are recorded and explicitly excluded until the owning migration task removes them. Do not silently suppress a violation.

- [ ] **Step 5: Commit the foundation rules**

```powershell
git add tools/check_architecture.ps1 docs/architecture/dependency-rules.md docs/architecture/worktree-ownership.md
git commit -m "docs: add modular boundaries and worktree ownership rules"
```

### Task 4: Foundation Gate

**Files:**
- Read: all files created by Tasks 1-3

**Interfaces:**
- Produces: a clean foundation commit sequence that later subplans can merge without changing gameplay files.

- [ ] **Step 1: Run the focused contract test and boundary checker**

```powershell
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/architecture/contract_regression.gd --quit-after 10
.\tools\check_architecture.ps1 -Root .
```

- [ ] **Step 2: Run editor parsing and inspect the diff**

```powershell
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --editor --quit
git diff --check
git status --short --branch
```

Expected: no parser errors, no whitespace errors, and no unrelated files staged.

- [ ] **Step 3: Record the foundation merge point**

Add the final commit hashes and the exact checker command to `docs/architecture/worktree-ownership.md`, then commit only that documentation change.

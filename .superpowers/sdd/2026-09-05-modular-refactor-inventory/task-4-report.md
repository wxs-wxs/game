# Task 4 Inventory Gate Report

日期：2026-09-05
工作树：`C:\\projects\\game\\.worktrees\\modular-refactor`

## 检查结果

### 1. Godot parser

命令：

```powershell
& "C:\\projects\\game\\.tools\\godot\\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --editor --quit
```

退出码：`0`

关键输出：`[ DONE ] first_scan_filesystem`、`[ DONE ] update_scripts_classes`。

说明：worktree 未带 `.tools` 目录，使用主项目同版本 Godot 4.7.2 可执行文件，项目路径仍为本 worktree。

### 2. Inventory regression

命令：

```powershell
& "C:\\projects\\game\\.tools\\godot\\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/inventory/inventory_domain_regression.gd --quit-after 10
```

退出码：`0`

关键输出：`INVENTORY_DOMAIN_REGRESSION_OK`

命令：

```powershell
& "C:\\projects\\game\\.tools\\godot\\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/inventory/resource_manager_facade_regression.gd --quit-after 10
```

退出码：`0`

关键输出：`RESOURCE_MANAGER_FACADE_REGRESSION_OK`

### 3. Extended inventory checks

| 检查 | 退出码 | 关键输出 |
|---|---:|---|
| `res://tests/resource_chain_smoke.gd` | 0 | `RESOURCE_CHAIN_SMOKE_OK stone=6 wood=4 axe=true pickaxe=true` |
| `res://tests/inventory_action_regression.gd` | 0 | `INVENTORY_ACTION_REGRESSION_OK carry=3/12 action=pickup` |
| `res://tests/storage_drag_regression.gd` | 0 | `STORAGE_DRAG_REGRESSION_OK slots=12/12 transfer=wood` |

上述脚本退出时出现 Godot 资源/ObjectDB 泄漏警告，但测试标记和进程退出码均为通过；未因此修改代码。

### 4. Architecture checker

命令：

```powershell
.\\tools\\check_architecture.ps1 -Root .
```

退出码：`1`（未通过）

输出共 13 条 `ARCHITECTURE_BOUNDARY_FAIL`，全部为 `scripts/domain/inventory/inventory_state.gd` 和 `scripts/domain/inventory/resource_ledger.gd` 中的 `amounts`、`backpack`、`storage` 字段直接写入，规则文本为 `core/domain must not write another module field directly`。本 gate 未修改实现代码。

### 5. Diff whitespace check

命令：

```powershell
git diff --check
```

退出码：`0`。无 whitespace error；Git 仅提示工作树文件下次触及时会发生 LF 到 CRLF 的换行转换。

## 未提交文件核对

当前工作树共 86 项未提交路径：

- 71 个 `.import` 导入元数据，包含 Ninja Adventure、Kenney Pixel UI、RPG icons、Fusion Pixel 字体、角色图等资源切片导入；其中 `assets/audio/` 下有 3 个音频 `.import`。
- 7 个 Godot 生成的 `.uid` 文件。
- `default_bus_layout.tres` 1 项导入/音频总线相关改动。

这些是 Godot 扫描/资源切片生成的工作树改动，未清理，也未将其误归入库存代码变更。除本报告外，本任务没有代码改动。

## Gate 结论

Parser、库存 facade/domain 回归、资源链、库存动作、仓库存取和 `git diff --check` 均通过；架构检查因上述 13 条现存 domain 字段写入规则违规返回 `1`，因此 Task 4 gate 整体暂不能标记为通过。报告文档是本任务唯一新增文件，需提交。

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

## 修复后复验（checker commit `b4e842c`）

在架构 checker 修复提交 `b4e842c` 后重新执行全套 gate：

| 检查 | 退出码 | 关键输出 |
|---|---:|---|
| Godot editor parser | 0 | `[ DONE ] first_scan_filesystem`、`[ DONE ] loading_editor_layout` |
| `inventory_domain_regression.gd` | 0 | `INVENTORY_DOMAIN_REGRESSION_OK` |
| `resource_manager_facade_regression.gd` | 0 | `RESOURCE_MANAGER_FACADE_REGRESSION_OK` |
| `resource_chain_smoke.gd` | 0 | `RESOURCE_CHAIN_SMOKE_OK stone=6 wood=4 axe=true pickaxe=true` |
| `inventory_action_regression.gd` | 0 | `INVENTORY_ACTION_REGRESSION_OK carry=3/12 action=pickup` |
| `storage_drag_regression.gd` | 0 | `STORAGE_DRAG_REGRESSION_OK slots=12/12 transfer=wood` |
| `tools/check_architecture.ps1 -Root .` | 0 | `ARCHITECTURE_BOUNDARY_OK` |
| `git diff --check` | 0 | 无 whitespace error（仅已有 LF/CRLF 转换提示） |

资源/ObjectDB 泄漏警告仍出现在三个 Godot smoke/regression 进程退出时，但不影响测试标记或退出码。本轮没有修改实现代码。

## 修复后结论

checker 修复后，Task 4 inventory gate 全部通过。报告历史部分保留第一轮 13 条误报失败记录，以上复验结果为当前结论。

## Reviewer fix round 1/5

审查指出 checker 以变量名 `inventory` 整体豁免，可能放行注入的 `InventoryState` 外部字典写入。已将豁免收窄为仅允许明确的 `self` 字段写入，并新增正反向 fixture 回归：

```powershell
& .\tests\architecture\check_architecture_regression.ps1
```

退出码：`0`；关键输出：`ARCHITECTURE_CHECK_REGRESSION_OK`。fixture 验证 `self.amounts[...]` 通过，同时验证注入对象 `inventory.storage[...]` 被拒绝。

修复后重新运行：

- Godot editor parser：退出码 `0`。
- `inventory_domain_regression.gd`：退出码 `0`，`INVENTORY_DOMAIN_REGRESSION_OK`。
- `resource_manager_facade_regression.gd`：退出码 `0`，`RESOURCE_MANAGER_FACADE_REGRESSION_OK`。
- `resource_chain_smoke.gd`：退出码 `0`，`RESOURCE_CHAIN_SMOKE_OK stone=6 wood=4 axe=true pickaxe=true`。
- `inventory_action_regression.gd`：退出码 `0`，`INVENTORY_ACTION_REGRESSION_OK carry=3/12 action=pickup`。
- `storage_drag_regression.gd`：退出码 `0`，`STORAGE_DRAG_REGRESSION_OK slots=12/12 transfer=wood`。
- `git diff --check`：退出码 `0`，无 whitespace error（仅已有 LF/CRLF 转换提示）。

项目级架构检查命令：

```powershell
& .\tools\check_architecture.ps1 -Root .
```

退出码：`1`，输出 5 条真实违规，全部在 `scripts/domain/inventory/resource_ledger.gd` 的 `inventory.storage[...]` 和 `inventory.backpack[...]` 写入（行 36、40、47、83、96）。这是收窄规则后暴露的运行时跨模块内部字典写入；本轮按要求未修改运行时玩法，故该项是后续 concern，不将其描述为通过。

## Reviewer fix round 2/5

为消除上述真实跨模块耦合，在 `InventoryState` 增加 `adjust_storage` 与 `adjust_backpack` 语义操作方法，`ResourceLedger` 的 5 处外部字典写入改为调用这些方法。方法保持原有“当前值加 delta”的行为，公开 `backpack`/`storage` 字典、容量限制、扣减、奖励和同步契约不变。

本轮执行结果：

| 检查 | 退出码 | 关键输出 |
|---|---:|---|
| Godot editor parser | 0 | `[ DONE ] first_scan_filesystem`、`[ DONE ] loading_editor_layout` |
| `inventory_domain_regression.gd` | 0 | `INVENTORY_DOMAIN_REGRESSION_OK` |
| `resource_manager_facade_regression.gd` | 0 | `RESOURCE_MANAGER_FACADE_REGRESSION_OK` |
| `resource_chain_smoke.gd` | 0 | `RESOURCE_CHAIN_SMOKE_OK stone=6 wood=4 axe=true pickaxe=true` |
| `inventory_action_regression.gd` | 0 | `INVENTORY_ACTION_REGRESSION_OK carry=3/12 action=pickup` |
| `storage_drag_regression.gd` | 0 | `STORAGE_DRAG_REGRESSION_OK slots=12/12 transfer=wood` |
| `tests/architecture/check_architecture_regression.ps1` | 0 | `ARCHITECTURE_CHECK_REGRESSION_OK` |
| `tools/check_architecture.ps1 -Root .` | 0 | `ARCHITECTURE_BOUNDARY_OK` |
| `git diff --check` | 0 | 无 whitespace error（仅已有 LF/CRLF 转换提示） |

三个 Godot smoke/regression 进程仍报告既有 ObjectDB/RID/resource 泄漏 warning，但测试标记和退出码均为通过。除 `scripts/domain/inventory/inventory_state.gd`、`scripts/domain/inventory/resource_ledger.gd`、checker fixture 外，本轮未修改文件；未触碰音频、`.import`、`.uid` 或 `default_bus_layout.tres`。

## Fix round 2 conclusion

注入的 `InventoryState` 不再通过 `ResourceLedger` 直接写入内部字典，项目级架构检查与正反向 fixture 均通过；库存回归和 parser 均保持通过。

## Resource atomic weather diagnosis

复现命令：

```powershell
& "C:\projects\game\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/resource_atomic_weather_regression.gd --quit-after 10
```

输出在 `tests/resource_atomic_weather_regression.gd:35` 报 assertion failed（`resources.storage.food > 0`），但 Godot 进程退出码为 `0`；该脚本当前不能仅以退出码判断通过。

原因是测试在初始化后执行 `resources.storage = {}`。`ResourceManager.storage` 是 `_bind_state_aliases()` 建立的公开字典别名，赋值会替换 facade 字段本身，却不会替换 `inventory_state.storage` 或 `ledger.inventory` 所持有的原字典。`TaskSystem.resolve_tick()` 的 `camp_task` 奖励通过 `ResourceLedger -> InventoryState.adjust_storage()` 写入原字典，所以断言读取被替换的空字典而失败。

证据：

- `421265c` 本轮只将 `ResourceLedger` 原有的 `inventory.storage/backpack` 直接写入替换为等价的 `adjust_storage/adjust_backpack` 调用，没有改变 ResourceManager alias 定义或赋值行为。
- `git diff 421265c^ 421265c -- scripts/resource_manager.gd` 无改动；alias 赋值问题在本轮之前已存在。
- `inventory_domain_regression`、`resource_manager_facade_regression`、`resource_chain_smoke`、`inventory_action_regression`、`storage_drag_regression` 均保持各自 `*_OK`，退出码为 `0`。

本轮其余验证：parser 退出码 `0`；checker fixture 输出 `ARCHITECTURE_CHECK_REGRESSION_OK`、退出码 `0`；项目 checker 输出 `ARCHITECTURE_BOUNDARY_OK`、退出码 `0`；`git diff --check` 退出码 `0`。三个 Godot smoke/regression 进程仍有既有资源/ObjectDB 泄漏 warning。未修改运行时代码或生成元数据；该问题属于后续 alias setter/测试契约修复 concern，不是 Task4 `adjust_*` 引入的回归。

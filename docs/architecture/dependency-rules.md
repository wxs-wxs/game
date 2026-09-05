# 模块依赖边界

这份规则约束后续模块化重构的静态依赖。检查器命令为
`tools/check_architecture.ps1 -Root <path>`，只扫描 `scripts/core/` 和
`scripts/domain/` 下的 `.gd` 文件，并忽略 `.uid` 文件。

## 允许的依赖方向

依赖只能从底层流向上层：

`scripts/core`（纯契约、值对象和通用结果） -> `scripts/domain`（玩法规则）
-> `scripts/world`（场景与世界适配） -> `scripts/presentation`（HUD、窗口和输入）
-> `scripts/infrastructure`（持久化、音频和平台适配）。

核心与领域代码不得反向依赖场景树、世界节点或表现层。跨层通信使用显式参数、结果字典、契约对象或信号；不得通过父节点查找或全局单例取回依赖。

## 禁止项

`scripts/core/` 和 `scripts/domain/` 中禁止引用 `UIController`、
`ExplorationWorld`、`get_parent()`、`/root/Main` 或直接访问 `game.ui`。
它们也禁止直接写入其他模块的 `amounts`、`backpack`、`storage`、`phase`
字段。违反时检查器输出 `ARCHITECTURE_BOUNDARY_FAIL <path>:<line> <rule>`
并返回退出码 1；无违反时输出 `ARCHITECTURE_BOUNDARY_OK` 并返回 0。

## 受保护文件

以下共享入口由集成 worktree 维护：

- `project.godot`
- `scenes/Main.tscn`
- `scripts/main.gd`
- 兼容门面及回归 runner（包括 `tools/run_regressions.ps1`）

功能 worktree 只有在 ownership 记录明确列出适配步骤时才修改这些文件，且只能提交转发、信号或构造注入等最小适配。

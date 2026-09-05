# Ember Camp Modular Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在不改变现有玩法、存档和公开入口行为的前提下，把 Ember Camp 的热点脚本拆成可按功能跨目录协作和合并的领域模块。

**Architecture:** 采用渐进式拆分。`Main` 保持组合根，`GameManager`、`ExplorationWorld` 和 `UIController` 在兼容期继续作为门面；资源、生存、世界、表现和存档职责逐步迁移到独立协作者。领域模块通过显式注入和稳定字典契约通信，不建立全局万能事件总线。

**Tech Stack:** Godot 4.7.2、GDScript、JSON 数据、Godot headless regression scripts、原生 CanvasLayer/Control HUD、现有 `AudioService`。

**Spec:** `docs/superpowers/specs/2026-09-05-modular-refactor-design.md`

## Global Constraints

- 不改变单主角探索主循环、交互 ID、奖励、碰撞、输入、HUD 视觉和游戏结束规则。
- 不改变 `SAVE_VERSION` 和现有存档顶层语义。
- 不改变现有公开入口的行为；旧入口通过兼容门面转发到新模块。
- 音频系统保持当前 `AudioService` 架构，不在本计划中重新设计音频。
- 不引入 Web UI、第二套资源账本、第二套事件管理器或全局万能 `EventBus`。
- 保持 960x540 逻辑视口、Fusion Pixel 字体、Kenney Pixel UI、最近邻过滤和整数缩放。
- 新类型优先使用显式 `preload()`，每个切片都运行编辑器解析。
- 一个功能 worktree 可以跨多个相关目录；ownership 按垂直功能切片登记，不按单一目录硬隔离。

## Execution Order

每个子计划都必须先合并前置计划，再在自己的 worktree 中执行。功能 worktree 可以拥有多个相关目录，但不得把新业务逻辑写回其他功能的内部实现。

1. [基础契约和架构检查](2026-09-05-modular-refactor-foundation.md)
2. [资源与背包](2026-09-05-modular-refactor-inventory.md)
3. [日循环与生存](2026-09-05-modular-refactor-survival.md)
4. [世界与交互](2026-09-05-modular-refactor-world.md)
5. [HUD 与输入](2026-09-05-modular-refactor-presentation.md)
6. [存档、集成与清理](2026-09-05-modular-refactor-persistence.md)

## Protected Files

`project.godot`、`scenes/Main.tscn`、`scripts/main.gd`、兼容门面和回归 runner 由集成 worktree 维护。子计划只有在明确列出的适配步骤中才修改门面，而且每次只提交转发、信号或构造注入改动。

## Common Verification

每个子计划的最后一个代码步骤都运行：

```powershell
& ".\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --editor --quit
```

阶段合并后由集成计划运行：

```powershell
.\tools\run_regressions.ps1
.\tools\run_audio_regressions.ps1
```

完成目标是解析通过、现有完整回归与音频回归通过、运行时状态检查通过，并完成一次跨目录功能切片的合并演练。结构重构不提高存档版本号。

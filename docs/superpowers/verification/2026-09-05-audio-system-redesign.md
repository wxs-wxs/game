# 2026-09-05 音频系统重设计核验记录

Worktree: `C:\projects\game\.worktrees\audio-system-redesign`

## 变更说明

为保证这个 worktree 能直接跑验证，我对 `tools/run_regressions.ps1` 做了一个非破坏性修正：它现在会像 `tools/run_audio_regressions.ps1` 一样，向上查找父目录里的 `.tools\godot\...`，而不是只盯着 worktree 根目录。

## 执行命令与结果

### 1. Headless editor parse

```powershell
& "C:\projects\game\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path "C:\projects\game\.worktrees\audio-system-redesign" --editor --quit
```

结果：

```text
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org
[ DONE ] first_scan_filesystem
[ DONE ] loading_editor_layout
```

没有 `SCRIPT ERROR`、`Parse Error` 或非零退出码。

### 2. Existing 30-test runner

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\projects\game\.worktrees\audio-system-redesign\tools\run_regressions.ps1"
```

结果：

```text
ALL_TESTS_OK count=30
```

说明：

- 每个测试结束后都打印了同类 teardown 警告。
- 常见输出是 `WARNING: XX ObjectDB instances were leaked at exit` 和 `ERROR: 12 resources still in use at exit`。
- 这些警告没有打断脚本，脚本最终退出码为 0。

### 3. Four-test audio runner

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\projects\game\.worktrees\audio-system-redesign\tools\run_audio_regressions.ps1"
```

结果：

```text
AUDIO_TESTS_OK count=4
```

附带输出：

- `AUDIO_CATALOG_OK cues=48 validation_errors=0`
- `AUDIO_SERVICE_OK buses=11 events=6 music=exploration_rain layers=3`
- `AUDIO_SAVE_OK legacy=3 omitted_audio=true persistence=true safe_missing=true`
- `AUDIO_GAMEPLAY_REGRESSION_OK`

警告情况：

- `audio_save_regression.gd` 打印了 `WARNING: 27 ObjectDB instances were leaked at exit` 和 `ERROR: 11 resources still in use at exit`。
- `audio_gameplay_regression.gd` 打印了 `WARNING: 45 ObjectDB instances were leaked at exit` 和 `ERROR: 12 resources still in use at exit`。
- 前两个音频测试在这次输出里没有额外的退出清理警告。

### 4. Main.tscn headless launch

```powershell
& "C:\projects\game\.tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path "C:\projects\game\.worktrees\audio-system-redesign" --quit-after 8
```

结果：

```text
WARNING: 29 ObjectDB instances were leaked at exit (run with `--verbose` for details).
ERROR: 12 resources still in use at exit (run with `--verbose` for details).
```

退出码为 0。

## 手工状态清单

这次没有做带鼠标的人工窗口检查；这里按现有回归覆盖来对照，保持诚实记录。

- [x] 户外游玩和下雨状态
  - 证据：`AUDIO_GAMEPLAY_REGRESSION_OK`、`SMOKE_OK`
- [x] 进屋和出屋
  - 证据：`AUDIO_GAMEPLAY_REGRESSION_OK`、`INTERIOR_REGRESSION_OK`
- [x] 点燃炉火和室内常态
  - 证据：`AUDIO_GAMEPLAY_REGRESSION_OK`、`HOUSE_FIRE_MAP_SMOKE_OK`
- [x] 暂停
  - 证据：`SMOKE_OK`、`HUD_INTERACTION_OVERLAY_REGRESSION_OK`
- [x] 背包
  - 证据：`AUDIO_GAMEPLAY_REGRESSION_OK`、`HUD_INTERACTION_OVERLAY_REGRESSION_OK`
- [x] 鱼处理
  - 证据：`AUDIO_GAMEPLAY_REGRESSION_OK`
- [x] 储物
  - 证据：`AUDIO_GAMEPLAY_REGRESSION_OK`
- [x] 建造完成
  - 证据：`AUDIO_GAMEPLAY_REGRESSION_OK`、`BUILD_MODE_REGRESSION_OK`
- [x] 夜间报告
  - 证据：`AUDIO_GAMEPLAY_REGRESSION_OK`、`STRATEGY_SMOKE_OK`
- [x] 游戏结束
  - 证据：`AUDIO_GAMEPLAY_REGRESSION_OK`、`ENDLESS_ACCEPTANCE_REGRESSION_OK`
- [ ] 现场人工视觉复核
  - 未在这次无头核验里执行；如果需要，得在带 UI 的运行里再看一遍。


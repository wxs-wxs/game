# Modular Refactor Baseline

Date: 2026-09-05
Worktree: `C:/projects/game/.worktrees/modular-refactor`
Branch: `codex/modular-refactor`
Starting commit: `f97c1a9 docs: add modular refactor implementation plans`

This is the pre-change baseline for the modular refactor. The existing audio
changes in the main checkout are not present in this worktree and are outside
the refactor scope.

## Verification Commands

### Editor parser

```powershell
& "C:/projects/game/.tools/godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path . --editor --quit
```

Result: exit code `0`.

The editor printed one existing `get_dependencies` resource diagnostic during
the initial scan, then completed filesystem scan, script registration and
reimport. No `Parse Error`, `SCRIPT ERROR` or failed editor exit was reported.

### Full regression runner

```powershell
.\tools\run_regressions.ps1
```

Result: exit code `0`; final marker `ALL_TESTS_OK count=36`.

All 36 scripts completed with their existing success markers. Several tests
print the known Godot shutdown diagnostics below; the runner treats them as
non-fatal because the process exit code is zero and no assertion or script
error is present:

```text
WARNING: <N> ObjectDB instances were leaked at exit.
ERROR: <N> resources still in use at exit.
ERROR: 1 RID allocations of type 'PN18TextServerAdvanced12FontAdvancedE' were leaked at exit.
WARNING: <N> RIDs of type "CanvasItem" were leaked.
```

### Audio regression runner

```powershell
.\tools\run_audio_regressions.ps1
```

Result: exit code `0`; final marker `AUDIO_TESTS_OK count=4`.

The audio runner produced `AUDIO_CATALOG_OK`, `AUDIO_SERVICE_OK`,
`AUDIO_SAVE_OK` and `AUDIO_GAMEPLAY_REGRESSION_OK`. The save and gameplay
scripts also printed the same known ObjectDB/resource-leak shutdown warnings.

## Baseline Contract

The refactor must preserve these parser and regression results. The known
shutdown warnings are recorded for comparison and are not new failures unless
their count or severity changes together with a failing exit code or assertion.

# Task 2 Report: AudioService, Player Pools, and Snapshots

Status: complete

Implementation commit: `fb4bc52` (`feat: add global audio service and mix snapshots`)

## Changes

- Added `AudioService` with catalog loading, normalized world state, event
  recording, missing-event and silent-stream fallback, listener position, and
  a private `RandomNumberGenerator`.
- Added double-buffer music state de-duplication and crossfade support,
  Environment/Weather/Fire ambience layers, and World/UI/Critical SFX pools.
- Added cooldown, max-instance, priority/steal handling and a reserved
  Critical channel. Headless mode records decisions without creating players.
- Added `AudioSnapshotStack` with pause, modal, interior, danger, and game-over
  targets calculated from the current user volume base values.
- Added `AudioSettings` ConfigFile round-trip support for
  `user://audio_settings.cfg` and clamped master/music/ambience/sfx values.
- Added `tests/audio_service_regression.gd` covering fixed buses, event/fallback
  recording, pool limits, Critical reservation, music and ambience state,
  snapshot recovery, settings clamping, listener position, and RNG ownership.

## Verification

Focused service test:

```powershell
& 'C:\projects\game\.tools\godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/audio_service_regression.gd --quit-after 5
```

Output:

```text
AUDIO_SERVICE_OK buses=11 events=5 music=exploration_rain layers=3
EXIT=0
```

Editor parse/scan:

```powershell
& 'C:\projects\game\.tools\godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --editor --quit
```

Result: `EXIT=0`; no `SCRIPT ERROR` or `Parse Error` messages.

Task 1 catalog regression (compatibility check):

```powershell
& 'C:\projects\game\.tools\godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/audio_catalog_regression.gd --quit-after 5
```

Output: `AUDIO_CATALOG_OK cues=48 validation_errors=0`, `EXIT=0`.

`git diff --check` passed for all Task 2 implementation files before commit.

## Concerns

- The Autoload registration and legacy save/settings migration are intentionally
  deferred to Task 3; direct construction and headless SceneTree tests are
  supported in this task.
- The current catalog still points at the approved placeholder WAV assets. Real
  audio replacement and gameplay call-site migration remain later tasks.
- Verification here is headless. Non-headless crossfade timing and audible
  output still need the runtime acceptance pass after Autoload registration.

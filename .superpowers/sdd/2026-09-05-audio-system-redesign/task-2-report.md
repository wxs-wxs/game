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

## Review Fixes

Fix commit: `3fe0df9` (`fix: harden audio pools and threat snapshots`)

- Bound each active SFX decision to its actual player node. Reuse now requires
  the correct spatial type, and every playback resets its bus, position,
  `max_distance`, and pitch. Stealing stops and reclaims the selected node;
  lowest-priority stealing only accepts a strictly lower-priority candidate.
- Added high/critical/danger threat music selection (`exploration_threat`) and
  a non-empty danger snapshot, with recovery when threat returns to low.
- Added ambience fade-in/fade-out tweens with a documented `fade_seconds`
  duration and safe no-tree/headless behavior.
- Added a real `AudioListener2D` for non-headless spatial playback and applied
  cue `max_distance` to `AudioStreamPlayer2D`.
- Expanded the regression test for ConfigFile persistence, final silent
  fallback, headless no-player creation, threat transitions, player routing,
  actual oldest/priority stealing, spatial distance/position, double-buffer
  music, and ambience layer transitions.

Review-fix verification:

```text
AUDIO_SERVICE_OK buses=11 events=5 music=exploration_rain layers=3
EXIT=0
EDITOR_EXIT=0
AUDIO_CATALOG_OK cues=48 validation_errors=0
CATALOG_EXIT=0
```

The focused test completed without the previous invalid-playback errors or
resource-leak warnings. The non-headless controller checks are safely forced
through configuration paths in the headless test; audible output still needs
the later runtime acceptance pass.

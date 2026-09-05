# Final Fix Report: Runtime Audio Playback and Semantic Coverage

Status: complete

Commit: `fix: harden runtime audio playback and semantic coverage`

Working tree: `C:\projects\game\.worktrees\audio-system-redesign`

## Fixes

- Music and ambience controllers force `AudioStreamWAV` loop streams to
  `AudioStreamWAV.LOOP_FORWARD`, including placeholder fallback WAVs.
- `AudioService.set_listener_position()` is called from the live player during
  outdoor and indoor movement and during world transitions.
- Catalog cue `base_volume_db` is passed to the music and ambience controllers;
  user bus settings and snapshot targets remain bus-level controls.
- The fixed Weather bus now has a low-pass filter, and the interior snapshot
  attenuates Weather by `-18 dB`. Outdoor rain and Fire layering are unchanged.
- Successful gameplay branches now emit the remaining catalog cues for player
  hurt/eat/medicine/cold, gathering, crafting, survival warnings/raids,
  dusk/sleep, event reveal/choice, tasks, milestones, and blueprint unlocks.
  Failed branches do not emit success cues.
- Audio regression settings use temporary `user://` paths and remove them after
  the test; no `audio_settings.cfg` test pollution remains.

## Verification

Focused audio regressions:

```powershell
.\tools\run_audio_regressions.ps1
```

Output:

```text
AUDIO_CATALOG_OK cues=48 validation_errors=0
AUDIO_SERVICE_OK buses=11 events=6 music=exploration_rain layers=3
AUDIO_SAVE_OK legacy=3 omitted_audio=true persistence=true safe_missing=true
AUDIO_GAMEPLAY_REGRESSION_OK
AUDIO_TESTS_OK count=4
```

Existing regression suite:

```powershell
.\tools\run_regressions.ps1
```

Output: `ALL_TESTS_OK count=30`.

Editor parse/scan:

```powershell
& 'C:\projects\game\.tools\godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --editor --quit
```

Output: exit code `0`; no script parse or load errors.

Main scene launch:

```powershell
& 'C:\projects\game\.tools\godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --scene res://scenes/Main.tscn --quit-after 3
```

Output: exit code `0`.

Diff check:

```powershell
git diff --check
```

Output: no whitespace errors. Godot test processes continue to report the
pre-existing ObjectDB/resource-leak warnings at exit; all commands return
success.

## Concerns

- Catalog runtime streams are still the approved placeholder WAV assets; this
  fix hardens playback behavior without changing the asset replacement scope.
- The non-headless loop/listener assertions exercise controller construction in
  the headless test process; audible output still requires a normal desktop
  session for final listening QA.

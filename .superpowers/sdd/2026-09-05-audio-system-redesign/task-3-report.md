# Task 3 Report

Status: PASS (Task 3 focused checks)

Commit: pending

Changes:

- Registered `AudioService` as the `res://scripts/audio_service.gd` Autoload.
- Removed local `AudioManager` construction from `scripts/main.gd`; startup now loads user audio settings once and keeps the Autoload as `GameManager.audio` compatibility state.
- Removed global audio preferences from new `GameManager.to_dict()` saves and migrated non-empty legacy `audio` dictionaries through a safe `/root/AudioService` lookup, with a compatibility fallback for tests before the Autoload is ready.
- Added `tests/audio_save_regression.gd` for legacy migration, omitted new save blocks, ConfigFile persistence, and missing-field safety.
- Updated `tests/smoke.gd` to use semantic event recording and fixed bus checks.
- Removed the conflicting `class_name AudioService` registration so Godot can instantiate an Autoload with the required `AudioService` name; adjusted service test typing for the script-preload form.

Commands and exact output:

```text
godot --headless --path . --script tests/audio_save_regression.gd
AUDIO_SAVE_OK legacy=3 omitted_audio=true persistence=true safe_missing=true
WARNING: 27 ObjectDB instances were leaked at exit (run with `--verbose` for details).
ERROR: 11 resources still in use at exit (run with --verbose for details).

godot --headless --path . --script tests/smoke.gd
SMOKE_OK audio_events=1 indoor=false build_xp=0
WARNING: 76 ObjectDB instances were leaked at exit (run with `--verbose` for details).
ERROR: 12 resources still in use at exit (run with --verbose for details).

godot --headless --path . --script tests/audio_catalog_regression.gd
AUDIO_CATALOG_OK cues=48 validation_errors=0

godot --headless --path . --script tests/audio_service_regression.gd
AUDIO_SERVICE_OK buses=11 events=5 music=exploration_rain layers=3

godot --headless --editor --quit --path .
exit code 0; no SCRIPT ERROR or Parse Error
```

Concerns:

- Existing Task 4 gameplay call sites still call `play_music`/`play_ambience` while `GameManager.audio` now points at `AudioService`; a normal headless game launch reports those expected migration errors until Task 4 replaces the call sites with semantic service calls.
- The focused tests still report the repository's existing ObjectDB/resource-leak warnings at exit.

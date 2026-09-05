# Ember Camp 音频系统重设计 Implementation Plan

> For agentic workers: REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

Goal: 在不改变探索、交互、建造、存档和 HUD 行为的前提下，用全局 AudioService、语义事件、固定总线、多层环境和可测试策略替换现有占位 AudioManager。

Architecture: AudioService 作为 Autoload 维护用户设置、世界音频状态、事件目录和快照；AudioCatalog 把数据目录转换为类型化 AudioCue 资源；音乐、环境和 SFX 控制器分别管理播放器、循环层和优先级池。玩法脚本只发送语义事件或状态更新，兼容层在迁移结束后删除。

Tech Stack: Godot 4.7.2 GDScript、AudioServer、AudioStreamPlayer/AudioStreamPlayer2D、ConfigFile、Godot headless regression scripts、现有 960x540 CanvasItem/integer stretch 配置。

Spec: docs/superpowers/specs/2026-09-05-audio-system-design.md

## Global Constraints

- 保持单主角探索主循环、现有地图、交互、建造、存档和 HUD 行为不变。
- 第一阶段继续使用现有 assets/audio/*/placeholder.wav，不下载或引入新的第三方音频资源。
- 音频故障、缺失资源、headless 或静音不能改变 gameplay 结果、游戏 RNG、存档和流程状态。
- 总线在 default_bus_layout.tres 中固定定义，运行时不得动态创建或删除总线。
- 用户设置使用 user://audio_settings.cfg；旧存档 audio 字段只迁移读取，不再写回游戏存档。
- 所有新 HUD 数值和控件仍使用 960x540 逻辑坐标、Fusion Pixel 字体、最近邻纹理和整数缩放。
- 现有 30 项回归必须继续通过；新增音频测试单独运行并报告结果。

---

### Task 1: Establish Audio Data Model and Fixed Bus Layout

Files:
- Create scripts/audio_cue.gd
- Create scripts/audio_catalog.gd
- Create data/audio_catalog.json
- Create default_bus_layout.tres
- Create assets/audio/SOURCES.md
- Test tests/audio_catalog_regression.gd

Interfaces:
- AudioCue exposes id, event_kind, output_bus, stream_paths, fallback_id, base_volume_db, pitch_min, pitch_max, priority, cooldown_ms, max_instances, spatial_mode, max_distance and steal_policy.
- AudioCatalog.load_from_path(path: String) -> AudioCatalog parses the JSON registry into AudioCue resources and exposes get_cue(id), has_cue(id), validate() and fallback_for(cue).
- All catalog IDs are lower-case dotted IDs from the approved spec; aliases are stored only in the migration map.

- [ ] Step 1: Write the failing catalog test. Load the catalog, assert the approved UI/player/interaction/build/world/survival/day/end-game IDs exist, assert validation returns no errors, and assert every cue resolves to an existing stream or a category placeholder.
- [ ] Step 2: Run the focused test with Godot headless. Expected: FAIL because the catalog and typed resource classes do not exist.
- [ ] Step 3: Implement AudioCue and AudioCatalog. Parse JSON with JSON.parse_string, reject duplicate IDs, normalize res:// paths, and resolve missing paths through fallback_id before returning a cue. Use only the existing three placeholder WAV files.
- [ ] Step 4: Create the AudioBusLayout with Master, Music, Ambience, Environment, Weather, Fire, SFX, World, UI, Critical and Voice buses. Route child buses to their parent categories and set audio/default_bus_layout=res://default_bus_layout.tres in project.godot.
- [ ] Step 5: Record existing placeholder WAV paths and future replacement requirements in assets/audio/SOURCES.md without adding new assets.
- [ ] Step 6: Run tests/audio_catalog_regression.gd. Expected: AUDIO_CATALOG_OK with zero validation errors.
- [ ] Step 7: Commit with git commit -m feat: add data-driven audio catalog and bus layout.

### Task 2: Implement AudioService, Player Pools, and Snapshots

Files:
- Create scripts/audio_service.gd
- Create scripts/audio_music_controller.gd
- Create scripts/audio_ambience_controller.gd
- Create scripts/audio_sfx_controller.gd
- Create scripts/audio_snapshot_stack.gd
- Create scripts/audio_settings.gd
- Test tests/audio_service_regression.gd

Interfaces:
- AudioService.emit_event(event_id: String, params: Dictionary = {}) -> String returns played, suppressed, missing or headless and records the event in event_log.
- AudioService.set_world_state(state: Dictionary) -> void accepts phase, location, weather, threat, fire_lit, fire_source and paused and reacts only when normalized state changes.
- AudioService.push_snapshot(id), pop_snapshot(id) and clear_snapshots() recompute all bus targets from the active snapshot set.
- AudioService.to_settings_dict(), apply_settings(data), load_user_settings() and save_user_settings() manage master/music/ambience/sfx in user://audio_settings.cfg.
- AudioService.set_listener_position(position: Vector2) updates the single 2D listener position for spatial events.

- [ ] Step 1: Write service tests for fixed buses, event recording in headless mode, missing-resource fallback, cooldown/max instances, Critical reservation, music de-duplication, snapshot recovery, settings round-trip and isolated audio RNG.
- [ ] Step 2: Run tests/audio_service_regression.gd and confirm it fails because the service and controllers do not exist.
- [ ] Step 3: Implement AudioSettings around ConfigFile, clamp four settings to 0.0..1.0, and make AudioSnapshotStack calculate target dB from base user volume plus active snapshots. No caller restores a hard-coded volume.
- [ ] Step 4: Implement music double-buffer crossfade, one player per ambience layer, and SFX pools for World/UI/Critical. Use lazy stream loading and a silent AudioStreamWAV fallback. Never synthesize a tone in normal mode.
- [ ] Step 5: Implement AudioService orchestration, catalog loading, normalized world state, music/layer mapping, priority/cooldown/steal policy, event_log, active_music_id, active_ambience_layers and last_snapshot_targets. Use a private RandomNumberGenerator.
- [ ] Step 6: Run tests/audio_service_regression.gd. Expected: AUDIO_SERVICE_OK with no script errors.
- [ ] Step 7: Commit with git commit -m feat: add global audio service and mix snapshots.

### Task 3: Register the Service and Migrate Settings/Save Compatibility

Files:
- Modify project.godot
- Modify scripts/main.gd
- Modify scripts/game_manager.gd
- Modify scripts/save_system.gd only if a migration helper is required
- Modify tests/smoke.gd
- Test tests/audio_save_regression.gd

Interfaces:
- The Autoload name is AudioService and its script path is res://scripts/audio_service.gd.
- GameManager.audio is a temporary reference to the Autoload for old save/test code; new gameplay code uses AudioService directly.
- GameManager.from_dict() reads legacy audio keys once and calls AudioService.apply_settings(); GameManager.to_dict() no longer writes a global audio preference block.

- [ ] Step 1: Write tests for legacy audio.music/sfx/ambience, a new dictionary without that field, user-settings persistence across a fresh service instance, and absence of the live audio preference block in GameManager.to_dict().
- [ ] Step 2: Run tests/audio_save_regression.gd and confirm it fails because the Autoload and migration are absent.
- [ ] Step 3: Add the Autoload entry, remove local audio_manager.gd construction from main.gd, assign game.audio = AudioService only as a compatibility pointer, and call load_user_settings once during startup.
- [ ] Step 4: Remove the live audio block from GameManager.to_dict(). In from_dict(), pass a legacy block to AudioService.apply_settings() without changing gameplay state. Do not overwrite settings with an empty dictionary.
- [ ] Step 5: Update smoke.gd to use the service API, assert the fixed child bus names, and assert event recording instead of current_music fields.
- [ ] Step 6: Run audio_save_regression.gd and smoke.gd. Expected: AUDIO_SAVE_OK and SMOKE_OK.
- [ ] Step 7: Commit with git commit -m refactor: register global audio service and migrate settings.

### Task 4: Migrate Gameplay and UI Call Sites to Semantic Audio

Files:
- Modify scripts/exploration_world.gd
- Modify scripts/explorer_player.gd
- Modify scripts/interaction_point.gd
- Modify scripts/build_mode_controller.gd
- Modify scripts/construction_site.gd
- Modify scripts/house_door.gd
- Modify scripts/game_manager.gd
- Modify scripts/ui_controller.gd
- Test tests/audio_gameplay_regression.gd

Interfaces:
- Gameplay uses AudioService.emit_event(id, params) for one-shot events and AudioService.set_world_state(state) for continuous context.
- ExplorationWorld._refresh_audio_context() is the only world-context synchronizer; it sends phase/location/weather/threat/fire_lit and never chooses an audio filename.
- UI pause/modal handlers push and pop named snapshots instead of calling set_pause_ducked().

- [ ] Step 1: Write an integration test for outdoor exploration, rain, house entry/exit, fireplace ignition, interaction start/cancel/complete/failure, build completion, pause, backpack, fish processing, storage, report and game-over. Assert semantic IDs and active ambience layers while retaining existing gameplay assertions.
- [ ] Step 2: Run tests/audio_gameplay_regression.gd and confirm it fails because call sites still address the old manager.
- [ ] Step 3: Update ExplorationWorld to send normalized state on morning start, weather changes, house entry and house exit. Update ExplorerPlayer footsteps to send player.footstep with surface, position and indoor parameters.
- [ ] Step 4: Map interaction shortage/start/cancel/failure/complete, fishing cast, build invalid/place/complete, door open/close and fire ignite/extinguish/fuel-low to semantic IDs. Emit after the same gameplay branch succeeds.
- [ ] Step 5: Map day/morning/report/game-over/build/upgrade events in GameManager. Replace UIController pause and modal ducking with snapshot push/pop, including nested backpack/storage/fish-processing/log/report overlays. Map save/load feedback to ui.save_complete and ui.load_complete.
- [ ] Step 6: Run audio_gameplay_regression.gd plus smoke.gd, interior_regression.gd, house_fire_map_smoke.gd, build_mode_regression.gd and hud_interaction_overlay_regression.gd. No direct game.audio.play_* references may remain outside the compatibility wrapper.
- [ ] Step 7: Commit with git commit -m refactor: migrate gameplay audio to semantic events.

### Task 5: Remove Legacy AudioManager and Add Audio Regression Runner

Files:
- Delete scripts/audio_manager.gd
- Delete scripts/audio_manager.gd.uid if unused
- Create tools/run_audio_regressions.ps1
- Modify README.md
- Modify assets/audio/SOURCES.md

Interfaces:
- No gameplay script or test may call play_music, play_ambience, play_sfx or set_pause_ducked after this task.
- The audio runner executes audio_catalog_regression.gd, audio_service_regression.gd, audio_save_regression.gd and audio_gameplay_regression.gd and finishes with AUDIO_TESTS_OK count=4.

- [ ] Step 1: Search scripts, tests, project.godot and README.md for play_music, play_ambience, play_sfx, set_pause_ducked and audio_manager. Update any remaining setup reference.
- [ ] Step 2: Delete the old manager and UID only after the search is clean. The Autoload script is the only global audio entry point.
- [ ] Step 3: Add the audio runner with the same fail-fast SCRIPT ERROR/exit-code checks as run_regressions.ps1. Document normal launch, existing 30-test command and the new audio command in README.md.
- [ ] Step 4: Run tools/run_audio_regressions.ps1. Expected: AUDIO_TESTS_OK count=4.
- [ ] Step 5: Commit with git commit -m refactor: remove legacy audio manager.

### Task 6: Full Verification and Runtime Checks

Files:
- Modify tools/run_regressions.ps1 only for a non-breaking path/output fix
- Create docs/superpowers/verification/2026-09-05-audio-system-redesign.md

- [ ] Step 1: Run Godot headless editor parse. Expected: exit code 0 with no SCRIPT ERROR or Parse Error.
- [ ] Step 2: Run tools/run_regressions.ps1. Expected: ALL_TESTS_OK count=30.
- [ ] Step 3: Run tools/run_audio_regressions.ps1. Expected: AUDIO_TESTS_OK count=4.
- [ ] Step 4: Run the game from the worktree and manually verify outdoor play, rain, house entry, lit fireplace, pause, backpack, fish processing, storage, build completion, night report and game-over. Verify no visual layout or input behavior changed.
- [ ] Step 5: Record exact commands, outputs, known ObjectDB/resource-leak warnings and the manual state checklist in the verification note. Run git diff --check and git status --short --branch; stage only intended audio implementation, tests, resources and docs.
- [ ] Step 6: Commit with git commit -m test: record audio system verification.

## Plan Self-Review

- Catalog, fallback, fixed buses and source records are covered by Task 1.
- Runtime controllers, snapshots, priority, cooldown, spatial events and settings are covered by Task 2.
- Autoload registration and legacy save migration are covered by Task 3.
- World, player, interaction, construction, survival, day-cycle and UI event coverage is covered by Task 4.
- Legacy API removal, command documentation and the independent audio runner are covered by Task 5.
- Existing 30-test regression, four audio tests, editor parse and manual viewport checks are covered by Task 6.
- No task depends on a placeholder asset beyond the existing files or an external download.
- No task changes gameplay RNG, resource outcomes or HUD layout rules.

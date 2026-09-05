# SDD ledger — plan: docs/superpowers/plans/2026-09-05-audio-system-redesign.md

## Preflight Scan

| Scope | Shared interface/files | Finding | Ruling |
| --- | --- | --- | --- |
| Task 1 -> Task 2 | AudioCue/AudioCatalog | Task 2 consumes the catalog and bus names from Task 1. No conflict. | Implement catalog validation before service loading. |
| Task 2 -> Task 3 | AudioService Autoload and settings API | Task 3 registers the singleton and migrates saves. No conflict. | Keep AudioService constructible for headless unit tests. |
| Task 2 -> Task 4 | emit_event/set_world_state/snapshots | Task 4 consumes exact APIs from Task 2. No conflict. | Preserve event_log and state introspection for integration tests. |
| Task 3 -> Task 4 | GameManager.audio compatibility pointer | Task 4 removes direct calls while Task 3 temporarily preserves the pointer. No conflict. | Remove pointer only after all call sites and tests migrate. |
| Task 4 -> Task 5 | Legacy methods | Task 5 deletes the wrapper after Task 4 search is clean. No conflict. | Run rg search before deletion. |
| Task 5 -> Task 6 | Test runners | Task 6 consumes the independent audio runner and existing 30-test runner. No conflict. | Keep existing count=30 and report audio count separately. |

| Task | Internal consistency | Finding | Ruling |
| --- | --- | --- | --- |
| 1 | Tests match catalog interfaces and files. | No conflict. | Proceed. |
| 2 | Tests match controller/service interfaces and headless behavior. | No conflict. | Proceed. |
| 3 | Save migration and Autoload registration match the service settings API. | No conflict. | Proceed. |
| 4 | Integration paths match current world/UI states. | No conflict. | Proceed. |
| 5 | Deletion occurs only after the legacy search. | No conflict. | Proceed. |
| 6 | Verification commands cover all required outputs. | No conflict. | Proceed. |

## Rulings

- Ruling: carry the current main-worktree tracked diff and required untracked test/script files into this isolated worktree — the committed HEAD alone is not parseable because construction_site.gd references the untracked workbench_art.gd, and current tests depend on the newer Survivor fields. Cost if wrong: the worktree would validate a stale, broken baseline instead of the user-visible project state.

## Task Status

- Task 1: complete (commits e943f0f..268619c, review clean). Minor deferred: validate negative priority and add malformed/duplicate/fallback-cycle cases in later hardening; keep legacy AudioManager until Tasks 3-5.
- Task 2: complete (commits fb4bc52..f59a0a6, review clean after two fix rounds). Fixed player routing/reuse, strict priority stealing, threat snapshots/music, ambience fade races, spatial distance reset and listener activation; minor untested edge cases are non-blocking.

- Task 3: fix round 1/5 (1 addressed, 0 open; commit b564b47). Added migration-only AudioService aliases and kept smoke pointed at the Autoload; headless main launch is clean.
- Task 3: complete (commits 4788d3e..b564b47, review clean).

- Task 4: fix round 1/5 (2 open findings: game-over snapshot lifecycle; unbalanced UI modal snapshot transitions). Fix dispatched to original implementer after review.
- Task 4: fix round 1/5 (2 addressed, 0 open; commit 25197a3). Game-over snapshots now clear on non-ended world state; modal snapshot is balanced across nested overlays.
- Task 4: complete (commits 141512f..25197a3, review clean).

- Task 5: complete (commits 730e8ac, review clean).

- Task 6: complete (commit 5bd46f4). Editor parse, 30-test runner, four-test audio runner, Main.tscn headless launch, diff check, and verification note completed; expected ObjectDB/resource-leak warnings recorded.

- Final fix wave: complete (pending commit `fix: harden runtime audio playback and semantic coverage`). Loop fallback streams, live listener synchronization, cue base volumes, indoor Weather attenuation/filtering, and remaining semantic gameplay coverage are implemented. Verification remains `ALL_TESTS_OK count=30`, `AUDIO_TESTS_OK count=4`, editor parse exit `0`, and Main.tscn headless exit `0`.

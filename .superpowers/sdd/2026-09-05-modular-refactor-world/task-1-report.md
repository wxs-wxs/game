# Task 1 Report: World Facade Characterization

## Command and result

The brief command used a relative `.tools` path, but this worktree does not
contain that directory. The available executable was resolved at
`C:\projects\game\.tools\godot\Godot_v4.7.2-stable_win64_console.exe` and
the equivalent command was run from `C:\projects\game\.worktrees\modular-refactor`:

```powershell
& 'C:\projects\game\.tools\godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/world/world_facade_regression.gd --quit-after 10
```

Exit code: `0`

Marker:

```text
WORLD_FACADE_REGRESSION_OK map=(1920.0, 1080.0) interior_offset=(2400.0, 0.0) outside_bounds=[P: (12.0, 12.0), S: (1896.0, 1056.0)] points=55 signals=22 nodes=Player,HouseDoor(type),InteractionPoints(array)
```

## Captured behavior

- `ExplorationWorld.MAP_SIZE` is `Vector2(1920, 1080)`.
- `INTERIOR_OFFSET` is outside the map at `Vector2(2400, 0)` and the room is
  `Vector2(180, 180)`.
- Outdoor player bounds are `[P: (12, 12), S: (1896, 1056)]`.
- `Player` is a real child node. The current implementation does not create a
  literal `HouseDoor` child name or an `InteractionPoints` container node:
  `HouseDoor` is a real `HouseDoor` instance in `world.interactions`, and the
  interaction collection is the real `world.interactions` array with 55 points.
  The test records these current semantics rather than changing production
  naming during characterization.
- The world exposes the five facade signals from the brief, among 22 total
  inherited/declared signal entries: `interaction_changed`,
  `interaction_result`, `interaction_progress_changed`,
  `storage_open_requested`, and `tool_selection_requested`.
- Registered point IDs include `campfire`, `house_door`, `river_fishing`,
  `old_ruins`, and `forest_tree`.
- A real door interaction from `HOUSE_DOOR_OUTSIDE_POSITION` starts and
  completes, sets `is_inside` and `player.interior`, creates an interior door
  with ID `house_exit`, and produces positive indoor bounds. `exit_house()`
  returns the player to the authored outside threshold and outdoor bounds.

## Self-review

- Only `tests/world/world_facade_regression.gd` was added for the test change.
- The test creates real `GameManager` and `ExplorationWorld` instances and
  does not use mocks, stubs, or empty assertions.
- Assertions cover constants, bounds, node/type presence, point IDs, signals,
  and both sides of the indoor/outdoor transition.
- No production scripts, audio files, `.import`, `.uid`, or default bus layout
  files were modified.

## Risks and follow-up

- Godot reports `43 ObjectDB instances were leaked at exit` and `19 resources
  still in use at exit` during headless process cleanup. The process exits 0 and
  the marker is emitted; this existing cleanup noise should be monitored if
  the extraction changes lifecycle ownership.
- Future extraction may introduce literal `HouseDoor` and `InteractionPoints`
  node names. The characterization should then retain the current type/array
  checks while adding compatibility assertions for those names if they become
  part of the public facade.

## Fix round 1

The characterization test was strengthened to lock the observed bounds and
signal signatures.

Commands and results:

```powershell
& 'C:\projects\game\.tools\godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/world/world_facade_regression.gd --quit-after 10
```

Exit code: `0`

```text
WORLD_FACADE_REGRESSION_OK map=(1920.0, 1080.0) interior_offset=(2400.0, 0.0) outside_bounds=[P: (12.0, 12.0), S: (1896.0, 1056.0)] points=55 signals=22 nodes=Player,HouseDoor(type),InteractionPoints(array)
```

The test now asserts outdoor bounds `Rect2(12, 12, 1896, 1056)` and indoor
bounds `Rect2(2416, 17, 148, 146)` before and after the real door transition.
It also validates signal argument counts and names: `prompt`; `message`;
`name`, `progress`; and no arguments for each storage/tool request signal.

Parser check:

```powershell
& 'C:\projects\game\.tools\godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --editor --quit
```

Exit code: `0`.

`git diff --check` exit code: `0`.

The same existing headless cleanup warnings remain (43 ObjectDB instances and
19 resources), with no effect on the successful exit code or marker.

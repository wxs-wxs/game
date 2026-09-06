# Task 1 Report: UI Facade Characterization

## Baseline Verification

The existing presentation regressions passed before any production UI change:

- `HUD_LAYOUT_OK`
- `HUD_ICONS_OK resources=7 rail=0`
- `HUD_INTERACTION_OVERLAY_REGRESSION_OK`
- `UI_DETAIL_REMOVED_OK`

## Characterization

Added `tests/presentation/ui_facade_regression.gd` without changing production
UI code. The test records the current compatibility facade contract:

- `HUDRoot` keeps `scale == Vector2.ONE` in the `960x540` logical viewport.
- Status/resource, survivor/objective, backpack, storage, and shortcut panels
  retain their current authored positions and sizes.
- Resource icons remain 16x16, textured, nearest-filtered, and unscaled; the
  survivor avatar remains textured at 24x36.
- `toggle_backpack()` and `close_overlay()` maintain one overlay pause layer,
  pause `GameManager.time`, and restore the prior unpaused state on close.
- `show_event()` and `show_report()` remain callable and replace one another
  while keeping a single modal pause layer.

## Verification

- `UI_FACADE_REGRESSION_OK`
- Existing ObjectDB/resource shutdown leak warnings remain non-fatal; tests exit
  with code 0.

# Task 3 Report: Persistent HUD View

## Changes

- Added `scripts/presentation/hud/hud_view.gd` with the required `setup`, `refresh`, and `required_snapshot_keys` contract.
- `HudView.setup` creates and initializes a default `UiFactory` when passed `null`, and can be exercised without a game scene.
- Added persistent HUD construction for status rail, temperature chip, resource badges/icons, survivor card, objective card, prompt, feedback toast, and interaction progress.
- Added `tests/presentation/hud_view_regression.gd`.
- Added `UIController._build_ui_snapshot()` and routes the final HUD refresh through a deep-copied snapshot while preserving all existing public fields as compatibility references.
- Removed per-control resource/status/survivor writes from `UIController.refresh()`; persistent HUD values now land through the single `HudView.refresh()` call.
- Overlay construction and gameplay/state rules remain in `UIController` for this stage.

## Verification

- Godot editor parser check: passed.
- `HUD_VIEW_REGRESSION_OK`: passed.
- `HUD_LAYOUT_OK`: passed.
- `HUD_RESOURCE_TOOLTIPS_OK resources=7`: passed.
- `HUD_INTERACTION_OVERLAY_REGRESSION_OK`: passed.
- `UI_FACADE_REGRESSION_OK`: passed.

## Notes

`UIController` now constructs the persistent HUD through `HudView.setup()` and maps its existing public fields to the view-owned controls. A legacy builder function remains in the source as an unused compatibility reference during this staged refactor; overlays continue to be built by `UIController`.

# Task 4 Report: World Interaction Registry

## Red test

- Added `tests/world/world_interaction_registry_regression.gd` with the brief's
  empty-registry nearest assertion.
- Initial run failed because `world_interaction_registry.gd` did not exist.

## Implementation

- Added `WorldInteractionRegistry` for point registration/unregistration,
  duplicate-ID allocation, availability-aware nearest lookup, interaction
  serialization/restoration, active interaction tracking, and construction-site
  restoration.
- Routed `ExplorationWorld` point registration, nearest selection, active state,
  serialization/restoration, and construction-site restoration through the
  registry while retaining facade signals and indoor/outdoor lifecycle order.

## Verification

- `WORLD_INTERACTION_REGISTRY_REGRESSION_OK`
- `SMOKE_OK audio_events=18 indoor=false build_xp=0`
- `RESOURCE_CHAIN_SMOKE_OK stone=6 wood=4 axe=true pickaxe=true`
- `NEW_FEATURES_REGRESSION_OK zoom=1.35 fish=fish_trout respawn=(850.7366, 834.4268)`
- `INTERIOR_REGRESSION_OK door=(158.0, 124.0) spawn=(2424.0, 90.0) exit=(158.0, 145.0)`
- `SAVE_PHASE_REGRESSION_OK version=9`
- `HUD_INTERACTION_OVERLAY_REGRESSION_OK`
- Headless editor parser exit 0; `ARCHITECTURE_BOUNDARY_OK`; `git diff --check`
  exit 0 (pre-existing CRLF conversion warnings only).

## Warnings

Existing smoke runs still report ObjectDB/resource shutdown leaks; all tests
exit 0 and emit their success markers.

## Review Fix: Indoor Point Cleanup

- `ExplorationWorld.exit_house()` now unregisters points owned by the active
  `HouseInterior` before `InteriorManager.exit()` queues that scene for removal.
  Outdoor points remain registered and visible after the transition.
- The interaction registry regression now covers direct register/unregister,
  two enter/exit cycles, stable outdoor point counts, and the absence of stale
  interior parents in the registry.

### Review Verification

- `WORLD_INTERACTION_REGISTRY_REGRESSION_OK`
- Related interior, smoke, save-phase, and HUD interaction regressions passed.
- Headless editor parser, architecture boundary check, and `git diff --check`
  passed; existing ObjectDB/resource shutdown leak warnings remain non-fatal.

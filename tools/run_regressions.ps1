$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$godotConsole = Join-Path $projectRoot ".tools\godot\Godot_v4.7.2-stable_win64_console.exe"
$tests = @(
    "tests/endless_day_flow_regression.gd",
    "tests/event_flow_regression.gd",
    "tests/unified_construction_regression.gd",
    "tests/campfire_fuel_regression.gd",
    "tests/fire_and_depth_regression.gd",
    "tests/resource_atomic_weather_regression.gd",
    "tests/hud_interaction_overlay_regression.gd",
    "tests/storage_drag_regression.gd",
    "tests/save_phase_regression.gd",
    "tests/endless_acceptance_regression.gd",
    "tests/smoke.gd",
    "tests/resource_chain_smoke.gd",
    "tests/inventory_action_regression.gd",
    "tests/backpack_redesign_regression.gd",
    "tests/strategy_smoke.gd",
    "tests/construction_unification_regression.gd",
    "tests/blueprint_effects_regression.gd",
    "tests/crafting_regression.gd",
    "tests/build_mode_regression.gd",
    "tests/building_icon_source_regression.gd",
    "tests/facility_regression.gd",
    "tests/interior_regression.gd",
    "tests/house_fire_map_smoke.gd",
    "tests/temperature_food_regression.gd",
    "tests/time_manager_regression.gd",
    "tests/hud_layout_regression.gd",
    "tests/hud_icon_regression.gd",
	"tests/hud_resource_tooltip_regression.gd",
	"tests/threat_removal_regression.gd",
    "tests/ui_detail_close.gd",
    "tests/map_art_regression.gd",
    "tests/ninja_adventure_art_smoke.gd",
    "tests/player_motion_regression.gd",
    "tests/new_features_regression.gd",
    "tests/tool_selection_regression.gd",
    "tests/workbench_regression.gd"
)

foreach ($test in $tests) {
    Write-Host ("RUN " + $test)
    $runOutput = & $godotConsole --headless --path $projectRoot --script ("res://" + $test) --quit-after 12 2>&1 | Out-String
    $exitCode = $LASTEXITCODE
    Write-Host $runOutput
    if ($exitCode -ne 0 -or $runOutput -match "SCRIPT ERROR|Assertion failed|Parse Error|Failed to load script") {
        Write-Error ("FAILED " + $test + " exit=" + $exitCode)
        exit ([Math]::Max(1, $exitCode))
    }
}
Write-Host "ALL_TESTS_OK count=$($tests.Count)"

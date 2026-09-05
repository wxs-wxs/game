$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$godotConsole = $null
$searchRoot = $projectRoot
while ($true) {
    $candidate = Join-Path $searchRoot ".tools\godot\Godot_v4.7.2-stable_win64_console.exe"
    if (Test-Path $candidate) {
        $godotConsole = $candidate
        break
    }
    $parent = Split-Path $searchRoot -Parent
    if ($parent -eq $searchRoot) {
        break
    }
    $searchRoot = $parent
}
if ($godotConsole -eq $null) {
    throw "Unable to locate Godot console executable."
}
$tests = @(
    "tests/audio_catalog_regression.gd",
    "tests/audio_asset_selection_regression.gd",
    "tests/audio_service_regression.gd",
    "tests/audio_save_regression.gd",
    "tests/audio_gameplay_regression.gd"
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
Write-Host "AUDIO_TESTS_OK count=$($tests.Count)"

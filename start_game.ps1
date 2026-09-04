$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$bundledEngine = Join-Path $projectRoot ".tools\godot\Godot_v4.7.2-stable_win64.exe"
$pathEngine = Get-Command godot -ErrorAction SilentlyContinue

if (Test-Path -LiteralPath $bundledEngine) {
    Start-Process -FilePath $bundledEngine -ArgumentList @("--path", $projectRoot)
    exit 0
}

if ($null -ne $pathEngine) {
    Start-Process -FilePath $pathEngine.Source -ArgumentList @("--path", $projectRoot)
    exit 0
}

Write-Error "Godot was not found. Install Godot 4.x or add godot.exe to PATH."
exit 1

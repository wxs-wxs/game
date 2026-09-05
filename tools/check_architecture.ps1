[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string] $Root = (Get-Location).Path
)

$ErrorActionPreference = 'Stop'
$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$scanDirectories = @('scripts/core', 'scripts/domain')
$rules = @(
    [pscustomobject]@{ Pattern = '\bUIController\b'; Rule = 'core/domain must not depend on UIController' }
    [pscustomobject]@{ Pattern = '\bExplorationWorld\b'; Rule = 'core/domain must not depend on ExplorationWorld' }
    [pscustomobject]@{ Pattern = '\bget_parent\s*\('; Rule = 'core/domain must not use get_parent()' }
    [pscustomobject]@{ Pattern = '/root/Main'; Rule = 'core/domain must not depend on /root/Main' }
    [pscustomobject]@{ Pattern = '\bgame\.ui\b'; Rule = 'core/domain must not access game.ui directly' }
    [pscustomobject]@{ Pattern = '(?:\$?[A-Za-z_]\w*(?:\.[A-Za-z_]\w*|\[[^\]]+\])*)\.(?:amounts|backpack|storage|phase)(?:\[[^\]]+\])?\s*(?:=|\+=|-=|\*=|/=|%=)'; Rule = 'core/domain must not write another module field directly' }
    [pscustomobject]@{ Pattern = '(?:\$?[A-Za-z_]\w*(?:\.[A-Za-z_]\w*|\[[^\]]+\])*)\[\s*["'']?(?:amounts|backpack|storage|phase)["'']?\s*\](?:\[[^\]]+\])?\s*(?:=|\+=|-=|\*=|/=|%=)'; Rule = 'core/domain must not write another module field directly' }
    [pscustomobject]@{ Pattern = '^\s*(?!var\s+)(?:amounts|backpack|storage|phase)(?:\[[^\]]+\])?\s*(?:=|\+=|-=|\*=|/=|%=)'; Rule = 'core/domain must not write another module field directly' }
)

$violations = @()
foreach ($directory in $scanDirectories) {
    $scanPath = Join-Path $resolvedRoot $directory
    if (-not (Test-Path -LiteralPath $scanPath -PathType Container)) {
        continue
    }

    $files = Get-ChildItem -LiteralPath $scanPath -Recurse -Filter '*.gd' -File
    foreach ($file in $files) {
        foreach ($rule in $rules) {
            $matches = Select-String -LiteralPath $file.FullName -Pattern $rule.Pattern
            foreach ($match in $matches) {
                $relativePath = [IO.Path]::GetRelativePath($resolvedRoot, $file.FullName).Replace('\', '/')
                $violations += "ARCHITECTURE_BOUNDARY_FAIL {0}:{1} {2}" -f $relativePath, $match.LineNumber, $rule.Rule
            }
        }
    }
}

if ($violations.Count -gt 0) {
    $violations | ForEach-Object { Write-Output $_ }
    exit 1
}

Write-Output 'ARCHITECTURE_BOUNDARY_OK'
exit 0

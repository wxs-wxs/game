[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$checker = Join-Path $PSScriptRoot '..\..\tools\check_architecture.ps1'
$checker = (Resolve-Path -LiteralPath $checker).Path
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("architecture-check-" + [Guid]::NewGuid().ToString('N'))

try {
    $localRoot = Join-Path $tempRoot 'local'
    New-Item -ItemType Directory -Force -Path (Join-Path $localRoot 'scripts\domain') | Out-Null
    @'
class_name LocalInventoryFixture
extends RefCounted

var amounts: Dictionary = {}

func add_amount(key: String, amount: int) -> void:
	self.amounts[key] += amount
'@ | Set-Content -LiteralPath (Join-Path $localRoot 'scripts\domain\local_fixture.gd')
    $localOutput = @(& pwsh -NoProfile -File $checker -Root $localRoot 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0 -or $localOutput -notmatch 'ARCHITECTURE_BOUNDARY_OK') {
        throw "local self field fixture should pass: $localOutput"
    }

    $externalRoot = Join-Path $tempRoot 'external'
    New-Item -ItemType Directory -Force -Path (Join-Path $externalRoot 'scripts\domain') | Out-Null
    @'
class_name ExternalInventoryFixture
extends RefCounted

var inventory: RefCounted

func add_amount(key: String, amount: int) -> void:
	inventory.storage[key] = amount
'@ | Set-Content -LiteralPath (Join-Path $externalRoot 'scripts\domain\external_fixture.gd')
    $externalOutput = @(& pwsh -NoProfile -File $checker -Root $externalRoot 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 1 -or $externalOutput -notmatch 'ARCHITECTURE_BOUNDARY_FAIL .*external_fixture\.gd:.*core/domain must not write another module field directly') {
        throw "injected inventory field fixture should fail: $externalOutput"
    }

    Write-Output 'ARCHITECTURE_CHECK_REGRESSION_OK'
    exit 0
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}

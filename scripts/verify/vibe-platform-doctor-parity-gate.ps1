param()

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$adapterRoot = Join-Path $repoRoot 'adapters'
$failures = @()

$codexWindowsPath = Join-Path $adapterRoot 'codex/platform-windows.json'
$codexLinuxPath = Join-Path $adapterRoot 'codex/platform-linux.json'
$codexMacPath = Join-Path $adapterRoot 'codex/platform-macos.json'

foreach ($path in @($codexWindowsPath, $codexLinuxPath, $codexMacPath)) {
    if (-not (Test-Path -LiteralPath $path)) {
        $failures += "missing codex platform contract: $path"
    }
}

if ($failures.Count -eq 0) {
    $win = Get-Content -LiteralPath $codexWindowsPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $linux = Get-Content -LiteralPath $codexLinuxPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $mac = Get-Content -LiteralPath $codexMacPath -Raw -Encoding UTF8 | ConvertFrom-Json

    if ($win.status -ne 'full-authoritative') {
        $failures += "codex windows must remain full-authoritative"
    }
    if ($linux.status -notin @('supported-with-constraints', 'degraded-but-supported')) {
        $failures += "codex linux must remain explicitly constrained, not silently promoted"
    }
    if ($mac.status -eq 'full-authoritative') {
        $failures += "codex macos cannot be marked full-authoritative before proof"
    }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Host "[FAIL] $_" -ForegroundColor Red }
    exit 1
}

Write-Host '[PASS] platform doctor parity gate'

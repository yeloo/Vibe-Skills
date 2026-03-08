param(
    [switch]$WriteArtifacts
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\common\vibe-governance-helpers.ps1')

function Assert-Collect {
    param(
        [bool]$Condition,
        [string]$Message,
        [object]$Details = $null
    )
    if ($Condition) {
        Write-Host "[PASS] $Message"
    } else {
        Write-Host "[FAIL] $Message" -ForegroundColor Red
    }
    return [pscustomobject]@{ pass = $Condition; message = $Message; details = $Details }
}

function Resolve-ManifestPath {
    param(
        [string]$RepoRoot,
        [string]$PathValue
    )
    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return [System.IO.Path]::GetFullPath($PathValue)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $PathValue))
}

$context = Get-VgoGovernanceContext -ScriptPath $PSCommandPath -EnforceExecutionContext
$repoRoot = $context.repoRoot
$manifestPath = Join-Path $repoRoot 'config\upstream-corpus-manifest.json'
$results = New-Object System.Collections.Generic.List[object]
$results.Add((Assert-Collect -Condition (Test-Path -LiteralPath $manifestPath) -Message '存在 upstream corpus manifest')) | Out-Null
if (@($results | Where-Object { -not $_.pass }).Count -gt 0) {
    exit 1
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$entries = @($manifest.entries)
$roots = @($manifest.mirror_roots)
$results.Add((Assert-Collect -Condition ($entries.Count -eq 15) -Message 'manifest entries 可用于 freshness 检查')) | Out-Null
$results.Add((Assert-Collect -Condition ($roots.Count -ge 2) -Message 'manifest 声明了多个 mirror roots')) | Out-Null

$rootResults = @()
$requiredPassCount = 0
$requiredRootCount = 0

foreach ($root in $roots) {
    $resolvedPath = Resolve-ManifestPath -RepoRoot $repoRoot -PathValue ([string]$root.path)
    $required = [bool]$root.required_for_freshness_gate
    if ($required) { $requiredRootCount++ }
    $missing = New-Object System.Collections.Generic.List[string]
    $nonGit = New-Object System.Collections.Generic.List[string]
    $drift = New-Object System.Collections.Generic.List[object]
    $matched = New-Object System.Collections.Generic.List[string]
    $present = New-Object System.Collections.Generic.List[string]

    foreach ($entry in $entries) {
        $slug = [string]$entry.slug
        $expected = [string]$entry.observed_head_sha
        $repoDir = Join-Path $resolvedPath $slug
        if (-not (Test-Path -LiteralPath $repoDir)) {
            $missing.Add($slug) | Out-Null
            continue
        }
        $present.Add($slug) | Out-Null
        if (-not (Test-Path -LiteralPath (Join-Path $repoDir '.git'))) {
            $nonGit.Add($slug) | Out-Null
            continue
        }
        $actual = ''
        try {
            $actual = [string](git -C $repoDir rev-parse HEAD 2>$null | Select-Object -First 1)
        } catch {
            $actual = ''
        }
        if ([string]::IsNullOrWhiteSpace($actual)) {
            $nonGit.Add($slug) | Out-Null
            continue
        }
        if ($actual -eq $expected) {
            $matched.Add($slug) | Out-Null
        } else {
            $drift.Add([pscustomobject]@{ slug = $slug; expected = $expected; actual = $actual }) | Out-Null
        }
    }

    $fullCoverage = (Test-Path -LiteralPath $resolvedPath) -and ($missing.Count -eq 0) -and ($nonGit.Count -eq 0) -and ($drift.Count -eq 0) -and ($matched.Count -eq $entries.Count)
    if ($required -and $fullCoverage) {
        $requiredPassCount++
    }

    $rootResults += [pscustomobject]@{
        id = [string]$root.id
        role = [string]$root.role
        path = $resolvedPath
        required_for_freshness_gate = $required
        exists = [bool](Test-Path -LiteralPath $resolvedPath)
        expected_entry_count = [int]$root.expected_entry_count
        present_count = $present.Count
        matched_count = $matched.Count
        missing = [string[]]$missing.ToArray()
        non_git = [string[]]$nonGit.ToArray()
        drift = [object[]]$drift.ToArray()
        full_coverage_and_match = $fullCoverage
    }

    if ($required) {
        $results.Add((Assert-Collect -Condition (Test-Path -LiteralPath $resolvedPath) -Message ('required root {0} 存在' -f $root.id) -Details $resolvedPath)) | Out-Null
        $results.Add((Assert-Collect -Condition $fullCoverage -Message ('required root {0} 满足全量 coverage + HEAD match' -f $root.id))) | Out-Null
    } else {
        $results.Add((Assert-Collect -Condition $true -Message ('non-required root {0} 已记录为 informational state' -f $root.id) -Details ([ordered]@{ path = $resolvedPath; present_count = $present.Count; missing_count = $missing.Count; non_git_count = $nonGit.Count; drift_count = $drift.Count }))) | Out-Null
    }
}

$results.Add((Assert-Collect -Condition ($requiredRootCount -ge 1) -Message '至少配置了一个 required freshness root')) | Out-Null
$results.Add((Assert-Collect -Condition ($requiredPassCount -ge 1) -Message '至少一个 required freshness root 完整且 HEAD 对齐')) | Out-Null

$total = $results.Count
$passed = @($results | Where-Object { $_.pass }).Count
$failed = $total - $passed
$gatePass = ($failed -eq 0)
$gateResultText = if ($gatePass) { 'PASS' } else { 'FAIL' }

Write-Host ''
Write-Host '=== Summary ==='
Write-Host ('Total assertions: ' + $total)
Write-Host ('Passed: ' + $passed)
Write-Host ('Failed: ' + $failed)
Write-Host ('Gate Result: ' + $gateResultText)

if ($WriteArtifacts) {
    $outDir = Join-Path $repoRoot 'outputs\verify'
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
    $jsonPath = Join-Path $outDir 'vibe-upstream-mirror-freshness-gate.json'
    $mdPath = Join-Path $outDir 'vibe-upstream-mirror-freshness-gate.md'
    $assertionSummary = @{ total = $total; passed = $passed; failed = $failed }
    $artifact = @{
        generated_at = [DateTime]::UtcNow.ToString('o')
        gate_result = $gateResultText
        assertions = $assertionSummary
        manifest_path = $manifestPath
        root_results = [object[]]$rootResults
        results = [object[]]$results
    }
    $artifact | ConvertTo-Json -Depth 50 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
    $md = New-Object System.Collections.Generic.List[string]
    $md.Add('# VCO Upstream Mirror Freshness Gate') | Out-Null
    $md.Add('') | Out-Null
    $md.Add('- Gate Result: **' + $artifact.gate_result + '**') | Out-Null
    $md.Add('- Assertions: total=' + $total + ', passed=' + $passed + ', failed=' + $failed) | Out-Null
    $md.Add('') | Out-Null
    $md.Add('| Root | Required | Present | Matched | Missing | Non-git | Drift | Full Coverage |') | Out-Null
    $md.Add('|---|---|---|---|---|---|---|---|') | Out-Null
    foreach ($rootResult in $rootResults) {
        $md.Add(('| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} |' -f $rootResult.id, $rootResult.required_for_freshness_gate, $rootResult.present_count, $rootResult.matched_count, $rootResult.missing.Count, $rootResult.non_git.Count, $rootResult.drift.Count, $rootResult.full_coverage_and_match)) | Out-Null
    }
    Set-Content -LiteralPath $mdPath -Value ($md -join [Environment]::NewLine) -Encoding UTF8
}

if (-not $gatePass) {
    exit 1
}

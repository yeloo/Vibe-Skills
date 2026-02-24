param()

$ErrorActionPreference = "Stop"

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if ($Condition) {
        Write-Host "[PASS] $Message"
        return $true
    }

    Write-Host "[FAIL] $Message" -ForegroundColor Red
    return $false
}

function Invoke-Route {
    param(
        [string]$Prompt,
        [string]$Grade,
        [string]$TaskType,
        [string]$RequestedSkill
    )

    $repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
    $resolver = Join-Path $repoRoot "scripts\router\resolve-pack-route.ps1"

    $routeArgs = @{
        Prompt = $Prompt
        Grade = $Grade
        TaskType = $TaskType
    }
    if ($RequestedSkill) {
        $routeArgs["RequestedSkill"] = $RequestedSkill
    }

    $json = & $resolver @routeArgs
    return ($json | ConvertFrom-Json)
}

$cases = @(
    [pscustomobject]@{ Name = "orchestration-core planning"; Prompt = "brainstorming and writing-plans for architecture"; Grade = "L"; TaskType = "planning"; RequestedSkill = $null; ExpectedPack = "orchestration-core"; ExpectedMode = "pack_overlay" },
    [pscustomobject]@{ Name = "code-quality review canonical"; Prompt = "run code review and security scan"; Grade = "M"; TaskType = "review"; RequestedSkill = "code-review"; ExpectedPack = "code-quality"; ExpectedMode = "pack_overlay" },
    [pscustomobject]@{ Name = "data-ml coding"; Prompt = "build machine learning model with feature engineering and training"; Grade = "M"; TaskType = "coding"; RequestedSkill = $null; ExpectedPack = "data-ml"; ExpectedMode = "legacy_fallback"; ExpectConfidenceBelowFallback = $true },
    [pscustomobject]@{ Name = "bio-science research"; Prompt = "bioinformatics genomics pathway sequencing analysis"; Grade = "L"; TaskType = "research"; RequestedSkill = $null; ExpectedPack = "bio-science"; ExpectedMode = "legacy_fallback"; ExpectConfidenceBelowFallback = $true },
    [pscustomobject]@{ Name = "docs-media coding canonical"; Prompt = "process xlsx spreadsheet and export document"; Grade = "M"; TaskType = "coding"; RequestedSkill = "xlsx"; ExpectedPack = "docs-media"; ExpectedMode = "pack_overlay" },
    [pscustomobject]@{ Name = "integration-devops debug"; Prompt = "debug github ci deploy issue with sentry logs"; Grade = "L"; TaskType = "debug"; RequestedSkill = $null; ExpectedPack = "integration-devops"; ExpectedMode = "pack_overlay" },
    [pscustomobject]@{ Name = "ai-llm research"; Prompt = "openai prompt optimization with embedding and rag"; Grade = "M"; TaskType = "research"; RequestedSkill = $null; ExpectedPack = "ai-llm"; ExpectedMode = "legacy_fallback"; ExpectConfidenceBelowFallback = $true },
    [pscustomobject]@{ Name = "research-design planning"; Prompt = "research methodology hypothesis and experimental design"; Grade = "L"; TaskType = "planning"; RequestedSkill = $null; ExpectedPack = "research-design"; ExpectedMode = "pack_overlay" },
    [pscustomobject]@{ Name = "low-signal fallback"; Prompt = "help me with this"; Grade = "M"; TaskType = "research"; RequestedSkill = $null; ExpectedPack = $null; ExpectedMode = "legacy_fallback" },
    [pscustomobject]@{ Name = "docs-media blocked in XL"; Prompt = "xlsx and docx parallel processing"; Grade = "XL"; TaskType = "coding"; RequestedSkill = "xlsx"; ExpectedPack = $null; ExpectedMode = $null; BlockedPack = "docs-media" }
)

$results = @()

Write-Host "=== VCO Pack Regression Matrix ==="
foreach ($case in $cases) {
    $route = Invoke-Route -Prompt $case.Prompt -Grade $case.Grade -TaskType $case.TaskType -RequestedSkill $case.RequestedSkill

    if ($case.ExpectedMode) {
        $results += Assert-True -Condition ($route.route_mode -eq $case.ExpectedMode) -Message "[$($case.Name)] route mode is $($case.ExpectedMode)"
    }

    if ($case.ExpectedPack) {
        $results += Assert-True -Condition ($route.selected.pack_id -eq $case.ExpectedPack) -Message "[$($case.Name)] selected pack is $($case.ExpectedPack)"
    }

    if ($case.BlockedPack) {
        $results += Assert-True -Condition ($route.selected.pack_id -ne $case.BlockedPack) -Message "[$($case.Name)] blocked pack $($case.BlockedPack) not selected"
    }

    if ($case.ExpectConfidenceBelowFallback) {
        $results += Assert-True -Condition ([double]$route.confidence -lt [double]$route.thresholds.fallback_to_legacy_below) -Message "[$($case.Name)] confidence below fallback threshold"
    }
}

# Determinism check: same input, same output.
$detA = Invoke-Route -Prompt "run code review and security scan" -Grade "M" -TaskType "review" -RequestedSkill "code-review"
$detB = Invoke-Route -Prompt "run code review and security scan" -Grade "M" -TaskType "review" -RequestedSkill "code-review"
$results += Assert-True -Condition ($detA.selected.pack_id -eq $detB.selected.pack_id) -Message "[determinism] selected pack is stable"
$results += Assert-True -Condition ($detA.route_mode -eq $detB.route_mode) -Message "[determinism] route mode is stable"
$results += Assert-True -Condition ($detA.confidence -eq $detB.confidence) -Message "[determinism] confidence is stable"

$passCount = ($results | Where-Object { $_ }).Count
$failCount = ($results | Where-Object { -not $_ }).Count
$total = $results.Count

Write-Host ""
Write-Host "=== Summary ==="
Write-Host "Total assertions: $total"
Write-Host "Passed: $passCount"
Write-Host "Failed: $failCount"

if ($failCount -gt 0) {
    exit 1
}

Write-Host "Pack regression matrix checks passed."
exit 0

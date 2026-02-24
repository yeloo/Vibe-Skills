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

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$configRoot = Join-Path $repoRoot "config"

$packManifestPath = Join-Path $configRoot "pack-manifest.json"
$aliasMapPath = Join-Path $configRoot "skill-alias-map.json"
$thresholdPath = Join-Path $configRoot "router-thresholds.json"
$skillKeywordIndexPath = Join-Path $configRoot "skill-keyword-index.json"

$results = @()

Write-Host "=== VCO Pack Router Config Checks ==="
$results += Assert-True -Condition (Test-Path -LiteralPath $packManifestPath) -Message "pack-manifest.json exists"
$results += Assert-True -Condition (Test-Path -LiteralPath $aliasMapPath) -Message "skill-alias-map.json exists"
$results += Assert-True -Condition (Test-Path -LiteralPath $thresholdPath) -Message "router-thresholds.json exists"
$results += Assert-True -Condition (Test-Path -LiteralPath $skillKeywordIndexPath) -Message "skill-keyword-index.json exists"

$packManifest = Get-Content -LiteralPath $packManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$aliasMap = Get-Content -LiteralPath $aliasMapPath -Raw -Encoding UTF8 | ConvertFrom-Json
$thresholds = Get-Content -LiteralPath $thresholdPath -Raw -Encoding UTF8 | ConvertFrom-Json
$skillKeywordIndex = Get-Content -LiteralPath $skillKeywordIndexPath -Raw -Encoding UTF8 | ConvertFrom-Json

$requiredPackIds = @(
    "orchestration-core",
    "code-quality",
    "data-ml",
    "bio-science",
    "docs-media",
    "integration-devops",
    "ai-llm",
    "research-design"
)

$packIds = @($packManifest.packs | ForEach-Object { $_.id })
$results += Assert-True -Condition ($packIds.Count -ge 8) -Message "at least 8 packs defined"
$results += Assert-True -Condition (($packIds | Sort-Object -Unique).Count -eq $packIds.Count) -Message "pack IDs are unique"

foreach ($id in $requiredPackIds) {
    $results += Assert-True -Condition ($packIds -contains $id) -Message "required pack '$id' exists"
}

$allowedGrades = @("M", "L", "XL")
$allowedTaskTypes = @("planning", "coding", "review", "debug", "research")

foreach ($pack in $packManifest.packs) {
    $results += Assert-True -Condition ($pack.skill_candidates.Count -gt 0) -Message "pack '$($pack.id)' has skill candidates"
    $results += Assert-True -Condition (($pack.grade_allow | Where-Object { $allowedGrades -notcontains $_ }).Count -eq 0) -Message "pack '$($pack.id)' grade boundaries valid"
    $results += Assert-True -Condition (($pack.task_allow | Where-Object { $allowedTaskTypes -notcontains $_ }).Count -eq 0) -Message "pack '$($pack.id)' task boundaries valid"
}

$autoRoute = [double]$thresholds.thresholds.auto_route
$confirmRequired = [double]$thresholds.thresholds.confirm_required
$fallbackBelow = [double]$thresholds.thresholds.fallback_to_legacy_below

$results += Assert-True -Condition ($autoRoute -gt $confirmRequired) -Message "auto_route threshold higher than confirm_required"
$results += Assert-True -Condition ($confirmRequired -ge $fallbackBelow) -Message "confirm_required is not lower than fallback threshold"
$results += Assert-True -Condition ($thresholds.safety.enforce_grade_boundary -eq $true) -Message "grade boundary safety is enabled"
$results += Assert-True -Condition ($thresholds.safety.enforce_task_boundary -eq $true) -Message "task boundary safety is enabled"
$results += Assert-True -Condition ($thresholds.weights.skill_keyword_signal -ne $null) -Message "skill_keyword_signal weight is configured"
$results += Assert-True -Condition ($skillKeywordIndex.selection.weights.keyword_match -ne $null) -Message "skill index keyword_match weight is configured"
$results += Assert-True -Condition ($skillKeywordIndex.selection.weights.name_match -ne $null) -Message "skill index name_match weight is configured"
$results += Assert-True -Condition ($skillKeywordIndex.selection.fallback_to_first_when_score_below -ne $null) -Message "skill index fallback threshold is configured"
$results += Assert-True -Condition ((@($skillKeywordIndex.skills.PSObject.Properties).Count -gt 0)) -Message "skill index contains skill mappings"

$aliasPairs = @($aliasMap.aliases.PSObject.Properties)
$results += Assert-True -Condition ($null -ne $aliasMap.aliases) -Message "alias mapping container exists"
$results += Assert-True -Condition ($aliasPairs.Count -ge 0) -Message "alias mapping count is valid (can be zero after hard cleanup)"

foreach ($pair in $aliasPairs) {
    $key = [string]$pair.Name
    $value = [string]$pair.Value
    $results += Assert-True -Condition ($key -ne $value) -Message "alias '$key' does not self-reference"
}

foreach ($pair in $aliasPairs) {
    $key = [string]$pair.Name
    $value = [string]$pair.Value

    if ($aliasMap.aliases.PSObject.Properties.Name -contains $value) {
        $reverseTarget = [string]$aliasMap.aliases.$value
        $results += Assert-True -Condition ($reverseTarget -ne $key) -Message "no direct alias loop between '$key' and '$value'"
    }
}

$skillsRoot = Resolve-Path (Join-Path $repoRoot "..")
$topLevelSkillFiles = Get-ChildItem -Path $skillsRoot -Directory |
    ForEach-Object { Join-Path $_.FullName "SKILL.md" } |
    Where-Object { Test-Path -LiteralPath $_ }
$topLevelSkillNames = $topLevelSkillFiles | ForEach-Object { Split-Path (Split-Path $_ -Parent) -Leaf }

foreach ($pair in $aliasPairs) {
    $target = [string]$pair.Value
    $results += Assert-True -Condition ($topLevelSkillNames -contains $target) -Message "alias target '$target' resolves to a canonical top-level skill"
}

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

Write-Host "Pack routing smoke checks passed."
exit 0

param(
    [switch]$FailOnCollision,
    [int]$FailCollisionRiskAt = 40,
    [switch]$WriteArtifacts
)

$ErrorActionPreference = "Stop"

function Normalize-RouterKeyword {
    param([string]$Keyword)
    if ($null -eq $Keyword) { return "" }
    return $Keyword.ToLowerInvariant()
}

function Normalize-TrimmedKeyword {
    param([string]$Keyword)
    if ($null -eq $Keyword) { return "" }
    return $Keyword.Trim().ToLowerInvariant()
}

function Get-CollisionRisk {
    param(
        [string]$KeywordLower,
        [string[]]$Packs
    )

    $packCount = if ($Packs) { $Packs.Count } else { 0 }
    if ($packCount -le 1) { return 0 }

    $risk = ($packCount - 1) * 10
    $len = $KeywordLower.Length
    $isCJK = [Regex]::IsMatch($KeywordLower, "[\p{IsCJKUnifiedIdeographs}]")
    $isAscii = [Regex]::IsMatch($KeywordLower, "[a-z0-9]")

    if ($isCJK) {
        if ($len -le 2) { $risk += 18 }
        elseif ($len -le 3) { $risk += 10 }
    }

    if ($isAscii) {
        if ($len -le 3) { $risk += 18 }
        elseif ($len -le 4) { $risk += 10 }
    }

    $stop = @(
        "ai", "ml", "llm", "api", "mcp",
        "agent", "agents", "prompt", "prompts", "rag",
        "data", "model", "models",
        "deploy", "deployment", "build", "test", "debug", "review", "research",
        "plan", "planning", "analysis", "report",
        "docs", "doc", "pdf", "xlsx", "excel", "github", "ci", "cd",
        "文献", "研究", "方法", "数据", "模型"
    )
    if ($stop -contains $KeywordLower) { $risk += 14 }

    return $risk
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$configRoot = Join-Path $repoRoot "config"
$packManifestPath = Join-Path $configRoot "pack-manifest.json"

if (-not (Test-Path -LiteralPath $packManifestPath)) {
    Write-Host "[FAIL] pack-manifest not found: $packManifestPath" -ForegroundColor Red
    exit 1
}

$manifest = Get-Content -LiteralPath $packManifestPath -Raw | ConvertFrom-Json
$packs = @($manifest.packs)

$errors = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

$perPackIssues = @()

# Global collision detection (router-normalized).
$kwToPacks = @{}

foreach ($pack in $packs) {
    $packId = [string]$pack.id
    $keywords = @($pack.trigger_keywords)

    $empty = @()
    $trimWs = @()
    $nonString = @()

    foreach ($k in $keywords) {
        if ($null -eq $k) { $nonString += $k; continue }
        if (-not ($k -is [string])) { $nonString += ($k | Out-String); continue }
        $s = [string]$k
        if ($s.Trim().Length -eq 0) { $empty += $s; continue }
        if ($s -ne $s.Trim()) { $trimWs += $s }

        $routerNorm = Normalize-RouterKeyword -Keyword $s
        if (-not $kwToPacks.ContainsKey($routerNorm)) {
            $kwToPacks[$routerNorm] = New-Object System.Collections.Generic.HashSet[string]
        }
        [void]$kwToPacks[$routerNorm].Add($packId)
    }

    # Duplicates that are semantically redundant under router normalization:
    # The router lowercases keywords before matching, so case-only duplicates are redundant.
    $routerNorms = @($keywords | Where-Object { $_ -is [string] -and $_.Trim().Length -gt 0 } | ForEach-Object { Normalize-RouterKeyword -Keyword ([string]$_) })
    $dupes = @($routerNorms | Group-Object | Where-Object Count -gt 1 | ForEach-Object { $_.Name })

    if ($nonString.Count -gt 0) {
        $errors.Add("pack '$packId' has non-string trigger_keywords entries ($($nonString.Count))")
    }
    if ($empty.Count -gt 0) {
        $errors.Add("pack '$packId' has empty/whitespace trigger_keywords entries ($($empty.Count))")
    }
    if ($trimWs.Count -gt 0) {
        $errors.Add("pack '$packId' has trigger_keywords with leading/trailing whitespace ($($trimWs.Count))")
    }
    if ($dupes.Count -gt 0) {
        $errors.Add("pack '$packId' has redundant trigger_keywords after lowercasing: $($dupes -join ', ')")
    }

    $perPackIssues += [pscustomobject]@{
        pack_id = $packId
        keyword_count = $keywords.Count
        empty_count = $empty.Count
        trim_ws_count = $trimWs.Count
        nonstring_count = $nonString.Count
        redundant_after_lowercase = $dupes
    }
}

$collisions = @()
foreach ($kv in $kwToPacks.GetEnumerator()) {
    $packsHit = @($kv.Value)
    if ($packsHit.Count -le 1) { continue }
    $k = $kv.Key
    $risk = Get-CollisionRisk -KeywordLower $k -Packs $packsHit
    $collisions += [pscustomobject]@{
        keyword = $k
        pack_count = $packsHit.Count
        packs = $packsHit
        risk = $risk
    }
}

if ($collisions.Count -gt 0) {
    $top = $collisions | Sort-Object -Property @{Expression = "risk"; Descending = $true }, @{Expression = "pack_count"; Descending = $true }, @{Expression = "keyword"; Descending = $false }
    $topSummary = @($top | Select-Object -First 5 | ForEach-Object { "'$($_.keyword)'($($_.pack_count) packs,risk=$($_.risk))" }) -join "; "
    $warnings.Add(("cross-pack trigger keyword collisions: {0} keyword(s); top: {1}" -f $collisions.Count, $topSummary))

    if ($FailOnCollision) {
        $bad = @($top | Where-Object { $_.risk -ge $FailCollisionRiskAt })
        if ($bad.Count -gt 0) {
            $badSummary = @($bad | Select-Object -First 10 | ForEach-Object { "'$($_.keyword)'($($_.pack_count) packs,risk=$($_.risk))" }) -join "; "
            $errors.Add(("collision risk >= {0}: {1}" -f $FailCollisionRiskAt, $badSummary))
        }
    }
}

foreach ($e in $errors) { Write-Host "[FAIL] $e" -ForegroundColor Red }
foreach ($w in $warnings) { Write-Host "[WARN] $w" -ForegroundColor Yellow }

Write-Host ("Packs: {0}" -f $packs.Count)
$totalKeywords = ($packs | ForEach-Object { @($_.trigger_keywords).Count } | Measure-Object -Sum | Select-Object -ExpandProperty Sum)
Write-Host ("Total trigger keywords: {0}" -f $totalKeywords)
Write-Host ("Errors: {0}" -f $errors.Count)
Write-Host ("Warnings: {0}" -f $warnings.Count)

if ($WriteArtifacts) {
    $outDir = Join-Path $repoRoot "outputs\\verify"
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
    $outPath = Join-Path $outDir "vibe-trigger-keyword-hygiene-gate.json"
    [pscustomobject]@{
        pack_manifest = $packManifestPath
        packs = $packs.Count
        issues = $perPackIssues
        collisions = ($collisions | Sort-Object -Property @{Expression = "risk"; Descending = $true }, @{Expression = "pack_count"; Descending = $true }, "keyword")
        errors = $errors
        warnings = $warnings
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $outPath -Encoding UTF8
    Write-Host "Wrote: $outPath"
}

if ($errors.Count -gt 0) { exit 1 }
exit 0

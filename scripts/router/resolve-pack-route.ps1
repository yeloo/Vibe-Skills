param(
    [Parameter(Mandatory = $true)]
    [string]$Prompt,
    [ValidateSet("M", "L", "XL")]
    [string]$Grade = "M",
    [ValidateSet("planning", "coding", "review", "debug", "research")]
    [string]$TaskType = "planning",
    [string]$RequestedSkill
)

$ErrorActionPreference = "Stop"

function Normalize-Key {
    param([string]$InputText)
    if (-not $InputText) { return "" }
    return ($InputText.Trim().Replace("\", "/")).ToLowerInvariant()
}

function Resolve-Alias {
    param(
        [string]$Skill,
        [object]$AliasMap
    )

    if (-not $Skill) {
        return [pscustomobject]@{
            input = $null
            normalized = $null
            canonical = $null
            alias_hit = $false
        }
    }

    $normalized = Normalize-Key -InputText $Skill
    $canonical = $normalized
    $aliasHit = $false

    $keys = $AliasMap.aliases.PSObject.Properties.Name
    if ($keys -contains $normalized) {
        $canonical = [string]$AliasMap.aliases.$normalized
        $aliasHit = $true
    } else {
        $leaf = $normalized.Split("/")[-1]
        if ($keys -contains $leaf) {
            $canonical = [string]$AliasMap.aliases.$leaf
            $aliasHit = $true
        } elseif ($leaf -match "^(.+)/skill\.md$") {
            $trimmed = $Matches[1]
            if ($keys -contains $trimmed) {
                $canonical = [string]$AliasMap.aliases.$trimmed
                $aliasHit = $true
            }
        }
    }

    return [pscustomobject]@{
        input = $Skill
        normalized = $normalized
        canonical = $canonical
        alias_hit = $aliasHit
    }
}

function Test-KeywordHit {
    param(
        [string]$PromptLower,
        [string]$Keyword
    )

    if (-not $PromptLower -or -not $Keyword) { return $false }
    $needle = $Keyword.ToLowerInvariant()
    if (-not $needle) { return $false }

    # CJK terms are best handled as substring matches.
    if ([Regex]::IsMatch($needle, "[\p{IsCJKUnifiedIdeographs}]")) {
        return $PromptLower.Contains($needle)
    }

    # ASCII-like terms should match on token boundaries to reduce cross-pack noise.
    if ([Regex]::IsMatch($needle, "[a-z0-9]")) {
        $escaped = [Regex]::Escape($needle)
        return [Regex]::IsMatch($PromptLower, "(?<![a-z0-9])$escaped(?![a-z0-9])")
    }

    return $PromptLower.Contains($needle)
}

function Get-TriggerKeywordScore {
    param(
        [string]$PromptLower,
        [string[]]$Keywords
    )

    if (-not $Keywords -or $Keywords.Count -eq 0) { return 0.0 }
    $matched = 0
    foreach ($k in $Keywords) {
        if (Test-KeywordHit -PromptLower $PromptLower -Keyword $k) {
            $matched++
        }
    }
    $denominator = [Math]::Min([double]$Keywords.Count, 4.0)
    if ($denominator -le 0) { return 0.0 }
    return [Math]::Min(1.0, ($matched / $denominator))
}

function Get-IntentScore {
    param(
        [string]$PromptLower,
        [string]$PackId,
        [string[]]$Candidates
    )

    $score = 0.0
    $packTokens = $PackId.Split("-")
    foreach ($token in $packTokens) {
        if ($token.Length -ge 3 -and (Test-KeywordHit -PromptLower $PromptLower -Keyword $token)) {
            $score += 0.35
        }
    }

    foreach ($c in $Candidates) {
        if (Test-KeywordHit -PromptLower $PromptLower -Keyword $c) {
            $score += 0.25
        }
    }

    return [Math]::Min(1.0, $score)
}

function Get-WorkspaceSignalScore {
    param(
        [string]$PromptLower,
        [string]$RequestedCanonical,
        [string[]]$Candidates
    )

    if ($RequestedCanonical -and ($Candidates -contains $RequestedCanonical)) {
        return 1.0
    }

    $hits = 0
    foreach ($c in $Candidates) {
        if (Test-KeywordHit -PromptLower $PromptLower -Keyword $c) {
            $hits++
        }
    }
    if ($hits -gt 0) { return 0.6 }
    return 0.0
}

function Get-CandidateNameMatchScore {
    param(
        [string]$PromptLower,
        [string]$Candidate
    )

    if (-not $Candidate) { return 0.0 }
    $variants = @(
        $Candidate,
        $Candidate.Replace("-", " "),
        $Candidate.Replace("-", ""),
        $Candidate.Replace("_", " ")
    ) | Select-Object -Unique

    foreach ($v in $variants) {
        if ($v -and (Test-KeywordHit -PromptLower $PromptLower -Keyword $v)) {
            return 1.0
        }
    }

    return 0.0
}

function Get-SkillKeywordScore {
    param(
        [string]$PromptLower,
        [string]$Candidate,
        [object]$SkillKeywordIndex
    )

    if (-not $SkillKeywordIndex -or -not $SkillKeywordIndex.skills) { return 0.0 }
    $keys = @($SkillKeywordIndex.skills.PSObject.Properties.Name)
    if (-not ($keys -contains $Candidate)) { return 0.0 }

    $entry = $SkillKeywordIndex.skills.$Candidate
    if (-not $entry -or -not $entry.keywords) { return 0.0 }

    $keywords = @($entry.keywords)
    if ($keywords.Count -eq 0) { return 0.0 }

    $hits = 0
    foreach ($k in $keywords) {
        if (Test-KeywordHit -PromptLower $PromptLower -Keyword $k) {
            $hits++
        }
    }

    if ($hits -le 0) { return 0.0 }
    $denominator = [Math]::Min([double]$keywords.Count, 4.0)
    if ($denominator -le 0) { return 0.0 }
    return [Math]::Min(1.0, ($hits / $denominator))
}

function Get-PackSkillSignalScore {
    param(
        [string]$PromptLower,
        [string[]]$Candidates,
        [object]$SkillKeywordIndex
    )

    if (-not $Candidates -or $Candidates.Count -eq 0) { return 0.0 }

    $maxScore = 0.0
    foreach ($candidate in $Candidates) {
        $score = Get-SkillKeywordScore -PromptLower $PromptLower -Candidate $candidate -SkillKeywordIndex $SkillKeywordIndex
        if ([double]$score -gt [double]$maxScore) {
            $maxScore = [double]$score
        }
    }

    return [Math]::Min(1.0, $maxScore)
}

function Select-PackCandidate {
    param(
        [string]$PromptLower,
        [string[]]$Candidates,
        [string]$RequestedCanonical,
        [object]$SkillKeywordIndex
    )

    if (-not $Candidates -or $Candidates.Count -eq 0) {
        return [pscustomobject]@{
            selected = $null
            score = 0.0
            reason = "no_candidates"
            ranking = @()
        }
    }

    if ($RequestedCanonical -and ($Candidates -contains $RequestedCanonical)) {
        return [pscustomobject]@{
            selected = $RequestedCanonical
            score = 1.0
            reason = "requested_skill"
            ranking = @(
                [pscustomobject]@{
                    skill = $RequestedCanonical
                    score = 1.0
                    keyword_score = 1.0
                    name_score = 1.0
                }
            )
        }
    }

    $weightKeyword = 0.8
    $weightName = 0.2
    $fallbackMin = 0.2
    if ($SkillKeywordIndex -and $SkillKeywordIndex.selection -and $SkillKeywordIndex.selection.weights) {
        if ($SkillKeywordIndex.selection.weights.keyword_match -ne $null) {
            $weightKeyword = [double]$SkillKeywordIndex.selection.weights.keyword_match
        }
        if ($SkillKeywordIndex.selection.weights.name_match -ne $null) {
            $weightName = [double]$SkillKeywordIndex.selection.weights.name_match
        }
    }
    if ($SkillKeywordIndex -and $SkillKeywordIndex.selection -and $SkillKeywordIndex.selection.fallback_to_first_when_score_below -ne $null) {
        $fallbackMin = [double]$SkillKeywordIndex.selection.fallback_to_first_when_score_below
    }

    $scored = @()
    for ($i = 0; $i -lt $Candidates.Count; $i++) {
        $candidate = [string]$Candidates[$i]
        $keywordScore = Get-SkillKeywordScore -PromptLower $PromptLower -Candidate $candidate -SkillKeywordIndex $SkillKeywordIndex
        $nameScore = Get-CandidateNameMatchScore -PromptLower $PromptLower -Candidate $candidate
        $score = ($weightKeyword * $keywordScore) + ($weightName * $nameScore)

        $scored += [pscustomobject]@{
            skill = $candidate
            score = [Math]::Round($score, 4)
            keyword_score = [Math]::Round($keywordScore, 4)
            name_score = [Math]::Round($nameScore, 4)
            ordinal = $i
        }
    }

    $ranked = $scored | Sort-Object -Property @(
        @{ Expression = "score"; Descending = $true },
        @{ Expression = "keyword_score"; Descending = $true },
        @{ Expression = "ordinal"; Descending = $false }
    )
    $top = $ranked | Select-Object -First 1
    if (-not $top) {
        return [pscustomobject]@{
            selected = $Candidates[0]
            score = 0.0
            reason = "fallback_first_candidate"
            ranking = @()
        }
    }

    if ([double]$top.score -lt $fallbackMin) {
        return [pscustomobject]@{
            selected = $Candidates[0]
            score = [double]$top.score
            reason = "fallback_first_candidate"
            ranking = @($ranked | Select-Object -First 3)
        }
    }

    return [pscustomobject]@{
        selected = [string]$top.skill
        score = [double]$top.score
        reason = "keyword_ranked"
        ranking = @($ranked | Select-Object -First 3)
    }
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$configRoot = Join-Path $repoRoot "config"

$packManifestPath = Join-Path $configRoot "pack-manifest.json"
$aliasMapPath = Join-Path $configRoot "skill-alias-map.json"
$thresholdPath = Join-Path $configRoot "router-thresholds.json"
$skillKeywordIndexPath = Join-Path $configRoot "skill-keyword-index.json"

$packManifest = Get-Content -LiteralPath $packManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$aliasMap = Get-Content -LiteralPath $aliasMapPath -Raw -Encoding UTF8 | ConvertFrom-Json
$thresholds = Get-Content -LiteralPath $thresholdPath -Raw -Encoding UTF8 | ConvertFrom-Json
$skillKeywordIndex = if (Test-Path -LiteralPath $skillKeywordIndexPath) {
    Get-Content -LiteralPath $skillKeywordIndexPath -Raw -Encoding UTF8 | ConvertFrom-Json
} else {
    $null
}

$weights = $thresholds.weights
$rules = $thresholds.safety
$th = $thresholds.thresholds
$weightSkillSignal = if ($weights.skill_keyword_signal -ne $null) { [double]$weights.skill_keyword_signal } else { 0.25 }

$aliasResult = Resolve-Alias -Skill $RequestedSkill -AliasMap $aliasMap
$requestedCanonical = [string]$aliasResult.canonical
$promptLower = $Prompt.ToLowerInvariant()

$packResults = @()
foreach ($pack in $packManifest.packs) {
    $gradeAllowed = ($pack.grade_allow -contains $Grade)
    $taskAllowed = ($pack.task_allow -contains $TaskType)

    if ($rules.enforce_grade_boundary -and -not $gradeAllowed) { continue }
    if ($rules.enforce_task_boundary -and -not $taskAllowed) { continue }

    $intent = Get-IntentScore -PromptLower $promptLower -PackId $pack.id -Candidates $pack.skill_candidates
    $trigger = Get-TriggerKeywordScore -PromptLower $promptLower -Keywords $pack.trigger_keywords
    $workspace = Get-WorkspaceSignalScore -PromptLower $promptLower -RequestedCanonical $requestedCanonical -Candidates $pack.skill_candidates
    $skillSignal = Get-PackSkillSignalScore -PromptLower $promptLower -Candidates $pack.skill_candidates -SkillKeywordIndex $skillKeywordIndex
    $prior = [double]$pack.priority / 100.0
    $conflictInverse = if ($gradeAllowed -and $taskAllowed) { 1.0 } else { 0.0 }

    $score =
        ([double]$weights.intent_match * $intent) +
        ([double]$weights.trigger_keyword_match * $trigger) +
        ([double]$weights.workspace_signal_match * $workspace) +
        ($weightSkillSignal * $skillSignal) +
        ([double]$weights.recent_success_prior * $prior) +
        ([double]$weights.conflict_penalty_inverse * $conflictInverse)

    $selection = Select-PackCandidate -PromptLower $promptLower -Candidates $pack.skill_candidates -RequestedCanonical $requestedCanonical -SkillKeywordIndex $skillKeywordIndex

    $packResults += [pscustomobject]@{
        pack_id = [string]$pack.id
        score = [Math]::Round($score, 4)
        intent = [Math]::Round($intent, 4)
        trigger = [Math]::Round($trigger, 4)
        workspace = [Math]::Round($workspace, 4)
        skill_signal = [Math]::Round($skillSignal, 4)
        prior = [Math]::Round($prior, 4)
        grade_allowed = $gradeAllowed
        task_allowed = $taskAllowed
        candidates = @($pack.skill_candidates)
        selected_candidate = $selection.selected
        candidate_selection_reason = $selection.reason
        candidate_selection_score = [Math]::Round([double]$selection.score, 4)
        candidate_ranking = @($selection.ranking)
    }
}

$ranked = $packResults | Sort-Object -Property @(
    @{ Expression = "score"; Descending = $true },
    @{ Expression = "pack_id"; Descending = $false }
)
$top = $ranked | Select-Object -First 1
$confidence = if ($top) { [double]$top.score } else { 0.0 }

# Soft-migration behavior: explicit legacy/canonical skill request mapped to a pack
# is treated as a strong routing signal to avoid unnecessary legacy fallback.
if ($top -and $requestedCanonical -and ($top.candidates -contains $requestedCanonical)) {
    $confidence = [Math]::Max($confidence, ([double]$th.confirm_required + 0.05))
}

$routeMode = if ($confidence -lt [double]$th.fallback_to_legacy_below) { "legacy_fallback" } else { "pack_overlay" }

$result = [pscustomobject]@{
    prompt = $Prompt
    grade = $Grade
    task_type = $TaskType
    route_mode = $routeMode
    confidence = [Math]::Round($confidence, 4)
    thresholds = [pscustomobject]@{
        auto_route = [double]$th.auto_route
        confirm_required = [double]$th.confirm_required
        fallback_to_legacy_below = [double]$th.fallback_to_legacy_below
    }
    alias = $aliasResult
    selected = if ($top) {
        [pscustomobject]@{
            pack_id = $top.pack_id
            skill = $top.selected_candidate
            selection_reason = $top.candidate_selection_reason
            selection_score = $top.candidate_selection_score
        }
    } else {
        $null
    }
    ranked = @($ranked | Select-Object -First 3)
}

$result | ConvertTo-Json -Depth 8

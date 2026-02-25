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

function Get-KeywordRatio {
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

    if ($matched -le 0) { return 0.0 }
    $denominator = [Math]::Min([double]$Keywords.Count, 4.0)
    if ($denominator -le 0) { return 0.0 }
    return [Math]::Min(1.0, ($matched / $denominator))
}

function Get-TriggerKeywordScore {
    param(
        [string]$PromptLower,
        [string[]]$Keywords
    )

    return Get-KeywordRatio -PromptLower $PromptLower -Keywords $Keywords
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

    return Get-KeywordRatio -PromptLower $PromptLower -Keywords @($entry.keywords)
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

function Get-RoutingRuleForCandidate {
    param(
        [string]$Candidate,
        [object]$RoutingRules
    )

    if (-not $RoutingRules -or -not $RoutingRules.skills -or -not $Candidate) {
        return $null
    }

    $keys = @($RoutingRules.skills.PSObject.Properties.Name)
    if ($keys -contains $Candidate) {
        return $RoutingRules.skills.$Candidate
    }

    return $null
}

function Test-RuleTaskAllowed {
    param(
        [object]$Rule,
        [string]$TaskType
    )

    if (-not $Rule -or -not $Rule.task_allow) { return $true }
    $allowed = @($Rule.task_allow)
    if ($allowed.Count -eq 0) { return $true }
    return ($allowed -contains $TaskType)
}

function Get-CanonicalForTaskHit {
    param(
        [object]$Rule,
        [string]$TaskType
    )

    if (-not $Rule -or -not $Rule.canonical_for_task) { return 0.0 }
    $canonical = @($Rule.canonical_for_task)
    if ($canonical -contains $TaskType) { return 1.0 }
    return 0.0
}

function Get-PackDefaultCandidate {
    param(
        [object]$Pack,
        [string]$TaskType,
        [string[]]$PreferredCandidates,
        [string[]]$AllCandidates
    )

    if (-not $Pack -or -not $Pack.defaults_by_task) { return $null }

    $taskKeys = @($Pack.defaults_by_task.PSObject.Properties.Name)
    if (-not ($taskKeys -contains $TaskType)) { return $null }

    $defaultSkill = [string]$Pack.defaults_by_task.$TaskType
    if (-not $defaultSkill) { return $null }

    if ($PreferredCandidates -and ($PreferredCandidates -contains $defaultSkill)) {
        return $defaultSkill
    }

    if ($AllCandidates -and ($AllCandidates -contains $defaultSkill)) {
        return $defaultSkill
    }

    return $null
}

function Get-OpenSpecTaskId {
    param(
        [string]$PromptLower,
        [string]$Grade,
        [string]$TaskType
    )

    $raw = "{0}|{1}|{2}" -f $Grade, $TaskType, $PromptLower
    $sha1 = [System.Security.Cryptography.SHA1]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($raw)
        $hashBytes = $sha1.ComputeHash($bytes)
        $hash = ($hashBytes | ForEach-Object { $_.ToString("x2") }) -join ""
        if ($hash.Length -ge 12) {
            return $hash.Substring(0, 12)
        }
        return $hash
    } finally {
        $sha1.Dispose()
    }
}

function Get-OpenSpecGovernanceAdvice {
    param(
        [string]$PromptLower,
        [string]$Grade,
        [string]$TaskType,
        [string]$RequestedCanonical,
        [object]$OpenSpecPolicy
    )

    if (-not $OpenSpecPolicy) {
        return [pscustomobject]@{
            enabled = $false
            mode = "off"
            profile = "none"
            task_applicable = $false
            enforcement = "none"
            reason = "policy_missing"
            bypass_due_to_requested_skill = $false
            preserve_routing_assignment = $true
            task_id = $null
            recommended_artifact = $null
            should_upgrade_to_full = $false
            upgrade_trigger_matches = @()
        }
    }

    $mode = if ($OpenSpecPolicy.mode) { [string]$OpenSpecPolicy.mode } else { "off" }
    if ($mode -eq "off") {
        return [pscustomobject]@{
            enabled = $false
            mode = "off"
            profile = "none"
            task_applicable = $false
            enforcement = "none"
            reason = "policy_off"
            bypass_due_to_requested_skill = $false
            preserve_routing_assignment = $true
            task_id = $null
            recommended_artifact = $null
            should_upgrade_to_full = $false
            upgrade_trigger_matches = @()
        }
    }

    $profile = "none"
    if ($OpenSpecPolicy.profile_by_grade) {
        $gradeKeys = @($OpenSpecPolicy.profile_by_grade.PSObject.Properties.Name)
        if ($gradeKeys -contains $Grade) {
            $profile = [string]$OpenSpecPolicy.profile_by_grade.$Grade
        }
    }

    $taskApplicable = $false
    if ($profile -ne "none" -and $OpenSpecPolicy.required_task_types_by_profile) {
        $profileKeys = @($OpenSpecPolicy.required_task_types_by_profile.PSObject.Properties.Name)
        if ($profileKeys -contains $profile) {
            $requiredTasks = @($OpenSpecPolicy.required_task_types_by_profile.$profile)
            $taskApplicable = ($requiredTasks -contains $TaskType)
        }
    }

    $bypassDueToRequestedSkill = $false
    if ($RequestedCanonical -and $OpenSpecPolicy.exemptions -and $OpenSpecPolicy.exemptions.requested_skill_bypass) {
        $bypassDueToRequestedSkill = $true
    }

    $taskId = Get-OpenSpecTaskId -PromptLower $PromptLower -Grade $Grade -TaskType $TaskType
    $recommendedArtifact = $null
    if ($profile -eq "lite") {
        $liteDir = if ($OpenSpecPolicy.m_lite -and $OpenSpecPolicy.m_lite.directory) {
            [string]$OpenSpecPolicy.m_lite.directory
        } else {
            "openspec/micro"
        }
        $recommendedArtifact = "{0}/{1}.md" -f $liteDir.TrimEnd("/"), $taskId
    } elseif ($profile -eq "full") {
        $changesDir = if ($OpenSpecPolicy.full -and $OpenSpecPolicy.full.changes_dir) {
            [string]$OpenSpecPolicy.full.changes_dir
        } else {
            "openspec/changes"
        }
        $recommendedArtifact = "{0}/{1}" -f $changesDir.TrimEnd("/"), $taskId
    }

    $softScopeHit = $true
    if ($OpenSpecPolicy.soft_confirm_scope) {
        $scopeGrades = @()
        $scopeTasks = @()
        if ($OpenSpecPolicy.soft_confirm_scope.grades) {
            $scopeGrades = @($OpenSpecPolicy.soft_confirm_scope.grades)
        }
        if ($OpenSpecPolicy.soft_confirm_scope.task_types) {
            $scopeTasks = @($OpenSpecPolicy.soft_confirm_scope.task_types)
        }

        if ($scopeGrades.Count -gt 0 -and -not ($scopeGrades -contains $Grade)) {
            $softScopeHit = $false
        }
        if ($scopeTasks.Count -gt 0 -and -not ($scopeTasks -contains $TaskType)) {
            $softScopeHit = $false
        }
    }

    $enforcement = "none"
    $reason = "task_not_applicable"
    if ($taskApplicable -and -not $bypassDueToRequestedSkill) {
        if ($profile -eq "lite") {
            $enforcement = "advisory"
            $reason = "m_lite_card"
        } elseif ($profile -eq "full") {
            switch ($mode) {
                "strict" {
                    $enforcement = "required"
                    $reason = "full_required_strict"
                }
                "soft" {
                    if ($softScopeHit) {
                        $enforcement = "confirm_required"
                        $reason = "full_confirm_soft"
                    } else {
                        $enforcement = "advisory"
                        $reason = "full_advisory_soft_outside_scope"
                    }
                }
                default {
                    $enforcement = "advisory"
                    $reason = "full_advisory_shadow"
                }
            }
        } else {
            $enforcement = "advisory"
            $reason = "profile_none"
        }
    } elseif ($bypassDueToRequestedSkill) {
        $reason = "requested_skill_bypass"
    }

    $upgradeMatches = @()
    if ($profile -eq "lite" -and $OpenSpecPolicy.upgrade_triggers) {
        foreach ($trigger in @($OpenSpecPolicy.upgrade_triggers)) {
            if (Test-KeywordHit -PromptLower $PromptLower -Keyword ([string]$trigger)) {
                $upgradeMatches += [string]$trigger
            }
        }
    }

    $preserveRoutingAssignment = $true
    if ($OpenSpecPolicy.preserve_routing_assignment -ne $null) {
        $preserveRoutingAssignment = [bool]$OpenSpecPolicy.preserve_routing_assignment
    }

    return [pscustomobject]@{
        enabled = $true
        mode = $mode
        profile = $profile
        task_applicable = $taskApplicable
        enforcement = $enforcement
        reason = $reason
        bypass_due_to_requested_skill = $bypassDueToRequestedSkill
        preserve_routing_assignment = $preserveRoutingAssignment
        task_id = $taskId
        recommended_artifact = $recommendedArtifact
        should_upgrade_to_full = ($upgradeMatches.Count -gt 0)
        upgrade_trigger_matches = @($upgradeMatches)
    }
}

function Get-GsdOverlayAdvice {
    param(
        [string]$PromptLower,
        [string]$Grade,
        [string]$TaskType,
        [object]$GsdOverlayPolicy
    )

    if (-not $GsdOverlayPolicy) {
        return [pscustomobject]@{
            enabled = $false
            mode = "off"
            task_applicable = $false
            grade_applicable = $false
            scope_applicable = $false
            enforcement = "none"
            reason = "policy_missing"
            preserve_routing_assignment = $true
            preflight_should_apply = $false
            wave_contract_should_apply = $false
            should_apply_hook = $false
            artifacts = [pscustomobject]@{
                brownfield_directory = $null
                assumption_artifact = $null
                wave_artifact = $null
            }
        }
    }

    $enabled = $true
    if ($GsdOverlayPolicy.enabled -ne $null) {
        $enabled = [bool]$GsdOverlayPolicy.enabled
    }

    $mode = if ($GsdOverlayPolicy.mode) { [string]$GsdOverlayPolicy.mode } else { "off" }
    if ((-not $enabled) -or ($mode -eq "off")) {
        return [pscustomobject]@{
            enabled = $false
            mode = "off"
            task_applicable = $false
            grade_applicable = $false
            scope_applicable = $false
            enforcement = "none"
            reason = "policy_off"
            preserve_routing_assignment = $true
            preflight_should_apply = $false
            wave_contract_should_apply = $false
            should_apply_hook = $false
            artifacts = [pscustomobject]@{
                brownfield_directory = $null
                assumption_artifact = $null
                wave_artifact = $null
            }
        }
    }

    $taskAllow = @("planning")
    if ($GsdOverlayPolicy.task_allow) {
        $taskAllow = @($GsdOverlayPolicy.task_allow)
    }

    $gradeAllow = @("L", "XL")
    if ($GsdOverlayPolicy.grade_allow) {
        $gradeAllow = @($GsdOverlayPolicy.grade_allow)
    }

    $taskApplicable = ($taskAllow -contains $TaskType)
    $gradeApplicable = ($gradeAllow -contains $Grade)
    $scopeApplicable = ($taskApplicable -and $gradeApplicable)

    $preflightApply = $scopeApplicable

    $waveEnabled = $false
    $waveXlOnly = $true
    if ($GsdOverlayPolicy.wave_contract) {
        if ($GsdOverlayPolicy.wave_contract.enabled -ne $null) {
            $waveEnabled = [bool]$GsdOverlayPolicy.wave_contract.enabled
        }
        if ($GsdOverlayPolicy.wave_contract.xl_only -ne $null) {
            $waveXlOnly = [bool]$GsdOverlayPolicy.wave_contract.xl_only
        }
    }

    $waveTaskAllowed = ($TaskType -in @("planning", "coding"))
    $waveGradeAllowed = (($Grade -eq "XL") -or (-not $waveXlOnly))
    $waveApply = ($scopeApplicable -and $waveEnabled -and $waveTaskAllowed -and $waveGradeAllowed)

    $enforcement = "none"
    $reason = "outside_scope"
    if ($scopeApplicable) {
        $confirmGrades = @("XL")
        if ($GsdOverlayPolicy.assumption_gate -and $GsdOverlayPolicy.assumption_gate.confirm_required_for) {
            $confirmGrades = @($GsdOverlayPolicy.assumption_gate.confirm_required_for)
        }

        switch ($mode) {
            "shadow" {
                $enforcement = "advisory"
                $reason = "shadow_advisory"
            }
            "soft" {
                if ($confirmGrades -contains $Grade) {
                    $enforcement = "confirm_required"
                    $reason = "soft_confirm_scope_hit"
                } else {
                    $enforcement = "advisory"
                    $reason = "soft_advisory_outside_confirm_grade"
                }
            }
            "strict" {
                $enforcement = "required"
                $reason = "strict_required"
            }
            default {
                $enforcement = "advisory"
                $reason = "unknown_mode_advisory"
            }
        }
    }

    $preserveRoutingAssignment = $true
    if ($GsdOverlayPolicy.preserve_routing_assignment -ne $null) {
        $preserveRoutingAssignment = [bool]$GsdOverlayPolicy.preserve_routing_assignment
    }

    $brownfieldDirectory = $null
    if ($GsdOverlayPolicy.brownfield_context -and $GsdOverlayPolicy.brownfield_context.directory) {
        $brownfieldDirectory = [string]$GsdOverlayPolicy.brownfield_context.directory
    }

    $assumptionArtifact = if ($GsdOverlayPolicy.assumption_gate -and $GsdOverlayPolicy.assumption_gate.artifact) {
        [string]$GsdOverlayPolicy.assumption_gate.artifact
    } else {
        "assumptions.md"
    }

    $waveArtifact = if ($GsdOverlayPolicy.wave_contract -and $GsdOverlayPolicy.wave_contract.artifact) {
        [string]$GsdOverlayPolicy.wave_contract.artifact
    } else {
        "waves.json"
    }

    return [pscustomobject]@{
        enabled = $true
        mode = $mode
        task_applicable = $taskApplicable
        grade_applicable = $gradeApplicable
        scope_applicable = $scopeApplicable
        enforcement = $enforcement
        reason = $reason
        preserve_routing_assignment = $preserveRoutingAssignment
        preflight_should_apply = $preflightApply
        wave_contract_should_apply = $waveApply
        should_apply_hook = ($preflightApply -or $waveApply)
        artifacts = [pscustomobject]@{
            brownfield_directory = $brownfieldDirectory
            assumption_artifact = $assumptionArtifact
            wave_artifact = $waveArtifact
        }
    }
}

function Get-PromptOverlayAdvice {
    param(
        [string]$PromptLower,
        [string]$Grade,
        [string]$TaskType,
        [object]$PromptOverlayPolicy
    )

    if (-not $PromptOverlayPolicy) {
        return [pscustomobject]@{
            enabled = $false
            mode = "off"
            task_applicable = $false
            grade_applicable = $false
            scope_applicable = $false
            enforcement = "none"
            reason = "policy_missing"
            preserve_routing_assignment = $true
            prompt_signal_hit = $false
            doc_surface_hit = $false
            ambiguity_detected = $false
            confirm_required = $false
            should_apply_hook = $false
            should_search_prompts_first = $false
            recommended_skill = $null
            matched_intent_facets = @()
            facet_matches = [pscustomobject]@{}
            prompt_signal_matches = @()
            doc_surface_matches = @()
        }
    }

    $enabled = $true
    if ($PromptOverlayPolicy.enabled -ne $null) {
        $enabled = [bool]$PromptOverlayPolicy.enabled
    }

    $mode = if ($PromptOverlayPolicy.mode) { [string]$PromptOverlayPolicy.mode } else { "off" }
    if ((-not $enabled) -or ($mode -eq "off")) {
        return [pscustomobject]@{
            enabled = $false
            mode = "off"
            task_applicable = $false
            grade_applicable = $false
            scope_applicable = $false
            enforcement = "none"
            reason = "policy_off"
            preserve_routing_assignment = $true
            prompt_signal_hit = $false
            doc_surface_hit = $false
            ambiguity_detected = $false
            confirm_required = $false
            should_apply_hook = $false
            should_search_prompts_first = $false
            recommended_skill = $null
            matched_intent_facets = @()
            facet_matches = [pscustomobject]@{}
            prompt_signal_matches = @()
            doc_surface_matches = @()
        }
    }

    $taskAllow = @("planning", "research")
    if ($PromptOverlayPolicy.task_allow) {
        $taskAllow = @($PromptOverlayPolicy.task_allow)
    }

    $gradeAllow = @("M", "L", "XL")
    if ($PromptOverlayPolicy.grade_allow) {
        $gradeAllow = @($PromptOverlayPolicy.grade_allow)
    }

    $taskApplicable = ($taskAllow -contains $TaskType)
    $gradeApplicable = ($gradeAllow -contains $Grade)
    $scopeApplicable = ($taskApplicable -and $gradeApplicable)

    $promptSignalKeywords = @("prompt", "prompts.chat", "提示词", "system prompt")
    if ($PromptOverlayPolicy.prompt_signal_keywords) {
        $promptSignalKeywords = @($PromptOverlayPolicy.prompt_signal_keywords)
    }

    $docSurfaceKeywords = @("api reference", "official docs", "responses api", "chat completions", "model limits", "官方文档")
    if ($PromptOverlayPolicy.doc_surface_keywords) {
        $docSurfaceKeywords = @($PromptOverlayPolicy.doc_surface_keywords)
    }

    $promptSignalMatches = @()
    foreach ($kw in $promptSignalKeywords) {
        if (Test-KeywordHit -PromptLower $PromptLower -Keyword ([string]$kw)) {
            $promptSignalMatches += [string]$kw
        }
    }

    $docSurfaceMatches = @()
    foreach ($kw in $docSurfaceKeywords) {
        if (Test-KeywordHit -PromptLower $PromptLower -Keyword ([string]$kw)) {
            $docSurfaceMatches += [string]$kw
        }
    }

    $promptSignalHit = ($promptSignalMatches.Count -gt 0)
    $docSurfaceHit = ($docSurfaceMatches.Count -gt 0)

    $facetMatches = [ordered]@{}
    $matchedIntentFacets = @()
    if ($PromptOverlayPolicy.intent_facets) {
        foreach ($facetName in @($PromptOverlayPolicy.intent_facets.PSObject.Properties.Name)) {
            $hits = @()
            foreach ($kw in @($PromptOverlayPolicy.intent_facets.$facetName)) {
                if (Test-KeywordHit -PromptLower $PromptLower -Keyword ([string]$kw)) {
                    $hits += [string]$kw
                }
            }

            $facetMatches[[string]$facetName] = @($hits)
            if ($hits.Count -gt 0) {
                $matchedIntentFacets += [string]$facetName
            }
        }
    }

    $explicitPromptAssetIntent = ($matchedIntentFacets.Count -gt 0)
    $ambiguityDetected = ($promptSignalHit -and $docSurfaceHit -and (-not $explicitPromptAssetIntent))

    $confirmScopeHit = $scopeApplicable
    if ($PromptOverlayPolicy.confirm_scope) {
        $scopeGrades = @()
        $scopeTasks = @()
        if ($PromptOverlayPolicy.confirm_scope.grades) {
            $scopeGrades = @($PromptOverlayPolicy.confirm_scope.grades)
        }
        if ($PromptOverlayPolicy.confirm_scope.task_types) {
            $scopeTasks = @($PromptOverlayPolicy.confirm_scope.task_types)
        }

        if ($scopeGrades.Count -gt 0 -and -not ($scopeGrades -contains $Grade)) {
            $confirmScopeHit = $false
        }
        if ($scopeTasks.Count -gt 0 -and -not ($scopeTasks -contains $TaskType)) {
            $confirmScopeHit = $false
        }
    }

    $enforcement = "none"
    $reason = "outside_scope"
    if ($scopeApplicable) {
        switch ($mode) {
            "shadow" {
                $enforcement = "advisory"
                $reason = "shadow_advisory"
            }
            "soft" {
                if ($ambiguityDetected -and $confirmScopeHit) {
                    $enforcement = "confirm_required"
                    $reason = "soft_confirm_doc_collision"
                } elseif ($explicitPromptAssetIntent) {
                    $enforcement = "advisory"
                    $reason = "soft_advisory_prompt_intent"
                } elseif ($promptSignalHit) {
                    $enforcement = "advisory"
                    $reason = "soft_advisory_prompt_signal"
                } else {
                    $enforcement = "advisory"
                    $reason = "soft_advisory_scope_only"
                }
            }
            "strict" {
                if ($ambiguityDetected -and $confirmScopeHit) {
                    $enforcement = "confirm_required"
                    $reason = "strict_confirm_doc_collision"
                } elseif ($promptSignalHit) {
                    $enforcement = "required"
                    $reason = "strict_required_prompt_signal"
                } else {
                    $enforcement = "required"
                    $reason = "strict_required_scope_only"
                }
            }
            default {
                $enforcement = "advisory"
                $reason = "unknown_mode_advisory"
            }
        }
    }

    $preserveRoutingAssignment = $true
    if ($PromptOverlayPolicy.preserve_routing_assignment -ne $null) {
        $preserveRoutingAssignment = [bool]$PromptOverlayPolicy.preserve_routing_assignment
    }

    $recommendedSkill = $null
    if ($explicitPromptAssetIntent) {
        $recommendedSkill = "prompt-lookup"
    } elseif ($docSurfaceHit) {
        $recommendedSkill = "documentation-lookup"
    }

    return [pscustomobject]@{
        enabled = $true
        mode = $mode
        task_applicable = $taskApplicable
        grade_applicable = $gradeApplicable
        scope_applicable = $scopeApplicable
        enforcement = $enforcement
        reason = $reason
        preserve_routing_assignment = $preserveRoutingAssignment
        prompt_signal_hit = $promptSignalHit
        doc_surface_hit = $docSurfaceHit
        ambiguity_detected = $ambiguityDetected
        confirm_required = (($enforcement -eq "confirm_required") -or ($enforcement -eq "required"))
        should_apply_hook = ($scopeApplicable -and ($promptSignalHit -or $explicitPromptAssetIntent))
        should_search_prompts_first = ($scopeApplicable -and $explicitPromptAssetIntent)
        recommended_skill = $recommendedSkill
        matched_intent_facets = @($matchedIntentFacets)
        facet_matches = [pscustomobject]$facetMatches
        prompt_signal_matches = @($promptSignalMatches)
        doc_surface_matches = @($docSurfaceMatches)
    }
}

function Get-MemoryGovernanceAdvice {
    param(
        [string]$Grade,
        [string]$TaskType,
        [object]$MemoryGovernancePolicy
    )

    if (-not $MemoryGovernancePolicy) {
        return [pscustomobject]@{
            enabled = $false
            mode = "off"
            task_applicable = $false
            grade_applicable = $false
            scope_applicable = $false
            enforcement = "none"
            reason = "policy_missing"
            preserve_routing_assignment = $true
            primary_memory = $null
            project_decision_memory = $null
            short_term_memory = $null
            long_term_memory = $null
            disabled_systems = @()
            governance_contract = [pscustomobject]@{}
            role_boundaries = [pscustomobject]@{}
        }
    }

    $enabled = $true
    if ($MemoryGovernancePolicy.enabled -ne $null) {
        $enabled = [bool]$MemoryGovernancePolicy.enabled
    }

    $mode = if ($MemoryGovernancePolicy.mode) { [string]$MemoryGovernancePolicy.mode } else { "off" }
    if ((-not $enabled) -or ($mode -eq "off")) {
        return [pscustomobject]@{
            enabled = $false
            mode = "off"
            task_applicable = $false
            grade_applicable = $false
            scope_applicable = $false
            enforcement = "none"
            reason = "policy_off"
            preserve_routing_assignment = $true
            primary_memory = $null
            project_decision_memory = $null
            short_term_memory = $null
            long_term_memory = $null
            disabled_systems = @()
            governance_contract = [pscustomobject]@{}
            role_boundaries = [pscustomobject]@{}
        }
    }

    $taskAllow = @("planning", "coding", "review", "debug", "research")
    if ($MemoryGovernancePolicy.task_allow) {
        $taskAllow = @($MemoryGovernancePolicy.task_allow)
    }

    $gradeAllow = @("M", "L", "XL")
    if ($MemoryGovernancePolicy.grade_allow) {
        $gradeAllow = @($MemoryGovernancePolicy.grade_allow)
    }

    $taskApplicable = ($taskAllow -contains $TaskType)
    $gradeApplicable = ($gradeAllow -contains $Grade)
    $scopeApplicable = ($taskApplicable -and $gradeApplicable)

    $taskDefaults = $null
    if ($MemoryGovernancePolicy.defaults_by_task) {
        $taskKeys = @($MemoryGovernancePolicy.defaults_by_task.PSObject.Properties.Name)
        if ($taskKeys -contains $TaskType) {
            $taskDefaults = $MemoryGovernancePolicy.defaults_by_task.$TaskType
        }
    }

    $primaryMemory = if ($taskDefaults -and $taskDefaults.primary) { [string]$taskDefaults.primary } else { "state_store" }
    $projectDecisionMemory = if ($taskDefaults -and $taskDefaults.project_decisions) { [string]$taskDefaults.project_decisions } else { "serena" }
    $shortTermMemory = if ($taskDefaults -and $taskDefaults.short_cache) { [string]$taskDefaults.short_cache } else { "ruflo" }
    $longTermMemory = if ($taskDefaults -and $taskDefaults.long_term) { [string]$taskDefaults.long_term } else { "cognee" }

    $disabledSystems = @()
    if ($MemoryGovernancePolicy.role_boundaries -and $MemoryGovernancePolicy.role_boundaries.episodic_memory) {
        $episodicBoundary = $MemoryGovernancePolicy.role_boundaries.episodic_memory
        if ($episodicBoundary.status -eq "disabled") {
            if ($episodicBoundary.canonical_name) {
                $disabledSystems += [string]$episodicBoundary.canonical_name
            } else {
                $disabledSystems += "episodic-memory"
            }
        }
    }

    $enforcement = "none"
    $reason = "outside_scope"
    if ($scopeApplicable) {
        switch ($mode) {
            "shadow" {
                $enforcement = "advisory"
                $reason = "shadow_advisory"
            }
            "soft" {
                $enforcement = "advisory"
                $reason = "soft_advisory"
            }
            "strict" {
                $enforcement = "required"
                $reason = "strict_required"
            }
            default {
                $enforcement = "advisory"
                $reason = "unknown_mode_advisory"
            }
        }
    }

    $preserveRoutingAssignment = $true
    if ($MemoryGovernancePolicy.preserve_routing_assignment -ne $null) {
        $preserveRoutingAssignment = [bool]$MemoryGovernancePolicy.preserve_routing_assignment
    }

    $governanceContract = [ordered]@{
        state_store = "session_state_only"
        serena = "explicit_project_decisions_only"
        ruflo = "short_term_vector_cache_only"
        cognee = "long_term_graph_memory_only"
        "episodic-memory" = "disabled"
    }

    $roleBoundaries = [pscustomobject]@{}
    if ($MemoryGovernancePolicy.role_boundaries) {
        $roleBoundaries = $MemoryGovernancePolicy.role_boundaries
    }

    return [pscustomobject]@{
        enabled = $true
        mode = $mode
        task_applicable = $taskApplicable
        grade_applicable = $gradeApplicable
        scope_applicable = $scopeApplicable
        enforcement = $enforcement
        reason = $reason
        preserve_routing_assignment = $preserveRoutingAssignment
        primary_memory = $primaryMemory
        project_decision_memory = $projectDecisionMemory
        short_term_memory = $shortTermMemory
        long_term_memory = $longTermMemory
        disabled_systems = @($disabledSystems | Select-Object -Unique)
        governance_contract = [pscustomobject]$governanceContract
        role_boundaries = $roleBoundaries
    }
}

function Get-PathCandidatesFromPrompt {
    param(
        [string]$Prompt,
        [string[]]$SupportedExtensions
    )

    $paths = @()
    if (-not $Prompt -or -not $SupportedExtensions -or $SupportedExtensions.Count -eq 0) {
        return @()
    }

    $escapedExt = @($SupportedExtensions | ForEach-Object { [Regex]::Escape(([string]$_).ToLowerInvariant()) } | Sort-Object -Unique)
    if ($escapedExt.Count -eq 0) {
        return @()
    }

    $extPattern = ($escapedExt | Sort-Object { $_.Length } -Descending) -join "|"
    $regexes = @(
        [Regex]::new('"([^"]+\.(?:' + $extPattern + '))"', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase),
        [Regex]::new("'([^']+\.(?:$extPattern))'", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase),
        [Regex]::new('([^\s"'';,()]+?\.(?:' + $extPattern + '))', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    )

    foreach ($regex in $regexes) {
        $matches = $regex.Matches($Prompt)
        foreach ($m in $matches) {
            if ($m.Groups.Count -lt 2) { continue }
            $candidate = [string]$m.Groups[1].Value
            if (-not $candidate) { continue }
            $normalized = $candidate.Trim().Trim('"', "'").TrimEnd('.', ',', ';', ')', ']')
            if ($normalized) {
                $paths += $normalized
            }
        }
    }

    return @($paths | Select-Object -Unique)
}

function Resolve-ExistingPathCandidates {
    param(
        [string[]]$PathCandidates,
        [bool]$WorkspaceProbeEnabled,
        [int]$WorkspaceProbeLimit,
        [string[]]$WorkspaceProbeExtensions
    )

    $resolvedPaths = @()
    $cwd = (Get-Location).Path

    foreach ($candidate in @($PathCandidates)) {
        $raw = [Environment]::ExpandEnvironmentVariables([string]$candidate)
        if (-not $raw) { continue }

        $tries = @()
        if ([System.IO.Path]::IsPathRooted($raw)) {
            $tries += $raw
        } else {
            $tries += (Join-Path -Path $cwd -ChildPath $raw)
            $tries += $raw
        }

        foreach ($tryPath in $tries) {
            if (-not $tryPath) { continue }
            if (Test-Path -LiteralPath $tryPath -PathType Leaf) {
                $resolved = (Resolve-Path -LiteralPath $tryPath -ErrorAction SilentlyContinue).Path
                if ($resolved) {
                    $resolvedPaths += $resolved
                    break
                }
            }
        }
    }

    if ($resolvedPaths.Count -eq 0 -and $WorkspaceProbeEnabled) {
        $limit = if ($WorkspaceProbeLimit -gt 0) { $WorkspaceProbeLimit } else { 3 }
        $probeExt = @($WorkspaceProbeExtensions | ForEach-Object { [string]$_ } | Where-Object { $_ })
        if ($probeExt.Count -gt 0) {
            foreach ($ext in $probeExt) {
                $pattern = "*.$ext"
                $hits = Get-ChildItem -Path $cwd -File -Filter $pattern -ErrorAction SilentlyContinue | Select-Object -First $limit
                foreach ($h in $hits) {
                    if ($h -and $h.FullName) {
                        $resolvedPaths += [string]$h.FullName
                    }
                }
                if ($resolvedPaths.Count -ge $limit) { break }
            }
        }
    }

    return @($resolvedPaths | Select-Object -Unique)
}

function Get-DetectedExtension {
    param(
        [string]$Path,
        [string[]]$SupportedExtensions
    )

    $name = [System.IO.Path]::GetFileName([string]$Path).ToLowerInvariant()
    foreach ($ext in @($SupportedExtensions | Sort-Object { $_.Length } -Descending)) {
        $needle = "." + ([string]$ext).ToLowerInvariant()
        if ($name.EndsWith($needle)) {
            return ([string]$ext).ToLowerInvariant()
        }
    }

    return [System.IO.Path]::GetExtension($name).TrimStart('.').ToLowerInvariant()
}

function Test-WorkbookExtension {
    param([string]$Extension)
    return ($Extension -in @("xlsx", "xlsm", "xls"))
}

function Test-CsvLikeExtension {
    param([string]$Extension)
    return ($Extension -in @(
            "csv", "tsv", "tab", "psv", "ssv", "scsv",
            "csv.gz", "tsv.gz", "tab.gz", "psv.gz", "ssv.gz", "scsv.gz",
            "csv.zst", "tsv.zst", "tab.zst"
        ))
}

function Get-DelimiterHint {
    param(
        [string]$Extension,
        [string]$HeaderLine
    )

    if ($Extension -match "^(tsv|tab)(\.|$)") { return "`t" }
    if ($Extension -match "^psv(\.|$)") { return "|" }
    if ($Extension -match "^(ssv|scsv)(\.|$)") { return ";" }

    $candidates = @(",", ";", "`t", "|")
    $best = ","
    $bestCount = -1
    foreach ($d in $candidates) {
        $count = ([string]$HeaderLine).Split($d).Count
        if ($count -gt $bestCount) {
            $best = $d
            $bestCount = $count
        }
    }

    return $best
}

function Get-DelimitedFileSampleStats {
    param(
        [string]$Path,
        [string]$Extension,
        [int64]$FileSizeBytes,
        [int]$MaxLines,
        [int]$MaxChars
    )

    $result = [ordered]@{
        columns = $null
        delimiter = $null
        sample_rows = 0
        sample_bytes = 0
        estimated_rows = $null
    }

    if ($Extension -match "\.(gz|zst)$") {
        return [pscustomobject]$result
    }

    $lineCap = if ($MaxLines -gt 0) { $MaxLines } else { 200 }
    $charCap = if ($MaxChars -gt 0) { $MaxChars } else { 200000 }

    $rawLines = @()
    try {
        $rawLines = @(Get-Content -LiteralPath $Path -TotalCount $lineCap -Encoding UTF8 -ErrorAction Stop)
    } catch {
        return [pscustomobject]$result
    }

    if ($rawLines.Count -eq 0) {
        return [pscustomobject]$result
    }

    $lines = @()
    $chars = 0
    foreach ($line in $rawLines) {
        $text = [string]$line
        if (($chars + $text.Length + 1) -gt $charCap -and $lines.Count -gt 0) {
            break
        }
        $lines += $text
        $chars += ($text.Length + 1)
    }

    if ($lines.Count -eq 0) {
        return [pscustomobject]$result
    }

    $header = [string]$lines[0]
    $delimiter = Get-DelimiterHint -Extension $Extension -HeaderLine $header
    $splitPattern = [Regex]::Escape($delimiter)
    $columns = if ($header.Length -gt 0) { ([Regex]::Split($header, $splitPattern, [System.Text.RegularExpressions.RegexOptions]::None)).Count } else { 0 }
    $sampleRows = [Math]::Max(0, $lines.Count - 1)

    $sampleText = $lines -join "`n"
    $sampleBytes = [System.Text.Encoding]::UTF8.GetByteCount($sampleText)
    $estimatedRows = $null
    if ($sampleRows -gt 0 -and $sampleBytes -gt 0 -and $FileSizeBytes -gt 0) {
        $estimatedRows = [int64][Math]::Round(([double]$FileSizeBytes / [double]$sampleBytes) * [double]$sampleRows, 0)
    }

    $result.columns = $columns
    $result.delimiter = $delimiter
    $result.sample_rows = $sampleRows
    $result.sample_bytes = $sampleBytes
    $result.estimated_rows = $estimatedRows
    return [pscustomobject]$result
}

function Get-DataScaleOverlayAdvice {
    param(
        [string]$Prompt,
        [string]$PromptLower,
        [string]$Grade,
        [string]$TaskType,
        [string]$RouteMode,
        [string]$SelectedPackId,
        [string]$SelectedSkill,
        [string[]]$PackCandidates,
        [object]$DataScaleOverlayPolicy
    )

    if (-not $DataScaleOverlayPolicy) {
        return [pscustomobject]@{
            enabled = $false
            mode = "off"
            task_applicable = $false
            grade_applicable = $false
            pack_applicable = $false
            skill_applicable = $false
            scope_applicable = $false
            enforcement = "none"
            reason = "policy_missing"
            preserve_routing_assignment = $true
            paths_detected = @()
            paths_existing = @()
            probe_file_count = 0
            probe_primary_file = $null
            probe_file_analysis = @()
            data_scale = "unknown"
            size_bytes = 0
            estimated_rows = $null
            column_count = $null
            is_workbook = $false
            is_csv_like = $false
            is_compressed = $false
            operation_prefers_xan = $false
            recommended_skill = $null
            confidence = 0.0
            confirm_required = $false
            auto_override = $false
            override_candidate_allowed = $false
        }
    }

    $enabled = $true
    if ($DataScaleOverlayPolicy.enabled -ne $null) {
        $enabled = [bool]$DataScaleOverlayPolicy.enabled
    }
    $mode = if ($DataScaleOverlayPolicy.mode) { [string]$DataScaleOverlayPolicy.mode } else { "off" }
    if ((-not $enabled) -or ($mode -eq "off")) {
        return [pscustomobject]@{
            enabled = $false
            mode = "off"
            task_applicable = $false
            grade_applicable = $false
            pack_applicable = $false
            skill_applicable = $false
            scope_applicable = $false
            enforcement = "none"
            reason = "policy_off"
            preserve_routing_assignment = $true
            paths_detected = @()
            paths_existing = @()
            probe_file_count = 0
            probe_primary_file = $null
            probe_file_analysis = @()
            data_scale = "unknown"
            size_bytes = 0
            estimated_rows = $null
            column_count = $null
            is_workbook = $false
            is_csv_like = $false
            is_compressed = $false
            operation_prefers_xan = $false
            recommended_skill = $null
            confidence = 0.0
            confirm_required = $false
            auto_override = $false
            override_candidate_allowed = $false
        }
    }

    $taskAllow = @("coding", "research")
    if ($DataScaleOverlayPolicy.task_allow) {
        $taskAllow = @($DataScaleOverlayPolicy.task_allow)
    }
    $gradeAllow = @("M", "L", "XL")
    if ($DataScaleOverlayPolicy.grade_allow) {
        $gradeAllow = @($DataScaleOverlayPolicy.grade_allow)
    }

    $packAllow = @()
    if ($DataScaleOverlayPolicy.monitor -and $DataScaleOverlayPolicy.monitor.pack_allow) {
        $packAllow = @($DataScaleOverlayPolicy.monitor.pack_allow)
    }
    $skillAllow = @()
    if ($DataScaleOverlayPolicy.monitor -and $DataScaleOverlayPolicy.monitor.skill_allow) {
        $skillAllow = @($DataScaleOverlayPolicy.monitor.skill_allow)
    }
    $supportedExt = @("csv", "tsv", "tab", "psv", "ssv", "scsv", "csv.gz", "tsv.gz", "tab.gz", "psv.gz", "ssv.gz", "scsv.gz", "csv.zst", "tsv.zst", "tab.zst", "xlsx", "xlsm", "xls")
    if ($DataScaleOverlayPolicy.monitor -and $DataScaleOverlayPolicy.monitor.supported_extensions) {
        $supportedExt = @($DataScaleOverlayPolicy.monitor.supported_extensions)
    }

    $taskApplicable = ($taskAllow -contains $TaskType)
    $gradeApplicable = ($gradeAllow -contains $Grade)
    $packApplicable = if ($packAllow.Count -gt 0) { $packAllow -contains $SelectedPackId } else { $true }
    $skillApplicable = if ($skillAllow.Count -gt 0) { $skillAllow -contains $SelectedSkill } else { $true }
    $scopeApplicable = ($taskApplicable -and $gradeApplicable -and $packApplicable -and $skillApplicable)

    $preserveRoutingAssignment = $true
    if ($DataScaleOverlayPolicy.preserve_routing_assignment -ne $null) {
        $preserveRoutingAssignment = [bool]$DataScaleOverlayPolicy.preserve_routing_assignment
    }

    if (-not $scopeApplicable) {
        return [pscustomobject]@{
            enabled = $true
            mode = $mode
            task_applicable = $taskApplicable
            grade_applicable = $gradeApplicable
            pack_applicable = $packApplicable
            skill_applicable = $skillApplicable
            scope_applicable = $false
            enforcement = "none"
            reason = "outside_scope"
            preserve_routing_assignment = $preserveRoutingAssignment
            paths_detected = @()
            paths_existing = @()
            probe_file_count = 0
            probe_primary_file = $null
            probe_file_analysis = @()
            data_scale = "unknown"
            size_bytes = 0
            estimated_rows = $null
            column_count = $null
            is_workbook = $false
            is_csv_like = $false
            is_compressed = $false
            operation_prefers_xan = $false
            recommended_skill = $null
            confidence = 0.0
            confirm_required = $false
            auto_override = $false
            override_candidate_allowed = $false
        }
    }

    $probeEnabled = $true
    $extractFromPrompt = $true
    $workspaceProbeWhenNoPath = $false
    $workspaceProbeLimit = 3
    $workspaceProbeExtensions = @("csv", "tsv", "tab", "psv", "ssv", "scsv", "xlsx", "xlsm", "xls")
    $sampleMaxLines = 200
    $sampleMaxChars = 200000

    if ($DataScaleOverlayPolicy.path_probe) {
        if ($DataScaleOverlayPolicy.path_probe.enabled -ne $null) {
            $probeEnabled = [bool]$DataScaleOverlayPolicy.path_probe.enabled
        }
        if ($DataScaleOverlayPolicy.path_probe.extract_from_prompt -ne $null) {
            $extractFromPrompt = [bool]$DataScaleOverlayPolicy.path_probe.extract_from_prompt
        }
        if ($DataScaleOverlayPolicy.path_probe.workspace_probe_when_no_path -ne $null) {
            $workspaceProbeWhenNoPath = [bool]$DataScaleOverlayPolicy.path_probe.workspace_probe_when_no_path
        }
        if ($DataScaleOverlayPolicy.path_probe.workspace_probe_limit -ne $null) {
            $workspaceProbeLimit = [int]$DataScaleOverlayPolicy.path_probe.workspace_probe_limit
        }
        if ($DataScaleOverlayPolicy.path_probe.workspace_probe_extensions) {
            $workspaceProbeExtensions = @($DataScaleOverlayPolicy.path_probe.workspace_probe_extensions)
        }
        if ($DataScaleOverlayPolicy.path_probe.read_sample_max_lines -ne $null) {
            $sampleMaxLines = [int]$DataScaleOverlayPolicy.path_probe.read_sample_max_lines
        }
        if ($DataScaleOverlayPolicy.path_probe.read_sample_max_chars -ne $null) {
            $sampleMaxChars = [int]$DataScaleOverlayPolicy.path_probe.read_sample_max_chars
        }
    }

    if (-not $probeEnabled) {
        return [pscustomobject]@{
            enabled = $true
            mode = $mode
            task_applicable = $taskApplicable
            grade_applicable = $gradeApplicable
            pack_applicable = $packApplicable
            skill_applicable = $skillApplicable
            scope_applicable = $true
            enforcement = "advisory"
            reason = "probe_disabled"
            preserve_routing_assignment = $preserveRoutingAssignment
            paths_detected = @()
            paths_existing = @()
            probe_file_count = 0
            probe_primary_file = $null
            probe_file_analysis = @()
            data_scale = "unknown"
            size_bytes = 0
            estimated_rows = $null
            column_count = $null
            is_workbook = $false
            is_csv_like = $false
            is_compressed = $false
            operation_prefers_xan = $false
            recommended_skill = $null
            confidence = 0.0
            confirm_required = $false
            auto_override = $false
            override_candidate_allowed = $false
        }
    }

    $pathsDetected = @()
    if ($extractFromPrompt) {
        $pathsDetected = Get-PathCandidatesFromPrompt -Prompt $Prompt -SupportedExtensions $supportedExt
    }
    $pathsExisting = Resolve-ExistingPathCandidates -PathCandidates $pathsDetected -WorkspaceProbeEnabled $workspaceProbeWhenNoPath -WorkspaceProbeLimit $workspaceProbeLimit -WorkspaceProbeExtensions $workspaceProbeExtensions

    if ($pathsExisting.Count -eq 0) {
        return [pscustomobject]@{
            enabled = $true
            mode = $mode
            task_applicable = $taskApplicable
            grade_applicable = $gradeApplicable
            pack_applicable = $packApplicable
            skill_applicable = $skillApplicable
            scope_applicable = $true
            enforcement = "advisory"
            reason = "no_existing_data_path"
            preserve_routing_assignment = $preserveRoutingAssignment
            paths_detected = @($pathsDetected)
            paths_existing = @()
            probe_file_count = 0
            probe_primary_file = $null
            probe_file_analysis = @()
            data_scale = "unknown"
            size_bytes = 0
            estimated_rows = $null
            column_count = $null
            is_workbook = $false
            is_csv_like = $false
            is_compressed = $false
            operation_prefers_xan = $false
            recommended_skill = $null
            confidence = 0.0
            confirm_required = $false
            auto_override = $false
            override_candidate_allowed = $false
        }
    }

    $fileAnalysis = @()
    foreach ($path in $pathsExisting) {
        $item = $null
        try {
            $item = Get-Item -LiteralPath $path -ErrorAction Stop
        } catch {
            continue
        }
        if (-not $item) { continue }

        $ext = Get-DetectedExtension -Path $item.FullName -SupportedExtensions $supportedExt
        $isWorkbook = Test-WorkbookExtension -Extension $ext
        $isCsvLike = Test-CsvLikeExtension -Extension $ext
        $isCompressed = ($ext -match "\.(gz|zst)$")

        $columns = $null
        $estimatedRows = $null
        $sampleRows = 0
        if ($isCsvLike -and -not $isCompressed) {
            $sample = Get-DelimitedFileSampleStats -Path $item.FullName -Extension $ext -FileSizeBytes ([int64]$item.Length) -MaxLines $sampleMaxLines -MaxChars $sampleMaxChars
            $columns = $sample.columns
            $estimatedRows = $sample.estimated_rows
            $sampleRows = $sample.sample_rows
        }

        $fileAnalysis += [pscustomobject]@{
            path = [string]$item.FullName
            size_bytes = [int64]$item.Length
            extension = $ext
            is_workbook = $isWorkbook
            is_csv_like = $isCsvLike
            is_compressed = $isCompressed
            columns = $columns
            estimated_rows = $estimatedRows
            sample_rows = $sampleRows
        }
    }

    if ($fileAnalysis.Count -eq 0) {
        return [pscustomobject]@{
            enabled = $true
            mode = $mode
            task_applicable = $taskApplicable
            grade_applicable = $gradeApplicable
            pack_applicable = $packApplicable
            skill_applicable = $skillApplicable
            scope_applicable = $true
            enforcement = "advisory"
            reason = "probe_failed"
            preserve_routing_assignment = $preserveRoutingAssignment
            paths_detected = @($pathsDetected)
            paths_existing = @($pathsExisting)
            probe_file_count = 0
            probe_primary_file = $null
            probe_file_analysis = @()
            data_scale = "unknown"
            size_bytes = 0
            estimated_rows = $null
            column_count = $null
            is_workbook = $false
            is_csv_like = $false
            is_compressed = $false
            operation_prefers_xan = $false
            recommended_skill = $null
            confidence = 0.0
            confirm_required = $false
            auto_override = $false
            override_candidate_allowed = $false
        }
    }

    $primary = $fileAnalysis | Sort-Object -Property @{ Expression = "size_bytes"; Descending = $true } | Select-Object -First 1
    $sizeBytes = [int64]$primary.size_bytes
    $estimatedRows = if ($primary.estimated_rows -ne $null) { [int64]$primary.estimated_rows } else { $null }
    $columnCount = if ($primary.columns -ne $null) { [int]$primary.columns } else { $null }
    $isWorkbook = [bool]$primary.is_workbook
    $isCsvLike = [bool]$primary.is_csv_like
    $isCompressed = [bool]$primary.is_compressed

    $mediumSize = 52428800
    $largeSize = 314572800
    $mediumRows = 500000
    $largeRows = 3000000
    $confirmMin = 0.6
    $overrideMin = 0.85

    if ($DataScaleOverlayPolicy.thresholds) {
        if ($DataScaleOverlayPolicy.thresholds.medium_size_bytes -ne $null) { $mediumSize = [int64]$DataScaleOverlayPolicy.thresholds.medium_size_bytes }
        if ($DataScaleOverlayPolicy.thresholds.large_size_bytes -ne $null) { $largeSize = [int64]$DataScaleOverlayPolicy.thresholds.large_size_bytes }
        if ($DataScaleOverlayPolicy.thresholds.medium_estimated_rows -ne $null) { $mediumRows = [int64]$DataScaleOverlayPolicy.thresholds.medium_estimated_rows }
        if ($DataScaleOverlayPolicy.thresholds.large_estimated_rows -ne $null) { $largeRows = [int64]$DataScaleOverlayPolicy.thresholds.large_estimated_rows }
        if ($DataScaleOverlayPolicy.thresholds.confirm_confidence_min -ne $null) { $confirmMin = [double]$DataScaleOverlayPolicy.thresholds.confirm_confidence_min }
        if ($DataScaleOverlayPolicy.thresholds.high_confidence_for_override -ne $null) { $overrideMin = [double]$DataScaleOverlayPolicy.thresholds.high_confidence_for_override }
    }

    $isLargeBySize = ($sizeBytes -ge $largeSize)
    $isLargeByRows = ($estimatedRows -ne $null -and $estimatedRows -ge $largeRows)
    $isMediumBySize = ($sizeBytes -ge $mediumSize)
    $isMediumByRows = ($estimatedRows -ne $null -and $estimatedRows -ge $mediumRows)

    $dataScale = "small"
    if ($isLargeBySize -or $isLargeByRows) {
        $dataScale = "large"
    } elseif ($isMediumBySize -or $isMediumByRows) {
        $dataScale = "medium"
    }

    $csvDefaultSkill = "spreadsheet"
    $csvLargeSkill = "xan"
    $workbookSkill = "xlsx"
    $workbookAnalysisSkill = "excel-analysis"
    $operationKeywords = @("join", "groupby", "dedup", "frequency", "sort", "filter", "pipeline", "aggregate", "window", "parallel", "merge", "split", "分组", "去重", "聚合", "连接", "排序", "过滤", "管道", "流式")
    if ($DataScaleOverlayPolicy.recommendations) {
        if ($DataScaleOverlayPolicy.recommendations.csv_default_skill) { $csvDefaultSkill = [string]$DataScaleOverlayPolicy.recommendations.csv_default_skill }
        if ($DataScaleOverlayPolicy.recommendations.csv_large_skill) { $csvLargeSkill = [string]$DataScaleOverlayPolicy.recommendations.csv_large_skill }
        if ($DataScaleOverlayPolicy.recommendations.workbook_skill) { $workbookSkill = [string]$DataScaleOverlayPolicy.recommendations.workbook_skill }
        if ($DataScaleOverlayPolicy.recommendations.workbook_analysis_skill) { $workbookAnalysisSkill = [string]$DataScaleOverlayPolicy.recommendations.workbook_analysis_skill }
        if ($DataScaleOverlayPolicy.recommendations.operations_preferring_xan) {
            $operationKeywords = @($DataScaleOverlayPolicy.recommendations.operations_preferring_xan)
        }
    }

    $operationPrefersXan = $false
    foreach ($kw in $operationKeywords) {
        if (Test-KeywordHit -PromptLower $PromptLower -Keyword ([string]$kw)) {
            $operationPrefersXan = $true
            break
        }
    }

    $recommendedSkill = $null
    $confidence = 0.0
    $reason = "no_recommendation"
    if ($isWorkbook) {
        $pivotLike = (Test-KeywordHit -PromptLower $PromptLower -Keyword "pivot") -or (Test-KeywordHit -PromptLower $PromptLower -Keyword "pivot table") -or (Test-KeywordHit -PromptLower $PromptLower -Keyword "数据透视") -or (Test-KeywordHit -PromptLower $PromptLower -Keyword "透视表")
        $recommendedSkill = if ($pivotLike) { $workbookAnalysisSkill } else { $workbookSkill }
        $confidence = 0.9
        $reason = "workbook_detected"
    } elseif ($isCsvLike) {
        if ($dataScale -eq "large") {
            $recommendedSkill = $csvLargeSkill
            $confidence = 0.9
            $reason = "csv_large_detected"
        } elseif ($dataScale -eq "medium" -and $operationPrefersXan) {
            $recommendedSkill = $csvLargeSkill
            $confidence = 0.72
            $reason = "csv_medium_operation_prefers_xan"
        } else {
            $recommendedSkill = $csvDefaultSkill
            $confidence = 0.68
            $reason = "csv_default_path"
        }
    } else {
        $reason = "unsupported_extension"
    }

    $overrideCandidateAllowed = ($recommendedSkill -and ($PackCandidates -contains $recommendedSkill))
    $enforcement = "advisory"
    $confirmRequired = $false
    $autoOverride = $false

    if ($recommendedSkill -and $overrideCandidateAllowed -and $SelectedSkill -and ($recommendedSkill -ne $SelectedSkill)) {
        switch ($mode) {
            "soft" {
                if ($confidence -ge $confirmMin) {
                    $enforcement = "confirm_required"
                    $confirmRequired = $true
                }
            }
            "strict" {
                if ($confidence -ge $overrideMin) {
                    $enforcement = "required"
                    $autoOverride = $true
                } elseif ($confidence -ge $confirmMin) {
                    $enforcement = "confirm_required"
                    $confirmRequired = $true
                }
            }
        }
    }

    return [pscustomobject]@{
        enabled = $true
        mode = $mode
        task_applicable = $taskApplicable
        grade_applicable = $gradeApplicable
        pack_applicable = $packApplicable
        skill_applicable = $skillApplicable
        scope_applicable = $scopeApplicable
        enforcement = $enforcement
        reason = $reason
        preserve_routing_assignment = $preserveRoutingAssignment
        paths_detected = @($pathsDetected)
        paths_existing = @($pathsExisting)
        probe_file_count = $fileAnalysis.Count
        probe_primary_file = [string]$primary.path
        probe_file_analysis = @($fileAnalysis)
        data_scale = $dataScale
        size_bytes = [int64]$sizeBytes
        estimated_rows = $estimatedRows
        column_count = $columnCount
        is_workbook = $isWorkbook
        is_csv_like = $isCsvLike
        is_compressed = $isCompressed
        operation_prefers_xan = $operationPrefersXan
        recommended_skill = $recommendedSkill
        confidence = [Math]::Round([double]$confidence, 4)
        confirm_required = $confirmRequired
        auto_override = $autoOverride
        override_candidate_allowed = $overrideCandidateAllowed
    }
}

function Select-PackCandidate {
    param(
        [string]$PromptLower,
        [string[]]$Candidates,
        [string]$TaskType,
        [string]$RequestedCanonical,
        [object]$SkillKeywordIndex,
        [object]$RoutingRules,
        [object]$Pack,
        [object]$CandidateSelectionConfig
    )

    if (-not $Candidates -or $Candidates.Count -eq 0) {
        return [pscustomobject]@{
            selected = $null
            score = 0.0
            reason = "no_candidates"
            ranking = @()
            top1_top2_gap = 0.0
            filtered_out_by_task = @()
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
                    positive_score = 1.0
                    negative_score = 0.0
                    canonical_for_task_hit = 1.0
                }
            )
            top1_top2_gap = 1.0
            filtered_out_by_task = @()
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

    $positiveBonus = 0.2
    $negativePenalty = 0.25
    $canonicalBonus = 0.12
    if ($CandidateSelectionConfig) {
        if ($CandidateSelectionConfig.rule_positive_keyword_bonus -ne $null) {
            $positiveBonus = [double]$CandidateSelectionConfig.rule_positive_keyword_bonus
        }
        if ($CandidateSelectionConfig.rule_negative_keyword_penalty -ne $null) {
            $negativePenalty = [double]$CandidateSelectionConfig.rule_negative_keyword_penalty
        }
        if ($CandidateSelectionConfig.canonical_for_task_bonus -ne $null) {
            $canonicalBonus = [double]$CandidateSelectionConfig.canonical_for_task_bonus
        }
    }

    $filteredCandidates = @()
    $blockedByTask = @()
    foreach ($candidate in $Candidates) {
        $rule = Get-RoutingRuleForCandidate -Candidate $candidate -RoutingRules $RoutingRules
        if (Test-RuleTaskAllowed -Rule $rule -TaskType $TaskType) {
            $filteredCandidates += $candidate
        } else {
            $blockedByTask += $candidate
        }
    }

    $defaultCandidate = Get-PackDefaultCandidate -Pack $Pack -TaskType $TaskType -PreferredCandidates $filteredCandidates -AllCandidates $Candidates

    if ($filteredCandidates.Count -eq 0) {
        if ($defaultCandidate) {
            return [pscustomobject]@{
                selected = $defaultCandidate
                score = 0.0
                reason = "fallback_task_default_after_task_filter"
                ranking = @()
                top1_top2_gap = 0.0
                filtered_out_by_task = @($blockedByTask)
            }
        }

        return [pscustomobject]@{
            selected = $Candidates[0]
            score = 0.0
            reason = "fallback_first_candidate_after_task_filter"
            ranking = @()
            top1_top2_gap = 0.0
            filtered_out_by_task = @($blockedByTask)
        }
    }

    $scored = @()
    for ($i = 0; $i -lt $filteredCandidates.Count; $i++) {
        $candidate = [string]$filteredCandidates[$i]
        $rule = Get-RoutingRuleForCandidate -Candidate $candidate -RoutingRules $RoutingRules

        $keywordScore = Get-SkillKeywordScore -PromptLower $PromptLower -Candidate $candidate -SkillKeywordIndex $SkillKeywordIndex
        $nameScore = Get-CandidateNameMatchScore -PromptLower $PromptLower -Candidate $candidate

        $positiveScore = 0.0
        $negativeScore = 0.0
        $equivalentGroup = $null
        if ($rule) {
            $positiveScore = Get-KeywordRatio -PromptLower $PromptLower -Keywords @($rule.positive_keywords)
            $negativeScore = Get-KeywordRatio -PromptLower $PromptLower -Keywords @($rule.negative_keywords)
            if ($rule.equivalent_group) {
                $equivalentGroup = [string]$rule.equivalent_group
            }
        }

        $canonicalHit = Get-CanonicalForTaskHit -Rule $rule -TaskType $TaskType

        $score =
            ($weightKeyword * $keywordScore) +
            ($weightName * $nameScore) +
            ($positiveBonus * $positiveScore) -
            ($negativePenalty * $negativeScore) +
            ($canonicalBonus * $canonicalHit)

        $score = [Math]::Max(0.0, [Math]::Min(1.0, $score))

        $scored += [pscustomobject]@{
            skill = $candidate
            score = [Math]::Round($score, 4)
            keyword_score = [Math]::Round($keywordScore, 4)
            name_score = [Math]::Round($nameScore, 4)
            positive_score = [Math]::Round($positiveScore, 4)
            negative_score = [Math]::Round($negativeScore, 4)
            canonical_for_task_hit = [Math]::Round($canonicalHit, 4)
            equivalent_group = $equivalentGroup
            ordinal = $i
        }
    }

    $ranked = $scored | Sort-Object -Property @(
        @{ Expression = "score"; Descending = $true },
        @{ Expression = "keyword_score"; Descending = $true },
        @{ Expression = "positive_score"; Descending = $true },
        @{ Expression = "ordinal"; Descending = $false }
    )

    $top = $ranked | Select-Object -First 1
    if (-not $top) {
        $fallback = if ($defaultCandidate) { $defaultCandidate } else { $filteredCandidates[0] }
        $fallbackReason = if ($defaultCandidate) { "fallback_task_default" } else { "fallback_first_candidate" }
        return [pscustomobject]@{
            selected = $fallback
            score = 0.0
            reason = $fallbackReason
            ranking = @()
            top1_top2_gap = 0.0
            filtered_out_by_task = @($blockedByTask)
        }
    }

    $second = $ranked | Select-Object -Skip 1 -First 1
    $gap = if ($second) { [double]$top.score - [double]$second.score } else { [double]$top.score }
    $gap = [Math]::Max(0.0, [Math]::Round($gap, 4))

    if ([double]$top.score -lt $fallbackMin) {
        if ($defaultCandidate) {
            $defaultInRank = $ranked | Where-Object { $_.skill -eq $defaultCandidate } | Select-Object -First 1
            $defaultScore = if ($defaultInRank) { [double]$defaultInRank.score } else { [double]$top.score }
            return [pscustomobject]@{
                selected = $defaultCandidate
                score = $defaultScore
                reason = "fallback_task_default"
                ranking = @($ranked | Select-Object -First 3)
                top1_top2_gap = $gap
                filtered_out_by_task = @($blockedByTask)
            }
        }

        return [pscustomobject]@{
            selected = $filteredCandidates[0]
            score = [double]$top.score
            reason = "fallback_first_candidate"
            ranking = @($ranked | Select-Object -First 3)
            top1_top2_gap = $gap
            filtered_out_by_task = @($blockedByTask)
        }
    }

    return [pscustomobject]@{
        selected = [string]$top.skill
        score = [double]$top.score
        reason = "keyword_ranked"
        ranking = @($ranked | Select-Object -First 3)
        top1_top2_gap = $gap
        filtered_out_by_task = @($blockedByTask)
    }
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$configRoot = Join-Path $repoRoot "config"

$packManifestPath = Join-Path $configRoot "pack-manifest.json"
$aliasMapPath = Join-Path $configRoot "skill-alias-map.json"
$thresholdPath = Join-Path $configRoot "router-thresholds.json"
$skillKeywordIndexPath = Join-Path $configRoot "skill-keyword-index.json"
$routingRulesPath = Join-Path $configRoot "skill-routing-rules.json"
$openSpecPolicyPath = Join-Path $configRoot "openspec-policy.json"
$gsdOverlayPolicyPath = Join-Path $configRoot "gsd-overlay.json"
$promptOverlayPolicyPath = Join-Path $configRoot "prompt-overlay.json"
$memoryGovernancePolicyPath = Join-Path $configRoot "memory-governance.json"
$dataScaleOverlayPolicyPath = Join-Path $configRoot "data-scale-overlay.json"

$packManifest = Get-Content -LiteralPath $packManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$aliasMap = Get-Content -LiteralPath $aliasMapPath -Raw -Encoding UTF8 | ConvertFrom-Json
$thresholds = Get-Content -LiteralPath $thresholdPath -Raw -Encoding UTF8 | ConvertFrom-Json
$skillKeywordIndex = if (Test-Path -LiteralPath $skillKeywordIndexPath) {
    Get-Content -LiteralPath $skillKeywordIndexPath -Raw -Encoding UTF8 | ConvertFrom-Json
} else {
    $null
}
$routingRules = if (Test-Path -LiteralPath $routingRulesPath) {
    Get-Content -LiteralPath $routingRulesPath -Raw -Encoding UTF8 | ConvertFrom-Json
} else {
    $null
}
$openSpecPolicy = if (Test-Path -LiteralPath $openSpecPolicyPath) {
    Get-Content -LiteralPath $openSpecPolicyPath -Raw -Encoding UTF8 | ConvertFrom-Json
} else {
    $null
}
$gsdOverlayPolicy = if (Test-Path -LiteralPath $gsdOverlayPolicyPath) {
    Get-Content -LiteralPath $gsdOverlayPolicyPath -Raw -Encoding UTF8 | ConvertFrom-Json
} else {
    $null
}
$promptOverlayPolicy = if (Test-Path -LiteralPath $promptOverlayPolicyPath) {
    Get-Content -LiteralPath $promptOverlayPolicyPath -Raw -Encoding UTF8 | ConvertFrom-Json
} else {
    $null
}
$memoryGovernancePolicy = if (Test-Path -LiteralPath $memoryGovernancePolicyPath) {
    Get-Content -LiteralPath $memoryGovernancePolicyPath -Raw -Encoding UTF8 | ConvertFrom-Json
} else {
    $null
}
$dataScaleOverlayPolicy = if (Test-Path -LiteralPath $dataScaleOverlayPolicyPath) {
    Get-Content -LiteralPath $dataScaleOverlayPolicyPath -Raw -Encoding UTF8 | ConvertFrom-Json
} else {
    $null
}

$weights = $thresholds.weights
$rules = $thresholds.safety
$th = $thresholds.thresholds
$weightSkillSignal = if ($weights.skill_keyword_signal -ne $null) { [double]$weights.skill_keyword_signal } else { 0.25 }
$candidateSelectionConfig = if ($thresholds.candidate_selection) { $thresholds.candidate_selection } else { $null }
$minTopGap = if ($th.min_top1_top2_gap -ne $null) { [double]$th.min_top1_top2_gap } else { 0.0 }
$minCandidateSignalForConfirmOverride = if ($th.min_candidate_signal_for_confirm_override -ne $null) { [double]$th.min_candidate_signal_for_confirm_override } else { 0.0 }

$aliasResult = Resolve-Alias -Skill $RequestedSkill -AliasMap $aliasMap
$requestedCanonical = [string]$aliasResult.canonical
$promptLower = $Prompt.ToLowerInvariant()
$openSpecAdvice = Get-OpenSpecGovernanceAdvice -PromptLower $promptLower -Grade $Grade -TaskType $TaskType -RequestedCanonical $requestedCanonical -OpenSpecPolicy $openSpecPolicy
$gsdOverlayAdvice = Get-GsdOverlayAdvice -PromptLower $promptLower -Grade $Grade -TaskType $TaskType -GsdOverlayPolicy $gsdOverlayPolicy
$promptOverlayAdvice = Get-PromptOverlayAdvice -PromptLower $promptLower -Grade $Grade -TaskType $TaskType -PromptOverlayPolicy $promptOverlayPolicy
$memoryGovernanceAdvice = Get-MemoryGovernanceAdvice -Grade $Grade -TaskType $TaskType -MemoryGovernancePolicy $memoryGovernancePolicy

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

    $selection = Select-PackCandidate -PromptLower $promptLower -Candidates $pack.skill_candidates -TaskType $TaskType -RequestedCanonical $requestedCanonical -SkillKeywordIndex $skillKeywordIndex -RoutingRules $routingRules -Pack $pack -CandidateSelectionConfig $candidateSelectionConfig
    $candidateSignal = ([double]$selection.score * 0.75) + ([double]$selection.top1_top2_gap * 0.25)
    $candidateSignal = [Math]::Round([Math]::Min(1.0, [Math]::Max(0.0, $candidateSignal)), 4)

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
        candidate_top1_top2_gap = [Math]::Round([double]$selection.top1_top2_gap, 4)
        candidate_signal = $candidateSignal
        candidate_filtered_out_by_task = @($selection.filtered_out_by_task)
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

$topGap = if ($top) { [double]$top.candidate_top1_top2_gap } else { 0.0 }
$candidateSignal = if ($top) { [double]$top.candidate_signal } else { 0.0 }
$canOverrideLegacyFallback = $false
if ($top -and ($top.candidate_selection_reason -in @("keyword_ranked", "requested_skill")) -and ($candidateSignal -ge $minCandidateSignalForConfirmOverride)) {
    $canOverrideLegacyFallback = $true
}
$routeReason = ""
if (-not $top) {
    $routeMode = "legacy_fallback"
    $routeReason = "no_eligible_pack"
} elseif ($confidence -lt [double]$th.fallback_to_legacy_below) {
    if ($canOverrideLegacyFallback) {
        $routeMode = "confirm_required"
        $routeReason = "candidate_signal_override"
        $confidence = [Math]::Max($confidence, [double]$th.confirm_required)
    } else {
        $routeMode = "legacy_fallback"
        $routeReason = "confidence_below_fallback"
    }
} elseif ($topGap -lt $minTopGap) {
    $routeMode = "confirm_required"
    $routeReason = "top_candidates_too_close"
} elseif ($confidence -lt [double]$th.auto_route) {
    $routeMode = "confirm_required"
    $routeReason = "confidence_requires_confirmation"
} else {
    $routeMode = "pack_overlay"
    $routeReason = "auto_route"
}

$promptOverlayRouteOverride = $false
if ($routeMode -eq "pack_overlay" -and $promptOverlayAdvice -and $promptOverlayAdvice.scope_applicable -and $promptOverlayAdvice.confirm_required) {
    $routeMode = "confirm_required"
    $routeReason = "prompt_overlay_confirm_required"
    $confidence = [Math]::Max($confidence, [double]$th.confirm_required)
    $promptOverlayRouteOverride = $true
}

$dataScaleAdvice = Get-DataScaleOverlayAdvice `
    -Prompt $Prompt `
    -PromptLower $promptLower `
    -Grade $Grade `
    -TaskType $TaskType `
    -RouteMode $routeMode `
    -SelectedPackId $(if ($top) { [string]$top.pack_id } else { $null }) `
    -SelectedSkill $(if ($top) { [string]$top.selected_candidate } else { $null }) `
    -PackCandidates $(if ($top) { @($top.candidates) } else { @() }) `
    -DataScaleOverlayPolicy $dataScaleOverlayPolicy

$dataScaleRouteOverride = $false
$effectiveSelectedSkill = if ($top) { [string]$top.selected_candidate } else { $null }
$effectiveSelectionReason = if ($top) { [string]$top.candidate_selection_reason } else { $null }
$effectiveSelectionScore = if ($top) { [double]$top.candidate_selection_score } else { 0.0 }

if ($top -and $dataScaleAdvice -and $dataScaleAdvice.scope_applicable -and $dataScaleAdvice.override_candidate_allowed -and $dataScaleAdvice.recommended_skill -and ($dataScaleAdvice.recommended_skill -ne $effectiveSelectedSkill)) {
    if ($dataScaleAdvice.auto_override) {
        $effectiveSelectedSkill = [string]$dataScaleAdvice.recommended_skill
        $effectiveSelectionReason = "data_scale_overlay_override"
        $effectiveSelectionScore = [Math]::Round([Math]::Max([double]$effectiveSelectionScore, [double]$dataScaleAdvice.confidence), 4)
        $dataScaleRouteOverride = $true
        if ($routeMode -eq "pack_overlay") {
            $routeReason = "data_scale_auto_override"
        }
    } elseif ($dataScaleAdvice.confirm_required -and $routeMode -eq "pack_overlay") {
        $routeMode = "confirm_required"
        $routeReason = "data_scale_confirm_required"
        $confidence = [Math]::Max($confidence, [double]$th.confirm_required)
        $dataScaleRouteOverride = $true
    }
}

$result = [pscustomobject]@{
    prompt = $Prompt
    grade = $Grade
    task_type = $TaskType
    route_mode = $routeMode
    route_reason = $routeReason
    confidence = [Math]::Round($confidence, 4)
    top1_top2_gap = [Math]::Round($topGap, 4)
    candidate_signal = [Math]::Round($candidateSignal, 4)
    thresholds = [pscustomobject]@{
        auto_route = [double]$th.auto_route
        confirm_required = [double]$th.confirm_required
        fallback_to_legacy_below = [double]$th.fallback_to_legacy_below
        min_top1_top2_gap = [double]$minTopGap
        min_candidate_signal_for_confirm_override = [double]$minCandidateSignalForConfirmOverride
    }
    alias = $aliasResult
    openspec_advice = $openSpecAdvice
    gsd_overlay_advice = $gsdOverlayAdvice
    prompt_overlay_advice = $promptOverlayAdvice
    memory_governance_advice = $memoryGovernanceAdvice
    prompt_overlay_route_override = $promptOverlayRouteOverride
    data_scale_advice = $dataScaleAdvice
    data_scale_route_override = $dataScaleRouteOverride
    selected = if ($top) {
        [pscustomobject]@{
            pack_id = $top.pack_id
            skill = $effectiveSelectedSkill
            selection_reason = $effectiveSelectionReason
            selection_score = $effectiveSelectionScore
            top1_top2_gap = $top.candidate_top1_top2_gap
            candidate_signal = $top.candidate_signal
            filtered_out_by_task = @($top.candidate_filtered_out_by_task)
        }
    } else {
        $null
    }
    ranked = @($ranked | Select-Object -First 3)
}

$result | ConvertTo-Json -Depth 10

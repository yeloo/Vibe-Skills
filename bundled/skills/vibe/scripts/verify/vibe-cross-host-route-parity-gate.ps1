param(
    [string]$FixturePath = '',
    [switch]$WriteArtifacts,
    [string]$OutputDirectory = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot '..\common\vibe-governance-helpers.ps1')

function Add-Assertion {
    param(
        [System.Collections.Generic.List[object]]$Assertions,
        [bool]$Pass,
        [string]$Message,
        [object]$Details = $null
    )

    [void]$Assertions.Add([pscustomobject]@{
        pass = [bool]$Pass
        message = [string]$Message
        details = $Details
    })
}

function New-ArtifactObject {
    param([hashtable]$Properties)
    return (New-Object PSObject -Property $Properties)
}

function Write-GateArtifacts {
    param(
        [string]$RepoRoot,
        [string]$OutputDirectory,
        [object]$Artifact
    )

    $dir = if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
        Join-Path $RepoRoot 'outputs\verify'
    } else {
        $OutputDirectory
    }
    New-Item -ItemType Directory -Force -Path $dir | Out-Null

    $jsonPath = Join-Path $dir 'vibe-cross-host-route-parity-gate.json'
    $mdPath = Join-Path $dir 'vibe-cross-host-route-parity-gate.md'
    Write-VgoUtf8NoBomText -Path $jsonPath -Content ($Artifact | ConvertTo-Json -Depth 100)

    $lines = @(
        '# Vibe Cross-Host Route Parity Gate',
        '',
        ('- Gate Result: **{0}**' -f $Artifact.gate_result),
        ('- Fixture: `{0}`' -f $Artifact.fixture_path),
        ('- Cases Checked: {0}' -f $Artifact.summary.cases_checked),
        ('- Failures: {0}' -f $Artifact.summary.failures),
        '',
        '## Assertions',
        ''
    )

    foreach ($assertion in @($Artifact.assertions)) {
        $lines += ('- `{0}` {1}' -f $(if ($assertion.pass) { 'PASS' } else { 'FAIL' }), $assertion.message)
    }

    $lines += ''
    $lines += '## Case Results'
    $lines += ''
    foreach ($case in @($Artifact.cases)) {
        $lines += ('- `{0}` expected={1}/{2}/{3} actual={4}/{5}/{6}' -f `
            $case.id,
            $case.expected.route_mode,
            $case.expected.selected_pack,
            $case.expected.selected_skill,
            $case.actual.route_mode,
            $case.actual.selected_pack,
            $case.actual.selected_skill)
        if ($case.actual.error) {
            $lines += ('  error: {0}' -f $case.actual.error)
        }
    }

    Write-VgoUtf8NoBomText -Path $mdPath -Content ($lines -join "`n")
}

$context = Get-VgoGovernanceContext -ScriptPath $PSCommandPath -EnforceExecutionContext
$repoRoot = [string]$context.repoRoot

$fixtureRel = if ([string]::IsNullOrWhiteSpace($FixturePath)) {
    'tests/replay/route/official-runtime-golden.json'
} else {
    $FixturePath
}
$fixtureFull = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $fixtureRel))
$routerScript = Join-Path $repoRoot 'scripts\router\resolve-pack-route.ps1'

$assertions = [System.Collections.Generic.List[object]]::new()
$caseResults = [System.Collections.Generic.List[object]]::new()

Add-Assertion -Assertions $assertions -Pass (Test-Path -LiteralPath $fixtureFull) -Message 'route fixture exists' -Details $fixtureFull
Add-Assertion -Assertions $assertions -Pass (Test-Path -LiteralPath $routerScript) -Message 'router script exists' -Details $routerScript

$fixture = $null
if (Test-Path -LiteralPath $fixtureFull) {
    try {
        $fixture = Get-Content -LiteralPath $fixtureFull -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        Add-Assertion -Assertions $assertions -Pass $false -Message 'route fixture parses as JSON' -Details $_.Exception.Message
    }
}

Add-Assertion -Assertions $assertions -Pass ($fixture -and [string]$fixture.schema_version -eq 'replay.route.v1') -Message 'route fixture schema_version == replay.route.v1' -Details $(if ($fixture) { $fixture.schema_version } else { $null })

$failures = 0
$checked = 0

if ($fixture -and $fixture.cases) {
    foreach ($case in @($fixture.cases)) {
        $checked++

        $actualRouteMode = $null
        $actualPack = $null
        $actualSkill = $null
        $actualError = $null

        try {
            $raw = powershell.exe -NoProfile -ExecutionPolicy Bypass -File $routerScript `
                -Prompt ([string]$case.prompt) `
                -Grade ([string]$case.grade) `
                -TaskType ([string]$case.task_type) `
                -Unattended 2>&1 | Out-String

            $parsed = $raw | ConvertFrom-Json
            $actualRouteMode = [string]$parsed.route_mode
            if ($parsed.selected) {
                $actualPack = [string]$parsed.selected.pack_id
                $actualSkill = [string]$parsed.selected.skill
            }
        } catch {
            $actualError = $_.Exception.Message
        }

        $expectedRouteMode = [string]$case.expected.route_mode
        $expectedPack = [string]$case.expected.selected_pack
        $expectedSkill = [string]$case.expected.selected_skill

        $casePass =
            ($null -eq $actualError) -and
            ($actualRouteMode -eq $expectedRouteMode) -and
            ($actualPack -eq $expectedPack) -and
            ($actualSkill -eq $expectedSkill)

        if (-not $casePass) {
            $failures++
        }

        [void]$caseResults.Add((New-ArtifactObject -Properties ([ordered]@{
            id = [string]$case.id
            input = New-ArtifactObject -Properties ([ordered]@{
                grade = [string]$case.grade
                task_type = [string]$case.task_type
            })
            expected = New-ArtifactObject -Properties ([ordered]@{
                route_mode = $expectedRouteMode
                selected_pack = $expectedPack
                selected_skill = $expectedSkill
            })
            actual = New-ArtifactObject -Properties ([ordered]@{
                route_mode = $actualRouteMode
                selected_pack = $actualPack
                selected_skill = $actualSkill
                error = $actualError
            })
            pass = [bool]$casePass
        })))
    }
}

Add-Assertion -Assertions $assertions -Pass ($failures -eq 0) -Message 'all route cases match golden fixture' -Details @{ failures = $failures; total = $checked }

$assertionFailures = @($assertions | Where-Object { -not $_.pass }).Count
$gateResult = if ($assertionFailures -eq 0 -and $failures -eq 0) { 'PASS' } else { 'FAIL' }

$artifact = New-ArtifactObject -Properties ([ordered]@{
    gate = 'vibe-cross-host-route-parity-gate'
    repo_root = $repoRoot
    fixture_path = $fixtureFull
    generated_at = (Get-Date).ToString('s')
    gate_result = $gateResult
    assertions = @($assertions.ToArray())
    cases = @($caseResults.ToArray())
    summary = New-ArtifactObject -Properties ([ordered]@{
        cases_checked = $checked
        failures = $failures
        assertion_failures = $assertionFailures
    })
})

if ($WriteArtifacts) {
    Write-GateArtifacts -RepoRoot $repoRoot -OutputDirectory $OutputDirectory -Artifact $artifact
}

if ($gateResult -ne 'PASS') {
    exit 1
}

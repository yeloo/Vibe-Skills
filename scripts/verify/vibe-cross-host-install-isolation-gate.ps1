param(
    [switch]$WriteArtifacts,
    [string]$OutputDirectory = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot '..\common\vibe-governance-helpers.ps1')

function Add-Assertion {
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [System.Collections.Generic.List[object]]$Assertions,
        [Parameter(Mandatory)] [bool]$Pass,
        [Parameter(Mandatory)] [string]$Message,
        [AllowNull()] [object]$Details = $null
    )

    [void]$Assertions.Add([pscustomobject]@{
        pass = [bool]$Pass
        message = [string]$Message
        details = $Details
    })

    if ($Pass) {
        Write-Host "[PASS] $Message"
    } else {
        Write-Host "[FAIL] $Message" -ForegroundColor Red
    }
}

function Write-GateArtifacts {
    param(
        [Parameter(Mandatory)] [string]$RepoRoot,
        [AllowEmptyString()] [string]$OutputDirectory,
        [Parameter(Mandatory)] [psobject]$Artifact
    )

    $dir = if ([string]::IsNullOrWhiteSpace($OutputDirectory)) { Join-Path $RepoRoot 'outputs\verify' } else { $OutputDirectory }
    New-Item -ItemType Directory -Force -Path $dir | Out-Null

    $jsonPath = Join-Path $dir 'vibe-cross-host-install-isolation-gate.json'
    $mdPath = Join-Path $dir 'vibe-cross-host-install-isolation-gate.md'

    Write-VgoUtf8NoBomText -Path $jsonPath -Content ($Artifact | ConvertTo-Json -Depth 100)

    $lines = @(
        '# VCO Cross-Host Install Isolation Gate (Diff-Based)',
        '',
        ('- Gate Result: **{0}**' -f $Artifact.gate_result),
        ('- Repo Root: `{0}`' -f $Artifact.repo_root),
        ('- Changed paths examined: {0}' -f $Artifact.summary.changed_path_count),
        ('- Violations: {0}' -f $Artifact.summary.violation_count),
        '',
        '## Notes',
        '',
        '- This gate enforces the Batch C non-regression rule: do not modify the official runtime main chain.',
        '- It is intentionally conservative and uses `git status --porcelain` as the evidence source.',
        '',
        '## Assertions',
        ''
    )

    foreach ($a in @($Artifact.assertions)) {
        $lines += ('- `{0}` {1}' -f $(if ($a.pass) { 'PASS' } else { 'FAIL' }), $a.message)
    }

    if (@($Artifact.violations).Count -gt 0) {
        $lines += ''
        $lines += '## Violations'
        $lines += ''
        foreach ($v in @($Artifact.violations)) {
            $lines += ('- {0}' -f $v)
        }
    }

    Write-VgoUtf8NoBomText -Path $mdPath -Content ($lines -join "`n")
}

function Get-GitStatusPaths {
    param([Parameter(Mandatory)][string]$RepoRoot)

    $out = & git -C $RepoRoot status --porcelain=v1 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "git status failed with exit code $LASTEXITCODE"
    }

    $paths = New-Object System.Collections.Generic.List[string]
    foreach ($line in @($out)) {
        $t = [string]$line
        if ([string]::IsNullOrWhiteSpace($t)) { continue }

        if ($t.Length -lt 4) { continue }
        $pathPart = $t.Substring(3)

        # Handle rename: "R  old -> new"
        if ($pathPart -like '* -> *') {
            $parts = $pathPart -split ' -> '
            foreach ($p in $parts) {
                if (-not [string]::IsNullOrWhiteSpace($p)) { [void]$paths.Add([string]$p) }
            }
        } else {
            [void]$paths.Add([string]$pathPart)
        }
    }

    return @($paths)
}

$context = Get-VgoGovernanceContext -ScriptPath $PSCommandPath -EnforceExecutionContext
$repoRoot = [string]$context.repoRoot

$assertions = [System.Collections.Generic.List[object]]::new()
$violations = [System.Collections.Generic.List[string]]::new()

$gitOk = $true
try {
    & git --version 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { $gitOk = $false }
} catch {
    $gitOk = $false
}
Add-Assertion -Assertions $assertions -Pass $gitOk -Message 'git is available for diff-based isolation checks' -Details $null

$changed = @()
if ($gitOk) {
    try {
        $changed = Get-GitStatusPaths -RepoRoot $repoRoot
        Add-Assertion -Assertions $assertions -Pass $true -Message 'git status parsed' -Details ("paths={0}" -f $changed.Count)
    } catch {
        Add-Assertion -Assertions $assertions -Pass $false -Message 'git status parsed' -Details $_.Exception.Message
        $gitOk = $false
    }
}

$protectedPrefixes = @(
    'scripts/router/'
)
$protectedExact = @(
    'install.ps1',
    'check.ps1',
    'install.sh',
    'check.sh',
    'config/version-governance.json'
)

foreach ($path in @($changed)) {
    $p = ([string]$path).Replace('\', '/')
    $pLower = $p.ToLowerInvariant()

    $isProtected = $false
    foreach ($prefix in $protectedPrefixes) {
        if ($pLower.StartsWith($prefix)) { $isProtected = $true; break }
    }
    if (-not $isProtected) {
        foreach ($exact in $protectedExact) {
            if ($pLower -eq $exact) { $isProtected = $true; break }
        }
    }

    if ($isProtected) {
        [void]$violations.Add($p)
    }
}

Add-Assertion -Assertions $assertions -Pass ($violations.Count -eq 0) -Message 'no official-runtime main-chain files changed' -Details ($violations -join ',')

$failureCount = @($assertions | Where-Object { -not $_.pass }).Count
$gateResult = if ($failureCount -eq 0) { 'PASS' } else { 'FAIL' }

$artifact = [pscustomobject]@{
    gate = 'vibe-cross-host-install-isolation-gate'
    mode = 'diff-based'
    repo_root = $repoRoot
    generated_at = (Get-Date).ToString('s')
    gate_result = $gateResult
    assertions = @($assertions)
    violations = @($violations)
    summary = [pscustomobject]@{
        changed_path_count = @($changed).Count
        violation_count = $violations.Count
    }
}

if ($WriteArtifacts) {
    Write-GateArtifacts -RepoRoot $repoRoot -OutputDirectory $OutputDirectory -Artifact $artifact
}

if ($gateResult -ne 'PASS') {
    exit 1
}

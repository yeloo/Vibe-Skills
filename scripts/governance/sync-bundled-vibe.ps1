param(
    [switch]$PruneBundledExtras,
    [switch]$Preview,
    [string]$PreviewOutputPath = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\common\vibe-governance-helpers.ps1')

function Copy-DirContent {
    param(
        [Parameter(Mandatory)] [string]$Source,
        [Parameter(Mandatory)] [string]$Destination
    )

    if (-not (Test-Path -LiteralPath $Source)) {
        return
    }

    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    Copy-Item -Path (Join-Path $Source '*') -Destination $Destination -Recurse -Force
}

function Add-PreviewAction {
    param(
        [System.Collections.Generic.List[object]]$Collection,
        [string]$Type,
        [string]$TargetId,
        [string]$RelativePath,
        [string]$Message
    )

    $Collection.Add([pscustomobject]@{
        type = $Type
        target_id = $TargetId
        relative_path = $RelativePath
        message = $Message
    }) | Out-Null
}

function Get-PreviewReceiptPath {
    param(
        [string]$CanonicalRoot,
        [string]$RequestedPath,
        [psobject]$Contract
    )

    if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
        return $RequestedPath
    }

    $root = if ($null -ne $Contract -and $Contract.PSObject.Properties.Name -contains 'preview_output_root') {
        [string]$Contract.preview_output_root
    } else {
        'outputs/governance/preview'
    }
    return Join-Path $CanonicalRoot (Join-Path $root 'sync-bundled-vibe.json')
}

$context = Get-VgoGovernanceContext -ScriptPath $PSCommandPath -EnforceExecutionContext
$canonicalRoot = $context.canonicalRoot
$packaging = $context.packaging
$mirrorFiles = @($packaging.mirror.files)
$mirrorDirs = @($packaging.mirror.directories)
$allowBundledOnly = @($packaging.allow_bundled_only)
$syncTargets = @(
    $context.mirrorTargets | Where-Object {
        -not $_.isCanonical -and $_.sync_enabled
    }
)
$previewContractPath = Join-Path $canonicalRoot 'config/operator-preview-contract.json'
$previewContract = if (Test-Path -LiteralPath $previewContractPath) {
    Get-Content -LiteralPath $previewContractPath -Raw -Encoding UTF8 | ConvertFrom-Json
} else {
    $null
}
$previewActions = [System.Collections.Generic.List[object]]::new()

function Sync-ToMirrorTarget {
    param(
        [Parameter(Mandatory)] [psobject]$Target
    )

    $targetRoot = [string]$Target.fullPath
    $shouldCreate = [bool]$Target.required -or ([string]$Target.presence_policy -eq 'required')
    $targetExists = Test-Path -LiteralPath $targetRoot
    if (-not $targetExists) {
        if ($shouldCreate) {
            if ($Preview) {
                Add-PreviewAction -Collection $previewActions -Type 'create-target' -TargetId ([string]$Target.id) -RelativePath '.' -Message ('would create mirror root ' + $targetRoot)
            } else {
                New-Item -ItemType Directory -Force -Path $targetRoot | Out-Null
                Write-Host ("[CREATE] {0} -> {1}" -f $Target.id, $targetRoot)
            }
        } else {
            $message = ("skip missing optional target {0} ({1})" -f $Target.id, $Target.presence_policy)
            if ($Preview) {
                Add-PreviewAction -Collection $previewActions -Type 'skip-target' -TargetId ([string]$Target.id) -RelativePath '.' -Message $message
            } else {
                Write-Host ("[SKIP] {0} missing and policy is {1}" -f $Target.id, $Target.presence_policy) -ForegroundColor Yellow
            }
            return
        }
    }

    foreach ($rel in $mirrorFiles) {
        $sourcePath = Join-Path $canonicalRoot $rel
        $targetPath = Join-Path $targetRoot $rel
        if (-not (Test-Path -LiteralPath $sourcePath)) {
            if (-not $Preview) {
                Write-Warning ("Skip missing canonical file: {0}" -f $rel)
            }
            continue
        }

        $targetDir = Split-Path -Parent $targetPath
        if ($Preview) {
            Add-PreviewAction -Collection $previewActions -Type 'sync-file' -TargetId ([string]$Target.id) -RelativePath $rel -Message ('would sync file to ' + $targetPath)
        } else {
            if (-not [string]::IsNullOrWhiteSpace($targetDir)) {
                New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
            }
            Copy-Item -LiteralPath $sourcePath -Destination $targetPath -Force
            Write-Host ("[SYNC] {0} file {1}" -f $Target.id, $rel)
        }
    }

    foreach ($dir in $mirrorDirs) {
        $sourceDir = Join-Path $canonicalRoot $dir
        $targetDir = Join-Path $targetRoot $dir
        if (-not (Test-Path -LiteralPath $sourceDir)) {
            if (-not $Preview) {
                Write-Warning ("Skip missing canonical dir: {0}" -f $dir)
            }
            continue
        }

        if ($Preview) {
            Add-PreviewAction -Collection $previewActions -Type 'sync-dir' -TargetId ([string]$Target.id) -RelativePath $dir -Message ('would sync directory to ' + $targetDir)
        } else {
            Copy-DirContent -Source $sourceDir -Destination $targetDir
            Write-Host ("[SYNC] {0} dir {1}" -f $Target.id, $dir)
        }

        if ($PruneBundledExtras -and (Test-Path -LiteralPath $targetDir)) {
            $sourceFiles = Get-VgoRelativeFileList -RootPath $sourceDir
            $targetFiles = Get-VgoRelativeFileList -RootPath $targetDir
            foreach ($relPath in @($targetFiles | Where-Object { $_ -notin $sourceFiles })) {
                $allowRel = ('{0}/{1}' -f $dir, $relPath).Replace('\', '/')
                if ($allowBundledOnly -contains $allowRel) {
                    continue
                }

                $candidatePath = Join-Path $targetDir $relPath
                if ($Preview) {
                    Add-PreviewAction -Collection $previewActions -Type 'prune-file' -TargetId ([string]$Target.id) -RelativePath $allowRel -Message ('would prune extra bundled file ' + $candidatePath)
                } elseif (Test-Path -LiteralPath $candidatePath) {
                    Remove-Item -LiteralPath $candidatePath -Force -ErrorAction SilentlyContinue
                    Write-Host ("[PRUNE] {0} {1}" -f $Target.id, $allowRel)
                }
            }
        }
    }
}

Write-Host '=== Sync Bundled Vibe ===' -ForegroundColor Cyan
Write-Host ("Canonical root : {0}" -f $canonicalRoot)
Write-Host ("Sync source    : {0}" -f $context.syncSourceTarget.id)
foreach ($target in $syncTargets) {
    Write-Host ("Mirror target  : {0} -> {1} [{2}]" -f $target.id, $target.fullPath, $target.presence_policy)
}
Write-Host ''

foreach ($target in $syncTargets) {
    Sync-ToMirrorTarget -Target $target
}

if ($Preview) {
    $receiptPath = Get-PreviewReceiptPath -CanonicalRoot $canonicalRoot -RequestedPath $PreviewOutputPath -Contract $previewContract
    $receipt = [ordered]@{
        operator = 'sync-bundled-vibe'
        contract_version = if ($null -ne $previewContract -and $previewContract.PSObject.Properties.Name -contains 'contract_version') { $previewContract.contract_version } else { 1 }
        mode = 'preview'
        precheck = [ordered]@{
            canonical_root = $canonicalRoot
            canonical_target_id = $context.canonicalTarget.id
            sync_source_target_id = $context.syncSourceTarget.id
            prune_bundled_extras = [bool]$PruneBundledExtras
            mirror_targets = @($syncTargets | ForEach-Object {
                [ordered]@{
                    id = $_.id
                    full_path = $_.fullPath
                    presence_policy = $_.presence_policy
                }
            })
        }
        preview = [ordered]@{
            generated_at = (Get-Date).ToString('s')
            action_count = $previewActions.Count
            planned_actions = @($previewActions)
        }
        postcheck = [ordered]@{
            verify_after_apply = @(
                'scripts/verify/vibe-mirror-edit-hygiene-gate.ps1',
                'scripts/verify/vibe-nested-bundled-parity-gate.ps1'
            )
        }
    }
    Write-VgoUtf8NoBomText -Path $receiptPath -Content ($receipt | ConvertTo-Json -Depth 100)
    Write-Host ("Preview receipt written: {0}" -f $receiptPath) -ForegroundColor Yellow
    return
}

Write-Host 'Sync complete.' -ForegroundColor Green

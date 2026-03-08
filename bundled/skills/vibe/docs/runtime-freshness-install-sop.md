# Runtime Freshness Install SOP

This SOP is the operator-facing playbook for the VCO install path after Wave33.

## Boundary Model

- release only governs repo parity
- install copies the governed payload into `${TARGET_ROOT}/skills/vibe`
- runtime freshness authoritatively validates the installed copy against canonical source
- routine checks call the freshness and coherence gates only from the canonical repo root

## Canonical Operator Flow

### PowerShell

```powershell
pwsh -NoProfile -File .\install.ps1 -Profile full -TargetRoot "$env:USERPROFILE\.codex"
pwsh -NoProfile -File .\check.ps1 -Profile full -TargetRoot "$env:USERPROFILE\.codex"
```

### Bash

```bash
bash ./install.sh --profile full --target-root "$HOME/.codex"
bash ./check.sh --profile full --target-root "$HOME/.codex"
```

## Freshness Commands

Run the authoritative runtime freshness gate directly:

```powershell
pwsh -NoProfile -File .\scripts\verify\vibe-installed-runtime-freshness-gate.ps1 -TargetRoot "$env:USERPROFILE\.codex" -WriteReceipt
```

Run the frontmatter / BOM gate against the installed runtime immediately after install/check:

```powershell
pwsh -NoProfile -File .\scripts\verify\vibe-bom-frontmatter-gate.ps1 -TargetRoot "$env:USERPROFILE\.codex" -WriteArtifacts
```

Run the release / install / runtime coherence gate:

```powershell
pwsh -NoProfile -File .\scripts\verify\vibe-release-install-runtime-coherence-gate.ps1 -TargetRoot "$env:USERPROFILE\.codex" -WriteArtifacts
```

## Receipt Contract

The receipt contract is owned by `scripts/verify/vibe-installed-runtime-freshness-gate.ps1`.

Current receipt contract:

- `receipt_contract_version = 1`
- receipt path: `runtime.installed_runtime.receipt_relpath`
- required semantic fields: `gate_result`, `receipt_version`, `target_root`, `installed_root`, `release.version`, `release.updated`

Operational expectations:

1. install writes the receipt only after the freshness gate passes
2. `check.ps1` / `check.sh` validate receipt presence and semantic alignment when possible
3. the coherence gate verifies that the configured contract and the emitting gate stay in sync

## Shell Degraded Behavior

shell degraded behavior is `warn_and_skip_authoritative_runtime_gate`.

This rule exists because Bash-only environments cannot authoritatively execute the PowerShell freshness gate in every installation context.

Expected degraded behavior:

- `install.sh` warns if `pwsh` is unavailable and skips authoritative freshness execution
- `check.sh` warns if `pwsh` is unavailable and skips authoritative freshness execution
- receipt absence in degraded mode is surfaced as a warning context, not a fabricated pass
- once `pwsh` becomes available, the freshness gate becomes the blocking authority again

## Execution-Context Lock

Governance commands must run from the canonical repo root.

Do not run these scripts from:

- `bundled/skills/vibe`
- `bundled/skills/vibe/bundled/skills/vibe`
- installed runtime copies under `${TARGET_ROOT}/skills/vibe`

Why:

- running verify scripts from mirror roots can create false bundled ↔ nested self-check loops
- runtime freshness must compare installed copies back to canonical source
- release/install/runtime coherence depends on canonical governance metadata
- frontmatter/BOM gate must also run from canonical repo root, even when the scan target is `${TARGET_ROOT}/skills/vibe`

## Stop-Ship Conditions

Treat these as stop-ship failures:

- runtime freshness gate fails
- installed runtime BOM/frontmatter gate fails (`SKILL.md` 等 frontmatter-sensitive 文件无法在 byte 0 直接看到 `---`)
- receipt is missing after an authoritative install run
- coherence gate detects contract drift between config, docs, check scripts, and receipt version
- nested parity or mirror edit hygiene fails before release packaging

## Routine Troubleshooting

### Fresh install failed

1. re-run `sync-bundled-vibe.ps1 -PruneBundledExtras`
2. verify repo parity gates
3. re-run install
4. re-run freshness gate with `-WriteReceipt`

### Check warns in shell mode

1. confirm whether `pwsh` is available
2. if not, treat the shell result as non-authoritative for freshness
3. re-run the PowerShell check from the canonical repo root

### Receipt exists but check fails

1. compare `receipt_version` to `runtime.installed_runtime.receipt_contract_version`
2. compare receipt `target_root` / `installed_root` to the actual target
3. inspect release metadata inside the installed copy
4. re-run the freshness gate to refresh the receipt

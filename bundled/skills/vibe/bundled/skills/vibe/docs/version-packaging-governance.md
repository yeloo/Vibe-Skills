# VCO Version / Packaging Governance

This document defines the canonical governance contract for Wave31-33:

- explicit mirror topology
- topology-driven mirror sync
- nested parity + mirror edit hygiene gates
- release / install / runtime freshness boundaries
- execution-context lock for governance scripts

## Mirror Topology Contract

The canonical repo root is the only source of truth. `mirror_topology.targets` now carries the machine-readable contract, while `source_of_truth.*` stays in place for backward compatibility.

| Target ID | Path | Role | Required | Presence Policy | Sync Rule |
| --- | --- | --- | --- | --- | --- |
| `canonical` | `.` | canonical | yes | `required` | never synced from any mirror |
| `bundled` | `bundled/skills/vibe` | release mirror | yes | `required` | synced directly from canonical |
| `nested_bundled` | `bundled/skills/vibe/bundled/skills/vibe` | compatibility mirror | no | `if_present_must_match` | synced directly from canonical when present |

Core rules:

1. `canonical` is the only authoritative target.
2. All sync operations copy from canonical to mirrors.
3. `nested_bundled` is optional to exist, but if it exists it must match canonical and bundled.
4. `allow_bundled_only` remains the only approved exception set for packaged mirror-only files.
5. Installed runtime stays outside repo parity, but it must obey the runtime freshness contract.

## Execution-Context Lock

The execution-context lock protects governance and verify scripts from running inside mirror roots and producing false passes.

Lock behavior:

- the resolved repo root must be the outer git root
- the executing script path must not live under any non-canonical mirror target
- topology resolution must land on the outer canonical root, not on a bundled ↔ nested closed loop

Shared entrypoint:

- `scripts/common/vibe-governance-helpers.ps1`
- `Get-VgoGovernanceContext -ScriptPath $PSCommandPath -EnforceExecutionContext`

## Packaging Scope

Repo parity and mirror parity continue to use the packaging contract from `config/version-governance.json`:

- mirror files: `SKILL.md`, `check.ps1`, `check.sh`, `install.ps1`, `install.sh`
- mirror directories: `config`, `protocols`, `references`, `docs`, `scripts`
- normalized JSON ignore keys: `updated`, `generated_at`
- bundled-only allowlist: `docs/CODEX_ECOSYSTEM_MAINTENANCE_PRINCIPLES.md`

## Topology-Driven Sync

Use `scripts/governance/sync-bundled-vibe.ps1` to sync mirrors.

Sync guarantees:

- the script enumerates `mirror_topology.targets`
- only targets with `sync_enabled = true` are considered
- optional targets with `presence_policy = if_present_must_match` are skipped when absent
- `-PruneBundledExtras` applies to every synced mirror target
- mirror-to-mirror cascading is forbidden

Recommended command:

```powershell
pwsh -NoProfile -File .\scripts\governance\sync-bundled-vibe.ps1 -PruneBundledExtras
```

## Gate Stack

### Repo / Mirror Gates

- `scripts/verify/vibe-version-packaging-gate.ps1`
- `scripts/verify/vibe-version-consistency-gate.ps1`
- `scripts/verify/vibe-config-parity-gate.ps1`
- `scripts/verify/vibe-nested-bundled-parity-gate.ps1`
- `scripts/verify/vibe-mirror-edit-hygiene-gate.ps1`

### Runtime / Coherence Gates

- `scripts/verify/vibe-installed-runtime-freshness-gate.ps1`
- `scripts/verify/vibe-release-install-runtime-coherence-gate.ps1`

## Release / Install / Runtime Boundaries

release only governs repo parity.

That means:

- release metadata and release-cut gates validate canonical + bundled + nested repo state
- install copies the governed payload into `${TARGET_ROOT}/skills/vibe` and writes a freshness receipt on success
- runtime freshness authoritatively validates the installed copy against canonical source
- routine `check.ps1` / `check.sh` may execute the runtime freshness gate only when the canonical repo context is available

## Runtime Freshness Contract

`runtime.installed_runtime` defines the runtime contract:

- `target_relpath`
- `receipt_relpath`
- `post_install_gate`
- `coherence_gate`
- `receipt_contract_version`
- `shell_degraded_behavior`
- `required_runtime_markers`

The installed runtime freshness gate remains the receipt authority. The coherence gate validates that release/install/runtime documentation, scripts, and receipt expectations stay aligned.

## Shell Degraded Behavior

Shell environments without authoritative PowerShell execution must not fake freshness success.

The configured shell degraded behavior is:

- `warn_and_skip_authoritative_runtime_gate`

Operational meaning:

- `check.sh` and `install.sh` warn when `pwsh` is unavailable
- receipt absence in that degraded mode is reported as context, not misreported as a successful freshness run
- once authoritative PowerShell is available, the freshness gate becomes blocking again

## Recommended Operational Flow

1. Edit canonical files only.
2. Run topology-driven sync.
3. Run repo parity gates, including nested parity and mirror hygiene.
4. Cut or verify release metadata.
5. Install into the target runtime.
6. Run runtime freshness and coherence checks.

Example sequence:

```powershell
pwsh -NoProfile -File .\scripts\governance\sync-bundled-vibe.ps1 -PruneBundledExtras
pwsh -NoProfile -File .\scripts\verify\vibe-version-packaging-gate.ps1 -WriteArtifacts
pwsh -NoProfile -File .\scripts\verify\vibe-nested-bundled-parity-gate.ps1 -WriteArtifacts
pwsh -NoProfile -File .\scripts\verify\vibe-mirror-edit-hygiene-gate.ps1 -WriteArtifacts
pwsh -NoProfile -File .\scripts\verify\vibe-installed-runtime-freshness-gate.ps1 -TargetRoot "$env:USERPROFILE\.codex" -WriteReceipt
pwsh -NoProfile -File .\scripts\verify\vibe-release-install-runtime-coherence-gate.ps1 -TargetRoot "$env:USERPROFILE\.codex" -WriteArtifacts
```

For the detailed operator SOP, see `docs/runtime-freshness-install-sop.md`.

## Related Governance

- docs/runtime-freshness-install-sop.md: operator-facing install / runtime freshness playbook.
- docs/promotion-board-governance.md: Wave39 uses version / parity / coherence gates as promotion and release evidence inputs.
- docs/plans/2026-03-07-vco-deep-value-extraction-drift-closure-plan.md: Wave31-39 execution plan and closure criteria.

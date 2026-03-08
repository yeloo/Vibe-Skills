# Releases

- Up: [`../README.md`](../README.md)

## What Lives Here

This directory stores release notes for governed VCO cuts.

Naming rule:
- one file per release
- filename format: `v<version>.md`
- each note should record release date, highlights, migration notes, and governance impact

## Latest

- [`v2.3.30.md`](v2.3.30.md)：Wave31-39 deep extraction / drift closure release.

## Release Index

- [`v2.3.30.md`](v2.3.30.md) — 2026-03-07 — Wave31-39 deep extraction / drift closure
- [`v2.3.29.md`](v2.3.29.md) — 2026-03-07 — Wave19-30 memory / browser / desktop / prompt / release cut closure
- [`v2.3.28.md`](v2.3.28.md) — 2026-03-05 — TurboMax / vector-first context / CUA / prompt asset boost / academic deliverable routing
- [`v2.3.24.md`](v2.3.24.md) — 2026-02-27 — version governance / packaging / release ledger foundation

## Release Cut Procedure

Canonical release cut entrypoint:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\governance\release-cut.ps1 -RunGates
```

The release cut flow is expected to:
- sync canonical -> bundled -> nested mirrors
- run required governance gates
- update release notes and release ledger
- leave evidence artifacts under `outputs/verify`

Operator notes:
- release procedure must remain aligned with [`../../scripts/governance/release-cut.ps1`](../../scripts/governance/release-cut.ps1)
- gate family navigation lives in [`../../scripts/verify/README.md`](../../scripts/verify/README.md) and [`../../scripts/verify/gate-family-index.md`](../../scripts/verify/gate-family-index.md)

## Required Gates (Stop-Ship)

These are the minimum stop-ship checks for a governed release cut:

- `vibe-version-consistency-gate.ps1`
- `vibe-version-packaging-gate.ps1`
- `vibe-config-parity-gate.ps1`
- `vibe-nested-bundled-parity-gate.ps1`
- `vibe-mirror-edit-hygiene-gate.ps1`
- `vibe-bom-frontmatter-gate.ps1`
- `vibe-wave40-63-board-gate.ps1`
- `vibe-capability-dedup-gate.ps1`
- `vibe-adaptive-routing-readiness-gate.ps1`
- `vibe-upstream-value-ops-gate.ps1`
- `vibe-release-install-runtime-coherence-gate.ps1`

## BOM / Frontmatter Warning

Frontmatter-sensitive files such as `SKILL.md` must expose `---` at byte 0.

Why this matters:
- UTF-8 BOM occupies byte 0..2
- some parsers do not strip BOM before looking for YAML frontmatter
- a file that visually starts with `---` can still fail to load if BOM hides byte 0

Operator rule:
- always run `vibe-bom-frontmatter-gate.ps1` before claiming runtime/install/release success

## Installed Runtime Validation

Canonical validation chain:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -Profile full -TargetRoot "$env:USERPROFILE\.codex"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\check.ps1 -Profile full -TargetRoot "$env:USERPROFILE\.codex"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify\vibe-bom-frontmatter-gate.ps1 -TargetRoot "$env:USERPROFILE\.codex" -WriteArtifacts
```

For the full runtime/install SOP, read:
- [`../runtime-freshness-install-sop.md`](../runtime-freshness-install-sop.md)

## Wave64-82 Extended Gates

Wave64-82 adds the following governed release-train extensions:

- `vibe-memory-runtime-v3-gate.ps1`
- `vibe-mem0-softrollout-gate.ps1`
- `vibe-letta-policy-conformance-gate.ps1`
- `vibe-browserops-scorecard-gate.ps1`
- `vibe-browserops-softrollout-gate.ps1`
- `vibe-desktopops-replay-gate.ps1`
- `vibe-desktopops-softrollout-gate.ps1`
- `vibe-docling-contract-v2-gate.ps1`
- `vibe-document-plane-benchmark-gate.ps1`
- `vibe-connector-scorecard-gate.ps1`
- `vibe-connector-action-ledger-gate.ps1`
- `vibe-prompt-intelligence-productization-gate.ps1`
- `vibe-cross-plane-task-contract-gate.ps1`
- `vibe-cross-plane-replay-gate.ps1`
- `vibe-promotion-scorecard-gate.ps1`
- `vibe-ops-cockpit-gate.ps1`
- `vibe-rollback-drill-gate.ps1`
- `vibe-release-train-v2-gate.ps1`
- `vibe-wave64-82-closure-gate.ps1`

These gates extend the stop-ship policy from runtime integrity into plane promotion, cross-plane replay, operator cockpit, rollback drill, and release-train closure.

## Wave83-100 Extended Gates

Wave83-100 adds the following governed release-train extensions:

- `vibe-gate-reliability-gate.ps1`
- `vibe-memory-quality-eval-gate.ps1`
- `vibe-openworld-runtime-eval-gate.ps1`
- `vibe-document-failure-taxonomy-gate.ps1`
- `vibe-prompt-intelligence-eval-gate.ps1`
- `vibe-candidate-quality-board-gate.ps1`
- `vibe-role-pack-v2-gate.ps1`
- `vibe-subagent-handoff-gate.ps1`
- `vibe-discovery-intake-scorecard-gate.ps1`
- `vibe-capability-lifecycle-gate.ps1`
- `vibe-connector-sandbox-simulation-gate.ps1`
- `vibe-skill-harvest-v2-gate.ps1`
- `vibe-ops-dashboard-gate.ps1`
- `vibe-release-evidence-bundle-gate.ps1`
- `vibe-manual-apply-policy-gate.ps1`
- `vibe-rollout-proposal-boundedness-gate.ps1`
- `vibe-upstream-reaudit-matrix-gate.ps1`
- `vibe-wave83-100-closure-gate.ps1`

These gates extend stop-ship policy into gate reliability, candidate quality boards, subagent handoff, discovery intake, lifecycle governance, sandbox simulation, bounded rollout proposals, and release evidence closure.

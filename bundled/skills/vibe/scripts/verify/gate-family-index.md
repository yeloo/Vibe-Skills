# Verify Gate Family Index

## Why This Exists

`scripts/verify/` contains many gates. Family-level navigation keeps governance operable without creating a second router.

## Gate Families

| Family | Typical Scripts | When to Run |
| --- | --- | --- |
| Runtime Integrity / Packaging | `vibe-bom-frontmatter-gate.ps1`, `vibe-version-packaging-gate.ps1`, `vibe-installed-runtime-freshness-gate.ps1`, `vibe-release-install-runtime-coherence-gate.ps1` | packaging, install, frontmatter, runtime freshness |
| Cleanliness / Outputs / Mirror Hygiene | `vibe-repo-cleanliness-gate.ps1`, `vibe-output-artifact-boundary-gate.ps1`, `vibe-mirror-edit-hygiene-gate.ps1`, `vibe-nested-bundled-parity-gate.ps1` | canonical cleanup batches, sync-before/after, fixture migrations |
| Plane Governance | `vibe-browserops-*.ps1`, `vibe-desktopops-*.ps1`, `vibe-docling-*.ps1`, `vibe-connector-*.ps1` | plane contract, rollout, replay, sandbox, benchmark changes |
| Capability / Role / Upstream Value Ops | `vibe-capability-*.ps1`, `vibe-role-pack-*.ps1`, `vibe-upstream-*.ps1`, `vibe-skill-harvest-v2-gate.ps1` | upstream distillation, role-pack and capability closure |
| Release / Promotion / Observability | `vibe-promotion-board-gate.ps1`, `vibe-release-evidence-bundle-gate.ps1`, `vibe-release-train-v2-gate.ps1`, `vibe-ops-cockpit-gate.ps1` | release, promotion, observability, cockpit updates |
| Operator Preview / Apply Safety | `vibe-operator-preview-contract-gate.ps1`, `vibe-manual-apply-policy-gate.ps1` | preview/apply contract changes for write-capable governance scripts |
| Execution-Context / Wave Runner | `vibe-wave121-upstream-mapping-gate.ps1`, `vibe-wave124-ops-cockpit-v2-gate.ps1`, `vibe-wave125-gate-family-convergence-gate.ps1` | manifest families, wave-runner coverage, execution-context lock hardening |

## Adjacent Operator Surface

These scripts are not verify gates, but they must remain aligned with the families above:

- `scripts/governance/sync-bundled-vibe.ps1`
- `scripts/governance/release-cut.ps1`
- `scripts/common/vibe-wave-gate-runner.ps1`
- `scripts/common/vibe-governance-helpers.ps1`

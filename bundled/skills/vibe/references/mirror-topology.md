# VCO Mirror Topology Reference

This reference is the human-readable mirror map for `config/version-governance.json`.

## Targets

| Target ID | Path | Role | Required | Presence Policy | Sync Enabled |
| --- | --- | --- | --- | --- | --- |
| `canonical` | `.` | canonical source | yes | `required` | no |
| `bundled` | `bundled/skills/vibe` | packaged mirror | yes | `required` | yes |
| `nested_bundled` | `bundled/skills/vibe/bundled/skills/vibe` | compatibility mirror | no | `if_present_must_match` | yes |

## Topology Rules

- `canonical` is the only source of truth.
- Every mirror sync starts from `canonical`, never from another mirror.
- `bundled` must always exist and stay in full parity with canonical packaging scope.
- `nested_bundled` may be absent, but if present it must stay in full parity with canonical and bundled.
- Installed runtime is governed separately by the runtime freshness contract and is not a repo mirror target.

## Packaging Scope

The mirror topology only applies to the governed package payload:

- top-level files: `SKILL.md`, `check.ps1`, `check.sh`, `install.ps1`, `install.sh`
- top-level directories: `config`, `protocols`, `references`, `docs`, `scripts`
- approved bundled-only exception: `docs/CODEX_ECOSYSTEM_MAINTENANCE_PRINCIPLES.md`

## Governance Gates

Topology-aware gates:

- `scripts/verify/vibe-version-packaging-gate.ps1`
- `scripts/verify/vibe-nested-bundled-parity-gate.ps1`
- `scripts/verify/vibe-mirror-edit-hygiene-gate.ps1`
- `scripts/verify/vibe-release-install-runtime-coherence-gate.ps1`

## Execution Notes

- Always run topology-aware governance scripts from the canonical repo root.
- Never treat bundled or nested mirrors as governance owners.
- If a mirror root is missing unexpectedly, fix the topology via canonical sync instead of hand-editing the mirror.

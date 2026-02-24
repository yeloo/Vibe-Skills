This directory stores optional verification scripts for CI and local smoke checks.

- `vibe-routing-smoke.ps1`: runtime-neutral terminology and M/L/XL routing behavior smoke tests.
- `vibe-pack-routing-smoke.ps1`: validates pack router config integrity, thresholds, and alias safety.
- `vibe-soft-migration-practice.ps1`: practical soft-migration checks for alias routing and legacy fallback behavior.
- `vibe-pack-regression-matrix.ps1`: broad pack-level regression matrix and determinism checks.
- `vibe-keyword-precision-audit.ps1`: bilingual keyword precision audit (EN/ZH), cross-pack interference gap checks, and full skill-by-skill routing sweep.
- `vibe-skill-index-routing-audit.ps1`: per-skill keyword index routing checks using common Chinese business phrases and ambiguous same-pack scenarios.

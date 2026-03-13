# Official Runtime Baseline Proof Bundle

This proof bundle freezes the minimum official-runtime surfaces that universalization work must not weaken.

## Included Artifacts

- `baseline-manifest.json`
- `docs/universalization/official-runtime-baseline.md`

## Protected Runtime Surfaces

- install entrypoints
- check / doctor entrypoints
- router authority
- version governance
- installed-runtime freshness and coherence verification

## Verification

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify\vibe-official-runtime-baseline-gate.ps1 -WriteArtifacts
```

Optional (if your installed runtime is not the default `~/.codex`):

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify\vibe-official-runtime-baseline-gate.ps1 -TargetRoot "D:\\path\\to\\.codex" -WriteArtifacts
```

The gate only checks the documented baseline contract and its proof bundle.
It does not install dependencies, rewrite runtime state, or claim host readiness.

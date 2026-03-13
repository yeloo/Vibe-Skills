# Route Replay Fixtures

`official-runtime-golden.json` encodes the **current official router outputs** for
a small set of high-signal prompts.

These prompts are chosen to be:

- Offline safe (no provider calls).
- Deterministic enough to act as a regression baseline.
- Representative of core routing intents (planning, review, debug, TDD, orchestration).

Validated by: `scripts/verify/vibe-cross-host-route-parity-gate.ps1`


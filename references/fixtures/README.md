# Fixture Migration Stage 2

This directory holds governed baseline fixtures mirrored from historically tracked `outputs/**` files.

## Why it exists

Wave123 moves the repository toward a clean boundary:

- runtime outputs stay in `outputs/**` and remain untracked;
- baseline fixture material moves to `references/fixtures/**`;
- legacy tracked outputs are mirrored here before strict cleanup removes them later.

## Fixture groups

- `external-corpus/`: external-corpus candidate and routing baseline fixture material
- `retro-compare/`: safety, sample-run, and smoke retro-compare baseline fixture snapshots
- `verify/routing-stability/`: routing-stability baseline fixture snapshots

## Reading rule

- treat these files as reference fixtures, not live runtime output;
- use `migration-map.json` as the source-of-truth map from tracked outputs to mirrored fixture copies;
- Stage 2 is `stage2_mirrored`, not strict deletion yet.

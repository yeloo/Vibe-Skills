# Host Capability Matrix

> Scope: execution contract for universalization, not marketing language.

## Purpose

This matrix freezes the difference between:

- official runtime ownership
- host adapter preview support
- advisory-only contract consumption

It prevents the project from collapsing all hosts into a fake "one runtime fits all" story.

## Status Vocabulary

| Status | Meaning |
| --- | --- |
| `supported-with-constraints` | repo has real host evidence and a bounded support claim, but some surfaces remain host-managed |
| `preview` | adapter contract exists, but proof bundle is incomplete |
| `not-yet-proven` | host is named in the migration target, but there is no verified runtime contract yet |
| `advisory-only` | host may consume canonical contracts, but the repo makes no runtime closure claim |

## Host Matrix

| Host | Status | Runtime Role | Settings Contract | Plugin/MCP Contract | Release Closure | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| Codex | `supported-with-constraints` | official-runtime-adapter | repo template + materialization exist | host-managed but documented | strongest current path | this is the current practical reference lane |
| Claude Code | `preview` | host-adapter-preview | template exists | mostly host-managed | not yet frozen | adapter may be built, but not marketed as full |
| OpenCode | `not-yet-proven` | future-host-adapter | none yet | none yet | none yet | no overclaim until contract + replay exist |
| Generic Host | `advisory-only` | contract-consumer | host-defined | host-defined | none | canonical skill truth can be consumed without runtime promise |

## Capability Guidance

### Codex

- Strongest current evidence for settings, install, health-check, and governed runtime payload.
- Still depends on host-managed plugin provisioning and credential provisioning.

### Claude Code

- Existing template proves configuration intent.
- No governed install/check closure lane in this repository yet.

### OpenCode

- Migration target only.
- No repository-backed capability proof yet.

### Generic Host

- Useful for future interoperability.
- Must never be described as an official runtime.

## Promotion Rule

No adapter may be promoted above its current status unless all of the following exist:

1. host profile
2. settings map
3. platform contracts
4. replay-backed verification
5. install isolation proof
6. wording parity between docs and measured support

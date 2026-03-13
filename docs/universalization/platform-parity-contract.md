# Platform Parity Contract

## Principle

Platform parity is not assumed from the presence of shell scripts.

A platform only earns a stronger support label when the repository can show:

1. install path
2. check path
3. doctor/gate path
4. degrade contract
5. measured evidence

## Current Rules

- Windows remains the authoritative official-runtime reference lane.
- Linux may be strong, but only when `pwsh` is provisioned and relevant PowerShell gates can run.
- Linux without `pwsh` is degraded, not secretly full.
- macOS remains `not-yet-proven` until a separate evidence lane exists.

## Required Parity Evidence

For each `<host, platform>` pair the project must eventually record:

- install entry points
- health check entry points
- required external prerequisites
- gated vs skipped governance surfaces
- final support label

## Anti-Overclaim Rule

The repository must never upgrade wording from:

- `supported-with-constraints`

to:

- `full-authoritative`

without corresponding gate and replay evidence.

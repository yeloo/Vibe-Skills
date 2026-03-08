# Mem0 Opt-in Backend Integration

## Role

`mem0` enters VCO as an optional external preference-memory backend.
It is not a primary session store, not a routing hint authority, and not a replacement for Serena/ruflo/Cognee.

## Allowed Payload Types

- user preference
- recurring style hint
- stable personal constraint
- reusable output preference

## Forbidden Payload Types

- route selection
- canonical project decision
- primary session state
- explicit build/test result truth
- security-sensitive raw secrets

## Operating Modes

- `off`: disabled
- `shadow`: classify payloads and emit recommendations only
- `soft`: allow opt-in writes after policy validation

## Rollback

Rollback is simple: set `config/mem0-backend-policy.json` to `off` and keep Memory Runtime v2 canonical owners unchanged.

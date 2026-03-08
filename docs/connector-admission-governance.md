# Connector Admission Governance

## Scope

Wave36 把 `awesome-mcp-servers`、`composio`、`activepieces` 统一收口到 **connector admission** 治理层，而不是让它们各自形成新的连接器控制面。

这层治理回答的问题是：

- 哪个来源只是 catalog reference；
- 哪个来源只是 provider candidate；
- 哪些 capability/risk class 可以进入 allowlist；
- 哪些动作必须保留 denylist 或 confirm gate。

## Source Roles

| Source | Position | Meaning |
|---|---|---|
| `awesome-mcp-servers` | `catalog_reference_only` | 只提供 connector scouting / catalog snapshot，不允许 auto-install |
| `composio` | `provider_candidate` | 提供 connector template / action surface，但必须先 shadow-governed |
| `activepieces` | `provider_candidate` | 提供 automation/action surface，但必须先 shadow-governed |

## Control Plane Invariants

所有 connector source 共享以下不变量：

- `control_plane_owner = vco`
- `allow_second_orchestrator = false`
- `allow_provider_takeover = false`
- `allow_auto_install_from_catalog = false`
- `require_allowlist_entry = true`
- `require_confirm_for_write = true`
- `require_shadow_first_for_new_connectors = true`

## Admission States

| Status | Meaning |
|---|---|
| `catalog_governed` | 目录类来源已进入制度化治理，但不能直接成为执行面 |
| `shadow_governed` | provider candidate 已被允许进入 shadow/advice-first 流程 |
| `allowlisted_provider` | 仅在后续明确晋升时使用，本轮不开放 |
| `denied` | 明确拒绝进入 canonical connector surface |

## Allowlist / Denylist Rule

allowlist 只记录“经过制度化审查后允许保留的 source + capability 组合”；denylist 记录永远不能让连接器来源接管的职责：

- second orchestrator（第二 orchestrator）
- route override
- auto-install from catalog
- 未确认的生产写动作
- credential exfiltration
- connector-defined memory truth source

## Matrix Usage

`references/connector-admission-matrix.md` 是运营视图；`config/connector-provider-policy.json` 是可执行视图；`scripts/verify/vibe-connector-admission-gate.ps1` 负责把两者的关键不变量固化为 gate。

## Follow-up

本轮只建立 admission governance，不改动 install/release/runtime 流程。后续若要升格任何 connector source，必须先补齐新的 docs + config + gate，并明确 rollback 路径。

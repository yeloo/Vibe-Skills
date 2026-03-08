# Connector Admission Matrix

| Source | Position | Status | Capability Scope | Risk Class | Confirm Posture | Fallback | Hard Reject |
|---|---|---|---|---|---|---|---|
| `awesome-mcp-servers` | `catalog_reference_only` | `catalog_governed` | `catalog_sync`, curated snapshot, capability tagging | `read_only_metadata` | n/a | `manual_review` | `auto_install_from_catalog`, `second_orchestrator` |
| `composio` | `provider_candidate` | `shadow_governed` | connector template, OAuth/API key actions, bounded read/write | `bounded_write` | `confirm_required` | `manual_or_existing_vco_tool` | `provider_takeover`, `unconfirmed_production_write` |
| `activepieces` | `provider_candidate` | `shadow_governed` | connector template, trigger/action graph, bounded read/write | `bounded_write` | `confirm_required` | `manual_or_existing_vco_tool` | `provider_takeover`, `unconfirmed_production_write` |

## Interpretation

- `awesome-mcp-servers` 只负责 catalog intelligence；
- `composio` 与 `activepieces` 只能以 shadow/advice-first 方式进入 admission layer；
- 本矩阵不授予任何来源 route ownership、memory ownership 或默认生产写权限。

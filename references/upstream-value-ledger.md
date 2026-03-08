# Upstream Value Ledger

| Slug | Lane | Status | Primary Value | Owner | Next Action |
|---|---|---|---|---|---|
| `activepieces` | `connector_admission` | `shadow_governed` | connector template 与 automation action surface | `vco/connector-admission` | Freeze piece categories into connector allowlist/denylist mapping and keep write actions confirm-gated. |
| `agent-s` | `desktopops_shadow_source` | `shadow_governed` | desktop shadow contract、replay pattern、failure taxonomy source | `vco/desktopops` | Keep Agent-S in shadow-first posture and distill replay / failure-handling improvements into DesktopOps contracts only. |
| `agent-squad` | `role_pack_source` | `tracked_corpus` | multi-agent role vocabulary 与 handoff patterns | `vco/role-pack-governance` | Extract reusable role vocabulary without importing a second orchestrator. |
| `antigravity-awesome-skills` | `skill_catalog_source` | `partial_absorption` | 已有 selective skill harvest 的上游技能目录 | `vco/skill-corpus` | Keep upstream mirrored and promote only proven skills into canonical bundles. |
| `awesome-agent-skills` | `skill_catalog_source` | `tracked_corpus` | agent skill catalog reference | `vco/skill-corpus` | Review agent skill cards for reusable high-signal patterns before bundling. |
| `awesome-ai-agents-e2b` | `discovery_eval_corpus` | `tracked_corpus` | agent/eval discovery examples | `vco/discovery-corpus` | Mine eval and agent examples into discovery notes rather than runtime ownership. |
| `awesome-ai-tools` | `discovery_eval_corpus` | `tracked_corpus` | ecosystem discovery list | `vco/discovery-corpus` | Use as discovery feed only; do not expose it as a runtime surface. |
| `awesome-claude-code-subagents` | `role_pack_source` | `tracked_corpus` | subagent topology reference | `vco/role-pack-governance` | Review subagent layouts for XL patterns without replacing VCO control plane. |
| `awesome-claude-skills-composio` | `skill_catalog_source` | `partial_absorption` | skill harvest source with downstream reuse | `vco/skill-corpus` | Continue selective skill harvesting under canonical pack routing and connector guardrails. |
| `awesome-mcp-servers` | `connector_admission` | `catalog_governed` | MCP server catalog / scouting feed | `vco/connector-admission` | Curate catalog snapshots into the connector admission allowlist; never auto-install from the catalog. |
| `awesome-vibe-coding` | `discovery_eval_corpus` | `tracked_corpus` | workflow discovery corpus | `vco/discovery-corpus` | Harvest workflow references into discovery and eval notes only. |
| `browser-use` | `browserops_provider_source` | `shadow_governed` | provider candidate 与 open-world browsing eval source | `vco/browserops` | Retain browser-use as an advice/shadow-first provider candidate and keep provider takeover forbidden. |
| `claude-skills` | `skill_catalog_source` | `partial_absorption` | upstream inspiration library with partial downstream reuse | `vco/skill-corpus` | Import only contract-compatible skill fragments and keep the rest mirrored as reference. |
| `composio` | `connector_admission` | `shadow_governed` | connector templates and action surfaces | `vco/connector-admission` | Map connector templates to risk classes and secret profiles before any promotion. |
| `docling` | `document_plane_contract` | `canonical_contract` | document plane primary contract source | `vco/document-plane` | Sync the canonical contract, provider policy, and recovered spec into packaged mirrors after gate pass. |
| `letta` | `memory_policy_source` | `partial_absorption` | memory-policy vocabulary 与 conformance contract source | `vco/memory-governance` | Keep Letta as a policy/vocabulary source only and convert remaining retention / conformance slices into auditable eval assets. |
| `mem0` | `memory_policy_source` | `shadow_governed` | optional preference-memory backend candidate | `vco/memory-governance` | Keep mem0 opt-in and replayable, never as canonical session or project truth-source. |
| `prompt-engineering-guide` | `prompt_contract_source` | `partial_absorption` | prompt governance source for pattern cards and review heuristics | `vco/prompt-governance` | Convert stable prompt patterns into canonical cards and risk review checklists. |
| `vibe-coding-cn` | `discovery_eval_corpus` | `tracked_corpus` | multilingual vibe-coding discovery corpus | `vco/discovery-corpus` | Keep as multilingual discovery corpus and summarize patterns instead of promoting it into runtime ownership. |

## Reading Rule

- `lane` 决定它走哪条制度化通道；
- `status` 说明当前成熟度，不代表默认 runtime ownership；
- `next_action` 必须是当前最直接、最小且可验证的收口动作；
- 所有 `Slug` 一律走 canonical alias registry，不再接受展示名直写。

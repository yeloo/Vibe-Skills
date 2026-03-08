# Role Pack Governance

## Goal

把 `agent-squad`、`claude-skills`、`awesome-agent-skills`、`awesome-claude-code-subagents`、`antigravity-awesome-skills` 的剩余价值，统一沉淀成 **VCO-native role pack governance**。

## Core Boundary

- 执行 owner 仍然只有 `Codex Native Team Runtime`；
- role pack 只规定：角色边界、输入输出、职责分工、技能质量规则；
- upstream catalog 不能变成新的 orchestration runtime。

## Absorbed Value

| Source | Absorbed Value | Landing |
|---|---|---|
| `agent-squad` | supervisor-as-tools decomposition | team-template reference |
| `claude-skills` | skill packaging heuristics | skill-authoring reference |
| `awesome-agent-skills` | role/capability taxonomy | role-card catalog |
| `awesome-claude-code-subagents` | subagent responsibility patterns | subagent pattern reference |
| `antigravity-awesome-skills` | skill quality exemplars | quality rules reference |

## Explicit Rejects

- 第二 orchestrator
- 第二 execution owner
- 直接从 upstream catalog 动态装载角色并执行
- 把 role pack 当作 routing authority

## Exit Criteria

- `config/role-pack-policy.json` 能解释吸收/拒绝边界；
- `references/role-pack-catalog.md` 能映射上游价值 -> VCO 落点；
- `vibe-role-pack-governance-gate.ps1` 能阻止越权扩张。

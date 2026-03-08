# Config Index

- Repo entry: [`../README.md`](../README.md)
- Docs entry: [`../docs/README.md`](../docs/README.md)
- References entry: [`../references/index.md`](../references/index.md)
- Cleanup umbrella: [`../docs/plans/2026-03-08-repo-full-cleanup-master-plan.md`](../docs/plans/2026-03-08-repo-full-cleanup-master-plan.md)

## What Lives Here

`config/` 保存 VCO 的 machine-readable contracts：路由阈值、pack 目录、rollout policy、quality board、cleanup/runtime 规则、mirror topology 与阶段性执行 board。

规则说明写在 `docs/`；这里存的是会被 `scripts/router/*`、`scripts/verify/*`、`scripts/governance/*` 实际执行的配置事实。

## Start Here

| File | Purpose |
| --- | --- |
| [`pack-manifest.json`](pack-manifest.json) | VCO pack routing 的主入口 |
| [`router-thresholds.json`](router-thresholds.json) | routing threshold / confidence contract |
| [`skill-alias-map.json`](skill-alias-map.json) | 兼容旧技能名与新 pack/skill 名的映射 |
| [`repo-cleanliness-policy.json`](repo-cleanliness-policy.json) | local noise / managed workset / mirror pressure 的分类规则 |
| [`outputs-boundary-policy.json`](outputs-boundary-policy.json) | `outputs/**` legacy allowlist 与 fixture migration 规则 |
| [`frontmatter-integrity-policy.json`](frontmatter-integrity-policy.json) | BOM / byte-0 frontmatter 保护面 |
| [`version-governance.json`](version-governance.json) | canonical / bundled / nested / installed runtime 的版本与 packaging contract |
| [`operator-preview-contract.json`](operator-preview-contract.json) | governance operator preview receipt contract |
| [`candidate-quality-board.json`](candidate-quality-board.json) | candidate quality board |
| [`promotion-board.json`](promotion-board.json) | capability promotion / absorption board |
| [`wave121-140-gate-manifest.json`](wave121-140-gate-manifest.json) | wave gate runner manifest example |

## Family Map

- **Routing core**：`pack-manifest.json`, `router-thresholds.json`, `skill-alias-map.json`, `skill-routing-rules.json`, `skill-keyword-index.json`.
- **Overlay / capability policy**：`prompt-overlay.json`, `memory-governance.json`, `observability-policy.json`, `role-pack-policy.json`, `browserops-provider-policy.json` 等。
- **Cleanliness / runtime / packaging**：`repo-cleanliness-policy.json`, `outputs-boundary-policy.json`, `frontmatter-integrity-policy.json`, `version-governance.json`, `execution-context-status.json`.
- **Boards / scorecards / lifecycle**：`candidate-quality-board.json`, `promotion-board.json`, `capability-catalog.json`, `capability-lifecycle-policy.json`, `role-pack-scorecard.json`.
- **Wave / rollout state**：`wave*-manifest.json`, `wave*-board.json`, `openspec-policy.json`, `gsd-overlay.json`, `upstream-value-ops-board.json`.

## Reading Order

1. 先看 [`repo-cleanliness-policy.json`](repo-cleanliness-policy.json)、[`outputs-boundary-policy.json`](outputs-boundary-policy.json)、[`version-governance.json`](version-governance.json) 建立 repo plane 边界。
2. 再看 [`pack-manifest.json`](pack-manifest.json)、[`router-thresholds.json`](router-thresholds.json)、[`skill-alias-map.json`](skill-alias-map.json) 理解路由主链。
3. 再看 board / scorecard / lifecycle 系列文件理解 capability admission、promotion 与 rollout。

## Rules

- 新增 config 文件时，必须在本 index 登记，并至少补一条 docs 或 scripts 反向锚点。
- 不要把运行时 receipt、telemetry、dashboard 数据写进 `config/`。
- mirror / install / release 相关 contract 修改后，必须复跑对应 verify gates。

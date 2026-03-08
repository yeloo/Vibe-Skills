# VCO References Index

Navigation guide for VCO contracts, registries, matrices, ledgers, scenarios, and overlay reference packs.

## Start Here

| Asset | Purpose |
| --- | --- |
| [reference-asset-taxonomy.md](reference-asset-taxonomy.md) | `references/` 的正式分类、命名约定与维护规则 |
| [unified-task-contract.md](unified-task-contract.md) | 跨平面任务合同的 cleanup-first 入口 |
| [mirror-topology.md](mirror-topology.md) | canonical / bundled / nested mirror topology 参考基线 |
| [changelog.md](changelog.md) | 参考层变更账本与长期演进轨迹 |
| [../docs/README.md](../docs/README.md) | 治理正文 / 集成说明 / plans / releases 总入口 |
| [../scripts/verify/gate-family-index.md](../scripts/verify/gate-family-index.md) | `scripts/verify/` gate family 导航与推荐运行顺序 |
| [../docs/plans/2026-03-08-repo-cleanliness-batch2-4-triage.md](../docs/plans/2026-03-08-repo-cleanliness-batch2-4-triage.md) | cleanup-first 的 Batch 2-4 拆分与 stop rules |
| [../docs/plans/2026-03-08-repo-full-cleanup-master-plan.md](../docs/plans/2026-03-08-repo-full-cleanup-master-plan.md) | full-repo cleanup umbrella plan；定义 batch0-9 的 plane-governance 收口顺序 |
| [fixtures/README.md](fixtures/README.md) | fixture migration stage2 的 baseline / migration map 入口 |
| [overlays/index.md](overlays/index.md) | overlay reference packs 的统一导航入口 |

## Contracts / Handbooks

| Asset | Purpose |
| --- | --- |
| [unified-task-contract.md](unified-task-contract.md) | VCO 统一任务合同 |
| [tool-rule-contract.md](tool-rule-contract.md) | 工具 / 规则约束合同 |
| [memory-block-contract.md](memory-block-contract.md) | memory block / tier 结构合同 |
| [memory-runtime-v3-contract.md](memory-runtime-v3-contract.md) | memory runtime v3 合同 |
| [browser-task-contract.md](browser-task-contract.md) | browser task contract |
| [openworld-task-contract.md](openworld-task-contract.md) | open-world runtime task contract |
| [gate-keyword-alias-contract.md](gate-keyword-alias-contract.md) | gate/document keyword alias contract |
| [eval-replay-ledger-contract.md](eval-replay-ledger-contract.md) | replay / audit ledger contract |
| [conflict-rules.md](conflict-rules.md) | 跨平面冲突仲裁手册 |
| [manual-apply-checklist.md](manual-apply-checklist.md) | 手工 apply / exception checklist |

## Registries / Catalogs

| Asset | Purpose |
| --- | --- |
| [tool-registry.md](tool-registry.md) | VCO tool registry |
| [capability-catalog.md](capability-catalog.md) | capability surface 总目录 |
| [role-pack-catalog.md](role-pack-catalog.md) | role-pack v1 catalog |
| [role-pack-catalog-v2.md](role-pack-catalog-v2.md) | role-pack v2 catalog |
| [discovery-intake-watchlist.md](discovery-intake-watchlist.md) | discovery intake watchlist |
| [connector-capability-matrix.md](connector-capability-matrix.md) | connector 与 capability 的映射入口 |

## Matrices / Scorecards

| Asset | Purpose |
| --- | --- |
| [connector-admission-matrix.md](connector-admission-matrix.md) | connector admission 决策矩阵 |
| [capability-dedup-matrix.md](capability-dedup-matrix.md) | capability overlap / owner / dedup 基线 |
| [capability-lifecycle-matrix.md](capability-lifecycle-matrix.md) | capability lifecycle 状态矩阵 |
| [candidate-quality-scorecards.md](candidate-quality-scorecards.md) | candidate 质量评分 |
| [browser-provider-scorecard.md](browser-provider-scorecard.md) | browser provider 评分卡 |
| [plane-scorecards.md](plane-scorecards.md) | memory / browser / desktop / document 等平面评分卡 |
| [subagent-pattern-scorecard.md](subagent-pattern-scorecard.md) | subagent pattern 质量评分 |
| [skill-distillation-scorecard.md](skill-distillation-scorecard.md) | skill distillation 评分标准 |
| [upstream-reaudit-matrix-v2.md](upstream-reaudit-matrix-v2.md) | upstream re-audit 矩阵 |

## Ledgers / Evidence / Changelog

| Asset | Purpose |
| --- | --- |
| [release-ledger.jsonl](release-ledger.jsonl) | release ledger |
| [release-evidence-bundle-contract.md](release-evidence-bundle-contract.md) | release evidence bundle contract |
| [changelog.md](changelog.md) | append-only reference changelog |
| [connector-action-ledger.md](connector-action-ledger.md) | connector action ledger |
| [cross-plane-replay-ledger.md](cross-plane-replay-ledger.md) | replay 证据账本 |
| [upstream-value-ledger.md](upstream-value-ledger.md) | upstream value extraction ledger |
| [rollout-proposal-contract.md](rollout-proposal-contract.md) | rollout proposal contract |

## Scenarios / Checklists / Quality Bars

| Asset | Purpose |
| --- | --- |
| [memory-eval-scenarios.md](memory-eval-scenarios.md) | memory quality / replay 场景 |
| [prompt-eval-scenarios.md](prompt-eval-scenarios.md) | prompt intelligence 场景 |
| [openworld-eval-scenarios.md](openworld-eval-scenarios.md) | open-world runtime 评测场景 |
| [connector-simulation-scenarios.md](connector-simulation-scenarios.md) | connector sandbox / simulation 场景 |
| [document-golden-corpus.md](document-golden-corpus.md) | 文档平面 golden corpus |
| [document-failure-taxonomy.md](document-failure-taxonomy.md) | document failure taxonomy |
| [prompt-risk-checklist.md](prompt-risk-checklist.md) | prompt risk checklist |
| [upstream-distillation-quality-bar.md](upstream-distillation-quality-bar.md) | upstream distillation quality bar |

## Overlay Packs

| Folder | Purpose |
| --- | --- |
| [overlays/turix-cua](overlays/turix-cua) | BrowserOps / CUA foundation 与 runbook |
| [overlays/gitnexus](overlays/gitnexus) | GitNexus foundation / architecture / impact / detect-changes |
| [overlays/ruc-nlpir](overlays/ruc-nlpir) | FlashRAG / WebThinker / DeepAgent overlay references |
| [overlays/agency](overlays/agency) | agency-style role overlays |

## Wave Execution Backlog Anchors

| Wave Set | Primary Assets |
| --- | --- |
| Wave19-30 | [../docs/plans/2026-03-07-vco-full-spectrum-integration-plan.md](../docs/plans/2026-03-07-vco-full-spectrum-integration-plan.md) |
| Wave31-39 | [../docs/plans/2026-03-07-vco-deep-value-extraction-drift-closure-plan.md](../docs/plans/2026-03-07-vco-deep-value-extraction-drift-closure-plan.md) |
| Wave40-63 | [../docs/plans/2026-03-07-vco-wave40-63-execution-plan.md](../docs/plans/2026-03-07-vco-wave40-63-execution-plan.md), [../config/wave40-63-planning-board.json](../config/wave40-63-planning-board.json) |
| Wave64-82 | [../docs/plans/2026-03-07-vco-wave64-82-execution-plan.md](../docs/plans/2026-03-07-vco-wave64-82-execution-plan.md), [../config/wave64-82-planning-board.json](../config/wave64-82-planning-board.json) |
| Wave83-100 | [../docs/plans/2026-03-07-vco-wave83-100-execution-plan.md](../docs/plans/2026-03-07-vco-wave83-100-execution-plan.md), [../docs/plans/2026-03-07-vco-wave83-100-execution-status.md](../docs/plans/2026-03-07-vco-wave83-100-execution-status.md) |

## Reading Order

1. 先看 [reference-asset-taxonomy.md](reference-asset-taxonomy.md) 了解资产类型；
2. 再看 [tool-registry.md](tool-registry.md)、[unified-task-contract.md](unified-task-contract.md)、[mirror-topology.md](mirror-topology.md)、[changelog.md](changelog.md) 建立 cleanup-first 基线；
3. 然后按 registry / catalog 理解“当前拥有哪些能力与规则面”；
4. 再按 matrix / scorecard 理解 admission、dedup、quality；
5. 最后进入 contract、scenario、overlay packs 做深读。

## Maintenance Rules

- 新增 reference 资产必须进入本 index。
- 新增 ledger / scorecard / contract 时，需至少补一个对应的 docs 或 gate 锚点。
- 不把 wave 执行正文塞进 `references/`；波次执行文档只放 `docs/plans/`。

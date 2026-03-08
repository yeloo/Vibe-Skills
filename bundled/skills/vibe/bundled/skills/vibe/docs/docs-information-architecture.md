# Docs Information Architecture

## Why This Exists

`docs/` 已经从少量治理说明扩展为 VCO 的正式知识平面：既包含长期治理合同，也包含 plane integration、运行时规范、执行计划与 release 证据入口。

cleanup-first 的目标不是一次性大搬家，而是在**不引入额外漂移**的前提下，先稳定目录语义与导航入口。

## Directory Contract

| Path | Role | What Belongs Here |
| --- | --- | --- |
| `docs/*.md` | 治理正文 / 集成设计 | 长期有效的 governance、integration、runtime、ops、productization 文档 |
| `docs/plans/*.md` | 执行计划 / triage / status | wave backlog、batch triage、执行状态、阶段性推进文档 |
| `docs/releases/*.md` | Release evidence | release notes、cut 记录、installed runtime 检查说明 |
| `docs/external-tooling/*` | 外部边界说明 | MCP / skill / provider / manual 等职责边界说明 |
| `docs/*.md`（archive-layer） | 历史报告 / 审计 / 草稿 | `*-report.md`、`*-audit*.md`、`*-recheck-*.md`、`*-draft.md`、`*-batch-plan.md`；暂时可留在 root，但必须在 `docs/README.md` 的 Archive 区明确索引 |

## Document Type Taxonomy

| Pattern | Meaning | Example |
| --- | --- | --- |
| `*-governance.md` | 稳定治理合同、stop rules、entry/exit criteria | `repo-cleanliness-governance.md` |
| `*-integration.md` | 某能力 / 平面 / upstream 资源与 VCO 的集成设计 | `browserops-provider-integration.md` |
| `*-productization.md` | 从试点走向长期能力面的收口设计 | `prompt-intelligence-productization.md` |
| `*-design.md` / `architecture.md` | 结构设计、建模与分析 | `deep-discovery-mode-design.md` |
| `*-report.md` / `*-audit*.md` / `*-recheck-*.md` | 阶段性调查、审计或重检产物（archive-layer） | `hard-migration-batch-a-report.md` |
| `*-draft.md` / `*-batch-plan.md` | 草稿或迁移过渡材料（archive-layer） | `gitnexus-mcp-integration-draft.md` |
| `plans/*.md` | 时间绑定的执行文档 | `plans/2026-03-08-repo-cleanliness-batch2-4-triage.md` |
| `releases/*.md` | release cut / note / install evidence | `releases/v2.3.30.md` |

## Navigation Rules

1. `docs/README.md` 是 `docs/` 的稳定入口；新增 root 文档时必须补导航。
2. `plans/` 与 `releases/` 不再混入 governance spine；root `docs/` 只保留长期正文。
3. 若某文档存在对应 gate / config / reference，至少补一条反向锚点：
   - doc -> script/config/reference
   - README / index -> doc
4. 不以“波次”作为唯一分类方式；优先按**治理主题**与**资产角色**归档。
5. `*-report.md` / `*-audit*.md` / `*-recheck-*.md` / `*-draft.md` / `*-batch-plan.md` 视为 archive-layer：即使暂时仍在 root `docs/`，也必须通过 `docs/README.md` 的 Archive 区索引，而不能混入 Governance Spine。

## Cleanup-First Maintenance Rules

- 先补 README / taxonomy / index，再考虑 rename。
- 同义文档允许暂时共存，但必须在 README 中解释“谁是主入口、谁是阶段报告”。
- 阶段性报告不升级为治理总纲，除非明确被新的 governance 文档吸收。
- 若某新文档没有进入 README，就视为未完成收口。

## Cross-Layer Linkage

`docs/` 不是孤立层，需与以下层面保持可追踪关系：

- `references/`：contracts、matrix、registry、ledger 资产；
- `scripts/verify/`：对治理合同的可执行 gate；
- `scripts/governance/`：sync / release / rollout / policy operator surface；
- `scripts/common/`：共享 no-BOM / execution-context / wave runner 原语；
- `config/`：machine-readable policy / planning board / rollout switch；
- `bundled/`：仅通过 canonical sync 继承，不在 mirror 侧单独组织。

## Current Cleanup Focus

当前 cleanup-first 批次优先稳定四条主线：

1. `docs/README.md`：让 governance、plans、releases、archive-layer 的入口分层清晰；
2. `references/index.md`：把 registry / matrix / contract / ledger 从散列状态提升为可导航资产层；
3. `scripts/verify/README.md`：建立 gate family 视图，减少“只能按文件名记忆”的使用成本；
4. `scripts/governance/README.md` / `scripts/common/README.md`：补齐 operator surface 与 shared primitives 的目录闭环。

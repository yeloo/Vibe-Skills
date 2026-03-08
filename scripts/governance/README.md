# Governance Scripts

- Scripts root: [`../README.md`](../README.md)
- Verify gates: [`../verify/README.md`](../verify/README.md)
- Shared primitives: [`../common/README.md`](../common/README.md)

## What Lives Here

`scripts/governance/` 是 VCO 的 operator surface：负责 **sync / rollout / release / policy advice / upstream audit**。

这里的脚本与 `scripts/verify/` 的区别在于：verify 负责“判定是否通过”，governance 负责“执行或编排操作”。

## Execution Context

- 涉及 mirror / packaging / release 的脚本必须从 canonical repo 运行。
- 已采用 `Get-VgoGovernanceContext -EnforceExecutionContext` 的脚本会主动阻止 mirror tree 误执行；其他 operator 也应逐步收敛到同一机制。
- 文本写入统一遵循 UTF-8 without BOM；优先复用 [`../common/vibe-governance-helpers.ps1`](../common/vibe-governance-helpers.ps1)。

## Command Index

| Script | Family | Mutates state | Preview mode | Output | Notes |
| --- | --- | --- | --- | --- | --- |
| [`sync-bundled-vibe.ps1`](sync-bundled-vibe.ps1) | mirror / packaging | yes | `-Preview` | host + preview receipt | canonical -> bundled -> nested mirror sync |
| [`install-local-worktree-excludes.ps1`](install-local-worktree-excludes.ps1) | cleanliness | yes | `-DryRun` | host | writes `.git/info/exclude` local-only patterns |
| [export-repo-cleanliness-inventory.ps1](export-repo-cleanliness-inventory.ps1) | cleanliness inventory | no | n/a | json + artifacts | exports plane split / top dirty prefixes / bucket summary for cleanup triage |
| [`release-cut.ps1`](release-cut.ps1) | release | yes | no explicit preview yet | host | updates version governance, changelog, release note, ledger, then syncs mirrors |
| [`set-openspec-rollout.ps1`](set-openspec-rollout.ps1) | rollout toggle | yes | `-WhatIf` | json | adjusts OpenSpec rollout stage |
| [`set-gsd-overlay-rollout.ps1`](set-gsd-overlay-rollout.ps1) | rollout toggle | yes | `-WhatIf` | json | adjusts GSD overlay rollout stage |
| [`publish-openspec-soft-rollout.ps1`](publish-openspec-soft-rollout.ps1) | rollout publish | yes | `-SkipPrecheck` as control, no dry-run | json | runs precheck -> switch -> postcheck sequence |
| [`publish-absorption-soft-rollout.ps1`](publish-absorption-soft-rollout.ps1) | promotion board write | conditional (`-WriteBoard`) | advice-first by default | host/json-like | evaluates board eligibility; only writes when explicitly asked |
| [`invoke-openspec-governance.ps1`](invoke-openspec-governance.ps1) | policy advice | no | n/a | json | emits planning advice / lite cards / task metadata |
| [`invoke-mem0-policy.ps1`](invoke-mem0-policy.ps1) | policy probe | no | n/a | json | checks payload admission against mem0 policy |
| [`audit-upstream.ps1`](audit-upstream.ps1) | audit / reporting | writes artifacts only | read-mostly | host + artifacts | audits upstream corpus / mirrors / installed plugins |

## Operator Run Order

1. **Precheck**：先从 [`../verify/README.md`](../verify/README.md) 选择对应 gate family，确认本次操作的 stop-ship 边界。
2. **Inventory / preview / advice-first**：当前 dirty 状态不清楚时，先运行 `export-repo-cleanliness-inventory.ps1 -WriteArtifacts`，再使用 `-WhatIf` / `-DryRun` / advice-first 路径。
3. **Apply**：只有在 preview / gate 结果可接受时，才执行真正写入。
4. **Postcheck**：操作完成后立即重跑对应 gates，确保 mirror / packaging / release evidence 没有漂移。

## Maintenance Notes

- 后续清理重点不是新建更多 operator，而是统一 preview 语义、machine-readable 输出、canonical execution lock 与 no-BOM 写入。
- 若新增 operator 脚本，必须在本 README 的索引表登记 `mutates / preview / output / notes`。

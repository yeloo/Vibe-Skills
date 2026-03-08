# Overlay Suggestion Scripts

- Scripts root: [`../README.md`](../README.md)
- Overlay references: [`../../references/overlays/index.md`](../../references/overlays/index.md)

## What Lives Here

`scripts/overlay/` 提供 advice-first overlay 建议脚本：根据当前任务上下文输出推荐的 external overlay / provider / role reference，不直接改变 router assignment。

## Current Scripts

| Script | Purpose |
| --- | --- |
| [`suggest-agency-overlays.ps1`](suggest-agency-overlays.ps1) | 建议 agency role overlays |
| [`suggest-browserops-provider.ps1`](suggest-browserops-provider.ps1) | 建议 BrowserOps provider |
| [`suggest-gitnexus-overlays.ps1`](suggest-gitnexus-overlays.ps1) | 建议 GitNexus overlays |
| [`suggest-turix-cua-overlays.ps1`](suggest-turix-cua-overlays.ps1) | 建议 TuriX-CUA overlays |
| [`suggest-vco-overlays.ps1`](suggest-vco-overlays.ps1) | 建议 VCO overlay set |

## Rule

- overlay suggestion 是 advisory surface，不是第二路由器；
- 若脚本需要新的 overlay reference，先更新 `references/overlays/index.md`。

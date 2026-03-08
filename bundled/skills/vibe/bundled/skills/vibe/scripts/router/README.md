# Router Surface

- Scripts root: [`../README.md`](../README.md)
- Config index: [`../../config/index.md`](../../config/index.md)

## What Lives Here

`scripts/router/` 保存 VCO 路由决策面：pack route 解析、legacy compatibility、以及为 router 提供的模块化 helper。

## Current Layout

| Path | Role |
| --- | --- |
| [`resolve-pack-route.ps1`](resolve-pack-route.ps1) | 主路由入口；产出 pack / skill 选择、overlay advice 与 confirm-required 信息 |
| [`legacy/`](legacy) | 兼容旧 routing 路径的辅助实现 |
| [`modules/`](modules) | router 可复用模块与分析原语 |

## Rule

- router 目录解释“如何判定与输出路由结果”；具体执行与验证仍分别落到 `scripts/governance/` 与 `scripts/verify/`。
- 新增 router helper 时，优先补 `modules/` 级文档，而不是把说明塞进单个脚本顶部。

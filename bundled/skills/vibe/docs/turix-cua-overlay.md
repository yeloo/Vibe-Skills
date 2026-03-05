# TuriX‑CUA overlay（Computer Use Agent，advice-only）接入 VCO

## 目标

把 `TuriX‑CUA` 作为 **“真实 UI/浏览器操作”** 的可选执行路径，以 **prompt overlay** 的形式接入 VCO：

- VCO 仍负责：Grade 路由、协议（think/do/review/team/retro）、工具链与质量闸门（P5/V2/V3）。
- overlay 只负责：帮助你在“必须操作 UI”的任务里快速做出 **CUA vs Playwright vs API** 的选择，并约束交付物与回退策略。

## 设计原则（避免冲突）

- **advice-only**：不改变 VCO 的路由/协议/工具选择，只影响“视角与交付物格式”。
- **组合上限**：默认最多选 2 个 overlay（典型：`turix-cua` + `agency-testing`）。
- **不阻塞**：CUA 不可用时必须自动回退（Playwright/API/人工 SOP），不影响交付推进。

## 上游来源（reference）

- `https://github.com/TurixAI/TuriX-CUA`（MIT）

> 本仓库不 vendoring 上游代码；只保留“可注入的 overlay 模板 + 自动建议脚本”。

## overlay 定义位置

- 配置：`config/turix-cua-overlays.json`
- 模板：`references/overlays/turix-cua/*.md`

当前包含两个 overlay：

- `turix-cua-foundation`：决策树 + 交付物格式 + 回退策略
- `turix-cua-runbook`：最小运行步骤（建议外置执行）+ artifacts 要求

## 自动建议 → 确认 → 注入：如何使用

### 1) 单独建议（只看 TuriX‑CUA）

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/overlay/suggest-turix-cua-overlays.ps1 `
  -Task "写你的任务描述" `
  -Stage do
```

选择并渲染注入文本（最多 1 个）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/overlay/suggest-turix-cua-overlays.ps1 `
  -Task "写你的任务描述" `
  -Stage do `
  -Select "1"
```

### 2) 统一入口（与 GitNexus / agency 共同候选）

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/overlay/suggest-vco-overlays.ps1 `
  -Task "写你的任务描述" `
  -Stage do
```

渲染注入（最多选 2 个）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/overlay/suggest-vco-overlays.ps1 `
  -Task "写你的任务描述" `
  -Stage do `
  -Select "1,2"
```

## 推荐组合（常用）

- UI/流程任务：`turix-cua-foundation` + `agency-testing`
- 代码改动任务：`gitnexus-foundation` + `agency-testing`

## 已知限制（重要）

- 上游 `TuriX‑CUA` 当前偏 `mac_agent_env`（屏幕录制权限 + `pyobjc/pycocoa` 等）。
- 在 Windows 环境建议把它当作“可选外部执行器”（或用 Mac runner），默认仍以 Playwright 作为确定性基线。


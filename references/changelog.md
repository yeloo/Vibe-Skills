# VCO Changelog

## v2.2.8 (2026-02-24)

- 完成 Batch E 最终硬清理（final cleanup）并切换到 canonical-only 运行态：
  - `config/skill-alias-map.json` 清空为 `{}`，停止 legacy alias 运行时解析
  - `bundled/skills/vibe/config/skill-alias-map.json` 同步为 canonical-only，消除 main/bundled 漂移
- 清理 Batch E 阻断项并统一 canonical 路由：
  - `spec-kit-vibe-compat/command-map.json`：`code-review3 -> code-review`
  - `security-reviewer/SKILL.md`、`think-harder/SKILL.md`：移除 `code-review3` 依赖表述
  - `scripts/verify/vibe-soft-migration-practice.ps1`、`vibe-pack-regression-matrix.ps1`：改为 canonical RequestedSkill 场景
  - `scripts/verify/vibe-pack-routing-smoke.ps1`：修复 alias 为空场景的布尔断言
- 安装器收口为 canonical-first：
  - `install.ps1`、`install.sh` 均优先 `skills/<name>`，仅将 `superpowers/skills/<name>` 作为 fallback
- 新增最终清理报告：
  - `docs/hard-migration-batch-e-final-cleanup-report.md`
- 审计留痕策略：
  - `config/batch-e-alias-whitelist.json` 标记为 historical snapshot（仅审计留痕，不参与运行时路由）
  - `docs/hard-migration-batch-e-alias-whitelist-audit.md` 标记为已被 final cleanup report 取代
- 全套验证通过：
  - `vibe-routing-smoke.ps1`: `38/38`
  - `vibe-pack-routing-smoke.ps1`: `49/49`
  - `vibe-skill-index-routing-audit.ps1`: `93/93`
  - `vibe-keyword-precision-audit.ps1`: `982/982`
  - `vibe-pack-regression-matrix.ps1`: `24/24`
  - `vibe-soft-migration-practice.ps1`: `11/11`

## v2.2.7 (2026-02-24)

- 完成 Batch E「可删 alias 白名单生成 + 影响面审计（不删先审）」：
  - 新增 `config/batch-e-alias-whitelist.json`（28 个 alias 风险分层与分阶段删除门禁）
  - 新增 `docs/hard-migration-batch-e-alias-whitelist-audit.md`（影响面审计报告）
- 验证阶段补充编码兼容性加固（Windows PowerShell）：
  - `scripts/router/resolve-pack-route.ps1` 显式 `-Encoding UTF8` 读取 JSON 配置
  - `scripts/verify/vibe-pack-routing-smoke.ps1` 显式 `-Encoding UTF8` 读取 JSON 配置
  - `scripts/verify/vibe-routing-smoke.ps1` 显式 `-Encoding UTF8` 读取文档
- 审计结论（当前不删除）：
  - 低风险可删候选（E2，门禁后执行）：`15`
  - 中风险延后（E3）：`11`
  - 高风险延后（E4）：`2`（`code-review3`、`xlsx1`）
- 关键阻断点：
  - 验证脚本仍显式依赖 `code-review3`、`xlsx1`
  - `spec-kit-vibe-compat` 与部分 SKILL 文档仍引用 `code-review3`
  - `dependency-map.json` 仍包含 `superpowers/skills/*` 路径耦合
- Batch E 当前阶段为 audit-only，不执行 alias 删除；后续删除需通过全套路由/精度/回归验证门禁。

## v2.2.6 (2026-02-24)

- 完成 Batch C/D 硬迁移候选裁剪（pack-level candidate pruning）：
  - `data-ml`: `52 -> 25`
  - `research-design`: `45 -> 25`
  - `ai-llm`: `13 -> 11`
  - `bio-science`: `34 -> 21`
  - `docs-media`: `22 -> 16`
  - `integration-devops`: `14 -> 12`
  - Batch C/D 合计：`180 -> 110`（减少 `70`, `38.89%`）
- 保持不变：
  - grade/task 边界
  - alias 映射
  - fallback 阈值与机制
- 变更前快照：
  - `outputs/backups/pack-manifest-pre-batch-cd-20260224-225014.json`
- 新增报告：
  - `docs/hard-migration-batch-cd-pruning-report.md`
- 验证通过：
  - `vibe-routing-smoke.ps1`: `38/38`
  - `vibe-pack-routing-smoke.ps1`: `104/104`
  - `vibe-skill-index-routing-audit.ps1`: `93/93`
  - `vibe-keyword-precision-audit.ps1`: `982/982`
  - `vibe-pack-regression-matrix.ps1`: `24/24`

## v2.2.5 (2026-02-24)

- 完成 Hard Migration Batch A2（bundled overlap 清理）：
  - 删除 `skills/vibe/bundled/skills` 下 8 个与 canonical 重复目录
  - 删除 `skills/vibe/bundled/superpowers-skills` 下 7 个与 canonical 重复目录
  - 保留 `bundled/skills/vibe` 作为 bundled 入口
- 硬迁移前新增目录级备份：
  - `outputs/backups/skills-pre-hard-migration-20260224-224135.zip`
- 为避免迁移后安装流程断裂，升级安装脚本 fallback：
  - `install.ps1`、`install.sh` 改为优先 canonical 路径，缺失时回退 bundled 路径
- 新增迁移报告：
  - `docs/hard-migration-batch-a2-report.md`
- 验证通过：
  - `vibe-routing-smoke.ps1`: `38/38`
  - `vibe-pack-routing-smoke.ps1`: `104/104`
  - `vibe-skill-index-routing-audit.ps1`: `93/93`
  - `vibe-keyword-precision-audit.ps1`: `1402/1402`
  - `vibe-pack-regression-matrix.ps1`: `24/24`
  - `check.ps1` (after install): `21 passed, 0 failed`

## v2.2.4 (2026-02-24)

- 基于全局历史日志语言习惯，追加 per-skill 中文业务短语索引（仅增量，不删除旧关键词）：
  - `vibe`
  - `writing-plans`
  - `verification-quality-assurance`
  - `mcp-integration`
  - `scikit-learn`
  - `biopython`
- 处理同 pack 内选择抖动：补充 `writing-plans` 的迁移场景短语（如“先做软迁移”“验证命中稳定”）。
- main/bundled 配置已同步：
  - `config/skill-keyword-index.json`
  - `bundled/skills/vibe/config/skill-keyword-index.json`
- 全套验证通过（补丁后）：
  - `vibe-skill-index-routing-audit.ps1`: `93/93`
  - `vibe-keyword-precision-audit.ps1`: `1402/1402`
  - `vibe-pack-regression-matrix.ps1`: `24/24`
- 追加专项对比报告：
  - `outputs/routing-audit/per-skill-chinese-index-comparison-report.md`
  - 命中率（专项短语集）`8/12 -> 12/12`，无新增回归。

## v2.2.3 (2026-02-24)

- 新增 per-skill 关键词索引配置：`config/skill-keyword-index.json`
  - 面向常见中文业务短语（如“修改xlsx工作簿”“会议录音转文字”“查询OpenAI文档”“单细胞分析”“修复GitHub Actions CI”等）
  - 用于降低同 pack 内 skill 选择抖动
- 路由器升级：`scripts/router/resolve-pack-route.ps1`
  - Pack 评分新增 `skill_keyword_signal`（来自 per-skill 索引的 pack 前置信号）
  - Pack 内 skill 选择改为 keyword ranking（显式 RequestedSkill 仍最高优先）
  - 同分时优先 `keyword_score`，减少名称匹配导致的泛化偏置
- 调整配置：
  - `router-thresholds.json` 增加 `weights.skill_keyword_signal`
  - `pack-manifest.json` 进一步补全中英文 trigger（录音/说话人、差异表达/BAM/VCF、Responses API、IMRAD、准实验等）
- 新增专项验证脚本：`scripts/verify/vibe-skill-index-routing-audit.ps1`
  - 覆盖 30+ 组中英文业务短语场景
  - 校验 pack 命中、skill 命中和选择稳定性
- `vibe-pack-routing-smoke.ps1` 增加 skill-index 配置完整性断言
- main/bundled 配置保持同步（含新增 `skill-keyword-index.json`）

## v2.2.2 (2026-02-24)

- 完成迁移后关键词精度专项整治（目标：中英文命中、降互扰、全量 skill 可达）
- 路由匹配器增强：`scripts/router/resolve-pack-route.ps1`
  - 新增 `Test-KeywordHit` 统一命中函数
  - 英文关键词改为 token boundary 匹配，减少 substring 误命中
  - CJK 关键词保持 substring 匹配，提升中文稳定命中
- `config/pack-manifest.json` 为 8 个 pack 全量补齐中英文 `trigger_keywords`
- 新增全量审计脚本：`scripts/verify/vibe-keyword-precision-audit.ps1`
  - 校验每个 pack 至少包含中英关键词
  - 校验 EN/ZH pack 级路由与 top1-top2 干扰间隔
  - 校验全部 223 个候选 skill 的 EN/ZH 定向命中稳定性
- 更新回归矩阵基线：`scripts/verify/vibe-pack-regression-matrix.ps1`（bio-science fallback 断言与当前阈值一致）
- 更新验证文档入口：`scripts/verify/README.md`
- 同步 bundled 配置，保持 main/bundled 无漂移

## v2.2.1 (2026-02-24)

- 完成 Soft Migration Batch B 扩容（保留 soft migration 语义，不执行 hard delete）
- `pack-manifest.json` 扩展到 near-full canonical 覆盖，8 个 pack 候选总数提升到 223
- `router-thresholds.json` 将 `max_skill_candidates_per_pack` 从 `7` 调整到 `80`
- 同步 bundled 配置副本，避免 main/bundled 漂移：
  - `bundled/skills/vibe/config/pack-manifest.json`
  - `bundled/skills/vibe/config/router-thresholds.json`
- 新增扩容验证报告：`docs/soft-migration-batch-b-expansion-report.md`
- 四项验证脚本全通过（routing/pack smoke/practice/regression matrix）

## v2.2.0 (2026-02-24)

- 完成 Hard Migration Batch A（在软迁移验证通过后执行）
- 删除顶层重复目录：
  - `skills/code-review1`
  - `skills/code-review2`
  - `skills/code-review3`
  - `skills/code-review4`
  - `skills/xlsx1`
- 保留 canonical 目录与 alias 映射，未破坏 fallback 路径
- 新增迁移报告：`docs/hard-migration-batch-a-report.md`

## v2.1.1 (2026-02-24)

- 新增软迁移路由解析器：`scripts/router/resolve-pack-route.ps1`
- 新增软迁移实践测试：`scripts/verify/vibe-soft-migration-practice.ps1`
- 新增软迁移执行手册：`docs/soft-migration-playbook.md`
- 更新 verify README 与 references index，纳入软迁移验证入口

## v2.1.0 (2026-02-24)

- 新增 Pack Router 融合层：在 Grade×TaskType 路由后执行 pack 评分与候选 skill 选择
- 新增路由配置文件：
  - `config/pack-manifest.json`
  - `config/skill-alias-map.json`
  - `config/router-thresholds.json`
- 新增大型重构主计划：`docs/skills-consolidation-roadmap.md`
- 新增 Pack 路由 smoke 校验脚本：`scripts/verify/vibe-pack-routing-smoke.ps1`
- 更新 `SKILL.md` 与 references 文档，明确 pack 路由边界和低置信度回退到 legacy matrix

## v2.0.10 (2026-02-24)

- 将决策提问接口从 `AskUserQuestion` 重构为 runtime-neutral `user_confirm interface`
- 将状态记录从 `TodoWrite` 重构为 runtime-neutral `state_store` 抽象
- 同步更新核心文档与 bundled 副本（SKILL / protocols / references / hooks）
- 新增自动化快速自测脚本，覆盖 M/L/XL 三个 `/vibe` 路由场景与关键约束断言

## v2.0.9 (2026-02-24)

- 删除 XL 设计中的 legacy compatibility orchestration 描述，统一为 Codex native agent runtime + ruflo 协作
- team.md 移除 compatibility orchestration option，仅保留 Native+ruflo 与 Native-only 路径
- fallback-chains.md 移除 compatibility Level，XL 仅保留 Native+ruflo -> Native-only -> L-grade sequential
- conflict-rules.md Rule 1 移除 compatibility agent system 条目
- tool-registry.md 移除 compatibility orchestration 集成描述，聚焦 ruflo 与 native team runtime

## v2.0.8 (2026-02-24)

- XL 标准路径明确为 `spawn_agent` / `send_input` / `wait` / `close_agent` 与 ruflo 协作（workflow/memory/consensus）
- team.md orchestration options 调整为：A=Native+ruflo（首选），B=Native-only（ruflo 不可用）
- fallback-chains.md 的 XL 链路更新为 Native+ruflo 优先，并补充 ruflo 不可用时的 native-only 降级
- conflict-rules.md Rule 1 更新为 XL=Native+ruflo 主路径，补充 native-only 分支
- team-templates.md 全量迁移为 native agent type (`default`/`explorer`/`worker`) 与 `send_input` 通信语义
- review.md 移除 `Task tool + subagent_type` 的旧表述，改为单代理直接调用 code-reviewer

## v2.0.7 (2026-02-24)

- XL execution primary path switched to Codex native agent orchestration (`spawn_agent` / `send_input` / `wait` / `close_agent`)
- Legacy compatibility fallback path downgraded from primary XL design
- Added explicit `build-error-resolver -> error-resolver` compatibility mapping in fallback and tool-detection guidance
- Updated team protocol role mapping to native agent types (`default`, `explorer`, `worker`)

## v2.0.6 (2026-02-22)

- C1 修复 conflict-rules.md Rule 1 与 Tool Selection 矩阵矛盾——M 级从"Everything-CC agents"改为"single-agent tools（允许 sc:design/systematic-debugging 等 skill commands，禁止 subagent spawning）"
- C2 修复 L 级 Dialectic Mode 使用只读 Plan agent 的问题——改为 general-purpose agent
- C3 在 SKILL.md Section 2 Tool Selection 矩阵下方添加 Excluded tools 说明（sc:implement 禁令）

## v2.0.5 (2026-02-22)

- Quick Probe 补充中文关键词（设计/架构/重构/迁移/前后端/并行/多智能体）
- index.md 模板数量 5→6
- do.md 术语 "Fallback exception" → "Fallback provision" 与 conflict-rules.md 统一
- retro.md Phase 2 各步骤补充显式 fallback 路径

## v2.0.4 (2026-02-22)

- 新增 dialectic-design 到 specialized agents 列表
- M 级补充 Behavioral Tone 引用
- team-templates 更新为 6 模板
- team.md 新增 Dialectic Mode 完整章节

## v2.0.3 (2026-02-22)

- M 级 stage sequence 移至概览行
- scope check 改为定性+定量 OR 条件
- conflict-rules.md 补充 fallback provision
- 补充探测失败默认行为
- low-friction rule 补充分类反馈格式
- Grade Definitions 增加 Key Signal 列和冲突裁决规则

## v2.0.2 (2026-02-22)

- 修复 do.md L 级 fallback exception 与 conflict rule 的矛盾
- P3/V1 补充内联定义
- team.md 补充 ToolSearch 前置步骤
- SKILL.md M 级补充阶段顺序和影响范围超预期暂停规则

## v2.0.1 (2026-02-22)

- S grade removed (implicit), 4→3 grades, 8→5 protocols, 6→3 conflict rules
- Quick probe + user decision gate added
- Team templates added

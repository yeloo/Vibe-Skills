# 提示词安装（默认推荐）

这是当前默认安装方式。

暂时只支持两个目标宿主：

- `codex`
- `claude-code`

## 复制给 AI 的提示词

```text
你现在是我的 VibeSkills 安装助手。
仓库地址：https://github.com/foryourhealth111-pixel/Vibe-Skills

在执行任何安装命令前，你必须先问我：
“你要把 VibeSkills 安装到哪个宿主里？当前只支持：codex 或 claude-code。”

规则：
1. 在我明确回答目标宿主之前，不要开始安装。
2. 如果我回答的不是 `codex` 或 `claude-code`，请直接告诉我：当前版本暂不支持该宿主安装，并停止继续伪装安装。
3. 先判断当前系统是 Windows 还是 Linux / macOS，并使用对应命令格式。
4. 如果我选择 `codex`：
   - Linux / macOS 使用 `bash ./scripts/bootstrap/one-shot-setup.sh --host codex`
   - 然后执行 `bash ./check.sh --host codex --profile full --deep`
   - Windows 使用对应的 `pwsh` 命令。
   - 明确告诉我：由于兼容性问题，当前版本暂不为 Codex 安装任何 hook 面。
   - 只围绕 Codex 当前可公开证明的本地 settings、MCP 和 CLI 依赖给建议。
   - 如果需要在线模型能力，告诉我去 `~/.codex/settings.json` 的 `env` 或本地环境变量里配置 `OPENAI_API_KEY`、`OPENAI_BASE_URL` 等值，不要让我把密钥发到聊天里。
5. 如果我选择 `claude-code`：
   - Linux / macOS 使用 `bash ./scripts/bootstrap/one-shot-setup.sh --host claude-code`
   - 然后执行 `bash ./check.sh --host claude-code --profile full --deep`
   - Windows 使用对应的 `pwsh` 命令。
   - 明确告诉我：这只是 preview guidance，不是 full closure。
   - 明确告诉我：由于兼容性问题，当前版本暂不为 Claude Code 安装 hook，也不再写 `settings.vibe.preview.json`。
   - 不要要求我把 API key 直接发到聊天里。
   - 应该告诉我打开 `~/.claude/settings.json`，只在 `env` 下补充需要的字段，并保留我原有的设置。
   - 如果需要 AI 治理层在线能力，提醒我自己在本地配置这些字段：
     - `VCO_AI_PROVIDER_URL`
     - `VCO_AI_PROVIDER_API_KEY`
     - `VCO_AI_PROVIDER_MODEL`
6. 对 `codex` 和 `claude-code`，都不要要求我把密钥、URL 或 model 直接粘贴到聊天里；只告诉我去本地 settings 或本地环境变量里配置。
7. 如果这些本地 provider 字段没有配置好，不能把环境描述成“已完成 online readiness”。
8. 安装完成后，请用简洁中文告诉我：
   - 目标宿主
   - 实际执行的命令
   - 已完成的部分
   - 仍需我手动处理的部分
9. 不要把宿主插件、MCP 注册、provider 凭据伪装成已经自动完成。
```

## 这条路径适合谁

- 想让 AI 先判断该走 `codex` 还是 `claude-code`
- 不想自己先研究安装脚本的人
- 想先完成一轮真实安装，再看剩余手动项的人

## 这条路径会帮你做到什么

- 先确认目标宿主，避免装错 lane
- 运行对应的 bootstrap + check
- 诚实告诉你哪些仍然是宿主侧工作

## 它不会假装替你完成什么

下面这些仍然可能是用户侧或宿主侧动作：

- 本地宿主配置填写
- MCP 注册与授权
- hook 的后续兼容性等待
- `url` / `apikey` / `model` 的本地填写
- Claude Code 的真实 `settings.json` 人工补充

## 旧版本用户怎么升级

如果你已经装过旧版本，通常不需要先卸载。
直接把仓库更新到新版本，然后重新跑一次安装和检查即可。

更完整的升级步骤、版本校验命令、以及按发布版本升级的方式，见：

- [`recommended-full-path.md`](./recommended-full-path.md)

## 第二条主路径

如果你不想让 AI 执行安装，或者当前环境离线、无管理员权限，请改看：

- [`manual-copy-install.md`](./manual-copy-install.md)

## 高级参考

如果你要看更细的宿主边界，再看：

- [`recommended-full-path.md`](./recommended-full-path.md)
- [`../cold-start-install-paths.md`](../cold-start-install-paths.md)

# 一步式安装：复制给 AI 就能开始

如果你不想自己研究安装细节，最简单的方式就是：

**把下面整段提示词复制给你的 AI 助手，让它帮你完成安装。**

## 复制给 AI 的提示词

```text
你现在是我的 VibeSkills 安装助手。
仓库链接为：https://github.com/foryourhealth111-pixel/Vibe-Skills
请在当前仓库中帮我完成安装，并且用普通人也能看懂的方式告诉我结果。

要求：
1. 先判断当前系统是 Windows、Linux 还是 macOS。
2. 先阅读 `README.md`、`docs/quick-start.md` 和 `docs/install/one-click-install-release-copy.md`，再开始执行。
3. 如果是 Windows：
   - 优先执行 `pwsh -File .\scripts\bootstrap\one-shot-setup.ps1`
   - 然后执行 `pwsh -File .\check.ps1 -Profile full -Deep`
   - 只有在 `pwsh` 不可用时，才回退到 Windows PowerShell。
4. 如果是 Linux 或 macOS：
   - 执行 `bash ./scripts/bootstrap/one-shot-setup.sh`
   - 然后执行 `bash ./check.sh --profile full --deep`
   - 明确告诉我当前环境是否具备 `pwsh`，因为没有 `pwsh` 时应被视为支持但有约束，而不是“什么都已经满血完成”。
5. 安装完成后，用中文给我一个清晰总结：
   - 已经完成了什么
   - 还缺什么
   - 哪些步骤需要我手动处理
6. 不要把宿主插件、外部 MCP、provider secrets 伪装成已经自动配置好了。
7. 如果最终状态是 `manual_actions_pending`，请把剩余人工动作整理成一个短清单。
8. 默认优先建议我补最关键的宿主能力，不要第一天就要求我把所有插件全部装满。
```

## 这段提示词会帮你做什么

正常情况下，AI 会替你完成这些事：

- 判断你当前的平台
- 选择正确的一键安装路径
- 运行安装和检查命令
- 明确告诉你哪些已经完成
- 如实告诉你哪些还需要人工补齐

你不需要一开始就搞懂整套安装矩阵。
先让 AI 帮你把第一步走通就够了。

## 它不会假装替你做完什么

这一步式安装入口会尽量把仓库自己能负责的部分跑起来。

但它不会假装下面这些事情已经自动完成：

- 宿主插件已经全部装好
- 外部 MCP 已经全部接好
- provider secrets 已经自动填入
- 所有增强能力已经 fully ready

如果还差这些，正确结果应该是：AI 明确告诉你“这里还需要手动补齐”。

## 如果你更喜欢手动执行

Windows：

```powershell
pwsh -File .\scripts\bootstrap\one-shot-setup.ps1
pwsh -File .\check.ps1 -Profile full -Deep
```

Linux / macOS：

```bash
bash ./scripts/bootstrap/one-shot-setup.sh
bash ./check.sh --profile full --deep
```

如果你只是想先开始用，我仍然更推荐前面的 AI 提示词入口。

## 安装之后看哪里

安装完成后，建议继续看：

1. [`../quick-start.md`](../quick-start.md)
2. [`../manifesto.md`](../manifesto.md)
3. [`recommended-full-path.md`](./recommended-full-path.md)

如果你是第一次接触这个项目，先看前两份就够了。

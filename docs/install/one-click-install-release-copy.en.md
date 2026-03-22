# Prompt-Based Install (Recommended Default)

This is the default installation path.

At the moment, only two target hosts are supported:

- `codex`
- `claude-code`

## Prompt To Copy Into AI

```text
You are now my VibeSkills installation assistant.
Repository: https://github.com/foryourhealth111-pixel/Vibe-Skills

Before running any install command, you must ask me:
"Which host do you want to install VibeSkills into? Currently supported: codex or claude-code."

Rules:
1. Do not start installation until I explicitly answer which target host I want.
2. If I answer with anything other than `codex` or `claude-code`, tell me clearly that this version does not support that host yet, and stop instead of pretending installation is complete.
3. Detect whether the current system is Windows or Linux / macOS, and use the matching command format.
4. If I choose `codex`:
   - on Linux / macOS, run `bash ./scripts/bootstrap/one-shot-setup.sh --host codex`
   - then run `bash ./check.sh --host codex --profile full --deep`
   - on Windows, use the equivalent `pwsh` commands.
   - explicitly tell me that the current version does not install any hook surface for Codex because of compatibility issues.
   - keep Codex guidance limited to officially supportable local settings, MCP, and optional CLI dependencies.
   - if online model access is needed, tell me to configure `OPENAI_API_KEY`, `OPENAI_BASE_URL`, and related values in `~/.codex/settings.json` under `env` or in local environment variables, not in chat.
5. If I choose `claude-code`:
   - on Linux / macOS, run `bash ./scripts/bootstrap/one-shot-setup.sh --host claude-code`
   - then run `bash ./check.sh --host claude-code --profile full --deep`
   - on Windows, use the equivalent `pwsh` commands.
   - explicitly tell me this is preview guidance, not full closure.
   - explicitly tell me that because of compatibility issues, the current version does not install hooks for Claude Code and no longer writes `settings.vibe.preview.json`.
   - do not ask me to paste API keys into chat.
   - tell me to open `~/.claude/settings.json` and add only the required `env` fields while preserving my existing settings.
   - if AI-governance online capability is needed, remind me to configure these fields locally:
     - `VCO_AI_PROVIDER_URL`
     - `VCO_AI_PROVIDER_API_KEY`
     - `VCO_AI_PROVIDER_MODEL`
6. For both `codex` and `claude-code`, never ask me to paste secrets, URLs, or model values into chat. Only point me to local settings or local environment variables.
7. If the required local provider fields are not configured yet, you must not describe the environment as online-ready.
8. After installation, give me a concise English summary of:
   - the target host
   - the commands actually executed
   - what is complete
   - what I still need to do manually
9. Do not pretend that host plugins, MCP registration, or provider credentials were completed automatically if they were not.
```

## Who This Path Is For

- users who want AI to choose between `codex` and `claude-code`
- users who do not want to study the scripts first
- users who want one truthful install pass plus a clear manual follow-up list

## What This Path Helps With

- confirming the target host first
- running the matching bootstrap + check flow
- explaining what is still host-managed

## What It Does Not Pretend To Do

These may still remain host-side or user-side tasks:

- local host configuration
- MCP registration and authorization
- waiting for hook compatibility work to resume
- local `url` / `apikey` / `model` configuration
- manual updates to Claude Code's real `settings.json`

## How old-version users should upgrade

If you already installed an older version, you usually do not need to uninstall first.
Update the repo to the newer version, then rerun the install and check flow.

For the full upgrade steps, the version verification command, and the release-tag upgrade path, see:

- [`recommended-full-path.en.md`](./recommended-full-path.en.md)

## Second Main Install Path

If you do not want AI to run installation, or the environment is offline or has no admin rights, use:

- [`manual-copy-install.en.md`](./manual-copy-install.en.md)

## Advanced References

If you need the more detailed host boundaries, see:

- [`recommended-full-path.en.md`](./recommended-full-path.en.md)
- [`../cold-start-install-paths.en.md`](../cold-start-install-paths.en.md)

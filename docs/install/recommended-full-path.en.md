# Install Path: Advanced Host / Lane Reference

> Most users should start with the two main install paths:
>
> - [`one-click-install-release-copy.en.md`](./one-click-install-release-copy.en.md)
> - [`manual-copy-install.en.md`](./manual-copy-install.en.md)

This document exists to explain the current real support boundary.

## Current Supported Surface

At the moment, only two hosts are supported:

- `codex`
- `claude-code`

Within that scope:

- `codex`: recommended path
- `claude-code`: preview guidance path

`TargetRoot` is only the install path.
`HostId` / `--host` is what decides host semantics.

## Recommended Commands

### Codex

```powershell
pwsh -File .\scripts\bootstrap\one-shot-setup.ps1 -HostId codex
pwsh -File .\check.ps1 -HostId codex -Profile full -Deep
```

```bash
bash ./scripts/bootstrap/one-shot-setup.sh --host codex
bash ./check.sh --host codex --profile full --deep
```

### Claude Code

```powershell
pwsh -File .\scripts\bootstrap\one-shot-setup.ps1 -HostId claude-code
pwsh -File .\check.ps1 -HostId claude-code -Profile full -Deep
```

```bash
bash ./scripts/bootstrap/one-shot-setup.sh --host claude-code
bash ./check.sh --host claude-code --profile full --deep
```

## How old-version users should upgrade

Old-version users do not need to uninstall first.
The supported path is to update the repo to a newer version, then rerun the install and check commands for the same host.

### If you still have a local checkout of this repo

Update the repo first:

```bash
git pull
```

If you follow named releases instead of tracking `main`, use:

```bash
git fetch --tags --force
git checkout vX.Y.Z
```

Then rerun the install flow.

### Upgrade an existing Codex install

```powershell
pwsh -File .\scripts\bootstrap\one-shot-setup.ps1 -HostId codex
pwsh -File .\check.ps1 -HostId codex -Profile full -Deep
```

```bash
bash ./scripts/bootstrap/one-shot-setup.sh --host codex
bash ./check.sh --host codex --profile full --deep
```

### Upgrade an existing Claude Code install

```powershell
pwsh -File .\scripts\bootstrap\one-shot-setup.ps1 -HostId claude-code
pwsh -File .\check.ps1 -HostId claude-code -Profile full -Deep
```

```bash
bash ./scripts/bootstrap/one-shot-setup.sh --host claude-code
bash ./check.sh --host claude-code --profile full --deep
```

### If you no longer have a local repo copy

Clone the latest repo again, then run the install commands above.

```bash
git clone https://github.com/foryourhealth111-pixel/Vibe-Skills.git
cd Vibe-Skills
```

### How to verify that the upgrade finished

If Codex is installed under the default `~/.codex` target root, check the version governance file directly:

```bash
jq -r '.release.version, .release.updated' ~/.codex/skills/vibe/config/version-governance.json
```

If you installed to a custom `TargetRoot`, replace `~/.codex` with that install root.

### What the upgrade overwrites

- the installer updates the VibeSkills runtime files under the target host root
- local host configuration should remain user-managed, especially local `env` / provider settings
- hooks that are already frozen in current releases do not get silently re-enabled during upgrade

## Boundaries That Must Stay Explicit

### Codex

- this is the strongest repo-governed path today
- guidance should stay limited to local `~/.codex` settings, official MCP registration, and optional CLI dependencies
- hooks are currently frozen because of compatibility issues and are not part of the standard install path
- if online model access is needed, point users to `~/.codex/settings.json` under `env` or local environment variables
- do not ask users to paste secrets into chat

### Claude Code

- this is preview guidance, not full closure
- hooks are currently frozen because of compatibility issues
- the installer no longer writes `settings.vibe.preview.json`
- users should open `~/.claude/settings.json` and add only the required fields under `env`
- common fields are:
  - `VCO_AI_PROVIDER_URL`
  - `VCO_AI_PROVIDER_API_KEY`
  - `VCO_AI_PROVIDER_MODEL`
- add `ANTHROPIC_BASE_URL` and `ANTHROPIC_AUTH_TOKEN` only when needed for the host connection
- do not ask users to paste secrets into chat

## AI Governance Reminder

For `claude-code`, if `url`, `apikey`, and `model` are not configured locally yet, the environment must not be described as online-ready.

Those values must be filled by the user in local host settings or local environment variables.

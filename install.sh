#!/usr/bin/env bash
set -euo pipefail

PROFILE="full"
INSTALL_EXTERNAL="false"
TARGET_ROOT="${HOME}/.codex"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    --target-root) TARGET_ROOT="$2"; shift 2 ;;
    --install-external) INSTALL_EXTERNAL="true"; shift ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CANONICAL_SKILLS_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
WORKSPACE_SKILLS_ROOT="${WORKSPACE_ROOT}/skills"
WORKSPACE_SUPERPOWERS_ROOT="${WORKSPACE_ROOT}/superpowers/skills"

mkdir -p "${TARGET_ROOT}/skills" "${TARGET_ROOT}/rules" "${TARGET_ROOT}/hooks" "${TARGET_ROOT}/agents/templates" "${TARGET_ROOT}/mcp/profiles" "${TARGET_ROOT}/config" "${TARGET_ROOT}/commands"

cp -R "${SCRIPT_DIR}/bundled/skills/." "${TARGET_ROOT}/skills/"

# Ensure unified /vibe entry uses the latest router implementation after install.
VIBE_ROUTER_SRC="${SCRIPT_DIR}/scripts/router/resolve-pack-route.ps1"
VIBE_ROUTER_DEST="${TARGET_ROOT}/skills/vibe/scripts/router/resolve-pack-route.ps1"
if [[ -f "${VIBE_ROUTER_SRC}" ]]; then
  mkdir -p "$(dirname "${VIBE_ROUTER_DEST}")"
  cp "${VIBE_ROUTER_SRC}" "${VIBE_ROUTER_DEST}"
fi

for n in dialectic local-vco-roles spec-kit-vibe-compat superclaude-framework-compat ralph-loop cancel-ralph tdd-guide think-harder; do
  if [[ -d "${CANONICAL_SKILLS_ROOT}/${n}" ]]; then
    cp -R "${CANONICAL_SKILLS_ROOT}/${n}" "${TARGET_ROOT}/skills/"
  elif [[ -d "${SCRIPT_DIR}/bundled/skills/${n}" ]]; then
    cp -R "${SCRIPT_DIR}/bundled/skills/${n}" "${TARGET_ROOT}/skills/"
  else
    echo "[WARN] missing required core skill source: ${n}"
  fi
done

for n in brainstorming writing-plans subagent-driven-development systematic-debugging; do
  if [[ -d "${WORKSPACE_SKILLS_ROOT}/${n}" ]]; then
    cp -R "${WORKSPACE_SKILLS_ROOT}/${n}" "${TARGET_ROOT}/skills/"
  elif [[ -d "${WORKSPACE_SUPERPOWERS_ROOT}/${n}" ]]; then
    cp -R "${WORKSPACE_SUPERPOWERS_ROOT}/${n}" "${TARGET_ROOT}/skills/"
  elif [[ -d "${SCRIPT_DIR}/bundled/superpowers-skills/${n}" ]]; then
    cp -R "${SCRIPT_DIR}/bundled/superpowers-skills/${n}" "${TARGET_ROOT}/skills/"
  else
    echo "[WARN] missing required workflow skill source: ${n}"
  fi
done

if [[ "${PROFILE}" == "full" ]]; then
  for n in requesting-code-review receiving-code-review verification-before-completion; do
    if [[ -d "${WORKSPACE_SKILLS_ROOT}/${n}" ]]; then
      cp -R "${WORKSPACE_SKILLS_ROOT}/${n}" "${TARGET_ROOT}/skills/"
    elif [[ -d "${WORKSPACE_SUPERPOWERS_ROOT}/${n}" ]]; then
      cp -R "${WORKSPACE_SUPERPOWERS_ROOT}/${n}" "${TARGET_ROOT}/skills/"
    elif [[ -d "${SCRIPT_DIR}/bundled/superpowers-skills/${n}" ]]; then
      cp -R "${SCRIPT_DIR}/bundled/superpowers-skills/${n}" "${TARGET_ROOT}/skills/"
    fi
  done
fi

cp -R "${SCRIPT_DIR}/rules/." "${TARGET_ROOT}/rules/"
cp -R "${SCRIPT_DIR}/hooks/." "${TARGET_ROOT}/hooks/"
cp -R "${SCRIPT_DIR}/agents/templates/." "${TARGET_ROOT}/agents/templates/"
cp -R "${SCRIPT_DIR}/mcp/." "${TARGET_ROOT}/mcp/"
cp "${SCRIPT_DIR}/config/plugins-manifest.codex.json" "${TARGET_ROOT}/config/plugins-manifest.codex.json"
cp "${SCRIPT_DIR}/config/upstream-lock.json" "${TARGET_ROOT}/config/upstream-lock.json"

if [[ ! -f "${TARGET_ROOT}/settings.json" ]]; then
  cp "${SCRIPT_DIR}/config/settings.template.codex.json" "${TARGET_ROOT}/settings.json"
fi

if [[ "${INSTALL_EXTERNAL}" == "true" ]]; then
  if command -v npm >/dev/null 2>&1; then
    npm install -g claude-flow || true
    npm install -g @th0rgal/ralph-wiggum || true
  fi

  if ! command -v xan >/dev/null 2>&1; then
    if command -v brew >/dev/null 2>&1; then
      brew install xan || true
    elif command -v pixi >/dev/null 2>&1; then
      pixi global install xan || true
    elif command -v conda >/dev/null 2>&1; then
      conda install -y conda-forge::xan || true
    else
      echo "[WARN] xan CLI not detected. Install manually (brew/pixi/conda/cargo) to enable large CSV acceleration."
    fi
  fi
fi

echo "Install done. Run: bash check.sh --profile ${PROFILE} --target-root ${TARGET_ROOT}"

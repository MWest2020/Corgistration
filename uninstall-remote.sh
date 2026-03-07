#!/usr/bin/env bash
# uninstall-remote.sh — remote uninstaller for corgistration
# Usage: curl -fsSL https://raw.githubusercontent.com/MWest2020/Corgistration/main/uninstall-remote.sh | bash
set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-${HOME}/.local/bin}"
K9S_PLUGINS="${K9S_CONFIG_DIR:-${HOME}/.config/k9s}/plugins.yaml"

if [[ -t 1 ]]; then
  CYAN='\033[1;36m' YELLOW='\033[0;33m' RED='\033[0;31m' RESET='\033[0m'
else
  CYAN='' YELLOW='' RED='' RESET=''
fi

info() { printf "${CYAN}[corgistration]${RESET} %s\n" "$*"; }
warn() { printf "${YELLOW}[corgistration] WARN:${RESET} %s\n" "$*" >&2; }

SCRIPTS=(corgistration.sh collect.sh render.sh orchestrate.sh claude-invoke.sh lib.sh corgi.txt)

for script in "${SCRIPTS[@]}"; do
  target="${INSTALL_DIR}/${script}"
  if [[ -f "$target" ]]; then
    rm "$target"
    info "Removed ${target}"
  fi
done

if [[ -f "${K9S_PLUGINS}" ]]; then
  if command -v yq &>/dev/null; then
    yq eval 'del(.plugins.corgi-pod) | del(.plugins.corgi-deployment) | del(.plugins.corgi-service)' \
      -i "${K9S_PLUGINS}"
    info "Removed corgistration entries from ${K9S_PLUGINS}"
  else
    warn "yq not found — manually remove corgi-pod, corgi-deployment, corgi-service from ${K9S_PLUGINS}"
  fi
fi

info "Uninstall complete. Restart K9s to apply changes."

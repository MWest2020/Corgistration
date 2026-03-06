#!/usr/bin/env bash
# uninstall.sh — remove corgistration scripts and K9s plugin entries
set -euo pipefail

K9S_PLUGINS="${K9S_CONFIG_DIR:-${HOME}/.config/k9s}/plugins.yaml"
INSTALL_DIR="${HOME}/.local/bin"

info() { printf '\033[0;36m[uninstall]\033[0m %s\n' "$*"; }
warn() { printf '\033[0;33m[uninstall] WARN:\033[0m %s\n' "$*" >&2; }

# ── Remove scripts ───────────────────────────────────────────────────────────
for script in corgistration.sh collect.sh render.sh orchestrate.sh claude-invoke.sh lib.sh; do
  target="${INSTALL_DIR}/${script}"
  if [[ -f "$target" ]]; then
    rm "$target"
    info "Removed ${target}"
  fi
done

# ── Remove K9s plugin entries ────────────────────────────────────────────────
if [[ ! -f "${K9S_PLUGINS}" ]]; then
  info "No plugins.yaml found at ${K9S_PLUGINS} — nothing to clean."
else
  if command -v yq &>/dev/null; then
    # Remove the three corgistration plugin keys
    yq eval 'del(.plugins.corgi-pod) | del(.plugins.corgi-deployment) | del(.plugins.corgi-service)' \
      -i "${K9S_PLUGINS}"
    info "Removed corgistration entries from ${K9S_PLUGINS}"
  else
    warn "yq not found — cannot automatically remove plugin entries."
    warn "Please manually remove corgi-pod, corgi-deployment, corgi-service from ${K9S_PLUGINS}"
  fi

  # Restore backup if available
  if [[ -f "${K9S_PLUGINS}.corgi-bak" ]]; then
    read -r -p "Restore original plugins.yaml from backup? [y/N] " answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
      cp "${K9S_PLUGINS}.corgi-bak" "${K9S_PLUGINS}"
      rm "${K9S_PLUGINS}.corgi-bak"
      info "Restored ${K9S_PLUGINS} from backup."
    else
      info "Backup kept at ${K9S_PLUGINS}.corgi-bak"
    fi
  fi
fi

info "Uninstall complete. Restart K9s to apply changes."

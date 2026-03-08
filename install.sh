#!/usr/bin/env bash
# install.sh — install corgistration scripts and K9s plugin entries
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K9S_PLUGINS="${K9S_CONFIG_DIR:-${HOME}/.config/k9s}/plugins.yaml"
INSTALL_DIR="${HOME}/.local/bin"
CORGI_MARKER="# corgistration-managed"

# ── Helpers ──────────────────────────────────────────────────────────────────
info()  { printf '\033[0;36m[install]\033[0m %s\n' "$*"; }
warn()  { printf '\033[0;33m[install] WARN:\033[0m %s\n' "$*" >&2; }
die()   { printf '\033[0;31m[install] ERROR:\033[0m %s\n' "$*" >&2; exit 1; }

require_cmd() {
  command -v "$1" &>/dev/null || die "'$1' is required. $2"
}

# ── Prerequisite check ───────────────────────────────────────────────────────
require_cmd yq  "Install yq: https://github.com/mikefarah/yq#install"
require_cmd go  "Install Go: https://go.dev/dl/"

# ── Build and install corgi binary ───────────────────────────────────────────
info "Building corgi binary…"
(cd "${SCRIPT_DIR}" && go build -ldflags "-X main.version=$(git describe --tags --always 2>/dev/null || echo dev) -X main.commit=$(git rev-parse --short HEAD 2>/dev/null || echo none)" -o "${INSTALL_DIR}/corgi" ./cmd/corgi/)
info "  installed corgi → ${INSTALL_DIR}/corgi"

# ── Install scripts ──────────────────────────────────────────────────────────
info "Installing scripts to ${INSTALL_DIR}/"
mkdir -p "${INSTALL_DIR}"

for script in corgistration.sh collect.sh render.sh orchestrate.sh claude-invoke.sh lib.sh corgi.txt; do
  src="${SCRIPT_DIR}/scripts/${script}"
  [[ -f "$src" ]] || die "Missing source script: ${src}"
  cp "$src" "${INSTALL_DIR}/${script}"
  chmod +x "${INSTALL_DIR}/${script}"
  info "  installed ${script}"
done

# ── K9s plugin merge ─────────────────────────────────────────────────────────
PLUGIN_SRC="${SCRIPT_DIR}/k9s/plugins.yaml"
mkdir -p "$(dirname "${K9S_PLUGINS}")"

# Idempotency check
if [[ -f "${K9S_PLUGINS}" ]] && grep -q "corgi-pod\|corgi-deployment\|corgi-service" "${K9S_PLUGINS}" 2>/dev/null; then
  info "Corgistration plugin entries already present in ${K9S_PLUGINS} — skipping merge."
else
  # Backup existing config
  if [[ -f "${K9S_PLUGINS}" ]]; then
    cp "${K9S_PLUGINS}" "${K9S_PLUGINS}.corgi-bak"
    info "Backed up existing plugins.yaml → ${K9S_PLUGINS}.corgi-bak"
    # Merge: combine existing plugins with corgistration entries
    yq eval-all 'select(fileIndex==0) * select(fileIndex==1)' \
      "${K9S_PLUGINS}" "${PLUGIN_SRC}" > "${K9S_PLUGINS}.tmp"
    mv "${K9S_PLUGINS}.tmp" "${K9S_PLUGINS}"
    info "Merged corgistration plugin entries into ${K9S_PLUGINS}"
  else
    cp "${PLUGIN_SRC}" "${K9S_PLUGINS}"
    info "Created ${K9S_PLUGINS} with corgistration plugin entries"
  fi
fi

# ── Done ─────────────────────────────────────────────────────────────────────
info ""
info "Installation complete!"
info ""
info "Next steps:"
info "  1. Restart K9s to pick up the new plugin."
info "  2. Navigate to a Pod, Deployment, or Service."
info "  3. Press Shift-A to trigger the diagnostic integration."
info ""
info "To change the hotkey, edit: ${K9S_PLUGINS}"
info "To uninstall, run: ./uninstall.sh"

#!/usr/bin/env bash
# setup_colorize.sh — install kubectl-colorize and wire it into claude CLI
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${HOME}/.local/bin"
COLORIZER_SRC="${SCRIPT_DIR}/kubectl_colorize.py"
COLORIZER_DST="${INSTALL_DIR}/kubectl-colorize"
BASHRC="${HOME}/.bashrc"

info()  { printf '\033[0;36m[colorize]\033[0m %s\n' "$*"; }
ok()    { printf '\033[0;32m[colorize]\033[0m %s\n' "$*"; }
warn()  { printf '\033[0;33m[colorize] WARN:\033[0m %s\n' "$*" >&2; }
die()   { printf '\033[0;31m[colorize] ERROR:\033[0m %s\n' "$*" >&2; exit 1; }

# ── Prerequisites ─────────────────────────────────────────────────────────────
command -v python3 &>/dev/null || die "python3 is required but not found on PATH."

# ── Install colorizer ─────────────────────────────────────────────────────────
mkdir -p "${INSTALL_DIR}"
cp "${COLORIZER_SRC}" "${COLORIZER_DST}"
chmod +x "${COLORIZER_DST}"
ok "Installed kubectl-colorize → ${COLORIZER_DST}"

# ── Patch ~/.bashrc (idempotent) ──────────────────────────────────────────────
MARKER="# corgistration: kubectl colorizer"

if grep -qF "$MARKER" "${BASHRC}" 2>/dev/null; then
  info "kubectl-colorize already wired into ${BASHRC} — skipping."
else
  cat >> "${BASHRC}" << 'EOF'

# corgistration: kubectl colorizer
# Wraps claude CLI in a PTY so output is colorized without breaking interactivity.
# To disable: set NO_COLOR=1 or pass --no-color before --
claude() {
  python3 ~/.local/bin/kubectl-colorize -- command claude "$@"
}
EOF
  ok "Wired claude() wrapper into ${BASHRC}"
fi

# ── Done ──────────────────────────────────────────────────────────────────────
info ""
info "Setup complete!"
info ""
info "Activate now:     source ~/.bashrc"
info "Test colorizer:   echo 'kubectl get pods -n production' | kubectl-colorize"
info "Test with claude: claude --version   (should still work)"
info ""
info "To uninstall:"
info "  rm ${COLORIZER_DST}"
info "  # Remove the 'corgistration: kubectl colorizer' block from ~/.bashrc"

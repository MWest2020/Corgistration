#!/usr/bin/env bash
# install.sh — install corgistration scripts, corgi binary, and K9s plugin entries
# Usage: ./install.sh [--install-deps]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K9S_PLUGINS="${K9S_CONFIG_DIR:-${HOME}/.config/k9s}/plugins.yaml"
INSTALL_DIR="${HOME}/.local/bin"
INSTALL_DEPS=false

# ── Helpers ──────────────────────────────────────────────────────────────────
info()  { printf '\033[0;36m[install]\033[0m %s\n' "$*"; }
warn()  { printf '\033[0;33m[install] WARN:\033[0m %s\n' "$*" >&2; }
die()   { printf '\033[0;31m[install] ERROR:\033[0m %s\n' "$*" >&2; exit 1; }
ok()    { printf '\033[0;32m[install]\033[0m %s\n' "$*"; }

# ── Flags ─────────────────────────────────────────────────────────────────────
for arg in "$@"; do
  case "$arg" in
    --install-deps|-d) INSTALL_DEPS=true ;;
    --help|-h)
      echo "Usage: ./install.sh [--install-deps]"
      echo "  --install-deps, -d   auto-install missing prerequisites"
      exit 0 ;;
  esac
done

# ── OS detection ──────────────────────────────────────────────────────────────
detect_os() {
  case "$(uname -s)" in
    Linux*)
      if command -v apt-get &>/dev/null; then echo "debian"
      elif command -v dnf &>/dev/null;   then echo "fedora"
      elif command -v pacman &>/dev/null; then echo "arch"
      else echo "linux"
      fi ;;
    Darwin*) echo "macos" ;;
    *)       echo "unknown" ;;
  esac
}
OS="$(detect_os)"

# ── Auto-install logic ────────────────────────────────────────────────────────
install_pkg() {
  local pkg="$1"
  info "Installing ${pkg}…"
  case "$OS" in
    debian) sudo apt-get install -y "$pkg" ;;
    fedora) sudo dnf install -y "$pkg" ;;
    arch)   sudo pacman -S --noconfirm "$pkg" ;;
    macos)  brew install "$pkg" ;;
    *)      die "Cannot auto-install ${pkg} on this OS. Install manually." ;;
  esac
}

install_go() {
  info "Installing Go via system package manager…"
  case "$OS" in
    debian) sudo apt-get install -y golang-go ;;
    fedora) sudo dnf install -y golang ;;
    arch)   sudo pacman -S --noconfirm go ;;
    macos)  brew install go ;;
    *)      die "Cannot auto-install Go on this OS. See https://go.dev/dl/" ;;
  esac
}

install_kubectl() {
  info "Installing kubectl…"
  case "$OS" in
    debian)
      curl -fsSL "https://dl.k8s.io/release/$(curl -fsSL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
        -o /tmp/kubectl
      chmod +x /tmp/kubectl
      sudo mv /tmp/kubectl /usr/local/bin/kubectl ;;
    fedora) sudo dnf install -y kubectl ;;
    arch)   sudo pacman -S --noconfirm kubectl ;;
    macos)  brew install kubectl ;;
    *)      die "Cannot auto-install kubectl on this OS. See https://kubernetes.io/docs/tasks/tools/" ;;
  esac
}

install_yq() {
  info "Installing yq…"
  local version="v4.44.2"
  case "$OS" in
    debian|fedora|linux)
      curl -fsSL "https://github.com/mikefarah/yq/releases/download/${version}/yq_linux_amd64" \
        -o /tmp/yq && chmod +x /tmp/yq && sudo mv /tmp/yq /usr/local/bin/yq ;;
    arch)   sudo pacman -S --noconfirm go-yq ;;
    macos)  brew install yq ;;
    *)      die "Cannot auto-install yq on this OS. See https://github.com/mikefarah/yq#install" ;;
  esac
}

install_claude() {
  die "claude CLI must be installed manually — it requires a Node.js runtime and an Anthropic account.
  Install Node.js:  https://nodejs.org
  Then run:         npm install -g @anthropic-ai/claude-code
  Sign in:          claude login"
}

install_tmux() { install_pkg tmux; }
install_bat() {
  case "$OS" in
    # Ubuntu/Debian ships bat as 'batcat' — install and symlink
    debian)
      sudo apt-get install -y bat
      mkdir -p "${HOME}/.local/bin"
      ln -sf "$(command -v batcat 2>/dev/null || echo /usr/bin/batcat)" "${HOME}/.local/bin/bat" ;;
    *) install_pkg bat ;;
  esac
}

# ── ensure_cmd ────────────────────────────────────────────────────────────────
# ensure_cmd <cmd> <install_fn> <required|optional>
ensure_cmd() {
  local cmd="$1" install_fn="$2" required="${3:-required}"
  if command -v "$cmd" &>/dev/null; then
    ok "  ${cmd} found"
    return 0
  fi
  if [[ "$INSTALL_DEPS" == "true" ]]; then
    "$install_fn" || true
    if command -v "$cmd" &>/dev/null; then
      ok "  ${cmd} installed"
    elif [[ "$required" == "optional" ]]; then
      warn "  ${cmd} could not be installed (optional — skipping)"
    else
      die "Failed to install ${cmd}"
    fi
  elif [[ "$required" == "optional" ]]; then
    warn "  ${cmd} not found (optional — skipping)"
  else
    die "'${cmd}' is required. Re-run with --install-deps to auto-install, or install manually."
  fi
}

# ── Prerequisite check / install ─────────────────────────────────────────────
info "Checking prerequisites…"
ensure_cmd tmux    install_tmux    required
ensure_cmd kubectl install_kubectl required
ensure_cmd claude  install_claude  required
ensure_cmd yq      install_yq      required
ensure_cmd go      install_go      required
ensure_cmd bat     install_bat     optional

# ── Build and install corgi binary ───────────────────────────────────────────
info "Building corgi binary…"
mkdir -p "${INSTALL_DIR}"
(cd "${SCRIPT_DIR}" && go build \
  -ldflags "-X main.version=$(git describe --tags --always 2>/dev/null || echo dev) -X main.commit=$(git rev-parse --short HEAD 2>/dev/null || echo none)" \
  -o "${INSTALL_DIR}/corgi" ./cmd/corgi/)
info "  installed corgi → ${INSTALL_DIR}/corgi"

# ── Install scripts ──────────────────────────────────────────────────────────
info "Installing scripts to ${INSTALL_DIR}/"

for script in corgistration.sh collect.sh render.sh orchestrate.sh claude-invoke.sh lib.sh corgi.txt; do
  src="${SCRIPT_DIR}/scripts/${script}"
  [[ -f "$src" ]] || die "Missing source script: ${src}"
  cp "$src" "${INSTALL_DIR}/${script}"
  [[ "$script" == *.txt ]] || chmod +x "${INSTALL_DIR}/${script}"
  info "  installed ${script}"
done

# ── K9s plugin merge ─────────────────────────────────────────────────────────
PLUGIN_SRC="${SCRIPT_DIR}/k9s/plugins.yaml"
mkdir -p "$(dirname "${K9S_PLUGINS}")"

if [[ -f "${K9S_PLUGINS}" ]] && grep -q "corgi-pod\|corgi-deployment\|corgi-service" "${K9S_PLUGINS}" 2>/dev/null; then
  info "Corgistration plugin entries already present in ${K9S_PLUGINS} — skipping merge."
else
  if [[ -f "${K9S_PLUGINS}" ]]; then
    cp "${K9S_PLUGINS}" "${K9S_PLUGINS}.corgi-bak"
    info "Backed up existing plugins.yaml → ${K9S_PLUGINS}.corgi-bak"
    yq eval-all 'select(fileIndex==0) * select(fileIndex==1)' \
      "${K9S_PLUGINS}" "${PLUGIN_SRC}" > "${K9S_PLUGINS}.tmp"
    mv "${K9S_PLUGINS}.tmp" "${K9S_PLUGINS}"
    info "Merged corgistration plugin entries into ${K9S_PLUGINS}"
  else
    cp "${PLUGIN_SRC}" "${K9S_PLUGINS}"
    info "Created ${K9S_PLUGINS} with corgistration plugin entries"
  fi
fi

# ── PATH check ────────────────────────────────────────────────────────────────
if ! echo "$PATH" | grep -q "${INSTALL_DIR}"; then
  warn "${INSTALL_DIR} is not in your PATH."
  warn "Add this to your ~/.bashrc or ~/.zshrc:"
  warn "  export PATH=\"${INSTALL_DIR}:\$PATH\""
  warn "Then run: source ~/.bashrc"
fi

# ── Done ─────────────────────────────────────────────────────────────────────
info ""
info "Installation complete!"
info ""
info "Next steps:"
info "  1. Restart K9s to pick up the new plugin."
info "  2. Navigate to a Pod, Deployment, or Service."
info "  3. Press Shift-A to trigger the diagnostic integration."
info "  Or run: corgi   (interactive TUI picker)"
info ""
info "To change the hotkey, edit: ${K9S_PLUGINS}"
info "To uninstall, run: ./uninstall.sh"

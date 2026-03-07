#!/usr/bin/env bash
# get.sh — remote installer for corgistration
# Usage: curl -fsSL https://raw.githubusercontent.com/MWest2020/Corgistration/main/get.sh | bash
#
# To review before running (recommended):
#   curl -fsSL https://raw.githubusercontent.com/MWest2020/Corgistration/main/get.sh | less
#   bash <(curl -fsSL https://raw.githubusercontent.com/MWest2020/Corgistration/main/get.sh)
set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
REPO="MWest2020/Corgistration"
BRANCH="${CORGI_BRANCH:-main}"
RAW="https://raw.githubusercontent.com/${REPO}/${BRANCH}"
INSTALL_DIR="${INSTALL_DIR:-${HOME}/.local/bin}"
K9S_PLUGINS="${K9S_CONFIG_DIR:-${HOME}/.config/k9s}/plugins.yaml"

SCRIPTS=(
  scripts/corgistration.sh
  scripts/collect.sh
  scripts/render.sh
  scripts/orchestrate.sh
  scripts/claude-invoke.sh
  scripts/lib.sh
  scripts/corgi.txt
)

# ── Colors ────────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  RED='\033[0;31m' YELLOW='\033[0;33m' CYAN='\033[1;36m' DIM='\033[2m' RESET='\033[0m'
else
  RED='' YELLOW='' CYAN='' DIM='' RESET=''
fi

info()    { printf "${CYAN}[corgistration]${RESET} %s\n" "$*"; }
warn()    { printf "${YELLOW}[corgistration] WARN:${RESET} %s\n" "$*" >&2; }
die()     { printf "${RED}[corgistration] ERROR:${RESET} %s\n" "$*" >&2; exit 1; }
success() { printf "${CYAN}[corgistration]${RESET} %s\n" "$*"; }

# ── Guards ────────────────────────────────────────────────────────────────────
[[ "$(id -u)" -eq 0 ]] && die "Do not run as root. corgistration installs to ~/.local/bin."

command -v curl &>/dev/null || die "curl is required to run this installer."

# ── OS detection & prereq hints ───────────────────────────────────────────────
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

hint_for() {
  local cmd="$1"
  case "$cmd" in
    tmux)
      case "$OS" in
        debian) echo "sudo apt-get install -y tmux" ;;
        fedora) echo "sudo dnf install -y tmux" ;;
        arch)   echo "sudo pacman -S tmux" ;;
        macos)  echo "brew install tmux" ;;
        *)      echo "https://github.com/tmux/tmux" ;;
      esac ;;
    kubectl)
      case "$OS" in
        debian|fedora|arch) echo "https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/" ;;
        macos)              echo "brew install kubectl" ;;
        *)                  echo "https://kubernetes.io/docs/tasks/tools/" ;;
      esac ;;
    claude)
      echo "npm install -g @anthropic-ai/claude-code  (requires Node.js)" ;;
    yq)
      case "$OS" in
        debian) echo "sudo snap install yq  OR  https://github.com/mikefarah/yq#install" ;;
        fedora) echo "sudo dnf install -y yq  OR  https://github.com/mikefarah/yq#install" ;;
        macos)  echo "brew install yq" ;;
        *)      echo "https://github.com/mikefarah/yq#install" ;;
      esac ;;
    bat)
      case "$OS" in
        debian) echo "sudo apt-get install -y bat" ;;
        fedora) echo "sudo dnf install -y bat" ;;
        macos)  echo "brew install bat" ;;
        *)      echo "https://github.com/sharkdp/bat#installation" ;;
      esac ;;
  esac
}

check_prereq() {
  local cmd="$1" required="${2:-true}"
  if ! command -v "$cmd" &>/dev/null; then
    if [[ "$required" == "true" ]]; then
      warn "Required: '$cmd' not found."
      warn "  Install: $(hint_for "$cmd")"
      return 1
    else
      info "Optional: '$cmd' not found — $(hint_for "$cmd")"
      return 0
    fi
  fi
}

# ── Prereq checks ─────────────────────────────────────────────────────────────
info "Checking prerequisites..."
MISSING=0
check_prereq tmux    required || MISSING=$((MISSING+1))
check_prereq kubectl required || MISSING=$((MISSING+1))
check_prereq claude  required || MISSING=$((MISSING+1))
check_prereq yq      required || MISSING=$((MISSING+1))
check_prereq bat     optional

(( MISSING > 0 )) && die "${MISSING} required prerequisite(s) missing. Install them and re-run."

# ── Download scripts ──────────────────────────────────────────────────────────
info "Installing scripts to ${INSTALL_DIR}/"
mkdir -p "${INSTALL_DIR}"

for file in "${SCRIPTS[@]}"; do
  dest="${INSTALL_DIR}/$(basename "$file")"
  curl -fsSL "${RAW}/${file}" -o "$dest"
  # corgi.txt is a data file, not executable
  [[ "$file" == *.txt ]] || chmod +x "$dest"
  info "  ✓ $(basename "$file")"
done

# ── K9s plugin merge ──────────────────────────────────────────────────────────
mkdir -p "$(dirname "${K9S_PLUGINS}")"
PLUGIN_TMP="$(mktemp)"
curl -fsSL "${RAW}/k9s/plugins.yaml" -o "$PLUGIN_TMP"

if [[ -f "${K9S_PLUGINS}" ]] && grep -q "corgi-pod\|corgi-deployment\|corgi-service" "${K9S_PLUGINS}" 2>/dev/null; then
  info "K9s plugin entries already present — skipping merge."
  rm -f "$PLUGIN_TMP"
else
  if [[ -f "${K9S_PLUGINS}" ]]; then
    cp "${K9S_PLUGINS}" "${K9S_PLUGINS}.corgi-bak"
    info "Backed up existing plugins.yaml → ${K9S_PLUGINS}.corgi-bak"
    yq eval-all 'select(fileIndex==0) * select(fileIndex==1)' \
      "${K9S_PLUGINS}" "$PLUGIN_TMP" > "${K9S_PLUGINS}.tmp"
    mv "${K9S_PLUGINS}.tmp" "${K9S_PLUGINS}"
  else
    cp "$PLUGIN_TMP" "${K9S_PLUGINS}"
  fi
  rm -f "$PLUGIN_TMP"
  info "K9s plugin entries installed → ${K9S_PLUGINS}"
fi

# ── PATH check ────────────────────────────────────────────────────────────────
if ! echo "$PATH" | grep -q "${INSTALL_DIR}"; then
  warn "${INSTALL_DIR} is not in your PATH."
  warn "Add this to your ~/.bashrc or ~/.zshrc:"
  warn "  export PATH=\"${INSTALL_DIR}:\$PATH\""
  warn "Then run: source ~/.bashrc"
fi

# ── Done ──────────────────────────────────────────────────────────────────────
printf "\n"
success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
success "  corgistration installed!"
success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
printf "\n"
info "Next steps:"
info "  1. Restart K9s to pick up the new plugin"
info "  2. Highlight any Pod, Deployment, or Service"
info "  3. Press Shift-A and let Claude diagnose it"
printf "\n"
info "  ${DIM}To uninstall:  curl -fsSL ${RAW}/uninstall-remote.sh | bash${RESET}"
info "  ${DIM}Docs:          https://github.com/${REPO}${RESET}"
printf "\n"

#!/usr/bin/env bash
# lib.sh — shared helpers for corgistration scripts

# ANSI colors
CORGI_RED='\033[0;31m'
CORGI_YELLOW='\033[0;33m'
CORGI_CYAN='\033[0;36m'
CORGI_BOLD_CYAN='\033[1;36m'
CORGI_DIM='\033[2m'
CORGI_RESET='\033[0m'

# corgi_log <level> <message>
# Levels: INFO, WARN, ERROR
corgi_log() {
  local level="$1"
  local msg="$2"
  case "$level" in
    ERROR) printf "${CORGI_RED}[corgistration] ERROR: %s${CORGI_RESET}\n" "$msg" >&2 ;;
    WARN)  printf "${CORGI_YELLOW}[corgistration] WARN: %s${CORGI_RESET}\n"  "$msg" >&2 ;;
    *)     printf "[corgistration] %s\n" "$msg" >&2 ;;
  esac
}

# corgi_banner [kind] [name] [namespace]
# Prints the ASCII corgi splash to stdout, scaled to terminal width.
corgi_banner() {
  local kind="${1:-}"
  local name="${2:-}"
  local ns="${3:-}"
  local target=""
  [[ -n "$kind" ]] && target="${kind}/${name} (${ns})"

  local _lib_dir
  _lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  # Detect terminal width; fall back to 80
  local cols
  cols="$(tput cols 2>/dev/null || echo 80)"

  local sep
  sep="$(printf '%*s' "$cols" '' | tr ' ' '=')"

  # Compact banner for narrow terminals (< 60 cols)
  if (( cols < 60 )); then
    printf "${CORGI_BOLD_CYAN}%s${CORGI_RESET}\n" "$sep"
    printf "${CORGI_YELLOW}  CORGISTRATION${CORGI_RESET}\n"
    printf "${CORGI_BOLD_CYAN}%s${CORGI_RESET}\n" "$sep"
    [[ -n "$target" ]] && printf "  ${CORGI_DIM}%s${CORGI_RESET}\n" "$target"
    printf "\n"
    return
  fi

  printf "${CORGI_BOLD_CYAN}%s${CORGI_RESET}\n" "$sep"
  printf "${CORGI_YELLOW}%*s${CORGI_RESET}\n" $(( (cols + 38) / 2 )) "C  O  R  G  I  S  T  R  A  T  I  O  N"
  printf "${CORGI_BOLD_CYAN}%s${CORGI_RESET}\n" "$sep"

  # Corgi art — clip lines to terminal width so they never wrap
  local art="${_lib_dir}/corgi.txt"
  if [[ -f "$art" ]]; then
    while IFS= read -r line; do
      printf '%.*s\n' "$cols" "$line"
    done < "$art"
  fi

  printf "${CORGI_DIM}%*s${CORGI_RESET}\n" $(( cols - 1 )) "☕  https://www.buymeacoffee.com/mark.westerweel"
  [[ -n "$target" ]] && printf "  ${CORGI_DIM}diagnosing: %s${CORGI_RESET}\n" "$target"
  printf "\n"
}

# require_cmd <cmd> [install-hint]
# Exits 1 if <cmd> is not on PATH, printing an actionable message.
require_cmd() {
  local cmd="$1"
  local hint="${2:-}"
  if ! command -v "$cmd" &>/dev/null; then
    corgi_log ERROR "'$cmd' is required but not found on PATH."
    if [[ -n "$hint" ]]; then
      printf "  Install hint: %s\n" "$hint" >&2
    fi
    return 1
  fi
}

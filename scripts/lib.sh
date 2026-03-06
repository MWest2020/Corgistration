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

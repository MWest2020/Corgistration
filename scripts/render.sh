#!/usr/bin/env bash
# render.sh — syntax-highlighted, colorized TUI renderer for corgistration context
# Usage: render.sh <context-file>
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

CONTEXT_FILE="${1:-}"
if [[ -z "$CONTEXT_FILE" || ! -f "$CONTEXT_FILE" ]]; then
  corgi_log ERROR "Usage: render.sh <context-file>"
  exit 1
fi

# ── Color helpers ─────────────────────────────────────────────────────────────
red()       { printf "${CORGI_RED}%s${CORGI_RESET}\n" "$1"; }
yellow()    { printf "${CORGI_YELLOW}%s${CORGI_RESET}\n" "$1"; }
dim()       { printf "${CORGI_DIM}%s${CORGI_RESET}\n" "$1"; }
bold_cyan() { printf "${CORGI_BOLD_CYAN}%s${CORGI_RESET}\n" "$1"; }

# ── Section header detector ───────────────────────────────────────────────────
is_section_header() { [[ "$1" =~ ^===.*===$ ]]; }

# ── Log line colorizer ────────────────────────────────────────────────────────
colorize_log_line() {
  local line="$1"
  if [[ "$line" =~ ERROR|FATAL ]]; then
    red "$line"
  elif [[ "$line" =~ WARN|WARNING ]]; then
    yellow "$line"
  else
    printf '%s\n' "$line"
  fi
}

# ── Event line colorizer ──────────────────────────────────────────────────────
colorize_event_line() {
  local line="$1"
  if [[ "$line" =~ ^Warning ]]; then
    printf "${CORGI_YELLOW}! %s${CORGI_RESET}\n" "$line"
  elif [[ "$line" =~ ^Normal ]]; then
    dim "$line"
  else
    printf '%s\n' "$line"
  fi
}

# ── Render function (writes to stdout) ───────────────────────────────────────
render_to_stdout() {
  local section=""
  local yaml_buf=""
  local in_yaml=0

  while IFS= read -r line; do
    if is_section_header "$line"; then
      # If we were buffering YAML, flush it now
      if [[ $in_yaml -eq 1 && -n "$yaml_buf" ]]; then
        if command -v bat &>/dev/null; then
          printf '%s\n' "$yaml_buf" | bat --language=yaml --color=always --style=plain
        else
          printf '%s\n' "$yaml_buf"
          printf '%s\n' "(install bat for syntax highlighting)"
        fi
        yaml_buf=""
        in_yaml=0
      fi
      bold_cyan "$line"
      section="$line"
      continue
    fi

    case "$section" in
      "=== YAML MANIFEST ===")
        in_yaml=1
        yaml_buf+="${line}"$'\n'
        ;;
      "=== EVENTS ===")
        colorize_event_line "$line"
        ;;
      "=== LOGS ===")
        colorize_log_line "$line"
        ;;
      *)
        printf '%s\n' "$line"
        ;;
    esac
  done < "$CONTEXT_FILE"

  # Flush any remaining YAML buffer
  if [[ $in_yaml -eq 1 && -n "$yaml_buf" ]]; then
    if command -v bat &>/dev/null; then
      printf '%s\n' "$yaml_buf" | bat --language=yaml --color=always --style=plain
    else
      printf '%s\n' "$yaml_buf"
      printf '%s\n' "(install bat for syntax highlighting)"
    fi
  fi
}

# ── Pager if output exceeds terminal height ───────────────────────────────────
TERM_LINES="${LINES:-$(tput lines 2>/dev/null || echo 40)}"
OUTPUT="$(render_to_stdout)"
OUTPUT_LINES="$(printf '%s\n' "$OUTPUT" | wc -l)"

if (( OUTPUT_LINES > TERM_LINES )); then
  printf '%s\n' "$OUTPUT" | less -R
else
  printf '%s\n' "$OUTPUT"
fi

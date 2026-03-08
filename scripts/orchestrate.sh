#!/usr/bin/env bash
# orchestrate.sh — manage tmux session layout for corgistration
# Usage: orchestrate.sh <context-file> <kind> <name> <namespace>
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

CONTEXT_FILE="${1:-}"
KIND="${2:-}"
NAME="${3:-}"
NAMESPACE="${4:-}"

if [[ -z "$CONTEXT_FILE" || -z "$KIND" || -z "$NAME" || -z "$NAMESPACE" ]]; then
  corgi_log ERROR "Usage: orchestrate.sh <context-file> <kind> <name> <namespace>"
  exit 1
fi

SESSION="corgistration"
LEFT_PANE="${SESSION}:0.0"   # YAML / events / logs
RIGHT_PANE="${SESSION}:0.1"  # Claude

# Shell-quote all user-derived values to prevent injection via resource name/namespace
Q_SCRIPT_DIR="$(printf '%q' "${SCRIPT_DIR}")"
Q_CONTEXT="$(printf '%q' "${CONTEXT_FILE}")"
Q_KIND="$(printf '%q' "${KIND}")"
Q_NAME="$(printf '%q' "${NAME}")"
Q_NS="$(printf '%q' "${NAMESPACE}")"

RENDER_CMD="${Q_SCRIPT_DIR}/render.sh ${Q_CONTEXT}"
INVOKE_CMD="${Q_SCRIPT_DIR}/claude-invoke.sh ${Q_CONTEXT} ${Q_KIND} ${Q_NAME} ${Q_NS}"

# ── Session management ────────────────────────────────────────────────────────
if tmux has-session -t "$SESSION" 2>/dev/null; then
  corgi_log INFO "Reusing existing tmux session: $SESSION"
  # Collapse any extra windows back to single-window layout if needed
  while tmux list-windows -t "$SESSION" | grep -q "^1:"; do
    tmux kill-window -t "${SESSION}:1" 2>/dev/null || break
  done
  tmux send-keys -t "$LEFT_PANE"  "clear && ${RENDER_CMD}" Enter
  tmux send-keys -t "$RIGHT_PANE" "clear && ${INVOKE_CMD}" Enter
else
  corgi_log INFO "Creating new tmux session: $SESSION"

  tmux new-session -d -s "$SESSION" -x 220 -y 50

  # Mouse mode: click to focus a pane, then select text freely.
  # Hold Shift while dragging to bypass tmux and use terminal native selection.
  tmux set-option -t "$SESSION" -g mouse on

  # Status bar hint
  tmux set-option -t "$SESSION" status-right \
    "#[fg=colour8] click=focus pane | Shift+drag=copy text | Ctrl-b [ =copy mode"

  # Keep pane alive if render exits
  tmux set-option -t "${SESSION}:0" remain-on-exit on

  # Split: left 55% = context, right 45% = Claude
  tmux split-window -t "${SESSION}:0" -h -l 45%

  # Left pane: YAML / events / logs
  tmux send-keys -t "$LEFT_PANE" "${RENDER_CMD}" Enter

  # Right pane: corgi banner then Claude
  tmux send-keys -t "$RIGHT_PANE" \
    "source ${Q_SCRIPT_DIR}/lib.sh && corgi_banner ${Q_KIND} ${Q_NAME} ${Q_NS} && ${INVOKE_CMD}" Enter
fi

# ── Attach focused on right pane (Claude) ─────────────────────────────────────
tmux select-pane -t "$RIGHT_PANE"

if [[ -n "${TMUX:-}" ]]; then
  tmux switch-client -t "$SESSION"
else
  tmux attach-session -t "$SESSION"
fi

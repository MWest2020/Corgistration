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

# ── Apply session options (always, new or reused) ─────────────────────────────
apply_session_options() {
  # Mouse: click to focus a pane. Shift+drag = terminal native copy (bypasses tmux).
  tmux set-option -t "$SESSION" -g mouse on

  # Pane border colours so active pane is obvious
  tmux set-option -t "$SESSION" -g pane-active-border-style "fg=colour4"
  tmux set-option -t "$SESSION" -g pane-border-style "fg=colour8"

  # Status bar — always visible at the bottom
  tmux set-option -t "$SESSION" status on
  tmux set-option -t "$SESSION" status-style "bg=colour235,fg=colour250"
  tmux set-option -t "$SESSION" status-left \
    "#[fg=colour6,bold] corgistration #[fg=colour8]│ "
  tmux set-option -t "$SESSION" status-right \
    "#[fg=colour3] Ctrl-b o#[fg=colour8]=switch pane  #[fg=colour3]Ctrl-b g#[fg=colour8]=new resource  #[fg=colour3]Shift+drag#[fg=colour8]=copy  #[fg=colour3]Ctrl-b d#[fg=colour8]=detach "
  tmux set-option -t "$SESSION" status-right-length 100

  # Ctrl-b g → open picker in a temporary window; on selection window closes
  # and the session panes are refreshed automatically by corgi itself.
  tmux bind-key -T prefix g new-window -n "picker" "corgi; tmux kill-window"

  # Ctrl-b o already cycles panes by default; also bind arrow keys explicitly
  tmux bind-key -T prefix Left  select-pane -L
  tmux bind-key -T prefix Right select-pane -R
}

# ── Session management ────────────────────────────────────────────────────────
if tmux has-session -t "$SESSION" 2>/dev/null; then
  corgi_log INFO "Reusing existing tmux session: $SESSION"

  # Collapse any extra windows (e.g. leftover picker window)
  while tmux list-windows -t "$SESSION" | grep -qE "^[1-9]:"; do
    tmux kill-window -t "${SESSION}:1" 2>/dev/null || break
  done

  apply_session_options

  tmux send-keys -t "$LEFT_PANE"  "clear && ${RENDER_CMD}" Enter
  tmux send-keys -t "$RIGHT_PANE" "clear && ${INVOKE_CMD}" Enter
else
  corgi_log INFO "Creating new tmux session: $SESSION"

  tmux new-session -d -s "$SESSION" -x 220 -y 50

  # Keep pane alive if render exits so YAML stays visible
  tmux set-option -t "${SESSION}:0" remain-on-exit on

  apply_session_options

  # Split: left 55% = context viewer, right 45% = Claude
  tmux split-window -t "${SESSION}:0" -h -l 45%

  # Left pane: YAML / events / logs
  tmux send-keys -t "$LEFT_PANE" "${RENDER_CMD}" Enter

  # Right pane: corgi banner then Claude
  tmux send-keys -t "$RIGHT_PANE" \
    "source ${Q_SCRIPT_DIR}/lib.sh && corgi_banner ${Q_KIND} ${Q_NAME} ${Q_NS} && ${INVOKE_CMD}" Enter
fi

# ── Attach focused on Claude (right pane) ─────────────────────────────────────
tmux select-pane -t "$RIGHT_PANE"

if [[ -n "${TMUX:-}" ]]; then
  tmux switch-client -t "$SESSION"
else
  tmux attach-session -t "$SESSION"
fi

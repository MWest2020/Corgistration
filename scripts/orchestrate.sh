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
PANE_YAML="${SESSION}:0.0"    # left        — YAML / events / logs
PANE_CLAUDE="${SESSION}:0.1"  # right top   — Claude
PANE_TERM="${SESSION}:0.2"    # right bottom — terminal (run kubectl here)

# Shell-quote all user-derived values to prevent injection via resource name/namespace
Q_SCRIPT_DIR="$(printf '%q' "${SCRIPT_DIR}")"
Q_CONTEXT="$(printf '%q' "${CONTEXT_FILE}")"
Q_KIND="$(printf '%q' "${KIND}")"
Q_NAME="$(printf '%q' "${NAME}")"
Q_NS="$(printf '%q' "${NAMESPACE}")"

RENDER_CMD="${Q_SCRIPT_DIR}/render.sh ${Q_CONTEXT}"
INVOKE_CMD="${Q_SCRIPT_DIR}/claude-invoke.sh ${Q_CONTEXT} ${Q_KIND} ${Q_NAME} ${Q_NS}"
BANNER_CMD="source ${Q_SCRIPT_DIR}/lib.sh && corgi_banner ${Q_KIND} ${Q_NAME} ${Q_NS}"

# ── Apply session options (always, new or reused) ─────────────────────────────
apply_session_options() {
  tmux set-option -t "$SESSION" -g mouse on
  tmux set-option -t "$SESSION" -g pane-active-border-style "fg=colour4"
  tmux set-option -t "$SESSION" -g pane-border-style "fg=colour8"
  tmux set-option -t "$SESSION" status on
  tmux set-option -t "$SESSION" status-style "bg=colour235,fg=colour250"
  tmux set-option -t "$SESSION" status-left "#[fg=colour6,bold] corgistration #[fg=colour8]│ "
  tmux set-option -t "$SESSION" status-right \
    "#[fg=colour3]Ctrl-b o#[fg=colour8]=pane  #[fg=colour3]Ctrl-b r#[fg=colour8]=picker  #[fg=colour3]Ctrl-b q#[fg=colour8]=quit  #[fg=colour3]Shift+drag#[fg=colour8]=copy  #[fg=colour3]Ctrl-b d#[fg=colour8]=detach "
  tmux set-option -t "$SESSION" status-right-length 100

  # Ctrl-b o already cycles panes — don't bind arrow keys (they interfere with Claude)

  CORGI_BIN="${HOME}/.local/bin/corgi"

  # Ctrl-b r → return to picker: runs corgi in a full-screen new window.
  # orchestrate.sh switches client back to window 0 after selection.
  # The picker window closes automatically when corgi exits.
  tmux bind-key -T prefix r new-window -n "picker" "${CORGI_BIN}"

  # Ctrl-b q → exit: kill session and return to terminal
  tmux bind-key -T prefix q kill-session
}

# ── Session management ────────────────────────────────────────────────────────
if tmux has-session -t "$SESSION" 2>/dev/null; then
  corgi_log INFO "Refreshing existing tmux session: $SESSION"

  apply_session_options

  # Ensure all three panes exist in window 0 — create if missing
  PANE_COUNT="$(tmux list-panes -t "${SESSION}:0" | wc -l)"
  if (( PANE_COUNT < 2 )); then
    tmux split-window -t "${SESSION}:0.0" -h -l 45% "bash"
  fi
  if (( PANE_COUNT < 3 )); then
    tmux split-window -t "${SESSION}:0.1" -v -l 25% "bash"
  fi

  # Respawn panes — YAML stays (remain-on-exit), others close cleanly
  tmux set-option -p -t "$PANE_YAML"   remain-on-exit on
  tmux set-option -p -t "$PANE_CLAUDE" remain-on-exit off
  tmux set-option -p -t "$PANE_TERM"   remain-on-exit off
  tmux respawn-pane -k -t "$PANE_YAML"   "${RENDER_CMD}"
  tmux respawn-pane -k -t "$PANE_CLAUDE" "${BANNER_CMD} && ${INVOKE_CMD}"
  tmux respawn-pane -k -t "$PANE_TERM"   "bash"

else
  corgi_log INFO "Creating new tmux session: $SESSION"

  # Window 0, pane 0: YAML viewer (left)
  tmux new-session -d -s "$SESSION" -n "corgi" -x 220 -y 50 \
    "${RENDER_CMD}"

  apply_session_options

  # YAML pane stays visible after render exits; other panes close normally
  tmux set-option -p -t "${SESSION}:0.0" remain-on-exit on

  # Pane 1: Claude (right top)
  tmux split-window -t "${SESSION}:0.0" -h -l 45% \
    "${BANNER_CMD} && ${INVOKE_CMD}"

  # Pane 2: terminal shell (right bottom, 25% height)
  tmux split-window -t "${SESSION}:0.1" -v -l 25% \
    "bash"
fi

# ── Always land on window 0, Claude pane — even when called from picker window
tmux select-window -t "${SESSION}:0"
tmux select-pane   -t "$PANE_CLAUDE"

if [[ -n "${TMUX:-}" ]]; then
  tmux switch-client -t "${SESSION}:0"
else
  tmux attach-session -t "${SESSION}:0"
fi

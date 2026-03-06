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
LEFT_PANE="${SESSION}:0.0"
RIGHT_PANE="${SESSION}:0.1"

# Shell-quote all user-derived values to prevent injection via resource name/namespace
# printf '%q' produces bash-safe quoting for each token
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
  # Update pane contents with new context
  tmux send-keys -t "$LEFT_PANE"  "clear && ${RENDER_CMD}" Enter
  tmux send-keys -t "$RIGHT_PANE" "clear && ${INVOKE_CMD}" Enter
else
  corgi_log INFO "Creating new tmux session: $SESSION"
  # Create detached session with first window
  tmux new-session -d -s "$SESSION" -x 220 -y 50

  # Set left pane to remain on exit so a render crash doesn't kill the session
  tmux set-option -t "${SESSION}:0" remain-on-exit on

  # Split horizontally: left=55%, right=45%
  tmux split-window -t "${SESSION}:0" -h -l 45%

  # Launch renderer in left pane (pane 0)
  tmux send-keys -t "$LEFT_PANE"  "${RENDER_CMD}" Enter

  # Launch claude invoker in right pane (pane 1)
  tmux send-keys -t "$RIGHT_PANE" "${INVOKE_CMD}" Enter
fi

# ── Attach or switch to session ───────────────────────────────────────────────
if [[ -n "${TMUX:-}" ]]; then
  # Already inside tmux — switch client
  tmux switch-client -t "$SESSION"
else
  # Outside tmux — attach
  tmux attach-session -t "$SESSION"
fi
